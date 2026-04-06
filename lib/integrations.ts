import * as Linking from 'expo-linking';

/**
 * Open Letterboxd search for the movie title
 * Letterboxd doesn't have a write API, so we deep link to search
 */
export function openLetterboxd(movieTitle: string): void {
  const encoded = encodeURIComponent(movieTitle);
  // Try the app first, fall back to web
  const appUrl = `letterboxd://search/${encoded}`;
  const webUrl = `https://letterboxd.com/search/${encoded}/`;

  Linking.canOpenURL(appUrl).then(supported => {
    if (supported) {
      Linking.openURL(appUrl);
    } else {
      Linking.openURL(webUrl);
    }
  });
}

/**
 * Generate an .ics calendar event string
 * Can be shared/opened to add to Apple Calendar
 */
export function generateICS(
  movieTitle: string,
  theater: string,
  date: string,
  time: string,
): string {
  // Parse date/time into UTC format for ICS
  const [year, month, day] = date.split('-').map(Number);
  const timeMatch = time.match(/(\d{1,2}):(\d{2})\s*(AM|PM)/i);
  if (!timeMatch) return '';

  let hours = parseInt(timeMatch[1]);
  const minutes = parseInt(timeMatch[2]);
  const ampm = timeMatch[3].toUpperCase();

  if (ampm === 'PM' && hours !== 12) hours += 12;
  if (ampm === 'AM' && hours === 12) hours = 0;

  const pad = (n: number) => n.toString().padStart(2, '0');
  const dtStart = `${year}${pad(month)}${pad(day)}T${pad(hours)}${pad(minutes)}00`;

  // Assume 2.5 hour movie
  const endHours = hours + 2;
  const endMinutes = minutes + 30;
  const dtEnd = `${year}${pad(month)}${pad(endMinutes >= 60 ? endHours + 1 : endHours)}${pad(endMinutes % 60)}00`;

  const reminderMinutes = 60;

  return [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//NDPass//Movie Ticket//EN',
    'BEGIN:VEVENT',
    `DTSTART:${dtStart}`,
    `DTEND:${dtEnd}`,
    `SUMMARY:🎬 ${movieTitle}`,
    `LOCATION:${theater}`,
    `DESCRIPTION:Movie ticket tracked by NDPass`,
    'BEGIN:VALARM',
    'TRIGGER:-PT60M',
    'ACTION:DISPLAY',
    `DESCRIPTION:${movieTitle} starts in 1 hour`,
    'END:VALARM',
    'END:VEVENT',
    'END:VCALENDAR',
  ].join('\r\n');
}
