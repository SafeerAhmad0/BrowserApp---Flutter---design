import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'ad_block_service.dart';

class AdOverlayService {
  static bool _isAdBlockEnabled = false;
  static Timer? _adTimer;
  static bool _isAdCurrentlyShowing = false;
  static const Duration _adInterval = Duration(minutes: 2);

  // TODO: Replace these URLs with your actual ad script URLs before production
  static const String _primaryAdUrl = 'fortunatelychastise.com/13/87/f0/1387f0ecd65d3c990df613124fc82007.js';
  static const String _backupAdUrl1 = 'primarycontest.com/bYXUVYsTd.Ggl/0IYWWCcM/fe/mT9Tu/ZgUSlkkaPxTeYK2/NCTOExyENOzxg/t/NjjIYE1eMcTMIi3_OiQ-';
  static const String _backupAdUrl2 = 'primarycontest.com/bvXHVusVd.GIl_0lYGWtcv/Ge/mH9VuBZOUhlckcP/T/Yv2xNVThEAy-NnzHQQtCNJj/Yp1vM/TKIP3pNxQO';

  static void setAdBlockEnabled(bool enabled) {
    _isAdBlockEnabled = enabled;
    if (enabled) {
      _stopAdTimer();
    }
  }

  static bool get isAdBlockEnabled => _isAdBlockEnabled;

  static void startAdTimer(BuildContext context, WebViewController controller) {
    if (_isAdBlockEnabled) return;

    _stopAdTimer();
    _adTimer = Timer.periodic(_adInterval, (timer) {
      if (!_isAdBlockEnabled && !_isAdCurrentlyShowing) {
        _showOverlayAd(context, controller);
      }
    });
  }

  static void _stopAdTimer() {
    _adTimer?.cancel();
    _adTimer = null;
  }

  static void showInitialAd(BuildContext context, WebViewController controller) {
    if (_isAdBlockEnabled) {
      return;
    }

    // Show ad after page is loaded (initial ad)
    Future.delayed(const Duration(seconds: 2), () {
      if (!_isAdBlockEnabled && !_isAdCurrentlyShowing) {
        _showOverlayAd(context, controller);
      }
    });
  }

  static void _showOverlayAd(BuildContext context, WebViewController controller) {
    if (_isAdCurrentlyShowing || _isAdBlockEnabled) {
      return;
    }

    // Just inject the ad scripts silently
    _isAdCurrentlyShowing = true;
    injectAdScripts(controller).then((_) {
      // Reset after 30 seconds to allow next ad
      Future.delayed(const Duration(seconds: 30), () {
        _isAdCurrentlyShowing = false;
      });
    });
  }

  static void _tryBackupAd(BuildContext context) {
    // No popup - ads work silently in background
    return;
  }

  static Future<void> injectAdScripts(WebViewController controller) async {
    if (_isAdBlockEnabled) {
      // Inject ad block flag
      await controller.runJavaScript('''
        window.__BLUEX_ADBLOCK_ENABLED = true;
      ''');
      return;
    }

    // Inject ad block flag as false
    await controller.runJavaScript('''
      window.__BLUEX_ADBLOCK_ENABLED = false;
    ''');

    // Primary high-CPM ad script
    final primaryAdScript = '''
      (function() {
        if (window.__BLUEX_ADBLOCK_ENABLED) return;

        var script = document.createElement('script');
        script.type = 'text/javascript';
        script.src = '//$_primaryAdUrl';
        script.onerror = function() {
          console.log('Primary ad failed to load, trying backup');
          window.__BLUEX_PRIMARY_AD_FAILED = true;
        };
        script.onload = function() {
          console.log('Primary ad loaded successfully');
          window.__BLUEX_PRIMARY_AD_LOADED = true;
        };
        document.head.appendChild(script);
      })();
    ''';

    // Backup ad 1 script
    final backupAd1Script = '''
      (function() {
        if (window.__BLUEX_ADBLOCK_ENABLED) return;

        // Wait a bit for primary ad to load or fail
        setTimeout(function() {
          if (!window.__BLUEX_PRIMARY_AD_LOADED && window.__BLUEX_PRIMARY_AD_FAILED) {
            (function(qnnmh){
              var d = document, s = d.createElement('script'), l = d.scripts[d.scripts.length - 1];
              s.settings = qnnmh || {};
              s.src = "//$_backupAdUrl1";
              s.async = true;
              s.referrerPolicy = 'no-referrer-when-downgrade';
              s.onerror = function() {
                console.log('Backup ad 1 failed to load');
                window.__BLUEX_BACKUP1_AD_FAILED = true;
              };
              s.onload = function() {
                console.log('Backup ad 1 loaded successfully');
                window.__BLUEX_BACKUP1_AD_LOADED = true;
              };
              l.parentNode.insertBefore(s, l);
            })({});
          }
        }, 2000);
      })();
    ''';

    // Backup ad 2 script
    final backupAd2Script = '''
      (function() {
        if (window.__BLUEX_ADBLOCK_ENABLED) return;

        // Wait for primary and backup1 to load or fail
        setTimeout(function() {
          if (!window.__BLUEX_PRIMARY_AD_LOADED &&
              !window.__BLUEX_BACKUP1_AD_LOADED &&
              window.__BLUEX_PRIMARY_AD_FAILED &&
              window.__BLUEX_BACKUP1_AD_FAILED) {
            (function(agvsx){
              var d = document, s = d.createElement('script'), l = d.scripts[d.scripts.length - 1];
              s.settings = agvsx || {};
              s.src = "//$_backupAdUrl2";
              s.async = true;
              s.referrerPolicy = 'no-referrer-when-downgrade';
              s.onload = function() {
                console.log('Backup ad 2 loaded successfully');
              };
              l.parentNode.insertBefore(s, l);
            })({});
          }
        }, 4000);
      })();
    ''';

    try {
      // Inject scripts one by one
      await controller.runJavaScript(primaryAdScript);
      await controller.runJavaScript(backupAd1Script);
      await controller.runJavaScript(backupAd2Script);
    } catch (e) {
      print('Error injecting ad scripts: $e');
    }
  }

  static void dispose() {
    _stopAdTimer();
    _isAdCurrentlyShowing = false;
  }
}

