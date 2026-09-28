// RHAPSODY — cover and suppression. Stand still with a weapon out beside anything solid (a
// wall, a rock, a desk, a crate, a parked car) and you're in cover: shots coming from that
// side mostly smack into it instead of you (crouch for more). You can blind-fire from cover,
// less accurately unless you're Cool. Near misses pin people down: a suppressed gunman stops
// advancing, fires slower and keeps his head low, and a timid one breaks.
'use strict';
(function () {
  const D = R.data, T = D.T, O = D.O, TS = R.TILE;
  const G = () => R.game;
  const CV = (R.cover = { dir: null, t: 0 });
  const HARD = new Set([T.BLDG, T.WALL, T.ROCK]);
  const OBJ = new Set(['DESK', 'COUNTER', 'CRATE', 'TABLE', 'CABINET', 'SAFE', 'BARREL', 'MAILBOX', 'BENCH', 'BOULDER', 'SHELF', 'HYDRANT', 'STUMP', 'TREE', 'PINE', 'PALM', 'DEADTREE', 'FENCE', 'PUMP', 'TRASH', 'PEW', 'SOFA', 'LOCKER', 'POOL', 'CARDTABLE', 'PIANO', 'FRIDGE', 'BOOKCASE', 'SLOT', 'ARCADE', 'ALTAR', 'REGISTER', 'VAULT'].map((k) => O[k]).filter((v) => v != null));

  // the side you're covered from, if any
  CV.find = function (pl) {
    const g = G(), w = g.world;
    let best = null;
    for (let k = 0; k < 8; k++) {
      const a = k * Math.PI / 4, dx = Math.cos(a), dy = Math.sin(a);
      const x = pl.x + dx * 11, y = pl.y + dy * 9;
      const tx = (x / TS) | 0, ty = (y / TS) | 0;
      if (!w.inb(tx, ty)) continue;
      const solid = HARD.has(w.t(tx, ty)) || OBJ.has(w.o(tx, ty));
      if (solid) { best = a; break; }
      const v = g.traffic.nearestCar(x, y, 12);
      if (v && !v.removed && v !== pl.inCar && Math.hypot(v.x - pl.x, v.y - pl.y) < TS * 1.6) { best = Math.atan2(v.y - pl.y, v.x - pl.x); break; }
    }
    return best;
  };
  CV.update = function (dt) {
    const g = G(), pl = g.player;
    if (!g.started || pl.dead || pl.inCar || pl.room && pl.room.b.type === 'none') { this.dir = null; return; }
    const armed = pl.weaponOut && pl.weapon && D.weapons[pl.weapon] && (D.weapons[pl.weapon].gun || D.weapons[pl.weapon].ring);
    const moved = this.px != null && Math.hypot(pl.x - this.px, pl.y - this.py) > 0.2;
    this.px = pl.x; this.py = pl.y;
    this.stillT = moved ? 0 : (this.stillT || 0) + dt;
    const still = this.stillT > 0.12;
    this.t -= dt;
    if (this.t <= 0) { this.t = 0.15; this.dir = armed && still ? this.find(pl) : null; }
    if (this.dir != null && !this.was) { this.was = true; g.fx.text(pl.x, pl.y - 28, 'COVER', '#c8c0b0'); }
    if (this.dir == null) this.was = false;
    // suppression wears off
    for (const a of g.actors.near(pl.x, pl.y, TS * 20)) if (a.suppT > 0) { a.suppT -= dt; if (a.suppT <= 0) a.supp = 0; }
  };
  // does the cover stop a shot from this attacker?
  CV.blocks = function (src) {
    const g = G(), pl = g.player;
    if (this.dir == null || !src || src === pl) return false;
    const d = Math.hypot(src.x - pl.x, src.y - pl.y);
    if (d < TS * 2) return false; // point blank: they're around it
    let da = Math.atan2(src.y - pl.y, src.x - pl.x) - this.dir;
    while (da > Math.PI) da -= 2 * Math.PI; while (da < -Math.PI) da += 2 * Math.PI;
    if (Math.abs(da) > 1.15) return false; // flanked
    return R.rng() < (pl.sneak ? 0.9 : 0.8);
  };

  CV.init = function () {
    if (this.wired) return;
    this.wired = true;
    const C = R.combat;
    // shots into cover
    const bDmg = C.damage;
    C.damage = function (t, amt, src, kind) {
      const g = G();
      if (t === g.player && kind === 'bullet' && CV.blocks(src)) {
        const x = g.player.x + Math.cos(CV.dir) * 9, y = g.player.y - 8 + Math.sin(CV.dir) * 6;
        g.fx.sparks(x, y, 3);
        if (R.rng() < 0.3) g.fx.text(x, y - 8, R.rng.pick(['TINK', 'PANG', 'THWACK']), '#c8c0b0');
        return;
      }
      return bDmg.apply(this, arguments);
    };
    // blind fire, and near misses that pin people down
    const bShoot = C.shoot;
    C.shoot = function (att, w, ang, target) {
      const g = G();
      if (att === g.player && CV.dir != null && !(g.player.coolOn && g.player.cool > 0)) w = Object.assign({}, w, { spread: (w.spread || 0) + 0.1 });
      return bShoot.call(this, att, w, ang, target);
    };
    const bRay = C.ray;
    C.ray = function (att, sx, sy, a, range, dmg) {
      const g = G(), pl = g.player;
      const r = bRay.apply(this, arguments);
      if (att === pl) {
        const dx = Math.cos(a), dy = Math.sin(a);
        for (const h of g.actors.near(sx + dx * range * 0.5, sy + dy * range * 0.5, range * 0.5 + 20)) {
          if (h.kind !== 'h' || h.dead || h === pl || h.crew || !h.hostile) continue;
          const px = h.x - sx, py = h.y - 10 - sy, along = px * dx + py * dy;
          if (along < 0 || along > range) continue;
          const off = Math.abs(px * dy - py * dx);
          if (off < 18 && off > 4) {
            h.supp = Math.min(4, (h.supp || 0) + 1); h.suppT = 2.5;
            if (h.supp >= 2 && !h.suppSaid) { h.suppSaid = true; g.actors.say(h, R.rng.pick(['I\'m pinned!', 'Keep your head down!', 'Covering! COVERING!', 'Jesus, he\'s everywhere!'])); setTimeout(() => { h.suppSaid = false; }, 5000); }
            if (h.supp >= 3 && !h.cop && !h.hostileLocked && h.tr && h.tr.brave < 0.5 && R.rng() < 0.35) g.actors.setCower(h, pl, 3);
          }
        }
      }
      return r;
    };
    // a suppressed gunman holds still and shoots slower
    const bFight = C.npcFight;
    C.npcFight = function (h, dt) {
      if (h.suppT > 0 && h.supp >= 2) {
        const g = G(), ax = h.x, ay = h.y;
        const r = bFight.apply(this, arguments);
        h.x = ax + (h.x - ax) * 0.15; h.y = ay + (h.y - ay) * 0.15; // hunkered down
        h.atkT = (h.atkT || 0) + dt * 0.6; // head down, fewer shots
        h.crouch = true;
        return r;
      }
      h.crouch = false;
      return bFight.apply(this, arguments);
    };
    // drawn over the world: a little wall marker on your covered side, crouched NPCs
    const bDraw = R.fearQuest.draw;
    R.fearQuest.draw = function (g) {
      bDraw.apply(this, arguments);
      const game = G(), pl = game.player;
      if (CV.dir != null && !pl.inCar) {
        const x = Math.round(pl.x + Math.cos(CV.dir) * 8), y = Math.round(pl.y - 20 + Math.sin(CV.dir) * 4);
        g.fillStyle = 'rgba(20,14,10,0.7)'; g.fillRect(x - 3, y - 2, 7, 5);
        g.fillStyle = '#c8c0b0'; g.fillRect(x - 2, y - 1, 5, 3);
        g.fillStyle = '#8a8070'; g.fillRect(x - 2, y + 1, 5, 1);
      }
      for (const a of game.actors.near(pl.x, pl.y, TS * 16)) if (a.suppT > 0 && a.supp >= 2 && !a.dead) { g.fillStyle = `rgba(255,220,120,${0.5 + Math.sin(game.clock.real * 12) * 0.3})`; g.fillRect(Math.round(a.x) - 1, Math.round(a.y) - 28, 3, 1); g.fillRect(Math.round(a.x), Math.round(a.y) - 30, 1, 3); }
    };
    // hunkered-down people draw crouched
    const RP = R.Renderer.prototype, bHuman = RP.drawHuman;
    RP.drawHuman = function (g, h) {
      if (h.crouch && h.suppT > 0 && !h.dead) { const A = R.art, bD = A.drawPerson; A.drawPerson = function (gg, x, y, dir, walk, look, st) { return bD.call(this, gg, x, y, dir, walk, look, Object.assign({}, st, { crouch: true })); }; try { return bHuman.apply(this, arguments); } finally { A.drawPerson = bD; } }
      return bHuman.apply(this, arguments);
    };
  };
})();
