import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:payment_verifier/core/constants/app_constants.dart';
import 'package:payment_verifier/core/theme/app_theme.dart';
import 'package:payment_verifier/domain/entities/user_profile_entity.dart';
import 'package:payment_verifier/presentation/providers/auth_provider.dart';
import 'package:payment_verifier/presentation/providers/theme_provider.dart';
import 'package:payment_verifier/presentation/providers/user_provider.dart';
import 'package:payment_verifier/presentation/widgets/custom_text_field.dart';
import 'package:payment_verifier/presentation/widgets/gradient_button.dart';
import 'package:payment_verifier/presentation/widgets/status_chip.dart';
import 'package:payment_verifier/presentation/screens/manage_users/waiter_detail_screen.dart';

class ManageUsersScreen extends ConsumerWidget {
  const ManageUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final usersAsync = ref.watch(usersListProvider);
    final currentUser = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    final bg = isDark ? AppTheme.bgDark : AppTheme.lightBg;
    final card = isDark ? AppTheme.bgCard : AppTheme.lightCard;
    final borderColor = isDark ? AppTheme.borderSubtle : AppTheme.lightBorderSubtle;
    final textPrimary = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;

    if (!isAdmin) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 64, color: isDark ? AppTheme.textTertiary : AppTheme.lightTextTertiary),
              const SizedBox(height: 16),
              Text('Access Restricted', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary)),
              const SizedBox(height: 8),
              Text('Admin access required', style: GoogleFonts.inter(fontSize: 14, color: textSecondary)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Manage Users', style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w700, color: textPrimary)),
                        const SizedBox(height: 4),
                        Text('Role-based access control', style: GoogleFonts.inter(fontSize: 13, color: textSecondary)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showInviteModal(context, ref),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        gradient: AppTheme.goldGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: AppTheme.accentGold.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: const Icon(Icons.person_add_outlined, color: AppTheme.textOnPrimary, size: 22),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: RefreshIndicator(
                color: AppTheme.primaryGreen,
                backgroundColor: card,
                onRefresh: () async => ref.invalidate(usersListProvider),
                child: usersAsync.when(
                  data: (users) => users.isEmpty
                      ? ListView(children: [
                          const SizedBox(height: 80),
                          Center(child: Text('No users found', style: GoogleFonts.outfit(fontSize: 16, color: textSecondary))),
                        ])
                      : ListView.builder(
                          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).padding.bottom + 100),
                          itemCount: users.length,
                          itemBuilder: (ctx, i) {
                            final u = users[i];
                            final isWaiter = !u.isAdmin;
                            return _UserCard(
                              user: u,
                              isCurrentUser: u.id == currentUser?.id,
                              isDark: isDark,
                              card: card,
                              borderColor: borderColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              textTertiary: isDark ? AppTheme.textTertiary : AppTheme.lightTextTertiary,
                              onTap: isWaiter ? () => Navigator.push(
                                ctx,
                                MaterialPageRoute(
                                  builder: (_) => WaiterDetailScreen(
                                    waiterId: u.id,
                                    waiterName: u.displayName,
                                    waiterEmail: u.email,
                                  ),
                                ),
                              ) : null,
                              onRoleChange: (role) async {
                                await ref.read(userManagementProvider.notifier).updateRole(u.id, role);
                                ref.invalidate(usersListProvider);
                              },
                            );
                          },
                        ),
                  loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
                  error: (e, _) => Center(child: Text('Error loading users', style: GoogleFonts.inter(color: textSecondary))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddWaiterModal(),
    );
  }
}

// ── User Card ─────────────────────────────────────────────────────────────────

class _UserCard extends ConsumerWidget {
  const _UserCard({
    required this.user,
    required this.isCurrentUser,
    required this.onRoleChange,
    required this.isDark,
    required this.card,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    this.onTap,
  });

  final UserProfileEntity user;
  final bool isCurrentUser, isDark;
  final void Function(String) onRoleChange;
  final Color card, borderColor, textPrimary, textSecondary, textTertiary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: isCurrentUser ? null : () => _showActionsDialog(context, ref),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isCurrentUser ? AppTheme.accentGold.withOpacity(0.3) : borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(gradient: user.isAdmin ? AppTheme.goldGradient : AppTheme.primaryGradient, shape: BoxShape.circle),
              child: Center(child: Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textOnPrimary))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(user.displayName, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary)),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppTheme.accentGold.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                          child: Text('You', style: GoogleFonts.inter(fontSize: 10, color: AppTheme.accentGold, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(user.email, style: GoogleFonts.inter(fontSize: 12, color: textTertiary), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                RoleBadge(role: user.role),
                if (!user.isAdmin && onTap != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('View scans', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.accentGold, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppTheme.accentGold),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRoleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: card,
        title: Text('Change Role',
            style: GoogleFonts.outfit(color: textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: UserRole.values.map((role) {
            return ListTile(
              leading: Icon(
                role == UserRole.admin
                    ? Icons.admin_panel_settings_outlined
                    : Icons.person_outline_rounded,
                color: role == UserRole.admin
                    ? AppTheme.accentGold
                    : AppTheme.primaryGreen,
              ),
              title: Text(role.value,
                  style: GoogleFonts.inter(color: textPrimary)),
              selected: user.role == role,
              selectedTileColor: AppTheme.primaryGreen.withOpacity(0.1),
              onTap: () {
                Navigator.pop(context);
                onRoleChange(role.value);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showActionsDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: card,
        title: Text(
          'Manage ${user.displayName}',
          style: GoogleFonts.outfit(color: textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.lock_reset_rounded, color: AppTheme.accentGold),
              title: Text('Reset Password', style: GoogleFonts.inter(color: textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _showResetPasswordDialog(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
              title: Text('Delete User', style: GoogleFonts.inter(color: textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteConfirmationDialog(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showResetPasswordDialog(BuildContext context, WidgetRef ref) {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: card,
        title: Text(
          'Reset Password',
          style: GoogleFonts.outfit(color: textPrimary),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Set a new password for ${user.displayName}.',
                style: GoogleFonts.inter(color: textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'New Password',
                hint: '••••••••',
                controller: passwordController,
                obscureText: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 8) return 'Min 8 characters';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: textTertiary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final success = await ref
                  .read(userManagementProvider.notifier)
                  .resetPassword(user.id, passwordController.text);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Password reset successfully for ${user.displayName}'
                          : 'Failed to reset password',
                    ),
                    backgroundColor: success ? AppTheme.primaryGreen : AppTheme.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: Text('Reset', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: card,
        title: Text(
          'Delete User',
          style: GoogleFonts.outfit(color: textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete ${user.displayName}? This action cannot be undone.',
          style: GoogleFonts.inter(color: textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: textTertiary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await ref
                  .read(userManagementProvider.notifier)
                  .deleteUser(user.id);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ref.invalidate(usersListProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? '${user.displayName} deleted successfully'
                          : 'Failed to delete user',
                    ),
                    backgroundColor: success ? AppTheme.primaryGreen : AppTheme.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Add Waiter Modal ──────────────────────────────────────────────────────────

class _AddWaiterModal extends ConsumerStatefulWidget {
  const _AddWaiterModal();

  @override
  ConsumerState<_AddWaiterModal> createState() => _AddWaiterModalState();
}

class _AddWaiterModalState extends ConsumerState<_AddWaiterModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final errorMsg = await ref.read(userManagementProvider.notifier).addWaiter(
          fullName: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    setState(() => _isLoading = false);

    if (mounted) {
      if (errorMsg == null) {
        ref.invalidate(usersListProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_nameController.text.trim()} added to team!'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg, style: GoogleFonts.inter(color: Colors.white)),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final bg = isDark ? AppTheme.bgSurface : AppTheme.lightSurface;
    final textPrimary = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final textTertiary = isDark ? AppTheme.textTertiary : AppTheme.lightTextTertiary;
    final borderMedium = isDark ? AppTheme.borderMedium : AppTheme.lightBorderMedium;

    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottom + MediaQuery.of(context).padding.bottom),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: borderMedium,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Add Waiter',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Create login credentials for a new waiter.',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: textSecondary),
                ),
                const SizedBox(height: 24),
                AppTextField(
                  label: 'Full Name',
                  hint: 'e.g. Tigist Alemu',
                  controller: _nameController,
                  prefixIcon: Icon(Icons.person_outline_rounded,
                      color: textTertiary, size: 20),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Email Address',
                  hint: 'waiter@tspay.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icon(Icons.email_outlined,
                      color: textTertiary, size: 20),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (!v.contains('@')) return 'Invalid email';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Temporary Password',
                  hint: '••••••••',
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  prefixIcon: Icon(Icons.lock_outline_rounded,
                      color: textTertiary, size: 20),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: textTertiary,
                      size: 20,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v.length < 8) return 'Min 8 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Confirm Password',
                  hint: '••••••••',
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  prefixIcon: Icon(Icons.lock_outline_rounded,
                      color: textTertiary, size: 20),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: textTertiary,
                      size: 20,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v != _passwordController.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                GradientButton(
                  label: 'Add Waiter',
                  icon: Icons.person_add_outlined,
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
