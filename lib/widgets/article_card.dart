import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/article.dart';
import '../providers/bookmark_provider.dart';
import '../screens/detail_screen.dart';

class ArticleCard extends StatelessWidget {
  final Article article;
  const ArticleCard({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saved = context.select<BookmarkProvider, bool>((b) => b.isSaved(article));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DetailScreen(article: article)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(article.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600, height: 1.3)),
                    if (article.description != null &&
                        article.description!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(article.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall),
                    ],
                    const SizedBox(height: 8),
                    Row(children: [
                      Flexible(
                        child: Text(article.source,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Text(article.timeAgo, style: theme.textTheme.labelSmall),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(children: [
                if (article.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: article.imageUrl!,
                      width: 96,
                      height: 80,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const SizedBox(
                          width: 96, height: 80, child: Icon(Icons.image_not_supported)),
                      placeholder: (_, __) => Container(
                          width: 96,
                          height: 80,
                          color: theme.colorScheme.surfaceContainerHighest),
                    ),
                  ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
                  onPressed: () => context.read<BookmarkProvider>().toggle(article),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
