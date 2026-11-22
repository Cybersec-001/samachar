import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/article.dart';

/// Reading history kept on the device. Powers the "For You" feed: categories
/// and sources the reader opens most get ranked higher.
class HistoryProvider extends ChangeNotifier {
  static const _key = 'history_v1';
  final SharedPreferences _prefs;
  final Map<String, double> _cats = {};
  final Map<String, double> _sources = {};
  final List<String> _read = [];

  HistoryProvider(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw == null) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      (m['cats'] as Map? ?? {}).forEach((k, v) => _cats['$k'] = (v as num).toDouble());
      (m['sources'] as Map? ?? {})
          .forEach((k, v) => _sources['$k'] = (v as num).toDouble());
      _read.addAll(((m['read'] as List?) ?? []).map((e) => '$e'));
    } catch (_) {}
  }

  int get readCount => _read.length;
  bool get hasHistory => _cats.isNotEmpty || _sources.isNotEmpty;
  bool isRead(Article a) => _read.contains(a.id);

  /// Category keys, most-read first.
  List<String> get topCategories {
    final e = _cats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return e.map((x) => x.key).toList();
  }

  Future<void> record(Article a) async {
    if (a.category != null) {
      _cats[a.category!] = (_cats[a.category!] ?? 0) + 1;
    }
    _sources[a.source] = (_sources[a.source] ?? 0) + 1;
    _read.remove(a.id);
    _read.insert(0, a.id);
    if (_read.length > 300) _read.removeRange(300, _read.length);
    notifyListeners();
    await _save();
  }

  Future<void> clear() async {
    _cats.clear();
    _sources.clear();
    _read.clear();
    notifyListeners();
    await _save();
  }

  Future<void> _save() => _prefs.setString(
      _key, jsonEncode({'cats': _cats, 'sources': _sources, 'read': _read}));

  double _score(Article a) {
    final catTotal = _cats.values.fold(0.0, (x, y) => x + y);
    final srcTotal = _sources.values.fold(0.0, (x, y) => x + y);
    final c = a.category == null || catTotal == 0
        ? 0.0
        : (_cats[a.category!] ?? 0) / catTotal;
    final s = srcTotal == 0 ? 0.0 : (_sources[a.source] ?? 0) / srcTotal;
    var fresh = 0.0;
    if (a.pubDate != null) {
      final hours = DateTime.now().difference(a.pubDate!).inMinutes / 60.0;
      fresh = exp(-max(0, hours) / 24.0);
    }
    return 3 * c + 1.5 * s + fresh;
  }

  /// Unread articles, best match first. Duplicates (same id) are removed.
  List<Article> rank(Iterable<Article> input) {
    final seen = <String>{};
    final list = input.where((a) => seen.add(a.id) && !isRead(a)).toList();
    list.sort((a, b) => _score(b).compareTo(_score(a)));
    return list;
  }
}
