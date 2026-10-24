import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/student_portal_service.dart';
import '../widgets/maestro_card.dart';

class StudentAccessScreen extends StatefulWidget {
  const StudentAccessScreen({super.key, required this.studentId, this.service});

  final int studentId;
  final StudentPortalService? service;

  @override
  State<StudentAccessScreen> createState() => _StudentAccessScreenState();
}

class _StudentAccessScreenState extends State<StudentAccessScreen> {
  late final StudentPortalService _service =
      widget.service ?? StudentPortalService(Supabase.instance.client);
  late Future<Map<String, dynamic>> _future =
      _service.loadAccess(widget.studentId);
  final _email = TextEditingController();
  bool _busy = false;
  String? _error;

  static const _settings = <String, String>{
    'enabled': 'Portal access',
    'viewCourses': 'Courses and lesson schedule',
    'viewNotes': 'Shared lesson notes',
    'viewReviews': 'Scheduled reviews and homework',
    'viewPieces': 'Pieces and projects',
    'viewPayments': 'Payment history',
    'viewBalance': 'Outstanding balance and credits',
    'requestChanges': 'Request lesson changes (future feature)',
  };

  static const _columns = <String, String>{
    'enabled': 'enabled',
    'viewCourses': 'view_courses',
    'viewNotes': 'view_notes',
    'viewReviews': 'view_reviews',
    'viewPieces': 'view_pieces',
    'viewPayments': 'view_payments',
    'viewBalance': 'view_balance',
    'requestChanges': 'request_changes',
  };

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _refresh() {
    final next = _service.loadAccess(widget.studentId);
    setState(() {
      _future = next;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) _refresh();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _invite(String email) async {
    if (_busy || !mounted) return;
    final invitedEmail = email.trim();
    if (invitedEmail.isEmpty) {
      setState(() {
        _error = 'Enter a student email address.';
      });
      return;
    }
    await _run(() async {
      final result = await _service.invite(widget.studentId, invitedEmail);
      if (!mounted) return;
      final token = result['token'] as String;
      final link = kIsWeb
          ? Uri.base.replace(queryParameters: {
              ...Uri.base.queryParameters,
              'invite': token,
            }, fragment: '').toString()
          : null;
      final invitation = link ?? token;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invitation ready'),
          content: SizedBox(
            width: 480,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Send this ${link == null ? 'token' : 'link'} to $invitedEmail. It expires in 7 days and works once.'),
                  const SizedBox(height: 12),
                  SelectableText(invitation),
                ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done')),
            TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: invitation));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            'Invitation ${link == null ? 'token' : 'link'} copied')));
                  }
                },
                icon: const Icon(Icons.copy_outlined),
                label: Text(link == null ? 'Copy token' : 'Copy link')),
            ElevatedButton.icon(
              onPressed: () {
                SharePlus.instance.share(ShareParams(
                    text: link == null
                        ? 'You have been invited to Maestro. Open the Student Portal and enter this invitation token: $token'
                        : 'You have been invited to Maestro. Open $link',
                    subject: 'Your Maestro student invitation'));
              },
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share invitation'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _unlink() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke student account access?'),
        content: const Text(
            'The linked account will lose access immediately. A new invitation will be required to reconnect it.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Revoke access')),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(() => _service.unlinkAccess(widget.studentId));
    }
  }

  String _status(Map<String, dynamic> invitation) {
    if (invitation['accepted_at'] != null) return 'Accepted';
    if (invitation['revoked_at'] != null) return 'Revoked';
    final expires = DateTime.tryParse('${invitation['expires_at']}');
    if (expires != null && expires.isBefore(DateTime.now())) return 'Expired';
    return 'Pending';
  }

  Future<void> _editPiece(Map<String, dynamic> piece) async {
    final instructions =
        TextEditingController(text: '${piece['instructions']}');
    var status = piece['status'] as String;
    var shared = piece['instructionsShared'] == true;
    final result = await showDialog<(String, String, bool)>(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
                title: Text('${piece['title']}'),
                content: SizedBox(
                    width: 440,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      DropdownButtonFormField<String>(
                          initialValue: status,
                          decoration:
                              const InputDecoration(labelText: 'Progress'),
                          items: const [
                            DropdownMenuItem(
                                value: 'NOT_STARTED',
                                child: Text('Not started')),
                            DropdownMenuItem(
                                value: 'IN_PROGRESS',
                                child: Text('In progress')),
                            DropdownMenuItem(
                                value: 'PRACTICING', child: Text('Practicing')),
                            DropdownMenuItem(
                                value: 'READY', child: Text('Ready')),
                            DropdownMenuItem(
                                value: 'COMPLETE', child: Text('Complete')),
                          ],
                          onChanged: (value) =>
                              setDialogState(() => status = value ?? status)),
                      const SizedBox(height: 12),
                      TextField(
                          controller: instructions,
                          maxLines: 3,
                          decoration: const InputDecoration(
                              labelText: 'Teacher instructions')),
                      SwitchListTile(
                          title: const Text('Share instructions with student'),
                          value: shared,
                          onChanged: (value) =>
                              setDialogState(() => shared = value)),
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(
                          context, (status, instructions.text, shared)),
                      child: const Text('Save')),
                ],
              )),
    );
    instructions.dispose();
    if (result == null) return;
    await _run(() => _service.setPieceProgress(
        piece['appId'] as int, result.$1, result.$2, result.$3));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Center(
                  child: Text('Could not load access: ${snapshot.error}'));
            }
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final access = data['access'] as Map<String, dynamic>?;
          final invitations = data['invitations'] as List<dynamic>;
          final pieces = data['pieces'] as List<dynamic>;
          return ListView(children: [
            MaestroCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Student Access',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(access?['user_id'] == null
                      ? 'No student account linked'
                      : 'Student account linked${access?['enabled'] == true ? '' : ' · Access disabled'}'),
                  if (access?['user_id'] != null)
                    TextButton.icon(
                      onPressed: _busy ? null : _unlink,
                      icon: const Icon(Icons.link_off),
                      label: const Text('Revoke linked account'),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                          labelText: 'Student email address')),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                      onPressed: _busy ? null : () => _invite(_email.text),
                      icon: const Icon(Icons.mail_outline),
                      label: const Text('Create invitation')),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error))),
                ])),
            const SizedBox(height: 16),
            MaestroCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Piece progress',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Text(
                      'Progress is visible when pieces are enabled. Instructions are private until shared.'),
                  if (pieces.isEmpty) const Text('No pieces yet.'),
                  for (final value in pieces)
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${value['title']}'),
                        subtitle:
                            Text('${value['project']} · ${value['status']}'),
                        trailing: TextButton(
                            onPressed: _busy
                                ? null
                                : () =>
                                    _editPiece(value as Map<String, dynamic>),
                            child: const Text('Edit'))),
                ])),
            const SizedBox(height: 16),
            MaestroCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Permissions',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Text(
                      'Payment access starts off. Existing notes stay private until shared individually.'),
                  for (final item in _settings.entries)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.value),
                      value: access?[_columns[item.key]] as bool? ??
                          (item.key == 'viewCourses' ||
                              item.key == 'viewReviews' ||
                              item.key == 'viewPieces'),
                      onChanged: _busy
                          ? null
                          : (value) => _run(() => _service
                              .setAccess(widget.studentId, {item.key: value})),
                    ),
                ])),
            const SizedBox(height: 16),
            MaestroCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Invitations',
                      style: Theme.of(context).textTheme.titleMedium),
                  if (invitations.isEmpty) const Text('No invitations yet.'),
                  for (final value in invitations)
                    Builder(builder: (context) {
                      final invite = value as Map<String, dynamic>;
                      final status = _status(invite);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(invite['email'] as String),
                        subtitle: Text(status),
                        trailing: Wrap(spacing: 4, children: [
                          if (status != 'Accepted')
                            TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _invite(invite['email'] as String),
                                child: const Text('Resend')),
                          if (status == 'Pending')
                            TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _run(() =>
                                        _service.revokeInvitation(
                                            invite['id'] as String)),
                                child: const Text('Revoke')),
                        ]),
                      );
                    }),
                ])),
          ]);
        },
      );
}
