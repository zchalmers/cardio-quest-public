import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { fetchCardioQuestData } from '@/data/api';
import { sampleData } from '@/data/sampleData';
import type { CardioQuestExport } from '@/types';

interface CardioDataContextValue {
  data: CardioQuestExport;
  source: 'api' | 'sample';
  error: string | null;
}

const CardioDataContext = createContext<CardioDataContextValue | null>(null);

export function CardioDataProvider({ children }: { children: ReactNode }) {
  const [data, setData] = useState<CardioQuestExport>(sampleData);
  const [source, setSource] = useState<'api' | 'sample'>('sample');
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!import.meta.env.VITE_CARDIO_API_URL) return;
    const controller = new AbortController();
    void fetchCardioQuestData(controller.signal)
      .then((response) => {
        setData(response);
        setSource('api');
        setError(null);
      })
      .catch((reason: unknown) => {
        if (controller.signal.aborted) return;
        setError(
          reason instanceof Error
            ? reason.message
            : 'Unable to load the Cardio Quest API.',
        );
      });
    return () => controller.abort();
  }, []);

  const value = useMemo(
    () => ({ data, source, error }),
    [data, source, error],
  );

  return (
    <CardioDataContext.Provider value={value}>
      {children}
    </CardioDataContext.Provider>
  );
}

export function useCardioData(): CardioDataContextValue {
  const context = useContext(CardioDataContext);
  if (!context) {
    throw new Error('useCardioData must be used within CardioDataProvider');
  }
  return context;
}
