// RHAPSODY — the route to your waypoint (or the current job). A coarse road-loving A*
// over 4x4-tile cells plans the way (on the simulation worker, see 12_sim); it draws as
// a line on the minimap and the full map, and as flowing gold chevrons on the ground.
'use strict';
interface RouteState {
  path: [number, number][] | null;
  t: number;
  goal: { x: number; y: number } | null;
  asked: number;
  target(g: Game): { x: number; y: number; wp?: boolean } | null;
  update(g: Game, dt: number): void;
  nearest(x: number, y: number): { i: number; d: number };
  drawWorld(g: CanvasRenderingContext2D, game: Game, left: number, top: number, vw: number, vh: number): void;
  drawMini(c: CanvasRenderingContext2D, toM: (x: number, y: number) => [number, number]): void;
  drawFull(c: CanvasRenderingContext2D): void;
}
(function () {
  const TS = R.TILE;
  const RT: RouteState = (R.route = { path: null, t: 0, goal: null, asked: 0 } as unknown as RouteState);

  RT.target = function (g) {
    if (g.waypoint) return { x: g.waypoint.x / TS, y: g.waypoint.y / TS, wp: true };
    const m = g.jobs.marker();
    return m ? { x: m.x / TS, y: m.y / TS } : null;
  };
  RT.update = function (g, dt) {
    const pl = g.player;
    if (pl.room) { this.path = null; return; }
    this.t -= dt;
    const tg = this.target(g);
    if (!tg) { this.path = null; this.goal = null; return; }
    const src = pl.inCar || pl;
    const px = src.x / TS, py = src.y / TS;
    // arrived
    if (tg.wp && Math.hypot(tg.x - px, tg.y - py) < 4) { g.waypoint = null; this.path = null; g.ui.toast('You\'ve arrived.', 'good'); return; }
    // stay on the plan unless the target moved or you wandered well off; an unreachable
    // target (no path) is only re-asked on the timer, not every tick
    const moved = !this.goal || Math.hypot(this.goal.x - tg.x, this.goal.y - tg.y) > 6;
    if (this.t > 0 && !moved && (!this.path || this.nearest(px, py).d <= 10)) return;
    this.t = 1.2;
    const goal = { x: tg.x, y: tg.y };
    this.goal = goal;
    if (Math.hypot(tg.x - px, tg.y - py) < 6) { this.path = null; return; }
    // ask the planner; keep drawing the old route until the new one arrives
    const ask = ++this.asked;
    R.sim.route(g.world, px | 0, py | 0, tg.x | 0, tg.y | 0, (p: [number, number][] | null) => {
      if (ask !== this.asked || this.goal !== goal) return; // a newer question is out
      this.path = p;
    });
  };
  RT.nearest = function (x: number, y: number) {
    let bi = 0, bd = 1e9;
    const p: [number, number][] = this.path || [];
    for (let i = 0; i < p.length; i++) { const d = Math.hypot(p[i][0] - x, p[i][1] - y); if (d < bd) { bd = d; bi = i; } }
    return { i: bi, d: bd };
  };
  // gold chevrons on the ground, flowing toward the target, for the next stretch of road
  RT.drawWorld = function (g, game, left, top, vw, vh) {
    const p = this.path;
    if (!p || p.length < 2) return;
    const pl = game.player, src = pl.inCar || pl;
    const start = this.nearest(src.x / TS, src.y / TS).i;
    const t = game.clock.real;
    let dist = 0;
    const spacing = 1.6, flow = (t * 2.4) % spacing;
    for (let i = Math.max(0, start - 1); i < Math.min(p.length - 1, start + 30); i++) {
      const [ax, ay] = p[i], [bx, by] = p[i + 1];
      const seg = Math.hypot(bx - ax, by - ay);
      if (!seg) continue;
      const ang = Math.atan2(by - ay, bx - ax);
      for (let s = (spacing - ((dist - flow) % spacing + spacing) % spacing); s < seg; s += spacing) {
        const x = (ax + (bx - ax) * s / seg) * TS + 8, y = (ay + (by - ay) * s / seg) * TS + 8;
        if (x < left - 16 || y < top - 16 || x > left + vw + 16 || y > top + vh + 16) continue;
        if (Math.hypot(x - src.x, y - src.y) < 18) continue;
        g.save(); g.translate(Math.round(x), Math.round(y)); g.rotate(ang);
        g.fillStyle = 'rgba(20,12,8,0.55)';
        g.beginPath(); g.moveTo(-3, -4); g.lineTo(2, 0); g.lineTo(-3, 4); g.lineTo(-1, 0); g.closePath(); g.fill();
        g.translate(0, -1);
        g.fillStyle = 'rgba(240,192,64,0.9)';
        g.beginPath(); g.moveTo(-3, -4); g.lineTo(2, 0); g.lineTo(-3, 4); g.lineTo(-1, 0); g.closePath(); g.fill();
        g.restore();
      }
      dist += seg;
    }
  };
  RT.drawMini = function (c, toM) {
    const p = this.path;
    if (!p || p.length < 2) return;
    c.save();
    c.lineJoin = 'round'; c.lineCap = 'round';
    for (const [col, lw] of [['#1b1410', 5], ['#f0c040', 3]] as [string, number][]) {
      c.strokeStyle = col; c.lineWidth = lw; c.beginPath();
      p.forEach(([x, y], i) => { const [mx, my] = toM(x * TS + 8, y * TS + 8); if (i) c.lineTo(mx, my); else c.moveTo(mx, my); });
      c.stroke();
    }
    c.restore();
  };
  RT.drawFull = function (c) {
    const p = this.path;
    if (!p || p.length < 2) return;
    c.save(); c.lineJoin = 'round'; c.lineCap = 'round';
    for (const [col, lw] of [['#1b1410', 6], ['#f0c040', 3.5]] as [string, number][]) { c.strokeStyle = col; c.lineWidth = lw; c.beginPath(); p.forEach(([x, y], i) => (i ? c.lineTo(x + 0.5, y + 0.5) : c.moveTo(x + 0.5, y + 0.5))); c.stroke(); }
    c.restore();
  };
})();
