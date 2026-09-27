// RHAPSODY — the law, modeled on RDR2: a crime only matters if someone sees it.
// Witnesses must physically report it (and can be stopped). Police respond to a
// last-known location, search a zone you can slip out of, and prefer arrests at
// low levels. Bounties are per jurisdiction and can be paid off. Accidents are free.
'use strict';
(function () {
  const D = R.data, TS = R.TILE;

  const CRIMES = {
    reckless: { name: 'Reckless Driving', bounty: 5, lvl: 1, minor: true },
    vandalism: { name: 'Vandalism', bounty: 5, lvl: 1, minor: true },
    brandish: { name: 'Brandishing a Weapon', bounty: 0, lvl: 1, minor: true },
    trespass: { name: 'Trespassing', bounty: 5, lvl: 1, minor: true },
    assault: { name: 'Assault', bounty: 15, lvl: 1 },
    theft: { name: 'Theft', bounty: 10, lvl: 1 },
    pickpocket: { name: 'Pickpocketing', bounty: 10, lvl: 1, minor: true },
    mugging: { name: 'Armed Robbery', bounty: 25, lvl: 1 },
    carjack: { name: 'Carjacking', bounty: 25, lvl: 1 },
    cartheft: { name: 'Auto Theft', bounty: 15, lvl: 1 },
    burglary: { name: 'Burglary', bounty: 35, lvl: 1 },
    robbery: { name: 'Store Robbery', bounty: 50, lvl: 2 },
    arson: { name: 'Arson', bounty: 45, lvl: 2 },
    explosion: { name: 'Explosives', bounty: 40, lvl: 2 },
    manslaughter: { name: 'Vehicular Manslaughter', bounty: 45, lvl: 1 },
    murder: { name: 'Murder', bounty: 100, lvl: 2 },
    copAssault: { name: 'Assaulting an Officer', bounty: 40, lvl: 2 },
    copMurder: { name: 'Killing an Officer', bounty: 250, lvl: 3 },
    heist: { name: 'Bank Robbery', bounty: 300, lvl: 3 },
    jailbreak: { name: 'Resisting Arrest', bounty: 20, lvl: 2 },
  };

  const Law = (R.Law = function (game) {
    this.game = game;
    this.bounty = {}; // jurisdiction -> $
    this.incident = null;
    this.warn = new WeakMap();
    this.log = [];
    this.recognizeT = 0;
    this.shotT = 0;
    this.hunterT = 60;
  });
  const L = Law.prototype;
  L.CRIMES = CRIMES;

  L.jurAt = function (x, y) {
    const c = this.game.world.cityAt((x / TS) | 0, (y / TS) | 0);
    return c ? c.id : 'county';
  };
  L.jurName = function (j) {
    const c = this.game.world.cities.find((c) => c.id === j);
    return c ? c.name : 'the County';
  };
  L.active = function () {
    return !!this.incident;
  };
  L.level = function () {
    return this.incident ? this.incident.level : 0;
  };
  L.totalBounty = function () {
    let s = 0;
    for (const k in this.bounty) s += this.bounty[k];
    return s;
  };

  // ------------------------------------------------ the crime happens
  L.crime = function (type, x, y, opts) {
    opts = opts || {};
    const g = this.game, pl = g.player;
    const def = CRIMES[type];
    if (!def) return;
    if (g.cheats && g.cheats.noLaw) return;
    const jur = this.jurAt(x, y);
    const loc = g.interiors ? g.interiors.outside(x, y) : { x, y };
    const crime = { type, def, x: loc.x, y: loc.y, jur, identified: !pl.masked, t: g.clock.t, lvl: def.lvl, bounty: def.bounty, victim: opts.victim || null };
    pl.stats.crimes++;
    // city consequences
    const city = g.world.cities.find((c) => c.id === jur);
    if (city && !def.minor) { city.heat += def.bounty / 10; city.prosperity = Math.max(0, city.prosperity - def.bounty / 40); }
    // who saw it?
    const night = g.clock.isNight();
    const range = TS * (night ? 7 : 12) * (g.env.weather.fog > 0.4 ? 0.6 : 1) * (g.env.weather.rain > 0.5 ? 0.8 : 1);
    const seen = [];
    let copSaw = null;
    for (const a of g.actors.near(x, y, range)) {
      if (a.kind !== 'h' || a.dead || a.down > 0 || a === opts.victim && opts.victim.dead) continue;
      if (a.hostile && !a.cop) continue; // your opponents are busy
      const lit = !night || g.env.litAt(a.x, a.y) || R.dist(a.x, a.y, x, y) < TS * 3;
      if (!lit) continue;
      if (!g.world.los(a.x, a.y - 10, x, y - 10)) continue;
      if (a.cop) { copSaw = a; continue; }
      seen.push(a);
    }
    if (opts.victim && !opts.victim.dead && !seen.includes(opts.victim) && opts.victim.kind === 'h' && !opts.victim.cop) seen.push(opts.victim);
    if (copSaw) {
      if (def.minor && !this.incident) {
        // a warning first for small stuff
        if (!this.warned(copSaw)) {
          this.warn.set(copSaw, g.clock.t);
          g.actors.say(copSaw, R.dialog.line('copWarnMinor', copSaw));
          g.ui.toast(`An officer saw that. One warning: ${def.name}.`);
          return;
        }
      }
      g.actors.say(copSaw, R.dialog.line('copSaw', copSaw));
      this.startIncident(crime, copSaw);
      return;
    }
    if (def.minor && type !== 'pickpocket' && type !== 'reckless') {
      // minor crimes don't get reported by civilians
      for (const a of seen) if (R.rng() < 0.5) g.actors.say(a, R.dialog.line('tut', a));
      return;
    }
    let witnesses = 0;
    for (const a of seen) {
      if (a.witness && !a.witness.done) continue;
      const p = a.person;
      // friends and the terrified keep quiet
      if ((p && p.opinion >= 55) || (a.faction && a.faction !== 'law' && g.jobs.familyStanding(a.faction) >= 20)) {
        if (R.rng() < 0.6) g.actors.say(a, R.dialog.line('sawNothing', a));
        continue;
      }
      const cityFear = city ? city.fear / 100 : 0;
      if (a.tr.brave < 0.35 && R.rng() < 0.25 + cityFear * 0.5 + pl.rep.infamy / 400) {
        g.actors.say(a, R.dialog.line('sawNothing', a));
        continue;
      }
      a.witness = { crime, done: false, silenced: false };
      witnesses++;
      if (a.tr.brave > 0.8 && a.armed && a !== opts.victim) {
        g.actors.setFight(a, pl);
        g.actors.say(a, R.dialog.line('hero', a));
      } else if (a.tr.brave < 0.3 && R.dist(a.x, a.y, pl.x, pl.y) < TS * 4) {
        g.actors.setCower(a, 3 + R.rng() * 3);
        g.actors.say(a, R.dialog.line('cower', a));
      } else {
        g.actors.setFlee(a, pl, 2 + R.rng() * 3);
        g.actors.say(a, R.dialog.line('witness', a));
      }
      a.alert = 'witness';
    }
    if (witnesses) {
      g.ui.toast(`${witnesses} witness${witnesses > 1 ? 'es' : ''} to ${def.name}${pl.masked ? ' (masked: they can\'t name you)' : ''}. Stop them before they reach a phone or a cop.`, 'warn');
      this.log.unshift(crime);
    } else if (!this.incident) {
      g.ui.toast(`Nobody saw the ${def.name.toLowerCase()}.`, 'good');
    } else {
      // during an active incident further crimes escalate directly
      this.escalate(crime);
    }
  };

  L.warned = function (h) {
    const t = this.warn.get(h);
    return t !== undefined && this.game.clock.t - t < 600;
  };
  L.brandish = function (cop) {
    const g = this.game;
    this.warn.set(cop, g.clock.t);
    cop.brandishT = 5;
    cop.state = 'watch';
    cop.watchT = g.player;
    cop.timer = 6;
    cop.drawn = true;
    g.ui.toast('Cop: "Put the gun away." Holster it (SWAP) or it becomes a problem.', 'warn');
  };

  // a witness made the call
  L.report = function (crime, witness) {
    const g = this.game;
    if (witness && witness.person) g.pop.remember(witness.person, 'witness', `I saw a ${crime.def.name.toLowerCase()} with my own eyes. Called it in.`, g.pop.day);
    g.ui.toast(`A witness reported the ${crime.def.name.toLowerCase()}. Police are responding in ${this.jurName(crime.jur)}.`, 'bad');
    g.audio.sfx('alarm');
    if (this.incident) this.escalate(crime);
    else this.startIncident(crime, null);
  };

  L.addBounty = function (crime) {
    if (!crime.identified || !crime.bounty) return;
    this.bounty[crime.jur] = (this.bounty[crime.jur] || 0) + crime.bounty;
    this.game.player.rep.infamy += crime.bounty / 25;
  };

  L.startIncident = function (crime, cop) {
    const g = this.game;
    this.addBounty(crime);
    this.incident = {
      jur: crime.jur, level: crime.lvl, lastX: crime.x, lastY: crime.y, state: cop ? 'pursuit' : 'responding',
      seenT: cop ? g.clock.real : -99, searchLeft: 0, units: [], crimes: [crime], started: g.clock.real, dispatchT: 0,
      arrestT: 0, identified: crime.identified,
    };
    if (cop) {
      this.incident.units.push(cop);
      g.actors.setFight(cop, g.player);
    }
    this.dispatch();
    g.audio.music('tense');
  };
  L.escalate = function (crime) {
    const inc = this.incident;
    this.addBounty(crime);
    inc.crimes.push(crime);
    if (crime.lvl > inc.level) {
      inc.level = crime.lvl;
      this.game.ui.toast(`Police response escalated: ${['', 'Wanted', 'Dangerous', 'Shoot on sight'][inc.level]}.`, 'bad');
      this.dispatch();
    }
    if (crime.identified) inc.identified = true;
  };

  // Send units towards the last known position
  L.dispatch = function () {
    const g = this.game, inc = this.incident;
    const want = [0, 2, 3, 5][inc.level];
    const alive = inc.units.filter((u) => !u.dead && !u.removed).length;
    const w = g.world;
    const cars = Math.ceil((want - alive) / 2);
    for (let k = 0; k < cars; k++) {
      const s = w.findNear(inc.lastX / TS, inc.lastY / TS, 20, 32, (x, y) => w.flow[w.idx(x, y)] && !g.cam.onScreen(x * TS, y * TS, 30));
      if (!s) continue;
      const car = g.traffic.make('police', s.x * TS + 8, s.y * TS + 8, 0, { mode: 'chase', keep: true });
      car.siren = true;
      car.angle = Math.atan2(inc.lastY - car.y, inc.lastX - car.x);
      const d1 = g.traffic.addDriver(car, { cop: true, role: 'cop', city: inc.jur });
      d1.look = g.pop.makeLook(R.mulberry(R.rng.int(0, 1e9)), { fem: R.rng.chance(0.25), age: 35, role: 'cop', city: inc.jur });
      g.actors.arm(d1, inc.level >= 3 ? 'shotgun' : 'revolver');
      const d2 = g.actors.makeHuman(car.x, car.y, { cop: true, role: 'cop', city: inc.jur });
      d2.look = g.pop.makeLook(R.mulberry(R.rng.int(0, 1e9)), { fem: R.rng.chance(0.25), age: 30, role: 'cop', city: inc.jur });
      if (inc.level >= 2) g.actors.arm(d2, R.rng.pick(['shotgun', 'revolver', 'magnum']));
      d2.inCar = car;
      d2.state = 'drive';
      car.passengers = [d2];
      car.ai = { dest: { x: inc.lastX, y: inc.lastY }, stopNear: 40, onArrive: (c) => this.unload(c) };
      d1.keep = d2.keep = true;
      inc.units.push(d1, d2);
      g.actors.say(d1, R.dialog.line('radio', d1));
    }
  };
  L.unload = function (car) {
    const g = this.game, inc = this.incident;
    const crew = [car.driver].concat(car.passengers || []).filter((x) => x && x !== g.player && !x.dead);
    car.passengers = [];
    for (const c of crew) {
      g.traffic.exitVehicle(car, c);
      c.state = 'idle';
      if (inc && inc.state === 'pursuit') g.actors.setFight(c, g.player);
      else this.searchPoint(c);
    }
    car.siren = inc ? true : false;
    car.ai = {};
  };
  L.searchPoint = function (c) {
    const inc = this.incident;
    if (!inc) return;
    const r = this.searchRadius();
    const a = R.rng() * Math.PI * 2, d = R.rng() * r;
    c.state = 'travel';
    c.hurry = true;
    this.game.actors.goTo(c, ((inc.lastX + Math.cos(a) * d) / TS) | 0, ((inc.lastY + Math.sin(a) * d) / TS) | 0, { near: 20 });
  };
  L.searchRadius = function () {
    return TS * (10 + this.incident.level * 4);
  };

  // ------------------------------------------------ perception hooks from cops
  L.copSees = function (cop, d) {
    const g = this.game, pl = g.player, inc = this.incident;
    if (inc) {
      if (d < TS * 12) this.seen(cop);
      return;
    }
    // brandishing warning expires into a crime
    if (cop.brandishT > 0) {
      if (!pl.weaponOut || !D.weapons[pl.weapon] || !D.weapons[pl.weapon].gun) { cop.brandishT = 0; g.actors.say(cop, R.dialog.line('copOk', cop)); cop.drawn = false; return; }
      cop.brandishT -= 0.3;
      if (cop.brandishT <= 0) this.startIncident({ type: 'brandish', def: CRIMES.brandish, x: pl.x, y: pl.y, jur: this.jurAt(pl.x, pl.y), identified: !pl.masked, lvl: 1, bounty: 5 }, cop);
      return;
    }
    // recognise a wanted face
    const b = this.bounty[this.jurAt(pl.x, pl.y)] || 0;
    if (b <= 0 || pl.masked || d > TS * 7) return;
    const disguise = pl.outfitChangedSince > 0 ? 0.25 : 1;
    const chance = Math.min(0.25, b / 2000) * disguise * (g.clock.isNight() ? 0.5 : 1);
    if (R.rng() < chance) {
      g.actors.say(cop, R.dialog.line('recognise', cop));
      g.ui.toast(`An officer recognised you. Bounty in ${this.jurName(this.jurAt(pl.x, pl.y))}: ${R.fmtMoney(b)}.`, 'warn');
      this.startIncident({ type: 'warrant', def: { name: 'Outstanding Warrant', minor: false }, x: pl.x, y: pl.y, jur: this.jurAt(pl.x, pl.y), identified: true, lvl: 1, bounty: 0 }, cop);
    }
  };
  L.copHears = function (cop, x, y, kind) {
    if (cop.state === 'fight' || cop.inCar) return;
    cop.state = 'travel';
    cop.hurry = true;
    this.game.actors.goTo(cop, (x / TS) | 0, (y / TS) | 0, { near: 30 });
    if (R.rng() < 0.5) this.game.actors.say(cop, R.dialog.line('copInvestigate', cop));
  };
  L.shotsFired = function (x, y) {
    // firing in town near cops without an incident is brandishing at least
    const g = this.game;
    if (this.incident) return;
    // shooting back at someone who is shooting at you is not a crime
    for (const a of g.actors.near(g.player.x, g.player.y, TS * 16)) if (!a.dead && a.kind === 'h' && (a.attackedPlayer || a.hostile && a.state === 'fight' && a.target === g.player)) return;
    for (const a of g.actors.near(x, y, TS * 12)) {
      if (a.cop && !a.dead && g.world.los(a.x, a.y - 8, x, y - 8)) {
        g.actors.say(a, R.dialog.line('copSaw', a));
        this.startIncident({ type: 'shots', def: { name: 'Discharging a Firearm' }, x, y, jur: this.jurAt(x, y), identified: !g.player.masked, lvl: 1, bounty: 10 }, a);
        return;
      }
    }
  };
  L.seen = function (cop) {
    const g = this.game, pl = g.player, inc = this.incident;
    const at = g.interiors.outside(pl.x, pl.y);
    inc.lastX = at.x;
    inc.lastY = at.y;
    inc.seenT = g.clock.real;
    if (inc.state !== 'pursuit') {
      inc.state = 'pursuit';
      g.ui.toast('Spotted! Police in pursuit.', 'bad');
    }
    if (cop && cop.state !== 'fight' && !cop.inCar) g.actors.setFight(cop, pl);
    if (cop && !inc.units.includes(cop)) inc.units.push(cop);
  };

  // level 1: cops walk up and cuff you
  L.wantsArrest = function () {
    const inc = this.incident;
    return inc && inc.level === 1 && !inc.resisted;
  };
  L.copArrest = function (cop, dt) {
    const g = this.game, pl = g.player, inc = this.incident;
    const d = R.dist(cop.x, cop.y, pl.x, pl.y);
    const ang = Math.atan2(pl.y - cop.y, pl.x - cop.x);
    cop.dir = R.dir4(Math.cos(ang), Math.sin(ang));
    cop.drawn = true;
    if (pl.inCar) {
      // order you out
      if (d < TS * 6 && !cop.saidOut) { cop.saidOut = true; g.actors.say(cop, 'Step out of the vehicle!'); }
      if (d > TS * 3) g.actors.moveActor(cop, Math.cos(ang) * 60, Math.sin(ang) * 60, dt), (cop.walk += dt * 20);
      inc.fleeT = (inc.fleeT || 0) + (Math.abs(pl.inCar.speed) > 60 ? dt : 0);
      if (inc.fleeT > 2) this.resist('Fleeing in a vehicle');
      return;
    }
    if (d > 26) {
      g.actors.moveActor(cop, Math.cos(ang) * 62, Math.sin(ang) * 62, dt);
      cop.walk += dt * 20;
      if (d > TS * 9 && inc.arrestT > 0) { inc.fleeT = (inc.fleeT || 0) + dt; if (inc.fleeT > 4) this.resist('Fleeing arrest'); }
      return;
    }
    if (!inc.arrestT) {
      inc.arrestT = 7;
      g.actors.say(cop, R.dialog.line('arrest', cop));
      g.ui.arrestPrompt(cop);
    }
  };
  L.resist = function (why) {
    const inc = this.incident;
    if (!inc || inc.resisted) return;
    inc.resisted = true;
    inc.arrestT = 0;
    this.game.ui.closeArrest();
    this.escalate({ type: 'jailbreak', def: CRIMES.jailbreak, x: this.game.player.x, y: this.game.player.y, jur: inc.jur, identified: !this.game.player.masked, lvl: 2, bounty: CRIMES.jailbreak.bounty });
    this.game.ui.toast(`${why}. Officers will use force.`, 'bad');
  };
  L.surrender = function () {
    const g = this.game, pl = g.player, inc = this.incident;
    const jur = inc ? inc.jur : this.jurAt(pl.x, pl.y);
    const b = this.bounty[jur] || 0;
    const fine = Math.max(25, Math.round(b));
    this.clearIncident(true);
    if (pl.cash >= fine) {
      pl.cash -= fine;
      this.bounty[jur] = 0;
      g.ui.story('BOOKED', `You spend a night in the ${this.jurName(jur)} lockup and pay ${R.fmtMoney(fine)} in fines. Your slate is clean here.`);
      g.clock.skip(10 * 60);
    } else {
      const days = 1 + Math.floor(b / 200);
      pl.cash = Math.floor(pl.cash * 0.5);
      this.bounty[jur] = 0;
      g.ui.story('DOING TIME', `Can't cover the ${R.fmtMoney(fine)} bounty. You serve ${days} day${days > 1 ? 's' : ''} in the ${this.jurName(jur)} county jail. The city kept living without you.`);
      for (let k = 0; k < days; k++) g.clock.skip(24 * 60);
    }
    const city = g.world.cities.find((c) => c.id === jur) || g.world.cities[0];
    const ps = city.buildings.find((b) => b.type === 'police');
    if (ps) pl.place(ps.out.x * TS + 8, ps.out.y * TS + 10);
    pl.weaponOut = false;
    pl.stats.arrests++;
  };
  L.payBounty = function (jur) {
    const g = this.game, pl = g.player;
    const b = this.bounty[jur] || 0;
    if (!b) return false;
    if (pl.cash < b) return false;
    pl.cash -= b;
    this.bounty[jur] = 0;
    g.ui.toast(`Bounty of ${R.fmtMoney(b)} paid in ${this.jurName(jur)}.`, 'good');
    return true;
  };
  L.clearIncident = function (quiet) {
    const g = this.game, inc = this.incident;
    if (!inc) return;
    for (const u of inc.units) {
      if (u.dead || u.removed) continue;
      u.keep = false;
      u.hostile = false;
      if (u.state === 'fight') { u.state = 'idle'; u.timer = 2; u.target = null; }
      if (u.inCar) u.inCar.keep = false;
    }
    for (const v of g.traffic.list) if (v.modelId === 'police') { v.siren = false; v.keep = false; if (v.ai) { v.ai.target = null; v.ai.dest = null; } }
    for (const a of g.actors.list) if (a.cop && a.hostile) { a.hostile = false; if (a.state === 'fight') { a.state = 'idle'; a.timer = 2; } }
    this.incident = null;
    g.ui.closeArrest();
    g.audio.music(null);
    if (!quiet) {
      const b = this.bounty[inc.jur] || 0;
      g.ui.toast(`You lost them.${b ? ` Bounty in ${this.jurName(inc.jur)}: ${R.fmtMoney(b)}.` : ' They never got a look at your face.'}`, 'good');
      g.player.stats.escapes++;
    }
  };

  // ------------------------------------------------ per-frame
  L.update = function (dt) {
    const g = this.game, inc = this.incident;
    // indoors, the law treats you as being at the building's front door
    const pl = g.player.room ? Object.assign({}, g.player, g.interiors.outside(g.player.x, g.player.y), { inside: g.player.room }) : g.player;
    this.hunterT -= dt;
    if (this.hunterT <= 0) { this.hunterT = 90; this.bountyHunters(); }
    if (!inc) return;
    const now = g.clock.real;
    // check cop line of sight directly (so cars count too)
    let seenNow = false;
    for (const u of inc.units) {
      if (u.dead || u.removed) continue;
      const P0 = u.room ? g.player : pl;
      const d = R.dist(u.x, u.y, P0.x, P0.y);
      if (d < TS * 13 && (u.room || !pl.inside) && g.world.los(u.x, u.y - 8, P0.x, P0.y - 8)) { seenNow = true; break; }
    }
    const P1 = g.player;
    for (const a of g.actors.near(P1.x, P1.y, TS * 12)) {
      if (a.cop && !a.dead && !inc.units.includes(a) && g.world.los(a.x, a.y - 8, P1.x, P1.y - 8)) { inc.units.push(a); seenNow = true; }
    }
    if (seenNow) this.seen(null);
    const sinceSeen = now - inc.seenT;
    // police cars chase when you drive, head to last seen otherwise
    for (const v of g.traffic.list) {
      if (v.modelId !== 'police' || !v.driver || v.driver === pl || v.removed || !v.keep) continue;
      if (inc.state === 'pursuit' && sinceSeen < 3 && pl.inCar) v.ai = { target: pl, stopNear: 0 };
      else if (inc.state === 'pursuit' && sinceSeen < 3 && R.dist(v.x, v.y, pl.x, pl.y) > TS * 6) v.ai = { target: pl, stopNear: 50, onArrive: (c) => this.unload(c) };
      else if (!v.ai || !v.ai.dest) v.ai = { dest: { x: inc.lastX, y: inc.lastY }, stopNear: 40, onArrive: (c) => this.unload(c) };
    }
    // foot units lose track -> search
    if (inc.state === 'pursuit' && sinceSeen > 6) {
      inc.state = 'search';
      inc.searchLeft = 40 + inc.level * 12;
      g.ui.toast('They lost sight of you. Leave the search area or lie low.', 'warn');
      for (const u of inc.units) if (!u.dead && !u.removed && !u.inCar) this.searchPoint(u);
    }
    if (inc.state === 'responding' || inc.state === 'search') {
      if (inc.state === 'responding' && now - inc.started > 25) { inc.state = 'search'; inc.searchLeft = 40 + inc.level * 12; }
      inc.searchLeft -= dt * (pl.inside ? 1.6 : 1);
      const outside = R.dist(pl.x, pl.y, inc.lastX, inc.lastY) > this.searchRadius();
      if (outside) inc.outT = (inc.outT || 0) + dt;
      else inc.outT = 0;
      for (const u of inc.units) if (!u.dead && !u.removed && !u.inCar && u.state === 'idle') this.searchPoint(u);
      if ((inc.state === 'search' && inc.searchLeft <= 0) || inc.outT > 6 || this.jurAt(pl.x, pl.y) !== inc.jur && inc.outT > 2) this.clearIncident(false);
    }
    // arrest countdown
    if (inc.arrestT > 0) {
      inc.arrestT -= dt;
      if (inc.arrestT <= 0 && this.incident) this.resist('You ignored the order');
    }
    // reinforcements
    inc.dispatchT -= dt;
    if (inc.dispatchT <= 0 && this.incident) { inc.dispatchT = 25; this.dispatch(); }
  };

  // ------------------------------------------------ bounty hunters on the open road
  L.bountyHunters = function () {
    const g = this.game, pl = g.player;
    if (this.incident || pl.inside) return;
    const jur = this.jurAt(pl.x, pl.y);
    if (jur !== 'county') return;
    let best = null, amt = 0;
    for (const k in this.bounty) if (this.bounty[k] > amt) { amt = this.bounty[k]; best = k; }
    if (amt < 120 || R.rng() > Math.min(0.5, amt / 800) * g.settings.events) return;
    const s = g.world.findNear(pl.x / TS, pl.y / TS, 16, 22, (x, y) => !g.world.solidPed(x, y) && !g.world.isWater(x, y));
    if (!s) return;
    const n = amt > 400 ? 3 : 2;
    for (let i = 0; i < n; i++) {
      const h = g.actors.makeHuman(s.x * TS + 8 + i * 12, s.y * TS + 8, { tag: 'bounty', weapon: R.rng.pick(['rifle', 'shotgun', 'revolver']) });
      h.look.hat = 'cowboy';
      h.look.hatCol = '#4a3020';
      h.look.top = '#5a4030';
      h.tr.brave = 1;
      h.hostileLocked = true;
      g.actors.setFight(h, pl);
      if (i === 0) g.actors.say(h, `That's the one from ${this.jurName(best)}. ${R.fmtMoney(amt)}, dead or alive!`);
    }
    g.ui.toast(`Bounty hunters from ${this.jurName(best)} tracked you down.`, 'bad');
  };

  L.serialize = function () {
    return { bounty: this.bounty };
  };
  L.restore = function (s) {
    this.bounty = s.bounty || {};
  };
})();
