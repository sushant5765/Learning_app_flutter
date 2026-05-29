// lib/screens/document_scan_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/document_history.dart';
import '../services/ai_service.dart';
import '../services/history_service.dart';
import 'document_history_screen.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
enum MessageSender { user, ai, document }

class Message {
  final String text;
  final MessageSender sender;
  Message({required this.text, required this.sender});
}

class DocumentLessonScreen extends StatefulWidget {
  final String? originalText;
  final DocumentHistory? history;

  const DocumentLessonScreen({
    super.key,
    this.originalText,
    this.history,
  });

  factory DocumentLessonScreen.fromHistory({
    required DocumentHistory history,
  }) {
    return DocumentLessonScreen(
      key: Key(history.id),
      originalText: history.originalText,
      history: history,
    );
  }

  @override
  State<DocumentLessonScreen> createState() => _DocumentLessonScreenState();
}

class _DocumentLessonScreenState extends State<DocumentLessonScreen> {
  final AiService _aiService = AiService();
  final HistoryService _historyService = HistoryService();
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  List<Message> _messages = [];
  bool _isLoading = false;
  Map<String, String> _vocabularyWithDefinitions = {};

  bool _isSpeaking = false;
  bool _isPaused = false;
  double _speechRate = 0.5;
  double _fontSize = 18.0;
  double _lineSpacing = 1.4;
  double _letterSpacing = 0.0;

  // Document state
  bool _hasDocument = false;
  String _documentText = '';
  String _summary = '';
  String _documentId = '';
  bool _isFromHistory = false;

  // Dyslexia-friendly colors
  final Color _primaryColor = const Color(0xFF4A90E2);
  final Color _secondaryColor = const Color(0xFF50C9C3);
  final Color _backgroundColor = const Color(0xFFF8FAFC); // Light background
  final Color _surfaceColor = const Color(0xFFF0F4F8); // Light surface color (not white)
  final Color _textColor = const Color(0xFF2D3748); // Dark text color

  @override
  void initState() {
    super.initState();
    _initTts();

    if (widget.originalText != null && widget.originalText!.isNotEmpty) {
      _initializeWithDocument(widget.originalText!);
    } else if (widget.history != null) {
      _loadFromHistory(widget.history!);
    }
  }

  void _initializeWithDocument(String text) {
    setState(() {
      _documentText = text;
      _hasDocument = true;
      _documentId = _generateDocumentId();
      _isFromHistory = false;
    });

    _aiService.startNewChat(text);                             //  chat starts
    _messages.add(Message(text: text, sender: MessageSender.document));



    // auto summary
    Future.delayed(const Duration(milliseconds: 100), () {
      _sendMessage("Summarize this document for me.");   // send message to Ai
    });
  }

  void _loadFromHistory(DocumentHistory history) {
    setState(() {
      _messages = history.conversation.map((chatMsg) {
        return Message(
          text: chatMsg.text,
          sender: _messageSenderFromString(chatMsg.sender),
        );
      }).toList();
      _summary = history.summary;
      _hasDocument = true;
      _documentId = history.id;
      _isFromHistory = true;
      _documentText = history.originalText;
    });
  }

  MessageSender _messageSenderFromString(String sender) {
    switch (sender) {
      case 'user':
        return MessageSender.user;
      case 'ai':
        return MessageSender.ai;
      case 'document':
        return MessageSender.document;
      default:
        return MessageSender.document;
    }
  }

  String _generateDocumentId() {
    return 'doc_${DateTime.now().millisecondsSinceEpoch}';
  }

  void _initTts() {
    _tts.setLanguage("en-US");
    _tts.setSpeechRate(_speechRate);
    _tts.setStartHandler(() {
      setState(() {
        _isSpeaking = true;
        _isPaused = false;
      });
    });
    _tts.setCompletionHandler(() {
      _ttsCompleter?.complete();
      // For non-chunked speech, update state when complete
      if (_textChunks.isEmpty) {
        setState(() {
          _isSpeaking = false;
          _isPaused = false;
          _currentlySpeakingIndex = null;
        });
      }
    });
    _tts.setPauseHandler(() {
      setState(() {
        _isPaused = true;
      });
    });
    _tts.setContinueHandler(() {
      setState(() {
        _isPaused = false;
      });
    });
  }

  @override
  void dispose() {
    if (_hasDocument && !_isFromHistory && _messages.length > 2) {
      _saveToHistory();
    }
    _textRecognizer.close();
    _tts.stop();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ========== FILE UPLOAD METHODS ==========

  Future<void> _pickFile() async {
    setState(() => _isLoading = true);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'txt'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final fileBytes = result.files.single.bytes!;
        final fileName = result.files.single.name.toLowerCase();

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );

        String extractedText = "";

        if (fileName.endsWith('.pdf')) {
          extractedText = await _extractTextFromPdf(fileBytes);
        } else if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg') || fileName.endsWith('.png')) {
          final tempFile = await File(
            '${(await getTemporaryDirectory()).path}/$fileName',
          ).writeAsBytes(fileBytes);
          extractedText = await _extractTextFromImage(tempFile);
        } else if (fileName.endsWith('.txt')) {
          extractedText = utf8.decode(fileBytes);
        }

        Navigator.of(context).pop();

        if (extractedText.trim().isEmpty) {
          _showError("Cannot extract text from this file.");
        } else {
          _initializeWithDocument(extractedText);
        }
      } else {
        _showError("No file selected or file could not be read.");
      }
    } catch (e) {
      Navigator.of(context).pop();
      _showError("Error picking or reading file: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // NEW: Capture image with camera
  Future<void> _captureWithCamera() async {
    setState(() => _isLoading = true);

    try {
      // Check camera permission
      final PermissionStatus status = await Permission.camera.request();

      if (status.isGranted) {
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.rear,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );

        if (image != null) {
          await _processImageFile(File(image.path));
        } else {
          _showError("No image captured.");
        }
      } else {
        _showError("Camera permission is required to capture documents.");
      }
    } catch (e) {
      _showError("Error capturing image: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

// NEW: Pick image from gallery
  Future<void> _pickImageFromGallery() async {
    setState(() => _isLoading = true);

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 90,
      );

      if (image != null) {
        await _processImageFile(File(image.path));
      } else {
        _showError("No image selected.");
      }
    } catch (e) {
      _showError("Error selecting image: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

// NEW: Process image file (shared by camera and gallery)
  Future<void> _processImageFile(File imageFile) async {
    // Show processing dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _buildProcessingDialog(),
    );

    try {
      final extractedText = await _extractTextFromImage(imageFile);

      Navigator.of(context).pop(); // Close processing dialog

      if (extractedText.trim().isEmpty) {
        _showError("No text found in the image. Please try again with a clearer photo.");
      } else {
        _initializeWithDocument(extractedText);
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close dialog on error
      _showError("Error processing image: $e");
    }
  }

// NEW: Processing dialog widget
  Widget _buildProcessingDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _primaryColor),
            const SizedBox(height: 16),
            Text(
              'Processing Image...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Extracting text from your image',
              style: TextStyle(
                color: _textColor.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _extractTextFromPdf(Uint8List bytes) async {
    try {
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      String extractedText = '';

      for (int i = 0; i < document.pages.count; i++) {
        final String pageText = PdfTextExtractor(document).extractText(startPageIndex: i, endPageIndex: i);
        extractedText += pageText + '\n\n';
      }

      document.dispose();
      return extractedText;
    } catch (e) {
      throw Exception('Failed to extract PDF text: $e');
    }
  }

  Future<String> _extractTextFromImage(File imageFile) async {
    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (e) {
      throw Exception('Failed to extract image text: $e');
    }
  }


  ///upload options showing
  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // ADD THIS
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SingleChildScrollView( // ADDED THIS
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add Document',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
                textAlign: TextAlign.center, // ADDED THIS
              ),
              const SizedBox(height: 20),
              // Camera Option
              _UploadOptionCard(
                icon: Icons.camera_alt,
                title: 'Take Photo',
                subtitle: 'Capture document with camera',
                onTap: () {
                  Navigator.of(context).pop();
                  _captureWithCamera();
                },
              ),
              const SizedBox(height: 12),
              _UploadOptionCard(
                icon: Icons.photo_library,
                title: 'Choose from Gallery',
                subtitle: 'Select image from your gallery',
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImageFromGallery();
                },
              ),
              const SizedBox(height: 12),
              _UploadOptionCard(
                icon: Icons.insert_drive_file,
                title: 'Upload File',
                subtitle: 'PDF, Images, Text files',
                onTap: () {
                  Navigator.of(context).pop();
                  _pickFile();
                },
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded( // THIS PREVENTS OVERFLOW
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: _primaryColor,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  // ========== AI CHAT METHODS ==========

  Future<void> _sendMessage(String messageText) async {
    if (messageText.trim().isEmpty || _isLoading || !_hasDocument) return;

    setState(() {
      _messages.add(Message(text: messageText, sender: MessageSender.user));            // add user message to chat
      _isLoading = true;
    });
    _textController.clear();
    _scrollToBottom();

    try {
      final aiResponse = await _aiService.sendMessage(messageText);             // sends message to ai

      setState(() {
        _messages.add(Message(text: aiResponse, sender: MessageSender.ai));          // ai reply to chat 

        if (!_isFromHistory && messageText.toLowerCase().contains('summarize') && _summary.isEmpty) {
          _summary = aiResponse;
          _saveToHistory();
        }
      });
      _scrollToBottom();

      if (!_isFromHistory) {
        _saveToHistory();
      }
    } catch (e) {
      setState(() {
        _messages.add(Message(
            text: "Error: Could not get a response. Try again after few minutes",
            sender: MessageSender.ai
        ));
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveToHistory() async {
    if (!_hasDocument) return;

    try {
      String title;
      if (_summary.isNotEmpty) {
        title = _summary.length > 30
            ? '${_summary.substring(0, 30)}...'
            : _summary;
      } else {
        title = _documentText.length > 30
            ? '${_documentText.substring(0, 30)}...'
            : _documentText;
      }

      final history = DocumentHistory(
        id: _documentId,
        originalText: _documentText,
        summary: _summary,
        createdAt: DateTime.now(),
        title: title.isEmpty ? 'Summarize' : title,
        conversation: _messages.map((msg) => ChatMessage(
          text: msg.text,
          sender: msg.sender.name,
          timestamp: DateTime.now(),
        )).toList(),
      );

      await _historyService.saveDocumentHistory(history);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document saved to history'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error saving history: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save progress'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
    ///TTS METHODS with spilting chunking the texts
  // ========== TTS METHODS ==========

  List<String> _textChunks = [];
  int _currentChunkIndex = 0;
  String? _currentSpeakingText;
  Completer<void>? _ttsCompleter;
  int? _currentlySpeakingIndex;

  Future<void> _speak(String text, int messageIndex) async {
    await _stopSpeech();
    await _tts.setSpeechRate(_speechRate);

    setState(() {
      _currentlySpeakingIndex = messageIndex;
      _isSpeaking = true;
      _isPaused = false;
    });

    // Only chunk if text is long (> 1500 characters)
    if (text.length > 2500) {
      _speakWithChunking(text);
    } else {
      // Short text - use simple TTS
      await _tts.speak(text);
    }
  }

  void _speakWithChunking(String text) {
    _textChunks = _splitTextIntoChunks(text, 300);
    _currentChunkIndex = 0;
    _currentSpeakingText = text;

    if (_textChunks.isNotEmpty) {
      _speakNextChunk();
    }
  }

  List<String> _splitTextIntoChunks(String text, int chunkSize) {
    List<String> chunks = [];

    // Split by sentences first for natural pauses
    List<String> sentences = text.split(RegExp(r'[.!?]+'));

    for (String sentence in sentences) {
      sentence = sentence.trim();
      if (sentence.isEmpty) continue;

      if (sentence.length <= chunkSize) {
        chunks.add(sentence);
      } else {
        // If sentence is too long, split by words
        List<String> words = sentence.split(' ');
        String currentChunk = '';

        for (String word in words) {
          if ((currentChunk + word).length <= chunkSize) {
            currentChunk += '$word ';
          } else {
            if (currentChunk.isNotEmpty) {
              chunks.add(currentChunk.trim());
            }
            currentChunk = '$word ';
          }
        }

        if (currentChunk.isNotEmpty) {
          chunks.add(currentChunk.trim());
        }
      }
    }

    return chunks;
  }

  void _speakNextChunk() {
    if (_currentChunkIndex < _textChunks.length && _isSpeaking && !_isPaused) {
      _tts.speak(_textChunks[_currentChunkIndex]).then((_) {
        _waitForChunkCompletion().then((_) {
          if (_isSpeaking && !_isPaused) {
            _currentChunkIndex++;
            if (_currentChunkIndex < _textChunks.length) {
              _speakNextChunk();
            } else {
              // All chunks completed
              _stopSpeech();
            }
          }
        });
      });
    }
  }

  Future<void> _waitForChunkCompletion() async {
    _ttsCompleter = Completer<void>();
    _tts.setCompletionHandler(() {
      _ttsCompleter?.complete();
    });
    return _ttsCompleter?.future ?? Future.value();
  }

  Future<void> _pauseSpeech() async {
    if (_isSpeaking && !_isPaused) {
      await _tts.pause();
      setState(() {
        _isPaused = true;
      });
    }
  }

  Future<void> _stopSpeech() async {
    await _tts.stop();
    _textChunks.clear();
    _currentChunkIndex = 0;
    _currentSpeakingText = null;
    _ttsCompleter?.complete();
    setState(() {
      _isSpeaking = false;
      _isPaused = false;
      _currentlySpeakingIndex = null;
    });
  }

  // ========== VOCABULARY METHODS ==========

  Future<void> _highlightVocabulary() async {
    if (!_hasDocument) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final vocab = _aiService.extractVocabularyWithContext(count: 12);
      if (vocab.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No standout vocabulary found yet.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() {
          _vocabularyWithDefinitions = vocab;
        });
        _showVocabularyDialog();
      }
    } catch (e) {
      print("Error highlighting vocabulary: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to extract vocabulary'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showVocabularyDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Vocabulary Words'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: _vocabularyWithDefinitions.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,fontFamily: 'Lexend',
                          fontSize: 22,

                          color: Color(0xFF1A237E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.value,
                        style: const TextStyle(
                          fontSize: 22,
                          fontFamily: 'Lexend',
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                      const Divider(height: 16),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // ========== ACCESSIBILITY METHODS ==========

  void _showAccessibilityOptions() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Reading Options',
            style: TextStyle(
              fontSize: 22, // Larger font
              fontWeight: FontWeight.w600,
              fontFamily: 'Lexend', // Lexend font
              color: _textColor,
            ),
          ),
          content: StatefulBuilder(
            builder: (context, setStateInDialog) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Font Size Option
                  Row(
                    children: [
                      Text(
                        'Font Size:',
                        style: TextStyle(
                          fontSize: 22, // Larger
                          fontFamily: 'Lexend',
                          fontWeight: FontWeight.w500,
                          color: _textColor,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: _fontSize,
                          min: 16.0,
                          max: 24.0,
                          divisions: 8,
                          label: _fontSize.toStringAsFixed(0),
                          onChanged: (newSize) {
                            setState(() {
                              _fontSize = newSize;
                            });
                            setStateInDialog(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20), // More spacing

                  // Line Spacing Option
                  Row(
                    children: [
                      Text(
                        'Line Spacing:',
                        style: TextStyle(
                          fontSize: 22, // Larger
                          fontFamily: 'Lexend',
                          fontWeight: FontWeight.w500,
                          color: _textColor,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: _lineSpacing,
                          min: 1.0,
                          max: 2.0,
                          divisions: 10,
                          label: _lineSpacing.toStringAsFixed(1),
                          onChanged: (newSpacing) {
                            setState(() {
                              _lineSpacing = newSpacing;
                            });
                            setStateInDialog(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20), // More spacing

                  // Letter Spacing Option
                  Row(
                    children: [
                      Text(
                        'Letter Spacing:',
                        style: TextStyle(
                          fontSize: 22, // Larger
                          fontFamily: 'Lexend',
                          fontWeight: FontWeight.w500,
                          color: _textColor,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: _letterSpacing,
                          min: 0.0,
                          max: 0.5,
                          divisions: 10,
                          label: _letterSpacing.toStringAsFixed(1),
                          onChanged: (newSpacing) {
                            setState(() {
                              _letterSpacing = newSpacing;
                            });
                            setStateInDialog(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Speech Speed Option
                  Row(
                    children: [
                      Text(
                        'Speech Speed:',
                        style: TextStyle(
                          fontSize: 22, // Larger
                          fontFamily: 'Lexend',
                          fontWeight: FontWeight.w500,
                          color: _textColor,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: _speechRate,
                          min: 0.3,
                          max: 0.8,
                          divisions: 5,
                          label: _speechRate.toStringAsFixed(1),
                          onChanged: (newRate) {
                            setState(() {
                              _speechRate = newRate;
                            });
                            setStateInDialog(() {});
                            if (_isSpeaking || _isPaused) {
                              _tts.setSpeechRate(_speechRate);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: TextStyle(
                  fontSize: 22, // Larger
                  fontFamily: 'Lexend',
                  fontWeight: FontWeight.w500,
                  color: _primaryColor,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToHistoryScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DocumentHistoryScreen(),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // ========== UI BUILD METHODS ==========

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          _hasDocument
              ? (_isFromHistory ? "Continue Lesson" : "Your summary")
              : "Upload Document",
          style: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 14
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _navigateToHistoryScreen,
            tooltip: 'View History',
          ),
          if (!_hasDocument)
            IconButton(
              icon: const Icon(Icons.upload),
              onPressed: _showUploadOptions,
              tooltip: 'Upload Document',
            ),
          if (_hasDocument && !_isFromHistory)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveToHistory,
              tooltip: 'Save Progress',
            ),
          if (_hasDocument)
            IconButton(
              icon: const Icon(Icons.library_books),
              onPressed: _highlightVocabulary,
              tooltip: 'Highlight Vocabulary',
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showAccessibilityOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_hasDocument)
            _buildUploadPrompt(),

          Expanded(
            child: _hasDocument
                ? _buildChatInterface()
                : _buildEmptyChatInterface(),
          ),

          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: LinearProgressIndicator(
                color: _primaryColor,
                backgroundColor: _surfaceColor,
              ),
            ),

          if (_hasDocument)
            _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildUploadPrompt() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Updated icons to include camera
          Icon(Icons.document_scanner, size: 80, color: _primaryColor),
          const SizedBox(height: 16),
          Text(
            'Add Document to Start',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Take a photo, upload from gallery, or choose files to begin your lesson',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textColor.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              // Camera button
              ElevatedButton.icon(
                onPressed: _captureWithCamera,
                icon: const Icon(Icons.camera_alt, size: 26),
                label: const Text('Take Photo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              // Gallery button
              ElevatedButton.icon(
                onPressed: _pickImageFromGallery,
                icon: const Icon(Icons.photo_library, size: 20),
                label: const Text('From Gallery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _secondaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              // Upload button
              ElevatedButton.icon(
                onPressed: _showUploadOptions,
                icon: const Icon(Icons.upload_file, size: 20),
                label: const Text('Upload Files'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7E57C2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildEmptyChatInterface() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat, size: 80, color: _primaryColor.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'Upload a document to start chatting with AI',
            style: TextStyle(
              fontSize: 16,
              color: _textColor.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }


  // chat interface building

  Widget _buildChatInterface() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isCurrentlySpeaking = _currentlySpeakingIndex == index;

        return _MessageBubble(
          message: message,
          messageIndex: index, // Added this
          isCurrentlySpeaking: isCurrentlySpeaking, // Added this
          onTapRead: () => _speak(message.text, index), // Added index as second argument
          onTapPause: isCurrentlySpeaking && _isSpeaking ? () => _pauseSpeech() : null,
          onTapStop: isCurrentlySpeaking && (_isSpeaking || _isPaused) ? () => _stopSpeech() : null,
          isSpeaking: isCurrentlySpeaking && _isSpeaking,
          isPaused: isCurrentlySpeaking && _isPaused,
          fontSize: _fontSize,
          lineSpacing: _lineSpacing,
          letterSpacing: _letterSpacing,
          primaryColor: _primaryColor,
          textColor: _textColor,
          backgroundColor: _backgroundColor,
          surfaceColor: _surfaceColor,
        );
      },
    );
  }
  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              style: TextStyle(
                fontSize: _fontSize,
                height: _lineSpacing,
                letterSpacing: _letterSpacing,
              ),
              decoration: InputDecoration(
                hintText: "Ask a question about the document...",
                hintStyle: TextStyle(
                  color: _textColor.withOpacity(0.5),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: _surfaceColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              onSubmitted: (value) => _sendMessage(value),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _isLoading ? null : () => _sendMessage(_textController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isLoading ? Colors.grey : _primaryColor,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(14),
              elevation: 4,
              shadowColor: Colors.black26,
            ),
            child: const Icon(Icons.send, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _UploadOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _UploadOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, size: 32, color: const Color(0xFF4A90E2)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}


// prevent chat box form stretching

class _MessageBubble extends StatelessWidget {
  final Message message;
  final VoidCallback onTapRead;
  final int messageIndex; //variables for splitting text
  final bool isCurrentlySpeaking; // ''
  final VoidCallback? onTapPause;
  final VoidCallback? onTapStop;
  final bool isSpeaking;
  final bool isPaused;
  final double fontSize;
  final double lineSpacing;
  final double letterSpacing;
  final Color primaryColor;
  final Color textColor;
  final Color backgroundColor;
  final Color surfaceColor;

  const _MessageBubble({
    required this.message,
    required this.onTapRead,
    required this.messageIndex, // to track which is spoken
    required this.isCurrentlySpeaking,// to check if its spekaing or not
    this.onTapPause,
    this.onTapStop,
    required this.isSpeaking,
    required this.isPaused,
    required this.fontSize,
    required this.lineSpacing,
    required this.letterSpacing,
    required this.primaryColor,
    required this.textColor,
    required this.backgroundColor,
    required this.surfaceColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isUser = message.sender == MessageSender.user;
    final bool isDocument = message.sender == MessageSender.document;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          gradient: isUser
              ? LinearGradient(
            colors: [primaryColor, const Color(0xFF50C9C3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : null,
          color: isDocument ? backgroundColor : (isUser ? null : surfaceColor),
          borderRadius: isDocument
              ? BorderRadius.circular(8)
              : BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: isUser ? const Radius.circular(18) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(18),
          ),
          boxShadow: isDocument
              ? []
              : [
            const BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(2, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isUser ? Colors.white : textColor,
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                height: lineSpacing,
                letterSpacing: letterSpacing,
              ),
            ),
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Read Aloud button
                    InkWell(
                      onTap: onTapRead,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPaused ? Icons.play_arrow : Icons.volume_up,
                            size: 18,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isPaused ? "Resume" : "Read Aloud",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Pause button (only when speaking)
                    if (isSpeaking && !isPaused) ...[
                      const SizedBox(width: 16),
                      InkWell(
                        onTap: onTapPause,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pause, size: 18, color: Colors.black54),
                            SizedBox(width: 4),
                            Text(
                              "Pause",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Stop button (only when speaking or paused)
                    if (isSpeaking || isPaused) ...[
                      const SizedBox(width: 16),
                      InkWell(
                        onTap: onTapStop,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.stop, size: 18, color: Colors.black54),
                            SizedBox(width: 4),
                            Text(
                              "Stop",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}