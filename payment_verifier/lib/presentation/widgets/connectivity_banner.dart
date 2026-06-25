import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:payment_verifier/core/theme/app_theme.dart';
import 'package:payment_verifier/presentation/providers/connectivity_provider.dart';

class ConnectivityBanner extends ConsumerWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conn = ref.watch(connectivityProvider);

    if (conn.quality == ConnectionQuality.good) return const SizedBox.shrink();

    final isOffline = conn.quality == ConnectionQuality.none;
    final bg = isOffline
        ? AppTheme.error
        : AppTheme.accentGold;
    final icon = isOffline
        ? Icons.wifi_off_rounded
        : Icons.speed_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        boxShadow: [
          BoxShadow(
            color: bg.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              conn.message,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          if (!isOffline)
            SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
        ],
      ),
    );
  }
}
