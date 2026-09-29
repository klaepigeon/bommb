// RHAPSODY — roadblocks. Run from the police in a car with a serious warrant (level 2 and up)
// and they stop chasing and start thinking: two cruisers slewed across the road ahead, officers
// behind the doors with shotguns, and a spike strip laid in front. Hit the strip and your tyres
// go: the car limps along at a crawl until a garage fixes it. Go round, go through, or go on foot.
'use strict';
(function () {
  const TS = R.TILE;
  const G = () => R.game;
  const RB = (R.roadblock = { strips: [], blocks: 0 });

  RB.place = function () {
    const g = G(), pl = g.player, v = pl.inCar, w = g.world, inc = g.law.incident;
    if (!v || !inc) return false;
    const ang = v.angle, ahead = 20;
    const tx = Math.round(v.x / TS + Math.cos(ang) * ahead), ty = Math.round(v.y / TS + Math.sin(ang) * ahead);
    const s = w.findNear(tx, ty, 0, 5, (x, y) => w.flow[w.idx(x, y)] && R.data.roadTile[w.t(x, y)]);
    if (!s) return false;
    const cx = s.x * TS + 8, cy = s.y * TS + 8, px = -Math.sin(ang), py = Math.cos(ang);
    for (const side of [-1, 1]) {
      const car = g.traffic.make('police', cx + px * side * 22, cy + py * side * 22, ang + Math.PI / 2, { parked: true, keep: true, locked: true });
      car.siren = true; car.roadblock = true;
      const cop = g.actors.makeHuman(car.x - Math.cos(ang) * 22, car.y - Math.sin(ang) * 22, { cop: true, role: 'cop', city: inc.jur });
      cop.look = g.pop.makeLook(R.mulberry(R.rng.int(0, 1e9)), { fem: R.rng.chance(0.25), age: 35, role: 'cop', city: inc.jur });
      g.actors.arm(cop, R.rng.pick(['shotgun', 'shotgun', 'revolver']));
      cop.keep = true;
      inc.units.push(cop);
    }
    // the strip, across the lanes in front of the cars
    this.strips.push({ x: cx - Math.cos(ang) * 30, y: cy - Math.sin(ang) * 30, ang: ang + Math.PI / 2, len: 70, t: 0 });
    if (this.strips.length > 4) this.strips.shift();
    this.blocks++;
    g.ui.toast('ROADBLOCK AHEAD. Cruisers across the road, and something glinting on the tarmac.', 'bad');
    g.audio.sfx('alarm');
    return true;
  };
  RB.spike = function (v) {
    if (v.spiked) return;
    v.spiked = true;
    v.model = Object.assign({}, v.model, { top: v.model.top * 0.3, acc: v.model.acc * 0.5 });
    v.hp = Math.max(1, v.hp - 10);
    const g = G();
    g.audio.sfx('crash', v.x, v.y);
    for (let k = 0; k < 10; k++) g.fx.add({ x: v.x, y: v.y, vx: (R.rng() - 0.5) * 60, vy: (R.rng() - 0.5) * 60, life: 0.5, max: 0.5, c: '#2a2a2a', s: 2 });
    if (v === g.player.inCar) g.ui.toast('BANG BANG BANG. All four tyres. The car wallows along on the rims. A garage can fix it.', 'bad');
  };
  RB.update = function (dt) {
    const g = G(), pl = g.player, inc = g.law.incident;
    // strips bite anything driving over them
    for (const s of this.strips) {
      s.t += dt;
      for (const v of g.traffic.list) {
        if (v.removed || v.spiked || v.roadblock || Math.abs(v.speed) < 10) continue;
        const dx = v.x - s.x, dy = v.y - s.y, along = dx * Math.cos(s.ang) + dy * Math.sin(s.ang), across = -dx * Math.sin(s.ang) + dy * Math.cos(s.ang);
        if (Math.abs(along) < s.len / 2 && Math.abs(across) < 7) this.spike(v);
      }
    }
    this.strips = this.strips.filter((s) => s.t < 240);
    this.t = (this.t || 0) - dt;
    if (this.t > 0) return;
    this.t = 2;
    if (inc && inc.level >= 2 && pl.inCar && Math.abs(pl.inCar.speed) > 60 && g.clock.t > (this.next || 0)) { if (this.place()) this.next = g.clock.t + 25; }
  };
  RB.draw = function (gx) {
    for (const s of this.strips) {
      const c = Math.cos(s.ang), sn = Math.sin(s.ang);
      for (let k = -s.len / 2; k <= s.len / 2; k += 4) {
        const x = Math.round(s.x + c * k), y = Math.round(s.y + sn * k);
        gx.fillStyle = '#1a1a1a'; gx.fillRect(x - 1, y - 1, 3, 3);
        gx.fillStyle = '#c8c8d0'; gx.fillRect(x, y - 2, 1, 1);
      }
    }
  };
  RB.init = function (g) {
    this.strips = []; this.next = 0;
    if (this.wrapped) return;
    this.wrapped = true;
    const GP = R.Game.prototype, tk = GP.tick;
    GP.tick = function (dt) { const r = tk.apply(this, arguments); if (this.law && this.traffic && !this.ui.paused()) RB.update(dt); return r; };
    const rd = R.ring.draw;
    R.ring.draw = function (gx) { rd.apply(this, arguments); if (RB.strips.length) RB.draw(gx); };
    // a garage fixes the tyres
    const U = R.UI.prototype, io = U.interiorOptions;
    U.interiorOptions = function (b) {
      const o = io.call(this, b), g2 = this.game, v = g2.player.inCar || g2.traffic.list.find((q) => !q.removed && q.spiked && (q.owner === 'player' || q.stolen) && R.dist(q.x, q.y, b.out.x * TS, b.out.y * TS) < TS * 8);
      if ((b.type === 'garage' || b.type === 'gas') && v && v.spiked) o.push({ label: 'New tyres', price: '$80', small: 'Four whitewalls, no questions', fn: () => { if (!g2.player.pay(80)) return g2.ui.toast('$80 for tyres.'); v.spiked = false; v.model = R.data.vehicles[v.modelId]; g2.ui.toast('Four new tyres. She rides like new.', 'good'); } });
      return o;
    };
  };
})();
