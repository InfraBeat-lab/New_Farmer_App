import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poultryos_farmer_app/core/services/local_storage_service.dart';
import 'package:poultryos_farmer_app/core/theme/app_theme.dart';
import 'package:poultryos_farmer_app/features/home/presentation/pages/login_screen.dart';
import 'package:poultryos_farmer_app/features/home/presentation/pages/splash_screen.dart';
import 'package:poultryos_farmer_app/features/home/presentation/pages/verify_otp_screen.dart';
import 'package:poultryos_farmer_app/features/home/presentation/pages/profile_screen.dart';
import 'package:poultryos_farmer_app/features/home/presentation/pages/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LocalStorageService.init();
  await dotenv.load(fileName: '.env');

  runApp(const ProviderScope(child: PoultryOSFarmerApp()));
}

class PoultryOSFarmerApp extends StatelessWidget {
  const PoultryOSFarmerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PoultryOS Farmer App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      routerConfig: _router,
    );
  }
}

final _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => SplashScreen(key: UniqueKey()),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/verify-otp',
      builder: (context, state) {
        final mobileNumber = state.extra as String? ?? '';
        return VerifyOtpScreen(mobileNumber: mobileNumber);
      },
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const DashboardScreen(),
    ),
  ],
);
