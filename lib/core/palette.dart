import 'package:flutter/material.dart';

@immutable
class RunPalette {
  const RunPalette({
    required this.skyTop,
    required this.skyBottom,
    required this.sun,
    required this.mountainFar,
    required this.mountainNear,
    required this.trees,
    required this.ground,
    required this.groundEdge,
    required this.foreground,
    required this.accent,
    required this.accentWarm,
  });

  final Color skyTop;
  final Color skyBottom;
  final Color sun;
  final Color mountainFar;
  final Color mountainNear;
  final Color trees;
  final Color ground;
  final Color groundEdge;
  final Color foreground;
  final Color accent;
  final Color accentWarm;

  static const RunPalette calm = RunPalette(
    skyTop: Color(0xFF081B35),
    skyBottom: Color(0xFF214B5E),
    sun: Color(0xFFFFDC9A),
    mountainFar: Color(0xFF385A67),
    mountainNear: Color(0xFF244756),
    trees: Color(0xFF14373E),
    ground: Color(0xFF18382F),
    groundEdge: Color(0xFF77C58D),
    foreground: Color(0xFF0A211D),
    accent: Color(0xFF65F2D0),
    accentWarm: Color(0xFFFFD166),
  );

  static const RunPalette intense = RunPalette(
    skyTop: Color(0xFF28103E),
    skyBottom: Color(0xFFB3475B),
    sun: Color(0xFFFFE29D),
    mountainFar: Color(0xFF824C68),
    mountainNear: Color(0xFF53344F),
    trees: Color(0xFF29243F),
    ground: Color(0xFF272A36),
    groundEdge: Color(0xFFFF8A5B),
    foreground: Color(0xFF141522),
    accent: Color(0xFFFF5C8A),
    accentWarm: Color(0xFFFFD166),
  );

  static RunPalette forSpeed(double normalizedSpeed) {
    final double t = Curves.easeInOutCubic.transform(
      normalizedSpeed.clamp(0, 1).toDouble(),
    );
    return RunPalette(
      skyTop: Color.lerp(calm.skyTop, intense.skyTop, t)!,
      skyBottom: Color.lerp(calm.skyBottom, intense.skyBottom, t)!,
      sun: Color.lerp(calm.sun, intense.sun, t)!,
      mountainFar: Color.lerp(calm.mountainFar, intense.mountainFar, t)!,
      mountainNear: Color.lerp(calm.mountainNear, intense.mountainNear, t)!,
      trees: Color.lerp(calm.trees, intense.trees, t)!,
      ground: Color.lerp(calm.ground, intense.ground, t)!,
      groundEdge: Color.lerp(calm.groundEdge, intense.groundEdge, t)!,
      foreground: Color.lerp(calm.foreground, intense.foreground, t)!,
      accent: Color.lerp(calm.accent, intense.accent, t)!,
      accentWarm: Color.lerp(calm.accentWarm, intense.accentWarm, t)!,
    );
  }
}

abstract final class AppColors {
  static const Color ink = Color(0xFF07131F);
  static const Color panel = Color(0xE6102231);
  static const Color panelLight = Color(0xFF173044);
  static const Color mint = Color(0xFF65F2D0);
  static const Color coral = Color(0xFFFF6B7A);
  static const Color gold = Color(0xFFFFD166);
  static const Color lavender = Color(0xFFB8A1FF);
  static const Color text = Color(0xFFF6FAFC);
  static const Color textMuted = Color(0xFFA9BAC8);
  static const Color success = Color(0xFF70E49A);
  static const Color warning = Color(0xFFFFB55E);
  static const Color danger = Color(0xFFFF5572);
}
