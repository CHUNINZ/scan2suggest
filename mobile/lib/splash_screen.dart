import 'package:flutter/material.dart';
import 'dart:async';
import 'onboarding.dart';
import 'main_navigation_controller.dart';
import 'app_theme.dart';
import 'services/api_service.dart';

class SplashScreen extends StatefulWidget {
  final bool isPostSignup;
  final bool isPostLogout;
  
  const SplashScreen({
    super.key,
    this.isPostSignup = false,
    this.isPostLogout = false,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _cookingElementsController;
  late AnimationController _textController;
  
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoFadeAnimation;
  late Animation<double> _whiskRotationAnimation;
  late Animation<double> _potSlideAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<double> _textScaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Logo animation controller (2 seconds)
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    // Cooking elements animation controller
    _cookingElementsController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    // Text animation controller
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    // Logo animations - elegant fade and scale
    _logoScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    ));
    
    _logoFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    ));
    
    // Cooking elements animations
    _whiskRotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cookingElementsController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeInOut),
    ));
    
    _potSlideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cookingElementsController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutBack),
    ));
    
    // Text animations
    _textFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
    ));
    
    _textScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
    ));
    
    _startAnimationSequence();
  }
  
  void _startAnimationSequence() async {
    // Start cooking elements animation first
    _cookingElementsController.forward();
    
    // Slight delay then start logo animation
    await Future.delayed(const Duration(milliseconds: 200));
    _logoController.forward();
    
    // Start text animation
    await Future.delayed(const Duration(milliseconds: 400));
    _textController.forward();
    
    // Determine timing based on context
    int splashDuration;
    if (widget.isPostLogout) {
      splashDuration = 1000; // Shorter for logout flow
    } else if (widget.isPostSignup) {
      splashDuration = 1500; // Medium for post-signup
    } else {
      splashDuration = 2800; // Full duration for app launch
    }
    
    await Future.delayed(Duration(milliseconds: splashDuration));
    
    if (mounted) {
      _navigateToNextScreen();
    }
  }
  
  void _navigateToNextScreen() async {
    Widget nextScreen;
    String navigationReason;

    // Try auto-login using stored JWT token
    await ApiService.initializeToken();
    try {
      final user = await ApiService.getCurrentUser();
      if (user != null && user['success'] == true) {
        nextScreen = const MainNavigationController();
        navigationReason = 'autologin';
      } else {
        nextScreen = const Onboarding();
        navigationReason = 'first_launch';
      }
    } catch (e) {
      // Token invalid or not present, go to onboarding
      nextScreen = const Onboarding();
      navigationReason = 'first_launch';
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return nextScreen;
        },
        transitionDuration: const Duration(milliseconds: 800),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (navigationReason == 'logout') {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 1.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          } else {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _cookingElementsController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: AppTheme.primaryGradientDecoration(
          borderRadius: BorderRadius.zero,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background cooking elements with animations
            _buildAnimatedBackground(),
            
            // Main logo content
            _buildMainContent(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _cookingElementsController,
        _whiskRotationAnimation,
        _potSlideAnimation,
      ]),
      builder: (context, child) {
        return Stack(
          children: [
            // Animated whisk in top-left
            Positioned(
              left: 40 + (20 * (1 - _potSlideAnimation.value)),
              top: 120,
              child: Transform.rotate(
                angle: _whiskRotationAnimation.value * 0.5,
                child: Opacity(
                  opacity: _potSlideAnimation.value * 0.3,
                  child: Icon(
                    Icons.kitchen,
                    size: 80,
                    color: AppTheme.surfaceWhite.withOpacity(0.2),
                  ),
                ),
              ),
            ),
            
            // Animated pot in bottom-right
            Positioned(
              right: 50 + (30 * (1 - _potSlideAnimation.value)),
              bottom: 150,
              child: Transform.scale(
                scale: _potSlideAnimation.value,
                child: Opacity(
                  opacity: _potSlideAnimation.value * 0.3,
                  child: Icon(
                    Icons.soup_kitchen,
                    size: 100,
                    color: AppTheme.surfaceWhite.withOpacity(0.2),
                  ),
                ),
              ),
            ),
            
            // Animated cooking utensils
            Positioned(
              left: MediaQuery.of(context).size.width - 100,
              top: 200,
              child: Transform.rotate(
                angle: -_whiskRotationAnimation.value * 0.3,
                child: Opacity(
                  opacity: _whiskRotationAnimation.value * 0.25,
                  child: Icon(
                    Icons.restaurant,
                    size: 60,
                    color: AppTheme.surfaceWhite.withOpacity(0.2),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildMainContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Animated cooking icon that morphs into final state
        AnimatedBuilder(
          animation: Listenable.merge([
            _logoController,
            _cookingElementsController,
          ]),
          builder: (context, child) {
            return Transform.scale(
              scale: _logoScaleAnimation.value,
              child: Opacity(
                opacity: _logoFadeAnimation.value,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.surfaceWhite.withOpacity(0.15),
                    border: Border.all(
                      color: AppTheme.surfaceWhite.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Multiple cooking icons that animate in sequence
                      if (_cookingElementsController.value > 0.0 && _cookingElementsController.value < 0.3)
                        Transform.rotate(
                          angle: _whiskRotationAnimation.value * 2,
                          child: const Icon(
                            Icons.kitchen,
                            size: 50,
                            color: AppTheme.surfaceWhite,
                          ),
                        ),
                      
                      if (_cookingElementsController.value >= 0.3 && _cookingElementsController.value < 0.6)
                        Transform.scale(
                          scale: _potSlideAnimation.value,
                          child: const Icon(
                            Icons.soup_kitchen,
                            size: 50,
                            color: AppTheme.surfaceWhite,
                          ),
                        ),
                      
                      if (_cookingElementsController.value >= 0.6)
                        Transform.rotate(
                          angle: _whiskRotationAnimation.value * 0.5,
                          child: const Icon(
                            Icons.restaurant_menu,
                            size: 50,
                            color: AppTheme.surfaceWhite,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        
        // Show logout message when logging out
        if (widget.isPostLogout) ...[
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: _textController,
            builder: (context, child) {
              return Opacity(
                opacity: _textFadeAnimation.value,
                child: const Text(
                  'Thanks for cooking with us!',
                  style: TextStyle(
                    color: AppTheme.surfaceWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              );
            },
          ),
        ],
        
        // Loading indicator for post-signup or post-logout
        if (widget.isPostSignup || widget.isPostLogout) ...[
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: _textController,
            builder: (context, child) {
              return Opacity(
                opacity: _textFadeAnimation.value,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.surfaceWhite.withOpacity(0.7),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}