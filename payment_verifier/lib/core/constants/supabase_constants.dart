/// T's Verify — Supabase Configuration
///
/// Loads credentials from .env file at the project root.
/// Copy .env.example to .env and fill in your Supabase project credentials.
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConstants {
  SupabaseConstants._();

  /// Your Supabase project URL
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? 'https://xyzabcdef.supabase.co';

  /// Your Supabase anon (public) key
  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? 'your-supabase-anon-key-here';
}
