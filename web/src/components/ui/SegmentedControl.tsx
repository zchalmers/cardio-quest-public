import { cn } from '@/lib/utils';

interface SegmentOption<T extends string> {
  value: T;
  label: string;
}

interface SegmentedControlProps<T extends string> {
  label: string;
  options: Array<SegmentOption<T>>;
  value: T;
  onChange: (value: T) => void;
  className?: string;
}

export function SegmentedControl<T extends string>({
  label,
  options,
  value,
  onChange,
  className,
}: SegmentedControlProps<T>) {
  return (
    <div
      className={cn(
        'inline-flex rounded-xl border border-white/[0.07] bg-ink/45 p-1',
        className,
      )}
      role="group"
      aria-label={label}
    >
      {options.map((option) => (
        <button
          key={option.value}
          type="button"
          onClick={() => onChange(option.value)}
          aria-pressed={value === option.value}
          className={cn(
            'rounded-lg px-3 py-2 text-xs font-semibold transition-all sm:px-3.5',
            value === option.value
              ? 'bg-panel-light text-white shadow-sm'
              : 'text-muted hover:bg-white/[0.04] hover:text-white',
          )}
        >
          {option.label}
        </button>
      ))}
    </div>
  );
}
