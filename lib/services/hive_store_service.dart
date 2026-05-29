import 'local_storage_service.dart';

class LocalService {
  static Future<void> savePerformance({
    required String userId,
    required double accuracy,
    required double timeSpent,
    required int mistakes,
    required double fluencyScore,
    required String simplifiedText,
    int points = 0,
  }) async {
    await LocalStorageService.savePerformanceRecord(userId, {
      'accuracy': accuracy,
      'timeSpent': timeSpent,
      'mistakes': mistakes,
      'fluencyScore': fluencyScore,
      'simplifiedTextSnippet': _snippet(simplifiedText),
      'points': points,
    });
  }

  static String _snippet(String text, {int maxLen = 200}) {
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen)}…';
  }
}
