import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:payment_verifier/core/constants/supabase_constants.dart';
import 'package:payment_verifier/core/router/app_router.dart';
import 'package:payment_verifier/core/theme/app_theme.dart';
import 'package:payment_verifier/presentation/providers/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file
  await dotenv.load(fileName: '.env');

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Default dark system UI until theme provider kicks in
  SystemChrome.setSystemUIOverlayStyle(AppTheme.darkOverlay);

  // Initialize Supabase
  try {
    await Supabase.initialize(
      url: SupabaseConstants.supabaseUrl,
      anonKey: SupabaseConstants.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase failed to initialize: $e');
  }

  runApp(
    const ProviderScope(
      child: TsPayApp(),
    ),
  );
}

class TsPayApp extends ConsumerWidget {
  const TsPayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: "T's Verify",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
