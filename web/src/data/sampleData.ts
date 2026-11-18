import type {
  Achievement,
  CardioQuestExport,
  Challenge,
  GameSummary,
  HeartRateZone,
  LeaderboardEntry,
  LeaderboardKind,
  MachineKind,
  PlayerProfile,
  Workout,
} from '@/types';

const ZONES: Exclude<HeartRateZone, 'unknown'>[] = [
  'recovery',
  'aerobic',
  'tempo',
  'threshold',
  'peak',
];

function mulberry32(seed: number): () => number {
  return () => {
    let value = (seed += 0x6d2b79f5);
    value = Math.imul(value ^ (value >>> 15), value | 1);
    value ^= value + Math.imul(value ^ (value >>> 7), value | 61);
    return ((value ^ (value >>> 14)) >>> 0) / 4_294_967_296;
  };
}

const random = mulberry32(2_406_202);

function between(min: number, max: number): number {
  return min + random() * (max - min);
}

function integer(min: number, max: number): number {
  return Math.round(between(min, max));
}

function dateAtDaysAgo(daysAgo: number, hour = 7): Date {
  const date = new Date();
  date.setHours(hour, integer(4, 48), 0, 0);
  date.setDate(date.getDate() - daysAgo);
  return date;
}

function zoneDurations(
  durationSeconds: number,
  intensity: number,
): Record<HeartRateZone, number> {
  const recovery = Math.round(durationSeconds * between(0.06, 0.13));
  const aerobic = Math.round(durationSeconds * between(0.24, 0.36));
  const tempo = Math.round(durationSeconds * between(0.29, 0.39));
  const threshold = Math.round(durationSeconds * between(0.13, 0.22) * intensity);
  const peak = Math.max(
    0,
    durationSeconds - recovery - aerobic - tempo - threshold,
  );
  return { recovery, aerobic, tempo, threshold, peak, unknown: 0 };
}

function workoutFor(daysAgo: number, index: number): Workout {
  const machineRoll = random();
  const machineKind: MachineKind =
    machineRoll < 0.55
      ? 'treadmill'
      : machineRoll < 0.82
        ? 'indoorBike'
        : machineRoll < 0.95
          ? 'rower'
          : 'crossTrainer';
  const durationMinutes = integer(24, 61);
  const durationSeconds = durationMinutes * 60 + integer(0, 50);
  const speedRange =
    machineKind === 'indoorBike'
      ? [20, 29]
      : machineKind === 'rower'
        ? [8.2, 12.6]
        : machineKind === 'crossTrainer'
          ? [9.4, 14.2]
          : [8.1, 12.4];
  const averageSpeedKph = between(speedRange[0] ?? 8, speedRange[1] ?? 12);
  const distanceMeters = averageSpeedKph * (durationSeconds / 3600) * 1000;
  const maxSpeedKph = averageSpeedKph * between(1.12, 1.32);
  const averageHeartRateBpm = integer(127, 156);
  const maxHeartRateBpm = Math.min(194, averageHeartRateBpm + integer(18, 33));
  const intensity = (averageHeartRateBpm - 105) / 55;
  const coins = integer(18, 82);
  const maxCombo = Number(between(2.4, 14.8).toFixed(1));
  const obstaclesCleared = integer(10, 43);
  const zones = zoneDurations(durationSeconds, intensity);
  const startedAt = dateAtDaysAgo(
    daysAgo,
    index % 7 === 0 ? 18 : index % 5 === 0 ? 20 : 7,
  );
  const endedAt = new Date(startedAt.getTime() + durationSeconds * 1000);
  const xpEarned = Math.round(
    distanceMeters + coins * 5 + (maxCombo - 1) * 75 + obstaclesCleared * 30,
  );
  const summary: GameSummary = {
    durationSeconds,
    distanceMeters: Number(distanceMeters.toFixed(1)),
    averageSpeedKph: Number(averageSpeedKph.toFixed(1)),
    maxSpeedKph: Number(maxSpeedKph.toFixed(1)),
    coins,
    score: Math.round(xpEarned * between(7.5, 10.5)),
    maxCombo,
    obstaclesCleared,
    averageHeartRateBpm,
    maxHeartRateBpm,
    restingHeartRateBpm: integer(54, 64),
    activeEnergyCalories: Math.round(durationMinutes * between(7.1, 11.6)),
    workoutStepCount:
      machineKind === 'treadmill'
        ? Math.round((distanceMeters / 1000) * between(1_180, 1_420))
        : 0,
    heartRateZoneDurations: zones,
    heartRateVariability: {
      sdnnMilliseconds: Number(between(35, 59).toFixed(1)),
      rmssdMilliseconds: Number(between(28, 51).toFixed(1)),
      heartRateStandardDeviationBpm: Number(between(8, 17).toFixed(1)),
      sampleCount: Math.round(durationSeconds / 5),
    },
    heartRateRecovery: {
      baselineBpm: maxHeartRateBpm - integer(1, 7),
      oneMinuteBpm: maxHeartRateBpm - integer(24, 38),
      twoMinuteBpm: maxHeartRateBpm - integer(39, 58),
      currentBpm: averageHeartRateBpm - integer(22, 36),
    },
    usedWearableData: index % 4 !== 0,
    wearableHeartRateSampleCount:
      index % 4 !== 0 ? Math.round(durationSeconds / 5) : 0,
    metricSamples: [],
  };

  return {
    id: `cq-${startedAt.toISOString().slice(0, 10)}-${index.toString().padStart(3, '0')}`,
    startedAt: startedAt.toISOString(),
    endedAt: endedAt.toISOString(),
    machineKind,
    summary,
    xpEarned,
  };
}

function generateWorkouts(): Workout[] {
  const offsets = [0, 1, 2, 3, 4, 5];
  let offset = 7;
  while (offset < 182) {
    offsets.push(offset);
    offset += integer(1, 4);
  }
  return offsets
    .slice(0, 78)
    .map((daysAgo, index) => workoutFor(daysAgo, index))
    .sort(
      (a, b) =>
        new Date(b.startedAt).getTime() - new Date(a.startedAt).getTime(),
    );
}

const workouts = generateWorkouts();

function totalFor(
  selector: (workout: Workout) => number,
): number {
  return workouts.reduce((total, workout) => total + selector(workout), 0);
}

function buildProfile(): PlayerProfile {
  const zoneSeconds = {
    recovery: 0,
    aerobic: 0,
    tempo: 0,
    threshold: 0,
    peak: 0,
  };
  for (const workout of workouts) {
    for (const zone of ZONES) {
      zoneSeconds[zone] += workout.summary.heartRateZoneDurations[zone];
    }
  }

  const totalXp = totalFor((workout) => workout.xpEarned) + 8_500;
  return {
    id: 'player-maya-chen',
    displayName: 'Maya Chen',
    initials: 'MC',
    rankTitle: 'Tempo Vanguard',
    totalXp,
    totalDistanceMeters: totalFor((workout) => workout.summary.distanceMeters),
    totalWorkouts: workouts.length,
    totalPlaytimeSeconds: totalFor(
      (workout) => workout.summary.durationSeconds,
    ),
    bestCombo: Math.max(...workouts.map((workout) => workout.summary.maxCombo)),
    bestSpeedKph: Math.max(
      ...workouts.map((workout) => workout.summary.maxSpeedKph),
    ),
    currentStreak: 6,
    longestStreak: 14,
    totalCoins: totalFor((workout) => workout.summary.coins),
    totalObstaclesCleared: totalFor(
      (workout) => workout.summary.obstaclesCleared,
    ),
    multiplayerWins: 18,
    totalCalories: totalFor(
      (workout) => workout.summary.activeEnergyCalories,
    ),
    earlyBirdWorkouts: workouts.filter(
      (workout) => new Date(workout.startedAt).getHours() < 8,
    ).length,
    nightOwlWorkouts: workouts.filter(
      (workout) => new Date(workout.startedAt).getHours() >= 20,
    ).length,
    longestSessionDistanceMeters: Math.max(
      ...workouts.map((workout) => workout.summary.distanceMeters),
    ),
    maximumHeartRateBpm: Math.max(
      ...workouts.map((workout) => workout.summary.maxHeartRateBpm),
    ),
    zoneSeconds,
    machineKindsUsed: ['treadmill', 'indoorBike', 'rower', 'crossTrainer'],
    level: 18,
    levelProgress: 0.68,
    xpIntoLevel: 16_840,
    xpNeededThisLevel: 24_760,
  };
}

const profile = buildProfile();

const achievementBlueprints: Array<
  Omit<Achievement, 'value' | 'unlockedAt'> & {
    value: number;
    unlockedDaysAgo?: number;
  }
> = [
  {
    id: 'distance_100k',
    name: 'Century Voyager',
    description: 'Travel 100 km across all quests',
    category: 'distance',
    tier: 'gold',
    icon: 'map',
    value: profile.totalDistanceMeters,
    target: 100_000,
    unit: 'm',
    unlockedDaysAgo: 72,
  },
  {
    id: 'distance_500k',
    name: 'World Walker',
    description: 'Travel 500 km across all quests',
    category: 'distance',
    tier: 'platinum',
    icon: 'globe',
    value: profile.totalDistanceMeters,
    target: 500_000,
    unit: 'm',
    unlockedDaysAgo: 13,
  },
  {
    id: 'speed_15',
    name: 'Velocity',
    description: 'Hit 15 km/h in a workout',
    category: 'speed',
    tier: 'gold',
    icon: 'zap',
    value: profile.bestSpeedKph,
    target: 15,
    unit: 'km/h',
    unlockedDaysAgo: 29,
  },
  {
    id: 'speed_35',
    name: 'Mach Cardio',
    description: 'Hit 35 km/h in a workout',
    category: 'speed',
    tier: 'legendary',
    icon: 'rocket',
    value: profile.bestSpeedKph,
    target: 35,
    unit: 'km/h',
    unlockedDaysAgo: 9,
  },
  {
    id: 'combo_10x',
    name: 'Unbroken Flow',
    description: 'Reach a 10× combo',
    category: 'combo',
    tier: 'gold',
    icon: 'flame',
    value: profile.bestCombo,
    target: 10,
    unit: '×',
    unlockedDaysAgo: 18,
  },
  {
    id: 'zone_tempo_10h',
    name: 'Tempo Warrior',
    description: 'Spend 10 total hours in the tempo zone',
    category: 'zones',
    tier: 'silver',
    icon: 'heart',
    value: profile.zoneSeconds.tempo,
    target: 36_000,
    unit: 'sec',
    unlockedDaysAgo: 47,
  },
  {
    id: 'streak_7',
    name: 'Seven Day Spark',
    description: 'Complete a workout seven days in a row',
    category: 'consistency',
    tier: 'silver',
    icon: 'calendar',
    value: profile.longestStreak,
    target: 7,
    unit: 'days',
    unlockedDaysAgo: 41,
  },
  {
    id: 'streak_21',
    name: 'Unstoppable',
    description: 'Build a 21-day workout streak',
    category: 'consistency',
    tier: 'legendary',
    icon: 'sparkles',
    value: profile.longestStreak,
    target: 21,
    unit: 'days',
  },
  {
    id: 'coins_2500',
    name: 'Treasure Runner',
    description: 'Collect 2,500 quest coins',
    category: 'coins',
    tier: 'gold',
    icon: 'coins',
    value: profile.totalCoins,
    target: 2_500,
    unit: 'coins',
    unlockedDaysAgo: 11,
  },
  {
    id: 'wins_25',
    name: 'Arena Ace',
    description: 'Win 25 multiplayer races',
    category: 'multiplayer',
    tier: 'platinum',
    icon: 'swords',
    value: profile.multiplayerWins,
    target: 25,
    unit: 'wins',
  },
  {
    id: 'calories_20k',
    name: 'Energy Forge',
    description: 'Burn 20,000 active calories',
    category: 'calories',
    tier: 'platinum',
    icon: 'activity',
    value: profile.totalCalories,
    target: 20_000,
    unit: 'kcal',
    unlockedDaysAgo: 7,
  },
  {
    id: 'variety_4',
    name: 'Quest Polymath',
    description: 'Train on four different machine types',
    category: 'variety',
    tier: 'gold',
    icon: 'shapes',
    value: profile.machineKindsUsed.length,
    target: 4,
    unit: 'types',
    unlockedDaysAgo: 36,
  },
  {
    id: 'early_20',
    name: 'Dawn Patrol',
    description: 'Complete 20 workouts before 8 AM',
    category: 'lifestyle',
    tier: 'silver',
    icon: 'sunrise',
    value: profile.earlyBirdWorkouts,
    target: 20,
    unit: 'workouts',
    unlockedDaysAgo: 15,
  },
  {
    id: 'hr_peak_190',
    name: 'Redline',
    description: 'Reach a heart rate of 190 BPM',
    category: 'heartRate',
    tier: 'legendary',
    icon: 'heart-pulse',
    value: profile.maximumHeartRateBpm,
    target: 190,
    unit: 'bpm',
  },
];

const achievements: Achievement[] = achievementBlueprints.map(
  ({ unlockedDaysAgo, ...achievement }) => ({
    ...achievement,
    ...(unlockedDaysAgo !== undefined
      ? { unlockedAt: dateAtDaysAgo(unlockedDaysAgo).toISOString() }
      : {}),
  }),
);

const challenges: Challenge[] = [
  {
    id: 'daily-tempo',
    name: 'Tempo Tune-Up',
    description: 'Spend 12 minutes in the tempo zone',
    cadence: 'daily',
    icon: 'heart-pulse',
    value: 9.4,
    target: 12,
    unit: 'min',
    reward: '+500 XP',
    endsAt: new Date(new Date().setHours(23, 59, 59, 999)).toISOString(),
  },
  {
    id: 'daily-distance',
    name: 'Morning Miles',
    description: 'Travel 5 km in any quest',
    cadence: 'daily',
    icon: 'route',
    value: 5,
    target: 5,
    unit: 'km',
    reward: '+350 XP',
    endsAt: new Date(new Date().setHours(23, 59, 59, 999)).toISOString(),
    completedAt: new Date().toISOString(),
  },
  {
    id: 'weekly-distance',
    name: 'Pathfinder',
    description: 'Travel 30 km across all quests this week',
    cadence: 'weekly',
    icon: 'mountain',
    value: 22.8,
    target: 30,
    unit: 'km',
    reward: 'Ghost trail',
    endsAt: dateAtDaysAgo(-3, 23).toISOString(),
  },
  {
    id: 'weekly-workouts',
    name: 'Momentum Maker',
    description: 'Complete 5 workouts this week',
    cadence: 'weekly',
    icon: 'flame',
    value: 4,
    target: 5,
    unit: 'workouts',
    reward: '+1,500 XP',
    endsAt: dateAtDaysAgo(-3, 23).toISOString(),
  },
];

const competitors = [
  ['Avery Park', 'AP', '#B8A1FF'],
  ['Leo Santos', 'LS', '#FFB55E'],
  ['Noah Williams', 'NW', '#65F2D0'],
  ['Maya Chen', 'MC', '#FF6B7A'],
  ['Priya Shah', 'PS', '#79B8FF'],
  ['Eli Turner', 'ET', '#70E49A'],
  ['Sam Rivera', 'SR', '#FFD166'],
  ['June Becker', 'JB', '#C9A7EB'],
  ['Ravi Mehta', 'RM', '#FF8B7B'],
  ['Tessa Young', 'TY', '#62D9EC'],
];

function makeBoard(
  kind: LeaderboardKind,
  values: number[],
  units: string,
): LeaderboardEntry[] {
  return values.map((value, index) => {
    const person = competitors[index] ?? ['Quest Player', 'QP', '#65F2D0'];
    return {
      id: `${kind}-${index}`,
      rank: index + 1,
      displayName: person[0] ?? 'Quest Player',
      initials: person[1] ?? 'QP',
      avatarColor: person[2] ?? '#65F2D0',
      value,
      unit: units,
      secondary:
        kind === 'challengeCompletion'
          ? `${integer(3, 7)} day streak`
          : `${integer(3, 6)} workouts`,
      trend: index === 0 ? 2 : index % 4 === 0 ? -1 : index % 3 === 0 ? 0 : 1,
      ...(person[0] === 'Maya Chen' ? { isCurrentPlayer: true } : {}),
    };
  });
}

const leaderboards: Record<LeaderboardKind, LeaderboardEntry[]> = {
  weeklyDistance: makeBoard(
    'weeklyDistance',
    [41.7, 38.4, 34.9, 32.6, 29.8, 27.3, 25.9, 23.4, 21.6, 19.8],
    'km',
  ),
  allTimeDistance: makeBoard(
    'allTimeDistance',
    [824.9, 781.2, 746.6, 693.4, 640.1, 612.7, 584.9, 521.8, 489.6, 461.3],
    'km',
  ),
  speedRecords: makeBoard(
    'speedRecords',
    [37.8, 36.2, 35.4, 34.9, 33.7, 32.4, 31.8, 30.9, 29.7, 28.8],
    'km/h',
  ),
  challengeCompletion: makeBoard(
    'challengeCompletion',
    [28, 26, 25, 24, 22, 21, 20, 19, 18, 17],
    'quests',
  ),
};

export function generateSampleData(): CardioQuestExport {
  return {
    generatedAt: new Date().toISOString(),
    profile,
    workouts,
    achievements,
    challenges,
    leaderboards,
  };
}

export const sampleData = generateSampleData();
