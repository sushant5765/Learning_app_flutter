import 'dart:math';

import 'package:english_words/english_words.dart' as words;

enum LanguageIssueType { spelling, grammar }

class LanguageIssue {
  LanguageIssue({
    required this.type,
    required this.word,
    required this.offset,
    required this.length,
    required this.message,
  });

  final LanguageIssueType type;
  final String word;
  final int offset;
  final int length;
  final String message;

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'word': word,
        'offset': offset,
        'length': length,
        'message': message,
      };
}

class LanguageAnalysis {
  LanguageAnalysis({
    required this.spelling,
    required this.grammar,
  });

  final List<LanguageIssue> spelling;
  final List<LanguageIssue> grammar;
}

/// Offline spelling & grammar helper.
class LocalLanguageToolService {
  LocalLanguageToolService._() {
    _dictionary.addAll(words.all.map((w) => w.toLowerCase()));                       // words all form english words dict
    _dictionary.addAll({
      'ai',
      'tutor',
      'student',
      'learning',
      'practice',
      'feedback',
      'analysis',
      'spelling',
      'grammar',
      'vocabulary',
      'passage',
      'highlight',
      'dyslexia',
      'accessible',
      'was',
      'were',
      'been',
      'being',
      'does',
      'did',
      'doing',
      'has',
      'have',
      'had',
      'is',
      'am',
      'be',
      'hibernate',
      'entertain',
      'are',


      'do',

      'kindness',
      'helping',
      'helped',
      'helpful',
      'help',
      'crossed',
      'crossing',
      'cross',
      'poor',
      'road',
      'boy',
      'act',
      'small',
    });
  }

  static final LocalLanguageToolService instance =
      LocalLanguageToolService._();

  final Set<String> _dictionary = <String>{};
  final RegExp _wordPattern = RegExp(r"[A-Za-z']+");

  LanguageAnalysis analyzeText(String text) {
    final spellingIssues = _findSpellingIssues(text);
    final grammarIssues = _findGrammarIssues(text);

    return LanguageAnalysis(spelling: spellingIssues, grammar: grammarIssues);
  }


  //spelling error
  List<LanguageIssue> _findSpellingIssues(String text) {   //spilt into words
    final issues = <LanguageIssue>[];
    for (final match in _wordPattern.allMatches(text)) {
      final word = match.group(0)!;
      if (word.isEmpty) continue;

      final normalized = word.toLowerCase();               //normalize for comparison
      if (_dictionary.contains(normalized)) continue;        //check in dictionary
      if (normalized.length <= 2) continue;

      if (_isKnownWord(normalized)) continue;                  //check derived form

      // Ignore capitalised first words (likely names).
      if (_isLikelyProperNoun(word, match.start, text)) continue;

      issues.add(
        LanguageIssue(
          type: LanguageIssueType.spelling,
          word: word,
          offset: match.start,
          length: match.end - match.start,
          message: _buildSpellingFeedback(word),
        ),
      );
    }
    return issues;
  }

  bool _isKnownWord(String word) {
    if (_dictionary.contains(word)) return true;

    final stripped = _stripPossessive(word);
    if (stripped != word && _dictionary.contains(stripped)) return true;

    for (final candidate in _derivedForms(word)) {
      if (_dictionary.contains(candidate)) return true;
    }

    return false;
  }

  String _stripPossessive(String word) {
    if (word.endsWith("'s")) {
      return word.substring(0, word.length - 2);
    }
    if (word.endsWith("’s")) {
      return word.substring(0, word.length - 2);
    }
    return word;
  }



  // derived form
  Iterable<String> _derivedForms(String word) sync* {
    if (word.endsWith('ies') && word.length > 3) {
      yield word.substring(0, word.length - 3) + 'y';
    }
    if (word.endsWith('ing') && word.length > 4) {
      final stem = word.substring(0, word.length - 3);
      yield stem;
      if (!stem.endsWith('e')) {
        yield stem + 'e';
      }
    }
    if (word.endsWith('ed') && word.length > 3) {
      final stem = word.substring(0, word.length - 2);
      yield stem;
      if (!stem.endsWith('e')) {
        yield stem + 'e';
      }
    }
    if (word.endsWith('er') && word.length > 3) {
      yield word.substring(0, word.length - 2);
    }
    if (word.endsWith('est') && word.length > 4) {
      yield word.substring(0, word.length - 3);
    }
    if (word.endsWith('ly') && word.length > 3) {
      yield word.substring(0, word.length - 2);
    }
    if (word.endsWith('ness') && word.length > 5) {
      yield word.substring(0, word.length - 4);
    }
    if (word.endsWith('ment') && word.length > 5) {
      yield word.substring(0, word.length - 4);
    }
    if (word.endsWith('ful') && word.length > 4) {
      yield word.substring(0, word.length - 3);
    }
    if (word.endsWith('less') && word.length > 5) {
      yield word.substring(0, word.length - 4);
    }
    if (word.endsWith('able') && word.length > 5) {
      yield word.substring(0, word.length - 4);
    }
    if (word.endsWith('ation') && word.length > 6) {
      yield word.substring(0, word.length - 5);
    }
    if (word.endsWith('s') && word.length > 3) {
      yield word.substring(0, word.length - 1);
    }
    if (word.endsWith('es') && word.length > 4) {
      yield word.substring(0, word.length - 2);
    }
  }

  // checks grammar rule based
  List<LanguageIssue> _findGrammarIssues(String text) {
    final issues = <LanguageIssue>[];
    issues.addAll(_checkRepeatedSpaces(text));
    issues.addAll(_checkSentenceCapitalisation(text));
    issues.addAll(_checkCommonConfusions(text));
    issues.addAll(_checkShortRunOns(text));
    return issues;
  }

  bool _isLikelyProperNoun(String word, int offset, String text) {
    if (word.length <= 1) return false;
    final isCapitalised =
        word[0] == word[0].toUpperCase() && word.substring(1) != word.substring(1).toUpperCase();
    if (!isCapitalised) return false;

    // Start of text or sentence.
    if (offset == 0) return true;
    final preceding = text.substring(0, max(0, offset));
    final endsWithPunctuation = RegExp(r'[.!?]\s*$').hasMatch(preceding);
    return endsWithPunctuation;
  }

  String _buildSpellingFeedback(String original) {
    final lower = original.toLowerCase();
    final suggestions = _dictionary
        .where((candidate) =>
            (candidate.length - lower.length).abs() <= 2 &&
            _levenshteinDistance(candidate, lower) <= 2)
        .take(4)
        .toList();

    if (suggestions.isEmpty) {
      return 'Check the spelling of "$original".';
    }
    return 'Possible spelling issue. Try ${suggestions.join(", ")} instead of "$original".';
  }

  // spaces checking
  List<LanguageIssue> _checkRepeatedSpaces(String text) {
    final issues = <LanguageIssue>[];
    final regex = RegExp(r' {2,}');
    for (final match in regex.allMatches(text)) {
      issues.add(
        LanguageIssue(
          type: LanguageIssueType.grammar,
          word: text.substring(match.start, match.end),
          offset: match.start,
          length: match.end - match.start,
          message: 'Extra spaces found here. Keep spacing consistent.',
        ),
      );
    }
    return issues;
  }

  //capital sentences
  List<LanguageIssue> _checkSentenceCapitalisation(String text) {
    final issues = <LanguageIssue>[];
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
    var cursor = 0;
    for (final sentence in sentences) {
      final trimmed = sentence.trimLeft();
      if (trimmed.isEmpty) {
        cursor += sentence.length + 1;
        continue;
      }
      final firstChar = trimmed[0];
      if (RegExp(r'[a-z]').hasMatch(firstChar)) {
        final offsetAdjustment = sentence.length - trimmed.length;
        issues.add(
          LanguageIssue(
            type: LanguageIssueType.grammar,
            word: trimmed.split(' ').first,
            offset: cursor + offsetAdjustment,
            length: trimmed.split(' ').first.length,
            message: 'Capitalize the first word of your sentence.',
          ),
        );
      }
      cursor += sentence.length + 1;
    }
    return issues;
  }

  //common word confusion
  List<LanguageIssue> _checkCommonConfusions(String text) {
    final issues = <LanguageIssue>[];

    final patterns = <RegExp, String>{
      RegExp(r'\bi\b'): 'Pronoun "I" should be uppercase.',
      RegExp(r"\b(your)\s+(you're)\b", caseSensitive: false):
          'Did you mean "you\'re" (you are) or "your"?',
      RegExp(r"\b(there)\s+(they\'re|their)\b", caseSensitive: false):
          'Double-check the homophone here.',
      RegExp(r"\b(an)\s+([bcdfghjklmnpqrstvwxyz]\w*)", caseSensitive: false):
          'Use "a" before consonant sounds.',
      RegExp(r"\b(a)\s+([aeiou]\w*)", caseSensitive: false):
          'Use "an" before vowel sounds.',
    };

    for (final entry in patterns.entries) {
      for (final match in entry.key.allMatches(text)) {
        issues.add(
          LanguageIssue(
            type: LanguageIssueType.grammar,
            word: text.substring(match.start, match.end),
            offset: match.start,
            length: match.end - match.start,
            message: entry.value,
          ),
        );
      }
    }

    return issues;
  }


  //commas after and checks conjunctions
  List<LanguageIssue> _checkShortRunOns(String text) {
    final issues = <LanguageIssue>[];
    final regex = RegExp(r'\b(and|but|so)\s+\b');
    for (final match in regex.allMatches(text)) {
      if (match.start == 0) continue;
      final precedingChar = text[match.start - 1];
      if (precedingChar != ',' && precedingChar != ';') {
        issues.add(
          LanguageIssue(
            type: LanguageIssueType.grammar,
            word: match.group(0)!,
            offset: match.start,
            length: match.end - match.start,
            message: 'Consider adding a comma before conjunctions joining clauses.',
          ),
        );
      }
    }
    return issues;
  }

  int _levenshteinDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final matrix = List.generate(
      a.length + 1,
      (_) => List<int>.filled(b.length + 1, 0),
    );

    for (var i = 0; i <= a.length; i++) {
      matrix[i][0] = i;
    }
    for (var j = 0; j <= b.length; j++) {
      matrix[0][j] = j;
    }

    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce(min);
      }
    }
    return matrix[a.length][b.length];
  }
}

