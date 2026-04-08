import { Platform } from 'react-native';
import { parse, subHours, subMinutes, setHours, setMinutes, setSeconds, isBefore } from 'date-fns';

// Lazy load expo-notifications to avoid crash if native module isn't ready
let Notifications: any = null;

function getNotifications() {
  if (!Notifications) {
    try {
      Notifications = require('expo-notifications');
      Notifications.setNotificationHandler({
        handleNotification: async () => ({
          shouldShowAlert: true,
          shouldPlaySound: true,
          shouldSetBadge: false,
        }),
      });
    } catch (e) {
      console.log('[NDPass] expo-notifications not available:', e);
      return null;
    }
  }
  return Notifications;
}

export async function requestPermissions(): Promise<boolean> {
  const N = getNotifications();
  if (!N) return false;
  try {
    const { status: existingStatus } = await N.getPermissionsAsync();
    let finalStatus = existingStatus;
    if (existingStatus !== 'granted') {
      const { status } = await N.requestPermissionsAsync();
      finalStatus = status;
    }
    if (finalStatus !== 'granted') return false;
    if (Platform.OS === 'android') {
      await N.setNotificationChannelAsync('reminders', {
        name: 'Show Reminders',
        importance: N.AndroidImportance.HIGH,
      });
    }
    return true;
  } catch { return false; }
}

export async function scheduleReminders(
  movieTitle: string, theater: string, date: string, time: string,
): Promise<string | null> {
  const N = getNotifications();
  if (!N) return null;
  
  try {
    const hasPermission = await requestPermissions();
    if (!hasPermission) return null;

    const showtime = parse(`${date} ${time}`, 'yyyy-MM-dd h:mm a', new Date());
    const now = new Date();
    const ids: string[] = [];

    const dayOf = setSeconds(setMinutes(setHours(new Date(showtime), 9), 0), 0);
    if (isBefore(now, dayOf)) {
      const id = await N.scheduleNotificationAsync({
        content: { title: `🎬 ${movieTitle} tonight`, body: `Tickets for ${theater} at ${time}`, sound: true },
        trigger: { type: N.SchedulableTriggerInputTypes.DATE, date: dayOf },
      });
      ids.push(id);
    }

    const twoHrs = subHours(showtime, 2);
    if (isBefore(now, twoHrs)) {
      const id = await N.scheduleNotificationAsync({
        content: { title: `🎬 ${movieTitle} in 2 hours`, body: `Showtime at ${time} — ${theater}`, sound: true },
        trigger: { type: N.SchedulableTriggerInputTypes.DATE, date: twoHrs },
      });
      ids.push(id);
    }

    const thirtyMin = subMinutes(showtime, 30);
    if (isBefore(now, thirtyMin)) {
      const id = await N.scheduleNotificationAsync({
        content: { title: `🎬 ${movieTitle} in 30 min`, body: `Head to ${theater} — showtime ${time}`, sound: true },
        trigger: { type: N.SchedulableTriggerInputTypes.DATE, date: thirtyMin },
      });
      ids.push(id);
    }

    return ids.length > 0 ? ids.join(',') : null;
  } catch (e) {
    console.log('[NDPass] Schedule reminders failed:', e);
    return null;
  }
}

export async function cancelReminders(notificationIds: string): Promise<void> {
  const N = getNotifications();
  if (!N) return;
  try {
    const ids = notificationIds.split(',').filter(Boolean);
    for (const id of ids) await N.cancelScheduledNotificationAsync(id);
  } catch {}
}
