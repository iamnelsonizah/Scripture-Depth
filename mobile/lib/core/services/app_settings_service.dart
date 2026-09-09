import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central reactive settings service managing reading typography,
/// default translation, audio playback styles, and offline status.
class AppSettingsService extends ChangeNotifier {
  static final AppSettingsService _instance = AppSettingsService._internal();
  factory AppSettingsService() => _instance;
  AppSettingsService._internal();

  // Preferences Keys
  static const String _keyDefaultTranslationId = 'pref_default_translation_id';
  static const String _keyDefaultTranslationAbbr = 'pref_default_translation_abbr';
  static const String _keyReaderFontSize = 'pref_reader_font_size';
  static const String _keyReaderFontFamily = 'pref_reader_font_family';
  static const String _keyAudioVoice = 'pref_audio_voice';
  static const String _keyAudioSpeed = 'pref_audio_speed';
  static const String _keyAutoScrollAudio = 'pref_auto_scroll_audio';
  static const String _keyHasCompletedOnboarding = 'has_completed_onboarding';
  static const String _keyAmbientSoundscape = 'pref_ambient_soundscape';
  static const String _keyStudyGoal = 'pref_study_goal';
  static const String _keyUserName = 'pref_user_name';

  // Default values
  String _defaultTranslationId = 'kjv';
  String _defaultTranslationAbbr = 'KJV';
  double _readerFontSize = 17.0;
  String _readerFontFamily = 'Georgia';
  String _audioVoice = 'Natural Reverent (US)';
  double _audioSpeed = 1.0;
  bool _autoScrollAudio = true;
  bool _hasCompletedOnboarding = false;
  String _ambientSoundscape = 'none'; // 'none', 'rain', 'library'
  String _studyGoal = 'original_languages';
  String _userName = '';

  // Live dynamic stats cache
  int _streakDays = 0;
  int _memorizedCount = 0;
  bool _isInitialized = false;

  // Getters
  String get defaultTranslationId => _defaultTranslationId;
  String get defaultTranslationAbbr => _defaultTranslationAbbr;
  String get selectedTranslation => _defaultTranslationAbbr;
  double get readerFontSize => _readerFontSize;
  String get readerFontFamily => _readerFontFamily;
  String get audioVoice => _audioVoice;
  double get audioSpeed => _audioSpeed;
  bool get autoScrollAudio => _autoScrollAudio;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  String get ambientSoundscape => _ambientSoundscape;
  String get studyGoal => _studyGoal;
  String get userName => _userName;
  int get streakDays => _streakDays;
  int get memorizedCount => _memorizedCount;
  bool get isInitialized => _isInitialized;

  /// Loads saved preferences from SharedPreferences
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _defaultTranslationId = prefs.getString(_keyDefaultTranslationId) ?? 'kjv';
      _defaultTranslationAbbr = prefs.getString(_keyDefaultTranslationAbbr) ?? 'KJV';
      _readerFontSize = prefs.getDouble(_keyReaderFontSize) ?? 17.0;
      _readerFontFamily = prefs.getString(_keyReaderFontFamily) ?? 'Georgia';
      _audioVoice = prefs.getString(_keyAudioVoice) ?? 'Natural Reverent (US)';
      _audioSpeed = prefs.getDouble(_keyAudioSpeed) ?? 1.0;
      _autoScrollAudio = prefs.getBool(_keyAutoScrollAudio) ?? true;
      _hasCompletedOnboarding = prefs.getBool(_keyHasCompletedOnboarding) ?? false;
      _ambientSoundscape = prefs.getString(_keyAmbientSoundscape) ?? 'none';
      _studyGoal = prefs.getString(_keyStudyGoal) ?? 'original_languages';
      _userName = prefs.getString(_keyUserName) ?? '';
    } catch (_) {}
    _isInitialized = true;
    notifyListeners();
  }

  /// Sets default Bible translation across reader and study views
  Future<void> setDefaultTranslation(String id, String abbr) async {
    _defaultTranslationId = id;
    _defaultTranslationAbbr = abbr;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDefaultTranslationId, id);
      await prefs.setString(_keyDefaultTranslationAbbr, abbr);
    } catch (_) {}
  }

  /// Sets reader font size (e.g. 15.0 to 24.0)
  Future<void> setReaderFontSize(double size) async {
    _readerFontSize = size;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyReaderFontSize, size);
    } catch (_) {}
  }

  /// Sets reading font family ('Georgia', 'Palatino', 'Times New Roman', 'Modern Sans')
  Future<void> setReaderFontFamily(String family) async {
    _readerFontFamily = family;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyReaderFontFamily, family);
    } catch (_) {}
  }

  /// Sets audio narration voice persona
  Future<void> setAudioVoice(String voice) async {
    _audioVoice = voice;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAudioVoice, voice);
    } catch (_) {}
  }

  /// Sets default audio narration playback speed
  Future<void> setAudioSpeed(double speed) async {
    _audioSpeed = speed;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyAudioSpeed, speed);
    } catch (_) {}
  }

  /// Toggles automatic verse scrolling during audio playback
  Future<void> setAutoScrollAudio(bool value) async {
    _autoScrollAudio = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAutoScrollAudio, value);
    } catch (_) {}
  }

  /// Sets whether the initial welcome onboarding flow was completed
  Future<void> setCompletedOnboarding(bool value) async {
    _hasCompletedOnboarding = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHasCompletedOnboarding, value);
    } catch (_) {}
  }

  /// Alias for setCompletedOnboarding
  Future<void> setHasCompletedOnboarding(bool value) => setCompletedOnboarding(value);

  /// Sets translation by abbreviation or ID
  Future<void> setTranslation(String abbrOrId) async {
    final lower = abbrOrId.toLowerCase();
    final upper = abbrOrId.toUpperCase();
    await setDefaultTranslation(lower, upper);
  }

  /// Sets active ambient background soundscape ('none', 'rain', 'library')
  Future<void> setAmbientSoundscape(String soundscape) async {
    _ambientSoundscape = soundscape;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAmbientSoundscape, soundscape);
    } catch (_) {}
  }

  /// Sets custom profile/user name
  Future<void> setUserName(String name) async {
    _userName = name.trim();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserName, _userName);
    } catch (_) {}
  }

  /// Sets primary theological study focus
  Future<void> setStudyGoal(String goal) async {
    _studyGoal = goal;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyStudyGoal, goal);
    } catch (_) {}
  }

  /// Updates cached dynamic stats from API responses
  void updateStats({int? streak, int? memorized}) {
    bool changed = false;
    if (streak != null && streak != _streakDays) {
      _streakDays = streak;
      changed = true;
    }
    if (memorized != null && memorized != _memorizedCount) {
      _memorizedCount = memorized;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }
}
