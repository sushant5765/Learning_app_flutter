// lib/screens/topic_selection.dart
import 'package:flutter/material.dart';
import '../services/ai_service.dart';

class TopicSelectionScreen extends StatefulWidget {
  final String uid;

  const TopicSelectionScreen({super.key, required this.uid});

  @override
  State<TopicSelectionScreen> createState() => _TopicSelectionScreenState();
}

class _TopicSelectionScreenState extends State<TopicSelectionScreen> {
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _lengthController = TextEditingController();
  bool _isGenerating = false;
  String _generatedPassage = '';

  final AiService _aiService = AiService();

  void _generatePassage() async {
    if (_topicController.text.isEmpty) return;

    setState(() => _isGenerating = true);

    try {
      final desiredLength =
          int.tryParse(_lengthController.text.trim()) ?? 100;
      final lengthLabel = desiredLength > 140 ? 'long' : 'short';
      final difficulty = desiredLength > 160
          ? 'advanced'
          : desiredLength > 110
              ? 'intermediate'
              : 'beginner';
      final response = await _aiService.generateReadingPassage(
        _topicController.text,
        lengthLabel,
        difficulty: difficulty,
      );
      setState(() => _generatedPassage = response);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error generating passage: $e")),
      );
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Generate AI Passage")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _topicController,
              decoration: const InputDecoration(
                labelText: 'Enter Topic',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lengthController,
              decoration: const InputDecoration(
                labelText: 'Word Count (optional)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isGenerating ? null : _generatePassage,
              child: _isGenerating
                  ? const CircularProgressIndicator()
                  : const Text('Generate Passage'),
            ),
            const SizedBox(height: 20),
            if (_generatedPassage.isNotEmpty) ...[
              Expanded(
                child: SingleChildScrollView(
                  child: Text(_generatedPassage),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, _generatedPassage);
                },
                child: const Text('Use This Passage'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}