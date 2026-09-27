// RHAPSODY — UI: HUD, context chips (Greet / Antagonize / Talk), sheets for talk,
// interiors, shops, the phone, fishing, gambling, burglary, the menu and map.
'use strict';
(function () {
  const D = R.data, T = D.T, TS = R.TILE;
  const $ = (s, r) => (r || document).querySelector(s);
  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

  const UI = (R.UI = function (game) {
    this.game = game;
    this.el = {
      cash: $('#cash'), hp: $('#hpbar i'), cool: $('#coolbar i'), rank: $('#rank'), job: $('#job'), clock: $('#clock'), place: $('#place'),
      wanted: $('#wanted'), toasts: $('#toasts'), subs: $('#subs'), ctx: $('#ctx'), sheet: $('#sheet'), dim: $('#dim'),
      story: $('#story'), death: $('#death'), arrest: $('#arrest'), hurt: $('#hurt'), use: $('#useLabel'), mini: $('#minimap'),
      pad: $('#pad'), wpn: $('#wpnName'), hud: $('#hud'),
    };
    this.miniG = this.el.mini.getContext('2d');
    this.hudT = 0;
    this.focus = null;
    this.subsList = [];
    this.sheetOpen = null;
    this.insideB = null;
    $('#stats').addEventListener('click', () => this.toggleMenu());
    $('#mapwrap').addEventListener('click', () => this.openMenu('map'));
    this.el.dim.addEventListener('click', () => { if (this.sheetOpen && this.sheetOpen !== 'fish' && this.sheetOpen !== 'burgle' && this.sheetOpen !== 'heist') this.closeSheet(); });
    $('#surrender').addEventListener('click', () => { this.closeArrest(); game.law.surrender(); });
    $('#resist').addEventListener('click', () => { this.closeArrest(); game.law.resist('You resisted'); });
    this.el.death.querySelector('button').addEventListener('click', () => { this.el.death.style.display = 'none'; game.player.respawn(); });
    this.el.story.querySelector('button').addEventListener('click', () => this.closeStory());
    this.lastCtxKey = '';
    this.grain();
  });
  const U = UI.prototype;

  U.grain = function () {
    const c = document.createElement('canvas');
    c.width = c.height = 90;
    const g = c.getContext('2d');
    const img = g.createImageData(90, 90);
    for (let i = 0; i < img.data.length; i += 4) {
      const v = Math.random() * 255;
      img.data[i] = img.data[i + 1] = img.data[i + 2] = v;
      img.data[i + 3] = 255;
    }
    g.putImageData(img, 0, 0);
    $('#grain').style.backgroundImage = `url(${c.toDataURL()})`;
    this.setGrain(this.game.settings.grain);
  };
  U.setGrain = function (on) { $('#grain').style.display = on ? 'block' : 'none'; };

  U.modalOpen = function () {
    return !!this.sheetOpen || this.el.story.style.display === 'flex' || this.el.death.style.display === 'flex' || $('#title').style.display === 'flex';
  };
  U.paused = function () {
    return this.sheetOpen === 'menu' || this.sheetOpen === 'shop' || this.el.story.style.display === 'flex' || $('#title').style.display === 'flex' || this.sheetOpen === 'board' || this.sheetOpen === 'phone';
  };

  // ---------------------------------------------------------------- toasts & subtitles
  U.toast = function (msg, kind) {
    const d = document.createElement('div');
    d.className = 'toast ' + (kind || '');
    d.textContent = msg;
    this.el.toasts.appendChild(d);
    const ts = this.el.toasts.querySelectorAll('.toast');
    if (ts.length > (window.innerHeight < 520 ? 2 : 3)) ts[0].remove();
    setTimeout(() => d.remove(), 3800 + msg.length * 30);
  };
  U.subtitle = function (name, text, color) {
    this.subsList.push({ name, text, t: 2.6 + text.length * 0.045 });
    if (this.subsList.length > 2) this.subsList.shift();
    this.renderSubs();
  };
  U.renderSubs = function () {
    this.el.subs.innerHTML = this.subsList.map((s) => `<div><b>${esc(s.name)}:</b>${esc(s.text)}</div>`).join('<br>');
  };

  // ---------------------------------------------------------------- focus & context chips
  U.focusTarget = function () {
    const g = this.game, pl = g.player;
    if (pl.inCar || pl.inside) return null;
    const keep = this.focus && !this.focus.dead && !this.focus.removed && !this.focus.inCar && R.dist(this.focus.x, this.focus.y, pl.x, pl.y) < 46 ? this.focus : null;
    let best = null, bs = 1e9;
    for (const a of g.actors.near(pl.x, pl.y, 40)) {
      if (a.kind !== 'h' || a.dead || a.inCar || a.crew && false) continue;
      const d = R.dist(a.x, a.y, pl.x, pl.y);
      const off = Math.abs(R.angDiff(pl.ang, Math.atan2(a.y - pl.y, a.x - pl.x)));
      if (off > 1.3 && d > 20) continue;
      const s = d + off * 14;
      if (s < bs) { bs = s; best = a; }
    }
    if (keep && (!best || R.dist(best.x, best.y, pl.x, pl.y) > R.dist(keep.x, keep.y, pl.x, pl.y) - 6)) best = keep;
    this.focus = best;
    return best;
  };
  U.focusOn = function (h) { this.focus = h; };

  U.updateCtx = function () {
    const g = this.game, pl = g.player, h = pl.focus;
    const ctx = this.el.ctx;
    const show = h && !h.dead && !pl.inCar && !pl.inside && !this.sheetOpen && h.down <= 0;
    if (!show) {
      if (this.lastCtxKey !== '') { ctx.style.display = 'none'; this.lastCtxKey = ''; }
      return;
    }
    const chips = [];
    chips.push(['greet', 'Greet', 'c-greet']);
    if (h.hostile && h.state === 'fight' && h.brawl) chips.push(['defuse', 'Defuse', 'c-defuse']);
    else chips.push(['antag', 'Antagonize', 'c-antag']);
    chips.push(['talk', 'Talk', 'c-talk']);
    if (!h.cop && (h.intimidated || h.state === 'cower' || h.state === 'surrender' || (pl.weaponOut && R.dialog.fear(h) > 20))) chips.push(['rob', 'Rob', 'c-rob']);
    const name = g.actors.displayName(h);
    const sub = h.person ? (h.person.met ? `${g.pop.title(h.person)} · ${h.person.age}` : 'Greet twice to learn their name') : h.cop ? 'Keep it civil' : h.tag === 'hitch' ? `Needs a ride to ${h.hitchDest.name}` : h.witness && !h.witness.done ? 'Witness! Pay them off or scare them' : h.look.kid ? 'Just a kid' : '';
    const moodTxt = h.state === 'fight' ? ' · hostile' : h.state === 'cower' || h.state === 'surrender' ? ' · scared' : '';
    const key = h.id + chips.map((c) => c[0]).join() + name + sub + moodTxt;
    if (key === this.lastCtxKey) return;
    this.lastCtxKey = key;
    ctx.style.display = 'flex';
    ctx.querySelector('.who').innerHTML = `${esc(name)}${moodTxt}<em>${esc(sub)}</em>`;
    const wrap = ctx.querySelector('.chips');
    wrap.innerHTML = '';
    for (const [k, label, cls] of chips) {
      const b = document.createElement('button');
      b.className = 'chip ' + cls;
      b.textContent = label;
      b.addEventListener('pointerdown', (e) => {
        e.preventDefault();
        e.stopPropagation();
        g.audio.unlock();
        const t = pl.focus;
        if (!t || t.dead) return;
        if (k === 'greet') pl.greet(t);
        if (k === 'antag') pl.antagonize(t);
        if (k === 'talk') pl.talk(t);
        if (k === 'defuse') R.dialog.defuse(t);
        if (k === 'rob') pl.rob(t);
        this.lastCtxKey = '';
      });
      wrap.appendChild(b);
    }
  };

  // ---------------------------------------------------------------- HUD
  U.update = function (dt) {
    const g = this.game, pl = g.player;
    for (const s of this.subsList) s.t -= dt;
    if (this.subsList.length && this.subsList[0].t <= 0) { this.subsList = this.subsList.filter((s) => s.t > 0); this.renderSubs(); }
    this.updateCtx();
    this.el.hud.classList.toggle('incar', !!pl.inCar);
    if (!this.movedOnce && (g.input.stick.x || g.input.stick.y)) { this.movedOnce = true; const hs = $('#hint-stick'); if (hs) hs.remove(); }
    const act = pl.dead || pl.inside ? null : pl.contextAction();
    const al = act ? act.label : '';
    if (this.el.use.textContent !== al) this.el.use.textContent = al;
    this.hudT -= dt;
    if (this.hudT > 0) return;
    this.hudT = 0.12;
    this.el.cash.textContent = R.fmtMoney(pl.cash);
    this.el.hp.style.width = Math.max(0, (pl.hp / pl.maxHp) * 100) + '%';
    this.el.cool.style.width = pl.cool + '%';
    this.el.rank.textContent = `${g.jobs.rankName()} · ${pl.family} family`;
    const j = g.jobs.active;
    let jt = '';
    if (j) {
      const m = g.jobs.marker();
      jt = '▶ ' + j.title;
      if (m) {
        const d = R.dist(pl.x, pl.y, m.x, m.y) / TS;
        const a = Math.atan2(m.y - pl.y, m.x - pl.x);
        const arrows = ['→', '↘', '↓', '↙', '←', '↖', '↑', '↗'];
        jt += ` · ${arrows[((Math.round(a / (Math.PI / 4)) % 8) + 8) % 8]} ${Math.round(d * 3)}m`;
      }
      if (j.left !== undefined && j.stage === 2) jt += ` · ${Math.max(0, Math.ceil(j.left))} min`;
    }
    if (this.el.job.textContent !== jt) this.el.job.textContent = jt;
    const w = g.env.weather;
    this.el.clock.textContent = `${g.clock.weekday()} ${g.clock.label()}`;
    const city = g.world.cityAt((pl.x / TS) | 0, (pl.y / TS) | 0);
    let place = city ? city.name : this.nearHamlet() || 'The County';
    if (pl.inCar && g.audio.mode === 'radio') place += ' · 📻';
    this.el.place.textContent = `${place} · ${g.env.WEATHER_NAMES[w.kind]}`;
    const ww = D.weapons[pl.weapon];
    this.el.wpn.textContent = pl.weapon === 'gascan' ? 'Gas' : ww ? (ww.gun ? `${pl.clip[pl.weapon] || 0}/${pl.inv.ammo[ww.ammo] || 0}` : ww.thrown ? 'x' + (pl.inv.ammo[pl.weapon] || 0) : ww.name.split(' ').pop()) : '';
    $('#mCool').classList.toggle('lit', pl.coolOn);
    $('#mMask').classList.toggle('lit', pl.masked);
    $('#mSneak').classList.toggle('lit', pl.sneak);
    // wanted banner
    const inc = g.law.incident;
    const wb = this.el.wanted;
    if (inc) {
      wb.style.display = 'block';
      const lvl = ['', 'WANTED', 'DANGEROUS', 'SHOOT ON SIGHT'][inc.level];
      const b = g.law.bounty[inc.jur] || 0;
      wb.querySelector('b').textContent = `${lvl} · ${g.law.jurName(inc.jur)}`;
      let s = inc.state === 'pursuit' ? 'Police in pursuit' : inc.state === 'responding' ? 'Police responding' : `Searching · ${Math.max(0, Math.ceil(inc.searchLeft))}s`;
      if (!inc.identified) s += ' · unidentified';
      else if (b) s += ' · ' + R.fmtMoney(b);
      wb.querySelector('span').textContent = s;
      wb.className = inc.state === 'pursuit' ? 'pulse' : inc.state === 'search' ? 'search' : '';
    } else {
      const wit = g.actors.list.some((a) => a.witness && !a.witness.done && !a.witness.silenced && !a.dead);
      if (wit) {
        wb.style.display = 'block';
        wb.className = 'search';
        wb.querySelector('b').textContent = 'Witness';
        wb.querySelector('span').textContent = 'Someone is running to report you';
      } else wb.style.display = 'none';
    }
    this.drawMini();
  };
  U.nearHamlet = function () {
    const g = this.game, pl = this.game.player;
    for (const h of g.world.hamlets) if (R.dist(pl.x / TS, pl.y / TS, h.cx, h.cy) < 26) return h.name;
    return null;
  };

  U.drawMini = function () {
    const g = this.game, pl = g.player, c = this.miniG, S = 216;
    const scale = pl.inCar ? 1.4 : 2.2; // px per tile
    const ptx = pl.x / TS, pty = pl.y / TS;
    c.save();
    c.clearRect(0, 0, S, S);
    c.beginPath(); c.arc(S / 2, S / 2, S / 2, 0, 7); c.clip();
    c.imageSmoothingEnabled = false;
    c.fillStyle = '#1f5566';
    c.fillRect(0, 0, S, S);
    const span = S / scale;
    c.drawImage(g.miniMap, ptx - span / 2, pty - span / 2, span, span, 0, 0, S, S);
    const toM = (x, y) => [S / 2 + (x / TS - ptx) * scale, S / 2 + (y / TS - pty) * scale];
    // search circle
    const inc = g.law.incident;
    if (inc && inc.state !== 'pursuit') {
      const [cx, cy] = toM(inc.lastX, inc.lastY);
      c.fillStyle = 'rgba(228,169,42,0.25)';
      c.strokeStyle = '#e4a92a';
      c.lineWidth = 2;
      c.beginPath(); c.arc(cx, cy, g.law.searchRadius() / TS * scale, 0, 7); c.fill(); c.stroke();
    }
    // blips
    for (const a of g.actors.list) {
      if (a.dead || a.removed) continue;
      const [x, y] = toM(a.x, a.y);
      if (x < 0 || y < 0 || x > S || y > S) continue;
      if (a.cop) { c.fillStyle = (performance.now() / 250) % 2 < 1 ? '#3050ff' : '#ff3030'; c.fillRect(x - 3, y - 3, 6, 6); }
      else if (a.witness && !a.witness.done && !a.witness.silenced) { c.fillStyle = '#e4a92a'; c.fillRect(x - 3, y - 3, 6, 6); }
      else if (a.hostile && a.state === 'fight') { c.fillStyle = '#c8321e'; c.fillRect(x - 2, y - 2, 5, 5); }
      else if (a.crew) { c.fillStyle = '#8ab04a'; c.fillRect(x - 2, y - 2, 5, 5); }
    }
    for (const v of g.traffic.list) {
      if (v.modelId !== 'police' || !v.siren) continue;
      const [x, y] = toM(v.x, v.y);
      c.fillStyle = '#3050ff'; c.fillRect(x - 3, y - 3, 7, 7);
    }
    // job marker / leads
    const m = g.jobs.marker();
    const drawPin = (mx, my, col) => {
      let [x, y] = toM(mx, my);
      const dx = x - S / 2, dy = y - S / 2, d = Math.hypot(dx, dy);
      if (d > S / 2 - 8) { x = S / 2 + (dx / d) * (S / 2 - 8); y = S / 2 + (dy / d) * (S / 2 - 8); }
      c.fillStyle = col; c.strokeStyle = '#1b1410'; c.lineWidth = 2;
      c.beginPath(); c.arc(x, y, 6, 0, 7); c.fill(); c.stroke();
    };
    for (const l of g.jobs.leads) drawPin(l.x * TS, l.y * TS, '#7a8a2e');
    if (g.waypoint) drawPin(g.waypoint.x, g.waypoint.y, '#f2e2c0');
    if (m) drawPin(m.x, m.y, '#e4a92a');
    // player arrow
    c.translate(S / 2, S / 2);
    c.rotate((pl.inCar ? pl.inCar.angle : pl.ang) + Math.PI / 2);
    c.fillStyle = '#d9621e'; c.strokeStyle = '#1b1410'; c.lineWidth = 2;
    c.beginPath(); c.moveTo(0, -9); c.lineTo(7, 7); c.lineTo(0, 3); c.lineTo(-7, 7); c.closePath(); c.fill(); c.stroke();
    c.restore();
  };

  U.hurtFlash = function (amt) {
    this.el.hurt.style.boxShadow = `inset 0 0 90px 30px rgba(200,20,10,${Math.min(0.7, amt / 30)})`;
    clearTimeout(this.hurtT);
    this.hurtT = setTimeout(() => (this.el.hurt.style.boxShadow = 'inset 0 0 90px 30px rgba(200,20,10,0)'), 180);
  };
  U.death = function () {
    this.closeSheet();
    const d = this.el.death;
    d.querySelector('p').textContent = R.rng.pick(['Somebody put you down. The hospital will patch you up, for a price.', 'You took a dirt nap. The Brass Coast keeps spinning without you, for a few hours anyway.', 'Lights out, Nicky. Wake up and try to duck next time.']);
    d.style.display = 'flex';
  };
  U.story = function (title, text, cb) {
    const s = this.el.story;
    s.querySelector('h1').textContent = title;
    s.querySelector('p').textContent = text;
    s.style.display = 'flex';
    this.storyCb = cb;
  };
  U.closeStory = function () {
    this.el.story.style.display = 'none';
    const cb = this.storyCb;
    this.storyCb = null;
    if (cb) cb();
  };
  U.arrestPrompt = function () { this.el.arrest.style.display = 'flex'; };
  U.closeArrest = function () { this.el.arrest.style.display = 'none'; };

  // ---------------------------------------------------------------- sheets
  U.openSheet = function (kind, html, center) {
    const s = this.el.sheet;
    s.className = 'sheet' + (center ? ' center' : '');
    s.innerHTML = html;
    s.style.display = 'flex';
    this.el.dim.style.display = 'block';
    this.sheetOpen = kind;
    const x = s.querySelector('header .x');
    if (x) x.addEventListener('click', () => this.closeSheet());
    return s;
  };
  U.closeSheet = function () {
    const was = this.sheetOpen;
    this.el.sheet.style.display = 'none';
    this.el.dim.style.display = 'none';
    this.sheetOpen = null;
    if (was === 'talk' && this.talkH) { this.talkH.state = 'idle'; this.talkH.timer = 1; this.talkH = null; }
    if (this.insideB && was !== 'talk' && was !== 'shop' && was !== 'board') this.leaveBuilding();
    if (this.onClose) { const f = this.onClose; this.onClose = null; f(); }
  };
  U.header = function (title, sub, portrait) {
    return `<header>${portrait ? '<canvas class="portrait" width="28" height="36"></canvas>' : ''}<div><h2>${esc(title)}</h2>${sub ? `<p>${esc(sub)}</p>` : ''}</div><button class="x" aria-label="Close">✕</button></header>`;
  };
  U.optsHtml = function (opts) {
    return `<div class="opts">${opts.map((o, i) => `<button class="opt ${o.cls || ''}" data-i="${i}">${o.price !== undefined ? `<span class="p">${o.price}</span>` : ''}${esc(o.label)}${o.small ? `<small>${esc(o.small)}</small>` : ''}</button>`).join('')}</div>`;
  };
  U.bindOpts = function (root, opts) {
    root.querySelectorAll('.opt[data-i]').forEach((b) => {
      b.addEventListener('click', () => {
        this.game.audio.sfx('click');
        const o = opts[+b.dataset.i];
        if (o && o.fn) o.fn();
      });
    });
  };
  U.drawPortrait = function (cv, look) {
    if (!cv) return;
    const g = cv.getContext('2d');
    g.clearRect(0, 0, cv.width, cv.height);
    g.fillStyle = '#e6d0a4';
    g.fillRect(0, 0, cv.width, cv.height);
    R.art.drawPerson(g, cv.width / 2, cv.height - 3, 2, 0, look, {});
  };

  U.choice = function (title, opts) {
    const wrapped = opts.map((o) => ({ label: o.label, small: o.small, fn: () => { this.closeSheet(); o.fn && o.fn(); } }));
    const s = this.openSheet('choice', this.header(title) + `<div class="body">${this.optsHtml(wrapped)}</div>`);
    this.bindOpts(s, wrapped);
  };

  // ---------------------------------------------------------------- talk
  U.openTalk = function (h) {
    const g = this.game;
    this.talkH = h;
    const t = R.dialog.tree(h);
    const s = this.openSheet('talk', this.header(t.title, t.sub, true) + `<div class="body"><div class="line" id="tline">${h.person && h.person.met ? '' : '<b>' + esc(t.title) + '</b> looks you over.'}</div>${this.optsHtml(t.options)}</div>`);
    this.drawPortrait(s.querySelector('.portrait'), h.look);
    this.bindOpts(s, t.options);
    if (h.person && h.person.met) this.talkLine(R.dialog.mood(h) > 20 ? R.rng.pick(['What can I do for ya?', 'Good to see you.', 'Hey, you.']) : R.rng.pick(['Yeah?', 'Make it quick.', 'What.']));
  };
  U.talkLine = function (text) {
    const el = $('#tline');
    if (el) el.textContent = '“' + text + '”';
    if (this.talkH) this.game.actors.say(this.talkH, text);
  };
  U.closeTalk = function () { this.closeSheet(); };

  // ---------------------------------------------------------------- interiors
  U.isOpen = function (b) {
    const bt = D.btypes[b.type];
    if (!bt.hours) return false;
    let [o, c] = bt.hours;
    const h = this.game.clock.hour();
    if (c === 24 && o === 0) return true;
    if (c <= o) return h >= o || h < c;
    return h >= o && h < c;
  };
  U.enterBuilding = function (b) {
    const g = this.game, pl = g.player;
    const bt = D.btypes[b.type];
    const open = this.isOpen(b) || b.playerOwned;
    const isHome = !!bt.house && !bt.hours;
    if (!open && !isHome) {
      const opts = [];
      if (b.type !== 'police' && b.type !== 'hospital') opts.push({ label: 'Break in', small: pl.inv.tools.lockpick ? 'Uses a lockpick. Quiet, but someone may see.' : 'No lockpick: you\'ll have to force it. Noisy.', fn: () => this.breakIn(b) });
      opts.push({ label: 'Walk away', fn: () => {} });
      return this.choice(`${b.name} — closed (opens ${bt.hours[0]}:00)`, opts);
    }
    this.insideB = b;
    pl.inside = b;
    pl.weaponOutBefore = pl.weaponOut;
    this.renderInterior();
    // cops search buildings you duck into while being chased
    const inc = g.law.incident;
    if (inc && inc.state === 'pursuit') this.toast('They saw you go in. Better not stay long.', 'warn');
    else if (inc) this.toast('Lying low inside. The search clock runs faster while you hide.', 'good');
  };
  U.leaveBuilding = function () {
    const g = this.game, pl = g.player, b = this.insideB;
    this.insideB = null;
    pl.inside = null;
    if (b) pl.place(b.out.x * TS + 8, b.out.y * TS + 10);
  };
  U.renderInterior = function (msg) {
    const g = this.game, pl = g.player, b = this.insideB;
    if (!b) return;
    const bt = D.btypes[b.type];
    const occ = g.life.occupants(b).slice(0, 12);
    const opts = this.interiorOptions(b);
    const people = occ.map((p) => `<div class="person"><canvas class="portrait" width="28" height="36" style="width:28px;height:36px" data-p="${p.id}"></canvas><div class="n">${esc(p.met ? g.pop.name(p) : g.pop.title(p))}<small>${esc(p.met ? g.pop.title(p) + ' · ' + p.age : 'Stranger')}</small></div><div class="meter" title="Opinion of you"><i style="width:${50 + p.opinion / 2}%;background:${p.opinion > 20 ? 'var(--good)' : p.opinion < -20 ? 'var(--red)' : 'var(--mustard)'}"></i></div><button data-g="${p.id}">Greet</button><button data-t="${p.id}">Talk</button></div>`).join('');
    const hours = bt.hours ? (bt.hours[0] === 0 && bt.hours[1] === 24 ? 'Open 24 hours' : `Open ${bt.hours[0]}:00–${bt.hours[1] % 24}:00`) : 'Private residence';
    const sub = `${bt.name} · ${b.city.name || 'County'} · ${hours}`;
    const s = this.openSheet('interior', this.header(b.name, sub) + `<div class="body">${msg ? `<div class="line" id="tline">${esc(msg)}</div>` : '<div class="line" id="tline"></div>'}${this.optsHtml(opts)}${occ.length ? `<div class="sect">Inside (${occ.length})</div><div class="people">${people}</div>` : ''}</div>`);
    this.bindOpts(s, opts);
    s.querySelectorAll('canvas[data-p]').forEach((cv) => this.drawPortrait(cv, g.pop.people[+cv.dataset.p].look));
    s.querySelectorAll('button[data-g]').forEach((btn) => btn.addEventListener('click', () => this.interiorGreet(g.pop.people[+btn.dataset.g])));
    s.querySelectorAll('button[data-t]').forEach((btn) => btn.addEventListener('click', () => this.interiorTalk(g.pop.people[+btn.dataset.t])));
  };
  // talking to someone inside: spawn them invisibly next to the player so the same trees work
  U.proxy = function (p) {
    const g = this.game, pl = g.player, b = this.insideB;
    const h = g.life.spawnPerson(p, pl.x, pl.y);
    if (!h) return null;
    h.proxyOf = b;
    h.keep = true;
    h.state = 'talk';
    h.timer = 999;
    h.destKey = 'b:' + b.id;
    h.insideProxy = true;
    return h;
  };
  U.dropProxy = function (h) {
    if (!h || !h.insideProxy || h.dead) return;
    h.person.place = 'b:' + h.proxyOf.id;
    this.game.actors.remove(h);
  };
  U.interiorGreet = function (p) {
    const g = this.game;
    const h = p.actor || this.proxy(p);
    if (!h) return;
    const mood = R.dialog.mood(h);
    R.dialog.greet(h);
    setTimeout(() => {
      const last = g.ui.subsList[g.ui.subsList.length - 1];
      const el = $('#tline');
      if (el && last) el.textContent = `${last.name}: “${last.text}”`;
      this.dropProxy(h);
      if (this.sheetOpen === 'interior') this.renderInterior(el ? el.textContent : '');
    }, 900);
  };
  U.interiorTalk = function (p) {
    const h = p.actor || this.proxy(p);
    if (!h) return;
    this.onClose = () => { this.dropProxy(h); if (this.insideB) setTimeout(() => this.insideB && this.renderInterior(), 0); };
    this.talkH = h;
    const t = R.dialog.tree(h);
    const s = this.openSheet('talk', this.header(t.title, t.sub, true) + `<div class="body"><div class="line" id="tline"></div>${this.optsHtml(t.options)}</div>`);
    this.drawPortrait(s.querySelector('.portrait'), h.look);
    this.bindOpts(s, t.options);
  };

  U.interiorOptions = function (b) {
    const g = this.game, pl = g.player, bt = D.btypes[b.type];
    const opts = [];
    const say = (s) => { const el = $('#tline'); if (el) el.textContent = s; };
    const buy = (label, price, fn, small) => opts.push({ label, price: R.fmtMoney(price), small, fn: () => { if (!pl.pay(price)) return say("You're short on cash."); fn(); g.audio.sfx('cash'); } });
    const cons = (id) => buy(D.consumables[id].name, D.consumables[id].price, () => { pl.inv.cons[id] = (pl.inv.cons[id] || 0) + 1; say(`Bought ${D.consumables[id].name}. (${pl.inv.cons[id]} in pocket, ITEM uses them)`); });
    switch (bt.shop) {
      case 'general': cons('bandage'); cons('sandwich'); cons('smokes'); cons('coffee'); buy('Lockpick', 15, () => { pl.inv.tools.lockpick = (pl.inv.tools.lockpick || 0) + 1; say('Lockpick in your pocket.'); }); buy('Fishing Rod', 30, () => { pl.inv.tools.rod = 1; say('Rod bought. Stand by water and press USE.'); }); buy('Bait', 2, () => { pl.inv.tools.bait = (pl.inv.tools.bait || 0) + 3; say('3 bait.'); }); break;
      case 'liquor': cons('whiskey'); cons('smokes'); buy('Molotov fixings', 25, () => { pl.inv.ammo.molotov = (pl.inv.ammo.molotov || 0) + 1; say('A bottle, a rag, and bad intentions.'); }); break;
      case 'pharmacy': cons('bandage'); cons('tonic'); cons('coffee'); break;
      case 'diner': buy('Blue plate special (eat now)', 6, () => { pl.hp = Math.min(pl.maxHp, pl.hp + 45); say('Meatloaf, mashed potatoes, pie. You feel human again.'); }); cons('sandwich'); cons('coffee'); break;
      case 'bar':
        buy('Whiskey, neat', 3, () => { pl.drink(); say('Burns going down. Feels cool.'); });
        buy('Buy the room a round', 25, () => { g.jobs.roundForHouse({ x: pl.x, y: pl.y }); say('The whole bar raises a glass to you.'); });
        opts.push({ label: 'Play poker dice', small: b.poker === g.pop.day ? 'High-stakes game tonight!' : 'Friendly game', fn: () => this.gamble(b.poker === g.pop.day ? 0.52 : 0.46, b.poker === g.pop.day ? 100 : 20) });
        break;
      case 'club':
        buy('Cover charge & dance', 5, () => { pl.cool = Math.min(100, pl.cool + 45); pl.rep.honor += 0.5; say('You tear up the light-up floor. Everyone saw. COOL restored.'); });
        buy('Tequila Sunrise', 5, () => { pl.drink(); say('Tastes like a sunset in Dustwater.'); });
        break;
      case 'pawn': opts.push({ label: 'Sell your goods', fn: () => this.openShop('pawn') }); buy('Brass Knuckles', 40, () => { pl.giveWeapon('knuckles'); say('Knuckles. Fits like a wedding ring.'); }); buy('Baseball Bat', 35, () => { pl.giveWeapon('bat'); say("Louisville Slugger. Not for baseball."); }); break;
      case 'guns': opts.push({ label: 'Browse the counter', fn: () => this.openShop('guns') }); break;
      case 'tailor': opts.push({ label: 'Try on suits', fn: () => this.openShop('tailor') }); buy('Ski Mask', 10, () => { pl.inv.tools.mask = 1; say('Wear it with MASK. Witnesses can\'t name you.'); }); break;
      case 'bank':
        opts.push({ label: 'Rob the vault', small: 'Big money. The whole city will come for you.', cls: 'bad', fn: () => this.heist(b) });
        break;
      case 'police': {
        const j = b.cityId;
        const bnt = g.law.bounty[j] || 0;
        if (bnt) opts.push({ label: `Pay your bounty in ${g.law.jurName(j)}`, price: R.fmtMoney(bnt), fn: () => { if (g.law.payBounty(j)) this.renderInterior('Paid. The desk sergeant stamps something without looking up.'); else say("You can't cover it."); } });
        for (const k in g.law.bounty) if (k !== j && g.law.bounty[k] > 0) opts.push({ label: `Pay bounty for ${g.law.jurName(k)}`, price: R.fmtMoney(g.law.bounty[k]), fn: () => { if (g.law.payBounty(k)) this.renderInterior('Wired across the county. Clean slate there.'); else say("You can't cover it."); } });
        if (!bnt) opts.push({ label: 'Ask about the city', fn: () => say(`${b.city.name}: prosperity ${Math.round(b.city.prosperity)}/100, heat ${Math.round(b.city.heat)}. The sergeant eyes your suit.`) });
        break;
      }
      case 'hospital': buy('Get patched up', 30, () => { pl.hp = pl.maxHp; pl.bloody = 0; say('Stitches, iodine, and a lollipop.'); }); cons('bandage'); break;
      case 'garage': opts.push({ label: 'Garage services & car lot', fn: () => this.openShop('garage') }); break;
      case 'hotel':
        buy('Rent a room: sleep & save', 15, () => this.sleep());
        break;
      case 'church':
        buy('Light a candle (donate)', 10, () => { pl.rep.honor += 2; pl.rep.infamy = Math.max(0, pl.rep.infamy - 2); say('Father looks relieved. So do you.'); });
        opts.push({ label: 'Sit in the pews a while', fn: () => { g.clock.skip(60); pl.cool = Math.min(100, pl.cool + 15); say('An hour of quiet. Stained glass, old wood, somebody practising the organ.'); } });
        break;
      case 'social':
        opts.push({ label: `See Don ${g.jobs.donName(b.city.def.family)} about work`, cls: 'go', fn: () => { this.closeSheet(); g.jobs.openBoard({ faction: b.city.def.family, x: pl.x, y: pl.y }); } });
        if (b.city.def.family === pl.family) opts.push({ label: 'Crash on the back room cot (save)', fn: () => this.sleep(true) });
        break;
      case 'gas': buy('Gas Can', 20, () => { pl.inv.tools.gascan = (pl.inv.tools.gascan || 0) + 1; say('Select it with WPN, hold HIT to pour a trail, then USE on the trail to light it.'); }); cons('smokes'); cons('coffee'); break;
      case 'butcher': opts.push({ label: 'Sell pelts & meat', fn: () => this.openShop('butcher') }); buy('Hunting Rifle', 300, () => { pl.giveWeapon('rifle'); pl.inv.ammo.rifle += 10; say('Bolt action. Kills a bear at 200 yards.'); }); break;
      case 'casino':
        opts.push({ label: 'Blackjack ($50 hands)', fn: () => this.gamble(0.47, 50) });
        opts.push({ label: 'Slot machines ($5 pulls)', fn: () => this.gamble(0.3, 5, 3) });
        buy('Champagne', 12, () => { pl.drink(); pl.cool = Math.min(100, pl.cool + 20); say('Bubbles up your nose. Very classy.'); });
        break;
      case 'arcade': buy('Play pinball', 1, () => { const s = Math.floor(R.rng() * 90000) + 1000; pl.cool = Math.min(100, pl.cool + 10); say(`TILT! You scored ${s.toLocaleString()}. ${s > 70000 ? 'High score. The kids stare in awe.' : 'A kid in a striped shirt snickers.'}`); }); break;
      case 'barber': buy('Haircut & shave', 8, () => { pl.outfitChangedSince = 600; say('Fresh shave, new part. Cops will have a harder time recognising you for a while.'); }); break;
      case 'laundry': buy('Wash your suit', 2, () => { pl.bloody = 0; say('The blood comes out. Mostly.'); }); break;
      case 'farm': buy('Buy a side of beef', 10, () => { pl.inv.cons.sandwich = (pl.inv.cons.sandwich || 0) + 2; say('Wrapped in paper. Makes two sandwiches.'); }); break;
      default: break;
    }
    // registers & rackets
    if (bt.rob && b.workers.length && b.type !== 'bank') {
      const ready = g.pop.day - b.robbedDay >= 3;
      opts.push({ label: 'Rob the register', small: ready ? 'Needs a weapon. The clerk might fight back.' : 'Cleaned out recently. Not much in the till.', cls: 'bad', fn: () => this.robRegister(b) });
    }
    if (b.racket && b.racketFamily === pl.family) {
      const due = b.racketDue || 0;
      opts.push({ label: `Collect protection`, price: R.fmtMoney(due), fn: () => { if (!due) return say('Nothing due yet. They pay by the week.'); pl.addCash(due); b.racketDue = 0; say('An envelope slides across the counter. Nobody looks at you.'); g.audio.sfx('cash'); } });
    }
    // houses
    if (bt.house && !bt.hours) {
      const occ = g.life.occupants(b);
      if (b.playerOwned) {
        opts.push({ label: 'Sleep & save', cls: 'go', fn: () => this.sleep(true) });
      } else if (!b.residents.length && !b.fromLot && b.type === 'house' || (!b.residents.length && b.type === 'cabin')) {
        buy('Buy this place (safehouse)', b.type === 'cabin' ? 900 : 1600, () => { b.playerOwned = true; pl.properties.push(b.id); g.player.stats.props = (g.player.stats.props || 0) + 1; this.renderInterior('Keys are yours. Sleep here to save any time.'); });
      } else {
        opts.push({ label: occ.length ? 'Knock and chat' : 'Knock (nobody home)', fn: () => { if (!occ.length) return say('No answer. The house is empty.'); this.interiorGreet(occ[0]); } });
        opts.push({ label: 'Burgle it', small: occ.length ? `${occ.length} inside${g.clock.isNight() ? ', probably asleep' : ''}` : 'Nobody home right now', cls: 'bad', fn: () => this.burgle(b) });
      }
    }
    if (bt.jobs && !b.playerOwned && (b.type === 'bar' || b.type === 'diner' || b.type === 'laundry' || b.type === 'arcade' || b.type === 'barber')) {
      const price = 1500 + b.w * b.h * 60;
      opts.push({ label: 'Buy out the owner', price: R.fmtMoney(price), small: 'Earns a daily cut. The owner has to like you, or fear you.', fn: () => {
        const owner = g.pop.people[b.owner];
        const willing = !owner || !owner.alive || owner.opinion > 30 || owner.fear > 60;
        if (!willing) return say('The owner laughs you out the door. Get them to like you first.');
        if (!pl.pay(price)) return say("You don't have that kind of money.");
        b.playerOwned = true;
        b.racket = 1; b.racketFamily = pl.family; b.racketDue = 0;
        pl.properties.push(b.id);
        this.renderInterior('Handshake, papers, a photo for the newspaper. It\'s yours.');
        g.pop.addNews(b.cityId, `${b.name} changes hands. New owner wears a fedora.`);
      } });
    }
    opts.push({ label: 'Leave', fn: () => this.closeSheet() });
    return opts;
  };

  U.sleep = function (free) {
    const g = this.game, pl = g.player;
    const h = g.clock.hour();
    const until = h < 7 ? 8 - h : 24 - h + 8;
    g.clock.skip(Math.round(until * 60));
    pl.hp = pl.maxHp;
    pl.drunk = 0;
    pl.cool = Math.max(pl.cool, 60);
    g.save();
    this.renderInterior(`You sleep till 8. Game saved. ${R.rng.pick(['You dream of disco balls.', 'Somebody next door plays Bee Gees all night.', 'The radiator bangs like a drum.'])}`);
  };

  U.robRegister = function (b) {
    const g = this.game, pl = g.player;
    const say = (s) => { const el = $('#tline'); if (el) el.textContent = s; };
    const armed = Object.keys(pl.inv.weapons).some((w) => w !== 'fists' && w !== 'knuckles');
    if (!armed) return say('You need a weapon to make this convincing.');
    const clerkP = b.workers.map((id) => g.pop.people[id]).find((p) => p && p.alive);
    const brave = clerkP ? clerkP.tr.brave : 0.5;
    const roll = R.rng();
    const cash = g.pop.day - b.robbedDay >= 3 ? b.cash + R.rng.int(20, 80) : R.rng.int(3, 15);
    b.robbedDay = g.pop.day;
    const crimeHere = () => g.law.crime('robbery', b.out.x * TS + 8, b.out.y * TS + 8, {});
    if (roll < 0.12 + brave * 0.25) {
      // shotgun under the counter
      this.closeSheet();
      const h = clerkP ? g.life.spawnPerson(clerkP, pl.x + 10, pl.y - 6) : g.actors.makeHuman(pl.x + 10, pl.y - 6, {});
      if (h) { g.actors.arm(h, 'shotgun'); h.hostile = true; g.actors.setFight(h, pl); g.actors.say(h, 'Not in MY store!'); }
      crimeHere();
      return;
    }
    if (roll < 0.3 + brave * 0.2) {
      g.audio.sfx('alarm');
      pl.addCash(Math.round(cash / 2));
      this.closeSheet();
      this.toast('The clerk hit the silent alarm. Police are on the way.', 'bad');
      g.law.startIncident({ type: 'robbery', def: g.law.CRIMES.robbery, x: pl.x, y: pl.y, jur: g.law.jurAt(pl.x, pl.y), identified: !pl.masked, lvl: 2, bounty: 50 }, null);
      return;
    }
    pl.addCash(cash);
    if (clerkP) { clerkP.fear = Math.min(100, clerkP.fear + 40); clerkP.opinion -= 30; g.pop.remember(clerkP, 'robbed', `Got held up at the register${pl.masked ? ' by a guy in a ski mask' : ' by a big fella in a fedora'}.`, g.pop.day); }
    b.city.prosperity = Math.max(0, b.city.prosperity - 2);
    g.pop.addNews(b.cityId, `${b.name} robbed ${pl.masked ? 'by a masked gunman' : 'in broad daylight'}.`);
    g.jobs.progress('robbed', b);
    this.closeSheet();
    this.toast(`Took ${R.fmtMoney(cash)} from the register. The clerk will call it in once you're gone.`, 'warn');
    // the clerk becomes a witness who calls from the shop phone after a delay
    setTimeout(() => { if (!g.law.active()) g.law.report({ type: 'robbery', def: g.law.CRIMES.robbery, x: b.out.x * TS, y: b.out.y * TS, jur: g.law.jurAt(b.out.x * TS, b.out.y * TS), identified: !pl.masked, lvl: 2, bounty: 50 }, null); }, pl.masked ? 9000 : 6000);
  };

  U.breakIn = function (b) {
    const g = this.game, pl = g.player;
    if (pl.inv.tools.lockpick) { if (R.rng() < 0.5) pl.inv.tools.lockpick--; }
    else { g.actors.noise(pl.x, pl.y, TS * 6, 'scream', pl); g.audio.sfx('glass'); }
    g.law.crime('burglary', pl.x, pl.y, {});
    if (D.btypes[b.type].house) return this.burgle(b, true);
    // closed businesses: the register and back room
    this.insideB = b;
    pl.inside = b;
    const loot = b.cash + R.rng.int(10, 60);
    const opts = [
      { label: 'Crack the till', small: 'Grab the cash', fn: () => { pl.addCash(loot); b.cash = 0; this.toast(`Took ${R.fmtMoney(loot)}.`); this.closeSheet(); } },
      { label: 'Leave quietly', fn: () => this.closeSheet() },
    ];
    const s = this.openSheet('interior', this.header(b.name + ' (after hours)', 'Dark, quiet, smells of floor wax') + `<div class="body">${this.optsHtml(opts)}</div>`);
    this.bindOpts(s, opts);
  };

  // Burglary minigame: search rooms, each search makes noise
  U.burgle = function (b, alreadyIn) {
    const g = this.game, pl = g.player;
    if (!alreadyIn) {
      if (pl.inv.tools.lockpick) { if (R.rng() < 0.5) pl.inv.tools.lockpick--; }
      else g.audio.sfx('glass');
      g.law.crime('burglary', b.out.x * TS + 8, b.out.y * TS + 8, {});
    }
    this.insideB = b;
    pl.inside = b;
    const occ = g.life.occupants(b);
    const asleep = g.clock.isNight();
    const rooms = ['Living room', 'Kitchen', 'Bedroom', 'Closet', 'Study'].slice(0, b.type === 'cabin' ? 3 : 5).map((n) => ({ n, done: false }));
    const st = { noise: 0, found: [] };
    const draw = (msg) => {
      const opts = rooms.map((r) => ({ label: r.done ? `${r.n} (searched)` : `Search the ${r.n.toLowerCase()}`, cls: r.done ? 'dim' : '', fn: () => !r.done && search(r) }));
      opts.push({ label: 'Get out', cls: 'go', fn: () => { this.closeSheet(); } });
      const s = this.openSheet('burgle', this.header(`Burgling ${b.name}`, `${occ.length ? occ.length + (asleep ? ' asleep upstairs' : ' home') : 'Nobody home'} · move quietly`) +
        `<div class="body"><div class="line" id="tline">${esc(msg || 'Your eyes adjust to the dark.')}</div><div class="sect">Noise</div><div class="progress"><i style="width:${Math.min(100, st.noise)}%;background:${st.noise > 60 ? 'var(--red)' : 'var(--orange)'}"></i></div>${this.optsHtml(opts)}</div>`);
      this.bindOpts(s, opts);
    };
    const search = (r) => {
      r.done = true;
      st.noise += R.rng.int(10, 28) - (pl.sneak ? 8 : 0);
      let found = '';
      const table = [['cash', 4], ['watch', 1.5], ['ring', 1], ['jewels', 0.6], ['silver', 1.5], ['tv', 1], ['eight', 2], ['radio', 1.5], ['cam', 1], ['fur', 0.4], ['painting', 0.25], ['bonds', 0.15], ['nothing', 3]];
      const it = R.rng.weighted(table);
      if (b.stash && (r.n === 'Bedroom' || r.n === 'Kitchen')) { pl.addCash(b.stash); found = `A coffee can stuffed with ${R.fmtMoney(b.stash)}!`; b.stash = 0; g.jobs.leads = g.jobs.leads.filter((l) => l.b !== b.id); }
      else if (it === 'cash') { const c = R.rng.int(5, 40); pl.addCash(c); found = `${R.fmtMoney(c)} in a drawer.`; }
      else if (it === 'nothing') found = 'Nothing worth taking.';
      else { pl.inv.loot[it] = (pl.inv.loot[it] || 0) + 1; found = `${D.loot[it].name}. The pawn shop will take it.`; }
      const wake = occ.length && R.rng() * 100 < st.noise * (asleep ? 0.7 : 1.3);
      if (wake) {
        const p = occ[0];
        this.closeSheet();
        const h = g.life.spawnPerson(p, pl.x, pl.y - 4);
        if (!h) return;
        g.actors.say(h, R.rng.pick(["Who's there?!", 'I got a gun!', 'Honey, call the police!']));
        h.witness = { crime: { type: 'burglary', def: g.law.CRIMES.burglary, x: pl.x, y: pl.y, jur: g.law.jurAt(pl.x, pl.y), identified: !pl.masked, lvl: 1, bounty: 35 }, done: false };
        if (h.tr.brave > 0.7) { if (!h.armed) g.actors.arm(h, 'bat'); h.hostile = true; g.actors.setFight(h, pl); }
        else { g.actors.setFlee(h, pl, 3); h.alert = 'witness'; }
        this.toast(`${p.first} woke up!`, 'bad');
        return;
      }
      draw(found);
    };
    draw();
  };

  U.heist = function (b) {
    const g = this.game, pl = g.player;
    const armed = Object.keys(pl.inv.weapons).some((w) => D.weapons[w].gun);
    if (!armed) return this.renderInterior("You need a gun for this. A real one.");
    const total = 14;
    let t = 0;
    const cash = R.rng.int(900, 2200);
    g.law.startIncident({ type: 'heist', def: g.law.CRIMES.heist, x: pl.x, y: pl.y, jur: g.law.jurAt(pl.x, pl.y), identified: !pl.masked, lvl: 3, bounty: 300 }, null);
    g.pop.addNews(b.cityId, `${b.name} held up ${pl.masked ? 'by a masked crew' : 'by a gunman in a pinstripe suit'}!`);
    this.openSheet('heist', this.header('The Vault', 'Tellers on the floor. The alarm is ringing.') + `<div class="body"><div class="line" id="tline">You jam the drill into the vault door.</div><div class="progress"><i id="hbar"></i></div><div class="opts"><button class="opt go" id="hgo">Grab what you can and run</button></div></div>`);
    const lines = ['"Everybody stay calm!"', 'Sirens, still far off.', 'A teller is crying.', 'Sirens getting louder.', 'Tumblers clicking...', 'The door groans open!'];
    const iv = setInterval(() => {
      t++;
      const bar = $('#hbar');
      if (!bar) return clearInterval(iv);
      bar.style.width = (t / total) * 100 + '%';
      const l = $('#tline');
      if (l && t % 3 === 0) l.textContent = lines[Math.min(lines.length - 1, Math.floor(t / 3))];
      if (t >= total) { clearInterval(iv); const l2 = $('#tline'); if (l2) l2.textContent = `The vault is open. ${R.fmtMoney(cash)} in bundles.`; $('#hgo').textContent = `Take ${R.fmtMoney(cash)} and run`; }
    }, 1000);
    $('#hgo').addEventListener('click', () => {
      clearInterval(iv);
      const got = Math.round(cash * Math.min(1, t / total) * (t >= total ? 1 : 0.4));
      pl.addCash(got);
      pl.rep.infamy += 10;
      g.jobs.addRep(50);
      b.city.prosperity = Math.max(0, b.city.prosperity - 8);
      this.closeSheet();
      this.toast(`Heist: ${R.fmtMoney(got)}. Now survive.`, 'warn');
    });
  };

  U.gamble = function (p, stake, mult) {
    const g = this.game, pl = g.player;
    const say = (s) => { const el = $('#tline'); if (el) el.textContent = s; };
    if (pl.cash < stake) return say(`You need ${R.fmtMoney(stake)} to play.`);
    pl.cash -= stake;
    const win = R.rng() < p;
    if (win) { const w = stake * (mult || 2); pl.addCash(w); say(R.rng.pick([`You win ${R.fmtMoney(w)}! The table groans.`, `Lady luck in a leisure suit: +${R.fmtMoney(w)}.`])); pl.cool = Math.min(100, pl.cool + 5); }
    else say(R.rng.pick([`Lost ${R.fmtMoney(stake)}. The dealer smiles.`, `Snake eyes. -${R.fmtMoney(stake)}.`, `Bust. -${R.fmtMoney(stake)}.`]));
  };

  // ---------------------------------------------------------------- shops (sub-sheets)
  U.openShop = function (kind) {
    const g = this.game, pl = g.player;
    const back = () => { this.closeSheet(); if (this.insideB) this.renderInterior(); };
    let opts = [], title = '', sub = '';
    if (kind === 'pawn' || kind === 'butcher') {
      title = kind === 'pawn' ? 'Pawn Counter' : 'Butcher & Trapper';
      sub = kind === 'pawn' ? 'No questions asked. Half of what it\'s worth, twice what you paid.' : 'Pelts, hides and meat. Fresh or not.';
      let total = 0;
      for (const k in pl.inv.loot) {
        const n = pl.inv.loot[k];
        if (!n) continue;
        const it = D.loot[k];
        if (!!it.pelt !== (kind === 'butcher')) continue;
        const v = Math.round(it.v * (kind === 'pawn' ? 0.8 : 1));
        total += v * n;
        opts.push({ label: `${it.name} ×${n}`, price: R.fmtMoney(v), fn: () => { pl.inv.loot[k]--; pl.addCash(v); g.audio.sfx('cash'); this.openShop(kind); } });
      }
      if (total) opts.unshift({ label: 'Sell everything', price: R.fmtMoney(total), cls: 'go', fn: () => { for (const k in pl.inv.loot) { const it = D.loot[k]; if (!!it.pelt === (kind === 'butcher')) pl.inv.loot[k] = 0; } pl.addCash(total); g.audio.sfx('cash'); this.openShop(kind); } });
      if (!opts.length) opts.push({ label: kind === 'pawn' ? 'You have nothing to sell. Rob someone.' : 'Nothing to sell. Go hunting.', cls: 'dim' });
    } else if (kind === 'guns') {
      title = 'Gun Counter';
      sub = 'Cash only. No waiting period in the Brass Coast.';
      for (const id of ['revolver', 'magnum', 'shotgun', 'rifle', 'chopper', 'knife']) {
        const w = D.weapons[id];
        const have = pl.inv.weapons[id];
        if (id === 'chopper' && g.jobs.rank() < 2) { opts.push({ label: `${w.name}`, small: 'Capo rank only. Ask the family.', cls: 'dim' }); continue; }
        opts.push({ label: have ? `${w.name} (owned)` : w.name, price: have ? '—' : R.fmtMoney(w.price), cls: have ? 'dim' : '', fn: () => { if (have) return; if (!pl.pay(w.price)) return this.toast("Can't afford it.", 'warn'); pl.giveWeapon(id); this.toast(`Bought ${w.name}.`, 'good'); g.audio.sfx('cash'); this.openShop('guns'); } });
      }
      for (const am in D.ammoPrice) {
        const [n, p] = D.ammoPrice[am];
        opts.push({ label: `${D.ammoNames[am]} ×${n}`, small: `You have ${pl.inv.ammo[am] || 0}`, price: R.fmtMoney(p), fn: () => { if (!pl.pay(p)) return this.toast("Can't afford it.", 'warn'); pl.inv.ammo[am] = (pl.inv.ammo[am] || 0) + n; g.audio.sfx('cash'); this.openShop('guns'); } });
      }
      opts.push({ label: 'Molotov', small: `You have ${pl.inv.ammo.molotov || 0}`, price: '$25', fn: () => { if (!pl.pay(25)) return; pl.inv.ammo.molotov = (pl.inv.ammo.molotov || 0) + 1; this.openShop('guns'); } });
      opts.push({ label: 'Dynamite', small: g.jobs.rank() < 1 ? 'Soldier rank only' : `You have ${pl.inv.ammo.dynamite || 0}`, price: '$60', cls: g.jobs.rank() < 1 ? 'dim' : '', fn: () => { if (g.jobs.rank() < 1 || !pl.pay(60)) return; pl.inv.ammo.dynamite = (pl.inv.ammo.dynamite || 0) + 1; this.openShop('guns'); } });
    } else if (kind === 'tailor') {
      title = 'Tailor';
      sub = 'A new suit also throws off anyone looking for the old one.';
      for (const id in D.outfits) {
        const o = D.outfits[id];
        const owned = pl.outfits && pl.outfits[id] || id === 'mook';
        opts.push({ label: o.name + (pl.outfit === id ? ' (wearing)' : ''), price: owned ? 'Wear' : R.fmtMoney(o.price), fn: () => {
          if (!owned) { if (!pl.pay(o.price)) return this.toast("Can't afford it.", 'warn'); pl.outfits = pl.outfits || {}; pl.outfits[id] = 1; }
          pl.outfit = id; pl.buildLook(); pl.outfitChangedSince = 900; pl.bloody = 0;
          this.toast(`Wearing: ${o.name}. Cops will need a second look.`, 'good');
          this.openShop('tailor');
        } });
      }
    } else if (kind === 'garage') {
      title = 'Garage';
      sub = 'Repairs, respray, and cars for sale.';
      const v = g.traffic.list.filter((c) => (c.stolen || c.owner === 'player') && !c.wrecked && R.dist(c.x, c.y, pl.x, pl.y) < TS * 10)[0];
      if (v) {
        opts.push({ label: `Repair the ${v.model.name}`, price: '$40', fn: () => { if (!pl.pay(40)) return; v.hp = v.maxHp; v.burning = 0; this.toast('Good as new.', 'good'); } });
        opts.push({ label: `Respray the ${v.model.name}`, small: 'New color. Throws off a search.', price: '$60', fn: () => {
          if (!pl.pay(60)) return;
          v.color = R.rng.pick(v.model.colors.concat(['#8a2a5a', '#2a8a5a', '#c0a020', '#f0f0e0']));
          if (g.law.active() && g.law.incident.state !== 'pursuit') g.law.clearIncident(false);
          this.toast('Fresh paint. The heat is off this ride.', 'good');
        } });
      } else opts.push({ label: 'Bring a car within a block for repairs', cls: 'dim' });
      for (const id of ['sedan', 'wagon', 'pickup', 'van', 'coupe', 'muscle']) {
        const m = D.vehicles[id];
        opts.push({ label: `Buy a ${m.name}`, small: `Top speed ${m.top} · yours to keep`, price: R.fmtMoney(m.price), fn: () => {
          if (!pl.pay(m.price)) return this.toast("Can't afford it.", 'warn');
          const b = this.insideB;
          const car = g.jobs.spawnCarNear(b || { out: { x: (pl.x / TS) | 0, y: (pl.y / TS) | 0 } }, id);
          if (car) { car.owner = 'player'; car.locked = false; car.keep = true; car.parked = true; pl.ownedCars.push(car); this.toast(`Your ${m.name} is parked outside.`, 'good'); }
          this.closeSheet();
        } });
      }
    }
    opts.push({ label: 'Back', fn: back });
    const s = this.openSheet('shop', this.header(title, sub) + `<div class="body">${this.optsHtml(opts)}</div>`);
    this.bindOpts(s, opts);
  };

  U.openBoard = function (family, offers, h) {
    const g = this.game, pl = g.player;
    const j = g.jobs.active;
    const opts = [];
    if (j) opts.push({ label: `Current: ${j.title}`, small: 'Abandon it (the family notices)', cls: 'bad', fn: () => { g.jobs.abandon(); this.closeSheet(); } });
    for (const o of offers) {
      opts.push({ label: o.title, small: o.desc, price: R.fmtMoney(o.reward), cls: 'go', fn: () => { g.jobs.accept(o); g.jobs.offers[family] = offers.filter((x) => x !== o); this.closeSheet(); } });
    }
    if (!offers.length) opts.push({ label: 'No more work today. Come back tomorrow.', cls: 'dim' });
    const st = Math.round(g.jobs.familyStanding(family));
    const sub = family === pl.family ? `${g.jobs.rankName()} · ${Math.round(g.jobs.rep)}/${g.jobs.nextRankRep()} respect to next rank` : `Standing ${st}. Working for rivals costs you at home.`;
    opts.push({ label: 'Leave', fn: () => this.closeSheet() });
    const s = this.openSheet('board', this.header(`Don ${g.jobs.donName(family)}`, sub) + `<div class="body"><div class="line">“${esc(R.rng.pick(['Sit. Eat something. Then we talk business.', 'I got problems, you got hands. Let\'s help each other.', 'Family first. Then money. Then everything else.']))}”</div>${this.optsHtml(opts)}</div>`);
    this.bindOpts(s, opts);
  };

  U.openPhone = function () {
    const g = this.game, pl = g.player;
    const opts = [];
    opts.push({ label: `Call the ${pl.family} family`, small: 'Hear about work', fn: () => { this.closeSheet(); g.jobs.openBoard({ faction: pl.family, x: pl.x, y: pl.y }); } });
    for (const c of g.world.cities) {
      opts.push({ label: `Taxi to ${c.name}`, small: c.def.tag, price: '$25', fn: () => {
        if (g.law.active()) return this.toast('No cab will take you with the cops on your tail.', 'warn');
        if (!pl.pay(25)) return this.toast("You can't afford the fare.", 'warn');
        this.closeSheet();
        const club = c.buildings.find((b) => b.type === 'hotel') || c.buildings[0];
        const d = R.dist(pl.x, pl.y, club.out.x * TS, club.out.y * TS) / TS;
        pl.place(club.out.x * TS + 8, club.out.y * TS + 10);
        g.clock.skip(Math.round(d / 4));
        g.cam.x = pl.x; g.cam.y = pl.y;
        this.toast(`The cabbie drops you in ${c.name}. ${R.rng.pick(['He talked about his ex-wife the whole way.', 'Bee Gees on the 8-track the whole ride.', 'He charged extra for the silence.'])}`);
      } });
    }
    if (pl.sweetheart >= 0) {
      const p = g.pop.people[pl.sweetheart];
      if (p && p.alive) opts.push({ label: `Call ${p.first}`, fn: () => { this.closeSheet(); this.toast(`${p.first}: "${R.rng.pick(['Miss you, big guy.', 'Are you being careful?', 'Come see me. Wear the good suit.'])}"`, 'good'); } });
    }
    opts.push({ label: 'Hang up', fn: () => this.closeSheet() });
    const s = this.openSheet('phone', this.header('Payphone', 'Dime a call. The line crackles.') + `<div class="body">${this.optsHtml(opts)}</div>`);
    this.bindOpts(s, opts);
  };

  U.fish = function () {
    const g = this.game, pl = g.player;
    if (!pl.inv.tools.bait) return this.toast('You need bait. The general store sells it.', 'warn');
    pl.inv.tools.bait--;
    let state = 'wait', t = 1.5 + R.rng() * 4, bite = 0;
    const s = this.openSheet('fish', this.header('Fishing', 'Wait for the bite, then reel.') + `<div class="body"><div class="line" id="tline">You cast the line. The bobber floats.</div><div class="opts"><button class="opt go" id="reel">Reel!</button><button class="opt" id="quit">Pack up</button></div></div>`);
    g.audio.sfx('splash');
    const iv = setInterval(() => {
      if (this.sheetOpen !== 'fish') return clearInterval(iv);
      t -= 0.1;
      if (state === 'wait' && t <= 0) { state = 'bite'; bite = 0.9; $('#tline').textContent = 'BITE! Reel now!'; g.audio.sfx('bite'); }
      else if (state === 'bite') { bite -= 0.1; if (bite <= 0) { state = 'miss'; $('#tline').textContent = 'It got away. Tap Reel to cast again.'; } }
    }, 100);
    $('#reel').addEventListener('click', () => {
      if (state === 'bite') {
        const big = R.rng() < 0.18;
        pl.inv.loot[big ? 'bigfish' : 'fish'] = (pl.inv.loot[big ? 'bigfish' : 'fish'] || 0) + 1;
        pl.stats.fish++;
        $('#tline').textContent = big ? 'A prize bass! The butcher will pay well.' : 'A decent fish. Tap Reel to cast again.';
        state = 'miss';
        pl.cool = Math.min(100, pl.cool + 4);
      } else if (state === 'miss') {
        if (!pl.inv.tools.bait) { $('#tline').textContent = 'Out of bait.'; return; }
        pl.inv.tools.bait--;
        state = 'wait'; t = 1.5 + R.rng() * 4;
        $('#tline').textContent = 'You cast the line again.';
        g.audio.sfx('splash');
      } else $('#tline').textContent = 'Too early. Wait for the bite.';
    });
    $('#quit').addEventListener('click', () => { clearInterval(iv); this.closeSheet(); });
  };

  // ---------------------------------------------------------------- menu
  U.toggleMenu = function () {
    if (this.sheetOpen === 'menu') this.closeSheet();
    else if (!this.sheetOpen) this.openMenu('map');
  };
  U.openMenu = function (tab) {
    if (this.sheetOpen && this.sheetOpen !== 'menu') return;
    const tabs = [['map', 'Map'], ['jobs', 'Jobs'], ['people', 'People'], ['status', 'Status'], ['items', 'Items'], ['news', 'Paper'], ['settings', 'Settings'], ['help', 'Help']];
    const s = this.openSheet('menu', `<div class="tabs">${tabs.map(([k, l]) => `<button data-tab="${k}" class="${k === tab ? 'sel' : ''}">${l}</button>`).join('')}<button data-tab="close" aria-label="Close">✕</button></div><div class="body" id="mbody"></div>`, true);
    s.style.maxHeight = '92%';
    s.querySelectorAll('[data-tab]').forEach((b) => b.addEventListener('click', () => (b.dataset.tab === 'close' ? this.closeSheet() : this.openMenuTab(b.dataset.tab, s))));
    this.openMenuTab(tab, s);
  };
  U.openMenuTab = function (tab, s) {
    const g = this.game, pl = g.player;
    s.querySelectorAll('[data-tab]').forEach((b) => b.classList.toggle('sel', b.dataset.tab === tab));
    const body = $('#mbody');
    body.scrollTop = 0;
    if (tab === 'map') {
      body.innerHTML = `<canvas id="fullmap" width="640" height="640"></canvas><p style="font-size:13px;color:var(--brown);margin:6px 0 0">Tap the map to set a waypoint. Gold: job · green: leads · red cross: hospitals · blue: police · orange: you.</p>`;
      this.drawFullMap();
      $('#fullmap').addEventListener('click', (e) => {
        const r = e.target.getBoundingClientRect();
        const x = ((e.clientX - r.left) / r.width) * g.world.W * TS, y = ((e.clientY - r.top) / r.height) * g.world.H * TS;
        g.waypoint = { x, y };
        this.drawFullMap();
      });
    } else if (tab === 'jobs') {
      const j = g.jobs.active;
      body.innerHTML = `<div class="sect">Current job</div>${j ? `<p style="font-size:16px"><b>${esc(j.title)}</b><br>${esc(j.desc)}</p>` : '<p>No job. Visit a Social Club or call the family from a payphone.</p>'}
        <div class="sect">Leads</div>${g.jobs.leads.length ? g.jobs.leads.map((l) => `<p>• ${esc(l.text)}</p>`).join('') : '<p>No leads. Greet people; chatty folks and bartenders talk.</p>'}
        <div class="sect">Rackets</div>${g.world.buildings.filter((b) => b && b.racket && b.racketFamily === pl.family).map((b) => `<p>• ${esc(b.name)} (${esc(b.city.name)}) · ${R.fmtMoney(b.racketDue || 0)} due</p>`).join('') || '<p>No protection clients yet (Soldier rank and up).</p>'}`;
    } else if (tab === 'people') {
      const met = g.pop.people.filter((p) => p.met).sort((a, b) => b.opinion - a.opinion);
      const pop = g.pop.people.filter((p) => p.alive).length;
      body.innerHTML = `<p style="font-size:14px;color:var(--brown)">${pop} people live on the Brass Coast. You know ${met.length}.</p><div class="people">${met.map((p) => `<div class="person"><canvas class="portrait" width="28" height="36" style="width:28px;height:36px" data-p="${p.id}"></canvas><div class="n">${esc(g.pop.name(p))}${p.alive ? '' : ' †'}<small>${esc(g.pop.title(p))} · ${p.age} · ${esc((g.pop.cityObj(p.city) || {}).name || 'County')}${p.id === pl.sweetheart ? ' · sweetheart' : ''}</small></div><div class="meter"><i style="width:${50 + p.opinion / 2}%;background:${p.opinion > 20 ? 'var(--good)' : p.opinion < -20 ? 'var(--red)' : 'var(--mustard)'}"></i></div></div>`).join('') || '<p>Nobody yet. Greet people twice to learn their names.</p>'}</div>`;
      body.querySelectorAll('canvas[data-p]').forEach((cv) => this.drawPortrait(cv, g.pop.people[+cv.dataset.p].look));
    } else if (tab === 'status') {
      const fam = D.cities.map((c) => `<span>${c.family} (${c.name})</span><span>${Math.round(g.jobs.familyStanding(c.family))}</span>`).join('');
      const bnt = D.cities.map((c) => `<span>${c.name}</span><span>${R.fmtMoney(g.law.bounty[c.id] || 0)}</span>`).join('') + `<span>The County</span><span>${R.fmtMoney(g.law.bounty.county || 0)}</span>`;
      const st = pl.stats;
      body.innerHTML = `<div class="sect">${esc(pl.name)} · ${g.jobs.rankName()}</div><div class="kv"><span>Respect</span><span>${Math.round(g.jobs.rep)} / ${g.jobs.nextRankRep()}</span><span>Infamy</span><span>${Math.round(pl.rep.infamy)}</span><span>Honor</span><span>${Math.round(pl.rep.honor)}</span><span>Health</span><span>${Math.round(pl.hp)}</span></div>
      <div class="sect">Families</div><div class="kv">${fam}</div><div class="sect">Bounties</div><div class="kv">${bnt}</div>
      <div class="sect">Record</div><div class="kv"><span>Jobs done</span><span>${st.jobs}</span><span>Crimes</span><span>${st.crimes}</span><span>Escapes</span><span>${st.escapes}</span><span>Arrests</span><span>${st.arrests}</span><span>Bodies</span><span>${st.kills}</span><span>Animals hunted</span><span>${st.hunted}</span><span>Fish caught</span><span>${st.fish}</span><span>People greeted</span><span>${st.greeted}</span><span>Properties</span><span>${pl.properties.length}</span></div>`;
    } else if (tab === 'items') {
      const rows = [];
      for (const k in pl.inv.cons) if (pl.inv.cons[k]) rows.push({ label: `${D.consumables[k].name} ×${pl.inv.cons[k]}`, small: 'Tap to use', fn: () => { const c = D.consumables[k]; pl.inv.cons[k]--; if (c.heal) pl.hp = Math.min(pl.maxHp, pl.hp + c.heal); if (c.cool) pl.cool = Math.min(100, pl.cool + c.cool); if (c.drunk) pl.drunk += c.drunk; if (c.sober) pl.drunk = 0; this.openMenuTab('items', s); } });
      const weapons = pl.weaponList().map((w) => (w === 'gascan' ? `Gas Can ×${pl.inv.tools.gascan}` : D.weapons[w].name + (D.weapons[w].gun ? ` (${pl.clip[w] || 0}+${pl.inv.ammo[D.weapons[w].ammo] || 0})` : D.weapons[w].thrown ? ` ×${pl.inv.ammo[w]}` : ''))).join(', ');
      const loot = Object.keys(pl.inv.loot).filter((k) => pl.inv.loot[k]).map((k) => `${D.loot[k].name} ×${pl.inv.loot[k]}`).join(', ');
      const tools = Object.keys(pl.inv.tools).filter((k) => pl.inv.tools[k]).map((k) => `${D.tools[k].name}${pl.inv.tools[k] > 1 ? ' ×' + pl.inv.tools[k] : ''}`).join(', ');
      body.innerHTML = `<div class="sect">Weapons</div><p>${esc(weapons)}</p><div class="sect">Pockets</div>${this.optsHtml(rows)}<div class="sect">Tools</div><p>${esc(tools || 'Nothing')}</p><div class="sect">Goods to fence</div><p>${esc(loot || 'Nothing')}</p><div class="sect">Outfit</div><p>${esc(D.outfits[pl.outfit].name)}</p>`;
      this.bindOpts(body, rows);
    } else if (tab === 'news') {
      const day = g.pop.day;
      const items = g.pop.news.slice(0, 16);
      const cityRows = g.world.cities.map((c) => {
        const n = (g.pop.byCity[c.id] || []).filter((p) => p.alive).length;
        const kids = (g.pop.byCity[c.id] || []).filter((p) => p.alive && p.age < 18).length;
        const proj = g.pop.projects.filter((p) => p.lot.city === c).length;
        return `<span>${c.name}</span><span>${n} · ${kids} kids · ${Math.round(c.prosperity)}% ${proj ? '· 🏗' + proj : ''}</span>`;
      }).join('');
      body.innerHTML = `<div class="news"><h3>The Brass Coast Bugle</h3><div class="dateline">Day ${day + 1} · ${g.clock.weekday()} · Still 1970-something in spirit</div>${items.map((n) => `<p><b>${esc((g.pop.cityObj(n.city) || { name: 'County' }).name)} · day ${n.day + 1}</b>${esc(n.text)}</p>`).join('') || '<p>Slow news day.</p>'}</div><div class="sect">Cities (people · kids · prosperity)</div><div class="kv">${cityRows}</div>`;
    } else if (tab === 'settings') {
      const st = g.settings;
      const sel = (id, vals, cur) => `<select id="${id}">${vals.map(([v, l]) => `<option value="${v}" ${String(v) === String(cur) ? 'selected' : ''}>${l}</option>`).join('')}</select>`;
      body.innerHTML = `<div class="set"><label for="sVol">Sound</label><input id="sVol" type="range" min="0" max="1" step="0.1" value="${st.vol}"></div>
      <div class="set"><label for="sMus">Music & radio</label><input id="sMus" type="range" min="0" max="1" step="0.1" value="${st.music}"></div>
      <div class="set"><label for="sLife">Life speed (NPC years per day)</label>${sel('sLife', [[0.25, 'Slow (¼)'], [0.5, 'Relaxed (½)'], [1, 'Normal (1)'], [2, 'Fast (2)'], [4, 'Dynasty (4)']], st.lifeSpeed)}</div>
      <div class="set"><label for="sTraffic">Traffic</label>${sel('sTraffic', [[0.5, 'Light'], [1, 'Normal'], [1.5, 'Rush hour']], st.traffic)}</div>
      <div class="set"><label for="sDens">Pedestrians</label>${sel('sDens', [[0.6, 'Sparse'], [1, 'Normal'], [1.4, 'Crowded']], st.density)}</div>
      <div class="set"><label for="sEv">Street events</label>${sel('sEv', [[0.5, 'Calm'], [1, 'Normal'], [1.8, 'Wild']], st.events)}</div>
      <div class="set"><label for="sZoom">Zoom</label>${sel('sZoom', [[0.8, 'Far'], [1, 'Normal'], [1.25, 'Close']], st.zoom)}</div>
      <div class="set"><label for="sGrain">Film grain</label><input id="sGrain" type="checkbox" ${st.grain ? 'checked' : ''}></div>
      <div class="opts"><button class="opt go" id="sSave">Save game</button><button class="opt bad" id="sNew">Start a new game</button></div>`;
      const bindS = (id, key, parse, after) => $('#' + id).addEventListener('change', (e) => { st[key] = parse(e.target); g.saveSettings(); if (after) after(st[key]); });
      bindS('sVol', 'vol', (e) => +e.value, (v) => g.audio.setVolume(v));
      bindS('sMus', 'music', (e) => +e.value, (v) => g.audio.setMusicVolume(v));
      bindS('sLife', 'lifeSpeed', (e) => +e.value);
      bindS('sTraffic', 'traffic', (e) => +e.value);
      bindS('sDens', 'density', (e) => +e.value);
      bindS('sEv', 'events', (e) => +e.value);
      bindS('sZoom', 'zoom', (e) => +e.value, () => g.resize());
      bindS('sGrain', 'grain', (e) => e.checked, (v) => this.setGrain(v));
      $('#sSave').addEventListener('click', () => { g.save(); this.toast('Game saved.', 'good'); });
      $('#sNew').addEventListener('click', (e) => {
        if (e.target.dataset.confirm) { g.newGame(); return; }
        e.target.dataset.confirm = '1';
        e.target.textContent = 'Tap again to erase your save and start over';
      });
    } else if (tab === 'help') {
      body.innerHTML = this.helpHtml();
    }
  };
  U.helpHtml = function () {
    return `<div class="sect">Controls</div><p><b>Touch:</b> drag anywhere on the left half to walk (push far to run). <b>A</b> uses whatever the label says: doors, cars, bodies, phones. <b>B</b> punches or fires. <b>WPN</b> switches weapons; hold it to holster. Near a person, chips appear: <b>Greet</b>, <b>Antagonize</b>, <b>Talk</b>, <b>Rob</b>.</p>
    <p><b>Keyboard:</b> WASD move · Shift run · E use · Space hit/fire · Q weapon · G greet · V antagonize · T talk · X defuse · Z cool · M mask · C sneak · I item · R radio · H horn · Esc menu.</p>
    <div class="sect">Driving</div><p>Point the stick where you want to go and the car steers there. Pull back to reverse. Hold <b>Brake</b> at speed to drift. Traffic stops at lights, honks, yields, and some drivers will get out and fight you.</p>
    <div class="sect">The law</div><p>A crime only counts if someone sees it. Witnesses run for a payphone or a cop, marked on your map in gold. Catch them first: scare them, pay them off, or worse. Once reported, police search the last place you were seen. Break line of sight and leave the circle to escape. Wear a mask and they can't put a name to the bounty. Accidents like bumping lamps or cars are never crimes, and cops warn you before minor stuff becomes a problem. Pay bounties at any police station.</p>
    <div class="sect">People</div><p>About a thousand people live here, with homes, jobs, spouses and kids. They age a year every in-game day (adjust in Settings), marry, have children, and move out. Cities build new houses and shops on empty lots when they're doing well, and rebuild after fires. People remember what you did to them and tell their friends.</p>
    <div class="sect">Getting ahead</div><p>Social Clubs hand out jobs. Respect earns rank: Soldiers run protection rackets, Capos recruit a crew, Underbosses collect tribute. Fence loot at pawn shops, sell pelts at the butcher, buy safehouses and businesses. The phone calls you a cab to any city.</p>
    <div class="sect">Play with the world</div><p>Pour gasoline trails and light them. Fires spread with the wind and die in the rain. Hit a hydrant with a car. Shoot out street lamps to darken a block. Hunt deer and bears in the north, gators in the bayou, fish off the piers. Lightning starts wildfires in a dry summer.</p>`;
  };
  U.drawFullMap = function () {
    const g = this.game, cv = $('#fullmap');
    if (!cv) return;
    const c = cv.getContext('2d');
    const W = g.world.W;
    c.imageSmoothingEnabled = false;
    c.drawImage(g.miniMap, 0, 0, W, W);
    c.font = 'bold 16px "Barlow Condensed", sans-serif';
    c.textAlign = 'center';
    for (const city of g.world.cities) {
      c.fillStyle = 'rgba(27,20,16,0.8)';
      const tw = c.measureText(city.name).width + 10;
      c.fillRect(city.cx - tw / 2, city.y0 - 22, tw, 18);
      c.fillStyle = city.def.color;
      c.fillText(city.name, city.cx, city.y0 - 8);
    }
    c.font = '12px "Barlow Condensed", sans-serif';
    for (const h of g.world.hamlets) { c.fillStyle = '#1b1410'; c.fillText(h.name, h.cx, h.y0 - 4); }
    for (const b of g.world.buildings) {
      if (!b || b.destroyed) continue;
      if (b.type === 'hospital') { c.fillStyle = '#c02020'; c.fillRect(b.x + 1, b.y, 3, 7); c.fillRect(b.x - 1, b.y + 2, 7, 3); }
      if (b.type === 'police') { c.fillStyle = '#3050c0'; c.fillRect(b.x, b.y, 6, 6); }
      if (b.type === 'social') { c.fillStyle = '#e4a92a'; c.fillRect(b.x, b.y, 6, 6); }
      if (b.playerOwned) { c.fillStyle = '#8ab04a'; c.fillRect(b.x, b.y, 6, 6); }
    }
    for (const l of g.jobs.leads) { c.fillStyle = '#7a8a2e'; c.beginPath(); c.arc(l.x, l.y, 6, 0, 7); c.fill(); }
    const m = g.jobs.marker();
    if (m) { c.fillStyle = '#e4a92a'; c.strokeStyle = '#1b1410'; c.lineWidth = 2; c.beginPath(); c.arc(m.x / TS, m.y / TS, 7, 0, 7); c.fill(); c.stroke(); }
    if (g.waypoint) { c.strokeStyle = '#f2e2c0'; c.lineWidth = 3; c.beginPath(); c.arc(g.waypoint.x / TS, g.waypoint.y / TS, 7, 0, 7); c.stroke(); }
    const inc = g.law.incident;
    if (inc) { c.strokeStyle = '#e4a92a'; c.lineWidth = 2; c.beginPath(); c.arc(inc.lastX / TS, inc.lastY / TS, g.law.searchRadius() / TS, 0, 7); c.stroke(); }
    const pl = g.player;
    c.fillStyle = '#d9621e'; c.strokeStyle = '#1b1410'; c.lineWidth = 3;
    c.beginPath(); c.arc(pl.x / TS, pl.y / TS, 7, 0, 7); c.fill(); c.stroke();
  };
})();
