import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:social_world_mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('register, login, load and update profile, then sign out', (
    tester,
  ) async {
    final uniqueId = DateTime.now().microsecondsSinceEpoch;
    final email = 'mobile-smoke-$uniqueId@example.test';
    const password = 'LocalSmokePassword-21!';
    const initialName = 'Mobile Smoke';
    const updatedName = 'Mobile Profile Updated';

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 1));

    await tester.tap(find.text('Создать аккаунт').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Как к вам обращаться'),
      initialName,
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Пароль'),
      password,
    );
    await tester.ensureVisible(find.text('Создать аккаунт').last);
    await tester.tap(find.text('Создать аккаунт').last);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(
      find.text('Рады видеть,\n$initialName'),
      findsOneWidget,
      reason:
          'Registration did not reach home. ${_snackBarMessage(tester)} Visible labels: ${_visibleLabels(tester, email, password)}',
    );

    await tester.tap(find.byTooltip('Профиль'));
    await tester.pumpAndSettle();
    expect(find.text(email), findsOneWidget);
    await tester.tap(find.text('Выйти из аккаунта'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('У меня уже есть аккаунт'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Пароль'),
      password,
    );
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Рады видеть,\n$initialName'), findsOneWidget);

    await tester.tap(find.byTooltip('Профиль'));
    await tester.pumpAndSettle();
    final nameField = find.byType(TextFormField).last;
    await tester.enterText(nameField, updatedName);
    await tester.tap(find.text('Сохранить изменения'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Имя профиля обновлено'), findsOneWidget);

    await tester.tap(find.text('Выйти из аккаунта'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Ближе к своим.'), findsOneWidget);
  });
}

String _snackBarMessage(WidgetTester tester) {
  final snackBars = tester.widgetList<SnackBar>(find.byType(SnackBar));
  if (snackBars.isEmpty) return 'No error message was shown.';
  final content = snackBars.last.content;
  return content is Text
      ? 'Visible message: ${content.data}'
      : 'An error was shown.';
}

String _visibleLabels(WidgetTester tester, String email, String password) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data ?? '')
      .where(
        (label) =>
            label.isNotEmpty &&
            !label.contains(email) &&
            !label.contains(password),
      )
      .join(' | ');
}
