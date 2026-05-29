// lib/screens/document_history_screen.dart
import 'package:flutter/material.dart';
import 'document_scan_screen.dart';
import '../models/document_history.dart';
import '../services/history_service.dart';

class DocumentHistoryScreen extends StatefulWidget {
  const DocumentHistoryScreen({super.key});

  @override
  State<DocumentHistoryScreen> createState() => _DocumentHistoryScreenState();
}

class _DocumentHistoryScreenState extends State<DocumentHistoryScreen> {
  final HistoryService _historyService = HistoryService();
  List<DocumentHistory> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final history = await _historyService.getDocumentHistory();
      setState(() => _history = history);
    } catch (e) {
      print('Error loading history: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _viewDocument(DocumentHistory history) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentLessonScreen.fromHistory(history: history),
      ),
    );
  }

  Future<void> _deleteDocument(DocumentHistory history) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text('Are you sure you want to delete this document?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _historyService.deleteDocumentHistory(history.id);
      await _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document History'),
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
          ? const Center(
        child: Text(
          'No document history yet',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _history.length,
        itemBuilder: (context, index) {
          final history = _history[index];
          return _HistoryItem(
            history: history,
            onTap: () => _viewDocument(history),
            onDelete: () => _deleteDocument(history),
          );
        },
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final DocumentHistory history;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryItem({
    required this.history,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          history.title.isEmpty ? 'Untitled Document' : history.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              history.summary.length > 150
                  ? '${history.summary.substring(0, 150)}...'
                  : history.summary,
              style: const TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              'Created: ${_formatDate(history.createdAt)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: onDelete,
        ),
        onTap: onTap,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}