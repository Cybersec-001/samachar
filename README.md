# Samachar – Hindi + English Current Affairs App (Flutter + Provider)

## Requirements
- Flutter 3.22+ (Dart 3.4+) — the UI uses APIs added in that version.

## Setup
1. Get a free API key: https://newsdata.io  (free plan: 200 requests/day, 10 articles each)
2. The `android/` platform folder is already included. Install deps:
       flutter pub get
3. Run:
       flutter run --dart-define=NEWS_API_KEY=YOUR_KEY
   If you forget the flag, the app opens a setup screen with these exact
   steps instead of a spinner or a crash.

## Features
- 10 current-affairs tabs: Top, Politics, World, Business, Education, Science, Tech, Environment, Health, Sports
- Language switch: Hindi / English / both (persisted)
- Infinite scroll, pull-to-refresh, retry on errors
- Search in both languages, bookmarks (offline-saved), share, dark mode

## Provider structure
- NewsProvider     -> per-category feeds, pagination, language, search
- BookmarkProvider -> saved articles (SharedPreferences)
- ThemeProvider    -> light/dark mode

## Security note: the API key ships inside the app binary
`--dart-define` compiles NEWS_API_KEY into the app as a constant. Anyone who
gets your built APK can extract it (apktool/strings) and burn your daily
quota. Fine for a college demo; do NOT distribute the APK publicly, and
rotate the key on newsdata.io if you ever do. For a production app, put the
key behind a small backend proxy and have the app call your server instead.

## Note: image URLs are upgraded to https
Some publishers serve article images over plain http://, which Android 9+
blocks as cleartext traffic. The app rewrites those URLs to https:// at the
model layer (most CDNs serve the same asset over both); if a host truly has
no https, the thumbnail falls back to the placeholder icon instead of a
broken image.
