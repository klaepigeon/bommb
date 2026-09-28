// RHAPSODY — time passing. The calendar turns: summer heat, autumn leaves, winter snow
// creeping down from the north into the cities, spring rain. Holidays happen: fireworks on
// the Fourth and New Year's Eve, jack-o'-lanterns and costumed kids at Halloween, strings of
// lights at Christmas. People leave footprints in snow, sand and mud; people standing
// around fidget, smoke and check their watches; conversations get a slow camera push-in.
// And the Legend: a running epilogue written from everything you've done, read at any
// time from the menu and at the end of each road to the top.
'use strict';
(function () {
  const D = R.data, T = D.T, TS = R.TILE;
  const G = () => R.game;
  const SN = (R.seasons = { t: 0 });
  const MONTH_DAYS = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

  // month (0 = Jan) and day of month for a game day; the story starts on June 1
  SN.date = function (day) {
    let d = ((day + 151) % 365 + 365) % 365, m = 0;
    while (d >= MONTH_DAYS[m]) { d -= MONTH_DAYS[m]; m++; }
    return { m, d: d + 1, year: Math.floor((day + 151) / 365) + 1 };
  };
  SN.season = function (day) { const m = this.date(day == null ? G().pop.day : day).m; return m === 11 || m <= 1 ? 'winter' : m <= 4 ? 'spring' : m <= 7 ? 'summer' : 'fall'; };
  SN.holiday = function (day) {
    const { m, d } = this.date(day == null ? G().pop.day : day);
    if (m === 6 && d === 4) return 'fourth';
    if (m === 9 && d >= 25) return 'halloween';
    if (m === 11 && d >= 10 && d <= 30) return 'christmas';
    if (m === 11 && d === 31) return 'newyear';
    return null;
  };

  // ---------------------------------------------------------------- the legend
  SN.legend = function () {
    const g = G(), pl = g.player, st = pl.stats, rep = pl.rep || {}, s = pl.campaign || {}, e = s.endings || {};
    const hon = rep.honor || 0, inf = rep.infamy || 0;
    const first = pl.first || 'Nicky', name = `${first}${pl.nick && pl.nick !== first ? ` "${pl.nick}"` : ''} ${pl.last || ''}`.trim();
    const days = g.pop.day;
    const P = [];
    P.push(`${name} came to the Brass Coast with a bullet in the gut and a borrowed suit. That was ${days} day${days === 1 ? '' : 's'} ago.`);
    if (hon >= 60 && inf < 40) P.push('People still talk about the stranger who helped. Shopkeepers wave. Mothers point you out to their kids as the kind of man who does the right thing when it costs him.');
    else if (hon >= 30 && inf >= 40) P.push('You did terrible things for decent reasons, and decent things for terrible ones. The neighbourhood can\'t decide what you are. Neither can you.');
    else if (inf >= 70) P.push('Your name is the kind people lower their voices to say. Doors close when your car turns onto the street.');
    else if (inf >= 40) P.push('The cops know your face. The families know your number. Everyone else knows to look away.');
    else P.push('Most people on the coast have never heard your name. That may be the smartest thing you ever did.');
    if (st.kills > 30) P.push(`${st.kills} people are in the ground because of you. Some of them had it coming.`);
    else if (st.kills > 5) P.push(`You've killed ${st.kills} people. You remember most of their faces.`);
    else if (st.kills > 0) P.push(`You killed ${st.kills === 1 ? 'one person' : st.kills + ' people'}. It was supposed to get easier.`);
    else P.push('You never killed anyone. On this coast, that\'s a miracle.');
    const camp = pl.street && pl.street.camp;
    if (camp && camp.members.length) {
      const loyal = camp.members.filter((m) => m.loyalty >= 70).length;
      P.push(loyal ? `${loyal} of your crew would take a bullet for you, and ${loyal === 1 ? 'one' : 'some'} already did.` : 'Your crew stayed for the money. You never gave them a reason to stay for anything else.');
    }
    if (e.blood) P.push('You emptied every chair at the table. The families remember you as the flood.');
    if (e.crown) P.push('Every city on the coast paid the same man at the end of the week. It was you.');
    if (e.badge) P.push('You wore the wire. The families went away for a long time, and so did you, under a name that isn\'t yours.');
    const rings = pl.street && pl.street.corps ? Object.keys(pl.street.corps.owned || {}).length : 0;
    if (rings >= 9) P.push('And every light of the spectrum answers to you. Somewhere past the moon, things are looking this way.');
    else if (rings > 1) P.push(`${rings} rings in a cigar box under your bed. Nobody would believe you.`);
    else if (rings === 1) P.push('Some nights the ring hums. You pretend not to hear it.');
    const fq = pl.fearQ || {};
    if (fq.halDead) P.push('A test pilot died on the Dustwater strip because a man in a cape asked you to. You think about that more than you expected.');
    if (fq.gperks && fq.gperks.knight) P.push('Hal still flies over sometimes, low, and waggles his wings.');
    const heists = pl.street && pl.street.mem ? pl.street.mem.ev.filter((x) => x.k === 'heist').length : 0;
    if (heists) P.push(`${heists} vault${heists > 1 ? 's' : ''} opened. The Herald called it the crime of the decade. Every time.`);
    if (pl.sweetheart >= 0 && g.pop.people[pl.sweetheart] && g.pop.people[pl.sweetheart].alive) P.push(`${g.pop.short(g.pop.people[pl.sweetheart])} still waits up for you. Don't make them wait too long.`);
    P.push(hon > inf ? 'Whatever happens next, they\'ll say you were better than you had to be.' : inf > hon + 30 ? 'Whatever happens next, nobody will cry at the funeral. They\'ll just be relieved.' : 'Whatever happens next, the coast will keep a place for you. It isn\'t decided yet which one.');
    return P;
  };
  SN.openLegend = function (title) {
    const g = G(), ui = g.ui;
    const html = ui.header(title || 'Your Legend', `As of ${R.calendar(g.pop.day, true)} · Year ${this.date(g.pop.day).year}`) + `<div class="body"><div class="news legend">${this.legend().map((p) => `<p>${p.replace(/[&<>]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]))}</p>`).join('')}</div></div>`;
    ui.openSheet('legend', html);
  };

  // ---------------------------------------------------------------- per-frame
  SN.update = function (dt) {
    const g = G(), pl = g.player;
    if (!g.started) return;
    const season = this.season(), hol = this.holiday(), hr = g.clock.hour(), night = g.clock.isNight();
    // announce seasons and holidays once
    if (this.lastSeason !== season) { if (this.lastSeason) { g.ui.toast({ winter: 'Winter. Snow on the ground up north, and creeping south.', spring: 'Spring. Rain, and everyone\'s in a better mood.', summer: 'Summer. Heat on the asphalt and short tempers.', fall: 'Fall. The leaves turn and the nights get longer.' }[season]); g.pop.addNews('port', { winter: 'First frost reported in Port Hollow. Dockworkers demand hot coffee rights.', spring: 'Spring cleaning: city crews repaint the crosswalks, again.', summer: 'Heat advisory: Dustwater hits 110. Ice cream trucks report record sales.', fall: 'Leaves down, Hawks down. The season is over and so, sadly, is the Hawks\'.' }[season]); } this.lastSeason = season; }
    if (hol && this.lastHol !== hol + g.pop.day) { this.lastHol = hol + g.pop.day; g.ui.toast({ fourth: 'The Fourth of July. Fireworks over every city tonight.', halloween: 'Halloween week. Kids in masks, pumpkins on porches. Nobody looks twice at a mask.', christmas: 'Christmas lights are up all over the coast.', newyear: 'New Year\'s Eve. Fireworks at midnight.' }[hol], 'good'); }
    // falling leaves in autumn, near trees
    if (season === 'fall' && !pl.room && R.rng() < dt * 6) { const x = g.cam.x + (R.rng() - 0.5) * 300, y = g.cam.y - 120 + R.rng() * 60; g.fx.add({ x, y, vx: 10 + R.rng() * 20, vy: 18 + R.rng() * 10, life: 5, max: 5, c: R.rng.pick(['#c8641c', '#a8401a', '#d8a030', '#8a5a1a']), s: 2 }); }
    // fireworks
    if ((hol === 'fourth' && night && hr >= 21) || (hol === 'newyear' && (hr >= 23 || hr < 1))) {
      if (!pl.room && R.rng() < dt * 1.5) this.firework();
    }
    // Halloween: masks everywhere, so your mask doesn't stand out
    if (hol === 'halloween') pl.halloween = true; else pl.halloween = false;
    this.t -= dt;
    if (this.t > 0) return;
    this.t = 0.25;
    // footprints and fidgets for people near you
    this.steps(g);
    this.fidget(g);
  };
  SN.firework = function () {
    const g = G(), x = g.cam.x + (R.rng() - 0.5) * 360, y = g.cam.y - 60 - R.rng() * 80;
    const c = R.rng.pick(['#ff4040', '#40a0ff', '#ffffff', '#ffe040', '#60ff80', '#ff60d0']);
    for (let k = 0; k < 40; k++) { const a = (k / 40) * Math.PI * 2, sp = 60 + R.rng() * 40; g.fx.add({ x, y, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp, g: 40, life: 1.4, max: 1.4, c, s: 2, glow: 1 }); }
    g.fx.flash && g.fx.flash(x, y);
    g.audio.sfx('thud', x, y);
  };
  // footprints: snow, sand, mud
  SN.steps = function (g) {
    const w = g.world, pl = g.player, snowy = g.env.weather.snow || (this.season() === 'winter' && pl.y / TS / w.H < 0.5);
    const walkers = [pl].concat(g.actors.near(pl.x, pl.y, TS * 14, (a) => a.kind === 'h' && !a.dead && !a.inCar && !a.room));
    for (const a of walkers) {
      if (a.inCar || (a === pl && pl.room)) continue;
      const tx = (a.x / TS) | 0, ty = (a.y / TS) | 0, t = w.t(tx, ty);
      const kind = t === T.SNOW || (snowy && t !== T.WATER && t !== T.DEEP && t !== T.BLDG && t !== T.WALL && t !== T.BRIDGE && t !== T.DOCK) ? 'snow' : t === T.DESERT || t === T.SAND ? 'sand' : t === T.MARSH || (g.env.weather.rain > 0.3 && (t === T.DIRT || t === T.DIRTROAD)) ? 'mud' : null;
      if (!kind) continue;
      const lx = a._fx, ly = a._fy;
      if (lx != null && Math.hypot(a.x - lx, a.y - ly) < 6) continue;
      a._fx = a.x; a._fy = a.y; a._fs = -(a._fs || 1);
      const ang = lx != null ? Math.atan2(a.y - ly, a.x - lx) + Math.PI / 2 : 0;
      const ox = Math.cos(ang) * 1.5 * a._fs, oy = Math.sin(ang) * 1.5 * a._fs;
      g.fx.decal({ x: a.x + ox, y: a.y + oy, r: 0.8, c: kind === 'snow' ? 'rgba(120,135,160,0.5)' : kind === 'sand' ? 'rgba(110,80,40,0.35)' : 'rgba(40,28,16,0.45)', t: kind === 'snow' ? 1200 : 600 });
    }
  };
  // idle people fidget: a cigarette, a watch, a stretch, a look around
  SN.fidget = function (g) {
    const pl = g.player, hr = g.clock.hour();
    for (const a of g.actors.near(pl.x, pl.y, TS * 12, (q) => q.kind === 'h' && !q.dead && !q.inCar && (q.state === 'idle' || q.state === 'hang') && !q.crew && !q.cop)) {
      if (a.smokeT > 0) { a.smokeT -= 0.25; if (R.rng() < 0.5) g.fx.add({ x: a.x + (a.dir === 0 ? 3 : a.dir === 2 ? -3 : 2), y: a.y - 20, vx: (R.rng() - 0.5) * 6, vy: -8 - R.rng() * 6, life: 1.6, max: 1.6, c: 'rgba(210,210,210,0.55)', s: 1 }); continue; }
      if (R.rng() > 0.035) continue;
      const r = R.rng();
      if (r < 0.3 && (a.arch === 'tough' || a.arch === 'hustler' || a.arch === 'gossip' || R.rng() < 0.3)) { a.smokeT = 8 + R.rng() * 8; g.fx.add({ x: a.x + 2, y: a.y - 18, vx: 0, vy: 0, life: 0.2, max: 0.2, c: '#ffb040', s: 1, glow: 1 }); }
      else if (r < 0.5) g.actors.say(a, R.rng.pick(['*checks watch*', '*taps foot*', '*hums*', '*sighs*']));
      else if (r < 0.65 && hr < 9) g.actors.say(a, R.rng.pick(['*yawns*', '*stretches*']));
      else if (r < 0.85) { a.dir = (a.dir + (R.rng() < 0.5 ? 1 : 3)) % 4; }
      else if (hr >= 12 && hr < 14) g.actors.say(a, R.rng.pick(['*eats a sandwich*', 'Where\'s a guy get lunch around here?']));
    }
  };

  // ---------------------------------------------------------------- wiring
  SN.init = function () {
    this.t = 1; this.lastSeason = this.season(); this.lastHol = null;
    if (this.wired) return;
    this.wired = true;
    // winter pushes the snow line south; seasons shift the weather
    const E = R.Env.prototype, bUpd = E.update;
    E.update = function (dt) {
      const r = bUpd.apply(this, arguments);
      const g = this.game, pl = g.player, s = SN.season();
      if (s === 'winter') { const fy = pl.y / TS / g.world.H, fx = pl.x / TS / g.world.W; if (!(fx > 0.6 && fy > 0.6)) this.weather.snow = this.weather.snow || fy < 0.55; }
      return r;
    };
    const bSet = E.setWeather;
    E.setWeather = function (kind) {
      const s = SN.season();
      if (s === 'summer' && (kind === 'rain' || kind === 'fog') && R.rng() < 0.35) kind = R.rng() < 0.5 ? 'clear' : 'heat';
      if ((s === 'spring' || s === 'fall') && kind === 'clear' && R.rng() < 0.3) kind = R.rng() < 0.6 ? 'rain' : 'cloudy';
      if (s === 'winter' && kind === 'heat') kind = 'cloudy';
      return bSet.call(this, kind);
    };
    // holiday decorations and night lights, drawn with the emissive layer
    const bDraw = R.fearQuest.draw;
    R.fearQuest.draw = function (g) {
      bDraw.apply(this, arguments);
      const game = G(), hol = SN.holiday(), pl = game.player;
      if (!hol || pl.room || !game.clock.isNight() && hol !== 'halloween') return;
      const cam = game.cam, t = game.clock.real;
      for (const b of game.world.buildings) {
        if (!b || b.destroyed || !b.out) continue;
        if (Math.abs(b.out.x * TS - cam.x) > 260 || Math.abs(b.out.y * TS - cam.y) > 180) continue;
        const fy = (b.y + b.h) * TS - 2;
        if (hol === 'christmas' && R.hash2(b.id, 3, 3) < 0.7) {
          for (let x = b.x * TS + 2; x < (b.x + b.w) * TS - 2; x += 4) { const k = ((x / 4) | 0) + Math.floor(t * 2); g.fillStyle = ['#ff3a3a', '#3aff6a', '#ffd83a', '#5aa8ff'][k % 4]; g.fillRect(x, fy - 1 + ((x / 4) % 2), 1, 1); }
        }
        if (hol === 'halloween' && D.btypes[b.type].house && R.hash2(b.id, 4, 4) < 0.5) {
          const x = (b.door.x + 1.2) * TS, y = fy + 4;
          g.fillStyle = '#c85a10'; g.fillRect(x - 3, y - 4, 6, 5); g.fillStyle = '#3a6a1a'; g.fillRect(x, y - 5, 1, 1);
          if (game.clock.isNight()) { g.fillStyle = `rgba(255,200,60,${0.7 + Math.sin(t * 9 + b.id) * 0.2})`; g.fillRect(x - 2, y - 3, 1, 1); g.fillRect(x + 1, y - 3, 1, 1); g.fillRect(x - 1, y - 1, 3, 1); }
        }
      }
    };
    // Halloween: a mask draws no attention, so witnesses don't count it against you
    const L = R.Law.prototype, bCrime = L.crime;
    L.crime = function (type, x, y, opts) { const g = G(); if (g.player.halloween && g.player.masked && type === 'masked') return; return bCrime.apply(this, arguments); };
    // conversations: a slow push-in on the people talking
    const RP = R.Renderer.prototype, bRender = RP.render;
    RP.render = function () {
      const g = this.game, talking = g.ui && g.ui.sheetOpen === 'talk' && !g.player.inCar;
      if (!talking) return bRender.apply(this, arguments);
      const bz = this.baseZoom;
      this.baseZoom = bz * 1.25;
      try { return bRender.apply(this, arguments); } finally { this.baseZoom = bz; }
    };
    // the legend: a button in the menu's stats tab, and after each road to the top
    const U = R.UI.prototype, bTab = U.openMenuTab;
    U.openMenuTab = function (tab) {
      const r = bTab.apply(this, arguments);
      if (tab === 'stats') { const body = document.getElementById('mbody'); if (body && !body.querySelector('[data-legend]')) { body.insertAdjacentHTML('afterbegin', '<button class="opt go" data-legend="1" style="margin-bottom:8px">Read your legend<small>What the coast will say about you</small></button>'); body.querySelector('[data-legend]').addEventListener('click', () => { G().audio.sfx('click'); SN.openLegend(); }); } }
      return r;
    };
    const bStory = U.story;
    U.story = function (title, text, cb) {
      if (/^(BLOOD|CROWN|BADGE): /.test(title)) return bStory.call(this, title, text, () => { cb && cb(); setTimeout(() => SN.openLegend('The Legend of the Brass Coast'), 300); });
      return bStory.apply(this, arguments);
    };
    const st = document.createElement('style');
    st.textContent = '.legend p{font-size:15px;line-height:1.35;margin:8px 0}.legend p:first-child:first-letter{font-family:var(--pix);font-size:26px;float:left;line-height:1;margin:2px 6px 0 0;color:var(--red)}';
    document.head.appendChild(st);
  };
})();
