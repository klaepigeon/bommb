// RHAPSODY — debug, part two: shortcuts into every system added since the first debug
// menu. Each button sets up the situation so it can be tried in seconds.
(function () {
  const D = R.data, TS = R.TILE;
  const base = R.debugTab;
  R.debugTab = function (body, g) {
    base.call(this, body, g);
    const pl = g.player, w = g.world, ui = g.ui;
    const btn = (id, label) => `<button class="dbg" data-x="${id}">${label}</button>`;
    const sect = (title, items) => `<div class="sect">${title}</div><div class="dbgrow">${items.join('')}</div>`;
    const PL = R.salvage ? R.salvage.PLACES.filter((p) => p.at) : [];
    const html = [
      sect('Arsenal+', [btn('guns', 'All new weapons + ammo'), btn('sil', 'Silence every gun'), btn('masks', 'All masks'), btn('wardrobe', 'Tailor here'), btn('barber', 'Barber here')]),
      sect('Money', [btn('dirty', '+$2,000 dirty'), btn('wash', 'Launder it all'), btn('susp', 'Treasury suspicion 90'), btn('audit', 'Audit now'), btn('cleanm', 'Clear suspicion')]),
      sect('Detectives', [btn('case', 'Open a murder case'), btn('case70', 'Case to 70%'), btn('warrant', 'Warrant now'), btn('det', 'Detective visit'), btn('wipe', 'Close all cases')]),
      sect('Serial killer', [btn('sk', 'Form a task force'), btn('skheat', 'Heat 90 (decoys, frisks)'), btn('frisk', 'Stop-and-frisk now'), btn('poi', 'Name me (death row)'), btn('skclear', 'Disband it')]),
      sect('Families', [btn('war', 'Start a war here'), btn('squad', 'Hit squad now'), btn('racket', 'Rival takes a racket'), btn('rule', 'Rule this city'), btn('revolt', 'Loyalist revolt')]),
      sect('Grudges', [btn('avenger', 'An avenger finds me'), btn('letter', 'Blackmail letter'), btn('hired', 'Hired guns')]),
      sect('Gore & bodies', [btn('corpse', 'Corpse + knife'), btn('corpses', 'Five corpses'), btn('bag', 'Bag of remains'), btn('deer', 'Dead deer'), btn('ko', 'Knocked-out man'), btn('rope', 'Rope + tape')]),
      sect('Nightlife & charm', [btn('strip', 'Strip club'), btn('costume', 'Costume shop'), btn('worker', 'Street worker'), btn('saint', 'Make me a saint'), btn('thug', 'Make me a thug'), btn('date', 'Someone who likes me')]),
      sect('Story NPCs', Object.keys(R.stories ? R.stories.PEOPLE : {}).map((k) => btn('npc:' + k, R.stories.PEOPLE[k].name)).concat([btn('perks', 'All story perks')])),
      sect('Exploration', PL.map((p, i) => btn('lm:' + i, p.name.replace(/^The /, ''))).concat([btn('tins', 'Show tins on map'), btn('smash', 'Street furniture here')])),
      sect('Opening', [btn('opening', 'Replay the opening'), btn('rename', 'Change my name')]),
      sect('Street business', [btn('loan', 'A debtor, a week late'), btn('fix', 'A fixed race'), btn('cops', '3 cops + captain here'), btn('ia', 'Internal Affairs sweep'), btn('rat', 'Someone flips'), btn('ratclue', 'Next rat clue'), btn('truck', 'Truck tip'), btn('shooters', 'Desert gunmen: all leads')]),
      sect('Reputation & weather', [btn('respect', 'Respected (honor 80)'), btn('fear', 'Feared (infamy 80)'), btn('dust', 'Dust storm'), btn('dent', 'Beat up the nearest car'), btn('collector', 'Rival collector here'), btn('crew', 'Rival hijack crew'), btn('wreck', 'Wreck on the road')]),
    ].join('');
    body.insertAdjacentHTML('beforeend', html);
    const near = () => w.findNear(pl.x / TS, pl.y / TS, 2, 6, (x, y) => !w.solidPed(x, y) && !w.isWater(x, y)) || { x: pl.x / TS, y: pl.y / TS };
    const tp = (x, y) => { if (pl.room) g.interiors.exit(); if (pl.inCar) pl.exitCar(); pl.place(x * TS + 8, y * TS + 8); g.cam.x = pl.x; g.cam.y = pl.y; ui.closeSheet(); };
    const human = (o) => { const s = near(); return g.actors.makeHuman(s.x * TS + 8, s.y * TS + 8, o || {}); };
    const person = () => { const c = w.cityAt((pl.x / TS) | 0, (pl.y / TS) | 0) || w.cities[0]; return g.pop.people.find((q) => q.alive && q.city === c.id && !q.isDon && q.age > 22 && !q.actor); };
    const city = () => w.cityAt((pl.x / TS) | 0, (pl.y / TS) | 0) || w.cities[0];
    const goTo = (type) => { const b = w.buildings.filter((q) => q && q.type === type && !q.destroyed).sort((a, b2) => Math.hypot(a.out.x - pl.x / TS, a.out.y - pl.y / TS) - Math.hypot(b2.out.x - pl.x / TS, b2.out.y - pl.y / TS))[0]; if (b) tp(b.out.x, b.out.y + 1); };
    body.querySelectorAll('[data-x]').forEach((el) => el.addEventListener('click', () => {
      const [k, v] = el.dataset.x.split(':');
      const C = R.cases, MN = R.money, TF = R.turf, SK = R.profile, VD = R.vendetta;
      try {
        switch (k) {
          case 'loan': { const p = person(); if (!p) break; const L = { pid: p.id, name: g.pop.name(p), principal: 250, vig: 25, day: g.pop.day - 8, due: g.pop.day - 1, late: 1, paid: 0, broke: 0, done: false, city: p.city }; R.shark.state().loans.push(L); if (p.actor && !p.actor.dead) g.actors.remove(p.actor); const s = near(); g.life.spawnPerson(p, s.x * TS + 8, s.y * TS + 8); ui.toast(`${L.name} owes you $275. Talk to them.`); break; }
          case 'fix': R.shark.state().fixed++; ui.toast('Bet the long shot at any bar.'); break;
          case 'cops': { const j = g.law.jurAt(pl.x, pl.y), r = R.payroll.jur(j); const cops = g.pop.people.filter((q) => q.alive && q.role === 'cop'); r.beats = cops.slice(0, 3).map((q) => q.id); r.captain = cops[3] ? cops[3].id : -99; r.capName = 'Captain ' + (cops[3] ? cops[3].last : 'Doyle'); R.payroll.state().due = g.pop.day + 7; ui.toast(`The ${g.law.jurName(j)} precinct is on your payroll.`); break; }
          case 'ia': { const s = R.payroll.state(), j = Object.keys(s.jur).find((q) => s.jur[q].beats.length || s.jur[q].captain != null); if (!j) { ui.toast('Buy some cops first.'); break; } const r = s.jur[j], burned = r.captain != null ? r.captain : r.beats[0]; ui.closeSheet(); ui.story('INTERNAL AFFAIRS', 'IA swept the precinct. Everybody you paid there is suspended, and one of them would very much like a deal.'); if (burned >= 0) R.rat.pressure(burned, 8); r.beats = []; r.captain = null; s.sweeps++; break; }
          case 'rat': { const p = R.shark.open()[0] ? g.pop.people[R.shark.open()[0].pid] : person(); if (!p) break; R.rat.pressure(p.id, 20, 'debtor'); R.rat.flip(p); const r = R.rat.state().cur; r.nextClue = g.pop.day; R.rat.clue(r); ui.toast(`${r.name} is talking to the FBI. Check the Heat tab.`); break; }
          case 'ratclue': { const r = R.rat.active(); if (r) R.rat.clue(r); else ui.toast('No rat right now.'); break; }
          case 'truck': R.hijack.state().tip = null; R.hijack.tip(null); break;
          case 'shooters': { const s = R.desert.state(); if (!s.shooters) { const pool = g.pop.people.filter((q) => q.alive && !q.fem && q.age > 22 && q.age < 50 && q.role !== 'cop' && !q.isDon && !q.faction); s.shooters = [pool[1].id, pool[5].id]; } for (const p of R.desert.men()) { const L = R.desert.lead(p); L.name = L.where = true; } ui.toast('Both names and where they work. Check the Jobs tab.'); break; }
          case 'collector': R.rivals.end(); ui.closeSheet(); R.rivals.collector(g, city()); if (!R.rivals.scene) ui.toast('Nobody broke enough around here. Try a busier street.'); break;
          case 'crew': R.rivals.end(); ui.closeSheet(); R.rivals.crew(g); if (!R.rivals.scene) ui.toast('Needs a highway outside town.'); break;
          case 'wreck': { const v = g.traffic.list.find((q) => !q.removed && !q.wrecked && q.driver && q.driver !== pl && R.dist(q.x, q.y, pl.x, pl.y) < TS * 16); if (v) { g.traffic.exitVehicle(v, v.driver); v.hp = v.maxHp * 0.1; v.burning = 0.01; ui.toast('A car\'s on fire up the road. Watch the drivers gawk.'); } else ui.toast('No traffic nearby.'); break; }
          case 'respect': pl.rep.honor = 80; pl.rep.infamy = Math.min(pl.rep.infamy, 30); break;
          case 'fear': pl.rep.infamy = 80; break;
          case 'dust': R.dust.storm = { left: 90 }; ui.toast(R.dust.inDesert() ? 'Dust storm.' : 'Dust storm (it only shows out in the Dustwater desert).'); break;
          case 'dent': { const v = g.traffic.nearestCar(pl.x, pl.y, 200); if (v) { v.hp = v.maxHp * 0.2; for (let i = 0; i < 5; i++) R.cars.dent(v, v.x + (Math.random() - 0.5) * 40, v.y + (Math.random() - 0.5) * 16, 90); } break; }
          case 'guns': for (const id in D.weapons) if (!D.weapons[id].thrown && !D.weapons[id].ring) pl.giveWeapon(id); Object.assign(pl.inv.ammo, { pistol: 300, shells: 100, smg: 400, rifle: 100, bolts: 40, molotov: 10, dynamite: 10 }); ui.toast('Every weapon on the coast.'); break;
          case 'sil': pl.inv.silenced = {}; for (const id in D.weapons) if (D.weapons[id].sil) pl.inv.silenced[id] = 1; ui.toast('Silencers on everything that takes one.'); break;
          case 'masks': pl.inv.masks = {}; for (const m in R.night.MASKS) pl.inv.masks[m] = 1; pl.inv.tools.mask = 1; ui.toast('All masks. Buy/wear at a costume shop, or MASK to toggle.'); break;
          case 'wardrobe': ui.closeSheet(); R.openWardrobe('tailor'); break;
          case 'barber': ui.closeSheet(); R.openWardrobe('barber'); break;
          case 'dirty': pl.addCash(2000); break;
          case 'wash': MN.state().dirty = 0; ui.toast('All clean.'); break;
          case 'susp': MN.state().susp = 90; ui.toast('Suspicion 90. An audit can land any morning.'); break;
          case 'audit': ui.closeSheet(); MN.audit(); break;
          case 'cleanm': MN.state().susp = 0; break;
          case 'case': { const h = human(); h.keep = true; const wit = human(); wit.keep = true; pl.giveWeapon('revolver'); pl.weapon = 'revolver'; R.combat.kill(h, pl, 'bullet'); ui.toast('Murder committed in front of a witness. Check the Heat tab.'); break; }
          case 'case70': for (const c of C.open()) c.progress = 70; break;
          case 'warrant': { const c = C.open()[0]; if (c) { c.progress = 99.9; C.hour(); } else ui.toast('No open case.'); break; }
          case 'det': { const c = C.open()[0]; if (c) { c.visited = false; C.detective = null; ui.closeSheet(); C.visit(c); } else ui.toast('No open case.'); break; }
          case 'wipe': for (const c of C.state().list) c.status = 'closed'; break;
          case 'sk': { const s = SK.state(), cid = city().id; for (let i = 0; i < 3; i++) { const q = g.pop.people.find((p) => p.alive && !p.isDon && p.fem && !s.unsolved.some((u) => u.pid === p.id) && !s.pending.some((u) => u.pid === p.id)); if (!q) break; s.pending.push({ pid: q.id, day: g.pop.day, weapon: 'blade', cut: 'none', dump: 'left', sex: 'f', age: 'mid', city: cid, time: 'night', x: pl.x, y: pl.y }); SK.discovered(s.pending[s.pending.length - 1], 'found'); } break; }
          case 'skheat': if (SK.state().profile) { SK.state().profile.heat = 90; SK.apply(SK.state().profile); } else ui.toast('Form a task force first.'); break;
          case 'frisk': if (SK.state().profile) { ui.closeSheet(); SK.frisk(near()); } else ui.toast('Form a task force first.'); break;
          case 'poi': SK.suspect(100); break;
          case 'skclear': { const s = SK.state(); s.profile = null; s.poi = 0; s.linked = false; SK.apply(null); break; }
          case 'war': { const f = city().def.family, o = R.data.cities.map((c) => c.family).find((x) => x !== f && x !== pl.family); TF.state().wars.push({ a: f, b: o, days: 0 }); TF.t = 0; ui.toast(`${f} vs ${o}. Shootouts start here soon.`); break; }
          case 'squad': { const f = R.data.cities.map((c) => c.family).find((x) => x !== pl.family); TF.state().grudge[f] = 60; TF.pendingSquad = f; ui.closeSheet(); break; }
          case 'racket': { const b = w.buildings.find((q) => q && q.city === city() && ['diner', 'general', 'laundry', 'barber'].includes(q.type)); if (b) { b.racket = 1; b.racketFamily = pl.family; TF.hitRacket(R.data.cities.map((c) => c.family).find((x) => x !== pl.family)); } break; }
          case 'rule': { const c = city(); R.campaign.claim(c, c.def.family); break; }
          case 'revolt': { const s = TF.state(), ruled = R.campaign.state().ruled, id = Object.keys(ruled)[0]; if (!id) { ui.toast('Rule a city first.'); break; } s.loyalty[id] = 10; TF.holdCities(); break; }
          case 'avenger': case 'hired': case 'letter': { const p = person(); if (!p) break; const vic = g.pop.people.find((q) => !q.alive) || person(); VD.state().list.push({ pid: p.id, vid: vic.id, rel: 'sibling', day: g.pop.day, knows: true, mode: k === 'avenger' ? 'hunt' : k === 'hired' ? 'hire' : 'blackmail', done: false, heat: 100, dueDay: 0 }); if (k === 'letter') { ui.closeSheet(); VD.letter(VD.state().list[VD.state().list.length - 1]); } else { VD.t = 0; ui.closeSheet(); } break; }
          case 'corpse': { const h = human(); h.keep = true; R.combat.kill(h, null, 'melee'); h.looted = true; pl.giveWeapon('knife'); pl.weapon = 'knife'; ui.toast('A body and a knife. USE on it.'); break; }
          case 'corpses': for (let i = 0; i < 5; i++) { const h = human(); h.keep = true; R.combat.kill(h, null, 'bullet'); } break;
          case 'bag': pl.inv.tools.remains = (pl.inv.tools.remains || 0) + 1; break;
          case 'deer': { const s = near(); const a = g.actors.makeAnimal(s.x * TS + 8, s.y * TS + 8, Object.keys(D.animals).find((x) => /deer/.test(x)) || Object.keys(D.animals)[0]); R.combat.kill(a, null, 'bullet'); break; }
          case 'ko': { const h = human(); h.keep = true; h.down = 60; h.ko = true; break; }
          case 'rope': pl.inv.tools.rope = (pl.inv.tools.rope || 0) + 5; pl.inv.tools.tape = (pl.inv.tools.tape || 0) + 5; break;
          case 'strip': goTo('strip'); break;
          case 'costume': goTo('costume'); break;
          case 'worker': { const b = w.buildings.find((q) => q && ['motel', 'bar', 'strip'].includes(q.type) && q.city === city()) || w.buildings.find((q) => q && q.type === 'bar'); R.night.spawnWorker(b ? { out: { x: (pl.x / TS) | 0, y: ((pl.y / TS) | 0) + 2 } } : b); ui.closeSheet(); break; }
          case 'saint': pl.rep.honor = 90; pl.rep.infamy = 5; break;
          case 'thug': pl.rep.honor = 5; pl.rep.infamy = 85; break;
          case 'date': { const h = human({ arch: 'flirt' }); h.keep = true; h.flirted = 2; if (h.person) h.person.opinion = 70; ui.closeSheet(); ui.toast('Someone who likes you is nearby. Seduce them.'); break; }
          case 'npc': { const P = R.stories.PEOPLE[v], c = g.jobs.cityOfFamily(P.city), b = c && c.buildings.find((x) => x && P.where.includes(x.type)); if (b) { g.clock.t = Math.floor(g.clock.t / 1440) * 1440 + 1440 + (P.hours[0] + 1) * 60; R.stories.t = 0; tp(b.out.x, b.out.y + 3); } break; }
          case 'perks': { const s = R.campaign.state(); for (const p of ['sanctuary', 'vera', 'hale', 'doc', 'zelie']) s.perks[p] = 1; ui.toast('All story perks.'); break; }
          case 'lm': { const p = PL[+v]; tp(p.at.x + 1, p.at.y + 3); break; }
          case 'tins': { const s = R.salvage.state(); while (s.tins.length < 10) s.tins.push(-1 - s.tins.length); ui.toast('Tins now show on the minimap.'); break; }
          case 'smash': { const s = near(); const O = D.O; [O.TRASH, O.MAILBOX, O.PHONE, O.CRATE, O.BENCH].forEach((o, i) => w.setO(((s.x | 0) + i - 2), (s.y | 0) + 1, o)); ui.toast('Smash away (melee).'); break; }
          case 'opening': ui.closeSheet(); R.opening.pickedUp = false; R.opening.run(g); break;
          case 'rename': ui.closeSheet(); R.opening.nameSheet(g, () => ui.toast(`You're ${pl.first} "${pl.nick}" ${pl.last} now.`, 'good')); break;
        }
      } catch (e) { ui.toast('Debug: ' + e.message, 'bad'); console.error(e); }
    }));
  };
})();
