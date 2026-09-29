// RHAPSODY — hurricane season. Every few weeks a storm comes in off the Gulf. The radio and the
// papers warn you a day ahead; then the wind comes, sideways rain, debris in the air, and the
// power goes out across the whole coast. In the blackout the street lights and signs die, the
// burglar alarms are dead, and every shop register is there for the taking (the police have
// their hands full). The lights come back a few hours after the wind drops. Then the papers
// count the damage.
'use strict';
(function () {
  const G = () => R.game;
  const HU = (R.hurricane = {});
  const NAMES = ['Agnes', 'Camille', 'Celia', 'Eloise', 'Frederic', 'Anita', 'Babe', 'Carmen', 'Delia', 'Fifi', 'Gilda', 'Hilda'];
  HU.state = function () { const st = R.shark.street(); return (st.storm = st.storm || { next: 18 + R.rng.int(0, 20), warned: false, until: 0, power: 0, name: null, count: 0, looted: {} }); };
  HU.active = function () { const g = G(), s = this.state(); return g.clock.t < s.until; };
  HU.warn = function () {
    const g = G(), s = this.state();
    s.name = NAMES[s.count % NAMES.length]; s.warned = true;
    g.pop.addNews(g.world.cities[0].id, `HURRICANE ${s.name.toUpperCase()} TO MAKE LANDFALL TOMORROW NIGHT. Board up your windows; the power company says to expect outages.`);
    g.ui.toast(`Radio: Hurricane ${s.name} makes landfall tomorrow night. Expect the power to go.`, 'warn');
  };
  HU.start = function (hours) {
    const g = G(), s = this.state();
    if (!s.name) s.name = NAMES[s.count % NAMES.length];
    s.until = g.clock.t + (hours || 10) * 60;
    s.power = s.until + 4 * 60;
    s.looted = {};
    g.env.setWeather('storm');
    g.ui.banner(`HURRICANE ${s.name.toUpperCase()}`, 'The power\'s out across the coast. The alarms are dead. The cops are busy.');
    g.audio.sfx('thunder');
  };
  HU.end = function () {
    const g = G(), s = this.state();
    s.count++; s.warned = false; s.next = g.pop.day + 18 + R.rng.int(0, 20);
    g.pop.addNews(g.world.cities[0].id, `${s.name} is gone. ${R.rng.int(40, 400)} homes damaged, ${R.rng.int(2, 30)} stores looted in the blackout. "Animals," says the mayor.`);
    g.ui.toast(`Hurricane ${s.name} has blown through. The power's back.`, 'good');
    s.name = null;
  };
  HU.update = function (dt) {
    const g = G(), s = this.state(), day = g.pop.day, w = g.env.weather;
    const blackout = g.clock.t < (s.power || 0);
    R.blackout = blackout;
    if (this.active()) {
      if (w.kind !== 'storm') g.env.setWeather('storm');
      w.wind = { x: 3.2, y: 0.6 };
      // debris in the air near you
      if (R.rng() < dt * 6 && g.player && !g.player.room) {
        const pl = g.player;
        g.fx.add({ x: pl.x - 180 + R.rng() * 40, y: pl.y - 120 + R.rng() * 240, vx: 260 + R.rng() * 120, vy: (R.rng() - 0.5) * 60, life: 1.6, max: 1.6, c: R.rng.pick(['#6a5a3a', '#3a5a2a', '#8a8a7a', '#5a4030']), s: 2 });
      }
    } else if (s.name && g.clock.t >= s.until && s.until > 0 && !blackout) this.end();
    if (!s.warned && day >= s.next - 1 && !this.active()) this.warn();
    if (s.warned && day >= s.next && !this.active() && g.clock.hour() >= 18 && g.clock.t > (s.power || 0)) this.start(10);
  };
  HU.init = function (g) {
    if (this.wrapped) return;
    this.wrapped = true;
    const GP = R.Game.prototype, tk = GP.tick;
    GP.tick = function (dt) { const r = tk.apply(this, arguments); if (this.env && this.pop && this.world && !this.ui.paused()) HU.update(dt); return r; };
    // the registers, in the dark
    const U = R.UI.prototype, io = U.interiorOptions;
    const SHOPS = new Set(['general', 'liquor', 'pharmacy', 'pawn', 'gunshop', 'tailor', 'diner', 'bar', 'butcher', 'laundry', 'barber', 'costume', 'garage', 'gas']);
    U.interiorOptions = function (b) {
      const o = io.call(this, b), g2 = this.game, s = HU.state();
      if (R.blackout && SHOPS.has(b.type) && !s.looted[b.id]) o.push({ label: 'Clean out the register', small: 'Blackout: no alarm, no lights, cops stretched thin', fn: () => {
        s.looted[b.id] = 1;
        const n = R.rng.int(40, 220);
        g2.player.addCash(n, true);
        g2.audio.sfx('cash');
        if (R.rng() < 0.15) g2.law.crime('robbery', g2.player.x, g2.player.y, { minor: true });
        g2.ui.toast(`By flashlight: ${R.fmtMoney(n)} from the till. Nobody's coming.`, 'good');
      } });
      return o;
    };
  };
})();
