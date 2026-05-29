import 'dart:math';

import 'local_nlp_service.dart';

class WritingEvaluation {
  WritingEvaluation({
    required this.isRelevant,
    required this.level,
    required this.feedback,
    required this.metrics,
  });

  final bool isRelevant;
  final String level;
  final String feedback;
  final WritingMetrics metrics;
}

class WritingMetrics {
  WritingMetrics({
    required this.wordCount,
    required this.sentenceCount,
    required this.averageSentenceLength,
    required this.typeTokenRatio,
  });

  final int wordCount;
  final int sentenceCount;
  final double averageSentenceLength;
  final double typeTokenRatio;
}

class WritingEvaluator {
  WritingEvaluator._();

  static final WritingEvaluator instance = WritingEvaluator._();
  final LocalNlpService _nlp = LocalNlpService();

  WritingEvaluation evaluate({                         // writing practice uses this
    required String prompt,
    required String response,
  }) {
    final metrics = _computeMetrics(response);
    final relevance = _isRelevant(prompt, response);
    final level = _determineLevel(metrics);
    final feedback = _buildFeedback(relevance, level, metrics);

    return WritingEvaluation(
      isRelevant: relevance,
      level: level,
      feedback: feedback,
      metrics: metrics,
    );
  }

  WritingMetrics _computeMetrics(String text) {
    final tokens = _nlp.tokenize(text);                    // used form nlp service tokenize and split sentences
    final sentences = _nlp.splitSentences(text);

    final wordCount = tokens.length;
    final sentenceCount = max(1, sentences.length);
    final averageSentenceLength = wordCount / sentenceCount;
    final uniqueWords = tokens.toSet().length;
    final double typeTokenRatio =
        wordCount == 0 ? 0.0 : uniqueWords / wordCount;

    return WritingMetrics(
      wordCount: wordCount,
      sentenceCount: sentenceCount,
      averageSentenceLength: averageSentenceLength,
      typeTokenRatio: typeTokenRatio,
    );
  }

  bool _isRelevant(String prompt, String response) {
    final promptTokens = _nlp.tokenize(prompt).toSet();
    final responseTokens = _nlp.tokenize(response).toSet();
    if (promptTokens.isEmpty || responseTokens.isEmpty) return false;

    final overlap = promptTokens.intersection(responseTokens);
    final ratio = overlap.length / promptTokens.length;
    return ratio >= 0.25;                                          // if 25% relevancy
  }


  // determine practice level
  String _determineLevel(WritingMetrics metrics) {
    if (metrics.wordCount < 40 ||
        metrics.averageSentenceLength < 8 ||
        metrics.typeTokenRatio < 0.35) {
      return 'Basic';
    }

    if (metrics.wordCount < 90 ||
        metrics.averageSentenceLength < 14 ||
        metrics.typeTokenRatio < 0.5) {
      return 'Intermediate';
    }

    return 'Advanced';
  }

  // feedback session

  String _buildFeedback(
    bool isRelevant,
    String level,
    WritingMetrics metrics,
  ) {
    final lines = <String>[];

    if (!isRelevant) {
      lines.add('Focus more on the topic mentioned in the prompt.');
    } else {
      lines.add('Great job staying on topic!');
    }

    switch (level) {
      case 'Basic':
        lines.add(
            'Try adding a few more sentences and descriptive words to grow your ideas.');
        break;
      case 'Intermediate':
        lines.add(
            'Nice structure. Add stronger transitions to connect your sentences.');
        break;
      case 'Advanced':
        lines.add(
            'Excellent depth! Keep refining word choice for even clearer writing.');
        break;
    }

    if (metrics.typeTokenRatio < 0.4) {
      lines.add('Use a wider range of words to keep your writing engaging.');
    }

    if (metrics.averageSentenceLength > 20) {
      lines.add('Shorten some sentences to help the reader follow your ideas.');
    }

    if (metrics.wordCount < 60) {
      lines.add('Aim for at least 60 words to explore the topic in more detail.');
    }

    return lines.map((line) => '• $line').join('\n');
  }
}

