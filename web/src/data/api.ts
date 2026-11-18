import { sampleData } from '@/data/sampleData';
import type { CardioQuestExport } from '@/types';

/**
 * Loads the Flutter JSON export. Development falls back to realistic local data
 * so the dashboard is fully usable before an API endpoint is configured.
 */
export async function fetchCardioQuestData(
  signal?: AbortSignal,
): Promise<CardioQuestExport> {
  const endpoint = import.meta.env.VITE_CARDIO_API_URL;
  if (!endpoint) return sampleData;

  const response = await fetch(endpoint, {
    headers: { Accept: 'application/json' },
    signal,
  });
  if (!response.ok) {
    throw new Error(`Cardio Quest API returned ${response.status}`);
  }
  return (await response.json()) as CardioQuestExport;
}
