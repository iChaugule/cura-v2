/**
 * Text-to-speech, shared by the notes tab and the AI chat.
 *
 * Tracks which item is speaking so a list can show a stop button on the right
 * row, and always stops cleanly when the screen goes away.
 */
import { useCallback, useEffect, useRef, useState } from 'react';
import * as Speech from 'expo-speech';

const LANG_TAGS: Record<string, string> = {
  en: 'en-IN', mr: 'mr-IN', hi: 'hi-IN', ta: 'ta-IN', te: 'te-IN',
  bn: 'bn-IN', gu: 'gu-IN', kn: 'kn-IN', ml: 'ml-IN', pa: 'pa-IN',
  es: 'es-ES', fr: 'fr-FR', ar: 'ar-SA', zh: 'zh-CN', tl: 'fil-PH',
};

export function speechTag(code: string): string {
  return LANG_TAGS[code] ?? code;
}

export function useSpeech() {
  const [speakingId, setSpeakingId] = useState<string | null>(null);
  const mounted = useRef(true);

  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
      Speech.stop();
    };
  }, []);

  const stop = useCallback(() => {
    Speech.stop();
    setSpeakingId(null);
  }, []);

  const speak = useCallback((id: string, text: string, lang = 'en') => {
    Speech.stop();
    if (!text.trim()) return;
    setSpeakingId(id);
    Speech.speak(text, {
      language: speechTag(lang),
      rate: 0.92,
      pitch: 1.0,
      onDone: () => { if (mounted.current) setSpeakingId(null); },
      onStopped: () => { if (mounted.current) setSpeakingId(null); },
      onError: () => { if (mounted.current) setSpeakingId(null); },
    });
  }, []);

  /** Speak this item, or stop if it is the one already speaking. */
  const toggle = useCallback((id: string, text: string, lang = 'en') => {
    if (speakingId === id) stop();
    else speak(id, text, lang);
  }, [speakingId, speak, stop]);

  return { speakingId, speak, stop, toggle };
}
