import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/maestro_data_source.dart';
import '../services/messaging_service.dart';
import '../services/student_portal_service.dart';
import '../services/parent_portal_service.dart';
import '../services/teacher_auth.dart';
import '../widgets/maestro_card.dart';
import 'maestro_app.dart';
import 'student_portal_screen.dart';
import 'parent_portal_screen.dart';

enum _Portal { teacher, student, parent }

class PortalShell extends StatefulWidget {
  const PortalShell(
      {super.key,
      required this.client,
      required this.api,
      required this.auth,
      this.initialParentInvite});

  final SupabaseClient client;
  final MaestroDataSource api;
  final TeacherAuth auth;
  final String? initialParentInvite;

  @override
  State<PortalShell> createState() => _PortalShellState();
}

class _PortalShellState extends State<PortalShell> {
  late final StudentPortalService _students =
      StudentPortalService(widget.client);
  late final ParentPortalService _parents = ParentPortalService(widget.client);
  late final String? _initialInvite = Uri.base.queryParameters['invite'];
  late bool _pendingStudentInvite = _initialInvite != null;
  late final String? _initialParentInvite =
      widget.initialParentInvite ?? Uri.base.queryParameters['parent_invite'];
  late bool _pendingParentInvite = _initialParentInvite != null;
  _Portal? _selected;
  bool _checking = true;
  bool _teacher = false;
  bool _student = false;
  bool _parent = false;
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
      _parent = false;
    }
    if (!widget.auth.hasSession) {
      if (mounted) {
        setState(() {
          _checking = false;
          _teacher = false;
          _student = false;
          _parent = false;
          _selected = _pendingParentInvite
              ? _Portal.parent
              : _pendingStudentInvite ? _Portal.student : null;
        });
      }
      return;
    }
    if (mounted) setState(() => _checking = true);
    try {
      final teachersFuture = widget.api.fetchTeachers();
      final studentsFuture = _students.loadPortals();
      final parentsFuture =
          _parents.loadPortals().catchError((_) => <Map<String, dynamic>>[]);
      final teacher = (await teachersFuture).isNotEmpty;
      final pendingTeacher = widget.auth is SupabaseTeacherAuth &&
          (widget.auth as SupabaseTeacherAuth).pendingTeacherProfile != null;
      final student = (await studentsFuture).isNotEmpty;
      final parent = (await parentsFuture).isNotEmpty;
      if (!mounted ||
          version != _restoreVersion ||
          userId != widget.client.auth.currentUser?.id) {
        return;
      }
      setState(() {
        _teacher = teacher;
        _student = student;
        _parent = parent;
        _checking = false;
        _error = null;
        if (_selected == _Portal.parent && !parent && !_pendingParentInvite) {
          _selected = null;
        }
        _selected ??= _pendingParentInvite
            ? _Portal.parent
            : _pendingStudentInvite
                ? _Portal.student
                : teacher || pendingTeacher
                    ? _Portal.teacher
                    : student
                        ? _Portal.student
                        : parent
                            ? _Portal.parent
                            : null;
      });
    } catch (error) {
      if (mounted && version == _restoreVersion) {
        setState(() {
          _checking = false;
          _teacher = false;
          _student = false;
          _parent = false;
          _selected = null;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _signOut() async {
    await MessagingService.clearDownloadedFiles();
    await widget.auth.signOut();
    if (mounted) setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking && _selected == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_selected == _Portal.teacher) {
      return MaestroApp(
          key: ValueKey(_sessionUserId),
          api: widget.api,
          auth: widget.auth,
          client: widget.client,
          onSwitchStudent: _student
              ? () => setState(() => _selected = _Portal.student)
              : null,
          onSwitchParent: _parent
              ? () => setState(() => _selected = _Portal.parent)
              : null);
    }
    if (_selected == _Portal.student) {
      if (_student && widget.auth.hasSession && !_pendingStudentInvite) {
        return StudentPortalScreen(
            client: widget.client,
            onSignOut: _signOut,
            canSwitchTeacher: _teacher,
            onSwitchTeacher: () => setState(() => _selected = _Portal.teacher),
            onSwitchParent: _parent
                ? () => setState(() => _selected = _Portal.parent)
                : null);
      }
      return _StudentSignIn(
          client: widget.client,
          auth: widget.auth,
          service: _students,
          initialInvite: _initialInvite,
          onAccessChanged: () {
            if (kIsWeb && _pendingStudentInvite) {
              final query = Map<String, String>.from(Uri.base.queryParameters)
                ..remove('invite');
              unawaited(SystemNavigator.routeInformationUpdated(
                  uri: Uri(path: Uri.base.path, queryParameters: query),
                  replace: true));
            }
            _pendingStudentInvite = false;
            _restore();
          },
          onBack: () => setState(() => _selected = null));
    }
    if (_selected == _Portal.parent) {
      if (_parent && widget.auth.hasSession && !_pendingParentInvite) {
        return ParentPortalScreen(
            key: ValueKey(_sessionUserId),
            client: widget.client,
            onSignOut: _signOut,
            onSwitchTeacher: _teacher
                ? () => setState(() => _selected = _Portal.teacher)
                : null,
            onSwitchStudent: _student
                ? () => setState(() => _selected = _Portal.student)
                : null);
      }
      return _ParentSignIn(
          client: widget.client,
          auth: widget.auth,
          service: _parents,
          initialInvite: _initialParentInvite,
          onAccessChanged: () {
            if (kIsWeb && _pendingParentInvite) {
              final query = Map<String, String>.from(Uri.base.queryParameters)
                ..remove('parent_invite');
              unawaited(SystemNavigator.routeInformationUpdated(
                  uri: Uri(path: Uri.base.path, queryParameters: query),
                  replace: true));
            }
            _pendingParentInvite = false;
            _restore();
          },
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
                const SizedBox(height: 10),
                OutlinedButton.icon(
                    onPressed: () => setState(() => _selected = _Portal.parent),
                    icon: const Icon(Icons.family_restroom_outlined),
                    label: const Text('I am a Parent')),
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
  bool _activating = false;
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
      if (mounted) {
        setState(() => _message = switch (error) {
              AuthException e => e.message,
              PostgrestException e => e.message,
              _ => error.toString().replaceFirst('Bad state: ', ''),
            });
      }
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

  String get _invitationToken {
    final raw = _token.text.trim();
    return Uri.tryParse(raw)?.queryParameters['invite'] ?? raw;
  }

  Future<void> _createAccount() async {
    final email = _email.text.trim();
    if (email.isEmpty ||
        _password.text.length < 6 ||
        _invitationToken.isEmpty) {
      throw StateError(
          'Enter an email, a password of at least 6 characters, and an invitation.');
    }
    final valid = await widget.service.checkInvitation(_invitationToken, email);
    if (!valid) {
      throw StateError('Invitation is invalid, expired, or for another email.');
    }
    final redirect = kIsWeb
        ? Uri.base.replace(queryParameters: {
            ...Uri.base.queryParameters,
            'invite': _invitationToken,
          }, fragment: '').toString()
        : null;
    final response = await widget.client.auth.signUp(
        email: email, password: _password.text, emailRedirectTo: redirect,
        data: {'maestro_signup_kind': 'student',
          'maestro_invitation_token': _invitationToken});
    if (response.session != null) {
      await _acceptIfReady();
      widget.onAccessChanged();
    } else if (mounted) {
      setState(() => _message =
          'Check your email to confirm your account, then sign in with this invitation. If you already have an account, sign in instead.');
    }
  }

  Future<void> _forgotPassword() async {
    if (_email.text.trim().isEmpty) {
      throw StateError('Enter your email address first.');
    }
    await widget.client.auth.resetPasswordForEmail(_email.text.trim());
    if (mounted) setState(() => _message = 'Check your email for a password reset link.');
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
                    const Text('Student accounts are created through an invitation from your music teacher.'),
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
                          onPressed: _busy ? null : () => setState(() => _activating = true),
                          child: const Text('Activate Invitation')),
                      TextButton(
                          onPressed: _busy ? null : () => _run(_forgotPassword),
                          child: const Text('Forgot Password')),
                      if (_activating || widget.initialInvite != null)
                        FilledButton(
                            onPressed: _busy ? null : () => _run(_createAccount),
                            child: const Text('Set password and activate')),
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

class _ParentSignIn extends StatefulWidget {
  const _ParentSignIn(
      {required this.client,
      required this.auth,
      required this.service,
      required this.initialInvite,
      required this.onAccessChanged,
      required this.onBack});

  final SupabaseClient client;
  final TeacherAuth auth;
  final ParentPortalService service;
  final String? initialInvite;
  final VoidCallback onAccessChanged;
  final VoidCallback onBack;

  @override
  State<_ParentSignIn> createState() => _ParentSignInState();
}

class _ParentSignInState extends State<_ParentSignIn> {
  final email = TextEditingController();
  final password = TextEditingController();
  late final token = TextEditingController(text: widget.initialInvite);
  bool busy = false;
  bool activating = false;
  String? message;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    token.dispose();
    super.dispose();
  }

  String get invitationToken {
    final raw = token.text.trim();
    return Uri.tryParse(raw)?.queryParameters['parent_invite'] ?? raw;
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() => message = e is AuthException
            ? e.message
            : e is PostgrestException
                ? e.message
                : '$e');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> accept() async {
    if (!widget.auth.hasSession || invitationToken.isEmpty) return;
    await widget.service.accept(invitationToken);
    widget.onAccessChanged();
  }

  Future<void> createAccount() async {
    final invitedEmail = email.text.trim();
    if (invitedEmail.isEmpty ||
        password.text.length < 6 ||
        invitationToken.isEmpty) {
      throw StateError(
          'Enter your email, a password of at least 6 characters, and your invitation.');
    }
    if (!await widget.service.checkInvitation(invitationToken, invitedEmail)) {
      throw StateError('Invitation is invalid, expired, or for another email.');
    }
    final redirect = kIsWeb
        ? Uri.base.replace(queryParameters: {
            ...Uri.base.queryParameters,
            'parent_invite': invitationToken,
          }, fragment: '').toString()
        : null;
    final response = await widget.client.auth.signUp(
        email: invitedEmail,
        password: password.text,
        emailRedirectTo: redirect,
        data: {'maestro_signup_kind': 'parent',
          'maestro_invitation_token': invitationToken});
    if (response.session != null) {
      await accept();
    } else if (mounted) {
      setState(() => message =
          'Check your email to confirm your account, then sign in with this invitation. If you already have an account, sign in instead.');
    }
  }

  Future<void> forgotPassword() async {
    if (email.text.trim().isEmpty) throw StateError('Enter your email address first.');
    await widget.client.auth.resetPasswordForEmail(email.text.trim());
    if (mounted) setState(() => message = 'Check your email for a password reset link.');
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
                    Text('Parent Portal',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    const Text("Parent accounts are available by invitation from your child's music teacher."),
                    const SizedBox(height: 18),
                    if (!widget.auth.hasSession) ...[
                      TextField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          decoration:
                              const InputDecoration(labelText: 'Email')),
                      const SizedBox(height: 10),
                      TextField(
                          controller: password,
                          obscureText: true,
                          decoration:
                              const InputDecoration(labelText: 'Password')),
                      const SizedBox(height: 12),
                      ElevatedButton(
                          onPressed: busy
                              ? null
                              : () => run(() async {
                                    await widget.auth.signIn(
                                        email.text.trim(), password.text);
                                    await accept();
                                    widget.onAccessChanged();
                                  }),
                          child: const Text('Sign in')),
                      TextButton(
                          onPressed: busy ? null : () => setState(() => activating = true),
                          child: const Text('Activate Invitation')),
                      TextButton(
                          onPressed: busy ? null : () => run(forgotPassword),
                          child: const Text('Forgot Password')),
                      if (activating || widget.initialInvite != null)
                        FilledButton(
                            onPressed: busy ? null : () => run(createAccount),
                            child: const Text('Set password and activate')),
                    ] else ...[
                      Text('Signed in as ${widget.auth.email ?? ''}'),
                      TextButton(
                          onPressed:
                              busy ? null : () => run(widget.auth.signOut),
                          child: const Text('Sign in with another account')),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                        controller: token,
                        decoration: const InputDecoration(
                            labelText: 'Invitation token or link')),
                    const SizedBox(height: 10),
                    OutlinedButton(
                        onPressed: busy || !widget.auth.hasSession
                            ? null
                            : () => run(accept),
                        child: const Text('Accept invitation')),
                    if (message != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(message!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error))),
                  ],
                ))),
          ),
        ),
      ));
}
