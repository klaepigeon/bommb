// RHAPSODY — interrogation. Anyone tied up, or with their hands up at gunpoint, can be made to
// talk. Everyone has a RESOLVE (the brave, the family men, the dons and the cops have more)
// and you wear it down: ask, bribe, threaten, rough them up, or make it hurt. Hurting works
// fastest, but people in enough pain say anything to make it stop, so some of what they say is
// a lie; and a scream carries. Break them and they talk: where the money is, who they work
// for (evidence on the family, their boss's club on the map), the safe combination at work,
// the secrets you can squeeze somebody with, what the police know. Then let them go, knock
// them out, or finish it.
// Also here: knockouts and kidnapping. Knock someone out (fists, a sap, a bat, or anyone with
// their hands up) and they stay out for a whole day, unless somebody wakes them: you can, and
// a passer-by who finds them will. Anyone out cold goes over your shoulder from the same menu.
'use strict';
(function () {
  const TS = R.TILE, D = R.data;
  const IN = (R.interro = {});
  const G = () => R.game;
  const machine = (h) => h && h.look && (h.look.xeno === 'robot' || h.look.xeno === 'android');
  const name = (h) => (h.person ? G().pop.name(h.person) : h.strangerName || 'them');
  const first = (h) => (h.person ? h.person.first : 'They');

  IN.captive = function (pl) {
    return G().actors.near(pl.x, pl.y, TS * 1.4, (q) => q.kind === 'h' && !q.dead && !q.carried && !q.sunk && !q.hidden && !(q.down > 0) && q.person && (q.tied || q.state === 'surrender'))[0];
  };
  IN.state = function (h) {
    if (h.intr) return h.intr;
    const p = h.person || {};
    let resolve = 25 + ((h.tr && h.tr.brave) || 0.4) * 45;
    if (p.faction && p.faction !== 'law') resolve += 20;
    if (p.isDon) resolve += 45;
    if (h.cop || p.role === 'cop') resolve += 25;
    if (machine(h)) resolve += 20;
    return (h.intr = { resolve: Math.round(resolve), max: Math.round(resolve), fear: 0, pain: 0, broken: false, told: {}, lies: 0, line: '' });
  };

  // ---------------------------------------------------------------- the methods
  const scream = (h) => {
    const g = G(), pl = g.player;
    if (h.gagged) return g.actors.say(h, 'MMMMPH!');
    g.actors.say(h, R.rng.pick(['AAAGH!', 'STOP! PLEASE!', 'HELP ME!', 'OKAY! OKAY!']));
    g.actors.noise(h.x, h.y, TS * 10, 'scream', pl);
    const cop = g.actors.near(h.x, h.y, TS * 9, (q) => q.cop && !q.dead)[0];
    if (cop || R.rng() < 0.25) g.law.crime('torture', h.x, h.y, { victim: h, witness: cop });
  };
  const hurt = (h, n, kind) => {
    const g = G(), pl = g.player;
    R.combat.damage(h, n, pl, kind);
    if (!h.dead && h.hp < 18) { h.down = 25 + R.rng() * 15; h.state = 'down'; return 'out'; }
    return h.dead ? 'dead' : 'ok';
  };
  IN.methods = function (h) {
    const g = G(), pl = g.player, w = D.weapons[pl.weapon] || {}, s = this.state(h), out = [];
    out.push({ id: 'ask', label: 'Ask', small: 'Calmly. Some people just want to be asked.' });
    out.push({ id: 'pay', label: 'Offer money ($100)', small: 'Everyone has a price. Some of them are cheap.' });
    out.push({ id: 'threat', label: w.gun ? 'Put the gun to their head' : w.melee && w.blade ? 'Show them the blade' : 'Threaten them', small: 'Fear works on almost everyone' });
    if (machine(h)) {
      out.push({ id: 'crack', label: 'Crack the casing', small: pl.inv.tools.lockpick ? 'Your bypass kit, into their memory. Loud and messy.' : 'Needs a bypass kit (lockpick)' });
    } else {
      out.push({ id: 'rough', label: 'Rough them up', small: 'Fists. Bruises heal.' });
      const nasty = w.blade ? ['Use the knife', 'They\'ll carry the scars'] : w.gun ? ['Shoot them in the leg', 'They won\'t walk right again'] : pl.inv.tools.gascan ? ['Douse them and show the lighter', 'Terrifying, and it smells'] : ['Break their fingers', 'One at a time'];
      out.push({ id: 'hurt', label: nasty[0], small: nasty[1] + '. Breaks anyone, but people in agony say anything.' });
    }
    return out;
  };
  IN.act = function (h, id) {
    const g = G(), pl = g.player, s = this.state(h);
    const say = (t) => { s.line = t; g.actors.say(h, t.length < 40 ? t : ''); };
    const dmgResolve = (n) => { s.resolve = Math.max(0, s.resolve - n); };
    let res = 'ok';
    switch (id) {
      case 'ask': {
        const soft = (h.tr && h.tr.brave < 0.3) || s.fear > 40;
        dmgResolve(soft ? 12 : 3);
        say(soft ? R.rng.pick(['I... look, I just want to go home.', 'If I tell you, you let me go?']) : R.rng.pick(['Go to hell.', 'I got nothing to say to you.', 'You think I\'m stupid?']));
        break;
      }
      case 'pay': {
        if (!pl.pay(100)) return g.ui.toast('You don\'t have $100.', 'warn');
        const poor = h.person && (h.person.wealth || 50) < 40;
        dmgResolve(poor ? 30 : 12);
        say(poor ? 'A hundred? ...Make it two and we\'re friends.' : 'That\'s it? You insult me.');
        break;
      }
      case 'threat': {
        const w = D.weapons[pl.weapon] || {};
        s.fear = Math.min(100, s.fear + (w.gun ? 30 : w.blade ? 25 : 15));
        dmgResolve(8 + s.fear * 0.1);
        say(R.rng.pick(['Okay, okay, easy!', 'You wouldn\'t.', 'Please, I got kids!', 'Put that away, man!']));
        g.audio.sfx('equip');
        break;
      }
      case 'rough': {
        s.fear = Math.min(100, s.fear + 15); s.pain = Math.min(100, s.pain + 12);
        dmgResolve(15);
        g.audio.sfx('punch', h.x, h.y);
        res = hurt(h, 7, 'melee');
        say(R.rng.pick(['Ugh! Alright!', 'You hit like my mother.', 'Okay! Okay!']));
        pl.rep.honor = (pl.rep.honor || 0) - 1;
        break;
      }
      case 'hurt': {
        const w = D.weapons[pl.weapon] || {};
        s.fear = Math.min(100, s.fear + 25); s.pain = Math.min(100, s.pain + 35);
        dmgResolve(38);
        if (w.gun) { g.audio.sfx(w.silenced ? 'thup' : 'pistol', h.x, h.y); res = hurt(h, 16, 'bullet'); }
        else if (w.blade) { g.audio.sfx('stab', h.x, h.y); res = hurt(h, 14, 'melee'); }
        else res = hurt(h, 12, 'melee');
        scream(h);
        pl.rep.honor = (pl.rep.honor || 0) - 4; pl.rep.infamy = (pl.rep.infamy || 0) + 2;
        pl.cool = Math.max(0, pl.cool - 8);
        break;
      }
      case 'crack': {
        if (!pl.inv.tools.lockpick) return g.ui.toast('You need a bypass kit (lockpick).', 'warn');
        pl.inv.tools.lockpick--;
        dmgResolve(R.rng() < 0.6 ? 100 : 30);
        g.fx.sparks(h.x, h.y - 14, 10); g.audio.sfx('zap', h.x, h.y);
        say(s.resolve <= 0 ? 'MEMORY ACCESS... GRANTED.' : 'ERROR. ERROR. INTRUSION.');
        break;
      }
    }
    if (res === 'out') { g.ui.toast(`${first(h)} passes out. Wait, or come back later.`, 'warn'); g.ui.closeSheet(); return; }
    if (res === 'dead') { g.ui.toast(`${first(h)} is dead. They won't be telling anyone anything.`, 'bad'); g.ui.closeSheet(); return; }
    if (s.resolve <= 0 && !s.broken) { s.broken = true; s.line = R.rng.pick(['Alright! ALRIGHT! What do you want to know?', 'I\'ll talk, I\'ll talk. Just stop.', 'Okay. Okay. Ask me.']); }
    this.open(h);
  };

  // ---------------------------------------------------------------- what they know
  // pain makes liars: past a point, some answers are made up to make it stop
  const lying = (s) => R.rng() < Math.max(0, Math.min(0.45, (s.pain - 55) / 100));
  IN.questions = function (h) {
    const g = G(), p = h.person, s = this.state(h), out = [];
    const V = R.vice, pop = g.pop, home = p && p.home != null ? g.world.buildings[p.home] : null, work = p && p.work != null ? g.world.buildings[p.work] : null;
    if (!s.told.money) out.push({ label: '"Where\'s your money?"', fn: () => {
      s.told.money = true;
      const pocket = Math.round(h.cash || 20 + R.rng() * 60);
      if (pocket > 0) { g.player.addCash(pocket); h.cash = 0; }
      if (home && !lying(s)) { home.stash = (home.stash || 0) + R.rng.int(150, 400); if (V && V.addFile) V.addFile({ kind: 'stash', about: p.id, b: home.id, proof: true, title: `Cash hidden at ${p.last}'s`, text: `${p.first} gave it up: "${R.rng.pick(['Under the floorboards', 'In the freezer, behind the peas', 'Taped under the sink'])}." About ${R.fmtMoney(home.stash)}.` }); R.poi && R.poi.add(home.out.x, home.out.y, 'tip', `${p.last}'s stash`, 'Under the floorboards'); }
      else if (home) { s.lies++; if (V && V.addFile) V.addFile({ kind: 'stash', about: p.id, b: -1, proof: false, title: `Cash hidden at ${p.last}'s?`, text: `${p.first} swore there was money in the house. They were screaming at the time.` }); }
      s.line = `${R.fmtMoney(pocket)} from their pockets. "${home ? 'The rest is at the house, I swear!' : 'That\'s all I got!'}"`;
      this.open(h);
    } });
    if (p && p.faction && p.faction !== 'law' && !s.told.boss) out.push({ label: '"Who do you work for?"', fn: () => {
      s.told.boss = true;
      const fam = p.faction, don = pop.people.find((q) => q.isDon && q.faction === fam && q.alive);
      const club = don && don.work != null ? g.world.buildings[don.work] : null;
      if (club && R.poi) R.poi.add(club.out.x, club.out.y, 'tip', `The ${fam} boss`, `${pop.name(don)} runs things from here`);
      if (!lying(s)) { if (R.campaign && R.campaign.addEvidence) R.campaign.addEvidence(fam, 1, 'A confession'); if (V && V.addFile) V.addFile({ kind: 'deal', about: p.id, fam, proof: true, title: `${fam} business`, text: `${p.first} gave up the ${fam} operation: the shipments, the pickups, who gets paid. The cops or a rival would pay for this.` }); }
      else s.lies++;
      s.line = `"The ${fam}s. ${don ? pop.name(don) + '. ' : ''}${club ? 'He\'s at ' + club.name + ' most nights.' : ''}"`;
      this.open(h);
    } });
    if (work && !s.told.combo) out.push({ label: '"The safe at work. The combination."', fn: () => {
      s.told.combo = true;
      if (!lying(s)) { work.comboKnown = true; if (V && V.addFile) V.addFile({ kind: 'combo', about: -1, b: work.id, proof: true, title: `Safe combination: ${work.name}`, text: `${p.first} recited it twice to be sure. Any safe in ${work.name} opens without a fuss now.` }); s.line = `"It's... it's written on a card in my wallet. ${work.name}."`; }
      else { s.lies++; s.line = `"Four numbers! I don't remember! Seven... seven something!"`; }
      this.open(h);
    } });
    if (p && !s.told.secret) out.push({ label: '"Tell me something I can use."', fn: () => {
      s.told.secret = true;
      let got = '';
      const others = pop.people.filter((q) => q.alive && q.city === p.city && q.id !== p.id && (q.affair != null || q.debt > 0));
      const q = R.rng.pick(others.length ? others : [p]);
      if (q && V && V.addFile && !lying(s)) {
        if (q.affair != null && pop.people[q.affair]) { const lv = pop.people[q.affair]; V.addFile({ kind: 'affair', about: q.id, other: lv.id, proof: false, title: `${pop.name(q)} is cheating`, text: `${p.first} says ${q.first} ${q.last} is seeing ${lv.first} ${lv.last} on the side. Hearsay; a phone tap would make it proof.` }); got = `${q.first} ${q.last} is cheating on their spouse.`; }
        else if (q.debt > 0) { V.addFile({ kind: 'debt', about: q.id, proof: true, title: `${pop.name(q)} owes money`, text: `${q.first} owes ${R.fmtMoney(q.debt)} and can't pay, says ${p.first}.` }); got = `${q.first} ${q.last} is in debt up to the eyeballs.`; }
      }
      if (!got) { s.lies++; got = 'Something about the mayor and a goat. It sounds made up.'; }
      s.line = `"${got}"`;
      this.open(h);
    } });
    if ((h.cop || (p && p.role === 'cop')) && !s.told.police) out.push({ label: '"What do the police have on me?"', fn: () => {
      s.told.police = true;
      const law = g.law, j = law.jurAt(h.x, h.y);
      if (law.bounty && law.bounty[j]) law.bounty[j] = Math.round(law.bounty[j] * 0.5);
      if (R.cases && R.cases.state) for (const c of R.cases.state().list) c.progress = Math.max(0, (c.progress || 0) - 25);
      s.line = '"Not as much as they think. The files... go missing, sometimes." (Bounty halved; open cases set back.)';
      this.open(h);
    } });
    if (R.rat && R.rat.active && R.rat.active() && !s.told.rat) out.push({ label: '"Who\'s talking to the Feds?"', fn: () => {
      s.told.rat = true;
      const r = R.rat.active();
      if (!lying(s) && R.rat.clue) { R.rat.clue(r); R.rat.clue(r); s.line = `"I hear things. Somebody close to you. Real close." (Two clues on the rat.)`; }
      else { s.lies++; s.line = '"The Feds? What Feds?"'; }
      this.open(h);
    } });
    return out;
  };

  // ---------------------------------------------------------------- the sheet
  const bar = (v, max, col) => `<span style="display:inline-block;width:90px;height:8px;background:#2a1a12;vertical-align:middle"><span style="display:block;height:8px;width:${Math.round((90 * Math.max(0, v)) / Math.max(1, max))}px;background:${col}"></span></span>`;
  IN.open = function (h) {
    const g = G(), ui = g.ui, s = this.state(h);
    if (h.dead || h.down > 0) return ui.closeSheet();
    const ask = s.broken ? this.questions(h) : [];
    const opts = s.broken ? ask : this.methods(h).map((m) => ({ label: m.label, small: m.small, fn: () => this.act(h, m.id) }));
    opts.push({ label: 'Knock them out', small: 'Lights out for a good while', fn: () => { this.ko(h); ui.closeSheet(); } });
    opts.push({ label: 'Let them go', small: s.broken ? 'They got what they deserved. Or they talk.' : 'Walk away', fn: () => { this.release(h); ui.closeSheet(); } });
    opts.push({ label: 'Finish it', small: 'No witnesses', cls: 'bad', fn: () => { ui.closeSheet(); R.combat.kill(h, g.player, 'melee'); g.law.crime('murder', h.x, h.y, { victim: h }); } });
    opts.push({ label: 'Step back', fn: () => ui.closeSheet() });
    const meters = `<div style="font-size:12px;line-height:18px;margin:4px 0 8px">RESOLVE ${bar(s.resolve, s.max, '#c8a040')} &nbsp; FEAR ${bar(s.fear, 100, '#a878c8')} &nbsp; PAIN ${bar(s.pain, 100, '#c83a2a')}${s.lies ? ` &nbsp; <b>${s.lies} answer${s.lies > 1 ? 's' : ''} may be lies</b>` : ''}</div>`;
    const line = s.line || (h.tied ? R.rng.pick(['What do you want from me?', 'Let me go, man. Please.']) : 'Easy. Easy, I\'m not armed.');
    const sheet = ui.openSheet('interro', ui.header(`Interrogating ${name(h)}`, s.broken ? 'Broken. They\'ll answer. Ask what you need.' : h.gagged ? 'Gagged: they can\'t scream, but they can\'t talk either. You\'ll take the tape off when you need to.' : 'Wear down their resolve.') + `<div class="body">${meters}<div class="line">"${line.replace(/^"|"$/g, '').replace(/</g, '&lt;')}"</div>${ui.optsHtml(opts)}</div>`);
    ui.bindOpts(sheet, opts);
    if (h.gagged && s.broken) h.gagged = false;
    return sheet;
  };
  IN.ko = function (h) {
    const g = G();
    h.tied = h.tied || false; h.hp = Math.max(1, Math.min(h.hp, 20)); h.state = 'down'; h.hostile = false; h.wasKO = true;
    this.knockOut(h);
    g.fx.text(h.x, h.y - 24, 'K.O.', '#f2e2c0'); g.audio.sfx('ko');
    if (h.witness) h.witness.silenced = true;
  };
  // out for a day (game time), unless someone wakes them
  const DAY = 1440, OUT = 1e6;
  IN.knockOut = function (h) { h.koUntil = G().clock.t + DAY; h.down = OUT; h.keep = true; h.found = 0; };
  IN.wake = function (h, by) {
    const g = G();
    h.koUntil = null; h.keep = false; h.down = 0.01; h.found = 0;
    if (by && by !== g.player) { g.actors.say(by, R.rng.pick(['Hey! Hey, buddy, wake up!', 'Oh my God. Are you okay?', 'Somebody call a doctor!'])); if (h.person && R.rng() < 0.6) g.law.crime('assault', h.x, h.y, { victim: h, witness: by, minor: true }); }
    else if (by === g.player) g.actors.say(h, R.rng.pick(['Wha... where am I?', 'Ugh. My head.', 'What happened?']));
  };
  IN.tick = function (dt) {
    const g = G();
    this.koT = (this.koT || 0) - dt;
    if (this.koT > 0) return;
    this.koT = 1;
    for (const h of g.actors.list) {
      if (h.kind !== 'h' || h.dead || !h.koUntil) continue;
      if (h.carried) continue;
      if (g.clock.t >= h.koUntil) { this.wake(h, null); continue; }
      if (h.tied) continue; // tied up: nobody's untying them by accident
      // passers-by who find someone out cold wake them up (and maybe call it in)
      const by = g.actors.near(h.x, h.y, TS * 2.5, (q) => q.kind === 'h' && q !== h && !q.dead && !(q.down > 0) && !q.hostile && !q.tied && q !== g.player && !q.carried)[0];
      if (by) { h.found = (h.found || 0) + 1; if (h.found >= 4) this.wake(h, by); } else h.found = 0;
    }
  };
  IN.release = function (h) {
    const g = G(), s = this.state(h);
    h.tied = false; h.gagged = false; h.stay = false; h.state = 'idle';
    g.actors.setFlee(h, g.player, 20);
    if (h.person) h.person.opinion = Math.max(-100, (h.person.opinion || 0) - (s.pain > 30 ? 60 : 25));
    if (s.pain > 30 && h.person && R.rng() < 0.5) g.pop.addNews(h.person.city, `A local man was found wandering the streets, badly hurt, saying "they wanted to know things". Police are looking for the attacker.`);
  };

  // ---------------------------------------------------------------- wiring
  IN.init = function (g) {
    if (this.wrapped) return;
    this.wrapped = true;
    const LP = R.Law.prototype;
    if (!LP.CRIMES.torture) LP.CRIMES.torture = { name: 'Torture', bounty: 150, lvl: 2 };
    const PP = R.Player.prototype, ctx = PP.contextAction;
    PP.contextAction = function () {
      const g2 = G(), pl = this;
      if (pl.inCar || pl.room || pl.carrying) return ctx.call(this);
      // kidnapping made simple: anyone out cold goes over your shoulder in one tap
      const out = g2.actors.near(pl.x, pl.y, TS * 1.3, (q) => q.kind === 'h' && !q.dead && q.down > 0 && !q.carried && !q.tied && !q.sunk && !q.hidden)[0];
      if (out) {
        const base = ctx.call(this);
        const opts = [{ label: 'Pick them up', small: 'Over your shoulder', fn: () => R.bodies.pickUp(out) }];
        if (base && /Tie|pocket|Search/i.test(base.label)) opts.push({ label: base.label, fn: base.fn });
        opts.push({ label: 'Wake them up', small: 'A slap and some water', fn: () => IN.wake(out, pl) });
        return { label: 'Out cold', fn: () => g2.ui.choice(name(out), opts.concat([{ label: 'Leave them', fn: () => {} }])) };
      }
      // a captive: tied up, or hands up at gunpoint
      const c = IN.captive(pl);
      if (c) {
        const base = ctx.call(this);
        const opts = [{ label: 'Interrogate', fn: () => IN.open(c) }];
        if (base) opts.push({ label: base.label, fn: base.fn });
        if (c.state === 'surrender' && !c.tied) opts.push({ label: 'Knock them out', fn: () => IN.ko(c) });
        return { label: opts.length === 1 ? 'Interrogate' : name(c), fn: () => (opts.length === 1 ? IN.open(c) : g2.ui.choice(name(c), opts.concat([{ label: 'Leave them', fn: () => {} }]))) };
      }
      return ctx.call(this);
    };
    // a fight's knockout lasts a day now, not half a minute
    const C = R.combat, cd = C.damage;
    C.damage = function (h, amt, source, kind) {
      const wasDown = h && h.down > 0, r = cd.apply(this, arguments);
      if (h && h.kind === 'h' && !h.dead && !wasDown && h.down > 0 && h.state === 'down' && h.hp <= 0) IN.knockOut(h);
      return r;
    };
    const GP = R.Game.prototype, tk = GP.tick;
    GP.tick = function (dt) { const r = tk.apply(this, arguments); if (this.actors && this.clock && !this.ui.paused()) IN.tick(dt); return r; };
    // the unconscious stay out while you carry them (they come round a while after you put them down)
    const B = R.bodies, pd = B.putDown;
    B.putDown = function (x, y) { const a = pd.call(this, x, y); if (a && !a.dead && a.koUntil) a.down = OUT; else if (a && !a.dead && !a.tied) a.down = Math.max(a.down || 0, 20); return a; };
  };
})();
