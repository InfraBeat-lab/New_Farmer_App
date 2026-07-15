// lib/features/recharge/models/recharge_models.dart
// Shared models used across the recharge flow screens.

class CartItem {
  final String module;
  int count;
  final double pricePerBatch;

  CartItem({
    required this.module,
    required this.count,
    this.pricePerBatch = 500.0,
  });

  double get subtotal => count * pricePerBatch;

  CartItem copyWith({int? count}) => CartItem(
        module: module,
        count: count ?? this.count,
        pricePerBatch: pricePerBatch,
      );
}

class CountryPurchaseConfig {
  final String symbol;
  final double pricePerBatch;
  final double flatDiscount;
  final String flatDiscountText;

  const CountryPurchaseConfig({
    required this.symbol,
    required this.pricePerBatch,
    required this.flatDiscount,
    required this.flatDiscountText,
  });
}

const Map<String, CountryPurchaseConfig> countryPurchaseConfigs = {
  'India': CountryPurchaseConfig(
      symbol: '₹',
      pricePerBatch: 500.0,
      flatDiscount: 500.0,
      flatDiscountText: 'Flat ₹500 discount'),
  'United States': CountryPurchaseConfig(
      symbol: '\$',
      pricePerBatch: 10.0,
      flatDiscount: 10.0,
      flatDiscountText: 'Flat \$10 discount'),
  'United Kingdom': CountryPurchaseConfig(
      symbol: '£',
      pricePerBatch: 8.0,
      flatDiscount: 8.0,
      flatDiscountText: 'Flat £8 discount'),
  'Australia': CountryPurchaseConfig(
      symbol: 'A\$',
      pricePerBatch: 15.0,
      flatDiscount: 15.0,
      flatDiscountText: 'Flat A\$15 discount'),
  'Canada': CountryPurchaseConfig(
      symbol: 'C\$',
      pricePerBatch: 15.0,
      flatDiscount: 15.0,
      flatDiscountText: 'Flat C\$15 discount'),
  'Germany': CountryPurchaseConfig(
      symbol: '€',
      pricePerBatch: 10.0,
      flatDiscount: 10.0,
      flatDiscountText: 'Flat €10 discount'),
  'France': CountryPurchaseConfig(
      symbol: '€',
      pricePerBatch: 10.0,
      flatDiscount: 10.0,
      flatDiscountText: 'Flat €10 discount'),
  'Japan': CountryPurchaseConfig(
      symbol: '¥',
      pricePerBatch: 1500.0,
      flatDiscount: 1500.0,
      flatDiscountText: 'Flat ¥1500 discount'),
  'China': CountryPurchaseConfig(
      symbol: '¥',
      pricePerBatch: 70.0,
      flatDiscount: 70.0,
      flatDiscountText: 'Flat ¥70 discount'),
  'UAE': CountryPurchaseConfig(
      symbol: 'AED ',
      pricePerBatch: 40.0,
      flatDiscount: 40.0,
      flatDiscountText: 'Flat AED 40 discount'),
  'Saudi Arabia': CountryPurchaseConfig(
      symbol: 'SAR ',
      pricePerBatch: 40.0,
      flatDiscount: 40.0,
      flatDiscountText: 'Flat SAR 40 discount'),
  'Singapore': CountryPurchaseConfig(
      symbol: 'S\$',
      pricePerBatch: 15.0,
      flatDiscount: 15.0,
      flatDiscountText: 'Flat S\$15 discount'),
  'South Africa': CountryPurchaseConfig(
      symbol: 'R',
      pricePerBatch: 180.0,
      flatDiscount: 180.0,
      flatDiscountText: 'Flat R 180 discount'),
  'Brazil': CountryPurchaseConfig(
      symbol: 'R\$',
      pricePerBatch: 50.0,
      flatDiscount: 50.0,
      flatDiscountText: 'Flat R\$50 discount'),
  'Mexico': CountryPurchaseConfig(
      symbol: 'Mex\$',
      pricePerBatch: 180.0,
      flatDiscount: 180.0,
      flatDiscountText: 'Flat Mex\$180 discount'),
};
