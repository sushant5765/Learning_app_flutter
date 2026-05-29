import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:learning_app/screens/ai_tutorscreen.dart';
import '../services/local_nlp_service.dart';


class LessonDetailScreen extends StatefulWidget {
  final String title;
  final String content;

  const LessonDetailScreen({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  final FlutterTts _tts = FlutterTts();
  final LocalNlpService _nlp = LocalNlpService();
  bool _speaking = false;
  bool _simplifying = false;

  @override
  void initState() {
    super.initState();
    // TTS setup
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.42);
    _tts.setPitch(1.0);
    _tts.setStartHandler(() => setState(() => _speaking = true));
    _tts.setCompletionHandler(() => setState(() => _speaking = false));
    _tts.setErrorHandler((_) => setState(() => _speaking = false));

  }

  String _simplifyText(String text) {
    final sentences = _nlp.splitSentences(text);
    final simplified = <String>[];

    for (final sentence in sentences) {
      final easier = _replaceComplexWords(sentence.trim());
      simplified.addAll(_chunkSentence(easier));
    }

    if (simplified.isEmpty) {
      return text;
    }

    return simplified
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n');
  }

  String _replaceComplexWords(String sentence) {
    const replacements = {
      'communicate': 'share ideas',
      'information': 'facts',
      'technology': 'tools',
      'difficult': 'hard',
      'important': 'key',
      'individuals': 'people',
      'utilize': 'use',
      'purchase': 'buy',
      'assist': 'help',
      'comprehend': 'understand',
    };

    return sentence.split(RegExp(r'(\b)')).map((token) {
      final lower = token.toLowerCase();
      if (replacements.containsKey(lower)) {
        final replacement = replacements[lower]!;
        if (token.isEmpty) return token;
        if (token[0] == token[0].toUpperCase()) {
          return replacement[0].toUpperCase() + replacement.substring(1);
        }
        return replacement;
      }
      return token;
    }).join();
  }

  List<String> _chunkSentence(String sentence) {
    final words = sentence.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final chunks = <String>[];
    final buffer = <String>[];
    for (final word in words) {
      buffer.add(word);
      if (buffer.length >= 12) {
        chunks.add(buffer.join(' '));
        buffer.clear();
      }
    }
    if (buffer.isNotEmpty) {
      chunks.add(buffer.join(' '));
    }

    return chunks.isEmpty ? [sentence] : chunks;
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _speak() async {
    await _tts.stop();
    await _tts.speak(widget.content);
  }

  Future<void> _stop() async {
    await _tts.stop();
    setState(() => _speaking = false);
  }

  Future<void> _simplify() async {
    setState(() => _simplifying = true);
    try {
      final simplified = _simplifyText(widget.content);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Simplified'),
          content: SingleChildScrollView(
            child: Text(
              simplified.isEmpty ? 'Could not simplify.' : simplified,
              style: const TextStyle(
                fontSize: 18,
                height: 1.5,
                fontFamily: 'OpenDyslexic',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            )
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Simplify failed: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _simplifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDE7),
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  widget.content,
                  style: const TextStyle(
                    fontSize: 20,
                    height: 1.6,
                    letterSpacing: 0.25,
                    fontFamily: 'OpenDyslexic',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Row with Read Aloud + Simplify
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _speaking ? _stop : _speak,
                    icon: Icon(
                      _speaking ? Icons.stop : Icons.volume_up,
                      color: Colors.white,
                    ),
                    label: Text(_speaking ? 'Stop' : 'Read Aloud'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _simplifying ? null : _simplify,
                    icon: _simplifying
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.auto_fix_high, color: Colors.white),
                    label: const Text('Simplify'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFA726),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Ask AI Tutor button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AiTutorScreen(
                        lessonTitle: widget.title,
                        lessonContent: widget.content,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.smart_toy, color: Colors.white),
                label: const Text('Ask AI Tutor'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
