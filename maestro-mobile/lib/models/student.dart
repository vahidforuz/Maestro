import 'student_course.dart';
import 'student_project.dart';

class Student {
  const Student({
    required this.id,
    required this.name,
    required this.firstName,
    required this.familyName,
    this.email,
    this.phone,
    this.birthday,
    this.status,
    this.instrument,
    this.level,
    this.teacherId,
    this.courseDay,
    this.courseHour,
    required this.coursePrice,
    required this.present,
    required this.firstCourseStatus,
    required this.nextWeekAssignment,
    required this.thisWeekComment,
    required this.paymentCreditBalance,
    required this.courses,
    required this.projects,
  });

  final int id;
  final String name;
  final String firstName;
  final String familyName;
  final String? email;
  final String? phone;
  final DateTime? birthday;
  final String? status;
  final String? instrument;
  final String? level;
  final int? teacherId;
  final String? courseDay;
  final String? courseHour;
  final double coursePrice;
  final bool present;
  final String firstCourseStatus;
  final String nextWeekAssignment;
  final String thisWeekComment;
  final double paymentCreditBalance;
  final List<StudentCourse> courses;
  final List<StudentProject> projects;

  factory Student.fromJson(Map<String, dynamic> json) {
    final firstName = json['firstName'] as String? ?? '';
    final familyName = json['familyName'] as String? ?? '';
    final computedName = '$firstName $familyName'.trim();

    return Student(
      id: json['id'] as int? ?? 0,
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : computedName,
      firstName: firstName,
      familyName: familyName,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      birthday: _parseDate(json['birthday']),
      status: json['status'] as String?,
      instrument: json['instrument'] as String?,
      level: json['level'] as String?,
      teacherId: json['teacherId'] as int?,
      courseDay: json['courseDay'] as String?,
      courseHour: json['courseHour']?.toString(),
      coursePrice: (json['coursePrice'] as num?)?.toDouble() ?? 0,
      present: json['present'] as bool? ?? false,
      firstCourseStatus: json['firstCourseStatus'] as String? ?? 'NOTHING',
      nextWeekAssignment: json['nextWeekAssignment'] as String? ?? '',
      thisWeekComment: json['thisWeekComment'] as String? ?? '',
      paymentCreditBalance:
          (json['paymentCreditBalance'] as num?)?.toDouble() ?? 0,
      courses: (json['courses'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(StudentCourse.fromJson)
          .toList(),
      projects: (json['projects'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(StudentProject.fromJson)
          .toList(),
    );
  }

  String get displayName => name.isEmpty ? 'Unnamed student' : name;

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
