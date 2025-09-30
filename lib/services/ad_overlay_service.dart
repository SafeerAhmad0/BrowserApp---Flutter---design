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
    Future.delayed(const Duration(milliseconds: 200), () {
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
    // REMOVED - All JavaScript injection consolidated to central service
  }

  static void dispose() {
    _stopAdTimer();
    _isAdCurrentlyShowing = false;
  }
}

