export interface Ticket {
  id: string;
  movieTitle: string;
  theater: string;
  date: string;        // ISO date string
  time: string;        // e.g. "7:30 PM"
  seat?: string;
  price?: string;
  imageUri: string;    // local URI to the ticket photo
  createdAt: string;   // ISO timestamp
  notificationId?: string;
  letterboxdLogged?: boolean;
  notes?: string;
}

export interface ParsedTicketData {
  movieTitle: string;
  theater: string;
  date: string;
  time: string;
  seat?: string;
  price?: string;
  confidence: number;  // 0-1 how confident the AI is
}

export interface TicketCollection {
  tickets: Ticket[];
  totalSpent: number;
  totalTickets: number;
  favoriteTheater: string | null;
}
