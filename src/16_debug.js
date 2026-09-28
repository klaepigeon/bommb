// RHAPSODY — the debug menu (Menu > Debug). Cheats, time and weather, teleports,
// spawners and a live readout of the simulation, for testing and for fun.
(function () {
  const TS = R.TILE;
  R.debugTab = function (body, g) {
    const pl = g.player, w = g.world, ch = g.cheats;
    const ui = g.ui;
    const btn = (id, label, cls) => `<button class="dbg ${cls || ''}" data-d="${id}">${label}</button>`;
    const tog = (id, label) => btn('t:' + id, `${ch[id] ? '☑' : '☐'} ${label}`, ch[id] ? 'on' : '');
    const alive = g.pop.people.filter((p) => p.alive).length;
    const stats = `Day ${g.clock.day() + 1} ${g.clock.label()} · ${g.env.weather.kind} · ${alive} people alive · ${g.actors.list.length} actors · ${g.traffic.list.length} cars · ${Math.round(g.fps || 0)} fps · calm ${g.calm().toFixed(2)} · tile ${(pl.x / TS) | 0},${(pl.y / TS) | 0}`;
    body.innerHTML = `<p class="dbgstat">${stats}</p>
      <div class="sect">Cheats</div><div class="dbgrow">${tog('god', 'God mode')}${tog('noLaw', 'No law')}${tog('oneHit', 'One-hit kills')}${tog('infAmmo', 'Infinite ammo')}${tog('fastRun', 'Fast legs')}</div>
      <div class="sect">Player</div><div class="dbgrow">${btn('cash', '+$1,000')}${btn('heal', 'Full heal')}${btn('arsenal', 'All weapons + ammo')}${btn('ring', 'Give Yellow Ring')}${btn('picks', '+5 lockpicks')}${btn('clean', 'Clear bounties')}${btn('infamy', '+20 infamy')}${btn('sober', 'Sober up')}</div>
      <div class="sect">Time & weather</div><div class="dbgrow">${btn('time:6', '6 AM')}${btn('time:12', 'Noon')}${btn('time:19', '7 PM')}${btn('time:0', 'Midnight')}${btn('time:2', '2 AM')}${btn('day', 'Skip a day')}${['clear', 'cloudy', 'rain', 'storm', 'fog', 'heat'].map((k) => btn('wx:' + k, k)).join('')}</div>
      <div class="sect">Teleport</div><div class="dbgrow">${w.cities.map((c) => btn('tp:' + c.id, c.name)).join('')}${btn('tp:fear', 'Fear Man\'s tree')}${btn('tp:pier', 'The piers')}${btn('tp:forest', 'Deep woods')}${btn('tp:marsh', 'The marsh')}${btn('tp:cross', 'A crossroads')}</div>
      <div class="sect">Spawn</div><div class="dbgrow">${btn('sp:mugger', 'Mugger')}${btn('sp:thug', 'Armed thug')}${btn('sp:cop', 'Cop')}${btn('sp:wolf', 'Wolf')}${btn('sp:bear', 'Bear')}${btn('sp:car', 'Muscle car')}${btn('sp:ghost', 'Ghost')}${btn('sp:squatch', 'Sasquatch')}${btn('sp:ufo', 'UFO')}${btn('sp:cross', 'Crossroads man')}${btn('sp:scratch', 'Old Scratch')}${btn('sp:fear', 'Fear Man (here)')}${btn('sp:props', 'Pile of junk')}</div>
      <div class="sect">Test rooms</div><div class="dbgrow">${btn('tr:gallery', 'Art gallery')}${btn('tr:arena', 'Combat arena')}${btn('tr:yard', 'Vehicle yard')}${btn('tr:fire', 'Fire lab')}${btn('tr:stealth', 'Stealth range')}${btn('tr:water', 'Water')}</div>
      <div class="sect">World</div><div class="dbgrow">${btn('ev', 'Street event now')}${btn('calm', 'Kill all hostiles')}${btn('law', 'Call the cops on me')}${btn('fire', 'Start a fire here')}${btn('save', 'Save now')}</div>`;
    const near = (pred, r) => w.findNear(pl.x / TS, pl.y / TS, 3, r || 8, pred || ((x, y) => !w.solidPed(x, y) && !w.isWater(x, y)));
    const tp = (x, y) => { if (pl.room) g.interiors.exit(); if (pl.inCar) pl.exitCar(); pl.place(x * TS + 8, y * TS + 8); g.cam.x = pl.x; g.cam.y = pl.y; ui.closeSheet(); };
    const scan = (pred) => { for (let r = 0; r < 300; r += 2) for (let a = 0; a < 6.28; a += 0.15) { const x = Math.round(pl.x / TS + Math.cos(a) * r), y = Math.round(pl.y / TS + Math.sin(a) * r); if (w.inb(x, y) && pred(x, y)) return { x, y }; } return null; };
    body.querySelectorAll('[data-d]').forEach((b) => b.addEventListener('click', () => {
      const [k, v] = b.dataset.d.split(':');
      const s = near();
      switch (k) {
        case 't': ch[v] = !ch[v]; ui.toast(`${v}: ${ch[v] ? 'on' : 'off'}`); break;
        case 'cash': pl.addCash(1000); break;
        case 'tr': R.testRooms.go(g, v); break;
        case 'heal': pl.hp = pl.maxHp; pl.bloody = 0; break;
        case 'arsenal': for (const id of ['knuckles', 'bat', 'knife', 'revolver', 'magnum', 'shotgun', 'chopper', 'rifle']) pl.giveWeapon(id); Object.assign(pl.inv.ammo, { pistol: 200, shells: 80, smg: 300, rifle: 60, molotov: 10, dynamite: 10 }); pl.inv.tools.gascan = 3; break;
        case 'ring': pl.inv.tools.ring = 1; pl.will = 100; ui.setRingButtons(); break;
        case 'picks': pl.inv.tools.lockpick = (pl.inv.tools.lockpick || 0) + 5; break;
        case 'clean': for (const j in g.law.bounty) g.law.bounty[j] = 0; g.law.incident = null; break;
        case 'infamy': pl.rep.infamy += 20; break;
        case 'sober': pl.drunk = 0; break;
        case 'time': g.clock.t = Math.floor(g.clock.t / 1440) * 1440 + (+v < g.clock.hour() ? 1440 : 0) + +v * 60; break;
        case 'day': g.clock.skip(1440); break;
        case 'wx': g.env.setWeather(v); break;
        case 'tp': {
          if (v === 'fear') { const f = R.ring.fearSpot; tp(f.x, f.y + 3); break; }
          if (v === 'pier') { const p = w.spots.find((q) => q.kind === 'pier'); tp(p.x, p.y); break; }
          if (v === 'forest') { const p = scan((x, y) => w.t(x, y) === R.data.T.FOREST && !w.cityAt(x, y) && Math.hypot(x - pl.x / TS, y - pl.y / TS) > 20); if (p) tp(p.x, p.y); break; }
          if (v === 'marsh') { const p = scan((x, y) => w.t(x, y) === R.data.T.MARSH && !w.cityAt(x, y)); if (p) tp(p.x, p.y); break; }
          if (v === 'cross') { const it = w.inters.filter((i) => !w.inCityRect(Math.round(i.cx), Math.round(i.cy), 4)).sort((a, b) => Math.hypot(a.cx - pl.x / TS, a.cy - pl.y / TS) - Math.hypot(b.cx - pl.x / TS, b.cy - pl.y / TS))[0]; if (it) tp(Math.round(it.cx) + 3, Math.round(it.cy) + 5); break; }
          const c = w.cities.find((q) => q.id === v);
          const p = w.findNear(c.colX + 1, c.rowY + 3, 0, 10, (x, y) => w.t(x, y) === R.data.T.WALK) || { x: c.colX, y: c.rowY };
          tp(p.x, p.y);
          break;
        }
        case 'sp': {
          if (!s) break;
          const X = s.x * TS + 8, Y = s.y * TS + 8;
          if (v === 'mugger' || v === 'thug') { const h = g.actors.makeHuman(X, Y, { tag: 'mugger', weapon: v === 'thug' ? 'revolver' : 'knife' }); h.hostile = true; g.actors.setFight(h, pl); }
          if (v === 'cop') g.actors.makeHuman(X, Y, { cop: true, role: 'cop' });
          if (v === 'wolf' || v === 'bear') { const a = g.actors.makeAnimal(X, Y, v); a.state = 'attack'; a.target = pl; a.timer = 30; }
          if (v === 'car') { const car = g.traffic.make('muscle', pl.x + 30, pl.y, 0, { parked: true, keep: true, locked: false }); car.owner = 'player'; }
          if (v === 'ghost') R.legends.spawnGhost({ x: s.x, y: s.y });
          if (v === 'squatch') { R.legends.active.squatch = null; const h = g.actors.makeHuman(X, Y, {}); g.actors.remove(h); R.legends.spawnSquatch(); if (!R.legends.active.squatch) ui.toast('Needs forest or snow nearby.', 'warn'); }
          if (v === 'ufo') { R.legends.spawnUfo(); R.legends.ufo.x = pl.x + 50; R.legends.ufo.y = pl.y; }
          if (v === 'cross') R.legends.spawnCrossroads({ cx: s.x - 3, cy: s.y - 3 });
          if (v === 'scratch') { R.legends.spawnScratch(); if (!R.legends.active.scratch) ui.toast('Needs marsh nearby.', 'warn'); }
          if (v === 'fear') { const f = R.ring.fearSpot; const keep = { x: f.x, y: f.y }; R.ring.fearSpot = { x: s.x, y: s.y }; const t = g.clock.t; g.clock.t = Math.floor(t / 1440) * 1440 + 120; R.ring.updateFearMan(); g.clock.t = t; if (R.ring.fearMan) R.ring.fearMan.stay = true; R.ring.fearSpot = keep; }
          if (v === 'props') for (const k of ['pipe', 'bottle', 'chair', 'plank', 'pan', 'cake', 'bowling', 'tv']) R.props.drop(k, pl.x + (R.rng() - 0.5) * 50, pl.y + 10 + R.rng() * 30);
          ui.closeSheet();
          break;
        }
        case 'ev': ui.closeSheet(); R.events.random(g); break;
        case 'calm': for (const a of g.actors.list) if ((a.hostile && a.kind === 'h') || (a.kind === 'a' && a.state === 'attack')) R.combat.kill(a, null, 'debug'); break;
        case 'law': g.law.startIncident({ type: 'debug', def: { name: 'Debugging' }, x: pl.x, y: pl.y, jur: g.law.jurAt(pl.x, pl.y), identified: true, lvl: 2, bounty: 50 }, null); ui.closeSheet(); break;
        case 'fire': g.env.ignite(pl.x + 30, pl.y, 1, null); ui.closeSheet(); break;
        case 'save': g.save(); ui.toast('Saved.', 'good'); break;
      }
      g.audio.sfx('click');
      if (ui.sheetOpen === 'menu') ui.openMenuTab('debug', ui.el.sheet);
    }));
  };
})();
