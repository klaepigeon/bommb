// The Ship Watch: three tabs added to game 1's menu. SHIP is the module editor (and hulls),
// CARGO is your holds plus the market wherever your ship is parked, SYSTEM is the map of
// the solar system (square-root scaled so Mercury and Neptune fit on one screen) where you
// set a course for the flight computer.

import { SQ, saveSequel, type Good } from './state';
import { PLANETS, BODY, BODIES, AU, systemData, worldProfile, type PlanetId, type BodyId } from './planets';
import { STARS, jump, jumpCost, clearSpace, jumpRange, lyBetween, starPos } from './galaxy';
import { speciesOn } from './aliens';
import { describe, faunaHere } from './eco';
import { fmt } from './bounty';
import { HULLS, MODS, modIcon, stats, type HullId, type Mod } from '../ship/ship';
import { GOODS, price, blackMarket, used, addCargo } from './cargo';
import { bodies, planetArt } from '../space/system';
import { SPACE, navTargets, autopilot } from './space';
import { nearShip } from './travel';

const esc = (s: string) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c] as string);
const TABS: [string, string][] = [['ship', 'Ship'], ['cargo', 'Cargo'], ['system', 'System']];
let selected: Mod | null = null;

const CSS = `
.sw-grid { display: grid; gap: 3px; background: #3c4654; padding: 4px; border-radius: 6px; margin: 6px auto; max-width: 100%; }
.sw-grid button { aspect-ratio: 1; border: none; border-radius: 3px; background: #2c3440; padding: 0; display: grid; place-items: center; min-width: 0; }
.sw-grid canvas, .sw-pal canvas { width: 80%; image-rendering: pixelated; }
.sw-pal { display: grid; grid-template-columns: repeat(auto-fill, minmax(34px, 1fr)); gap: 4px; margin: 6px 0; }
.sw-pal button { aspect-ratio: 1; border: 2px solid transparent; border-radius: 4px; background: #efe6d2; padding: 0; display: grid; place-items: center; }
.sw-pal button.on { border-color: #d9621e; background: #fff; }
.sw-stats { font-size: 13px; display: flex; flex-wrap: wrap; gap: 4px 10px; color: var(--brown); }
.sw-stats b { color: var(--ink, #2a1a12); }
.sw-warn { color: #b83a2a; font-size: 13px; margin: 4px 0; }
.sw-info { font-size: 13px; color: var(--brown); min-height: 2.6em; }
.sw-row { display: flex; flex-wrap: wrap; gap: 6px; margin: 6px 0; }
.sw-row button, .sw-trade button { font: inherit; font-size: 13px; padding: 5px 9px; border-radius: 5px; border: 2px solid #2a1a12; background: #efe6d2; }
.sw-row button:disabled, .sw-trade button:disabled { opacity: 0.35; }
.sw-trade { display: grid; grid-template-columns: 1fr auto 4em auto auto; gap: 6px; align-items: center; font-size: 14px; margin: 3px 0; }
.sw-trade small { color: var(--brown); }
.sw-map, .sw-chart { width: 100%; image-rendering: pixelated; border-radius: 6px; display: block; background: #0c0a24; }
`;

export function installWatch(g: Game): void {
  const U = R.UI.prototype;
  if (U._watch) return;
  U._watch = true;
  const st = document.createElement('style'); st.textContent = CSS; document.head.appendChild(st);
  const baseMenu = U.openMenu, baseTab = U.openMenuTab;
  U.openMenu = function (this: { sheetOpen: string | null; openMenuTab(t: string, s: HTMLElement): void }, tab: string) {
    const r = baseMenu.call(this, TABS.some(([k]) => k === tab) ? 'map' : tab);
    const s = document.querySelector('.sheet') as HTMLElement | null, row = s && s.querySelector('.tabs');
    if (s && row && !row.querySelector('[data-tab="ship"]')) {
      const close = row.querySelector('[data-tab="close"]');
      for (const [k, l] of TABS) {
        const b = document.createElement('button'); b.dataset.tab = k; b.textContent = l;
        b.addEventListener('click', () => this.openMenuTab(k, s));
        row.insertBefore(b, close);
      }
    }
    if (s && TABS.some(([k]) => k === tab)) this.openMenuTab(tab, s);
    return r;
  };
  U.openMenuTab = function (this: unknown, tab: string, s: HTMLElement) {
    if (!TABS.some(([k]) => k === tab)) return baseTab.call(this, tab, s);
    s.querySelectorAll<HTMLElement>('[data-tab]').forEach((b) => b.classList.toggle('sel', b.dataset.tab === tab));
    const body = document.getElementById('mbody') as HTMLElement;
    body.scrollTop = 0;
    if (tab === 'ship') shipTab(g, body);
    else if (tab === 'cargo') cargoTab(g, body);
    else systemTab(g, body);
  };
}
export function openWatch(g: Game, tab: string): void { g.ui.openMenu(tab); }
const refresh = (g: Game, tab: string) => { const s = document.querySelector('.sheet') as HTMLElement | null; if (s) g.ui.openMenuTab(tab, s); };

// ---------------------------------------------------------------- SHIP
// refitting away from the pad: a shipyard in orbit (the rebels' yard, your own base's drydock)
export const REFIT = { yard: '' as '' | 'rebel' | 'base' };
// more sections under the ship editor (the crew roster)
export const SHIP_TAB_EXTRA: ((g: Game, body: HTMLElement) => void)[] = [];
// rebel tech: only the rebels' yard fits it
const REBEL_ONLY = new Set<Mod>(['cloak']);
// capital hulls at 30% off in your own level-3 drydock
const hullPrice = (h: HullId) => (REFIT.yard === 'base' && (SQ.bases || []).some((b) => b.level >= 3) && HULLS[h].cls === 'capital' ? Math.round(HULLS[h].price * 0.7) : HULLS[h].price);
function shipTab(g: Game, body: HTMLElement): void {
  const s = SQ.ship, H = HULLS[s.hull], st = stats(s), pl = g.player;
  const docked = (!SPACE.active && !pl.room && nearShip(pl)) || !!REFIT.yard;
  const mods = (Object.keys(MODS) as Mod[]).filter((m) => m !== 'cockpit' && (!REBEL_ONLY.has(m) || REFIT.yard === 'rebel'));
  body.innerHTML = `<div class="sect">${esc(s.name)} · ${H.name}</div>
    <div class="sw-grid" style="grid-template-columns:repeat(${H.w},1fr);width:min(100%,${H.w * 44}px)">${s.grid.map((m, i) => `<button data-i="${i}" title="${m ? MODS[m].name : 'Empty slot'}" aria-label="${m ? MODS[m].name : 'Empty slot'}"></button>`).join('')}</div>
    <div class="sw-stats"><span>Thrust <b>${Math.round(st.thrust)}</b></span><span>Power <b>${st.power >= 0 ? '+' : ''}${st.power}</b></span><span>Hull <b>${Math.max(0, Math.round(SQ.hull < 0 ? st.hull : SQ.hull))}/${st.hull}</b></span><span>Shield <b>${st.shield}</b></span><span>Guns <b>${st.guns}</b></span><span>Cargo <b>${st.cargo}</b> + hidden <b>${st.hidden}</b></span></div>
    ${st.problems.length ? `<div class="sw-warn">${st.problems.map(esc).join('<br>')}</div>` : ''}
    ${docked ? `<div class="sect">Fit modules</div><div class="sw-pal">${mods.map((m) => `<button data-m="${m}" class="${selected === m ? 'on' : ''}" title="${MODS[m].name}" aria-label="${MODS[m].name}"></button>`).join('')}</div>
      <div class="sw-info">${selected ? `<b>${MODS[selected].name}</b> · $${MODS[selected].price} · ${esc(MODS[selected].blurb)}` : 'Pick a module, then tap a slot to fit it. Tap a fitted slot with nothing picked to strip it for half its price.'}</div>
      <div class="sw-row">${(Object.keys(HULLS) as HullId[]).filter((h) => h !== s.hull && HULLS[h].price > 0).map((h) => `<button data-h="${h}">${HULLS[h].name} hull · $${hullPrice(h).toLocaleString()}</button>`).join('')}
      ${SQ.hull >= 0 && SQ.hull < st.hull ? `<button data-repair="1">Repair hull · $${Math.ceil((st.hull - SQ.hull) * 2)}</button>` : ''}</div>`
    : '<p class="sw-info">Refits happen on the pad (or docked at a shipyard). Walk up to your ship to fit modules, buy hulls or repair. The Cloaking Field is rebel tech: only the Free Ganymede Shipyard fits it.</p>'}`;
  const icon = (m: Mod) => { const c = document.createElement('canvas'); c.width = 16; c.height = 16; (c.getContext('2d') as CanvasRenderingContext2D).drawImage(modIcon(m), 0, 0); return c; };
  body.querySelectorAll<HTMLButtonElement>('.sw-grid button').forEach((b) => { const m = s.grid[+(b.dataset.i as string)]; if (m) b.appendChild(icon(m)); });
  body.querySelectorAll<HTMLButtonElement>('.sw-pal button').forEach((b) => b.appendChild(icon(b.dataset.m as Mod)));
  for (const f of SHIP_TAB_EXTRA) f(g, body);
  body.onclick = (e) => {
    const t = e.target as HTMLElement;
    const mod = t.closest<HTMLElement>('[data-m]'), cell = t.closest<HTMLElement>('[data-i]'), hull = t.closest<HTMLElement>('[data-h]'), rep = t.closest('[data-repair]');
    if (mod) { selected = selected === mod.dataset.m ? null : (mod.dataset.m as Mod); return refresh(g, 'ship'); }
    if (!docked) return;
    if (cell) {
      const i = +(cell.dataset.i as string), cur = s.grid[i];
      if (cur === 'cockpit') return g.ui.toast('The cockpit stays where it is.', 'warn');
      if (selected) {
        const cost = MODS[selected].price - (cur ? Math.floor(MODS[cur].price / 2) : 0);
        if (pl.cash < cost) return g.ui.toast("You can't afford that module.", 'warn');
        pl.cash -= cost; s.grid[i] = selected; g.audio.sfx('equip');
      } else if (cur) { pl.cash += Math.floor(MODS[cur].price / 2); s.grid[i] = null; g.audio.sfx('reload'); }
      SQ.hull = -1; saveSequel();
      return refresh(g, 'ship');
    }
    if (rep) { const cost = Math.ceil((st.hull - SQ.hull) * 2); if (pl.cash < cost) return g.ui.toast("You can't afford the repair.", 'warn'); pl.cash -= cost; SQ.hull = -1; saveSequel(); g.audio.sfx('equip'); return refresh(g, 'ship'); }
    if (hull) {
      const h = hull.dataset.h as HullId, NH = HULLS[h];
      if (pl.cash < hullPrice(h)) return g.ui.toast("You can't afford that hull.", 'warn');
      const grid: (Mod | null)[] = new Array(NH.w * NH.h).fill(null);
      for (let y = 0; y < H.h; y++) for (let x = 0; x < H.w; x++) {
        const m = s.grid[y * H.w + x]; if (!m) continue;
        const nx = m === 'cockpit' || m === 'gun' ? NH.w - (H.w - x) : x, ny = y + Math.floor((NH.h - H.h) / 2);
        if (nx >= 0 && nx < NH.w && ny >= 0 && ny < NH.h) grid[ny * NH.w + nx] = m;
      }
      pl.cash -= hullPrice(h); s.hull = h; s.grid = grid; s.paint = NH.paint; SQ.hull = -1; saveSequel();
      g.audio.sfx('accept'); g.ui.toast(`New ${NH.name} hull. Your modules came across.`, 'good');
      return refresh(g, 'ship');
    }
  };
}

// ---------------------------------------------------------------- CARGO
function cargoTab(g: Game, body: HTMLElement): void {
  const st = stats(SQ.ship), u = used(), pl = g.player, at = SQ.planet as PlanetId;
  const docked = !SPACE.active && !pl.room && nearShip(pl);
  const black = blackMarket(at);
  const goods = Object.keys(GOODS) as Good[];
  body.innerHTML = `<div class="sect">Holds · bay ${u.open}/${st.cargo} · hidden ${u.hidden}/${st.hidden}</div>
    ${SQ.cargo.filter((l) => l.n > 0).map((l) => `<p>${l.n} × ${GOODS[l.good].name}${l.stolen ? ' <b style="color:#b83a2a">stolen</b>' : ''}${GOODS[l.good].contraband ? ' <b style="color:#b83a2a">contraband</b>' : ''}${l.hidden ? ' <small>(hidden hold)</small>' : ''}</p>`).join('') || '<p>Empty holds.</p>'}
    <div class="sect">${docked ? (black ? 'Black market' : 'Pad exchange') + ' · ' + PLANETS[at].name : 'Market'}</div>
    ${docked ? goods.map((k) => {
      const p = price(at, k), have = SQ.cargo.filter((l) => l.good === k).reduce((s, l) => s + l.n, 0), hot = SQ.cargo.filter((l) => l.good === k && l.stolen).reduce((s, l) => s + l.n, 0);
      return `<div class="sw-trade"><span>${GOODS[k].name}${GOODS[k].contraband ? '*' : ''}</span><b>$${p}</b><small>${have ? 'have ' + have : ''}</small><button data-b="${k}" ${black || !GOODS[k].contraband ? '' : 'disabled'}>Buy</button><button data-s="${k}" ${have && (black || have > hot) ? '' : 'disabled'}>Sell</button></div>`;
    }).join('') + `<p class="sw-info">${black ? 'Stolen goods sell at full price here.' : '*Contraband. Stolen goods won\'t sell on an Imperial pad: find a black market.'}</p>` : '<p class="sw-info">Trade from your ship\'s pad on any planet.</p>'}
    <p class="sw-info">Imperial heat: <b>${Math.round(SQ.heat.empire)}</b>. Land hot on an Imperial world and customs scan your open bay. A smuggler's hold hides stolen cargo.</p>`;
  body.onclick = (e) => {
    const t = (e.target as HTMLElement).closest('button'); if (!t || !docked) return;
    const buy = t.dataset.b as Good | undefined, sell = t.dataset.s as Good | undefined;
    if (buy) {
      const p = price(at, buy);
      if (pl.cash < p) return g.ui.toast("You can't afford it.", 'warn');
      if (!addCargo(buy, 1, false)) return g.ui.toast('No room in the holds.', 'warn');
      pl.cash -= p; g.audio.sfx('cash');
    }
    if (sell) {
      const lot = SQ.cargo.filter((l) => l.good === sell && l.n > 0 && (black || !l.stolen)).sort((a, b) => Number(a.stolen) - Number(b.stolen))[0];
      if (!lot) return;
      lot.n--; pl.cash += price(at, sell); g.audio.sfx('cash');
      if (lot.stolen) pl.stats.fenced = (pl.stats.fenced || 0) + 1;
      SQ.cargo = SQ.cargo.filter((l) => l.n > 0);
    }
    saveSequel();
    refresh(g, 'cargo');
  };
}

// ---------------------------------------------------------------- SYSTEM
function systemTab(g: Game, body: HTMLElement): void {
  const B = bodies(g.clock.t), at = (id: BodyId) => B.find((b) => b.id === id)!;
  const inSpace = SPACE.active;
  const sys = systemData(SQ.system), my = stats(SQ.ship), cs = clearSpace();
  const allStars = [{ id: 'sol', name: 'Sol', ly: 0, col: '#ffe070', x: 0, y: 0 }, ...STARS];
  const reach = allStars.filter((st) => st.id !== SQ.system && lyBetween(SQ.system, st.id) <= jumpRange()).sort((a, b) => lyBetween(SQ.system, a.id) - lyBetween(SQ.system, b.id));
  const peoples = (id: string) => { const sp = speciesOn(id); return sp.length ? ` Peoples: ${sp.map((x) => esc(x.plural)).join(', ')}.` : ''; };
  const onGround = !inSpace && SQ.home === SQ.system;
  const wild = faunaHere().filter((b: { bird?: number; name: string; biome: string[] }) => !b.biome.includes('city') || b.bird).map((b: { name: string }) => b.name);
  body.innerHTML = `<div class="sect">${esc(sys.name)}${SQ.system !== 'sol' ? ` · ${sys.ly} light years from Sol` : ''}</div>
    <canvas class="sw-map" width="300" height="300" aria-label="Map of the ${esc(sys.name)} system"></canvas>
    <p class="sw-info">${inSpace ? 'Set a course, then engage cruise (RUN) and let go of the stick: the flight computer steers and drops you out on arrival.' : `You're on ${esc(worldProfile().name)}. Launch from your ship to fly.`}${SQ.course && BODY[SQ.course] ? ` Course: <b>${BODY[SQ.course].name}</b>.` : ''}</p>
    ${SQ.bounty > 0 ? `<p class="sw-warn">Imperial bounty: <b>${fmt(SQ.bounty)}</b>. Hunters are looking. Answer it at the court on Venus.</p>` : ''}
    <div class="sect">Worlds you can land on</div><div class="sw-row" id="swland">${(Object.keys(PLANETS) as PlanetId[]).map((id) => `<button data-c="${id}" ${inSpace ? '' : 'disabled'}>${BODY[id].name}${PLANETS[id].frontier ? ' (frontier)' : ''}${SQ.visited.includes(id) ? '' : ' ★'}</button>`).join('')}</div>
    ${(Object.keys(PLANETS) as PlanetId[]).map((id) => `<p><b>${BODY[id].name}</b>: ${esc(BODY[id].blurb)} <small>Run by ${esc(PLANETS[id].faction)}.${peoples(id)}</small></p>`).join('')}
    ${onGround ? `<div class="sect">Wildlife on ${esc(worldProfile().name)}</div><p class="sw-info">${esc(wild.join(', '))}. ${esc(describe().join('; '))}.</p>` : ''}
    <div class="sect">The rest of the system</div><div class="sw-row" id="swfar">${BODIES.filter((b) => b.id !== 'sun' && !(b.id in PLANETS)).map((b) => `<button data-c="${b.id}" ${inSpace ? '' : 'disabled'}>${b.name}</button>`).join('')}</div>
    <div class="sect">Jump drive${my.jump ? ` · fuel ${SQ.fuel}/${my.fuel}` : ''}</div>
    <canvas class="sw-chart" width="300" height="300" aria-label="Galaxy chart"></canvas>
    ${my.jump ? `<p class="sw-info">One jump folds <b>${jumpRange()} ly</b>. ${cs.ok ? 'Clear space: tap a star in range (or a button).' : esc(cs.why)}</p><div class="sw-row" id="swjump">${reach.map((st) => `<button data-j="${st.id}" ${inSpace && cs.ok && SQ.fuel >= jumpCost(st.id) ? '' : 'disabled'}>${esc(st.name)} · ${lyBetween(SQ.system, st.id).toFixed(1)} ly · ${jumpCost(st.id)} fuel${SQ.known.includes(st.id) ? '' : ' ★'}</button>`).join('')}</div>` : '<p class="sw-info">Fit a Jump Drive (Refit, on the pad) to reach the stars on this chart. Each jump folds 12 light years; further stars take hops.</p>'}
    <p class="sw-info">${SQ.system === 'sol' ? '1 AU = 150 million km. Neptune is 30 AU out.' : 'Jump fuel refills when you land on an inhabited world.'}</p>`;
  const cv = body.querySelector('canvas') as HTMLCanvasElement, c = cv.getContext('2d') as CanvasRenderingContext2D;
  c.imageSmoothingEnabled = false;
  const outer = Math.max(...BODIES.filter((b) => b.parent === 'sun').map((b) => b.au), 1), S = 300, cx = S / 2, cy = S / 2, K = (S / 2 - 16) / Math.sqrt(outer * 1.03);
  const map = (x: number, y: number) => { const d = Math.hypot(x, y) / AU, a = Math.atan2(y, x), r = Math.sqrt(d) * K; return { x: cx + Math.cos(a) * r, y: cy + Math.sin(a) * r }; };
  c.fillStyle = '#0c0a24'; c.fillRect(0, 0, S, S);
  // the 80s grid, faintly
  c.strokeStyle = 'rgba(255,90,200,0.08)';
  for (let k = 0; k <= S; k += 20) { c.beginPath(); c.moveTo(k, 0); c.lineTo(k, S); c.stroke(); c.beginPath(); c.moveTo(0, k); c.lineTo(S, k); c.stroke(); }
  c.strokeStyle = 'rgba(160,150,230,0.35)'; c.setLineDash([2, 3]);
  for (const b of BODIES) if (b.parent === 'sun') { c.beginPath(); c.arc(cx, cy, Math.sqrt(b.au) * K, 0, 7); c.stroke(); }
  c.setLineDash([]);
  c.fillStyle = BODY.sun ? BODY.sun.color : '#ffe070'; c.beginPath(); c.arc(cx, cy, 5, 0, 7); c.fill();
  for (const b of BODIES) {
    if (b.id === 'sun') continue;
    const pos = at(b.id);
    let m = map(pos.x, pos.y);
    if (b.parent && b.parent !== 'sun') { const p = map(at(b.parent).x, at(b.parent).y), a = Math.atan2(pos.y - at(b.parent).y, pos.x - at(b.parent).x); m = { x: p.x + Math.cos(a) * 7, y: p.y + Math.sin(a) * 7 }; }
    const moon = b.parent !== 'sun', s = moon ? 3 : Math.max(5, Math.min(12, b.radius / 90));
    if (moon) { c.fillStyle = b.color; c.fillRect(m.x - 1, m.y - 1, 2, 2); }
    else c.drawImage(planetArt(b.id), m.x - s / 2 - (b.rings ? s / 2 : 0), m.y - s / 2 - (b.rings ? s / 2 : 0), s * (b.rings ? 2 : 1), s * (b.rings ? 2 : 1));
    if (!moon || b.id === 'luna') R.art.ptext(c, b.name.toUpperCase(), m.x + s / 2 + 2, m.y - 3, { scale: 1, color: b.id in PLANETS ? '#ffe070' : '#b8b0d8' });
    if (SQ.course === b.id) { c.strokeStyle = '#ff9a3a'; c.strokeRect(m.x - 6, m.y - 6, 12, 12); }
  }
  const me = inSpace || !at(SQ.planet) ? map(SPACE.x, SPACE.y) : map(at(SQ.planet).x, at(SQ.planet).y);
  c.fillStyle = '#ff5ad0'; c.beginPath(); c.moveTo(me.x, me.y - 5); c.lineTo(me.x + 4, me.y + 4); c.lineTo(me.x - 4, me.y + 4); c.fill();
  // the galaxy chart: centred on where you are, the jump range as a ring
  const ch = body.querySelector('.sw-chart') as HTMLCanvasElement, cc = ch.getContext('2d') as CanvasRenderingContext2D;
  const [ox, oy] = starPos(SQ.system), SC = 300 / 2 / 40; // 40 ly to the edge
  const toC = (x: number, y: number) => ({ x: 150 + (x - ox) * SC, y: 150 + (y - oy) * SC });
  cc.fillStyle = '#07051a'; cc.fillRect(0, 0, 300, 300);
  cc.strokeStyle = 'rgba(104,240,160,0.5)'; cc.setLineDash([3, 3]); cc.beginPath(); cc.arc(150, 150, jumpRange() * SC, 0, 7); cc.stroke(); cc.setLineDash([]);
  for (const st of allStars) {
    const q = toC(st.x || 0, st.y || 0);
    if (q.x < -4 || q.x > 304 || q.y < -4 || q.y > 304) continue;
    const here = st.id === SQ.system, inR = reach.includes(st as any), known = SQ.known.includes(st.id);
    cc.fillStyle = st.col; cc.fillRect(Math.round(q.x) - (here ? 2 : 1), Math.round(q.y) - (here ? 2 : 1), here ? 5 : 3, here ? 5 : 3);
    if (here) { cc.strokeStyle = '#ff5ad0'; cc.strokeRect(q.x - 5, q.y - 5, 10, 10); }
    if (here || inR || known || st.id === 'sol') R.art.ptext(cc, st.name.toUpperCase(), Math.round(q.x) + 4, Math.round(q.y) - 3, { scale: 1, color: here ? '#ff5ad0' : inR ? '#68f0a0' : '#8a86a8' });
  }
  ch.addEventListener('click', (e) => {
    const r = ch.getBoundingClientRect(), mx = ((e.clientX - r.left) / r.width) * 300, my2 = ((e.clientY - r.top) / r.height) * 300;
    const hit = allStars.map((st) => ({ st, d: Math.hypot(toC(st.x || 0, st.y || 0).x - mx, toC(st.x || 0, st.y || 0).y - my2) })).sort((a, b) => a.d - b.d)[0];
    if (!hit || hit.d > 14 || hit.st.id === SQ.system) return;
    if (!my.jump) return g.ui.toast(`${hit.st.name}: ${lyBetween(SQ.system, hit.st.id).toFixed(1)} ly. You need a Jump Drive.`);
    if (jump(g, hit.st.id)) g.ui.closeSheet();
  });
  body.querySelectorAll<HTMLElement>('[data-j]').forEach((bt) => bt.addEventListener('click', () => { if (jump(g, bt.dataset.j as string)) g.ui.closeSheet(); }));
  body.querySelectorAll<HTMLElement>('[data-c]').forEach((bt) => bt.addEventListener('click', () => {
    if (!inSpace) return;
    SQ.course = bt.dataset.c as BodyId; saveSequel();
    g.ui.closeSheet();
    const t = navTargets().find((n) => n.id === SQ.course);
    if (t) return autopilot(g, t);
    const d = Math.hypot(at(SQ.course).x - SPACE.x, at(SQ.course).y - SPACE.y) / AU;
    g.ui.toast(`Course set for ${BODY[SQ.course].name}, ${d.toFixed(2)} AU out. Engage cruise (RUN) and let go of the stick.`, 'good');
  }));
}
