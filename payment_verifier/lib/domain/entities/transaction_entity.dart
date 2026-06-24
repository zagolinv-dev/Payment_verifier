/// T's Pay — Domain Entities
library;

import 'package:equatable/equatable.dart';
import 'package:payment_verifier/core/constants/app_constants.dart';

// ── Transaction Entity ────────────────────────────────────────────────────────

class TransactionEntity extends Equatable {
  const TransactionEntity({
    required this.id,
    required this.bankName,
    required this.referenceCode,
    required this.buyerName,
    required this.amount,
    this.tip = 0.0,
    required this.status,
    this.verifiedBy,
    required this.createdAt,
  });

  final String id;
  final String bankName;
  final String referenceCode;
  final String buyerName;
  final double amount;
  final double tip;
  final TransactionStatus status;
  final String? verifiedBy;
  final DateTime createdAt;

  double get total => amount + tip;

  @override
  List<Object?> get props => [
        id, bankName, referenceCode, buyerName,
        amount, tip, status, verifiedBy, createdAt,
      ];
}
