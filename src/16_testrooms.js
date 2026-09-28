// RHAPSODY — test rooms (Menu > Debug > Test rooms). Purpose-built areas carved into an
// empty corner of the countryside for repeatable visual and systems playtests:
//   gallery — every weapon and pose in eight directions, every car, every junk prop
//   arena   — waves of fists, blades, bats and guns around crates for cover
//   yard    — every car model on open tarmac, cones, a pond to drive into
//   fire    — a grass field with wooden cabins, trees and a pile of gas and molotovs
//   stealth — a lamplit night yard with patrolling guards, bushes and crates
//   water   — a pond with a pier, reeds and a rowboat's worth of shoreline
'use strict';
(function () {
  const D = R.data, T = D.T, O = D.O, TS = R.TILE;
  const TR = (R.testRooms = { spots: {} });
  const RW = 40, RH = 28; // room size in tiles

  // somewhere open and far from any town
  TR.site = function (g) {
    if (this.base && this.baseWorld === g.world) return this.base;
    const w = g.world;
    const ok = (x, y) => { for (let yy = y - 2; yy < y + RH * 2 + 6; yy += 2) for (let xx = x - 2; xx < x + RW * 3 + 10; xx += 2) { if (!w.inb(xx, yy) || w.cityAt(xx, yy) || D.waterTile[w.t(xx, yy)] || D.roadTile[w.t(xx, yy)] || w.t(xx, yy) === T.BLDG) return false; } return true; };
    for (let tries = 0; tries < 4000; tries++) {
      const x = 10 + ((R.rng() * (w.W - RW * 3 - 30)) | 0), y = 10 + ((R.rng() * (w.TH - RH * 2 - 30)) | 0);
      if (ok(x, y)) { this.base = { x, y }; this.baseWorld = w; return this.base; }
    }
    this.base = { x: 20, y: 20 }; this.baseWorld = w;
    return this.base;
  };
  const ROOMS = ['gallery', 'arena', 'yard', 'fire', 'stealth', 'water'];
  TR.origin = function (g, room) {
    const b = this.site(g), i = ROOMS.indexOf(room);
    return { x: b.x + (i % 3) * (RW + 4), y: b.y + Math.floor(i / 3) * (RH + 4) };
  };
  // clear a room: flat floor, fence around, nobody inside
  TR.carve = function (g, o, floor, fence) {
    const w = g.world;
    for (let y = o.y - 1; y <= o.y + RH; y++) for (let x = o.x - 1; x <= o.x + RW; x++) {
      const edge = x === o.x - 1 || y === o.y - 1 || x === o.x + RW || y === o.y + RH;
      w.setT(x, y, edge ? T.GRASS : floor);
      w.setO(x, y, edge && fence && !(y === o.y + RH && Math.abs(x - (o.x + RW / 2)) < 2) ? O.FENCE : 0);
    }
    for (const a of g.actors.list.slice()) if (a !== g.player && a.x > (o.x - 2) * TS && a.x < (o.x + RW + 2) * TS && a.y > (o.y - 2) * TS && a.y < (o.y + RH + 2) * TS) g.actors.remove(a);
    for (const v of g.traffic.list.slice()) if (v !== g.player.inCar && v.x > (o.x - 2) * TS && v.x < (o.x + RW + 2) * TS && v.y > (o.y - 2) * TS && v.y < (o.y + RH + 2) * TS) g.traffic.remove(v);
    if (R.art.chunkCache) R.art.chunkCache.clear();
    g.miniDirty = true;
  };
  const place = (g, x, y) => { const pl = g.player; if (pl.room) g.interiors.exit(); if (pl.inCar) pl.exitCar(); pl.place(x * TS + 8, y * TS + 8); g.cam.x = pl.x; g.cam.y = pl.y; };
  const mannequin = (g, x, y, pose) => {
    const h = g.actors.makeHuman(x * TS + 8, y * TS + 8, { arch: 'friendly', cash: 0, weapon: pose.weapon && R.data.weapons[pose.weapon] ? pose.weapon : undefined });
    h.keep = true; h.stay = true; h.state = 'idle'; h.timer = 1e9; h.testPose = pose; h.strangerName = pose.label || 'Mannequin';
    return h;
  };

  TR.go = function (g, room) {
    const o = this.origin(g, room);
    const cx = o.x + (RW >> 1), cy = o.y + (RH >> 1);
    const pl = g.player, w = g.world;
    g.ui.closeSheet();
    this.active = room;
    if (room === 'gallery') {
      this.carve(g, o, T.PLAZA, true);
      // weapons and poses: one row each, eight facings
      const rows = [
        { weapon: 'revolver' }, { weapon: 'shotgun' }, { weapon: 'rifle' }, { weapon: 'chopper' },
        { weapon: 'bat' }, { weapon: 'knife' }, { held: 'bottle' }, { held: 'pipe' }, { held: 'tv' },
        { pose: 'h', label: 'Hands up' }, { pose: 'p1', label: 'Punch' }, { pose: 'b2', label: 'Swing' },
      ];
      rows.forEach((r, i) => { for (let d = 0; d < 8; d++) mannequin(g, o.x + 2 + (i % 2) * 18 + d * 2, o.y + 2 + Math.floor(i / 2) * 2, Object.assign({ ang: d * Math.PI / 4 }, r)); });
      // every car
      Object.keys(D.vehicles).forEach((k, i) => { const m = D.vehicles[k]; g.traffic.make(k, (o.x + 4 + (i % 4) * 9) * TS, (o.y + 16 + Math.floor(i / 4) * 3) * TS, 0, { parked: true, keep: true, color: m.colors[0] }); });
      // junk props
      const props = Object.keys(R.old.props || {}).slice(0, 32);
      props.forEach((k, i) => { try { R.props.drop(k, (o.x + 2 + (i % 16) * 2.2) * TS, (o.y + RH - 2 - Math.floor(i / 16) * 1.5) * TS); } catch (e) { /* not a droppable prop */ } });
      for (let x = o.x + 4; x < o.x + RW - 2; x += 8) w.setO(x, o.y + 14, O.LAMP);
      place(g, cx, o.y + 14);
      g.ui.toast('Gallery: every weapon, pose, car and prop. Try Noon / Midnight in the debug menu.', 'good');
    }
    if (room === 'arena') {
      this.carve(g, o, T.DIRT, true);
      for (let i = 0; i < 14; i++) w.setO(o.x + 3 + ((R.rng() * (RW - 6)) | 0), o.y + 3 + ((R.rng() * (RH - 6)) | 0), R.rng() < 0.5 ? O.CRATE : O.BARREL);
      for (const id of ['knuckles', 'bat', 'knife', 'revolver', 'magnum', 'shotgun', 'chopper', 'rifle']) pl.giveWeapon(id);
      Object.assign(pl.inv.ammo, { pistol: 200, shells: 80, smg: 300, rifle: 60 });
      pl.hp = pl.maxHp;
      place(g, cx, o.y + RH - 3);
      this.waves = [{ n: 4, w: [null] }, { n: 4, w: ['knife', 'bat'] }, { n: 4, w: ['revolver', 'shotgun'] }, { n: 3, w: ['chopper', 'magnum'] }];
      this.waveT = 2; this.wave = 0; this.arena = o; this.foes = []; this.cleared = false;
      g.ui.toast('Arena: four waves. Fists, then blades and bats, then guns.', 'warn');
    }
    if (room === 'yard') {
      this.carve(g, o, T.ROAD, true);
      for (let y = o.y + RH - 9; y < o.y + RH - 2; y++) for (let x = o.x + RW - 12; x < o.x + RW - 2; x++) if ((x - (o.x + RW - 7)) ** 2 / 25 + (y - (o.y + RH - 5.5)) ** 2 / 12 < 1) w.setT(x, y, T.WATER);
      for (let k = 0; k < 10; k++) w.setO(o.x + 6 + k * 3, o.y + RH - 12, O.CONE);
      Object.keys(D.vehicles).forEach((k, i) => g.traffic.make(k, (o.x + 5 + (i % 4) * 9) * TS, (o.y + 3 + Math.floor(i / 4) * 4) * TS, 0, { parked: true, keep: true }));
      place(g, o.x + 14, o.y + 9);
      g.ui.toast('Vehicle yard: every model, cones and a pond.', 'good');
    }
    if (room === 'fire') {
      this.carve(g, o, T.GRASS, true);
      const c = w.countyCity ? w.countyCity() : w.cities[0];
      const rnd = R.mulberry(7);
      for (let i = 0; i < 3; i++) { const b = w.addBuilding(c, 'cabin', o.x + 4 + i * 12, o.y + 4, 4, 3, 'S', rnd); b.name = `Test Cabin ${i + 1}`; }
      for (let i = 0; i < 30; i++) w.setO(o.x + 2 + ((R.rng() * (RW - 4)) | 0), o.y + 11 + ((R.rng() * (RH - 14)) | 0), R.rng() < 0.6 ? O.TREE : O.BUSH);
      for (let y = o.y + 11; y < o.y + RH - 1; y++) for (let x = o.x + RW - 10; x < o.x + RW - 1; x++) w.setT(x, y, T.FIELD);
      pl.inv.tools.gascan = (pl.inv.tools.gascan || 0) + 3;
      pl.inv.ammo.molotov = (pl.inv.ammo.molotov || 0) + 10;
      pl.giveWeapon && pl.giveWeapon('molotov');
      place(g, o.x + 6, o.y + 9);
      g.ui.toast('Fire lab: three cabins, trees and a wheat field. You have 10 molotovs and 3 gas cans.', 'good');
    }
    if (room === 'stealth') {
      this.carve(g, o, T.LOT, true);
      for (let x = o.x + 4; x < o.x + RW - 2; x += 9) for (let y = o.y + 5; y < o.y + RH - 2; y += 9) w.setO(x, y, O.LAMP);
      for (let i = 0; i < 24; i++) w.setO(o.x + 2 + ((R.rng() * (RW - 4)) | 0), o.y + 2 + ((R.rng() * (RH - 4)) | 0), [O.BUSH, O.CRATE, O.BARREL, O.BUSH][i % 4]);
      g.clock.t = Math.floor(g.clock.t / 1440) * 1440 + 1440 + 23 * 60;
      this.guards = [];
      for (let i = 0; i < 4; i++) {
        const gd = g.actors.makeHuman((o.x + 8 + i * 8) * TS, (o.y + 6 + (i % 2) * 12) * TS, { faction: 'Castellano', weapon: 'revolver', arch: 'tough' });
        gd.keep = true; gd.strangerName = 'Guard'; gd.patrol = [{ x: gd.x, y: gd.y }, { x: gd.x + TS * 6 * (i % 2 ? -1 : 1), y: gd.y + TS * 5 }]; gd.patrolI = 0; gd.testGuard = true;
        this.guards.push(gd);
      }
      g.jobs.standing.Castellano = -60; // they shoot on sight
      pl.sneak = false;
      place(g, o.x + 3, o.y + 8);
      g.ui.toast('Stealth range: four guards shoot on sight. SNEAK and stand still to vanish.', 'warn');
    }
    if (room === 'water') {
      this.carve(g, o, T.GRASS, true);
      for (let y = o.y + 3; y < o.y + RH - 3; y++) for (let x = o.x + 6; x < o.x + RW - 6; x++) { const e = (x - cx) ** 2 / 170 + (y - cy) ** 2 / 60; if (e < 1) w.setT(x, y, e < 0.45 ? T.DEEP : T.WATER); else if (e < 1.2) w.setT(x, y, T.SAND); }
      for (let x = o.x + 4; x < cx; x++) w.setT(x, cy, T.DOCK);
      for (let i = 0; i < 16; i++) { const a = R.rng() * 6.28; w.setO(Math.round(cx + Math.cos(a) * 14), Math.round(cy + Math.sin(a) * 8.5), O.REED); }
      g.traffic.make('pickup', (o.x + 3) * TS, (cy - 3) * TS, 0, { parked: true, keep: true });
      place(g, o.x + 4, cy + 2);
      g.ui.toast('Water: a pond, a pier and a pickup to drive in.', 'good');
    }
  };

  // live behaviour: arena waves and patrolling guards
  TR.update = function (g, dt) {
    if (this.active === 'arena' && this.waves && this.arena) {
      const alive = this.foes.filter((f) => !f.dead && !(f.down > 0));
      if (!alive.length) {
        this.waveT -= dt;
        if (this.waveT <= 0 && this.wave < this.waves.length) {
          const wv = this.waves[this.wave++], o = this.arena;
          for (let i = 0; i < wv.n; i++) {
            const a = R.rng() * 6.28, pl = g.player;
            const h = g.actors.makeHuman(R.clamp(pl.x + Math.cos(a) * TS * 9, (o.x + 1) * TS, (o.x + RW - 1) * TS), R.clamp(pl.y + Math.sin(a) * TS * 6, (o.y + 1) * TS, (o.y + RH - 1) * TS), { weapon: R.rng.pick(wv.w) || undefined, arch: 'tough' });
            h.keep = true; h.hostile = true; h.tr.brave = 1; g.actors.setFight(h, g.player); this.foes.push(h);
          }
          g.ui.toast(`Wave ${this.wave} of ${this.waves.length}`, 'bad');
          this.waveT = 4;
        } else if (this.wave >= this.waves.length && this.waveT <= 0 && !this.cleared) { this.cleared = true; g.ui.toast('Arena cleared.', 'good'); }
      }
    }
    if (this.active === 'stealth' && this.guards) for (const gd of this.guards) {
      if (gd.dead || gd.state === 'fight' || !gd.patrol) continue;
      const tgt = gd.patrol[gd.patrolI];
      const dx = tgt.x - gd.x, dy = tgt.y - gd.y, d = Math.hypot(dx, dy);
      if (d < 4) { gd.patrolI = 1 - gd.patrolI; continue; }
      gd.state = 'idle'; gd.timer = 1;
      g.actors.moveActor(gd, dx / d * 24, dy / d * 24, dt);
      gd.walk += dt * 8; gd.dir = R.dir4(dx, dy); gd.ang = Math.atan2(dy, dx);
    }
  };
})();
