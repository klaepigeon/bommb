// RHAPSODY — the Fear Man's lessons. Once you wear his ring he has five jobs for you,
// each a nod to the emerald-and-yellow space-cop saga he walked out of: fear taught on
// the streets, a lost power lantern, a green-ringed test pilot, a moth that eats
// courage, and a corps of your own. Every step pays out in new powers.
(function () {
  const D = R.data, TS = R.TILE, T = D.T;
  const GLOW = 'rgba(255,226,60,';
  const GREEN = 'rgba(80,240,110,';
  // the oath is our own words, recited at the lantern
  const OATH = 'By dread of dark and fear of light,\nI bind the brave and bend their might.\nLet all who stand against my sight\nlearn terror\'s yellow, burning bright.';

  const QUESTS = [
    { id: 'lesson', title: 'The First Lesson', goal: 'Frighten 6 people in a single night (antagonize, draw on them, or use the ring).',
      give: 'Order is a kind of fear, properly applied. Go out tonight and teach six of them to step aside for you. Then come back.',
      done: 'Better. You have the gift. Wear this: on my world it meant the law.', reward: 'His blue-and-black uniform (free at any tailor), +25 max Will.' },
    { id: 'lantern', title: 'A Lantern for the Light', goal: 'Find the Fear Man\'s power lantern in the wreck of his ship, high in the northern snows.',
      give: 'My ship came down in the snow north of Pinecrest. My lantern is in the wreck. Things came through with me, from the anti-matter side. They will not want to give it up.',
      done: 'The lantern. Speak the words and the ring drinks its fill. Once a day. Do not abuse it.', reward: 'The Power Lantern: recharge Will to full once a day. Constructs hit harder.' },
    { id: 'pilot', title: 'The Emerald Pilot', goal: 'Find the green-ringed test pilot out on the Dustwater airstrip (daytime) and beat him in a duel.',
      give: 'There is a man in a flight jacket out on the Dustwater strip with a green ring. His kind chased me off a thousand worlds. He fills people with nerve. Show him what nerve is worth.',
      done: 'He ran. They always run, eventually. You have learned to hold the light steady.', reward: 'Duelist\'s Edge: ring bolts hit 50% harder, the beam costs half.' },
    { id: 'moth', title: 'The Moth of Fear', goal: 'At night in Port Hollow, free the possessed and drive off the great yellow moth with the ring.',
      give: 'Something followed me. A moth the size of a house, made of fear itself. It is feeding on Port Hollow at night, wearing people like coats. Burn it off them.',
      done: 'Gone, for now. It will be back in some other century. You have its taste in your ring.', reward: 'Fear Aura: when you\'re badly hurt, enemies may break and run. Constructs cost a quarter less.' },
    { id: 'corps', title: 'A Corps of Your Own', goal: 'Give three lesser rings to people who fear you (fear 50+): Talk to them.',
      give: 'Every lantern needs a corps. Here: three lesser rings. Find three who fear you, and let them carry a little of it.',
      done: 'A corps. Small, badly dressed, but a corps. I can go home now. Keep the light burning, Nicky.', reward: 'The Fear Corps: your ring-bearers fight beside you with bolts of yellow light.' },
  ];

  const Q = (R.fearQuest = { game: null });
  Q.init = function (game) {
    this.game = game;
    this.scared = new Set();
    this.night = -1;
    this.moth = null;
    this.greens = [];
    this.placeSites();
  };
  Q.state = function () { const pl = this.game.player; return (pl.fearQ = pl.fearQ || { stage: 0, active: false, perks: {}, progress: 0, rings: 0 }); };
  Q.perk = function (k) { const s = this.game && this.game.player && this.game.player.fearQ; return !!(s && s.perks[k]); };
  Q.current = function () { const s = this.state(); return s.stage < QUESTS.length ? QUESTS[s.stage] : null; };

  // where things are: the ship wreck in the snow, the airstrip in the desert
  Q.placeSites = function () {
    const w = this.game.world;
    const rnd = R.mulberry(w.seed * 3 + 71);
    const pine = w.cities.find((c) => c.id === 'pine'), dust = w.cities.find((c) => c.id === 'dust');
    const find = (cx, cy, r0, r1, pred) => { for (let k = 0; k < 600; k++) { const a = rnd() * 6.28, r = r0 + rnd() * (r1 - r0); const x = Math.round(cx + Math.cos(a) * r), y = Math.round(cy + Math.sin(a) * r); if (w.inb(x, y) && pred(x, y)) return { x, y }; } return null; };
    const open = (x, y) => !w.isWater(x, y) && !w.bid[w.idx(x, y)] && !D.roadTile[w.t(x, y)] && !w.inCityRect(x, y, 10);
    this.wreck = find(pine.cx, pine.cy - 20, 40, 110, (x, y) => (w.t(x, y) === T.SNOW || w.t(x, y) === T.ROCK || w.t(x, y) === T.FOREST) && open(x, y) && y < pine.cy) || { x: pine.cx, y: Math.max(8, pine.y0 - 40) };
    this.strip = find(dust.cx, dust.cy, dust.nbx * 13 + 20, dust.nbx * 13 + 60, (x, y) => w.biomeAt(x, y) === 'desert' && open(x, y)) || { x: dust.cx + 70, y: dust.cy };
    // clear and mark the crash and the airstrip
    const clear = (s, r) => { for (let yy = s.y - r; yy <= s.y + r; yy++) for (let xx = s.x - r; xx <= s.x + r; xx++) if (w.inb(xx, yy) && !w.bid[w.idx(xx, yy)]) w.obj[w.idx(xx, yy)] = 0; };
    clear(this.wreck, 5);
    for (let k = 0; k < 7; k++) { const a = k * 0.9, xx = Math.round(this.wreck.x + Math.cos(a) * 5), yy = Math.round(this.wreck.y + Math.sin(a) * 4); if (w.inb(xx, yy)) w.obj[w.idx(xx, yy)] = D.O.BOULDER; }
    for (let xx = this.strip.x - 14; xx <= this.strip.x + 14; xx++) for (let yy = this.strip.y - 1; yy <= this.strip.y + 1; yy++) if (w.inb(xx, yy) && !w.bid[w.idx(xx, yy)] && !w.isWater(xx, yy)) { w.tile[w.idx(xx, yy)] = T.DIRTROAD; w.obj[w.idx(xx, yy)] = 0; }
  };

  // ---------------------------------------------------------------- talking to him
  Q.options = function (h, say, close) {
    const g = this.game, pl = g.player, s = this.state(), q = this.current();
    const opts = [];
    if (!q) { opts.push({ label: '"What now?"', fn: () => say('Now you keep order. I am going home to Korugar... to what is left of it.') }); return opts; }
    if (!s.active) {
      opts.push({ label: `"Got something for me?" (${q.title})`, cls: 'go', fn: () => { s.active = true; s.progress = 0; say(q.give); this.onStart(q); g.ui.toast(`Fear Man: ${q.title}. ${q.goal}`, 'good'); } });
    } else if (this.complete(q)) {
      opts.push({ label: `"It's done." (${q.title})`, cls: 'go', fn: () => { say(q.done); this.finish(q); } });
    } else opts.push({ label: `"About ${q.title.toLowerCase()}..."`, fn: () => say(`${q.goal} ${this.progressText(q)}`) });
    if (pl.wardrobe && pl.wardrobe['unlock:fearsuit'] && pl.style.shirt !== 'fearblue') opts.push({ label: 'Put on his uniform', fn: () => { this.suitUp(); say('Now you look like someone.'); } });
    return opts;
  };
  Q.progressText = function (q) {
    const s = this.state();
    if (q.id === 'lesson') return `(${this.scared.size}/6 tonight)`;
    if (q.id === 'lantern') return this.game.player.inv.tools.lantern ? '(You have it.)' : '(Still in the wreck.)';
    if (q.id === 'pilot') return s.pilotBeaten ? '(He ran.)' : '(Unfinished.)';
    if (q.id === 'moth') return s.mothDone ? '(The moth is gone.)' : '(It still feeds.)';
    if (q.id === 'corps') return `(${s.rings}/3 rings given)`;
    return '';
  };
  Q.complete = function (q) {
    const s = this.state(), pl = this.game.player;
    if (q.id === 'lesson') return s.lessonDone;
    if (q.id === 'lantern') return !!pl.inv.tools.lantern;
    if (q.id === 'pilot') return !!s.pilotBeaten;
    if (q.id === 'moth') return !!s.mothDone;
    if (q.id === 'corps') return s.rings >= 3;
    return false;
  };
  Q.onStart = function (q) {
    const P = R.poi;
    if (q.id === 'lantern') P.add(this.wreck.x, this.wreck.y, 'tip', 'Crashed ship', 'The Fear Man\'s lantern');
    if (q.id === 'pilot') P.add(this.strip.x, this.strip.y, 'tip', 'Dustwater airstrip', 'The emerald pilot');
    if (q.id === 'moth') { const c = this.game.world.cities[0]; P.add(c.cx, c.cy, 'tip', 'The Moth of Fear', 'Port Hollow, at night'); }
    if (q.id === 'corps') this.state().rings = 0;
  };
  Q.finish = function (q) {
    const g = this.game, pl = g.player, s = this.state();
    s.stage++; s.active = false;
    g.audio.sfx('promote');
    if (q.id === 'lesson') { pl.wardrobe = pl.wardrobe || {}; pl.wardrobe['unlock:fearsuit'] = 1; s.perks.suit = 1; pl.willMax = (pl.willMax || 100) + 25; pl.will = pl.willMax; }
    if (q.id === 'lantern') s.perks.lantern = 1;
    if (q.id === 'pilot') s.perks.duel = 1;
    if (q.id === 'moth') s.perks.aura = 1;
    if (q.id === 'corps') { s.perks.corps = 1; g.pop.addNews('dust', 'The yellow light over the Dustwater flats is gone. Truckers say it went straight up.'); }
    g.ui.story(`${q.title}: done`, `${q.done}\n\nReward: ${q.reward}`);
    if (q.id === 'corps') setTimeout(() => { if (R.ring.fearMan) { g.fx.text(R.ring.fearMan.x, R.ring.fearMan.y - 24, 'Farewell.', '#fff27a'); R.ring.goneForever = true; } }, 500);
  };
  Q.suitUp = function () {
    const pl = this.game.player;
    Object.assign(pl.style, { jacket: 'none', shirt: 'fearblue', top: 'turtle', pants: 'fearblack', hat: 'none' });
    pl.buildLook();
    this.game.ui.toast('Blue and black. People cross the street when they see you coming.', 'good');
  };

  // ---------------------------------------------------------------- tracking
  // people you frighten tonight (lesson one); hooks the actor fear states
  Q.scare = function (h) {
    const s = this.state(), q = this.current();
    if (!q || q.id !== 'lesson' || !s.active || s.lessonDone || !h || h.kind !== 'h' || h.dead) return;
    const g = this.game, night = Math.floor((g.clock.t - 300) / 1440);
    if (!g.clock.isNight()) return;
    if (night !== this.night) { this.night = night; this.scared.clear(); }
    if (this.scared.has(h)) return;
    this.scared.add(h);
    g.fx.text(h.x, h.y - 26, `FEAR ${this.scared.size}/6`, '#fff27a');
    if (this.scared.size >= 6) { s.lessonDone = true; g.ui.toast('Six of them. The Fear Man will want to hear about it.', 'good'); }
  };
  (function hookFear() {
    const AP = R.Actors.prototype;
    for (const m of ['setFlee', 'setCower']) {
      const base = AP[m];
      AP[m] = function (h, from, secs) {
        const r = base.apply(this, arguments);
        if ((from === this.game.player || (from && from.driver === this.game.player)) && R.fearQuest.game) R.fearQuest.scare(h);
        return r;
      };
    }
  })();

  // ---------------------------------------------------------------- per frame
  Q.update = function (dt) {
    const g = this.game, pl = g.player, s = this.state(), q = this.current();
    // lantern recharge cooldown
    // quest encounters
    if (q && s.active) {
      if (q.id === 'lantern') this.updateWreck(dt);
      if (q.id === 'pilot') this.updatePilot(dt);
      if (q.id === 'moth') this.updateMoth(dt);
    }
    this.updateGreens(dt);
    if (s.perks.corps) this.updateCorps(dt);
  };

  // the wreck: guardians from the anti-matter side, and the lantern in the snow
  Q.updateWreck = function () {
    const g = this.game, pl = g.player, w = this.wreck;
    const d = Math.hypot(pl.x / TS - w.x, pl.y / TS - w.y);
    if (d < 30 && !this.guards && !pl.inv.tools.lantern) {
      this.guards = [];
      for (let k = 0; k < 3; k++) {
        const h = g.actors.makeHuman((w.x + 3 - k * 3) * TS, (w.y + 3) * TS, { tag: 'qward', weapon: 'knife', cash: 0,
          look: { fem: false, age: 40, skin: '#402050', hair: '#000', top: '#201030', bottom: '#100818', seedStr: 'qward' + k, oldOverride: { skin: ['#1a0a24', '#2c1238', '#401c50', '#5a2a6a'], style: 'bald', jacket: ['#08040c', '#120818', '#1c0c24', '#281030'], shirt: ['#08040c', '#120818', '#1c0c24', '#281030'], pants: ['#08040c', '#120818', '#1c0c24', '#281030'], glasses: true } } });
        h.strangerName = 'Shadow Man'; h.keep = true; h.hostile = true; h.hostileLocked = true; h.tr.brave = 1; h.hp = h.maxHp = 90;
        g.actors.setFight(h, pl);
        this.guards.push(h);
      }
      g.ui.toast('Grey men with no faces climb out of the wreck. They don\'t cast shadows. They ARE shadows.', 'warn');
    }
  };
  Q.context = function (pl) {
    const s = this.state(), q = this.current();
    // the lantern in the wreck
    if (q && s.active && q.id === 'lantern' && !pl.inv.tools.lantern && Math.hypot(pl.x / TS - this.wreck.x, pl.y / TS - this.wreck.y) < 2.2)
      return { label: 'Take the lantern', fn: () => { pl.inv.tools.lantern = 1; this.game.audio.sfx('promote'); this.game.ui.story('The Power Lantern', 'A squat lantern of yellow metal, warm as a stove. The ring on your hand hums when you hold it close.\n\nTake it back to the Fear Man.'); } };
    return null;
  };
  // recite the oath at the lantern (inventory action)
  Q.charge = function () {
    const g = this.game, pl = g.player, s = this.state();
    const day = Math.floor(g.clock.t / 1440);
    if (!s.perks.lantern) return g.ui.toast('The lantern is cold. Bring it to the Fear Man first.', 'warn');
    if (s.chargedDay === day) return g.ui.toast('The lantern needs a day to glow again.', 'warn');
    s.chargedDay = day;
    pl.will = pl.willMax || 100;
    g.audio.sfx('coolOn');
    for (let k = 0; k < 24; k++) g.fx.add({ x: pl.x, y: pl.y - 10, vx: (R.rng() - 0.5) * 160, vy: (R.rng() - 0.5) * 160, life: 0.8, max: 0.8, c: '#fff27a', s: 2, glow: 1 });
    g.ui.story('The Oath', OATH + '\n\n(Will fully charged.)');
  };

  // the emerald pilot: a duel on the Dustwater airstrip
  Q.updatePilot = function (dt) {
    const g = this.game, pl = g.player, s = this.state(), st = this.strip;
    const h = g.clock.hour();
    const near = Math.hypot(pl.x / TS - st.x, pl.y / TS - st.y) < 32;
    if (!this.pilot && near && h > 7 && h < 19 && !s.pilotBeaten) {
      const p = g.actors.makeHuman(st.x * TS + 8, st.y * TS + 8, { tag: 'pilot', cash: 0, arch: 'tough',
        look: { fem: false, age: 32, skin: '#e0ac7e', hair: '#5a3a20', top: '#6a4a2a', bottom: '#2a3a2a', seedStr: 'pilot', oldOverride: { style: 'short', jacket: ['#3a2410', '#5a3a1c', '#7c5228', '#a06c38'], shirt: ['#1a4a24', '#2a6a34', '#3a8a48', '#5aaa68'], pants: ['#1a2a1a', '#243424', '#344a34', '#4a6a4a'], glasses: false } } });
      p.strangerName = 'Test Pilot'; p.keep = true; p.hp = p.maxHp = 320; p.tr.brave = 1; p.pilot = true;
      g.actors.say(p, 'Nice ring. Wrong color, pal.');
      this.pilot = p;
    }
    const p = this.pilot;
    if (!p) return;
    if (p.dead || !g.actors.list.includes(p)) { this.pilot = null; if (p.dead) { s.pilotBeaten = true; g.ui.toast('The pilot is down. His ring flickers out. That will do.', 'good'); } return; }
    if (p.hp < p.maxHp * 0.2 && !s.pilotBeaten) {
      s.pilotBeaten = true;
      g.actors.say(p, 'Okay, okay! You win this round. In brightest day, pal!');
      g.actors.setFlee(p, pl, 30);
      g.ui.toast('The pilot runs for his plane. Tell the Fear Man.', 'good');
    }
    if (s.pilotBeaten) return;
    // he fights back with green light
    if (p.hp < p.maxHp && p.state !== 'fight') { p.hostile = true; g.actors.setFight(p, pl); }
    if (p.state === 'fight') {
      p.greenT = (p.greenT || 0) - dt;
      if (p.greenT <= 0 && Math.hypot(p.x - pl.x, p.y - pl.y) < TS * 12) {
        p.greenT = 1.4 + R.rng();
        const a = Math.atan2(pl.y - 10 - (p.y - 10), pl.x - p.x);
        this.greens.push({ x: p.x, y: p.y - 10, vx: Math.cos(a) * 190, vy: Math.sin(a) * 190, t: 0, glove: R.rng() < 0.4 });
        if (R.rng() < 0.3) g.actors.say(p, R.rng.pick(['Boxing glove!', 'Got a jet with your name on it!', 'Fear\'s got nothing on will, pal!']));
      }
    }
  };
  Q.updateGreens = function (dt) {
    const g = this.game, pl = g.player;
    for (let i = this.greens.length - 1; i >= 0; i--) {
      const b = this.greens[i];
      b.t += dt; b.x += b.vx * dt; b.y += b.vy * dt;
      if (Math.hypot(b.x - pl.x, b.y - (pl.y - 10)) < 10 && !pl.inCar) { pl.hurt((b.glove ? 14 : 9) * (b.yellow ? 1.3 : 1), b.yellow ? R.ring.fearMan : this.pilot || null, 'blast'); pl.knock(Math.atan2(b.vy, b.vx), b.glove ? 180 : 80); this.greens.splice(i, 1); g.fx.text(pl.x, pl.y - 26, b.glove ? 'POW!' : 'ZING!', b.yellow ? '#ffe23c' : '#70f080'); continue; }
      if (b.t > 1.4) this.greens.splice(i, 1);
    }
  };

  // the moth: a fear-eater over Port Hollow at night, riding possessed townsfolk
  Q.updateMoth = function (dt) {
    const g = this.game, pl = g.player, s = this.state();
    const c = g.world.cities[0];
    const inTown = g.world.cityAt((pl.x / TS) | 0, (pl.y / TS) | 0) === c;
    if (!this.moth && inTown && g.clock.isNight() && !s.mothDone && !pl.room) {
      this.moth = { x: pl.x + 90, y: pl.y - 30, hp: 360, maxHp: 360, t: 0, hosts: [] };
      for (let k = 0; k < 3; k++) {
        const hsp = g.world.findNear(pl.x / TS, pl.y / TS, 5, 10, (x, y) => !g.world.solidPed(x, y) && !g.world.isWater(x, y));
        if (!hsp) continue;
        const h = g.actors.makeHuman(hsp.x * TS + 8, hsp.y * TS + 8, {});
        h.possessed = true; h.keep = true; h.hostile = true; h.hostileLocked = true; h.tr.brave = 1; h.strangerName = 'Possessed';
        g.actors.setFight(h, pl);
        this.moth.hosts.push(h);
      }
      g.ui.toast('A shape the size of a house blots out the moon. Yellow wings. Three people with yellow eyes turn toward you.', 'bad');
    }
    const m = this.moth;
    if (!m) return;
    m.t += dt;
    m.x += (pl.x + Math.cos(m.t * 0.7) * 70 - m.x) * dt * 0.8;
    m.y += (pl.y - 40 + Math.sin(m.t * 1.1) * 30 - m.y) * dt * 0.8;
    // freed hosts: knocked out or killed
    for (const h of m.hosts) if (h.possessed && (h.dead || h.down > 0)) { h.possessed = false; h.hostile = false; if (!h.dead) g.actors.say(h, 'Where... where am I?'); }
    // it swoops at you
    m.swoopT = (m.swoopT || 3) - dt;
    if (m.swoopT <= 0 && !pl.inCar) { m.swoopT = 3 + R.rng() * 2; if (Math.hypot(m.x - pl.x, m.y - pl.y) < 70) { pl.hurt(10, null, 'blast'); g.cam.shake(4); g.fx.text(pl.x, pl.y - 28, 'DREAD', '#f0c020'); } }
    if (m.hp <= 0) {
      this.moth = null;
      s.mothDone = true;
      for (const h of m.hosts) if (h.possessed) { h.possessed = false; h.hostile = false; }
      for (let k = 0; k < 40; k++) g.fx.add({ x: m.x, y: m.y, vx: (R.rng() - 0.5) * 220, vy: (R.rng() - 0.5) * 220, life: 1.2, max: 1.2, c: R.rng() < 0.5 ? '#fff27a' : '#f0c020', s: 3, glow: 1 });
      g.ui.toast('The moth shreds into yellow light and is gone. The Fear Man will know.', 'good');
      g.pop.addNews('port', 'Residents of Port Hollow report "a terrible dream" last night, then a light show over the harbor.');
    }
  };
  // ring fire can hit the moth
  Q.hitTest = function (x, y, dmg) {
    const m = this.moth;
    if (!m || Math.hypot(x - m.x, y - m.y) > 26) return false;
    m.hp -= dmg;
    m.hurtT = 0.15;
    return true;
  };

  // your corps: ring-bearers who fire yellow bolts at whoever you're fighting
  Q.updateCorps = function (dt) {
    const g = this.game, pl = g.player;
    for (const c of pl.crew) {
      if (!c.fearRing || c.dead || c.inCar) continue;
      c.boltT = (c.boltT || 0) - dt;
      if (c.boltT > 0) continue;
      const foe = g.actors.near(c.x, c.y, TS * 10, (a) => a.kind === 'h' && !a.dead && a.hostile && a.state === 'fight' && !a.crew)[0];
      if (!foe) continue;
      c.boltT = 1.1 + R.rng() * 0.6;
      const a = Math.atan2(foe.y - c.y, foe.x - c.x);
      R.ring.shots.push({ k: 'bolt', bolt: true, x: c.x + Math.cos(a) * 6, y: c.y - 10, vx: Math.cos(a) * 380, vy: Math.sin(a) * 380, t: 0, life: 0.6, rot: a, hits: new Set(), owner: c });
    }
  };
  // give a lesser ring (talk option on people who fear you)
  Q.canGiveRing = function (h) {
    const s = this.state(), q = this.current();
    return q && q.id === 'corps' && s.active && s.rings < 3 && h.person && (h.person.fear || 0) >= 50 && !h.fearRing && !h.cop && !h.look.kid;
  };
  Q.giveRing = function (h) {
    const g = this.game, pl = g.player, s = this.state();
    s.rings++;
    h.fearRing = true;
    if (!h.crew) pl.recruit(h);
    h.person.opinion = Math.max(h.person.opinion, 40);
    g.actors.say(h, R.rng.pick(['It\'s... warm. I can feel it watching.', 'Yes sir. Whatever you say, sir.', 'I never felt so... tall.']));
    g.ui.toast(`${s.rings}/3 ring-bearers.`, 'good');
  };

  // ---------------------------------------------------------------- drawing (emissive layer)
  Q.draw = function (g) {
    const t = this.game.clock.real;
    // the wreck glows in the snow
    const w = this.wreck, pl = this.game.player;
    if (w && Math.abs(w.x * TS - pl.x) < 400 && Math.abs(w.y * TS - pl.y) < 300) {
      const x = w.x * TS + 8, y = w.y * TS + 8;
      g.fillStyle = '#2a2a34'; g.beginPath(); g.ellipse(x, y + 4, 34, 12, 0, 0, 7); g.fill();
      g.fillStyle = '#6a6a78'; g.beginPath(); g.moveTo(x - 30, y); g.lineTo(x + 10, y - 16); g.lineTo(x + 26, y - 4); g.lineTo(x - 6, y + 8); g.closePath(); g.fill();
      g.fillStyle = '#9a9aa8'; g.fillRect(x - 12, y - 10, 16, 3);
      if (!pl.inv.tools.lantern) {
        g.fillStyle = GLOW + (0.2 + Math.sin(t * 3) * 0.08) + ')'; g.beginPath(); g.arc(x, y - 2, 14, 0, 7); g.fill();
        g.fillStyle = '#b88400'; g.fillRect(x - 3, y - 8, 7, 9); g.fillStyle = '#fff27a'; g.fillRect(x - 2, y - 7, 5, 6);
      }
    }
    // green constructs from the pilot
    for (const b of this.greens) {
      g.fillStyle = (b.yellow ? 'rgba(255,226,60,' : GREEN) + '0.35)'; g.beginPath(); g.arc(b.x, b.y, b.glove ? 7 : 4, 0, 7); g.fill();
      g.fillStyle = b.yellow ? '#ffe23c' : '#70f080';
      if (b.glove) { g.fillRect(b.x - 4, b.y - 4, 8, 7); g.fillRect(b.x - 6, b.y - 2, 3, 4); }
      else g.fillRect(b.x - 2, b.y - 2, 4, 4);
    }
    if (this.pilot && !this.pilot.dead) { const p = this.pilot; g.fillStyle = GREEN + (0.5 + Math.sin(t * 5) * 0.2) + ')'; g.fillRect(Math.round(p.x) + 3, Math.round(p.y) - 11, 2, 2); }
    // possessed eyes
    if (this.moth) for (const h of this.moth.hosts) if (h.possessed && !h.dead) { g.fillStyle = '#fff27a'; g.fillRect(Math.round(h.x) - 3, Math.round(h.y) - 19, 2, 1); g.fillRect(Math.round(h.x) + 1, Math.round(h.y) - 19, 2, 1); }
    const m = this.moth;
    if (m) {
      const flap = Math.sin(t * 9) * 0.6;
      g.fillStyle = GLOW + '0.12)'; g.beginPath(); g.arc(m.x, m.y, 60, 0, 7); g.fill();
      g.save(); g.translate(m.x, m.y);
      for (const sgn of [-1, 1]) {
        g.fillStyle = m.hurtT > 0 ? '#ffffff' : '#c89a10';
        g.beginPath(); g.ellipse(sgn * 18, -4, 20, 12 * (1 + flap * sgn * 0.3), sgn * 0.4, 0, 7); g.fill();
        g.fillStyle = '#f0c020'; g.beginPath(); g.ellipse(sgn * 16, 10, 12, 8, -sgn * 0.3, 0, 7); g.fill();
        g.fillStyle = '#6a4600'; g.beginPath(); g.arc(sgn * 18, -4, 5, 0, 7); g.fill();
      }
      g.fillStyle = '#3a2800'; g.fillRect(-3, -14, 6, 28);
      g.fillStyle = '#ff3020'; g.fillRect(-3, -14, 2, 2); g.fillRect(1, -14, 2, 2);
      g.restore();
      if (m.hurtT > 0) m.hurtT -= 1 / 60;
      // health bar
      g.fillStyle = '#1b1410'; g.fillRect(m.x - 21, m.y - 34, 42, 5);
      g.fillStyle = '#f0c020'; g.fillRect(m.x - 20, m.y - 33, 40 * Math.max(0, m.hp / m.maxHp), 3);
    }
    // your corps' rings
    for (const c of pl.crew) if (c.fearRing && !c.dead) { g.fillStyle = GLOW + '0.7)'; g.fillRect(Math.round(c.x) + 3, Math.round(c.y) - 6, 2, 2); }
  };
  // Fear Aura: badly hurt, you frighten the people fighting you
  Q.onPlayerHurt = function () {
    const g = this.game, pl = g.player;
    if (!this.perk('aura') || pl.hp > pl.maxHp * 0.35 || g.clock.real - (this.auraT || -99) < 12) return;
    this.auraT = g.clock.real;
    let n = 0;
    for (const a of g.actors.near(pl.x, pl.y, TS * 9)) if (a.kind === 'h' && !a.dead && a.hostile && !a.hostileLocked && R.rng() < 0.7) { g.actors.setFlee(a, pl, 6); g.actors.say(a, R.rng.pick(['Its EYES!', 'No no no no!', 'Get away from me!'])); n++; }
    if (n) { g.fx.text(pl.x, pl.y - 30, 'FEAR AURA', '#fff27a'); for (let k = 0; k < 30; k++) g.fx.add({ x: pl.x, y: pl.y - 10, vx: (R.rng() - 0.5) * 240, vy: (R.rng() - 0.5) * 240, life: 0.6, max: 0.6, c: '#f0c020', s: 2, glow: 1 }); }
  };
})();

// ---------------------------------------------------------------- the green path
// Talk to the test pilot instead of fighting him and you can side with Hal: prove you
// protect people, earn a green ring, uniform and power battery, then face the Fear Man.
// He cannot be killed. At the brink he goes up like a flare, and that's another story.
(function () {
  const D = R.data, TS = R.TILE, Q = R.fearQuest;
  const GREEN_OATH = 'When all is dark and hope is slight,\nI hold the line with all my might.\nLet every fear that stalks the night\nfall back before my will\'s green light.';
  const GQ = [
    { id: 'protect', title: 'Prove It', goal: 'Take off the yellow ring and protect people: put down 5 muggers, robbers or thugs who are hurting someone.',
      give: 'That ring runs on fear. It\'ll hollow you out. Take it off. Show me you\'d stand up for somebody, five times, and I\'ll show you a better light.',
      done: 'You did good. Here. Hold it up to the battery, say the words, and mean them.', reward: 'The green ring (bolts, beam and constructs in green; Will returns faster near people who like you), the green-and-black uniform and a power battery.' },
    { id: 'showdown', title: 'Face the Fear Man', goal: 'Confront the Fear Man under his dead tree between 1 and 4 AM. He will not go quietly.',
      give: 'He knows by now. He\'ll be waiting at that tree, and he\'ll be angry. I\'d go with you but somebody has to watch the sky. Don\'t let him scare you. That\'s all he\'s got.',
      done: '', reward: 'Emerald Knight: constructs cost a quarter less, the bubble shield lasts twice as long, and you can call Hal for backup from any payphone.' },
  ];

  Q.gcurrent = function () { const s = this.state(); return s.path === 'green' && s.gstage < GQ.length ? GQ[s.gstage] : null; };
  Q.perkG = (k) => { const s = R.game && R.game.player && R.game.player.fearQ; return !!(s && s.gperks && s.gperks[k]); };

  // the pilot's conversation, instead of a fight
  Q.pilotTree = function (h) {
    const g = this.game, pl = g.player, s = this.state(), ui = g.ui;
    const say = (t) => ui.talkLine(t);
    const opts = [];
    const gq = this.gcurrent();
    if (s.path !== 'green') {
      opts.push({ label: '"Who are you?"', fn: () => say('Hal. I fly test planes out of this strip. Among other things. That ring on your hand... where\'d you get it?') });
      opts.push({ label: '"The Fear Man sent me."', fn: () => say('Then you\'re wearing his leash. That ring feeds on fear: everybody else\'s first, then yours.') });
      opts.push({ label: '"What would you have me do?"', fn: () => say('Take it off. Help me stop him. You\'d be surprised what you can do with a little willpower.') });
      opts.push({ label: 'Side with Hal (turn on the Fear Man)', cls: 'go', fn: () => {
        s.path = 'green'; s.gstage = 0; s.gactive = true; s.saved = 0; s.gperks = s.gperks || {};
        s.active = false; // the Fear Man's lesson is abandoned
        pl.weapon = pl.weapon === 'ring' ? 'fists' : pl.weapon;
        say(GQ[0].give); ui.closeSheet();
        g.ui.toast(`Hal: ${GQ[0].title}. ${GQ[0].goal}`, 'good');
        h.hostile = false; h.state = 'idle'; h.timer = 1e9; h.stay = true; h.strangerName = 'Hal';
      } });
      opts.push({ label: '"Let\'s settle this." (fight him)', cls: 'bad', fn: () => { ui.closeSheet(); h.hostile = true; g.actors.setFight(h, pl); } });
    } else if (gq && s.gactive && gq.id === 'protect' && s.saved >= 5) {
      opts.push({ label: '"Five of them. Satisfied?"', cls: 'go', fn: () => { say(GQ[0].done); ui.closeSheet(); this.gfinish(); } });
    } else if (gq) opts.push({ label: `"About ${gq.title.toLowerCase()}..."`, fn: () => say(`${gq.goal}${gq.id === 'protect' ? ` (${s.saved}/5)` : ''}`) });
    else opts.push({ label: '"How\'s the sky?"', fn: () => say('Quiet. Too quiet. Somewhere up there he\'s licking his wounds. Keep that ring charged.') });
    if (pl.wardrobe && pl.wardrobe['unlock:glsuit'] && pl.style.shirt !== 'gljersey') opts.push({ label: 'Put on the green uniform', fn: () => { this.greenSuit(); say('Looks good on you. Don\'t get cocky.'); } });
    opts.push({ label: 'Leave', fn: () => ui.closeSheet() });
    return { title: 'Hal', sub: 'Leather flight jacket, green shirt, a grin like he owns the sky. A ring glows green on his hand.', options: opts };
  };
  Q.greenSuit = function () {
    const pl = this.game.player;
    Object.assign(pl.style, { jacket: 'none', shirt: 'gljersey', top: 'turtle', pants: 'glblack', hat: 'none' });
    pl.buildLook();
    this.game.ui.toast('Green and black. Kids point at you on the street.', 'good');
  };
  Q.gfinish = function () {
    const g = this.game, pl = g.player, s = this.state(), q = GQ[s.gstage];
    s.gstage++;
    if (q.id === 'protect') {
      pl.ringColor = 'green';
      pl.inv.tools.ring = 1;
      pl.inv.tools.battery = 1;
      pl.wardrobe = pl.wardrobe || {}; pl.wardrobe['unlock:glsuit'] = 1;
      D.weapons.ring.name = 'Green Ring';
      g.ui.setRingButtons();
      s.gactive = true;
      g.audio.sfx('promote');
      g.ui.story('The Green Ring', `Hal presses a ring into your palm. It is cool, and it hums a different note.\n\n${GREEN_OATH}\n\nYour constructs, bolts and beam burn green now. Will comes back faster near people who like you. Recite the oath at the power battery once a day for a full charge.\n\nNext: ${GQ[1].goal}`);
      g.ui.toast(`Hal: ${GQ[1].title}.`, 'good');
      R.poi.add(R.ring.fearSpot.x, R.ring.fearSpot.y, 'tip', 'The dead tree', 'Face the Fear Man, 1-4 AM');
    }
    if (q.id === 'showdown') {
      s.gperks.knight = 1;
      s.fmGone = true;
      g.audio.sfx('promote');
      g.pop.addNews('dust', 'A pillar of yellow light rose from the Dustwater flats at 3 AM and did not come down. Observatory staff "have no comment".');
      g.ui.story('TO BE CONTINUED...', 'He is gone. Not dead: gone. A streak of yellow went straight up past the clouds, past the moon, and kept going.\n\nSomewhere out there, a planet of little blue men and a lantern the size of a city are waiting.\n\nThe Brass Coast is quiet tonight. For now.\n\n(Emerald Knight: constructs cost a quarter less, the shield lasts twice as long, and you can call Hal from any payphone.)');
    }
  };
  // bad guys you put down while they're hurting someone
  Q.onDefeat = function (h, byPlayer) {
    const s = this.state();
    if (!byPlayer || s.path !== 'green' || !s.gactive || s.gstage !== 0 || !h || h.kind !== 'h') return;
    const baddie = ['mugger', 'robber', 'perp', 'thief', 'qward', 'bounty'].includes(h.tag) || h.possessed || (h.hostile && h.target && h.target !== this.game.player && h.target.kind === 'h');
    if (!baddie || h.countedSave) return;
    h.countedSave = true;
    s.saved++;
    this.game.fx.text(h.x, h.y - 26, `PROTECTED ${Math.min(5, s.saved)}/5`, '#70f080');
    if (s.saved === 5) this.game.ui.toast('Five. Go tell Hal on the Dustwater airstrip.', 'good');
  };
  // trouble finds a would-be hero: more street crime while you're proving yourself
  Q.gupdate = function (dt) {
    const g = this.game, s = this.state(), pl = g.player;
    if (s.path !== 'green') return;
    if (s.gstage === 0 && s.gactive && s.saved < 5) {
      this.crimeT = (this.crimeT || 20) - dt;
      if (this.crimeT <= 0 && !pl.room && g.world.cityAt((pl.x / TS) | 0, (pl.y / TS) | 0)) { this.crimeT = 45; const city = g.world.cityAt((pl.x / TS) | 0, (pl.y / TS) | 0); if (R.events.robbery) R.events.robbery(g, city); }
    }
    // Hal waits on the strip for you in daylight
    const st = this.strip, h = g.clock.hour();
    if (!this.pilot && (s.gstage === 0 || s.gstage >= 1) && Math.hypot(pl.x / TS - st.x, pl.y / TS - st.y) < 32 && h > 7 && h < 19) this.spawnHal();
    // Will from hope: people who like you nearby
    if (pl.ringColor === 'green' && pl.will != null) {
      let hope = 0;
      for (const a of g.actors.near(pl.x, pl.y, TS * 8)) if (a.person && a.person.opinion > 30 && !a.dead) hope++;
      pl.will = Math.min(pl.willMax || 100, pl.will + dt * Math.min(15, hope * 3));
    }
    this.updateHalBackup(dt);
  };
  Q.spawnHal = function () {
    const g = this.game, st = this.strip;
    const p = g.actors.makeHuman(st.x * TS + 8, st.y * TS + 8, { tag: 'pilot', cash: 0, arch: 'friendly',
      look: { fem: false, age: 32, skin: '#e0ac7e', hair: '#5a3a20', top: '#6a4a2a', bottom: '#2a3a2a', seedStr: 'pilot', oldOverride: { style: 'short', jacket: ['#3a2410', '#5a3a1c', '#7c5228', '#a06c38'], shirt: ['#1a4a24', '#2a6a34', '#3a8a48', '#5aaa68'], pants: ['#1a2a1a', '#243424', '#344a34', '#4a6a4a'] } } });
    p.strangerName = 'Hal'; p.keep = true; p.hp = p.maxHp = 320; p.tr.brave = 1; p.pilot = true; p.stay = true; p.state = 'idle'; p.timer = 1e9;
    this.pilot = p;
  };
  // the showdown: he fights, he can't die, he leaves
  Q.fightFearMan = function (fm) {
    const g = this.game, pl = g.player, s = this.state(), gq = this.gcurrent();
    if (!gq || gq.id !== 'showdown') return false;
    if (!fm.fearFight) {
      fm.fearFight = true; fm.maxHp = fm.hp = 700; fm.hostile = true; fm.hostileLocked = true; fm.stay = false; fm.tr.brave = 1;
      g.actors.say(fm, 'Hal\'s little recruit. You could have ruled this coast. Now you will fear it.');
      g.actors.setFight(fm, pl);
      g.ui.toast('The Fear Man rises off the ground. Yellow light pours from his fist.', 'bad');
    }
    fm.boltT = (fm.boltT || 1) - 1 / 30;
    if (fm.boltT <= 0 && Math.hypot(fm.x - pl.x, fm.y - pl.y) < TS * 14) {
      fm.boltT = 0.9 + R.rng() * 0.5;
      const a = Math.atan2(pl.y - fm.y, pl.x - fm.x);
      this.greens.push({ x: fm.x, y: fm.y - 10, vx: Math.cos(a) * 210, vy: Math.sin(a) * 210, t: 0, glove: R.rng() < 0.35, yellow: true });
      if (R.rng() < 0.25) g.actors.say(fm, R.rng.pick(['Kneel.', 'I have ended wars bigger than your planet.', 'Fear is the only honest emotion.', 'You will not be remembered.']));
    }
    // he can't be killed: at the brink, he goes
    if (fm.hp < fm.maxHp * 0.15) {
      fm.hp = Math.max(1, fm.hp); fm.fearGone = true;
      g.actors.say(fm, 'This is not over. The stars are wide, and I am patient.');
      for (let k = 0; k < 60; k++) g.fx.add({ x: fm.x + (R.rng() - 0.5) * 10, y: fm.y - R.rng() * 200, vx: (R.rng() - 0.5) * 20, vy: -200 - R.rng() * 200, life: 1.5, max: 1.5, c: R.rng() < 0.5 ? '#fff27a' : '#f0c020', s: 3, glow: 1 });
      g.cam.shake(8);
      g.actors.remove(fm);
      R.ring.fearMan = null;
      this.gfinish();
    }
    return true;
  };
  // Emerald Knight: call Hal from a payphone and he flies in to help for a minute
  Q.callHal = function () {
    const g = this.game, pl = g.player;
    if (this.halT > 0) return g.ui.toast('Hal: "Already on my way, hotshot."');
    const s = g.world.findNear((pl.x / TS) | 0, (pl.y / TS) | 0, 3, 6, (x, y) => !g.world.solidPed(x, y) && !g.world.isWater(x, y));
    if (!s) return;
    const h = g.actors.makeHuman(s.x * TS + 8, s.y * TS + 8, { tag: 'hal', weapon: 'revolver', arch: 'friendly' });
    h.strangerName = 'Hal'; h.keep = true; h.hp = h.maxHp = 300; h.tr.brave = 1; h.halBackup = true;
    h.look.oldOverride = { style: 'short', jacket: ['#3a2410', '#5a3a1c', '#7c5228', '#a06c38'], shirt: ['#1a4a24', '#2a6a34', '#3a8a48', '#5aaa68'], pants: ['#1a2a1a', '#243424', '#344a34', '#4a6a4a'] }; h.look.seedStr = 'halbackup'; h.look.old = null;
    pl.recruit(h);
    h.fearRing = true; // fires ring bolts with your corps logic (green here)
    this.halT = 60;
    this.halRef = h;
    g.ui.toast('A green streak drops out of the sky. "Heard you needed a hand."', 'good');
  };
  Q.updateHalBackup = function (dt) {
    if (!(this.halT > 0)) return;
    this.halT -= dt;
    const h = this.halRef;
    if (h && !h.dead) {
      const g = this.game;
      h.boltT = (h.boltT || 0) - dt;
      const foe = g.actors.near(h.x, h.y, TS * 10, (a) => a.kind === 'h' && !a.dead && a.hostile && a.state === 'fight' && !a.crew)[0];
      if (foe && h.boltT <= 0) { h.boltT = 0.8; const a = Math.atan2(foe.y - h.y, foe.x - h.x); R.ring.shots.push({ k: 'bolt', bolt: true, x: h.x, y: h.y - 10, vx: Math.cos(a) * 400, vy: Math.sin(a) * 400, t: 0, life: 0.6, rot: a, hits: new Set(), owner: h }); }
    }
    if (this.halT <= 0 && h && !h.dead) { this.game.player.dismiss(h); this.game.fx.text(h.x, h.y - 26, 'Gotta fly!', '#70f080'); this.game.actors.remove(h); this.halRef = null; }
  };
  // the green battery: recite the oath once a day
  Q.chargeGreen = function () {
    const g = this.game, pl = g.player, s = this.state();
    const day = Math.floor(g.clock.t / 1440);
    if (s.gChargedDay === day) return g.ui.toast('The battery needs a day to glow again.', 'warn');
    s.gChargedDay = day;
    pl.will = pl.willMax || 100;
    g.audio.sfx('coolOn');
    for (let k = 0; k < 24; k++) g.fx.add({ x: pl.x, y: pl.y - 10, vx: (R.rng() - 0.5) * 160, vy: (R.rng() - 0.5) * 160, life: 0.8, max: 0.8, c: '#9af0a8', s: 2, glow: 1 });
    g.ui.story('The Oath', GREEN_OATH + '\n\n(Will fully charged.)');
  };
  // the pilot fight on the fear path shouldn't happen until you choose it
  const baseUpdatePilot = Q.updatePilot;
  Q.updatePilot = function (dt) {
    const s = this.state();
    if (this.pilot && !this.pilot.hostile && this.pilot.state !== 'fight' && s.path !== 'green') { this.pilot.state = 'idle'; this.pilot.timer = 1e9; }
    return baseUpdatePilot.call(this, dt);
  };
  const baseUpdate = Q.update;
  Q.update = function (dt) { baseUpdate.call(this, dt); this.gupdate(dt); };
  const baseOptions = Q.options;
  Q.options = function (h, say, close) {
    const s = this.state();
    if (s.path === 'green') return [{ label: '"It\'s over, old man."', fn: () => say('You chose the pilot. Then we have nothing to say until one of us is on the ground.') }];
    return baseOptions.call(this, h, say, close);
  };
})();
// count the bad guys the would-be hero puts down (killed or knocked out)
(function () {
  const baseKill = R.combat.kill;
  R.combat.kill = function (h, source, kind) {
    const g = R.game, was = h && h.dead;
    baseKill.call(this, h, source, kind);
    if (!was && g && R.fearQuest.onDefeat) R.fearQuest.onDefeat(h, source === g.player || (source && source.driver === g.player) || (source && source.owner === g.player));
  };
  R.bus.on('player:ko', (h) => R.fearQuest.onDefeat && R.fearQuest.onDefeat(h, true));
})();
