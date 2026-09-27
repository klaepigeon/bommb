// RHAPSODY — what's in your pockets. A proper inventory with pixel icons, 70s street
// drugs that say exactly what they are and what they'll do to you, the dealers who sell
// them, and hired help: people who like you will run errands for a fee or a cut.
(function () {
  const D = R.data, TS = R.TILE, INK = '#1b1410';

  // ---------------------------------------------------------------- drugs
  // dur is in seconds; each effect is applied while it lasts.
  D.drugs = {
    reefer: { name: 'Reefer', street: '"Acapulco Gold"', price: 10, dur: 120, desc: 'Mellow. +30 Cool now, people warm to you, a little snack-heal. Aim drifts.', fx: { cool: 30, heal: 8, mellow: 1 } },
    coke: { name: 'Cocaine', street: '"Nose candy"', price: 60, dur: 60, desc: 'Run 30% faster and hit 25% harder for a minute. Then the crash: sluggish and -15 health.', fx: { speed: 1.3, power: 1.25 }, crash: { speed: 0.8, hurt: 15, dur: 40 } },
    ludes: { name: 'Quaaludes', street: '"Lemmon 714s"', price: 25, dur: 90, desc: 'Numb. Take 40% less damage for 90 seconds, but you stagger like you\'re drunk.', fx: { armor: 0.6, drunk: 0.45 } },
    dust: { name: 'Angel Dust', street: '"Wack" (PCP)', price: 40, dur: 40, desc: 'Berserk. Punches hit 60% harder and nothing knocks you out. The comedown costs 25 health.', fx: { power: 1.6, tough: 1, red: 1 }, crash: { hurt: 25, dur: 5 } },
    acid: { name: 'LSD', street: '"Purple Owsley" blotter', price: 15, dur: 150, desc: 'The colours breathe. Cool keeps refilling and the Ring\'s Will comes back double. The city gets weird.', fx: { trip: 1, coolRegen: 6, willRegen: 2 } },
    uppers: { name: 'Black Beauties', street: 'Amphetamine pills', price: 20, dur: 150, desc: 'Wired. 15% faster, reload twice as fast, Cool drains slower. Mild comedown.', fx: { speed: 1.15, reload: 0.5, coolSave: 0.5 }, crash: { speed: 0.9, dur: 30 } },
    smack: { name: 'Heroin', street: '"Horse"', price: 50, dur: 90, desc: 'Heals 60 at once, then you\'re sluggish and dim for 90 seconds. Take it twice and you might not wake up.', fx: { heal: 60, speed: 0.65, dim: 1 }, od: 1 },
  };

  const G = () => R.game;
  const Goods = (R.goods = {});

  Goods.effects = function (pl) { return (pl.drugFx = pl.drugFx || {}); };
  Goods.mod = function (pl, key, base) {
    let v = base;
    const fx = this.effects(pl);
    for (const k in fx) {
      const e = fx[k];
      const src = e.crash ? D.drugs[k].crash : D.drugs[k].fx;
      if (src && src[key] !== undefined) v = typeof base === 'number' && key !== 'tough' ? v * src[key] : src[key];
    }
    return v;
  };
  Goods.has = function (pl, key) {
    const fx = this.effects(pl);
    for (const k in fx) { const src = fx[k].crash ? D.drugs[k].crash : D.drugs[k].fx; if (src && src[key]) return true; }
    return false;
  };
  Goods.take = function (id) {
    const g = G(), pl = g.player, d = D.drugs[id];
    if (!pl.inv.drugs || !pl.inv.drugs[id]) return;
    pl.inv.drugs[id]--;
    const fx = this.effects(pl);
    if (d.od && fx[id] && !fx[id].crash) {
      delete fx[id];
      g.ui.story('Overdose', 'The room tilts. The floor comes up to meet you.\n\nYou wake up in a hospital bed a day later with a $150 bill and a nurse who won\'t look at you.');
      pl.cash = Math.max(0, pl.cash - 150);
      g.clock.skip(1440);
      pl.hp = Math.round(pl.maxHp * 0.5);
      return;
    }
    fx[id] = { t: d.dur, crash: false };
    if (d.fx.cool) pl.cool = Math.min(100, pl.cool + d.fx.cool);
    if (d.fx.heal) pl.hp = Math.min(pl.maxHp, pl.hp + d.fx.heal);
    g.audio.sfx('drink');
    g.ui.toast(`${d.name}: ${d.desc.split('.')[0]}.`, 'good');
    // doing it in front of a cop is a (minor) crime
    g.law.crime('possession', pl.x, pl.y, { minor: true });
  };
  Goods.update = function (dt) {
    const g = G(), pl = g.player, fx = this.effects(pl);
    for (const k in fx) {
      const e = fx[k], d = D.drugs[k];
      e.t -= dt;
      if (!e.crash) {
        if (d.fx.coolRegen) pl.cool = Math.min(100, pl.cool + d.fx.coolRegen * dt);
        if (d.fx.willRegen && pl.will != null) pl.will = Math.min(100, pl.will + 5 * dt);
        if (d.fx.drunk) pl.drunk = Math.max(pl.drunk, d.fx.drunk);
        if (d.fx.tough && pl.hp < 1) pl.hp = 1;
      }
      if (e.t <= 0) {
        if (!e.crash && d.crash) {
          e.crash = true; e.t = d.crash.dur;
          if (d.crash.hurt) { pl.hp = Math.max(1, pl.hp - d.crash.hurt); g.ui.hurtFlash(d.crash.hurt); }
          g.ui.toast(`The ${d.name.toLowerCase()} wears off. Here comes the comedown.`, 'warn');
        } else { delete fx[k]; if (!d.crash || e.crash) g.ui.toast(`${d.name} has worn off.`); }
      }
    }
    // errands come due
    this.errandT = (this.errandT || 0) - dt;
    if (this.errandT <= 0) { this.errandT = 2; this.tickErrands(); }
  };
  // screen tints for whatever you're on
  Goods.overlay = function (g, w, h, t) {
    const pl = G().player;
    if (this.has(pl, 'trip')) {
      const hue = (t * 40) % 360;
      g.fillStyle = `hsla(${hue},80%,55%,0.13)`; g.fillRect(0, 0, w, h);
      g.fillStyle = `hsla(${(hue + 180) % 360},80%,55%,0.07)`; g.fillRect(0, h * 0.5 + Math.sin(t * 2) * h * 0.3, w, h * 0.2);
    }
    if (this.has(pl, 'red')) { g.fillStyle = `rgba(160,20,10,${0.12 + Math.sin(t * 6) * 0.04})`; g.fillRect(0, 0, w, h); }
    if (this.has(pl, 'dim')) { g.fillStyle = 'rgba(10,10,30,0.28)'; g.fillRect(0, 0, w, h); }
    if (this.has(pl, 'mellow')) { g.fillStyle = 'rgba(90,140,60,0.08)'; g.fillRect(0, 0, w, h); }
  };

  // ---------------------------------------------------------------- dealers
  Goods.dealerStock = function (h) {
    if (!h.stock) {
      const keys = Object.keys(D.drugs);
      const n = 3 + Math.floor(R.rng() * 3);
      h.stock = keys.sort(() => R.rng() - 0.5).slice(0, n);
      h.markup = 0.85 + R.rng() * 0.4;
    }
    return h.stock;
  };
  Goods.openDealer = function (h) {
    const g = G(), ui = g.ui, pl = g.player;
    pl.inv.drugs = pl.inv.drugs || {};
    const render = (line) => {
      const stock = this.dealerStock(h);
      const opts = stock.map((k) => {
        const d = D.drugs[k], p = Math.round(d.price * h.markup);
        return { label: `${d.name} · ${d.street}`, small: d.desc, price: R.fmtMoney(p), fn: () => {
          if (!pl.pay(p)) return render('"Cash up front, friend."');
          pl.inv.drugs[k] = (pl.inv.drugs[k] || 0) + 1;
          g.audio.sfx('cash');
          render(`"${R.rng.pick(['Pleasure doing business.', 'Good stuff, trust me.', 'Don\'t take it all at once, hear?', 'You didn\'t get it from me.'])}"`);
        } };
      });
      for (const k in pl.inv.drugs) if (pl.inv.drugs[k] > 0) {
        const d = D.drugs[k], p = Math.round(d.price * 0.55);
        opts.push({ label: `Sell ${d.name} (have ${pl.inv.drugs[k]})`, small: 'He\'ll take it off your hands, cheap.', price: '+' + R.fmtMoney(p), cls: 'go', fn: () => { pl.inv.drugs[k]--; pl.addCash(p); render('"I can move that."'); } });
      }
      opts.push({ label: 'Walk away', fn: () => ui.closeSheet() });
      const s = ui.openSheet('dealer', ui.header(h.strangerName || 'Dealer', 'Leather coat, gold teeth, eyes on the street. Everything he sells is labelled, more or less.') + `<div class="body"><div class="line">${line || '"What\'ll it be? I got the good stuff."'}</div>${ui.optsHtml(opts)}</div>`);
      ui.bindOpts(s, opts);
    };
    render();
  };
  Goods.spawnDealer = function (x, y, room) {
    const g = G();
    const h = g.actors.makeHuman(x, y, { arch: 'hustler', tag: 'dealer', role: 'dealer', cash: 80 + Math.floor(R.rng() * 120) });
    h.dealer = true;
    h.strangerName = R.rng.pick(['Slick', 'Candyman', 'Doc', 'Sugar', 'Jive', 'Lucky', 'Skinny Pete', 'The Pharmacist']);
    h.look.hatKind = R.rng.pick(['fedora', 'porkpie', 'beanie', null]);
    h.look.hatCol = D.style.hatCols[R.rng.pick(['red', 'cream', 'black', 'tan'])];
    if (room) h.room = room;
    return h;
  };

  // ---------------------------------------------------------------- hired help
  const ERRANDS = {
    job: { name: 'Handle my family job', desc: 'They do the job you\'re on; you keep the respect, they take 35% of the pay.' },
    car: { name: 'Boost me a car', fee: 80, desc: 'They steal something nice and leave it parked near you.' },
    store: { name: 'Knock over a store', desc: 'They rob a shop in another town. You split the haul 50/50.' },
    numbers: { name: 'Run numbers for a week', fee: 50, desc: 'A little each day from the local numbers game. Soldier rank or higher.' },
    scout: { name: 'Scout for me', fee: 20, desc: 'They ask around and mark something worth knowing on your map.' },
  };
  Goods.canHire = function (h) {
    const p = h.person;
    if (!p || h.cop || h.look.kid || p.role === 'don' || h.crew || h.dealer) return false;
    return p.opinion >= 25 || ((h.arch === 'hustler' || h.arch === 'tough') && p.opinion >= 0);
  };
  Goods.odds = function (h, kind) {
    const p = h.person, t = h.tr;
    const base = { job: 0.45 + t.brave * 0.35, car: 0.6 + t.greed * 0.2, store: 0.35 + t.brave * 0.4, numbers: 0.9, scout: 0.95 }[kind];
    return R.clamp(base + (p.fam || 0) * 0.02 + (p.opinion - 25) / 400, 0.1, 0.95);
  };
  Goods.openHire = function (h) {
    const g = G(), ui = g.ui, pl = g.player, p = h.person;
    pl.errands = pl.errands || [];
    const busy = pl.errands.find((e) => e.pid === p.id);
    if (busy) { ui.toast(`${p.first} is still busy with your last errand.`, 'warn'); return; }
    const opts = [];
    const j = g.jobs.active;
    for (const k in ERRANDS) {
      const e = ERRANDS[k];
      if (k === 'job' && !(j && ['collect', 'scare', 'rob', 'steal', 'torch'].includes(j.kind) && !pl.errands.some((q) => q.kind === 'job'))) continue;
      if (k === 'numbers' && g.jobs.rank() < 1) continue;
      const odds = Math.round(this.odds(h, k) * 100);
      opts.push({ label: k === 'job' ? `${e.name}: ${j.title}` : e.name, small: `${e.desc} Chance: ${odds}%.`, price: e.fee ? R.fmtMoney(e.fee) : 'Cut', fn: () => {
        if (e.fee && !pl.pay(e.fee)) return ui.toast('You can\'t cover the fee.', 'warn');
        const hours = k === 'numbers' ? 24 : k === 'scout' ? 1 : 2 + Math.floor(R.rng() * 4);
        pl.errands.push({ pid: p.id, kind: k, due: g.clock.t + hours * 60, left: k === 'numbers' ? 7 : 1, job: k === 'job' ? j.id : null, city: h.person.city });
        g.actors.say(h, R.rng.pick(['Consider it done, boss.', 'I\'ll take care of it.', 'Give me a few hours.', 'You won\'t regret this.']));
        ui.closeSheet();
        ui.toast(`${p.first} is on it. ${k === 'numbers' ? 'Money comes in each day.' : `Expect a call in about ${hours} hours.`}`, 'good');
        if (k === 'job') g.jobs.active.delegated = p.id;
      } });
    }
    opts.push({ label: 'Never mind', fn: () => ui.closeSheet() });
    const s = ui.openSheet('hire', ui.header(`Hire ${p.first} ${p.last}`, `${g.pop.title(p)}, ${p.age}. Likes you ${p.opinion > 60 ? 'a lot' : p.opinion > 25 ? 'well enough' : 'for the money'}. Brave ${Math.round(h.tr.brave * 10)}/10.`) + `<div class="body">${ui.optsHtml(opts)}</div>`);
    ui.bindOpts(s, opts);
  };
  Goods.tickErrands = function () {
    const g = G(), pl = g.player;
    if (!pl.errands || !pl.errands.length) return;
    for (const e of pl.errands.slice()) {
      if (g.clock.t < e.due) continue;
      const p = g.pop.people[e.pid];
      const done = () => { pl.errands.splice(pl.errands.indexOf(e), 1); };
      if (!p || !p.alive) { done(); continue; }
      const h = { person: p, tr: p.tr || { brave: 0.5, greed: 0.5 } };
      const ok = R.rng() < this.odds(h, e.kind);
      const who = `${p.first} ${p.last}`;
      const call = (txt, good) => g.ui.story(good ? 'The phone rings' : 'Bad news', `${who}: "${txt}"`);
      if (e.kind === 'job') {
        const j = g.jobs.active;
        done();
        if (!j || j.id !== e.job) { call('Job\'s already off? Fine, I walked away.', false); continue; }
        if (ok) { const cut = Math.round(j.reward * 0.35); g.jobs.complete(j, -cut); g.ui.toast(`${p.first} took a ${R.fmtMoney(cut)} cut.`); }
        else { call(R.rng.pick(['It went sideways. Cops showed up. I got out, the job didn\'t.', 'They didn\'t scare. I\'m sorry, boss.']), false); j.delegated = null; }
      } else if (e.kind === 'car') {
        done();
        if (ok) {
          const w = g.world, s = w.findNear(pl.x / TS, pl.y / TS, 3, 10, (x, y) => D.roadTile[w.t(x, y)] || w.t(x, y) === D.T.PARKING);
          const model = R.rng.pick(['muscle', 'coupe', 'sedan', 'pickup', 'van']);
          if (s && !pl.room) { const v = g.traffic.make(model, s.x * TS + 8, s.y * TS + 8, 0, { parked: true, keep: true, locked: false }); v.owner = 'player'; v.hotwired = true; pl.ownedCars.push(v); }
          call(`Left a ${D.vehicles[model].name} for you just down the street. Keys in the visor. Hot as a pistol, so repaint it.`, true);
        } else call('Owner came out with a shotgun. I ran. No car, sorry.', false);
      } else if (e.kind === 'store') {
        done();
        if (ok) { const haul = 60 + Math.floor(R.rng() * 160); pl.addCash(Math.round(haul / 2)); call(`Hit a ${R.rng.pick(['liquor store', 'gas station', 'diner'])} over in ${g.world.cities.find((c) => c.id !== e.city).name}. ${R.fmtMoney(haul)} total. Your half's on the way.`, true); }
        else { p.opinion -= 10; g.pop.addNews(e.city, `${p.first} ${p.last} (${p.age}) arrested after a botched robbery.`); call('They got me. Don\'t worry, I didn\'t say your name. Probably.', false); if (R.rng() < 0.25) { const jur = g.law.jurAt(pl.x, pl.y); g.law.bounty[jur] = (g.law.bounty[jur] || 0) + 30; g.ui.toast('...They said your name. +$30 bounty.', 'bad'); } }
      } else if (e.kind === 'numbers') {
        const take = 15 + Math.floor(R.rng() * 30);
        pl.addCash(take);
        g.ui.toast(`${p.first} drops off ${R.fmtMoney(take)} from the numbers.`, 'good');
        e.left--; e.due += 1440;
        if (e.left <= 0) { done(); g.ui.toast(`${p.first} is done running your numbers. Hire them again any time.`); }
      } else if (e.kind === 'scout') {
        done();
        const b = R.rng.pick(g.world.buildings.filter((q) => q && !q.destroyed && ['bank', 'casino', 'pawn', 'jewelry', 'gunshop', 'liquor'].includes(q.type)));
        if (b) { R.poi && R.poi.add(b.out.x, b.out.y, 'tip', `${p.first}'s tip: ${b.name}`, 'Worth a look'); call(`${b.name} in ${b.city.name}. Night guard sleeps on the job. I marked it on your map.`, true); }
      }
    }
  };

  // ---------------------------------------------------------------- inventory
  // item icons painted on the original's pixel canvas
  const X = () => R.old.x;
  const ICON = {
    knuckles(o) { const m = X().metal; for (let i = 0; i < 4; i++) o.shadedEllipse(4 + i * 3, 7, 1.8, 2.2, m); o.shadedRect(3, 9, 11, 3, m); },
    bat(o) { o.line(2, 14, 13, 3, X().wood[2]); o.line(3, 14, 14, 3, X().wood[1]); o.rect(11, 2, 3, 3, X().wood[2]); },
    knife(o) { o.line(3, 13, 7, 9, X().wood[1]); o.line(7, 9, 14, 2, X().metal[3]); o.line(8, 9, 14, 3, X().metal[2]); },
    revolver(o) { const m = X().metal; o.shadedRect(3, 5, 10, 3, m); o.shadedRect(4, 8, 4, 2, m); o.shadedRect(3, 9, 3, 5, X().wood); },
    magnum(o) { const m = X().black; o.shadedRect(2, 5, 12, 3, m); o.shadedRect(4, 8, 4, 2, m); o.shadedRect(3, 9, 3, 5, X().wood); },
    shotgun(o) { o.shadedRect(1, 6, 14, 2, X().metal); o.shadedRect(1, 8, 6, 3, X().wood); o.shadedRect(9, 8, 4, 1, X().wood); },
    chopper(o) { const m = X().black; o.shadedRect(2, 5, 12, 3, m); o.shadedEllipse(7, 10, 3, 3, m); o.shadedRect(2, 8, 3, 4, X().wood); },
    rifle(o) { o.shadedRect(0, 6, 16, 2, X().metal); o.shadedRect(0, 8, 7, 3, X().wood); o.rect(7, 4, 5, 2, X().black[2]); },
    molotov(o) { o.shadedRect(6, 6, 5, 8, X().glass); o.rect(7, 3, 3, 3, X().glass[2]); o.rect(8, 1, 2, 3, X().cloth ? X().cloth[2] : '#e0d0a0'); o.set(9, 0, '#ffb030'); },
    dynamite(o) { o.shadedRect(4, 4, 8, 10, X().red); o.hline(4, 11, 8, X().red[0]); o.line(8, 4, 10, 0, '#8a8a8a'); o.set(10, 0, '#ffd040'); },
    ammo(o) { for (let i = 0; i < 3; i++) { o.shadedRect(3 + i * 4, 6, 3, 8, X().yellow); o.rect(3 + i * 4, 4, 3, 2, X().metal[2]); } },
    bandage(o) { o.shadedRect(3, 5, 10, 7, X().white); o.rect(7, 6, 2, 5, X().red[2]); o.rect(5, 8, 6, 1, X().red[2]); },
    whiskey(o) { o.shadedRect(5, 6, 6, 8, ['#4a2a0a', '#7a4a14', '#a86a20', '#d8a048']); o.rect(7, 2, 2, 4, '#5a3a1a'); o.rect(6, 9, 4, 2, '#f0e0b0'); },
    smokes(o) { o.shadedRect(4, 4, 8, 10, X().red); o.rect(4, 4, 8, 3, X().white[2]); for (let i = 0; i < 3; i++) o.rect(5 + i * 2, 2, 1, 2, '#f0e8d0'); },
    coffee(o) { o.shadedRect(4, 5, 7, 8, X().white); o.rect(11, 7, 2, 3, X().white[1]); o.rect(5, 5, 5, 1, '#3a2010'); },
    sandwich(o) { o.shadedRect(2, 7, 12, 2, X().wood); o.rect(2, 9, 12, 1, '#6a9a3a'); o.rect(2, 10, 12, 1, '#c84a3a'); o.shadedRect(2, 11, 12, 2, X().wood); },
    tonic(o) { o.shadedRect(5, 5, 6, 9, ['#2a3a1a', '#3a5a2a', '#5a8a3a', '#8ac060']); o.rect(6, 2, 4, 3, X().wood[2]); o.rect(6, 8, 4, 3, '#f0e0b0'); },
    reefer(o) { o.line(2, 12, 13, 6, '#f0ead4'); o.line(2, 13, 13, 7, '#d8d0b8'); o.set(14, 6, '#ff7030'); o.set(15, 5, '#a0a0a0'); o.set(15, 3, '#c0c0c0'); },
    coke(o) { o.shadedRect(4, 5, 8, 8, ['#8a8a90', '#c0c0c8', '#e8e8f0', '#ffffff']); o.rect(6, 3, 4, 2, '#c0c0c8'); o.rect(4, 5, 8, 1, '#e04040'); },
    ludes(o) { for (const [x, y] of [[5, 7], [10, 6], [7, 11]]) o.shadedEllipse(x, y, 2.5, 2.5, X().white); },
    dust(o) { o.shadedRect(6, 4, 4, 10, X().glass); o.rect(6, 2, 4, 2, X().red[2]); o.rect(7, 10, 2, 3, '#e8e0f0'); },
    acid(o) { o.shadedRect(3, 3, 10, 10, ['#4a2a6a', '#6a3a9a', '#9a5ac8', '#c890f0']); o.ellipse(8, 8, 2.5, 2.5, '#ffd040'); o.set(8, 8, '#e04040'); },
    uppers(o) { for (const [x, y] of [[5, 6], [10, 8], [6, 11]]) { o.shadedEllipse(x, y, 2.5, 1.8, X().black); } },
    smack(o) { o.shadedRect(4, 6, 8, 6, ['#6a5a3a', '#9a8a60', '#c8b888', '#e8dcb0']); o.line(4, 6, 8, 3, '#9a8a60'); o.line(8, 3, 12, 6, '#9a8a60'); },
    lockpick(o) { o.line(2, 13, 12, 3, X().metal[3]); o.line(3, 13, 13, 3, X().metal[1]); o.rect(12, 2, 2, 1, X().metal[3]); o.line(4, 14, 13, 8, X().metal[2]); },
    gascan(o) { o.shadedRect(3, 5, 10, 9, X().red); o.rect(10, 3, 3, 2, X().metal[2]); o.rect(5, 3, 3, 2, X().black[2]); },
    rod(o) { o.line(1, 14, 14, 1, X().wood[2]); o.line(14, 1, 14, 10, '#d0d0d0'); o.set(14, 11, X().metal[2]); },
    mask(o) { o.shadedEllipse(8, 8, 5.5, 6.5, X().black); o.rect(5, 6, 2, 2, '#e0ac7e'); o.rect(9, 6, 2, 2, '#e0ac7e'); o.rect(6, 11, 4, 1, '#e0ac7e'); },
    bait(o) { o.shadedRect(4, 6, 8, 7, X().wood); o.line(6, 5, 10, 3, '#c86a6a'); },
    rope(o) { o.ellipse(8, 8, 6, 6, X().wood[2]); o.ellipse(8, 8, 3.5, 3.5, null); o.ellipse(8, 8, 4, 4, X().wood[1]); o.ellipse(8, 8, 3, 3, null); },
    ring(o) { o.ellipse(8, 9, 5, 4, '#f0c020'); o.ellipse(8, 9, 3, 2, null); o.shadedRect(6, 2, 4, 3, ['#6a4600', '#b88400', '#f0c020', '#fff27a']); },
    watch(o) { o.rect(6, 1, 4, 14, X().wood[1]); o.shadedEllipse(8, 8, 4, 4, X().yellow); o.ellipse(8, 8, 2.8, 2.8, '#fff8e0'); o.line(8, 8, 8, 6, INK); },
    chain(o) { for (let i = 0; i < 6; i++) o.ellipse(3 + i * 2, 5 + Math.abs(3 - i) * -1 + 6, 1.5, 1.2, X().yellow[2]); },
    jewels(o) { o.shadedRect(2, 6, 12, 8, ['#3a1a2a', '#5a2a44', '#7a3a60', '#9a5a80']); o.set(5, 5, '#80f0f0'); o.set(9, 4, '#f06080'); o.set(11, 5, '#f0f080'); },
    bonds(o) { o.shadedRect(2, 3, 12, 10, ['#6a7a5a', '#9aaa80', '#c8d4a8', '#e8f0d0']); o.hline(4, 11, 6, '#3a5a2a'); o.hline(4, 9, 9, '#3a5a2a'); },
    painting(o) { o.shadedRect(1, 2, 14, 12, X().yellow); o.rect(3, 4, 10, 8, '#3a6a8a'); o.rect(3, 9, 10, 3, '#4a7a3a'); o.set(10, 6, '#f0e060'); },
    pelt(o) { o.ellipse(8, 9, 6.5, 5, X().wood[2]); o.rect(2, 4, 2, 3, X().wood[1]); o.rect(12, 4, 2, 3, X().wood[1]); o.rect(2, 12, 2, 3, X().wood[1]); o.rect(12, 12, 2, 3, X().wood[1]); },
    doubloon(o) { o.shadedEllipse(8, 8, 6, 6, X().yellow); o.ellipse(8, 8, 3.5, 3.5, X().yellow[1]); o.set(8, 8, X().yellow[3]); },
    loot(o) { o.shadedRect(3, 5, 10, 9, X().wood); o.rect(3, 8, 10, 1, X().wood[0]); o.rect(7, 8, 2, 2, X().yellow[2]); },
  };
  const ALIAS = { pelt_rabbit: 'pelt', pelt_deer: 'pelt', pelt_wolf: 'pelt', pelt_bear: 'pelt', pelt_gator: 'pelt', pelt_coyote: 'pelt', pelt_boar: 'pelt', pelt_squatch: 'pelt', pelt_scratch: 'pelt', ring: 'ring', fur: 'pelt', tv: 'prop:tv', fish: 'prop:fish', bigfish: 'prop:fish', meat: 'pelt', eight: 'loot', cam: 'loot', radio: 'loot', silver: 'loot', pistol: 'ammo', shells: 'ammo', smg: 'ammo' };
  const iconCache = {};
  Goods.icon = function (key, jewelRing) {
    const k = jewelRing ? 'watch' : key;
    if (iconCache[k]) return iconCache[k];
    let a = ALIAS[k] || k, cv;
    if (a.startsWith('prop:')) cv = R.old.paintProp(a.slice(5));
    else {
      const f = ICON[a] || ICON.loot;
      const o = new R.old.O(16, 16);
      try { f(o); } catch (e) { ICON.loot(o); }
      cv = o.outlineBy(R.old.Ue).toCanvas();
    }
    return (iconCache[k] = cv);
  };

  // every item the player holds, grouped
  Goods.items = function () {
    const pl = G().player, inv = pl.inv, out = [];
    const push = (sec, key, name, n, desc, actions, iconKey) => out.push({ sec, key, name, n, desc, actions: actions || [], icon: iconKey || key });
    for (const w of pl.weaponList()) {
      if (w === 'fists' || w === 'gascan') continue;
      const d = D.weapons[w];
      const n = d.gun ? `${pl.clip[w] || 0}+${inv.ammo[d.ammo] || 0}` : d.thrown ? inv.ammo[w] : '';
      push('Weapons', w, d.name, n, d.gun ? `Damage ${d.dmg}${d.pellets ? '×' + d.pellets : ''}, range ${d.range}, ${d.clip}-round clip.` : d.thrown ? 'Thrown. Lights things up.' : `Melee. Damage ${d.dmg}.`, [['equip', 'Equip']]);
    }
    if (pl.held) push('Weapons', 'held', D.props[pl.held.k].name, pl.held.dur >= 99 ? '' : pl.held.dur, 'Improvised. HIT swings it, SWAP throws it.', [['drop', 'Drop']], 'prop:' + pl.held.k);
    for (const k in inv.cons) if (inv.cons[k]) { const c = D.consumables[k]; push('Food & first aid', k, c.name, inv.cons[k], [c.heal ? `+${c.heal} health` : '', c.cool ? `+${c.cool} Cool` : '', c.drunk ? 'gets you tipsy' : '', c.sober ? 'sobers you up' : ''].filter(Boolean).join(', ') + '.', [['use', 'Use']]); }
    for (const k in inv.drugs || {}) if (inv.drugs[k]) { const d = D.drugs[k]; push('Drugs', k, `${d.name} ${d.street}`, inv.drugs[k], d.desc, [['take', 'Take']]); }
    for (const k in inv.tools) if (inv.tools[k]) { if (k === 'ring') { push('Tools', 'ring', 'The Yellow Ring', '', 'Hard light from will. Tap RING to conjure, hold to beam, LIB to choose.', [['lib', 'Library']]); continue; } const t = D.tools[k]; if (t) push('Tools', k, t.name, inv.tools[k] > 1 ? inv.tools[k] : '', { lockpick: 'Opens doors and car locks quietly.', gascan: 'Pour a trail, then light it.', rod: 'Stand by water and press USE.', mask: 'MASK button. Witnesses can\'t name you.', bait: 'Fish bite faster.', rope: 'For tying things up.' }[k] || ''); }
    for (const k in inv.loot) if (inv.loot[k]) { const l = D.loot[k]; if (l) push(l.pelt ? 'Pelts & catch' : 'Valuables', k, l.name, inv.loot[k], `Worth about ${R.fmtMoney(l.v)} to a ${l.pelt ? 'butcher' : 'fence'}.`, [], k); }
    for (const k in inv.ammo) if (inv.ammo[k] && !D.weapons[k]) push('Ammo', k, D.ammoNames[k] || k, inv.ammo[k], 'Loose rounds.', [], 'ammo');
    return out;
  };
  Goods.act = function (it, a) {
    const g = G(), pl = g.player;
    if (a === 'equip') { pl.weapon = it.key; pl.weaponOut = it.key !== 'fists'; g.audio.sfx('equip'); }
    if (a === 'use') { const c = D.consumables[it.key]; pl.inv.cons[it.key]--; if (c.heal) pl.hp = Math.min(pl.maxHp, pl.hp + c.heal); if (c.cool) pl.cool = Math.min(100, pl.cool + c.cool); if (c.drunk) pl.drunk = Math.min(1, pl.drunk + c.drunk); if (c.sober) pl.drunk = 0; g.audio.sfx('drink'); }
    if (a === 'take') this.take(it.key);
    if (a === 'drop') R.props.dropHeld(pl);
    if (a === 'lib') { g.ui.closeSheet(); R.ring.openLibrary(); return true; }
  };
  Goods.renderInventory = function (body, onChange) {
    const g = G(), pl = g.player;
    const items = this.items();
    const secs = [...new Set(items.map((i) => i.sec))];
    body.innerHTML = `<div class="invtop"><span>${R.fmtMoney(pl.cash)}</span><span>${Math.round(pl.hp)}/${pl.maxHp} health</span><span>Cool ${Math.round(pl.cool)}</span>${Object.keys(this.effects(pl)).length ? `<span class="high">On: ${Object.keys(this.effects(pl)).map((k) => D.drugs[k].name + (this.effects(pl)[k].crash ? ' (comedown)' : '')).join(', ')}</span>` : ''}</div>` +
      (items.length ? secs.map((sec) => `<div class="sect">${sec}</div><div class="invgrid">${items.map((it, i) => (it.sec === sec ? `<button class="inv" data-i="${i}"><canvas width="32" height="32"></canvas><b>${it.n !== '' && it.n !== undefined ? it.n : ''}</b><span>${it.name}</span></button>` : '')).join('')}</div>`).join('') : '<p>Your pockets are empty.</p>') +
      `<div class="invdetail" id="invd">Tap something to look at it.</div>`;
    body.querySelectorAll('.inv').forEach((b) => {
      const it = items[+b.dataset.i];
      const cv = b.querySelector('canvas'), cg = cv.getContext('2d');
      cg.imageSmoothingEnabled = false;
      const ic = it.icon.startsWith && it.icon.startsWith('prop:') ? R.old.paintProp(it.icon.slice(5)) : this.icon(it.icon);
      cg.drawImage(ic, 0, 0, 32, 32);
      b.addEventListener('click', () => {
        const d = body.querySelector('#invd');
        d.innerHTML = `<b>${it.name}</b><p>${it.desc}</p><div class="opts">${it.actions.map(([k, l]) => `<button class="opt go" data-a="${k}">${l}</button>`).join('')}</div>`;
        d.querySelectorAll('[data-a]').forEach((x) => x.addEventListener('click', () => { if (!this.act(it, x.dataset.a)) onChange(); }));
      });
    });
  };
})();

// on acid, the city starts talking nonsense
(function () {
  const AP = R.Actors.prototype, baseSay = AP.say;
  const WEIRD = ['The walls are breathing, man.', 'Your aura is SO orange.', 'I can taste purple.', 'Are you... are you made of jazz?', 'The pigeons know.', 'Everything is connected, brother.', 'Why is your face melting? Cool.', 'I am the walrus.'];
  AP.say = function (h, text, dur, color) {
    if (h && h.kind === 'h' && R.goods.has(this.game.player, 'trip') && R.rng() < 0.45) text = WEIRD[Math.floor(R.rng() * WEIRD.length)];
    return baseSay.call(this, h, text, dur, color);
  };
})();
