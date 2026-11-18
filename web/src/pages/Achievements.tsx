import { useMemo, useState } from 'react';
import {
  Activity,
  CalendarDays,
  Check,
  Coins,
  Flame,
  Globe2,
  Heart,
  HeartPulse,
  Lock,
  Map,
  Medal,
  Rocket,
  Shapes,
  Sparkles,
  Sunrise,
  Swords,
  Trophy,
  Zap,
} from 'lucide-react';
import type { LucideIcon } from 'lucide-react';
import { PageHeader } from '@/components/ui/PageHeader';
import { Panel } from '@/components/ui/Panel';
import { ProgressBar } from '@/components/ui/ProgressBar';
import { useCardioData } from '@/data/CardioDataProvider';
import { cn, formatCompactNumber, formatDate } from '@/lib/utils';
import type {
  Achievement,
  AchievementCategory,
  AchievementTier,
} from '@/types';

type CategoryFilter = 'all' | AchievementCategory;

const iconMap: Record<string, LucideIcon> = {
  activity: Activity,
  calendar: CalendarDays,
  coins: Coins,
  flame: Flame,
  globe: Globe2,
  heart: Heart,
  'heart-pulse': HeartPulse,
  map: Map,
  rocket: Rocket,
  shapes: Shapes,
  sparkles: Sparkles,
  sunrise: Sunrise,
  swords: Swords,
  trophy: Trophy,
  zap: Zap,
};

const tierStyle: Record<
  AchievementTier,
  { label: string; icon: string; border: string; badge: string; bar: string }
> = {
  bronze: {
    label: 'Bronze',
    icon: 'text-[#D69468] bg-[#D69468]/10',
    border: 'border-[#D69468]/15',
    badge: 'text-[#E2AA83] bg-[#D69468]/10',
    bar: 'from-[#C9855A] to-[#E2AA83]',
  },
  silver: {
    label: 'Silver',
    icon: 'text-[#BFCAD4] bg-[#BFCAD4]/10',
    border: 'border-[#BFCAD4]/15',
    badge: 'text-[#D8E1E8] bg-[#BFCAD4]/10',
    bar: 'from-[#91A2B0] to-[#D8E1E8]',
  },
  gold: {
    label: 'Gold',
    icon: 'text-gold bg-gold/10',
    border: 'border-gold/15',
    badge: 'text-gold bg-gold/10',
    bar: 'from-[#E9A93C] to-gold',
  },
  platinum: {
    label: 'Platinum',
    icon: 'text-mint bg-mint/10',
    border: 'border-mint/15',
    badge: 'text-mint bg-mint/10',
    bar: 'from-[#58CDB8] to-mint',
  },
  legendary: {
    label: 'Legendary',
    icon: 'text-lavender bg-lavender/10',
    border: 'border-lavender/20',
    badge: 'text-lavender bg-lavender/10',
    bar: 'from-coral via-lavender to-mint',
  },
};

const categories: Array<{ value: CategoryFilter; label: string }> = [
  { value: 'all', label: 'All' },
  { value: 'distance', label: 'Distance' },
  { value: 'speed', label: 'Speed' },
  { value: 'combo', label: 'Combo' },
  { value: 'zones', label: 'HR zones' },
  { value: 'consistency', label: 'Consistency' },
  { value: 'coins', label: 'Coins' },
  { value: 'multiplayer', label: 'Multiplayer' },
  { value: 'calories', label: 'Calories' },
  { value: 'variety', label: 'Variety' },
  { value: 'lifestyle', label: 'Lifestyle' },
  { value: 'heartRate', label: 'Heart rate' },
];

function displayProgress(achievement: Achievement): {
  value: string;
  target: string;
} {
  if (achievement.unit === 'm') {
    return {
      value: `${(achievement.value / 1000).toFixed(0)} km`,
      target: `${achievement.target / 1000} km`,
    };
  }
  if (achievement.unit === 'sec') {
    return {
      value: `${(achievement.value / 3600).toFixed(1)} hr`,
      target: `${achievement.target / 3600} hr`,
    };
  }
  return {
    value: formatCompactNumber(achievement.value),
    target: `${formatCompactNumber(achievement.target)} ${achievement.unit}`,
  };
}

function AchievementCard({ achievement }: { achievement: Achievement }) {
  const Icon = iconMap[achievement.icon] ?? Medal;
  const style = tierStyle[achievement.tier];
  const isUnlocked = Boolean(achievement.unlockedAt);
  const percent = Math.min(100, (achievement.value / achievement.target) * 100);
  const progress = displayProgress(achievement);
  return (
    <article
      className={cn(
        'group relative overflow-hidden rounded-2xl border bg-gradient-to-br from-panel/80 to-[#0D202F] p-5 transition duration-300 hover:-translate-y-0.5 hover:shadow-panel',
        style.border,
        !isUnlocked && 'grayscale-[0.2]',
      )}
    >
      {isUnlocked ? (
        <div
          className="pointer-events-none absolute -right-12 -top-12 h-32 w-32 rounded-full bg-mint/[0.045] blur-2xl"
          aria-hidden="true"
        />
      ) : null}
      <div className="relative flex items-start justify-between">
        <div
          className={cn(
            'flex h-12 w-12 items-center justify-center rounded-2xl ring-1 ring-inset ring-white/[0.04]',
            style.icon,
          )}
        >
          <Icon size={23} strokeWidth={2} aria-hidden="true" />
        </div>
        <div className="flex items-center gap-2">
          <span
            className={cn(
              'rounded-md px-2 py-1 text-[9px] font-bold uppercase tracking-wider',
              style.badge,
            )}
          >
            {style.label}
          </span>
          <span
            className={cn(
              'flex h-7 w-7 items-center justify-center rounded-full',
              isUnlocked
                ? 'bg-success/10 text-success'
                : 'bg-white/[0.05] text-muted/60',
            )}
          >
            {isUnlocked ? (
              <Check size={14} strokeWidth={2.7} aria-hidden="true" />
            ) : (
              <Lock size={12} aria-hidden="true" />
            )}
          </span>
        </div>
      </div>
      <div className="relative mt-5">
        <h2 className="font-display text-base font-semibold text-white">
          {achievement.name}
        </h2>
        <p className="mt-1.5 min-h-10 text-xs leading-5 text-muted">
          {achievement.description}
        </p>
      </div>
      <div className="relative mt-5 border-t border-white/[0.06] pt-4">
        {isUnlocked ? (
          <div className="flex items-center justify-between">
            <span className="flex items-center gap-1.5 text-[10px] font-bold uppercase tracking-wider text-success">
              <Sparkles size={11} aria-hidden="true" />
              Unlocked
            </span>
            <time className="text-[10px] text-muted" dateTime={achievement.unlockedAt}>
              {formatDate(achievement.unlockedAt ?? '')}
            </time>
          </div>
        ) : (
          <>
            <div className="mb-2 flex items-center justify-between text-[10px]">
              <span className="font-bold text-white">{progress.value}</span>
              <span className="text-muted">{progress.target}</span>
            </div>
            <ProgressBar
              value={achievement.value}
              max={achievement.target}
              label={`${achievement.name} progress`}
              fillClassName={style.bar}
            />
            <p className="mt-2 text-right text-[10px] font-bold text-muted">
              {Math.round(percent)}%
            </p>
          </>
        )}
      </div>
    </article>
  );
}

export function Achievements() {
  const [category, setCategory] = useState<CategoryFilter>('all');
  const {
    data: { achievements },
  } = useCardioData();
  const unlocked = achievements.filter(
    (achievement) => achievement.unlockedAt,
  ).length;
  const completion = Math.round(
    (unlocked / achievements.length) * 100,
  );
  const filtered = useMemo(
    () =>
      category === 'all'
        ? achievements
        : achievements.filter(
            (achievement) => achievement.category === category,
          ),
    [achievements, category],
  );
  const nearestLocked = [...achievements]
    .filter((achievement) => !achievement.unlockedAt)
    .sort((a, b) => b.value / b.target - a.value / a.target)[0];
  const latestUnlocked = [...achievements]
    .filter((achievement) => achievement.unlockedAt)
    .sort(
      (a, b) =>
        new Date(b.unlockedAt ?? 0).getTime() -
        new Date(a.unlockedAt ?? 0).getTime(),
    )[0];
  const LatestIcon = latestUnlocked
    ? (iconMap[latestUnlocked.icon] ?? Trophy)
    : Trophy;

  return (
    <div className="page-enter">
      <PageHeader
        eyebrow="Trophy room"
        title="Achievements"
        description="Every milestone tells part of your quest. Keep pushing to turn the remaining emblems into earned rewards."
      />

      <section className="mb-5 grid gap-4 lg:grid-cols-[minmax(0,1.2fr)_minmax(280px,0.55fr)]">
        <Panel variant="highlight" className="p-6">
          <div className="relative flex flex-col gap-6 sm:flex-row sm:items-center">
            <div
              className="relative grid h-28 w-28 shrink-0 place-items-center rounded-full"
              style={{
                background: `conic-gradient(#65F2D0 ${completion}%, rgba(255,255,255,0.07) ${completion}% 100%)`,
              }}
              role="img"
              aria-label={`${completion} percent of achievements unlocked`}
            >
              <div className="grid h-[92px] w-[92px] place-items-center rounded-full bg-[#102433]">
                <div className="text-center">
                  <p className="font-display text-2xl font-bold text-white">
                    {completion}%
                  </p>
                  <p className="text-[9px] font-bold uppercase tracking-wider text-muted">
                    Complete
                  </p>
                </div>
              </div>
            </div>
            <div>
              <p className="text-[10px] font-bold uppercase tracking-[0.2em] text-mint">
                Collection progress
              </p>
              <h2 className="mt-2 font-display text-2xl font-semibold text-white">
                {unlocked} of {achievements.length} emblems unlocked
              </h2>
              <p className="mt-2 max-w-xl text-xs leading-5 text-muted">
                {achievements.length - unlocked} achievements are still in
                reach.
                {nearestLocked ? (
                  <>
                    {' '}
                    Your closest is{' '}
                    <span className="font-semibold text-white">
                      {nearestLocked.name}
                    </span>{' '}
                    at{' '}
                    {Math.round(
                      (nearestLocked.value / nearestLocked.target) * 100,
                    )}
                    % completion.
                  </>
                ) : null}
              </p>
              <div className="mt-4 flex flex-wrap gap-2">
                {(['gold', 'platinum', 'legendary'] as AchievementTier[]).map(
                  (tier) => {
                    const count = achievements.filter(
                      (achievement) =>
                        achievement.tier === tier && achievement.unlockedAt,
                    ).length;
                    return (
                      <span
                        key={tier}
                        className={cn(
                          'rounded-lg px-2.5 py-1.5 text-[10px] font-bold capitalize',
                          tierStyle[tier].badge,
                        )}
                      >
                        {count} {tier}
                      </span>
                    );
                  },
                )}
              </div>
            </div>
          </div>
        </Panel>

        <Panel className="p-6">
          <div className="relative flex h-full flex-col justify-between">
            <div className="flex items-start justify-between">
              <div>
                <p className="text-[10px] font-bold uppercase tracking-[0.18em] text-lavender">
                  Latest unlock
                </p>
                <h2 className="mt-2 font-display text-xl font-semibold text-white">
                  {latestUnlocked?.name ?? 'No unlocks yet'}
                </h2>
                <p className="mt-1 text-xs text-muted">
                  {latestUnlocked?.description ?? 'Start a quest to make progress'}
                </p>
              </div>
              <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-mint/10 text-mint">
                <LatestIcon size={21} aria-hidden="true" />
              </div>
            </div>
            <p className="mt-6 flex items-center gap-2 text-[11px] font-semibold text-success">
              <Check size={13} aria-hidden="true" />
              {latestUnlocked?.unlockedAt
                ? `Earned ${formatDate(latestUnlocked.unlockedAt)}`
                : 'Ready for your first milestone'}
            </p>
          </div>
        </Panel>
      </section>

      <div className="mb-5 overflow-x-auto pb-1">
        <div
          className="inline-flex min-w-max gap-1 rounded-xl border border-white/[0.07] bg-ink/35 p-1"
          role="group"
          aria-label="Filter achievements by category"
        >
          {categories.map((item) => (
            <button
              key={item.value}
              type="button"
              onClick={() => setCategory(item.value)}
              aria-pressed={category === item.value}
              className={cn(
                'rounded-lg px-3 py-2 text-[11px] font-semibold transition',
                category === item.value
                  ? 'bg-panel-light text-white'
                  : 'text-muted hover:bg-white/[0.04] hover:text-white',
              )}
            >
              {item.label}
            </button>
          ))}
        </div>
      </div>

      <section
        className="grid gap-4 sm:grid-cols-2 2xl:grid-cols-3"
        aria-label={`${category === 'all' ? 'All' : category} achievements`}
      >
        {filtered.map((achievement) => (
          <AchievementCard key={achievement.id} achievement={achievement} />
        ))}
      </section>
    </div>
  );
}
