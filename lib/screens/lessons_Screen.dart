import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'lesson_detail_screen.dart';

class LessonsScreen extends StatefulWidget {
  const LessonsScreen({super.key});

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  late Future<List<dynamic>> _lessonsF;

  @override
  void initState() {
    super.initState();
    _lessonsF = _loadLessons();
  }

  Future<List<dynamic>> _loadLessons() async {
    final raw = await rootBundle.loadString('assets/lessons.json');
    return json.decode(raw) as List<dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDE7), // warm cream
      appBar: AppBar(
        title: const Text('Lessons'),
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _lessonsF,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Failed to load lessons: ${snap.error}'));
          }
          final lessons = snap.data ?? [];
          if (lessons.isEmpty) {
            return const Center(child: Text('No lessons found.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lessons.length,
            itemBuilder: (context, i) {
              final l = lessons[i] as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  title: Text(
                    l['title'] as String,
                    style: const TextStyle(fontSize: 18, height: 1.3),
                  ),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LessonDetailScreen(
                          title: l['title'] as String,
                          content: l['content'] as String,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
