// RHAPSODY — the route to your waypoint (or the current job). A coarse road-loving A*
// over 4x4-tile cells plans the way; it draws as a line on the minimap and the full map,
// and as flowing gold chevrons painted on the ground ahead of you.
'use strict';
(function () {
  const D = R.data, T = D.T, TS = R.TILE;
  const C4 = 4;
  const RT = (R.route = { path: null, t: 0 });

  // per-cell cost and a representative tile to draw through (a road tile if there is one)
  RT.build = function (w) {
    const CW = Math.ceil(w.W / C4), CH = Math.ceil(w.TH / C4);
    const cost = new Float32Array(CW * CH), px = new Int16Array(CW * CH), py = new Int16Array(CW * CH);
    for (let cy = 0; cy < CH; cy++) for (let cx = 0; cx < CW; cx++) {
      let road = 0, walk = 0, open = 0, water = 0, bridge = 0, best = null, bd = 1e9;
      for (let y = cy * C4; y < cy * C4 + C4; y++) for (let x = cx * C4; x < cx * C4 + C4; x++) {
        if (!w.inb(x, y)) continue;
        const t = w.t(x, y);
        if (t === T.BRIDGE) bridge++;
        if (D.roadTile[t]) { road++; const d = Math.abs(x - cx * C4 - 1.5) + Math.abs(y - cy * C4 - 1.5); if (d < bd) { bd = d; best = [x, y]; } }
        else if (t === T.WALK || t === T.PLAZA || t === T.PARKING || t === T.DOCK) walk++;
        else if (D.waterTile[t]) water++;
        else if (!D.solidTile[t]) open++;
      }
      const i = cy * CW + cx;
      cost[i] = bridge ? 1 : road ? 1 : walk ? 1.6 : water > 10 ? -1 : open > 4 ? 3 : -1;
      if (!best) best = [cx * C4 + 2, cy * C4 + 2];
      px[i] = best[0]; py[i] = best[1];
    }
    this.grid = { w, CW, CH, cost, px, py };
  };
  RT.find = function (sx, sy, gx, gy) {
    const G = this.grid, CW = G.CW, CH = G.CH;
    const c = (x, y) => Math.max(0, Math.min(CW - 1, x)) + Math.max(0, Math.min(CH - 1, y)) * CW;
    const start = c((sx / C4) | 0, (sy / C4) | 0), goal = c((gx / C4) | 0, (gy / C4) | 0);
    const n = CW * CH;
    const gs = new Float32Array(n).fill(1e9), from = new Int32Array(n).fill(-1), closed = new Uint8Array(n);
    const heap = [start], hf = [0];
    gs[start] = 0;
    const hx = goal % CW, hy = (goal / CW) | 0;
    const push = (i, f) => { heap.push(i); hf.push(f); let k = heap.length - 1; while (k > 0) { const p = (k - 1) >> 1; if (hf[p] <= hf[k]) break; [heap[p], heap[k]] = [heap[k], heap[p]]; [hf[p], hf[k]] = [hf[k], hf[p]]; k = p; } };
    const pop = () => { const top = heap[0], li = heap.pop(), lf = hf.pop(); if (heap.length) { heap[0] = li; hf[0] = lf; let k = 0; for (;;) { const l = k * 2 + 1, r = l + 1; let m = k; if (l < heap.length && hf[l] < hf[m]) m = l; if (r < heap.length && hf[r] < hf[m]) m = r; if (m === k) break; [heap[m], heap[k]] = [heap[k], heap[m]]; [hf[m], hf[k]] = [hf[k], hf[m]]; k = m; } } return top; };
    let steps = 0;
    while (heap.length && steps++ < 60000) {
      const cur = pop();
      if (cur === goal) break;
      if (closed[cur]) continue;
      closed[cur] = 1;
      const x = cur % CW, y = (cur / CW) | 0;
      for (let d = 0; d < 8; d++) {
        const dx = [1, -1, 0, 0, 1, 1, -1, -1][d], dy = [0, 0, 1, -1, 1, -1, 1, -1][d];
        const nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= CW || ny >= CH) continue;
        const ni = ny * CW + nx;
        const k = G.cost[ni];
        if (k < 0 && ni !== goal) continue;
        const ng = gs[cur] + Math.max(0.5, k) * (dx && dy ? 1.41 : 1);
        if (ng < gs[ni]) { gs[ni] = ng; from[ni] = cur; push(ni, ng + Math.hypot(nx - hx, ny - hy) * 0.95); }
      }
    }
    if (from[goal] === -1 && goal !== start) return null;
    const out = [];
    for (let k = goal; k !== -1; k = from[k]) out.push([G.px[k], G.py[k]]);
    out.reverse();
    out[out.length - 1] = [gx, gy];
    return out;
  };
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
    if (!tg) { this.path = null; return; }
    const px = (pl.inCar || pl).x / TS, py = (pl.inCar || pl).y / TS;
    // arrived
    if (tg.wp && Math.hypot(tg.x - px, tg.y - py) < 4) { g.waypoint = null; this.path = null; g.ui.toast('You\'ve arrived.', 'good'); return; }
    if (this.t > 0 && this.path) {
      // stay on it unless the target moved or you wandered well off
      const moved = !this.goal || Math.hypot(this.goal.x - tg.x, this.goal.y - tg.y) > 6;
      const off = this.nearest(px, py).d > 10;
      if (!moved && !off) return;
    }
    this.t = 1.2;
    if (!this.grid || this.grid.w !== g.world || g.clock.real - (this.builtAt || 0) > 30) { this.build(g.world); this.builtAt = g.clock.real; }
    this.goal = { x: tg.x, y: tg.y };
    this.path = Math.hypot(tg.x - px, tg.y - py) < 6 ? null : this.find(px | 0, py | 0, tg.x | 0, tg.y | 0);
  };
  RT.nearest = function (x, y) {
    let bi = 0, bd = 1e9;
    const p = this.path || [];
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
    for (const [col, lw] of [['#1b1410', 5], ['#f0c040', 3]]) {
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
    for (const [col, lw] of [['#1b1410', 6], ['#f0c040', 3.5]]) { c.strokeStyle = col; c.lineWidth = lw; c.beginPath(); p.forEach(([x, y], i) => (i ? c.lineTo(x + 0.5, y + 0.5) : c.moveTo(x + 0.5, y + 0.5))); c.stroke(); }
    c.restore();
  };
})();
