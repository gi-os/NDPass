import * as SQLite from 'expo-sqlite';
import { Ticket } from './types';

const DB_NAME = 'ndpass.db';

let db: SQLite.SQLiteDatabase | null = null;

export async function getDB(): Promise<SQLite.SQLiteDatabase> {
  if (!db) {
    db = await SQLite.openDatabaseAsync(DB_NAME);
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
        notificationId TEXT,
        letterboxdLogged INTEGER DEFAULT 0,
        notes TEXT
      );
    `);
  }
  return db;
}

export async function insertTicket(ticket: Ticket): Promise<void> {
  const database = await getDB();
  await database.runAsync(
    `INSERT INTO tickets (id, movieTitle, theater, date, time, seat, price, imageUri, createdAt, notificationId, letterboxdLogged, notes)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      ticket.id,
      ticket.movieTitle,
      ticket.theater,
      ticket.date,
      ticket.time,
      ticket.seat ?? null,
      ticket.price ?? null,
      ticket.imageUri,
      ticket.createdAt,
      ticket.notificationId ?? null,
      ticket.letterboxdLogged ? 1 : 0,
      ticket.notes ?? null,
    ]
  );
}

export async function getAllTickets(): Promise<Ticket[]> {
  const database = await getDB();
  const rows = await database.getAllAsync<any>(
    'SELECT * FROM tickets ORDER BY date DESC, time DESC'
  );
  return rows.map(row => ({
    ...row,
    letterboxdLogged: !!row.letterboxdLogged,
  }));
}

export async function getTicketById(id: string): Promise<Ticket | null> {
  const database = await getDB();
  const row = await database.getFirstAsync<any>(
    'SELECT * FROM tickets WHERE id = ?',
    [id]
  );
  if (!row) return null;
  return { ...row, letterboxdLogged: !!row.letterboxdLogged };
}

export async function updateTicket(ticket: Partial<Ticket> & { id: string }): Promise<void> {
  const database = await getDB();
  const fields: string[] = [];
  const values: any[] = [];

  const updatable = ['movieTitle', 'theater', 'date', 'time', 'seat', 'price', 'notificationId', 'letterboxdLogged', 'notes'] as const;

  for (const key of updatable) {
    if (key in ticket) {
      fields.push(`${key} = ?`);
      values.push(key === 'letterboxdLogged' ? (ticket[key] ? 1 : 0) : ticket[key as keyof typeof ticket]);
    }
  }

  if (fields.length === 0) return;
  values.push(ticket.id);

  await database.runAsync(
    `UPDATE tickets SET ${fields.join(', ')} WHERE id = ?`,
    values
  );
}

export async function deleteTicket(id: string): Promise<void> {
  const database = await getDB();
  await database.runAsync('DELETE FROM tickets WHERE id = ?', [id]);
}

export async function getStats(): Promise<{
  totalTickets: number;
  totalSpent: number;
  favoriteTheater: string | null;
  thisMonth: number;
}> {
  const database = await getDB();

  const countRow = await database.getFirstAsync<{ count: number }>(
    'SELECT COUNT(*) as count FROM tickets'
  );

  const spentRow = await database.getFirstAsync<{ total: number }>(
    `SELECT COALESCE(SUM(CAST(REPLACE(REPLACE(price, '$', ''), ',', '') AS REAL)), 0) as total FROM tickets WHERE price IS NOT NULL`
  );

  const theaterRow = await database.getFirstAsync<{ theater: string; cnt: number }>(
    `SELECT theater, COUNT(*) as cnt FROM tickets GROUP BY theater ORDER BY cnt DESC LIMIT 1`
  );

  const now = new Date();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();
  const monthRow = await database.getFirstAsync<{ count: number }>(
    'SELECT COUNT(*) as count FROM tickets WHERE date >= ?',
    [monthStart]
  );

  return {
    totalTickets: countRow?.count ?? 0,
    totalSpent: spentRow?.total ?? 0,
    favoriteTheater: theaterRow?.theater ?? null,
    thisMonth: monthRow?.count ?? 0,
  };
}
