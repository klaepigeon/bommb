// RHAPSODY — vehicles: lane-following civilian traffic with signals and yielding,
// arcade handling with drift for the player, chase steering for police/EMS,
// collisions, road rage and ambient pursuits.
'use strict';
(function () {
  const D = R.data, T = D.T, F = R.FLOW, TS = R.TILE;
  const DIRA = [-Math.PI / 2, 0, Math.PI / 2, Math.PI];

  const Traffic = (R.Traffic = function (game) {
    this.game = game;
    this.list = [];
    this.hash = new R.SpatialHash(64);
    this.timer = 0;
    this.lightT = 0;
  });
  const TP = Traffic.prototype;

  TP.make = function (modelId, x, y, angle, opts) {
    opts = opts || {};
    const m = D.vehicles[modelId];
    const v = {
      kind: 'v', modelId, model: m, x, y, angle, speed: 0, vx: 0, vy: 0, color: opts.color || R.rng.pick(m.colors),
      hp: m.hp, maxHp: m.hp, driver: null, ai: opts.ai || null, lights: false, siren: false, braking: false, wrecked: false,
      burning: 0, parked: !!opts.parked, locked: opts.locked !== undefined ? opts.locked : R.rng.chance(0.4), owner: opts.owner || null,
      honkT: 0, wait: 0, variant: R.rng.chance(0.5), id: 0, r: m.w * 0.42, mode: opts.mode || 'lane', radio: R.rng.int(0, 2),
      stolen: false, keep: !!opts.keep,
    };
    v.id = ++this.nid || (this.nid = 1);
    this.list.push(v);
    return v;
  };
  TP.remove = function (v) {
    v.removed = true;
    if (v.driver && v.driver !== this.game.player) {
      this.game.actors.remove(v.driver);
    }
    for (const p of v.passengers || []) this.game.actors.remove(p);
  };

  TP.addDriver = function (v, opts) {
    const h = this.game.actors.makeHuman(v.x, v.y, Object.assign({ tag: 'driver' }, opts || {}));
    h.inCar = v;
    h.state = 'drive';
    v.driver = h;
    return h;
  };

  // ------------------------------------------------ update
  TP.update = function (dt) {
    const game = this.game;
    // traffic lights
    for (const it of game.world.inters) {
      if (!it.light) continue;
      it.timer += dt;
      const len = it.phase % 2 === 0 ? 9 : 2;
      if (it.timer > len) { it.timer = 0; it.phase = (it.phase + 1) % 4; }
    }
    this.hash.clear();
    for (const v of this.list) if (!v.removed) this.hash.insert(v);
    for (const v of this.list) {
      if (v.removed) continue;
      if (v.driver === game.player) this.playerDrive(v, dt);
      else if (v.driver && !v.driver.dead && !v.wrecked) {
        if (v.mode === 'lane') this.laneDrive(v, dt);
        else this.chaseDrive(v, dt);
      } else this.coast(v, dt);
      if (v.driver && v.driver !== game.player) { v.driver.x = v.x; v.driver.y = v.y; }
      for (const p of v.passengers || []) { p.x = v.x; p.y = v.y; }
      this.collide(v, dt);
      if (v.burning > 0) this.burn(v, dt);
      v.lights = game.clock.isNight() || game.env.weather.rain > 0.5 || game.env.weather.fog > 0.4;
      if (v.honkT > 0) v.honkT -= dt;
    }
    this.list = this.list.filter((v) => !v.removed);
    this.timer -= dt;
    if (this.timer <= 0) {
      this.timer = 0.6;
      this.manage();
    }
  };

  // ------------------------------------------------ lane following
  TP.laneDrive = function (v, dt) {
    const w = this.game.world, ai = v.ai;
    const tcx = ai.tx * TS + 8, tcy = ai.ty * TS + 8;
    // Next tile center target
    const [dx, dy] = R.DIRS[ai.dir];
    let nx = ai.tx + dx, ny = ai.ty + dy;
    const tgx = nx * TS + 8, tgy = ny * TS + 8;
    const road = w.t(ai.tx, ai.ty);
    const hwy = road === T.HWY || road === T.BRIDGE;
    let want = v.model.top * (hwy ? 0.78 : 0.48) * (ai.reckless ? 1.6 : 1) * (this.game.env.weather.rain > 0.5 ? 0.85 : 1);
    // obstacle ahead
    const obst = this.obstacleAhead(v);
    if (obst) {
      const d = obst.d;
      want = d < v.model.w * 0.5 + 6 ? 0 : Math.min(want, (d - v.model.w * 0.5) * 2.2);
      if (v.speed < 5) {
        v.wait += dt;
        if ((obst.player || obst.o.driver === this.game.player) && v.wait > 1.8 && v.honkT <= 0) this.honk(v);
        if (v.wait > 7 && obst.o.kind === 'v' && !obst.o.driver) this.goAround(v);
        if (v.wait > 5 && obst.player && v.driver && v.driver.tr.brave > 0.7 && !v.driver.raged) this.roadRage(v);
      }
    } else v.wait = Math.max(0, v.wait - dt);
    // light / yield before entering intersection
    if (ai.hold) {
      want = 0;
      if (this.canEnter(v, nx, ny)) ai.hold = false;
    }
    v.braking = want < v.speed - 5;
    v.speed = R.approach(v.speed, want, (want > v.speed ? v.model.acc * 0.6 : 260) * dt);
    // move towards target
    const dist = R.dist(v.x, v.y, tgx, tgy);
    const step = v.speed * dt;
    if (dist <= step + 0.5 || dist < 1) {
      v.x = tgx; v.y = tgy;
      ai.tx = nx; ai.ty = ny;
      this.decide(v);
    } else {
      v.x += ((tgx - v.x) / dist) * step;
      v.y += ((tgy - v.y) / dist) * step;
    }
    const heading = Math.atan2(tgy - v.y, tgx - v.x);
    if (dist > 0.5) v.angle += R.angDiff(v.angle, heading) * Math.min(1, dt * 10);
    // lost the road (knocked off): switch to coasting
    if (!w.flow[w.idx(ai.tx, ai.ty)]) { v.mode = 'chase'; ai.wanderT = 3; }
  };
  TP.decide = function (v) {
    const w = this.game.world, ai = v.ai;
    const f = w.flow[w.idx(ai.tx, ai.ty)];
    const inX = !!(f & F.X);
    if (!inX) ai.turned = false;
    const valid = [];
    for (let d = 0; d < 4; d++) {
      if (d === (ai.dir + 2) % 4) continue;
      if (!(f & R.DIRBIT[d])) continue;
      const nx = ai.tx + R.DIRS[d][0], ny = ai.ty + R.DIRS[d][1];
      if (!w.inb(nx, ny)) continue;
      if (!(w.flow[w.idx(nx, ny)] & R.DIRBIT[d])) continue;
      valid.push(d);
    }
    let nd;
    if (!valid.length) {
      // dead end: u-turn into the opposite lane
      nd = (ai.dir + 2) % 4;
      const side = R.DIRS[(ai.dir + 3) % 4]; // left of travel
      const lx = ai.tx + side[0], ly = ai.ty + side[1];
      if (w.flow[w.idx(lx, ly)] & R.DIRBIT[nd]) { ai.tx = lx; ai.ty = ly; }
      else { v.mode = 'chase'; ai.wanderT = 2; return; }
    } else if (inX && ai.turned) nd = valid.includes(ai.dir) ? ai.dir : valid[0];
    else {
      const opts = valid.map((d) => [d, d === ai.dir ? 3 : 1]);
      nd = R.rng.weighted(opts);
    }
    if (nd !== ai.dir && inX) ai.turned = true;
    ai.dir = nd;
    // entering an intersection?
    const nx = ai.tx + R.DIRS[nd][0], ny = ai.ty + R.DIRS[nd][1];
    if (!inX && w.flow[w.idx(nx, ny)] & F.X) ai.hold = !this.canEnter(v, nx, ny);
  };
  TP.canEnter = function (v, nx, ny) {
    const w = this.game.world;
    const it = w.interAt.get(w.idx(nx, ny));
    if (!it) return true;
    if (v.ai.reckless) return true;
    if (it.light) {
      const ew = v.ai.dir === 1 || v.ai.dir === 3;
      if (ew ? it.phase !== 0 : it.phase !== 2) return false;
    }
    // occupied by a crossing vehicle?
    const cx = it.cx * TS + 16, cy = it.cy * TS + 16;
    for (const o of this.hash.query(cx, cy, 30)) {
      if (o === v || o.removed) continue;
      if (o.speed > 8 && o.ai && ((o.ai.dir & 1) !== (v.ai.dir & 1))) return false;
    }
    return true;
  };
  TP.obstacleAhead = function (v) {
    const fx = Math.cos(v.angle), fy = Math.sin(v.angle);
    const reach = v.model.w * 0.5 + 10 + v.speed * 0.45;
    let best = null;
    const test = (o, isPlayer) => {
      const rx = o.x - v.x, ry = o.y - v.y;
      const along = rx * fx + ry * fy;
      const lat = Math.abs(-rx * fy + ry * fx);
      const lw = o.kind === 'v' ? o.model.h * 0.5 + 5 : 7;
      if (along > 0 && along < reach + (o.kind === 'v' ? o.model.w * 0.5 : 0) && lat < lw) {
        const d = along - (o.kind === 'v' ? o.model.w * 0.5 : 0);
        if (!best || d < best.d) best = { d, o, player: isPlayer };
      }
    };
    for (const o of this.hash.query(v.x, v.y, reach + 30)) if (o !== v && !o.removed) test(o, false);
    for (const h of this.game.actors.near(v.x + fx * reach * 0.5, v.y + fy * reach * 0.5, reach * 0.6 + 8)) {
      if (h.kind === 'h' && !h.inCar && !h.dead) test(h, false);
      if (h.kind === 'a' && !h.dead && !h.flying) test(h, false);
    }
    const pl = this.game.player;
    if (!pl.inCar && !pl.inside) test(pl, true);
    return best;
  };
  TP.honk = function (v) {
    v.honkT = 2.5;
    this.game.fx.text(v.x, v.y - 14, 'HONK!', '#e4a92a');
    this.game.audio.sfx('horn', v.x, v.y);
    if (v.driver && R.rng() < 0.5) this.game.actors.say(v.driver, R.dialog.line('driverYell', v.driver));
  };
  TP.goAround = function (v) {
    v.mode = 'chase';
    v.ai.wanderT = 2.5;
    v.wait = 0;
  };
  TP.roadRage = function (v) {
    const h = v.driver;
    h.raged = true;
    this.exitVehicle(v, h);
    this.game.actors.say(h, R.dialog.line('roadRage', h));
    h.state = 'follow';
    h.hurry = true;
    h.timer = 10;
    h.onReach = (m) => {
      m.state = 'talk';
      m.timer = 4;
      m.anger = 60;
      this.game.ui.focusOn(m);
    };
  };

  // ------------------------------------------------ arcade steering (player + chasers)
  TP.physics = function (v, dt, throttle, steerTo, brake, handbrake) {
    const m = v.model;
    const fx = Math.cos(v.angle), fy = Math.sin(v.angle);
    let fwd = v.vx * fx + v.vy * fy;
    let lat = -v.vx * fy + v.vy * fx;
    // steering: rotate towards steerTo, rate limited by speed
    if (steerTo !== null) {
      const diff = R.angDiff(v.angle, steerTo);
      const rate = 3.2 * R.clamp(Math.abs(fwd) / 70, 0.15, 1) * (handbrake ? 1.5 : 1);
      const dir = fwd < -5 ? -1 : 1;
      v.angle += R.clamp(diff, -rate * dt, rate * dt) * (dir < 0 ? 1 : 1);
    }
    const top = m.top * (this.game.player.inCar === v ? 1.15 : 1);
    if (throttle > 0) fwd += m.acc * throttle * dt * (fwd < 0 ? 2.5 : 1);
    else if (throttle < 0) fwd += m.acc * throttle * 0.7 * dt * (fwd > 0 ? 2.5 : 1);
    if (brake) fwd = R.approach(fwd, 0, 380 * dt);
    fwd = R.clamp(fwd, -top * 0.45, top);
    // drag
    fwd *= 1 - dt * (throttle ? 0.25 : 0.9);
    const grip = handbrake ? 1.4 : this.game.env.weather.rain > 0.4 ? 5 : 8.5;
    lat = R.approach(lat, 0, Math.abs(lat) * grip * dt + 20 * dt);
    const nfx = Math.cos(v.angle), nfy = Math.sin(v.angle);
    v.vx = nfx * fwd - nfy * lat;
    v.vy = nfy * fwd + nfx * lat;
    v.speed = Math.hypot(v.vx, v.vy) * (fwd < 0 ? -1 : 1);
    v.drift = Math.abs(lat) > 60;
    v.braking = brake || (throttle < 0 && fwd > 0);
    this.integrate(v, dt);
  };
  TP.integrate = function (v, dt) {
    const w = this.game.world;
    const nx = v.x + v.vx * dt, ny = v.y + v.vy * dt;
    const hit = this.worldHit(v, nx, ny);
    if (!hit) {
      v.x = nx; v.y = ny;
    } else {
      const impact = Math.hypot(v.vx, v.vy);
      // try sliding along an axis
      if (!this.worldHit(v, nx, v.y)) { v.x = nx; v.vy *= -0.2; }
      else if (!this.worldHit(v, v.x, ny)) { v.y = ny; v.vx *= -0.2; }
      else { v.vx *= -0.3; v.vy *= -0.3; }
      if (impact > 70) {
        this.damage(v, (impact - 60) * 0.18, null);
        this.game.fx.sparks(v.x + Math.cos(v.angle) * v.model.w * 0.5, v.y + Math.sin(v.angle) * v.model.w * 0.5, 6);
        this.game.audio.sfx('crash', v.x, v.y);
        if (v.driver === this.game.player) this.game.cam.shake(Math.min(6, impact / 40));
      }
    }
    // knock over small street furniture (never a crime on its own)
    const tx = (v.x / TS) | 0, ty = (v.y / TS) | 0;
    for (let yy = ty - 1; yy <= ty + 1; yy++)
      for (let xx = tx - 1; xx <= tx + 1; xx++) {
        const o = w.o(xx, yy);
        if (!o || !D.smallObj[o] && o !== D.O.CONE && o !== D.O.BUSH && o !== D.O.FLOWERS && o !== D.O.FENCE && o !== D.O.REED) continue;
        if (Math.abs(v.speed) < 25) continue;
        const ox = xx * TS + 8, oy = yy * TS + 8;
        if (R.dist(ox, oy, v.x, v.y) < v.model.w * 0.5) {
          w.setO(xx, yy, 0);
          this.game.fx.debris(ox, oy, o);
          if (o === D.O.HYDRANT) this.game.env.geyser(ox, oy);
          v.vx *= 0.85; v.vy *= 0.85;
          this.game.audio.sfx('bump', ox, oy);
        }
      }
  };
  TP.worldHit = function (v, x, y) {
    const w = this.game.world;
    const c = Math.cos(v.angle), s = Math.sin(v.angle);
    const hl = v.model.w * 0.5 - 1, hw = v.model.h * 0.5 - 1;
    const pts = [[hl, hw], [hl, -hw], [-hl, hw], [-hl, -hw], [hl, 0], [-hl, 0]];
    for (const [a, b] of pts) {
      const px = x + a * c - b * s, py = y + a * s + b * c;
      if (w.solidCar((px / TS) | 0, (py / TS) | 0)) return true;
    }
    return false;
  };

  TP.playerDrive = function (v, dt) {
    const inp = this.game.input;
    const st = inp.stick;
    const mag = Math.min(1, Math.hypot(st.x, st.y));
    let throttle = 0, steer = null;
    if (mag > 0.15) {
      const want = Math.atan2(st.y, st.x);
      const diff = Math.abs(R.angDiff(v.angle, want));
      const fwd = v.vx * Math.cos(v.angle) + v.vy * Math.sin(v.angle);
      if (diff > 2.4 && fwd < 40) {
        throttle = -mag; // reverse
        steer = want + Math.PI;
      } else {
        throttle = mag * (diff > 1.6 ? 0.4 : 1);
        steer = want;
      }
    }
    const brake = inp.held('brake');
    this.physics(v, dt, throttle, steer, brake && Math.abs(v.speed) > 30 ? false : brake, brake && Math.abs(v.speed) > 30);
    if (inp.pressed('horn')) this.honkPlayer(v);
  };
  TP.honkPlayer = function (v) {
    this.game.audio.sfx('horn', v.x, v.y);
    this.game.fx.text(v.x, v.y - 14, 'HONK!', '#e4a92a');
    // peds in front jump out of the way; drivers ahead get annoyed
    for (const h of this.game.actors.near(v.x, v.y, 60)) {
      if (h.kind === 'h' && !h.inCar && !h.dead && h.state !== 'fight') {
        this.game.actors.setFlee(h, v, 1.2);
        if (R.rng() < 0.3) this.game.actors.say(h, R.dialog.line('honkedAt', h));
      }
    }
  };

  // Steering for police / EMS / reckless drivers: arcade physics towards a target with ray avoidance.
  TP.chaseDrive = function (v, dt) {
    const game = this.game, w = game.world, ai = v.ai || (v.ai = {});
    let tx, ty;
    if (ai.target) {
      const t = ai.target.inCar || ai.target;
      tx = t.x; ty = t.y;
    } else if (ai.dest) { tx = ai.dest.x; ty = ai.dest.y; }
    else {
      // wander: try to snap back onto a lane
      ai.wanderT = (ai.wanderT || 0) - dt;
      const t = ((v.x / TS) | 0), u = ((v.y / TS) | 0);
      const f = w.flow[w.idx(t, u)];
      if (ai.wanderT <= 0 && f && !(f & F.X)) {
        for (let d = 0; d < 4; d++) if (f & R.DIRBIT[d] && Math.abs(R.angDiff(v.angle, DIRA[d])) < 1.2) {
          v.mode = 'lane';
          ai.tx = t; ai.ty = u; ai.dir = d; ai.hold = false;
          v.speed = Math.max(0, v.vx * Math.cos(v.angle) + v.vy * Math.sin(v.angle));
          v.vx = v.vy = 0;
          return;
        }
      }
      tx = v.x + Math.cos(v.angle) * 80;
      ty = v.y + Math.sin(v.angle) * 80;
      if (ai.wanderT < -6) { v.mode = 'chase'; ai.dest = null; }
    }
    let want = Math.atan2(ty - v.y, tx - v.x);
    // ray avoidance
    const look = 30 + Math.abs(v.speed) * 0.35;
    const free = (ang) => {
      for (let k = 1; k <= 3; k++) {
        const px = v.x + Math.cos(ang) * look * (k / 3), py = v.y + Math.sin(ang) * look * (k / 3);
        if (w.solidCar((px / TS) | 0, (py / TS) | 0)) return k / 3 - 0.34;
      }
      return 1;
    };
    const cands = [0, 0.5, -0.5, 1.0, -1.0, 1.6, -1.6];
    let best = want, bs = -1e9;
    for (const c of cands) {
      const a = v.angle + c;
      const score = free(a) * 2 - Math.abs(R.angDiff(a, want)) * 0.6;
      if (score > bs) { bs = score; best = a; }
    }
    const d = R.dist(v.x, v.y, tx, ty);
    let throttle = d > 50 ? 1 : d / 60;
    if (ai.stopNear && d < ai.stopNear) throttle = 0;
    // stuck recovery
    ai.stuckT = Math.abs(v.speed) < 8 && throttle > 0.2 ? (ai.stuckT || 0) + dt : 0;
    if (ai.stuckT > 1.5) { ai.reverseT = 0.9; ai.stuckT = 0; }
    if (ai.reverseT > 0) { ai.reverseT -= dt; this.physics(v, dt, -0.8, best + Math.PI, false, false); return; }
    this.physics(v, dt, throttle, best, ai.stopNear && d < ai.stopNear, false);
    if (ai.onArrive && d < (ai.stopNear || 40) + 10) { const f = ai.onArrive; ai.onArrive = null; f(v); }
  };

  TP.coast = function (v, dt) {
    v.vx *= 1 - dt * 1.8;
    v.vy *= 1 - dt * 1.8;
    v.speed = Math.hypot(v.vx, v.vy);
    if (v.speed > 2) this.integrate(v, dt);
    v.braking = false;
  };

  // ------------------------------------------------ collisions car/car, car/ped
  TP.collide = function (v, dt) {
    const game = this.game;
    const sp = Math.hypot(v.vx, v.vy) || Math.abs(v.speed);
    for (const o of this.hash.query(v.x, v.y, v.model.w)) {
      if (o === v || o.removed || o.id < v.id) continue;
      const d = R.dist(v.x, v.y, o.x, o.y);
      const minD = (v.model.h + o.model.h) * 0.5 + Math.min(v.model.w, o.model.w) * 0.12;
      if (d < minD && d > 0.01) {
        const nx = (o.x - v.x) / d, ny = (o.y - v.y) / d;
        const push = (minD - d) * 0.5;
        const heavyV = v.model.hp > 200 ? 0.3 : 1, heavyO = o.model.hp > 200 ? 0.3 : 1;
        v.x -= nx * push * heavyV; v.y -= ny * push * heavyV;
        o.x += nx * push * heavyO; o.y += ny * push * heavyO;
        const rel = Math.abs((v.vx - o.vx) * nx + (v.vy - o.vy) * ny) + Math.abs(v.speed - o.speed) * 0.3;
        if (rel > 25) {
          this.damage(v, rel * 0.1, o.driver);
          this.damage(o, rel * 0.1, v.driver);
          game.fx.sparks((v.x + o.x) / 2, (v.y + o.y) / 2, 5);
          game.audio.sfx('crash', v.x, v.y);
          // kick lane cars out of their lane
          for (const c of [v, o]) if (c.mode === 'lane' && c.driver !== game.player) { c.speed = 0; c.wait = 1; }
          if (o.mode === 'chase' || !o.driver) { o.vx += nx * rel * 0.5; o.vy += ny * rel * 0.5; }
          const pl = game.player;
          const other = v.driver === pl ? o : o.driver === pl ? v : null;
          if (other && other.driver && other.driver.kind === 'h' && !other.driver.dead) this.aggrieved(other, rel);
          if (v.driver === pl || o.driver === pl) game.cam.shake(Math.min(5, rel / 30));
        }
        if (v.mode === 'lane' && v.driver !== game.player) { v.speed *= 0.5; }
      }
    }
    // pedestrians and animals
    if (sp < 25) return;
    for (const a of game.actors.near(v.x, v.y, v.model.w * 0.55 + 4)) {
      if (a.dead || a.inCar || (a.kind === 'a' && a.flying)) continue;
      const rx = a.x - v.x, ry = a.y - v.y;
      const c = Math.cos(v.angle), s = Math.sin(v.angle);
      const along = rx * c + ry * s, lat = -rx * s + ry * c;
      if (Math.abs(along) < v.model.w * 0.5 + 2 && Math.abs(lat) < v.model.h * 0.5 + 2) {
        R.combat.runOver(v, a, sp);
      }
    }
    const pl = game.player;
    if (!pl.inCar && !pl.inside && !pl.dead && v.driver !== pl) {
      const rx = pl.x - v.x, ry = pl.y - v.y;
      const c = Math.cos(v.angle), s = Math.sin(v.angle);
      if (Math.abs(rx * c + ry * s) < v.model.w * 0.5 + 2 && Math.abs(-rx * s + ry * c) < v.model.h * 0.5 + 2) R.combat.runOver(v, pl, sp);
    }
  };
  TP.aggrieved = function (car, force) {
    const h = car.driver;
    if (!h || h.raged) return;
    if (car.driver.cop) return;
    this.game.actors.say(h, R.dialog.line(force > 80 ? 'crashBig' : 'crashSmall', h));
    if (h.tr.brave > 0.55 && R.rng() < 0.6) {
      car.mode = 'chase';
      car.ai = car.ai || {};
      setTimeout(() => { if (!car.removed && car.driver === h && !h.dead) this.roadRage(car); }, 900);
    }
  };
  TP.damage = function (v, amt, by) {
    if (v.wrecked) return;
    v.hp -= amt;
    if (v.hp < 20 && v.burning <= 0 && v.hp > 0 && R.rng() < 0.4) v.burning = 0.01;
    if (v.hp <= 0) this.explode(v, by);
  };
  TP.burn = function (v, dt) {
    v.burning += dt;
    if (R.rng() < dt * 10) this.game.fx.smoke(v.x, v.y - 4, v.burning > 3);
    if (v.burning > 6 && !v.wrecked) this.explode(v);
  };
  TP.explode = function (v, by) {
    if (v.wrecked) return;
    v.wrecked = true;
    v.hp = 0;
    v.burning = 0;
    R.combat.explosion(v.x, v.y, 44, 70, by || null, true);
    if (v.driver === this.game.player) this.exitVehicle(v, this.game.player);
    else if (v.driver) {
      const d = v.driver;
      this.exitVehicle(v, d);
      R.combat.damage(d, 200, by, 'blast');
    }
  };

  // ------------------------------------------------ enter / exit
  TP.exitVehicle = function (v, h) {
    const w = this.game.world;
    // find a free spot beside the car (left side first)
    const sides = [v.angle - Math.PI / 2, v.angle + Math.PI / 2, v.angle + Math.PI, v.angle];
    let px = v.x, py = v.y;
    for (const a of sides) {
      const x = v.x + Math.cos(a) * (v.model.h * 0.5 + 7), y = v.y + Math.sin(a) * (v.model.h * 0.5 + 7);
      if (!w.solidPed((x / TS) | 0, (y / TS) | 0)) { px = x; py = y; break; }
    }
    h.x = px; h.y = py;
    if (v.driver === h) v.driver = null;
    h.inCar = null;
    if (h !== this.game.player) {
      h.state = 'idle';
      h.timer = 0.5;
    }
    v.mode = 'chase';
    v.ai = v.ai || {};
    v.ai.target = null;
    v.ai.dest = null;
  };
  TP.nearestCar = function (x, y, r) {
    let best = null, bd = r;
    for (const v of this.list) {
      if (v.removed || v.wrecked) continue;
      const d = R.dist(x, y, v.x, v.y) - v.model.w * 0.3;
      if (d < bd) { bd = d; best = v; }
    }
    return best;
  };

  // ------------------------------------------------ spawning around the player
  TP.manage = function () {
    const game = this.game, w = game.world, pl = game.player;
    const cam = game.cam;
    let n = 0;
    for (const v of this.list) {
      const d = R.dist(v.x, v.y, pl.x, pl.y) / TS;
      const mine = v === pl.inCar || v.owner === 'player' || v.keep;
      if (d > 46 && !mine) { this.remove(v); continue; }
      if (!v.parked && v.driver && v.driver !== pl) n++;
    }
    const ptx = (pl.x / TS) | 0, pty = (pl.y / TS) | 0;
    const city = w.cityAt(ptx, pty);
    const hour = game.clock.hour();
    const tod = hour < 5 ? 0.3 : hour < 7 ? 0.6 : hour >= 7 && hour < 9 ? 1.3 : hour >= 16 && hour < 19 ? 1.3 : hour < 22 ? 1 : 0.6;
    let target = city ? (city.id === 'avalon' ? 20 : 13) : 5;
    target = Math.round(target * tod * game.settings.traffic);
    for (let k = 0; k < 3 && n < target; k++) {
      const s = w.findNear(ptx, pty, 18, 34, (x, y) => {
        const f = w.flow[w.idx(x, y)];
        return f && !(f & F.X);
      });
      if (!s) break;
      const px = s.x * TS + 8, py = s.y * TS + 8;
      if (cam.onScreen(px, py, 40)) continue;
      if (this.hash.query(px, py, 36).length) continue;
      const f = w.flow[w.idx(s.x, s.y)];
      const dirs = [0, 1, 2, 3].filter((d) => f & R.DIRBIT[d]);
      const dir = R.rng.pick(dirs);
      const sc = w.cityAt(s.x, s.y);
      let model = R.rng.weighted(sc ? D.civCars : D.ruralCars);
      if (sc && R.rng() < 0.05) model = 'bus';
      const v = this.make(model, px, py, DIRA[dir], { ai: { tx: s.x, ty: s.y, dir, turned: false } });
      this.addDriver(v, { city: sc ? sc.id : 'county', role: model === 'taxi' ? 'cabbie' : model === 'truck' ? 'trucker' : 'none' });
      if (R.rng() < 0.02 * game.settings.events) v.ai.reckless = true;
      n++;
      // ambient police chase
      if (sc && R.rng() < 0.012 * game.settings.events && !game.law.active()) this.ambientChase(v);
      else if (sc && R.rng() < 0.12 && this.list.filter((q) => q.modelId === 'police' && !q.removed).length < 2) {
        // patrol car
        v.model = D.vehicles.police; v.modelId = 'police'; v.color = '#1a1a24';
        v.driver.cop = true;
        v.driver.look = game.pop.makeLook(R.mulberry(R.rng.int(0, 1e9)), { fem: R.rng.chance(0.3), age: 35, role: 'cop', city: sc.id });
        game.actors.arm(v.driver, 'revolver');
        v.patrol = true;
      }
    }
    // parked cars in lots nearby
    if (city) {
      const parked = this.list.filter((v) => v.parked && !v.removed).length;
      if (parked < 8) {
        const s = w.findNear(ptx, pty, 14, 30, (x, y) => w.t(x, y) === T.PARKING);
        if (s) {
          const px = s.x * TS + 8, py = s.y * TS + 8;
          if (!cam.onScreen(px, py, 30) && !this.hash.query(px, py, 20).length)
            this.make(R.rng.weighted(D.civCars.filter(([m]) => m !== 'truck' && m !== 'taxi')), px, py, Math.PI / 2 * (R.rng() < 0.5 ? 1 : -1), { parked: true });
        }
      }
    }
  };

  TP.ambientChase = function (runner) {
    runner.ai.reckless = true;
    runner.model = D.vehicles.muscle; runner.modelId = 'muscle';
    const game = this.game;
    // police car spawns behind
    const back = runner.angle + Math.PI;
    const cx = runner.x + Math.cos(back) * 60, cy = runner.y + Math.sin(back) * 60;
    if (game.world.solidCar((cx / TS) | 0, (cy / TS) | 0)) return;
    const cop = this.make('police', cx, cy, runner.angle, { mode: 'chase' });
    const d = this.addDriver(cop, { cop: true, role: 'cop' });
    d.look = game.pop.makeLook(R.mulberry(R.rng.int(0, 1e9)), { fem: false, age: 40, role: 'cop', city: 'avalon' });
    cop.siren = true;
    cop.ai = { target: runner.driver, stopNear: 0 };
    runner.chasedBy = cop;
    game.ui.toast('Police pursuit in progress nearby.');
  };
})();
