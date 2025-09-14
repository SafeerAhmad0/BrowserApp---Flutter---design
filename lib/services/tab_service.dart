import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class TabData {
  final String id;
  final String url;
  final String title;
  final DateTime createdAt;
  final DateTime lastVisited;

  TabData({
    required this.id,
    required this.url,
    required this.title,
    required this.createdAt,
    required this.lastVisited,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'title': title,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastVisited': lastVisited.millisecondsSinceEpoch,
    };
  }

  factory TabData.fromJson(Map<String, dynamic> json) {
    return TabData(
      id: json['id'] ?? '',
      url: json['url'] ?? '',
      title: json['title'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] ?? 0),
      lastVisited: DateTime.fromMillisecondsSinceEpoch(json['lastVisited'] ?? 0),
    );
  }

  TabData copyWith({
    String? url,
    String? title,
    DateTime? lastVisited,
  }) {
    return TabData(
      id: id,
      url: url ?? this.url,
      title: title ?? this.title,
      createdAt: createdAt,
      lastVisited: lastVisited ?? this.lastVisited,
    );
  }
}

class TabService {
  static const String _tabsKey = 'browser_tabs';
  static const String _activeTabKey = 'active_tab_id';

  static Future<List<TabData>> getAllTabs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tabsJson = prefs.getString(_tabsKey);

      if (tabsJson == null || tabsJson.isEmpty) {
        return [];
      }

      final List<dynamic> tabsList = json.decode(tabsJson);
      return tabsList.map((json) => TabData.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error loading tabs: $e');
      return [];
    }
  }

  static Future<void> createNewTab(String url, String title) async {
    try {
      final tabs = await getAllTabs();
      final newTab = TabData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        url: url,
        title: title,
        createdAt: DateTime.now(),
        lastVisited: DateTime.now(),
      );

      tabs.add(newTab);
      await _saveTabs(tabs);
      await setActiveTab(newTab.id);
    } catch (e) {
      print('Error creating new tab: $e');
    }
  }

  static Future<void> updateTab(String tabId, {String? url, String? title}) async {
    try {
      final tabs = await getAllTabs();
      final tabIndex = tabs.indexWhere((tab) => tab.id == tabId);

      if (tabIndex != -1) {
        tabs[tabIndex] = tabs[tabIndex].copyWith(
          url: url,
          title: title,
          lastVisited: DateTime.now(),
        );
        await _saveTabs(tabs);
      }
    } catch (e) {
      print('Error updating tab: $e');
    }
  }

  static Future<void> closeTab(String tabId) async {
    try {
      final tabs = await getAllTabs();
      tabs.removeWhere((tab) => tab.id == tabId);
      await _saveTabs(tabs);

      // If the closed tab was active, set a new active tab
      final activeTabId = await getActiveTabId();
      if (activeTabId == tabId && tabs.isNotEmpty) {
        await setActiveTab(tabs.first.id);
      } else if (tabs.isEmpty) {
        await setActiveTab('');
      }
    } catch (e) {
      print('Error closing tab: $e');
    }
  }

  static Future<void> clearAllTabs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tabsKey);
      await prefs.remove(_activeTabKey);
    } catch (e) {
      print('Error clearing all tabs: $e');
    }
  }

  static Future<String?> getActiveTabId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_activeTabKey);
    } catch (e) {
      print('Error getting active tab ID: $e');
      return null;
    }
  }

  static Future<void> setActiveTab(String tabId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeTabKey, tabId);
    } catch (e) {
      print('Error setting active tab: $e');
    }
  }

  static Future<TabData?> getActiveTab() async {
    try {
      final activeTabId = await getActiveTabId();
      if (activeTabId == null || activeTabId.isEmpty) {
        return null;
      }

      final tabs = await getAllTabs();
      return tabs.firstWhere(
        (tab) => tab.id == activeTabId,
        orElse: () => tabs.isNotEmpty ? tabs.first : throw Exception('No tabs available'),
      );
    } catch (e) {
      print('Error getting active tab: $e');
      return null;
    }
  }

  static Future<void> _saveTabs(List<TabData> tabs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tabsJson = json.encode(tabs.map((tab) => tab.toJson()).toList());
      await prefs.setString(_tabsKey, tabsJson);
    } catch (e) {
      print('Error saving tabs: $e');
    }
  }

  static Future<int> getTabCount() async {
    final tabs = await getAllTabs();
    return tabs.length;
  }
}