import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/article.dart';
import '../services/news_service.dart';

enum NewsLanguage {
  both('hi,en', 'हिंदी + English'),
  english('en', 'English'),
  hindi('hi', 'हिंदी');

  final String apiValue;
  final String label;
  const NewsLanguage(this.apiValue, this.label);
}

class NewsCategory {
  final String key, en, hi;
  const NewsCategory(this.key, this.en, this.hi);
}

const categories = [
  NewsCategory('top', 'Top', 'मुख्य'),
  NewsCategory('politics', 'Politics', 'राजनीति'),
  NewsCategory('world', 'World', 'विश्व'),
  NewsCategory('business', 'Business', 'व्यापार'),
  NewsCategory('education', 'Education', 'शिक्षा'),
  NewsCategory('science', 'Science', 'विज्ञान'),
  NewsCategory('technology', 'Tech', 'तकनीक'),
  NewsCategory('environment', 'Environment', 'पर्यावरण'),
  NewsCategory('health', 'Health', 'स्वास्थ्य'),
  NewsCategory('sports', 'Sports', 'खेल'),
];

class Feed {
  final List<Article> articles = [];
  String? nextPage;
  bool loading = false;
  bool loaded = false;
  String? error;

  /// Bumped when a refresh supersedes an in-flight request, so the older
  /// request's result is discarded instead of overwriting fresh data.
  int requestId = 0;
}

class NewsProvider extends ChangeNotifier {
  static const searchKey = '_search';

  final SharedPreferences _prefs;
  final NewsService _service = NewsService();
  Map<String, Feed> _feeds = {};
  NewsLanguage _language;
  String _query = '';
  int _epoch = 0; // invalidates in-flight requests when language/query changes

  NewsProvider(this._prefs)
      : _language = NewsLanguage.values.firstWhere(
          (l) => l.name == _prefs.getString('lang'),
          orElse: () => NewsLanguage.both,
        );

  NewsLanguage get language => _language;
  String get query => _query;

  Feed feedFor(String key) => _feeds.putIfAbsent(key, () => Feed());

  Future<void> setLanguage(NewsLanguage lang) async {
    if (lang == _language) return;
    _language = lang;
    _epoch++;
    _feeds = {};
    await _prefs.setString('lang', lang.name);
    notifyListeners();
    // Keep the search screen alive across a language switch: without this the
    // search feed is gone and nothing reloads it, leaving a spinner forever.
    if (_query.isNotEmpty) await load(searchKey);
  }

  Future<void> search(String q) async {
    final query = q.trim();
    if (query.isNotEmpty && query == _query) {
      // Same query submitted again: reuse the results we already have
      // instead of spending another request from the daily free quota.
      final existing = _feeds[searchKey];
      if (existing != null && existing.loaded) return;
    }
    _query = query;
    _epoch++;
    _feeds.remove(searchKey);
    notifyListeners();
    if (_query.isNotEmpty) await load(searchKey);
  }

  /// Loads the first page, or the next page if already loaded.
  Future<void> load(String key, {bool refresh = false}) async {
    final feed = feedFor(key);
    if (feed.loading && !refresh) return;
    final isFirst = refresh || !feed.loaded;
    if (!isFirst && feed.nextPage == null) return;

    // A refresh supersedes any in-flight request for this feed, so
    // pull-to-refresh is honoured even while a page load is running.
    if (refresh) feed.requestId++;
    final requestId = feed.requestId;

    feed.loading = true;
    feed.error = null;
    notifyListeners();

    final epoch = _epoch;
    bool stale() => epoch != _epoch || requestId != feed.requestId;
    try {
      final page = await _service.fetch(
        language: _language.apiValue,
        category: key == searchKey ? null : key,
        query: key == searchKey ? _query : null,
        page: isFirst ? null : feed.nextPage,
      );
      if (stale()) return;
      if (isFirst) feed.articles.clear();
      final seen = feed.articles.map((a) => a.id).toSet();
      feed.articles.addAll(page.articles.where((a) => seen.add(a.id)));
      feed.nextPage = page.nextPage;
      feed.loaded = true;
    } catch (e) {
      if (stale()) return;
      feed.error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (!stale()) {
        feed.loading = false;
        notifyListeners();
      }
    }
  }
}
