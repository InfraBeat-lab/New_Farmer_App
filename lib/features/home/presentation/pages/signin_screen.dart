import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poultryos_farmer_app/core/services/auth_service.dart';
import 'package:poultryos_farmer_app/core/services/local_storage_service.dart';
import 'package:poultryos_farmer_app/core/services/auth_api_service.dart';
import 'package:poultryos_farmer_app/core/theme/app_theme.dart';

/// Sign-in mode: either registered email+password or registered mobile+PIN.
enum _LoginMode { email, mobile }

class SigninScreen extends StatefulWidget {
  const SigninScreen({super.key});

  @override
  State<SigninScreen> createState() => _SigninScreenState();
}

class _SigninScreenState extends State<SigninScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _credentialController = TextEditingController();

  _LoginMode _mode = _LoginMode.email;
  bool _showCredential = false;
  bool _isSubmitting = false;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _credentialController.dispose();
    super.dispose();
  }

  void _switchMode(_LoginMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _identifierController.clear();
      _credentialController.clear();
      _showCredential = false;
    });
  }

  Future<void> _handleSignIn() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final identifier = _identifierController.text.trim();
    final credential = _credentialController.text.trim();

    final result = await AuthApiService.login(
      identifier: identifier,
      credential: credential,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.success && result.user != null) {
      final user = result.user!;

      await LocalStorageService.setString(
          'email', (user['email_address'] ?? '') as String);
      await LocalStorageService.setString(
          'mobile', (user['mobile_number'] ?? '') as String);
      await LocalStorageService.setInt('role', (user['role_id'] ?? 1));
      await LocalStorageService.setString(
          'user_code', (user['user_code'] ?? '') as String);
      await LocalStorageService.setString(
          'display_name', (user['user_name'] ?? '') as String);
      await LocalStorageService.setString('access_token', result.token ?? '');
      await LocalStorageService.setInt('IsLogin', 1);

      if (user['farmer_id'] != null) {
        await LocalStorageService.setInt('farmer_id', user['farmer_id'] as int);
        await LocalStorageService.setBool('profile_completed', true);
      } else if (user['farmer'] != null && user['farmer']['id'] != null) {
        await LocalStorageService.setInt(
            'farmer_id', user['farmer']['id'] as int);
        await LocalStorageService.setBool('profile_completed', true);
      }

      final isProfileCompleted =
          LocalStorageService.getBool('profile_completed') ?? false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Signing in as ${user['user_name']}...'),
          backgroundColor: AppTheme.primaryRed,
          duration: const Duration(seconds: 1),
        ),
      );

      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        if (isProfileCompleted) {
          context.go('/recharge');
        } else {
          context.go('/profile');
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              result.errorMessage ?? 'Invalid credentials. Please try again.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isGoogleLoading) return;
    setState(() => _isGoogleLoading = true);

    try {
      final result =
          await AuthService.signInWithGoogle(allowMockFallback: true);
      if (!mounted) return;

      if (result.success) {
        await LocalStorageService.setString('email', result.email ?? '');
        await LocalStorageService.setString('role', 'Farmer');
        await LocalStorageService.setString(
            'user_code', 'G-${result.email?.split('@').first ?? 'USER'}');
        await LocalStorageService.setString(
            'display_name', result.displayName ?? 'Google User');
        await LocalStorageService.setString(
            'profile_image_url', result.photoUrl ?? '');
        await LocalStorageService.setInt('IsLogin', 1);
        await LocalStorageService.setString('session_id', 'google_session_id');

        final isProfileCompleted =
            LocalStorageService.getBool('profile_completed') ?? false;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Signed in successfully as ${result.displayName}!'),
            backgroundColor: const Color(0xFF0D8B60),
            duration: const Duration(seconds: 2),
          ),
        );

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            if (isProfileCompleted) {
              context.go('/');
            } else {
              context.go('/profile');
            }
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(result.errorMessage ?? 'Google authentication failed.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('An unexpected error occurred: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      _buildHeroBadge(),
                      const SizedBox(height: 24),
                      const Text(
                        'Welcome back!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to continue to your account',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 28),

                      _buildModeToggle(),
                      const SizedBox(height: 20),

                      // Identifier field (email or mobile depending on mode)
                      Text(
                        _mode == _LoginMode.email
                            ? 'Email Address'
                            : 'Mobile Number',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _identifierController,
                        keyboardType: _mode == _LoginMode.email
                            ? TextInputType.emailAddress
                            : TextInputType.phone,
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return 'Required';
                          if (_mode == _LoginMode.email &&
                              !value.contains('@')) {
                            return 'Enter a valid email';
                          }
                          if (_mode == _LoginMode.mobile &&
                              !RegExp(r'^\d{10}$').hasMatch(value)) {
                            return 'Enter a valid 10-digit number';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: _mode == _LoginMode.email
                              ? 'Enter your email'
                              : 'Enter your mobile number',
                          prefixIcon: Icon(
                            _mode == _LoginMode.email
                                ? Icons.alternate_email
                                : Icons.phone_iphone,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Credential field (password or PIN depending on mode)
                      Text(
                        _mode == _LoginMode.email ? 'Password' : 'PIN',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _credentialController,
                        obscureText: !_showCredential,
                        keyboardType: _mode == _LoginMode.mobile
                            ? TextInputType.number
                            : TextInputType.text,
                        validator: (v) => (v ?? '').isEmpty ? 'Required' : null,
                        decoration: InputDecoration(
                          hintText: _mode == _LoginMode.email
                              ? 'Enter your password'
                              : 'Enter your PIN',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                                () => _showCredential = !_showCredential),
                            icon: Icon(_showCredential
                                ? Icons.visibility
                                : Icons.visibility_off),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 8),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Forgot password flow not implemented yet.')),
                            );
                          },
                          child: const Text(
                            'Forgot password?',
                            style: TextStyle(
                                color: AppTheme.primaryRed,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _handleSignIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Sign In',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey[300])),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('or',
                                style: TextStyle(
                                    color: Colors.black54, fontSize: 13)),
                          ),
                          Expanded(child: Divider(color: Colors.grey[300])),
                        ],
                      ),
                      const SizedBox(height: 16),

                      OutlinedButton(
                        onPressed:
                            _isGoogleLoading ? null : _handleGoogleSignIn,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                              color: AppTheme.primaryRed.withOpacity(0.4)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isGoogleLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/images/gmail.png',
                                    width: 20,
                                    height: 20,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.g_mobiledata,
                                        size: 22),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text('Continue with Google',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                      ),
                      const SizedBox(height: 24),

                      Center(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[700]),
                            children: [
                              const TextSpan(text: "Don't have an account? "),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: GestureDetector(
                                  onTap: () => context.push('/signup'),
                                  child: const Text(
                                    'Sign up',
                                    style: TextStyle(
                                      color: AppTheme.primaryRed,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 1)),
      ),
      child: Row(
        children: [
          _buildModeTab(
            label: 'Email',
            icon: Icons.mail_outline,
            mode: _LoginMode.email,
          ),
          _buildModeTab(
            label: 'Mobile',
            icon: Icons.smartphone,
            mode: _LoginMode.mobile,
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required String label,
    required IconData icon,
    required _LoginMode mode,
  }) {
    final selected = _mode == mode;
    return Expanded(
      child: InkWell(
        onTap: () => _switchMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppTheme.primaryRed : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? AppTheme.primaryRed : Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppTheme.primaryRed : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBadge() {
    return Center(
      child: SizedBox(
        width: 160,
        height: 160,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryRed.withOpacity(0.06),
              ),
            ),
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryRed.withOpacity(0.85),
                    AppTheme.primaryRed
                  ],
                ),
              ),
              child: const Icon(Icons.shield_outlined,
                  color: Colors.white, size: 48),
            ),
            const Positioned(
              top: 10,
              right: 10,
              child: Icon(Icons.send_rounded, color: Colors.black26, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}
