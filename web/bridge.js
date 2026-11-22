// Browser helpers called from Dart (lib/services/bridge_web.dart).
(function () {
  var synth = window.speechSynthesis;
  var bridge = {
    ttsSupported: !!synth && typeof SpeechSynthesisUtterance !== 'undefined',
    pushSupported: false,
    speak: function (text, lang) {
      if (!bridge.ttsSupported) return;
      synth.cancel();
      var u = new SpeechSynthesisUtterance(text);
      u.lang = lang || 'en-IN';
      var voices = synth.getVoices();
      var pref = voices.filter(function (v) { return v.lang && v.lang.replace('_', '-').toLowerCase().indexOf((lang || 'en').slice(0, 2).toLowerCase()) === 0; });
      if (pref.length) u.voice = pref[0];
      synth.speak(u);
    },
    stopSpeak: function () { if (bridge.ttsSupported) synth.cancel(); },
    isSpeaking: function () { return bridge.ttsSupported && (synth.speaking || synth.pending); },
    enablePush: function () { return Promise.reject(new Error('Notifications are not set up yet.')); },
    disablePush: function () { return Promise.resolve(); }
  };
  window.samacharBridge = bridge;
})();
