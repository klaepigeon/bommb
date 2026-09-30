// The XX8X debug menu (Menu > Debug). Everything the sequel adds, one tap away: money and the
// clamp, every hull fitted out, spawning any kind of ship, landing on any world or Earth
// sector, jumping to any star, the Fear Man, ring flight, first contact. Game 1's own debug
// tools are still there, folded away underneath.

import { LA } from './lanterns';
import { COAST_SECTOR } from './state';
import { SQ, saveSequel, HOME_SECTOR } from './state';
import { PLANETS, AU } from './planets';
import { SPACE, launch, spawnCraft, SCAN, type Craft } from './space';
import { travelTo } from './travel';
import { STARS, enterSystem } from './galaxy';
import { landFrac } from './earth';
import { bodies } from '../space/system';
import { HULLS, MODS, npcShip, stats, type HullId, type Mod } from '../ship/ship';
import { waypointToShip } from './shipmark';
import { markFearMan } from './fearboss';
import { takeOff } from './ringfly';
import { contact } from './aliens';

// a hull with everything a player would want on it, powered
function fitted(hull: HullId): ReturnType<typeof npcShip> {
  const s = npcShip('patrol', Math.random, SQ.ship.name, hull), H = HULLS[hull];
  const want: Mod[] = ['tube', 'jump', 'cargo', 'hold', 'tractor', 'missile', 'drone', 'pd', 'sensor', 'burner', 'refinery', 'shield', 'cargo', 'med', 'quarters'];
  const core = new Set<Mod | null>(['cockpit', 'engine', 'reactor', 'gun', null]);
  let k = 0;
  for (let i = 0; i < s.grid.length && k < want.length; i++) if (!core.has(s.grid[i]) && i % H.w > 1) s.grid[i] = want[k++];
  for (let guard = 0; guard < 60 && stats(s).power < 0; guard++) {
    const j = s.grid.findIndex((m, n) => !!m && !core.has(m) && !want.slice(0, 6).includes(m as Mod) && n % H.w > 0);
    if (j < 0) break;
    s.grid[j] = 'reactor';
  }
  s.paint = SQ.ship.paint;
  return s;
}

function jumpTo(g: Game, to: string): void {
  if (!SPACE.active) launch(g);
  enterSystem(to);
  const a = Math.random() * Math.PI * 2, r = (to === 'sol' ? 5 : 3) * AU;
  Object.assign(SPACE, { x: Math.cos(a) * r, y: Math.sin(a) * r, vx: 0, vy: 0, cruise: false, crafts: [], shots: [], g: null });
  SPACE.B = bodies(g.clock.t);
  saveSequel();
}

const fearActor = (g: Game) => g.actors.list.find((a: any) => a.kind === 'h' && !a.dead && a.look && a.look.xeno === 'fearman');
const fearPerson = (g: Game) => g.pop.people.find((q: any) => q.isDon && q.look && q.look.xeno === 'fearman' && q.alive);

const baseTab = R.debugTab;
R.debugTab = function (body: HTMLElement, g: Game) {
  baseTab.call(this, body, g);
  // game 1's tools, folded away
  const old = document.createElement('details');
  old.innerHTML = '<summary class="sect" style="cursor:pointer">Game 1 tools (Brass Coast)</summary>';
  while (body.firstChild) old.appendChild(body.firstChild);
  const pl = g.player, ui = g.ui, my = stats(SQ.ship);
  const btn = (id: string, label: string) => `<button class="dbg" data-q="${id}">${label}</button>`;
  const sect = (title: string, items: string[]) => `<div class="sect">${title}</div><div class="dbgrow">${items.join('')}</div>`;
  const where = SPACE.active ? `space (${SQ.system})` : `${PLANETS[SQ.planet] ? PLANETS[SQ.planet].name : SQ.planet}${SQ.planet === 'earth' ? ` sector ${SQ.sector.join(',')}` : ''}`;
  const readout = `XX8X · ${where} · ship ${SQ.ship.name} (${HULLS[SQ.ship.hull].name}) hull ${Math.round(SQ.hull < 0 ? my.hull : SQ.hull)}/${my.hull} · thrust ${Math.round(my.thrust)} · fuel ${SQ.fuel}/${my.fuel} · bounty $${SQ.bounty} · heat ${SQ.heat.empire} · clamp ${SQ.flags.clamp ? 'ON' : 'off'} · Fear Man ${SQ.flags.fearDead ? 'dead' : 'alive'}${SQ.ringFly ? ' · RING FLIGHT' : ''} · ${SPACE.crafts.filter((c) => !c.dead).length} craft`;
  const html = `<p class="dbgstat">${readout}</p>` + [
    sect('Money & status', [btn('cash:10000', '+10,000 cr'), btn('cash:100000', '+100,000 cr'), btn('clamp', 'Release the clamp'), btn('fix', 'Repair + refuel'), btn('bounty:0', 'Clear bounty'), btn('bounty:5000', 'Bounty $5,000'), btn('heat', 'Imperial heat 40'), btn('will', 'Full WILL')]),
    sect('Ships (fitted out)', (Object.keys(HULLS) as HullId[]).map((h) => btn('hull:' + h, HULLS[h].name))),
    sect('Space', [btn('launch', 'Launch'), ...(['freighter', 'patrol', 'hunter', 'capital', 'rebel'] as Craft['kind'][]).map((k) => btn('spawn:' + k, 'Spawn ' + k)), btn('clearsp', 'Clear space'), btn('ore', '+12 ore')]),
    sect('Land on', Object.keys(PLANETS).map((id) => btn('land:' + id, PLANETS[id].name))),
    sect('Earth sectors', [btn('sec:home', 'The Brass Coast'), btn('sec:la', 'Los Angeles (Rayner)'), btn('sec:coast', 'Coast City (the Fear Man)'), btn('sec:tokyo', 'Tokyo'), btn('sec:sahara', 'Sahara'), btn('sec:random', 'Random land'), btn('night', 'Neon night (22:00)'), btn('rain', 'Acid rain')]),
    sect('Stars', [btn('star:sol', 'Sol'), ...STARS.slice(0, 12).map((s) => btn('star:' + s.id, s.name))]),
    sect('The Fear Man & the rings', [btn('fm:mark', 'Mark his club'), btn('fm:tp', 'Take me to him'), btn('fm:kill', 'Kill him now'), btn('ringfly', 'Take off on the ring'), btn('ringfree', 'Unlock rings (skip the kill)')]),
    sect('Aliens & story', [btn('europa', 'Europa: first contact'), btn('titan', 'Titan: the signal')]),
    sect('Look', [btn('look:cody', 'Road duster (Cody)'), btn('look:black', 'Black duster + visor helmet'), btn('look:proto', 'Protoman red')]),
  ].join('');
  body.insertAdjacentHTML('afterbegin', html);
  body.appendChild(old);
  body.querySelectorAll('[data-q]').forEach((el) => el.addEventListener('click', () => {
    const [k, v] = (el as HTMLElement).dataset.q!.split(':');
    try {
      switch (k) {
        case 'cash': pl.addCash(+v); break;
        case 'clamp': if (SQ.flags.clamp) { SQ.flags.clamp = 0; waypointToShip(g); markFearMan(g); ui.toast('Clamp off. Follow the blue marker.', 'good'); } break;
        case 'fix': SQ.hull = stats(SQ.ship).hull; SQ.fuel = Math.max(SQ.fuel, stats(SQ.ship).fuel); SPACE.shield = stats(SQ.ship).shield; break;
        case 'bounty': SQ.bounty = +v; break;
        case 'heat': SQ.heat.empire = 40; break;
        case 'will': pl.will = 100; break;
        case 'hull': SQ.ship = fitted(v as HullId); SQ.hull = stats(SQ.ship).hull; SQ.fuel = stats(SQ.ship).fuel; ui.toast(`${HULLS[v as HullId].name}, fitted: ${[...new Set(SQ.ship.grid.filter(Boolean))].map((m) => MODS[m as Mod].name).join(', ')}.`, 'good'); break;
        case 'launch': ui.closeSheet(); if (!SPACE.active) launch(g); break;
        case 'spawn': ui.closeSheet(); if (!SPACE.active) launch(g); spawnCraft(v as Craft['kind'], v !== 'freighter', v === 'capital' ? 900 : 400); break;
        case 'clearsp': SPACE.crafts = []; SPACE.shots = []; break;
        case 'ore': { const lot = SQ.cargo.find((l) => l.good === 'ore' && !l.stolen && !l.hidden); if (lot) lot.n += 12; else SQ.cargo.push({ good: 'ore', n: 12, stolen: false, hidden: false }); break; }
        case 'land': ui.closeSheet(); SPACE.active = false; SQ.mode = 'planet'; SQ.space = null; if (SQ.system !== SQ.home) enterSystem(SQ.home); travelTo(g, v, true); break;
        case 'sec': {
          ui.closeSheet();
          let s: [number, number] = [HOME_SECTOR[0], HOME_SECTOR[1]];
          if (v === 'tokyo') s = [63, 10]; else if (v === 'sahara') s = [37, 13]; else if (v === 'la') s = [LA[0], LA[1]]; else if (v === 'coast') s = [COAST_SECTOR[0], COAST_SECTOR[1]];
          else if (v === 'random') { for (let n = 0; n < 500; n++) { const c: [number, number] = [Math.floor(Math.random() * 72), 4 + Math.floor(Math.random() * 26)]; if (landFrac(c[0], c[1]) > 0.6) { s = c; break; } } }
          SPACE.active = false; SQ.mode = 'planet'; SQ.space = null; if (SQ.system !== 'sol') enterSystem('sol');
          SQ.sector = s; travelTo(g, 'earth', true);
          // straight into the middle of town for the named cities
          if (v === 'la' || v === 'coast') { const c = g.world.cities[0], w = g.world, at = w.findNear(c.cx, c.cy, 0, 8, (x: number, y: number) => !w.solidPed(x, y) && !w.isWater(x, y)) || { x: c.cx, y: c.cy }; const P = g.player; P.place(at.x * R.TILE + 8, at.y * R.TILE + 8); g.cam.x = P.x; g.cam.y = P.y; ui.toast(`${c.name}.`, 'good'); } // (setup made a new player)
          break;
        }
        case 'night': g.clock.t = Math.floor(g.clock.t / 1440) * 1440 + (g.clock.hour() >= 22 ? 1440 : 0) + 22 * 60; break;
        case 'rain': g.env.setWeather('rain'); break;
        case 'star': ui.closeSheet(); jumpTo(g, v); ui.toast(`Jumped to ${v === 'sol' ? 'Sol' : STARS.find((s) => s.id === v)!.name}.`, 'good'); break;
        case 'fm': {
          const p = fearPerson(g);
          if (v === 'mark') { markFearMan(g); if (p) ui.toast('His club is on the map.'); break; }
          if (!p) { ui.toast('No Fear Man here. He keeps court in Coast City (Earth sectors > Coast City).', 'warn'); break; }
          const b = g.world.buildings[p.home];
          if (v === 'tp' && b) { ui.closeSheet(); if (pl.room) g.interiors.exit(); if (pl.inCar) pl.exitCar(); pl.place(b.out.x * R.TILE + 8, (b.out.y + 1) * R.TILE + 8); g.cam.x = pl.x; g.cam.y = pl.y; break; }
          if (v === 'kill') {
            ui.closeSheet();
            let a = fearActor(g);
            if (!a && b) { a = g.actors.makeHuman(pl.x + 30, pl.y, { person: p }); if (a && p) { a.person = p; a.look = p.look; } }
            if (a) R.combat.kill(a, pl); else ui.toast('Couldn\'t find him.', 'warn');
          }
          break;
        }
        case 'ringfly': if (!pl.inv.tools.ring) { ui.toast('No ring yet. Kill the Fear Man (or unlock rings) first.', 'warn'); break; } pl.will = 100; takeOff(g); break;
        case 'ringfree': SQ.flags.fearDead = 1; saveSequel(); R.corps.give('yellow'); ui.toast('Rings unlocked, and the yellow is yours.', 'good'); break;
        case 'europa': ui.closeSheet(); contact(g); break;
        case 'titan': ui.closeSheet(); if (SCAN.titan) SCAN.titan(g); break;
        case 'look': {
          const st = v === 'cody' ? { jacket: 'duster', shirt: 'tank', pants: 'jeans', top: 'tee', hat: 'none' } : v === 'black' ? { jacket: 'duster_black', shirt: 'tank', pants: 'jeans', top: 'tee', hat: 'protohelm' } : { jacket: 'duster_red', shirt: 'tank', pants: 'leather', top: 'tee', hat: 'protohelm' };
          Object.assign(pl.style, st); pl.buildLook(); break;
        }
      }
      saveSequel();
    } catch (e) { ui.toast('Debug: ' + (e as Error).message, 'bad'); }
  }));
};
