import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:learning_app/screens/Login_screen.dart';
import 'package:learning_app/screens/homescreen.dart';

import 'package:learning_app/services/auth_services.dart';


class SplashScreen extends StatefulWidget {
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {

  // ========== MAIN 1: ANIMATION VARIABLES ==========

  late AnimationController _controller;
  late Animation<double> _scaleAnimation;   //defines  value change scales
  late Animation<double> _fadeAnimation;    // fade

  @override
  void initState() {
    super.initState();

    // Animations
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _scaleAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();

    // Navigate after 3s
    Timer(
      const Duration(seconds: 5),
          () async {
        // Check if user should be auto-logged in
        bool isLoggedIn = await AuthService().isUserLoggedIn();
        // Go to HomeScreen if logged in, else LoginScreen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => isLoggedIn ? const HomeScreen() : const LoginScreen(),
            ),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {

    // ========== MAIN 6: BUILD UI WITH ANIMATIONS ==========
    return Scaffold(
      // Premium gradient background
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F5F0), Color(0xFFFFFBF5)], // Calm cream gradient
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Circle with glow
                  Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4A6FA5), Color(0xFF3A5A8A)], // Calm blue
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4A6FA5).withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),

                  // Center Text
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      const Text(
                        "READIFY",
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "LEARN FROM HOME",
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: Color(0xFFFFF3E0), // Calm cream
                        ),
                      ),
                    ],
                  ),

                  // Animated bubbles
                  ..._buildBubbles(),

                  // Decorative angled lines
                  Positioned(
                    left: 30,
                    top: 200,
                    child: Column(
                      children: [
                        buildAngledLine(),
                        const SizedBox(height: 5),
                        buildAngledLine(),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 30,
                    top: 90,
                    child: Column(
                      children: [
                        buildAngledLine(),
                        const SizedBox(height: 5),
                        buildAngledLine(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Animated bubbles
  List<Widget> _buildBubbles() {
    return [
      _animatedBubble(top: 40, left: 60, color: const Color(0xFF4A6FA5)), // Calm blue
      _animatedBubble(top: 60, right: 50, color: const Color(0xFF4CAF50)), // Calm green
      _animatedBubble(bottom: 50, left: 70, color: const Color(0xFF4CAF50)), // Calm green
      _animatedBubble(bottom: 60, right: 65, color: const Color(0xFF4A6FA5)), // Calm blue
      _animatedBubble(top: 120, left: 20, color: const Color(0xFF4CAF50), small: true), // Calm green
      _animatedBubble(top: 130, right: 25, color: const Color(0xFF4A6FA5), small: true), // Calm blue
    ];
  }

  Widget _animatedBubble({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required Color color,
    bool small = false,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: ScaleTransition(
        scale: Tween(begin: 0.8, end: 1.2).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(0.3, 1.0, curve: Curves.easeInOut),
          ),
        ),
        child: CircleAvatar(
          radius: small ? 6 : 10,
          backgroundColor: color,
        ),
      ),
    );
  }

  // Decorative angled line
  Widget buildAngledLine() {
    return Transform.rotate(
      angle: pi / 4,
      child: Container(
        width: 28,
        height: 3,
        color: const Color(0xFF4A6FA5), // Calm blue
      ),
    );
  }
}
