import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samachar/main.dart';
import 'package:samachar/models/article.dart';

void main() {
  testWidgets('API key setup screen explains how to supply the key',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ApiKeySetupScreen()));
    expect(find.text('News API key missing'), findsOneWidget);
    expect(find.textContaining('--dart-define=NEWS_API_KEY='), findsOneWidget);
  });

  test('http image URLs are upgraded to https', () {
    final a = Article.fromJson(const {
      'article_id': 'x',
      'title': 't',
      'link': 'https://example.com/a',
      'image_url': 'http://cdn.example.com/img.jpg',
      'source_name': 'Example',
    });
    expect(a.imageUrl, 'https://cdn.example.com/img.jpg');
  });

  test('non-web image URLs are dropped', () {
    final a = Article.fromJson(const {
      'article_id': 'x',
      'title': 't',
      'link': 'https://example.com/a',
      'image_url': 'ftp://example.com/img.jpg',
    });
    expect(a.imageUrl, isNull);
  });
}
