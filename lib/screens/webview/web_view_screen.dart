import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/ad_block_service.dart';
import '../../services/ad_overlay_service.dart';
import '../../services/history_service.dart';
import '../../services/tab_service.dart';
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
              const PopupMenuItem<String>(
                value: 'new_tab',
                child: Row(
                  children: [
                    Icon(Icons.add_box, color: Color(0xFF2196F3)),
                    SizedBox(width: 8),
                    Text('New Tab'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'tabs',
                child: Row(
                  children: [
                    Icon(Icons.tab, color: Color(0xFF2196F3)),
                    SizedBox(width: 8),
                    Text('Tab Manager'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: Color(0xFF2196F3)),
                    SizedBox(width: 8),
                    Text('Refresh'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'desktop',
                child: Row(
                  children: [
                    Icon(
                      _isDesktopMode ? Icons.phone_android : Icons.desktop_windows,
                      color: const Color(0xFF2196F3),
                    ),
                    const SizedBox(width: 8),
                    Text(_isDesktopMode ? 'Mobile Mode' : 'Desktop Mode'),
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
                    const SizedBox(width: 8),
                    Text(_isAdBlockEnabled ? 'Ad Block: ON' : 'Ad Block: OFF'),
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