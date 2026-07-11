import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:payment_verifier/core/theme/app_theme.dart';
import 'package:payment_verifier/domain/entities/notification_entity.dart';
import 'package:payment_verifier/presentation/providers/notification_provider.dart';
import 'package:payment_verifier/presentation/providers/theme_provider.dart';
import 'package:payment_verifier/presentation/providers/auth_provider.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    final bg = isDark ? AppTheme.bgDark : AppTheme.lightBg;
    final card = isDark ? AppTheme.bgCard : AppTheme.lightCard;
    final textPrimary = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary;
    final borderColor = isDark ? AppTheme.borderSubtle : AppTheme.lightBorderSubtle;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: notificationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
          error: (_, __) => const Center(child: Text('Failed to load notifications')),
          data: (notifications) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Notifications',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (notifications.isNotEmpty)
                          GestureDetector(
                            onTap: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: card,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  title: Text('Clear all?', style: GoogleFonts.outfit(color: textPrimary)),
                                  content: Text('Delete all notifications?', style: GoogleFonts.inter(color: textSecondary)),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.inter(color: textSecondary))),
                                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Clear', style: GoogleFonts.inter(color: AppTheme.error, fontWeight: FontWeight.w600))),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                try {
                                  await ref.read(clearAllNotificationsProvider)();
                                  ref.invalidate(notificationsProvider);
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to clear notifications')),
                                    );
                                  }
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Clear all',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.error),
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        if (notifications.any((n) => !n.isRead))
                          GestureDetector(
                            onTap: () async {
                              await ref.read(markAllNotificationsReadProvider)();
                              ref.invalidate(notificationsProvider);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Mark all read',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '${notifications.length} notification${notifications.length == 1 ? '' : 's'}',
                  style: GoogleFonts.inter(fontSize: 14, color: textSecondary),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_none_rounded, size: 64, color: textSecondary.withOpacity(0.4)),
                            const SizedBox(height: 16),
                            Text(
                              'No notifications',
                              style: GoogleFonts.outfit(fontSize: 16, color: textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        itemCount: notifications.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final n = notifications[index];
                          return Dismissible(
                            key: ValueKey(n.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: AppTheme.error.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 22),
                            ),
                            confirmDismiss: (_) async {
                              return await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: card,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  title: Text('Delete?', style: GoogleFonts.outfit(color: textPrimary)),
                                  content: Text('Remove this notification?', style: GoogleFonts.inter(color: textSecondary)),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.inter(color: textSecondary))),
                                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: GoogleFonts.inter(color: AppTheme.error, fontWeight: FontWeight.w600))),
                                  ],
                                ),
                              );
                            },
                            onDismissed: (_) async {
                              try {
                                await ref.read(deleteNotificationProvider)(n.id);
                                ref.invalidate(notificationsProvider);
                              } catch (_) {}
                            },
                            child: _NotificationTile(
                              item: n,
                              isDark: isDark,
                              card: card,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              borderColor: borderColor,
                              onTap: () async {
                                if (!n.isRead) {
                                  await ref.read(markNotificationReadProvider)(n.id);
                                  ref.invalidate(notificationsProvider);
                                }
                              },
                              onResetPassword: n.title.contains('Password Reset Appeal')
                                  ? () => _showResetPasswordDialog(context, ref, n, isDark, card, textPrimary, textSecondary)
                                  : null,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showResetPasswordDialog(
    BuildContext context,
    WidgetRef ref,
    NotificationEntity notification,
    bool isDark,
    Color card,
    Color textPrimary,
    Color textSecondary,
  ) {
    final emailMatch = RegExp(r'\(([^)]+)\)').firstMatch(notification.message);
    final email = emailMatch?.group(1) ?? '';

    final nameMatch = RegExp(r'(?:Manager|Waiter)\s+([^(]+)\s+\(').firstMatch(notification.message);
    final name = nameMatch?.group(1)?.trim() ?? '';

    final passwordController = TextEditingController();
    bool isResetting = false;
    bool obscurePassword = true;
    String resetSuccessPassword = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              backgroundColor: card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Reset Password', style: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.bold)),
              content: resetSuccessPassword.isNotEmpty
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_rounded, color: AppTheme.primaryGreen, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Text('Password reset!', style: GoogleFonts.inter(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: resetSuccessPassword));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: AppTheme.primaryGreen,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                content: Text('Password copied!', style: GoogleFonts.inter(color: Colors.white)),
                              ),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    resetSuccessPassword,
                                    style: GoogleFonts.robotoMono(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.5),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryGreen.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.copy_rounded, size: 14, color: AppTheme.primaryGreen),
                                      const SizedBox(width: 4),
                                      Text('Copy', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Tap to copy and send to ${name.isNotEmpty ? name : 'user'}.', style: GoogleFonts.inter(color: textSecondary, fontSize: 11)),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Set a new password for ${name.isNotEmpty ? name : email}.', style: GoogleFonts.inter(color: textSecondary, fontSize: 13)),
                        const SizedBox(height: 16),
                        TextField(
                          controller: passwordController,
                          onChanged: (_) => setState(() {}),
                          style: GoogleFonts.inter(color: textPrimary),
                          obscureText: obscurePassword,
                          decoration: InputDecoration(
                            hintText: 'Min 8 characters',
                            hintStyle: GoogleFonts.inter(color: textSecondary.withOpacity(0.5)),
                            filled: true,
                            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppTheme.primaryGreen.withOpacity(0.5)),
                            ),
                            prefixIcon: Icon(Icons.lock_outline_rounded, color: textSecondary.withOpacity(0.5), size: 20),
                            suffixIcon: GestureDetector(
                              onTap: () => setState(() => obscurePassword = !obscurePassword),
                              child: Icon(
                                obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: textSecondary.withOpacity(0.6),
                                size: 20,
                              ),
                            ),
                            counterText: '${passwordController.text.length}/8 min',
                            counterStyle: GoogleFonts.inter(fontSize: 10, color: textSecondary),
                          ),
                        ),
                      ],
                    ),
              actions: resetSuccessPassword.isNotEmpty
                  ? [
                      TextButton(
                        onPressed: () {
                          passwordController.dispose();
                          Navigator.pop(ctx);
                        },
                        child: Text('Done', style: GoogleFonts.inter(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
                      ),
                    ]
                  : [
                      TextButton(
                        onPressed: isResetting ? null : () {
                          passwordController.dispose();
                          Navigator.pop(ctx);
                        },
                        child: Text('Cancel', style: GoogleFonts.inter(color: textSecondary)),
                      ),
                      TextButton(
                        onPressed: (isResetting || passwordController.text.length < 8)
                            ? null
                            : () async {
                                setState(() => isResetting = true);
                                try {
                                  final supabase = ref.read(supabaseClientProvider);
                                  final res = await supabase.functions.invoke(
                                    'reset-user-password',
                                    body: {'email': email, 'newPassword': passwordController.text},
                                  );

                                  if (res.status == 200) {
                                    setState(() {
                                      resetSuccessPassword = passwordController.text;
                                      isResetting = false;
                                    });
                                  } else {
                                    throw Exception(res.data?['error'] ?? 'Unknown error');
                                  }
                                } catch (e) {
                                  setState(() => isResetting = false);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: AppTheme.error,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        content: Text('Failed: $e', style: GoogleFonts.inter(color: Colors.white)),
                                      ),
                                    );
                                  }
                                }
                              },
                        child: isResetting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen))
                            : Text('Set Password', style: GoogleFonts.inter(
                                color: passwordController.text.length >= 8 ? AppTheme.primaryGreen : textSecondary,
                                fontWeight: FontWeight.bold,
                              )),
                      ),
                    ],
            );
          },
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.isDark,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.borderColor,
    required this.onTap,
    this.onResetPassword,
  });

  final NotificationEntity item;
  final bool isDark;
  final Color card, textPrimary, textSecondary, borderColor;
  final VoidCallback onTap;
  final VoidCallback? onResetPassword;

  (IconData, Color) get _typeIcon {
    return switch (item.type) {
      'alert' => (Icons.warning_amber_rounded, AppTheme.error),
      'warning' => (Icons.info_outline_rounded, AppTheme.warning),
      _ => (Icons.notifications_rounded, AppTheme.pending),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _typeIcon;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: item.isRead ? card : color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: item.isRead ? borderColor : color.withOpacity(0.2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: item.isRead ? Colors.transparent : color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.message,
                    style: GoogleFonts.inter(fontSize: 12, color: textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}',
                    style: GoogleFonts.inter(fontSize: 11, color: textSecondary.withOpacity(0.6)),
                  ),
                  if (onResetPassword != null && !item.isRead) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        onTap(); // Mark read
                        onResetPassword!();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.warning.withOpacity(0.2)),
                        ),
                        child: Text(
                          'Generate New Password',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.warning,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
