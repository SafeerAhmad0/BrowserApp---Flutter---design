import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/ad_block_service.dart';
import '../../services/language_preference_service.dart';
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
  NewsLanguage _currentTranslationLanguage = NewsLanguage.english;
  
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

  void _translatePage(NewsLanguage targetLanguage) async {
    if (targetLanguage == NewsLanguage.english) {
      // Remove translation
      await _controller.runJavaScript('''
        // Remove any existing Google Translate elements
        var googleTranslateElements = document.querySelectorAll('[id*="google_translate"], [class*="skiptranslate"], [class*="goog-te"]');
        googleTranslateElements.forEach(function(element) {
          element.remove();
        });

        // Restore original content if cached
        if (window.originalBodyHTML) {
          document.body.innerHTML = window.originalBodyHTML;
        }
      ''');
      setState(() => _currentTranslationLanguage = NewsLanguage.english);
      return;
    }

    setState(() => _currentTranslationLanguage = targetLanguage);

    try {
      // Inject Google Translate
      await _controller.runJavaScript('''
        // Cache original content
        if (!window.originalBodyHTML) {
          window.originalBodyHTML = document.body.innerHTML;
        }

        // Remove existing Google Translate elements
        var existingElements = document.querySelectorAll('[id*="google_translate"], [class*="skiptranslate"], [class*="goog-te"]');
        existingElements.forEach(function(element) {
          element.remove();
        });

        // Add Google Translate script
        if (!document.querySelector('script[src*="translate.google.com"]')) {
          var script = document.createElement('script');
          script.type = 'text/javascript';
          script.src = 'https://translate.google.com/translate_a/element.js?cb=googleTranslateElementInit';
          document.getElementsByTagName('head')[0].appendChild(script);
        }

        // Initialize Google Translate
        window.googleTranslateElementInit = function() {
          new google.translate.TranslateElement({
            pageLanguage: 'en',
            includedLanguages: '${targetLanguage.code}',
            layout: google.translate.TranslateElement.InlineLayout.SIMPLE,
            autoDisplay: false
          }, 'google_translate_element');

          // Auto-trigger translation
          setTimeout(function() {
            var selectElement = document.querySelector('.goog-te-combo');
            if (selectElement) {
              selectElement.value = '${targetLanguage.code}';
              selectElement.dispatchEvent(new Event('change'));
            }
          }, 1000);
        };

        // Add translate element container
        var translateDiv = document.createElement('div');
        translateDiv.id = 'google_translate_element';
        translateDiv.style.display = 'none';
        document.body.appendChild(translateDiv);

      ''');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Translating page to ${targetLanguage.displayName}...'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Translation failed. Please try again.'),
          duration: Duration(seconds: 2),
        ),
      );
      setState(() => _currentTranslationLanguage = NewsLanguage.english);
    }
  }

  void _showTranslateMenu() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Translate Page'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Choose a language to translate this page:'),
              const SizedBox(height: 16),
              ...NewsLanguage.values.map((language) => ListTile(
                leading: Icon(
                  language == _currentTranslationLanguage
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: language == _currentTranslationLanguage ? Colors.blue : null,
                ),
                title: Text(language.displayName),
                onTap: () {
                  Navigator.pop(context);
                  _translatePage(language);
                },
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
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'translate_submenu',
                child: Row(
                  children: [
                    Icon(
                      Icons.translate,
                      color: _currentTranslationLanguage != NewsLanguage.english ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(_currentTranslationLanguage == NewsLanguage.english
                        ? 'Translate Page'
                        : 'Translate: ${_currentTranslationLanguage.displayName}'),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'adblock') {
                _toggleAdBlock();
              } else if (value == 'translate_submenu') {
                _showTranslateMenu();
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