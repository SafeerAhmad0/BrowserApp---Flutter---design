import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  static Future<void> initialize() async {
    // Initialize local notifications
    const androidInitialize = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOSInitialize = DarwinInitializationSettings();
    const initializationsSettings = InitializationSettings(
      android: androidInitialize,
      iOS: iOSInitialize,
    );

    await _localNotifications.initialize(
      initializationsSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleLocalNotificationTap(response);
      },
    );

    // Check if app was launched from a local notification tap
    print('🔍 Checking if app was launched from notification...');
    final notificationAppLaunchDetails = await _localNotifications.getNotificationAppLaunchDetails();
    print('🔍 notificationAppLaunchDetails: $notificationAppLaunchDetails');
    print('🔍 didNotificationLaunchApp: ${notificationAppLaunchDetails?.didNotificationLaunchApp}');

    if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
      final response = notificationAppLaunchDetails!.notificationResponse;
      print('🚀 ✅ YES! App WAS launched from local notification!');
      print('🚀 Response: $response');
      print('🚀 Payload: ${response?.payload}');

      if (response != null) {
        print('🚀 Calling _handleLocalNotificationTap with payload: ${response.payload}');
        await _handleLocalNotificationTap(response);
        print('✅ ✅ Finished handling notification launch');
      } else {
        print('❌ Response is null!');
      }
    } else {
      print('🔍 ❌ App was NOT launched from notification (normal launch)');
    }

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    // Handle notification taps when app is terminated or in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message);
    });

    // Check for initial message if app was opened from a notification
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // Start listening to Realtime Database for admin notifications
    await _startRealtimeNotificationListener();
  }

  

  // Listen to Realtime Database 'notifications' and show local notifications on new items
  static Future<void> _startRealtimeNotificationListener() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSeen = prefs.getInt('last_seen_notification_sent_at') ?? 0;

      final db = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://bluex-browser-default-rtdb.firebaseio.com',
      );

      final ref = db.ref('notifications');

      // Use onChildAdded to react to new notifications without requiring index rules
      ref.onChildAdded.listen((event) async {
        final val = event.snapshot.value;
        if (val is Map) {
          final data = Map<String, dynamic>.from(val as Map);
          final int sentAt = (data['sentAt'] is int) ? data['sentAt'] as int : 0;

          // Only notify if it's newer than last seen
          if (sentAt > (prefs.getInt('last_seen_notification_sent_at') ?? 0)) {
            final String title = (data["title"] ?? 'Announcement').toString();
            final String body = (data['body'] ?? '').toString();
            final String? actionUrl = (data['actionUrl'] as String?);
            final String? imageUrl = (data['imageUrl'] as String?);

            print('🔥 NEW NOTIFICATION from Firebase:');
            print('   Title: $title');
            print('   Body: $body');
            print('   Action URL: $actionUrl');
            print('   Image URL: $imageUrl');

            await showLocal(title: title, body: body, payload: actionUrl, imageUrl: imageUrl);

            // Update last seen
            await prefs.setInt('last_seen_notification_sent_at', sentAt);
          }
        }
      });
    } catch (e) {
      // Swallow errors to avoid crashing
    }
  }

  static Future<void> requestPermission() async {
    final prefs = await SharedPreferences.getInstance();
    final lastRequest = prefs.getString('last_notification_request');
    final now = DateTime.now().toIso8601String();

    // Check if we've already requested permission today
    if (lastRequest != null) {
      final lastRequestDate = DateTime.parse(lastRequest);
      final difference = DateTime.now().difference(lastRequestDate);
      if (difference.inDays < 1) {
        return; // Don't request again within 24 hours
      }
    }

    // Request permission
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Get FCM token
      String? token = await _firebaseMessaging.getToken();

      // Save the request date
      await prefs.setString('last_notification_request', now);
    }
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'browser_app_channel',
      'Browser App Notifications',
      channelDescription: 'Notifications from Browser App',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'ticker',
      autoCancel: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    const iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await _localNotifications.show(
      notificationId,
      message.notification?.title ?? message.data['title'] ?? 'New notification',
      message.notification?.body ?? message.data['body'] ?? '',
      details,
      payload: message.data['actionUrl'] ?? '',
    );
  }

  static Future<Uint8List?> _downloadImageBytes(String url) async {
    try {
      print('📥 Processing notification image: ${url.substring(0, 50)}...');

      // Check if it's a base64 data URL
      if (url.startsWith('data:image')) {
        print('🖼️ Detected base64 image data URL');
        // Extract base64 data from data URL format: data:image/png;base64,iVBORw0K...
        final base64String = url.split(',')[1];
        final bytes = base64Decode(base64String);
        print('✅ Base64 image decoded successfully, size: ${bytes.length} bytes');
        return bytes;
      }
      // Otherwise, treat it as a regular HTTP URL
      else if (url.startsWith('http://') || url.startsWith('https://')) {
        print('🌐 Detected HTTP URL, downloading...');
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          print('✅ Image downloaded successfully, size: ${response.bodyBytes.length} bytes');
          return response.bodyBytes;
        } else {
          print('❌ Failed to download image, status code: ${response.statusCode}');
        }
      } else {
        print('❌ Unknown image URL format');
      }
    } catch (e) {
      print('❌ Error processing notification image: $e');
    }
    return null;
  }

  static Future<void> showLocal({
    required String title,
    required String body,
    String? payload,
    String? imageUrl,
  }) async {
    print('🔔 Creating notification: $title');
    if (imageUrl != null && imageUrl.isNotEmpty) {
      print('🖼️ Image URL provided: $imageUrl');
    }
    if (payload != null && payload.isNotEmpty) {
      print('🔗 Action URL provided: $payload');
    }

    // Add URL to notification body if present
    String enhancedBody = body;
    if (payload != null && payload.isNotEmpty) {
      enhancedBody = '$body\n\n🔗 Tap to open: $payload';
    }

    AndroidNotificationDetails androidDetails;

    // Download image bytes if URL is provided
    Uint8List? imageBytes;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      imageBytes = await _downloadImageBytes(imageUrl);
      if (imageBytes != null) {
        print('✅ Using image in notification');
      } else {
        print('⚠️ Failed to download image, showing notification without image');
      }
    }

    // Create notification with or without image
    if (imageBytes != null) {
      androidDetails = AndroidNotificationDetails(
        'browser_app_channel',
        'Browser App Notifications',
        channelDescription: 'Notifications from Browser App',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'ticker',
        autoCancel: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        largeIcon: ByteArrayAndroidBitmap(imageBytes),
        styleInformation: BigPictureStyleInformation(
          ByteArrayAndroidBitmap(imageBytes),
          contentTitle: title,
          summaryText: enhancedBody,
          largeIcon: ByteArrayAndroidBitmap(imageBytes),
        ),
      );
    } else {
      androidDetails = AndroidNotificationDetails(
        'browser_app_channel',
        'Browser App Notifications',
        channelDescription: 'Notifications from Browser App',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'ticker',
        autoCancel: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(
          enhancedBody,
          contentTitle: title,
        ),
      );
    }

    const iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await _localNotifications.show(
      notificationId,
      title,
      enhancedBody,
      details,
      payload: payload ?? '',
    );
  }


  static void _handleNotificationTap(RemoteMessage message) {
    // Handle notification tap logic here
    final actionUrl = message.data['actionUrl'];
    if (actionUrl != null && actionUrl.isNotEmpty) {
      _openUrl(actionUrl);
    }
  }

  static Future<void> _handleLocalNotificationTap(NotificationResponse response) async {
    // Handle local notification tap
    final actionUrl = response.payload;
    print('🔔 Notification tapped! Payload: $actionUrl');
    if (actionUrl != null && actionUrl.isNotEmpty) {
      await _openUrl(actionUrl);
    }
  }

  static Future<void> _openUrl(String url) async {
    try {
      print('🌐 _openUrl called with URL: $url');
      print('🌐 Callback registered? ${_onNotificationUrlTap != null}');

      // Import the navigator key from main.dart
      // We'll need to use url_launcher or navigate to WebViewScreen
      // For now, let's use a simple approach with a global callback
      if (_onNotificationUrlTap != null) {
        print('✅ Callback IS registered, calling it NOW with URL: $url');
        _onNotificationUrlTap!(url);
        print('✅ Callback executed successfully');
      } else {
        print('⚠️ Callback NOT registered yet, saving URL to SharedPreferences for later');
        // Save the URL to be opened when app is ready
        final prefs = await SharedPreferences.getInstance();
        print('💾 Got SharedPreferences instance, saving URL: $url');
        await prefs.setString('pending_notification_url', url);
        print('💾 ✅ SAVED URL to SharedPreferences: $url');

        // Verify it was saved
        final savedUrl = prefs.getString('pending_notification_url');
        print('💾 ✅ VERIFIED - URL in SharedPreferences: $savedUrl');
      }
    } catch (e) {
      print('❌ Error in _openUrl: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  }

  // Callback for handling URL taps
  static Function(String)? _onNotificationUrlTap;

  static void setOnNotificationUrlTap(Function(String) callback) {
    _onNotificationUrlTap = callback;
  }

  // Check for pending notification URL and open it
  static Future<String?> getPendingNotificationUrl() async {
    try {
      print('🔍 getPendingNotificationUrl: Starting check...');
      final prefs = await SharedPreferences.getInstance();
      final url = prefs.getString('pending_notification_url');
      print('🔍 getPendingNotificationUrl: Raw value from SharedPreferences: $url');
      if (url != null && url.isNotEmpty) {
        // Clear it after reading
        await prefs.remove('pending_notification_url');
        print('📱 ✅ Found pending notification URL: $url');
        print('📱 ✅ Cleared from SharedPreferences');
        return url;
      } else {
        print('📱 ❌ No pending notification URL in SharedPreferences');
      }
    } catch (e) {
      print('❌ Error getting pending notification URL: $e');
    }
    return null;
  }

  static Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }
}

// Background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
}