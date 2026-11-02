// Optional body-photo check (owner request 2026-10-27). One photo goes to a vision model with a strict prompt; only
// neutral, non-medical notes about posture and visible development come back, plus focus areas from a fixed list.
// No body-fat percentage, weight, BMI, attractiveness or health judgement: replies that contain them are refused.
// The photo is never stored: it lives only in this request. Pure TypeScript, tested with node.

export const FOCUS_AREAS = ['upper body', 'lower body', 'core', 'posture and mobility', 'conditioning'] as const;
export type FocusArea = (typeof FOCUS_AREAS)[number];
export type BodyCheck = { observations: string[]; focus: FocusArea[] };

export const MAX_IMAGE_BYTES = 4 * 1024 * 1024; // decoded size; the app sends a 1024 px JPEG well under this
export const IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'] as const;
/** The largest request body read: the base64 of a MAX_IMAGE_BYTES photo plus room for the JSON around it. */
export const MAX_REQUEST_BYTES = Math.ceil(MAX_IMAGE_BYTES / 3) * 4 + 1024;

export const BODY_CHECK_SYSTEM = `You look at one photo of an adult who asked for training advice. Reply with JSON only:
{"observations": [up to 4 short sentences], "focus": [1 to 3 of ${FOCUS_AREAS.map((f) => `"${f}"`).join(', ')}]}
Observations: neutral and encouraging, about posture (head, shoulders, hips, stance) and which areas look more or less trained relative to each other.
Never estimate body fat, weight, BMI or age. Never comment on attractiveness, skin, or any medical condition. Never use words like fat, obese, skinny, overweight or ugly.
If the photo does not show a person's body clearly, reply {"observations": ["The photo does not show enough to comment. Try a full-length photo in good light."], "focus": []}.`;

const BANNED = /\b(body ?fat|fat|obese|obesity|overweight|underweight|skinny|bmi|ugly|unattractive|diagnos\w*|disease|disorder|kg|pounds|lbs)\b|%/i;

/** Validated reply, or null when it is not the agreed JSON or breaks the content rules. */
export function parseBodyCheck(text: string): BodyCheck | null {
  const json = text.slice(text.indexOf('{'), text.lastIndexOf('}') + 1);
  let raw: unknown;
  try {
    raw = JSON.parse(json);
  } catch {
    return null;
  }
  if (typeof raw !== 'object' || raw === null) return null;
  const r = raw as Record<string, unknown>;
  if (!Array.isArray(r.observations) || !Array.isArray(r.focus)) return null;
  const observations = r.observations.filter((o): o is string => typeof o === 'string').map((o) => o.trim()).filter((o) => o.length > 0);
  if (observations.length === 0 || observations.length > 4 || observations.some((o) => o.length > 240 || BANNED.test(o))) return null;
  const focus = [...new Set(r.focus.filter((f): f is FocusArea => (FOCUS_AREAS as readonly string[]).includes(f as string)))].slice(0, 3);
  return { observations, focus };
}

/**
 * The request body as text, reading at most [max] bytes as they arrive: null as soon as more come (the stream is
 * cancelled, nothing more is buffered). Counts real bytes, so a missing or false Content-Length changes nothing.
 */
export async function readCapped(req: Request, max: number): Promise<string | null> {
  if (!req.body) return '';
  const reader = req.body.getReader();
  const chunks: Uint8Array[] = [];
  let n = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    n += value.byteLength;
    if (n > max) {
      await reader.cancel().catch(() => {});
      return null;
    }
    chunks.push(value);
  }
  const all = new Uint8Array(n);
  let at = 0;
  for (const c of chunks) {
    all.set(c, at);
    at += c.byteLength;
  }
  return new TextDecoder().decode(all);
}

/** Whether the photo's first bytes are those of [mime] (JPEG FF D8 FF, PNG signature, WebP RIFF....WEBP). */
export function imageMatches(mime: string, b64: string): boolean {
  let head: string;
  try {
    head = atob(b64.slice(0, 16));
  } catch {
    return false;
  }
  if (mime === 'image/jpeg') return head.startsWith('\xFF\xD8\xFF');
  if (mime === 'image/png') return head.startsWith('\x89PNG\r\n\x1A\n');
  if (mime === 'image/webp') return head.startsWith('RIFF') && head.slice(8, 12) === 'WEBP';
  return false;
}

/** Bytes of a base64 string once decoded. */
export function base64Bytes(b64: string): number {
  const pad = b64.endsWith('==') ? 2 : b64.endsWith('=') ? 1 : 0;
  return Math.floor((b64.length * 3) / 4) - pad;
}

/** The request body for an OpenAI-compatible vision chat call. */
export function visionRequest(model: string, mime: string, b64: string) {
  return {
    model,
    temperature: 0.2,
    max_tokens: 500,
    response_format: { type: 'json_object' },
    messages: [
      { role: 'system', content: BODY_CHECK_SYSTEM },
      {
        role: 'user',
        content: [
          { type: 'text', text: 'Here is my photo. What should my training focus on?' },
          { type: 'image_url', image_url: { url: `data:${mime};base64,${b64}` } },
        ],
      },
    ],
  };
}
