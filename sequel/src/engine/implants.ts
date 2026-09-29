// Chrome. The Chrome Clinics (game 1's pharmacies) put machines in you: pay, lie back, and
// wake up faster, harder and a little less human. Bring in implants you've ripped out of
// cyborgs and the clinic knocks $1,000 off per implant, no questions asked.
//   Reflex Wiring: you run 15% faster.        Dermal Plating: you take 25% less damage.
//   Titan Arm: everything you hold hits 40% harder.  Heart Pump: you heal slowly, always.

import { SQ, saveSequel } from './state';

export const IMPLANTS: Record<string, { name: string; price: number; blurb: string }> = {
  reflex: { name: 'Reflex Wiring', price: 2500, blurb: 'Run 15% faster' },
  dermal: { name: 'Dermal Plating', price: 4000, blurb: 'Take 25% less damage' },
  arm: { name: 'Titan Arm', price: 6000, blurb: 'Everything you hold hits 40% harder' },
  heart: { name: 'Heart Pump', price: 3500, blurb: 'Heal slowly, all the time' },
};
const has = (k: string) => !!(SQ.implants && SQ.implants[k]);
export const installed = () => Object.keys(IMPLANTS).filter(has);

// the effects
const Goods = (R as any).goods, baseMod = Goods.mod;
Goods.mod = function (this: unknown, pl: any, key: string, base: number) {
  let v = baseMod.call(this, pl, key, base);
  if (pl === (R.game && R.game.player)) {
    if (key === 'speed' && has('reflex')) v *= 1.15;
    if (key === 'power' && has('arm')) v *= 1.4;
  }
  return v;
};
const PP = R.Player.prototype, baseHurt = PP.hurt;
PP.hurt = function (this: any, amt: number, src: any, kind: string) { return baseHurt.call(this, has('dermal') ? amt * 0.75 : amt, src, kind); };
let pumpT = 0;
const GP = R.Game.prototype, baseTick = GP.tick;
GP.tick = function (this: Game, dt: number) {
  const r = baseTick.call(this, dt);
  if (has('heart') && this.player && !this.player.dead) { pumpT -= dt; if (pumpT <= 0) { pumpT = 3; if (this.player.hp < this.player.maxHp) this.player.hp = Math.min(this.player.maxHp, this.player.hp + 1); } }
  return r;
};

// the clinic
export function install(g: Game, k: string): boolean {
  const pl = g.player, I = IMPLANTS[k];
  if (has(k)) { g.ui.toast(`You already have ${I.name}.`); return false; }
  const trade = Math.min(pl.inv.loot.implant || 0, Math.floor(I.price / 1000));
  const cost = I.price - trade * 1000;
  if (pl.cash < cost) { g.ui.toast(`${I.name} is ${'$' + cost}${trade ? ` after your trade-ins` : ''}. You're short.`, 'warn'); return false; }
  pl.cash -= cost; if (trade) pl.inv.loot.implant -= trade;
  SQ.implants = SQ.implants || {}; SQ.implants[k] = 1; saveSequel();
  pl.cool = Math.max(0, pl.cool - 10);
  g.audio.sfx('zap');
  g.ui.toast(`${I.name} installed. ${I.blurb}. You wake up tasting copper.`, 'good');
  return true;
}
const U = (R as any).UI.prototype, baseOpts = U.interiorOptions;
U.interiorOptions = function (this: any, b: any) {
  const opts = baseOpts.call(this, b);
  if (b && b.type === 'pharmacy') {
    const g = this.game, trade = g.player.inv.loot.implant || 0;
    for (const k of Object.keys(IMPLANTS)) {
      const I = IMPLANTS[k];
      opts.push({ label: has(k) ? `${I.name} (installed)` : `Install ${I.name}`, price: has(k) ? undefined : '$' + Math.max(0, I.price - Math.min(trade, Math.floor(I.price / 1000)) * 1000), small: I.blurb + (trade && !has(k) ? ` · ${trade} ripped implant(s) traded in` : ''), fn: () => install(g, k) });
    }
  }
  return opts;
};

(window as any).BS2 = Object.assign((window as any).BS2 || {}, { IMPLANTS, install: (k: string) => install(R.game, k), implants: installed });
