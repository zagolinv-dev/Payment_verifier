import 'package:payment_verifier/domain/entities/bank_account_entity.dart';

class BankAccountModel extends BankAccountEntity {
  const BankAccountModel({
    required super.id,
    required super.holderName,
    required super.bankName,
    required super.accountNumber,
    super.phone,
    super.notes,
    super.isActive,
    required super.createdAt,
  });

  factory BankAccountModel.fromJson(Map<String, dynamic> json) {
    return BankAccountModel(
      id: json['id'] as String,
      holderName: json['holder_name'] as String? ?? '',
      bankName: json['bank_name'] as String? ?? '',
      accountNumber: json['account_number'] as String? ?? '',
      phone: json['phone'] as String?,
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'holder_name': holderName,
      'bank_name': bankName,
      'account_number': accountNumber,
      'phone': phone,
      'notes': notes,
      'is_active': isActive,
    };
  }
}
