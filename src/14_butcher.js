// RHAPSODY — gore, the second cut. Wounds stay where they land: bullet holes that weep
// down the shirt, knife cuts, bruises that go from red to purple to yellow, a split lip, a
// black eye. A point-blank shotgun blast takes the head clean off in a red cloud. And a
// knife turns a body into a problem you can solve: take the head, take the limbs, skin
// it. Without a face or fingerprints, nobody can say who it was; parts go in a bag, and a
// bag goes in the harbor. Everything here respects the Blood & gore setting.
'use strict';
(function () {
  const D = R.data, O = D.O, TS = R.TILE;
  const G = () => R.game;
  const on = () => G() && G().settings.gore !== false;
  const BU = (R.butcher = {});
  const wnd = (a) => { a.wnd = a.wnd || { bruise: 0, bleed: 0 }; if (a.look) a.look._w = a.wnd; return a.wnd; };

  // ---------------------------------------------------------------- where it hit
  BU.mark = function (a, amt, source, kind) {
    const w = wnd(a), g = G();
    const blade = source && ((D.weapons[source.weapon] && D.weapons[source.weapon].blade) || (source.held && source.held.k === 'bottle'));
    const k = kind === 'melee' ? (blade ? 'cut' : 'bruise') : kind === 'bullet' ? 'hole' : kind === 'blast' ? 'burn' : kind === 'car' ? 'bruise' : null;
    if (!k) return;
    w.marks = w.marks || [];
    const face = k === 'bruise' ? R.rng() < 0.6 : R.rng() < 0.15;
    w.marks.push({ k, x: R.rng.int(-3, 2), y: face ? R.rng.int(-18, -13) : R.rng.int(-10, -5), t: g.clock.t, n: amt > 30 ? 2 : 1 });
    if (w.marks.length > 9) w.marks.shift();
  };
  const PAL = { hole: ['#2a0604', '#6a1410'], cut: ['#a8201a', '#e05048'], burn: ['#1a1410', '#3a2a20'] };
  BU.drawMarks = function (g, X, Y, w) {
    const now = G().clock.t;
    for (const m of w.marks) {
      const x = X + m.x, y = Y + m.y, age = now - m.t;
      if (m.k === 'hole') {
        // a hole, and a stain that runs down the shirt while they bleed
        const run = Math.min(5, 1 + Math.floor(age / 8) + (w.bleed > 0.2 ? 2 : 0));
        g.fillStyle = '#8a1a14'; g.fillRect(x, y + 1, 1, run); if (m.n > 1) g.fillRect(x - 1, y, 3, 2);
        g.fillStyle = PAL.hole[1]; g.fillRect(x - 1, y - 1 + 1, 3, 1);
        g.fillStyle = PAL.hole[0]; g.fillRect(x, y, 1, 1);
      } else if (m.k === 'cut') {
        g.fillStyle = PAL.cut[0]; g.fillRect(x - 1, y + 1, 1, 1); g.fillRect(x, y, 1, 1); g.fillRect(x + 1, y - 1, 1, 1);
        if (m.n > 1) { g.fillRect(x + 2, y - 2, 1, 1); g.fillStyle = '#8a1a14'; g.fillRect(x, y + 1, 1, Math.min(4, 1 + age / 10)); }
        g.fillStyle = PAL.cut[1]; g.fillRect(x, y, 1, 1);
      } else if (m.k === 'burn') {
        g.fillStyle = PAL.burn[0]; g.fillRect(x - 1, y, 3, 2); g.fillStyle = PAL.burn[1]; g.fillRect(x, y - 1, 2, 1);
      } else {
        // bruises age: angry red, then purple, then a sick yellow-green, then gone
        if (age > 1440 * 3) continue;
        const c = age < 60 ? '#b8404a' : age < 1440 ? '#5a2a6e' : '#8a8a3a';
        g.globalAlpha = age > 1440 * 2 ? 0.5 : 0.9;
        g.fillStyle = c; g.fillRect(x, y, 2, 1); if (m.n > 1) g.fillRect(x, y + 1, 1, 1);
        g.globalAlpha = 1;
      }
    }
    // a black eye and a split lip for the badly beaten
    if (w.bruise > 0.5) { g.fillStyle = '#3a1a4a'; g.fillRect(X - 3, Y - 17, 2, 1); g.fillStyle = '#a8201a'; g.fillRect(X, Y - 14, 1, 1); }
  };

  // ---------------------------------------------------------------- corpses, rebuilt pixel by pixel
  const cache = new Map();
  const MUSCLE = ['#3a0808', '#6a1210', '#98241c', '#c04232', '#d86a58'];
  const BONE = ['#6a6254', '#a89e88', '#d8d0bc', '#f0ead8'];
  BU.corpseArt = function (look, w) {
    const k = `${look.seedStr || ''}|${look.skin}|${w.headless ? 1 : 0}${w.limbs ? 1 : 0}${w.flayed ? 1 : 0}${w.armless ? 1 : 0}`;
    let cv = cache.get(k);
    if (cv) return cv;
    const spr = R.art.oldSprite(look, 2, 0, null);
    cv = document.createElement('canvas'); cv.width = spr.width; cv.height = spr.height;
    const g = cv.getContext('2d'); g.drawImage(spr, 0, 0);
    const img = g.getImageData(0, 0, cv.width, cv.height), d = img.data, W = cv.width;
    const set = (x, y, hex) => { const i = (y * W + x) * 4; d[i] = parseInt(hex.slice(1, 3), 16); d[i + 1] = parseInt(hex.slice(3, 5), 16); d[i + 2] = parseInt(hex.slice(5, 7), 16); d[i + 3] = 255; };
    const clear = (x, y) => { d[(y * W + x) * 4 + 3] = 0; };
    const lum = (x, y) => { const i = (y * W + x) * 4; return (d[i] * 0.3 + d[i + 1] * 0.59 + d[i + 2] * 0.11) / 255; };
    const solid = (x, y) => d[(y * W + x) * 4 + 3] > 10;
    if (w.flayed) {
      for (let y = 0; y < cv.height; y++) for (let x = 0; x < W; x++) {
        if (!solid(x, y)) continue;
        const l = lum(x, y);
        if (l < 0.1) continue; // keep the outline
        if (y <= 14) set(x, y, BONE[Math.min(3, Math.floor(l * 4 + 1))]);
        else set(x, y, MUSCLE[Math.min(4, Math.floor(l * 4) + ((x + (y >> 1)) % 3 === 0 ? 1 : 0))]);
      }
      if (!w.headless) { set(5, 10, '#1a0a08'); set(10, 10, '#1a0a08'); set(5, 9, '#3a2a20'); set(10, 9, '#3a2a20'); for (let x = 6; x <= 9; x++) set(x, 13, x % 2 ? '#f0ead8' : '#6a6254'); }
    }
    if (w.headless) {
      for (let y = 0; y <= 14; y++) for (let x = 0; x < W; x++) clear(x, y);
      for (let x = 5; x <= 10; x++) { set(x, 14, '#3a0808'); set(x, 15, x === 7 || x === 8 ? '#e8e0cc' : '#a8201a'); }
    }
    if (w.limbs || w.armless) {
      for (let y = 15; y <= 21; y++) for (const x of [0, 1, 2, 13, 14, 15]) clear(x, y);
      for (const y of [16, 17]) { set(3, y, '#a8201a'); set(12, y, '#a8201a'); }
    }
    if (w.limbs) {
      for (let y = 22; y < cv.height; y++) for (let x = 0; x < W; x++) clear(x, y);
      for (let x = 4; x <= 11; x++) set(x, 22, x === 5 || x === 10 ? '#e8e0cc' : x % 3 ? '#a8201a' : '#6a1210');
    }
    g.putImageData(img, 0, 0);
    cache.set(k, cv);
    if (cache.size > 200) cache.delete(cache.keys().next().value);
    return cv;
  };
  const special = (w) => w && (w.flayed || w.limbs || w.headless || w.armless);

  // ---------------------------------------------------------------- head shots
  BU.burst = function (h, ang) {
    const g = G(), w = wnd(h);
    w.headless = true; w.burst = true;
    const x = h.x, y = h.y - 18;
    g.fx.spray(x, y, ang, 26); g.fx.spray(x, y, ang + 0.6, 12); g.fx.spray(x, y, ang - 0.6, 12); g.fx.spray(x, y, -Math.PI / 2, 10);
    for (let k = 0; k < 14; k++) { const a = ang + (R.rng() - 0.5) * 1.8, sp = 60 + R.rng() * 150; g.fx.add({ x, y, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - 40, g: 260, life: 1.2, max: 1.2, c: R.rng.pick(['#e8e0cc', '#d8a0a0', '#c86a6a', '#f0ead8', (h.look && h.look.hair) || '#2a2a2a']), s: R.rng() < 0.5 ? 2 : 1, floor: h.y + (R.rng() - 0.3) * 18, stain: 1 }); }
    const dx = Math.cos(ang) * 14, dy = Math.sin(ang) * 8;
    g.fx.decal({ x: h.x + dx, y: h.y + dy, r: 5, grow: 14, rate: 4, c: 'rgba(110,14,12,0.7)', t: 900 });
    g.fx.decal({ x: h.x + dx * 1.8, y: h.y + dy * 1.8, r: 2, grow: 6, rate: 3, c: 'rgba(140,30,30,0.55)', t: 900 });
    g.cam.shake(4);
    g.hitStop = Math.max(g.hitStop || 0, 0.08);
    if (h.person) h.person.unidentified = h.person.unidentified || R.rng() < 0.5;
  };

  // ---------------------------------------------------------------- the knife
  BU.body = function (pl) {
    const g = G();
    return g.actors.near(pl.x, pl.y, TS * 1.4, (q) => q.kind === 'h' && q.dead && !q.carried && !q.sunk && !q.hidden && !q.gibbed)[0];
  };
  BU.partsNear = function (pl) { return R.gore.parts.filter((p) => p.rest && !p.bagged && R.dist(p.x, p.y, pl.x, pl.y) < TS * 2.2); };
  BU.work = function (a, what, fn) {
    const g = G(), pl = g.player;
    g.audio.sfx('stab', a.x, a.y);
    setTimeout(() => g.audio.sfx('stab', a.x, a.y), 250);
    g.fx.blood(a.x + 8, a.y - 2, 10);
    g.fx.decal({ x: a.x + 6, y: a.y, r: 3, grow: 8, rate: 2, c: 'rgba(96,14,12,0.6)', t: 900 });
    pl.bloody = Math.min(1, pl.bloody + 0.35);
    g.hitStop = Math.max(g.hitStop || 0, 0.06);
    fn();
    if (a.person && (wnd(a).headless || wnd(a).flayed)) {
      a.person.unidentified = true;
      if (R.cases) for (const c of R.cases.state().list) if (c.body && c.body.pid === a.person.id) c.body.who = 'an unidentified body';
    }
    a.looted = true;
    a.mutilated = (a.mutilated || 0) + 1;
    g.actors.noise(a.x, a.y, TS * 4, 'rustle', pl);
    g.law.crime('mutilation', a.x, a.y, {});
    g.ui.toast(what, 'warn');
  };
  BU.drop = function (a, kind, n) {
    const G_ = G();
    for (let i = 0; i < n; i++) {
      const ang = R.rng() * 6.28;
      const pants = (a.look && a.look.bottom) || '#2a2a3a', top = (a.look && (a.look.jacketCol || a.look.top)) || '#3a3a4a';
      const base = { x: a.x + 8 + Math.cos(ang) * 6, y: a.y - 2, floor: a.y + (R.rng() - 0.5) * 10, vx: Math.cos(ang) * 30, vy: -40, rot: R.rng() * 6, vr: (R.rng() - 0.5) * 8, t: 0 };
      if (kind === 'head') R.gore.parts.push(Object.assign(base, { kind: 'head', spr: R.art.oldSprite(a.look, 2, 0, null) }));
      else R.gore.parts.push(Object.assign(base, { kind: 'arm', col: kind === 'leg' ? pants : top, skin: kind === 'leg' ? '#1a1410' : (a.look && a.look.skin) || '#d8a070', leg: kind === 'leg' }));
    }
    if (R.gore.parts.length > 60) R.gore.parts.splice(0, R.gore.parts.length - 60);
  };
  BU.menu = function (a) {
    const g = G(), pl = g.player, w = wnd(a), ui = g.ui;
    const who = a.person && !a.person.unidentified ? `${a.person.first} ${a.person.last}` : 'the body';
    const opts = [];
    if (!w.headless) opts.push({ label: 'Take the head', small: 'No face, no name', fn: () => this.work(a, 'It takes longer than the movies make it look.', () => { w.headless = true; this.drop(a, 'head', 1); }) });
    if (!w.limbs) opts.push({ label: 'Take the arms and legs', small: 'Easier to move, in pieces', fn: () => this.work(a, 'Four pieces, and a lot less body to carry.', () => { w.limbs = true; w.armless = true; this.drop(a, 'arm', 2); this.drop(a, 'leg', 2); }) });
    if (!w.flayed) opts.push({ label: 'Skin it', small: 'Nothing left anyone could recognise', fn: () => this.work(a, 'You work until there\'s nothing left anybody could recognise. Your hands won\'t stop shaking.', () => { w.flayed = true; pl.cool = Math.max(0, pl.cool - 20); }) });
    opts.push({ label: 'Leave it', fn: () => {} });
    ui.choice(`Cut up ${who}`, opts);
  };
  BU.context = function (pl) {
    const g = G();
    if (!on() || pl.inCar || pl.room || pl.carrying) return null;
    const tools = pl.inv.tools;
    // parts: bag them up; bags: get rid of them
    const parts = this.partsNear(pl);
    if (parts.length && (tools.remains || 0) < 6) return { label: `Bag the remains (${parts.length})`, fn: () => { for (const p of parts) p.bagged = true; R.gore.parts = R.gore.parts.filter((p) => !p.bagged); tools.remains = (tools.remains || 0) + 1; g.audio.sfx('loot'); g.ui.toast('Into a garbage bag, tied tight. It\'s heavier than it looks.', 'warn'); } };
    if (tools.remains > 0) {
      const s = R.bodies.spots(pl);
      if (s.water) return { label: `Sink the bag of remains (${tools.remains})`, fn: () => { tools.remains--; R.water && R.water.splash && R.water.splash(s.water.x * TS + 8, s.water.y * TS + 8); g.audio.sfx('splash', pl.x, pl.y); g.ui.toast('A few bubbles, and then the water is flat again.', 'good'); } };
      if (s.trash) return { label: `Dump the bag of remains (${tools.remains})`, fn: () => { tools.remains--; g.audio.sfx('bump', pl.x, pl.y); g.ui.toast('One more black bag in a city full of them.', 'good'); if (R.rng() < 0.25) setTimeout(() => g.pop.addNews(R.rng.pick(g.world.cities).id, 'Sanitation worker makes grisly discovery on his route. Police are "keeping an open mind".'), 20000); } };
    }
    if (!D.weapons[pl.weapon] || !D.weapons[pl.weapon].blade) return null;
    const a = this.body(pl);
    if (!a) return null;
    const w = wnd(a);
    if (w.headless && w.limbs && w.flayed) return null;
    return { label: 'Cut up the body', fn: () => this.menu(a) };
  };

  // ---------------------------------------------------------------- wiring
  BU.init = function (g) {
    if (this.wrapped) return;
    this.wrapped = true;
    const LP = R.Law.prototype;
    if (!LP.CRIMES.mutilation) LP.CRIMES.mutilation = { name: 'Desecrating a Body', bounty: 60, lvl: 2 };
    // record every wound
    const GO = R.gore, hurt = GO.hurt;
    GO.hurt = function (a, amt, source, kind) { hurt.call(this, a, amt, source, kind); if (on()) BU.mark(a, amt, source, kind); };
    const PP = R.Player.prototype, pHurt = PP.hurt;
    PP.hurt = function (amt, src, kind) { const hp0 = this.hp; const r = pHurt.call(this, amt, src, kind); if (this.hp < hp0 && on()) BU.mark(this, amt, src, kind); return r; };
    // point-blank shotgun: the head goes
    const C = R.combat, kill = C.kill;
    C.kill = function (h, source, kind) {
      const was = h && h.dead;
      const wpn = source && source.weapon, k = kind || (h && h.lastHitKind);
      const d = source && source.x != null && h ? R.dist(source.x, source.y, h.x, h.y) : 999;
      // decide before the old decapitation roll: point blank, the head doesn't come off, it comes apart
      const pop = !was && h && h.kind === 'h' && on() && k === 'bullet' && ((wpn === 'shotgun' && d < TS * 3.2 && R.rng() < 0.85) || ((wpn === 'magnum' || wpn === 'rifle') && R.rng() < 0.12));
      const decap = C.decap;
      if (pop) C.decap = function () {};
      let r;
      try { r = kill.call(this, h, source, kind); } finally { C.decap = decap; }
      if (pop && h.dead && !h.gibbed) BU.burst(h, source && source.x != null ? Math.atan2(h.y - source.y, h.x - source.x) : R.rng() * 6.28);
      return r;
    };
    // bodies: the rebuilt corpse; the living: wounds where they landed
    const A = R.art, draw = A.drawPerson;
    A.drawPerson = function (g, x, y, dir, walk, look, st) {
      const w = look && look._w;
      if (!w || !on()) return draw.call(this, g, x, y, dir, walk, look, st);
      st = st || {};
      const X = Math.round(x), Y = Math.round(y);
      if (st.down && special(w)) {
        g.fillStyle = 'rgba(16,12,36,0.45)'; g.fillRect(X - 4, Y - 1, 8, 2);
        const cv = BU.corpseArt(look, w);
        g.save(); g.translate(X, Y - 3); g.rotate(Math.PI / 2); if (st.alpha != null) g.globalAlpha = st.alpha; g.drawImage(cv, -cv.width / 2, -22); g.restore();
        return;
      }
      // wounds get drawn here instead of the older dots
      look._w = w.marks && w.marks.length ? null : w;
      draw.call(this, g, x, y, dir, walk, look, st);
      look._w = w;
      if (!st.down && !st.scale && !st.crouch && st.alpha == null && w.marks && w.marks.length) BU.drawMarks(g, X, Y, w);
    };
    // bodies over a shoulder look like themselves
    R.bodies.drawCarried = function (g, pl) { const a = pl.carrying; if (a) A.drawPerson(g, pl.x + 1, pl.y - 12, 2, 0, a.look, { down: true }); };
    // legs have shoes
    const gd = GO.draw;
    GO.draw = function (g) {
      gd.call(this, g);
      if (!on()) return;
      for (const p of this.parts) if (p.leg) { g.save(); g.translate(Math.round(p.x), Math.round(p.y)); g.rotate(p.rest ? Math.round(p.rot / (Math.PI / 2)) * (Math.PI / 2) : p.rot); g.fillStyle = '#1a1410'; g.fillRect(-1, 3, 3, 3); g.restore(); }
    };
    const ctx = PP.contextAction;
    PP.contextAction = function () { return BU.context(this) || ctx.call(this); };
    D.tools.remains = { name: 'Bag of Remains', price: 0 };
  };
})();
