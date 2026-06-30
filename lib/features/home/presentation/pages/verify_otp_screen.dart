import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:poultryos_farmer_app/viewmodels/otp_viewmodel.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:poultryos_farmer_app/core/widgets/powered_by_footer.widget.dart';

class VerifyOtpScreen extends ConsumerStatefulWidget {
  final String mobileNumber;

  const VerifyOtpScreen({super.key, required this.mobileNumber});

  @override
  ConsumerState<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends ConsumerState<VerifyOtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _handleStateChange(VerifyOtpState state) {
    if (state.status == VerifyOtpStatus.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login successful!'),
          backgroundColor: Colors.green,
        ),
      );
      // Navigate to home screen
      context.go('/');
    } else if (state.status == VerifyOtpStatus.error) {
      _showErrorDialog(state.errorMessage);
      ref.read(verifyOtpProvider.notifier).resetState();
    } else if (state.status == VerifyOtpStatus.updateRequired) {
      _showUpdateDialog();
      ref.read(verifyOtpProvider.notifier).resetState();
    }
  }

  void _handleVerifyOtp() {
    if (_formKey.currentState!.validate()) {
      ref
          .read(verifyOtpProvider.notifier)
          .verifyOtp(widget.mobileNumber, _otpController.text.trim());
    }
  }

  void _handleResendOtp() {
    ref.read(verifyOtpProvider.notifier).resendOtp(widget.mobileNumber);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Requesting new OTP...'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alert'),
        content: Text(message),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ok'),
          ),
        ],
      ),
    );
  }

  void _showUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Update Required'),
          content: const Text(
              'A new version of the app is available. Please update to continue.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                const url =
                    'https://play.google.com/store/apps/details?id=com.poultryos.farmerapp';
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url),
                      mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen for state transitions
    ref.listen<VerifyOtpState>(verifyOtpProvider, (_, next) {
      _handleStateChange(next);
    });

    final otpState = ref.watch(verifyOtpProvider);
    final isLoading = otpState.status == VerifyOtpStatus.loading;
    final canResend = otpState.canResend;
    final resendCounter = otpState.resendCounter;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.1),

                  // Almost there text
                  Text(
                    'Almost there...',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                      fontSize: 24,
                      fontFamily: 'Roboto',
                    ),
                  ),

                  SizedBox(height: MediaQuery.of(context).size.height * 0.1),

                  // Graphic image
                  Image.asset(
                    'assets/images/graphic_2.png',
                    width: MediaQuery.of(context).size.width * 0.7,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset(
                        'assets/images/KKCK_logo.png',
                        width: MediaQuery.of(context).size.width * 0.5,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 120,
                            width: 120,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                'KKCK',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  // Instructions
                  const Text(
                    'Please enter the verification code sent to',
                    style: TextStyle(fontSize: 17, fontFamily: 'Roboto'),
                  ),

                  const SizedBox(height: 5),

                  // Mobile number
                  Text(
                    '+91 ${widget.mobileNumber}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // OTP Input
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      textAlign: TextAlign.center,
                      style: const TextStyle(letterSpacing: 20, fontSize: 20),
                      obscureText: true,
                      enabled: !isLoading,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                        hintText: '****',
                        counterText: '',
                        border: InputBorder.none,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter OTP';
                        }
                        if (value.length != 4) {
                          return 'OTP must be 4 digits';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _handleVerifyOtp(),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // "Didn't receive OTP"
                  const Center(
                    child: Text(
                      "Didn't receive OTP?",
                      style: TextStyle(fontSize: 14),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Buttons row
                  Row(
                    children: [
                      // Verify Button
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isLoading ? null : _handleVerifyOtp,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.deepOrange),
                            foregroundColor: Colors.deepOrange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.deepOrange,
                                    ),
                                  ),
                                )
                              : const Text('VERIFY OTP'),
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Resend Button
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              canResend && !isLoading ? _handleResendOtp : null,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: canResend
                                  ? Colors.grey
                                  : Colors.grey.withOpacity(0.3),
                            ),
                            foregroundColor: Colors.grey,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: resendCounter > 0
                              ? Text('WAIT ${resendCounter}s')
                              : const Text('RESEND OTP'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const PoweredByFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
