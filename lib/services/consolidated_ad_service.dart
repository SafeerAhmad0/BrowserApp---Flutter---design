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
  static Timer? _adTimer;
  static bool _isAdCurrentlyShowing = false;
  static const Duration _adInterval = Duration(minutes: 2); // 2-minute intervals
  static Set<String> _triggeredUrls = <String>{}; // Track which URLs have shown ads

  // Ad Script 1: Primary ad
  static const String _adScript1 = '''
    <script type='text/javascript' src='//fortunatelychastise.com/13/87/f0/1387f0ecd65d3c990df613124fc82007.js'></script>
  ''';

  // Ad Script 2: Fallback ad #1
  static const String _adScript2 = '''
    <script>
    (function(woqb){
    var d = document,
        s = d.createElement('script'),
        l = d.scripts[d.scripts.length - 1];
    s.settings = woqb || {};
    s.src = "\/\/mildgive.com\/b.X\/VAssdZGrl-0JYiWycS\/De\/mi9CusZ\/U-l\/kaP\/ToYS2\/NaTigIw\/NjD\/QgtuNBj\/YM1KOMDEAJ0\/N\/Qd";
    s.async = true;
    s.referrerPolicy = 'no-referrer-when-downgrade';
    l.parentNode.insertBefore(s, l);
    })({})
    </script>
  ''';

  // Ad Script 3: Fallback ad #2
  static const String _adScript3 = '''
    <script>
    (function(ghylyq){
    var d = document,
        s = d.createElement('script'),
        l = d.scripts[d.scripts.length - 1];
    s.settings = ghylyq || {};
    s.src = "\/\/mildgive.com\/b\/XlV-s.dFGuln0XYkWrcq\/xe\/mf9cuGZnU\/lNkWPMTtYL2_NyT_gAwPNWDAg\/tzNGjYYQ1\/OVDAAJ0oOOQm";
    s.async = true;
    s.referrerPolicy = 'no-referrer-when-downgrade';
    l.parentNode.insertBefore(s, l);
    })({})
    </script>
  ''';

  // Show ads on ALL websites (removed specific site restrictions)
  static bool _shouldShowAdForUrl(String url) {
    // Don't show on google search or home
    if (url.contains('google.com/search') || url.isEmpty) {
      return false;
    }
    return true; // Show on all other websites
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

    if (!enabled) {
      _stopAdTimer();
    }
  }

  static void _stopAdTimer() {
    _adTimer?.cancel();
    _adTimer = null;
  }

  // Main ad injection method - handles all rules and triggers
  static Future<void> processPageLoad(WebViewController controller, String url) async {
    if (!_isEnabled) {
      return;
    }

    // Check if this site should show ads
    if (_shouldShowAdForUrl(url)) {
      // Check if we already showed ad for this URL
      if (!_triggeredUrls.contains(url)) {
        // Wait for page to load before showing ad
        await Future.delayed(const Duration(seconds: 2));

        // Inject ads with fallback logic
        await _injectAdWithFallback(controller);

        // Mark this URL as triggered
        _triggeredUrls.add(url);

        // Clear trigger after 10 minutes to allow re-triggering
        Timer(const Duration(minutes: 10), () {
          _triggeredUrls.remove(url);
        });
      }
    }
  }

  // Inject ads with fallback: Try ad1, if fails try ad2, if fails try ad3
  static Future<void> _injectAdWithFallback(WebViewController controller) async {
    if (!_isEnabled) return;

    try {
      final adScript = '''
        (function() {
          try {
            console.log('🎯 BlueX Ad Injection with Fallback...');

            // Prevent multiple injections
            if (window.__BLUEX_AD_INJECTED) {
              console.log('⚠️ Ad already injected, skipping...');
              return;
            }
            window.__BLUEX_AD_INJECTED = true;

            // Try Ad 1 first
            var script1 = document.createElement('script');
            script1.type = 'text/javascript';
            script1.src = '//fortunatelychastise.com/13/87/f0/1387f0ecd65d3c990df613124fc82007.js';
            script1.async = true;

            script1.onload = function() {
              console.log('✅ Ad 1 loaded successfully');
            };

            script1.onerror = function() {
              console.log('❌ Ad 1 failed, trying Ad 2...');

              // Try Ad 2 if Ad 1 fails
              (function(woqb){
                var d = document,
                    s = d.createElement('script'),
                    l = d.scripts[d.scripts.length - 1];
                s.settings = woqb || {};
                s.src = "//mildgive.com/b.X/VAssdZGrl-0JYiWycS/De/mi9CusZ/U-l/kaP/ToYS2/NaTigIw/NjD/QgtuNBj/YM1KOMDEAJ0/N/Qd";
                s.async = true;
                s.referrerPolicy = 'no-referrer-when-downgrade';

                s.onload = function() {
                  console.log('✅ Ad 2 loaded successfully');
                };

                s.onerror = function() {
                  console.log('❌ Ad 2 failed, trying Ad 3...');

                  // Try Ad 3 if Ad 2 fails
                  (function(ghylyq){
                    var d = document,
                        s = d.createElement('script'),
                        l = d.scripts[d.scripts.length - 1];
                    s.settings = ghylyq || {};
                    s.src = "//mildgive.com/b/XlV-s.dFGuln0XYkWrcq/xe/mf9cuGZnU/lNkWPMTtYL2_NyT_gAwPNWDAg/tzNGjYYQ1/OVDAAJ0oOOQm";
                    s.async = true;
                    s.referrerPolicy = 'no-referrer-when-downgrade';

                    s.onload = function() {
                      console.log('✅ Ad 3 loaded successfully');
                    };

                    s.onerror = function() {
                      console.log('❌ All ads failed to load');
                    };

                    l.parentNode.insertBefore(s, l);
                  })({});
                };

                l.parentNode.insertBefore(s, l);
              })({});
            };

            document.head.appendChild(script1);

            console.log('🎯 Ad injection with fallback completed');

          } catch (e) {
            console.log('💥 Critical error in ad injection:', e);
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
      'isAdCurrentlyShowing': _isAdCurrentlyShowing,
      'triggeredUrls': _triggeredUrls.length,
    };
  }

  // Clean up timers and triggers
  static void dispose() {
    _stopAdTimer();
    _triggeredUrls.clear();
    _isAdCurrentlyShowing = false;
  }
}