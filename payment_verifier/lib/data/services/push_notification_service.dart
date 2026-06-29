import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  StreamSubscription? _subscription;
  bool _initialized = false;
  String? _currentUserId;
  bool _initialSnapshotSkipped = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        // User tapped the notification — could navigate to notifications screen
      },
    );

    await _requestPermission();

    _initialized = true;
  }

  Future<void> _requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.requestNotificationsPermission();
    }
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'ts_verify_notifications',
      'T\'s Verify Notifications',
      channelDescription: 'Payment verification alerts and updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  void subscribe(SupabaseClient client, String userId) {
    if (_subscription != null) {
      if (_currentUserId == userId) return;
      _subscription!.cancel();
    }

    _currentUserId = userId;

    _subscription = client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .listen((List<Map<String, dynamic>> data) {
      if (data.isEmpty) return;
      if (!_initialSnapshotSkipped) {
        _initialSnapshotSkipped = true;
        return;
      }
      final latest = data.last;
      final id = latest['id'] as String?;
      if (id == null) return;
      final isRead = latest['is_read'] as bool? ?? false;
      if (isRead) return;
      final title = latest['title'] as String? ?? 'T\'s Verify';
      final body = latest['message'] as String? ?? '';
      if (title.isNotEmpty && body.isNotEmpty) {
        showNotification(title: title, body: body, payload: id);
      }
    });
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _currentUserId = null;
    _initialSnapshotSkipped = false;
  }
}
