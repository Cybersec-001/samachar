#!/bin/sh
# Vercel build for the Samachar Flutter web app.
# Vercel has no Flutter image, so install the SDK, scaffold the web runner,
# apply demo-page polish, then build into build/web (the project Output
# Directory). The NewsData.io key is NOT here: the app calls the same-origin
# /api/news proxy (api/news.js), which holds the key server-side.
set -e

curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.50.1-stable.tar.xz -o sdk.tar.xz
tar -xJf sdk.tar.xz
git config --global --add safe.directory "$PWD/flutter"

./flutter/bin/flutter create . --platforms web --project-name samachar

sed -i 's|<title>samachar</title>|<title>Samachar - Hindi + English News</title>|; s|A new Flutter project.|Samachar: bilingual Hindi + English current affairs news from across India.|' web/index.html
sed -i 's|"name": "samachar"|"name": "Samachar - Hindi + English News"|; s|"short_name": "samachar"|"short_name": "Samachar"|; s|#0175C2|#1E3A8A|g; s|A new Flutter project.|Samachar - bilingual Hindi + English news.|' web/manifest.json

./flutter/bin/flutter pub get
./flutter/bin/flutter build web --release --no-wasm-dry-run --dart-define=API_BASE=SAME
