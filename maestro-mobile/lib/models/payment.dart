class Payment {
  const Payment({
    required this.id,
    required this.amount,
    this.paymentDate,
    this.method,
    this.note,
    this.studentId,
    this.studentName,
  });

  final int id;
  final double amount;
  final DateTime? paymentDate;
  final String? method;
  final String? note;
  final int? studentId;
  final String? studentName;

  factory Payment.fromJson(Map<String, dynamic> json) {
    final student = json['student'];
    return Payment(
      id: json['id'] as int? ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      paymentDate: _parseDate(json['paymentDate']),
      method: json['method'] as String?,
      note: json['note'] as String?,
      studentId: student is Map<String, dynamic> ? student['id'] as int? : null,
      studentName:
          student is Map<String, dynamic> ? student['name'] as String? : null,
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
