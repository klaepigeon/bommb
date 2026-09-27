// RHAPSODY — improvised weapons, ported from the original build: anything loose can be
// picked up, swung until it breaks, or thrown. Street furniture comes out of the
// ground, rooms have their own clutter, and every material breaks its own way.
(function () {
  const D = R.data, O = D.O, TS = R.TILE;

  // name, damage tier, reach, knockback, durability, heavy, throw power, swing ms,
  // material, special effect, where it turns up. Straight from the original's table.
  const PROPS = (D.props = {
    crate: { name: 'Crate', dmg: 1, reach: 9, kb: 100, dur: 2, throw: 1, swing: 220, mat: 'wood', where: ['harbor', 'store', 'street'] },
    bench: { name: 'Park Bench', dmg: 2, reach: 13, kb: 150, dur: 4, heavy: 1, throw: 0.7, swing: 340, mat: 'wood', fx: 'sweep', where: ['park'] },
    trashcan: { name: 'Trash Can', dmg: 2, reach: 11, kb: 130, dur: 3, heavy: 1, throw: 0.75, swing: 300, mat: 'metal', fx: 'trash', where: ['street', 'diner', 'bar'] },
    mailbox: { name: 'Mailbox', dmg: 3, reach: 12, kb: 170, dur: 2, heavy: 1, throw: 0.55, swing: 380, mat: 'metal', fx: 'mail', where: ['house'] },
    hydrant: { name: 'Fire Hydrant', dmg: 3, reach: 11, kb: 180, dur: 3, heavy: 1, throw: 0.5, swing: 400, mat: 'metal', fx: 'geyser', where: ['street'] },
    pan: { name: 'Frying Pan', dmg: 2, reach: 9, kb: 120, dur: 8, throw: 1, swing: 200, mat: 'pan', fx: 'stun', where: ['diner', 'house'] },
    bottle: { name: 'Glass Bottle', dmg: 2, reach: 8, kb: 80, dur: 1, throw: 1.25, swing: 170, mat: 'glass', fx: 'shatter', where: ['bar', 'store', 'street', 'harbor'] },
    chair: { name: 'Folding Chair', dmg: 2, reach: 10, kb: 140, dur: 3, throw: 0.9, swing: 260, mat: 'metal', fx: 'stun', where: ['bar', 'chapel', 'house'] },
    stool: { name: 'Bar Stool', dmg: 2, reach: 10, kb: 130, dur: 2, throw: 0.9, swing: 250, mat: 'wood', where: ['bar', 'diner'] },
    broom: { name: 'Broom', dmg: 1, reach: 15, kb: 90, dur: 5, throw: 1.1, swing: 240, mat: 'soft', fx: 'sweep', where: ['store', 'chapel', 'house', 'diner'] },
    plank: { name: '2x4 Plank', dmg: 2, reach: 14, kb: 130, dur: 3, throw: 1, swing: 280, mat: 'wood', fx: 'sweep', where: ['garage', 'harbor', 'lot'] },
    pipe: { name: 'Lead Pipe', dmg: 3, reach: 11, kb: 130, dur: 9, throw: 1, swing: 230, mat: 'metal', where: ['garage', 'lot'] },
    wrench: { name: 'Pipe Wrench', dmg: 2, reach: 10, kb: 120, dur: 9, throw: 1.1, swing: 210, mat: 'metal', fx: 'stun', where: ['garage'] },
    cone: { name: 'Traffic Cone', dmg: 1, reach: 10, kb: 70, dur: 6, throw: 1.3, swing: 180, mat: 'soft', fx: 'cone', where: ['street', 'lot'] },
    sign: { name: 'Stop Sign', dmg: 2, reach: 17, kb: 150, dur: 4, heavy: 1, throw: 0.8, swing: 320, mat: 'metal', fx: 'sweep', where: ['street', 'lot'] },
    guitar: { name: 'Acoustic Guitar', dmg: 2, reach: 12, kb: 130, dur: 2, throw: 0.9, swing: 260, mat: 'twang', fx: 'noisy', where: ['bar', 'house', 'chapel'] },
    fish: { name: 'Wet Fish', dmg: 1, reach: 9, kb: 60, dur: 12, throw: 1.2, swing: 160, mat: 'squish', fx: 'fish', where: ['harbor', 'diner'] },
    bowling: { name: 'Bowling Ball', dmg: 3, reach: 8, kb: 160, dur: 99, heavy: 1, throw: 1.1, swing: 320, mat: 'thud', fx: 'roll', thrownDmg: 3, where: ['house'] },
    tire: { name: 'Spare Tire', dmg: 1, reach: 10, kb: 150, dur: 99, throw: 1.2, swing: 260, mat: 'boing', fx: 'roll', where: ['garage', 'lot'] },
    barrel: { name: 'Oil Barrel', dmg: 3, reach: 11, kb: 190, dur: 3, heavy: 1, throw: 0.8, swing: 420, mat: 'metal', fx: 'roll', where: ['harbor', 'garage'] },
    propane: { name: 'Propane Tank', dmg: 2, reach: 10, kb: 140, dur: 3, heavy: 1, throw: 0.8, swing: 330, mat: 'metal', fx: 'boom', where: ['garage', 'diner', 'harbor'] },
    paint: { name: 'Paint Can', dmg: 1, reach: 9, kb: 90, dur: 2, throw: 1.1, swing: 220, mat: 'metal', fx: 'paint', where: ['garage', 'store', 'house'] },
    bucket: { name: 'Bucket of Water', dmg: 0, reach: 12, kb: 160, dur: 1, throw: 1, swing: 240, mat: 'splash', fx: 'splash', where: ['park', 'harbor', 'chapel', 'house'] },
    extinguisher: { name: 'Fire Extinguisher', dmg: 1, reach: 16, kb: 170, dur: 7, throw: 0.9, swing: 260, mat: 'hiss', fx: 'spray', where: ['clinic', 'diner', 'garage', 'store', 'police'] },
    flare: { name: 'Road Flare', dmg: 1, reach: 9, kb: 80, dur: 4, throw: 1.2, swing: 190, mat: 'soft', fx: 'flare', where: ['lot', 'police', 'harbor'] },
    plant: { name: 'Potted Plant', dmg: 2, reach: 9, kb: 100, dur: 1, throw: 1, swing: 240, mat: 'glass', fx: 'shatter', where: ['house', 'clinic', 'park', 'chapel'] },
    tv: { name: 'Old TV', dmg: 3, reach: 10, kb: 150, dur: 1, heavy: 1, throw: 0.7, swing: 380, mat: 'glass', fx: 'zap', where: ['house', 'bar'] },
    dumbbell: { name: 'Dumbbell', dmg: 3, reach: 8, kb: 140, dur: 99, heavy: 1, throw: 0.8, swing: 260, mat: 'thud', fx: 'stun', where: ['house'] },
    gnome: { name: 'Garden Gnome', dmg: 2, reach: 8, kb: 110, dur: 1, throw: 1.1, swing: 200, mat: 'glass', fx: 'shatter', where: ['house', 'park'] },
    shovel: { name: 'Shovel', dmg: 2, reach: 14, kb: 140, dur: 7, throw: 0.9, swing: 270, mat: 'pan', fx: 'stun', where: ['park', 'chapel', 'lot'] },
    lamp: { name: 'Table Lamp', dmg: 1, reach: 9, kb: 90, dur: 1, throw: 1, swing: 200, mat: 'glass', fx: 'zap', where: ['house', 'clinic'] },
    cake: { name: 'Whole Cake', dmg: 0, reach: 9, kb: 50, dur: 1, throw: 1.1, swing: 200, mat: 'squish', fx: 'cake', where: ['diner', 'store'] },
  });

  // what each building type keeps lying around
  const ROOM_TAGS = {
    bar: 'bar', club: 'bar', casino: 'bar', diner: 'diner', house: 'house', apartment: 'house', cabin: 'house', hotel: 'house', motel: 'house',
    garage: 'garage', general: 'store', liquor: 'store', pharmacy: 'store', pawn: 'store', laundry: 'store', tailor: 'store', barber: 'store', butcher: 'diner',
    church: 'chapel', hospital: 'clinic', police: 'police', warehouse: 'harbor', factory: 'garage', barn: 'lot', social: 'bar', arcade: 'store', gas: 'garage',
  };
  // street furniture you can rip out of the ground
  const FROM_OBJ = { [O.TRASH]: 'trashcan', [O.BENCH]: 'bench', [O.HYDRANT]: 'hydrant', [O.CONE]: 'cone', [O.BARREL]: 'barrel', [O.CRATE]: 'crate', [O.MAILBOX]: 'mailbox', [O.SIGNPOST]: 'sign' };
  const HIT_WORD = { wood: 'CRACK!', metal: 'CLANG!', pan: 'BONK!', glass: 'SMASH!', soft: 'FWUMP!', twang: 'TWANNG!', squish: 'SPLAT!', thud: 'THUD!', boing: 'BOING!', splash: 'SPLOOSH!', hiss: 'FSSSH!' };
  const MAT_SFX = { wood: 'thud', metal: 'bump', pan: 'bump', glass: 'glass', soft: 'punch', twang: 'bump', squish: 'punch', thud: 'thud', boing: 'bump', splash: 'splash', hiss: 'splash' };

  const sprites = {};
  const sprite = (k) => sprites[k] || (sprites[k] = R.old.props[k] ? R.old.paintProp(k) : null);

  const Props = (R.props = {
    loose: [],
    flying: [],
    game: null,
    streetT: 0,
  });

  Props.init = function (game) {
    this.game = game;
    this.loose = [];
    this.flying = [];
    this.roomsDone = new Set();
  };

  Props.drop = function (k, x, y, dur) {
    const d = PROPS[k];
    if (!d) return null;
    const p = { k, x, y, dur: dur == null ? d.dur : dur, t: 0 };
    this.loose.push(p);
    return p;
  };

  // clutter a room the first time it's entered this session
  Props.furnishRoom = function (room) {
    const b = room.b;
    if (this.roomsDone.has(b.id)) return;
    this.roomsDone.add(b.id);
    const tag = ROOM_TAGS[b.type];
    if (!tag || !room.extra.length) return;
    const pool = Object.keys(PROPS).filter((k) => PROPS[k].where.includes(tag));
    if (!pool.length) return;
    const rnd = R.mulberry(b.seedArt + 17);
    const n = 1 + Math.floor(rnd() * 3);
    for (let i = 0; i < n; i++) {
      const s = room.extra[Math.floor(rnd() * room.extra.length)];
      this.drop(pool[Math.floor(rnd() * pool.length)], s.x * TS + 4 + rnd() * 8, s.y * TS + 8 + rnd() * 4);
    }
  };

  // keep a little junk lying around the streets near the player
  Props.update = function (dt) {
    const g = this.game, pl = g.player, w = g.world;
    for (const p of this.loose) p.t += dt;
    // flying things
    for (let i = this.flying.length - 1; i >= 0; i--) {
      const f = this.flying[i];
      f.t += dt;
      f.x += f.vx * dt;
      f.y += f.vy * dt;
      f.spin += dt * 14;
      const tx = (f.x / TS) | 0, ty = ((f.y + 4) / TS) | 0;
      const t = w.t(tx, ty);
      let land = f.t > f.life || t === D.T.BLDG || t === D.T.WALL || t === D.T.VOID;
      if (!land) {
        for (const a of g.actors.near(f.x, f.y, 14)) {
          if (a === f.owner || a.dead || a.inCar) continue;
          const d = PROPS[f.k];
          const dmg = (d.thrownDmg || d.dmg) * 13 * d.throw + 4;
          R.combat.damage(a, dmg, f.owner, 'melee');
          if (a.kind === 'h' && !a.dead) { a.down = Math.max(a.down, d.heavy ? 2.5 : 1.2); g.actors.moveActor(a, f.vx * 0.2, f.vy * 0.2, 0.1); }
          this.impact(f.k, f.x, f.y, a, f.owner);
          f.dur -= 1;
          land = true;
          break;
        }
        if (!land) {
          const v = g.traffic.nearestCar(f.x, f.y, 12);
          if (v && !v.wrecked && v !== f.owner.inCar) {
            g.traffic.damage(v, PROPS[f.k].dmg * 4, f.owner);
            this.impact(f.k, f.x, f.y, null, f.owner);
            f.dur -= 1;
            land = true;
          }
        }
      }
      if (land) {
        this.flying.splice(i, 1);
        if (f.dur > 0 && !PROPS[f.k].fragile) this.drop(f.k, f.x, f.y, f.dur);
        else this.breakFx(f.k, f.x, f.y, f.owner);
      }
    }
    // ambient street junk
    this.streetT -= dt;
    if (this.streetT <= 0 && !pl.room && !pl.inCar) {
      this.streetT = 4;
      const near = this.loose.filter((p) => Math.abs(p.x - pl.x) < TS * 24 && Math.abs(p.y - pl.y) < TS * 24).length;
      if (near < 5) {
        const city = w.cityAt((pl.x / TS) | 0, (pl.y / TS) | 0);
        const s = w.findNear(pl.x / TS, pl.y / TS, 12, 20, (x, y) => { const tt = w.t(x, y); return (tt === D.T.WALK || tt === D.T.LOT || tt === D.T.PARK || tt === D.T.DOCK) && !w.o(x, y); });
        if (s) {
          const tt = w.t(s.x, s.y);
          const tag = tt === D.T.PARK ? 'park' : tt === D.T.LOT ? 'lot' : tt === D.T.DOCK ? 'harbor' : 'street';
          const pool = Object.keys(PROPS).filter((k) => PROPS[k].where.includes(tag) && !PROPS[k].heavy && !FROM_OBJ_VALUES.has(k));
          if (pool.length && (city || R.rng() < 0.3)) this.drop(R.rng.pick(pool), s.x * TS + 8, s.y * TS + 10);
        }
      }
      // forget junk far away
      this.loose = this.loose.filter((p) => p.pinned || p.y >= w.H * TS || Math.abs(p.x - pl.x) < TS * 60 && Math.abs(p.y - pl.y) < TS * 60);
    }
  };
  const FROM_OBJ_VALUES = new Set(Object.values(FROM_OBJ));

  // the nearest thing the player could grab
  Props.grabbable = function (pl) {
    const g = this.game, w = g.world;
    let best = null, bd = 16;
    for (const p of this.loose) {
      const d = Math.hypot(p.x - pl.x, p.y - pl.y);
      if (d < bd) { bd = d; best = { p }; }
    }
    if (best) return best;
    if (pl.room) return null;
    const tx = (pl.x / TS) | 0, ty = (pl.y / TS) | 0;
    for (let yy = ty - 1; yy <= ty + 1; yy++)
      for (let xx = tx - 1; xx <= tx + 1; xx++) {
        const k = FROM_OBJ[w.o(xx, yy)];
        if (k && Math.hypot(xx * TS + 8 - pl.x, yy * TS + 10 - pl.y) < 18) return { tile: { x: xx, y: yy }, k };
      }
    return null;
  };
  Props.label = function (gr) { return 'Pick up ' + PROPS[gr.p ? gr.p.k : gr.k].name; };

  Props.pickUp = function (pl, gr) {
    const g = this.game;
    if (pl.held) this.dropHeld(pl);
    if (gr.p) {
      this.loose.splice(this.loose.indexOf(gr.p), 1);
      pl.held = { k: gr.p.k, dur: gr.p.dur };
    } else {
      const k = gr.k;
      g.world.setO(gr.tile.x, gr.tile.y, 0);
      if (k === 'hydrant') g.env.geyser(gr.tile.x * TS + 8, gr.tile.y * TS + 8);
      pl.held = { k, dur: PROPS[k].dur };
    }
    const d = PROPS[pl.held.k];
    g.audio.sfx('equip');
    g.ui.toast(`${d.name}${d.heavy ? ' (heavy)' : ''}. HIT swings it, SWAP throws it, hold SWAP to drop it.`);
    if (!g.hints.improv) { g.hints.improv = 1; }
  };
  Props.dropHeld = function (pl) {
    if (!pl.held) return;
    this.drop(pl.held.k, pl.x + Math.cos(pl.ang) * 8, pl.y + Math.sin(pl.ang) * 6 + 2, pl.held.dur);
    pl.held = null;
  };

  // swing it: behaves like any melee weapon, so the law and NPCs treat it the same
  Props.swing = function (pl) {
    const g = this.game, h = pl.held, d = PROPS[h.k];
    if (pl.atkT > 0) return;
    pl.atkT = d.swing / 1000;
    pl.punchT = 0.22;
    pl.punchN = (pl.punchN || 0) + 1;
    const w = { name: d.name, melee: 1, dmg: 8 + d.dmg * 9, range: 12 + d.reach, rate: d.swing / 1000, knock: d.kb };
    const tg = pl.aimTarget();
    const ang = tg ? Math.atan2(tg.y - pl.y, tg.x - pl.x) : pl.ang;
    pl.ang = ang;
    const hits = [];
    const first = R.combat.melee(pl, w, ang);
    if (first) hits.push(1);
    // sweeping props clip a second body in the arc
    if (d.fx === 'sweep') {
      const others = g.actors.near(pl.x, pl.y, w.range + 6).filter((a) => !a.dead && !a.inCar && Math.abs(R.angDiff(ang, Math.atan2(a.y - pl.y, a.x - pl.x))) < 1.2);
      if (others.length > 1) { R.combat.damage(others[1], w.dmg * 0.6, pl, 'melee'); hits.push(1); }
    }
    if (hits.length) {
      const victim = tg && !tg.dead ? tg : null;
      this.impact(h.k, pl.x + Math.cos(ang) * 12, pl.y - 8 + Math.sin(ang) * 8, victim, pl);
      h.dur -= 1;
      if (h.dur <= 0) {
        this.breakFx(h.k, pl.x + Math.cos(ang) * 10, pl.y - 6, pl);
        g.ui.toast(`The ${d.name.toLowerCase()} broke.`);
        pl.held = null;
      }
    }
  };

  Props.throwHeld = function (pl) {
    const g = this.game, h = pl.held, d = PROPS[h.k];
    const tg = pl.aimTarget();
    const ang = tg ? Math.atan2(tg.y - pl.y, tg.x - pl.x) : pl.ang;
    const sp = 170 * d.throw;
    this.flying.push({ k: h.k, x: pl.x + Math.cos(ang) * 8, y: pl.y - 6 + Math.sin(ang) * 6, vx: Math.cos(ang) * sp, vy: Math.sin(ang) * sp, t: 0, life: 0.9 * d.throw, spin: 0, dur: h.dur, owner: pl });
    pl.held = null;
    pl.punchT = 0.22;
    g.audio.sfx('swing', pl.x, pl.y);
  };

  // what happens when it connects
  Props.impact = function (k, x, y, victim, owner) {
    const g = this.game, d = PROPS[k];
    g.fx.text(x, y - 6, HIT_WORD[d.mat] || 'WHACK!', d.mat === 'glass' ? '#a8e0f8' : '#f6ecd0');
    g.audio.sfx(MAT_SFX[d.mat] || 'punch', x, y);
    g.cam.shake(d.heavy ? 3 : 1.5);
    if (!victim || victim.kind !== 'h') return;
    switch (d.fx) {
      case 'stun': victim.down = Math.max(victim.down, 2.2); break;
      case 'fish': g.actors.say(victim, R.rng.pick(['Did you just hit me with a FISH?', 'That smells awful!', 'A fish? Really?'])); break;
      case 'cake': g.actors.say(victim, R.rng.pick(['My suit!', 'Is that... buttercream?', 'Happy birthday to ME, I guess.'])); victim.look.frosted = 1; break;
      case 'cone': g.actors.say(victim, 'Hey! Get this thing off me!'); break;
      case 'noisy': g.actors.noise(x, y, TS * 10, 'fight', owner); break;
      case 'splash': victim.down = Math.max(victim.down, 0.6); g.env.douse(x, y, TS * 2, 3); break;
      case 'spray': g.env.douse(x, y, TS * 3, 4); for (let i = 0; i < 6; i++) g.fx.smoke(x, y); break;
      case 'flare': g.env.ignite(x, y + 6, 0.5, owner); break;
      case 'zap': g.fx.sparks(x, y, 8); victim.down = Math.max(victim.down, 1.5); break;
      case 'paint': g.fx.decals.push({ x, y: y + 8, r: 6, c: R.rng.pick(['rgba(200,40,40,0.7)', 'rgba(40,120,200,0.7)', 'rgba(240,200,40,0.7)']), t: 900 }); break;
      case 'mail': for (let i = 0; i < 5; i++) g.fx.add({ x, y, vx: (R.rng() - 0.5) * 90, vy: -40 - R.rng() * 40, g: 120, life: 1.2, max: 1.2, c: '#f6ecd0', s: 2 }); break;
      case 'trash': for (let i = 0; i < 5; i++) g.fx.add({ x, y, vx: (R.rng() - 0.5) * 90, vy: -30 - R.rng() * 30, g: 140, life: 0.9, max: 0.9, c: R.rng.pick(['#6a5a3a', '#8a8a6a', '#3a4a2a']), s: 2 }); break;
    }
  };
  Props.breakFx = function (k, x, y, owner) {
    const g = this.game, d = PROPS[k];
    const col = { wood: '#8a5a2a', metal: '#a0a0a8', pan: '#2a2a30', glass: '#a8e0f8', soft: '#e0a040', twang: '#c89040', squish: '#f0d0e0', thud: '#3a3a42', boing: '#1a1a1a', splash: '#6ab0e0', hiss: '#e0e0e0' }[d.mat] || '#8a8a8a';
    for (let i = 0; i < 8; i++) g.fx.add({ x, y, vx: (R.rng() - 0.5) * 120, vy: -30 - R.rng() * 60, g: 220, life: 0.6, max: 0.6, c: col, s: 1.5 });
    if (d.fx === 'boom') R.combat.explosion(x, y, 34, 55, owner);
    else if (d.fx === 'geyser') g.env.geyser(x, y);
    else if (d.fx === 'splash') { g.env.douse(x, y, TS * 2, 3); g.audio.sfx('splash', x, y); }
    else if (d.mat === 'glass') g.audio.sfx('glass', x, y);
  };

  // ---------------------------------------------------------------- drawing
  Props.drawGround = function (g, inView) {
    for (const p of this.loose) {
      if (!inView(p.x, p.y)) continue;
      const s = sprite(p.k);
      if (!s) continue;
      g.fillStyle = 'rgba(16,12,36,0.35)';
      g.fillRect(Math.round(p.x) - 5, Math.round(p.y) - 1, 10, 2);
      g.drawImage(s, Math.round(p.x) - 8, Math.round(p.y) - 14);
    }
  };
  Props.drawFlying = function (g) {
    for (const f of this.flying) {
      const s = sprite(f.k);
      if (!s) continue;
      const arc = Math.sin((f.t / f.life) * Math.PI) * 10;
      g.fillStyle = 'rgba(16,12,36,0.3)';
      g.fillRect(Math.round(f.x) - 4, Math.round(f.y) + 4, 8, 2);
      g.save();
      g.translate(Math.round(f.x), Math.round(f.y - arc));
      g.rotate(f.spin);
      g.drawImage(s, -8, -8);
      g.restore();
    }
  };
  // carried in the hand, raised mid-swing
  Props.drawHeld = function (g, pl) {
    const h = pl.held;
    if (!h) return;
    const s = sprite(h.k);
    if (!s) return;
    const d = PROPS[h.k];
    const swing = pl.punchT > 0 ? (1 - pl.punchT / 0.22) : 0;
    const a = pl.ang + (swing ? -1.2 + swing * 2.2 : 0.5);
    const hx = pl.x + Math.cos(pl.ang) * 5, hy = pl.y - 11 + Math.sin(pl.ang) * 3;
    g.save();
    g.translate(Math.round(hx), Math.round(hy));
    if (d.heavy && !swing) { g.drawImage(s, -8, -18); g.restore(); return; } // hoisted overhead
    g.rotate(a);
    g.drawImage(s, -3, -8);
    g.restore();
  };
})();
