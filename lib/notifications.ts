import * as Notifications from 'expo-notifications';
import { Platform } from 'react-native';
import { parse, subHours, isBefore } from 'date-fns';

// Configure notification behavior
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

  if (finalStatus !== 'granted') {
    return false;
  }

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
 * Schedule a reminder 1 hour before showtime
 * Returns the notification ID for cancellation
 */
export async function scheduleReminder(
  movieTitle: string,
  theater: string,
  date: string,    // YYYY-MM-DD
  time: string,    // h:mm AM/PM
): Promise<string | null> {
  const hasPermission = await requestPermissions();
  if (!hasPermission) return null;

  // Parse the showtime
  const showtimeStr = `${date} ${time}`;
  const showtime = parse(showtimeStr, 'yyyy-MM-dd h:mm a', new Date());
  const reminderTime = subHours(showtime, 1);

  // Don't schedule if the reminder time is in the past
  if (isBefore(reminderTime, new Date())) {
    return null;
  }

  const id = await Notifications.scheduleNotificationAsync({
    content: {
      title: '🎬 Showtime in 1 hour',
      body: `${movieTitle} at ${theater}`,
      data: { movieTitle, theater, date, time },
      sound: true,
    },
    trigger: {
      type: Notifications.SchedulableTriggerInputTypes.DATE,
      date: reminderTime,
    },
  });

  return id;
}

export async function cancelReminder(notificationId: string): Promise<void> {
  await Notifications.cancelScheduledNotificationAsync(notificationId);
}
