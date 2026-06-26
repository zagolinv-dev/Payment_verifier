import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:payment_verifier/core/router/app_router.dart';
import 'package:payment_verifier/core/theme/app_theme.dart';
import 'package:payment_verifier/presentation/providers/auth_provider.dart';
import 'package:payment_verifier/presentation/providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final user = ref.watch(currentUserProvider);
    final isAdmin = ref.watch(isAdminProvider);

    final bg = isDark ? AppTheme.bgDark : AppTheme.lightBg;
    final card = isDark ? AppTheme.bgCard : AppTheme.lightCard;
    final textPrimary = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final borderColor = isDark ? AppTheme.borderSubtle : AppTheme.lightBorderSubtle;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────────
              Text(
                'Manage your account preferences',
                style: GoogleFonts.inter(fontSize: 14, color: textSecondary),
              ),
              const SizedBox(height: 28),

              // ── Profile Card ───────────────────────────────────────────
              _ProfileCard(
                name: user?.displayName ?? 'User',
                email: user?.email ?? '',
                role: isAdmin ? 'Manager' : 'Waiter',
                isDark: isDark,
                card: card,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                borderColor: borderColor,
              ),
              const SizedBox(height: 24),

              // ── Appearance ────────────────────────────────────────────
              _SectionHeader(label: 'Appearance', textSecondary: textSecondary),
              const SizedBox(height: 12),
              _SettingsTile(
                icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                iconColor: isDark ? AppTheme.accentGold : const Color(0xFFF59E0B),
                title: 'Theme',
                subtitle: isDark ? 'Dark Mode' : 'Light Mode',
                card: card,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                borderColor: borderColor,
                trailing: Switch(
                  value: !isDark,
                  activeColor: AppTheme.primaryGreen,
                  inactiveTrackColor: AppTheme.bgCard,
                  onChanged: (_) => ref.read(themeProvider.notifier).toggle(),
                ),
              ),
              const SizedBox(height: 24),

              // ── Account ───────────────────────────────────────────────
              _SectionHeader(label: 'Account', textSecondary: textSecondary),
              const SizedBox(height: 12),
              _SettingsTile(
                icon: Icons.person_outline_rounded,
                iconColor: AppTheme.primaryGreen,
                title: 'Profile',
                subtitle: 'View your profile details',
                card: card,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                borderColor: borderColor,
                onTap: () => _showProfileSheet(context, user?.displayName ?? '', user?.email ?? '', isAdmin, isDark, card, textPrimary, textSecondary, borderColor),
              ),
              if (isAdmin) ...[
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.lock_outline_rounded,
                  iconColor: AppTheme.pending,
                  title: 'Change Password',
                  subtitle: 'Update your login password',
                  card: card,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  borderColor: borderColor,
                  onTap: () => _showChangePasswordDialog(context, ref),
                ),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.group_outlined,
                  iconColor: AppTheme.accentGold,
                  title: 'Manage Team',
                  subtitle: 'Add waiters and manage roles',
                  card: card,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  borderColor: borderColor,
                  onTap: () => context.go(AppRoutes.manageUsers),
                ),
              ],
              const SizedBox(height: 24),

              // ── Data & Privacy ────────────────────────────────────────
              _SectionHeader(label: 'Data & Privacy', textSecondary: textSecondary),
              const SizedBox(height: 12),
              _SettingsTile(
                icon: Icons.receipt_long_outlined,
                iconColor: AppTheme.primaryGreen,
                title: 'Transaction History',
                subtitle: 'View all your verified payments',
                card: card,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                borderColor: borderColor,
                onTap: () => context.go(AppRoutes.transactions),
              ),
              const SizedBox(height: 24),

              // ── About ─────────────────────────────────────────────────
              _SectionHeader(label: 'About', textSecondary: textSecondary),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(12)),
                          child: Center(child: Text('T', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white))),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("T's Verify", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary)),
                            Text('Version 1.0.0', style: GoogleFonts.inter(fontSize: 12, color: textSecondary)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: borderColor, height: 1),
                    const SizedBox(height: 14),
                    Text(
                      "T's Verify is an Ethiopian payment verification platform designed for cafés, restaurants, and service businesses.",
                      style: GoogleFonts.inter(fontSize: 13, color: textSecondary, height: 1.5),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Waiters scan or enter reference codes from CBE, Telebirr, CBE Birr, and Awash Bank transfers. Every verified payment is recorded instantly with amount, tip, and waiter info — giving managers full visibility into daily revenue.',
                      style: GoogleFonts.inter(fontSize: 13, color: textSecondary, height: 1.5),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: [
                        _AboutChip(label: 'CBE', color: AppTheme.primaryGreen),
                        _AboutChip(label: 'Telebirr', color: AppTheme.accentGold),
                        _AboutChip(label: 'CBE Birr', color: AppTheme.pending),
                        _AboutChip(label: 'Awash Bank', color: AppTheme.success),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Sign Out ──────────────────────────────────────────────
              _SignOutButton(
                onTap: () async {
                  final confirmed = await _showLogoutDialog(context, isDark, card, textPrimary, textSecondary);
                  if (confirmed != true) return;
                  if (!context.mounted) return;
                  await ref.read(authProvider.notifier).signOut();
                  if (context.mounted) context.go(AppRoutes.auth);
                },
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  "T's Verify © 2024",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? AppTheme.textTertiary : AppTheme.lightTextTertiary,
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

// ── Helpers ───────────────────────────────────────────────────────────────────

Future<bool?> _showLogoutDialog(BuildContext context, bool isDark, Color card, Color textPrimary, Color textSecondary) {
  return showDialog<bool>(
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
        ButtonBar(
          buttonMinWidth: 110,
          buttonPadding: EdgeInsets.zero,
          alignment: MainAxisAlignment.end,
          children: [
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text('Sign Out', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ],
    ),
  );
}

void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
  final isDark = ref.read(themeProvider) == ThemeMode.dark;
  final card = isDark ? AppTheme.bgCard : AppTheme.lightCard;
  final textPrimary = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
  final textSecondary = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
  final textTertiary = isDark ? AppTheme.textTertiary : AppTheme.lightTextTertiary;

  final currentCtrl = TextEditingController();
  final newCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        bool obscureCurrent = true;
        bool obscureNew = true;
        bool obscureConfirm = true;

        return AlertDialog(
          backgroundColor: card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Change Password', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentCtrl,
                  obscureText: obscureCurrent,
                  style: GoogleFonts.inter(color: textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 13),
                    suffixIcon: IconButton(
                      icon: Icon(obscureCurrent ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
                      color: textSecondary,
                      onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newCtrl,
                  obscureText: obscureNew,
                  style: GoogleFonts.inter(color: textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 13),
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
                      color: textSecondary,
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v.length < 8) return 'Min 8 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmCtrl,
                  obscureText: obscureConfirm,
                  style: GoogleFonts.inter(color: textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 13),
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
                      color: textSecondary,
                      onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v != newCtrl.text) return 'Passwords do not match';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            ButtonBar(
              buttonMinWidth: 110,
              buttonPadding: EdgeInsets.zero,
              alignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: GoogleFonts.inter(color: textTertiary)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Password updated successfully', style: GoogleFonts.inter(color: Colors.white)),
                        backgroundColor: AppTheme.primaryGreen,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text('Update', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

void _showProfileSheet(
  BuildContext context,
  String name,
  String email,
  bool isAdmin,
  bool isDark,
  Color card,
  Color textPrimary,
  Color textSecondary,
  Color borderColor,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Container(
      decoration: BoxDecoration(color: card, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? AppTheme.borderMedium : AppTheme.lightBorderMedium, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          Container(
            width: 72, height: 72,
            decoration: const BoxDecoration(gradient: AppTheme.primaryGradient, shape: BoxShape.circle),
            child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', style: GoogleFonts.outfit(fontSize: 30, fontWeight: FontWeight.w700, color: Colors.white))),
          ),
          const SizedBox(height: 16),
          Text(name, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary)),
          const SizedBox(height: 4),
          Text(email, style: GoogleFonts.inter(fontSize: 13, color: textSecondary)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(color: AppTheme.primaryGreen.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Text(isAdmin ? 'Manager' : 'Waiter', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen)),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: isDark ? AppTheme.bgDark : AppTheme.lightBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
            child: Column(
              children: [
                _ProfileInfoRow(label: 'Full Name', value: name, textPrimary: textPrimary, textSecondary: textSecondary),
                Divider(color: borderColor, height: 20),
                _ProfileInfoRow(label: 'Email', value: email, textPrimary: textPrimary, textSecondary: textSecondary),
                Divider(color: borderColor, height: 20),
                _ProfileInfoRow(label: 'Role', value: isAdmin ? 'Manager / Admin' : 'Waiter / Staff', textPrimary: textPrimary, textSecondary: textSecondary),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: textPrimary,
                side: BorderSide(color: borderColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('Close', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
      ), // Padding
    ),
  );
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({required this.label, required this.value, required this.textPrimary, required this.textSecondary});
  final String label, value;
  final Color textPrimary, textSecondary;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: textSecondary)),
        Flexible(child: Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary), textAlign: TextAlign.end, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.textSecondary});
  final String label;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: textSecondary,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.email,
    required this.role,
    required this.isDark,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.borderColor,
  });

  final String name, email, role;
  final bool isDark;
  final Color card, textPrimary, textSecondary, borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: GoogleFonts.inter(fontSize: 13, color: textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              role,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.borderColor,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor, card, textPrimary, textSecondary, borderColor;
  final String title, subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: textSecondary)),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _AboutChip extends StatelessWidget {
  const _AboutChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.error.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
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
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
