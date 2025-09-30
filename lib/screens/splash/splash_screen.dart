import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../home/index.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.7, 1.0, curve: Curves.easeInOut),
    ));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.8, 1.0, curve: Curves.easeInOut),
    ));

    // Start animation after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _controller.forward().then((_) {
          // Navigate to home screen
          if (mounted) {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const HomeScreen(),
                transitionDuration: const Duration(milliseconds: 300),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
              ),
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value == 0.0 ? 1.0 : _scaleAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value == 0.0 ? 1.0 : _opacityAnimation.value,
              child: Container(
                color: const Color(0xFF121212), // Dark background
                // decoration: const BoxDecoration(
                //   gradient: LinearGradient(
                //     begin: Alignment.topLeft,
                //     end: Alignment.bottomRight,
                //     colors: [
                //       Color(0xFF64B5F6), // Light blue
                //       Color(0xFF2196F3), // Blue
                //       Color(0xFF1976D2), // Darker blue
                //       Color(0xFF0D47A1), // Deep blue
                //     ],
                //     stops: [0.0, 0.4, 0.8, 1.0],
                //   ),
                // ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App Icon/Logo - Fixed aspect ratio
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/images/appLogo.jpg',
                            fit: BoxFit.contain, // Changed from cover to contain
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.security,
                                size: 70,
                                color: Color(0xFF121212), // Color(0xFF2196F3) - Blue
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // App Name TORX with colored letters - TOR normal, X bold italic
                      RichText(
                        textAlign: TextAlign.center,
                        text: const TextSpan(
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.normal,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 3),
                                blurRadius: 8,
                                color: Colors.black26,
                              ),
                            ],
                          ),
                          children: [
                            TextSpan(
                              text: 'T',
                              style: TextStyle(color: Color(0xFF9C27B0)), // Purple
                            ),
                            TextSpan(
                              text: 'O',
                              style: TextStyle(color: Color(0xFF4CAF50)), // Green
                            ),
                            TextSpan(
                              text: 'R',
                              style: TextStyle(color: Color(0xFF2196F3)), // Blue
                            ),
                            TextSpan(
                              text: 'X',
                              style: TextStyle(
                                color: Color(0xFFE53935), // Red
                                fontWeight: FontWeight.bold,
                                fontStyle: FontStyle.italic,
                                fontSize: 56, // Slightly bigger for emphasis
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 50),

                      // Loading Animation
                      LoadingAnimationWidget.progressiveDots(
                        color: Colors.white,
                        size: 60,
                      ),
                      const SizedBox(height: 15),

                      // Loading text - centered below animation
                      Text(
                        'Loading...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.w300,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}