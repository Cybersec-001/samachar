import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/article.dart';
import '../services/supabase_api.dart';
import 'auth_provider.dart';

class BookmarkProvider extends ChangeNotifier {
  static const _key = 'bookmarks';
  final SharedPreferences _prefs;
  final AuthProvider? _auth;
  final List<Article> _items = [];
  bool _wasSignedIn = false;
  bool syncing = false;
  String? syncError;

  BookmarkProvider(this._prefs, [this._auth]) {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      // Parse each entry independently so one corrupt bookmark only loses
      // itself instead of silently wiping the whole saved list.
      try {
        for (final e in jsonDecode(raw) as List) {
          try {
            _items.add(Article.fromSaved(e as Map<String, dynamic>));
          } catch (_) {}
        }
      } catch (_) {}
    }
    _wasSignedIn = _auth?.signedIn ?? false;
    _auth?.addListener(_onAuth);
    if (_wasSignedIn) sync();
  }

  @override
  void dispose() {
    _auth?.removeListener(_onAuth);
    super.dispose();
  }

  void _onAuth() {
    final now = _auth?.signedIn ?? false;
    if (now && !_wasSignedIn) sync();
    _wasSignedIn = now;
  }

  List<Article> get items => List.unmodifiable(_items);
  bool isSaved(Article a) => _items.any((e) => e.id == a.id);

  Future<void> _persist() => _prefs.setString(
      _key, jsonEncode(_items.map((e) => e.toJson()).toList()));

  /// Merge this device's saved articles with the account's, both ways.
  Future<void> sync() async {
    final auth = _auth;
    if (auth == null || !auth.signedIn || syncing) return;
    syncing = true;
    syncError = null;
    notifyListeners();
    try {
      final token = await auth.token();
      if (token == null) throw ApiException('Sign in again to sync.');
      final remote = await SupabaseApi.fetchBookmarks(token);
      final remoteIds = remote.map((a) => a.id).toSet();
      final localIds = _items.map((a) => a.id).toSet();
      for (final a in _items.where((a) => !remoteIds.contains(a.id))) {
        await SupabaseApi.upsertBookmark(token, a);
      }
      for (final a in remote.where((a) => !localIds.contains(a.id))) {
        _items.add(a);
      }
      await _persist();
    } on ApiException catch (e) {
      syncError = e.message;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> toggle(Article a) async {
    final i = _items.indexWhere((e) => e.id == a.id);
    final removing = i >= 0;
    if (removing) {
      _items.removeAt(i);
    } else {
      _items.insert(0, a);
    }
    notifyListeners();
    await _persist();
    final auth = _auth;
    if (auth != null && auth.signedIn) {
      try {
        final token = await auth.token();
        if (token == null) return;
        if (removing) {
          await SupabaseApi.deleteBookmark(token, a);
        } else {
          await SupabaseApi.upsertBookmark(token, a);
        }
      } on ApiException catch (e) {
        syncError = e.message;
        notifyListeners();
      }
    }
  }
}
