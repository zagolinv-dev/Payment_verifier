import 'package:payment_verifier/core/constants/app_constants.dart';
import 'package:payment_verifier/domain/entities/transaction_entity.dart';

class TransactionModel extends TransactionEntity {
  const TransactionModel({
    required super.id,
    required super.bankName,
    required super.referenceCode,
    required super.buyerName,
    required super.amount,
    super.tip,
    required super.status,
    super.verifiedBy,
    required super.createdAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      bankName: json['bank_name'] as String? ?? '',
      referenceCode: json['reference_code'] as String? ?? '',
      buyerName: json['buyer_name'] as String? ?? 'Unknown',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      tip: (json['tip'] as num?)?.toDouble() ?? 0.0,
      status: TransactionStatus.fromString(json['status'] as String? ?? 'PENDING'),
      verifiedBy: json['verified_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bank_name': bankName,
      'reference_code': referenceCode,
      'buyer_name': buyerName,
      'amount': amount,
      'tip': tip,
      'status': status.value,
      'verified_by': verifiedBy,
    };
  }
}
