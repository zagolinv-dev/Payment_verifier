import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:payment_verifier/core/router/app_router.dart';
import 'package:payment_verifier/core/theme/app_theme.dart';
import 'package:payment_verifier/presentation/providers/auth_provider.dart';
import 'package:payment_verifier/presentation/widgets/custom_text_field.dart';
import 'package:payment_verifier/presentation/widgets/gradient_button.dart';
import 'package:payment_verifier/presentation/widgets/curved_shape.dart';
import 'dart:math' as math;

enum _AuthStep {
  signIn,
  roleSelect,
  managerForm,
  managerPending,
  waiterInfo,
  forgotPassword,
}

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  _AuthStep _currentStep = _AuthStep.signIn;
  String _selectedSignInRole = 'Manager'; // 'Manager' or 'Waiter'

  // Controllers
  final _signInFormKey = GlobalKey<FormState>();
  final _signInEmailController = TextEditingController();
  final _signInPasswordController = TextEditingController();

  final _managerFormKey = GlobalKey<FormState>();
  final _cafeNameController = TextEditingController();
  final _managerPhoneController = TextEditingController();
  final _managerCityController = TextEditingController();
  final _managerEmailController = TextEditingController();
  final _managerPasswordController = TextEditingController();
  final _managerConfirmPasswordController = TextEditingController();
  final _managerDescController = TextEditingController();

  String _selectedCategory = 'Food & Beverage';
  final List<String> _categories = [
    'Food & Beverage',
    'Retail / Supermarket',
    'Hotel & Lodging',
    'Entertainment',
    'Other'
  ];

  bool _obscureSignInPassword = true;
  bool _obscureManagerPassword = true;
  bool _obscureManagerConfirmPassword = true;
  bool _isLoadingSignUp = false;

  late final AnimationController _bgAnimController;

  @override
  void initState() {
    super.initState();
    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _signInEmailController.dispose();
    _signInPasswordController.dispose();
    _cafeNameController.dispose();
    _managerPhoneController.dispose();
    _managerCityController.dispose();
    _managerEmailController.dispose();
    _managerPasswordController.dispose();
    _managerConfirmPasswordController.dispose();
    _managerDescController.dispose();
    _bgAnimController.dispose();
    super.dispose();
  }

  void _changeStep(_AuthStep step) {
    setState(() {
      _currentStep = step;
    });
  }

  Future<void> _submitSignIn() async {
    if (!_signInFormKey.currentState!.validate()) return;

    final auth = ref.read(authProvider.notifier);
    await auth.signIn(
      email: _signInEmailController.text.trim(),
      password: _signInPasswordController.text,
      role: _selectedSignInRole,
    );

    if (!mounted) return;
    final authState = ref.read(authProvider);
    if (authState.hasError) {
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
    } else if (authState.valueOrNull != null) {
      context.go(AppRoutes.dashboard);
    }
  }

  Future<void> _submitManagerSignUp() async {
    if (!_managerFormKey.currentState!.validate()) return;

    setState(() => _isLoadingSignUp = true);
    try {
      final auth = ref.read(authProvider.notifier);
      await auth.signUp(
        email: _managerEmailController.text.trim(),
        password: _managerPasswordController.text,
        fullName: _cafeNameController.text.trim(),
      );
      if (!mounted) return;
      final authState = ref.read(authProvider);
      if (authState.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.error,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(authState.error.toString().replaceAll('Exception:', '').trim(), style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
          ),
        );
        setState(() => _isLoadingSignUp = false);
        return;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.error,
          content: Text('Sign up failed: $e', style: GoogleFonts.inter(color: Colors.white)),
        ),
      );
      setState(() => _isLoadingSignUp = false);
      return;
    }
    if (!mounted) return;
    setState(() => _isLoadingSignUp = false);
    _changeStep(_AuthStep.managerPending);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isSignInLoading = authState.isLoading;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF080E0B),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Curved top shape
          ClipPath(
            clipper: const CurvedTopShape(heightFactor: 0.5),
            child: Container(
              height: size.height * 0.55,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryGreenDark,
                    AppTheme.primaryGreenDim,
                    AppTheme.primaryGreen.withOpacity(0.3),
                  ],
                ),
              ),
            ),
          ),
          // Curved bottom shape
          Positioned(
            bottom: 0,
            child: ClipPath(
              clipper: const CurvedBottomShape(heightFactor: 0.15),
              child: Container(
                width: size.width,
                height: size.height * 0.25,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.accentGold.withOpacity(0.15),
                      AppTheme.accentGold.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Animated Background Paint
          AnimatedBuilder(
            animation: _bgAnimController,
            builder: (_, __) => CustomPaint(
              size: size,
              painter: _AuthBgPainter(progress: _bgAnimController.value),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    
                    // Wizard Card
                    Container(
                      constraints: const BoxConstraints(maxWidth: 460),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E1A12).withOpacity(0.94),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.06),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(28),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, anim) {
                          return FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.05),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: anim,
                                curve: Curves.easeOutCubic,
                              )),
                              child: child,
                            ),
                          );
                        },
                        child: _buildCurrentStep(isSignInLoading || _isLoadingSignUp),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    bool isShortHeader = _currentStep == _AuthStep.managerForm;
    return Column(
      children: [
        // App Logo Icon
        Hero(
          tag: 'app_logo',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              'assets/images/T_s_verify_logo.png',
              width: isShortHeader ? 48 : 64,
              height: isShortHeader ? 48 : 64,
              fit: BoxFit.cover,
            ),
          ),
        ),
        if (!isShortHeader) ...[
          const SizedBox(height: 16),
          Text(
            "T's Verify",
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  Widget _buildCurrentStep(bool isLoading) {
    switch (_currentStep) {
      case _AuthStep.signIn:
        return _buildSignInStep(isLoading);
      case _AuthStep.roleSelect:
        return _buildRoleSelectStep();
      case _AuthStep.managerForm:
        return _buildManagerFormStep(isLoading);
      case _AuthStep.managerPending:
        return _buildManagerPendingStep();
      case _AuthStep.waiterInfo:
        return _buildWaiterInfoStep();
      case _AuthStep.forgotPassword:
        return _buildForgotPasswordStep();
    }
  }

  // ── Step 1: Sign In ─────────────────────────────────────────────────────────

  Widget _buildSignInStep(bool isLoading) {
    return Form(
      key: _signInFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Sign In',
            style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Select your role and enter your credentials',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.5)),
          ),
          const SizedBox(height: 20),

          // ── Role Selector ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                _RoleToggleOption(
                  label: 'Manager',
                  icon: Icons.store_rounded,
                  isSelected: _selectedSignInRole == 'Manager',
                  color: AppTheme.accentGold,
                  onTap: () => setState(() => _selectedSignInRole = 'Manager'),
                ),
                _RoleToggleOption(
                  label: 'Waiter',
                  icon: Icons.badge_rounded,
                  isSelected: _selectedSignInRole == 'Waiter',
                  color: AppTheme.primaryGreen,
                  onTap: () => setState(() => _selectedSignInRole = 'Waiter'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          AppTextField(
            label: 'Email Address',
            hint: _selectedSignInRole == 'Manager'
                ? 'e.g. manager@tspay.com'
                : 'e.g. waiter@tspay.com',
            controller: _signInEmailController,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.textTertiary, size: 20),
            textInputAction: TextInputAction.next,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (!v.contains('@')) return 'Invalid email';
              return null;
            },
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Password',
            hint: '••••••••',
            controller: _signInPasswordController,
            obscureText: _obscureSignInPassword,
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.textTertiary, size: 20),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscureSignInPassword = !_obscureSignInPassword),
              icon: Icon(
                _obscureSignInPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppTheme.textTertiary,
                size: 20,
              ),
            ),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submitSignIn(),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              return null;
            },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _changeStep(_AuthStep.forgotPassword),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Forgot Password?',
                style: GoogleFonts.inter(color: AppTheme.accentGold, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 20),
          GradientButton(
            label: 'Sign In as $_selectedSignInRole',
            icon: _selectedSignInRole == 'Manager' ? Icons.store_rounded : Icons.badge_rounded,
            height: 50,
            borderRadius: 14,
            isLoading: isLoading,
            onPressed: isLoading ? null : _submitSignIn,
            gradient: _selectedSignInRole == 'Waiter'
                ? AppTheme.primaryGradient
                : AppTheme.goldGradient,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Divider(color: Colors.white.withOpacity(0.08))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'NEW USER?',
                  style: GoogleFonts.inter(fontSize: 10, color: Colors.white.withOpacity(0.3), fontWeight: FontWeight.w700, letterSpacing: 1),
                ),
              ),
              Expanded(child: Divider(color: Colors.white.withOpacity(0.08))),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _changeStep(_AuthStep.roleSelect),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.primaryGreen.withOpacity(0.35),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  'Create Account / Join',
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
    );
  }

  // ── Step 2: Role Selection ──────────────────────────────────────────────────

  Widget _buildRoleSelectStep() {
    return Column(
      key: const ValueKey('roleSelect'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => _changeStep(_AuthStep.signIn),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              'Select Your Role',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Choose how you want to join the platform',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 24),
        
        // Manager Card
        _buildRoleOptionCard(
          title: 'I am a Manager',
          description: 'Register your cafe / business, set up bank accounts, and manage your waiter team.',
          icon: Icons.store_rounded,
          color: AppTheme.accentGold,
          onTap: () => _changeStep(_AuthStep.managerForm),
        ),
        const SizedBox(height: 16),
        
        // Waiter Card
        _buildRoleOptionCard(
          title: 'I am a Waiter',
          description: 'Verify payment transfers at tables. Note: your account must be created by your manager.',
          icon: Icons.badge_rounded,
          color: AppTheme.primaryGreen,
          onTap: () => _changeStep(_AuthStep.waiterInfo),
        ),
      ],
    );
  }

  Widget _buildRoleOptionCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.5),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.3), size: 24),
          ],
        ),
      ),
    );
  }

  // ── Step 3: Manager Form ────────────────────────────────────────────────────

  Widget _buildManagerFormStep(bool isLoading) {
    return Form(
      key: _managerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _changeStep(_AuthStep.roleSelect),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'Register Café',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Submit details for super admin approval',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          
          AppTextField(
            label: 'Business / Café Name',
            hint: 'e.g. T\'s Pay Bistro',
            controller: _cafeNameController,
            prefixIcon: const Icon(Icons.storefront_rounded, color: AppTheme.textTertiary, size: 20),
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          
          AppTextField(
            label: 'Phone Number',
            hint: 'e.g. +251 911 223 344',
            controller: _managerPhoneController,
            keyboardType: TextInputType.phone,
            prefixIcon: const Icon(Icons.phone_rounded, color: AppTheme.textTertiary, size: 20),
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: 'City',
                  hint: 'e.g. Addis Ababa',
                  controller: _managerCityController,
                  prefixIcon: const Icon(Icons.location_on_outlined, color: AppTheme.textTertiary, size: 20),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Category Selector Pills
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Café Category',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((cat) {
                  final isSel = _selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSel,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCategory = cat);
                      }
                    },
                    selectedColor: AppTheme.primaryGreen.withOpacity(0.2),
                    backgroundColor: Colors.white.withOpacity(0.04),
                    labelStyle: GoogleFonts.inter(
                      color: isSel ? AppTheme.primaryGreen : Colors.white.withOpacity(0.5),
                      fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 11,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSel ? AppTheme.primaryGreen : Colors.white.withOpacity(0.08),
                        width: 1,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          AppTextField(
            label: 'Email Address',
            hint: 'manager@example.com',
            controller: _managerEmailController,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.textTertiary, size: 20),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (!v.contains('@')) return 'Invalid email';
              return null;
            },
          ),
          const SizedBox(height: 12),
          
          AppTextField(
            label: 'Password',
            hint: 'Min. 8 characters',
            controller: _managerPasswordController,
            obscureText: _obscureManagerPassword,
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.textTertiary, size: 20),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscureManagerPassword = !_obscureManagerPassword),
              icon: Icon(
                _obscureManagerPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppTheme.textTertiary,
                size: 20,
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (v.length < 8) return 'Min 8 characters';
              return null;
            },
          ),
          const SizedBox(height: 12),

          AppTextField(
            label: 'Confirm Password',
            hint: '••••••••',
            controller: _managerConfirmPasswordController,
            obscureText: _obscureManagerConfirmPassword,
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.textTertiary, size: 20),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscureManagerConfirmPassword = !_obscureManagerConfirmPassword),
              icon: Icon(
                _obscureManagerConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppTheme.textTertiary,
                size: 20,
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (v != _managerPasswordController.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 12),

          AppTextField(
            label: 'Description (Optional)',
            hint: 'Briefly describe your cafe / business...',
            controller: _managerDescController,
            maxLines: 2,
            prefixIcon: const Icon(Icons.description_outlined, color: AppTheme.textTertiary, size: 20),
          ),
          const SizedBox(height: 24),
          
          GradientButton(
            label: 'Submit Application',
            icon: Icons.send_rounded,
            isLoading: isLoading,
            onPressed: isLoading ? null : _submitManagerSignUp,
          ),
        ],
      ),
    );
  }

  // ── Step 4: Manager Pending Approval ────────────────────────────────────────

  Widget _buildManagerPendingStep() {
    return Column(
      key: const ValueKey('managerPending'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        // Pulse graphic around success icon
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppTheme.accentGold.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: AppTheme.accentGold.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                gradient: AppTheme.goldGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pending_actions_rounded, color: Colors.white, size: 26),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Application Submitted!',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Your registration is currently under review. The super admin will approve your business details.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.white.withOpacity(0.6),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Once approved, you can sign in using your registered email and password.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppTheme.accentGold.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 32),
        GradientButton(
          label: 'Back to Sign In',
          icon: Icons.login_rounded,
          onPressed: () => _changeStep(_AuthStep.signIn),
        ),
      ],
    );
  }

  // ── Step 5: Waiter Info Screen ──────────────────────────────────────────────

  Widget _buildWaiterInfoStep() {
    return Column(
      key: const ValueKey('waiterInfo'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => _changeStep(_AuthStep.roleSelect),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              'Join as Waiter',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            children: [
              const Icon(Icons.info_outline_rounded, color: AppTheme.primaryGreen, size: 40),
              const SizedBox(height: 16),
              Text(
                'Manager Setup Required',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your café manager must create your waiter account and provide you with login credentials.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.6),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please contact your manager directly to get your email and password.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.05),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          icon: const Icon(Icons.phone_android_rounded, size: 20),
          label: Text('Contact Manager', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 12),
        GradientButton(
          label: 'Back to Sign In',
          icon: Icons.login_rounded,
          onPressed: () => _changeStep(_AuthStep.signIn),
        ),
      ],
    );
  }

  // ── Step 6: Forgot Password Screen ──────────────────────────────────────────

  Widget _buildForgotPasswordStep() {
    return Column(
      key: const ValueKey('forgotPassword'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => _changeStep(_AuthStep.signIn),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              'Reset Password',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Choose your account type to recover your credentials',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 24),
        
        // Manager Reset Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.store_rounded, color: AppTheme.accentGold, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'I am a Manager',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Please contact support@tspay.com or message the super admin directly to request a password reset link.',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: Colors.white.withOpacity(0.6),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Waiter Reset Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.badge_rounded, color: AppTheme.primaryGreen, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'I am a Waiter',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Please contact your café manager. They can reset your password directly from the Team Management screen.',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: Colors.white.withOpacity(0.6),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        GradientButton(
          label: 'Back to Sign In',
          icon: Icons.login_rounded,
          onPressed: () => _changeStep(_AuthStep.signIn),
        ),
      ],
    );
  }
}

// ── Role Toggle Option ────────────────────────────────────────────────────────

class _RoleToggleOption extends StatelessWidget {
  const _RoleToggleOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: color.withOpacity(0.5), width: 1.5)
                : Border.all(color: Colors.transparent),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? color : Colors.white.withOpacity(0.35)),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected ? color : Colors.white.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Animated Background Painter ───────────────────────────────────────────────

class _AuthBgPainter extends CustomPainter {
  _AuthBgPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);

    // Top right glow
    paint.color = const Color(0xFF1F805B).withOpacity(0.22);
    final x1 = size.width * 0.82 + math.sin(progress * 2 * math.pi) * 30;
    final y1 = size.height * 0.15 + math.cos(progress * 2 * math.pi) * 20;
    canvas.drawCircle(Offset(x1, y1), 200, paint);

    // Bottom left glow
    paint.color = const Color(0xFF1F805B).withOpacity(0.12);
    final x2 = size.width * 0.15 + math.cos(progress * 2 * math.pi + 2) * 25;
    final y2 = size.height * 0.5 + math.sin(progress * 2 * math.pi + 2) * 30;
    canvas.drawCircle(Offset(x2, y2), 150, paint);

    // Gold accent
    paint.color = const Color(0xFFD4A017).withOpacity(0.08);
    final x3 = size.width * 0.5 + math.sin(progress * 2 * math.pi + 4) * 40;
    final y3 = size.height * 0.35 + math.cos(progress * 2 * math.pi + 4) * 25;
    canvas.drawCircle(Offset(x3, y3), 110, paint);
  }

  @override
  bool shouldRepaint(_AuthBgPainter old) => old.progress != progress;
}
