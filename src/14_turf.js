// RHAPSODY — the families live without you. Every morning each family with a don decides
// what to do: build up, move on a rival's turf, go to war, lean on your rackets, or send
// somebody to settle a score with you. Wars spill into the streets as shootouts. Cities
// you've taken have to be held: loyalty fades, the old family's loyalists plot a comeback,
// and if you're not there when they make their move, the city slips away.
'use strict';
(function () {
  const D = R.data, TS = R.TILE;
  const G = () => R.game;
  const TF = (R.turf = { live: [] });
  const FAMS = D.cities.map((c) => c.family);
  const PLF = (f) => (/[sx]$/.test(f) ? `the ${f} family` : `the ${f}s`);
  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
  const key = (a, b) => [a, b].sort().join('|');

  TF.state = function () {
    const pl = G().player;
    if (!pl.turf) {
      const rnd = R.mulberry(G().seed + 404);
      const s = { str: {}, grudge: {}, rel: {}, wars: [], loyalty: {}, squadDay: {}, lost: {}, log: [] };
      for (const f of FAMS) { s.str[f] = 55 + Math.round(rnd() * 20); s.grudge[f] = 0; }
      for (let i = 0; i < FAMS.length; i++) for (let j = i + 1; j < FAMS.length; j++) s.rel[key(FAMS[i], FAMS[j])] = Math.round(rnd() * 80 - 40);
      pl.turf = s;
    }
    return pl.turf;
  };
  const C = () => R.campaign;
  const alive = (f) => !C().donGone(f) && !C().state().ruled[(G().jobs.cityOfFamily(f) || {}).id];
  TF.atWar = function (a, b) { return this.state().wars.some((w) => w.a === a && w.b === b || w.a === b && w.b === a); };
  TF.note = function (text, city) { const s = this.state(), g = G(); s.log.unshift({ day: g.pop.day, text }); if (s.log.length > 14) s.log.pop(); if (city) g.pop.addNews(city, text); };

  // ---------------------------------------------------------------- the morning meeting
  TF.daily = function () {
    const g = G(), pl = g.player, s = this.state(), day = g.pop.day;
    const live = FAMS.filter(alive);
    for (const f of FAMS) {
      if (!alive(f)) { s.str[f] = Math.max(0, s.str[f] - 3); continue; }
      const c = g.jobs.cityOfFamily(f);
      s.str[f] = R.clamp(s.str[f] + 2 + (c ? (c.prosperity - 50) / 25 : 0), 0, 100);
      s.grudge[f] = Math.max(0, s.grudge[f] - 3);
    }
    // wars run their course
    for (const w of s.wars.slice()) {
      const loss = 3 + R.rng() * 4;
      s.str[w.a] = Math.max(0, s.str[w.a] - loss * (s.str[w.b] / 70)); s.str[w.b] = Math.max(0, s.str[w.b] - loss * (s.str[w.a] / 70));
      w.days++;
      if (R.rng() < 0.4) this.note(R.rng.pick([`Three men shot outside a ${R.rng.pick(['bakery', 'social club', 'laundromat', 'bowling alley'])}. Police blame the ${w.a}-${w.b} feud.`, `Another car bomb in the ${w.a}-${w.b} war. "It has to stop," says the mayor.`, `${w.a} and ${w.b} soldiers exchange fire in broad daylight.`]), (g.jobs.cityOfFamily(R.rng.pick([w.a, w.b])) || {}).id);
      if (w.days > 4 && (R.rng() < 0.25 || Math.min(s.str[w.a], s.str[w.b]) < 15 || !alive(w.a) || !alive(w.b))) {
        s.wars.splice(s.wars.indexOf(w), 1);
        s.rel[key(w.a, w.b)] = 0;
        const win = s.str[w.a] >= s.str[w.b] ? w.a : w.b, lose = win === w.a ? w.b : w.a;
        this.note(`A sit-down ends the war between ${PLF(w.a)} and ${PLF(w.b)}. ${win} comes out on top.`, (g.jobs.cityOfFamily(lose) || {}).id);
      }
    }
    // each family makes one move
    for (const f of live) {
      const r = R.rng();
      const enemies = live.filter((o) => o !== f).sort((a, b) => s.rel[key(f, a)] - s.rel[key(f, b)]);
      const foe = enemies[0];
      // settle scores with you first
      if (s.grudge[f] >= 30 && f !== pl.family && (s.squadDay[f] || -9) < day - 1) { s.squadDay[f] = day; this.pendingSquad = f; continue; }
      if (s.grudge[f] >= 20 && r < 0.5 && this.hitRacket(f)) continue;
      if (foe && s.rel[key(f, foe)] < -35 && !this.atWar(f, foe) && s.wars.length < 2 && r < 0.35) {
        s.wars.push({ a: f, b: foe, days: 0 });
        this.note(`WAR: ${PLF(f)} and ${PLF(foe)} are at war. Stay off the streets after dark.`, (g.jobs.cityOfFamily(f) || {}).id);
        if (f === pl.family || foe === pl.family) g.ui.toast(`Your family is at war with ${PLF(f === pl.family ? foe : f)}. Their soldiers will shoot on sight.`, 'bad');
        continue;
      }
      if (foe && r < 0.5) s.rel[key(f, foe)] = R.clamp(s.rel[key(f, foe)] - R.rng.int(2, 9), -100, 100);
      else if (foe && r < 0.6) s.rel[key(f, enemies[enemies.length - 1])] = R.clamp(s.rel[key(f, enemies[enemies.length - 1])] + 5, -100, 100);
    }
    this.holdCities();
  };
  // a rival leans on one of your rackets
  TF.hitRacket = function (f) {
    const g = G(), pl = g.player, s = this.state();
    const mine = g.world.buildings.filter((b) => b && b.racket && b.racketFamily === pl.family && !b.destroyed && !s.lost[b.id]);
    if (!mine.length) return false;
    const b = R.rng.pick(mine);
    s.lost[b.id] = f; b.racketFamily = f;
    this.note(`${f} collectors are working ${b.name} now. The owner says he "doesn't want trouble".`, b.city.id);
    g.ui.toast(`${PLF(f)} muscled in on ${b.name}. Run their collectors off to take it back.`, 'bad');
    return true;
  };

  // ---------------------------------------------------------------- cities you hold
  TF.holdCities = function () {
    const g = G(), pl = g.player, s = this.state(), ruled = C().state().ruled;
    for (const id in ruled) {
      const c = g.world.cities.find((x) => x.id === id);
      if (!c) continue;
      if (s.loyalty[id] == null) s.loyalty[id] = 70;
      const visited = (c.lastVisit || 0) >= g.pop.day - 2;
      s.loyalty[id] = R.clamp(s.loyalty[id] - (visited ? 2 : 6) + (c.prosperity > 60 ? 2 : 0), 0, 100);
      const old = ruled[id];
      if (s.loyalty[id] < 30 && !s.revolt) {
        s.revolt = { city: id, fam: old, day: g.pop.day + 2 };
        g.ui.story('LOYALISTS', `What's left of ${PLF(old)} is arming up in ${c.name}. They mean to take it back.\n\nBe at the social club in ${c.name} within two days, or the city is theirs again.`);
      }
    }
    // a revolt you didn't answer
    if (s.revolt && g.pop.day >= s.revolt.day && !s.revolt.fighting) {
      const c = g.world.cities.find((x) => x.id === s.revolt.city);
      this.loseCity(c, s.revolt.fam);
    }
  };
  TF.loseCity = function (c, fam) {
    const g = G(), s = this.state(), cs = C().state();
    delete cs.ruled[c.id];
    c.ruler = fam;
    for (const b of c.buildings) if (b && b.type === 'social') b.playerOwned = false;
    for (const p of g.pop.byCity[c.id] || []) if (p.alive && p.faction === g.player.family && !p.isDon) p.faction = fam;
    s.str[fam] = Math.max(s.str[fam], 35);
    s.revolt = null; s.loyalty[c.id] = null;
    g.miniDirty = true;
    this.note(`The ${fam} name is back over the door in ${c.name}. "We never left," says a man in a new suit.`, c.id);
    g.ui.story(`${c.name.toUpperCase()} IS LOST`, `The ${fam} loyalists took ${c.name} back while you were away. You'll have to take it again.`);
  };
  TF.feast = function (c) {
    const g = G(), pl = g.player, s = this.state();
    if (!pl.pay(300)) return g.ui.toast('A feast for the neighborhood runs $300.', 'warn');
    s.loyalty[c.id] = Math.min(100, (s.loyalty[c.id] || 50) + 25);
    g.ui.toast(`Sausage and peppers for every family on the block. ${c.name} remembers who pays. (loyalty ${Math.round(s.loyalty[c.id])})`, 'good');
  };

  // ---------------------------------------------------------------- live events
  const spawnGun = (fam, x, y, tag) => {
    const g = G();
    const s = g.world.findNear(x | 0, y | 0, 0, 5, (xx, yy) => !g.world.solidPed(xx, yy) && !g.world.isWater(xx, yy));
    if (!s) return null;
    const h = g.actors.makeHuman(s.x * TS + 8, s.y * TS + 8, { faction: fam, weapon: R.rng.pick(['revolver', 'revolver', 'shotgun', 'magnum', 'chopper']), arch: 'tough', tag: tag || 'turf', cash: R.rng.int(15, 70) });
    h.keep = true; h.tr.brave = Math.max(h.tr.brave, 0.85); h.turf = true;
    TF.live.push(h);
    return h;
  };
  TF.update = function (dt) {
    const g = G(), pl = g.player, s = this.state();
    this.live = this.live.filter((h) => !h.dead && !h.removed && g.actors.list.includes(h) && (Math.hypot(h.x - pl.x, h.y - pl.y) < TS * 60 || (h.keep = false)));
    if (pl.room || pl.dead) return;
    const px = pl.x / TS, py = pl.y / TS;
    const city = g.world.cityAt(px | 0, py | 0);
    if (city) city.lastVisit = g.pop.day;
    // hit squads
    if (this.pendingSquad && !g.law.incident && !pl.inCar) {
      const f = this.pendingSquad; this.pendingSquad = null;
      const sp = g.world.findNear(px, py, 16, 22, (x, y) => !g.world.solidPed(x, y) && !g.world.isWater(x, y));
      if (sp) {
        const n = s.grudge[f] > 60 ? 4 : 3;
        for (let i = 0; i < n; i++) { const h = spawnGun(f, sp.x + i, sp.y, 'squad'); if (h) { h.hostileLocked = true; h.hostile = true; g.actors.setFight(h, pl); } }
        s.grudge[f] = Math.max(0, s.grudge[f] - 25);
        g.ui.toast(`A ${f} crew is here for you. Somebody talked.`, 'bad');
        this.note(`Gunmen went looking for a young man in a good suit. Nobody's talking.`, null);
      }
    }
    this.t = (this.t == null ? 30 : this.t) - dt;
    if (this.t <= 0) {
      this.t = 70 + R.rng() * 90;
      // shootouts where the war is
      if (city && s.wars.length && this.live.length < 4) {
        const w = s.wars.find((x) => [x.a, x.b].some((f) => (g.jobs.cityOfFamily(f) || {}).id === city.id));
        if (w && R.rng() < 0.7) {
          const sp = g.world.findNear(px, py, 12, 18, (x, y) => !g.world.solidPed(x, y) && !g.world.isWater(x, y) && D.roadTile[g.world.t(x, y)]);
          if (sp) {
            const A = [], B = [];
            for (let i = 0; i < 2 + (R.rng() < 0.5 ? 1 : 0); i++) { const a = spawnGun(w.a, sp.x - 3, sp.y + i); const b = spawnGun(w.b, sp.x + 4, sp.y + i); if (a) A.push(a); if (b) B.push(b); }
            A.forEach((a, i) => B[i % B.length] && g.actors.setFight(a, B[i % B.length]));
            B.forEach((b, i) => A[i % A.length] && g.actors.setFight(b, A[i % A.length]));
            if (A[0]) g.actors.say(A[0], R.rng.pick([`This is ${w.a} turf!`, `For Don ${g.jobs.donName(w.a)}!`, 'Light \'em up!']));
            g.ui.toast(`Shooting in the street: ${w.a} and ${w.b} soldiers. Their war, not yours. Unless you make it yours.`, 'warn');
          }
        }
      }
    }
    // collectors on the rackets they took from you
    for (const id in s.lost) {
      const b = g.world.buildings[id];
      if (!b || b.destroyed) { delete s.lost[id]; continue; }
      const d = Math.hypot(px - b.out.x, py - b.out.y);
      if (d < 14 && !b.collectors) {
        b.collectors = [];
        for (let i = 0; i < 2; i++) { const h = spawnGun(s.lost[id], b.out.x + i * 2 - 1, b.out.y + 2, 'collector'); if (h) { h.stay = true; h.state = 'idle'; h.timer = 1e9; b.collectors.push(h); } }
        if (b.collectors[0]) g.actors.say(b.collectors[0], 'Keep walking. This place pays us now.');
      }
      if (b.collectors && b.collectors.length && b.collectors.every((h) => h.dead || h.down > 0)) {
        b.racketFamily = pl.family; delete s.lost[id]; b.collectors = null;
        g.ui.toast(`${b.name} pays you again. The owner looks relieved, mostly.`, 'good');
      } else if (b.collectors && d < 5) for (const h of b.collectors) if (!h.dead && h.state !== 'fight') { h.stay = false; h.hostile = true; g.actors.setFight(h, pl); }
    }
    // a revolt you showed up for
    if (s.revolt && city && city.id === s.revolt.city && !s.revolt.fighting) {
      const club = city.buildings.find((b) => b && b.type === 'social');
      if (club && Math.hypot(px - club.out.x, py - club.out.y) < 14) {
        s.revolt.fighting = true; s.revolt.foes = [];
        for (let i = 0; i < 5; i++) { const h = spawnGun(s.revolt.fam, club.out.x + R.rng.int(-6, 6), club.out.y + R.rng.int(3, 8), 'loyalist'); if (h) { h.hostile = true; h.hostileLocked = true; g.actors.setFight(h, pl); s.revolt.foes.push(h); } }
        g.ui.toast(`${s.revolt.fam} loyalists at the club! Put them down and ${city.name} stays yours.`, 'bad');
      }
    }
    if (s.revolt && s.revolt.fighting && s.revolt.foes && s.revolt.foes.every((h) => h.dead || h.down > 0 || h.removed)) {
      s.loyalty[s.revolt.city] = 80; s.revolt = null;
      g.ui.story('THE CITY HOLDS', 'The loyalists are finished. Nobody will try that again for a long time.');
      pl.rep.infamy += 3;
    }
  };

  // ---------------------------------------------------------------- scores
  TF.onKill = function (h, byPlayer) {
    if (!byPlayer || !h || h.kind !== 'h') return;
    const g = G(), pl = g.player, s = this.state(), f = h.faction;
    if (!f || f === 'law' || !s.grudge.hasOwnProperty(f) || f === pl.family) return;
    s.grudge[f] = Math.min(100, s.grudge[f] + (h.person && h.person.isDon ? 40 : h.boss ? 15 : 7));
    s.str[f] = Math.max(0, s.str[f] - 1.5);
    // their rivals like you for it
    for (const o of FAMS) if (o !== f && o !== pl.family && this.atWar(o, f)) g.jobs.standing[o] = Math.min(100, (g.jobs.standing[o] || 0) + 2);
  };

  // ---------------------------------------------------------------- the jobs tab
  TF.html = function () {
    const g = G(), pl = g.player, s = this.state(), ruled = C().state().ruled;
    let h = '<div class="sect">The families</div>';
    for (const f of FAMS) {
      const dead = !alive(f);
      const st = Math.round(s.str[f]), gr = Math.round(s.grudge[f]);
      const wars = s.wars.filter((w) => w.a === f || w.b === f).map((w) => (w.a === f ? w.b : w.a));
      h += `<p style="margin:4px 0"><b>${esc(f)}</b>${f === pl.family ? ' (yours)' : ''} ${dead ? '· <i>finished</i>' : `<span class="meter" style="display:inline-block;width:5em;vertical-align:middle"><i style="width:${st}%;background:var(--gold)"></i></span> ${st}`}${wars.length ? ` · <b style="color:var(--red)">at war with ${wars.map(esc).join(', ')}</b>` : ''}${gr >= 10 && f !== pl.family ? ` · <span style="color:var(--red)">grudge against you ${gr}</span>` : ''}</p>`;
    }
    const held = Object.keys(ruled);
    if (held.length) h += `<p><b>Cities you hold:</b> ${held.map((id) => { const c = g.world.cities.find((x) => x.id === id); return `${esc(c ? c.name : id)} (loyalty ${Math.round(s.loyalty[id] == null ? 70 : s.loyalty[id])})`; }).join(' · ')}<br><small>Loyalty fades when you stay away. Throw a feast at the club to win hearts.</small></p>`;
    if (s.revolt) h += `<p style="color:var(--red)"><b>Loyalists are rising in ${esc((g.world.cities.find((x) => x.id === s.revolt.city) || {}).name || '')}.</b> Get to the club before day ${s.revolt.day + 1}.</p>`;
    const lost = Object.keys(s.lost);
    if (lost.length) h += `<p>Rackets taken from you: ${lost.map((id) => `${esc(g.world.buildings[id].name)} (${esc(s.lost[id])})`).join(', ')}</p>`;
    if (s.log.length) h += `<p style="font-size:13px;color:var(--brown)">${s.log.slice(0, 4).map((l) => `Day ${l.day + 1}: ${esc(l.text)}`).join('<br>')}</p>`;
    return h;
  };

  TF.init = function (g) {
    this.live = []; this.pendingSquad = null;
    if (!this.onKillFn) this.onKillFn = (h, by) => TF.onKill(h, by);
    const ls = R.bus.map.get('actor:died');
    if (!ls || !ls.includes(this.onKillFn)) R.bus.on('actor:died', this.onKillFn);
    if (this.wrapped) return;
    this.wrapped = true;
    const J = R.Jobs.prototype, jd = J.daily;
    J.daily = function () { jd.call(this); TF.daily(); };
    const cj = R.campaign.jobsHtml;
    R.campaign.jobsHtml = function () { return cj.call(this) + TF.html(); };
    // a feast at a club you rule
    const U = R.UI.prototype, io = U.interiorOptions;
    U.interiorOptions = function (b) {
      const o = io.call(this, b);
      if (b.type === 'social' && C().state().ruled[b.city.id]) o.unshift({ label: 'Throw a feast for the neighborhood', price: '$300', small: `Loyalty in ${b.city.name}: ${Math.round(TF.state().loyalty[b.city.id] == null ? 70 : TF.state().loyalty[b.city.id])}`, fn: () => TF.feast(b.city) });
      return o;
    };
    // families at war with yours shoot your people, and you, on sight
    const AP = R.Actors.prototype, think = AP.updateHuman;
    AP.updateHuman = function (h, dt) {
      const r = think.apply(this, arguments);
      if (h.faction && h.turf === undefined && h.armed && !h.hostile && !h.dead && h.state !== 'fight') {
        const pl = G().player;
        if (pl.family && TF.atWar(h.faction, pl.family) && Math.hypot(h.x - pl.x, h.y - pl.y) < TS * 7 && R.rng() < dt * 0.3) { h.hostile = true; this.setFight(h, pl); this.say(h, `You're ${pl.family}! Get him!`); }
      }
      return r;
    };
  };
})();
