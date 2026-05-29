import 'dart:io';
import 'package:flutter/foundation.dart';
import 'tflite_model_service.dart';

/// Service to call AI models for summarization and Q&A
/// Uses TFLite models on mobile (iOS/Android) and Python scripts on desktop
class AiModelService {
  static const bool _useModels = true; // Enable trained models
  static bool _tfliteInitialized = false;
  
  /// Get the project root directory by finding pubspec.yaml
  static String? _findProjectRoot() {
    // Start from current directory
    Directory current = Directory.current;
    
    // Try current directory
    if (File('${current.path}/pubspec.yaml').existsSync()) {
      return current.path;
    }
    
    // Try parent directories (up to 5 levels)
    Directory? checkDir = current;
    for (int i = 0; i < 5; i++) {
      checkDir = checkDir?.parent;
      if (checkDir == null) break;
      if (File('${checkDir.path}/pubspec.yaml').existsSync()) {
        return checkDir.path;
      }
    }
    
    // Fallback: try absolute path from common locations
    final commonPaths = [
      '/Users/sanjay/Downloads/Learning_app',
      '${current.path}/Learning_app',
      current.path,
    ];
    
    for (final path in commonPaths) {
      if (File('$path/pubspec.yaml').existsSync()) {
        return path;
      }
    }
    
    return null;
  }
  
  /// Summarize text using trained model with fallback to local NLP
  /// On iOS/Android: Uses TFLite models
  /// On Desktop: Uses Python inference scripts
  static Future<String> summarizeWithModel(String text) async {
    if (!_useModels) {
      return ""; // Empty string means use fallback
    }
    
    // Try TFLite models first (works on iOS and Android)
    if (Platform.isIOS || Platform.isAndroid) {
      if (!_tfliteInitialized) {
        _tfliteInitialized = await TfliteModelService.initialize();
      }
      
      if (_tfliteInitialized) {
        final result = await TfliteModelService.summarize(text);
        if (result.isNotEmpty) {
          debugPrint('✅ TFLite summarization successful');
          return result;
        }
      }
      
      debugPrint('TFLite model not available, using local NLP fallback');
      return ""; // Fallback to local NLP
    }
    
    try {
      // Find project root
      final projectRoot = _findProjectRoot();
      if (projectRoot == null) {
        debugPrint('Could not find project root. Using local NLP fallback.');
        return ""; // Fallback to local NLP
      }
      
      final scriptPath = '$projectRoot/AI/scripts/inference_summarizer.py';
      
      if (!File(scriptPath).existsSync()) {
        debugPrint('Inference script not found at: $scriptPath');
        debugPrint('Current directory: ${Directory.current.path}');
        return ""; // Fallback to local NLP
      }
      
      debugPrint('✅ Found inference script: $scriptPath');
      debugPrint('📁 Project root: $projectRoot');

      // trim the input
      // Limit text length for model (models expect max 200 words)
      final words = text.split(' ');
      final limitedText = words.length > 200 ? words.take(200).join(' ') : text;
      
      final result = await Process.run(
        'python3',
        [scriptPath, limitedText],
        runInShell: false,
        workingDirectory: projectRoot,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Model inference timeout');
        },
      );
      
      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        if (output.isNotEmpty && !output.contains('Error') && !output.contains('Unable')) {
          debugPrint('✅ Model summarization successful');
          return output;
        } else {
          debugPrint('⚠️ Model output empty or contains errors: $output');
        }
      } else {
        debugPrint('❌ Model inference failed with exit code ${result.exitCode}');
        debugPrint('Error: ${result.stderr}');
      }
      
      return ""; // Fallback to local NLP
    } catch (e) {
      debugPrint('Model inference error: $e');
      return ""; // Fallback to local NLP
    }
  }
  
  /// Answer question using trained Q&A model with fallback to local NLP
  /// On iOS/Android: Uses TFLite models
  /// On Desktop: Uses Python inference scripts
  static Future<String> answerWithModel(String question, String context) async {
    if (!_useModels) {
      return ""; // Empty string means use fallback
    }
    
    // Try TFLite models first (works on iOS and Android)
    if (Platform.isIOS || Platform.isAndroid) {
      if (!_tfliteInitialized) {
        _tfliteInitialized = await TfliteModelService.initialize();
      }
      
      if (_tfliteInitialized) {
        final result = await TfliteModelService.answerQuestion(question, context);
        if (result.isNotEmpty) {
          debugPrint('✅ TFLite Q&A successful');
          return result;
        }
      }
      
      debugPrint('TFLite model not available, using local NLP fallback');
      return ""; // Fallback to local NLP
    }
    
    try {
      // Find project root
      final projectRoot = _findProjectRoot();
      if (projectRoot == null) {
        debugPrint('Could not find project root. Using local NLP fallback.');
        return ""; // Fallback to local NLP
      }
      
      final scriptPath = '$projectRoot/AI/scripts/inference_qa.py';
      
      if (!File(scriptPath).existsSync()) {
        debugPrint('Q&A inference script not found at: $scriptPath');
        debugPrint('Current directory: ${Directory.current.path}');
        return ""; // Fallback to local NLP
      }
      
      debugPrint('✅ Found Q&A inference script: $scriptPath');
      debugPrint('📁 Project root: $projectRoot');
      
      // Limit context length (models expect max 200 words)
      final contextWords = context.split(' ');
      final limitedContext = contextWords.length > 200 
          ? contextWords.take(200).join(' ') 
          : context;
      
      final result = await Process.run(
        'python3',
        [scriptPath, question, limitedContext],
        runInShell: false,
        workingDirectory: projectRoot,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Q&A model inference timeout');
        },
      );
      
      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        if (output.isNotEmpty && !output.contains('Error') && !output.contains('Unable')) {
          debugPrint('✅ Model Q&A successful');
          return output;
        } else {
          debugPrint('⚠️ Model Q&A output empty or contains errors: $output');
        }
      } else {
        debugPrint('❌ Q&A model inference failed with exit code ${result.exitCode}');
        debugPrint('Error: ${result.stderr}');
      }
      
      return ""; // Fallback to local NLP
    } catch (e) {
      debugPrint('Q&A model inference error: $e');
      return ""; // Fallback to local NLP
    }
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
}

