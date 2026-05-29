import 'package:flutter/material.dart';
import 'package:learning_app/screens/Login_screen.dart';
import 'package:learning_app/services/auth_services.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _username = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final AuthService _authService = AuthService();

  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  String? _emailError;

  Widget _buildEnhancedTextField(
      TextEditingController controller, String label,
      {bool isPassword = false, FocusNode? focusNode, String? errorText, VoidCallback? onChanged}) {
    bool isFocused = focusNode?.hasFocus ?? false;
    final hasError = errorText != null && errorText.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(16),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: hasError ? Colors.red.withOpacity(0.3) : Colors.blue.withOpacity(0.3),
                      offset: const Offset(4, 4),
                      blurRadius: 12,
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.9),
                      offset: const Offset(-4, -4),
                      blurRadius: 12,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: hasError ? Colors.red.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                      offset: const Offset(4, 4),
                      blurRadius: 8,
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.8),
                      offset: const Offset(-4, -4),
                      blurRadius: 8,
                    ),
                  ],
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword,
            focusNode: focusNode,
            onChanged: (value) {
              if (onChanged != null) {
                onChanged();
              }
              // Force validation update
              if (controller == _email) {
                _validateEmail();
              }
            },
            style: const TextStyle(
              fontFamily: 'Lexend',
              color: Color(0xFF2D3748),
              fontSize: 20,
              letterSpacing: 0.5,
            ),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(
                color: hasError ? const Color(0xFFE74C3C) : (isFocused ? const Color(0xFF4A6FA5) : const Color(0xFF4A5568)),
                fontSize: 18,
                fontFamily: 'Lexend',
                fontWeight: FontWeight.w600,
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 8),
            child: Text(
              errorText!,
              style: const TextStyle(
                color: Color(0xFFE74C3C),
                fontSize: 18,
                fontFamily: 'Lexend',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  bool _isValidGmail(String email) {
    // Check if email contains @gmail.com
    final emailLower = email.toLowerCase().trim();
    return emailLower.contains('@gmail.com') && 
           emailLower.endsWith('@gmail.com') &&
           emailLower.split('@')[0].isNotEmpty;
  }

  void _validateEmail() {
    setState(() {
      final email = _email.text.trim();
      if (email.isEmpty) {
        _emailError = null;
      } else if (!_isValidGmail(email)) {
        _emailError = 'Registration unsuccessful email invalid';
      } else {
        _emailError = null;
      }
    });
  }

  Future<void> _registerUser() async {
    final username = _username.text.trim();
    final email = _email.text.trim();
    final password = _password.text.trim();

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "Please fill all fields",
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 18,
            ),
          ),
          backgroundColor: const Color(0xFFE74C3C),
        ),
      );
      return;
    }

    // Validate email format (must be @gmail.com)
    if (!_isValidGmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "Registration unsuccessful email invalid",
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 18,
            ),
          ),
          backgroundColor: const Color(0xFFE74C3C),
        ),
      );
      return;
    }

    // Validate password length
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "Password must be at least 6 characters long",
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 18,
            ),
          ),
          backgroundColor: const Color(0xFFE74C3C),
        ),
      );
      return;
    }



    final userId = await _authService.register(    // calls auth service to save in database
      username: username,
      email: email,
      password: password,
    );

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "Email already registered",
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 18,
            ),
          ),
          backgroundColor: const Color(0xFFE74C3C),
        ),
      );
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          "Success",
          style: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          "Registration successful!",
          style: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          SizedBox(
            height: 60,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              child: const Text(
                "OK",
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
  void initState() {
    super.initState();
    _email.addListener(_validateEmail);
  }

  @override
  void dispose() {
    _email.removeListener(_validateEmail);
    _usernameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0), // Calm cream background
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Text(
                "Create an Account",
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 30),
              _buildEnhancedTextField(_username, "Username",
                  focusNode: _usernameFocus),
              const SizedBox(height: 20),
              _buildEnhancedTextField(
                _email, 
                "Email", 
                focusNode: _emailFocus,
                errorText: _emailError,
                onChanged: _validateEmail,
              ),
              const SizedBox(height: 20),
              _buildEnhancedTextField(_password, "Password",
                  isPassword: true, focusNode: _passwordFocus),
              const SizedBox(height: 30),
              GestureDetector(
                onTapDown: (_) => setState(() {}),
                onTapUp: (_) => setState(() {}),
                child: ElevatedButton(
                  onPressed: _email.text.trim().isNotEmpty && 
                            _isValidGmail(_email.text.trim())
                      ? _registerUser
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50), // Calm green
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF9E9E9E),
                    disabledForegroundColor: Colors.white70,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: Color(0xFF2E7D32), width: 3),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 20, horizontal: 50),
                    elevation: 4,
                    shadowColor: Colors.black.withOpacity(0.2),
                  ),
                  child: const Text(
                    "Register",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Lexend',
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
