// RHAPSODY — legends of the Brass Coast. Rare, time-and-place encounters that bartenders,
// old-timers and the paper whisper about: a drowned captain on the Port Hollow piers, a
// sasquatch in the Pinecrest woods, lights over the Dustwater flats, the gentleman who
// waits at a lonely crossroads at midnight, and Old Scratch, the gator as long as a bus.
(function () {
  const D = R.data, TS = R.TILE, T = D.T;
  D.loot.doubloon = { name: 'Old Doubloon', v: 140 };
  D.loot.pelt_squatch = { name: 'Sasquatch Pelt', v: 1500, pelt: 1 };
  D.loot.pelt_scratch = { name: 'Old Scratch\'s Hide', v: 1200, pelt: 1 };

  const L = (R.legends = { game: null, t: 0 });
  L.init = function (game) {
    this.game = game;
    this.t = 3;
    this.ufo = null;
    this.active = {};
  };
  const hr = () => L.game.clock.hour();
  const day = () => Math.floor(L.game.clock.t / 1440);
  const seen = (k) => L.game.hints['legend_' + k];
  const mark = (k) => { L.game.hints['legend_' + k] = day() + 1; };

  L.rumor = function () {
    const g = this.game;
    const dust = g.world.cities.find((c) => c.id === 'dust');
    const s = R.ring.fearSpot;
    const dir = s && dust ? R.compass(s.x - dust.cx, s.y - dust.cy) : 'out';
    return R.rng.pick([
      `Trucker swore to me there's a pink-faced fella standing under a dead tree ${dir} of Dustwater, way out in the flats. Only after one in the morning. Said his hand was glowing.`,
      'Fishermen won\'t work the Port Hollow piers after midnight. Say a drowned captain walks the planks looking for his ship.',
      'Hunters up in Pinecrest keep finding footprints the size of a snow shovel. Dusk and dawn, they say. Something big.',
      'Lights over the Dustwater desert, two, three in the morning. My cousin lost four hours out there. Came back with a sunburn at night.',
      'Don\'t stand at a country crossroads at midnight. There\'s a man in a white suit who\'ll buy anything. Anything.',
      'Old Scratch is back in the bayou. Gator as long as a city bus. Comes out at night.',
      `That pink-faced man ${dir} of Dustwater? They call him the Fear Man. Nobody who met him will say what he wanted.`,
    ]);
  };

  // ---------------------------------------------------------------- spawning
  L.update = function (dt) {
    const g = this.game, pl = g.player;
    this.updateUfo(dt);
    for (const k in this.active) { const a = this.active[k]; if (!a || a.dead && k !== 'scratch' && k !== 'squatch' || !g.actors.list.includes(a)) delete this.active[k]; }
    this.tickActive(dt);
    this.t -= dt;
    if (this.t > 0 || pl.room) return;
    this.t = 5;
    const w = g.world, h = hr();
    const tx = (pl.x / TS) | 0, ty = (pl.y / TS) | 0;
    const biome = w.biomeAt(tx, ty);
    const city = w.cityAt(tx, ty);
    // the drowned captain
    if (!this.active.ghost && h < 3 && seen('ghost') !== day() + 1 && city && city.id === 'port') {
      const pier = w.spots.filter((s) => s.kind === 'pier').sort((a, b) => Math.hypot(a.x - tx, a.y - ty) - Math.hypot(b.x - tx, b.y - ty))[0];
      if (pier && Math.hypot(pier.x - tx, pier.y - ty) < 30) this.spawnGhost(pier);
    }
    // sasquatch at dusk and dawn
    if (!this.active.squatch && (h > 5 && h < 7.5 || h > 18 && h < 20.5) && (biome === 'forest' || biome === 'snow') && !city && R.rng() < 0.18) this.spawnSquatch();
    // lights in the sky
    if (!this.ufo && h >= 2 && h < 4 && biome === 'desert' && !city && seen('ufo') !== day() + 1 && R.rng() < 0.4) this.spawnUfo();
    // the crossroads
    if (!this.active.cross && (h >= 23 || h < 3) && !city) {
      const it = w.inters.filter((i) => !w.inCityRect(Math.round(i.cx), Math.round(i.cy), 4)).sort((a, b) => Math.hypot(a.cx - tx, a.cy - ty) - Math.hypot(b.cx - tx, b.cy - ty))[0];
      if (it && Math.hypot(it.cx - tx, it.cy - ty) < 24) this.spawnCrossroads(it);
    }
    // Old Scratch
    if (!this.active.scratch && g.clock.isNight() && biome === 'marsh' && !seen('scratchDead') && R.rng() < 0.12) this.spawnScratch();
    // the bill comes due
    if (g.hints.soulSold && h < 1 && g.hints.hellhound !== day() && !city) this.spawnHellhound();
  };
  L.tickActive = function (dt) {
    const g = this.game, pl = g.player;
    const gh = this.active.ghost;
    if (gh) {
      gh.ghostT = (gh.ghostT || 0) + dt;
      const d = Math.hypot(gh.x - pl.x, gh.y - pl.y);
      if (hr() >= 3 || gh.hp < gh.maxHp || gh.vanish) {
        for (let i = 0; i < 10; i++) g.fx.add({ x: gh.x, y: gh.y - 10, vx: (R.rng() - 0.5) * 40, vy: -20 - R.rng() * 20, life: 1.2, max: 1.2, c: 'rgba(180,220,255,0.6)', s: 2 });
        if (gh.vanish && !gh.gave) { gh.gave = true; pl.inv.loot.doubloon = (pl.inv.loot.doubloon || 0) + 1; g.ui.toast('Where he stood, a tarnished gold doubloon. (Old Doubloon added)', 'good'); }
        g.actors.remove(gh);
        delete this.active.ghost;
        mark('ghost');
      } else if (d < TS * 1.6 && !g.ui.sheetOpen) { gh.vanish = true; }
    }
    const os = this.active.scratch;
    if (os && os.dead && !os.mourned) { os.mourned = true; this.onAnimalDeath(os); }
    const sq = this.active.squatch;
    if (sq && !sq.dead) {
      const d = Math.hypot(sq.x - pl.x, sq.y - pl.y);
      if (d < TS * 9 && !sq.spotted && g.world.los(pl.x, pl.y - 8, sq.x, sq.y - 8)) {
        sq.spotted = true;
        if (!seen('squatch')) {
          mark('squatch');
          pl.addCash(150);
          g.ui.toast('You SAW it. The Pinecrest Gazette pays $150 for your story.', 'good');
          g.pop.addNews('pine', 'Local man claims close encounter with "a hairy giant, eight feet tall" in the woods. Experts skeptical.');
        } else g.ui.toast('The big hairy thing again. Nobody will believe you twice.');
      }
      if (d < TS * 12 && sq.state !== 'flee') g.actors.setFlee(sq, pl, 5);
      if (d > TS * 40) { g.actors.remove(sq); delete this.active.squatch; }
    }
    const cr = this.active.cross;
    if (cr) {
      // he keeps his appointment from eleven till three, and never walks out on a deal
      const d = Math.hypot(cr.x - pl.x, cr.y - pl.y);
      const talking = g.ui.sheetOpen === 'talk' && g.ui.talkH === cr;
      const late = hr() >= 3 && hr() < 23;
      if (!talking && ((late && d > TS * 6) || d > TS * 70)) {
        g.fx.smoke(cr.x, cr.y - 10, true); g.fx.smoke(cr.x + 4, cr.y - 14, true);
        g.actors.remove(cr); delete this.active.cross;
        if (d < TS * 20) g.ui.toast('The man in white is gone. The crossroads smell of struck matches.');
      } else { cr.state = 'idle'; cr.timer = 1e9; cr.dir = R.dir4(pl.x - cr.x, pl.y - cr.y); }
    }
  };

  L.legendLook = function (seed, ov) {
    return { fem: false, age: 60, skin: '#e0e0f0', hair: '#c0c0c0', top: '#5a6a7a', bottom: '#3a4a5a', hat: null, seedStr: seed, oldOverride: ov };
  };
  L.spawnGhost = function (pier) {
    const g = this.game;
    const h = g.actors.makeHuman(pier.x * TS + 8, pier.y * TS + 8, { tag: 'legend', cash: 0, arch: 'eccentric',
      look: this.legendLook('ghost', { skin: ['#5a7a9a', '#7a9aba', '#a8c8e0', '#d8ecf8'], style: 'long', stache: true, jacket: ['#1a2a3a', '#2a3a4a', '#3a5a6a', '#5a7a8a'], top: 'collar', shirt: ['#6a7a8a', '#8a9aaa', '#b0c0d0', '#d8e0e8'], pants: ['#1a2230', '#2a3240', '#3a4250', '#4a5260'], cap: ['#10141a', '#1a2028', '#2a3038', '#3a4048'] }) });
    h.legend = 'ghost'; h.ghost = true; h.keep = true; h.stay = true; h.state = 'idle'; h.timer = 1e9;
    h.strangerName = 'Drowned Captain';
    this.active.ghost = h;
  };
  L.spawnSquatch = function () {
    const g = this.game, w = g.world, pl = g.player;
    const s = w.findNear(pl.x / TS, pl.y / TS, 16, 26, (x, y) => !w.solidPed(x, y) && !w.isWater(x, y) && (w.t(x, y) === T.FOREST || w.t(x, y) === T.SNOW));
    if (!s) return;
    const h = g.actors.makeHuman(s.x * TS + 8, s.y * TS + 8, { tag: 'legend', cash: 0, arch: 'timid',
      look: this.legendLook('squatch', { skin: ['#2a1a10', '#3a2618', '#4e3422', '#6a4a30'], style: 'afro', stache: true, jacket: ['#2a1a10', '#3a2618', '#4e3422', '#6a4a30'], shirt: ['#2a1a10', '#3a2618', '#4e3422', '#6a4a30'], pants: ['#2a1a10', '#3a2618', '#4e3422', '#6a4a30'], hair: ['#1e120a', '#2e1c10', '#442a18', '#5e3c24'] }) });
    h.legend = 'squatch'; h.scale = 1.4; h.hp = h.maxHp = 400; h.keep = true; h.speedMul = 1.6; h.strangerName = 'Something Big';
    h.loot = ['pelt_squatch'];
    this.active.squatch = h;
  };
  L.spawnCrossroads = function (it) {
    const g = this.game;
    const x = (Math.round(it.cx) + 3) * TS + 8, y = (Math.round(it.cy) + 3) * TS + 8;
    const h = g.actors.makeHuman(x, y, { tag: 'legend', cash: 0, arch: 'hustler',
      look: this.legendLook('crossroads', { skin: ['#5a3a2a', '#7a5040', '#a06a54', '#c8907a'], style: 'short', stache: true, jacket: ['#b8b0a0', '#d8d0c0', '#eee8dc', '#fffaf0'], top: 'collar', shirt: ['#5a0a0a', '#8a1010', '#b82020', '#e04040'], pants: ['#b8b0a0', '#d8d0c0', '#eee8dc', '#fffaf0'], glasses: true }) });
    h.legend = 'cross'; h.keep = true; h.stay = true; h.state = 'idle'; h.timer = 1e9; h.strangerName = 'Gentleman in White';
    this.active.cross = h;
    g.fx.smoke(x, y - 8, true);
  };
  L.spawnScratch = function () {
    const g = this.game, w = g.world, pl = g.player;
    const s = w.findNear(pl.x / TS, pl.y / TS, 12, 20, (x, y) => w.t(x, y) === T.MARSH && !w.solidPed(x, y));
    if (!s) return;
    const a = g.actors.makeAnimal(s.x * TS + 8, s.y * TS + 8, 'gator');
    a.def = Object.assign({}, a.def, { name: 'Old Scratch', size: 20, hp: 520, dmg: 45, speed: 80, pelt: 'pelt_scratch', col: '#2a3a1a' });
    a.hp = a.maxHp = 520;
    a.r = 9;
    a.keep = true;
    a.legendary = 'scratch';
    this.active.scratch = a;
    g.ui.toast('Something enormous slides into the water nearby.', 'warn');
  };
  L.spawnHellhound = function () {
    const g = this.game, w = g.world, pl = g.player;
    g.hints.hellhound = day();
    const s = w.findNear(pl.x / TS, pl.y / TS, 10, 16, (x, y) => !w.solidPed(x, y) && !w.isWater(x, y));
    if (!s) return;
    const a = g.actors.makeAnimal(s.x * TS + 8, s.y * TS + 8, 'wolf');
    a.def = Object.assign({}, a.def, { name: 'Hellhound', hp: 160, dmg: 22, speed: 130, col: '#141010', pelt: null, eyes: '#ff3020' });
    a.hp = a.maxHp = 160;
    a.state = 'attack'; a.target = pl; a.timer = 60; a.keep = true;
    g.ui.toast('A black dog with ember eyes. The gentleman sends his regards.', 'bad');
  };
  L.onAnimalDeath = function (a) {
    if (a.legendary === 'scratch') {
      mark('scratchDead');
      this.game.pop.addNews('bayou', 'OLD SCRATCH IS DEAD. Bayou Clair holds its breath: was the legend real? The hide says yes.');
    }
  };

  // ---------------------------------------------------------------- the UFO
  L.spawnUfo = function () {
    const g = this.game, pl = g.player;
    const a = R.rng() * 6.28;
    this.ufo = { x: pl.x + Math.cos(a) * TS * 14, y: pl.y + Math.sin(a) * TS * 14, t: 0, beamT: 0, life: 90 };
    g.ui.toast('Lights in the sky. Three of them. Not moving like a plane.', 'warn');
  };
  L.updateUfo = function (dt) {
    const u = this.ufo;
    if (!u) return;
    const g = this.game, pl = g.player;
    u.t += dt;
    u.x += Math.sin(u.t * 0.4) * 8 * dt;
    u.y += Math.cos(u.t * 0.3) * 6 * dt;
    if (u.t > u.life || hr() >= 4) { this.ufo = null; mark('ufo'); return; }
    const d = Math.hypot(pl.x - u.x, pl.y - u.y);
    if (d < 18 && !pl.inCar) {
      u.beamT += dt;
      if (u.beamT > 1.6) {
        this.ufo = null;
        mark('ufo');
        const w = g.world;
        const s = w.findNear(pl.x / TS + (R.rng() - 0.5) * 80, pl.y / TS + (R.rng() - 0.5) * 80, 0, 30, (x, y) => !w.solidPed(x, y) && !w.isWater(x, y));
        if (s) pl.place(s.x * TS + 8, s.y * TS + 8);
        g.clock.skip(180);
        pl.cool = 100;
        pl.maxHp += 10; pl.hp = pl.maxHp;
        g.cam.x = pl.x; g.cam.y = pl.y;
        g.ui.story('Missing Time', 'A hum. White light. Then nothing.\n\nYou wake up somewhere else, three hours later, with a small neat scar behind your ear and the strange feeling that you are tougher than you were.\n\n(+10 max health, Cool refilled)');
      }
    } else u.beamT = Math.max(0, u.beamT - dt);
  };
  L.draw = function (g) {
    const u = this.ufo, t = this.game.clock.real;
    if (u) {
      const y = u.y - 70 + Math.sin(t * 2) * 3;
      g.fillStyle = `rgba(200,255,220,${0.12 + (u.beamT > 0 ? 0.2 : 0)})`;
      g.beginPath(); g.moveTo(u.x - 6, y + 6); g.lineTo(u.x + 6, y + 6); g.lineTo(u.x + 18, u.y); g.lineTo(u.x - 18, u.y); g.fill();
      g.fillStyle = '#8a9aa8'; g.beginPath(); g.ellipse(u.x, y, 20, 6, 0, 0, 7); g.fill();
      g.fillStyle = '#c8e8f0'; g.beginPath(); g.ellipse(u.x, y - 4, 8, 5, 0, Math.PI, 0); g.fill();
      for (let k = 0; k < 5; k++) { g.fillStyle = (Math.floor(t * 6) + k) % 3 === 0 ? '#ff5040' : '#80ffb0'; g.fillRect(Math.round(u.x - 14 + k * 7), Math.round(y + 1), 2, 2); }
      g.fillStyle = 'rgba(200,255,220,0.25)'; g.beginPath(); g.ellipse(u.x, u.y, 18, 6, 0, 0, 7); g.fill();
    }
  };

  // ---------------------------------------------------------------- dialogue
  L.tree = function (h) {
    const g = this.game, pl = g.player, ui = g.ui;
    const say = (t) => ui.talkLine(t);
    const opts = [];
    if (h.legend === 'ghost') {
      opts.push({ label: '"Who are you?"', fn: () => say('Captain Elias Crane, of the Mary Alice. We went down off the point in the storm of \'26. Nineteen twenty-six.') });
      opts.push({ label: '"What are you looking for?"', fn: () => say('My ship. My crew. The lighthouse keeper who let the lamp go dark. He drank, you know.') });
      opts.push({ label: '"Rest easy, Captain."', fn: () => { say('...Rest. Yes. It has been a long watch.'); h.vanish = true; ui.closeSheet(); } });
      return { title: 'Drowned Captain', sub: 'Pale as sea-foam, dripping, and you can see the pier through him.', options: opts };
    }
    if (h.legend === 'cross') {
      if (!g.hints.soulSold) {
        opts.push({ label: '"Who are you?"', fn: () => say('A collector. Of talent, mostly. Of souls, when the talent is lacking.') });
        opts.push({ label: 'Sell your soul ($2,500)', small: 'Something will come for you on moonless nights', fn: () => {
          g.hints.soulSold = 1; pl.addCash(2500); g.audio.sfx('cash');
          say('Pleasure doing business. Mind the dogs.');
          ui.closeSheet();
          g.ui.toast('+$2,500. The air smells like struck matches.', 'warn');
        } });
      } else {
        opts.push({ label: 'Buy your soul back ($5,000)', fn: () => { if (!pl.pay(5000)) return say('Interest, you understand. Come back when you have it.'); g.hints.soulSold = 0; say('A shame. You were such a good investment.'); } });
        opts.push({ label: '"Call off your dogs."', fn: () => say('They are not MY dogs. They are YOUR debt.') });
      }
      opts.push({ label: 'Walk away', fn: () => ui.closeSheet() });
      return { title: 'Gentleman in White', sub: 'White suit, red shirt, dark glasses at midnight. He smells like a struck match.', options: opts };
    }
    opts.push({ label: 'Back away slowly', fn: () => ui.closeSheet() });
    return { title: h.strangerName || '???', sub: '', options: opts };
  };

  // bartenders and gossips know the stories
  const baseRumor = R.dialog.rumor;
  R.dialog.rumor = function (h) {
    if (R.rng() < (h.role === 'bartender' ? 0.45 : 0.18)) return L.rumor();
    return baseRumor.call(this, h);
  };
})();
