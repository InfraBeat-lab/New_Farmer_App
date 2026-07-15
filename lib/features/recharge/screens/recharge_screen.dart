// lib/features/recharge/screens/recharge_screen.dart
// Screen 1 of the Recharge flow:
// - Shows current credit balance (Broiler / Layer / Breeder)
// - Module selector + stepper quantity input
// - Cart list with delete / edit support
// - CTA to Checkout screen

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poultryos_farmer_app/core/services/local_storage_service.dart';
import 'package:poultryos_farmer_app/core/theme/app_theme.dart';
import 'package:poultryos_farmer_app/features/recharge/models/recharge_models.dart';

class RechargeScreen extends StatefulWidget {
  const RechargeScreen({super.key});

  @override
  State<RechargeScreen> createState() => _RechargeScreenState();
}

class _RechargeScreenState extends State<RechargeScreen>
    with SingleTickerProviderStateMixin {
  // ─── Balances ────────────────────────────────────────────────────────────────
  late int _broilerBalance;
  late int _layerBalance;
  late int _breederBalance;

  // ─── Country / Pricing ───────────────────────────────────────────────────────
  late String _currencySymbol;
  late double _pricePerBatch;
  late double _flatDiscountAmount;
  late String _flatDiscountText;

  // ─── Selection state ─────────────────────────────────────────────────────────
  String _selectedModule = 'Broiler';
  int _quantity = 1;

  // ─── Cart ────────────────────────────────────────────────────────────────────
  final List<CartItem> _cart = [];

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

    _broilerBalance = LocalStorageService.getInt('broiler_balance') ?? 0;
    _layerBalance = LocalStorageService.getInt('layer_balance') ?? 0;
    _breederBalance = LocalStorageService.getInt('breeder_balance') ?? 0;

    final country = LocalStorageService.getString('country') ?? 'India';
    final config =
        countryPurchaseConfigs[country] ?? countryPurchaseConfigs['India']!;
    _currencySymbol = config.symbol;
    _pricePerBatch = config.pricePerBatch;
    _flatDiscountAmount = config.flatDiscount;
    _flatDiscountText = config.flatDiscountText;
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ─── Cart helpers ─────────────────────────────────────────────────────────────
  void _addToCart() {
    setState(() {
      final existing = _cart.indexWhere((c) => c.module == _selectedModule);
      if (existing != -1) {
        _cart[existing] = CartItem(
          module: _selectedModule,
          count: _cart[existing].count + _quantity,
          pricePerBatch: _pricePerBatch,
        );
      } else {
        _cart.add(CartItem(
          module: _selectedModule,
          count: _quantity,
          pricePerBatch: _pricePerBatch,
        ));
      }
      _quantity = 1;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$_selectedModule module added to cart!'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _removeFromCart(int index) {
    setState(() => _cart.removeAt(index));
  }

  void _updateQuantity(int index, int newCount) {
    if (newCount <= 0) {
      _removeFromCart(index);
      return;
    }
    setState(() {
      _cart[index] = CartItem(
        module: _cart[index].module,
        count: newCount,
        pricePerBatch: _pricePerBatch,
      );
    });
  }

  double get _cartSubtotal => _cart.fold(0.0, (s, i) => s + i.subtotal);

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
          'Recharge Credits',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.grey800),
        ),
        actions: [
          if (_cart.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart_outlined,
                        color: AppTheme.primaryRed),
                    onPressed: () => _scrollToCart(),
                  ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryRed,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${_cart.length}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBalanceCard(),
              const SizedBox(height: 20),
              _buildModuleSelector(),
              const SizedBox(height: 20),
              _buildCart(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _cart.isNotEmpty ? _buildBottomBar() : null,
    );
  }

  // ─── Balance Card ─────────────────────────────────────────────────────────────
  Widget _buildBalanceCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F3460).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet_outlined,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Credit Balance',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.greenAccent.withValues(alpha: 0.4)),
                ),
                child: const Text(
                  'Active',
                  style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                  child: _buildBalanceTile(
                      'Broiler', '$_broilerBalance', const Color(0xFFFF6B35))),
              _buildDivider(),
              Expanded(
                  child: _buildBalanceTile(
                      'Layer', '$_layerBalance', const Color(0xFFFFD700))),
              _buildDivider(),
              Expanded(
                  child: _buildBalanceTile(
                      'Breeder', '$_breederBalance', const Color(0xFFFF4757))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() =>
      Container(height: 40, width: 1, color: Colors.white12);

  Widget _buildBalanceTile(String title, String value, Color accentColor) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: accentColor, fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(title,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
      ],
    );
  }

  // ─── Module Selector ─────────────────────────────────────────────────────────
  Widget _buildModuleSelector() {
    final modules = ['Broiler', 'Layer', 'Breeder'];
    final icons = [
      Icons.egg_alt_outlined,
      Icons.egg_outlined,
      Icons.flutter_dash_outlined
    ];
    final colors = [Colors.orange, Colors.amber, Colors.redAccent];

    return Container(
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
          const Text('Select Module',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey800)),
          const SizedBox(height: 4),
          Text(
            '$_currencySymbol${_pricePerBatch.toStringAsFixed(0)} per batch',
            style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
          ),
          const SizedBox(height: 16),
          // Module chips
          Row(
            children: List.generate(modules.length, (i) {
              final isSelected = _selectedModule == modules[i];
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedModule = modules[i]),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin:
                        EdgeInsets.only(right: i < modules.length - 1 ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? AppTheme.primaryRed : AppTheme.grey100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isSelected ? AppTheme.primaryRed : AppTheme.grey200,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(icons[i],
                            size: 22,
                            color: isSelected ? Colors.white : colors[i]),
                        const SizedBox(height: 6),
                        Text(
                          modules[i],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : AppTheme.grey700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          // Quantity stepper
          Row(
            children: [
              const Expanded(
                  child: Text('Batch Count',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.grey700))),
              _buildStepper(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Subtotal: $_currencySymbol${(_quantity * _pricePerBatch).toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 13, color: AppTheme.grey500),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addToCart,
              icon: const Icon(Icons.add_shopping_cart_outlined),
              label: const Text('Add to Cart',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.grey200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _stepBtn(Icons.remove_rounded,
              () => setState(() => _quantity = max(1, _quantity - 1))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('$_quantity',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.grey800)),
          ),
          _stepBtn(Icons.add_rounded,
              () => setState(() => _quantity = min(100, _quantity + 1))),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.grey100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: AppTheme.grey700),
      ),
    );
  }

  // ─── Cart ─────────────────────────────────────────────────────────────────────
  final _cartKey = GlobalKey();

  void _scrollToCart() {
    final ctx = _cartKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    }
  }

  Widget _buildCart() {
    if (_cart.isEmpty) {
      return Container(
        key: _cartKey,
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
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            Icon(Icons.shopping_cart_outlined,
                size: 56, color: AppTheme.grey300),
            const SizedBox(height: 12),
            const Text('Your cart is empty',
                style: TextStyle(
                    fontSize: 15,
                    color: AppTheme.grey500,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            const Text('Select a module and add batches above',
                style: TextStyle(fontSize: 12, color: AppTheme.grey400)),
          ],
        ),
      );
    }

    return Container(
      key: _cartKey,
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
          Row(
            children: [
              const Icon(Icons.shopping_cart_rounded,
                  color: AppTheme.primaryRed, size: 20),
              const SizedBox(width: 8),
              Text(
                'Cart (${_cart.length} item${_cart.length > 1 ? 's' : ''})',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.grey800),
              ),
            ],
          ),
          const Divider(height: 20),
          ...List.generate(_cart.length, (i) => _buildCartItem(i)),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.grey700)),
              Text(
                '$_currencySymbol${_cartSubtotal.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryRed),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(int index) {
    final item = _cart[index];
    final moduleColors = {
      'Broiler': Colors.orange,
      'Layer': Colors.amber,
      'Breeder': Colors.redAccent
    };
    final color = moduleColors[item.module] ?? AppTheme.primaryRed;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.grey100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.layers_rounded, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item.module} Module',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.grey800)),
                Text(
                    '$_currencySymbol${_pricePerBatch.toStringAsFixed(0)} × ${item.count}',
                    style:
                        const TextStyle(fontSize: 12, color: AppTheme.grey500)),
              ],
            ),
          ),
          // Quantity controls
          Row(
            children: [
              _cartStepBtn(Icons.remove_rounded,
                  () => _updateQuantity(index, item.count - 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('${item.count}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
              ),
              _cartStepBtn(Icons.add_rounded,
                  () => _updateQuantity(index, item.count + 1)),
            ],
          ),
          const SizedBox(width: 10),
          Text(
            '$_currencySymbol${item.subtotal.toStringAsFixed(0)}',
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppTheme.grey800),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _removeFromCart(index),
            child: const Icon(Icons.delete_outline_rounded,
                size: 18, color: AppTheme.error),
          ),
        ],
      ),
    );
  }

  Widget _cartStepBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.grey300),
        ),
        child: Icon(icon, size: 14, color: AppTheme.grey700),
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
        child: ElevatedButton(
          onPressed: () => context.push('/recharge/checkout', extra: {
            'cart': _cart,
            'currencySymbol': _currencySymbol,
            'flatDiscountAmount': _flatDiscountAmount,
            'flatDiscountText': _flatDiscountText,
          }),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryRed,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 3,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.receipt_long_outlined),
              const SizedBox(width: 8),
              Text(
                'Proceed to Checkout  ·  $_currencySymbol${_cartSubtotal.toStringAsFixed(2)}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
