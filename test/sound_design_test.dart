import 'dart:convert';

import 'package:cardio_quest/models/machine_models.dart';
import 'package:cardio_quest/services/sound_design.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('renders every procedural effect as an in-memory WAV', () {
    final SoundDesign design = SoundDesign.instance;
    final List<List<int>> sounds = <List<int>>[
      for (final MotionMode mode in MotionMode.values)
        design.renderFootstep(mode),
      design.renderCoinPickup(),
      design.renderJump(),
      design.renderObstacleHit(shielded: false),
      design.renderObstacleHit(shielded: true),
      for (final PowerUpType type in PowerUpType.values)
        design.renderPowerUp(type),
      design.renderSpeedTransition(speedingUp: true),
      design.renderSpeedTransition(speedingUp: false),
      for (final int milestone in <int>[2, 3, 5, 10])
        design.renderComboMilestone(milestone),
      for (final HeartRateZone zone in HeartRateZone.values)
        design.renderZoneTransition(zone),
      for (final MusicLayer layer in MusicLayer.values)
        design.renderMusicLayer(layer),
    ];

    for (final List<int> sound in sounds) {
      expect(sound.length, greaterThan(44));
      expect(ascii.decode(sound.sublist(0, 4)), 'RIFF');
      expect(ascii.decode(sound.sublist(8, 12)), 'WAVE');
      expect(ascii.decode(sound.sublist(36, 40)), 'data');
    }
  });
}
