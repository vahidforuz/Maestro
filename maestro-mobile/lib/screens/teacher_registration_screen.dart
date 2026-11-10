import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/teacher_auth.dart';
import '../widgets/maestro_card.dart';

class TeacherRegistrationScreen extends StatefulWidget {
  const TeacherRegistrationScreen({super.key, required this.auth});

  final TeacherAuth auth;

  @override
  State<TeacherRegistrationScreen> createState() => _TeacherRegistrationScreenState();
}

class _TeacherRegistrationScreenState extends State<TeacherRegistrationScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _phone = TextEditingController();
  final _studio = TextEditingController();
  final _instruments = TextEditingController();
  final _picture = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    for (final controller in [_first, _last, _email, _password, _confirm,
      _phone, _studio, _instruments, _picture]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    if (_first.text.trim().isEmpty || _last.text.trim().isEmpty ||
        _email.text.trim().isEmpty || _password.text.length < 6 ||
        _password.text != _confirm.text) {
      setState(() => _message =
          'Enter your first name, last name, email, and matching passwords of at least 6 characters.');
      return;
    }
    setState(() { _busy = true; _message = null; });
    try {
      final profile = <String, dynamic>{
        'firstName': _first.text.trim(),
        'lastName': _last.text.trim(),
        'telephone': _phone.text.trim(),
        'studioName': _studio.text.trim(),
        'mainInstrument': _instruments.text.split(',').first.trim(),
        'otherInstruments': _instruments.text.trim(),
        'profileImagePath': _picture.text.trim(),
      };
      final signedIn = widget.auth is SupabaseTeacherAuth
          ? await (widget.auth as SupabaseTeacherAuth).registerTeacher(
              _email.text.trim(), _password.text, profile)
          : await widget.auth.signUp(_email.text.trim(), _password.text);
      if (!mounted) return;
      if (signedIn) {
        Navigator.pop(context, true);
      } else {
        setState(() => _message =
            'Check your email to verify your account, then sign in. Your teacher profile will be created after verification.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message =
            error is AuthException ? error.message : '$error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create Teacher Account')),
    body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560),
        child: MaestroCard(child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Teacher Registration', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            TextField(controller: _first, decoration: const InputDecoration(labelText: 'First Name')),
            TextField(controller: _last, decoration: const InputDecoration(labelText: 'Last Name')),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: _password, obscureText: true,
                decoration: const InputDecoration(labelText: 'Password')),
            TextField(controller: _confirm, obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm Password')),
            const SizedBox(height: 12),
            TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone (optional)')),
            TextField(controller: _studio, decoration: const InputDecoration(labelText: 'Studio / School Name (optional)')),
            TextField(controller: _instruments, decoration: const InputDecoration(labelText: 'Instruments Taught (optional)')),
            TextField(controller: _picture, keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'Profile Picture URL (optional)')),
            const SizedBox(height: 16),
            FilledButton(onPressed: _busy ? null : _register,
                child: const Text('Create Teacher Account')),
            if (_message != null) Padding(padding: const EdgeInsets.only(top: 12),
                child: Text(_message!)),
          ],
        ))),
    ))),
  );
}
