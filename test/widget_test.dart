import 'package:cardio_quest/core/theme.dart';
import 'package:cardio_quest/screens/menu_screen.dart';
import 'package:cardio_quest/services/fitness_export_service.dart';
import 'package:cardio_quest/services/garmin_service.dart';
import 'package:cardio_quest/services/machine_service.dart';
import 'package:cardio_quest/services/strava_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('renders the Cardio Quest connection screen', (
    WidgetTester tester,
  ) async {
    final MachineService service = MachineService.withoutBluetooth();
    final FitnessExportService fitnessExportService = FitnessExportService(
      stravaService: StravaService(
        client: MockClient(
          (http.Request request) async => http.Response('{}', 200),
        ),
      ),
      garminService: GarminService(
        client: MockClient(
          (http.Request request) async => http.Response('{}', 200),
        ),
      ),
    );
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(service.dispose);
    addTearDown(fitnessExportService.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: CardioQuestTheme.dark,
        home: MenuScreen(
          machineService: service,
          fitnessExportService: fitnessExportService,
        ),
      ),
    );

    expect(find.text('CARDIO QUEST'), findsOneWidget);
    expect(find.textContaining('TURN YOUR'), findsOneWidget);
    expect(find.text('MULTIPLAYER RACE'), findsOneWidget);
  });
}
