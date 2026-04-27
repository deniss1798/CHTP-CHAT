import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/app/widgets/app_avatar.dart';
import 'package:mobile_app/app/widgets/app_button.dart';
import 'package:mobile_app/app/widgets/app_text_field.dart';

void main() {
  group('AppAvatar', () {
    test('builds initials from title', () {
      expect(const AppAvatar(title: 'Code Green').initials, 'CG');
      expect(const AppAvatar(title: 'Messenger').initials, 'M');
      expect(const AppAvatar(title: '   ').initials, '?');
    });
  });

  group('AppButton', () {
    testWidgets('shows loading indicator instead of icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              label: 'Отправить',
              isLoading: true,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Отправить'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('AppSearchField', () {
    testWidgets('clears text with suffix action', (tester) async {
      final controller = TextEditingController(text: 'alice');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSearchField(
              controller: controller,
              hintText: 'Поиск',
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Очистить'));
      await tester.pump();

      expect(controller.text, isEmpty);
    });
  });
}
