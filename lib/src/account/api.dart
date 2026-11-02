// Talking to exceltokml.com: the same account, sign-in and email check as Excel to KML and
// Traverse & Level.
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../brand.dart';

class ApiError implements Exception {
  ApiError(this.message, {this.status, this.data = const {}});
  final String message;
  final int? status;
  final Map<String, Object?> data;

  /// The account's email isn't confirmed: the website emailed a code
  bool get needsEmailCode => data['verifyRequired'] == true && data['challenge'] is String;

  @override
  String toString() => message;
}

class Api {
  Api({required this.base, required this.client, this.platform = 'windows'});

  final String base;
  final http.Client client;
  final String platform;

  /// The session token from sign-in; sent as a Bearer token
  String? token;

  Future<Map<String, Object?>> call(String method, String path, [Map<String, Object?>? body]) async {
    final req = http.Request(method, Uri.parse('$base$path'))
      ..headers.addAll({
        'Accept': 'application/json',
        'X-App-Name': 'toolkit',
        'X-App-Platform': platform,
        'X-App-Version': appVersion,
        if (token != null) 'Authorization': 'Bearer $token',
        if (body != null) 'Content-Type': 'application/json',
      });
    if (body != null) req.body = jsonEncode(body);
    http.Response res;
    try {
      res = await http.Response.fromStream(await client.send(req).timeout(const Duration(seconds: 25)));
    } catch (_) {
      throw ApiError('Could not reach exceltokml.com. Check your connection and try again.');
    }
    Map<String, Object?> json = const {};
    try {
      final v = jsonDecode(utf8.decode(res.bodyBytes));
      if (v is Map<String, Object?>) json = v;
    } on FormatException {
      // an empty or non-JSON reply
    }
    if (res.statusCode >= 400) {
      throw ApiError(
        (json['error'] as String?) ?? 'The server answered ${res.statusCode}.',
        status: res.statusCode,
        data: json,
      );
    }
    return json;
  }
}
