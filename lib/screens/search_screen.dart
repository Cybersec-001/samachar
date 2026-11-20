import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/news_provider.dart';
import '../widgets/article_list_view.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final news = context.watch<NewsProvider>();
    final feed = news.feedFor(NewsProvider.searchKey);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
              hintText: 'Search news / समाचार खोजें', border: InputBorder.none),
          onSubmitted: news.search,
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () => news.search(_ctrl.text)),
        ],
      ),
      body: news.query.isEmpty
          ? const Center(child: Text('Search current affairs in Hindi or English'))
          : ArticleListView(
              feed: feed,
              onRefresh: () => news.load(NewsProvider.searchKey, refresh: true),
              onLoadMore: () => news.load(NewsProvider.searchKey),
            ),
    );
  }
}
