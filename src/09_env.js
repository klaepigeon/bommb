// RHAPSODY — environment: clock, weather, fire propagation, gasoline, hydrants,
// street lighting, building damage, particles and the camera.
'use strict';
(function () {
  const D = R.data, T = D.T, O = D.O, TS = R.TILE;

  // ---------------------------------------------------------------- clock
  R.Clock = function (game, startMinutes) {
    this.game = game;
    this.t = startMinutes; // in-game minutes since the epoch
    this.real = 0; // real seconds
    this.rate = 1; // game minutes per real second
    this.lastDay = Math.floor(startMinutes / 1440);
  };
  const CK = R.Clock.prototype;
  CK.update = function (dt) {
    this.real += dt;
    this.t += dt * this.rate;
    this.checkDay();
  };
  CK.checkDay = function () {
    // the daily life tick happens at 5am
    const d = Math.floor((this.t - 300) / 1440);
    while (this.lastDay < d) {
      this.lastDay++;
      this.game.onNewDay();
    }
  };
  CK.skip = function (mins) {
    this.t += mins;
    this.checkDay();
  };
  CK.day = function () { return Math.floor(this.t / 1440); };
  CK.hour = function () { return (this.t % 1440) / 60; };
  CK.isNight = function () { const h = this.hour(); return h < 5.5 || h >= 20.5; };
  CK.weekday = function () { return ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'][this.day() % 7]; };
  CK.label = function () {
    const h = Math.floor(this.hour()), m = Math.floor(this.t % 60);
    const ap = h < 12 ? 'AM' : 'PM';
    const hh = h % 12 === 0 ? 12 : h % 12;
    return `${hh}:${String(m).padStart(2, '0')} ${ap}`;
  };
  // 0 bright day .. 1 darkest night
  CK.darkness = function () {
    const h = this.hour();
    if (h >= 7 && h < 18.5) return 0;
    if (h >= 18.5 && h < 21) return (h - 18.5) / 2.5 * 0.82;
    if (h >= 21 || h < 4.5) return 0.82;
    return 0.82 * (1 - (h - 4.5) / 2.5);
  };
  // warm tint strength around sunset / sunrise
  CK.golden = function () {
    const h = this.hour();
    const a = Math.max(0, 1 - Math.abs(h - 18.7) / 1.6);
    const b = Math.max(0, 1 - Math.abs(h - 6.2) / 1.2) * 0.7;
    return Math.max(a, b);
  };

  // ---------------------------------------------------------------- environment
  const Env = (R.Env = function (game) {
    this.game = game;
    this.weather = { kind: 'clear', rain: 0, fog: 0, cloud: 0.1, wind: { x: 0.6, y: 0.2 }, target: null, nextT: 40, dry: 0.4, snow: false, heat: 0 };
    this.fires = new Map(); // tile idx -> {i, fuel, b}
    this.gas = new Map(); // tile idx -> amount
    this.geysers = [];
    this.fireT = 0;
    this.lightning = 0;
    this.fireDispatchT = 0;
    R.env = this;
  });
  const E = Env.prototype;

  const WEATHER = {
    clear: { rain: 0, fog: 0, cloud: 0.05, next: [['clear', 3], ['cloudy', 2], ['heat', 0.8], ['fog', 0.5]] },
    cloudy: { rain: 0, fog: 0.05, cloud: 0.5, next: [['clear', 2], ['rain', 2], ['cloudy', 1], ['storm', 0.6]] },
    rain: { rain: 0.7, fog: 0.15, cloud: 0.8, next: [['cloudy', 2], ['rain', 1], ['storm', 1], ['fog', 0.6]] },
    storm: { rain: 1, fog: 0.2, cloud: 1, next: [['rain', 2], ['cloudy', 1]] },
    fog: { rain: 0, fog: 0.7, cloud: 0.4, next: [['clear', 2], ['cloudy', 1]] },
    heat: { rain: 0, fog: 0, cloud: 0, next: [['clear', 2], ['heat', 1], ['storm', 0.4]] },
  };
  E.WEATHER_NAMES = { clear: 'Clear', cloudy: 'Overcast', rain: 'Rain', storm: 'Thunderstorm', fog: 'Fog', heat: 'Heatwave' };

  E.setWeather = function (kind) {
    const w = this.weather;
    w.kind = kind;
    w.target = WEATHER[kind];
    w.nextT = 40 + R.rng() * 80;
    const a = R.rng() * Math.PI * 2, s = kind === 'storm' ? 1.4 : 0.3 + R.rng() * 0.7;
    w.wind = { x: Math.cos(a) * s, y: Math.sin(a) * s };
  };

  E.update = function (dt) {
    const g = this.game, w = this.weather, pl = g.player;
    // regional flavour: the desert rarely rains, the north snows
    const fy = pl.y / TS / g.world.H, fx = pl.x / TS / g.world.W;
    const desert = fx > 0.6 && fy > 0.6;
    w.snow = fy < 0.22;
    w.nextT -= dt * g.clock.rate;
    if (w.nextT <= 0 || !w.target) {
      let nk = R.rng.weighted(WEATHER[w.kind].next);
      if (desert && (nk === 'rain' || nk === 'fog') && R.rng() < 0.7) nk = 'heat';
      this.setWeather(nk);
      if (g.started && nk !== 'clear' && nk !== 'cloudy') g.ui.toast(`Weather: ${this.WEATHER_NAMES[nk]}${w.snow && (nk === 'rain' || nk === 'storm') ? ' (snow up north)' : ''}.`);
    }
    const tg = w.target;
    const k = Math.min(1, dt * 0.15);
    w.rain += (tg.rain * (desert ? 0.4 : 1) - w.rain) * k;
    w.fog += (tg.fog - w.fog) * k;
    w.cloud += (tg.cloud - w.cloud) * k;
    w.heat += ((w.kind === 'heat' ? 1 : 0) - w.heat) * k;
    w.dry = R.clamp(w.dry + dt * (w.rain > 0.2 ? -0.01 * w.rain : w.kind === 'heat' ? 0.004 : 0.0015), 0.05, 1);
    // lightning
    this.lightning = Math.max(0, this.lightning - dt * 3);
    if (w.kind === 'storm' && R.rng() < dt * 0.08) this.strike();
    // geysers
    for (const gz of this.geysers) {
      gz.t -= dt;
      for (let k2 = 0; k2 < 3; k2++) g.fx.water(gz.x, gz.y - 4);
      this.douse(gz.x, gz.y, 30, dt * 2);
      for (const a of g.actors.near(gz.x, gz.y, 14)) if (a.kind === 'h' && !a.dead && a.state !== 'flee' && R.rng() < 0.05) g.actors.say(a, R.dialog.line('wet', a));
    }
    this.geysers = this.geysers.filter((gz) => gz.t > 0);
    // fire tick
    this.fireT -= dt;
    if (this.fireT <= 0) {
      this.fireT = 0.2;
      this.tickFire(0.2);
    }
  };

  E.strike = function () {
    const g = this.game, pl = g.player;
    this.lightning = 1;
    g.audio.sfx('thunder');
    if (R.rng() < 0.45) {
      const a = R.rng() * 6.28, d = 60 + R.rng() * 240;
      const x = pl.x + Math.cos(a) * d, y = pl.y + Math.sin(a) * d;
      g.fx.bolt(x, y);
      const tx = (x / TS) | 0, ty = (y / TS) | 0;
      const o = g.world.o(tx, ty);
      if ((o === O.TREE || o === O.PINE || o === O.DEADTREE || this.weather.rain < 0.8) && R.rng() < 0.7) this.ignite(x, y, 0.6, null);
      g.actors.noise(x, y, TS * 12, 'blast', null);
      if (R.dist(x, y, pl.x, pl.y) < 20 && !pl.inCar) pl.hurt(40, null, 'blast');
    }
  };

  // ---------------------------------------------------------------- fire
  E.flammability = function (x, y) {
    const w = this.game.world;
    const i = w.idx(x, y);
    const t = w.tile[i];
    let f = D.flammableTile[t];
    if (D.flammableObj[w.obj[i]]) f = Math.max(f, 0.9);
    if (w.bid[i]) {
      const b = w.buildings[w.bid[i]];
      f = Math.max(f, (D.btypes[b.type].fl || 0.5) * 0.35);
    }
    if (this.gas.has(i)) f = 3;
    return f;
  };
  E.ignite = function (x, y, radiusTiles, owner) {
    const w = this.game.world;
    const tx = (x / TS) | 0, ty = (y / TS) | 0;
    const r = Math.max(0.5, radiusTiles);
    for (let yy = Math.floor(ty - r); yy <= Math.ceil(ty + r); yy++)
      for (let xx = Math.floor(tx - r); xx <= Math.ceil(tx + r); xx++) {
        if (!w.inb(xx, yy) || R.dist(xx, yy, tx, ty) > r) continue;
        const fl = this.flammability(xx, yy);
        if (fl <= 0.02 && !this.gas.has(w.idx(xx, yy))) {
          // even pavement burns briefly from a molotov
          this.addFire(xx, yy, 0.35, owner);
        } else this.addFire(xx, yy, 1.2 + fl * 3, owner);
      }
  };
  E.addFire = function (x, y, fuel, owner) {
    const w = this.game.world;
    if (!w.inb(x, y) || w.isWater(x, y)) return;
    const i = w.idx(x, y);
    if (this.fires.has(i)) return;
    if (this.fires.size > 500) return;
    this.fires.set(i, { i: 0.3, fuel, owner, x, y });
    const b = w.buildingAt(x, y);
    if (b && !b.burning) {
      b.burning = 1;
      this.evacuate(b);
      if (owner === this.game.player && !b.arsonLogged) {
        b.arsonLogged = true;
        this.game.law.crime('arson', x * TS, y * TS, {});
        R.bus.emit('building:torched', b);
      }
    }
  };
  E.tickFire = function (dt) {
    const g = this.game, w = g.world, we = this.weather;
    if (!this.fires.size) return;
    const add = [];
    const rainKill = we.rain * 0.35;
    for (const [i, f] of this.fires) {
      f.i = Math.min(1, f.i + dt * 0.8);
      f.fuel -= dt * (0.5 + rainKill * 2);
      if (R.rng() < rainKill * dt) f.fuel -= 1;
      // spread
      if (f.i > 0.5) {
        for (let dy = -1; dy <= 1; dy++)
          for (let dx = -1; dx <= 1; dx++) {
            if (!dx && !dy) continue;
            const nx = f.x + dx, ny = f.y + dy;
            if (!w.inb(nx, ny)) continue;
            const ni = w.idx(nx, ny);
            if (this.fires.has(ni)) continue;
            const fl = this.flammability(nx, ny);
            if (fl <= 0) continue;
            const windAlign = 1 + (dx * we.wind.x + dy * we.wind.y) * 1.5;
            const p = fl * 0.1 * we.dry * 2 * Math.max(0.1, windAlign) * (1 - we.rain * 0.9) * dt * 1.6;
            if (R.rng() < p) add.push([nx, ny, 1.5 + fl * 3]);
          }
      }
      // damage what's here
      const b = w.bid[i] ? w.buildings[w.bid[i]] : null;
      if (b) {
        // scaled to the footprint so a big store blazes for a good half-minute instead of
        // collapsing before the flames even show
        b.hp -= dt * 2.2 * f.i * Math.min(1, 10 / (b.w * b.h));
        if (b.hp <= 0 && !b.destroyed) {
          w.destroyBuilding(b);
          g.pop.addNews(b.cityId, `${b.name} burned to the ground.`);
          if (b.city && !b.city.rural) b.city.prosperity = Math.max(0, b.city.prosperity - 4);
        }
        if (f.fuel <= 0 && !b.destroyed) f.fuel = 1; // buildings burn until gone or doused
      }
      if (f.fuel <= 0) {
        this.fires.delete(i);
        const t = w.tile[i], o = w.obj[i];
        if (t === T.GRASS || t === T.FOREST || t === T.FIELD || t === T.PARK || t === T.LOT || t === T.MARSH) w.setT(f.x, f.y, T.BURNT);
        if (o === O.TREE || o === O.PINE || o === O.PALM) w.setO(f.x, f.y, O.DEADTREE);
        else if (D.flammableObj[o]) w.setO(f.x, f.y, 0);
        this.gas.delete(i);
        if (w.bid[i]) { const bb = w.buildings[w.bid[i]]; if (bb) bb.burning = 0; }
      }
    }
    for (const [x, y, fuel] of add) this.addFire(x, y, fuel, null);
    // hurt things in the flames
    const pl = g.player;
    const pi = w.idx((pl.x / TS) | 0, (pl.y / TS) | 0);
    if (!pl.inside && this.fires.has(pi) && this.fires.get(pi).i > 0.4) {
      if (pl.inCar) g.traffic.damage(pl.inCar, 4, null);
      else pl.hurt(6, null, 'fire');
    }
    for (const a of g.actors.list) {
      if (a.dead || a.inCar) continue;
      const ai = w.idx((a.x / TS) | 0, (a.y / TS) | 0);
      if (this.fires.has(ai)) {
        if (a.kind === 'h') { a.burning = Math.max(a.burning || 0, 2); a.lastHitBy = this.fires.get(ai).owner || a.lastHitBy; }
        else R.combat.damage(a, 5, null, 'fire');
      } else if (a.kind === 'h' && !a.cop && a.state !== 'flee' && a.tag !== 'fireman' && R.rng() < 0.08) {
        // flee from nearby flames
        for (let k = 0; k < 3; k++) {
          const tx = ((a.x / TS) | 0) + R.rng.int(-3, 3), ty = ((a.y / TS) | 0) + R.rng.int(-3, 3);
          if (this.fires.has(w.idx(tx, ty))) {
            g.actors.setFlee(a, { x: tx * TS, y: ty * TS }, 6);
            if (R.rng() < 0.3) g.actors.say(a, R.dialog.line('fire', a));
            break;
          }
        }
      }
    }
    for (const v of g.traffic.list) {
      if (v.wrecked) continue;
      const vi = w.idx((v.x / TS) | 0, (v.y / TS) | 0);
      if (this.fires.has(vi) && v.burning <= 0) v.burning = 0.01;
    }
    // call the fire department in town
    this.fireDispatchT -= dt;
    if (this.fireDispatchT <= 0 && this.fires.size > 3) {
      this.fireDispatchT = 30;
      let any = null;
      for (const f of this.fires.values()) { if (w.cityAt(f.x, f.y)) { any = f; break; } }
      if (any) this.dispatchFire(any);
    }
  };
  E.douse = function (x, y, radius, amt) {
    const w = this.game.world;
    const tx = (x / TS) | 0, ty = (y / TS) | 0, r = Math.ceil(radius / TS);
    for (let yy = ty - r; yy <= ty + r; yy++)
      for (let xx = tx - r; xx <= tx + r; xx++) {
        const i = w.idx(xx, yy);
        const f = this.fires.get(i);
        if (f) { f.fuel -= amt; f.i = Math.max(0.05, f.i - amt * 0.3); if (f.fuel <= 0) f.fuel = 0; }
        this.gas.delete(i);
      }
  };
  E.evacuate = function (b) {
    const g = this.game;
    const inside = g.life.occupants(b);
    let n = 0;
    for (const p of inside) {
      if (n++ > 8) break;
      const h = g.life.spawnPerson(p, b.out.x * TS + 8 + (R.rng() - 0.5) * 10, b.out.y * TS + 8);
      if (h) { g.actors.setFlee(h, { x: b.door.x * TS + 8, y: b.door.y * TS + 8 }, 8); g.actors.say(h, R.dialog.line('fire', h)); }
    }
  };
  E.dispatchFire = function (f) {
    const g = this.game, w = g.world;
    if (g.traffic.list.some((v) => v.modelId === 'firetruck' && !v.removed && v.keep)) return;
    const s = w.findNear(f.x, f.y, 18, 30, (x, y) => w.flow[w.idx(x, y)] && !g.cam.onScreen(x * TS, y * TS, 20));
    if (!s) return;
    const truck = g.traffic.make('firetruck', s.x * TS + 8, s.y * TS + 8, 0, { mode: 'chase', keep: true });
    truck.siren = true;
    const d = g.traffic.addDriver(truck, { tag: 'fireman' });
    d.look.top = '#c8a030'; d.look.hat = 'cap'; d.look.hatCol = '#c02020';
    truck.ai = {
      dest: { x: f.x * TS, y: f.y * TS }, stopNear: 60,
      onArrive: (tk) => {
        const crew = [tk.driver];
        g.traffic.exitVehicle(tk, tk.driver);
        const h2 = g.actors.makeHuman(tk.x + 10, tk.y + 10, { tag: 'fireman' });
        h2.look.top = '#c8a030'; h2.look.hat = 'cap'; h2.look.hatCol = '#c02020';
        crew.push(h2);
        for (const c of crew) { c.tag = 'fireman'; c.state = 'work'; c.timer = 40; c.keep = true; }
        tk.siren = false;
        setTimeout(() => { tk.keep = false; for (const c of crew) c.keep = false; }, 60000);
      },
    };
    g.ui.toast('Fire engine dispatched.');
  };
  E.fireman = function (h, dt) {
    const g = this.game, w = g.world;
    // walk to nearest fire, spray
    let best = null, bd = 1e9;
    for (const f of this.fires.values()) {
      const d = R.dist(h.x, h.y, f.x * TS + 8, f.y * TS + 8);
      if (d < bd) { bd = d; best = f; }
    }
    if (!best || bd > TS * 30) { h.timer = 0; return; }
    const fx = best.x * TS + 8, fy = best.y * TS + 8;
    const ang = Math.atan2(fy - h.y, fx - h.x);
    h.dir = R.dir4(Math.cos(ang), Math.sin(ang));
    if (bd > TS * 3) { g.actors.moveActor(h, Math.cos(ang) * 55, Math.sin(ang) * 55, dt); h.walk += dt * 18; }
    else {
      h.timer = Math.max(h.timer, 5);
      if (R.rng() < 0.7) g.fx.water(h.x + Math.cos(ang) * 10, h.y - 8 + Math.sin(ang) * 10, ang);
      this.douse(fx, fy, 22, dt * 3);
    }
  };

  // ---------------------------------------------------------------- gasoline
  E.pourGas = function (x, y) {
    const w = this.game.world;
    const tx = (x / TS) | 0, ty = (y / TS) | 0;
    const i = w.idx(tx, ty);
    if (w.isWater(tx, ty)) return false;
    this.gas.set(i, 1);
    return true;
  };
  E.gasAt = function (x, y) {
    const w = this.game.world;
    return this.gas.has(w.idx((x / TS) | 0, (y / TS) | 0));
  };

  E.geyser = function (x, y) {
    this.geysers.push({ x, y, t: 18 });
  };
  E.shootLamp = function (tx, ty) {
    const g = this.game;
    g.world.setO(tx, ty, 0);
    g.fx.sparks(tx * TS + 8, ty * TS + 2, 10);
    g.audio.sfx('glass', tx * TS, ty * TS);
  };
  E.damageBuilding = function (b, amt, owner) {
    if (b.destroyed) return;
    b.hp -= amt;
    if (b.hp < 55 && !b.burning && amt > 10 && R.rng() < 0.6) this.addFire(b.door.x, b.door.y, 3, owner);
    if (b.hp <= 0) this.addFire(b.x + (b.w >> 1), b.y + (b.h >> 1), 3, owner);
  };

  // is this spot lit (for night witnesses)?
  E.litAt = function (x, y) {
    const g = this.game, w = g.world;
    if (g.clock.darkness() < 0.35) return true;
    const tx = (x / TS) | 0, ty = (y / TS) | 0;
    for (let yy = ty - 3; yy <= ty + 3; yy++) for (let xx = tx - 3; xx <= tx + 3; xx++) if (w.o(xx, yy) === O.LAMP) return true;
    for (const f of this.fires.values()) if (Math.abs(f.x - tx) < 5 && Math.abs(f.y - ty) < 5) return true;
    return false;
  };

  // ---------------------------------------------------------------- camera
  R.Camera = function (game) {
    this.game = game;
    this.x = 0; this.y = 0;
    this.zoom = 2;
    this.sh = 0;
    this.vw = 400; this.vh = 800;
    this.ox = 0; this.oy = 0;
  };
  const CM = R.Camera.prototype;
  CM.shake = function (a) { this.sh = Math.max(this.sh, a); };
  CM.update = function (dt, tx, ty, lead) {
    const k = Math.min(1, dt * 6);
    this.x += (tx + (lead ? lead.x : 0) - this.x) * k;
    this.y += (ty + (lead ? lead.y : 0) - this.y) * k;
    this.sh = Math.max(0, this.sh - dt * 12);
    this.ox = (R.rng() - 0.5) * this.sh;
    this.oy = (R.rng() - 0.5) * this.sh;
  };
  CM.left = function () { return this.x - this.vw / 2 / this.zoom; };
  CM.top = function () { return this.y - this.vh / 2 / this.zoom; };
  CM.onScreen = function (x, y, m) {
    m = m || 0;
    const hw = this.vw / 2 / this.zoom + m, hh = this.vh / 2 / this.zoom + m;
    return Math.abs(x - this.x) < hw && Math.abs(y - this.y) < hh;
  };
  CM.toWorld = function (sx, sy) {
    return { x: this.left() + sx / this.zoom, y: this.top() + sy / this.zoom };
  };

  // ---------------------------------------------------------------- particles & floating text
  const FX = (R.FX = function (game) {
    this.game = game;
    this.p = [];
    this.texts = [];
    this.tracers = [];
    this.decals = [];
    this.flashes = [];
    this.bolts = [];
  });
  const FP = FX.prototype;
  FP.add = function (o) {
    if (this.p.length > 900) this.p.shift();
    this.p.push(o);
  };
  // ---- gore: blood flies, lands and stains; bodies bleed out into growing pools
  const gore = (fx) => fx.game.settings.gore !== false;
  const BLOODS = ['#8a1a14', '#a8201a', '#6a1410', '#b8302a'];
  FP.decal = function (d) {
    if (this.decals.length > 420) this.decals.shift();
    this.decals.push(d);
  };
  FP.blood = function (x, y, n) {
    if (!gore(this)) { for (let k = 0; k < Math.min(3, n); k++) this.add({ x, y, vx: (R.rng() - 0.5) * 50, vy: (R.rng() - 0.8) * 40, g: 160, life: 0.35, max: 0.35, c: '#c8b898', s: 1.5 }); return; }
    for (let k = 0; k < n; k++) this.add({ x, y, vx: (R.rng() - 0.5) * 70, vy: (R.rng() - 0.8) * 60, g: 180, life: 0.9, max: 0.9, c: R.rng.pick(BLOODS), s: R.rng() < 0.3 ? 2 : 1, floor: y + 8 + R.rng() * 4, stain: 1 });
    this.decal({ x: x + (R.rng() - 0.5) * 6, y: y + 8, r: 1.5 + R.rng() * 2, c: 'rgba(110,20,16,0.6)', t: 500 });
  };
  // arterial spray away from the shooter
  FP.spray = function (x, y, ang, n) {
    if (!gore(this)) return;
    for (let k = 0; k < n; k++) {
      const a = ang + (R.rng() - 0.5) * 0.7, sp = 60 + R.rng() * 110;
      this.add({ x, y, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - 30, g: 200, life: 1, max: 1, c: R.rng.pick(BLOODS), s: R.rng() < 0.4 ? 2 : 1, floor: y + 10 + Math.sin(a) * 10 + R.rng() * 6, stain: 1 });
    }
  };
  FP.pool = function (x, y) {
    if (!gore(this)) return;
    this.decal({ x, y: y - 2, r: 2, grow: 9 + R.rng() * 4, rate: 1.6, c: 'rgba(96,14,12,0.62)', t: 900 });
  };
  FP.gib = function (x, y, look) {
    if (!gore(this)) return this.boom && this.smoke(x, y, true);
    const cols = ['#7a1410', '#a8201a', '#5a0c0c', (look && look.top) || '#3a3a4a', (look && look.skin) || '#d8a070'];
    for (let k = 0; k < 16; k++) {
      const a = R.rng() * 6.28, sp = 40 + R.rng() * 140;
      this.add({ x, y: y - 8, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - 60, g: 260, life: 1.4, max: 1.4, c: cols[k % cols.length], s: 2 + (k % 3), floor: y + (R.rng() - 0.5) * 20, stain: 1 });
    }
    this.spray(x, y - 8, -Math.PI / 2, 14);
    this.decal({ x, y, r: 4, grow: 12, rate: 3, c: 'rgba(90,12,10,0.6)', t: 900 });
  };
  FP.hit = function (x, y) { for (let k = 0; k < 4; k++) this.add({ x, y, vx: (R.rng() - 0.5) * 80, vy: (R.rng() - 0.5) * 80, life: 0.15, max: 0.15, c: '#f2e2c0', s: 2 }); };
  FP.sparks = function (x, y, n) { for (let k = 0; k < n; k++) this.add({ x, y, vx: (R.rng() - 0.5) * 140, vy: (R.rng() - 0.7) * 120, g: 200, life: 0.35, max: 0.35, c: R.rng() < 0.5 ? '#ffe070' : '#fff6c0', s: 1.5, glow: 1 }); };
  FP.spark1 = function (x, y) { this.add({ x, y, vx: (R.rng() - 0.5) * 40, vy: -30 - R.rng() * 30, g: 100, life: 0.3, max: 0.3, c: '#ffd040', s: 1.5, glow: 1 }); };
  FP.flash = function (x, y) { this.flashes.push({ x, y, t: 0.06 }); };
  FP.tracer = function (x1, y1, x2, y2) { this.tracers.push({ x1, y1, x2, y2, t: 0.08 }); };
  FP.smoke = function (x, y, black) { this.add({ x, y, vx: (R.rng() - 0.5) * 10 + this.game.env.weather.wind.x * 15, vy: -18 - R.rng() * 10, life: 2.2, max: 2.2, c: black ? 'rgba(30,26,24,0.55)' : 'rgba(160,150,140,0.4)', s: 4, grow: 5 }); };
  FP.flame = function (x, y) { this.add({ x: x + (R.rng() - 0.5) * 8, y, vx: (R.rng() - 0.5) * 12, vy: -30 - R.rng() * 20, life: 0.5, max: 0.5, c: R.rng() < 0.5 ? '#ff9a20' : '#ffd040', s: 3, glow: 1, shrink: 1 }); };
  FP.water = function (x, y, ang) {
    const a = ang !== undefined ? ang + (R.rng() - 0.5) * 0.4 : -Math.PI / 2 + (R.rng() - 0.5) * 0.6;
    const sp = 80 + R.rng() * 60;
    this.add({ x, y, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp, g: 220, life: 0.7, max: 0.7, c: 'rgba(170,210,235,0.8)', s: 2, floor: y + 16 });
  };
  FP.debris = function (x, y, o) {
    const c = o === O.HYDRANT ? '#c83a1a' : o === O.LAMP ? '#3a3a3a' : o === O.MAILBOX ? '#2a4a8a' : o === O.BUSH || o === O.FLOWERS || o === O.REED ? '#5e7034' : o === O.CONE ? '#e46a1a' : '#7a5a3a';
    for (let k = 0; k < 7; k++) this.add({ x, y, vx: (R.rng() - 0.5) * 120, vy: (R.rng() - 0.7) * 100, g: 220, life: 0.8, max: 0.8, c, s: 2, floor: y + 8 });
  };
  FP.shatter = function (x, y) { for (let k = 0; k < 10; k++) this.add({ x, y, vx: (R.rng() - 0.5) * 100, vy: (R.rng() - 0.7) * 80, g: 200, life: 0.5, max: 0.5, c: '#a8d0c0', s: 1.5 }); };
  FP.boom = function (x, y, r) {
    for (let k = 0; k < 40; k++) {
      const a = R.rng() * 6.28, s = R.rng() * r * 3;
      this.add({ x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s - 30, life: 0.6 + R.rng() * 0.4, max: 1, c: R.rng() < 0.4 ? '#ffd040' : R.rng() < 0.5 ? '#ff7a20' : '#fff0c0', s: 4, glow: 1, shrink: 1 });
    }
    for (let k = 0; k < 14; k++) this.smoke(x + (R.rng() - 0.5) * r, y + (R.rng() - 0.5) * r * 0.5, true);
    this.flashes.push({ x, y, t: 0.18, big: r });
    this.decals.push({ x, y, r: r * 0.45, c: 'rgba(20,16,14,0.55)', t: 800 });
  };
  FP.bolt = function (x, y) { this.bolts.push({ x, y, t: 0.25, seed: R.rng() }); };
  FP.note = function (x, y) { this.texts.push({ x: x + (R.rng() - 0.5) * 10, y, t: 1.6, max: 1.6, s: R.rng() < 0.5 ? '♪' : '♫', c: '#e4a92a', vy: -16 }); };
  FP.text = function (x, y, s, c) { this.texts.push({ x, y, t: 1.2, max: 1.2, s, c: c || '#f2e2c0', vy: -20 }); };
  FP.money = function (x, y, amt) { this.text(x, y, '+' + R.fmtMoney(amt), '#9ad070'); };

  FP.update = function (dt) {
    for (const p of this.p) {
      p.life -= dt;
      p.vy += (p.g || 0) * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      if (p.floor && p.y > p.floor) {
        p.y = p.floor; p.vx *= 0.5; p.vy = 0;
        if (p.stain) { this.decal({ x: p.x, y: p.y, sq: Math.max(1, p.s), c: p.c, t: 600 }); p.life = 0; }
      }
      if (p.grow) p.s += p.grow * dt;
    }
    this.p = this.p.filter((p) => p.life > 0);
    for (const t of this.texts) { t.t -= dt; t.y += t.vy * dt; }
    this.texts = this.texts.filter((t) => t.t > 0);
    for (const t of this.tracers) t.t -= dt;
    this.tracers = this.tracers.filter((t) => t.t > 0);
    for (const f of this.flashes) f.t -= dt;
    this.flashes = this.flashes.filter((f) => f.t > 0);
    for (const b of this.bolts) b.t -= dt;
    this.bolts = this.bolts.filter((b) => b.t > 0);
    for (const d of this.decals) { d.t -= dt; if (d.grow && d.r < d.grow) d.r = Math.min(d.grow, d.r + d.rate * dt); }
    this.decals = this.decals.filter((d) => d.t > 0);
    if (this.decals.length > 480) this.decals.splice(0, this.decals.length - 480);
  };
  FP.drawDecals = function (g) {
    for (const d of this.decals) {
      g.fillStyle = d.c;
      if (d.sq) { g.globalAlpha = Math.min(1, d.t / 60); g.fillRect(Math.round(d.x), Math.round(d.y), d.sq, d.sq); g.globalAlpha = 1; continue; }
      g.beginPath();
      g.ellipse(d.x, d.y, d.r, d.r * 0.6, 0, 0, 7);
      g.fill();
    }
  };
  FP.draw = function (g) {
    for (const p of this.p) {
      g.globalAlpha = Math.max(0, Math.min(1, p.life / p.max * 1.5));
      g.fillStyle = p.c;
      const s = p.shrink ? p.s * (p.life / p.max) : p.s;
      g.fillRect(p.x - s / 2, p.y - s / 2, s, s);
    }
    g.globalAlpha = 1;
    g.lineWidth = 1;
    for (const t of this.tracers) {
      g.strokeStyle = `rgba(255,240,180,${t.t / 0.08})`;
      g.beginPath(); g.moveTo(t.x1, t.y1); g.lineTo(t.x2, t.y2); g.stroke();
    }
    for (const f of this.flashes) {
      g.fillStyle = f.big ? `rgba(255,230,160,${f.t * 3})` : '#fff4b0';
      g.beginPath(); g.arc(f.x, f.y, f.big ? f.big * 0.8 : 4, 0, 7); g.fill();
    }
    for (const b of this.bolts) {
      const rnd = R.mulberry((b.seed * 1e6) | 0);
      g.strokeStyle = `rgba(230,240,255,${b.t * 4})`;
      g.lineWidth = 2;
      g.beginPath();
      let x = b.x + (rnd() - 0.5) * 40, y = b.y - 220;
      g.moveTo(x, y);
      while (y < b.y) { y += 20; x += (rnd() - 0.5) * 24; g.lineTo(y >= b.y ? b.x : x, Math.min(y, b.y)); }
      g.stroke();
    }
    g.textAlign = 'center';
    for (const t of this.texts) {
      g.globalAlpha = Math.min(1, t.t / t.max * 2);
      if (t.s === '♪' || t.s === '♫') { g.fillStyle = t.c; g.fillRect(Math.round(t.x), Math.round(t.y) - 4, 1, 5); g.fillRect(Math.round(t.x) - 2, Math.round(t.y), 3, 2); g.fillRect(Math.round(t.x), Math.round(t.y) - 4, 3, 1); continue; }
      R.art.ptext(g, String(t.s).toUpperCase(), t.x, t.y - 8, { align: 'center', color: t.c, shadow: '#1b1410' });
    }
    g.globalAlpha = 1;
  };
})();
