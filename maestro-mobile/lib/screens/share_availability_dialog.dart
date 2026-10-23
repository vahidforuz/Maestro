import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/calendar_availability_data_source.dart';

class ShareAvailabilityDialog extends StatefulWidget {
  const ShareAvailabilityDialog({super.key, required this.source});
  final CalendarAvailabilityDataSource source;

  @override
  State<ShareAvailabilityDialog> createState() =>
      _ShareAvailabilityDialogState();
}

class _ShareAvailabilityDialogState extends State<ShareAvailabilityDialog> {
  static const _configuredBase = String.fromEnvironment('MAESTRO_WEB_URL');
  late Future<List<AvailabilityShareLink>> _links =
      widget.source.fetchAvailabilityShareLinks();
  DateTime? _from;
  DateTime? _until;
  int? _expiresDays;
  bool _saving = false;
  String? _newUrl;
  String? _error;

  String? get _baseUrl {
    if (_configuredBase.isNotEmpty) {
      return _configuredBase.replaceAll(RegExp(r'/$'), '');
    }
    if (kIsWeb && Uri.base.hasAuthority) return Uri.base.origin;
    return null;
  }

  Future<void> _pickDate(bool start) async {
    final date = await showDatePicker(
        context: context,
        initialDate:
            start ? _from ?? DateTime.now() : _until ?? _from ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2100));
    if (date != null) {
      setState(() {
        if (start) {
          _from = date;
        } else {
          _until = date;
        }
      });
    }
  }

  Future<void> _create() async {
    if (_baseUrl == null) {
      setState(
          () => _error = 'Set MAESTRO_WEB_URL when building the mobile app.');
      return;
    }
    if (_from != null && _until != null && _until!.isBefore(_from!)) {
      setState(() => _error = 'End date must be on or after start date.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final link = await widget.source.createAvailabilityShareLink(
          expiresAt: _expiresDays == null
              ? null
              : DateTime.now().toUtc().add(Duration(days: _expiresDays!)),
          rangeFrom: _from,
          rangeUntil: _until);
      if (!mounted) return;
      setState(() {
        _newUrl = '$_baseUrl/availability/${link.token}';
        _links = widget.source.fetchAvailabilityShareLinks();
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _revoke(String id) async {
    try {
      await widget.source.revokeAvailabilityShareLink(id);
      if (mounted) {
        setState(() {
          _newUrl = null;
          _links = widget.source.fetchAvailabilityShareLinks();
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Share Availability'),
      content: SizedBox(
        width: 450,
        height: 500,
        child: SingleChildScrollView(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Anyone with the link can view free time slots. No student or appointment details are shared.'),
            const SizedBox(height: 14),
            DropdownButtonFormField<int?>(
              initialValue: _expiresDays,
              decoration: const InputDecoration(labelText: 'Link expires'),
              items: const [
                DropdownMenuItem<int?>(value: null, child: Text('Never')),
                DropdownMenuItem<int?>(value: 7, child: Text('After 7 days')),
                DropdownMenuItem<int?>(value: 30, child: Text('After 30 days')),
              ],
              onChanged: (value) => setState(() => _expiresDays = value),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton(
                  onPressed: () => _pickDate(true),
                  child: Text(_from == null
                      ? 'Start date (optional)'
                      : 'From ${DateFormat.yMMMd().format(_from!)}')),
              OutlinedButton(
                  onPressed: () => _pickDate(false),
                  child: Text(_until == null
                      ? 'End date (optional)'
                      : 'Until ${DateFormat.yMMMd().format(_until!)}')),
              if (_from != null || _until != null)
                TextButton(
                    onPressed: () => setState(() {
                          _from = null;
                          _until = null;
                        }),
                    child: const Text('Clear dates')),
            ]),
            const SizedBox(height: 10),
            FilledButton.icon(
                onPressed: _saving ? null : _create,
                icon: const Icon(Icons.link),
                label: const Text('Generate link')),
            if (_newUrl != null) ...[
              const SizedBox(height: 14),
              const Text(
                  'Copy this link now. For security, its token is shown only once.',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              SelectableText(_newUrl!),
              TextButton.icon(
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: _newUrl!)),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy link')),
            ],
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child:
                      Text(_error!, style: const TextStyle(color: Colors.red))),
            const Divider(height: 28),
            const Text('Existing links',
                style: TextStyle(fontWeight: FontWeight.w900)),
            FutureBuilder<List<AvailabilityShareLink>>(
                future: _links,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Could not load links: ${snapshot.error}');
                  }
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  if (snapshot.data!.isEmpty) {
                    return const Text('No links yet.');
                  }
                  return Column(children: [
                    for (final link in snapshot.data!)
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                              'Created ${DateFormat.yMMMd().format(link.createdAt)}'),
                          subtitle: Text(link.active
                              ? 'Active${link.expiresAt == null ? '' : ' · Expires ${DateFormat.yMMMd().format(link.expiresAt!)}'}'
                              : 'Revoked or expired'),
                          trailing: link.active
                              ? IconButton(
                                  tooltip: 'Disable link',
                                  icon: const Icon(Icons.link_off),
                                  onPressed: () => _revoke(link.id))
                              : null),
                  ]);
                }),
          ],
        )),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Close'))
      ],
    );
  }
}
