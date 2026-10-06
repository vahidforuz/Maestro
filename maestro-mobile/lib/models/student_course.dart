import 'course_note.dart';

class StudentCourse {
  const StudentCourse({
    required this.id,
    required this.title,
    this.day,
    this.date,
    this.hour,
    required this.price,
    required this.status,
    required this.assignment,
    required this.comment,
    required this.homeworkNextLesson,
    required this.notes,
  });

  final int id;
  final String title;
  final String? day;
  final DateTime? date;
  final String? hour;
  final double price;
  final String status;
  final String assignment;
  final String comment;
  final String homeworkNextLesson;
  final List<CourseNote> notes;

  factory StudentCourse.fromJson(Map<String, dynamic> json) {
    return StudentCourse(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? 'Course',
      day: json['day'] as String?,
      date: _parseDate(json['date']),
      hour: json['hour']?.toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'NOTHING',
      assignment: json['assignment'] as String? ?? '',
      comment: json['comment'] as String? ?? '',
      homeworkNextLesson: json['homeworkNextLesson'] as String? ?? '',
      notes: (json['notes'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CourseNote.fromJson)
          .toList(),
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
