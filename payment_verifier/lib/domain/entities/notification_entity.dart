import 'package:equatable/equatable.dart';

class NotificationEntity extends Equatable {
  const NotificationEntity({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.transactionId,
    this.amount = 0,
    this.isRead = false,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String type;
  final String title;
  final String message;
  final String? transactionId;
  final double amount;
  final bool isRead;
  final DateTime createdAt;

  NotificationEntity copyWith({bool? isRead}) {
    return NotificationEntity(
      id: id,
      userId: userId,
      type: type,
      title: title,
      message: message,
      transactionId: transactionId,
      amount: amount,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, userId, type, title, message, transactionId, amount, isRead, createdAt];
}
