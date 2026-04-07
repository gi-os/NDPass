import { useEffect } from 'react';
import * as FileSystem from 'expo-file-system';
import * as Linking from 'expo-linking';
import { Platform, Alert } from 'react-native';
import { router } from 'expo-router';

const APP_GROUP = 'group.com.gios.ndpass';

/**
 * Check if a ticket image was shared via the Share Extension.
 * The extension saves the image to the App Group container
 * and sets a flag file. This hook checks for that flag on app launch
 * and when the app receives the ndpass://scan/shared URL.
 */
export function useShareExtension() {
  useEffect(() => {
    // Check on mount
    checkForSharedImage();

    // Listen for URL scheme
    const subscription = Linking.addEventListener('url', (event) => {
      if (event.url.includes('scan/shared')) {
        checkForSharedImage();
      }
    });

    return () => subscription.remove();
  }, []);
}

async function checkForSharedImage() {
  if (Platform.OS !== 'ios') return;

  try {
    // The shared container path — this needs react-native-shared-group-preferences
    // or a native module to access. For now we log the intent.
    console.log('[NDPass] Checking for shared ticket image...');

    // When the share extension saves an image, it'll be at:
    // <AppGroup>/shared_ticket.jpg with a pending_share.flag
    // This requires native bridge to read from App Group container.
    // The full implementation needs the native module — for now,
    // navigate to scan tab so user can pick the image.

    // TODO: Once react-native-shared-group-preferences is installed,
    // read the image from the App Group and auto-start scanning.
  } catch (err) {
    console.log('[NDPass] Share check failed:', err);
  }
}

/**
 * Get the path to a shared image if one exists.
 * Returns null if no pending share.
 */
export async function getSharedImagePath(): Promise<string | null> {
  // This will be implemented once the native bridge is set up
  // For now returns null — the share extension opens the app
  // and the user taps "Library" to pick the screenshot
  return null;
}
