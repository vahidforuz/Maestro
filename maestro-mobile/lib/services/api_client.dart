import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  ApiClient({required String baseUrl, http.Client? httpClient})
      : baseUri = Uri.parse(_trimTrailingSlash(baseUrl)),
        _httpClient = httpClient ?? http.Client();

  final Uri baseUri;
  final http.Client _httpClient;

  Future<List<dynamic>> getList(String path) async {
    final response = await _httpClient.get(_uri(path));
    _log('GET', path, response.statusCode);
    final decoded = _decode(response);
    if (decoded is List<dynamic>) {
      return decoded;
    }
    throw const ApiException('Expected a JSON array from the API.');
  }

  Future<Map<String, dynamic>> getMap(String path) async {
    final response = await _httpClient.get(_uri(path));
    _log('GET', path, response.statusCode);
    final decoded = _decode(response);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const ApiException('Expected a JSON object from the API.');
  }

  Future<Map<String, dynamic>> postMap(
      String path, Map<String, dynamic> body) async {
    final response = await _httpClient.post(
      _uri(path),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    _log('POST', path, response.statusCode);
    final decoded = _decode(response);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const ApiException('Expected a JSON object from the API.');
  }

  Future<Map<String, dynamic>> putMap(
      String path, Map<String, dynamic> body) async {
    final response = await _httpClient.put(
      _uri(path),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    _log('PUT', path, response.statusCode);
    final decoded = _decode(response);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const ApiException('Expected a JSON object from the API.');
  }

  Future<Map<String, dynamic>> deleteMap(String path) async {
    final response = await _httpClient.delete(_uri(path));
    _log('DELETE', path, response.statusCode);
    final decoded = _decode(response);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const ApiException('Expected a JSON object from the API.');
  }

  Object? _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.body.isEmpty ? 'Request failed.' : response.body,
        statusCode: response.statusCode,
      );
    }
    if (response.body.isEmpty) {
      return null;
    }
    return jsonDecode(response.body);
  }

  Uri _uri(String path) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return baseUri.replace(path: '${baseUri.path}/$cleanPath');
  }

  void _log(String method, String path, int statusCode) {
    if (kDebugMode) {
      debugPrint('$method ${_uri(path)} -> $statusCode');
    }
  }

  static String _trimTrailingSlash(String value) {
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }
}
