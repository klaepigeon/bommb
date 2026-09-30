// The Green Lanterns, ten years on.
//   Kyle Rayner. The last Green Lantern on Earth, in the full uniform (green and black, the
//   mask, the lantern on his chest), still patrolling Los Angeles one sector south of the
//   Brass Coast like the Syndicate never happened. The Fear Man's one job: kill him. He fights
//   with the ring (fists, hammers, walls of green light, a shield when he's hurt), and when he
//   dies the ring slides off his finger and streaks away into the sky, looking for somebody
//   worthy. Not you. The clamp comes off your ship.
//   Parallax. Hal Jordan, what's left of him: hair gone white, the green armour grown over
//   him like a shell, the yellow burning behind his eyes. He's been living in the Martian
//   wastes, burning out claim camps. A boss fight in three moods (bolts, a nova ring of fear,
//   then he comes at you himself). Beat him and the yellow drains out of him, and for a
//   second he's Hal again. His ring comes to you, and so does the armour.

import { SQ, saveSequel } from './state';
import { EARTH } from './earth';
import { SPACE, HOOKS } from './space';
import { giveRingAnyway } from './fearboss';

const TS = R.TILE;
export const LA: [number, number] = [12, 11];
interface Bolt { x: number; y: number; vx: number; vy: number; t: number; col: string; dmg: number; big: boolean; life: number }
export const LANTERNS = { kyle: null as any, hal: null as any, bolts: [] as Bolt[], ring: null as null | { x: number; y: number; vx: number; vy: number; t: number }, release: null as null | ((g: Game) => void), marsSpot: null as null | { x: number; y: number } };
const inLA = () => EARTH.active && EARTH.sector[0] === LA[0] && EARTH.sector[1] === LA[1];
const onMars = () => SQ.planet === 'mars' && SQ.home === 'sol';
const GREEN = ['#0e4a1e', '#1a7a34', '#2eb04e', '#7cf08c'], BLACK = ['#08080c', '#121218', '#1e1e28', '#30303c'];

// ---------------------------------------------------------------- the job
export function giveRaynerJob(g: Game): void {
  if (SQ.flags.rayner) return;
  SQ.flags.rayner = 1; saveSequel();
  g.ui.story('The Fear Man\'s job', 'A Syndicate courier finds you on the pad and presses a holo-card into your hand. It plays once, in a thin old voice.\n\n"My master, Parallax, wants the last green ring gone from this world. There is one of them left. One green ring on all of Earth. Kyle Rayner. He guards Los Angeles as though it were still worth guarding."\n\n"Bring me his death and your ship is yours."\n\nLos Angeles is the next sector south: walk or drive off the bottom of the map, or fly there and pick it from the landing zones.\n\n(Or there\'s the other way to get a clamp off: kill the man who put it there.)');
}
export const raynerText = () => (SQ.flags.rayner === 1 ? 'Kill Kyle Rayner in Los Angeles (the next sector south), or kill the Fear Man. Either way the clamp comes off.' : null);

// ---------------------------------------------------------------- looks
function lanternLook(g: Game): any {
  const l = g.pop.makeLook(R.mulberry(4711), { fem: false, age: 30, role: 'none', city: 'port' });
  return Object.assign(l, { skin: '#d8a07a', hair: '#141418', hat: null, shades: false, seedStr: 'kyle-rayner', domino: '#1a7a34', emblem: 1,
    oldOverride: { skin: ['#7a4a2a', '#a8704a', '#d8a07a', '#f0c8a0'], hair: ['#08080c', '#101016', '#1c1c24', '#2c2c38'], style: 'short', stache: false, beard: false, glasses: false, jacket: null, top: 'turtle', shirt: GREEN, pants: BLACK, belt: '#1a7a34', flare: false }, old: null });
}
function parallaxLook(g: Game): any {
  const l = g.pop.makeLook(R.mulberry(2814), { fem: false, age: 45, role: 'none', city: 'port' });
  return Object.assign(l, { skin: '#e0ac7e', hair: '#e8e8f0', hat: null, shades: false, seedStr: 'parallax', domino: '#0a2a14', emblem: 2, armor: 1,
    oldOverride: { skin: ['#8a5a3a', '#b87a54', '#e0ac7e', '#f8d0a8'], hair: ['#8a8a98', '#b8b8c8', '#e8e8f0', '#ffffff'], style: 'short', stache: false, beard: false, glasses: false, jacket: ['#0a2a14', '#14482a', '#2a6a3a', '#e0c030'], top: 'collar', shirt: ['#6a5a10', '#a88a18', '#e0c030', '#fff27a'], pants: ['#06140a', '#0c2414', '#163a20', '#245a30'], belt: '#e0c030', flare: false }, old: null });
}
// the mask, the lantern on the chest, Parallax's pauldrons: painted over the sprite, rooted to it
const DIR8 = ['right', 'downright', 'down', 'downright', 'right', 'upright', 'up', 'upright'];
const FLIP8 = [false, false, false, true, true, true, false, false];
const A = R.art as any, drawPerson = A.drawPerson;
A.drawPerson = function (g: CanvasRenderingContext2D, x: number, y: number, dir: number, walk: number, look: any, st: any) {
  const res = drawPerson.call(this, g, x, y, dir, walk, look, st);
  if (!look || !look.domino || (st && (st.down || st.scale || st.crouch))) return res;
  const moving = walk && Math.abs(walk) > 0.01, bob = moving && (Math.floor(walk * 0.5) % 4) % 2 ? 1 : 0;
  const X = Math.round(x), Y = Math.round(y) - bob, d8 = A.dir8(dir, st && st.ang), n = DIR8[d8], flip = FLIP8[d8];
  const back = n === 'up' || n === 'upright';
  const cx = n === 'down' || n === 'up' ? 7.5 : n === 'downright' || n === 'upright' ? 9 : 10, sq = n === 'right' ? 0.6 : n === 'downright' || n === 'upright' ? 0.85 : 1;
  const rect = (dx: number, row: number, w: number, h: number, c: string) => { const ww = Math.max(1, Math.round(w * sq)); const sx = cx + dx * sq; const xx = Math.round(flip ? 16 - sx - ww : sx); g.fillStyle = c; g.fillRect(X - 8 + xx, Y - 25 + row, ww, h); };
  if (!back) {
    rect(-4, 9, 9, 2, look.domino);
    if (look.emblem === 2) { rect(-3, 10, 1, 1, '#fff27a'); rect(2, 10, 1, 1, '#fff27a'); }
    else { rect(-3, 10, 2, 1, '#e8fff0'); rect(1, 10, 2, 1, '#e8fff0'); }
    rect(-1, 18, 3, 3, '#f0fff4'); rect(0, 19, 1, 1, look.emblem === 2 ? '#e0c030' : '#1a7a34');
  }
  if (look.armor) { rect(-7, 15, 3, 2, '#e0c030'); rect(4, 15, 3, 2, '#e0c030'); rect(-7, 15, 3, 1, '#fff27a'); rect(4, 15, 3, 1, '#fff27a'); }
  return res;
};

// ---------------------------------------------------------------- shared: light constructs
function bolt(from: any, to: any, col: string, dmg: number, big = false, ang?: number, speed = 200): void {
  const a = ang != null ? ang : Math.atan2(to.y - 10 - (from.y - 12), to.x - from.x);
  LANTERNS.bolts.push({ x: from.x, y: from.y - 12, vx: Math.cos(a) * speed, vy: Math.sin(a) * speed, t: 0, col, dmg, big, life: 1.6 });
}
function stepBolts(g: Game, dt: number): void {
  const pl = g.player;
  for (let i = LANTERNS.bolts.length - 1; i >= 0; i--) {
    const b = LANTERNS.bolts[i];
    b.t += dt; b.x += b.vx * dt; b.y += b.vy * dt;
    if (!pl.inCar && !pl.hidden && Math.hypot(b.x - pl.x, b.y - (pl.y - 10)) < (b.big ? 12 : 9)) {
      pl.hurt(b.dmg, LANTERNS.hal || LANTERNS.kyle || null, 'blast'); if (pl.knock) pl.knock(Math.atan2(b.vy, b.vx), b.big ? 180 : 90);
      g.fx.text(pl.x, pl.y - 26, b.big ? 'WHAM!' : 'ZAP!', b.col); LANTERNS.bolts.splice(i, 1); continue;
    }
    if (b.t > b.life) LANTERNS.bolts.splice(i, 1);
  }
}
const aura = (g: CanvasRenderingContext2D, h: any, col: string, r: number) => { const t = performance.now() / 1000, k = 0.5 + Math.sin(t * 4) * 0.15; const gr = g.createRadialGradient(h.x, h.y - 12, 2, h.x, h.y - 12, r); gr.addColorStop(0, col.replace('A', String(0.35 * k))); gr.addColorStop(1, col.replace('A', '0')); g.fillStyle = gr; g.fillRect(h.x - r, h.y - 12 - r, r * 2, r * 2); };
function hpBar(g: CanvasRenderingContext2D, h: any, name: string, col: string): void {
  if (!h || h.dead || h.hp >= h.maxHp) return;
  const w = 44, x = Math.round(h.x - w / 2), y = Math.round(h.y - 40);
  g.fillStyle = '#10101a'; g.fillRect(x - 1, y - 1, w + 2, 5); g.fillStyle = col; g.fillRect(x, y, Math.max(0, w * h.hp / h.maxHp), 3);
  A.ptext(g, name, h.x, y - 9, { align: 'center', scale: 1, color: col, shadow: '#07051a' });
}

// ---------------------------------------------------------------- Kyle Rayner
function spawnKyle(g: Game): void {
  const w = g.world, c = w.cities[0];
  const at = w.findNear(c.cx, c.cy, 0, 10, (x: number, y: number) => !w.solidPed(x, y) && !w.isWater(x, y) && !!w.cityAt(x, y)) || { x: c.cx, y: c.cy };
  const h = g.actors.makeHuman(at.x * TS + 8, at.y * TS + 8, { arch: 'friendly', tag: 'lantern', cash: 0, look: lanternLook(g) });
  h.look = lanternLook(g);
  h.strangerName = 'Kyle Rayner'; h.keep = true; h.hp = h.maxHp = 420; h.tr.brave = 1; h.kyle = true; h.stay = true; h.state = 'idle'; h.timer = 1e9; h.hostileLocked = true;
  LANTERNS.kyle = h;
  (R as any).poi && (R as any).poi.add(at.x, at.y, 'tip', 'Kyle Rayner', 'The Fear Man\'s job');
  g.waypoint = { x: h.x, y: h.y };
}
function updateKyle(g: Game, dt: number): void {
  const pl = g.player, h = LANTERNS.kyle;
  if (!h) {
    if (SQ.flags.rayner === 1 && inLA() && !SPACE.active) {
      const c = g.world.cities[0];
      if (Math.hypot(pl.x / TS - c.cx, pl.y / TS - c.cy) < 70) spawnKyle(g);
      else if (!LANTERNS.marsSpot && !(g as any).laTold) { (g as any).laTold = 1; g.waypoint = { x: c.cx * TS + 8, y: c.cy * TS + 8 }; g.ui.toast(`Los Angeles. Rayner patrols ${c.name}. Waypoint set.`, 'warn'); }
    }
    return;
  }
  if (h.dead || h.removed) return;
  const d = Math.hypot(h.x - pl.x, h.y - pl.y);
  if (!h.met && d < TS * 7) { h.met = true; g.actors.say(h, 'I know that look. The Fear Man sent you. Go home. Tonight, just go home.'); h.warnT = 5; }
  if (h.met && !h.hostile) { h.warnT -= dt; if (h.warnT <= 0 || h.hp < h.maxHp) { h.hostile = true; g.actors.setFight(h, pl); g.actors.say(h, 'Okay. The hard way. In brightest day...'); g.ui.banner('KYLE RAYNER', 'The last Green Lantern on Earth'); } }
  if (!h.hostile) return;
  if (h.state !== 'fight') g.actors.setFight(h, pl);
  // a shield dome when he's hurt, once
  if (h.hp < h.maxHp * 0.5 && !h.shielded) { h.shielded = 4; g.actors.say(h, 'Not today!'); }
  if (h.shielded > 0) { h.shielded -= dt; if (h.shielded <= 0) h.shielded = -1; }
  h.boltT = (h.boltT || 0) - dt;
  if (h.boltT <= 0 && d < TS * 13) {
    h.boltT = 1.1 + Math.random() * 0.6;
    const big = Math.random() < 0.35;
    bolt(h, pl, '#70f080', big ? 16 : 10, big);
    if (Math.random() < 0.3) g.actors.say(h, ['A hammer!', 'Giant fist, coming up!', 'Wall!', 'Catch!'][Math.floor(Math.random() * 4)]);
  }
}

// ---------------------------------------------------------------- Parallax
function marsSpot(g: Game): { x: number; y: number } | null {
  if (LANTERNS.marsSpot) return LANTERNS.marsSpot;
  const w = g.world, p = w.pad;
  if (!p) return null;
  const free = (x: number, y: number) => !w.cityAt(x, y) && !w.solidPed(x, y) && !w.isWater(x, y);
  const s = w.findNear(p.x + 7, p.y + 4, 50, 90, free) || w.findNear(p.x + 7, p.y + 4, 30, 120, free);
  LANTERNS.marsSpot = s;
  return s;
}
function spawnHal(g: Game, s: { x: number; y: number }): void {
  const h = g.actors.makeHuman(s.x * TS + 8, s.y * TS + 8, { arch: 'tough', tag: 'parallax', cash: 0, look: parallaxLook(g) });
  h.look = parallaxLook(g);
  h.strangerName = 'Parallax'; h.keep = true; h.hp = h.maxHp = 1400; h.tr.brave = 1; h.hal = true; h.stay = true; h.state = 'idle'; h.timer = 1e9; h.hostileLocked = true; h.phase = 0;
  LANTERNS.hal = h;
}
function updateHal(g: Game, dt: number): void {
  const pl = g.player;
  if (!onMars() || SPACE.active || SQ.flags.parallax === 2) return;
  const s = marsSpot(g);
  if (!s) return;
  let h = LANTERNS.hal;
  if (!h) {
    if (Math.hypot(pl.x / TS - s.x, pl.y / TS - s.y) < 34) spawnHal(g, s);
    return;
  }
  if (h.dead || h.removed) return;
  const d = Math.hypot(h.x - pl.x, h.y - pl.y);
  if (!h.hostile && d < TS * 9) {
    h.hostile = true; g.actors.setFight(h, pl);
    g.ui.banner('PARALLAX', 'Hal Jordan, what\'s left of him');
    g.actors.say(h, 'Another one. They keep sending them. They keep being AFRAID.');
    g.cam.shake(3); g.audio.sfx('thunder');
  }
  if (!h.hostile) return;
  if (h.state !== 'fight') g.actors.setFight(h, pl);
  const k = h.hp / h.maxHp;
  const phase = k > 0.6 ? 0 : k > 0.3 ? 1 : 2;
  if (phase !== h.phase) { h.phase = phase; g.actors.say(h, phase === 1 ? 'You think you can FEAR me? I AM fear!' : 'Enough. I\'ll do it myself.'); g.cam.shake(4); }
  h.boltT = (h.boltT || 0) - dt;
  if (h.boltT <= 0) {
    if (phase === 0) { h.boltT = 1.2; const a = Math.atan2(pl.y - h.y, pl.x - h.x); for (const o of [-0.25, 0, 0.25]) bolt(h, pl, '#ffe23c', 12, false, a + o, 190); }
    else if (phase === 1) { h.boltT = 2.2; for (let i = 0; i < 14; i++) bolt(h, pl, i % 2 ? '#ffe23c' : '#70f080', 14, true, (i / 14) * Math.PI * 2 + Math.random() * 0.2, 150); g.cam.shake(2); }
    else {
      // the dash: he's there, then he's HERE, afterimages behind him
      h.boltT = 1.6;
      const a = Math.atan2(pl.y - h.y, pl.x - h.x), jump = Math.min(d - 14, 90);
      for (let i = 0; i < 6; i++) g.fx.add({ x: h.x + Math.cos(a) * jump * (i / 6), y: h.y - 12 + Math.sin(a) * jump * (i / 6), vx: 0, vy: 0, life: 0.4, max: 0.4, c: '#ffe23c', s: 3, glow: 1 });
      h.x += Math.cos(a) * jump; h.y += Math.sin(a) * jump;
      if (Math.hypot(h.x - pl.x, h.y - pl.y) < 20) { pl.hurt(22, h, 'blast'); if (pl.knock) pl.knock(a, 220); g.cam.shake(4); }
      bolt(h, pl, '#ffe23c', 12, false);
    }
  }
}

// ---------------------------------------------------------------- deaths
const C = R.combat as any, kill = C.kill;
C.kill = function (h: any, source: any, kind: string) {
  const was = h && h.dead, r = kill.apply(this, arguments);
  if (was || !h || !h.dead) return r;
  const g = R.game;
  if (h.kyle) {
    LANTERNS.kyle = null; SQ.flags.rayner = 2; saveSequel();
    g.actors.say(h, '...in blackest... night...');
    // the ring won't stay on a dead man's hand, and it won't go to his killer
    LANTERNS.ring = { x: h.x, y: h.y - 10, vx: (Math.random() - 0.5) * 30, vy: -20, t: 0 };
    g.pop.addNews(g.world.cities[0].id, 'THE LAST LANTERN FALLS. Witnesses saw a green light go out over the city, and then a second one rise into the sky and vanish.');
    setTimeout(() => {
      g.ui.story('The ring', `Kyle Rayner doesn't get up.\n\nThe ring slides off his finger on its own. It hangs in the air a moment, as if it's looking at you, and then it goes: straight up, a green streak through the smog, past the clouds, gone.\n\nIt's looking for someone worthy. It didn't even consider you.\n\nThe Fear Man will be pleased. The clamp is coming off.`, () => { if (LANTERNS.release) LANTERNS.release(g); });
    }, 2600);
  }
  if (h.hal) {
    LANTERNS.hal = null; SQ.flags.parallax = 2; saveSequel();
    g.cam.shake(6); g.audio.sfx('boom');
    for (let k = 0; k < 80; k++) g.fx.add({ x: h.x, y: h.y - 12, vx: (Math.random() - 0.5) * 260, vy: (Math.random() - 0.5) * 260, life: 1.4, max: 1.4, c: Math.random() < 0.5 ? '#ffe23c' : '#70f080', s: 2, glow: 1 });
    g.actors.say(h, 'The yellow... it\'s... going. Tell them I\'m sorry. Tell them...');
    const pl = g.player;
    setTimeout(() => {
      giveRingAnyway('green');
      pl.wardrobe = pl.wardrobe || {}; pl.wardrobe['unlock:parallax'] = 1;
      Object.assign(pl.style, { jacket: 'parallax' }); pl.buildLook();
      SQ.achieved = SQ.achieved || {}; SQ.achieved.parallax = 1; saveSequel();
      SQ.flags.fearWeak = 1;
      g.ui.story('Hal Jordan', 'The yellow drains out of him like water out of sand. For a second, at the very end, the man looking up at you is just Hal: the test pilot, the one with the grin.\n\n"Take it," he says, and holds out his hand. "It was never supposed to be his. Or mine."\n\nThe green ring is yours. So is the armour, cracked and still warm, and it fits like it was waiting for you.\n\n(The Parallax Armour: a third less damage from everything. Swap it at any wardrobe.)\n\nFar away, in Coast City, the gold starts to fade, and an old man in a club on the main street feels his ring go cold.');
    }, 1800);
  }
  return r;
};
// the armour: a third off everything that hits you
const ST = R.data.style as any;
ST.jackets.parallax = { name: 'Parallax Armour', price: 0, c: ['#0a2a14', '#14482a', '#2a6a3a', '#e0c030'], fancy: 1, lock: 'parallax' };
const PP = R.Player.prototype as any, hurt = PP.hurt;
PP.hurt = function (this: any, amt: number, ...rest: any[]) { if (this.style && this.style.jacket === 'parallax') amt *= 0.66; return hurt.call(this, amt, ...rest); };
// Kyle's shield soaks everything
const damage = C.damage;
C.damage = function (t: any, amt: number, source: any, kind: string) {
  if (t && t.kyle && t.shielded > 0) { R.game.fx.text(t.x, t.y - 26, 'SHIELD', '#70f080'); return; }
  return damage.apply(this, arguments);
};

// ---------------------------------------------------------------- the loop and the drawing
const GP = R.Game.prototype, tick = GP.tick;
GP.tick = function (this: Game, dt: number) {
  const r = tick.call(this, dt);
  if (!this.player || !this.world || this.ui.paused() || SPACE.active) return r;
  // a new sector or planet is a new world: forget actors left behind in the old one
  if (LANTERNS.kyle && !this.actors.list.includes(LANTERNS.kyle)) LANTERNS.kyle = null;
  if (LANTERNS.hal && !this.actors.list.includes(LANTERNS.hal)) LANTERNS.hal = null;
  if (LANTERNS.marsSpot && !onMars()) LANTERNS.marsSpot = null;
  updateKyle(this, dt); updateHal(this, dt); stepBolts(this, dt);
  const rg = LANTERNS.ring;
  if (rg) {
    rg.t += dt; rg.vy -= 260 * dt * Math.min(1, rg.t); rg.x += rg.vx * dt; rg.y += rg.vy * dt;
    if (Math.random() < 0.8) this.fx.add({ x: rg.x, y: rg.y, vx: (Math.random() - 0.5) * 20, vy: 20, life: 0.6, max: 0.6, c: '#70f080', s: 2, glow: 1 });
    if (rg.t > 4) LANTERNS.ring = null;
  }
  return r;
};
const ring = (R as any).ring, draw = ring.draw;
ring.draw = function (gx: CanvasRenderingContext2D) {
  draw.apply(this, arguments);
  const k = LANTERNS.kyle, h = LANTERNS.hal, t = performance.now() / 1000;
  if (k && !k.dead) { aura(gx, k, 'rgba(112,240,128,A)', 22); if (k.shielded > 0) { gx.strokeStyle = `rgba(112,240,128,${0.5 + Math.sin(t * 12) * 0.2})`; gx.lineWidth = 2; gx.beginPath(); gx.arc(k.x, k.y - 12, 18, 0, 7); gx.stroke(); gx.lineWidth = 1; } hpBar(gx, k, 'KYLE RAYNER', '#70f080'); }
  if (h && !h.dead) { aura(gx, h, 'rgba(255,226,60,A)', h.phase === 2 ? 34 : 26); hpBar(gx, h, 'PARALLAX', '#ffe23c'); }
  for (const b of LANTERNS.bolts) {
    gx.fillStyle = b.col; gx.globalAlpha = 0.35; gx.beginPath(); gx.arc(b.x, b.y, b.big ? 7 : 4, 0, 7); gx.fill(); gx.globalAlpha = 1;
    if (b.big) { gx.fillRect(b.x - 4, b.y - 4, 8, 7); gx.fillRect(b.x - 6, b.y - 2, 3, 4); } else gx.fillRect(b.x - 2, b.y - 2, 4, 4);
  }
  const rg = LANTERNS.ring;
  if (rg) { gx.fillStyle = 'rgba(112,240,128,0.4)'; gx.beginPath(); gx.arc(rg.x, rg.y, 6, 0, 7); gx.fill(); gx.strokeStyle = '#c8ffd0'; gx.lineWidth = 2; gx.beginPath(); gx.arc(rg.x, rg.y, 3, 0, 7); gx.stroke(); gx.lineWidth = 1; }
  // the Martian site: burned-out claim camp, scorched in a ring
  const s = LANTERNS.marsSpot, w = R.game && R.game.world;
  if (s && onMars() && SQ.flags.parallax !== 2 && w) { const x = s.x * TS + 8, y = s.y * TS + 8; gx.strokeStyle = 'rgba(40,20,10,0.5)'; gx.lineWidth = 3; gx.beginPath(); gx.ellipse(x, y, 60, 30, 0, 0, 7); gx.stroke(); gx.lineWidth = 1; }
};
// Mars: the first time you land, the rumour
HOOKS.landed.push((g, id) => {
  if (id !== 'mars' || SQ.home !== 'sol' || SQ.flags.parallax) return;
  SQ.flags.parallax = 1; saveSequel();
  setTimeout(() => {
    const s = marsSpot(g);
    if (s) { g.waypoint = { x: s.x * TS + 8, y: s.y * TS + 8 }; if ((R as any).poi) (R as any).poi.add(s.x, s.y, 'tip', 'Burned claim camp', 'Something in green armour'); }
    g.ui.story('Mars', 'The claim office is half empty. The clerk won\'t look up.\n\n"Out past the ridge. A man in green armour, hair white as bone. He glows yellow when he\'s angry, and he\'s always angry. He burned out the Kessler camp last week. Nobody went back for the bodies."\n\n"Some of the old-timers say he used to be a hero."\n\n(Waypoint set.)');
  }, 900);
});

(window as any).BS2 = Object.assign((window as any).BS2 || {}, { LANTERNS, giveRaynerJob: () => giveRaynerJob(R.game), spawnKyle: () => spawnKyle(R.game), spawnHal: () => { const s = marsSpot(R.game) || { x: (R.game.player.x / TS) | 0, y: ((R.game.player.y / TS) | 0) + 4 }; spawnHal(R.game, s); } });
