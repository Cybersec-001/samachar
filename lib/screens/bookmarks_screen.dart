import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bookmark_provider.dart';
import '../widgets/article_card.dart';

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = context.watch<BookmarkProvider>().items;
    return Scaffold(
      appBar: AppBar(title: const Text('Saved / सहेजे गए')),
      body: items.isEmpty
          ? const Center(child: Text('No saved articles yet.'))
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) => ArticleCard(article: items[i]),
            ),
    );
  }
}
