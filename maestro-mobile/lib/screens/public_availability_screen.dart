import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/calendar_availability.dart';
import '../theme/maestro_theme.dart';

/// This route is usable without a Maestro session. The RPC returns only free
/// slots and display metadata after validating the revocable share token.
class PublicAvailabilityScreen extends StatefulWidget {
  const PublicAvailabilityScreen(
      {super.key, required this.client, required this.token});

  final SupabaseClient client;
  final String token;

  @override
  State<PublicAvailabilityScreen> createState() =>
      _PublicAvailabilityScreenState();
}

class _PublicAvailabilityScreenState extends State<PublicAvailabilityScreen> {
  DateTime _weekStart = _monday(DateTime.now());
  int _duration = 60;
  late Future<Map<String, dynamic>> _future = _load();

  static DateTime _monday(DateTime date) =>
      DateTime(date.year, date.month, date.day - date.weekday + 1);

  static DateTime _addDays(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);

  Future<Map<String, dynamic>> _load() async {
    final result =
        await widget.client.rpc('maestro_shared_availability', params: {
      'p_token': widget.token,
      'p_week_start': DateFormat('yyyy-MM-dd').format(_weekStart),
      'p_duration': _duration,
    });
    return Map<String, dynamic>.from(result as Map);
  }

  void _move(int weeks) => setState(() {
        _weekStart = _addDays(_weekStart, 7 * weeks);
        _future = _load();
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Maestro · Availability')),
      body: SafeArea(
          child: Padding(
        padding: const EdgeInsets.all(20),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                  child: Text(
                      'This availability link is unavailable or has expired.'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!;
            final slots = (data['slots'] as List<dynamic>? ?? const [])
                .whereType<Map>()
                .map((row) => Map<String, dynamic>.from(row))
                .toList();
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${data['teacher']} · Available times',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('Timezone: ${data['timezone']}',
                      style: const TextStyle(color: MaestroColors.muted)),
                  const SizedBox(height: 16),
                  Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        IconButton.filledTonal(
                            tooltip: 'Previous week',
                            onPressed: () => _move(-1),
                            icon: const Icon(Icons.chevron_left)),
                        OutlinedButton(
                            onPressed: () => setState(() {
                                  _weekStart = _monday(DateTime.now());
                                  _future = _load();
                                }),
                            child: const Text('Today')),
                        IconButton.filledTonal(
                            tooltip: 'Next week',
                            onPressed: () => _move(1),
                            icon: const Icon(Icons.chevron_right)),
                        Text(
                            '${DateFormat.yMMMd().format(_weekStart)} – '
                            '${DateFormat.yMMMd().format(_addDays(_weekStart, 6))}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        DropdownButton<int>(
                            value: _duration,
                            items: const [30, 45, 60]
                                .map((value) => DropdownMenuItem(
                                    value: value,
                                    child: Text('$value min slots')))
                                .toList(),
                            onChanged: (value) => setState(() {
                                  _duration = value ?? 60;
                                  _future = _load();
                                })),
                      ]),
                  const SizedBox(height: 16),
                  Expanded(
                      child: LayoutBuilder(builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1100
                        ? 7
                        : constraints.maxWidth >= 650
                            ? 3
                            : 1;
                    return GridView.builder(
                      itemCount: 7,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          mainAxisExtent: 260),
                      itemBuilder: (context, index) {
                        final day = _addDays(_weekStart, index);
                        final dayKey = DateFormat('yyyy-MM-dd').format(day);
                        final times = slots
                            .where((row) => row['date'] == dayKey)
                            .toList();
                        return Card(
                            child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          DateFormat('EEEE, MMM d').format(day),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w900)),
                                      const SizedBox(height: 10),
                                      Expanded(
                                          child: times.isEmpty
                                              ? const Text('Unavailable',
                                                  style: TextStyle(
                                                      color:
                                                          MaestroColors.muted))
                                              : ListView(children: [
                                                  for (final slot in times)
                                                    Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                bottom: 5),
                                                        child: DecoratedBox(
                                                          decoration: BoxDecoration(
                                                              color:
                                                                  MaestroColors
                                                                      .successBg,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          6)),
                                                          child: Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(7),
                                                              child: Text(
                                                                  '${clockLabel(slot['startMinute'] as int)}–'
                                                                  '${clockLabel(slot['endMinute'] as int)}',
                                                                  style: const TextStyle(
                                                                      color: MaestroColors
                                                                          .successText,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700))),
                                                        )),
                                                ])),
                                    ])));
                      },
                    );
                  })),
                  const SizedBox(height: 8),
                  const Text(
                      'Times are for viewing only. Contact the teacher to arrange a lesson.',
                      style: TextStyle(color: MaestroColors.muted)),
                ]);
          },
        ),
      )),
    );
  }
}
