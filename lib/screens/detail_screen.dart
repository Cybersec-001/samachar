import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/article.dart';
import '../providers/bookmark_provider.dart';

class DetailScreen extends StatelessWidget {
  final Article article;
  const DetailScreen({super.key, required this.article});

  Future<void> _openArticle(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(article.link);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      messenger.showSnackBar(
          const SnackBar(content: Text('This link cannot be opened.')));
      return;
    }
    try {
      final opened =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Could not open the link.')));
      }
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not open the link.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saved = context.select<BookmarkProvider, bool>((b) => b.isSaved(article));

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
            onPressed: () => context.read<BookmarkProvider>().toggle(article),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => Share.share('${article.title}\n${article.link}'),
          ),
        ],
      ),
      body: ListView(
        children: [
          if (article.imageUrl != null)
            CachedNetworkImage(
              imageUrl: article.imageUrl!,
              height: 220,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(article.title,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold, height: 1.3)),
                const SizedBox(height: 10),
                Text('${article.source}  •  ${article.timeAgo}',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: theme.colorScheme.primary)),
                const SizedBox(height: 16),
                Text(article.description ?? 'Tap below to read the full story.',
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.6)),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Read full article'),
                  onPressed: () => _openArticle(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
