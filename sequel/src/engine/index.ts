// RHAPSODY XX8X: the sequel layer. Game 1's engine is loaded first (every system,
// unchanged); this file runs after it, before the game boots, and adds the sequel on top:
// planets, travel, space, ships, piracy, the Ship Watch and the Gen 4 look.

import { SQ, resetSequel, saveSequel } from './state';
import { enterSystem } from './galaxy';
import { current, nearShip, SHIP_MENU, shipHere, travelTo } from './travel';
import { launch, resumeSpace, SPACE, nearPlanet, spawnCraft, HOOKS, navTargets, autopilot } from './space';
import { openWatch, installWatch } from './watch';
import { shipSprites, npcShip, stats } from '../ship/ship';
import './board';
import './gen4';
import './older';
import './outfit';
import './aliens';
import './eco';
import './stations';
import './bounty';
import './earthplay';
import './dystopia';
import './earthlook';
import { WEAPONS } from './weapons';
import { waypointToShip } from './shipmark';
import { markFearMan } from './fearboss';
import { takeOff } from './ringfly';
import './debug';
import './colony';

const GP = R.Game.prototype;

// ---------------------------------------------------------------- new game and the opening
const baseNew = GP.newGame;
GP.newGame = function (this: Game) {
  resetSequel();
  enterSystem('sol');
  return baseNew.call(this);
};
GP.intro = function (this: Game) {
  const pl = this.player;
  pl.stats.startT = this.clock.t;
  pl.cash = Math.max(pl.cash, 600);
  this.ui.story('Earth, year XX8X', `Ten years since the Brass\u00A0Coast. The old mob is finished. The Fear Man, the magenta alien from the dead tree in the desert, came down out of the dark and took the whole underworld of Earth, and your old outfit came with it. He's old now, and his mind wanders, but his ring still glows and everybody still pays.\n\nYou've got 600 credits and a ship, the ${SQ.ship.name}, on Pad 3. His people put a clamp on it.\n\nPay the Fear Man 1,200, or do him one job. Then get off this rock. Or stay, and take his ring off his finger.`, () => {
    const offers = this.jobs.offersFor(pl.family);
    const first = offers.find((o: { kind: string }) => o.kind === 'collect') || offers[0];
    if (first) { this.jobs.accept(first); this.jobs.offers[pl.family] = offers.filter((o: unknown) => o !== first); }
    this.ui.toast('The Fear Man\'s job is marked in gold. Jobs pay triple now. Your ship waits on Pad 3.', 'good');
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
    SQ.flags.clamp ? { label: 'Launch (clamped)', small: 'The Fear Man\'s clamp is on the landing gear', fn: () => clampMenu(g) } : { label: 'Launch', small: 'Into orbit. The planet waits for you.', fn: () => launch(g) },
    { label: 'Refit the ship', small: 'Modules, hulls and paint', fn: () => openWatch(g, 'ship') },
    { label: 'Cargo and trade', small: `Prices on ${current().name}`, fn: () => openWatch(g, 'cargo') },
    ...SHIP_MENU.map((f) => f(g)).filter((o): o is NonNullable<typeof o> => !!o),
    { label: 'Save', fn: () => { g.save(); saveSequel(); g.ui.toast('Saved.', 'good'); } },
    { label: 'Not now', fn: () => {} },
  ]);
}

// the Fear Man's clamp: pay the release fee, or do one job for the Syndicate
export const CLAMP_FEE = 1200;
function clampMenu(g: Game): void {
  g.ui.choice('The Syndicate Clamp', [
    { label: `Pay the Fear Man's release fee (${CLAMP_FEE})`, small: g.player.cash >= CLAMP_FEE ? 'The clamp comes off now' : `You have ${Math.floor(g.player.cash)}`, fn: () => {
      if (g.player.cash < CLAMP_FEE) return g.ui.toast('Not enough. Do a job for the Fear Man instead: it pays triple.', 'warn');
      g.player.cash -= CLAMP_FEE; releaseClamp(g, 'You pay. A Syndicate robot rolls up and cuts the clamp with a torch.');
    } },
    { label: 'Do a job for the Fear Man instead', small: 'Any Syndicate job takes the clamp off', fn: () => g.ui.openMenu('jobs') },
  ]);
}
export function releaseClamp(g: Game, how: string): void {
  if (!SQ.flags.clamp) return;
  SQ.flags.clamp = 0; saveSequel();
  waypointToShip(g);
  markFearMan(g);
  g.ui.story('The Fear Man', `${how}\n\n"You are free to fly. Bring me credits from the stars and I will forget you were ever Vane's. I forget most things now."\n\nFollow the blue marker back to the ${SQ.ship.name}.`);
}
// every job pays triple in XX8X, and the Fear Man's first job frees your ship
const JP = R.Jobs.prototype, baseComplete = JP.complete;
JP.complete = function (this: { game: Game }, j: { reward: number; family?: string }, extra?: number) {
  const r = baseComplete.call(this, j, (extra || 0) + j.reward * 2);
  if (SQ.flags.clamp) setTimeout(() => releaseClamp(this.game, 'Word comes down from the Fear Man: the job\'s done, the clamp comes off.'), 50);
  return r;
};

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
w.BS2 = Object.assign(w.BS2 || {}, { navTargets, autopilot, SQ, SPACE, launch, shipSprites, nearPlanetId: () => nearPlanet()?.id, spawnCraft, npcShip, stats, WEAPONS, takeOff, HOOKS, shipHere, travelTo });
