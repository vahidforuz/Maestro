import 'package:flutter/material.dart';

import '../models/teacher.dart';
import '../services/maestro_data_source.dart';
import '../services/teacher_auth.dart';
import '../widgets/maestro_card.dart';
import '../widgets/section_header.dart';

class TeacherGateScreen extends StatefulWidget {
  const TeacherGateScreen(
      {super.key,
      required this.api,
      required this.auth,
      required this.onSignedIn});

  final MaestroDataSource api;
  final TeacherAuth auth;
  final ValueChanged<Teacher> onSignedIn;

  @override
  State<TeacherGateScreen> createState() => _TeacherGateScreenState();
}

class _TeacherGateScreenState extends State<TeacherGateScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _checking = true;
  bool _needsProfile = false;
  bool _blockedAccount = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    if (!widget.auth.hasSession) {
      if (mounted) {
        setState(() {
          _checking = false;
          _needsProfile = false;
          _blockedAccount = false;
        });
      }
      return;
    }
    try {
      final teachers = await widget.api.fetchTeachers();
      if (!mounted) return;
      if (teachers.isNotEmpty) {
        widget.onSignedIn(teachers.first);
      } else {
        final canCreate = await widget.auth.canCreateTeacherProfile();
        if (!mounted) return;
        setState(() {
          _needsProfile = canCreate;
          _blockedAccount = !canCreate;
          if (!canCreate) {
            _message = 'This account is not linked to a teacher profile.';
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _blockedAccount = true;
          _message = 'Could not load the teacher profile: $error';
        });
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _signIn() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _message = 'Enter your email and password.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.auth.signIn(_email.text.trim(), _password.text);
      await _restore();
    } catch (error) {
      if (mounted) setState(() => _message = 'Sign in failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signUp() async {
    if (_email.text.trim().isEmpty || _password.text.length < 6) {
      setState(() =>
          _message = 'Enter an email and a password of at least 6 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final signedIn =
          await widget.auth.signUp(_email.text.trim(), _password.text);
      if (signedIn) {
        await _restore();
      } else if (mounted) {
        setState(() => _message =
            'Check your email to confirm the account, then sign in.');
      }
    } catch (error) {
      if (mounted) setState(() => _message = 'Account creation failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createProfile() async {
    final teacher = await showDialog<Teacher>(
        context: context,
        builder: (context) => _TeacherDialog(
            api: widget.api, initialEmail: widget.auth.email ?? ''));
    if (teacher != null && mounted) widget.onSignedIn(teacher);
  }

  Future<void> _signOut() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.auth.signOut();
      if (mounted) {
        setState(() {
          _needsProfile = false;
          _blockedAccount = false;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _message = 'Sign out failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
          child: Center(
              child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
            padding: const EdgeInsets.all(24),
            child: MaestroCard(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader(
                        title: 'Maestro',
                        subtitle:
                            'Sign in with your teacher account to continue.'),
                    const SizedBox(height: 18),
                    if (_checking)
                      const Center(child: CircularProgressIndicator()),
                    if (!_checking && !_needsProfile && !_blockedAccount) ...[
                      TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration:
                              const InputDecoration(labelText: 'Email')),
                      const SizedBox(height: 12),
                      TextField(
                          controller: _password,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          onSubmitted: (_) => _signIn(),
                          decoration:
                              const InputDecoration(labelText: 'Password')),
                      const SizedBox(height: 16),
                      Wrap(spacing: 10, runSpacing: 10, children: [
                        ElevatedButton.icon(
                            onPressed: _busy ? null : _signIn,
                            icon: const Icon(Icons.login),
                            label: const Text('Sign In')),
                        OutlinedButton.icon(
                            onPressed: _busy ? null : _signUp,
                            icon: const Icon(Icons.person_add_alt),
                            label: const Text('Create Account')),
                      ]),
                    ],
                    if (!_checking && _needsProfile) ...[
                      Text('Signed in as ${widget.auth.email ?? 'teacher'}.'),
                      const SizedBox(height: 12),
                      const Text('Create your teacher profile to continue.'),
                      const SizedBox(height: 12),
                      Wrap(spacing: 10, children: [
                        ElevatedButton.icon(
                            onPressed: _busy ? null : _createProfile,
                            icon: const Icon(Icons.person_add_alt),
                            label: const Text('Create Teacher Profile')),
                        TextButton(
                            onPressed: _busy ? null : _signOut,
                            child: const Text('Sign Out')),
                      ]),
                    ],
                    if (!_checking && _blockedAccount) ...[
                      Text('Signed in as ${widget.auth.email ?? 'account'}.'),
                      TextButton(
                          onPressed: _busy ? null : _signOut,
                          child: const Text('Sign Out')),
                    ],
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      Text(_message!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ],
                  ]),
            )),
      )));
}

class _TeacherDialog extends StatefulWidget {
  const _TeacherDialog({required this.api, required this.initialEmail});
  final MaestroDataSource api;
  final String initialEmail;

  @override
  State<_TeacherDialog> createState() => _TeacherDialogState();
}

class _TeacherDialogState extends State<_TeacherDialog> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _phone = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_firstName.text.trim().isEmpty && _lastName.text.trim().isEmpty) {
      setState(() => _error = 'Enter a first or last name.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final teacher = await widget.api.createTeacher({
        'firstName': _firstName.text.trim(),
        'lastName': _lastName.text.trim(),
        'email': _email.text.trim(),
        'telephone': _phone.text.trim(),
      });
      if (mounted) Navigator.pop(context, teacher);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Create Teacher Profile'),
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
                    keyboardType: TextInputType.emailAddress,
                    decoration:
                        const InputDecoration(labelText: 'Contact email')),
                const SizedBox(height: 10),
                TextField(
                    controller: _phone,
                    decoration: const InputDecoration(labelText: 'Phone')),
                if (_error != null)
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
              ],
            )),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: _saving ? null : _save, child: const Text('Create')),
        ],
      );
}
