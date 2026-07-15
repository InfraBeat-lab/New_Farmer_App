// lib/features/recharge/screens/payment_screen.dart
// Screen 3 of the Recharge flow:
// - Launches Cashfree's native Web Checkout via the official Flutter SDK
//   (flutter_cashfree_pg_sdk) — no more hand-built WebView URL.
// - On SUCCESS: updates local credit balance, shows animated success screen
// - On FAILURE / CANCEL: shows error with retry

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfexceptions.dart';
import 'package:poultryos_farmer_app/core/services/local_storage_service.dart';
import 'package:poultryos_farmer_app/core/theme/app_theme.dart';
import 'package:poultryos_farmer_app/features/recharge/models/recharge_models.dart';

enum _PaymentStatus { launching, inProgress, success, failure, cancelled }

class PaymentScreen extends StatefulWidget {
  final String orderId;
  final String paymentSessionId;
  final bool isProduction;
  final double total;
  final String currencySymbol;
  final List<CartItem> cart;
  final String? appliedCoupon;
  final double discountAmount;
  final bool isInterstate;
  final String farmerName;
  final String farmName;

  const PaymentScreen({
    super.key,
    required this.orderId,
    required this.paymentSessionId,
    required this.isProduction,
    required this.total,
    required this.currencySymbol,
    required this.cart,
    this.appliedCoupon,
    required this.discountAmount,
    required this.isInterstate,
    required this.farmerName,
    required this.farmName,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with SingleTickerProviderStateMixin {
  final CFPaymentGatewayService _cfPaymentGatewayService =
      CFPaymentGatewayService();

  _PaymentStatus _status = _PaymentStatus.launching;
  String? _errorMessage;

  // For success animation
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);

    _cfPaymentGatewayService.setCallback(_verifyPayment, _onError);

    // Launch checkout right after the first frame renders.
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCheckout());
  }

  void _startCheckout() {
    setState(() => _status = _PaymentStatus.inProgress);
    try {
      final session = CFSessionBuilder()
          .setEnvironment(widget.isProduction
              ? CFEnvironment.PRODUCTION
              : CFEnvironment.SANDBOX)
          .setOrderId(widget.orderId)
          .setPaymentSessionId(widget.paymentSessionId)
          .build();

      final webCheckout =
          CFWebCheckoutPaymentBuilder().setSession(session).build();

      _cfPaymentGatewayService.doPayment(webCheckout);
    } on CFException catch (e) {
      setState(() {
        _status = _PaymentStatus.failure;
        _errorMessage = e.message;
      });
    }
  }

  // ─── SDK callbacks ────────────────────────────────────────────────────────────
  void _verifyPayment(String orderId) {
    if (!mounted) return;
    // TODO: For production, call your backend to verify the order status
    // via GET /pg/orders/{order_id} before crediting the account — the
    // client-side callback alone should not be treated as proof of payment.
    _updateLocalBalances();
    setState(() => _status = _PaymentStatus.success);
    _animCtrl.forward();
  }

  void _onError(CFErrorResponse errorResponse, String orderId) {
    if (!mounted) return;
    final message =
        errorResponse.getMessage() ?? 'Payment could not be completed';
    final looksCancelled = message.toLowerCase().contains('cancel');
    setState(() {
      _status =
          looksCancelled ? _PaymentStatus.cancelled : _PaymentStatus.failure;
      _errorMessage = message;
    });
  }

  /// Update local storage credit balances after successful payment
  void _updateLocalBalances() {
    int broiler = LocalStorageService.getInt('broiler_balance') ?? 0;
    int layer = LocalStorageService.getInt('layer_balance') ?? 0;
    int breeder = LocalStorageService.getInt('breeder_balance') ?? 0;

    for (final item in widget.cart) {
      switch (item.module) {
        case 'Broiler':
          broiler += item.count;
          break;
        case 'Layer':
          layer += item.count;
          break;
        case 'Breeder':
          breeder += item.count;
          break;
      }
    }

    LocalStorageService.setInt('broiler_balance', broiler);
    LocalStorageService.setInt('layer_balance', layer);
    LocalStorageService.setInt('breeder_balance', breeder);
    LocalStorageService.setBool('recharged', true);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: (_status == _PaymentStatus.inProgress ||
              _status == _PaymentStatus.launching)
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              automaticallyImplyLeading: false,
              title: const Row(
                children: [
                  Icon(Icons.lock_rounded, size: 16, color: Colors.green),
                  SizedBox(width: 6),
                  Text('Secure Payment',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.grey800)),
                ],
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  backgroundColor: AppTheme.grey100,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppTheme.primaryRed),
                  value: null,
                ),
              ),
            )
          : null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case _PaymentStatus.launching:
      case _PaymentStatus.inProgress:
        return _buildLoading();
      case _PaymentStatus.success:
        return _buildSuccess();
      case _PaymentStatus.failure:
        return _buildFailure();
      case _PaymentStatus.cancelled:
        return _buildCancelled();
    }
  }

  // ─── Loading ──────────────────────────────────────────────────────────────────
  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: AppTheme.primaryRed.withValues(alpha: 0.15),
                    blurRadius: 20)
              ],
            ),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryRed),
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Launching Cashfree Checkout',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.grey800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please wait, do not close this screen',
            style: TextStyle(fontSize: 13, color: AppTheme.grey500),
          ),
          const SizedBox(height: 24),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.security_rounded, size: 14, color: AppTheme.grey400),
              SizedBox(width: 4),
              Text('Secured by Cashfree Payments',
                  style: TextStyle(fontSize: 11, color: AppTheme.grey400)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Success ──────────────────────────────────────────────────────────────────
  Widget _buildSuccess() {
    final broilerItems = widget.cart
        .where((c) => c.module == 'Broiler')
        .fold(0, (s, c) => s + c.count);
    final layerItems = widget.cart
        .where((c) => c.module == 'Layer')
        .fold(0, (s, c) => s + c.count);
    final breederItems = widget.cart
        .where((c) => c.module == 'Breeder')
        .fold(0, (s, c) => s + c.count);

    return FadeTransition(
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 30),
            ScaleTransition(
              scale: _scaleAnim,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00C853), Color(0xFF69F0AE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00C853).withValues(alpha: 0.4),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 56),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Payment Successful!',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey800),
            ),
            const SizedBox(height: 8),
            Text(
              'Credits added to your account',
              style: TextStyle(fontSize: 14, color: AppTheme.grey500),
            ),
            const SizedBox(height: 32),
            if (broilerItems > 0 || layerItems > 0 || breederItems > 0) ...[
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A1A2E), Color(0xFF0F3460)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text('Credits Added',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        if (broilerItems > 0)
                          _creditBadge('Broiler', broilerItems, Colors.orange),
                        if (layerItems > 0)
                          _creditBadge(
                              'Layer', layerItems, const Color(0xFFFFD700)),
                        if (breederItems > 0)
                          _creditBadge(
                              'Breeder', breederItems, Colors.redAccent),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.receipt_long_rounded,
                        size: 18, color: AppTheme.primaryRed),
                    const SizedBox(width: 8),
                    const Text('Payment Receipt',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ]),
                  const Divider(height: 16),
                  _receiptRow('Transaction ID', widget.orderId),
                  _receiptRow('Farmer Name', widget.farmerName),
                  _receiptRow('Farm', widget.farmName),
                  const Divider(height: 14),
                  ...widget.cart.map((item) => _receiptRow(
                      '${item.module} License (${item.count} Batches)',
                      '${widget.currencySymbol}${item.subtotal.toStringAsFixed(2)}')),
                  const Divider(height: 14),
                  if (widget.appliedCoupon != null)
                    _receiptRow('Coupon (${widget.appliedCoupon})',
                        '-${widget.currencySymbol}${widget.discountAmount.toStringAsFixed(2)}',
                        valueColor: AppTheme.successDark),
                  _receiptRow('Total Paid',
                      '${widget.currencySymbol}${widget.total.toStringAsFixed(2)}',
                      bold: true, valueColor: AppTheme.primaryRed),
                  _receiptRow('Status', '✅ PAID',
                      bold: true, valueColor: const Color(0xFF00C853)),
                ],
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home_rounded),
                label: const Text('Go to Dashboard',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _creditBadge(String label, int count, Color color) {
    return Column(
      children: [
        Text('+$count',
            style: TextStyle(
                color: color, fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text('Batches',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
      ],
    );
  }

  Widget _receiptRow(String label, String value,
      {bool bold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              flex: 3,
              child: Text(label,
                  style:
                      const TextStyle(fontSize: 12, color: AppTheme.grey500))),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                color: valueColor ?? AppTheme.grey800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Failure ──────────────────────────────────────────────────────────────────
  Widget _buildFailure() {
    return _buildResultScreen(
      icon: Icons.cancel_rounded,
      iconColor: AppTheme.error,
      title: 'Payment Failed',
      subtitle: _errorMessage ??
          'Your payment could not be processed.\nNo amount has been deducted.',
      primaryLabel: 'Try Again',
      onPrimary: _startCheckout,
      secondaryLabel: 'Go Back',
      onSecondary: () => context.pop(),
    );
  }

  // ─── Cancelled ────────────────────────────────────────────────────────────────
  Widget _buildCancelled() {
    return _buildResultScreen(
      icon: Icons.remove_circle_rounded,
      iconColor: Colors.orange,
      title: 'Payment Cancelled',
      subtitle: 'You cancelled the payment.\nYour cart is still saved.',
      primaryLabel: 'Try Again',
      onPrimary: _startCheckout,
      secondaryLabel: 'Go Back to Cart',
      onSecondary: () => context.pop(),
    );
  }

  Widget _buildResultScreen({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String primaryLabel,
    required VoidCallback onPrimary,
    required String secondaryLabel,
    required VoidCallback onSecondary,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 50),
            ),
            const SizedBox(height: 24),
            Text(title,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.grey800)),
            const SizedBox(height: 10),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.grey500, height: 1.5)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPrimary,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(primaryLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onSecondary,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.grey300),
                  foregroundColor: AppTheme.grey700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(secondaryLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
