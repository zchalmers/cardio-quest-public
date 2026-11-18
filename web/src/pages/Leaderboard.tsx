import { useState } from 'react';
import {
  ArrowDown,
  ArrowUp,
  CalendarClock,
  Check,
  Crown,
  Gauge,
  Medal,
  Minus,
  Route,
  Shield,
  Sparkles,
  Trophy,
  Users,
} from 'lucide-react';
import type { LucideIcon } from 'lucide-react';
import { PageHeader } from '@/components/ui/PageHeader';
import { Panel } from '@/components/ui/Panel';
import { useCardioData } from '@/data/CardioDataProvider';
import { cn } from '@/lib/utils';
import type { LeaderboardEntry, LeaderboardKind } from '@/types';

interface LeaderboardTab {
  id: LeaderboardKind;
  label: string;
  shortLabel: string;
  description: string;
  icon: LucideIcon;
}

const tabs: LeaderboardTab[] = [
  {
    id: 'weeklyDistance',
    label: 'Weekly distance',
    shortLabel: 'Weekly',
    description: 'Total distance since Monday',
    icon: Route,
  },
  {
    id: 'allTimeDistance',
    label: 'All-time distance',
    shortLabel: 'All-time',
    description: 'Lifetime quest distance',
    icon: Trophy,
  },
  {
    id: 'speedRecords',
    label: 'Speed records',
    shortLabel: 'Speed',
    description: 'Fastest peak speed recorded',
    icon: Gauge,
  },
  {
    id: 'challengeCompletion',
    label: 'Challenge completion',
    shortLabel: 'Challenges',
    description: 'Weekly quests completed',
    icon: Check,
  },
];

function formatValue(entry: LeaderboardEntry): string {
  const digits = entry.unit === 'quests' ? 0 : 1;
  return `${entry.value.toFixed(digits)} ${entry.unit}`;
}

function Avatar({
  entry,
  size = 'default',
}: {
  entry: LeaderboardEntry;
  size?: 'default' | 'large';
}) {
  return (
    <div
      className={cn(
        'grid shrink-0 place-items-center rounded-2xl font-extrabold text-ink ring-4 ring-navy',
        size === 'large' ? 'h-16 w-16 text-sm' : 'h-10 w-10 text-xs',
      )}
      style={{ background: entry.avatarColor }}
      aria-hidden="true"
    >
      {entry.initials}
    </div>
  );
}

function Podium({
  board,
  boardLabel,
}: {
  board: LeaderboardEntry[];
  boardLabel: string;
}) {
  const positions = [board[1], board[0], board[2]].filter(
    (entry): entry is LeaderboardEntry => Boolean(entry),
  );
  return (
    <div className="grid grid-cols-3 items-end gap-2 sm:gap-4">
      {positions.map((entry) => {
        const isFirst = entry.rank === 1;
        return (
          <div
            key={entry.id}
            className={cn(
              'relative flex flex-col items-center rounded-t-2xl border border-b-0 px-2 pb-5 pt-4 text-center',
              isFirst
                ? 'h-[210px] border-gold/20 bg-gradient-to-b from-gold/[0.11] to-gold/[0.025]'
                : 'h-[178px] border-white/[0.08] bg-gradient-to-b from-white/[0.055] to-transparent',
            )}
          >
            {isFirst ? (
              <Crown
                size={21}
                className="absolute -top-7 text-gold"
                fill="currentColor"
                aria-label="First place"
              />
            ) : null}
            <div className="relative">
              <Avatar entry={entry} size="large" />
              <span
                className={cn(
                  'absolute -bottom-2 -right-1 grid h-6 w-6 place-items-center rounded-full text-[10px] font-black text-ink ring-2 ring-navy',
                  entry.rank === 1
                    ? 'bg-gold'
                    : entry.rank === 2
                      ? 'bg-[#C9D5DF]'
                      : 'bg-[#D69468]',
                )}
              >
                {entry.rank}
              </span>
            </div>
            <p className="mt-5 max-w-full truncate text-xs font-bold text-white sm:text-sm">
              {entry.displayName}
            </p>
            <p
              className={cn(
                'mt-2 font-display text-sm font-semibold sm:text-base',
                isFirst ? 'text-gold' : 'text-mint',
              )}
            >
              {formatValue(entry)}
            </p>
            <p className="mt-1 hidden text-[9px] text-muted sm:block">
              {entry.secondary}
            </p>
            <span className="sr-only">
              {entry.rank} place in {boardLabel}
            </span>
          </div>
        );
      })}
    </div>
  );
}

function Trend({ value }: { value: number }) {
  if (value > 0) {
    return (
      <span className="inline-flex items-center gap-0.5 text-success" aria-label={`Up ${value} places`}>
        <ArrowUp size={12} aria-hidden="true" />
        {value}
      </span>
    );
  }
  if (value < 0) {
    return (
      <span className="inline-flex items-center gap-0.5 text-coral" aria-label={`Down ${Math.abs(value)} places`}>
        <ArrowDown size={12} aria-hidden="true" />
        {Math.abs(value)}
      </span>
    );
  }
  return (
    <span className="inline-flex text-muted/60" aria-label="No rank change">
      <Minus size={12} aria-hidden="true" />
    </span>
  );
}

export function Leaderboard() {
  const [activeBoard, setActiveBoard] =
    useState<LeaderboardKind>('weeklyDistance');
  const {
    data: { leaderboards },
  } = useCardioData();
  const activeTab =
    tabs.find((tab) => tab.id === activeBoard) ?? tabs[0]!;
  const board = leaderboards[activeBoard];
  const currentPlayer = board.find((entry) => entry.isCurrentPlayer);

  return (
    <div className="page-enter">
      <PageHeader
        eyebrow="Community rankings"
        title="Leaderboard"
        description="See how your quest pace stacks up. Rankings refresh as new workouts and challenge results sync."
        action={
          <div className="inline-flex items-center gap-2 rounded-xl border border-white/[0.08] bg-white/[0.035] px-3.5 py-2.5 text-xs font-semibold text-muted">
            <CalendarClock size={14} className="text-mint" aria-hidden="true" />
            Resets in 3d 8h
          </div>
        }
      />

      <div className="mb-5 overflow-x-auto pb-1">
        <div
          className="inline-flex min-w-max gap-1 rounded-xl border border-white/[0.07] bg-ink/35 p-1"
          role="tablist"
          aria-label="Leaderboard category"
        >
          {tabs.map((tab) => (
            <button
              key={tab.id}
              id={`tab-${tab.id}`}
              type="button"
              role="tab"
              aria-selected={activeBoard === tab.id}
              aria-controls={`panel-${tab.id}`}
              onClick={() => setActiveBoard(tab.id)}
              className={cn(
                'flex items-center gap-2 rounded-lg px-3.5 py-2.5 text-[11px] font-semibold transition sm:px-4',
                activeBoard === tab.id
                  ? 'bg-panel-light text-white shadow-sm'
                  : 'text-muted hover:bg-white/[0.04] hover:text-white',
              )}
            >
              <tab.icon
                size={14}
                className={activeBoard === tab.id ? 'text-mint' : undefined}
                aria-hidden="true"
              />
              <span className="sm:hidden">{tab.shortLabel}</span>
              <span className="hidden sm:inline">{tab.label}</span>
            </button>
          ))}
        </div>
      </div>

      <div
        id={`panel-${activeBoard}`}
        role="tabpanel"
        aria-labelledby={`tab-${activeBoard}`}
        className="grid gap-5 xl:grid-cols-[minmax(330px,0.68fr)_minmax(0,1.32fr)]"
      >
        <div className="space-y-5">
          <Panel variant="highlight" className="p-5 sm:p-6">
            <div className="relative">
              <div className="mb-9 flex items-start justify-between">
                <div>
                  <p className="text-[10px] font-bold uppercase tracking-[0.2em] text-mint">
                    Top questers
                  </p>
                  <h2 className="mt-2 font-display text-xl font-semibold text-white">
                    {activeTab.label}
                  </h2>
                  <p className="mt-1 text-xs text-muted">{activeTab.description}</p>
                </div>
                <Trophy size={22} className="text-gold" aria-hidden="true" />
              </div>
              <Podium board={board} boardLabel={activeTab.label} />
            </div>
          </Panel>

          {currentPlayer ? (
            <Panel className="p-5">
              <div className="relative">
                <div className="flex items-center justify-between">
                  <p className="text-[10px] font-bold uppercase tracking-[0.18em] text-muted">
                    Your standing
                  </p>
                  <span className="rounded-md bg-mint/10 px-2 py-1 text-[9px] font-bold text-mint">
                    Top {Math.round((currentPlayer.rank / board.length) * 100)}%
                  </span>
                </div>
                <div className="mt-4 flex items-center gap-3">
                  <Avatar entry={currentPlayer} />
                  <div>
                    <p className="text-sm font-bold text-white">
                      {currentPlayer.displayName}
                    </p>
                    <p className="mt-0.5 text-[10px] text-muted">
                      {currentPlayer.secondary}
                    </p>
                  </div>
                  <div className="ml-auto text-right">
                    <p className="font-display text-xl font-semibold text-mint">
                      #{currentPlayer.rank}
                    </p>
                    <p className="mt-0.5 text-[10px] font-semibold text-white">
                      {formatValue(currentPlayer)}
                    </p>
                  </div>
                </div>
              </div>
            </Panel>
          ) : null}
        </div>

        <Panel className="p-5 sm:p-6">
          <div className="relative">
            <div className="mb-5 flex items-center justify-between">
              <div>
                <h2 className="font-display text-lg font-semibold text-white">
                  Full rankings
                </h2>
                <p className="mt-1 text-xs text-muted">
                  {board.length} active questers in your division
                </p>
              </div>
              <span className="flex items-center gap-1.5 rounded-lg bg-white/[0.04] px-2.5 py-2 text-[10px] font-semibold text-muted">
                <Users size={12} aria-hidden="true" />
                Emerald league
              </span>
            </div>

            <div className="overflow-x-auto">
              <table className="w-full min-w-[580px] border-separate border-spacing-0 text-left">
                <caption className="sr-only">
                  {activeTab.label} full ranking
                </caption>
                <thead>
                  <tr className="text-[9px] font-bold uppercase tracking-[0.14em] text-muted/65">
                    <th scope="col" className="border-b border-white/[0.07] px-3 pb-3">
                      Rank
                    </th>
                    <th scope="col" className="border-b border-white/[0.07] px-3 pb-3">
                      Quester
                    </th>
                    <th scope="col" className="border-b border-white/[0.07] px-3 pb-3">
                      Activity
                    </th>
                    <th scope="col" className="border-b border-white/[0.07] px-3 pb-3 text-right">
                      Score
                    </th>
                    <th scope="col" className="border-b border-white/[0.07] px-3 pb-3 text-right">
                      Trend
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {board.map((entry) => (
                    <tr
                      key={entry.id}
                      className={cn(
                        'transition-colors',
                        entry.isCurrentPlayer && 'bg-mint/[0.055]',
                      )}
                    >
                      <td className="border-b border-white/[0.05] px-3 py-3.5">
                        <span
                          className={cn(
                            'grid h-7 w-7 place-items-center rounded-lg text-[11px] font-extrabold',
                            entry.rank === 1
                              ? 'bg-gold/10 text-gold'
                              : entry.rank === 2
                                ? 'bg-white/[0.07] text-[#D8E1E8]'
                                : entry.rank === 3
                                  ? 'bg-[#D69468]/10 text-[#E2AA83]'
                                  : 'text-muted',
                          )}
                        >
                          {entry.rank <= 3 ? (
                            <Medal size={14} aria-label={`Rank ${entry.rank}`} />
                          ) : (
                            entry.rank
                          )}
                        </span>
                      </td>
                      <th
                        scope="row"
                        className="border-b border-white/[0.05] px-3 py-3.5"
                      >
                        <span className="flex items-center gap-3">
                          <Avatar entry={entry} />
                          <span>
                            <span className="block text-xs font-bold text-white">
                              {entry.displayName}
                              {entry.isCurrentPlayer ? (
                                <span className="ml-2 text-[9px] font-bold text-mint">
                                  YOU
                                </span>
                              ) : null}
                            </span>
                            <span className="mt-0.5 block text-[9px] text-muted">
                              Level {28 - entry.rank}
                            </span>
                          </span>
                        </span>
                      </th>
                      <td className="border-b border-white/[0.05] px-3 py-3.5 text-[11px] text-muted">
                        {entry.secondary}
                      </td>
                      <td className="border-b border-white/[0.05] px-3 py-3.5 text-right font-display text-sm font-semibold text-white">
                        {formatValue(entry)}
                      </td>
                      <td className="border-b border-white/[0.05] px-3 py-3.5 text-right text-[10px] font-bold">
                        <Trend value={entry.trend} />
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            <div className="mt-5 flex flex-col gap-3 rounded-xl border border-white/[0.06] bg-ink/25 p-4 sm:flex-row sm:items-center sm:justify-between">
              <div className="flex items-center gap-3">
                <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-lavender/10 text-lavender">
                  <Shield size={17} aria-hidden="true" />
                </div>
                <div>
                  <p className="text-xs font-bold text-white">Emerald league</p>
                  <p className="mt-0.5 text-[10px] text-muted">
                    Finish in the top 5 to advance
                  </p>
                </div>
              </div>
              <span className="flex items-center gap-1.5 text-[10px] font-bold text-gold">
                <Sparkles size={11} aria-hidden="true" />
                2,000 XP league reward
              </span>
            </div>
          </div>
        </Panel>
      </div>
    </div>
  );
}
