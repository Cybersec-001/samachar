class AppConfig {
  /// Get a free key at https://newsdata.io (200 credits/day on the free plan).
  /// Run with:  flutter run --dart-define=NEWS_API_KEY=your_key
  ///
  /// If the flag is missing the key is empty, and the app fails fast with a
  /// clear "API key missing" error instead of making a doomed request that
  /// comes back as a confusing 401.
  static const apiKey = String.fromEnvironment('NEWS_API_KEY');

  static bool get hasApiKey => apiKey.isNotEmpty;
}
