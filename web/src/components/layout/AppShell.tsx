import { useState } from 'react';
import {
  BarChart3,
  ChevronRight,
  History,
  LayoutDashboard,
  Menu,
  Mountain,
  Sparkles,
  Trophy,
  X,
} from 'lucide-react';
import { NavLink, Outlet } from 'react-router-dom';
import { useCardioData } from '@/data/CardioDataProvider';
import { cn } from '@/lib/utils';

const navigation = [
  { label: 'Dashboard', to: '/', icon: LayoutDashboard, end: true },
  { label: 'History', to: '/history', icon: History },
  { label: 'Achievements', to: '/achievements', icon: Sparkles },
  { label: 'Analytics', to: '/analytics', icon: BarChart3 },
  { label: 'Leaderboard', to: '/leaderboard', icon: Trophy },
];

function Brand() {
  return (
    <div className="flex items-center gap-3">
      <div className="relative flex h-10 w-10 items-center justify-center overflow-hidden rounded-xl bg-mint text-ink shadow-[0_0_28px_rgba(101,242,208,0.25)]">
        <Mountain size={23} strokeWidth={2.6} aria-hidden="true" />
        <span className="absolute bottom-1.5 right-1.5 h-1.5 w-1.5 rounded-full bg-coral ring-2 ring-mint" />
      </div>
      <div>
        <p className="font-display text-[17px] font-bold tracking-[-0.03em] text-white">
          Cardio Quest
        </p>
        <p className="text-[9px] font-bold uppercase tracking-[0.23em] text-mint/80">
          Player portal
        </p>
      </div>
    </div>
  );
}

interface SidebarProps {
  onNavigate?: () => void;
}

function Sidebar({ onNavigate }: SidebarProps) {
  const {
    data: { profile },
  } = useCardioData();
  return (
    <div className="flex h-full flex-col">
      <div className="px-6 pb-8 pt-6">
        <Brand />
      </div>
      <nav aria-label="Main navigation" className="flex-1 px-3">
        <p className="mb-3 px-3 text-[9px] font-bold uppercase tracking-[0.2em] text-muted/60">
          Quest log
        </p>
        <ul className="space-y-1">
          {navigation.map(({ label, to, icon: Icon, end }) => (
            <li key={to}>
              <NavLink
                to={to}
                end={end}
                onClick={onNavigate}
                className={({ isActive }) =>
                  cn(
                    'group flex items-center gap-3 rounded-xl px-3 py-3 text-sm font-semibold transition-all',
                    isActive
                      ? 'bg-mint/[0.11] text-mint'
                      : 'text-muted hover:bg-white/[0.04] hover:text-white',
                  )
                }
              >
                {({ isActive }) => (
                  <>
                    <Icon
                      size={18}
                      strokeWidth={isActive ? 2.4 : 1.9}
                      aria-hidden="true"
                    />
                    <span>{label}</span>
                    <ChevronRight
                      size={14}
                      className={cn(
                        'ml-auto transition-transform',
                        isActive
                          ? 'translate-x-0 opacity-100'
                          : '-translate-x-1 opacity-0 group-hover:translate-x-0 group-hover:opacity-60',
                      )}
                      aria-hidden="true"
                    />
                  </>
                )}
              </NavLink>
            </li>
          ))}
        </ul>
      </nav>
      <div className="m-4 rounded-2xl border border-white/[0.07] bg-ink/35 p-3">
        <div className="flex items-center gap-3">
          <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-coral to-lavender text-xs font-extrabold text-ink">
            {profile.initials}
          </div>
          <div className="min-w-0">
            <p className="truncate text-xs font-bold text-white">
              {profile.displayName}
            </p>
            <p className="mt-0.5 truncate text-[10px] text-muted">
              Lv. {profile.level} · {profile.rankTitle}
            </p>
          </div>
          <span className="ml-auto h-2 w-2 shrink-0 rounded-full bg-success shadow-[0_0_10px_rgba(112,228,154,0.7)]">
            <span className="sr-only">Data synced</span>
          </span>
        </div>
      </div>
    </div>
  );
}

export function AppShell() {
  const [mobileOpen, setMobileOpen] = useState(false);
  return (
    <div className="min-h-screen">
      <aside className="fixed inset-y-0 left-0 z-30 hidden w-[244px] border-r border-white/[0.07] bg-[#091925]/90 backdrop-blur-xl lg:block">
        <Sidebar />
      </aside>

      <header className="sticky top-0 z-20 flex h-16 items-center justify-between border-b border-white/[0.07] bg-navy/90 px-4 backdrop-blur-xl lg:hidden">
        <Brand />
        <button
          type="button"
          onClick={() => setMobileOpen(true)}
          className="flex h-10 w-10 items-center justify-center rounded-xl border border-white/10 bg-white/[0.04] text-white"
          aria-label="Open navigation"
          aria-expanded={mobileOpen}
          aria-controls="mobile-navigation"
        >
          <Menu size={20} aria-hidden="true" />
        </button>
      </header>

      {mobileOpen ? (
        <div className="fixed inset-0 z-50 lg:hidden">
          <button
            className="absolute inset-0 bg-ink/75 backdrop-blur-sm"
            type="button"
            aria-label="Close navigation"
            onClick={() => setMobileOpen(false)}
          />
          <aside
            id="mobile-navigation"
            className="absolute inset-y-0 left-0 w-[min(86vw,300px)] border-r border-white/10 bg-[#091925] shadow-2xl"
          >
            <button
              type="button"
              onClick={() => setMobileOpen(false)}
              className="absolute right-3 top-3 flex h-10 w-10 items-center justify-center rounded-xl text-muted hover:bg-white/5 hover:text-white"
              aria-label="Close navigation"
            >
              <X size={20} aria-hidden="true" />
            </button>
            <Sidebar onNavigate={() => setMobileOpen(false)} />
          </aside>
        </div>
      ) : null}

      <main className="min-h-screen lg:pl-[244px]">
        <div className="mx-auto max-w-[1500px] px-4 py-7 sm:px-6 sm:py-9 lg:px-8 xl:px-10">
          <Outlet />
        </div>
      </main>

      <div
        className="pointer-events-none fixed right-[-11rem] top-[-14rem] -z-10 h-[34rem] w-[34rem] rounded-full bg-mint/[0.035] blur-3xl"
        aria-hidden="true"
      />
    </div>
  );
}
