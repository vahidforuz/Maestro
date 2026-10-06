import '../models/payment.dart';
import '../models/student.dart';
import '../models/teacher.dart';
import 'api_client.dart';

class MaestroApi {
  const MaestroApi(this._client);

  final ApiClient _client;

  Uri get baseUri => _client.baseUri;

  Future<List<Student>> fetchStudents() async {
    final json = await _client.getList('/students');
    return json
        .whereType<Map<String, dynamic>>()
        .map(Student.fromJson)
        .toList();
  }

  Future<Student> fetchStudent(int id) async {
    return Student.fromJson(await _client.getMap('/students/$id'));
  }

  Future<List<Payment>> fetchPayments() async {
    final json = await _client.getList('/payments');
    return json
        .whereType<Map<String, dynamic>>()
        .map(Payment.fromJson)
        .toList();
  }

  Future<List<Payment>> fetchStudentPayments(int studentId) async {
    final json = await _client.getList('/students/$studentId/payments');
    return json
        .whereType<Map<String, dynamic>>()
        .map(Payment.fromJson)
        .toList();
  }

  Future<List<Teacher>> fetchTeachers() async {
    final json = await _client.getList('/teachers');
    return json
        .whereType<Map<String, dynamic>>()
        .map(Teacher.fromJson)
        .toList();
  }

  Future<Teacher> fetchTeacher(int id) async {
    return Teacher.fromJson(await _client.getMap('/teachers/$id'));
  }

  Future<Teacher> createTeacher(Map<String, dynamic> request) async {
    return Teacher.fromJson(await _client.postMap('/teachers', request));
  }

  Future<Teacher> updateTeacher(int id, Map<String, dynamic> request) async {
    return Teacher.fromJson(await _client.putMap('/teachers/$id', request));
  }

  Future<Student> createStudent(Map<String, dynamic> request) async {
    return Student.fromJson(await _client.postMap('/students', request));
  }

  Future<Payment> createPayment(
      int studentId, Map<String, dynamic> request) async {
    return Payment.fromJson(
        await _client.postMap('/students/$studentId/payments', request));
  }

  Future<Student> addProject(int studentId, Map<String, dynamic> request) {
    return _studentFromMap(
        _client.postMap('/students/$studentId/projects', request));
  }

  Future<Student> updateProject(
      int studentId, int projectId, Map<String, dynamic> request) {
    return _studentFromMap(
        _client.putMap('/students/$studentId/projects/$projectId', request));
  }

  Future<Student> deleteProject(int studentId, int projectId) {
    return _studentFromMap(
        _client.deleteMap('/students/$studentId/projects/$projectId'));
  }

  Future<Student> addPiece(
      int studentId, int projectId, Map<String, dynamic> request) {
    return _studentFromMap(_client.postMap(
        '/students/$studentId/projects/$projectId/pieces', request));
  }

  Future<Student> updatePiece(int studentId, int projectId, int pieceIndex,
      Map<String, dynamic> request) {
    return _studentFromMap(_client.putMap(
        '/students/$studentId/projects/$projectId/pieces/$pieceIndex',
        request));
  }

  Future<Student> deletePiece(int studentId, int projectId, int pieceIndex) {
    return _studentFromMap(_client.deleteMap(
        '/students/$studentId/projects/$projectId/pieces/$pieceIndex'));
  }

  Future<Student> addCourse(int studentId, int projectId) {
    return _studentFromMap(_client
        .postMap('/students/$studentId/projects/$projectId/courses', {}));
  }

  Future<Student> updateCourse(int studentId, int projectId, int courseId,
      Map<String, dynamic> request) {
    return _studentFromMap(_client.putMap(
        '/students/$studentId/projects/$projectId/courses/$courseId', request));
  }

  Future<Student> deleteCourse(int studentId, int projectId, int courseId) {
    return _studentFromMap(_client.deleteMap(
        '/students/$studentId/projects/$projectId/courses/$courseId'));
  }

  Future<Student> addNote(int studentId, int projectId, int courseId,
      Map<String, dynamic> request) {
    return _studentFromMap(_client.postMap(
        '/students/$studentId/projects/$projectId/courses/$courseId/notes',
        request));
  }

  Future<Student> updateNote(int studentId, int projectId, int courseId,
      int noteId, Map<String, dynamic> request) {
    return _studentFromMap(_client.putMap(
        '/students/$studentId/projects/$projectId/courses/$courseId/notes/$noteId',
        request));
  }

  Future<Student> deleteNote(
      int studentId, int projectId, int courseId, int noteId) {
    return _studentFromMap(_client.deleteMap(
        '/students/$studentId/projects/$projectId/courses/$courseId/notes/$noteId'));
  }

  Future<Student> _studentFromMap(Future<Map<String, dynamic>> future) async {
    return Student.fromJson(await future);
  }
}
