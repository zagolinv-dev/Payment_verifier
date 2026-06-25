import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:payment_verifier/presentation/providers/auth_provider.dart';
import 'package:payment_verifier/presentation/screens/auth/auth_screen.dart';
import 'package:payment_verifier/presentation/screens/bank_accounts/bank_accounts_screen.dart';
import 'package:payment_verifier/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:payment_verifier/presentation/screens/home/home_shell.dart';
import 'package:payment_verifier/presentation/screens/manage_users/manage_users_screen.dart';
import 'package:payment_verifier/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:payment_verifier/presentation/screens/reports/reports_screen.dart';
import 'package:payment_verifier/presentation/screens/notifications/notifications_screen.dart';
import 'package:payment_verifier/presentation/screens/settings/settings_screen.dart';
import 'package:payment_verifier/presentation/screens/splash/splash_screen.dart';
import 'package:payment_verifier/presentation/screens/transactions/transactions_screen.dart';
import 'package:payment_verifier/presentation/screens/verify_payment/verify_payment_screen.dart';

// Route Names
class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const auth = '/auth';
  static const home = '/home';
  static const dashboard = '/home/dashboard';
  static const verify = '/home/verify';
  static const transactions = '/home/transactions';
  static const bankAccounts = '/home/bank-accounts';
  static const manageUsers = '/home/manage-users';
  static const reports = '/home/reports';
  static const notifications = '/home/notifications';
  static const settings = '/home/settings';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    redirect: (context, state) async {
      final isLoading = authState.isLoading;
      if (isLoading) return null;

      final user = authState.valueOrNull;
      final isSplash = state.matchedLocation == AppRoutes.splash;
      final isOnboarding = state.matchedLocation == AppRoutes.onboarding;
      final isAuth = state.matchedLocation == AppRoutes.auth;

      if (isSplash || isOnboarding) return null;

      if (user == null && !isAuth) return AppRoutes.auth;
      if (user != null && isAuth) return AppRoutes.dashboard;

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.auth,
        builder: (context, state) => const AuthScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            parentNavigatorKey: _shellNavigatorKey,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.verify,
            parentNavigatorKey: _shellNavigatorKey,
            builder: (context, state) => const VerifyPaymentScreen(),
          ),
          GoRoute(
            path: AppRoutes.transactions,
            parentNavigatorKey: _shellNavigatorKey,
            builder: (context, state) => const TransactionsScreen(),
          ),
          GoRoute(
            path: AppRoutes.bankAccounts,
            parentNavigatorKey: _shellNavigatorKey,
            builder: (context, state) => const BankAccountsScreen(),
          ),
          GoRoute(
            path: AppRoutes.manageUsers,
            parentNavigatorKey: _shellNavigatorKey,
            builder: (context, state) => const ManageUsersScreen(),
          ),
          GoRoute(
            path: AppRoutes.reports,
            parentNavigatorKey: _shellNavigatorKey,
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            parentNavigatorKey: _shellNavigatorKey,
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            parentNavigatorKey: _shellNavigatorKey,
            builder: (context, state) => const NotificationsScreen(),
          ),
        ],
      ),
    ],
  );
});
