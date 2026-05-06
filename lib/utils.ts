/**
 * Simple unique ID generator (no crypto dependency needed)
 */
export function generateId(): string {
  const timestamp = Date.now().toString(36);
  const random = Math.random().toString(36).substring(2, 8);
  return `${timestamp}-${random}`;
}

/**
 * Format a price string consistently
 */
export function formatPrice(price: string | undefined): string {
  if (!price) return '—';
  const num = parseFloat(price.replace(/[^0-9.]/g, ''));
  if (isNaN(num)) return price;
  return `$${num.toFixed(2)}`;
}

/**
 * Format date for display
 */
export function formatDisplayDate(dateStr: string): string {
  const date = new Date(dateStr + 'T00:00:00');
  return date.toLocaleDateString('en-US', {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
}

/**
 * Convert string to Title Case (e.g. "METROGRAPH" → "Metrograph")
 */
export function toTitleCase(str: string): string {
  if (!str) return str;
  // If it's mixed case already (like "IFC Center"), leave it
  const hasLower = /[a-z]/.test(str);
  const hasUpper = /[A-Z]/.test(str);
  if (hasLower && hasUpper) return str;
  // All caps or all lower — title case it
  return str.toLowerCase().replace(/\b\w/g, c => c.toUpperCase());
}
