// Aliens. Species live among the people of each world as a share of the population: game 1's
// population system makes them (they have homes, jobs, families, grudges like anyone), and
// this layer gives them their bodies, names and voices. Some want things from you:
//   Greys (Luna, Ceres): brokers. They buy what's rare and sell what's forbidden.
//   The Choir (Luna, Titan): hybrids who hum the signal. Listen long enough and it listens back.
//   Martians (Mars): little green tourists with big bankrolls. Pulp to the bone.
//   Saurians (Venus): the Empire's old allies, crested and cold, at court.
//   Belters (Ceres): people the belt changed. Visors, long bones, their own slang.
//   Europans: never seen. They live under the ice and answer the radio (first contact).
// Other stars bring other species (galaxy.ts adds them to SPECIES).

import { SQ, saveSequel } from './state';
import { PLANETS, worldProfile } from './planets';
import { addCargo, GOODS } from './cargo';
import { SCAN, SPACE } from './space';

type Feature = 'mohawk' | 'quiff' | 'elder' | 'antennae' | 'crest' | 'dome' | 'halo' | 'visor' | 'tendrils' | 'horns' | 'fins' | 'implant' | 'robot' | 'mutant' | 'boss';
type Eyes = 'big' | 'glow' | 'slit' | 'many' | 'none' | 'red' | 'bar' | 'odd';
export interface Species {
  id: string; name: string; plural: string; skin: string; eye: string; eyes: Eyes; feature: Feature; accent: string;
  names: string[]; lines: string[]; blurb: string; trader?: boolean; hums?: boolean;
  keepSkin?: boolean; // people with parts added (cyborgs) keep their own skin and hair
  keepName?: boolean; // and their own names
  skins?: string[]; accents?: string[]; // procedural variety, picked per person
  unit?: boolean; // robots get serial numbers
}

export const SPECIES: Record<string, Species> = {
  // ---- the street: neon punks and Bomber gangs (Streets of Fire)
  punk: {
    id: 'punk', name: 'Neon Punk', plural: 'neon punks', skin: '#e0ac7e', eye: '#08080c', eyes: 'none', feature: 'mohawk', accent: '#ff3a7a', keepSkin: true, keepName: true,
    accents: ['#ff3a7a', '#3af0ff', '#68f0a0', '#ffe070', '#c878ff', '#ff8a3a'],
    names: [], lines: ['No future, chum. Literally, we checked.', 'Syndicate can kiss my chrome.', 'You lost, old man?', 'Got a cred for a synth-beer?', 'The Peacekeepers fear the mohawk.'],
    blurb: 'Kids with neon hair and nothing to lose, living in the gaps the Syndicate forgot.',
  },
  bomber: {
    id: 'bomber', name: 'Bomber', plural: 'the Bombers', skin: '#e0ac7e', eye: '#08080c', eyes: 'none', feature: 'quiff', accent: '#141418', keepSkin: true, keepName: true,
    accents: ['#141418', '#2a1a12', '#3a0a0a'],
    names: [], lines: ['This is Bomber turf, pal.', 'Nice coat. It\'d look better on me.', 'We run the Battery. Everybody knows that.', 'You want trouble? We\'re the trouble.', 'Raven says hi.'],
    blurb: 'A motorcycle gang in black leather and grease: rubber overalls, pompadours and bad intentions.',
  },
  // ---- the made and the changed: procedural people of the future
  cyborg: {
    id: 'cyborg', name: 'Cyborg', plural: 'cyborgs', skin: '#e0ac7e', eye: '#ff3030', eyes: 'red', feature: 'implant', accent: '#a8b0c0', keepSkin: true, keepName: true,
    accents: ['#a8b0c0', '#c8a040', '#6a7080', '#d0d8e8', '#8a5a3a'],
    names: [], lines: ['Upgraded the arm. Still owe on the eye.', 'Warranty expired in XX79. I run on spite.', 'Don\'t stare at the chrome, chum.', 'You still all meat? Brave.', 'The clinic on Fifth does knees cheap.'],
    blurb: 'People with parts bought, stolen or grown. Half the street is some percentage machine.',
  },
  robot: {
    id: 'robot', name: 'Robot', plural: 'robots', skin: '#9aa0aa', eye: '#68f0ff', eyes: 'bar', feature: 'robot', accent: '#e84848', unit: true,
    skins: ['#9aa0aa', '#b8a070', '#6a7a8a', '#c8c8d0', '#8a6a5a', '#5a6a5a'], accents: ['#e84848', '#f0b838', '#68f0a0', '#ff5ad0'],
    names: [], lines: ['GREETINGS. PLEASE STATE YOUR BUSINESS.', 'MY SHIFT ENDS IN 4,112 HOURS.', 'I AM NOT PROGRAMMED FOR SMALL TALK. BUT I AM TRYING.', 'DO YOU REQUIRE ASSISTANCE, OR VIOLENCE?', 'BEEP. THAT WAS A JOKE.'],
    blurb: 'Service units, security units, units nobody remembers ordering. Some of them have opinions now.',
  },
  mutant: {
    id: 'mutant', name: 'Mutant', plural: 'mutants', skin: '#8ab86a', eye: '#f0d030', eyes: 'odd', feature: 'mutant', accent: '#6a8a4a', keepName: true,
    skins: ['#8ab86a', '#a878b8', '#c89060', '#6ab8a8', '#b8b860', '#c86a6a'], accents: ['#5a7a3a', '#6a3a7a', '#8a5a2a', '#3a7a6a'],
    names: [], lines: ['Born downwind of the refinery. Grew an extra something.', 'Don\'t drink the tap water. Look at me.', 'The rain did this. The rain does everything.', 'Third eye sees you coming.', 'We were here first. Before the arcologies.'],
    blurb: 'Children of the fallout zones and the poisoned seas. The street takes them in; the arcologies don\'t.',
  },
  android: {
    id: 'android', name: 'Android', plural: 'androids', skin: '#e8e0e8', eye: '#68f0ff', eyes: 'glow', feature: 'implant', accent: '#d0d8e8', keepName: true,
    names: [], lines: ['I remember a childhood. It was installed on a Tuesday.', 'More human than human, they said. They were wrong.', 'I have four years left. I intend to enjoy them.', 'Have you ever wondered if you\'re real?', 'The rain is lovely, from the inside of a window.'],
    blurb: 'Made to look like people, and some of them think they are. The Peacekeepers retire the ones that run.',
  },
  fearman: {
    id: 'fearman', name: 'The Fear Man', plural: 'the Fear Man\'s people', skin: '#b04a7c', eye: '#f0c020', eyes: 'none', feature: 'elder', accent: '#f0c020',
    names: ['The Fear Man'], lines: ['I kept order across a thousand worlds. Now I keep it on this one. Mostly.', 'You were Vane\'s. Now you are mine. Earth is mine. Where did I put my ring?', 'Get me credits, get a ship, get out of my sight. In that order. What order?', 'Order is a kind of fear, properly applied. Who are you again?', 'I remember you. You were younger. So was I.'],
    blurb: 'The Fear Man: once the terror of a thousand worlds, now the one boss of all of Earth\'s underworld, and very, very old. His yellow ring still glows. His memory doesn\'t.',
  },
  grey: {
    id: 'grey', name: 'Grey', plural: 'Greys', skin: '#a8b4bc', eye: '#08080c', eyes: 'big', feature: 'dome', accent: '#d8e0e8', trader: true,
    names: ['Ixx', 'Oolan', 'Tethe', 'Vrin', 'Aash', 'Quelle', 'Numm', 'Seph'],
    lines: ['We buy. We sell. We do not ask.', 'Your species is loud. We like the music.', 'Europa sings to those who listen properly.', 'Everything has a price. Even silence.', 'We were here before the domes. We will be here after.'],
    blurb: 'Brokers from somewhere they won\'t name. They buy what\'s rare and sell what\'s forbidden.',
  },
  choir: {
    id: 'choir', name: 'Choir Hybrid', plural: 'the Choir', skin: '#d8dce8', eye: '#c878ff', eyes: 'glow', feature: 'halo', accent: '#c878ff', hums: true,
    names: ['Canticle', 'Vesper', 'Lauds', 'Matins', 'Antiphon', 'Kyrie', 'Psalter', 'Descant'],
    lines: ['mmmmmmm. The signal is kind.', 'It came from Titan. It is coming for all of us. Gently.', 'Listen. Underneath the static.', 'We were miners once. Now we are the song.', 'Your ring hums in the wrong key.'],
    blurb: 'Miners changed by the signal from Titan. They hum, and their eyes glow violet.',
  },
  martian: {
    id: 'martian', name: 'Martian', plural: 'Martians', skin: '#6ac858', eye: '#101010', eyes: 'big', feature: 'antennae', accent: '#ff5ad0',
    names: ['Zorp', 'Blee', 'Quix', 'Glorbo', 'Zimzam', 'Plonk', 'Veebo', 'Kazoo'],
    lines: ['Greetings, Earthling! Take me to your bookie.', 'We come in peace. We leave broke.', 'Is this the famous casino? It is SO red.', 'Ack ack! Ack!', 'My saucer is double-parked, be quick.'],
    blurb: 'Little green tourists with big bankrolls. The casinos of Mars love them.',
  },
  saurian: {
    id: 'saurian', name: 'Saurian', plural: 'Saurians', skin: '#4a8a5a', eye: '#f0d030', eyes: 'slit', feature: 'crest', accent: '#d8a830',
    names: ['Ssaveth', 'Kraal', 'Issik', 'Thrax', 'Vessa', 'Oskra', 'Zhaal', 'Sarn'],
    lines: ['The Empire is a young thing. We remember older ones.', 'Step aside, warm-blood.', 'The court sits at noon. Justice sits whenever it likes.', 'Your bounty smells delicious.', 'Cold-blooded is a compliment where I come from.'],
    blurb: 'The Empire\'s oldest allies: crested, cold, and in every corridor of the court.',
  },
  belter: {
    id: 'belter', name: 'Belter', plural: 'Belters', skin: '#c8a888', eye: '#101010', eyes: 'none', feature: 'visor', accent: '#f0b838',
    names: ['Anka', 'Dusty', 'Rook', 'Pell', 'Marisol', 'Tamsin', 'Ossie', 'Kit'],
    lines: ['Oi, rock-hopper. Mind the tailings.', 'Gravity\'s for people with money.', 'Claim\'s mine. Shot\'s yours if you want it.', 'Ice is life out here. Ore is just money.', 'You walk like a flatlander.'],
    blurb: 'People the belt changed: long bones, gold visors, their own slang.',
  },
};

// ---------------------------------------------------------------- who is an alien
const hashN = (n: number, k: number) => { let h = (n ^ (k * 0x9e3779b1)) >>> 0; h = Math.imul(h ^ (h >>> 15), 0x2c1b3c6d); h = Math.imul(h ^ (h >>> 12), 0x297a2d39); return ((h ^ (h >>> 15)) >>> 0) / 4294967296; };
const ramp = (hex: string) => {
  const n = parseInt(hex.slice(1), 16), c = [(n >> 16) & 255, (n >> 8) & 255, n & 255];
  const at = (k: number) => '#' + c.map((v) => Math.max(0, Math.min(255, Math.round(k < 0 ? v * (1 + k) : v + (255 - v) * k))).toString(16).padStart(2, '0')).join('');
  return [at(-0.45), at(-0.2), hex, at(0.3)];
};
export function speciesFor(seed: number): Species | null {
  const p = worldProfile();
  if (!p || !p.species) return null;
  let roll = hashN(seed | 0, 7);
  for (const [id, share] of p.species) { if (roll < share && SPECIES[id]) return SPECIES[id]; roll -= share; }
  return null;
}
// the boss of Earth: game 1's Fear Man, ten years older and going grey at the widow's peak
export function fearLook(look: any): void {
  look.xeno = 'fearman'; look.xenoSeed = 1; look.seedStr = 'fearman-old';
  look.skin = '#b04a7c'; look.hair = '#8a8a90'; look.hat = null; look.shades = false; look.fem = false; look.age = 80;
  look.oldOverride = { skin: ['#4a1030', '#7a2050', '#b04a7c', '#e080aa'], hair: ['#4a4a52', '#6a6a72', '#9a9aa2', '#c8c8d0'], style: 'short', stache: true, jacket: ['#0e0e22', '#1c1c3c', '#2c2c5a', '#44447a'], top: 'collar', shirt: ['#6a4600', '#b88400', '#f0c020', '#fff27a'], pants: ['#08080e', '#14141e', '#22222e', '#34344a'], belt: '#f0c020', flare: false };
  look.old = null;
}
function alienise(look: any, sp: Species, seed: number): void {
  look.xeno = sp.id; look.xenoSeed = seed;
  const pickOf = (a: string[] | undefined, k: number, d: string) => (a && a.length ? a[Math.floor(hashN(seed, k) * a.length)] : d);
  look.xenoAccent = pickOf(sp.accents, 11, sp.accent);
  look.seedStr = 'xeno-' + sp.id + '-' + seed;
  if (sp.keepSkin) { look.old = null; return; }
  const skin = pickOf(sp.skins, 12, sp.skin);
  look.xenoSkin = skin;
  look.skin = skin; look.hair = skin; look.beard = false; look.hat = null; look.shades = false;
  look.oldOverride = Object.assign({}, look.oldOverride || {}, { skin: ramp(skin), style: 'bald', stache: false, glasses: false });
  look.old = null;
}

const POP = R.Population.prototype, baseLook = POP.makeLook;
POP.makeLook = function (this: unknown, rnd: () => number, p: any) {
  const look = baseLook.call(this, rnd, p);
  if (!p || p.role === 'cop' || p.role === 'detective' || p.seed == null) return look;
  if (p.isDon && p.faction === 'Vane' && SQ.planet === 'earth' && SQ.home === 'sol') { fearLook(look); return look; }
  const sp = speciesFor(p.seed);
  if (!sp) return look;
  alienise(look, sp, p.seed);
  // the population gives everyone a human name; aliens keep their own
  if (!p._xeno) {
    p._xeno = sp.id;
    if (sp.unit) { p.first = ['UNIT', 'SERV', 'SEC', 'MED', 'CARGO', 'ORBO'][Math.floor(hashN(p.seed, 3) * 6)]; p.last = (100 + Math.floor(hashN(p.seed, 4) * 900)) + '-' + 'XKRZVT'[Math.floor(hashN(p.seed, 5) * 6)]; }
    else if (!sp.keepName && sp.names.length) { p.first = sp.names[Math.floor(hashN(p.seed, 3) * sp.names.length)]; p.last = sp.id === 'belter' ? p.last : sp.plural === 'the Choir' ? 'of the Choir' : sp.name; }
  }
  return look;
};

// ---------------------------------------------------------------- bodies
// [dx from face centre, row in the 16x32 cell, w, h, colour]
type Pix = [number, number, number, number, string];
const FEATURES: Record<Feature, (s: Species) => { front: Pix[]; back: Pix[] }> = {
  antennae: (s) => { const f: Pix[] = [[-3, -3, 1, 5, s.skin], [2, -3, 1, 5, s.skin], [-4, -5, 2, 2, s.accent], [2, -5, 2, 2, s.accent]]; return { front: f, back: f }; },
  crest: (s) => { const f: Pix[] = [[-1, -2, 2, 6, s.accent], [-2, 0, 4, 1, s.accent], [0, -3, 1, 2, s.accent]]; return { front: f, back: f }; },
  // a tall rounded cranium, lit from the top left
  dome: (s) => { const f: Pix[] = [[-3, -2, 6, 1, s.skin], [-5, -1, 10, 1, s.skin], [-6, 0, 12, 4, s.skin], [-3, -1, 3, 1, s.accent], [-5, 0, 2, 2, s.accent]]; return { front: f, back: f }; },
  halo: (s) => { const f: Pix[] = [[-4, -3, 8, 1, s.accent], [-5, -2, 1, 1, s.accent], [4, -2, 1, 1, s.accent]]; return { front: f, back: f }; },
  visor: (s) => ({ front: [[-5, 11, 10, 2, s.accent], [-5, 11, 10, 1, '#fff4c0'], [-6, 11, 1, 1, '#3a3a42'], [5, 11, 1, 1, '#3a3a42']], back: [[-5, 11, 10, 1, '#3a3a42']] }),
  tendrils: (s) => { const f: Pix[] = [[-5, 12, 1, 4, s.accent], [-2, 13, 1, 4, s.accent], [1, 13, 1, 4, s.accent], [4, 12, 1, 4, s.accent]]; return { front: f, back: [] }; },
  horns: (s) => { const f: Pix[] = [[-5, 0, 2, 2, s.accent], [-6, -2, 2, 2, s.accent], [3, 0, 2, 2, s.accent], [4, -2, 2, 2, s.accent]]; return { front: f, back: f }; },
  fins: (s) => { const f: Pix[] = [[-8, 6, 2, 5, s.accent], [6, 6, 2, 5, s.accent], [-1, -1, 2, 3, s.accent]]; return { front: f, back: f }; },
  // a chrome plate over one side of the face, a jack behind the ear
  implant: (s) => ({ front: [[1, 6, 5, 6, s.accent], [2, 7, 3, 1, '#ffffff'], [5, 12, 1, 2, s.accent]], back: [[-2, 8, 3, 3, s.accent], [-1, 9, 1, 1, '#ff3030']] }),
  // a boxy head, rivets, an antenna with a light
  robot: (s) => { const f: Pix[] = [[-6, 2, 12, 11, s.skin], [-6, 2, 12, 1, '#ffffff'], [-6, 12, 12, 1, '#303038'], [0, -3, 1, 5, '#303038'], [-1, -4, 3, 2, s.accent], [-6, 6, 1, 1, '#303038'], [5, 6, 1, 1, '#303038']]; return { front: f, back: f }; },
  // lumps and a crooked growth, per person
  mutant: (s) => ({ front: [[-6, 3, 3, 2, s.accent], [3, 1, 3, 3, s.accent], [-2, 13, 4, 1, s.accent]], back: [[-5, 2, 4, 3, s.accent], [2, 4, 3, 2, s.accent]] }),
  // a neon mohawk, spiked tall
  mohawk: (s) => ({ front: [[-1, -4, 2, 7, s.accent], [-1, -5, 2, 1, '#ffffff'], [1, 12, 1, 1, '#d0d8e8'], [-2, 12, 1, 1, '#d0d8e8']], back: [[-1, -4, 2, 8, s.accent], [-1, -5, 2, 1, '#ffffff']] }),
  // a greased pompadour and a leather collar
  quiff: (s) => ({ front: [[-5, 0, 10, 4, '#141418'], [-4, -1, 7, 2, '#2a2a34'], [2, 0, 3, 1, '#58586a'], [-4, 16, 8, 2, s.accent]], back: [[-5, 0, 10, 5, '#141418'], [-4, 16, 8, 2, s.accent]] }),
  // the Fear Man: a widow's peak and the yellow ring glowing on his hand
  elder: () => ({ front: [[-1, 3, 2, 3, '#1a1a20'], [5, 20, 2, 2, '#f0c020'], [6, 19, 1, 1, '#fff27a']], back: [[-1, 3, 2, 2, '#1a1a20']] }),
  // (unused since the Fear Man took Earth) a crown of spines and a beard of tendrils
  boss: (s) => { const f: Pix[] = [[-6, -3, 2, 4, s.accent], [-2, -5, 2, 6, s.accent], [2, -4, 2, 5, s.accent], [5, -2, 2, 3, s.accent], [-5, 12, 1, 5, s.accent], [-2, 13, 1, 6, s.accent], [1, 13, 1, 6, s.accent], [4, 12, 1, 5, s.accent]]; return { front: f, back: f.slice(0, 4) }; },
};
const EYES: Record<Eyes, (s: Species) => Pix[]> = {
  big: (s) => [[-4, 9, 3, 2, s.eye], [1, 9, 3, 2, s.eye], [-3, 9, 1, 1, '#ffffff']],
  glow: (s) => [[-3, 10, 1, 1, s.eye], [2, 10, 1, 1, s.eye], [-4, 10, 1, 1, 'rgba(200,120,255,0.4)'], [3, 10, 1, 1, 'rgba(200,120,255,0.4)']],
  slit: (s) => [[-3, 9, 2, 2, s.eye], [2, 9, 2, 2, s.eye], [-3, 9, 1, 2, '#101010'], [2, 9, 1, 2, '#101010']],
  many: (s) => [[-4, 8, 1, 1, s.eye], [-2, 9, 1, 1, s.eye], [1, 9, 1, 1, s.eye], [3, 8, 1, 1, s.eye], [-1, 7, 2, 1, s.eye]],
  none: () => [],
  red: (s) => [[2, 10, 2, 1, s.eye], [4, 10, 1, 1, 'rgba(255,48,48,0.5)']],
  bar: (s) => [[-4, 9, 8, 2, '#101014'], [-3, 9, 6, 1, s.eye]],
  odd: (s) => [[-3, 10, 1, 1, '#101010'], [2, 10, 2, 2, '#101010'], [0, 7, 1, 1, s.eye]],
};
const DIR8 = ['right', 'downright', 'down', 'downright', 'right', 'upright', 'up', 'upright'];
const FLIP8 = [false, false, false, true, true, true, false, false];
function paint(g: CanvasRenderingContext2D, X: number, Y: number, list: Pix[], n: string, flip: boolean): void {
  const cx = n === 'down' || n === 'up' ? 7.5 : n === 'downright' || n === 'upright' ? 9 : 10;
  const sq = n === 'right' ? 0.6 : n === 'downright' || n === 'upright' ? 0.85 : 1;
  for (const [dx, row, w, h, c] of list) {
    const sx = cx + dx * sq, x = flip ? 16 - sx - w : sx;
    g.fillStyle = c;
    g.fillRect(Math.round(X - 8 + x), Math.round(Y - 25 + row), Math.max(1, Math.round(w * sq)), h);
  }
}
const A = R.art as any, baseDraw = A.drawPerson;
A.drawPerson = function (g: CanvasRenderingContext2D, x: number, y: number, dir: number, walk: number, look: any, st: any) {
  const res = baseDraw.call(this, g, x, y, dir, walk, look, st);
  const sp: Species | undefined = look && look.xeno ? SPECIES[look.xeno] : undefined;
  if (!sp || look.mask || (st && (st.down || st.scale || st.crouch))) return res;
  const moving = walk && Math.abs(walk) > 0.01, bob = moving && (Math.floor(walk * 0.5) % 4) % 2 ? 1 : 0;
  const X = Math.round(x), Y = Math.round(y) - bob;
  const d8 = A.dir8(dir, st && st.ang), n = DIR8[d8], flip = FLIP8[d8], back = n === 'up' || n === 'upright';
  const varied: Species = look.xenoAccent || look.xenoSkin ? Object.assign({}, sp, { accent: look.xenoAccent || sp.accent, skin: look.xenoSkin || sp.skin }) : sp;
  const f = FEATURES[sp.feature](varied);
  paint(g, X, Y, back ? f.back : f.front, n, flip);
  if (!back) paint(g, X, Y, EYES[sp.eyes](varied), n, flip);
  return res;
};

// ---------------------------------------------------------------- voices
const D2 = R.dialog, baseLine = D2.line;
D2.line = function (kind: string, h: any) {
  const sp = h && h.look && h.look.xeno && SPECIES[h.look.xeno];
  if (sp && (kind === 'greet' || kind === 'hello' || kind === 'chat' || Math.random() < 0.35)) return sp.lines[Math.floor(Math.random() * sp.lines.length)];
  return baseLine.call(this, kind, h);
};
// the Choir hums as it walks
const GP = R.Game.prototype, baseTick = GP.tick;
let humT = 0;
GP.tick = function (this: Game, dt: number) {
  const r = baseTick.call(this, dt);
  humT -= dt;
  if (humT <= 0 && this.actors && !this.ui.paused()) {
    humT = 3 + Math.random() * 4;
    const pl = this.player;
    const near = this.actors.list.find((a: any) => a.kind === 'h' && !a.dead && a.look && a.look.xeno === 'choir' && Math.hypot(a.x - pl.x, a.y - pl.y) < 140);
    if (near) this.fx.text(near.x, near.y - 22, 'mmmmm', '#c878ff');
  }
  return r;
};

// ---------------------------------------------------------------- what they want from you
const nearAlien = (pl: Player, id: string) => R.game.actors.list.find((a: any) => a.kind === 'h' && !a.dead && !a.hostile && a.down <= 0 && a.look && a.look.xeno === id && Math.hypot(a.x - pl.x, a.y - pl.y) < 22 && a.room === pl.room);
const alienName = (a: any) => (a.person ? R.game.pop.name(a.person) : SPECIES[a.look.xeno].name);
const PP = R.Player.prototype, baseCtx = PP.contextAction;
PP.contextAction = function (this: Player) {
  if (!this.inCar && !SPACE.active) {
    const grey = nearAlien(this, 'grey');
    if (grey) return { label: 'Trade with ' + alienName(grey), fn: () => greyTrade(R.game, grey) };
    const choir = nearAlien(this, 'choir');
    if (choir) return { label: 'Listen to ' + alienName(choir), fn: () => listen(R.game, choir) };
  }
  return baseCtx.call(this);
};

const have = (good: string) => SQ.cargo.filter((l) => l.good === good && l.n > 0).reduce((s, l) => s + l.n, 0);
function take(good: string, n: number): number {
  let left = n;
  for (const l of SQ.cargo) if (l.good === good && left > 0) { const k = Math.min(l.n, left); l.n -= k; left -= k; }
  SQ.cargo = SQ.cargo.filter((l) => l.n > 0);
  return n - left;
}
export function greyTrade(g: Game, a: any): void {
  const pl = g.player, name = alienName(a);
  const buy = (good: 'pearls' | 'plat' | 'ice', mul: number) => {
    const n = have(good);
    return { label: `Sell ${GOODS[good].name} (${n})`, small: n ? `$${Math.round(GOODS[good].base * mul)} each, from your holds` : 'You have none', fn: () => { if (!n) return; take(good, n); pl.cash += Math.round(GOODS[good].base * mul) * n; g.audio.sfx('cash'); saveSequel(); g.ui.toast(`${name} pays in clean credits. They don't ask where it came from.`, 'good'); } };
  };
  const tech = Math.round(GOODS.xeno.base * 0.75);
  g.ui.choice(`${name} · Grey broker`, [
    buy('pearls', 2.2), buy('plat', 1.5), buy('ice', 1.2),
    { label: `Buy Xeno-Tech ($${tech})`, small: 'Contraband everywhere the Empire reaches. Worth a fortune to the right buyer.', fn: () => {
      if (pl.cash < tech) return g.ui.toast('"You cannot afford the future."', 'warn');
      if (!addCargo('xeno', 1, true)) return g.ui.toast('Your holds are full.', 'warn');
      pl.cash -= tech; g.audio.sfx('cash'); saveSequel(); g.ui.toast('A humming grey box, cold to the touch. Keep it hidden.', 'good');
    } },
    { label: 'Ask about Europa', fn: () => g.ui.story(name, SQ.flags.europa ? '"You have heard them sing. Bring us their pearls and we will make you rich."' : '"Under the ice of Jupiter\'s second moon, something answers the radio. Fly close, scan it, and listen. They speak in patterns. Repeat them back, exactly."') },
    { label: 'Leave', fn: () => {} },
  ]);
}
function listen(g: Game, a: any): void {
  const n = (SQ.flags.choir = (SQ.flags.choir || 0) + 1);
  saveSequel();
  const pl = g.player;
  const lines = [
    'The humming fills your head like warm water. For a second you remember a desert, a gun, a don who picked you up off the sand. Then it\'s gone.',
    '"You were someone else, once. So were we." The hybrid touches your ring hand. The ring hums back, out of tune.',
    '"Go to Titan. Our Cathedral hangs over it. The signal wants to meet you."',
  ];
  if (pl.will != null && pl.willMax) pl.will = Math.min(pl.willMax, pl.will + 20);
  g.ui.story(alienName(a), lines[Math.min(n, 3) - 1] + (n >= 3 ? '\n\n(The Cathedral of the Choir orbits Titan: pick it from "Where to?" in space.)' : ''));
}

// ---------------------------------------------------------------- Europa: first contact
// Scanning Europa opens a channel. They answer in patterns of four tones; repeat each one back.
SCAN.europa = (g: Game) => {
  if (SQ.flags.europa) return europaTrade(g);
  contact(g);
};
export const CONTACT: { st: any } = { st: null };
export function contact(g: Game): void {
  const TONES = ['LOW', 'MID', 'HIGH', 'DEEP'], COLS = ['#3a7ed0', '#68f0a0', '#f0d040', '#c878ff'];
  const rounds = [3, 4, 5];
  CONTACT.st = R.mini.open({
    title: 'Europa · Open Channel', sub: 'Something under the ice is answering. Watch the pattern, then play it back exactly. Three phrases.', w: 240, h: 130,
    buttons: [['0', 'LOW'], ['1', 'MID'], ['2', 'HIGH'], ['3', 'DEEP'], ['quit', 'CUT LINK']],
    init(this: any, s: any) { s.press = (id: string) => this.press(s, id); s.round = 0; s.seq = []; s.pos = 0; s.show = 0; s.lit = -1; s.litT = 0; s.newRound = () => { s.seq = Array.from({ length: rounds[s.round] }, () => Math.floor(Math.random() * 4)); s.pos = 0; s.show = 1.2; s.msg(`Phrase ${s.round + 1} of 3. Listen...`); }; s.newRound(); },
    update(s: any, dt: number) {
      s.litT -= dt;
      if (s.show > 0) {
        s.show += dt;
        const k = Math.floor((s.show - 1.2) / 0.6);
        if (s.show > 1.2 && k < s.seq.length) { s.lit = s.seq[k]; s.litT = 0.35; }
        if (k >= s.seq.length) { s.show = 0; s.msg('Your turn. Play it back.'); }
      }
      if (s.litT <= 0 && s.show <= 0) s.lit = -1;
    },
    press(s: any, id: string) {
      if (id === 'quit') return s.finish(false, 0);
      if (s.show > 0) return;
      const t = +id;
      s.lit = t; s.litT = 0.25; R.game.audio.sfx('click');
      if (s.seq[s.pos] !== t) { s.msg('Static. They go quiet, then start again.'); s.round = Math.max(0, s.round - 1); return s.newRound(); }
      s.pos++;
      if (s.pos >= s.seq.length) {
        s.round++;
        if (s.round >= rounds.length) { s.msg('The channel fills with song.'); return s.finish(true, 1400); }
        s.newRound();
      }
    },
    down(s: any, x: number) { if (x > 20 && x < 220) this.press(s, String(Math.min(3, Math.floor((x - 20) / 50)))); },
    draw(g2: CanvasRenderingContext2D, s: any) {
      g2.fillStyle = '#04081a'; g2.fillRect(0, 0, 240, 130);
      for (let k = 0; k < 40; k++) { g2.fillStyle = 'rgba(120,180,255,0.15)'; g2.fillRect((k * 53) % 240, (k * 29) % 60, 1, 1); }
      // the ice, and the light under it
      g2.fillStyle = '#c8d8e8'; g2.fillRect(0, 60, 240, 6);
      const glow = s.lit >= 0 ? COLS[s.lit] : '#0a1a3a';
      g2.fillStyle = glow; g2.globalAlpha = 0.35; g2.fillRect(0, 66, 240, 64); g2.globalAlpha = 1;
      for (let k = 0; k < 4; k++) {
        const x = 20 + k * 50;
        g2.fillStyle = '#1b1410'; g2.fillRect(x - 1, 79, 42, 32);
        g2.fillStyle = s.lit === k ? '#ffffff' : COLS[k]; g2.fillRect(x, 80, 40, 30);
        R.art.ptext(g2, TONES[k], x + 20, 90, { align: 'center', color: '#1b1410', shadow: null });
      }
      R.art.ptext(g2, `PHRASE ${Math.min(3, s.round + 1)}/3`, 120, 20, { align: 'center', color: '#a8c8ff' });
      for (let k = 0; k < s.seq.length; k++) { g2.fillStyle = k < s.pos ? '#68f0a0' : '#2a3a5a'; g2.fillRect(120 - s.seq.length * 5 + k * 10, 36, 7, 7); }
    },
  }, (ok: boolean) => {
    if (!ok) return;
    SQ.flags.europa = 1;
    const put = addCargo('pearls', 3, false);
    saveSequel();
    g.player.rep.honor = (g.player.rep.honor || 0) + 5;
    setTimeout(() => g.ui.story('First Contact', `You played their song back to them, and under two kilometres of ice, something sang along.\n\nThe Europans have no hands and no ships, but they have gifts: ${put ? put + ' Song-Pearls drift up through a crack in the ice and into your hold.' : 'your holds are full, so the pearls sink back down. Come back with room.'}\n\nThey want music. Bring Holo-Vinyl and scan Europa again to trade. The Greys on Luna will pay a fortune for the pearls.`), 300);
  });
}
function europaTrade(g: Game): void {
  const v = have('vinyl');
  g.ui.choice('Europa · the deep ones sing', [
    { label: `Play them your Holo-Vinyl (${v})`, small: 'Two pearls for every record', fn: () => {
      if (!v) return g.ui.toast('You have no Holo-Vinyl. Venus and Earth sell it cheap.', 'warn');
      take('vinyl', v);
      const put = addCargo('pearls', v * 2, false);
      saveSequel(); g.audio.sfx('loot');
      g.ui.toast(`The ice lights up. ${put} Song-Pearls drift into your hold.`, 'good');
    } },
    { label: 'Just listen', fn: () => { if (g.player.will != null && g.player.willMax) g.player.will = g.player.willMax; g.ui.toast('Whale-song and pipe organs. Your ring charges full.', 'good'); } },
  ]);
}

// ---------------------------------------------------------------- Titan: the signal
SCAN.titan = (g: Game) => {
  if (!SQ.flags.choir) return g.ui.story('Titan', 'Orange haze and methane lakes. Your scanner picks up a hum under the static, too regular to be weather.\n\n(Someone on Luna might know what it is.)');
  if (SQ.flags.signal) return g.ui.story('Titan', 'The signal hums in your ring now. It knows you.');
  g.ui.choice('Titan · the signal', [
    { label: 'Let it in', small: 'The Choir will know you as one of their own', fn: () => { SQ.flags.signal = 1; saveSequel(); if (g.player.willMax) { g.player.willMax += 20; g.player.will = g.player.willMax; } g.ui.story('The Signal', 'It isn\'t a voice. It\'s a key change. For a moment every star in the sky is a note, and you can hear the whole chord.\n\nYour ring holds more now. And the Choir will greet you as family.'); } },
    { label: 'Shut the scanner off', fn: () => { SQ.flags.signal = -1; saveSequel(); g.ui.toast('Silence. The hum stays in your teeth for an hour.'); } },
  ]);
};

export const speciesOn = (id: string) => (PLANETS[id] && PLANETS[id].species ? PLANETS[id].species!.map(([s]) => SPECIES[s]).filter(Boolean) : []);

(window as any).BS2 = Object.assign((window as any).BS2 || {}, { SPECIES, CONTACT, greyTrade });
