// RHAPSODY — one-tap tracking. The TRACK button beside the minimap (T on a keyboard) cycles
// your waypoint through everything you're working on: the current job, the Fear Man's or
// Hal's errand, the spectrum's leads, story leads and map tips. Moving targets (a mark, a
// van) are followed live. The Jobs tab lists the same objectives with a Track button each.
'use strict';
interface Objective { key: string; label: string; x: number; y: number }
interface Tracker {
  sel: string | null;
  t: number;
  wp: { x: number; y: number } | null;
  wired?: boolean;
  list(): Objective[];
  pick(key: string, quiet?: boolean): void;
  cycle(): void;
  update(dt: number): void;
  paint(): void;
  init(game: Game): void;
}
(function () {
  const TS = R.TILE;
  const G = (): Game => R.game;
  const TR: Tracker = (R.track = { sel: null, t: 0, wp: null } as unknown as Tracker);

  // everything worth walking to, right now: [{ key, label, x, y }] in pixels
  TR.list = function () {
    const g = G(), out: Objective[] = [], pl = g.player;
    const add = (key: string, label: string, x: number | null | undefined, y: number | null | undefined) => { if (x != null && y != null && isFinite(x) && isFinite(y)) out.push({ key, label, x, y }); };
    const m = g.jobs.marker();
    const j = g.jobs.active;
    if (m) add('job', `${j ? j.title : 'Job'}${m.label ? ' · ' + m.label : ''}`, m.x, m.y);
    const Q = R.fearQuest, s = pl.fearQ;
    if (Q && s) {
      const q = Q.current();
      if (q && s.active && s.path !== 'green') {
        const at = q.id === 'lantern' ? Q.wreck : q.id === 'pilot' ? Q.strip : q.id === 'moth' ? g.world.cities[0] && { x: g.world.cities[0].cx, y: g.world.cities[0].cy } : null;
        if (at) add('fear', `The Fear Man: ${q.title}`, at.x * TS + 8, at.y * TS + 8);
      }
      if (q && !s.active && s.path !== 'green' && R.ring.fearSpot && R.ring.owned()) add('fearman', 'The Fear Man (1 to 4 AM)', R.ring.fearSpot.x * TS + 8, R.ring.fearSpot.y * TS + 8);
      const gq = Q.gcurrent && Q.gcurrent();
      if (gq) {
        const b = gq.id === 'gardner' ? Q.school() : null;
        const done = (gq.id === 'carol' && s.carolFreed) || (gq.id === 'gardner' && s.guyRing);
        const at = done ? Q.strip : gq.id === 'carol' ? Q.glade : gq.id === 'gardner' ? b && b.out : gq.id === 'showdown' ? R.ring.fearSpot : null;
        if (at) add('hal', done ? 'Hal: report back (airstrip, by day)' : `Hal: ${gq.title}`, at.x * TS + 8, at.y * TS + 8);
      }
    }
    const C = R.campaign && R.campaign.marker && R.campaign.marker();
    if (C && !(m && Math.abs(m.x - C.x) < 2 && Math.abs(m.y - C.y) < 2)) add('saga', `Story: ${C.label || 'next step'}`, C.x, C.y);
    for (const l of g.jobs.leads || []) add('lead:' + l.x + ',' + l.y, `Lead: ${l.text.slice(0, 48)}`, l.x * TS + 8, l.y * TS + 8);
    for (const p of R.poi.pins || []) if (p.kind === 'tip') add('pin:' + p.x + ',' + p.y + p.label, `${p.label}${p.sub ? ' · ' + p.sub : ''}`, p.x * TS + 8, p.y * TS + 8);
    // dedupe by position
    const seen = new Set<string>();
    return out.filter((o) => { const k = Math.round(o.x / TS / 3) + ',' + Math.round(o.y / TS / 3); if (seen.has(k)) return false; seen.add(k); return true; });
  };
  TR.pick = function (key, quiet) {
    const g = G(), o = this.list().find((e) => e.key === key);
    if (!o) return;
    this.sel = key;
    g.waypoint = this.wp = { x: o.x, y: o.y };
    this.t = 1;
    if (R.route) R.route.t = 0;
    if (!quiet) { g.audio.sfx('click'); g.ui.toast(`Tracking: ${o.label}`, 'good'); }
    this.paint();
  };
  TR.cycle = function () {
    const g = G(), L = this.list();
    if (!L.length) { this.sel = null; g.waypoint = null; g.ui.toast('Nothing to track. Find work at a Social Club, or a payphone.', 'warn'); return this.paint(); }
    let i = L.findIndex((e) => e.key === this.sel);
    i++;
    if (i >= L.length) { this.sel = null; g.waypoint = null; g.audio.sfx('click'); g.ui.toast('Tracking off.'); return this.paint(); }
    this.pick(L[i].key, true);
    g.audio.sfx('click');
    g.ui.toast(`Tracking ${i + 1}/${L.length}: ${L[i].label}`, 'good');
  };
  TR.update = function (dt) {
    const g = G();
    if (!this.sel) return;
    this.t -= dt;
    if (this.t > 0) return;
    this.t = 1;
    // arrived (the route clears the waypoint) or you set one yourself: let go
    if (g.waypoint !== this.wp) { this.sel = null; this.wp = null; return this.paint(); }
    const o = this.list().find((e) => e.key === this.sel);
    if (!o) { this.sel = null; this.wp = null; g.waypoint = null; this.paint(); g.ui.toast('That objective is done. Tap TRACK for the next one.'); return; }
    g.waypoint = this.wp = { x: o.x, y: o.y };
  };
  TR.paint = function () {
    const b = document.getElementById('trackbtn');
    if (b) b.classList.toggle('on', !!this.sel);
  };
  TR.init = function (game) {
    this.sel = null; this.wp = null;
    if (this.wired) return this.paint();
    this.wired = true;
    // the button, beside MENU
    const menu = document.getElementById('menubtn');
    const esc = (t: unknown) => String(t).replace(/[&<>"]/g, (m) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' } as Record<string, string>)[m]);
    if (menu && !document.getElementById('trackbtn')) {
      menu.insertAdjacentHTML('beforebegin', '<button id="trackbtn" aria-label="Track the next objective">TRACK</button>');
      const st = document.createElement('style');
      st.textContent = '#trackbtn{border:3px solid var(--ink);background:var(--paper2);color:var(--ink);border-radius:10px;font-size:10px;padding:6px 8px;box-shadow:0 3px 0 var(--ink);margin-right:4px}#trackbtn.on{background:#e4a92a}.maprow{display:flex;align-items:flex-start;gap:0}body.cine #trackbtn{display:none}';
      document.head.appendChild(st);
      const btn = document.getElementById('trackbtn');
      if (btn) btn.addEventListener('click', (e) => { e.stopPropagation(); if (G() && G().started) TR.cycle(); });
    }
    window.addEventListener('keydown', (e) => { if (e.code === 'KeyT' && !e.repeat && G() && G().started && !G().ui.sheetOpen) TR.cycle(); });
    // the Jobs tab: a Track button per objective
    const cj = R.campaign.jobsHtml;
    R.campaign.jobsHtml = function (this: unknown) {
      const L = TR.list();
      const h = L.length ? `<div class="sect">Track on the map</div><div class="opts">${L.map((o) => `<button class="opt ${o.key === TR.sel ? 'go' : ''}" data-trk="${esc(o.key)}">${esc(o.label)}<small>${o.key === TR.sel ? 'Tracking now' : 'Tap to track'}</small></button>`).join('')}</div>` : '';
      return h + cj.call(this);
    };
    document.addEventListener('click', (e) => {
      const el = e.target instanceof Element ? e.target.closest<HTMLElement>('[data-trk]') : null;
      if (!el || !G() || !el.dataset.trk) return;
      TR.pick(el.dataset.trk);
      G().ui.closeSheet();
    });
  };
})();
