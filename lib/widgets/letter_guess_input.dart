// widgets/letter_guess_input.dart

import 'dart:math';
import 'package:flutter/material.dart';

class LetterGuessInput extends StatefulWidget {
  final String correctWord;
  final Function(String) onCompleted;

  const LetterGuessInput({
    Key? key,
    required this.correctWord,
    required this.onCompleted,
  }) : super(key: key);

  @override
  _LetterGuessInputState createState() => _LetterGuessInputState();
}

class _LetterGuessInputState extends State<LetterGuessInput> {
  List<String> selectedLetters = [];
  late List<String> options;

  @override
  void initState() {
    super.initState();
    _generateOptions();
  }

  void _generateOptions() {
    final random = Random();
    List<String> letters = widget.correctWord.toUpperCase().split("");

    // add some random extra letters
    while (letters.length < widget.correctWord.length + 6) {
      letters.add(String.fromCharCode(random.nextInt(26) + 65));
    }
    letters.shuffle();
    options = letters;
  }

  void _onLetterTap(String letter) {
    if (selectedLetters.length < widget.correctWord.length) {
      setState(() {
        selectedLetters.add(letter);
      });

      if (selectedLetters.length == widget.correctWord.length) {
        widget.onCompleted(selectedLetters.join(""));
      }
    }
  }

  void _onBackspace() {
    if (selectedLetters.isNotEmpty) {
      setState(() {
        selectedLetters.removeLast();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Wrap(
          spacing: 8,
          children: List.generate(widget.correctWord.length, (i) {
            return Container(
              width: 40,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
              ),
              child: Text(
                i < selectedLetters.length ? selectedLetters[i] : "",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...options.map((letter) {
              return ElevatedButton(
                onPressed: () => _onLetterTap(letter),
                child: Text(letter),
              );
            }).toList(),
            ElevatedButton(
              onPressed: _onBackspace,
              child: const Icon(Icons.backspace),
            )
          ],
        )
      ],
    );
  }
}
