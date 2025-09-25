import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/ad_block_service.dart';
import '../../services/ad_overlay_service.dart';
import '../../services/history_service.dart';
import '../../services/tab_service.dart';
import '../../services/language_preference_service.dart';
import '../tabs/tab_manager_screen.dart';
import '../../models/tab.dart';

class WebViewScreen extends StatefulWidget {
  final String url;
  final String title;
  final String? tabId;

  const WebViewScreen({
    super.key,
    required this.url,
    required this.title,
    this.tabId,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isDesktopMode = false;
  bool _isAdBlockEnabled = true;
  String? _currentTabId;
  NewsLanguage _currentTranslationLanguage = NewsLanguage.english;

  @override
  void initState() {
    super.initState();
    _currentTabId = widget.tabId;
    _initializeWebView();
    _initializeTab();
    // Load the initial URL
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.loadRequest(Uri.parse(widget.url));
      }
    });
  }

  Future<void> _initializeTab() async {
    // If no tab ID provided, create a new tab
    if (_currentTabId == null) {
      await TabService.createNewTab(widget.url, widget.title);
      final activeTab = await TabService.getActiveTab();
      if (activeTab != null) {
        _currentTabId = activeTab.id;
      }
    } else {
      // Update existing tab
      await TabService.updateTab(_currentTabId!, url: widget.url, title: widget.title);
      await TabService.setActiveTab(_currentTabId!);
    }
  }

  @override
  void dispose() {
    // Clean up to prevent memory issues
    try {
      // Clear caches and data
      _controller.clearCache();
      _controller.clearLocalStorage();

      // Stop any ongoing processes
      _controller.runJavaScript('window.stop();').catchError((e) {
        print('Error stopping page: $e');
      });

    } catch (e) {
      print('Error during cleanup: $e');
    }
    super.dispose();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_isDesktopMode
          ? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
          : 'Mozilla/5.0 (Linux; Android 10; SM-A325F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36')
      ..enableZoom(true)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (String url) async {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });

              // Add to browsing history and update tab
              try {
                String title = widget.title;
                // Try to get the actual page title
                try {
                  final pageTitle = await _controller.getTitle();
                  if (pageTitle != null && pageTitle.isNotEmpty) {
                    title = pageTitle;
                  }
                } catch (e) {
                  print('Could not get page title: $e');
                }

                await HistoryService.addToHistory(
                  url: url,
                  title: title,
                );

                // Update tab with new URL and title
                if (_currentTabId != null) {
                  await TabService.updateTab(_currentTabId!, url: url, title: title);
                }
              } catch (e) {
                print('Error adding to history: $e');
              }

              // Apply ad blocking OR ad injection
              if (_isAdBlockEnabled) {
                try {
                  await AdBlockService.injectAdBlocker(_controller);
                } catch (e) {
                  print('Ad block injection failed: $e');
                }
              } else {
                // Inject ads when ad block is disabled
                try {
                  await AdOverlayService.injectAdScripts(_controller);
                  AdOverlayService.showInitialAd(context, _controller);
                  AdOverlayService.startAdTimer(context, _controller);
                } catch (e) {
                  print('Ad injection failed: $e');
                }
              }

              // Apply performance improvements
              {
                // Performance improvements for all pages
                try {
                  await _controller.runJavaScript('''
                    // Reduce memory usage
                    if (typeof window.performance !== 'undefined') {
                      if (window.performance.clearResourceTimings) {
                        window.performance.clearResourceTimings();
                      }
                    }
                    if (console.log.length > 100) {
                      console.clear();
                    }
                  ''');
                } catch (e) {
                  print('Performance optimization failed: $e');
                }
              }
            }
          },
          onWebResourceError: (WebResourceError error) {
            print('WebView error: ${error.description}');
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onHttpError: (HttpResponseError error) {
            print('HTTP error: ${error.response?.statusCode}');
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            // Allow all navigation for Google Translate to work properly
            print('Navigation to: ${request.url}');
            return NavigationDecision.navigate;
          },
        ),
      );
  }

  void _toggleDesktopMode() async {
    setState(() {
      _isDesktopMode = !_isDesktopMode;
      _isLoading = true;
    });

    try {
      // Set the new user agent directly
      final newUserAgent = _isDesktopMode
          ? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
          : 'Mozilla/5.0 (Linux; Android 10; SM-A325F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

      await _controller.setUserAgent(newUserAgent);

      // Reload the page with new user agent
      await _controller.reload();

      // Show feedback to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isDesktopMode ? 'Switched to Desktop Mode' : 'Switched to Mobile Mode',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF2196F3),
          ),
        );
      }
    } catch (e) {
      print('Error toggling desktop mode: $e');
      // Revert the state if failed
      if (mounted) {
        setState(() {
          _isDesktopMode = !_isDesktopMode;
          _isLoading = false;
        });
      }
    }
  }

  void _toggleAdBlock() {
    setState(() {
      _isAdBlockEnabled = !_isAdBlockEnabled;
    });

    // Update global services
    AdBlockService.setEnabled(_isAdBlockEnabled);
    AdOverlayService.setAdBlockEnabled(_isAdBlockEnabled);

    // Reload page to apply changes
    _controller.reload();

    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isAdBlockEnabled ? '🛡️ Ad Block Enabled' : '🎯 Ads Enabled - Scripts will load',
        ),
        backgroundColor: _isAdBlockEnabled ? Colors.green : Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _createNewTab() async {
    await TabService.createNewTab('https://www.google.com', 'New Tab');
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const WebViewScreen(
            url: 'https://www.google.com',
            title: 'New Tab',
          ),
        ),
      );
    }
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

        console.log('Google Translate initialized for ${targetLanguage.displayName}');
      ''');

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
              const Text('Translate Page'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Choose a language to translate this page:'),
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
                    color: language == _currentTranslationLanguage ? const Color(0xFF2196F3) : Colors.grey,
                  ),
                  title: Text(
                    language.displayName,
                    style: TextStyle(
                      fontWeight: language == _currentTranslationLanguage ? FontWeight.bold : FontWeight.normal,
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








  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            // Add smooth animation and styling
            splashRadius: 20,
            offset: const Offset(0, 50),
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              switch (value) {
                case 'refresh':
                  _controller.reload();
                  break;
                case 'desktop':
                  _toggleDesktopMode();
                  break;
                case 'adblock':
                  _toggleAdBlock();
                  break;
                case 'translate':
                  _showTranslateMenu();
                  break;
                case 'tabs':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TabManagerScreen(
                        tabs: const <BrowserTab>[],
                        onTabSelected: (index) {
                          // Handle tab selection
                        },
                        onTabClosed: (index) {
                          // Handle tab closure
                        },
                        onNewTab: () {
                          // Handle new tab
                        },
                      ),
                    ),
                  );
                  break;
                case 'new_tab':
                  _createNewTab();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'new_tab',
                child: Row(
                  children: const [
                    Icon(Icons.add_box, color: Color(0xFF2196F3)),
                    SizedBox(width: 12),
                    Text('New Tab', style: TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'tabs',
                child: Row(
                  children: const [
                    Icon(Icons.tab, color: Color(0xFF2196F3)),
                    SizedBox(width: 12),
                    Text('Tab Manager', style: TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'refresh',
                child: Row(
                  children: const [
                    Icon(Icons.refresh, color: Color(0xFF2196F3)),
                    SizedBox(width: 12),
                    Text('Refresh', style: TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'translate',
                child: Row(
                  children: [
                    Icon(
                      Icons.translate,
                      color: _currentTranslationLanguage != NewsLanguage.english
                        ? const Color(0xFF2196F3)
                        : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _currentTranslationLanguage == NewsLanguage.english
                            ? 'Translate Page'
                            : 'Translate: ${_currentTranslationLanguage.displayName}',
                        style: TextStyle(
                          fontWeight: _currentTranslationLanguage != NewsLanguage.english
                            ? FontWeight.w600
                            : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (_currentTranslationLanguage != NewsLanguage.english)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2196F3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'ON',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'desktop',
                child: Row(
                  children: [
                    Icon(
                      _isDesktopMode ? Icons.phone_android : Icons.desktop_windows,
                      color: const Color(0xFF2196F3),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isDesktopMode ? 'Mobile Mode' : 'Desktop Mode',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'adblock',
                child: Row(
                  children: [
                    Icon(
                      _isAdBlockEnabled ? Icons.block : Icons.ads_click,
                      color: _isAdBlockEnabled ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isAdBlockEnabled ? 'Ad Block: ON' : 'Ad Block: OFF',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: Colors.white,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF2196F3),
                ),
              ),
            ),
          // Back and Forward buttons - ALWAYS VISIBLE
          Positioned(
            top: 100,
            right: 20,
            child: Column(
              children: [
                // Back button
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: () async {
                      if (await _controller.canGoBack()) {
                        await _controller.goBack();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('❌ NO BACK PAGE'),
                            duration: Duration(seconds: 2),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 30,
                    ),
                    tooltip: 'BACK',
                  ),
                ),
                // Forward button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: () async {
                      if (await _controller.canGoForward()) {
                        await _controller.goForward();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('❌ NO FORWARD PAGE'),
                            duration: Duration(seconds: 2),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                      size: 30,
                    ),
                    tooltip: 'FORWARD',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}