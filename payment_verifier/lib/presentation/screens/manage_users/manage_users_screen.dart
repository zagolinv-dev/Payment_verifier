import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:payment_verifier/core/constants/app_constants.dart';
import 'package:payment_verifier/core/theme/app_theme.dart';
import 'package:payment_verifier/domain/entities/user_profile_entity.dart';
import 'package:payment_verifier/presentation/providers/auth_provider.dart';
import 'package:payment_verifier/presentation/providers/user_provider.dart';
import 'package:payment_verifier/presentation/widgets/custom_text_field.dart';
import 'package:payment_verifier/presentation/widgets/gradient_button.dart';
import 'package:payment_verifier/presentation/widgets/status_chip.dart';

class ManageUsersScreen extends ConsumerWidget {
  const ManageUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final usersAsync = ref.watch(usersListProvider);
    final currentUser = ref.watch(currentUserProvider);

    if (!isAdmin) {
      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded,
                  size: 64, color: AppTheme.textTertiary),
              const SizedBox(height: 16),
              Text('Access Restricted',
                  style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              Text('Admin access required',
                  style: GoogleFonts.inter(
                      fontSize: 14, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manage Users',
                          style: GoogleFonts.outfit(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Role-based access control',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Invite button
                  GestureDetector(
                    onTap: () => _showInviteModal(context, ref),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppTheme.goldGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentGold.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.person_add_outlined,
                          color: AppTheme.textOnPrimary, size: 22),
                    ),
                  ),
                ],
              ),
            ),

            // User list
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.primaryGreen,
                backgroundColor: AppTheme.bgCard,
                onRefresh: () async => ref.invalidate(usersListProvider),
                child: usersAsync.when(
                  data: (users) => users.isEmpty
                      ? ListView(children: [
                          const SizedBox(height: 80),
                          Center(
                            child: Text('No users found',
                                style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    color: AppTheme.textSecondary)),
                          ),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                          itemCount: users.length,
                          itemBuilder: (ctx, i) => _UserCard(
                            user: users[i],
                            isCurrentUser: users[i].id == currentUser?.id,
                            onRoleChange: (role) async {
                              await ref
                                  .read(userManagementProvider.notifier)
                                  .updateRole(users[i].id, role);
                              ref.invalidate(usersListProvider);
                            },
                          ),
                        ),
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primaryGreen),
                  ),
                  error: (e, _) => Center(
                    child: Text('Error loading users',
                        style: GoogleFonts.inter(
                            color: AppTheme.textSecondary)),
                  ),
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
      builder: (_) => const _InviteUserModal(),
    );
  }
}

// ── User Card ─────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.isCurrentUser,
    required this.onRoleChange,
  });

  final UserProfileEntity user;
  final bool isCurrentUser;
  final void Function(String) onRoleChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrentUser
              ? AppTheme.accentGold.withOpacity(0.3)
              : AppTheme.borderSubtle,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: user.isAdmin
                  ? AppTheme.goldGradient
                  : AppTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                user.displayName.isNotEmpty
                    ? user.displayName[0].toUpperCase()
                    : '?',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textOnPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user.displayName,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGold.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('You',
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                color: AppTheme.accentGold,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textTertiary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Role badge + change
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              RoleBadge(role: user.role),
              if (!isCurrentUser) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _showRoleDialog(context),
                  child: Text(
                    'Change role',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showRoleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Text('Change Role',
            style: GoogleFonts.outfit(color: AppTheme.textPrimary)),
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
                  style: GoogleFonts.inter(color: AppTheme.textPrimary)),
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
}

// ── Invite User Modal ─────────────────────────────────────────────────────────

class _InviteUserModal extends StatefulWidget {
  const _InviteUserModal();

  @override
  State<_InviteUserModal> createState() => _InviteUserModalState();
}

class _InviteUserModalState extends State<_InviteUserModal> {
  final _emailController = TextEditingController();
  String _selectedRole = UserRole.waitress.value;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottom),
      decoration: const BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
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
                color: AppTheme.borderMedium,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Invite User',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Send an invitation email to onboard a new team member.',
            style: GoogleFonts.inter(
                fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          AppTextField(
            label: 'Email Address',
            hint: 'colleague@example.com',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(Icons.email_outlined,
                color: AppTheme.textTertiary, size: 20),
          ),
          const SizedBox(height: 16),
          // Role selector
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Assign Role',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Row(
                children: UserRole.values.map((role) {
                  final isSelected = _selectedRole == role.value;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedRole = role.value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: EdgeInsets.only(
                            right: role != UserRole.values.last ? 10 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryGreenDark
                              : AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primaryGreen
                                : AppTheme.borderSubtle,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              role == UserRole.admin
                                  ? Icons.admin_panel_settings_rounded
                                  : Icons.person_rounded,
                              color: isSelected
                                  ? AppTheme.primaryGreen
                                  : AppTheme.textTertiary,
                              size: 24,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              role.value,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? AppTheme.primaryGreen
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 28),
          GradientButton(
            label: 'Send Invitation',
            icon: Icons.send_rounded,
            isLoading: _isLoading,
            onPressed: _isLoading
                ? null
                : () {
                    // Stub — in production, call Supabase Auth admin invite API
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Invitation flow requires Supabase Admin API — configure server-side function.'),
                        backgroundColor: AppTheme.bgCardElevated,
                      ),
                    );
                    Navigator.pop(context);
                  },
          ),
        ],
      ),
    );
  }
}
