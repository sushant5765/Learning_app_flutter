// lib/screens/session_summary_screen.dart
import 'package:flutter/material.dart';

class SessionSummaryScreen extends StatelessWidget {
  final int points;
  final int correct;
  final int incorrect;
  final List<String> badges;
  final VoidCallback onClose;

  const SessionSummaryScreen({
    Key? key,
    required this.points,
    required this.correct,
    required this.incorrect,
    required this.badges,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🎉 Session Summary")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Points: $points", style: const TextStyle(fontSize: 20)),
            Text("Correct: $correct", style: const TextStyle(fontSize: 20)),
            Text("Incorrect: $incorrect", style: const TextStyle(fontSize: 20)),
            if (badges.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text("Badges Earned:", style: TextStyle(fontSize: 18)),
              Wrap(
                spacing: 8,
                children: badges
                    .map((b) => Chip(
                  label: Text(b),
                  backgroundColor: Colors.amberAccent,
                ))
                    .toList(),
              )
            ],
            const SizedBox(height: 30),
            ElevatedButton(onPressed: onClose, child: const Text("Close"))
          ],
        ),
      ),
    );
  }
}
