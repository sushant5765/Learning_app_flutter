import 'package:flutter/material.dart';
import 'package:learning_app/screens/homescreen.dart';
import 'package:learning_app/screens/register.dart';

import 'package:learning_app/services/auth_services.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final AuthService _authService = AuthService();

  // Track focus for input fields
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  // Remember Me state
  bool _rememberMe = true;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
    _email.addListener(_validateEmail);
  }

  @override
  void dispose() {
    _email.removeListener(_validateEmail);
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _loadSavedEmail() async {
    final savedEmail = await _authService.getSavedEmail();
    if (savedEmail != null && savedEmail.isNotEmpty) {
      setState(() {
        _email.text = savedEmail;
      });
    }
  }

  Widget _buildEnhancedTextField(
      TextEditingController controller, String label,
      {bool isPassword = false, FocusNode? focusNode, String? errorText}) {
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
            focusNode: focusNode,   // text field with focus node
            onChanged: (value) {
              // Force validation update for email field
              if (controller == _email) {
                _validateEmail();
              }
            },
            style: const TextStyle(
              color: Color(0xFF2D3748),
              fontSize: 20,
              fontFamily: 'Lexend',
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

  Widget _buildRememberMeCheckbox() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _rememberMe = !_rememberMe;             // send this boolean  auth services gets this boolean
            });
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _rememberMe ? const Color(0xFF4CAF50) : Colors.transparent,
              border: Border.all(
                color: _rememberMe
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFF9E9E9E),
                width: 3,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: _rememberMe
                ? const Icon(
              Icons.check,
              size: 18,
              color: Colors.white,
            )
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _rememberMe = !_rememberMe;
              });
            },
            child: const Text(
              'Remember Me',
              style: TextStyle(
                color: Color(0xFF2D3748),
                fontFamily: 'Lexend',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              overflow: TextOverflow.ellipsis,
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

  Future<void> _loginUser() async {
    final email = _email.text.trim();
    final password = _password.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter email and password",
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Validate email format (must be @gmail.com)
    if (!_isValidGmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Registration unsuccessful email invalid",
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Check if user exists first
    final emailExists = await _authService.emailExists(email);
    if (!emailExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No account found with this email. Please register first.",
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final userId = await _authService.login(
      email: email,
      password: password,
      rememberMe: _rememberMe,
    );

    if (userId != null && userId.isNotEmpty) {
      // Successfully logged in - redirect to dashboard
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      // Invalid password
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Incorrect password. Please try again.",
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ForgotPasswordDialog(
        authService: _authService,
        isValidGmail: _isValidGmail,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0), // Calm cream background
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 500,
              ),
              child: Container(
                padding:
                const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white, // Clean white card
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      offset: const Offset(6, 6),
                      blurRadius: 12,
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.9),
                      offset: const Offset(-6, -6),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Welcome Back!',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                        fontFamily: 'Lexend',
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 30),
                    _buildEnhancedTextField(
                      _email,
                      'Email',
                      focusNode: _emailFocus,
                      errorText: _emailError,
                    ),
                    const SizedBox(height: 20),
                    _buildEnhancedTextField(_password, 'Password',
                        isPassword: true, focusNode: _passwordFocus),
                    const SizedBox(height: 20),

                    // Remember Me Checkbox
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        _buildRememberMeCheckbox(),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // Forgot Password link - moved below Remember Me
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        TextButton(
                          onPressed: _showForgotPasswordDialog,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: Color(0xFF4A6FA5),
                              fontFamily: 'Lexend', // Dyslexia-friendly font
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),


                    // Checks condition
                    ElevatedButton(
                      onPressed: _email.text.trim().isNotEmpty &&     // if not empty green color
                          _isValidGmail(_email.text.trim())
                          ? _loginUser
                          : null,     // either disabled grey color
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4FAF4F), // Light green (changed from 0xFF4CAF50)
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF9E9E9E),
                        disabledForegroundColor: Colors.white70,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: const BorderSide(color: Color(0xFF76C776), width: 3), // Light green border
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: 20, horizontal: 50),
                        elevation: 4,
                        shadowColor: Colors.black.withOpacity(0.2),
                      ),
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Lexend',
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account?",
                          style: TextStyle(
                            color: Color(0xFF4A5568),
                            fontFamily: 'Lexend',
                            fontSize: 16,
                            letterSpacing: 0.5,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegistrationScreen(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Register now',
                            style: TextStyle(
                              color: Color(0xFF4A6FA5),
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Lexend',
                              fontSize: 18,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Separate StatefulWidget to properly manage TextEditingController lifecycle
class _ForgotPasswordDialog extends StatefulWidget {
  final AuthService authService;
  final bool Function(String) isValidGmail;

  const _ForgotPasswordDialog({
    required this.authService,
    required this.isValidGmail,
  });

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _emailController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Reset Password',
        style: TextStyle(
          fontFamily: 'Lexend',
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: _isLoading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your email and new password',
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 20,
                color: Color(0xFF2D3748),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              style: const TextStyle(
                fontFamily: 'Lexend',
                fontSize: 18,
              ),
              decoration: const InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 18,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                prefixIcon: Icon(Icons.email),
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPasswordController,
              style: const TextStyle(
                fontFamily: 'Lexend',
                fontSize: 18,
              ),
              decoration: const InputDecoration(
                labelText: 'New Password',
                labelStyle: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 18,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                prefixIcon: Icon(Icons.lock),
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              style: const TextStyle(
                fontFamily: 'Lexend',
                fontSize: 18,
              ),
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                labelStyle: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 18,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                prefixIcon: Icon(Icons.lock_outline),
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              ),
              obscureText: true,
            ),
          ],
        ),
      ),
      actions: [
        if (!_isLoading)
          SizedBox(
            height: 60,
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
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
        if (!_isLoading)
          SizedBox(
            height: 60,
            child: ElevatedButton(
              onPressed: _handleResetPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Reset Password',
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // handles password reset
  Future<void> _handleResetPassword() async {
    final email = _emailController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    print('🔐 Password reset requested for: $email');

    if (email.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Please fill all fields",
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 18,
              ),
            ),
            backgroundColor: Color(0xFFE74C3C),
          ),
        );
      }
      return;
    }

    // Validate email format (must be @gmail.com)
    if (!widget.isValidGmail(email)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Please enter a valid Gmail address",
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 18,
              ),
            ),
            backgroundColor: Color(0xFFE74C3C),
          ),
        );
      }
      return;
    }

    if (newPassword != confirmPassword) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Passwords do not match",
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 18,
              ),
            ),
            backgroundColor: Color(0xFFE74C3C),
          ),
        );
      }
      return;
    }

    if (newPassword.length < 6) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Password must be at least 6 characters",
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 18,
              ),
            ),
            backgroundColor: Color(0xFFE74C3C),
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Check if email exists
    final exists = await widget.authService.emailExists(email);
    if (!exists) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "No account found with this email",
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 18,
              ),
            ),
            backgroundColor: Color(0xFFE74C3C),
          ),
        );
      }
      return;
    }

    // Reset password
    print('🔄 Calling resetPassword service...');
    final success = await widget.authService.resetPassword(
      email: email,
      newPassword: newPassword,
    );

    print('📊 Reset password result: $success');

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      print('✅ Password reset successful! Closing dialog...');
      Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Password reset successfully! Please login with your new password.",
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 18,
              ),
            ),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 4),
          ),
        );
        print('✅ Success message shown to user');
      }
    } else {
      print('❌ Password reset failed');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Failed to reset password. Please try again.",
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
}