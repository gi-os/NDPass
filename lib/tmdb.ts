import { getSetting } from './settings';

const TMDB_BASE = 'https://api.themoviedb.org/3';
const TMDB_IMG = 'https://image.tmdb.org/t/p';

export interface TmdbMovie {
  id: number;
  title: string;
  posterPath: string | null;
  backdropPath: string | null;
  releaseDate: string;
  overview: string;
}

async function getTmdbKey(): Promise<string | null> {
  return getSetting('tmdb_api_key');
}

export async function searchMovie(title: string): Promise<TmdbMovie | null> {
  const results = await searchMovies(title);
  return results.length > 0 ? results[0] : null;
}

export async function searchMovies(title: string, limit: number = 5): Promise<TmdbMovie[]> {
  try {
    const key = await getTmdbKey();
    if (!key) {
      console.log('[NDPass] No TMDb API key — skip poster lookup. Add one in Settings.');
      return [];
    }

    const query = encodeURIComponent(title);
    const resp = await fetch(
      `${TMDB_BASE}/search/movie?api_key=${key}&query=${query}&language=en-US&page=1`
    );
    if (!resp.ok) {
      console.log('[NDPass] TMDb error:', resp.status);
      return [];
    }

    const data = await resp.json();
    const results = data.results;
    if (!results || results.length === 0) return [];

    return results.slice(0, limit).map((movie: any) => ({
      id: movie.id,
      title: movie.title,
      posterPath: movie.poster_path,
      backdropPath: movie.backdrop_path,
      releaseDate: movie.release_date ?? '',
      overview: movie.overview ?? '',
    }));
  } catch (err) {
    console.log('[NDPass] TMDb search failed:', err);
    return [];
  }
}

export function getPosterUrl(posterPath: string, size: 'w185' | 'w342' | 'w500' | 'original' = 'w342'): string {
  return `${TMDB_IMG}/${size}${posterPath}`;
}

export function getBackdropUrl(backdropPath: string, size: 'w780' | 'w1280' | 'original' = 'w780'): string {
  return `${TMDB_IMG}/${size}${backdropPath}`;
}
