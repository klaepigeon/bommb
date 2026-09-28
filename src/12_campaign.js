// RHAPSODY — the families' sagas and the three roads to the top.
// Every family has a three-act saga, told through a small mission engine (go somewhere,
// clear a crew, hold a door, take out a mark, run a car, grab a thing, talk someone round,
// stake out a deal). On top of that sit three endgames you can walk into at any time:
//   BLOOD — kill every don on the coast.
//   CROWN — squeeze each family until its city is yours.
//   BADGE — wear a wire for Detective Rourke and put the families behind bars.
'use strict';
(function () {
  const D = R.data, TS = R.TILE;
  const C = (R.campaign = {});
  const FAMS = D.cities.map((c) => c.family);
  const FAMCOLOR = Object.fromEntries(D.cities.map((c) => [c.family, c.color]));
  // 'the Castellanos', but 'the Reyes family' and 'the Thibodeaux family'
  const PLF = (f) => (/[sx]$/.test(f) ? `${f} family` : `${f}s`);
  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);

  // ---------------------------------------------------------------- places
  const cityOf = (fam) => C.game.jobs.cityOfFamily(fam);
  const bOf = (fam, types) => { const c = cityOf(fam); if (!c) return null; return c.buildings.find((b) => b && !b.destroyed && types.includes(b.type)) || c.buildings.find((b) => b && !b.destroyed) || null; };
  const clubOf = (fam) => bOf(fam, ['social']);
  const walkable = (x, y) => { const w = C.game.world; return w.inb(x, y) && !w.solidPed(x, y) && !w.isWater(x, y); };
  const near = (x, y, r0, r1) => C.game.world.findNear(x | 0, y | 0, r0 || 0, r1 || 8, walkable);
  const atB = (fam, types) => () => { const b = bOf(fam, types); return b ? { x: b.out.x, y: b.out.y + 1, b: b.id } : null; };
  // somewhere out past the edge of town, away from the middle of the map
  const outskirts = (fam, dist) => () => {
    const g = C.game, w = g.world, c = cityOf(fam);
    if (!c) return null;
    let dx = c.cx - w.W / 2, dy = c.cy - w.H / 2;
    const l = Math.hypot(dx, dy) || 1; dx /= l; dy /= l;
    const half = Math.max(c.x1 - c.x0, c.y1 - c.y0) / 2;
    const tx = R.clamp(Math.round(c.cx + dx * (half + dist)), 6, w.W - 7), ty = R.clamp(Math.round(c.cy + dy * (half + dist)), 6, w.H - 7);
    const s = w.findNear(tx, ty, 0, 18, (x, y) => walkable(x, y) && !w.cityAt(x, y) && !D.roadTile[w.t(x, y)]);
    return s ? { x: s.x, y: s.y } : { x: tx, y: ty };
  };

  // ---------------------------------------------------------------- the sagas
  // step kinds: go, squad, defend, kill, drive, grab, talk, stake
  const SAGAS = {
    Vane: { title: 'The Fog Ledger', perk: 'Harbor Pass: the docks pay you $60 every morning.', acts: [
      { title: 'Low Tide', brief: 'Castellano smugglers are landing crates on Vane docks after dark, bold as brass. Gus wants the crates, the men gone, and the shipping manifest on his desk.',
        steps: [{ k: 'squad', at: atB('Vane', ['warehouse', 'garage']), enemy: 'Castellano', n: 4, text: 'Clear the Castellano crew at the Port Hollow warehouses.' },
          { k: 'grab', at: atB('Vane', ['warehouse', 'garage']), item: 'the manifest', text: 'Take the manifest from the crates.' }], cash: 300, rep: 60 },
      { title: 'The Rat', brief: 'Somebody in Port Hollow is feeding the cops. Old Mo mends nets by the water and hears everything. Ask him.',
        steps: [{ k: 'talk', at: atB('Vane', ['bar', 'diner', 'fish', 'general']), npc: 'Old Mo', say: 'Sal Pennino. Drinks coffee with a detective every day at noon, thinks nobody notices. He\'s out back of the diner now, with two of his cousins.', choices: [['"Thanks, Mo."', null]], text: 'Find Old Mo and ask about the rat.' },
          { k: 'kill', at: atB('Vane', ['diner', 'bar', 'general']), name: 'Sal "The Rat" Pennino', hp: 150, guards: 2, enemy: 'Vane', spare: 'You let Sal run. He\'ll never show his face in Port Hollow again.', text: 'Deal with Sal the Rat.' }], cash: 400, rep: 70 },
      { title: 'Harbor Masters', brief: 'The Castellanos want Port Hollow and they\'re done asking. They\'re coming for the club tonight, and Gus\'s nephew Teddy is inside.',
        steps: [{ k: 'defend', at: atB('Vane', ['social']), enemy: 'Castellano', waves: 3, per: 28, n: 3, dur: 85, vip: 'Teddy Vane', text: 'Hold the Vane club. Keep Teddy alive.' }], cash: 800, rep: 120, perk: 'vane' },
    ] },
    Castellano: { title: 'Neon Crown', perk: 'House Favor: every casino table in the state leans your way.', acts: [
      { title: 'The Skim', brief: 'The casino count van leaves New Avalon every night with the Castellanos\' share of the drop. Tonight the regular driver has a broken wrist. You\'re driving.',
        steps: [{ k: 'drive', from: atB('Castellano', ['casino', 'hotel', 'bank']), to: atB('Vane', ['warehouse', 'social']), model: 'van', text: 'Run the count van to Port Hollow without losing it.' }], cash: 350, rep: 60 },
      { title: 'Wedding Crashers', brief: 'Carmine\'s daughter Gina is getting married at the church, and the Reyes family was not invited. They\'re coming anyway.',
        steps: [{ k: 'defend', at: atB('Castellano', ['church', 'hotel']), enemy: 'Reyes', waves: 3, per: 24, n: 3, dur: 75, vip: 'Gina Castellano', text: 'Protect the bride.' }], cash: 500, rep: 80 },
      { title: 'The Commission', brief: 'Councilman Bertolli took Castellano money for ten years and just testified to a grand jury. He travels with private muscle.',
        steps: [{ k: 'kill', at: atB('Castellano', ['bank', 'hotel', 'casino']), name: 'Councilman Bertolli', hp: 140, guards: 3, enemy: null, text: 'Take out Councilman Bertolli.' }], cash: 900, rep: 120, perk: 'castellano' },
    ] },
    Reyes: { title: 'Desert Gold', perk: 'Sangre del Desierto: +25 max health, for good.', acts: [
      { title: 'Dry Run', brief: 'O\'Malley bootleggers hit a Reyes truck out in the flats and are sitting on the cargo, waiting for a buyer. Soledad wants it back.',
        steps: [{ k: 'squad', at: outskirts('Reyes', 16), enemy: "O'Malley", n: 4, text: 'Take back the Reyes cargo in the desert.' }, { k: 'grab', at: outskirts('Reyes', 16), item: 'the gold bars', text: 'Grab the gold.' }], cash: 350, rep: 60 },
      { title: 'The Canyon Run', brief: 'A muscle car full of Reyes gold needs to reach Mama Thibodeaux in Bayou Clair. Every family on the coast has heard about it.',
        steps: [{ k: 'drive', from: atB('Reyes', ['garage', 'gas', 'social']), to: atB('Thibodeaux', ['social']), model: 'muscle', text: 'Drive the gold to Bayou Clair.' }], cash: 500, rep: 80 },
      { title: 'El Alacrán', brief: 'Soledad\'s own lieutenant, the Scorpion, has gone out on his own with half her soldiers and a cave full of guns.',
        steps: [{ k: 'kill', at: outskirts('Reyes', 30), name: 'El Alacrán', hp: 260, guards: 4, enemy: 'Reyes', weapon: 'chopper', text: 'End El Alacrán\'s little revolution.' }], cash: 900, rep: 120, perk: 'reyes' },
    ] },
    "O'Malley": { title: 'The Long Winter', perk: 'Lumber Rights: the sawmill pays you $40 every morning.', acts: [
      { title: 'Timber Tax', brief: 'Vane collectors are shaking down the Pinecrest sawmill like they own it. Declan wants them gone and the ledger they keep.',
        steps: [{ k: 'squad', at: atB("O'Malley", ['warehouse', 'garage', 'general']), enemy: 'Vane', n: 3, text: 'Run the Vane collectors out of Pinecrest.' }, { k: 'grab', at: atB("O'Malley", ['warehouse', 'garage', 'general']), item: 'the tax ledger', text: 'Take their ledger.' }], cash: 300, rep: 60 },
      { title: 'Snowblind', brief: 'Declan\'s brother Finn owes the Vanes more than he\'s worth and is hiding in a hunting cabin up north. They know where.',
        steps: [{ k: 'talk', at: outskirts("O'Malley", 14), npc: 'Finn O\'Malley', say: 'They found me? Course they did. I\'m not leaving the whiskey, and I\'m not dying up here either. Stay with me.', choices: [['"Stay behind me, Finn."', null]], text: 'Find Finn in the woods.' },
          { k: 'defend', at: outskirts("O'Malley", 14), enemy: 'Vane', waves: 2, per: 22, n: 3, dur: 55, vip: 'Finn O\'Malley', reuseVip: true, text: 'Keep Finn alive.' }], cash: 450, rep: 80 },
      { title: 'Last Call', brief: 'The Castellanos have bought half the cops in Pinecrest and the other half are scared. Tonight they come for the O\'Malley club.',
        steps: [{ k: 'defend', at: atB("O'Malley", ['social']), enemy: 'Castellano', waves: 3, per: 26, n: 3, dur: 85, vip: 'Nora O\'Malley', text: 'Hold the club. Keep Nora alive.' }], cash: 800, rep: 120, perk: 'omalley' },
    ] },
    Thibodeaux: { title: 'Hush Money', perk: 'Gris-Gris: once a day, a killing blow leaves you standing at 1 HP.', acts: [
      { title: 'Gator Bait', brief: 'A satchel of Mama\'s money went into the marsh with a courier who never came out. Reyes runners are looking for it too.',
        steps: [{ k: 'squad', at: outskirts('Thibodeaux', 14), enemy: 'Reyes', n: 3, text: 'Beat the Reyes runners to the satchel.' }, { k: 'grab', at: outskirts('Thibodeaux', 14), item: 'Mama\'s satchel', text: 'Fish the satchel out of the reeds.' }], cash: 300, rep: 60 },
      { title: 'The Preacher\'s Tongue', brief: 'Reverend Achille has started preaching about "the sins of a certain family" on Sunday mornings. Mama would like it to stop.',
        steps: [{ k: 'talk', at: atB('Thibodeaux', ['church']), npc: 'Reverend Achille', say: 'I know who sent you. I have a congregation. I have a conscience. What I do not have is a pension.', choices: [['Scare him quiet', 'scared', 'He goes pale and starts talking about the weather instead.'], ['Pay him off ($200)', 'paid', 'He pockets it with a small blessing.'], ['Make him disappear', 'gone', 'The reverend takes a long trip down the river.']], text: 'Have a word with the Reverend.' }], cash: 400, rep: 80 },
      { title: 'Hoodoo Night', brief: 'The O\'Malleys think the bayou is soft. Tonight they find out. They\'re coming for Mama\'s place and her granddaughter Celeste.',
        steps: [{ k: 'defend', at: atB('Thibodeaux', ['social']), enemy: "O'Malley", waves: 3, per: 26, n: 3, dur: 85, vip: 'Celeste Thibodeaux', text: 'Hold Mama\'s place. Keep Celeste alive.' }], cash: 800, rep: 120, perk: 'thibodeaux' },
    ] },
  };
  const ACT_NEED = [0, 25, 45]; // standing with the family to start each act
  C.SAGAS = SAGAS;
  C.atB = atB; C.outskirts = outskirts; C.clubOf = clubOf;

  // ---------------------------------------------------------------- state
  C.state = function () {
    const pl = this.game.player;
    return (pl.campaign = pl.campaign || { saga: {}, active: null, perks: {}, flags: {}, dons: {}, pressure: {}, ruled: {}, route: null, evidence: {}, suspicion: {}, blown: {}, raided: {}, wireDay: {}, endings: {}, fixDay: -1, grisDay: -1 });
  };
  C.init = function (game) {
    this.game = game;
    this.run = null;
    const self = this;
    // a don dies (the bus can be reset between games, so check every time)
    if (!this.onDeathFn) this.onDeathFn = (p, byPlayer) => self.onDeath(p, byPlayer);
    const ls = R.bus.map.get('person:died');
    if (!ls || !ls.includes(this.onDeathFn)) R.bus.on('person:died', this.onDeathFn);
    if (this.wrapped) return;
    this.wrapped = true;
    // perks
    const J = R.Jobs.prototype, daily = J.daily;
    J.daily = function () { daily.call(this); self.daily(); };
    const marker = J.marker;
    J.marker = function () { return self.marker() || marker.call(this); };
    const U = R.UI.prototype, gamble = U.gamble;
    U.gamble = function (p, stake, mult) { return gamble.call(this, p + (self.state().perks.castellano ? 0.05 : 0), stake, mult); };
    const PP = R.Player.prototype, die = PP.die;
    PP.die = function () {
      const s = self.state();
      if (s.perks.thibodeaux && s.grisDay !== game.pop.day) { s.grisDay = game.pop.day; this.hp = 1; game.ui.toast('Mama\'s gris-gris burns hot in your pocket. Not today.', 'good'); game.fx.text(this.x, this.y - 26, 'GRIS-GRIS', '#e0a0ff'); return; }
      return die.call(this);
    };
    const opts = U.interiorOptions;
    U.interiorOptions = function (b) { const o = opts.call(this, b); self.interiorOpts(b, o); return o; };
    const tree = R.dialog.tree;
    R.dialog.tree = function (h) {
      if (h.campaignTalk) return self.talkTree(h);
      const t = tree.call(this, h);
      if (h.person && h.person.isDon && t && t.options) self.donOpts(h, t.options);
      return t;
    };
  };
  C.afterLoad = function () {
    // re-apply what the coast looks like now: cities you rule, dons in jail, new dons
    const s = this.state(), g = this.game;
    for (const id in s.ruled) this.applyRule(g.world.cities.find((c) => c.id === id), true);
    for (const fam in s.newDon) this.applyDon(fam, s.newDon[fam]);
  };

  // ---------------------------------------------------------------- saga flow
  C.sagaAct = (fam) => C.state().saga[fam] || 0;
  C.canStart = function (fam) {
    const g = this.game, s = this.state(), i = this.sagaAct(fam), saga = SAGAS[fam];
    if (!saga || i >= saga.acts.length) return { ok: false, why: 'Finished.' };
    if (s.active) return { ok: false, why: 'You already have family business running.' };
    if (this.donGone(fam)) return { ok: false, why: 'There\'s nobody left to give the orders.' };
    const st = g.jobs.familyStanding(fam);
    if (st <= -20) return { ok: false, why: 'They don\'t trust you.' };
    if (st < ACT_NEED[i]) return { ok: false, why: `Needs ${ACT_NEED[i]} standing with the ${PLF(fam)} (you have ${Math.round(st)}). Do their jobs.` };
    if (i === 2 && fam === g.player.family && g.jobs.rank() < 2) return { ok: false, why: 'Needs Capo rank.' };
    return { ok: true };
  };
  C.start = function (fam) {
    const g = this.game, s = this.state(), i = this.sagaAct(fam), act = SAGAS[fam].acts[i];
    s.active = { fam, act: i, step: 0 };
    this.run = null;
    g.ui.story(`${SAGAS[fam].title}: ${act.title}`, `${act.brief}\n\n${act.steps[0].text}`);
    g.audio.sfx('accept');
  };
  C.current = function () {
    const s = this.state();
    if (!s.active) return null;
    if (!SAGAS[s.active.fam]) { s.active = null; return null; }
    const act = SAGAS[s.active.fam].acts[s.active.act];
    return { fam: s.active.fam, act, step: act.steps[s.active.step] };
  };
  C.abandon = function () {
    const s = this.state();
    if (!s.active) return;
    this.cleanup(false);
    s.active = null;
    this.game.ui.toast('You walked away from family business. They noticed.', 'warn');
  };
  C.nextStep = function () {
    const g = this.game, s = this.state(), cur = this.current();
    this.cleanup(true);
    s.active.step++;
    if (s.active.step >= cur.act.steps.length) return this.finishAct();
    g.ui.toast(cur.act.steps[s.active.step].text, 'good');
  };
  C.finishAct = function () {
    const g = this.game, s = this.state(), a = s.active, act = SAGAS[a.fam].acts[a.act], pl = g.player;
    s.saga[a.fam] = a.act + 1;
    s.active = null;
    if (a.fam === '__stake') { delete s.saga.__stake; pl.addCash(act.cash); g.audio.sfx('cash'); return g.ui.story('STAKEOUT DONE', `Rourke flips through the photos. "Nice work." +${R.fmtMoney(act.cash)}.`); }
    pl.addCash(act.cash);
    g.jobs.addRep(act.rep, a.fam);
    if (a.fam !== pl.family) g.jobs.standing[a.fam] = Math.min(100, (g.jobs.standing[a.fam] || 0) + 12);
    let extra = '';
    if (act.perk) {
      s.perks[act.perk] = 1;
      if (act.perk === 'reyes') { pl.maxHp += 25; pl.hp = pl.maxHp; }
      extra = `\n\n${SAGAS[a.fam].perk}`;
    }
    g.audio.sfx('promote');
    const last = s.saga[a.fam] >= SAGAS[a.fam].acts.length;
    if (SAGAS[a.fam].story) { g.ui.story(last ? `${SAGAS[a.fam].title}: COMPLETE` : SAGAS[a.fam].title, `${act.title}.\n\n+${R.fmtMoney(act.cash)}${extra}${last ? '' : `\n\nTalk to ${SAGAS[a.fam].who} again when you're ready.`}`); return; }
    g.ui.story(last ? `${SAGAS[a.fam].title}: COMPLETE` : 'FAMILY BUSINESS', `${act.title}.\n\n+${R.fmtMoney(act.cash)}  ·  +${act.rep} respect with the ${PLF(a.fam)}.${extra}${last ? '' : `\n\nThe next chapter needs ${ACT_NEED[a.act + 1]} standing with the ${PLF(a.fam)}.`}`);
    g.pop.addNews(cityOf(a.fam) ? cityOf(a.fam).id : 'port', R.rng.pick(['Police baffled by another night of gunfire.', 'Neighbours report "fireworks" near a local social club.', 'A quiet week, say the families. Nobody believes them.']));
  };
  C.fail = function (why) {
    const g = this.game, s = this.state(), a = s.active;
    this.cleanup(false);
    s.active = null;
    if (a) g.jobs.standing[a.fam] = (g.jobs.standing[a.fam] || 0) - 5;
    g.ui.story('IT WENT WRONG', `${why}\n\nTalk to the family again when you\'re ready to try again.`);
  };
  C.cleanup = function (won) {
    const r = this.run, g = this.game;
    if (!r) return;
    for (const h of r.foes || []) if (!h.dead) { h.keep = false; if (!won) h.hostile = false; }
    if (r.vip && !r.vip.dead && !r.keepVip) { g.fx.text(r.vip.x, r.vip.y - 26, 'Thank you!', '#f2e2c0'); r.vip.keep = false; r.vip.stay = false; r.vip.state = 'idle'; }
    if (r.npc && !r.npc.dead && !(r.keepVip)) { r.npc.keep = false; r.npc.campaignTalk = null; r.npc.stay = false; }
    if (r.car && !r.car.removed) r.car.keep = false;
    this.run = null;
  };

  // ---------------------------------------------------------------- spawning
  C.spawnFoe = function (x, y, fam, weapon) {
    const g = this.game;
    const s = near(x, y, 0, 6);
    if (!s) return null;
    const h = g.actors.makeHuman(s.x * TS + 8, s.y * TS + 8, { faction: fam || null, weapon: weapon || R.rng.pick(['revolver', 'revolver', 'knife', 'bat', 'magnum', 'shotgun']), arch: 'tough', tag: 'campaign', cash: R.rng.int(10, 60) });
    h.keep = true; h.campaign = true; h.hostile = true; h.tr.brave = Math.max(h.tr.brave, 0.85);
    return h;
  };
  C.spawnFriend = function (x, y, name) {
    const g = this.game;
    const s = near(x, y, 0, 4);
    if (!s) return null;
    const h = g.actors.makeHuman(s.x * TS + 8, s.y * TS + 8, { arch: 'friendly', tag: 'campaign', cash: 0 });
    h.keep = true; h.stay = true; h.state = 'idle'; h.timer = 1e9; h.strangerName = name; h.hp = h.maxHp = 160; h.campaign = true;
    return h;
  };

  // ---------------------------------------------------------------- per frame
  C.update = function (dt) {
    const g = this.game, pl = g.player;
    const cur = this.current();
    if (!cur) return;
    const st = cur.step;
    let r = this.run;
    if (!r) {
      r = this.run = { t: 0, foes: [], spawned: false };
      r.at = st.at ? st.at() : null;
      if (st.k === 'drive') { r.from = st.from(); r.to = st.to(); }
      if ((st.at && !r.at) || (st.k === 'drive' && (!r.from || !r.to))) return this.fail('The place you were sent to is gone.');
    }
    r.t += dt;
    const d = r.at ? Math.hypot(pl.x / TS - r.at.x, pl.y / TS - r.at.y) : 1e9;
    const alive = (h) => h && !h.dead && !(h.down > 0) && g.actors.list.includes(h);
    switch (st.k) {
      case 'go': if (d < (st.r || 3)) this.nextStep(); break;
      case 'grab': break; // handled by the USE prompt
      case 'squad':
        if (!r.spawned && d < 34) { r.spawned = true; for (let i = 0; i < st.n; i++) { const f = this.spawnFoe(r.at.x + R.rng.int(-3, 3), r.at.y + R.rng.int(-2, 3), st.enemy); if (f) r.foes.push(f); } g.ui.toast(`${st.n} ${st.enemy || 'hired'} guns, dead ahead.`, 'warn'); }
        if (r.spawned) { for (const f of r.foes) if (alive(f) && d < 14 && f.state !== 'fight') g.actors.setFight(f, pl); if (!r.foes.some(alive)) this.nextStep(); }
        break;
      case 'kill':
        if (!r.spawned && d < 34) {
          r.spawned = true;
          const b = this.spawnFoe(r.at.x, r.at.y, st.enemy, st.weapon || 'magnum');
          if (b) { b.hp = b.maxHp = st.hp; b.strangerName = st.name; b.boss = true; b.hostile = false; b.stay = true; b.state = 'idle'; b.timer = 1e9; r.boss = b; }
          for (let i = 0; i < st.guards; i++) { const f = this.spawnFoe(r.at.x + R.rng.int(-3, 3), r.at.y + R.rng.int(-3, 3), st.enemy); if (f) { f.hostile = false; r.foes.push(f); } }
          g.ui.toast(st.guards ? `${st.name} is here, with ${st.guards} guards.` : `${st.name} is here.`, 'warn');
        }
        if (r.spawned) {
          const b = r.boss;
          if (!b) return this.nextStep();
          if (d < 9 || b.hp < b.maxHp || r.foes.some((f) => f.hp < f.maxHp)) { if (!r.loud) { r.loud = true; g.actors.say(b, R.rng.pick(['Get him!', 'You picked the wrong day.', 'Kill that one!'])); } for (const f of [b, ...r.foes]) if (alive(f) && f.state !== 'fight') { f.hostile = true; f.stay = false; g.actors.setFight(f, pl); } }
          if (st.spare && !r.asked && alive(b) && b.hp < b.maxHp * 0.3) {
            r.asked = true;
            b.state = 'surrender'; b.timer = 1e9; b.hostile = false;
            g.actors.say(b, 'Wait! Wait! I\'ll leave! You\'ll never see me again!');
            g.ui.choice(`${st.name} begs`, [
              { label: 'Finish it', fn: () => { R.combat.kill(b, pl, 'melee'); pl.rep.infamy += 3; } },
              { label: 'Let them run', small: 'Honor +, the family won\'t love it', fn: () => { this.state().flags[st.name] = 'spared'; pl.rep.honor += 4; g.actors.setFlee(b, pl, 30); b.keep = false; g.ui.toast(st.spare, 'good'); this.nextStep(); } },
            ]);
          }
          if (!alive(b) && (b.dead || b.down > 0)) this.nextStep();
          else if (!g.actors.list.includes(b)) this.nextStep();
        }
        break;
      case 'defend': {
        if (!r.vip && d < 30) {
          r.vip = st.reuseVip && this.lastNpc && !this.lastNpc.dead ? this.lastNpc : this.spawnFriend(r.at.x, r.at.y, st.vip);
          if (r.vip) { r.vip.campaignTalk = null; r.vip.stay = true; r.vip.state = 'idle'; r.vip.timer = 1e9; }
          r.wave = 0; r.waveT = 4; r.left = st.dur;
          g.ui.toast(`${st.vip}: "They're coming. Don't let them get me!"`, 'warn');
        }
        if (!r.vip) break;
        if (r.vip.dead) return this.fail(`${st.vip} is dead.`);
        r.left -= dt;
        r.waveT -= dt;
        if (r.waveT <= 0 && r.wave < st.waves) {
          r.wave++; r.waveT = st.per;
          const a = R.rng() * Math.PI * 2;
          const cx = r.at.x + Math.cos(a) * 13, cy = r.at.y + Math.sin(a) * 13;
          for (let i = 0; i < st.n + (r.wave === st.waves ? 1 : 0); i++) { const f = this.spawnFoe(cx + R.rng.int(-2, 2), cy + R.rng.int(-2, 2), st.enemy); if (f) { r.foes.push(f); g.actors.setFight(f, R.rng() < 0.55 ? r.vip : pl); } }
          g.ui.toast(`Wave ${r.wave} of ${st.waves}: ${st.enemy || 'hired'} gunmen!`, 'bad');
        }
        for (const f of r.foes) if (alive(f) && f.state !== 'fight') g.actors.setFight(f, R.rng() < 0.5 ? r.vip : pl);
        if (r.wave >= st.waves && r.left <= 0 && !r.foes.some(alive)) { r.keepVip = false; this.nextStep(); }
        break;
      }
      case 'talk':
        if (!r.npc && d < 30) { r.npc = this.spawnFriend(r.at.x, r.at.y, st.npc); if (r.npc) { r.npc.campaignTalk = st; this.lastNpc = r.npc; r.keepVip = true; } }
        if (r.npc && r.npc.dead) return this.fail(`${st.npc} is dead.`);
        break;
      case 'drive': {
        if (!r.car && Math.hypot(pl.x / TS - r.from.x, pl.y / TS - r.from.y) < 40) {
          const b = g.world.buildings[r.from.b];
          r.car = b && g.jobs.spawnCarNear(b, st.model);
          if (r.car) { r.car.keep = true; r.car.locked = false; r.car.campaign = true; r.car.jobCar = true; }
        }
        if (r.car) {
          if (r.car.removed || r.car.wrecked) return this.fail('The car is scrap, and so is the cargo.');
          if (!r.started && pl.inCar === r.car) { r.started = true; r.t0 = g.clock.t; r.minutes = Math.round(Math.hypot(r.to.x - r.from.x, r.to.y - r.from.y) * 0.2 + 14); g.ui.toast(`Drive to ${g.world.buildings[r.to.b].name}. ${r.minutes} minutes.`, 'warn'); }
          if (r.started) {
            r.leftMin = r.minutes - (g.clock.t - r.t0);
            if (r.leftMin <= 0) return this.fail('Too slow. They stopped waiting.');
            if (pl.inCar === r.car && Math.hypot(r.car.x / TS - r.to.x, r.car.y / TS - r.to.y) < 5 && Math.abs(r.car.speed) < 20) {
              if (g.law.active()) { if (!r.warned) { r.warned = true; g.ui.toast('Lose the cops before you pull in.', 'warn'); } }
              else { pl.exitCar(); const car = r.car; setTimeout(() => g.traffic.remove(car), 2500); this.nextStep(); }
            }
            // somebody always wants the cargo
            if (!r.ambush && r.leftMin < r.minutes * 0.6) { r.ambush = true; const e = R.rng.pick(FAMS.filter((f) => f !== cur.fam)); for (let i = 0; i < 3; i++) { const f = this.spawnFoe(pl.x / TS + 10, pl.y / TS + R.rng.int(-4, 4), e); if (f) { r.foes.push(f); g.actors.setFight(f, pl); } } g.ui.toast(`${e} gunmen on the road!`, 'bad'); }
          }
        }
        break;
      }
      case 'stake': {
        // watch a deal from a distance without being spotted
        if (!r.spawned && d < 34) { r.spawned = true; for (let i = 0; i < 3; i++) { const f = this.spawnFoe(r.at.x + R.rng.int(-2, 2), r.at.y + R.rng.int(-2, 2), st.enemy); if (f) { f.hostile = false; f.stay = true; f.state = 'idle'; f.timer = 1e9; r.foes.push(f); } } r.watch = 0; }
        if (r.spawned) {
          if (d < 3.5 && !r.blown) { r.blown = true; g.ui.toast('They made you!', 'bad'); for (const f of r.foes) if (alive(f)) { f.stay = false; g.actors.setFight(f, pl); } this.state().suspicion[st.enemy] = Math.min(100, (this.state().suspicion[st.enemy] || 0) + 25); }
          if (r.blown) { if (!r.foes.some(alive)) return this.fail('The deal fell apart in a gunfight. No photos a jury would want.'); break; }
          if (d < 10) { r.watch += dt; if (Math.floor(r.watch) !== Math.floor(r.watch - dt)) g.fx.text(pl.x, pl.y - 28, `click ${Math.min(6, Math.floor(r.watch))}/6`, '#f2e2c0'); }
          if (r.watch >= 6) { this.addEvidence(st.enemy, 1, 'Photos of the deal'); for (const f of r.foes) { f.keep = false; f.stay = false; } this.nextStep(); }
        }
        break;
      }
      default: break;
    }
  };
  // USE: pick up a mission item
  C.context = function (pl) {
    const cur = this.current(), r = this.run;
    if (!cur || cur.step.k !== 'grab' || !r || !r.at) return null;
    if (Math.hypot(pl.x / TS - r.at.x - 0.5, pl.y / TS - r.at.y - 0.5) > 3) return null;
    return { label: `Take ${cur.step.item}`, fn: () => { this.game.audio.sfx('cash'); this.game.ui.toast(`You have ${cur.step.item}.`, 'good'); this.nextStep(); } };
  };
  // grab spots glint so you can find them
  C.draw = function (g) {
    const cur = this.current(), r = this.run;
    if (!cur || !r || !r.at || cur.step.k !== 'grab') return;
    const t = this.game.clock.real, x = r.at.x * TS + 8, y = r.at.y * TS + 8;
    g.fillStyle = '#6a4a24'; g.fillRect(x - 5, y - 6, 10, 7); g.fillStyle = '#a07a40'; g.fillRect(x - 5, y - 6, 10, 2);
    g.fillStyle = `rgba(255,230,140,${0.5 + Math.sin(t * 5) * 0.4})`; g.fillRect(x - 1, y - 12 - Math.sin(t * 3) * 2, 2, 2);
  };
  C.marker = function () {
    const cur = this.current(), r = this.run;
    if (!cur || !r) return null;
    if (cur.step.k === 'drive') {
      if (r.car && this.game.player.inCar !== r.car) return { x: r.car.x, y: r.car.y, label: 'The car' };
      const p = r.car ? r.to : r.from;
      return p && { x: p.x * TS + 8, y: p.y * TS + 8, label: cur.act.title };
    }
    if (cur.step.k === 'kill' && r.boss && !r.boss.dead) return { x: r.boss.x, y: r.boss.y, label: cur.step.name };
    return r.at ? { x: r.at.x * TS + 8, y: r.at.y * TS + 8, label: cur.act.title } : null;
  };
  C.talkTree = function (h) {
    const g = this.game, st = h.campaignTalk, ui = g.ui;
    const opts = [];
    const cur = this.current();
    if (cur && cur.step === st) {
      for (const [label, flag, result] of st.choices) opts.push({ label, fn: () => {
        if (flag === 'paid' && !g.player.pay(200)) return ui.talkLine('"Two hundred. Not a penny less."');
        if (flag) this.state().flags[st.npc] = flag;
        if (flag === 'gone') { g.player.rep.infamy += 4; g.pop.addNews('bayou', 'Reverend Achille has left Bayou Clair "on a mission". His flock is worried.'); ui.closeSheet(); g.actors.remove(h); this.run.npc = null; }
        else if (flag === 'scared') { g.player.rep.infamy += 1; ui.closeSheet(); }
        else if (flag === 'paid') { g.player.rep.honor += 1; ui.closeSheet(); }
        else ui.closeSheet();
        if (result) g.ui.toast(result, 'good');
        this.nextStep();
      } });
    }
    opts.push({ label: 'Leave', fn: () => ui.closeSheet() });
    setTimeout(() => ui.talkLine(st.say), 0);
    return { title: st.npc, sub: 'Expecting you, more or less.', options: opts };
  };

  // ---------------------------------------------------------------- BLOOD: kill the dons
  C.donOf = function (fam) { const c = cityOf(fam); const p = c && c.don != null ? this.game.pop.people[c.don] : null; return p; };
  C.donGone = function (fam) { const p = this.donOf(fam); return !p || !p.alive || (p.jailed && p.jailed > this.game.pop.day); };
  C.onDeath = function (p, byPlayer) {
    const g = this.game, s = this.state();
    if (!p) return;
    const fam = p.faction;
    if (p.isDon && fam) {
      const c = cityOf(fam);
      s.donDeadDay = s.donDeadDay || {};
      s.donDeadDay[fam] = g.pop.day;
      if (!byPlayer) return;
      s.dons[fam] = g.pop.day + 1;
      g.jobs.standing[fam] = -100;
      s.pressure[fam] = (s.pressure[fam] || 0) + 35;
      if (c) g.pop.addNews(c.id, `${p.first} ${p.last}, head of the ${fam} family, found dead. Police expect "a very long week".`);
      const rivals = FAMS.filter((f) => f !== g.player.family), killed = FAMS.filter((f) => s.dons[f]);
      g.ui.story('A DON IS DEAD', `Don ${p.last} is dead, and everyone knows who did it. Every ${fam} soldier on the coast wants your head.\n\nDons killed: ${killed.length} of ${FAMS.length}.${fam === g.player.family ? '\n\nYou killed your own Don. Your family is hunting you now.' : ''}`);
      if (fam === g.player.family) { g.jobs.standing[fam] = -100; }
      if (!s.endings.blood && rivals.every((f) => s.dons[f])) {
        s.endings.blood = 1;
        const own = g.player.family;
        if (!s.dons[own]) { g.jobs.rep = Math.max(g.jobs.rep, 1600); g.jobs.promote(5); }
        setTimeout(() => g.ui.story('BLOOD: BOSS OF BOSSES', s.dons[own] ? 'Every chair at the table is empty, including your own family\'s. There is nobody left to answer to and nobody left to protect you. The Brass Coast is a graveyard with your name on every headstone.\n\nThe game goes on. The feuds do too.' : `The other four families are headless. Don ${g.jobs.donName(own)} pours two glasses of something very old, hands you one, and gives you the family.\n\nYou are the Boss of Bosses. Nobody on the coast moves without your say-so.\n\nThe game goes on.`), 400);
      }
      if (!s.endings.lastman && FAMS.every((f) => s.dons[f])) { s.endings.lastman = 1; setTimeout(() => g.ui.story('BLOOD: LAST MAN STANDING', 'All five dons are dead, and you killed every one. The families are shattered into feuding crews with no one to make peace.\n\nNo one is left to tell you no.'), 900); }
      return;
    }
    // squeezing a family: each soldier or capo you put down in their city is pressure
    if (byPlayer && fam && fam !== 'law' && (p.role === 'soldier' || p.role === 'capo')) s.pressure[fam] = Math.min(100, (s.pressure[fam] || 0) + (p.role === 'capo' ? 10 : 6));
  };
  // a headless family eventually promotes a capo, unless you took the city
  C.daily = function () {
    const g = this.game, s = this.state(), pl = g.player;
    if (s.perks.vane) { pl.addCash(60); g.ui.toast('Harbor Pass: +$60 from the docks.', 'good'); }
    if (s.perks.omalley) { pl.addCash(40); g.ui.toast('Lumber Rights: +$40 from the sawmill.', 'good'); }
    const ruled = Object.keys(s.ruled).length;
    if (ruled) { const t = ruled * 150; pl.addCash(t); g.ui.toast(`Tribute from ${ruled} ${ruled > 1 ? 'cities' : 'city'}: +${R.fmtMoney(t)}`, 'good'); }
    for (const fam of FAMS) {
      const c = cityOf(fam);
      if (!c || s.ruled[c.id] || s.raided[fam]) continue;
      const dd = s.donDeadDay && s.donDeadDay[fam];
      if (this.donGone(fam) && dd != null && g.pop.day - dd >= 4) {
        const cands = (g.pop.byCity[c.id] || []).filter((p) => p.alive && !p.jailed && p.faction === fam && (p.role === 'capo' || p.role === 'soldier'));
        const heir = cands.find((p) => p.role === 'capo') || cands[0];
        if (!heir) continue;
        s.newDon = s.newDon || {};
        s.newDon[fam] = heir.id;
        this.applyDon(fam, heir.id);
        delete s.donDeadDay[fam];
        g.pop.addNews(c.id, `${heir.first} ${heir.last} is the new head of the ${fam} family. The funeral flowers are still fresh.`);
        g.ui.toast(`The ${PLF(fam)} have a new Don: ${heir.first} ${heir.last}.`, 'warn');
      }
    }
    // pressure fades if you let up
    for (const f in s.pressure) s.pressure[f] = Math.max(0, s.pressure[f] - 1);
  };
  C.applyDon = function (fam, id) {
    const g = this.game, c = cityOf(fam), p = g.pop.people[id];
    if (!c || !p || !p.alive) return;
    const club = clubOf(fam);
    p.isDon = true; p.role = 'don'; p.faction = fam;
    if (club) { p.work = club.id; p.home = club.id; club.owner = p.id; }
    c.don = p.id;
    g.life.cache.delete(p.id);
  };

  // ---------------------------------------------------------------- CROWN: take the cities
  C.control = function (fam) {
    const g = this.game, s = this.state(), c = cityOf(fam);
    if (!c) return 0;
    if (s.ruled[c.id]) return 100;
    const rackets = c.buildings.filter((b) => b && b.racket && b.racketFamily === g.player.family).length;
    return Math.min(100, Math.round((s.pressure[fam] || 0) + rackets * 9 + (this.donGone(fam) ? 30 : 0) + Math.max(0, g.jobs.rank() - 1) * 5));
  };
  C.takeover = function (fam, b) {
    const g = this.game, s = this.state(), pl = g.player, c = cityOf(fam), ui = g.ui;
    if (s.route === 'badge') return ui.toast('You\'re working for Rourke now. Kings don\'t wear wires.', 'warn');
    const ctl = this.control(fam), don = this.donOf(fam);
    if (this.donGone(fam)) return this.claim(c, fam);
    const own = fam === pl.family;
    const yields = own ? g.jobs.rank() >= 4 : ctl >= 90 || (ctl >= 70 && g.jobs.rank() >= 3);
    if (yields) {
      don.alive && (don.retired = true);
      ui.story(own ? 'THE CHAIR' : 'THE SIT-DOWN', own ? `Don ${don.last} looks at you for a long time, then laughs and pushes the ring across the table. "I'm tired. Take it. Visit me in Florida."` : `Don ${don.last} knows the numbers. His rackets pay you, his soldiers are dead or bought, and his town is yours in all but name. He signs it over and leaves for "the old country" by morning.`);
      don.jailed = g.pop.day + 100000; // gone from the coast
      return this.claim(c, fam);
    }
    // he says no
    ui.story('THE SIT-DOWN', `Don ${don.last} listens to your offer, smiles, and snaps his fingers.\n\n"Take this one outside."`);
    g.jobs.standing[fam] = -100;
    for (const a of g.actors.list) if (a.kind === 'h' && !a.dead && a.faction === fam && Math.hypot(a.x - pl.x, a.y - pl.y) < TS * 14) { a.hostile = true; g.actors.setFight(a, pl); }
  };
  C.claim = function (c, fam) {
    const g = this.game, s = this.state(), pl = g.player;
    s.ruled[c.id] = fam;
    s.ruledDay = s.ruledDay || {}; s.ruledDay[c.id] = g.pop.day + 1;
    this.applyRule(c);
    g.jobs.standing[fam] = 40;
    g.pop.addNews(c.id, `Word on the street: ${c.name} belongs to the ${pl.family} family now.`);
    g.audio.sfx('promote');
    const n = Object.keys(s.ruled).length;
    g.ui.story(`${c.name.toUpperCase()} IS YOURS`, `The ${fam} soldiers who are left kiss your ring. Every racket in ${c.name} pays you now: $150 a day in tribute.\n\nCities ruled: ${n} of ${FAMS.length}.`);
    if (n >= FAMS.length && !s.endings.crown) { s.endings.crown = 1; if (g.jobs.rank() < 5) { g.jobs.rep = Math.max(g.jobs.rep, 1600); } setTimeout(() => g.ui.story('CROWN: KING OF THE BRASS COAST', 'Port Hollow, New Avalon, Dustwater, Pinecrest and Bayou Clair. Every docks crane, casino chip, gold bar, sawmill and bayou shack pays the same boss.\n\nYou.\n\nThe game goes on. Somebody always wants the crown.'), 500); }
  };
  C.applyRule = function (c) {
    if (!c) return;
    const g = this.game, pl = g.player, s = this.state(), old = s.ruled[c.id];
    c.ruler = pl.family;
    for (const p of g.pop.byCity[c.id] || []) if (p.alive && p.faction === old) p.faction = pl.family;
    for (const a of g.actors.list) if (a.kind === 'h' && a.faction === old && g.world.cityAt((a.x / TS) | 0, (a.y / TS) | 0) === c) { a.faction = pl.family; a.hostile = false; if (a.state === 'fight' && a.target === pl) a.state = 'idle'; }
    for (const b of c.buildings) if (b && (b.type === 'social' || b.racket)) { if (b.type === 'social') b.playerOwned = true; }
    g.miniDirty = true;
  };

  // ---------------------------------------------------------------- BADGE: work with the cops
  C.addEvidence = function (fam, n, what) {
    const s = this.state();
    s.evidence[fam] = Math.min(3, (s.evidence[fam] || 0) + n);
    this.game.ui.toast(`${what}: evidence on the ${PLF(fam)} ${s.evidence[fam]}/3.`, 'good');
  };
  C.becomeInformant = function () {
    const g = this.game, s = this.state();
    if (Object.keys(s.ruled).length) return g.ui.toast('Rourke laughs. "You run a city. You\'re the one I want in cuffs."', 'warn');
    if (g.law.totalBounty() > 0) return g.ui.toast('"Clear your bounties first. I don\'t work with wanted men."', 'warn');
    s.route = 'badge';
    g.audio.sfx('accept');
    g.ui.story('BADGE: THE DEAL', 'Detective Rourke slides a wire across the table. "Evidence on all five families: three pieces each. Wear this to a sit-down, crack a back-office safe, or photograph a deal. Bring me a full file and I\'ll bring the whole family in."\n\n"I\'ll make your little bounties go away, one a day. Get made, and you\'re on your own."\n\nTalk shop with each don wearing the wire, crack their safes, or ask Rourke for a stakeout.');
  };
  C.stakeout = function (fam) {
    const g = this.game, s = this.state();
    if (s.active) return g.ui.toast('Finish what you\'re doing first.', 'warn');
    const at = outskirts(fam, 10);
    // a one-step mission reusing the engine
    SAGAS.__stake = { title: 'Stakeout', acts: [{ title: `Stakeout: the ${PLF(fam)}`, brief: '', steps: [{ k: 'stake', at, enemy: fam, text: `Photograph the ${fam} deal outside ${cityOf(fam).name}. Stay within 10 tiles, never closer than 3, for six seconds.` }], cash: 150, rep: 0 }] };
    s.active = { fam: '__stake', act: 0, step: 0 };
    this.run = null;
    g.ui.story('STAKEOUT', `Rourke: "The ${PLF(fam)} are moving something outside ${cityOf(fam).name} tonight. Get me pictures. Don't get close, and don't get seen."`);
  };
  C.wire = function (fam, b) {
    const g = this.game, s = this.state(), ui = g.ui;
    if (s.wireDay[fam] === g.pop.day) return ui.toast('Twice in one day and he\'d get suspicious.', 'warn');
    if (s.blown[fam]) return ui.toast('They know about the wire. The door stays shut.', 'bad');
    s.wireDay[fam] = g.pop.day;
    s.suspicion[fam] = s.suspicion[fam] || 0;
    const don = this.donOf(fam);
    let round = 0;
    const Qs = [
      ['"How\'s business?"', '"Business is business. The docks, the tables, the usual."', 1, 8],
      ['"Who handled that thing last month?"', `"Thing? What thing? ...Ah, my nephew. Clean work, too."`, 1, 22],
      ['"Where do you keep the books?"', '"Why do you care where I keep the books?"', 2, 38],
      ['"I hear the cops are sniffing around."', '"Let them sniff. Captain eats at my table every Sunday."', 1, 15],
      ['"Who\'d you have to pay off for the casino permit?"', '"You ask a lot of questions for a guest."', 2, 34],
    ];
    const ask = () => {
      round++;
      const pool = R.rng.shuffle ? R.rng.shuffle(Qs.slice()) : Qs.slice().sort(() => R.rng() - 0.5);
      const opts = pool.slice(0, 3).map(([q, a, ev, sus]) => ({ label: q, small: sus > 30 ? 'Risky' : sus > 15 ? 'Careful' : 'Safe', fn: () => {
        s.suspicion[fam] += sus + R.rng.int(-4, 6);
        if (s.suspicion[fam] >= 100) return blown();
        if (R.rng() < 0.75) this.addEvidence(fam, ev, 'On tape');
        ui.toast(`Don ${don.last}: ${a}`, s.suspicion[fam] > 60 ? 'warn' : '');
        if (round < 3) setTimeout(ask, 50); else ui.toast(`He walks you to the door. Suspicion: ${Math.round(s.suspicion[fam])}%.`);
      } }));
      opts.push({ label: 'Change the subject', small: 'Suspicion down', fn: () => { s.suspicion[fam] = Math.max(0, s.suspicion[fam] - 15); if (round < 3) setTimeout(ask, 50); } });
      ui.choice(`Wired sit-down with Don ${don.last} (${round}/3) · suspicion ${Math.round(s.suspicion[fam])}%`, opts);
    };
    const blown = () => {
      s.blown[fam] = true;
      g.jobs.standing[fam] = -100;
      ui.story('MADE!', `Don ${don.last}'s hand stops halfway to his glass. "Open your shirt."\n\nYou run.`);
      for (const a of g.actors.list) if (a.kind === 'h' && !a.dead && a.faction === fam) { a.hostile = true; g.actors.setFight(a, g.player); }
    };
    ask();
  };
  C.safe = function (fam) {
    const g = this.game, s = this.state();
    s.safeDay = s.safeDay || {};
    if (s.safeDay[fam] === g.pop.day) return g.ui.toast('Somebody\'s in the back office now. Try tomorrow.', 'warn');
    s.safeDay[fam] = g.pop.day;
    const done = (ok) => {
      if (ok) this.addEvidence(fam, 2, 'The ledgers');
      else { s.suspicion[fam] = (s.suspicion[fam] || 0) + 40; g.ui.toast(`Footsteps. You get out fast. Suspicion ${Math.round(s.suspicion[fam])}%.`, 'warn'); if (s.suspicion[fam] >= 100) { s.blown[fam] = true; g.jobs.standing[fam] = -100; } }
    };
    if (R.mini && R.mini.safe) R.mini.safe({}, (ok) => done(!!ok));
    else done(R.rng() < 0.6);
  };
  C.raid = function (fam) {
    const g = this.game, s = this.state(), pl = g.player, c = cityOf(fam);
    s.raided[fam] = g.pop.day + 1;
    s.evidence[fam] = 0;
    const don = this.donOf(fam);
    let n = 0;
    for (const p of g.pop.byCity[c.id] || []) if (p.alive && p.faction === fam && (p.isDon || p.role === 'capo' || (p.role === 'soldier' && R.rng() < 0.7))) { p.jailed = g.pop.day + 100000; n++; if (p.actor && !p.actor.dead) g.actors.remove(p.actor); }
    g.jobs.standing[fam] = -100;
    pl.addCash(600);
    for (const j in g.law.bounty) g.law.bounty[j] = 0;
    g.pop.addNews(c.id, `DAWN RAIDS: ${n} members of the ${fam} family arrested${don ? `, including ${don.first} ${don.last}` : ''}. Police credit "a confidential source".`);
    g.audio.sfx('promote');
    const done = FAMS.filter((f) => s.raided[f]).length;
    g.ui.story('RAID', `At dawn, forty cops hit every ${fam} address in ${c.name} at once. ${n} arrests. Rourke hands you an envelope with $600 in it and wipes your record clean.\n\nFamilies behind bars: ${done} of ${FAMS.length}.${fam !== pl.family && !s.raided[pl.family] ? `\n\nThe ${PLF(pl.family)} are asking how the cops knew so much.` : ''}`);
    if (fam !== pl.family) g.jobs.standing[pl.family] = Math.max(-100, (g.jobs.standing[pl.family] || 0) - 15);
    if (done >= FAMS.length && !s.endings.badge) { s.endings.badge = 1; setTimeout(() => g.ui.story('BADGE: WITNESS PROTECTION', 'All five families are behind bars. Your testimony runs for eleven weeks.\n\nAfterwards Rourke hands you a new driver\'s license, a new name and a key to a bungalow somewhere much too sunny.\n\n"Keep your head down. Somebody always gets out."\n\nThe game goes on. So does the coast, quieter now.'), 500); }
  };

  // ---------------------------------------------------------------- menus
  C.sagaOption = function (fam) {
    const saga = SAGAS[fam], i = this.sagaAct(fam), s = this.state();
    if (!saga) return null;
    if (s.active && s.active.fam === fam) return { label: `${saga.title}: ${saga.acts[s.active.act].title}`, small: 'In progress · tap to walk away', cls: 'bad', fn: () => this.abandon() };
    if (i >= saga.acts.length) return null;
    const ok = this.canStart(fam);
    return { label: `Family business: ${saga.title} ${i + 1}/3 · ${saga.acts[i].title}`, small: ok.ok ? 'A big job. The kind people remember.' : ok.why, cls: ok.ok ? 'go' : '', fn: () => { if (ok.ok) this.start(fam); else this.game.ui.toast(ok.why, 'warn'); } };
  };
  C.routeOptions = function (fam) {
    const g = this.game, s = this.state(), out = [];
    const c = cityOf(fam);
    if (!c) return out;
    if (s.route === 'badge') {
      if (!s.raided[fam]) {
        out.push({ label: `Talk shop with Don ${this.donOf(fam) ? this.donOf(fam).last : ''} (wire running)`, small: `Evidence ${s.evidence[fam] || 0}/3 · suspicion ${Math.round(s.suspicion[fam] || 0)}%`, fn: () => { g.ui.closeSheet(); this.wire(fam); } });
        out.push({ label: 'Slip into the back office', small: 'Crack the safe for the ledgers', fn: () => { g.ui.closeSheet(); this.safe(fam); } });
      }
    } else if (!s.ruled[c.id]) {
      const ctl = this.control(fam);
      if (ctl >= 70 || (this.donGone(fam) && ctl >= 40) || (fam === g.player.family && g.jobs.rank() >= 4)) out.push({ label: fam === g.player.family ? `Ask Don ${g.jobs.donName(fam)} to step aside` : `Take over ${c.name}`, small: `Control ${ctl}%`, cls: 'bad', fn: () => { g.ui.closeSheet(); this.takeover(fam); } });
    }
    return out;
  };
  C.interiorOpts = function (b, all) {
    const g = this.game, s = this.state();
    const leave = all.length && /^Leave/.test(all[all.length - 1].label) ? all.pop() : null;
    const opts = all;
    try { this.interiorOpts2(b, opts, g, s); } finally { if (leave) all.push(leave); }
  };
  C.interiorOpts2 = function (b, opts, g, s) {
    if (b.type === 'social' && b.city && b.city.def && b.city.def.family) {
      const fam = b.city.def.family;
      if (!this.donGone(fam) && !s.raided[fam]) { const o = this.sagaOption(fam); if (o) opts.push(o); }
      for (const o of this.routeOptions(fam)) opts.push(o);
    }
    if (b.type === 'police') {
      if (s.route !== 'badge') opts.push({ label: 'Ask for Detective Rourke', small: 'Work with the cops', fn: () => g.ui.choice('Detective Rourke', [
        { label: '"I want to talk about the families."', small: 'Become an informant. The families will never forgive it.', fn: () => this.becomeInformant() },
        { label: '"Never mind."', fn: () => {} },
      ]) });
      else {
        for (const fam of FAMS) if ((s.evidence[fam] || 0) >= 3 && !s.raided[fam]) opts.push({ label: `Hand over the ${fam} file`, small: 'Rourke brings them all in at dawn', cls: 'go', fn: () => { g.ui.closeSheet(); this.raid(fam); } });
        opts.push({ label: 'Ask Rourke for a stakeout', small: 'Photograph a deal', fn: () => g.ui.choice('Which family?', FAMS.filter((f) => !s.raided[f] && (s.evidence[f] || 0) < 3).map((f) => ({ label: `The ${PLF(f)}`, fn: () => { g.ui.closeSheet(); this.stakeout(f); } }))) });
        if (s.fixDay !== g.pop.day && g.law.totalBounty() > 0) opts.push({ label: 'Have Rourke lose a bounty', small: 'Once a day', fn: () => { s.fixDay = g.pop.day; const j = Object.keys(g.law.bounty).find((k) => g.law.bounty[k] > 0); if (j) g.law.bounty[j] = 0; g.ui.toast('"Paperwork gets lost all the time."', 'good'); } });
      }
    }
  };
  C.donOpts = function (h, opts) {
    const fam = h.person.faction;
    if (!fam || !SAGAS[fam]) return;
    const o = this.sagaOption(fam);
    const at = Math.max(0, opts.length - 1);
    if (o) opts.splice(at, 0, o);
    for (const r of this.routeOptions(fam)) opts.splice(at, 0, r);
  };

  // ---------------------------------------------------------------- the Jobs tab
  C.jobsHtml = function () {
    const g = this.game, s = this.state(), cur = this.current();
    let h = '';
    if (cur) {
      const r = this.run;
      const extra = cur.step.k === 'defend' && r && r.left != null ? ` (${Math.max(0, Math.ceil(r.left))}s, wave ${r.wave || 0}/${cur.step.waves})` : cur.step.k === 'drive' && r && r.leftMin != null ? ` (${Math.max(0, Math.round(r.leftMin))} min)` : '';
      h += `<div class="sect">${SAGAS[cur.fam].story ? esc(SAGAS[cur.fam].who) : 'Family business'}</div><p style="font-size:15px"><b>${esc(cur.act.title)}</b><br>${esc(cur.step.text)}${extra}</p>`;
    }
    h += '<div class="sect">The family sagas</div>';
    for (const f of FAMS) { const i = this.sagaAct(f), sg = SAGAS[f]; h += `<p>• <span style="color:${FAMCOLOR[f]}">■</span> <b>${esc(sg.title)}</b> (${esc(f)}): ${i >= 3 ? 'complete ✓' : `act ${i + 1}/3, ${esc(sg.acts[i].title)}`}${s.perks[f === "O'Malley" ? 'omalley' : f.toLowerCase()] ? ' · perk earned' : ''}</p>`; }
    if (R.stories) h += R.stories.jobsHtml(esc);
    h += '<div class="sect">Roads to the top</div>';
    h += `<p><b>BLOOD:</b> kill every don. ${FAMS.map((f) => `${esc(f)} ${s.dons[f] ? '✗' : this.donGone(f) ? '—' : '●'}`).join(' · ')}${s.endings.blood ? ' · <b>done</b>' : ''}</p>`;
    h += `<p><b>CROWN:</b> take each city. ${FAMS.map((f) => { const c = cityOf(f); return `${esc(c ? c.name : f)} ${s.ruled[c && c.id] ? '♛' : this.control(f) + '%'}`; }).join(' · ')}<br><small>Control rises with your rackets there, soldiers you put down, a dead don and your rank. At 70% take it at their social club.</small></p>`;
    h += `<p><b>BADGE:</b> ${s.route === 'badge' ? FAMS.map((f) => `${esc(f)} ${s.raided[f] ? 'jailed' : (s.evidence[f] || 0) + '/3'}`).join(' · ') : 'ask for Detective Rourke at any police station.'}</p>`;
    return h;
  };
  C.rulerColor = function (city) { return city.ruler ? FAMCOLOR[city.ruler] || city.def.color : city.def.color; };
})();
