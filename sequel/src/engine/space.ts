// Space, inside game 1's loop. While you're in orbit the world you left is paused, exactly as
// you left it; the tick flies your ship through the real solar system instead.
//   Flight: Newtonian. Every body pulls (surface gravity × radius²). With flight assist on
//   (the default) the ship damps its drift and leans against gravity; turn it off (SNEAK)
//   for true orbits. The dotted line is where you're falling.
//   Cruise (RUN): speed scales with your altitude over the nearest body, so open space flies
//   fast and planets pull you back to local speeds. The camera zooms out with your speed, so
//   worlds shrink away behind you and the orbits come into view.
//   A course (System tab) steers you in cruise and drops you out at the destination.
//   Attack fires, USE lands, boards or hails.

import { SQ, saveSequel, type Good } from './state';
import { PLANETS, BODY, landable, type PlanetId, type BodyId } from './planets';
import { travelTo } from './travel';
import { bodies, planetArt, gravity, orbitalSpeed, orbitRadius, type Body } from '../space/system';
import { npcShip, shipSprites, stats, HULLS, type Ship } from '../ship/ship';
import { enterFreighter } from './board';

export interface Craft {
  id: number; kind: 'freighter' | 'patrol' | 'hunter' | 'capital' | 'rebel'; ship: Ship; flag: 'empire' | 'solari' | 'hunter' | 'rebel';
  x: number; y: number; vx: number; vy: number; a: number;
  hull: number; maxHull: number; shield: number; maxShield: number;
  disabled: boolean; looted: boolean; dead: boolean;
  target: PlanetId; cool: number; hostile: boolean;
  cargo: { good: Good; n: number }[]; name: string;
}
interface Shot { x: number; y: number; vx: number; vy: number; life: number; from: 'me' | number; dmg: number }
interface Spark { x: number; y: number; vx: number; vy: number; life: number; col: string }

export const SPACE = {
  active: false,
  x: 0, y: 0, vx: 0, vy: 0, a: 0, shield: 0,
  cruise: false, assist: true, zoom: 1, grace: 0,
  auto: null as NavTarget | null, autoT: 0, // the autopilot's destination (nav menu or System tab)
  crafts: [] as Craft[], shots: [] as Shot[], sparks: [] as Spark[], nextId: 1, spawnT: 0, fireT: 0, thrustT: 0, hintT: 8,
  boarding: null as Craft | null,
  ticks: 0,
  B: [] as Body[], g: null as ReturnType<typeof gravity> | null,
};

// what happens when you scan a world you can't land on (aliens.ts adds to this)
export const SCAN: Record<string, (g: Game) => void> = {};
// somewhere the autopilot can fly you: a world, a station, a base. pos() is in world units and
// units per second; r is how far out from the centre to hold (a world's surface, plus a margin)
export interface NavTarget { id: string; name: string; kind: 'world' | 'body' | 'station' | 'base'; via: BodyId; r: number; pos: () => { x: number; y: number; vx: number; vy: number } }
// plug-ins for the other space modules (stations, the belt, bounty hunters, the jump drive):
// update every frame, draw into the view, claim the USE button, catch your shots
export interface View { g: CanvasRenderingContext2D; sx: (x: number) => number; sy: (y: number) => number; Z: number; W: number; H: number; mark: (x: number, y: number, col: string, label: string) => void }
export const HOOKS = {
  update: [] as ((g: Game, dt: number) => void)[],
  draw: [] as ((v: View) => void)[],
  use: [] as ((g: Game) => { label: string; fn: () => void } | null)[],
  shot: [] as ((x: number, y: number, dmg: number) => boolean)[],
  hud: [] as (() => string | null)[],
  // worlds that ask where to come down (Earth's landing zones)
  land: {} as Record<string, (g: Game, go: () => void) => void>,
  // draw yourself instead of the ship (flying on a lantern ring); true = drawn
  self: [] as ((g: CanvasRenderingContext2D, x: number, y: number, a: number, k: number) => boolean)[],
  // after you set down anywhere
  landed: [] as ((g: Game, id: PlanetId) => void)[],
  // more places for the nav menu (stations, bases)
  nav: [] as (() => NavTarget[])[],
  // actions at the top of the nav menu (build a base here...)
  navExtra: [] as ((g: Game) => { label: string; small?: string; fn: () => void } | null)[],
};
export const inSpace = () => SPACE.active;
export const shipBody = (id: BodyId) => body(id);

const NAMES = ['Imperial Hauler 7', 'Castra Venture', 'Solari Queen', 'Ore Mule', 'Marble Barge', 'Senator\'s Pride', 'Dusty Rose', 'Mule Train', 'Tithe of Castra', 'Night Orchid', 'Red Planet Express', 'Tranquility Tug'];
const GOODS: Good[] = ['rum', 'tea', 'ore', 'meds', 'vinyl', 'blasters'];
const rnd = () => Math.random();
const pick = <T>(a: T[]) => a[Math.floor(rnd() * a.length)];
const dist = (ax: number, ay: number, bx: number, by: number) => Math.hypot(bx - ax, by - ay);
const clamp = (v: number, lo: number, hi: number) => (v < lo ? lo : v > hi ? hi : v);
const angDiff = (a: number, b: number) => { let d = (b - a) % (Math.PI * 2); if (d > Math.PI) d -= Math.PI * 2; if (d < -Math.PI) d += Math.PI * 2; return d; };
const minutes = () => (R.game && R.game.clock ? R.game.clock.t : SQ.minutes);
const bs = () => (SPACE.B.length ? SPACE.B : bodies(minutes()));
const sfx = (n: string) => R.game && R.game.audio && R.game.audio.sfx(n);
const body = (id: BodyId) => bs().find((b) => b.id === id) as Body;
const inputStick = () => (R.game && R.game.input ? R.game.input.stick : { x: 0, y: 0 });

// how big a craft is to hit: half its sprite, give or take
export const craftR = (c: Craft) => Math.max(12, HULLS[c.ship.hull].w * 3);
const freighterShip = () => npcShip('trader', rnd, 'Freighter');
const patrolShip = () => npcShip('patrol', rnd, 'Patrol');

// traffic lives in the lanes around the inhabited worlds, near you
function spawnFreighter(near?: boolean): void {
  const LANES = landable();
  if (!LANES.length) return;
  const home = LANES.map((id) => body(id)).sort((a, b) => dist(a.x, a.y, SPACE.x, SPACE.y) - dist(b.x, b.y, SPACE.x, SPACE.y))[0];
  if (!near && dist(home.x, home.y, SPACE.x, SPACE.y) > 25000) return;
  const sh = freighterShip(), s = stats(sh), ang = rnd() * Math.PI * 2;
  const x = near ? SPACE.x + Math.cos(ang) * 700 : home.x + Math.cos(ang) * (home.r + 400 + rnd() * 1200), y = near ? SPACE.y + Math.sin(ang) * 700 : home.y + Math.sin(ang) * (home.r + 400 + rnd() * 1200);
  SPACE.crafts.push({
    id: SPACE.nextId++, kind: 'freighter', ship: sh, flag: rnd() < 0.65 ? 'empire' : 'solari', x, y, vx: 0, vy: 0, a: 0,
    hull: s.hull, maxHull: s.hull, shield: s.shield, maxShield: s.shield, disabled: false, looted: false, dead: false, target: pick(LANES.length > 1 ? LANES.filter((l) => l !== home.id) : LANES), cool: 0, hostile: false,
    name: pick(NAMES), cargo: [{ good: pick(GOODS), n: 4 + Math.floor(rnd() * 6) }, { good: pick(GOODS), n: 3 + Math.floor(rnd() * 5) }],
  });
}
function spawnPatrol(): void {
  const sh = patrolShip(), s = stats(sh), ang = rnd() * Math.PI * 2;
  SPACE.crafts.push({
    id: SPACE.nextId++, kind: 'patrol', ship: sh, flag: 'empire', x: SPACE.x + Math.cos(ang) * 600, y: SPACE.y + Math.sin(ang) * 600, vx: SPACE.vx, vy: SPACE.vy, a: ang + Math.PI,
    hull: s.hull, maxHull: s.hull, shield: s.shield, maxShield: s.shield, disabled: false, looted: false, dead: false, target: 'venus', cool: 1.5, hostile: true, name: 'Imperial Patrol', cargo: [],
  });
  R.game.ui.toast('IMPERIAL PATROL: "Unregistered vessel, cut your engines and prepare to be boarded."', 'bad');
  sfx('alarm');
}

// put any kind of ship near you (debug, events, capital ships on their rounds)
export function spawnCraft(kind: Craft['kind'], hostile = kind === 'patrol' || kind === 'hunter', dist0 = 500): Craft {
  const role = kind === 'freighter' ? 'trader' : kind;
  const sh = npcShip(role, rnd, kind === 'capital' ? 'Imperial Star Dreadnought' : 'Ship'), s = stats(sh), ang = rnd() * Math.PI * 2;
  const names: Record<string, string> = { freighter: pick(NAMES), patrol: 'Imperial Patrol', hunter: 'Hunter', capital: pick(['ISD Castra Invicta', 'ISD Senate\'s Fist', 'ISD Dominion']), rebel: pick(['Free Ganymede', 'Red Sparrow', 'Long Shot']) };
  const LANES = landable();
  const c: Craft = {
    id: SPACE.nextId++, kind, ship: sh, flag: kind === 'freighter' || kind === 'patrol' || kind === 'capital' ? 'empire' : kind === 'rebel' ? 'rebel' : 'hunter',
    x: SPACE.x + Math.cos(ang) * dist0, y: SPACE.y + Math.sin(ang) * dist0, vx: SPACE.vx, vy: SPACE.vy, a: ang + Math.PI,
    hull: s.hull, maxHull: s.hull, shield: s.shield, maxShield: s.shield, disabled: false, looted: false, dead: false,
    target: LANES.length ? pick(LANES) : ('earth' as PlanetId), cool: 1.5, hostile, name: names[kind],
    cargo: kind === 'freighter' ? [{ good: pick(GOODS), n: 4 + Math.floor(rnd() * 6) }] : [],
  };
  SPACE.crafts.push(c);
  return c;
}

// ---------------------------------------------------------------- entering and leaving space
export function launch(g: Game): void {
  g.save();
  SPACE.B = bodies(minutes());
  const b = body(SQ.planet) || body('sun');
  // up out of the atmosphere, already moving at orbital speed
  const out = Math.atan2(b.y, b.x), d = b.r + 140, v = orbitalSpeed(b, d);
  Object.assign(SPACE, { x: b.x + Math.cos(out) * d, y: b.y + Math.sin(out) * d, vx: -Math.sin(out) * v, vy: Math.cos(out) * v, a: out + Math.PI / 2, shots: [], sparks: [], cruise: false });
  const my = stats(SQ.ship);
  if (SQ.hull < 0 || SQ.hull > my.hull) SQ.hull = my.hull;
  SPACE.shield = my.shield;
  SPACE.crafts = SPACE.crafts.filter((c) => dist(c.x, c.y, SPACE.x, SPACE.y) < 20000);
  if (!SPACE.crafts.some((c) => c.kind === 'freighter' && !c.dead)) { for (let k = 0; k < 3; k++) spawnFreighter(); spawnFreighter(true); }
  SPACE.active = true; SQ.mode = 'space';
  saveSequel();
  sfx('boom');
  g.ui.toast(`In orbit over ${BODY[SQ.planet].name}. Push the stick to fly, let go to stop. A: WHERE TO? (the autopilot flies you there). Attack fires. RUN: cruise.`, 'good');
}
export function resumeSpace(g: Game): void {
  const s = SQ.space;
  if (!s) { launch(g); return; }
  Object.assign(SPACE, { x: s.x, y: s.y, a: s.a, vx: 0, vy: 0, cruise: false });
  SPACE.B = bodies(minutes());
  SPACE.active = true;
  if (!SPACE.crafts.length) { for (let k = 0; k < 3; k++) spawnFreighter(); spawnFreighter(true); }
}
function land(g: Game, id: PlanetId, force = false): void {
  SPACE.active = false; SPACE.cruise = false; SQ.mode = 'planet'; SQ.space = null; SQ.course = null;
  sfx('crash');
  if (force || id !== SQ.planet || SQ.home !== SQ.system) travelTo(g, id, true);
  else { const w = g.world; g.player.place(w.pad.sx - 40, w.pad.sy + 44); g.cam.x = g.player.x; g.cam.y = g.player.y; }
  const p = PLANETS[id];
  g.ui.toast(`Landed on ${p.name}. ${p.blurb}`, 'good');
  // customs: Imperial worlds scan open cargo if you're hot with the Empire
  if (!p.black && SQ.heat.empire > 10) {
    const hot = SQ.cargo.filter((l) => l.stolen && !l.hidden);
    if (hot.length) {
      const n = hot.reduce((s, l) => s + l.n, 0), fine = Math.min(g.player.cash, 150);
      SQ.cargo = SQ.cargo.filter((l) => !(l.stolen && !l.hidden));
      g.player.cash -= fine;
      setTimeout(() => g.ui.story(p.law + ' Customs', `The scanner finds ${n} crates of stolen cargo in your open bay. They take the crates and ${fine} credits for the paperwork.\n\nNext time, fit a smuggler's hold.`), 500);
    }
  }
  SQ.heat.empire = Math.max(0, SQ.heat.empire - 10);
  for (const h of HOOKS.landed) h(g, id);
  saveSequel();
  g.save();
}

// ---------------------------------------------------------------- combat helpers
export function fire(x: number, y: number, a: number, vx: number, vy: number, from: 'me' | number, dmg: number, n: number): void {
  for (let k = 0; k < n; k++) {
    const off = (k - (n - 1) / 2) * 5, px = -Math.sin(a) * off, py = Math.cos(a) * off;
    SPACE.shots.push({ x: x + Math.cos(a) * 14 + px, y: y + Math.sin(a) * 14 + py, vx: vx + Math.cos(a) * 520, vy: vy + Math.sin(a) * 520, life: 1.1, from, dmg });
  }
}
export function burst(x: number, y: number, n: number, cols: string[], vx = 0, vy = 0): void {
  for (let k = 0; k < n; k++) { const a = rnd() * 7, s = 20 + rnd() * 120; SPACE.sparks.push({ x, y, vx: vx + Math.cos(a) * s, vy: vy + Math.sin(a) * s, life: 0.4 + rnd() * 0.7, col: cols[k % cols.length] }); }
}
// the landable world you're low enough over to land on (or hail)
export const nearPlanet = () => bs().find((b) => b.id !== 'sun' && dist(SPACE.x, SPACE.y, b.x, b.y) < b.r + 220) || null;
const nearWreck = () => SPACE.crafts.find((c) => c.disabled && !c.looted && !c.dead && dist(SPACE.x, SPACE.y, c.x, c.y) < 70) || null;

export function hitCraft(g: Game, c: Craft, dmg: number): void {
  const peaceful = !c.hostile;
  if (c.shield > 0) { c.shield = Math.max(0, c.shield - dmg); burst(c.x, c.y, 3, ['#9ad8ff', '#ffffff'], c.vx, c.vy); }
  else { c.hull -= dmg; burst(c.x, c.y, 4, ['#ffd060', '#ff8030'], c.vx, c.vy); }
  sfx('thup');
  c.hostile = true;
  if (peaceful) {
    g.ui.toast(`${c.name}: "Mayday! Pirates on the ${PLANETS[c.target].name} lane!"`, 'bad');
    if (c.flag === 'empire') { SQ.heat.empire += 15; SQ.bounty += 150; } else if (c.flag === 'solari') SQ.heat.families += 15;
    g.player.rep.infamy = (g.player.rep.infamy || 0) + 2;
  }
  if (c.kind === 'freighter' && !c.disabled && c.hull < c.maxHull * 0.35) {
    c.disabled = true; c.hostile = false;
    g.ui.toast(stats(SQ.ship).tube ? `${c.name} is dead in space. Match her speed and USE to board.` : 'Freighter disabled, but you have no boarding tube.', 'good');
  }
  if (c.hull <= 0) {
    c.dead = true; sfx('boom'); burst(c.x, c.y, 40, ['#ffd060', '#ff8030', '#ffffff', '#c83a2a'], c.vx, c.vy);
    if (c.kind === 'patrol' || c.kind === 'capital') { SQ.heat.empire += 20; SQ.bounty += 600; g.ui.toast('Patrol destroyed. The Empire will remember that. (+$600 on your head)', 'bad'); g.player.rep.infamy += 5; }
    else if (c.kind === 'hunter') { const prize = 200 + Math.floor(Math.random() * 300); g.player.cash += prize; g.ui.toast(`${c.name} is scrap. You pull $${prize} from the wreck's strongbox.`, 'good'); }
    else g.ui.toast(`${c.name} breaks apart. Her cargo burns with her.`);
  }
}

// ---------------------------------------------------------------- the simulation
function update(g: Game, dt: number): void {
  SPACE.ticks++;
  const inp = g.input, my = stats(SQ.ship);
  SPACE.B = bodies(minutes());
  const G = gravity(SPACE.B, SPACE.x, SPACE.y);
  SPACE.g = G;
  const frame = G.dom; // velocities are read relative to the dominant body
  const rvx = SPACE.vx - frame.vx / 60, rvy = SPACE.vy - frame.vy / 60;
  if (inp.pressed('run')) {
    const clear = G.alt > 15; // off the ground: the drive turns and climbs by itself
    SPACE.cruise = !SPACE.cruise && clear;
    SPACE.grace = SPACE.cruise ? 3 : 0; // a few seconds to climb away before the drop-out check
    g.ui.toast(SPACE.cruise ? 'Cruise drive engaged. Speed grows with distance from the nearest world.' : !clear ? `Too low over ${BODY[G.near.id].name} for cruise. Climb out of the atmosphere.` : 'Cruise drive off.', SPACE.cruise ? 'good' : '');
    sfx(SPACE.cruise ? 'boom' : 'click');
  }
  if (inp.pressed('sneak')) { SPACE.assist = !SPACE.assist; g.ui.toast(SPACE.assist ? 'Flight assist on: the stick is where you go, letting go stops you, gravity can\'t touch you.' : 'Flight assist off: pure Newtonian. The stick is thrust; watch the dotted line: that\'s your orbit.'); }
  // the stick points the nose; a course steers for you in cruise
  let sx = inp.stick.x, sy = inp.stick.y, mag = Math.hypot(sx, sy);
  // the autopilot: cruise out to the destination, drop in, and hold station over it.
  // Touch the stick to take over.
  const auto = SPACE.auto;
  let autoVel: { x: number; y: number } | null = null;
  if (auto && mag > 0.35) { SPACE.auto = null; g.ui.toast('Autopilot off. You have the stick.'); }
  else if (auto) {
    const t = auto.pos(), dx = t.x - SPACE.x, dy = t.y - SPACE.y, d = Math.hypot(dx, dy) || 1;
    const hold = auto.r + (auto.kind === 'station' || auto.kind === 'base' ? 30 : 70);
    SPACE.autoT -= dt;
    if (d > hold + 4000 + auto.r * 1.5) {
      SQ.course = auto.via;
      if (!SPACE.cruise && G.alt > 15 && SPACE.autoT <= 0) { SPACE.cruise = true; SPACE.grace = 3; }
    } else {
      if (SPACE.cruise) { SPACE.cruise = false; SPACE.autoT = 3; }
      // the hold point: straight out from the target toward where you are
      const hx = t.x - (dx / d) * hold, hy = t.y - (dy / d) * hold, hd = Math.hypot(hx - SPACE.x, hy - SPACE.y);
      // no faster than the drive can stop from
      const brake = Math.max(220, my.thrust * 3) * 0.6, sp = Math.min(900, Math.sqrt(2 * brake * hd), hd * 2.5);
      autoVel = { x: t.vx + ((hx - SPACE.x) / (hd || 1)) * sp, y: t.vy + ((hy - SPACE.y) / (hd || 1)) * sp };
      if (hd < 30 && Math.hypot(SPACE.vx - t.vx, SPACE.vy - t.vy) < 40) {
        SPACE.auto = null; SQ.course = null;
        g.ui.toast(`Holding over ${auto.name}. ${auto.kind === 'world' ? 'A to land.' : auto.kind === 'station' || auto.kind === 'base' ? 'A to dock.' : 'A to scan.'}`, 'good');
        sfx('click');
      }
    }
  }
  const course = SQ.course ? body(SQ.course) : null;
  if (course && SPACE.cruise && mag < 0.2) {
    // the flight computer: head for the course, but climb out of any world you're low over
    // first instead of ploughing through it
    const d = Math.hypot(course.x - SPACE.x, course.y - SPACE.y) || 1;
    let vx = (course.x - SPACE.x) / d, vy = (course.y - SPACE.y) / d;
    const n = G.near, nd = Math.hypot(SPACE.x - n.x, SPACE.y - n.y) || 1, ox = (SPACE.x - n.x) / nd, oy = (SPACE.y - n.y) / nd;
    if (n.id !== course.id) { const up = Math.max(0, 2.5 - G.alt / n.r) * 1.6; vx += ox * up; vy += oy * up; }
    // and steer wide of the star: never through the corona
    const sun = body('sun');
    if (sun && course.id !== 'sun') {
      const px = sun.x - SPACE.x, py = sun.y - SPACE.y, along = px * vx + py * vy;
      if (along > 0 && along < d) {
        const cx = SPACE.x + vx * along - sun.x, cy = SPACE.y + vy * along - sun.y, miss = Math.hypot(cx, cy) || 1, safe = sun.r * 6;
        if (miss < safe) { const k = (1 - miss / safe) * 2; vx += (cx / miss) * k; vy += (cy / miss) * k; }
      }
    }
    sx = vx; sy = vy; mag = 1;
  }
  if (autoVel && !SPACE.cruise) { sx = autoVel.x - SPACE.vx; sy = autoVel.y - SPACE.vy; const m = Math.hypot(sx, sy); mag = m > 8 ? 1 : 0; if (!mag) { sx = Math.cos(SPACE.a); sy = Math.sin(SPACE.a); } }
  if (mag > 0.2) {
    const want = Math.atan2(sy, sx), d = angDiff(SPACE.a, want);
    const tr = my.turn * dt * (SPACE.cruise ? 0.6 : SPACE.assist ? 2.2 : 1);
    SPACE.a += clamp(d, -tr, tr);
  }
  if (SPACE.cruise) {
    // cruise: speed proportional to altitude; gravity is left behind in the drive's bubble
    const vmax = clamp(G.alt * 0.2, 300, 60000);
    // low over a world with the nose pointing down: turn first, then go
    const on = G.near, od = Math.hypot(SPACE.x - on.x, SPACE.y - on.y) || 1;
    const up = (Math.cos(SPACE.a) * (SPACE.x - on.x) + Math.sin(SPACE.a) * (SPACE.y - on.y)) / od;
    const diving = G.alt < on.r && up < -0.2 && (!course || course.id !== on.id);
    const tv = mag > 0.2 && !diving ? vmax * Math.min(1, mag) : 0;
    const cur = Math.hypot(SPACE.vx, SPACE.vy), nv = cur + clamp(tv - cur, -vmax * 2 * dt - 400 * dt, vmax * 0.9 * dt + 200 * dt);
    SPACE.vx = Math.cos(SPACE.a) * nv; SPACE.vy = Math.sin(SPACE.a) * nv;
    // drop out near a world (or at the course's end)
    const dest = course && dist(SPACE.x, SPACE.y, course.x, course.y) < course.r * 2.2;
    // falling toward a world's surface drops you out (climbing away from one doesn't)
    const toward = Math.cos(SPACE.a) * (G.near.x - SPACE.x) + Math.sin(SPACE.a) * (G.near.y - SPACE.y) > 0;
    SPACE.grace -= dt;
    if ((G.alt < G.near.r * 0.35 && toward && (SPACE.grace <= 0 || G.alt < 30)) || dest) {
      SPACE.cruise = false;
      const v = orbitalSpeed(G.near, dist(SPACE.x, SPACE.y, G.near.x, G.near.y)), ang = Math.atan2(SPACE.y - G.near.y, SPACE.x - G.near.x);
      SPACE.vx = -Math.sin(ang) * v * 0.9 + G.near.vx / 60; SPACE.vy = Math.cos(ang) * v * 0.9 + G.near.vy / 60;
      if (dest) SQ.course = null;
      g.ui.toast(`Dropped out of cruise over ${BODY[G.near.id].name}.${PLANETS[G.near.id as PlanetId] ? ' Get low and USE to land.' : ''}`, 'good');
      sfx('boom');
    }
  } else if (SPACE.assist) {
    // flight assist (the default): arcade flying. The drive cancels gravity outright; the stick
    // is the direction and speed you want to go, and letting go brakes you to a stop against
    // whatever world you're near. The autopilot flies the same way.
    const top = (my.burner ? 1000 : 700) * (0.6 + Math.min(1, my.thrust / 150) * 0.4);
    const accel = Math.max(220, my.thrust * 3);
    let tvx: number, tvy: number;
    if (autoVel) { tvx = autoVel.x; tvy = autoVel.y; }
    else if (mag > 0.2) { const k = Math.min(1, mag) * top / (mag || 1); tvx = frame.vx / 60 + sx * k; tvy = frame.vy / 60 + sy * k; }
    else { tvx = frame.vx / 60; tvy = frame.vy / 60; }
    const dvx = tvx - SPACE.vx, dvy = tvy - SPACE.vy, dm = Math.hypot(dvx, dvy), step = Math.min(dm, accel * dt * (mag > 0.2 || autoVel ? 1 : 1.6));
    if (dm > 0.001) { SPACE.vx += (dvx / dm) * step; SPACE.vy += (dvy / dm) * step; }
  } else {
    // Newtonian (SNEAK toggles it): thrust along the nose plus every body's gravity
    if (mag > 0.2) {
      const d = angDiff(SPACE.a, Math.atan2(sy, sx));
      const push = my.thrust * Math.min(1, mag) * (Math.abs(d) < 1.2 ? 1 : 0.3);
      SPACE.vx += Math.cos(SPACE.a) * push * dt; SPACE.vy += Math.sin(SPACE.a) * push * dt;
    }
    SPACE.vx += G.ax * dt; SPACE.vy += G.ay * dt;
    const sp = Math.hypot(rvx, rvy), cap = my.burner ? 1250 : 900;
    if (sp > cap) { SPACE.vx = frame.vx / 60 + (rvx * cap) / sp; SPACE.vy = frame.vy / 60 + (rvy * cap) / sp; }
  }
  if ((mag > 0.2 || SPACE.cruise) && !SQ.ringFly) {
    SPACE.thrustT -= dt;
    if (SPACE.thrustT <= 0) { SPACE.thrustT = 0.05; SPACE.sparks.push({ x: SPACE.x - Math.cos(SPACE.a) * 16, y: SPACE.y - Math.sin(SPACE.a) * 16, vx: SPACE.vx - Math.cos(SPACE.a) * 60 + (rnd() - 0.5) * 20, vy: SPACE.vy - Math.sin(SPACE.a) * 60 + (rnd() - 0.5) * 20, life: 0.35, col: SPACE.cruise ? (rnd() < 0.5 ? '#a8e8ff' : '#ffffff') : rnd() < 0.5 ? '#ffd060' : '#ff8030' }); }
  }
  SPACE.x += SPACE.vx * dt; SPACE.y += SPACE.vy * dt;
  // hitting a surface: landable worlds let you set down slowly; anything else hurts
  const surf = G.near, dd = dist(SPACE.x, SPACE.y, surf.x, surf.y);
  if (dd < surf.r) {
    // speeds against the world you hit (not whatever pulls hardest out here)
    const svx = SPACE.vx - surf.vx / 60, svy = SPACE.vy - surf.vy / 60;
    const ang = Math.atan2(SPACE.y - surf.y, SPACE.x - surf.x), sp = Math.hypot(svx, svy);
    SPACE.x = surf.x + Math.cos(ang) * (surf.r + 2); SPACE.y = surf.y + Math.sin(ang) * (surf.r + 2);
    if (surf.id === 'sun') SQ.hull -= 60 * dt;
    else if (sp > 120) { SQ.hull -= sp * 0.15; burst(SPACE.x, SPACE.y, 14, ['#ffd060', '#8a6a4a']); sfx('crash'); g.ui.toast(`You hit ${BODY[surf.id].name} at ${Math.round(sp)}. Land slower.`, 'bad'); }
    const nx = Math.cos(ang), ny = Math.sin(ang), vn = svx * nx + svy * ny;
    if (vn < 0) { SPACE.vx -= vn * nx * 1.3; SPACE.vy -= vn * ny * 1.3; }
    SPACE.cruise = false;
  }
  if (dist(SPACE.x, SPACE.y, 0, 0) < BODY.sun.radius * 1.6) SQ.hull -= 12 * dt; // the corona
  SPACE.shield = Math.min(my.shield, SPACE.shield + my.shield * 0.08 * dt);
  SPACE.fireT -= dt;
  if (inp.held('attack') && SPACE.fireT <= 0 && my.guns > 0 && !SPACE.cruise) { SPACE.fireT = 0.22; fire(SPACE.x, SPACE.y, SPACE.a, SPACE.vx, SPACE.vy, 'me', my.dmg, my.guns); sfx('smg'); }
  if (inp.pressed('use')) {
    for (const h of HOOKS.use) { const u = h(g); if (u) { u.fn(); return; } }
    const w = nearWreck(), p = nearPlanet();
    if (!w && !p) { openNav(g); return; }
    if (w) { if (!my.tube) g.ui.toast('You need a Boarding Tube module to board.', 'bad'); else { SPACE.active = false; SPACE.boarding = w; enterFreighter(g, w); return; } }
    else if (p) {
      const rel = Math.hypot(SPACE.vx - p.vx / 60, SPACE.vy - p.vy / 60);
      if (!(p.id in PLANETS)) { if (SCAN[p.id]) SCAN[p.id](g); else g.ui.story(BODY[p.id].name, `${BODY[p.id].blurb}\n\nThere's nowhere to set down here yet.`); }
      else if (rel > 400) g.ui.toast(`Too fast to land (${Math.round(rel)}). Let go of the stick to brake.`, 'bad');
      else { const id = p.id as PlanetId; if (HOOKS.land[id]) HOOKS.land[id](g, () => land(g, id, true)); else land(g, id); return; }
    }
  }
  // the camera: zoom out with speed and with distance from the nearest world
  const speed = Math.hypot(rvx, rvy);
  const wantZoom = clamp(1 / (1 + speed / 700 + Math.max(0, G.alt - 2000) / 9000), 1 / 600, 1);
  SPACE.zoom += (wantZoom - SPACE.zoom) * Math.min(1, dt * 2.5);

  // traffic in the lanes
  SPACE.spawnT -= dt;
  if (SPACE.spawnT <= 0) {
    SPACE.spawnT = 18;
    if (SPACE.crafts.filter((c) => c.kind === 'freighter' && !c.dead && !c.looted).length < 4) spawnFreighter();
    if (SQ.heat.empire >= 20 && !SPACE.crafts.some((c) => c.kind === 'patrol' && !c.dead) && !SPACE.cruise) spawnPatrol();
  }
  for (const c of SPACE.crafts) {
    if (c.dead) continue;
    const cs = stats(c.ship), cg = gravity(SPACE.B, c.x, c.y);
    c.shield = Math.min(c.maxShield, c.shield + c.maxShield * 0.03 * dt);
    if (c.disabled) { c.vx += cg.ax * dt * 0.2; c.vy += cg.ay * dt * 0.2; c.a += dt * 0.2; }
    else {
      let tx: number, ty: number;
      // patrols and hunters come for you; capital ships and rebels only once you've started it.
      // A cloaking field loses them past close range.
      const seen = !my.cloak || dist(c.x, c.y, SPACE.x, SPACE.y) < 240;
      const chaser = seen && (c.kind === 'patrol' || c.kind === 'hunter' || (c.hostile && (c.kind === 'capital' || c.kind === 'rebel')));
      if (chaser || (seen && c.hostile && dist(c.x, c.y, SPACE.x, SPACE.y) < 500)) { tx = SPACE.x; ty = SPACE.y; }
      else if (c.kind === 'capital' && body(c.target)) { const t = body(c.target), oa = Math.atan2(c.y - t.y, c.x - t.x) + 0.25; tx = t.x + Math.cos(oa) * (t.r + 900); ty = t.y + Math.sin(oa) * (t.r + 900); }
      else { const t = body(c.target); tx = t.x; ty = t.y; }
      const want = Math.atan2(ty - c.y, tx - c.x), d = angDiff(c.a, want);
      c.a += clamp(d, -cs.turn * dt * 0.8, cs.turn * dt * 0.8);
      // traders cruise the lane; patrols keep pace with you
      const top = c.kind === 'capital' ? 120 : chaser ? Math.max(c.kind === 'hunter' ? 380 : 320, Math.hypot(SPACE.vx, SPACE.vy) * 1.1) : 160;
      const tvx = Math.cos(c.a) * top, tvy = Math.sin(c.a) * top, k = Math.min(1, dt * 1.2);
      if (!(chaser && dist(c.x, c.y, SPACE.x, SPACE.y) < 130)) { c.vx += (tvx - c.vx) * k; c.vy += (tvy - c.vy) * k; }
      else { c.vx += (SPACE.vx - c.vx) * k; c.vy += (SPACE.vy - c.vy) * k; }
      c.cool -= dt;
      if (c.hostile && seen && c.cool <= 0 && dist(c.x, c.y, SPACE.x, SPACE.y) < (c.kind === 'capital' ? 520 : 360) && Math.abs(d) < (c.kind === 'capital' ? 1.2 : 0.4)) {
        c.cool = chaser ? 0.5 : 1.3;
        fire(c.x, c.y, c.a, c.vx, c.vy, c.id, chaser ? 8 : 5, clamp(cs.guns, 1, 4));
      }
    }
    c.x += c.vx * dt; c.y += c.vy * dt;
  }
  SPACE.crafts = SPACE.crafts.filter((c) => dist(c.x, c.y, SPACE.x, SPACE.y) < (c.dead || c.looted ? 3000 : 30000));
  for (const s of SPACE.shots) {
    s.x += s.vx * dt; s.y += s.vy * dt; s.life -= dt;
    if (s.from === 'me') {
      for (const c of SPACE.crafts) if (!c.dead && dist(s.x, s.y, c.x, c.y) < craftR(c)) { hitCraft(g, c, s.dmg); s.life = 0; break; }
      if (s.life > 0) for (const h of HOOKS.shot) if (h(s.x, s.y, s.dmg)) { s.life = 0; break; }
    }
    else if (dist(s.x, s.y, SPACE.x, SPACE.y) < 14) {
      s.life = 0; sfx('thup');
      if (SPACE.shield > 0) { SPACE.shield = Math.max(0, SPACE.shield - s.dmg); burst(SPACE.x, SPACE.y, 3, ['#9ad8ff', '#fff'], SPACE.vx, SPACE.vy); }
      else { SQ.hull -= s.dmg; burst(SPACE.x, SPACE.y, 4, ['#ffd060', '#ff8030'], SPACE.vx, SPACE.vy); if (g.ui.hurtFlash) g.ui.hurtFlash(s.dmg); }
    }
  }
  SPACE.shots = SPACE.shots.filter((s) => s.life > 0);
  for (const p of SPACE.sparks) { p.x += p.vx * dt; p.y += p.vy * dt; p.life -= dt; }
  SPACE.sparks = SPACE.sparks.filter((p) => p.life > 0);
  if (SQ.hull <= 0) {
    sfx('boom');
    SQ.cargo = [];
    const cut = Math.round(g.player.cash * 0.3);
    g.player.cash -= cut; SQ.hull = my.hull; SQ.heat.empire = 0;
    land(g, SQ.planet in PLANETS ? SQ.planet : Object.keys(PLANETS)[0]);
    g.ui.story('Salvage Crew', `We pulled you out of the wreck and towed you home. The cargo's gone and the tow was ${cut} credits.`);
  }
  SPACE.hintT -= dt;
  if (SPACE.hintT <= 0) {
    SPACE.hintT = 55;
    const f = SPACE.crafts.find((c) => c.kind === 'freighter' && !c.dead && !c.disabled);
    if (f && !SQ.cargo.some((l) => l.stolen) && !SPACE.cruise) g.ui.toast(`Scanner: ${f.name} (${f.flag === 'empire' ? 'Imperial' : 'Solari'} flag) bound for ${PLANETS[f.target].name}. Shoot out her engines, then board.`);
  }
  for (const h of HOOKS.update) h(g, dt);
  SQ.space = { x: SPACE.x, y: SPACE.y, a: SPACE.a };
}

// ---------------------------------------------------------------- the nav menu and autopilot
export function navTargets(): NavTarget[] {
  const out: NavTarget[] = [];
  for (const b of bs()) {
    if (b.id === 'sun') continue;
    const id = b.id;
    out.push({ id, name: BODY[id].name, kind: id in PLANETS ? 'world' : 'body', via: id, r: b.r, pos: () => { const q = body(id); return { x: q.x, y: q.y, vx: q.vx / 60, vy: q.vy / 60 }; } });
  }
  for (const h of HOOKS.nav) out.push(...h());
  return out;
}
export function autopilot(g: Game, t: NavTarget): void {
  SPACE.auto = t; SPACE.autoT = 0; SQ.course = t.via; saveSequel();
  const p = t.pos(), d = Math.hypot(p.x - SPACE.x, p.y - SPACE.y);
  g.ui.toast(`Autopilot: ${t.name}, ${d > 30000 ? (d / 60000).toFixed(2) + ' AU' : Math.round(d / 10) + ' km'}. Touch the stick to take over.`, 'good');
  sfx('boom');
}
export function openNav(g: Game): void {
  const list = navTargets().map((t) => ({ t, d: Math.hypot(t.pos().x - SPACE.x, t.pos().y - SPACE.y) })).sort((a, b) => a.d - b.d);
  const fmtD = (d: number) => (d > 30000 ? (d / 60000).toFixed(2) + ' AU' : Math.round(d / 10) + ' km');
  const kind = { world: 'land', body: 'scan', station: 'dock', base: 'your base' };
  const extra = HOOKS.navExtra.map((h) => h(g)).filter(Boolean) as { label: string; small?: string; fn: () => void }[];
  g.ui.choice('Where to?', [...extra, ...list.slice(0, 14).map(({ t, d }) => ({ label: `${t.name} · ${fmtD(d)}`, small: `${kind[t.kind]}${t.kind === 'world' && PLANETS[t.id] && PLANETS[t.id].frontier ? ' · frontier' : ''}`, fn: () => autopilot(g, t) }))]);
}

// ---------------------------------------------------------------- drawing
// the world is drawn at 2× (the GBA scale) times the flight zoom; far out, worlds shrink to
// discs and orbits, and your ship becomes a marker
function draw(g: CanvasRenderingContext2D, BW: number, BH: number): void {
  const Z = SPACE.zoom, W = BW / 2, H = BH / 2;
  g.setTransform(2, 0, 0, 2, 0, 0);
  g.imageSmoothingEnabled = false;
  const A = R.art;
  // background: deep space with an 80s synth glow toward the Sun
  g.fillStyle = '#07051a'; g.fillRect(0, 0, W, H);
  const sunDir = Math.atan2(-SPACE.y, -SPACE.x);
  const glow = g.createRadialGradient(W / 2 + Math.cos(sunDir) * W, H / 2 + Math.sin(sunDir) * H, 10, W / 2, H / 2, W * 1.2);
  glow.addColorStop(0, 'rgba(255,90,160,0.28)'); glow.addColorStop(0.5, 'rgba(90,40,140,0.15)'); glow.addColorStop(1, 'rgba(7,5,26,0)');
  g.fillStyle = glow; g.fillRect(0, 0, W, H);
  for (const [layer, size, cell] of [[0.02, 1, 40], [0.06, 1, 60], [0.15, 2, 90]] as [number, number, number][]) {
    const ox = SPACE.x * layer * Z * 4, oy = SPACE.y * layer * Z * 4;
    for (let gy = Math.floor(oy / cell); gy <= Math.floor((oy + H) / cell); gy++)
      for (let gx = Math.floor(ox / cell); gx <= Math.floor((ox + W) / cell); gx++) {
        const h = R.hash2(gx, gy, size * 13 + cell);
        if (h > 0.55) continue;
        g.fillStyle = h < 0.08 ? '#ffe8a0' : h < 0.16 ? '#a8c8ff' : h < 0.2 ? '#ff9ad8' : '#e8e8f8';
        g.fillRect(Math.round(gx * cell + R.hash2(gx, gy, 1) * cell - ox), Math.round(gy * cell + R.hash2(gx, gy, 2) * cell - oy), size, size);
      }
  }
  // speed lines in cruise
  if (SPACE.cruise) {
    const a = Math.atan2(SPACE.vy, SPACE.vx);
    g.strokeStyle = 'rgba(168,232,255,0.35)';
    for (let k = 0; k < 18; k++) { const x = R.hash2(k, 11, (performance.now() / 90) | 0) * W, y = R.hash2(k, 12, (performance.now() / 90) | 0) * H; g.beginPath(); g.moveTo(x, y); g.lineTo(x - Math.cos(a) * 18, y - Math.sin(a) * 18); g.stroke(); }
  }
  const sx = (x: number) => (x - SPACE.x) * Z + W / 2, sy = (y: number) => (y - SPACE.y) * Z + H / 2;
  // orbits, once you're far enough out to see them
  if (Z < 0.2) {
    g.strokeStyle = `rgba(160,150,230,${clamp(0.4 - Z * 2, 0.1, 0.35)})`; g.setLineDash([2, 3]);
    for (const b of SPACE.B) {
      const d = BODY[b.id]; if (!d.parent) continue;
      const p = SPACE.B.find((x) => x.id === d.parent) as Body, r = orbitRadius(b.id) * Z;
      if (r < 3 || r > W * 40) continue;
      g.beginPath(); g.arc(sx(p.x), sy(p.y), r, 0, 7); g.stroke();
    }
    g.setLineDash([]);
  }
  // the bodies
  for (const b of SPACE.B) {
    const r = Math.max(b.id === 'sun' ? 3 : 1.5, b.r * Z), x = sx(b.x), y = sy(b.y);
    if (x + r * 2 < 0 || x - r * 2 > W || y + r * 2 < 0 || y - r * 2 > H) continue;
    if (b.id === 'sun') { const sg = g.createRadialGradient(x, y, r * 0.8, x, y, r * 3); sg.addColorStop(0, 'rgba(255,200,120,0.55)'); sg.addColorStop(1, 'rgba(255,90,160,0)'); g.fillStyle = sg; g.fillRect(x - r * 3, y - r * 3, r * 6, r * 6); }
    if (r < 3) { g.fillStyle = BODY[b.id].color; g.fillRect(Math.round(x - r), Math.round(y - r), Math.ceil(r * 2), Math.ceil(r * 2)); }
    else {
      const art = planetArt(b.id), k = r / 96;
      g.drawImage(art, Math.round(x - (art.width / 2) * k), Math.round(y - (art.height / 2) * k), Math.round(art.width * k), Math.round(art.height * k));
    }
    if (Z < 0.25 && b.id !== 'sun') A.ptext(g, BODY[b.id].name.toUpperCase(), Math.round(x), Math.round(y + r + 3), { align: 'center', scale: 1, color: b.id in PLANETS ? '#ffe070' : '#b8b0d8', shadow: '#07051a' });
  }
  // the trajectory: where you're falling (no thrust), a few seconds ahead
  if (!SPACE.cruise) {
    let px = SPACE.x, py = SPACE.y, vx = SPACE.vx, vy = SPACE.vy;
    g.fillStyle = 'rgba(104,240,160,0.7)';
    for (let k = 0; k < 160; k++) {
      const G = gravity(SPACE.B, px, py);
      vx += G.ax * 0.1; vy += G.ay * 0.1; px += vx * 0.1; py += vy * 0.1;
      if (Math.hypot(px - G.near.x, py - G.near.y) < G.near.r) { g.fillStyle = '#ff5a5a'; g.fillRect(Math.round(sx(px)) - 1, Math.round(sy(py)) - 1, 3, 3); break; }
      if (k % 4 === 0) g.fillRect(Math.round(sx(px)), Math.round(sy(py)), 1, 1);
    }
  }
  const view: View = { g, sx, sy, Z, W, H, mark: () => {} };
  // craft, shots, sparks (scaled with the world, but never smaller than a marker)
  const frameOf = (a: number) => ((Math.round((a / (Math.PI * 2)) * 32) % 32) + 32) % 32;
  // ships are always drawn: never smaller than half size, however far the camera pulls out
  const shipK = Math.max(0.5, Math.min(1, Z));
  const sprite = (spr: HTMLCanvasElement, x: number, y: number) => {
    const k = shipK;
    g.drawImage(spr, Math.round(x - (spr.width * k) / 2), Math.round(y - (spr.height * k) / 2), Math.round(spr.width * k), Math.round(spr.height * k));
    return true;
  };
  for (const c of SPACE.crafts) {
    if (c.dead) continue;
    const x = sx(c.x), y = sy(c.y);
    if (x < -160 || x > W + 160 || y < -160 || y > H + 160) continue;
    const spr = shipSprites(c.ship)[frameOf(c.a)];
    if (!sprite(spr, x, y)) { g.fillStyle = c.kind === 'patrol' ? '#ff5a5a' : c.disabled ? '#68f0a0' : '#e8e0c8'; g.fillRect(Math.round(x) - 1, Math.round(y) - 1, 3, 3); continue; }
    if (c.shield > 0 && c.hostile) { g.strokeStyle = 'rgba(150,210,255,0.5)'; g.beginPath(); g.arc(x, y, (spr.width / 2) * shipK, 0, 7); g.stroke(); }
    if (c.kind === 'hunter' && c.hull < c.maxHull) { g.fillStyle = '#ff5a5a'; g.fillRect(x - 1, y - (spr.height / 2) * shipK - 6, 3, 3); }
    if (c.disabled && !c.looted && Math.floor(performance.now() / 300) % 2) { g.fillStyle = '#68f0a0'; g.fillRect(x - 1, y - (spr.height / 2) * shipK - 6, 3, 3); }
    if (c.hostile || c.disabled) { g.fillStyle = '#1c1828'; g.fillRect(x - 14, y + (spr.height / 2) * shipK + 2, 28, 3); g.fillStyle = c.disabled ? '#e8b020' : '#e84848'; g.fillRect(x - 14, y + (spr.height / 2) * shipK + 2, 28 * Math.max(0, c.hull / c.maxHull), 3); }
  }
  for (const s of SPACE.shots) { g.fillStyle = s.from === 'me' ? '#ff5ad0' : '#78ff98'; const a = Math.atan2(s.vy, s.vx); for (let k = 0; k < 5; k++) g.fillRect(Math.round(sx(s.x - Math.cos(a) * k / Z)), Math.round(sy(s.y - Math.sin(a) * k / Z)), 2, 2); }
  for (const p of SPACE.sparks) { g.fillStyle = p.col; g.fillRect(Math.round(sx(p.x)), Math.round(sy(p.y)), p.life > 0.3 ? 2 : 1, p.life > 0.3 ? 2 : 1); }
  const my = stats(SQ.ship), me = shipSprites(SQ.ship)[frameOf(SPACE.a)];
  const selfDrawn = HOOKS.self.some((h) => h(g, W / 2, H / 2, SPACE.a, shipK));
  if (!selfDrawn && (SPACE.cruise || Math.hypot(inputStick().x, inputStick().y) > 0.2)) {
    const bx = W / 2 - Math.cos(SPACE.a) * (me.width * shipK * 0.42), by = H / 2 - Math.sin(SPACE.a) * (me.width * shipK * 0.42), f = 0.7 + Math.random() * 0.3;
    const glow = g.createRadialGradient(bx, by, 0, bx, by, 10 * shipK * f);
    glow.addColorStop(0, SPACE.cruise ? 'rgba(200,245,255,0.9)' : 'rgba(255,230,140,0.9)'); glow.addColorStop(1, 'rgba(255,120,40,0)');
    g.fillStyle = glow; g.fillRect(bx - 12, by - 12, 24, 24);
  }
  if (selfDrawn) { /* drawn by a hook */ }
  else if (!sprite(me, W / 2, H / 2)) {
    // far out: your ship is an arrowhead marker
    const a = SPACE.a; g.fillStyle = '#ff9a3a'; g.beginPath(); g.moveTo(W / 2 + Math.cos(a) * 6, H / 2 + Math.sin(a) * 6); g.lineTo(W / 2 + Math.cos(a + 2.5) * 4, H / 2 + Math.sin(a + 2.5) * 4); g.lineTo(W / 2 + Math.cos(a - 2.5) * 4, H / 2 + Math.sin(a - 2.5) * 4); g.fill();
  } else if (SPACE.shield > 1) { g.strokeStyle = `rgba(150,210,255,${0.2 + 0.4 * (SPACE.shield / Math.max(1, my.shield))})`; g.beginPath(); g.arc(W / 2, H / 2, (me.width / 2) * shipK + 1, 0, 7); g.stroke(); }
  // edge markers: inhabited worlds, the course, targets
  const placed: { x: number; y: number }[] = [];
  const mark = (x: number, y: number, col: string, label: string) => {
    const dx = (x - SPACE.x) * Z, dy = (y - SPACE.y) * Z;
    if (Math.abs(dx) < W / 2 - 8 && Math.abs(dy) < H / 2 - 8) return;
    const top = 30 + 10 * HOOKS.hud.length + 14;
    const a = Math.atan2(dy, dx), k = Math.min((W / 2 - 14) / Math.abs(Math.cos(a) || 1e-3), (Math.sin(a) < 0 ? H / 2 - top : H / 2 - 30) / Math.abs(Math.sin(a) || 1e-3));
    const mx = W / 2 + Math.cos(a) * k;
    let my2 = H / 2 + Math.sin(a) * k;
    // stack markers that land on top of each other (a planet and its moon)
    // (the direction is fixed up front: flipping it at the midline could bounce forever)
    const step = my2 > H / 2 ? -11 : 11;
    for (let n = 0; n < 12 && placed.some((p) => Math.abs(p.x - mx) < 60 && Math.abs(p.y - my2) < 10); n++) my2 += step;
    placed.push({ x: mx, y: my2 });
    g.fillStyle = col; g.beginPath(); g.moveTo(mx + Math.cos(a) * 6, my2 + Math.sin(a) * 6); g.lineTo(mx + Math.cos(a + 2.4) * 5, my2 + Math.sin(a + 2.4) * 5); g.lineTo(mx + Math.cos(a - 2.4) * 5, my2 + Math.sin(a - 2.4) * 5); g.fill();
    A.ptext(g, label, clamp(mx - Math.cos(a) * 18, 26, W - 26), clamp(my2 - Math.sin(a) * 12 - 2, 6, H - 12), { align: 'center', scale: 1, color: col, shadow: '#07051a' });
  };
  view.mark = mark;
  for (const h of HOOKS.draw) h(view);
  const fmt = (d: number) => (d > 30000 ? (d / 60000).toFixed(2) + ' AU' : Math.round(d / 10) + ' KM');
  // world markers: where you're headed, plus the three nearest places to land (not the lot:
  // a screen full of arrows is no help to anyone)
  const nearest = SPACE.B.filter((b) => b.id in PLANETS && b.id !== SQ.course).sort((a, b) => dist(SPACE.x, SPACE.y, a.x, a.y) - dist(SPACE.x, SPACE.y, b.x, b.y)).slice(0, 3);
  const crs = SQ.course ? SPACE.B.find((b) => b.id === SQ.course) : null;
  for (const b of crs ? [crs, ...nearest] : nearest) mark(b.x, b.y, b === crs ? '#ff9a3a' : '#ffe070', (b === crs ? '> ' : '') + BODY[b.id].name.toUpperCase() + ' ' + fmt(dist(SPACE.x, SPACE.y, b.x, b.y) - b.r));
  for (const c of SPACE.crafts) if (!c.dead && (c.kind !== 'freighter' || (c.disabled && !c.looted) || dist(c.x, c.y, SPACE.x, SPACE.y) < 1400)) mark(c.x, c.y, c.kind === 'rebel' ? '#ff9a3a' : c.kind !== 'freighter' ? '#ff5a5a' : c.disabled ? '#68f0a0' : '#e8e0c8', c.kind === 'patrol' ? 'PATROL' : c.kind === 'hunter' ? 'HUNTER' : c.kind === 'capital' ? c.name.toUpperCase() : c.kind === 'rebel' ? 'REBEL' : c.disabled ? 'BOARD' : 'FREIGHT');
  // the flight readout, top centre: where you are, how high, how fast, and the orbit you'd need
  const G = SPACE.g;
  if (G) {
    const rel = Math.hypot(SPACE.vx - G.dom.vx / 60, SPACE.vy - G.dom.vy / 60), d = dist(SPACE.x, SPACE.y, G.dom.x, G.dom.y);
    const mode = SPACE.cruise ? 'CRUISE' : SPACE.assist ? 'ASSIST' : 'NEWTONIAN';
    A.ptext(g, `${mode} · ${BODY[G.dom.id].name.toUpperCase()} · ALT ${fmt(Math.max(0, d - G.dom.r))} · ${Math.round(rel)} U/S${SPACE.cruise || d - G.dom.r > 5000 ? '' : ' · ORBIT ' + Math.round(orbitalSpeed(G.dom, d))}`, W / 2, 30, { align: 'center', scale: 1, color: SPACE.cruise ? '#a8e8ff' : '#f0ecf8', shadow: '#07051a' });
  }
  let hy = 42;
  for (const h of HOOKS.hud) { const t = h(); if (t) { A.ptext(g, t, W / 2, hy, { align: 'center', scale: 1, color: '#ffb0d8', shadow: '#07051a' }); hy += 10; } }
  const bar = (y: number, v: number, col: string, label: string) => { g.fillStyle = 'rgba(12,10,30,0.7)'; g.fillRect(6, y, 62, 7); g.fillStyle = col; g.fillRect(7, y + 1, 60 * clamp(v, 0, 1), 5); A.ptext(g, label, 72, y, { scale: 1, color: '#f0ecf8' }); };
  bar(H - 22, SQ.hull / my.hull, '#ff5a8a', 'HULL');
  bar(H - 13, my.shield ? SPACE.shield / my.shield : 0, '#5ad0ff', 'SHIELD');
  const p = nearPlanet(), w = nearWreck();
  if (!w && !p) A.ptext(g, SPACE.auto ? `AUTOPILOT: ${SPACE.auto.name.toUpperCase()} · STICK TAKES OVER` : 'USE: WHERE TO?', W / 2, H - 34, { align: 'center', scale: 1, color: SPACE.auto ? '#ff9a3a' : '#68f0a0', shadow: '#07051a' });
  if (w || p) A.ptext(g, w ? 'USE: BOARD ' + w.name.toUpperCase() : (p!.id in PLANETS ? 'USE: LAND ON ' : 'USE: SCAN ') + BODY[p!.id].name.toUpperCase(), W / 2, H - 34, { align: 'center', scale: 1, color: '#68f0a0', shadow: '#07051a' });
  g.setTransform(1, 0, 0, 1, 0, 0);
}

// ---------------------------------------------------------------- hooks into game 1's loop and renderer
const GP = R.Game.prototype, baseTick = GP.tick;
GP.tick = function (this: Game, dt: number) {
  if (!SPACE.active) return baseTick.call(this, dt);
  this.input.update();
  if (!this.ui.paused()) { this.clock.update(dt * this.timeScale); update(this, dt); }
  this.ui.update(dt);
  this.input.endFrame();
};
const RP = R.Renderer.prototype, baseRender = RP.render;
RP.render = function (this: { g: CanvasRenderingContext2D; cv: HTMLCanvasElement; present(): void; glFrame?: boolean }) {
  if (!SPACE.active) return baseRender.call(this);
  draw(this.g, this.cv.width, this.cv.height);
  this.glFrame = false;
  this.present();
};
// the label on the USE button while flying
const PP = R.Player.prototype, baseCtx = PP.contextAction;
PP.contextAction = function (this: Player) {
  if (SPACE.active) { for (const h of HOOKS.use) { const u = h(R.game); if (u) return { label: u.label, fn: () => {} }; } const w = nearWreck(), p = nearPlanet(); return w ? { label: 'Board', fn: () => {} } : p ? { label: p.id in PLANETS ? 'Land' : 'Scan', fn: () => {} } : null; }
  return baseCtx.call(this);
};
