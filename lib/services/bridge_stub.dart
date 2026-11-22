/// Non-web fallback: browser-only features (speech, web push) are unavailable.
class Bridge {
  static bool get ttsSupported => false;
  static bool get speaking => false;
  static void speak(String text, String lang) {}
  static void stopSpeaking() {}
  static bool get pushSupported => false;
  static Future<String> enablePush() async =>
      throw Exception('Notifications work in the web app.');
  static Future<void> disablePush() async {}
}
