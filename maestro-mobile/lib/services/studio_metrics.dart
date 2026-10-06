import '../models/payment.dart';
import '../models/student.dart';
import '../models/student_course.dart';
import '../models/teacher.dart';

bool isVisibleForTeacher(Student student, Teacher teacher) {
  return student.teacherId == null || student.teacherId == teacher.id;
}

List<Student> visibleStudentsForTeacher(
    List<Student> students, Teacher teacher) {
  return students
      .where((student) => isVisibleForTeacher(student, teacher))
      .toList();
}

List<Payment> visiblePaymentsForTeacher(
  List<Payment> payments,
  List<Student> students,
  Teacher teacher,
) {
  final visibleIds = visibleStudentsForTeacher(students, teacher)
      .map((student) => student.id)
      .toSet();
  return payments
      .where((payment) =>
          payment.studentId == null || visibleIds.contains(payment.studentId))
      .toList();
}

double paymentBalance(Student student, List<Payment> payments) {
  final paid = payments
      .where((payment) => payment.studentId == student.id)
      .fold<double>(0, (total, payment) => total + payment.amount);
  final charged = student.courses
      .where(
          (course) => course.status == 'PRESENT' || course.status == 'ABSENT')
      .fold<double>(0, (total, course) => total + course.price);
  return paid - charged;
}

List<LessonItem> lessonsForStudents(List<Student> students) {
  final lessons = <LessonItem>[];
  for (final student in students) {
    for (final course in student.courses) {
      lessons.add(LessonItem(student: student, course: course));
    }
  }
  lessons.sort((first, second) {
    final firstDate = first.course.date;
    final secondDate = second.course.date;
    if (firstDate == null && secondDate != null) return 1;
    if (firstDate != null && secondDate == null) return -1;
    if (firstDate != null && secondDate != null) {
      final dateCompare = firstDate.compareTo(secondDate);
      if (dateCompare != 0) return dateCompare;
    }
    return first.student.displayName.compareTo(second.student.displayName);
  });
  return lessons;
}

class LessonItem {
  const LessonItem({required this.student, required this.course});

  final Student student;
  final StudentCourse course;
}
