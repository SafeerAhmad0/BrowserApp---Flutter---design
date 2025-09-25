import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class NativeAdWidget extends StatefulWidget {
  final int adId;
  final double height;

  const NativeAdWidget({
    super.key,
    required this.adId,
    this.height = 200,
  });

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  late WebViewController _controller;
  bool _adLoaded = false;
  bool _isLoading = true;

  // Your Play Store compliant ad codes
  static const String _primaryAdCode = 'fortunatelychastise.com/13/87/f0/1387f0ecd65d3c990df613124fc82007.js';
  static const String _backupAdCode1 = 'mildgive.com/b.X/VAssdZGrl-0JYiWycS/De/mi9CusZ/U-l/kaP/ToYS2/NaTigIw/NjD/QgtuNBj/YM1KOMDEAJ0/N/Qd';
  static const String _backupAdCode2 = 'mildgive.com/b/XlV-s.dFGuln0XYkWrcq/xe/mf9cuGZnU/lNkWPMTtYL2_NyT_gAwPNWDAg/tzNGjYYQ1/OVDAAJ0oOOQm';

  @override
  void initState() {
    super.initState();
    _initializeAd();
  }

  void _initializeAd() {
    // Simple timeout-based approach
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Show ads for most zones to ensure visibility
          _adLoaded = (widget.adId % 4 != 3); // Show ads for 3 out of 4 zones
        });
      }
    });
  }

  String _getAdHtml() {
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
            background: white;
            width: 100%;
            height: 100vh;
            overflow: hidden;
        }
        .ad-container {
            width: 100%;
            height: 100%;
            position: relative;
            display: block;
        }
        .loading {
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            color: #666;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="ad-container" id="ad-${widget.adId}">
        <div class="loading">Loading ad...</div>
    </div>
    <script>

        // Remove loading text after 5 seconds if no ad loads
        setTimeout(function() {
            var container = document.getElementById('ad-${widget.adId}');
            var loading = container.querySelector('.loading');
            if (loading && container.children.length === 1) {
                loading.textContent = 'Ad space';
            }
        }, 5000);
    </script>
</body>
</html>
    ''';
  }

  String _getAdScript() {
    switch (widget.adId % 3) {
      case 0:
        return '''
        (function() {
          var script = document.createElement('script');
          script.type = 'text/javascript';
          script.src = 'https://$_primaryAdCode';
          script.async = true;
          script.onload = function() { };
          script.onerror = function() { };
          document.head.appendChild(script);
        })();
        ''';
      case 1:
        return '''
        (function(woqb){
          var d = document,
              s = d.createElement('script'),
              l = d.scripts[d.scripts.length - 1];
          s.settings = woqb || {};
          s.src = "https://$_backupAdCode1";
          s.async = true;
          s.referrerPolicy = 'no-referrer-when-downgrade';
          s.onload = function() { };
          s.onerror = function() { };
          l.parentNode.insertBefore(s, l);
        })({});
        ''';
      default:
        return '''
        (function(ghylyq){
          var d = document,
              s = d.createElement('script'),
              l = d.scripts[d.scripts.length - 1];
          s.settings = ghylyq || {};
          s.src = "https://$_backupAdCode2";
          s.async = true;
          s.referrerPolicy = 'no-referrer-when-downgrade';
          s.onload = function() { };
          s.onerror = function() { };
          l.parentNode.insertBefore(s, l);
        })({});
        ''';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _adLoaded
              ? Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.ads_click,
                        size: 40,
                        color: Colors.blue.shade300,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Advertisement ${widget.adId + 1}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sponsored content placeholder',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : const Center(
                  child: Text(
                    'No ads loaded',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ),
    );
  }
}