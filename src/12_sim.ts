// RHAPSODY — the simulation thread. Two jobs:
//  1. A fixed-timestep driver: the simulation always advances in 1/60 s steps, however
//     fast or slow the screen refreshes (a 120 Hz phone, a 30 fps laptop). The render runs
//     every frame; the sim catches up in whole steps (at most four per frame, then it
//     lets time go rather than spiral).
//  2. A Web Worker for route planning, the heaviest job that doesn't touch the scene:
//     the road-loving coarse grid (rebuilt every 30 s as the world changes) and the A*
//     across it run off the main thread. The same planning code runs synchronously as a
//     fallback if workers aren't allowed (some sandboxes) or the worker goes quiet.
'use strict';

interface RouteGridTables { road: Uint8Array; water: Uint8Array; solid: Uint8Array; walk: Uint8Array; bridge: number }
interface RouteGrid { CW: number; CH: number; cost: Float32Array; px: Int16Array; py: Int16Array }
type RoutePath = [number, number][] | null;
interface RouteCore {
  build(W: number, TH: number, tile: Uint8Array, tabs: RouteGridTables): RouteGrid;
  find(G: RouteGrid, sx: number, sy: number, gx: number, gy: number): RoutePath;
}

// The planning code, self-contained so it can be stringified into the worker.
function routeCore(): RouteCore {
  const C4 = 4;
  return {
    // per 4x4 cell: a cost, and a representative tile to draw through (a road tile if there is one)
    build(W, TH, tile, tabs) {
      const CW = Math.ceil(W / C4), CH = Math.ceil(TH / C4);
      const cost = new Float32Array(CW * CH), px = new Int16Array(CW * CH), py = new Int16Array(CW * CH);
      for (let cy = 0; cy < CH; cy++) for (let cx = 0; cx < CW; cx++) {
        let road = 0, walk = 0, open = 0, water = 0, bridge = 0, bx = -1, by = -1, bd = 1e9;
        for (let y = cy * C4; y < cy * C4 + C4; y++) for (let x = cx * C4; x < cx * C4 + C4; x++) {
          if (x < 0 || y < 0 || x >= W || y >= TH) continue;
          const t = tile[y * W + x];
          if (t === tabs.bridge) bridge++;
          if (tabs.road[t]) { road++; const d = Math.abs(x - cx * C4 - 1.5) + Math.abs(y - cy * C4 - 1.5); if (d < bd) { bd = d; bx = x; by = y; } }
          else if (tabs.walk[t]) walk++;
          else if (tabs.water[t]) water++;
          else if (!tabs.solid[t]) open++;
        }
        const i = cy * CW + cx;
        cost[i] = bridge ? 1 : road ? 1 : walk ? 1.6 : water > 10 ? -1 : open > 4 ? 3 : -1;
        if (bx < 0) { bx = cx * C4 + 2; by = cy * C4 + 2; }
        px[i] = bx; py[i] = by;
      }
      return { CW, CH, cost, px, py };
    },
    find(G, sx, sy, gx, gy) {
      const CW = G.CW, CH = G.CH;
      const c = (x: number, y: number) => Math.max(0, Math.min(CW - 1, x)) + Math.max(0, Math.min(CH - 1, y)) * CW;
      const start = c((sx / C4) | 0, (sy / C4) | 0), goal = c((gx / C4) | 0, (gy / C4) | 0);
      const n = CW * CH;
      const gs = new Float32Array(n).fill(1e9), from = new Int32Array(n).fill(-1), closed = new Uint8Array(n);
      const heap: number[] = [start], hf: number[] = [0];
      gs[start] = 0;
      const hx = goal % CW, hy = (goal / CW) | 0;
      const push = (i: number, f: number) => { heap.push(i); hf.push(f); let k = heap.length - 1; while (k > 0) { const p = (k - 1) >> 1; if (hf[p] <= hf[k]) break; [heap[p], heap[k]] = [heap[k], heap[p]]; [hf[p], hf[k]] = [hf[k], hf[p]]; k = p; } };
      const pop = () => { const top = heap[0], li = heap.pop() as number, lf = hf.pop() as number; if (heap.length) { heap[0] = li; hf[0] = lf; let k = 0; for (;;) { const l = k * 2 + 1, r = l + 1; let m = k; if (l < heap.length && hf[l] < hf[m]) m = l; if (r < heap.length && hf[r] < hf[m]) m = r; if (m === k) break; [heap[m], heap[k]] = [heap[k], heap[m]]; [hf[m], hf[k]] = [hf[k], hf[m]]; k = m; } } return top; };
      const DX = [1, -1, 0, 0, 1, 1, -1, -1], DY = [0, 0, 1, -1, 1, -1, 1, -1];
      let steps = 0;
      while (heap.length && steps++ < 60000) {
        const cur = pop();
        if (cur === goal) break;
        if (closed[cur]) continue;
        closed[cur] = 1;
        const x = cur % CW, y = (cur / CW) | 0;
        for (let d = 0; d < 8; d++) {
          const dx = DX[d], dy = DY[d], nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= CW || ny >= CH) continue;
          const ni = ny * CW + nx;
          const k = G.cost[ni];
          if (k < 0 && ni !== goal) continue;
          const ng = gs[cur] + Math.max(0.5, k) * (dx && dy ? 1.41 : 1);
          if (ng < gs[ni]) { gs[ni] = ng; from[ni] = cur; push(ni, ng + Math.hypot(nx - hx, ny - hy) * 0.95); }
        }
      }
      if (from[goal] === -1 && goal !== start) return null;
      const out: [number, number][] = [];
      for (let k = goal; k !== -1; k = from[k]) out.push([G.px[k], G.py[k]]);
      out.reverse();
      out[out.length - 1] = [gx, gy];
      return out;
    },
  };
}

interface SimState {
  core: RouteCore;
  worker: Worker | null;
  ready: boolean;
  grid: RouteGrid | null;
  gridW: World | null;
  builtAt: number;
  nextId: number;
  pending: Map<number, (p: RoutePath) => void>;
  sentAt: Map<number, number>;
  stats: { routes: number; worker: number; sync: number; maxWait: number; steps?: number };
  tables(): RouteGridTables;
  start(): void;
  sendGrid(w: World): void;
  route(w: World, sx: number, sy: number, gx: number, gy: number, cb: (p: RoutePath) => void): void;
  fail(why: string): void;
  advance(realDt: number, tick: (dt: number) => void): number;
  STEP: number;
  acc: number;
}

(function () {
  const D = R.data;
  const SIM: SimState = (R.sim = {
    core: routeCore(),
    worker: null,
    ready: false,
    grid: null,
    gridW: null,
    builtAt: -1e9,
    nextId: 1,
    pending: new Map(),
    sentAt: new Map(),
    stats: { routes: 0, worker: 0, sync: 0, maxWait: 0 },
    STEP: 1 / 60,
    acc: 0,
  } as unknown as SimState);

  SIM.tables = function (): RouteGridTables {
    const T = D.T;
    const walk = new Uint8Array(256);
    for (const t of [T.WALK, T.PLAZA, T.PARKING, T.DOCK]) walk[t] = 1;
    const u8 = (a: ArrayLike<number>) => { const o = new Uint8Array(256); for (let i = 0; i < a.length && i < 256; i++) o[i] = a[i] ? 1 : 0; return o; };
    return { road: u8(D.roadTile), water: u8(D.waterTile), solid: u8(D.solidTile), walk, bridge: T.BRIDGE };
  };

  // the worker: the planning core plus a tiny message loop
  SIM.start = function () {
    if (this.worker || typeof Worker === 'undefined' || typeof Blob === 'undefined') return;
    try {
      const src = `'use strict';const core=(${routeCore.toString()})();let grid=null;
onmessage=(e)=>{const m=e.data;
if(m.type==='grid'){grid=core.build(m.W,m.TH,m.tile,m.tabs);postMessage({type:'grid'});}
else if(m.type==='route'){const p=grid?core.find(grid,m.sx,m.sy,m.gx,m.gy):null;postMessage({type:'route',id:m.id,path:p});}};`;
      const url = URL.createObjectURL(new Blob([src], { type: 'text/javascript' }));
      const wk = new Worker(url);
      URL.revokeObjectURL(url);
      wk.onmessage = (e: MessageEvent) => {
        const m = e.data;
        if (m.type === 'grid') { this.ready = true; return; }
        if (m.type === 'route') {
          const cb = this.pending.get(m.id);
          this.pending.delete(m.id);
          const t0 = this.sentAt.get(m.id);
          this.sentAt.delete(m.id);
          if (t0 != null) this.stats.maxWait = Math.max(this.stats.maxWait, performance.now() - t0);
          this.stats.worker++;
          if (cb) cb(m.path as RoutePath);
        }
      };
      wk.onerror = (e: ErrorEvent) => { e.preventDefault(); this.fail(e.message || 'worker error'); };
      this.worker = wk;
    } catch (e) {
      this.fail(String(e && (e as Error).message || e));
    }
  };
  SIM.fail = function (why: string) {
    if (this.worker) { try { this.worker.terminate(); } catch (e) { /* already gone */ } }
    this.worker = null; this.ready = false;
    console.warn('Sim worker off, planning on the main thread:', why);
    // answer anything still waiting, synchronously
    const w = this.gridW;
    for (const [id, cb] of this.pending) { this.pending.delete(id); cb(null); }
    if (w) this.grid = null;
  };
  SIM.sendGrid = function (w: World) {
    this.gridW = w;
    this.builtAt = performance.now();
    if (this.worker) {
      const tile = w.tile.slice(); // a copy the worker owns
      this.worker.postMessage({ type: 'grid', W: w.W, TH: w.TH, tile, tabs: this.tables() }, [tile.buffer]);
    } else this.grid = this.core.build(w.W, w.TH, w.tile, this.tables());
  };
  // plan a route; the answer comes back through cb (asynchronously from the worker)
  SIM.route = function (w: World, sx: number, sy: number, gx: number, gy: number, cb: (p: RoutePath) => void) {
    this.stats.routes++;
    if (this.gridW !== w || performance.now() - this.builtAt > 30000) this.sendGrid(w);
    if (this.worker) {
      const id = this.nextId++;
      this.pending.set(id, cb);
      this.sentAt.set(id, performance.now());
      this.worker.postMessage({ type: 'route', id, sx, sy, gx, gy });
      // a worker that never answers (a strict sandbox): fall back
      const probe = id;
      setTimeout(() => { if (this.pending.has(probe) && !this.ready) this.fail('no answer'); }, 3000);
      return;
    }
    if (!this.grid) this.grid = this.core.build(w.W, w.TH, w.tile, this.tables());
    this.stats.sync++;
    cb(this.core.find(this.grid, sx, sy, gx, gy));
  };

  // ---------------------------------------------------------------- fixed-step driver
  // Real frame time goes into an accumulator; the sim advances in whole 1/60 s steps.
  // Returns how many steps ran (0 on a fast display's in-between frames).
  SIM.advance = function (realDt: number, tick: (dt: number) => void): number {
    this.acc = Math.min(this.acc + Math.max(0, realDt), this.STEP * 8);
    let n = 0;
    while (this.acc >= this.STEP && n < 4) { tick(this.STEP); this.acc -= this.STEP; n++; }
    if (n === 4) this.acc = 0; // too far behind: let the time go instead of spiralling
    this.stats.steps = (this.stats.steps || 0) + n;
    return n;
  };
})();
