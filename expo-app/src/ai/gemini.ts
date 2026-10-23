/**
 * Thin Gemini client.
 *
 * One place that knows about the API so the feature code (chatbot, translate,
 * summaries) only deals with plain objects. Handles model fallback, timeouts
 * and grounding-metadata extraction.
 */
import type { AiSource } from '../models/types';

/**
 * Read from expo-app/.env (EXPO_PUBLIC_GEMINI_API_KEY), which git ignores.
 * When Supabase is configured the app calls the `ai` edge function instead,
 * so the key never ships inside the app at all.
 */
export const GEMINI_API_KEY = process.env.EXPO_PUBLIC_GEMINI_API_KEY ?? '';

const ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta/models';

/** Tried in order — if a model is retired the next one picks up. */
const MODELS = ['gemini-3.6-flash', 'gemini-flash-latest', 'gemini-3.5-flash'];

const TIMEOUT_MS = 45_000;

export interface GeminiPart { text: string }
export interface GeminiContent { role: 'user' | 'model'; parts: GeminiPart[] }

export interface GenerateOptions {
  system: string;
  contents: GeminiContent[];
  /** Enable Google Search grounding so medical claims can be checked. */
  search?: boolean;
  temperature?: number;
  maxOutputTokens?: number;
  /** Response schema for structured output. Cannot be combined with search. */
  jsonSchema?: Record<string, unknown>;
  /**
   * Gemini 3 reasons before answering, and those tokens come out of
   * maxOutputTokens. "low" is right for everything here — the hard part is the
   * care record we hand it, not the reasoning — and it is roughly 5x faster.
   */
  thinking?: 'low' | 'high';
}

export interface GenerateResult {
  text: string;
  sources: AiSource[];
}

export class GeminiError extends Error {
  constructor(message: string, readonly status?: number) {
    super(message);
    this.name = 'GeminiError';
  }
}

function buildBody(o: GenerateOptions) {
  const body: Record<string, unknown> = {
    contents: o.contents,
    systemInstruction: { parts: [{ text: o.system }] },
    generationConfig: {
      temperature: o.temperature ?? 0.4,
      maxOutputTokens: o.maxOutputTokens ?? 2048,
      thinkingConfig: { thinkingLevel: o.thinking ?? 'low' },
      ...(o.jsonSchema
        ? { responseMimeType: 'application/json', responseSchema: o.jsonSchema }
        : {}),
    },
    safetySettings: [
      'HARM_CATEGORY_HARASSMENT',
      'HARM_CATEGORY_HATE_SPEECH',
      'HARM_CATEGORY_SEXUALLY_EXPLICIT',
      'HARM_CATEGORY_DANGEROUS_CONTENT',
    ].map(category => ({ category, threshold: 'BLOCK_ONLY_HIGH' })),
  };
  if (o.search) body.tools = [{ google_search: {} }];
  return body;
}

function extractText(data: any): string {
  const parts = data?.candidates?.[0]?.content?.parts ?? [];
  return parts
    .map((p: any) => (typeof p?.text === 'string' ? p.text : ''))
    .join('')
    .trim();
}

function extractSources(data: any): AiSource[] {
  const chunks = data?.candidates?.[0]?.groundingMetadata?.groundingChunks ?? [];
  const seen = new Set<string>();
  const out: AiSource[] = [];
  for (const c of chunks) {
    const uri: string | undefined = c?.web?.uri;
    if (!uri || seen.has(uri)) continue;
    seen.add(uri);
    out.push({ title: c.web.title || new URL(uri).hostname, uri });
  }
  return out.slice(0, 6);
}

async function callModel(model: string, body: unknown): Promise<any> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    const res = await fetch(`${ENDPOINT}/${model}:generateContent`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': GEMINI_API_KEY,
      },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
    const data = await res.json().catch(() => null);
    if (!res.ok) {
      throw new GeminiError(data?.error?.message ?? `Request failed (${res.status})`, res.status);
    }
    return data;
  } finally {
    clearTimeout(timer);
  }
}

export async function generate(options: GenerateOptions): Promise<GenerateResult> {
  const body = buildBody(options);
  let lastError: unknown;

  for (const model of MODELS) {
    try {
      const data = await callModel(model, body);
      const text = extractText(data);
      if (!text) {
        // Blocked or empty — surface the reason rather than retrying blindly.
        const reason = data?.promptFeedback?.blockReason
          ?? data?.candidates?.[0]?.finishReason;
        throw new GeminiError(
          reason ? `No answer returned (${reason}).` : 'No answer returned.',
        );
      }
      const finish = data?.candidates?.[0]?.finishReason;
      if (finish === 'MAX_TOKENS') {
        // Better a visible seam than a sentence that stops mid-word.
        return {
          text: `${text}…\n\n_(cut off, ask me to continue)_`,
          sources: extractSources(data),
        };
      }
      return { text, sources: extractSources(data) };
    } catch (err) {
      lastError = err;
      const status = err instanceof GeminiError ? err.status : undefined;
      // 404 = model retired for this key, 403/429 = try the next model too.
      const retryable = status === 404 || status === 403 || status === 429 || status === 500;
      if (!retryable) throw err;
    }
  }
  throw lastError instanceof Error
    ? lastError
    : new GeminiError('Could not reach Cura AI.');
}

/** Parse a JSON response, tolerating stray code fences. */
export function parseJson<T>(text: string): T | null {
  const cleaned = text.replace(/^```(?:json)?\s*/i, '').replace(/```\s*$/, '').trim();
  try {
    return JSON.parse(cleaned) as T;
  } catch {
    const match = cleaned.match(/[[{][\s\S]*[\]}]/);
    if (!match) return null;
    try {
      return JSON.parse(match[0]) as T;
    } catch {
      return null;
    }
  }
}

export function friendlyError(err: unknown): string {
  if (err instanceof GeminiError) {
    if (err.status === 429) return 'Cura AI is busy right now. Try again in a moment.';
    if (err.status === 401 || err.status === 403) return 'Cura AI could not authenticate. Check the API key.';
    return err.message;
  }
  if (err instanceof Error) {
    if (err.name === 'AbortError') return 'That took too long. Try again.';
    // Surface the real reason rather than blaming the network for everything.
    if (err.message) return err.message;
  }
  return 'Could not reach Cura AI. Check your connection and try again.';
}
