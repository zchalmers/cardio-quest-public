import 'dart:async';

import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../services/fitness_export_models.dart';
import '../services/fitness_export_service.dart';
import '../services/sound_design.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.fitnessExportService, super.key});

  final FitnessExportService fitnessExportService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Set<FitnessPlatform> _busyPlatforms = <FitnessPlatform>{};
  late final Listenable _settingsListenable;
  bool _manualSyncRunning = false;

  @override
  void initState() {
    super.initState();
    _settingsListenable = Listenable.merge(<Listenable>[
      widget.fitnessExportService,
      SoundDesign.instance,
    ]);
    unawaited(widget.fitnessExportService.initialize());
    unawaited(SoundDesign.instance.initialize());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF07131F),
              Color(0xFF102B3A),
              Color(0xFF1C2038),
            ],
          ),
        ),
        child: AnimatedBuilder(
          animation: _settingsListenable,
          builder: (BuildContext context, Widget? child) {
            final FitnessExportService service = widget.fitnessExportService;
            if (!service.isInitialized) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.mint),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 36),
              children: <Widget>[
                _audioSettingsSection(),
                const SizedBox(height: 28),
                Text(
                  'Connected platforms',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Completed workouts upload automatically to every linked '
                  'account. Failed transfers stay on this device for retry.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 18),
                ...FitnessPlatform.values.map(
                  (FitnessPlatform platform) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _connectionCard(platform),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sharing privacy',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Card(
                  child: Column(
                    children: <Widget>[
                      SwitchListTile(
                        value: service.shareHeartRate,
                        onChanged: service.setShareHeartRate,
                        secondary: const Icon(
                          Icons.favorite_rounded,
                          color: AppColors.coral,
                        ),
                        title: const Text('Share heart-rate data'),
                        subtitle: const Text(
                          'Include sampled and summary heart rate in exports.',
                        ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        value: service.shareLocation,
                        onChanged: service.setShareLocation,
                        secondary: const Icon(
                          Icons.location_on_rounded,
                          color: AppColors.mint,
                        ),
                        title: const Text('Share location data'),
                        subtitle: const Text(
                          'Cardio Quest currently records indoor workouts '
                          'without GPS. This applies if routes are added.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _syncPanel(),
                const SizedBox(height: 20),
                Text(
                  'Export history',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                if (service.history.isEmpty)
                  const _EmptyHistory()
                else
                  ...service.history
                      .take(20)
                      .map(
                        (FitnessExportEntry entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _HistoryTile(entry: entry),
                        ),
                      ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _audioSettingsSection() {
    final SoundDesign sound = SoundDesign.instance;
    final bool coachEnabled = sound.voiceCoachEnabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Audio & coaching',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        const Text(
          'Every effect and music layer is synthesized on this device. '
          'Voice callouts automatically duck the adaptive score.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              children: <Widget>[
                const _AudioCardHeader(
                  icon: Icons.graphic_eq_rounded,
                  title: 'Volume mixer',
                  color: AppColors.mint,
                ),
                _volumeSlider(
                  label: 'Master',
                  value: sound.masterVolume,
                  onChanged: sound.setMasterVolume,
                ),
                _volumeSlider(
                  label: 'Music',
                  value: sound.musicVolume,
                  onChanged: sound.setMusicVolume,
                ),
                _volumeSlider(
                  label: 'Sound effects',
                  value: sound.sfxVolume,
                  onChanged: sound.setSfxVolume,
                ),
                _volumeSlider(
                  label: 'Voice',
                  value: sound.voiceVolume,
                  onChanged: sound.setVoiceVolume,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: <Widget>[
              SwitchListTile(
                value: coachEnabled,
                onChanged: sound.setVoiceCoachEnabled,
                secondary: const Icon(
                  Icons.record_voice_over_rounded,
                  color: AppColors.lavender,
                ),
                title: const Text('Voice coach'),
                subtitle: const Text(
                  'Zone, pace, interval, and milestone callouts.',
                ),
              ),
              if (coachEnabled) ...<Widget>[
                const Divider(height: 1),
                _pickerRow<CoachFrequency>(
                  label: 'Pace prompt frequency',
                  value: sound.coachFrequency,
                  values: CoachFrequency.values,
                  labelFor: (CoachFrequency value) => value.label,
                  onChanged: sound.setCoachFrequency,
                ),
                const Divider(height: 1),
                _pickerRow<IntervalWorkoutPreset>(
                  label: 'Interval workout',
                  value: sound.intervalPreset,
                  values: IntervalWorkoutPreset.values,
                  labelFor: (IntervalWorkoutPreset value) => value.label,
                  onChanged: sound.setIntervalPreset,
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Text(
                        'Coach voice',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<CoachVoiceGender>(
                        segments: CoachVoiceGender.values
                            .map(
                              (CoachVoiceGender gender) =>
                                  ButtonSegment<CoachVoiceGender>(
                                    value: gender,
                                    label: Text(gender.label),
                                    icon: Icon(
                                      gender == CoachVoiceGender.female
                                          ? Icons.face_3_rounded
                                          : Icons.face_rounded,
                                    ),
                                  ),
                            )
                            .toList(growable: false),
                        selected: <CoachVoiceGender>{sound.coachVoiceGender},
                        onSelectionChanged: (Set<CoachVoiceGender> selection) {
                          sound.setCoachVoiceGender(selection.first);
                        },
                      ),
                      const SizedBox(height: 8),
                      _voiceOptionSlider(
                        label: 'Pitch',
                        value: sound.coachPitch,
                        minimum: 0.7,
                        maximum: 1.3,
                        onChanged: sound.setCoachPitch,
                      ),
                      _voiceOptionSlider(
                        label: 'Speech speed',
                        value: sound.coachSpeechRate,
                        minimum: 0.3,
                        maximum: 0.7,
                        onChanged: sound.setCoachSpeechRate,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: <Widget>[
              SwitchListTile(
                value: sound.heartRateAlertsEnabled,
                onChanged: sound.setHeartRateAlertsEnabled,
                secondary: const Icon(
                  Icons.monitor_heart_rounded,
                  color: AppColors.coral,
                ),
                title: const Text('Heart-rate alerts'),
                subtitle: const Text(
                  'Warn when effort approaches your estimated maximum.',
                ),
              ),
              if (sound.heartRateAlertsEnabled) ...<Widget>[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Row(
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          'Alert threshold',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '${(sound.heartRateAlertThreshold * 100).round()}% max',
                        style: const TextStyle(
                          color: AppColors.coral,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                Slider(
                  value: sound.heartRateAlertThreshold,
                  min: 0.7,
                  max: 1,
                  divisions: 6,
                  label:
                      '${(sound.heartRateAlertThreshold * 100).round()}% max',
                  onChanged: sound.setHeartRateAlertThreshold,
                ),
                const SizedBox(height: 5),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _volumeSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            label: '${(value * 100).round()}%',
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 42,
          child: Text(
            '${(value * 100).round()}',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  Widget _voiceOptionSlider({
    required String label,
    required double value,
    required double minimum,
    required double maximum,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: <Widget>[
        SizedBox(width: 96, child: Text(label)),
        Expanded(
          child: Slider(
            value: value,
            min: minimum,
            max: maximum,
            divisions: 12,
            label: value.toStringAsFixed(2),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 42,
          child: Text(
            value.toStringAsFixed(2),
            textAlign: TextAlign.right,
            style: const TextStyle(color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }

  Widget _pickerRow<T>({
    required String label,
    required T value,
    required List<T> values,
    required String Function(T value) labelFor,
    required ValueChanged<T> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: values
                  .map(
                    (T option) => DropdownMenuItem<T>(
                      value: option,
                      child: Text(
                        labelFor(option),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (T? option) {
                if (option != null) {
                  onChanged(option);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _connectionCard(FitnessPlatform platform) {
    final FitnessExportService service = widget.fitnessExportService;
    final FitnessConnectionStatus status = service.connectionStatus(platform);
    final bool connected = service.isConnected(platform);
    final bool unavailable = status == FitnessConnectionStatus.unavailable;
    final bool busy =
        _busyPlatforms.contains(platform) ||
        status == FitnessConnectionStatus.connecting;
    final FitnessAccountProfile? profile = service.account(platform);
    final String? error = service.connectionError(platform);
    final _StatusVisual visual = _statusVisual(status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: visual.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_platformIcon(platform), color: visual.color),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _platformName(platform),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: <Widget>[
                          Icon(visual.icon, color: visual.color, size: 14),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              visual.label,
                              style: TextStyle(
                                color: visual.color,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.all(11),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  Switch(
                    value: connected,
                    onChanged: unavailable
                        ? null
                        : (bool value) => _setConnection(platform, value),
                  ),
              ],
            ),
            if (profile != null && connected) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.account_circle_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      profile.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
            if (platform == FitnessPlatform.garmin && unavailable) ...<Widget>[
              const SizedBox(height: 12),
              const Text(
                'Garmin activity upload is partner-gated. Add the OAuth and '
                'upload endpoints issued by Garmin to enable this switch.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
            if (error != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                error,
                style: const TextStyle(color: AppColors.coral, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _syncPanel() {
    final FitnessExportService service = widget.fitnessExportService;
    final DateTime? lastSync = service.lastSyncAt;
    final bool busy = _manualSyncRunning || service.isSyncing;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            const Icon(Icons.sync_rounded, color: AppColors.mint),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Workout sync',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    lastSync == null
                        ? 'Not synced yet • ${service.pendingCount} pending'
                        : 'Last sync ${_formatTimestamp(lastSync)} • '
                              '${service.pendingCount} pending',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: busy ? null : _manualSync,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded),
              label: const Text('SYNC NOW'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setConnection(FitnessPlatform platform, bool connect) async {
    setState(() => _busyPlatforms.add(platform));
    try {
      if (connect) {
        await widget.fitnessExportService.connect(platform);
      } else {
        await widget.fitnessExportService.disconnect(platform);
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
      }
    } finally {
      if (mounted) {
        setState(() => _busyPlatforms.remove(platform));
      }
    }
  }

  Future<void> _manualSync() async {
    setState(() => _manualSyncRunning = true);
    try {
      await widget.fitnessExportService.retryFailedUploads();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Fitness sync finished.')));
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
      }
    } finally {
      if (mounted) {
        setState(() => _manualSyncRunning = false);
      }
    }
  }

  _StatusVisual _statusVisual(FitnessConnectionStatus status) {
    return switch (status) {
      FitnessConnectionStatus.connected => const _StatusVisual(
        label: 'CONNECTED',
        color: AppColors.success,
        icon: Icons.check_circle_rounded,
      ),
      FitnessConnectionStatus.connecting => const _StatusVisual(
        label: 'CONNECTING',
        color: AppColors.gold,
        icon: Icons.pending_rounded,
      ),
      FitnessConnectionStatus.error => const _StatusVisual(
        label: 'CONNECTION ERROR',
        color: AppColors.coral,
        icon: Icons.error_rounded,
      ),
      FitnessConnectionStatus.unavailable => const _StatusVisual(
        label: 'SETUP REQUIRED',
        color: AppColors.warning,
        icon: Icons.info_rounded,
      ),
      FitnessConnectionStatus.disconnected => const _StatusVisual(
        label: 'DISCONNECTED',
        color: AppColors.textMuted,
        icon: Icons.link_off_rounded,
      ),
    };
  }

  IconData _platformIcon(FitnessPlatform platform) => switch (platform) {
    FitnessPlatform.strava => Icons.terrain_rounded,
    FitnessPlatform.garmin => Icons.watch_rounded,
  };

  String _platformName(FitnessPlatform platform) => switch (platform) {
    FitnessPlatform.strava => 'Strava',
    FitnessPlatform.garmin => 'Garmin Connect',
  };

  String _friendlyError(Object error) {
    if (error is FitnessServiceException) {
      return error.message;
    }
    return 'The fitness connection could not be updated.';
  }

  String _formatTimestamp(DateTime value) {
    final DateTime local = value.toLocal();
    final String month = local.month.toString().padLeft(2, '0');
    final String day = local.day.toString().padLeft(2, '0');
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final FitnessExportEntry entry;

  @override
  Widget build(BuildContext context) {
    final _StatusVisual visual = switch (entry.status) {
      FitnessUploadStatus.succeeded => const _StatusVisual(
        label: 'UPLOADED',
        color: AppColors.success,
        icon: Icons.check_circle_rounded,
      ),
      FitnessUploadStatus.failed => const _StatusVisual(
        label: 'RETRY QUEUED',
        color: AppColors.coral,
        icon: Icons.error_rounded,
      ),
      FitnessUploadStatus.processing => const _StatusVisual(
        label: 'PROCESSING',
        color: AppColors.gold,
        icon: Icons.pending_rounded,
      ),
      FitnessUploadStatus.queued ||
      FitnessUploadStatus.uploading => const _StatusVisual(
        label: 'QUEUED',
        color: AppColors.gold,
        icon: Icons.cloud_upload_rounded,
      ),
    };
    return Card(
      child: ListTile(
        leading: Icon(visual.icon, color: visual.color),
        title: Text(
          entry.platform == FitnessPlatform.strava
              ? 'Strava'
              : 'Garmin Connect',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          entry.errorMessage ??
              '${entry.sportType} • ${_formatTimestamp(entry.endedAt)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          visual.label,
          style: TextStyle(
            color: visual.color,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime value) {
    final DateTime local = value.toLocal();
    final String month = local.month.toString().padLeft(2, '0');
    final String day = local.day.toString().padLeft(2, '0');
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0x0DFFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: const Column(
        children: <Widget>[
          Icon(Icons.cloud_done_rounded, color: AppColors.textMuted, size: 30),
          SizedBox(height: 9),
          Text(
            'No exported workouts yet',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _StatusVisual {
  const _StatusVisual({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;
}

class _AudioCardHeader extends StatelessWidget {
  const _AudioCardHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, color: color, size: 21),
        const SizedBox(width: 9),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}
