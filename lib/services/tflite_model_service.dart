import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:typed_data';

/// Service to run TFLite models for summarization and Q&A
/// Works on both iOS and Android
class TfliteModelService {
  static Interpreter? _summarizerInterpreter;
  static Interpreter? _qaInterpreter;
  static Map<String, int>? _wordToIdx;
  static Map<int, String>? _idxToWord;
  static bool _initialized = false;

  /// Initialize TFLite models and vocabulary
  static Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      // Load vocabulary
      await _loadVocabulary();


      // Try to load TFLite models
      // Note: Models need to be in assets folder
      try {
        _summarizerInterpreter = await _loadModel('assets/models/summarizer_model.tflite');
        if (_summarizerInterpreter != null) {
          debugPrint('✅ Summarizer model loaded');
        } else {
          debugPrint('⚠️ Summarizer model not loaded');
        }
        
        _qaInterpreter = await _loadModel('assets/models/qa_model.tflite');
        if (_qaInterpreter != null) {
          debugPrint('✅ Q&A model loaded');
        } else {
          debugPrint('⚠️ Q&A model not loaded');
        }
        
        if (_summarizerInterpreter != null && _qaInterpreter != null) {
          debugPrint('✅ TFLite models loaded successfully');
          _initialized = true;
          return true;
        } else {
          debugPrint('⚠️ Some models failed to load, using local NLP fallback');
        }
      } catch (e) {
        debugPrint('⚠️ TFLite model loading error: $e');
        debugPrint('Using local NLP fallback');
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error initializing TFLite models: $e');
      return false;
    }
  }

  /// Load vocabulary from assets
  static Future<void> _loadVocabulary() async {
    try {
      final vocabData = await rootBundle.loadString('assets/models/vocabulary.json');
      final vocabMap = json.decode(vocabData) as Map<String, dynamic>;
      _wordToIdx = vocabMap.map((key, value) => MapEntry(key, value as int));
      _idxToWord = _wordToIdx!.map((key, value) => MapEntry(value, key));
      debugPrint('✅ Vocabulary loaded: ${_wordToIdx!.length} words');
    } catch (e) {
      debugPrint('⚠️ Could not load vocabulary: $e');
      // Create minimal vocabulary
      _wordToIdx = {'<PAD>': 0, '<UNK>': 1};
      _idxToWord = {0: '<PAD>', 1: '<UNK>'};
    }
  }

  /// Load TFLite model from assets
  /// Simplified version that works reliably on Android
  static Future<Interpreter?> _loadModel(String assetPath) async {
    try {
      debugPrint('📦 Loading model: $assetPath');
      final modelData = await rootBundle.load(assetPath);
      final modelBytes = modelData.buffer.asUint8List();
      final modelSizeMB = modelBytes.length / 1024 / 1024;
      debugPrint('📦 Model loaded: ${modelSizeMB.toStringAsFixed(2)} MB');
      
      // Validate model buffer
      if (modelBytes.isEmpty) {
        debugPrint('❌ Model buffer is empty');
        return null;
      }
      
      // Create interpreter from buffer (works reliably on Android)
      try {
        final interpreter = Interpreter.fromBuffer(modelBytes);
        
        // Validate interpreter by checking tensor info
        final inputTensors = interpreter.getInputTensors();
        final outputTensors = interpreter.getOutputTensors();
        debugPrint('✅ Interpreter created: ${inputTensors.length} inputs, ${outputTensors.length} outputs');
        if (inputTensors.isNotEmpty) {
          debugPrint('   Input shape: ${inputTensors[0].shape}');
        }
        if (outputTensors.isNotEmpty) {
          debugPrint('   Output shape: ${outputTensors[0].shape}');
        }
        return interpreter;
      } catch (e, stackTrace) {
        debugPrint('❌ Failed to create interpreter: $e');
        debugPrint('   Error details: $stackTrace');
        debugPrint('   Models will use local NLP fallback');
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Could not load model from $assetPath: $e');
      debugPrint('Error type: ${e.runtimeType}');
      return null;
    }
  }

  /// Convert text to sequence of indices
  static List<int> _textToSequence(String text, int maxLen) {
    if (_wordToIdx == null) return List.filled(maxLen, 0);
    
    final words = text.toLowerCase().split(RegExp(r'\s+'));
    final sequence = <int>[];
    
    for (final word in words) {
      final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '');
      if (cleanWord.isEmpty) continue;
      final idx = _wordToIdx![cleanWord] ?? _wordToIdx!['<UNK>'] ?? 1;
      sequence.add(idx);
      if (sequence.length >= maxLen) break;
    }
    
    // Pad to maxLen
    while (sequence.length < maxLen) {
      sequence.add(0); // PAD token
    }
    
    return sequence;
  }

  /// Convert sequence of indices to text
  static String _sequenceToText(List<int> sequence) {
    if (_idxToWord == null) return '';
    
    final words = <String>[];
    for (final idx in sequence) {
      if (idx == 0) continue; // Skip PAD
      final word = _idxToWord![idx];
      if (word != null && 
          word != '<PAD>' && 
          word != '<UNK>' && 
          word != '<start>' && 
          word != '<end>') {
        words.add(word);
      }
    }
    
    return words.join(' ').trim();
  }

  /// Summarize text using TFLite model
  static Future<String> summarize(String text) async {
    if (!_initialized || _summarizerInterpreter == null) {
      return ''; // Empty means use fallback
    }

    try {
      // Convert text to sequence
      final inputSeq = _textToSequence(text, 200);
      final input = [inputSeq];

      // Prepare output
      final outputShape = _summarizerInterpreter!.getOutputTensor(0).shape;
      final outputSize = outputShape.fold(1, (a, b) => a * b);
      final output = List.generate(outputSize, (_) => 0.0);

      // Run inference
      _summarizerInterpreter!.run(input, output);

      // Convert output to text
      // Output shape: [1, MAX_OUTPUT_LEN, VOCAB_SIZE]
      final flatSeq = <int>[];
      final batchSize = outputShape[0];
      final seqLen = outputShape[1];
      final vocabSize = outputShape[2];
      
      for (int i = 0; i < seqLen; i++) {
        int maxIdx = 0;
        double maxProb = -double.infinity;
        final startIdx = i * vocabSize;
        for (int j = 0; j < vocabSize; j++) {
          final prob = (output[startIdx + j] as num).toDouble();
          if (prob > maxProb) {
            maxProb = prob;
            maxIdx = j;
          }
        }
        flatSeq.add(maxIdx);
      }
      
      final summary = _sequenceToText(flatSeq);

      return summary.isNotEmpty ? summary : '';
    } catch (e) {
      debugPrint('TFLite summarization error: $e');
      return '';
    }
  }

  /// Answer question using TFLite model
  static Future<String> answerQuestion(String question, String context) async {
    if (!_initialized || _qaInterpreter == null) {
      return ''; // Empty means use fallback
    }

    try {
      // Convert to sequences
      final questionSeq = _textToSequence(question, 50);
      final contextSeq = _textToSequence(context, 200);
      final input = [questionSeq, contextSeq];

      // Prepare outputs
      final answerShape = _qaInterpreter!.getOutputTensor(0).shape;
      final answerSize = answerShape.fold(1, (a, b) => a * b);
      final answerOutput = List.generate(answerSize, (_) => 0.0);

      final similarityShape = _qaInterpreter!.getOutputTensor(1).shape;
      final similaritySize = similarityShape.fold(1, (a, b) => a * b);
      final similarityOutput = List.generate(similaritySize, (_) => 0.0);

      // Run inference
      _qaInterpreter!.run(input, [answerOutput, similarityOutput]);

      // Convert answer output to text
      // Answer shape: [1, MAX_ANSWER_LEN, VOCAB_SIZE]
      final answerSeq = <int>[];
      final seqLen = answerShape[1];
      final vocabSize = answerShape[2];



      //argmax decoding
      for (int i = 0; i < seqLen; i++) {
        int maxIdx = 0;
        double maxProb = -double.infinity;
        final startIdx = i * vocabSize;
        for (int j = 0; j < vocabSize; j++) {
          final prob = (answerOutput[startIdx + j] as num).toDouble();
          if (prob > maxProb) {
            maxProb = prob;
            maxIdx = j;
          }
        }
        answerSeq.add(maxIdx);
      }

      final answer = _sequenceToText(answerSeq);
      final confidence = (similarityOutput[0] as num).toDouble();

      if (answer.isNotEmpty && confidence > 0.3) {
        return answer;
      }

      return '';
    } catch (e) {
      debugPrint('TFLite Q&A error: $e');
      return '';
    }
  }
}


