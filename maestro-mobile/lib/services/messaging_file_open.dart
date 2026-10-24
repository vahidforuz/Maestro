import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> openPrivateMessageFile(SupabaseClient client, String bucket,
    Map<String, dynamic> attachment) async {
  throw UnsupportedError(
      'Private file viewing currently requires the mobile app.');
}

Future<void> clearPrivateMessageDownloads() async {}
