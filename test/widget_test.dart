import 'package:flutter_test/flutter_test.dart';

import 'package:connect_app/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CorporateConnectApp());

    // Verify that the app loads with the expected title.
    expect(find.text('Corporate Connect'), findsOneWidget);
  });
}
