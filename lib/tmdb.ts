import { getSetting, setSetting } from './settings';

const TMDB_BASE = 'https://api.themoviedb.org/3';
const TMDB_IMG = 'https://image.tmdb.org/t/p';

// Free TMDb API key — rate limited but fine for personal use
// Users can add their own in settings if they want
const DEFAULT_TMDB_KEY = '0be08fd0eb12ea7c89b5646007b11bb0';

async function getTmdbKey(): Promise<string> {
  const custom = await getSetting('tmdb_api_key');
  return custom ?? DEFAULT_TMDB_KEY;
}

export interface TmdbMovie {
  id: number;
  title: string;
  posterPath: string | null;
  backdropPath: string | null;
  releaseDate: string;
  overview: string;
}

/**
 * Search TMDb for a movie by title, return the best match
 */
export async function searchMovie(title: string): Promise<TmdbMovie | null> {
  try {
    const key = await getTmdbKey();
    const query = encodeURIComponent(title);
    const resp = await fetch(
      `${TMDB_BASE}/search/movie?api_key=${key}&query=${query}&language=en-US&page=1`
    );
    if (!resp.ok) return null;

    const data = await resp.json();
    const results = data.results;
    if (!results || results.length === 0) return null;

    // Take first result (best match)
    const movie = results[0];
    return {
      id: movie.id,
      title: movie.title,
      posterPath: movie.poster_path,
      backdropPath: movie.backdrop_path,
      releaseDate: movie.release_date ?? '',
      overview: movie.overview ?? '',
    };
  } catch {
    return null;
  }
}

/**
 * Get poster URL at a specific size
 */
export function getPosterUrl(posterPath: string, size: 'w185' | 'w342' | 'w500' | 'original' = 'w342'): string {
  return `${TMDB_IMG}/${size}${posterPath}`;
}

/**
 * Get backdrop URL
 */
export function getBackdropUrl(backdropPath: string, size: 'w780' | 'w1280' | 'original' = 'w780'): string {
  return `${TMDB_IMG}/${size}${backdropPath}`;
}
