import 'package:payment_verifier/core/constants/app_constants.dart';
import 'package:payment_verifier/data/models/notification_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseNotificationDatasource {
  SupabaseNotificationDatasource(this._client);
  final SupabaseClient _client;

  Future<List<NotificationModel>> getNotifications() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final response = await _client
        .from(AppConstants.notificationsTable)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<NotificationModel> createNotification({
    required String type,
    required String title,
    required String message,
    String? transactionId,
    double amount = 0,
  }) async {
    final userId = _client.auth.currentUser?.id;
    final data = {
      'user_id': userId,
      'type': type,
      'title': title,
      'message': message,
      'transaction_id': transactionId,
      'amount': amount,
    };
    final response = await _client
        .from(AppConstants.notificationsTable)
        .insert(data)
        .select()
        .single();
    return NotificationModel.fromJson(response as Map<String, dynamic>);
  }

  Future<void> markRead(String id) async {
    await _client
        .from(AppConstants.notificationsTable)
        .update({'is_read': true})
        .eq('id', id);
  }

  Future<void> markAllRead() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from(AppConstants.notificationsTable)
        .update({'is_read': true})
        .eq('user_id', userId);
  }

  Future<void> clearAll() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from(AppConstants.notificationsTable)
        .delete()
        .eq('user_id', userId);
  }

  Future<void> deleteNotification(String id) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from(AppConstants.notificationsTable)
        .delete()
        .eq('id', id)
        .eq('user_id', userId);
  }
}
