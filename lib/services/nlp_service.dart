import 'dart:math';

class NlpService {
  static final Map<String, String> _simpleMap = {
    "utilize": "use",
    "comprehend": "understand",
    "demonstrate": "show",
    "approximately": "about",
    "difficult": "hard",
    "assistance": "help",
    "individual": "person",
    "significant": "important",
    "reduce": "lower",
    "increase": "raise",
  };

  static Future<String> simplifyText(String text) async {
    if (text.trim().isEmpty) return text;
    final sentences = _splitIntoSentences(text);
    final simplifiedSentences = <String>[];
    for (var s in sentences) {
      var s2 = _replaceComplexWords(s);
      s2 = _shortenLongSentence(s2);
      simplifiedSentences.add(s2.trim());
    }
    return simplifiedSentences.join(' ');
  }

  static List<String> extractKeyPoints(String text, {int maxPoints = 5}) {
    if (text.trim().isEmpty) return [];
    final sentences = _splitIntoSentences(text);
    final scored = <MapEntry<String,double>>[];
    for (int i=0;i<sentences.length;i++){
      final s = sentences[i];
      final lenScore = s.split(' ').length.toDouble();
      final posScore = 1.0 / (1 + i);
      final score = lenScore * 0.6 + posScore * 0.4;
      scored.add(MapEntry(s, score));
    }
    scored.sort((a,b) => b.value.compareTo(a.value));
    return scored.take(min(maxPoints, scored.length)).map((e)=>e.key.trim()).toList();
  }

  static String _replaceComplexWords(String s) {
    var words = s.split(RegExp(r'(\s+)'));
    for (int i=0;i<words.length;i++){
      final w = words[i];
      final key = w.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
      if (_simpleMap.containsKey(key)) {
        var replacement = _simpleMap[key]!;
        words[i] = words[i].replaceAll(RegExp('(?i)$key'), replacement);
      }
    }
    return words.join();
  }

  static String _shortenLongSentence(String s, {int maxWords=20}) {
    final words = s.split(RegExp(r'\s+'));
    if (words.length <= maxWords) return s;
    List<String> parts = [];
    for (int i=0;i<words.length;i+=maxWords) {
      parts.add(words.sublist(i, min(i+maxWords, words.length)).join(' '));
    }
    return parts.join('. ');
  }

  static List<String> _splitIntoSentences(String text) {
    return text.split(RegExp(r'(?<=[.!?])\s+')).map((s)=>s.trim()).where((s)=>s.isNotEmpty).toList();
  }
}
