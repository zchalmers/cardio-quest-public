export type MachineKind =
  | 'treadmill'
  | 'indoorBike'
  | 'crossTrainer'
  | 'rower'
  | 'unknown'
  | 'simulator';

export type HeartRateZone =
  | 'recovery'
  | 'aerobic'
  | 'tempo'
  | 'threshold'
  | 'peak'
  | 'unknown';

export type HeartRateSource = 'none' | 'machine' | 'wearable' | 'simulated';

export interface WorkoutMetricSample {
  recordedAt: string;
  elapsedSeconds: number;
  speedKph: number;
  inclinePercent: number;
  distanceMeters: number;
  heartRateBpm: number;
  heartRateSource: HeartRateSource;
  activeEnergyCalories?: number;
}

export interface HeartRateVariabilityStats {
  sdnnMilliseconds?: number;
  rmssdMilliseconds?: number;
  heartRateStandardDeviationBpm?: number;
  sampleCount: number;
}

export interface HeartRateRecoveryStats {
  baselineBpm?: number;
  oneMinuteBpm?: number;
  twoMinuteBpm?: number;
  currentBpm?: number;
}

/** JSON representation of the Flutter GameSummary model. */
export interface GameSummary {
  durationSeconds: number;
  distanceMeters: number;
  averageSpeedKph: number;
  maxSpeedKph: number;
  coins: number;
  score: number;
  maxCombo: number;
  obstaclesCleared: number;
  averageHeartRateBpm: number;
  maxHeartRateBpm: number;
  restingHeartRateBpm?: number;
  activeEnergyCalories: number;
  workoutStepCount: number;
  heartRateZoneDurations: Record<HeartRateZone, number>;
  heartRateVariability: HeartRateVariabilityStats;
  heartRateRecovery: HeartRateRecoveryStats;
  usedWearableData: boolean;
  wearableHeartRateSampleCount: number;
  metricSamples: WorkoutMetricSample[];
}

/** JSON representation of the persisted Flutter PlayerProfile model. */
export interface PlayerProfile {
  id: string;
  displayName: string;
  initials: string;
  rankTitle: string;
  totalXp: number;
  totalDistanceMeters: number;
  totalWorkouts: number;
  totalPlaytimeSeconds: number;
  bestCombo: number;
  bestSpeedKph: number;
  currentStreak: number;
  longestStreak: number;
  totalCoins: number;
  totalObstaclesCleared: number;
  multiplayerWins: number;
  totalCalories: number;
  earlyBirdWorkouts: number;
  nightOwlWorkouts: number;
  longestSessionDistanceMeters: number;
  maximumHeartRateBpm: number;
  zoneSeconds: Record<Exclude<HeartRateZone, 'unknown'>, number>;
  machineKindsUsed: MachineKind[];
  level: number;
  levelProgress: number;
  xpIntoLevel: number;
  xpNeededThisLevel: number;
}

export interface Workout {
  id: string;
  startedAt: string;
  endedAt: string;
  machineKind: MachineKind;
  summary: GameSummary;
  xpEarned: number;
}

export type AchievementCategory =
  | 'distance'
  | 'speed'
  | 'combo'
  | 'zones'
  | 'consistency'
  | 'coins'
  | 'multiplayer'
  | 'heartRate'
  | 'calories'
  | 'variety'
  | 'lifestyle';

export type AchievementTier =
  | 'bronze'
  | 'silver'
  | 'gold'
  | 'platinum'
  | 'legendary';

export interface Achievement {
  id: string;
  name: string;
  description: string;
  category: AchievementCategory;
  tier: AchievementTier;
  icon: string;
  value: number;
  target: number;
  unit: string;
  unlockedAt?: string;
}

export type ChallengeCadence = 'daily' | 'weekly';

export interface Challenge {
  id: string;
  name: string;
  description: string;
  cadence: ChallengeCadence;
  icon: string;
  value: number;
  target: number;
  unit: string;
  reward: string;
  endsAt: string;
  completedAt?: string;
}

export type LeaderboardKind =
  | 'weeklyDistance'
  | 'allTimeDistance'
  | 'speedRecords'
  | 'challengeCompletion';

export interface LeaderboardEntry {
  id: string;
  rank: number;
  displayName: string;
  initials: string;
  value: number;
  unit: string;
  secondary: string;
  trend: number;
  avatarColor: string;
  isCurrentPlayer?: boolean;
}

export interface CardioQuestExport {
  generatedAt: string;
  profile: PlayerProfile;
  workouts: Workout[];
  achievements: Achievement[];
  challenges: Challenge[];
  leaderboards: Record<LeaderboardKind, LeaderboardEntry[]>;
}
