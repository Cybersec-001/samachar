import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/article.dart';

class NewsPage {
  final List<Article> articles;
  final String? nextPage;
  const NewsPage(this.articles, this.nextPage);
}

class NewsService {
  static const _host = 'newsdata.io';

  Future<NewsPage> fetch({
    required String language, // "en", "hi" or "hi,en"
    String? category,
    String? query,
    String? page,
  }) async {
    if (!AppConfig.hasApiKey) {
      throw Exception(
          'API key missing. Run with: flutter run --dart-define=NEWS_API_KEY=your_key');
    }

    final params = <String, String>{
      'apikey': AppConfig.apiKey,
      'country': 'in',
      'language': language,
      if (category != null) 'category': category,
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (page != null) 'page': page,
    };
    final uri = Uri.https(_host, '/api/1/latest', params);

    http.Response res;
    try {
      res = await http.get(uri).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw Exception('Request timed out. Check your connection.');
    } catch (_) {
      throw Exception('No internet connection.');
    }

    if (res.statusCode == 401) throw Exception('Invalid API key.');
    if (res.statusCode == 429) {
      throw Exception('Daily free limit reached. Try again tomorrow.');
    }
    if (res.statusCode != 200) {
      throw Exception(
          'Server error (${res.statusCode}). Please try again later.');
    }

    // Some error pages (proxies, Cloudflare, 5xx) return non-JSON bodies;
    // surface a clean message instead of a raw FormatException.
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Unexpected response from the server. Try again.');
    }

    if (body['status'] != 'success') {
      String? msg;
      final results = body['results'];
      if (results is Map && results['message'] != null) {
        msg = results['message'].toString();
      }
      throw Exception(
          msg == null || msg.isEmpty ? 'Something went wrong.' : msg);
    }

    final list = (body['results'] as List? ?? [])
        .map((e) => Article.fromJson(e as Map<String, dynamic>))
        .where((a) => a.title.isNotEmpty && a.link.isNotEmpty)
        .toList();
    return NewsPage(list, body['nextPage'] as String?);
  }
}
