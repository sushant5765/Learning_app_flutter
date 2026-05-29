import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();

  Future<bool> init() async {
    return await _speech.initialize();
  }

  void listen(void Function(String recognized) onResult) {
    _speech.listen(onResult: (result) {
      onResult(result.recognizedWords);
    }, listenFor: Duration(seconds: 10));
  }

  void stop() {
    _speech.stop();
  }
}
