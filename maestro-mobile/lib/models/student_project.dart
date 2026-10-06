import 'student_course.dart';

class StudentProject {
  const StudentProject({
    required this.id,
    required this.name,
    required this.paidCourseCount,
    required this.courses,
    required this.pieces,
  });

  final int id;
  final String name;
  final int paidCourseCount;
  final List<StudentCourse> courses;
  final List<String> pieces;

  factory StudentProject.fromJson(Map<String, dynamic> json) {
    return StudentProject(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Project',
      paidCourseCount: json['paidCourseCount'] as int? ?? 0,
      courses: (json['courses'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(StudentCourse.fromJson)
          .toList(),
      pieces: (json['pieces'] as List<dynamic>? ?? const [])
          .map((piece) => piece.toString())
          .toList(),
    );
  }
}
