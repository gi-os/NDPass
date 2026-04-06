import { ParsedTicketData } from './types';
import * as FileSystem from 'expo-file-system';

// ── Configuration ───────────────────────────────────────────
// Option A: Direct Anthropic call (API key on device — dev only)
// Option B: Server proxy (recommended — key stays on BasilNet)
//
// Set EXPO_PUBLIC_NDPASS_SERVER to your server URL to use proxy mode.
// If not set, falls back to direct Anthropic call.

const NDPASS_SERVER = process.env.EXPO_PUBLIC_NDPASS_SERVER ?? '';
const ANTHROPIC_API_KEY = process.env.EXPO_PUBLIC_ANTHROPIC_API_KEY ?? '';

const PARSE_PROMPT = `You are a movie ticket parser. Analyze this image of a movie ticket and extract the following information. Return ONLY valid JSON, no markdown, no backticks, no explanation.

{
  "movieTitle": "exact movie title shown on ticket",
  "theater": "theater/cinema name",
  "date": "YYYY-MM-DD format, infer year if not shown (use current year)",
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

export async function parseTicketImage(imageUri: string): Promise<ParsedTicketData> {
  // Read image as base64
  const base64 = await FileSystem.readAsStringAsync(imageUri, {
    encoding: FileSystem.EncodingType.Base64,
  });

  const isJpg = imageUri.toLowerCase().includes('.jpg') || imageUri.toLowerCase().includes('.jpeg');
  const mediaType = isJpg ? 'image/jpeg' : 'image/png';

  // Route to server or direct based on config
  const parsed = NDPASS_SERVER
    ? await parseViaServer(base64, mediaType)
    : await parseDirectly(base64, mediaType);

  if ((parsed as any).error === 'not_a_ticket') {
    throw new Error('This doesn\'t look like a movie ticket. Try another photo.');
  }

  return {
    movieTitle: parsed.movieTitle ?? 'Unknown',
    theater: parsed.theater ?? 'Unknown',
    date: parsed.date ?? new Date().toISOString().split('T')[0],
    time: parsed.time ?? '7:00 PM',
    seat: parsed.seat ?? undefined,
    price: parsed.price ?? undefined,
    confidence: parsed.confidence ?? 0.5,
  };
}

// ── Server proxy mode (recommended) ────────────────────────
async function parseViaServer(base64: string, mediaType: string): Promise<any> {
  const response = await fetch(`${NDPASS_SERVER}/parse`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ image: base64, mediaType }),
  });

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`Server error: ${response.status} — ${err}`);
  }

  return response.json();
}

// ── Direct Anthropic mode (dev/fallback) ────────────────────
async function parseDirectly(base64: string, mediaType: string): Promise<any> {
  if (!ANTHROPIC_API_KEY) {
    throw new Error(
      'No API key or server configured.\n\n' +
      'Set EXPO_PUBLIC_NDPASS_SERVER (recommended)\n' +
      'or EXPO_PUBLIC_ANTHROPIC_API_KEY in .env'
    );
  }

  const response = await fetch('https://api.anthropic.com/v1/messages', {
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
  });

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`Anthropic API error: ${response.status} — ${err}`);
  }

  const data = await response.json();
  const text = data.content?.[0]?.text ?? '';
  const cleaned = text.replace(/```json\n?|```/g, '').trim();
  return JSON.parse(cleaned);
}
