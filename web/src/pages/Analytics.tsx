import {
  Activity,
  Bike,
  CalendarDays,
  Clock3,
  Flame,
  Footprints,
  Gauge,
  Heart,
  Medal,
  Route,
  Sparkles,
  Waves,
} from 'lucide-react';
import type { LucideIcon } from 'lucide-react';
import {
  Area,
  AreaChart,
  CartesianGrid,
  Cell,
  Line,
  LineChart,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import { ChartTooltip } from '@/components/ui/ChartTooltip';
import { PageHeader } from '@/components/ui/PageHeader';
import { Panel } from '@/components/ui/Panel';
import { useCardioData } from '@/data/CardioDataProvider';
import {
  cn,
  formatDate,
  formatDistance,
  formatDuration,
  startOfDay,
  startOfWeek,
} from '@/lib/utils';
import type { HeartRateZone, MachineKind, Workout } from '@/types';

const zonePalette: Array<{
  zone: Exclude<HeartRateZone, 'unknown'>;
  name: string;
  color: string;
}> = [
  { zone: 'recovery', name: 'Recovery', color: '#79B8FF' },
  { zone: 'aerobic', name: 'Aerobic', color: '#70E49A' },
  { zone: 'tempo', name: 'Tempo', color: '#FFD166' },
  { zone: 'threshold', name: 'Threshold', color: '#FF8B6B' },
  { zone: 'peak', name: 'Peak', color: '#FF5572' },
];

const machineIcons = {
  treadmill: Footprints,
  indoorBike: Bike,
  rower: Waves,
  crossTrainer: Activity,
  simulator: Sparkles,
  unknown: Activity,
} satisfies Record<MachineKind, LucideIcon>;

function speedProgression(workouts: Workout[]) {
  return workouts
    .filter((workout) => workout.machineKind === 'treadmill')
    .slice(0, 26)
    .reverse()
    .map((workout) => ({
      date: new Intl.DateTimeFormat('en-US', {
        month: 'short',
        day: 'numeric',
      }).format(new Date(workout.startedAt)),
      speed: workout.summary.averageSpeedKph,
      max: workout.summary.maxSpeedKph,
    }));
}

function weeklyTrends(allWorkouts: Workout[]) {
  const now = new Date();
  const currentWeek = startOfWeek(now);
  return Array.from({ length: 16 }, (_, index) => {
    const weekStart = new Date(currentWeek);
    weekStart.setDate(currentWeek.getDate() - (15 - index) * 7);
    const weekEnd = new Date(weekStart);
    weekEnd.setDate(weekStart.getDate() + 7);
    const workouts = allWorkouts.filter((workout) => {
      const date = new Date(workout.startedAt);
      return date >= weekStart && date < weekEnd;
    });
    return {
      week: new Intl.DateTimeFormat('en-US', {
        month: 'short',
        day: 'numeric',
      }).format(weekStart),
      distance: Number(
        (
          workouts.reduce(
            (sum, workout) => sum + workout.summary.distanceMeters,
            0,
          ) / 1000
        ).toFixed(1),
      ),
    };
  });
}

function heatmapDays(workouts: Workout[]) {
  const today = startOfDay();
  const firstDay = new Date(today);
  firstDay.setDate(today.getDate() - 17 * 7 - ((today.getDay() + 6) % 7));
  const distanceByDay = new Map<string, number>();
  for (const workout of workouts) {
    const key = workout.startedAt.slice(0, 10);
    distanceByDay.set(
      key,
      (distanceByDay.get(key) ?? 0) + workout.summary.distanceMeters / 1000,
    );
  }

  return Array.from({ length: 18 * 7 }, (_, index) => {
    const date = new Date(firstDay);
    date.setDate(firstDay.getDate() + index);
    const key = date.toISOString().slice(0, 10);
    const distance = Number((distanceByDay.get(key) ?? 0).toFixed(1));
    const intensity =
      distance === 0 ? 0 : distance < 4 ? 1 : distance < 8 ? 2 : distance < 13 ? 3 : 4;
    return { date, key, distance, intensity, isFuture: date > today };
  });
}

function personalRecords(workouts: Workout[]) {
  const longestDistance = workouts.reduce((best, workout) =>
    workout.summary.distanceMeters > best.summary.distanceMeters ? workout : best,
  );
  const fastest = workouts.reduce((best, workout) =>
    workout.summary.maxSpeedKph > best.summary.maxSpeedKph ? workout : best,
  );
  const longestDuration = workouts.reduce((best, workout) =>
    workout.summary.durationSeconds > best.summary.durationSeconds
      ? workout
      : best,
  );
  const highestCombo = workouts.reduce((best, workout) =>
    workout.summary.maxCombo > best.summary.maxCombo ? workout : best,
  );
  return [
    {
      label: 'Longest distance',
      value: formatDistance(longestDistance.summary.distanceMeters),
      workout: longestDistance,
      icon: Route,
    },
    {
      label: 'Top speed',
      value: `${fastest.summary.maxSpeedKph.toFixed(1)} km/h`,
      workout: fastest,
      icon: Gauge,
    },
    {
      label: 'Longest workout',
      value: formatDuration(longestDuration.summary.durationSeconds),
      workout: longestDuration,
      icon: Clock3,
    },
    {
      label: 'Highest combo',
      value: `${highestCombo.summary.maxCombo.toFixed(1)}×`,
      workout: highestCombo,
      icon: Flame,
    },
  ];
}

function SectionHeading({
  title,
  description,
}: {
  title: string;
  description: string;
}) {
  return (
    <div>
      <h2 className="font-display text-lg font-semibold text-white">{title}</h2>
      <p className="mt-1 text-xs text-muted">{description}</p>
    </div>
  );
}

export function Analytics() {
  const {
    data: { profile, workouts },
  } = useCardioData();
  const totalZoneTime = Object.values(profile.zoneSeconds).reduce(
    (sum, value) => sum + value,
    0,
  );
  const zoneData = zonePalette.map((item) => ({
    ...item,
    value: Math.round(profile.zoneSeconds[item.zone] / 60),
    percent: Math.round((profile.zoneSeconds[item.zone] / totalZoneTime) * 100),
  }));
  const averageHeartRate = Math.round(
    workouts.reduce(
      (sum, workout) => sum + workout.summary.averageHeartRateBpm,
      0,
    ) / workouts.length,
  );
  const weeksActive = Math.max(
    1,
    Math.ceil(
      (Date.now() -
        new Date(workouts[workouts.length - 1]?.startedAt ?? Date.now()).getTime()) /
        (7 * 86_400_000),
    ),
  );
  const averageWeeklyDistance = profile.totalDistanceMeters / weeksActive;
  const heatmap = heatmapDays(workouts);
  const records = personalRecords(workouts);

  return (
    <div className="page-enter">
      <PageHeader
        eyebrow="Performance lab"
        title="Analytics"
        description="Spot the patterns behind your progress, from heart-rate intensity to weekly volume and personal bests."
      />

      <section aria-label="Analytics overview" className="mb-5 grid grid-cols-2 gap-3 xl:grid-cols-4">
        {[
          {
            label: 'Weekly average',
            value: formatDistance(averageWeeklyDistance),
            detail: 'across active weeks',
            icon: Route,
            color: 'text-mint bg-mint/10',
          },
          {
            label: 'Training time',
            value: formatDuration(profile.totalPlaytimeSeconds),
            detail: 'all-time active time',
            icon: Clock3,
            color: 'text-[#79B8FF] bg-[#79B8FF]/10',
          },
          {
            label: 'Average HR',
            value: `${averageHeartRate} bpm`,
            detail: 'across all workouts',
            icon: Heart,
            color: 'text-coral bg-coral/10',
          },
          {
            label: 'Active calories',
            value: `${Math.round(profile.totalCalories / 1000)}k`,
            detail: 'total kcal burned',
            icon: Flame,
            color: 'text-gold bg-gold/10',
          },
        ].map((stat) => (
          <Panel key={stat.label} className="p-4 sm:p-5">
            <div className="relative flex items-start justify-between gap-3">
              <div>
                <p className="text-[9px] font-bold uppercase tracking-wider text-muted/70">
                  {stat.label}
                </p>
                <p className="mt-2 font-display text-xl font-semibold text-white sm:text-2xl">
                  {stat.value}
                </p>
                <p className="mt-1 text-[10px] text-muted">{stat.detail}</p>
              </div>
              <span
                className={cn(
                  'flex h-9 w-9 shrink-0 items-center justify-center rounded-xl',
                  stat.color,
                )}
              >
                <stat.icon size={17} aria-hidden="true" />
              </span>
            </div>
          </Panel>
        ))}
      </section>

      <section className="grid gap-5 xl:grid-cols-[minmax(330px,0.75fr)_minmax(0,1.25fr)]">
        <Panel className="p-5 sm:p-6">
          <div className="relative">
            <SectionHeading
              title="Heart-rate distribution"
              description="All-time minutes by training zone"
            />
            <div className="mt-3 grid items-center sm:grid-cols-[minmax(180px,0.9fr)_1fr] xl:grid-cols-1 2xl:grid-cols-[minmax(180px,0.9fr)_1fr]">
              <div className="relative h-56" role="img" aria-label="Donut chart showing all-time heart rate zone distribution">
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart accessibilityLayer>
                    <Pie
                      data={zoneData}
                      dataKey="value"
                      nameKey="name"
                      cx="50%"
                      cy="50%"
                      innerRadius={58}
                      outerRadius={82}
                      paddingAngle={3}
                      cornerRadius={5}
                      stroke="transparent"
                      isAnimationActive={false}
                    >
                      {zoneData.map((zone) => (
                        <Cell key={zone.zone} fill={zone.color} />
                      ))}
                    </Pie>
                    <Tooltip
                      content={
                        <ChartTooltip
                          valueFormatter={(value) => `${value} min`}
                        />
                      }
                    />
                  </PieChart>
                </ResponsiveContainer>
                <div className="pointer-events-none absolute inset-0 grid place-items-center text-center">
                  <div>
                    <p className="font-display text-xl font-semibold text-white">
                      {Math.round(totalZoneTime / 3600)}h
                    </p>
                    <p className="text-[9px] font-bold uppercase tracking-wider text-muted">
                      Zone time
                    </p>
                  </div>
                </div>
              </div>
              <div className="space-y-2.5">
                {zoneData.map((zone) => (
                  <div key={zone.zone} className="flex items-center gap-2.5">
                    <span
                      className="h-2.5 w-2.5 rounded-full"
                      style={{ backgroundColor: zone.color }}
                      aria-hidden="true"
                    />
                    <span className="flex-1 text-[11px] text-muted">{zone.name}</span>
                    <span className="text-[11px] font-bold text-white">
                      {zone.percent}%
                    </span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </Panel>

        <Panel className="p-5 sm:p-6">
          <div className="relative">
            <div className="flex items-start justify-between gap-4">
              <SectionHeading
                title="Speed progression"
                description="Average and maximum running speed over time"
              />
              <div className="hidden items-center gap-3 text-[9px] font-semibold text-muted sm:flex">
                <span className="flex items-center gap-1.5">
                  <span className="h-2 w-2 rounded-full bg-mint" />
                  Average
                </span>
                <span className="flex items-center gap-1.5">
                  <span className="h-2 w-2 rounded-full bg-lavender" />
                  Maximum
                </span>
              </div>
            </div>
            <div className="mt-5 h-72" role="img" aria-label="Line chart showing average and maximum workout speed over time">
              <ResponsiveContainer width="100%" height="100%">
                <LineChart
                  data={speedProgression(workouts)}
                  margin={{ top: 4, right: 8, left: -22, bottom: 0 }}
                  accessibilityLayer
                >
                  <CartesianGrid
                    vertical={false}
                    stroke="rgba(169,186,200,0.09)"
                    strokeDasharray="3 5"
                  />
                  <XAxis
                    dataKey="date"
                    axisLine={false}
                    tickLine={false}
                    interval={4}
                    tick={{ fill: '#718797', fontSize: 10 }}
                    dy={9}
                  />
                  <YAxis
                    axisLine={false}
                    tickLine={false}
                    tick={{ fill: '#718797', fontSize: 10 }}
                    domain={['dataMin - 2', 'dataMax + 2']}
                  />
                  <Tooltip
                    content={<ChartTooltip unit=" km/h" />}
                    cursor={{ stroke: 'rgba(101,242,208,0.18)' }}
                  />
                  <Line
                    type="monotone"
                    dataKey="max"
                    name="Maximum"
                    stroke="#B8A1FF"
                    strokeWidth={1.6}
                    strokeDasharray="4 5"
                    dot={false}
                    isAnimationActive={false}
                    activeDot={{ r: 4, fill: '#B8A1FF', stroke: '#0B1C29' }}
                  />
                  <Line
                    type="monotone"
                    dataKey="speed"
                    name="Average"
                    stroke="#65F2D0"
                    strokeWidth={2.5}
                    dot={false}
                    isAnimationActive={false}
                    activeDot={{ r: 5, fill: '#65F2D0', stroke: '#0B1C29', strokeWidth: 3 }}
                  />
                </LineChart>
              </ResponsiveContainer>
            </div>
          </div>
        </Panel>
      </section>

      <section className="mt-5 grid gap-5 xl:grid-cols-[minmax(0,1.35fr)_minmax(330px,0.65fr)]">
        <Panel className="p-5 sm:p-6">
          <div className="relative">
            <div className="flex items-start justify-between">
              <SectionHeading
                title="Distance trend"
                description="Weekly totals across the last four months"
              />
              <span className="rounded-lg bg-success/10 px-2.5 py-1 text-[10px] font-bold text-success">
                +11.8%
              </span>
            </div>
            <div className="mt-5 h-64" role="img" aria-label="Area chart showing weekly distance totals over four months">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart
                  data={weeklyTrends(workouts)}
                  margin={{ top: 4, right: 8, left: -23, bottom: 0 }}
                  accessibilityLayer
                >
                  <defs>
                    <linearGradient id="distanceFill" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor="#65F2D0" stopOpacity={0.34} />
                      <stop offset="100%" stopColor="#65F2D0" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid
                    vertical={false}
                    stroke="rgba(169,186,200,0.09)"
                    strokeDasharray="3 5"
                  />
                  <XAxis
                    dataKey="week"
                    axisLine={false}
                    tickLine={false}
                    interval={3}
                    tick={{ fill: '#718797', fontSize: 10 }}
                    dy={9}
                  />
                  <YAxis
                    axisLine={false}
                    tickLine={false}
                    tick={{ fill: '#718797', fontSize: 10 }}
                    tickFormatter={(value: number) => `${value}`}
                  />
                  <Tooltip content={<ChartTooltip unit=" km" />} />
                  <Area
                    type="monotone"
                    dataKey="distance"
                    name="Distance"
                    stroke="#65F2D0"
                    strokeWidth={2.5}
                    fill="url(#distanceFill)"
                    isAnimationActive={false}
                    activeDot={{ r: 5, fill: '#65F2D0', stroke: '#0B1C29', strokeWidth: 3 }}
                  />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </div>
        </Panel>

        <Panel className="p-5 sm:p-6">
          <div className="relative">
            <SectionHeading
              title="Workout frequency"
              description="Your training rhythm over 18 weeks"
            />
            <div className="mt-7 overflow-x-auto pb-2">
              <div className="min-w-[460px]">
                <div
                  className="grid grid-flow-col grid-rows-7 gap-1.5"
                  role="img"
                  aria-label={`${workouts.length} workouts logged over the displayed 18 week period`}
                >
                  {heatmap.map((day) => (
                    <span
                      key={day.key}
                      className={cn(
                        'h-[14px] w-[14px] rounded-[4px] border border-white/[0.025]',
                        day.isFuture
                          ? 'bg-transparent'
                          : day.intensity === 0
                            ? 'bg-white/[0.045]'
                            : day.intensity === 1
                              ? 'bg-mint/20'
                              : day.intensity === 2
                                ? 'bg-mint/40'
                                : day.intensity === 3
                                  ? 'bg-mint/65'
                                  : 'bg-mint',
                      )}
                      title={`${formatDate(day.date.toISOString(), 'long')}: ${day.distance} km`}
                    />
                  ))}
                </div>
                <div className="mt-4 flex items-center justify-end gap-1.5 text-[9px] text-muted">
                  <span className="mr-1">Less</span>
                  {[0, 1, 2, 3, 4].map((level) => (
                    <span
                      key={level}
                      className={cn(
                        'h-2.5 w-2.5 rounded-[3px]',
                        level === 0
                          ? 'bg-white/[0.045]'
                          : level === 1
                            ? 'bg-mint/20'
                            : level === 2
                              ? 'bg-mint/40'
                              : level === 3
                                ? 'bg-mint/65'
                                : 'bg-mint',
                      )}
                    />
                  ))}
                  <span className="ml-1">More</span>
                </div>
              </div>
            </div>
            <div className="mt-4 flex items-center justify-between rounded-xl bg-ink/30 px-3.5 py-3 text-[10px]">
              <span className="flex items-center gap-1.5 text-muted">
                <CalendarDays size={12} aria-hidden="true" />
                Current consistency
              </span>
              <span className="font-bold text-mint">4.2 workouts / week</span>
            </div>
          </div>
        </Panel>
      </section>

      <section className="mt-5">
        <Panel className="p-5 sm:p-6">
          <div className="relative">
            <div className="mb-5 flex items-center justify-between">
              <SectionHeading
                title="Personal records"
                description="Your strongest performances across every machine"
              />
              <Medal size={21} className="text-gold" aria-hidden="true" />
            </div>
            <div className="overflow-x-auto">
              <table className="w-full min-w-[680px] border-separate border-spacing-0 text-left">
                <caption className="sr-only">
                  Cardio Quest personal record performances
                </caption>
                <thead>
                  <tr className="text-[9px] font-bold uppercase tracking-[0.14em] text-muted/65">
                    <th scope="col" className="border-b border-white/[0.07] px-3 pb-3">
                      Record
                    </th>
                    <th scope="col" className="border-b border-white/[0.07] px-3 pb-3">
                      Best
                    </th>
                    <th scope="col" className="border-b border-white/[0.07] px-3 pb-3">
                      Quest type
                    </th>
                    <th scope="col" className="border-b border-white/[0.07] px-3 pb-3">
                      Date set
                    </th>
                    <th scope="col" className="border-b border-white/[0.07] px-3 pb-3 text-right">
                      XP earned
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {records.map((record) => {
                    const MachineIcon = machineIcons[record.workout.machineKind];
                    return (
                      <tr key={record.label} className="group">
                        <th
                          scope="row"
                          className="border-b border-white/[0.05] px-3 py-4 text-xs font-semibold text-white"
                        >
                          <span className="flex items-center gap-2.5">
                            <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-gold/10 text-gold">
                              <record.icon size={15} aria-hidden="true" />
                            </span>
                            {record.label}
                          </span>
                        </th>
                        <td className="border-b border-white/[0.05] px-3 py-4 font-display text-sm font-semibold text-mint">
                          {record.value}
                        </td>
                        <td className="border-b border-white/[0.05] px-3 py-4 text-xs text-muted">
                          <span className="flex items-center gap-2">
                            <MachineIcon size={14} aria-hidden="true" />
                            {record.workout.machineKind === 'indoorBike'
                              ? 'Ride'
                              : record.workout.machineKind === 'rower'
                                ? 'Row'
                                : 'Run'}
                          </span>
                        </td>
                        <td className="border-b border-white/[0.05] px-3 py-4 text-xs text-muted">
                          {formatDate(record.workout.startedAt, 'long')}
                        </td>
                        <td className="border-b border-white/[0.05] px-3 py-4 text-right text-xs font-bold text-lavender">
                          +{record.workout.xpEarned.toLocaleString()}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </div>
        </Panel>
      </section>
    </div>
  );
}
