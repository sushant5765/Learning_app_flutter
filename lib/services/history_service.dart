// lib/services/history_service.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../models/document_history.dart';

class HistoryService {
  static const String _historyKey = 'document_history';

  Future<void> saveDocumentHistory(DocumentHistory history) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> historyList = prefs.getStringList(_historyKey) ?? [];

    // Remove existing entry with same ID to avoid duplicates
    historyList.removeWhere((item) {
      final map = json.decode(item);
      return map['id'] == history.id;
    });

    // Add new entry at the beginning
    historyList.insert(0, json.encode(history.toMap()));

    // Keep only last 50 items to prevent storage issues
    if (historyList.length > 50) {
      historyList.removeLast();
    }

    await prefs.setStringList(_historyKey, historyList);
  }

  Future<List<DocumentHistory>> getDocumentHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> historyList = prefs.getStringList(_historyKey) ?? [];

    return historyList.map((item) {
      try {
        return DocumentHistory.fromMap(json.decode(item));
      } catch (e) {
        return null;
      }
    }).whereType<DocumentHistory>().toList();
  }

  Future<void> deleteDocumentHistory(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> historyList = prefs.getStringList(_historyKey) ?? [];

    historyList.removeWhere((item) {
      final map = json.decode(item);
      return map['id'] == id;
    });

    await prefs.setStringList(_historyKey, historyList);
  }
}