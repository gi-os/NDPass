import { ParsedTicketData } from './types';
import * as FileSystem from 'expo-file-system';
import * as ImageManipulator from 'expo-image-manipulator';

// ── Configuration ───────────────────────────────────────────
const NDPASS_SERVER = process.env.EXPO_PUBLIC_NDPASS_SERVER ?? '';
const ANTHROPIC_API_KEY = process.env.EXPO_PUBLIC_ANTHROPIC_API_KEY ?? '';

const REQUEST_TIMEOUT_MS = 30000; // 30s timeout
const MAX_RETRIES = 2;

const PARSE_PROMPT = `You are a movie ticket parser. Analyze this image of a movie ticket and extract the following information. Return ONLY valid JSON, no markdown, no backticks, no explanation.

{
  "movieTitle": "exact movie title shown on ticket",
  "theater": "theater/cinema name",
  "date": "YYYY-MM-DD format, infer year if not shown (use current year 2026)",
  "time": "h:mm AM/PM format",
  "seat": "seat/row info if visible, or null",
  "price": "price with $ if visible, or null",
  "confidence": 0.95
}

Rules:
- If a field is illegible or missing, use your best guess and lower the confidence score
- For date, always output ISO format YYYY-MM-DD
- For time, always output 12-hour with AM/PM
- confidence is 0-1 representing how sure you are about ALL extracted fields
- If this is NOT a movie ticket, return {"error": "not_a_ticket", "confidence": 0}`;

/**
 * Compress image before sending to API
 * Big images cause timeouts — resize to max 1200px wide
 */
async function compressImage(imageUri: string): Promise<{ base64: string; mediaType: string }> {
  console.log('[NDPass] Compressing image...');

  const manipulated = await ImageManipulator.manipulateAsync(
    imageUri,
    [{ resize: { width: 1200 } }],
    { compress: 0.7, format: ImageManipulator.SaveFormat.JPEG, base64: true }
  );

  console.log(`[NDPass] Compressed: ${Math.round((manipulated.base64?.length ?? 0) / 1024)}KB base64`);
  return {
    base64: manipulated.base64!,
    mediaType: 'image/jpeg',
  };
}

/**
 * Fetch with timeout
 */
async function fetchWithTimeout(url: string, options: RequestInit, timeoutMs: number): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(url, { ...options, signal: controller.signal });
    return response;
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Main entry — parse a ticket image
 */
export async function parseTicketImage(
  imageUri: string,
  onStatus?: (msg: string) => void,
): Promise<ParsedTicketData> {
  const log = (msg: string) => {
    console.log(`[NDPass] ${msg}`);
    onStatus?.(msg);
  };

  log('Starting ticket scan...');

  // Compress image
  const { base64, mediaType } = await compressImage(imageUri);
  log(`Image ready (${Math.round(base64.length / 1024)}KB)`);

  // Retry loop
  let lastError: Error | null = null;
  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    try {
      log(attempt > 1 ? `Retry ${attempt}/${MAX_RETRIES}...` : 'Sending to AI...');

      const parsed = NDPASS_SERVER
        ? await parseViaServer(base64, mediaType, log)
        : await parseDirectly(base64, mediaType, log);

      if ((parsed as any).error === 'not_a_ticket') {
        throw new Error("This doesn't look like a movie ticket. Try another photo.");
      }

      log('Scan complete!');

      return {
        movieTitle: parsed.movieTitle ?? 'Unknown',
        theater: parsed.theater ?? 'Unknown',
        date: parsed.date ?? new Date().toISOString().split('T')[0],
        time: parsed.time ?? '7:00 PM',
        seat: parsed.seat ?? undefined,
        price: parsed.price ?? undefined,
        confidence: parsed.confidence ?? 0.5,
      };
    } catch (err: any) {
      lastError = err;
      const isTimeout = err.name === 'AbortError' || err.message?.includes('timeout') || err.message?.includes('Timeout');
      log(`Attempt ${attempt} failed: ${isTimeout ? 'Timed out' : err.message}`);

      if (attempt === MAX_RETRIES || !isTimeout) {
        break;
      }
      // Brief pause before retry
      await new Promise(r => setTimeout(r, 1000));
    }
  }

  throw lastError ?? new Error('Failed to parse ticket');
}

// ── Server proxy mode ──────────────────────────────────────
async function parseViaServer(base64: string, mediaType: string, log: (m: string) => void): Promise<any> {
  log(`Calling server: ${NDPASS_SERVER}/parse`);

  const response = await fetchWithTimeout(
    `${NDPASS_SERVER}/parse`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ image: base64, mediaType }),
    },
    REQUEST_TIMEOUT_MS,
  );

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`Server error ${response.status}: ${err}`);
  }

  const data = await response.json();
  log(`Server response: ${JSON.stringify(data).slice(0, 100)}...`);
  return data;
}

// ── Direct Anthropic mode ──────────────────────────────────
async function parseDirectly(base64: string, mediaType: string, log: (m: string) => void): Promise<any> {
  if (!ANTHROPIC_API_KEY) {
    throw new Error(
      'No API key or server configured.\n\n' +
      'Set EXPO_PUBLIC_NDPASS_SERVER (recommended)\n' +
      'or EXPO_PUBLIC_ANTHROPIC_API_KEY in .env'
    );
  }

  log('Calling Anthropic API directly...');

  const response = await fetchWithTimeout(
    'https://api.anthropic.com/v1/messages',
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-20250514',
        max_tokens: 512,
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'image',
                source: { type: 'base64', media_type: mediaType, data: base64 },
              },
              { type: 'text', text: PARSE_PROMPT },
            ],
          },
        ],
      }),
    },
    REQUEST_TIMEOUT_MS,
  );

  if (!response.ok) {
    const err = await response.text();
    log(`API error: ${err.slice(0, 200)}`);
    throw new Error(`Anthropic API error ${response.status}: ${err.slice(0, 100)}`);
  }

  const data = await response.json();
  const text = data.content?.[0]?.text ?? '';
  log(`API response: ${text.slice(0, 100)}...`);

  const cleaned = text.replace(/```json\n?|```/g, '').trim();
  return JSON.parse(cleaned);
}
