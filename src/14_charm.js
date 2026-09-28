// RHAPSODY — who you are comes out of your mouth. A decent man says "evening, ma'am"; a
// thug says something that would make his mother cry, and cusses when he fights. People
// read your reputation: the pious warm to an honourable man, hustlers and hard cases
// respect a dangerous one, the timid cross the street. And there's a third button now,
// between Greet and Antagonize: Flirt, which becomes Seduce once they like you enough.
'use strict';
(function () {
  const D = R.data, TS = R.TILE;
  const G = () => R.game;
  const CH = (R.charm = {});
  const pick = (a) => a[Math.floor(R.rng() * a.length)];
  const clean = () => G().settings.clean;

  CH.tier = function () { const r = G().player.rep; return r.honor >= 60 && r.infamy < 40 ? 'saint' : r.honor < 35 || r.infamy > 50 ? 'thug' : 'gent'; };
  const LINES = {
    greet: {
      saint: ['Good evening.', 'God bless, friend.', 'Anything I can do for you?', 'Beautiful day, ain\'t it?', 'Evenin\', ma\'am. Sir.', 'You take care now.'],
      gent: ['How ya doin\'?', 'Evenin\'.', 'Nice day, huh?', 'Hey there.', 'How\'s it going, friend?', 'Looking good.'],
      thug: ['Hey. Yeah, you.', 'What\'s shakin\'?', 'Evenin\'. Don\'t get any ideas.', 'You look like you owe somebody money.', 'Heh. Relax. I\'m bein\' friendly.'],
      salty: ['How the hell are ya?', 'Hey, dumbass. Kidding. Mostly.', 'Look at this sorry bastard. How ya doin\'?', 'Evenin\'. Don\'t fuck it up.', 'Nice day. Shame about your face.'],
    },
    antag: {
      saint: ['You oughta be ashamed.', 'Watch your manners, friend.', 'Grow up.', 'Your mother raised you better.'],
      gent: ['What are you lookin\' at?', 'Nice shoes. Your mother pick \'em?', 'You got a problem?', 'Get outta my way.', 'You smell like a fish market.'],
      thug: ['Outta my way, meatball.', 'Keep lookin\' and I\'ll give you something to look at.', 'You\'re in my light, sweetheart.', 'Beat it before I beat you.'],
      salty: ['What the fuck are you lookin\' at?', 'Get outta my face, asshole.', 'Your mother know you dress like that, dipshit?', 'Keep walkin\', you piece of shit.', 'I\'ll break your fuckin\' jaw.', 'Move, jackass.'],
    },
    hurt: {
      clean: ['Argh!', 'Ooh, that smarts!', 'Oof!', 'You\'ll pay for that!'],
      salty: ['Son of a bitch!', 'Fuck!', 'Goddammit!', 'Ow, you bastard!', 'Shit, shit, shit!', 'That\'s gonna cost you, asshole!'],
    },
    kill: {
      clean: ['Nothing personal.', 'Sleep tight.', 'Should\'ve stayed home.'],
      salty: ['Stay down, motherfucker.', 'Eat shit.', 'Fuck around, find out.', 'Rot in hell.', 'Stupid bastard.'],
    },
    flirt: {
      saint: ['Pardon me, but you\'ve got the loveliest smile on this street.', 'I don\'t usually do this... can I buy you a coffee?', 'You make this whole town look good.'],
      gent: ['Is it hot out here, or is it just you?', 'You come here often, or am I just lucky tonight?', 'Nice outfit. It\'d look better on my arm.', 'I\'d tell you a joke, but I\'d rather hear you laugh.'],
      thug: ['Hey, gorgeous. Lose the zero you\'re with.', 'You and me. Tonight. Think about it.', 'I got a car and a roll of cash. You got plans?'],
      salty: ['Damn, you\'re a goddamn knockout.', 'Hell of a view from here, sweetheart.', 'You and me, tonight. Say yes before I lose my nerve, dammit.'],
    },
    seduce: {
      saint: ['I\'d love to see you again. Maybe somewhere quieter?', 'Walk with me a while?'],
      gent: ['What do you say we get out of here?', 'I know a place with a good record player and better whiskey.'],
      thug: ['My place. Now. You won\'t regret it.', 'Let\'s go somewhere I can show you a good time.'],
      salty: ['Let\'s get the hell outta here, just you and me.', 'Screw the party. My place.'],
    },
  };
  const tierLine = (kind) => { const t = CH.tier(); if (t === 'thug' && !clean() && R.rng() < 0.7) return pick(LINES[kind].salty); return pick(LINES[kind][t]); };
  const barkLine = (kind) => { const t = CH.tier(); return pick(LINES[kind][!clean() && (t === 'thug' || R.rng() < 0.35) ? 'salty' : 'clean']); };

  // ---------------------------------------------------------------- who likes what
  CH.likes = function (h) {
    const seed = h.person ? h.person.seed || h.person.id : (h.look && h.look.seedStr ? h.look.seedStr.length * 31 : (h.x | 0));
    const r = R.hash2(seed | 0, 7, 99);
    const fem = !!h.look.fem;
    return 'both'; // everybody on the Brass Coast swings both ways
  };
  CH.attracted = function (h) {
    const pl = G().player, want = this.likes(h);
    return want === 'both' || want === !!pl.look.fem;
  };
  CH.canFlirt = function (h) {
    return h && !h.dead && h.kind === 'h' && !h.cop && !h.look.kid && !(h.person && h.person.isDon) && !h.storyNpc && !h.detectiveFor && !(h.person && h.person.age < 18) && !(h.person && h.person.playerChild) && h.state !== 'fight' && !(h.witness && !h.witness.done && !h.witness.silenced);
  };
  CH.chipLabel = function (h) { return (h.flirted || 0) >= 2 || (h.person && h.person.opinion > 55) ? 'Seduce' : 'Flirt'; };
  const ARCH = { flirt: 0.35, friendly: 0.1, eccentric: 0.05, gossip: 0.05, hustler: 0.05, tough: 0, square: -0.05, timid: -0.12, grumpy: -0.2, pious: -0.3 };
  // everyone has a type: seeded tastes in morals, reputation, clothes, hair and mob ties
  const HAIRS = ['short', 'shag', 'long', 'afro', 'spiky', 'bald', 'ponytail', 'bun'], FACIAL = ['clean', 'stache', 'beard'];
  CH.taste = function (h) {
    if (h._taste) return h._taste;
    const seed = h.person ? (h.person.seed || h.person.id * 7919) : ((h.look && h.look.seedStr ? h.look.seedStr.split('').reduce((a, c) => (a * 31 + c.charCodeAt(0)) | 0, 7) : h.x * 13 + h.y) | 0);
    const r = R.mulberry(Math.abs(seed) + 12345);
    const t = {
      morals: r() < 0.35 ? 'saint' : r() < 0.55 ? 'thug' : null, // likes good boys, bad boys, or doesn't care
      danger: r() < 0.3 ? 1 : r() < 0.55 ? -1 : 0, // a reputation turns them on, or off
      fancy: r() < 0.4 ? 1 : r() < 0.6 ? -1 : 0, // loves a sharp suit, or hates a peacock
      hairLove: HAIRS[(r() * HAIRS.length) | 0], hairHate: HAIRS[(r() * HAIRS.length) | 0],
      faceLove: FACIAL[(r() * 3) | 0], faceHate: FACIAL[(r() * 3) | 0],
      mob: r() < 0.3 ? 1 : r() < 0.55 ? -1 : 0, // wiseguys: yes please, or absolutely not
    };
    if (t.hairHate === t.hairLove) t.hairHate = null;
    if (t.faceHate === t.faceLove) t.faceHate = null;
    return (h._taste = t);
  };
  // how much they're drawn to you, and the thing they'd say about it
  CH.appeal = function (h) {
    const g = G(), pl = g.player, t = this.taste(h), st = pl.style, rep = pl.rep, tier = this.tier(), notes = [];
    let a = 0;
    const add = (v, line) => { a += v; if (line) notes.push([v, line]); };
    if (t.morals && tier === t.morals) add(0.2, t.morals === 'saint' ? 'I like a gentleman.' : 'I like a man with a little danger in him.');
    else if (t.morals && tier !== 'gent') add(-0.2, t.morals === 'saint' ? 'I heard what kind of man you are.' : 'You\'re a little too clean-cut for me.');
    if (t.danger) add(t.danger * (rep.infamy - 30) / 150, t.danger > 0 && rep.infamy > 50 ? 'I know who you are. That\'s kind of exciting.' : t.danger < 0 && rep.infamy > 50 ? 'I\'ve read about you in the papers. No thanks.' : null);
    const fancy = pl.outfitScore ? pl.outfitScore() : 0;
    if (t.fancy) add(t.fancy * (fancy - 3) / 18, t.fancy > 0 && fancy > 6 ? 'Sharp suit.' : t.fancy < 0 && fancy > 6 ? 'Bit of a peacock, aren\'t you?' : null);
    if (st.hair === t.hairLove) add(0.15, 'Love the hair.'); else if (st.hair === t.hairHate) add(-0.2, `Lose the ${st.hair === 'bald' ? 'chrome dome' : st.hair}, then we'll talk.`);
    if (st.facial === t.faceLove && st.facial !== 'clean') add(0.12, st.facial === 'beard' ? 'I like a beard.' : 'Nice moustache.');
    else if (st.facial === t.faceHate) add(-0.15, st.facial === 'clean' ? 'Grow some whiskers, baby face.' : 'That thing on your lip has to go.');
    const theirs = h.faction || g.jobs.cityFamily(h);
    if (h.person && (h.person.role === 'cop' || h.person.role === 'detective')) add(pl.family ? -0.3 : 0, pl.family ? 'I don\'t date wiseguys.' : null);
    else if (pl.family && theirs) { const sd = g.jobs.familyStanding(theirs); if (theirs === pl.family) add(0.12, 'Any friend of the family.'); else if (sd < -20) add(-0.3, `You're with the ${pl.family}s? My people would kill me.`); }
    if (t.mob && pl.family) add(t.mob * 0.12, t.mob > 0 ? 'Is it true what they say about you boys?' : 'Mob guys are nothing but trouble.');
    if (pl.masked) add(-0.35, 'Take the mask off, weirdo.');
    if (pl.bloody > 0.3) add(-0.3, 'Is that... blood?');
    return { a, notes };
  };
  CH.odds = function (h) {
    const pl = G().player, p = h.person;
    let o = 0.25 + R.dialog.mood(h) / 180 + (ARCH[h.arch] || 0) + pl.cool / 400 + this.appeal(h).a;
    if (p && p.spouse >= 0) o -= 0.25;
    return R.clamp(o, 0.02, 0.95);
  };
  CH.remark = function (h, good) {
    const n = this.appeal(h).notes.filter((x) => (good ? x[0] > 0 : x[0] < 0));
    return n.length ? n.sort((a, b) => Math.abs(b[0]) - Math.abs(a[0]))[0][1] : null;
  };
  CH.flirt = function (h) {
    const g = G(), pl = g.player, p = h.person;
    if (!this.canFlirt(h)) return;
    const seduce = this.chipLabel(h) === 'Seduce';
    g.actors.say(pl, tierLine(seduce ? 'seduce' : 'flirt'));
    h.state = 'talk'; h.timer = 5;
    const ok = R.rng() < this.odds(h) * (seduce ? 0.85 : 1);
    setTimeout(() => {
      if (h.dead || h.removed) return;
      if (!ok) {
        const why = CH.remark(h, false);
        g.actors.say(h, why && R.rng() < 0.75 ? why : p && p.spouse >= 0 ? pick(['I\'m married, you creep.', 'My husband\'s the jealous type.', 'Put a ring on it? Somebody already did.']) : pick(clean() ? ['In your dreams.', 'Pig.', 'Keep walking, Casanova.', 'Does that line ever work?'] : ['In your dreams, creep.', 'Pig.', 'Get lost, you sleaze.', 'Does that shit ever work?']));
        if (R.rng() < 0.25 && h.arch !== 'timid') { g.fx.text(h.x, h.y - 26, 'SLAP!', '#ff8a80'); g.audio.sfx('punch', pl.x, pl.y); pl.cool = Math.max(0, pl.cool - 15); }
        if (p) p.opinion = Math.max(-100, p.opinion - 4);
        h.flirted = Math.max(0, (h.flirted || 0) - 1);
        return;
      }
      h.flirted = (h.flirted || 0) + 1;
      if (p) p.opinion = Math.min(100, p.opinion + 8);
      pl.cool = Math.min(100, pl.cool + 10);
      if (!seduce) { const why = CH.remark(h, true); if (why && R.rng() < 0.6) { g.actors.say(h, why); g.fx.text(h.x, h.y - 28, '♥', '#ff6a8a'); return; } g.actors.say(h, pick(['Well, aren\'t you smooth.', 'Ha! You\'re trouble, aren\'t you?', 'Keep talking, handsome.', 'Maybe I\'ll let you buy me a drink.', 'Oh, stop. No, keep going.'])); g.fx.text(h.x, h.y - 28, '♥', '#ff6a8a'); return; }
      // seduced
      g.actors.say(h, pick(['Lead the way.', 'I thought you\'d never ask.', 'Your place. Before I change my mind.']));
      g.fx.text(h.x, h.y - 28, '♥♥', '#ff6a8a');
      const V = R.vice;
      if (p && V) {
        const s = V.state();
        if (!s.love[p.id]) s.love[p.id] = { love: 35, stage: 'dating', last: g.pop.day };
        if (p.spouse >= 0) { const sp = g.pop.people[p.spouse]; if (sp) V.addFile({ kind: 'affair', about: p.id, other: -1, text: `${p.first} ${p.last} is stepping out on ${sp.first}. With you.` }); }
        if (V.hasPlace()) setTimeout(() => V.bringHome(p), 500);
        else g.ui.toast(`${p.first} writes a number on your hand. "Get a place with a door that locks." (Talk to ${p.first} to take them out.)`, 'good');
      } else {
        if (V && V.hasPlace()) { g.clock.skip(60 * 5); pl.cool = 100; g.ui.story('Later that night...', 'A stranger, a borrowed record, and a door that locks.\n\nIn the morning there\'s a lipstick note on the mirror and no name.'); g.actors.remove(h); }
        else g.ui.toast('"Your place or mine?" You don\'t have a place. The moment passes.', 'warn');
      }
    }, 700);
  };

  // ---------------------------------------------------------------- wiring
  CH.init = function (g) {
    if (this.wrapped) return;
    this.wrapped = true;
    const D2 = R.dialog, greet = D2.greet, antag = D2.antagonize, mood = D2.mood;
    D2.greet = function (h) { const r = greet.call(this, h); G().actors.say(G().player, tierLine('greet')); return r; };
    D2.antagonize = function (h) { const r = antag.call(this, h); G().actors.say(G().player, tierLine('antag')); return r; };
    // your reputation colours how people take you
    D2.mood = function (h) {
      let m = mood.call(this, h);
      const pl = G().player, hon = pl.rep.honor, inf = pl.rep.infamy;
      m += (hon - 50) * (h.arch === 'pious' ? 0.6 : h.arch === 'square' ? 0.4 : 0.2);
      if (h.arch === 'tough' || h.arch === 'hustler') m += inf * 0.2;
      else if (h.arch === 'timid' || h.arch === 'pious') m -= inf * 0.3;
      else m -= inf * 0.1;
      return m;
    };
    // the player talks while he fights
    const PP = R.Player.prototype, hurt = PP.hurt;
    PP.hurt = function (amt, src, kind) { const hp0 = this.hp; const r = hurt.call(this, amt, src, kind); if (this.hp < hp0 && amt >= 6 && (this.barkT || 0) < G().clock.real && R.rng() < 0.4) { this.barkT = G().clock.real + 4; G().actors.say(this, barkLine('hurt')); } return r; };
    R.bus && R.bus.on && (CH.onKill = CH.onKill || ((h, by) => { const pl = G().player; if (by && h.kind === 'h' && (pl.barkT || 0) < G().clock.real && R.rng() < 0.35) { pl.barkT = G().clock.real + 5; G().actors.say(pl, barkLine('kill')); } }));
    const ls = R.bus.map.get('actor:died');
    if (!ls || !ls.includes(CH.onKill)) R.bus.on('actor:died', CH.onKill);
    // the Flirt button
    const U = R.UI.prototype, uc = U.updateCtx;
    U.updateCtx = function () {
      uc.call(this);
      const pl = G().player, h = pl.focus, ctx = this.el.ctx;
      if (!h || ctx.classList.contains('off') || !CH.canFlirt(h)) return;
      const wrap = ctx.querySelector('.chips'), label = CH.chipLabel(h);
      let b = wrap.querySelector('.c-flirt');
      if (b && b.dataset.for === String(h.id) && b.textContent === label) return;
      if (b) b.remove();
      b = document.createElement('button');
      b.className = 'chip c-flirt'; b.textContent = label; b.dataset.for = String(h.id);
      b.addEventListener('pointerdown', (e) => { e.preventDefault(); e.stopPropagation(); G().audio.unlock(); const t = G().player.focus; if (t && !t.dead) CH.flirt(t); this.lastCtxKey = ''; });
      const antagBtn = wrap.querySelector('.c-antag');
      wrap.insertBefore(b, antagBtn ? antagBtn.nextSibling : null);
    };
  };
  // keep the kill bark registered across new games
  CH.reinit = function () { const ls = R.bus.map.get('actor:died'); if (CH.onKill && (!ls || !ls.includes(CH.onKill))) R.bus.on('actor:died', CH.onKill); };
})();
