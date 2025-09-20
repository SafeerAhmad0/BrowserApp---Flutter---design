import 'package:flutter/material.dart';
import '../notifications/notifications_screen.dart';
import '../admin/admin_panel.dart';
import '../../services/auth_service.dart';
import '../../services/language_service.dart';
import '../../components/auth_dialog.dart';
import '../../components/language_dialog.dart';
import 'browsing_history_screen.dart';
import '../webview/web_view_screen.dart';
import '../../services/history_service.dart';
import '../../services/tab_service.dart';
import '../tabs/tab_manager_screen.dart';
import '../../models/tab.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  bool _isAdmin = false;
  bool _isLoggedIn = false;
  String _currentLanguage = 'English';
  int _historyCount = 0;
  List<HistoryItem> _recentHistory = [];
  int _tabCount = 0;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
    _loadCurrentLanguage();
    _loadHistory();
    _loadTabCount();
  }

  void _loadCurrentLanguage() {
    final langCode = LanguageService.currentLanguage;
    final langNames = LanguageService.supportedLanguages;
    setState(() {
      _currentLanguage = langNames[langCode] ?? 'English';
    });
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => const LanguageDialog(),
    ).then((_) {
      _loadCurrentLanguage();
      // Trigger a rebuild of the entire app
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  void _checkAuthState() {
    final user = _authService.currentUser;
    setState(() {
      _isLoggedIn = user != null;
      _isAdmin = _authService.isAdmin(user);
    });
  }

  void _showLoginDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const AuthDialog(),
    ).then((_) => _checkAuthState());
  }

  Future<void> _loadHistory() async {
    try {
      final history = await HistoryService.getHistory();
      if (mounted) {
        setState(() {
          _historyCount = history.length;
          _recentHistory = history.take(3).toList();
        });
      }
    } catch (e) {
      print('Error loading history: $e');
    }
  }

  Future<void> _clearAllHistory() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Clear All History?'),
          ],
        ),
        content: const Text(
          'This will permanently delete all your browsing history. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await HistoryService.clearAllHistory();
              _loadHistory();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ All browsing history cleared'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _showFullHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BrowsingHistoryScreen(),
      ),
    ).then((_) => _loadHistory());
  }

  Future<void> _loadTabCount() async {
    try {
      final count = await TabService.getTabCount();
      if (mounted) {
        setState(() {
          _tabCount = count;
        });
      }
    } catch (e) {
      print('Error loading tab count: $e');
    }
  }

  Future<void> _clearAllTabs() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Close All Tabs?'),
          ],
        ),
        content: const Text(
          'This will close all open tabs. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await TabService.clearAllTabs();
              _loadTabCount();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ All tabs closed'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Close All'),
          ),
        ],
      ),
    );
  }

  void _showTabManager() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TabManagerScreen(
          tabs: const <BrowserTab>[], // Empty tabs list for settings screen
          onTabSelected: (index) {
            // Handle tab selection if needed
          },
          onTabClosed: (index) {
            // Handle tab closure if needed
          },
          onNewTab: () {
            // Handle new tab creation if needed
          },
        ),
      ),
    ).then((_) => _loadTabCount());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          LanguageService.translate('settings'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF87CEEB), Color(0xFF2196F3)],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF0F8FF),
              Color(0xFFE6F3FF),
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
          // Language Selection Section
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: ListTile(
              leading: const Icon(Icons.language, color: Color(0xFF2196F3)),
              title: Text(
                LanguageService.translate('language'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Current: $_currentLanguage',
                style: TextStyle(color: Colors.grey[600]),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _showLanguageDialog,
            ),
          ),

          const SizedBox(height: 16),
          if (!_isLoggedIn)
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('Sign In / Sign Up'),
              subtitle: const Text('Access your account'),
              onTap: _showLoginDialog,
            ),
          if (_isLoggedIn) ...[
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Notifications'),
              subtitle: const Text('View your notifications'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsScreen(),
                  ),
                );
              },
            ),
            if (_isAdmin)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: const Text('Admin Panel'),
                subtitle: const Text('Manage application settings'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminPanel(),
                    ),
                  );
                },
              ),
            if (_isAdmin)
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign Out'),
                onTap: () async {
                  await _authService.signOut();
                  _checkAuthState();
                },
              ),
          ],

          const SizedBox(height: 16),

          // Browsing Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Browsing',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Tab Manager
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: ListTile(
              leading: const Icon(Icons.tab, color: Color(0xFF2196F3)),
              title: const Text(
                'Tab Manager',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '$_tabCount open tabs',
                style: TextStyle(color: Colors.grey[600]),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_tabCount > 0)
                    IconButton(
                      onPressed: _clearAllTabs,
                      icon: const Icon(Icons.clear_all, color: Colors.red, size: 20),
                      tooltip: 'Close All Tabs',
                    ),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
              onTap: _showTabManager,
            ),
          ),

          // Privacy Section
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Privacy',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Browsing History
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.history, color: Color(0xFF2196F3)),
                  title: const Text(
                    'Browsing History',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '$_historyCount sites visited',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _clearAllHistory,
                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                        tooltip: 'Clear All History',
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  ),
                  onTap: _showFullHistory,
                ),
                if (_recentHistory.isNotEmpty) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...(_recentHistory.take(3).map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => WebViewScreen(
                                        url: item.url,
                                        title: item.title,
                                      ),
                                    ),
                                  );
                                },
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.language,
                                      size: 16,
                                      color: Colors.grey[500],
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF1976D2),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )).toList()),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // General Section
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'General',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 8),

          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: ListTile(
              leading: const Icon(Icons.history, color: Color(0xFF2196F3)),
              title: const Text(
                'Notification History',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'View past notifications',
                style: TextStyle(color: Colors.grey[600]),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsScreen(),
                  ),
                );
              },
            ),
          ),
          ],
        ),
      ),
    );
  }
}