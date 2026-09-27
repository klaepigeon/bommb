// RHAPSODY — the player: Nicky "The Mook" Marchetti. Movement, weapons, cars,
// robbing, looting, skinning, crew, the "Cool" slow-mo, gasoline and fishing.
'use strict';
(function () {
  const D = R.data, T = D.T, O = D.O, TS = R.TILE;

  const Player = (R.Player = function (game) {
    this.game = game;
    this.kind = 'player';
    this.name = 'Nicky Marchetti';
    this.nick = 'Nicky';
    this.family = 'Vane';
    this.x = 0; this.y = 0; this.r = 4;
    this.dir = 2; this.ang = Math.PI / 2; this.walk = 0;
    this.hp = 100; this.maxHp = 100;
    this.cool = 40; this.coolOn = false;
    this.cash = 60;
    this.inv = { weapons: { fists: 1, revolver: 1 }, ammo: { pistol: 18, shells: 0, smg: 0, rifle: 0, molotov: 1, dynamite: 0 }, cons: { bandage: 2, smokes: 1 }, loot: {}, tools: { mask: 1, lockpick: 2 } };
    this.clip = { revolver: 6 };
    this.weapon = 'fists';
    this.weaponOut = false;
    this.masked = false;
    this.sneak = false;
    this.inCar = null;
    this.inside = null;
    this.outfit = 'mook';
    this.style = R.styleDefault();
    this.wardrobe = {};
    this.outfitChangedSince = 0;
    this.rep = { infamy: 0, honor: 0 };
    this.standing = {};
    this.stats = { kills: 0, crimes: 0, arrests: 0, escapes: 0, jobs: 0, deaths: 0, hunted: 0, fish: 0, robbed: 0, greeted: 0, miles: 0, startT: null };
    this.crew = [];
    this.sweetheart = -1;
    this.drunk = 0;
    this.bloody = 0;
    this.atkT = 0;
    this.knockV = null;
    this.dead = false;
    this.gasLeft = 0;
    this.ownedCars = [];
    this.properties = [];
    this.buildLook();
  });
  const P = Player.prototype;

  // A young mafioso, painted by the original game's own character routine (see 13_style.js).
  P.buildLook = function () {
    if (!this.style) this.style = R.styleDefault();
    this.outfit = this.style.jacket in D.outfits ? this.style.jacket : 'mook';
    this.look = R.lookFromStyle(this.style, this.masked);
  };
  P.outfitScore = function () {
    const city = this.game.world.cityAt((this.x / TS) | 0, (this.y / TS) | 0);
    const j = this.style ? this.style.jacket : this.outfit;
    const jd = D.style.jackets[j] || {};
    const fancy = !!jd.fancy, rugged = j === 'leather' || j === 'denim' || j === 'none' || j === 'corduroy';
    const hatBonus = this.style && this.style.hat !== 'none' ? (this.style.hat === 'cowboy' ? (city ? -2 : 4) : 2) : 0;
    if (!city) return (rugged ? 10 : fancy ? -5 : 0) + hatBonus;
    return (fancy ? 8 : rugged ? 2 : 3) + hatBonus;
  };
  P.place = function (x, y) {
    this.x = x; this.y = y;
  };
  P.addCash = function (n) {
    this.cash += n;
    this.game.fx.money(this.x, this.y - 24, n);
  };
  P.pay = function (n) {
    if (this.cash < n) return false;
    this.cash -= n;
    return true;
  };
  P.giveWeapon = function (id) {
    this.inv.weapons[id] = 1;
    const w = D.weapons[id];
    if (w.clip && this.clip[id] === undefined) this.clip[id] = w.clip;
  };

  // ---------------------------------------------------------------- update
  P.update = function (dt) {
    const g = this.game, inp = g.input;
    if (this.dead) return;
    this.drunk = Math.max(0, this.drunk - dt * 0.004);
    if (this.punchT > 0) this.punchT -= dt;
    this.bloody = Math.max(0, this.bloody - dt * 0.003);
    if (this.outfitChangedSince > 0) this.outfitChangedSince -= dt;
    // cool meter
    if (this.coolOn) {
      this.cool -= dt * 28 / (g.timeScale || 1);
      if (this.cool <= 0 || inp.pressed('cool')) this.setCool(false);
    } else if (inp.pressed('cool')) this.setCool(true);
    if (inp.pressed('mask')) this.toggleMask();
    if (inp.pressed('sneak') && !this.inCar) { this.sneak = !this.sneak; g.ui.toast(this.sneak ? 'Sneaking: quieter, animals spook less.' : 'Walking normally.'); }
    if (inp.pressed('heal')) this.useConsumable();
    if (this.inside) return;
    if (this.inCar) return this.updateCar(dt);
    // knockback
    if (this.knockV) {
      g.actors.moveActor(this, this.knockV.x, this.knockV.y, dt);
      this.knockV.x *= 1 - dt * 6; this.knockV.y *= 1 - dt * 6;
      if (Math.hypot(this.knockV.x, this.knockV.y) < 5) this.knockV = null;
      return;
    }
    // movement
    const st = inp.stick;
    let mx = st.x, my = st.y;
    const mag = Math.min(1, Math.hypot(mx, my));
    if (this.drunk > 0.2) {
      const wob = Math.sin(g.clock.real * 2.3) * this.drunk * 0.9;
      const c = Math.cos(wob), s = Math.sin(wob);
      [mx, my] = [mx * c - my * s, mx * s + my * c];
    }
    const running = (inp.held('run') || inp.held('runStick')) && !this.sneak;
    const heavy = this.held && D.props[this.held.k].heavy ? 0.7 : 1;
    const speed = (this.sneak ? 26 : running ? 86 : 48) * heavy * (g.timeScale < 1 ? 1.8 : 1) * (g.cheats.fastRun ? 2.2 : 1);
    if (mag > 0.12) {
      const nx = mx / Math.max(mag, 0.001), ny = my / Math.max(mag, 0.001);
      g.actors.moveActor(this, nx * speed * mag, ny * speed * mag, dt);
      this.walk += dt * speed * mag * 0.35;
      if (!(this.weaponOut && inp.held('attack'))) {
        this.ang = Math.atan2(ny, nx);
        this.dir = R.dir4(nx, ny);
      }
      this.stats.miles += speed * mag * dt / TS / 1600;
      if (g.env.gasAt(this.x, this.y) === false && this.weapon === 'gascan' && inp.held('attack')) {}
    } else this.walk = 0;
    // water: slow + can't draw
    // focus target
    this.focus = g.ui.focusTarget();
    this.atkT -= dt;
    // an improvised weapon in hand takes over HIT and SWAP
    if (this.held) {
      if (inp.longPressed('weapon')) { R.props.dropHeld(this); g.ui.toast('Dropped it.'); }
      else if (inp.pressed('weapon')) this.throwPending = true;
      if (this.throwPending && !inp.held('weapon')) { this.throwPending = false; if (this.held) R.props.throwHeld(this); }
      if (this.held && inp.pressed('attack')) R.props.swing(this);
      if (inp.pressed('use')) this.use();
      this.crewUpdate(dt);
      return;
    }
    // weapons
    if (inp.pressed('weapon')) this.cycleWeapon();
    if (inp.longPressed('weapon')) this.holster();
    const w = D.weapons[this.weapon];
    if (this.weapon === 'gascan') {
      if (inp.held('attack')) this.pour(dt);
    } else if (w && (inp.pressed('attack') || (w.auto && inp.held('attack')))) {
      if (!this.weaponOut && this.weapon !== 'fists') { this.weaponOut = true; this.atkT = 0.2; }
      else this.fire();
    }
    // context action (USE)
    if (inp.pressed('use')) this.use();
    // greet / antagonize / talk keyboard shortcuts
    const f = this.focus;
    if (f && f.kind === 'h' && !f.dead) {
      if (inp.pressed('greet')) this.greet(f);
      if (inp.pressed('antag')) this.antagonize(f);
      if (inp.pressed('talk')) this.talk(f);
      if (inp.pressed('defuse')) R.dialog.defuse(f);
    }
    // pickpocket-thief reclaim, crew upkeep
    this.crewUpdate(dt);
  };

  P.setCool = function (on) {
    const g = this.game;
    if (on && this.cool < 15) return g.ui.toast('Not cool enough. Have a drink or a smoke.', 'warn');
    this.coolOn = on;
    g.timeScale = on ? 0.35 : 1;
    g.audio.sfx(on ? 'coolOn' : 'coolOff');
    if (on) g.ui.toast('COOL: time slows, every shot lands.');
  };
  P.toggleMask = function () {
    const g = this.game;
    if (!this.inv.tools.mask) return g.ui.toast('No mask. Tailors sell ski masks.', 'warn');
    this.masked = !this.masked;
    this.buildLook();
    // taking it off in front of people who saw a masked crime: identified
    if (!this.masked && g.law.incident && !g.law.incident.identified) {
      for (const a of g.actors.near(this.x, this.y, TS * 8)) {
        if (a.kind === 'h' && !a.dead && (a.cop || a.witness) && g.world.los(a.x, a.y - 8, this.x, this.y - 8)) {
          g.law.incident.identified = true;
          for (const c of g.law.incident.crimes) if (!c.identified) { c.identified = true; g.law.addBounty(c); }
          g.ui.toast('They saw your face. The bounty is on you now.', 'bad');
          break;
        }
      }
    }
    g.ui.toast(this.masked ? 'Mask on. Witnesses won\'t know who you are, but everyone gets nervous.' : 'Mask off.');
  };

  P.weaponList = function () {
    const order = ['fists', 'knuckles', 'bat', 'knife', 'revolver', 'magnum', 'shotgun', 'chopper', 'rifle', 'molotov', 'dynamite'];
    const out = order.filter((w) => this.inv.weapons[w] || (D.weapons[w].thrown && this.inv.ammo[w] > 0));
    if (this.inv.tools.gascan) out.push('gascan');
    return out;
  };
  P.cycleWeapon = function () {
    const list = this.weaponList();
    const i = list.indexOf(this.weapon);
    this.weapon = list[(i + 1) % list.length];
    this.weaponOut = this.weapon !== 'fists';
    this.game.audio.sfx('equip');
    const w = D.weapons[this.weapon];
    const name = this.weapon === 'gascan' ? `Gas Can (${this.inv.tools.gascan})` : w.name;
    this.game.ui.toast(name + (w && w.gun ? `  ${this.clip[this.weapon] || 0}/${this.inv.ammo[w.ammo] || 0}` : w && w.thrown ? `  x${this.inv.ammo[this.weapon]}` : ''));
  };
  P.holster = function () {
    this.weapon = 'fists';
    this.weaponOut = false;
    this.game.ui.toast('Holstered.');
  };
  P.aimTarget = function () {
    const g = this.game;
    const w = D.weapons[this.weapon];
    const range = w ? (w.melee ? 30 : w.range) : 60;
    let best = null, bs = 1e9;
    for (const a of g.actors.near(this.x, this.y, range)) {
      if (a.dead || a.inCar || (a.kind === 'a' && a.flying)) continue;
      const d = R.dist(this.x, this.y, a.x, a.y);
      const ang = Math.atan2(a.y - this.y, a.x - this.x);
      const off = Math.abs(R.angDiff(this.ang, ang));
      const hostile = (a.kind === 'h' && a.hostile && a.state === 'fight') || (a.kind === 'a' && a.state === 'attack');
      if (off > (hostile ? 1.6 : 0.8)) continue;
      if (!g.world.los(this.x, this.y - 8, a.x, a.y - 8)) continue;
      const score = d + off * 60 - (hostile ? 120 : 0) - (a === this.focus ? 40 : 0);
      if (score < bs) { bs = score; best = a; }
    }
    // cars too, for guns
    if (!best && w && w.gun) {
      const v = g.traffic.hash.query(this.x + Math.cos(this.ang) * 50, this.y + Math.sin(this.ang) * 50, 50).find((v) => !v.wrecked && v !== this.inCar);
      if (v) best = v;
    }
    return best;
  };
  P.fire = function () {
    const g = this.game;
    const w = D.weapons[this.weapon];
    if (!w || this.atkT > 0) return;
    if (R.ring.canSwing(this)) return R.ring.swing(this);
    const tg = this.aimTarget();
    let ang = this.ang;
    if (tg) {
      ang = Math.atan2((tg.y - (tg.kind === 'h' && w.gun ? 10 : 0)) - (this.y - 10), tg.x - this.x);
      this.ang = Math.atan2(tg.y - this.y, tg.x - this.x);
      this.dir = R.dir4(Math.cos(this.ang), Math.sin(this.ang));
    }
    if (w.gun) {
      const c = this.clip[this.weapon] || 0;
      if (c <= 0) return this.reload();
      if (!g.cheats.infAmmo) this.clip[this.weapon] = c - 1;
      this.atkT = w.rate;
      R.combat.shoot(this, w, ang, tg);
      if (this.clip[this.weapon] <= 0) setTimeout(() => this.reload(), 250);
    } else if (w.thrown) {
      if (!this.inv.ammo[this.weapon]) return g.ui.toast('Out of ' + w.name + 's.', 'warn');
      this.inv.ammo[this.weapon]--;
      this.atkT = w.rate;
      R.combat.throwIt(this, this.weapon, w, ang, tg);
      if (!this.inv.ammo[this.weapon]) this.cycleWeapon();
    } else {
      this.atkT = w.rate;
      this.power = 1 + (this.drunk > 0.3 ? 0.2 : 0);
      this.punchT = 0.18;
      this.punchN = (this.punchN || 0) + 1;
      R.combat.melee(this, w, ang);
    }
  };
  P.reload = function () {
    const g = this.game;
    const w = D.weapons[this.weapon];
    if (!w || !w.gun) return;
    const have = this.inv.ammo[w.ammo] || 0;
    const need = w.clip - (this.clip[this.weapon] || 0);
    if (!have) return g.ui.toast('Out of ammo. The gun store has more.', 'warn');
    const n = Math.min(need, have);
    this.inv.ammo[w.ammo] -= n;
    this.clip[this.weapon] = (this.clip[this.weapon] || 0) + n;
    this.atkT = 0.9;
    g.audio.sfx('reload');
  };

  // ---------------------------------------------------------------- USE / context
  // Returns the best contextual action {label, fn}
  P.contextAction = function () {
    const g = this.game, w = g.world;
    if (this.inCar) {
      const v = this.inCar;
      const hitch = g.actors.near(v.x, v.y, 36, (a) => a.tag === 'hitch' && !a.dead && !a.inCar)[0];
      if (hitch && Math.abs(v.speed) < 15) return { label: 'Offer ride', fn: () => this.pickUp(hitch) };
      return { label: 'Exit', fn: () => this.exitCar() };
    }
    // indoors: the doormat and the furniture
    if (this.room) {
      const room = this.room;
      const tx = (this.x / TS) | 0, ty = ((this.y + 4) / TS) | 0;
      if (Math.abs(tx - room.exit.x) <= 1 && ty >= room.exit.y - 1) return { label: 'Leave', fn: () => g.interiors.exit() };
      for (const a of g.actors.near(this.x, this.y, 18)) {
        if (a.kind === 'h' && (a.dead || a.down > 0) && !a.looted) return { label: a.dead ? 'Search body' : 'Go through pockets', fn: () => this.loot(a) };
      }
      const grI = R.props.grabbable(this);
      if (grI) return { label: R.props.label(grI), fn: () => R.props.pickUp(this, grI) };
      const fa = g.interiors.furnitureAhead();
      if (fa) { const act = g.interiors.furnitureAction(fa); if (act) return act; }
      return null;
    }
    // gasoline
    if (g.env.gasAt(this.x, this.y) && this.inv.ammo) return { label: 'Light it', fn: () => { g.env.ignite(this.x, this.y, 0.6, this); g.audio.sfx('match'); this.knock(this.ang + Math.PI, 90); } };
    // bodies & animals
    for (const a of g.actors.near(this.x, this.y, 18)) {
      if (a.kind === 'a' && a.dead && !a.skinned && a.def.pelt) return { label: 'Skin ' + a.def.name, fn: () => this.skin(a) };
      if (a.kind === 'h' && (a.dead || a.down > 0) && !a.looted) return { label: a.dead ? 'Search body' : 'Go through pockets', fn: () => this.loot(a) };
    }
    // loose junk lying right at your feet beats the door you happen to be near
    const gr = R.props.grabbable(this);
    if (gr && gr.p) return { label: R.props.label(gr), fn: () => R.props.pickUp(this, gr) };
    // doors
    const door = this.nearDoor();
    if (door) return { label: door.label, fn: door.fn };
    // cars
    const v = g.traffic.nearestCar(this.x, this.y, 22);
    if (v) {
      if (v.driver && v.driver !== this && !v.driver.dead) return { label: v.driver.cop ? 'Carjack (police!)' : 'Carjack', fn: () => this.carjack(v) };
      if (v.locked && v.owner !== 'player') return this.inv.tools.lockpick ? { label: 'Pick the car lock', fn: () => R.mini.lockpick({ pins: 3, title: 'Pick the car door' }, (ok) => { if (ok) { v.locked = false; g.law.crime('cartheft', v.x, v.y, { minor: true }); this.enterCar(v); } }) } : { label: 'Smash the window', fn: () => this.breakIn(v) };
      return { label: 'Get in', fn: () => this.enterCar(v) };
    }
    // street furniture you can rip up
    if (gr) return { label: R.props.label(gr), fn: () => R.props.pickUp(this, gr) };
    // phone booths
    const tx = (this.x / TS) | 0, ty = (this.y / TS) | 0;
    for (let yy = ty - 1; yy <= ty + 1; yy++) for (let xx = tx - 1; xx <= tx + 1; xx++) if (w.o(xx, yy) === O.PHONE) return { label: 'Use payphone', fn: () => g.ui.openPhone() };
    // fishing
    if (this.inv.tools.rod) {
      for (const [dx, dy] of R.DIRS) if (w.isWater(tx + dx, ty + dy)) return { label: 'Fish', fn: () => g.ui.fish() };
    }
    // hydrant: smash it
    return null;
  };
  P.use = function () {
    const a = this.contextAction();
    if (a) a.fn();
  };
  P.nearDoor = function () {
    const g = this.game, w = g.world;
    const tx = (this.x / TS) | 0, ty = (this.y / TS) | 0;
    for (let yy = ty - 1; yy <= ty + 1; yy++)
      for (let xx = tx - 1; xx <= tx + 1; xx++) {
        const b = w.buildingAt(xx, yy);
        if (!b || b.destroyed) continue;
        if (b.door.x === xx && b.door.y === yy && Math.abs(b.out.x - tx) + Math.abs(b.out.y - ty) <= 1) {
          return { b, label: 'Enter ' + b.name, fn: () => g.interiors.doorPrompt(b) };
        }
      }
    return null;
  };

  P.greet = function (h) {
    if (h.state === 'fight' || h.dead) return;
    R.dialog.greet(h);
    this.stats.greeted++;
  };
  P.antagonize = function (h) {
    if (h.dead) return;
    R.dialog.antagonize(h);
  };
  P.talk = function (h) {
    if (h.dead || h.state === 'fight') return;
    h.state = 'talk';
    h.timer = 60;
    this.game.ui.openTalk(h);
  };

  P.rob = function (h) {
    const g = this.game;
    const cash = h.cash;
    this.addCash(cash);
    h.cash = 0;
    for (const l of h.loot) this.inv.loot[l] = (this.inv.loot[l] || 0) + 1;
    const lootNames = h.loot.map((l) => D.loot[l].name);
    h.loot = [];
    g.actors.say(h, R.rng.pick(['Take it! Just take it!', 'That\'s my rent money...', 'You\'ll get yours, mister.']));
    g.law.crime('mugging', h.x, h.y, { victim: h });
    h.robbed = true;
    this.stats.robbed++;
    if (h.person) {
      h.person.opinion = Math.max(-100, h.person.opinion - 30);
      h.person.fear = Math.min(100, h.person.fear + 25);
      g.pop.remember(h.person, 'robbed', 'I got robbed in broad daylight by a guy in a fedora.', g.pop.day);
      this.collectDebt(h.person, cash);
    }
    g.ui.toast(`Robbed ${R.fmtMoney(cash)}${lootNames.length ? ' + ' + lootNames.join(', ') : ''}.`);
    g.actors.setFlee(h, this, 8);
  };
  P.collectDebt = function (p, amount) {
    const g = this.game;
    const j = g.jobs.active;
    if (!j || j.kind !== 'collect' || j.person !== p.id || p.debt <= 0) return;
    const paid = Math.min(p.debt, Math.max(amount, p.debt)); // they cough up the rest to stop the beating
    p.debt = 0;
    g.ui.toast(`${p.first} paid the ${R.fmtMoney(paid)} they owed the family.`, 'good');
  };
  P.loot = function (h) {
    const g = this.game;
    h.looted = true;
    let cash = h.cash;
    if (h.stolen) cash += 0; // pickpocket's haul is already in cash
    this.addCash(cash);
    h.cash = 0;
    for (const l of h.loot) this.inv.loot[l] = (this.inv.loot[l] || 0) + 1;
    const n = h.loot.length;
    h.loot = [];
    // ammo off armed bodies
    if (h.armed && D.weapons[h.weapon] && D.weapons[h.weapon].gun) {
      const am = D.weapons[h.weapon].ammo;
      const got = R.rng.int(2, 6);
      this.inv.ammo[am] = (this.inv.ammo[am] || 0) + got;
      if (!this.inv.weapons[h.weapon] && R.rng() < 0.5) { this.giveWeapon(h.weapon); g.ui.toast(`Picked up a ${D.weapons[h.weapon].name}.`, 'good'); }
    }
    if (h.person) this.collectDebt(h.person, cash);
    g.ui.toast(`Found ${R.fmtMoney(cash)}${n ? ` and ${n} item${n > 1 ? 's' : ''}` : ''}.`);
    if (!h.dead && h.down > 0 && !h.hostile) g.law.crime('theft', h.x, h.y, { victim: null, minor: false });
    g.audio.sfx('loot');
  };
  P.skin = function (a) {
    const g = this.game;
    a.skinned = true;
    const pelt = a.def.pelt;
    this.inv.loot[pelt] = (this.inv.loot[pelt] || 0) + 1;
    if (pelt !== 'meat') this.inv.loot.meat = (this.inv.loot.meat || 0) + (a.def.size > 8 ? 2 : 1);
    g.fx.blood(a.x, a.y, 6);
    g.ui.toast(`Skinned: ${D.loot[pelt].name}. Sell it at a Butcher & Trapper.`, 'good');
    g.audio.sfx('loot');
  };

  // ---------------------------------------------------------------- vehicles
  P.enterCar = function (v, wired) {
    const g = this.game;
    if (v.wrecked) return;
    // a parked car that isn't yours has to be hotwired
    if (!wired && v.parked && v.owner !== 'player' && !v.hotwired && !v.jobCar) {
      return R.mini.hotwire({ wires: v.model.top > 200 ? 5 : 4, time: 14 }, (ok) => {
        if (ok) { v.hotwired = true; this.enterCar(v, true); return; }
        g.audio.sfx('alarm', v.x, v.y);
        g.actors.noise(v.x, v.y, TS * 8, 'scream', this);
        g.ui.toast('Car alarm! Try again or get out of here.', 'warn');
      });
    }
    this.inCar = v;
    v.driver = this;
    v.parked = false;
    v.mode = 'player';
    v.keep = true;
    this.weaponOut = false;
    g.audio.sfx('door');
    if (v.owner !== 'player' && !v.stolen) {
      v.stolen = true;
      this.stats.carsStolen = (this.stats.carsStolen || 0) + 1;
    }
    // crew hop in
    v.passengers = v.passengers || [];
    for (const c of this.crew) if (!c.dead && R.dist(c.x, c.y, v.x, v.y) < TS * 5) { c.inCar = v; v.passengers.push(c); }
    g.audio.radio(v.radio);
    R.bus.emit('player:car', v);
  };
  P.exitCar = function () {
    const g = this.game;
    const v = this.inCar;
    if (!v) return;
    if (Math.abs(v.speed) > 70) {
      // bail out at speed
      this.hurt(15, null, 'fall');
    }
    g.traffic.exitVehicle(v, this);
    v.driver = null;
    v.mode = 'chase';
    v.keep = v.owner === 'player';
    this.inCar = null;
    for (const c of v.passengers || []) { if (c.crew) { g.traffic.exitVehicle(v, c); c.state = 'follow'; } }
    v.passengers = (v.passengers || []).filter((p) => !p.crew);
    g.audio.radio(null);
    g.audio.sfx('door');
  };
  P.carjack = function (v) {
    const g = this.game;
    const d = v.driver;
    g.traffic.exitVehicle(v, d);
    d.hp -= 10;
    d.down = 1.5;
    g.actors.say(d, R.rng.pick(['Hey! That\'s my car!', 'Help! Carjacker!', 'Not again!']));
    for (const p of v.passengers || []) { g.traffic.exitVehicle(v, p); g.actors.setFlee(p, this, 8); }
    v.passengers = [];
    setTimeout(() => { if (!d.dead) { if (d.tr.brave > 0.75 || d.cop) g.actors.setFight(d, this); else g.actors.setFlee(d, this, 8); } }, 1500);
    g.law.crime(d.cop ? 'copAssault' : 'carjack', v.x, v.y, { victim: d });
    this.enterCar(v);
  };
  P.breakIn = function (v) {
    const g = this.game;
    g.audio.sfx('glass', v.x, v.y);
    g.fx.shatter(v.x, v.y);
    v.locked = false;
    g.actors.noise(v.x, v.y, TS * 6, 'scream', this);
    g.law.crime('cartheft', v.x, v.y, {});
    if (v.jobCar) {} // part of a job
    if (R.rng() < 0.3 && g.clock.isNight() === false) g.ui.toast('Car alarm!', 'warn'), g.audio.sfx('alarm');
    this.enterCar(v);
  };
  P.updateCar = function (dt) {
    const g = this.game, inp = g.input, v = this.inCar;
    this.x = v.x; this.y = v.y;
    this.focus = null;
    if (inp.pressed('use')) this.use();
    if (inp.pressed('radio')) g.audio.nextStation(v);
    if (inp.pressed('attack')) {
      // drive-by: fire sideways at nearest target
      const w = D.weapons[this.weapon];
      const best = g.actors.near(v.x, v.y, 150, (a) => !a.dead && !a.inCar && (a.kind === 'a' || a.hostile || a.cop))[0];
      if (w && w.gun && best) {
        const ang = Math.atan2(best.y - v.y, best.x - v.x);
        if ((this.clip[this.weapon] || 0) > 0 && this.atkT <= 0) { this.clip[this.weapon]--; this.atkT = w.rate; R.combat.shoot(this, w, ang, best); }
        else this.reload();
      }
    }
    this.atkT -= dt;
    if (inp.pressed('weapon')) this.cycleWeapon();
    // hitchhiker drop-off
    for (const p of v.passengers || []) {
      if (p.tag === 'hitch' && p.hitchDest) {
        const c = p.hitchDest;
        if (R.dist(v.x / TS, v.y / TS, c.cx, c.cy) < c.nbx * 7 && Math.abs(v.speed) < 20) {
          v.passengers = v.passengers.filter((q) => q !== p);
          g.traffic.exitVehicle(v, p);
          p.tag = 'ambient';
          p.keep = false;
          const tip = R.rng.int(25, 60);
          this.addCash(tip);
          g.actors.say(p, `Thanks for the lift! Here's ${R.fmtMoney(tip)}. Stay groovy.`);
          this.rep.honor += 2;
        }
      }
    }
  };
  P.pickUp = function (h) {
    const v = this.inCar;
    h.inCar = v;
    v.passengers = v.passengers || [];
    v.passengers.push(h);
    this.game.actors.say(h, `Bless you! ${h.hitchDest.name}, please.`);
  };

  // ---------------------------------------------------------------- health
  P.hurt = function (amt, src, kind) {
    const g = this.game;
    if (this.dead || (g.cheats && g.cheats.god)) return;
    if (this.inside) return;
    if (this.inCar && kind !== 'blast' && kind !== 'fire' && kind !== 'bullet' && kind !== 'fall') return;
    if (this.shieldT > 0) { g.fx.text(this.x, this.y - 26, 'BLOCKED', '#fff27a'); g.fx.sparks(this.x, this.y - 12, 3); return; }
    this.hp -= amt;
    this.bloody = Math.min(1, this.bloody + amt / 60);
    g.ui.hurtFlash(amt);
    g.fx.blood(this.x, this.y - 8, 3);
    if (src && src.kind === 'h' && src !== this) {
      // being attacked makes the attacker hostile: self-defence is legal
      src.hostile = true;
    }
    if (this.hp <= 0) this.die();
  };
  P.knock = function (ang, force) {
    this.knockV = { x: Math.cos(ang) * force, y: Math.sin(ang) * force };
  };
  P.die = function () {
    const g = this.game;
    this.dead = true;
    this.hp = 0;
    this.stats.deaths++;
    if (this.inCar) this.exitCar();
    if (this.coolOn) this.setCool(false);
    g.ui.death();
  };
  P.respawn = function () {
    const g = this.game, w = g.world;
    // nearest hospital
    let best = null, bd = 1e9;
    for (const b of w.buildings) {
      if (!b || b.type !== 'hospital' || b.destroyed) continue;
      const d = R.dist(b.out.x * TS, b.out.y * TS, this.x, this.y);
      if (d < bd) { bd = d; best = b; }
    }
    g.law.clearIncident(true);
    const fee = Math.min(this.cash, Math.max(20, Math.round(this.cash * 0.1)));
    this.cash -= fee;
    this.hp = this.maxHp;
    this.dead = false;
    this.bloody = 0;
    this.drunk = 0;
    this.weaponOut = false;
    this.knockV = null;
    for (const a of g.actors.list) if (a.hostile && a.state === 'fight') { a.state = 'idle'; a.target = null; a.hostile = false; }
    if (best) this.place(best.out.x * TS + 8, best.out.y * TS + 12);
    g.clock.skip(6 * 60);
    g.ui.toast(`You wake up at ${best ? best.name : 'the hospital'}. The bill: ${R.fmtMoney(fee)}.`);
  };
  P.useConsumable = function () {
    const g = this.game;
    const order = this.hp < this.maxHp * 0.7 ? ['bandage', 'tonic', 'sandwich', 'whiskey', 'smokes', 'coffee'] : ['smokes', 'whiskey', 'tonic', 'bandage', 'sandwich', 'coffee'];
    for (const id of order) {
      if (!this.inv.cons[id]) continue;
      this.inv.cons[id]--;
      const c = D.consumables[id];
      if (c.heal) this.hp = Math.min(this.maxHp, this.hp + c.heal);
      if (c.cool) this.cool = Math.min(100, this.cool + c.cool);
      if (c.drunk) this.drunk = Math.min(1, this.drunk + c.drunk);
      if (c.sober) this.drunk = 0;
      g.ui.toast(`Used ${c.name}.`);
      g.audio.sfx('drink');
      return;
    }
    g.ui.toast('Nothing to use. Stores sell bandages, smokes and whiskey.', 'warn');
  };
  P.drink = function () {
    this.drunk = Math.min(1, this.drunk + 0.25);
    this.cool = Math.min(100, this.cool + 30);
    this.hp = Math.min(this.maxHp, this.hp + 5);
  };

  // ---------------------------------------------------------------- gasoline
  P.pour = function (dt) {
    const g = this.game;
    this.pourT = (this.pourT || 0) - dt;
    if (this.pourT > 0) return;
    this.pourT = 0.12;
    if ((this.gasLeft || 0) <= 0) {
      if (!this.inv.tools.gascan) return;
      this.inv.tools.gascan--;
      this.gasLeft = 30;
    }
    if (g.env.pourGas(this.x, this.y + 2)) {
      this.gasLeft--;
      g.fx.add({ x: this.x + Math.cos(this.ang) * 6, y: this.y - 2, vx: 0, vy: 20, life: 0.2, max: 0.2, c: '#6a5a30', s: 2 });
    }
    if (this.gasLeft <= 0 && !this.inv.tools.gascan) { g.ui.toast('Gas can empty. Stand on the trail and press USE to light it.'); this.weapon = 'fists'; }
  };

  // ---------------------------------------------------------------- crew
  P.recruit = function (h) {
    h.crew = true;
    h.tag = 'crew';
    h.keep = true;
    h.hostile = false;
    h.state = 'follow';
    h.timer = 1e9;
    this.crew.push(h);
    if (!h.armed) this.game.actors.arm(h, 'revolver');
    this.game.ui.toast(`${this.game.actors.displayName(h)} joined your crew.`, 'good');
  };
  P.dismiss = function (h) {
    h.crew = false;
    h.tag = 'named';
    h.keep = false;
    h.state = 'idle';
    this.crew = this.crew.filter((c) => c !== h);
  };
  P.crewUpdate = function (dt) {
    const g = this.game;
    this.crew = this.crew.filter((c) => !c.dead && !c.removed);
    for (const c of this.crew) {
      if (c.inCar) continue;
      if (c.state === 'fight' && c.target && !c.target.dead && c.target !== this) continue;
      // defend the boss
      const threat = g.actors.near(this.x, this.y, TS * 10, (a) => a.kind === 'h' && !a.dead && a.hostile && a.state === 'fight' && !a.crew)[0];
      if (threat) { c.state = 'fight'; c.target = threat; c.drawn = true; continue; }
      if (c.state !== 'follow') { c.state = 'follow'; c.timer = 1e9; }
    }
  };
})();
