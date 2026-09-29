// RHAPSODY — the Phone Man. Once people know your name (infamy 10+), a payphone near you rings
// every couple of days. Answer it and a voice nobody has ever put a face to offers a contract:
// a name, where they'll be, a price, and sometimes a way he'd like it done (with a knife, no
// guns, make it look like an accident, in broad daylight). Do it his way for double. The money
// is waiting in an envelope taped under the payphone you answered. Let the deadline pass and
// he doesn't call for a while.
'use strict';
(function () {
  const TS = R.TILE, D = R.data;
  const G = () => R.game;
  const PM = (R.phoneman = {});
  const STYLES = [
    { id: 'any', text: 'However you like.', test: () => true },
    { id: 'knife', text: 'With a blade. He wants it personal.', test: (k) => k.blade },
    { id: 'nogun', text: 'No guns. Nothing the ballistics boys can use.', test: (k) => !k.gun },
    { id: 'accident', text: 'Make it look like an accident: a car, the water, a fire, a fall.', test: (k) => ['car', 'drown', 'fire', 'fall', 'blast'].includes(k.kind) },
    { id: 'daylight', text: 'In broad daylight. He wants people to see.', test: (k) => k.hour >= 9 && k.hour < 18 },
    { id: 'quiet', text: 'Quietly. A silencer, or your hands.', test: (k) => k.silenced || k.melee },
  ];
  PM.state = function () { const st = R.shark.street(); return (st.phone = st.phone || { ring: null, job: null, done: 0, cool: 0 }); };
  const phonesNear = (x, y, r) => {
    const w = G().world, out = [], tx = (x / TS) | 0, ty = (y / TS) | 0;
    for (let yy = ty - r; yy <= ty + r; yy++) for (let xx = tx - r; xx <= tx + r; xx++) if (w.inb(xx, yy) && w.o(xx, yy) === D.O.PHONE) out.push({ x: xx, y: yy });
    return out;
  };
  // a phone rings
  PM.ringNear = function () {
    const g = G(), pl = g.player, s = this.state();
    if (s.job || s.ring || pl.room) return false;
    const ph = phonesNear(pl.x, pl.y, 28).sort((a, b) => Math.hypot(a.x * TS - pl.x, a.y * TS - pl.y) - Math.hypot(b.x * TS - pl.x, b.y * TS - pl.y))[0];
    if (!ph) return false;
    s.ring = { x: ph.x, y: ph.y, until: g.clock.t + 180 };
    g.ui.toast('A payphone is ringing nearby. It keeps ringing.', 'warn');
    if (!g.waypoint) g.waypoint = { x: ph.x * TS + 8, y: ph.y * TS + 8 };
    return true;
  };
  PM.offer = function () {
    const g = G(), pop = g.pop, s = this.state();
    const pool = pop.people.filter((p) => p.alive && p.age >= 20 && !p.isDon && !p.playerPartner && !p.playerChild && p.home != null && p.role !== 'cop');
    const p = R.rng.pick(pool);
    if (!p) return null;
    const style = R.rng() < 0.35 ? STYLES[0] : R.rng.pick(STYLES.slice(1));
    const pay = R.rng.int(4, 10) * 100;
    return { pid: p.id, style: style.id, pay, until: pop.day + 3, at: { x: s.ring.x, y: s.ring.y } };
  };
  PM.answer = function () {
    const g = G(), s = this.state(), job = this.offer(), pop = g.pop;
    s.ring = null;
    if (!job) return g.ui.toast('Dial tone.');
    const p = pop.people[job.pid], st = STYLES.find((x) => x.id === job.style), home = g.world.buildings[p.home];
    g.audio.sfx('click');
    g.ui.story('The Phone Man', `"Don't say anything. Just listen."\n\n"${p.first} ${p.last}. ${p.age}. Lives at ${home ? home.name : 'the edge of town'}${p.work != null && g.world.buildings[p.work] ? ', works at ' + g.world.buildings[p.work].name : ''}. ${R.fmtMoney(job.pay)}. Three days."\n\n"${st.text}${job.style !== 'any' ? ' Do it my way and it pays double.' : ''}"\n\n"The money will be under this phone." Click.`, () => {
      g.ui.choice('The contract', [
        { label: `Take it (${R.fmtMoney(job.pay)}${job.style !== 'any' ? ', double his way' : ''})`, small: `${p.first} ${p.last} · ${st.text}`, fn: () => {
          s.job = job;
          p.met = true;
          if (home && R.poi) R.poi.add(home.out.x, home.out.y, 'tip', `${p.first} ${p.last}`, 'The Phone Man\'s contract');
          if (home) g.waypoint = { x: home.out.x * TS + 8, y: home.out.y * TS + 8 };
          g.ui.toast(`Contract: ${p.first} ${p.last}. Their house is marked.`, 'warn');
        } },
        { label: 'Hang up', small: 'He won\'t call again for a while', fn: () => { s.cool = g.clock.t + 1440 * 3; } },
      ]);
    });
  };
  // how a kill was done
  PM.onKill = function (h, source, kind) {
    const g = G(), s = this.state(), job = s.job, pl = g.player;
    if (!job || !h.person || h.person.id !== job.pid) return;
    const byMe = source === pl || (source && source.driver === pl);
    const w = D.weapons[pl.weapon] || {};
    const k = { kind: kind || h.lastHitKind, blade: !!w.blade && (kind === 'melee' || !kind), gun: !!w.gun && kind === 'bullet', melee: kind === 'melee', silenced: pl.silencedGun && pl.silencedGun(pl.weapon), hour: g.clock.hour() };
    if (!byMe && !['drown', 'fire', 'fall', 'car'].includes(k.kind)) { s.job = null; g.ui.toast('Somebody else got to your contract first. The Phone Man doesn\'t pay for luck.', 'warn'); return; }
    const st = STYLES.find((x) => x.id === job.style);
    const his = job.style !== 'any' && st.test(k);
    job.done = true; job.paid = his ? job.pay * 2 : job.pay;
    g.ui.toast(his ? 'Done his way. The envelope will be fat.' : 'Done. The envelope is waiting under the payphone.', 'good');
  };
  // collect at the phone you answered
  PM.context = function (pl) {
    const s = this.state(), g = G();
    if (s.ring) for (const ph of phonesNear(pl.x, pl.y, 1)) if (ph.x === s.ring.x && ph.y === s.ring.y) return { label: 'Answer the ringing phone', fn: () => this.answer() };
    const job = s.job;
    if (job && job.done) for (const ph of phonesNear(pl.x, pl.y, 1)) if (ph.x === job.at.x && ph.y === job.at.y) return { label: 'Feel under the payphone', fn: () => { pl.addCash(job.paid); s.done++; s.job = null; s.cool = g.clock.t + 1440 * 2; g.audio.sfx('cash'); g.ui.toast(`An envelope, taped under the box: ${R.fmtMoney(job.paid)}. Nobody saw you take it.`, 'good'); } };
    return null;
  };
  PM.update = function (dt) {
    const g = G(), s = this.state(), pl = g.player;
    this.t = (this.t || 0) - dt;
    if (this.t > 0) return;
    this.t = 5;
    if (s.ring && g.clock.t > s.ring.until) { s.ring = null; g.ui.toast('The payphone stops ringing.'); }
    if (s.job && !s.job.done && g.pop.day > s.job.until) { s.job = null; s.cool = g.clock.t + 1440 * 4; g.ui.toast('The Phone Man\'s deadline passed. He won\'t be calling for a while.', 'warn'); }
    if (!s.job && !s.ring && (pl.rep.infamy || 0) >= 10 && g.clock.t > (s.cool || 0) && R.rng() < 0.02) this.ringNear();
  };
  PM.init = function (g) {
    this.t = 10;
    if (this.wrapped) return;
    this.wrapped = true;
    const PP = R.Player.prototype, ctx = PP.contextAction;
    PP.contextAction = function () { return (!this.inCar && !this.room && PM.context(this)) || ctx.call(this); };
    const C = R.combat, ck = C.kill;
    C.kill = function (h, source, kind) { const was = h && h.dead, r = ck.apply(this, arguments); if (!was && h && h.dead) PM.onKill(h, source, kind); return r; };
    const GP = R.Game.prototype, tk = GP.tick;
    GP.tick = function (dt) { const r = tk.apply(this, arguments); if (this.player && this.pop && !this.ui.paused()) PM.update(dt); return r; };
  };
})();
