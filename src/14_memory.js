// RHAPSODY — the world remembers. Everything you do that people would talk about goes into
// one event log: who, what, where, whether you were seen and what you were wearing. The log
// feeds everything that talks back: the morning Herald (newsboys shout the headline on
// street corners, and a copy waits by your bed), people gossiping about it on the street
// (and doing a double take if you walk past in the same shirt), and an unmarked sedan that
// parks outside your place once a detective's case is warm.
'use strict';
(function () {
  const D = R.data, TS = R.TILE;
  const G = () => R.game;
  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
  const MEM = (R.memory = { t: 0 });

  MEM.state = function () {
    const pl = G().player;
    pl.street = pl.street || {};
    return (pl.street.mem = pl.street.mem || { ev: [], papers: {}, read: -1 });
  };
  // how people describe you: what they could see
  MEM.looks = function () {
    const pl = G().player, st = D.style, s = pl.style || {};
    if (pl.masked) return 'a masked man';
    const shirt = st.shirts[s.shirt], jacket = s.jacket && s.jacket !== 'none' ? st.jackets[s.jacket] : null, hat = s.hat && s.hat !== 'none' ? st.hats[s.hat] : null;
    const bits = [];
    if (jacket) bits.push(`a ${jacket.name.toLowerCase().replace(/^(no jacket|charcoal two-piece)$/, 'dark suit')}`);
    else if (shirt) bits.push(`a ${shirt.name.toLowerCase()} shirt`);
    if (hat) bits.push(`a ${hat.name.toLowerCase()}`);
    return 'a man in ' + (bits.join(' and ') || 'a wide collar');
  };
  MEM.cityName = function (x, y) { const c = G().world.cityAt((x / TS) | 0, (y / TS) | 0); return c ? c.name : 'the County'; };
  MEM.cityId = function (x, y) { const c = G().world.cityAt((x / TS) | 0, (y / TS) | 0); return c ? c.id : 'county'; };
  MEM.streetNear = function (x, y) {
    const g = G(), b = g.world.buildings.filter((q) => q && !q.destroyed && q.name && Math.abs(q.out.x * TS - x) < TS * 14 && Math.abs(q.out.y * TS - y) < TS * 14).sort((a, c) => Math.hypot(a.out.x * TS - x, a.out.y * TS - y) - Math.hypot(c.out.x * TS - x, c.out.y * TS - y))[0];
    return b ? `outside ${b.name}` : `in ${this.cityName(x, y)}`;
  };
  // record something people would talk about
  MEM.log = function (k, o) {
    const g = G(), s = this.state();
    const e = Object.assign({ k, day: g.pop.day, t: g.clock.t, city: this.cityId(o.x, o.y), cityName: this.cityName(o.x, o.y), where: this.streetNear(o.x, o.y), looks: this.looks(), masked: !!g.player.masked, shirt: g.player.style && g.player.style.shirt }, o);
    delete e.x; delete e.y;
    s.ev.unshift(e);
    if (s.ev.length > 120) s.ev.length = 120;
    return e;
  };
  MEM.recent = function (days, pred) { const d = G().pop.day; return this.state().ev.filter((e) => d - e.day <= days && (!pred || pred(e))); };

  // ---------------------------------------------------------------- the Herald
  const HEAD = {
    murder: (e) => [`${e.victim ? e.victim.toUpperCase() + ' SLAIN' : 'MAN SLAIN'} ${e.cityName === 'the County' ? 'IN THE COUNTY' : 'IN ' + e.cityName.toUpperCase()}`, `${e.victim || 'A local'} was killed ${e.where} ${e.hour < 6 || e.hour > 20 ? 'late last night' : 'yesterday'}. ${e.seen ? `Witnesses describe ${e.looks}.` : 'Police say nobody saw a thing, and that nobody ever does.'}`],
    copMurder: (e) => [`OFFICER DOWN ${e.cityName === 'the County' ? 'ON COUNTY ROAD' : 'IN ' + e.cityName.toUpperCase()}`, `A police officer was shot and killed ${e.where}. The department has cancelled all leave. ${e.seen ? `They are looking for ${e.looks}.` : 'Every car in the county is being stopped.'}`],
    manslaughter: (e) => [`HIT AND RUN ${e.cityName === 'the County' ? 'ON THE HIGHWAY' : 'IN ' + e.cityName.toUpperCase()}`, `${e.victim || 'A pedestrian'} died ${e.where} after being struck by a car that did not stop.`],
    robbery: (e) => [`STICK-UP ${e.where.toUpperCase().replace(/^OUTSIDE /, 'AT ')}`, `A gunman emptied the register ${e.where}. ${e.seen ? `The clerk remembers ${e.looks}.` : 'Nobody got a good look.'}`],
    heist: (e) => ['BANK JOB STUNS COAST', `Thieves walked out of ${e.where.replace(/^outside /, '')} with a fortune. The Treasury has sent men from Washington.`],
    arson: (e) => [`BLAZE GUTS ${e.cityName.toUpperCase()} BLOCK`, `Firemen fought through the night ${e.where}. The fire marshal is calling it deliberate.`],
    explosion: (e) => ['BLAST ROCKS STREET', `An explosion ${e.where} shattered windows for two blocks. ${e.seen ? `Neighbours saw ${e.looks} walking away.` : 'Police have no suspects.'}`],
    shootout: (e) => [`GUNFIRE ${e.cityName === 'the County' ? 'IN THE COUNTY' : 'IN ' + e.cityName.toUpperCase()}`, `${e.n || 'Several'} shots were fired ${e.where}. ${e.seen ? `Witnesses describe ${e.looks}.` : 'Residents want to know where the police were.'}`],
    carjack: (e) => ['MOTORIST DRAGGED FROM CAR', `A driver was pulled from ${e.what || 'their car'} ${e.where}. ${e.seen ? `The thief: ${e.looks}.` : ''}`],
    rescue: (e) => [`"HE CAME OUT OF NOWHERE"`, `${e.victim ? e.victim : 'A resident'} was saved from an attacker ${e.where} by a stranger who then walked off without a word. ${e.masked ? 'The hero wore a mask.' : `Described as ${e.looks}.`}`],
    revive: (e) => ['MIRACLE ON ' + e.cityName.toUpperCase() + ' STREET', `${e.victim || 'A man'}, pronounced dead at the scene, got up and walked home. Doctors "cannot explain it."`],
    ring: (e) => [`STRANGE LIGHTS OVER ${e.cityName.toUpperCase()}`, `Residents ${e.where} report "a man throwing ${e.color || 'yellow'} light around like confetti." Observatory staff decline to comment.`],
  };
  const WEIGHT = { copMurder: 10, heist: 9, murder: 8, explosion: 7, arson: 7, revive: 7, shootout: 6, manslaughter: 6, robbery: 5, rescue: 5, carjack: 4, ring: 4 };
  const SPORTS = ['Harbor Hawks drop another one at home, 4-2', 'Dustwater Rodeo draws record crowd', 'Longshot "Lucky Collar" pays 30 to 1 at the Downs', 'Pinecrest bowling league scandal: "the pins were loaded"', 'Bayou Gators win the county cup in extra innings'];
  const ADS = ['WANTED: driver, no questions asked. Ask at the docks.', 'FOR SALE: 8-track player, barely stolen. $12.', 'LOST: grey cat, answers to "Mister". Reward.', 'DANCE LESSONS: learn the Hustle in one night. Club Tropicana.', 'ROOMS BY THE WEEK. Clean sheets, no cops.', 'PSYCHIC READINGS: know your future before it knows you.'];

  MEM.paper = function (day) {
    const g = G(), s = this.state();
    if (s.papers[day]) return s.papers[day];
    const evs = s.ev.filter((e) => e.day < day && e.day >= day - 2 && HEAD[e.k]).sort((a, b) => (WEIGHT[b.k] || 0) - (WEIGHT[a.k] || 0));
    const stories = [];
    const used = new Set();
    for (const e of evs) { const key = e.k + e.city; if (used.has(key)) continue; used.add(key); const [h, t] = HEAD[e.k](e); stories.push({ h, t, you: 1 }); if (stories.length >= 3) break; }
    for (const n of g.pop.news.filter((q) => q.day === day - 1 || q.day === day).slice(0, 5)) stories.push({ h: (g.pop.cityObj(n.city) || { name: 'County' }).name.toUpperCase() + ' BRIEFS', t: n.text });
    if (!stories.length) stories.push({ h: 'SLOW DAY ON THE COAST', t: 'Nothing happened yesterday, and the Herald would like to thank everyone involved.' });
    const rnd = R.mulberry(day * 7919 + 3);
    const P = { day, stories: stories.slice(0, 6), sports: SPORTS[(rnd() * SPORTS.length) | 0], ad: [ADS[(rnd() * ADS.length) | 0], ADS[(rnd() * ADS.length) | 0]].filter((v, i, a) => a.indexOf(v) === i), weather: g.env.weather.rain > 0.4 ? 'Showers, then more showers.' : g.env.weather.fog > 0.4 ? 'Fog off the water by morning.' : 'Fair and warm. Wide collars advised.' };
    s.papers[day] = P;
    for (const k of Object.keys(s.papers)) if (+k < day - 6) delete s.papers[k];
    return P;
  };
  MEM.headline = function (day) { const p = this.paper(day); return p.stories[0].h; };
  MEM.paperHtml = function (P) {
    const g = G();
    const lead = P.stories[0], rest = P.stories.slice(1);
    return `<div class="news herald"><h3>The Brass Coast Herald</h3><div class="dateline">${R.calendar(P.day, true)} · Morning edition · 25¢</div>` +
      `<h2 class="hl">${esc(lead.h)}</h2><p class="lede">${esc(lead.t)}</p>` +
      rest.map((s) => `<p><b>${esc(s.h)}</b> ${esc(s.t)}</p>`).join('') +
      `<div class="cols"><p><b>SPORTS</b> ${esc(P.sports)}</p><p><b>WEATHER</b> ${esc(P.weather)}</p></div>` +
      `<p class="ads"><b>CLASSIFIEDS</b> ${P.ad.map(esc).join(' &nbsp;·&nbsp; ')}</p></div>`;
  };
  MEM.read = function (day) {
    const g = G(), s = this.state();
    day = day == null ? g.pop.day : day;
    s.read = Math.max(s.read, day);
    const html = g.ui.header('The Morning Paper', 'Read all about it.') + `<div class="body">${this.paperHtml(this.paper(day))}</div>`;
    g.ui.openSheet('herald', html);
    const lead = this.paper(day).stories[0];
    if (lead.you && !g.player.masked && /Witnesses|remember|looking for|thief|Described/.test(lead.t)) setTimeout(() => g.ui.toast('That description sounds a lot like you. Maybe change your clothes.', 'warn'), 400);
  };

  // ---------------------------------------------------------------- newsboys
  MEM.spawnNewsboy = function () {
    const g = G(), pl = g.player, w = g.world;
    const s = w.findNear((pl.x / TS) | 0, (pl.y / TS) | 0, 6, 12, (x, y) => w.t(x, y) === D.T.WALK && !w.solidPed(x, y));
    if (!s) return;
    const h = g.actors.makeHuman(s.x * TS + 8, s.y * TS + 8, { tag: 'newsboy', kid: true, cash: 3, arch: 'friendly' });
    h.newsboy = true; h.strangerName = 'Newsboy'; h.keep = true; h.state = 'idle'; h.timer = 1e9; h.stay = true;
    this.boy = h; this.boyShout = 0;
  };
  MEM.boyTree = function (h) {
    const g = G(), ui = g.ui, pl = g.player;
    const hl = this.headline(g.pop.day);
    return { title: 'Newsboy', sub: 'A flat cap, a canvas bag, a voice that carries three blocks.', options: [
      { label: 'Buy the Herald', small: '25¢', cls: 'go', fn: () => { if (!pl.pay(1)) return ui.talkLine('No money, no news, mister.'); ui.closeSheet(); this.read(); } },
      { label: '"What\'s the big story?"', fn: () => ui.talkLine(`${hl}! Read all about it! ...That's all I know, I can't read.`) },
      { label: 'Leave', fn: () => ui.closeSheet() },
    ] };
  };

  // ---------------------------------------------------------------- gossip
  const GOSSIP = {
    murder: (e) => [`Did you hear? ${e.victim || 'Somebody'} got killed ${e.where}.`, e.seen ? `They say it was ${e.looks}.` : 'Nobody saw nothing. Figures.'],
    copMurder: () => ['They shot a cop. A COP.', 'This whole town\'s gonna get turned upside down.'],
    robbery: (e) => [`Somebody stuck up the place ${e.where}.`, 'Guy had a gun the size of my arm, I heard.'],
    heist: () => ['You hear about the bank?', 'Robin Hood, I say. Banks had it coming.'],
    shootout: (e) => [`Shots fired ${e.where} yesterday. Like a war.`, 'I kept my head down. You should too.'],
    arson: (e) => [`The fire ${e.where}... I could see it from my window.`, 'Insurance job, I bet.'],
    explosion: () => ['Heard the bang? Rattled my teeth.', 'Gas main, they say. Gas main my foot.'],
    rescue: (e) => [`Some guy saved ${e.victim || 'a lady'} ${e.where}. Just walked off after.`, 'Still some good people out there.'],
    revive: (e) => [`${e.victim || 'That fella'} came back from the dead, swear to God.`, 'My cousin saw it. White light, she said.'],
    ring: (e) => [`Somebody was throwing ${e.color || 'glowing'} light around ${e.where}.`, 'Swamp gas. Has to be swamp gas.'],
  };
  MEM.gossip = function (h, o) {
    const g = G(), pl = g.player;
    const city = this.cityId(h.x, h.y);
    const e = this.recent(2, (q) => GOSSIP[q.k] && (q.city === city || WEIGHT[q.k] >= 8))[0];
    if (!e) return false;
    const [a, b] = GOSSIP[e.k](e);
    g.actors.say(h, a);
    setTimeout(() => {
      if (o.dead || o.removed) return;
      g.actors.say(o, b);
      // the double take: same shirt, not masked, close enough to see
      if (e.seen && !e.masked && e.shirt && pl.style.shirt === e.shirt && !pl.masked && Math.hypot(pl.x - o.x, pl.y - o.y) < TS * 5 && R.rng() < 0.6) {
        setTimeout(() => { if (o.dead || o.removed) return; g.actors.say(o, R.rng.pick(['...hey. HEY. Isn\'t that...?', 'Wait. That shirt...', 'Don\'t look now, but...'])); o.dir = R.dir4(pl.x - o.x, pl.y - o.y); if (R.cases && R.cases.open().length) { const c = R.cases.open()[0]; c.progress = Math.min(99, c.progress + 4); } }, 1500);
      }
    }, 1600);
    return true;
  };

  // ---------------------------------------------------------------- the stakeout
  MEM.home = function () {
    const g = G(), pl = g.player;
    const id = (pl.properties && pl.properties[0]) != null ? pl.properties[0] : pl.hotel ? pl.hotel.hid : null;
    return id != null ? g.world.buildings[id] : null;
  };
  MEM.updateStakeout = function () {
    const g = G(), pl = g.player, CS = R.cases;
    const hot = CS && CS.open().find((c) => c.progress >= 50);
    const b = this.home();
    if (this.car && (this.car.removed || this.car.wrecked)) this.car = null;
    if (!hot || !b) { if (this.car && Math.hypot(this.car.x - pl.x, this.car.y - pl.y) > TS * 30) { g.traffic.remove(this.car); this.car = null; } return; }
    const d = Math.hypot(b.out.x * TS - pl.x, b.out.y * TS - pl.y);
    if (!this.car && d < TS * 26 && d > TS * 10) {
      const w = g.world;
      const s = w.findNear(b.out.x, b.out.y, 3, 7, (x, y) => D.roadTile[w.t(x, y)] && !g.traffic.nearestCar(x * TS + 8, y * TS + 8, TS * 1.5));
      if (!s) return;
      const v = g.traffic.make('sedan', s.x * TS + 8, s.y * TS + 8, 0, { parked: true, locked: true, keep: true, color: '#6a4a2a' });
      v.stakeout = true; v.lights = false; v.speed = 0;
      this.car = v;
      g.ui.toast(`A brown sedan is parked across from ${b.name}. Two men inside, not eating their sandwiches. ${hot.det} is watching your place.`, 'warn');
    }
  };

  // ---------------------------------------------------------------- per-frame
  MEM.update = function (dt) {
    const g = G(), pl = g.player;
    if (!g.started || (R.opening && R.opening.active)) return;
    this.t -= dt;
    if (this.t > 0) return;
    this.t = 2;
    const hr = g.clock.hour(), day = g.pop.day;
    // morning: a newsboy on the corner, shouting the headline
    const inCity = g.world.cityAt((pl.x / TS) | 0, (pl.y / TS) | 0);
    if (this.boy && (this.boy.removed || this.boy.dead || hr >= 12 || Math.hypot(this.boy.x - pl.x, this.boy.y - pl.y) > TS * 30)) { if (!this.boy.removed && !this.boy.dead) g.actors.remove(this.boy); this.boy = null; }
    if (!this.boy && inCity && !pl.room && !pl.inCar && hr >= 6 && hr < 12 && this.boyDay !== day) { this.boyDay = day; this.spawnNewsboy(); }
    if (this.boy && !this.boy.dead) {
      this.boyShout -= 2;
      if (this.boyShout <= 0 && Math.hypot(this.boy.x - pl.x, this.boy.y - pl.y) < TS * 16) { this.boyShout = 9; g.actors.say(this.boy, `EXTRA! EXTRA! ${this.headline(day)}!`); }
    }
    this.updateStakeout();
    // a shootout: lots of shots in a short time
    if (this.shots && g.clock.t - this.shots.t > 3) { if (this.shots.n >= 6) this.log('shootout', { x: this.shots.x, y: this.shots.y, n: this.shots.n, seen: this.shots.seen, hour: hr }); this.shots = null; }
  };

  // ---------------------------------------------------------------- wiring
  MEM.init = function (game) {
    this.boy = null; this.car = null; this.t = 3; this.shots = null;
    this.state();
    if (this.wired) return;
    this.wired = true;
    const L = R.Law.prototype, bCrime = L.crime;
    L.crime = function (type, x, y, opts) {
      const r = bCrime.apply(this, arguments);
      const g = G();
      try {
        if (HEAD[type] && type !== 'murder' && type !== 'copMurder' && type !== 'manslaughter') MEM.log(type, { x, y, seen: !g.player.masked && !!(this.incident || g.actors.near(x, y, TS * 10, (a) => a.witness && !a.dead).length), hour: g.clock.hour(), victim: opts && opts.victim && opts.victim.person ? g.pop.short(opts.victim.person) : null, what: opts && opts.car ? opts.car.model.name : null });
        if (type === 'murder' || type === 'copMurder' || type === 'manslaughter') {
          const v = opts && opts.victim;
          MEM.log(type, { x, y, seen: !g.player.masked && !!(this.incident || g.actors.near(x, y, TS * 10, (a) => a.witness && !a.dead).length), hour: g.clock.hour(), victim: v && v.person ? g.pop.name(v.person) : v && v.strangerName ? v.strangerName : null });
        }
      } catch (e) { /* the paper can go to press without it */ }
      return r;
    };
    // gunfire adds up to a shootout
    const bNoise = R.Actors.prototype.noise;
    R.Actors.prototype.noise = function (x, y, r, kind, src) {
      const g = G();
      if (kind === 'gunshot' && src === g.player) {
        if (!MEM.shots) MEM.shots = { t: g.clock.t, x, y, n: 0, seen: !g.player.masked };
        MEM.shots.n++; MEM.shots.t = g.clock.t;
      }
      return bNoise.apply(this, arguments);
    };
    // rescues: you put down someone who was hurting somebody else
    const bKill = R.combat.kill;
    R.combat.kill = function (h, source) {
      const g = G(), was = h && h.dead;
      const saving = h && h.kind === 'h' && h.hostile && h.target && h.target !== g.player && h.target.kind === 'h' && !h.target.dead;
      const victim = saving ? h.target : null;
      bKill.apply(this, arguments);
      if (!was && h && h.dead && saving && (source === g.player || (source && source.driver === g.player))) MEM.log('rescue', { x: h.x, y: h.y, seen: true, victim: victim.person ? g.pop.short(victim.person) : null, hour: g.clock.hour() });
    };
    if (R.corps) {
      const bRev = R.corps.revive;
      R.corps.revive = function (a) { bRev.apply(this, arguments); MEM.log('revive', { x: a.x, y: a.y, seen: true, victim: a.person ? G().pop.short(a.person) : null }); };
      const bPow = R.corps.power;
      R.corps.power = function () { const g = G(); if (g.world.cityAt((g.player.x / TS) | 0, (g.player.y / TS) | 0) && !MEM.recent(0, (e) => e.k === 'ring').length) MEM.log('ring', { x: g.player.x, y: g.player.y, seen: true, color: R.corps.col() }); return bPow.apply(this, arguments); };
    }
    // two neighbours chatting now talk about what happened
    const bChat = R.Actors.prototype.ambientChat;
    R.Actors.prototype.ambientChat = function (h) {
      const others = this.near(h.x, h.y, 40, (o) => o !== h && o.kind === 'h' && !o.dead && !o.cop && (o.state === 'idle' || o.state === 'hang'));
      if (others.length && R.rng() < 0.4 && MEM.gossip(h, others[0])) return;
      return bChat.apply(this, arguments);
    };
    // newsboy talk
    const bTree = R.dialog.tree;
    R.dialog.tree = function (h) { if (h && h.newsboy) return MEM.boyTree(h); return bTree.apply(this, arguments); };
    // the paper by your bed when you wake
    const IP = R.Interiors.prototype, bSleep = IP.sleep;
    if (bSleep) IP.sleep = function () { const d0 = G().pop.day; const r = bSleep.apply(this, arguments); setTimeout(() => { const g = G(); if (g.pop.day !== d0 && !g.ui.sheetOpen) { g.ui.toast('The morning paper is by the door.', 'good'); MEM.read(); } }, 1200); return r; };
    // the News tab leads with today's Herald
    const U = R.UI.prototype, bTab = U.openMenuTab;
    U.openMenuTab = function (tab, s) {
      const r = bTab.apply(this, arguments);
      if (tab === 'news') { const body = document.getElementById('mbody'); const n = body && body.querySelector('.news'); if (n) n.insertAdjacentHTML('beforebegin', MEM.paperHtml(MEM.paper(G().pop.day)) + '<div class="sect">Older wire stories</div>'); }
      return r;
    };
    // fewer toasts: the same line within a few seconds is dropped
    const bToast = U.toast;
    U.toast = function (msg, kind) {
      const now = performance.now();
      this.toastSeen = this.toastSeen || new Map();
      const last = this.toastSeen.get(msg);
      if (last && now - last < 5000) return;
      this.toastSeen.set(msg, now);
      if (this.toastSeen.size > 60) this.toastSeen.clear();
      return bToast.apply(this, arguments);
    };
    const st = document.createElement('style');
    st.textContent = '.herald h2.hl{font-family:var(--pix);font-weight:400;font-size:17px;line-height:1.15;margin:6px 0 4px;color:var(--ink);text-align:center}.herald .lede{font-size:15px;border-bottom:2px solid var(--ink);padding-bottom:8px}.herald .cols{display:grid;grid-template-columns:1fr 1fr;gap:8px;border-top:2px solid var(--ink);margin-top:6px}.herald .ads{font-size:12px;border-top:2px dashed var(--ink);padding-top:6px}';
    document.head.appendChild(st);
  };
})();
