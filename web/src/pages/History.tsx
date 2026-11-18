import { useMemo, useState } from 'react';
import {
  Activity,
  Bike,
  Calendar,
  ChevronDown,
  Clock3,
  Footprints,
  Gauge,
  Heart,
  Route,
  Sparkles,
  Waves,
  Zap,
} from 'lucide-react';
import { PageHeader } from '@/components/ui/PageHeader';
import { Panel } from '@/components/ui/Panel';
import { SegmentedControl } from '@/components/ui/SegmentedControl';
import { useCardioData } from '@/data/CardioDataProvider';
import {
  cn,
  formatDate,
  formatDistance,
  formatDuration,
  formatNumber,
  machineLabel,
  startOfWeek,
} from '@/lib/utils';
import type { HeartRateZone, MachineKind, Workout } from '@/types';

type TimeFilter = 'week' | 'month' | 'all';
type SortOption = 'date' | 'distance' | 'duration';

const zoneConfig: Array<{
  zone: Exclude<HeartRateZone, 'unknown'>;
  label: string;
  color: string;
}> = [
  { zone: 'recovery', label: 'Z1', color: '#79B8FF' },
  { zone: 'aerobic', label: 'Z2', color: '#70E49A' },
  { zone: 'tempo', label: 'Z3', color: '#FFD166' },
  { zone: 'threshold', label: 'Z4', color: '#FF8B6B' },
  { zone: 'peak', label: 'Z5', color: '#FF5572' },
];

const machineConfig = {
  treadmill: { icon: Footprints, color: 'text-mint bg-mint/10' },
  indoorBike: { icon: Bike, color: 'text-[#79B8FF] bg-[#79B8FF]/10' },
  rower: { icon: Waves, color: 'text-lavender bg-lavender/10' },
  crossTrainer: { icon: Activity, color: 'text-gold bg-gold/10' },
  simulator: { icon: Zap, color: 'text-coral bg-coral/10' },
  unknown: { icon: Activity, color: 'text-muted bg-white/5' },
} satisfies Record<
  MachineKind,
  { icon: typeof Activity; color: string }
>;

function HeartRateZones({ workout }: { workout: Workout }) {
  const total = zoneConfig.reduce(
    (sum, item) => sum + workout.summary.heartRateZoneDurations[item.zone],
    0,
  );
  return (
    <div>
      <div className="mb-2 flex items-center justify-between">
        <p className="text-[10px] font-semibold uppercase tracking-wider text-muted/70">
          Heart rate zones
        </p>
        <p className="flex items-center gap-1 text-[10px] font-bold text-coral">
          <Heart size={10} fill="currentColor" aria-hidden="true" />
          {workout.summary.averageHeartRateBpm} avg
        </p>
      </div>
      <div
        className="flex h-2.5 overflow-hidden rounded-full bg-white/5"
        aria-label={`Heart rate zones for ${machineLabel(workout.machineKind)} on ${formatDate(workout.startedAt)}`}
      >
        {zoneConfig.map(({ zone, label, color }) => {
          const value = workout.summary.heartRateZoneDurations[zone];
          const percent = total > 0 ? (value / total) * 100 : 0;
          return (
            <span
              key={zone}
              className="h-full border-r border-navy/30 last:border-0"
              style={{ width: `${percent}%`, backgroundColor: color }}
              title={`${label}: ${Math.round(value / 60)} min`}
            />
          );
        })}
      </div>
      <div className="mt-2 flex flex-wrap gap-x-3 gap-y-1">
        {zoneConfig.map(({ zone, label, color }) => (
          <span key={zone} className="flex items-center gap-1 text-[9px] text-muted">
            <span
              className="h-1.5 w-1.5 rounded-full"
              style={{ backgroundColor: color }}
              aria-hidden="true"
            />
            {label} {Math.round(workout.summary.heartRateZoneDurations[zone] / 60)}m
          </span>
        ))}
      </div>
    </div>
  );
}

function WorkoutCard({ workout }: { workout: Workout }) {
  const machine = machineConfig[workout.machineKind];
  const Icon = machine.icon;
  return (
    <article className="group rounded-2xl border border-white/[0.07] bg-ink/25 p-4 transition duration-200 hover:border-white/[0.13] hover:bg-ink/35 sm:p-5">
      <div className="grid gap-5 xl:grid-cols-[minmax(185px,0.9fr)_minmax(340px,1.4fr)_minmax(260px,1fr)_auto] xl:items-center">
        <div className="flex items-center gap-3">
          <div
            className={cn(
              'flex h-12 w-12 shrink-0 items-center justify-center rounded-xl',
              machine.color,
            )}
          >
            <Icon size={21} aria-hidden="true" />
          </div>
          <div>
            <h2 className="text-sm font-bold text-white">
              {machineLabel(workout.machineKind)} quest
            </h2>
            <p className="mt-1 flex items-center gap-1.5 text-[11px] text-muted">
              <Calendar size={11} aria-hidden="true" />
              {formatDate(workout.startedAt, 'long')}
            </p>
          </div>
        </div>

        <dl className="grid grid-cols-3 gap-2 border-y border-white/[0.06] py-4 xl:border-x xl:border-y-0 xl:px-5 xl:py-1">
          <div>
            <dt className="flex items-center gap-1 text-[9px] font-bold uppercase tracking-wider text-muted/65">
              <Route size={10} aria-hidden="true" />
              Distance
            </dt>
            <dd className="mt-1.5 text-sm font-bold text-white">
              {formatDistance(workout.summary.distanceMeters)}
            </dd>
          </div>
          <div>
            <dt className="flex items-center gap-1 text-[9px] font-bold uppercase tracking-wider text-muted/65">
              <Clock3 size={10} aria-hidden="true" />
              Duration
            </dt>
            <dd className="mt-1.5 text-sm font-bold text-white">
              {formatDuration(workout.summary.durationSeconds)}
            </dd>
          </div>
          <div>
            <dt className="flex items-center gap-1 text-[9px] font-bold uppercase tracking-wider text-muted/65">
              <Gauge size={10} aria-hidden="true" />
              Avg speed
            </dt>
            <dd className="mt-1.5 text-sm font-bold text-white">
              {workout.summary.averageSpeedKph.toFixed(1)}
              <span className="ml-1 text-[9px] font-medium text-muted">km/h</span>
            </dd>
          </div>
        </dl>

        <HeartRateZones workout={workout} />

        <div className="flex items-center justify-between rounded-xl bg-lavender/[0.07] px-3.5 py-3 xl:block xl:min-w-[92px] xl:text-right">
          <p className="flex items-center gap-1 text-[9px] font-bold uppercase tracking-wider text-lavender xl:justify-end">
            <Sparkles size={10} aria-hidden="true" />
            XP earned
          </p>
          <p className="mt-1 font-display text-lg font-semibold text-white">
            +{formatNumber(workout.xpEarned)}
          </p>
        </div>
      </div>
    </article>
  );
}

export function History() {
  const [filter, setFilter] = useState<TimeFilter>('month');
  const [sort, setSort] = useState<SortOption>('date');
  const {
    data: { workouts },
  } = useCardioData();

  const filteredWorkouts = useMemo(() => {
    const now = new Date();
    const weekStart = startOfWeek(now).getTime();
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).getTime();
    const cutoff =
      filter === 'week' ? weekStart : filter === 'month' ? monthStart : 0;
    return workouts
      .filter((workout) => new Date(workout.startedAt).getTime() >= cutoff)
      .sort((a, b) => {
        if (sort === 'distance') {
          return b.summary.distanceMeters - a.summary.distanceMeters;
        }
        if (sort === 'duration') {
          return b.summary.durationSeconds - a.summary.durationSeconds;
        }
        return (
          new Date(b.startedAt).getTime() - new Date(a.startedAt).getTime()
        );
      });
  }, [filter, sort, workouts]);

  const totalDistance = filteredWorkouts.reduce(
    (sum, workout) => sum + workout.summary.distanceMeters,
    0,
  );
  const totalDuration = filteredWorkouts.reduce(
    (sum, workout) => sum + workout.summary.durationSeconds,
    0,
  );

  return (
    <div className="page-enter">
      <PageHeader
        eyebrow="Quest archive"
        title="Workout history"
        description="Revisit every completed quest, compare performance, and see exactly where your training time went."
      />

      <Panel className="mb-5 p-4 sm:p-5">
        <div className="relative flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
          <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
            <SegmentedControl
              label="Workout time period"
              value={filter}
              onChange={setFilter}
              options={[
                { value: 'week', label: 'This week' },
                { value: 'month', label: 'This month' },
                { value: 'all', label: 'All time' },
              ]}
            />
            <div className="relative">
              <label htmlFor="history-sort" className="sr-only">
                Sort workouts
              </label>
              <select
                id="history-sort"
                value={sort}
                onChange={(event) => setSort(event.target.value as SortOption)}
                className="h-11 w-full appearance-none rounded-xl border border-white/[0.07] bg-ink/45 py-2 pl-3.5 pr-9 text-xs font-semibold text-white sm:w-auto"
              >
                <option value="date">Sort: Newest</option>
                <option value="distance">Sort: Distance</option>
                <option value="duration">Sort: Duration</option>
              </select>
              <ChevronDown
                size={14}
                className="pointer-events-none absolute right-3 top-3.5 text-muted"
                aria-hidden="true"
              />
            </div>
          </div>

          <dl className="flex items-center gap-5">
            <div>
              <dt className="text-[9px] font-bold uppercase tracking-wider text-muted/65">
                Workouts
              </dt>
              <dd className="mt-1 text-sm font-bold text-white">
                {filteredWorkouts.length}
              </dd>
            </div>
            <div className="h-8 w-px bg-white/[0.08]" aria-hidden="true" />
            <div>
              <dt className="text-[9px] font-bold uppercase tracking-wider text-muted/65">
                Distance
              </dt>
              <dd className="mt-1 text-sm font-bold text-white">
                {formatDistance(totalDistance)}
              </dd>
            </div>
            <div className="h-8 w-px bg-white/[0.08]" aria-hidden="true" />
            <div>
              <dt className="text-[9px] font-bold uppercase tracking-wider text-muted/65">
                Time
              </dt>
              <dd className="mt-1 text-sm font-bold text-white">
                {formatDuration(totalDuration)}
              </dd>
            </div>
          </dl>
        </div>
      </Panel>

      <section aria-label="Workouts" className="max-h-[calc(100vh-270px)] min-h-[420px] space-y-3 overflow-y-auto pr-1">
        {filteredWorkouts.length > 0 ? (
          filteredWorkouts.map((workout) => (
            <WorkoutCard key={workout.id} workout={workout} />
          ))
        ) : (
          <Panel className="flex min-h-72 flex-col items-center justify-center p-8 text-center">
            <Activity size={28} className="relative text-mint" aria-hidden="true" />
            <h2 className="relative mt-4 font-display text-lg font-semibold text-white">
              No workouts in this period
            </h2>
            <p className="relative mt-2 text-sm text-muted">
              Complete a Cardio Quest workout and it will appear here.
            </p>
          </Panel>
        )}
      </section>
    </div>
  );
}
