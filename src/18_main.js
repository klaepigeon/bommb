// RHAPSODY — the game object: boot, loop, daily ticks, save/load, intro.
'use strict';
(function () {
  const D = R.data, TS = R.TILE;
  const SAVE = 'rhapsody.save.v2';
  const SETTINGS = 'rhapsody.settings.v1';

  const Game = (R.Game = function () {
    R.game = this;
    this.settings = Object.assign({ vol: 0.7, music: 0.5, lifeSpeed: 1, traffic: 1, density: 1, events: 1, zoom: 1, grain: true, gore: true }, R.store.get(SETTINGS) || {});
    this.timeScale = 1;
    this.started = false;
    this.cheats = {};
    this.hints = {};
    this.worldLog = [];
  });
  const G = Game.prototype;

  G.saveSettings = function () { R.store.set(SETTINGS, this.settings); };

  G.boot = function () {
    const root = document.getElementById('app');
    this.canvas = document.getElementById('view');
    this.audio = new R.Audio(this);
    this.audio.vol = this.settings.vol;
    this.audio.musicVol = this.settings.music;
    this.cam = new R.Camera(this);
    this.fx = new R.FX(this);
    this.ui = new R.UI(this);
    this.input = new R.Input(this, root);
    this.renderer = new R.Renderer(this, this.canvas);
    const title = document.getElementById('title');
    title.style.display = 'flex';
    this.resize();
    const save = R.store.get(SAVE);
    this.loop();
    // wait (briefly) for the pixel fonts, then build the world
    const fonts = document.fonts ? Promise.all([document.fonts.load('8px "Silkscreen"'), document.fonts.load('11px "Pixelify Sans"')]).catch(() => {}) : Promise.resolve();
    Promise.race([fonts, new Promise((r) => setTimeout(r, 2500))]).then(() => setTimeout(() => {
      this.setup(save ? save.seed : (Math.random() * 1e9) | 0, save);
      document.getElementById('loading').hidden = true;
      title.querySelector('.menu').hidden = false;
      const cont = document.getElementById('btnContinue');
      if (save) {
        cont.hidden = false;
        cont.addEventListener('click', () => this.start(false));
      }
      document.getElementById('btnNew').addEventListener('click', (e) => {
        if (save && !e.target.dataset.confirm) { e.target.dataset.confirm = 1; e.target.textContent = 'Erase save? Tap again'; return; }
        this.newGame();
      });
      document.getElementById('btnHelp').addEventListener('click', () => {
        this.ui.openSheet('help', this.ui.header('How to Play', 'The short version') + `<div class="body">${this.ui.helpHtml()}</div>`, true);
      });
    }, 30));
    window.addEventListener('resize', () => this.resize());
    document.addEventListener('visibilitychange', () => { if (document.hidden && this.started) this.save(); });
  };

  G.setup = function (seed, save) {
    this.seed = seed;
    const t0 = performance.now();
    this.world = new R.World(seed);
    this.wrapWorldLog();
    R.path.init(this.world);
    this.pop = new R.Population(this.world, seed);
    this.clock = new R.Clock(this, 18 * 60 + 10);
    this.env = new R.Env(this);
    this.env.setWeather('clear');
    this.actors = new R.Actors(this);
    this.traffic = new R.Traffic(this);
    this.law = new R.Law(this);
    this.jobs = new R.Jobs(this);
    this.player = new R.Player(this);
    this.life = new R.Life(this);
    this.interiors = new R.Interiors(this);
    R.props.init(this);
    R.ring.init(this);
    R.fearQuest.init(this);
    R.campaign.init(this);
    R.stories.spots = {};
    R.salvage.init(this);
    R.cases.init(this);
    R.money.init(this);
    R.turf.init(this);
    R.vendetta.init(this);
    R.shark.init(this); R.payroll.init(this); R.rat.init(this); R.hijack.init(this); R.desert.init(this); R.cars.init(this); R.honor.init(this); R.dust.init(this);
    R.butcher.init(this);
    R.arms.init(this);
    R.profile.init(this);
    R.carry.init(this);
    R.charm.init(this); R.charm.reinit();
    R.night.init(this);
    R.opening.init(this);
    R.vice.init(this);
    R.gore.init(this);
    R.relics.init(this);
    R.legends.init(this);
    R.poi.init(this);
    R.art.chunkCache.clear();
    const port = this.world.cities[0];
    const club = port.buildings.find((b) => b.type === 'social');
    this.player.place(club.out.x * TS + 8, club.out.y * TS + 12);
    this.homeClub = club.id;
    if (save) this.load(save);
    this.miniMap = R.art.buildMiniMap(this.world);
    this.miniDirty = false;
    this.cam.x = this.player.x;
    this.cam.y = this.player.y;
    this.resize();
    for (const p of this.pop.people) p.place = this.life.desiredKey(p);
    R.bus.on('building:new', () => (this.miniDirty = true));
    R.bus.on('building:destroyed', () => (this.miniDirty = true));
    R.bus.on('actor:died', (h, byPlayer) => this.onDeath(h, byPlayer));
    R.bus.on('player:ko', (h) => this.onDeath(h, true, true));
    this.genMs = performance.now() - t0;
  };

  // record world mutations so a save can replay them onto the seeded world
  G.wrapWorldLog = function () {
    const w = this.world, log = this.worldLog;
    const build = w.buildOnLot.bind(w), destroy = w.destroyBuilding.bind(w), site = w.setSite.bind(w);
    w.buildOnLot = (lot, type, rnd) => {
      const s = R.rng.int(0, 1e9);
      log.push(['b', w.lots.indexOf(lot), type, s]);
      return build(lot, type, R.mulberry(s));
    };
    w.destroyBuilding = (b) => { if (!b.destroyed) log.push(['d', b.id]); return destroy(b); };
    w.setSite = (lot, on) => { log.push(['s', w.lots.indexOf(lot), on ? 1 : 0]); return site(lot, on); };
  };
  G.replayWorld = function (log) {
    const w = this.world;
    for (const e of log) {
      if (e[0] === 'b') { const lot = w.lots[e[1]]; if (lot) w.buildOnLot(lot, e[2]); }
      else if (e[0] === 'd') { const b = w.buildings[e[1]]; if (b) w.destroyBuilding(b); }
      else if (e[0] === 's') { const lot = w.lots[e[1]]; if (lot) { w.setSite(lot, !!e[2]); lot.site = !!e[2]; } }
    }
  };

  G.resize = function () {
    if (!this.renderer) return;
    const app = document.getElementById('app');
    const portrait = window.innerHeight > window.innerWidth * 1.05;
    app.classList.toggle('portrait', portrait);
    app.classList.toggle('landscape', !portrait);
    app.classList.toggle('touch', 'ontouchstart' in window || navigator.maxTouchPoints > 0);
    this.renderer.resize();
    requestAnimationFrame(() => this.renderer.resize());
  };

  G.start = function (fresh) {
    document.getElementById('title').style.display = 'none';
    this.audio.unlock();
    this.audio.setVolume(this.settings.vol);
    this.audio.setMusicVolume(this.settings.music);
    this.started = true;
    this.ui.setRingButtons();
    if (fresh) this.intro();
    else this.ui.toast(`Welcome back, ${this.player.nick}. ${this.clock.weekday()}, ${this.clock.label()}.`, 'good');
  };

  G.newGame = function () {
    R.store.del(SAVE);
    location.hash = 'new';
    if (this.started || this.world) {
      // rebuild from a fresh seed
      this.worldLog.length = 0;
      R.art.chunkCache.clear();
      R.bus.map.clear();
      this.setup((Math.random() * 1e9) | 0, null);
      this.ui.closeSheet();
    }
    this.start(true);
  };

  // 0.2 on your first day, 1 once you've been around a while or made a name.
  // Scales how often street trouble finds you.
  G.calm = function () {
    const st = this.player.stats;
    const days = st.startT == null ? 6 : (this.clock.t - st.startT) / 1440;
    return R.clamp(0.2 + days * 0.16 + this.player.rep.infamy / 120 + st.jobs * 0.03, 0.2, 1);
  };

  G.intro = function () {
    if (R.opening && !/quick/.test(location.search)) return R.opening.run(this);
    const pl = this.player;
    pl.stats.startT = this.clock.t;
    const club = this.world.buildings[this.homeClub];
    this.interiors.enter(club, 'guest');
    this.ui.story('Port Hollow, 2026', `The calendar says 2026. The Brass Coast never got the memo: wide collars, eight-tracks, disco on every radio.\n\nYou're Nicky "The Mook" Marchetti, fresh off the bus with a pinstripe suit and a cousin's recommendation. Don Gus Vane runs Port Hollow out of ${club.name}, and you're standing in his back room.\n\nHe's got work for you. Everyone else is just living their lives.`, () => {
      const offers = this.jobs.offersFor(pl.family);
      const first = offers.find((o) => o.kind === 'collect') || offers[0];
      if (first) {
        this.jobs.accept(first);
        this.jobs.offers[pl.family] = offers.filter((o) => o !== first);
      }
      this.ui.toast('Talk to Don Vane for more work. Your first job is marked in gold. Walk out the doormat to leave.', 'good');
      setTimeout(() => this.ui.toast('Crimes only count if someone sees them. Watch for gold "!" witnesses.'), 7000);
      this.save();
    });
  };

  // ---------------------------------------------------------------- loop
  G.loop = function () {
    let last = performance.now();
    const frame = (now) => {
      requestAnimationFrame(frame);
      let dt = Math.min(0.05, (now - last) / 1000);
      this.fps = this.fps ? this.fps * 0.95 + (1 / Math.max(0.001, (now - last) / 1000)) * 0.05 : 60;
      last = now;
      try {
        if (!this.started) { this.renderer.renderTitle(now / 1000); return; }
        this.tick(dt);
        this.renderer.render();
      } catch (e) {
        console.error(e);
        if (!this.errShown) { this.errShown = true; this.ui.toast('Something glitched: ' + e.message, 'bad'); }
      }
    };
    requestAnimationFrame(frame);
  };

  G.tick = function (dt) {
    const pl = this.player;
    this.input.update();
    const paused = !this.started || this.ui.paused() || pl.dead;
    if (this.hitStop > 0) { this.hitStop -= dt; dt *= 0.08; }
    if (!paused) {
      const sdt = dt * this.timeScale;
      this.clock.update(sdt);
      // windows light up at dusk: repaint the cached city
      const nightNow = this.clock.isNight();
      if (nightNow !== this.wasNight) { this.wasNight = nightNow; R.art.chunkCache.clear(); }
      this.env.update(sdt);
      pl.update(dt * (this.timeScale < 1 ? 0.8 : 1));
      this.actors.update(sdt);
      this.traffic.update(sdt);
      R.combat.update(sdt);
      this.law.update(sdt);
      this.jobs.update(sdt);
      this.life.update(sdt);
      this.interiors.update(sdt);
      R.props.update(sdt);
      R.ring.update(sdt);
      R.fearQuest.update(sdt);
      R.campaign.update(sdt);
      R.stories.update(sdt); R.stories.tick(sdt);
      R.salvage.update(sdt);
      R.cases.update(sdt);
      R.turf.update(sdt);
      R.vendetta.update(sdt);
      R.hijack.update(sdt);
      R.desert.update(sdt);
      R.dust.update(sdt);
      R.payroll.update(sdt);
      R.profile.update(sdt);
      R.carry.update(sdt);
      R.night.update(sdt);
      R.opening.update(sdt);
      R.route.update(this, sdt);
      R.vice.update(sdt);
      R.water.update(sdt);
      R.bodies.update(sdt);
      R.gore.update(sdt);
      R.slammer.update(sdt);
      R.heist.update(sdt);
      R.relics.update(sdt);
      if (R.testRooms.active) R.testRooms.update(this, sdt);
      R.legends.update(sdt);
      R.goods.update(sdt);
      R.poi.update(sdt);
      this.fx.update(sdt);
      this.hintCheck();
      this.occT = (this.occT || 0) - dt;
      if (this.occT <= 0) { this.occT = 3; this.updateOccupancy(); }
      this.autosaveT = (this.autosaveT || 120) - dt;
      if (this.autosaveT <= 0) { this.autosaveT = 120; this.save(); }
      if (this.miniDirty) { this.miniDirty = false; this.miniMap = R.art.buildMiniMap(this.world); }
    } else if (this.started) this.fx.update(0);
    const tgt = pl.inCar || pl;
    // the camera looks a little ahead of where you're going
    const st = this.input.stick;
    const lead = pl.inCar ? { x: pl.inCar.vx * 0.35, y: pl.inCar.vy * 0.35 } : pl.room ? null : { x: st.x * 22, y: st.y * 14 };
    this.cam.update(dt, tgt.x, tgt.y - 6, lead);
    if (pl.room) {
      // keep the camera inside the room, centred when the room is smaller than the screen
      const r = pl.room, hw = this.cam.vw / 2 / this.cam.zoom, hh = this.cam.vh / 2 / this.cam.zoom;
      const x0 = r.x0 * TS, x1 = (r.x0 + r.w) * TS, y0 = r.y0 * TS, y1 = (r.y0 + r.h) * TS;
      this.cam.x = x1 - x0 < hw * 2 ? (x0 + x1) / 2 : R.clamp(this.cam.x, x0 + hw, x1 - hw);
      this.cam.y = y1 - y0 < hh * 2 ? (y0 + y1) / 2 : R.clamp(this.cam.y, y0 + hh, y1 - hh);
    }
    if (pl.bubble) { pl.bubble.t -= dt; if (pl.bubble.t <= 0) pl.bubble = null; }
    this.ui.update(dt);
    this.input.endFrame();
  };

  G.updateOccupancy = function () {
    const pl = this.player, w = this.world;
    const tx = pl.x / TS, ty = pl.y / TS;
    for (const b of w.buildings) {
      if (!b) continue;
      if (Math.abs(b.x - tx) > 40 || Math.abs(b.y - ty) > 40) continue;
      b.occ = this.life.occupants(b).length;
    }
  };

  G.hintCheck = function () {
    const pl = this.player;
    const hint = (k, msg) => { if (!this.hints[k] && this.clock.real - (this.lastHint || -99) > 12) { this.hints[k] = 1; this.lastHint = this.clock.real; this.ui.toast(msg); } };
    if (pl.focus && !pl.inCar) hint('greet', 'GREET builds trust. ANTAGONIZE picks fights (fistfights you didn\'t start aren\'t crimes). TALK opens real conversations.');
    if (pl.inCar) hint('car', 'Point the stick where you want to drive. BRAKE at speed drifts. RADIO flips stations.');
    if (this.law.active()) hint('law', 'Break line of sight and get out of the search circle. Hiding indoors speeds up the search clock.');
    if (this.clock.isNight()) hint('night', 'At night fewer people see crimes, but lamps light you up. You can shoot lamps out.');
  };

  G.onNewDay = function () {
    if (!this.pop) return;
    const r = this.pop.dailyTick(this);
    this.jobs.daily();
    const built = this.pop.projects.length;
    if (this.started) this.ui.toast(`New day. ${r.births.length} born, ${r.deaths.length} passed on, ${built} building project${built === 1 ? '' : 's'} under way. Check the paper (menu).`);
    this.life.cache.clear();
  };

  G.onDeath = function (h, byPlayer, ko) {
    if (!byPlayer) return;
    const pl = this.player;
    if (h.onDeathReward) {
      const r = h.onDeathReward;
      h.onDeathReward = null;
      pl.addCash(r.amt);
      pl.rep.honor += 3;
      const c = this.world.cityAt((h.x / TS) | 0, (h.y / TS) | 0);
      if (c) pl.standing[c.id] = Math.min(100, (pl.standing[c.id] || 0) + 6);
      this.ui.toast(`You stopped the thief. ${r.b ? r.b.name + ' pays' : 'Reward:'} ${R.fmtMoney(r.amt)}.`, 'good');
      if (r.b) for (const id of r.b.workers) { const p = this.pop.people[id]; if (p) p.opinion = Math.min(100, p.opinion + 25); }
    }
    if (h.stolen && !ko) this.ui.toast('Get your money back: search the pickpocket (USE).');
    if (h.kind === 'a' && h.target && h.target.onSavedReward && !h.target.dead) {
      const v = h.target;
      v.onSavedReward = false;
      const amt = R.rng.int(15, 40);
      pl.addCash(amt);
      pl.rep.honor += 3;
      this.actors.say(v, `You saved my life, mister! Here, it's all I got: ${R.fmtMoney(amt)}.`);
    }
    if (h.kind === 'a') pl.cool = Math.min(100, pl.cool + 4);
    else pl.cool = Math.min(100, pl.cool + 8);
  };

  // ---------------------------------------------------------------- persistence
  G.save = function () {
    if (!this.started || this.player.dead) return;
    const pl = this.player;
    const data = {
      v: 2, seed: this.seed, t: this.clock.t, log: this.worldLog, weather: this.env.weather.kind,
      player: {
        x: pl.room ? this.interiors.outside(pl.x, pl.y).x : pl.x, y: pl.room ? this.interiors.outside(pl.x, pl.y).y : pl.y, hp: pl.hp, cool: pl.cool, cash: pl.cash, inv: pl.inv, clip: pl.clip, outfit: pl.outfit, outfits: pl.outfits || {}, style: pl.style, wardrobe: pl.wardrobe,
        will: pl.will, willMax: pl.willMax || 100, docHp: pl.docHp || 0, explore: pl.explore || null, cases: pl.cases || null, money: pl.money || null, turf: pl.turf || null, vend: pl.vend || null, street: pl.street || null, killer: pl.killer || null, who: { first: pl.first, last: pl.last, nick: pl.nick, family: pl.family, club: this.homeClub, crawl: !!pl.crawling, road: R.opening && R.opening.road }, maxHp: pl.maxHp, fearQ: pl.fearQ || null, relics: pl.relics || null, jail: pl.jail || null, vice: pl.vice || null, affairs: this.pop.people.filter((q) => q.affair != null).map((q) => [q.id, q.affair]), partners: this.pop.people.filter((q) => q.playerPartner || q.playerChild).map((q) => [q.id, q.playerPartner ? 1 : 0, q.playerChild ? 1 : 0]), hotel: pl.hotel || null, stash: pl.stash || null, propUp: (pl.properties || []).map((id) => { const b = this.world.buildings[id]; return b ? [id, b.sec ? 1 : 0, b.reno ? 1 : 0] : null; }).filter(Boolean), campaign: pl.campaign || null, ringColor: pl.ringColor || null, errands: pl.errands || [], poi: R.poi.serialize(), rep: pl.rep, standing: pl.standing, stats: pl.stats, sweetheart: pl.sweetheart, properties: pl.properties, masked: pl.masked,
        cars: pl.ownedCars.filter((c) => !c.removed && !c.wrecked).map((c) => [c.modelId, c.x, c.y, c.angle, c.color]),
      },
      pop: this.pop.serialize(), law: this.law.serialize(), jobs: this.jobs.serialize(), hints: this.hints,
      rackets: this.world.buildings.filter((b) => b && b.racket).map((b) => [b.id, b.racketFamily, b.racketDue || 0, b.playerOwned ? 1 : 0]),
      owned: this.world.buildings.filter((b) => b && b.playerOwned).map((b) => b.id),
      cities: this.world.cities.map((c) => [c.prosperity, c.fear, c.heat]),
    };
    if (!R.store.set(SAVE, data)) this.ui.toast('Could not save (storage unavailable).', 'warn');
  };
  G.load = function (s) {
    try {
      this.replayWorld(s.log || []);
      this.worldLog.length = 0;
      for (const e of s.log || []) this.worldLog.push(e);
      this.clock.t = s.t;
      this.clock.lastDay = Math.floor((s.t - 300) / 1440);
      this.env.setWeather(s.weather || 'clear');
      this.pop.restore(s.pop, this);
      this.law.restore(s.law || {});
      this.jobs.restore(s.jobs || {});
      this.hints = s.hints || {};
      const pl = this.player, p = s.player;
      Object.assign(pl, { hp: p.hp, cool: p.cool, cash: p.cash, inv: p.inv, clip: p.clip, outfit: p.outfit, outfits: p.outfits, rep: p.rep, standing: p.standing, stats: Object.assign(pl.stats, p.stats), sweetheart: p.sweetheart, properties: p.properties || [], masked: !!p.masked });
      if (p.will != null) pl.will = p.will;
      if (p.willMax) pl.willMax = p.willMax;
      if (p.docHp) pl.docHp = p.docHp;
      pl.explore = p.explore || null;
      pl.cases = p.cases || null;
      pl.money = p.money || null;
      pl.turf = p.turf || null;
      pl.vend = p.vend || null;
      pl.street = p.street || null;
      pl.killer = p.killer || null;
      if (p.who) { pl.first = p.who.first; pl.last = p.who.last; pl.nick = p.who.nick || pl.nick; if (p.who.family) pl.family = p.who.family; if (p.who.club != null) this.homeClub = p.who.club; if (p.who.crawl && p.who.road) { pl.crawling = true; R.opening.road = p.who.road; R.opening.pickedUp = false; this.waypoint = { x: p.who.road.x * 16 + 8, y: p.who.road.y * 16 + 8 }; } }
      if (p.maxHp) pl.maxHp = p.maxHp;
      if (p.fearQ) pl.fearQ = p.fearQ;
      pl.relics = p.relics || null;
      pl.jail = p.jail || null; if (pl.jail) setTimeout(() => R.slammer.resume(), 0);
      pl.vice = p.vice || null;
      for (const [a, b] of p.affairs || []) if (this.pop.people[a]) this.pop.people[a].affair = b;
      for (const [id, pp, pc] of p.partners || []) { const q = this.pop.people[id]; if (q) { q.playerPartner = !!pp; q.playerChild = !!pc; } }
      pl.hotel = p.hotel || null; pl.stash = p.stash || null;
      for (const [id, sec, reno] of p.propUp || []) { const b = this.world.buildings[id]; if (b) { b.sec = sec; b.reno = reno; } }
      if (p.campaign) { pl.campaign = p.campaign; R.campaign.run = null; R.campaign.afterLoad(); }
      if (p.ringColor) { pl.ringColor = p.ringColor; R.data.weapons.ring.name = 'Green Ring'; }
      if (p.style) pl.style = Object.assign(R.styleDefault(), p.style);
      pl.wardrobe = p.wardrobe || {};
      pl.errands = p.errands || [];
      R.poi.restore(p.poi);
      pl.place(p.x, p.y);
      pl.buildLook();
      for (const [id, fam, due, owned] of s.rackets || []) { const b = this.world.buildings[id]; if (b) { b.racket = 1; b.racketFamily = fam; b.racketDue = due; if (owned) b.playerOwned = true; } }
      for (const id of s.owned || []) { const b = this.world.buildings[id]; if (b) b.playerOwned = true; }
      (s.cities || []).forEach((c, i) => { const cc = this.world.cities[i]; if (cc) [cc.prosperity, cc.fear, cc.heat] = c; });
      for (const [m, x, y, a, col] of p.cars || []) {
        const v = this.traffic.make(m, x, y, a, { parked: true, keep: true, locked: false, color: col });
        v.owner = 'player';
        pl.ownedCars.push(v);
      }
      // don't spawn inside a wall
      if (this.world.solidPed((pl.x / TS) | 0, (pl.y / TS) | 0) || pl.y >= this.world.H * TS) {
        const club = this.world.buildings[this.homeClub];
        pl.place(club.out.x * TS + 8, club.out.y * TS + 12);
      }
    } catch (e) {
      console.error('load failed', e);
      this.ui.toast('Your save was damaged; starting fresh.', 'bad');
    }
  };

  window.addEventListener('load', () => new Game().boot());
})();
