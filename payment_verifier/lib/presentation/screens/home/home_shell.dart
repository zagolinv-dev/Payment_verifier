import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:payment_verifier/core/router/app_router.dart';
import 'package:payment_verifier/core/theme/app_theme.dart';
import 'package:payment_verifier/presentation/providers/auth_provider.dart';
import 'package:payment_verifier/presentation/providers/theme_provider.dart';
import 'package:payment_verifier/presentation/providers/notification_provider.dart';
import 'package:payment_verifier/presentation/widgets/blur_overlay.dart';
import 'package:payment_verifier/presentation/widgets/connectivity_banner.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final user = ref.watch(currentUserProvider);
    final location = GoRouterState.of(context).matchedLocation;

    final bg = isDark ? AppTheme.bgDark : AppTheme.lightBg;
    final card = isDark ? AppTheme.bgCard : AppTheme.lightCard;
    final borderColor = isDark ? AppTheme.borderSubtle : AppTheme.lightBorderSubtle;
    final textPrimary = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;

    final routes = [
      AppRoutes.dashboard,
      AppRoutes.verify,
      AppRoutes.transactions,
      if (isAdmin) AppRoutes.bankAccounts,
      if (isAdmin) AppRoutes.manageUsers,
      AppRoutes.settings,
    ];

    final navItems = [
      _NavData(icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view_rounded, label: 'Home'),
      _NavData(icon: Icons.qr_code_scanner_outlined, activeIcon: Icons.qr_code_scanner, label: 'Verify'),
      _NavData(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded, label: 'History'),
      if (isAdmin) _NavData(icon: Icons.account_balance_outlined, activeIcon: Icons.account_balance_rounded, label: 'Accounts'),
      if (isAdmin) _NavData(icon: Icons.group_outlined, activeIcon: Icons.group_rounded, label: 'Team'),
      _NavData(icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded, label: 'Settings'),
    ];

    // Sync index from current route
    final idx = routes.indexOf(location);
    if (idx >= 0 && idx != _currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => setState(() => _currentIndex = idx));
    }

    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      backgroundColor: bg,
      drawer: _AppDrawer(
        isDark: isDark,
        isAdmin: isAdmin,
        user: user,
        bg: bg,
        card: card,
        borderColor: borderColor,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        onNavigate: (route) {
          _scaffoldKey.currentState?.closeDrawer();
          context.go(route);
        },
        onSignOut: () async {
          _scaffoldKey.currentState?.closeDrawer();
          final confirmed = await _showLogoutDialog(context, isDark);
          if (confirmed != true) return;
          if (!context.mounted) return;
          await ref.read(authProvider.notifier).signOut();
          if (context.mounted) context.go(AppRoutes.auth);
        },
        onThemeToggle: () => ref.read(themeProvider.notifier).toggle(),
      ),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: AppBar(
          backgroundColor: isDark ? AppTheme.bgDark : AppTheme.lightBg,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: _MenuButton(
              isDark: isDark,
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          ),
          leadingWidth: 56,
          title: Text(
            _pageTitle(location),
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _NotificationBell(
                isDark: isDark,
                unreadCount: ref.watch(unreadCountProvider).valueOrNull ?? 0,
                onTap: () => context.go(AppRoutes.notifications),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          const ConnectivityBanner(),
          Expanded(child: widget.child),
        ],
      ),
      bottomNavigationBar: _OvalNavBar(
        items: navItems,
        currentIndex: _currentIndex,
        isDark: isDark,
        onTap: (i) {
          setState(() => _currentIndex = i);
          context.go(routes[i]);
        },
      ),
    );
  }

  String _pageTitle(String location) {
    switch (location) {
      case AppRoutes.dashboard: return '';  // dashboard has its own header
      case AppRoutes.verify: return 'Verify Payment';
      case AppRoutes.transactions: return 'Transactions';
      case AppRoutes.bankAccounts: return 'Bank Accounts';
      case AppRoutes.manageUsers: return 'Manage Team';
      case AppRoutes.reports: return 'Reports';
      case AppRoutes.settings: return 'Settings';
      case AppRoutes.about: return 'About';
      default: return '';
    }
  }

  Future<bool?> _showLogoutDialog(BuildContext context, bool isDark) {
    final card = isDark ? AppTheme.bgCard : AppTheme.lightCard;
    final textPrimary = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    return showBlurredDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: AppTheme.error, size: 32),
            ),
            const SizedBox(height: 20),
            Text('Sign Out?', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary)),
            const SizedBox(height: 8),
            Text('Are you sure you want to sign out?', style: GoogleFonts.inter(fontSize: 14, color: textSecondary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: textSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('Sign Out', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Menu Button ───────────────────────────────────────────────────────────────

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.isDark, required this.onTap});
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.bgCard.withOpacity(0.9) : AppTheme.lightCard.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppTheme.borderSubtle : AppTheme.lightBorderSubtle,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.menu_rounded,
          size: 20,
          color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
        ),
      ),
    );
  }
}

// ── App Drawer ────────────────────────────────────────────────────────────────

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({
    required this.isDark,
    required this.isAdmin,
    required this.user,
    required this.bg,
    required this.card,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.onNavigate,
    required this.onSignOut,
    required this.onThemeToggle,
  });

  final bool isDark;
  final bool isAdmin;
  final dynamic user;
  final Color bg, card, borderColor, textPrimary, textSecondary;
  final void Function(String) onNavigate;
  final VoidCallback onSignOut;
  final VoidCallback onThemeToggle;

  @override
  Widget build(BuildContext context) {
    final name = user?.displayName ?? 'User';
    final email = user?.email ?? '';
    final role = isAdmin ? 'Manager' : 'Waiter';

    return Drawer(
      backgroundColor: bg,
      width: 280,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── User Header ──────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.75),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            role,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Quick Tools ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                'QUICK TOOLS',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            _DrawerItem(
              icon: Icons.grid_view_rounded,
              label: 'Dashboard',
              color: AppTheme.primaryGreen,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              card: card,
              borderColor: borderColor,
              onTap: () => onNavigate(AppRoutes.dashboard),
            ),
            _DrawerItem(
              icon: Icons.qr_code_scanner,
              label: 'Verify Payment',
              color: AppTheme.primaryGreen,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              card: card,
              borderColor: borderColor,
              onTap: () => onNavigate(AppRoutes.verify),
            ),
            _DrawerItem(
              icon: Icons.receipt_long_rounded,
              label: 'Transactions',
              color: AppTheme.pending,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              card: card,
              borderColor: borderColor,
              onTap: () => onNavigate(AppRoutes.transactions),
            ),
            if (isAdmin) ...[
              _DrawerItem(
                icon: Icons.bar_chart_rounded,
                label: 'Reports',
                color: AppTheme.accentGold,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                card: card,
                borderColor: borderColor,
                onTap: () => onNavigate(AppRoutes.reports),
              ),
              _DrawerItem(
                icon: Icons.account_balance_rounded,
                label: 'Bank Accounts',
                color: AppTheme.accentGold,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                card: card,
                borderColor: borderColor,
                onTap: () => onNavigate(AppRoutes.bankAccounts),
              ),
              _DrawerItem(
                icon: Icons.group_rounded,
                label: 'Manage Team',
                color: AppTheme.accentGold,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                card: card,
                borderColor: borderColor,
                onTap: () => onNavigate(AppRoutes.manageUsers),
              ),
            ],
            _DrawerItem(
              icon: Icons.settings_rounded,
              label: 'Settings',
              color: textSecondary,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              card: card,
              borderColor: borderColor,
              onTap: () => onNavigate(AppRoutes.settings),
            ),

            // ── Theme Toggle ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: GestureDetector(
                onTap: onThemeToggle,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        color: AppTheme.accentGold,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Spacer(),

            // ── Sign Out ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GestureDetector(
                onTap: onSignOut,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout_rounded, color: AppTheme.error, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Sign Out',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.textPrimary,
    required this.textSecondary,
    required this.card,
    required this.borderColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color, textPrimary, textSecondary, card, borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 3, 16, 3),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: textPrimary),
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, color: textSecondary, size: 16),
            ],
          ),
        ),
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
    required this.isDark,
  });

  final List<_NavData> items;
  final int currentIndex;
  final void Function(int) onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final navBg = isDark ? AppTheme.bgCard.withOpacity(0.95) : Colors.white.withOpacity(0.95);
    final borderColor = isDark ? AppTheme.borderSubtle : AppTheme.lightBorderSubtle;
    final shadowColor = isDark ? Colors.black.withOpacity(0.5) : Colors.black.withOpacity(0.12);
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, (bottomPad > 0 ? bottomPad : 12) + 8),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: navBg,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(color: shadowColor, blurRadius: 30, offset: const Offset(0, 10)),
            if (!isDark) BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.08), blurRadius: 20, spreadRadius: -4, offset: const Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              items.length,
              (i) => _NavPill(
                data: items[i],
                isSelected: currentIndex == i,
                isDark: isDark,
                onTap: () => onTap(i),
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
  const _NavPill({required this.data, required this.isSelected, required this.isDark, required this.onTap});

  final _NavData data;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inactiveColor = isDark ? Colors.white.withOpacity(0.35) : AppTheme.lightTextTertiary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen.withOpacity(0.12) : Colors.transparent,
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
                color: isSelected ? AppTheme.primaryGreen : inactiveColor,
                size: 21,
              ),
              if (isSelected) ...[
                const SizedBox(width: 5),
                Text(
                  data.label,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({
    required this.isDark,
    required this.unreadCount,
    required this.onTap,
  });

  final bool isDark;
  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.bgCard.withOpacity(0.9) : AppTheme.lightCard.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppTheme.borderSubtle : AppTheme.lightBorderSubtle,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Icon(
                Icons.notifications_outlined,
                size: 20,
                color: isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppTheme.error,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavData {
  const _NavData({required this.icon, required this.activeIcon, required this.label});
  final IconData icon;
  final IconData activeIcon;
  final String label;
}
