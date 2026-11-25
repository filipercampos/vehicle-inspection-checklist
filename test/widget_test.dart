import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vehicle_inspection/app.dart';
import 'package:vehicle_inspection/data/inspection_repository.dart';
import 'package:vehicle_inspection/domain/models.dart';
import 'package:vehicle_inspection/state/providers.dart';
import 'package:vehicle_inspection/ui/car3d/vehicle_part_map.dart';
import 'package:vehicle_inspection/ui/theme.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  Future<void> pumpApp(WidgetTester tester, {double height = 2400}) async {
    tester.view.physicalSize = Size(1000, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          useGoogleFontsProvider.overrideWithValue(false),
          repositoryProvider.overrideWithValue(
            InMemoryInspectionRepository(latency: Duration.zero),
          ),
        ],
        child: const InspectionApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openDrawer(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(const Key('menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  /// Signs in (landing on Home) and opens the fleet list.
  Future<void> signIn(WidgetTester tester) async {
    await tester.tap(find.text('Ana Souza'));
    await tester.pumpAndSettle();
    await openDrawer(tester, 'drawer-1');
  }

  testWidgets('sign in lands on the home dashboard', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Ana Souza'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Home'), findsOneWidget);
  });

  testWidgets('unauthenticated user is redirected to login', (tester) async {
    await pumpApp(tester);
    expect(find.text('Sign in as'), findsOneWidget);
  });

  testWidgets('sign in shows the fleet with seeded statuses', (tester) async {
    await pumpApp(tester);
    await signIn(tester);
    expect(find.text('Fleet'), findsWidgets);
    expect(find.text('RTA-4F21'), findsOneWidget);
    expect(find.text('Blocked'), findsOneWidget);
  });

  Future<void> openInspection(WidgetTester tester) async {
    await signIn(tester);
    await tester.tap(find.text('SBK-1C77'));
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('wizard-next')));
    await tester.pumpAndSettle();
  }

  Future<void> fillReadings(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Use last reading'));
    await tester.tap(find.text('1/2'));
    await tester.pumpAndSettle();
  }

  String stepTitle(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('step-title'))).data!;

  testWidgets('wizard does not advance past an invalid step', (tester) async {
    await pumpApp(tester);
    await openInspection(tester);
    expect(stepTitle(tester), 'Step 1 of 9 · Vehicle');

    await next(tester);
    expect(find.text('Odometer reading is required'), findsOneWidget);
    expect(stepTitle(tester), 'Step 1 of 9 · Vehicle');

    await fillReadings(tester);
    await next(tester);
    expect(stepTitle(tester), 'Step 2 of 9 · Body');
    await next(tester);
    expect(stepTitle(tester), 'Step 3 of 9 · Exterior');

    // An unanswered section blocks the next step and highlights the items.
    await next(tester);
    expect(find.text('4 item(s) not answered'), findsOneWidget);
    expect(stepTitle(tester), 'Step 3 of 9 · Exterior');

    await tester.tap(find.byKey(const Key('wizard-back')));
    await tester.pumpAndSettle();
    expect(stepTitle(tester), 'Step 2 of 9 · Body');
  });

  testWidgets('"All OK" answers every item of a section', (tester) async {
    await pumpApp(tester);
    await openInspection(tester);
    await fillReadings(tester);
    await next(tester);
    await next(tester);

    await tester.tap(find.byKey(const Key('all-ok')));
    await tester.pumpAndSettle();
    expect(find.text('4/4 answered'), findsOneWidget);
  });

  testWidgets('complete inspection is submitted and opens the report', (
    tester,
  ) async {
    await pumpApp(tester);
    await openInspection(tester);
    await fillReadings(tester);
    await next(tester);
    await next(tester);
    while (find.byKey(const Key('wizard-next')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('all-ok')));
      await tester.pumpAndSettle();
      await next(tester);
    }
    expect(stepTitle(tester), 'Step 9 of 9 · Review');

    // Submitting unsigned shows the remaining error.
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();
    expect(find.text('• Inspector signature is required'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('signature-pad')),
      const Offset(120, 30),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();

    expect(find.text('Report INS-1004'), findsOneWidget);
    expect(find.text('Approved'), findsOneWidget);

    // The finished report offers a way back to the fleet.
    await tester.tap(find.byKey(const Key('report-done')));
    await tester.pumpAndSettle();
    expect(find.text('Fleet'), findsWidgets);
    expect(find.byKey(const Key('report-done')), findsNothing);
  });

  testWidgets('tapping the 3D SUV records body damage and restricts verdict', (
    tester,
  ) async {
    // Real file I/O: load the part map outside the fake-async zone.
    await tester.runAsync(() => VehiclePartMap.load(VehicleType.suv));
    await pumpApp(tester);
    await openInspection(tester);
    await fillReadings(tester);
    await next(tester);

    // The centre of the default 3/4 view always lands on a body part.
    await tester.tap(find.byKey(const Key('vehicle-viewer')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dent'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-damage')));
    await tester.pumpAndSettle();

    expect(find.text('1 part(s) damaged'), findsOneWidget);
    expect(find.textContaining('· Dent'), findsOneWidget);

    // Jump to the review through the sections.
    await next(tester);
    while (find.byKey(const Key('wizard-next')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('all-ok')));
      await tester.pumpAndSettle();
      await next(tester);
    }
    expect(find.text('Approved with restrictions'), findsOneWidget);
  });

  testWidgets('drawer navigates; settings page switches language and theme', (
    tester,
  ) async {
    await pumpApp(tester);
    await signIn(tester);
    expect(find.byType(NavigationBar), findsNothing);

    Future<void> openDrawer() async {
      await tester.tap(find.byKey(const Key('menu-button')));
      await tester.pumpAndSettle();
    }

    await openDrawer();
    await tester.tap(find.byKey(const Key('drawer-2')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'History'), findsOneWidget);

    await openDrawer();
    await tester.tap(find.byKey(const Key('drawer-settings')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);

    await tester.tap(find.byKey(const Key('language-pt')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Configurações'), findsOneWidget);

    BuildContext ctx() => tester.element(find.text('Idioma'));
    expect(Theme.of(ctx()).brightness, Brightness.dark);
    await tester.tap(find.byKey(const Key('dark-theme')));
    await tester.pumpAndSettle();
    expect(Theme.of(ctx()).brightness, Brightness.light);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Histórico'), findsOneWidget);

    await openDrawer();
    await tester.tap(find.byKey(const Key('sign-out')));
    await tester.pumpAndSettle();
    expect(find.text('Entrar como'), findsOneWidget);
  });

  testWidgets('theme toggle switches between dark and light', (tester) async {
    await pumpApp(tester);
    BuildContext ctx() => tester.element(find.text('Sign in as'));
    expect(Theme.of(ctx()).brightness, Brightness.dark);
    await tester.tap(find.byTooltip('Light theme'));
    await tester.pumpAndSettle();
    expect(Theme.of(ctx()).brightness, Brightness.light);
  });
}
