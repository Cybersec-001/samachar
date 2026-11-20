import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/article.dart';

class BookmarkProvider extends ChangeNotifier {
  static const _key = 'bookmarks';
  final SharedPreferences _prefs;
  final List<Article> _items = [];

  BookmarkProvider(this._prefs) {
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
  }

  List<Article> get items => List.unmodifiable(_items);
  bool isSaved(Article a) => _items.any((e) => e.id == a.id);

  Future<void> toggle(Article a) async {
    final i = _items.indexWhere((e) => e.id == a.id);
    if (i >= 0) {
      _items.removeAt(i);
    } else {
      _items.insert(0, a);
    }
    notifyListeners();
    await _prefs.setString(_key, jsonEncode(_items.map((e) => e.toJson()).toList()));
  }
}
