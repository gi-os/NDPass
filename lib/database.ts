import * as SQLite from 'expo-sqlite';
import { Ticket, TicketGroup } from './types';

const DB_NAME = 'ndpass.db';
let db: SQLite.SQLiteDatabase | null = null;

export async function getDB(): Promise<SQLite.SQLiteDatabase> {
  if (!db) {
    db = await SQLite.openDatabaseAsync(DB_NAME);

    // Migrate: drop old table and recreate with correct schema
    // This is safe during early development — no production data yet
    await db.execAsync(`DROP TABLE IF EXISTS tickets`);

    await db.execAsync(`
      CREATE TABLE IF NOT EXISTS tickets (
        id TEXT PRIMARY KEY,
        movieTitle TEXT NOT NULL,
        theater TEXT NOT NULL,
        date TEXT NOT NULL,
        time TEXT NOT NULL,
        seat TEXT,
        price TEXT,
        imageUri TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        notificationIds TEXT,
        notes TEXT,
        posterPath TEXT,
        backdropPath TEXT,
        tmdbId INTEGER,
        archived INTEGER DEFAULT 0,
        groupKey TEXT
      );
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    `);

    // Auto-archive past tickets
    await archivePastTickets();
  }
  return db;
}

/**
 * Auto-archive tickets where the showtime has passed
 */
export async function archivePastTickets(): Promise<void> {
  const database = db ?? await getDB();
  const today = new Date().toISOString().split('T')[0];
  await database.runAsync(
    'UPDATE tickets SET archived = 1 WHERE date < ? AND archived = 0',
    [today]
  );
}

export async function insertTicket(ticket: Ticket): Promise<void> {
  const database = await getDB();
  const groupKey = `${ticket.movieTitle}|${ticket.theater}|${ticket.date}|${ticket.time}`;
  await database.runAsync(
    `INSERT INTO tickets (id, movieTitle, theater, date, time, seat, price, imageUri, createdAt, notificationIds, notes, posterPath, backdropPath, tmdbId, archived, groupKey)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      ticket.id, ticket.movieTitle, ticket.theater, ticket.date, ticket.time,
      ticket.seat ?? null, ticket.price ?? null, ticket.imageUri, ticket.createdAt,
      ticket.notificationIds ?? null, ticket.notes ?? null,
      ticket.posterPath ?? null, ticket.backdropPath ?? null, ticket.tmdbId ?? null,
      ticket.archived ? 1 : 0, groupKey,
    ]
  );
}

export async function getActiveTickets(): Promise<Ticket[]> {
  const database = await getDB();
  await archivePastTickets();
  const rows = await database.getAllAsync<any>(
    'SELECT * FROM tickets WHERE archived = 0 ORDER BY date ASC, time ASC'
  );
  return rows.map(mapRow);
}

export async function getArchivedTickets(): Promise<Ticket[]> {
  const database = await getDB();
  const rows = await database.getAllAsync<any>(
    'SELECT * FROM tickets WHERE archived = 1 ORDER BY date DESC, time DESC'
  );
  return rows.map(mapRow);
}

export async function getAllTickets(): Promise<Ticket[]> {
  const database = await getDB();
  const rows = await database.getAllAsync<any>(
    'SELECT * FROM tickets ORDER BY date DESC, time DESC'
  );
  return rows.map(mapRow);
}

export async function getTicketById(id: string): Promise<Ticket | null> {
  const database = await getDB();
  const row = await database.getFirstAsync<any>(
    'SELECT * FROM tickets WHERE id = ?', [id]
  );
  return row ? mapRow(row) : null;
}

export async function updateTicket(ticket: Partial<Ticket> & { id: string }): Promise<void> {
  const database = await getDB();
  const fields: string[] = [];
  const values: any[] = [];
  const updatable = [
    'movieTitle', 'theater', 'date', 'time', 'seat', 'price',
    'notificationIds', 'notes', 'posterPath', 'backdropPath', 'tmdbId', 'archived', 'groupKey',
  ] as const;

  for (const key of updatable) {
    if (key in ticket) {
      fields.push(`${key} = ?`);
      const val = ticket[key as keyof typeof ticket];
      values.push(key === 'archived' ? (val ? 1 : 0) : val);
    }
  }
  if (fields.length === 0) return;
  values.push(ticket.id);
  await database.runAsync(`UPDATE tickets SET ${fields.join(', ')} WHERE id = ?`, values);
}

export async function deleteTicket(id: string): Promise<void> {
  const database = await getDB();
  await database.runAsync('DELETE FROM tickets WHERE id = ?', [id]);
}

/**
 * Group tickets by same showing (same movie+theater+date+time)
 */
export function groupTickets(tickets: Ticket[]): TicketGroup[] {
  const groups = new Map<string, TicketGroup>();

  for (const ticket of tickets) {
    const key = ticket.groupKey ?? `${ticket.movieTitle}|${ticket.theater}|${ticket.date}|${ticket.time}`;
    if (!groups.has(key)) {
      groups.set(key, {
        groupKey: key,
        movieTitle: ticket.movieTitle,
        theater: ticket.theater,
        date: ticket.date,
        time: ticket.time,
        tickets: [],
        posterPath: ticket.posterPath,
        backdropPath: ticket.backdropPath,
      });
    }
    groups.get(key)!.tickets.push(ticket);
  }

  return Array.from(groups.values());
}

export async function getStats(): Promise<{
  totalTickets: number;
  totalSpent: number;
  favoriteTheater: string | null;
  thisMonth: number;
}> {
  const database = await getDB();
  const countRow = await database.getFirstAsync<{ count: number }>('SELECT COUNT(*) as count FROM tickets');
  const spentRow = await database.getFirstAsync<{ total: number }>(
    `SELECT COALESCE(SUM(CAST(REPLACE(REPLACE(price, '$', ''), ',', '') AS REAL)), 0) as total FROM tickets WHERE price IS NOT NULL`
  );
  const theaterRow = await database.getFirstAsync<{ theater: string }>(
    `SELECT theater, COUNT(*) as cnt FROM tickets GROUP BY theater ORDER BY cnt DESC LIMIT 1`
  );
  const now = new Date();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();
  const monthRow = await database.getFirstAsync<{ count: number }>(
    'SELECT COUNT(*) as count FROM tickets WHERE date >= ?', [monthStart]
  );
  return {
    totalTickets: countRow?.count ?? 0,
    totalSpent: spentRow?.total ?? 0,
    favoriteTheater: theaterRow?.theater ?? null,
    thisMonth: monthRow?.count ?? 0,
  };
}

function mapRow(row: any): Ticket {
  return {
    ...row,
    archived: !!row.archived,
    tmdbId: row.tmdbId ?? undefined,
    posterPath: row.posterPath ?? undefined,
    backdropPath: row.backdropPath ?? undefined,
    groupKey: row.groupKey ?? undefined,
  };
}
