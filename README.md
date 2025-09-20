# BlueX Browser - Flutter WebView App

BlueX is a production-ready mobile browser built with Flutter, featuring a WebView-based browsing experience with an integrated ad system, news feed, and comprehensive browser functionality.

**⚠️ CRITICAL: Replace all placeholder ad URLs before production deployment!**

## 🚀 Features

### Core Browser Features
- **Multi-tab browsing** with tab management
- **WebView integration** with full web compatibility
- **Blue-themed UI** following Material Design
- **Chrome-like search/URL bar** with auto-completion
- **Home button** that always returns to start page
- **Cache management** with one-click clear functionality

### Start Page
- **Google-style BlueX branding** with elegant typography
- **Quick-access icons** for popular sites:
  - ChatGPT, Grokai, Amazon, Daraz, YouTube, Facebook
- **Integrated news feed** with live content
- **Native-looking ad slots** seamlessly integrated

### Ad Management System
- **Smart ad overlay system** that appears after page load
- **Primary/fallback ad logic** with automatic failover
- **Ad Block toggle** for instant ad control
- **2-minute ad intervals** (configurable)
- **Proper ad labeling** as "Sponsored" content
- **JavaScript injection** for ad block detection

### Privacy & Controls
- **Desktop mode toggle** with user agent switching
- **Ad blocking** with persistent settings
- **Privacy-focused** design with user consent consideration
- **Cache clearing** for browsing data management

## 📱 Screenshots & UI Layout

The app follows the provided design specifications:

### Top Bar Layout
```
[🏠] [Search/URL Bar ----------------] [🔥/+] [📑] [⋮]
```

- **Left**: Home button (🏠)
- **Center**: Search/URL bar (Chrome-like)
- **Right**: Clear cache (🔥) or New tab (+), Tabs, Menu (⋮)

### Menu Items
- Translate (placeholder)
- Desktop Mode toggle
- Ad Block toggle
- Settings

### News Feed Pattern
```
News Article 1
News Article 2
[Advertisement Slot]
News Article 3
News Article 4
News Article 5
[Advertisement Slot]
News Article 6
News Article 7
News Article 8
[Advertisement Slot]
```

## 🔧 Setup Instructions

### Prerequisites
- Flutter SDK (latest stable version)
- Android Studio / Xcode for mobile development
- Firebase project (optional, for full functionality)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd BrowserApp---Flutter---design
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase (Optional)**
   ```bash
   # Install FlutterFire CLI if not already installed
   dart pub global activate flutterfire_cli

   # Configure Firebase for your project
   flutterfire configure --project=your-firebase-project-id
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

## 🎯 Ad Integration Setup

### IMPORTANT: Replace Placeholder URLs

Before deploying to production, you MUST replace the placeholder ad URLs in the code:

#### File Location: `lib/services/ad_overlay_service.dart` (lines 15-17)

```dart
// TODO: Replace these URLs with your actual ad script URLs before production
static const String _primaryAdUrl = 'PRIMARY_AD_URL';           // ⚠️ REPLACE THIS
static const String _backupAdUrl1 = 'BACKUP_AD_URL_1';         // ⚠️ REPLACE THIS
static const String _backupAdUrl2 = 'BACKUP_AD_URL_2';         // ⚠️ REPLACE THIS
```

**Replace with your actual ad script URLs:**
```dart
static const String _primaryAdUrl = 'your-high-cpm-ad-domain.com/script.js';
static const String _backupAdUrl1 = 'your-backup-ad-network1.com/ads.js';
static const String _backupAdUrl2 = 'your-backup-ad-network2.com/fallback.js';
```

### Ad Script Structure Implementation

The app implements your exact ad script requirements:

#### Primary Ad (High CPM)
```html
<script type='text/javascript' src='//PRIMARY_AD_URL'></script>
```

#### Backup Ad 1
```javascript
(function(qnnmh){
  var d = document, s = d.createElement('script'), l = d.scripts[d.scripts.length - 1];
  s.settings = qnnmh || {};
  s.src = "//BACKUP_AD_URL_1";
  s.async = true;
  s.referrerPolicy = 'no-referrer-when-downgrade';
  l.parentNode.insertBefore(s, l);
})({})
```

#### Backup Ad 2
```javascript
(function(agvsx){
  var d = document, s = d.createElement('script'), l = d.scripts[d.scripts.length - 1];
  s.settings = agvsx || {};
  s.src = "//BACKUP_AD_URL_2";
  s.async = true;
  s.referrerPolicy = 'no-referrer-when-downgrade';
  l.parentNode.insertBefore(s, l);
})({})
```

### Ad System Behavior

1. **Primary ad loads first** (highest CPM)
2. **If primary fails**, automatically tries backup ad 1
3. **If backup 1 fails**, tries backup ad 2
4. **Ads appear 2 seconds** after website loads
5. **Ads repeat every 2 minutes** while on same page
6. **Ad Block toggle** instantly disables all ads
7. **Native overlay system** for better control

### Ad Block Integration

The app sets a global JavaScript flag that ad scripts can check:
```javascript
window.__BLUEX_ADBLOCK_ENABLED = true/false
```

Ad scripts should respect this flag to avoid displaying when Ad Block is enabled.

## 🗞️ News API Integration

### Current Implementation
- Uses mock data for demonstration
- Implements the required 2→ad→3→ad→3→ad pattern
- Properly labels ad slots as "Sponsored"

### NewsAPI Configuration

**File**: `lib/services/news_service.dart` (line 42)

The app already includes NewsAPI integration. To use your own API key:

1. **Get NewsAPI key** from https://newsapi.org/
2. **Replace the API key**:
   ```dart
   static const String _apiKey = 'your_newsapi_key_here';  // ⚠️ REPLACE THIS
   ```

The news service includes fallback data if the API fails, ensuring the app always has content.

## 🔒 Privacy & Compliance

### GDPR/CCPA Compliance
- Add user consent dialogs before ad loading
- Implement privacy policy links
- Allow users to opt-out of tracking

### Platform Policies
- All ads are clearly labeled as "Sponsored"
- Ad scripts are sandboxed in overlay system
- No deceptive ad placement as editorial content
- Respects user Ad Block preferences

## 🚀 Development & Testing

### Testing Ad Integration
1. **Ensure Ad Block is disabled** (toggle in three-dot menu)
2. **Navigate to any website** using quick-access icons or URL bar
3. **Ad overlay appears** 2 seconds after page loads
4. **Test primary/backup fallback** by modifying ad URLs temporarily
5. **Verify Ad Block toggle** stops ads completely
6. **Test 2-minute intervals** by staying on same page

### Development Mode

To disable ads during development:

**File**: `lib/services/ad_overlay_service.dart` (line 4)
```dart
static bool _isAdBlockEnabled = true; // Set to true for development
```

Or modify in **File**: `lib/services/ad_block_service.dart` (line 4)
```dart
static bool _isEnabled = true; // Set to true to block ads during development
```

## 📂 Project Structure

```
lib/
├── main.dart                    # Main application entry point
├── components/                  # Reusable UI components
│   ├── search_bar.dart         # Chrome-like search bar
│   ├── news_card.dart          # News article cards
│   └── ...
├── screens/                    # Screen widgets
│   ├── home/                   # Main browser screen (BlueX start page)
│   ├── webview/               # WebView implementation
│   ├── tabs/                  # Tab management
│   ├── settings/              # App settings
│   └── ...
├── services/                  # Business logic services
│   ├── ad_overlay_service.dart    # ⚠️ Main ad system (REPLACE URLs HERE)
│   ├── ad_block_service.dart      # Ad blocking functionality
│   ├── news_service.dart          # NewsAPI integration (REPLACE API KEY)
│   └── ...
├── models/                    # Data models
└── firebase_options.dart      # Firebase configuration
```

### Key Files for Configuration

1. **Ad System**: `lib/services/ad_overlay_service.dart` - Replace ad URLs
2. **News API**: `lib/services/news_service.dart` - Replace API key
3. **Main UI**: `lib/screens/home/index.dart` - BlueX browser implementation
4. **Ad Blocking**: `lib/services/ad_block_service.dart` - Toggle settings

## 🔮 Future Enhancements

### TODO Items for Production

1. **Firebase Integration**
   - Analytics for user behavior
   - Push notifications for news updates
   - Remote configuration for ad settings

2. **Proxy Support**
   - Add proxy configuration in settings
   - Support for HTTP/HTTPS/SOCKS proxies
   - Per-app proxy settings

3. **Payment Integration**
   - Premium subscription for ad-free experience
   - In-app purchases for advanced features
   - Payment gateway integration

4. **Enhanced Features**
   - Bookmark management
   - Download manager
   - Incognito/private browsing mode
   - Voice search integration
   - Translation services
   - Reading mode

5. **Performance Optimizations**
   - Image compression for news feed
   - Lazy loading for better performance
   - Caching strategies for news content
   - Memory management for multiple tabs

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🛠️ Support

For issues, feature requests, or questions:
1. Check existing issues in the repository
2. Create a new issue with detailed description
3. Include device/platform information for bugs

## 🚨 Production Checklist

Before deploying to production:

- [ ] ✅ Replace `PRIMARY_AD_URL` in `ad_overlay_service.dart`
- [ ] ✅ Replace `BACKUP_AD_URL_1` in `ad_overlay_service.dart`
- [ ] ✅ Replace `BACKUP_AD_URL_2` in `ad_overlay_service.dart`
- [ ] ✅ Update NewsAPI key in `news_service.dart`
- [ ] ✅ Configure Firebase for production environment
- [ ] ✅ Test ad loading and fallback behavior
- [ ] ✅ Verify Ad Block toggle functionality
- [ ] ✅ Test multi-tab operations
- [ ] ✅ Validate news feed with ad slots (2→ad→3→ad→3→ad pattern)
- [ ] ✅ Check all quick-access icons work correctly
- [ ] ✅ Test cache clearing functionality
- [ ] ✅ Verify home button behavior
- [ ] ✅ Test top bar UI on different screen sizes
- [ ] ✅ Validate privacy compliance measures

## 📱 App Store Deployment

### Android (Google Play Store)
1. Update `android/app/build.gradle` with proper signing config
2. Test on multiple Android versions and devices
3. Ensure all required permissions are declared
4. Comply with Google Play policies for WebView apps

### iOS (App Store)
1. Configure proper iOS capabilities in Xcode
2. Test on multiple iOS versions and devices
3. Ensure compliance with App Store Review Guidelines
4. Configure proper app privacy labels

---

**⚠️ CRITICAL: This app is production-ready but requires ad URL replacement before deployment. All placeholder URLs MUST be updated with actual ad network URLs.**
