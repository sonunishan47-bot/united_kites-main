class DaybookEntry {
  DaybookEntry({
    required this.id,
    required this.action,
    required this.reference,
    required this.actor,
    required this.amount,
    this.note = '',
    DateTime? at,
  }) : at = at ?? DateTime.now();

  final String id;
  final String action;
  final String reference;
  final String actor;
  final double amount;
  final String note;
  final DateTime at;

  Map<String, dynamic> toJson() => {
        'id': id,
        'action': action,
        'reference': reference,
        'actor': actor,
        'amount': amount,
        'note': note,
        'at': at.toIso8601String(),
      };

  factory DaybookEntry.fromJson(Map<String, dynamic> json) {
    return DaybookEntry(
      id: json['id'].toString(),
      action: json['action']?.toString() ?? '',
      reference: json['reference']?.toString() ?? '',
      actor: json['actor']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      note: json['note']?.toString() ?? '',
      at: DateTime.tryParse(json['at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
