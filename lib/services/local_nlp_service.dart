import 'dart:math';

/// Lightweight NLP helpers that run fully on-device.
class LocalNlpService {
  LocalNlpService();

  // common words ignored for summaries
  final Set<String> _stopWords = {
    'a',
    'an',
    'and',
    'are',
    'as',
    'at',
    'be',
    'but',
    'by',
    'for',
    'if',
    'in',
    'into',
    'is',
    'it',
    'of',
    'on',
    'or',
    'such',
    'that',
    'the',
    'their',
    'then',
    'there',
    'these',
    'they',
    'this',
    'to',
    'was',
    'were',
    'will',
    'with',
    'your',
    'from',
    'have',
    'has',
    'had',
    'not',
    'can',
    'just',
    'about',
    'also',
    'more',
    'other',
    'some',
    'very',
    'you',
    'we',
    'our',
    'i',
  };

  /// Splits text into rough sentences.
  List<String> splitSentences(String text) {
    final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return const [];

    final parts = cleaned.split(RegExp(r'(?<=[.!?])\s+'));
    return parts
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }

  /// Tokenises text into lower-case words.
  List<String> tokenize(String text) {
    return RegExp(r"[A-Za-z']+")
        .allMatches(text.toLowerCase())
        .map((m) => m.group(0)!)
        .where((token) => token.isNotEmpty)
        .toList();
  }

  /// Calculates a simple frequency map excluding stop-words.
  Map<String, double> _wordFrequency(String text) {
    final freq = <String, double>{};
    for (final token in tokenize(text)) {
      if (_stopWords.contains(token)) continue;
      freq[token] = (freq[token] ?? 0) + 1;
    }
    if (freq.isEmpty) return freq;
    final maxValue = freq.values.reduce(max);
    if (maxValue == 0) return freq;

    return freq.map((key, value) => MapEntry(key, value / maxValue));
  }

  /// Generates an extractive summary using a simple TextRank-like scoring.
  String summarize(
    String text, {
    int maxSentences = 3,
  }) {
    final sentences = splitSentences(text);                //spilt sentences
    if (sentences.length <= maxSentences) {
      return sentences.join(' ');
    }

    final globalFreq = _wordFrequency(text);             //calculate frequency
    final sentenceScores = <int, double>{};

    for (var i = 0; i < sentences.length; i++) {
      final sentence = sentences[i];
      final tokens = tokenize(sentence);
      if (tokens.isEmpty) continue;

      double score = 0;
      for (final token in tokens) {
        score += globalFreq[token] ?? 0;
      }
      sentenceScores[i] = score / tokens.length;
    }

    final sortedSentences = sentenceScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final selected = sortedSentences
        .take(maxSentences)
        .map((entry) => entry.key)
        .toList()
      ..sort();

    return selected.map((index) => sentences[index]).join(' ');
  }

  /// Returns a ranked list of keywords by term frequency.
  List<String> extractKeywords(
    String text, {
    int maxKeywords = 10,
  }) {
    final freq = _wordFrequency(text);
    if (freq.isEmpty) return const [];

    final entries = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries
        .take(maxKeywords)
        .map((entry) => entry.key)
        .toList(growable: false);
  }

  /// Returns important sentences suitable for notes/highlights.
  List<String> extractHighlights(
    String text, {
    int maxSentences = 4,
  }) {
    final sentences = splitSentences(text);
    if (sentences.isEmpty) return const [];

    final globalFreq = _wordFrequency(text);
    final ranked = <int, double>{};

    for (var i = 0; i < sentences.length; i++) {
      final sentence = sentences[i];
      final tokens = tokenize(sentence);
      if (tokens.isEmpty) continue;
      double score = 0;
      for (final token in tokens) {
        if (_stopWords.contains(token)) continue;
        score += (globalFreq[token] ?? 0);
      }
      ranked[i] = score;
    }

    final selected = ranked.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return selected
        .take(maxSentences)
        .map((entry) => sentences[entry.key])
        .toList(growable: false);
  }

  /// Attempts to answer a question using sentence similarity.
  String answerQuestion(
    String sourceText,
    String question, {
    List<String> conversationHistory = const [],
  }) {
    final sentences = splitSentences(sourceText);
    if (sentences.isEmpty) {
      return "I couldn't find relevant information yet.";
    }

    final expandedQuestion = [
      ...conversationHistory.take(3),
      question,
    ].join(' ');

    final questionTokens = tokenize(expandedQuestion)
        .where((token) => !_stopWords.contains(token))
        .toSet();
    if (questionTokens.isEmpty) {
      return "Try asking your question a different way.";
    }

    double bestScore = 0;
    String? bestSentence;

    for (final sentence in sentences) {
      final tokens = tokenize(sentence).toSet();
      if (tokens.isEmpty) continue;
      final intersection =
          tokens.where((token) => questionTokens.contains(token)).length;
      final union = tokens.length + questionTokens.length - intersection;
      if (union == 0) continue;
      final score = intersection / union;
      if (score > bestScore) {
        bestScore = score;
        bestSentence = sentence;
      }
    }

    if (bestSentence != null && bestScore >= 0.08) {
      final clause = _selectRelevantClause(bestSentence, questionTokens);
      return _formatAnswer(question, clause ?? bestSentence);
    }

    // Fallback: return top highlight sentence with helpful prefix.
    final highlight = extractHighlights(sourceText, maxSentences: 1);
    if (highlight.isNotEmpty) {
      final cleaned = _cleanSnippet(highlight.first);
      return _toSentence(
          "Here's something useful: ${_lowercaseFirst(cleaned)}");
    }

    return "I'm not sure about that yet. Try rephrasing or look back at the text.";
  }

  /// Finds vocabulary by spotting uncommon words and returning their context.
  Map<String, String> extractVocabularyWithContext(
    String text, {
    int maxItems = 12,
  }) {
    final sentences = splitSentences(text);
    if (sentences.isEmpty) return const {};

    final keywords = extractKeywords(text, maxKeywords: maxItems * 2);
    if (keywords.isEmpty) return const {};

    final vocab = <String, String>{};

    for (final keyword in keywords) {
      if (vocab.length >= maxItems) break;
      final pattern = RegExp(
        '\\b${RegExp.escape(keyword)}\\b',
        caseSensitive: false,
      );
      final matchSentence = sentences.firstWhere(
        (sentence) => pattern.hasMatch(sentence),
        orElse: () => '',
      );

      if (matchSentence.isEmpty) continue;
      vocab[keyword] = _buildContextualDefinition(keyword, matchSentence);
    }

    return vocab;
  }

  String buildOutlineSummary(
    String text, {
    int maxHighlights = 3,
    int maxKeywords = 5,
  }) {
    final highlights = extractHighlights(
      text,
      maxSentences: maxHighlights,
    );
    final keywords = extractKeywords(
      text,
      maxKeywords: maxKeywords,
    );

    final buffer = <String>[];
    if (highlights.isNotEmpty) {
      buffer.add('Highlights:');
      for (final highlight in highlights) {
        buffer.add('- ${_truncate(highlight, maxLength: 160)}');
      }
    }
    if (keywords.isNotEmpty) {
      buffer.add('Keywords: ${keywords.take(maxKeywords).join(', ')}');
    }

    if (buffer.isEmpty) {
      final sentences = splitSentences(text);
      if (sentences.isEmpty) return text;
      return sentences.first;
    }

    return buffer.join('\n');
  }

  String _buildContextualDefinition(String word, String sentence) {
    final compact = sentence.replaceAll(RegExp(r'\s+'), ' ').trim();
    final truncated =
        compact.length > 140 ? '${compact.substring(0, 137)}…' : compact;
    return "In this document, \"$word\" is used here: $truncated";
  }

  String _cleanSnippet(String text) {
    var result = text.trim();
    if (result.contains(':')) {
      final parts = result.split(':');
      if (parts.first.split(' ').length <= 3) {
        final rest = parts.sublist(1).join(':').trim();
        if (rest.isNotEmpty) result = rest;
      }
    }
    result = result.replaceAll(RegExp(r'\s+'), ' ');
    if (result.startsWith('that ')) {
      result = result.substring(5);
    }
    if (result.startsWith('where ')) {
      result = result.substring(6);
    }
    return result;
  }

  String _toSentence(String text) {
    if (text.isEmpty) return text;
    var trimmed = text.trim();
    if (!trimmed.endsWith('.')) {
      trimmed += '.';
    }
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  String _lowercaseFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toLowerCase() + text.substring(1);
  }

  List<String> _sentenceClauses(String sentence) {
    return sentence
        .split(RegExp(r'[;,:]'))
        .map((clause) => clause.trim())
        .where((clause) => clause.isNotEmpty)
        .toList();
  }

  String? _selectRelevantClause(
    String sentence,
    Set<String> questionTokens,
  ) {
    final clauses = _sentenceClauses(sentence);
    if (clauses.isEmpty) return null;

    String? bestClause;
    double bestScore = 0;

    for (final clause in clauses) {
      final clauseTokens = tokenize(clause).toSet();
      if (clauseTokens.isEmpty) continue;
      final overlap =
          clauseTokens.where((token) => questionTokens.contains(token)).length;
      final score =
          overlap / clauseTokens.length; // prefer clauses that match question
      if (score > bestScore) {
        bestScore = score;
        bestClause = clause;
      }
    }

    return bestClause ?? clauses.first;
  }

  String _formatAnswer(String question, String sentence) {
    final snippet = _cleanSnippet(sentence);
    final lower = question.toLowerCase().trim();

    if (snippet.isEmpty) {
      return "I'm not sure yet. Try rephrasing the question.";
    }

    if (lower.startsWith('what')) {
      return _toSentence("It means ${_lowercaseFirst(snippet)}");
    }
    if (lower.startsWith('where')) {
      final lowered = snippet.toLowerCase();
      if (lowered.startsWith('at ') ||
          lowered.startsWith('in ') ||
          lowered.startsWith('inside ') ||
          lowered.startsWith('within ')) {
        return _toSentence("They wait ${_lowercaseFirst(snippet)}");
      }
      return _toSentence("They wait at ${_lowercaseFirst(snippet)}");
    }
    if (lower.startsWith('who')) {
      return _toSentence("It refers to ${_lowercaseFirst(snippet)}");
    }
    if (lower.startsWith('when')) {
      return _toSentence("It happens when ${_lowercaseFirst(snippet)}");
    }
    if (lower.startsWith('why')) {
      return _toSentence("This happens because ${_lowercaseFirst(snippet)}");
    }
    if (lower.startsWith('how')) {
      return _toSentence("It works like this: ${_lowercaseFirst(snippet)}");
    }

    return _toSentence("Here’s what I found: ${_lowercaseFirst(snippet)}");
  }

  String _truncate(String text, {int maxLength = 200}) {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= maxLength) return compact;
    return '${compact.substring(0, maxLength - 1)}…';
  }
}

