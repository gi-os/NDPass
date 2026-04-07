import * as Notifications from 'expo-notifications';
import { Platform } from 'react-native';
import { parse, subHours, subMinutes, setHours, setMinutes, setSeconds, isBefore } from 'date-fns';

Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldPlaySound: true,
    shouldSetBadge: false,
  }),
});

export async function requestPermissions(): Promise<boolean> {
  const { status: existingStatus } = await Notifications.getPermissionsAsync();
  let finalStatus = existingStatus;
  if (existingStatus !== 'granted') {
    const { status } = await Notifications.requestPermissionsAsync();
    finalStatus = status;
  }
  if (finalStatus !== 'granted') return false;
  if (Platform.OS === 'android') {
    await Notifications.setNotificationChannelAsync('reminders', {
      name: 'Show Reminders',
      importance: Notifications.AndroidImportance.HIGH,
      vibrationPattern: [0, 250, 250, 250],
      lightColor: '#E8D5B7',
    });
  }
  return true;
}

/**
 * Schedule 3 reminders:
 * 1. 9:00 AM on the day of the show
 * 2. 2 hours before showtime
 * 3. 30 minutes before showtime
 *
 * Returns comma-separated notification IDs
 */
export async function scheduleReminders(
  movieTitle: string,
  theater: string,
  date: string,
  time: string,
): Promise<string | null> {
  const hasPermission = await requestPermissions();
  if (!hasPermission) return null;

  const showtimeStr = `${date} ${time}`;
  const showtime = parse(showtimeStr, 'yyyy-MM-dd h:mm a', new Date());
  const now = new Date();

  const ids: string[] = [];

  // 1. 9:00 AM day-of
  const dayOf = setSeconds(setMinutes(setHours(new Date(showtime), 9), 0), 0);
  if (isBefore(now, dayOf)) {
    const id = await Notifications.scheduleNotificationAsync({
      content: {
        title: `🎬 ${movieTitle} tonight`,
        body: `You've got tickets for ${theater} at ${time}`,
        data: { movieTitle, theater, type: 'morning' },
        sound: true,
      },
      trigger: { type: Notifications.SchedulableTriggerInputTypes.DATE, date: dayOf },
    });
    ids.push(id);
  }

  // 2. 2 hours before
  const twoHoursBefore = subHours(showtime, 2);
  if (isBefore(now, twoHoursBefore)) {
    const id = await Notifications.scheduleNotificationAsync({
      content: {
        title: `🎬 ${movieTitle} in 2 hours`,
        body: `Showtime at ${time} — ${theater}`,
        data: { movieTitle, theater, type: '2hr' },
        sound: true,
      },
      trigger: { type: Notifications.SchedulableTriggerInputTypes.DATE, date: twoHoursBefore },
    });
    ids.push(id);
  }

  // 3. 30 minutes before
  const thirtyMinBefore = subMinutes(showtime, 30);
  if (isBefore(now, thirtyMinBefore)) {
    const id = await Notifications.scheduleNotificationAsync({
      content: {
        title: `🎬 ${movieTitle} in 30 min`,
        body: `Head to ${theater} — showtime ${time}`,
        data: { movieTitle, theater, type: '30min' },
        sound: true,
      },
      trigger: { type: Notifications.SchedulableTriggerInputTypes.DATE, date: thirtyMinBefore },
    });
    ids.push(id);
  }

  return ids.length > 0 ? ids.join(',') : null;
}

export async function cancelReminders(notificationIds: string): Promise<void> {
  const ids = notificationIds.split(',').filter(Boolean);
  for (const id of ids) {
    await Notifications.cancelScheduledNotificationAsync(id);
  }
}
