import 'dart:math';

import 'local_nlp_service.dart';
import 'ai_model_service.dart';

class AiService {
  AiService();

  final LocalNlpService _nlp = LocalNlpService();
  final List<String> _conversationHistory = [];

  String? _documentText;
  String? _cachedSummary;
  List<String> _cachedHighlights = const [];
  String? _lastAnswer;

  void startNewChat(String documentText) {
    _documentText = documentText;
    _conversationHistory.clear();
    _cachedSummary = null;
    _cachedHighlights = const [];
    _lastAnswer = null;
  }



  // send message for summarization   dipslay in UI
  Future<String> sendMessage(String userMessage) async {                   //used by document  scan screen
    if (_documentText == null || _documentText!.trim().isEmpty) {
      return 'Load a document to start the conversation.';
    }

    final lower = userMessage.toLowerCase();

    if (lower.contains('summar')) {
      return await _summarizeCurrentDocument();
    }

    if (lower.contains('highlight') || lower.contains('note')) {
      return _formatHighlights();
    }

    if (lower.contains('keyword') || lower.contains('vocabulary')) {
      return _formatVocabularyList();
    }

    _conversationHistory.add(userMessage);

    // Try trained Q&A model first
    String answer;
    try {
      final modelAnswer = await AiModelService.answerWithModel(                    // answer questions
        userMessage,
        _documentText!,
      );
      if (modelAnswer.isNotEmpty) {
        answer = modelAnswer;
      } else {
        // Fallback to local NLP
        answer = _nlp.answerQuestion(
          _documentText!,
          userMessage,
          conversationHistory: _conversationHistory.reversed.take(3).toList(),
        );
      }
    } catch (e) {
      // Fallback to local NLP on error
      answer = _nlp.answerQuestion(
        _documentText!,
        userMessage,
        conversationHistory: _conversationHistory.reversed.take(3).toList(),
      );
    }

    if (_documentText != null &&
        _lastAnswer != null &&
        answer.trim().toLowerCase() == _lastAnswer!.trim().toLowerCase()) {
      final extra = _nlp.extractHighlights(_documentText!, maxSentences: 2);
      if (extra.isNotEmpty) {
        answer = "Another detail: ${extra.first}";
      }
    }

    _conversationHistory.add(answer);
    _lastAnswer = answer;
    return answer;
  }


  // extra parts
  Future<String> generateReadingPassage(
    String topic,
    String length, {
    String difficulty = 'beginner',
  }) async {
    final sanitizedTopic =
        topic.trim().isEmpty ? 'learning something new' : topic.trim();
    final isLong = length.toLowerCase() == 'long';
    final difficultyDescriptor = _difficultyDescriptor(difficulty);

    final opening = _openingSentence(sanitizedTopic, difficultyDescriptor);
    final body = _bodySentence(sanitizedTopic, difficultyDescriptor);
    final closing = _closingSentence(sanitizedTopic, difficultyDescriptor);

    final sentences = <String>[opening, body];
    if (isLong) {
      sentences.add(_secondBodySentence(sanitizedTopic, difficultyDescriptor));
    }
    sentences.add(closing);

    return sentences.join(' ');
  }

  String _difficultyDescriptor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'intermediate':
        return 'curious middle school learner';
      case 'advanced':
        return 'confident young scholar';
      default:
        return 'friendly reader';
    }
  }

  String _openingSentence(String topic, String descriptor) {
    final templates = [
      'Today, a $descriptor explores $topic with open eyes.',
      '$topic can teach a $descriptor more than they expect.',
      'Imagine a $descriptor discovering $topic for the first time.',
    ];
    return templates[Random().nextInt(templates.length)];
  }

  String _bodySentence(String topic, String descriptor) {
    final templates = [
      'They notice simple details, like how $topic influences everyday choices.',
      'They ask gentle questions about $topic and connect it to real-life moments.',
      'They collect facts about $topic and explain them in calm, clear steps.',
    ];
    return templates[Random().nextInt(templates.length)];
  }

  String _secondBodySentence(String topic, String descriptor) {
    final templates = [
      'Soon, the $descriptor shares short examples to help friends understand $topic.',
      'They link $topic to a past experience and reflect on what changed.',
      'Learning about $topic gives the $descriptor a new idea they want to try.',
    ];
    return templates[Random().nextInt(templates.length)];
  }

  String _closingSentence(String topic, String descriptor) {
    final templates = [
      'By the end, the $descriptor feels proud and ready to explain $topic to someone else.',
      'This gentle journey shows the $descriptor that $topic can inspire kinder actions.',
      'The $descriptor realises that understanding $topic helps them grow with confidence.',
    ];
    return templates[Random().nextInt(templates.length)];
  }

  Future<String> _summarizeCurrentDocument() async {
    if (_documentText == null || _documentText!.trim().isEmpty) {
      return 'I need a document to summarise first.';
    }
    final source = _documentText!;
    
    // Try trained model first
    if (_cachedSummary == null) {
      try {
        final modelSummary = await AiModelService.summarizeWithModel(source);
        if (modelSummary.isNotEmpty && !_needsFallbackSummary(modelSummary, source)) {
          _cachedSummary = modelSummary;
          _lastAnswer = _cachedSummary;
          return _cachedSummary!;
        }
      } catch (e) {
        // Fall through to local NLP
      }
    }
    
    // Use local NLP as fallback or if cached
    _cachedSummary ??= _nlp.summarize(source);
    if (_cachedSummary == null) {
      _cachedSummary = _nlp.buildOutlineSummary(source);
    }

    if (_needsFallbackSummary(_cachedSummary!, source)) {
      _cachedSummary = _nlp.buildOutlineSummary(source);
    }

    _lastAnswer = _cachedSummary;
    return _cachedSummary!;
  }

  String _formatHighlights() {
    if (_documentText == null || _documentText!.trim().isEmpty) {
      return 'Upload a document to highlight key points.';
    }
    if (_cachedHighlights.isEmpty) {
      _cachedHighlights = _nlp.extractHighlights(_documentText!);
    }
    if (_cachedHighlights.isEmpty) {
      return 'I could not find strong highlight sentences yet.';
    }
    final bullet = _cachedHighlights.map((sentence) => '• $sentence').join('\n');

    _lastAnswer = bullet;
    return 'Here are helpful notes:\n$bullet';
  }

  String _formatVocabularyList() {
    if (_documentText == null || _documentText!.trim().isEmpty) {
      return 'A document is needed before gathering vocabulary.';
    }
    final vocab =
        _nlp.extractVocabularyWithContext(_documentText!, maxItems: 10);
    if (vocab.isEmpty) {
      return 'No standout vocabulary found yet.';
    }
    final result = vocab.entries
        .map((entry) => '• ${entry.key}: ${entry.value}')
        .join('\n');

    _lastAnswer = result;
    return result;
  }

  Map<String, String> extractVocabularyWithContext({int count = 12}) {
    if (_documentText == null || _documentText!.trim().isEmpty) {
      return const {};
    }
    return _nlp.extractVocabularyWithContext(
      _documentText!,
      maxItems: count,
    );
  }

  String summarizeLesson(String lessonContent) {
    if (lessonContent.trim().isEmpty) {
      return 'The lesson is empty.';
    }
    return _nlp.summarize(lessonContent, maxSentences: 2);
  }

  String answerLessonQuestion(String lessonContent, String question) {
    return _nlp.answerQuestion(lessonContent, question);
  }

  void resetConversation() {
    _conversationHistory.clear();
    _documentText = null;
    _cachedSummary = null;
    _cachedHighlights = const [];
  }

  bool _needsFallbackSummary(String summary, String original) {
    final normalizedSummary = summary.replaceAll(RegExp(r'\s+'), ' ').trim();
    final normalizedOriginal = original.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalizedSummary.isEmpty) return true;
    if (normalizedSummary.toLowerCase() == normalizedOriginal.toLowerCase()) {
      return true;
    }

    final summaryWords = normalizedSummary.split(' ');
    final originalWords = normalizedOriginal.split(' ');

    if (originalWords.length <= 6) {
      // For very short texts, prefer concise bullet outline.
      return summaryWords.length >= originalWords.length;
    }

    final ratio =
        originalWords.isEmpty ? 1.0 : summaryWords.length / originalWords.length;
    return ratio >= 0.8;
  }
}
