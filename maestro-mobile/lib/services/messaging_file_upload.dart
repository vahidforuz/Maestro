import 'package:file_selector/file_selector.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Browsers expose picker files as bytes rather than file-system paths.
Future<void> uploadMessageFile(SupabaseClient client, String bucket,
    String path, XFile file, String mimeType) async {
  await client.storage.from(bucket).uploadBinary(path, await file.readAsBytes(),
      fileOptions: FileOptions(contentType: mimeType, upsert: false));
}
