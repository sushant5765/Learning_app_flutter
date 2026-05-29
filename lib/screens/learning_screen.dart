import 'package:flutter/material.dart';
import '../services/nlp_service.dart';
import '../services/tts_service.dart';
import '../services/speech_service.dart';
import '../services/hive_store_service.dart';
import 'dart:math';
import '../services/auth_services.dart';

class LearningScreen extends StatefulWidget {
  final String originalText;
  LearningScreen({required this.originalText});

  @override
  _LearningScreenState createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  String simplifiedText = "";
  List<String> keyPoints = [];
  final SpeechService _speechService = SpeechService();
  String recognized = "";
  double accuracy = 0.0;
  String feedback = "";
  bool listening = false;
  bool processing = true;
  DateTime? _listenStart;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    simplifiedText = await NlpService.simplifyText(widget.originalText);
    keyPoints = NlpService.extractKeyPoints(widget.originalText, maxPoints: 5);
    await _speechService.init();
    setState(() { processing = false; });
  }

  void _playTTS() async {
    await TtsService.speak(simplifiedText);
  }

  void _startListening() async {
    setState(() {
      listening = true;
      recognized = "";
      accuracy = 0.0;
      feedback = "";
      _listenStart = DateTime.now();
    });

    _speechService.listen((result) {
      setState(() { recognized = result; });
      // Evaluate each time partial result arrives
      _evaluate(result);
    });

    // Stop after 10 seconds if not automatically stopped
    Future.delayed(Duration(seconds: 11), () {
      _speechService.stop();
      if (mounted) setState(() { listening = false; });
    });
  }

  void _evaluate(String studentText) async {
    final ref = _normalize(simplifiedText);
    final hyp = _normalize(studentText);
    final refWords = ref.split(' ').where((s)=>s.isNotEmpty).toList();
    final hypWords = hyp.split(' ').where((s)=>s.isNotEmpty).toList();

    final dist = _levenshtein(refWords, hypWords);
    final wer = refWords.isEmpty ? 1.0 : dist / refWords.length;
    final acc = (1 - wer) * 100;

    final now = DateTime.now();
    final timeSpent = _listenStart == null ? 0.0 : now.difference(_listenStart!).inSeconds.toDouble();
    final mistakesCount = _estimateMistakes(refWords, hypWords);

    setState(() {
      accuracy = acc.clamp(0.0, 100.0);
      feedback = accuracy >= 85 ? "Excellent pronunciation!" :
      accuracy >= 65 ? "Good — a few mistakes." :
      "Keep practicing — focus on pronunciation and fluency.";
    });

    // Save to Firestore (demoUser). In production use authenticated uid.
    try {
      final userId = AuthService().currentUserId ?? 'local_user';
      await LocalService.savePerformance(
        userId: userId,
        accuracy: accuracy,
        timeSpent: timeSpent,
        mistakes: mistakesCount,
        fluencyScore: (accuracy / 100.0),
        simplifiedText: simplifiedText,
      );
    } catch (e) {
      print('Error saving performance: $e');
    }
  }

  String _normalize(String s) {
    return s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  int _levenshtein(List<String> a, List<String> b) {
    final n = a.length;
    final m = b.length;
    if (n == 0) return m;
    if (m == 0) return n;
    List<List<int>> d = List.generate(n+1, (_) => List.filled(m+1, 0));
    for (int i=0;i<=n;i++) d[i][0] = i;
    for (int j=0;j<=m;j++) d[0][j] = j;
    for (int i=1;i<=n;i++){
      for (int j=1;j<=m;j++){
        int cost = a[i-1] == b[j-1] ? 0 : 1;
        d[i][j] = [
          d[i-1][j] + 1,
          d[i][j-1] + 1,
          d[i-1][j-1] + cost
        ].reduce(min);
      }
    }
    return d[n][m];
  }

  int _estimateMistakes(List<String> refWords, List<String> hypWords) {
    return _levenshtein(refWords, hypWords);
  }

  @override
  void dispose() {
    _speechService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Learning"),
      ),
      body: processing ? Center(child: CircularProgressIndicator()) : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Original Text (extracted):", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Expanded(
              child: SingleChildScrollView(
                child: Text(widget.originalText),
              ),
            ),
            Divider(),
            Text("Simplified Text:", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
              child: Text(simplifiedText, style: TextStyle(fontSize: 16)),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: keyPoints.map((kp) => Chip(label: Text(kp, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _playTTS,
                  icon: Icon(Icons.volume_up),
                  label: Text("Listen"),
                ),
                SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: listening ? null : _startListening,
                  icon: Icon(Icons.mic),
                  label: Text(listening ? "Listening..." : "Read aloud"),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text("Recognized: $recognized"),
            SizedBox(height: 6),
            Text("Accuracy: ${accuracy.toStringAsFixed(1)}%", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(feedback, style: TextStyle(color: accuracy >= 85 ? Colors.green : Colors.orange)),
          ],
        ),
      ),
    );
  }
}
