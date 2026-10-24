import 'package:supabase_flutter/supabase_flutter.dart';

/// All student reads go through the checked database projection. The client
/// never constructs a student query from a typed student or teacher ID.
class StudentPortalService {
  const StudentPortalService(this.client);

  final SupabaseClient client;

  Future<List<Map<String, dynamic>>> loadPortals() async {
    final result = await client.rpc('maestro_student_portal_data');
    return (result as List<dynamic>)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
  }

  Future<void> accept(String token) async {
    await client.rpc('maestro_accept_student_invitation',
        params: {'p_token': token.trim()});
  }

  Future<Map<String, dynamic>> loadAccess(int studentAppId) async {
    final teacher = await client
        .from('teachers')
        .select('id')
        .eq('user_id', client.auth.currentUser!.id)
        .single();
    final student = await client
        .from('students')
        .select('id')
        .eq('app_id', studentAppId)
        .single();
    final teacherId = teacher['id'] as String;
    final studentId = student['id'] as String;
    final access = await client
        .from('student_portal_access')
        .select()
        .eq('teacher_id', teacherId)
        .eq('student_id', studentId)
        .maybeSingle();
    final invitations = await client
        .from('student_invitations')
        .select('id,email,expires_at,accepted_at,revoked_at,created_at')
        .eq('teacher_id', teacherId)
        .eq('student_id', studentId)
        .order('created_at', ascending: false);
    final pieces = await client.rpc('maestro_teacher_piece_progress',
        params: {'p_student_app_id': studentAppId});
    return {
      'access': access == null ? null : Map<String, dynamic>.from(access),
      'invitations':
          invitations.map((value) => Map<String, dynamic>.from(value)).toList(),
      'pieces': (pieces as List<dynamic>)
          .map((value) => Map<String, dynamic>.from(value as Map))
          .toList(),
    };
  }

  Future<Map<String, dynamic>> invite(int studentAppId, String email) async {
    final value = await client.rpc('maestro_invite_student', params: {
      'p_student_app_id': studentAppId,
      'p_email': email,
    });
    return Map<String, dynamic>.from(value as Map);
  }

  Future<void> revokeInvitation(String id) async {
    await client.rpc('maestro_revoke_student_invitation',
        params: {'p_invitation_id': id});
  }

  Future<void> setAccess(int studentAppId, Map<String, bool> settings) async {
    await client.rpc('maestro_set_student_access', params: {
      'p_student_app_id': studentAppId,
      'p_settings': settings,
    });
  }

  Future<void> unlinkAccess(int studentAppId) async {
    await client.rpc('maestro_unlink_student_access',
        params: {'p_student_app_id': studentAppId});
  }

  Future<void> setNoteShared(int noteAppId, bool shared) async {
    await client.rpc('maestro_set_note_shared',
        params: {'p_note_app_id': noteAppId, 'p_shared': shared});
  }

  Future<void> setPieceProgress(
      int pieceAppId, String status, String instructions, bool shared) async {
    await client.rpc('maestro_set_piece_progress', params: {
      'p_piece_app_id': pieceAppId,
      'p_status': status,
      'p_instructions': instructions,
      'p_instructions_shared': shared,
    });
  }
}
