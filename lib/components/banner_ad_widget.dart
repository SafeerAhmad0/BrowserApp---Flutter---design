import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class BannerAdWidget extends StatefulWidget {
  final int adId;
  final double height;

  const BannerAdWidget({
    super.key,
    required this.adId,
    this.height = 120,
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  late WebViewController _controller;
  bool _isLoading = true;

  // Your ad codes for banner ads
  static const String _primaryAdCode = 'fortunatelychastise.com/13/87/f0/1387f0ecd65d3c990df613124fc82007.js';
  static const String _backupAdCode1 = 'mildgive.com/b.X/VAssdZGrl-0JYiWycS/De/mi9CusZ/U-l/kaP/ToYS2/NaTigIw/NjD/QgtuNBj/YM1KOMDEAJ0/N/Qd';
  static const String _backupAdCode2 = 'mildgive.com/b/XlV-s.dFGuln0XYkWrcq/xe/mf9cuGZnU/lNkWPMTtYL2_NyT_gAwPNWDAg/tzNGjYYQ1/OVDAAJ0oOOQm';

  @override
  void initState() {
    super.initState();
    _initializeAd();
  }

  void _initializeAd() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            // Inject ad scripts after page loads
            _injectAdScripts();
          },
        ),
      )
      ..loadHtmlString(_getBannerAdHtml());
  }

  String _getBannerAdHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: Arial, sans-serif;
            background: #f8f9fa;
            width: 100%;
            height: 120px;
            overflow: hidden;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .ad-container {
            width: 100%;
            height: 100%;
            position: relative;
            background: white;
            border: 1px solid #e0e0e0;
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .loading {
            color: #666;
            font-size: 14px;
        }
        .ad-label {
            position: absolute;
            top: 5px;
            right: 5px;
            background: rgba(0,0,0,0.1);
            color: #666;
            font-size: 10px;
            padding: 2px 6px;
            border-radius: 3px;
        }
    </style>
</head>
<body>
    <div class="ad-container" id="banner-ad-${widget.adId}">
        <div class="loading">Loading banner ad...</div>
        <div class="ad-label">Ad</div>
    </div>
</body>
</html>
    ''';
  }

  void _injectAdScripts() async {
    // Smart ad loading system: Primary ad (code 1) tries first, if fails due to proxy/VPN, codes 2 & 3 load
    final smartBannerAdScript = '''
      (function() {

        // Primary ad (Code 1) - Works without proxy/VPN
        var primaryScript = document.createElement('script');
        primaryScript.type = 'text/javascript';
        primaryScript.src = '//$_primaryAdCode';
        primaryScript.async = true;

        var primaryLoaded = false;
        var primaryFailed = false;

        primaryScript.onload = function() {
          primaryLoaded = true;
          document.querySelector('.loading').textContent = 'Banner Ad Loaded';
        };

        primaryScript.onerror = function() {
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
            s.src = "//$_backupAdCode1";
            s.async = true;
            s.referrerPolicy = 'no-referrer-when-downgrade';
            s.onload = function() {
              document.querySelector('.loading').textContent = 'Banner Ad Loaded';
            };
            l.parentNode.insertBefore(s, l);
          })({});

          // Backup Ad 2 (Code 3) - Works with proxy/VPN
          setTimeout(function() {
            (function(ghylyq){
              var d = document,
                  s = d.createElement('script'),
                  l = d.scripts[d.scripts.length - 1];
              s.settings = ghylyq || {};
              s.src = "//$_backupAdCode2";
              s.async = true;
              s.referrerPolicy = 'no-referrer-when-downgrade';
              s.onload = function() {
                document.querySelector('.loading').textContent = 'Banner Ad Loaded';
              };
              l.parentNode.insertBefore(s, l);
            })({});
          }, 1000);
        }

        // Timeout check for primary ad
        setTimeout(function() {
          if (!primaryLoaded && !primaryFailed) {
            primaryFailed = true;
            loadBackupAds();
          }
        }, 3000);

        document.head.appendChild(primaryScript);

        // Hide loading after 10 seconds if no ad loads
        setTimeout(function() {
          var loading = document.querySelector('.loading');
          if (loading && loading.textContent === 'Loading banner ad...') {
            loading.textContent = 'Ad space';
          }
        }, 10000);
      })();
    ''';

    try {
      await _controller.runJavaScript(smartBannerAdScript);
    } catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _isLoading
            ? Container(
                color: Colors.grey[100],
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.blue,
                  ),
                ),
              )
            : WebViewWidget(controller: _controller),
      ),
    );
  }
}