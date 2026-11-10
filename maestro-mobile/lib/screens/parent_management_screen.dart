import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/messaging_service.dart';
import '../services/parent_portal_service.dart';
import 'messages_screen.dart';

class ParentManagementScreen extends StatefulWidget {
  const ParentManagementScreen(
      {super.key, required this.studentId, this.service});

  final int studentId;
  final ParentPortalService? service;

  @override
  State<ParentManagementScreen> createState() => _ParentManagementScreenState();
}

class _ParentManagementScreenState extends State<ParentManagementScreen> {
  late final ParentPortalService service =
      widget.service ?? ParentPortalService(Supabase.instance.client);
  late Future<Map<String, dynamic>> future =
      service.management(widget.studentId);
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final email = TextEditingController();
  String relationship = 'Other';
  bool busy = false;
  String? error;

  @override
  void dispose() {
    firstName.dispose();
    lastName.dispose();
    email.dispose();
    super.dispose();
  }

  void refresh() =>
      setState(() => future = service.management(widget.studentId));

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      if (mounted) refresh();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> invite(String parentName, String parentEmail,
      {String? invitationRelationship}) => run(() async {
        if (parentName.trim().isEmpty || parentEmail.trim().isEmpty) {
          throw StateError('Enter a parent name and email.');
        }
        final result = await service.invite(
            widget.studentId, parentName.trim(), parentEmail.trim(),
            relationship: invitationRelationship ?? relationship);
        if (mounted) {
          final delivered = result['delivered'] == true;
          final token = result['token'] as String;
          final link = result['link'] as String? ??
              (kIsWeb
                  ? Uri.base.replace(queryParameters: {
                      ...Uri.base.queryParameters,
                      'parent_invite': token,
                    }, fragment: '').toString()
                  : null);
          final invitation = link ?? token;
          await showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                    title: Text(delivered
                        ? 'Parent invitation sent'
                        : 'Share parent invitation manually'),
                    content: SizedBox(
                        width: 480,
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(delivered
                                  ? 'Activation email sent to ${parentEmail.trim()}.'
                                  : 'The invitation email service is unavailable, so no email was sent. Copy this invitation for ${parentEmail.trim()} and share it securely.'),
                              const SizedBox(height: 12),
                              const Text(
                                  'This invitation expires in 7 days and works once.'),
                              const SizedBox(height: 12),
                              SelectableText(invitation),
                            ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Done')),
                      TextButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                                ClipboardData(text: invitation));
                            if (context.mounted) Navigator.pop(context);
                          },
                          icon: const Icon(Icons.copy_outlined),
                          label:
                              Text(link == null ? 'Copy token' : 'Copy link')),
                      TextButton.icon(
                          onPressed: () => SharePlus.instance.share(ShareParams(
                              text: link == null
                                  ? 'Open the Maestro Parent Portal and enter this invitation token: $token'
                                  : 'Open $link to activate your Maestro parent account.',
                              subject: 'Your Maestro parent invitation')),
                          icon: const Icon(Icons.share_outlined),
                          label: const Text('Share')),
                    ],
                  ));
          firstName.clear();
          lastName.clear();
          email.clear();
        }
      });

  Future<void> remove(Map<String, dynamic> parent) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove parent access?'),
        content: Text(
            '${parent['name']} will lose access to this student and their conversations with this teacher.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed == true) {
      await run(
          () => service.remove(widget.studentId, parent['userId'] as String));
    }
  }

  Future<void> openChat(
      Map<String, dynamic> data, List<String> ids, bool group) async {
    await run(() async {
      final messaging = MessagingService(service.client);
      final id = await messaging.openParent(widget.studentId, ids, group);
      if (!mounted) return;
      final parentName = group
          ? 'Student and parents'
          : (data['parents'] as List)
                  .map((value) => Map<String, dynamic>.from(value as Map))
                  .firstWhere((parent) => parent['userId'] == ids.first)['name']
              as String;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ChatRoom(
          service: messaging,
          teacherId: data['teacherId'] as String,
          studentId: data['studentId'] as String,
          name: parentName,
          instrument: group ? 'group' : 'teacher_parent',
          conversationId: id,
        ),
      ));
    });
  }

  Future<void> chooseGroup(
      Map<String, dynamic> data, List<Map<String, dynamic>> parents) async {
    final selected = <String>{};
    final ids = await showDialog<List<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
                title: const Text('Start group conversation'),
                content: SizedBox(
                    width: 360,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text(
                          'Teacher and student are included. Select parents:'),
                      for (final parent in parents)
                        CheckboxListTile(
                          title: Text(parent['name'] as String),
                          value: selected.contains(parent['userId']),
                          onChanged: (value) => update(() {
                            if (value == true) {
                              selected.add(parent['userId'] as String);
                            } else {
                              selected.remove(parent['userId']);
                            }
                          }),
                        ),
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: selected.isEmpty
                          ? null
                          : () => Navigator.pop(context, selected.toList()),
                      child: const Text('Start')),
                ],
              )),
    );
    if (ids != null && ids.isNotEmpty) await openChat(data, ids, true);
  }

  String status(Map<String, dynamic> invitation) {
    if (invitation['acceptedAt'] != null) return 'Accepted';
    if (invitation['revokedAt'] != null) return 'Revoked';
    final expires = DateTime.tryParse('${invitation['expiresAt']}');
    return expires == null || expires.isBefore(DateTime.now())
        ? 'Expired'
        : 'Pending';
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Text('Could not load parents: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final parents = (data['parents'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final invitations = (data['invitations'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text('Parents / Guardians',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
                controller: firstName,
                decoration: const InputDecoration(
                    labelText: 'Parent First Name')),
            TextField(controller: lastName,
                decoration: const InputDecoration(labelText: 'Parent Last Name')),
            TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Parent Email')),
            DropdownButtonFormField<String>(
              initialValue: relationship,
              decoration: const InputDecoration(labelText: 'Relationship'),
              items: const ['Mother', 'Father', 'Guardian', 'Other']
                  .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (value) => setState(() => relationship = value ?? 'Other'),
            ),
            const SizedBox(height: 8),
            Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                    onPressed:
                        busy ? null : () {
                          if (firstName.text.trim().isEmpty ||
                              lastName.text.trim().isEmpty) {
                            setState(() => error =
                                'Enter the parent first and last name.');
                            return;
                          }
                          invite('${firstName.text.trim()} ${lastName.text.trim()}',
                              email.text);
                        },
                    icon: const Icon(Icons.mail_outline),
                    label: const Text('Send Invitation'))),
            if (error != null)
              Text(error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 18),
            Text('Associated parents',
                style: Theme.of(context).textTheme.titleMedium),
            if (parents.isEmpty) const Text('No parents linked yet.'),
            for (final parent in parents)
              ListTile(
                  title: Text(parent['name'] as String),
                  subtitle: Text(parent['email'] as String),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'message') {
                        openChat(data, [parent['userId'] as String], false);
                      }
                      if (value == 'remove') remove(parent);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'message', child: Text('Private message')),
                      PopupMenuItem(
                          value: 'remove', child: Text('Remove access')),
                    ],
                  )),
            if (parents.isNotEmpty)
              OutlinedButton.icon(
                  onPressed: busy || data['studentReady'] != true
                      ? null
                      : () => chooseGroup(data, parents),
                  icon: const Icon(Icons.groups_outlined),
                  label: const Text('Start group conversation')),
            if (parents.isNotEmpty && data['studentReady'] != true)
              const Text(
                  'Activate Student Access before starting a group conversation.'),
            const SizedBox(height: 18),
            Text('Invitation Status', style: Theme.of(context).textTheme.titleMedium),
            for (final invitation in invitations)
              ListTile(
                title: Text(invitation['name'] as String),
                subtitle:
                    Text('${invitation['email']} · ${invitation['relationship'] ?? 'Other'} · ${status(invitation)}'),
                trailing: status(invitation) == 'Accepted'
                    ? null
                    : PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'resend') {
                            invite(invitation['name'] as String,
                                invitation['email'] as String,
                                invitationRelationship: invitation['relationship'] as String?);
                          }
                          if (value == 'revoke') {
                            run(() => service
                                .revokeInvitation(invitation['id'] as String));
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                              value: 'resend',
                              child: Text('Resend invitation')),
                          if (status(invitation) == 'Pending')
                            const PopupMenuItem(
                                value: 'revoke',
                                child: Text('Revoke invitation')),
                        ],
                      ),
              ),
          ]);
        },
      );
}
