// RHAPSODY — break things, find things. Street furniture takes a beating before it gives:
// kick in a phone booth for its coin box, pry a mailbox for birthday cash, bust a crate open,
// dig through the trash. The city sends crews to fix what you broke. And past the edge of
// every town there's something worth the drive: eight landmarks with a story and a reward,
// and three dozen cash tins hidden in alleys and weeds for anyone who looks.
'use strict';
(function () {
  const D = R.data, O = D.O, TS = R.TILE;
  const G = () => R.game;
  const SV = (R.salvage = { hp: new Map(), broken: [] });

  // ---------------------------------------------------------------- smashing
  // hp: damage it takes; loot: what falls out; crime: counts as vandalism when seen in town
  const SMASH = {
    [O.TRASH]: { hp: 14, name: 'trash can', loot: 'trash', mat: 'metal' },
    [O.MAILBOX]: { hp: 26, name: 'mailbox', loot: 'mail', mat: 'metal', crime: 1 },
    [O.PHONE]: { hp: 44, name: 'phone booth', loot: 'coins', mat: 'glass', crime: 1 },
    [O.CRATE]: { hp: 20, name: 'crate', loot: 'crate', mat: 'wood' },
    [O.BENCH]: { hp: 30, name: 'bench', mat: 'wood' },
    [O.SIGNPOST]: { hp: 22, name: 'sign', mat: 'metal', crime: 1 },
    [O.CONE]: { hp: 4, name: 'cone', mat: 'soft' },
    [O.FENCE]: { hp: 16, name: 'fence', mat: 'wood' },
    [O.LAMP]: { hp: 34, name: 'lamp post', mat: 'glass', crime: 1 },
    [O.HYDRANT]: { hp: 48, name: 'hydrant', mat: 'metal', crime: 1 },
    [O.FLOWERS]: { hp: 3, name: 'flower bed', mat: 'soft' },
  };
  const LOOT = {
    trash: () => R.rng.weighted([[null, 5], [{ cash: R.rng.int(1, 6) }, 3], [{ cons: 'sandwich', say: 'a half-eaten sandwich' }, 2], [{ loot: 'eight' }, 1.5], [{ cons: 'smokes', say: 'a crushed pack of smokes' }, 1.5], [{ loot: 'radio', say: 'a radio that still works' }, 0.6], [{ weapon: 'revolver', say: 'a .38 somebody ditched' }, 0.25]]),
    mail: () => R.rng.weighted([[{ cash: R.rng.int(5, 25), say: 'a birthday card with cash in it' }, 4], [{ cash: R.rng.int(20, 60), say: 'a Social Security check you cash at a discount' }, 1.5], [{ loot: 'bonds', say: 'a registered envelope of bearer bonds' }, 0.25], [{ rumor: 1 }, 2], [null, 2]]),
    coins: () => ({ cash: R.rng.int(4, 18), say: 'the coin box' }),
    crate: () => R.rng.weighted([[{ ammo: 12 }, 2], [{ cons: 'bandage' }, 2], [{ cons: 'whiskey' }, 2], [{ loot: 'radio' }, 1], [{ loot: 'tv' }, 0.6], [{ cash: R.rng.int(10, 50) }, 1.5], [null, 1.5]]),
  };
  SV.give = function (r, from) {
    const g = G(), pl = g.player;
    if (!r) { g.fx.text(pl.x, pl.y - 24, 'nothing', '#b0a080'); return null; }
    let what = r.say;
    if (r.cash) { pl.addCash(r.cash); what = what || R.fmtMoney(r.cash); }
    if (r.cons) { pl.inv.cons[r.cons] = (pl.inv.cons[r.cons] || 0) + 1; what = what || D.consumables[r.cons].name; }
    if (r.loot) { pl.inv.loot[r.loot] = (pl.inv.loot[r.loot] || 0) + (r.n || 1); what = what || D.loot[r.loot].name; }
    if (r.ammo) { pl.inv.ammo.pistol += r.ammo; what = what || `${r.ammo} rounds`; }
    if (r.weapon) { pl.giveWeapon(r.weapon); what = what || D.weapons[r.weapon].name; }
    if (r.rumor) { const t = R.dialog.rumor({ x: pl.x, y: pl.y, tr: { chatty: 1 } }); g.ui.toast(`A letter, not meant for you: "${t}"`); return 'a letter'; }
    g.ui.toast(`${from ? from + ': ' : ''}${what}.`, 'good');
    g.audio.sfx('loot');
    return what;
  };
  // hit whatever is in front of you
  SV.strike = function (att, w, ang) {
    const g = G(), wd = g.world;
    const ox = att.x + Math.cos(ang) * 10, oy = att.y - 2 + Math.sin(ang) * 10;
    let best = null, bd = 13;
    for (let yy = ((oy / TS) | 0) - 1; yy <= ((oy / TS) | 0) + 1; yy++)
      for (let xx = ((ox / TS) | 0) - 1; xx <= ((ox / TS) | 0) + 1; xx++) {
        const o = wd.o(xx, yy);
        if (!SMASH[o] || yy >= wd.H) continue;
        const d = R.dist(ox, oy, xx * TS + 8, yy * TS + 8);
        if (d < bd) { bd = d; best = { x: xx, y: yy, o }; }
      }
    if (!best) return false;
    const s = SMASH[best.o], key = best.y * wd.W + best.x, cx = best.x * TS + 8, cy = best.y * TS + 8;
    const dmg = w.dmg * (att.power || 1) * (w === D.weapons.fists ? 0.6 : 1);
    const left = (this.hp.has(key) ? this.hp.get(key) : s.hp) - dmg;
    g.fx.sparks(cx, cy - 4, s.mat === 'metal' ? 3 : 0);
    if (s.mat === 'wood' || s.mat === 'soft') g.fx.debris(cx, cy, best.o === O.FLOWERS ? O.FLOWERS : O.CRATE);
    g.cam.shake(1);
    g.hitStop = Math.max(g.hitStop || 0, 0.025);
    if (left > 0) {
      this.hp.set(key, left);
      g.audio.sfx(s.mat === 'glass' ? 'bump' : s.mat === 'wood' ? 'thud' : 'bump', cx, cy);
      g.fx.text(cx, cy - 16, s.mat === 'wood' ? 'CRACK' : s.mat === 'soft' ? 'FWUMP' : 'CLANG', '#f2e2c0');
      return true;
    }
    this.hp.delete(key);
    this.breakObj(best.x, best.y, best.o, att);
    return true;
  };
  SV.breakObj = function (x, y, o, att) {
    const g = G(), wd = g.world, s = SMASH[o], cx = x * TS + 8, cy = y * TS + 8, pl = g.player;
    if (o === O.LAMP) g.env.shootLamp(x, y);
    else { wd.setO(x, y, 0); g.fx.debris(cx, cy, o); }
    if (o === O.PHONE || o === O.LAMP) g.fx.shatter(cx, cy - 8);
    if (o === O.HYDRANT) g.env.geyser(cx, cy);
    if (o === O.PHONE) { const i = wd.phones ? wd.phones.findIndex((p) => p.x === x && p.y === y) : -1; if (i >= 0) wd.phones.splice(i, 1); }
    g.audio.sfx(s.mat === 'glass' ? 'glass' : 'crash', cx, cy);
    g.fx.text(cx, cy - 18, s.mat === 'glass' ? 'SMASH!' : s.mat === 'wood' ? 'CRUNCH!' : 'KRANG!', '#ffd070');
    if (att === pl) {
      pl.stats.smashed = (pl.stats.smashed || 0) + 1;
      if (s.loot) this.give(LOOT[s.loot](), `The ${s.name}`);
      if (s.crime && wd.cityAt(x, y)) g.law.crime('vandalism', cx, cy, { minor: true });
      g.actors.noise(cx, cy, TS * 8, 'crash', pl);
    }
  };

  // city crews put things back. Anything street-side that goes missing is logged here.
  const FIX = new Set([O.LAMP, O.HYDRANT, O.PHONE, O.BENCH, O.TRASH, O.MAILBOX, O.FENCE, O.SIGNPOST, O.CONE]);
  SV.watchWorld = function (w) {
    if (w._svWrapped) return;
    w._svWrapped = true;
    const base = w.setO;
    w.setO = function (x, y, o) {
      const was = this.o(x, y);
      if (!o && FIX.has(was) && y < this.H && G().pop) SV.broken.push({ x, y, o: was, day: G().pop.day });
      return base.call(this, x, y, o);
    };
  };
  SV.daily = function () {
    const g = G(), pl = g.player, w = g.world, day = g.pop.day;
    let n = 0;
    this.broken = this.broken.filter((b) => {
      if (day - b.day < 2) return true;
      if (Math.hypot(pl.x / TS - b.x, pl.y / TS - b.y) < 30) return true;
      if (w.o(b.x, b.y) || w.solidPed(b.x, b.y) && b.o !== O.FENCE) return false;
      w.obj[b.y * w.W + b.x] = b.o; w.markDirty(b.x, b.y);
      if (b.o === O.PHONE && w.phones) w.phones.push({ x: b.x, y: b.y });
      n++;
      return false;
    });
    if (n > 8) g.pop.addNews(R.rng.pick(g.world.cities).id, `City crews worked overtime this week replacing ${n} lamp posts, benches and phone booths. "Hooligans," says the mayor.`);
  };

  // ---------------------------------------------------------------- landmarks
  const PLACES = [
    { id: 'wreck', name: 'The Smuggler\'s Wreck', fam: 'Vane', ang: 0.6, dist: 16, water: true, art: 'boat',
      text: 'A rum-runner\'s launch, driven onto the rocks years ago. The hull is split, but the false bottom is still nailed shut.',
      reward: { cash: 400, weapon: 'shotgun', ammo: 12 }, hint: 'Out past the lighthouse there\'s a smuggler\'s boat on the rocks. Nobody ever found the money.' },
    { id: 'limo', name: 'The Burnt Limousine', fam: 'Castellano', ang: -0.7, dist: 14, art: 'limo',
      text: 'Somebody torched a Castellano limo in a ditch outside town and nobody ever towed it. The trunk is welded shut by the heat. Almost.',
      reward: { cash: 600, loot: 'chain' }, hint: 'There\'s a burnt-out limo in a ditch outside New Avalon. Belonged to a made guy. Nobody touches it.' },
    { id: 'plane', name: 'The Crashed Beechcraft', fam: 'Reyes', ang: 0.8, dist: 24, art: 'plane',
      text: 'A twin-engine plane, belly-down in the sand. The pilot walked away, or didn\'t. The cargo hold is full of burlap.',
      reward: { cash: 350, weapon: 'rifle', ammo: 10 }, hint: 'A drug plane went down in the Dustwater flats last spring. The cargo was never recovered.' },
    { id: 'circle', name: 'The Scorched Circle', fam: 'Reyes', ang: -0.9, dist: 30, art: 'circle',
      text: 'A perfect ring of glassed sand, forty feet across. Your watch stops while you stand in it. Something small and silver is buried at the center.',
      reward: { cash: 200, loot: 'silver', hp: 5 }, hint: 'There\'s a burned ring in the desert east of Dustwater. Perfect circle. Cows won\'t go near it.' },
    { id: 'camp', name: 'Hunter\'s Camp', fam: "O'Malley", ang: 0.5, dist: 14, art: 'camp',
      text: 'A canvas tent and a fire still warm. The hunter hasn\'t been back in days. His gear is still here.',
      reward: { cash: 150, loot: 'pelt_bear', cons: 'whiskey', ammo: 8 }, hint: 'Some hunter\'s been camping in the woods past Pinecrest for a month. Big bear pelt drying on a line.' },
    { id: 'still', name: 'The Hermit\'s Still', fam: "O'Malley", ang: -0.8, dist: 22, art: 'still',
      text: 'A copper moonshine still, hidden in the pines and humming along with nobody watching it. There\'s a coffee can buried under the barrel.',
      reward: { cash: 250, cons: 'whiskey', n: 3 }, hint: 'Old Jeb runs a still somewhere up in the pines. Buries his money in coffee cans, the fool.' },
    { id: 'altar', name: 'The Candle Ring', fam: 'Thibodeaux', ang: 0.7, dist: 16, art: 'altar',
      text: 'Black candles in a ring around a cypress stump, still burning. Offerings of coins and rings. The spirits won\'t miss a few. Probably.',
      reward: { cash: 180, loot: 'ring', cons: 'tonic' }, hint: 'Out in the marsh there\'s a ring of candles that never burn down. People leave rings there. Real ones.' },
    { id: 'pirogue', name: 'The Sunken Pirogue', fam: 'Thibodeaux', ang: -0.6, dist: 12, water: true, art: 'pirogue',
      text: 'A dugout canoe, half-sunk at the water\'s edge with a tackle box still wedged under the seat.',
      reward: { cash: 300, loot: 'jewels' }, hint: 'Fisherman drowned in the bayou last year. His canoe\'s still out there. Folks say he was smuggling jewels.' },
  ];
  SV.PLACES = PLACES;
  const walkable = (w, x, y) => w.inb(x, y) && !w.solidPed(x, y) && !w.isWater(x, y) && !w.o(x, y) && !w.cityAt(x, y) && !D.roadTile[w.t(x, y)];
  SV.placeAll = function () {
    const g = G(), w = g.world;
    for (const P of PLACES) {
      const c = g.jobs.cityOfFamily(P.fam);
      if (!c) { P.at = null; continue; }
      let dx = c.cx - w.W / 2, dy = c.cy - w.H / 2; const l = Math.hypot(dx, dy) || 1; dx /= l; dy /= l;
      const half = Math.max(c.x1 - c.x0, c.y1 - c.y0) / 2;
      // needs a 5x3 clearing (brush gets cleared), next to water for the boats
      const open = (x, y) => w.inb(x, y) && !w.isWater(x, y) && !w.cityAt(x, y) && !D.roadTile[w.t(x, y)] && !w.buildingAt(x, y) && (!w.solidPed(x, y) || [O.TREE, O.PINE, O.BOULDER, O.CACTUS, O.DEADTREE, O.PALM].includes(w.o(x, y)));
      const clear = (x, y) => { for (let yy = -1; yy <= 1; yy++) for (let xx = -2; xx <= 2; xx++) if (!open(x + xx, y + yy)) return false; return true; };
      const wet = (x, y) => { for (let yy = -4; yy <= 4; yy++) for (let xx = -5; xx <= 5; xx++) if (w.isWater(x + xx, y + yy)) return true; return false; };
      let s = null;
      for (const pass of [0, 1]) for (const off of [0, 0.7, -0.7, 1.5, -1.5, 2.4, -2.4, 3.1]) {
        if (s) break;
        const a = Math.atan2(dy, dx) + P.ang + off;
        const tx = R.clamp(Math.round(c.cx + Math.cos(a) * (half + P.dist)), 8, w.W - 9), ty = R.clamp(Math.round(c.cy + Math.sin(a) * (half + P.dist)), 8, w.H - 9);
        s = w.findNear(tx, ty, 0, 24, (x, y) => clear(x, y) && (pass || !P.water || wet(x, y)));
      }
      if (s) for (let yy = -1; yy <= 1; yy++) for (let xx = -2; xx <= 2; xx++) if (w.o(s.x + xx, s.y + yy)) { w.obj[(s.y + yy) * w.W + s.x + xx] = 0; w.markDirty(s.x + xx, s.y + yy); }
      P.at = s ? { x: s.x, y: s.y } : null;
    }
  };

  // ---------------------------------------------------------------- hidden cash tins
  SV.placeTins = function () {
    const g = G(), w = g.world, rnd = R.mulberry(w.seed + 911);
    const tins = [];
    const hidey = (x, y) => {
      if (!w.inb(x, y) || w.solidPed(x, y) || w.isWater(x, y) || D.roadTile[w.t(x, y)] || w.o(x, y)) return false;
      // tucked against a wall, a bush or a tree
      for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const o = w.o(x + dx, y + dy); if (w.buildingAt(x + dx, y + dy) || o === O.BUSH || o === O.TREE || o === O.PINE || o === O.BOULDER || o === O.FENCE || o === O.REED) return true; }
      return false;
    };
    for (const c of w.cities) {
      for (let k = 0; k < 5; k++) {
        for (let tries = 0; tries < 40; tries++) {
          const x = Math.round(c.x0 + rnd() * (c.x1 - c.x0)), y = Math.round(c.y0 + rnd() * (c.y1 - c.y0));
          if (hidey(x, y) && !tins.some((t) => Math.abs(t.x - x) + Math.abs(t.y - y) < 10)) { tins.push({ x, y, v: 20 + Math.round(rnd() * 60) }); break; }
        }
      }
    }
    // and out in the wild
    for (let tries = 0; tries < 600 && tins.length < 36; tries++) {
      const x = 10 + Math.round(rnd() * (w.W - 20)), y = 10 + Math.round(rnd() * (w.H - 20));
      if (w.cityAt(x, y) || !hidey(x, y) || tins.some((t) => Math.abs(t.x - x) + Math.abs(t.y - y) < 24)) continue;
      tins.push({ x, y, v: 40 + Math.round(rnd() * 110) });
    }
    this.tins = tins;
  };
  const MILESTONES = {
    5: ['Pack Rat', 'Five tins. You\'re starting to see hiding places everywhere.', { cash: 250 }],
    10: ['Magpie', 'Ten tins. Your eye for a loose brick is uncanny: tins now glint from much farther away, and show on your minimap.', { cash: 400 }],
    20: ['Treasure Hunter', 'Twenty tins. Somebody\'s old army canteen was in that last one. You feel tougher.', { cash: 800, hp: 10 }],
    30: ['King of the Junkyard', 'Thirty tins. You could retire. You won\'t.', { cash: 1500 }],
    36: ['Every Last Tin', 'Every tin on the coast. Some of them were probably yours.', { cash: 5000 }],
  };

  // ---------------------------------------------------------------- state
  SV.state = function () { const pl = G().player; return (pl.explore = pl.explore || { tins: [], places: [], looted: [] }); };
  SV.init = function (g) {
    this.hp = new Map(); this.broken = [];
    this.watchWorld(g.world);
    this.placeAll(); this.placeTins();
    if (this.wrapped) return;
    this.wrapped = true;
    const PP = R.Player.prototype, baseCtx = PP.contextAction;
    PP.contextAction = function () { return SV.context(this) || baseCtx.call(this); };
    const J = R.Jobs.prototype, jd = J.daily;
    J.daily = function () { jd.call(this); SV.daily(); };
  };
  // melee on the world
  const C = R.combat, baseMelee = C.melee;
  C.melee = function (att, w, ang) {
    const hit = baseMelee.call(this, att, w, ang);
    const g = G();
    if (!hit && att === g.player && !att.room && !(g.traffic.nearestCar(att.x + Math.cos(ang) * 8, att.y - 6 + Math.sin(ang) * 8, 14))) SV.strike(att, w, ang);
    return hit;
  };
  // gossip points at places you haven't found
  const D2 = R.dialog, baseRumor = D2.rumor;
  D2.rumor = function (h) {
    const g = G();
    if (g && g.player && R.rng() < 0.2) {
      const s = SV.state(), left = PLACES.filter((p) => p.at && !s.places.includes(p.id));
      if (left.length) { const p = R.rng.pick(left); if (!s.heard) s.heard = []; if (!s.heard.includes(p.id)) s.heard.push(p.id); return p.hint; }
    }
    return baseRumor.call(this, h);
  };

  SV.update = function (dt) {
    const g = G(), pl = g.player, s = this.state();
    if (pl.room || pl.dead) return;
    const px = pl.x / TS, py = pl.y / TS;
    // discover landmarks
    for (const P of PLACES) {
      if (!P.at || s.places.includes(P.id)) continue;
      if (Math.hypot(px - P.at.x, py - P.at.y) < 6) {
        s.places.push(P.id);
        pl.addCash(50);
        g.audio.sfx('promote');
        g.ui.toast(`Discovered: ${P.name}. ${s.places.length}/${PLACES.length} places found.`, 'good');
        g.fx.text(P.at.x * TS + 8, P.at.y * TS - 20, 'DISCOVERED', '#ffd070');
      }
    }
    // pick up tins by walking over them
    if (!pl.inCar && this.tins) {
      for (let i = 0; i < this.tins.length; i++) {
        const t = this.tins[i];
        if (s.tins.includes(i) || Math.abs(px - t.x - 0.5) > 0.8 || Math.abs(py - t.y - 0.6) > 0.8) continue;
        s.tins.push(i);
        pl.addCash(t.v);
        g.audio.sfx('cash');
        const n = s.tins.length;
        g.ui.toast(`A rusty tobacco tin, hidden ${R.rng.pick(['under a loose brick', 'behind a drainpipe', 'in the weeds', 'under a rock', 'in a hollow'])}: ${R.fmtMoney(t.v)}. (${n}/${this.tins.length})`, 'good');
        const m = MILESTONES[n] || (n === this.tins.length && MILESTONES[36]);
        if (m) { if (m[2].cash) pl.addCash(m[2].cash); if (m[2].hp) { pl.maxHp += m[2].hp; pl.hp = pl.maxHp; } setTimeout(() => g.ui.story(m[0].toUpperCase(), `${m[1]}\n\n+${R.fmtMoney(m[2].cash)}${m[2].hp ? `, +${m[2].hp} max health` : ''}`), 600); }
      }
    }
    // the plane still smokes a little
    const pp = PLACES[2];
    if (pp.at && R.rng() < dt * 2 && Math.hypot(px - pp.at.x, py - pp.at.y) < 20) g.fx.smoke(pp.at.x * TS + 18, pp.at.y * TS - 2, true);
  };
  SV.context = function (pl) {
    const s = this.state();
    if (pl.room || pl.inCar) return null;
    for (const P of PLACES) {
      if (!P.at || s.looted.includes(P.id) || !s.places.includes(P.id)) continue;
      const sx = P.at.x + (P.spot || 1.5), sy = P.at.y + 0.5;
      if (Math.hypot(pl.x / TS - sx, pl.y / TS - sy) > 2.2) continue;
      return { label: `Search ${P.name.replace(/^The /, 'the ')}`, fn: () => {
        const g = G();
        s.looted.push(P.id);
        g.ui.story(P.name.toUpperCase(), P.text);
        const r = P.reward;
        this.give({ cash: r.cash, weapon: r.weapon, loot: r.loot, cons: r.cons, n: r.n, ammo: r.ammo, say: [r.cash && R.fmtMoney(r.cash), r.weapon && D.weapons[r.weapon].name, r.loot && D.loot[r.loot].name, r.cons && ((r.n || 1) > 1 ? `${r.n} × ` : '') + D.consumables[r.cons].name].filter(Boolean).join(', ') }, 'Found');
        if (r.cons && r.n > 1) pl.inv.cons[r.cons] += r.n - 1;
        if (r.hp) { pl.maxHp += r.hp; pl.hp = pl.maxHp; }
      } };
    }
    return null;
  };
  SV.jobsHtml = function (esc) {
    const s = this.state();
    let h = '<div class="sect">Off the map</div>';
    h += `<p>Places found: <b>${s.places.length}/${PLACES.length}</b> · cash tins: <b>${s.tins.length}/${(this.tins || []).length}</b> · things smashed: ${G().player.stats.smashed || 0}</p>`;
    for (const P of PLACES) {
      const f = s.places.includes(P.id), heard = (s.heard || []).includes(P.id);
      if (f) h += `<p>• <b>${esc(P.name)}</b>${s.looted.includes(P.id) ? ' ✓' : ' (not searched yet)'}</p>`;
      else if (heard) h += `<p>• <i>Rumor:</i> ${esc(P.hint)}</p>`;
    }
    const unheard = PLACES.filter((P) => !s.places.includes(P.id) && !(s.heard || []).includes(P.id)).length;
    if (unheard) h += `<p><small>${unheard} more place${unheard > 1 ? 's' : ''} out there. Locals love to gossip.</small></p>`;
    return h;
  };
  const baseJobs = R.campaign.jobsHtml;
  R.campaign.jobsHtml = function () {
    const esc = (x) => String(x).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
    return baseJobs.call(this) + SV.jobsHtml(esc);
  };

  // ---------------------------------------------------------------- map
  const RT = R.route, baseFull = RT.drawFull, baseMini = RT.drawMini;
  RT.drawFull = function (c) {
    baseFull.call(this, c);
    const s = SV.state();
    for (const P of PLACES) {
      if (!P.at) continue;
      const f = s.places.includes(P.id), heard = (s.heard || []).includes(P.id);
      if (!f && !heard) continue;
      const x = P.at.x, y = P.at.y;
      c.fillStyle = '#1b1410'; c.beginPath(); c.arc(x, y, 8, 0, 7); c.fill();
      c.fillStyle = f ? (s.looted.includes(P.id) ? '#8a7a5a' : '#f0c040') : '#b0a080';
      c.beginPath(); c.arc(x, y, 6, 0, 7); c.fill();
      c.fillStyle = '#1b1410'; c.font = 'bold 10px "Barlow Condensed", sans-serif'; c.textAlign = 'center'; c.fillText(f ? '★' : '?', x, y + 4);
      if (f) { c.font = '11px "Barlow Condensed", sans-serif'; c.fillStyle = '#1b1410'; c.fillText(P.name, x, y - 11); }
    }
  };
  RT.drawMini = function (c, toM) {
    baseMini.call(this, c, toM);
    const s = SV.state();
    if (s.tins.length < 10 || !SV.tins) return;
    const t = performance.now() / 300;
    SV.tins.forEach((tin, i) => {
      if (s.tins.includes(i)) return;
      const [x, y] = toM(tin.x * TS + 8, tin.y * TS + 8);
      c.fillStyle = `rgba(255,230,140,${0.6 + Math.sin(t + i) * 0.3})`; c.fillRect(x - 1.5, y - 1.5, 3, 3);
    });
  };

  // ---------------------------------------------------------------- drawing
  const OUT = '#140e10';
  const rect = (g, c, x, y, w, h) => { g.fillStyle = c; g.fillRect(x, y, w, h); };
  const ART = {
    boat(g, x, y) {
      g.fillStyle = 'rgba(0,0,0,0.25)'; g.beginPath(); g.ellipse(x + 16, y + 10, 24, 6, 0, 0, 7); g.fill();
      // split hull lying on its side
      rect(g, OUT, x - 6, y - 2, 42, 12);
      rect(g, '#5a3a1c', x - 5, y - 1, 40, 10); rect(g, '#7c5228', x - 5, y - 1, 40, 3); rect(g, '#a06c38', x - 3, y - 1, 34, 1);
      for (let k = 0; k < 5; k++) rect(g, '#3a2410', x - 1 + k * 8, y + 2, 1, 7);
      rect(g, '#e8e0c8', x - 5, y + 5, 40, 2); rect(g, '#c83a1a', x - 5, y + 7, 40, 1);
      rect(g, OUT, x + 12, y - 1, 3, 11); rect(g, '#2a3a44', x + 13, y, 1, 9); // the split
      rect(g, OUT, x + 26, y - 14, 3, 13); rect(g, '#7c5228', x + 27, y - 13, 1, 12); // broken mast
      rect(g, '#b0a080', x + 29, y - 12, 6, 5); rect(g, '#8a7a5a', x + 29, y - 8, 6, 1);
    },
    limo(g, x, y) {
      g.fillStyle = 'rgba(0,0,0,0.3)'; g.beginPath(); g.ellipse(x + 16, y + 8, 26, 6, 0, 0, 7); g.fill();
      rect(g, OUT, x - 8, y - 6, 48, 14);
      rect(g, '#2a2420', x - 7, y - 5, 46, 12); rect(g, '#4a3a30', x - 7, y - 5, 46, 2);
      rect(g, '#6a4020', x + 2, y - 3, 6, 3); rect(g, '#8a5028', x + 20, y + 2, 9, 2); rect(g, '#6a4020', x + 33, y - 3, 4, 4); // rust
      rect(g, '#101010', x + 5, y - 5, 26, 4); rect(g, '#3a3a3a', x + 12, y - 5, 1, 4); rect(g, '#3a3a3a', x + 20, y - 5, 1, 4);
      for (const wx of [x - 3, x + 30]) { rect(g, OUT, wx, y + 5, 6, 4); rect(g, '#3a3a3a', wx + 1, y + 6, 4, 2); }
      rect(g, '#8a8a8a', x - 8, y - 1, 2, 3); rect(g, '#8a8a8a', x + 38, y - 1, 2, 3);
    },
    plane(g, x, y) {
      g.fillStyle = 'rgba(20,16,14,0.35)'; g.beginPath(); g.ellipse(x + 18, y + 8, 34, 9, 0, 0, 7); g.fill();
      // broken wing, then fuselage
      rect(g, OUT, x - 10, y - 2, 30, 7); rect(g, '#9a9e9e', x - 9, y - 1, 28, 5); rect(g, '#c0c4c0', x - 9, y - 1, 28, 1);
      rect(g, OUT, x + 26, y + 2, 16, 6); rect(g, '#8a8e90', x + 27, y + 3, 14, 4);
      rect(g, OUT, x + 2, y - 10, 38, 12);
      rect(g, '#8a8e90', x + 3, y - 9, 36, 10); rect(g, '#b8bcb8', x + 3, y - 9, 36, 2); rect(g, '#5a5e62', x + 3, y - 1, 36, 2);
      rect(g, '#c83a1a', x + 3, y - 5, 36, 1);
      for (let k = 0; k < 4; k++) rect(g, '#2a3a4a', x + 12 + k * 5, y - 7, 3, 2);
      rect(g, OUT, x + 36, y - 18, 6, 10); rect(g, '#9a9e9e', x + 37, y - 17, 4, 9); rect(g, '#c83a1a', x + 37, y - 13, 4, 1); // tail
      rect(g, '#3a3a3a', x - 2, y - 8, 5, 8); rect(g, '#1a1a1a', x - 3, y - 6, 1, 4); // crumpled nose + prop
      rect(g, '#8a7050', x + 14, y + 2, 5, 4); rect(g, '#a08a60', x + 21, y + 3, 4, 3); // burlap bales
    },
    circle(g, x, y, t) {
      g.strokeStyle = 'rgba(30,20,14,0.55)'; g.lineWidth = 4; g.beginPath(); g.ellipse(x + 16, y + 2, 30, 16, 0, 0, 7); g.stroke();
      g.strokeStyle = 'rgba(240,230,190,0.35)'; g.lineWidth = 1; g.beginPath(); g.ellipse(x + 16, y + 2, 27, 14, 0, 0, 7); g.stroke();
      g.fillStyle = 'rgba(30,20,14,0.3)'; for (let k = 0; k < 3; k++) { const a = k * 2.1; g.fillRect(x + 16 + Math.cos(a) * 14 - 2, y + 2 + Math.sin(a) * 7 - 1, 4, 3); }
      g.fillStyle = `rgba(140,255,170,${0.5 + Math.sin(t * 3) * 0.3})`; g.fillRect(x + 15, y + 1, 2, 2);
      for (let k = 0; k < 5; k++) { const a = t * 0.7 + k * 1.26; g.fillStyle = 'rgba(140,255,170,0.4)'; g.fillRect(x + 16 + Math.cos(a) * 22, y + 2 + Math.sin(a) * 11, 1, 1); }
    },
    camp(g, x, y, t) {
      g.fillStyle = 'rgba(0,0,0,0.25)'; g.beginPath(); g.ellipse(x + 6, y + 8, 14, 4, 0, 0, 7); g.fill();
      // A-frame tent
      g.fillStyle = OUT; g.beginPath(); g.moveTo(x - 9, y + 8); g.lineTo(x + 6, y - 12); g.lineTo(x + 21, y + 8); g.fill();
      g.fillStyle = '#6a6a3a'; g.beginPath(); g.moveTo(x - 7, y + 7); g.lineTo(x + 6, y - 10); g.lineTo(x + 19, y + 7); g.fill();
      g.fillStyle = '#8a8a4a'; g.beginPath(); g.moveTo(x - 7, y + 7); g.lineTo(x + 6, y - 10); g.lineTo(x + 3, y + 7); g.fill();
      rect(g, '#2a2a1a', x + 4, y - 1, 5, 8);
      // fire ring + flame
      for (let k = 0; k < 6; k++) rect(g, '#6a6a6a', x + 30 + Math.round(Math.cos(k) * 5), y + 5 + Math.round(Math.sin(k) * 2), 2, 2);
      rect(g, '#3a2410', x + 27, y + 4, 8, 2);
      const f = Math.sin(t * 12) > 0 ? 1 : 0;
      rect(g, '#c83a1a', x + 29, y - 1 + f, 5, 5); rect(g, '#ff9a20', x + 30, y + f, 3, 4); rect(g, '#ffe070', x + 31, y + 2, 1, 2);
      // drying line with a pelt
      rect(g, '#5a3a1c', x + 42, y - 10, 1, 17); rect(g, '#8a7a5a', x + 22, y - 10, 20, 1);
      rect(g, '#4a2e1c', x + 28, y - 9, 9, 7); rect(g, '#6a4a2c', x + 29, y - 9, 7, 2);
    },
    still(g, x, y, t) {
      g.fillStyle = 'rgba(0,0,0,0.25)'; g.beginPath(); g.ellipse(x + 12, y + 8, 20, 5, 0, 0, 7); g.fill();
      rect(g, OUT, x - 2, y - 10, 14, 18); rect(g, '#b86a2a', x - 1, y - 9, 12, 16); rect(g, '#e0985a', x, y - 9, 3, 16); rect(g, '#8a4a1a', x + 8, y - 9, 3, 16);
      rect(g, OUT, x + 2, y - 14, 6, 5); rect(g, '#b86a2a', x + 3, y - 13, 4, 4);
      rect(g, '#b86a2a', x + 7, y - 13, 12, 2); rect(g, '#b86a2a', x + 18, y - 13, 2, 12); // coil pipe
      for (let k = 0; k < 3; k++) rect(g, '#e0985a', x + 16, y - 9 + k * 3, 6, 1);
      rect(g, OUT, x + 20, y - 4, 12, 12); rect(g, '#6a4a24', x + 21, y - 3, 10, 10); rect(g, '#3a2410', x + 21, y, 10, 1); rect(g, '#3a2410', x + 21, y + 4, 10, 1);
      rect(g, '#c83a1a', x + 2, y + 5, 6, 2); rect(g, Math.sin(t * 10) > 0 ? '#ffd040' : '#ff9a20', x + 3, y + 5, 4, 1);
      rect(g, '#e8e0c8', x + 34, y + 3, 3, 5); rect(g, '#e8e0c8', x + 38, y + 4, 3, 4); // jugs
    },
    altar(g, x, y, t) {
      rect(g, OUT, x + 12, y - 8, 10, 14); rect(g, '#4a3a2a', x + 13, y - 7, 8, 13); rect(g, '#6a5a44', x + 13, y - 7, 8, 2); // stump
      rect(g, '#e8e0c8', x + 15, y - 13, 4, 4); rect(g, OUT, x + 15, y - 12, 1, 1); rect(g, OUT, x + 18, y - 12, 1, 1); // skull
      for (let k = 0; k < 9; k++) {
        const a = k / 9 * 6.28, cx = x + 17 + Math.round(Math.cos(a) * 20), cy = y + 1 + Math.round(Math.sin(a) * 9);
        rect(g, '#1a1a1a', cx, cy - 3, 2, 4);
        rect(g, (Math.sin(t * 9 + k) > 0) ? '#ffd040' : '#ff9a20', cx, cy - 5, 2, 2);
      }
      rect(g, '#d8c048', x + 9, y + 4, 2, 1); rect(g, '#d8c048', x + 24, y + 3, 2, 1); rect(g, '#c0c0c8', x + 20, y + 6, 2, 1); // coins
    },
    pirogue(g, x, y) {
      g.fillStyle = 'rgba(40,60,70,0.35)'; g.beginPath(); g.ellipse(x + 16, y + 6, 24, 5, 0, 0, 7); g.fill();
      rect(g, OUT, x - 4, y - 1, 38, 7); rect(g, '#4a3a2a', x - 3, y, 36, 5); rect(g, '#6a5a44', x - 3, y, 36, 1); rect(g, '#2a1e14', x, y + 2, 30, 2);
      rect(g, 'rgba(90,130,150,0.7)', x + 14, y + 1, 18, 4); // it's half full of water
      rect(g, '#5a5a2a', x + 4, y + 1, 7, 3); rect(g, '#8a8a4a', x + 5, y + 1, 5, 1); // tackle box
      rect(g, '#6a5a44', x + 20, y - 7, 1, 8); rect(g, '#6a5a44', x + 12, y - 8, 16, 1); // paddle
    },
  };
  SV.draw = function (g, left, top, vw, vh, t) {
    for (const P of PLACES) {
      if (!P.at) continue;
      const x = P.at.x * TS - 8, y = P.at.y * TS + 6;
      if (x < left - 80 || x > left + vw + 40 || y < top - 40 || y > top + vh + 40) continue;
      ART[P.art](g, x, y, t);
      // unsearched: a glint on the spot to search
      if (!SV.state().looted.includes(P.id) && Math.sin(t * 4 + x) > 0.6) { const sx = (P.at.x + 1.5) * TS, sy = (P.at.y + 0.5) * TS; rect(g, '#fff6c0', sx - 1, sy - 12, 2, 2); }
    }
  };
  // tins glint after dark too, so draw them over the lighting
  SV.glow = function (g, t) {
    const pl = G().player, s = this.state();
    if (!this.tins || pl.room) return;
    const range = s.tins.length >= 10 ? 14 : 6;
    this.tins.forEach((tin, i) => {
      if (s.tins.includes(i)) return;
      if (Math.abs(pl.x / TS - tin.x) > range || Math.abs(pl.y / TS - tin.y) > range) return;
      const x = tin.x * TS + 8, y = tin.y * TS + 10;
      rect(g, '#6a6a5a', x - 2, y - 1, 5, 3); rect(g, '#a0a08a', x - 2, y - 1, 5, 1);
      const p = (t * 1.3 + i * 0.37) % 1.6;
      if (p < 0.3) { const a = 1 - Math.abs(p - 0.15) / 0.15; g.fillStyle = `rgba(255,246,192,${a})`; g.fillRect(x, y - 4, 1, 5); g.fillRect(x - 2, y - 2, 5, 1); }
    });
  };
})();
