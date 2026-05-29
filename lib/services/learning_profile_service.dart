import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class LearningProfileService {
  LearningProfileService._();

  static final LearningProfileService instance = LearningProfileService._();

  static const _readingScoreKey = 'learning_profile_reading_score';
  static const _vocabScoreKey = 'learning_profile_vocab_score';
  static const _writingScoreKey = 'learning_profile_writing_score';
  
  // Adaptive learning tracking keys
  static const _readingAdaptiveEnabledKey = 'reading_adaptive_enabled';
  static const _vocabAdaptiveEnabledKey = 'vocab_adaptive_enabled';
  static const _readingConsecutiveSuccessKey = 'reading_consecutive_success';
  static const _vocabConsecutiveSuccessKey = 'vocab_consecutive_success';
  static const _readingCurrentLevelKey = 'reading_current_level';
  static const _vocabCurrentLevelKey = 'vocab_current_level';
  
  // Thresholds for automatic level progression
  static const int _readingSuccessThreshold = 3; // 3 consecutive good sessions
  static const int _vocabSuccessThreshold = 5; // 5 consecutive correct answers
  static const double _readingMinAccuracy = 85.0;
  static const double _readingMinWpm = 80.0;

  Future<String> recommendedReadingLevel() async {
    final score = await _getScore(_readingScoreKey);
    if (score < 0.35) return 'beginner';
    if (score < 0.7) return 'intermediate';
    return 'advanced';
  }

  Future<void> updateReadingSession({
    required double accuracy,
    required double wordsPerMinute,
  }) async {
    final score = _readingCompositeScore(accuracy, wordsPerMinute);
    await _updateScore(_readingScoreKey, score);
    
    // Track consecutive successes for adaptive learning
    final prefs = await SharedPreferences.getInstance();
    final adaptiveEnabled = prefs.getBool(_readingAdaptiveEnabledKey) ?? true;
    
    if (adaptiveEnabled && accuracy >= _readingMinAccuracy && wordsPerMinute >= _readingMinWpm) {
      final currentSuccess = prefs.getInt(_readingConsecutiveSuccessKey) ?? 0;
      await prefs.setInt(_readingConsecutiveSuccessKey, currentSuccess + 1);
    } else {
      // Reset on poor performance
      await prefs.setInt(_readingConsecutiveSuccessKey, 0);
    }
  }

  /// Check if reading level should automatically progress
  Future<bool> shouldProgressReadingLevel(String currentLevel) async {
    final prefs = await SharedPreferences.getInstance();
    final adaptiveEnabled = prefs.getBool(_readingAdaptiveEnabledKey) ?? true;
    
    if (!adaptiveEnabled) return false;
    
    final consecutiveSuccess = prefs.getInt(_readingConsecutiveSuccessKey) ?? 0;
    
    if (currentLevel == 'beginner' && consecutiveSuccess >= _readingSuccessThreshold) {
      return true;
    } else if (currentLevel == 'intermediate' && consecutiveSuccess >= _readingSuccessThreshold) {
      return true;
    }
    
    return false;
  }

  /// Get next level for reading
  String getNextReadingLevel(String currentLevel) {
    switch (currentLevel.toLowerCase()) {
      case 'beginner':
        return 'intermediate';
      case 'intermediate':
        return 'advanced';
      default:
        return currentLevel;
    }
  }

  /// Progress reading level and reset counter
  Future<void> progressReadingLevel() async {
    final prefs = await SharedPreferences.getInstance();
    final currentLevel = prefs.getString(_readingCurrentLevelKey) ?? 'beginner';
    final nextLevel = getNextReadingLevel(currentLevel);
    await prefs.setString(_readingCurrentLevelKey, nextLevel);
    await prefs.setInt(_readingConsecutiveSuccessKey, 0); // Reset counter
  }

  /// Enable/disable adaptive learning for reading
  Future<void> setReadingAdaptiveEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_readingAdaptiveEnabledKey, enabled);
    if (!enabled) {
      await prefs.setInt(_readingConsecutiveSuccessKey, 0);
    }
  }

  /// Check if adaptive learning is enabled for reading
  Future<bool> isReadingAdaptiveEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_readingAdaptiveEnabledKey) ?? true;
  }

  /// Get current reading level (for adaptive learning)
  Future<String> getCurrentReadingLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_readingCurrentLevelKey) ?? 'beginner';
  }

  /// Set current reading level (when manually changed, disables adaptive)
  Future<void> setCurrentReadingLevel(String level, {bool isManual = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_readingCurrentLevelKey, level);
    if (isManual) {

      await prefs.setInt(_readingConsecutiveSuccessKey, 0);
    }
  }

  Future<String> recommendedVocabularyDifficulty() async {
    final score = await _getScore(_vocabScoreKey);
    if (score < 0.4) return 'easy';
    if (score < 0.75) return 'medium';
    return 'hard';
  }

  Future<void> updateVocabularySession({
    required int totalAttempts,
    required int correctAttempts,
  }) async {
    final ratio =
        totalAttempts == 0 ? 0.0 : correctAttempts / totalAttempts.toDouble();
    await _updateScore(_vocabScoreKey, ratio);
    
    // Track consecutive successes for adaptive learning
    final prefs = await SharedPreferences.getInstance();
    final adaptiveEnabled = prefs.getBool(_vocabAdaptiveEnabledKey) ?? true;
    
    if (adaptiveEnabled && correctAttempts == totalAttempts && totalAttempts > 0) {
      final currentSuccess = prefs.getInt(_vocabConsecutiveSuccessKey) ?? 0;
      await prefs.setInt(_vocabConsecutiveSuccessKey, currentSuccess + correctAttempts);
    } else {
      // Reset on incorrect answer
      await prefs.setInt(_vocabConsecutiveSuccessKey, 0);
    }
  }

  /// Check if vocabulary level should automatically progress
  Future<bool> shouldProgressVocabLevel(String currentLevel) async {
    final prefs = await SharedPreferences.getInstance();
    final adaptiveEnabled = prefs.getBool(_vocabAdaptiveEnabledKey) ?? true;
    
    if (!adaptiveEnabled) return false;
    
    final consecutiveSuccess = prefs.getInt(_vocabConsecutiveSuccessKey) ?? 0;
    
    if (currentLevel.toLowerCase() == 'easy' && consecutiveSuccess >= _vocabSuccessThreshold) {
      return true;
    } else if (currentLevel.toLowerCase() == 'medium' && consecutiveSuccess >= _vocabSuccessThreshold) {
      return true;
    }
    
    return false;
  }

  /// Get next level for vocabulary
  String getNextVocabLevel(String currentLevel) {
    switch (currentLevel.toLowerCase()) {
      case 'easy':
        return 'medium';
      case 'medium':
        return 'hard';
      default:
        return currentLevel;
    }
  }

  /// Progress vocabulary level and reset counter
  Future<void> progressVocabLevel() async {
    final prefs = await SharedPreferences.getInstance();
    final currentLevel = prefs.getString(_vocabCurrentLevelKey) ?? 'easy';
    final nextLevel = getNextVocabLevel(currentLevel);
    await prefs.setString(_vocabCurrentLevelKey, nextLevel);
    await prefs.setInt(_vocabConsecutiveSuccessKey, 0); // Reset counter
  }

  /// Enable/disable adaptive learning for vocabulary
  Future<void> setVocabAdaptiveEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vocabAdaptiveEnabledKey, enabled);
    if (!enabled) {
      await prefs.setInt(_vocabConsecutiveSuccessKey, 0);
    }
  }

  /// Check if adaptive learning is enabled for vocabulary
  Future<bool> isVocabAdaptiveEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_vocabAdaptiveEnabledKey) ?? true;
  }

  /// Get current vocabulary level (for adaptive learning)
  Future<String> getCurrentVocabLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_vocabCurrentLevelKey) ?? 'easy';
  }

  /// Set current vocabulary level (when manually changed, disables adaptive)
  Future<void> setCurrentVocabLevel(String level, {bool isManual = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_vocabCurrentLevelKey, level);
    if (isManual) {
      await prefs.setBool(_vocabAdaptiveEnabledKey, false);
      await prefs.setInt(_vocabConsecutiveSuccessKey, 0);
    }
  }

  Future<void> updateWritingQuality(double qualityScore) async {
    await _updateScore(_writingScoreKey, qualityScore);
  }

  Future<double> _getScore(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(key) ?? 0.4;
  }

  Future<void> _updateScore(String key, double newScore) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getDouble(key) ?? 0.4;
    // Exponential moving average to smooth progress.
    final updated = (current * 0.6) + (newScore * 0.4);
    await prefs.setDouble(key, updated.clamp(0, 1));
  }

  double _readingCompositeScore(double accuracy, double wpm) {
    final accuracyScore = accuracy / 100.0;
    final speedScore = wpm / 130.0; // Reasonable upper bound.
    return min(1.0, (accuracyScore * 0.7) + (speedScore * 0.3));    // accuracy imp than speed
  }
}

