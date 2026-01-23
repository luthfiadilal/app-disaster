// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_disaster_gis/main.dart';
import 'package:app_disaster_gis/providers/auth_provider.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Create a mock AuthProvider for testing
    final authProvider = AuthProvider();

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(authProvider: authProvider));

    // Verify that the app loads (looking for ZONARA text in AppBar)
    expect(find.text('ZONARA'), findsOneWidget);
  });
}
