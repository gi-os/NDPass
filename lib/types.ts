export interface Ticket {
  id: string;
  movieTitle: string;
  theater: string;
  date: string;        // ISO date YYYY-MM-DD
  time: string;        // e.g. "7:30 PM"
  seat?: string;
  price?: string;
  imageUri: string;    // local URI to the ticket photo
  createdAt: string;
  notificationIds?: string; // comma-separated notification IDs
  notes?: string;
  overview?: string;   // TMDb movie description
  // TMDb data
  posterPath?: string;
  backdropPath?: string;
  tmdbId?: number;
  // Archive
  archived: boolean;
  // Grouping — tickets with the same groupKey are grouped
  groupKey?: string;   // `${movieTitle}|${theater}|${date}|${time}`
}

export interface ParsedTicketData {
  movieTitle: string;
  theater: string;
  date: string;
  time: string;
  seat?: string;
  price?: string;
  confidence: number;
}

export interface TicketGroup {
  groupKey: string;
  movieTitle: string;
  theater: string;
  date: string;
  time: string;
  tickets: Ticket[];
  posterPath?: string;
  backdropPath?: string;
}
