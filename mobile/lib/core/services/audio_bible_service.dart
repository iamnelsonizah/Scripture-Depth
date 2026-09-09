import 'dart:async';
import 'dart:io' show Platform, Process, File;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/scripture_models.dart';
import '../network/api_client.dart';
import 'app_settings_service.dart';
import 'audio_cache_service.dart';

class AudioBibleService {
  static final AudioBibleService _instance = AudioBibleService._internal();
  factory AudioBibleService() => _instance;
  AudioBibleService._internal();

  static const MethodChannel _audioplayersTestChannel =
      MethodChannel('xyz.luan/audioplayers.global');

  final FlutterTts _tts = FlutterTts();
  AudioPlayer? _audioPlayer;
  bool _isInitialized = false;
  bool _hasTtsPlugin = false;
  bool _hasAudioPlayerPlugin = false;
  bool _isTestMode = false;

  Process? _activeProcess;
  Process? _activeAudioProcess;
  Timer? _fallbackTimer;
  Timer? _playbackPositionTimer;

  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);
  final ValueNotifier<int?> currentVerseNumber = ValueNotifier<int?>(null);
  final ValueNotifier<String?> currentReference = ValueNotifier<String?>(null);
  final ValueNotifier<double> playbackSpeed = ValueNotifier<double>(1.0);

  // Audio fidelity & state tracking
  final ValueNotifier<String> fidelityLabel = ValueNotifier<String>('High-Fidelity Audio');
  final ValueNotifier<bool> isUsingHumanAudio = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isCachedOffline = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isManuscriptMode = ValueNotifier<bool>(false);

  List<VerseModel> _currentPlaylist = [];
  int _currentIndex = 0;
  bool _isChapterMode = false;
  String? _currentBookName;
  String? _currentBookCode;
  int? _currentChapter;
  String _currentTranslationId = 'kjv';

  ChapterAudioInfo? _currentAudioInfo;
  StreamSubscription? _positionSub;
  StreamSubscription? _completeSub;

  Future<bool> _isAudioPlayersSupported() async {
    try {
      await _audioplayersTestChannel.invokeMethod<void>('init');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isTestMode = Platform.environment.containsKey('FLUTTER_TEST');
    if (_isTestMode) {
      _hasTtsPlugin = false;
      _hasAudioPlayerPlugin = false;
      _isInitialized = true;
      return;
    }

    final settings = AppSettingsService();
    playbackSpeed.value = settings.audioSpeed;

    // 1. Guarded AudioPlayer initialization:
    // Probe the method channel first. If the plugin isn't compiled into the binary
    // (e.g. before full rebuild or on unsupported targets), NEVER construct AudioPlayer.
    bool pluginAvailable = false;
    try {
      pluginAvailable = await _isAudioPlayersSupported();
    } catch (_) {
      pluginAvailable = false;
    }

    if (pluginAvailable) {
      try {
        final player = AudioPlayer();
        _audioPlayer = player;
        player.setReleaseMode(ReleaseMode.stop);

        _positionSub = player.onPositionChanged.listen(
          (Duration pos) => _handleStreamPosition(pos),
          onError: (_) => _hasAudioPlayerPlugin = false,
        );

        _completeSub = player.onPlayerComplete.listen(
          (_) {
            isPlaying.value = false;
            currentVerseNumber.value = null;
            currentReference.value = null;
          },
          onError: (_) => _hasAudioPlayerPlugin = false,
        );

        _hasAudioPlayerPlugin = true;
      } catch (_) {
        _hasAudioPlayerPlugin = false;
        _audioPlayer = null;
      }
    } else {
      _hasAudioPlayerPlugin = false;
      _audioPlayer = null;
    }

    // 2. Initialize fallback TTS engine
    try {
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.setLanguage(_getVoiceLanguage());

      if (!kIsWeb) {
        try {
          await _tts.setIosAudioCategory(
            IosTextToSpeechAudioCategory.ambient,
            [
              IosTextToSpeechAudioCategoryOptions.allowBluetooth,
              IosTextToSpeechAudioCategoryOptions.duckOthers,
            ],
          );
          await _tts.awaitSpeakCompletion(true);
        } catch (_) {}
      }

      _tts.setStartHandler(() => isPlaying.value = true);
      _tts.setCompletionHandler(() {
        if (_isChapterMode) {
          _advanceToNextVerse();
        } else {
          isPlaying.value = false;
          currentVerseNumber.value = null;
          currentReference.value = null;
        }
      });
      _tts.setCancelHandler(() {
        isPlaying.value = false;
        currentVerseNumber.value = null;
        currentReference.value = null;
      });
      _tts.setErrorHandler((_) {
        isPlaying.value = false;
        currentVerseNumber.value = null;
        currentReference.value = null;
      });

      _hasTtsPlugin = true;
    } catch (_) {
      _hasTtsPlugin = false;
    }

    _isInitialized = true;
  }

  void _handleStreamPosition(Duration pos) {
    if (_currentAudioInfo == null || _currentAudioInfo!.verses.isEmpty) return;
    final ms = pos.inMilliseconds;
    for (final marker in _currentAudioInfo!.verses) {
      if (ms >= marker.startMs && ms < marker.endMs) {
        if (currentVerseNumber.value != marker.verse) {
          currentVerseNumber.value = marker.verse;
          if (_currentBookName != null && _currentChapter != null) {
            currentReference.value = '$_currentBookName $_currentChapter:${marker.verse}';
          }
        }
        break;
      }
    }
  }

  String _getVoiceLanguage() {
    try {
      final voice = AppSettingsService().audioVoice;
      if (voice.contains('(UK)')) return 'en-GB';
      if (voice.contains('(AU)')) return 'en-AU';
      return 'en-US';
    } catch (_) {
      return 'en-US';
    }
  }

  /// Sets playback speed multiplier (e.g., 0.75, 1.0, 1.25, 1.5, 2.0)
  Future<void> setSpeed(double speed) async {
    playbackSpeed.value = speed;
    AppSettingsService().setAudioSpeed(speed);

    if (_hasAudioPlayerPlugin && _audioPlayer != null && !_isTestMode) {
      try {
        await _audioPlayer?.setPlaybackRate(speed);
      } catch (_) {}
    }

    final rate = (0.48 * speed).clamp(0.25, 1.0);
    if (_hasTtsPlugin) {
      try {
        await _tts.setSpeechRate(rate);
      } catch (_) {}
    }
  }

  Future<void> _stopSpeechOnly() async {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _playbackPositionTimer?.cancel();
    _playbackPositionTimer = null;

    if (_hasAudioPlayerPlugin && _audioPlayer != null && !_isTestMode) {
      try {
        await _audioPlayer?.stop();
      } catch (_) {}
    }

    final audioProc = _activeAudioProcess;
    _activeAudioProcess = null;
    audioProc?.kill();

    if (_hasTtsPlugin) {
      try {
        await _tts.stop();
      } catch (_) {}
    }

    final proc = _activeProcess;
    _activeProcess = null;
    proc?.kill();
  }

  void _startPositionTracking({int startVerseIndex = 0}) {
    _playbackPositionTimer?.cancel();
    if (_currentAudioInfo == null || _currentAudioInfo!.verses.isEmpty) return;

    final startTime = DateTime.now();
    int initialMs = 0;
    if (startVerseIndex > 0 && startVerseIndex < _currentAudioInfo!.verses.length) {
      initialMs = _currentAudioInfo!.verses[startVerseIndex].startMs;
    }

    _playbackPositionTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (!isPlaying.value) {
        timer.cancel();
        return;
      }
      final elapsedMs = (DateTime.now().difference(startTime).inMilliseconds * playbackSpeed.value).round() + initialMs;
      for (final marker in _currentAudioInfo!.verses) {
        if (elapsedMs >= marker.startMs && elapsedMs < marker.endMs) {
          if (currentVerseNumber.value != marker.verse) {
            currentVerseNumber.value = marker.verse;
            if (_currentBookName != null && _currentChapter != null) {
              currentReference.value = '$_currentBookName $_currentChapter:${marker.verse}';
            }
          }
          break;
        }
      }
    });
  }

  Future<void> _speakText(String text, {String? language, double rate = 0.48}) async {
    if (_isTestMode) return;

    final lang = language ?? _getVoiceLanguage();

    if (_hasTtsPlugin) {
      try {
        await _tts.setLanguage(lang);
        await _tts.setSpeechRate(rate);
        await _tts.speak(text);
        return;
      } catch (_) {}
    }

    // Native macOS desktop fallback using built-in /usr/bin/say
    if (!kIsWeb && Platform.isMacOS) {
      try {
        final wpm = (175 * playbackSpeed.value).round();
        final voiceArgs = lang == 'en-GB' ? ['-v', 'Daniel'] : ['-v', 'Samantha'];
        Process proc;
        try {
          proc = await Process.start('say', [...voiceArgs, '-r', '$wpm', text]);
        } catch (_) {
          proc = await Process.start('say', ['-r', '$wpm', text]);
        }
        _activeProcess = proc;
        proc.exitCode.then((exitCode) {
          if (_activeProcess == proc) {
            _activeProcess = null;
            if (_isChapterMode) {
              _advanceToNextVerse();
            } else {
              isPlaying.value = false;
              currentVerseNumber.value = null;
              currentReference.value = null;
            }
          }
        });
        return;
      } catch (_) {}
    }

    // Fallback simulation timer when no audio output device is present
    _fallbackTimer?.cancel();
    final wordCount = text.split(' ').length;
    final durationSec = (wordCount / (3.0 * playbackSpeed.value)).clamp(1.0, 20.0);
    _fallbackTimer = Timer(Duration(milliseconds: (durationSec * 1000).round()), () {
      if (isPlaying.value) {
        if (_isChapterMode) {
          _advanceToNextVerse();
        } else {
          isPlaying.value = false;
          currentVerseNumber.value = null;
          currentReference.value = null;
        }
      }
    });
  }

  /// Pronounces an original language word (Greek, Hebrew, Latin, or English transliteration)
  Future<void> pronounceWord(String word, {String language = 'greek'}) async {
    await initialize();
    await _stopSpeechOnly();

    String langCode = 'en-US';
    final langLower = language.toLowerCase();
    if (langLower.contains('greek')) {
      langCode = 'el-GR';
    } else if (langLower.contains('hebrew')) {
      langCode = 'he-IL';
    } else if (langLower.contains('latin')) {
      langCode = 'la';
    }

    await _speakText(word, language: langCode, rate: 0.38);
  }

  /// Reads a single verse
  Future<void> speakSingleVerse(
    VerseModel verse, {
    String? bookName,
    int? chapter,
    String? bookCode,
    String translationId = 'kjv',
  }) async {
    await initialize();
    await _stopSpeechOnly();
    _isChapterMode = false;
    _currentPlaylist = [verse];
    _currentIndex = 0;
    _currentBookName = bookName;
    _currentBookCode = bookCode;
    _currentChapter = chapter;
    _currentTranslationId = translationId;

    currentVerseNumber.value = verse.verse;
    currentReference.value = bookName != null && chapter != null
        ? '$bookName $chapter:${verse.verse}'
        : 'Verse ${verse.verse}';
    isPlaying.value = true;

    final rate = (0.48 * playbackSpeed.value).clamp(0.25, 1.0);
    await _speakText(verse.text, language: _getVoiceLanguage(), rate: rate);
  }

  /// Starts or resumes reading an entire chapter sequentially using
  /// High-Fidelity Human Narration with local MP3 cache & offline fallback
  Future<void> playChapter(
    List<VerseModel> verses, {
    int startVerseIndex = 0,
    String? bookName,
    int? chapter,
    String? bookCode,
    String translationId = 'kjv',
    ApiClient? apiClient,
  }) async {
    await initialize();
    if (verses.isEmpty) return;
    await _stopSpeechOnly();

    _currentPlaylist = verses;
    _currentIndex = startVerseIndex.clamp(0, verses.length - 1);
    _isChapterMode = true;
    _currentBookName = bookName;
    _currentBookCode = bookCode;
    _currentChapter = chapter;
    _currentTranslationId = translationId;

    final initialVerse = _currentPlaylist[_currentIndex];
    currentVerseNumber.value = initialVerse.verse;
    if (_currentBookName != null && _currentChapter != null) {
      currentReference.value = '$_currentBookName $_currentChapter:${initialVerse.verse}';
    } else {
      currentReference.value = 'Verse ${initialVerse.verse}';
    }

    if (_isTestMode) {
      isPlaying.value = true;
      _playCurrentVerseFallback();
      return;
    }

    final bCode = bookCode ?? 'GEN';
    final chNum = chapter ?? 1;

    // Step 1: Check Local Disk Audio Cache
    final cachedFile = await AudioCacheService().getCachedFile(translationId, bCode, chNum);
    if (cachedFile != null) {
      await _playFile(cachedFile, startVerseIndex: startVerseIndex);
      return;
    }

    // Step 2: Fetch High-Fidelity Audio Info & Stream
    final client = apiClient ?? ApiClient();
    try {
      final info = await client.getChapterAudioInfo(
        translationId: translationId,
        bookCode: bCode,
        chapter: chNum,
      );

      if (info != null && (info.streamUrl.isNotEmpty || info.directCdnUrl.isNotEmpty)) {
        _currentAudioInfo = info;
        isPlaying.value = true;
        isUsingHumanAudio.value = true;
        fidelityLabel.value = info.fidelityLabel;

        // On mobile with AudioPlayer plugin:
        if (_hasAudioPlayerPlugin && _audioPlayer != null) {
          try {
            await _audioPlayer?.play(UrlSource(info.streamUrl));
            await _audioPlayer?.setPlaybackRate(playbackSpeed.value);
            if (startVerseIndex > 0 && startVerseIndex < info.verses.length) {
              final marker = info.verses[startVerseIndex];
              await _audioPlayer?.seek(Duration(milliseconds: marker.startMs));
            }

            // Cache in background
            AudioCacheService().downloadAndCacheChapter(
              translationId: translationId,
              bookCode: bCode,
              chapter: chNum,
              audioUrl: info.streamUrl,
            ).then((cached) {
              if (cached) isCachedOffline.value = true;
            });
            return;
          } catch (_) {}
        }

        // On macOS desktop without CocoaPods: Download and play using built-in /usr/bin/afplay
        if (!kIsWeb && Platform.isMacOS) {
          final targetUrl = info.directCdnUrl.isNotEmpty ? info.directCdnUrl : info.streamUrl;
          final downloaded = await AudioCacheService().downloadAndCacheChapter(
            translationId: translationId,
            bookCode: bCode,
            chapter: chNum,
            audioUrl: targetUrl,
          );
          if (downloaded) {
            final f = await AudioCacheService().getCachedFile(translationId, bCode, chNum);
            if (f != null) {
              await _playFile(f, startVerseIndex: startVerseIndex);
              return;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('AudioBibleService: High-fidelity audio unavailable: $e');
    }

    // Step 3: Offline Fallback to System Voice
    isCachedOffline.value = false;
    isUsingHumanAudio.value = false;
    fidelityLabel.value = 'System Voice · Offline';
    isPlaying.value = true;
    await _playCurrentVerseFallback();
  }

  Future<void> _playFile(File file, {int startVerseIndex = 0}) async {
    isCachedOffline.value = true;
    isUsingHumanAudio.value = true;
    fidelityLabel.value = 'Alexander Scourby · Cached';
    isPlaying.value = true;

    // A: Mobile audioplayers
    if (_hasAudioPlayerPlugin && _audioPlayer != null && !_isTestMode) {
      try {
        await _audioPlayer?.play(DeviceFileSource(file.path));
        await _audioPlayer?.setPlaybackRate(playbackSpeed.value);
        return;
      } catch (_) {}
    }

    // B: macOS built-in afplay
    if (!kIsWeb && Platform.isMacOS) {
      try {
        final rate = playbackSpeed.value.toStringAsFixed(2);
        final proc = await Process.start('afplay', [file.path, '-r', rate]);
        _activeAudioProcess = proc;
        _startPositionTracking(startVerseIndex: startVerseIndex);

        proc.exitCode.then((_) {
          if (_activeAudioProcess == proc) {
            _activeAudioProcess = null;
            _playbackPositionTimer?.cancel();
            isPlaying.value = false;
            currentVerseNumber.value = null;
            currentReference.value = null;
          }
        });
        return;
      } catch (e) {
        debugPrint('AudioBibleService: afplay error: $e');
      }
    }

    // C: Fallback to speech text
    await _playCurrentVerseFallback();
  }

  Future<void> _playCurrentVerseFallback() async {
    if (_currentIndex < 0 || _currentIndex >= _currentPlaylist.length) {
      await stop();
      return;
    }

    final verse = _currentPlaylist[_currentIndex];
    currentVerseNumber.value = verse.verse;
    if (_currentBookName != null && _currentChapter != null) {
      currentReference.value = '$_currentBookName $_currentChapter:${verse.verse}';
    } else {
      currentReference.value = 'Verse ${verse.verse}';
    }
    isPlaying.value = true;

    final rate = (0.48 * playbackSpeed.value).clamp(0.25, 1.0);
    await _speakText(verse.text, language: _getVoiceLanguage(), rate: rate);
  }

  void _advanceToNextVerse() {
    if (!_isChapterMode) return;
    if (_currentIndex + 1 < _currentPlaylist.length) {
      _currentIndex++;
      _playCurrentVerseFallback();
    } else {
      stop();
    }
  }

  /// Skip to next verse in playlist / audio track
  Future<void> nextVerse() async {
    if (_currentPlaylist.isEmpty) return;

    if (isUsingHumanAudio.value && _hasAudioPlayerPlugin && _audioPlayer != null && _currentAudioInfo != null && !_isTestMode) {
      if (_currentIndex + 1 < _currentAudioInfo!.verses.length) {
        _currentIndex++;
        final marker = _currentAudioInfo!.verses[_currentIndex];
        await _audioPlayer?.seek(Duration(milliseconds: marker.startMs));
        currentVerseNumber.value = marker.verse;
        if (_currentBookName != null && _currentChapter != null) {
          currentReference.value = '$_currentBookName $_currentChapter:${marker.verse}';
        }
        return;
      } else {
        await stop();
        return;
      }
    }

    await _stopSpeechOnly();
    if (_currentIndex + 1 < _currentPlaylist.length) {
      _currentIndex++;
      await _playCurrentVerseFallback();
    } else {
      await stop();
    }
  }

  /// Go back to previous verse in playlist / audio track
  Future<void> previousVerse() async {
    if (_currentPlaylist.isEmpty) return;

    if (isUsingHumanAudio.value && _hasAudioPlayerPlugin && _audioPlayer != null && _currentAudioInfo != null && !_isTestMode) {
      if (_currentIndex > 0) {
        _currentIndex--;
      }
      final marker = _currentAudioInfo!.verses[_currentIndex];
      await _audioPlayer?.seek(Duration(milliseconds: marker.startMs));
      currentVerseNumber.value = marker.verse;
      if (_currentBookName != null && _currentChapter != null) {
        currentReference.value = '$_currentBookName $_currentChapter:${marker.verse}';
      }
      return;
    }

    await _stopSpeechOnly();
    if (_currentIndex > 0) {
      _currentIndex--;
    }
    await _playCurrentVerseFallback();
  }

  /// Seeks to a specific verse within the active chapter
  Future<void> seekToVerse(int verseNumber) async {
    final idx = _currentPlaylist.indexWhere((v) => v.verse == verseNumber);
    if (idx != -1) {
      _currentIndex = idx;
    }

    if (isUsingHumanAudio.value && _hasAudioPlayerPlugin && _audioPlayer != null && _currentAudioInfo != null && !_isTestMode) {
      final marker = _currentAudioInfo!.verses.firstWhere(
        (m) => m.verse == verseNumber,
        orElse: () => _currentAudioInfo!.verses.first,
      );
      await _audioPlayer?.seek(Duration(milliseconds: marker.startMs));
      currentVerseNumber.value = verseNumber;
      if (_currentBookName != null && _currentChapter != null) {
        currentReference.value = '$_currentBookName $_currentChapter:$verseNumber';
      }
      return;
    }

    await _stopSpeechOnly();
    await _playCurrentVerseFallback();
  }

  /// Pre-caches the current chapter audio to disk
  Future<bool> cacheCurrentChapter({ApiClient? apiClient}) async {
    if (_currentBookCode == null || _currentChapter == null) return false;
    final client = apiClient ?? ApiClient();
    try {
      final info = await client.getChapterAudioInfo(
        translationId: _currentTranslationId,
        bookCode: _currentBookCode!,
        chapter: _currentChapter!,
      );
      if (info != null && (info.streamUrl.isNotEmpty || info.directCdnUrl.isNotEmpty)) {
        final targetUrl = info.directCdnUrl.isNotEmpty ? info.directCdnUrl : info.streamUrl;
        final success = await AudioCacheService().downloadAndCacheChapter(
          translationId: _currentTranslationId,
          bookCode: _currentBookCode!,
          chapter: _currentChapter!,
          audioUrl: targetUrl,
        );
        if (success) {
          isCachedOffline.value = true;
          fidelityLabel.value = '${info.narrator} · Cached';
        }
        return success;
      }
    } catch (_) {}
    return false;
  }

  /// Pause current audio / speech
  Future<void> pause() async {
    if (_hasAudioPlayerPlugin && _audioPlayer != null && !_isTestMode) {
      try {
        await _audioPlayer?.pause();
      } catch (_) {}
    }
    await _stopSpeechOnly();
    isPlaying.value = false;
  }

  /// Resume playback
  Future<void> resume() async {
    if (_hasAudioPlayerPlugin && _audioPlayer != null && !_isTestMode) {
      try {
        await _audioPlayer?.resume();
        isPlaying.value = true;
        return;
      } catch (_) {}
    }

    if (_currentPlaylist.isNotEmpty) {
      await _playCurrentVerseFallback();
    } else {
      isPlaying.value = true;
    }
  }

  /// Stop all playback and reset active verse
  Future<void> stop() async {
    await _stopSpeechOnly();
    isPlaying.value = false;
    currentVerseNumber.value = null;
    currentReference.value = null;
    _isChapterMode = false;
    _currentPlaylist = [];
    _currentIndex = 0;
    _currentAudioInfo = null;
  }
}
