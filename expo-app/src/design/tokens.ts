/**
 * Cura design tokens.
 *
 * The palette is built around two anchors the product defines:
 *   text  → #9A5337 (comforting brown)
 *   base  → #F2EBE1 (cream)
 *
 * Everything else is a warm neighbour of those two so the whole app reads as
 * one material. No cool greys anywhere — greys are tinted toward the cream.
 */

export const Colors = {
  // ── Anchors ───────────────────────────────────────────────
  brown: '#9A5337',
  cream: '#F2EBE1',

  // ── Surfaces ──────────────────────────────────────────────
  bgBase: '#F2EBE1',
  bgSunken: '#E9DFD1', // behind cards, chat canvas
  surface: '#FBF7F1', // cards
  surfaceRaised: '#FFFCF7', // inputs: a touch lighter than cards, never pure white
  surfaceTinted: '#EFE4D6', // chips, inactive segments

  // ── Text ──────────────────────────────────────────────────
  textPrimary: '#9A5337',
  textStrong: '#6E3A26', // headings, emphasis
  textSecondary: '#A97C63', // supporting copy
  textTertiary: '#C2A492', // placeholders, timestamps
  textOnBrown: '#FDF8F2',

  // ── Lines ─────────────────────────────────────────────────
  separator: '#E2D3C2',
  border: '#D9C6B2',

  // ── Semantic ──────────────────────────────────────────────
  accent: '#9A5337',
  accentSoft: '#EADCCE',
  positive: '#5F7D55', // improving
  positiveSoft: '#E2E9DC',
  caution: '#C08135', // watch
  cautionSoft: '#F5E6D0',
  urgent: '#B04A31', // declining / emergency
  urgentSoft: '#F6DFD7',
  info: '#6B7E96',
  infoSoft: '#E1E6EC',
} as const;

/** Trend direction used by notes, quizzes and the home summary. */
export const TrendColors = {
  better: { fg: Colors.positive, bg: Colors.positiveSoft, label: 'Improving' },
  same: { fg: Colors.textSecondary, bg: Colors.surfaceTinted, label: 'No change' },
  worse: { fg: Colors.caution, bg: Colors.cautionSoft, label: 'Declining' },
  urgent: { fg: Colors.urgent, bg: Colors.urgentSoft, label: 'Needs attention' },
} as const;

export type Trend = keyof typeof TrendColors;

export const Spacing = {
  xxs: 2,
  xs: 4,
  sm: 8,
  md: 16,
  lg: 24,
  xl: 32,
  xxl: 48,
} as const;

/**
 * Corners are deliberately not all the same: inputs and buttons are fairly
 * square (they are tools), cards a little softer, and only small tags are
 * fully round.
 */
export const Radius = {
  sm: 6,
  md: 10,
  lg: 14,
  xl: 18,
  xxl: 24,
  pill: 999,
} as const;

/**
 * Fraunces, a soft old-style serif, for headings: it reads like a letter from
 * family rather than a dashboard. Body text stays in the platform font, which
 * is the most legible choice for small sizes and for older eyes.
 */
export const Fonts = {
  heading: 'Fraunces_600SemiBold',
  headingBold: 'Fraunces_700Bold',
} as const;

export const Type = {
  display: { fontSize: 34, fontFamily: 'Fraunces_700Bold', letterSpacing: -0.5 },
  title: { fontSize: 25, fontFamily: 'Fraunces_600SemiBold', letterSpacing: -0.3 },
  heading: { fontSize: 19, fontFamily: 'Fraunces_600SemiBold', letterSpacing: -0.1 },
  subhead: { fontSize: 16, fontWeight: '600' as const },
  body: { fontSize: 15, fontWeight: '400' as const, lineHeight: 22 },
  callout: { fontSize: 14, fontWeight: '500' as const, lineHeight: 20 },
  caption: { fontSize: 12, fontWeight: '500' as const },
  overline: { fontSize: 11, fontWeight: '700' as const, letterSpacing: 0.8 },
} as const;

/**
 * Shadows use `boxShadow` — React Native deprecated the `shadow*` props (and
 * Android's `elevation`) in 0.86, and boxShadow renders on iOS, Android and web
 * from one declaration.
 *
 * The tint is the same brown as the text, so shadows read as warm depth rather
 * than grey haze on the cream background.
 */
export const Shadow = {
  card: { boxShadow: '0px 2px 8px rgba(110, 58, 38, 0.07)' },
  lifted: { boxShadow: '0px 6px 16px rgba(110, 58, 38, 0.12)' },
} as const;
