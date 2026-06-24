import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:payment_verifier/core/theme/app_theme.dart';
import 'package:payment_verifier/presentation/providers/auth_provider.dart';
import 'package:payment_verifier/presentation/widgets/custom_text_field.dart';
import 'package:payment_verifier/presentation/widgets/gradient_button.dart';
import 'dart:math' as math;

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool _isSignIn = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isSignIn = !_isSignIn;
      _formKey.currentState?.reset();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
    _animController.forward(from: 0);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = ref.read(authProvider.notifier);
    if (_isSignIn) {
      await auth.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } else {
      await auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _emailController.text.trim().split('@').first,
      );
    }

    final authState = ref.read(authProvider);
    if (authState.hasError && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.error,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Text(
            authState.error.toString().replaceAll('Exception:', '').trim(),
            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF080E0B),
      body: Stack(
        children: [
          // ── Animated background ──────────────────────────────────────────
          const _AuthBackground(),

          // ── Top logo section ─────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo badge
                    Hero(
                      tag: 'app_logo',
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryGreen.withOpacity(0.4),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            "T",
                            style: GoogleFonts.outfit(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "T's Pay",
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isSignIn
                          ? 'Welcome back. Sign in to continue.'
                          : 'Create your account to get started.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom sheet card ────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _animController,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, _slideAnim.value),
                child: Opacity(opacity: _fadeAnim.value, child: child),
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: size.height * 0.68,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1A12),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(36)),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.07),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 40,
                      offset: const Offset(0, -10),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tab switcher
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Row(
                          children: [
                            _AuthTab(
                              label: 'Sign In',
                              isActive: _isSignIn,
                              onTap: () {
                                if (!_isSignIn) _toggleMode();
                              },
                            ),
                            _AuthTab(
                              label: 'Sign Up',
                              isActive: !_isSignIn,
                              onTap: () {
                                if (_isSignIn) _toggleMode();
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Form
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppTextField(
                              label: 'Email Address',
                              hint: 'you@example.com',
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              prefixIcon: const Icon(
                                Icons.email_outlined,
                                color: AppTheme.textTertiary,
                                size: 20,
                              ),
                              textInputAction: TextInputAction.next,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                if (!v.contains('@')) return 'Invalid email';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            AppTextField(
                              label: 'Password',
                              hint: '••••••••',
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                                color: AppTheme.textTertiary,
                                size: 20,
                              ),
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: AppTheme.textTertiary,
                                  size: 20,
                                ),
                              ),
                              textInputAction: _isSignIn
                                  ? TextInputAction.done
                                  : TextInputAction.next,
                              onFieldSubmitted:
                                  _isSignIn ? (_) => _submit() : null,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                if (v.length < 6) return 'Min 6 characters';
                                return null;
                              },
                            ),

                            // Confirm password (Sign Up only)
                            if (!_isSignIn) ...[
                              const SizedBox(height: 14),
                              AppTextField(
                                label: 'Confirm Password',
                                hint: '••••••••',
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                  color: AppTheme.textTertiary,
                                  size: 20,
                                ),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(() =>
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword),
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: AppTheme.textTertiary,
                                    size: 20,
                                  ),
                                ),
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Required';
                                  if (v != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),
                            ],

                            // Forgot password (Sign In only)
                            if (_isSignIn)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {},
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4, horizontal: 0),
                                  ),
                                  child: Text(
                                    'Forgot Password?',
                                    style: GoogleFonts.inter(
                                      color: AppTheme.accentGold,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),

                            const SizedBox(height: 24),

                            // Primary action button
                            GradientButton(
                              label: _isSignIn ? 'Sign In' : 'Create Account',
                              icon: _isSignIn
                                  ? Icons.login_rounded
                                  : Icons.person_add_rounded,
                              height: 52,
                              borderRadius: 16,
                              isLoading: isLoading,
                              onPressed: isLoading ? null : _submit,
                            ),

                            const SizedBox(height: 20),

                            // OR divider
                            Row(
                              children: [
                                Expanded(
                                    child: Divider(
                                        color: Colors.white.withOpacity(0.1))),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Text(
                                    'OR',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.white.withOpacity(0.3),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                                Expanded(
                                    child: Divider(
                                        color: Colors.white.withOpacity(0.1))),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Toggle mode button
                            GestureDetector(
                              onTap: _toggleMode,
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppTheme.primaryGreen
                                        .withOpacity(0.35),
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    _isSignIn
                                        ? "Don't have an account? Sign Up"
                                        : 'Already have an account? Sign In',
                                    style: GoogleFonts.inter(
                                      color: AppTheme.primaryGreen,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Auth Tab Widget ────────────────────────────────────────────────────────────

class _AuthTab extends StatelessWidget {
  const _AuthTab({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isActive ? AppTheme.primaryGradient : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                color: isActive
                    ? Colors.white
                    : Colors.white.withOpacity(0.4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Animated Background ────────────────────────────────────────────────────────

class _AuthBackground extends StatefulWidget {
  const _AuthBackground();

  @override
  State<_AuthBackground> createState() => _AuthBackgroundState();
}

class _AuthBackgroundState extends State<_AuthBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        size: size,
        painter: _AuthBgPainter(progress: _ctrl.value),
      ),
    );
  }
}

class _AuthBgPainter extends CustomPainter {
  _AuthBgPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 90);

    // Top right glow
    paint.color = const Color(0xFF1F805B).withOpacity(0.2);
    final x1 = size.width * 0.85 + math.sin(progress * 2 * math.pi) * 25;
    final y1 = size.height * 0.12 + math.cos(progress * 2 * math.pi) * 20;
    canvas.drawCircle(Offset(x1, y1), 180, paint);

    // Bottom left glow
    paint.color = const Color(0xFF1F805B).withOpacity(0.1);
    final x2 = size.width * 0.1 + math.cos(progress * 2 * math.pi + 2) * 20;
    final y2 = size.height * 0.45 + math.sin(progress * 2 * math.pi + 2) * 25;
    canvas.drawCircle(Offset(x2, y2), 130, paint);

    // Gold accent
    paint.color = const Color(0xFFD4A017).withOpacity(0.07);
    final x3 = size.width * 0.5 + math.sin(progress * 2 * math.pi + 4) * 35;
    final y3 = size.height * 0.3 + math.cos(progress * 2 * math.pi + 4) * 20;
    canvas.drawCircle(Offset(x3, y3), 100, paint);
  }

  @override
  bool shouldRepaint(_AuthBgPainter old) => old.progress != progress;
}
