import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:poultryos_farmer_app/core/services/local_storage_service.dart';
import 'package:poultryos_farmer_app/core/services/auth_api_service.dart';
import 'package:poultryos_farmer_app/core/theme/app_theme.dart';

/// Which identifier the user is registering with.
/// Email registrations require a password; mobile registrations require a PIN.
enum _SignupMode { email, mobile }

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _identifierController = TextEditingController();
  final _credentialController = TextEditingController();
  final _confirmCredentialController = TextEditingController();

  _SignupMode _mode = _SignupMode.email;
  bool _showCredential = false;
  bool _showConfirm = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _identifierController.dispose();
    _credentialController.dispose();
    _confirmCredentialController.dispose();
    super.dispose();
  }

  void _switchMode(_SignupMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _identifierController.clear();
      _credentialController.clear();
      _confirmCredentialController.clear();
    });
  }

  Future<void> _handleSignUp() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final name = _nameController.text.trim();
    final identifier = _identifierController.text.trim();
    final credential = _credentialController.text.trim();

    final result = await AuthApiService.signup(
      name: name,
      email: _mode == _SignupMode.email ? identifier : null,
      mobile: _mode == _SignupMode.mobile ? identifier : null,
      password: _mode == _SignupMode.email ? credential : null,
      pin: _mode == _SignupMode.mobile ? credential : null,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.success && result.user != null) {
      final user = result.user!;

      await LocalStorageService.setString(
          'email', (user['email'] ?? '') as String);
      await LocalStorageService.setString(
          'mobile', (user['mobile'] ?? '') as String);
      await LocalStorageService.setString(
          'role', (user['role'] ?? 'Farmer') as String);
      await LocalStorageService.setString(
          'user_code', (user['user_code'] ?? '') as String);
      await LocalStorageService.setString(
          'display_name', (user['name'] ?? '') as String);
      await LocalStorageService.setString('access_token', result.token ?? '');
      await LocalStorageService.setInt('IsLogin', 1);
      await LocalStorageService.setBool('profile_completed', false);
      await LocalStorageService.remove('farmer_id');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome, ${user['name']}! Your account is ready.'),
          backgroundColor: const Color(0xFF0D8B60),
          duration: const Duration(seconds: 2),
        ),
      );

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) context.go('/profile');
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(result.errorMessage ?? 'Sign up failed. Please try again.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
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
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/login'),
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
                      Center(
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryRed.withOpacity(0.85),
                                AppTheme.primaryRed
                              ],
                            ),
                          ),
                          child: const Icon(Icons.person_add_alt_1,
                              color: Colors.white, size: 40),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Create your account',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign up with your email or mobile number',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 28),
                      _buildModeToggle(),
                      const SizedBox(height: 20),
                      const Text('Full Name',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? 'Required' : null,
                        decoration: InputDecoration(
                          hintText: 'Enter your full name',
                          prefixIcon: const Icon(Icons.person_outline),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _mode == _SignupMode.email
                            ? 'Email Address'
                            : 'Mobile Number',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _identifierController,
                        keyboardType: _mode == _SignupMode.email
                            ? TextInputType.emailAddress
                            : TextInputType.phone,
                        inputFormatters: _mode == _SignupMode.mobile
                            ? [FilteringTextInputFormatter.digitsOnly]
                            : [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return 'Required';
                          if (_mode == _SignupMode.email &&
                              !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                  .hasMatch(value)) {
                            return 'Enter a valid email';
                          }
                          if (_mode == _SignupMode.mobile &&
                              !RegExp(r'^\d{10}$').hasMatch(value)) {
                            return 'Enter a valid 10-digit number';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: _mode == _SignupMode.email
                              ? 'you@example.com'
                              : 'Enter your mobile number',
                          prefixIcon: Icon(
                            _mode == _SignupMode.email
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
                      Text(
                        _mode == _SignupMode.email
                            ? 'Password'
                            : 'PIN (4-6 digits)',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _credentialController,
                        obscureText: !_showCredential,
                        keyboardType: _mode == _SignupMode.mobile
                            ? TextInputType.number
                            : TextInputType.text,
                        inputFormatters: _mode == _SignupMode.mobile
                            ? [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6)
                              ]
                            : null,
                        validator: (v) {
                          final value = v ?? '';
                          if (value.isEmpty) return 'Required';
                          if (_mode == _SignupMode.email && value.length < 6) {
                            return 'At least 6 characters';
                          }
                          if (_mode == _SignupMode.mobile &&
                              !RegExp(r'^\d{4,6}$').hasMatch(value)) {
                            return 'PIN must be 4-6 digits';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: _mode == _SignupMode.email
                              ? 'Create a password'
                              : 'Create a PIN',
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
                      const SizedBox(height: 16),
                      Text(
                        _mode == _SignupMode.email
                            ? 'Confirm Password'
                            : 'Confirm PIN',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _confirmCredentialController,
                        obscureText: !_showConfirm,
                        keyboardType: _mode == _SignupMode.mobile
                            ? TextInputType.number
                            : TextInputType.text,
                        inputFormatters: _mode == _SignupMode.mobile
                            ? [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6)
                              ]
                            : null,
                        validator: (v) {
                          if ((v ?? '') != _credentialController.text) {
                            return _mode == _SignupMode.email
                                ? 'Passwords do not match'
                                : 'PINs do not match';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: _mode == _SignupMode.email
                              ? 'Re-enter your password'
                              : 'Re-enter your PIN',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _showConfirm = !_showConfirm),
                            icon: Icon(_showConfirm
                                ? Icons.visibility
                                : Icons.visibility_off),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _handleSignUp,
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
                            : const Text('Sign Up',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[700]),
                            children: [
                              const TextSpan(text: 'Already have an account? '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: GestureDetector(
                                  onTap: () => context.canPop()
                                      ? context.pop()
                                      : context.go('/login'),
                                  child: const Text(
                                    'Sign in',
                                    style: TextStyle(
                                        color: AppTheme.primaryRed,
                                        fontWeight: FontWeight.w700),
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
              mode: _SignupMode.email),
          _buildModeTab(
              label: 'Mobile',
              icon: Icons.smartphone,
              mode: _SignupMode.mobile),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required String label,
    required IconData icon,
    required _SignupMode mode,
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
}
