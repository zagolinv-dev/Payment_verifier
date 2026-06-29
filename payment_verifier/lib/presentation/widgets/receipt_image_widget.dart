import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:payment_verifier/core/theme/app_theme.dart';
import 'package:payment_verifier/presentation/providers/auth_provider.dart';

/// Displays a receipt image from a URL or local file path.
/// If the URL fails (expired / private bucket), it extracts the Supabase
/// storage path from the URL fragment and requests a fresh signed URL.
class ReceiptImageWidget extends ConsumerStatefulWidget {
  const ReceiptImageWidget({
    super.key,
    required this.imagePath,
    this.height = 400,
    this.fit = BoxFit.contain,
  });

  final String imagePath;
  final double height;
  final BoxFit fit;

  @override
  ConsumerState<ReceiptImageWidget> createState() => _ReceiptImageWidgetState();
}

class _ReceiptImageWidgetState extends ConsumerState<ReceiptImageWidget> {
  String? _resolvedUrl;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _resolve(widget.imagePath);
  }

  @override
  void didUpdateWidget(ReceiptImageWidget old) {
    super.didUpdateWidget(old);
    if (old.imagePath != widget.imagePath) {
      _resolve(widget.imagePath);
    }
  }

  Future<void> _resolve(String path) async {
    if (!mounted) return;
    setState(() { _loading = true; _failed = false; _resolvedUrl = null; });

    // Local file — use directly
    if (!path.startsWith('http')) {
      final exists = await File(path).exists();
      if (mounted) setState(() { _resolvedUrl = exists ? path : null; _failed = !exists; _loading = false; });
      return;
    }

    // Remote URL — use as-is first; the errorBuilder will trigger a retry
    if (mounted) setState(() { _resolvedUrl = _stripFragment(path); _loading = false; });
  }

  /// On image load error, try to get a fresh signed URL from Supabase Storage.
  Future<void> _retryWithSignedUrl() async {
    if (_failed || !mounted) return;
    final storagePath = _extractStoragePath(widget.imagePath);
    if (storagePath == null) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    try {
      final client = ref.read(supabaseClientProvider);
      final signed = await client.storage
          .from('receipts')
          .createSignedUrl(storagePath, 60 * 60 * 24 * 365);
      if (mounted) setState(() { _resolvedUrl = signed; _failed = false; });
    } catch (e) {
      debugPrint('[ReceiptImageWidget] signed URL failed: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  // Strip the #path=... fragment we appended at upload time
  String _stripFragment(String url) {
    final idx = url.indexOf('#');
    return idx >= 0 ? url.substring(0, idx) : url;
  }

  // Extract storagePath from the fragment "#path=userId/receipt_123.jpg"
  String? _extractStoragePath(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final fragment = uri.fragment; // "path=userId/receipt_123.jpg"
    if (fragment.startsWith('path=')) return fragment.substring(5);
    // Fallback: parse from the URL path itself
    // e.g. ".../storage/v1/object/public/receipts/userId/receipt_123.jpg"
    final match = RegExp(r'/receipts/(.+?)(?:\?|$)').firstMatch(url);
    return match?.group(1);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        height: widget.height,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen)),
      );
    }

    if (_failed || _resolvedUrl == null) {
      return _broken();
    }

    final path = _resolvedUrl!;
    final isUrl = path.startsWith('http');

    if (isUrl) {
      return Image.network(
        path,
        height: widget.height,
        width: double.infinity,
        fit: widget.fit,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            height: widget.height,
            child: Center(child: CircularProgressIndicator(
              strokeWidth: 2,
              value: progress.expectedTotalBytes != null
                  ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                  : null,
              color: AppTheme.primaryGreen,
            )),
          );
        },
        errorBuilder: (_, error, __) {
          debugPrint('[ReceiptImageWidget] network error: $error — retrying with signed URL');
          // Trigger signed URL retry asynchronously
          WidgetsBinding.instance.addPostFrameCallback((_) => _retryWithSignedUrl());
          return _broken(retrying: true);
        },
      );
    }

    return Image.file(
      File(path),
      height: widget.height,
      width: double.infinity,
      fit: widget.fit,
      errorBuilder: (_, __, ___) => _broken(),
    );
  }

  Widget _broken({bool retrying = false}) {
    return Container(
      height: widget.height.clamp(0, 200),
      color: AppTheme.bgCard,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (retrying)
              const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen),
              )
            else
              const Icon(Icons.broken_image_rounded, color: AppTheme.textTertiary, size: 40),
            const SizedBox(height: 8),
            Text(
              retrying ? 'Refreshing image...' : 'Receipt image unavailable',
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
