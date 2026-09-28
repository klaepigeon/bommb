// RHAPSODY — the juice. Lend money to people the banks won't touch: the gambler, the
// widow with the roof, the kid with the car payment. The loan comes back with 10% a week
// on top (the vig), for as long as they carry it. Most people pay. Some can't, and then
// you choose: patience, the fingers, the car in their driveway, or a favour they owe you
// instead. People who are frightened of you sometimes talk to the wrong people.
// Also here: the bookie in the back of every bar, and the race that's already decided.
'use strict';
(function () {
  const TS = R.TILE;
  const G = () => R.game;
  const SH = (R.shark = {});
  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
  const VIG = 0.1;

  SH.street = function () { const pl = G().player; return (pl.street = pl.street || {}); };
  SH.state = function () { const st = this.street(); return (st.book = st.book || { loans: [], lent: 0, juice: 0, broke: 0, fixed: 0 }); };
  SH.open = function () { return this.state().loans.filter((l) => !l.done); };
  SH.loanOf = function (p) { return p && this.open().find((l) => l.pid === p.id); };
  SH.owed = function (l) { return l.principal + l.vig; };

  // ---------------------------------------------------------------- who asks
  SH.canLend = function (h) {
    const p = h.person, pl = G().player;
    if (!p || h.cop || h.detectiveFor || h.storyNpc || h.isDon || p.role === 'don' || p.age < 18 || !p.alive) return false;
    if (this.loanOf(p)) return false;
    if (pl.cash < 100 || (p.opinion || 0) < -30) return false;
    return (p.wealth || 30) < 55 || /gambler|hustler|drunk/.test(p.arch || '');
  };
  SH.need = function (p) {
    const hash = R.hash2(p.id, 17, 3);
    return ['the rent', 'a bookie in Port Hollow', 'the car payment', 'my mother\'s operation', 'the roof', 'a bad night at cards', 'my kid\'s braces', 'a guy named Sal'][Math.floor(hash * 8)];
  };
  SH.offer = function (h) {
    const g = G(), pl = g.player, p = h.person, ui = g.ui;
    const cap = Math.min(pl.cash, 150 + Math.round((60 - Math.min(60, p.wealth || 30)) * 12));
    const sizes = [100, 250, 500, 1000].filter((n) => n <= cap);
    if (!sizes.length) return ui.toast('You don\'t have enough on you to be anybody\'s bank.');
    const keen = (p.wealth || 30) < 30 || /gambler|hustler/.test(p.arch || '');
    ui.choice(`${g.pop.name(p)} needs it for ${this.need(p)}`, sizes.map((n) => ({
      label: `Lend ${R.fmtMoney(n)}`,
      small: `They owe ${R.fmtMoney(Math.round(n * VIG))} a week in juice until they pay it back`,
      fn: () => {
        if (!keen && R.rng() < 0.35 && n > 250) { g.actors.say(h, 'That much? With your interest? No, no. I\'ll figure something out.'); return; }
        if (!pl.pay(n)) return;
        const l = { pid: p.id, name: g.pop.name(p), principal: n, vig: 0, day: g.pop.day, due: g.pop.day + 7, late: 0, paid: 0, broke: 0, done: false, city: p.city };
        this.state().loans.push(l);
        this.state().lent += n;
        p.opinion = Math.min(100, (p.opinion || 0) + 10);
        g.actors.say(h, R.rng.pick(['You\'re a lifesaver. Seven days, I swear.', 'I won\'t forget this. Really.', 'Thank you. Thank you. Don\'t tell my wife.']));
        ui.toast(`Loaned ${R.fmtMoney(n)} to ${l.name}. The juice is ${R.fmtMoney(Math.round(n * VIG))} a week. First payment in 7 days.`, 'good');
      },
    })).concat([{ label: 'Never mind', fn: () => {} }]));
  };

  // ---------------------------------------------------------------- collecting
  // what they can scrape together today
  SH.purse = function (p, l) {
    const w = p.wealth || 30, luck = R.hash2(p.id, G().pop.day, 11);
    return Math.round((w * 9 + 40) * (0.5 + luck) * (l.broke ? 1.4 : 1) * (p.fear > 60 ? 1.3 : 1));
  };
  SH.collect = function (h) {
    const g = G(), pl = g.player, p = h.person, l = this.loanOf(p), ui = g.ui, s = this.state();
    if (!l) return;
    const owed = this.owed(l), weekly = Math.round(l.principal * VIG), purse = this.purse(p, l);
    const opts = [];
    if (purse >= owed) opts.push({ label: `"All of it. ${R.fmtMoney(owed)}."`, small: 'They can cover it today', cls: 'go', fn: () => this.pay(h, l, owed, true) });
    if (purse >= Math.max(weekly, l.vig)) opts.push({ label: `"Just the juice, then. ${R.fmtMoney(Math.max(weekly, l.vig))}."`, small: 'Keeps the loan running. You keep earning', fn: () => this.pay(h, l, Math.max(weekly, l.vig), false) });
    if (purse < Math.max(weekly, l.vig)) {
      opts.push({ label: 'Break a finger', small: `Assault. They'll find the money next time, and they'll never love you`, cls: 'bad', fn: () => this.hurt(h, l) });
      opts.push({ label: 'Take something instead', small: 'The car, the TV, the watch. Clears the debt', fn: () => this.seize(h, l) });
      opts.push({ label: '"Then you owe me a favour."', small: 'Work it off: a tip, a door left open, a fixed race', fn: () => this.favour(h, l) });
    }
    opts.push({ label: 'Give them another week', small: 'Honor +1. The juice keeps adding up', fn: () => { l.due = g.pop.day + 7; pl.rep.honor += 1; g.actors.say(h, 'God bless you. Next week. Swear to God.'); } });
    if (l.principal <= 250 || pl.rep.honor > 40) opts.push({ label: 'Forgive the whole thing', small: 'Honor +3. They\'ll remember', fn: () => { l.done = true; l.forgiven = true; pl.rep.honor += 3; p.opinion = 100; g.actors.say(h, 'I... I don\'t know what to say. Anything you ever need.'); ui.toast(`You tore up ${l.name}'s marker.`, 'good'); } });
    opts.push({ label: 'Walk away', fn: () => {} });
    ui.choice(`${l.name} owes you ${R.fmtMoney(owed)}${l.late ? ` · ${l.late} day${l.late > 1 ? 's' : ''} late` : ''}`, opts);
    s.lastAsk = g.pop.day;
  };
  SH.pay = function (h, l, amt, all) {
    const g = G(), pl = g.player, s = this.state();
    pl.addCash(amt); // dirty
    l.paid += amt;
    if (all) { l.done = true; s.juice += amt - l.principal; g.actors.say(h, 'We\'re square. Don\'t ever lend me money again.'); g.ui.toast(`${l.name} paid in full: ${R.fmtMoney(amt)}.`, 'good'); }
    else { const vig = Math.min(amt, l.vig || amt); l.vig = Math.max(0, l.vig - amt); s.juice += vig; l.due = g.pop.day + 7; l.late = 0; g.actors.say(h, R.rng.pick(['Here. Same time next week, I know.', 'It\'s all I got. It\'s the juice.', 'Take it. I\'m working on the rest.'])); g.ui.toast(`Collected ${R.fmtMoney(amt)} in juice from ${l.name}.`, 'good'); }
    g.audio.sfx('cash');
  };
  SH.hurt = function (h, l) {
    const g = G(), pl = g.player, p = h.person;
    l.broke++; this.state().broke++;
    h.hp = Math.max(1, h.hp - 12);
    if (R.butcher) R.butcher.mark(h, 12, null, 'melee');
    g.audio.sfx('punch');
    g.actors.say(h, R.rng.pick(['AAGH! My hand! Okay! OKAY!', 'Jesus! Friday! You\'ll have it Friday!', 'Please... please, I got kids...']));
    p.fear = Math.min(100, (p.fear || 0) + 50); p.opinion = Math.min(p.opinion || 0, -40);
    pl.rep.infamy += 2; pl.rep.honor = Math.max(0, pl.rep.honor - 2);
    l.due = g.pop.day + 3;
    g.law.crime('assault', h.x, h.y, { victim: h });
    h.state = 'flee';
    if (R.rat) R.rat.pressure(p.id, 3);
  };
  SH.seize = function (h, l) {
    const g = G(), pl = g.player, p = h.person, owed = this.owed(l);
    const what = (p.wealth || 30) > 35 ? R.rng.pick(['the car', 'the color TV', 'the gold watch', 'the hi-fi']) : R.rng.pick(['the wedding ring', 'the TV', 'the fur coat', 'the record collection']);
    const worth = Math.round(owed * (0.7 + R.rng() * 0.5));
    pl.addCash(worth);
    l.done = true; l.seized = what;
    this.state().juice += Math.max(0, worth - l.principal);
    p.opinion = Math.min(p.opinion || 0, -50); p.fear = Math.min(100, (p.fear || 0) + 25);
    pl.rep.infamy += 1;
    g.actors.say(h, `Not ${what}... fine. FINE. Take it.`);
    g.ui.toast(`You took ${what}. Sold for ${R.fmtMoney(worth)}. Debt cleared.`, 'warn');
    if (R.rat) R.rat.pressure(p.id, 2);
  };
  // they owe you something better than money
  SH.favour = function (h, l) {
    const g = G(), p = h.person;
    l.done = true; l.favour = true;
    const kind = R.rng.pick(['truck', 'race', 'race', 'truck', 'mark']);
    if (kind === 'race') { this.state().fixed++; g.actors.say(h, 'My cousin walks horses at the track. Next time you\'re at a bar, bet the long shot. Trust me.'); g.ui.toast('You have a fixed race. The next pony bet at any bar is a sure thing.', 'good'); }
    else if (kind === 'truck' && R.hijack) { g.actors.say(h, 'I drive for the depot. There\'s a load coming through I can tell you about.'); R.hijack.tip(p); }
    else { const pl = g.player; pl.addCash(Math.round(this.owed(l) * 0.8)); g.actors.say(h, 'The guy I work for keeps his cash in a coffee can. I\'ll leave the back door open.'); g.ui.toast(`${l.name} let you into their boss's back room. You found ${R.fmtMoney(Math.round(this.owed(l) * 0.8))}.`, 'good'); }
  };

  // ---------------------------------------------------------------- every morning
  SH.daily = function () {
    const g = G(), pop = g.pop;
    for (const l of this.open()) {
      const p = pop.people[l.pid];
      if (!p || !p.alive) { l.done = true; l.dead = true; continue; }
      if (pop.day >= l.due) {
        // a week's juice rolls onto the tab
        if (pop.day === l.due) { l.vig += Math.round(l.principal * VIG); }
        l.late = pop.day - l.due;
        if (l.late === 1) {
          g.ui.toast(`${l.name} missed a payment. They owe you ${R.fmtMoney(this.owed(l))}.`, 'warn');
          const b = g.world.buildings[p.home];
          if (b && !g.waypoint) g.waypoint = { x: b.out.x * TS + 8, y: b.out.y * TS + 8 };
        }
        if (l.late > 0 && l.late % 7 === 0) l.vig += Math.round(l.principal * VIG);
        // the frightened ones run, or go to the police
        if (l.late > 9 && R.rng() < 0.12) {
          l.done = true; l.skipped = true;
          pop.addNews(p.city, `Neighbours say ${pop.name(p)} left town in the night. "Owed money all over," says one.`);
          g.ui.toast(`${l.name} skipped town owing you ${R.fmtMoney(this.owed(l))}.`, 'bad');
        }
        if (R.rat && l.late > 3) R.rat.pressure(p.id, 1);
      }
    }
  };

  // ---------------------------------------------------------------- the ponies
  const HORSES = ['Midnight Ramble', 'Lucky Lorraine', 'Sgt. Pepperoni', 'Disco Inferno', 'Old Glory', 'Mama\'s Pearls', 'Second Mortgage', 'Tax Refund', 'Blue Suede', 'Rhapsody in Brown', 'Johnny Two-Times', 'Big Ol\' Tuesday'];
  SH.ponies = function (b, opts) {
    const g = G();
    if (b.type !== 'bar' && b.type !== 'club' && b.type !== 'casino') return;
    opts.push({ label: 'The bookie in the back', small: 'Bet on the 4:15 at Hollow Downs', fn: () => this.race() });
  };
  SH.race = function () {
    const g = G(), pl = g.player, ui = g.ui, s = this.state();
    const seed = g.pop.day * 7 + Math.floor(g.clock.hour());
    const field = [0, 1, 2, 3].map((i) => HORSES[Math.floor(R.hash2(seed, i, 5) * HORSES.length)] + (i && HORSES[Math.floor(R.hash2(seed, i, 5) * HORSES.length)] === HORSES[Math.floor(R.hash2(seed, 0, 5) * HORSES.length)] ? ' II' : ''));
    const odds = [2, 3, 5, 12];
    const stake = Math.min(pl.cash, 50 + g.jobs.rank() * 50);
    if (stake < 10) return ui.toast('The bookie doesn\'t take IOUs.');
    ui.choice(`Hollow Downs, 4:15 · ${R.fmtMoney(stake)} a ticket`, field.map((name, i) => ({
      label: `${name} (${odds[i]}–1)`,
      small: i === 3 && s.fixed ? 'Your tip. The fix is in' : ['The favourite', 'Runs well in the wet', 'Hasn\'t won since spring', 'A long shot'][i],
      fn: () => {
        if (!pl.pay(stake)) return;
        const fixed = i === 3 && s.fixed > 0;
        const w = [0.42, 0.28, 0.19, 0.11], r = R.rng();
        let win = 0, acc = 0; for (let k = 0; k < 4; k++) { acc += w[k]; if (r < acc) { win = k; break; } }
        if (s.fixed > 0) { win = 3; s.fixed--; }
        const call = `And down the stretch they come... it's ${field[win]} by a length!`;
        if (win === i) { const pot = stake * (odds[i] + 1); R.money ? R.money.clean(() => pl.addCash(pot)) : pl.addCash(pot); g.audio.sfx('cash'); ui.story('THE 4:15', `${call}\n\nThe bookie counts out ${R.fmtMoney(pot)} with a sour face.${fixed ? ' He knows. He can\'t prove it.' : ''}`); }
        else ui.story('THE 4:15', `${call}\n\nYour ticket goes in the ashtray with the others.`);
      },
    })).concat([{ label: 'Not today', fn: () => {} }]));
  };

  // ---------------------------------------------------------------- the jobs tab
  SH.html = function () {
    const g = G(), s = this.state(), open = this.open();
    if (!open.length && !s.lent) return '';
    let h = `<div class="sect">Your book</div><p><small>Lent ${R.fmtMoney(s.lent)} · juice collected ${R.fmtMoney(Math.round(s.juice))}${s.fixed ? ` · <b>${s.fixed} fixed race${s.fixed > 1 ? 's' : ''}</b> waiting at the bookie` : ''}</small></p>`;
    for (const l of open) {
      const p = g.pop.people[l.pid], b = p && g.world.buildings[p.home];
      h += `<p>• <b>${esc(l.name)}</b> owes <b>${R.fmtMoney(this.owed(l))}</b> ${l.late ? `<span style="color:var(--red)">${l.late} day${l.late > 1 ? 's' : ''} late</span>` : `<small>due day ${l.due + 1}</small>`}${l.broke ? ' · <small>fingers broken</small>' : ''}<br><small>${esc(b ? b.name : '')}${p ? ', ' + esc((g.pop.cityObj(p.city) || {}).name || '') : ''}</small></p>`;
    }
    return h;
  };

  SH.init = function (g) {
    if (this.wrapped) return;
    this.wrapped = true;
    const tree = R.dialog.tree;
    R.dialog.tree = function (h) {
      const t = tree.call(this, h);
      if (!t || !t.options || !h.person) return t;
      const i = Math.max(0, t.options.findIndex((o) => /Goodbye/.test(o.label)));
      if (SH.loanOf(h.person)) t.options.splice(i, 0, { label: `"About the money you owe me..."`, small: `${R.fmtMoney(SH.owed(SH.loanOf(h.person)))} on the tab`, cls: 'go', fn: () => SH.collect(h) });
      else if (SH.canLend(h)) t.options.splice(i, 0, { label: '"Short on cash? I can help with that."', small: 'Loan shark: 10% a week', fn: () => SH.offer(h) });
      return t;
    };
    const U = R.UI.prototype, io = U.interiorOptions;
    U.interiorOptions = function (b) { const o = io.call(this, b); SH.ponies(b, o); return o; };
    const J = R.Jobs.prototype, jd = J.daily;
    J.daily = function () { jd.call(this); SH.daily(); };
    const cj = R.campaign.jobsHtml;
    R.campaign.jobsHtml = function () { return cj.call(this) + SH.html(); };
  };
})();
