import 'package:flutter/material.dart';
import '../services/hive_store.dart';
import '../services/progress_ai_insights.dart';

class ProgressDashboardScreen extends StatefulWidget {
  final String uid;
  const ProgressDashboardScreen({super.key, required this.uid});

  @override
  State<ProgressDashboardScreen> createState() => _ProgressDashboardScreenState();
}

class _ProgressDashboardScreenState extends State<ProgressDashboardScreen> {
  late HiveService _service;
  bool _isLoading = true;
  String _errorMessage = '';
  int _currentTab = 0;

  List<Map<String, dynamic>> _readingResults = [];
  List<Map<String, dynamic>> _writingResults = [];
  List<Map<String, dynamic>> _vocabResults = [];
  ProgressInsights? _insights;

  // Dyslexia-friendly colors
  final Color _background = const Color(0xFFFEFEFE);
  final Color _textColor = const Color(0xFF2D3748);
  final Color _primary = const Color(0xFF4A6FA5);
  final Color _secondary = const Color(0xFFE67E22);
  final Color _success = const Color(0xFF27AE60);
  final Color _warning = const Color(0xFFF39C12);
  final Color _cardColor = const Color(0xFFF8F9FA);
  final Color _accent = const Color(0xFF6C63FF);

  // Bigger font sizes for dyslexia
  final double _fontSizeXL = 28.0;
  final double _fontSizeL = 24.0;
  final double _fontSizeM = 20.0;
  final double _fontSizeS = 18.0;
  final double _fontSizeXS = 16.0;
  final double _fontSizeXXS = 14.0;

  //   badges system  Session progression system - ADDED vocabulary
  final Map<String, int> _sessionGoals = {
    'reading': 10,  // 10 sessions per level
    'writing': 8,   // 8 exercises per level
    'vocabulary': 15, // NEW: 15 words per session
  };

  final List<String> _badgeLevels = [
    'Beginner', 'Learner', 'Advanced', 'Expert', 'Master'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.uid.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'User ID is missing. Please log out and log in again.';
      });
      return;
    }
    print('✅ Progress Dashboard initialized for user: ${widget.uid}');
    _service = HiveService(widget.uid);
    _fetchData();
  }

  // UPDATED: Session progression calculations - ADDED vocabulary
  int _getSessionProgress(String type) {
    if (type == 'vocabulary') {
      final totalWords = _totalVocabularyWords();
      final goal = _sessionGoals[type]!;
      return totalWords % goal;
    }
    final completed = type == 'reading' ? _readingResults.length : _writingResults.length;
    final goal = _sessionGoals[type]!;
    return completed % goal;
  }


  // badges working mechanism

  int _getCurrentSession(String type) {
    if (type == 'vocabulary') {
      final totalWords = _totalVocabularyWords();
      final goal = _sessionGoals[type]!;
      return (totalWords / goal).floor() + 1;
    }
    final completed = type == 'reading' ? _readingResults.length : _writingResults.length;
    final goal = _sessionGoals[type]!;
    return (completed / goal).floor() + 1;
  }

  String _getCurrentBadge(String type) {
    final session = _getCurrentSession(type);
    if (session <= _badgeLevels.length) {
      return _badgeLevels[session - 1];
    }
    return _badgeLevels.last; // Master level for beyond
  }

  int _getCurrentStreak() {
    // Simple streak calculation based on recent activity
    final today = DateTime.now();
    int streak = 0;

    // Check last 7 days for activity
    for (int i = 0; i < 7; i++) {
      final checkDate = today.subtract(Duration(days: i));
      bool hasActivity = _readingResults.any((session) =>
      _getSessionDate(session).day == checkDate.day &&
          _getSessionDate(session).month == checkDate.month &&
          _getSessionDate(session).year == checkDate.year) ||
          _writingResults.any((session) =>
          _getSessionDate(session).day == checkDate.day &&
              _getSessionDate(session).month == checkDate.month &&
              _getSessionDate(session).year == checkDate.year) ||
          _vocabResults.any((session) =>
          _getSessionDate(session).day == checkDate.day &&
              _getSessionDate(session).month == checkDate.month &&
              _getSessionDate(session).year == checkDate.year);

      if (hasActivity) {
        streak++;
      } else if (i == 0) {
        // No activity today, streak continues if yesterday had activity
        continue;
      } else {
        break;
      }
    }
    return streak;
  }

  String _getSessionStatus(String type) {
    final progress = _getSessionProgress(type);
    final goal = _sessionGoals[type]!;
    final session = _getCurrentSession(type);
    final badge = _getCurrentBadge(type);

    if (progress >= goal) {
      return "🎉 Complete!\nNext: Session ${session + 1}";
    }

    if (type == 'vocabulary') {
      return "$progress/$goal words • $badge";
    }
    return "$progress/$goal • $badge";
  }

  // AUTOMATIC GOAL PROGRESSION SYSTEM
  int _getCurrentWritingGoal() {
    final completed = _writingResults.length;
    if (completed < 10) return 10;
    if (completed < 25) return 25;
    if (completed < 50) return 50;
    if (completed < 100) return 100;
    if (completed < 200) return 200;
    return ((completed / 100).ceil() * 100).toInt();
  }

  int _getCurrentReadingGoal() {
    final completed = _readingResults.length;
    if (completed < 20) return 20;
    if (completed < 50) return 50;
    if (completed < 100) return 100;
    if (completed < 200) return 200;
    return ((completed / 50).ceil() * 50).toInt();
  }

  // NEW: Vocabulary goal progression
  int _getCurrentVocabularyGoal() {
    final totalWords = _totalVocabularyWords();
    if (totalWords < 30) return 30;
    if (totalWords < 75) return 75;
    if (totalWords < 150) return 150;
    if (totalWords < 300) return 300;
    return ((totalWords / 50).ceil() * 50).toInt();
  }

  String _getGoalStatus(int completed, int goal) {
    if (completed >= goal) {
      final nextGoal = _getNextGoal(goal);
      return "🎉 $completed/$goal ✅\nNext: $nextGoal";
    }
    return "$completed/$goal";
  }

  int _getNextGoal(int currentGoal) {
    final goals = [10, 20, 25, 50, 75, 100, 150, 200, 250, 300, 400, 500, 750, 1000];
    for (int goal in goals) {
      if (goal > currentGoal) return goal;
    }
    return currentGoal * 2;
  }


  // data fetching from database
  Future<void> _fetchData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      print('Fetching progress data for user: ${widget.uid}');             // load data form database
      final readingResults = await _service.getReadingResults();
      final writingResults = await _service.getWritingResults();
      final vocabResults = await _service.getVocabularyResults();
      
      print('📊 Progress data fetched:');
      print('   - Reading sessions: ${readingResults.length}');
      print('   - Writing sessions: ${writingResults.length}');
      print('   - Vocabulary sessions: ${vocabResults.length}');

      _readingResults = readingResults;
      _writingResults = writingResults;
      _vocabResults = vocabResults;

      _insights = ProgressAiInsights.analyze(                  // passed data to ai insights
        readingSessions: _readingResults,
        writingSessions: _writingResults,
        vocabularySessions: _vocabResults,
      );

    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load your progress data. Please check your connection.';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  DateTime _getSessionDate(Map<String, dynamic> session) {
    try {
      final timestamp = session['timestamp'];
      if (timestamp is String) return DateTime.parse(timestamp);
      return DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }


  // welcome message
  String _getWelcomeMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning! 🌞";
    if (hour < 17) return "Good Afternoon! ☀️";
    return "Good Evening! 🌙";
  }

  String _getMotivationMessage() {
    final streak = _getCurrentStreak();
    if (streak >= 7) return "🔥 Amazing $streak-day streak! You're on fire!";
    if (streak >= 3) return "🚀 Great $streak-day consistency! Keep going!";
    if (_readingResults.isNotEmpty || _writingResults.isNotEmpty || _vocabResults.isNotEmpty) {
      return "💪 You're making progress! Every session counts.";
    }
    return "🎯 Start your first session to begin your learning journey!";
  }

  double _getReadingAccuracy() {
    if (_readingResults.isEmpty) return 0.0;
    double totalAccuracy = 0.0;
    int validResults = 0;
    for (var result in _readingResults) {
      final accuracy = result['accuracy'];
      if (accuracy != null) {
        totalAccuracy += (accuracy is int ? accuracy.toDouble() : accuracy ?? 0);
        validResults++;
      }
    }
    return validResults > 0 ? totalAccuracy / validResults : 0.0;
  }


  //calculates average wpm            .... total wpm/ no of sessions

  double _getAverageWPM() {
    if (_readingResults.isEmpty) return 0.0;
    double totalWPM = 0.0;
    int validResults = 0;
    for (var result in _readingResults) {
      final wpm = result['wpm'];
      if (wpm != null) {
        totalWPM += (wpm is int ? wpm.toDouble() : wpm ?? 0);
        validResults++;
      }
    }
    return validResults > 0 ? totalWPM / validResults : 0.0;
  }

  // Count perfect reading sessions (100% accuracy)

  int _getPerfectReadsCount() {
    int perfectReads = 0;
    for (var result in _readingResults) {
      final accuracy = result['accuracy'];
      if (accuracy != null) {
        final accuracyValue = accuracy is int ? accuracy.toDouble() : accuracy ?? 0;
        if (accuracyValue >= 100.0) {          // 100% accuracy = perfect read
          perfectReads++;
        }
      }
    }
    return perfectReads;
  }

  double _averageWritingErrors(String key) {
    if (_writingResults.isEmpty) return 0;
    final total = _writingResults.fold<double>(0, (sum, item) {
      final value = item[key];
      return sum + (value is int ? value.toDouble() : (value ?? 0).toDouble());
    });
    return total / _writingResults.length;
  }

  int _totalVocabularyWords() {
    int total = 0;
    for (var session in _vocabResults) {
      final words = session['words'] as List? ?? [];
      total += words.length;
    }
    return total;
  }

  // UPDATED: Vocabulary progress based on session completion
  double _getVocabularyProgressPercentage() {
    final totalWords = _totalVocabularyWords();
    if (totalWords == 0) return 0.0;
    final goal = _sessionGoals['vocabulary']!;
    final sessionProgress = totalWords % goal;
    return (sessionProgress / goal * 100).clamp(0, 100).toDouble();
  }

  //  UPDATED: Count mastered words based on sessions completed
  int _masteredVocabularyWords() {
    final totalWords = _totalVocabularyWords();
    final goal = _sessionGoals['vocabulary']!;
    final completedSessions = (totalWords / goal).floor();
    return completedSessions * goal; // Words from completed sessions
  }

  Map<String, int> _vocabularyByCategory() {
    Map<String, int> categories = {};
    for (var session in _vocabResults) {
      final words = session['words'] as List? ?? [];
      for (var word in words) {
        if (word is Map) {
          final category = word['category']?.toString() ?? 'General';
          categories[category] = (categories[category] ?? 0) + 1;
        }
      }
    }
    return categories;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: Text("Progress Dashboard", style: TextStyle(fontSize: _fontSizeS, fontWeight: FontWeight.w700, fontFamily: "Lexend", color: _textColor)),
        centerTitle: true,
        backgroundColor: _background,
        elevation: 0,
        iconTheme: IconThemeData(color: _textColor),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _primary, size: 28),
            onPressed: _fetchData,
            tooltip: "Refresh Data",
          )
        ],
      ),
      body: _isLoading ? _buildLoading() : _errorMessage.isNotEmpty ? _buildError() : _buildMainContent(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_primary)),
          SizedBox(height: 20),
          Text("Loading your progress...", style: TextStyle(fontFamily: "Lexend", color: _textColor, fontSize: _fontSizeS)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: _warning),
            SizedBox(height: 20),
            Text("Oops!", style: TextStyle(fontSize: _fontSizeL, fontWeight: FontWeight.w700, fontFamily: "Lexend", color: _textColor)),
            SizedBox(height: 12),
            Text(_errorMessage, textAlign: TextAlign.center, style: TextStyle(fontFamily: "Lexend", color: _textColor, fontSize: _fontSizeS)),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: _fetchData,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text("Try Again", style: TextStyle(fontFamily: "Lexend", color: Colors.white, fontSize: _fontSizeS)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        Container(
          color: _cardColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTab(0, Icons.dashboard, "Overview"),
                _buildTab(1, Icons.menu_book, "Reading"),
                _buildTab(2, Icons.edit, "Writing"),
                _buildTab(3, Icons.library_books, "Vocabulary"),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _buildCurrentTab(),
          ),
        ),
      ],
    );
  }

  Widget _buildTab(int tabIndex, IconData icon, String label) {
    final isSelected = _currentTab == tabIndex;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentTab = tabIndex),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isSelected ? _primary : Colors.transparent, width: 3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? _primary : _textColor.withOpacity(0.5), size: 26),
              SizedBox(height: 8),
              Text(label, style: TextStyle(
                  fontFamily: "Lexend", fontSize: _fontSizeXXS,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? _primary : _textColor.withOpacity(0.7)
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentTab) {
      case 0: return _buildOverviewTab();
      case 1: return _buildReadingTab();
      case 2: return _buildWritingTab();
      case 3: return _buildVocabularyTab();
      default: return _buildOverviewTab();
    }
  }

  // OVERVIEW TAB
  Widget _buildOverviewTab() {
    return Column(
      children: [
        _buildWelcomeCard(),
        SizedBox(height: 24),
        _buildMotivationCard(),
        if (_insights != null) ...[
          SizedBox(height: 24),
          _buildInsightsPanel(),
        ],
        SizedBox(height: 24),
        Text("Your Progress Overview", style: TextStyle(fontSize: _fontSizeL, fontWeight: FontWeight.w700, fontFamily: "Lexend", color: _textColor)),
        SizedBox(height: 20),
        _buildProgressRings(),
        SizedBox(height: 28),
        _buildQuickStatsGrid(),
        SizedBox(height: 28),
        _buildRecentActivity(),
      ],
    );
  }

  Widget _buildWelcomeCard() {
    final streak = _getCurrentStreak();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_primary.withOpacity(0.9), _accent.withOpacity(0.9)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _primary.withOpacity(0.3), blurRadius: 15, offset: Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_getWelcomeMessage(), style: TextStyle(fontSize: _fontSizeL, fontWeight: FontWeight.w700, fontFamily: "Lexend", color: Colors.white)),
          SizedBox(height: 12),
          Text("Ready to continue your learning journey?", style: TextStyle(fontFamily: "Lexend", color: Colors.white.withOpacity(0.9), fontSize: _fontSizeS)),
          if (streak > 0) ...[
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_fire_department, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text("Current Streak: $streak days", style: TextStyle(fontFamily: "Lexend", color: Colors.white, fontSize: _fontSizeXS, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // motivation card
  Widget _buildMotivationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _success.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events_rounded, color: _success, size: 36),
          SizedBox(width: 20),
          Expanded(child: Text(_getMotivationMessage(), style: TextStyle(fontSize: _fontSizeS, fontWeight: FontWeight.w600, fontFamily: "Lexend", color: _textColor))),
        ],
      ),
    );
  }


  //ai insights panel

  Widget _buildInsightsPanel() {
    final insights = _insights!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _accent.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_graph, color: _accent, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  insights.headline,
                  style: TextStyle(
                    fontSize: _fontSizeM,
                    fontWeight: FontWeight.w700,
                    fontFamily: "Lexend",
                    color: _textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildMomentumRow(
            reading: insights.readingMomentum,
            writing: insights.writingMomentum,
            vocabulary: insights.vocabularyMomentum,
          ),
          const SizedBox(height: 20),
          if (insights.celebrations.isNotEmpty) ...[
            Text(
              "Highlights",
              style: TextStyle(
                fontSize: _fontSizeXS,
                fontWeight: FontWeight.w700,
                fontFamily: "Lexend",
                color: _success,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: insights.celebrations
                  .map((text) => _buildInsightChip(text, _success))
                  .toList(),
            ),
            const SizedBox(height: 18),
          ],
          if (insights.strengths.isNotEmpty) ...[
            Text(
              "Strengths",
              style: TextStyle(
                fontSize: _fontSizeXS,
                fontWeight: FontWeight.w700,
                fontFamily: "Lexend",
                color: _primary,
              ),
            ),
            const SizedBox(height: 8),
            ...insights.strengths
                .map((line) => _buildInsightTile(
                      icon: Icons.check_circle,
                      color: _primary,
                      text: line,
                    ))
                .toList(),
            const SizedBox(height: 18),
          ],
          if (insights.focusAreas.isNotEmpty) ...[
            Text(
              "Focus Next",
              style: TextStyle(
                fontSize: _fontSizeXS,
                fontWeight: FontWeight.w700,
                fontFamily: "Lexend",
                color: _warning,
              ),
            ),
            const SizedBox(height: 8),
            ...insights.focusAreas
                .map((line) => _buildInsightTile(
                      icon: Icons.flag,
                      color: _warning,
                      text: line,
                    ))
                .toList(),
            const SizedBox(height: 18),
          ],
          if (insights.recommendations.isNotEmpty) ...[
            Text(
              "Adaptive Suggestions",
              style: TextStyle(
                fontSize: _fontSizeXS,
                fontWeight: FontWeight.w700,
                fontFamily: "Lexend",
                color: _accent,
              ),
            ),
            const SizedBox(height: 8),
            ...insights.recommendations
                .map((line) => _buildInsightTile(
                      icon: Icons.auto_awesome,
                      color: _accent,
                      text: line,
                    ))
                .toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildInsightChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: "Lexend",
                fontSize: _fontSizeXXS,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightTile({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: "Lexend",
                fontSize: _fontSizeXXS,
                color: _textColor,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMomentumRow({
    required double reading,
    required double writing,
    required double vocabulary,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildMomentumBadge("Reading", reading, _primary),
        _buildMomentumBadge("Writing", writing, _secondary),
        _buildMomentumBadge("Vocab", vocabulary, _success),
      ],
    );
  }

  Widget _buildMomentumBadge(String label, double value, Color color) {
    final clamped = value.clamp(-9.9, 9.9);
    IconData icon;
    Color pillColor;
    if (clamped > 0.8) {
      icon = Icons.trending_up;
      pillColor = color.withOpacity(0.18);
    } else if (clamped < -0.8) {
      icon = Icons.trending_down;
      pillColor = Colors.redAccent.withOpacity(0.18);
    } else {
      icon = Icons.horizontal_rule;
      pillColor = _textColor.withOpacity(0.08);
    }
    final formatted = clamped.toStringAsFixed(1);
    final valueColor =
        clamped < -0.8 ? Colors.redAccent : (clamped > 0.8 ? color : _textColor);

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: pillColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: valueColor),
                const SizedBox(width: 4),
                Text(
                  "$formatted",
                  style: TextStyle(
                    fontFamily: "Lexend",
                    fontSize: _fontSizeXXS,
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: "Lexend",
                fontSize: 10,
                color: _textColor.withOpacity(0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // build progress rings
  Widget _buildProgressRings() {
    final readingAccuracy = _getReadingAccuracy();               // each ring gets it percentage
    final vocabProgress = _getVocabularyProgressPercentage();        //  UPDATED
    final writingProgress = _writingResults.length > 0 ? (_writingResults.length / _getCurrentWritingGoal() * 100).clamp(0, 100).toDouble() : 0.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildProgressRing("Reading", readingAccuracy, _primary, Icons.menu_book),
        _buildProgressRing("Vocabulary", vocabProgress, _success, Icons.library_books), // UPDATED
        _buildProgressRing("Writing", writingProgress, _secondary, Icons.edit),
      ],
    );
  }

  Widget _buildProgressRing(String title, double percentage, Color color, IconData icon) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 100, height: 100,
              child: CircularProgressIndicator(
                value: percentage / 100, strokeWidth: 10,
                backgroundColor: color.withOpacity(0.2), valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Column(children: [
              Icon(icon, color: color, size: 24),
              SizedBox(height: 6),
              Text("${percentage.toStringAsFixed(0)}%", style: TextStyle(fontSize: _fontSizeXS, fontWeight: FontWeight.w700, fontFamily: "Lexend", color: color)),
            ]),
          ],
        ),
        SizedBox(height: 12),
        Text(title, style: TextStyle(fontFamily: "Lexend", fontSize: _fontSizeXXS, color: _textColor)),
      ],
    );
  }

//quick stats grid
  Widget _buildQuickStatsGrid() {
    final streak = _getCurrentStreak();
    final perfectReads = _getPerfectReadsCount();
    final avgWPM = _getAverageWPM();

    // Use shorter session status for grid to prevent overflow
    final readingSessionProgress = _getSessionProgress('reading');
    final readingSessionGoal = _sessionGoals['reading']!;
    final readingSessionStatus = "$readingSessionProgress/$readingSessionGoal";

    final writingSessionProgress = _getSessionProgress('writing');
    final writingSessionGoal = _sessionGoals['writing']!;
    final writingSessionStatus = "$writingSessionProgress/$writingSessionGoal";

    final vocabSessionProgress = _getSessionProgress('vocabulary');
    final vocabSessionGoal = _sessionGoals['vocabulary']!;
    final vocabSessionStatus = "$vocabSessionProgress/$vocabSessionGoal";

    final readingBadge = _getCurrentBadge('reading');
    final writingBadge = _getCurrentBadge('writing');
    final vocabularyBadge = _getCurrentBadge('vocabulary');

    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.2,
      children: [
        _buildStatCard("Current Streak", "$streak days", Icons.local_fire_department, _warning),
        _buildStatCard("Reading", readingSessionStatus, Icons.library_books, _primary),
        _buildStatCard("Perfect Reads", "$perfectReads", Icons.star, _success),
        _buildStatCard("Avg WPM", avgWPM.toStringAsFixed(0), Icons.speed, _accent),
        _buildStatCard("Writing", writingSessionStatus, Icons.edit, _secondary),
        _buildStatCard("Vocabulary", vocabSessionStatus, Icons.library_books, _success),
        _buildStatCard("Reading Badge", readingBadge, Icons.emoji_events, _accent),
        _buildStatCard("Writing Badge", writingBadge, Icons.workspace_premium, _secondary),
        _buildStatCard("Vocab Badge", vocabularyBadge, Icons.auto_awesome, _success),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardColor, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: _fontSizeXS, fontWeight: FontWeight.w800, fontFamily: "Lexend", color: _textColor)),
          SizedBox(height: 4),
          Text(title, style: TextStyle(fontFamily: "Lexend", fontSize: 10, color: _textColor.withOpacity(0.7))),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Recent Activity", style: TextStyle(fontSize: _fontSizeM, fontWeight: FontWeight.w700, fontFamily: "Lexend", color: _textColor)),
        SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _cardColor, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _primary.withOpacity(0.1)),
          ),
          child: Column(children: [
            _buildActivityItem("Reading Sessions Completed", _readingResults.length, _primary),
            _buildActivityItem("Writing Exercises Done", _writingResults.length, _secondary),
            _buildActivityItem("Vocabulary Sessions", (_totalVocabularyWords() / _sessionGoals['vocabulary']!).floor(), _success), // 🆕 UPDATED
            _buildActivityItem("Total Words Practiced", _totalVocabularyWords(), _accent), // 🆕 NEW
            _buildActivityItem("Total Practice Sessions", _readingResults.length + _writingResults.length + _vocabResults.length, _accent),
          ]),
        ),
      ],
    );
  }

  Widget _buildActivityItem(String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          SizedBox(width: 16),
          Expanded(child: Text(title, style: TextStyle(fontFamily: "Lexend", color: _textColor, fontSize: _fontSizeXS))),
          Text("$count", style: TextStyle(fontFamily: "Lexend", fontWeight: FontWeight.w700, color: color, fontSize: _fontSizeXS)),
        ],
      ),
    );
  }

  // READING TAB
  Widget _buildReadingTab() {
    return Column(children: [
      _buildReadingPerformanceCard(),
      SizedBox(height: 24),
      _buildReadingSessionProgress(),
      SizedBox(height: 24),
      _buildReadingSessionHistory(),
    ]);
  }

  // NEW: Reading session progress
  Widget _buildReadingSessionProgress() {
    final progress = _getSessionProgress('reading');
    final goal = _sessionGoals['reading']!;
    final session = _getCurrentSession('reading');
    final badge = _getCurrentBadge('reading');
    final isComplete = progress >= goal;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isComplete ? _success.withOpacity(0.3) : _primary.withOpacity(0.1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("Session Progress", style: TextStyle(fontSize: _fontSizeM, fontWeight: FontWeight.w700, fontFamily: "Lexend", color: _textColor)),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: _accent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Text("Session $session", style: TextStyle(fontSize: _fontSizeXS, fontWeight: FontWeight.w700, color: _accent)),
          ),
        ]),
        SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("Current Badge", style: TextStyle(fontFamily: "Lexend", color: _textColor.withOpacity(0.8), fontSize: _fontSizeXS)),
          Text(badge, style: TextStyle(fontFamily: "Lexend", color: _accent, fontSize: _fontSizeXS, fontWeight: FontWeight.w700)),
        ]),
        SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("Sessions Completed", style: TextStyle(fontFamily: "Lexend", color: _textColor.withOpacity(0.8), fontSize: _fontSizeXS)),
          Text("$progress/$goal", style: TextStyle(fontFamily: "Lexend", color: _textColor, fontSize: _fontSizeXS, fontWeight: FontWeight.w700)),
        ]),
        SizedBox(height: 12),
        Container(height: 8, width: double.infinity, decoration: BoxDecoration(color: _primary.withOpacity(0.2), borderRadius: BorderRadius.circular(4)), child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: progress / goal > 1 ? 1.0 : progress / goal,
          child: Container(decoration: BoxDecoration(
              gradient: isComplete ? LinearGradient(colors: [_success, _accent]) : LinearGradient(colors: [_primary, _accent]),
              borderRadius: BorderRadius.circular(4)
          )),
        )),
        if (isComplete) ...[
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(color: _success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(Icons.celebration, color: _success, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text("Session Complete! 🎉 Continue to Session ${session + 1}", style: TextStyle(fontSize: _fontSizeXS, color: _success, fontWeight: FontWeight.w600))),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _buildReadingPerformanceCard() {
    final avgWPM = _getAverageWPM();
    final avgAccuracy = _getReadingAccuracy();
    final streak = _getCurrentStreak();
    final readingGoal = _getCurrentReadingGoal();
    final perfectReads = _getPerfectReadsCount();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_primary.withOpacity(0.9), _accent.withOpacity(0.8)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _primary.withOpacity(0.3), blurRadius: 15, offset: Offset(0, 5))],
      ),
      child: Column(children: [
        Text("Reading Performance", style: TextStyle(fontSize: _fontSizeL, fontWeight: FontWeight.w700, fontFamily: "Lexend", color: Colors.white)),
        SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _buildPerformanceMetric("${avgWPM.toStringAsFixed(0)}", "WPM", Icons.speed, Colors.white),
          _buildPerformanceMetric("${avgAccuracy.toStringAsFixed(1)}%", "Accuracy", Icons.track_changes, Colors.white),
          _buildPerformanceMetric("$streak", "Day Streak", Icons.local_fire_department, Colors.white),
        ]),
        SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _buildPerformanceMetric("${_readingResults.length}", "Sessions", Icons.library_books, Colors.white),
          _buildPerformanceMetric("$perfectReads", "Perfect Reads", Icons.star, Colors.white),
        ]),
        if (_readingResults.isNotEmpty) ...[
          SizedBox(height: 20), Divider(color: Colors.white.withOpacity(0.3), height: 20),
          _buildProgressIndicator("Sessions Completed", _readingResults.length, readingGoal, Colors.white),
        ],
      ]),
    );
  }

  Widget _buildPerformanceMetric(String value, String label, IconData icon, Color color) {
    return Column(children: [
      Icon(icon, color: color, size: 32), SizedBox(height: 12),
      Text(value, style: TextStyle(fontSize: _fontSizeL, fontWeight: FontWeight.w800, fontFamily: "Lexend", color: color)),
      Text(label, style: TextStyle(fontSize: _fontSizeXXS, fontFamily: "Lexend", color: color.withOpacity(0.8))),
    ]);
  }

  Widget _buildProgressIndicator(String label, int current, int max, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontFamily: "Lexend", color: color.withOpacity(0.9), fontSize: _fontSizeXS)),
        Text("$current/$max", style: TextStyle(fontFamily: "Lexend", color: color, fontSize: _fontSizeXS)),
      ]),
      SizedBox(height: 8),
      Container(height: 6, width: double.infinity, decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(3)), child: FractionallySizedBox(
        alignment: Alignment.centerLeft, widthFactor: current / max,
        child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      )),
    ]);
  }

  Widget _buildReadingSessionHistory() {
    if (_readingResults.isEmpty) return _buildEmptyState("No reading sessions yet", "Complete reading exercises to see your progress here", Icons.menu_book);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("Session History", style: TextStyle(fontSize: _fontSizeM, fontWeight: FontWeight.w700, fontFamily: "Lexend", color: _textColor)),
      SizedBox(height: 16),
      ..._readingResults.reversed.map((session) => _buildReadingSessionCard(session)).toList(),
    ]);
  }



  //reading result card

  Widget _buildReadingSessionCard(Map<String, dynamic> session) {
    final date = _getSessionDate(session);
    final wpm = (session['wpm'] ?? 0).toDouble();     // get wpm
    final accuracy = (session['accuracy'] ?? 0).toDouble();   // get accuracy
    final misreadWords = (session['misreadWords'] as List? ?? []).length;
    final isPerfectRead = accuracy >= 100.0;        // perfect read

    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isPerfectRead ? _success.withOpacity(0.3) : _primary.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(_formatDate(date), style: TextStyle(fontFamily: "Lexend", fontWeight: FontWeight.w600, color: _textColor, fontSize: _fontSizeXS)),
          if (isPerfectRead) Icon(Icons.star, color: _success, size: 16),
          Text(_formatTime(date), style: TextStyle(fontFamily: "Lexend", color: _textColor.withOpacity(0.7), fontSize: _fontSizeXXS)),
        ]),
        SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _buildSessionMetric("${wpm.toStringAsFixed(0)}", "WPM", _primary),
          _buildSessionMetric("${accuracy.toStringAsFixed(1)}%", "Accuracy", isPerfectRead ? _success : _textColor),
          _buildSessionMetric("$misreadWords", "Errors", _warning),
        ]),
        if (isPerfectRead) ...[
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: _success.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Text("Perfect Read! 🎉", style: TextStyle(fontFamily: "Lexend", color: _success, fontSize: _fontSizeXXS, fontWeight: FontWeight.w600)),
          ),
        ],
      ]),
    );
  }

  Widget _buildSessionMetric(String value, String label, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: _fontSizeS, fontWeight: FontWeight.w700, fontFamily: "Lexend", color: color)),
      Text(label, style: TextStyle(fontSize: _fontSizeXXS, fontFamily: "Lexend", color: _textColor.withOpacity(0.7))),
    ]);
  }

  // display date and time
  String _formatDate(DateTime date) => "${date.day}/${date.month}/${date.year}";
  String _formatTime(DateTime date) => "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";

  // WRITING TAB
  Widget _buildWritingTab() {
    return Column(children: [
      _buildWritingSummaryCard(),
      SizedBox(height: 24),
      _buildWritingSessionProgress(),
      SizedBox(height: 24),
      _buildWritingHistory(),
    ]);
  }

  // Writing session progress

  Widget _buildWritingSessionProgress() {
    final progress = _getSessionProgress('writing');
    final goal = _sessionGoals['writing']!;
    final session = _getCurrentSession('writing');
    final badge = _getCurrentBadge('writing');
    final isComplete = progress >= goal;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isComplete ? _success.withOpacity(0.3) : _secondary.withOpacity(0.1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("Session Progress", style: TextStyle(fontSize: _fontSizeM, fontWeight: FontWeight.w700, fontFamily: "Lexend", color: _textColor)),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: _secondary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Text("Session $session", style: TextStyle(fontSize: _fontSizeXS, fontWeight: FontWeight.w700, color: _secondary)),
          ),
        ]),
        SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("Current Badge", style: TextStyle(fontFamily: "Lexend", color: _textColor.withOpacity(0.8), fontSize: _fontSizeXS)),
          Text(badge, style: TextStyle(fontFamily: "Lexend", color: _secondary, fontSize: _fontSizeXS, fontWeight: FontWeight.w700)),
        ]),
        SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("Exercises Completed", style: TextStyle(fontFamily: "Lexend", color: _textColor.withOpacity(0.8), fontSize: _fontSizeXS)),
          Text("$progress/$goal", style: TextStyle(fontFamily: "Lexend", color: _textColor, fontSize: _fontSizeXS, fontWeight: FontWeight.w700)),
        ]),
        SizedBox(height: 12),
        Container(height: 8, width: double.infinity, decoration: BoxDecoration(color: _secondary.withOpacity(0.2), borderRadius: BorderRadius.circular(4)), child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: progress / goal > 1 ? 1.0 : progress / goal,
          child: Container(decoration: BoxDecoration(
              gradient: isComplete ? LinearGradient(colors: [_success, _accent]) : LinearGradient(colors: [_secondary, _primary]),
              borderRadius: BorderRadius.circular(4)
          )),
        )),
        if (isComplete) ...[
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(color: _success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(Icons.celebration, color: _success, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text("Session Complete! 🎉 Continue to Session ${session + 1}", style: TextStyle(fontSize: _fontSizeXS, color: _success, fontWeight: FontWeight.w600))),
            ]),
          ),
        ],
      ]),
    );
  }

  // writing summary card

  Widget _buildWritingSummaryCard() {
    final avgSpelling = _averageWritingErrors("spellingErrors");
    final avgGrammar = _averageWritingErrors("grammarErrors");
    final avgPunct = _averageWritingErrors("punctuationErrors");



    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: _secondary.withOpacity(0.1))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Writing Analytics", style: TextStyle(fontSize: _fontSizeM, fontWeight: FontWeight.w700, fontFamily: "Lexend", color: _textColor)),
        SizedBox(height: 12),
        if (_writingResults.isEmpty) _buildEmptyState("No writing exercises yet", "Complete writing exercises to see your analytics", Icons.edit),
        if (_writingResults.isNotEmpty) Column(children: [
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.spaceAround, children: [
            _buildWritingStat("Exercises", "${_writingResults.length}", Icons.edit, _secondary),
            _buildWritingStat("Spelling", avgSpelling.toStringAsFixed(1), Icons.spellcheck, _success),
            _buildWritingStat("Grammar", avgGrammar.toStringAsFixed(1), Icons.graphic_eq, _warning),
            _buildWritingStat("Punctuation", avgPunct.toStringAsFixed(1), Icons.pin_end, _primary),
          ]),
          SizedBox(height: 12),
          Text("Average errors per exercise", style: TextStyle(fontFamily: "Lexend", color: _textColor.withOpacity(0.7), fontSize: _fontSizeXXS)),
        ]),
      ]),
    );
  }

  Widget _buildWritingStat(String title, String value, IconData icon, Color color) {
    return Container(width: 70, child: Column(children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 18)),
      SizedBox(height: 6),
      Text(value, style: TextStyle(fontSize: _fontSizeXS, fontWeight: FontWeight.w700, fontFamily: "Lexend", color: _textColor)),
      Text(title, style: TextStyle(fontFamily: "Lexend", fontSize: 10, color: _textColor.withOpacity(0.7))),
    ]));
  }

  Widget _buildWritingHistory() {
    if (_writingResults.isEmpty) return SizedBox();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("Recent Writing", style: TextStyle(fontSize: _fontSizeM, fontWeight: FontWeight.w600, fontFamily: "Lexend", color: _textColor)),
      SizedBox(height: 12),
      ..._writingResults.reversed.take(3).map((session) => _buildWritingSessionCard(session)).toList(),
    ]);
  }


  // writing session card

  Widget _buildWritingSessionCard(Map<String, dynamic> session) {
    final date = _getSessionDate(session);
    final prompt = session['prompt']?.toString() ?? 'No prompt';
    final wordCount = session['wordCount'] ?? 0;
    final spellingErrors = session['spellingErrors'] ?? 0;
    final grammarErrors = session['grammarErrors'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: _secondary.withOpacity(0.1))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(_formatDate(date), style: TextStyle(fontFamily: "Lexend", color: _textColor.withOpacity(0.7), fontSize: _fontSizeXS)),
          Spacer(),
          Text("$wordCount words", style: TextStyle(fontFamily: "Lexend", color: _textColor.withOpacity(0.7), fontSize: _fontSizeXS)),
        ]),
        SizedBox(height: 8),
        Text(prompt, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: "Lexend", color: _textColor, fontWeight: FontWeight.w600, fontSize: _fontSizeXS)),
        SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (spellingErrors > 0) _buildErrorChip("Spelling: $spellingErrors", _success),
          if (grammarErrors > 0) _buildErrorChip("Grammar: $grammarErrors", _warning),
        ]),
      ]),
    );
  }

  Widget _buildErrorChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontFamily: "Lexend", fontSize: _fontSizeXXS, color: color)),
    );
  }

  // VOCABULARY TAB
  Widget _buildVocabularyTab() {
    return Column(children: [
      _buildVocabularySummaryCard(),
      SizedBox(height: 24),
      _buildVocabularySessionProgress(), // 🆕 NEW: Session progress
      SizedBox(height: 24),
      _buildVocabularyCategories(),
      SizedBox(height: 24),
      _buildRecentVocabulary(),
    ]);
  }

  //  Vocabulary session progress
  Widget _buildVocabularySessionProgress() {
    final progress = _getSessionProgress('vocabulary');
    final goal = _sessionGoals['vocabulary']!;
    final session = _getCurrentSession('vocabulary');
    final badge = _getCurrentBadge('vocabulary');
    final isComplete = progress >= goal;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isComplete ? _success.withOpacity(0.3) : _success.withOpacity(0.1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
            child: Text("Vocabulary Progress",
              style: TextStyle(fontSize: _fontSizeM, fontWeight: FontWeight.w700, fontFamily: "Lexend", color: _textColor),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: _success.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Text("Session $session",
                style: TextStyle(fontSize: _fontSizeXS, fontWeight: FontWeight.w700, color: _success)),
          ),
        ]),
        SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("Current Badge",
              style: TextStyle(fontFamily: "Lexend", color: _textColor.withOpacity(0.8), fontSize: _fontSizeXS)),
          Expanded(
            child: Text(badge,
                textAlign: TextAlign.right,
                style: TextStyle(fontFamily: "Lexend", color: _success, fontSize: _fontSizeXS, fontWeight: FontWeight.w700)),
          ),
        ]),
        SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("Words Practiced",
              style: TextStyle(fontFamily: "Lexend", color: _textColor.withOpacity(0.8), fontSize: _fontSizeXS)),
          Text("$progress/$goal",
              style: TextStyle(fontFamily: "Lexend", color: _textColor, fontSize: _fontSizeXS, fontWeight: FontWeight.w700)),
        ]),
        SizedBox(height: 12),
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(color: _success.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress / goal > 1 ? 1.0 : progress / goal,
            child: Container(decoration: BoxDecoration(
                gradient: isComplete ? LinearGradient(colors: [_success, _accent]) : LinearGradient(colors: [_success, _primary]),
                borderRadius: BorderRadius.circular(4)
            )),
          ),
        ),
        if (isComplete) ...[
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(color: _success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(Icons.celebration, color: _success, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text("Session Complete! 🎉",
                    style: TextStyle(fontSize: _fontSizeXS, color: _success, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ],
      ]),
    );
  }


  // vocabulary summary card
  Widget _buildVocabularySummaryCard() {
    final totalWords = _totalVocabularyWords();
    final masteredWords = _masteredVocabularyWords(); // UPDATED
    final progressPercentage = _getVocabularyProgressPercentage(); //  UPDATED
    final goal = _getCurrentVocabularyGoal();
    final sessionStatus = _getSessionStatus('vocabulary'); // NEW

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: _success.withOpacity(0.1))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Vocabulary Progress", style: TextStyle(fontSize: _fontSizeM, fontWeight: FontWeight.w700, fontFamily: "Lexend", color: _textColor)),
        SizedBox(height: 16),
        if (_vocabResults.isEmpty) _buildEmptyState("No vocabulary practice yet", "Complete vocabulary exercises to track your progress", Icons.library_books),
        if (_vocabResults.isNotEmpty) Column(children: [
          // NEW: Session status
          Container(
            padding: EdgeInsets.all(12),
            margin: EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: _success.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(Icons.auto_awesome, color: _success, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text(sessionStatus, style: TextStyle(fontSize: _fontSizeXS, color: _success, fontWeight: FontWeight.w600))),
            ]),
          ),

          Row(children: [
            Expanded(child: Column(children: [
              _buildVocabMetric("Total Words", totalWords.toString(), Icons.library_books, _primary),
              SizedBox(height: 12),
              _buildVocabMetric("Session Progress", "$masteredWords/$goal words", Icons.star, _success), // UPDATED
              SizedBox(height: 12),
              _buildVocabMetric("Current Session", "Session ${_getCurrentSession('vocabulary')}", Icons.emoji_events, _accent), // 🆕 NEW
            ])),
            SizedBox(width: 20),
            Stack(alignment: Alignment.center, children: [
              SizedBox(width: 100, height: 100, child: CircularProgressIndicator(
                value: progressPercentage / 100, strokeWidth: 10, // 🆕 UPDATED
                backgroundColor: _success.withOpacity(0.2), valueColor: AlwaysStoppedAnimation<Color>(_success),
              )),
              Column(children: [
                Text("${progressPercentage.toStringAsFixed(0)}%", style: TextStyle(fontSize: _fontSizeS, fontWeight: FontWeight.w700, fontFamily: "OpenDyslexic", color: _textColor)),
                Text("Session", style: TextStyle(fontFamily: "Lexend", fontSize: _fontSizeXXS, color: _textColor.withOpacity(0.7))),
              ]),
            ]),
          ]),
        ]),
      ]),
    );
  }

  Widget _buildVocabMetric(String title, String value, IconData icon, Color color) {
    return Row(children: [
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 22)),
      SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(fontSize: _fontSizeS, fontWeight: FontWeight.w700, fontFamily: "Lexend", color: _textColor)),
        Text(title, style: TextStyle(fontFamily: "Lexend", fontSize: _fontSizeXXS, color: _textColor.withOpacity(0.7))),
      ]),
    ]);
  }

  Widget _buildVocabularyCategories() {
    final categories = _vocabularyByCategory();
    if (categories.isEmpty) return SizedBox();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("Words Practiced", style: TextStyle(fontSize: _fontSizeM, fontWeight: FontWeight.w600, fontFamily: "Lexend", color: _textColor)),
      SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: categories.entries.map((entry) => Chip(
        label: Text("${entry.key}: ${entry.value}", style: TextStyle(fontFamily: "Lexend", fontSize: _fontSizeXXS)),
        backgroundColor: _primary.withOpacity(0.1), side: BorderSide.none,
      )).toList()),
    ]);
  }

  Widget _buildRecentVocabulary() {
    if (_vocabResults.isEmpty) return SizedBox();
    final recentWords = _getRecentVocabularyWords();
    if (recentWords.isEmpty) return SizedBox();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("Recently Practiced Words", style: TextStyle(fontSize: _fontSizeM, fontWeight: FontWeight.w600, fontFamily: "Lexend", color: _textColor)),
      SizedBox(height: 12),
      Column(children: recentWords.take(10).map((word) => _buildVocabularyWordCard(word)).toList()),
    ]);
  }

  List<Map<String, dynamic>> _getRecentVocabularyWords() {
    List<Map<String, dynamic>> allWords = [];
    for (var session in _vocabResults) {
      final words = session['words'] as List? ?? [];
      for (var word in words) {
        if (word is Map) allWords.add(Map<String, dynamic>.from(word));
      }
    }
    return allWords;
  }
  Widget _buildVocabularyWordCard(Map<String, dynamic> wordData) {
    final word = wordData['word']?.toString() ?? 'Unknown';
    final category = wordData['category']?.toString() ?? 'General';
    final definition = wordData['definition']?.toString() ?? '';
    final isSecondAttempt = _isSecondAttempt(wordData);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _primary.withOpacity(0.1)),
      ),
      child: Row(children: [
        Icon(Icons.book_rounded, color: _primary, size: 22),
        SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(word, style: TextStyle(fontFamily: "Lexend", fontWeight: FontWeight.w600, color: _textColor, fontSize: _fontSizeXS)),
          if (isSecondAttempt) ...[
            SizedBox(height: 2),
            Text("Second attempt", style: TextStyle(
                fontFamily: "Lexend",
                fontSize: _fontSizeXXS,
                color: _accent,
                fontWeight: FontWeight.w600
            )),
          ],
          if (definition.isNotEmpty) ...[
            SizedBox(height: 4),
            Text(definition, style: TextStyle(fontFamily: "Lexend", fontSize: _fontSizeXXS, color: _textColor.withOpacity(0.7)))
          ],
          SizedBox(height: 4),
          Text(category, style: TextStyle(fontFamily: "Lexend", fontSize: _fontSizeXXS, color: _primary)),
        ])),
      ]),
    );
  }

// SIMPLIFIED VERSION
  bool _isSecondAttempt(Map<String, dynamic> currentWordData) {
    final currentWord = currentWordData['word']?.toString();
    if (currentWord == null) return false;

    bool foundFirst = false;

    // Go through all vocabulary results
    for (var session in _vocabResults) {
      final words = session['words'] as List? ?? [];
      for (var word in words) {
        if (word is Map) {
          final wordText = word['word']?.toString();
          if (wordText == currentWord) {
            // If we found the same word before finding the current one, it's a second attempt
            if (word == currentWordData) {
              return foundFirst; // If we found a previous one, this is second attempt
            } else {
              foundFirst = true; // We found a previous occurrence
            }
          }
        }
      }
    }
    return false;
  }

  Widget _buildEmptyState(String title, String message, IconData icon) {
    return Container(padding: const EdgeInsets.symmetric(vertical: 40), child: Column(children: [
      Icon(icon, size: 64, color: _textColor.withOpacity(0.3)), SizedBox(height: 16),
      Text(title, style: TextStyle(fontSize: _fontSizeM, fontWeight: FontWeight.w600, fontFamily: "Lexend", color: _textColor.withOpacity(0.5))),
      SizedBox(height: 8), Text(message, textAlign: TextAlign.center, style: TextStyle(fontFamily: "Lexend", fontSize: _fontSizeS, color: _textColor.withOpacity(0.5))),
    ]));
  }
}