// The interface. Top screen: the dialogue box (typewriter text, a name tag, choices) and
// toasts. Bottom screen: the Ship Watch, a seventies wrist-computer with apps: the system
// map, the ship editor, cargo, the market, the radio log and your goals.

import type { Game, Ui, Good } from '../game';
import { GOODS } from '../game';
import type { Input } from '../core/input';
import { HULLS, MODS, modIcon, stats, type HullId, type Mod } from '../ship/ship';
import { bodies, planetArt } from '../space/system';
import { spaceState } from '../space/spaceScene';
import { PLANETS, type PlanetId } from '../world/planets';
import { sfx } from '../audio';

const $ = <T extends HTMLElement = HTMLElement>(s: string) => document.querySelector(s) as T;
const esc = (s: string) => s.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c] as string);

type App = 'map' | 'ship' | 'cargo' | 'market' | 'radio' | 'goals';
const APPS: [App, string, string][] = [['map', 'MAP', '◎'], ['ship', 'SHIP', '▣'], ['cargo', 'CARGO', '▤'], ['market', 'TRADE', '¢'], ['radio', 'RADIO', '≋'], ['goals', 'GOALS', '✓']];

export class DsUi implements Ui {
  game: Game;
  app: App = 'goals';
  private box = $('#dialog');
  private queue: { who: string; text: string; choices?: { label: string; fn: () => void }[] }[] = [];
  private typing = 0;
  private full = '';
  private open = false;
  selected: Mod | null = null;
  marketAt: PlanetId | null = null;

  constructor(game: Game) {
    this.game = game;
    const tabs = $('#apps');
    tabs.innerHTML = APPS.map(([id, label, ic]) => `<button data-app="${id}"><i>${ic}</i>${label}</button>`).join('');
    tabs.addEventListener('click', (e) => { const b = (e.target as HTMLElement).closest('button'); if (b) { sfx('blip'); this.openApp(b.dataset.app as App); } });
    this.box.addEventListener('pointerdown', (e) => { if (!(e.target as HTMLElement).closest('button')) this.advance(); });
  }

  // ---------------------------------------------------------------- dialogue
  say(who: string, text: string, choices?: { label: string; fn: () => void }[]): void {
    this.queue.push({ who, text, choices });
    if (!this.open) this.next();
  }
  busy(): boolean { return this.open; }
  private next(): void {
    const m = this.queue.shift();
    if (!m) { this.open = false; this.box.hidden = true; return; }
    this.open = true;
    this.box.hidden = false;
    this.full = m.text; this.typing = 0;
    this.box.innerHTML = `<b class="who">${esc(m.who)}</b><p></p><div class="choices"></div><span class="more">▼</span>`;
    const ch = this.box.querySelector('.choices') as HTMLElement;
    if (m.choices) {
      ch.innerHTML = m.choices.map((c, i) => `<button data-i="${i}">${esc(c.label)}</button>`).join('');
      ch.addEventListener('click', (e) => {
        const b = (e.target as HTMLElement).closest('button'); if (!b) return;
        sfx('blip');
        const c = m.choices![+(b.dataset.i as string)];
        this.next();
        c.fn();
      });
    }
    this.box.dataset.choices = m.choices ? '1' : '';
  }
  private advance(): void {
    if (!this.open) return;
    if (this.typing < this.full.length) { this.typing = this.full.length; return; }
    if (this.box.dataset.choices) return; // pick an option
    sfx('blip');
    this.next();
  }
  // per frame: type the text out, and let A/B advance the box
  tick(dt: number, input: Input): void {
    if (!this.open) return;
    const p = this.box.querySelector('p') as HTMLElement;
    if (this.typing < this.full.length) { this.typing = Math.min(this.full.length, this.typing + dt * 60); p.textContent = this.full.slice(0, Math.floor(this.typing)); }
    else if (p.textContent !== this.full) p.textContent = this.full;
    this.box.classList.toggle('done', this.typing >= this.full.length);
    if (input.pressed('a') || input.pressed('b')) {
      if (this.box.dataset.choices && this.typing >= this.full.length && input.pressed('a')) {
        // A picks the first choice
        (this.box.querySelector('.choices button') as HTMLButtonElement | null)?.click();
      } else this.advance();
    }
  }

  toast(text: string, kind: 'good' | 'bad' | '' = ''): void {
    const t = document.createElement('div');
    t.className = 'toast ' + kind; t.textContent = text;
    $('#toasts').appendChild(t);
    setTimeout(() => t.classList.add('out'), 2600);
    setTimeout(() => t.remove(), 3200);
  }

  // ---------------------------------------------------------------- the Ship Watch
  openApp(app: string): void {
    this.app = app as App;
    if (app === 'market') this.marketAt = this.game.location.kind === 'planet' ? this.game.location.planet : null;
    this.refresh();
  }

  refresh(): void {
    const g = this.game;
    document.querySelectorAll('#apps button').forEach((b) => b.classList.toggle('on', (b as HTMLElement).dataset.app === this.app));
    $('#status').innerHTML = `<span>${g.clockLabel()}</span><span>¢${g.credits.toLocaleString()}</span><span class="${g.heat.empire > 10 ? 'hot' : ''}">HEAT ${Math.round(g.heat.empire)}</span>`;
    const body = $('#appbody');
    switch (this.app) {
      case 'map': return this.mapApp(body);
      case 'ship': return this.shipApp(body);
      case 'cargo': return this.cargoApp(body);
      case 'market': return this.marketApp(body);
      case 'radio': body.innerHTML = `<div class="list">${g.log.map((l) => `<p><small>${String(Math.floor(l.t / 60) % 24).padStart(2, '0')}:${String(Math.floor(l.t % 60)).padStart(2, '0')}</small> ${esc(l.text)}</p>`).join('') || '<p>Static.</p>'}</div>`; return;
      case 'goals': body.innerHTML = `<div class="list"><h4>BRASS STARS · v0.1</h4>${g.objectives.map((o) => `<p class="${o.done ? 'done' : ''}">${o.done ? '✓' : '○'} ${esc(o.text)}</p>`).join('')}<p class="hint">Stick moves · A talks/uses · B runs on foot, fires in space · tap the apps above.</p></div>`; return;
    }
  }

  private mapApp(body: HTMLElement): void {
    const g = this.game;
    body.innerHTML = `<canvas id="mapcv" width="240" height="150"></canvas><div class="row" id="jumps"></div>`;
    const cv = body.querySelector('#mapcv') as HTMLCanvasElement, c = cv.getContext('2d') as CanvasRenderingContext2D;
    c.imageSmoothingEnabled = false;
    const B = bodies(g.minutes), k = 70 / 4200, cx = 120, cy = 75;
    c.fillStyle = '#0c0a24'; c.fillRect(0, 0, 240, 150);
    c.strokeStyle = 'rgba(160,150,220,0.35)'; c.setLineDash([2, 3]);
    for (const b of B) { c.beginPath(); c.arc(cx, cy, PLANETS[b.id].orbit * k, 0, 7); c.stroke(); }
    c.setLineDash([]);
    c.strokeStyle = 'rgba(160,150,140,0.25)'; c.lineWidth = 4; c.beginPath(); c.arc(cx, cy, 3300 * k, 0, 7); c.stroke(); c.lineWidth = 1;
    c.fillStyle = '#ffe070'; c.beginPath(); c.arc(cx, cy, 4, 0, 7); c.fill();
    for (const b of B) { const a = planetArt(b.id), s = Math.max(6, b.r / 9); c.drawImage(a, cx + b.x * k - s / 2, cy + b.y * k - s / 2, s, s); c.fillStyle = '#f0ecf8'; c.font = '8px "Pixelify Sans", monospace'; c.fillText(PLANETS[b.id].name, cx + b.x * k + s / 2 + 2, cy + b.y * k + 3); }
    const S = spaceState(g);
    let me = { x: 0, y: 0 };
    if (g.location.kind === 'space' && S) me = { x: S.x, y: S.y };
    else { const b = B.find((x) => x.id === g.location.planet); if (b) me = b; }
    if (S && g.location.kind === 'space') for (const cr of S.crafts) if (!cr.dead) { c.fillStyle = cr.kind === 'patrol' ? '#ff5a5a' : cr.disabled ? '#68f0a0' : '#c8c0b0'; c.fillRect(cx + cr.x * k - 1, cy + cr.y * k - 1, 2, 2); }
    c.fillStyle = '#ffffff'; c.fillRect(cx + me.x * k - 2, cy + me.y * k - 2, 4, 4); c.strokeStyle = '#ff9a3a'; c.strokeRect(cx + me.x * k - 4, cy + me.y * k - 4, 8, 8);
    // hyperlane jumps: only from open space, not in a fight
    const row = body.querySelector('#jumps') as HTMLElement;
    if (g.location.kind === 'space' && S) {
      const hot = S.crafts.some((cr) => !cr.dead && cr.hostile && Math.hypot(cr.x - S.x, cr.y - S.y) < 500);
      row.innerHTML = B.filter((b) => PLANETS[b.id].orbit).map((b) => `<button data-p="${b.id}" ${hot ? 'disabled' : ''}>JUMP ▸ ${PLANETS[b.id].name}</button>`).join('');
      row.onclick = (e) => {
        const bt = (e.target as HTMLElement).closest('button'); if (!bt || hot) return;
        const t = B.find((b) => b.id === bt.dataset.p)!;
        const a = Math.atan2(t.y, t.x);
        S.x = t.x + Math.cos(a) * (t.r + 60); S.y = t.y + Math.sin(a) * (t.r + 60); S.vx = S.vy = 0; S.a = a + Math.PI;
        g.minutes += 180;
        sfx('launch');
        g.radio(`Hyperlane jump to ${PLANETS[t.id].name}. Three hours in the lane.`);
        this.refresh();
      };
    } else row.innerHTML = `<small>On ${PLANETS[g.location.planet].name}. Launch to fly or jump.</small>`;
  }

  private shipApp(body: HTMLElement): void {
    const g = this.game, s = g.ship, H = HULLS[s.hull], st = stats(s);
    const docked = g.location.kind === 'planet';
    const owned = (Object.keys(MODS) as Mod[]).filter((m) => m !== 'cockpit');
    body.innerHTML = `<div class="shiptop"><b>${esc(s.name)}</b> <small>${H.name}</small></div>
      <div class="grid" style="grid-template-columns:repeat(${H.w},1fr);width:calc(${H.w} * 1.7em)">${s.grid.map((m, i) => `<button class="cell ${m ? 'full' : ''}" data-i="${i}" title="${m ? MODS[m].name : 'empty'}"></button>`).join('')}</div>
      <div class="stats">THR ${Math.round(st.thrust)} · PWR ${st.power >= 0 ? '+' : ''}${st.power} · HULL ${st.hull} · SHD ${st.shield} · GUN ${st.guns} · CARGO ${st.cargo}+${st.hidden}</div>
      ${st.problems.length ? `<div class="warn">${st.problems.map(esc).join('<br>')}</div>` : ''}
      ${docked ? `<div class="pal">${owned.map((m) => `<button class="mod ${this.selected === m ? 'on' : ''}" data-m="${m}" title="${MODS[m].name}: ${MODS[m].blurb}"></button>`).join('')}</div>
      <div class="info">${this.selected ? `<b>${MODS[this.selected].name}</b> ¢${MODS[this.selected].price} · ${esc(MODS[this.selected].blurb)}` : 'Pick a module, then tap a slot to fit it. Tap a fitted slot with nothing picked to strip it (half back).'}</div>
      <div class="row">${(Object.keys(HULLS) as HullId[]).filter((h) => h !== s.hull && HULLS[h].price > 0).map((h) => `<button data-h="${h}">${HULLS[h].name} hull ¢${HULLS[h].price.toLocaleString()}</button>`).join('')}</div>`
      : '<div class="info">Refits happen on the ground. Land at a planet to change modules.</div>'}`;
    // draw module icons into the cells and palette
    const icon = (m: Mod) => { const c2 = document.createElement('canvas'); c2.width = 16; c2.height = 16; (c2.getContext('2d') as CanvasRenderingContext2D).drawImage(modIcon(m), 0, 0); return c2; };
    body.querySelectorAll<HTMLButtonElement>('.cell').forEach((b) => { const m = s.grid[+(b.dataset.i as string)]; if (m) b.appendChild(icon(m)); });
    body.querySelectorAll<HTMLButtonElement>('.mod').forEach((b) => b.appendChild(icon(b.dataset.m as Mod)));
    body.onclick = (e) => {
      const t = e.target as HTMLElement;
      const mod = t.closest<HTMLButtonElement>('.mod'), cell = t.closest<HTMLButtonElement>('.cell'), hull = t.closest<HTMLButtonElement>('[data-h]');
      if (mod) { this.selected = this.selected === mod.dataset.m ? null : (mod.dataset.m as Mod); sfx('blip'); return this.refresh(); }
      if (cell && docked) {
        const i = +(cell.dataset.i as string), cur = s.grid[i];
        if (this.selected) {
          const price = MODS[this.selected].price - (cur ? Math.floor(MODS[cur].price / 2) : 0);
          if (cur === 'cockpit') return this.toast('The cockpit stays.', 'bad');
          if (g.credits < price) return this.toast('Not enough credits.', 'bad');
          g.credits -= price; s.grid[i] = this.selected; sfx('coin'); g.complete('upgrade');
        } else if (cur && cur !== 'cockpit') { g.credits += Math.floor(MODS[cur].price / 2); s.grid[i] = null; sfx('door'); }
        g.shipHull = -1;
        return this.refresh();
      }
      if (hull && docked) {
        const h = hull.dataset.h as HullId, NH = HULLS[h];
        if (g.credits < NH.price) return this.toast('Not enough credits.', 'bad');
        // move the modules across, keeping the tail and the nose where they were
        const grid: (Mod | null)[] = new Array(NH.w * NH.h).fill(null);
        for (let y = 0; y < H.h; y++) for (let x = 0; x < H.w; x++) {
          const m = s.grid[y * H.w + x]; if (!m) continue;
          const nx = m === 'cockpit' || m === 'gun' ? NH.w - (H.w - x) : x, ny = y + Math.floor((NH.h - H.h) / 2);
          if (nx >= 0 && nx < NH.w && ny >= 0 && ny < NH.h) grid[ny * NH.w + nx] = m;
        }
        g.credits -= NH.price; s.hull = h; s.grid = grid; s.paint = NH.paint; g.shipHull = -1;
        sfx('coin'); g.complete('upgrade'); this.toast(`New ${NH.name} hull. Your modules came across.`, 'good');
        return this.refresh();
      }
    };
  }

  private cargoApp(body: HTMLElement): void {
    const g = this.game, st = stats(g.ship), u = g.used();
    body.innerHTML = `<div class="list"><h4>BAY ${u.open}/${st.cargo} · HIDDEN ${u.hidden}/${st.hidden}</h4>
      ${g.cargo.filter((l) => l.n > 0).map((l) => `<p>${l.n} × ${GOODS[l.good].name}${l.stolen ? ' <em>stolen</em>' : ''}${GOODS[l.good].contraband ? ' <em>contraband</em>' : ''}${l.hidden ? ' <small>(hidden)</small>' : ''}</p>`).join('') || '<p>Empty holds.</p>'}
      <p class="hint">Stolen cargo in the open bay gets confiscated if you land hot on Veridia. The Smuggler's Hold hides it.</p></div>`;
  }

  private marketApp(body: HTMLElement): void {
    const g = this.game, at = this.marketAt;
    if (!at || g.location.kind !== 'planet' || g.location.planet !== at) { body.innerHTML = '<div class="list"><p>Walk into a market on a planet to trade.</p></div>'; return; }
    const black = at === 'hollow';
    const goods = Object.keys(GOODS) as Good[];
    body.innerHTML = `<div class="list"><h4>${black ? 'BLACK MARKET · HOLLOW MOON' : 'EMERALD EXCHANGE · VERIDIA'}</h4>
      ${goods.map((k) => {
        const p = g.price(at, k), have = g.cargo.filter((l) => l.good === k).reduce((s, l) => s + l.n, 0), hot = g.cargo.filter((l) => l.good === k && l.stolen).reduce((s, l) => s + l.n, 0);
        const canBuy = black || !GOODS[k].contraband;
        return `<div class="trade"><span>${GOODS[k].name}${GOODS[k].contraband ? '*' : ''}</span><b>¢${p}</b><small>${have ? 'have ' + have : ''}</small>
          <button data-b="${k}" ${canBuy ? '' : 'disabled'}>BUY</button><button data-s="${k}" ${have && (black || have > hot) ? '' : 'disabled'}>SELL</button></div>`;
      }).join('')}
      <p class="hint">${black ? 'Stolen goods sell at full price here.' : '*Contraband. Stolen goods won\'t sell here: find a fence.'}</p></div>`;
    body.onclick = (e) => {
      const t = (e.target as HTMLElement).closest('button'); if (!t) return;
      const buy = t.dataset.b as Good | undefined, sell = t.dataset.s as Good | undefined;
      if (buy) {
        const p = g.price(at, buy);
        if (g.credits < p) return this.toast('Not enough credits.', 'bad');
        if (!g.addCargo(buy, 1, false)) return this.toast('No room in the holds.', 'bad');
        g.credits -= p; sfx('coin');
      }
      if (sell) {
        // sell clean goods first; stolen only on the black market
        const lots = g.cargo.filter((l) => l.good === sell && l.n > 0 && (black || !l.stolen)).sort((a, b) => Number(a.stolen) - Number(b.stolen));
        const lot = lots[0]; if (!lot) return;
        lot.n--; g.credits += g.price(at, sell); sfx('coin');
        if (lot.stolen && black) g.complete('fence');
        g.cargo = g.cargo.filter((l) => l.n > 0);
      }
      this.refresh();
    };
  }
}
