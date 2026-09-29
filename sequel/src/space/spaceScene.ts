// Space: fly your ship around the system. Point the stick where you want to go (the ship turns
// and thrusts that way), hold B to fire, A to land near a planet or to board a disabled ship.
// Freighters run between planets; Imperial patrols hunt you once you're hot.

import type { Game, Scene, Good } from '../game';
import { bodies, planetArt, sunArt, type Body } from './system';
import { blankShip, shipSprites, stats, type Ship, type Mod } from '../ship/ship';
import { PLANETS, type PlanetId } from '../world/planets';
import { angDiff, clamp, dist, hash2, rng } from '../core/math';
import { sfx } from '../audio';
import { planetScene } from '../world/planetScene';
import { boardScene } from './boardScene';

export interface Craft {
  id: number; kind: 'freighter' | 'patrol'; ship: Ship; flag: 'empire' | 'solari';
  x: number; y: number; vx: number; vy: number; a: number;
  hull: number; maxHull: number; shield: number; maxShield: number;
  disabled: boolean; looted: boolean; dead: boolean;
  target: PlanetId; cool: number; hostile: boolean;
  cargo: { good: Good; n: number }[]; name: string;
}
interface Shot { x: number; y: number; vx: number; vy: number; life: number; from: 'me' | number; dmg: number }
interface Spark { x: number; y: number; vx: number; vy: number; life: number; col: string }

export interface SpaceState {
  x: number; y: number; vx: number; vy: number; a: number;
  shield: number; crafts: Craft[]; shots: Shot[]; sparks: Spark[]; nextId: number; spawnT: number;
}

const states = new WeakMap<Game, SpaceState>();
export function spaceState(game: Game): SpaceState | undefined { return states.get(game); }

const NAMES = ['Imperial Hauler 7', 'Castra Venture', 'Solari Queen', 'Ore Mule', 'Marble Barge', 'Senator\'s Pride', 'Dusty Rose', 'Mule Train'];

function freighterShip(seed: number): Ship {
  const s = blankShip('freighter', 'Freighter'), W = 9, q = rng(seed);
  const set = (x: number, y: number, m: Mod) => { s.grid[y * W + x] = m; };
  for (let y = 0; y < 5; y++) for (let x = 2; x < 7; x++) set(x, y, 'cargo');
  set(8, 2, 'cockpit'); set(0, 1, 'engine'); set(0, 3, 'engine'); set(1, 2, 'reactor'); set(7, 1, 'quarters'); set(7, 3, 'shield'); set(7, 2, 'gun');
  for (let y = 0; y < 5; y++) if (q.chance(0.3)) set(1, y === 2 ? 1 : y, 'fuel');
  s.paint = q.pick(['#8a96a8', '#b8a080', '#a0a8b8']);
  return s;
}
function patrolShip(): Ship {
  const s = blankShip('cutter', 'Patrol'), W = 7;
  const set = (x: number, y: number, m: Mod) => { s.grid[y * W + x] = m; };
  set(6, 1, 'cockpit'); set(6, 2, 'gun'); set(5, 0, 'gun'); set(5, 3, 'gun'); set(0, 1, 'engine'); set(0, 2, 'engine'); set(1, 1, 'reactor'); set(1, 2, 'reactor');
  set(3, 1, 'shield'); set(3, 2, 'armor'); set(4, 1, 'armor'); set(4, 2, 'armor'); set(2, 1, 'quarters');
  s.paint = '#eceef4';
  return s;
}

export function spaceScene(game: Game, from: PlanetId | null): Scene {
  let S = states.get(game);
  const bs = () => bodies(game.minutes);
  if (!S || from) {
    const b = bs().find((x) => x.id === (from || 'veridia')) as Body;
    const out = Math.atan2(b.y, b.x);
    S = { x: b.x + Math.cos(out) * (b.r + 50), y: b.y + Math.sin(out) * (b.r + 50), vx: 0, vy: 0, a: out, shield: 0, crafts: S ? S.crafts : [], shots: [], sparks: [], nextId: S ? S.nextId : 1, spawnT: 0 };
    states.set(game, S);
  }
  const st = S;
  let my = stats(game.ship);
  if (game.shipHull < 0) game.shipHull = my.hull;
  st.shield = my.shield;
  let fireT = 0, thrustT = 0, hintT = 0;

  const spawnFreighter = (near?: boolean) => {
    const B = bs().filter((b) => PLANETS[b.id].orbit), a = B[Math.floor(Math.random() * B.length)], t = B.find((b) => b.id !== a.id) as Body;
    const seed = st.nextId * 7919;
    const q = rng(seed);
    const sh = freighterShip(seed), s = stats(sh);
    const ang = Math.random() * Math.PI * 2;
    const x = near ? st.x + Math.cos(ang) * 700 : a.x + Math.cos(ang) * (a.r + 60), y = near ? st.y + Math.sin(ang) * 700 : a.y + Math.sin(ang) * (a.r + 60);
    const goods: Good[] = ['rum', 'tea', 'ore', 'meds', 'vinyl', 'blasters'];
    st.crafts.push({
      id: st.nextId++, kind: 'freighter', ship: sh, flag: q.chance(0.65) ? 'empire' : 'solari', x, y, vx: 0, vy: 0, a: 0, hull: s.hull, maxHull: s.hull, shield: s.shield, maxShield: s.shield,
      disabled: false, looted: false, dead: false, target: t.id, cool: 0, hostile: false, name: q.pick(NAMES),
      cargo: [{ good: q.pick(goods), n: q.int(4, 9) }, { good: q.pick(goods), n: q.int(3, 7) }],
    });
  };
  const spawnPatrol = () => {
    const sh = patrolShip(), s = stats(sh), ang = Math.random() * Math.PI * 2;
    st.crafts.push({
      id: st.nextId++, kind: 'patrol', ship: sh, flag: 'empire', x: st.x + Math.cos(ang) * 600, y: st.y + Math.sin(ang) * 600, vx: 0, vy: 0, a: ang + Math.PI,
      hull: s.hull, maxHull: s.hull, shield: s.shield, maxShield: s.shield, disabled: false, looted: false, dead: false, target: 'castra', cool: 1.5, hostile: true, name: 'Imperial Patrol', cargo: [],
    });
    game.radio('IMPERIAL PATROL: "Unregistered vessel, cut your engines and prepare to be boarded."');
    sfx('bad');
  };
  if (!st.crafts.some((c) => c.kind === 'freighter' && !c.dead)) { for (let k = 0; k < 3; k++) spawnFreighter(); spawnFreighter(true); }

  const fire = (x: number, y: number, a: number, vx: number, vy: number, from: 'me' | number, dmg: number, n: number) => {
    for (let k = 0; k < n; k++) {
      const off = (k - (n - 1) / 2) * 5, px = -Math.sin(a) * off, py = Math.cos(a) * off;
      st.shots.push({ x: x + Math.cos(a) * 14 + px, y: y + Math.sin(a) * 14 + py, vx: vx + Math.cos(a) * 420, vy: vy + Math.sin(a) * 420, life: 1.1, from, dmg });
    }
  };
  const boom = (x: number, y: number, n: number, cols: string[]) => {
    for (let k = 0; k < n; k++) { const a = Math.random() * 7, s = 20 + Math.random() * 120; st.sparks.push({ x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s, life: 0.4 + Math.random() * 0.7, col: cols[k % cols.length] }); }
  };

  const nearPlanet = () => bs().find((b) => dist(st.x, st.y, b.x, b.y) < b.r + 70) || null;
  const nearWreck = () => st.crafts.find((c) => c.disabled && !c.looted && !c.dead && dist(st.x, st.y, c.x, c.y) < 60) || null;

  const hitCraft = (c: Craft, dmg: number) => {
    const wasPeaceful = !c.hostile;
    if (c.shield > 0) { c.shield = Math.max(0, c.shield - dmg); boom(c.x, c.y, 3, ['#9ad8ff', '#ffffff']); }
    else { c.hull -= dmg; boom(c.x, c.y, 4, ['#ffd060', '#ff8030']); }
    sfx('hit');
    c.hostile = true;
    if (wasPeaceful) {
      game.radio(`${c.name}: "Mayday, mayday! Pirates on the ${PLANETS[c.target].name} lane!"`);
      if (c.flag === 'empire') game.heat.empire += 15; else game.heat.families += 15;
    }
    if (c.kind === 'freighter' && !c.disabled && c.hull < c.maxHull * 0.35) {
      c.disabled = true; c.hostile = false;
      game.radio(`${c.name}: "Engines are gone! We surrender, we surrender!"`);
      game.ui.toast(my.tube ? 'Freighter disabled. Fly alongside and press A to board.' : 'Freighter disabled, but you have no boarding tube.', 'good');
    }
    if (c.hull <= 0) {
      c.dead = true; sfx('boom'); boom(c.x, c.y, 40, ['#ffd060', '#ff8030', '#ffffff', '#c83a2a']);
      if (c.kind === 'patrol') { game.heat.empire += 20; game.radio('Patrol destroyed. The Empire will remember that.'); }
      else game.radio(`${c.name} breaks apart. Her cargo burns with her.`);
    }
  };

  const scene: Scene = {
    name: 'space',
    enter() { game.location = { kind: 'space', planet: from || game.location.planet }; my = stats(game.ship); game.ui.refresh(); },
    update(dt, input) {
      my = stats(game.ship);
      if (game.ui.busy()) return;
      // --- your ship: point the stick where you want to go
      const mag = Math.hypot(input.x, input.y);
      if (mag > 0.2) {
        const want = Math.atan2(input.y, input.x);
        const d = angDiff(st.a, want);
        st.a += clamp(d, -my.turn * dt, my.turn * dt);
        const push = my.thrust * Math.min(1, mag) * (Math.abs(d) < 1.2 ? 1 : 0.3);
        st.vx += Math.cos(st.a) * push * dt; st.vy += Math.sin(st.a) * push * dt;
        thrustT -= dt;
        if (thrustT <= 0) { thrustT = 0.05; st.sparks.push({ x: st.x - Math.cos(st.a) * 16, y: st.y - Math.sin(st.a) * 16, vx: -Math.cos(st.a) * 60 + (Math.random() - 0.5) * 20, vy: -Math.sin(st.a) * 60 + (Math.random() - 0.5) * 20, life: 0.35, col: Math.random() < 0.5 ? '#ffd060' : '#ff8030' }); }
      }
      // gentle space drag so it stays controllable on a phone
      const drag = Math.pow(0.55, dt);
      st.vx *= drag; st.vy *= drag;
      const sp = Math.hypot(st.vx, st.vy), max = 320;
      if (sp > max) { st.vx *= max / sp; st.vy *= max / sp; }
      st.x += st.vx * dt; st.y += st.vy * dt;
      // the sun burns
      if (Math.hypot(st.x, st.y) < 120) { const a = Math.atan2(st.y, st.x); st.vx += Math.cos(a) * 400 * dt; st.vy += Math.sin(a) * 400 * dt; game.shipHull -= 20 * dt; }
      // shields recharge
      st.shield = Math.min(my.shield, st.shield + my.shield * 0.08 * dt);
      fireT -= dt;
      if (input.down('b') && fireT <= 0 && my.guns > 0) { fireT = 0.22; fire(st.x, st.y, st.a, st.vx, st.vy, 'me', 10, my.guns); sfx('laser'); }
      if (input.pressed('a')) {
        const w = nearWreck(), p = nearPlanet();
        if (w) {
          if (!my.tube) game.ui.toast('You need a Boarding Tube module to board.', 'bad');
          else { sfx('door'); game.go(() => boardScene(game, w)); }
        } else if (p) {
          if (!PLANETS[p.id].landable) { game.ui.say('Castra Control', 'Negative, unregistered vessel. Landing clearance on Castra Prime needs papers. (Castra opens in a later build.)'); }
          else if (sp > 150) game.ui.toast('Too fast to land. Slow down.', 'bad');
          else { sfx('land'); game.go(() => planetScene(game, p.id, true)); }
        }
      }

      // --- other craft
      st.spawnT -= dt;
      if (st.spawnT <= 0) { st.spawnT = 20; if (st.crafts.filter((c) => c.kind === 'freighter' && !c.dead && !c.looted).length < 4) spawnFreighter(); if (game.heat.empire >= 20 && !st.crafts.some((c) => c.kind === 'patrol' && !c.dead)) spawnPatrol(); }
      const B = bs();
      for (const c of st.crafts) {
        if (c.dead) continue;
        const cs = stats(c.ship);
        c.shield = Math.min(c.maxShield, c.shield + c.maxShield * 0.03 * dt);
        if (c.disabled) { c.vx *= Math.pow(0.8, dt); c.vy *= Math.pow(0.8, dt); c.a += dt * 0.2; }
        else {
          let tx: number, ty: number;
          if (c.kind === 'patrol' || (c.hostile && dist(c.x, c.y, st.x, st.y) < 400)) { tx = st.x; ty = st.y; }
          else { const t = B.find((b) => b.id === c.target) as Body; tx = t.x; ty = t.y; if (dist(c.x, c.y, tx, ty) < t.r + 40) { c.dead = true; continue; } }
          const want = Math.atan2(ty - c.y, tx - c.x), d = angDiff(c.a, want);
          c.a += clamp(d, -cs.turn * dt * 0.8, cs.turn * dt * 0.8);
          const acc = c.kind === 'patrol' ? cs.thrust * 0.9 : cs.thrust * 0.45;
          if (!(c.kind === 'patrol' && dist(c.x, c.y, st.x, st.y) < 110)) { c.vx += Math.cos(c.a) * acc * dt; c.vy += Math.sin(c.a) * acc * dt; }
          c.vx *= Math.pow(0.55, dt); c.vy *= Math.pow(0.55, dt);
          // shoot back
          c.cool -= dt;
          if (c.hostile && c.cool <= 0 && dist(c.x, c.y, st.x, st.y) < 340 && Math.abs(d) < 0.4) {
            c.cool = c.kind === 'patrol' ? 0.5 : 1.3;
            fire(c.x, c.y, c.a, c.vx, c.vy, c.id, c.kind === 'patrol' ? 8 : 5, c.kind === 'patrol' ? 2 : 1);
          }
        }
        c.x += c.vx * dt; c.y += c.vy * dt;
      }
      st.crafts = st.crafts.filter((c) => !(c.dead && c.kind === 'freighter' && dist(c.x, c.y, st.x, st.y) > 2000) && !(c.looted && dist(c.x, c.y, st.x, st.y) > 1500));

      // --- shots
      for (const s of st.shots) {
        s.x += s.vx * dt; s.y += s.vy * dt; s.life -= dt;
        if (s.from === 'me') {
          for (const c of st.crafts) if (!c.dead && dist(s.x, s.y, c.x, c.y) < (c.kind === 'freighter' ? 24 : 16)) { hitCraft(c, s.dmg); s.life = 0; break; }
        } else if (dist(s.x, s.y, st.x, st.y) < 14) {
          s.life = 0; sfx('hit');
          if (st.shield > 0) { st.shield = Math.max(0, st.shield - s.dmg); boom(st.x, st.y, 3, ['#9ad8ff', '#fff']); }
          else { game.shipHull -= s.dmg; boom(st.x, st.y, 4, ['#ffd060', '#ff8030']); }
        }
      }
      st.shots = st.shots.filter((s) => s.life > 0);
      for (const p of st.sparks) { p.x += p.vx * dt; p.y += p.vy * dt; p.life -= dt; }
      st.sparks = st.sparks.filter((p) => p.life > 0);

      // --- destroyed: towed back to the last planet, minus the cargo and a cut
      if (game.shipHull <= 0) {
        sfx('boom');
        game.cargo = [];
        const cut = Math.round(game.credits * 0.3);
        game.credits -= cut; game.shipHull = my.hull; game.heat.empire = 0;
        game.ui.say('Salvage Crew', `We pulled you out of the wreck. The cargo's gone and the tow was ${cut} credits. Try not to do that again.`);
        game.go(() => planetScene(game, game.location.planet === 'hollow' ? 'hollow' : 'veridia', true));
      }
      hintT -= dt;
      if (hintT <= 0 && !game.objectives.find((o) => o.id === 'rob')?.done) {
        hintT = 45;
        const f = st.crafts.find((c) => c.kind === 'freighter' && !c.dead && !c.disabled);
        if (f) game.radio(`Scanner: ${f.name} (${f.flag === 'empire' ? 'Imperial' : 'Solari'} flag) inbound to ${PLANETS[f.target].name}. Shoot her engines out, then board.`);
      }
    },
    action() {
      const w = nearWreck();
      if (w) return 'BOARD';
      const p = nearPlanet();
      if (p) return PLANETS[p.id].landable ? 'LAND' : 'HAIL';
      return '';
    },
    draw(g, W, H) {
      const cx = st.x - W / 2, cy = st.y - H / 2;
      g.fillStyle = '#070718'; g.fillRect(0, 0, W, H);
      // nebula wash that shifts across the system
      const neb = g.createRadialGradient(W * 0.3 - cx * 0.02, H * 0.4 - cy * 0.02, 10, W * 0.3, H * 0.4, W);
      neb.addColorStop(0, 'rgba(90,40,120,0.35)'); neb.addColorStop(1, 'rgba(10,10,40,0)');
      g.fillStyle = neb; g.fillRect(0, 0, W, H);
      // three layers of stars
      for (const [layer, size, cell] of [[0.15, 1, 40], [0.4, 1, 60], [0.8, 2, 90]] as [number, number, number][]) {
        const ox = cx * layer, oy = cy * layer;
        for (let gy = Math.floor(oy / cell); gy <= Math.floor((oy + H) / cell); gy++)
          for (let gx = Math.floor(ox / cell); gx <= Math.floor((ox + W) / cell); gx++) {
            const h = hash2(gx, gy, size * 13 + cell);
            if (h > 0.55) continue;
            const x = gx * cell + hash2(gx, gy, 1) * cell - ox, y = gy * cell + hash2(gx, gy, 2) * cell - oy;
            g.fillStyle = h < 0.08 ? '#ffe8a0' : h < 0.16 ? '#a8c8ff' : '#e8e8f8';
            g.fillRect(Math.round(x), Math.round(y), size, size);
          }
      }
      g.save();
      g.translate(-Math.round(cx), -Math.round(cy));
      // the sun and its glow
      const sg = g.createRadialGradient(0, 0, 60, 0, 0, 380);
      sg.addColorStop(0, 'rgba(255,220,120,0.5)'); sg.addColorStop(1, 'rgba(255,160,60,0)');
      g.fillStyle = sg; g.fillRect(-380, -380, 760, 760);
      const sa = sunArt(); g.drawImage(sa, -sa.width / 2, -sa.height / 2);
      // the asteroid belt between Castra and Hollow: drawn only near the camera
      const BELT = 3300, cell = 48;
      for (let gy = Math.floor(cy / cell); gy <= Math.floor((cy + H) / cell); gy++)
        for (let gx = Math.floor(cx / cell); gx <= Math.floor((cx + W) / cell); gx++) {
          const x = gx * cell + hash2(gx, gy, 4) * cell, y = gy * cell + hash2(gx, gy, 5) * cell;
          const r = Math.hypot(x, y);
          if (Math.abs(r - BELT) > 160 || hash2(gx, gy, 6) > 0.35) continue;
          const s = 2 + Math.floor(hash2(gx, gy, 8) * 5);
          g.fillStyle = '#3e3440'; g.fillRect(x - s, y - s + 1, s * 2, s * 2);
          g.fillStyle = '#6e6272'; g.fillRect(x - s, y - s, s * 2 - 1, s * 2 - 1);
          g.fillStyle = '#a498a8'; g.fillRect(x - s, y - s, s, 1);
        }
      for (const b of bs()) {
        if (b.x + b.r < cx - 20 || b.x - b.r > cx + W + 20 || b.y + b.r < cy - 20 || b.y - b.r > cy + H + 20) continue;
        const a = planetArt(b.id); g.drawImage(a, Math.round(b.x - a.width / 2), Math.round(b.y - a.height / 2));
      }
      // craft
      for (const c of st.crafts) {
        if (c.dead || c.x < cx - 60 || c.x > cx + W + 60 || c.y < cy - 60 || c.y > cy + H + 60) continue;
        const spr = shipSprites(c.ship)[((Math.round((c.a / (Math.PI * 2)) * 32) % 32) + 32) % 32];
        g.drawImage(spr, Math.round(c.x - spr.width / 2), Math.round(c.y - spr.height / 2));
        if (c.shield > 0 && c.hostile) { g.strokeStyle = 'rgba(150,210,255,0.5)'; g.beginPath(); g.arc(c.x, c.y, spr.width / 2, 0, 7); g.stroke(); }
        if (c.disabled && !c.looted && Math.floor(performance.now() / 300) % 2) { g.fillStyle = '#68f0a0'; g.fillRect(c.x - 1, c.y - spr.height / 2 - 6, 3, 3); }
        // hull bar once they're in a fight
        if (c.hostile || c.disabled) { g.fillStyle = '#1c1828'; g.fillRect(c.x - 14, c.y + spr.height / 2 + 2, 28, 3); g.fillStyle = c.disabled ? '#e8b020' : '#e84848'; g.fillRect(c.x - 14, c.y + spr.height / 2 + 2, 28 * Math.max(0, c.hull / c.maxHull), 3); }
      }
      // shots and sparks
      for (const s of st.shots) { g.fillStyle = s.from === 'me' ? '#ff5a5a' : '#78ff98'; const a = Math.atan2(s.vy, s.vx); for (let k = 0; k < 5; k++) g.fillRect(Math.round(s.x - Math.cos(a) * k), Math.round(s.y - Math.sin(a) * k), 2, 2); }
      for (const p of st.sparks) { g.fillStyle = p.col; g.fillRect(Math.round(p.x), Math.round(p.y), p.life > 0.3 ? 2 : 1, p.life > 0.3 ? 2 : 1); }
      // you
      const me = shipSprites(game.ship)[((Math.round((st.a / (Math.PI * 2)) * 32) % 32) + 32) % 32];
      g.drawImage(me, Math.round(st.x - me.width / 2), Math.round(st.y - me.height / 2));
      if (st.shield > 1) { g.strokeStyle = `rgba(150,210,255,${0.2 + 0.4 * (st.shield / Math.max(1, my.shield))})`; g.beginPath(); g.arc(st.x, st.y, me.width / 2 + 1, 0, 7); g.stroke(); }
      g.restore();

      // off-screen markers for planets and targets, DS-style
      const mark = (x: number, y: number, col: string, label: string) => {
        const dx = x - st.x, dy = y - st.y;
        if (Math.abs(dx) < W / 2 - 8 && Math.abs(dy) < H / 2 - 8) return;
        const a = Math.atan2(dy, dx), k = Math.min((W / 2 - 14) / Math.abs(Math.cos(a) || 1e-3), (H / 2 - 14) / Math.abs(Math.sin(a) || 1e-3));
        const mx = W / 2 + Math.cos(a) * k, my2 = H / 2 + Math.sin(a) * k;
        g.fillStyle = col; g.beginPath(); g.moveTo(mx + Math.cos(a) * 6, my2 + Math.sin(a) * 6); g.lineTo(mx + Math.cos(a + 2.4) * 5, my2 + Math.sin(a + 2.4) * 5); g.lineTo(mx + Math.cos(a - 2.4) * 5, my2 + Math.sin(a - 2.4) * 5); g.fill();
        g.font = '8px "Pixelify Sans", monospace'; g.textAlign = 'center'; g.fillStyle = '#f0ecf8';
        g.fillText(label, clamp(mx - Math.cos(a) * 14, 20, W - 20), clamp(my2 - Math.sin(a) * 12 + 3, 10, H - 4));
      };
      for (const b of bs()) mark(b.x, b.y, PLANETS[b.id].color, PLANETS[b.id].name.toUpperCase() + ' ' + Math.round(dist(st.x, st.y, b.x, b.y) / 10) + 'km');
      for (const c of st.crafts) if (!c.dead && (c.kind === 'patrol' || (c.disabled && !c.looted) || dist(c.x, c.y, st.x, st.y) < 1400)) mark(c.x, c.y, c.kind === 'patrol' ? '#ff5a5a' : c.disabled ? '#68f0a0' : '#e8e0c8', c.kind === 'patrol' ? 'PATROL' : c.disabled ? 'BOARD' : 'FREIGHT');
      // hull and shield gauges
      const bar = (y: number, v: number, col: string, label: string) => { g.fillStyle = 'rgba(12,10,30,0.7)'; g.fillRect(6, y, 62, 7); g.fillStyle = col; g.fillRect(7, y + 1, 60 * clamp(v, 0, 1), 5); g.font = '7px "Pixelify Sans", monospace'; g.textAlign = 'left'; g.fillStyle = '#f0ecf8'; g.fillText(label, 72, y + 6); };
      bar(H - 22, game.shipHull / my.hull, '#e84848', 'HULL');
      bar(H - 13, my.shield ? st.shield / my.shield : 0, '#58a8e8', 'SHIELD');
    },
  };
  return scene;
}
