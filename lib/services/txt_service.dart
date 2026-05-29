import 'dart:io';

class TxtService {
  static Future<String> extractTextFromTXT(File file) async {
    return await file.readAsString();
  }
}
