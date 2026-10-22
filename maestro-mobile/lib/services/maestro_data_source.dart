import '../models/payment.dart';
import '../models/student.dart';
import '../models/teacher.dart';

/// Operations used by the existing Flutter screens.
///
/// The Supabase implementation preserves the current response models and
/// existing screen workflows while PostgreSQL enforces access and writes.
abstract interface class MaestroDataSource {
  Future<List<Student>> fetchStudents();
  Future<Student> fetchStudent(int id);
  Future<List<Payment>> fetchPayments();
  Future<List<Payment>> fetchStudentPayments(int studentId);
  Future<List<Teacher>> fetchTeachers();
  Future<Teacher> fetchTeacher(int id);
  Future<Teacher> createTeacher(Map<String, dynamic> request);
  Future<Teacher> updateTeacher(int id, Map<String, dynamic> request);
  Future<Student> createStudent(Map<String, dynamic> request);
  Future<Payment> createPayment(int studentId, Map<String, dynamic> request);
  Future<Student> addProject(int studentId, Map<String, dynamic> request);
  Future<Student> updateProject(
      int studentId, int projectId, Map<String, dynamic> request);
  Future<Student> deleteProject(int studentId, int projectId);
  Future<Student> addPiece(
      int studentId, int projectId, Map<String, dynamic> request);
  Future<Student> updatePiece(int studentId, int projectId, int pieceIndex,
      Map<String, dynamic> request);
  Future<Student> deletePiece(int studentId, int projectId, int pieceIndex);
  Future<Student> addCourse(int studentId, int projectId);
  Future<Student> updateCourse(
      int studentId, int projectId, int courseId, Map<String, dynamic> request);
  Future<Student> deleteCourse(int studentId, int projectId, int courseId);
  Future<Student> addNote(
      int studentId, int projectId, int courseId, Map<String, dynamic> request);
  Future<Student> updateNote(int studentId, int projectId, int courseId,
      int noteId, Map<String, dynamic> request);
  Future<Student> deleteNote(
      int studentId, int projectId, int courseId, int noteId);
  Future<Student> markReviewReviewed(int studentId, int noteId, int courseId);
  Future<Student> keepReviewForNextCourse(
      int studentId, int noteId, int courseId);
}
