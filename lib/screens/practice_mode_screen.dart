// lib/screens/practice_mode_screen.dart
import 'package:flutter/material.dart';

class PracticeModeScreen extends StatelessWidget {
  final Map<String, dynamic> word;
  final List<String> options;
  final double fontSize;
  final double lineHeight;
  final double letterSpacing;
  final String fontFamily;
  final double progress;
  final Function(String) onAnswer;
  final VoidCallback onOpenSettings;

  const PracticeModeScreen({
    Key? key,
    required this.word,
    required this.options,
    required this.fontSize,
    required this.lineHeight,
    required this.letterSpacing,
    required this.fontFamily,
    required this.progress,
    required this.onAnswer,
    required this.onOpenSettings,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final sentence = word['exampleSentence']
        .replaceAll(word['word'], '_____'); // blank word

    return Scaffold(
      appBar: AppBar(
        title: const Text("🎮 Practice Mode"),
        actions: [
          IconButton(icon: const Icon(Icons.tune), onPressed: onOpenSettings),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              sentence,
              style: TextStyle(
                fontSize: fontSize,
                height: lineHeight,
                letterSpacing: letterSpacing,
                fontFamily: fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              children: options
                  .map(
                    (w) => ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => onAnswer(w),
                  child: Text(
                    w,
                    style: TextStyle(fontSize: fontSize - 2, fontFamily: fontFamily),
                  ),
                ),
              )
                  .toList(),
            ),
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: progress,
              color: Colors.green,
              backgroundColor: Colors.grey[300],
            ),
          ],
        ),
      ),
    );
  }
}
