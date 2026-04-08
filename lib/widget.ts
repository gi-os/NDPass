import { getActiveTickets } from './database';
import { getPosterUrl } from './tmdb';
import { Platform } from 'react-native';
import * as FileSystem from 'expo-file-system';

/**
 * Update widget data by writing a JSON file.
 * 
 * Strategy: Write to the app's documents directory.
 * The SwiftUI widget reads from the App Group UserDefaults.
 * 
 * Since we can't write to UserDefaults from JS without a native module,
 * we use a workaround: write to a file in the shared App Group container.
 * The widget's timeline provider reads this file.
 * 
 * For this to work fully, we need the native module installed.
 * For now, we log what WOULD be written so you can verify the data flow.
 * The widget will show placeholder data until the native bridge is set up.
 * 
 * TODO: Replace with @callstack/react-native-app-group-data or a custom
 * Expo module once we do a prebuild with native deps.
 */
export async function updateWidget(): Promise<void> {
  if (Platform.OS !== 'ios') return;

  try {
    const tickets = await getActiveTickets();

    if (tickets.length === 0) {
      console.log('[NDPass] Widget: no upcoming tickets');
      return;
    }

    const next = tickets[0];
    const data = {
      movieTitle: next.movieTitle,
      theater: next.theater,
      date: next.date,
      time: next.time,
      posterUrl: next.posterPath ? getPosterUrl(next.posterPath, 'w342') : null,
      dominantColor: '#E8A63A',
    };

    console.log('[NDPass] Widget data ready:', JSON.stringify(data));

    // Write to app's document directory as a fallback
    // The widget can't read this directly but it proves the data pipeline works
    const widgetDataPath = `${FileSystem.documentDirectory}widget_data.json`;
    await FileSystem.writeAsStringAsync(widgetDataPath, JSON.stringify(data));
    console.log('[NDPass] Widget data written to:', widgetDataPath);

    // Try native UserDefaults write if available
    try {
      const SharedGroupPreferences = require('react-native-shared-group-preferences').default;
      await SharedGroupPreferences.setItem('nextShowing', JSON.stringify(data), 'group.com.gios.ndpass');
      console.log('[NDPass] ✓ Widget UserDefaults updated');
    } catch {
      console.log('[NDPass] Native widget bridge not linked — widget shows placeholder');
      console.log('[NDPass] Run: npm install react-native-shared-group-preferences && npx expo prebuild --clean');
    }
  } catch (err) {
    console.log('[NDPass] Widget update failed:', err);
  }
}
