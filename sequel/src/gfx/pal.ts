// Gen 4 palettes: five or six tones per material, soft steps, cool shadows and warm lights.
// Ramps run dark to light.

export type Ramp = readonly string[];

export const PAL = {
  grass: ['#285830', '#327838', '#409848', '#58b458', '#78cc70', '#a8e490'],
  tall: ['#1c4a24', '#28683a', '#34884a', '#48a45a', '#68c070', '#98dc8c'],
  path: ['#8a6440', '#a47c50', '#bc9464', '#d2ae7c', '#e4c898', '#f4e2bc'],
  plaza: ['#6c6a78', '#8a8898', '#a4a2b0', '#bcbac6', '#d2d0da', '#ecebf0'],
  water: ['#1e4c98', '#2a64b8', '#3a7ed0', '#5a9ce4', '#84bcf0', '#c8e6fc'],
  sand: ['#a8844c', '#c09c60', '#d6b478', '#e6ca94', '#f2dcb0', '#fcf0d4'],
  dust: ['#6e4a3a', '#8a5e48', '#a4745a', '#bc8c6c', '#d2a684', '#e8c4a4'],
  rock: ['#3e3440', '#564a58', '#6e6272', '#887c8c', '#a498a8', '#c4bac8'],
  pad: ['#3a3c48', '#4c4e5c', '#606272', '#767888', '#8e909e', '#b0b2be'],
  metal: ['#2c3440', '#3c4654', '#505c6c', '#687688', '#8494a6', '#b0c0d0'],
  floor: ['#4a3c48', '#5e4e5a', '#74626e', '#8c7884', '#a6929c', '#c4b2ba'],
  leaf: ['#123a24', '#1c5a30', '#28783c', '#389a48', '#54b85a', '#88d878'],
  bark: ['#3a2418', '#5a3822', '#7a5030', '#9a6a40', '#b88858'],
  crystal: ['#3a1c5a', '#5a2c88', '#7c44b0', '#a068d4', '#c898ec', '#f0dcff'],
};

// darken for outlines: toward a deep blue-violet, like the DS games
export function ink(hex: string): string {
  const v = parseInt(hex.slice(1, 7), 16);
  const r = (v >> 16) & 255, g = (v >> 8) & 255, b = v & 255;
  const k = 0.32;
  return '#' + [r * k + 8, g * k + 8, b * k + 22].map((c) => Math.min(255, Math.round(c)).toString(16).padStart(2, '0')).join('');
}

export function mix(a: string, b: string, t: number): string {
  const x = parseInt(a.slice(1, 7), 16), y = parseInt(b.slice(1, 7), 16);
  const c = (s: number) => Math.round(((x >> s) & 255) + (((y >> s) & 255) - ((x >> s) & 255)) * t);
  return '#' + [c(16), c(8), c(0)].map((v) => v.toString(16).padStart(2, '0')).join('');
}

// a five-tone ramp from one base colour: cool darks, warm lights
export function rampOf(base: string): string[] {
  return [mix(base, '#10102a', 0.62), mix(base, '#1a1840', 0.36), base, mix(base, '#fff4dc', 0.3), mix(base, '#fffaf0', 0.6)];
}
