import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class AudioCacheService {
  static final AudioCacheService _instance = AudioCacheService._internal();
  factory AudioCacheService() => _instance;
  AudioCacheService._internal();

  Directory? _cacheDir;

  Future<Directory> _getDirectory() async {
    if (_cacheDir != null) return _cacheDir!;
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      _cacheDir = Directory.systemTemp.createTempSync('scripture_audio_test_');
      return _cacheDir!;
    }
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/audio_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  String _buildFileName(String translationId, String bookCode, int chapter) {
    return '${translationId.toLowerCase()}_${bookCode.toUpperCase()}_$chapter.mp3';
  }

  /// Returns the absolute path where the chapter audio is or should be stored.
  Future<String> getLocalAudioPath(String translationId, String bookCode, int chapter) async {
    final dir = await _getDirectory();
    return '${dir.path}/${_buildFileName(translationId, bookCode, chapter)}';
  }

  /// Returns true if the high-fidelity audio MP3 for the chapter is cached locally.
  Future<bool> isChapterCached(String translationId, String bookCode, int chapter) async {
    try {
      final path = await getLocalAudioPath(translationId, bookCode, chapter);
      final file = File(path);
      return await file.exists() && (await file.length()) > 1024;
    } catch (_) {
      return false;
    }
  }

  /// Returns the File handle if cached, or null if not yet cached.
  Future<File?> getCachedFile(String translationId, String bookCode, int chapter) async {
    try {
      final path = await getLocalAudioPath(translationId, bookCode, chapter);
      final file = File(path);
      if (await file.exists() && (await file.length()) > 1024) {
        return file;
      }
    } catch (_) {}
    return null;
  }

  /// Downloads chapter MP3 and caches it on local storage.
  Future<bool> downloadAndCacheChapter({
    required String translationId,
    required String bookCode,
    required int chapter,
    required String audioUrl,
  }) async {
    try {
      final uri = Uri.parse(audioUrl);
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 && response.bodyBytes.length > 1024) {
        final path = await getLocalAudioPath(translationId, bookCode, chapter);
        final file = File(path);
        await file.writeAsBytes(response.bodyBytes, flush: true);
        debugPrint('AudioCacheService: successfully cached $path (${response.bodyBytes.length} bytes)');
        return true;
      }
    } catch (e) {
      debugPrint('AudioCacheService: download failed for $bookCode $chapter: $e');
    }
    return false;
  }

  /// Saves raw MP3 bytes directly to cache.
  Future<bool> saveAudioBytes({
    required String translationId,
    required String bookCode,
    required int chapter,
    required List<int> bytes,
  }) async {
    try {
      final path = await getLocalAudioPath(translationId, bookCode, chapter);
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Returns the total size of cached audio files in megabytes.
  Future<double> getCacheSizeMB() async {
    try {
      final dir = await _getDirectory();
      if (!await dir.exists()) return 0.0;
      int totalBytes = 0;
      await for (final file in dir.list(recursive: false)) {
        if (file is File && file.path.endsWith('.mp3')) {
          totalBytes += await file.length();
        }
      }
      return totalBytes / (1024.0 * 1024.0);
    } catch (_) {
      return 0.0;
    }
  }

  /// Returns the total count of downloaded chapters.
  Future<int> getCachedChaptersCount() async {
    try {
      final dir = await _getDirectory();
      if (!await dir.exists()) return 0;
      int count = 0;
      await for (final file in dir.list(recursive: false)) {
        if (file is File && file.path.endsWith('.mp3')) {
          count++;
        }
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  /// Clears all cached MP3 audio files from the device.
  Future<void> clearCache() async {
    try {
      final dir = await _getDirectory();
      if (await dir.exists()) {
        await for (final file in dir.list(recursive: false)) {
          if (file is File && file.path.endsWith('.mp3')) {
            await file.delete();
          }
        }
      }
    } catch (_) {}
  }
}
