import { getActiveTickets } from './database';
import { getPosterUrl } from './tmdb';
import { Platform } from 'react-native';

export async function updateWidget(): Promise<void> {
  if (Platform.OS !== 'ios') return;

  try {
    const tickets = await getActiveTickets();

    const data = tickets.length > 0 ? {
      movieTitle: tickets[0].movieTitle,
      theater: tickets[0].theater,
      date: tickets[0].date,
      time: tickets[0].time,
      posterUrl: tickets[0].posterPath ? getPosterUrl(tickets[0].posterPath, 'w342') : null,
      dominantColor: '#E8A63A',
    } : null;

    console.log('[NDPass] Widget data:', data ? data.movieTitle : 'empty');

    try {
      const SharedGroupPreferences = require('react-native-shared-group-preferences').default;
      const jsonString = data ? JSON.stringify(data) : '';
      await SharedGroupPreferences.setItem('nextShowing', jsonString, 'group.com.gios.ndpass');
      console.log('[NDPass] ✓ Widget UserDefaults written');

      // Download poster to App Group container so widget can read it locally
      if (data?.posterUrl) {
        try {
          const resp = await fetch(data.posterUrl);
          const blob = await resp.blob();
          const reader = new FileReader();
          const base64 = await new Promise<string>((resolve) => {
            reader.onloadend = () => {
              const result = reader.result as string;
              // Strip data URI prefix
              const base64Data = result.split(',')[1] ?? result;
              resolve(base64Data);
            };
            reader.readAsDataURL(blob);
          });
          await SharedGroupPreferences.setItem('widgetPosterBase64', base64, 'group.com.gios.ndpass');
          console.log('[NDPass] ✓ Widget poster saved to App Group');
        } catch (e) {
          console.log('[NDPass] Poster download failed:', e);
        }
      }
    } catch (e: any) {
      console.log('[NDPass] SharedGroupPreferences error:', e.message ?? e);
    }
  } catch (err) {
    console.log('[NDPass] Widget update failed:', err);
  }
}
