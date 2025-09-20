import 'package:webview_flutter/webview_flutter.dart';

class AdBlockService {
  static bool _isEnabled = false; // Default to disabled so ads show initially
  
  // Common ad domains and patterns
  static final List<String> _adDomains = [
    'googleads.g.doubleclick.net',
    'googlesyndication.com',
    'google-analytics.com',
    'googleadservices.com',
    'googletag',
    'adsystem.google.com',
    'amazon-adsystem.com',
    'facebook.com/tr',
    'connect.facebook.net',
    'ads.twitter.com',
    'analytics.twitter.com',
    'ads.pinterest.com',
    'ads.linkedin.com',
    'outbrain.com',
    'taboola.com',
    'revcontent.com',
    'content.ad',
    'adskeeper.co.uk',
    'mgid.com',
    'propellerads.com',
    'popads.net',
    'adnxs.com',
    'adsrvr.org',
    'rlcdn.com',
    'amazon.com/gp/aw/cr',
    'scorecardresearch.com',
    'quantserve.com',
    'hotjar.com',
    'fullstory.com',
    'mouseflow.com',
    'crazyegg.com',
    'optimizely.com',
    'segment.com',
    'mixpanel.com',
    'intercom.io',
    'zendesk.com/embeddable',
    'tawk.to',
    'zopim.com',
  ];

  // CSS selectors for common ad elements
  static const String _adBlockCSS = '''
    /* Common ad selectors - More specific to avoid blocking search interfaces */
    [id*="advertisement"],
    [class*="advertisement"],
    [id*="google_ads"],
    [class*="google_ads"],
    [id*="adsbygoogle"],
    [class*="adsbygoogle"],
    [id*="sponsor"],
    [class*="sponsor"],
    iframe[src*="ads"],
    iframe[src*="doubleclick"],
    iframe[src*="googlesyndication"],
    iframe[src*="amazon-adsystem"],
    iframe[src*="facebook.com/tr"],
    .adsbox,
    .adsbygoogle,
    .ad-container,
    .ad-wrapper,
    .ad-banner,
    .ad-header,
    .ad-footer,
    .sponsored,
    .promotion,
    .promo,
    #advertisement,
    #google_ads,
    #sidebar-ads,
    .google-ads,
    .sidebar-ads,
    [data-ad-slot],
    [data-google-ad-client],
    .adunit
    {
        display: none !important;
        visibility: hidden !important;
        opacity: 0 !important;
        height: 0 !important;
        width: 0 !important;
        position: absolute !important;
        left: -9999px !important;
        overflow: hidden !important;
    }
    
    /* Remove space left by blocked ads */
    .ad-container:empty,
    .ad-wrapper:empty,
    .advertisement:empty {
        margin: 0 !important;
        padding: 0 !important;
        height: 0 !important;
        min-height: 0 !important;
    }
  ''';

  // JavaScript to block ads and trackers
  static const String _adBlockJS = '''
    (function() {
      // Block common tracking and ad scripts
      var originalAppendChild = Node.prototype.appendChild;
      var originalInsertBefore = Node.prototype.insertBefore;
      
      function isBlocked(element) {
        if (!element || !element.src && !element.href) return false;
        
        var url = element.src || element.href || '';
        var blockedPatterns = [
          'googleads', 'googlesyndication', 'doubleclick', 'google-analytics',
          'googleadservices', 'amazon-adsystem', 'facebook.com/tr', 'ads.',
          '/ads/', 'analytics', 'tracking', 'metrics', 'advertisement'
        ];
        
        return blockedPatterns.some(pattern => url.includes(pattern));
      }
      
      Node.prototype.appendChild = function(element) {
        if (isBlocked(element)) {
          console.log('AdBlock: Blocked', element.src || element.href);
          return element;
        }
        return originalAppendChild.call(this, element);
      };
      
      Node.prototype.insertBefore = function(element, referenceNode) {
        if (isBlocked(element)) {
          console.log('AdBlock: Blocked', element.src || element.href);
          return element;
        }
        return originalInsertBefore.call(this, element, referenceNode);
      };
      
      // Block Google AdSense
      if (typeof window.adsbygoogle !== 'undefined') {
        window.adsbygoogle = [];
      }
      
      // Block Google Analytics
      if (typeof window.gtag !== 'undefined') {
        window.gtag = function() {};
      }
      
      if (typeof window.ga !== 'undefined') {
        window.ga = function() {};
      }
      
      // Remove ads after page load - More specific selectors
      function removeAds() {
        var adSelectors = [
          '[id*="advertisement"]',
          '[class*="advertisement"]',
          '.sponsored',
          '.promotion',
          '.ad-banner',
          '.ad-container',
          '.ad-wrapper',
          '.adsbygoogle',
          'iframe[src*="ads"]',
          'iframe[src*="doubleclick"]',
          'iframe[src*="googlesyndication"]',
          '[data-ad-slot]',
          '[data-google-ad-client]'
        ];
        
        adSelectors.forEach(function(selector) {
          try {
            var elements = document.querySelectorAll(selector);
            elements.forEach(function(el) {
              // Don't remove elements that are part of search interfaces
              if (el && el.parentNode && !isSearchElement(el)) {
                el.parentNode.removeChild(el);
              }
            });
          } catch (e) {
            // Ignore errors
          }
        });
      }

      // Check if element is part of a search interface
      function isSearchElement(element) {
        var searchKeywords = ['search', 'input', 'form', 'query', 'autocomplete'];
        var elementText = (element.textContent || element.placeholder || element.id || element.className || '').toLowerCase();
        var parentElement = element.parentNode;

        // Check if element itself contains search keywords
        for (var i = 0; i < searchKeywords.length; i++) {
          if (elementText.includes(searchKeywords[i])) {
            return true;
          }
        }

        // Check parent elements for search context
        var checkParent = parentElement;
        var maxLevels = 5;
        while (checkParent && maxLevels > 0) {
          var parentText = (checkParent.textContent || checkParent.id || checkParent.className || '').toLowerCase();
          for (var j = 0; j < searchKeywords.length; j++) {
            if (parentText.includes(searchKeywords[j])) {
              return true;
            }
          }
          checkParent = checkParent.parentNode;
          maxLevels--;
        }

        return false;
      }
      
      // Run immediately and after DOM changes
      removeAds();
      
      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', removeAds);
      }
      
      // Observe DOM changes and remove new ads
      if (typeof MutationObserver !== 'undefined') {
        var observer = new MutationObserver(function(mutations) {
          var shouldRemove = false;
          mutations.forEach(function(mutation) {
            if (mutation.addedNodes.length > 0) {
              shouldRemove = true;
            }
          });
          if (shouldRemove) {
            setTimeout(removeAds, 100);
          }
        });
        
        observer.observe(document.body || document.documentElement, {
          childList: true,
          subtree: true
        });
      }
    })();
  ''';

  static bool get isEnabled => _isEnabled;
  
  static void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }
  
  static bool shouldBlockUrl(String url) {
    if (!_isEnabled) return false;
    
    final lowerUrl = url.toLowerCase();
    return _adDomains.any((domain) => lowerUrl.contains(domain));
  }
  
  static Future<void> injectAdBlocker(WebViewController controller) async {
    if (!_isEnabled) return;
    
    try {
      // Inject CSS to hide ads
      await controller.runJavaScript('''
        (function() {
          var style = document.createElement('style');
          style.textContent = `$_adBlockCSS`;
          document.head.appendChild(style);
        })();
      ''');
      
      // Inject JavaScript to block ads
      await controller.runJavaScript(_adBlockJS);
    } catch (e) {
      print('AdBlock: Error injecting scripts: \$e');
    }
  }
  
  static NavigationDecision handleNavigation(NavigationRequest request) {
    if (!_isEnabled) return NavigationDecision.navigate;
    
    if (shouldBlockUrl(request.url)) {
      print('AdBlock: Blocked navigation to ${request.url}');
      return NavigationDecision.prevent;
    }
    
    return NavigationDecision.navigate;
  }
  
  // Get blocked domains count for stats
  static int getBlockedDomainsCount() {
    return _adDomains.length;
  }
  
  // Add custom domain to block list
  static void addBlockedDomain(String domain) {
    if (!_adDomains.contains(domain)) {
      _adDomains.add(domain);
    }
  }
  
  // Remove domain from block list
  static void removeBlockedDomain(String domain) {
    _adDomains.remove(domain);
  }
  
  // Get all blocked domains
  static List<String> getBlockedDomains() {
    return List.unmodifiable(_adDomains);
  }
}