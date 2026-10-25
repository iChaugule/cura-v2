/**
 * Which web sources Cura AI is allowed to lean on.
 *
 * Search grounding cannot be restricted to a list of sites ahead of time, so
 * every source is checked after the fact. Only clinical bodies, government
 * health agencies, universities and recognised dementia charities are kept.
 * Everything else (forums, care-home sales pages, blogs, product pages) is
 * dropped from the list shown to the person, and the answer says so when
 * nothing trustworthy backed it.
 */
import type { AiSource } from '../models/types';

const TRUSTED_DOMAINS = [
  'nih.gov', 'nia.nih.gov', 'medlineplus.gov', 'ncbi.nlm.nih.gov', 'cdc.gov', 'cms.gov', 'va.gov',
  'who.int', 'alz.org', 'alzint.org', 'alzheimers.org.uk', 'dementiauk.org', 'alzheimer.ca',
  'dementia.org.au', 'alzheimers.gov', 'nhs.uk', 'nice.org.uk', 'mayoclinic.org', 'clevelandclinic.org',
  'hopkinsmedicine.org', 'health.harvard.edu', 'cochrane.org', 'thelancet.com', 'jamanetwork.com',
  'bmj.com', 'nejm.org', 'nature.com', 'aafp.org', 'ama-assn.org', 'aan.com', 'geriatrics.org',
  'healthinaging.org', 'nimhans.ac.in', 'icmr.gov.in', 'mohfw.gov.in', 'ardsi.org',
];

/** Any site on these suffixes is a government or university body. */
const TRUSTED_SUFFIXES = ['.gov', '.gov.uk', '.gov.au', '.gov.in', '.nic.in', '.edu', '.ac.uk', '.edu.au', '.ac.in'];

/** A grounding source's title is usually its domain; fall back to the link. */
function hostOf(src: AiSource): string {
  const title = src.title.trim().toLowerCase();
  if (/^[a-z0-9.-]+\.[a-z]{2,}$/.test(title)) return title.replace(/^www\./, '');
  try {
    return new URL(src.uri).hostname.replace(/^www\./, '').toLowerCase();
  } catch {
    return title;
  }
}

export function isReliableSource(src: AiSource): boolean {
  const host = hostOf(src);
  // The search service wraps real links in its own redirect; only the title tells us the site.
  if (host.includes('vertexaisearch') || host.includes('googleapis')) return false;
  if (TRUSTED_DOMAINS.some(d => host === d || host.endsWith(`.${d}`))) return true;
  return TRUSTED_SUFFIXES.some(sfx => host.endsWith(sfx));
}

export function reliableSources(sources: AiSource[]): AiSource[] {
  return sources.filter(isReliableSource);
}

export const NO_TRUSTED_SOURCE_NOTE =
  'I could not confirm this with a trusted medical source, so please check it with their doctor or pharmacist before acting on it.';

/**
 * Cura never tells a family what stage of dementia someone is in. Stage words
 * are removed from model output even if the record or a source used them.
 */
export function stripStageTerms(text: string): string {
  return text
    .replace(/\b(?:in )?(?:the )?(?:early|middle|late|mild|moderate|severe|advanced|end)[- ]stages? of\b/gi, 'with')
    .replace(/\b(?:early|middle|mid|late|mild|moderate|severe|advanced|end)[- ]stage\b ?/gi, '')
    .replace(/\b(?:mild|moderate|severe|advanced) (Alzheimer[’']?s|dementia)\b/gi, '$1')
    .replace(/[ \t]{2,}/g, ' ');
}
