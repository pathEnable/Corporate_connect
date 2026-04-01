import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_app/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame inside a ProviderScope.
    await tester.pumpWidget(const ProviderScope(child: CorporateConnectApp()));

    // Verify that the app loads (it will show the Loading indicator first).
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
