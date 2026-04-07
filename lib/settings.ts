import { getDB } from './database';

// We store settings in the same SQLite DB — no extra deps needed

export async function initSettings(): Promise<void> {
  const db = await getDB();
  await db.execAsync(`
    CREATE TABLE IF NOT EXISTS settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );
  `);
}

export async function getSetting(key: string): Promise<string | null> {
  await initSettings();
  const db = await getDB();
  const row = await db.getFirstAsync<{ value: string }>(
    'SELECT value FROM settings WHERE key = ?',
    [key]
  );
  return row?.value ?? null;
}

export async function setSetting(key: string, value: string): Promise<void> {
  await initSettings();
  const db = await getDB();
  await db.runAsync(
    'INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)',
    [key, value]
  );
}

export async function deleteSetting(key: string): Promise<void> {
  await initSettings();
  const db = await getDB();
  await db.runAsync('DELETE FROM settings WHERE key = ?', [key]);
}

// ── Convenience helpers ─────────────────────────────────────

export async function getApiKey(): Promise<string | null> {
  return getSetting('anthropic_api_key');
}

export async function setApiKey(key: string): Promise<void> {
  return setSetting('anthropic_api_key', key.trim());
}

export async function hasApiKey(): Promise<boolean> {
  const key = await getApiKey();
  return !!key && key.length > 0;
}
