import { getActiveTickets } from './database';
import { getPosterUrl } from './tmdb';
import { Platform } from 'react-native';
import * as FileSystem from 'expo-file-system';

export async function updateWidget(): Promise<void> {
  if (Platform.OS !== 'ios') return;

  try {
    const tickets = await getActiveTickets();

    const next = tickets.length > 0 ? tickets[0] : null;
    const posterUrl = next?.posterPath ? getPosterUrl(next.posterPath, 'w342') : null;

    const data = next ? {
      movieTitle: next.movieTitle,
      theater: next.theater,
      date: next.date,
      time: next.time,
      posterUrl: posterUrl,
      dominantColor: '#E8A63A',
    } : null;

    console.log('[NDPass] Widget data:', data ? data.movieTitle : 'empty');

    // Download poster as base64 using expo-file-system (reliable)
    let posterBase64: string | null = null;
    if (posterUrl) {
      try {
        const downloadPath = `${FileSystem.cacheDirectory}widget_poster.jpg`;
        const result = await FileSystem.downloadAsync(posterUrl, downloadPath);
        if (result.status === 200) {
          posterBase64 = await FileSystem.readAsStringAsync(downloadPath, {
            encoding: FileSystem.EncodingType.Base64,
          });
          console.log(`[NDPass] ✓ Poster downloaded (${Math.round(posterBase64.length / 1024)}KB base64)`);
        }
      } catch (e) {
        console.log('[NDPass] Poster download failed:', e);
      }
    }

    // Write to App Group UserDefaults
    try {
      const SharedGroupPreferences = require('react-native-shared-group-preferences').default;
      const group = 'group.com.gios.ndpass';

      // Write showing data
      await SharedGroupPreferences.setItem('nextShowing', data ? JSON.stringify(data) : '', group);

      // Write poster base64 separately (UserDefaults can handle it)
      if (posterBase64) {
        await SharedGroupPreferences.setItem('widgetPosterBase64', posterBase64, group);
        console.log('[NDPass] ✓ Poster base64 written to App Group');
      } else {
        await SharedGroupPreferences.setItem('widgetPosterBase64', '', group);
      }

      console.log('[NDPass] ✓ Widget UserDefaults written');
    } catch (e: any) {
      console.log('[NDPass] SharedGroupPreferences error:', e.message ?? e);
    }
  } catch (err) {
    console.log('[NDPass] Widget update failed:', err);
  }
}
