import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/ad_block_service.dart';
import '../../components/search_bar.dart' as custom;

class BrowserScreen extends StatefulWidget {
  final String? initialUrl;
  
  const BrowserScreen({super.key, this.initialUrl});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  late WebViewController _controller;
  bool _isLoading = true;
  bool _isDesktopMode = false;
  String _currentUrl = '';
  String _currentTitle = '';
  final List<Tab> _tabs = [];
  int _activeTabIndex = 0;
  
  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _addNewTab(widget.initialUrl ?? 'https://www.google.com');
  }
  
  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            return AdBlockService.handleNavigation(request);
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _currentUrl = url;
            });
          },
          onPageFinished: (String url) async {
            setState(() {
              _isLoading = false;
              _currentUrl = url;
            });
            String? title = await _controller.getTitle();
            setState(() {
              _currentTitle = title ?? 'Untitled';
              _tabs[_activeTabIndex] = _tabs[_activeTabIndex].copyWith(
                title: _currentTitle,
                url: url,
              );
            });
            
            // Inject ad blocker after page loads
            await AdBlockService.injectAdBlocker(_controller);
          },
          onWebResourceError: (WebResourceError error) {
            setState(() => _isLoading = false);
          },
        ),
      );
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
            if (_tabs.isNotEmpty && _activeTabIndex < _tabs.length) {
              setState(() {
                _currentUrl = tabUrl;
                _tabs[_activeTabIndex] = _tabs[_activeTabIndex].copyWith(url: tabUrl);
              });
            }
          },
          onPageFinished: (String tabUrl) async {
            await AdBlockService.injectAdBlocker(tabController);
            if (_tabs.isNotEmpty && _activeTabIndex < _tabs.length) {
              String? title = await tabController.getTitle();
              setState(() {
                _currentUrl = tabUrl;
                _currentTitle = title ?? 'Untitled';
                _tabs[_activeTabIndex] = _tabs[_activeTabIndex].copyWith(
                  title: _currentTitle,
                  url: tabUrl,
                );
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
    
    setState(() {
      _tabs.add(Tab(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Loading...',
        url: url,
        controller: tabController,
      ));
      _activeTabIndex = _tabs.length - 1;
    });
    
    if (_activeTabIndex == 0) {
      _controller.loadRequest(Uri.parse(url));
    }
  }
  
  void _closeTab(int index) {
    if (_tabs.length <= 1) return;
    
    setState(() {
      _tabs.removeAt(index);
      if (_activeTabIndex >= _tabs.length) {
        _activeTabIndex = _tabs.length - 1;
      }
    });
  }
  
  void _switchTab(int index) {
    setState(() {
      _activeTabIndex = index;
      _controller = _tabs[index].controller;
      _currentUrl = _tabs[index].url;
      _currentTitle = _tabs[index].title;
    });
  }
  
  void _navigateToUrl(String url) {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://www.google.com/search?q=${Uri.encodeComponent(url)}';
    }
    
    _controller.loadRequest(Uri.parse(url));
  }
  
  void _toggleDesktopMode() {
    setState(() => _isDesktopMode = !_isDesktopMode);
    
    String userAgent = _isDesktopMode 
      ? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
      : 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Mobile Safari/537.36';
    
    _controller.setUserAgent(userAgent);
    _controller.reload();
  }
  
  bool _shouldHideSearchBar() {
    if (_currentUrl.isEmpty) return false;
    
    // List of websites where we should hide our search bar
    final hideSearchBarSites = [
      'google.com',
      'youtube.com',
      'facebook.com',
      'amazon.com',
      'spotify.com',
      'twitter.com',
      'linkedin.com',
      'instagram.com',
      'bing.com',
      'yahoo.com',
      'duckduckgo.com',
    ];
    
    return hideSearchBarSites.any((site) => _currentUrl.contains(site));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTitle.length > 30 
          ? '${_currentTitle.substring(0, 30)}...' 
          : _currentTitle),
        actions: [
          IconButton(
            icon: Icon(_isDesktopMode ? Icons.phone_android : Icons.desktop_windows),
            onPressed: _toggleDesktopMode,
            tooltip: _isDesktopMode ? 'Switch to Mobile' : 'Switch to Desktop',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _addNewTab('https://www.google.com'),
            tooltip: 'New Tab',
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'adblock',
                child: Row(
                  children: [
                    Icon(
                      AdBlockService.isEnabled ? Icons.shield : Icons.shield_outlined,
                      color: AdBlockService.isEnabled ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(AdBlockService.isEnabled ? 'Ad Block: ON' : 'Ad Block: OFF'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'adblock') {
                _toggleAdBlock();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Google-style Search Bar (hide on major websites)
          if (!_shouldHideSearchBar())
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: custom.SearchBar(
                onSearch: _navigateToUrl,
                hintText: "Search Google or type a URL",
              ),
            ),
          
          // Tab Bar
          if (_tabs.length > 1)
            Container(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _tabs.length,
                itemBuilder: (context, index) {
                  final tab = _tabs[index];
                  final isActive = index == _activeTabIndex;
                  
                  return GestureDetector(
                    onTap: () => _switchTab(index),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.blue : Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tab.title.length > 15 
                              ? '${tab.title.substring(0, 15)}...' 
                              : tab.title,
                            style: TextStyle(
                              color: isActive ? Colors.white : Colors.black,
                              fontSize: 12,
                            ),
                          ),
                          if (_tabs.length > 1) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _closeTab(index),
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: isActive ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          
          // Loading indicator
          if (_isLoading)
            const LinearProgressIndicator(),
          
          // WebView
          Expanded(
            child: _tabs.isEmpty 
              ? const Center(child: Text('No tabs open'))
              : WebViewWidget(controller: _controller),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 50,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              onPressed: () => _controller.goBack(),
              icon: const Icon(Icons.arrow_back),
            ),
            IconButton(
              onPressed: () => _controller.goForward(),
              icon: const Icon(Icons.arrow_forward),
            ),
            IconButton(
              onPressed: () => _controller.reload(),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
    );
  }
  
  void _toggleAdBlock() {
    setState(() {
      AdBlockService.setEnabled(!AdBlockService.isEnabled);
    });
    
    final message = AdBlockService.isEnabled 
      ? 'Ad blocker enabled. Reload page to take effect.'
      : 'Ad blocker disabled. Reload page to take effect.';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Reload',
          onPressed: () => _controller.reload(),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showHistory() {
    // TODO: Implement history dialog
    showDialog(
      context: context,
      builder: (context) => const AlertDialog(
        title: Text('History'),
        content: Text('History feature coming soon!'),
      ),
    );
  }
  

}

class Tab {
  final String id;
  final String title;
  final String url;
  final WebViewController controller;
  
  Tab({
    required this.id,
    required this.title,
    required this.url,
    required this.controller,
  });
  
  Tab copyWith({
    String? id,
    String? title,
    String? url,
    WebViewController? controller,
  }) {
    return Tab(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      controller: controller ?? this.controller,
    );
  }
}