// RHAPSODY — chunk scheduling. The world is painted in cached chunks; two things used to
// stall a frame: the dusk/dawn switch (every lit window changes, so the whole cache was
// thrown away and repainted at once, ~45 ms) and walking into unpainted ground. Now:
//  - dusk/dawn marks chunks stale; stale chunks keep drawing while at most two a frame are
//    repainted, so the lights come on across the city over a few frames instead of a hitch
//  - between frames (idle callback, or leftover frame time) the chunks just ahead of the
//    camera are painted before you get there
'use strict';
interface ChunkEntry { canvas: HTMLCanvasElement; used: number; stale?: boolean }
(function () {
  const A = R.art;
  const TS = R.TILE;
  const cache: Map<number, ChunkEntry> = A.chunkCache;
  const CH: number = A.CH;
  const baseGet: (world: World, cx: number, cy: number) => HTMLCanvasElement = A.getChunk;
  let budget = 2;

  A.getChunk = function (world: World, cx: number, cy: number): HTMLCanvasElement {
    const key = (cx << 16) | cy;
    const c = cache.get(key);
    if (c && c.stale && !world.dirty.has(key)) {
      if (budget <= 0) { c.used = performance.now(); return c.canvas; } // repaint later
      budget--;
      c.stale = false;
      world.dirty.add(key); // let the base painter redo it in place
    }
    return baseGet.call(this, world, cx, cy);
  };
  // dusk and dawn: everything needs repainting, but not all at once
  A.staleAll = function () { for (const c of cache.values()) c.stale = true; };

  // prefetch: the ring of chunks ahead of where the camera is heading
  let lastX = 0, lastY = 0;
  // paints at most `max` chunks (a chunk is 32x32 tiles, 3-20 ms to paint: one per idle slot)
  const prefetch = (max: number) => {
    const g = R.game;
    if (!g || !g.started || g.player.room || !g.world) return;
    const cam = g.cam, z = cam.zoom || 2, cpx = CH * TS;
    const vx = cam.x - lastX, vy = cam.y - lastY;
    lastX = cam.x; lastY = cam.y;
    const left = cam.left(), top = cam.top(), vw = cam.vw / z, vh = cam.vh / z;
    const lead = 1.5;
    const x0 = Math.floor((left - cpx * (vx < 0 ? lead : 0.5)) / cpx), x1 = Math.floor((left + vw + cpx * (vx > 0 ? lead : 0.5)) / cpx);
    const y0 = Math.floor((top - cpx * (vy < 0 ? lead : 0.5)) / cpx), y1 = Math.floor((top + vh + cpx * (vy > 0 ? lead : 0.5)) / cpx);
    const w = g.world, maxX = Math.floor(w.W / CH) - 1, maxY = Math.floor(w.TH / CH) - 1;
    for (let cy = Math.max(0, y0); cy <= Math.min(maxY, y1); cy++)
      for (let cx = Math.max(0, x0); cx <= Math.min(maxX, x1); cx++) {
        if (max <= 0) return;
        const key = (cx << 16) | cy, c = cache.get(key);
        if (c && !c.stale && !w.dirty.has(key)) continue;
        if (c && c.stale) { c.stale = false; w.dirty.add(key); }
        baseGet.call(A, w, cx, cy);
        PF.prefetched++;
        max--;
      }
  };
  const PF = (R.chunks = { prefetched: 0, prefetch } as { prefetched: number; [k: string]: any });
  type Idle = { timeRemaining(): number; didTimeout?: boolean };
  const idle = (cb: (d: Idle) => void) => {
    const ric = (window as any).requestIdleCallback as undefined | ((f: (d: Idle) => void, o?: { timeout: number }) => number);
    if (ric) ric(cb, { timeout: 250 });
    else setTimeout(() => cb({ timeRemaining: () => 8 }), 50);
  };
  const tick = (d: Idle) => {
    // one chunk per idle slot: better painted between frames than in the middle of one
    try { if (d.didTimeout || d.timeRemaining() > 1) prefetch(1); } catch (e) { /* the world may be rebuilding */ }
    idle(tick);
  };
  idle(tick);

  // a fresh repaint budget every frame
  const RP = R.Renderer.prototype, bRender = RP.render;
  RP.render = function (this: any) { budget = 2; return bRender.apply(this, arguments as any); };
})();
