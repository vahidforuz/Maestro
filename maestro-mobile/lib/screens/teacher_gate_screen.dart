import 'package:flutter/material.dart';

import '../models/teacher.dart';
import '../services/maestro_api.dart';
import '../theme/maestro_theme.dart';
import '../widgets/async_state.dart';
import '../widgets/maestro_card.dart';
import '../widgets/section_header.dart';

class TeacherGateScreen extends StatefulWidget {
  const TeacherGateScreen({
    super.key,
    required this.api,
    required this.onSignedIn,
  });

  final MaestroApi api;
  final ValueChanged<Teacher> onSignedIn;

  @override
  State<TeacherGateScreen> createState() => _TeacherGateScreenState();
}

class _TeacherGateScreenState extends State<TeacherGateScreen> {
  late Future<List<Teacher>> _future;
  final _idController = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchTeachers();
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: FutureBuilder<List<Teacher>>(
              future: _future,
              builder: (context, snapshot) {
                return AsyncState<List<Teacher>>(
                  snapshot: snapshot,
                  builder: (teachers) => MaestroCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionHeader(
                          title: 'Maestro',
                          subtitle:
                              'Sign in with a teacher account to continue.',
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _idController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Teacher ID',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          onSubmitted: (_) => _signInById(),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _busy ? null : _signInById,
                              icon: const Icon(Icons.login),
                              label: const Text('Sign In'),
                            ),
                            OutlinedButton.icon(
                              onPressed:
                                  _busy ? null : _showCreateTeacherDialog,
                              icon: const Icon(Icons.person_add_alt),
                              label: const Text('Create Teacher Account'),
                            ),
                          ],
                        ),
                        if (teachers.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Text(
                            'Available teachers',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 8),
                          for (final teacher in teachers)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: MaestroColors.subtleBlue,
                                child: Text(teacher.id.toString()),
                              ),
                              title: Text(teacher.displayName),
                              subtitle: Text(
                                  teacher.email ?? 'Teacher ID ${teacher.id}'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => widget.onSignedIn(teacher),
                            ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signInById() async {
    final id = int.tryParse(_idController.text.trim());
    if (id == null) {
      _showMessage('Teacher ID must be a number.');
      return;
    }
    setState(() => _busy = true);
    try {
      widget.onSignedIn(await widget.api.fetchTeacher(id));
    } catch (error) {
      _showMessage('Teacher not found.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showCreateTeacherDialog() async {
    final teacher = await showDialog<Teacher>(
      context: context,
      builder: (context) => _TeacherDialog(api: widget.api),
    );
    if (teacher != null) {
      widget.onSignedIn(teacher);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TeacherDialog extends StatefulWidget {
  const _TeacherDialog({required this.api});

  final MaestroApi api;

  @override
  State<_TeacherDialog> createState() => _TeacherDialogState();
}

class _TeacherDialogState extends State<_TeacherDialog> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Teacher Account'),
      content: SizedBox(
        width: 420,
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
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 10),
            TextField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Phone')),
          ],
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
    final first = _firstName.text.trim();
    final last = _lastName.text.trim();
    final name = '$first $last'.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final teacher = await widget.api.createTeacher({
      'name': name,
      'firstName': first,
      'lastName': last,
      'email': _email.text.trim(),
      'telephone': _phone.text.trim(),
      'address': '',
    });
    if (mounted) Navigator.pop(context, teacher);
  }
}
