import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/hive_store.dart';
import '../services/learning_profile_service.dart';

enum PracticePhase { listen, practice, results }

class VocabularyPracticeScreen extends StatefulWidget {
  final String uid;
  const VocabularyPracticeScreen({super.key, required this.uid});

  @override
  State<VocabularyPracticeScreen> createState() => _VocabularyPracticeScreenState();
}

class _VocabularyPracticeScreenState extends State<VocabularyPracticeScreen> {
  late FlutterTts _tts;
  PracticePhase _phase = PracticePhase.listen;
  int _streak = 0;
  int _totalCorrect = 0;
  bool _isLoading = false;
  String _currentBadge = "";
  int _attempts = 0;
  bool _practiceCustomOnly = false;
  bool _keyboardUppercase = false;
  String _selectedDifficulty = "medium";
  String _displayLevel = "Intermediate"; // For UI display
  bool _isAdaptiveEnabled = true; // Track if adaptive learning is enabled

  final Map<String, List<String>> _wordBank = {
    "easy": [
      "garden",
      "sunshine",
      "puzzle",
      "wonder",
      "brave",
      "adventure",
      "friendship",
      "joyful",
      "curious",
      "sparkle",

      "rainbow", "butterfly", "treasure", "whisper", "courage",
      "dolphin", "harmony", "journey", "kindness", "laughter",
      "miracle", "nurture", "orchard", "peaceful", "quietly",
      "silence", "twilight", "uplift", "vibrant", "wander",
      "yonder", "zestful", "blossom", "crystal", "daydream",
    ],
    "medium": [
      "accommodate",
      "benevolent",
      "facilitate",
      "resilience",
      "tranquility",
      "magnanimous",
      "idiosyncrasy",
      "precision",
      "harmony",
      "navigate",

      "articulate", "commemorate", "deliberate", "elaborate", "formidable",
      "gratitude", "hypothesis", "integrate", "jurisdiction", "legitimate",
      "magnificent", "noteworthy", "obligation", "perspective", "qualification",
      "recognition", "substantial", "transcend", "undeniable", "versatile",
      "willingness", "exceptional", "foundation", "generation", "illustrate",
    ],
    "hard": [
      "juxtaposition",
      "cacophony",
      "obfuscate",
      "pernicious",
      "quintessential",
      "ubiquitous",
      "vociferous",
      "xenophobia",
      "languorous",
      "hierarchy",

      "antithesis", "bellicose", "capricious", "disparate", "equivocate",
      "facetious", "grandiose", "hegemony", "incongruous", "judicious",
      "kaleidoscope", "labyrinth", "meticulous", "nefarious", "obsequious",
      "paradigm", "quandary", "resilient", "sycophant", "taciturn",
      "ubiquity", "vicarious", "wanderlust", "xenophile", "yesteryear",
      "zeitgeist", "allegory", "bombastic", "catalyst", "didactic",
    ],
  };


  // custom words
  List<String> _customWords = [];
  late String _currentWord;
  List<String> _selectedLetters = [];
  String _message = "";
  bool _isCorrect = false;

  // Badges and rewards
  final Map<String, String> _badges = {
    "3_streak": "🔥 3-Word Streak",
    "5_streak": "⭐ 5-Word Streak",
    "10_streak": "🏆 Master Speller",
    "perfect_score": "✅ Perfect Score",
    "first_try": "🚀 First Try",
    "quick_learner": "⚡ Quick Learner"
  };

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _loadCustomWords();
    _loadAdaptiveDifficulty();
  }

  Future<void> _loadCustomWords() async {
    try {
      setState(() => _isLoading = true);
      final words = await HiveService(widget.uid).getCustomVocabularyWords();
      if (mounted) {
        setState(() {
          _customWords = words ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _customWords = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadAdaptiveDifficulty() async {
    if (!mounted) return;

    // Load adaptive learning state
    final adaptiveEnabled = await LearningProfileService.instance.isVocabAdaptiveEnabled();
    final currentLevel = await LearningProfileService.instance.getCurrentVocabLevel();

    setState(() {
      _isAdaptiveEnabled = adaptiveEnabled;
      if (adaptiveEnabled) {
        // Use adaptive level
        _selectedDifficulty = currentLevel;
      } else {
        // Use recommended level if adaptive is disabled
        _selectedDifficulty = currentLevel;
      }
      _displayLevel = _difficultyToDisplayLevel(_selectedDifficulty);
    });
    _startNewWord();
  }

  String _difficultyToDisplayLevel(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return 'Beginner';
      case 'medium':
        return 'Intermediate';
      case 'hard':
        return 'Advanced';
      default:
        return 'Intermediate';
    }
  }


  // level display

  String _displayLevelToDifficulty(String displayLevel) {
    switch (displayLevel) {
      case 'Beginner':
        return 'easy';
      case 'Intermediate':
        return 'medium';
      case 'Advanced':
        return 'hard';
      default:
        return 'medium';
    }
  }

  Future<void> _changeLevel(String newLevel, {bool isManual = false}) async {
    final difficulty = _displayLevelToDifficulty(newLevel);

    // If manually changed, disable adaptive learning
    if (isManual) {
      await LearningProfileService.instance.setCurrentVocabLevel(difficulty, isManual: true);
      setState(() {
        _isAdaptiveEnabled = false;
        _displayLevel = newLevel;
        _selectedDifficulty = difficulty;
      });
    } else {
      // Automatic progression - keep adaptive enabled
      await LearningProfileService.instance.setCurrentVocabLevel(difficulty, isManual: false);
      setState(() {
        _displayLevel = newLevel;
        _selectedDifficulty = difficulty;
      });
    }
    _startNewWord();
  }


  // use words based on selected level
  void _startNewWord() {
    // Use only custom words if the flag is set, otherwise use all words
    final baseWords =
    List<String>.from(_wordBank[_selectedDifficulty] ?? _wordBank['medium']!);
    final practiceWords =
    _practiceCustomOnly ? _customWords : [...baseWords, ..._customWords];      // custom word practice

    if (practiceWords.isEmpty) {
      setState(() {
        _message = _practiceCustomOnly
            ? "You haven't added any custom words yet! Tap the + button to add some."
            : "No words available for practice";
        _phase = PracticePhase.results;
        _isCorrect = false;
      });
      return;
    }


    setState(() {
      _currentWord = practiceWords[Random().nextInt(practiceWords.length)];
      _selectedLetters = [];
      _phase = PracticePhase.listen;
      _message = "";
      _isCorrect = false;
      _currentBadge = "";
      _attempts = 0;
    });
  }

  void _practiceSameWordAgain() {
    setState(() {
      _selectedLetters = [];
      _phase = PracticePhase.listen;
      _message = "";
      _isCorrect = false;
      _currentBadge = "";
      _attempts = 0;
    });
  }

  Future<void> _playWord() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.speak(_currentWord);
  }
  bool _isPlaying = false; //  variable to state class


  Future<void> _playSyllables() async {
    // Prevent multiple taps while already playing
    if (_isPlaying) {
      await _tts.stop(); // Stop current speech if tapped again
      setState(() {
        _isPlaying = false;
      });
      return;
    }

    setState(() {
      _isPlaying = true;
    });

    try {
      // Stop any ongoing speech and wait for it to complete
      await _tts.stop();
      await Future.delayed(const Duration(milliseconds: 100));

      // Ensure TTS is properly configured
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.4);
      await _tts.setPitch(1.0);

      // Pronounce each letter with its NORMAL SOUND (a, b, c, d)
      for (int i = 0; i < _currentWord.length; i++) {
        String letter = _currentWord[i];

        // Speak the letter directly - TTS will pronounce it normally
        await _tts.speak(letter);
        await _tts.awaitSpeakCompletion(true);

        // Add pause between letters (except after the last one)
        if (i < _currentWord.length - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    } catch (e) {
      print("TTS Error: $e");
      // Fallback: just speak the word normally
      await _tts.speak(_currentWord);
    } finally {
      setState(() {
        _isPlaying = false;
      });
    }
  }
  void _handleLetterTap(String letter) {
    if (_phase == PracticePhase.practice) {
      setState(() {
        _selectedLetters.add(letter);
      });
    }
  }

  void _removeLastLetter() {
    if (_selectedLetters.isNotEmpty) {
      setState(() {
        _selectedLetters.removeLast();
      });
    }
  }


  // check the performance
  Future<void> _submitAnswer() async {
    _attempts++;
    final selectedWord = _selectedLetters.join('').toLowerCase();
    final targetWord = _currentWord.toLowerCase();

    setState(() {
      _isCorrect = selectedWord == targetWord;       // string comparison

      if (_isCorrect) {
        _streak++;
        _totalCorrect++;
        _message = "Excellent! You spelled it correctly!";
        _awardBadges();
      } else {
        _streak = 0;
        _message = "Almost! The correct word is ${_currentWord.toUpperCase()}";
      }

      _phase = PracticePhase.results;
    });

    // Pronounce the word again for reinforcement after a short delay
    Future.delayed(const Duration(milliseconds: 800), () {
      _playWord();
    });

    // Save results
    _saveResult();
    LearningProfileService.instance.updateVocabularySession(
      totalAttempts: 1,
      correctAttempts: _isCorrect ? 1 : 0,
    );

    // Automatic adaptive learning: Progress level automatically when user performs well
    if (_isAdaptiveEnabled && _isCorrect && mounted) {
      final shouldProgress = await LearningProfileService.instance.shouldProgressVocabLevel(_selectedDifficulty);

      if (shouldProgress) {
        final nextLevelDifficulty = LearningProfileService.instance.getNextVocabLevel(_selectedDifficulty);
        final nextDisplayLevel = _difficultyToDisplayLevel(nextLevelDifficulty);

        // Progress the level in the service
        await LearningProfileService.instance.progressVocabLevel();

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            // Automatically progress level
            _changeLevel(nextDisplayLevel, isManual: false);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Level automatically upgraded to $nextDisplayLevel! 🚀'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        });
      }
    }
  }

  void _awardBadges() {
    if (_streak >= 3 && _streak < 5) {
      _currentBadge = _badges["3_streak"]!;
    } else if (_streak >= 5 && _streak < 10) {
      _currentBadge = _badges["5_streak"]!;
    } else if (_streak >= 10) {
      _currentBadge = _badges["10_streak"]!;
    } else if (_selectedLetters.length == _currentWord.length && _isCorrect) {
      _currentBadge = _badges["perfect_score"]!;
    } else if (_totalCorrect == 1) {
      _currentBadge = _badges["first_try"]!;
    } else if (_attempts == 1 && _isCorrect) {
      _currentBadge = _badges["quick_learner"]!;
    }
  }

  String _capitalizeFirstLetter(String word) {
    if (word.isEmpty) return word;

    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }


  //result saved
  Future<void> _saveResult() async {
    try {
      await HiveService(widget.uid).saveVocabularyResult(words: [
        {
          "word": _currentWord,
          "streak": _streak,
          "accuracy": _isCorrect ? 100 : 0,
          "timestamp": DateTime.now().toString(),
          "badge": _currentBadge,
          "attempts": _attempts
        }
      ]);
    } catch (e) {
      print('Save error: $e');
    }
  }



  // function to add custom words
  void _addCustomWord() {
    final TextEditingController controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFFBF5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Add New Word",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Lexend",
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(fontSize: 18, fontFamily: "OpenDyslexic"),
                decoration: InputDecoration(
                  hintText: "Type your word here...",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF4CAF50)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 70,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          side: const BorderSide(color: Color(0xFF757575), width: 3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            fontFamily: "Lexend",
                            letterSpacing: 1.5,
                            color: Color(0xFF424242),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 70,
                      child: ElevatedButton(
                        onPressed: () async {
                          final word = controller.text.trim().toLowerCase();
                          if (word.isNotEmpty && word.length >= 2) {
                            try {
                              await HiveService(widget.uid).addCustomWord(word);
                              await _loadCustomWords();
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added "$word" successfully!'),
                                  backgroundColor: const Color(0xFF4CAF50),
                                ),
                              );
                            } catch (e) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Error adding word'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFF2E7D32), width: 3),
                          ),
                          elevation: 4,
                        ),
                        child: const Text(
                          "Add Word",
                          style: TextStyle(
                            fontSize: 22,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: "Lexend",
                            letterSpacing: 1.5,
                          ),
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


  // view custom words here
  void _viewCustomWords() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Color(0xFFFFFBF5),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 50,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "My Word Dictionary",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: "Lexend",
                    ),
                  ),
                  // Add Practice Button if there are custom words
                  if (_customWords.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 70,
                      child: ElevatedButton(
                        onPressed: () {
                          // Close the word list
                          Navigator.pop(context);
                          // Set to practice only custom words
                          setState(() {
                            _practiceCustomOnly = true;
                            _startNewWord();
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFF2E7D32), width: 3),
                          ),
                          elevation: 4,
                        ),
                        child: const Text(
                          "🔄 Practice These Words",
                          style: TextStyle(
                            fontSize: 22,
                            color: Colors.white,
                            fontFamily: "Lexend",
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: _customWords.isEmpty
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.book_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      "No words yet",
                      style: TextStyle(fontSize: 20, fontFamily: "Lexend"),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Add words to practice!",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _customWords.length,
                itemBuilder: (context, index) => Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF2196F3).withOpacity(0.3)),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.book, color: Color(0xFF2196F3)),
                    title: Text(
                      _customWords[index].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: "Lexend",
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteCustomWord(_customWords[index]),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 70,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFF1565C0), width: 3),
                    ),
                    elevation: 4,
                  ),
                  child: const Text(
                    "Close",
                    style: TextStyle(
                      fontSize: 22,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: "Lexend",
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCustomWord(String word) async {
    final currentContext = context; // Save context reference

    showDialog(
      context: currentContext,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFBF5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Delete Word?",
          style: TextStyle(fontFamily: "Lexend", fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Delete "$word" from your dictionary?',
          style: const TextStyle(fontFamily: "Lexend"),
        ),
        actions: [
          SizedBox(
            height: 60,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                side: const BorderSide(color: Color(0xFF757575), width: 3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                "Cancel",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Lexend",
                  letterSpacing: 1.5,
                  color: Color(0xFF424242),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 60,
            child: ElevatedButton(
              onPressed: () async {
                try {
                  // Close the dialog first
                  Navigator.pop(context);

                  // Check if widget is still mounted before proceeding
                  if (!mounted) return;

                  await HiveService(widget.uid).deleteCustomWord(word);
                  await _loadCustomWords();

                  // Check again if widget is still mounted
                  if (!mounted) return;

                  // Close the word list bottom sheet if it's still open
                  Navigator.of(currentContext).pop();

                  ScaffoldMessenger.of(currentContext).showSnackBar(
                    SnackBar(
                      content: Text('Deleted "$word"'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(currentContext).showSnackBar(
                      const SnackBar(
                        content: Text('Error deleting word'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFC62828), width: 3),
                ),
                elevation: 4,
              ),
              child: const Text(
                "Delete",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Lexend",
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseWordCount = _wordBank[_selectedDifficulty]?.length ?? 0;
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBF5),
        elevation: 0,
        title: Text(
          _practiceCustomOnly
              ? "Custom Words (${_customWords.length} words)"
              : "Vocabulary Practice (${_customWords.length + baseWordCount} words)",
          style: const TextStyle(fontFamily: "Lexend", fontSize: 13, fontWeight: FontWeight.bold),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.school, size: 28, color: Color(0xFF4A4A4A)),
            onSelected: (level) => _changeLevel(level, isManual: true),
            tooltip: "Change Level",
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'Beginner',
                child: Row(
                  children: [
                    Icon(Icons.check,
                        color: _displayLevel == 'Beginner' ? Colors.green : Colors.transparent),
                    const SizedBox(width: 8),
                    const Text('Beginner', style: TextStyle(fontFamily: "Lexend")),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'Intermediate',
                child: Row(
                  children: [
                    Icon(Icons.check,
                        color: _displayLevel == 'Intermediate' ? Colors.green : Colors.transparent),
                    const SizedBox(width: 8),
                    const Text('Intermediate', style: TextStyle(fontFamily: "Lexend")),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'Advanced',
                child: Row(
                  children: [
                    Icon(Icons.check,
                        color: _displayLevel == 'Advanced' ? Colors.green : Colors.transparent),
                    const SizedBox(width: 8),
                    const Text('Advanced', style: TextStyle(fontFamily: "Lexend")),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.library_books, size: 28, color: Color(0xFF2196F3)),
            onPressed: _viewCustomWords,
            tooltip: "My Words",
          ),
          IconButton(
            icon: const Icon(Icons.add_circle, size: 28, color: Color(0xFF4CAF50)),
            onPressed: _addCustomWord,         // custom word adding
            tooltip: "Add Word",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Adaptive Learning Level Indicator
            if (!_practiceCustomOnly)
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
                    const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    // Only show AI-Driven when adaptive learning is enabled
                    if (_isAdaptiveEnabled)
                      Flexible(
                        child: Text(
                          '',
                          style: const TextStyle(
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _displayLevel.toUpperCase(),
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
            // Mode indicator when practicing custom words only
            Visibility(
              visible: _practiceCustomOnly,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF9800)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Color(0xFFFF9800)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Practicing only your custom words",
                        style: TextStyle(
                          fontFamily: "Lexend",
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _practiceCustomOnly = false;
                          _startNewWord();
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "Show All Words",
                        style: TextStyle(
                          color: const Color(0xFF1976D2),
                          fontFamily: "Lexend",
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            _buildWordDisplay(),
            const SizedBox(height: 24),
            _buildPhaseContent(),
            const SizedBox(height: 24),
            if (_phase == PracticePhase.practice)
              _buildLetterGrid(),
            const SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }


  // displays the words
  Widget _buildWordDisplay() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA), // Better background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2E7D32), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            _capitalizeFirstLetter(_currentWord), // Mixed case
            style: const TextStyle(
              fontSize: 36, // Bigger font
              fontWeight: FontWeight.w600,
              fontFamily: "Lexend",
              color: Color(0xFF2E7D32), // Dyslexia-friendly green
              letterSpacing: 4.0, // Proper spacing between letters
            ),
          ),
          const SizedBox(height: 20),
          // Show selected letters
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4CAF50), width: 1),
            ),
            child: Text(
              _capitalizeFirstLetter(_selectedLetters.join('')), // Mixed case, no .toUpperCase()
              style: const TextStyle(
                fontSize: 24, // Bigger font
                fontWeight: FontWeight.w600,
                fontFamily: "Lexend",
                color: Color(0xFF1B5E20), // Dyslexia-friendly color
                letterSpacing: 2.0, // Letter spacing
              ),
            ),
          ),
          if (_phase == PracticePhase.results) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                // CHANGED: Red color changed to dyslexia-friendly coral
                color: _isCorrect ? const Color(0xFF4CAF50) : const Color(0xFFFF6B6B), // Soft coral for errors
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: (_isCorrect ? const Color(0xFF4CAF50) : const Color(0xFFFF6B6B)).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isCorrect ? Icons.check_circle : Icons.info,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isCorrect ? "CORRECT!" : "TRY AGAIN!",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: "Lexend",
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _message,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontFamily: "Lexend",
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_currentBadge.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _currentBadge,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: "Lexend",
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _playWord,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1976D2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFF1976D2), width: 3),
                        ),
                        elevation: 4,
                      ),
                      child: const Text(
                        "🔊 Hear Word Again",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: "Lexend",
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }


  //Validation purpose  show result card
  Widget _buildPhaseContent() {
    switch (_phase) {
      case PracticePhase.listen:
        return _buildCard(
          "🎧 Listen & Learn!",
          "First, listen to the word and its letters",
          const Color(0xFFE8F5E8),
        );
      case PracticePhase.practice:
        return _buildCard(
          "📝 Practice Spelling!",
          "Tap letters to spell: ${_capitalizeFirstLetter(_currentWord)}\nCurrent streak: $_streak", //  Mixed case
          const Color(0xFFFFF3E0),
        );
      case PracticePhase.results:
        return _buildCard(
          _isCorrect ? "🎉 Excellent Work!" : "💪 Keep Practicing!",
          _isCorrect
              ? "🏆 Your streak: $_streak\n⭐ You're mastering words! ⭐"
              : "The word was: ${_capitalizeFirstLetter(_currentWord)}\nTry again!", // Mixed case
          // CHANGED: Red color changed to dyslexia-friendly coral
          _isCorrect ? const Color(0xFF4CAF50) : const Color(0xFFFF6B6B), // Soft coral for errors
          textColor: Colors.white,
        );
    }
  }

  Widget _buildCard(String title, String subtitle, Color color, {Color textColor = Colors.black}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: "Lexend",
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 18,
              fontFamily: "Lexend",
              height: 1.4,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }


  // build keyboard animated keyboards
// a- z words keyboards
  Widget _buildLetterGrid() {
    // Create a list of all letters in the current word plus some random letters
    Set<String> lettersSet = Set.from(_currentWord.split(''));
    List<String> allLetters = 'abcdefghijklmnopqrstuvwxyz'.split('');
    allLetters.shuffle();

    // Add random letters to make 16 total
    while (lettersSet.length < 16) {
      lettersSet.add(allLetters.removeLast());
    }

    List<String> letterGrid = lettersSet.toList()..shuffle();

    return Column(
      children: [
        // ✅ ADD CASE TOGGLE BUTTON - Dyslexia-friendly
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                _keyboardUppercase = !_keyboardUppercase;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _keyboardUppercase ? const Color(0xFF4CAF50) : const Color(0xFFE3F2FD),
              foregroundColor: _keyboardUppercase ? Colors.white : const Color(0xFF1B5E20),
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: _keyboardUppercase ? const Color(0xFF2E7D32) : const Color(0xFF2196F3),
                  width: 3,
                ),
              ),
              elevation: 4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _keyboardUppercase ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  _keyboardUppercase ? "UPPERCASE" : "lowercase",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: "Lexend",
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.2,
          ),
          itemCount: letterGrid.length,
          itemBuilder: (context, index) {
            final letter = letterGrid[index];
            final displayLetter = _keyboardUppercase ? letter.toUpperCase() : letter; //  Dynamic case

            return ElevatedButton(
              onPressed: () => _handleLetterTap(letter),
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentWord.contains(letter)
                    ? const Color(0xFFE8F5E9) // Light green background for correct letters
                    : Colors.white,
                foregroundColor: _currentWord.contains(letter)
                    ? const Color(0xFF1B5E20) // Dark green text for correct letters
                    : const Color(0xFF424242), // Dark gray for other letters
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: _currentWord.contains(letter)
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFF9E9E9E),
                    width: 3, // Thicker border for better visibility
                  ),
                ),
                elevation: 4,
              ),
              child: Text(
                displayLetter,
                style: TextStyle(
                  fontSize: 32, // Much larger font for dyslexia
                  fontWeight: FontWeight.bold,
                  fontFamily: "Lexend",
                  letterSpacing: 2.0, // Increased letter spacing
                  color: _currentWord.contains(letter)
                      ? const Color(0xFF1B5E20)
                      : const Color(0xFF424242),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 70,
                child: ElevatedButton(
                  onPressed: _removeLastLetter,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF3E0),
                    foregroundColor: const Color(0xFFE65100),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFFF9800), width: 3),
                    ),
                    elevation: 4,
                  ),
                  child: const Text(
                    "← Remove",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: "Lexend",
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 70,
                child: ElevatedButton(
                  onPressed: _submitAnswer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFF2E7D32), width: 3),
                    ),
                    elevation: 4,
                  ),
                  child: const Text(
                    "Submit ",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: "Lexend",
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }


  // action buttons
  Widget _buildActionButtons() {
    if (_phase == PracticePhase.listen) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildButton("🔊 Hear Word", _playWord, const Color(0xFFE3F2FD)),
              ),
              const SizedBox(width: 20), // Increased spacing
              Expanded(
                child: _buildButton("🔤 Hear Letters", _playSyllables, const Color(0xFFFFF3E0)),
              ),
            ],
          ),
          const SizedBox(height: 28), // Increased spacing
          _buildButton("✨ Start Spelling", () {
            setState(() {
              _phase = PracticePhase.practice;
            });
          }, const Color(0xFF2E7D32), textColor: Colors.white),
        ],
      );
    } else if (_phase == PracticePhase.results) {
      return Column(
        children: [
          if (!_isCorrect)
            _buildButton(
                "🔄 Practice Again", // CHANGED: Text changed from "Practice This Word Again" to "Practice Again"
                _practiceSameWordAgain,
                const Color(0xFFFF9800),
                textColor: Colors.white
            ),
          if (!_isCorrect) const SizedBox(height: 16), // Increased spacing
          Row(
            children: [
              if (_isCorrect) Expanded(
                child: _buildButton(
                    "⭐ Continue Streak",
                    _startNewWord,
                    const Color(0xFF4CAF50),
                    textColor: Colors.white
                ),
              ) else Expanded(
                child: _buildButton(
                    "Try Another Word",
                    _startNewWord,
                    const Color(0xFF2196F3),
                    textColor: Colors.white
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildButton(String text, VoidCallback? onPressed, Color color, {Color textColor = Colors.black87}) {
    return SizedBox(
      width: double.infinity,
      height: 100, // INCREASED: From 80 to 100 (larger button)
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: textColor == Colors.white
                  ? Colors.white.withOpacity(0.3)
                  : color.withOpacity(0.5),
              width: 3,
            ),
          ),
          elevation: onPressed != null ? 6 : 1,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 20, // DECREASED: From 24 to 20 (to fit larger button better)
            fontWeight: FontWeight.bold,
            fontFamily: "Lexend",
            color: textColor,
            letterSpacing: 1.5, // Good letter spacing for dyslexia
            height: 1.3, // Better line height
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Color _getLevelColor() {
    switch (_displayLevel) {
      case 'Beginner':
        return const Color(0xFF4CAF50); // Green
      case 'Intermediate':
        return const Color(0xFFFF9800); // Orange
      case 'Advanced':
        return const Color(0xFFF44336); // Red
      default:
        return const Color(0xFF2196F3); // Blue
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}