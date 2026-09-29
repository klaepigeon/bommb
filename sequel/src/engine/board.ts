// Boarding a disabled freighter, as a game 1 interior: the ship becomes a building whose room
// is built like a warehouse (crates, shelves, cover) and whose crew are game 1 people with
// guns. Everything from game 1 applies aboard: melee, firearms, props, cover, gore, bodies,
// looting pockets, rope and tape. Take the cargo crates, then leave by the airlock (the
// doormat) to get back to your ship.

import { SQ, saveSequel } from './state';
import type { Craft } from './space';
import { SPACE } from './space';
import { GOODS, addCargo } from './cargo';

const D = R.data, O = D.O, TS = R.TILE;
D.btypes.freighter = Object.assign({}, D.btypes.warehouse, { name: 'Freighter', jobs: {}, hours: null });

interface Hold { craft: Craft; room: { x0: number; y0: number; w: number; h: number; b: Building } | null; taken: Set<number>; crates: number[]; took: number }
let hold: Hold | null = null;

const I = R.Interiors.prototype, baseBuild = I.build, baseExit = I.exit;
// the room: a warehouse layout, in the freighter's paint
I.build = function (this: unknown, b: Building, slot: number) {
  if (b.type !== 'freighter') return baseBuild.call(this, b, slot);
  b.type = 'warehouse';
  try { return baseBuild.call(this, b, slot); } finally { b.type = 'freighter'; }
};
// any other room reached from space (a station, your own ship when boarders come): its exit
// takes you back to space and runs its own ending
let docked: { b: Building; done: (g: Game) => void } | null = null;
export function enterDock(g: Game, type: string, name: string, mode: string, done: (g: Game) => void): void {
  const w = g.world, pad = w.pad;
  const b = {
    id: w.buildings.length, type, name, x: pad.x, y: pad.y, w: 1, h: 1, out: { x: Math.floor(pad.sx / TS) - 2, y: Math.floor(pad.sy / TS) + 3 }, door: { x: 0, y: 0 },
    face: 'S', city: w.cities[0], cityId: w.cities[0].id, destroyed: false, seedArt: (Math.random() * 1e6) | 0, jobs: {}, fake: true,
  } as unknown as Building;
  w.buildings.push(b);
  docked = { b, done };
  SPACE.active = false;
  g.interiors.enter(b, mode);
  // interior rooms reuse a few slots of the world; nothing should still be burning from last time
  const room = g.player.room, fires = g.env && g.env.fires;
  if (room && fires) for (const i of [...fires.keys()]) { const x = i % w.W, y = (i / w.W) | 0; if (x >= room.x0 - 1 && x <= room.x0 + room.w && y >= room.y0 - 1 && y <= room.y0 + room.h) fires.delete(i); }
}
export const dockedRoom = () => docked;

// the airlock takes you back to your ship, not out onto a street
I.exit = function (this: { game: Game }) {
  const g = this.game, room = g.player.room;
  if (room && docked && room.b === docked.b) {
    const d = docked;
    baseExit.call(this);
    g.world.buildings[room.b.id] = null;
    g.interiors.clearRoom(room);
    docked = null;
    SPACE.active = true; SQ.mode = 'space'; saveSequel();
    d.done(g);
    return;
  }
  if (!room || room.b.type !== 'freighter') return baseExit.call(this);
  baseExit.call(this);
  const h = hold;
  if (h) {
    h.craft.looted = h.took > 0 || h.craft.looted;
    g.ui.toast(h.took ? `Back aboard your ship with ${h.took} crates from the ${h.craft.name}.` : `You back out of the ${h.craft.name} empty-handed.`, h.took ? 'good' : '');
    // drop the fake building so it never shows up anywhere else
    g.world.buildings[room.b.id] = null;
    g.interiors.clearRoom(room);
  }
  hold = null;
  SPACE.boarding = null;
  SPACE.active = true;
  SQ.mode = 'space';
  saveSequel();
};

export function enterFreighter(g: Game, craft: Craft): void {
  const w = g.world, pad = w.pad;
  const id = w.buildings.length;
  const b = {
    id, type: 'freighter', name: craft.name, x: pad.x, y: pad.y, w: 1, h: 1, out: { x: Math.floor(pad.sx / TS) - 2, y: Math.floor(pad.sy / TS) + 3 }, door: { x: 0, y: 0 },
    face: 'S', city: w.cities[0], cityId: w.cities[0].id, destroyed: false, seedArt: craft.id * 977, jobs: {}, fake: true,
  } as unknown as Building;
  w.buildings.push(b);
  hold = { craft, room: null, taken: new Set(), crates: [], took: 0 };
  g.interiors.enter(b, 'breakin');
  const room = g.player.room;
  hold.room = room;
  // the crates in the room carry the freighter's cargo
  for (let y = room.y0; y < room.y0 + room.h; y++) for (let x = room.x0; x < room.x0 + room.w; x++) if (w.o(x, y) === O.CRATE) hold.crates.push(w.idx(x, y));
  // the crew: Imperial ratings on Empire ships, Solari soldiers otherwise
  const floor: { x: number; y: number }[] = [];
  for (let y = room.y0 + 2; y < room.y0 + room.h - 3; y++) for (let x = room.x0 + 1; x < room.x0 + room.w - 1; x++) if (!w.solidPed(x, y)) floor.push({ x, y });
  const n = craft.flag === 'empire' ? 4 : 3;
  const white = ['#9aa0b0', '#c8ccd8', '#e6e8f0', '#ffffff'], black = ['#141418', '#24242e', '#383846', '#50505e'];
  for (let k = 0; k < n && floor.length; k++) {
    const s = floor.splice(Math.floor(Math.random() * floor.length), 1)[0];
    const h = g.interiors.spawnAt(room, null, s, { weapon: R.rng.pick(craft.flag === 'empire' ? ['revolver', 'rifle', 'carbine', 'tommy'] : ['magnum', 'shotgun', 'bat', 'machete']), arch: 'tough', tag: 'crew' });
    if (!h) continue;
    h.hostile = true; h.hostileLocked = true; h.tr.brave = 0.7 + Math.random() * 0.3;
    h.strangerName = craft.flag === 'empire' ? 'Imperial crewman' : 'Solari soldier';
    if (craft.flag === 'empire') { h.look.uniform = { shirt: white, pants: white, style: 'cap', cap: black }; h.look.old = null; }
    g.actors.setFight(h, g.player);
  }
  g.ui.banner(craft.name, `${n} crew aboard · crates in the hold`);
  g.ui.toast('Take the crates (USE), deal with the crew however you like, then leave by the airlock.', 'good');
}

// taking crates: a USE option on the freighter's crates
const PP = R.Player.prototype, baseCtx = PP.contextAction;
PP.contextAction = function (this: Player) {
  if (hold && this.room && this.room.b.type === 'freighter') {
    const w = R.game.world, tx = (this.x / TS) | 0, ty = (this.y / TS) | 0;
    for (let y = ty - 1; y <= ty + 1; y++) for (let x = tx - 1; x <= tx + 1; x++) {
      const i = w.idx(x, y);
      if (w.o(x, y) !== O.CRATE || hold.taken.has(i)) continue;
      const h = hold;
      const lotIdx = h.crates.indexOf(i) % Math.max(1, h.craft.cargo.length);
      const lot = h.craft.cargo[lotIdx];
      if (!lot || lot.n <= 0) continue;
      return { label: 'Take ' + GOODS[lot.good].name, fn: () => {
        const k = Math.min(lot.n, 3), put = addCargo(lot.good, k, true);
        if (!put) return R.game.ui.toast('Your holds are full.', 'bad');
        lot.n -= put; h.took += put; h.taken.add(i);
        w.setO(x, y, 0);
        R.game.audio.sfx('loot');
        R.game.ui.toast(`+${put} ${GOODS[lot.good].name}${GOODS[lot.good].contraband ? ' (contraband)' : ''}`, 'good');
      } };
    }
  }
  return baseCtx.call(this);
};

export const boarding = () => hold;
