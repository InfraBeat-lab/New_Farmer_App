import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:poultryos_farmer_app/core/services/local_storage_service.dart';
import 'package:poultryos_farmer_app/core/widgets/powered_by_footer.widget.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  late PageController _carouselController;
  int _currentCarouselIndex = 0;
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    _carouselController = PageController(viewportFraction: 0.9);
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_carouselController.hasClients) return;

      final nextPage = (_carouselController.page?.round() ?? 0) + 1;

      _carouselController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _carouselController.dispose();
    super.dispose();
  }



  void _handleSignIn() async {
    FocusScope.of(context).unfocus();
    
    final emailVal = _emailController.text.trim();
    final passwordVal = _passwordController.text.trim();

    // Default to Ramesh Patel if both are empty (for testing)
    final email = emailVal.isEmpty ? 'ramesh.farms@gmail.com' : emailVal;
    final password = passwordVal.isEmpty ? 'adminpassword' : passwordVal;

    // Load users from Local Storage
    final usersJson = LocalStorageService.getString('users_list');
    List<dynamic> users = [];
    if (usersJson != null && usersJson.isNotEmpty) {
      try {
        users = jsonDecode(usersJson) as List<dynamic>;
      } catch (e) {
        debugPrint('Error parsing users_list: $e');
      }
    }

    // Always ensure Admin Ramesh is in the list
    bool adminExists = users.any((u) => u['email'] == 'ramesh.farms@gmail.com');
    if (!adminExists) {
      users.insert(0, {
        'name': 'Ramesh Patel (Admin)',
        'mobile': '9876543210',
        'email': 'ramesh.farms@gmail.com',
        'password': 'adminpassword',
        'role': 'Farmer',
        'farmerId': '1',
        'userCode': 'RP-1001',
        'isAdmin': true
      });
      await LocalStorageService.setString('users_list', jsonEncode(users));
    }

    // Look for matching user
    Map<String, dynamic>? matchedUser;
    for (var u in users) {
      if (u['email'] == email && u['password'] == password) {
        matchedUser = Map<String, dynamic>.from(u as Map);
        break;
      }
    }

    if (matchedUser != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Signing in as ${matchedUser['name']}...'),
          backgroundColor: const Color(0xFF0D8B60),
          duration: const Duration(seconds: 1),
        ),
      );

      final isAdmin = matchedUser['isAdmin'] == true;
      final role = matchedUser['role'] ?? 'Farmer';
      final code = matchedUser['userCode'] ?? 'RP-1001';
      final name = matchedUser['name'] ?? 'Ramesh Patel';

      await LocalStorageService.setString('email', email);
      await LocalStorageService.setString('role', role);
      await LocalStorageService.setString('user_code', code);
      await LocalStorageService.setString('display_name', name);
      await LocalStorageService.setInt('IsLogin', 1);
      await LocalStorageService.setString('session_id', 'dummy_session_id');

      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        if (isAdmin) {
          context.go('/profile');
        } else {
          context.go('/');
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid email or password. Please try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCarouselSection(context),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                // ← ADD: prevents overflow on small screens
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    const Text(
                      'Welcome back',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sign in to manage your batches',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 20),

                    // ── Login Form ──────────────────────────────
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Email label
                          const Padding(
                            padding: EdgeInsets.only(left: 4.0, bottom: 6.0),
                            child: Text(
                              'Email',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            inputFormatters: [
                              FilteringTextInputFormatter.deny(RegExp(r'\s')),
                            ],
                            decoration: InputDecoration(
                              hintText: 'ramesh.farms@gmail.com',
                              prefixIcon: const Icon(Icons.alternate_email),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Password label
                          const Padding(
                            padding: EdgeInsets.only(left: 4.0, bottom: 6.0),
                            child: Text(
                              'Password',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_showPassword,
                            decoration: InputDecoration(
                              hintText: '********',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(
                                      () => _showPassword = !_showPassword);
                                },
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Forgot password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Forgot password flow not implemented yet.'),
                                  ),
                                );
                              },
                              child: const Text(
                                'Forgot password?',
                                style: TextStyle(
                                  color: Color(0xFF0D8B60),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Sign in button
                          ElevatedButton(
                            onPressed: _handleSignIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D8B60),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Sign in',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // OR divider
                          const Center(
                            child: Text(
                              'Or continue with',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Social buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildSymbolButton(
                                assetPath: 'assets/images/gmail.png',
                                backgroundColor: const Color(0xFFFDE8E8),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Gmail login not implemented yet'),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 16),
                              _buildSymbolButton(
                                assetPath: 'assets/images/google.png',
                                backgroundColor: const Color(0xFFE3F2FD),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Google login not implemented yet'),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          const PoweredByFooter(),
                          const SizedBox(height: 16), // ← bottom breathing room
                        ], // Form Column children
                      ), // Form Column
                    ), // Form
                  ], // ← outer Column children  (was MISSING the closing ])
                ), // outer Column
              ), // SingleChildScrollView
            ), // Expanded
          ], // SafeArea Column children
        ), // SafeArea Column
      ), // SafeArea
    ); // Scaffold
  }

  // Add this list at the top of your State class
  final List<Map<String, dynamic>> _carouselData = [
    {
      'image': 'assets/images/3.jpg',
      'title': 'Breeder Management',
      'subtitle': 'Track parent flock performance & feed',
      'color': Color(0xFF6FCF97),
      'icon': Icons.egg_alt_outlined,
    },
    {
      'image': 'assets/images/21.jpg',
      'title': 'Hatchery Tracking',
      'subtitle': 'Monitor incubation, hatching & chick dispatch',
      'color': Color(0xFF05A660),
      'icon': Icons.device_thermostat,
    },
    {
      'image': 'assets/images/23.jpg',
      'title': 'Farm Analytics',
      'subtitle': 'Real-time reports & batch performance',
      'color': Color(0xFF07754A),
      'icon': Icons.bar_chart,
    }
  ];

// ── Updated _buildCarouselSection ────────────────────────────
  Widget _buildCarouselSection(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _carouselController,
            onPageChanged: (index) {
              // setState(() {
              //   _currentCarouselIndex = index % _carouselData.length;
              // });
              setState(() {
                _currentCarouselIndex = index % _carouselData.length;
              });
              _autoScrollTimer?.cancel();
              _startAutoScroll();
            },
            itemBuilder: (context, index) {
              final actualIndex = index % _carouselData.length;
              final item = _carouselData[actualIndex];

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // ── Background image ──────────────────────
                      Image.asset(
                        item['image'] as String,
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, ___) {
                          debugPrint(
                              'Image load failed: ${item['image']} → $error');
                          return Container(color: item['color'] as Color);
                        },
                      ),

                      // ── Dark gradient overlay ─────────────────
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                            colors: [
                              Colors.black.withOpacity(0.15),
                              Colors.black.withOpacity(0.65),
                            ],
                          ),
                        ),
                      ),

                      // ── Text content ──────────────────────────
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Icon badge
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.4),
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                item['icon'] as IconData,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Title + subtitle
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['title'] as String,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      height: 1.2,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black38,
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item['subtitle'] as String,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 12,
                                      height: 1.4,
                                      shadows: const [
                                        Shadow(
                                          color: Colors.black26,
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // ── Dot indicators ────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _carouselData.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: _currentCarouselIndex == index ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: _currentCarouselIndex == index
                      ? const Color(0xFF0D8B60)
                      : Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSymbolButton({
    required String assetPath,
    required Color backgroundColor,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Image.asset(
            assetPath,
            fit: BoxFit.contain,
            errorBuilder: (_, error, __) {
              debugPrint('Icon load failed: $assetPath → $error');
              return const Icon(Icons.error_outline, color: Colors.grey);
            },
          ),
        ),
      ),
    );
  }
}
