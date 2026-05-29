// lib/screens/passage_generation_screen.dart
import 'package:flutter/material.dart';
import 'reading_practice.dart';
import '../services/reading_content_service.dart';

class PassageGenerationScreen extends StatefulWidget {
  final String uid;

  const PassageGenerationScreen({super.key, required this.uid});

  @override
  State<PassageGenerationScreen> createState() => _PassageGenerationScreenState();
}

class _PassageGenerationScreenState extends State<PassageGenerationScreen> {
  final _topicController = TextEditingController();
  String _selectedLength = 'short';
  bool _isGenerating = false;
  String? _selectedTopicChip;

  final List<String> _suggestedTopics = const [
    "Space exploration",
    "Ocean animals",
    "Ancient Egypt",
    "Mindful breathing",
    "Renewable energy",
    "Friendship",
  ];

  void _generatePassage() async {
    if (_topicController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a topic")),
      );
      return;
    }

    setState(() => _isGenerating = true);

    final longForm = _selectedLength == 'long';
    final passage = ReadingContentService.generatePassage(
      topic: _topicController.text,
      level: longForm ? 'intermediate' : 'beginner',
      longForm: longForm,
    );

    if (!mounted) return;

    setState(() => _isGenerating = false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReadingPracticeScreen(
          uid: widget.uid,
          practiceText: passage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0), // Calm, soft background
      appBar: AppBar(
        title: const Text(
          "Generate Reading Passage",
          style: TextStyle(
            fontFamily: "Lexend",
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748), // Dark text
          ),
        ),
        backgroundColor: const Color(0xFFF5F5F0),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "What would you like to read about?",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: "Lexend",
                color: Color(0xFF2D3748), // Dark text
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _topicController,
              onChanged: (_) => setState(() => _selectedTopicChip = null),
              style: const TextStyle(
                fontSize: 20,
                fontFamily: "Lexend",
                color: Color(0xFF2D3748),
              ),
              decoration: InputDecoration(
                hintText: "e.g., Space exploration, Ocean animals, Ancient Egypt",
                hintStyle: TextStyle(
                  fontSize: 18,
                  fontFamily: "Lexend",
                  color: Colors.grey[600],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 3),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Suggested Topics:",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: "Lexend",
                color: Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _suggestedTopics.map((topic) {
                final selected = _selectedTopicChip == topic;
                return ChoiceChip(
                  label: Text(
                    topic,
                    style: TextStyle(
                      fontFamily: "Lexend",
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : const Color(0xFF2D3748),
                      letterSpacing: 0.5,
                    ),
                  ),
                  selected: selected,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        _selectedTopicChip = topic;
                        _topicController.text = topic;
                      } else {
                        _selectedTopicChip = null;
                      }
                    });
                  },
                  backgroundColor: const Color(0xFFE8F5E9), // Calm light green
                  selectedColor: const Color(0xFF4CAF50), // Bright green when selected
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  side: BorderSide(
                    color: selected ? const Color(0xFF2E7D32) : const Color(0xFF81C784),
                    width: 2,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            const Text(
              "Passage length:",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: "Lexend",
                color: Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 60,
                    child: ChoiceChip(
                      label: const Text(
                        "Short",
                        style: TextStyle(
                          fontFamily: "Lexend",
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      selected: _selectedLength == 'short',
                      onSelected: (selected) {
                        setState(() => _selectedLength = 'short');
                      },
                      backgroundColor: const Color(0xFFE8F5E9),
                      selectedColor: const Color(0xFF4CAF50),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      side: BorderSide(
                        color: _selectedLength == 'short'
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFF81C784),
                        width: 3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 60,
                    child: ChoiceChip(
                      label: const Text(
                        "Long",
                        style: TextStyle(
                          fontFamily: "Lexend",
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      selected: _selectedLength == 'long',
                      onSelected: (selected) {
                        setState(() => _selectedLength = 'long');
                      },
                      backgroundColor: const Color(0xFFE8F5E9),
                      selectedColor: const Color(0xFF4CAF50),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      side: BorderSide(
                        color: _selectedLength == 'long'
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFF81C784),
                        width: 3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 70,
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _generatePassage,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  backgroundColor: const Color(0xFF4CAF50), // Bright green button
                  foregroundColor: Colors.white, // White text on bright button
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: Color(0xFF2E7D32), width: 3),
                  ),
                  elevation: 4,
                ),
                child: _isGenerating
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  "Generate Passage",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: "Lexend",
                    color: Colors.white, // Dark text on bright button
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }
}