import 'package:hive/hive.dart';

class LocalStorageService {
  static const String _userProfilesBoxName = 'user_profiles';
  static const String _readingSessionsBoxName = 'reading_sessions';
  static const String _writingSessionsBoxName = 'writing_sessions';
  static const String _vocabularySessionsBoxName = 'vocabulary_sessions';
  static const String _customWordsBoxName = 'custom_words';
  static const String _userDataBoxName = 'user_data';

  static late Box _userProfilesBox;
  static late Box _readingSessionsBox;
  static late Box _writingSessionsBox;
  static late Box _vocabularySessionsBox;
  static late Box _customWordsBox;
  static late Box _userDataBox;
  static late Box _performanceBox;

  static Future<void> initialize() async {
    _userProfilesBox = await Hive.openBox(_userProfilesBoxName);
    _readingSessionsBox = await Hive.openBox(_readingSessionsBoxName);
    _writingSessionsBox = await Hive.openBox(_writingSessionsBoxName);
    _vocabularySessionsBox = await Hive.openBox(_vocabularySessionsBoxName);
    _customWordsBox = await Hive.openBox(_customWordsBoxName);
    _userDataBox = await Hive.openBox(_userDataBoxName);
    _performanceBox = await Hive.openBox('performance_history');
  }

  // --- User Profiles -------------------------------------------------
  static Map<String, dynamic>? getUserProfile(String userId) {
    final raw = _userProfilesBox.get(userId);
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  static Future<void> saveUserProfile(String userId, Map<String, dynamic> data) async {
    await _userProfilesBox.put(userId, data);
  }

  static Iterable<Map<String, dynamic>> getAllUserProfiles() {
    return _userProfilesBox.values
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e));
  }

  static Iterable<Map<String, dynamic>> getAllUserProfilesSync() {
    return getAllUserProfiles();
  }

  // --- Reading Sessions ---------------------------------------------
  static Future<void> saveReadingSession(
    String userId, {
    required double wpm,
    required double accuracy,
    required List<String> misreadWords,
  }) async {
    final session = {
      'wpm': wpm,
      'accuracy': accuracy,
      'misreadWords': misreadWords,
      'timestamp': DateTime.now().toIso8601String(),
    };
    final sessions = _getSessionList(_readingSessionsBox, userId);
    sessions.add(session);
    await _readingSessionsBox.put(userId, sessions);
  }

  static List<Map<String, dynamic>> getReadingSessions(String userId) {
    return _getSessionList(_readingSessionsBox, userId);
  }

  static Future<void> saveReadingData(String userId, Map<String, dynamic> data) async {
    final userData = _getUserData(userId);
    userData['readingData'] = data;
    await _userDataBox.put(userId, userData);
  }

  static Map<String, dynamic> getReadingData(String userId) {
    final userData = _getUserData(userId);
    final raw = userData['readingData'];
    if (raw is Map) {
      return Map<String, dynamic>.from(raw as Map);
    }
    return {
      'streak': 0,
      'totalSessions': 0,
      'perfectReadings': 0,
      'badges': <String>[],
    };
  }

  // --- Writing Sessions ---------------------------------------------
  static Future<void> saveWritingSession(
    String userId, {
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
    final session = {
      'prompt': prompt,
      'userResponse': userResponse,
      'correctedText': correctedText ?? userResponse,
      'spellingErrors': spellingErrors,
      'grammarErrors': grammarErrors,
      'punctuationErrors': punctuationErrors,
      'accessibilitySettings': accessibilitySettings,
      'wordCount': wordCount,
      'sentenceCount': sentenceCount,
      'timestamp': DateTime.now().toIso8601String(),
    };
    final sessions = _getSessionList(_writingSessionsBox, userId);
    sessions.add(session);
    await _writingSessionsBox.put(userId, sessions);
  }

  static List<Map<String, dynamic>> getWritingSessions(String userId) {
    return _getSessionList(_writingSessionsBox, userId);
  }

  static Future<void> saveWritingProgress(String userId, Map<String, dynamic> data) async {
    final userData = _getUserData(userId);
    userData['writingProgress'] = data;
    await _userDataBox.put(userId, userData);
  }

  static Map<String, dynamic> getWritingProgress(String userId) {
    final userData = _getUserData(userId);
    final raw = userData['writingProgress'];
    if (raw is Map) {
      return Map<String, dynamic>.from(raw as Map);
    }
    return {
      'writingStreak': 0,
      'badges': <String>[],
      'totalWritingExercises': 0,
    };
  }

  // --- Vocabulary Sessions -----------------------------------------
  static Future<void> saveVocabularySession(
    String userId, {
    required List<Map<String, dynamic>> words,
    String sessionType = 'practice',
  }) async {
    final formattedWords = words
        .map((word) => Map<String, dynamic>.from(word))
        .toList(growable: false);

    final session = {
      'words': formattedWords,
      'timestamp': DateTime.now().toIso8601String(),
      'sessionType': sessionType,
    };

    final sessions = _getSessionList(_vocabularySessionsBox, userId);
    sessions.add(session);
    await _vocabularySessionsBox.put(userId, sessions);
  }

  static List<Map<String, dynamic>> getVocabularySessions(String userId) {
    return _getSessionList(_vocabularySessionsBox, userId).reversed.toList();
  }

  // --- Custom Words -------------------------------------------------
  static Future<void> addCustomWord(String userId, String word) async {
    final words = _getCustomWordList(userId);
    if (!words.contains(word)) {
      words.add(word);
      await _customWordsBox.put(userId, words);
    }
  }

  static Future<void> deleteCustomWord(String userId, String word) async {
    final words = _getCustomWordList(userId);
    words.remove(word);
    await _customWordsBox.put(userId, words);
  }

  static List<String> getCustomWords(String userId) {
    return _getCustomWordList(userId);
  }

  // --- Preferences / Misc ------------------------------------------
  static Future<void> saveUserPreferences(String userId, Map<String, dynamic> preferences) async {
    final userData = _getUserData(userId);
    userData['preferences'] = preferences;
    await _userDataBox.put(userId, userData);
  }

  static Map<String, dynamic>? getUserPreferences(String userId) {
    final userData = _getUserData(userId);
    final raw = userData['preferences'];
    if (raw is Map) {
      return Map<String, dynamic>.from(raw as Map);
    }
    return null;
  }

  // --- Performance records -----------------------------------------
  static Future<void> savePerformanceRecord(String userId, Map<String, dynamic> data) async {
    final records = _getSessionList(_performanceBox, userId);
    records.add({
      ...data,
      'timestamp': DateTime.now().toIso8601String(),
    });
    await _performanceBox.put(userId, records);
  }

  static List<Map<String, dynamic>> getPerformanceRecords(String userId) {
    return _getSessionList(_performanceBox, userId);
  }

  // --- Helpers ------------------------------------------------------
  static List<Map<String, dynamic>> _getSessionList(Box box, String userId) {
    final raw = box.get(userId);
    final rawList = raw is List ? raw : <dynamic>[];
    return rawList
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static List<String> _getCustomWordList(String userId) {
    final rawList = _customWordsBox.get(userId, defaultValue: <dynamic>[]) as List;
    return rawList.map((e) => e.toString()).toList();
  }

  static Map<String, dynamic> _getUserData(String userId) {
    final raw = _userDataBox.get(userId);
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
  }
}
