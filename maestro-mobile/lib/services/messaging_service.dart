import 'package:file_selector/file_selector.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'messaging_file_upload.dart'
    if (dart.library.io) 'messaging_file_upload_io.dart' as file_upload;
import 'messaging_file_open.dart'
    if (dart.library.io) 'messaging_file_open_io.dart' as file_open;

class MessagingService {
  MessagingService(this.client);

  final SupabaseClient client;
  static const bucket = 'maestro-messages';
  static const pageSize = 40;
  static const maxFileBytes = 20 * 1024 * 1024;
  static const uuid = Uuid();

  static Future<void> clearDownloadedFiles() async {
    try {
      await file_open.clearPrivateMessageDownloads();
    } catch (_) {
      // Sign-out must still complete if the device file system is unavailable.
    }
  }

  String get userId => client.auth.currentUser!.id;

  Future<List<Map<String, dynamic>>> candidates() async =>
      _rows(await client.rpc('maestro_message_candidates'));

  Future<List<Map<String, dynamic>>> summaries() async =>
      _rows(await client.rpc('maestro_conversation_summaries'));

  Future<bool> notificationsEnabled() async {
    final row = await client
        .from('message_notification_preferences')
        .select('enabled')
        .eq('user_id', userId)
        .maybeSingle();
    return row?['enabled'] as bool? ?? true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    await client.from('message_notification_preferences').upsert({
      'user_id': userId,
      'enabled': enabled,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> shareableReferences(
          String conversationId, String kind) async =>
      _rows(await client.rpc('maestro_shareable_references', params: {
        'p_conversation_id': conversationId,
        'p_kind': kind,
      }));

  Future<String> open(String teacherId, String studentId) async =>
      await client.rpc('maestro_open_conversation', params: {
        'p_teacher_id': teacherId,
        'p_student_id': studentId,
      }) as String;

  Future<bool> canMessage(String conversationId) async =>
      await client.rpc('maestro_can_message', params: {
        'p_conversation_id': conversationId,
      }) as bool;

  Future<List<Map<String, dynamic>>> messages(String conversationId,
      {DateTime? before, String? beforeId}) async {
    var query = client
        .from('messages')
        .select(
            'id,conversation_id,sender_id,client_id,kind,body,reference_id,created_at,message_attachments(id,storage_path,file_name,mime_type,size_bytes,duration_ms)')
        .eq('conversation_id', conversationId);
    if (before != null && beforeId != null) {
      // Stable cursor, including messages with an identical server timestamp.
      query = query.or(
          'created_at.lt.${before.toUtc().toIso8601String()},and(created_at.eq.${before.toUtc().toIso8601String()},id.lt.$beforeId)');
    }
    final rows = await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(pageSize);
    return rows
        .map((row) => Map<String, dynamic>.from(row))
        .toList()
        .reversed
        .toList();
  }

  Future<Map<String, dynamic>> send(
      String conversationId, String clientId, String kind, String body,
      {String? referenceId}) async {
    final value = await client.rpc('maestro_send_message', params: {
      'p_conversation_id': conversationId,
      'p_client_id': clientId,
      'p_kind': kind,
      'p_body': body,
      'p_reference_id': referenceId,
    });
    return Map<String, dynamic>.from(value as Map);
  }

  Future<void> markRead(String conversationId, String messageId) async {
    await client.rpc('maestro_mark_read', params: {
      'p_conversation_id': conversationId,
      'p_message_id': messageId,
    });
  }

  RealtimeChannel watchMessages(
      String conversationId, void Function(Map<String, dynamic>) onMessage) {
    return client
        .channel('messages:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) =>
              onMessage(Map<String, dynamic>.from(payload.newRecord)),
        )
        .subscribe();
  }

  RealtimeChannel watchSummaries(
      void Function() onChanged, void Function() onConnected) {
    return client
        .channel('message-summaries')
        .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            callback: (_) => onChanged())
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'conversation_reads',
            filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: userId),
            callback: (_) => onChanged())
        .subscribe((status, _) {
      if (status == RealtimeSubscribeStatus.subscribed) onConnected();
    });
  }

  RealtimeChannel watchReads(String conversationId, void Function() onChanged) {
    return client
        .channel('reads:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversation_reads',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  RealtimeChannel watchAttachments(
      String conversationId, void Function() onChanged) {
    return client
        .channel('attachments:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'message_attachments',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'conversation_id',
              value: conversationId),
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  Future<void> unwatch(RealtimeChannel channel) =>
      client.removeChannel(channel);

  Future<DateTime?> peerReadAt(String conversationId) async {
    final rows = await client
        .from('conversation_reads')
        .select('last_read_at,user_id')
        .eq('conversation_id', conversationId)
        .neq('user_id', userId)
        .limit(1);
    final value = rows.isEmpty ? null : rows.first['last_read_at'];
    return value == null ? null : DateTime.tryParse(value as String);
  }

  Future<Map<String, dynamic>> upload(
      String conversationId,
      Map<String, dynamic> message,
      XFile file,
      String fileName,
      String mimeType,
      {int? durationMs}) async {
    final prior = await client
        .from('message_attachments')
        .select()
        .eq('message_id', message['id'] as String)
        .maybeSingle();
    if (prior != null) return Map<String, dynamic>.from(prior);
    final size = await file.length();
    if (size == 0 || size > maxFileBytes) {
      throw ArgumentError('Files must be between 1 byte and 20 MB.');
    }
    const extensions = {
      'application/pdf': 'pdf',
      'image/jpeg': 'jpg',
      'image/png': 'png',
      'image/webp': 'webp',
      'audio/mpeg': 'mp3',
      'audio/mp4': 'm4a',
      'audio/wav': 'wav',
      'audio/x-wav': 'wav',
      'audio/aac': 'aac',
      'audio/ogg': 'ogg',
      'audio/webm': 'webm',
    };
    final extension = extensions[mimeType];
    if (extension == null) throw ArgumentError('Unsupported file type.');
    final path = '$conversationId/${message['id']}/${uuid.v4()}.$extension';
    await file_upload.uploadMessageFile(client, bucket, path, file, mimeType);
    try {
      final value = await client.rpc('maestro_attach_message', params: {
        'p_message_id': message['id'],
        'p_path': path,
        'p_file_name': fileName,
        'p_mime_type': mimeType,
        'p_size_bytes': size,
        'p_duration_ms': durationMs,
      });
      return Map<String, dynamic>.from(value as Map);
    } catch (_) {
      final attached = await client
          .from('message_attachments')
          .select()
          .eq('message_id', message['id'] as String)
          .maybeSingle();
      if (attached != null) return Map<String, dynamic>.from(attached);
      rethrow;
    }
  }

  Future<void> openAttachment(Map<String, dynamic> attachment) =>
      file_open.openPrivateMessageFile(client, bucket, attachment);

  static bool isImage(Map<String, dynamic> attachment) => const {
        'image/jpeg',
        'image/png',
        'image/webp'
      }.contains(attachment['mime_type']);

  Future<String> signedImageUrl(String path, {bool thumbnail = true}) =>
      client.storage.from(bucket).createSignedUrl(path, 60,
          transform: thumbnail
              ? const TransformOptions(
                  width: 480, height: 480, resize: ResizeMode.contain)
              : null);

  String authenticatedAudioUrl(String path) =>
      '${client.storage.url}/object/authenticated/$bucket/${Uri.encodeFull(path)}';

  Map<String, String> get audioHeaders =>
      Map<String, String>.from(client.storage.headers);

  static List<Map<String, dynamic>> _rows(dynamic result) => (result as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();
}
