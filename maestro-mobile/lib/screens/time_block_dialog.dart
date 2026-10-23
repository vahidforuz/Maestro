import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/time_block.dart';

enum TimeBlockAction { save, delete }

enum TimeBlockScope { occurrence, series }

class TimeBlockResult {
  const TimeBlockResult(this.action, this.scope, this.block);
  final TimeBlockAction action;
  final TimeBlockScope scope;
  final TimeBlock block;
}

class TimeBlockDialog extends StatefulWidget {
  const TimeBlockDialog(
      {super.key, required this.initial, this.occurrence, this.preset});
  final TimeBlock initial;
  final TimeBlockOccurrence? occurrence;
  final String? preset;

  @override
  State<TimeBlockDialog> createState() => _TimeBlockDialogState();
}

class _TimeBlockDialogState extends State<TimeBlockDialog> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late DateTime _start;
  late DateTime _end;
  late bool _allDay;
  late BlockCategory _category;
  late BlockRepeat _repeat;
  late Set<int> _weekdays;
  late DateTime? _until;
  TimeBlockScope _scope = TimeBlockScope.occurrence;
  String? _error;

  @override
  void initState() {
    super.initState();
    final occurrence = widget.occurrence;
    final block = widget.initial;
    _title =
        TextEditingController(text: occurrence?.displayTitle ?? block.title);
    _notes =
        TextEditingController(text: occurrence?.notes ?? block.notes ?? '');
    _start = occurrence?.start ?? block.start;
    _end = occurrence?.end ?? block.end;
    _allDay = occurrence == null
        ? block.allDay
        : occurrence.start.hour == 0 &&
            occurrence.start.minute == 0 &&
            occurrence.end.hour == 0 &&
            occurrence.end.minute == 0;
    _category = occurrence?.displayCategory ?? block.category;
    _repeat = block.repeat;
    _weekdays = block.weekdays.toSet();
    _until = block.repeatUntil;
    if (widget.preset != null) _applyPreset(widget.preset!);
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  DateTime _dateWith(DateTime date, DateTime time) =>
      DateTime.utc(date.year, date.month, date.day, time.hour, time.minute);

  Future<void> _pickDate(bool start) async {
    final current = start
        ? _start
        : (_allDay ? _end.subtract(const Duration(days: 1)) : _end);
    final picked = await showDatePicker(
        context: context,
        initialDate: current,
        firstDate: DateTime.utc(2020),
        lastDate: DateTime.utc(2100));
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = _dateWith(picked, _start);
      } else {
        _end = _dateWith(
            _allDay
                ? DateTime.utc(picked.year, picked.month, picked.day + 1)
                : picked,
            _end);
      }
    });
  }

  Future<void> _pickTime(bool start) async {
    final current = start ? _start : _end;
    final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: current.hour, minute: current.minute));
    if (picked == null) return;
    setState(() {
      final date = DateTime.utc(
          current.year, current.month, current.day, picked.hour, picked.minute);
      if (start) {
        _start = date;
      } else {
        _end = date;
      }
    });
  }

  void _applyPreset(String preset) {
    final day = DateTime.utc(_start.year, _start.month, _start.day);
    setState(() {
      switch (preset) {
        case 'Sleep':
          _title.text = 'Sleep';
          _category = BlockCategory.sleep;
          _allDay = false;
          _repeat = BlockRepeat.daily;
          _start = DateTime.utc(day.year, day.month, day.day, 23);
          _end = DateTime.utc(day.year, day.month, day.day + 1, 7);
        case 'Vacation':
          _title.text = 'Vacation';
          _category = BlockCategory.vacation;
          _allDay = true;
          _repeat = BlockRepeat.never;
          _start = day;
          _end = DateTime.utc(day.year, day.month, day.day + 1);
        case 'Day Off':
          _title.text = 'Day off';
          _category = BlockCategory.other;
          _allDay = true;
          _repeat = BlockRepeat.weekly;
          _start = day;
          _end = DateTime.utc(day.year, day.month, day.day + 1);
      }
    });
  }

  void _switchScope(TimeBlockScope scope) {
    final occurrence = widget.occurrence;
    if (occurrence == null) return;
    final block = widget.initial;
    setState(() {
      _scope = scope;
      if (scope == TimeBlockScope.series) {
        _start = block.start;
        _end = block.end;
        _allDay = block.allDay;
        _title.text = block.title;
        _category = block.category;
        _notes.text = block.notes ?? '';
      } else {
        _start = occurrence.start;
        _end = occurrence.end;
        _allDay = occurrence.start.hour == 0 &&
            occurrence.start.minute == 0 &&
            occurrence.end.hour == 0 &&
            occurrence.end.minute == 0;
        _title.text = occurrence.displayTitle;
        _category = occurrence.displayCategory;
        _notes.text = occurrence.notes ?? block.notes ?? '';
      }
    });
  }

  TimeBlock _draft() => TimeBlock(
        id: widget.initial.id,
        title: _title.text.trim(),
        category: _category,
        start: _start,
        end: _end,
        allDay: _allDay,
        repeat: _repeat,
        weekdays:
            _repeat == BlockRepeat.custom ? (_weekdays.toList()..sort()) : [],
        repeatUntil: _repeat == BlockRepeat.never ? null : _until,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        exceptions: widget.initial.exceptions,
      );

  void _save() {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Enter a title or reason.');
      return;
    }
    if (!_end.isAfter(_start)) {
      setState(() => _error = 'End must be after start.');
      return;
    }
    if (_end.difference(_start) > const Duration(days: 366)) {
      setState(() => _error = 'Choose a range of at most 366 days.');
      return;
    }
    if (_repeat == BlockRepeat.custom && _weekdays.isEmpty) {
      setState(() => _error = 'Select at least one weekday.');
      return;
    }
    if (_until != null &&
        DateTime.utc(_until!.year, _until!.month, _until!.day)
            .isBefore(DateTime.utc(_start.year, _start.month, _start.day))) {
      setState(() => _error = 'Repeat end must be on or after start.');
      return;
    }
    Navigator.pop(
        context, TimeBlockResult(TimeBlockAction.save, _scope, _draft()));
  }

  Future<void> _delete() async {
    if (widget.initial.repeat != BlockRepeat.never) {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Delete repeating block?'),
                content: Text(_scope == TimeBlockScope.series
                    ? 'Delete the entire series and all its occurrence edits?'
                    : 'Delete only this occurrence?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete')),
                ],
              ));
      if (confirmed != true || !mounted) return;
    }
    Navigator.pop(
        context, TimeBlockResult(TimeBlockAction.delete, _scope, _draft()));
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd();
    final timeFormat = DateFormat.Hm();
    final endDate =
        _allDay ? DateTime.utc(_end.year, _end.month, _end.day - 1) : _end;
    return AlertDialog(
      title:
          Text(widget.initial.id.isEmpty ? 'Block time' : 'Edit blocked time'),
      content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                if (widget.initial.id.isEmpty)
                  Wrap(spacing: 6, children: [
                    for (final preset in ['Sleep', 'Vacation', 'Day Off'])
                      ActionChip(
                          label: Text(preset),
                          onPressed: () => _applyPreset(preset)),
                  ]),
                TextField(
                    controller: _title,
                    maxLength: 120,
                    decoration:
                        const InputDecoration(labelText: 'Title or reason')),
                DropdownButtonFormField<BlockCategory>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final category in BlockCategory.values)
                      DropdownMenuItem(
                          value: category,
                          child: Text(switch (category) {
                            BlockCategory.breakTime => 'Break',
                            BlockCategory.sleep => 'Sleep',
                            BlockCategory.vacation => 'Vacation',
                            BlockCategory.personal => 'Personal',
                            BlockCategory.other => 'Other',
                          }))
                  ],
                  onChanged: (value) => setState(() => _category = value!),
                ),
                SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('All day'),
                    value: _allDay,
                    onChanged: (value) => setState(() {
                          _allDay = value;
                          if (value) {
                            _start = DateTime.utc(
                                _start.year, _start.month, _start.day);
                            _end = DateTime.utc(
                                _end.year,
                                _end.month,
                                _end.day +
                                    (_end.hour == 0 && _end.minute == 0
                                        ? 0
                                        : 1));
                          }
                        })),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  OutlinedButton(
                      onPressed: () => _pickDate(true),
                      child: Text('Start: ${dateFormat.format(_start)}')),
                  if (!_allDay)
                    OutlinedButton(
                        onPressed: () => _pickTime(true),
                        child: Text(timeFormat.format(_start))),
                  OutlinedButton(
                      onPressed: () => _pickDate(false),
                      child: Text('End: ${dateFormat.format(endDate)}')),
                  if (!_allDay)
                    OutlinedButton(
                        onPressed: () => _pickTime(false),
                        child: Text(timeFormat.format(_end))),
                ]),
                if (widget.occurrence != null &&
                    widget.initial.repeat != BlockRepeat.never)
                  DropdownButtonFormField<TimeBlockScope>(
                    initialValue: _scope,
                    decoration:
                        const InputDecoration(labelText: 'Apply changes to'),
                    items: const [
                      DropdownMenuItem(
                          value: TimeBlockScope.occurrence,
                          child: Text('This occurrence')),
                      DropdownMenuItem(
                          value: TimeBlockScope.series,
                          child: Text('Entire series')),
                    ],
                    onChanged: (value) => _switchScope(value!),
                  ),
                if (widget.occurrence == null ||
                    _scope == TimeBlockScope.series)
                  DropdownButtonFormField<BlockRepeat>(
                    initialValue: _repeat,
                    decoration: const InputDecoration(labelText: 'Repeat'),
                    items: const [
                      DropdownMenuItem(
                          value: BlockRepeat.never, child: Text('Never')),
                      DropdownMenuItem(
                          value: BlockRepeat.daily, child: Text('Daily')),
                      DropdownMenuItem(
                          value: BlockRepeat.weekly, child: Text('Weekly')),
                      DropdownMenuItem(
                          value: BlockRepeat.custom, child: Text('Custom')),
                    ],
                    onChanged: (value) => setState(() => _repeat = value!),
                  ),
                if (_repeat == BlockRepeat.custom &&
                    (widget.occurrence == null ||
                        _scope == TimeBlockScope.series))
                  Wrap(spacing: 2, children: [
                    for (var day = 1; day <= 7; day++)
                      FilterChip(
                          label: Text(
                              ['M', 'T', 'W', 'T', 'F', 'S', 'S'][day - 1]),
                          selected: _weekdays.contains(day),
                          onSelected: (selected) => setState(() => selected
                              ? _weekdays.add(day)
                              : _weekdays.remove(day))),
                  ]),
                if (_repeat != BlockRepeat.never &&
                    (widget.occurrence == null ||
                        _scope == TimeBlockScope.series))
                  Row(children: [
                    Expanded(
                        child: Text(_until == null
                            ? 'No repeat end date'
                            : 'Repeat until ${dateFormat.format(_until!)}')),
                    if (_until != null)
                      IconButton(
                          onPressed: () => setState(() => _until = null),
                          icon: const Icon(Icons.close),
                          tooltip: 'Clear repeat end'),
                    TextButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                              context: context,
                              initialDate: _until ?? _start,
                              firstDate: DateTime.utc(
                                  _start.year, _start.month, _start.day),
                              lastDate: DateTime.utc(2100));
                          if (date != null) setState(() => _until = date);
                        },
                        child: const Text('Choose')),
                  ]),
                TextField(
                    controller: _notes,
                    maxLength: 2000,
                    maxLines: 2,
                    decoration:
                        const InputDecoration(labelText: 'Notes (optional)')),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red)),
              ]))),
      actions: [
        if (widget.initial.id.isNotEmpty)
          TextButton(onPressed: _delete, child: const Text('Delete')),
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
