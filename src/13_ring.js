// RHAPSODY — the Yellow Ring. A gaunt, magenta-faced drifter who calls himself the Fear
// Man stands under a dead tree deep in the Dustwater flats between one and four in the
// morning. Find him and he gives you his ring: picture a thing and it appears in hard
// yellow light. Tap RING to hurl the construct picked in the library, hold RING for the
// beam, and bare fists swing whatever giant construct springs to mind. Will powers it
// all, and fear refills it.
(function () {
  const D = R.data, TS = R.TILE, T = D.T;
  let Y = ['#6a4600', '#b88400', '#f0c020', '#fff27a'];
  const GLOW = 'rgba(255,226,60,';
  // the ring's colour: yellow is fear, green is will. Everything hard-light reads it.
  const PAL = {
    yellow: { Y: ['#6a4600', '#b88400', '#f0c020', '#fff27a'], glow: 'rgba(255,226,60,', core: '#ffe23c', hi: '#fff27a', light: '#fffbe0', mid: '#f0c020' },
    green: { Y: ['#0a4a1a', '#1a8a34', '#30c050', '#9af0a8'], glow: 'rgba(80,240,110,', core: '#50f070', hi: '#9af0a8', light: '#eaffee', mid: '#30c050' },
  };
  R.ringPALS = PAL; // the other corps add their colours in 14_corps
  const pal = () => PAL[(R.game && R.game.player && R.game.player.ringColor) || 'yellow'] || PAL.yellow;
  const GL = () => pal().glow;
  R.ringPal = pal;

  // ---------------------------------------------------------------- the library
  // kind: throw (projectile), drop (falls from the sky on the target), trap (holds
  // them in place), spring (launches), rocket (explodes), shark (homes in and bites),
  // saw (cuts through a line of people), shield (guards you), douse (puts out fires)
  const LIB = (D.constructs = {
    anvil: { name: 'Anvil', cat: 'Heavy', kind: 'drop', dmg: 70, r: 14, cost: 18 },
    piano: { name: 'Grand Piano', cat: 'Heavy', kind: 'drop', dmg: 90, r: 20, cost: 26 },
    safe: { name: 'Safe', cat: 'Heavy', kind: 'drop', dmg: 80, r: 14, cost: 22 },
    boulder: { name: 'Boulder', cat: 'Heavy', kind: 'throw', dmg: 60, r: 10, cost: 16, roll: 1 },
    mallet: { name: 'Giant Mallet', cat: 'Weapons', kind: 'throw', dmg: 45, r: 8, cost: 10, swing: 1 },
    hammer: { name: 'Claw Hammer', cat: 'Weapons', kind: 'throw', dmg: 35, r: 6, cost: 8, swing: 1 },
    glove: { name: 'Boxing Glove', cat: 'Weapons', kind: 'spring', dmg: 30, r: 8, cost: 10, swing: 1 },
    fist: { name: 'Giant Fist', cat: 'Weapons', kind: 'throw', dmg: 40, r: 9, cost: 10, swing: 1 },
    bat: { name: 'Baseball Bat', cat: 'Weapons', kind: 'throw', dmg: 32, r: 6, cost: 7, swing: 1 },
    saw: { name: 'Buzzsaw', cat: 'Weapons', kind: 'saw', dmg: 45, r: 7, cost: 16 },
    rocket: { name: 'Rocket', cat: 'Weapons', kind: 'rocket', dmg: 70, r: 34, cost: 28 },
    shark: { name: 'Shark', cat: 'Weird', kind: 'shark', dmg: 22, r: 8, cost: 20 },
    cage: { name: 'Cage', cat: 'Traps', kind: 'trap', dmg: 0, r: 10, cost: 14, hold: 9 },
    net: { name: 'Net', cat: 'Traps', kind: 'trap', dmg: 0, r: 12, cost: 10, hold: 6 },
    spring: { name: 'Spring', cat: 'Traps', kind: 'spring', dmg: 10, r: 10, cost: 8 },
    shield: { name: 'Bubble Shield', cat: 'Weird', kind: 'shield', dmg: 0, r: 0, cost: 30 },
    // the original's household and street props, remade in light
    crate: { name: 'Crate', cat: 'Street', prop: 'crate', kind: 'throw', dmg: 26, r: 7, cost: 5 },
    bench: { name: 'Park Bench', cat: 'Street', prop: 'bench', kind: 'throw', dmg: 38, r: 10, cost: 9, swing: 1 },
    trashcan: { name: 'Trash Can', cat: 'Street', prop: 'trashcan', kind: 'throw', dmg: 30, r: 8, cost: 6 },
    mailbox: { name: 'Mailbox', cat: 'Street', prop: 'mailbox', kind: 'throw', dmg: 34, r: 8, cost: 7 },
    hydrant: { name: 'Fire Hydrant', cat: 'Street', prop: 'hydrant', kind: 'douse', dmg: 30, r: 8, cost: 8 },
    cone: { name: 'Traffic Cone', cat: 'Street', prop: 'cone', kind: 'throw', dmg: 14, r: 6, cost: 3 },
    sign: { name: 'Stop Sign', cat: 'Street', prop: 'sign', kind: 'throw', dmg: 34, r: 8, cost: 7, swing: 1 },
    barrel: { name: 'Oil Barrel', cat: 'Street', prop: 'barrel', kind: 'throw', dmg: 40, r: 9, cost: 9, roll: 1 },
    tire: { name: 'Spare Tire', cat: 'Street', prop: 'tire', kind: 'throw', dmg: 22, r: 7, cost: 5, roll: 1 },
    propane: { name: 'Propane Tank', cat: 'Street', prop: 'propane', kind: 'rocket', dmg: 50, r: 26, cost: 18 },
    pan: { name: 'Frying Pan', cat: 'Household', prop: 'pan', kind: 'throw', dmg: 28, r: 6, cost: 5, swing: 1 },
    bottle: { name: 'Bottle', cat: 'Household', prop: 'bottle', kind: 'throw', dmg: 18, r: 5, cost: 3 },
    chair: { name: 'Folding Chair', cat: 'Household', prop: 'chair', kind: 'throw', dmg: 28, r: 7, cost: 5, swing: 1 },
    stool: { name: 'Bar Stool', cat: 'Household', prop: 'stool', kind: 'throw', dmg: 26, r: 7, cost: 5 },
    broom: { name: 'Broom', cat: 'Household', prop: 'broom', kind: 'throw', dmg: 16, r: 6, cost: 3, swing: 1 },
    plank: { name: '2x4 Plank', cat: 'Household', prop: 'plank', kind: 'throw', dmg: 26, r: 7, cost: 5, swing: 1 },
    pipe: { name: 'Lead Pipe', cat: 'Household', prop: 'pipe', kind: 'throw', dmg: 32, r: 6, cost: 6, swing: 1 },
    wrench: { name: 'Pipe Wrench', cat: 'Household', prop: 'wrench', kind: 'throw', dmg: 28, r: 6, cost: 5 },
    guitar: { name: 'Guitar', cat: 'Household', prop: 'guitar', kind: 'throw', dmg: 26, r: 7, cost: 5, swing: 1 },
    bowling: { name: 'Bowling Ball', cat: 'Household', prop: 'bowling', kind: 'throw', dmg: 40, r: 6, cost: 7, roll: 1 },
    bucket: { name: 'Bucket of Water', cat: 'Household', prop: 'bucket', kind: 'douse', dmg: 8, r: 10, cost: 4 },
    extinguisher: { name: 'Extinguisher', cat: 'Household', prop: 'extinguisher', kind: 'douse', dmg: 16, r: 14, cost: 6 },
    tv: { name: 'Old TV', cat: 'Household', prop: 'tv', kind: 'throw', dmg: 36, r: 8, cost: 7 },
    dumbbell: { name: 'Dumbbell', cat: 'Household', prop: 'dumbbell', kind: 'throw', dmg: 38, r: 6, cost: 7 },
    shovel: { name: 'Shovel', cat: 'Household', prop: 'shovel', kind: 'throw', dmg: 28, r: 7, cost: 5, swing: 1 },
    lamp: { name: 'Table Lamp', cat: 'Household', prop: 'lamp', kind: 'throw', dmg: 16, r: 6, cost: 3 },
    plant: { name: 'Potted Plant', cat: 'Household', prop: 'plant', kind: 'throw', dmg: 18, r: 6, cost: 3 },
    gnome: { name: 'Garden Gnome', cat: 'Weird', prop: 'gnome', kind: 'throw', dmg: 20, r: 6, cost: 4 },
    fish: { name: 'Wet Fish', cat: 'Weird', prop: 'fish', kind: 'throw', dmg: 12, r: 6, cost: 2 },
    cake: { name: 'Whole Cake', cat: 'Weird', prop: 'cake', kind: 'throw', dmg: 4, r: 6, cost: 2 },
  });
  const CATS = ['All', 'Heavy', 'Weapons', 'Traps', 'Street', 'Household', 'Weird'];
  const SWING_SET = Object.keys(LIB).filter((k) => LIB[k].swing);

  // ---------------------------------------------------------------- sprites
  // hand-drawn constructs on the original's pixel canvas, in a yellow ramp
  const PAINT = {
    anvil(o) { o.shadedRect(2, 6, 14, 4, Y); o.rect(0, 6, 3, 2, Y[2]); o.set(0, 7, Y[1]); o.shadedRect(6, 10, 6, 3, Y); o.shadedRect(4, 13, 10, 3, Y); o.hline(3, 15, 6, Y[3]); },
    piano(o) { o.ellipse(10, 9, 9, 7, (x, y, a, b) => (b < -0.4 ? Y[3] : a > 0.5 ? Y[1] : Y[2])); o.rect(1, 12, 18, 4, Y[1]); for (let x = 2; x < 18; x += 2) o.rect(x, 13, 1, 3, Y[3]); o.rect(3, 16, 1, 3, Y[1]); o.rect(16, 16, 1, 3, Y[1]); o.line(4, 4, 12, 1, Y[3]); },
    safe(o) { o.shadedRect(2, 2, 14, 14, Y); o.ellipse(9, 9, 3.5, 3.5, (x, y, a, b) => (a * a + b * b < 0.3 ? Y[0] : Y[3])); o.rect(13, 7, 2, 4, Y[1]); o.rect(3, 16, 2, 2, Y[1]); o.rect(13, 16, 2, 2, Y[1]); },
    boulder(o) { o.shadedEllipse(9, 9, 7.5, 6.5, Y); o.set(6, 6, Y[3]); o.line(9, 10, 12, 13, Y[1]); o.set(5, 11, Y[1]); },
    mallet(o) { o.shadedRect(1, 2, 16, 7, Y); o.hline(1, 16, 2, Y[3]); o.rect(8, 9, 3, 9, Y[1]); o.rect(9, 9, 1, 9, Y[2]); },
    hammer(o) { o.shadedRect(3, 2, 10, 4, Y); o.line(13, 3, 16, 1, Y[2]); o.line(13, 5, 16, 7, Y[2]); o.rect(7, 6, 2, 11, Y[1]); o.rect(7, 6, 1, 11, Y[2]); },
    glove(o) { o.shadedEllipse(8, 7, 6.5, 5.5, Y); o.shadedEllipse(3, 9, 2.5, 2.5, Y); o.shadedRect(5, 12, 7, 5, Y); o.hline(5, 11, 13, Y[3]); o.set(9, 4, Y[3]); },
    fist(o) { o.shadedEllipse(9, 8, 7, 6, Y); for (const x of [5, 8, 11]) o.vline(x, 3, 8, Y[1]); o.shadedRect(5, 13, 8, 4, Y); o.hline(3, 8, 10, Y[1]); },
    bat(o) { o.line(2, 16, 14, 2, Y[2]); o.line(3, 16, 15, 3, Y[1]); o.line(11, 3, 15, 1, Y[3]); o.line(12, 5, 16, 3, Y[2]); o.rect(1, 15, 3, 2, Y[1]); },
    saw(o) { o.shadedEllipse(9, 9, 6.5, 6.5, Y); o.ellipse(9, 9, 2, 2, Y[0]); for (let a = 0; a < 6.28; a += 0.785) o.set(Math.round(9 + Math.cos(a) * 8), Math.round(9 + Math.sin(a) * 8), Y[3]); },
    rocket(o) { o.shadedRect(4, 6, 10, 6, Y); o.ellipse(15, 9, 3, 3, Y[3]); o.rect(1, 3, 4, 3, Y[1]); o.rect(1, 12, 4, 3, Y[1]); o.rect(8, 8, 2, 2, Y[0]); o.rect(0, 8, 3, 2, Y[3]); },
    shark(o) { o.ellipse(9, 10, 8, 4, (x, y, a, b) => (b > 0.2 ? Y[3] : Y[2])); o.line(8, 6, 11, 2, Y[2]); o.line(9, 6, 12, 3, Y[1]); o.line(1, 7, 1, 13, Y[1]); o.line(2, 8, 2, 12, Y[2]); o.set(14, 9, Y[0]); o.hline(12, 16, 12, Y[0]); },
    cage(o) { o.shadedRect(2, 1, 14, 2, Y); o.shadedRect(2, 15, 14, 2, Y); for (let x = 2; x <= 15; x += 3) o.rect(x, 3, 1, 12, Y[2]); o.set(9, 0, Y[3]); },
    net(o) { for (let k = 0; k < 18; k += 4) { o.line(k, 0, 17, 17 - k, Y[2]); o.line(0, k, 17 - k, 17, Y[2]); o.line(17 - k, 0, 0, 17 - k, Y[1]); } },
    spring(o) { for (let y = 3; y < 15; y += 3) { o.line(3, y, 14, y + 1, Y[2]); o.line(14, y + 1, 3, y + 3, Y[1]); } o.shadedRect(2, 15, 14, 2, Y); o.shadedRect(2, 1, 14, 2, Y); },
    shield(o) { o.ellipse(9, 9, 8, 8, (x, y, a, b) => { const d = a * a + b * b; return d > 0.72 ? Y[2] : a < -0.3 && b < -0.3 && d > 0.3 ? Y[3] : null; }); },
  };
  const sprites = {};
  function recolor(cv) {
    const c = document.createElement('canvas');
    c.width = cv.width; c.height = cv.height;
    const g = c.getContext('2d');
    g.drawImage(cv, 0, 0);
    const im = g.getImageData(0, 0, c.width, c.height);
    const d = im.data;
    for (let i = 0; i < d.length; i += 4) {
      if (!d[i + 3]) continue;
      const l = (d[i] * 0.3 + d[i + 1] * 0.55 + d[i + 2] * 0.15) / 255;
      const hex = Y[Math.min(3, Math.floor(l * 4.2))];
      const n = parseInt(hex.slice(1), 16);
      d[i] = n >> 16; d[i + 1] = (n >> 8) & 255; d[i + 2] = n & 255;
    }
    g.putImageData(im, 0, 0);
    return c;
  }
  const sprite = (k) => {
    const col = Object.keys(PAL).find((c) => PAL[c] === pal()) || 'yellow';
    const key = col === 'yellow' ? k : col + ':' + k;
    if (sprites[key]) return sprites[key];
    Y = pal().Y;
    const c = LIB[k];
    let cv;
    if (c.prop && R.old.props[c.prop]) cv = recolor(R.old.paintProp(c.prop));
    else if (PAINT[k]) { const o = new R.old.O(18, 18); PAINT[k](o); cv = o.outlineBy(() => Y[0]).toCanvas(); }
    else cv = document.createElement('canvas');
    return (sprites[key] = cv);
  };
  // hard light: the sprite plus a soft halo
  function drawLit(g, cv, x, y, scale, rot, alpha) {
    g.save();
    g.translate(Math.round(x), Math.round(y));
    if (rot) g.rotate(rot);
    const s = scale || 1;
    g.globalAlpha = (alpha == null ? 1 : alpha) * 0.28;
    for (const [dx, dy] of [[-1, 0], [1, 0], [0, -1], [0, 1]]) g.drawImage(cv, -cv.width * s / 2 + dx * 2, -cv.height * s / 2 + dy * 2, cv.width * s, cv.height * s);
    g.globalAlpha = alpha == null ? 0.92 : alpha;
    g.drawImage(cv, -cv.width * s / 2, -cv.height * s / 2, cv.width * s, cv.height * s);
    g.restore();
  }

  // ---------------------------------------------------------------- state
  // the ring as a weapon: B fires a bolt of hard light, holding B pours out the beam
  D.weapons.ring = { name: 'Yellow Ring', ring: 1, rate: 0.28, range: 230, dmg: 26 };
  const Ring = (R.ring = { game: null, shots: [], drops: [], swings: [], beam: null, selected: 'anvil', cat: 'All' });
  Ring.init = function (game) {
    this.game = game;
    this.shots = []; this.drops = []; this.swings = [];
    this.beam = null;
    const pl = game.player;
    if (pl.will == null) pl.will = 100;
    this.placeFearMan();
  };
  Ring.owned = function () { const pl = this.game.player; return !!(pl.inv.tools && pl.inv.tools.ring); };

  // ---------------------------------------------------------------- the Fear Man
  // A clearing with a dead tree, deep in the desert, the same for every seed's world.
  Ring.placeFearMan = function () {
    const w = this.game.world;
    const dust = w.cities.find((c) => c.id === 'dust') || w.cities[0];
    const rnd = R.mulberry(w.seed * 7 + 1313);
    let spot = null;
    for (let k = 0; k < 400 && !spot; k++) {
      const a = rnd() * Math.PI * 2, r = 55 + rnd() * 40;
      const x = Math.round(dust.cx + Math.cos(a) * (dust.nbx * 13 + r)), y = Math.round(dust.cy + Math.sin(a) * (dust.nby * 13 + r));
      if (!w.inb(x, y) || w.isWater(x, y) || w.inCityRect(x, y, 20)) continue;
      let clear = true;
      for (let yy = y - 6; yy <= y + 6 && clear; yy++) for (let xx = x - 6; xx <= x + 6 && clear; xx++) if (!w.inb(xx, yy) || D.roadTile[w.t(xx, yy)] || w.bid[w.idx(xx, yy)] || w.isWater(xx, yy)) clear = false;
      if (clear) spot = { x, y };
    }
    if (!spot) spot = { x: dust.cx + dust.nbx * 13 + 60, y: dust.cy };
    this.fearSpot = spot;
    // a ring of bleached stones round the dead tree, so the place is recognisable
    for (let yy = spot.y - 3; yy <= spot.y + 3; yy++) for (let xx = spot.x - 3; xx <= spot.x + 3; xx++) if (w.inb(xx, yy)) w.obj[w.idx(xx, yy)] = 0;
    w.obj[w.idx(spot.x, spot.y - 1)] = D.O.DEADTREE;
    for (let a = 0; a < 6.28; a += 0.9) { const xx = Math.round(spot.x + Math.cos(a) * 3), yy = Math.round(spot.y + Math.sin(a) * 3); if (w.inb(xx, yy)) w.obj[w.idx(xx, yy)] = D.O.BOULDER; }
  };
  Ring.fearHours = function () { const h = this.game.clock.hour(); return h >= 1 && h < 4; };
  Ring.updateFearMan = function () {
    const g = this.game, pl = g.player, s = this.fearSpot;
    if (!s) return;
    const d = Math.hypot(pl.x / TS - s.x, pl.y / TS - s.y);
    const fm = this.fearMan && !this.fearMan.dead && g.actors.list.includes(this.fearMan) ? this.fearMan : null;
    const want = this.fearHours() && d < 34 && !pl.room && g.clock.t > (this.goneUntil || 0) && !this.goneForever && !(pl.fearQ && pl.fearQ.fmGone);
    if (want && !fm) {
      const h = g.actors.makeHuman(s.x * TS + 8, s.y * TS + 14, {
        tag: 'fearman', role: 'fearman', arch: 'eccentric', cash: 0,
        look: { fem: false, age: 50, skin: '#b05080', hair: '#101010', top: '#1a1a3a', bottom: '#101018', hat: null, seedStr: 'fearman', build: 1,
          oldOverride: { skin: ['#4a1030', '#7a2050', '#b04a7c', '#e080aa'], style: 'short', stache: true, jacket: ['#0e0e22', '#1c1c3c', '#2c2c5a', '#44447a'], top: 'collar', shirt: ['#6a4600', '#b88400', '#f0c020', '#fff27a'], pants: ['#08080e', '#14141e', '#22222e', '#34344a'] } },
      });
      h.keep = true;
      h.stay = true;
      h.state = 'idle';
      h.timer = 1e9;
      h.tr.brave = 1;
      h.strangerName = 'Fear Man';
      h.fearman = true;
      h.spot = { x: s.x, y: s.y, kind: 'fear' };
      this.fearMan = h;
    } else if (fm && !want) {
      g.fx.text(fm.x, fm.y - 20, '...', pal().hi);
      g.actors.remove(fm);
      this.fearMan = null;
    }
    if (fm) {
      fm.dir = R.dir4(pl.x - fm.x, pl.y - fm.y);
      fm.ang = Math.atan2(pl.y - fm.y, pl.x - fm.x);
      if (R.rng() < 0.08) g.fx.add({ x: fm.x + (R.rng() - 0.5) * 10, y: fm.y - 10 - R.rng() * 8, vx: 0, vy: -12, life: 1, max: 1, c: pal().hi, s: 1, glow: 1 });
      // the showdown on the green path is handled by the quest
      if (R.fearQuest.fightFearMan(fm)) return;
      // strike him and he's gone for three nights
      if (fm.hp < fm.maxHp) {
        g.actors.say(fm, 'You mistake me for something that can be hurt.');
        for (let i = 0; i < 14; i++) g.fx.add({ x: fm.x, y: fm.y - 10, vx: (R.rng() - 0.5) * 120, vy: (R.rng() - 0.5) * 120, life: 0.6, max: 0.6, c: pal().hi, s: 2, glow: 1 });
        g.actors.remove(fm);
        this.fearMan = null;
        this.goneUntil = g.clock.t + 1440 * 3;
        g.ui.toast('He is gone. The stones hum. Come back in a few nights.', 'warn');
      }
    }
  };
  Ring.fearTree = function (h) {
    const g = this.game, pl = g.player, ui = g.ui;
    const say = (t) => ui.talkLine(t);
    const opts = [];
    const met = g.hints.fearMet;
    opts.push({ label: '"Who are you?"', fn: () => { g.hints.fearMet = 1; say(R.rng.pick(['They call me the Fear Man. Once I kept order across a thousand worlds. Order is a kind of fear, properly applied.', 'A man who was thrown out of the finest police force in the universe for being right.'])); } });
    opts.push({ label: '"What are you doing out here?"', fn: () => say('Waiting for someone who understands that people do what they are afraid not to do.') });
    if (!this.owned()) {
      opts.push({ label: '"What\'s that glow on your hand?"', fn: () => say('A ring. It turns what you imagine into hard light. It is powered by will, and fed by fear.') });
      opts.push({ label: met ? '"Give me the ring."' : '"I could use a thing like that."', fn: () => {
        if (!g.hints.fearMet) return say('You do not even know who I am. Ask.');
        pl.inv.tools.ring = 1;
        pl.will = 100;
        pl.wardrobe = pl.wardrobe || {}; pl.wardrobe['unlock:fearsuit'] = 1;
        g.hints.fearMet = 1;
        say('Take it. You have the gift: people step aside for you. Imagine a thing, and it will be there.');
        g.ui.closeSheet();
        g.audio.sfx('promote');
        g.ui.setRingButtons();
        g.ui.story('The Yellow Ring', 'A band of warm yellow metal. It hums against your knuckle. He hands you a folded blue-and-black uniform too.\n\nSWAP to the RING and press B to fire bolts of hard light; hold B for a beam. Press A with nothing around to SUMMON a construct from the library. With bare fists, every punch swings something enormous.\n\nIt runs on WILL, which comes back faster when the people around you are afraid. The Fear Man has more lessons for you.');
        g.pop.addNews('dust', 'Truckers report "a yellow light like a second moon" over the Dustwater flats last night.');
      } });
    } else { for (const o of R.fearQuest.options(h, say, () => ui.closeSheet())) opts.push(o); opts.push({ label: '"About the ring..."', fn: () => say(R.rng.pick(['Fear is not cruelty. Fear is respect with the pretenses stripped away.', 'Your will is weak tonight. Frighten someone and it will return.', 'Use it well. Or do not. I have watched empires do both.'])) }); }
    opts.push({ label: 'Leave him be', fn: () => ui.closeSheet() });
    return { title: g.hints.fearMet ? 'The Fear Man' : 'A gaunt stranger', sub: 'Magenta skin, a widow\'s peak, a pencil moustache. He does not blink.', options: opts };
  };

  // ---------------------------------------------------------------- using it
  Ring.update = function (dt) {
    const g = this.game, pl = g.player;
    this.updateFearMan();
    if (pl.shieldT > 0) pl.shieldT -= dt;
    if (!this.owned()) return;
    // will: comes back slowly, faster when the people nearby are afraid
    let fear = 0;
    for (const a of g.actors.near(pl.x, pl.y, TS * 10)) if (a.kind === 'h' && !a.dead && (a.state === 'flee' || a.state === 'cower' || a.state === 'surrender')) fear++;
    pl.will = Math.min(pl.willMax || 100, pl.will + dt * (5 + Math.min(18, fear * 3)));
    const inp = g.input;
    if (!pl.inCar && !pl.room) {
      if (inp.pressed('ring')) this.pressT = 0;
      if (inp.held('ring')) {
        this.pressT = (this.pressT || 0) + dt;
        if (this.pressT > 0.3) this.fireBeam(dt);
      } else if (this.pressT != null) {
        if (this.pressT <= 0.3) this.conjure();
        this.pressT = null;
        this.beam = null;
      }
      if (inp.pressed('lib')) this.openLibrary();
      // ring equipped: hold B for the beam (a tap fires a bolt through P.fire)
      if (pl.weapon === 'ring' && pl.weaponOut && inp.held('attack')) {
        this.holdB = (this.holdB || 0) + dt;
        if (this.holdB > 0.35) this.fireBeam(dt);
      } else if (this.holdB) { this.holdB = 0; if (!inp.held('ring')) this.beam = null; }
    }
    this.updateShots(dt);
  };

  Ring.spend = function (n) {
    const g = this.game, pl = g.player;
    if (pl.will < n) { if (!this.lowT || g.clock.real - this.lowT > 2) { this.lowT = g.clock.real; g.ui.toast('Not enough WILL. Scare somebody or wait.', 'warn'); } return false; }
    pl.will -= n;
    return true;
  };
  Ring.aim = function () {
    const pl = this.game.player;
    const tg = pl.aimTarget();
    return { tg, ang: tg ? Math.atan2(tg.y - pl.y, tg.x - pl.x) : pl.ang };
  };

  Ring.conjure = function () {
    const g = this.game, pl = g.player, k = this.selected, c = LIB[k];
    if (!c || !this.spend(Math.round(c.cost * (R.fearQuest && (R.fearQuest.perk('aura') || R.fearQuest.perkG('knight')) ? 0.75 : 1)))) return;
    const { tg, ang } = this.aim();
    pl.ang = ang;
    pl.punchT = 0.22;
    g.audio.sfx('coolOn', pl.x, pl.y);
    if (c.kind === 'shield') {
      pl.shieldT = R.fearQuest && R.fearQuest.perkG('knight') ? 20 : 10;
      g.ui.toast('A bubble of hard light surrounds you.');
      return;
    }
    if (c.kind === 'drop') {
      const tx = tg ? tg.x : pl.x + Math.cos(ang) * 60, ty = tg ? tg.y : pl.y + Math.sin(ang) * 60;
      this.drops.push({ k, x: tx, y: ty, t: 0, fall: 0.7 });
      return;
    }
    const sp = c.kind === 'rocket' ? 240 : c.kind === 'shark' ? 150 : c.roll ? 160 : 210;
    this.shots.push({ k, x: pl.x + Math.cos(ang) * 10, y: pl.y - 8 + Math.sin(ang) * 6, vx: Math.cos(ang) * sp, vy: Math.sin(ang) * sp, t: 0, life: c.kind === 'shark' ? 3 : 1.3, rot: 0, tg, hits: new Set(), bites: 0 });
  };

  Ring.updateShots = function (dt) {
    const g = this.game, w = g.world, pl = g.player;
    for (let i = this.shots.length - 1; i >= 0; i--) {
      const s = this.shots[i];
      if (s.bolt) {
        s.t += dt; s.x += s.vx * dt; s.y += s.vy * dt;
        const tt = w.t((s.x / TS) | 0, ((s.y + 8) / TS) | 0);
        let end = s.t > s.life || tt === T.BLDG || tt === T.WALL || tt === T.VOID || tt === T.ROCK || R.fearQuest.hitTest(s.x, s.y, 30);
        if (!end) for (const a of g.actors.near(s.x, s.y + 8, 12)) {
          if (a.dead || a.inCar || (a.fearman && !a.fearFight) || Math.hypot(a.x - s.x, a.y - 10 - s.y) > 8) continue;
          R.combat.damage(a, D.weapons.ring.dmg * (R.fearQuest && R.fearQuest.perk('duel') ? 1.5 : 1), s.owner || pl, 'bullet');
          if (a.kind === 'h' && !a.dead) { g.actors.moveActor(a, s.vx * 0.12, s.vy * 0.12, 0.1); a.down = Math.max(a.down, 0.6); }
          g.fx.text(a.x, a.y - 24, 'ZAP!', pal().hi);
          end = true; break;
        }
        if (!end) { const v = g.traffic.nearestCar(s.x, s.y + 6, 12); if (v && !v.wrecked && v !== pl.inCar) { g.traffic.damage(v, 14, pl); end = true; } }
        if (end) { this.shots.splice(i, 1); this.burst(s.x, s.y); }
        continue;
      }
      const c = LIB[s.k];
      s.t += dt;
      if (c.kind === 'shark' && s.tg && !s.tg.dead) {
        const a = Math.atan2(s.tg.y - 6 - s.y, s.tg.x - s.x), cur = Math.atan2(s.vy, s.vx);
        const na = cur + R.clamp(R.angDiff(cur, a), -4 * dt, 4 * dt);
        s.vx = Math.cos(na) * 150; s.vy = Math.sin(na) * 150;
      }
      s.x += s.vx * dt; s.y += s.vy * dt;
      s.rot += dt * (c.roll ? 12 : c.kind === 'saw' ? 30 : c.kind === 'rocket' || c.kind === 'shark' ? 0 : 8);
      if (c.kind === 'rocket' && R.rng() < 0.6) g.fx.smoke(s.x - s.vx * 0.03, s.y - s.vy * 0.03);
      const tx = (s.x / TS) | 0, ty = ((s.y + 8) / TS) | 0;
      const tt = w.t(tx, ty);
      let end = s.t > s.life || tt === T.BLDG || tt === T.WALL || tt === T.VOID || tt === T.ROCK;
      if (!end) {
        for (const a of g.actors.near(s.x, s.y + 6, c.r + 6)) {
          if (a.dead || a.inCar || s.hits.has(a) || (a.fearman && !a.fearFight)) continue;
          if (Math.hypot(a.x - s.x, a.y - 8 - s.y) > c.r + 6) continue;
          this.hit(s.k, a, s.x, s.y, Math.atan2(s.vy, s.vx));
          s.hits.add(a);
          if (c.kind === 'saw') continue;
          if (c.kind === 'shark' && ++s.bites < 3) { s.hits.clear(); s.hits.add(a); s.vx *= -0.6; s.vy *= -0.6; continue; }
          end = true;
          break;
        }
        if (!end) {
          const v = g.traffic.nearestCar(s.x, s.y + 6, 14);
          if (v && !v.wrecked && v !== pl.inCar) { g.traffic.damage(v, c.dmg * 0.8, pl); v.vx += s.vx * 0.4; v.vy += s.vy * 0.4; end = true; }
        }
      }
      if (end) {
        this.shots.splice(i, 1);
        this.burst(s.x, s.y);
        if (c.kind === 'rocket') R.combat.explosion(s.x, s.y + 6, c.r, c.dmg, pl, false, true);
        if (c.kind === 'douse') { g.env.douse(s.x, s.y + 6, TS * 3, 6); for (let k = 0; k < 8; k++) g.fx.add({ x: s.x, y: s.y, vx: (R.rng() - 0.5) * 100, vy: -40 - R.rng() * 50, g: 200, life: 0.6, max: 0.6, c: '#9ad0f0', s: 2 }); }
      }
    }
    for (let i = this.drops.length - 1; i >= 0; i--) {
      const d = this.drops[i], c = LIB[d.k];
      d.t += dt;
      if (d.t >= d.fall) {
        this.drops.splice(i, 1);
        g.cam.shake(5);
        g.audio.sfx('thud', d.x, d.y);
        g.fx.text(d.x, d.y - 20, d.k === 'piano' ? 'PLONNNG!' : 'KA-THUNK!', pal().hi);
        this.burst(d.x, d.y - 6);
        for (const a of g.actors.near(d.x, d.y, c.r + 4)) if (!a.dead && !a.inCar && !(a.fearman && !a.fearFight)) this.hit(d.k, a, d.x, d.y, -Math.PI / 2);
        const v = g.traffic.nearestCar(d.x, d.y, c.r + 6);
        if (v && !v.wrecked) g.traffic.damage(v, c.dmg * 1.5, pl);
      }
    }
    for (let i = this.swings.length - 1; i >= 0; i--) if ((this.swings[i].t += dt) > 0.28) this.swings.splice(i, 1);
  };

  // B with the ring equipped: a fast bolt of yellow light from the ring hand
  Ring.blast = function (pl) {
    const g = this.game;
    if (pl.atkT > 0) return;
    if (!this.spend(3)) return;
    pl.atkT = D.weapons.ring.rate;
    const { tg, ang } = this.aim();
    pl.ang = ang;
    pl.dir = R.dir4(Math.cos(ang), Math.sin(ang));
    const [hx, hy] = R.art.handPos(pl, 'g');
    let a = ang;
    if (tg) a = Math.atan2(tg.y - 10 - hy, tg.x - hx);
    this.shots.push({ k: 'bolt', bolt: true, x: hx, y: hy, vx: Math.cos(a) * 420, vy: Math.sin(a) * 420, t: 0, life: 0.55, rot: a, hits: new Set() });
    g.fx.flash(hx, hy);
    g.audio.sfx('coolOn', pl.x, pl.y);
    g.actors.noise(pl.x, pl.y, TS * 8, 'fight', pl);
  };
  Ring.hit = function (k, a, x, y, ang) {
    const g = this.game, pl = g.player, c = LIB[k];
    if (c.dmg) R.combat.damage(a, c.dmg, pl, 'melee');
    g.fx.text(a.x, a.y - 24, R.rng.pick(['WHAM!', 'POW!', 'KRAKK!', 'BLAM!']), pal().hi);
    g.cam.shake(2.5);
    if (a.kind !== 'h' || a.dead) return;
    if (c.kind === 'trap') {
      a.state = 'surrender'; a.timer = c.hold; a.caged = { k, t: c.hold }; a.hostile = false;
      g.actors.say(a, R.rng.pick(['Hey! Let me out!', 'What IS this?!', 'I can\'t move!']));
    } else if (c.kind === 'spring') {
      g.actors.moveActor(a, Math.cos(ang) * 900, Math.sin(ang) * 900, 0.1);
      a.down = Math.max(a.down, 3);
      g.fx.text(a.x, a.y - 30, 'BOING!', pal().hi);
    } else {
      g.actors.moveActor(a, Math.cos(ang) * 260, Math.sin(ang) * 260, 0.1);
      if (!a.dead) a.down = Math.max(a.down, c.dmg > 40 ? 3 : 1.5);
    }
    if (k === 'cake') g.actors.say(a, 'Is this... is this a CAKE made of LIGHT?');
    if (k === 'fish') g.actors.say(a, 'A glowing fish?!');
  };
  Ring.burst = function (x, y) {
    const g = this.game;
    for (let i = 0; i < 10; i++) g.fx.add({ x, y, vx: (R.rng() - 0.5) * 130, vy: (R.rng() - 0.5) * 130, life: 0.45, max: 0.45, c: R.rng() < 0.5 ? pal().hi : pal().mid, s: 2, glow: 1 });
  };

  // hold RING: a lance of yellow light
  Ring.fireBeam = function (dt) {
    const g = this.game, w = g.world, pl = g.player;
    if (!this.spend(32 * dt * (R.fearQuest && R.fearQuest.perk('duel') ? 0.5 : 1))) { this.beam = null; return; }
    const { ang } = this.aim();
    pl.ang = ang;
    pl.dir = R.dir4(Math.cos(ang), Math.sin(ang));
    const sx = pl.x + Math.cos(ang) * 8, sy = pl.y - 10 + Math.sin(ang) * 5;
    let ex = sx, ey = sy, hitA = null;
    for (let d = 4; d < 230; d += 3) {
      const x = sx + Math.cos(ang) * d, y = sy + Math.sin(ang) * d;
      ex = x; ey = y;
      const tt = w.t((x / TS) | 0, ((y + 8) / TS) | 0);
      if (tt === T.BLDG || tt === T.WALL || tt === T.VOID || tt === T.ROCK) { const b = w.buildingAt((x / TS) | 0, ((y + 8) / TS) | 0); if (b) g.env.damageBuilding(b, 12 * dt, pl); break; }
      if (R.fearQuest.hitTest(x, y, 130 * dt)) { ex = x; ey = y; break; }
      const a = g.actors.near(x, y + 8, 12).find((q) => !q.dead && !q.inCar && !(q.fearman && !q.fearFight) && Math.hypot(q.x - x, q.y - 8 - y) < 8);
      if (a) { hitA = a; break; }
      const v = g.traffic.nearestCar(x, y + 6, 10);
      if (v && !v.wrecked && v !== pl.inCar) { g.traffic.damage(v, 60 * dt, pl); v.vx += Math.cos(ang) * 200 * dt; v.vy += Math.sin(ang) * 200 * dt; break; }
    }
    if (hitA) {
      R.combat.damage(hitA, 130 * dt, pl, 'bullet');
      g.actors.moveActor(hitA, Math.cos(ang) * 60, Math.sin(ang) * 60, dt);
    }
    if (R.rng() < 0.5) this.burst(ex, ey);
    if (!this.beam) g.audio.sfx('coolOn', pl.x, pl.y);
    this.beam = { sx, sy, ex, ey, t: g.clock.real };
    if (R.rng() < dt * 4) g.actors.noise(pl.x, pl.y, TS * 12, 'gunshot', pl);
  };

  // bare fists with the ring on: every punch is something enormous
  Ring.canSwing = function (pl) { return this.owned() && pl.weapon === 'fists' && !pl.held && !pl.inCar && pl.will >= 4; };
  Ring.swing = function (pl) {
    const g = this.game;
    if (pl.atkT > 0) return;
    pl.atkT = 0.42;
    pl.will -= 4;
    pl.punchT = 0.22;
    pl.punchN = (pl.punchN || 0) + 1;
    const k = R.rng.pick(SWING_SET);
    const { tg, ang } = this.aim();
    pl.ang = ang;
    this.swings.push({ k, ang, t: 0, side: pl.punchN % 2 ? 1 : -1 });
    g.audio.sfx('swing', pl.x, pl.y);
    let n = 0;
    for (const a of g.actors.near(pl.x, pl.y, 40)) {
      if (a.dead || a.inCar || (a.fearman && !a.fearFight)) continue;
      const d = Math.hypot(a.x - pl.x, a.y - pl.y);
      if (d > 36 || Math.abs(R.angDiff(ang, Math.atan2(a.y - pl.y, a.x - pl.x))) > 1.3) continue;
      R.combat.damage(a, 34 + R.rng() * 12, pl, 'melee');
      if (a.kind === 'h' && !a.dead) { g.actors.moveActor(a, Math.cos(ang) * 320, Math.sin(ang) * 320, 0.1); a.down = Math.max(a.down, 2); }
      n++;
    }
    const v = g.traffic.nearestCar(pl.x + Math.cos(ang) * 22, pl.y + Math.sin(ang) * 22, 20);
    if (v && !v.wrecked) { g.traffic.damage(v, 25, pl); v.vx += Math.cos(ang) * 120; v.vy += Math.sin(ang) * 120; n++; }
    if (n) { g.cam.shake(3); g.fx.text(pl.x + Math.cos(ang) * 20, pl.y - 20, R.rng.pick(['WHAM!', 'KRAK!', 'SMAAASH!']), pal().hi); g.audio.sfx('thud', pl.x, pl.y); }
  };

  // ---------------------------------------------------------------- library UI
  Ring.openLibrary = function (summon) {
    const g = this.game, ui = g.ui;
    if (!this.owned()) return;
    const render = () => {
      const keys = Object.keys(LIB).filter((k) => this.cat === 'All' || LIB[k].cat === this.cat);
      const html = ui.header('Ring Library', `Picture it and it appears. WILL ${Math.round(g.player.will)}/100. Tap one to ready it.`) +
        `<div class="body"><div class="tabs lib">${CATS.map((c) => `<button data-cat="${c}" class="${c === this.cat ? 'sel' : ''}">${c}</button>`).join('')}</div>` +
        `<div class="libgrid">${keys.map((k) => `<button class="libi ${k === this.selected ? 'sel' : ''}" data-k="${k}"><canvas width="36" height="36"></canvas><span>${LIB[k].name}</span><small>${LIB[k].cost} WILL · ${LIB[k].kind === 'drop' ? 'from above' : LIB[k].kind}</small></button>`).join('')}</div></div>`;
      const s = ui.openSheet('ringlib', html);
      s.querySelectorAll('[data-cat]').forEach((b) => b.addEventListener('click', () => { this.cat = b.dataset.cat; render(); }));
      s.querySelectorAll('.libi').forEach((b) => {
        const cv = b.querySelector('canvas'), cg = cv.getContext('2d');
        cg.imageSmoothingEnabled = false;
        const sp = sprite(b.dataset.k);
        cg.drawImage(sp, (36 - sp.width * 2) / 2, (36 - sp.height * 2) / 2, sp.width * 2, sp.height * 2);
        b.addEventListener('click', () => {
          this.selected = b.dataset.k; g.audio.sfx('click'); ui.closeSheet();
          if (summon) this.conjure();
          else ui.toast(`${LIB[this.selected].name} ready. Tap RING to throw it.`);
        });
      });
    };
    render();
  };

  // ---------------------------------------------------------------- drawing
  Ring.draw = function (g) {
    const game = this.game, pl = game.player, t = game.clock.real;
    for (const d of this.drops) {
      const c = LIB[d.k], f = d.t / d.fall;
      g.fillStyle = `rgba(20,14,0,${0.2 + f * 0.35})`;
      g.beginPath(); g.ellipse(d.x, d.y, c.r * (0.4 + f * 0.6), c.r * 0.4 * (0.4 + f * 0.6), 0, 0, 7); g.fill();
      drawLit(g, sprite(d.k), d.x, d.y - 8 - (1 - f) * 140, 1.6, 0, 0.5 + f * 0.5);
    }
    for (const s of this.shots) {
      if (s.bolt) {
        const len = 10;
        const tx = s.x - Math.cos(s.rot) * len, ty = s.y - Math.sin(s.rot) * len;
        g.strokeStyle = GL() + '0.35)'; g.lineWidth = 5;
        g.beginPath(); g.moveTo(tx, ty); g.lineTo(s.x, s.y); g.stroke();
        g.strokeStyle = pal().core; g.lineWidth = 2;
        g.beginPath(); g.moveTo(tx, ty); g.lineTo(s.x, s.y); g.stroke();
        g.fillStyle = pal().light; g.fillRect(Math.round(s.x) - 1, Math.round(s.y) - 1, 2, 2);
        continue;
      }
      const c = LIB[s.k];
      g.fillStyle = 'rgba(20,14,0,0.25)';
      g.fillRect(Math.round(s.x) - 4, Math.round(s.y) + 8, 8, 2);
      const rot = c.kind === 'rocket' || c.kind === 'shark' ? Math.atan2(s.vy, s.vx) : s.rot;
      drawLit(g, sprite(s.k), s.x, s.y, c.cat === 'Heavy' ? 1.4 : 1.1, rot);
    }
    // caged / netted people
    for (const a of game.actors.list) {
      if (!a.caged) continue;
      a.caged.t -= 1 / 60;
      if (a.caged.t <= 0 || a.dead) { a.caged = null; continue; }
      drawLit(g, sprite(a.caged.k), a.x, a.y - 10, 1.6, 0, 0.75);
    }
    if (pl.shieldT > 0) {
      g.strokeStyle = GL() + (0.5 + Math.sin(t * 8) * 0.2) + ')';
      g.lineWidth = 2;
      g.beginPath(); g.ellipse(pl.x, pl.y - 10, 14, 18, 0, 0, 7); g.stroke();
    }
    if (this.beam && game.clock.real - this.beam.t < 0.1) {
      const b = this.beam;
      const wob = Math.sin(t * 40);
      g.strokeStyle = GL() + '0.35)'; g.lineWidth = 7 + wob;
      g.beginPath(); g.moveTo(b.sx, b.sy); g.lineTo(b.ex, b.ey); g.stroke();
      g.strokeStyle = pal().core; g.lineWidth = 3;
      g.beginPath(); g.moveTo(b.sx, b.sy); g.lineTo(b.ex, b.ey); g.stroke();
      g.strokeStyle = pal().light; g.lineWidth = 1;
      g.beginPath(); g.moveTo(b.sx, b.sy); g.lineTo(b.ex, b.ey); g.stroke();
    }
  };
  // the swing arc, drawn over the player
  Ring.drawSwing = function (g, pl) {
    for (const s of this.swings) {
      const f = s.t / 0.28;
      const a = s.ang + s.side * (-1.3 + f * 2.6);
      const r = 20;
      drawLit(g, sprite(s.k), pl.x + Math.cos(a) * r, pl.y - 10 + Math.sin(a) * r * 0.7, 2, a + Math.PI / 2, 1 - f * 0.3);
    }
    if (this.owned() && !pl.inCar) {
      // the ring hand glows
      const pose = pl.weapon === 'ring' && pl.weaponOut ? 'g' : pl._pose || null;
      const [hx, hy, hidden] = R.art.handPos(pl, pose);
      if (hidden) return;
      const t = this.game.clock.real, bright = pl.weapon === 'ring' && pl.weaponOut ? 1 : 0.6;
      g.fillStyle = GL() + (0.18 + Math.sin(t * 4) * 0.06) * bright + ')';
      g.beginPath(); g.arc(hx, hy, 4 + bright, 0, 7); g.fill();
      g.fillStyle = GL() + 0.55 * bright + ')';
      g.fillRect(Math.round(hx) - 1, Math.round(hy) - 1, 3, 3);
      g.fillStyle = pal().hi;
      g.fillRect(Math.round(hx), Math.round(hy), 1, 1);
    }
  };
})();
