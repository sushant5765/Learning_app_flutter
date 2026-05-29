// lib/screens/reading_practice.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:learning_app/screens/passage_generation_screen.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/hive_store.dart';
import '../data/passages.dart';     // Import the passages file
import '../services/learning_profile_service.dart';

class ReadingPracticeScreen extends StatefulWidget {
  final String uid;
  final String? practiceText;

  const ReadingPracticeScreen({
    super.key,
    required this.uid,
    this.practiceText,
  });

  @override
  State<ReadingPracticeScreen> createState() => _ReadingPracticeScreenState();
}

class _ReadingPracticeScreenState extends State<ReadingPracticeScreen>
    with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;
  late FlutterTts _tts;

  bool _isListening = false;
  bool _hasCompleted = false;
  bool _hasValidAudio = false;
  bool _isPlayingTTS = false;
  String _recognized = "";
  DateTime? _startTime;

  double _wpm = 0;
  double _accuracy = 0;

  // Font size accessibility
  double _fontSizeMultiplier = 1.0;

  // Enhanced error tracking - CLEAR SEPARATION
  final List<String> _mispronouncedWords = []; // Words said but wrong pronunciation
  final List<String> _missedWords = []; // Words completely skipped
  final List<int> _mispronouncedIndices = [];
  final List<int> _missedIndices = [];
  final List<_Substitution> _substitutions = [];

  // Level selection
  String _selectedLevel = 'beginner'; // Default level
  bool _isAdaptiveEnabled = true; // Track if adaptive learning is enabled
  List<String> get _currentLevelPassages => ReadingPassages.getPassagesByLevel(_selectedLevel);

  String _currentPassage = "";
  String? _originalPracticeText;
  String _initialPassage = "";

  // Pronunciation practice state
  bool _isPracticingPronunciation = false;
  int _currentPracticeIndex = 0;
  List<String> _wordsToPractice = [];

  // Animated mic
  late AnimationController _micCtrl;
  late Animation<double> _micScale;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();

    // Initialize TTS with slower rate for pronunciation practice
    _initializeTTS();

    // Use custom text if provided, otherwise pick from default passages
    if (widget.practiceText != null && widget.practiceText!.isNotEmpty) {
      _currentPassage = widget.practiceText!;
      _originalPracticeText = widget.practiceText!;
      _initialPassage = widget.practiceText!;
    } else {
      _initializeAdaptivePassage();
    }

    _micCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _micScale = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _micCtrl, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeTTS() async {
    await _tts.setLanguage("en-IN");
    await _tts.setSpeechRate(0.5); // Slower for better clarity
    await _tts.setPitch(1.0);
    await _tts.setVolume(0.8);

    _tts.setStartHandler(() {
      setState(() => _isPlayingTTS = true);
    });

    _tts.setCompletionHandler(() {
      setState(() => _isPlayingTTS = false);
    });

    _tts.setErrorHandler((msg) {
      setState(() => _isPlayingTTS = false);
    });
  }

  Future<void> _initializeAdaptivePassage() async {
    if (!mounted || widget.practiceText != null) return;
    
    // Load adaptive learning state
    await LearningProfileService.instance.setReadingAdaptiveEnabled(true);
    final adaptiveEnabled = await LearningProfileService.instance.isReadingAdaptiveEnabled();
    final currentLevel = await LearningProfileService.instance.getCurrentReadingLevel();
    
    setState(() {
      _isAdaptiveEnabled = adaptiveEnabled;
      _isAdaptiveEnabled = true;
      if (adaptiveEnabled) {
        // Use adaptive level
        _selectedLevel = currentLevel;
      } else {
        // Use recommended level if adaptive is disabled
        _selectedLevel = currentLevel;
      }
      _pickRandomPassage();
      _initialPassage = _currentPassage;
    });
  }

  Future<void> _speakPassage() async {
    if (_isPlayingTTS) {
      await _tts.stop();
      return;
    }

    try {
      await _tts.speak(_currentPassage);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("TTS Error: ${e.toString()}")),
        );
      }
    }
  }

  Future<void> _speakWordSlowly(String word) async {
    try {
      // Even slower rate for word pronunciation practice
      await _tts.setSpeechRate(0.3);
      await _tts.speak(word);
      // Reset to normal rate after pronunciation
      await _tts.setSpeechRate(0.5);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not pronounce word: $word")),
        );
      }
    }
  }

  // Pick random passage from current level
  void _pickRandomPassage() {
    final passages = _currentLevelPassages;
    if (passages.isEmpty) {
      _currentPassage = "No passages available for $_selectedLevel level. Please select another level.";
      return;
    }
    final rand = Random().nextInt(passages.length);
    _currentPassage = passages[rand];
  }

  // NEW: Change level and refresh passage   // adaptive
  Future<void> _changeLevel(String newLevel, {bool isManual = false}) async {
    if (newLevel != _selectedLevel) {
      // If manually changed, disable adaptive learning
      await LearningProfileService.instance.setReadingAdaptiveEnabled(true);
      if (isManual) {
        await LearningProfileService.instance.setCurrentReadingLevel(newLevel, isManual: true);
        setState(() {

          _selectedLevel = newLevel;
          _isAdaptiveEnabled = true;
          _pickRandomPassage();
          _resetPracticeState();
        });
      } else {
        // Automatic progression - keep adaptive enabled
        await LearningProfileService.instance.setCurrentReadingLevel(newLevel, isManual: false);
        setState(() {
          _selectedLevel = newLevel;
          _pickRandomPassage();
          _resetPracticeState();
        });
      }
    }
  }

  // NEW: Refresh passage - loads a new passage from current level
  Future<void> _refreshPassage() async {
    if (widget.practiceText != null) {
      // If it's an AI-generated passage, navigate to generation screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PassageGenerationScreen(uid: widget.uid),
        ),
      );
    } else {
      final recommended =
          await LearningProfileService.instance.getCurrentReadingLevel();
      // If it's from default passages, pick a new random one from current level
      final passages = ReadingPassages.getPassagesByLevel(recommended);
      if (passages.length <= 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "Only one passage available in $recommended level right now")),
        );
        return;
      }

      String newPassage;
      do {
        final rand = Random().nextInt(passages.length);
        newPassage = passages[rand];
      } while (newPassage == _currentPassage && passages.length > 1);

      setState(() {
        _selectedLevel = recommended;
        _currentPassage = newPassage;
        _initialPassage = newPassage;
      });
      _resetPracticeState();
    }
  }

  // NEW: Reset only practice state without changing passage
  void _resetPracticeState() {
    setState(() {
      _isListening = false;
      _hasCompleted = false;
      _hasValidAudio = false;
      _isPlayingTTS = false;
      _isPracticingPronunciation = false;
      _recognized = "";
      _wpm = 0;
      _accuracy = 0;
      _mispronouncedWords.clear();
      _missedWords.clear();
      _mispronouncedIndices.clear();
      _missedIndices.clear();
      _substitutions.clear();
      _startTime = null;
    });

    _tts.stop();
  }

  // ENHANCED: Pronunciation practice flow
  void _startPronunciationPractice() {
    if (_mispronouncedWords.isEmpty) return;

    setState(() {
      _isPracticingPronunciation = true;
      _currentPracticeIndex = 0;
      _wordsToPractice = List.from(_mispronouncedWords);
    });

    _speakNextWord();
  }

  void _speakNextWord() {
    if (_currentPracticeIndex < _wordsToPractice.length) {
      _speakWordSlowly(_wordsToPractice[_currentPracticeIndex]);
    } else {
      // Practice completed
      setState(() {
        _isPracticingPronunciation = false;
        _currentPracticeIndex = 0;
      });
    }
  }

  void _nextWord() {
    setState(() {
      _currentPracticeIndex++;
    });
    _speakNextWord();
  }

  void _previousWord() {
    if (_currentPracticeIndex > 0) {
      setState(() {
        _currentPracticeIndex--;
      });
      _speakWordSlowly(_wordsToPractice[_currentPracticeIndex]);
    }
  }

  void _resetPractice() {
    setState(() {
      // FIXED: Keep the same passage for "Practice Again"
      _resetPracticeState();
    });
  }

  @override
  void dispose() {
    _micCtrl.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  List<String> _tokens(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r"[^\w\s]"), "")
        .split(RegExp(r"\s+"))
        .where((w) => w.isNotEmpty)
        .toList();
  }

  // IMPROVED: Enhanced Levenshtein distance with better pronunciation detection
  int _levenshteinDistance(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    // More forgiving for pronunciation variations
    if ((a.length - b.length).abs() > 3) return 100;

    final m = a.length, n = b.length;
    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));

    for (int i = 0; i <= m; i++) dp[i][0] = i;
    for (int j = 0; j <= n; j++) dp[0][j] = j;

    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = min(
          dp[i - 1][j] + 1,
          min(
            dp[i][j - 1] + 1,
            dp[i - 1][j - 1] + cost,
          ),
        );
      }
    }
    return dp[m][n];
  }


  // analyzing calculation  wpm

  void _analyzeReading({
    required List<String> passageWords,
    required List<String> spokenWords,
  }) {
    _mispronouncedWords.clear();
    _missedWords.clear();
    _mispronouncedIndices.clear();
    _missedIndices.clear();
    _substitutions.clear();

    // DEBUG: See what we're working with
    print("🎯 ANALYZING: ${passageWords.length} passage words vs ${spokenWords.length} spoken words");
    print("📖 Passage type: ${widget.practiceText != null ? 'AI Generated' : 'Random'}");

    int passageIndex = 0, spokenIndex = 0;
    int correctWords = 0;
    final totalWords = passageWords.length;

    while (passageIndex < totalWords && spokenIndex < spokenWords.length) {
      final expectedWord = passageWords[passageIndex];
      final spokenWord = spokenWords[spokenIndex];

      // SIMPLE CHECK: If words are similar enough, count as CORRECT
      if (_isSimilarEnough(expectedWord, spokenWord)) {
        correctWords++;
        passageIndex++;
        spokenIndex++;
      }
      // ENHANCED: Recovery logic for longer passages
      else {
        bool recoveryFound = false;

        // Detailed analysis  //extra word
        // STRATEGY 1: Check if user said extra words but will say correct word soon
        for (int lookahead = 1; lookahead <= 3 && spokenIndex + lookahead < spokenWords.length; lookahead++) {
          if (_isSimilarEnough(expectedWord, spokenWords[spokenIndex + lookahead])) {
            // User said extra words but eventually got it right
            _mispronouncedWords.add(expectedWord);
            _mispronouncedIndices.add(passageIndex);
            _substitutions.add(_Substitution(expected: expectedWord, heard: spokenWords[spokenIndex + lookahead]));
            passageIndex++;
            spokenIndex += lookahead + 1; // Skip the extra words
            recoveryFound = true;
            break;
          }
        }


        // skipped words
        // STRATEGY 2: Check if current spoken word matches FUTURE passage words (user skipped words)
        if (!recoveryFound) {
          for (int lookahead = 1; lookahead <= 2 && passageIndex + lookahead < totalWords; lookahead++) {
            if (_isSimilarEnough(passageWords[passageIndex + lookahead], spokenWord)) {
              // User skipped current word but will say future words
              _missedWords.add(expectedWord);
              _missedIndices.add(passageIndex);
              passageIndex++;
              // Keep spokenIndex the same to match with next passage word
              recoveryFound = true;
              break;
            }
          }
        }

          //detailed analysis wrong words
        // STRATEGY 3: If no recovery possible, mark as error but keep moving
        if (!recoveryFound) {
          _mispronouncedWords.add(expectedWord);
          _mispronouncedIndices.add(passageIndex);
          _substitutions.add(_Substitution(expected: expectedWord, heard: spokenWord));
          passageIndex++;
          spokenIndex++;
        }
      }
    }

    // Handle any remaining passage words as missed words
    while (passageIndex < totalWords) {
      _missedWords.add(passageWords[passageIndex]);
      _missedIndices.add(passageIndex);
      passageIndex++;
    }

    // Calculate accuracy and WPM
    _accuracy = totalWords == 0 ? 0 : (correctWords / totalWords) * 100;

    if (_startTime != null) {
      final seconds = max(1, DateTime.now().difference(_startTime!).inSeconds);
      final minutes = seconds / 60.0;
      _wpm = spokenWords.isEmpty ? 0 : spokenWords.length / minutes;
    } else {
      _wpm = 0;
    }

    // DEBUG: Show results
    print("📊 ANALYSIS COMPLETE:");
    print("   Correct: $correctWords/$totalWords (${_accuracy.toStringAsFixed(1)}%)");
    print("   Mispronounced: ${_mispronouncedWords.length} words");
    print("   Missed: ${_missedWords.length} words");
    print("   WPM: ${_wpm.toStringAsFixed(1)}");
  }

  // ENHANCED SIMILARITY CHECK - Works for both short and long passages
  bool _isSimilarEnough(String expected, String spoken) {
    // Clean the words
    expected = expected.toLowerCase().trim();
    spoken = spoken.toLowerCase().trim();

    // Exact match
    if (expected == spoken) return true;

    // Ignore punctuation differences
    String cleanExpected = expected.replaceAll(RegExp(r'[^\w]'), '');
    String cleanSpoken = spoken.replaceAll(RegExp(r'[^\w]'), '');
    if (cleanExpected == cleanSpoken) return true;

    // Common word variations (plurals, tenses, etc.)
    if (expected == spoken + 's' || spoken == expected + 's') return true;
    if (expected == spoken + 'ed' || spoken == expected + 'ed') return true;
    if (expected == spoken + 'ing' || spoken == expected + 'ing') return true;
    if (expected == spoken + 'ly' || spoken == expected + 'ly') return true;
    if (expected == spoken + 'er' || spoken == expected + 'er') return true;


    // accepts mistakes
    // Allow character differences - MORE FORGIVING for longer passages
    final distance = _levenshteinDistance(expected, spoken);

    if (expected.length <= 3 && distance <= 1) return true;
    if (expected.length <= 5 && distance <= 2) return true;
    if (expected.length > 5 && distance <= 3) return true;

    return false;
  }

  Future<void> _startListening() async {
    final isAvailable = await _speech.initialize(
      onStatus: (status) => print('Speech status: $status'),
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Speech error: ${error.errorMsg}")),
          );
        }
      },
    );

    if (!isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Speech recognition not available")),
        );
      }
      return;
    }

    setState(() {
      _isListening = true;
      _hasCompleted = false;
      _hasValidAudio = false;
      _recognized = "";
      _wpm = 0;
      _accuracy = 0;
      _mispronouncedWords.clear();
      _missedWords.clear();
      _mispronouncedIndices.clear();
      _missedIndices.clear();
      _substitutions.clear();
      _startTime = DateTime.now();
    });

    _speech.listen(
      onResult: (result) {
        setState(() {
          _recognized = result.recognizedWords;
          if (_recognized.trim().isNotEmpty) _hasValidAudio = true;
        });
      },
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      cancelOnError: true,
      listenFor: Duration(minutes: 10), // Listen for 10 minutes max
      pauseFor: Duration(minutes: 3),
    );
  }


  // analyzing done after this
  Future<void> _stopListening() async {
    // CAPTURE THE TRANSCRIPT FIRST before any changes
    final String finalTranscript = _recognized;

    await _speech.stop();
    setState(() => _isListening = false);

    // Use the captured transcript instead of _recognized
    if (finalTranscript.trim().isEmpty || _startTime == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("I didn't hear anything. Try again 🙂")),
        );
      }
      setState(() => _hasCompleted = false);
      return;
    }

    final passageWords = _tokens(_currentPassage);
    final spokenWords = _tokens(finalTranscript); // ← Use captured transcript

    // DEBUG: Checking what's being analyzed
    print("🎯 ANALYZING TRANSCRIPT: '$finalTranscript'");
    print("🎯 PASSAGE: '$_currentPassage'");

    _analyzeReading(passageWords: passageWords, spokenWords: spokenWords);

    setState(() => _hasCompleted = true);

    // Save results to hive

    await HiveService(widget.uid).saveReadingResult(
      wpm: _wpm,
      accuracy: _accuracy,
      misreadWords: _mispronouncedWords + _missedWords,
    );

    // save performance
    await LearningProfileService.instance.updateReadingSession(
      accuracy: _accuracy,
      wordsPerMinute: _wpm,
    );




    // Automatic adaptive learning: Progress level automatically when user performs well
    if (_isAdaptiveEnabled && mounted) {
      final shouldProgress = await LearningProfileService.instance.shouldProgressReadingLevel(_selectedLevel);
      
      if (shouldProgress) {
        final nextLevel = LearningProfileService.instance.getNextReadingLevel(_selectedLevel);
        
        // Progress the level in the service
        await LearningProfileService.instance.progressReadingLevel();
        
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            // Automatically progress level
            _changeLevel(nextLevel, isManual: false);
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Level automatically upgraded to ${nextLevel.toUpperCase()}! 🚀'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBF5),
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.practiceText != null ? "Practice Summary" : "Reading Practice",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16 * _fontSizeMultiplier,
            color: const Color(0xFF4A4A4A),
            fontFamily: "Lexend", // Dyslexia-friendly font
          ),
        ),
        actions: [
          // Level Selection - Hidden by default, shown via settings icon
          IconButton(
            icon: const Icon(Icons.settings, color: Color(0xFF4A4A4A)),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Select Difficulty Level', style: TextStyle(fontFamily: "Lexend")),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Note: Manual selection will disable adaptive learning',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontFamily: "Lexend",
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildLevelOption('beginner', 'Beginner - Simple, short passages'),
                      const SizedBox(height: 8),
                      _buildLevelOption('intermediate', 'Intermediate - Longer sentences'),
                      const SizedBox(height: 8),
                      _buildLevelOption('advanced', 'Advanced - Complex vocabulary'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close', style: TextStyle(fontFamily: "Lexend")),
                    ),
                  ],
                ),
              );
            },
            tooltip: "Change Level",
          ),
          // Refresh Button
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF4A4A4A)),
            onPressed: _refreshPassage,
            tooltip: "Load New Passage",
          ),
          // Font size accessibility
          PopupMenuButton<double>(
            icon: const Icon(Icons.text_fields, color: Color(0xFF4A4A4A)),
            onSelected: (value) {
              setState(() {
                _fontSizeMultiplier = value;
              });
            },

            // does the font changing
            itemBuilder: (context) => [
              const PopupMenuItem(value: 0.8, child: Text("Small", style: TextStyle(fontSize: 20, fontFamily: "Lexend"))),
              const PopupMenuItem(value: 1.0, child: Text("Normal", style: TextStyle(fontSize: 20, fontFamily: "Lexend"))),
              const PopupMenuItem(value: 1.2, child: Text("Large", style: TextStyle(fontSize: 20, fontFamily: "Lexend"))),
              const PopupMenuItem(value: 1.4, child: Text("X-Large", style: TextStyle(fontSize: 20, fontFamily: "Lexend"))),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Professional Adaptive Learning Label
            if (widget.practiceText == null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getLevelColor(),
                      _getLevelColor().withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _getLevelColor().withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Only show AI-Driven when adaptive learning is enabled
                    if (_isAdaptiveEnabled) ...[
                      Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontFamily: "Lexend",
                            letterSpacing: 0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _selectedLevel.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontFamily: "Lexend",
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),

            // Hear Passage First Button
            if (!_hasCompleted && !_isListening)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                child: _primaryBtn(
                  onTap: _speakPassage,
                  color: _isPlayingTTS ? const Color(0xFFFFE0E0) : const Color(0xFFE0F7FA),
                  icon: _isPlayingTTS ? Icons.stop : Icons.volume_up,
                  label: _isPlayingTTS ? "Stop Listening" : "Hear Passage First",
                ),
              ),

            // Passage Card
            _card(
              child: _hasCompleted
                  ? _buildHighlightedPassage()
                  : Text(
                _currentPassage,
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: (_currentPassage.length > 300 ? 20 : 22) * _fontSizeMultiplier,
                  height: 1.6,
                  fontWeight: FontWeight.w600,
                  fontFamily: "Lexend",
                ),
                overflow: TextOverflow.visible,
                softWrap: true,
              ),
            ),
            const SizedBox(height: 20),

            if (!_hasCompleted) ...[
              Row(
                children: [
                  Expanded(
                    child: _primaryBtn(
                      onTap: !_isListening ? _startListening : null,
                      color: const Color(0xFFFFF3E0),
                      icon: Icons.mic,
                      label: _isListening ? "Listening…" : "Start Reading",
                      animate: _isListening,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _primaryBtn(
                      onTap: _isListening ? _stopListening : null,
                      color: const Color(0xFFFFF3E0),
                      icon: Icons.stop,
                      label: "Stop",
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Live Transcript
            if (_isListening && _recognized.isNotEmpty)
              _card(
                color: const Color(0xFFF9F9F5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle("Live Transcript"),
                    const SizedBox(height: 8),
                    Text(
                      _recognized,
                      style: TextStyle(
                          fontSize: 18 * _fontSizeMultiplier,
                          height: 1.5,
                          fontFamily: "Lexend"),
                    ),
                  ],
                ),
              ),

            // Results Section
            if (_hasCompleted) ...[
              _sectionTitle("Your Results"),
              const SizedBox(height: 10),
              _metricRow(context),
              const SizedBox(height: 14),

              // Perfect Reading
              if (_mispronouncedWords.isEmpty && _missedWords.isEmpty)
                _card(
                  color: const Color(0xFFDFF5E1),
                  child: Text(
                    "🌟 Brilliant! You read every word clearly. Keep going—today's focus becomes tomorrow's confidence.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18 * _fontSizeMultiplier,
                      fontWeight: FontWeight.w700,
                      fontFamily: "Lexend",
                    ),
                  ),
                )
              else ...[
                // Pronunciation Practice Section
                if (_mispronouncedWords.isNotEmpty && !_isPracticingPronunciation)
                  _card(
                    color: const Color(0xFFFFF4D6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle("Mispronounced Words"),
                        const SizedBox(height: 8),
                        Text(
                          "You said these words but with wrong pronunciation:",
                          style: TextStyle(fontSize: 16 * _fontSizeMultiplier, color: Colors.black87),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _mispronouncedWords.take(8).map((word) => GestureDetector(
                            onTap: () => _speakWordSlowly(word),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE89A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFFD54F)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    word,
                                    style: TextStyle(
                                      fontSize: 18 * _fontSizeMultiplier,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0E4A4A),
                                      fontFamily: "Lexend",
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.volume_up, size: 16, color: Color(0xFF0E4A4A)),
                                ],
                              ),
                            ),
                          )).toList(),
                        ),
                        const SizedBox(height: 16),
                        _primaryBtn(
                          onTap: _startPronunciationPractice,
                          color: const Color(0xFFFFD54F),
                          icon: Icons.record_voice_over,
                          label: "Practice Pronunciation",
                          isSmall: true,
                        ),
                      ],
                    ),
                  ),

                // Active Pronunciation Practice
                if (_isPracticingPronunciation)
                  _card(
                    color: const Color(0xFFFFF8E1),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle("Pronunciation Practice"),
                        const SizedBox(height: 8),
                        Text(
                          "Listen carefully and repeat:",
                          style: TextStyle(fontSize: 16 * _fontSizeMultiplier),
                        ),
                        const SizedBox(height: 16),

                        // Current word being practiced
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                _wordsToPractice[_currentPracticeIndex],
                                style: TextStyle(
                                  fontSize: 32 * _fontSizeMultiplier,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFE65100),
                                  fontFamily: "Lexend",
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Word ${_currentPracticeIndex + 1} of ${_wordsToPractice.length}",
                                style: TextStyle(
                                  fontSize: 16 * _fontSizeMultiplier,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Practice controls
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 400) {
                              // Stack vertically on small screens
                              return Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    child: _primaryBtn(
                                      onTap: _previousWord,
                                      color: const Color(0xFFE0E0E0),
                                      icon: Icons.skip_previous,
                                      label: "Previous",
                                      isSmall: true,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: _primaryBtn(
                                      onTap: () => _speakWordSlowly(_wordsToPractice[_currentPracticeIndex]),
                                      color: const Color(0xFFFFD54F),
                                      icon: Icons.volume_up,
                                      label: "Hear Again",
                                      isSmall: true,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: _primaryBtn(
                                      onTap: _nextWord,
                                      color: const Color(0xFF4CAF50),
                                      icon: Icons.skip_next,
                                      label: _currentPracticeIndex == _wordsToPractice.length - 1 ? "Finish" : "Next",
                                      isSmall: true,
                                    ),
                                  ),
                                ],
                              );
                            }
                            // Use Row on larger screens
                            return Row(
                              children: [
                                Expanded(
                                  child: _primaryBtn(
                                    onTap: _previousWord,
                                    color: const Color(0xFFE0E0E0),
                                    icon: Icons.skip_previous,
                                    label: "Previous",
                                    isSmall: true,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _primaryBtn(
                                    onTap: () => _speakWordSlowly(_wordsToPractice[_currentPracticeIndex]),
                                    color: const Color(0xFFFFD54F),
                                    icon: Icons.volume_up,
                                    label: "Hear Again",
                                    isSmall: true,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _primaryBtn(
                                    onTap: _nextWord,
                                    color: const Color(0xFF4CAF50),
                                    icon: Icons.skip_next,
                                    label: _currentPracticeIndex == _wordsToPractice.length - 1 ? "Finish" : "Next",
                                    isSmall: true,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                // Missed Words Section
                if (_missedWords.isNotEmpty)
                  _card(
                    color: const Color(0xFFFFE0E0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle("Missed Words"),
                        const SizedBox(height: 8),
                        Text(
                          "You completely skipped these words:",
                          style: TextStyle(fontSize: 16 * _fontSizeMultiplier, color: Colors.black87),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _missedWords.take(8).map((word) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFCDD2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              word,
                              style: TextStyle(
                                fontSize: 18 * _fontSizeMultiplier,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFB71C1C),
                                fontFamily: "Lexend",
                              ),
                            ),
                          )).toList(),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Detailed Analysis
                if (_substitutions.isNotEmpty)
                  _card(
                    color: const Color(0xFFF3E5F5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle("Detailed Analysis"),
                        const SizedBox(height: 8),
                        ..._substitutions.take(6).map(
                              (s) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Text(
                              "• Expected '${s.expected}' → Heard '${s.heard}'",
                              style: TextStyle(
                                fontSize: 16 * _fontSizeMultiplier,
                                fontFamily: "Lexend",
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],

              const SizedBox(height: 20),

              // Practice Again Button - KEEPS SAME PASSAGE
              _primaryBtn(
                onTap: _resetPractice,
                color: const Color(0xFFE0F7FA),
                icon: Icons.refresh,
                label: "Practice Again",
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: widget.practiceText == null
          ? FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PassageGenerationScreen(uid: widget.uid),
            ),
          );
        },
        backgroundColor: const Color(0xFFFFF3E0),
        child: const Icon(Icons.auto_awesome, color: Colors.black87),
        tooltip: "Generate Custom Passage",
      )
          : null,
    );
  }

  // Helper method to get color for current level
  Color _getLevelColor() {
    switch (_selectedLevel) {
      case 'beginner':
        return const Color(0xFF4CAF50); // Green
      case 'intermediate':
        return const Color(0xFFFF9800); // Orange
      case 'advanced':
        return const Color(0xFFF44336); // Red
      default:
        return const Color(0xFF2196F3); // Blue
    }
  }


  // error highlighting of the passage

  Widget _buildHighlightedPassage() {
    final words = _tokens(_currentPassage);
    final spans = <TextSpan>[];

    for (int i = 0; i < words.length; i++) {
      final mispronounced = _mispronouncedIndices.contains(i);
      final missed = _missedIndices.contains(i);

      Color backgroundColor = Colors.transparent;
      if (mispronounced) {
        backgroundColor = const Color(0xFFFFE89A); // Yellow for mispronounced
      } else if (missed) {
        backgroundColor = const Color(0xFFFFCDD2); // Red for missed
      }

      spans.add(
        TextSpan(
          text: words[i] + (i == words.length - 1 ? "" : " "),
          style: TextStyle(
            fontSize: (_currentPassage.length > 300 ? 20 : 22) * _fontSizeMultiplier,
            height: 1.6,
            fontWeight: FontWeight.w700,
            fontFamily: "Lexend",
            color: Colors.black87,
            backgroundColor: backgroundColor,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.black),
            children: spans,
          ),
          overflow: TextOverflow.visible,
        ),
        if (_currentPassage.length > 500)
          Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: Text(
              "(Text truncated for practice. Scroll in original document for full content.)",
              style: TextStyle(
                fontSize: 14 * _fontSizeMultiplier,
                fontStyle: FontStyle.italic,
                color: Colors.grey[600],
                fontFamily: "Lexend",
              ),
            ),
          ),
      ],
    );
  }

  Widget _card({required Widget child, Color color = Colors.white}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, spreadRadius: 1)
        ],
      ),
      child: child,
    );
  }

  Widget _primaryBtn({
    required VoidCallback? onTap,
    required Color color,
    required IconData icon,
    required String label,
    bool animate = false,
    bool isSmall = false,
  }) {
    final btn = ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: isSmall ? 20 : 28, color: Colors.black87),
      label: Text(
        label,
        style: TextStyle(
            fontSize: isSmall ? 16 : 20,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
            fontFamily: "Lexend"),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: isSmall
            ? const EdgeInsets.symmetric(vertical: 12, horizontal: 8)
            : const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 4,
      ),
    );

    if (!animate) return btn;
    return ScaleTransition(scale: _micScale, child: btn);
  }

  Widget _sectionTitle(String s) {
    return Text(
      s,
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF0E4A4A),
        fontFamily: "Lexend",
      ),
    );
  }

  Widget _metricRow(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use Column on very small screens to prevent overflow
        if (constraints.maxWidth < 300) {
          return Column(
            children: [
              _card(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("WPM",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            fontFamily: "Lexend")),
                    const SizedBox(height: 6),
                    Text(
                      _wpm.isNaN ? "0.0" : _wpm.toStringAsFixed(1),
                      style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          fontFamily: "Lexend"),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Accuracy",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            fontFamily: "Lexend")),
                    const SizedBox(height: 6),
                    Text(
                      "${_accuracy.isNaN ? "0.0" : _accuracy.toStringAsFixed(1)}%",
                      style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          fontFamily: "Lexend"),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        // Use Row on larger screens
        return Row(
          children: [
            Expanded(
              child: _card(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("WPM",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            fontFamily: "Lexend")),
                    const SizedBox(height: 6),
                    Flexible(
                      child: Text(
                        _wpm.isNaN ? "0.0" : _wpm.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            fontFamily: "Lexend"),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _card(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text("Accuracy",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              fontFamily: "Lexend"),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(height: 6),
                    Flexible(
                      child: Text(
                        "${_accuracy.isNaN ? "0.0" : _accuracy.toStringAsFixed(1)}%",
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            fontFamily: "Lexend"),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLevelOption(String level, String description) {
    final isSelected = _selectedLevel == level;
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _changeLevel(level, isManual: true);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? _getLevelColor().withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? _getLevelColor() : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? _getLevelColor() : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level[0].toUpperCase() + level.substring(1),
                    style: TextStyle(
                      fontFamily: "Lexend",
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? _getLevelColor() : Colors.black87,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontFamily: "Lexend",
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Substitution {
  final String expected;
  final String heard;
  _Substitution({required this.expected, required this.heard});
}