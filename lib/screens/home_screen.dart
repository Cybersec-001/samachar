import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/news_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/article_list_view.dart';
import 'bookmarks_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final news = context.watch<NewsProvider>();
    final hindi = news.language == NewsLanguage.hindi;

    return DefaultTabController(
      length: categories.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(hindi ? 'समाचार' : 'Samachar',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SearchScreen())),
            ),
            PopupMenuButton<NewsLanguage>(
              icon: const Icon(Icons.translate),
              tooltip: 'Language',
              initialValue: news.language,
              onSelected: news.setLanguage,
              itemBuilder: (_) => [
                for (final l in NewsLanguage.values)
                  CheckedPopupMenuItem(
                      value: l, checked: l == news.language, child: Text(l.label)),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.bookmarks_outlined),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const BookmarksScreen())),
            ),
            IconButton(
              icon: Icon(Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode),
              onPressed: () => context
                  .read<ThemeProvider>()
                  .toggle(Theme.of(context).brightness),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final c in categories) Tab(text: hindi ? c.hi : c.en)],
          ),
        ),
        body: TabBarView(
          children: [for (final c in categories) _CategoryTab(category: c)],
        ),
      ),
    );
  }
}

class _CategoryTab extends StatefulWidget {
  final NewsCategory category;
  const _CategoryTab({required this.category});

  @override
  State<_CategoryTab> createState() => _CategoryTabState();
}

class _CategoryTabState extends State<_CategoryTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final news = context.watch<NewsProvider>();
    final feed = news.feedFor(widget.category.key);

    // Lazy-load on first view (and again after a language switch).
    if (!feed.loaded && !feed.loading && feed.error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) news.load(widget.category.key);
      });
    }

    return ArticleListView(
      feed: feed,
      onRefresh: () => news.load(widget.category.key, refresh: true),
      onLoadMore: () => news.load(widget.category.key),
    );
  }
}
