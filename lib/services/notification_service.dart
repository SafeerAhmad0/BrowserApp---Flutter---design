import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        databaseURL: 'https://test-51a88-default-rtdb.firebaseio.com',
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

            await showLocal(title: title, body: body, payload: actionUrl);

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
      print('FCM Token: $token');

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

  static Future<void> showLocal({
    required String title,
    required String body,
    String? payload,
  }) async {
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
      title,
      body,
      details,
      payload: payload ?? '',
    );
  }


  static void _handleNotificationTap(RemoteMessage message) {
    // Handle notification tap logic here
    print('Notification tapped: ${message.data}');
    final actionUrl = message.data['actionUrl'];
    if (actionUrl != null && actionUrl.isNotEmpty) {
      // TODO: Navigate to URL or specific screen
      print('Opening URL: $actionUrl');
    }
  }

  static void _handleLocalNotificationTap(NotificationResponse response) {
    // Handle local notification tap
    print('Local notification tapped: ${response.payload}');
    final actionUrl = response.payload;
    if (actionUrl != null && actionUrl.isNotEmpty) {
      // TODO: Navigate to URL or specific screen
      print('Opening URL: $actionUrl');
    }
  }

  static Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }
}

// Background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling a background message: ${message.messageId}');
}