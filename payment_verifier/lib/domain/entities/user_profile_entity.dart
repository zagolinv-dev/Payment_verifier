import 'package:equatable/equatable.dart';
import 'package:payment_verifier/core/constants/app_constants.dart';

// ── UserProfile Entity ────────────────────────────────────────────────────────

class UserProfileEntity extends Equatable {
  const UserProfileEntity({
    required this.id,
    required this.email,
    this.fullName,
    this.avatarUrl,
    this.role = UserRole.waitress,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String? fullName;
  final String? avatarUrl;
  final UserRole role;
  final DateTime createdAt;

  bool get isAdmin => role == UserRole.admin;

  String get displayName => fullName ?? email.split('@').first;

  @override
  List<Object?> get props => [id, email, fullName, avatarUrl, role, createdAt];
}
