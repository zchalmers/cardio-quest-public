import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme.dart';
import 'screens/menu_screen.dart';
import 'services/achievement_service.dart';
import 'services/audio_engine.dart';
import 'services/challenge_service.dart';
import 'services/cosmetics_service.dart';
import 'services/fitness_export_service.dart';
import 'services/machine_service.dart';
import 'services/player_profile.dart';
import 'services/voice_coach.dart';
import 'services/wearable_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  try {
    await Future.wait(<Future<void>>[
      PlayerProfile.instance.initialize(),
      AchievementService.instance.initialize(),
      CosmeticsService.instance.initialize(),
      ChallengeService.instance.initialize(),
    ]);
    await AchievementService.instance.checkAchievements(PlayerProfile.instance);
    await CosmeticsService.instance.syncUnlocks(
      PlayerProfile.instance,
      AchievementService.instance,
      announce: false,
    );
  } on Object catch (error, stackTrace) {
    // A storage/plugin failure must not strand the process on the launch
    // storyboard. The services can recover with their in-memory defaults.
    debugPrint('Persistent state could not be restored: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
  runApp(const CardioQuestApp());
}

class CardioQuestApp extends StatefulWidget {
  const CardioQuestApp({super.key});

  @override
  State<CardioQuestApp> createState() => _CardioQuestAppState();
}

class _CardioQuestAppState extends State<CardioQuestApp> {
  late final WearableService _wearableService;
  late final MachineService _machineService;
  late final FitnessExportService _fitnessExportService;

  @override
  void initState() {
    super.initState();
    _wearableService = WearableService();
    _machineService = MachineService(wearableService: _wearableService);
    _fitnessExportService = FitnessExportService();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      unawaited(_initializeBackgroundServices());
    });
  }

  Future<void> _initializeBackgroundServices() async {
    await _runOptionalInitializer(_wearableService.startMonitoring);
    await _runOptionalInitializer(_fitnessExportService.initialize);
    await _runOptionalInitializer(_initializeAudio);
  }

  Future<void> _runOptionalInitializer(
    Future<Object?> Function() initializer,
  ) async {
    try {
      await initializer();
    } on Object catch (error, stackTrace) {
      debugPrint('An optional background service is unavailable: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _initializeAudio() async {
    await AudioEngine.instance.initialize();
    await VoiceCoach.instance.initialize();
  }

  @override
  void dispose() {
    unawaited(_shutdownAudio());
    _machineService.dispose();
    _wearableService.dispose();
    _fitnessExportService.dispose();
    super.dispose();
  }

  Future<void> _shutdownAudio() async {
    await VoiceCoach.instance.shutdown();
    await AudioEngine.instance.shutdown();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cardio Quest',
      debugShowCheckedModeBanner: false,
      theme: CardioQuestTheme.dark,
      home: MenuScreen(
        machineService: _machineService,
        fitnessExportService: _fitnessExportService,
      ),
    );
  }
}
