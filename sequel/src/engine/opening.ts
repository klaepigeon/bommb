// The opening, told in scenes like game 1's (the letterbox, captions, the world playing it
// out), not a page of text.
//   1. Earth, near midnight, acid rain. The camera drifts down a street: hover cars, neon, a
//      curfew drone's searchlight sweeping the pavement.
//   2. Over the plaza a hologram flickers up forty feet tall: the Fear Man, old now, magenta
//      and gold, telling Earth to work, pay and sleep. He loses his thread halfway through.
//   3. Pad 3. Control asks who's coming down. You tell them, and the ship lands.
//   4. Two Syndicate men and a clamp robot are waiting. The clamp goes on. Twelve hundred
//      credits, or one job for the old man.

import { SQ, saveSequel } from './state';
import { fearLook } from './aliens';
import { landShip, LAND, clampSpot } from './landing';
import { CURFEW } from './curfew';

const TS = R.TILE;
const OPN = { holo: null as null | { x: number; y: number; t: number; look: any; alpha: number }, active: false, stage: '' };
const op = () => (R as any).opening;
const wait = (s: number) => op().wait(s);
const say = (who: any, text: string, name?: string) => op().say(who, text, name);

function walkTo(g: Game, h: any, x: number, y: number, speed = 40, max = 5): Promise<void> {
  return (async () => {
    for (let k = 0; k < max * 20 && h && !h.dead && Math.hypot(h.x - x, h.y - y) > 6; k++) {
      const d = Math.hypot(x - h.x, y - h.y);
      g.actors.moveActor(h, ((x - h.x) / d) * speed, ((y - h.y) / d) * speed, 0.05);
      h.state = 'idle'; h.timer = 1e9;
      await wait(0.05);
    }
  })();
}
// the camera rides on the (hidden) player: glide it somewhere
async function glide(g: Game, x: number, y: number, secs: number): Promise<void> {
  const pl = g.player, x0 = pl.x, y0 = pl.y, n = Math.max(1, Math.round(secs * 20));
  for (let i = 1; i <= n; i++) { const k = i / n, e = k * k * (3 - 2 * k); pl.x = x0 + (x - x0) * e; pl.y = y0 + (y - y0) * e; await wait(0.05); }
}
function cast(g: Game, x: number, y: number, opts: any, name: string): any {
  const h = g.actors.makeHuman(x, y, Object.assign({ arch: 'tough', cash: 20 }, opts));
  h.keep = true; h.scripted = true; h.stay = true; h.state = 'idle'; h.timer = 1e9; h.hostile = false; h.strangerName = name;
  return h;
}

export async function runOpening(g: Game, then: () => void): Promise<void> {
  const O = op(), pl = g.player, w = g.world, p = w.pad;
  if (!O || !p) { then(); return; }
  OPN.active = true;
  // game 1's "a scene is playing" flag: no muggers, no hints, no stray trouble mid-shot. It
  // also clears the roads (its desert highway wants them empty); ours wants the traffic
  O.active = true;
  const tr = g.traffic as any, manage = Object.getPrototypeOf(tr).manage;
  tr.manage = function (this: any) { O.active = false; try { return manage.apply(this, arguments); } finally { O.active = OPN.active; } };
  O.lock = { x: 0, y: 0 };
  pl.hidden = true;
  const day = Math.floor(g.clock.t / 1440);
  g.clock.t = day * 1440 + 23 * 60 + 5;
  g.env.setWeather('rain');
  O.cine(true);
  O.cineEl().querySelector('.cf').classList.add('black');
  OPN.stage = 'street';
  // ---------------------------------------------------------------- 1. the street
  const street = w.findNear(p.x + 7, p.y + 4, 16, 40, (x: number, y: number) => !!w.cityAt(x, y) && !!R.data.roadTile[w.t(x, y)] && !!R.data.roadTile[w.t(x + 1, y)] && !!R.data.roadTile[w.t(x - 1, y)])
    || w.findNear(p.x + 7, p.y + 4, 10, 60, (x: number, y: number) => !!R.data.roadTile[w.t(x, y)]) || { x: p.x + 7, y: p.y + 20 };
  const sx = street.x * TS + 8, sy = street.y * TS + 8;
  pl.place(sx - 90, sy); g.cam.x = pl.x; g.cam.y = pl.y;
  CURFEW.script = true;
  const drone = { x: sx + 140, y: sy - 10, hp: 30, seen: 0, lost: 0, dead: 0, checked: false };
  CURFEW.drones.push(drone);
  await wait(0.4);
  O.fade(false);
  O.caption('Earth · the year XX8X');
  const pan = glide(g, sx + 60, sy, 7);
  // the drone's searchlight sweeps across the street, the other way
  (async () => { for (let i = 0; i < 140 && OPN.active; i++) { drone.x -= 2.1; drone.y = sy - 10 + Math.sin(i / 9) * 14; if (i === 60) drone.seen = 1.5; if (i === 80) drone.seen = 0; await wait(0.05); } })();
  await wait(3.2);
  O.caption('Ten years since the Brass\u00A0Coast.'); // (a plain space would be renamed "Earth" by the text layer)
  await pan;
  O.caption('');
  OPN.stage = 'holo';
  // ---------------------------------------------------------------- 2. the Fear Man, forty feet tall
  const look = (() => { const l = R.lookFromStyle(R.styleDefault(), false); fearLook(l); return l; })();
  OPN.holo = { x: pl.x + 40, y: pl.y + 20, t: 0, look, alpha: 0 };
  g.audio.sfx('alarm');
  await glide(g, pl.x + 20, pl.y - 20, 1.5);
  await say(null, 'Citizens of Earth.', 'THE FEAR MAN');
  await say(null, 'Fear is order. Order is peace. The tithe is due on the first.', 'THE FEAR MAN');
  await say(null, 'Work. Pay. Sleep. And... and...', 'THE FEAR MAN');
  await wait(0.8);
  await say(null, '...what was I saying. Hm. Yes. Obey.', 'THE FEAR MAN');
  O.caption('The old families are dust. He owns the underworld now. All of it.');
  await wait(3.4);
  O.caption('');
  await O.fade(true);
  OPN.holo = null;
  CURFEW.drones.splice(CURFEW.drones.indexOf(drone), 1);
  OPN.stage = 'pad';
  // ---------------------------------------------------------------- 3. Pad 3
  pl.place(p.sx, p.sy + 50); g.cam.x = pl.x; g.cam.y = pl.y - 30;
  const clamp = SQ.flags.clamp;
  await wait(0.3);
  O.fade(false);
  O.caption('Pad 3 · 23:40');
  await say(null, 'Pad Three control. Inbound vessel on final, identify yourself.', 'PAD CONTROL');
  O.caption('');
  OPN.stage = 'name';
  await new Promise<void>((res) => O.nameSheet(g, res, '"Pad Three control. Identify yourself."'));
  await say(null, `${pl.first} ${pl.last}. The ${SQ.ship.name}. Coming down.`, (pl.first || 'YOU').toUpperCase());
  await say(null, `...${pl.first} ${pl.last}. Copy. Somebody's been waiting for you.`, 'PAD CONTROL');
  OPN.stage = 'landing';
  await new Promise<void>((res) => landShip(g, res));
  // stay by the ship for this one (no stroll down the apron): the camera keeps it in frame
  LAND.walk = 0; O.lock = { x: 0, y: 0 };
  await wait(1.0);
  OPN.stage = 'welcome';
  // ---------------------------------------------------------------- 4. the welcome
  // on the apron: the men come in from either side of the pad, the robot trundles up behind
  const ex = pl.x, ey = pl.y, left = p.x * TS + 14, right = (p.x + p.w) * TS - 14;
  const a = cast(g, left, ey - 4, { weapon: 'revolver' }, 'Syndicate Man'), b = cast(g, right, ey + 2, { weapon: 'shotgun' }, 'Syndicate Man');
  const bot = cast(g, left + 10, ey - 30, { arch: 'square' }, 'Clamp Unit');
  bot.look = Object.assign({}, bot.look, { xeno: 'robot', xenoSeed: 7, xenoAccent: '#ff3030', xenoSkin: '#8a8a98', skin: '#8a8a98', hair: '#8a8a98', seedStr: 'xeno-robot-clamp', hat: null, oldOverride: { skin: ['#4a4a58', '#6a6a78', '#8a8a98', '#b8b8c8'], style: 'bald', stache: false, glasses: false }, old: null });
  await Promise.all([walkTo(g, a, ex - 22, ey - 2, 44, 6), walkTo(g, b, ex + 22, ey + 2, 44, 6)]);
  pl.dir = 0;
  await say(a, `Welcome home, ${pl.first}.`);
  await say(b, 'Mr. Fear heard you were coming back. He sent a present.');
  // the clamp robot rolls to the landing leg and bolts it on
  const leg = clampSpot() || { x: p.sx + 24, y: p.sy + 16 };
  leg.y += 6;
  await walkTo(g, bot, leg.x, leg.y, 34, 4);
  SQ.flags.clamp = 0; // hidden until it's on
  for (let k = 0; k < 3; k++) { g.fx.sparks(leg.x, leg.y - 4, 6); g.audio.sfx('clank'); await wait(0.35); }
  SQ.flags.clamp = clamp || 1; saveSequel();
  await say(bot, 'CLAMP. ENGAGED. HAVE A PRODUCTIVE EVENING, CITIZEN.');
  await say(a, 'Twelve hundred credits and it comes off.');
  await say(b, 'Or you do the old man one job. There\'s a Green Lantern in Los Angeles he\'d like dead.');
  OPN.stage = 'ask';
  await O.ask('The Syndicate\'s welcome', [
    { label: '"Tell Mr. Fear I said hello."', small: 'Infamy +1', fn: () => { pl.rep.infamy = (pl.rep.infamy || 0) + 1; } },
    { label: '"Twelve hundred? For a clamp?"', small: 'Haggle', fn: () => {} },
    { label: 'Say nothing. Look at the clamp.', small: 'Remember their faces', fn: () => {} },
  ]);
  await say(a, 'He remembers you, you know. On his good days.');
  await say(b, 'Job\'s on your map. Don\'t make us come find you.');
  OPN.stage = 'exit';
  await Promise.all([walkTo(g, a, left, ey, 45, 3), walkTo(g, b, right, ey, 45, 3), walkTo(g, bot, left + 10, ey - 30, 34, 3)]);
  OPN.stage = 'fade';
  await O.fade(true);
  for (const h of [a, b, bot]) g.actors.remove(h);
  pl.hidden = false; pl.place(p.sx - 40, p.sy + 44); pl.dir = 2;
  O.cine(false);
  O.lock = null;
  OPN.active = false;
  O.active = false;
  delete tr.manage;
  CURFEW.script = false;
  // whatever the night got up to while the cameras were rolling, it wasn't you
  if ((g.law as any).incident) (g.law as any).incident = null;
  O.fade(false);
  then();
}

// ---------------------------------------------------------------- the hologram
const holoCv = document.createElement('canvas'); holoCv.width = 48; holoCv.height = 48;
const ring = (R as any).ring, draw = ring.draw;
ring.draw = function (gx: CanvasRenderingContext2D) {
  draw.apply(this, arguments);
  const h = OPN.holo;
  if (!h) return;
  const t = performance.now() / 1000;
  h.alpha = Math.min(1, h.alpha + 0.02);
  // the figure, drawn small, then scanlined and tinted
  const c = holoCv.getContext('2d')!;
  c.clearRect(0, 0, 48, 48);
  R.art.drawPerson(c, 24, 42, 0, 0, h.look, { ang: Math.PI / 2 });
  c.globalCompositeOperation = 'source-atop';
  c.fillStyle = 'rgba(255,80,200,0.35)'; c.fillRect(0, 0, 48, 48);
  c.globalCompositeOperation = 'destination-out';
  for (let y = (Math.floor(t * 20) % 3); y < 48; y += 3) c.fillRect(0, y, 48, 1);
  c.globalCompositeOperation = 'source-over';
  const S = 3, glitch = Math.random() < 0.06 ? (Math.random() - 0.5) * 6 : 0;
  // the projector on the ground and its beam
  gx.fillStyle = '#2a2a34'; gx.fillRect(h.x - 5, h.y - 2, 10, 4); gx.fillStyle = '#ff5ad0'; gx.fillRect(h.x - 1, h.y - 3, 2, 1);
  const beam = gx.createLinearGradient(h.x, h.y, h.x, h.y - 48 * S);
  beam.addColorStop(0, 'rgba(255,90,210,0.28)'); beam.addColorStop(1, 'rgba(255,90,210,0)');
  gx.fillStyle = beam; gx.beginPath(); gx.moveTo(h.x - 2, h.y - 2); gx.lineTo(h.x - 30, h.y - 42 * S); gx.lineTo(h.x + 30, h.y - 42 * S); gx.lineTo(h.x + 2, h.y - 2); gx.fill();
  gx.save();
  gx.globalAlpha = h.alpha * (0.62 + Math.sin(t * 13) * 0.08 + (Math.random() < 0.04 ? -0.3 : 0));
  gx.imageSmoothingEnabled = false;
  gx.drawImage(holoCv, Math.round(h.x - 24 * S + glitch), Math.round(h.y - 44 * S), 48 * S, 48 * S);
  gx.restore();
};

(window as any).BS2 = Object.assign((window as any).BS2 || {}, { runOpening: (then?: () => void) => runOpening(R.game, then || (() => {})), OPN });

// street trouble waits until the credits are done
const EV = (R as any).events, evRandom = EV.random;
EV.random = function (this: any) { if (OPN.active) return; return evRandom.apply(this, arguments); };
// (and a mugger who walks up on his own can try his luck another night)
const evMug = EV.mugging;
EV.mugging = function (this: any, m: any) { if (OPN.active) { if (m) { m.state = 'wander'; m.onReach = null; } return; } return evMug.apply(this, arguments); };
