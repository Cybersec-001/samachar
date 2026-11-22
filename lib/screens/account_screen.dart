import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/bookmark_provider.dart';
import '../providers/history_provider.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit(bool create) async {
    final email = _email.text.trim();
    if (!email.contains('@') || _pass.text.length < 6) {
      setState(() => _error = 'Enter a valid email and a password of 6+ characters.');
      return;
    }
    setState(() => _error = null);
    final err = await context
        .read<AuthProvider>()
        .signIn(email, _pass.text, create: create);
    if (!mounted) return;
    setState(() => _error = err);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final bookmarks = context.watch<BookmarkProvider>();
    final history = context.watch<HistoryProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Account / खाता')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (!auth.signedIn) ...[
            Text('Sign in to keep your saved articles on every device.',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                  labelText: 'Email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pass,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _submit(false),
              decoration: const InputDecoration(
                  labelText: 'Password', border: OutlineInputBorder()),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: FilledButton(
                  onPressed: auth.busy ? null : () => _submit(false),
                  child: auth.busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Sign in'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: auth.busy ? null : () => _submit(true),
                  child: const Text('Create account'),
                ),
              ),
            ]),
          ] else ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(auth.email ?? ''),
              subtitle: Text(bookmarks.syncing
                  ? 'Syncing saved articles...'
                  : bookmarks.syncError ??
                      '${bookmarks.items.length} saved articles synced'),
            ),
            const SizedBox(height: 8),
            Row(children: [
              OutlinedButton.icon(
                onPressed: bookmarks.syncing ? null : bookmarks.sync,
                icon: const Icon(Icons.sync),
                label: const Text('Sync now'),
              ),
              const SizedBox(width: 12),
              TextButton(onPressed: auth.signOut, child: const Text('Sign out')),
            ]),
          ],
          const Divider(height: 40),
          Text('Reading history', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
              '${history.readCount} articles read on this device. It only shapes your For You feed and is never uploaded.'),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: history.readCount == 0 ? null : history.clear,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear history'),
            ),
          ),
        ],
      ),
    );
  }
}
