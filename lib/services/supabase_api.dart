import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/article.dart';

class AuthSession {
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String email;
  final String userId;
  const AuthSession(
      this.accessToken, this.refreshToken, this.expiresAt, this.email, this.userId);

  Map<String, dynamic> toJson() => {
        'a': accessToken,
        'r': refreshToken,
        'e': expiresAt.toIso8601String(),
        'm': email,
        'u': userId,
      };

  static AuthSession? fromJson(Map<String, dynamic> j) {
    try {
      return AuthSession(j['a'], j['r'], DateTime.parse(j['e']), j['m'], j['u']);
    } catch (_) {
      return null;
    }
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

/// Minimal Supabase REST client (GoTrue auth + PostgREST bookmarks table).
class SupabaseApi {
  static const _base = AppConfig.supabaseUrl;
  static Map<String, String> _headers([String? token]) => {
        'apikey': AppConfig.supabaseKey,
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static Future<http.Response> _send(Future<http.Response> Function() f) async {
    try {
      return await f().timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw ApiException('Request timed out. Check your connection.');
    } catch (_) {
      throw ApiException('No internet connection.');
    }
  }

  static String _errorOf(http.Response r, String fallback) {
    try {
      final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      final m = j['msg'] ?? j['error_description'] ?? j['message'] ?? j['error'];
      if (m != null) return m.toString();
    } catch (_) {}
    return fallback;
  }

  static AuthSession _session(Map<String, dynamic> j) {
    final user = j['user'] as Map<String, dynamic>;
    final expiresIn = (j['expires_in'] as num?)?.toInt() ?? 3600;
    return AuthSession(
      j['access_token'] as String,
      j['refresh_token'] as String,
      DateTime.now().add(Duration(seconds: expiresIn)),
      (user['email'] ?? '') as String,
      user['id'] as String,
    );
  }

  static Future<AuthSession> signUp(String email, String password) async {
    final r = await _send(() => http.post(Uri.parse('$_base/auth/v1/signup'),
        headers: _headers(),
        body: jsonEncode({'email': email, 'password': password})));
    if (r.statusCode != 200) throw ApiException(_errorOf(r, 'Sign up failed.'));
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    if (j['access_token'] == null) {
      throw ApiException('Check your email to confirm your account, then sign in.');
    }
    return _session(j);
  }

  static Future<AuthSession> signIn(String email, String password) async {
    final r = await _send(() => http.post(
        Uri.parse('$_base/auth/v1/token?grant_type=password'),
        headers: _headers(),
        body: jsonEncode({'email': email, 'password': password})));
    if (r.statusCode != 200) {
      throw ApiException(_errorOf(r, 'Sign in failed.'));
    }
    return _session(jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>);
  }

  static Future<AuthSession> refresh(String refreshToken) async {
    final r = await _send(() => http.post(
        Uri.parse('$_base/auth/v1/token?grant_type=refresh_token'),
        headers: _headers(),
        body: jsonEncode({'refresh_token': refreshToken})));
    if (r.statusCode != 200) throw ApiException('Session expired. Sign in again.');
    return _session(jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>);
  }

  static Future<List<Article>> fetchBookmarks(String token) async {
    final r = await _send(() => http.get(
        Uri.parse('$_base/rest/v1/bookmarks?select=data&order=created_at.desc'),
        headers: _headers(token)));
    if (r.statusCode != 200) throw ApiException('Could not load saved articles.');
    final out = <Article>[];
    for (final row in jsonDecode(utf8.decode(r.bodyBytes)) as List) {
      try {
        out.add(Article.fromSaved((row as Map)['data'] as Map<String, dynamic>));
      } catch (_) {}
    }
    return out;
  }

  static Future<void> upsertBookmark(String token, Article a) async {
    final r = await _send(() => http.post(
        Uri.parse('$_base/rest/v1/bookmarks?on_conflict=user_id,article_id'),
        headers: {
          ..._headers(token),
          'Prefer': 'resolution=merge-duplicates,return=minimal',
        },
        body: jsonEncode({'article_id': a.id, 'data': a.toJson()})));
    if (r.statusCode >= 300) throw ApiException('Could not save to your account.');
  }

  static Future<void> deleteBookmark(String token, Article a) async {
    final r = await _send(() => http.delete(
        Uri.parse('$_base/rest/v1/bookmarks?article_id=eq.${Uri.encodeComponent(a.id)}'),
        headers: _headers(token)));
    if (r.statusCode >= 300) throw ApiException('Could not update your account.');
  }
}
