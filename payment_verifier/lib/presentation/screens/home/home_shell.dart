import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:payment_verifier/core/router/app_router.dart';
import 'package:payment_verifier/core/theme/app_theme.dart';
import 'package:payment_verifier/presentation/providers/auth_provider.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final location = GoRouterState.of(context).matchedLocation;

    final routes = [
      AppRoutes.dashboard,
      AppRoutes.verify,
      AppRoutes.transactions,
      if (isAdmin) AppRoutes.bankAccounts,
      if (isAdmin) AppRoutes.manageUsers,
    ];

    final navItems = [
      _NavData(
          icon: Icons.grid_view_outlined,
          activeIcon: Icons.grid_view_rounded,
          label: 'Home'),
      _NavData(
          icon: Icons.verified_outlined,
          activeIcon: Icons.verified_rounded,
          label: 'Verify',
          isCta: true),
      _NavData(
          icon: Icons.receipt_long_outlined,
          activeIcon: Icons.receipt_long_rounded,
          label: 'History'),
      if (isAdmin)
        _NavData(
            icon: Icons.account_balance_outlined,
            activeIcon: Icons.account_balance_rounded,
            label: 'Accounts'),
      if (isAdmin)
        _NavData(
            icon: Icons.group_outlined,
            activeIcon: Icons.group_rounded,
            label: 'Team'),
    ];

    // Sync index from current route
    final idx = routes.indexOf(location);
    if (idx >= 0 && idx != _currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => setState(() => _currentIndex = idx),
      );
    }

    return Scaffold(
      extendBody: true,
      body: widget.child,
      bottomNavigationBar: _OvalNavBar(
        items: navItems,
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
          context.go(routes[i]);
        },
      ),
    );
  }
}

// ── Oval Navigation Bar ────────────────────────────────────────────────────────

class _OvalNavBar extends StatelessWidget {
  const _OvalNavBar({
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<_NavData> items;
  final int currentIndex;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          // Deep glass-dark background
          color: const Color(0xFF0E1A12).withOpacity(0.97),
          // Pill / Oval shape
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: AppTheme.primaryGreen.withOpacity(0.08),
              blurRadius: 20,
              spreadRadius: -4,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                items.length,
                (i) => _NavPill(
                  data: items[i],
                  isSelected: currentIndex == i,
                  onTap: () => onTap(i),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Individual Nav Pill ────────────────────────────────────────────────────────

class _NavPill extends StatelessWidget {
  const _NavPill({
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  final _NavData data;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (data.isCta) {
      // Central CTA button — raised glowing circle
      return GestureDetector(
        onTap: onTap,
        child: Transform.translate(
          offset: const Offset(0, -12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryGreen.withOpacity(
                    isSelected ? 0.5 : 0.3,
                  ),
                  blurRadius: isSelected ? 24 : 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              isSelected ? data.activeIcon : data.icon,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      );
    }

    // Standard nav item
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryGreen.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? data.activeIcon : data.icon,
                color: isSelected
                    ? AppTheme.primaryGreen
                    : Colors.white.withOpacity(0.35),
                size: 22,
              ),
              if (isSelected) ...[
                const SizedBox(width: 6),
                Text(
                  data.label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

class _NavData {
  const _NavData({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.isCta = false,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isCta;
}
