import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:learning_app/services/hive_store.dart';
import 'package:learning_app/services/learning_profile_service.dart';
import 'package:learning_app/services/local_language_tool_service.dart';
import 'package:learning_app/services/writing_evaluator.dart';
import 'package:learning_app/services/writing_prompt_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class WritingPracticeScreen extends StatefulWidget {
  final String uid;
  const WritingPracticeScreen({super.key, required this.uid});

  @override
  State<WritingPracticeScreen> createState() => _WritingPracticeScreenState();
}

class _WritingPracticeScreenState extends State<WritingPracticeScreen> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _preferenceController = TextEditingController();

  final WritingPromptService _promptService = WritingPromptService.instance;
  final LocalLanguageToolService _languageTool = LocalLanguageToolService.instance;
  final WritingEvaluator _evaluator = WritingEvaluator.instance;

  late final HiveService _storage;
  late stt.SpeechToText _speech;

  String _currentPrompt = '';
  String _difficulty = 'beginner';
  String _preference = 'general';

  bool _isGeneratingPrompt = false;
  bool _isAnalyzing = false;
  bool _isSubmitting = false;
  bool _isListening = false;

  List<LanguageIssue> _spellingIssues = [];
  List<LanguageIssue> _grammarIssues = [];
  int _wordCount = 0;

  // Accessibility settings - Default to larger dyslexia-friendly sizes
  double _fontSize = 22.0; // Increased from 16.0
  double _lineHeight = 1.6; // Increased from 1.5
  double _letterSpacing = 1.0; // Increased from 0.0
  String _selectedFont = 'Lexend';

  // Word suggestions
  Map<String, List<String>> _wordSuggestions = {};

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _storage = HiveService(widget.uid);
    _speech = stt.SpeechToText();
    _controller.addListener(_updateWordCount);
    _controller.addListener(_scheduleLiveAnalysis);
    _loadPreferences();
    _loadAccessibilitySettings();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _preferenceController.dispose();
    super.dispose();
  }


  // counts word
  void _updateWordCount() {
    final text = _controller.text.trim();
    setState(() {
      _wordCount = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;     //splits counts
    });
  }


  // checking instant checking of issues
  void _scheduleLiveAnalysis() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      if (_controller.text.trim().isNotEmpty) {
        _analyzeText();    // analyze function called
      } else {
        setState(() {
          _spellingIssues = [];
          _grammarIssues = [];
        });
      }
    });
  }

  Future<void> _generatePrompt() async {
    setState(() => _isGeneratingPrompt = true);
    await Future.delayed(const Duration(milliseconds: 300));
    final prompt = _promptService.generatePrompt(  //calls generate prompt service
      difficulty: _difficulty,
      preference: _preference,
    );
    setState(() {
      _currentPrompt = prompt;
      _controller.clear();
      _spellingIssues = [];
      _grammarIssues = [];
      _wordCount = 0;
      _isGeneratingPrompt = false;
    });
  }


  //cheks writing during typing
  Future<void> _analyzeText() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() {
        _spellingIssues = [];
        _grammarIssues = [];
        _wordSuggestions = {};
      });
      return;
    }

    setState(() => _isAnalyzing = true);
    await Future.delayed(const Duration(milliseconds: 200));
    final analysis = _languageTool.analyzeText(text);  // calls language tool
    
    // Generate word suggestions for errors
    final suggestions = <String, List<String>>{};
    for (final issue in analysis.spelling) {
      suggestions[issue.word] = _generateWordSuggestions(issue.word);
    }
    
    setState(() {
      _spellingIssues = analysis.spelling;
      _grammarIssues = analysis.grammar;
      _wordSuggestions = suggestions;
      _isAnalyzing = false;
    });
  }

  List<String> _generateWordSuggestions(String word) {
    // Simple suggestion algorithm based on common misspellings
    final suggestions = <String>[];
    final lower = word.toLowerCase();
    
    // Common patterns
    if (lower.endsWith('ing')) {
      suggestions.add(lower.substring(0, lower.length - 3));
    }
    if (lower.endsWith('ed')) {
      suggestions.add(lower.substring(0, lower.length - 2));
    }
    if (lower.endsWith('ly')) {
      suggestions.add(lower.substring(0, lower.length - 2));
    }
    
    // Add some common corrections
    final commonCorrections = {
      'teh': 'the',
      'adn': 'and',
      'taht': 'that',
      'recieve': 'receive',
      'seperate': 'separate',
      'occured': 'occurred',
    };
    
    if (commonCorrections.containsKey(lower)) {
      suggestions.add(commonCorrections[lower]!);
    }
    
    return suggestions.take(3).toList();
  }

  Future<void> _submitAnswer() async {
    final response = _controller.text.trim();
    if (response.isEmpty) {
      Fluttertoast.showToast(msg: 'Write your answer before submitting.');
      return;
    }

    setState(() => _isSubmitting = true);
    final evaluation = _evaluator.evaluate(prompt: _currentPrompt, response: response);
    await _storage.saveWritingResult(                     // save result
      prompt: _currentPrompt,
      userResponse: response,
      spellingErrors: _spellingIssues.length,
      grammarErrors: _grammarIssues.length,
      punctuationErrors: 0,
      accessibilitySettings: {
        'difficulty': _difficulty,
        'preference': _preference,
      },
      wordCount: evaluation.metrics.wordCount,
      sentenceCount: evaluation.metrics.sentenceCount,
      correctedText: response,
    );

    final qualityScore = evaluation.metrics.typeTokenRatio;              //lexical diversity from writing evaluator
    await LearningProfileService.instance.updateWritingQuality(qualityScore);
    
    // Suggest level
    // Adaptive learning: Update difficulty based on performance
    final currentDifficultyScore = _difficulty == 'beginner' ? 0.3 : 
                                   _difficulty == 'intermediate' ? 0.6 : 0.9;
    if (qualityScore > 0.7 && _difficulty == 'beginner') {
      // Suggest intermediate after good performance
      if (mounted) {
        Future.delayed(const Duration(seconds: 1), () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text(
                'Great Progress!',
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: const Text(
                'You\'re doing well! Would you like to try intermediate level prompts?',
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 20,
                  letterSpacing: 1.0,
                ),
              ),
              actions: [
                SizedBox(
                  height: 60,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Stay at Beginner',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _updateDifficulty('intermediate');
                      _generatePrompt();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    child: const Text(
                      'Try Intermediate',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      }
    }
    await _storage.saveUserPreferences({
      'difficulty': _difficulty,
      'preference': _preference,
    });

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Writing feedback', style: _boldStyle()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Level: ${evaluation.level}', style: _bodyStyle()),
              const SizedBox(height: 16),
              Text(evaluation.feedback, style: _bodyStyle()),
              const SizedBox(height: 20),
              Text('Metrics', style: _boldStyle()),
              const SizedBox(height: 12),
              _metricRow('Words', evaluation.metrics.wordCount.toString()),
              _metricRow('Sentences', evaluation.metrics.sentenceCount.toString()),
              _metricRow('Avg sentence length',
                  evaluation.metrics.averageSentenceLength.toStringAsFixed(1)),
              _metricRow('Lexical diversity',
                  evaluation.metrics.typeTokenRatio.toStringAsFixed(2)),
            ],
          ),
        ),
        actions: [
          SizedBox(
            height: 60,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              child: const Text(
                'Close',
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    setState(() => _isSubmitting = false);
  }

  TextStyle _bodyStyle() => const TextStyle(
    fontFamily: 'Lexend',
    fontSize: 22,
    letterSpacing: 1.0,
    color: Color(0xFF2D3748),
  );
  TextStyle _boldStyle() => const TextStyle(
    fontFamily: 'Lexend',
    fontWeight: FontWeight.bold,
    fontSize: 24,
    letterSpacing: 1.5,
    color: Color(0xFF2D3748),
  );

  Widget _metricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Lexend',
              fontSize: 20,
              color: Color(0xFF2D3748),
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Lexend',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
        ],
      ),
    );
  }

  void _updateDifficulty(String difficulty) {
    setState(() {
      _difficulty = difficulty;
    });
  }

  void _updatePreference(String preference) {
    setState(() {
      _preference = preference;
      _preferenceController.text = preference;
    });
  }


  //user preferences
  Future<void> _loadPreferences() async {
    final prefs = await _storage.getUserPreferences();
    if (prefs != null) {
      setState(() {
        _difficulty = prefs['difficulty']?.toString() ?? _difficulty;
        _preference = prefs['preference']?.toString() ?? _preference;
        _preferenceController.text = _preference;
      });
    } else {
      _preferenceController.text = _preference;
    }
    await _generatePrompt();
  }

  Future<void> _loadAccessibilitySettings() async {
    final prefs = await _storage.getUserPreferences();
    if (prefs != null && prefs['accessibility'] != null) {
      final acc = prefs['accessibility'] as Map<String, dynamic>;
      setState(() {
        _fontSize = (acc['fontSize'] as num?)?.toDouble() ?? 16.0;
        _lineHeight = (acc['lineHeight'] as num?)?.toDouble() ?? 1.5;
        _letterSpacing = (acc['letterSpacing'] as num?)?.toDouble() ?? 0.0;
        _selectedFont = acc['font']?.toString() ?? 'Lexend';
      });
    }
  }

  Future<void> _saveAccessibilitySettings() async {
    await _storage.saveUserPreferences({
      'accessibility': {
        'fontSize': _fontSize,
        'lineHeight': _lineHeight,
        'letterSpacing': _letterSpacing,
        'font': _selectedFont,
      },
    });
  }


  // speech to text
  Future<void> _startListening() async {
    final isAvailable = await _speech.initialize(
      onStatus: (status) => print('Speech status: $status'),
      onError: (error) {
        if (mounted) {
          Fluttertoast.showToast(msg: 'Speech error: ${error.errorMsg}');
        }
      },
    );

    if (!isAvailable) {
      if (mounted) {
        Fluttertoast.showToast(msg: 'Speech recognition not available');
      }
      return;
    }

    setState(() => _isListening = true);

    _speech.listen(
      onResult: (result) {
        setState(() {
          _controller.text = result.recognizedWords;
          _updateWordCount();
        });
      },
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      cancelOnError: true,
      listenFor: const Duration(minutes: 5),
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF2),
      appBar: AppBar(
        title: const Text(
          'Writing Practice',
          style: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        backgroundColor: const Color(0xFFFFFBF2),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.accessibility_new),
            onPressed: () => _showAccessibilityDialog(),
            tooltip: 'Accessibility Settings',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isGeneratingPrompt ? null : _generatePrompt,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPromptCard(),
            const SizedBox(height: 20),
            _buildControls(),
            const SizedBox(height: 20),
            _buildEditor(),
            const SizedBox(height: 20),
            _buildIssueSummary(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildPromptCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your prompt',
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: Color(0xFF2D3748),
                ),
              ),
              if (_isGeneratingPrompt)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _currentPrompt.isEmpty
                ? 'Tap refresh to get a new prompt.'
                : _currentPrompt,
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 22, // Increased from 16
              height: 1.6, // Increased from 1.5
              letterSpacing: 1.0,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2D3748),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Customize prompt',
          style: TextStyle(
            fontFamily: 'Lexend',
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 1.0,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _difficultyChip('beginner'),
            _difficultyChip('intermediate'),
            _difficultyChip('advanced'),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _preferenceController,
          style: const TextStyle(
            fontFamily: 'Lexend',
            fontSize: 20,
            letterSpacing: 1.0,
          ),
          decoration: InputDecoration(
            labelText: 'Interests (e.g., animals, travel, technology)',
            labelStyle: const TextStyle(
              fontFamily: 'Lexend',
              fontSize: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 3),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            suffixIcon: IconButton(
              icon: const Icon(Icons.save, size: 28),
              onPressed: () {
                _updatePreference(_preferenceController.text.trim().isEmpty
                    ? 'general'
                    : _preferenceController.text.trim());
                Fluttertoast.showToast(msg: 'Preferences updated');
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _preferenceChip('general'),
            _preferenceChip('animals'),
            _preferenceChip('travel'),
            _preferenceChip('science'),
            _preferenceChip('community'),
          ],
        ),
      ],
    );
  }

  Widget _difficultyChip(String value) {
    final selected = _difficulty == value;
    return ChoiceChip(
      label: Text(
        value[0].toUpperCase() + value.substring(1),
        style: const TextStyle(
          fontFamily: 'Lexend',
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
      selected: selected,
      onSelected: (_) {
        _updateDifficulty(value);
        _generatePrompt();
      },
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      selectedColor: const Color(0xFF4CAF50),
      backgroundColor: const Color(0xFFE8F5E9),
      side: BorderSide(
        color: selected ? const Color(0xFF2E7D32) : const Color(0xFF81C784),
        width: 2,
      ),
    );
  }

  Widget _preferenceChip(String value) {
    final selected = _preference.toLowerCase() == value.toLowerCase();
    return ChoiceChip(
      label: Text(
        value,
        style: const TextStyle(
          fontFamily: 'Lexend',
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
      selected: selected,
      onSelected: (_) {
        _updatePreference(value);
        _generatePrompt();
      },
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      selectedColor: const Color(0xFF4CAF50),
      backgroundColor: const Color(0xFFE8F5E9),
      side: BorderSide(
        color: selected ? const Color(0xFF2E7D32) : const Color(0xFF81C784),
        width: 2,
      ),
    );
  }


  // editor text editor

  Widget _buildEditor() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your response',
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: Color(0xFF2D3748),
                ),
              ),
              Text(
                '$_wordCount words',
                style: const TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 20,
                  color: Color(0xFF2D3748),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            minLines: 8,
            maxLines: null,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Start writing your answer here...',
              hintStyle: TextStyle(
                fontFamily: _selectedFont,
                fontSize: _fontSize,
                color: Colors.grey[500],
                letterSpacing: _letterSpacing,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              suffixIcon: IconButton(
                icon: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  size: 32,
                  color: _isListening ? Colors.red : Colors.grey,
                ),
                onPressed: _isListening ? _stopListening : _startListening,
                tooltip: _isListening ? 'Stop recording' : 'Start voice input',
              ),
            ),
            style: TextStyle(
              fontFamily: _selectedFont,
              fontSize: _fontSize, // Now defaults to 22
              height: _lineHeight, // Now defaults to 1.6
              letterSpacing: _letterSpacing, // Now defaults to 1.0
              color: const Color(0xFF2D3748),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }


  // issues grammar and spelling
  Widget _buildIssueSummary() {
    final hasIssues = _spellingIssues.isNotEmpty || _grammarIssues.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: hasIssues ? Colors.white : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(18),
        boxShadow: hasIssues
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.spellcheck, color: Color(0xFF4C8CBF)),
              const SizedBox(width: 8),
              Text(
                hasIssues ? 'Suggestions found' : 'No issues detected',
                style: const TextStyle(
                  fontFamily: 'Lexend',
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  letterSpacing: 1.0,
                  color: Color(0xFF2D3748),
                ),
              ),
              if (_isAnalyzing) ...[
                const SizedBox(width: 10),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ]
            ],
          ),
          const SizedBox(height: 16),
          if (hasIssues)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_spellingIssues.isNotEmpty) ...[
                  const Text('Spelling',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        letterSpacing: 1.0,
                        color: Color(0xFF2D3748),
                      )),
                  const SizedBox(height: 8),
                  ..._spellingIssues.map(_issueTile).toList(),
                  const SizedBox(height: 16),
                ],
                if (_grammarIssues.isNotEmpty) ...[
                  const Text('Grammar',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        letterSpacing: 1.0,
                        color: Color(0xFF2D3748),
                      )),
                  const SizedBox(height: 8),
                  ..._grammarIssues.map(_issueTile).toList(),
                ],
              ],
            )
          else
            const Text(
              'Great work! Keep refining your response or submit when ready.',
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 20,
                letterSpacing: 1.0,
                color: Color(0xFF2D3748),
              ),
            ),
        ],
      ),
    );
  }

  // errors colors when typing
  Widget _issueTile(LanguageIssue issue) {
    final color = issue.type == LanguageIssueType.spelling
        ? const Color(0xFFE74C3C)
        : const Color(0xFF27AE60);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(issue.word,
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          letterSpacing: 1.0,
                          color: color,
                        )),
                    const SizedBox(height: 8),
                    Text(issue.message,
                        style: const TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 18,
                          letterSpacing: 0.5,
                          color: Color(0xFF2D3748),
                        )),
                  ],
                ),
              ),
              if (_wordSuggestions.containsKey(issue.word) && 
                  _wordSuggestions[issue.word]!.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Suggestions:', 
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        )),
                    const SizedBox(height: 8),
                    ..._wordSuggestions[issue.word]!.map((suggestion) => 
                      InkWell(
                        onTap: () {
                          final text = _controller.text;
                          final newText = text.replaceAll(issue.word, suggestion);
                          _controller.text = newText;
                          _analyzeText();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF2196F3), width: 2),
                          ),
                          child: Text(suggestion,
                              style: const TextStyle(
                                fontFamily: 'Lexend',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1976D2),
                                letterSpacing: 1.0,
                              )),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    // Dyslexia-friendly colors: high contrast, avoid red-green
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isAnalyzing ? null : _analyzeText,
              icon: const Icon(Icons.search, color: Colors.white, size: 28),
              label: const Text('Analyze', 
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  )),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A6FA5), // Blue, not red/green
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFF1976D2), width: 3),
                ),
                elevation: 4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitAnswer,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                    )
                  : const Icon(Icons.check_circle_outline, color: Colors.white, size: 28),
              label: const Text('Submit', 
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  )),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF27AE60), // Green, high contrast
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFF1B5E20), width: 3),
                ),
                elevation: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAccessibilityDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            'Accessibility Settings',
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Font Size',
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Slider(
                  value: _fontSize,
                  min: 18,
                  max: 32,
                  divisions: 14,
                  label: _fontSize.round().toString(),
                  onChanged: (value) {
                    setDialogState(() => _fontSize = value);
                  },
                ),
                Text(
                  '${_fontSize.round()}px',
                  style: const TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Line Spacing',
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Slider(
                  value: _lineHeight,
                  min: 1.2,
                  max: 2.5,
                  divisions: 13,
                  label: _lineHeight.toStringAsFixed(1),
                  onChanged: (value) {
                    setDialogState(() => _lineHeight = value);
                  },
                ),
                Text(
                  _lineHeight.toStringAsFixed(1),
                  style: const TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Letter Spacing',
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Slider(
                  value: _letterSpacing,
                  min: 0.0,
                  max: 3.0,
                  divisions: 30,
                  label: _letterSpacing.toStringAsFixed(1),
                  onChanged: (value) {
                    setDialogState(() => _letterSpacing = value);
                  },
                ),
                Text(
                  _letterSpacing.toStringAsFixed(1),
                  style: const TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            SizedBox(
              height: 60,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  _saveAccessibilitySettings();
                  Navigator.pop(context);
                  setState(() {}); // Refresh UI
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}