/// T's Verify — Domain Entities
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
    this.receiptImage,
    required this.createdAt,
    this.riskScore = 0.0,
    this.riskFlags = const [],
    this.orderTotal = 0.0,
  });

  final String id;
  final String bankName;
  final String referenceCode;
  final String buyerName;
  final double amount;
  final double tip;
  final TransactionStatus status;
  final String? verifiedBy;
  final String? receiptImage;
  final DateTime createdAt;
  final double riskScore;
  final List<String> riskFlags;
  final double orderTotal;

  double get total => amount + tip;

  @override
  List<Object?> get props => [
        id, bankName, referenceCode, buyerName,
        amount, tip, status, verifiedBy, receiptImage, createdAt,
        riskScore, riskFlags, orderTotal,
      ];
}
