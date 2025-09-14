import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class HistoryItem {
  final String url;
  final String title;
  final DateTime visitTime;
  final String? favicon;

  HistoryItem({
    required this.url,
    required this.title,
    required this.visitTime,
    this.favicon,
  });

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'title': title,
      'visitTime': visitTime.millisecondsSinceEpoch,
      'favicon': favicon,
    };
  }

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      url: json['url'] ?? '',
      title: json['title'] ?? 'Untitled',
      visitTime: DateTime.fromMillisecondsSinceEpoch(json['visitTime'] ?? 0),
      favicon: json['favicon'],
    );
  }
}

class HistoryService {
  static const String _historyKey = 'browsing_history';
  static const int _maxHistoryItems = 100;

  static Future<void> addToHistory({
    required String url,
    required String title,
    String? favicon,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyItems = await getHistory();

      // Remove duplicate if exists (same URL)
      historyItems.removeWhere((item) => item.url == url);

      // Add new item at the beginning
      historyItems.insert(
        0,
        HistoryItem(
          url: url,
          title: title,
          visitTime: DateTime.now(),
          favicon: favicon,
        ),
      );

      // Keep only the latest items (limit to max)
      if (historyItems.length > _maxHistoryItems) {
        historyItems.removeRange(_maxHistoryItems, historyItems.length);
      }

      // Save to SharedPreferences
      final jsonList = historyItems.map((item) => item.toJson()).toList();
      await prefs.setString(_historyKey, json.encode(jsonList));
    } catch (e) {
      print('Error saving to history: $e');
    }
  }

  static Future<List<HistoryItem>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyString = prefs.getString(_historyKey);

      if (historyString == null) return [];

      final jsonList = json.decode(historyString) as List;
      return jsonList
          .map((json) => HistoryItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading history: $e');
      return [];
    }
  }

  static Future<List<HistoryItem>> searchHistory(String query) async {
    final history = await getHistory();
    if (query.isEmpty) return history;

    return history
        .where((item) =>
            item.title.toLowerCase().contains(query.toLowerCase()) ||
            item.url.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  static Future<void> removeFromHistory(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyItems = await getHistory();

      historyItems.removeWhere((item) => item.url == url);

      final jsonList = historyItems.map((item) => item.toJson()).toList();
      await prefs.setString(_historyKey, json.encode(jsonList));
    } catch (e) {
      print('Error removing from history: $e');
    }
  }

  static Future<void> clearAllHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
    } catch (e) {
      print('Error clearing history: $e');
    }
  }

  static Future<List<HistoryItem>> getTodaysHistory() async {
    final history = await getHistory();
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    return history
        .where((item) => item.visitTime.isAfter(startOfDay))
        .toList();
  }

  static Future<List<HistoryItem>> getRecentHistory({int limit = 10}) async {
    final history = await getHistory();
    return history.take(limit).toList();
  }

  static Future<int> getHistoryCount() async {
    final history = await getHistory();
    return history.length;
  }

  static Future<Map<String, int>> getHistoryStats() async {
    final history = await getHistory();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisWeek = today.subtract(const Duration(days: 7));
    final thisMonth = DateTime(now.year, now.month, 1);

    int todayCount = 0;
    int weekCount = 0;
    int monthCount = 0;

    for (final item in history) {
      if (item.visitTime.isAfter(today)) {
        todayCount++;
      }
      if (item.visitTime.isAfter(thisWeek)) {
        weekCount++;
      }
      if (item.visitTime.isAfter(thisMonth)) {
        monthCount++;
      }
    }

    return {
      'total': history.length,
      'today': todayCount,
      'week': weekCount,
      'month': monthCount,
    };
  }
}