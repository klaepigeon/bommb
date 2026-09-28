// RHAPSODY — the county jail, and how to leave it early.
// Can't pay your fine and you're booked: your gear goes in the evidence locker and you
// wake up in a cell. Serve your days by sleeping in your bunk, or break out:
//   pick the cell and gate locks (smuggle a lockpick from an inmate or a bent guard),
//   knock out a guard and walk out in his uniform, dig a tunnel with a sharpened spoon,
//   start a riot in the mess hall, or call the family from the hall phone.
// Guards patrol and shout you back to your cell; get caught out and you do extra time.
'use strict';
(function () {
  const D = R.data, O = D.O, T = D.T, TS = R.TILE;
  const J = (R.slammer = {});
  const G = () => R.game;
  D.furniture[O.BARS] = D.furniture[O.BARS] || { verb: 'Bars', bars: 1 };
  D.btypes.jail = { name: 'County Jail', w: [1, 1], h: [1, 1], roof: ['#3a3a3a'], wall: ['#8a8a80'], fl: 0.2 };

  J.jailFor = function (jur) {
    const g = G(), w = g.world;
    const city = g.world.cities.find((c) => c.id === jur) || g.world.cities[0];
    const ps = city.buildings.find((b) => b.type === 'police') || city.buildings[0];
    let b = w.buildings.find((x) => x && x.jailOf === ps.id);
    if (!b) {
      b = { id: w.buildings.length, type: 'jail', jailOf: ps.id, x: ps.x, y: ps.y, w: 0, h: 0, face: ps.face, city: ps.city, cityId: ps.cityId, door: ps.door, out: ps.out,
        roof: '#3a3a3a', wall: '#8a8a80', name: `${city.name} County Jail`, residents: [], workers: [], owner: null, hp: 100, burning: 0, destroyed: false, cash: 0,
        robbedDay: -9, burgledDay: -9, racket: 0, playerOwned: false, floors: 1, seedArt: ps.seedArt + 9 };
      w.buildings.push(b);
    }
    return b;
  };

  // ---------------------------------------------------------------- booking
  J.book = function (jur, days) {
    const g = G(), pl = g.player;
    if (pl.inCar) pl.exitCar();
    if (pl.room) g.interiors.exit();
    const ev = { weapons: Object.assign({}, pl.inv.weapons), ammo: Object.assign({}, pl.inv.ammo), cash: Math.max(0, pl.cash - 20), picks: pl.inv.tools.lockpick || 0 };
    pl.inv.weapons = { fists: 1 };
    for (const k in pl.inv.ammo) pl.inv.ammo[k] = 0;
    pl.inv.tools.lockpick = 0;
    pl.cash = Math.min(pl.cash, 20);
    pl.weapon = 'fists'; pl.weaponOut = false; pl.held = null; pl.carrying = null;
    pl.jail = { jur, days, ev, dig: 0, spoon: false, uniform: false, caught: 0, warned: 0, released: false };
    this.rioting = false;
    const b = this.jailFor(jur);
    // a fresh room every time
    const r = g.interiors.rooms.get(b.id);
    if (r) g.interiors.clearRoom(r);
    g.interiors.enter(b, 'normal');
    this.setup();
    g.ui.story('BOOKED', `Fingerprints, a mugshot, an orange jumpsuit. Your things go in the evidence locker behind the guard desk.\n\n${days} day${days > 1 ? 's' : ''} to serve. Cells open for yard time from 8 AM to 8 PM. Sleep in your bunk to do your time, or find another way out:\n• a lockpick for the cell and the gate (inmates and bent guards sell them)\n• a guard's uniform\n• a sharpened spoon and a few nights of digging\n• a riot\n• the hall phone`);
  };
  J.setup = function () {
    const g = G(), pl = g.player, room = pl.room;
    if (!room || room.b.type !== 'jail') return;
    const at = (x, y) => ({ x: (room.x0 + x) * TS + 8, y: (room.y0 + y) * TS + 8 });
    // your cell (freshly built with its door shut; the routine opens it if it's yard time)
    const c = at(2, 3);
    pl.place(c.x, c.y);
    if (pl.jail) pl.jail.yardOpen = false;
    // guards
    this.guards = [];
    const routes = [[[3, 6], [18, 6]], [[14, 9], [14, 12], [8, 12]], [[18, 7], [18, 11]]];
    for (let i = 0; i < 3; i++) {
      const p0 = at(...routes[i][0]);
      const h = g.actors.makeHuman(p0.x, p0.y, { role: 'cop', arch: 'tough', weapon: 'bat', cash: 20 });
      h.room = room; h.keep = true; h.jailGuard = true; h.strangerName = 'Guard'; h.route = routes[i].map((p) => at(...p)); h.ri = 1; h.stay = true; h.state = 'idle'; h.timer = 1e9;
      this.guards.push(h);
    }
    // inmates in the mess hall
    this.inmates = [];
    for (let i = 0; i < 5; i++) {
      const p0 = at(2 + (i % 3) * 3, 9 + Math.floor(i / 3) * 2);
      const h = g.actors.makeHuman(p0.x, p0.y, { arch: R.rng.pick(['tough', 'hustler', 'grumpy', 'friendly']), cash: 0 });
      h.room = room; h.keep = true; h.inmate = true; h.strangerName = R.rng.pick(['Lefty', 'Ox', 'Pops', 'Knuckles', 'The Professor', 'Deacon', 'Weasel', 'Tiny']); h.stay = true; h.state = 'idle'; h.timer = 1e9;
      h.look = Object.assign({}, h.look, { oldOverride: Object.assign({}, h.look.oldOverride || {}, { shirt: ['#8a3a08', '#c85a10', '#f08020', '#ffb050'], pants: ['#8a3a08', '#c85a10', '#f08020', '#ffb050'], jacket: null }), old: null });
      this.inmates.push(h);
    }
    pl.look = Object.assign({}, pl.look, { oldOverride: Object.assign({}, pl.look.oldOverride || {}, { shirt: ['#8a3a08', '#c85a10', '#f08020', '#ffb050'], pants: ['#8a3a08', '#c85a10', '#f08020', '#ffb050'], jacket: null }), old: null });
  };
  // furnish the jail when it's built
  const IP = R.Interiors.prototype, baseBuild = IP.build;
  IP.build = function (b, slot) {
    const room = baseBuild.call(this, b, slot);
    if (b.type !== 'jail') return room;
    const w = this.game.world, rw = room.w, rh = room.h;
    const set = (x, y, o) => { w.obj[w.idx(room.x0 + x, room.y0 + y)] = o; };
    const floor = (x, y, t) => { w.tile[w.idx(room.x0 + x, room.y0 + y)] = t; };
    for (let y = 2; y < rh - 1; y++) for (let x = 1; x < rw - 1; x++) { floor(x, y, y <= 4 ? T.CONCRETE : T.TILEF); set(x, y, 0); }
    room.staff.length = room.seats.length = room.extra.length = room.beds.length = 0;
    // five cells along the top wall; yours is the first, and its door is locked
    for (let k = 0; k < 5; k++) {
      const x0 = 1 + k * 4;
      if (k) for (let y = 2; y <= 4; y++) set(x0 - 1, y, O.BARS);
      set(x0, 2, O.BED);
      for (let x = x0; x < x0 + 3; x++) if (x !== x0 + 1 || k === 0) set(x, 5, O.BARS);
    }
    for (let y = 2; y <= 5; y++) set(20, y, O.BARS);
    // mess hall
    for (const [x, y] of [[3, 9], [7, 9], [3, 11], [7, 11]]) { set(x, y, O.TABLE); set(x - 1, y, O.CHAIR); set(x + 1, y, O.CHAIR); }
    // guard desk, evidence locker, hall phone
    set(17, 9, O.DESK); set(18, 9, O.CHAIR); set(20, 8, O.LOCKER); set(20, 9, O.CABINET); set(13, 12, O.PHONE);
    // the gate in front of the door
    const ex = Math.floor(rw / 2);
    set(ex, rh - 2, O.BARS);
    room.jailGate = { x: room.x0 + ex, y: room.y0 + rh - 2 };
    room.jailCell = { x: room.x0 + 2, y: room.y0 + 5 };
    return room;
  };

  // ---------------------------------------------------------------- interactions
  const inCell = (pl, room) => { const tx = (pl.x / TS) | 0, ty = (pl.y / TS) | 0; return tx - room.x0 >= 1 && tx - room.x0 <= 3 && ty - room.y0 >= 2 && ty - room.y0 <= 4; };
  const baseFA = IP.furnitureAction;
  IP.furnitureAction = function (fa) {
    const g = this.game, pl = g.player, room = pl.room, j = pl.jail;
    if (!room || room.b.type !== 'jail' || !j) return baseFA.call(this, fa);
    const o = g.world.o(fa.x, fa.y);
    const isGate = room.jailGate && fa.x === room.jailGate.x && fa.y === room.jailGate.y;
    const isCell = room.jailCell && fa.x === room.jailCell.x && fa.y === room.jailCell.y;
    if (o === O.BARS && (isGate || isCell)) {
      const open = () => { g.world.setO(fa.x, fa.y, 0); g.audio.sfx('door'); };
      if (isGate && j.uniform) return { label: 'Buzz yourself through', fn: () => { open(); g.ui.toast('"Night, Earl." The gate buzzes. Nobody looks up.', 'good'); } };
      if (pl.inv.tools.lockpick) return { label: isGate ? 'Pick the gate lock' : 'Pick the cell lock', fn: () => R.mini.lockpick({ pins: isGate ? 5 : 3, title: isGate ? 'The main gate' : 'Your cell door' }, (ok) => { if (ok) { open(); g.ui.toast(isGate ? 'The gate swings open.' : 'Click. The cell door slides open. Stay out of sight.', 'good'); } else { pl.inv.tools.lockpick--; g.ui.toast('The pick snaps.', 'warn'); } }) };
      return { label: isGate ? 'Locked gate' : 'Locked cell door', fn: () => g.ui.toast(isGate ? 'Heavy bars. A guard could buzz it open... if you were a guard.' : 'Locked. You need a lockpick.') };
    }
    if (o === O.BED) return { label: j.dig >= 100 ? 'Crawl into the tunnel' : 'Sleep (serve a day)', fn: () => (j.dig >= 100 ? J.escape('tunnel') : J.sleep()) };
    if (o === O.LOCKER) return { label: 'Evidence locker: get your things back', fn: () => { J.returnItems(); g.ui.toast('Your guns, your cash, your lockpicks. All here.', 'good'); } };
    if (o === O.PHONE) return { label: 'Use the hall phone', fn: () => J.phone() };
    return baseFA.call(this, fa);
  };
  J.returnItems = function () {
    const pl = G().player, j = pl.jail;
    if (!j || !j.ev) return;
    Object.assign(pl.inv.weapons, j.ev.weapons);
    for (const k in j.ev.ammo) pl.inv.ammo[k] = (pl.inv.ammo[k] || 0) + j.ev.ammo[k];
    pl.cash += j.ev.cash;
    pl.inv.tools.lockpick = (pl.inv.tools.lockpick || 0) + j.ev.picks;
    j.ev = null;
  };
  J.sleep = function () {
    const g = G(), pl = g.player, j = pl.jail;
    const h = g.clock.hour();
    g.clock.skip(Math.round((h < 7 ? 8 - h : 24 - h + 8) * 60));
    pl.hp = pl.maxHp;
    if (j.spoon) {
      if (R.rng() < 0.18) { j.dig = 0; j.days += 2; return g.ui.story('SHAKEDOWN', 'Guards toss your cell at dawn and find the hole behind the bunk. They fill it with concrete and add two days to your sentence.'); }
      j.dig = Math.min(100, j.dig + 34);
      if (j.dig >= 100) return g.ui.story('LIGHT', 'Your spoon breaks through into a storm drain. Tonight you can crawl out. (Use the bunk.)');
      g.ui.toast(`You dig all night with the spoon. Tunnel ${j.dig}%.`, 'good');
    }
    j.days--;
    if (j.days <= 0) return this.release();
    g.ui.story('ANOTHER DAY', `Grey eggs, a shower with the lights flickering, the yard. ${j.days} day${j.days > 1 ? 's' : ''} to go.`);
  };
  J.release = function () {
    const g = G(), pl = g.player;
    this.returnItems();
    pl.jail.released = true;
    this.cleanup();
    g.interiors.exit();
    pl.jail = null;
    pl.buildLook();
    g.ui.story('RELEASED', 'Time served. They hand back your things in a paper bag and a clerk tells you not to come back. The street looks brighter than you remember.');
  };
  J.escape = function (how) {
    const g = G(), pl = g.player, j = pl.jail;
    if (!j) return;
    j.released = true;
    this.cleanup();
    if (pl.room) g.interiors.exit();
    const jur = j.jur;
    pl.jail = null;
    pl.buildLook();
    // come out a way off from the front door if you didn't use it
    if (how === 'tunnel' || how === 'family') { const s = g.world.findNear((pl.x / TS) | 0, ((pl.y / TS) | 0) + 10, 4, 14, (x, y) => !g.world.solidPed(x, y) && !g.world.isWater(x, y)); if (s) pl.place(s.x * TS + 8, s.y * TS + 8); }
    pl.stats.escapes = (pl.stats.escapes || 0) + 1;
    g.pop.addNews(jur, `Jailbreak! ${pl.name} escaped the county jail ${how === 'tunnel' ? 'through a tunnel dug with a spoon' : how === 'riot' ? 'during a riot' : how === 'family' ? 'when somebody blew a hole in the wall' : how === 'uniform' ? 'dressed as a guard' : 'overnight'}. Police are asking the public for help.`);
    g.law.startIncident({ type: 'jailbreak', def: g.law.CRIMES.jailbreak, x: pl.x, y: pl.y, jur, identified: true, lvl: 2, bounty: 150 }, null);
    g.ui.story('OUT', { tunnel: 'You squeeze through the storm drain and come up in a ditch behind the station. Free, filthy and wanted.', riot: 'In the smoke and the screaming, nobody watches the door. You walk out into the night.', family: 'The wall of the mess hall blows in. A car idles outside with the back door open. "Get in, the Don is waiting."', uniform: 'A nod to the desk sergeant, a salute to the night shift, and you\'re out on the steps.', door: 'You slip out the front door into the night.' }[how] + '\n\nThey know it was you: a jailbreak bounty is on your head.' + (pl.inv.weapons.revolver || Object.keys(pl.inv.weapons).length > 1 ? '' : '\n\n(Your guns are still in the evidence locker.)'));
  };
  // loading a save made behind bars puts you back in your cell
  J.resume = function () {
    const g = G(), pl = g.player, j = pl.jail;
    if (!j) return;
    this.rioting = false;
    const b = this.jailFor(j.jur);
    const r = g.interiors.rooms.get(b.id);
    if (r) g.interiors.clearRoom(r);
    g.interiors.enter(b, 'normal');
    this.setup();
  };
  J.cleanup = function () {
    const g = G();
    for (const h of (this.guards || []).concat(this.inmates || [])) if (h && !h.dead) { h.keep = false; g.actors.remove(h); }
    this.guards = []; this.inmates = [];
  };
  J.phone = function () {
    const g = G(), pl = g.player, j = pl.jail, st = g.jobs.familyStanding(pl.family), stash = pl.stash ? pl.stash.cash : 0;
    const opts = [];
    const lawyer = Math.round(80 + j.days * 60);
    opts.push({ label: `Call your lawyer (${R.fmtMoney(lawyer)} from your stash)`, small: stash >= lawyer ? 'Out legally by morning' : `Your stash has ${R.fmtMoney(stash)}`, fn: () => { if (stash < lawyer) return g.ui.toast('The lawyer wants cash first.', 'warn'); pl.stash.cash -= lawyer; j.days = 0; g.ui.toast('"Sit tight. You\'re out in the morning." Sleep in your bunk.', 'good'); j.days = 1; } });
    opts.push({ label: `Call the ${pl.family} family`, small: st >= 30 && g.jobs.rank() >= 1 ? 'They look after their own' : 'They don\'t owe you anything yet', fn: () => {
      if (st < 30 || g.jobs.rank() < 1) return g.ui.toast('"Who is this? We don\'t know you." Click.', 'warn');
      g.ui.toast('"Stay away from the mess hall wall tonight." Click.', 'good');
      setTimeout(() => { if (!pl.jail) return; g.fx.boom ? g.fx.boom(pl.x - 60, pl.y) : 0; g.cam.shake(10); g.audio.sfx('explosion'); setTimeout(() => J.escape('family'), 1200); }, 5000);
    } });
    opts.push({ label: 'Hang up', fn: () => {} });
    g.ui.choice('Hall phone', opts);
  };
  // inmates and guards talk
  const baseTree = R.dialog.tree;
  R.dialog.tree = function (h) {
    const g = G(), pl = g.player, j = pl.jail;
    if (!j || !(h.inmate || h.jailGuard)) return baseTree.call(this, h);
    const say = (x) => g.ui.talkLine(x), close = () => g.ui.closeTalk();
    const opts = [];
    if (h.inmate) {
      opts.push({ label: '"What are you in for?"', fn: () => say(R.rng.pick(['Didn\'t do it. Nobody in here did it.', 'Stole a hearse. Long story.', 'Tax stuff. Don\'t ask.', 'Punched a cop. Would do it again.'])) });
      opts.push({ label: '"I need a lockpick."', small: '$15 commissary, or 2 smokes', fn: () => { if ((pl.inv.cons.smokes || 0) >= 2) pl.inv.cons.smokes -= 2; else if (!pl.pay(15)) return say('Nothing\'s free in here, fish.'); pl.inv.tools.lockpick = (pl.inv.tools.lockpick || 0) + 1; say('Bent bobby pin. Works on the cell doors. Didn\'t get it from me.'); } });
      if (!j.spoon) opts.push({ label: '"Anybody ever dig out of here?"', fn: () => { j.spoon = true; say('Spoon from the mess hall. Sharpened. Dig behind your bunk, a little every night. Don\'t get caught.'); g.ui.toast('You have a sharpened spoon. Sleep to dig.', 'good'); } });
      opts.push({ label: 'Start a riot', small: 'Everybody against the guards', cls: 'bad', fn: () => { close(); J.riot(); } });
    } else {
      opts.push({ label: '"Look the other way for a minute?"', small: '$10 now, $200 from your stash', fn: () => { const stash = pl.stash ? pl.stash.cash : 0; if (stash < 200 || !pl.pay(10)) return say('Get back in your cell.'); pl.stash.cash -= 200; pl.inv.tools.lockpick = (pl.inv.tools.lockpick || 0) + 1; h.bribed = true; say('I didn\'t see nothing. And this pick fell out of my pocket.'); } });
      opts.push({ label: '"When do I get out?"', fn: () => say(`${j.days} more day${j.days > 1 ? 's' : ''}. Keep your nose clean.`) });
    }
    opts.push({ label: 'Walk away', fn: close });
    return { title: h.strangerName, sub: h.inmate ? 'Orange jumpsuit, prison tattoos, eyes on the guards.' : 'Blue uniform, a baton and a bad attitude.', options: opts };
  };
  J.riot = function () {
    const g = G();
    if (this.rioting) return;
    this.rioting = true;
    g.ui.toast('You flip a table. "IT\'S GOING DOWN!" The mess hall explodes.', 'bad');
    for (const i of this.inmates) { const gd = R.rng.pick(this.guards.filter((x) => !x.dead)); if (gd) { i.stay = false; i.hostile = true; g.actors.setFight(i, gd); } }
    for (const gd of this.guards) { gd.stay = false; const i = R.rng.pick(this.inmates); if (i) g.actors.setFight(gd, i); }
    const room = g.player.room;
    if (room && room.jailGate) g.world.setO(room.jailGate.x, room.jailGate.y, 0);
    if (room && room.jailCell) g.world.setO(room.jailCell.x, room.jailCell.y, 0);
    g.player.jail.rioted = true;
  };
  // knock out a guard: take his uniform
  const PP = R.Player.prototype, baseCtx = PP.contextAction;
  PP.contextAction = function () {
    const j = this.jail;
    if (j && !j.uniform) {
      const gd = this.game.actors.near(this.x, this.y, TS * 1.3, (a) => a.jailGuard && (a.down > 0 || a.dead))[0];
      if (gd) return { label: 'Take the guard\'s uniform', fn: () => { j.uniform = true; this.look = Object.assign({}, gd.look); this.game.ui.toast('Blue shirt, badge, keys. Walk like you belong here.', 'good'); } };
    }
    return baseCtx.call(this);
  };
  // leaving by the front door is escaping
  const baseExit = IP.exit;
  IP.exit = function () {
    const pl = this.game.player;
    if (pl.room && pl.room.b.type === 'jail' && pl.jail && !pl.jail.released) { baseExit.call(this); return J.escape(pl.jail.uniform ? 'uniform' : pl.jail.rioted ? 'riot' : 'door'); }
    return baseExit.call(this);
  };

  // ---------------------------------------------------------------- guards
  // the daily routine: cells open for yard time, lock at lights out
  const yardTime = () => { const h = G().clock.hour(); return h >= 8 && h < 20; };
  // behind the guard desk, the evidence locker, the front gate: off limits any time
  const restricted = (pl, room) => { const x = ((pl.x / TS) | 0) - room.x0, y = ((pl.y / TS) | 0) - room.y0; return (x >= 15 && y >= 7) || y >= room.h - 3; };
  J.routine = function (g, pl, j, room) {
    if (this.rioting) return; // the riot opened everything; nobody's locking anything now
    const open = yardTime() && j.lockdown !== g.pop.day;
    if (open === !!j.yardOpen) return;
    j.yardOpen = open;
    if (!room.jailCell) return;
    if (open) {
      g.world.setO(room.jailCell.x, room.jailCell.y, 0);
      g.audio.sfx('door');
      g.ui.toast('Yard time. The cell doors buzz open until 8 PM. Stay away from the guard desk and the gate.', 'good');
    } else {
      // lights out: anyone out of their cell gets walked back, no harm done
      if (!inCell(pl, room)) { const c = { x: (room.x0 + 2) * TS + 8, y: (room.y0 + 3) * TS + 8 }; pl.place(c.x, c.y); }
      g.world.setO(room.jailCell.x, room.jailCell.y, O.BARS);
      g.audio.sfx('door');
      const gd = (this.guards || []).find((x) => !x.dead);
      if (gd) g.actors.say(gd, 'LIGHTS OUT! Everybody in their cells!');
      g.ui.toast('Lights out. Your cell is locked until morning. Out of it now and the guards come running.', 'warn');
    }
  };
  J.update = function (dt) {
    const g = G(), pl = g.player, j = pl.jail, room = pl.room;
    if (!j || !room || room.b.type !== 'jail' || this.rioting && !j) return;
    this.routine(g, pl, j, room);
    for (const gd of this.guards || []) {
      if (gd.dead || gd.down > 0 || !gd.route || this.rioting) continue;
      const tgt = gd.route[gd.ri], d = Math.hypot(tgt.x - gd.x, tgt.y - gd.y);
      if (gd.chase) {
        const dp = Math.hypot(pl.x - gd.x, pl.y - gd.y);
        if (dp < TS * 1.1) { this.caught(gd); continue; }
        g.actors.moveActor(gd, (pl.x - gd.x) / dp * 70, (pl.y - gd.y) / dp * 70, dt);
        gd.walk += dt * 14; gd.dir = R.dir4(pl.x - gd.x, pl.y - gd.y);
        continue;
      }
      if (d < 4) gd.ri = (gd.ri + 1) % gd.route.length;
      else { g.actors.moveActor(gd, (tgt.x - gd.x) / d * 26, (tgt.y - gd.y) / d * 26, dt); gd.walk += dt * 8; gd.dir = R.dir4(tgt.x - gd.x, tgt.y - gd.y); gd.ang = Math.atan2(tgt.y - gd.y, tgt.x - gd.x); }
      // can he see you out of your cell?
      const dp = Math.hypot(pl.x - gd.x, pl.y - gd.y);
      if (inCell(pl, room) || gd.bribed || dp > TS * 6 || !g.world.los(gd.x, gd.y - 8, pl.x, pl.y - 8)) continue;
      // during yard time you can be out, just not where the guards work (or with a weapon in your hand)
      if (j.yardOpen && !restricted(pl, room) && !pl.weaponOut) { j.warned = 0; continue; }
      if (j.uniform && dp > TS * 1.4) continue;
      if (pl.sneak && !(pl.walk > 0) && dp > TS * 2) continue;
      j.warned += dt;
      if (j.warned < 0.1 + dt) g.actors.say(gd, j.uniform ? 'Hey... you\'re not Earl!' : R.rng.pick(['Hey! Back in your cell!', 'Where do you think you\'re going?!', 'Inmate out of his cell!']));
      if (j.warned > 1.2) { gd.chase = true; g.ui.toast('The guards are on you!', 'bad'); }
    }
  };
  J.caught = function (gd) {
    const g = G(), pl = g.player, j = pl.jail, room = pl.room;
    for (const x of this.guards) x.chase = false;
    j.warned = 0; j.caught++; j.days += 1;
    j.lockdown = g.pop.day; j.yardOpen = false; // confined to your cell for the rest of the day
    if (j.uniform) { j.uniform = false; pl.buildLook(); this.setupLook(); }
    pl.inv.tools.lockpick = 0;
    g.actors.say(gd, 'Nice try.');
    pl.hp = Math.max(20, pl.hp - 25);
    const c = { x: (room.x0 + 2) * TS + 8, y: (room.y0 + 3) * TS + 8 };
    pl.place(c.x, c.y);
    if (room.jailCell) g.world.setO(room.jailCell.x, room.jailCell.y, O.BARS);
    g.ui.story('CAUGHT', `A baton to the ribs and a long walk back to your cell. They took your lockpicks. One more day added, and you're locked in until tomorrow. (${j.days} to go.)`);
  };
  J.setupLook = function () { const pl = G().player; pl.look = Object.assign({}, pl.look, { oldOverride: Object.assign({}, pl.look.oldOverride || {}, { shirt: ['#8a3a08', '#c85a10', '#f08020', '#ffb050'], pants: ['#8a3a08', '#c85a10', '#f08020', '#ffb050'], jacket: null }), old: null }); };

  // arrested and can't pay: jail instead of a skipped clock
  const LP = R.Law.prototype, baseSurrender = LP.surrender;
  LP.surrender = function () {
    const g = this.game, pl = g.player, inc = this.incident;
    const jur = inc ? inc.jur : this.jurAt(pl.x, pl.y);
    const b = this.bounty[jur] || 0, fine = Math.max(25, Math.round(b));
    const book = () => { this.clearIncident(true); this.bounty[jur] = 0; pl.stats.arrests++; J.book(jur, Math.min(7, 1 + Math.floor(b / 150))); };
    // serious bounties mean a cell, no fine to pay; small ones, your choice
    if (b >= 150 || pl.cash < fine) return book();
    g.ui.choice(`Arrested · ${R.fmtMoney(fine)} bounty`, [
      { label: `Pay the fine (${R.fmtMoney(fine)})`, small: 'Walk out today', fn: () => baseSurrender.call(this) },
      { label: 'Take the cell instead', small: 'Keep your money. Do the time, or break out', fn: book },
    ]);
  };
})();
