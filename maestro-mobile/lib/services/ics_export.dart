import 'dart:convert';

class IcsEvent {
  const IcsEvent({
    required this.uid,
    required this.startUtc,
    required this.endUtc,
    required this.summary,
    this.transparent = false,
  });
  final String uid;
  final DateTime startUtc;
  final DateTime endUtc;
  final String summary;
  final bool transparent;
}

/// RFC 5545 UTC events avoid a VTIMEZONE dependency in importing clients.
String buildIcsCalendar(Iterable<IcsEvent> events, {DateTime? generatedAt}) {
  final stamp = _utcStamp(generatedAt ?? DateTime.now());
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Maestro//Calendar Export//EN',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
  ];
  for (final event in events) {
    if (!event.endUtc.isAfter(event.startUtc)) {
      throw ArgumentError('ICS event end must be after start');
    }
    lines.addAll([
      'BEGIN:VEVENT',
      'UID:${_escape(event.uid)}@maestro',
      'DTSTAMP:$stamp',
      'DTSTART:${_utcStamp(event.startUtc)}',
      'DTEND:${_utcStamp(event.endUtc)}',
      'SUMMARY:${_escape(event.summary)}',
      'TRANSP:${event.transparent ? 'TRANSPARENT' : 'OPAQUE'}',
      if (!event.transparent) 'CLASS:PRIVATE',
      'END:VEVENT',
    ]);
  }
  lines.add('END:VCALENDAR');
  return '${lines.map(_fold).join('\r\n')}\r\n';
}

String _utcStamp(DateTime value) {
  final date = value.toUtc();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${date.year.toString().padLeft(4, '0')}${two(date.month)}${two(date.day)}'
      'T${two(date.hour)}${two(date.minute)}${two(date.second)}Z';
}

String _escape(String value) => value
    .replaceAll('\\', '\\\\')
    .replaceAll('\n', '\\n')
    .replaceAll('\r', '')
    .replaceAll(';', '\\;')
    .replaceAll(',', '\\,');

String _fold(String line) {
  final result = StringBuffer();
  var length = 0;
  for (final rune in line.runes) {
    final character = String.fromCharCode(rune);
    final bytes = utf8.encode(character).length;
    if (length + bytes > 75) {
      result.write('\r\n ');
      length = 1;
    }
    result.write(character);
    length += bytes;
  }
  return result.toString();
}
