import type { LucideIcon } from 'lucide-react';
import { ArrowDownRight, ArrowUpRight } from 'lucide-react';
import { cn } from '@/lib/utils';
import { Panel } from '@/components/ui/Panel';

interface StatCardProps {
  label: string;
  value: string;
  detail: string;
  icon: LucideIcon;
  accent?: 'mint' | 'coral' | 'gold' | 'lavender' | 'blue';
  trend?: number;
  featured?: boolean;
  className?: string;
}

const accents = {
  mint: 'bg-mint/10 text-mint ring-mint/15',
  coral: 'bg-coral/10 text-coral ring-coral/15',
  gold: 'bg-gold/10 text-gold ring-gold/15',
  lavender: 'bg-lavender/10 text-lavender ring-lavender/15',
  blue: 'bg-[#79B8FF]/10 text-[#79B8FF] ring-[#79B8FF]/15',
};

export function StatCard({
  label,
  value,
  detail,
  icon: Icon,
  accent = 'mint',
  trend,
  featured = false,
  className,
}: StatCardProps) {
  return (
    <Panel
      variant={featured ? 'highlight' : 'default'}
      className={cn(
        'group min-h-[140px] p-4 transition duration-300 hover:-translate-y-0.5 hover:border-white/15 sm:min-h-[146px] sm:p-5',
        className,
      )}
    >
      <div className="relative flex items-start justify-between">
        <p className="text-xs font-semibold uppercase tracking-[0.12em] text-muted">
          {label}
        </p>
        <span
          className={cn(
            'flex h-9 w-9 items-center justify-center rounded-xl ring-1',
            accents[accent],
          )}
        >
          <Icon size={17} strokeWidth={2.2} aria-hidden="true" />
        </span>
      </div>
      <p className="relative mt-4 font-display text-2xl font-semibold tracking-[-0.04em] text-white sm:text-3xl">
        {value}
      </p>
      <div className="relative mt-2 flex items-center gap-1.5 text-xs text-muted">
        {trend !== undefined ? (
          <span
            className={cn(
              'inline-flex items-center gap-0.5 font-bold',
              trend >= 0 ? 'text-success' : 'text-coral',
            )}
          >
            {trend >= 0 ? (
              <ArrowUpRight size={13} aria-hidden="true" />
            ) : (
              <ArrowDownRight size={13} aria-hidden="true" />
            )}
            {Math.abs(trend)}%
          </span>
        ) : null}
        <span>{detail}</span>
      </div>
    </Panel>
  );
}
