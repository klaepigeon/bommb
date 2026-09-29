// RHAPSODY — funerals. When a don or a capo dies (whoever did it), the family buries him the
// next morning at the church in his city, and the whole underworld turns out in black: the
// widow, the soldiers, and a boss from a rival family who came to be seen paying respects. Go
// and stand at the back with an envelope and the family remembers the gesture (unless you're
// the reason for the funeral). Or come for the guest of honour: he's standing on the church
// steps with his hat in his hands and only two men watching him.
'use strict';
(function () {
  const TS = R.TILE;
  const G = () => R.game;
  const FU = (R.funeral = { t: 0, actors: [] });
  FU.state = function () { const st = R.shark.street(); return (st.funerals = st.funerals || { list: [], paid: 0, hits: 0 }); };
  FU.cur = function () { const g = G(), s = this.state(); return s.list.find((f) => f.day === g.pop.day && !f.over) || null; };
  // someone important died: book the church for tomorrow morning
  FU.onDeath = function (p, byPlayer) {
    const g = G();
    if (!p || !p.faction || p.faction === 'law' || !(p.isDon || p.role === 'capo')) return;
    const w = g.world, s = this.state();
    if (s.list.some((f) => f.pid === p.id)) return;
    const city = w.cities.find((c) => c.id === p.city) || w.cities[0];
    const ch = w.buildings.find((b) => b && !b.destroyed && b.type === 'church' && b.cityId === city.id) || w.buildings.find((b) => b && !b.destroyed && b.type === 'church');
    if (!ch) return;
    // the guest of honour: a boss from another family
    const others = g.pop.people.filter((q) => q && q.alive && !q.jailed && q.faction && q.faction !== p.faction && q.faction !== 'law' && (q.role === 'capo' || q.isDon) && !q.actor);
    const guest = others.length ? R.rng.pick(others) : null;
    const f = { pid: p.id, name: `${p.first} ${p.last}`, don: !!p.isDon, fam: p.faction, bid: ch.id, day: g.pop.day + 1, byPlayer: !!byPlayer, guest: guest ? guest.id : null, over: false };
    s.list.push(f);
    if (s.list.length > 12) s.list.shift();
    g.pop.addNews(city.id, `Funeral mass for ${f.name} tomorrow morning at ${ch.name}. The family asks for privacy. Police will be "keeping an eye on things."`);
    if (R.dist(g.player.x, g.player.y, ch.out.x * TS, ch.out.y * TS) < TS * 200) g.ui.toast(`${f.name} will be buried tomorrow morning at ${ch.name}. Everybody who matters will be there.`, 'warn');
  };
  FU.stage = function (f) {
    const g = G(), w = g.world, ch = w.buildings[f.bid];
    if (!ch) return;
    f.staged = true;
    const ox = ch.out.x * TS + 8, oy = ch.out.y * TS + 8, place = (dx, dy) => { const s = w.findNear(ch.out.x + dx, ch.out.y + dy, 0, 3, (x, y) => !w.solidPed(x, y) && !w.isWater(x, y)); return s ? { x: s.x * TS + 8, y: s.y * TS + 8 } : { x: ox, y: oy }; };
    this.actors = [];
    const pr = place(0, 2), priest = g.actors.makeHuman(pr.x, pr.y, { arch: 'pious', role: 'priest', cash: 5 });
    priest.strangerName = 'Father Bianchi'; priest.keep = true; this.actors.push(priest);
    const widow = g.actors.makeHuman(pr.x - 16, pr.y + 18, { arch: 'timid', cash: 20 });
    widow.strangerName = `Mrs. ${f.name.split(' ').slice(-1)[0]}`; widow.keep = true; this.actors.push(widow);
    for (let k = 0; k < 4; k++) {
      const p = place(-3 + k * 2, 4), m = g.actors.makeHuman(p.x, p.y, { arch: 'tough', role: 'soldier', weapon: 'revolver', cash: 30 });
      m.strangerName = `${f.fam} soldier`; m.keep = true; m.mourner = f.fam; this.actors.push(m);
    }
    const gp = f.guest != null ? g.pop.people[f.guest] : null;
    if (gp && gp.alive && !gp.actor) {
      const p = place(3, 3), h = g.actors.makeHuman(p.x, p.y, { person: gp, cash: 400 });
      h.keep = true; h.funeralGuest = true; this.actors.push(h); f.guestActor = h;
      for (let k = 0; k < 2; k++) { const b = g.actors.makeHuman(p.x + (k ? 14 : -14), p.y + 10, { arch: 'tough', weapon: 'shotgun', cash: 25 }); b.strangerName = 'Bodyguard'; b.keep = true; b.guarding = h; this.actors.push(b); }
    }
    for (const a of this.actors) { a.state = 'idle'; a.timer = 1e9; a.angle = Math.atan2(oy - a.y, ox - a.x); }
  };
  FU.clear = function () {
    const g = G();
    for (const a of this.actors) if (a && !a.dead && !a.removed && !a.hostile && !a.carried) g.actors.remove(a);
    this.actors = [];
  };
  FU.respects = function (f) {
    const g = G(), pl = g.player, s = this.state();
    if (f.paid) return g.ui.toast('You already paid your respects.');
    if (!pl.pay(100)) return g.ui.toast('You need an envelope: $100.', 'warn');
    f.paid = true; s.paid++;
    if (f.byPlayer && R.rng() < 0.5) {
      g.ui.toast('The widow looks up from the envelope, then at your face, and screams. Every soldier on the steps goes for his gun.', 'bad');
      for (const a of this.actors) if (a.mourner && !a.dead) { a.hostile = true; a.hostileLocked = true; g.actors.setFight(a, pl); }
      return;
    }
    g.jobs.standing[f.fam] = R.clamp((g.jobs.standing[f.fam] || 0) + (f.byPlayer ? 4 : 12), -100, 100);
    pl.rep.honor = (pl.rep.honor || 0) + 1;
    g.ui.toast(`An envelope in the widow's hands, a nod to the soldiers. The ${f.fam} family will remember you came.${f.byPlayer ? ' (Nobody knows. Yet.)' : ''}`, 'good');
  };
  FU.context = function (pl) {
    const f = this.cur();
    if (!f || !f.staged || pl.inCar || pl.room) return null;
    const ch = G().world.buildings[f.bid];
    if (!ch || R.dist(pl.x, pl.y, ch.out.x * TS + 8, ch.out.y * TS + 8) > TS * 5) return null;
    return { label: `The funeral of ${f.name}`, fn: () => G().ui.choice(`Funeral: ${f.name}`, [
      { label: 'Pay your respects', price: '$100', small: `An envelope for the widow. The ${f.fam} family notices who came`, fn: () => this.respects(f) },
      f.guestActor && !f.guestActor.dead ? { label: 'Look over the guests', small: 'Who came, and who\'s watching them', fn: () => G().ui.toast(`${f.guestActor.person ? `${f.guestActor.person.first} ${f.guestActor.person.last}` : 'A rival boss'} of the ${f.guestActor.person ? f.guestActor.person.faction : 'other'} family, on the steps, two bodyguards. The soldiers are all watching the widow.`) } : null,
      { label: 'Leave', fn: () => {} },
    ].filter(Boolean)) };
  };
  FU.update = function (dt) {
    const g = G(), pl = g.player, s = this.state();
    this.t -= dt;
    if (this.t > 0) return;
    this.t = 1;
    const h = g.clock.hour();
    for (const f of s.list) {
      if (f.over) continue;
      if (g.pop.day > f.day || (g.pop.day === f.day && h >= 13)) { f.over = true; if (f.staged) this.clear(); continue; }
      if (g.pop.day !== f.day || h < 9) continue;
      const ch = g.world.buildings[f.bid];
      if (!ch) { f.over = true; continue; }
      const d = R.dist(pl.x, pl.y, ch.out.x * TS, ch.out.y * TS);
      if (!f.staged && d < TS * 40) this.stage(f);
      // keep the named guest from wandering off to his usual day
      if (f.guestActor && !f.guestActor.dead && f.guestActor.person && g.life) f.guestActor.destKey = g.life.desiredKey(f.guestActor.person);
      // the hit
      if (f.guestActor && f.guestActor.dead && !f.hit) {
        f.hit = true; s.hits++;
        const own = pl.family, gp = f.guestActor.person;
        if (own && gp && gp.faction !== own) { pl.addCash(1500); g.jobs.standing[own] = R.clamp((g.jobs.standing[own] || 0) + 10, -100, 100); }
        for (const a of this.actors) if (!a.dead && (a.mourner || a.guarding)) { a.hostile = true; a.hostileLocked = true; g.actors.setFight(a, pl); }
        g.pop.addNews(ch.cityId || g.world.cities[0].id, `MASSACRE ON THE CHURCH STEPS. ${gp ? `${gp.first} ${gp.last}` : 'A mourner'} gunned down at the funeral of ${f.name}. "Is nothing sacred?" asks the Archbishop.`);
        g.ui.toast(`The guest of honour goes down on the church steps.${own && gp && gp.faction !== own ? ' Your family sends $1,500 and its compliments.' : ''}`, 'good');
      }
    }
  };
  FU.draw = function (gx) {
    const f = this.cur();
    if (!f || !f.staged) return;
    const ch = G().world.buildings[f.bid];
    if (!ch) return;
    // the hearse-black coffin on its stand, and wreaths
    const x = ch.out.x * TS + 8, y = ch.out.y * TS + 8 + 22;
    gx.fillStyle = '#3a2a1a'; gx.fillRect(x - 3, y + 3, 1, 4); gx.fillRect(x + 12, y + 3, 1, 4);
    gx.fillStyle = '#1a1210'; gx.fillRect(x - 5, y - 2, 20, 6); gx.fillStyle = '#6a4a2a'; gx.fillRect(x - 5, y - 2, 20, 1); gx.fillStyle = '#c8a040'; gx.fillRect(x + 1, y, 6, 1);
    for (const [dx, c] of [[-12, '#e8e0e0'], [22, '#c83040']]) { gx.fillStyle = '#2a5a2a'; gx.fillRect(x + dx - 3, y - 4, 7, 7); gx.fillStyle = c; gx.fillRect(x + dx - 1, y - 2, 3, 3); }
  };
  FU.init = function (g) {
    this.t = 0; this.actors = [];
    if (!this.onDeathFn) this.onDeathFn = (p, by) => FU.onDeath(p, by);
    const ls = R.bus.map.get('person:died');
    if (!ls || !ls.includes(this.onDeathFn)) R.bus.on('person:died', this.onDeathFn);
    if (this.wrapped) return;
    this.wrapped = true;
    const PP = R.Player.prototype, ctx = PP.contextAction;
    PP.contextAction = function () { return FU.context(this) || ctx.call(this); };
    const GP = R.Game.prototype, tk = GP.tick;
    GP.tick = function (dt) { const r = tk.apply(this, arguments); if (this.pop && this.player && this.jobs && !this.ui.paused()) FU.update(dt); return r; };
    const rd = R.ring.draw;
    R.ring.draw = function (gx) { rd.apply(this, arguments); FU.draw(gx); };
  };
})();
