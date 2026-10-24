import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Native upload streams the selected file from disk.
Future<void> uploadMessageFile(SupabaseClient client, String bucket,
    String path, XFile file, String mimeType) async {
  await client.storage.from(bucket).upload(path, File(file.path),
      fileOptions: FileOptions(contentType: mimeType, upsert: false));
}
