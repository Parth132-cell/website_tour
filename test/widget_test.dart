import 'package:dynamic_tour_engine/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('demo opens with first-time onboarding', (tester) async {
    await tester.pumpWidget(const FlowDeskApp());
    await tester.pumpAndSettle();

    expect(find.text('FlowDesk'), findsOneWidget);
    expect(find.text('Welcome to Dashboard tour'), findsOneWidget);
  });

  testWidgets('active tour tooltip has an Overlay ancestor', (tester) async {
    await tester.pumpWidget(const FlowDeskApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start tour'));
    await tester.pumpAndSettle();

    final closeButton = find.byTooltip('Close tour');
    expect(closeButton, findsOneWidget);
    expect(Overlay.maybeOf(tester.element(closeButton)), isNotNull);
    expect(tester.takeException(), isNull);
  });
}
