// Street races, Streets of Fire style. Any Hover Garage (or cantina) has a promoter: put up
// the buy-in and he lends you a Stallion Thruster GT outside, lights up a route through the
// city (neon gates, and your route line), and sets the time to beat: Raven's. Hit every gate
// in order and beat Raven's time for the pot. Bail out of the car for long and it's a DNF.

import { SQ, saveSequel } from './state';
import { fmt } from './bounty';

const TS = R.TILE, D = R.data;
interface Race { gates: { x: number; y: number }[]; i: number; t: number; par: number; pot: number; out: number; car: any }
let race: Race | null = null;
export const raceState = () => race;

function route(g: Game, n: number): { x: number; y: number }[] | null {
  const w = g.world, pl = g.player, pts: { x: number; y: number }[] = [];
  let cx = pl.x / TS, cy = pl.y / TS;
  for (let k = 0; k < n; k++) {
    let best: { x: number; y: number } | null = null;
    for (let tries = 0; tries < 120 && !best; tries++) {
      const a = Math.random() * Math.PI * 2, r = 22 + Math.random() * 20;
      const x = Math.round(cx + Math.cos(a) * r), y = Math.round(cy + Math.sin(a) * r);
      if (!w.inb(x, y) || !D.roadTile[w.t(x, y)]) continue;
      if (pts.some((p) => Math.hypot(p.x - x, p.y - y) < 14)) continue;
      best = { x, y };
    }
    if (!best) return null;
    pts.push(best); cx = best.x; cy = best.y;
  }
  return pts;
}
export function startRace(g: Game, buyIn = 200): boolean {
  const pl = g.player;
  if (race) { g.ui.toast('You\'re already racing.'); return false; }
  if (pl.cash < buyIn) { g.ui.toast(`The buy-in is ${fmt(buyIn)}.`, 'warn'); return false; }
  if (pl.room && g.interiors.exit) g.interiors.exit();
  g.ui.closeSheet();
  const gates = route(g, 6);
  if (!gates) { g.ui.toast('No roads here worth racing on.', 'warn'); return false; }
  pl.cash -= buyIn;
  let car: any = pl.inCar;
  if (!car) {
    car = g.traffic.make('muscle', pl.x + 26, pl.y, 0, { parked: true, keep: true, locked: false });
    car.owner = 'player';
    pl.enterCar(car);
  }
  let len = Math.hypot(gates[0].x - pl.x / TS, gates[0].y - pl.y / TS);
  for (let k = 1; k < gates.length; k++) len += Math.hypot(gates[k].x - gates[k - 1].x, gates[k].y - gates[k - 1].y);
  race = { gates, i: 0, t: 0, par: Math.round(len * 0.11 + 6), pot: buyIn * 4, out: 0, car };
  g.waypoint = { x: gates[0].x * TS + 8, y: gates[0].y * TS + 8 };
  g.audio.sfx('boom');
  g.ui.banner('STREET RACE', `Six gates. Raven's time: ${race.par}s. The pot: ${fmt(race.pot)}.`);
  return true;
}
function finish(g: Game, won: boolean, why: string): void {
  const r = race!;
  race = null; g.waypoint = null;
  if (won) {
    g.player.cash += r.pot; saveSequel();
    SQ.achieved = SQ.achieved || {}; SQ.achieved.races = (SQ.achieved.races || 0) + 1;
    g.audio.sfx('cash');
    g.ui.story('You beat Raven', `${r.t.toFixed(1)} seconds. Raven's time was ${r.par}. The crowd at the garage goes crazy and the promoter counts ${fmt(r.pot)} into your hand like it hurts.`);
  } else g.ui.toast(why, 'bad');
}
const GP = R.Game.prototype, baseTick = GP.tick;
GP.tick = function (this: Game, dt: number) {
  const res = baseTick.call(this, dt);
  if (!race || !this.player || this.ui.paused()) return res;
  const pl = this.player, r = race, gt = r.gates[r.i];
  r.t += dt;
  if (!pl.inCar) { r.out += dt; if (r.out > 8) finish(this, false, 'You left the car. DNF.'); return res; }
  r.out = 0;
  if (Math.hypot(pl.x / TS - gt.x, pl.y / TS - gt.y) < 4) {
    r.i++; this.audio.sfx('click');
    if (r.i >= r.gates.length) finish(this, r.t <= r.par, `${r.t.toFixed(1)}s. Raven did it in ${r.par}. You lose the buy-in.`);
    else { const n = r.gates[r.i]; this.waypoint = { x: n.x * TS + 8, y: n.y * TS + 8 }; this.fx.text(pl.x, pl.y - 30, `GATE ${r.i}/${r.gates.length}  ${r.t.toFixed(1)}s`, '#3af0ff'); }
  }
  if (race && r.t > r.par * 2.5) finish(this, false, 'Raven\'s long gone. You lose the buy-in.');
  return res;
};
// the gates: neon arches on the road, the next one bright
const baseDraw = R.ring.draw;
R.ring.draw = function (this: unknown, g: CanvasRenderingContext2D) {
  baseDraw.call(this, g);
  if (!race) return;
  const t = performance.now() / 1000;
  race.gates.forEach((gt, k) => {
    if (k < race!.i) return;
    const x = gt.x * TS + 8, y = gt.y * TS + 8, next = k === race!.i;
    g.strokeStyle = next ? (Math.floor(t * 6) % 2 ? '#3af0ff' : '#ff3a7a') : 'rgba(255,58,122,0.45)'; g.lineWidth = next ? 3 : 2;
    g.beginPath(); g.arc(x, y - 6, next ? 22 : 16, Math.PI, 0); g.stroke();
    R.art.ptext(g, String(k + 1), Math.round(x), Math.round(y - 34), { align: 'center', scale: 1, color: next ? '#3af0ff' : '#ff3a7a', shadow: '#07051a' });
  });
  const pl = R.game.player, m = g.getTransform();
  R.art.ptext(g, `RACE ${race.t.toFixed(1)}s / RAVEN ${race.par}s · GATE ${race.i + 1}/${race.gates.length}`, Math.round(-m.e / m.a + g.canvas.width / m.a / 2), Math.round(-m.f / m.d + 62), { align: 'center', scale: 1, color: race.t > race.par ? '#ff5a5a' : '#68f0a0', shadow: '#07051a' });
  void pl;
};
// the promoter
const U = (R as any).UI.prototype, baseOpts = U.interiorOptions;
U.interiorOptions = function (this: any, b: any) {
  const opts = baseOpts.call(this, b);
  if (b && (b.type === 'garage' || b.type === 'bar')) opts.push({ label: 'Street race (the promoter)', price: '$200', small: 'Beat Raven\'s time through six gates. The pot is $800.', fn: () => startRace(this.game, 200) });
  return opts;
};

(window as any).BS2 = Object.assign((window as any).BS2 || {}, { startRace: (b?: number) => startRace(R.game, b), raceState });
