/**
 * Original procedural textures (SVG filters as data URIs) — no third-party artwork.
 * Each returns a CSS `background-image` value meant to be blended over a base colour.
 */
const svg = (inner: string, size = 320) =>
  `url("data:image/svg+xml,${encodeURIComponent(`<svg xmlns='http://www.w3.org/2000/svg' width='${size}' height='${size}'>${inner}</svg>`)}")`;

/** Carved stone: fractal noise lit from the top-left. */
export const STONE = svg(
  `<filter id='s' x='0' y='0'><feTurbulence type='fractalNoise' baseFrequency='.028' numOctaves='5' seed='7'/><feDiffuseLighting lighting-color='#9aa0aa' surfaceScale='2.6'><feDistantLight azimuth='225' elevation='52'/></feDiffuseLighting></filter><rect width='100%' height='100%' filter='url(#s)'/>`,
  360,
);

/** Brushed dark metal: anisotropic noise (long horizontal streaks). */
export const METAL = svg(
  `<filter id='m' x='0' y='0'><feTurbulence type='fractalNoise' baseFrequency='.003 .6' numOctaves='3' seed='2'/><feColorMatrix values='0 0 0 0 .62  0 0 0 0 .64  0 0 0 0 .68  0 0 0 .55 0'/></filter><rect width='100%' height='100%' filter='url(#m)'/>`,
  400,
);

/** Aged parchment fibres. */
export const PARCHMENT = svg(
  `<filter id='p' x='0' y='0'><feTurbulence type='fractalNoise' baseFrequency='.65' numOctaves='3' seed='11'/><feColorMatrix values='0 0 0 0 .42  0 0 0 0 .30  0 0 0 0 .15  0 0 0 .42 0'/></filter><rect width='100%' height='100%' filter='url(#p)'/>`,
  240,
);

/** Fine film grain for large dark areas. */
export const GRAIN = svg(
  `<filter id='g'><feTurbulence type='fractalNoise' baseFrequency='.85' numOctaves='2' stitchTiles='stitch'/></filter><rect width='100%' height='100%' filter='url(#g)' opacity='.5'/>`,
  180,
);

/** Metallic gold for display type (use with background-clip:text). */
export const GOLD_TEXT = 'linear-gradient(180deg, #fff3cf 0%, #f0d48f 28%, #c99a45 52%, #8a6424 66%, #e8c983 86%, #fff0c4 100%)';
export const GOLD_STROKE = 'linear-gradient(90deg, transparent, #b8923f 15%, #f3dc9c 50%, #b8923f 85%, transparent)';
