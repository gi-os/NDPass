import { getActiveTickets } from './database';
import { getPosterUrl } from './tmdb';
import { Platform, NativeModules } from 'react-native';

/**
 * Update widget data and trigger a timeline reload.
 */
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

    // Write to App Group UserDefaults
    try {
      const SharedGroupPreferences = require('react-native-shared-group-preferences').default;
      const jsonString = data ? JSON.stringify(data) : '';
      await SharedGroupPreferences.setItem('nextShowing', jsonString, 'group.com.gios.ndpass');
      console.log('[NDPass] ✓ Widget UserDefaults written');
    } catch (e: any) {
      console.log('[NDPass] SharedGroupPreferences error:', e.message ?? e);
    }

    // Reload widget timelines
    try {
      // WidgetKit reload is available if expo-widgets or a custom module exposes it
      // For now, the widget refreshes on its own every 30 min
      // or when the user removes and re-adds it
      if (NativeModules.WidgetModule?.reloadAllTimelines) {
        NativeModules.WidgetModule.reloadAllTimelines();
        console.log('[NDPass] ✓ Widget timelines reloaded');
      }
    } catch {
      // Expected — no custom WidgetModule yet
    }
  } catch (err) {
    console.log('[NDPass] Widget update failed:', err);
  }
}
