// RHAPSODY — the living population: ~1,000 named people with homes, jobs, families,
// schedules, memories and opinions. Aging, marriage, births, deaths and city growth
// tick once per in-game day.
'use strict';
(function () {
  const D = R.data;

  const SKIN = ['#f1c9a5', '#e0ac7e', '#c68a5a', '#a0663c', '#7a4a2a', '#5a3620', '#f5d6b8'];
  const HAIR = ['#1a1210', '#3a2418', '#5a3a1e', '#8a5a2a', '#c89a50', '#d8c090', '#6a2a1a', '#9a9a9a', '#e0e0e0'];
  const TOPS = ['#8a4a1e', '#c8781e', '#e4a92a', '#7a8a2e', '#2a7d7a', '#5c2a4a', '#a8401c', '#e8dcc0', '#3a5a8a', '#6a4a3a', '#b05a6a', '#4a6a5a', '#d8b890', '#2a2a2a'];
  const BOTTOMS = ['#3a5a8a', '#2a3a5a', '#4a3a2a', '#6a5a3a', '#2a2a2a', '#8a7a5a', '#5a3a4a', '#a88a5a'];

  const Pop = (R.Population = function (world, seed) {
    this.world = world;
    this.seed = seed;
    this.people = [];
    this.byCity = {};
    this.projects = []; // construction
    this.news = []; // {day, city, text}
    this.day = 0;
    this.generate();
  });
  const P = Pop.prototype;

  P.makeLook = function (rnd, p) {
    const fem = p.fem;
    const look = {
      skin: rnd.pick(SKIN), hair: rnd.pick(p.age > 60 ? HAIR.slice(7) : HAIR.slice(0, 7)),
      hairStyle: rnd.chance(0.15) ? 2 : fem ? 1 : rnd.chance(0.25) ? 1 : 0,
      top: rnd.pick(TOPS), bottom: rnd.pick(BOTTOMS), fem, kid: p.age < 14,
      build: rnd.chance(0.25) ? 2 : rnd.chance(0.3) ? 0 : 1, beard: !fem && p.age > 17 && rnd.chance(0.35),
      shades: rnd.chance(0.12), dress: fem && rnd.chance(0.5), hat: null, hatCol: null, stripe: null, lapel: null,
    };
    const role = p.role;
    if (role === 'cop' || role === 'detective') {
      look.top = role === 'cop' ? '#2a3a6a' : '#6a5a4a';
      look.bottom = '#1a2a4a';
      look.hat = role === 'cop' ? 'police' : 'fedora';
      look.hatCol = '#4a3a2a';
      look.dress = false;
    } else if (role === 'capo' || role === 'soldier' || role === 'don') {
      look.top = rnd.pick(['#2a2a30', '#3a2a24', '#2a3040', '#4a2a2a']);
      look.bottom = look.top;
      look.stripe = 'rgba(255,255,255,0.18)';
      look.lapel = '#e8d8b8';
      look.hat = 'fedora';
      look.hatCol = '#1a1614';
      look.chain = true;
      look.dress = false;
      look.build = role === 'soldier' ? 2 : look.build;
    } else if (role === 'farmer' || role === 'hunter') {
      look.hat = rnd.chance(0.6) ? 'cowboy' : 'cap';
      look.hatCol = rnd.pick(['#8a6a3a', '#5a3a1a', '#c8a060']);
      look.bottom = '#3a5a8a';
    } else if (role === 'dockhand' || role === 'fisher' || role === 'worker') {
      look.hat = rnd.chance(0.5) ? 'beanie' : 'cap';
      look.hatCol = rnd.pick(['#6a2a1a', '#2a4a6a', '#4a4a4a']);
    } else if (role === 'nurse' || role === 'doctor') {
      look.top = '#e8e8e0';
    } else if (role === 'priest') {
      look.top = '#1a1a1a';
      look.bottom = '#1a1a1a';
      look.lapel = '#f0f0f0';
    } else if (p.city === 'dust' && rnd.chance(0.4)) {
      look.hat = 'cowboy';
      look.hatCol = rnd.pick(['#c8a060', '#8a6a3a', '#e8dcc0']);
    } else if (rnd.chance(0.08)) {
      look.hat = rnd.pick(['cap', 'fedora', 'beanie']);
      look.hatCol = rnd.pick(HAIR);
    }
    return look;
  };

  P.newPerson = function (rnd, city, opts) {
    const fem = opts.fem !== undefined ? opts.fem : rnd.chance(0.5);
    const lasts = D.lastAll[city] || D.lastAll.avalon;
    const p = {
      id: this.people.length,
      first: rnd.pick(fem ? D.firstF : D.firstM),
      last: opts.last || rnd.pick(lasts),
      nick: null,
      fem, age: opts.age, city, home: opts.home || 0, work: 0, role: 'none',
      arch: opts.arch || rnd.weighted([['friendly', 3], ['grumpy', 2], ['timid', 2], ['tough', 1.5], ['gossip', 1.5], ['square', 2], ['hustler', 1.2], ['flirt', 1], ['eccentric', 0.8], ['pious', 1]]),
      opinion: 0, fear: 0, fam: 0, met: false, alive: true,
      spouse: -1, parents: opts.parents || [], kids: [], wealth: rnd.int(5, 80), mem: [],
      place: null, lastGreet: -1, faction: null, seed: rnd.int(0, 1e9), look: null, debt: 0, grudge: 0,
    };
    const a = D.archetypes[p.arch];
    p.tr = {
      brave: R.clamp(a.brave + (rnd() - 0.5) * 0.3, 0, 1), warm: R.clamp(a.warm + (rnd() - 0.5) * 0.3, 0, 1),
      lawful: R.clamp(a.lawful + (rnd() - 0.5) * 0.3, 0, 1), chatty: R.clamp(a.chatty + (rnd() - 0.5) * 0.3, 0, 1),
      greed: R.clamp(a.greed + (rnd() - 0.5) * 0.3, 0, 1),
    };
    if (p.age < 14) p.role = 'kid';
    else if (p.age < 18) p.role = 'student';
    this.people.push(p);
    (this.byCity[city] = this.byCity[city] || []).push(p);
    return p;
  };
  P.name = function (p) {
    return p.nick ? `${p.first} "${p.nick}" ${p.last}` : `${p.first} ${p.last}`;
  };
  P.short = function (p) {
    return p.nick ? `"${p.nick}"` : p.first;
  };
  P.title = function (p) {
    return D.roleNames[p.role] || 'Local';
  };

  P.generate = function () {
    const rnd = R.mulberry(this.seed + 404);
    const w = this.world;
    const cityDefs = D.cities.map((d, i) => ({ id: d.id, c: w.cities[i], target: d.pop }));
    cityDefs.push({ id: 'county', c: w.countyCity(), target: 60, rural: true });
    // hamlet buildings are part of the county
    for (const h of w.hamlets) for (const b of h.buildings) { b.city = w.countyCity(); b.cityId = 'county'; w.countyCity().buildings.push(b); }
    for (const b of w.buildings) if (b && b.rural) b.cityId = 'county';

    for (const cd of cityDefs) {
      const homes = cd.c.buildings.filter((b) => D.btypes[b.type].house && b.type !== 'hotel');
      rnd.shuffle(homes);
      let pop = 0, hi = 0;
      while (pop < cd.target && hi < homes.length * 3) {
        const home = homes[hi % homes.length];
        hi++;
        const cap = D.btypes[home.type].house;
        if (home.residents.length >= cap) continue;
        // household
        const last = rnd.pick(D.lastAll[cd.id] || D.lastAll.avalon);
        const a1 = this.newPerson(rnd, cd.id, { age: rnd.int(19, 78), last, home: home.id });
        home.residents.push(a1.id);
        pop++;
        if (a1.age < 70 && rnd.chance(0.55) && home.residents.length < cap) {
          const a2 = this.newPerson(rnd, cd.id, { age: R.clamp(a1.age + rnd.int(-6, 6), 19, 80), last, home: home.id, fem: !a1.fem });
          a1.spouse = a2.id; a2.spouse = a1.id;
          home.residents.push(a2.id);
          pop++;
          const mom = a1.fem ? a1 : a2;
          const nk = mom.age < 50 ? rnd.weighted([[0, 2], [1, 3], [2, 3], [3, 1.5]]) : rnd.chance(0.3) ? 1 : 0;
          for (let k = 0; k < nk && home.residents.length < cap; k++) {
            const maxAge = Math.max(0, Math.min(mom.age - 18, 17));
            const kid = this.newPerson(rnd, cd.id, { age: rnd.int(0, maxAge), last, home: home.id, parents: [a1.id, a2.id] });
            a1.kids.push(kid.id); a2.kids.push(kid.id);
            home.residents.push(kid.id);
            pop++;
          }
        }
      }
      // jobs
      const adults = this.byCity[cd.id].filter((p) => p.age >= 18 && p.age < 67);
      rnd.shuffle(adults);
      let ai = 0;
      const jobsList = [];
      for (const b of cd.c.buildings) {
        const jobs = D.btypes[b.type].jobs;
        if (jobs) for (const role in jobs) for (let k = 0; k < jobs[role]; k++) jobsList.push([b, role]);
      }
      rnd.shuffle(jobsList);
      // prioritise essential roles
      const prio = { cop: 0, capo: 0, bartender: 1, fence: 1, clerk: 2 };
      jobsList.sort((a, b) => (prio[a[1]] ?? 3) - (prio[b[1]] ?? 3));
      for (const [b, role] of jobsList) {
        if (ai >= adults.length) break;
        const p = adults[ai++];
        this.assignJob(p, b, role, rnd);
      }
      for (const p of this.byCity[cd.id]) {
        if (p.role !== 'none') continue;
        if (p.age >= 67) p.role = 'retired';
        else if (cd.rural) p.role = rnd.pick(['farmer', 'hunter', 'hunter', 'drifter']);
        else p.role = rnd.weighted([['none', 4], ['hustler', 2], ['musician', 0.6], ['artist', 0.5], ['preacher', 0.3], ['drifter', 0.8], [cd.id === 'port' || cd.id === 'bayou' ? 'fisher' : 'none', 1.5]]);
      }
      // The Don
      if (!cd.rural) {
        const club = cd.c.buildings.find((b) => b.type === 'social');
        const def = D.cities.find((d) => d.id === cd.id);
        const [first, ...rest] = def.don.replace(/".*?"\s/, '').split(' ');
        const don = this.newPerson(rnd, cd.id, { age: rnd.int(52, 71), last: rest.join(' '), fem: /Mama|Soledad/.test(def.don), arch: 'tough' });
        don.first = first;
        const m = def.don.match(/"(.*?)"/);
        if (m) don.nick = m[1];
        don.role = 'don';
        don.work = club ? club.id : 0;
        don.faction = def.family;
        don.home = club ? club.id : 0;
        don.wealth = 5000;
        don.tr.brave = 1;
        don.isDon = true;
        if (club) club.owner = don.id;
        cd.c.don = don.id;
      }
    }
    // look + nicknames + businesses owners
    for (const p of this.people) {
      if (!p.look) p.look = this.makeLook(R.mulberry(p.seed), p);
      if ((p.role === 'soldier' || p.role === 'capo' || p.role === 'hustler') && rnd.chance(0.55)) p.nick = rnd.pick(D.nick);
      if (p.role === 'cop' || p.role === 'detective') p.faction = 'law';
    }
    for (const b of w.buildings) {
      if (!b || b.owner !== null) continue;
      if (b.workers.length) b.owner = b.workers[0];
      else if (b.residents.length) b.owner = b.residents[0];
    }
    this.count0 = this.people.length;
  };

  P.assignJob = function (p, b, role, rnd) {
    p.work = b.id;
    p.role = role;
    b.workers.push(p.id);
    if (role === 'capo' || role === 'soldier') {
      const def = D.cities.find((d) => d.id === p.city);
      p.faction = def ? def.family : null;
      p.arch = rnd.chance(0.6) ? 'tough' : 'hustler';
      p.tr.brave = Math.max(p.tr.brave, 0.7);
      p.tr.lawful = Math.min(p.tr.lawful, 0.2);
    }
    if (role === 'cop' || role === 'detective') {
      p.faction = 'law';
      p.tr.lawful = Math.max(p.tr.lawful, 0.8);
      p.tr.brave = Math.max(p.tr.brave, 0.6);
    }
    if (role === 'bouncer' || role === 'guard') p.tr.brave = Math.max(p.tr.brave, 0.75);
    p.look = null;
  };

  P.get = function (id) { return this.people[id]; };
  P.building = function (id) { return id ? this.world.buildings[id] : null; };

  // -------------------------------------------------- schedules
  // Returns desired place for hour h (float), on day d.
  P.desired = function (p, h, day) {
    const w = this.world;
    const hr = R.hash2(p.id, day, 71);
    const home = p.home;
    if (!p.alive) return null;
    if (p.jailed && p.jailed > day) return { b: 0, gone: true };
    if (p.forceSpot && h >= 7 && h < 23) return { spot: p.forceSpot };
    if (p.isDon && p.work) return { b: p.work }; // the Don holds court at his club
    if (p.role === 'kid' || p.role === 'student') {
      if (p.age >= 6 && h >= 8 && h < 15) {
        const school = this.cityBuilding(p.city, 'school');
        if (school) return { b: school.id };
      }
      if (p.age >= 7 && h >= 15 && h < 19 && hr < 0.6) return { spot: this.spotFor(p, day, 'park') };
      return { b: home };
    }
    const work = p.work ? w.buildings[p.work] : null;
    if (work && !work.destroyed) {
      const bt = D.btypes[work.type];
      let [o, c] = bt.hours || [9, 17];
      if (c <= o) c += 24;
      let len = c - o;
      let start = o, end = c;
      if (len > 10) {
        // shift work: split by id
        const shifts = Math.ceil(len / 9);
        const s = p.id % shifts;
        start = o + s * (len / shifts);
        end = start + len / shifts;
      }
      const off = R.hash2(p.id, 3, 3) < 0.15 && day % 7 === p.id % 7; // day off
      let hh = h;
      if (hh < start && end > 24 && hh + 24 < end) hh += 24;
      if (!off && hh >= start && hh < end) return { b: work.id };
    }
    // nightlife / leisure
    const night = h >= 22 || h < 6;
    const owl = p.role === 'hustler' || p.role === 'drifter' || p.role === 'musician' || p.arch === 'flirt';
    if ((h >= 23 || h < 6) && !(owl && h < 3)) return { b: home };
    if (h < 7) return { b: home };
    // outdoor jobs
    if (['musician', 'preacher', 'hustler', 'artist', 'fisher', 'drifter'].includes(p.role) && h >= 10 && h < 21) {
      return { spot: this.spotFor(p, day, p.role === 'fisher' ? 'pier' : null) };
    }
    if (p.role === 'hunter' || p.role === 'farmer') return h < 20 ? { spot: this.spotFor(p, day, 'porch') } : { b: home };
    const leisureChance = 0.2 + p.tr.chatty * 0.35;
    if (hr < leisureChance && h >= 17) {
      const lb = this.leisureFor(p, day, night);
      if (lb) return { b: lb.id };
    }
    if (hr > 0.75 && h >= 9 && h < 20) return { spot: this.spotFor(p, day, null) };
    return { b: home };
  };
  P.cityBuilding = function (cityId, type) {
    const c = this.cityObj(cityId);
    return c ? c.buildings.find((b) => b.type === type && !b.destroyed) : null;
  };
  P.cityObj = function (id) {
    if (id === 'county') return this.world.countyCity();
    return this.world.cities.find((c) => c.id === id);
  };
  P.leisureFor = function (p, day, night) {
    const c = this.cityObj(p.city);
    if (!c) return null;
    if (!c._leisure) c._leisure = c.buildings.filter((b) => D.btypes[b.type].leisure);
    const opts = c._leisure.filter((b) => !b.destroyed && (p.age >= 21 || (b.type !== 'bar' && b.type !== 'club')) && (b.type !== 'church' || p.arch === 'pious' || day % 7 === 6));
    if (!opts.length) return null;
    return opts[Math.floor(R.hash2(p.id, day, 5) * opts.length)];
  };
  P.spotFor = function (p, day, kind) {
    const c = this.cityObj(p.city);
    if (!c) return null;
    if (!c._spots) c._spots = this.world.spots.filter((s) => s.city === c);
    let opts = kind ? c._spots.filter((s) => s.kind === kind) : c._spots;
    if (!opts.length) opts = c._spots;
    if (!opts.length) return null;
    return opts[Math.floor(R.hash2(p.id, day, 9) * opts.length)];
  };

  // -------------------------------------------------- memories & opinions
  P.remember = function (p, kind, text, day) {
    p.mem.unshift({ kind, text, day });
    if (p.mem.length > 6) p.mem.length = 6;
  };
  P.addNews = function (city, text) {
    this.news.unshift({ day: this.day, city, text });
    if (this.news.length > 40) this.news.length = 40;
  };
  P.family = function (p) {
    const out = [];
    if (p.spouse >= 0) out.push(['spouse', this.people[p.spouse]]);
    for (const k of p.kids) out.push(['kid', this.people[k]]);
    for (const k of p.parents) out.push(['parent', this.people[k]]);
    return out.filter((x) => x[1]);
  };
  // A fact the person can mention when chatting (life-sim flavor)
  P.lifeFact = function (p) {
    const rnd = R.mulberry(p.seed + this.day);
    const facts = [];
    const fam = this.family(p);
    for (const [rel, q] of fam) {
      if (!q.alive) facts.push(`I still miss ${q.first}. Not a day goes by.`);
      else if (rel === 'kid' && q.age < 1) facts.push(`We just had a baby. ${q.first}. Hardly slept since.`);
      else if (rel === 'kid' && q.age < 13) facts.push(`My ${q.fem ? 'girl' : 'boy'} ${q.first} turned ${q.age}. Growing like a weed.`);
      else if (rel === 'kid' && q.age < 18) facts.push(`${q.first} is ${q.age} and already thinks ${q.fem ? 'she' : 'he'} knows everything.`);
      else if (rel === 'kid') facts.push(`${q.first} works as a ${D.roleNames[q.role] || 'something'} now. Proud of ${q.fem ? 'her' : 'him'}.`);
      else if (rel === 'spouse') facts.push(`${q.first} and me, ${Math.max(1, Math.min(p.age, q.age) - 20)} years married. Still dance on Fridays.`);
    }
    const work = p.work ? this.world.buildings[p.work] : null;
    if (work) facts.push(`I work over at ${work.name}. ${rnd.pick(['It pays the bills.', 'Boss is a creep.', "Can't complain.", 'Best job I ever had. Only job, too.'])}`);
    for (const m of p.mem.slice(0, 2)) if (m.text) facts.push(m.text);
    const news = this.news.find((n) => n.city === p.city && this.day - n.day < 3);
    if (news) facts.push(`You hear? ${news.text}`);
    return facts.length ? rnd.pick(facts) : 'Nothing new under the sun.';
  };

  // -------------------------------------------------- daily life sim
  P.dailyTick = function (game) {
    this.day++;
    const rnd = R.mulberry(this.seed + this.day * 977);
    const yrs = game.settings.lifeSpeed; // years per day
    const births = [], deaths = [];
    const aging = yrs >= 1 ? Math.round(yrs) : R.hash2(this.day, 1, 1) < yrs ? 1 : 0;
    for (const p of this.people) {
      if (!p.alive) continue;
      if (p.jailed && p.jailed <= this.day) p.jailed = 0;
      if (aging) {
        const was = p.age;
        p.age += aging;
        if (was < 14 && p.age >= 14) { p.look.kid = false; p.role = 'student'; }
        if (was < 18 && p.age >= 18) this.comeOfAge(p, rnd);
        if (p.age > 72 && rnd.chance((p.age - 70) * 0.012 * aging) && !p.isDon) deaths.push(p);
      }
      // mood drift towards neutral
      p.fear *= 0.8;
      p.grudge = Math.max(0, p.grudge - 3);
    }
    const byD = {};
    for (const p of deaths) {
      this.kill(p, 'old age');
      (byD[p.city] = byD[p.city] || []).push(p);
    }
    for (const c in byD) {
      const ds = byD[c];
      this.addNews(c, ds.length === 1 ? `${this.name(ds[0])} passed peacefully at ${ds[0].age}.` : `Services held for ${this.name(ds[0])} (${ds[0].age}) and ${ds.length - 1} other${ds.length > 2 ? 's' : ''}.`);
    }
    if (aging) {
      // marriages
      for (const cityId in this.byCity) {
        const singles = this.byCity[cityId].filter((p) => p.alive && p.spouse < 0 && p.age >= 20 && p.age <= 55 && !p.isDon && !p.playerPartner);
        rnd.shuffle(singles);
        for (let i = 0; i < singles.length; i++) {
          const a = singles[i];
          if (a.spouse >= 0 || !rnd.chance(0.06 * aging)) continue;
          const b = singles.find((q) => q.spouse < 0 && q !== a && q.fem !== a.fem && Math.abs(q.age - a.age) < 9);
          if (!b) continue;
          a.spouse = b.id; b.spouse = a.id;
          const wife = a.fem ? a : b, hub = a.fem ? b : a;
          if (rnd.chance(0.7)) wife.last = hub.last;
          this.moveIn(b, a.home);
          this.addNews(cityId, `Wedding bells: ${a.first} ${a.last} married ${b.first}.`);
          this.remember(a, 'life', `I got married to ${b.first}. Can you believe it?`, this.day);
          this.remember(b, 'life', `Married ${a.first}. Best day of my life.`, this.day);
        }
        // births
        for (const p of this.byCity[cityId]) {
          if (!p.alive || !p.fem || p.spouse < 0 || p.age < 20 || p.age > 42) continue;
          const dad = this.people[p.spouse];
          if (!dad || !dad.alive) continue;
          const nk = p.kids.length;
          if (!rnd.chance((nk < 3 ? 0.14 : 0.03) * aging)) continue;
          const home = this.world.buildings[p.home];
          if (home && home.residents.length >= D.btypes[home.type].house + 4) continue;
          const kid = this.newPerson(rnd, cityId, { age: 0, last: dad.last, home: p.home, parents: [p.id, dad.id] });
          kid.look = this.makeLook(R.mulberry(kid.seed), kid);
          kid.look.skin = rnd.chance(0.5) ? p.look.skin : dad.look.skin;
          kid.look.hair = rnd.chance(0.5) ? p.look.hair : dad.look.hair;
          p.kids.push(kid.id); dad.kids.push(kid.id);
          if (home) home.residents.push(kid.id);
          births.push(kid);
          this.remember(p, 'life', `We just had a ${kid.fem ? 'baby girl' : 'baby boy'}. ${kid.first}.`, this.day);
        }
      }
    }
    // one birth announcement line per town
    const byC = {};
    for (const k of births) (byC[k.city] = byC[k.city] || []).push(k);
    for (const c in byC) {
      const ks = byC[c];
      const names = ks.slice(0, 2).map((k) => `${k.first} ${k.last}`);
      this.addNews(c, ks.length === 1 ? `It's a ${ks[0].fem ? 'girl' : 'boy'}! Welcome ${names[0]}.` : `${ks.length} babies born, including ${names.join(' and ')}.`);
    }
    if (aging) this.migrate(rnd);
    this.fillJobs(rnd);
    this.growCities(game, rnd);
    return { births, deaths };
  };

  // Towns hold their size over the decades: families move in when a town thins out
  // and young folks leave for the big city when it gets crowded.
  P.migrate = function (rnd) {
    const w = this.world;
    const targets = {};
    for (const d of D.cities) targets[d.id] = d.pop;
    targets.county = 60;
    for (const cityId in targets) {
      const c = this.cityObj(cityId);
      if (!c) continue;
      const alive = (this.byCity[cityId] || []).filter((p) => p.alive);
      const n = alive.length, target = targets[cityId];
      if (n < target * 0.94) {
        const want = Math.min(4, Math.ceil((target * 0.94 - n) / 6));
        const free = c.buildings.filter((b) => b && !b.destroyed && D.btypes[b.type].house && b.type !== 'hotel' && b.residents.length + 2 <= D.btypes[b.type].house);
        rnd.shuffle(free);
        for (let k = 0; k < want && k < free.length; k++) {
          const home = free[k];
          const last = rnd.pick(D.lastAll[cityId] || D.lastAll.avalon);
          const a1 = this.newPerson(rnd, cityId, { age: rnd.int(22, 38), last, home: home.id });
          a1.look = this.makeLook(R.mulberry(a1.seed), a1);
          home.residents.push(a1.id);
          if (rnd.chance(0.75)) {
            const a2 = this.newPerson(rnd, cityId, { age: R.clamp(a1.age + rnd.int(-4, 4), 20, 45), last, home: home.id, fem: !a1.fem });
            a2.look = this.makeLook(R.mulberry(a2.seed), a2);
            a1.spouse = a2.id; a2.spouse = a1.id;
            home.residents.push(a2.id);
            const nk = rnd.weighted([[0, 3], [1, 3], [2, 2]]);
            for (let j = 0; j < nk && home.residents.length < D.btypes[home.type].house; j++) {
              const kid = this.newPerson(rnd, cityId, { age: rnd.int(0, 12), last, home: home.id, parents: [a1.id, a2.id] });
              kid.look = this.makeLook(R.mulberry(kid.seed), kid);
              a1.kids.push(kid.id); a2.kids.push(kid.id);
              home.residents.push(kid.id);
            }
          }
          if (k === 0) this.addNews(cityId, `New in town: the ${last} family moved into ${home.name === 'House' ? 'a house' : home.name} in ${c.name}.`);
        }
      } else if (n > target * 1.18) {
        const leavers = alive.filter((p) => p.age >= 18 && p.age <= 32 && p.spouse < 0 && !p.isDon && !p.faction && !p.actor && p.role !== 'cop');
        rnd.shuffle(leavers);
        const go = leavers.slice(0, Math.min(3, Math.ceil((n - target * 1.18) / 8)));
        for (const p of go) this.leave(p);
        if (go.length) this.addNews(cityId, `${this.name(go[0])} packed a suitcase and left ${c.name} for the big city.`);
      }
    }
  };
  P.leave = function (p) {
    p.alive = false;
    p.gone = true;
    p.diedDay = this.day;
    const h = this.world.buildings[p.home];
    if (h) h.residents = h.residents.filter((id) => id !== p.id);
    const wb = this.world.buildings[p.work];
    if (wb && wb.workers) wb.workers = wb.workers.filter((id) => id !== p.id);
    p.role = 'gone';
  };
  P.comeOfAge = function (p, rnd) {
    p.role = 'none';
    p.look = this.makeLook(R.mulberry(p.seed + 1), p);
    // try to move out
    const c = this.cityObj(p.city);
    if (!c) return;
    const free = c.buildings.find((b) => D.btypes[b.type].house && !b.destroyed && b.residents.length < D.btypes[b.type].house && b.type !== 'hotel');
    if (free && rnd.chance(0.8)) this.moveIn(p, free.id);
    this.remember(p, 'life', `I'm ${p.age} now. Out of school, looking for work.`, this.day);
  };
  P.moveIn = function (p, bid) {
    const old = this.world.buildings[p.home];
    if (old) old.residents = old.residents.filter((id) => id !== p.id);
    p.home = bid;
    const nb = this.world.buildings[bid];
    if (nb && !nb.residents.includes(p.id)) nb.residents.push(p.id);
  };
  P.fillJobs = function (rnd) {
    for (const c of this.world.cities.concat([this.world.countyCity()])) {
      const pool = (this.byCity[c.id] || []).filter((p) => p.alive && p.age >= 18 && p.age < 67 && (p.role === 'none' || p.role === 'drifter'));
      if (!pool.length) continue;
      for (const b of c.buildings) {
        if (b.destroyed) continue;
        const jobs = D.btypes[b.type].jobs;
        if (!jobs) continue;
        for (const role in jobs) {
          const have = b.workers.filter((id) => this.people[id].alive && this.people[id].role === role && this.people[id].work === b.id).length;
          for (let k = have; k < jobs[role] && pool.length; k++) {
            const p = pool.pop();
            this.assignJob(p, b, role, rnd);
            p.look = this.makeLook(R.mulberry(p.seed + 2), p);
            this.remember(p, 'life', `Started as a ${D.roleNames[role]} at ${b.name}.`, this.day);
          }
        }
      }
    }
  };
  P.kill = function (p, cause) {
    if (!p.alive) return;
    p.alive = false;
    p.deathCause = cause;
    p.diedDay = this.day;
    const b = this.world.buildings[p.work];
    if (b) b.workers = b.workers.filter((id) => id !== p.id);
    const h = this.world.buildings[p.home];
    if (h) h.residents = h.residents.filter((id) => id !== p.id);
    for (const [rel, q] of this.family(p)) {
      if (!q.alive) continue;
      this.remember(q, 'grief', cause === 'player' ? `Somebody killed my ${rel === 'spouse' ? (p.fem ? 'wife' : 'husband') : rel === 'kid' ? (p.fem ? 'daughter' : 'son') : p.fem ? 'mother' : 'father'} ${p.first}. I will find out who.` : `We buried ${p.first} this week.`, this.day);
      if (cause === 'player') q.grudge = 100;
    }
    if (p.spouse >= 0) {
      const s = this.people[p.spouse];
      if (s) s.spouse = -1;
    }
  };

  // Construction: cities with pressure build on vacant lots.
  P.growCities = function (game, rnd) {
    const w = this.world;
    // finish projects
    for (const pr of this.projects.slice()) {
      if (this.day < pr.done) continue;
      this.projects.splice(this.projects.indexOf(pr), 1);
      w.setSite(pr.lot, false);
      const b = w.buildOnLot(pr.lot, pr.type, rnd);
      if (b) {
        b.cityId = pr.lot.city.id;
        b.new = true;
        this.addNews(b.city.id, `Ribbon cut on the new ${D.btypes[b.type].name.toLowerCase()}: ${b.name}.`);
        if (b.city._leisure) b.city._leisure = null;
        R.bus.emit('building:new', b);
      }
    }
    for (const c of w.cities) {
      const pop = (this.byCity[c.id] || []).filter((p) => p.alive).length;
      let housing = 0;
      for (const b of c.buildings) if (!b.destroyed && D.btypes[b.type].house) housing += D.btypes[b.type].house;
      const pressure = pop / Math.max(1, housing);
      c.prosperity = R.clamp(c.prosperity + (c.prosperity < 60 ? 1.5 : 0.4) - c.heat * 0.05, 0, 100);
      c.heat *= 0.7;
      const active = this.projects.filter((p) => p.lot.city === c).length;
      const lots = c.lots.filter((l) => !l.used && !l.site);
      if (!lots.length || active >= 2 + (c.prosperity > 70 ? 1 : 0)) continue;
      const chance = 0.25 + c.prosperity / 200 + (pressure > 0.75 ? 0.3 : 0);
      if (!rnd.chance(chance * Math.max(0.5, game.settings.lifeSpeed))) continue;
      const lot = rnd.pick(lots);
      // choose what to build
      let type;
      const have = (t) => c.buildings.some((b) => b.type === t && !b.destroyed);
      const missing = D.cityRequired.find((t) => !have(t) && D.btypes[t].w[0] <= lot.w);
      if (missing) type = missing;
      else if (pressure > 0.7) type = lot.w >= 6 && rnd.chance(0.5) ? 'apartment' : 'house';
      else type = rnd.weighted(D.cityMix.mid.filter(([t]) => D.btypes[t].w[0] <= lot.w));
      if (!type || D.btypes[type].w[0] > lot.w) type = 'house';
      lot.site = true;
      w.setSite(lot, true);
      this.projects.push({ lot, type, start: this.day, done: this.day + rnd.int(1, 3) });
      this.addNews(c.id, `Ground broken on a new ${D.btypes[type].name.toLowerCase()} in ${c.name}.`);
    }
  };

  // -------------------------------------------------- persistence
  P.serialize = function () {
    return {
      day: this.day,
      people: this.people.map((p) => [p.age, p.alive ? 1 : 0, p.opinion | 0, p.fear | 0, p.fam, p.met ? 1 : 0, p.spouse, p.kids, p.home, p.work, p.role, p.last, p.mem, p.grudge | 0, p.debt | 0, p.nick, p.jailed | 0, p.first, p.fem ? 1 : 0, p.parents, p.city, p.seed, p.arch]),
      projects: this.projects.map((p) => ({ i: this.world.lots.indexOf(p.lot), type: p.type, done: p.done, start: p.start })),
      news: this.news.slice(0, 20),
    };
  };
  P.restore = function (s, game) {
    this.day = s.day;
    this.news = s.news || [];
    const rnd = R.mulberry(this.seed + 5);
    // reset building rosters
    for (const b of this.world.buildings) if (b) { b.residents = []; b.workers = []; }
    s.people.forEach((a, i) => {
      let p = this.people[i];
      if (!p) p = this.newPerson(rnd, a[20], { age: a[0] });
      [p.age, p.alive, p.opinion, p.fear, p.fam, p.met, p.spouse, p.kids, p.home, p.work, p.role, p.last, p.mem, p.grudge, p.debt, p.nick, p.jailed, p.first, p.fem, p.parents, p.city, p.seed, p.arch] = a;
      p.alive = !!p.alive; p.met = !!p.met; p.fem = !!p.fem;
      const a2 = D.archetypes[p.arch];
      p.look = this.makeLook(R.mulberry(p.seed), p);
      if (p.alive) {
        const h = this.world.buildings[p.home];
        if (h) h.residents.push(p.id);
        const wk = this.world.buildings[p.work];
        if (wk) wk.workers.push(p.id);
      }
    });
    this.byCity = {};
    for (const p of this.people) (this.byCity[p.city] = this.byCity[p.city] || []).push(p);
  };
})();
