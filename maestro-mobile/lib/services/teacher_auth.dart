import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class TeacherAuth {
  bool get hasSession;
  String? get email;
  Stream<bool> get sessionChanges;
  Future<bool> canCreateTeacherProfile();
  Future<void> signIn(String email, String password);
  Future<bool> signUp(String email, String password);
  Future<void> signOut();
}

class SupabaseTeacherAuth implements TeacherAuth {
  const SupabaseTeacherAuth(this._client);

  final SupabaseClient _client;

  Map<String, dynamic>? get pendingTeacherProfile {
    final user = _client.auth.currentUser;
    if (user?.emailConfirmedAt == null) return null;
    final value = user?.userMetadata?['maestro_teacher_profile'];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  Future<bool> registerTeacher(String email, String password,
      Map<String, dynamic> profile) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'maestro_signup_kind': 'teacher',
        'maestro_teacher_profile': profile,
      },
    );
    return response.session != null;
  }

  Future<void> resetPassword(String email) =>
      _client.auth.resetPasswordForEmail(email);

  @override
  bool get hasSession => _client.auth.currentSession != null;

  @override
  String? get email => _client.auth.currentUser?.email;

  @override
  Stream<bool> get sessionChanges =>
      _client.auth.onAuthStateChange.map((event) => event.session != null);

  @override
  Future<bool> canCreateTeacherProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    final row = await _client
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
    return row?['role'] == 'user';
  }

  @override
  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<bool> signUp(String email, String password) async {
    final response =
        await _client.auth.signUp(email: email, password: password);
    return response.session != null;
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}
