import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/history_provider.dart';
import '../providers/news_provider.dart';
import '../widgets/article_card.dart';
import '../providers/theme_provider.dart';
import '../widgets/article_list_view.dart';
import 'account_screen.dart';
import 'bookmarks_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final news = context.watch<NewsProvider>();
    final hindi = news.language == NewsLanguage.hindi;

    return DefaultTabController(
      length: categories.length + 1,
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
              tooltip: 'Account',
              icon: Icon(context.watch<AuthProvider>().signedIn
                  ? Icons.account_circle
                  : Icons.account_circle_outlined),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AccountScreen())),
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
            tabs: [
              Tab(text: hindi ? 'आपके लिए' : 'For You'),
              for (final c in categories) Tab(text: hindi ? c.hi : c.en),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const _ForYouTab(),
            for (final c in categories) _CategoryTab(category: c),
          ],
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

/// Personalised feed: merges the feeds the reader cares about (from local
/// reading history) and ranks unread articles by category/source affinity.
class _ForYouTab extends StatefulWidget {
  const _ForYouTab();

  @override
  State<_ForYouTab> createState() => _ForYouTabState();
}

class _ForYouTabState extends State<_ForYouTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<String> _keys(HistoryProvider h) {
    final fav = h.topCategories
        .where((k) => categories.any((c) => c.key == k))
        .take(2)
        .toList();
    final defaults = ['politics', 'technology'];
    final keys = <String>['top', ...fav];
    for (final d in defaults) {
      if (keys.length >= 3) break;
      if (!keys.contains(d)) keys.add(d);
    }
    return keys;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final news = context.watch<NewsProvider>();
    final history = context.watch<HistoryProvider>();
    final keys = _keys(history);

    final feeds = [for (final k in keys) news.feedFor(k)];
    for (var i = 0; i < keys.length; i++) {
      final f = feeds[i];
      if (!f.loaded && !f.loading && f.error == null) {
        final key = keys[i];
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) news.load(key);
        });
      }
    }

    final merged = history.rank(feeds.expand((f) => f.articles));
    final loading = feeds.any((f) => f.loading) && merged.isEmpty;
    final failed = merged.isEmpty && feeds.every((f) => f.error != null);

    if (loading) return const Center(child: CircularProgressIndicator());
    if (failed) {
      return Center(
        child: FilledButton.icon(
          onPressed: () {
            for (final k in keys) {
              news.load(k, refresh: true);
            }
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([for (final k in keys) news.load(k, refresh: true)]);
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: merged.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(children: [
                const Icon(Icons.auto_awesome, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    history.hasHistory
                        ? 'Picked for you from what you read'
                        : 'Read a few stories and this feed learns your taste',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ]),
            );
          }
          return ArticleCard(article: merged[i - 1]);
        },
      ),
    );
  }
}
