import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_app/app/app.dart';

void main() {
  testWidgets('MessengerApp builds', (WidgetTester tester) async {
    await tester.pumpWidget(const MessengerApp());
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);

    // SplashScreen: Future.delayed(500ms) before auth check.
    await tester.pump(const Duration(milliseconds: 501));
    await tester.pump();
    // Navigation / async work after token read.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
  });
}
