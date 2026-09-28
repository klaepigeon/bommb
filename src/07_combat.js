// RHAPSODY — combat: melee, hitscan guns, thrown molotovs/dynamite, explosions,
// knockouts vs kills, self-defence rules and NPC fighting AI.
'use strict';
(function () {
  const D = R.data, T = D.T, TS = R.TILE;
  const C = (R.combat = {});
  C.projectiles = [];

  const game = () => R.game;

  // hit test: humans are about 6px wide and stand from y-18 to y
  function hitHuman(a, x, y) {
    if (a.kind === 'h') return Math.abs(x - a.x) < 5 && y < a.y + 2 && y > a.y - 18;
    if (a.kind === 'a') return R.dist(x, y, a.x, a.y - a.def.size * 0.4) < a.def.size * 0.7 + 2;
    return false;
  }

  // ---------------------------------------------------------------- damage
  C.damage = function (target, amt, source, kind) {
    const g = game();
    if (!target || target.dead) return;
    const byPlayer = source === g.player || (source && source.driver === g.player);
    if (target === g.player) {
      if (source && source.kind === 'h') source.attackedPlayer = true;
      return g.player.hurt(amt, source, kind);
    }
    if (target.kind === 'v') return g.traffic.damage(target, amt, source);
    if (g.cheats && g.cheats.oneHit && byPlayer) amt = 999;
    target.hp -= amt;
    target.lastHitBy = source;
    if (target.kind === 'a') {
      if (kind === 'melee') { target.hp -= amt * 0.4; target.stunT = target.def.size >= 12 ? 0.08 : 0.2; } // animals have no guard against a swing
      g.fx.blood(target.x, target.y - 4, kind === 'bullet' ? 4 : 2);
      if (target.hp <= 0) C.kill(target, source);
      else {
        if (target.def.predator || target.def.angry || target.def.dog) { target.state = 'attack'; target.target = source && source.kind ? (source.inCar ? null : source) : g.player; target.timer = 10; target.anger = 1; }
        else { target.state = 'flee'; target.target = source || g.player; target.timer = 6; }
      }
      return;
    }
    // humans
    const h = target;
    if (h.inCar) return;
    g.fx.blood(h.x, h.y - 8, kind === 'melee' ? 3 : 6);
    if (kind === 'bullet' && source && source.x !== undefined) g.fx.spray(h.x, h.y - 10, Math.atan2(h.y - source.y, h.x - source.x), 5 + Math.round(amt / 10));
    h.lastHitKind = kind;
    if (byPlayer) C.onPlayerHits(h, amt, kind);
    const nonLethal = kind === 'melee' && (!source || !source.weapon || source.weapon === 'fists' || source.weapon === 'knuckles' || source.weapon === 'bat');
    if (h.hp <= 0 && h.fearFight) h.hp = 1;
    if (h.hp <= 0) {
      if (nonLethal && h.down <= 0 && !h.wasKO) {
        h.hp = 0;
        h.down = 18 + R.rng() * 12;
        h.wasKO = true;
        h.state = 'down';
        g.fx.text(h.x, h.y - 24, 'K.O.', '#f2e2c0');
        g.audio.sfx('ko');
        g.actors.noise(h.x, h.y, TS * 8, 'fight', source);
        if (byPlayer) R.bus.emit('player:ko', h);
      } else C.kill(h, source, kind);
      return;
    }
    // reaction to being hit
    if (h.down > 0) return;
    if (kind === 'melee' || kind === 'bullet') {
      g.actors.noise(h.x, h.y, TS * 7, kind === 'melee' ? 'fight' : 'scream', source);
    }
    if (source && source.kind && h.state !== 'fight') {
      const brave = h.tr.brave + (h.armed ? 0.25 : 0) + (h.cop ? 1 : 0) - (kind === 'bullet' ? 0.3 : 0);
      if (brave > 0.55 || h.hostile) {
        g.actors.setFight(h, source.inCar || source);
        if (R.rng() < 0.6) g.actors.say(h, R.dialog.line('fightBack', h));
      } else if (h.hp < 45) {
        h.state = 'surrender';
        h.timer = 8;
        g.actors.say(h, R.dialog.line('beg', h));
      } else {
        g.actors.setFlee(h, source, 10);
        g.actors.say(h, R.dialog.line('hurt', h));
      }
    }
  };

  // What the law thinks of the player's violence. Self-defence is free.
  C.onPlayerHits = function (h, amt, kind) {
    const g = game();
    if (h.cop) {
      if (!h.copHit) { h.copHit = true; g.law.crime('copAssault', h.x, h.y, { victim: h }); }
      return;
    }
    const selfDefence = h.attackedPlayer || h.hostile && (h.state === 'fight' || h.tag === 'mugger' || h.tag === 'bounty');
    if (selfDefence) return;
    if (h.brawl) return; // mutual fistfight after an antagonize
    if (!h.assaulted) {
      h.assaulted = true;
      g.law.crime('assault', h.x, h.y, { victim: h });
      if (h.person) {
        h.person.opinion = Math.max(-100, h.person.opinion - 30);
        h.person.fear = Math.min(100, h.person.fear + 30);
        g.pop.remember(h.person, 'hurt', `Some goon in a fedora beat on me for no reason.`, g.pop.day);
      }
    }
  };

  C.kill = function (h, source, kind) {
    const g = game();
    if (h.dead) return;
    h.dead = true;
    h.hp = 0;
    h.down = 0;
    h.bubble = null;
    h.state = 'dead';
    h.alert = null;
    const byPlayer = source === g.player || (source && source.driver === g.player);
    if (h.kind === 'a') {
      g.fx.blood(h.x, h.y, 8);
      if (byPlayer) g.player.stats.hunted++;
      return;
    }
    g.fx.pool(h.x, h.y);
    if (kind === 'blast' || h.lastHitKind === 'blast') { g.fx.gib(h.x, h.y, h.look); h.gibbed = true; }
    if (h.person) {
      g.pop.kill(h.person, byPlayer ? 'player' : kind || 'violence');
      g.pop.addNews(h.person.city, `${g.pop.name(h.person)} (${h.person.age}) found dead. ${byPlayer ? 'Police are asking questions.' : ''}`);
      R.bus.emit('person:died', h.person, byPlayer);
    }
    if (byPlayer) {
      g.player.stats.kills++;
      const armedHostile = h.hostile && h.armed && h.drawn;
      const excessive = h.hostile && !h.armed && D.weapons[g.player.weapon] && D.weapons[g.player.weapon].gun;
      if (h.cop) g.law.crime('copMurder', h.x, h.y, { victim: h });
      else if (!h.attackedPlayer && !(h.hostile && (armedHostile || h.tag === 'mugger' || h.tag === 'bounty' || !excessive)) && !h.brawlOnly) g.law.crime(kind === 'car' ? 'manslaughter' : 'murder', h.x, h.y, { victim: h });
      const city = g.world.cityAt((h.x / TS) | 0, (h.y / TS) | 0);
      if (city) { city.fear = Math.min(100, city.fear + 4); city.heat += 3; }
      g.player.rep.infamy += h.cop ? 6 : 3;
    }
    g.actors.noise(h.x, h.y, TS * 9, 'scream', source);
    R.bus.emit('actor:died', h, byPlayer);
  };

  C.runOver = function (v, a, speed) {
    const g = game();
    if (a === g.player) {
      // one hit per bump, thrown clear of the car rather than along its path
      const now = g.clock.real;
      if (a.hitByCarT && now - a.hitByCarT < 1.2) return;
      a.hitByCarT = now;
      const away = Math.atan2(a.y - v.y, a.x - v.x);
      if (speed > 40) { g.player.hurt(Math.min(40, speed * 0.2), v, 'car'); g.player.knock(away, 60 + speed * 0.8); g.cam.shake(4); }
      else g.player.knock(away, 60);
      if (v.driver && v.driver !== g.player) { v.speed *= 0.2; v.vx *= 0.2; v.vy *= 0.2; if (v.honkT <= 0 && g.traffic.honk) g.traffic.honk(v); }
      return;
    }
    if (a.hitByCar && performance.now() - a.hitByCar < 700) return;
    a.hitByCar = performance.now();
    const dmg = speed * (a.kind === 'a' ? 0.6 : 0.45);
    // knock back
    const ang = Math.atan2(a.y - v.y, a.x - v.x);
    g.actors.moveActor(a, Math.cos(ang) * speed * 1.2, Math.sin(ang) * speed * 1.2, 0.12);
    if (a.kind === 'h') {
      g.fx.blood(a.x, a.y - 6, 4);
      g.audio.sfx('thud', a.x, a.y);
      const byPlayer = v.driver === g.player;
      if (byPlayer && !a.hostile && !a.cop) {
        if (dmg >= a.hp) {} // handled by kill -> manslaughter
        else if (!a.assaulted && speed > 70) { a.assaulted = true; g.law.crime('reckless', a.x, a.y, { victim: a, minor: true }); }
      }
      if (dmg >= a.hp) C.kill(a, v.driver || v, 'car');
      else {
        a.hp -= dmg;
        a.down = 3 + speed / 40;
        g.actors.say(a, R.dialog.line('hitByCar', a));
      }
    } else {
      C.damage(a, dmg, v.driver || v, 'car');
    }
    v.vx *= 0.9; v.vy *= 0.9;
  };

  // ---------------------------------------------------------------- attacks
  // Generic attack from any attacker (player or NPC)
  C.attack = function (att, weaponId, aimAng, target) {
    const g = game();
    const w = D.weapons[weaponId];
    if (!w) return;
    if (w.melee) return C.melee(att, w, aimAng);
    if (w.gun) return C.shoot(att, w, aimAng, target);
    if (w.thrown) return C.throwIt(att, weaponId, w, aimAng, target);
  };

  C.melee = function (att, w, ang) {
    const g = game();
    const ox = att.x + Math.cos(ang) * 8, oy = att.y - 6 + Math.sin(ang) * 8;
    g.audio.sfx('swing', att.x, att.y);
    let hit = false;
    const cands = g.actors.near(att.x, att.y, w.range + 10);
    if (att !== g.player && !g.player.inCar && !g.player.inside) cands.push(g.player);
    for (const t of cands) {
      if (t === att || t.dead || t.inCar) continue;
      const d = R.dist(att.x, att.y, t.x, t.y);
      if (d > w.range + (t.r || 4)) continue;
      const a = Math.atan2(t.y - att.y, t.x - att.x);
      if (Math.abs(R.angDiff(ang, a)) > 1.1 && d > 8) continue;
      let dmg = w.dmg * (att.power || 1) * (0.85 + R.rng() * 0.3);
      if (t.down > 0 && att === g.player) dmg *= 2.2;
      C.damage(t, dmg, att, 'melee');
      if (t !== g.player && t.kind === 'h' && !t.dead) g.actors.moveActor(t, Math.cos(a) * w.knock, Math.sin(a) * w.knock, 0.12);
      g.fx.hit(t.x, t.y - 10);
      g.audio.sfx(w === D.weapons.knife ? 'stab' : 'punch', t.x, t.y);
      hit = true;
      // hitstop: a few frames of freeze sells the impact
      if (att === g.player) { g.cam.shake(1.5 + w.dmg / 12); g.hitStop = Math.max(g.hitStop || 0, 0.035 + Math.min(0.05, w.dmg / 600)); }
      else if (t === g.player) g.hitStop = Math.max(g.hitStop || 0, 0.03);
      break;
    }
    if (!hit && att === g.player) {
      // hit cars / world
      const v = g.traffic.nearestCar(ox, oy, 14);
      if (v && !v.wrecked) {
        g.traffic.damage(v, w.dmg * 0.4, att);
        g.fx.sparks(ox, oy, 3);
        g.audio.sfx('bump', ox, oy);
        if (v.parked || (v.driver && !v.driver.dead)) {
          if (v.driver && v.driver.kind === 'h' && v.driver !== g.player) {
            v.dentCount = (v.dentCount || 0) + 1;
            if (v.dentCount === 2) g.traffic.aggrieved(v, 50);
          } else if (v.parked) {
            v.dentCount = (v.dentCount || 0) + 1;
            if (v.dentCount >= 3 && !v.vandalReported) { v.vandalReported = true; g.law.crime('vandalism', v.x, v.y, { minor: true }); }
          }
        }
      }
    }
    return hit;
  };

  C.shoot = function (att, w, ang, target) {
    const g = game();
    if (att === g.player && g.player.cool > 0 && g.player.coolOn) w = Object.assign({}, w, { spread: 0 });
    const n = w.pellets || 1;
    // bullets leave the muzzle of the gun actually drawn in their hand
    const [sx, sy] = R.art.muzzle && !att.inCar ? R.art.muzzle(att, att.weapon, ang) : [att.x + Math.cos(ang) * 8, att.y - 10 + Math.sin(ang) * 6];
    g.fx.flash(sx, sy);
    g.audio.sfx(w === D.weapons.shotgun ? 'shotgun' : w === D.weapons.chopper ? 'smg' : w === D.weapons.rifle ? 'rifle' : 'shot', att.x, att.y);
    g.actors.noise(att.x, att.y, TS * 22 * (w.loud || 1), 'gunshot', att);
    if (att === g.player) {
      g.cam.shake(w.pellets ? 3 : 1.5);
      g.law.shotsFired(att.x, att.y);
    }
    const skill = att === g.player ? 1 : att.cop ? 0.75 : 0.55;
    for (let p = 0; p < n; p++) {
      const spread = w.spread + (1 - skill) * 0.12 + (att.drunk ? 0.1 : 0);
      const a = ang + (R.rng() - 0.5) * spread * 2;
      C.ray(att, sx, sy, a, w.range, w.dmg);
    }
  };

  C.ray = function (att, sx, sy, a, range, dmg) {
    const g = game(), world = g.world;
    const dx = Math.cos(a), dy = Math.sin(a);
    let ex = sx + dx * range, ey = sy + dy * range;
    let hitT = null;
    const step = 4;
    const cands = g.actors.near(sx + dx * range * 0.5, sy + dy * range * 0.5, range * 0.5 + 20);
    const pl = g.player;
    if (att !== pl && !pl.inside) cands.push(pl.inCar || pl);
    const cars = g.traffic.hash.query(sx + dx * range * 0.5, sy + dy * range * 0.5, range * 0.5 + 40);
    for (let d = 6; d < range; d += step) {
      const x = sx + dx * d, y = sy + dy * d;
      const tx = (x / TS) | 0, ty = ((y + 8) / TS) | 0;
      const t = world.t(tx, ty);
      if (t === T.BLDG || t === T.ROCK || t === T.WALL || t === T.VOID) {
        ex = x; ey = y;
        g.fx.sparks(x, y, 2);
        const b = world.buildingAt(tx, ty);
        if (b && att === pl) g.env.damageBuilding(b, 0.5, att);
        break;
      }
      const o = world.o(tx, ty);
      if (o === D.O.LAMP && R.dist(x, y + 8, tx * TS + 8, ty * TS + 4) < 5) {
        g.env.shootLamp(tx, ty);
      }
      if (o === D.O.BARREL && R.dist(x, y + 8, tx * TS + 8, ty * TS + 8) < 7) {
        world.setO(tx, ty, 0);
        C.explosion(tx * TS + 8, ty * TS + 8, 36, 60, att);
        ex = x; ey = y;
        break;
      }
      for (const c of cars) {
        if (c.removed || c.wrecked || c === att.inCar) continue;
        const rx = x - c.x, ry = y + 6 - c.y;
        const cc = Math.cos(c.angle), ss = Math.sin(c.angle);
        if (Math.abs(rx * cc + ry * ss) < c.model.w * 0.5 && Math.abs(-rx * ss + ry * cc) < c.model.h * 0.5) {
          // the occupant may get hit
          if (c.driver && R.rng() < 0.35) C.damage(c.driver === pl ? pl : c.driver, dmg * 0.6, att, 'bullet');
          g.traffic.damage(c, dmg * 0.25, att);
          g.fx.sparks(x, y, 2);
          hitT = c;
          break;
        }
      }
      if (hitT) { ex = x; ey = y; break; }
      for (const t of cands) {
        if (t === att || t.dead || t.inCar || (t.kind === 'a' && t.flying && R.rng() < 0.5)) continue;
        if (t.kind === 'v') continue;
        if (hitHuman(t, x, y)) {
          const head = t.kind === 'h' && y < t.y - 13;
          C.damage(t, dmg * (head ? 1.8 : 1), att, 'bullet');
          if (head && att === pl) g.fx.text(t.x, t.y - 26, 'HEADSHOT', '#e4a92a');
          hitT = t;
          break;
        }
      }
      if (hitT) { ex = x; ey = y; break; }
    }
    g.fx.tracer(sx, sy, ex, ey);
  };

  C.throwIt = function (att, id, w, ang, target) {
    const g = game();
    let dist = w.range;
    if (target) dist = Math.min(w.range, R.dist(att.x, att.y, target.x, target.y));
    const tx = att.x + Math.cos(ang) * dist, ty = att.y + Math.sin(ang) * dist;
    C.projectiles.push({ id, x: att.x, y: att.y - 10, sx: att.x, sy: att.y - 10, tx, ty, t: 0, dur: 0.55 + dist / 400, owner: att, fuse: id === 'dynamite' ? 2.2 : 0 });
    g.audio.sfx('swing', att.x, att.y);
  };

  C.update = function (dt) {
    const g = game();
    // the wounded leave a trail
    for (const a of g.actors.list) if (a.kind === 'h' && !a.dead && a.hp < 45 && R.rng() < dt * (a.moving || a.state === 'flee' ? 3 : 0.6)) g.fx.blood(a.x + (R.rng() - 0.5) * 3, a.y - 4, 1);
    for (const p of C.projectiles) {
      p.t += dt;
      const k = Math.min(1, p.t / p.dur);
      p.x = R.lerp(p.sx, p.tx, k);
      p.y = R.lerp(p.sy, p.ty, k) - Math.sin(k * Math.PI) * 26;
      if (k >= 1 && !p.landed) {
        p.landed = true;
        if (p.id === 'molotov') {
          g.fx.shatter(p.tx, p.ty);
          g.env.ignite(p.tx, p.ty, 1.8, p.owner);
          for (const a of g.actors.near(p.tx, p.ty, 26)) C.damage(a, 12, p.owner, 'fire'), (a.kind === 'h' && !a.dead && (a.burning = 4));
          if (!g.player.inCar && R.dist(g.player.x, g.player.y, p.tx, p.ty) < 22) g.player.hurt(10, p.owner, 'fire');
          g.actors.noise(p.tx, p.ty, TS * 10, 'blast', p.owner);
          p.done = true;
          if (p.owner === g.player) g.law.crime('arson', p.tx, p.ty, { minor: true });
        }
      }
      if (p.landed && p.id === 'dynamite') {
        p.fuse -= dt;
        if (R.rng() < 0.5) g.fx.spark1(p.tx, p.ty - 4);
        if (p.fuse <= 0) {
          C.explosion(p.tx, p.ty, 52, 120, p.owner);
          p.done = true;
        }
      }
    }
    C.projectiles = C.projectiles.filter((p) => !p.done);
    // burning people
    for (const a of g.actors.list) {
      if (a.burning > 0 && !a.dead) {
        a.burning -= dt;
        a.hp -= dt * 14;
        if (R.rng() < 0.4) g.fx.flame(a.x, a.y - 8);
        if (a.state !== 'flee' && a.kind === 'h') g.actors.setFlee(a, a, 3);
        if (a.hp <= 0) C.kill(a, a.lastHitBy, 'fire');
      }
    }
  };

  C.explosion = function (x, y, radius, dmg, owner, isCar, spareOwner) {
    const g = game();
    g.fx.boom(x, y, radius);
    g.audio.sfx('boom', x, y);
    g.cam.shake(R.clamp(10 - R.dist(x, y, g.player.x, g.player.y) / 30, 2, 10));
    g.actors.noise(x, y, TS * 28, 'blast', owner);
    for (const a of g.actors.near(x, y, radius + 10)) {
      const d = R.dist(x, y, a.x, a.y);
      const f = 1 - d / (radius + 10);
      if (f > 0) C.damage(a, dmg * f, owner, 'blast');
      if (!a.dead && a.kind === 'h') { a.down = Math.max(a.down, 2); g.actors.moveActor(a, (a.x - x) * 4, (a.y - y) * 4, 0.2); }
    }
    for (const v of g.traffic.hash.query(x, y, radius + 20)) {
      if (v.wrecked) continue;
      const d = R.dist(x, y, v.x, v.y);
      const f = 1 - d / (radius + 20);
      if (f > 0) { g.traffic.damage(v, dmg * f * 1.2, owner); v.vx += (v.x - x) * f * 5; v.vy += (v.y - y) * f * 5; }
    }
    const pl = g.player;
    const pd = R.dist(x, y, pl.x, pl.y);
    if (spareOwner && owner === pl) {} // the ring's hard light never turns on its wearer
    else if (pd < radius + 10 && !isCar) pl.hurt(dmg * (1 - pd / (radius + 10)), owner, 'blast');
    else if (pd < radius && isCar) pl.hurt(30 * (1 - pd / radius), owner, 'blast');
    // world: fire, trees, buildings
    if (!spareOwner) g.env.ignite(x, y, radius / TS, owner);
    const tr = Math.ceil(radius / TS);
    const tx0 = (x / TS) | 0, ty0 = (y / TS) | 0;
    const hitB = new Set();
    for (let yy = ty0 - tr; yy <= ty0 + tr; yy++)
      for (let xx = tx0 - tr; xx <= tx0 + tr; xx++) {
        if (R.dist(xx, yy, tx0, ty0) > tr) continue;
        const o = g.world.o(xx, yy);
        if (o === D.O.TREE || o === D.O.PINE || o === D.O.PALM) g.world.setO(xx, yy, D.O.STUMP);
        else if (o && o !== D.O.STUMP) { g.world.setO(xx, yy, 0); g.fx.debris(xx * TS + 8, yy * TS + 8, o); }
        const b = g.world.buildingAt(xx, yy);
        if (b) hitB.add(b);
      }
    for (const b of hitB) g.env.damageBuilding(b, dmg * 0.5, owner);
    if (owner === pl && !isCar && !spareOwner) g.law.crime('explosion', x, y, {});
  };

  // ---------------------------------------------------------------- NPC fighting AI
  C.npcFight = function (h, dt) {
    const g = game();
    const pl = g.player;
    let tg = h.target;
    if (tg && tg.inCar && tg !== pl) tg = tg.inCar;
    if (tg === pl && pl.inCar) tg = pl.inCar;
    if (!tg || tg.dead || tg.removed || (tg === pl && (pl.dead || pl.inside)) || (tg === pl && pl.arrested)) {
      h.state = 'idle';
      h.timer = 2;
      h.target = null;
      return;
    }
    // cops at level 1 try to arrest rather than shoot
    if (h.cop && tg === pl && g.law.wantsArrest()) return g.law.copArrest(h, dt);
    const w = D.weapons[h.weapon];
    const d = R.dist(h.x, h.y, tg.x, tg.y);
    const ang = Math.atan2(tg.y - h.y, tg.x - h.x);
    h.ang = ang;
    h.dir = R.dir4(Math.cos(ang), Math.sin(ang));
    h.drawn = true;
    h.atkT = (h.atkT || 0) - dt;
    if (h.swingT > 0) h.swingT -= dt;
    const runSpeed = 68 * (h.cop ? 1.05 : 1);
    // give up if the fight is going badly (non-cops)
    if (!h.cop && h.hp < 30 && h.tr.brave < 0.8 && !h.hostileLocked) {
      h.state = 'surrender';
      h.timer = 6;
      g.actors.say(h, R.dialog.line('beg', h));
      return;
    }
    if (w.melee || (w.gun && h.ammo <= 0)) {
      if (d > w.range) {
        g.actors.moveActor(h, Math.cos(ang) * runSpeed, Math.sin(ang) * runSpeed, dt);
        h.walk += dt * 20;
      } else if (h.atkT <= 0) {
        h.atkT = w.rate * 2.2 + R.rng() * 0.5;
        h.swingT = 0.22; h.swingN = (h.swingN || 0) + 1;
        C.melee(h, w.gun ? D.weapons.fists : w, ang);
      }
      return;
    }
    // gunfighter: keep medium distance, strafe, shoot when in sight
    const ideal = w === D.weapons.shotgun ? 50 : 90;
    const los = g.world.los(h.x, h.y - 8, tg.x, tg.y - 8);
    let mx = 0, my = 0;
    if (!los || d > w.range * 0.9) { mx = Math.cos(ang); my = Math.sin(ang); }
    else if (d < ideal * 0.6) { mx = -Math.cos(ang); my = -Math.sin(ang); }
    else { h.strafe = h.strafe || (R.rng() < 0.5 ? 1 : -1); mx = Math.cos(ang + Math.PI / 2 * h.strafe) * 0.6; my = Math.sin(ang + Math.PI / 2 * h.strafe) * 0.6; if (R.rng() < dt * 0.4) h.strafe *= -1; }
    if (mx || my) { g.actors.moveActor(h, mx * runSpeed * 0.8, my * runSpeed * 0.8, dt); h.walk += dt * 15; }
    if (los && d < w.range && h.atkT <= 0) {
      h.atkT = w.rate * (h.cop ? 2.4 : 3) + R.rng() * 0.8;
      h.clipLeft = h.clipLeft === undefined ? w.clip : h.clipLeft;
      if (h.clipLeft <= 0) { h.clipLeft = w.clip; h.atkT = 1.6; return; }
      h.clipLeft--;
      h.ammo--;
      C.shoot(h, w, ang, tg);
    }
  };
})();
