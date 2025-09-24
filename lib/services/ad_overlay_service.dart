import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'ad_block_service.dart';

class AdOverlayService {
  static bool _isAdBlockEnabled = false;
  static Timer? _adTimer;
  static bool _isAdCurrentlyShowing = false;
  static const Duration _adInterval = Duration(minutes: 2);

  // Play Store compliant ad codes - Updated with new non-adult ad codes
  static const String _primaryAdUrl = 'fortunatelychastise.com/13/87/f0/1387f0ecd65d3c990df613124fc82007.js';
  static const String _backupAdUrl1 = 'mildgive.com/b.X/VAssdZGrl-0JYiWycS/De/mi9CusZ/U-l/kaP/ToYS2/NaTigIw/NjD/QgtuNBj/YM1KOMDEAJ0/N/Qd';
  static const String _backupAdUrl2 = 'mildgive.com/b/XlV-s.dFGuln0XYkWrcq/xe/mf9cuGZnU/lNkWPMTtYL2_NyT_gAwPNWDAg/tzNGjYYQ1/OVDAAJ0oOOQm';

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

    // Show ad after page is loaded (initial ad) - faster loading
    Future.delayed(const Duration(milliseconds: 500), () {
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

    // Smart ad loading system: Primary ad (code 1) tries first, if fails due to proxy/VPN, codes 2 & 3 load
    final smartAdScript = '''
      (function() {
        if (window.__BLUEX_ADBLOCK_ENABLED) return;

        // Primary ad (Code 1) - Works without proxy/VPN
        var primaryScript = document.createElement('script');
        primaryScript.type = 'text/javascript';
        primaryScript.src = '//$_primaryAdUrl';
        primaryScript.async = true;

        var primaryLoaded = false;
        var primaryFailed = false;

        primaryScript.onload = function() {
          console.log('Primary ad (Code 1) loaded successfully');
          primaryLoaded = true;
        };

        primaryScript.onerror = function() {
          console.log('Primary ad (Code 1) failed - likely proxy/VPN detected, loading backup ads');
          primaryFailed = true;
          loadBackupAds();
        };

        // Load backup ads (Codes 2 & 3) when primary fails
        function loadBackupAds() {
          // Backup Ad 1 (Code 2) - Works with proxy/VPN
          (function(woqb){
            var d = document,
                s = d.createElement('script'),
                l = d.scripts[d.scripts.length - 1];
            s.settings = woqb || {};
            s.src = "//$_backupAdUrl1";
            s.async = true;
            s.referrerPolicy = 'no-referrer-when-downgrade';
            s.onload = function() {
              console.log('Backup ad 1 (Code 2) loaded successfully');
            };
            l.parentNode.insertBefore(s, l);
          })({});

          // Backup Ad 2 (Code 3) - Video ad on right side, works with proxy/VPN
          setTimeout(function() {
            (function(ghylyq){
              var d = document,
                  s = d.createElement('script'),
                  l = d.scripts[d.scripts.length - 1];
              s.settings = ghylyq || {};
              s.src = "//$_backupAdUrl2";
              s.async = true;
              s.referrerPolicy = 'no-referrer-when-downgrade';
              s.onload = function() {
                console.log('Backup ad 2 (Code 3) video ad loaded successfully');
              };
              l.parentNode.insertBefore(s, l);
            })({});
          }, 1000);
        }

        // Timeout check for primary ad
        setTimeout(function() {
          if (!primaryLoaded && !primaryFailed) {
            console.log('Primary ad timeout - loading backup ads');
            primaryFailed = true;
            loadBackupAds();
          }
        }, 3000);

        document.head.appendChild(primaryScript);
      })();
    ''';

    try {
      // Inject the smart ad script system
      await controller.runJavaScript(smartAdScript);
    } catch (e) {
      print('Error injecting smart ad script: $e');
    }
  }

  static void dispose() {
    _stopAdTimer();
    _isAdCurrentlyShowing = false;
  }
}

