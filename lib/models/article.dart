class Article {
  final String id;
  final String title;
  final String? description;
  final String link;
  final String? imageUrl;
  final String source;
  final String? language;
  final DateTime? pubDate;
  final String? category;

  const Article({
    required this.id,
    required this.title,
    required this.link,
    required this.source,
    this.description,
    this.imageUrl,
    this.language,
    this.pubDate,
    this.category,
  });


  /// NewsData sometimes serves image URLs over plain http://, which Android
  /// blocks as cleartext traffic. Most CDNs host the same asset over https,
  /// so upgrade the scheme; if the host really has no https, the widgets
  /// fall back to their error placeholder instead of a broken image.
  static String? _sanitizeImageUrl(Object? raw) {
    if (raw is! String) return null;
    var url = raw.trim();
    if (url.isEmpty) return null;
    if (url.startsWith('http://')) url = 'https://${url.substring(7)}';
    if (!url.startsWith('https://')) return null; // not a loadable web image
    return url;
  }

  static String? _firstCategory(Object? raw) {
    if (raw is List && raw.isNotEmpty && raw.first is String) {
      return raw.first as String;
    }
    if (raw is String && raw.isNotEmpty) return raw;
    return null;
  }

  factory Article.fromJson(Map<String, dynamic> j) {
    DateTime? date;
    final raw = j['pubDate'] as String?;
    if (raw != null) {
      // NewsData returns UTC like "2026-11-15 08:30:00"
      date = DateTime.tryParse('${raw.replaceFirst(' ', 'T')}Z')?.toLocal();
    }
    final link = (j['link'] ?? '') as String;
    return Article(
      id: (j['article_id'] ?? link) as String,
      title: ((j['title'] ?? '') as String).trim(),
      description: (j['description'] as String?)?.trim(),
      link: link,
      imageUrl: _sanitizeImageUrl(j['image_url']),
      source: (j['source_name'] ?? j['source_id'] ?? 'Unknown') as String,
      language: j['language'] as String?,
      pubDate: date,
      category: _firstCategory(j['category']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'link': link,
        'imageUrl': imageUrl,
        'source': source,
        'language': language,
        'pubDate': pubDate?.toIso8601String(),
        'category': category,
      };

  factory Article.fromSaved(Map<String, dynamic> j) => Article(
        id: j['id'],
        title: j['title'],
        description: j['description'],
        link: j['link'],
        imageUrl: _sanitizeImageUrl(j['imageUrl']),
        source: j['source'],
        language: j['language'],
        pubDate: j['pubDate'] == null ? null : DateTime.tryParse(j['pubDate']),
        category: j['category'] as String?,
      );

  String get timeAgo {
    if (pubDate == null) return '';
    final d = DateTime.now().difference(pubDate!);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}
