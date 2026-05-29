import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final FlutterTts _tts = FlutterTts();

  static Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.45);
    await _tts.speak(text);
  }

  static Future<void> stop() => _tts.stop();
}
