// Playing on a planet-sized Earth: crossing sector borders on foot (or by car, leaving it at
// the line), calling your ship to whichever sector you've walked to, choosing where to come
// down from orbit on the planet map, and the map itself.

import { SQ, saveSequel } from './state';
import { NX, NY, HOME, isHome, landValue, landFrac, climate, lonOf, latOf, sectorName, EARTH } from './earth';
import { travelTo, nearPad, shipHere } from './travel';
import { HOOKS } from './space';

const TS = R.TILE;

// ---------------------------------------------------------------- the map
const COL = { ice: [216, 224, 232], tundra: [122, 138, 122], desert: [184, 152, 90], jungle: [58, 106, 58], temperate: [96, 106, 66] } as const;
let mapCache: HTMLCanvasElement | null = null;
// the whole planet at 4 pixels a sector: ocean, climates, and the lit sprawls
export function planetMap(): HTMLCanvasElement {
  if (mapCache) return mapCache;
  const S = 4, c = document.createElement('canvas');
  c.width = NX * S; c.height = NY * S;
  const g = c.getContext('2d')!, img = g.createImageData(c.width, c.height);
  for (let y = 0; y < c.height; y++) for (let x = 0; x < c.width; x++) {
    const u = x / S, v = y / S, lv = landValue(u, v), k = (y * c.width + x) * 4;
    let rgb: readonly number[];
    if (lv < 0.5) rgb = lv < 0.44 ? [22, 34, 48] : [34, 58, 70];
    else rgb = COL[climate(lonOf(u), latOf(v))];
    img.data[k] = rgb[0]; img.data[k + 1] = rgb[1]; img.data[k + 2] = rgb[2]; img.data[k + 3] = 255;
  }
  g.putImageData(img, 0, 0);
  mapCache = c;
  return c;
}
export function drawPlanetMap(cv: HTMLCanvasElement, pick?: [number, number] | null): void {
  const g = cv.getContext('2d')!, m = planetMap(), sx = cv.width / m.width, sy = cv.height / m.height;
  g.imageSmoothingEnabled = false;
  g.drawImage(m, 0, 0, cv.width, cv.height);
  const cell = (s: [number, number], col: string, fill = false) => { g.strokeStyle = col; g.fillStyle = col; const x = s[0] * 4 * sx, y = s[1] * 4 * sy; if (fill) g.fillRect(x, y, 4 * sx, 4 * sy); else g.strokeRect(x + 0.5, y + 0.5, 4 * sx - 1, 4 * sy - 1); };
  // sectors you've been to glow faintly (the grid is too fine to draw whole)
  for (const k of ((SQ as any).sectorLRU || []) as string[]) { const [x, y] = k.split(',').map(Number); g.globalAlpha = 0.35; cell([x, y], '#ff5ad0', true); g.globalAlpha = 1; }
  cell(HOME, '#f0b838');
  if (SQ.planet === 'earth') { cell(SQ.shipAt, '#68f0a0'); cell(SQ.sector, '#ffffff'); }
  if (pick) cell(pick, '#ff5ad0');
}

// ---------------------------------------------------------------- choosing a landing zone
function chooser(g: Game, go: () => void): void {
  let pick: [number, number] | null = null;
  const home = SQ.shipAt && landFrac(SQ.shipAt[0], SQ.shipAt[1]) > 0.05 ? SQ.shipAt : HOME;
  const s = g.ui.openSheet('planet', g.ui.header('Earth · Choose a Landing Zone', '2,592 sectors, each one the size of the Brass Coast. Tap land to pick one.') + `<div class="body"><canvas class="sw-map" width="576" height="288" style="aspect-ratio:2/1"></canvas><p class="sw-info" id="lzinfo">Gold: the Brass Coast. Green: where you last parked. Pink: where you've been.</p><div class="sw-row"><button data-lz="home">The Brass Coast</button><button data-lz="pick" disabled>Land here</button></div></div>`);
  const cv = s.querySelector('canvas') as HTMLCanvasElement, info = s.querySelector('#lzinfo') as HTMLElement, btn = s.querySelector('[data-lz="pick"]') as HTMLButtonElement;
  drawPlanetMap(cv, null);
  cv.addEventListener('pointerdown', (e) => {
    const r = cv.getBoundingClientRect(), x = Math.floor(((e.clientX - r.left) / r.width) * NX), y = Math.floor(((e.clientY - r.top) / r.height) * NY);
    const f = landFrac(x, y);
    pick = f > 0.05 ? [x, y] : null;
    drawPlanetMap(cv, pick ?? [x, y]);
    info.textContent = pick ? `${sectorName(x, y)} · ${Math.round(f * 100)}% land · ${climate(lonOf(x + 0.5), latOf(y + 0.5))}` : 'Open ocean. Nowhere to set down.';
    btn.disabled = !pick;
  });
  const land = (sec: [number, number]) => { SQ.sector = [sec[0], sec[1]]; SQ.shipAt = [sec[0], sec[1]]; saveSequel(); g.ui.closeSheet(); go(); };
  s.querySelector('[data-lz="home"]')!.addEventListener('click', () => land(HOME));
  btn.addEventListener('click', () => { if (pick) land(pick); });
  void home;
}
HOOKS.land.earth = chooser;
export const landAt = (g: Game, sec: [number, number], go: () => void) => { SQ.sector = [sec[0], sec[1]]; SQ.shipAt = [sec[0], sec[1]]; go(); };

// ---------------------------------------------------------------- crossing a border
let crossing = false, blockT = 0;
const GP = R.Game.prototype, baseTick = GP.tick;
GP.tick = function (this: Game, dt: number) {
  const r = baseTick.call(this, dt);
  blockT -= dt;
  if (!EARTH.active || crossing || !this.player || this.ui.paused() || (window as any).BS2?.SPACE?.active) return r;
  const pl = this.player, w = this.world;
  if (pl.room) return r;
  const x = (pl.inCar ? pl.inCar.x : pl.x) / TS, y = (pl.inCar ? pl.inCar.y : pl.y) / TS, M = 3;
  const edge = x < M ? 'w' : x > w.W - M ? 'e' : y < M ? 'n' : y > w.H - M ? 's' : null;
  if (!edge) return r;
  const [sx, sy] = SQ.sector;
  const to: [number, number] = edge === 'w' ? [(sx + NX - 1) % NX, sy] : edge === 'e' ? [(sx + 1) % NX, sy] : edge === 'n' ? [sx, sy - 1] : [sx, sy + 1];
  const push = () => { const dx = edge === 'w' ? 3 : edge === 'e' ? -3 : 0, dy = edge === 'n' ? 3 : edge === 's' ? -3 : 0; if (pl.inCar) { pl.inCar.x += dx * TS; pl.inCar.y += dy * TS; pl.inCar.vx = pl.inCar.vy = 0; } else pl.place(pl.x + dx * TS, pl.y + dy * TS); };
  if (to[1] < 0 || to[1] >= NY || landFrac(to[0], to[1]) < 0.04) {
    push();
    if (blockT <= 0) { blockT = 4; this.ui.toast(to[1] < 0 || to[1] >= NY ? 'The ice goes on forever. Nothing lives out there.' : 'Open ocean for five hundred kilometres. Nothing out there but acid and plastic.', 'warn'); }
    return r;
  }
  crossing = true;
  if (pl.inCar) { pl.exitCar(); this.ui.toast('You leave the car at the checkpoint.'); }
  const f = edge === 'w' || edge === 'e' ? y / w.H : x / w.W;
  SQ.sector = to; SQ.arriveEdge = { edge, f };
  saveSequel();
  travelTo(this, 'earth', true);
  crossing = false;
  this.ui.banner(sectorName(to[0], to[1]), `Sector ${to[0]},${to[1]} · ${climate(lonOf(to[0] + 0.5), latOf(to[1] + 0.5))}`);
  return r;
};

// ---------------------------------------------------------------- your ship, wherever you are
const PP = R.Player.prototype, baseCtx = PP.contextAction;
PP.contextAction = function (this: Player) {
  if (SQ.mode !== 'space' && !SQ.ringFly && !shipHere() && nearPad(this)) {
    return { label: 'Call ' + SQ.ship.name, fn: () => {
      if (SQ.planet === 'earth') SQ.shipAt = [SQ.sector[0], SQ.sector[1]];
      SQ.shipLoc = { sys: SQ.home, planet: SQ.planet }; saveSequel();
      R.game.audio.sfx('boom');
      R.game.ui.toast(`The ${SQ.ship.name} comes down on autopilot from ${isHome(SQ.shipAt) ? 'the coast' : 'orbit'}. Rent on a pad is extra.`, 'good');
    } };
  }
  return baseCtx.call(this);
};

(window as any).BS2 = Object.assign((window as any).BS2 || {}, { landFrac, landAt, EARTH, earthMap: planetMap });
