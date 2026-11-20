import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'providers/bookmark_provider.dart';
import 'providers/news_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NewsProvider(prefs)),
        ChangeNotifierProvider(create: (_) => BookmarkProvider(prefs)),
        ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
      ],
      child: const SamacharApp(),
    ),
  );
}

class SamacharApp extends StatelessWidget {
  const SamacharApp({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<ThemeProvider>().mode;
    const seed = Color(0xFF1E3A8A);
    return MaterialApp(
      title: 'Samachar',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: seed),
      darkTheme: ThemeData(
          useMaterial3: true, colorSchemeSeed: seed, brightness: Brightness.dark),
      home: (AppConfig.hasApiKey || AppConfig.hasApiBase)
          ? const HomeScreen()
          : const ApiKeySetupScreen(),
    );
  }
}

/// Shown when the app was launched without
/// `--dart-define=NEWS_API_KEY=...`. Without this the app would open to a
/// spinner or an unexplained failure on every tab; instead it says exactly
/// what is missing and how to supply it.
class ApiKeySetupScreen extends StatelessWidget {
  const ApiKeySetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.key_off,
                  size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('News API key missing',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              const Text(
                'This app needs a free NewsData.io API key to load news.\n\n'
                '1. Get a key at https://newsdata.io\n'
                '2. Run the app with it:\n\n'
                'flutter run --dart-define=NEWS_API_KEY=YOUR_KEY',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
