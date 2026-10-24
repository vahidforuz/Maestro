import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/maestro_data_source.dart';
import '../services/student_portal_service.dart';
import '../services/teacher_auth.dart';
import '../widgets/maestro_card.dart';
import 'maestro_app.dart';
import 'student_portal_screen.dart';

enum _Portal { teacher, student }

class PortalShell extends StatefulWidget {
  const PortalShell(
      {super.key, required this.client, required this.api, required this.auth});

  final SupabaseClient client;
  final MaestroDataSource api;
  final TeacherAuth auth;

  @override
  State<PortalShell> createState() => _PortalShellState();
}

class _PortalShellState extends State<PortalShell> {
  late final StudentPortalService _students =
      StudentPortalService(widget.client);
  late final String? _initialInvite = Uri.base.queryParameters['invite'];
  _Portal? _selected;
  bool _checking = true;
  bool _teacher = false;
  bool _student = false;
  String? _error;
  String? _sessionUserId;
  int _restoreVersion = 0;
  StreamSubscription<bool>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = widget.auth.sessionChanges.listen((_) => _restore());
    _restore();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _restore() async {
    final version = ++_restoreVersion;
    final userId = widget.client.auth.currentUser?.id;
    if (_sessionUserId != userId) {
      _sessionUserId = userId;
      _selected = null;
      _teacher = false;
      _student = false;
    }
    if (!widget.auth.hasSession) {
      if (mounted) {
        setState(() {
          _checking = false;
          _teacher = false;
          _student = false;
          _selected = null;
        });
      }
      return;
    }
    if (mounted) setState(() => _checking = true);
    try {
      final teacher = (await widget.api.fetchTeachers()).isNotEmpty;
      final student = (await _students.loadPortals()).isNotEmpty;
      if (!mounted ||
          version != _restoreVersion ||
          userId != widget.client.auth.currentUser?.id) {
        return;
      }
      setState(() {
        _teacher = teacher;
        _student = student;
        _checking = false;
        _error = null;
        if (_selected == _Portal.teacher && !teacher) _selected = null;
        _selected ??= _initialInvite != null
            ? _Portal.student
            : teacher
                ? _Portal.teacher
                : student
                    ? _Portal.student
                    : null;
      });
    } catch (error) {
      if (mounted && version == _restoreVersion) {
        setState(() {
          _checking = false;
          _teacher = false;
          _student = false;
          _selected = null;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _signOut() async {
    await widget.auth.signOut();
    if (mounted) setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_selected == _Portal.teacher) {
      return MaestroApp(
          key: ValueKey(_sessionUserId),
          api: widget.api,
          auth: widget.auth,
          onSwitchStudent: _student
              ? () => setState(() => _selected = _Portal.student)
              : null);
    }
    if (_selected == _Portal.student) {
      if (_student && widget.auth.hasSession) {
        return StudentPortalScreen(
            client: widget.client,
            onSignOut: _signOut,
            canSwitchTeacher: _teacher,
            onSwitchTeacher: () => setState(() => _selected = _Portal.teacher));
      }
      return _StudentSignIn(
          client: widget.client,
          auth: widget.auth,
          service: _students,
          initialInvite: _initialInvite,
          onAccessChanged: _restore,
          onBack: () => setState(() => _selected = null));
    }
    return Scaffold(
        body: SafeArea(
            child: Center(
                child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: MaestroCard(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Center(
                    child: Image.asset('assets/images/maestro-icon.png',
                        width: 72, height: 72)),
                const SizedBox(height: 14),
                Text('Maestro',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                const Text('Your music school, in one place.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                    onPressed: () =>
                        setState(() => _selected = _Portal.teacher),
                    icon: const Icon(Icons.school_outlined),
                    label: const Text('I am a Teacher')),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => _selected = _Portal.student),
                    icon: const Icon(Icons.music_note_outlined),
                    label: const Text('I am a Student')),
                if (widget.auth.hasSession) ...[
                  const SizedBox(height: 12),
                  Text('Signed in as ${widget.auth.email ?? 'account'}',
                      textAlign: TextAlign.center),
                  TextButton(
                      onPressed: _signOut, child: const Text('Sign out')),
                ],
                if (_error != null)
                  Column(children: [
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                    TextButton(
                        onPressed: _restore, child: const Text('Try again')),
                  ]),
              ]))),
    ))));
  }
}

class _StudentSignIn extends StatefulWidget {
  const _StudentSignIn(
      {required this.client,
      required this.auth,
      required this.service,
      required this.initialInvite,
      required this.onAccessChanged,
      required this.onBack});
  final SupabaseClient client;
  final TeacherAuth auth;
  final StudentPortalService service;
  final String? initialInvite;
  final VoidCallback onAccessChanged;
  final VoidCallback onBack;

  @override
  State<_StudentSignIn> createState() => _StudentSignInState();
}

class _StudentSignInState extends State<_StudentSignIn> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final _token = TextEditingController(text: widget.initialInvite);
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _acceptIfReady() async {
    if (!widget.auth.hasSession || _token.text.trim().isEmpty) return;
    final raw = _token.text.trim();
    final token = Uri.tryParse(raw)?.queryParameters['invite'] ?? raw;
    await widget.service.accept(token);
    widget.onAccessChanged();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
          body: SafeArea(
              child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: MaestroCard(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    TextButton.icon(
                        onPressed: widget.onBack,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Welcome')),
                    Text('Student Portal',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    const Text(
                        'Sign in with the email address your teacher invited.'),
                    const SizedBox(height: 18),
                    if (!widget.auth.hasSession) ...[
                      TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration:
                              const InputDecoration(labelText: 'Email')),
                      const SizedBox(height: 10),
                      TextField(
                          controller: _password,
                          obscureText: true,
                          decoration:
                              const InputDecoration(labelText: 'Password')),
                      const SizedBox(height: 12),
                      ElevatedButton(
                          onPressed: _busy
                              ? null
                              : () => _run(() async {
                                    await widget.auth.signIn(
                                        _email.text.trim(), _password.text);
                                    await _acceptIfReady();
                                    widget.onAccessChanged();
                                  }),
                          child: const Text('Sign in')),
                      TextButton(
                          onPressed: _busy
                              ? null
                              : () => _run(() async {
                                    final active = await widget.auth.signUp(
                                        _email.text.trim(), _password.text);
                                    if (active) {
                                      await _acceptIfReady();
                                      widget.onAccessChanged();
                                    } else if (mounted) {
                                      setState(() => _message =
                                          'Check your email to confirm your account, then sign in.');
                                    }
                                  }),
                          child: const Text('Create student account')),
                    ] else ...[
                      Text('Signed in as ${widget.auth.email ?? ''}'),
                      TextButton(
                          onPressed:
                              _busy ? null : () => _run(widget.auth.signOut),
                          child: const Text('Sign in with another account')),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                        controller: _token,
                        decoration: const InputDecoration(
                            labelText: 'Invitation token or link')),
                    const SizedBox(height: 10),
                    OutlinedButton(
                        onPressed: _busy || !widget.auth.hasSession
                            ? null
                            : () => _run(_acceptIfReady),
                        child: const Text('Accept invitation')),
                    if (_message != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(_message!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error))),
                  ]))),
        ),
      )));
}
