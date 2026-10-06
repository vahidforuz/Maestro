import 'package:flutter/material.dart';

import '../models/student.dart';
import '../models/teacher.dart';
import '../services/maestro_api.dart';
import '../services/studio_metrics.dart';
import '../theme/maestro_theme.dart';
import '../widgets/async_state.dart';
import '../widgets/maestro_card.dart';
import '../widgets/section_header.dart';
import '../widgets/status_badge.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({
    super.key,
    required this.api,
    required this.teacher,
    required this.onOpenStudent,
  });

  final MaestroApi api;
  final Teacher teacher;
  final ValueChanged<Student> onOpenStudent;

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  late Future<List<Student>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchStudents();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: FutureBuilder<List<Student>>(
          future: _future,
          builder: (context, snapshot) {
            return AsyncState<List<Student>>(
              snapshot: snapshot,
              builder: _content,
            );
          },
        ),
      ),
    );
  }

  Widget _content(List<Student> students) {
    final visible = visibleStudentsForTeacher(students, widget.teacher);
    final filtered = visible.where((student) {
      final haystack = [
        student.displayName,
        student.email ?? '',
        student.phone ?? '',
        student.instrument ?? '',
        student.level ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(_query.toLowerCase());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Students',
          subtitle:
              '${visible.length} students for ${widget.teacher.displayName}',
          trailing: ElevatedButton.icon(
            onPressed: _showAddStudentDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Student'),
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search students',
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 760) {
                return _StudentTable(
                  students: filtered,
                  onOpenStudent: widget.onOpenStudent,
                );
              }
              return _StudentList(
                students: filtered,
                onOpenStudent: widget.onOpenStudent,
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showAddStudentDialog() async {
    final created = await showAddStudentDialog(
      context,
      api: widget.api,
      teacher: widget.teacher,
    );
    if (created != null) {
      setState(() => _future = widget.api.fetchStudents());
      widget.onOpenStudent(created);
    }
  }
}

Future<Student?> showAddStudentDialog(
  BuildContext context, {
  required MaestroApi api,
  required Teacher teacher,
}) {
  return showDialog<Student>(
    context: context,
    builder: (context) => _StudentDialog(api: api, teacher: teacher),
  );
}

class _StudentTable extends StatelessWidget {
  const _StudentTable({required this.students, required this.onOpenStudent});

  final List<Student> students;
  final ValueChanged<Student> onOpenStudent;

  @override
  Widget build(BuildContext context) {
    return MaestroCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 28,
          headingTextStyle: const TextStyle(
            color: MaestroColors.muted,
            fontWeight: FontWeight.w800,
          ),
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Instrument')),
            DataColumn(label: Text('Level')),
            DataColumn(label: Text('Lesson')),
            DataColumn(label: Text('Status')),
          ],
          rows: [
            for (final student in students)
              DataRow(
                onSelectChanged: (_) => onOpenStudent(student),
                cells: [
                  DataCell(Text(student.displayName)),
                  DataCell(Text(student.instrument ?? 'Not set')),
                  DataCell(Text(student.level ?? 'Not set')),
                  DataCell(Text(
                      '${student.courseDay ?? 'No day'} ${student.courseHour ?? ''}')),
                  DataCell(StatusBadge(label: student.firstCourseStatus)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _StudentDialog extends StatefulWidget {
  const _StudentDialog({required this.api, required this.teacher});

  final MaestroApi api;
  final Teacher teacher;

  @override
  State<_StudentDialog> createState() => _StudentDialogState();
}

class _StudentDialogState extends State<_StudentDialog> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _hour = TextEditingController(text: '16:00');
  late final _price =
      TextEditingController(text: '${widget.teacher.defaultLessonPrice}');
  String _instrument = 'PIANO';
  String _level = 'BEGINNER';
  String _day = 'MONDAY';
  bool _saving = false;

  static const _instruments = [
    'PIANO',
    'GUITAR',
    'VIOLIN',
    'DRUMS',
    'FLUTE',
    'SAXOPHONE',
    'TRUMPET',
    'CELLO',
    'HARP',
    'CLARINET',
  ];
  static const _levels = ['BEGINNER', 'INTERMEDIATE', 'ADVANCED'];
  static const _days = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY',
    'SUNDAY'
  ];

  @override
  void initState() {
    super.initState();
    final teacherInstrument =
        widget.teacher.mainInstrument.trim().toUpperCase();
    if (_instruments.contains(teacherInstrument)) {
      _instrument = teacherInstrument;
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _email.dispose();
    _hour.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Student'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: _firstName,
                  decoration: const InputDecoration(labelText: 'First name')),
              const SizedBox(height: 10),
              TextField(
                  controller: _lastName,
                  decoration: const InputDecoration(labelText: 'Last name')),
              const SizedBox(height: 10),
              TextField(
                  controller: _phone,
                  decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 10),
              TextField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _instrument,
                items: _instruments
                    .map((value) =>
                        DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _instrument = value ?? _instrument),
                decoration: const InputDecoration(labelText: 'Instrument'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _level,
                items: _levels
                    .map((value) =>
                        DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) => setState(() => _level = value ?? _level),
                decoration: const InputDecoration(labelText: 'Level'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _day,
                items: _days
                    .map((value) =>
                        DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) => setState(() => _day = value ?? _day),
                decoration: const InputDecoration(labelText: 'Course day'),
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: _hour,
                  decoration: const InputDecoration(labelText: 'Course hour')),
              const SizedBox(height: 10),
              TextField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Course price')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
            onPressed: _saving ? null : _save, child: const Text('Create')),
      ],
    );
  }

  Future<void> _save() async {
    final price = double.tryParse(_price.text.trim());
    if (price == null) {
      _showMessage('Course price must be a number.');
      return;
    }
    if (_firstName.text.trim().isEmpty && _lastName.text.trim().isEmpty) {
      _showMessage('Enter at least a first or last name.');
      return;
    }
    setState(() => _saving = true);
    try {
      final student = await widget.api.createStudent({
        'firstName': _firstName.text.trim(),
        'familyName': _lastName.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'instrument': _instrument,
        'level': _level,
        'teacherId': widget.teacher.id,
        'courseDay': _day,
        'courseHour': _hour.text.trim(),
        'coursePrice': price,
      });
      if (mounted) Navigator.pop(context, student);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _showMessage(error.toString());
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _StudentList extends StatelessWidget {
  const _StudentList({required this.students, required this.onOpenStudent});

  final List<Student> students;
  final ValueChanged<Student> onOpenStudent;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: students.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final student = students[index];
        return MaestroCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(student.displayName),
            subtitle: Text(
              '${student.instrument ?? 'No instrument'} - ${student.level ?? 'No level'}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onOpenStudent(student),
          ),
        );
      },
    );
  }
}
