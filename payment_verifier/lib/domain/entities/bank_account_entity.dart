import 'package:equatable/equatable.dart';

// ── BankAccount Entity ────────────────────────────────────────────────────────

class BankAccountEntity extends Equatable {
  const BankAccountEntity({
    required this.id,
    required this.holderName,
    required this.bankName,
    required this.accountNumber,
    this.phone,
    this.notes,
    this.isActive = true,
    required this.createdAt,
  });

  final String id;
  final String holderName;
  final String bankName;
  final String accountNumber;
  final String? phone;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
        id, holderName, bankName, accountNumber,
        phone, notes, isActive, createdAt,
      ];
}
