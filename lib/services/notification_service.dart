import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../main.dart';
import '../views/main/main_view.dart';
import '../views/product_details/product_details_view.dart';
import '../data/models/product_model.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp();
      
      // Set the background messaging handler early on, as a logic basis
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request permissions
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('User granted permission: ${settings.authorizationStatus}');

      // Configure local notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // TODO: iOS settings if needed

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await _localNotificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          _handleNotificationTap(response.payload);
        },
      );

      // Create Android Notification Channel
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel', // id
        'High Importance Notifications', // title
        description: 'This channel is used for important notifications.', // description
        importance: Importance.max,
      );

      await _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');

        if (message.notification != null) {
          debugPrint('Message also contained a notification: ${message.notification}');
          _showLocalNotification(message, channel);
        }
      });

      // Handle interaction when app is in background but opened from notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('A new onMessageOpenedApp event was published!');
        _handleNotificationTap(jsonEncode(message.data));
      });
      
      // Handle interaction when app is terminated but opened from notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
         debugPrint('App opened from terminated state via notification');
         // Use Future.delayed to ensure the app has finished rendering its first frame
         Future.delayed(const Duration(milliseconds: 500), () {
           _handleNotificationTap(jsonEncode(initialMessage.data));
         });
      }

      // Fetch FCM token
      final token = await _messaging.getToken();
      debugPrint('FCM Token: $token');
      if (token != null) {
        try {
          await ApiService().updateFcmToken(token);
        } catch (e) {
          debugPrint('Failed to send FCM token to backend: $e');
        }
      }

      // Setup token refresh listener
      _messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('FCM Token Refreshed: $newToken');
        try {
          await ApiService().updateFcmToken(newToken);
        } catch (e) {
          debugPrint('Failed to send FCM token to backend: $e');
        }
      });

      _initialized = true;
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message, AndroidNotificationChannel channel) async {
    final notification = message.notification;
    final android = message.notification?.android;
    final data = message.data;

    if (notification != null && android != null && !kIsWeb) {
      String? imageUrl = android.imageUrl ?? data['image'];
      BigPictureStyleInformation? bigPictureStyleInformation;

      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          final response = await http.get(Uri.parse(imageUrl));
          if (response.statusCode == 200) {
            bigPictureStyleInformation = BigPictureStyleInformation(
              ByteArrayAndroidBitmap(response.bodyBytes),
              largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
              contentTitle: notification.title,
              summaryText: notification.body,
              htmlFormatContentTitle: true,
              htmlFormatSummaryText: true,
            );
          }
        } catch (e) {
          debugPrint('Error downloading image for notification: $e');
        }
      }

      _localNotificationsPlugin.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: '@mipmap/ic_launcher',
            color: const Color(0xFF4CAF50), // Premium styling color
            ledColor: const Color(0xFF4CAF50),
            ledOnMs: 1000,
            ledOffMs: 500,
            importance: Importance.max,
            priority: Priority.high,
            styleInformation: bigPictureStyleInformation ??
                BigTextStyleInformation(
                  notification.body ?? '',
                  htmlFormatBigText: true,
                  contentTitle: notification.title,
                  htmlFormatContentTitle: true,
                ),
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  void _handleNotificationTap(String? payload) {
    if (payload == null) return;
    try {
      final data = jsonDecode(payload);
      final context = appNavigatorKey.currentContext;
      if (context == null) return;

      if (data['type'] == 'new_product') {
        final productId = int.tryParse(data['product_id'].toString()) ?? 0;
        if (productId != 0) {
           Navigator.of(context).push(
             MaterialPageRoute(
               builder: (_) => ProductDetailsView(
                 product: ProductModel(
                   id: productId.toString(),
                   category: ProductCategory.other,
                   name: 'Loading...',
                   imageUrl: '',
                   price: 0.0,
                 ),
                 currentBottomBarIndex: 0,
               ),
             ),
           );
        }
      } else if (data['type'] == 'order_status') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainView(initialIndex: 2)),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error handling notification tap: $e');
    }
  }
}
