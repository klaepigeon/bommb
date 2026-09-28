// RHAPSODY — heists. Every bank has a vault level and every casino a counting room,
// and there's more than one way down and more than one way in:
//   loud  — storm it in business hours with a gun; the manager opens up, the alarm rings,
//           and you have about a minute before the cavalry.
//   quiet — break in after hours, or badge through with the manager's keycard.
// Downstairs: sweeping cameras (silent alarm), an alarm panel you can cut, patrolling
// guards, and a vault you open with a tapped combination, a thermal drill (slow, noisy)
// or dynamite (instant, alarm). Bag the cash (each bag slows you) and walk out the door.
'use strict';
(function () {
  const D = R.data, O = D.O, T = D.T, TS = R.TILE;
  const H = (R.heist = {});
  const G = () => R.game;
  D.btypes.vaultlvl = { name: 'Vault Level', w: [1, 1], h: [1, 1], roof: ['#333'], wall: ['#777'], fl: 0.1 };
  D.tools.drill = D.tools.drill || { name: 'Thermal Drill' };
  D.tools.keycard = D.tools.keycard || { name: 'Vault Keycard' };

  H.levelFor = function (b) {
    const w = G().world;
    let v = w.buildings.find((x) => x && x.vaultOf === b.id);
    if (!v) {
      v = { id: w.buildings.length, type: 'vaultlvl', vaultOf: b.id, casino: b.type === 'casino', x: b.x, y: b.y, w: 0, h: 0, face: b.face, city: b.city, cityId: b.cityId, door: b.door, out: b.out,
        roof: '#333', wall: '#777', name: b.type === 'casino' ? `${b.name}: Counting Room` : `${b.name}: Vault Level`, residents: [], workers: [], owner: null, hp: 100, burning: 0, destroyed: false,
        cash: 0, robbedDay: -9, burgledDay: -9, racket: 0, playerOwned: false, floors: 1, seedArt: b.seedArt + 13 };
      w.buildings.push(v);
    }
    return v;
  };
  // the level itself
  const IP = R.Interiors.prototype, baseBuild = IP.build;
  IP.build = function (b, slot) {
    const room = baseBuild.call(this, b, slot);
    if (b.type !== 'vaultlvl') return room;
    const w = this.game.world, rw = room.w, rh = room.h, ex = Math.floor(rw / 2);
    const set = (x, y, o) => { w.obj[w.idx(room.x0 + x, room.y0 + y)] = o; };
    const tile = (x, y, t) => { w.tile[w.idx(room.x0 + x, room.y0 + y)] = t; };
    for (let y = 2; y < rh - 1; y++) for (let x = 1; x < rw - 1; x++) { tile(x, y, y <= 4 ? T.CARPET : T.CONCRETE); set(x, y, 0); }
    room.staff.length = room.seats.length = room.extra.length = room.beds.length = 0;
    // the vault: a wall with one big door
    for (let x = 1; x < rw - 1; x++) tile(x, 5, T.WALL);
    tile(ex, 5, T.CONCRETE); set(ex, 5, O.VAULT);
    room.vaultDoor = { x: room.x0 + ex, y: room.y0 + 5 };
    // cash pallets and deposit boxes inside
    room.cash = [];
    const pallets = b.casino ? [4, 6, 8, 13, 15, 17] : [6, 8, 13, 15];
    for (const x of pallets) { set(x, 3, O.TABLE); room.cash.push({ x: room.x0 + x, y: room.y0 + 3, left: b.casino ? 2 : 2 }); }
    for (const x of [2, 3, rw - 4, rw - 3]) set(x, 2, O.SAFE);
    // guard post, alarm panel, cover
    set(rw - 4, 9, O.DESK); set(rw - 3, 9, O.CHAIR); set(rw - 2, 10, O.CABINET);
    room.panel = { x: room.x0 + rw - 2, y: room.y0 + 10 };
    for (const [x, y] of [[4, 10], [7, 11], [12, 9], [15, 12], [5, 7]]) set(x, y, O.CRATE);
    room.cams = [{ x: room.x0 + 1.5, y: room.y0 + 6.5, a: 0.3, dir: 1 }, { x: room.x0 + rw - 1.5, y: room.y0 + 6.5, a: Math.PI - 0.3, dir: -1 }, { x: room.x0 + rw - 1.5, y: room.y0 + rh - 1.5, a: -2.4, dir: 1, base: -2.4 }];
    return room;
  };

  // ---------------------------------------------------------------- getting in
  H.enter = function (b, how) {
    const g = G(), pl = g.player;
    const v = this.levelFor(b);
    const r = g.interiors.rooms.get(v.id);
    if (r) g.interiors.clearRoom(r);
    if (pl.room) { pl.room = null; }
    g.ui.closeSheet();
    g.interiors.enter(v, 'breakin');
    const room = pl.room;
    room.alarm = 'off'; room.alarmT = 0; room.panelCut = false; room.grace = how === 'loud' ? 0 : 4; room.cased = !!(pl.cased && pl.cased[b.id]);
    pl.heist = { b: b.id, bags: 0, value: 0, loud: how === 'loud', started: g.clock.t };
    this.guards = [];
    const at = (x, y) => ({ x: (room.x0 + x) * TS + 8, y: (room.y0 + y) * TS + 8 });
    const routes = [[[2, 7], [19, 7]], [[3, 11], [8, 11], [8, 8]], [[18, 12], [18, 8]], [[9, 9], [16, 11]]].slice(0, b.casino ? 4 : 3);
    for (const rt of routes) {
      const p0 = at(...rt[0]);
      const h = g.actors.makeHuman(p0.x, p0.y, { role: 'cop', arch: 'tough', weapon: R.rng.pick(['revolver', 'revolver', 'shotgun']), cash: R.rng.int(10, 40) });
      h.room = room; h.keep = true; h.vaultGuard = true; h.strangerName = b.casino ? 'Pit Boss Muscle' : 'Bank Guard'; h.route = rt.map((p) => at(...p)); h.ri = 1; h.stay = true; h.state = 'idle'; h.timer = 1e9;
      this.guards.push(h);
    }
    const s = at(Math.floor(room.w / 2), room.h - 2);
    pl.place(s.x, s.y);
    if (how === 'loud') {
      g.world.setO(room.vaultDoor.x, room.vaultDoor.y, 0);
      this.raise('loud', 'The manager fumbles the vault open with your gun in his ear. The alarm is screaming.');
    } else g.ui.toast(`You're in. ${room.cased ? 'You know the camera timings: they sweep slower for you.' : 'Watch the cameras.'} Cut the alarm panel, open the vault, bag the cash, walk out.`, 'good');
  };
  H.raise = function (level, why) {
    const g = G(), pl = g.player, room = pl.room;
    if (!room || room.b.type !== 'vaultlvl') return;
    if (room.alarm === 'loud' || (room.alarm === 'silent' && level === 'silent')) return;
    room.alarm = level;
    const b = g.world.buildings[room.b.vaultOf];
    if (level === 'silent') { room.alarmT = 45; g.ui.toast(why || 'A red light blinks somewhere. Silent alarm. You have maybe 45 seconds.', 'bad'); return; }
    g.law.startIncident({ type: 'heist', def: g.law.CRIMES.heist, x: pl.x, y: pl.y, jur: g.law.jurAt(b.out.x * TS, b.out.y * TS), identified: !pl.masked, lvl: 3, bounty: 300 }, null);
    for (const gd of this.guards) if (!gd.dead) { gd.stay = false; gd.hostile = true; g.actors.setFight(gd, pl); }
    g.audio.sfx('alarm', pl.x, pl.y);
    g.ui.toast(why || 'ALARM! Every cop in the county is on the way.', 'bad');
  };

  // ---------------------------------------------------------------- inside
  const baseFA = IP.furnitureAction;
  IP.furnitureAction = function (fa) {
    const g = this.game, pl = g.player, room = pl.room;
    if (!room || room.b.type !== 'vaultlvl') return baseFA.call(this, fa);
    const o = g.world.o(fa.x, fa.y), bank = g.world.buildings[room.b.vaultOf];
    if (o === O.VAULT) {
      const open = (msg) => { g.world.setO(fa.x, fa.y, 0); g.audio.sfx('door'); g.cam.shake(2); g.ui.toast(msg, 'good'); };
      if (bank.comboKnown) return { label: 'Dial the combination', fn: () => { g.clock.skip(1); open('Left, right, left. The wheel spins free. Not a sound.'); } };
      const opts = [];
      if (pl.inv.tools.drill) opts.push({ label: 'Drill the lock', small: '15 seconds of noise', fn: () => H.drill(fa) });
      if ((pl.inv.ammo.dynamite || 0) > 0) opts.push({ label: 'Blow the door', small: 'Instant. Very loud.', cls: 'bad', fn: () => { pl.inv.ammo.dynamite--; g.fx.boom ? g.fx.boom(fa.x * TS + 8, fa.y * TS + 8) : 0; R.combat.explosion(fa.x * TS + 8, fa.y * TS + 16, 30, 0, pl); g.world.setO(fa.x, fa.y, 0); H.raise('loud', 'BOOM. The vault door folds like cardboard, and the alarm goes off.'); } });
      return { label: 'The vault door', fn: () => (opts.length ? g.ui.choice('A foot of steel', opts.concat([{ label: 'Leave it', fn: () => {} }])) : g.ui.toast('You need the combination (tap the bank\'s phone), a thermal drill (pawn shop) or dynamite.', 'warn')) };
    }
    if (o === O.CABINET && room.panel && fa.x === room.panel.x && fa.y === room.panel.y) {
      if (room.panelCut) return { label: 'Alarm panel (cut)', fn: () => g.ui.toast('Dead wires. No alarm will reach the station now.') };
      return { label: 'Cut the alarm wires', fn: () => R.mini.hotwire({ wires: 5, time: 14, title: 'Alarm Panel', sub: 'Match the pairs to bridge the circuit, then cut. Wrong wire and it trips.' }, (ok) => { if (ok) { room.panelCut = true; if (room.alarm === 'silent') { room.alarm = 'off'; g.ui.toast('You kill the panel just in time. The silent alarm never reaches the station.', 'good'); } else g.ui.toast('Wires cut. Cameras and guards can\'t call it in now.', 'good'); } else H.raise('silent', 'The panel sparks. A relay clicks somewhere. Silent alarm!'); }) };
    }
    if (o === O.TABLE) {
      const c = room.cash.find((q) => q.x === fa.x && q.y === fa.y);
      if (c && c.left > 0) return { label: `Bag the cash (${pl.heist.bags}/4 bags)`, fn: () => H.bag(c) };
      if (c) return { label: 'Empty pallet', fn: () => {} };
    }
    if (o === O.SAFE) return { label: 'Drill the deposit boxes', fn: () => { if (!pl.inv.tools.drill && !pl.inv.tools.lockpick) return g.ui.toast('You need a drill or a lockpick.', 'warn'); this.search(fa, { cash: [60, 240], items: ['jewels', 'bonds', 'watch', 'ring'], slow: 1 }); } };
    return baseFA.call(this, fa);
  };
  H.drill = function (fa) {
    const g = G(), pl = g.player, room = pl.room;
    if (room.drilling) return;
    room.drilling = { fa, t: 15 };
    g.ui.toast('The drill bites into the steel. Loud. Hold your ground.', 'warn');
  };
  H.bag = function (c) {
    const g = G(), pl = g.player, hs = pl.heist;
    if (hs.bags >= 4) return g.ui.toast('You can\'t carry any more.', 'warn');
    const room = pl.room, casino = room.b.casino;
    const v = R.rng.int(casino ? 900 : 700, casino ? 1600 : 1300);
    c.left--; hs.bags++; hs.value += v;
    g.audio.sfx('cash');
    g.ui.toast(`Bag ${hs.bags}: about ${R.fmtMoney(v)}. ${hs.bags >= 3 ? 'Heavy. You\'re slowing down.' : ''}`, 'good');
  };
  // heavy bags slow you
  const AP = R.Actors.prototype, baseMove = AP.moveActor;
  AP.moveActor = function (a, vx, vy, dt) {
    const pl = G() && G().player;
    if (a === pl && pl.heist && pl.heist.bags) { const k = 1 - pl.heist.bags * 0.11; vx *= k; vy *= k; }
    return baseMove.call(this, a, vx, vy, dt);
  };
  // walking out with the money
  const baseExit = IP.exit;
  IP.exit = function () {
    const g = this.game, pl = g.player, room = pl.room;
    if (!room || room.b.type !== 'vaultlvl') return baseExit.call(this);
    for (const gd of H.guards || []) if (!gd.dead) { gd.keep = false; }
    baseExit.call(this);
    const hs = pl.heist, bank = g.world.buildings[room.b.vaultOf];
    pl.heist = null;
    if (!hs || !hs.bags) return g.ui.toast('You leave empty-handed.');
    pl.addCash(hs.value);
    pl.rep.infamy += 8 + hs.bags * 3;
    g.jobs.addRep(40 + hs.bags * 15);
    bank.city.prosperity = Math.max(0, bank.city.prosperity - 6);
    bank.robbedDay = g.pop.day;
    const quiet = room.alarm === 'off';
    g.pop.addNews(bank.cityId, quiet ? `${bank.name} opens to find its ${bank.type === 'casino' ? 'counting room' : 'vault'} empty. "Not a single alarm," says a baffled police chief.` : `Daring raid on ${bank.name}! Robbers made off with an estimated ${R.fmtMoney(hs.value)}.`);
    if (quiet) { const c = g.law.jurAt(pl.x, pl.y); g.law.bounty[c] = (g.law.bounty[c] || 0); }
    g.ui.story(quiet ? 'CLEAN' : 'THE TAKE', `${hs.bags} bag${hs.bags > 1 ? 's' : ''} of cash: ${R.fmtMoney(hs.value)}.\n\n${quiet ? 'Not a bell rang. By the time anyone opens the vault in the morning you\'ll be three towns away.' : 'Now get somewhere safe.'}`);
    g.audio.sfx('promote');
  };

  // ---------------------------------------------------------------- guards, cameras, the drill, the clock
  H.update = function (dt) {
    const g = G(), pl = g.player, room = pl.room;
    if (!room || room.b.type !== 'vaultlvl') return;
    // a few seconds' grace as you come down the stairs
    if (room.grace > 0) room.grace -= dt;
    // cameras sweep
    for (const c of room.cams) {
      c.a += dt * 0.5 * (room.cased ? 0.6 : 1) * c.dir;
      const base = c.base != null ? c.base : c.x < room.x0 + 3 ? 0.3 : Math.PI - 0.3;
      if (Math.abs(c.a - base) > 0.7) c.dir *= -1;
      if (room.alarm !== 'off' || room.panelCut || room.grace > 0) continue;
      const dx = pl.x / TS - c.x, dy = pl.y / TS - c.y, d = Math.hypot(dx, dy);
      let da = Math.atan2(dy, dx) - c.a; while (da > Math.PI) da -= 2 * Math.PI; while (da < -Math.PI) da += 2 * Math.PI;
      if (d < 6 && Math.abs(da) < 0.35 && !(pl.sneak && !(pl.walk > 0))) this.raise('silent', 'A camera swings onto you and stops. Silent alarm!');
    }
    // the silent alarm counts down unless the panel is cut
    if (room.alarm === 'silent') { room.alarmT -= dt; if (room.alarmT <= 0) this.raise('loud', 'Squad cars outside. The alarm goes loud.'); }
    // drilling
    if (room.drilling) {
      room.drilling.t -= dt;
      if (R.rng() < dt * 12) g.fx.sparks(room.drilling.fa.x * TS + 8, room.drilling.fa.y * TS + 12, 2);
      for (const gd of this.guards) if (!gd.dead && !gd.alert && Math.hypot(gd.x - pl.x, gd.y - pl.y) < TS * 9) { gd.alert = true; gd.route = [{ x: room.drilling.fa.x * TS + 8, y: (room.drilling.fa.y + 1) * TS + 8 }]; gd.ri = 0; g.actors.say(gd, 'What\'s that noise?'); }
      if (room.drilling.t <= 0) { g.world.setO(room.drilling.fa.x, room.drilling.fa.y, 0); room.drilling = null; g.ui.toast('The drill punches through. The bolts slide back.', 'good'); }
    }
    // guards patrol and look
    for (const gd of this.guards) {
      if (gd.dead || gd.down > 0 || gd.state === 'fight' || !gd.route) continue;
      const tgt = gd.route[gd.ri % gd.route.length], d = Math.hypot(tgt.x - gd.x, tgt.y - gd.y);
      if (d < 4) gd.ri = (gd.ri + 1) % gd.route.length;
      else { g.actors.moveActor(gd, (tgt.x - gd.x) / d * 26, (tgt.y - gd.y) / d * 26, dt); gd.walk += dt * 8; gd.dir = R.dir4(tgt.x - gd.x, tgt.y - gd.y); gd.ang = Math.atan2(tgt.y - gd.y, tgt.x - gd.x); }
      const dp = Math.hypot(pl.x - gd.x, pl.y - gd.y);
      if (room.grace > 0 || dp > TS * 6 || !g.world.los(gd.x, gd.y - 8, pl.x, pl.y - 8)) continue;
      if (pl.sneak && !(pl.walk > 0) && dp > TS * 2) continue;
      // facing roughly toward you?
      let da = Math.atan2(pl.y - gd.y, pl.x - gd.x) - (gd.ang || 0); while (da > Math.PI) da -= 2 * Math.PI; while (da < -Math.PI) da += 2 * Math.PI;
      if (Math.abs(da) > 1.1 && dp > TS * 1.5) continue;
      g.actors.say(gd, R.rng.pick(['Freeze!', 'Intruder!', 'Hands where I can see them!']));
      gd.stay = false; gd.hostile = true; g.actors.setFight(gd, pl);
      this.raise(room.panelCut ? 'silent' : 'loud', room.panelCut ? 'A guard spotted you. His radio is dead, but the shooting won\'t be quiet for long.' : null);
    }
  };
  // cameras and cash drawn on top
  H.draw = function (g) {
    const game = G(), pl = game.player, room = pl.room;
    if (!room || room.b.type !== 'vaultlvl') return;
    for (const c of room.cams) {
      const x = c.x * TS, y = c.y * TS;
      if (!room.panelCut && room.alarm === 'off') {
        g.fillStyle = 'rgba(255,60,40,0.13)';
        g.beginPath(); g.moveTo(x, y); g.arc(x, y, 6 * TS, c.a - 0.35, c.a + 0.35); g.closePath(); g.fill();
      }
      g.fillStyle = '#1b1410'; g.fillRect(x - 3, y - 3, 6, 5);
      g.fillStyle = (game.clock.real * 2) % 1 < 0.5 ? '#ff3a2a' : '#5a1410'; g.fillRect(x - 1, y - 2, 2, 2);
    }
    for (const c of room.cash) for (let k = 0; k < c.left; k++) { const x = c.x * TS + 4 + k * 5, y = c.y * TS + 2; g.fillStyle = '#1b1410'; g.fillRect(x - 1, y - 1, 6, 6); g.fillStyle = '#5a9a4a'; g.fillRect(x, y, 4, 4); g.fillStyle = '#b8e0a0'; g.fillRect(x, y + 1, 4, 1); }
    if (room.alarm !== 'off' && (game.clock.real * 3) % 1 < 0.5) { g.fillStyle = 'rgba(255,30,20,0.12)'; g.fillRect(room.x0 * TS, room.y0 * TS, room.w * TS, room.h * TS); }
  };

  // ---------------------------------------------------------------- the way down
  // the lobby vault / counter: loud in business hours, quiet after hours or with a keycard
  const U = R.UI.prototype;
  U.heist = function (b) {
    const g = this.game, pl = g.player, room = pl.room;
    const armed = Object.keys(pl.inv.weapons).some((w) => D.weapons[w] && D.weapons[w].gun);
    const afterHours = room && room.mode === 'breakin';
    const card = pl.keycards && pl.keycards[b.id];
    const opts = [];
    if (afterHours || card) opts.push({ label: 'Slip down the staff stairs', small: card ? 'Your keycard opens the staff door' : 'Nobody here but the night guards', cls: 'go', fn: () => H.enter(b, 'quiet') });
    if (armed && !afterHours) opts.push({ label: 'Storm the vault at gunpoint', small: 'Loud. About a minute before the cavalry.', cls: 'bad', fn: () => H.enter(b, 'loud') });
    if (!opts.length) return this.toast('Staff only. You need a gun, a keycard from the manager, or to come back after hours.', 'warn');
    opts.push({ label: 'Not today', fn: () => {} });
    this.choice(b.type === 'casino' ? 'The counting room' : 'The vault', opts);
  };
  const baseOpts = U.interiorOptions;
  U.interiorOptions = function (b) {
    const g = this.game, pl = g.player, opts = baseOpts.call(this, b);
    const add = (o) => { const li = opts.findIndex((x) => /^(Leave|Done)$/.test(x.label)); opts.splice(li >= 0 ? li : opts.length, 0, o); };
    if (b.type === 'bank' || b.type === 'casino') {
      if (!(pl.cased && pl.cased[b.id])) add({ label: b.type === 'bank' ? 'Ask about safe-deposit boxes' : 'Ask about the high-roller room', small: 'Case the place', fn: () => { pl.cased = pl.cased || {}; pl.cased[b.id] = 1; this.toast('You clock the guard rotation and the camera sweep while they talk. You\'ll know the timings downstairs.', 'good'); } });
      if (b.type === 'casino') add({ label: 'The counting room', small: 'Staff only', cls: 'bad', fn: () => this.heist(b) });
    }
    if (b.type === 'pawn' && !pl.inv.tools.drill) add({ label: 'Thermal Drill', price: '$250', small: 'Opens a vault door. Loud.', fn: () => { if (!pl.pay(250)) return this.toast('$250.', 'warn'); pl.inv.tools.drill = 1; this.toast('Heavy, ugly, and it will eat through a vault door.', 'good'); } });
    return opts;
  };
  // bank managers carry keycards
  const PP = R.Player.prototype, baseRob = PP.rob;
  PP.rob = function (h) {
    const r = baseRob.call(this, h);
    if (h && h.bankManager) { this.keycards = this.keycards || {}; this.keycards[h.bankManager] = 1; this.game.ui.toast('Among his keys: a keycard for the vault level.', 'good'); }
    return r;
  };
  const baseLoot = PP.loot;
  PP.loot = function (h) {
    const r = baseLoot.apply(this, arguments);
    if (h && h.bankManager) { this.keycards = this.keycards || {}; this.keycards[h.bankManager] = 1; this.game.ui.toast('In his breast pocket: a keycard for the vault level.', 'good'); }
    return r;
  };
  const basePop = IP.populate;
  IP.populate = function (room) {
    const r = basePop.call(this, room);
    const b = room.b;
    if ((b.type === 'bank' || b.type === 'casino') && room.mode !== 'breakin') {
      const s = room.staff[0] || room.center;
      const h = this.game.actors.makeHuman(s.x * TS + 24, (s.y + 3) * TS + 8, { arch: 'square', cash: R.rng.int(40, 120) });
      h.room = room; h.keep = true; h.stay = true; h.state = 'idle'; h.timer = 1e9; h.bankManager = b.id; h.strangerName = b.type === 'casino' ? 'Floor Manager' : 'Bank Manager';
    }
    return r;
  };
})();
