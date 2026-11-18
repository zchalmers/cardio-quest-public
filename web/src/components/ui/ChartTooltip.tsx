interface TooltipPayload {
  color?: string;
  dataKey?: string | number;
  name?: string | number;
  value?: string | number;
}

interface ChartTooltipProps {
  active?: boolean;
  label?: string | number;
  payload?: TooltipPayload[];
  unit?: string;
  valueFormatter?: (value: number) => string;
}

export function ChartTooltip({
  active,
  label,
  payload,
  unit = '',
  valueFormatter,
}: ChartTooltipProps) {
  if (!active || !payload?.length) return null;
  return (
    <div className="min-w-32 rounded-xl border border-white/10 bg-[#0B1C29]/95 px-3.5 py-3 shadow-2xl backdrop-blur-xl">
      <p className="mb-2 text-[11px] font-bold uppercase tracking-wider text-muted">
        {label}
      </p>
      <div className="space-y-1.5">
        {payload.map((item) => {
          const numericValue =
            typeof item.value === 'number'
              ? item.value
              : Number.parseFloat(String(item.value ?? 0));
          return (
            <div
              key={`${String(item.dataKey)}-${String(item.name)}`}
              className="flex items-center justify-between gap-5 text-xs"
            >
              <span className="flex items-center gap-2 text-muted">
                <span
                  className="h-2 w-2 rounded-full"
                  style={{ backgroundColor: item.color ?? '#65F2D0' }}
                  aria-hidden="true"
                />
                {item.name}
              </span>
              <span className="font-bold text-white">
                {valueFormatter
                  ? valueFormatter(numericValue)
                  : `${numericValue.toLocaleString()}${unit}`}
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
}
