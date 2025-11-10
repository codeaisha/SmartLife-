import 'dart:async';
import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'dart:math';

class SplashScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool)? toggleTheme;
  final bool isLoggedIn;
  final Function(bool)? updateLoginState;

  const SplashScreen({
    super.key,
    required this.isDarkMode,
    this.toggleTheme,
    required this.isLoggedIn,
    this.updateLoginState,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  bool _visible = false;
  late AnimationController _iconController;
  late Animation<double> _iconAnimation;
  late AnimationController _gradientController;

  String _title = "";
  final String _fullTitle = "SmartLife+";

  @override
  void initState() {
    super.initState();

    _startTypingAnimation();

    Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _visible = true;
      });
    });

    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _iconAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.easeInOut),
    );

    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    Timer(const Duration(seconds: 4), () {
      if (widget.isLoggedIn) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              isDarkMode: widget.isDarkMode,
              updateTheme: widget.toggleTheme,
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => LoginScreen(
              isDarkMode: widget.isDarkMode,
              toggleTheme: widget.toggleTheme,
              updateLoginState: widget.updateLoginState,
            ),
          ),
        );
      }
    });
  }

  void _startTypingAnimation() {
    int i = 0;
    Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (i < _fullTitle.length) {
        setState(() {
          _title += _fullTitle[i];
          i++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _iconController.dispose();
    _gradientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _gradientController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.deepPurple.shade400,
                  Colors.purple.shade300,
                  Colors.blueAccent.shade100,
                  Colors.teal.shade200,
                ],
                begin: Alignment(-1 + 2 * _gradientController.value, -1),
                end: Alignment(1, 1 - 2 * _gradientController.value),
              ),
            ),
            child: child,
          );
        },
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _iconAnimation,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.mood, size: 140, color: Colors.white24),
                    Icon(Icons.mood, size: 120, color: Colors.white),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AnimatedOpacity(
                opacity: _visible ? 1.0 : 0.0,
                duration: const Duration(seconds: 2),
                child: Text(
                  _title,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              AnimatedOpacity(
                opacity: _visible ? 1.0 : 0.0,
                duration: const Duration(seconds: 2),
                child: const Text(
                  "AI-Powered Personal Assistant\nfor Home & Wellness",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              AnimatedOpacity(
                opacity: _visible ? 1.0 : 0.0,
                duration: const Duration(seconds: 2),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    strokeWidth: 5,
                    color: Colors.white70,
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
