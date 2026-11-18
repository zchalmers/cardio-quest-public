import type { HTMLAttributes, ReactNode } from 'react';
import { cn } from '@/lib/utils';

interface PanelProps extends HTMLAttributes<HTMLDivElement> {
  children: ReactNode;
  variant?: 'default' | 'highlight' | 'flat';
}

export function Panel({
  children,
  className,
  variant = 'default',
  ...props
}: PanelProps) {
  return (
    <div
      className={cn(
        'relative overflow-hidden rounded-2xl',
        variant === 'default' && 'glass-panel',
        variant === 'highlight' &&
          'border border-mint/20 bg-quest-gradient shadow-glow',
        variant === 'flat' && 'border border-white/[0.07] bg-ink/25',
        className,
      )}
      {...props}
    >
      {children}
    </div>
  );
}
