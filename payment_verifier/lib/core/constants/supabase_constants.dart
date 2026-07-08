/// T's Verify — Supabase Configuration
///
/// Loads credentials from .env file at the project root.
/// Copy .env.example to .env and fill in your Supabase project credentials.
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConstants {
  SupabaseConstants._();

  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? 'https://xyzabcdef.supabase.co';

  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? 'your-supabase-anon-key-here';

  /// Service role key — only used for admin operations (create waiter).
  /// Never exposed to end users; loaded from .env which is gitignored.
  static String get supabaseServiceRoleKey =>
      dotenv.env['SUPABASE_SERVICE_ROLE_KEY'] ?? '';
}
