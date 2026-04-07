import { getActiveTickets } from './database';
import { getPosterUrl } from './tmdb';
import { Platform, NativeModules } from 'react-native';

const APP_GROUP = 'group.com.gios.ndpass';

/**
 * Update the widget with the next upcoming showing.
 * Writes to shared App Group UserDefaults so the SwiftUI widget can read it.
 *
 * Call this after every ticket insert/delete/update.
 */
export async function updateWidget(): Promise<void> {
  if (Platform.OS !== 'ios') return;

  try {
    const tickets = await getActiveTickets();

    if (tickets.length === 0) {
      await writeToAppGroup(null);
      return;
    }

    // First ticket is the soonest (already sorted by date ASC)
    const next = tickets[0];

    const data = {
      movieTitle: next.movieTitle,
      theater: next.theater,
      date: next.date,
      time: next.time,
      posterUrl: next.posterPath ? getPosterUrl(next.posterPath, 'w342') : null,
      dominantColor: '#E8A63A', // default amber — could extract from poster later
    };

    await writeToAppGroup(data);
  } catch (err) {
    console.log('[NDPass] Widget update failed:', err);
  }
}

/**
 * Write data to shared UserDefaults via expo-modules or direct native call.
 * For now, we use a simple approach that works with expo-shared-preferences
 * or a tiny native module. Falls back gracefully if not available.
 */
async function writeToAppGroup(data: any): Promise<void> {
  // Try using the SharedGroupPreferences if available
  try {
    const SharedGroupPreferences = require('react-native-shared-group-preferences').default;
    if (data) {
      await SharedGroupPreferences.setItem('nextShowing', JSON.stringify(data), APP_GROUP);
    } else {
      await SharedGroupPreferences.setItem('nextShowing', '', APP_GROUP);
    }
    console.log('[NDPass] Widget data updated');
  } catch {
    // Package not installed yet — log but don't crash
    console.log('[NDPass] Widget bridge not installed yet (react-native-shared-group-preferences)');
    console.log('[NDPass] Widget data would be:', JSON.stringify(data));
  }
}
