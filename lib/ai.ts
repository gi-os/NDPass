import { ParsedTicketData } from './types';
import * as FileSystem from 'expo-file-system';

// Store your API key securely — in production use expo-secure-store
// For now, set this in your .env or replace before building
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
  if (!ANTHROPIC_API_KEY) {
    throw new Error('ANTHROPIC_API_KEY not set. Add EXPO_PUBLIC_ANTHROPIC_API_KEY to your .env');
  }

  // Read image as base64
  const base64 = await FileSystem.readAsStringAsync(imageUri, {
    encoding: FileSystem.EncodingType.Base64,
  });

  // Detect media type from URI
  const isJpg = imageUri.toLowerCase().includes('.jpg') || imageUri.toLowerCase().includes('.jpeg');
  const mediaType = isJpg ? 'image/jpeg' : 'image/png';

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
              source: {
                type: 'base64',
                media_type: mediaType,
                data: base64,
              },
            },
            {
              type: 'text',
              text: PARSE_PROMPT,
            },
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

  // Parse the JSON response
  const cleaned = text.replace(/```json\n?|```/g, '').trim();
  const parsed = JSON.parse(cleaned);

  if (parsed.error === 'not_a_ticket') {
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
