import 'package:cardio_quest/game/cardio_quest_game.dart';
import 'package:cardio_quest/models/machine_models.dart';
import 'package:cardio_quest/services/machine_service.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('simulator drives and renders the complete Flame scene', (
    WidgetTester tester,
  ) async {
    final MachineService service = MachineService.withoutBluetooth();
    await service.enableSimulator();
    service
      ..setFallbackSpeed(9.5)
      ..setFallbackIncline(6)
      ..beginWorkout();
    final CardioQuestGame game = CardioQuestGame(
      machineService: service,
      onComplete: (GameSummary summary) {},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 800,
              height: 450,
              child: GameWidget<CardioQuestGame>(game: game),
            ),
          ),
        ),
      ),
    );
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
    expect(game.player.isLoaded, isTrue);
    expect(game.motionMode, MotionMode.sprint);
    expect(game.distanceMeters, greaterThan(1));

    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
  });
}
