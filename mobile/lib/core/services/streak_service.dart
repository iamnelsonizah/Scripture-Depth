import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';

class StreakService {
  static final StreakService _instance = StreakService._internal();
  factory StreakService() => _instance;
  StreakService._internal();

  ApiClient? _apiClient;
  void init(ApiClient client) {
    _apiClient = client;
  }

  static const String _keyLastDate = 'streak_last_study_date';
  static const String _keyCurrentStreak = 'streak_current_count';
  static const String _keyLongestStreak = 'streak_longest_count';
  static const String _keyTotalChapters = 'streak_total_chapters';
  static const String _keyTotalCards = 'streak_total_cards';

  final ValueNotifier<int> currentStreak = ValueNotifier<int>(4);
  final ValueNotifier<int> longestStreak = ValueNotifier<int>(21);
  final ValueNotifier<bool> studiedToday = ValueNotifier<bool>(true);

  Future<void> loadLocalStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastDateStr = prefs.getString(_keyLastDate);
      final todayStr = _formatDate(DateTime.now());
      final yesterdayStr = _formatDate(DateTime.now().subtract(const Duration(days: 1)));

      int streak = prefs.getInt(_keyCurrentStreak) ?? 4;
      int longest = prefs.getInt(_keyLongestStreak) ?? 21;

      if (lastDateStr == todayStr) {
        studiedToday.value = true;
      } else if (lastDateStr == yesterdayStr) {
        studiedToday.value = false;
      } else if (lastDateStr != null) {
        // Missed yesterday - streak reset
        streak = 1;
        studiedToday.value = false;
      }

      currentStreak.value = streak;
      longestStreak.value = longest > streak ? longest : streak;
    } catch (_) {}
  }

  Future<void> recordActivity({int chaptersRead = 0, int cardsReviewed = 0}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = _formatDate(DateTime.now());
      final lastDateStr = prefs.getString(_keyLastDate);
      final yesterdayStr = _formatDate(DateTime.now().subtract(const Duration(days: 1)));

      int streak = prefs.getInt(_keyCurrentStreak) ?? 4;
      int longest = prefs.getInt(_keyLongestStreak) ?? 21;
      int totalChap = (prefs.getInt(_keyTotalChapters) ?? 14) + chaptersRead;
      int totalCard = (prefs.getInt(_keyTotalCards) ?? 28) + cardsReviewed;

      if (lastDateStr != todayStr) {
        if (lastDateStr == yesterdayStr) {
          streak += 1;
        } else {
          streak = 1;
        }
        if (streak > longest) longest = streak;

        await prefs.setString(_keyLastDate, todayStr);
        await prefs.setInt(_keyCurrentStreak, streak);
        await prefs.setInt(_keyLongestStreak, longest);
      }

      await prefs.setInt(_keyTotalChapters, totalChap);
      await prefs.setInt(_keyTotalCards, totalCard);

      currentStreak.value = streak;
      longestStreak.value = longest;
      studiedToday.value = true;

      // Sync with backend API
      if (_apiClient != null) {
        await _apiClient!.recordStudyActivity(
          chaptersRead: chaptersRead,
          cardsReviewed: cardsReviewed,
        );
      }
    } catch (_) {}
  }

  String _formatDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
