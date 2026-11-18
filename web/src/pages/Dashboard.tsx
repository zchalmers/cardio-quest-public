import {
  Activity,
  Bike,
  CalendarDays,
  Check,
  ChevronRight,
  Clock3,
  Flame,
  Footprints,
  Heart,
  Mountain,
  RefreshCw,
  Route,
  Sparkles,
  Trophy,
  Waves,
  Zap,
} from 'lucide-react';
import { Link } from 'react-router-dom';
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import { ChartTooltip } from '@/components/ui/ChartTooltip';
import { PageHeader } from '@/components/ui/PageHeader';
import { Panel } from '@/components/ui/Panel';
import { ProgressBar } from '@/components/ui/ProgressBar';
import { StatCard } from '@/components/ui/StatCard';
import { useCardioData } from '@/data/CardioDataProvider';
import {
  cn,
  formatCompactNumber,
  formatDistance,
  formatDuration,
  formatNumber,
  formatRelativeDate,
  machineLabel,
  startOfWeek,
} from '@/lib/utils';
import type { Challenge, MachineKind, Workout } from '@/types';

const machineIcons = {
  treadmill: Footprints,
  indoorBike: Bike,
  rower: Waves,
  crossTrainer: Activity,
  simulator: Zap,
  unknown: Activity,
} satisfies Record<MachineKind, typeof Activity>;

const challengeIcons = {
  'heart-pulse': Heart,
  route: Route,
  mountain: Mountain,
  flame: Flame,
};

function weeklyActivity(workouts: Workout[]) {
  const start = startOfWeek();
  return Array.from({ length: 7 }, (_, index) => {
    const day = new Date(start);
    day.setDate(start.getDate() + index);
    const next = new Date(day);
    next.setDate(day.getDate() + 1);
    const meters = workouts
      .filter((workout) => {
        const started = new Date(workout.startedAt);
        return started >= day && started < next;
      })
      .reduce((total, workout) => total + workout.summary.distanceMeters, 0);
    return {
      day: new Intl.DateTimeFormat('en-US', { weekday: 'short' }).format(day),
      distance: Number((meters / 1000).toFixed(1)),
      isToday: day.toDateString() === new Date().toDateString(),
    };
  });
}

function WorkoutMiniCard({ workout }: { workout: Workout }) {
  const Icon = machineIcons[workout.machineKind];
  return (
    <article className="group flex flex-col gap-4 rounded-2xl border border-white/[0.07] bg-ink/25 p-4 transition hover:border-mint/20 hover:bg-ink/40 sm:flex-row sm:items-center">
      <div className="flex min-w-0 items-center gap-3 sm:w-52">
        <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-mint/[0.09] text-mint ring-1 ring-inset ring-mint/10">
          <Icon size={20} aria-hidden="true" />
        </div>
        <div className="min-w-0">
          <h3 className="truncate text-sm font-bold text-white">
            {machineLabel(workout.machineKind)} quest
          </h3>
          <p className="mt-1 text-xs text-muted">
            {formatRelativeDate(workout.startedAt)}
          </p>
        </div>
      </div>
      <div className="grid flex-1 grid-cols-3 gap-3 border-t border-white/[0.06] pt-4 sm:border-l sm:border-t-0 sm:pl-5 sm:pt-0">
        <div>
          <p className="text-[10px] font-semibold uppercase tracking-wider text-muted/70">
            Distance
          </p>
          <p className="mt-1 text-sm font-bold text-white">
            {formatDistance(workout.summary.distanceMeters)}
          </p>
        </div>
        <div>
          <p className="text-[10px] font-semibold uppercase tracking-wider text-muted/70">
            Time
          </p>
          <p className="mt-1 text-sm font-bold text-white">
            {formatDuration(workout.summary.durationSeconds)}
          </p>
        </div>
        <div>
          <p className="text-[10px] font-semibold uppercase tracking-wider text-muted/70">
            Avg HR
          </p>
          <p className="mt-1 flex items-center gap-1 text-sm font-bold text-white">
            <Heart size={12} className="text-coral" fill="currentColor" aria-hidden="true" />
            {workout.summary.averageHeartRateBpm}
          </p>
        </div>
      </div>
      <ChevronRight
        size={17}
        className="hidden text-muted/40 transition group-hover:translate-x-0.5 group-hover:text-mint sm:block"
        aria-hidden="true"
      />
    </article>
  );
}

function ChallengeCard({ challenge }: { challenge: Challenge }) {
  const Icon =
    challengeIcons[challenge.icon as keyof typeof challengeIcons] ?? Trophy;
  const percent = Math.min(100, (challenge.value / challenge.target) * 100);
  return (
    <article className="rounded-xl border border-white/[0.06] bg-ink/25 p-4">
      <div className="flex items-start gap-3">
        <div
          className={cn(
            'flex h-10 w-10 shrink-0 items-center justify-center rounded-xl',
            challenge.completedAt
              ? 'bg-success/10 text-success'
              : 'bg-lavender/10 text-lavender',
          )}
        >
          {challenge.completedAt ? (
            <Check size={19} strokeWidth={2.5} aria-hidden="true" />
          ) : (
            <Icon size={19} aria-hidden="true" />
          )}
        </div>
        <div className="min-w-0 flex-1">
          <div className="flex items-center justify-between gap-3">
            <h3 className="truncate text-sm font-bold text-white">
              {challenge.name}
            </h3>
            <span className="shrink-0 rounded-md bg-white/[0.05] px-2 py-1 text-[9px] font-bold uppercase tracking-wider text-muted">
              {challenge.cadence}
            </span>
          </div>
          <p className="mt-1 text-[11px] leading-5 text-muted">
            {challenge.description}
          </p>
        </div>
      </div>
      <div className="mt-4">
        <div className="mb-2 flex items-end justify-between text-xs">
          <span className="font-bold text-white">
            {challenge.value.toLocaleString()} / {challenge.target.toLocaleString()}{' '}
            <span className="font-medium text-muted">{challenge.unit}</span>
          </span>
          <span className="font-semibold text-mint">{Math.round(percent)}%</span>
        </div>
        <ProgressBar
          value={challenge.value}
          max={challenge.target}
          label={`${challenge.name} progress`}
          fillClassName={
            challenge.completedAt
              ? 'from-success to-mint'
              : challenge.cadence === 'weekly'
                ? 'from-lavender to-[#79B8FF]'
                : undefined
          }
        />
        <div className="mt-2 flex items-center justify-between text-[10px]">
          <span className="text-muted">Reward</span>
          <span className="font-bold text-gold">{challenge.reward}</span>
        </div>
      </div>
    </article>
  );
}

export function Dashboard() {
  const { data, source, error } = useCardioData();
  const { profile, workouts, challenges } = data;
  const weekData = weeklyActivity(workouts);
  const weekDistance = weekData.reduce((total, item) => total + item.distance, 0);
  const recent = workouts.slice(0, 4);

  return (
    <div className="page-enter">
      <PageHeader
        eyebrow="Command center"
        title={`Welcome back, ${profile.displayName.split(' ')[0] ?? 'Quester'}`}
        description="Your momentum is building. Keep the streak alive and close out this week's Pathfinder challenge."
        action={
          <div className="inline-flex items-center gap-2 rounded-xl border border-white/[0.08] bg-white/[0.035] px-3.5 py-2.5 text-xs font-semibold text-muted">
            <RefreshCw size={13} className="text-success" aria-hidden="true" />
            {source === 'api'
              ? 'Synced just now'
              : error
                ? 'Sample data · API unavailable'
                : 'Development data'}
          </div>
        }
      />

      <section aria-labelledby="overview-heading">
        <h2 id="overview-heading" className="sr-only">
          Player overview
        </h2>
        <div className="grid grid-cols-2 gap-3 xl:grid-cols-5">
          <StatCard
            label="Total distance"
            value={formatDistance(profile.totalDistanceMeters, 0)}
            detail="all quest routes"
            icon={Route}
            featured
            trend={12.4}
            className="col-span-2 xl:col-span-1"
          />
          <StatCard
            label="Workouts"
            value={formatNumber(profile.totalWorkouts)}
            detail="8 this month"
            icon={CalendarDays}
            accent="blue"
            trend={8.1}
          />
          <StatCard
            label="Total XP"
            value={formatCompactNumber(profile.totalXp)}
            detail={`${formatNumber(profile.xpIntoLevel)} to next level`}
            icon={Sparkles}
            accent="lavender"
          />
          <StatCard
            label="Current level"
            value={`${profile.level}`}
            detail={profile.rankTitle}
            icon={Trophy}
            accent="gold"
          />
          <StatCard
            label="Current streak"
            value={`${profile.currentStreak} days`}
            detail={`Best: ${profile.longestStreak} days`}
            icon={Flame}
            accent="coral"
          />
        </div>
      </section>

      <section
        aria-label="Weekly activity and level progress"
        className="mt-5 grid gap-5 xl:grid-cols-[minmax(0,1.7fr)_minmax(320px,0.8fr)]"
      >
        <Panel className="p-5 sm:p-6">
          <div className="relative mb-5 flex items-start justify-between gap-4">
            <div>
              <h2 className="font-display text-lg font-semibold text-white">
                Weekly activity
              </h2>
              <p className="mt-1 text-xs text-muted">Distance by training day</p>
            </div>
            <div className="text-right">
              <p className="font-display text-2xl font-semibold text-white">
                {weekDistance.toFixed(1)}
                <span className="ml-1 text-xs font-medium text-muted">km</span>
              </p>
              <p className="mt-1 text-[10px] font-bold text-success">
                +18% vs last week
              </p>
            </div>
          </div>
          <div className="relative h-64 w-full" role="img" aria-label="Bar chart of distance traveled each day this week">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart
                data={weekData}
                margin={{ top: 6, right: 0, left: -24, bottom: 0 }}
                accessibilityLayer
              >
                <CartesianGrid
                  vertical={false}
                  stroke="rgba(169,186,200,0.09)"
                  strokeDasharray="3 5"
                />
                <XAxis
                  dataKey="day"
                  axisLine={false}
                  tickLine={false}
                  tick={{ fill: '#8296A6', fontSize: 11 }}
                  dy={9}
                />
                <YAxis
                  axisLine={false}
                  tickLine={false}
                  tick={{ fill: '#718797', fontSize: 10 }}
                  tickFormatter={(value: number) => `${value}`}
                />
                <Tooltip
                  cursor={{ fill: 'rgba(101,242,208,0.035)' }}
                  content={<ChartTooltip unit=" km" />}
                />
                <Bar
                  dataKey="distance"
                  name="Distance"
                  radius={[7, 7, 7, 7]}
                  maxBarSize={34}
                  isAnimationActive={false}
                >
                  {weekData.map((entry) => (
                    <Cell
                      key={entry.day}
                      fill={entry.isToday ? '#65F2D0' : 'rgba(101,242,208,0.28)'}
                    />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </div>
        </Panel>

        <Panel variant="highlight" className="flex flex-col justify-between p-6">
          <div className="relative">
            <div className="flex items-center justify-between">
              <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-gold/10 text-gold ring-1 ring-gold/15">
                <Trophy size={21} aria-hidden="true" />
              </div>
              <span className="rounded-full border border-mint/15 bg-mint/[0.08] px-2.5 py-1 text-[9px] font-bold uppercase tracking-wider text-mint">
                Level progress
              </span>
            </div>
            <p className="mt-6 text-xs font-semibold uppercase tracking-[0.14em] text-muted">
              Level {profile.level}
            </p>
            <h2 className="mt-1 font-display text-2xl font-semibold text-white">
              {profile.rankTitle}
            </h2>
            <p className="mt-2 text-xs leading-5 text-muted">
              Keep training to unlock the Aurora trail at level {profile.level + 1}.
            </p>
          </div>
          <div className="relative mt-8">
            <div className="mb-2 flex items-center justify-between text-xs">
              <span className="font-bold text-white">
                {formatNumber(profile.xpIntoLevel)} XP
              </span>
              <span className="text-muted">
                {formatNumber(profile.xpNeededThisLevel)} XP
              </span>
            </div>
            <ProgressBar
              value={profile.xpIntoLevel}
              max={profile.xpNeededThisLevel}
              label="Level progress"
              className="h-2.5"
              fillClassName="from-gold via-mint to-mint"
            />
            <p className="mt-3 flex items-center gap-1.5 text-[10px] font-semibold text-mint">
              <Zap size={12} fill="currentColor" aria-hidden="true" />
              {Math.round(profile.levelProgress * 100)}% complete
            </p>
          </div>
        </Panel>
      </section>

      <section className="mt-5 grid gap-5 xl:grid-cols-[minmax(0,1.25fr)_minmax(390px,0.75fr)]">
        <Panel className="p-5 sm:p-6">
          <div className="relative mb-5 flex items-center justify-between">
            <div>
              <h2 className="font-display text-lg font-semibold text-white">
                Recent workouts
              </h2>
              <p className="mt-1 text-xs text-muted">Your latest completed quests</p>
            </div>
            <Link
              to="/history"
              className="flex items-center gap-1 text-xs font-bold text-mint transition hover:text-white"
            >
              View all
              <ChevronRight size={14} aria-hidden="true" />
            </Link>
          </div>
          <div className="relative space-y-3">
            {recent.map((workout) => (
              <WorkoutMiniCard key={workout.id} workout={workout} />
            ))}
          </div>
        </Panel>

        <Panel className="p-5 sm:p-6">
          <div className="relative mb-5 flex items-start justify-between">
            <div>
              <h2 className="font-display text-lg font-semibold text-white">
                Active challenges
              </h2>
              <p className="mt-1 text-xs text-muted">Daily & weekly quests</p>
            </div>
            <div className="flex items-center gap-1.5 text-[10px] font-semibold text-muted">
              <Clock3 size={12} aria-hidden="true" />
              8h left
            </div>
          </div>
          <div className="relative space-y-3">
            {challenges.map((challenge) => (
              <ChallengeCard key={challenge.id} challenge={challenge} />
            ))}
          </div>
        </Panel>
      </section>
    </div>
  );
}
