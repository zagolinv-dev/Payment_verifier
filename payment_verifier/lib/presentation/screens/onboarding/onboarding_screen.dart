import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:payment_verifier/core/constants/app_constants.dart';
import 'package:payment_verifier/core/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

class _OnboardingPage {
  const _OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.tag,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final String tag;
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pages = const [
    _OnboardingPage(
      title: 'Verify Payments\nInstantly',
      subtitle:
          'Confirm transactions from CBE, Telebirr, CBE Birr & Awash Bank in seconds — via receipt scan or reference code.',
      icon: Icons.qr_code_scanner_rounded,
      accentColor: Color(0xFF1F805B),
      tag: 'Step 01',
    ),
    _OnboardingPage(
      title: 'Track Every\nBirr Earned',
      subtitle:
          'Monitor daily income, track tip splits per session, and reconcile multi-wallet settlements in one elegant dashboard.',
      icon: Icons.account_balance_wallet_rounded,
      accentColor: Color(0xFFD4A017),
      tag: 'Step 02',
    ),
  ];

  final _controller = PageController();
  int _current = 0;
  late AnimationController _bgAnim;
  late AnimationController _iconAnim;
  late Animation<double> _iconPulse;

  @override
  void initState() {
    super.initState();
    _bgAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _iconAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _iconPulse = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _iconAnim, curve: Curves.easeInOut),
    );
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.onboardingDoneKey, true);
    if (mounted) context.go(AppRoutes.auth);
  }

  @override
  void dispose() {
    _controller.dispose();
    _bgAnim.dispose();
    _iconAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final page = _pages[_current];

    return Scaffold(
      backgroundColor: const Color(0xFF080E0B),
      body: Stack(
        children: [
          // ── Animated blob background ──────────────────────────────────
          AnimatedBuilder(
            animation: _bgAnim,
            builder: (_, __) => CustomPaint(
              size: Size(size.width, size.height),
              painter: _BlobPainter(
                progress: _bgAnim.value,
                accentColor: page.accentColor,
              ),
            ),
          ),

          // ── Main content ──────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Top bar (Skip + Step indicator)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Step tag pill
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        child: Container(
                          key: ValueKey<String>(page.tag),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: page.accentColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: page.accentColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            page.tag,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: page.accentColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      // Skip
                      TextButton(
                        onPressed: _finish,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                                color: Colors.white.withOpacity(0.15)),
                          ),
                        ),
                        child: Text(
                          'Skip',
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.7),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Hero icon area ────────────────────────────────────────
                Expanded(
                  flex: 5,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      switchInCurve: Curves.easeOutBack,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, anim) => ScaleTransition(
                        scale: anim,
                        child: FadeTransition(opacity: anim, child: child),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey<int>(_current),
                        child: ScaleTransition(
                          scale: _iconPulse,
                          child: _HeroIconWidget(
                            icon: page.icon,
                            accentColor: page.accentColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Bottom glass card ─────────────────────────────────────
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111A14).withOpacity(0.92),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: page.accentColor.withOpacity(0.12),
                        blurRadius: 40,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Page dots
                        Row(
                          children: List.generate(
                            _pages.length,
                            (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeInOut,
                              margin: const EdgeInsets.only(right: 6),
                              width: _current == i ? 28 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _current == i
                                    ? page.accentColor
                                    : Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Title (PageView scrollable)
                        SizedBox(
                          height: 80,
                          child: PageView.builder(
                            controller: _controller,
                            itemCount: _pages.length,
                            onPageChanged: (i) =>
                                setState(() => _current = i),
                            itemBuilder: (_, index) {
                              final p = _pages[index];
                              return Text(
                                p.title,
                                style: GoogleFonts.outfit(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.2,
                                  letterSpacing: -0.5,
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Subtitle
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          child: Text(
                            key: ValueKey<int>(_current),
                            _pages[_current].subtitle,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.55),
                              height: 1.65,
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // CTA Button
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: GestureDetector(
                            onTap: () {
                              if (_current < _pages.length - 1) {
                                _controller.nextPage(
                                  duration: const Duration(milliseconds: 450),
                                  curve: Curves.easeInOutCubic,
                                );
                              } else {
                                _finish();
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 350),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    page.accentColor,
                                    page.accentColor.withOpacity(0.7),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: page.accentColor.withOpacity(0.35),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _current == _pages.length - 1
                                          ? 'Get Started'
                                          : 'Continue',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      _current == _pages.length - 1
                                          ? Icons.rocket_launch_rounded
                                          : Icons.arrow_forward_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero Icon Widget ───────────────────────────────────────────────────────────

class _HeroIconWidget extends StatelessWidget {
  const _HeroIconWidget({
    required this.icon,
    required this.accentColor,
  });

  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow ring
        Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: accentColor.withOpacity(0.08),
              width: 1,
            ),
          ),
        ),
        // Mid glow ring
        Container(
          width: 170,
          height: 170,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accentColor.withOpacity(0.06),
            border: Border.all(
              color: accentColor.withOpacity(0.15),
              width: 1,
            ),
          ),
        ),
        // Inner icon container
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                accentColor.withOpacity(0.3),
                accentColor.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color: accentColor.withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.3),
                blurRadius: 40,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 56,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

// ── Blob Background Painter ────────────────────────────────────────────────────

class _BlobPainter extends CustomPainter {
  _BlobPainter({required this.progress, required this.accentColor});
  final double progress;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    // Blob 1 - top right
    final b1x = size.width * 0.8 + math.sin(progress * 2 * math.pi) * 30;
    final b1y = size.height * 0.15 + math.cos(progress * 2 * math.pi) * 20;
    paint.color = accentColor.withOpacity(0.18);
    canvas.drawCircle(Offset(b1x, b1y), 160, paint);

    // Blob 2 - bottom left
    final b2x = size.width * 0.1 + math.cos(progress * 2 * math.pi + 1) * 25;
    final b2y =
        size.height * 0.7 + math.sin(progress * 2 * math.pi + 1) * 30;
    paint.color = accentColor.withOpacity(0.1);
    canvas.drawCircle(Offset(b2x, b2y), 130, paint);

    // Blob 3 - center subtle
    final b3x =
        size.width * 0.5 + math.sin(progress * 2 * math.pi + 2) * 40;
    final b3y =
        size.height * 0.4 + math.cos(progress * 2 * math.pi + 2) * 25;
    paint.color = accentColor.withOpacity(0.06);
    canvas.drawCircle(Offset(b3x, b3y), 100, paint);
  }

  @override
  bool shouldRepaint(_BlobPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.accentColor != accentColor;
}
