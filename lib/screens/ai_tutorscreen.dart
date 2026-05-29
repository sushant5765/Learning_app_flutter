import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/ai_service.dart';

class AiTutorScreen extends StatefulWidget {
  final String lessonTitle;
  final String lessonContent;

  const AiTutorScreen({
    super.key,
    required this.lessonTitle,
    required this.lessonContent,
  });

  @override
  State<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends State<AiTutorScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final FlutterTts _tts = FlutterTts();

  final AiService _aiService = AiService();
  bool _loading = false;
  bool _speaking = false;

  String? _lastAnswer; // 🔥 store last AI answer

  @override
  void initState() {
    super.initState();

    // TTS setup
    _tts.setLanguage("en-US");
    _tts.setSpeechRate(0.42);
    _tts.setPitch(1.0);
    _tts.setStartHandler(() => setState(() => _speaking = true));
    _tts.setCompletionHandler(() => setState(() => _speaking = false));
    _tts.setErrorHandler((_) => setState(() => _speaking = false));

    _aiService.startNewChat(widget.lessonContent);
    final overview = _aiService.summarizeLesson(widget.lessonContent);

    // Welcome message
    _messages.add({
      "role": "ai",
      "text":
          "Hello! 👋 I'm your tutor for \"${widget.lessonTitle}\".\nHere is a quick overview:\n$overview"
    });
  }

  @override
  void dispose() {
    _tts.stop();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "text": text});
      _controller.clear();
      _loading = true;
    });

    try {
      final resolvedReply = await _aiService.sendMessage(text);

      if (!mounted) return;

      setState(() {
        _messages.add({"role": "ai", "text": resolvedReply});
        _lastAnswer = resolvedReply; // 🔥 save the reply
        _loading = false;
      });

      // Speak reply aloud
      await _tts.stop();
      if (resolvedReply.isNotEmpty) {
        await _tts.speak(resolvedReply);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Tutor assistant issue: $e")),
      );
    }
  }

  Future<void> _stopSpeaking() async {
    await _tts.stop();
    setState(() => _speaking = false);
  }

  Future<void> _replayAnswer() async {
    if (_lastAnswer == null) return;
    await _tts.stop();
    await _tts.speak(_lastAnswer!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDE7),
      appBar: AppBar(
        title: Text("AI Tutor - ${widget.lessonTitle}"),
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
        actions: [
          if (_speaking)
            IconButton(
              icon: const Icon(Icons.stop_circle, color: Colors.white),
              onPressed: _stopSpeaking,
              tooltip: "Stop Voice",
            ),
          if (!_speaking && _lastAnswer != null) // 🔥 show play when not speaking
            IconButton(
              icon: const Icon(Icons.play_circle, color: Colors.white),
              onPressed: _replayAnswer,
              tooltip: "Play Again",
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg["role"] == "user";
                return Align(
                  alignment:
                  isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser
                          ? const Color(0xFF4A90E2)
                          : const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      msg["text"] ?? "",
                      style: TextStyle(
                        fontSize: 16,
                        color: isUser ? Colors.white : Colors.black,
                        fontFamily: "OpenDyslexic",
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "Ask me something...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF4A90E2)),
                  onPressed: _loading ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
