import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poultryos_farmer_app/main.dart';

void main() {
  testWidgets('PoultryOS Farmer App builds', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: PoultryOSFarmerApp()));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
