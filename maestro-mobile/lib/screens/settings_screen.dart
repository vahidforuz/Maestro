import 'package:flutter/material.dart';

import '../models/teacher.dart';
import '../services/maestro_api.dart';
import '../widgets/maestro_card.dart';
import '../widgets/section_header.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.api,
    required this.teacher,
    required this.onTeacherChanged,
    required this.onSignOut,
  });

  final MaestroApi api;
  final Teacher teacher;
  final ValueChanged<Teacher> onTeacherChanged;
  final VoidCallback onSignOut;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _editing = false;
  late final _firstName = TextEditingController(text: widget.teacher.firstName);
  late final _lastName = TextEditingController(text: widget.teacher.lastName);
  late final _studioName =
      TextEditingController(text: widget.teacher.studioName);
  late final _email = TextEditingController(text: widget.teacher.email ?? '');
  late final _phone =
      TextEditingController(text: widget.teacher.telephone ?? '');
  late final _address =
      TextEditingController(text: widget.teacher.address ?? '');
  late final _city = TextEditingController(text: widget.teacher.city);
  late final _postalCode =
      TextEditingController(text: widget.teacher.postalCode);
  late final _mainInstrument =
      TextEditingController(text: widget.teacher.mainInstrument);
  late final _otherInstruments =
      TextEditingController(text: widget.teacher.otherInstruments);
  late final _duration =
      TextEditingController(text: '${widget.teacher.defaultLessonDuration}');
  late final _price =
      TextEditingController(text: '${widget.teacher.defaultLessonPrice}');
  late final _currency = TextEditingController(text: widget.teacher.currency);
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _lastName,
      _studioName,
      _email,
      _phone,
      _address,
      _city,
      _postalCode,
      _mainInstrument,
      _otherInstruments,
      _duration,
      _price,
      _currency,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            SectionHeader(
              title: 'Settings',
              subtitle: 'Teacher profile and lesson defaults',
              trailing: Wrap(
                spacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: widget.onSignOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign Out'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _saving
                        ? null
                        : (_editing
                            ? _save
                            : () => setState(() => _editing = true)),
                    icon: Icon(_editing ? Icons.save : Icons.edit),
                    label: Text(_editing ? 'Save Changes' : 'Edit Profile'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumn = constraints.maxWidth >= 820;
                final cards = [
                  _profileCard(context),
                  _teachingCard(context),
                ];
                if (twoColumn) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 14),
                      Expanded(child: cards[1]),
                    ],
                  );
                }
                return Column(
                    children: [cards[0], const SizedBox(height: 14), cards[1]]);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileCard(BuildContext context) {
    return MaestroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Teacher Profile',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _field('First name', _firstName),
          _field('Last name', _lastName),
          _field('Studio name', _studioName),
          _field('Email', _email),
          _field('Phone', _phone),
          _field('Address', _address),
          _field('City', _city),
          _field('Postal code', _postalCode),
        ],
      ),
    );
  }

  Widget _teachingCard(BuildContext context) {
    return MaestroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Teaching Defaults',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _field('Main instrument', _mainInstrument),
          _field('Other instruments', _otherInstruments),
          _field('Default lesson duration', _duration,
              keyboardType: TextInputType.number),
          _field('Default lesson price', _price,
              keyboardType: TextInputType.number),
          _field('Currency', _currency),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController controller,
      {TextInputType? keyboardType}) {
    if (_editing) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(labelText: label),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
              width: 170,
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w700))),
          Expanded(
              child: Text(controller.text.trim().isEmpty
                  ? 'Not set'
                  : controller.text.trim())),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final duration = int.tryParse(_duration.text.trim());
    final price = double.tryParse(_price.text.trim());
    if (duration == null || price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Duration and price must be numbers.')),
      );
      return;
    }

    setState(() => _saving = true);
    final name = '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim();
    final updated = await widget.api.updateTeacher(widget.teacher.id, {
      'id': widget.teacher.id,
      'name': name.isEmpty ? widget.teacher.displayName : name,
      'firstName': _firstName.text.trim(),
      'lastName': _lastName.text.trim(),
      'studioName': _studioName.text.trim(),
      'email': _email.text.trim(),
      'telephone': _phone.text.trim(),
      'address': _address.text.trim(),
      'city': _city.text.trim(),
      'postalCode': _postalCode.text.trim(),
      'mainInstrument': _mainInstrument.text.trim(),
      'otherInstruments': _otherInstruments.text.trim(),
      'defaultLessonDuration': duration,
      'defaultLessonPrice': price,
      'currency': _currency.text.trim(),
      'profileImagePath': widget.teacher.profileImagePath,
    });
    if (!mounted) return;
    setState(() {
      _saving = false;
      _editing = false;
    });
    widget.onTeacherChanged(updated);
  }
}
