import 'package:flutter/material.dart';
import 'package:learning_app/screens/Login_screen.dart';
import 'package:learning_app/screens/progress_dashboard.dart';
import 'package:learning_app/screens/reading_practice.dart';
import 'package:learning_app/screens/vocabs_practice.dart';
import 'package:learning_app/screens/writing_practice.dart';
import 'package:learning_app/screens/document_scan_screen.dart';
import 'package:learning_app/services/auth_services.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? username;
  String? email;
  String? _userId;
  bool isLoading = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }


  // load current username
  Future<void> _loadProfile() async {
    final profile = _authService.currentUserProfile();    // sends to auth service
    setState(() {
      username = profile?['username']?.toString() ?? 'Learner';
      email = profile?['email']?.toString();
      _userId = profile?['id']?.toString();
      isLoading = false;
    });
  }

  Future<void> _updateUsername(String newUsername) async {
    if (newUsername.isEmpty) return;
    setState(() {
      isLoading = true;
    });
    final success = await _authService.updateUsername(newUsername);
    if (success) {
      await _loadProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Username updated to: $newUsername",
              style: const TextStyle(
                fontFamily: 'Lexend',
                fontSize: 18,
              ),
            ),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      }
    } else {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Unable to update username",
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 18,
              ),
            ),
            backgroundColor: Color(0xFFE74C3C),
          ),
        );
      }
    }
  }

  Future<void> _logoutUser() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "Log Out",
          style: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          "Are you sure you want to log out?",
          style: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          SizedBox(
            height: 60,
            child: TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                "Cancel",
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
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFE74C3C),
              ),
              child: const Text(
                "Log Out",
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

    if (shouldLogout == true) {
      setState(() {
        isLoading = true;
      });
      await _authService.clearLoginState();        // calls this method here to logout
      await _authService.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _showEditUsernameDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController(text: username);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "Edit Username",
          style: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(
            fontFamily: 'Lexend',
            fontSize: 20,
            letterSpacing: 0.5,
          ),
          decoration: const InputDecoration(
            hintText: "Enter new username",
            hintStyle: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          ),
          autofocus: true,
        ),
        actions: [
          SizedBox(
            height: 60,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Cancel",
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
              onPressed: () async {
                final newUsername = controller.text.trim();
                if (newUsername.isNotEmpty) {
                  Navigator.pop(context);
                  await _updateUsername(newUsername);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Username cannot be empty"),
                      backgroundColor: Color(0xFFFF9800),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              child: const Text(
                "Save",
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
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    // Ensure userId is not null/empty - reload profile if needed
    final userId = _userId ?? '';
    if (userId.isEmpty && !isLoading) {
      // Try to reload profile if userId is missing
      _loadProfile();
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F5F0), // Calm cream background
      appBar: AppBar(
        title: Text(
          isLoading ? "Loading..." : "Hello, $username 👋",        // display username in app bar
          style: const TextStyle(
            fontFamily: 'Lexend',
            color: Color(0xFF2D3748), // Dark text
            fontWeight: FontWeight.bold,
            fontSize: 24,
            letterSpacing: 1.0,
          ),
        ),
        backgroundColor: const Color(0xFFF5F5F0),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.person,
              color: Color(0xFF2D3748),
              size: 32,
            ),
            onPressed: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
        ],
      ),
      endDrawer: _buildProfileDrawer(context),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Positioned(
                  top: -screenHeight * 0.15,
                  left: -screenHeight * 0.1,
                  child: Container(
                    height: screenHeight * 0.5,
                    width: screenHeight * 0.5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF4A6FA5).withOpacity(0.15), // Calm blue
                          Colors.transparent
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -screenHeight * 0.2,
                  right: -screenHeight * 0.15,
                  child: Container(
                    height: screenHeight * 0.6,
                    width: screenHeight * 0.6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF4A6FA5).withOpacity(0.12), // Calm blue
                          Colors.transparent
                        ],
                        begin: Alignment.bottomRight,
                        end: Alignment.topLeft,
                      ),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              offset: const Offset(4, 4),
                              blurRadius: 12,
                            ),
                            BoxShadow(
                              color: Colors.white.withOpacity(0.7),
                              offset: const Offset(-4, -4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Welcome back, $username!",
                              style: const TextStyle(
                                fontFamily: 'Lexend',
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D3748),
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              "Ready to continue your learning journey today?",
                              style: TextStyle(
                                fontFamily: 'Lexend',
                                fontSize: 20,
                                color: Color(0xFF4A5568),
                                letterSpacing: 0.5,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      _buildSectionHeader(
                        title: "What do you want to practice today?",
                        subtitle: "Choose a practice to strengthen your skills.",
                      ),
                      const SizedBox(height: 20),
                      _buildInteractiveButton(
                        label: "Writing Practice",
                        icon: Icons.edit,
                        onTap: () {
                          if (userId.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Unable to load user profile. Please log out and log in again.",
                                  style: TextStyle(
                                    fontFamily: 'Lexend',
                                    fontSize: 18,
                                  ),
                                ),
                                backgroundColor: Color(0xFFE74C3C),
                              ),
                            );
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => WritingPracticeScreen(uid: userId),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildInteractiveButton(
                        label: "Reading Practice",
                        icon: Icons.menu_book,
                        onTap: () {
                          if (userId.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Unable to load user profile. Please log out and log in again.",
                                  style: TextStyle(
                                    fontFamily: 'Lexend',
                                    fontSize: 18,
                                  ),
                                ),
                                backgroundColor: Color(0xFFE74C3C),
                              ),
                            );
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReadingPracticeScreen(uid: userId),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildInteractiveButton(
                        label: "Vocabulary Practice",
                        icon: Icons.translate,
                        onTap: () {
                          if (userId.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Unable to load user profile. Please log out and log in again.",
                                  style: TextStyle(
                                    fontFamily: 'Lexend',
                                    fontSize: 18,
                                  ),
                                ),
                                backgroundColor: Color(0xFFE74C3C),
                              ),
                            );
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VocabularyPracticeScreen(uid: userId),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 40),
                      _buildSectionHeader(
                        title: "Your Journey",
                        subtitle: "Monitor your learning progress.",
                      ),
                      const SizedBox(height: 20),
                      _buildInteractiveButton(
                        label: "Progress Dashboard",
                        icon: Icons.bar_chart,
                        onTap: () {
                          if (userId.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Unable to load user profile. Please log out and log in again.",
                                  style: TextStyle(
                                    fontFamily: 'Lexend',
                                    fontSize: 18,
                                  ),
                                ),
                                backgroundColor: Color(0xFFE74C3C),
                              ),
                            );
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProgressDashboardScreen(uid: userId),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildProfileDrawer(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      backgroundColor: const Color(0xFFF5F5F0), // Calm cream
      child: Stack(
        children: [
          Positioned(
            top: -screenHeight * 0.1,
            right: -screenHeight * 0.1,
            child: Container(
              height: screenHeight * 0.4,
              width: screenHeight * 0.4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF4A6FA5).withOpacity(0.12), // Calm blue
                    Colors.transparent
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 40),
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        offset: const Offset(4, 4),
                        blurRadius: 12,
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.7),
                        offset: const Offset(-4, -4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.person,
                    size: 64,
                    color: const Color(0xFF4A6FA5).withOpacity(0.7), // Calm blue
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  username ?? "User",
                  style: const TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  email ?? "No email",
                  style: const TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 18,
                    color: Color(0xFF4A5568),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 40),
                _buildDrawerButton(
                  icon: Icons.edit,
                  label: "Edit Username",
                  onTap: () {
                    Navigator.pop(context);
                    _showEditUsernameDialog(context);
                  },
                ),
                const SizedBox(height: 16),
                _buildDrawerButton(
                  icon: Icons.logout,
                  label: "Log Out",
                  onTap: _logoutUser,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        offset: const Offset(2, 2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Text(
                    "Learning App v1.0",
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 14,
                      color: Color(0xFF888888),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool pressed = false;
        return GestureDetector(
          onTapDown: (_) => setState(() => pressed = true),
          onTapUp: (_) => setState(() => pressed = false),
          onTapCancel: () => setState(() => pressed = false),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            transform: Matrix4.identity()..scale(pressed ? 0.95 : 1.0),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: pressed
                  ? const Color(0xFF4A6FA5).withOpacity(0.1) // Calm blue
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: pressed
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        offset: const Offset(2, 2),
                        blurRadius: 8,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        offset: const Offset(4, 4),
                        blurRadius: 12,
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.7),
                        offset: const Offset(-4, -4),
                        blurRadius: 12,
                      ),
                    ],
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: const Color(0xFF4A6FA5), // Calm blue
                  size: 28,
                ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Lexend',
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            fontFamily: 'Lexend',
            fontSize: 18,
            color: Color(0xFF4A5568),
            letterSpacing: 0.5,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildInteractiveButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool pressed = false;
        return GestureDetector(
          onTapDown: (_) => setState(() => pressed = true),
          onTapUp: (_) => setState(() => pressed = false),
          onTapCancel: () => setState(() => pressed = false),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            transform: Matrix4.identity()..scale(pressed ? 0.93 : 1.0),
            padding: const EdgeInsets.symmetric(vertical: 22),
            decoration: BoxDecoration(
              color: pressed
                  ? const Color(0xFF4A6FA5).withOpacity(0.15) // Calm blue
                  : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: pressed
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        offset: const Offset(2, 2),
                        blurRadius: 8,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        offset: const Offset(6, 6),
                        blurRadius: 15,
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.9),
                        offset: const Offset(-6, -6),
                        blurRadius: 15,
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: const Color(0xFF4A6FA5), size: 32), // Calm blue
                const SizedBox(width: 16),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingActionButton() {
    return StatefulBuilder(
      builder: (context, setState) {
        bool pressed = false;

        return GestureDetector(
          onTapDown: (_) => setState(() => pressed = true),
          onTapUp: (_) => setState(() => pressed = false),
          onTapCancel: () => setState(() => pressed = false),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DocumentLessonScreen(),
              ),
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            transform: Matrix4.identity()..scale(pressed ? 0.92 : 1.0),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: pressed
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        offset: const Offset(2, 2),
                        blurRadius: 8,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        offset: const Offset(6, 6),
                        blurRadius: 15,
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.9),
                        offset: const Offset(-6, -6),
                        blurRadius: 15,
                      ),
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.psychology, color: Color(0xFF4A6FA5), size: 28), // Calm blue
                SizedBox(width: 12),
                Text(
                  "AI Scan",
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A6FA5),
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}