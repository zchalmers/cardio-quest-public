import { lazy, Suspense } from 'react';
import { LoaderCircle } from 'lucide-react';
import { Navigate, Route, Routes } from 'react-router-dom';
import { AppShell } from '@/components/layout/AppShell';

const Dashboard = lazy(() =>
  import('@/pages/Dashboard').then((module) => ({
    default: module.Dashboard,
  })),
);
const History = lazy(() =>
  import('@/pages/History').then((module) => ({ default: module.History })),
);
const Achievements = lazy(() =>
  import('@/pages/Achievements').then((module) => ({
    default: module.Achievements,
  })),
);
const Analytics = lazy(() =>
  import('@/pages/Analytics').then((module) => ({
    default: module.Analytics,
  })),
);
const Leaderboard = lazy(() =>
  import('@/pages/Leaderboard').then((module) => ({
    default: module.Leaderboard,
  })),
);

function PageLoader() {
  return (
    <div
      className="flex min-h-[60vh] items-center justify-center"
      role="status"
      aria-label="Loading page"
    >
      <LoaderCircle className="animate-spin text-mint" aria-hidden="true" />
    </div>
  );
}

export default function App() {
  return (
    <Suspense fallback={<PageLoader />}>
      <Routes>
        <Route element={<AppShell />}>
          <Route index element={<Dashboard />} />
          <Route path="history" element={<History />} />
          <Route path="achievements" element={<Achievements />} />
          <Route path="analytics" element={<Analytics />} />
          <Route path="leaderboard" element={<Leaderboard />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
      </Routes>
    </Suspense>
  );
}
