import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'proxy_service.dart';

class ConsolidatedAdService {
  static final ConsolidatedAdService _instance = ConsolidatedAdService._internal();
  factory ConsolidatedAdService() => _instance;
  ConsolidatedAdService._internal();

  static bool _isEnabled = true; // Always enabled by default

  // Ad Code 1: For normal browsing (no proxy)
  static const String _normalAdCode = '''
    <script type='text/javascript' src='//fortunatelychastise.com/06/5b/09/065b09109e27940443f5df1b695f61cb.js'></script>
  ''';

  // Ad Code 2: For proxy browsing
  static const String _proxyAdCode = '''
    <script>
    (function(vsxva){
    var d = document,
        s = d.createElement('script'),
        l = d.scripts[d.scripts.length - 1];
    s.settings = vsxva || {};
    s.src = "\/\/mildgive.com\/b.X\/V_sBdhGFlJ0_YTW\/cz\/zeWm-9xurZqUtlCkyPaTgYq2RNVTngvwdNIDrQKtcN\/jkY\/1bO\/DJAB0LNUQm";
    s.async = true;
    s.referrerPolicy = 'no-referrer-when-downgrade';
    l.parentNode.insertBefore(s, l);
    })({})
    </script>
  ''';

  // Show ads ONLY on actual websites, NOT on search engines
  static bool _shouldShowAdForUrl(String url) {
    if (url.isEmpty) {
      return false;
    }

    final uri = Uri.tryParse(url.toLowerCase());
    if (uri == null) {
      return false;
    }

    // List of search engines and pages where we DON'T want to show ads
    final excludedDomains = [
      'google.com',
      'www.google.com',
      'bing.com',
      'www.bing.com',
      'yahoo.com',
      'www.yahoo.com',
      'duckduckgo.com',
      'www.duckduckgo.com',
      'search.yahoo.com',
      'yandex.com',
      'www.yandex.com',
      'baidu.com',
      'www.baidu.com',
      'ask.com',
      'www.ask.com',
    ];

    // Check if the URL is a search engine
    final host = uri.host;
    for (final domain in excludedDomains) {
      if (host == domain || host.endsWith('.$domain')) {
        return false; // Don't show ads on search engines
      }
    }

    // Check if it's a search results page (has search query parameters)
    final searchParams = ['q', 'query', 'search', 's'];
    for (final param in searchParams) {
      if (uri.queryParameters.containsKey(param)) {
        return false; // Don't show ads on search result pages
      }
    }

    // Show ads on actual websites
    return true;
  }

  static bool get isEnabled => _isEnabled;

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool('consolidated_ads_enabled') ?? true;
  }

  static Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('consolidated_ads_enabled', enabled);
  }

  // Main ad injection method - shows ad every time a website opens
  static Future<void> processPageLoad(WebViewController controller, String url) async {
    if (!_isEnabled) {
      return;
    }

    // Check if this site should show ads
    if (_shouldShowAdForUrl(url)) {
      // Wait for page to load before showing ad
      await Future.delayed(const Duration(seconds: 1));

      // Check if proxy is enabled to decide which ad to show
      final proxyService = ProxyService();
      final isProxyEnabled = proxyService.isProxyEnabled;
      final isBlockedSite = proxyService.isWebsiteBlocked(url);

      // Show proxy ad if proxy is enabled AND the site is blocked, otherwise show normal ad
      final useProxyAd = isProxyEnabled && isBlockedSite;

      // Inject the appropriate ad
      await _injectAd(controller, useProxyAd);
    }
  }

  // Inject ad based on proxy status
  static Future<void> _injectAd(WebViewController controller, bool useProxyAd) async {
    if (!_isEnabled) return;

    try {
      final adScript = useProxyAd ? '''
        (function() {
          try {
            console.log('🎯 BlueX Proxy Ad Injection...');

            // Prevent multiple injections
            if (window.__BLUEX_AD_INJECTED) {
              console.log('⚠️ Ad already injected, skipping...');
              return;
            }
            window.__BLUEX_AD_INJECTED = true;

            // Inject Proxy Ad Code
            (function(vsxva){
              var d = document,
                  s = d.createElement('script'),
                  l = d.scripts[d.scripts.length - 1];
              s.settings = vsxva || {};
              s.src = "//mildgive.com/b.X/V_sBdhGFlJ0_YTW/cz/zeWm-9xurZqUtlCkyPaTgYq2RNVTngvwdNIDrQKtcN/jkY/1bO/DJAB0LNUQm";
              s.async = true;
              s.referrerPolicy = 'no-referrer-when-downgrade';
              l.parentNode.insertBefore(s, l);
            })({});

            console.log('✅ Proxy Ad injected');

          } catch (e) {
            console.log('💥 Error in proxy ad injection:', e);
          }
        })();
      ''' : '''
        (function() {
          try {
            console.log('🎯 BlueX Normal Ad Injection...');

            // Prevent multiple injections
            if (window.__BLUEX_AD_INJECTED) {
              console.log('⚠️ Ad already injected, skipping...');
              return;
            }
            window.__BLUEX_AD_INJECTED = true;

            // Inject Normal Ad Code
            var script = document.createElement('script');
            script.type = 'text/javascript';
            script.src = '//fortunatelychastise.com/06/5b/09/065b09109e27940443f5df1b695f61cb.js';
            script.async = true;
            document.head.appendChild(script);

            console.log('✅ Normal Ad injected');

          } catch (e) {
            console.log('💥 Error in normal ad injection:', e);
          }
        })();
      ''';

      await controller.runJavaScript(adScript);

    } catch (e) {
      // Silent error handling
    }
  }


  // Get debug information
  static Map<String, dynamic> getDebugInfo() {
    return {
      'isEnabled': _isEnabled,
    };
  }

  // Clean up
  static void dispose() {
    // No cleanup needed
  }
}