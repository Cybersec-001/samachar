import 'package:flutter/material.dart';
import '../providers/news_provider.dart';
import 'article_card.dart';

class ArticleListView extends StatefulWidget {
  final Feed feed;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  const ArticleListView({
    super.key,
    required this.feed,
    required this.onRefresh,
    required this.onLoadMore,
  });

  @override
  State<ArticleListView> createState() => _ArticleListViewState();
}

class _ArticleListViewState extends State<ArticleListView> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final f = widget.feed;
      if (_controller.hasClients &&
          _controller.position.extentAfter < 500 &&
          !f.loading &&
          f.error == null &&
          f.nextPage != null) {
        widget.onLoadMore();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.feed;

    if (f.articles.isEmpty) {
      if (f.error != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_off, size: 48),
              const SizedBox(height: 12),
              Text(f.error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                  onPressed: widget.onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry')),
            ]),
          ),
        );
      }
      if (f.loaded) {
        return const Center(child: Text('No articles found.'));
      }
      return const Center(child: CircularProgressIndicator());
    }

    final showFooter = f.loading || f.error != null;
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        controller: _controller,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: f.articles.length + (showFooter ? 1 : 0),
        itemBuilder: (_, i) {
          if (i < f.articles.length) return ArticleCard(article: f.articles[i]);
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: f.error != null
                  ? TextButton(
                      onPressed: widget.onLoadMore, child: Text('${f.error} — tap to retry'))
                  : const CircularProgressIndicator(),
            ),
          );
        },
      ),
    );
  }
}
