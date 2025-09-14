import 'package:flutter/material.dart';
import '../../components/search_bar.dart' as custom;
import '../../services/news_service.dart';
import '../news/all_news_screen.dart';
import '../news/news_detail_screen.dart';
import '../notifications/notifications_screen.dart';
import '../webview/web_view_screen.dart';
import '../admin/admin_panel.dart';
import '../../components/auth_dialog.dart';
import '../../services/auth_service.dart';
import '../../services/language_service.dart';
import '../settings/settings_screen.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_core/firebase_core.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<NewsArticle> _newsArticles = [];
  bool _isLoadingNews = true;
  bool _isAdmin = false;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadNews();
    _checkAdminStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showNotificationsSlideshow();
    });
  }

  Future<void> _checkAdminStatus() async {
    final user = _authService.currentUser;
    setState(() {
      _isAdmin = _authService.isAdmin(user);
    });
    print('Admin status checked: $_isAdmin, User: ${user?.email}');
  }

  Future<void> _loadNews() async {
    try {
      final articles = await NewsService.getTopHeadlines();
      if (mounted) {
        setState(() {
          _newsArticles = articles;
          _isLoadingNews = false;
        });
      }
    } catch (e) {
      print('Error loading news: $e');
      if (mounted) {
        setState(() {
          _isLoadingNews = false;
        });
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
                      builder: (context) => const AdminPanel(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          LanguageService.translate('app_name'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
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
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
            // 🔎 Search Bar with improved styling
            Container(
              margin: const EdgeInsets.all(20.0),
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
                hintText: LanguageService.translate('search'),
                onSearch: (query) {
                  String url = query.toLowerCase();
                  if (!url.startsWith('http://') && !url.startsWith('https://')) {
                    if (Uri.tryParse(url)?.hasScheme ?? false) {
                      // URL without scheme but valid
                      url = 'https://$url';
                    } else {
                      // Not a URL, do a Google search
                      url = 'https://www.google.com/search?q=${Uri.encodeComponent(query)}';
                    }
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WebViewScreen(
                        url: url,
                        title: 'Browser',
                      ),
                    ),
                  );
                },
              ),
            ),

            // Welcome text
            // Container(
            //   margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            //   child: const Text(
            //     "Quick Access",
            //     style: TextStyle(
            //       fontSize: 22,
            //       fontWeight: FontWeight.bold,
            //       color: Colors.white,
            //     ),
            //   ),
            // ),

            // 🌐 Shortcut Websites Grid with improved design
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              padding: const EdgeInsets.all(16),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WebViewScreen(
                            url: 'https://www.google.com',
                            title: 'Google Search',
                          ),
                        ),
                      );
                    },
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF2196F3).withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.language, size: 24, color: const Color(0xFF2196F3)),
                          const SizedBox(height: 4),
                          const Text(
                            "Google",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1976D2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WebViewScreen(
                            url: 'https://www.youtube.com',
                            title: 'YouTube',
                          ),
                        ),
                      );
                    },
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.red.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.video_library, size: 24, color: Colors.red[600]),
                          const SizedBox(height: 4),
                          const Text(
                            "YouTube",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1976D2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WebViewScreen(
                            url: 'https://www.facebook.com',
                            title: 'Facebook',
                          ),
                        ),
                      );
                    },
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.facebook, size: 24, color: Colors.blue[900]),
                          const SizedBox(height: 4),
                          const Text(
                            "Facebook",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1976D2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WebViewScreen(
                            url: 'https://www.amazon.com',
                            title: 'Shopping',
                          ),
                        ),
                      );
                    },
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_bag, size: 24, color: Colors.green[600]),
                          const SizedBox(height: 4),
                          const Text(
                            "Shopping",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1976D2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                ],
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
              child: Row(
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
            ),

            // 📰 News Feed
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: _isLoadingNews
                  ? Container(
                      height: 300,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF2196F3),
                        ),
                      ),
                    )
                  : Column(
                      children: _newsArticles.map((article) {
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
                      }).toList(),
                    ),
              ),

              // Extra padding at bottom for better scrolling
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),

      // No bottom navigation bar needed
    );
  }
}
