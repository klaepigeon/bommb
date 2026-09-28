// RHAPSODY — the emotional spectrum. The Fear Man's yellow and Hal's green are two lights of
// nine, and every ring points the way to the next:
//   yellow -> green (side with Hal: find Carol, deliver Gardner's ring, fight the Fear Man)
//   green  -> violet (Carol's crystal: be loved, then visit the glade at night)
//   violet -> indigo (a woman with a staff at a church, at night) -> blue (the Walker in the pines)
//   yellow -> red (rage: kill Hal for the Fear Man, or ten in a day) -> orange (kill Larfleeze
//   and search his hoard) -> black (the ghosts whisper of a churchyard at midnight) -> white
//   (the Fear Man's dead tree blooms at dawn for whoever holds death).
// Every ring has its own bolt, its own RING power and its own way of refilling Will. Swap
// between the ones you own at any wardrobe (tailor, or the closet at home).
'use strict';
(function () {
  const D = R.data, TS = R.TILE;
  const ramp = (a, b, c, d) => [a, b, c, d];
  const G = () => R.game;

  const COL = {
    yellow: { name: 'Yellow Ring', corps: 'Sinestro Corps', emo: 'Fear', c: '#f0c020', shirt: 'sccorps',
      oath: 'By dread of dark and fear of light,\nI bind the brave and bend their might.',
      how: 'Bolts send people running. RING: the construct library. Will returns when people near you are afraid.' },
    green: { name: 'Green Ring', corps: 'Green Lantern Corps', emo: 'Will', c: '#30c050', shirt: 'gljersey', pants: 'glblack',
      oath: 'When all is dark and hope is slight,\nI hold the line with all my might.',
      how: 'Clean bolts. RING: the construct library. Will returns near people who like you.' },
    red: { name: 'Red Ring', corps: 'Red Lantern Corps', emo: 'Rage', c: '#d02828', shirt: 'redcorps',
      oath: 'With blood and rage of crimson red,\nI burn until my foes are dead.',
      how: 'Bolts hit a third harder and set people alight. RING: vomit a stream of burning plasma. Will comes from getting hurt and from killing.' },
    orange: { name: 'Orange Ring', corps: 'Orange Lantern', emo: 'Avarice', c: '#f07a18', shirt: 'orcorps',
      oath: 'What\'s mine is mine and what\'s yours is mine,\nand all of it glows in orange light.',
      how: 'Bolts pick pockets. Anyone the ring kills becomes a ghost in it. RING: release up to three ghosts to fight for you. Will (greed) only comes from crimes that pay, and it overfills to double.' },
    blue: { name: 'Blue Ring', corps: 'Blue Lantern Corps', emo: 'Hope', c: '#3a80e8', shirt: 'bluecorps',
      oath: 'In fearful day, in raging night,\nall will be well: hold on to light.',
      how: 'Bolts hurt less but may talk a fighter down, and heal you a little. RING: a pulse of hope that heals you and your crew and calms the panicked. Will returns faster the more hurt you are, and while Will is high your wounds close by themselves.' },
    indigo: { name: 'Indigo Ring', corps: 'Indigo Tribe', emo: 'Compassion', c: '#5a38b8', shirt: 'indcorps',
      oath: 'Tor lorek san, nok var.\n(Their pain is mine to carry.)',
      how: 'Bolts make the target feel what they\'ve done: they drop their fight and weep. RING: step through the light to your waypoint (or a short hop ahead without one). Will returns while people nearby are hurt.' },
    violet: { name: 'Violet Ring', corps: 'Star Sapphires', emo: 'Love', c: '#d040a8', shirt: 'vcorps',
      oath: 'For hearts that break and hearts that heal,\nlove\'s violet crystal, bright as steel.',
      how: 'Bolts lock people in violet crystal. RING: crystal prison on your target, or with no target a wave of love that ends fights and warms hearts. Will returns near people who love you.' },
    black: { name: 'Black Ring', corps: 'Black Lantern Corps', emo: 'Death', c: '#2a2438', shirt: 'blkcorps',
      oath: 'Rise.',
      how: 'Bolts drain life into you. The dead you make rise as black lanterns and fight for you for a minute. RING: raise every corpse around you. You see people\'s emotions as colours. Will returns near the dead.' },
    white: { name: 'White Ring', corps: 'White Lantern', emo: 'Life', c: '#f0f0f0', shirt: 'whcorps',
      oath: 'Live.',
      how: 'Bolts heal your crew as they fly and obliterate the undead. RING: bring the dead around you back to life. Once a day it drags you back from death. Will returns slowly from everything.' },
  };
  const ORDER = ['yellow', 'green', 'red', 'orange', 'blue', 'indigo', 'violet', 'black', 'white'];
  const PAL = {
    red: { Y: ['#4a0808', '#8c1414', '#d02828', '#ff7060'], glow: 'rgba(255,60,50,', core: '#ff3a30', hi: '#ff8070', light: '#ffe0dc', mid: '#d02828' },
    orange: { Y: ['#5a2400', '#a04a08', '#f07a18', '#ffc070'], glow: 'rgba(255,140,30,', core: '#ff8a20', hi: '#ffc070', light: '#fff0dc', mid: '#f07a18' },
    blue: { Y: ['#0a2458', '#1a4aa0', '#3a80e8', '#a0d0ff'], glow: 'rgba(70,150,255,', core: '#4a9aff', hi: '#a0d0ff', light: '#e8f4ff', mid: '#3a80e8' },
    indigo: { Y: ['#1a0a40', '#34187a', '#5a38b8', '#a890f0'], glow: 'rgba(110,70,230,', core: '#7050e0', hi: '#a890f0', light: '#ece4ff', mid: '#5a38b8' },
    violet: { Y: ['#4a0a3a', '#8a1a6a', '#d040a8', '#ffa0e0'], glow: 'rgba(240,80,200,', core: '#f050c8', hi: '#ffa0e0', light: '#ffe8f8', mid: '#d040a8' },
    black: { Y: ['#000000', '#14101c', '#2a2438', '#7a6a90'], glow: 'rgba(40,20,60,', core: '#1a1024', hi: '#9a8ab0', light: '#d8d0e8', mid: '#2a2438' },
    white: { Y: ['#8a8a90', '#c0c0c8', '#eaeaf0', '#ffffff'], glow: 'rgba(255,255,255,', core: '#ffffff', hi: '#ffffff', light: '#ffffff', mid: '#eaeaf0' },
  };
  Object.assign(R.ringPALS, PAL);

  // uniforms: a tunic in the corps colour over black flight pants
  const ST = D.style;
  const uni = (name, c, lock) => ({ name, price: 0, lock, c });
  Object.assign(ST.shirts, {
    sccorps: uni('Sinestro Corps Tunic', ramp('#0a0a0e', '#16161e', '#262630', '#f0c020'), 'scsuit'),
    redcorps: uni('Red Lantern Tunic', ramp('#3a0606', '#6a0e0e', '#a01a1a', '#e04040'), 'redsuit'),
    orcorps: uni('Orange Lantern Wrap', ramp('#5a2400', '#8c3c08', '#c86010', '#f09a40'), 'orsuit'),
    bluecorps: uni('Blue Lantern Robe', ramp('#0a2458', '#1a3c88', '#2a5cc0', '#70a8f0'), 'bluesuit'),
    indcorps: uni('Indigo Tribe Wrap', ramp('#140a30', '#281658', '#40288a', '#7a60c8'), 'indsuit'),
    vcorps: uni('Star Sapphire Suit', ramp('#4a0a3a', '#761660', '#a82888', '#e070c8'), 'vsuit'),
    blkcorps: uni('Black Lantern Suit', ramp('#000000', '#0c0a12', '#18141f', '#4a4058'), 'blksuit'),
    whcorps: uni('White Lantern Suit', ramp('#9a9aa0', '#c8c8d0', '#ececf2', '#ffffff'), 'whsuit'),
  });
  ST.pants.corpsblack = uni('Corps Flight Pants', ramp('#06060a', '#101018', '#1a1a26', '#2a2a3a'), 'corpssuit');
  const SUIT = { yellow: 'scsuit', green: 'glsuit', red: 'redsuit', orange: 'orsuit', blue: 'bluesuit', indigo: 'indsuit', violet: 'vsuit', black: 'blksuit', white: 'whsuit' };
  const SHIRT_COL = {};
  for (const k of ORDER) SHIRT_COL[COL[k].shirt] = k;
  const baseLook = R.lookFromStyle;
  R.lookFromStyle = function (s, masked) {
    const L = baseLook.call(this, s, masked);
    const col = SHIRT_COL[s.shirt];
    if (col && col !== 'green' && L.oldOverride) {
      L.oldOverride.belt = col === 'black' ? '#6a6080' : col === 'white' ? '#c8c8d0' : col === 'yellow' ? '#f0c020' : PAL[col].Y[3];
      L.oldOverride.flare = false;
      L.oldOverride.top = 'turtle';
      if (s.pants === 'corpsblack') L.oldOverride.shoes = ['#06060a', '#101018', '#1a1a26'];
    }
    return L;
  };

  const CP = (R.corps = { COL, ORDER, allies: [], foes: [], t: 0 });

  // ---------------------------------------------------------------- state
  CP.state = function () {
    const pl = G().player;
    pl.street = pl.street || {};
    const s = (pl.street.corps = pl.street.corps || { owned: {}, ghosts: [], charged: {}, rage: { day: -1, n: 0 }, larf: {}, violet: {}, indigo: {}, blue: {}, black: {}, white: {} });
    for (const k of ['larf', 'violet', 'indigo', 'blue', 'black', 'white']) s[k] = s[k] || {};
    // rings from before the spectrum existed
    const fq = pl.fearQ || {};
    if (pl.inv.tools.ring && fq.path !== 'green' && !s.owned.yellow) s.owned.yellow = 1;
    if (pl.ringColor === 'green' || (fq.gperks && fq.gperks.knight)) s.owned.green = 1;
    if (fq.path === 'green' && pl.inv.tools.ring && !s.owned.yellow && !s.lostYellow) s.owned.yellow = 1;
    return s;
  };
  CP.owns = function (c) { return !!this.state().owned[c]; };
  CP.count = function () { const o = this.state().owned; return ORDER.filter((c) => o[c]).length; };
  CP.col = function () { return G().player.ringColor || 'yellow'; };

  CP.give = function (col, quiet) {
    const g = G(), pl = g.player, s = this.state();
    const first = !this.count();
    s.owned[col] = 1;
    pl.inv.tools.ring = 1;
    pl.wardrobe = pl.wardrobe || {};
    pl.wardrobe['unlock:' + SUIT[col]] = 1;
    pl.wardrobe['unlock:corpssuit'] = 1;
    if (!pl.inv.weapons.ring && pl.giveWeapon) pl.giveWeapon('ring');
    if (first || col === 'green' || !pl.ringColor) this.wear(col, true);
    g.ui.setRingButtons();
    g.audio.sfx('promote');
    for (let k = 0; k < 40; k++) g.fx.add({ x: pl.x, y: pl.y - 10, vx: (R.rng() - 0.5) * 220, vy: (R.rng() - 0.5) * 220, life: 1, max: 1, c: col === 'black' ? '#6a5a80' : COL[col].c, s: 2, glow: 1 });
    if (!quiet) g.ui.toast(`The ${COL[col].name} is yours: ${COL[col].corps}, the light of ${COL[col].emo.toLowerCase()}. Swap rings at any wardrobe.`, 'good');
  };
  CP.wear = function (col, quiet) {
    const g = G(), pl = g.player;
    pl.ringColor = col;
    D.weapons.ring.name = COL[col].name;
    if (col !== 'orange') pl.will = Math.min(pl.will, pl.willMax || 100);
    if (!quiet) { g.audio.sfx('coolOn'); g.ui.toast(`You slide on the ${COL[col].name}. ${COL[col].emo} burns in your fist.`, 'good'); }
  };
  CP.suitUp = function (col) {
    const pl = G().player;
    Object.assign(pl.style, { jacket: 'none', shirt: COL[col].shirt, top: 'turtle', pants: COL[col].pants || 'corpsblack', hat: 'none' });
    pl.buildLook();
    G().ui.toast(`${COL[col].corps} colours. People stare.`, 'good');
  };

  // ---------------------------------------------------------------- the ring sheet (wardrobe)
  CP.openRings = function (swap) {
    const g = G(), ui = g.ui, pl = g.player, s = this.state();
    const day = Math.floor(g.clock.t / 1440);
    const owned = ORDER.filter((c) => s.owned[c]);
    const esc = (t) => String(t).replace(/[&<>"]/g, (m) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[m]));
    let html = ui.header('Your Rings', `${owned.length} of 9 lights. WILL ${Math.round(pl.will)}/${pl.willMax || 100}${s.ghosts.length ? ` · ${s.ghosts.length} ghost${s.ghosts.length > 1 ? 's' : ''} in the orange ring` : ''}`) + '<div class="body"><div class="opts">';
    const opts = [];
    for (const c of owned) {
      const on = this.col() === c;
      opts.push({ label: `<i class="sw" style="background:${COL[c].c};border:1px solid #1b1410"></i> ${COL[c].name}${on ? ' (wearing)' : ''}`, small: `${COL[c].corps} · ${COL[c].emo}. ${COL[c].how}`, cls: on ? '' : 'go', fn: on || !swap ? null : () => { this.wear(c); ui.closeSheet(); } });
      if (s.charged[c] !== day && (c === 'yellow' ? pl.inv.tools.lantern : c === 'green' ? pl.inv.tools.battery : s.batt && s.batt[c]) && on) opts.push({ label: `Recite the ${COL[c].emo.toLowerCase()} oath`, small: c === 'orange' ? 'Fills greed to double' : 'Full charge, once a day', fn: () => { this.charge(c); ui.closeSheet(); } });
      if (swap && pl.wardrobe && pl.wardrobe['unlock:' + SUIT[c]] && pl.style.shirt !== COL[c].shirt) opts.push({ label: `Put on the ${COL[c].corps} uniform`, small: 'Free', fn: () => { this.suitUp(c); ui.closeSheet(); } });
    }
    const leads = this.leads();
    html += opts.map((o, i) => `<button class="opt ${o.cls || ''}" data-i="${i}" ${o.fn ? '' : 'disabled'}>${o.label}<small>${esc(o.small)}</small></button>`).join('') + '</div>';
    if (leads.length) html += `<div class="sect">Where the light points</div>${leads.map((l) => `<p style="font-size:14px">• ${esc(l)}</p>`).join('')}`;
    if (!swap) html += '<p style="font-size:13px;color:var(--brown)">Swap rings at any wardrobe: a tailor, or the closet at home.</p>';
    html += '</div>';
    const sh = ui.openSheet('rings', html);
    sh.querySelectorAll('[data-i]').forEach((b) => b.addEventListener('click', () => { const o = opts[+b.dataset.i]; if (o.fn) { g.audio.sfx('click'); o.fn(); } }));
  };
  CP.charge = function (c) {
    const g = G(), pl = g.player, s = this.state();
    s.charged[c] = Math.floor(g.clock.t / 1440);
    pl.will = (pl.willMax || 100) * (c === 'orange' ? 2 : 1);
    g.audio.sfx('coolOn');
    for (let k = 0; k < 24; k++) g.fx.add({ x: pl.x, y: pl.y - 10, vx: (R.rng() - 0.5) * 160, vy: (R.rng() - 0.5) * 160, life: 0.8, max: 0.8, c: COL[c].c, s: 2, glow: 1 });
    g.ui.story('The Oath', COL[c].oath + `\n\n(Will ${c === 'orange' ? 'overflowing' : 'fully charged'}.)`);
  };
  // what the rings you hold are pointing you toward
  CP.leads = function () {
    const s = this.state(), o = s.owned, out = [];
    const fq = G().player.fearQ || {};
    if (o.yellow && !o.green && !fq.halDead && fq.path !== 'green') out.push('Green: a pilot named Hal flies out of the Dustwater airstrip by day.');
    if (o.yellow && !o.red) out.push(fq.halDead ? 'Red: something out there smelled Hal\'s blood on you. Stay angry.' : 'Red: rage calls to rage. Kill ten people in a single day.');
    if (s.violet.stage && !o.violet) out.push('Violet: be loved (a sweetheart or spouse who thinks the world of you), then visit the violet glade at night.');
    if (o.violet && !o.indigo) out.push('Indigo: a woman with a staff waits at a church, after dark.');
    if (o.indigo && !o.blue) out.push(`Blue: the Walker in the Pinecrest pines, by day. He wants to see compassion first (${Math.min(3, s.indigo.calmed || 0)}/3 fights ended with the indigo light).`);
    if (o.red && !o.orange) out.push(s.larf.dead ? 'Orange: Larfleeze is dead. Search what\'s left of him.' : 'Orange: Larfleeze, the hoarder, in the badlands. He will not share.');
    if (o.orange && !o.black) out.push((s.ghosts.length >= 5 ? 'Black: ' : `Black: the ghosts are quiet (${s.ghosts.length}/5). `) + 'The dead whisper of a churchyard at midnight.');
    if (o.black && !o.white) out.push('White: the Fear Man\'s dead tree, at dawn.');
    return out;
  };

  // ---------------------------------------------------------------- sites
  CP.placeSites = function () {
    const g = G(), w = g.world, rnd = R.mulberry(w.seed * 11 + 909);
    const find = (cx, cy, r0, r1, pred) => { for (let k = 0; k < 900; k++) { const a = rnd() * 6.28, r = r0 + rnd() * (r1 - r0); const x = Math.round(cx + Math.cos(a) * r), y = Math.round(cy + Math.sin(a) * r); if (w.inb(x, y) && pred(x, y)) return { x, y }; } return null; };
    const open = (x, y) => !w.isWater(x, y) && !w.bid[w.idx(x, y)] && !D.roadTile[w.t(x, y)] && !w.inCityRect(x, y, 10);
    const c0 = w.cities[0], dust = w.cities.find((c) => c.id === 'dust') || c0, pine = w.cities.find((c) => c.id === 'pine') || c0;
    const clear = (s, r) => { for (let yy = s.y - r; yy <= s.y + r; yy++) for (let xx = s.x - r; xx <= s.x + r; xx++) if (w.inb(xx, yy) && !w.bid[w.idx(xx, yy)]) w.obj[w.idx(xx, yy)] = 0; };
    this.glade = find(c0.cx, c0.cy, 50, 140, (x, y) => w.biomeAt(x, y) === 'forest' && open(x, y)) || find(c0.cx, c0.cy, 40, 140, open) || { x: c0.cx + 40, y: c0.cy - 40 };
    this.hoard = find(dust.cx, dust.cy, 60, 130, (x, y) => w.biomeAt(x, y) === 'desert' && open(x, y) && Math.hypot(x - R.fearQuest.strip.x, y - R.fearQuest.strip.y) > 30) || { x: dust.cx - 60, y: dust.cy + 30 };
    this.walker = find(pine.cx, pine.cy, 25, 70, (x, y) => (w.biomeAt(x, y) === 'forest' || w.biomeAt(x, y) === 'snow') && open(x, y)) || { x: pine.cx + 30, y: pine.cy };
    clear(this.glade, 3); clear(this.hoard, 6); clear(this.walker, 2);
    // the hoard: junk piled in a ring
    for (let k = 0; k < 10; k++) { const a = k * 0.63, xx = Math.round(this.hoard.x + Math.cos(a) * 6), yy = Math.round(this.hoard.y + Math.sin(a) * 5); if (w.inb(xx, yy) && !w.bid[w.idx(xx, yy)]) w.obj[w.idx(xx, yy)] = D.O.BOULDER; }
    R.fearQuest.glade = this.glade;
  };

  // ---------------------------------------------------------------- people of the spectrum
  const LOOKS = {
    carol: { fem: true, age: 30, skin: '#e8b890', hair: '#3a2010', top: '#a82888', bottom: '#761660', seedStr: 'carol', oldOverride: { style: 'long', shirt: ramp('#4a0a3a', '#761660', '#a82888', '#e070c8'), pants: ramp('#4a0a3a', '#761660', '#a82888', '#e070c8'), jacket: null, hair: ramp('#1a0c04', '#3a2010', '#5a3418', '#7a4a24'), top: 'turtle', flare: false } },
    guy: { fem: false, age: 34, skin: '#f0c0a0', hair: '#c04818', top: '#2a6a34', bottom: '#2a2a3a', seedStr: 'gardner', oldOverride: { style: 'short', shirt: ramp('#1a4a24', '#2a6a34', '#3a8a48', '#5aaa68'), pants: ramp('#14141c', '#24243a', '#383852', '#54547a'), jacket: null, hair: ramp('#6a2008', '#a03810', '#c85418', '#e87830'), top: 'tee' } },
    indigo: { fem: true, age: 40, skin: '#a86a48', hair: '#141010', top: '#40288a', bottom: '#281658', seedStr: 'indigo', oldOverride: { style: 'long', shirt: ramp('#140a30', '#281658', '#40288a', '#7a60c8'), pants: ramp('#140a30', '#281658', '#40288a', '#7a60c8'), jacket: null, top: 'turtle' } },
    walker: { fem: false, age: 60, skin: '#6a8ac0', hair: '#e8e8f0', top: '#2a5cc0', bottom: '#1a3c88', seedStr: 'walker', oldOverride: { style: 'short', shirt: ramp('#0a2458', '#1a3c88', '#2a5cc0', '#70a8f0'), pants: ramp('#0a2458', '#1a3c88', '#2a5cc0', '#70a8f0'), jacket: null, top: 'turtle', flare: false } },
    larfleeze: { fem: false, age: 70, skin: '#6a7a9a', hair: '#1a1a24', top: '#c86010', bottom: '#8c3c08', seedStr: 'larfleeze', oldOverride: { style: 'short', shirt: ramp('#5a2400', '#8c3c08', '#c86010', '#f09a40'), pants: ramp('#5a2400', '#8c3c08', '#c86010', '#f09a40'), jacket: null, hair: ramp('#0a0a10', '#1a1a24', '#2a2a36', '#3a3a4a'), top: 'tee', flare: false } },
  };
  const tinted = (col, base, seed) => {
    const Y = col === 'orange' ? PAL.orange.Y : col === 'black' ? ['#000000', '#0c0a12', '#1a1622', '#3a3448'] : PAL[col] ? PAL[col].Y : ramp('#444', '#666', '#888', '#aaa');
    const skin = col === 'orange' ? '#f0a050' : col === 'black' ? '#8a8a96' : '#e0ac7e';
    return { fem: !!(base && base.fem), age: (base && base.age) || 30, skin, hair: Y[1], top: Y[2], bottom: Y[1], seedStr: seed, oldOverride: { style: (base && base.fem) ? 'long' : 'short', shirt: Y, pants: col === 'black' ? Y : ramp(Y[0], Y[0], Y[1], Y[2]), jacket: null, hair: ramp(Y[0], Y[1], Y[1], Y[2]), top: 'turtle', flare: false } };
  };
  CP.npc = function (x, y, kind, o) {
    const g = G();
    const h = g.actors.makeHuman(x, y, Object.assign({ tag: 'corpsnpc', cash: 0, arch: 'tough', look: LOOKS[kind] }, o || {}));
    h.armed = false; h.weapon = 'fists';
    h.keep = true; h.tr.brave = 1; h.corpsNpc = kind; h.stay = true; h.state = 'idle'; h.timer = 1e9;
    return h;
  };
  // allies of light: ghosts from the orange ring, black lanterns, Guy Gardner
  CP.spawnAlly = function (x, y, col, look, name, life, hp) {
    const g = G(), pl = g.player;
    const h = g.actors.makeHuman(x, y, { tag: 'crew', cash: 0, arch: 'tough', look });
    h.armed = false; h.weapon = 'fists';
    h.strangerName = name; h.keep = true; h.hp = h.maxHp = hp || 120; h.tr.brave = 1;
    h.corpsAlly = col; h.allyT = life; h.noLoot = true;
    h.crew = true; h.hostile = false; h.state = 'follow'; h.timer = 1e9;
    pl.crew.push(h);
    this.allies.push(h);
    for (let k = 0; k < 14; k++) g.fx.add({ x, y: y - 10, vx: (R.rng() - 0.5) * 120, vy: -R.rng() * 120, life: 0.7, max: 0.7, c: col === 'black' ? '#6a5a80' : COL[col] ? COL[col].c : '#fff', s: 2, glow: 1 });
    return h;
  };
  CP.spawnFoe = function (x, y, col, look, name, hp, life) {
    const g = G();
    const h = g.actors.makeHuman(x, y, { tag: 'corpsfoe', cash: 0, arch: 'tough', look });
    h.armed = false; h.weapon = 'fists';
    h.strangerName = name; h.keep = true; h.hp = h.maxHp = hp; h.tr.brave = 1; h.corpsFoe = col; h.allyT = life || 0; h.noLoot = true;
    h.hostile = true; h.hostileLocked = true;
    g.actors.setFight(h, g.player);
    this.foes.push(h);
    return h;
  };
  // enemy ring bolts (Carol, Larfleeze, the black dead)
  CP.foeBolt = function (from, to, col, dmg) {
    const a = Math.atan2(to.y - from.y, to.x - from.x);
    (this.fshots = this.fshots || []).push({ x: from.x, y: from.y - 10, vx: Math.cos(a) * 200, vy: Math.sin(a) * 200, t: 0, col, dmg: dmg || 9, src: from });
  };

  // ---------------------------------------------------------------- hits: what each light does to people
  CP.onHit = function (a, dmg) {
    const g = G(), pl = g.player, col = this.col();
    if (!a || a.kind !== 'h') return;
    const alive = !a.dead;
    if (col === 'yellow' && alive && R.rng() < 0.3 && !a.hostileLocked) g.actors.setFlee(a, pl, 5);
    if (col === 'red') { if (alive) a.burning = Math.max(a.burning || 0, 2.5); pl.will = Math.min(pl.willMax || 100, pl.will + 2); }
    if (col === 'orange') {
      const take = Math.min(a.cash || 0, R.rng.int(5, 20));
      if (take > 0) { a.cash -= take; pl.addCash(take); g.fx.text(a.x, a.y - 30, 'MINE!', '#ffc070'); }
    }
    if (col === 'blue') {
      pl.hp = Math.min(pl.maxHp, pl.hp + 2);
      if (alive && a.hostile && !a.hostileLocked && R.rng() < 0.25) { a.hostile = false; a.state = 'idle'; a.target = null; a.timer = 3; g.actors.say(a, R.rng.pick(['...I don\'t want to do this anymore.', 'Maybe... maybe it\'ll be okay.', 'What am I doing?'])); }
    }
    if (col === 'indigo' && alive) {
      const wasFighting = a.hostile && a.state === 'fight';
      if (!a.hostileLocked) { a.hostile = false; g.actors.setCower(a, pl, 6); }
      g.actors.say(a, R.rng.pick(['Oh God... what have I done?', 'I\'m sorry. I\'m so sorry.', 'I can feel it. All of it.', 'Mama...']));
      if (a.person) a.person.opinion = Math.min(100, a.person.opinion + 4);
      if (wasFighting && !a.hostileLocked) { const s = this.state(); s.indigo.calmed = (s.indigo.calmed || 0) + 1; }
    }
    if (col === 'violet' && alive) this.crystal(a, 4);
    if (col === 'black') pl.hp = Math.min(pl.maxHp, pl.hp + dmg * 0.3);
    if (col === 'white') for (const c of pl.crew) if (!c.dead && Math.hypot(c.x - a.x, c.y - a.y) < TS * 6) c.hp = Math.min(c.maxHp, c.hp + 10);
    // the killing blow
    if (a.dead && alive === false && !a.corpsCounted) {
      a.corpsCounted = true;
      if (col === 'orange' && !a.corpsAlly && !a.corpsFoe) {
        const s = this.state(), name = (a.person && g.pop.short(a.person)) || a.strangerName || 'Somebody';
        s.ghosts.push({ n: name, f: a.look && a.look.fem ? 1 : 0, a: (a.look && a.look.age) || 30 });
        if (s.ghosts.length > 24) s.ghosts.shift();
        g.fx.text(a.x, a.y - 30, 'COLLECTED', '#ffc070');
        for (let k = 0; k < 10; k++) g.fx.add({ x: a.x, y: a.y - 10, vx: (pl.x - a.x) * (1 + R.rng()), vy: (pl.y - a.y) * (1 + R.rng()), life: 0.6, max: 0.6, c: '#ffc070', s: 2, glow: 1 });
      }
      if (col === 'black' && !a.corpsFoe && !a.corpsAlly) setTimeout(() => { if (a.dead && !a.removed && G() === g) this.raise(a); }, 1500);
      if (col === 'red') pl.will = Math.min(pl.willMax || 100, pl.will + 10);
    }
  };
  CP.crystal = function (a, secs) {
    const g = G();
    a.crystalT = secs; a.state = 'surrender'; a.timer = secs; if (!a.hostileLocked) a.hostile = false;
    a.vx = a.vy = 0;
    if (R.rng() < 0.5) g.actors.say(a, R.rng.pick(['I can\'t move!', 'It\'s... beautiful.', 'Let me out!']));
  };
  CP.raise = function (a) {
    const g = G();
    if (!a.dead || a.raised) return;
    a.raised = true;
    const name = 'Black Lantern ' + ((a.person && a.person.first) || a.strangerName || '');
    const look = tinted('black', a.look, 'bl' + (a.person ? a.person.id : R.rng.int(0, 1e6)));
    const h = this.spawnAlly(a.x, a.y, 'black', look, name.trim(), 60, 150);
    h.blackLantern = true;
    g.actors.say(h, R.rng.pick(['Rise.', 'Heartbeat... I hear yours.', 'Your fear smells sweet.']));
    g.actors.remove(a);
  };

  // ---------------------------------------------------------------- RING: each light's signature power
  CP.power = function () {
    const g = G(), pl = g.player, col = this.col(), Ring = R.ring;
    const { tg, ang } = Ring.aim();
    pl.ang = ang; pl.punchT = 0.22;
    const fx = (n, c, sp) => { for (let k = 0; k < n; k++) g.fx.add({ x: pl.x, y: pl.y - 10, vx: (R.rng() - 0.5) * sp, vy: (R.rng() - 0.5) * sp, life: 0.7, max: 0.7, c, s: 2, glow: 1 }); };
    if (col === 'red') {
      if (!Ring.spend(25)) return;
      g.audio.sfx('coolOn', pl.x, pl.y);
      g.fx.text(pl.x, pl.y - 30, 'RAAAAGH!', '#ff7060');
      for (let d = 1; d <= 6; d++) {
        const x = pl.x + Math.cos(ang) * d * 14, y = pl.y + Math.sin(ang) * d * 14;
        g.env.ignite(x, y, 0.5, pl);
        for (let k = 0; k < 4; k++) g.fx.add({ x, y: y - 8, vx: Math.cos(ang) * 60 + (R.rng() - 0.5) * 40, vy: Math.sin(ang) * 60 + (R.rng() - 0.5) * 40, life: 0.5, max: 0.5, c: R.rng() < 0.5 ? '#ff3a30' : '#8c1414', s: 3 });
      }
      for (const a of g.actors.near(pl.x, pl.y, 90)) {
        if (a.dead || a.inCar || a === pl || a.crew || (a.fearman && !a.fearFight)) continue;
        if (Math.abs(R.angDiff(ang, Math.atan2(a.y - pl.y, a.x - pl.x))) > 0.5) continue;
        CP.ctx++; R.combat.damage(a, 30, pl, 'fire'); CP.ctx--;
        if (!a.dead) a.burning = Math.max(a.burning || 0, 4);
      }
      return;
    }
    if (col === 'orange') {
      const s = this.state();
      if (!s.ghosts.length) return g.ui.toast('Your orange ring is empty. Kill with it and it keeps what it takes.', 'warn');
      const out = this.allies.filter((a) => a.corpsAlly === 'orange' && !a.dead).length;
      if (out >= 3) return g.ui.toast('Three ghosts are already out.', 'warn');
      if (!Ring.spend(20)) return;
      const n = Math.min(3 - out, s.ghosts.length);
      for (let i = 0; i < n; i++) {
        const gh = s.ghosts[(s.gi = ((s.gi || 0) + 1) % s.ghosts.length)];
        const sp = g.world.findNear((pl.x / TS) | 0, (pl.y / TS) | 0, 1, 3, (x, y) => !g.world.solidPed(x, y) && !g.world.isWater(x, y)) || { x: pl.x / TS, y: pl.y / TS };
        const h = this.spawnAlly(sp.x * TS + 8, sp.y * TS + 8, 'orange', tinted('orange', { fem: gh.f, age: gh.a }, 'ghost' + gh.n), 'Ghost of ' + gh.n, 40, 110);
        g.actors.say(h, R.rng.pick(['...mine...', 'Where am I?', 'It\'s so cold in the ring.', 'Who do I hurt?']));
      }
      g.audio.sfx('coolOn', pl.x, pl.y);
      return;
    }
    if (col === 'blue') {
      if (!Ring.spend(35)) return;
      pl.hp = Math.min(pl.maxHp, pl.hp + 40);
      for (const c of pl.crew) if (!c.dead) c.hp = Math.min(c.maxHp, c.hp + 40);
      for (const a of g.actors.near(pl.x, pl.y, TS * 8)) if (a.kind === 'h' && !a.dead && (a.state === 'flee' || a.state === 'cower')) { a.state = 'idle'; a.timer = 2; if (a.person) a.person.opinion = Math.min(100, a.person.opinion + 5); }
      fx(30, '#a0d0ff', 200);
      g.fx.text(pl.x, pl.y - 30, 'All will be well.', '#a0d0ff');
      g.audio.sfx('coolOn', pl.x, pl.y);
      return;
    }
    if (col === 'indigo') {
      const w = g.world, wp = g.waypoint;
      let to = null;
      if (wp) { if (!Ring.spend(60)) return; to = w.findNear((wp.x / TS) | 0, (wp.y / TS) | 0, 0, 5, (x, y) => !w.solidPed(x, y) && !w.isWater(x, y)); }
      else {
        if (!Ring.spend(15)) return;
        for (let d = 6; d >= 2 && !to; d--) { const x = ((pl.x + Math.cos(ang) * d * TS) / TS) | 0, y = ((pl.y + Math.sin(ang) * d * TS) / TS) | 0; if (w.inb(x, y) && !w.solidPed(x, y) && !w.isWater(x, y)) to = { x, y }; }
      }
      if (!to) return g.ui.toast('The light can\'t find footing there.', 'warn');
      fx(24, '#a890f0', 160);
      pl.place(to.x * TS + 8, to.y * TS + 8);
      g.cam.x = pl.x; g.cam.y = pl.y;
      fx(24, '#a890f0', 160);
      g.audio.sfx('coolOn', pl.x, pl.y);
      if (R.route) R.route.path = null;
      return;
    }
    if (col === 'violet') {
      if (tg && tg.kind === 'h' && !tg.dead) { if (!Ring.spend(20)) return; this.crystal(tg, 8); g.fx.text(tg.x, tg.y - 30, 'CRYSTAL', '#ffa0e0'); g.audio.sfx('coolOn', pl.x, pl.y); return; }
      if (!Ring.spend(30)) return;
      let n = 0;
      for (const a of g.actors.near(pl.x, pl.y, TS * 8)) {
        if (a.kind !== 'h' || a.dead || a.crew) continue;
        if (a.person) a.person.opinion = Math.min(100, a.person.opinion + 8);
        if (a.hostile && !a.hostileLocked) { a.hostile = false; a.state = 'idle'; a.target = null; a.timer = 3; g.actors.say(a, R.rng.pick(['I... can\'t hurt you.', 'Why was I so angry?', 'You have kind eyes.'])); n++; }
      }
      fx(30, '#ffa0e0', 220);
      g.fx.text(pl.x, pl.y - 30, n ? 'LOVE CONQUERS' : '♥', '#ffa0e0');
      g.audio.sfx('coolOn', pl.x, pl.y);
      return;
    }
    if (col === 'black') {
      const dead = g.actors.list.filter((a) => a.kind === 'h' && a.dead && !a.raised && !a.removed && Math.hypot(a.x - pl.x, a.y - pl.y) < TS * 10);
      if (!dead.length) return g.ui.toast('No dead here to raise.', 'warn');
      if (!Ring.spend(40)) return;
      for (const a of dead.slice(0, 6)) this.raise(a);
      g.fx.text(pl.x, pl.y - 30, 'RISE.', '#9a8ab0');
      g.audio.sfx('coolOn', pl.x, pl.y);
      return;
    }
    if (col === 'white') {
      const dead = g.actors.list.filter((a) => a.kind === 'h' && a.dead && !a.removed && Math.hypot(a.x - pl.x, a.y - pl.y) < TS * 6);
      const undead = this.allies.concat(this.foes).filter((a) => a.blackLantern && !a.dead && Math.hypot(a.x - pl.x, a.y - pl.y) < TS * 8);
      if (!dead.length && !undead.length) return g.ui.toast('Nobody here needs living.', 'warn');
      if (!Ring.spend(50)) return;
      for (const a of undead) R.combat.damage(a, 999, pl, 'blast');
      for (const a of dead.slice(0, 5)) this.revive(a);
      fx(40, '#ffffff', 240);
      g.fx.text(pl.x, pl.y - 30, 'LIVE.', '#ffffff');
      g.audio.sfx('coolOn', pl.x, pl.y);
    }
  };
  CP.revive = function (a) {
    const g = G(), pl = g.player;
    a.dead = false; a.hp = a.maxHp * 0.5; a.state = 'idle'; a.timer = 3; a.down = 0; a.hostile = false; a.target = null; a.burning = 0; a.looted = false;
    if (a.person) { a.person.alive = true; a.person.opinion = Math.min(100, a.person.opinion + 50); }
    g.actors.say(a, R.rng.pick(['I was... somewhere warm.', 'What happened? I saw a white light.', 'You brought me back. You brought me BACK.']));
    for (let k = 0; k < 16; k++) g.fx.add({ x: a.x, y: a.y - 10, vx: (R.rng() - 0.5) * 80, vy: -R.rng() * 120, life: 0.9, max: 0.9, c: '#ffffff', s: 2, glow: 1 });
    pl.rep && (pl.rep.honor = (pl.rep.honor || 0) + 2);
  };

  // ---------------------------------------------------------------- the quests of the spectrum
  CP.startViolet = function () {
    const s = this.state(), g = G();
    if (s.violet.stage) return;
    s.violet.stage = 1;
    R.poi.add(this.glade.x, this.glade.y, 'tip', 'The violet glade', 'At night, if someone loves you');
    g.ui.toast('Carol: "The crystal only answers to people who are loved. Find someone, then come to the glade at night."', 'good');
  };
  const loved = () => {
    const g = G(), pl = g.player;
    const p = pl.sweetheart >= 0 ? g.pop.people[pl.sweetheart] : g.pop.people.find((q) => q.playerPartner);
    return p && p.alive && p.opinion >= 60 ? p : null;
  };
  CP.hint = function (key, text, pin) {
    const s = this.state(), g = G();
    if (s['h_' + key]) return;
    s['h_' + key] = 1;
    g.ui.story('The light points', text);
    if (pin) { R.poi.add(pin.x, pin.y, 'tip', pin.label, pin.sub); g.waypoint = { x: pin.x * TS + 8, y: pin.y * TS + 8 }; }
  };
  CP.nearestChurch = function () {
    const g = G(), pl = g.player; let best = null, bd = 1e9;
    for (const b of g.world.buildings) if (b && b.type === 'church' && !b.destroyed) { const d = Math.hypot(b.out.x * TS - pl.x, b.out.y * TS - pl.y); if (d < bd) { bd = d; best = b; } }
    return best;
  };

  CP.tick = function () {
    const g = G(), pl = g.player, s = this.state(), o = s.owned, fq = pl.fearQ || {};
    if (pl.room || pl.dead || (R.opening && R.opening.active)) return;
    const hr = g.clock.hour(), night = hr >= 21 || hr < 4, tx = pl.x / TS, ty = pl.y / TS;
    const near = (p, r) => p && Math.hypot(tx - p.x, ty - p.y) < r;
    // red: rage
    if (o.yellow && !o.red && (fq.halDead || s.rage.n >= 10)) {
      this.give('red');
      s.larf.hint = true;
      g.ui.story('The Red Ring', `A red ring comes screaming down out of the sky like a flare and bites onto your finger. For a second you can't see anything but red.\n\n${COL.red.oath}\n\nThen a picture, burned into the back of your eyes: a hunched blue-grey thing on a mountain of stolen junk in the badlands, hugging an orange lantern. "MINE," it says. It's all it ever says.\n\n(Larfleeze's hoard is marked on your map.)`);
      R.poi.add(this.hoard.x, this.hoard.y, 'tip', 'Larfleeze\'s hoard', 'He will not share');
    }
    // orange: Larfleeze on his hoard, any hour
    if (s.larf.hint && !s.larf.dead && near(this.hoard, 30) && !(this.larf && !this.larf.dead && !this.larf.removed)) this.spawnLarfleeze();
    // black: the ghosts whisper once you have enough of them
    if (o.orange && !o.black && s.ghosts.length >= 5) {
      const ch = this.nearestChurch();
      if (ch) this.hint('black', 'The ghosts in your orange ring won\'t stop whispering. One word, over and over, in all their voices: churchyard. Midnight. Churchyard. Midnight.\n\n(Go to a church between midnight and 3 AM.)', { x: ch.out.x, y: ch.out.y, label: 'The churchyard', sub: 'Midnight to 3 AM' });
      if (ch && hr < 3 && Math.hypot(tx - ch.out.x, ty - ch.out.y) < 10 && !s.black.risen) this.churchyard(ch);
    }
    if (s.black.risen && !o.black && this.foes.filter((f) => f.blackLantern && !f.dead).length === 0) {
      this.give('black');
      g.ui.story('The Black Ring', `The last of them falls, and a ring crawls out of the grave dirt like a beetle and onto your finger. It is cold, colder than anything.\n\n${COL.black.oath}\n\nYou can hear heartbeats now. Everyone's. And under them, faint, from the direction of the Dustwater flats: something alive enough to hurt.\n\n(White: the Fear Man's dead tree, at dawn.)`);
    }
    // white: the dead tree blooms at dawn
    if (o.black && !o.white) {
      const ft = R.ring.fearSpot;
      if (ft) this.hint('white', 'Every black ring casts a white shadow. The Fear Man\'s dead tree has been dead a long time. Go there at dawn and see.', { x: ft.x, y: ft.y, label: 'The dead tree', sub: 'At dawn (5 to 7 AM)' });
      if (ft && near(ft, 6) && hr >= 5 && hr < 7) {
        this.give('white');
        for (let k = 0; k < 80; k++) g.fx.add({ x: ft.x * TS + 8 + (R.rng() - 0.5) * 30, y: ft.y * TS - R.rng() * 30, vx: (R.rng() - 0.5) * 40, vy: -20 - R.rng() * 60, life: 2, max: 2, c: R.rng() < 0.5 ? '#ffffff' : '#fff0f8', s: 2, glow: 1 });
        g.ui.story('The White Ring', `The dead tree cracks, and out of the crack comes a single white blossom, and out of the blossom comes light.\n\nThe black ring on your hand screams, and goes quiet, and the white one settles beside it.\n\n${COL.white.oath}\n\nNine lights. Every one of them yours. Somewhere very far away, the Fear Man looks up.`);
      }
    }
    // violet: Carol's crystal
    if (s.violet.stage && !o.violet && near(this.glade, 5) && night) {
      const p = loved();
      if (p) {
        this.give('violet');
        g.ui.story('The Violet Ring', `The crystal in the glade hums, then sings. It shows you ${g.pop.short(p)}'s face, lit from inside, and then there is a ring on your finger the colour of a bruise healing.\n\n${COL.violet.oath}\n\nIn the crystal, for a moment, another face: a woman with a staff, standing in a church doorway after dark, carrying something heavy that isn't there.\n\n(Indigo: a church, after dark.)`);
        const ch = this.nearestChurch(); if (ch) R.poi.add(ch.out.x, ch.out.y, 'tip', 'The woman with the staff', 'After dark');
      } else if (!this.violetNag || g.clock.real - this.violetNag > 30) { this.violetNag = g.clock.real; g.ui.toast('The crystal stays dark. It wants someone who loves you (a sweetheart or spouse at 60+).', 'warn'); }
    }
    // indigo: the woman with the staff, at the nearest church after dark
    if (o.violet && !o.indigo && night && !(this.indigoNpc && !this.indigoNpc.removed)) {
      const ch = this.nearestChurch();
      if (ch && Math.hypot(tx - ch.out.x, ty - ch.out.y) < 18) { this.indigoNpc = this.npc(ch.out.x * TS + 8, ch.out.y * TS + 12, 'indigo'); this.indigoNpc.strangerName = 'Woman with a staff'; }
    }
    if (this.indigoNpc && !night && !this.indigoNpc.removed) { g.actors.remove(this.indigoNpc); this.indigoNpc = null; }
    // blue: the Walker in the pines by day
    if (o.indigo && !o.blue) {
      this.hint('blue', 'The woman with the staff said one more thing, in a language you didn\'t know you knew: "Walker." Up in the Pinecrest pines there is a man who walks and does not stop. He carries hope the way she carries pain.', { x: this.walker.x, y: this.walker.y, label: 'The Walker', sub: 'Pinecrest pines, by day' });
      if (!night && near(this.walker, 24) && !(this.walkerNpc && !this.walkerNpc.removed)) { this.walkerNpc = this.npc(this.walker.x * TS + 8, this.walker.y * TS + 8, 'walker'); this.walkerNpc.strangerName = 'The Walker'; }
    }
  };

  // Larfleeze: the orange boss
  CP.spawnLarfleeze = function () {
    const g = G(), h = this.hoard;
    const L = this.spawnFoe(h.x * TS + 8, h.y * TS + 8, 'orange', LOOKS.larfleeze, 'Larfleeze', 1500);
    L.larfleeze = true; L.noLoot = false; L.keep = true; L.speedMul = 1.15;
    L.hostile = false; L.state = 'idle'; L.timer = 1e9; L.woke = false;
    this.larf = L;
  };
  CP.updateLarfleeze = function (dt) {
    const g = G(), pl = g.player, L = this.larf, s = this.state();
    if (!L || L.removed) return;
    if (L.dead) {
      if (!s.larf.dead) { s.larf.dead = true; g.ui.toast('Larfleeze is dead. Search his body: the ring, the lantern, all of it.', 'good'); g.pop.addNews('dust', 'Prospectors report "a thousand stolen hubcaps, three mailboxes and a hot-dog cart" piled in the Dustwater badlands. The owner could not be reached.'); }
      return;
    }
    const d = Math.hypot(L.x - pl.x, L.y - pl.y);
    if (!L.woke) {
      if (d < TS * 12) {
        L.woke = true; L.hostile = true; L.hostileLocked = true; L.stay = false; g.actors.setFight(L, pl);
        g.actors.say(L, 'MINE! You\'ve come for my lantern! EVERYONE comes for my lantern!');
        g.ui.toast('Larfleeze. He\'s small, he\'s old, and he\'s faster than he looks.', 'bad');
        g.cam.shake(4);
      }
      return;
    }
    if (L.state !== 'fight') { L.hostile = true; g.actors.setFight(L, pl); }
    const rage = L.hp < L.maxHp * 0.5;
    L.boltT = (L.boltT || 1) - dt;
    if (L.boltT <= 0 && d < TS * 14) { L.boltT = rage ? 0.55 : 0.95; this.foeBolt(L, pl, 'orange', rage ? 11 : 8); if (R.rng() < 0.2) g.actors.say(L, R.rng.pick(['MINE!', 'You can\'t have it!', 'I\'ll put you in my COLLECTION!', 'Give me your shoes! I want your SHOES!'])); }
    L.sumT = (L.sumT == null ? 4 : L.sumT) - dt;
    if (L.sumT <= 0) {
      L.sumT = rage ? 8 : 12;
      const n = rage ? 3 : 2;
      for (let i = 0; i < n; i++) {
        const a = R.rng() * 6.28;
        const f = this.spawnFoe(L.x + Math.cos(a) * 22, L.y + Math.sin(a) * 22, 'orange', tinted('orange', { fem: R.rng() < 0.5, age: 40 }, 'stolen' + R.rng.int(0, 1e5)), 'Stolen soul', 60, 30);
        f.boltCol = 'orange';
      }
      g.actors.say(L, rage ? 'Go! GO! Bring me back what\'s MINE!' : 'My collection will deal with you!');
    }
    if (rage && !L.raged) { L.raged = true; L.speedMul = 1.4; g.actors.say(L, 'NO! NO NO NO! You don\'t get to TAKE from ME!'); g.cam.shake(6); }
  };
  // the churchyard: the dead get up
  CP.churchyard = function (ch) {
    const g = G(), s = this.state();
    s.black.risen = true;
    g.cam.shake(6);
    g.ui.toast('The ground in the churchyard splits. Hands. Then the rest of them.', 'bad');
    for (let i = 0; i < 5; i++) {
      const sp = g.world.findNear(ch.out.x, ch.out.y + 2, 1, 6, (x, y) => !g.world.solidPed(x, y) && !g.world.isWater(x, y)) || { x: ch.out.x, y: ch.out.y + 2 };
      const f = this.spawnFoe(sp.x * TS + 8, sp.y * TS + 8, 'black', tinted('black', { fem: R.rng() < 0.5, age: 50 }, 'grave' + i), 'Black Lantern', 110, 0);
      f.blackLantern = true; f.boltCol = 'black';
      g.actors.say(f, R.rng.pick(['Rise.', 'Your heart is so loud.', 'Join us.']));
    }
  };

  // talking to the spectrum's people
  CP.tree = function (h) {
    const g = G(), pl = g.player, ui = g.ui, s = this.state(), fq = pl.fearQ || {};
    const say = (t) => ui.talkLine(t), opts = [];
    const k = h.corpsNpc;
    if (k === 'carol') {
      if (h.freed) {
        opts.push({ label: '"Hal\'s waiting for you."', fn: () => { say('Then I\'m going home. Tell him... no. I\'ll tell him myself. And you: that stone. Come see me. Come see the glade.'); ui.closeSheet(); fq.carolFreed = true; g.actors.remove(h); this.carol = null; g.ui.toast('Carol drives home. Tell Hal.', 'good'); } });
      } else opts.push({ label: '"Carol? Hal sent me."', fn: () => say('Hal? HAL doesn\'t get to have me. Nobody gets to have me. I am the Star Sapphire!') });
      return { title: h.freed ? 'Carol' : 'Star Sapphire', sub: h.freed ? 'A woman in a flight-school jacket, shaking. A violet stone hangs from her neck, quiet now.' : 'Violet light pours from a crystal on her brow.', options: opts.concat([{ label: 'Leave', fn: () => ui.closeSheet() }]) };
    }
    if (k === 'guy') {
      if (!h.beaten) {
        opts.push({ label: '"Hal Jordan sent me with this."', fn: () => say('JORDAN? That stiff? Whatever he\'s sellin\', I ain\'t buyin\'.') });
        opts.push({ label: 'Offer him the green ring', cls: 'go', fn: () => { say('Nobody gives Guy Gardner nothin\'. You want me wearin\' that, you go a round with me first. Fists. No funny lights.'); ui.closeSheet(); h.hostile = true; h.hostileLocked = true; h.noKill = true; h.stay = false; g.actors.setFight(h, pl); g.ui.toast('Guy Gardner wants a fistfight. Knock the wind out of him.', 'warn'); } });
      } else opts.push({ label: 'Hand him the ring', cls: 'go', fn: () => { say('...Huh. It fits. Tell Jordan I said nothin\'. And when that yellow creep shows his face, you call me.'); ui.closeSheet(); fq.guyRing = true; for (let i = 0; i < 20; i++) g.fx.add({ x: h.x, y: h.y - 10, vx: (R.rng() - 0.5) * 100, vy: -R.rng() * 200, life: 1, max: 1, c: '#50f070', s: 2, glow: 1 }); g.actors.remove(h); this.guy = null; g.ui.toast('Guy Gardner flies off, badly. Go tell Hal.', 'good'); } });
      return { title: 'Guy Gardner', sub: 'Gym coach. Bowl cut the colour of a fire truck. Whistle, attitude.', options: opts.concat([{ label: 'Leave', fn: () => ui.closeSheet() }]) };
    }
    if (k === 'indigo') {
      opts.push({ label: '"Who are you?"', fn: () => say('Nok. I carry what others feel. Yours is heavy. You have hurt people and been hurt by them.') });
      if (!s.owned.indigo) opts.push({ label: 'Share her burden (give $200 to the poor box)', small: pl.cash >= 200 ? 'Honor +3' : 'You need $200', cls: 'go', fn: () => {
        if (!pl.pay(200)) return say('The box is for what you can spare. Come back when you can.');
        pl.rep.honor = (pl.rep.honor || 0) + 3;
        say('There. Now feel it. Feel all of them.'); ui.closeSheet();
        this.give('indigo');
        g.ui.story('The Indigo Ring', `She presses her staff to your hand and there's a ring on it, deep violet-blue, and for a moment you feel what everyone on this street is feeling. It is a lot.\n\n${COL.indigo.oath}\n\nAs she walks away she says one more word: "Walker."`);
        g.actors.remove(h); this.indigoNpc = null;
      } });
      return { title: 'Nok', sub: 'A woman with a staff and tattoos across her face. She looks at you like she already knows.', options: opts.concat([{ label: 'Leave', fn: () => ui.closeSheet() }]) };
    }
    if (k === 'walker') {
      const calmed = s.indigo.calmed || 0;
      opts.push({ label: '"Who are you?"', fn: () => say('I walk. Where I walk, people remember that things can get better. All will be well.') });
      if (calmed >= 3) opts.push({ label: '"Nok sent me."', cls: 'go', fn: () => {
        say('I know. And you have ended fights with compassion instead of finishing them. Hope needs somewhere to stand. Here.'); ui.closeSheet();
        this.give('blue');
        g.ui.story('The Blue Ring', `The Walker opens his hand and there's a ring in it, blue as the sky over the pines.\n\n${COL.blue.oath}\n\n"Hope is not the absence of fear," he says. "It is what you do in its presence." Then he walks on.`);
        g.actors.remove(h); this.walkerNpc = null;
      } });
      else opts.push({ label: '"Nok sent me."', fn: () => say(`Then show me compassion. Three times, stop a fight with the indigo light instead of finishing it. (${calmed}/3)`) });
      return { title: 'The Walker', sub: 'Blue skin, white hair, bare feet on the pine needles. He is smiling.', options: opts.concat([{ label: 'Leave', fn: () => ui.closeSheet() }]) };
    }
    return null;
  };

  // Carol and Guy, for Hal's quests (called from the green path in 13_ringquest)
  const Q = R.fearQuest;
  Q.updateCarol = function (dt) {
    const g = G(), pl = g.player, s = this.state(), gq = this.gcurrent();
    if (!gq || gq.id !== 'carol' || s.carolFreed) return;
    const c = CP.glade, near = Math.hypot(pl.x / TS - c.x, pl.y / TS - c.y) < 30;
    if (!CP.carol && near) {
      const h = CP.npc(c.x * TS + 8, c.y * TS + 8, 'carol');
      h.strangerName = 'Star Sapphire'; h.hp = h.maxHp = 420; h.noKill = true;
      CP.carol = h;
    }
    const h = CP.carol;
    if (!h || h.removed) { CP.carol = null; return; }
    if (h.freed) return;
    const d = Math.hypot(h.x - pl.x, h.y - pl.y);
    if (!h.woke && d < TS * 9) { h.woke = true; h.hostile = true; h.hostileLocked = true; h.stay = false; g.actors.setFight(h, pl); g.actors.say(h, 'You\'re here to take me from the crystal. NOBODY takes me from the crystal!'); g.ui.toast('Carol is wearing the violet crystal, and the crystal is wearing her. Knock it out of her without killing her.', 'bad'); }
    if (!h.woke) return;
    if (h.state !== 'fight' && !h.freed) g.actors.setFight(h, pl);
    h.boltT = (h.boltT || 1) - dt;
    if (h.boltT <= 0 && d < TS * 12) { h.boltT = 1.1; CP.foeBolt(h, pl, 'violet', 8); }
    if (h.hp < h.maxHp * 0.35) {
      h.freed = true; h.hostile = false; h.hostileLocked = false; h.state = 'idle'; h.timer = 1e9; h.stay = true; h.strangerName = 'Carol'; h.target = null;
      for (let k = 0; k < 30; k++) g.fx.add({ x: h.x, y: h.y - 16, vx: (R.rng() - 0.5) * 160, vy: (R.rng() - 0.5) * 160, life: 0.8, max: 0.8, c: '#ffa0e0', s: 2, glow: 1 });
      g.actors.say(h, 'Where... where am I? Who are you?');
      g.ui.toast('The crystal cracks and goes quiet. Talk to Carol.', 'good');
    }
  };
  Q.updateGuy = function (dt) {
    const g = G(), pl = g.player, s = this.state(), gq = this.gcurrent();
    if (!gq || gq.id !== 'gardner' || s.guyRing) return;
    const b = this.school(), hr = g.clock.hour();
    if (!b) return;
    if (!CP.guy && hr >= 7 && hr < 16 && Math.hypot(pl.x / TS - b.out.x, pl.y / TS - b.out.y) < 24) { CP.guy = CP.npc(b.out.x * TS + 8, b.out.y * TS + 14, 'guy'); CP.guy.strangerName = 'Guy Gardner'; CP.guy.hp = CP.guy.maxHp = 260; }
    const h = CP.guy;
    if (!h || h.removed) { CP.guy = null; return; }
    if (h.hostile && !h.beaten && h.hp < h.maxHp * 0.4) {
      h.beaten = true; h.hostile = false; h.hostileLocked = false; h.state = 'idle'; h.timer = 1e9; h.stay = true; h.target = null;
      g.actors.say(h, 'Okay! OKAY. You hit like a truck. Gimme the stupid ring.');
      g.ui.toast('Guy yields. Give him the ring.', 'good');
    }
  };
  // Gardner shows up for the showdown
  const baseFight = Q.fightFearMan;
  Q.fightFearMan = function (fm) {
    const first = !fm.fearFight;
    const r = baseFight.call(this, fm);
    if (r && first && this.state().guyRing) {
      const g = G(), pl = g.player;
      const h = CP.spawnAlly(pl.x + 20, pl.y, 'green', LOOKS.guy, 'Guy Gardner', 120, 400);
      h.guyAlly = true;
      g.actors.say(h, 'Somebody call for a REAL Green Lantern?');
    }
    return r;
  };

  // ---------------------------------------------------------------- per-frame
  CP.update = function (dt) {
    const g = G(), pl = g.player;
    if (!g || !g.started) return;
    this.t -= dt;
    if (this.t <= 0) { this.t = 1; this.tick(); }
    this.updateLarfleeze(dt);
    const col = this.col(), s = this.state();
    // allies: bolt whoever's fighting you, then fade
    for (const a of this.allies) {
      if (a.dead || a.removed) continue;
      a.allyT -= dt;
      if (a.allyT <= 0) { g.fx.text(a.x, a.y - 26, a.corpsAlly === 'orange' ? '...back to the ring...' : a.guyAlly ? 'Later, rookie!' : '...', COL[a.corpsAlly] ? COL[a.corpsAlly].c : '#fff'); pl.dismiss(a); g.actors.remove(a); continue; }
      a.boltT = (a.boltT || R.rng()) - dt;
      if (a.boltT > 0) continue;
      const foe = g.actors.near(a.x, a.y, TS * 10, (q) => q.kind === 'h' && !q.dead && q.hostile && q.state === 'fight' && !q.crew)[0];
      if (!foe) continue;
      a.boltT = 1 + R.rng() * 0.5;
      const an = Math.atan2(foe.y - a.y, foe.x - a.x);
      R.ring.shots.push({ k: 'bolt', bolt: true, x: a.x + Math.cos(an) * 6, y: a.y - 10, vx: Math.cos(an) * 380, vy: Math.sin(an) * 380, t: 0, life: 0.6, rot: an, hits: new Set(), owner: a });
    }
    this.allies = this.allies.filter((a) => !a.dead && !a.removed);
    // foes: stolen souls fade; the black dead fire back
    for (const f of this.foes) {
      if (f.dead || f.removed || f.larfleeze) continue;
      if (f.allyT) { f.allyT -= dt; if (f.allyT <= 0) { g.actors.remove(f); continue; } }
      if (f.state !== 'fight') { f.hostile = true; g.actors.setFight(f, pl); }
      f.boltT = (f.boltT || 1 + R.rng()) - dt;
      if (f.boltT <= 0 && Math.hypot(f.x - pl.x, f.y - pl.y) < TS * 10) { f.boltT = 1.6 + R.rng(); this.foeBolt(f, pl, f.boltCol || 'orange', 6); }
    }
    this.foes = this.foes.filter((f) => !f.removed && !(f.dead && !f.larfleeze));
    // crystal prisons hold
    for (const a of g.actors.near(pl.x, pl.y, TS * 30)) if (a.crystalT > 0) { a.crystalT -= dt; a.vx = a.vy = 0; if (a.state !== 'dead') a.state = 'surrender'; if (a.crystalT <= 0) { a.crystalT = 0; a.timer = 0.5; } }
    // enemy bolts
    const fs = this.fshots || [];
    for (let i = fs.length - 1; i >= 0; i--) {
      const b = fs[i];
      b.t += dt; b.x += b.vx * dt; b.y += b.vy * dt;
      if (Math.hypot(b.x - pl.x, b.y - (pl.y - 10)) < 9 && !pl.inCar) { pl.hurt(b.dmg, b.src, 'blast'); pl.knock(Math.atan2(b.vy, b.vx), 80); fs.splice(i, 1); g.fx.text(pl.x, pl.y - 26, 'ZAP!', b.col === 'black' ? '#9a8ab0' : COL[b.col].c); continue; }
      let hit = null;
      for (const c of pl.crew) if (!c.dead && Math.hypot(b.x - c.x, b.y - (c.y - 10)) < 8) { hit = c; break; }
      if (hit) { R.combat.damage(hit, b.dmg, b.src, 'bullet'); fs.splice(i, 1); continue; }
      if (b.t > 1.4) fs.splice(i, 1);
    }
    // passive Will from each light
    if (!R.ring.owned() || pl.dead) return;
    const mx = pl.willMax || 100;
    if (col === 'blue') {
      pl.will = Math.min(mx, pl.will + dt * 8 * (1 - pl.hp / pl.maxHp));
      if (pl.will > mx * 0.5 && pl.hp < pl.maxHp) { pl.hp = Math.min(pl.maxHp, pl.hp + dt * 1.5); pl.will -= dt * 1.5; }
    }
    if (col === 'indigo') { let hurt = 0; for (const a of g.actors.near(pl.x, pl.y, TS * 8)) if (a.kind === 'h' && !a.dead && a.hp < a.maxHp * 0.7) hurt++; pl.will = Math.min(mx, pl.will + dt * Math.min(12, hurt * 3)); }
    if (col === 'violet') { let love = 0; for (const a of g.actors.near(pl.x, pl.y, TS * 8)) if (a.person && !a.dead && (a.person.opinion > 60 || a.person.id === pl.sweetheart || a.person.playerPartner)) love++; pl.will = Math.min(mx, pl.will + dt * Math.min(15, love * 4)); }
    if (col === 'black') { let dead = 0; for (const a of g.actors.near(pl.x, pl.y, TS * 8)) if (a.kind === 'h' && a.dead) dead++; pl.will = Math.min(mx, pl.will + dt * Math.min(15, dead * 3)); }
    if (col === 'white') pl.will = Math.min(mx, pl.will + dt * 2);
  };

  // ---------------------------------------------------------------- drawing (emissive layer)
  CP.draw = function (g) {
    const game = G(), pl = game.player, t = game.clock.real;
    const glowOf = (c) => (c === 'black' ? 'rgba(20,10,30,' : c === 'white' ? 'rgba(255,255,255,' : PAL[c] ? PAL[c].glow : c === 'yellow' ? 'rgba(255,226,60,' : 'rgba(80,240,110,');
    for (const a of this.allies.concat(this.foes)) {
      if (a.dead || a.removed) continue;
      const c = a.corpsAlly || a.corpsFoe;
      g.fillStyle = glowOf(c) + (0.16 + Math.sin(t * 4 + a.x) * 0.05) + ')';
      g.beginPath(); g.ellipse(a.x, a.y - 10, 9, 14, 0, 0, 7); g.fill();
      if (a.blackLantern) { g.fillStyle = '#f0f0ff'; g.fillRect(Math.round(a.x) - 2, Math.round(a.y) - 22, 1, 1); g.fillRect(Math.round(a.x) + 1, Math.round(a.y) - 22, 1, 1); }
    }
    // bosses: a health bar
    for (const b of [this.larf, this.carol]) {
      if (!b || b.dead || b.removed || !b.woke || b.freed) continue;
      g.fillStyle = '#1b1410'; g.fillRect(b.x - 21, b.y - 36, 42, 5);
      g.fillStyle = b === this.larf ? '#f07a18' : '#d040a8'; g.fillRect(b.x - 20, b.y - 35, 40 * Math.max(0, b.hp / b.maxHp), 3);
    }
    for (const n of [this.carol, this.indigoNpc, this.walkerNpc, this.larf]) {
      if (!n || n.dead || n.removed) continue;
      const c = n === this.carol ? (n.freed ? null : 'violet') : n === this.indigoNpc ? 'indigo' : n === this.walkerNpc ? 'blue' : 'orange';
      if (!c) continue;
      g.fillStyle = glowOf(c) + (0.2 + Math.sin(t * 3) * 0.08) + ')';
      g.beginPath(); g.ellipse(n.x, n.y - 10, 11, 16, 0, 0, 7); g.fill();
    }
    // violet crystal prisons
    for (const a of game.actors.near(pl.x, pl.y, TS * 30)) {
      if (!(a.crystalT > 0)) continue;
      const x = Math.round(a.x), y = Math.round(a.y);
      g.fillStyle = 'rgba(240,80,200,0.28)'; g.strokeStyle = 'rgba(255,160,224,0.9)'; g.lineWidth = 1;
      g.beginPath(); g.moveTo(x, y - 30); g.lineTo(x + 9, y - 14); g.lineTo(x + 6, y + 2); g.lineTo(x - 6, y + 2); g.lineTo(x - 9, y - 14); g.closePath(); g.fill(); g.stroke();
      g.fillStyle = 'rgba(255,255,255,0.6)'; g.fillRect(x - 4, y - 24, 1, 8);
    }
    // enemy bolts
    for (const b of this.fshots || []) {
      g.fillStyle = glowOf(b.col) + '0.35)'; g.beginPath(); g.arc(b.x, b.y, 5, 0, 7); g.fill();
      g.fillStyle = b.col === 'black' ? '#9a8ab0' : COL[b.col].c; g.fillRect(Math.round(b.x) - 1, Math.round(b.y) - 1, 3, 3);
    }
    // the black ring's emotional sight
    if (this.col() === 'black' && R.ring.owned() && !pl.inCar) {
      for (const a of game.actors.near(pl.x, pl.y, TS * 12)) {
        if (a.kind !== 'h' || a.dead || a === pl) continue;
        const c = a.state === 'flee' || a.state === 'cower' || a.state === 'surrender' ? '#f0c020' : a.hostile && a.state === 'fight' ? '#d02828' : a.person && a.person.opinion > 50 ? '#d040a8' : a.hp < a.maxHp * 0.6 ? '#5a38b8' : a.person && a.person.opinion > 20 ? '#3a80e8' : '#30c050';
        g.fillStyle = c; g.fillRect(Math.round(a.x) - 1, Math.round(a.y) - 30, 3, 3);
      }
    }
    // the sites glow
    const glade = this.glade, s = this.state();
    if (glade && s.violet.stage && !s.owned.violet) { const x = glade.x * TS + 8, y = glade.y * TS + 8; g.fillStyle = `rgba(240,80,200,${0.25 + Math.sin(t * 2) * 0.1})`; g.beginPath(); g.moveTo(x, y - 18); g.lineTo(x + 6, y - 6); g.lineTo(x, y + 2); g.lineTo(x - 6, y - 6); g.closePath(); g.fill(); }
  };

  // ---------------------------------------------------------------- wiring
  CP.ctx = 0;
  CP.init = function (game) {
    this.game = game;
    this.allies = []; this.foes = []; this.fshots = []; this.larf = null; this.carol = null; this.guy = null; this.indigoNpc = null; this.walkerNpc = null; this.t = 2;
    this.placeSites();
    const s = this.state();
    if (game.player.ringColor && COL[game.player.ringColor]) D.weapons.ring.name = COL[game.player.ringColor].name;
    if (this.wired) return;
    this.wired = true;
    const Ring = R.ring;
    // ring hits run through each colour's effect
    for (const m of ['updateShots', 'fireBeam', 'swing']) { const b = Ring[m]; Ring[m] = function () { CP.ctx++; try { return b.apply(this, arguments); } finally { CP.ctx--; } }; }
    const bDmg = R.combat.damage;
    R.combat.damage = function (a, amt, src, kind) {
      const g = G();
      if (a && a.noKill && !a.dead && amt >= a.hp) amt = Math.max(0, a.hp - 1);
      if (!CP.ctx || !g || src !== g.player || !a || a.kind !== 'h' || a.dead) return bDmg.apply(this, arguments);
      const col = CP.col();
      let m = col === 'red' ? 1.35 : col === 'blue' ? 0.6 : col === 'indigo' ? 0.5 : col === 'violet' ? 0.7 : col === 'black' ? 1.1 : 1;
      if (col === 'white' && a.blackLantern) m = 5;
      const args = Array.from(arguments); args[1] = amt * m;
      const r = bDmg.apply(this, args);
      CP.onHit(a, amt * m);
      return r;
    };
    // tap RING: the library for yellow and green, each other light's own power
    const bConj = Ring.conjure;
    Ring.conjure = function () { const c = CP.col(); return c === 'yellow' || c === 'green' ? bConj.apply(this, arguments) : CP.power(); };
    const bLib = Ring.openLibrary;
    Ring.openLibrary = function (summon) { const c = CP.col(); if (c === 'yellow' || c === 'green') return bLib.apply(this, arguments); if (summon) return CP.power(); return CP.openRings(false); };
    // greed: orange only fills from money that came dirty, and overfills
    const bUpd = Ring.update;
    Ring.update = function (dt) {
      const pl = this.game.player, mx = pl.willMax || 100;
      let over = 0;
      if (pl.will > mx) { over = pl.will - mx; pl.will = mx; }
      const w0 = pl.will;
      bUpd.call(this, dt);
      const col = CP.col();
      if (pl.will > w0 && col !== 'yellow') pl.will = w0 + (pl.will - w0) * (col === 'orange' ? 0.08 : col === 'red' ? 0.3 : 0.5);
      pl.will += over;
    };
    const PP = R.Player.prototype, bAdd = PP.addCash;
    PP.addCash = function (n, clean) {
      bAdd.apply(this, arguments);
      if (n > 0 && !clean && !(R.money && R.money.cleanDepth) && this === G().player && R.ring.owned() && CP.col() === 'orange') {
        const mx = this.willMax || 100;
        this.will = Math.min(mx * 2, this.will + Math.max(2, n * 0.5));
        if (n >= 20) G().fx.text(this.x, this.y - 34, 'GREED', '#ffc070');
      }
    };
    const bHurt = PP.hurt;
    PP.hurt = function (amt, src, kind) {
      const hp0 = this.hp;
      bHurt.apply(this, arguments);
      if (this === G().player && R.ring.owned() && CP.col() === 'red' && this.hp < hp0) this.will = Math.min(this.willMax || 100, this.will + (hp0 - this.hp) * 1.5);
    };
    // the white ring drags you back, once a day
    const bDie = PP.die;
    PP.die = function () {
      const g = G(), s = CP.state(), day = g.pop.day;
      if (this === g.player && s.owned.white && s.white.saved !== day) {
        s.white.saved = day;
        this.hp = this.maxHp * 0.5; this.dead = false;
        for (let k = 0; k < 40; k++) g.fx.add({ x: this.x, y: this.y - 10, vx: (R.rng() - 0.5) * 200, vy: (R.rng() - 0.5) * 200, life: 1, max: 1, c: '#ffffff', s: 2, glow: 1 });
        g.ui.toast('White light. You were dead for a second there. The ring says: not today.', 'good');
        return;
      }
      return bDie.apply(this, arguments);
    };
    // rage counts the day's kills
    const bKill = R.combat.kill;
    R.combat.kill = function (h, source) {
      const g = G(), was = h && h.dead;
      if (h && h.noKill && !h.dead) { h.hp = Math.max(1, h.hp); h.down = Math.max(h.down || 0, 1.5); return; }
      bKill.apply(this, arguments);
      if (!was && g && h && h.dead && h.kind === 'h' && (source === g.player || (source && source.driver === g.player))) {
        const s = CP.state();
        if (s.rage.day !== g.pop.day) { s.rage.day = g.pop.day; s.rage.n = 0; }
        s.rage.n++;
      }
    };
    // bodies: Larfleeze's hoard, Hal's empty hand, nothing on the conjured
    const bLoot = PP.loot;
    PP.loot = function (h) {
      const g = G();
      if (h && h.noLoot) { h.looted = true; return g.ui.toast('Nothing but light, going out.'); }
      const r = bLoot.apply(this, arguments);
      if (h && h.larfleeze && !CP.owns('orange')) {
        const s = CP.state();
        s.batt = s.batt || {}; s.batt.orange = 1;
        CP.give('orange', true);
        this.addCash(R.rng.int(400, 900));
        g.ui.story('The Orange Ring', `Under the rags: an orange ring, still warm, and a lantern he was hugging so hard it left a dent in his chest. And pockets. So many pockets.\n\n${COL.orange.oath}\n\nThe ring is hungry. Anyone you kill with it, it keeps, and you can let them out to fight for you. It fills on greed, the kind that comes from crimes that pay, and it doesn't stop at full.\n\n(Orange ring, orange lantern and the Orange Lantern wrap are yours.)`);
      }
      if (h && h.halBody) g.ui.toast('His hand is empty. The green ring left when he did, looking for someone without fear.', 'warn');
      return r;
    };
    // talking
    const bTree = R.dialog.tree;
    R.dialog.tree = function (h) { if (h && h.corpsNpc) { const t = CP.tree(h); if (t) return t; } return bTree.apply(this, arguments); };
    // the wardrobe: a Rings tab once you own two or more
    const U = R.UI.prototype, bSheet = U.openSheet;
    U.openSheet = function (id, html) {
      const s = bSheet.apply(this, arguments);
      if (id === 'wardrobe' && CP.count() > 1 && s) {
        const cats = s.querySelector('.wcats');
        if (cats && !cats.querySelector('[data-rings]')) {
          cats.insertAdjacentHTML('beforeend', '<button data-rings="1" style="border-color:#f0c020">Rings</button>');
          cats.querySelector('[data-rings]').addEventListener('click', (e) => { e.stopPropagation(); G().audio.sfx('click'); CP.openRings(true); });
        }
      }
      return s;
    };
    // draw after the Fear Man's glow
    const bDraw = R.fearQuest.draw;
    R.fearQuest.draw = function (g) { bDraw.apply(this, arguments); CP.draw(g); };
  };
})();
