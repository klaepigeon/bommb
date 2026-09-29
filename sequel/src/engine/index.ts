// RHAPSODY XX8X: the sequel layer. Game 1's engine is loaded first (every system,
// unchanged); this file runs after it, before the game boots, and adds the sequel on top:
// planets, travel, space, ships, piracy, the Ship Watch and the Gen 4 look.

import { SQ, resetSequel, saveSequel } from './state';
import { enterSystem } from './galaxy';
import { current, nearShip, SHIP_MENU } from './travel';
import { launch, resumeSpace, SPACE, nearPlanet } from './space';
import { openWatch, installWatch } from './watch';
import './board';
import './gen4';
import './older';
import './aliens';
import './eco';
import './stations';
import './bounty';

const GP = R.Game.prototype;

// ---------------------------------------------------------------- new game and the opening
const baseNew = GP.newGame;
GP.newGame = function (this: Game) {
  resetSequel();
  enterSystem('sol');
  return baseNew.call(this);
};
GP.intro = function (this: Game) {
  const pl = this.player, p = current();
  const c0 = p.cities ? p.cities[0] : { name: R.data.cities[0].name, family: 'Vane', don: 'Gus Vane' };
  pl.stats.startT = this.clock.t;
  this.ui.story(`${p.name}, year XX8X`, `Ten years since the Brass\u00A0Coast. Ten years of greying at the temples, of jobs nobody talks about, of that Sinestro Corps uniform folded at the bottom of a duffel bag.\n\nNow you've got a scrappy skiff called the ${SQ.ship.name}, a few hundred credits, and a solar system that went and got itself an Empire while you weren't looking.\n\n${c0.name} is ${c0.family} country. ${c0.don} runs the pads, the cards and the Imperial Security payroll, and word is they're hiring.\n\nYour ship is on Pad 3, right behind you. Walk up to it to launch, refit or trade cargo. Earth is out there too.`, () => {
    const offers = this.jobs.offersFor(pl.family);
    const first = offers.find((o: { kind: string }) => o.kind === 'collect') || offers[0];
    if (first) { this.jobs.accept(first); this.jobs.offers[pl.family] = offers.filter((o: unknown) => o !== first); }
    this.ui.toast(`Your first job for the ${c0.family} family is marked in gold. Your ship waits on Pad 3.`, 'good');
    this.save();
  });
};

// resume in space if that's where you saved
const baseStart = GP.start;
GP.start = function (this: Game, fresh: boolean) {
  const r = baseStart.call(this, fresh);
  if (!fresh && SQ.mode === 'space') resumeSpace(this);
  installWatch(this);
  return r;
};

// ---------------------------------------------------------------- your ship on the pad
const PP = R.Player.prototype, baseCtx = PP.contextAction;
PP.contextAction = function (this: Player) {
  if (nearShip(this)) return { label: SQ.ship.name, fn: () => shipMenu(R.game) };
  return baseCtx.call(this);
};
function shipMenu(g: Game): void {
  g.ui.choice(SQ.ship.name, [
    { label: 'Launch', small: 'Into orbit. The planet waits for you.', fn: () => launch(g) },
    { label: 'Refit the ship', small: 'Modules, hulls and paint', fn: () => openWatch(g, 'ship') },
    { label: 'Cargo and trade', small: `Prices on ${current().name}`, fn: () => openWatch(g, 'cargo') },
    ...SHIP_MENU.map((f) => f(g)).filter((o): o is NonNullable<typeof o> => !!o),
    { label: 'Save', fn: () => { g.save(); saveSequel(); g.ui.toast('Saved.', 'good'); } },
    { label: 'Not now', fn: () => {} },
  ]);
}

// ---------------------------------------------------------------- the title screen
const RP = R.Renderer.prototype;
RP.renderTitle = function (this: { g: CanvasRenderingContext2D; cv: HTMLCanvasElement; present(): void }, t: number) {
  const g = this.g, W = this.cv.width, H = this.cv.height, A = R.art;
  g.setTransform(1, 0, 0, 1, 0, 0);
  g.imageSmoothingEnabled = false;
  g.fillStyle = '#070718'; g.fillRect(0, 0, W, H);
  const neb = g.createRadialGradient(W * 0.3, H * 0.45, 10, W * 0.3, H * 0.45, W * 0.8);
  neb.addColorStop(0, 'rgba(110,50,140,0.5)'); neb.addColorStop(1, 'rgba(10,10,40,0)');
  g.fillStyle = neb; g.fillRect(0, 0, W, H);
  for (let k = 0; k < 220; k++) {
    const x = (R.hash2(k, 1, 3) * W + t * (6 + R.hash2(k, 2, 3) * 30)) % W, y = R.hash2(k, 3, 3) * H;
    g.fillStyle = R.hash2(k, 4, 3) < 0.15 ? '#ffe8a0' : '#d8d8f0'; g.fillRect(Math.floor(x), Math.floor(y), R.hash2(k, 5, 3) < 0.2 ? 2 : 1, 1);
  }
  // a planet on the horizon and the ship crossing it
  g.fillStyle = '#2a6a3a'; g.beginPath(); g.arc(W * 0.78, H * 1.15, H * 0.62, 0, 7); g.fill();
  g.fillStyle = '#58b458'; g.beginPath(); g.arc(W * 0.78 - 6, H * 1.15 - 6, H * 0.6, Math.PI * 1.05, Math.PI * 1.75); g.fill();
  A.ptext(g, 'RHAPSODY', W / 2 + 4, 52 + 4, { align: 'center', scale: 5, color: '#2a1a12' });
  A.ptext(g, 'RHAPSODY', W / 2 + 2, 52 + 2, { align: 'center', scale: 5, color: '#c83a2a' });
  A.ptext(g, 'RHAPSODY', W / 2, 52, { align: 'center', scale: 5, color: '#f0b838' });
  A.ptext(g, 'XX8X', W / 2, 108, { align: 'center', scale: 3, color: '#ff5ad0', shadow: '#2a1a12' });
  A.ptext(g, 'TEN YEARS LATER · THE SOLAR SYSTEM', W / 2, 140, { align: 'center', scale: 1, color: '#b8a8d8' });
  this.present();
};

// for tests and debugging
const w = window as unknown as { BS2: Record<string, unknown> };
w.BS2 = Object.assign(w.BS2 || {}, { SQ, SPACE, launch, nearPlanetId: () => nearPlanet()?.id });
