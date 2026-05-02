import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/features/onboarding/application/onboarding_provider.dart';
import 'package:lilia_app/routing/app_route_enum.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _floatController;
  late AnimationController _fadeController;

  final List<_PageData> _pages = [
    _PageData(
      title: 'Decouvrez les saveurs',
      description:
          'Les meilleurs restaurants de Brazzaville reunis dans une seule app. Commandez vos plats preferes en quelques clics.',
      gradientStart: Color(0xFFFF6B35),
      gradientEnd: Color(0xFFE84545),
      bgGradientStart: Color(0xFFFFF5F0),
      bgGradientEnd: Color(0xFFFFE8E0),
    ),
    _PageData(
      title: 'Livraison express',
      description:
          'Faites-vous livrer a domicile en un temps record ou recuperez votre commande directement au restaurant.',
      gradientStart: Color(0xFFE84545),
      gradientEnd: Color(0xFFD63384),
      bgGradientStart: Color(0xFFFFF0F3),
      bgGradientEnd: Color(0xFFFFE0EB),
    ),
    _PageData(
      title: 'Paiement simple',
      description:
          'Payez facilement et en toute securite via MTN Mobile Money ou en especes a la livraison.',
      gradientStart: Color(0xFFD63384),
      gradientEnd: Color(0xFF7B2FBE),
      bgGradientStart: Color(0xFFF8F0FF),
      bgGradientEnd: Color(0xFFF0E4FF),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _floatController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    _fadeController.forward(from: 0.0);
    setState(() {
      _currentPage = page;
    });
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _completeOnboarding() async {
    await ref.read(onboardingStatusProvider.notifier).completeOnboarding();
    if (mounted) {
      context.goNamed(AppRoutes.signIn.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [page.bgGradientStart, page.bgGradientEnd],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 12),
                  child: TextButton(
                    onPressed: _completeOnboarding,
                    child: Text(
                      'Passer',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),

              // Page content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _buildPage(index);
                  },
                ),
              ),

              // Bottom section
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Column(
                  children: [
                    // Dot indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (index) => _buildDot(index),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Gradient button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [page.gradientStart, page.gradientEnd],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: page.gradientStart.withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _currentPage == _pages.length - 1
                                    ? 'Commencer'
                                    : 'Suivant',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _currentPage == _pages.length - 1
                                    ? Icons.arrow_forward_rounded
                                    : Icons.arrow_forward_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(int index) {
    final data = _pages[index];
    return FadeTransition(
      opacity: _fadeController,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Illustration
            SizedBox(
              width: 280,
              height: 280,
              child: _buildIllustration(index, data),
            ),
            const SizedBox(height: 48),

            // Title
            Text(
              data.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Colors.grey[850],
                height: 1.15,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              data.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
                height: 1.6,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIllustration(int index, _PageData data) {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        final floatValue = _floatController.value;
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Background soft circle
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      data.gradientStart.withValues(alpha: 0.12),
                      data.gradientStart.withValues(alpha: 0.03),
                    ],
                  ),
                ),
              ),
            ),

            // Main gradient circle
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [data.gradientStart, data.gradientEnd],
                ),
                boxShadow: [
                  BoxShadow(
                    color: data.gradientEnd.withValues(alpha: 0.35),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Icon(
                _mainIcon(index),
                size: 72,
                color: Colors.white,
              ),
            ),

            // Floating elements specific to each page
            ..._buildFloatingElements(index, data, floatValue),
          ],
        );
      },
    );
  }

  IconData _mainIcon(int index) {
    switch (index) {
      case 0:
        return Icons.restaurant_menu_rounded;
      case 1:
        return Icons.delivery_dining_rounded;
      case 2:
        return Icons.smartphone_rounded;
      default:
        return Icons.restaurant_menu_rounded;
    }
  }

  List<Widget> _buildFloatingElements(
      int index, _PageData data, double floatValue) {
    switch (index) {
      case 0:
        return _buildFoodElements(data, floatValue);
      case 1:
        return _buildDeliveryElements(data, floatValue);
      case 2:
        return _buildPaymentElements(data, floatValue);
      default:
        return [];
    }
  }

  // Page 1: floating food cards
  List<Widget> _buildFoodElements(_PageData data, double v) {
    return [
      // Top-left: pizza
      Positioned(
        top: 10 + (v * 8),
        left: 10,
        child: _FloatingCard(
          icon: Icons.local_pizza_rounded,
          color: data.gradientStart,
          size: 52,
          iconSize: 26,
        ),
      ),
      // Top-right: coffee
      Positioned(
        top: 25 - (v * 6),
        right: 15,
        child: _FloatingCard(
          icon: Icons.coffee_rounded,
          color: data.gradientEnd,
          size: 46,
          iconSize: 22,
        ),
      ),
      // Bottom-left: burger
      Positioned(
        bottom: 30 - (v * 8),
        left: 20,
        child: _FloatingCard(
          icon: Icons.lunch_dining_rounded,
          color: Color(0xFFFF8C42),
          size: 50,
          iconSize: 24,
        ),
      ),
      // Bottom-right: bowl
      Positioned(
        bottom: 15 + (v * 10),
        right: 10,
        child: _FloatingCard(
          icon: Icons.ramen_dining_rounded,
          color: data.gradientEnd,
          size: 48,
          iconSize: 22,
        ),
      ),
      // Small star accent
      Positioned(
        top: 60,
        right: 45,
        child: Transform.rotate(
          angle: v * math.pi * 0.1,
          child: Icon(
            Icons.star_rounded,
            size: 20,
            color: data.gradientStart.withValues(alpha: 0.5),
          ),
        ),
      ),
    ];
  }

  // Page 2: delivery elements
  List<Widget> _buildDeliveryElements(_PageData data, double v) {
    return [
      // Speed lines (concentric arcs)
      Positioned(
        left: -10 + (v * 5),
        top: 80,
        child: Icon(
          Icons.speed_rounded,
          size: 40,
          color: data.gradientStart.withValues(alpha: 0.25),
        ),
      ),
      // Top-right: clock
      Positioned(
        top: 15 - (v * 6),
        right: 20,
        child: _FloatingCard(
          icon: Icons.schedule_rounded,
          color: data.gradientStart,
          size: 50,
          iconSize: 24,
        ),
      ),
      // Bottom-left: location pin
      Positioned(
        bottom: 25 + (v * 8),
        left: 15,
        child: _FloatingCard(
          icon: Icons.location_on_rounded,
          color: data.gradientEnd,
          size: 48,
          iconSize: 24,
        ),
      ),
      // Bottom-right: home
      Positioned(
        bottom: 45 - (v * 6),
        right: 25,
        child: _FloatingCard(
          icon: Icons.home_rounded,
          color: Color(0xFFFF6B8A),
          size: 46,
          iconSize: 22,
        ),
      ),
      // Top-left: fast food bag
      Positioned(
        top: 30 + (v * 10),
        left: 25,
        child: _FloatingCard(
          icon: Icons.shopping_bag_rounded,
          color: data.gradientStart.withValues(alpha: 0.9),
          size: 44,
          iconSize: 20,
        ),
      ),
    ];
  }

  // Page 3: payment elements
  List<Widget> _buildPaymentElements(_PageData data, double v) {
    return [
      // Top-left: shield / security
      Positioned(
        top: 15 + (v * 8),
        left: 15,
        child: _FloatingCard(
          icon: Icons.verified_user_rounded,
          color: data.gradientStart,
          size: 50,
          iconSize: 24,
        ),
      ),
      // Top-right: money
      Positioned(
        top: 30 - (v * 6),
        right: 15,
        child: _FloatingCard(
          icon: Icons.payments_rounded,
          color: data.gradientEnd,
          size: 48,
          iconSize: 22,
        ),
      ),
      // Bottom-left: phone
      Positioned(
        bottom: 25 - (v * 8),
        left: 25,
        child: _FloatingCard(
          icon: Icons.phone_android_rounded,
          color: Color(0xFF9B59B6),
          size: 46,
          iconSize: 22,
        ),
      ),
      // Bottom-right: check circle
      Positioned(
        bottom: 40 + (v * 10),
        right: 20,
        child: _FloatingCard(
          icon: Icons.check_circle_rounded,
          color: Color(0xFF27AE60),
          size: 44,
          iconSize: 22,
        ),
      ),
      // Small lock accent
      Positioned(
        top: 70,
        left: 55,
        child: Transform.rotate(
          angle: v * math.pi * 0.08,
          child: Icon(
            Icons.lock_rounded,
            size: 18,
            color: data.gradientEnd.withValues(alpha: 0.4),
          ),
        ),
      ),
    ];
  }

  Widget _buildDot(int index) {
    final isActive = index == _currentPage;
    final page = _pages[_currentPage];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      width: isActive ? 28 : 10,
      height: 10,
      decoration: BoxDecoration(
        color: isActive
            ? page.gradientStart
            : page.gradientStart.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }
}

/// Floating card widget used in illustrations
class _FloatingCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  const _FloatingCard({
    required this.icon,
    required this.color,
    required this.size,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}

/// Data model for each onboarding page
class _PageData {
  final String title;
  final String description;
  final Color gradientStart;
  final Color gradientEnd;
  final Color bgGradientStart;
  final Color bgGradientEnd;

  _PageData({
    required this.title,
    required this.description,
    required this.gradientStart,
    required this.gradientEnd,
    required this.bgGradientStart,
    required this.bgGradientEnd,
  });
}
