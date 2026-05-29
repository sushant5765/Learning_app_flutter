class ProgressInsights {
  ProgressInsights({
    required this.headline,
    required this.strengths,
    required this.focusAreas,
    required this.recommendations,
    required this.celebrations,
    required this.readingMomentum,
    required this.writingMomentum,
    required this.vocabularyMomentum,
  });

  final String headline;
  final List<String> strengths;
  final List<String> focusAreas;
  final List<String> recommendations;
  final List<String> celebrations;
  final double readingMomentum;
  final double writingMomentum;
  final double vocabularyMomentum;
}

class ProgressAiInsights {
  static const _minSessionsForTrend = 4;

  static ProgressInsights analyze({
    required List<Map<String, dynamic>> readingSessions,
    required List<Map<String, dynamic>> writingSessions,
    required List<Map<String, dynamic>> vocabularySessions,
  }) {
    final readingAccuracies =
        _extractDoubles(readingSessions, 'accuracy', maxLength: 12);
    final readingWpm = _extractDoubles(readingSessions, 'wpm', maxLength: 12);
    final writingSpellingErrors =
        _extractDoubles(writingSessions, 'spellingErrors', maxLength: 12);
    final writingGrammarErrors =
        _extractDoubles(writingSessions, 'grammarErrors', maxLength: 12);
    final vocabWordCounts =
        _extractVocabularyWordCounts(vocabularySessions, maxLength: 12);

    final readingTrend = _momentum(readingAccuracies);
    final writingTrend = -_momentum(writingSpellingErrors);
    final vocabTrend = _momentum(vocabWordCounts);

    final strengths = <String>[];
    final focus = <String>[];
    final recommendations = <String>[];
    final celebrations = <String>[];

    final avgAccuracy = _average(readingAccuracies);
    final avgWpm = _average(readingWpm);
    final avgSpelling = _average(writingSpellingErrors);
    final avgGrammar = _average(writingGrammarErrors);
    final recentVocab = vocabWordCounts.isEmpty ? 0 : vocabWordCounts.last;

    if (avgAccuracy >= 88 && readingTrend >= 1) {
      strengths.add("Reading accuracy is impressive (${avgAccuracy.toStringAsFixed(0)}%).");
    }
    if (avgWpm >= 105) {
      strengths.add("Reading speed is strong (${avgWpm.toStringAsFixed(0)} WPM).");
    }
    if (avgSpelling <= 1.2) {
      strengths.add("Spelling mistakes are very low (${avgSpelling.toStringAsFixed(1)} per entry).");
    }
    if (recentVocab >= 12) {
      strengths.add("Great vocabulary session: ${recentVocab.toStringAsFixed(0)} new words.");
    }

    if (avgAccuracy < 80 || readingTrend < -1) {
      focus.add("Reading accuracy dipped. Try a focused comprehension activity.");
      recommendations.add("Read a short beginner passage and re-tell the main idea.");
    }
    if (avgSpelling > 2 || avgGrammar > 2.5) {
      focus.add("Writing errors are creeping up. Review spelling/grammar highlights before submitting.");
      recommendations.add("Use the Analyze button twice: once mid-writing, once before submission.");
    }
    if (recentVocab < 8 || vocabTrend < 0) {
      focus.add("Vocabulary sessions slowed down. Schedule a quick practice round.");
      recommendations.add("Revisit mastered words and add 5 themed words (science, travel, etc.).");
    }

    if (readingTrend > 1.5) {
      celebrations.add("Reading accuracy is climbing! Keep the momentum going.");
    }
    if (writingTrend > 1.5) {
      celebrations.add("Writing clarity improved this week—excellent revision habits.");
    }
    if (vocabTrend > 1.5) {
      celebrations.add("Vocabulary growth spiked. You're building a solid word bank.");
    }

    if (strengths.isEmpty && focus.isEmpty) {
      strengths.add("Every journey starts somewhere—log your first session to unlock insights.");
    }

    final headline = _craftHeadline(
      readingTrend: readingTrend,
      writingTrend: writingTrend,
      vocabTrend: vocabTrend,
      avgAccuracy: avgAccuracy,
      avgSpelling: avgSpelling,
      strengths: strengths,
      focus: focus,
    );

    return ProgressInsights(
      headline: headline,
      strengths: strengths,
      focusAreas: focus,
      recommendations: recommendations,
      celebrations: celebrations,
      readingMomentum: readingTrend,
      writingMomentum: writingTrend,
      vocabularyMomentum: vocabTrend,
    );
  }

  static List<double> _extractDoubles(
    List<Map<String, dynamic>> sessions,
    String key, {
    required int maxLength,
  }) {
    final values = <double>[];
    for (final session in sessions) {
      final raw = session[key];
      if (raw == null) continue;
      if (raw is num) {
        values.add(raw.toDouble());
      } else if (raw is String) {
        final parsed = double.tryParse(raw);
        if (parsed != null) values.add(parsed);
      }
      if (values.length >= maxLength) break;
    }
    return values;
  }

  static List<double> _extractVocabularyWordCounts(
    List<Map<String, dynamic>> sessions, {
    required int maxLength,
  }) {
    final values = <double>[];
    for (final session in sessions) {
      final words = session['words'];
      if (words is List) {
        values.add(words.length.toDouble());
      }
      if (values.length >= maxLength) break;
    }
    return values;
  }

  static double _average(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  // calculates trend how changes  happens form 6 vs 6 comparison

  static double _momentum(List<double> values) {
    if (values.length < _minSessionsForTrend) return 0;
    final midpoint = values.length ~/ 2;
    final recent = values.sublist(midpoint);
    final earlier = values.sublist(0, midpoint);
    final recentAvg = _average(recent);
    final earlierAvg = _average(earlier);
    final delta = recentAvg - earlierAvg;
    return double.parse(delta.toStringAsFixed(2));
  }

  // gives summary message based on focus trends averages

  static String _craftHeadline({
    required double readingTrend,
    required double writingTrend,
    required double vocabTrend,
    required double avgAccuracy,
    required double avgSpelling,
    required List<String> strengths,
    required List<String> focus,
  }) {
    if (strengths.isNotEmpty && focus.isEmpty) {
      return "You're on a roll! 📈";
    }
    if (readingTrend > 2 && writingTrend > 1) {
      return "Momentum rising across reading and writing!";
    }
    if (avgAccuracy >= 90 && avgSpelling <= 1.5) {
      return "Precision power! Accuracy and clarity shine.";
    }
    if (focus.isNotEmpty) {
      return "Smart tweaks will unlock your next level.";
    }
    if (readingTrend < -2 || writingTrend < -2 || vocabTrend < -2) {
      return "Let’s steady the ship and bounce back.";
    }
    return "Your learning story is evolving nicely.";
  }
}

