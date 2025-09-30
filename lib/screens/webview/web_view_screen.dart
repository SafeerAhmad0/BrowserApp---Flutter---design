import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import '../../services/ad_block_service.dart';
import '../../services/ad_overlay_service.dart';
import '../../services/history_service.dart';
import '../../services/tab_service.dart';
import '../../services/language_preference_service.dart';
import '../../services/proxy_service.dart';
import '../../services/consolidated_ad_service.dart';
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
  bool _isAdBlockEnabled = false; // Default to show ads
  String? _currentTabId;
  NewsLanguage _currentTranslationLanguage = NewsLanguage.english;

  @override
  void initState() {
    super.initState();
    _currentTabId = widget.tabId;
    _initializeWebView();
    _initializeTab();
    _initializeProxy();
    // Load the initial URL
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadUrlWithProxy(widget.url);
      }
    });
  }

  Future<void> _initializeProxy() async {
    await ProxyService().initialize();
  }


  Future<void> _loadUrlWithProxy(String url) async {
    // Check if website needs proxy
    final proxyService = ProxyService();
    final needsProxy = proxyService.isWebsiteBlocked(url) && proxyService.isProxyEnabled;

    print('🚀 LOADING URL: $url');
    print('   Needs Proxy: $needsProxy');
    print('   Proxy Enabled: ${proxyService.isProxyEnabled}');
    print('   Selected Server: ${proxyService.selectedServer?.name}');

    if (needsProxy && proxyService.selectedServer != null) {
      // Show proxy notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.vpn_lock, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('🌐 Loading via ${proxyService.selectedServer!.location} proxy'),
                ),
              ],
            ),
            backgroundColor: Colors.orange[600],
            duration: Duration(seconds: 3),
          ),
        );
      }

      print('🔥 USING PROXY FOR: $url');
      await _setupProxyForBlockedSite(url);
    } else {
      print('📡 DIRECT LOAD: $url');
      _controller.loadRequest(Uri.parse(url));
    }
  }

  Future<void> _setupProxyForBlockedSite(String url) async {
    final proxyService = ProxyService();

    try {
      // Fetch content through our VPS proxy
      final htmlContent = await proxyService.fetchWithProxy(url);

      if (htmlContent != null) {
        // Load the proxy-fetched content into WebView
        await _controller.loadHtmlString(
          _createProxyHtml(htmlContent, url),
          baseUrl: url,
        );
      } else {
        // Fallback to direct loading if proxy fails
        _controller.loadRequest(Uri.parse(url));
      }
    } catch (e) {
      // Fallback to direct loading
      _controller.loadRequest(Uri.parse(url));
    }
  }

  String _createProxyHtml(String content, String originalUrl) {
    // Inject base URL and fix relative links
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <base href="$originalUrl">
    <title>Proxied Content</title>
    <style>
        body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
        .proxy-banner {
            background: linear-gradient(90deg, #ff6b35, #f7931e);
            color: white;
            padding: 8px 16px;
            text-align: center;
            font-size: 12px;
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            z-index: 9999;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .proxy-content { margin-top: 40px; }
    </style>
</head>
<body>
    <div class="proxy-banner">
        🌐 Loading via VPS Proxy Server
    </div>
    <div class="proxy-content">
        $content
    </div>
    <script>
        // Fix relative links on page load
        document.addEventListener('DOMContentLoaded', function() {
            const baseUrl = '$originalUrl';
            const links = document.querySelectorAll('a');

            links.forEach(link => {
                const href = link.getAttribute('href');
                if (href) {
                    if (href.startsWith('/')) {
                        // Absolute path - add domain
                        const urlObj = new URL(baseUrl);
                        link.href = urlObj.protocol + '//' + urlObj.host + href;
                    } else if (href.startsWith('./') || href.startsWith('../')) {
                        // Relative path - resolve relative to base
                        try {
                            link.href = new URL(href, baseUrl).href;
                        } catch (e) {
                            // Keep original if URL construction fails
                        }
                    }
                    // Absolute URLs (http://, https://) are left as-is
                }
            });
        });
    </script>
</body>
</html>''';
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

      // Stop any ongoing processes - COMMENTED OUT TO PREVENT NAVIGATION DIALOGS
      // _controller.runJavaScript('window.stop();').catchError((e) {
      // });

    } catch (e) {
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
      ..setOnJavaScriptAlertDialog((JavaScriptAlertDialogRequest request) async {
        // Automatically dismiss all JavaScript alerts to prevent navigation dialogs
        return;
      })
      ..setOnJavaScriptConfirmDialog((JavaScriptConfirmDialogRequest request) async {
        // Automatically return true for all JavaScript confirms to prevent navigation dialogs
        return true;
      })
      ..setOnJavaScriptTextInputDialog((JavaScriptTextInputDialogRequest request) async {
        // Automatically return empty string for all JavaScript prompts
        return '';
      })
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

              // Use consolidated ad service for all ad injection
              await ConsolidatedAdService.processPageLoad(_controller, url);

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
              }

              // Apply ad injection - ONLY ONCE PER PAGE LOAD
              if (!_isAdBlockEnabled) {
                // Inject ads when ad block is disabled
                try {
                  await AdOverlayService.injectAdScripts(_controller);
                  AdOverlayService.showInitialAd(context, _controller);
                  AdOverlayService.startAdTimer(context, _controller);
                } catch (e) {
                  // Silently handle any ad injection errors
                }
              }

              // Apply performance improvements
              {
                // Performance improvements for all pages - COMMENTED OUT TO PREVENT NAVIGATION DIALOGS
                /*
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
                }
                */
              }
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onHttpError: (HttpResponseError error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            // Intercept ALL navigation to use proxy for blocked sites
            final proxyService = ProxyService();
            final needsProxy = proxyService.isWebsiteBlocked(request.url) && proxyService.isProxyEnabled;

            print('🚀 NAVIGATION REQUEST: ${request.url}');
            print('   Needs Proxy: $needsProxy');
            print('   Proxy Enabled: ${proxyService.isProxyEnabled}');

            if (needsProxy) {
              // Load through proxy asynchronously
              print('🔥 INTERCEPTING NAVIGATION FOR PROXY: ${request.url}');
              Future.microtask(() => _loadUrlWithProxy(request.url));
              return NavigationDecision.prevent; // Prevent normal navigation
            }

            // Allow normal navigation for non-blocked sites
            print('📡 ALLOWING DIRECT NAVIGATION: ${request.url}');
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
      // Remove translation - COMMENTED OUT TO PREVENT NAVIGATION DIALOGS
      /*
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
      */
      setState(() => _currentTranslationLanguage = NewsLanguage.english);
      return;
    }

    setState(() => _currentTranslationLanguage = targetLanguage);

    try {
      // Inject Google Translate - COMMENTED OUT TO PREVENT NAVIGATION DIALOGS
      /*
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
      */

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
                case 'proxy':
                  _showProxyMenu();
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
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'proxy',
                child: FutureBuilder<bool>(
                  future: _getProxyStatus(),
                  builder: (context, snapshot) {
                    final isEnabled = snapshot.data ?? false;
                    return Row(
                      children: [
                        Icon(
                          isEnabled ? Icons.vpn_lock : Icons.vpn_lock_outlined,
                          color: isEnabled ? Colors.orange : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isEnabled ? 'Proxy: ON' : 'Proxy: OFF',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        if (isEnabled) ...[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'VPS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
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

  Future<bool> _getProxyStatus() async {
    await ProxyService().initialize();
    return ProxyService().isProxyEnabled;
  }

  void _showProxyMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ProxyMenuWidget(),
    );
  }
}

class ProxyMenuWidget extends StatefulWidget {
  @override
  _ProxyMenuWidgetState createState() => _ProxyMenuWidgetState();
}

class _ProxyMenuWidgetState extends State<ProxyMenuWidget> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 50,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Row(
            children: [
              Icon(Icons.vpn_lock, color: Colors.orange[700], size: 24),
              const SizedBox(width: 8),
              Text(
                'Proxy Settings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Proxy Status and Toggle
          FutureBuilder<bool>(
            future: _getProxyStatus(),
            builder: (context, snapshot) {
              final isEnabled = snapshot.data ?? false;
              return Card(
                child: SwitchListTile(
                  title: const Text('Enable Proxy'),
                  subtitle: Text(
                    isEnabled
                        ? 'Proxy is active for blocked websites'
                        : 'Direct connection',
                  ),
                  value: isEnabled,
                  activeColor: Colors.orange,
                  onChanged: _isLoading ? null : (value) => _toggleProxy(value),
                  secondary: Icon(
                    isEnabled ? Icons.vpn_lock : Icons.vpn_lock_outlined,
                    color: isEnabled ? Colors.orange : Colors.grey,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Server Selection
          FutureBuilder<ProxyServer?>(
            future: _getSelectedServer(),
            builder: (context, snapshot) {
              final selectedServer = snapshot.data;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Server Location',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...ProxyService().servers.map((server) => _buildServerOption(server, selectedServer)),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Control Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _testConnection,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.speed),
                  label: Text(_isLoading ? 'Testing...' : 'Test Connection'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('Close'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildServerOption(ProxyServer server, ProxyServer? selectedServer) {
    final isSelected = selectedServer?.host == server.host;
    return RadioListTile<ProxyServer>(
      title: Text(server.name),
      subtitle: Text('${server.location} • ${server.host}'),
      value: server,
      groupValue: selectedServer,
      activeColor: Colors.orange,
      onChanged: _isLoading ? null : (value) => _selectServer(value!),
      dense: true,
    );
  }

  Future<bool> _getProxyStatus() async {
    await ProxyService().initialize();
    return ProxyService().isProxyEnabled;
  }

  Future<ProxyServer?> _getSelectedServer() async {
    await ProxyService().initialize();
    return ProxyService().selectedServer;
  }

  Future<void> _toggleProxy(bool enabled) async {
    setState(() => _isLoading = true);

    try {
      await ProxyService().setProxyEnabled(enabled);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled ? '✅ Proxy Enabled' : '❌ Proxy Disabled',
          ),
          backgroundColor: enabled ? Colors.green : Colors.orange,
        ),
      );

      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isLoading = false);
  }

  Future<void> _selectServer(ProxyServer server) async {
    setState(() => _isLoading = true);

    try {
      await ProxyService().selectServer(server);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Selected ${server.name}'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isLoading = false);
  }

  Future<void> _testConnection() async {
    setState(() => _isLoading = true);

    try {
      final proxyService = ProxyService();
      await proxyService.initialize();

      final selectedServer = proxyService.selectedServer;
      if (selectedServer == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Please select a server first'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final isConnected = await proxyService.testProxyConnection(selectedServer);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isConnected
                ? '✅ ${selectedServer.name} is working'
                : '❌ ${selectedServer.name} connection failed',
          ),
          backgroundColor: isConnected ? Colors.green : Colors.red,
        ),
      );

      if (isConnected) {
        final currentIP = await proxyService.getCurrentIP();
        if (currentIP != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🌐 Current IP: $currentIP'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isLoading = false);
  }
}