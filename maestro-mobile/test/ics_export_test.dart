import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro_mobile/services/ics_export.dart';

void main() {
  test('UTC ICS export uses private lesson and transparent availability events',
      () {
    final ics = buildIcsCalendar([
      IcsEvent(
          uid: 'lesson-1001',
          startUtc: DateTime.utc(2026, 11, 2, 14),
          endUtc: DateTime.utc(2026, 11, 2, 14, 45),
          summary: 'Lesson'),
      IcsEvent(
          uid: 'free-1',
          startUtc: DateTime.utc(2026, 11, 2, 15),
          endUtc: DateTime.utc(2026, 11, 2, 16),
          summary: 'Available',
          transparent: true),
    ], generatedAt: DateTime.utc(2026, 10, 23, 12));
    expect(ics, startsWith('BEGIN:VCALENDAR\r\nVERSION:2.0\r\n'));
    expect(ics, contains('DTSTART:20261102T140000Z\r\n'));
    expect(ics, contains('DTEND:20261102T144500Z\r\n'));
    expect(ics, contains('CLASS:PRIVATE\r\n'));
    expect(ics, contains('TRANSP:TRANSPARENT\r\n'));
    expect(ics, endsWith('END:VCALENDAR\r\n'));
    expect(ics, isNot(contains('Student')));
    for (final line in ics.split('\r\n')) {
      expect(utf8.encode(line).length, lessThanOrEqualTo(75));
    }
  });
}
