import 'dart:convert';
import 'dart:io';

import '../../../core/utils/logger.dart';

/// Minimal GET helper built on `dart:io`.
///
/// Deliberately dependency-free: adding `http` as a direct dependency for two
/// requests is not worth the resolution risk, and both context sources need
/// nothing beyond a timeout and a body.
///
/// Note this pins the feature to non-web platforms — `dart:io` does not
/// compile for web. Android and iOS are the shipping targets; if web is ever
/// added, this file needs a conditional-import shim.
Future<String?> httpGetBody(
  Uri url, {
  Duration timeout = const Duration(seconds: 8),
  Map<String, String> headers = const {},
}) async {
  HttpClient? client;
  try {
    client = HttpClient()..connectionTimeout = timeout;
    final req = await client.getUrl(url).timeout(timeout);
    headers.forEach(req.headers.set);
    final res = await req.close().timeout(timeout);
    if (res.statusCode != 200) {
      logWarn('GET ${url.host} returned ${res.statusCode}');
      return null;
    }
    return await res.transform(utf8.decoder).join().timeout(timeout);
  } catch (e, st) {
    // Context is a nice-to-have: a failed fetch must never surface an error
    // to the user or block anything. The app is offline-first by design.
    logWarn('GET ${url.host} failed', e, st);
    return null;
  } finally {
    client?.close(force: true);
  }
}

/// GET and decode a JSON object, or null on any failure.
Future<Map<String, dynamic>?> httpGetJson(
  Uri url, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  final body = await httpGetBody(url, timeout: timeout);
  if (body == null) return null;
  try {
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (e, st) {
    logWarn('Bad JSON from ${url.host}', e, st);
    return null;
  }
}
