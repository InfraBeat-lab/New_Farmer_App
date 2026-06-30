import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poultryos_farmer_app/core/services/health_check_service.dart';
import 'package:poultryos_farmer_app/features/home/presentation/pages/server_down_screen.dart';
import 'package:poultryos_farmer_app/core/services/local_storage_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 SplashScreen initialized');

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    debugPrint('⏱️ Waiting 3 seconds before API check...');
    await Future.delayed(const Duration(seconds: 3));
    await _checkAndNavigate();
  }

  Future<void> _checkAndNavigate() async {

    debugPrint('🔄 _checkAndNavigate called');

    if (!mounted) {
      debugPrint('⚠️ Widget not mounted, returning');
      return;
    }

    final apiResults = await HealthCheckService.checkApis();

    final failedApis = apiResults.where((api) => !api.isUp).toList();

    final connected = failedApis.isEmpty;

    debugPrint('🌐 Connected: $connected, Mounted: $mounted');

    if (!mounted) {
      debugPrint('⚠️ Widget not mounted after API check, returning');
      return;
    }

    if (!connected) {
      debugPrint('📴 Server down, showing ServerDownScreen');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ServerDownScreen(
              failedApis: failedApis,
            ),
          ),
        );
      }
      return;
    }

    debugPrint('✅ APIs are up, checking login status');
    final isLogin = LocalStorageService.getInt('IsLogin') ?? 0;
    final sessionId = LocalStorageService.getString('session_id');

    debugPrint('👤 IsLogin: $isLogin, SessionId: $sessionId');

    if (!mounted) {
      debugPrint('⚠️ Widget not mounted before navigation, returning');
      return;
    }

    if (isLogin == 1 && sessionId != null && sessionId.isNotEmpty) {
      debugPrint('🏠 Going to home screen');
      context.go('/');
    } else {
      debugPrint('🔑 Going to login screen');
      await LocalStorageService.remove('IsLogin');
      await LocalStorageService.remove('session_id');
      context.go('/login');
    }
  }

  @override
  void dispose() {
    debugPrint('🧹 SplashScreen disposed');
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE80E15), Color(0xFFC20B12)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Image.asset(
                      'assets/images/PoultryOS.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('❌ Failed to load logo: $error');
                        return const Center(
                          child: Text(
                            'PoultryOS',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE80E15),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              FadeTransition(
                opacity: _fadeAnimation,
                child: const Column(
                  children: [
                    Text(
                      'PoultryOS',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Farmer Management System',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}
