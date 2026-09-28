// RHAPSODY — people worth knowing. Five memorable townsfolk, one per city, each with a
// three-act story told through the saga mission engine and a reward that changes how
// the coast treats you. And everyone else gets a quirk: something they always talk about,
// and eyes for the state you're in.
'use strict';
(function () {
  const D = R.data, TS = R.TILE;
  const G = () => R.game;
  const ST = (R.stories = {});

  // ---------------------------------------------------------------- the five
  const PEOPLE = {
    callahan: { name: 'Father Callahan', city: 'Vane', where: ['church'], hours: [7, 21], perk: 'sanctuary',
      look: { skin: ['#6a4030', '#a06a50', '#d8a078', '#f0c8a0'], style: 'bald', jacket: ['#08080e', '#14141e', '#22222e', '#34344a'], top: 'collar', shirt: ['#d8d8d8', '#e8e8e8', '#f4f4f4', '#ffffff'], pants: ['#08080e', '#14141e', '#22222e', '#34344a'], glasses: true },
      intro: ['I hear confessions from half this town. You\'d be amazed who kneels in my booth, son.', 'God forgives. The Vanes, less so. Mind yourself.', 'Sit a while. The pews don\'t judge.'],
      perkText: 'Sanctuary: duck into any church and sit in the pews while the cops search for you, and Father Callahan\'s friends make the search go away.',
      saga: { title: 'The Poor Box', acts: [
        { title: 'Thieves in the Nave', brief: 'Someone\'s been robbing the poor box, and last night they came back with friends and crowbars. Father Callahan won\'t call the police. He\'s calling you.', steps: [{ k: 'squad', at: 'church', enemy: null, n: 3, text: 'Run the poor-box thieves off the church steps.' }, { k: 'grab', at: 'church', item: 'the poor box', text: 'Bring back the poor box.' }], cash: 150, rep: 0 },
        { title: 'A Lost Sheep', brief: 'His nephew Danny is into a loan shark for more than he\'s worth and hiding out past the edge of town. The shark\'s men are looking for him.', steps: [{ k: 'talk', at: 'out:12', npc: 'Danny Callahan', say: 'Uncle sent you? I owe the Deacon three grand. His guys said they\'d take it out of my knees. I\'m not going back.', choices: [['"Stay behind me."', null]], text: 'Find Danny outside town.' }, { k: 'defend', at: 'out:12', enemy: null, waves: 2, per: 20, n: 3, dur: 50, vip: 'Danny Callahan', reuseVip: true, text: 'Keep Danny alive.' }], cash: 250, rep: 0 },
        { title: 'Confession', brief: 'The loan shark they call the Deacon runs his book out of a warehouse by the docks. Father Callahan asks you to make it stop. How is up to you.', steps: [{ k: 'kill', at: 'warehouse', name: 'The Deacon', hp: 180, guards: 3, enemy: null, spare: 'The Deacon tears up Danny\'s marker and leaves town before dawn.', text: 'Deal with the Deacon.' }], cash: 400, rep: 0, perk: 'sanctuary' },
      ] } },
    vera: { name: 'Velvet Vera', city: 'Castellano', where: ['club', 'casino'], hours: [18, 30], perk: 'vera',
      look: { skin: ['#4a2a1a', '#7a4a2e', '#a86a44', '#d09060'], style: 'afro', shirt: ['#6a0a4a', '#a0186a', '#d8309a', '#ff70c8'], pants: ['#6a0a4a', '#a0186a', '#d8309a', '#ff70c8'], dress: true },
      intro: ['Honey, the night doesn\'t start till I walk in.', 'You dance? Everybody dances. Even hoods.', 'I hear everything under the mirror ball. Everything.'],
      perkText: 'Vera\'s favour: walk into any club or casino and your Cool fills to the top, and every morning she whispers you a lead.',
      saga: { title: 'Saturday Night', acts: [
        { title: 'The Creep', brief: 'A man in a brown suit has followed Vera home four nights running. The cops laughed at her. You won\'t.', steps: [{ k: 'kill', at: 'club', name: 'Vinnie the Creep', hp: 90, guards: 0, enemy: null, spare: 'Vinnie swears on his mother he\'s moving to Ohio.', text: 'Deal with Vinnie the Creep.' }], cash: 150, rep: 0 },
        { title: 'The Master Tapes', brief: 'A record man stole the tapes of her first album and is sitting on them in a warehouse with some hired muscle.', steps: [{ k: 'squad', at: 'warehouse', enemy: 'Castellano', n: 4, text: 'Clear the record man\'s muscle.' }, { k: 'grab', at: 'warehouse', item: 'the master tapes', text: 'Take back Vera\'s tapes.' }], cash: 300, rep: 0 },
        { title: 'Opening Night', brief: 'Her record drops tonight and the man she took it from wants her to not make it to the stage.', steps: [{ k: 'defend', at: 'club', enemy: null, waves: 3, per: 22, n: 3, dur: 75, vip: 'Velvet Vera', text: 'Get Vera to the stage alive.' }], cash: 500, rep: 0, perk: 'vera' },
      ] } },
    hale: { name: 'Sheriff Buck Hale', city: 'Reyes', where: ['police'], hours: [8, 20], perk: 'hale',
      look: { skin: ['#6a3a20', '#9a5a34', '#c88050', '#e8a878'], style: 'cap', cap: ['#3a2410', '#5a3a1c', '#7c5228', '#a06c38'], stache: true, shirt: ['#6a5a3a', '#8a7a4a', '#b0a06a', '#d8c890'], pants: ['#3a3a2a', '#5a5a3a', '#7a7a4a', '#9a9a6a'] },
      intro: ['This is my county, son. I just rent it to the Reyes family.', 'Election\'s in a week. You a registered voter? Doesn\'t matter.', 'I\'ve got a jail cell with your name on it. Or a job. Your pick.'],
      perkText: 'The Sheriff\'s thanks: any bounty put on you in Dustwater is cut in half.',
      saga: { title: 'Election Year', acts: [
        { title: 'Ballot Run', brief: 'A van full of pre-marked ballots needs to get to Pinecrest before the count. Hale can\'t be seen driving it.', steps: [{ k: 'drive', from: 'police', to: "O'Malley:general", model: 'van', text: 'Run the ballot van to Pinecrest.' }], cash: 250, rep: 0 },
        { title: 'The Other Candidate', brief: 'Hale\'s opponent has hired a bruiser called Big Earl to watch the polling station. Hale would like Earl to take a long vacation.', steps: [{ k: 'kill', at: 'out:16', name: 'Big Earl', hp: 220, guards: 3, enemy: null, spare: 'Big Earl decides he never liked politics.', text: 'Take care of Big Earl.' }], cash: 350, rep: 0 },
        { title: 'Recount', brief: 'Somebody demanded a recount. The ballot box is in the bank vault... no, it\'s in the back of the courthouse, guarded by the other side.', steps: [{ k: 'squad', at: 'bank', enemy: null, n: 3, text: 'Clear the courthouse guards.' }, { k: 'grab', at: 'bank', item: 'the ballot box', text: 'Take the ballot box.' }], cash: 500, rep: 0, perk: 'hale' },
      ] } },
    doc: { name: 'Doc Marlowe', city: "O'Malley", where: ['hospital', 'pharmacy', 'general'], hours: [7, 22], perk: 'doc', hair: '#c8c8c8',
      look: { skin: ['#6a4a3a', '#9a7058', '#c89a78', '#ecc8a8'], style: 'short', jacket: ['#b8b8b8', '#d8d8d8', '#ececec', '#ffffff'], shirt: ['#3a4a6a', '#4a5a8a', '#5a6aa0', '#7a8ac0'], pants: ['#3a3a3a', '#4a4a4a', '#5a5a5a', '#7a7a7a'], glasses: true },
      intro: ['I\'ve stitched up more bullet holes than a battlefield surgeon. This is a lumber town.', 'Keep pressure on it. No, the other hand.', 'I don\'t ask how you got hurt. I just bill for it.'],
      perkText: 'Doc\'s care: +10 max health for good, and any hospital patches you up free.',
      saga: { title: 'House Calls', acts: [
        { title: 'Snowbound', brief: 'A whole family in Bayou Clair has the fever and the medicine is sitting in Doc\'s back room. The roads are bad and the Doc is old.', steps: [{ k: 'drive', from: 'hospital', to: 'Thibodeaux:hospital', model: 'wagon', text: 'Drive the medicine to Bayou Clair.' }], cash: 200, rep: 0 },
        { title: 'Bikers', brief: 'A motorcycle gang wants Doc\'s morphine and they\'re not asking twice.', steps: [{ k: 'defend', at: 'hospital', enemy: null, waves: 3, per: 20, n: 3, dur: 70, vip: 'Doc Marlowe', text: 'Protect Doc Marlowe.' }], cash: 350, rep: 0 },
        { title: 'The Cure', brief: 'There\'s a root that grows only in the deep woods north of town. Poachers have been ripping it up to sell. Doc needs some before they get it all.', steps: [{ k: 'squad', at: 'out:18', enemy: null, n: 3, text: 'Run off the root poachers.' }, { k: 'grab', at: 'out:18', item: 'the rare root', text: 'Dig up the root.' }], cash: 400, rep: 0, perk: 'doc' },
      ] } },
    zelie: { name: 'Madame Zelie', city: 'Thibodeaux', where: ['bar', 'general', 'church'], hours: [17, 28], perk: 'zelie', hair: '#1c1c1c',
      look: { skin: ['#3a2010', '#5a3420', '#7a4a30', '#9a6444'], style: 'long', shirt: ['#3a1a5a', '#5a2a8a', '#7a3ab0', '#a060d8'], pants: ['#3a1a5a', '#5a2a8a', '#7a3ab0', '#a060d8'], dress: true },
      intro: ['The cards told me you\'d come. They also told me you\'d be late.', 'Cross my palm, cher. Silver, not paper.', 'Something follows you. Many somethings. Most of them are cops.'],
      perkText: 'Zelie\'s reading: every morning the cards point you to a stash, marked on your map.',
      saga: { title: 'The Rougarou', acts: [
        { title: 'Something in the Marsh', brief: 'Three fishermen dead in a month, and the marsh folk swear a wolf-man walks the bayou at night. Zelie says it\'s a man in a wolf pelt, and the man is very real.', steps: [{ k: 'kill', at: 'out:14', name: 'The Rougarou', hp: 300, guards: 2, enemy: null, weapon: 'knife', text: 'Hunt the Rougarou.' }], cash: 250, rep: 0 },
        { title: 'The Stolen Deck', brief: 'Her grandmother\'s tarot deck was taken by a card sharp who thinks it\'s lucky. He\'s holding a game, and holding muscle.', steps: [{ k: 'squad', at: 'bar', enemy: null, n: 3, text: 'Break up the card game.' }, { k: 'grab', at: 'bar', item: 'the tarot deck', text: 'Take back the deck.' }], cash: 300, rep: 0 },
        { title: 'The Reading', brief: 'With the deck back, Zelie wants to read for a widow whose husband never came home. She wants you there, for the truth.', steps: [{ k: 'talk', at: 'church', npc: 'Widow Boudreaux', say: 'She says my Remy isn\'t dead. That he ran off with the money and a waitress in Dustwater. Is it true?', choices: [['"It\'s true. He\'s alive."', 'truth', 'She laughs and cries at once, and swears she\'ll find him.'], ['"He loved you. He\'s gone."', 'mercy', 'She squeezes your hand. Some lies are kindness.']], text: 'Sit in on the reading.' }], cash: 400, rep: 0, perk: 'zelie' },
      ] } },
  };
  ST.PEOPLE = PEOPLE;
  // register the stories with the saga engine
  const C = R.campaign;
  const cityOfFam = (fam) => G().jobs.cityOfFamily(fam);
  const place = (fam, spec) => {
    if (spec.startsWith('out:')) return C.outskirts(fam, +spec.slice(4));
    const [f2, t2] = spec.includes(':') ? spec.split(':') : [fam, spec];
    return C.atB(f2, [t2, 'general', 'bar']);
  };
  for (const id in PEOPLE) {
    const P = PEOPLE[id];
    const acts = P.saga.acts.map((a) => ({ ...a, steps: a.steps.map((s) => ({ ...s, at: s.at ? place(P.city, s.at) : undefined, from: s.from ? place(P.city, s.from) : undefined, to: s.to ? place(P.city, s.to) : undefined })) }));
    C.SAGAS['story:' + id] = { title: P.saga.title, story: true, who: P.name, perk: P.perkText, acts };
  }

  // ---------------------------------------------------------------- the people themselves
  ST.spots = {};
  ST.update = function (dt) {
    const g = G(), pl = g.player;
    this.t = (this.t || 0) - dt;
    if (this.t > 0) return;
    this.t = 1.5;
    const hr = g.clock.hour();
    for (const id in PEOPLE) {
      const P = PEOPLE[id];
      let h = this.spots[id];
      if (h && (h.dead || h.removed || !g.actors.list.includes(h))) { if (h.dead) { const s = C.state(); s.storyDead = s.storyDead || {}; s.storyDead[id] = 1; } this.spots[id] = h = null; }
      const s = C.state();
      if (s.storyDead && s.storyDead[id]) continue;
      const c = cityOfFam(P.city);
      if (!c) continue;
      const b = c.buildings.find((x) => x && !x.destroyed && P.where.includes(x.type));
      if (!b) continue;
      const on = (hr >= P.hours[0] && hr < P.hours[1]) || (P.hours[1] > 24 && hr < P.hours[1] - 24);
      const d = Math.hypot(pl.x / TS - b.out.x, pl.y / TS - b.out.y);
      if (!h && on && d < 28 && !pl.room) {
        const sp = g.world.findNear(b.out.x + 1, b.out.y + 1, 0, 4, (x, y) => !g.world.solidPed(x, y) && !g.world.isWater(x, y));
        if (!sp) continue;
        h = g.actors.makeHuman(sp.x * TS + 8, sp.y * TS + 8, { arch: 'eccentric', cash: 0, look: { fem: !!P.look.dress, age: 45, skin: P.look.skin[2], hair: P.hair || '#303030', top: '#555', bottom: '#333', seedStr: 'story_' + id, oldOverride: P.look } });
        h.keep = true; h.stay = true; h.state = 'idle'; h.timer = 1e9; h.storyNpc = id; h.strangerName = P.name;
        this.spots[id] = h;
      } else if (h && (!on || d > 40)) { h.keep = false; g.actors.remove(h); this.spots[id] = null; }
    }
  };
  ST.tree = function (h) {
    const g = G(), pl = g.player, id = h.storyNpc, P = PEOPLE[id], key = 'story:' + id;
    const s = C.state(), i = C.sagaAct(key), saga = C.SAGAS[key];
    const say = (t) => g.ui.talkLine(t), close = () => g.ui.closeSheet();
    const opts = [];
    opts.push({ label: '"Tell me about yourself."', fn: () => say(R.rng.pick(P.intro)) });
    if (s.active && s.active.fam === key) opts.push({ label: `"About ${saga.acts[s.active.act].title.toLowerCase()}..."`, fn: () => say(saga.acts[s.active.act].steps[s.active.step].text) });
    else if (i < saga.acts.length) opts.push({ label: i === 0 ? '"Something\'s troubling you."' : '"What else do you need?"', small: `${saga.title} ${i + 1}/3 · ${saga.acts[i].title}`, cls: 'go', fn: () => { if (s.active) return say('Finish what you\'re doing first. I\'ll be here.'); close(); C.start(key); } });
    else opts.push({ label: '"How are things?"', fn: () => say(R.rng.pick(['Better, thanks to you.', 'Quiet. I owe you for that.', 'You\'re always welcome here.'])) });
    opts.push({ label: 'Goodbye', fn: close });
    return { title: P.name, sub: i >= saga.acts.length ? P.perkText : 'Everybody in town knows this face.', options: opts };
  };
  const baseTree = R.dialog.tree;
  R.dialog.tree = function (h) { return h.storyNpc ? ST.tree(h) : baseTree.call(this, h); };
  ST.jobsHtml = function (esc) {
    const s = C.state();
    let h = '<div class="sect">People worth knowing</div>';
    for (const id in PEOPLE) {
      const P = PEOPLE[id], key = 'story:' + id, i = C.sagaAct(key), c = cityOfFam(P.city);
      const where = `${c ? c.name : ''}, ${P.where[0]}, ${P.hours[0]}:00–${P.hours[1] % 24}:00`;
      const st = s.storyDead && s.storyDead[id] ? 'dead' : i >= 3 ? 'complete ✓ · ' + esc(P.perkText.split(':')[0]) : `${esc(P.saga.title)} ${i + 1}/3`;
      h += `<p>• <b>${esc(P.name)}</b> <small>(${esc(where)})</small>: ${st}</p>`;
    }
    return h;
  };
  ST.perk = (k) => !!(C.state().perks || {})[k];

  // ---------------------------------------------------------------- the rewards
  ST.daily = function () {
    const g = G(), pl = g.player;
    if (this.perk('vera')) { const c = g.world.cities[(R.rng() * g.world.cities.length) | 0]; const lead = g.jobs.makeLead({ x: (c.cx) * TS, y: c.cy * TS }); if (lead) g.ui.toast(`Vera, on the phone: "${lead}"`, 'good'); }
    if (this.perk('zelie')) {
      const houses = g.world.buildings.filter((b) => b && (b.type === 'house' || b.type === 'cabin') && !b.destroyed && b.residents.length);
      const b = R.rng.pick(houses);
      if (b) { b.stash = (b.stash || 0) + R.rng.int(150, 400); g.jobs.addLead({ kind: 'stash', x: b.out.x, y: b.out.y, text: 'The Tower card: a stash', b: b.id }); g.ui.toast('Zelie turns the Tower card: "Money, hidden under a floor. I marked it for you, cher."', 'good'); }
    }
    if (this.perk('doc') && !pl.docHp) { pl.docHp = 1; pl.maxHp += 10; }
  };
  ST.tick = function (dt) {
    const g = G(), pl = g.player, room = pl.room;
    if (!room) return;
    const t = room.b.type;
    if (this.perk('sanctuary') && t === 'church' && g.law.incident && g.law.incident.state !== 'pursuit') { g.law.clearIncident(true); g.ui.toast('An altar boy slips out the side door. Twenty minutes later the patrol cars roll away.', 'good'); }
    if (this.perk('vera') && (t === 'club' || t === 'casino') && pl.cool < 100) pl.cool = 100;
    if (this.perk('doc') && t === 'hospital' && pl.hp < pl.maxHp) { pl.hp = pl.maxHp; pl.bloody = 0; if (pl.wnd) pl.wnd.bleed = 0; g.ui.toast('Doc Marlowe\'s nurses wave you straight through. No charge.', 'good'); }
  };
  const LP = R.Law.prototype, baseAdd = LP.addBounty;
  LP.addBounty = function (crime) {
    if (crime && crime.jur === 'dust' && ST.perk('hale') && crime.bounty) crime = Object.assign({}, crime, { bounty: Math.round(crime.bounty / 2) });
    return baseAdd.call(this, crime);
  };
  const JD = R.Jobs.prototype.daily;
  R.Jobs.prototype.daily = function () { JD.call(this); ST.daily(); };

  // ---------------------------------------------------------------- everybody else: quirks
  const QUIRKS = [
    { id: 'hungry', lines: ['You eat yet? I could eat.', 'The diner\'s got meatloaf Tuesday. Is it Tuesday?', 'I\'m starving. I\'m always starving.'] },
    { id: 'conspiracy', lines: ['The moon landing? Soundstage in Dustwater. I\'ve seen it.', 'They put something in the water. Why do you think the fish are so calm?', 'The lights over the desert aren\'t planes. Wake up.'] },
    { id: 'disco', lines: ['Saturday night, man. That\'s all I live for.', 'You ever seen the floor light up under your feet? Religious.', 'The Bee Gees are the Beatles of now. Fight me.'] },
    { id: 'hypochondriac', lines: ['Does this look swollen to you? Be honest.', 'I think I have the gout. Or the other gout.', 'Don\'t stand so close, I\'m catching something.'] },
    { id: 'gambler', lines: ['I got a system for the ponies. Can\'t lose. Well, I have lost.', 'Five bucks says it rains before noon.', 'The house always wins. Unless you know the house.'] },
    { id: 'vet', lines: ['Korea was cold. This is nothing.', 'You learn to sleep anywhere in a war.', 'I don\'t like loud noises. You understand.'] },
    { id: 'poet', lines: ['The city breathes in neon and exhales smoke. I wrote that.', 'I\'m working on a sonnet about the harbor. It\'s mostly about seagulls.', 'Everybody\'s a poem. Most of them rhyme badly.'] },
    { id: 'boxer', lines: ['I went six rounds with Kid Gavilan once. Well, his cousin.', 'Keep your left up. Always keep your left up.', 'My nose has been broke nine times. It\'s a good nose.'] },
    { id: 'gossip2', lines: ['Did you hear about the Don\'s nephew? Oh, you didn\'t hear it from me.', 'I know everybody\'s business. It\'s a public service.', 'The mailman and the Widow Pruitt. That\'s all I\'ll say.'] },
    { id: 'pious2', lines: ['I\'ll pray for you. You look like you need it.', 'Sunday mass. Nine sharp. You should come.', 'The Lord sees your sideburns.'] },
  ];
  const quirk = (h) => {
    if (h.quirk !== undefined) return h.quirk;
    const seed = h.person ? h.person.seed || h.person.id : (h.look && h.look.seedStr ? h.look.seedStr.length * 7 : (h.x * 13 + h.y) | 0);
    h.quirk = h.look && h.look.kid ? null : QUIRKS[Math.abs(seed | 0) % QUIRKS.length];
    return h.quirk;
  };
  // what you look like to them
  ST.reaction = function (h) {
    const g = G(), pl = g.player;
    if (pl.sneak) return pl.disguise === 'bush' || pl.disguise === 'plant' ? R.rng.pick(['That bush just said hello.', 'I\'ve had too much coffee. The shrubs are talking.']) : R.rng.pick([`Why are you talking to me from inside a ${pl.disguise || 'box'}?`, `The ${pl.disguise || 'box'} talks. Great. I\'m going home.`]);
    if (pl.wnd && pl.wnd.bleed > 0.25) return h.quirk && h.quirk.id === 'hypochondriac' ? 'Oh God, is that blood? Don\'t get it on me!' : R.rng.pick(['Mister, you\'re bleeding all over the sidewalk.', 'You should see a doctor. Like, now.']);
    if (pl.bloody > 0.5) return R.rng.pick(['Is that... ketchup on your suit?', 'You\'ve got something on your shirt. A lot of something.']);
    if (pl.masked) return R.rng.pick(['Take the mask off, you\'re scaring my kid.', 'Halloween\'s in October, pal.']);
    if (pl.swimming || (pl.swimT || 0) > 0) return 'Why are you all wet?';
    if (pl.drunk > 0.5) return R.rng.pick(['You\'re swaying, friend.', 'How many have you had?']);
    if (pl.style && (pl.style.shirt === 'gljersey' || pl.style.shirt === 'fearblue')) return R.rng.pick(['Nice costume. You in the circus?', 'Is that a uniform? For what?']);
    if (pl.rep && pl.rep.infamy > 60) return R.rng.pick(['I know who you are. Please don\'t hurt me.', 'You\'re the one from the papers.']);
    return null;
  };
  const D2 = R.dialog, baseGreet = D2.greet;
  D2.greet = function (h) {
    const r = baseGreet.call(this, h);
    if (h && !h.dead && !h.look.kid && !h.cop && R.rng() < 0.5) {
      const react = ST.reaction(h), q = quirk(h);
      const line = react || (q && R.rng() < 0.6 ? R.rng.pick(q.lines) : null);
      if (line) setTimeout(() => { if (!h.dead && !h.removed) G().actors.say(h, line); }, 2600);
    }
    return r;
  };
  const baseChatter = D2.chatter;
  D2.chatter = function (h, o) {
    const q = quirk(h);
    if (q && R.rng() < 0.3) return R.rng.pick(q.lines);
    return baseChatter.call(this, h, o);
  };
  ST.quirkOf = quirk;
})();
// a bobbing '!' over anyone with a chapter waiting for you
(function () {
  const C = R.campaign, ST = R.stories, cd = C.draw;
  C.draw = function (g) {
    cd.call(this, g);
    if (C.state().active) return;
    const t = this.game.clock.real;
    for (const id in ST.spots) {
      const h = ST.spots[id];
      if (!h || h.dead || C.sagaAct('story:' + id) >= 3) continue;
      const x = Math.round(h.x), y = Math.round(h.y - 30 + Math.sin(t * 4) * 1.5);
      g.fillStyle = '#140e10'; g.fillRect(x - 2, y - 1, 5, 10);
      g.fillStyle = '#f0c020'; g.fillRect(x - 1, y, 3, 5); g.fillRect(x - 1, y + 6, 3, 2);
    }
  };
})();
