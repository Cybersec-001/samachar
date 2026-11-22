import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/article.dart';
import '../providers/bookmark_provider.dart';
import '../providers/history_provider.dart';
import '../services/bridge.dart';

class DetailScreen extends StatefulWidget {
  final Article article;
  const DetailScreen({super.key, required this.article});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  Article get article => widget.article;
  bool _speaking = false;
  bool _sumLoading = false;
  String? _summary;
  String? _sumError;

  Future<void> _summarize() async {
    setState(() {
      _sumLoading = true;
      _sumError = null;
    });
    try {
      final hindi = RegExp(r'[\u0900-\u097F]').hasMatch(article.title);
      final r = await http
          .post(Uri(path: '/api/summarize'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'title': article.title,
                'description': article.description,
                'link': article.link,
                'lang': hindi ? 'hi' : 'en',
              }))
          .timeout(const Duration(seconds: 30));
      final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      if (r.statusCode == 200 && j['summary'] is String) {
        _summary = j['summary'] as String;
      } else {
        _sumError = (j['error'] ?? 'Summary unavailable.').toString();
      }
    } catch (_) {
      _sumError = 'Could not reach the summary service.';
    }
    if (mounted) setState(() => _sumLoading = false);
  }

  @override
  void initState() {
    super.initState();
    // Remember what was read: feeds the "For You" ranking.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<HistoryProvider>().record(article);
    });
  }

  @override
  void dispose() {
    Bridge.stopSpeaking();
    super.dispose();
  }

  void _toggleSpeak() {
    if (_speaking) {
      Bridge.stopSpeaking();
      setState(() => _speaking = false);
      return;
    }
    final text = [article.title, article.description ?? '']
        .where((t) => t.isNotEmpty)
        .join('. ');
    final hindi = RegExp(r'[\u0900-\u097F]').hasMatch(text);
    Bridge.speak(text, hindi ? 'hi-IN' : 'en-IN');
    setState(() => _speaking = true);
    // The browser has no reliable end callback across engines: poll briefly.
    Future.doWhile(() async {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return false;
      if (!Bridge.speaking) {
        setState(() => _speaking = false);
        return false;
      }
      return true;
    });
  }

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
          if (Bridge.ttsSupported)
            IconButton(
              tooltip: _speaking ? 'Stop' : 'Listen',
              icon: Icon(_speaking ? Icons.stop_circle : Icons.headphones),
              onPressed: _toggleSpeak,
            ),
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
                const SizedBox(height: 16),
                if (_summary != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.auto_awesome, size: 18),
                          const SizedBox(width: 6),
                          Text('AI summary',
                              style: theme.textTheme.labelLarge
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                        ]),
                        const SizedBox(height: 8),
                        Text(_summary!,
                            style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
                      ],
                    ),
                  )
                else ...[
                  OutlinedButton.icon(
                    icon: _sumLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome),
                    label: Text(_sumLoading ? 'Summarising...' : 'AI summary'),
                    onPressed: _sumLoading ? null : _summarize,
                  ),
                  if (_sumError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_sumError!,
                          style: TextStyle(color: theme.colorScheme.error)),
                    ),
                ],
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
