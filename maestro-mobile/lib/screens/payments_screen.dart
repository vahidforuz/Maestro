import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/payment.dart';
import '../models/student.dart';
import '../models/teacher.dart';
import '../services/maestro_api.dart';
import '../services/studio_metrics.dart';
import '../theme/maestro_theme.dart';
import '../widgets/async_state.dart';
import '../widgets/maestro_card.dart';
import '../widgets/section_header.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({
    super.key,
    required this.api,
    required this.teacher,
  });

  final MaestroApi api;
  final Teacher teacher;

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  late Future<_PaymentsData> _future;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: FutureBuilder<_PaymentsData>(
          future: _future,
          builder: (context, snapshot) {
            return AsyncState<_PaymentsData>(
              snapshot: snapshot,
              builder: _content,
            );
          },
        ),
      ),
    );
  }

  Widget _content(_PaymentsData data) {
    final students = visibleStudentsForTeacher(data.students, widget.teacher);
    final payments =
        visiblePaymentsForTeacher(data.payments, data.students, widget.teacher)
            .where((payment) {
      final date = payment.paymentDate;
      if (date == null || date.month != _month || date.year != _year) {
        return false;
      }
      if (_query.trim().isEmpty) return true;
      return (payment.studentName ?? '')
          .toLowerCase()
          .contains(_query.toLowerCase());
    }).toList();
    final revenue =
        payments.fold<double>(0, (total, payment) => total + payment.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Payments',
          subtitle:
              '${payments.length} payments - ${NumberFormat.simpleCurrency().format(revenue)}',
          trailing: ElevatedButton.icon(
            onPressed:
                students.isEmpty ? null : () => _showAddPaymentDialog(students),
            icon: const Icon(Icons.add),
            label: const Text('Add Payment'),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<int>(
              value: _month,
              items: [
                for (var i = 1; i <= 12; i++)
                  DropdownMenuItem(
                      value: i,
                      child: Text(DateFormat.MMMM().format(DateTime(2024, i)))),
              ],
              onChanged: (value) => setState(() => _month = value ?? _month),
            ),
            DropdownButton<int>(
              value: _year,
              items: _years(data.payments)
                  .map((year) =>
                      DropdownMenuItem(value: year, child: Text('$year')))
                  .toList(),
              onChanged: (value) => setState(() => _year = value ?? _year),
            ),
            SizedBox(
              width: 280,
              child: TextField(
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search), hintText: 'Search student'),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: payments.isEmpty
              ? const MaestroCard(
                  child: Text('No payments match the selected filters.'))
              : MaestroCard(
                  padding: EdgeInsets.zero,
                  child: ListView.separated(
                    itemCount: payments.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final payment = payments[index];
                      return ListTile(
                        title: Text(payment.studentName ??
                            'Student ${payment.studentId ?? ''}'),
                        subtitle: Text([
                          if (payment.paymentDate != null)
                            DateFormat.yMMMd().format(payment.paymentDate!),
                          payment.method ?? 'Payment',
                          if ((payment.note ?? '').isNotEmpty) payment.note!,
                        ].join(' - ')),
                        trailing: Text(
                          NumberFormat.simpleCurrency().format(payment.amount),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: MaestroColors.text),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Future<_PaymentsData> _load() async {
    final results = await Future.wait(
        [widget.api.fetchStudents(), widget.api.fetchPayments()]);
    return _PaymentsData(
      students: results[0] as List<Student>,
      payments: results[1] as List<Payment>,
    );
  }

  List<int> _years(List<Payment> payments) {
    final years = payments
        .map((payment) => payment.paymentDate?.year)
        .whereType<int>()
        .toSet();
    years.add(DateTime.now().year);
    final sorted = years.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  Future<void> _showAddPaymentDialog(List<Student> students) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => _PaymentDialog(api: widget.api, students: students),
    );
    if (created == true) {
      setState(() => _future = _load());
    }
  }
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({required this.api, required this.students});

  final MaestroApi api;
  final List<Student> students;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late Student _student = widget.students.first;
  final _amount = TextEditingController();
  final _method = TextEditingController(text: 'Cash');
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _method.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Payment'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<Student>(
              initialValue: _student,
              items: widget.students.map((student) {
                return DropdownMenuItem(
                    value: student, child: Text(student.displayName));
              }).toList(),
              onChanged: (value) =>
                  setState(() => _student = value ?? _student),
              decoration: const InputDecoration(labelText: 'Student'),
            ),
            const SizedBox(height: 10),
            TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount')),
            const SizedBox(height: 10),
            TextField(
                controller: _method,
                decoration: const InputDecoration(labelText: 'Method')),
            const SizedBox(height: 10),
            TextField(
                controller: _note,
                decoration: const InputDecoration(labelText: 'Note')),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(DateFormat.yMMMd().format(_date)),
              trailing: const Icon(Icons.calendar_month),
              onTap: _pickDate,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
            onPressed: _saving ? null : _save, child: const Text('Save')),
      ],
    );
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: _date,
    );
    if (value != null) setState(() => _date = value);
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null) return;
    setState(() => _saving = true);
    await widget.api.createPayment(_student.id, {
      'amount': amount,
      'paymentDate': DateFormat('yyyy-MM-dd').format(_date),
      'method': _method.text.trim(),
      'note': _note.text.trim(),
    });
    if (mounted) Navigator.pop(context, true);
  }
}

class _PaymentsData {
  const _PaymentsData({required this.students, required this.payments});

  final List<Student> students;
  final List<Payment> payments;
}
