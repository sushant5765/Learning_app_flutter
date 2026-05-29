import 'dart:math';
import 'package:flutter/material.dart';
import 'package:learning_app/services/hive_store.dart';

class VocabGameScreen extends StatefulWidget {
  final String uid;
  final List<String> words;
  const VocabGameScreen({super.key, required this.uid, required this.words});

  @override
  State<VocabGameScreen> createState() => _VocabGameScreenState();
}

class _VocabGameScreenState extends State<VocabGameScreen> {
  late String _currentWord;
  late List<String?> _blanks;
  final TextEditingController _controller = TextEditingController();
  bool _completed = false;
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _pickWord();
  }

  void _pickWord() {
    final rand = Random().nextInt(widget.words.length);
    _currentWord = widget.words[rand];
    _blanks = _generateBlanks(_currentWord);
    _completed = false;
  }

  List<String?> _generateBlanks(String word) {
    final rand = Random();
    return word.split('').map((l) {
      if (rand.nextBool()) return null; // hidden
      return l; // visible
    }).toList();
  }

  void _checkAnswer() async {
    final userInput = _controller.text.trim().toLowerCase();
    final correct = userInput == _currentWord.toLowerCase();
    if (correct) _streak += 1;
    else _streak = 0;

    setState(() => _completed = true);

    // Save result to Firestore
    await HiveService(widget.uid).saveVocabularyResult(words: [
      {"word": _currentWord, "correct": correct, "streak": _streak}
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Vocabulary Game")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              "Fill in the blanks",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 6,
              children: _blanks
                  .map((l) => Container(
                width: 30,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(width: 2))),
                child: Text(l ?? "_", style: const TextStyle(fontSize: 22)),
              ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: "Enter the full word",
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
                onPressed: _completed ? null : _checkAnswer,
                child: const Text("Submit")),
            if (_completed)
              Column(
                children: [
                  const SizedBox(height: 12),
                  Text(
                    _controller.text.toLowerCase() == _currentWord.toLowerCase()
                        ? "🌟 Correct! Streak: $_streak"
                        : "❌ Incorrect. Correct word: $_currentWord",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                      onPressed: () {
                        _controller.clear();
                        _pickWord();
                        setState(() {});
                      },
                      child: const Text("Next Word"))
                ],
              )
          ],
        ),
      ),
    );
  }
}
