/**
 * Show any piece of text in the reader's language.
 *
 * Translation runs once per (text, language) and is remembered for the rest of
 * the session. A small queue keeps a screen full of notes from firing dozens of
 * requests at once. When no translation is needed, or translating fails, the
 * original text is shown and nothing breaks.
 */
import { useEffect, useState } from 'react';
import { translateText, looksLikeNoise } from '../ai/cura';
import { GEMINI_API_KEY } from '../ai/gemini';

const cache = new Map<string, string | null>(); // null = already in the target language
const waiting = new Map<string, Promise<string | null>>();
let running = 0;
const queue: (() => void)[] = [];
const MAX_AT_ONCE = 2;

function run<T>(job: () => Promise<T>): Promise<T> {
  return new Promise((resolve, reject) => {
    const start = () => {
      running++;
      job().then(resolve, reject).finally(() => {
        running--;
        queue.shift()?.();
      });
    };
    if (running < MAX_AT_ONCE) start(); else queue.push(start);
  });
}

function translateOnce(text: string, target: string): Promise<string | null> {
  const key = `${target}|${text}`;
  if (cache.has(key)) return Promise.resolve(cache.get(key) ?? null);
  const inFlight = waiting.get(key);
  if (inFlight) return inFlight;
  const p = run(() => translateText(text, target))
    .then(r => {
      const out = r.unchanged || r.translated.trim() === text.trim() ? null : r.translated;
      cache.set(key, out);
      return out;
    })
    .finally(() => waiting.delete(key));
  waiting.set(key, p);
  return p;
}

export function useTranslated(
  text: string, sourceLang: string | undefined, targetLang: string | undefined,
  /** A translation we already have (a message's stored translation). Used before asking the API. */
  known?: string,
) {
  const needs = !known &&
    !!text && !!targetLang && !!sourceLang && sourceLang !== targetLang &&
    !!GEMINI_API_KEY && !looksLikeNoise(text);
  const key = `${targetLang}|${text}`;
  const [value, setValue] = useState<string | null | undefined>(cache.get(key));

  useEffect(() => {
    if (!needs || !targetLang) { setValue(undefined); return; }
    if (cache.has(key)) { setValue(cache.get(key)); return; }
    let live = true;
    translateOnce(text, targetLang).then(v => { if (live) setValue(v); }).catch(() => {});
    return () => { live = false; };
  }, [needs, key, text, targetLang]);

  if (known && sourceLang && targetLang && sourceLang !== targetLang) {
    return { text: known, translated: true, loading: false };
  }
  const translated = needs && !!value;
  return { text: translated ? (value as string) : text, translated, loading: needs && value === undefined };
}
