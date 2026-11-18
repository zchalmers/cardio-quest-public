import { cn } from '@/lib/utils';

interface ProgressBarProps {
  value: number;
  max?: number;
  label: string;
  className?: string;
  fillClassName?: string;
}

export function ProgressBar({
  value,
  max = 100,
  label,
  className,
  fillClassName,
}: ProgressBarProps) {
  const percent = Math.min(100, Math.max(0, (value / max) * 100));
  return (
    <div
      className={cn(
        'h-2 overflow-hidden rounded-full bg-white/[0.07]',
        className,
      )}
      role="progressbar"
      aria-label={label}
      aria-valuemin={0}
      aria-valuemax={max}
      aria-valuenow={Math.min(max, value)}
    >
      <div
        className={cn(
          'h-full rounded-full bg-gradient-to-r from-mint to-[#78BFFF] transition-[width] duration-700',
          fillClassName,
        )}
        style={{ width: `${percent}%` }}
      />
    </div>
  );
}
