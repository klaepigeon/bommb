// The galaxy, starting next door. The jump drive reaches real nearby stars (their real names,
// distances and colours); what orbits them is generated from the star's name, so every save
// sees the same worlds. Each system has planets, moons, sometimes a belt, and one or two
// inhabited worlds: a full game 1 world each, with its own cities, families, law, aliens and
// wildlife. Jumping needs the Jump Drive module, jump fuel, and clear space: far enough from
// the star and from every world that the fold doesn't tear the ship apart.

import { SQ, saveSequel } from './state';
import { AU, GEN, SOL, loadSystem, systemData, type BodyDef, type Profile, type System } from './planets';
import { SPECIES, type Species } from './aliens';
import { registerFauna, type Beast } from './eco';
import { SPACE, HOOKS } from './space';
import { stats } from '../ship/ship';
import { bodies } from '../space/system';

// the neighbourhood: real stars, real distances (light years), real spectral colours
export const STARS: { id: string; name: string; ly: number; col: string; radius: number; blurb: string }[] = [
  { id: 'centauri', name: 'Alpha Centauri', ly: 4.37, col: '#fff0c0', radius: 2800, blurb: 'Two suns like ours, dancing. Everyone\'s first stop.' },
  { id: 'barnard', name: 'Barnard\'s Star', ly: 5.96, col: '#ff8a5a', radius: 1400, blurb: 'An old red dwarf, running fast across the sky.' },
  { id: 'wolf359', name: 'Wolf 359', ly: 7.9, col: '#ff6a4a', radius: 1100, blurb: 'Dim, flaring, and famous for the wrong reasons.' },
  { id: 'sirius', name: 'Sirius', ly: 8.6, col: '#d8e8ff', radius: 3600, blurb: 'The brightest star in Earth\'s sky, and its white dwarf shadow.' },
  { id: 'eridani', name: 'Epsilon Eridani', ly: 10.5, col: '#ffd890', radius: 2300, blurb: 'Young, dusty, ringed with belts. Frontier country.' },
  { id: 'tauceti', name: 'Tau Ceti', ly: 11.9, col: '#fff4d0', radius: 2500, blurb: 'Quiet, sunlike, and full of old comets.' },
];
export const star = (id: string) => STARS.find((s) => s.id === id);

// ---------------------------------------------------------------- a seeded generator
function rng(seed: string) {
  let h = 2166136261;
  for (let i = 0; i < seed.length; i++) h = Math.imul(h ^ seed.charCodeAt(i), 16777619);
  let s = h >>> 0;
  const r = () => { s = (s + 0x6d2b79f5) >>> 0; let t = s; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
  return { r, pick: <T>(a: T[]) => a[Math.floor(r() * a.length)], int: (a: number, b: number) => a + Math.floor(r() * (b - a + 1)) };
}
const SYL = ['ka', 'vo', 'ri', 'tha', 'mel', 'zan', 'or', 'ix', 'le', 'dun', 'sa', 'qua', 'bel', 'nor', 'ae', 'tor', 'vy', 'shen', 'ul', 'ra', 'mo', 'ke', 'zi', 'an'];
type Rng = ReturnType<typeof rng>;
const word = (g: Rng, n = g.int(2, 3)) => { let s = ''; for (let k = 0; k < n; k++) s += g.pick(SYL); return s[0].toUpperCase() + s.slice(1); };
const hexMix = (a: string, b: string, k: number) => { const pa = parseInt(a.slice(1), 16), pb = parseInt(b.slice(1), 16); const c = [16, 8, 0].map((sh) => Math.round(((pa >> sh) & 255) * (1 - k) + ((pb >> sh) & 255) * k)); return '#' + c.map((v) => v.toString(16).padStart(2, '0')).join(''); };
const PALETTE = ['#c8603a', '#4a8a4a', '#3a7ed0', '#d8a878', '#8a8478', '#a8e0e8', '#e8d098', '#6a4a8a', '#c84888', '#48b8a0', '#b8c848', '#e89048'];

// ---------------------------------------------------------------- species and wildlife for new worlds
const FEATS = ['antennae', 'crest', 'dome', 'halo', 'visor', 'tendrils', 'horns', 'fins'] as const;
const EYES = ['big', 'glow', 'slit', 'many', 'none'] as const;
const VOICES = [
  ['The sky here is the right colour. Yours is wrong.', 'You smell of engines.', 'Trade or leave. Both are fine.', 'We heard about your Empire. We are not impressed.', 'Welcome, far-traveller.'],
  ['Hhhrrrk. Credits?', 'The old ones built this place. We just live in it.', 'Your ship is small. Your guns are not.', 'Do not drink the water. Or do. It is your funeral.', 'Tell the Solari we remember them.'],
  ['Sing with us, or be quiet.', 'We have been waiting for a ship like yours.', 'The families here are older than your sun\'s planets.', 'Another human. How charming.', 'Mind the wildlife. It minds you.'],
];
function makeSpecies(g: Rng, id: string): Species {
  const skin = g.pick(PALETTE), accent = g.pick(PALETTE.filter((c) => c !== skin));
  const name = word(g, 2);
  const sp: Species = {
    id, name, plural: name + (name.endsWith('s') ? 'i' : 's'), skin, eye: g.pick(['#08080c', '#f0d030', '#68f0a0', '#ff5a8a', '#c878ff']), eyes: g.pick([...EYES]), feature: g.pick([...FEATS]), accent,
    names: Array.from({ length: 8 }, () => word(g, 2)), lines: g.pick(VOICES), blurb: `The ${name} people of this world.`, trader: g.r() < 0.3,
  };
  SPECIES[id] = sp;
  return sp;
}
function makeFauna(g: Rng, id: string, terrain: string): void {
  const col = () => g.pick(PALETTE);
  const bio = terrain === 'ice' ? ['snow', 'desert', 'grass', 'forest'] : terrain === 'jungle' ? ['grass', 'forest', 'marsh', 'field'] : ['grass', 'forest', 'desert', 'field', 'marsh'];
  const set: Record<string, Beast> = {
    grazer: { name: word(g, 2) + ' ' + g.pick(['Buck', 'Strider', 'Grazer', 'Hopper']), size: g.int(6, 11), hp: 40, speed: 105, prey: 1, col: col(), biome: bio, herd: [2, 5], shape: g.pick(['quad', 'strider', 'crab'] as const), role: 'prey' },
    small: { name: word(g, 2) + ' ' + g.pick(['Rat', 'Hare', 'Bug', 'Skitter']), size: 5, hp: 8, speed: 95, prey: 1, col: col(), biome: bio, herd: [1, 4], role: 'prey' },
    hunter: { name: word(g, 2) + ' ' + g.pick(['Stalker', 'Wolf', 'Cat', 'Fang']), size: g.int(8, 11), hp: 60, speed: 118, predator: 1, dmg: 12, col: col(), biome: bio, herd: [1, 3], night: 1.6, role: 'pred' },
    lurker: { name: word(g, 2) + ' ' + g.pick(['Worm', 'Lurker', 'Maw', 'Jelly']), size: 12, hp: 120, speed: 70, predator: 1, ambush: 1, dmg: 26, col: col(), biome: bio.slice(0, 2), shape: g.pick(['worm', 'blob'] as const), role: 'pred' },
    crow: { name: word(g, 2) + ' Flier', size: 4, hp: 3, speed: 130, bird: 1, col: col(), biome: bio.concat(['city']), herd: [2, 6], role: 'bird' },
    gull: { name: word(g, 2) + ' Flier', size: 4, hp: 3, speed: 130, bird: 1, col: col(), biome: ['coast', 'city'], herd: [2, 6], role: 'bird' },
    dog: { name: 'Street ' + word(g, 2), size: 6, hp: 20, speed: 100, dmg: 5, col: col(), biome: ['city'], role: 'pest' },
  };
  registerFauna(id, set);
}
function makeWorld(g: Rng, sys: string, pid: string, name: string): Profile {
  const terrain = g.pick(['jungle', 'ice', 'mars', 'moon', 'capital', 'earth'] as const);
  const sp1 = makeSpecies(g, `${sys}-${pid}-a`), sp2 = g.r() < 0.6 ? makeSpecies(g, `${sys}-${pid}-b`) : null;
  makeFauna(g, `${sys}-${pid}`, terrain);
  const fams = Array.from({ length: 5 }, () => word(g, 2));
  const tags = ['the old quarter', 'the spaceport strip', 'where the money sleeps', 'the lawless edge', 'farm towns and feuds', 'the temple district', 'smugglers\' coves', 'the neon mile'];
  const law = g.pick(['Hive Wardens', 'The Watch', 'Council Guard', 'Peacekeepers', 'Temple Guard']);
  return {
    id: pid, name, faction: `the ${sp1.plural} and five old families`, blurb: `${name}: ${terrain === 'ice' ? 'a frozen world of domes and deep mines' : terrain === 'jungle' ? 'a hothouse jungle world' : terrain === 'moon' ? 'an airless rock with domed towns' : terrain === 'capital' ? 'a world of white cities and old money' : terrain === 'mars' ? 'a half-terraformed desert' : 'a blue-green world much like Earth'}, home of the ${sp1.plural}${sp2 ? ' and the ' + sp2.plural : ''}.`,
    law, terrain, black: g.r() < 0.6, fauna: `${sys}-${pid}`,
    species: sp2 ? [[sp1.id, 0.3], [sp2.id, 0.15]] : [[sp1.id, 0.4]],
    cities: fams.map((f, i) => ({ name: word(g, 2) + ' ' + g.pick(['Port', 'Reach', 'Hollow', 'Spire', 'Gate', 'Crossing', 'Deep', 'Heights']), tag: g.pick(tags), family: f, don: `${g.pick(['Old', 'Mother', 'Don', 'Lady', 'Boss', 'Elder'])} ${word(g, 2)} ${f}`, biome: i === 2 ? 'desert' : undefined })) as Profile['cities'],
    hamlets: [word(g, 2), word(g, 2) + ' Well', word(g, 2) + ' Stop', 'Camp ' + word(g, 1)],
  };
}

// ---------------------------------------------------------------- systems
const cache = new Map<string, System>();
export function genSystem(id: string): System {
  const hit = cache.get(id);
  if (hit) return hit;
  const s = star(id)!, g = rng('star:' + id);
  const bodies: BodyDef[] = [{ id: 'sun', name: s.name, parent: null, au: 0, days: 1, radius: s.radius, gs: 900 * (s.radius / 2600), color: s.col, blurb: s.blurb }];
  const planets: Record<string, Profile> = {};
  const n = g.int(3, 6);
  let au = 0.3 + g.r() * 0.3;
  let belt: [number, number] | undefined;
  const inhabited = new Set<number>([g.int(0, Math.min(2, n - 1))]);
  if (g.r() < 0.5) inhabited.add(g.int(1, n - 1));
  for (let i = 0; i < n; i++) {
    au *= 1.5 + g.r() * 0.6;
    if (!belt && i === 2 && g.r() < 0.6) { belt = [au * 0.9, au * 1.25]; au *= 1.5; }
    const pid = 'w' + (i + 1), name = word(g), giant = !inhabited.has(i) && au > 2.5 && g.r() < 0.6;
    const col = g.pick(PALETTE);
    const b: BodyDef = {
      id: pid, name, parent: 'sun', au, days: Math.round(365 * Math.pow(au, 1.5)), radius: giant ? g.int(900, 1500) : g.int(220, 480), gs: giant ? g.int(150, 220) : g.int(50, 110),
      color: col, sea: !giant && g.r() < 0.6 ? hexMix(g.pick(['#2a64b8', '#3a8a7a', '#6a3a8a']), col, 0.2) : undefined, bands: giant, rings: giant && g.r() < 0.4, air: giant || g.r() < 0.7,
      blurb: giant ? 'A gas giant. Nothing lives here that you\'d want to meet.' : 'Uninhabited.',
    };
    bodies.push(b);
    if (inhabited.has(i)) { const w = makeWorld(g, id, pid, name); planets[pid] = w; b.blurb = w.blurb; }
    if (g.r() < 0.5) { const mid = pid + 'm'; bodies.push({ id: mid, name: name + ' ' + g.pick(['I', 'Minor', 'Prime']), parent: pid, au: g.int(3, 6), days: g.int(5, 30), radius: g.int(90, 150), gs: 25, color: g.pick(PALETTE), blurb: 'A moon. Rock and ice.' }); }
  }
  const sys: System = { id, name: s.name, bodies, planets, belt, ly: s.ly };
  cache.set(id, sys);
  return sys;
}
GEN.system = genSystem;

export function enterSystem(id: string): void {
  const sys = id === 'sol' ? SOL : genSystem(id);
  loadSystem(sys.bodies, sys.planets);
  SQ.system = id;
  if (!SQ.known.includes(id)) SQ.known.push(id);
}
// on boot: whatever system your ship is in (and, if you're standing in another, that one's
// species and wildlife get registered too)
if (SQ.home !== 'sol') genSystem(SQ.home);
enterSystem(SQ.system);

// ---------------------------------------------------------------- the jump
const lyBetween = (a: string, b: string) => { const la = a === 'sol' ? 0 : star(a)!.ly, lb = b === 'sol' ? 0 : star(b)!.ly; return a === 'sol' || b === 'sol' ? Math.max(la, lb) : Math.max(1.5, Math.abs(la - lb) + 2); };
export const jumpCost = (to: string) => Math.max(1, Math.ceil(lyBetween(SQ.system, to) / 4));
export function clearSpace(): { ok: boolean; why: string } {
  const my = stats(SQ.ship);
  if (!my.jump) return { ok: false, why: 'No Jump Drive fitted. Shipyards sell them (Refit).' };
  if (!SPACE.active) return { ok: false, why: 'Launch first.' };
  const d = Math.hypot(SPACE.x, SPACE.y) / AU, need = SQ.system === 'sol' ? 4 : 2.5;
  if (d < need) return { ok: false, why: `Too deep in the star's gravity: ${d.toFixed(1)} AU out, the drive needs ${need} AU.` };
  if (SPACE.g && SPACE.g.alt < 20000) return { ok: false, why: `Too close to ${SPACE.g.near.id === 'sun' ? 'the star' : 'a world'}. Get clear.` };
  return { ok: true, why: '' };
}
export function jump(g: Game, to: string): boolean {
  const c = clearSpace(), cost = jumpCost(to);
  if (!c.ok) { g.ui.toast(c.why, 'warn'); return false; }
  if (SQ.fuel < cost) { g.ui.toast(`Not enough jump fuel: ${cost} needed, ${SQ.fuel} aboard. Land to refuel, or buy it at the Haulyard.`, 'warn'); return false; }
  SQ.fuel -= cost;
  enterSystem(to);
  const sys = systemData(to), a = Math.random() * Math.PI * 2, r = (to === 'sol' ? 5 : 3) * AU;
  Object.assign(SPACE, { x: Math.cos(a) * r, y: Math.sin(a) * r, vx: 0, vy: 0, cruise: false, crafts: [], shots: [], flash: 1.2, g: null });
  SPACE.B = bodies(R.game && R.game.clock ? R.game.clock.t : SQ.minutes);
  SQ.course = Object.keys(sys.planets)[0] || null;
  saveSequel();
  g.audio.sfx('boom');
  const inhabited = Object.values(sys.planets).map((p) => p.name).join(' and ');
  g.ui.story(sys.name, `Space folds, and unfolds ${lyBetween(to === 'sol' ? SQ.known[0] : 'sol', to).toFixed(1)} light years away.\n\n${to === 'sol' ? 'Home. The Sun, the Empire, and everyone you owe money to.' : `${star(to)!.blurb}\n\n${sys.bodies.filter((b) => b.parent === 'sun').length} planets. Inhabited: ${inhabited || 'nothing'}. The flight computer has a course laid in.`}`);
  return true;
}
// fuel: a free top-up whenever you touch down on an inhabited world
const GP = R.Game.prototype, baseSetup = GP.setup;
GP.setup = function (this: Game, seed: number, save: unknown) {
  const r = baseSetup.call(this, seed, save);
  SQ.fuel = Math.max(SQ.fuel, stats(SQ.ship).fuel);
  return r;
};
// the fold: a white flash as you arrive
HOOKS.draw.push((v) => {
  const f = (SPACE as any).flash || 0;
  if (f > 0) { v.g.fillStyle = `rgba(255,240,255,${Math.min(1, f)})`; v.g.fillRect(0, 0, v.W, v.H); }
});
HOOKS.update.push((_g, dt) => { const S = SPACE as any; if (S.flash > 0) S.flash = Math.max(0, S.flash - dt * 1.6); });
HOOKS.hud.push(() => (SQ.system !== 'sol' ? `${systemData(SQ.system).name.toUpperCase()} · ${star(SQ.system)!.ly} LY FROM SOL` : null));

(window as any).BS2 = Object.assign((window as any).BS2 || {}, { enterSystem, genSystem, jump, clearSpace });
