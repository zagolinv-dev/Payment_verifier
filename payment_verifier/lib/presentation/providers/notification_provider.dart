import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:payment_verifier/data/datasources/supabase_notification_datasource.dart';
import 'package:payment_verifier/domain/entities/notification_entity.dart';
import 'package:payment_verifier/presentation/providers/auth_provider.dart';

final notificationDatasourceProvider = Provider<SupabaseNotificationDatasource>((ref) {
  return SupabaseNotificationDatasource(ref.watch(supabaseClientProvider));
});

final notificationsProvider = FutureProvider.autoDispose<List<NotificationEntity>>((ref) async {
  final datasource = ref.watch(notificationDatasourceProvider);
  return datasource.getNotifications();
});

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final notifications = await ref.watch(notificationsProvider.future);
  return notifications.where((n) => !n.isRead).length;
});

final markNotificationReadProvider = Provider.autoDispose<Future<void> Function(String)>((ref) {
  final datasource = ref.watch(notificationDatasourceProvider);
  return (String id) => datasource.markRead(id);
});

final markAllNotificationsReadProvider = Provider.autoDispose<Future<void> Function()>((ref) {
  final datasource = ref.watch(notificationDatasourceProvider);
  return () => datasource.markAllRead();
});

final deleteNotificationProvider = Provider.autoDispose<Future<void> Function(String)>((ref) {
  final datasource = ref.watch(notificationDatasourceProvider);
  return (String id) => datasource.deleteNotification(id);
});

final clearAllNotificationsProvider = Provider.autoDispose<Future<void> Function()>((ref) {
  final datasource = ref.watch(notificationDatasourceProvider);
  return () => datasource.clearAll();
});

final createNotificationProvider = Provider.autoDispose<Future<void> Function({
  required String type,
  required String title,
  required String message,
  String? transactionId,
  double amount,
})>((ref) {
  final datasource = ref.watch(notificationDatasourceProvider);
  return ({
    required String type,
    required String title,
    required String message,
    String? transactionId,
    double amount = 0,
  }) async {
    await datasource.createNotification(
      type: type,
      title: title,
      message: message,
      transactionId: transactionId,
      amount: amount,
    );
    ref.invalidate(notificationsProvider);
  };
});
