class AppConfig {
  /// Get a free key at https://newsdata.io (200 credits/day on the free plan).
  /// Run with:  flutter run --dart-define=NEWS_API_KEY=your_key
  ///
  /// If the flag is missing the key is empty, and the app fails fast with a
  /// clear "API key missing" error instead of making a doomed request that
  /// comes back as a confusing 401.
  static const apiKey = String.fromEnvironment('NEWS_API_KEY');

  /// Optional base URL of a server-side proxy that holds the NewsData.io key
  /// (the web build cannot call newsdata.io directly: the API blocks CORS).
  /// Pass --dart-define=API_BASE=https://your-proxy.example.com and the app
  /// calls <API_BASE>/api/news without ever seeing the key.
  /// The special value SAME (i.e. --dart-define=API_BASE=SAME) calls the
  /// relative path /api/news on the origin serving the app.
  static const apiBase = String.fromEnvironment('API_BASE');

  /// Supabase (login + synced bookmarks). The project URL and the publishable
  /// key are public by design: access is enforced by row-level security.
  static const supabaseUrl = 'https://ybbrrftwgxrxskilcwzv.supabase.co';
  static const supabaseKey = 'sb_publishable_ovtIhLMISLXLZDRvya7-Kw_V-oJy2MT';

  static bool get hasApiKey => apiKey.isNotEmpty;
  static bool get hasApiBase => apiBase.isNotEmpty;
}
