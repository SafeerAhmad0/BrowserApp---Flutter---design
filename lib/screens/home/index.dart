import 'package:flutter/material.dart';
import '../../components/search_bar.dart' as custom;
import '../../components/top_search_bar.dart';
import '../../services/news_service.dart';
import '../news/all_news_screen.dart';
import '../news/news_detail_screen.dart';
import '../notifications/notifications_screen.dart';
import '../webview/web_view_screen.dart';
import '../admin/new_admin_panel.dart';
import '../../components/auth_dialog.dart';
import '../../services/auth_service.dart';
import '../../services/language_service.dart';
import '../../services/language_preference_service.dart';
import '../../services/translation_service.dart';
import '../settings/settings_screen.dart';
import '../settings/browsing_history_screen.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../services/ad_block_service.dart';
import '../../services/ad_overlay_service.dart';
import '../../services/consolidated_ad_service.dart';
import '../../services/history_service.dart';
import '../tabs/tab_manager_screen.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/tab.dart';
import '../../components/native_ad_widget.dart';
import '../../components/banner_ad_widget.dart';
import '../../components/admin_card_widget.dart';
import '../../services/admin_card_service.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}


class _HomeScreenState extends State<HomeScreen> {
  List<NewsArticle> _newsArticles = [];
  bool _isLoadingNews = true;
  bool _isLoadingMoreNews = false;
  bool _isTranslating = false;
  String _translationStatus = '';
  bool _isAdmin = false;
  final AuthService _authService = AuthService();
  final List<BrowserTab> _tabs = [];
  int _activeTabIndex = 0;
  WebViewController? _currentController;
  bool _isOnHomePage = true;
  String _currentUrl = '';
  String _pageTitle = 'BlueX';
  bool _isSearchFocused = false;
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  final GlobalKey<TopSearchBarState> _searchBarKey = GlobalKey<TopSearchBarState>();
  bool _isDesktopMode = false;
  NewsLanguage _currentTranslationLanguage = NewsLanguage.english;

  @override
  void initState() {
    super.initState();
    _initializeLanguageService();
    _loadNews();
    _loadAdminCards();
    _checkAdminStatus();
    _setupScrollListener();

    // Listen to auth state changes to update admin status
    _authService.authStateChanges.listen((user) {
      _checkAdminStatus();
    });

    // Removed automatic notifications slideshow popup
  }

  Future<void> _initializeLanguageService() async {
    await LanguagePreferenceService.loadLanguagePreference();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    AdOverlayService.dispose();
    super.dispose();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        // Load more news when user is 200 pixels from the bottom
        if (!_isLoadingMoreNews) {
          _loadMoreNews();
        }
      }
    });
  }

  Future<void> _checkAdminStatus() async {
    final user = _authService.currentUser;
    final wasAdmin = _isAdmin;
    final isAdminNow = _authService.isAdmin(user);

    setState(() {
      _isAdmin = isAdminNow;
    });

  }

  Future<void> _loadAdminCards() async {
    try {
      await AdminCardService.loadAdminCards();
    } catch (e) {
    }
  }

  Future<void> _loadNews() async {
    if (!mounted) return;

    setState(() {
      _isLoadingNews = true;
      _isTranslating = false;
      _translationStatus = '';
    });

    try {
      final targetLanguage = LanguagePreferenceService.currentLanguage;

      if (targetLanguage != NewsLanguage.english) {
        setState(() {
          _isTranslating = true;
          _translationStatus = 'Loading news for translation...';
        });
      }

      // Use the new translated news service
      final articles = await NewsService.getTranslatedTopHeadlines();

      if (mounted) {
        setState(() {
          _newsArticles = articles;
          _isLoadingNews = false;
          _isTranslating = false;
          _translationStatus = '';
          _currentPage = 1;
        });

        // Show success message if translated
        if (targetLanguage != NewsLanguage.english && articles.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ News translated to ${targetLanguage.displayName}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingNews = false;
          _isTranslating = false;
          _translationStatus = '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to load news: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _loadMoreNews() async {
    if (_isLoadingMoreNews) return;

    setState(() {
      _isLoadingMoreNews = true;
    });

    try {
      final targetLanguage = LanguagePreferenceService.currentLanguage;

      // Get more English news from different categories
      List<NewsArticle> englishArticles = [];

      switch (_currentPage % 6) {
        case 1:
          englishArticles = await NewsService.getTechNews();
          break;
        case 2:
          englishArticles = await NewsService.getBusinessNews();
          break;
        case 3:
          englishArticles = await NewsService.getSportsNews();
          break;
        case 4:
          englishArticles = await NewsService.getHealthNews();
          break;
        case 5:
          englishArticles = await NewsService.getScienceNews();
          break;
        case 0:
          englishArticles = await NewsService.getEntertainmentNews();
          break;
      }

      // Translate if needed
      List<NewsArticle> finalArticles = [];
      if (targetLanguage == NewsLanguage.english) {
        finalArticles = englishArticles;
      } else {
        // Translate each article
        for (final article in englishArticles) {
          final translated = await article.translateTo(targetLanguage);
          finalArticles.add(translated);
        }
      }

      if (mounted) {
        setState(() {
          _newsArticles.addAll(finalArticles);
          _currentPage++;
          _isLoadingMoreNews = false;
        });

        // Show success message if translated
        if (targetLanguage != NewsLanguage.english && finalArticles.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${finalArticles.length} more articles translated to ${targetLanguage.displayName}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMoreNews = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to load more news: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _openSettings() {
    // Refresh admin status before showing settings
    _checkAdminStatus();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Show current user info if logged in
            if (_authService.currentUser != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: _isAdmin ? Colors.orange.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isAdmin ? Colors.orange.shade200 : Colors.blue.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isAdmin ? Icons.admin_panel_settings : Icons.person,
                      color: _isAdmin ? Colors.orange : Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isAdmin ? 'Admin Account' : 'User Account',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _isAdmin ? Colors.orange.shade800 : Colors.blue.shade800,
                            ),
                          ),
                          Text(
                            _authService.currentUser?.email ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _authService.signOut();
                        _checkAdminStatus();
                      },
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              ),
            
            // Sign in option if not logged in
            if (_authService.currentUser == null)
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Sign In / Sign Up'),
                subtitle: const Text('Access your account'),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (context) => const AuthDialog(),
                  ).then((_) {
                    _checkAdminStatus();
                  });
                },
              ),
            
            // Admin panel option if admin
            if (_isAdmin)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: Colors.orange),
                title: const Text('Admin Panel'),
                subtitle: const Text('Manage app content'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NewAdminPanel(),
                    ),
                  );
                },
              ),
            
            // Notifications
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Notifications'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showNotificationsSlideshow() async {
    try {
      final db = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://test-51a88-default-rtdb.firebaseio.com',
      );
      final ref = db.ref('notifications');
      final snapshot = await ref.get();

      final List<Map<String, dynamic>> items = [];
      if (snapshot.exists && snapshot.value is Map) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            items.add(Map<String, dynamic>.from(value as Map));
          }
        });
        items.sort((a, b) => ((b['sentAt'] ?? 0) as int).compareTo((a['sentAt'] ?? 0) as int));
        if (items.length > 10) {
          items.removeRange(10, items.length);
        }
      }

      if (!mounted || items.isEmpty) return;

      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) {
          final pageController = PageController();
          int currentIndex = 0;
          return StatefulBuilder(
            builder: (context, setState) {
              return Dialog(
                backgroundColor: Colors.transparent,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                              ),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            width: double.infinity,
                            child: const Text(
                              'Latest Announcements',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: PageView.builder(
                              controller: pageController,
                              itemCount: items.length,
                              onPageChanged: (i) => setState(() => currentIndex = i),
                              itemBuilder: (context, index) {
                                final n = items[index];
                                final String title = (n['title'] ?? '') as String;
                                final String body = (n['body'] ?? '') as String;
                                final String? imageUrl = n['imageUrl'] as String?;
                                final String? actionUrl = n['actionUrl'] as String?;
                                return SingleChildScrollView(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (imageUrl != null && imageUrl.isNotEmpty)
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: SizedBox(
                                            height: 180,
                                            width: double.infinity,
                                            child: CachedNetworkImage(
                                              imageUrl: imageUrl,
                                              fit: BoxFit.cover,
                                              placeholder: (c, _) => Container(
                                                color: Colors.grey[100],
                                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF667eea))),
                                              ),
                                              errorWidget: (c, u, e) => Container(
                                                color: Colors.grey[100],
                                                child: const Center(child: Icon(Icons.image_not_supported, color: Colors.grey)),
                                              ),
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 12),
                                      Text(
                                        title,
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        body,
                                        style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.4),
                                      ),
                                      if (actionUrl != null && actionUrl.isNotEmpty)
                                        Container(
                                          margin: const EdgeInsets.only(top: 12),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF667eea).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.touch_app, size: 16, color: Color(0xFF667eea)),
                                              SizedBox(width: 6),
                                              Text('Tap from Notifications page', style: TextStyle(fontSize: 12, color: Color(0xFF667eea), fontWeight: FontWeight.w600)),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Dots indicator
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(items.length, (i) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 10),
                              width: i == currentIndex ? 10 : 6,
                              height: i == currentIndex ? 10 : 6,
                              decoration: BoxDecoration(
                                color: i == currentIndex ? const Color(0xFF667eea) : Colors.grey[400],
                                shape: BoxShape.circle,
                              ),
                            )),
                          ),
                        ],
                      ),

                      // Close button
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Material(
                          color: Colors.black.withOpacity(0.15),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.pop(context),
                            child: const Padding(
                              padding: EdgeInsets.all(6.0),
                              child: Icon(Icons.close, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      // silent fail to avoid blocking app open
    }
  }

  void _addNewTab(String url) {
    late WebViewController tabController;

    tabController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            return AdBlockService.handleNavigation(request);
          },
          onPageStarted: (String tabUrl) {
            setState(() {
              _isOnHomePage = false;
              _currentUrl = tabUrl;
            });
          },
          onPageFinished: (String tabUrl) async {
            // Use consolidated ad service for all ad injection
            await ConsolidatedAdService.processPageLoad(tabController, tabUrl);
            String? title = await tabController.getTitle();

            // Add to browsing history
            try {
              await HistoryService.addToHistory(
                url: tabUrl,
                title: title ?? 'Untitled',
              );
            } catch (e) {
            }

            setState(() {
              _currentUrl = tabUrl;
              _pageTitle = title ?? 'Untitled';
              if (_tabs.isNotEmpty && _activeTabIndex < _tabs.length) {
                _tabs[_activeTabIndex] = _tabs[_activeTabIndex].copyWith(
                  title: _pageTitle,
                  url: tabUrl,
                );
              }
            });

            // Debug info
          },
          onWebResourceError: (WebResourceError error) {
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    setState(() {
      _tabs.add(BrowserTab(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Loading...',
        url: url,
        controller: tabController,
      ));
      _activeTabIndex = _tabs.length - 1;
      _currentController = tabController;
      _isOnHomePage = false;
      _currentUrl = url;
    });
  }

  void _goHome() {
    setState(() {
      _isOnHomePage = true;
      _pageTitle = 'BlueX';
      _currentUrl = '';
    });
  }

  void _clearSearchBar() {
    _searchBarKey.currentState?.clearText();
  }

  String _formatUrl(String url) {
    // Remove https:// and www. for cleaner display
    String formatted = url;
    if (formatted.startsWith('https://')) {
      formatted = formatted.substring(8);
    } else if (formatted.startsWith('http://')) {
      formatted = formatted.substring(7);
    }
    if (formatted.startsWith('www.')) {
      formatted = formatted.substring(4);
    }
    return formatted;
  }

  void _toggleDesktopMode() async {
    setState(() {
      _isDesktopMode = !_isDesktopMode;
    });

    if (_currentController != null) {
      try {
        // Set user agent based on desktop mode
        final newUserAgent = _isDesktopMode
            ? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
            : 'Mozilla/5.0 (Linux; Android 10; SM-A325F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

        await _currentController!.setUserAgent(newUserAgent);
        await _currentController!.reload();

        // Show feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isDesktopMode ? '🖥️ Switched to Desktop Mode' : '📱 Switched to Mobile Mode',
              ),
              duration: const Duration(seconds: 2),
              backgroundColor: const Color(0xFF2196F3),
            ),
          );
        }
      } catch (e) {
        // Revert the state if failed
        if (mounted) {
          setState(() {
            _isDesktopMode = !_isDesktopMode;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Failed to switch mode'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showClearHistoryDialog() {
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

  void _clearCache() {
    if (_currentController != null) {
      _currentController!.clearCache();
      _currentController!.clearLocalStorage();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Cache and local storage cleared!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ No active page to clear cache'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showTabManager() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TabManagerScreen(
          tabs: _tabs,
          onTabSelected: (index) {
            // Close tab manager and switch to selected tab
            Navigator.pop(context);
            setState(() {
              _activeTabIndex = index;
              _currentController = _tabs[index].controller;
              _currentUrl = _tabs[index].url;
              _pageTitle = _tabs[index].title;
              _isOnHomePage = false;
            });
          },
          onTabClosed: (index) {
            // Keep tab manager open, just update the tabs
            setState(() {
              if (_tabs.length > 1) {
                _tabs.removeAt(index);
                if (_activeTabIndex >= _tabs.length) {
                  _activeTabIndex = _tabs.length - 1;
                }
                if (_activeTabIndex >= 0) {
                  _currentController = _tabs[_activeTabIndex].controller;
                  _currentUrl = _tabs[_activeTabIndex].url;
                  _pageTitle = _tabs[_activeTabIndex].title;
                }
              } else {
                _tabs.clear();
                _currentController = null;
                _isOnHomePage = true;
                _pageTitle = 'BlueX';
                _currentUrl = '';
              }
            });
          },
          onNewTab: () {
            _addNewTab('https://www.google.com');
          },
        ),
      ),
    );
  }

  void _translatePage(NewsLanguage targetLanguage) async {
    if (!_isOnHomePage && _currentController != null) {
      // WebView translation
      if (targetLanguage == NewsLanguage.english) {
        // REMOVED - All JavaScript injection consolidated to central service
        setState(() => _currentTranslationLanguage = NewsLanguage.english);
        return;
      }

      setState(() => _currentTranslationLanguage = targetLanguage);

      try {
        // REMOVED - All JavaScript injection consolidated to central service

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🌍 Translating page to ${targetLanguage.displayName}...'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF2196F3),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('❌ Translation failed. Please try again.'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _currentTranslationLanguage = NewsLanguage.english);
      }
    } else {
      // Home page - just change news language
      setState(() => _currentTranslationLanguage = targetLanguage);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🌍 News language set to ${targetLanguage.displayName}'),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF2196F3),
        ),
      );
    }
  }

  void _showTranslateMenu() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.translate, color: Color(0xFF2196F3)),
              const SizedBox(width: 8),
              Text(_isOnHomePage ? 'News Language' : 'Translate Page'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_isOnHomePage
                  ? 'Choose language for news content:'
                  : 'Choose a language to translate this page:'),
              const SizedBox(height: 16),
              ...NewsLanguage.values.map((language) => Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: language == _currentTranslationLanguage
                      ? const Color(0xFF2196F3).withOpacity(0.1)
                      : null,
                ),
                child: ListTile(
                  leading: Icon(
                    language == _currentTranslationLanguage
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: language == _currentTranslationLanguage
                        ? const Color(0xFF2196F3)
                        : Colors.grey,
                  ),
                  title: Text(  
                    language.displayName,
                    style: TextStyle(
                      fontWeight: language == _currentTranslationLanguage
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _translatePage(language);
                  },
                ),
              )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showSettingsMenu() {
    // Refresh admin status before showing menu
    _checkAdminStatus();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Translate option
            ListTile(
              leading: Icon(
                Icons.translate,
                color: _currentTranslationLanguage != NewsLanguage.english
                  ? const Color(0xFF2196F3)
                  : Colors.grey,
              ),
              title: Text(
                _currentTranslationLanguage == NewsLanguage.english
                    ? 'Translate Page'
                    : 'Translate: ${_currentTranslationLanguage.displayName}',
              ),
              trailing: _currentTranslationLanguage != NewsLanguage.english
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'ON',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                _showTranslateMenu();
              },
            ),

            // Desktop Mode (only show when browsing)
            if (!_isOnHomePage)
              ListTile(
                leading: Icon(
                  _isDesktopMode ? Icons.desktop_windows : Icons.phone_android,
                  color: const Color(0xFF2196F3),
                ),
                title: const Text('Desktop Mode'),
                trailing: Switch(
                  value: _isDesktopMode,
                  onChanged: (value) {
                    Navigator.pop(context);
                    _toggleDesktopMode();
                  },
                ),
              ),

            // Ad Block toggle
            ListTile(
              leading: Icon(
                AdBlockService.isEnabled ? Icons.shield : Icons.shield_outlined,
                color: AdBlockService.isEnabled ? Colors.green : Colors.grey,
              ),
              title: const Text('Ad Block'),
              trailing: Switch(
                value: AdBlockService.isEnabled,
                onChanged: (value) {
                  setState(() {
                    AdBlockService.setEnabled(value);
                    AdOverlayService.setAdBlockEnabled(value);
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        value ? 'Ad Block enabled' : 'Ad Block disabled',
                      ),
                      backgroundColor: value ? Colors.green : Colors.orange,
                    ),
                  );
                },
              ),
            ),

            // Ad Block Settings
            ListTile(
              leading: const Icon(Icons.settings, color: Color(0xFF2196F3)),
              title: const Text('Ad Block Settings'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to ad block settings
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ad Block settings coming soon!')),
                );
              },
            ),

            // View History
            ListTile(
              leading: const Icon(Icons.history, color: Color(0xFF2196F3)),
              title: const Text('View Browsing History'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BrowsingHistoryScreen(),
                  ),
                ).then((_) {
                });
              },
            ),

            // Clear History
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Clear History'),
              onTap: () {
                Navigator.pop(context);
                _showClearHistoryDialog();
              },
            ),

            // Login/Signup
            ListTile(
              leading: const Icon(Icons.login, color: Color(0xFF2196F3)),
              title: const Text('Login / Signup'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  barrierDismissible: true,
                  builder: (context) => const AuthDialog(),
                ).then((_) {
                  // Refresh admin status after auth dialog closes
                  _checkAdminStatus();
                });
              },
            ),

            // Admin panel option if admin (THREE-DOT MENU)
            if (_isAdmin)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: Colors.orange),
                title: const Text('Admin Panel'),
                subtitle: const Text('Manage app content & notifications'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NewAdminPanel(),
                    ),
                  );
                },
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            // Home button
            IconButton(
              icon: const Icon(Icons.home, color: Colors.white, size: 24),
              onPressed: _goHome,
              tooltip: 'Home',
            ),

            // Current URL/Search bar display
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                child: _isOnHomePage
                  ? TopSearchBar(
                      key: _searchBarKey,
                      hintText: 'Search Google or type a URL',
                      onFocusChanged: (hasFocus) {
                        setState(() {
                          _isSearchFocused = hasFocus;
                        });
                      },
                      onSearch: (query) {
                        String url = query.toLowerCase();
                        if (!url.startsWith('http://') && !url.startsWith('https://')) {
                          if (Uri.tryParse(url)?.hasScheme ?? false) {
                            url = 'https://$url';
                          } else {
                            url = 'https://www.google.com/search?q=${Uri.encodeComponent(query)}';
                          }
                        }
                        _addNewTab(url);
                      },
                    )
                  : Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 12),
                            child: Icon(Icons.language, color: Color(0xFF2196F3), size: 18),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                _currentUrl.isNotEmpty ? _formatUrl(_currentUrl) : 'Loading...',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ),
                    ),
              ),
            ),

            // Dynamic button (Clear Cache on home, New Tab on pages)
            IconButton(
              icon: Icon(
                _isOnHomePage ? Icons.whatshot : Icons.add,
                color: Colors.white,
                size: 24,
              ),
              onPressed: _isOnHomePage ? _clearCache : () {
                _addNewTab('https://www.google.com');
                // Clear search bar when creating new tab
                _clearSearchBar();
              },
              tooltip: _isOnHomePage ? 'Clear Cache' : 'New Tab',
            ),

            // Tabs button
            IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.tab, color: Colors.white, size: 24),
                  if (_tabs.isNotEmpty)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${_tabs.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: _showTabManager,
              tooltip: 'Tabs',
            ),

            // Three-dot menu
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white, size: 24),
              onPressed: _showSettingsMenu,
              tooltip: 'Menu',
            ),
          ],
        ),
      ),
      body: _isOnHomePage ? _buildHomePage() : _buildWebViewPage(),
      bottomNavigationBar: !_isOnHomePage ? _buildBottomNavigationBar() : null,
    );
  }

  Widget _buildHomePage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2196F3),
            Color(0xFF1976D2),
            Colors.white,
          ],
          stops: [0.0, 0.3, 1.0],
        ),
      ),
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // BlueX Header - Blue bold & small, X thin & big
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        offset: Offset(2, 2),
                        blurRadius: 4,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                  children: [
                    TextSpan(
                      text: 'Blue',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    TextSpan(
                      text: 'X',
                      style: TextStyle(
                        fontSize: 68,
                        fontWeight: FontWeight.w200,
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Search Bar right after BlueX logo
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    offset: const Offset(0, 4),
                    blurRadius: 15,
                  ),
                ],
              ),
              child: custom.SearchBar(
                hintText: 'Search Google or type a URL',
                onSearch: (query) {
                  String url = query.toLowerCase();
                  if (!url.startsWith('http://') && !url.startsWith('https://')) {
                    if (Uri.tryParse(url)?.hasScheme ?? false) {
                      url = 'https://$url';
                    } else {
                      url = 'https://www.google.com/search?q=${Uri.encodeComponent(query)}';
                    }
                  }
                  _addNewTab(url);
                },
              ),
            ),

            // Scrollable Quick Access Icons Row with White Background
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    offset: const Offset(0, 4),
                    blurRadius: 15,
                  ),
                ],
              ),
              child: SizedBox(
                height: 90,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildQuickAccessIconWithAsset(
                      'ChatGPT',
                      'assets/svgs/ChatGPT_logo.svg.png',
                      'https://chat.openai.com',
                    ),
                    const SizedBox(width: 16),
                    _buildQuickAccessIconWithAsset(
                      'GrokAI',
                      'assets/svgs/GrokAI.png',
                      'https://groq.com',
                    ),
                    const SizedBox(width: 16),
                    _buildQuickAccessIconWithAsset(
                      'Amazon',
                      'assets/svgs/amazon-logo.png',
                      'https://www.amazon.com',
                    ),
                    const SizedBox(width: 16),
                    _buildQuickAccessIcon(
                      'Daraz',
                      Icons.shopping_cart,
                      Colors.deepOrange,
                      'https://www.daraz.pk',
                    ),
                    const SizedBox(width: 16),
                    _buildQuickAccessIcon(
                      'YouTube',
                      Icons.play_circle,
                      Colors.red,
                      'https://www.youtube.com',
                    ),
                    const SizedBox(width: 16),
                    _buildQuickAccessIcon(
                      'Facebook',
                      Icons.facebook,
                      Colors.blue,
                      'https://www.facebook.com',
                    ),
                    const SizedBox(width: 16),
                    _buildQuickAccessIconWithAsset(
                      'Google',
                      'assets/svgs/google.png',
                      'https://www.google.com',
                    ),
                    const SizedBox(width: 16),
                    _buildQuickAccessIconWithAsset(
                      'Twitter',
                      'assets/svgs/twitter.svg',
                      'https://www.twitter.com',
                    ),
                    const SizedBox(width: 16),
                    _buildQuickAccessIcon(
                      'Instagram',
                      Icons.camera_alt,
                      Colors.pink,
                      'https://www.instagram.com',
                    ),
                    const SizedBox(width: 20), // Extra space at the end
                  ],
                ),
              ),
            ),


            const SizedBox(height: 20),

            // 📰 News Section Header
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    offset: const Offset(0, -2),
                    blurRadius: 15,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Language Selector Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.language, color: Color(0xFF2196F3), size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'News Language:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<NewsLanguage>(
                        value: LanguagePreferenceService.currentLanguage,
                        onChanged: _isTranslating ? null : (NewsLanguage? newLanguage) async {
                          if (newLanguage != null && newLanguage != LanguagePreferenceService.currentLanguage) {
                            await LanguagePreferenceService.setLanguagePreference(newLanguage);

                            // Show loading immediately
                            setState(() {
                              _isLoadingNews = true;
                              _isTranslating = newLanguage != NewsLanguage.english;
                              _translationStatus = newLanguage != NewsLanguage.english
                                ? 'Switching to ${newLanguage.displayName}...'
                                : '';
                            });

                            await _loadNews();
                          }
                        },
                        items: LanguagePreferenceService.availableLanguages.map((language) {
                          return DropdownMenuItem<NewsLanguage>(
                            value: language,
                            child: Text(
                              language.displayName,
                              style: const TextStyle(fontSize: 14),
                            ),
                          );
                        }).toList(),
                        underline: Container(),
                        style: const TextStyle(
                          color: Color(0xFF2196F3),
                          fontWeight: FontWeight.w500,
                        ),
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // News Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "📰 Latest News",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1976D2),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AllNewsScreen(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text("View All"),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 📰 News Feed with Ad Slots (2→ad→3→ad→3→ad pattern)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: _isLoadingNews
                  ? Container(
                      height: 300,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              color: Color(0xFF2196F3),
                              strokeWidth: 3,
                            ),
                            const SizedBox(height: 16),
                            if (_isTranslating && _translationStatus.isNotEmpty)
                              Column(
                                children: [
                                  Text(
                                    _translationStatus,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '🌐 Translating news content...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              )
                            else
                              Text(
                                'Loading latest news...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                  : _buildNewsFeedWithAds(),
            ),

            // Loading indicator for more news
            if (_isLoadingMoreNews)
              Container(
                padding: const EdgeInsets.all(20),
                child: const Column(
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFF2196F3),
                      strokeWidth: 2,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Loading more news...',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

            // Extra padding at bottom for better scrolling
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildWebViewPage() {
    if (_tabs.isEmpty || _currentController == null) {
      return const Center(
        child: Text(
          'No page loaded',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    return WebViewWidget(controller: _currentController!);
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            offset: const Offset(0, -1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Back arrow
          IconButton(
            onPressed: () async {
              if (_currentController != null && await _currentController!.canGoBack()) {
                await _currentController!.goBack();
              } else {
                // Go to home page when no back history
                _goHome();
              }
            },
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
              size: 18,
            ),
            splashRadius: 20,
            padding: const EdgeInsets.all(8),
          ),

          // Forward arrow
          IconButton(
            onPressed: () async {
              if (_currentController != null && await _currentController!.canGoForward()) {
                await _currentController!.goForward();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ No forward page available'),
                    duration: Duration(seconds: 1),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            icon: const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 18,
            ),
            splashRadius: 20,
            padding: const EdgeInsets.all(8),
          ),

          // Refresh button
          IconButton(
            onPressed: () {
              if (_currentController != null) {
                _currentController!.reload();
              }
            },
            icon: const Icon(
              Icons.refresh,
              color: Colors.white,
              size: 18,
            ),
            splashRadius: 20,
            padding: const EdgeInsets.all(8),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessIcon(
    String title,
    IconData icon,
    Color color,
    String url,
  ) {
    return InkWell(
      onTap: () => _addNewTab(url),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 74,
        child: Column(
          children: [
            // Chrome-style circular icon container with more realistic design
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    offset: const Offset(0, 1),
                    blurRadius: 3,
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 24,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            // Title below icon - Chrome style
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Colors.grey[700],
                height: 1.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessIconWithAsset(
    String title,
    String assetPath,
    String url,
  ) {
    return InkWell(
      onTap: () => _addNewTab(url),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 74,
        child: Column(
          children: [
            // Chrome-style circular icon container with custom asset
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    offset: const Offset(0, 1),
                    blurRadius: 3,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: assetPath.endsWith('.svg')
                  ? SvgPicture.asset(
                      assetPath,
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                      placeholderBuilder: (BuildContext context) => Icon(
                        Icons.image,
                        size: 24,
                        color: Colors.grey[400],
                      ),
                    )
                  : Image.asset(
                      assetPath,
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.image,
                          size: 24,
                          color: Colors.grey[400],
                        );
                      },
                    ),
              ),
            ),
            const SizedBox(height: 8),
            // Title below icon - Chrome style
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Colors.grey[700],
                height: 1.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsFeedWithAds() {
    List<Widget> items = [];

    if (_newsArticles.isEmpty) {
      return Column(children: items);
    }

    // NEW PATTERN: 3-4-5 news articles then admin cards
    print('🔍 Building news feed with ${_newsArticles.length} articles');

    // Get admin card positions using the new pattern
    final adminCardPositions = AdminCardService.getAdminCardPositions(_newsArticles.length);
    print('📍 Admin cards will appear at positions: $adminCardPositions');

    int newsIndex = 0;
    int adminCardIndex = 0;

    while (newsIndex < _newsArticles.length) {
      // Add news article
      items.add(_buildNewsCard(_newsArticles[newsIndex]));
      newsIndex++;

      // Check if we should add an admin card after this news position
      if (AdminCardService.shouldShowAdminCardAt(newsIndex, adminCardPositions)) {
        if (AdminCardService.adminCards.isNotEmpty && adminCardIndex < adminCardPositions.length) {
          final adminCard = AdminCardService.getAdminCardAtPosition(newsIndex, adminCardPositions);

          if (adminCard != null) {
            print('🎯 Adding admin card "${adminCard.title}" after $newsIndex news articles');

            // Add some spacing before the admin card
            items.add(const SizedBox(height: 16));

            items.add(AdminCardWidget(
              adminCard: adminCard,
              cardNumber: adminCardIndex + 1,
            ));

            // Add some spacing after the admin card
            items.add(const SizedBox(height: 16));

            adminCardIndex++;
          }
        }
      }

      // Add banner ad occasionally (much less frequent)
      if (newsIndex % 20 == 0 && newsIndex > 10) {
        items.add(BannerAdWidget(
          adId: newsIndex ~/ 20,
          height: 120,
        ));
      }
    }

    // Debug output
    AdminCardService.debugPattern(_newsArticles.length);

    return Column(children: items);
  }

  Widget _buildNewsCard(NewsArticle article) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NewsDetailScreen(article: article),
          ),
        );
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 8.0,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
          border: Border.all(
            color: const Color(0xFF2196F3).withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.urlToImage != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15.0),
                ),
                child: Image.network(
                  article.urlToImage!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox.shrink();
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.0,
                      color: Color(0xFF1976D2),
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    article.description,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14.0,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              article.source,
                              style: const TextStyle(
                                color: Color(0xFF1976D2),
                                fontSize: 11.0,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (article.isTranslated) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.translate,
                                    size: 10,
                                    color: Colors.green[700],
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    article.language.displayName,
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      Flexible(
                        child: Text(
                          article.author ?? '',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11.0,
                          ),
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

