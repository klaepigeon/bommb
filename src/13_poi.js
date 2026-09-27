// RHAPSODY — points of interest. Shops hang a pixel sign with an OPEN / CLOSED lamp by
// the door; walking past one puts it on your map with its icon. People you talk to can
// point you somewhere ("Know any good spots?"), tips and rumours drop pins, and pins you
// reach are ticked off.
(function () {
  const D = R.data, TS = R.TILE, INK = '#1b1410';

  // 7x7 glyphs
  const G7 = {
    gun: ['.......', '######.', '######.', '.##....', '.##....', '.#.....', '.......'],
    mug: ['.......', '#####..', '#####.#', '#####.#', '#####..', '#####..', '.......'],
    disco: ['...#...', '.#####.', '#.#.#.#', '#######', '#.#.#.#', '.#####.', '.......'],
    cross: ['..###..', '..###..', '#######', '#######', '..###..', '..###..', '.......'],
    fork: ['#.#.##.', '#.#.##.', '###.##.', '.#..##.', '.#..#..', '.#..#..', '.......'],
    scissors: ['#...#..', '.#.#...', '..#....', '.#.#...', '##.##..', '##.##..', '.......'],
    suit: ['.#...#.', '###.###', '#######', '.#####.', '.#####.', '.#####.', '.......'],
    dollar: ['..#....', '.####..', '#.#....', '.###...', '..#.#..', '####...', '..#....'],
    wrench: ['##...##', '.#...#.', '.#####.', '...#...', '...#...', '..###..', '.......'],
    pump: ['####...', '#..#.#.', '####..#', '####..#', '####.#.', '####...', '.......'],
    badge: ['...#...', '..###..', '#######', '.#####.', '..###..', '.##.##.', '.......'],
    cards: ['.###...', '.#.###.', '.#.#.#.', '.###.#.', '...###.', '.......', '.......'],
    bed: ['#......', '#......', '#######', '#######', '#.....#', '.......', '.......'],
    church: ['...#...', '..###..', '...#...', '.#####.', '.#.#.#.', '.#####.', '.......'],
    cleaver: ['.####..', '.####..', '.####..', '.#####.', '....##.', '....##.', '.......'],
    bag: ['..###..', '.#...#.', '#######', '#######', '#######', '#######', '.......'],
    wash: ['#######', '#.....#', '#.###.#', '#.#.#.#', '#.###.#', '#######', '.......'],
    hat: ['.......', '..###..', '..###..', '.#####.', '#######', '.......', '.......'],
    joy: ['...#...', '..###..', '...#...', '...#...', '#######', '#######', '.......'],
    star: ['...#...', '...#...', '#######', '.#####.', '..#.#..', '.#...#.', '.......'],
    pin: ['.###...', '#####..', '##.##..', '#####..', '.###...', '..#....', '..#....'],
    q: ['.###...', '#...#..', '...#...', '..#....', '..#....', '.......', '..#....'],
  };
  const SHOP = {
    gunshop: ['gun', '#8a8a92', 'Gun store'], bar: ['mug', '#e0a030', 'Bar'], club: ['disco', '#ff70c8', 'Disco'], pharmacy: ['cross', '#3ab080', 'Pharmacy'],
    hospital: ['cross', '#e03030', 'Hospital'], diner: ['fork', '#e0c080', 'Diner'], barber: ['scissors', '#e04a6a', 'Barber'], tailor: ['suit', '#9a6ad0', 'Tailor'],
    bank: ['dollar', '#6ac060', 'Bank'], pawn: ['dollar', '#c0a040', 'Pawn & fence'], garage: ['wrench', '#8aa0b0', 'Garage'], gas: ['pump', '#e05a30', 'Gas station'],
    police: ['badge', '#5a80e0', 'Police'], casino: ['cards', '#e0c040', 'Casino'], hotel: ['bed', '#a0b0d0', 'Hotel'], motel: ['bed', '#80c0c0', 'Motel'],
    church: ['church', '#e8e0d0', 'Church'], butcher: ['cleaver', '#c06050', 'Butcher & trapper'], general: ['bag', '#d0b060', 'General store'], liquor: ['mug', '#b070d0', 'Liquor'],
    laundry: ['wash', '#70b0d0', 'Laundromat'], social: ['hat', '#f0b838', 'Social club'], arcade: ['joy', '#70e070', 'Arcade'],
  };
  const PIN = { tip: ['pin', '#f0b838'], rumor: ['q', '#c890f0'], spot: ['star', '#f6ecd0'], dealer: ['pin', '#c890f0'] };

  const P = (R.poi = { found: new Set(), pins: [], t: 0 });
  P.shopInfo = (type) => SHOP[type];
  P.glyph = function (g, key, x, y, s, col) {
    const rows = G7[key];
    if (!rows) return;
    g.fillStyle = col;
    for (let j = 0; j < 7; j++) for (let i = 0; i < 7; i++) if (rows[j][i] === '#') g.fillRect(x + i * s, y + j * s, s, s);
  };
  P.init = function (game) { this.game = game; this.found = new Set(); this.pins = []; this.t = 0; };
  P.serialize = function () { return { found: [...this.found], pins: this.pins }; };
  P.restore = function (s) { if (!s) return; this.found = new Set(s.found || []); this.pins = s.pins || []; };
  P.add = function (tx, ty, kind, label, sub, quiet) {
    if (this.pins.some((p) => Math.abs(p.x - tx) < 3 && Math.abs(p.y - ty) < 3 && p.label === label)) return;
    this.pins.push({ x: tx, y: ty, kind, label, sub: sub || '', day: this.game.pop.day });
    if (this.pins.length > 40) this.pins.shift();
    if (!quiet) this.game.ui.toast(`Marked on your map: ${label}`, 'good');
  };
  P.discover = function (b, quiet) {
    if (!SHOP[b.type] || this.found.has(b.id)) return;
    this.found.add(b.id);
    if (!quiet && this.game.started) this.game.ui.toast(`New on your map: ${b.name} (${SHOP[b.type][2]})`);
  };
  P.update = function (dt) {
    const g = this.game, pl = g.player;
    this.t -= dt;
    if (this.t > 0 || pl.room) return;
    this.t = 1;
    const tx = pl.x / TS, ty = pl.y / TS;
    for (const b of g.world.buildings) if (b && !b.destroyed && SHOP[b.type] && !this.found.has(b.id) && Math.abs(b.out.x - tx) < 12 && Math.abs(b.out.y - ty) < 9) this.discover(b);
    // reached a pin
    for (const p of this.pins.slice()) if (Math.hypot(p.x - tx, p.y - ty) < 3 && p.kind !== 'rumor') { this.pins.splice(this.pins.indexOf(p), 1); g.ui.toast(`Found it: ${p.label}`, 'good'); }
  };
  // somebody tells you where to go
  P.askAround = function (h) {
    const g = this.game, pl = g.player, w = g.world;
    const city = w.cityAt((h.x / TS) | 0, (h.y / TS) | 0) || w.cities[0];
    const want = Object.keys(SHOP).filter((t) => t !== 'police');
    const cands = city.buildings.filter((b) => b && !b.destroyed && want.includes(b.type) && !this.found.has(b.id));
    if (!cands.length) {
      const rumor = R.legends.rumor();
      this.pinRumor(rumor);
      return rumor;
    }
    const pref = cands.filter((b) => ['gunshop', 'tailor', 'barber', 'pawn', 'casino', 'bar', 'club', 'hospital', 'garage'].includes(b.type));
    const b = R.rng.pick(pref.length ? pref : cands);
    this.discover(b, true);
    this.add(b.out.x, b.out.y, 'tip', b.name, SHOP[b.type][2]);
    const why = { gunshop: 'if you need iron', tailor: 'if you want to look like somebody', barber: 'for a proper shave', pawn: 'if you got something to sell, no questions', casino: 'if you feel lucky', bar: 'best drinks in town', club: 'if you can dance', hospital: 'you look like you\'ll need it', garage: 'for your ride' }[b.type] || 'worth a look';
    return `${b.name}, ${why}. I'll show you on your map.`;
  };
  // legend rumours drop a fuzzy pin near the real spot
  P.pinRumor = function (text) {
    const g = this.game;
    let s = null, label = '';
    if (/pink|Fear Man/.test(text) && R.ring.fearSpot) { s = R.ring.fearSpot; label = 'The pink-faced man?'; }
    else if (/piers|captain/.test(text)) { s = g.world.spots.find((q) => q.kind === 'pier'); label = 'Drowned captain?'; }
    else if (/Pinecrest|footprints/.test(text)) { const c = g.world.cities.find((q) => q.id === 'pine'); s = { x: c.cx, y: c.y0 - 25 }; label = 'Big footprints?'; }
    else if (/Dustwater desert|Lights/.test(text)) { const c = g.world.cities.find((q) => q.id === 'dust'); s = { x: c.cx + 40, y: c.cy + 30 }; label = 'Lights in the sky?'; }
    else if (/Scratch|bayou/.test(text)) { const c = g.world.cities.find((q) => q.id === 'bayou'); s = { x: c.cx - 30, y: c.cy + 20 }; label = 'Old Scratch?'; }
    if (!s) return;
    const r = R.rng;
    this.add(Math.round(s.x + (r() - 0.5) * 16), Math.round(s.y + (r() - 0.5) * 16), 'rumor', label, 'Just a rumour. Somewhere around here.');
  };

  // ---------------------------------------------------------------- drawing
  // the sign that hangs by a shop door, with an OPEN / CLOSED lamp
  P.drawSigns = function (g, left, top, vw, vh, t) {
    const game = this.game, w = game.world;
    const x0 = Math.floor(left / TS) - 4, y0 = Math.floor(top / TS) - 4, x1 = x0 + Math.ceil(vw / TS) + 8, y1 = y0 + Math.ceil(vh / TS) + 8;
    const seen = new Set();
    for (let ty = y0; ty < y1; ty++) for (let tx = x0; tx < x1; tx++) {
      const b = w.buildingAt(tx, ty);
      if (!b || seen.has(b.id) || b.destroyed) continue;
      seen.add(b.id);
      const info = SHOP[b.type];
      if (!info) continue;
      const open = game.ui.isOpen(b);
      const dx = b.door.x * TS, dy = b.door.y * TS;
      // bracket sign beside the door: a big pixel icon you can read from across the street
      const sx = dx + 17, sy = b.face === 'S' ? dy + TS - 29 : dy - 6;
      g.fillStyle = INK; g.fillRect(sx - 3, sy - 4, 22, 2); g.fillRect(sx + 2, sy - 4, 2, 4); g.fillRect(sx + 14, sy - 4, 2, 4);
      g.fillRect(sx - 1, sy - 1, 20, 20);
      g.fillStyle = '#2a1c14'; g.fillRect(sx, sy, 18, 18);
      g.fillStyle = info[1]; g.globalAlpha = 0.25; g.fillRect(sx + 1, sy + 1, 16, 16); g.globalAlpha = 1;
      this.glyph(g, info[0], sx + 2, sy + 2, 2, info[1]);
      // OPEN / CLOSED lamp above the door
      const lx = dx + 5, ly = b.face === 'S' ? dy + TS - 24 : dy - 10;
      g.fillStyle = INK; g.fillRect(lx - 1, ly - 1, 8, 6);
      const blink = open ? 1 : 0.6 + Math.sin(t * 2) * 0.15;
      g.fillStyle = open ? '#50f070' : '#c02a20'; g.globalAlpha = blink; g.fillRect(lx, ly, 6, 4); g.globalAlpha = 1;
      if (game.clock.isNight()) { g.fillStyle = open ? 'rgba(80,240,112,0.2)' : 'rgba(200,40,30,0.15)'; g.beginPath(); g.arc(lx + 3, ly + 2, 9, 0, 7); g.fill(); }
    }
  };
  P.drawMini = function (c, toM, S) {
    const w = this.game.world;
    for (const id of this.found) {
      const b = w.buildings[id];
      if (!b || b.destroyed) continue;
      const [x, y] = toM(b.out.x * TS, b.out.y * TS);
      if (x < -6 || y < -6 || x > S + 6 || y > S + 6) continue;
      const info = SHOP[b.type];
      c.fillStyle = INK; c.fillRect(x - 5, y - 5, 10, 10);
      this.glyph(c, info[0], x - 3.5, y - 3.5, 1, info[1]);
    }
    for (const p of this.pins) {
      const [x, y] = toM(p.x * TS, p.y * TS);
      const [k, col] = PIN[p.kind] || PIN.tip;
      const cx = R.clamp(x, 8, S - 8), cy = R.clamp(y, 8, S - 8);
      c.fillStyle = INK; c.fillRect(cx - 6, cy - 6, 12, 12);
      this.glyph(c, k, cx - 3.5, cy - 4, 1, col);
    }
  };
  P.drawFull = function (c, scale) {
    const w = this.game.world;
    for (const id of this.found) {
      const b = w.buildings[id];
      if (!b || b.destroyed) continue;
      const info = SHOP[b.type];
      const x = b.out.x * scale, y = b.out.y * scale;
      c.fillStyle = INK; c.fillRect(x - 6, y - 6, 12, 12);
      this.glyph(c, info[0], x - 5, y - 5, 1.43, info[1]);
    }
    c.font = 'bold 13px "Barlow Condensed", sans-serif';
    c.textAlign = 'left';
    for (const p of this.pins) {
      const [k, col] = PIN[p.kind] || PIN.tip;
      const x = p.x * scale, y = p.y * scale;
      if (p.kind === 'rumor') { c.strokeStyle = 'rgba(200,144,240,0.8)'; c.setLineDash([4, 4]); c.lineWidth = 2; c.beginPath(); c.arc(x, y, 12 * scale, 0, 7); c.stroke(); c.setLineDash([]); }
      c.fillStyle = INK; c.fillRect(x - 8, y - 8, 16, 16);
      this.glyph(c, k, x - 6, y - 6, 1.8, col);
      const tw = c.measureText(p.label).width + 8;
      c.fillStyle = 'rgba(27,20,16,0.85)'; c.fillRect(x + 10, y - 8, tw, 16);
      c.fillStyle = col; c.fillText(p.label, x + 14, y + 4);
    }
  };
})();
