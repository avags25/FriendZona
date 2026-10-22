import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:social_world_mobile/src/map/map_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'OpenFreeMap style loads in MapLibre and camera controls are available',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: MapPage())),
      );

      expect(find.byType(MapLibreMap), findsOneWidget);
      expect(find.text('Загружаем карту…'), findsOneWidget);

      final deadline = DateTime.now().add(const Duration(seconds: 40));
      while (find.text('Загружаем карту…').evaluate().isNotEmpty &&
          find.text('Не удалось загрузить карту').evaluate().isEmpty &&
          DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 250));
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }

      expect(
        find.text('Загружаем карту…'),
        findsNothing,
        reason: 'MapLibre must complete loading or show the retry state.',
      );
      expect(find.text('Не удалось загрузить карту'), findsNothing);
      expect(find.byTooltip('Вернуться к стартовой области'), findsOneWidget);
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);

      await tester.tap(find.byTooltip('Вернуться к стартовой области'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.drag(find.byType(MapLibreMap), const Offset(80, 45));
      await tester.pump(const Duration(milliseconds: 500));
      final mapCenter = tester.getRect(find.byType(MapLibreMap)).center;
      final firstPointer = await tester.startGesture(
        mapCenter - const Offset(30, 0),
        pointer: 1,
      );
      final secondPointer = await tester.startGesture(
        mapCenter + const Offset(30, 0),
        pointer: 2,
      );
      await firstPointer.moveBy(const Offset(-15, 0));
      await secondPointer.moveBy(const Offset(15, 0));
      await tester.pump(const Duration(milliseconds: 500));
      await firstPointer.up();
      await secondPointer.up();

      await tester.tap(find.byTooltip('Моё местоположение'));
      await tester.pumpAndSettle();
      expect(find.text('Перейти к вашему местоположению?'), findsOneWidget);
      await tester.tap(find.text('Не сейчас'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
