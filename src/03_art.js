// RHAPSODY — procedural pixel art. Terrain is pre-rendered into 32x32-tile chunks;
// people, cars and animals are drawn each frame from a few rectangles.
'use strict';
(function () {
  const D = R.data, T = D.T, O = D.O, F = R.FLOW, TS = R.TILE;
  const A = (R.art = {});
  const CH = 32; // tiles per chunk
  A.CH = CH;

  const shade = (hex, amt) => {
    let n = parseInt(hex.slice(1), 16);
    let r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
    r = R.clamp(Math.round(r + amt), 0, 255);
    g = R.clamp(Math.round(g + amt), 0, 255);
    b = R.clamp(Math.round(b + amt), 0, 255);
    return '#' + ((1 << 24) | (r << 16) | (g << 8) | b).toString(16).slice(1);
  };
  A.shade = shade;

  const base = {};
  base[T.DEEP] = '#1f5566'; base[T.WATER] = '#2f7a86'; base[T.SAND] = '#e3cf9c'; base[T.GRASS] = '#78843e';
  base[T.FOREST] = '#566b33'; base[T.DIRT] = '#a88a5a'; base[T.DESERT] = '#d6b577'; base[T.MARSH] = '#5d6a3c';
  base[T.ROCK] = '#7d7468'; base[T.ROAD] = '#4a4541'; base[T.WALK] = '#b9ab92'; base[T.BLDG] = '#555';
  base[T.LOT] = '#7f8a48'; base[T.PARK] = '#6f8a3e'; base[T.DIRTROAD] = '#9a7a4e'; base[T.BRIDGE] = '#6a5a4a';
  base[T.PLAZA] = '#c08a62'; base[T.FIELD] = '#b89a48'; base[T.SNOW] = '#e8ecee'; base[T.BURNT] = '#3a332e';
  base[T.SITE] = '#9a7a52'; base[T.DOCK] = '#8a6a44'; base[T.PARKING] = '#565049'; base[T.HWY] = '#46423f';
  A.tileColor = base;

  // ------------------------------------------------------------ chunks
  A.chunkCache = new Map();
  A.getChunk = function (world, cx, cy) {
    const key = (cx << 16) | cy;
    let c = A.chunkCache.get(key);
    if (c && !world.dirty.has(key)) {
      c.used = performance.now();
      return c.canvas;
    }
    if (!c) {
      if (A.chunkCache.size >= 40) {
        let oldK = null, oldT = Infinity;
        for (const [k, v] of A.chunkCache) if (v.used < oldT) { oldT = v.used; oldK = k; }
        c = A.chunkCache.get(oldK);
        A.chunkCache.delete(oldK);
      } else {
        const cv = document.createElement('canvas');
        cv.width = cv.height = CH * TS;
        c = { canvas: cv };
      }
      A.chunkCache.set(key, c);
    }
    world.dirty.delete(key);
    c.used = performance.now();
    A.renderChunk(world, cx, cy, c.canvas);
    return c.canvas;
  };

  A.renderChunk = function (world, cx, cy, cv) {
    const g = cv.getContext('2d');
    g.imageSmoothingEnabled = false;
    const x0 = cx * CH, y0 = cy * CH;
    g.clearRect(0, 0, cv.width, cv.height);
    for (let ty = 0; ty < CH; ty++)
      for (let tx = 0; tx < CH; tx++) A.drawTile(g, world, x0 + tx, y0 + ty, tx * TS, ty * TS);
    // buildings overlapping this chunk
    const seen = new Set();
    for (let ty = -1; ty <= CH; ty++)
      for (let tx = -1; tx <= CH; tx++) {
        const b = world.buildingAt(x0 + tx, y0 + ty);
        if (b && !seen.has(b.id)) {
          seen.add(b.id);
          A.drawBuilding(g, b, (b.x - x0) * TS, (b.y - y0) * TS);
        }
      }
    // objects (with a margin so canopies cross chunk borders)
    for (let ty = -2; ty <= CH + 1; ty++)
      for (let tx = -2; tx <= CH + 1; tx++) {
        const o = world.o(x0 + tx, y0 + ty);
        if (o) A.drawObj(g, o, tx * TS, ty * TS, x0 + tx, y0 + ty, world);
      }
  };

  function speck(g, x, y, col, n, h, sz) {
    g.fillStyle = col;
    for (let k = 0; k < n; k++) {
      const a = R.hash2(h, k, 3), b = R.hash2(k, h, 7);
      g.fillRect(x + ((a * TS) | 0), y + ((b * TS) | 0), sz || 1, sz || 1);
    }
  }

  A.drawTile = function (g, w, x, y, px, py) {
    const t = w.t(x, y);
    const h = R.hash2(x, y, 17);
    const hi = (x * 7 + y * 13) | 0;
    let col = base[t] || '#f0f';
    // subtle per-tile variation
    const v = (h - 0.5) * 10;
    g.fillStyle = shade(col, v);
    g.fillRect(px, py, TS, TS);
    switch (t) {
      case T.WATER:
      case T.DEEP: {
        g.fillStyle = shade(col, 14);
        if (h < 0.4) g.fillRect(px + ((h * 30) % 10), py + 5, 5, 1);
        if (h > 0.7) g.fillRect(px + 3, py + 11, 4, 1);
        // shoreline foam
        for (let d = 0; d < 4; d++) {
          const [dx, dy] = R.DIRS[d];
          const nt = w.t(x + dx, y + dy);
          if (!D.waterTile[nt] && nt !== T.BRIDGE && nt !== T.DOCK) {
            g.fillStyle = 'rgba(240,240,220,0.55)';
            if (d === 0) g.fillRect(px, py, TS, 2);
            if (d === 2) g.fillRect(px, py + TS - 2, TS, 2);
            if (d === 1) g.fillRect(px + TS - 2, py, 2, TS);
            if (d === 3) g.fillRect(px, py, 2, TS);
          }
        }
        break;
      }
      case T.GRASS: case T.LOT: case T.PARK:
        speck(g, px, py, shade(col, 16), 5, hi, 1);
        speck(g, px, py, shade(col, -14), 4, hi + 1, 1);
        break;
      case T.FOREST:
        speck(g, px, py, shade(col, -16), 7, hi, 2);
        speck(g, px, py, '#7a6a3a', 2, hi + 3, 1);
        break;
      case T.MARSH:
        speck(g, px, py, '#3e5a48', 5, hi, 2);
        speck(g, px, py, '#7a8a4a', 3, hi + 2, 1);
        break;
      case T.DESERT: case T.SAND: case T.DIRT:
        speck(g, px, py, shade(col, -18), 4, hi, 1);
        speck(g, px, py, shade(col, 12), 3, hi + 5, 1);
        break;
      case T.SNOW:
        speck(g, px, py, '#c8d4dc', 4, hi, 2);
        break;
      case T.ROCK:
        g.fillStyle = shade(col, -20);
        g.fillRect(px, py + 10, TS, 6);
        g.fillStyle = shade(col, 18);
        g.fillRect(px + 2, py + 2, 7, 4);
        speck(g, px, py, shade(col, -35), 3, hi, 2);
        break;
      case T.WALK: {
        g.fillStyle = shade(col, -16);
        g.fillRect(px, py + TS - 1, TS, 1);
        g.fillRect(px + TS - 1, py, 1, TS);
        // curb against road
        for (let d = 0; d < 4; d++) {
          const [dx, dy] = R.DIRS[d];
          if (D.roadTile[w.t(x + dx, y + dy)]) {
            g.fillStyle = '#d8ccb4';
            if (d === 0) g.fillRect(px, py, TS, 2);
            if (d === 2) g.fillRect(px, py + TS - 2, TS, 2);
            if (d === 1) g.fillRect(px + TS - 2, py, 2, TS);
            if (d === 3) g.fillRect(px, py, 2, TS);
          }
        }
        break;
      }
      case T.PLAZA:
        g.fillStyle = shade(col, -18);
        g.fillRect(px, py + 7, TS, 1);
        g.fillRect(px + 7, py, 1, TS);
        break;
      case T.FIELD:
        g.fillStyle = shade(col, -22);
        for (let k = 0; k < TS; k += 4) g.fillRect(px, py + k, TS, 1);
        g.fillStyle = '#d8c060';
        speck(g, px, py, '#d8c060', 3, hi, 1);
        break;
      case T.DOCK:
        g.fillStyle = shade(col, -22);
        for (let k = 0; k < TS; k += 4) g.fillRect(px, py + k + 3, TS, 1);
        g.fillStyle = shade(col, -35);
        g.fillRect(px + 3, py + 1, 1, 1);
        g.fillRect(px + 11, py + 9, 1, 1);
        break;
      case T.PARKING:
        g.fillStyle = '#d8d0b8';
        if (x % 3 === 0) g.fillRect(px, py, 1, TS);
        break;
      case T.BURNT:
        speck(g, px, py, '#1e1a18', 6, hi, 2);
        speck(g, px, py, '#5a4a40', 3, hi + 1, 1);
        break;
      case T.SITE:
        speck(g, px, py, '#7a5a3a', 6, hi, 2);
        g.fillStyle = '#e4a92a';
        if ((x + y) % 5 === 0) g.fillRect(px + 2, py + 6, 12, 2);
        break;
      case T.ROAD: case T.HWY: case T.BRIDGE: case T.DIRTROAD:
        A.drawRoad(g, w, x, y, px, py, t);
        break;
    }
  };

  A.drawRoad = function (g, w, x, y, px, py, t) {
    const f = w.flow[w.idx(x, y)];
    if (t === T.BRIDGE) {
      g.fillStyle = '#54504a';
      g.fillRect(px, py, TS, TS);
      g.fillStyle = '#8a7a6a';
      // rails on the outside edges
      if (!(w.flow[w.idx(x, y - 1)])) g.fillRect(px, py, TS, 2);
      if (!(w.flow[w.idx(x, y + 1)])) g.fillRect(px, py + TS - 2, TS, 2);
      if (!(w.flow[w.idx(x - 1, y)])) g.fillRect(px, py, 2, TS);
      if (!(w.flow[w.idx(x + 1, y)])) g.fillRect(px + TS - 2, py, 2, TS);
    }
    // asphalt grain
    speck(g, px, py, '#3c3835', 4, x * 31 + y, 1);
    speck(g, px, py, '#5a544e', 2, x * 17 + y * 3, 1);
    if (f & F.X) {
      return;
    }
    const center = t === T.HWY || t === T.BRIDGE ? '#e8c040' : '#e4b030';
    // lane divider
    if (f & F.W && w.flow[w.idx(x, y + 1)] & F.E) {
      g.fillStyle = center;
      if (t === T.HWY || t === T.BRIDGE) g.fillRect(px, py + TS - 1, TS, 1), g.fillRect(px, py + TS - 3, TS, 1);
      else if (x % 2 === 0) g.fillRect(px + 2, py + TS - 1, 10, 2);
    }
    if (f & F.S && w.flow[w.idx(x + 1, y)] & F.N) {
      g.fillStyle = center;
      if (t === T.HWY || t === T.BRIDGE) g.fillRect(px + TS - 1, py, 1, TS), g.fillRect(px + TS - 3, py, 1, TS);
      else if (y % 2 === 0) g.fillRect(px + TS - 1, py + 2, 2, 10);
    }
    // crosswalks next to intersections in town
    if (t === T.ROAD) {
      g.fillStyle = 'rgba(235,230,210,0.8)';
      if (f & (F.E | F.W)) {
        if (w.flow[w.idx(x + 1, y)] & F.X) for (let k = 1; k < TS; k += 4) g.fillRect(px + TS - 4, py + k, 3, 2);
        if (w.flow[w.idx(x - 1, y)] & F.X) for (let k = 1; k < TS; k += 4) g.fillRect(px + 1, py + k, 3, 2);
      }
      if (f & (F.N | F.S)) {
        if (w.flow[w.idx(x, y + 1)] & F.X) for (let k = 1; k < TS; k += 4) g.fillRect(px + k, py + TS - 4, 2, 3);
        if (w.flow[w.idx(x, y - 1)] & F.X) for (let k = 1; k < TS; k += 4) g.fillRect(px + k, py + 1, 2, 3);
      }
    }
    if (t === T.HWY) {
      // white shoulder lines
      g.fillStyle = 'rgba(230,225,210,0.6)';
      if (!w.flow[w.idx(x, y - 1)] && f & (F.E | F.W)) g.fillRect(px, py + 1, TS, 1);
      if (!w.flow[w.idx(x, y + 1)] && f & (F.E | F.W)) g.fillRect(px, py + TS - 2, TS, 1);
      if (!w.flow[w.idx(x - 1, y)] && f & (F.N | F.S)) g.fillRect(px + 1, py, 1, TS);
      if (!w.flow[w.idx(x + 1, y)] && f & (F.N | F.S)) g.fillRect(px + TS - 2, py, 1, TS);
    }
  };

  // ------------------------------------------------------------ buildings
  A.drawBuilding = function (g, b, px, py) {
    const bw = b.w * TS, bh = b.h * TS;
    const rnd = R.mulberry(b.seedArt);
    const bt = D.btypes[b.type];
    const facadeH = 7;
    // drop shadow
    g.fillStyle = 'rgba(20,12,8,0.35)';
    g.fillRect(px + 3, py + 3, bw, bh);
    // roof
    const roof = b.roof;
    g.fillStyle = roof;
    g.fillRect(px, py, bw, bh - facadeH);
    // roof texture per type
    if (b.type === 'house' || b.type === 'cabin' || b.type === 'barn' || b.type === 'church') {
      // pitched: ridge + shingles
      g.fillStyle = shade(roof, 18);
      g.fillRect(px, py, bw, Math.floor((bh - facadeH) / 2));
      g.fillStyle = shade(roof, -18);
      for (let yy = 3; yy < bh - facadeH; yy += 4) g.fillRect(px, py + yy, bw, 1);
      g.fillStyle = shade(roof, -30);
      g.fillRect(px, py + Math.floor((bh - facadeH) / 2), bw, 1);
      if (b.type === 'church') {
        g.fillStyle = '#e8e0d0';
        g.fillRect(px + bw / 2 - 5, py + 2, 10, 12);
        g.fillStyle = '#c8a040';
        g.fillRect(px + bw / 2 - 1, py - 4, 2, 10);
        g.fillRect(px + bw / 2 - 4, py - 1, 8, 2);
      }
    } else {
      // flat roof: parapet, AC units, vents, gravel
      g.fillStyle = shade(roof, 20);
      g.fillRect(px, py, bw, 2);
      g.fillRect(px, py, 2, bh - facadeH);
      g.fillRect(px + bw - 2, py, 2, bh - facadeH);
      g.fillStyle = shade(roof, -12);
      for (let k = 0; k < (b.w * b.h) / 2; k++) g.fillRect(px + 3 + rnd() * (bw - 6), py + 3 + rnd() * (bh - facadeH - 6), 1, 1);
      const units = 1 + Math.floor(rnd() * 3);
      for (let k = 0; k < units; k++) {
        const ux = px + 4 + rnd() * Math.max(1, bw - 16), uy = py + 4 + rnd() * Math.max(1, bh - facadeH - 14);
        g.fillStyle = '#8a8a86';
        g.fillRect(ux, uy, 9, 7);
        g.fillStyle = '#5a5a58';
        g.fillRect(ux + 2, uy + 2, 5, 3);
      }
      if (b.floors > 2) {
        g.fillStyle = '#2a2a2a';
        g.fillRect(px + bw - 12, py + 4, 6, 6); // water tank
        g.fillStyle = '#6a4a2a';
        g.fillRect(px + bw - 13, py + 3, 8, 3);
      }
    }
    // facade (always drawn to the south for the 3/4 look)
    const fy = py + bh - facadeH;
    g.fillStyle = b.wall;
    g.fillRect(px, fy, bw, facadeH);
    g.fillStyle = shade(b.wall, -40);
    g.fillRect(px, fy, bw, 1);
    // windows
    g.fillStyle = '#2a3a44';
    for (let wx = 3; wx < bw - 4; wx += 6) g.fillRect(px + wx, fy + 2, 3, 3);
    // awning + door marker on the entrance side
    const dx = (b.door.x - b.x) * TS, dy = (b.door.y - b.y) * TS;
    const aw = bt.neon ? '#e040a0' : shade(roof, 30);
    g.fillStyle = aw;
    if (b.face === 'S') {
      g.fillStyle = '#2a1a12';
      g.fillRect(px + dx + 4, fy + 1, 8, facadeH - 1);
      g.fillStyle = aw;
      for (let k = 0; k < 16; k += 4) g.fillRect(px + dx + k, fy - 3, 3, 3);
    } else if (b.face === 'N') {
      g.fillRect(px + dx + 1, py - 2, 14, 4);
      g.fillStyle = '#f0e0c0';
      for (let k = 2; k < 14; k += 4) g.fillRect(px + dx + 1 + k, py - 2, 2, 4);
    } else if (b.face === 'E') {
      g.fillRect(px + bw - 2, py + dy + 1, 4, 14);
    } else {
      g.fillRect(px - 2, py + dy + 1, 4, 14);
    }
    if (b.type === 'police') {
      g.fillStyle = '#2a4a8a';
      g.fillRect(px + 4, py + 4, 8, 8);
      g.fillStyle = '#e8e8f0';
      g.fillRect(px + 7, py + 5, 2, 6);
      g.fillRect(px + 5, py + 7, 6, 2);
    }
    if (b.type === 'hospital') {
      g.fillStyle = '#c02020';
      g.fillRect(px + bw / 2 - 2, py + 12, 4, 12);
      g.fillRect(px + bw / 2 - 6, py + 16, 12, 4);
    }
  };

  // ------------------------------------------------------------ objects
  A.drawObj = function (g, o, px, py, x, y, w) {
    const h = R.hash2(x, y, 5);
    switch (o) {
      case O.TREE: {
        const c = w.t(x, y) === T.SNOW ? '#4a6a4a' : h < 0.5 ? '#4f6a2a' : '#5e7a30';
        g.fillStyle = 'rgba(10,20,5,0.3)';
        g.beginPath(); g.ellipse(px + 10, py + 13, 9, 5, 0, 0, 7); g.fill();
        g.fillStyle = '#5a3a1e';
        g.fillRect(px + 7, py + 8, 3, 7);
        g.fillStyle = shade(c, -18);
        g.beginPath(); g.arc(px + 8, py + 5, 9, 0, 7); g.fill();
        g.fillStyle = c;
        g.beginPath(); g.arc(px + 7, py + 3, 7, 0, 7); g.fill();
        g.fillStyle = shade(c, 22);
        g.fillRect(px + 4, py - 1, 3, 2);
        if (h > 0.85) { g.fillStyle = '#d9621e'; g.fillRect(px + 10, py + 4, 2, 2); } // autumn leaf
        break;
      }
      case O.PINE: {
        g.fillStyle = 'rgba(10,20,5,0.3)';
        g.beginPath(); g.ellipse(px + 9, py + 14, 7, 3, 0, 0, 7); g.fill();
        g.fillStyle = '#4a2e18';
        g.fillRect(px + 7, py + 10, 2, 5);
        const c = w.t(x, y) === T.SNOW ? '#3a5a4a' : '#2f5230';
        for (let k = 0; k < 3; k++) {
          g.fillStyle = shade(c, k * 10);
          g.beginPath();
          g.moveTo(px + 8, py - 8 + k * 5);
          g.lineTo(px + 15 - k, py + 6 + k * 2);
          g.lineTo(px + 1 + k, py + 6 + k * 2);
          g.fill();
        }
        if (w.t(x, y) === T.SNOW) { g.fillStyle = '#f0f4f4'; g.fillRect(px + 6, py - 6, 4, 2); }
        break;
      }
      case O.PALM:
        g.fillStyle = '#7a5a3a';
        g.fillRect(px + 7, py - 2, 2, 16);
        g.fillStyle = '#4a7a3a';
        for (let k = 0; k < 5; k++) {
          const a = (k / 5) * Math.PI * 2;
          g.fillRect(px + 8 + Math.cos(a) * 5 - 2, py - 3 + Math.sin(a) * 3, 5, 2);
        }
        break;
      case O.CACTUS:
        g.fillStyle = '#4a7a3a';
        g.fillRect(px + 6, py + 1, 4, 14);
        g.fillRect(px + 2, py + 5, 3, 2); g.fillRect(px + 2, py + 2, 2, 4);
        g.fillRect(px + 11, py + 7, 3, 2); g.fillRect(px + 12, py + 4, 2, 4);
        g.fillStyle = '#6a9a4a';
        g.fillRect(px + 7, py + 1, 1, 13);
        break;
      case O.BUSH:
        g.fillStyle = '#4a5a28';
        g.beginPath(); g.arc(px + 8, py + 10, 5, 0, 7); g.fill();
        g.fillStyle = '#5e7034';
        g.beginPath(); g.arc(px + 7, py + 9, 3, 0, 7); g.fill();
        break;
      case O.BOULDER:
        g.fillStyle = '#6a645a';
        g.fillRect(px + 3, py + 6, 10, 8);
        g.fillStyle = '#8a8478';
        g.fillRect(px + 4, py + 6, 6, 3);
        break;
      case O.REED:
        g.fillStyle = '#8a8a4a';
        for (let k = 0; k < 4; k++) g.fillRect(px + 3 + k * 3, py + 5 + ((h * 10 + k) % 4), 1, 8);
        g.fillStyle = '#5a3a1a';
        g.fillRect(px + 6, py + 4, 2, 3);
        break;
      case O.DEADTREE:
        g.fillStyle = '#5a4a3a';
        g.fillRect(px + 7, py + 1, 2, 14);
        g.fillRect(px + 3, py + 4, 5, 1); g.fillRect(px + 9, py + 6, 5, 1);
        break;
      case O.STUMP:
        g.fillStyle = '#2a2420';
        g.fillRect(px + 6, py + 9, 4, 5);
        break;
      case O.FLOWERS:
        for (let k = 0; k < 4; k++) {
          g.fillStyle = ['#e4a92a', '#d9621e', '#e8e0f0', '#c04a8a'][(k + ((h * 4) | 0)) % 4];
          g.fillRect(px + 2 + k * 3, py + 6 + (k % 2) * 4, 2, 2);
        }
        break;
      case O.LAMP:
        g.fillStyle = '#3a3a3a';
        g.fillRect(px + 7, py + 2, 2, 12);
        g.fillStyle = '#2a2a2a';
        g.fillRect(px + 5, py + 13, 6, 2);
        g.fillStyle = '#f0e0a0';
        g.fillRect(px + 5, py + 1, 6, 3);
        break;
      case O.HYDRANT:
        g.fillStyle = '#c83a1a';
        g.fillRect(px + 6, py + 7, 4, 7);
        g.fillRect(px + 5, py + 9, 6, 2);
        g.fillStyle = '#e8c040';
        g.fillRect(px + 6, py + 6, 4, 1);
        break;
      case O.PHONE:
        g.fillStyle = 'rgba(0,0,0,0.3)';
        g.fillRect(px + 4, py + 12, 10, 4);
        g.fillStyle = '#2a5a9a';
        g.fillRect(px + 3, py + 1, 10, 13);
        g.fillStyle = '#a8d0f0';
        g.fillRect(px + 5, py + 4, 6, 7);
        g.fillStyle = '#f0f0e0';
        g.fillRect(px + 3, py + 1, 10, 2);
        break;
      case O.BENCH:
        g.fillStyle = '#6a4a2a';
        g.fillRect(px + 1, py + 6, 14, 3);
        g.fillRect(px + 1, py + 3, 14, 2);
        g.fillStyle = '#2a2a2a';
        g.fillRect(px + 2, py + 9, 1, 3); g.fillRect(px + 13, py + 9, 1, 3);
        break;
      case O.FENCE:
        g.fillStyle = '#7a5a3a';
        g.fillRect(px, py + 6, TS, 2);
        g.fillRect(px, py + 10, TS, 2);
        g.fillRect(px + 2, py + 4, 2, 10); g.fillRect(px + 11, py + 4, 2, 10);
        break;
      case O.PUMP:
        g.fillStyle = '#c04030';
        g.fillRect(px + 4, py + 2, 8, 12);
        g.fillStyle = '#f0f0e0';
        g.fillRect(px + 5, py + 4, 6, 4);
        g.fillStyle = '#2a2a2a';
        g.fillRect(px + 12, py + 6, 2, 5);
        break;
      case O.TRASH:
        g.fillStyle = '#5a6a5a';
        g.fillRect(px + 5, py + 6, 6, 8);
        g.fillStyle = '#7a8a7a';
        g.fillRect(px + 4, py + 5, 8, 2);
        break;
      case O.MAILBOX:
        g.fillStyle = '#2a4a8a';
        g.fillRect(px + 5, py + 5, 6, 9);
        g.fillStyle = '#4a6aaa';
        g.fillRect(px + 5, py + 5, 6, 2);
        break;
      case O.BARREL:
        g.fillStyle = h < 0.5 ? '#c04a1a' : '#4a6a3a';
        g.fillRect(px + 4, py + 3, 9, 11);
        g.fillStyle = 'rgba(0,0,0,0.3)';
        g.fillRect(px + 4, py + 6, 9, 1);
        g.fillRect(px + 4, py + 10, 9, 1);
        break;
      case O.CRATE:
        g.fillStyle = '#9a7040';
        g.fillRect(px + 2, py + 2, 12, 12);
        g.strokeStyle = '#6a4a28';
        g.lineWidth = 1;
        g.strokeRect(px + 2.5, py + 2.5, 11, 11);
        g.beginPath(); g.moveTo(px + 3, py + 3); g.lineTo(px + 13, py + 13); g.stroke();
        break;
      case O.CONE:
        g.fillStyle = '#e46a1a';
        g.beginPath(); g.moveTo(px + 8, py + 3); g.lineTo(px + 12, py + 13); g.lineTo(px + 4, py + 13); g.fill();
        g.fillStyle = '#f0f0f0';
        g.fillRect(px + 6, py + 8, 4, 2);
        break;
      case O.SIGNPOST:
        g.fillStyle = '#6a4a2a';
        g.fillRect(px + 7, py + 4, 2, 11);
        g.fillStyle = '#2a6a3a';
        g.fillRect(px + 1, py + 2, 14, 5);
        break;
    }
  };

  // ------------------------------------------------------------ people
  // look: { skin, hair, hairStyle, top, bottom, hat, hatCol, build, fem, kid, beard, shades, stripe, chain, mask, uniform }
  A.drawPerson = function (g, x, y, dir, walk, look, st) {
    st = st || {};
    const s = look.kid ? 0.72 : 1;
    const bw = (look.build === 2 ? 12 : look.build === 0 ? 8 : 10) * s;
    const X = Math.round(x), Y = Math.round(y);
    g.save();
    g.translate(X, Y);
    if (st.down) {
      // knocked down / dead: lie sideways
      g.rotate(Math.PI / 2);
      g.translate(-4, 0);
    }
    // shadow
    g.fillStyle = 'rgba(15,10,5,0.35)';
    g.beginPath(); g.ellipse(0, 1, bw * 0.6, 3 * s, 0, 0, 7); g.fill();
    const legSwing = walk ? Math.sin(walk) * 2.5 * s : 0;
    const lh = 6 * s, th = 8 * s, hh = 6 * s;
    const legTop = -lh;
    // legs
    g.fillStyle = look.bottom;
    if (dir === 1 || dir === 3) {
      g.fillRect(-2 * s + legSwing, legTop, 3 * s, lh);
      g.fillRect(-1 * s - legSwing, legTop, 3 * s, lh);
    } else {
      g.fillRect(-bw / 2 + 1, legTop + (legSwing > 0 ? -1 : 0), bw / 2 - 1, lh);
      g.fillRect(1, legTop + (legSwing < 0 ? -1 : 0), bw / 2 - 1, lh);
    }
    // shoes
    g.fillStyle = '#1a1210';
    if (dir === 1 || dir === 3) g.fillRect(-3 * s, -1.5, 6 * s, 1.5);
    else { g.fillRect(-bw / 2 + 1, -1.5, bw / 2 - 1, 1.5); g.fillRect(1, -1.5, bw / 2 - 1, 1.5); }
    // torso
    const tTop = legTop - th;
    const tw = dir === 1 || dir === 3 ? bw * 0.7 : bw;
    g.fillStyle = look.top;
    g.fillRect(-tw / 2, tTop, tw, th + 1);
    if (look.fem && !look.kid && look.dress) {
      g.fillRect(-tw / 2 - 1, legTop - 1, tw + 2, 4 * s);
    }
    if (look.stripe) {
      g.fillStyle = look.stripe;
      for (let k = -tw / 2 + 1.5; k < tw / 2; k += 2.5) g.fillRect(k, tTop + 1, 0.6, th - 1);
    }
    if (dir === 2) {
      // lapels / collar
      if (look.lapel) {
        g.fillStyle = look.lapel;
        g.beginPath(); g.moveTo(-2, tTop); g.lineTo(0, tTop + 5); g.lineTo(2, tTop); g.fill();
      }
      if (look.chain) { g.fillStyle = '#f0c040'; g.fillRect(-1.5, tTop + 1.5, 3, 1); }
    }
    // arms
    const armSwing = walk ? Math.cos(walk) * 2 * s : 0;
    g.fillStyle = look.top;
    if (dir === 1 || dir === 3) g.fillRect(-1.5 + armSwing * 0.8, tTop + 1, 3 * s, th - 1);
    else {
      g.fillRect(-tw / 2 - 2 * s, tTop + 1 + armSwing * 0.3, 2 * s, th - 1);
      g.fillRect(tw / 2, tTop + 1 - armSwing * 0.3, 2 * s, th - 1);
      g.fillStyle = look.skin;
      g.fillRect(-tw / 2 - 2 * s, tTop + th - 1 + armSwing * 0.3, 2 * s, 2);
      g.fillRect(tw / 2, tTop + th - 1 - armSwing * 0.3, 2 * s, 2);
    }
    // held weapon
    if (st.weapon && st.weapon !== 'fists') {
      g.fillStyle = st.weapon === 'bat' ? '#b08050' : st.weapon === 'knife' ? '#d0d0d0' : '#2a2a2a';
      const wl = st.weapon === 'bat' ? 8 : st.weapon === 'shotgun' || st.weapon === 'rifle' ? 9 : st.weapon === 'chopper' ? 7 : 4;
      if (dir === 1) g.fillRect(2, tTop + 4, wl, 2);
      else if (dir === 3) g.fillRect(-2 - wl, tTop + 4, wl, 2);
      else if (dir === 2) g.fillRect(tw / 2, tTop + 5, 2, wl);
      else g.fillRect(tw / 2, tTop + 1 - wl + 4, 2, wl);
    }
    // head
    const hTop = tTop - hh;
    const hw = 6 * s;
    g.fillStyle = look.mask ? '#2a2a2a' : look.skin;
    g.fillRect(-hw / 2, hTop, hw, hh);
    // hair
    if (!look.mask) {
      g.fillStyle = look.hair;
      if (look.hairStyle === 2) {
        // afro
        g.beginPath(); g.arc(0, hTop + 1, 5 * s, 0, 7); g.fill();
        g.fillStyle = look.skin;
        if (dir === 2) g.fillRect(-hw / 2 + 0.5, hTop + 2, hw - 1, hh - 2);
        else if (dir === 1) g.fillRect(0, hTop + 2, hw / 2, hh - 2);
        else if (dir === 3) g.fillRect(-hw / 2, hTop + 2, hw / 2, hh - 2);
      } else if (dir === 0) g.fillRect(-hw / 2, hTop, hw, hh - 1);
      else {
        g.fillRect(-hw / 2, hTop - 1, hw, 2.5);
        if (look.hairStyle === 1 || look.fem) {
          // long hair
          if (dir === 1) g.fillRect(-hw / 2, hTop, 2, hh + 2);
          else if (dir === 3) g.fillRect(hw / 2 - 2, hTop, 2, hh + 2);
          else { g.fillRect(-hw / 2 - 0.5, hTop, 1.5, hh + 2); g.fillRect(hw / 2 - 1, hTop, 1.5, hh + 2); }
        }
      }
      // face
      if (dir !== 0) {
        g.fillStyle = '#1a1010';
        const ex = dir === 1 ? 1 : dir === 3 ? -2 : 0;
        if (look.shades) {
          g.fillStyle = '#101010';
          if (dir === 2) g.fillRect(-2.5, hTop + 2.5, 5, 1.3);
          else g.fillRect(ex, hTop + 2.5, 2, 1.3);
        } else if (dir === 2) {
          g.fillRect(-2, hTop + 2.5, 1, 1); g.fillRect(1, hTop + 2.5, 1, 1);
        } else g.fillRect(ex + 0.5, hTop + 2.5, 1, 1);
        if (look.beard) {
          g.fillStyle = look.hair;
          if (dir === 2) g.fillRect(-2, hTop + 4, 4, 1);
          else g.fillRect(dir === 1 ? 0 : -3, hTop + 4, 3, 1);
        }
      }
    } else if (dir !== 0) {
      g.fillStyle = '#e8d0b0';
      if (dir === 2) { g.fillRect(-2.5, hTop + 2, 2, 1.5); g.fillRect(0.5, hTop + 2, 2, 1.5); }
      else g.fillRect(dir === 1 ? 0.5 : -2.5, hTop + 2, 2, 1.5);
    }
    // hat
    if (look.hat && !look.mask) {
      g.fillStyle = look.hatCol || '#2a2020';
      if (look.hat === 'fedora') {
        g.fillRect(-hw / 2 - 2, hTop + 0.5, hw + 4, 1.5); // brim
        g.fillRect(-hw / 2 + 0.5, hTop - 2.5, hw - 1, 3.2);
        g.fillStyle = '#7a2a1a';
        g.fillRect(-hw / 2 + 0.5, hTop - 0.3, hw - 1, 0.9); // band
      } else if (look.hat === 'cap') {
        g.fillRect(-hw / 2, hTop - 1.5, hw, 2.5);
        if (dir === 2) g.fillRect(-hw / 2, hTop + 0.5, hw, 1);
        else if (dir === 1) g.fillRect(hw / 2 - 1, hTop, 3, 1);
        else if (dir === 3) g.fillRect(-hw / 2 - 2, hTop, 3, 1);
      } else if (look.hat === 'cowboy') {
        g.fillRect(-hw / 2 - 3, hTop + 0.5, hw + 6, 1.5);
        g.fillRect(-hw / 2 + 0.5, hTop - 3, hw - 1, 3.6);
      } else if (look.hat === 'police') {
        g.fillStyle = '#1a2a4a';
        g.fillRect(-hw / 2 - 0.5, hTop - 2, hw + 1, 3);
        g.fillStyle = '#e4c040';
        g.fillRect(-0.5, hTop - 1.5, 1.2, 1.2);
      } else if (look.hat === 'beanie') {
        g.fillRect(-hw / 2, hTop - 2, hw, 3);
      }
    }
    g.restore();
  };

  // ------------------------------------------------------------ vehicles
  A.drawCar = function (g, v) {
    const m = v.model;
    const L = m.w, Wd = m.h;
    g.save();
    g.translate(Math.round(v.x), Math.round(v.y));
    g.rotate(v.angle);
    // shadow
    g.fillStyle = 'rgba(15,10,5,0.4)';
    g.fillRect(-L / 2 + 2, -Wd / 2 + 3, L, Wd);
    const col = v.wrecked ? '#3a3230' : v.color;
    // body
    g.fillStyle = shade(col, -30);
    g.fillRect(-L / 2, -Wd / 2, L, Wd);
    g.fillStyle = col;
    g.fillRect(-L / 2 + 1, -Wd / 2 + 1, L - 2, Wd - 2);
    // wheels peeking
    g.fillStyle = '#141414';
    g.fillRect(-L / 2 + 4, -Wd / 2 - 1, 6, 2); g.fillRect(L / 2 - 10, -Wd / 2 - 1, 6, 2);
    g.fillRect(-L / 2 + 4, Wd / 2 - 1, 6, 2); g.fillRect(L / 2 - 10, Wd / 2 - 1, 6, 2);
    if (m.bus || m.box || m.fire) {
      g.fillStyle = shade(col, 15);
      g.fillRect(-L / 2 + 2, -Wd / 2 + 2, L - 14, Wd - 4);
      g.fillStyle = '#2a3a4a';
      g.fillRect(L / 2 - 11, -Wd / 2 + 2, 5, Wd - 4); // cab glass
      if (m.bus) {
        g.fillStyle = '#a8c8d8';
        for (let k = -L / 2 + 4; k < L / 2 - 14; k += 6) { g.fillRect(k, -Wd / 2 + 1, 4, 2); g.fillRect(k, Wd / 2 - 3, 4, 2); }
      }
      if (m.fire) {
        g.fillStyle = '#d0d0d0';
        g.fillRect(-L / 2 + 4, -2, L - 18, 4); // ladder
        g.fillStyle = '#909090';
        for (let k = -L / 2 + 5; k < L / 2 - 14; k += 4) g.fillRect(k, -2, 1, 4);
      }
      if (m.box && v.variant) {
        g.fillStyle = '#f2e2c0';
        g.fillRect(-L / 2 + 6, -3, 18, 6);
      }
    } else {
      // windshield, roof, rear window
      const roofL = L * 0.42;
      g.fillStyle = '#2a3a48';
      g.fillRect(-roofL / 2 + 4, -Wd / 2 + 2, 4, Wd - 4); // front glass (towards +x)
      g.fillRect(-roofL / 2 - 3, -Wd / 2 + 2, 3, Wd - 4);
      g.fillStyle = m.vinyl ? '#f0e8d8' : shade(col, 18);
      g.fillRect(-roofL / 2, -Wd / 2 + 2, roofL - 2, Wd - 4);
      if (m.wood && !v.wrecked) {
        g.fillStyle = '#8a5a2a';
        g.fillRect(-L / 2 + 2, -Wd / 2 + 1, L - 8, 2);
        g.fillRect(-L / 2 + 2, Wd / 2 - 3, L - 8, 2);
      }
      if (m.stripes && !v.wrecked) {
        g.fillStyle = '#f0f0f0';
        g.fillRect(-L / 2 + 1, -1.5, L - 2, 1);
        g.fillRect(-L / 2 + 1, 0.5, L - 2, 1);
      }
      if (m.bed) {
        g.fillStyle = shade(col, -45);
        g.fillRect(-L / 2 + 2, -Wd / 2 + 2, 10, Wd - 4);
      }
      if (m.checker) {
        g.fillStyle = '#1a1a1a';
        for (let k = 0; k < 6; k++) g.fillRect(-L / 2 + 6 + k * 3, (k % 2) * 2 - Wd / 2 + 1, 2, 1);
        g.fillStyle = '#f0e0a0';
        g.fillRect(-2, -2, 4, 4);
      }
      if (m.mural && !v.wrecked) {
        g.fillStyle = '#e4a92a';
        g.beginPath(); g.arc(-6, -Wd / 2 + 2, 3, 0, Math.PI); g.fill();
        g.fillStyle = '#d9621e';
        g.beginPath(); g.arc(-6, Wd / 2 - 2, 3, Math.PI, 0); g.fill();
      }
      if (m.police) {
        g.fillStyle = '#f0f0f0';
        g.fillRect(-L / 2 + 1, -Wd / 2 + 1, 8, Wd - 2);
        g.fillRect(L / 2 - 8, -Wd / 2 + 1, 7, Wd - 2);
        const on = v.siren && (performance.now() / 150) % 2 < 1;
        g.fillStyle = on ? '#ff3030' : '#801818';
        g.fillRect(-3, -Wd / 2 + 2, 3, (Wd - 4) / 2);
        g.fillStyle = on ? '#3050ff' : '#182880';
        g.fillRect(-3, 0, 3, (Wd - 4) / 2);
      }
      if (m.medic) {
        g.fillStyle = '#c02020';
        g.fillRect(-6, -1, 8, 2);
        g.fillRect(-3, -4, 2, 8);
      }
    }
    // lights
    g.fillStyle = v.lights ? '#fff6c0' : '#d8d0a0';
    g.fillRect(L / 2 - 1, -Wd / 2 + 1, 1, 3);
    g.fillRect(L / 2 - 1, Wd / 2 - 4, 1, 3);
    g.fillStyle = v.braking ? '#ff3020' : '#8a1a10';
    g.fillRect(-L / 2, -Wd / 2 + 1, 1, 3);
    g.fillRect(-L / 2, Wd / 2 - 4, 1, 3);
    if (v.hp < 35 && !v.wrecked) {
      g.fillStyle = 'rgba(40,40,40,0.5)';
      g.fillRect(L / 2 - 8, -3, 5, 6);
    }
    g.restore();
  };

  // ------------------------------------------------------------ animals
  A.drawAnimal = function (g, a) {
    const d = a.def, s = d.size;
    g.save();
    g.translate(Math.round(a.x), Math.round(a.y));
    if (d.bird && a.flying) {
      g.translate(0, -10 - Math.sin(a.t * 3) * 2);
      g.fillStyle = 'rgba(0,0,0,0.15)';
      g.fillRect(-2, 12, 4, 2);
      g.fillStyle = d.col;
      const flap = Math.sin(a.t * 18) * 3;
      g.fillRect(-1, -1, 3, 3);
      g.fillRect(-5, -1 - flap, 4, 1.5);
      g.fillRect(2, -1 - flap, 4, 1.5);
      g.restore();
      return;
    }
    const face = Math.cos(a.angle) >= 0 ? 1 : -1;
    g.scale(face, 1);
    if (a.dead) g.rotate(Math.PI / 2 * 0.9);
    g.fillStyle = 'rgba(15,10,5,0.3)';
    g.beginPath(); g.ellipse(0, 1, s * 0.8, s * 0.3, 0, 0, 7); g.fill();
    const leg = a.moving && !a.dead ? Math.sin(a.t * 14) * 1.5 : 0;
    g.fillStyle = shade(d.col, -25);
    if (d.bird) {
      g.fillStyle = d.col;
      g.fillRect(-2, -4, 4, 3);
      g.fillRect(1, -6, 2, 2);
      g.fillStyle = '#e4a92a';
      g.fillRect(3, -5, 1.5, 1);
      g.restore();
      return;
    }
    if (a.def === D.animals.snake) {
      g.fillStyle = d.col;
      for (let k = 0; k < 5; k++) g.fillRect(-6 + k * 2.5, -2 + Math.sin(a.t * 6 + k) * 1.5, 3, 2);
      g.restore();
      return;
    }
    if (a.def === D.animals.gator) {
      g.fillStyle = d.col;
      g.fillRect(-s, -4, s * 2, 5);
      g.fillRect(s - 2, -3, 6, 3);
      g.fillRect(-s - 5, -3, 6, 2);
      g.fillStyle = '#e8e0a0';
      g.fillRect(s + 2, -3, 1, 1);
      g.restore();
      return;
    }
    // quadruped
    const bl = s * 1.3, bh = s * 0.55;
    g.fillRect(-bl / 2 + 1 + leg, -3, 2, 4);
    g.fillRect(bl / 2 - 3 - leg, -3, 2, 4);
    g.fillStyle = d.col;
    g.fillRect(-bl / 2, -3 - bh, bl, bh);
    // head
    g.fillRect(bl / 2 - 1, -3 - bh - s * 0.35, s * 0.5, s * 0.45);
    if (a.def === D.animals.deer && a.buck) {
      g.fillStyle = '#d8c8a0';
      g.fillRect(bl / 2, -3 - bh - s * 0.35 - 4, 1, 4);
      g.fillRect(bl / 2 + 2, -3 - bh - s * 0.35 - 3, 1, 3);
    }
    g.fillStyle = shade(d.col, 20);
    g.fillRect(-bl / 2, -3 - bh, bl, 1);
    // tail
    g.fillStyle = d.col;
    g.fillRect(-bl / 2 - 2, -3 - bh + 1, 2, 1.5);
    if (a.def === D.animals.rabbit) {
      g.fillStyle = '#f0e8e0';
      g.fillRect(-bl / 2 - 1, -3 - bh, 2, 2);
      g.fillStyle = d.col;
      g.fillRect(bl / 2, -3 - bh - s * 0.35 - 3, 1, 3);
    }
    if (a.def === D.animals.cattle) {
      g.fillStyle = '#f0e8e0';
      g.fillRect(-2, -3 - bh + 1, 4, 3);
    }
    g.restore();
  };

  // ------------------------------------------------------------ minimap image
  A.buildMiniMap = function (world) {
    const cv = document.createElement('canvas');
    cv.width = world.W;
    cv.height = world.H;
    const g = cv.getContext('2d');
    const img = g.createImageData(world.W, world.H);
    const rgb = {};
    for (const k in base) {
      const n = parseInt(base[k].slice(1), 16);
      rgb[k] = [(n >> 16) & 255, (n >> 8) & 255, n & 255];
    }
    rgb[T.BLDG] = [58, 44, 36];
    rgb[T.ROAD] = [222, 206, 170];
    rgb[T.HWY] = [240, 200, 110];
    rgb[T.BRIDGE] = [240, 200, 110];
    rgb[T.WALK] = [150, 140, 120];
    for (let i = 0; i < world.tile.length; i++) {
      const c = rgb[world.tile[i]] || [255, 0, 255];
      const o = world.obj[i];
      const dim = o === O.TREE || o === O.PINE ? 0.8 : 1;
      img.data[i * 4] = c[0] * dim;
      img.data[i * 4 + 1] = c[1] * dim;
      img.data[i * 4 + 2] = c[2] * dim;
      img.data[i * 4 + 3] = 255;
    }
    g.putImageData(img, 0, 0);
    return cv;
  };
})();
