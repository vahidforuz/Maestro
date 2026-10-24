import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> openPrivateMessageFile(SupabaseClient client, String bucket,
    Map<String, dynamic> attachment) async {
  final path = attachment['storage_path'] as String;
  final id = attachment['id'] as String;
  final extension = path.split('.').last;
  if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id) ||
      !RegExp(r'^[a-z0-9]{2,5}$').hasMatch(extension)) {
    throw ArgumentError('Invalid attachment path.');
  }
  final directory =
      Directory('${(await getTemporaryDirectory()).path}/maestro-attachments');
  await directory.create(recursive: true);
  final file = File('${directory.path}/$id.$extension');
  final uri = Uri.parse('${client.storage.url}/object/authenticated/$bucket/'
      '${Uri.encodeFull(path)}');
  final request = http.Request('GET', uri)
    ..headers.addAll(client.storage.headers);
  final httpClient = http.Client();
  IOSink? sink;
  try {
    final response = await httpClient.send(request);
    if (response.statusCode != 200) {
      throw StateError('Download denied (${response.statusCode}).');
    }
    if (response.contentLength != null &&
        response.contentLength! > 20 * 1024 * 1024) {
      throw StateError('File exceeds the 20 MB limit.');
    }
    sink = file.openWrite();
    var size = 0;
    await for (final chunk in response.stream) {
      size += chunk.length;
      if (size > 20 * 1024 * 1024) {
        throw StateError('File exceeds the 20 MB limit.');
      }
      sink.add(chunk);
    }
    await sink.close();
    sink = null;
    if (size != attachment['size_bytes']) {
      throw StateError('Downloaded file size does not match.');
    }
    final result = await OpenFilex.open(file.path,
        type: attachment['mime_type'] as String?);
    if (result.type != ResultType.done) throw StateError(result.message);
  } catch (_) {
    await sink?.close();
    if (await file.exists()) await file.delete();
    rethrow;
  } finally {
    httpClient.close();
  }
}

Future<void> clearPrivateMessageDownloads() async {
  final directory =
      Directory('${(await getTemporaryDirectory()).path}/maestro-attachments');
  if (await directory.exists()) await directory.delete(recursive: true);
}
