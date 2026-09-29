// RHAPSODY — the families, your rank, procedural contracts, rackets and leads.
'use strict';
(function () {
  const D = R.data, T = D.T, TS = R.TILE;
  const RANKS = ['Associate', 'Soldier', 'Capo', 'Underboss', 'Consigliere', 'Boss'];
  const RANK_REP = [0, 80, 240, 520, 950, 1600];

  const Jobs = (R.Jobs = function (game) {
    this.game = game;
    this.standing = {}; // family -> -100..100
    this.rep = 0; // with own family
    this.offers = {}; // family -> [job]
    this.offerDay = {};
    this.active = null;
    this.leads = [];
    this.done = 0;
    for (const c of D.cities) this.standing[c.family] = 0;
    this.nid = 1;
  });
  const J = Jobs.prototype;
  J.RANKS = RANKS;

  J.rank = function () {
    let r = 0;
    for (let i = 0; i < RANK_REP.length; i++) if (this.rep >= RANK_REP[i]) r = i;
    return r;
  };
  J.rankName = function () { return RANKS[this.rank()]; };
  J.nextRankRep = function () { return RANK_REP[Math.min(RANK_REP.length - 1, this.rank() + 1)]; };
  J.familyStanding = function (f) { return f === this.game.player.family ? Math.max(40, this.standing[f] || 0) : this.standing[f] || 0; };
  J.donName = function (f) {
    const c = D.cities.find((c) => c.family === f);
    return c ? c.don.replace(/ ".*?"/, '').split(' ').pop() : f;
  };
  J.cityFamily = function (h) {
    const c = this.game.world.cityAt((h.x / TS) | 0, (h.y / TS) | 0);
    return c ? c.def.family : null;
  };
  J.cityOfFamily = function (f) {
    const d = D.cities.find((c) => c.family === f);
    return d ? this.game.world.cities.find((c) => c.id === d.id) : null;
  };
  J.addRep = function (n, family) {
    const pl = this.game.player;
    if (!family || family === pl.family) {
      const before = this.rank();
      this.rep += n;
      this.standing[pl.family] = R.clamp((this.standing[pl.family] || 0) + n / 10, -100, 100);
      const after = this.rank();
      if (after > before) this.promote(after);
    } else {
      this.standing[family] = R.clamp((this.standing[family] || 0) + n / 5, -100, 100);
      // freelancing for a rival costs a little at home
      this.standing[pl.family] = R.clamp((this.standing[pl.family] || 0) - n / 20, -100, 100);
    }
  };
  J.promote = function (r) {
    const g = this.game;
    const perks = [
      '',
      'Soldiers can shake down shops for protection money.',
      'Capos can recruit a crew of two from people who like them.',
      'Underbosses collect a weekly tribute from the family.',
      'The Consigliere\'s word clears bounties: the family pays half your fines.',
      'You run the family now. Every racket in town pays you.',
    ];
    g.ui.story('MADE', `Don ${this.donName(g.player.family)} kisses both your cheeks. You are now a ${RANKS[r]} of the ${g.player.family} family.\n\n${perks[r]}`);
    g.audio.sfx('promote');
  };

  // ---------------------------------------------------------------- contracts
  J.offersFor = function (family) {
    const g = this.game;
    if (this.offerDay[family] === g.pop.day && this.offers[family]) return this.offers[family];
    const rnd = R.mulberry(g.pop.day * 131 + R.strHash(family));
    const city = this.cityOfFamily(family);
    const list = [];
    const kinds = ['collect', 'collect', 'hit', 'deliver', 'steal', 'torch', 'rob', 'racket', 'scare'];
    rnd.shuffle(kinds);
    for (const k of kinds) {
      if (list.length >= 3) break;
      const j = this.makeJob(k, family, city, rnd);
      if (j) list.push(j);
    }
    this.offers[family] = list;
    this.offerDay[family] = g.pop.day;
    return list;
  };
  J.makeJob = function (kind, family, city, rnd) {
    const g = this.game, pop = g.pop, w = g.world;
    const scale = 1 + this.rank() * 0.35;
    const people = (pop.byCity[city.id] || []).filter((p) => p.alive && p.age >= 18 && !p.isDon && p.role !== 'cop' && !p.jailed);
    const rivals = D.cities.filter((c) => c.family !== family).map((c) => c.family);
    const j = { id: this.nid++, kind, family, city: city.id, stage: 0, reward: 0, rep: 0 };
    if (kind === 'collect' || kind === 'scare') {
      const p = rnd.pick(people.filter((q) => q.role !== 'capo' && q.role !== 'soldier'));
      if (!p) return null;
      j.person = p.id;
      j.amount = Math.round((kind === 'collect' ? rnd.int(60, 180) : 0) * scale);
      j.reward = kind === 'collect' ? Math.round(j.amount * 0.35) + 20 : Math.round(rnd.int(40, 80) * scale);
      j.rep = kind === 'collect' ? 30 : 25;
      j.title = kind === 'collect' ? `Collect from ${pop.name(p)}` : `Lean on ${pop.name(p)}`;
      j.desc = kind === 'collect'
        ? `${p.first} borrowed ${R.fmtMoney(j.amount)} and stopped returning calls. ${pop.title(p)}${p.work ? ' at ' + w.buildings[p.work].name : ''}. Get the money. Break something if you have to, but the dead don't pay.`
        : `${p.first} has been talking to the cops. Make them understand that talking is bad for their health. Antagonize them until they're scared stiff. Don't kill them.`;
      return j;
    }
    if (kind === 'hit') {
      const tg = rnd.pick(people.filter((q) => (q.faction && q.faction !== family) || q.role === 'hustler' || q.role === 'fence' || rnd() < 0.05));
      if (!tg) return null;
      j.person = tg.id;
      j.reward = Math.round(rnd.int(180, 320) * scale);
      j.rep = 70;
      j.title = `Whack ${pop.name(tg)}`;
      j.desc = `${tg.first} ${tg.last}, ${pop.title(tg).toLowerCase()}. ${rnd.pick(['A rat.', 'Skimming from the family.', 'Disrespected the Don at a wedding.', 'Knows too much.'])} Quietly, if you can. A mask helps.`;
      return j;
    }
    if (kind === 'deliver') {
      const dest = rnd.pick(w.cities.filter((c) => c.id !== city.id));
      const dclub = dest.buildings.find((b) => b.type === 'social') || dest.buildings[0];
      const src = rnd.pick(city.buildings.filter((b) => b.type === 'warehouse' || b.type === 'garage' || b.type === 'social'));
      if (!dclub || !src) return null;
      j.src = src.id;
      j.dest = dclub.id;
      j.reward = Math.round((80 + R.dist(src.x, src.y, dclub.x, dclub.y) * 0.5) * scale);
      j.rep = 35;
      j.minutes = Math.round(R.dist(src.x, src.y, dclub.x, dclub.y) * 0.18 + 12);
      j.title = `Run a van to ${dest.name}`;
      j.desc = `There's a Mystic Van behind ${src.name}. What's in the back is none of your business. Get it to ${dclub.name} in ${dest.name} within ${j.minutes} minutes, in one piece, without a tail.`;
      return j;
    }
    if (kind === 'steal') {
      const models = ['muscle', 'coupe', 'wagon', 'van'];
      j.model = rnd.pick(models);
      const garage = city.buildings.find((b) => b.type === 'garage');
      const tcity = rnd.pick(w.cities);
      const lotB = rnd.pick(tcity.buildings.filter((b) => !b.destroyed && b.type !== 'police'));
      if (!garage || !lotB) return null;
      j.dest = garage.id;
      j.at = lotB.id;
      j.reward = Math.round(D.vehicles[j.model].price * 0.25 * scale);
      j.rep = 30;
      j.title = `Boost a ${D.vehicles[j.model].name}`;
      j.desc = `A client wants a ${D.vehicles[j.model].name}. One's parked near ${lotB.name} in ${tcity.name}. Bring it to ${garage.name} with the paint unscratched. Break in when nobody's looking.`;
      return j;
    }
    if (kind === 'torch') {
      const rc = w.cities.filter((c) => c.def.family !== family);
      const tcity = rnd.pick(rc);
      const b = rnd.pick(tcity.buildings.filter((b) => !b.destroyed && ['bar', 'club', 'diner', 'laundry', 'general', 'liquor', 'warehouse'].includes(b.type)));
      if (!b) return null;
      j.building = b.id;
      j.reward = Math.round(rnd.int(200, 350) * scale);
      j.rep = 60;
      j.title = `Torch ${b.name}`;
      j.desc = `${b.name} in ${tcity.name} pays the ${tcity.def.family}s. Burn it. Gas cans are at any gas station; molotovs at the gun store. Arson draws a crowd, so leave fast.`;
      return j;
    }
    if (kind === 'rob') {
      const tcity = rnd.pick(w.cities.filter((c) => c.def.family !== family));
      const b = rnd.pick(tcity.buildings.filter((b) => !b.destroyed && D.btypes[b.type].rob));
      if (!b) return null;
      j.building = b.id;
      j.reward = Math.round(rnd.int(60, 120) * scale);
      j.rep = 40;
      j.title = `Knock over ${b.name}`;
      j.desc = `${b.name} in ${tcity.name}. The ${tcity.def.family}s call it theirs. Walk in, gun out, empty the register. If the clerk gets brave, deal with them and empty the till yourself. Keep what's in it plus our fee.`;
      return j;
    }
    if (kind === 'racket') {
      j.need = 2;
      j.count = 0;
      j.reward = Math.round(120 * scale);
      j.rep = 50;
      j.title = 'Sign up two new "clients"';
      j.desc = `Visit shopkeepers in ${city.name} and explain the benefits of protection. Talk to a clerk, cook, barber or tailor. Needs Soldier rank.`;
      if (this.rank() < 1) return null;
      return j;
    }
    return null;
  };

  J.accept = function (j) {
    const g = this.game, pop = g.pop, w = g.world;
    if (this.active) this.abandon(true);
    this.active = j;
    j.stage = 1;
    j.started = g.clock.t;
    if (j.person !== undefined) {
      const p = pop.people[j.person];
      // they'll be hanging around outside their workplace or home
      const b = w.buildings[p.work] || w.buildings[p.home];
      if (b) {
        const spot = { x: b.out.x, y: b.out.y, city: b.city, kind: 'job', i: w.spots.length };
        w.spots.push(spot);
        p.forceSpot = spot;
      }
      g.life.cache.delete(p.id);
      if (j.kind === 'collect') p.debt = j.amount;
    }
    if (j.kind === 'deliver') {
      const src = w.buildings[j.src];
      const v = this.spawnCarNear(src, 'van');
      if (v) { v.jobCar = j.id; v.keep = true; v.locked = false; j.car = v; }
    }
    if (j.kind === 'steal') {
      j.spawned = false;
    }
    g.ui.toast(`Job accepted: ${j.title}`, 'good');
    g.audio.sfx('accept');
  };
  J.spawnCarNear = function (b, model) {
    const g = this.game, w = g.world;
    const s = w.findNear(b.out.x, b.out.y, 1, 6, (x, y) => { const t = w.t(x, y); return (t === T.PARKING || t === T.LOT || t === T.WALK || D.roadTile[t]) && !w.solidCar(x, y) && !w.solidCar(x + 1, y) && !w.solidCar(x - 1, y); });
    if (!s) return null;
    return g.traffic.make(model, s.x * TS + 8, s.y * TS + 8, 0, { parked: true, keep: true, locked: false });
  };
  J.abandon = function (quiet) {
    const g = this.game;
    const j = this.active;
    if (!j) return;
    if (j.person !== undefined) { const p = g.pop.people[j.person]; p.forceSpot = null; g.life.cache.delete(p.id); }
    if (j.car && !j.car.removed) j.car.keep = false;
    this.active = null;
    if (!quiet) { g.ui.toast('Job abandoned. The family noticed.', 'warn'); this.standing[j.family] = (this.standing[j.family] || 0) - 3; }
  };
  J.complete = function (j, extra) {
    const g = this.game, pl = g.player;
    const pay = j.reward + (extra || 0);
    pl.addCash(pay);
    this.addRep(j.rep, j.family);
    this.done++;
    pl.stats.jobs++;
    if (j.person !== undefined) { const p = g.pop.people[j.person]; p.forceSpot = null; p.debt = 0; g.life.cache.delete(p.id); }
    if (j.car && !j.car.removed) { j.car.keep = false; }
    this.active = null;
    g.ui.story('JOB DONE', `${j.title}.\n\n+${R.fmtMoney(pay)}  ·  +${j.rep} respect with the ${j.family}s.`);
    g.audio.sfx('cash');
  };
  J.fail = function (j, why) {
    const g = this.game;
    if (j.person !== undefined) { const p = g.pop.people[j.person]; p.forceSpot = null; g.life.cache.delete(p.id); }
    this.active = null;
    this.standing[j.family] = (this.standing[j.family] || 0) - 5;
    g.ui.story('JOB FAILED', `${j.title}.\n\n${why}`);
  };
  J.progress = function (kind, data) {
    const j = this.active;
    if (!j) return;
    if (kind === 'racket' && j.kind === 'racket') {
      j.count++;
      if (j.count >= j.need) this.complete(j);
      else this.game.ui.toast(`Protection deals: ${j.count}/${j.need}`);
    }
    if (kind === 'robbed' && j.kind === 'rob' && data.id === j.building) this.complete(j);
  };

  // marker for the map / compass
  J.marker = function () {
    const g = this.game, j = this.active;
    if (!j) return null;
    const w = g.world;
    if (j.person !== undefined) {
      const p = g.pop.people[j.person];
      if (p.actor && !p.actor.dead) return { x: p.actor.x, y: p.actor.y, label: g.pop.short(p) };
      const k = g.life.desiredKey(p);
      const pos = g.life.posOf(k);
      if (pos) return { x: pos.x * TS + 8, y: pos.y * TS + 8, label: g.pop.short(p) };
    }
    if (j.kind === 'deliver') {
      if (j.stage === 1 && j.car) return { x: j.car.x, y: j.car.y, label: 'Van' };
      const b = w.buildings[j.dest];
      return { x: b.out.x * TS + 8, y: b.out.y * TS + 8, label: b.name };
    }
    if (j.kind === 'steal') {
      if (j.stage === 1) { const b = w.buildings[j.at]; if (j.car && !j.car.removed) return { x: j.car.x, y: j.car.y, label: 'Target car' }; return { x: b.out.x * TS + 8, y: b.out.y * TS + 8, label: b.name }; }
      const b = w.buildings[j.dest];
      return { x: b.out.x * TS + 8, y: b.out.y * TS + 8, label: b.name };
    }
    if (j.building) { const b = w.buildings[j.building]; return { x: b.out.x * TS + 8, y: b.out.y * TS + 8, label: b.name }; }
    return null;
  };

  J.update = function (dt) {
    const g = this.game, j = this.active, pl = g.player, w = g.world;
    if (!j) return;
    if (j.person !== undefined) {
      const p = g.pop.people[j.person];
      if (j.kind === 'hit' && !p.alive) return this.complete(j);
      if ((j.kind === 'collect' || j.kind === 'scare') && !p.alive) return this.fail(j, 'The target is dead. The dead don\'t pay, and they don\'t learn lessons.');
      if (j.kind === 'collect' && p.debt <= 0) return this.complete(j);
      if (j.kind === 'scare' && p.fear >= 70) return this.complete(j);
      if (j.kind === 'collect' && p.actor && (p.actor.down > 0 || p.actor.state === 'surrender') && !j.beaten) {
        j.beaten = true;
        g.ui.toast('They\'re down. Search them (USE) to take what they owe.');
      }
    }
    if (j.kind === 'deliver') {
      const v = j.car;
      if (!v || v.removed || v.wrecked) return this.fail(j, 'The van is gone. So is the merchandise.');
      if (j.stage === 1 && pl.inCar === v) { j.stage = 2; j.t0 = g.clock.t; g.ui.toast(`Drive to ${w.buildings[j.dest].name}. ${j.minutes} minutes.`, 'warn'); }
      if (j.stage === 2) {
        j.left = j.minutes - (g.clock.t - j.t0);
        const b = w.buildings[j.dest];
        if (pl.inCar === v && R.dist(v.x, v.y, b.out.x * TS, b.out.y * TS) < TS * 5 && Math.abs(v.speed) < 20) {
          if (g.law.active()) { if (!j.warnTail) { j.warnTail = true; g.ui.toast('Lose the cops before you pull in.', 'warn'); } }
          else { const bonus = Math.round(j.reward * (v.hp / v.maxHp - 0.5)); g.player.exitCar(); v.keep = false; v.locked = true; setTimeout(() => g.traffic.remove(v), 3000); return this.complete(j, Math.max(0, bonus)); }
        }
        if (j.left <= 0) return this.fail(j, 'Too slow. The buyer walked.');
      }
    }
    if (j.kind === 'steal') {
      if (j.stage === 1 && !j.car) {
        const b = w.buildings[j.at];
        if (R.dist(pl.x, pl.y, b.out.x * TS, b.out.y * TS) < TS * 30) {
          const v = this.spawnCarNear(b, j.model);
          if (v) { v.locked = true; v.jobCar = j.id; j.car = v; v.owned = 'npc'; }
        }
      }
      if (j.car && pl.inCar === j.car && j.stage === 1) { j.stage = 2; g.ui.toast(`Deliver the ${D.vehicles[j.model].name} to ${w.buildings[j.dest].name}.`); }
      if (j.car && (j.car.removed || j.car.wrecked)) return this.fail(j, 'The car is scrap. The client wanted it pristine.');
      if (j.stage === 2) {
        const b = w.buildings[j.dest];
        if (pl.inCar === j.car && R.dist(j.car.x, j.car.y, b.out.x * TS, b.out.y * TS) < TS * 5 && !g.law.active()) {
          g.player.exitCar();
          const v = j.car;
          setTimeout(() => g.traffic.remove(v), 2500);
          return this.complete(j, Math.round(j.reward * (v.hp / v.maxHp - 0.6)));
        }
      }
    }
    if (j.kind === 'torch') {
      const b = w.buildings[j.building];
      if (b.destroyed || b.burning) return this.complete(j);
    }
  };

  // weekly tribute + racket income accumulate daily
  J.daily = function () {
    const g = this.game;
    for (const b of g.world.buildings) {
      if (!b || !b.racket || b.destroyed) continue;
      b.racketDue = (b.racketDue || 0) + Math.round((20 + b.w * 5) / 7 * (b.city.prosperity / 60 + 0.4));
    }
    if (this.rank() >= 3) {
      const t = 40 * this.rank();
      g.player.addCash(t);
      g.ui.toast(`Family tribute: +${R.fmtMoney(t)}`, 'good');
    }
    // standings drift towards neutral
    for (const f in this.standing) this.standing[f] *= 0.98;
    this.leads = this.leads.filter((l) => g.pop.day - l.day < 2);
  };

  J.roundForHouse = function (h) {
    const g = this.game;
    const b = g.world.buildingAt(((h.x / TS) | 0), ((h.y / TS) | 0) - 1) || g.ui.insideB;
    const c = g.world.cityAt((g.player.x / TS) | 0, (g.player.y / TS) | 0) || (b && b.city);
    if (c && c.id) g.player.standing[c.id] = Math.min(100, (g.player.standing[c.id] || 0) + 4);
    const pats = b ? g.life.occupants(b) : [];
    for (const p of pats) p.opinion = Math.min(100, p.opinion + 6);
    g.player.rep.honor += 1;
    g.player.cool = Math.min(100, g.player.cool + 20);
  };

  // ---------------------------------------------------------------- leads (rumours that mark opportunities)
  J.makeLead = function (h) {
    const g = this.game, w = g.world, pop = g.pop;
    const city = w.cityAt((h.x / TS) | 0, (h.y / TS) | 0) || (h.person && pop.cityObj(h.person.city));
    if (!city || !city.buildings) return null;
    const rnd = R.rng;
    const kind = rnd.weighted([['stash', 2], ['rich', 1.3], ['poker', 1], ['hunt', 0.7], ['racketHint', 0.6]]);
    if (kind === 'stash') {
      const houses = city.buildings.filter((b) => (b.type === 'house' || b.type === 'cabin') && !b.destroyed && b.residents.length);
      if (!houses.length) return null;
      const b = rnd.pick(houses);
      const owner = pop.people[b.residents[0]];
      b.stash = rnd.int(80, 260);
      this.addLead({ kind, x: b.out.x, y: b.out.y, text: `Stash at ${owner ? owner.last : 'a'} house`, b: b.id });
      return `Word is old ${owner ? owner.first + ' ' + owner.last : 'somebody'} keeps a coffee can full of cash at home. Doesn't trust banks. Marked it on your map.`;
    }
    if (kind === 'rich') {
      const rich = (pop.byCity[city.id] || []).filter((p) => p.alive && p.age > 30 && (p.role === 'teller' || p.role === 'doctor' || p.role === 'dealer' || p.wealth > 60));
      if (!rich.length) return null;
      const p = rnd.pick(rich);
      p.wealth += 200;
      p.fat = true;
      return `${pop.name(p)}, the ${pop.title(p).toLowerCase()}, just cashed a fat check. Walks around with it too. Dumb.`;
    }
    if (kind === 'poker') {
      const bars = city.buildings.filter((b) => b.type === 'bar' || b.type === 'social' || b.type === 'casino');
      if (!bars.length) return null;
      const b = rnd.pick(bars);
      b.poker = pop.day;
      this.addLead({ kind, x: b.out.x, y: b.out.y, text: `Card game at ${b.name}`, b: b.id });
      return `High-stakes cards in the back of ${b.name} tonight. Bring money you don't mind losing.`;
    }
    if (kind === 'hunt') {
      return rnd.pick(['A monster bear\'s been seen up past Pinecrest. Pelt\'s worth a fortune.', 'Gators the size of a Cadillac out in the bayou. The butcher pays good for hides.', 'Wolves are running the ridge again. Farmers will pay to be rid of them.']);
    }
    const shops = city.buildings.filter((b) => ['general', 'diner', 'laundry', 'barber', 'tailor'].includes(b.type) && !b.racket);
    if (!shops.length) return null;
    const b = rnd.pick(shops);
    return `${b.name} doesn't pay anybody for protection. Yet.`;
  };
  J.addLead = function (l) {
    l.day = this.game.pop.day;
    this.leads = this.leads.filter((q) => q.b !== l.b);
    this.leads.push(l);
    this.game.ui.toast('New lead marked on your map.', 'good');
  };

  J.openBoard = function (h) {
    const g = this.game;
    const fam = h.faction || this.cityFamily(h) || g.player.family;
    g.ui.openBoard(fam, this.offersFor(fam), h);
  };

  J.serialize = function () {
    return { standing: this.standing, rep: this.rep, done: this.done };
  };
  J.restore = function (s) {
    Object.assign(this.standing, s.standing || {});
    this.rep = s.rep || 0;
    this.done = s.done || 0;
  };
})();
