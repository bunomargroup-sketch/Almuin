import 'package:flutter_tts/flutter_tts.dart';

import '../utils/logger.dart';

/// Read-aloud for adhkar ("استمع" action and the dhikr page).
///
/// Arabic voice is preferred; the user can later switch voice in settings.
/// TTS runs only in the foreground (platform limitation), which is why the
/// notification's اللاستماع action deep-links into the app with `?read=1`.
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool enabled = true;

  Future<void> init() async {
    if (_ready) return;
    try {
      await _tts.setLanguage('ar');
      await _tts.setSpeechRate(0.42); // slow, tilawah-friendly pace
      await _tts.setPitch(1.0);
      _ready = true;
    } catch (e, st) {
      logWarn('TTS unavailable', e, st);
    }
  }

  Future<void> speakArabic(String text) async {
    if (!enabled) return;
    await init();
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (e, st) {
      logWarn('TTS speak failed', e, st);
    }
  }

  Future<void> stop() async {
    if (_ready) await _tts.stop();
  }
}
