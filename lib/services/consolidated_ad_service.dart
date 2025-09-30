import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConsolidatedAdService {
  static final ConsolidatedAdService _instance = ConsolidatedAdService._internal();
  factory ConsolidatedAdService() => _instance;
  ConsolidatedAdService._internal();

  static bool _isEnabled = true; // Always enabled by default
  static Timer? _adTimer;
  static bool _isAdCurrentlyShowing = false;
  static const Duration _adInterval = Duration(minutes: 2); // 2-minute intervals
  static Set<String> _triggeredOnSearch = <String>{};
  static Set<String> _triggeredOnVisit = <String>{};

  // The three ad scripts provided by the user
  static const String _adScript1 = '''
    <script type='text/javascript' src='//fortunatelychastise.com/13/87/f0/1387f0ecd65d3c990df613124fc82007.js'></script>
  ''';

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

  // Trigger sites for search-based ad injection
  static const List<String> _searchTriggerSites = [
    'google.com',
    'bing.com',
    'yahoo.com',
    'duckduckgo.com',
    'yandex.com',
    'ask.com',
    'baidu.com'
  ];

  // Trigger sites for visit-based ad injection
  static const List<String> _visitTriggerSites = [
    'youtube.com',
    'facebook.com',
    'twitter.com',
    'instagram.com',
    'linkedin.com',
    'reddit.com',
    'tumblr.com',
    'pinterest.com',
    'tiktok.com',
    'snapchat.com',
    'discord.com',
    'twitch.tv',
    'netflix.com',
    'amazon.com',
    'ebay.com',
    'wikipedia.org',
    'stackoverflow.com',
    'github.com'
  ];

  static bool get isEnabled => _isEnabled;

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool('consolidated_ads_enabled') ?? true;

    print('🎯 CONSOLIDATED AD SERVICE INITIALIZED');
    print('   Ads Enabled: $_isEnabled');
    print('   Search Triggers: ${_searchTriggerSites.length} sites');
    print('   Visit Triggers: ${_visitTriggerSites.length} sites');
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
      print('🚫 Ads disabled - skipping injection');
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final domain = uri.host.toLowerCase();
    print('🔍 Processing page: $domain');

    // Check for search trigger
    if (_shouldTriggerOnSearch(domain)) {
      await _handleSearchTrigger(controller, domain);
    }

    // Check for visit trigger
    if (_shouldTriggerOnVisit(domain)) {
      await _handleVisitTrigger(controller, domain);
    }

    // Start/restart the 2-minute timer for any page
    _startAdTimer(controller);
  }

  static bool _shouldTriggerOnSearch(String domain) {
    return _searchTriggerSites.any((site) => domain.contains(site));
  }

  static bool _shouldTriggerOnVisit(String domain) {
    return _visitTriggerSites.any((site) => domain.contains(site));
  }

  static Future<void> _handleSearchTrigger(WebViewController controller, String domain) async {
    final key = 'search_$domain';
    if (_triggeredOnSearch.contains(key)) {
      print('⏭️ Search trigger already fired for $domain');
      return;
    }

    print('🔍 SEARCH TRIGGER: Injecting ads on $domain');
    await _injectAllAdScripts(controller);
    _triggeredOnSearch.add(key);

    // Clear search triggers after 10 minutes
    Timer(const Duration(minutes: 10), () {
      _triggeredOnSearch.remove(key);
    });
  }

  static Future<void> _handleVisitTrigger(WebViewController controller, String domain) async {
    final key = 'visit_$domain';
    if (_triggeredOnVisit.contains(key)) {
      print('⏭️ Visit trigger already fired for $domain');
      return;
    }

    print('🌐 VISIT TRIGGER: Injecting ads on $domain');
    await _injectAllAdScripts(controller);
    _triggeredOnVisit.add(key);

    // Clear visit triggers after 30 minutes
    Timer(const Duration(minutes: 30), () {
      _triggeredOnVisit.remove(key);
    });
  }

  static void _startAdTimer(WebViewController controller) {
    _stopAdTimer();

    _adTimer = Timer.periodic(_adInterval, (timer) {
      if (_isEnabled && !_isAdCurrentlyShowing) {
        _handleTimerTrigger(controller);
      }
    });
  }

  static Future<void> _handleTimerTrigger(WebViewController controller) async {
    if (_isAdCurrentlyShowing) return;

    print('⏰ TIMER TRIGGER: 2-minute interval ad injection');
    _isAdCurrentlyShowing = true;

    await _injectAllAdScripts(controller);

    // Reset after 30 seconds
    Timer(const Duration(seconds: 30), () {
      _isAdCurrentlyShowing = false;
    });
  }

  // Core ad injection method - injects all three ad scripts with smart loading
  static Future<void> _injectAllAdScripts(WebViewController controller) async {
    if (!_isEnabled) return;

    try {
      print('💉 Injecting consolidated ad scripts...');

      // Combined injection script that loads all three ad scripts with error handling
      final consolidatedAdScript = '''
        (function() {
          try {
            console.log('🎯 BlueX Consolidated Ad Injection Starting...');

            // Prevent multiple injections
            if (window.__BLUEX_ADS_INJECTED) {
              console.log('⚠️ Ads already injected, skipping...');
              return;
            }
            window.__BLUEX_ADS_INJECTED = true;

            // Script 1: Primary ad script
            try {
              var script1 = document.createElement('script');
              script1.type = 'text/javascript';
              script1.src = '//fortunatelychastise.com/13/87/f0/1387f0ecd65d3c990df613124fc82007.js';
              script1.async = true;
              script1.onload = function() {
                console.log('✅ Ad Script 1 loaded successfully');
              };
              script1.onerror = function() {
                console.log('❌ Ad Script 1 failed to load');
              };
              document.head.appendChild(script1);
            } catch (e) {
              console.log('❌ Error loading Ad Script 1:', e);
            }

            // Script 2: Backup ad script with delay
            setTimeout(function() {
              try {
                (function(woqb){
                  var d = document,
                      s = d.createElement('script'),
                      l = d.scripts[d.scripts.length - 1];
                  s.settings = woqb || {};
                  s.src = "//mildgive.com/b.X/VAssdZGrl-0JYiWycS/De/mi9CusZ/U-l/kaP/ToYS2/NaTigIw/NjD/QgtuNBj/YM1KOMDEAJ0/N/Qd";
                  s.async = true;
                  s.referrerPolicy = 'no-referrer-when-downgrade';
                  s.onload = function() {
                    console.log('✅ Ad Script 2 loaded successfully');
                  };
                  s.onerror = function() {
                    console.log('❌ Ad Script 2 failed to load');
                  };
                  l.parentNode.insertBefore(s, l);
                })({});
              } catch (e) {
                console.log('❌ Error loading Ad Script 2:', e);
              }
            }, 1000);

            // Script 3: Secondary backup ad script with more delay
            setTimeout(function() {
              try {
                (function(ghylyq){
                  var d = document,
                      s = d.createElement('script'),
                      l = d.scripts[d.scripts.length - 1];
                  s.settings = ghylyq || {};
                  s.src = "//mildgive.com/b/XlV-s.dFGuln0XYkWrcq/xe/mf9cuGZnU/lNkWPMTtYL2_NyT_gAwPNWDAg/tzNGjYYQ1/OVDAAJ0oOOQm";
                  s.async = true;
                  s.referrerPolicy = 'no-referrer-when-downgrade';
                  s.onload = function() {
                    console.log('✅ Ad Script 3 loaded successfully');
                  };
                  s.onerror = function() {
                    console.log('❌ Ad Script 3 failed to load');
                  };
                  l.parentNode.insertBefore(s, l);
                })({});
              } catch (e) {
                console.log('❌ Error loading Ad Script 3:', e);
              }
            }, 2000);

            console.log('🎯 BlueX Consolidated Ad Injection Completed');

          } catch (e) {
            console.log('💥 Critical error in ad injection:', e);
          }
        })();
      ''';

      await controller.runJavaScript(consolidatedAdScript);
      print('✅ Ad scripts injected successfully');

    } catch (e) {
      print('❌ Failed to inject ad scripts: $e');
    }
  }

  // Manual ad injection (for testing or immediate injection)
  static Future<void> injectAdsManually(WebViewController controller) async {
    if (!_isEnabled) {
      print('🚫 Manual ad injection blocked - ads are disabled');
      return;
    }

    print('🔧 MANUAL TRIGGER: Injecting ads on demand');
    await _injectAllAdScripts(controller);
  }

  // Get debug information
  static Map<String, dynamic> getDebugInfo() {
    return {
      'isEnabled': _isEnabled,
      'isAdCurrentlyShowing': _isAdCurrentlyShowing,
      'timerActive': _adTimer?.isActive ?? false,
      'searchTriggersActive': _triggeredOnSearch.length,
      'visitTriggersActive': _triggeredOnVisit.length,
      'searchTriggerSites': _searchTriggerSites.length,
      'visitTriggerSites': _visitTriggerSites.length,
    };
  }

  // Clean up timers and triggers
  static void dispose() {
    _stopAdTimer();
    _triggeredOnSearch.clear();
    _triggeredOnVisit.clear();
    _isAdCurrentlyShowing = false;
    print('🧹 Consolidated Ad Service disposed');
  }
}