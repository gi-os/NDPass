import { ParsedTicketData } from './types';
import { getApiKey } from './settings';

const REQUEST_TIMEOUT_MS = 30000;
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

async function fetchWithTimeout(url: string, options: RequestInit, timeoutMs: number): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { ...options, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Parse a ticket image using Claude Vision.
 * @param base64 - base64-encoded image data (from image picker)
 * @param onStatus - callback for debug log messages
 */
export async function parseTicketImage(
  base64: string,
  onStatus?: (msg: string) => void,
): Promise<ParsedTicketData> {
  const log = (msg: string) => {
    console.log(`[NDPass] ${msg}`);
    onStatus?.(msg);
  };

  const apiKey = await getApiKey();
  if (!apiKey) {
    throw new Error('No API key configured.\n\nGo to Settings tab and add your Anthropic API key.');
  }

  const sizeKB = Math.round(base64.length / 1024);
  log(`Image ready (${sizeKB}KB base64)`);

  let lastError: Error | null = null;
  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    try {
      log(attempt > 1 ? `Retry ${attempt}/${MAX_RETRIES}...` : 'Calling Claude...');

      const response = await fetchWithTimeout(
        'https://api.anthropic.com/v1/messages',
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': apiKey,
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
                    source: { type: 'base64', media_type: 'image/jpeg', data: base64 },
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
        if (response.status === 401) {
          throw new Error('Invalid API key. Check your key in Settings.');
        }
        throw new Error(`API error ${response.status}: ${err.slice(0, 100)}`);
      }

      const data = await response.json();
      const text = data.content?.[0]?.text ?? '';
      log(`Response: ${text.slice(0, 80)}...`);

      const cleaned = text.replace(/```json\n?|```/g, '').trim();
      const parsed = JSON.parse(cleaned);

      if (parsed.error === 'not_a_ticket') {
        throw new Error("This doesn't look like a movie ticket. Try another photo.");
      }

      log('✓ Scan complete!');
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
      const isTimeout = err.name === 'AbortError' || err.message?.includes('timeout');
      log(`Attempt ${attempt} failed: ${isTimeout ? 'Timed out' : err.message}`);
      if (attempt === MAX_RETRIES || !isTimeout) break;
      await new Promise(r => setTimeout(r, 1000));
    }
  }

  throw lastError ?? new Error('Failed to parse ticket');
}
