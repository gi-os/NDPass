import { Platform, NativeModules } from 'react-native';

const GROUP = 'group.com.gios.ndpass';

/**
 * Check if a ticket image was shared via the Share Extension.
 * The extension saves the image to the App Group container as shared_ticket.jpg
 * and sets a pending_share.flag file.
 *
 * Returns the base64 image data if a pending share exists, null otherwise.
 * Clears the flag after reading.
 */
export async function checkForSharedImage(): Promise<string | null> {
  if (Platform.OS !== 'ios') return null;

  try {
    const { SharedStorage } = NativeModules;
    if (!SharedStorage?.get) {
      console.log('[NDPass] SharedStorage not available for share check');
      return null;
    }

    // Check for pending share flag
    const flag = await SharedStorage.get('pendingShareFlag', GROUP);
    if (!flag || flag !== '1') return null;

    console.log('[NDPass] Found pending shared ticket!');

    // Read the shared image base64
    const imageBase64 = await SharedStorage.get('sharedTicketBase64', GROUP);
    if (!imageBase64) {
      console.log('[NDPass] No image data in share');
      return null;
    }

    // Clear the flag
    await SharedStorage.set('pendingShareFlag', '', GROUP);

    console.log(`[NDPass] Shared image loaded (${Math.round(imageBase64.length / 1024)}KB)`);
    return imageBase64;
  } catch (err) {
    console.log('[NDPass] Share check failed:', err);
    return null;
  }
}
