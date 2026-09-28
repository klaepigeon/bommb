// RHAPSODY — bridges the abstract population with on-screen actors, plus the
// ambient street events that make the world feel alive.
'use strict';
(function () {
  const D = R.data, T = D.T, TS = R.TILE;

  const Life = (R.Life = function (game) {
    this.game = game;
    this.t = 0;
    this.eventT = 30;
    game.world.spots.forEach((s, i) => (s.i = i));
    this.cache = new Map();
  });
  const L = Life.prototype;

  L.key = function (d) {
    if (!d) return null;
    if (d.gone) return 'gone';
    if (d.spot) return 's:' + d.spot.i;
    return 'b:' + d.b;
  };
  L.desiredKey = function (p) {
    const g = this.game;
    const slot = Math.floor(g.clock.t / 10);
    const c = this.cache.get(p.id);
    if (c && c[0] === slot) return c[1];
    const k = this.key(g.pop.desired(p, g.clock.hour(), g.clock.day()));
    this.cache.set(p.id, [slot, k]);
    return k;
  };
  L.posOf = function (key) {
    if (!key || key === 'gone') return null;
    const w = this.game.world;
    if (key[0] === 's') { const s = w.spots[+key.slice(2)]; return s ? { x: s.x, y: s.y, spot: s } : null; }
    const b = w.buildings[+key.slice(2)];
    return b && !b.destroyed ? { x: b.out.x, y: b.out.y, b } : null;
  };
  L.occupants = function (b) {
    const g = this.game;
    const list = g.pop.byCity[b.cityId] || [];
    const key = 'b:' + b.id;
    return list.filter((p) => p.alive && !p.actor && this.desiredKey(p) === key);
  };

  L.spawnPerson = function (p, x, y) {
    const g = this.game;
    if (p.actor || !p.alive) return p.actor;
    const h = g.actors.makeHuman(x, y, { person: p, city: p.city });
    h.tag = p.role === 'kid' || p.role === 'student' ? 'kid' : 'named';
    return h;
  };

  L.update = function (dt) {
    const g = this.game, pl = g.player;
    this.t -= dt;
    this.eventT -= dt;
    if (this.eventT <= 0) {
      // the world starts quiet and livens up as the days go by and your name spreads
      const calm = g.calm();
      this.eventT = (40 + R.rng() * 50) / Math.max(0.25, calm);
      if (R.rng() < 0.35 + calm * 0.65) R.events.random(g);
    }
    if (this.t > 0) return;
    this.t = 1.2;
    this.crews();
    const ptx = pl.x / TS, pty = pl.y / TS;
    let spawned = 0;
    const cap = 22;
    let named = 0;
    for (const a of g.actors.list) if (a.person && !a.dead) named++;
    const cities = g.world.cities.filter((c) => R.dist(ptx, pty, c.cx, c.cy) < c.nbx * 8 + 60);
    if (R.dist(ptx, pty, 0, 0) >= 0) cities.push(g.world.countyCity());
    for (const c of cities) {
      const list = g.pop.byCity[c.id] || [];
      for (const p of list) {
        if (!p.alive) continue;
        const want = this.desiredKey(p);
        if (p.actor) {
          const h = p.actor;
          if (h.dead || h.removed) { p.actor = null; continue; }
          if (h.room) continue; // the interior manages people inside
          const calm = h.state === 'idle' || h.state === 'hang' || h.state === 'wander' || h.state === 'perform' || (h.state === 'travel' && h.destKey !== want);
          if (calm && h.destKey !== want) this.route(h, want);
          continue;
        }
        if (want === 'gone') { p.place = want; continue; }
        if (p.place === want) {
          if (want && want[0] === 's' && named < cap && spawned < 4) {
            const pos = this.posOf(want);
            if (pos && R.dist(ptx, pty, pos.x, pos.y) < 34) {
              const h = this.spawnPerson(p, pos.x * TS + 8 + (R.rng() - 0.5) * 24, pos.y * TS + 8 + (R.rng() - 0.5) * 24);
              if (h) { h.spot = pos.spot; h.destKey = want; g.actors.hangAround(h); spawned++; named++; }
            }
          }
          continue;
        }
        // transition
        const from = this.posOf(p.place);
        const to = this.posOf(want);
        if (from && to && named < cap && spawned < 4 && R.dist(ptx, pty, from.x, from.y) < 34 && R.dist(from.x, from.y, to.x, to.y) < 140 && !g.world.solidPed(from.x, from.y)) {
          const h = this.spawnPerson(p, from.x * TS + 8, from.y * TS + 8);
          if (h) { this.route(h, want); spawned++; named++; }
        }
        p.place = p.actor ? p.place : want;
      }
    }
  };
  // construction crews hammer away at building sites near the player during the day
  L.crews = function () {
    const g = this.game, pl = g.player, h = g.clock.hour();
    if (h < 7 || h > 18) return;
    for (const pr of g.pop.projects) {
      const lot = pr.lot;
      const cx = (lot.x + lot.w / 2) * TS, cy = (lot.y + lot.h / 2) * TS;
      if (R.dist(cx, cy, pl.x, pl.y) > TS * 30) continue;
      pr.crew = (pr.crew || []).filter((w) => !w.dead && !w.removed);
      while (pr.crew.length < 2) {
        const w = g.actors.makeHuman(cx + (R.rng() - 0.5) * lot.w * 10, cy + (R.rng() - 0.5) * 40, { tag: 'worker', arch: R.rng.pick(['grumpy', 'friendly', 'tough']) });
        w.look.hat = 'cap'; w.look.hatCol = '#e4a92a'; w.look.top = R.rng.pick(['#d9621e', '#4a6a8a', '#8a7a5a']);
        w.state = 'work'; w.timer = 60; w.tag = 'worker';
        pr.crew.push(w);
      }
      for (const w of pr.crew) {
        if (w.state === 'work' && R.rng() < 0.15) { g.fx.sparks(w.x + 4, w.y - 6, 2); g.audio.sfx('bump', w.x, w.y); }
        if (w.state !== 'work' && w.state !== 'flee' && w.state !== 'fight' && w.state !== 'cower' && w.state !== 'talk') { w.state = 'work'; w.timer = 40; }
      }
    }
  };
  L.route = function (h, want) {
    const g = this.game;
    const to = this.posOf(want);
    h.destKey = want;
    if (!to) { h.state = 'idle'; return; }
    h.spot = null;
    g.actors.goTo(h, to.x, to.y, { enter: !!to.b, spot: to.spot, placeKey: want, near: to.b ? 8 : 14, far: true });
    h.state = 'travel';
  };

  // ---------------------------------------------------------------- street events
  const EV = (R.events = {});

  EV.mugging = function (m) {
    const g = R.game, pl = g.player;
    if (m.dead || pl.inCar || pl.inside) return;
    m.state = 'talk';
    m.timer = 12;
    m.hostile = false;
    m.drawn = true;
    g.actors.say(m, R.rng.pick(['Empty your pockets, pal.', 'Nice suit. Hand over the wallet.', 'Wallet. Now. Nobody gets hurt.', 'This is a stick-up, fancy pants.']));
    const take = Math.min(pl.cash, R.rng.int(20, 60));
    g.ui.choice(`${g.actors.displayName(m)} wants your money`, [
      { label: `Hand over ${R.fmtMoney(take)}`, fn: () => { pl.cash -= take; m.cash += take; g.actors.say(m, 'Pleasure doing business.'); g.actors.setFlee(m, pl, 10); } },
      { label: 'Intimidate', fn: () => {
        const p = 0.35 + pl.rep.infamy / 150 + (pl.weaponOut ? 0.3 : 0) + (pl.masked ? 0.1 : 0);
        if (R.rng() < p) { g.actors.say(m, R.rng.pick(['Whoa, my mistake, boss!', "You're... you're HIM. Sorry!", "Forget I said nothin'."])); g.actors.setFlee(m, pl, 12); pl.rep.infamy += 1; }
        else { g.actors.say(m, 'Wrong answer.'); m.hostile = true; g.actors.setFight(m, pl); }
      } },
      { label: 'Fight', fn: () => { m.hostile = true; g.actors.setFight(m, pl); g.ui.toast('Self-defence: no crime to fight back.', 'good'); } },
    ]);
  };
  EV.pickpocket = function (m) {
    const g = R.game, pl = g.player;
    if (m.dead || pl.inCar || pl.inside || pl.cash < 5) { m.state = 'idle'; return; }
    const amt = Math.min(pl.cash, R.rng.int(10, 45));
    pl.cash -= amt;
    m.cash += amt;
    m.stolen = amt;
    m.hostile = true;
    m.tag = 'pickpocket';
    m.alert = 'thief';
    g.actors.setFlee(m, pl, 25);
    g.ui.toast(`Your wallet feels lighter: -${R.fmtMoney(amt)}. Catch that pickpocket!`, 'bad');
    g.audio.sfx('steal');
  };
  EV.hustlerPitch = function (m) {
    const g = R.game, pl = g.player;
    if (m.dead || pl.inCar || pl.inside) return;
    m.state = 'talk';
    m.timer = 12;
    const offers = [
      { item: 'watch', price: 22, line: 'Psst. Genuine Swiss watch. Fell off a truck.' },
      { item: 'ring', price: 45, line: "Diamond ring. Don't ask where it's been." },
      { item: 'bandage', price: 5, line: 'Hospital-grade bandages. Half price.', cons: true },
      { item: 'whiskey', price: 3, line: 'Bootleg rye. Puts hair on your hair.', cons: true },
      { item: 'knuckles', price: 20, line: 'Brass knuckles. For conversations.', weap: true },
      { item: 'lockpick', price: 8, line: 'Lockpicks. For your own front door, obviously.', tool: true },
    ];
    const o = R.rng.pick(offers);
    g.actors.say(m, o.line);
    g.ui.choice(`Hustler's offer: ${o.price ? R.fmtMoney(o.price) : ''}`, [
      { label: `Buy (${R.fmtMoney(o.price)})`, fn: () => {
        if (pl.cash < o.price) return g.ui.toast("You can't cover it.", 'warn');
        pl.cash -= o.price;
        if (o.cons) pl.inv.cons[o.item] = (pl.inv.cons[o.item] || 0) + 1;
        else if (o.weap) pl.giveWeapon(o.item);
        else if (o.tool) pl.inv.tools[o.item] = (pl.inv.tools[o.item] || 0) + 1;
        else pl.inv.loot[o.item] = (pl.inv.loot[o.item] || 0) + 1;
        g.actors.say(m, 'Pleasure. We never met.');
      } },
      { label: 'Shake him down', fn: () => {
        if (R.rng() < 0.5 + pl.rep.infamy / 200) { const c = m.cash + 10; pl.addCash(c); m.cash = 0; g.actors.say(m, 'Okay okay! Take it!'); g.actors.setFlee(m, pl, 10); g.law.crime('mugging', m.x, m.y, { victim: m }); }
        else { g.actors.say(m, 'You picked the wrong hustler.'); m.hostile = true; g.actors.setFight(m, pl); }
      } },
      { label: 'Walk away', fn: () => { g.actors.say(m, 'Your loss, sport.'); m.state = 'idle'; } },
    ]);
  };

  EV.random = function (g) {
    const pl = g.player;
    if (pl.inside || g.law.active()) return;
    const w = g.world;
    const city = w.cityAt((pl.x / TS) | 0, (pl.y / TS) | 0);
    const hour = g.clock.hour();
    const roll = R.rng();
    const calm = g.calm();
    const rough = calm * calm; // violent events ramp in slower than friendly ones
    if (city) {
      const evs = [
        ['brawl', (hour > 20 || hour < 3 ? 3 : 0.6) * rough],
        ['robbery', 1 * rough],
        ['newsboy', hour > 6 && hour < 12 ? 2 : 0.4],
        ['party', hour > 21 || hour < 3 ? 1.6 : 0],
        ['wedding', g.pop.news.some((n) => n.city === city.id && n.day === g.pop.day && /Wedding/.test(n.text)) && hour > 10 && hour < 18 ? 3 : 0],
        ['footchase', 0.8 * rough],
        ['dealer', hour > 20 || hour < 4 ? 1.4 : 0.2],
        ['crash', 0.7 * calm],
        ['nothing', 2],
      ];
      const ev = R.rng.weighted(evs.filter((e) => e[1] > 0).map(([k, v]) => [k, v * (k === 'nothing' ? 1 : g.settings.events)]));
      if (EV[ev]) EV[ev](g, city);
    } else {
      const ev = R.rng.weighted([['hitchhiker', 1.3], ['ambush', 0.6 * rough], ['predator', 1 * rough], ['nothing', 2.5]].map(([k, v]) => [k, v * (k === 'nothing' ? 1 : g.settings.events)]));
      if (EV[ev]) EV[ev](g);
    }
  };
  const spotNear = (g, rmin, rmax, pred) => g.world.findNear(g.player.x / TS, g.player.y / TS, rmin, rmax, pred || ((x, y) => { const t = g.world.t(x, y); return (t === T.WALK || t === T.PLAZA) && !g.world.solidPed(x, y); }));

  EV.dealer = function (g) {
    const s = spotNear(g, 6, 12);
    if (!s || g.actors.list.some((a) => a.dealer && !a.dead)) return;
    const h = R.goods.spawnDealer(s.x * TS + 8, s.y * TS + 8);
    h.keep = true; h.stay = true; h.state = 'idle'; h.timer = 240;
    g.actors.say(h, R.rng.pick(['Psst. You holding? I\'m selling.', 'Candy, man? Got whatever you need.', 'Hey, sharp suit. Wanna feel sharper?']));
  };
  EV.brawl = function (g) {
    const s = spotNear(g, 8, 14);
    if (!s) return;
    const a = g.actors.makeHuman(s.x * TS + 4, s.y * TS + 8, { arch: 'tough', drunk: 1 });
    const b = g.actors.makeHuman(s.x * TS + 16, s.y * TS + 8, { arch: 'grumpy', drunk: 1 });
    a.hostileLocked = b.hostileLocked = true;
    a.tr.brave = b.tr.brave = 0.9;
    g.actors.setFight(a, b);
    g.actors.setFight(b, a);
    a.hostile = b.hostile = false;
    g.actors.say(a, R.rng.pick(['You spilled my drink!', 'Say that about my mother again!', "She was MY date!"]));
    g.actors.say(b, R.rng.pick(['Come on then!', "I'll knock your block off!"]));
    g.actors.noise(a.x, a.y, TS * 8, 'fight', a);
    g.ui.toast('A drunken brawl broke out nearby.');
  };
  EV.robbery = function (g, city) {
    const shops = city.buildings.filter((b) => D.btypes[b.type].rob && !b.destroyed && !b.sec && R.dist(b.out.x, b.out.y, g.player.x / TS, g.player.y / TS) < 22 && R.dist(b.out.x, b.out.y, g.player.x / TS, g.player.y / TS) > 6);
    if (!shops.length) return;
    const b = R.rng.pick(shops);
    const robber = g.actors.makeHuman(b.out.x * TS + 8, b.out.y * TS + 8, { tag: 'robber', weapon: 'revolver', arch: 'hustler' });
    robber.look.mask = true;
    robber.cash = R.rng.int(80, 200);
    robber.hostile = true;
    robber.alert = 'thief';
    robber.bounty = true;
    g.actors.setFlee(robber, { x: b.door.x * TS, y: b.door.y * TS }, 30);
    g.actors.say(robber, 'Outta my way!');
    const clerk = g.actors.makeHuman(b.out.x * TS + 12, b.out.y * TS + 12, {});
    clerk.state = 'idle'; clerk.timer = 8;
    g.actors.say(clerk, `Help! He robbed ${b.name}! Stop him!`);
    g.ui.toast(`${b.name} just got robbed. Stop the masked thief for a reward.`, 'warn');
    robber.onDeathReward = { b, amt: 60 };
  };
  EV.newsboy = function (g, city) {
    const s = spotNear(g, 6, 12);
    if (!s) return;
    const h = g.actors.makeHuman(s.x * TS + 8, s.y * TS + 8, { kid: true, tag: 'kid' });
    h.look.hat = 'cap'; h.look.hatCol = '#6a4a2a';
    const news = g.pop.news.filter((n) => n.city === city.id).slice(0, 3);
    const n = news.length ? R.rng.pick(news) : { text: 'Disco still not dead!' };
    h.state = 'idle'; h.timer = 12;
    g.actors.say(h, `Extra! Extra! ${n.text}`, 5, '#e4a92a');
  };
  EV.party = function (g, city) {
    const club = city.buildings.find((b) => (b.type === 'club' || b.type === 'bar') && R.dist(b.out.x, b.out.y, g.player.x / TS, g.player.y / TS) < 20);
    if (!club) return;
    const n = R.rng.int(4, 7);
    for (let k = 0; k < n; k++) {
      const h = g.actors.makeHuman(club.out.x * TS + 8 + (R.rng() - 0.5) * 50, club.out.y * TS + 8 + (R.rng() - 0.5) * 30, { arch: R.rng.pick(['flirt', 'friendly', 'eccentric']) });
      h.state = 'perform';
      h.role = 'dancer';
      h.timer = 30 + R.rng() * 20;
      h.look.top = R.rng.pick(['#e040a0', '#e4a92a', '#2a7d7a', '#f0f0f0', '#d9621e']);
    }
    g.ui.toast(`Block party spilling out of ${club.name}.`);
  };
  EV.wedding = function (g, city) {
    const church = city.buildings.find((b) => b.type === 'church');
    if (!church || R.dist(church.out.x, church.out.y, g.player.x / TS, g.player.y / TS) > 30) return;
    for (let k = 0; k < 8; k++) {
      const h = g.actors.makeHuman(church.out.x * TS + 8 + (R.rng() - 0.5) * 60, church.out.y * TS + 12 + R.rng() * 20, { arch: 'friendly' });
      h.state = 'watch';
      h.watchKind = 'wedding';
      h.watchT = { x: church.out.x * TS + 8, y: church.out.y * TS + 8 };
      h.timer = 40;
      if (k === 0) { h.look.top = '#f8f4ec'; h.look.dress = true; h.look.fem = true; }
      if (k === 1) { h.look.top = '#1a1a1a'; h.look.lapel = '#f0f0f0'; h.look.fem = false; }
    }
    g.ui.toast(`Wedding bells at ${church.name}.`);
  };
  EV.footchase = function (g, city) {
    const s = spotNear(g, 10, 16);
    if (!s) return;
    const perp = g.actors.makeHuman(s.x * TS + 8, s.y * TS + 8, { tag: 'robber', arch: 'hustler' });
    perp.hostile = true;
    perp.cash = R.rng.int(30, 90);
    perp.loot.push('watch');
    perp.alert = 'thief';
    const cop = g.actors.makeHuman(s.x * TS + 8 - 40, s.y * TS + 8, { cop: true, role: 'cop' });
    cop.look = g.pop.makeLook(R.mulberry(R.rng.int(0, 1e9)), { fem: false, age: 40, role: 'cop', city: city.id });
    g.actors.setFlee(perp, cop, 25);
    g.actors.setFight(cop, perp);
    cop.hostile = false;
    g.actors.say(cop, 'Stop! Police!');
    perp.onDeathReward = { amt: 30 };
  };
  EV.crash = function (g) {
    const cars = g.traffic.list.filter((v) => v.driver && v.driver !== g.player && v.mode === 'lane' && !g.cam.onScreen(v.x, v.y, -20) && R.dist(v.x, v.y, g.player.x, g.player.y) < TS * 18);
    if (!cars.length) return;
    const v = R.rng.pick(cars);
    v.ai.reckless = true;
    v.mode = 'chase';
    v.ai.wanderT = 4;
    v.ai.dest = null;
  };
  EV.hitchhiker = function (g) {
    const s = g.world.findNear(g.player.x / TS, g.player.y / TS, 8, 16, (x, y) => { const t = g.world.t(x, y); return !D.roadTile[t] && !g.world.solidPed(x, y) && D.roadTile[g.world.t(x + 1, y)]; });
    if (!s) return;
    const h = g.actors.makeHuman(s.x * TS + 8, s.y * TS + 8, { arch: R.rng.pick(['friendly', 'eccentric', 'gossip']) });
    h.tag = 'hitch';
    h.keep = true;
    const dest = R.rng.pick(g.world.cities);
    h.hitchDest = dest;
    h.state = 'idle';
    h.timer = 60;
    g.actors.say(h, `Ride to ${dest.name}? I can pay!`, 6);
    g.ui.toast(`A hitchhiker needs a ride to ${dest.name}. Stop your car next to them and honk.`);
  };
  EV.ambush = function (g) {
    const s = g.world.findNear(g.player.x / TS, g.player.y / TS, 12, 18, (x, y) => !g.world.solidPed(x, y) && !g.world.isWater(x, y));
    if (!s) return;
    const lure = g.actors.makeHuman(s.x * TS + 8, s.y * TS + 8, { arch: 'hustler', weapon: 'revolver' });
    lure.tag = 'lure';
    lure.drawn = false;
    g.actors.say(lure, 'Help! My car broke down! Please!', 5);
    lure.state = 'follow';
    lure.timer = 40;
    lure.onReach = (m) => {
      if (R.rng() < 0.55) {
        g.actors.say(m, 'Sucker. Boys, now!');
        m.hostile = true;
        g.actors.setFight(m, g.player);
        for (let k = 0; k < 2; k++) {
          const b = g.actors.makeHuman(m.x + (k ? 40 : -40), m.y + 30, { weapon: R.rng.pick(['bat', 'revolver', 'knife']), arch: 'tough' });
          b.hostile = true;
          g.actors.setFight(b, g.player);
        }
        g.ui.toast('Roadside ambush!', 'bad');
      } else {
        g.actors.say(m, "Oh thank God. Here, for your trouble. Don't tell my wife I was out here.");
        g.player.addCash(R.rng.int(10, 30));
        g.player.rep.honor += 2;
        m.state = 'idle';
      }
    };
  };
  EV.predator = function (g) {
    const s = g.world.findNear(g.player.x / TS, g.player.y / TS, 10, 16, (x, y) => !g.world.solidPed(x, y) && !g.world.isWater(x, y) && !D.roadTile[g.world.t(x, y)]);
    if (!s) return;
    const biome = g.world.biomeAt(s.x, s.y);
    const type = biome === 'marsh' ? 'gator' : biome === 'desert' ? 'coyote' : biome === 'forest' || biome === 'snow' ? (R.rng() < 0.3 ? 'bear' : 'wolf') : 'coyote';
    const victim = g.actors.makeHuman(s.x * TS + 8, s.y * TS + 8, { arch: 'timid' });
    victim.role = 'hunter';
    g.actors.say(victim, 'HELP! Somebody help me!', 5);
    const n = type === 'wolf' || type === 'coyote' ? 3 : 1;
    for (let k = 0; k < n; k++) {
      const a = g.actors.makeAnimal(victim.x + 40 + k * 10, victim.y + (k - 1) * 16, type);
      a.state = 'attack';
      a.target = victim;
      a.timer = 25;
    }
    g.actors.setFlee(victim, { x: victim.x + 40, y: victim.y }, 20);
    victim.onSavedReward = true;
    victim.keep = true;
    g.ui.toast('Someone is being attacked by animals nearby!');
  };
})();
