// lib/features/recharge/screens/checkout_screen.dart
// Screen 2 of the Recharge flow:
// - Farmer profile header (name, farm name, transaction ID)
// - Full cart line items
// - Inter-state / Intra-state toggle
// - Coupon code input and quick-apply coupon cards
// - Detailed invoice breakdown (subtotal → discount → tax → total)
// - "Pay Now" CTA → creates Cashfree order → navigates to PaymentScreen

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poultryos_farmer_app/core/services/local_storage_service.dart';
import 'package:poultryos_farmer_app/core/theme/app_theme.dart';
import 'package:poultryos_farmer_app/features/recharge/models/recharge_models.dart';
import 'package:poultryos_farmer_app/features/recharge/services/cashfree_service.dart';

class CheckoutScreen extends StatefulWidget {
  final List<CartItem> cart;
  final String currencySymbol;
  final double flatDiscountAmount;
  final String flatDiscountText;

  const CheckoutScreen({
    super.key,
    required this.cart,
    required this.currencySymbol,
    required this.flatDiscountAmount,
    required this.flatDiscountText,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen>
    with SingleTickerProviderStateMixin {
  // ─── User Info ────────────────────────────────────────────────────────────────
  late String _farmerName;
  late String _farmName;
  late String _mobile;
  late String _email;
  late String _txnId;

  // ─── Tax ──────────────────────────────────────────────────────────────────────
  bool _isInterstate = false;

  // ─── Coupon ───────────────────────────────────────────────────────────────────
  final _couponCtrl = TextEditingController();
  String? _appliedCoupon;
  double _discountAmount = 0.0;
  String? _couponError;
  String? _couponSuccess;

  // ─── Payment loading ──────────────────────────────────────────────────────────
  bool _creatingOrder = false;

  // ─── Animation ───────────────────────────────────────────────────────────────
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _farmerName = LocalStorageService.getString('name') ??
        LocalStorageService.getString('display_name') ??
        'Farmer';
    _farmName = LocalStorageService.getString('farm_name') ?? 'My Farm';
    _mobile = LocalStorageService.getString('mobile') ?? '';
    _email = LocalStorageService.getString('email') ?? '';

    final n = Random().nextInt(90000000) + 10000000;
    _txnId = 'TXN-POULTRY-$n';
  }

  @override
  void dispose() {
    _couponCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ─── Computed values ─────────────────────────────────────────────────────────
  double get _subtotal => widget.cart.fold(0.0, (s, i) => s + i.subtotal);

  double get _discountedSubtotal => max(0.0, _subtotal - _discountAmount);

  double get _cgst => _isInterstate ? 0.0 : _discountedSubtotal * 0.09;

  double get _sgst => _isInterstate ? 0.0 : _discountedSubtotal * 0.09;

  double get _igst => _isInterstate ? _discountedSubtotal * 0.18 : 0.0;

  double get _total => _discountedSubtotal + _cgst + _sgst + _igst;

  // ─── Coupon logic ─────────────────────────────────────────────────────────────
  void _applyCoupon(String code) {
    code = code.trim().toUpperCase();
    double discount = 0.0;
    String? successMsg;
    String? errorMsg;

    if (code == 'FARMER50') {
      discount = _subtotal * 0.5;
      successMsg = 'FARMER50 applied! 50% discount';
    } else if (code == 'WELCOME10') {
      discount = _subtotal * 0.1;
      successMsg = 'WELCOME10 applied! 10% discount';
    } else if (code == 'FREESHED') {
      discount = min(widget.flatDiscountAmount, _subtotal);
      successMsg = 'FREESHED applied! ${widget.flatDiscountText}';
    } else if (code == 'POULTRYOS') {
      discount = _subtotal * 0.2;
      successMsg = 'POULTRYOS applied! 20% discount';
    } else {
      errorMsg = 'Invalid coupon code';
    }

    setState(() {
      if (errorMsg != null) {
        _couponError = errorMsg;
        _couponSuccess = null;
        _appliedCoupon = null;
        _discountAmount = 0.0;
      } else {
        _couponError = null;
        _couponSuccess = successMsg;
        _appliedCoupon = code;
        _discountAmount = discount;
        _couponCtrl.text = code;
      }
    });
  }

  void _removeCoupon() => setState(() {
        _appliedCoupon = null;
        _discountAmount = 0.0;
        _couponCtrl.clear();
        _couponError = null;
        _couponSuccess = null;
      });

  // ─── Payment initiation ───────────────────────────────────────────────────────
  Future<void> _initPayment() async {
    if (_creatingOrder) return;
    setState(() => _creatingOrder = true);

    final result = await CashfreeService.createOrder(
      amount: _total,
      customerName: _farmerName,
      customerPhone: _mobile,
      customerEmail: _email,
    );

    if (!mounted) return;
    setState(() => _creatingOrder = false);

    if (result.success && result.paymentSessionId != null) {
      context.push('/recharge/payment', extra: {
        'orderId': result.orderId ?? _txnId,
        'paymentSessionId': result.paymentSessionId!,
        'isProduction': result.isProduction,
        'total': _total,
        'currencySymbol': widget.currencySymbol,
        'cart': widget.cart,
        'appliedCoupon': _appliedCoupon,
        'discountAmount': _discountAmount,
        'isInterstate': _isInterstate,
        'farmerName': _farmerName,
        'farmName': _farmName,
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Payment initiation failed: ${result.error ?? 'Unknown error'}'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ─── UI ───────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppTheme.grey800,
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Invoice & Checkout',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.grey800),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFarmerHeader(),
              const SizedBox(height: 16),
              _buildCartDetails(),
              const SizedBox(height: 16),
              _buildTaxToggle(),
              const SizedBox(height: 16),
              _buildCouponSection(),
              const SizedBox(height: 16),
              _buildInvoiceSummary(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ─── Farmer Header ────────────────────────────────────────────────────────────
  Widget _buildFarmerHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F3460), Color(0xFF16213E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    _farmerName.isNotEmpty ? _farmerName[0].toUpperCase() : 'F',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_farmerName,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.grey800)),
                    const SizedBox(height: 2),
                    Text(_farmName,
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.grey500)),
                    if (_mobile.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(_mobile,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.grey400)),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('TXN ID',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.grey400,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(
                    _txnId.replaceAll('TXN-POULTRY-', 'TXN\n'),
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.primaryRed,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 14, color: AppTheme.grey400),
              const SizedBox(width: 6),
              Text(
                'Invoice Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEEE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('DRAFT',
                    style: TextStyle(
                        color: AppTheme.primaryRed,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Cart Details ─────────────────────────────────────────────────────────────
  Widget _buildCartDetails() {
    final moduleIcons = {
      'Broiler': Icons.cruelty_free_outlined,
      'Layer': Icons.egg_outlined,
      'Breeder': Icons.egg_alt_outlined
    };
    final moduleColors = {
      'Broiler': Colors.orange,
      'Layer': Colors.amber,
      'Breeder': Colors.redAccent
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.shopping_bag_outlined,
                size: 18, color: AppTheme.primaryRed),
            const SizedBox(width: 8),
            const Text('Order Items',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.grey800)),
          ]),
          const Divider(height: 16),
          ...widget.cart.map((item) {
            final icon = moduleIcons[item.module] ?? Icons.layers;
            final color = moduleColors[item.module] ?? AppTheme.primaryRed;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${item.module} Module License',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(
                            '${item.count} Batches × ${widget.currencySymbol}${item.pricePerBatch.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.grey500)),
                      ],
                    ),
                  ),
                  Text(
                    '${widget.currencySymbol}${item.subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Tax Toggle ───────────────────────────────────────────────────────────────
  Widget _buildTaxToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        title: const Text('Inter-state Purchase',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: const Text(
            'Toggle for IGST (18%) instead of CGST + SGST (9% + 9%)',
            style: TextStyle(fontSize: 11)),
        value: _isInterstate,
        activeColor: AppTheme.primaryRed,
        onChanged: (v) => setState(() => _isInterstate = v),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEEEE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.account_balance_outlined,
              color: AppTheme.primaryRed, size: 20),
        ),
      ),
    );
  }

  // ─── Coupon Section ───────────────────────────────────────────────────────────
  Widget _buildCouponSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.local_offer_outlined,
                size: 18, color: AppTheme.primaryRed),
            const SizedBox(width: 8),
            const Text('Offers & Coupons',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.grey800)),
          ]),
          const SizedBox(height: 14),
          // Manual entry
          Row(children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: TextField(
                  controller: _couponCtrl,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1),
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Enter coupon code',
                    hintStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                        letterSpacing: 0),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                    prefixIcon: const Icon(Icons.confirmation_number_outlined,
                        size: 18, color: AppTheme.grey400),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: AppTheme.grey200),
                        borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                        borderSide:
                            const BorderSide(color: AppTheme.primaryRed),
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: () => _appliedCoupon != null
                    ? _removeCoupon()
                    : _applyCoupon(_couponCtrl.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _appliedCoupon != null
                      ? AppTheme.grey700
                      : AppTheme.primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: Text(
                  _appliedCoupon != null ? 'Remove' : 'Apply',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ]),
          if (_couponError != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.error_outline, size: 14, color: AppTheme.error),
              const SizedBox(width: 4),
              Text(_couponError!,
                  style: const TextStyle(
                      color: AppTheme.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ],
          if (_couponSuccess != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.check_circle_outline,
                  size: 14, color: AppTheme.successDark),
              const SizedBox(width: 4),
              Text(_couponSuccess!,
                  style: const TextStyle(
                      color: AppTheme.successDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ],
          const SizedBox(height: 14),
          // Coupon cards (horizontal scroll)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildCouponChip(
                    'FARMER50', '50% OFF', 'Save 50% on all licenses'),
                _buildCouponChip(
                    'FREESHED',
                    '${widget.currencySymbol}${widget.flatDiscountAmount.toStringAsFixed(0)} OFF',
                    widget.flatDiscountText),
                _buildCouponChip(
                    'POULTRYOS', '20% OFF', 'Flat 20% on total cost'),
                _buildCouponChip(
                    'WELCOME10', '10% OFF', 'Flat 10% for first recharge'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponChip(String code, String label, String desc) {
    final isSelected = _appliedCoupon == code;
    return GestureDetector(
      onTap: () => _applyCoupon(code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 160,
        margin: const EdgeInsets.only(right: 10, top: 4, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryRed.withValues(alpha: 0.06)
              : const Color(0xFFFAFAFA),
          border: Border.all(
            color: isSelected ? AppTheme.primaryRed : AppTheme.grey200,
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.card_giftcard_rounded,
                  size: 13,
                  color: isSelected ? AppTheme.primaryRed : AppTheme.grey500),
              const SizedBox(width: 4),
              Text(code,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color:
                          isSelected ? AppTheme.primaryRed : AppTheme.grey700)),
            ]),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color:
                        isSelected ? AppTheme.primaryRed : AppTheme.grey800)),
            const SizedBox(height: 2),
            Text(desc,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: AppTheme.grey400)),
          ],
        ),
      ),
    );
  }

  // ─── Invoice Summary ──────────────────────────────────────────────────────────
  Widget _buildInvoiceSummary() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF0F3460)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF0F3460).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.receipt_long_rounded, color: Colors.white70, size: 18),
            SizedBox(width: 8),
            Text('Price Breakdown',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ]),
          const SizedBox(height: 16),
          // Cart items
          ...widget.cart.map((item) => _darkRow(
                '${item.module} (${item.count} Batches)',
                '${widget.currencySymbol}${item.subtotal.toStringAsFixed(2)}',
              )),
          const Divider(color: Colors.white12, height: 20),
          _darkRow('Subtotal',
              '${widget.currencySymbol}${_subtotal.toStringAsFixed(2)}'),
          if (_appliedCoupon != null)
            _darkRow(
              'Coupon ($_appliedCoupon)',
              '-${widget.currencySymbol}${_discountAmount.toStringAsFixed(2)}',
              highlight: const Color(0xFF4ADE80),
            ),
          // Tax
          AnimatedOpacity(
            opacity: _isInterstate ? 0.3 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: _darkRow('CGST (9%)',
                '${widget.currencySymbol}${_cgst.toStringAsFixed(2)}'),
          ),
          AnimatedOpacity(
            opacity: _isInterstate ? 0.3 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: _darkRow('SGST (9%)',
                '${widget.currencySymbol}${_sgst.toStringAsFixed(2)}'),
          ),
          AnimatedOpacity(
            opacity: _isInterstate ? 1.0 : 0.3,
            duration: const Duration(milliseconds: 200),
            child: _darkRow('IGST (18%)',
                '${widget.currencySymbol}${_igst.toStringAsFixed(2)}'),
          ),
          const Divider(color: Colors.white12, height: 20),
          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Amount',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  '${widget.currencySymbol}${_total.toStringAsFixed(2)}',
                  key: ValueKey(_total.toStringAsFixed(2)),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20),
                ),
              ),
            ],
          ),
          if (_appliedCoupon != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF4ADE80).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF4ADE80).withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.savings_outlined,
                    color: Color(0xFF4ADE80), size: 14),
                const SizedBox(width: 6),
                Text(
                  'You save ${widget.currencySymbol}${_discountAmount.toStringAsFixed(2)} with $_appliedCoupon!',
                  style: const TextStyle(
                      color: Color(0xFF4ADE80),
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _darkRow(String label, String value, {Color? highlight}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
          Text(value,
              style: TextStyle(
                  color: highlight ?? Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ─── Bottom Bar ───────────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Payable',
                    style: TextStyle(fontSize: 13, color: AppTheme.grey500)),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    '${widget.currencySymbol}${_total.toStringAsFixed(2)}',
                    key: ValueKey(_total.toStringAsFixed(2)),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryRed),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _creatingOrder ? null : _initPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryRed,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppTheme.primaryRed.withValues(alpha: 0.6),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 3,
                ),
                child: _creatingOrder
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2)),
                          SizedBox(width: 10),
                          Text('Creating Order...',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_outlined, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Pay ${widget.currencySymbol}${_total.toStringAsFixed(2)} via Cashfree',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.security_rounded, size: 12, color: AppTheme.grey400),
                SizedBox(width: 4),
                Text('Secured by Cashfree Payments',
                    style: TextStyle(fontSize: 11, color: AppTheme.grey400)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
