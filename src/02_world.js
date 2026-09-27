// RHAPSODY — procedural world: coastline, biomes, rivers, five cities on street grids,
// hamlets, highways with lane-flow data for traffic, farms, cabins and street furniture.
'use strict';
(function () {
  const D = R.data, T = D.T, O = D.O, F = R.FLOW;
  const P = 16; // city block pitch: 14 tiles of block + 2 tiles of road

  function World(seed) {
    this.seed = seed;
    this.W = 640;
    this.H = 640;
    const N = this.W * this.H;
    this.tile = new Uint8Array(N);
    this.obj = new Uint8Array(N);
    this.flow = new Uint8Array(N);
    this.bid = new Uint16Array(N); // building id + 1
    this.zone = new Uint8Array(N); // city index + 1 (0 = county)
    this.dirty = new Set(); // chunk keys needing re-render
    this.buildings = [null];
    this.lots = [];
    this.inters = [];
    this.interAt = new Map();
    this.cities = [];
    this.hamlets = [];
    this.spots = []; // outdoor hangout spots for named NPCs
    this.phones = [];
    this.gen();
  }
  const W = World.prototype;
  W.idx = function (x, y) { return y * this.W + x; };
  W.inb = function (x, y) { return x >= 0 && y >= 0 && x < this.W && y < this.H; };
  W.t = function (x, y) { return this.inb(x, y) ? this.tile[y * this.W + x] : T.DEEP; };
  W.o = function (x, y) { return this.inb(x, y) ? this.obj[y * this.W + x] : 0; };
  W.setT = function (x, y, t) {
    if (!this.inb(x, y)) return;
    this.tile[y * this.W + x] = t;
    this.markDirty(x, y);
  };
  W.setO = function (x, y, o) {
    if (!this.inb(x, y)) return;
    this.obj[y * this.W + x] = o;
    this.markDirty(x, y);
  };
  W.markDirty = function (x, y) {
    if (this.genDone) this.dirty.add(((x >> 5) << 16) | (y >> 5));
  };
  // Pedestrian collision
  W.solidPed = function (x, y) {
    if (!this.inb(x, y)) return true;
    const i = y * this.W + x;
    const t = this.tile[i];
    return D.solidTile[t] === 1 || D.solidObj[this.obj[i]] === 1 || t === T.DEEP;
  };
  // Vehicle collision
  W.solidCar = function (x, y) {
    if (!this.inb(x, y)) return true;
    const i = y * this.W + x;
    const t = this.tile[i];
    return D.solidTile[t] === 1 || D.solidObj[this.obj[i]] === 1 || D.waterTile[t] === 1;
  };
  W.isWater = function (x, y) { return D.waterTile[this.t(x, y)] === 1; };
  W.cityAt = function (tx, ty) {
    const z = this.inb(tx, ty) ? this.zone[ty * this.W + tx] : 0;
    return z ? this.cities[z - 1] : null;
  };
  W.buildingAt = function (tx, ty) {
    const b = this.inb(tx, ty) ? this.bid[ty * this.W + tx] : 0;
    return b ? this.buildings[b] : null;
  };
  W.biomeAt = function (tx, ty) {
    const t = this.t(tx, ty);
    if (this.cityAt(tx, ty)) return 'city';
    switch (t) {
      case T.FOREST: return 'forest';
      case T.DESERT: return 'desert';
      case T.MARSH: return 'marsh';
      case T.SNOW: return 'snow';
      case T.FIELD: return 'field';
      case T.SAND: return 'coast';
      case T.WATER: case T.DEEP: return 'water';
      default: return 'grass';
    }
  };

  // ------------------------------------------------------------------
  W.gen = function () {
    const rnd = (this.rnd = R.mulberry(this.seed));
    this.planCities(rnd);
    this.genTerrain(rnd);
    this.genRiver(rnd);
    for (const c of this.cities) this.genCity(c, rnd);
    this.genHighways(rnd);
    this.genCountryside(rnd);
    this.finishRoads();
    this.genFurniture(rnd);
    this.genDone = true;
  };

  W.planCities = function (rnd) {
    const sizes = { port: [8, 8], avalon: [10, 9], dust: [6, 6], pine: [6, 5], bayou: [6, 6] };
    D.cities.forEach((def, i) => {
      const [nbx, nby] = sizes[def.id];
      const cx = Math.round(def.fx * this.W), cy = Math.round(def.fy * this.H);
      const x0 = cx - Math.floor((nbx * P) / 2), y0 = cy - Math.floor((nby * P) / 2);
      this.cities.push({
        idx: i, id: def.id, name: def.name, def, x0, y0, nbx, nby,
        x1: x0 + nbx * P + 1, y1: y0 + nby * P + 1,
        rowY: y0 + Math.floor(nby / 2) * P, colX: x0 + Math.floor(nbx / 2) * P,
        cx, cy, buildings: [], lots: [], hamlet: false,
        prosperity: 55, fear: 0, heat: 0, growth: 0, // live stats
      });
    });
    D.hamlets.forEach((h, i) => {
      const nb = 2;
      const cx = Math.round(h.fx * this.W), cy = Math.round(h.fy * this.H);
      const x0 = cx - P, y0 = cy - P;
      this.hamlets.push({
        idx: -1, id: 'ham' + i, name: h.name, def: { family: null, color: '#a08060', biome: 'hamlet' }, x0, y0, nbx: nb, nby: nb,
        x1: x0 + nb * P + 1, y1: y0 + nb * P + 1, rowY: y0 + P, colX: x0 + P, cx, cy, buildings: [], lots: [], hamlet: true,
        prosperity: 40, fear: 0, heat: 0, growth: 0,
      });
    });
  };

  W.inCityRect = function (x, y, m) {
    for (const c of this.cities.concat(this.hamlets))
      if (x >= c.x0 - m && x <= c.x1 + m && y >= c.y0 - m && y <= c.y1 + m) return c;
    return null;
  };

  W.genTerrain = function (rnd) {
    const nE = R.makeNoise(this.seed + 11), nM = R.makeNoise(this.seed + 23), nC = R.makeNoise(this.seed + 37);
    const w = this.W, h = this.H;
    const port = this.cities[0];
    for (let y = 0; y < h; y++) {
      const coastX = w * (0.075 + 0.045 * nC.fbm(y / 70, 3.3, 3)) + (y > h * 0.75 ? (y - h * 0.75) * 0.25 : 0);
      for (let x = 0; x < w; x++) {
        const i = y * w + x;
        const fx = x / w, fy = y / h;
        let e = nE.fbm(x / 95, y / 95, 5);
        e += Math.pow(Math.max(0, 0.32 - fy), 1.4) * 1.7; // northern range
        e += Math.max(0, fx - 0.88) * 2.2; // eastern ridge
        let m = nM.fbm(x / 80, y / 80, 4);
        m += (0.5 - fx) * 0.3;
        // coast: ocean on the west, bending south
        let coast = coastX;
        if (y > port.y0 - 10 && y < port.y1 + 10) coast = Math.min(coast, port.x0 + P + 2 - 6); // harbor inlet
        const sea = x - coast;
        const southSea = fy > 0.955 + 0.02 * nC(x / 40, 9) && fx < 0.5;
        let t;
        if (sea < 0 || southSea) t = sea < -5 || southSea ? T.DEEP : T.WATER;
        else if (sea < 3) t = T.SAND;
        else {
          const desert = (fx - 0.55) * 2.2 + (fy - 0.5) * 2.0 - m * 0.8;
          const marshC = 1 - R.dist(fx, fy, 0.25, 0.83) / 0.2 + (nM(x / 25, y / 25) - 0.5) * 0.6;
          if (e > 0.86) t = T.ROCK;
          else if (fy < 0.17 && e > 0.7) t = T.SNOW;
          else if (marshC > 0.35) t = nM(x / 9, y / 9) > 0.72 ? T.WATER : T.MARSH;
          else if (desert > 0.7) t = T.DESERT;
          else if (m > 0.54 || (fy < 0.3 && m > 0.44)) t = T.FOREST;
          else if (desert > 0.45 && nM(x / 12, y / 12) > 0.5) t = T.DIRT;
          else t = T.GRASS;
        }
        this.tile[i] = t;
        // scatter
        const r = R.hash2(x, y, this.seed + 5);
        let o = 0;
        if (t === T.FOREST) o = r < 0.36 ? (fy < 0.35 || e > 0.6 ? O.PINE : r < 0.2 ? O.TREE : O.PINE) : r < 0.42 ? O.BUSH : 0;
        else if (t === T.GRASS) o = r < 0.018 ? O.TREE : r < 0.03 ? O.BUSH : r < 0.034 ? O.BOULDER : r < 0.04 ? O.FLOWERS : 0;
        else if (t === T.DESERT) o = r < 0.012 ? O.CACTUS : r < 0.018 ? O.BOULDER : r < 0.021 ? O.DEADTREE : 0;
        else if (t === T.MARSH) o = r < 0.12 ? O.REED : r < 0.15 ? O.DEADTREE : r < 0.18 ? O.TREE : 0;
        else if (t === T.SNOW) o = r < 0.14 ? O.PINE : r < 0.16 ? O.BOULDER : 0;
        else if (t === T.SAND) o = r < 0.01 && fy > 0.6 ? O.PALM : 0;
        else if (t === T.DIRT) o = r < 0.02 ? O.BOULDER : r < 0.03 ? O.BUSH : 0;
        this.obj[i] = o;
      }
    }
    // clear land under settlements
    for (const c of this.cities.concat(this.hamlets)) {
      for (let y = c.y0 - 3; y <= c.y1 + 3; y++)
        for (let x = c.x0 - 3; x <= c.x1 + 3; x++) {
          if (!this.inb(x, y)) continue;
          const i = y * w + x;
          if (c.id === 'port' && x < c.x0 + P + 2) continue; // docks handled in genCity
          const t = this.tile[i];
          this.tile[i] = c.def.biome === 'desert' ? T.DESERT : t === T.SNOW ? T.SNOW : T.GRASS;
          if (c.def.biome === 'marsh' && t === T.MARSH) this.tile[i] = T.GRASS;
          this.obj[i] = 0;
          this.zone[i] = c.hamlet ? 0 : c.idx + 1;
        }
      // jurisdiction margin
      if (!c.hamlet)
        for (let y = c.y0 - 18; y <= c.y1 + 18; y++)
          for (let x = c.x0 - 18; x <= c.x1 + 18; x++) if (this.inb(x, y)) this.zone[y * w + x] = c.idx + 1;
    }
  };

  W.genRiver = function (rnd) {
    const pts = [[0.71, -0.02], [0.73, 0.2], [0.7, 0.4], [0.705, 0.62], [0.6, 0.86], [0.55, 1.03]];
    const nR = R.makeNoise(this.seed + 99);
    for (let s = 0; s < pts.length - 1; s++) {
      const [ax, ay] = pts[s], [bx, by] = pts[s + 1];
      const steps = Math.ceil(R.dist(ax * this.W, ay * this.H, bx * this.W, by * this.H));
      for (let k = 0; k <= steps; k++) {
        const t = k / steps;
        let x = R.lerp(ax, bx, t) * this.W, y = R.lerp(ay, by, t) * this.H;
        x += (nR(y / 30, 1) - 0.5) * 22;
        const width = 3 + nR(x / 20, y / 20) * 3;
        for (let dy = -width; dy <= width; dy++)
          for (let dx = -width; dx <= width; dx++) {
            const px = Math.round(x + dx), py = Math.round(y + dy);
            if (!this.inb(px, py) || this.inCityRect(px, py, 2)) continue;
            const d = Math.hypot(dx, dy);
            const i = py * this.W + px;
            if (d < width - 1.2) {
              this.tile[i] = d < width - 2.5 ? T.DEEP : T.WATER;
              this.obj[i] = 0;
            } else if (d < width + 0.5 && !D.waterTile[this.tile[i]] && this.tile[i] !== T.ROCK) {
              this.tile[i] = this.tile[i] === T.DESERT ? T.SAND : this.tile[i];
              if (this.obj[i] === O.CACTUS) this.obj[i] = 0;
              if (R.hash2(px, py, 3) < 0.25) this.obj[i] = O.REED;
            }
          }
      }
    }
    // Pinecrest lake
    const lx = 0.43 * this.W, ly = 0.14 * this.H;
    for (let y = -16; y <= 16; y++)
      for (let x = -24; x <= 24; x++) {
        const d = Math.hypot(x / 24, y / 16) + (nR((lx + x) / 8, (ly + y) / 8) - 0.5) * 0.25;
        const px = Math.round(lx + x), py = Math.round(ly + y);
        if (!this.inb(px, py) || this.inCityRect(px, py, 2)) continue;
        const i = py * this.W + px;
        if (d < 0.75) { this.tile[i] = d < 0.5 ? T.DEEP : T.WATER; this.obj[i] = 0; }
        else if (d < 0.85) { this.tile[i] = T.SAND; this.obj[i] = 0; }
      }
  };

  // Lay a two-lane road. Horizontal: row y = westbound, y+1 = eastbound.
  // Vertical: col x = southbound, x+1 = northbound. (drive on the right)
  W.layH = function (xa, xb, y, type) {
    const x0 = Math.min(xa, xb), x1 = Math.max(xa, xb);
    for (let x = x0; x <= x1; x++) {
      this.paveRoad(x, y, F.W, type);
      this.paveRoad(x, y + 1, F.E, type);
    }
  };
  W.layV = function (x, ya, yb, type) {
    const y0 = Math.min(ya, yb), y1 = Math.max(ya, yb);
    for (let y = y0; y <= y1; y++) {
      this.paveRoad(x, y, F.S, type);
      this.paveRoad(x + 1, y, F.N, type);
    }
  };
  W.paveRoad = function (x, y, flow, type) {
    if (!this.inb(x, y)) return;
    const i = y * this.W + x;
    const t = this.tile[i];
    if (t === T.BLDG) return;
    if (D.waterTile[t] || t === T.BRIDGE) this.tile[i] = T.BRIDGE;
    else if (t === T.ROAD) {} // keep city pavement
    else this.tile[i] = type;
    this.obj[i] = 0;
    this.flow[i] |= flow;
  };

  W.genCity = function (c, rnd) {
    const def = c.def;
    const roadT = T.ROAD;
    // grid roads
    for (let i = 0; i <= c.nbx; i++) this.layV(c.x0 + i * P, c.y0, c.y0 + c.nby * P + 1, roadT);
    for (let j = 0; j <= c.nby; j++) this.layH(c.x0, c.x0 + c.nbx * P + 1, c.y0 + j * P, roadT);
    // blocks
    const rows = [];
    const cxB = (c.nbx - 1) / 2, cyB = (c.nby - 1) / 2;
    for (let i = 0; i < c.nbx; i++)
      for (let j = 0; j < c.nby; j++) {
        const bx = c.x0 + i * P + 2, by = c.y0 + j * P + 2;
        const d = Math.hypot((i - cxB) / Math.max(1, cxB + 0.5), (j - cyB) / Math.max(1, cyB + 0.5));
        const zone = c.hamlet ? 'hamlet' : d < 0.38 ? 'core' : d < 0.78 ? 'mid' : 'edge';
        // port: westmost column is the harbor
        if (c.id === 'port' && i === 0) {
          this.genDocks(c, bx, by, rnd);
          continue;
        }
        // sidewalk ring
        for (let y = by; y < by + 14; y++)
          for (let x = bx; x < bx + 14; x++) {
            const edge = x === bx || y === by || x === bx + 13 || y === by + 13;
            this.tile[y * this.W + x] = edge ? T.WALK : T.LOT;
            this.obj[y * this.W + x] = 0;
          }
        // parks
        const parkChance = zone === 'core' ? 0.06 : zone === 'mid' ? 0.1 : 0.06;
        if (!c.hamlet && rnd() < parkChance) {
          this.genPark(c, bx, by, rnd);
          continue;
        }
        rows.push({ c, x: bx + 1, y: by + 1, face: 'N', cur: 0, zone, d });
        rows.push({ c, x: bx + 1, y: by + 7, face: 'S', cur: 0, zone, d });
      }
    // required buildings first, closest rows to the centre
    const req = c.hamlet ? ['gas', 'diner', 'bar', 'general', 'motel'] : D.cityRequired.slice();
    if (c.id === 'avalon') req.push('casino', 'club', 'bank', 'police', 'arcade', 'social');
    if (c.id === 'port') req.push('warehouse', 'bar');
    if (c.id === 'pine') req.push('factory', 'butcher', 'cabin');
    if (c.id === 'dust') req.push('motel', 'gas');
    if (c.id === 'bayou') req.push('bar', 'butcher');
    const sorted = rows.slice().sort((a, b) => a.d - b.d + (rnd() - 0.5) * 0.35);
    for (const type of req) {
      const bt = D.btypes[type];
      const w = rnd.int(bt.w[0], bt.w[1]);
      const row = sorted.find((r) => 12 - r.cur >= w && (type !== 'house' || r.zone !== 'core'));
      if (row) this.placeBuilding(row, type, w, rnd);
    }
    // fill
    for (const row of rows) {
      let guard = 0;
      while (row.cur < 12 && guard++ < 10) {
        const left = 12 - row.cur;
        const mix = c.hamlet ? [['house', 4], ['barn', 1], ['general', 0.3], ['bar', 0.3]] : D.cityMix[row.zone];
        let type = rnd.weighted(mix);
        if (c.id === 'dust' && type === 'apartment' && rnd() < 0.5) type = 'house';
        if (c.id === 'pine' && type === 'house' && rnd() < 0.3) type = 'cabin';
        const bt = D.btypes[type];
        const vacant = row.zone === 'edge' ? 0.3 : row.zone === 'mid' ? 0.08 : 0.03;
        if (left < bt.w[0] || rnd() < vacant) {
          const w = left < 3 ? left : Math.min(left, rnd.int(4, 6));
          if (w >= 3 && rnd() < 0.25 && row.zone !== 'edge') this.placeParking(row, w);
          else this.addLot(row, w);
          continue;
        }
        const w = Math.min(left, rnd.int(bt.w[0], bt.w[1]));
        this.placeBuilding(row, type, w, rnd);
      }
    }
    // hangout spots: plaza corners near core
    for (let k = 0; k < c.nbx * c.nby * 0.6; k++) {
      const i = rnd.int(0, c.nbx - 1), j = rnd.int(0, c.nby - 1);
      const bx = c.x0 + i * P + 2, by = c.y0 + j * P + 2;
      const corner = rnd.int(0, 3);
      const x = corner & 1 ? bx + 13 : bx, y = corner & 2 ? by + 13 : by;
      if (this.t(x, y) === T.WALK) this.spots.push({ x, y, city: c, kind: 'corner' });
    }
  };

  W.addLot = function (row, w) {
    const x = row.x + row.cur;
    row.cur += w;
    if (w < 3) return;
    const lot = { x, y: row.y, w, h: 6, face: row.face, city: row.c, zone: row.zone, used: false };
    this.lots.push(lot);
    row.c.lots.push(lot);
    for (let yy = row.y; yy < row.y + 6; yy++)
      for (let xx = x; xx < x + w; xx++) {
        this.tile[yy * this.W + xx] = T.LOT;
        if (R.hash2(xx, yy, 77) < 0.08) this.obj[yy * this.W + xx] = O.BUSH;
      }
  };
  W.placeParking = function (row, w) {
    const x = row.x + row.cur;
    row.cur += w;
    for (let yy = row.y; yy < row.y + 6; yy++)
      for (let xx = x; xx < x + w; xx++) this.tile[yy * this.W + xx] = T.PARKING;
  };

  W.placeBuilding = function (row, type, w, rnd, lot) {
    const bt = D.btypes[type];
    const h = Math.min(6, rnd.int(bt.h[0], bt.h[1]));
    const x = lot ? lot.x : row.x + row.cur;
    const face = lot ? lot.face : row.face;
    const rowY = lot ? lot.y : row.y;
    const y = face === 'N' ? rowY : rowY + 6 - h;
    if (row) row.cur += w + (type === 'house' || type === 'cabin' ? (row.cur + w < 11 ? 1 : 0) : 0);
    const c = lot ? lot.city : row.c;
    return this.addBuilding(c, type, x, y, w, h, face, rnd);
  };

  W.addBuilding = function (c, type, x, y, w, h, face, rnd) {
    const bt = D.btypes[type];
    const id = this.buildings.length;
    const doorX = x + Math.floor(w / 2);
    const doorY = face === 'N' ? y : face === 'S' ? y + h - 1 : y + Math.floor(h / 2);
    const out = face === 'N' ? [doorX, y - 1] : face === 'S' ? [doorX, y + h] : face === 'E' ? [x + w, doorY] : [x - 1, doorY];
    const b = {
      id, type, x, y, w, h, face, city: c, cityId: c.id,
      door: { x: face === 'E' ? x + w - 1 : face === 'W' ? x : doorX, y: doorY },
      out: { x: out[0], y: out[1] },
      roof: rnd.pick(bt.roof), wall: rnd.pick(bt.wall),
      name: this.nameBuilding(c, type, rnd),
      residents: [], workers: [], owner: null, // person ids
      hp: 100, burning: 0, destroyed: false,
      cash: bt.rob ? rnd.int(40, 160) : 0, robbedDay: -9, burgledDay: -9, racket: 0, playerOwned: false,
      floors: type === 'office' || type === 'apartment' || type === 'hotel' ? rnd.int(2, 5) : 1,
      seedArt: rnd.int(0, 99999),
    };
    this.buildings.push(b);
    c.buildings.push(b);
    for (let yy = y; yy < y + h; yy++)
      for (let xx = x; xx < x + w; xx++) {
        const i = yy * this.W + xx;
        this.tile[i] = T.BLDG;
        this.obj[i] = 0;
        this.bid[i] = id;
      }
    // yard trees behind houses
    if (type === 'house' || type === 'cabin') {
      const yardY = face === 'N' ? y + h : y - 1;
      for (let xx = x; xx < x + w; xx++)
        if (this.t(xx, yardY) === T.LOT && R.hash2(xx, yardY, 5) < 0.3) this.obj[yardY * this.W + xx] = rnd() < 0.5 ? O.TREE : O.BUSH;
    }
    if (this.genDone) for (let yy = y; yy < y + h; yy++) for (let xx = x; xx < x + w; xx++) this.markDirty(xx, yy);
    return b;
  };

  W.nameBuilding = function (c, type, rnd) {
    const pats = D.shopNames[type] || ['{L}'];
    const lasts = D.lastAll[c.id] || D.lastAll.avalon;
    return rnd
      .pick(pats)
      .replace('{L}', rnd.pick(lasts))
      .replace('{F}', rnd.pick(rnd() < 0.5 ? D.firstM : D.firstF))
      .replace('{C}', c.name.split(' ').pop())
      .replace('{Fam}', c.def.family || 'Kessler')
      .replace('{N}', String(rnd.int(3, 19)));
  };

  W.genPark = function (c, bx, by, rnd) {
    for (let y = by; y < by + 14; y++)
      for (let x = bx; x < bx + 14; x++) {
        const edge = x === bx || y === by || x === bx + 13 || y === by + 13;
        const i = y * this.W + x;
        const cross = x === bx + 6 || x === bx + 7 || y === by + 6 || y === by + 7;
        this.tile[i] = edge ? T.WALK : cross ? T.PLAZA : T.PARK;
        const r = R.hash2(x, y, 41);
        this.obj[i] = !edge && !cross ? (r < 0.22 ? (c.def.biome === 'desert' ? O.PALM : O.TREE) : r < 0.3 ? O.FLOWERS : r < 0.35 ? O.BUSH : 0) : 0;
        if (cross && !edge && (x === bx + 5 || x === bx + 8 || y === by + 5 || y === by + 8) && r < 0.3) this.obj[i] = O.BENCH;
      }
    this.spots.push({ x: bx + 6, y: by + 6, city: c, kind: 'park' });
    this.spots.push({ x: bx + 7, y: by + 3, city: c, kind: 'park' });
    this.spots.push({ x: bx + 3, y: by + 7, city: c, kind: 'park' });
  };

  W.genDocks = function (c, bx, by, rnd) {
    // Planks over water with a warehouse or two, west side of Port Hollow.
    for (let y = by - 2; y < by + 14; y++)
      for (let x = bx - 30; x < bx + 14; x++) {
        if (!this.inb(x, y)) continue;
        const i = y * this.W + x;
        if (x >= bx) {
          this.tile[i] = x === bx + 13 || y === by + 13 ? T.WALK : T.DOCK;
          this.obj[i] = 0;
          this.zone[i] = c.idx + 1;
        } else if (!D.waterTile[this.tile[i]] && x < bx - 1) {
          this.tile[i] = T.WATER;
          this.obj[i] = 0;
        } else if (x >= bx - 1) {
          this.tile[i] = T.WATER;
          this.obj[i] = 0;
        }
      }
    // piers
    for (let p = 0; p < 3; p++) {
      const py = by + 1 + p * 5;
      for (let x = bx - 12; x < bx; x++) {
        this.tile[py * this.W + x] = T.DOCK;
        this.tile[(py + 1) * this.W + x] = T.DOCK;
        if (x === bx - 12 || x === bx - 6) this.obj[py * this.W + x] = O.CRATE;
      }
      this.spots.push({ x: bx - 8, y: py + 1, city: c, kind: 'pier' });
    }
    const wy = by + 3;
    const b = this.addBuilding(c, 'warehouse', bx + 5, wy, 8, 6, 'E', rnd);
    b.out = { x: bx + 13, y: b.door.y };
    for (let k = 0; k < 6; k++) {
      const x = bx + rnd.int(1, 4), y = by + rnd.int(1, 12);
      if (this.t(x, y) === T.DOCK) this.obj[y * this.W + x] = rnd() < 0.6 ? O.CRATE : O.BARREL;
    }
  };

  // Highways: horizontal leg on A's main row, vertical leg on B's main column.
  W.genHighways = function (rnd) {
    const byId = {};
    for (const c of this.cities) byId[c.id] = c;
    this.hamlets.forEach((h, i) => (byId['h' + i] = h));
    const edges = [
      ['port', 'h0'], ['h0', 'pine'], ['h0', 'avalon'], ['port', 'avalon'], ['avalon', 'h1'], ['h1', 'dust'],
      ['pine', 'h2'], ['h2', 'h1'], ['avalon', 'h3'], ['h3', 'bayou'], ['bayou', 'port'], ['h3', 'dust'],
    ];
    this.highways = [];
    const all = this.cities.concat(this.hamlets);
    const inRect = (x, y) => all.find((c) => x >= c.x0 - 1 && x <= c.x1 + 1 && y >= c.y0 - 1 && y <= c.y1 + 1);
    const onRow = (c, y) => y >= c.y0 && (y - c.y0) % P === 0;
    const onCol = (c, x) => x >= c.x0 && (x - c.x0) % P === 0;
    const rowsOf = (c) => Array.from({ length: c.nby + 1 }, (_, j) => c.y0 + j * P);
    const colsOf = (c) => Array.from({ length: c.nbx + 1 }, (_, i) => c.x0 + i * P);
    const legOk = (horiz, fixed, a0, a1) => {
      const lo = Math.min(a0, a1), hi = Math.max(a0, a1);
      for (let v = lo; v <= hi; v++)
        for (let o = 0; o < 2; o++) {
          const x = horiz ? v : fixed + o, y = horiz ? fixed + o : v;
          const c = inRect(x, y);
          if (c && !(horiz ? onRow(c, fixed) : onCol(c, fixed))) return false;
          if (this.t(x, y) === T.ROCK && R.hash2(x, y, 1) < 0.02) {} // tunnels are fine
        }
      return true;
    };
    for (const [a, b] of edges) {
      const A = byId[a], B = byId[b];
      let done = false;
      // Option 1: horizontal out of A on one of its rows, vertical into B on one of its cols
      const rA = rowsOf(A).sort((p, q) => Math.abs(p - B.cy) - Math.abs(q - B.cy));
      const cB = colsOf(B).sort((p, q) => Math.abs(p - A.cx) - Math.abs(q - A.cx));
      const cA = colsOf(A).sort((p, q) => Math.abs(p - B.cx) - Math.abs(q - B.cx));
      const rB = rowsOf(B).sort((p, q) => Math.abs(p - A.cy) - Math.abs(q - A.cy));
      for (const row of rA) {
        for (const col of cB) {
          const sx = A.colX;
          if (legOk(true, row, sx, col + 1) && legOk(false, col, row, B.rowY + 1)) {
            this.layH(sx, col + 1, row, T.HWY);
            this.layV(col, row, B.rowY + 1, T.HWY);
            this.highways.push({ a: A, b: B });
            done = true;
            break;
          }
        }
        if (done) break;
      }
      if (done) continue;
      // Option 2: vertical out of A, horizontal into B
      for (const col of cA) {
        for (const row of rB) {
          if (legOk(false, col, A.rowY, row + 1) && legOk(true, row, col, B.colX + 1)) {
            this.layV(col, A.rowY, row + 1, T.HWY);
            this.layH(col, B.colX + 1, row, T.HWY);
            this.highways.push({ a: A, b: B });
            done = true;
            break;
          }
        }
        if (done) break;
      }
      if (!done) console.warn('highway skipped', a, b);
    }
    // Hamlet grids are generated after highways cross them
    for (const h of this.hamlets) this.genCity(h, rnd);
  };

  W.genCountryside = function (rnd) {
    // Farms and cabins facing highways
    let farms = 0, cabins = 0;
    for (let tries = 0; tries < 900 && (farms < 22 || cabins < 20); tries++) {
      const x = rnd.int(10, this.W - 20), y = rnd.int(10, this.H - 20);
      const t = this.t(x, y);
      if (t !== T.HWY) continue;
      if (this.inCityRect(x, y, 14)) continue;
      const fl = this.flow[y * this.W + x];
      const horiz = fl & (F.E | F.W);
      // pick side
      const side = rnd() < 0.5 ? -1 : 1;
      const biome = this.biomeAt(x + (horiz ? 0 : side * 6), y + (horiz ? side * 6 : 0));
      const type = biome === 'forest' || biome === 'snow' ? 'cabin' : biome === 'grass' || biome === 'field' ? 'barn' : rnd() < 0.3 ? 'cabin' : null;
      if (!type || (type === 'barn' && farms >= 22) || (type === 'cabin' && cabins >= 20)) continue;
      const bt = D.btypes[type];
      const w = bt.w[1], h = bt.h[1];
      let bx, by, face;
      if (horiz) {
        // road rows are y..y+1 for this highway segment; find its top row
        const top = this.flow[(y - 1) * this.W + x] & (F.E | F.W) ? y - 1 : y;
        bx = x - Math.floor(w / 2);
        if (side < 0) { by = top - 2 - h; face = 'S'; } else { by = top + 4; face = 'N'; }
      } else {
        const left = this.flow[y * this.W + x - 1] & (F.N | F.S) ? x - 1 : x;
        by = y - Math.floor(h / 2);
        if (side < 0) { bx = left - 2 - w; face = 'E'; } else { bx = left + 4; face = 'W'; }
      }
      if (!this.areaFree(bx - 3, by - 3, w + 6, h + 6)) continue;
      const b = this.addBuilding(this.countyCity(), type, bx, by, w, h, face, rnd);
      b.rural = true;
      // path from door to road
      let px = b.out.x, py = b.out.y;
      for (let k = 0; k < 4; k++) {
        if (!this.inb(px, py) || D.roadTile[this.t(px, py)]) break;
        this.tile[py * this.W + px] = T.DIRT;
        this.obj[py * this.W + px] = 0;
        if (face === 'N') py--; else if (face === 'S') py++; else if (face === 'E') px++; else px--;
      }
      // clear yard, fields for farms
      for (let yy = by - 3; yy < by + h + 3; yy++)
        for (let xx = bx - 3; xx < bx + w + 3; xx++) {
          if (this.bid[yy * this.W + xx]) continue;
          const i = yy * this.W + xx;
          if (D.roadTile[this.tile[i]]) continue;
          this.obj[i] = 0;
          if (this.tile[i] !== T.DIRT) this.tile[i] = type === 'barn' ? T.GRASS : this.tile[i];
        }
      if (type === 'barn') {
        const fx0 = face === 'E' || face === 'W' ? bx + (face === 'E' ? -16 : w + 3) : bx - 6;
        const fy0 = face === 'N' ? by + h + 2 : face === 'S' ? by - 12 : by - 4;
        for (let yy = fy0; yy < fy0 + 10; yy++)
          for (let xx = fx0; xx < fx0 + 14; xx++) {
            if (!this.inb(xx, yy)) continue;
            const i = yy * this.W + xx;
            if (this.tile[i] === T.GRASS || this.tile[i] === T.DIRT || this.tile[i] === T.FOREST) {
              this.tile[i] = T.FIELD;
              this.obj[i] = xx === fx0 || yy === fy0 || xx === fx0 + 13 || yy === fy0 + 9 ? O.FENCE : 0;
            }
          }
        farms++;
      } else cabins++;
      this.spots.push({ x: b.out.x, y: b.out.y, city: this.countyCity(), kind: 'porch', b });
    }
  };
  W.countyCity = function () {
    if (!this._county)
      this._county = { idx: -1, id: 'county', name: 'County', def: { family: null, color: '#8a7a5a', biome: 'rural' }, buildings: [], lots: [], hamlet: true, rural: true, prosperity: 40, fear: 0, heat: 0, growth: 0 };
    return this._county;
  };
  W.areaFree = function (x, y, w, h) {
    for (let yy = y; yy < y + h; yy++)
      for (let xx = x; xx < x + w; xx++) {
        if (!this.inb(xx, yy)) return false;
        const t = this.tile[yy * this.W + xx];
        if (D.roadTile[t] || D.waterTile[t] || t === T.BLDG || t === T.ROCK || t === T.WALK || t === T.FIELD || t === T.DIRT && this.bid[yy * this.W + xx]) return false;
      }
    return true;
  };

  // Detect intersections and group them; add lights in town.
  W.finishRoads = function () {
    const w = this.W;
    for (let i = 0; i < this.flow.length; i++) {
      const f = this.flow[i];
      if (!f) continue;
      if (f & (F.N | F.S) && f & (F.E | F.W)) this.flow[i] |= F.X;
    }
    const seen = new Uint8Array(this.flow.length);
    for (let i = 0; i < this.flow.length; i++) {
      if (!(this.flow[i] & F.X) || seen[i]) continue;
      const stack = [i], tiles = [];
      seen[i] = 1;
      while (stack.length) {
        const j = stack.pop();
        tiles.push(j);
        const x = j % w, y = (j / w) | 0;
        for (const [dx, dy] of R.DIRS) {
          const k = (y + dy) * w + x + dx;
          if (this.inb(x + dx, y + dy) && !seen[k] && this.flow[k] & F.X) {
            seen[k] = 1;
            stack.push(k);
          }
        }
      }
      let arms = 0, mx = 0, my = 0;
      for (const j of tiles) {
        const x = j % w, y = (j / w) | 0;
        mx += x; my += y;
        R.DIRS.forEach(([dx, dy], d) => {
          const k = (y + dy) * w + x + dx;
          if (this.inb(x + dx, y + dy) && this.flow[k] && !(this.flow[k] & F.X)) arms++;
        });
      }
      const cx = mx / tiles.length, cy = my / tiles.length;
      const town = this.inCityRect(Math.round(cx), Math.round(cy), 0);
      const inTown = !!town && (Math.abs(cy - town.rowY - 0.5) < 2 || Math.abs(cx - town.colX - 0.5) < 2 || R.hash2(Math.round(cx), Math.round(cy), 4) < 0.45);
      const inter = {
        id: this.inters.length, tiles, cx, cy, arms: arms / 2, light: inTown && arms / 2 >= 3,
        phase: 0, timer: R.hash2(cx, cy, 1) * 8, // phase 0: E-W green, 1: yellow, 2: N-S green, 3: yellow
      };
      this.inters.push(inter);
      for (const j of tiles) this.interAt.set(j, inter);
    }
  };

  W.genFurniture = function (rnd) {
    const w = this.W;
    for (let y = 1; y < this.H - 1; y++)
      for (let x = 1; x < w - 1; x++) {
        const i = y * w + x;
        if (this.tile[i] !== T.WALK || this.obj[i]) continue;
        // next to road?
        let nearRoad = false;
        for (const [dx, dy] of R.DIRS) if (D.roadTile[this.tile[i + dy * w + dx]]) nearRoad = true;
        const r = R.hash2(x, y, 202);
        let nearDoor = false;
        for (const [dx, dy] of R.DIRS) {
          const b = this.bid[i + dy * w + dx];
          if (b && this.buildings[b].door.x === x + dx && this.buildings[b].door.y === y + dy) nearDoor = true;
        }
        if (nearRoad && (x + y) % 7 === 0 && r < 0.8) this.obj[i] = O.LAMP;
        else if (nearDoor) continue;
        else if (r < 0.02) this.obj[i] = O.HYDRANT;
        else if (r < 0.026) this.obj[i] = O.MAILBOX;
        else if (r < 0.032) this.obj[i] = O.TRASH;
        else if (r < 0.04) {
          this.obj[i] = O.PHONE;
          this.phones.push({ x, y });
        } else if (r < 0.05 && !nearRoad) this.obj[i] = O.BENCH;
      }
    // gas pumps in front of gas stations; barrels near warehouses
    for (const b of this.buildings) {
      if (!b) continue;
      if (b.type === 'gas') {
        const py = b.face === 'N' ? b.y - 2 : b.y + b.h + 1;
        for (let xx = b.x; xx < b.x + b.w; xx += 2) {
          const t = this.t(xx, py);
          if (t === T.LOT || t === T.WALK || t === T.GRASS || t === T.DESERT || t === T.DIRT) {}
        }
        // pumps live on the lot beside the door
        const sx = b.x - 1;
        if (this.t(sx, b.door.y) === T.LOT) this.obj[b.door.y * w + sx] = O.PUMP;
        if (this.t(b.x + b.w, b.door.y) === T.LOT) this.obj[b.door.y * w + b.x + b.w] = O.PUMP;
      }
      if (b.type === 'warehouse' || b.type === 'factory') {
        for (let k = 0; k < 4; k++) {
          const xx = b.x - 1 + rnd.int(0, b.w + 1), yy = b.face === 'N' ? b.y + b.h : b.y - 1;
          if (this.t(xx, yy) === T.LOT && !this.obj[yy * w + xx]) this.obj[yy * w + xx] = rnd() < 0.5 ? O.BARREL : O.CRATE;
        }
      }
    }
    // ensure some phone booths per city
    for (const c of this.cities) {
      let n = this.phones.filter((p) => p.x >= c.x0 && p.x <= c.x1 && p.y >= c.y0 && p.y <= c.y1).length;
      for (let k = 0; k < 200 && n < c.nbx * c.nby * 0.7; k++) {
        const x = rnd.int(c.x0, c.x1), y = rnd.int(c.y0, c.y1);
        const i = y * w + x;
        if (this.tile[i] === T.WALK && !this.obj[i]) {
          let ok = true;
          for (const [dx, dy] of R.DIRS) if (D.roadTile[this.tile[i + dy * w + dx]] || this.bid[i + dy * w + dx]) ok = false;
          if (ok) { this.obj[i] = O.PHONE; this.phones.push({ x, y }); n++; }
        }
      }
    }
  };

  // Build on a vacant lot (city growth / player investment)
  W.buildOnLot = function (lot, type, rnd) {
    const bt = D.btypes[type];
    const w = Math.min(lot.w, bt.w[1]);
    if (w < bt.w[0]) return null;
    for (let yy = lot.y; yy < lot.y + lot.h; yy++) for (let xx = lot.x; xx < lot.x + lot.w; xx++) this.setO(xx, yy, 0);
    const b = this.placeBuilding(null, type, w, rnd, lot);
    lot.used = true;
    b.fromLot = lot;
    return b;
  };
  W.setSite = function (lot, on) {
    for (let yy = lot.y; yy < lot.y + lot.h; yy++)
      for (let xx = lot.x; xx < lot.x + lot.w; xx++) {
        this.setT(xx, yy, on ? T.SITE : T.LOT);
        this.setO(xx, yy, on && (xx === lot.x || xx === lot.x + lot.w - 1) && (yy === lot.y || yy === lot.y + lot.h - 1) ? O.CONE : 0);
      }
  };
  // Wreck a building (fire, dynamite) — becomes a lot for rebuilding later.
  W.destroyBuilding = function (b) {
    if (b.destroyed) return;
    b.destroyed = true;
    for (let yy = b.y; yy < b.y + b.h; yy++)
      for (let xx = b.x; xx < b.x + b.w; xx++) {
        const i = yy * this.W + xx;
        this.bid[i] = 0;
        this.setT(xx, yy, T.BURNT);
        this.setO(xx, yy, R.hash2(xx, yy, 9) < 0.25 ? O.CRATE : 0);
      }
    const face = b.face === 'N' || b.face === 'S' ? b.face : 'N';
    const lot = { x: b.x, y: face === 'N' ? b.y : b.y + b.h - 6, w: b.w, h: 6, face, city: b.city, zone: 'mid', used: false, ruin: true };
    if (b.fromLot) Object.assign(lot, { x: b.fromLot.x, y: b.fromLot.y, w: b.fromLot.w, h: b.fromLot.h });
    if (!b.city.rural) {
      this.lots.push(lot);
      b.city.lots.push(lot);
    }
    R.bus.emit('building:destroyed', b);
  };

  // Nearest tile of a type set in a ring search (for spawning / pathing targets)
  W.findNear = function (tx, ty, rmin, rmax, pred, rnd) {
    rnd = rnd || R.rng;
    for (let k = 0; k < 40; k++) {
      const a = rnd() * Math.PI * 2, r = rmin + rnd() * (rmax - rmin);
      const x = Math.round(tx + Math.cos(a) * r), y = Math.round(ty + Math.sin(a) * r);
      if (this.inb(x, y) && pred(x, y)) return { x, y };
    }
    return null;
  };

  // Line of sight in tiles (buildings/rock block sight)
  W.los = function (ax, ay, bx, by) {
    const T_ = R.TILE;
    const dist = R.dist(ax, ay, bx, by);
    const steps = Math.ceil(dist / (T_ * 0.5));
    for (let s = 1; s < steps; s++) {
      const t = s / steps;
      const x = ((ax + (bx - ax) * t) / T_) | 0, y = ((ay + (by - ay) * t) / T_) | 0;
      const tt = this.t(x, y);
      if (tt === T.BLDG || tt === T.ROCK) return false;
    }
    return true;
  };

  R.World = World;
  R.BLOCK_PITCH = P;
})();
