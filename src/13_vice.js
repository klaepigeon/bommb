// RHAPSODY — vice and private lives.
//   Dealing: buy weight from dealers, sell to people who want it or work a corner; every
//            town craves something different, and cops and squares don't approve.
//   Romance: ask people out, take them dancing, bring them home (the camera looks away),
//            propose, marry, and raise the kids who come along.
//   Affairs: married folk cheat. Hear it through gossip or a phone tap, then blackmail
//            the cheater or tell the spouse.
//   Phone taps: a blue box on a house's line or a payphone fills your Files: affairs,
//            debts, hidden cash, safe combinations, rats and family deals, each usable.
'use strict';
(function () {
  const D = R.data, TS = R.TILE;
  const V = (R.vice = {});
  const G = () => R.game;
  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
  V.state = function () {
    const pl = G().player;
    return (pl.vice = pl.vice || { love: {}, kids: [], files: [], nextFile: 1, customers: {}, sold: 0, tapped: {}, hush: {} });
  };

  // ---------------------------------------------------------------- dealing
  // what each town craves
  const DEMAND = {
    port: { reefer: 1.35, smack: 1.25, ludes: 1.1 }, avalon: { coke: 1.6, ludes: 1.3, acid: 1.15 }, dust: { dust: 1.55, uppers: 1.3, reefer: 1.1 },
    pine: { uppers: 1.45, reefer: 1.25, smack: 1.1 }, bayou: { smack: 1.5, reefer: 1.3, acid: 1.2 },
  };
  const BUYER_ARCH = { hustler: 0.8, flirt: 0.6, eccentric: 0.7, tough: 0.45, gossip: 0.35, friendly: 0.25, grumpy: 0.2, timid: 0.15, square: 0.05, pious: 0.02 };
  V.streetPrice = function (k, cityId) {
    const d = D.drugs[k];
    return Math.round(d.price * 1.35 * ((DEMAND[cityId] || {})[k] || 0.9));
  };
  V.cityHere = function () { const g = G(), pl = g.player; return g.world.cityAt((pl.x / TS) | 0, (pl.y / TS) | 0); };
  V.sell = function (h, k) {
    const g = G(), pl = g.player, s = this.state();
    const c = this.cityHere(), cid = c ? c.id : 'county';
    let price = this.streetPrice(k, cid);
    if (h.person && s.customers[h.person.id]) price = Math.round(price * 1.15); // regulars pay a little more
    pl.inv.drugs[k]--;
    pl.addCash(price);
    s.sold++;
    if (h.person) { s.customers[h.person.id] = (s.customers[h.person.id] || 0) + 1; h.person.opinion = Math.min(100, h.person.opinion + 3); }
    g.audio.sfx('cash');
    g.fx.text(h.x, h.y - 26, `+${R.fmtMoney(price)}`, '#8ab04a');
    // someone else's turf
    const fam = c && c.def && c.def.family;
    if (fam && fam !== pl.family) { g.jobs.standing[fam] = Math.max(-100, (g.jobs.standing[fam] || 0) - 1.5); if (R.rng() < 0.12) g.ui.toast(`The ${fam}s don't like you dealing on their streets.`, 'warn'); }
    // was anybody watching?
    for (const a of g.actors.near(pl.x, pl.y, TS * 8)) {
      if (a.dead || a === h) continue;
      if (a.cop && g.world.los(a.x, a.y - 8, pl.x, pl.y - 8)) { g.law.crime('dealing', pl.x, pl.y, { witness: a }); break; }
      if (a.kind === 'h' && (a.arch === 'square' || a.arch === 'pious') && R.rng() < 0.25 && g.world.los(a.x, a.y - 8, pl.x, pl.y - 8)) { g.law.crime('dealing', pl.x, pl.y, {}); break; }
    }
    return price;
  };
  V.pitch = function (h, say) {
    const g = G(), pl = g.player;
    const have = Object.keys(pl.inv.drugs || {}).filter((k) => pl.inv.drugs[k] > 0);
    if (h.cop) { say('Is that so? Hands on the car.'); g.law.crime('dealing', pl.x, pl.y, { witness: h }); return; }
    const want = (BUYER_ARCH[h.arch] || 0.2) + (h.drunk > 0.3 ? 0.25 : 0) + (h.person && h.person.age < 35 ? 0.15 : 0) + (h.person && this.state().customers[h.person.id] ? 0.4 : 0);
    if (R.rng() > want) {
      if (h.arch === 'square' || h.arch === 'pious') { say(R.rng.pick(['Drugs? I\'m calling the police!', 'Shame on you. SHAME.'])); if (R.rng() < 0.5) g.law.crime('dealing', pl.x, pl.y, {}); }
      else say(R.rng.pick(['Nah, I\'m clean.', 'Not today, man.', 'My wife would kill me.']));
      return;
    }
    const c = this.cityHere(), cid = c ? c.id : 'county';
    const k = have.slice().sort((a, b) => ((DEMAND[cid] || {})[b] || 0.9) - ((DEMAND[cid] || {})[a] || 0.9))[0];
    const price = this.sell(h, k);
    say(R.rng.pick([`${D.drugs[k].street}? Here's ${R.fmtMoney(price)}. Where can I find you again?`, 'Far out. Same time next week?', 'Keep it quiet, huh?']));
  };
  // work a corner: buyers walk up to you
  V.startCorner = function () {
    const g = G(), pl = g.player;
    if (pl.inCar || pl.room) return g.ui.toast('Find a street corner first.', 'warn');
    const c = this.cityHere();
    if (!c) return g.ui.toast('Nobody out here to sell to. Find a town.', 'warn');
    this.corner = { x: pl.x, y: pl.y, t: 120, next: 3, buyer: null, sales: 0 };
    g.ui.closeSheet();
    g.ui.toast(`Open for business in ${c.name}. Stay put; they'll come to you. Craves: ${Object.keys(DEMAND[c.id] || {}).map((k) => D.drugs[k].name).join(', ') || 'anything'}.`, 'good');
  };
  V.updateCorner = function (dt) {
    const g = G(), pl = g.player, cn = this.corner;
    if (!cn) return;
    const have = Object.keys(pl.inv.drugs || {}).filter((k) => pl.inv.drugs[k] > 0);
    const stop = (why) => { if (cn.buyer && !cn.buyer.dead) { cn.buyer.keep = false; cn.buyer.state = 'idle'; } this.corner = null; g.ui.toast(`${why} (${cn.sales} sales)`, cn.sales ? 'good' : ''); };
    if (!have.length) return stop('Sold out.');
    if (Math.hypot(pl.x - cn.x, pl.y - cn.y) > TS * 3 || pl.inCar || pl.room) return stop('You left your corner.');
    if (g.law.active()) return stop('Heat\'s on. You close up shop.');
    cn.t -= dt;
    if (cn.t <= 0) return stop('The street goes quiet.');
    const b = cn.buyer;
    if (!b) {
      cn.next -= dt;
      if (cn.next > 0) return;
      cn.next = 5 + R.rng() * 6 * (g.clock.isNight() ? 0.6 : 1);
      const pick = g.actors.near(pl.x, pl.y, TS * 14, (a) => a.kind === 'h' && !a.dead && !a.cop && !a.crew && !a.look.kid && a.state !== 'fight' && !a.stay && R.rng() < (BUYER_ARCH[a.arch] || 0.2) + 0.2)[0];
      if (pick) { cn.buyer = pick; pick.keep = true; cn.bt = 0; }
      return;
    }
    if (b.dead || b.down > 0) { cn.buyer = null; return; }
    const d = Math.hypot(b.x - pl.x, b.y - pl.y);
    cn.bt = (cn.bt || 0) + dt;
    if (cn.bt > 8 && d > TS * 3) { b.keep = false; cn.buyer = null; return; } // got distracted
    if (d > TS * (cn.bt > 8 ? 3 : 1.2)) {
      b.state = 'idle'; b.timer = 1;
      g.actors.moveActor(b, (pl.x - b.x) / d * 40, (pl.y - b.y) / d * 40, dt);
      b.walk += dt * 10; b.dir = R.dir4(pl.x - b.x, pl.y - b.y); b.ang = Math.atan2(pl.y - b.y, pl.x - b.x);
      return;
    }
    const cid = this.cityHere() ? this.cityHere().id : 'county';
    const k = have.sort((x, y) => ((DEMAND[cid] || {})[y] || 0.9) - ((DEMAND[cid] || {})[x] || 0.9))[0];
    this.sell(b, k);
    g.actors.say(b, R.rng.pick(['Thanks, man.', 'You\'re a lifesaver.', 'Same time tomorrow?', 'Groovy.']));
    cn.sales++;
    b.keep = false; b.state = 'idle'; b.timer = 2;
    cn.buyer = null;
  };
  // buy weight from a dealer: ten at wholesale
  V.dealerWeight = function (h, opts, render) {
    const g = G(), pl = g.player;
    for (const k of R.goods.dealerStock(h)) {
      const d = D.drugs[k], p = Math.round(d.price * h.markup * 0.5) * 10;
      opts.splice(opts.length - 1, 0, { label: `Buy weight: 10 × ${d.name}`, small: `Wholesale. Sells for about ${R.fmtMoney(this.streetPrice(k, (this.cityHere() || { id: 'x' }).id))} each on the right street.`, price: R.fmtMoney(p), fn: () => {
        if (!pl.pay(p)) return render('"Come back with real money."');
        pl.inv.drugs[k] = (pl.inv.drugs[k] || 0) + 10;
        g.audio.sfx('cash');
        render('"Don\'t say where you got it."');
      } });
    }
  };

  // ---------------------------------------------------------------- romance and family
  V.partner = function (id) { return this.state().love[id]; };
  V.hasPlace = function () { const g = G(), pl = g.player; return (pl.properties || []).some((id) => { const b = g.world.buildings[id]; return b && !b.destroyed && (D.btypes[b.type].house || b.type === 'suite'); }) || !!(R.estate && R.estate.rental(g)); };
  V.date = function (p, venue) {
    const g = G(), pl = g.player, s = this.state(), r = s.love[p.id];
    const VEN = {
      diner: ['Dinner at the diner', 20, 'Meatloaf, pie and a jukebox. ' + p.first + ' steals your fries and laughs at every bad joke.', 8],
      dance: ['Dancing at the disco', 15, 'The floor lights up under you. ' + p.first + ' can really move.', 12],
      movie: ['A double feature and a malt', 8, 'Two monster movies. ' + p.first + ' grabs your arm at the scary parts, on purpose.', 7],
      drive: ['A drive up to the lookout', 0, 'The whole coast lit up below you. Neither of you says much. You don\'t need to.', 14],
    }[venue];
    if (venue === 'drive' && !pl.inCar && !g.traffic.list.some((v) => v.owner === 'player' || v.stolen)) return g.ui.toast('You need wheels for that.', 'warn');
    if (!pl.pay(VEN[1])) return g.ui.toast(`That date costs ${R.fmtMoney(VEN[1])}.`, 'warn');
    g.clock.skip(120);
    r.love = Math.min(100, r.love + VEN[3] + (pl.cool > 60 ? 3 : 0));
    r.last = g.pop.day;
    p.opinion = Math.min(100, p.opinion + 6);
    pl.cool = Math.min(100, pl.cool + 25);
    g.ui.story(VEN[0], `${VEN[2]}\n\n♥ ${Math.round(r.love)}/100`);
  };
  V.bringHome = function (p) {
    const g = G(), s = this.state(), r = s.love[p.id], pl = g.player;
    if (!this.hasPlace()) return g.ui.toast('You need a place: buy a safehouse or rent a hotel room.', 'warn');
    g.clock.skip(60 * 6);
    r.love = Math.min(100, r.love + 10); r.last = g.pop.day; r.nights = (r.nights || 0) + 1;
    pl.hp = pl.maxHp; pl.cool = 100;
    const canBaby = p.fem !== pl.look.fem && p.age >= 18 && p.age <= 42 && r.pregnantDay == null && (r.kidsN || 0) < 4;
    if (canBaby && R.rng() < 0.22) r.pregnantDay = g.pop.day;
    g.ui.story('Later that night...', `The record ends. Nobody gets up to change it.\n\nThe rest of the night is nobody's business.\n\n(Full health, full Cool. ♥ ${Math.round(r.love)}/100)`);
  };
  V.propose = function (p) {
    const g = G(), pl = g.player, s = this.state(), r = s.love[p.id];
    if (!pl.pay(300)) return g.ui.toast('A ring worth giving is $300.', 'warn');
    if (r.love < 80 || R.rng() > r.love / 110) { r.love -= 10; return g.ui.story('Not yet', `${p.first} looks at the ring a long time, then closes the box. "Ask me again when you mean it. When I know you."`); }
    r.stage = 'married'; p.playerPartner = true;
    for (const id in s.love) if (+id !== p.id && s.love[id].stage !== 'ex') s.love[id].stage = 'ex';
    pl.sweetheart = p.id;
    g.pop.addNews(p.city, `Wedding bells: ${p.first} ${p.last} weds ${pl.name}. The bride's mother wore black.`);
    g.ui.story('JUST MARRIED', `A little chapel, a big party, and somebody's uncle starts a fight at the reception. ${p.first} is family now.\n\nYour spouse will cover for you with the cops once a day, patches you up when you sleep at home, and the kids will have your name.`);
    g.audio.sfx('promote');
  };
  V.babies = function () {
    const g = G(), s = this.state(), pl = g.player, pop = g.pop;
    for (const id in s.love) {
      const r = s.love[id], p = pop.people[id];
      if (r.pregnantDay == null || !p || !p.alive) continue;
      if (pop.day - r.pregnantDay < 1) continue;
      r.pregnantDay = null;
      const rnd = R.mulberry(p.id * 31 + pop.day);
      const last = pl.name.split(' ').slice(-1)[0];
      const kid = pop.newPerson(rnd, p.city, { age: 0, last, home: p.home, parents: [p.id] });
      kid.look = pop.makeLook(R.mulberry(kid.seed), kid);
      kid.look.skin = rnd.chance(0.5) ? p.look.skin : pl.look.skin || p.look.skin;
      kid.playerChild = true; kid.met = true; kid.opinion = 80;
      p.kids.push(kid.id);
      const home = g.world.buildings[p.home];
      if (home) home.residents.push(kid.id);
      s.kids.push(kid.id);
      r.kidsN = (r.kidsN || 0) + 1;
      g.ui.story(kid.fem ? 'IT\'S A GIRL' : 'IT\'S A BOY', `${p.first} calls you from the hospital. ${kid.first} ${kid.last}: ten fingers, ten toes, and your nose, God help ${kid.fem ? 'her' : 'him'}.\n\nOn the Brass Coast kids grow up fast: a year a day. Visit, give them an allowance, and one day they might ride with you.`);
      pop.addNews(p.city, `Born: ${kid.first} ${kid.last}, to ${p.first} ${p.last} and ${pl.name}.`);
    }
  };
  V.dailyLove = function () {
    const g = G(), s = this.state(), pop = g.pop;
    const active = Object.keys(s.love).filter((id) => s.love[id].stage !== 'ex' && pop.people[id] && pop.people[id].alive);
    for (const id of active) {
      const r = s.love[id];
      if (pop.day - (r.last || 0) >= 3) r.love = Math.max(0, r.love - 3);
      if (r.love <= 0 && r.stage !== 'married') { r.stage = 'ex'; g.ui.toast(`${pop.people[id].first} stopped waiting for you to call.`, 'warn'); }
    }
    // two at once? they find out eventually
    const dating = active.filter((id) => s.love[id].stage !== 'ex');
    if (dating.length >= 2 && R.rng() < 0.2) {
      const [a, b] = dating.slice(0, 2).map((id) => pop.people[id]);
      for (const p of [a, b]) { const r = s.love[p.id]; r.love = Math.max(0, r.love - 35); p.opinion = Math.max(-100, p.opinion - 30); }
      g.ui.story('BUSTED', `${a.first} and ${b.first} found out about each other. There was yelling. There was a thrown drink.\n\nBoth of them are furious with you.`);
    }
    this.babies();
  };

  // ---------------------------------------------------------------- affairs, files and blackmail
  V.addFile = function (f) {
    const s = this.state();
    if (s.files.some((x) => x.kind === f.kind && x.about === f.about && x.other === f.other && !x.used)) {
      const x = s.files.find((y) => y.kind === f.kind && y.about === f.about && y.other === f.other);
      if (f.proof && !x.proof) { x.proof = true; x.text = f.text; G().ui.toast(`Proof added to your file on ${G().pop.name(G().pop.people[f.about])}.`, 'good'); }
      return x;
    }
    f.id = s.nextFile++; f.day = G().pop.day;
    s.files.unshift(f);
    if (s.files.length > 60) s.files.pop();
    G().ui.toast(`New in your Files: ${f.title}`, 'good');
    return f;
  };
  V.dailyAffairs = function () {
    const g = G(), pop = g.pop;
    for (const cid in pop.byCity) {
      const list = pop.byCity[cid];
      for (const p of list) {
        if (!p.alive || p.spouse < 0 || p.affair != null || p.age < 22 || p.age > 60 || R.rng() > 0.012) continue;
        const lover = list.find((q) => q.alive && q !== p && q.id !== p.spouse && q.fem !== p.fem && q.age >= 20 && Math.abs(q.age - p.age) < 15 && q.affair == null && R.rng() < 0.08);
        if (!lover) continue;
        p.affair = lover.id; lover.affair = p.id;
      }
    }
  };
  // gossip carries affairs you already half-know about
  const baseRumor = R.dialog.rumor;
  R.dialog.rumor = function (h) {
    const g = G(), pop = g.pop;
    if (R.rng() < 0.3) {
      const city = h.person ? h.person.city : null;
      const cheat = (pop.byCity[city] || []).find((p) => p.alive && p.affair != null && p.met && pop.people[p.affair] && pop.people[p.affair].alive);
      if (cheat) {
        const lover = pop.people[cheat.affair], sp = pop.people[cheat.spouse];
        V.addFile({ kind: 'affair', about: cheat.id, other: lover.id, proof: false, title: `${pop.name(cheat)} is cheating`, text: `Gossip says ${cheat.first} is seeing ${lover.first} ${lover.last} behind ${sp ? sp.first + '\'s' : 'their spouse\'s'} back. Hearsay: a phone tap would make it proof.` });
        return `Don't repeat this, but ${cheat.first} ${cheat.last} has been sneaking out to see ${lover.first} ${lover.last}. And ${cheat.fem ? 'her' : 'his'} ${sp ? (sp.fem ? 'wife' : 'husband') : 'spouse'} has no idea.`;
      }
    }
    return baseRumor.call(this, h);
  };
  // the blue box: tap a house line or a payphone
  V.tap = function (target) {
    const g = G(), pl = g.player, s = this.state(), pop = g.pop;
    if (!pl.inv.tools.bluebox) return g.ui.toast('You need a blue box. Pawn shops keep one under the counter.', 'warn');
    const key = target.b ? 'b' + target.b.id : 'p' + target.x + ',' + target.y;
    if (s.tapped[key] === pop.day) return g.ui.toast('You already bled this line dry today.');
    R.mini.hotwire({ wires: 4, time: 16, title: 'Tap the Line', sub: 'Match the pairs on the junction block, then clip in before someone picks up.' }, (ok) => {
      if (!ok) { g.ui.toast('Sparks, a dial tone, a neighbour at the window.', 'warn'); if (R.rng() < 0.4) g.law.crime('trespass', pl.x, pl.y, {}); return; }
      s.tapped[key] = pop.day;
      g.audio.sfx('coolOn');
      let n = 0;
      if (target.b) {
        const occ = target.b.residents.map((id) => pop.people[id]).filter((p) => p && p.alive && p.age >= 16);
        for (const p of occ) {
          p.met = true;
          if (p.affair != null && pop.people[p.affair]) { const lv = pop.people[p.affair], sp = pop.people[p.spouse]; V.addFile({ kind: 'affair', about: p.id, other: lv.id, proof: true, title: `${pop.name(p)} is cheating`, text: `On tape: ${p.first} whispering to ${lv.first} ${lv.last} about "Tuesday, same motel". ${sp ? sp.first + ' is in the next room.' : ''} That's proof.` }); n++; }
          if (p.debt > 0) { V.addFile({ kind: 'debt', about: p.id, proof: true, title: `${pop.name(p)} owes money`, text: `${p.first} begging a cousin for ${R.fmtMoney(p.debt)} to cover a debt. Desperate people make deals.` }); n++; }
          if (p.wealth > 60 && R.rng() < 0.6) { const b = target.b; b.stash = (b.stash || 0) + R.rng.int(120, 320); V.addFile({ kind: 'stash', about: p.id, b: b.id, proof: true, title: `Cash hidden at ${p.last}'s`, text: `${p.first} on the phone: "It's under the floorboard, where it always is." ${R.fmtMoney(b.stash)} or so.` }); n++; }
          if (p.faction && p.faction !== 'law' && R.rng() < 0.7) { V.addFile({ kind: 'deal', about: p.id, fam: p.faction, proof: true, title: `${p.faction} business`, text: `${p.first} talking about a shipment for the ${p.faction}s: times, places, names. The cops or a rival family would pay for this.` }); n++; }
        }
        target.b.comboKnown = true;
        V.addFile({ kind: 'combo', about: -1, b: target.b.id, proof: true, title: `Safe combination: ${target.b.name}`, text: `Somebody read the combination out loud over the phone. Any safe in ${target.b.name} opens without a fuss now.` }); n++;
      } else {
        // payphones: the whole town's business
        const c = V.cityHere(), list = c ? (pop.byCity[c.id] || []).filter((p) => p.alive && p.age >= 18) : [];
        const rat = list.find((p) => p.faction && p.faction !== 'law' && R.rng() < 0.08);
        if (rat) { V.addFile({ kind: 'informant', about: rat.id, fam: rat.faction, proof: true, title: `${pop.name(rat)} is a rat`, text: `${rat.first} ${rat.last} calling a detective from this very phone, naming ${rat.faction} names. The ${rat.faction}s would pay to know. Or you could use it.` }); n++; }
        const cheat = list.find((p) => p.affair != null && R.rng() < 0.3);
        if (cheat) { const lv = pop.people[cheat.affair]; cheat.met = true; V.addFile({ kind: 'affair', about: cheat.id, other: lv.id, proof: true, title: `${pop.name(cheat)} is cheating`, text: `${cheat.first} calling ${lv.first} ${lv.last} from the payphone so the spouse won't see the bill. Recorded.` }); n++; }
        if (!n) { const lead = g.jobs.makeLead({ x: pl.x, y: pl.y }); if (lead) { g.ui.toast(`Overheard: ${lead}`); n++; } }
      }
      g.ui.toast(n ? `The tape is rolling. ${n} new ${n > 1 ? 'files' : 'file'}: check the Files tab.` : 'Nothing but a weather report and somebody\'s mother.', n ? 'good' : '');
    });
  };
  V.blackmail = function (h, f, say) {
    const g = G(), pl = g.player, s = this.state(), p = h.person;
    const last = s.hush[p.id];
    if (last != null && g.pop.day - last < 5) return say('I already paid you. Leave me alone!');
    const brave = h.tr.brave + (f.proof ? -0.35 : 0.15) - (pl.weaponOut ? 0.25 : 0);
    if (!f.proof && R.rng() < 0.45) { say(R.rng.pick(['That\'s a lie and you can\'t prove it.', 'Says who? Get lost.'])); return; }
    if (brave > 0.75 && R.rng() < 0.5) { say('You son of a bitch!'); h.hostile = true; g.actors.setFight(h, pl); return; }
    const amt = Math.round(40 + (p.wealth || 20) * (f.proof ? 3 : 1.5));
    s.hush[p.id] = g.pop.day;
    pl.addCash(amt);
    p.fear = Math.min(100, (p.fear || 0) + 40); p.opinion = Math.max(-100, p.opinion - 25);
    g.pop.remember(p, 'threatened', 'Somebody knows my secret and makes me pay for it.', g.pop.day);
    g.audio.sfx('cash');
    say(R.rng.pick([`Here. ${R.fmtMoney(amt)}. Just... keep your mouth shut.`, `Take it. Please don't tell ${f.kind === 'affair' ? 'my family' : 'anyone'}.`]));
  };
  V.tellSpouse = function (h, f, say) {
    const g = G(), pop = g.pop, cheat = pop.people[f.about], sp = h.person, lover = pop.people[f.other];
    f.used = true;
    if (!f.proof && R.rng() < 0.4) { say('I don\'t believe you. My ' + (cheat.fem ? 'wife' : 'husband') + ' would never.'); sp.opinion -= 10; return; }
    say(R.rng.pick(['I KNEW it. I knew it!', 'That lying...', '...Thank you for telling me.']));
    sp.opinion = Math.min(100, sp.opinion + 15);
    cheat.opinion = Math.max(-100, cheat.opinion - 50); cheat.grudge = 1;
    if (lover) { lover.affair = null; }
    cheat.affair = null;
    if (R.rng() < 0.7) {
      cheat.spouse = -1; sp.spouse = -1;
      pop.addNews(sp.city, `Divorce filed: ${sp.first} ${sp.last} v. ${cheat.first} ${cheat.last}. Neighbours report "a lot of shouting and a thrown lamp".`);
      g.ui.toast(`${sp.first} is divorcing ${cheat.first}.`, 'warn');
    }
    if (cheat.actor && !cheat.actor.dead && R.rng() < 0.4) { cheat.actor.hostile = true; g.actors.setFight(cheat.actor, g.player); }
  };
  V.useFile = function (f) {
    const g = G(), pl = g.player, pop = g.pop, ui = g.ui;
    const who = pop.people[f.about];
    const opts = [];
    if (who && who.alive) opts.push({ label: `Mark ${who.first} on my map`, fn: () => { const k = g.life.desiredKey(who), pos = g.life.posOf(k); if (pos) { g.waypoint = { x: pos.x * TS + 8, y: pos.y * TS + 8 }; ui.toast(`Route set to ${who.first}.`, 'good'); } else ui.toast('Nobody knows where they are right now.'); } });
    if (f.kind === 'stash' && f.b != null) opts.push({ label: 'Mark the stash', fn: () => { const b = g.world.buildings[f.b]; g.jobs.addLead({ kind: 'stash', x: b.out.x, y: b.out.y, text: `Stash at ${who ? who.last : 'a'} house`, b: b.id }); } });
    if ((f.kind === 'deal' || f.kind === 'informant') && !f.used) {
      const buyer = f.kind === 'informant' ? f.fam : (FAMS.find((x) => x !== f.fam && x !== pl.family) || pl.family);
      opts.push({ label: f.kind === 'informant' ? `Sell the rat to the ${f.fam}s` : `Sell it to the ${buyer}s`, price: f.kind === 'informant' ? '$250' : '$150', fn: () => { f.used = true; pl.addCash(f.kind === 'informant' ? 250 : 150); g.jobs.standing[buyer] = Math.min(100, (g.jobs.standing[buyer] || 0) + 8); if (f.kind === 'informant' && who) { g.pop.remember(who, 'threatened', 'Somebody sold me out to the family.', g.pop.day); if (R.rng() < 0.6) { g.pop.kill(who, 'violence'); g.pop.addNews(who.city, `${who.first} ${who.last} (${who.age}) found floating in the harbor.`); } } ui.toast('Cash for information. Nobody asks where you got it.', 'good'); } });
      const camp = R.campaign && R.campaign.state && R.campaign.state();
      if (camp && camp.route === 'badge' && f.fam) opts.push({ label: 'Give it to Detective Rourke', small: 'Evidence toward a raid', fn: () => { f.used = true; R.campaign.addEvidence(f.fam, 1, 'Wiretap'); } });
    }
    opts.push({ label: 'Shred it', fn: () => { const s = this.state(); s.files = s.files.filter((x) => x !== f); } });
    opts.push({ label: 'Back', fn: () => {} });
    ui.choice(f.title, opts);
  };
  const FAMS = D.cities.map((c) => c.family);
  V.filesHtml = function () {
    const s = this.state(), pop = G().pop;
    const icon = { affair: '♥', debt: '$', stash: '▣', combo: '⊕', deal: '◆', informant: '☎' };
    const love = Object.keys(s.love).map((id) => [pop.people[id], s.love[id]]).filter(([p, r]) => p && r.stage !== 'ex');
    const kids = s.kids.map((id) => pop.people[id]).filter(Boolean);
    return `<div class="sect">Your people</div>${love.length ? love.map(([p, r]) => `<p>♥ <b>${esc(pop.name(p))}</b> · ${r.stage === 'married' ? 'spouse' : 'dating'} · ${Math.round(r.love)}/100${r.pregnantDay != null ? ' · expecting!' : ''}</p>`).join('') : '<p>Nobody special. Greet people, get to know them, ask them out.</p>'}
      ${kids.length ? `<p>Kids: ${kids.map((k) => `${esc(k.first)} (${k.age}${k.alive ? '' : ' †'})`).join(', ')}</p>` : ''}
      <div class="sect">Files</div>${s.files.length ? s.files.map((f, i) => `<button class="opt" data-file="${i}" style="text-align:left">${icon[f.kind] || '•'} ${esc(f.title)}${f.proof ? ' · <b>proof</b>' : ' · hearsay'}${f.used ? ' · used' : ''}<small>${esc(f.text)}</small></button>`).join('') : '<p>Nothing on file. Listen to gossip, or tap a phone line with a blue box.</p>'}
      <div class="sect">Business</div><p>Drugs sold: ${s.sold}. Regular customers: ${Object.keys(s.customers).length}.</p>`;
  };
  V.bindFiles = function (body) {
    const s = this.state();
    body.querySelectorAll('[data-file]').forEach((b) => b.addEventListener('click', () => this.useFile(s.files[+b.dataset.file])));
  };

  // ---------------------------------------------------------------- hooks
  // talk options
  const baseTree = R.dialog.tree;
  R.dialog.tree = function (h) {
    const t = baseTree.call(this, h);
    if (!t || !t.options || h.fearman || h.legend || h.pilot || h.campaignTalk) return t;
    const g = G(), pl = g.player, p = h.person, s = V.state();
    const say = (x) => g.ui.talkLine(x), close = () => g.ui.closeTalk();
    const add = [];
    const have = Object.keys(pl.inv.drugs || {}).some((k) => pl.inv.drugs[k] > 0);
    if (have && !h.look.kid && !h.dealer) add.push({ label: '"Looking to party? I got the good stuff."', fn: () => V.pitch(h, say) });
    if (p && p.alive && !h.look.kid && p.age >= 18 && !h.cop) {
      const r = s.love[p.id];
      if (p.playerChild) { /* your own kid: see below */ }
      else if (r && r.stage !== 'ex') {
        add.push({ label: `Take ${p.first} out`, small: `♥ ${Math.round(r.love)}/100`, fn: () => g.ui.choice(`A date with ${p.first}`, [
          { label: 'Dinner at the diner', price: '$20', fn: () => V.date(p, 'diner') }, { label: 'Dancing at the disco', price: '$15', fn: () => V.date(p, 'dance') },
          { label: 'A double feature and a malt', price: '$8', fn: () => V.date(p, 'movie') }, { label: 'A drive up to the lookout', small: 'Needs a car', fn: () => V.date(p, 'drive') }, { label: 'Not tonight', fn: () => {} }]) });
        if (r.love >= 45) add.push({ label: `Invite ${p.first} back to your place`, small: V.hasPlace() ? 'Your safehouse or hotel room' : 'You need a place first', fn: () => { close(); V.bringHome(p); } });
        if (r.love >= 70 && r.stage !== 'married') add.push({ label: `Propose to ${p.first}`, price: '$300 ring', fn: () => { close(); V.propose(p); } });
        if (r.stage === 'married') add.push({ label: 'Ask your spouse to cover for you', small: 'Once a day: an alibi for the cops', fn: () => { if (r.coverDay === g.pop.day) return say('Once a day, sweetheart. I\'m not a miracle worker.'); r.coverDay = g.pop.day; if (g.law.active() && g.law.incident.state !== 'pursuit') { g.law.clearIncident(true); say('You were home with me all night. The officer believed every word.'); } else { const c = R.rng.int(25, 70); pl.addCash(c); say(`Here's ${R.fmtMoney(c)} from the grocery money. Don't tell me what it's for.`); } } });
      } else if (p.opinion > 40 && p.fam >= 3 && p.spouse < 0 && !p.playerPartner && Math.abs(p.age - 30) < 30) {
        add.push({ label: `Ask ${p.first} out`, fn: () => {
          const odds = 0.3 + p.opinion / 160 + pl.cool / 400 + (h.arch === 'flirt' ? 0.2 : 0) - (pl.bloody > 0.3 ? 0.2 : 0);
          if (R.rng() < odds) { s.love[p.id] = { love: 25, stage: 'dating', last: g.pop.day }; pl.sweetheart = p.id; p.opinion = Math.min(100, p.opinion + 10); say(R.rng.pick(['Pick me up at eight. Wear the good suit.', 'I thought you\'d never ask.', 'Okay. But you\'re buying.'])); g.ui.toast(`You're dating ${p.first}. Take them out to fall for each other.`, 'good'); }
          else say(R.rng.pick(['Ha! Maybe someday.', 'I don\'t date guys like you.', 'Buy me a drink first, big shot.']));
        } });
      }
      // files about this person
      for (const f of s.files) {
        if (f.used) continue;
        if (f.about === p.id && (f.kind === 'affair' || f.kind === 'debt' || f.kind === 'informant')) add.push({ label: f.kind === 'affair' ? `"I know about you and ${g.pop.people[f.other] ? g.pop.people[f.other].first : 'your friend'}."` : f.kind === 'debt' ? '"I hear you\'re in a hole. I could tell people."' : '"I know who you\'ve been talking to downtown."', small: f.proof ? 'Blackmail · you have proof' : 'Blackmail · only hearsay', cls: 'bad', fn: () => V.blackmail(h, f, say) });
        if (f.kind === 'affair' && g.pop.people[f.about] && g.pop.people[f.about].spouse === p.id) add.push({ label: `Tell ${p.first} about the affair`, small: 'Break it wide open', fn: () => V.tellSpouse(h, f, say) });
      }
    }
    if (p && p.playerChild) {
      add.push({ label: `Give ${p.first} an allowance ($10)`, fn: () => { if (!pl.pay(10)) return; p.opinion = Math.min(100, p.opinion + 8); say(p.age < 10 ? 'Thanks, Dad! Comic books!' : p.age < 16 ? 'Thanks. Don\'t tell Mom.' : 'Appreciate it. I\'ll pay you back.'); } });
      if (p.age >= 16 && !h.crew && pl.crew.length < 3) add.push({ label: `"Ride with me, kid."`, fn: () => { g.player.recruit(h); say(R.rng.pick(['Finally! I won\'t let you down.', 'Mom\'s gonna kill us both.'])); } });
    }
    const at = Math.max(0, t.options.length - 1);
    t.options.splice(at, 0, ...add);
    return t;
  };
  // the dealer sells weight, the pawn shop sells blue boxes
  const baseDealer = R.goods.openDealer;
  R.goods.openDealer = function (h) {
    baseDealer.call(this, h);
    const g = G(), ui = g.ui;
    // rebuild the sheet's options with weight added
    const s = document.querySelector('.sheet');
    if (!s) return;
    const btn = document.createElement('button');
    btn.className = 'opt go';
    btn.innerHTML = '▶ Buy weight (wholesale)<small>Ten at a time, cheap. Sell it on the street.</small>';
    btn.addEventListener('click', () => {
      const list = [{ label: 'Back', fn: () => R.goods.openDealer(h) }];
      V.dealerWeight(h, list, (line) => ui.toast(line.replace(/"/g, '')));
      ui.choice(`${h.strangerName || 'Dealer'}: weight`, list);
    });
    const body = s.querySelector('.body') || s;
    body.insertBefore(btn, body.children[1] || null);
  };
  // context: tap a phone line
  const PP = R.Player.prototype, baseCtx = PP.contextAction;
  PP.contextAction = function () {
    const a = baseCtx.call(this);
    if (a || this.inCar || this.room || !this.inv.tools.bluebox) return a;
    const g = this.game, w = g.world, tx = (this.x / TS) | 0, ty = (this.y / TS) | 0;
    for (let yy = ty - 1; yy <= ty + 1; yy++) for (let xx = tx - 1; xx <= tx + 1; xx++) if (w.o(xx, yy) === D.O.PHONE) return { label: 'Tap the payphone', fn: () => V.tap({ x: xx, y: yy }) };
    const b = w.buildingAt(tx, ty - 1) || w.buildingAt(tx, ty + 1) || w.buildingAt(tx - 1, ty) || w.buildingAt(tx + 1, ty);
    if (b && !b.destroyed && b.residents && b.residents.length && (D.btypes[b.type].house)) return { label: 'Tap their phone line', fn: () => V.tap({ b }) };
    return a;
  };
  // inventory: work a corner
  const baseItems = R.goods.items;
  R.goods.items = function () {
    const out = baseItems.call(this);
    for (const it of out) if (it.sec === 'Drugs') it.actions.push(['corner', 'Deal on this corner']);
    if (G().player.inv.tools.bluebox) { const x = out.find((i) => i.key === 'bluebox'); if (x) x.desc = 'Stand by a payphone or a house and press USE to tap the line.'; }
    return out;
  };
  const baseAct = R.goods.act;
  R.goods.act = function (it, a) { if (a === 'corner') { V.startCorner(); return true; } return baseAct.call(this, it, a); };
  D.tools = D.tools || {};
  D.tools.bluebox = { name: 'Blue Box', price: 120 };
  // daily and per-frame
  const JD = R.Jobs.prototype.daily;
  R.Jobs.prototype.daily = function () { JD.call(this); V.dailyAffairs(); V.dailyLove(); };
  V.update = function (dt) { this.updateCorner(dt); };
  V.init = function (g) {
    this.corner = null;
    if (g.law.CRIMES && !g.law.CRIMES.dealing) g.law.CRIMES.dealing = { name: 'Drug Dealing', bounty: 30, lvl: 1 };
  };
})();
