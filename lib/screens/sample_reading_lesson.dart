import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/local_nlp_service.dart';

class SampleReadingLesson extends StatefulWidget {
  const SampleReadingLesson({super.key});

  @override
  State<SampleReadingLesson> createState() => _SampleReadingLessonState();
}

class _SampleReadingLessonState extends State<SampleReadingLesson> {
  // ---- Content ----
  final String _passage = 'The internet has changed how people communicate.';

  // ---- TTS ----
  final FlutterTts _tts = FlutterTts();
  bool _speaking = false;

  // ---- STT ----
  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _listening = false;

  // ---- Local NLP ----
  final LocalNlpService _nlp = LocalNlpService();
  bool _aiBusy = false;

  // ---- Answer + Feedback ----
  final TextEditingController _answerCtl = TextEditingController();
  String _feedback = '';
  Color _feedbackColor = Colors.black87;

  // ---- Timer & Progress ----
  late DateTime _startTime;
  bool _finished = false;

  // prefs keys
  final String _kAttempts = 'reading_lesson1_attempts';
  final String _kCorrect = 'reading_lesson1_correct';
  final String _kBestMs  = 'reading_lesson1_best_ms';
  final String _kBadgeFast = 'badge_fast_reader';

  @override
  void initState() {
    super.initState();

    // Start timer when screen opens
    _startTime = DateTime.now();

    // TTS
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.42);
    _tts.setPitch(1.0);
    _tts.setStartHandler(() => setState(() => _speaking = true));
    _tts.setCompletionHandler(() => setState(() => _speaking = false));
    _tts.setErrorHandler((_) => setState(() => _speaking = false));

    // No remote AI initialisation needed
  }

  @override
  void dispose() {
    _tts.stop();
    _answerCtl.dispose();
    super.dispose();
  }

  // ----------------- TTS -----------------
  Future<void> _speak() async {
    await _tts.stop();
    await _tts.speak(_passage);
  }

  Future<void> _stopSpeak() async {
    await _tts.stop();
    setState(() => _speaking = false);
  }

  // ----------------- STT -----------------
  Future<void> _startListening() async {
    if (_listening) return;
    final available = await _stt.initialize(
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          setState(() => _listening = false);
        }
      },
      onError: (e) {
        setState(() => _listening = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mic error: ${e.errorMsg}')),
        );
      },
    );
    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech not available. Type your answer.')),
      );
      return;
    }
    setState(() => _listening = true);
    await _stt.listen(
      localeId: 'en_US',
      onResult: (res) {
        setState(() {
          _answerCtl.text = res.recognizedWords;
        });
      },
    );
  }

  Future<void> _stopListening() async {
    await _stt.stop();
    setState(() => _listening = false);
  }

  // ----------------- AI Explain word -----------------
  Future<void> _explainWord(String word) async {
    setState(() => _aiBusy = true);
    try {
      final explanation = _buildWordExplanation(word);
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            explanation,
            style: const TextStyle(
              fontFamily: 'OpenDyslexic',
              fontSize: 18,
              height: 1.5,
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not explain "$word". $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  String _buildWordExplanation(String word) {
    final normalized = word.toLowerCase();
    const simpleDefinitions = {
      'internet':
          'Definition: The internet is a global network that lets computers share information.\nExample: I used the internet to chat with my cousin.',
      'communicate':
          'Definition: Communicate means to share ideas or feelings with someone.\nExample: We communicate by talking, texting, or writing.',
      'network':
          'Definition: A network is a group of connected things or people.\nExample: The school has a network of computers in every classroom.',
    };

    if (simpleDefinitions.containsKey(normalized)) {
      return simpleDefinitions[normalized]!;
    }

    final vocabContext =
        _nlp.extractVocabularyWithContext(_passage, maxItems: 10);
    final match = vocabContext.entries.firstWhere(
      (entry) => entry.key.toLowerCase() == normalized,
      orElse: () => MapEntry(
        normalized,
        'Look at this sentence for clues: "$_passage"',
      ),
    );

    return 'Definition: In this passage, "$word" relates to the idea mentioned below.\nExample: ${match.value}';
  }

  // ----------------- Evaluate Answer -----------------
  // Simple normalized Levenshtein similarity
  double _similarity(String a, String b) {
    a = _norm(a);
    b = _norm(b);
    if (a.isEmpty && b.isEmpty) return 1.0;
    final dist = _levenshtein(a, b);
    final maxLen = a.length > b.length ? a.length : b.length;
    return 1.0 - (dist / maxLen);
  }

  String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();

  int _levenshtein(String s, String t) {
    final m = s.length, n = t.length;
    if (m == 0) return n;
    if (n == 0) return m;

    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
    for (int i = 0; i <= m; i++) dp[i][0] = i;
    for (int j = 0; j <= n; j++) dp[0][j] = j;

    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        final cost = s[i - 1] == t[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,         // deletion
          dp[i][j - 1] + 1,         // insertion
          dp[i - 1][j - 1] + cost,  // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }
    return dp[m][n];
  }

  Future<void> _submitAnswer() async {
    final ans = _answerCtl.text;
    if (ans.trim().isEmpty) {
      setState(() {
        _feedback = 'Please say or type your answer.';
        _feedbackColor = Colors.red;
      });
      return;
    }

    // Accepted answers (you can grow this set)
    const expected = [
      'how people communicate',
      'the way people communicate',
      'communication',
      'how people talk to each other',
    ];

    // Score by best similarity among expected
    final sim = expected.map((e) => _similarity(ans, e)).fold<double>(0.0, (p, c) => c > p ? c : p);

    final correct = sim >= 0.62; // tweak threshold as needed

    if (!mounted) return;
    setState(() {
      _feedback = correct ? 'Correct! 🎉' : 'Not quite. Hint: focus on “communicate”.';
      _feedbackColor = correct ? Colors.green : Colors.orange;
    });

    // Save progress
    final prefs = await SharedPreferences.getInstance();
    final attempts = (prefs.getInt(_kAttempts) ?? 0) + 1;
    await prefs.setInt(_kAttempts, attempts);

    if (correct && !_finished) {
      final elapsedMs = DateTime.now().difference(_startTime).inMilliseconds;
      final prevBest = prefs.getInt(_kBestMs);
      if (prevBest == null || elapsedMs < prevBest) {
        await prefs.setInt(_kBestMs, elapsedMs);
      }
      final correctCount = (prefs.getInt(_kCorrect) ?? 0) + 1;
      await prefs.setInt(_kCorrect, correctCount);

      // Badge if under 30 seconds
      if (elapsedMs <= 30000) {
        await prefs.setBool(_kBadgeFast, true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🏅 Badge earned: Fast Reader')),
          );
        }
      }

      setState(() => _finished = true);

      // Show a simple result dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Great job!'),
            content: Text(
              'Time: ${(elapsedMs / 1000).toStringAsFixed(1)}s\n'
                  'Attempts: $attempts\n'
                  'Best time: ${((prefs.getInt(_kBestMs) ?? elapsedMs) / 1000).toStringAsFixed(1)}s',
              style: const TextStyle(fontFamily: 'OpenDyslexic', height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dyslexia-friendly palette
    const cream = Color(0xFFFDF6E3);
    const blue = Color(0xFF4A90E2);
    const orange = Color(0xFFFFA726);

    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        title: const Text(
          'Reading Lesson',
          style: TextStyle(fontFamily: 'OpenDyslexic', fontWeight: FontWeight.bold),
        ),
        backgroundColor: blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // Passage card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _passage,
                  style: const TextStyle(
                    fontFamily: 'OpenDyslexic',
                    fontSize: 20,
                    height: 1.6,
                    letterSpacing: 0.25,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Read Aloud
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _speaking ? _stopSpeak : _speak,
                    icon: Icon(_speaking ? Icons.stop : Icons.volume_up, color: Colors.white),
                    label: Text(_speaking ? 'Stop' : 'Read Aloud'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Hard words → AI Explain
            Text(
              'Tap a word for help:',
              style: TextStyle(
                fontFamily: 'OpenDyslexic',
                fontSize: 16,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _ExplainChip(
                  label: 'internet',
                  busy: _aiBusy,
                  onTap: () => _explainWord('internet'),
                ),
                _ExplainChip(
                  label: 'communicate',
                  busy: _aiBusy,
                  onTap: () => _explainWord('communicate'),
                ),
                _ExplainChip(
                  label: 'changed',
                  busy: _aiBusy,
                  onTap: () => _explainWord('changed'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Question
            const Text(
              'Question:',
              style: TextStyle(fontFamily: 'OpenDyslexic', fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'What changed because of the internet?',
              style: TextStyle(fontFamily: 'OpenDyslexic', fontSize: 18, height: 1.4),
            ),
            const SizedBox(height: 10),

            // Answer input + mic
            TextField(
              controller: _answerCtl,
              style: const TextStyle(fontFamily: 'OpenDyslexic', fontSize: 18),
              decoration: InputDecoration(
                hintText: 'Speak or type your answer…',
                hintStyle: const TextStyle(fontFamily: 'OpenDyslexic'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: IconButton(
                  onPressed: _listening ? _stopListening : _startListening,
                  icon: Icon(_listening ? Icons.mic_off : Icons.mic),
                  tooltip: _listening ? 'Stop listening' : 'Start voice input',
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitAnswer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: orange,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Submit Answer',
                  style: TextStyle(fontFamily: 'OpenDyslexic', fontSize: 18, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Feedback
            if (_feedback.isNotEmpty)
              Text(
                _feedback,
                style: TextStyle(
                  fontFamily: 'OpenDyslexic',
                  fontSize: 16,
                  color: _feedbackColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExplainChip extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback onTap;
  const _ExplainChip({
    required this.label,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: busy ? null : onTap,
      label: Text(
        label,
        style: const TextStyle(fontFamily: 'OpenDyslexic', fontSize: 16),
      ),
    );
  }
}
