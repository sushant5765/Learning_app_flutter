// lib/services/hive_store.dart

import 'local_storage_service.dart';

class HiveService {
  final String uid;

  HiveService(this.uid);

  Future<void> saveReadingResult({
    required double wpm,
    required double accuracy,
    required List<String> misreadWords,
  }) async {
    if (uid.isEmpty) {
      print('⚠️ ERROR: Cannot save reading result - UID is empty!');
      return;
    }
    print('✅ Saving reading result for user: $uid');
    await LocalStorageService.saveReadingSession(
      uid,
      wpm: wpm,
      accuracy: accuracy,
      misreadWords: misreadWords,
    );
    print('✅ Reading result saved successfully');
  }

  Future<void> updateUserReadingData({
    required int streak,
    required int totalSessions,
    required int perfectReadings,
    required List<String> badges,
  }) async {
    await LocalStorageService.saveReadingData(uid, {
      'streak': streak,
      'totalSessions': totalSessions,
      'perfectReadings': perfectReadings,
      'badges': badges,
      'lastPracticeDate': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>> getUserReadingData() async {
    return LocalStorageService.getReadingData(uid);
  }

  Future<List<Map<String, dynamic>>> getReadingResults() async {
    if (uid.isEmpty) {
      print('⚠️ ERROR: Cannot get reading results - UID is empty!');
      return [];
    }
    print('✅ Fetching reading results for user: $uid');
    final results = LocalStorageService.getReadingSessions(uid);
    print('✅ Found ${results.length} reading sessions');
    return results;
  }

  Future<void> saveWritingResult({
    required String prompt,
    required String userResponse,
    required int spellingErrors,
    required int grammarErrors,
    required int punctuationErrors,
    required Map<String, dynamic> accessibilitySettings,
    required int wordCount,
    required int sentenceCount,
    String? correctedText,
  }) async {
    if (uid.isEmpty) {
      print('⚠️ ERROR: Cannot save writing result - UID is empty!');
      return;
    }
    print('✅ Saving writing result for user: $uid');
    await LocalStorageService.saveWritingSession(
      uid,
      prompt: prompt,
      userResponse: userResponse,
      spellingErrors: spellingErrors,
      grammarErrors: grammarErrors,
      punctuationErrors: punctuationErrors,
      accessibilitySettings: accessibilitySettings,
      wordCount: wordCount,
      sentenceCount: sentenceCount,
      correctedText: correctedText,
    );
    print('✅ Writing result saved successfully');
  }

  Future<void> updateUserProgress({
    required int streak,
    required List<String> badges,
    required int totalExercises,
  }) async {
    await LocalStorageService.saveWritingProgress(uid, {
      'writingStreak': streak,
      'badges': badges,
      'totalWritingExercises': totalExercises,
      'lastPracticeDate': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> getUserPreferences() async {
    return LocalStorageService.getUserPreferences(uid);
  }

  Future<void> saveUserPreferences(Map<String, dynamic> preferences) async {
    await LocalStorageService.saveUserPreferences(uid, preferences);
  }

  Future<List<Map<String, dynamic>>> getWritingResults() async {
    if (uid.isEmpty) {
      print('⚠️ ERROR: Cannot get writing results - UID is empty!');
      return [];
    }
    print('✅ Fetching writing results for user: $uid');
    final results = LocalStorageService.getWritingSessions(uid);
    print('✅ Found ${results.length} writing sessions');
    return results;
  }

  Future<void> saveVocabularyResult({
    required List<Map<String, dynamic>> words,
  }) async {
    if (uid.isEmpty) {
      print('⚠️ ERROR: Cannot save vocabulary result - UID is empty!');
      return;
    }
    print('✅ Saving vocabulary result for user: $uid');
    await LocalStorageService.saveVocabularySession(uid, words: words);
    print('✅ Vocabulary result saved successfully');
  }

  Future<List<Map<String, dynamic>>> getVocabularyResults() async {
    if (uid.isEmpty) {
      print('⚠️ ERROR: Cannot get vocabulary results - UID is empty!');
      return [];
    }
    print('✅ Fetching vocabulary results for user: $uid');
    final results = LocalStorageService.getVocabularySessions(uid);
    print('✅ Found ${results.length} vocabulary sessions');
    return results;
  }

  Future<List<String>> getCustomVocabularyWords() async {
    return LocalStorageService.getCustomWords(uid);
  }

  Future<void> addCustomWord(String word) async {
    await LocalStorageService.addCustomWord(uid, word);
  }

  Future<void> deleteCustomWord(String word) async {
    await LocalStorageService.deleteCustomWord(uid, word);
  }
}
