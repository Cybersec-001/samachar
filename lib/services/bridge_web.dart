import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Thin wrapper over window.samacharBridge (web/bridge.js): browser speech
/// synthesis and Firebase Cloud Messaging web push.
class Bridge {
  static JSObject? get _b {
    final o = globalContext['samacharBridge'];
    return o.isA<JSObject>() ? o as JSObject : null;
  }

  static bool _bool(String name) {
    final b = _b;
    if (b == null) return false;
    final v = b[name];
    return v.isA<JSBoolean>() ? (v as JSBoolean).toDart : false;
  }

  static bool get ttsSupported => _bool('ttsSupported');
  static bool get speaking {
    final b = _b;
    if (b == null) return false;
    final v = b.callMethod('isSpeaking'.toJS);
    return v.isA<JSBoolean>() ? (v as JSBoolean).toDart : false;
  }

  static void speak(String text, String lang) {
    _b?.callMethod('speak'.toJS, text.toJS, lang.toJS);
  }

  static void stopSpeaking() {
    _b?.callMethod('stopSpeak'.toJS);
  }

  static bool get pushSupported => _bool('pushSupported');

  /// Asks permission, registers with FCM and returns the device token.
  static Future<String> enablePush() async {
    final b = _b;
    if (b == null) throw Exception('Notifications are not available here.');
    try {
      final r = await (b.callMethod('enablePush'.toJS) as JSPromise).toDart;
      if (r.isA<JSString>()) return (r as JSString).toDart;
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
    throw Exception('Could not enable notifications.');
  }

  static Future<void> disablePush() async {
    final b = _b;
    if (b == null) return;
    try {
      await (b.callMethod('disablePush'.toJS) as JSPromise).toDart;
    } catch (_) {}
  }
}
