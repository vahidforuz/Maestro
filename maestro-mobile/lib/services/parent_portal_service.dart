import 'package:supabase_flutter/supabase_flutter.dart';

class ParentPortalService {
  const ParentPortalService(this.client);

  final SupabaseClient client;

  Future<List<Map<String, dynamic>>> loadPortals() async {
    final value = await client.rpc('maestro_parent_portal_data');
    return (value as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<bool> checkInvitation(String token, String email) async =>
      await client.rpc('maestro_check_parent_invitation', params: {
        'p_token': token,
        'p_email': email,
      }) as bool;

  Future<void> accept(String token) async {
    await client
        .rpc('maestro_accept_parent_invitation', params: {'p_token': token});
  }

  Future<Map<String, dynamic>> management(int studentId) async {
    final value = await client.rpc('maestro_parent_management',
        params: {'p_student_app_id': studentId});
    return Map<String, dynamic>.from(value as Map);
  }

  Future<Map<String, dynamic>> invite(
      int studentId, String name, String email, {String relationship = 'Other'}) async {
    try {
      final response = await client.functions.invoke('send-invitation', body: {
        'kind': 'parent',
        'studentId': studentId,
        'name': name,
        'email': email,
        'relationship': relationship,
      });
      return Map<String, dynamic>.from(response.data as Map);
    } on FunctionsHttpException catch (error) {
      // Kong emits this response before the Edge Function runs when it cannot
      // resolve the local Edge Runtime container. The checked teacher RPC can
      // still issue a token for manual delivery. A missing mail configuration
      // is also known to fail before the function issues its own token.
      final details = error.details.toString();
      final gatewayUnavailable =
          error.status == 503 && details.contains('name resolution failed');
      final emailUnconfigured = error.status == 400 &&
          details.contains('Invitation email is not configured.');
      if (!gatewayUnavailable && !emailUnconfigured) {
        rethrow;
      }
      final value = await client.rpc('maestro_invite_parent', params: {
        'p_student_app_id': studentId,
        'p_name': name,
        'p_email': email,
        'p_relationship': relationship,
      });
      return {
        ...Map<String, dynamic>.from(value as Map),
        'delivered': false,
      };
    }
  }

  Future<void> revokeInvitation(String id) async {
    await client.rpc('maestro_revoke_parent_invitation',
        params: {'p_invitation_id': id});
  }

  Future<void> remove(int studentId, String parentUserId) async {
    await client.rpc('maestro_remove_parent_access', params: {
      'p_student_app_id': studentId,
      'p_parent_user_id': parentUserId,
    });
  }
}
