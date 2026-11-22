import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_api.dart';

class AuthProvider extends ChangeNotifier {
  static const _key = 'auth_session_v1';
  final SharedPreferences _prefs;
  AuthSession? _session;
  bool busy = false;

  AuthProvider(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      try {
        _session = AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
  }

  bool get signedIn => _session != null;
  String? get email => _session?.email;

  Future<void> _set(AuthSession? s) async {
    _session = s;
    if (s == null) {
      await _prefs.remove(_key);
    } else {
      await _prefs.setString(_key, jsonEncode(s.toJson()));
    }
    notifyListeners();
  }

  /// Returns an error message, or null on success.
  Future<String?> signIn(String email, String password, {required bool create}) async {
    busy = true;
    notifyListeners();
    try {
      final s = create
          ? await SupabaseApi.signUp(email.trim(), password)
          : await SupabaseApi.signIn(email.trim(), password);
      busy = false;
      await _set(s);
      return null;
    } on ApiException catch (e) {
      busy = false;
      notifyListeners();
      return e.message;
    }
  }

  Future<void> signOut() => _set(null);

  /// A valid access token, refreshed when it is about to expire. Null if signed out.
  Future<String?> token() async {
    final s = _session;
    if (s == null) return null;
    if (s.expiresAt.difference(DateTime.now()).inMinutes > 2) return s.accessToken;
    try {
      final n = await SupabaseApi.refresh(s.refreshToken);
      await _set(n);
      return n.accessToken;
    } on ApiException catch (e) {
      // Only sign out when the server rejected the refresh token, not on network errors.
      if (e.message.startsWith('Session expired')) await _set(null);
      return null;
    }
  }
}
