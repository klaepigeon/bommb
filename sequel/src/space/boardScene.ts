// Boarding a disabled ship. Its module grid becomes the interior: every module is a 4×4 room,
// neighbouring modules get a door between them, and the cargo bays hold the crates. The crew
// fights back; take what you can carry and get back to the tube.

import type { Game, Scene, Good } from '../game';
import { GOODS } from '../game';
import type { Craft } from './spaceScene';
import { spaceScene } from './spaceScene';
import { HULLS } from '../ship/ship';
import { tileCanvas, TS, T } from '../gfx/tiles';
import { propArt } from '../gfx/buildings';
import { personSprite, randomLook, type Facing, type Look } from '../gfx/people';
import { clamp, dist, rng } from '../core/math';
import { sfx } from '../audio';

interface Guard { x: number; y: number; hp: number; facing: Facing; look: Look; cool: number; walk: number; down: boolean }
interface Crate { x: number; y: number; good: Good; n: number; taken: boolean }
interface Bolt { x: number; y: number; vx: number; vy: number; life: number; mine: boolean }

export function boardScene(game: Game, craft: Craft): Scene {
  const H = HULLS[craft.ship.hull];
  const CW = 5, W = H.w * CW + 1, Hh = H.h * CW + 3; // two extra rows on top for the tube
  const tile = new Uint8Array(W * Hh).fill(T.VOID);
  const at = (x: number, y: number) => (x < 0 || y < 0 || x >= W || y >= Hh ? T.VOID : tile[y * W + x]);
  const set = (x: number, y: number, t: number) => { if (x >= 0 && y >= 0 && x < W && y < Hh) tile[y * W + x] = t; };
  const cell = (gx: number, gy: number) => (gx < 0 || gy < 0 || gx >= H.w || gy >= H.h ? null : craft.ship.grid[gy * H.w + gx]);
  const q = rng(craft.id * 131);
  const crates: Crate[] = [];
  // rooms
  for (let gy = 0; gy < H.h; gy++)
    for (let gx = 0; gx < H.w; gx++) {
      if (!cell(gx, gy)) continue;
      const ox = gx * CW, oy = gy * CW + 2;
      for (let j = 0; j <= CW; j++) for (let i = 0; i <= CW; i++) if (at(ox + i, oy + j) !== T.FLOOR) set(ox + i, oy + j, i === 0 || j === 0 || i === CW || j === CW ? T.WALL : T.FLOOR);
      // doors to neighbours
      if (cell(gx + 1, gy)) { set(ox + CW, oy + 2, T.FLOOR); set(ox + CW, oy + 3, T.FLOOR); }
      if (cell(gx, gy + 1)) { set(ox + 2, oy + CW, T.FLOOR); set(ox + 3, oy + CW, T.FLOOR); }
    }
  // re-open doors that a later room's wall covered
  for (let gy = 0; gy < H.h; gy++)
    for (let gx = 0; gx < H.w; gx++) {
      if (!cell(gx, gy)) continue;
      const ox = gx * CW, oy = gy * CW + 2;
      if (cell(gx + 1, gy)) { set(ox + CW, oy + 2, T.FLOOR); set(ox + CW, oy + 3, T.FLOOR); }
      if (cell(gx, gy + 1)) { set(ox + 2, oy + CW, T.FLOOR); set(ox + 3, oy + CW, T.FLOOR); }
    }
  // the tube docks on the top of the middle cargo bay
  const tubeGX = Math.floor(H.w / 2), tubeX = tubeGX * CW + 2;
  set(tubeX, 0, T.TUBE); set(tubeX + 1, 0, T.TUBE); set(tubeX, 1, T.TUBE); set(tubeX + 1, 1, T.TUBE); set(tubeX, 2, T.FLOOR); set(tubeX + 1, 2, T.FLOOR);
  // crates: the freighter's cargo spread over its bays
  const bays: [number, number][] = [];
  for (let gy = 0; gy < H.h; gy++) for (let gx = 0; gx < H.w; gx++) if (cell(gx, gy) === 'cargo' && !(gx === tubeGX && gy === 0)) bays.push([gx, gy]);
  for (const lot of craft.cargo) {
    let left = lot.n;
    while (left > 0 && bays.length) {
      const [gx, gy] = bays.splice(q.int(0, bays.length - 1), 1)[0];
      const k = Math.min(left, q.int(2, 4));
      crates.push({ x: (gx * CW + 2 + q.int(0, 1)) * TS + 8, y: (gy * CW + 2 + 2 + q.int(0, 1)) * TS + 8, good: lot.good, n: k, taken: false });
      left -= k;
    }
  }
  // the crew: Imperial troopers on Empire ships, Solari soldiers otherwise
  const guards: Guard[] = [];
  const rooms: [number, number][] = [];
  for (let gy = 0; gy < H.h; gy++) for (let gx = 0; gx < H.w; gx++) if (cell(gx, gy) && Math.abs(gx - tubeGX) + gy > 2) rooms.push([gx, gy]);
  const nG = Math.min(rooms.length, 3 + (craft.flag === 'empire' ? 1 : 0));
  for (let k = 0; k < nG; k++) {
    const [gx, gy] = rooms.splice(q.int(0, rooms.length - 1), 1)[0];
    guards.push({ x: (gx * CW + 2) * TS + 16, y: (gy * CW + 2 + 2) * TS + 16, hp: 30, facing: 0, look: randomLook(craft.id * 17 + k, craft.flag === 'empire' ? 'trooper' : 'suit'), cool: 1 + k * 0.4, walk: 0, down: false });
  }

  const pl = { x: (tubeX + 1) * TS, y: 1 * TS + 8, facing: 0 as Facing, walk: 0, cool: 0, hurtT: 0 };
  const bolts: Bolt[] = [];
  let took = 0, leaving = false, frame = 0, ft = 0;
  const solidAt = (x: number, y: number) => { const t = at(Math.floor(x / TS), Math.floor(y / TS)); return t === T.WALL || t === T.VOID || t === T.HULL; };
  const blocked = (x: number, y: number) => [[-5, -3], [5, -3], [-5, 3], [5, 3]].some(([ox, oy]) => solidAt(x + ox, y + oy));
  const los = (ax: number, ay: number, bx: number, by: number) => { const n = Math.ceil(dist(ax, ay, bx, by) / 6); for (let k = 1; k < n; k++) if (solidAt(ax + ((bx - ax) * k) / n, ay + ((by - ay) * k) / n)) return false; return true; };
  const dirVec = (f: Facing) => [[0, 1], [-1, 0], [1, 0], [0, -1]][f];
  const nearCrate = () => crates.find((c) => !c.taken && dist(pl.x, pl.y, c.x, c.y) < 20) || null;
  const onTube = () => at(Math.floor(pl.x / TS), Math.floor(pl.y / TS)) === T.TUBE;

  const leave = (msg: string) => {
    if (leaving) return;
    leaving = true;
    craft.looted = took > 0 || craft.looted;
    if (took) game.complete('rob');
    game.radio(msg);
    game.go(() => spaceScene(game, null));
  };

  const scene: Scene = {
    name: 'board',
    enter() {
      game.location = { kind: 'board', planet: game.location.planet };
      game.radio(`Tube sealed to the ${craft.name}. ${guards.length} crew aboard. Crates are in the cargo bays.`);
    },
    update(dt, input) {
      ft += dt; if (ft > 0.3) { ft = 0; frame++; }
      if (game.ui.busy()) return;
      // you
      const mag = Math.hypot(input.x, input.y);
      if (mag > 0.2) {
        const sp = 70 * dt, mx = (input.x / Math.max(1, mag)) * sp, my = (input.y / Math.max(1, mag)) * sp;
        if (!blocked(pl.x + mx, pl.y)) pl.x += mx;
        if (!blocked(pl.x, pl.y + my)) pl.y += my;
        pl.facing = Math.abs(input.x) > Math.abs(input.y) ? (input.x < 0 ? 1 : 2) : input.y < 0 ? 3 : 0;
        pl.walk += dt;
      } else pl.walk = 0;
      pl.cool -= dt; pl.hurtT -= dt;
      if (input.down('b') && pl.cool <= 0) {
        pl.cool = 0.32;
        // auto-aim at the nearest guard in view, like the DS games' lock-on
        let tx = pl.x + dirVec(pl.facing)[0] * 100, ty = pl.y + dirVec(pl.facing)[1] * 100;
        const g = guards.filter((x) => !x.down && dist(x.x, x.y, pl.x, pl.y) < 160 && los(pl.x, pl.y - 8, x.x, x.y - 8)).sort((a, b) => dist(a.x, a.y, pl.x, pl.y) - dist(b.x, b.y, pl.x, pl.y))[0];
        if (g) { tx = g.x; ty = g.y; const dx = tx - pl.x, dy = ty - pl.y; pl.facing = Math.abs(dx) > Math.abs(dy) ? (dx < 0 ? 1 : 2) : dy < 0 ? 3 : 0; }
        const a = Math.atan2(ty - pl.y, tx - pl.x);
        bolts.push({ x: pl.x + Math.cos(a) * 8, y: pl.y - 10 + Math.sin(a) * 8, vx: Math.cos(a) * 260, vy: Math.sin(a) * 260, life: 1, mine: true });
        sfx('laser');
      }
      if (input.pressed('a')) {
        const c = nearCrate();
        if (c) {
          const put = game.addCargo(c.good, c.n, true);
          if (!put) game.ui.toast('Your holds are full.', 'bad');
          else { c.n -= put; took += put; if (c.n <= 0) c.taken = true; sfx('coin'); game.ui.toast(`+${put} ${GOODS[c.good].name}${GOODS[c.good].contraband ? ' (contraband)' : ''}`, 'good'); }
        } else if (onTube()) leave(took ? `Back aboard with ${took} crates of ${craft.name}'s cargo.` : 'You back out through the tube empty-handed.');
      }
      // the crew
      for (const g of guards) {
        if (g.down) continue;
        const d = dist(g.x, g.y, pl.x, pl.y), see = d < 170 && los(g.x, g.y - 8, pl.x, pl.y - 8);
        g.cool -= dt;
        if (see) {
          const dx = pl.x - g.x, dy = pl.y - g.y;
          g.facing = Math.abs(dx) > Math.abs(dy) ? (dx < 0 ? 1 : 2) : dy < 0 ? 3 : 0;
          if (d > 70) { const sp = 34 * dt, mx = (dx / d) * sp, my = (dy / d) * sp; if (!blocked(g.x + mx, g.y)) g.x += mx; if (!blocked(g.x, g.y + my)) g.y += my; g.walk += dt; } else g.walk = 0;
          if (g.cool <= 0) {
            g.cool = 1.1 + Math.random() * 0.6;
            const a = Math.atan2(pl.y - g.y, pl.x - g.x) + (Math.random() - 0.5) * 0.25;
            bolts.push({ x: g.x + Math.cos(a) * 8, y: g.y - 10 + Math.sin(a) * 8, vx: Math.cos(a) * 170, vy: Math.sin(a) * 170, life: 1.4, mine: false });
            sfx('laser');
          }
        } else g.walk = 0;
      }
      for (const b of bolts) {
        b.x += b.vx * dt; b.y += b.vy * dt; b.life -= dt;
        if (solidAt(b.x, b.y + 10)) { b.life = 0; continue; }
        if (b.mine) {
          for (const g of guards) if (!g.down && dist(b.x, b.y, g.x, g.y - 10) < 9) {
            b.life = 0; g.hp -= 15; sfx('hit');
            if (g.hp <= 0) { g.down = true; if (guards.every((x) => x.down)) { game.ui.toast('The crew surrenders. The ship is yours to strip.', 'good'); game.radio(`${craft.name}'s crew throws down their blasters.`); } }
          }
        } else if (dist(b.x, b.y, pl.x, pl.y - 10) < 8) { b.life = 0; game.hp -= 12; pl.hurtT = 0.25; sfx('hit'); }
      }
      for (let i = bolts.length - 1; i >= 0; i--) if (bolts[i].life <= 0) bolts.splice(i, 1);
      if (game.hp <= 0) {
        game.hp = 35;
        game.ui.say(craft.name, 'The crew drags you back to your tube and shoves you through. They keep their cargo and your pride.');
        leave('Thrown off the ship. That went badly.');
      }
    },
    action() { if (nearCrate()) return 'TAKE'; if (onTube()) return 'LEAVE'; return ''; },
    test: {
      clearCrew: () => { for (const gd of guards) gd.down = true; return guards.length; },
      // walk to each crate and take it, through the same code path as pressing A
      lootAll: () => { for (const c of crates) { if (c.taken) continue; pl.x = c.x; pl.y = c.y + 6; const put = game.addCargo(c.good, c.n, true); c.n -= put; took += put; if (c.n <= 0) c.taken = true; } return took; },
      leave: () => leave(`Back aboard with ${took} crates.`),
    },
    draw(g, SW, Hc) {
      const cx = clamp(pl.x - SW / 2, -40, Math.max(-40, W * TS - SW + 40)), cy = clamp(pl.y - Hc / 2, -40, Math.max(-40, Hh * TS - Hc + 40));
      g.fillStyle = '#070718'; g.fillRect(0, 0, SW, Hc);
      g.save(); g.translate(-Math.round(cx), -Math.round(cy));
      for (let y = 0; y < Hh; y++) for (let x = 0; x < W; x++) { const t = at(x, y); if (t !== T.VOID) g.drawImage(tileCanvas(t, (x * 7 + y) % 6, frame), x * TS, y * TS); }
      // module labels on the floors, like painted deck stencils
      g.font = '7px "Pixelify Sans", monospace'; g.textAlign = 'center'; g.fillStyle = 'rgba(255,255,255,0.28)';
      for (let gy = 0; gy < H.h; gy++) for (let gx = 0; gx < H.w; gx++) { const m = cell(gx, gy); if (m) g.fillText(m.toUpperCase(), gx * CW * TS + CW * 8, (gy * CW + 2) * TS + 22); }
      const items: { y: number; draw: () => void }[] = [];
      for (const c of crates) if (!c.taken) items.push({ y: c.y, draw: () => { const s = propArt('crate', 0, false); g.drawImage(s.cv, c.x - 8, c.y - 12); if (GOODS[c.good].contraband) { g.fillStyle = '#e84848'; g.fillRect(c.x - 1, c.y - 9, 3, 3); } } });
      const person = (x: number, y: number, look: Look, f: Facing, walk: number, down: boolean, hurt: boolean) => {
        if (down) { g.save(); g.translate(x, y); g.rotate(Math.PI / 2); g.globalAlpha = 0.85; g.drawImage(personSprite(look, 0, 0), -16, -25); g.restore(); return; }
        const fr = walk > 0 ? (Math.floor(walk * 7) % 4 === 1 ? 1 : Math.floor(walk * 7) % 4 === 3 ? 2 : 0) : 0;
        g.fillStyle = 'rgba(0,0,0,0.3)'; g.beginPath(); g.ellipse(x, y + 5, 6, 2.5, 0, 0, 7); g.fill();
        if (hurt) g.globalAlpha = 0.5;
        g.drawImage(personSprite(look, f, fr), Math.round(x - 16), Math.round(y - 25));
        g.globalAlpha = 1;
      };
      for (const gd of guards) items.push({ y: gd.y, draw: () => person(gd.x, gd.y, gd.look, gd.facing, gd.walk, gd.down, false) });
      items.push({ y: pl.y, draw: () => person(pl.x, pl.y, game.player, pl.facing, pl.walk, false, pl.hurtT > 0) });
      items.sort((a, b) => a.y - b.y);
      for (const it of items) it.draw();
      for (const b of bolts) { g.fillStyle = b.mine ? '#ff6a5a' : '#78ff98'; g.fillRect(Math.round(b.x) - 1, Math.round(b.y) - 1, 3, 3); g.fillStyle = '#ffffff'; g.fillRect(Math.round(b.x), Math.round(b.y), 1, 1); }
      g.restore();
      // a red emergency light: the ship's disabled
      g.fillStyle = `rgba(200,30,40,${0.08 + 0.06 * Math.sin(performance.now() / 300)})`; g.fillRect(0, 0, SW, Hc);
      // your health
      g.fillStyle = 'rgba(12,10,30,0.7)'; g.fillRect(6, Hc - 13, 62, 7); g.fillStyle = '#e84848'; g.fillRect(7, Hc - 12, 60 * clamp(game.hp / 100, 0, 1), 5);
      g.font = '7px "Pixelify Sans", monospace'; g.textAlign = 'left'; g.fillStyle = '#f0ecf8'; g.fillText('HEALTH', 72, Hc - 7);
    },
  };
  return scene;
}
