// RHAPSODY — actors: pedestrians (named + strangers), cops, animals. Steering,
// pathfinding, perception and reactions live here.
'use strict';
(function () {
  const D = R.data, T = D.T, TS = R.TILE;

  // ------------------------------------------------ A* pathfinder (tile grid)
  const PF = (R.path = {});
  PF.init = function (world) {
    const n = world.W * world.TH;
    PF.w = world;
    PF.g = new Float32Array(n);
    PF.stamp = new Int32Array(n);
    PF.from = new Int32Array(n);
    PF.closed = new Int32Array(n);
    PF.gen = 1;
    PF.budget = 0;
  };
  PF.cost = function (x, y) {
    const w = PF.w;
    if (w.solidPed(x, y)) return -1;
    const t = w.tile[y * w.W + x];
    if (t === T.WATER) return 6;
    if (t === T.ROAD || t === T.HWY) return 2.2;
    if (t === T.FOREST || t === T.MARSH) return 1.4;
    if (w.obj[y * w.W + x] && D.smallObj[w.obj[y * w.W + x]]) return 1.6;
    return 1;
  };
  PF.find = function (sx, sy, gx, gy, maxNodes) {
    const w = PF.w;
    if (!w.inb(gx, gy) || !w.inb(sx, sy)) return null;
    if (PF.cost(gx, gy) < 0) {
      // goal is solid (e.g. a door): allow it as final node
    }
    maxNodes = maxNodes || 4000;
    PF.budget -= 1;
    const gen = ++PF.gen;
    const W = w.W;
    const start = sy * W + sx, goal = gy * W + gx;
    const heap = [start], hf = [0];
    PF.stamp[start] = gen;
    PF.g[start] = 0;
    PF.from[start] = -1;
    let n = 0;
    const push = (i, f) => {
      heap.push(i); hf.push(f);
      let k = heap.length - 1;
      while (k > 0) {
        const p = (k - 1) >> 1;
        if (hf[p] <= hf[k]) break;
        [heap[p], heap[k]] = [heap[k], heap[p]];
        [hf[p], hf[k]] = [hf[k], hf[p]];
        k = p;
      }
    };
    const pop = () => {
      const top = heap[0];
      const li = heap.pop(), lf = hf.pop();
      if (heap.length) {
        heap[0] = li; hf[0] = lf;
        let k = 0;
        for (;;) {
          const l = k * 2 + 1, r = l + 1;
          let m = k;
          if (l < heap.length && hf[l] < hf[m]) m = l;
          if (r < heap.length && hf[r] < hf[m]) m = r;
          if (m === k) break;
          [heap[m], heap[k]] = [heap[k], heap[m]];
          [hf[m], hf[k]] = [hf[k], hf[m]];
          k = m;
        }
      }
      return top;
    };
    while (heap.length && n++ < maxNodes) {
      const cur = pop();
      if (cur === goal) {
        const out = [];
        let c = cur;
        while (c !== -1) { out.push(c); c = PF.from[c]; }
        out.reverse();
        return out.map((i) => ({ x: i % W, y: (i / W) | 0 }));
      }
      if (PF.closed[cur] === gen) continue;
      PF.closed[cur] = gen;
      const cx = cur % W, cy = (cur / W) | 0;
      for (let d = 0; d < 4; d++) {
        const nx = cx + R.DIRS[d][0], ny = cy + R.DIRS[d][1];
        if (!w.inb(nx, ny)) continue;
        const ni = ny * W + nx;
        let c = ni === goal ? 1 : PF.cost(nx, ny);
        if (c < 0) continue;
        const ng = PF.g[cur] + c;
        if (PF.stamp[ni] !== gen || ng < PF.g[ni]) {
          PF.stamp[ni] = gen;
          PF.g[ni] = ng;
          PF.from[ni] = cur;
          push(ni, ng + (Math.abs(nx - gx) + Math.abs(ny - gy)) * 1.05);
        }
      }
    }
    return null;
  };

  // ------------------------------------------------ Actor manager
  const Actors = (R.Actors = function (game) {
    this.game = game;
    this.list = [];
    this.hash = new R.SpatialHash(64);
    this.nextId = 1;
    this.spawnTimer = 0;
  });
  const AP = Actors.prototype;

  AP.add = function (a) {
    a.id = this.nextId++;
    this.list.push(a);
    return a;
  };
  AP.remove = function (a) {
    a.removed = true;
    if (a.person) {
      a.person.actor = null;
    }
  };
  AP.near = function (x, y, r, filter) {
    const out = this.hash.query(x, y, r);
    return filter ? out.filter(filter) : out;
  };

  // --------- human factory
  AP.makeHuman = function (x, y, opts) {
    const game = this.game;
    const rnd = R.rng;
    const person = opts.person || null;
    let look = opts.look, arch = opts.arch, tr = opts.tr;
    if (person) {
      look = person.look;
      arch = person.arch;
      tr = person.tr;
    }
    if (!arch) arch = rnd.weighted([['friendly', 3], ['grumpy', 2], ['timid', 2], ['tough', 1.4], ['gossip', 1], ['square', 2], ['hustler', 1], ['flirt', 1], ['eccentric', 0.7], ['pious', 0.6]]);
    if (!tr) {
      const a = D.archetypes[arch];
      tr = {};
      for (const k in a) tr[k] = R.clamp(a[k] + (rnd() - 0.5) * 0.3, 0, 1);
    }
    if (!look) {
      const fake = { fem: rnd.chance(0.5), age: opts.kid ? 9 : rnd.int(18, 75), role: opts.role || 'none', city: opts.city || 'avalon' };
      look = game.pop.makeLook(R.mulberry(rnd.int(0, 1e9)), fake);
      look.fem = fake.fem;
      if (opts.kid) look.kid = true;
    }
    const cop = opts.cop || (person && (person.role === 'cop' || person.role === 'detective'));
    const h = {
      kind: 'h', x, y, r: 3, dir: 2, ang: Math.PI / 2, vx: 0, vy: 0, walk: 0, hp: 100, maxHp: 100,
      look, person, arch, tr, role: person ? person.role : opts.role || 'none',
      state: 'idle', timer: rnd() * 2, goal: null, path: null, pathI: 0, weapon: 'fists', armed: false, ammo: 0,
      cop: !!cop, hostile: false, target: null, down: 0, dead: false, bubble: null, alert: null,
      cash: opts.cash !== undefined ? opts.cash : rnd.int(2, 45), loot: [], witness: null, anger: 0, fear: 0,
      tag: opts.tag || (person ? 'named' : 'ambient'), speedMul: 1, greeted: 0, lastSeenPlayer: 0, stuck: 0,
      strangerName: null, drunk: opts.drunk || 0, faction: person ? person.faction : opts.faction || null, alertT: 0,
      thinkT: rnd() * 0.3, looted: false, mood: 0,
    };
    // who carries what
    const carry = cop ? 'revolver' : opts.weapon;
    if (carry) this.arm(h, carry);
    else if (h.faction && h.faction !== 'law') this.arm(h, R.rng.pick(['revolver', 'revolver', 'knife', 'magnum']));
    else if (tr.brave > 0.75 && rnd.chance(0.3)) this.arm(h, rnd.pick(['knife', 'bat', 'revolver']));
    else if (game.world.cityAt((x / TS) | 0, (y / TS) | 0) === null && rnd.chance(0.35)) this.arm(h, 'rifle');
    if (cop) { h.hp = h.maxHp = 130; h.cash = rnd.int(10, 40); }
    if (person) {
      h.cash = Math.min(person.wealth, rnd.int(5, 60));
      person.actor = h;
      if (rnd.chance(0.25)) h.loot.push(rnd.pick(['watch', 'ring', 'chain', 'cam', 'radio']));
    } else if (rnd.chance(0.12)) h.loot.push(rnd.pick(['watch', 'chain', 'radio', 'eight']));
    return this.add(h);
  };
  AP.arm = function (h, w) {
    h.weapon = w;
    h.armed = true;
    const def = D.weapons[w];
    h.ammo = def.clip ? def.clip * 3 : 0;
    h.clip = def.clip || 0;
    h.drawn = false;
  };
  AP.displayName = function (h) {
    if (h.kind === 'player') return h.nick;
    if (h.person) return h.person.met ? this.game.pop.name(h.person) : this.game.pop.title(h.person);
    if (h.strangerName) return h.strangerName;
    if (h.cop) return 'Police Officer';
    if (h.tag === 'mugger') return 'Mugger';
    if (h.tag === 'bounty') return 'Bounty Hunter';
    if (h.tag === 'worker') return 'Construction Worker';
    if (h.tag === 'fireman') return 'Firefighter';
    if (h.look.kid) return 'Kid';
    return 'Stranger';
  };

  AP.makeAnimal = function (x, y, type) {
    const def = D.animals[type];
    const a = {
      kind: 'a', type, def, x, y, r: def.size * 0.3, angle: R.rng() * 6.28, hp: def.hp, maxHp: def.hp, state: 'wander', timer: R.rng() * 3, t: R.rng() * 10,
      target: null, dead: false, moving: false, flying: false, skinned: false, buck: type === 'deer' && R.rng.chance(0.4), vx: 0, vy: 0, anger: 0,
    };
    return this.add(a);
  };

  // ------------------------------------------------ movement helpers
  AP.moveActor = function (a, dx, dy, dt) {
    const w = this.game.world;
    const r = a.r || 4;
    const nx = a.x + dx * dt;
    const blockedX = this.blocked(w, nx, a.y, r, a);
    if (!blockedX) a.x = nx;
    const ny = a.y + dy * dt;
    const blockedY = this.blocked(w, a.x, ny, r, a);
    if (!blockedY) a.y = ny;
    return !(blockedX || blockedY);
  };
  AP.blocked = function (w, x, y, r, a) {
    const x0 = ((x - r) / TS) | 0, x1 = ((x + r) / TS) | 0, y0 = ((y - r * 0.6) / TS) | 0, y1 = ((y + r * 0.4) / TS) | 0;
    for (let ty = y0; ty <= y1; ty++)
      for (let tx = x0; tx <= x1; tx++) {
        if (a.kind === 'a') {
          if (a.def.bird && a.flying) continue;
          const t = w.t(tx, ty);
          if (D.solidTile[t] || t === T.DEEP) return true;
          if (a.type !== 'gator' && t === T.WATER && a.type !== 'heron') return true;
          if (D.solidObj[w.o(tx, ty)] && w.o(tx, ty) !== D.O.FENCE) continue; // animals slip between trees
          continue;
        }
        if (w.solidPed(tx, ty)) return true;
      }
    return false;
  };

  AP.goTo = function (h, tx, ty, opts) {
    // tx, ty in tiles
    h.goal = { tx, ty, opts: opts || {} };
    h.path = null;
    h.pathI = 0;
    h.pathWait = 0;
  };

  // follow path or steer straight. returns true when arrived
  AP.steer = function (h, dt, speed) {
    const g = h.goal;
    if (!g) return true;
    const gx = g.tx * TS + TS / 2, gy = g.ty * TS + TS / 2;
    const d = R.dist(h.x, h.y, gx, gy);
    if (d < (g.opts.near || 10)) return true;
    const stx = (h.x / TS) | 0, sty = (h.y / TS) | 0;
    if (!h.path && d > TS * 2.5) {
      if (PF.budget > 0) {
        h.path = PF.find(stx, sty, g.tx, g.ty, g.opts.far ? 9000 : 5000) || 'fail';
        h.pathI = 1;
      }
    }
    let wx = gx, wy = gy;
    if (Array.isArray(h.path) && h.pathI < h.path.length) {
      const n = h.path[h.pathI];
      wx = n.x * TS + TS / 2;
      wy = n.y * TS + TS / 2;
      if (R.dist(h.x, h.y, wx, wy) < 6) h.pathI++;
      // skip ahead if next next is visible straight (smooth corners)
    }
    const ang = Math.atan2(wy - h.y, wx - h.x);
    const ok = this.moveActor(h, Math.cos(ang) * speed, Math.sin(ang) * speed, dt);
    h.ang = ang;
    h.dir = R.dir4(Math.cos(ang), Math.sin(ang));
    h.walk += dt * speed * 0.35;
    if (!ok) {
      h.stuck += dt;
      if (h.stuck > 1.2) {
        // nudge sideways and re-path
        h.stuck = 0;
        h.path = null;
        const side = ang + (R.rng() < 0.5 ? 1.57 : -1.57);
        this.moveActor(h, Math.cos(side) * 60, Math.sin(side) * 60, 0.2);
      }
    } else h.stuck = Math.max(0, h.stuck - dt);
    return false;
  };

  // Talk bubble
  AP.say = function (h, text, dur, color) {
    if (!text) return;
    h.bubble = { text, t: dur || Math.min(5, 1.6 + text.length * 0.05), color };
    const pl = this.game.player;
    if (R.dist(h.x, h.y, pl.x, pl.y) < TS * 14) this.game.ui.subtitle(this.displayName(h), text, color);
  };

  // ------------------------------------------------ main update
  AP.update = function (dt) {
    const game = this.game;
    PF.budget = 3;
    this.hash.clear();
    for (const a of this.list) if (!a.removed) this.hash.insert(a);
    for (const a of this.list) {
      if (a.removed) continue;
      if (a.kind === 'h') this.updateHuman(a, dt);
      else this.updateAnimal(a, dt);
      if (a.bubble && (a.bubble.t -= dt) <= 0) a.bubble = null;
    }
    // separation between humans
    for (const a of this.list) {
      if (a.removed || a.dead || a.kind !== 'h' || a.inCar) continue;
      const near = this.hash.query(a.x, a.y, 8);
      for (const b of near) {
        if (b === a || b.dead || b.kind !== 'h' || b.inCar) continue;
        const d = R.dist(a.x, a.y, b.x, b.y);
        if (d > 0.01 && d < 5) {
          const push = (5 - d) * 0.5;
          this.moveActor(a, ((a.x - b.x) / d) * push * 10, ((a.y - b.y) / d) * push * 10, dt);
        }
      }
    }
    this.list = this.list.filter((a) => !a.removed);
    this.spawnTimer -= dt;
    if (this.spawnTimer <= 0) {
      this.spawnTimer = 0.5;
      this.manage();
    }
  };

  // ------------------------------------------------ humans
  AP.updateHuman = function (h, dt) {
    const game = this.game, pl = game.player;
    if (h.inCar) return; // traffic drives them
    if (h.dead) {
      h.rot = (h.rot || 0) + dt;
      return;
    }
    if (h.down > 0) {
      h.down -= dt;
      if (h.down <= 0) {
        h.hp = Math.max(h.hp, 25);
        this.say(h, R.dialog.line('getup', h));
        if (h.cop || (h.tr.brave > 0.6 && h.hostile)) this.setFight(h, pl);
        else this.setFlee(h, pl, 12);
      }
      return;
    }
    if (h.bleed) {
      h.hp -= dt * 2;
      if (h.hp <= 0) R.combat.kill(h, h.lastHitBy);
    }
    h.thinkT -= dt;
    const think = h.thinkT <= 0;
    if (think) {
      h.thinkT = 0.25 + R.rng() * 0.15;
      this.perceive(h);
    }
    const walkSpeed = (h.look.kid ? 30 : 34) * (h.drunk ? 0.7 : 1);
    const runSpeed = 74;
    switch (h.state) {
      case 'idle': {
        h.timer -= dt;
        if (h.timer <= 0) {
          if (h.goal) h.state = 'travel';
          else if (h.tag === 'ambient' || h.tag === 'kid') this.startWander(h);
          else if (h.spot) this.hangAround(h);
          else h.timer = 2;
        }
        break;
      }
      case 'wander': {
        this.sidewalkWalk(h, dt, walkSpeed);
        h.timer -= dt;
        if (h.timer <= 0) {
          h.state = 'idle';
          h.timer = 1 + R.rng() * 3;
          if (R.rng() < 0.3) this.ambientChat(h);
        }
        break;
      }
      case 'travel': {
        const arrived = this.steer(h, dt, h.hurry ? runSpeed : walkSpeed);
        if (arrived) {
          h.hurry = false;
          const g = h.goal;
          h.goal = null;
          if (g && g.opts.enter) {
            // enters a building: leave the world
            if (h.person) h.person.place = g.opts.placeKey;
            this.remove(h);
          } else if (g && g.opts.spot) {
            h.spot = g.opts.spot;
            if (h.person) h.person.place = g.opts.placeKey;
            h.state = 'idle';
            h.timer = 1;
          } else {
            h.state = 'idle';
            h.timer = 1;
          }
        }
        break;
      }
      case 'hang': {
        h.timer -= dt;
        if (h.goal && !this.steer(h, dt, walkSpeed * 0.7)) break;
        h.goal = null;
        if (h.timer <= 0) this.hangAround(h);
        break;
      }
      case 'flee': {
        h.timer -= dt;
        const src = h.threat || pl;
        const ang = Math.atan2(h.y - src.y, h.x - src.x) + (h.fleeBias || 0);
        const ok = this.moveActor(h, Math.cos(ang) * runSpeed, Math.sin(ang) * runSpeed, dt);
        if (!ok) h.fleeBias = (h.fleeBias || 0) + (R.rng() < 0.5 ? 0.8 : -0.8);
        h.dir = R.dir4(Math.cos(ang), Math.sin(ang));
        h.walk += dt * 20;
        if (think && R.rng() < 0.05) this.say(h, R.dialog.line('fleeing', h));
        if (h.timer <= 0) {
          h.state = 'idle';
          h.timer = 2;
          h.threat = null;
          if (h.witness && !h.witness.done) this.startReport(h);
        }
        break;
      }
      case 'cower': {
        h.timer -= dt;
        h.walk = 0;
        if (h.timer <= 0) {
          if (h.witness && !h.witness.done && !h.witness.silenced) this.startReport(h);
          else this.setFlee(h, pl, 8);
        }
        break;
      }
      case 'report': this.updateReport(h, dt, runSpeed); break;
      case 'fight': R.combat.npcFight(h, dt); break;
      case 'talk': {
        // facing the player during an interaction
        h.timer -= dt;
        const a = Math.atan2(pl.y - h.y, pl.x - h.x);
        h.dir = R.dir4(Math.cos(a), Math.sin(a));
        if (h.timer <= 0 || R.dist(h.x, h.y, pl.x, pl.y) > TS * 5) {
          h.state = 'idle';
          h.timer = 0.5;
        }
        break;
      }
      case 'follow': {
        // walk up to the player (cop arrest, hustler pitch, crew)
        const d = R.dist(h.x, h.y, pl.x, pl.y);
        if (d > 22) {
          const a = Math.atan2(pl.y - h.y, pl.x - h.x);
          const sp = h.hurry ? runSpeed : walkSpeed * 1.3;
          this.moveActor(h, Math.cos(a) * sp, Math.sin(a) * sp, dt);
          h.dir = R.dir4(Math.cos(a), Math.sin(a));
          h.walk += dt * sp * 0.35;
        } else if (h.onReach) {
          const f = h.onReach;
          h.onReach = null;
          f(h);
        }
        h.timer -= dt;
        if (h.timer <= 0) {
          h.state = 'idle';
          h.timer = 1;
          h.onReach = null;
        }
        break;
      }
      case 'watch': {
        // onlooker at a fight or musician
        h.timer -= dt;
        const src = h.watchT || pl;
        const a = Math.atan2(src.y - h.y, src.x - h.x);
        h.dir = R.dir4(Math.cos(a), Math.sin(a));
        if (R.dist(h.x, h.y, src.x, src.y) > TS * 4) this.moveActor(h, Math.cos(a) * walkSpeed, Math.sin(a) * walkSpeed, dt), (h.walk += dt * 10);
        if (think && R.rng() < 0.04) this.say(h, R.dialog.line(h.watchKind || 'cheer', h));
        if (h.timer <= 0) { h.state = 'idle'; h.timer = 1; }
        break;
      }
      case 'work': {
        // construction workers hammer, firemen spray
        h.timer -= dt;
        h.walk = 0;
        if (h.tag === 'fireman') R.env.fireman(h, dt);
        if (h.timer <= 0) this.startWander(h);
        break;
      }
      case 'perform': {
        h.timer -= dt;
        h.walk += dt * 3;
        if (think && R.rng() < 0.2) game.fx.note(h.x, h.y - 20);
        if (think && R.rng() < 0.02) this.say(h, R.dialog.line(h.role === 'preacher' ? 'preach' : 'perform', h));
        if (h.timer <= 0) this.hangAround(h);
        break;
      }
      case 'sleep': {
        h.walk = 0;
        break;
      }
      case 'surrender': {
        h.walk = 0;
        h.timer -= dt;
        if (h.timer <= 0) this.setFlee(h, pl, 10);
        break;
      }
    }
  };

  AP.hangAround = function (h) {
    const s = h.spot;
    h.state = 'hang';
    h.timer = 3 + R.rng() * 6;
    if (!s) { h.state = 'idle'; return; }
    if ((h.role === 'musician' || h.role === 'preacher') && R.rng() < 0.7) {
      h.state = 'perform';
      h.timer = 8 + R.rng() * 8;
      return;
    }
    const rad = h.stay ? 1 : 3;
    for (let k = 0; k < 6; k++) {
      const tx = s.x + R.rng.int(-rad, rad), ty = s.y + R.rng.int(-rad, rad);
      if (!this.game.world.solidPed(tx, ty) && !D.roadTile[this.game.world.t(tx, ty)]) {
        this.goTo(h, tx, ty, { near: 4 });
        break;
      }
    }
    if (R.rng() < 0.25) this.ambientChat(h);
  };

  AP.startWander = function (h) {
    h.state = 'wander';
    h.timer = 4 + R.rng() * 8;
    h.wdir = h.wdir !== undefined ? h.wdir : R.rng.int(0, 3);
  };
  // Walk along sidewalks / paths, choose at tile centers
  AP.sidewalkWalk = function (h, dt, speed) {
    const w = this.game.world;
    const tx = (h.x / TS) | 0, ty = (h.y / TS) | 0;
    const cx = tx * TS + 8, cy = ty * TS + 8;
    const [dx, dy] = R.DIRS[h.wdir];
    const good = (x, y) => {
      if (w.solidPed(x, y)) return false;
      const t = w.t(x, y);
      if (h.crossing && D.roadTile[t]) return true;
      return t === T.WALK || t === T.PLAZA || t === T.PARK || t === T.DOCK || t === T.PARKING || (!w.cityAt(x, y) && !D.waterTile[t] && !D.roadTile[t]);
    };
    // at center? decide
    const nearCenter = Math.abs(h.x - cx) < 2.5 && Math.abs(h.y - cy) < 2.5;
    if (nearCenter && h.lastDecide !== ty * 10000 + tx) {
      h.lastDecide = ty * 10000 + tx;
      const t = w.t(tx, ty);
      if (!D.roadTile[t]) h.crossing = false;
      const opts = [];
      for (let d = 0; d < 4; d++) {
        if (d === (h.wdir + 2) % 4) continue;
        if (good(tx + R.DIRS[d][0], ty + R.DIRS[d][1])) opts.push(d);
      }
      // crosswalk: road ahead then sidewalk beyond
      if (!opts.includes(h.wdir) && D.roadTile[w.t(tx + dx, ty + dy)] && R.rng() < 0.35) {
        let k = 1;
        while (k < 5 && D.roadTile[w.t(tx + dx * k, ty + dy * k)]) k++;
        if (k < 5 && w.t(tx + dx * k, ty + dy * k) === T.WALK) {
          h.crossing = true;
          opts.push(h.wdir);
        }
      }
      if (opts.includes(h.wdir) && R.rng() < 0.8) {} // keep going
      else if (opts.length) h.wdir = R.rng.pick(opts);
      else h.wdir = (h.wdir + 2) % 4;
      h.x = cx; h.y = cy;
    }
    const [ddx, ddy] = R.DIRS[h.wdir];
    const ok = this.moveActor(h, ddx * speed, ddy * speed, dt);
    if (!ok) { h.wdir = (h.wdir + 1 + R.rng.int(0, 2)) % 4; h.lastDecide = -1; }
    h.dir = h.wdir;
    h.walk += dt * speed * 0.35;
  };

  AP.ambientChat = function (h) {
    // Two neighbours chat; or a comment about the world
    const others = this.near(h.x, h.y, 40, (o) => o !== h && o.kind === 'h' && !o.dead && !o.cop && (o.state === 'idle' || o.state === 'hang'));
    if (others.length && R.rng() < 0.6) {
      const o = others[0];
      this.say(h, R.dialog.chatter(h, o));
      setTimeout(() => { if (!o.dead && !o.removed) this.say(o, R.dialog.chatterReply(o, h)); }, 1600);
      const a = Math.atan2(o.y - h.y, o.x - h.x);
      h.dir = R.dir4(Math.cos(a), Math.sin(a));
      o.dir = R.dir4(-Math.cos(a), -Math.sin(a));
    }
  };

  AP.setFlee = function (h, from, secs) {
    if (h.dead) return;
    h.state = 'flee';
    h.threat = from;
    h.timer = secs || 8;
    h.goal = null;
    h.fleeBias = (R.rng() - 0.5) * 0.8;
    if (h.person) h.person.place = null;
  };
  AP.setCower = function (h, secs) {
    h.state = 'cower';
    h.timer = secs || 6;
    h.goal = null;
  };
  AP.setFight = function (h, target) {
    if (h.dead) return;
    h.state = 'fight';
    h.target = target;
    h.goal = null;
    if (target === this.game.player) h.hostile = true;
    if (h.armed) h.drawn = true;
  };

  // ------------------------------------------------ perception
  AP.perceive = function (h) {
    const game = this.game, pl = game.player;
    if (h.state === 'fight' || h.state === 'report' || h.state === 'surrender' || h.state === 'sleep') return;
    const d = R.dist(h.x, h.y, pl.x, pl.y);
    const seesPlayer = d < TS * 10 && !pl.inside && (d < TS * 3 || game.world.los(h.x, h.y - 8, pl.x, pl.y - 8));
    // player with a gun drawn close by
    if (seesPlayer && pl.weaponOut && D.weapons[pl.weapon] && D.weapons[pl.weapon].gun && d < TS * 7 && h.state !== 'flee' && h.state !== 'cower') {
      if (h.cop) {
        if (!game.law.warned(h)) {
          this.say(h, R.dialog.line('copWarnGun', h));
          game.law.brandish(h);
        }
      } else if (h.hostile || (h.faction && h.faction !== 'law' && game.jobs.familyStanding(h.faction) < -20)) this.setFight(h, pl);
      else if (h.tr.brave > 0.8 && h.armed) {
        this.say(h, R.dialog.line('standoff', h));
        h.drawn = true;
        h.state = 'watch';
        h.watchT = pl;
        h.timer = 3;
      } else if (h.tr.brave < 0.35 || d < TS * 3) {
        this.setCower(h, 5);
        this.say(h, R.dialog.line('cower', h));
      } else {
        this.setFlee(h, pl, 7);
        this.say(h, R.dialog.line('seeGun', h));
      }
      return;
    }
    // masked stranger in daylight makes people nervous
    if (seesPlayer && pl.masked && d < TS * 4 && h.state === 'idle' && R.rng() < 0.08) this.say(h, R.dialog.line('seeMask', h));
    // cops recognise wanted player
    if (h.cop && seesPlayer) game.law.copSees(h, d);
    // hostile factions attack on sight
    if (seesPlayer && h.faction && h.faction !== 'law' && h.armed && game.jobs.familyStanding(h.faction) <= -50 && d < TS * 8) {
      this.say(h, R.dialog.line('rivalSpot', h));
      this.setFight(h, pl);
      return;
    }
    // grudge holders (you killed their kin) confront you
    if (seesPlayer && h.person && h.person.grudge > 60 && d < TS * 6 && !pl.masked && R.rng() < 0.3) {
      this.say(h, R.dialog.line('grudge', h));
      if (h.tr.brave > 0.45) this.setFight(h, pl);
      else this.setFlee(h, pl, 6);
      h.person.grudge = 40;
      return;
    }
    // bump reactions and people commenting on the player
    if (seesPlayer && d < TS * 2.2 && h.state !== 'talk' && h.state !== 'flee' && h.state !== 'cower' && R.rng() < 0.03 && (!h.greetCool || game.clock.t > h.greetCool)) {
      h.greetCool = game.clock.t + 40;
      this.say(h, R.dialog.passing(h, pl));
    }
  };

  // ------------------------------------------------ reporting crimes (RDR2-style witnesses)
  AP.startReport = function (h) {
    const game = this.game, w = game.world;
    if (!h.witness || h.witness.done) return;
    h.state = 'report';
    h.alert = 'report';
    // nearest of: cop actor, phone booth, police station
    const tx = (h.x / TS) | 0, ty = (h.y / TS) | 0;
    let best = null, bd = 1e9;
    for (const c of this.list) {
      if (!c.cop || c.dead || c.removed) continue;
      const d = R.dist(h.x, h.y, c.x, c.y);
      if (d < bd) { bd = d; best = { cop: c, tx: (c.x / TS) | 0, ty: (c.y / TS) | 0 }; }
    }
    for (const p of w.phones) {
      const d = R.dist(tx, ty, p.x, p.y) * TS;
      if (d < bd) { bd = d; best = { tx: p.x, ty: p.y }; }
    }
    const city = w.cityAt(tx, ty);
    if (city) {
      const ps = city.buildings.find((b) => b.type === 'police');
      if (ps) {
        const d = R.dist(tx, ty, ps.out.x, ps.out.y) * TS;
        if (d < bd) { bd = d; best = { tx: ps.out.x, ty: ps.out.y }; }
      }
    }
    if (!best || bd > TS * 60) {
      // nowhere to report: they'll tell the next lawman they meet (still counts as a slower report)
      best = null;
      h.witness.slow = true;
      h.timer = 25 + R.rng() * 15;
    }
    h.reportTo = best;
    if (best) this.goTo(h, best.tx, best.ty, { near: best.cop ? 20 : 14 });
    h.reportT = 0;
  };
  AP.updateReport = function (h, dt, speed) {
    const game = this.game;
    const wt = h.witness;
    if (!wt || wt.done || wt.silenced) { h.state = 'idle'; h.alert = null; return; }
    h.reportT += dt;
    if (!h.reportTo) {
      h.timer -= dt;
      this.moveActor(h, Math.cos(h.ang) * speed * 0.5, Math.sin(h.ang) * speed * 0.5, dt);
      if (h.timer <= 0) { game.law.report(wt.crime, h); wt.done = true; h.alert = null; this.setFlee(h, game.player, 5); }
      return;
    }
    if (h.reportTo.cop && !h.reportTo.cop.dead) {
      h.goal.tx = (h.reportTo.cop.x / TS) | 0;
      h.goal.ty = (h.reportTo.cop.y / TS) | 0;
    }
    const arrived = this.steer(h, dt, speed);
    if (arrived) {
      // phones take a moment
      h.phoneT = (h.phoneT || 0) + dt;
      h.walk = 0;
      if (h.phoneT > (h.reportTo.cop ? 0.5 : 2.5)) {
        this.say(h, R.dialog.line(h.reportTo.cop ? 'reportCop' : 'reportPhone', h));
        game.law.report(wt.crime, h);
        wt.done = true;
        h.alert = null;
        this.setFlee(h, game.player, 6);
      }
    } else if (h.reportT > 90) {
      wt.done = true; // gave up
      h.alert = null;
      h.state = 'idle';
    }
  };

  // ------------------------------------------------ noise events (gunshots, explosions, screams)
  AP.noise = function (x, y, radius, kind, source) {
    const game = this.game;
    const near = this.near(x, y, radius);
    for (const a of near) {
      if (a.dead || a === source) continue;
      if (a.state === 'sleep') {
        const d = R.dist(a.x, a.y, x, y);
        if (R.rng() < (kind === 'rustle' ? 0.35 : 1) * (1 - d / (radius + 1)) + (kind === 'rustle' ? 0 : 0.5)) {
          a.state = 'idle';
          a.timer = 1;
          a.x += 8;
          this.say(a, R.dialog.line('woken', a));
          const pl = this.game.player;
          if (pl.room && a.room === pl.room && !pl.room.b.playerOwned) {
            setTimeout(() => this.game.law.crime('burglary', pl.x, pl.y, { victim: a }), 400);
          }
        }
        continue;
      }
      if (kind === 'rustle') continue;
      if (a.kind === 'a') {
        if (a.def.bird) { a.flying = true; a.state = 'flee'; a.timer = 6; }
        else if (a.def.prey || !a.def.predator || R.rng() < 0.5) { a.state = 'flee'; a.target = source || game.player; a.timer = 6; }
        continue;
      }
      if (a.inCar) continue;
      if (a.cop) {
        if (kind === 'gunshot' || kind === 'blast' || kind === 'scream') game.law.copHears(a, x, y, kind);
        continue;
      }
      if (a.state === 'fight' || a.state === 'report') continue;
      if (a.hostile && a.armed) { this.setFight(a, game.player); continue; }
      const d = R.dist(a.x, a.y, x, y);
      if (kind === 'fight' && d < TS * 7 && a.state !== 'flee') {
        if (a.tr.brave > 0.45 && a.tag !== 'kid' && R.rng() < 0.6) { a.state = 'watch'; a.watchT = source || game.player; a.watchKind = 'cheer'; a.timer = 6 + R.rng() * 4; }
        else this.setFlee(a, source || game.player, 5);
        continue;
      }
      if (kind === 'gunshot' || kind === 'blast') {
        if (a.tr.brave < 0.3 && d < TS * 6) { this.setCower(a, 4 + R.rng() * 3); this.say(a, R.dialog.line('cower', a)); }
        else { this.setFlee(a, { x, y }, 8 + R.rng() * 5); if (R.rng() < 0.3) this.say(a, R.dialog.line('fleeing', a)); }
      }
    }
  };

  // ------------------------------------------------ animals
  AP.updateAnimal = function (a, dt) {
    const game = this.game, pl = game.player, def = a.def;
    a.t += dt;
    if (a.dead) return;
    a.timer -= dt;
    a.moving = false;
    const dp = R.dist(a.x, a.y, pl.x, pl.y);
    const night = game.clock.isNight();
    const plTarget = pl.inCar || pl;
    const sneakMul = pl.sneak ? 0.45 : 1;
    let speed = def.speed * (a.state === 'flee' || a.state === 'hunt' || a.state === 'attack' ? 1 : 0.35);
    if (def.bird) {
      if (!a.flying && (dp < TS * 3.5 * sneakMul || a.state === 'flee')) {
        a.flying = true;
        a.state = 'flee';
        a.angle = Math.atan2(a.y - pl.y, a.x - pl.x) + (R.rng() - 0.5);
        a.timer = 8;
      }
      if (a.flying) {
        this.moveActor(a, Math.cos(a.angle) * def.speed, Math.sin(a.angle) * def.speed, dt);
        a.moving = true;
        if (a.timer <= 0) this.remove(a);
      } else if (a.timer <= 0) {
        a.angle = R.rng() * 6.28;
        a.timer = 1 + R.rng() * 2;
        this.moveActor(a, Math.cos(a.angle) * 8, Math.sin(a.angle) * 8, 0.3);
      }
      return;
    }
    switch (a.state) {
      case 'wander': {
        if (a.timer <= 0) {
          a.timer = 1.5 + R.rng() * 4;
          a.angle = R.rng() * 6.28;
          a.pause = R.rng() < 0.5;
        }
        if (!a.pause) {
          a.moving = true;
          if (!this.moveActor(a, Math.cos(a.angle) * speed, Math.sin(a.angle) * speed, dt)) a.angle += 1.5;
        }
        // perception
        if (def.prey && dp < TS * 7 * sneakMul && (!pl.sneak || dp < TS * 3)) { a.state = 'flee'; a.target = plTarget; a.timer = 5; }
        if (def.dog && dp < TS * 5 && a.timer < 0.2 && R.rng() < 0.3) { game.fx.text(a.x, a.y - 14, 'woof!', '#f2e2c0'); if (R.rng() < 0.3) { a.state = 'follow'; a.timer = 12; } }
        if (def.predator && !def.dog) {
          const aggro = (night ? def.night || 1 : 1) * (a.anger > 0 ? 3 : 1);
          if (!pl.inCar && dp < TS * (def.ambush ? 2.5 : 5) * aggro * sneakMul && (def === D.animals.bear || def === D.animals.gator || def === D.animals.snake || night || a.anger > 0 || R.rng() < 0.02)) {
            if (def === D.animals.snake && !a.warned) { a.warned = true; game.fx.text(a.x, a.y - 12, '*rattle*', '#e4a92a'); a.timer = 1.5; break; }
            a.state = 'attack';
            a.target = pl;
            a.timer = 12;
            if (def === D.animals.bear) game.fx.text(a.x, a.y - 20, 'ROAR', '#d9621e');
            if (def === D.animals.wolf) game.audio.sfx('howl');
          } else if (R.rng() < 0.01) {
            // hunt nearby prey
            const prey = this.near(a.x, a.y, TS * 12, (o) => o.kind === 'a' && !o.dead && o.def.prey && o !== a)[0];
            if (prey) { a.state = 'attack'; a.target = prey; a.timer = 10; }
          }
        }
        if (def.angry && dp < TS * 2.5 && R.rng() < 0.05) { a.state = 'attack'; a.target = pl; a.timer = 6; }
        break;
      }
      case 'follow': {
        if (dp > 24) {
          const ang = Math.atan2(pl.y - a.y, pl.x - a.x);
          a.angle = ang;
          a.moving = true;
          this.moveActor(a, Math.cos(ang) * def.speed * 0.6, Math.sin(ang) * def.speed * 0.6, dt);
        }
        if (a.timer <= 0) a.state = 'wander';
        break;
      }
      case 'flee': {
        const src = a.target || pl;
        const ang = Math.atan2(a.y - src.y, a.x - src.x) + Math.sin(a.t * 2) * 0.4;
        a.angle = ang;
        a.moving = true;
        if (!this.moveActor(a, Math.cos(ang) * def.speed, Math.sin(ang) * def.speed, dt)) a.target = { x: a.x + (R.rng() - 0.5) * 50, y: a.y + (R.rng() - 0.5) * 50 };
        if (a.timer <= 0) { a.state = 'wander'; a.target = null; }
        break;
      }
      case 'attack': {
        const tg = a.target;
        if (!tg || tg.dead || a.timer <= 0 || (tg === pl && (pl.inCar || pl.inside))) { a.state = 'wander'; a.target = null; break; }
        const d = R.dist(a.x, a.y, tg.x, tg.y);
        const ang = Math.atan2(tg.y - a.y, tg.x - a.x);
        a.angle = ang;
        if (d > (a.r + 8)) {
          a.moving = true;
          const lunge = def.ambush && d < 40 ? 1.8 : 1;
          this.moveActor(a, Math.cos(ang) * def.speed * lunge, Math.sin(ang) * def.speed * lunge, dt);
        } else {
          a.biteT = (a.biteT || 0) - dt;
          if (a.biteT <= 0) {
            a.biteT = 0.9;
            R.combat.damage(tg, def.dmg || 5, a, 'animal');
            game.fx.blood(tg.x, tg.y - 6, 5);
            if (tg.kind === 'a' && tg.dead) { a.state = 'wander'; a.timer = 20; a.pause = true; }
          }
        }
        // cowardly predators give up when hurt
        if (a.hp < a.maxHp * 0.35 && def !== D.animals.bear) { a.state = 'flee'; a.target = pl; a.timer = 8; }
        break;
      }
    }
  };

  // ------------------------------------------------ population management around the player
  AP.manage = function () {
    const game = this.game, w = game.world, pl = game.player;
    const ptx = pl.x / TS, pty = pl.y / TS;
    // despawn far actors
    let humans = 0, animals = 0;
    for (const a of this.list) {
      const d = R.dist(a.x, a.y, pl.x, pl.y) / TS;
      if (a.inCar) continue;
      if (d > (a.dead ? 30 : 42) && !a.keep) { this.remove(a); continue; }
      if (a.kind === 'h' && !a.dead && (a.tag === 'ambient' || a.tag === 'kid')) humans++;
      if (a.kind === 'a' && !a.dead) animals++;
    }
    if (pl.room) return; // nothing spawns while you're indoors
    const city = w.cityAt(ptx | 0, pty | 0);
    const hour = game.clock.hour();
    const tod = hour < 5 ? 0.25 : hour < 7 ? 0.5 : hour < 20 ? 1 : hour < 23 ? 0.7 : 0.4;
    const weather = game.env.weather.rain > 0.3 ? 0.55 : 1;
    let target = 3;
    if (city) {
      const dc = R.dist(ptx, pty, city.cx, city.cy) / (city.nbx * 8);
      target = dc < 0.4 ? 26 : dc < 0.8 ? 18 : 11;
      if (city.id === 'avalon') target += 6;
    } else if (w.inCityRect(ptx | 0, pty | 0, 4)) target = 7;
    target = Math.round(target * tod * weather * game.settings.density);
    if (humans < target) {
      for (let k = 0; k < 3 && humans < target; k++) {
        const s = w.findNear(ptx, pty, 16, 30, (x, y) => {
          const t = w.t(x, y);
          return (t === T.WALK || t === T.PLAZA || t === T.PARK || (!city && (t === T.GRASS || t === T.DIRT || t === T.DESERT || t === T.SNOW || t === T.FOREST))) && !w.solidPed(x, y);
        });
        if (!s) continue;
        const sc = w.cityAt(s.x, s.y);
        const kid = hour > 7 && hour < 19 && R.rng() < 0.08;
        const h = this.makeHuman(s.x * TS + 8, s.y * TS + 8, { city: sc ? sc.id : 'county', kid, tag: kid ? 'kid' : 'ambient', drunk: hour > 22 || hour < 3 ? (R.rng() < 0.25 ? 1 : 0) : 0 });
        if (!sc) h.role = R.rng.pick(['hunter', 'drifter', 'farmer']);
        this.startWander(h);
        humans++;
        // nighttime muggers in the city, bounty hunters on the road
        if (sc && (hour >= 22 || hour < 4) && R.rng() < 0.08 * game.settings.events && !kid) {
          h.tag = 'mugger';
          this.arm(h, R.rng.pick(['knife', 'bat', 'revolver']));
          h.state = 'follow';
          h.timer = 30;
          h.hurry = false;
          h.onReach = (m) => R.events.mugging(m);
        } else if (sc && hour > 9 && hour < 21 && R.rng() < 0.03 * game.settings.events && !kid) {
          h.tag = 'pickpocket';
          h.state = 'follow';
          h.timer = 25;
          h.onReach = (m) => R.events.pickpocket(m);
        } else if (sc && R.rng() < 0.03 * game.settings.events && !kid) {
          h.tag = 'hustler';
          h.state = 'follow';
          h.timer = 25;
          h.onReach = (m) => R.events.hustlerPitch(m);
        }
      }
    }
    // wildlife
    if (!city && animals < 9 * game.settings.density) {
      const s = w.findNear(ptx, pty, 17, 32, (x, y) => !w.solidPed(x, y) && !D.roadTile[w.t(x, y)]);
      if (s) {
        const biome = w.biomeAt(s.x, s.y);
        const opts = Object.keys(D.animals).filter((k) => D.animals[k].biome.includes(biome) && (!D.animals[k].rare || R.rng() < 0.3));
        if (opts.length) {
          const type = R.rng.pick(opts);
          const def = D.animals[type];
          const n = def.herd ? R.rng.int(def.herd[0], def.herd[1]) : 1;
          for (let i = 0; i < n; i++) {
            const x = s.x * TS + 8 + (R.rng() - 0.5) * 40, y = s.y * TS + 8 + (R.rng() - 0.5) * 40;
            if (w.solidPed((x / TS) | 0, (y / TS) | 0) || w.isWater((x / TS) | 0, (y / TS) | 0) && type !== 'gator') continue;
            this.makeAnimal(x, y, type);
          }
        }
      }
    } else if (city && animals < 4) {
      const s = w.findNear(ptx, pty, 14, 26, (x, y) => { const t = w.t(x, y); return t === T.PARK || t === T.WALK || t === T.PLAZA || t === T.DOCK; });
      if (s) {
        const type = city.id === 'port' && R.rng() < 0.6 ? 'gull' : R.rng() < 0.2 ? 'dog' : 'crow';
        const def = D.animals[type];
        const n = def.herd ? R.rng.int(def.herd[0], def.herd[1]) : 1;
        for (let i = 0; i < n; i++) this.makeAnimal(s.x * TS + 8 + (R.rng() - 0.5) * 30, s.y * TS + 8 + (R.rng() - 0.5) * 30, type);
      }
    }
  };
})();
