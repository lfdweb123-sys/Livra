class WalletTransaction {
  final String id;
  final String type; // credit | debit
  final num amount;
  final String reason;

  WalletTransaction({required this.id, required this.type, required this.amount, required this.reason});

  factory WalletTransaction.fromMap(String id, Map<String, dynamic> map) => WalletTransaction(
        id: id,
        type: map['type'] ?? 'credit',
        amount: map['amount'] ?? 0,
        reason: map['reason'] ?? '',
      );
}
