import { getActiveTickets } from './database';
import { getPosterUrl } from './tmdb';
import { Platform, NativeModules } from 'react-native';
import * as FileSystem from 'expo-file-system';

const GROUP = 'group.com.gios.ndpass';

export async function updateWidget(): Promise<void> {
  if (Platform.OS !== 'ios') return;

  try {
    const tickets = await getActiveTickets();
    const next = tickets.length > 0 ? tickets[0] : null;
    const posterUrl = next?.posterPath ? getPosterUrl(next.posterPath, 'w342') : null;

    const data = next ? JSON.stringify({
      movieTitle: next.movieTitle,
      theater: next.theater,
      date: next.date,
      time: next.time,
      posterUrl,
      dominantColor: '#E8A63A',
    }) : '';

    console.log('[NDPass] Widget data:', next ? next.movieTitle : 'empty');

    // Try our custom native module first (direct UserDefaults + WidgetKit reload)
    const { SharedStorage } = NativeModules;
    if (SharedStorage?.set) {
      await SharedStorage.set('nextShowing', data, GROUP);
      console.log('[NDPass] ✓ SharedStorage: nextShowing written');

      // Download and save poster
      if (posterUrl) {
        try {
          const dlPath = `${FileSystem.cacheDirectory}widget_poster.jpg`;
          const result = await FileSystem.downloadAsync(posterUrl, dlPath);
          if (result.status === 200) {
            const b64 = await FileSystem.readAsStringAsync(dlPath, {
              encoding: FileSystem.EncodingType.Base64,
            });
            await SharedStorage.set('widgetPosterBase64', b64, GROUP);
            console.log(`[NDPass] ✓ SharedStorage: poster saved (${Math.round(b64.length / 1024)}KB)`);
          }
        } catch (e) {
          console.log('[NDPass] Poster download failed:', e);
        }
      } else {
        await SharedStorage.set('widgetPosterBase64', '', GROUP);
      }

      console.log('[NDPass] ✓ Widget timelines reloaded');
      return;
    }

    // Fallback: try react-native-shared-group-preferences
    console.log('[NDPass] SharedStorage native module not found, trying fallback...');
    try {
      const SGP = require('react-native-shared-group-preferences').default;
      await SGP.setItem('nextShowing', data, GROUP);
      console.log('[NDPass] ✓ Fallback: nextShowing written');
    } catch (e: any) {
      console.log('[NDPass] All widget bridges failed:', e.message ?? e);
    }
  } catch (err) {
    console.log('[NDPass] Widget update failed:', err);
  }
}
