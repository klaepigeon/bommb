// RHAPSODY — the task force. Every murder you get away with leaves a signature: how they
// died, what was done to them, where they ended up, who they were, where and when. Bodies
// surface: the ones you left, the ones you hid badly, the ones the tide brings back. When
// three unsolved bodies look alike, the police stop treating them as separate crimes. The
// papers give the killer a name; a profile gets printed, right or wrong; and the city
// changes: curfews, extra patrols, undercover decoys, stop-and-frisks, cops watching the
// old dump sites. Change your habits and the profile blurs. Keep them and they narrow in
// on you. If they ever prove it's you, there's no fine to pay: it's death row.
'use strict';
(function () {
  const D = R.data, TS = R.TILE;
  const G = () => R.game;
  const SK = (R.profile = { live: [], runtime: new Map() });
  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
  const TRAITS = ['weapon', 'cut', 'dump', 'sex', 'age', 'city', 'time'];
  const LABEL = {
    weapon: { blade: 'uses a blade', gun: 'uses a handgun', shotgun: 'uses a shotgun', rifle: 'uses a rifle', blunt: 'beats them to death', silent: 'kills quietly: a silencer or a crossbow', hands: 'uses his hands', car: 'runs them down' },
    cut: { none: 'leaves the bodies whole', head: 'takes the heads', limbs: 'dismembers the bodies', skin: 'skins them', burst: 'destroys the face' },
    dump: { left: 'leaves them where they fall', trash: 'dumps them in the trash', water: 'puts them in the water', brush: 'hides them in the brush', bag: 'bags the remains', trunk: 'moves them by car' },
    sex: { m: 'targets men', f: 'targets women' },
    age: { young: 'prefers young victims', mid: 'prefers victims in middle age', old: 'preys on the elderly' },
    time: { night: 'strikes at night', day: 'strikes in broad daylight' },
  };

  SK.state = function () { const pl = G().player; return (pl.killer = pl.killer || { pending: [], unsolved: [], profile: null, sites: [], poi: 0, linked: false, history: [] }); };
  const weaponOf = (w, kind) => {
    const d = D.weapons[w];
    if (kind === 'car') return 'car';
    if (!d || w === 'fists' || w === 'knuckles') return 'hands';
    if (d.silent || (G().player.silencedGun && G().player.silencedGun(w))) return 'silent';
    if (d.blade) return 'blade';
    if (d.pellets) return 'shotgun';
    if (w === 'rifle' || w === 'carbine') return 'rifle';
    if (d.gun) return 'gun';
    return 'blunt';
  };

  // ---------------------------------------------------------------- a murder
  SK.onMurder = function (victim, kind) {
    const g = G(), pl = g.player, s = this.state();
    if (!victim || !victim.person) return;
    const p = victim.person, hr = g.clock.hour(), c = g.world.cityAt((victim.x / TS) | 0, (victim.y / TS) | 0);
    const sig = { pid: p.id, day: g.pop.day, weapon: weaponOf(pl.weapon, kind), cut: 'none', dump: 'left', sex: p.fem ? 'f' : 'm', age: p.age < 30 ? 'young' : p.age < 55 ? 'mid' : 'old', city: c ? c.id : 'county', time: hr >= 20 || hr < 6 ? 'night' : 'day', x: victim.x, y: victim.y };
    s.pending.push(sig);
    this.runtime.set(p.id, victim);
  };
  // how the body ended up, read off the actor
  SK.refresh = function (sig) {
    const a = this.runtime.get(sig.pid);
    if (!a) return;
    const w = a.wnd || {};
    sig.cut = w.flayed ? 'skin' : w.limbs ? 'limbs' : w.burst ? 'burst' : w.headless ? 'head' : 'none';
    if (a.sunk) sig.dump = 'water';
    else if (a.hidden && a.trashed) sig.dump = 'trash';
    else if (a.hidden && !a.removed) sig.dump = 'brush';
    else if (a.hidden) sig.dump = a.inTrunk ? 'trunk' : 'trash';
    else if (a.removed && w.limbs) sig.dump = 'bag';
    if (!a.removed) { sig.x = a.x; sig.y = a.y; }
  };

  // ---------------------------------------------------------------- bodies surfacing
  SK.poll = function () {
    const g = G(), s = this.state();
    for (const sig of s.pending.slice()) {
      this.refresh(sig);
      const a = this.runtime.get(sig.pid);
      if (a && a.found && !a.hidden) this.discovered(sig, 'found');
    }
  };
  SK.dailyDiscovery = function () {
    const s = this.state();
    for (const sig of s.pending.slice()) {
      this.refresh(sig);
      const chance = { left: 0.6, brush: 0.12, trash: 0.25, water: 0.08, bag: 0.05, trunk: 0.03 }[sig.dump] || 0.1;
      if (R.rng() < chance) this.discovered(sig, sig.dump);
      else if (G().pop.day - sig.day > 25) s.pending.splice(s.pending.indexOf(sig), 1); // never found
    }
  };
  SK.discovered = function (sig, how) {
    const g = G(), pl = g.player, s = this.state();
    s.pending.splice(s.pending.indexOf(sig), 1);
    this.runtime.delete(sig.pid);
    const p = g.pop.people[sig.pid];
    // a case that already names you isn't a mystery
    const known = R.cases && R.cases.state().list.some((c) => c.body && c.body.pid === sig.pid && c.witnesses.some((x) => !x.masked && !x.gone));
    if (known) return;
    if (how !== 'found') g.pop.addNews(sig.city === 'county' ? 'port' : sig.city, { water: `A body washed up ${R.rng.pick(['under the pier', 'on the mudflats', 'against the dam'])}. ${p && p.unidentified ? 'Police have not identified the victim.' : `Relatives identified ${p ? p.first + ' ' + p.last : 'the victim'}.`}`, trash: 'Sanitation crew finds human remains in a dumpster. Police are asking the public for help.', brush: 'Dog walker finds a body in the brush. "I\'ll never walk that way again."', bag: 'Garbage bags full of human remains found. Police won\'t say how many.', trunk: 'Body found in the trunk of an abandoned car.' }[how] || 'Another body found.');
    // near the scene when they find it? That gets noticed
    if (R.dist(pl.x, pl.y, sig.x, sig.y) < TS * 8 && !pl.room) this.suspect(12, 'You were near the scene when they found the body.');
    s.sites.unshift({ x: sig.x, y: sig.y, city: sig.city, dump: sig.dump, day: g.pop.day });
    if (s.sites.length > 8) s.sites.pop();
    s.unsolved.push(sig);
    if (s.unsolved.length > 40) s.unsolved.shift();
    this.link(sig);
  };
  const sim = (a, b) => TRAITS.reduce((n, t) => n + (a[t] === b[t] ? 1 : 0), 0);
  SK.link = function (sig) {
    const g = G(), s = this.state();
    const P = s.profile;
    if (P && P.phase !== 'closed') {
      const match = sim(sig, P.traits);
      if (match >= 4 || (P.phase === 'wrongman' && match >= 3)) {
        P.bodies.push(sig.pid);
        P.heat = Math.min(100, P.heat + 30);
        if (P.phase === 'wrongman') { P.phase = 'active'; P.heat = Math.min(100, P.heat + 30); g.pop.addNews(P.city, `THE ${P.name.toUpperCase()} STRIKES AGAIN. Police admit the man in custody "may not be responsible". His lawyer is furious.`); g.ui.toast(`The ${P.name} is back in the papers. They know they got the wrong man.`, 'bad'); }
        else g.pop.addNews(P.city, `Police link a ${this.ord(P.bodies.length)} death to the ${P.name}.`);
        this.retrace(P);
        this.suspect(4);
      } else if (match >= 2) {
        P.confidence = Math.max(10, P.confidence - 8);
        g.pop.addNews(P.city, `Is it the ${P.name}, or a copycat? Detectives are divided.`);
      }
      return;
    }
    // three alike and the task force forms
    const group = s.unsolved.filter((o) => sim(o, sig) >= 4 && g.pop.day - o.day < 60);
    if (group.length >= 3) {
      const traits = {};
      for (const t of TRAITS) { const n = {}; for (const o of group) n[o[t]] = (n[o[t]] || 0) + 1; traits[t] = Object.entries(n).sort((a, b) => b[1] - a[1])[0][0]; }
      const city = traits.city === 'county' ? 'port' : traits.city;
      const P2 = { name: this.nickname(traits), traits, conf: {}, confidence: 60, bodies: group.map((o) => o.pid), heat: 60, city, phase: 'active', day: g.pop.day, lastBody: g.pop.day, measures: {} };
      s.profile = P2;
      this.retrace(P2);
      g.pop.addNews(city, `POLICE: ONE KILLER. ${group.length} deaths now linked. The press calls him "the ${P2.name}". A task force of forty officers is on the case.`);
      g.ui.story(`THE ${P2.name.toUpperCase()}`, `The police have linked ${group.length} of your killings. The papers have a name for you now.\n\nA task force is working the city: more patrols after dark, a curfew, and plenty of things they won't tell the papers. Check the Heat tab for the profile they printed. It's what they think they know.`);
      this.apply(P2);
    }
  };
  SK.retrace = function (P) {
    const s = this.state(), bodies = s.unsolved.filter((o) => P.bodies.includes(o.pid));
    for (const t of TRAITS) { const n = {}; for (const o of bodies) n[o[t]] = (n[o[t]] || 0) + 1; const top = Object.entries(n).sort((a, b) => b[1] - a[1])[0]; if (top) { P.traits[t] = top[0]; P.conf[t] = Math.round(100 * top[1] / bodies.length); } }
    P.lastBody = G().pop.day;
  };
  SK.ord = (n) => ['', 'first', 'second', 'third', 'fourth', 'fifth', 'sixth', 'seventh', 'eighth', 'ninth', 'tenth'][n] || `${n}th`;
  SK.nickname = function (t) {
    const place = { port: 'Harbor', avalon: 'Neon', dust: 'Desert', pine: 'Timber', bayou: 'Bayou', county: 'Backroad' }[t.city] || 'Night';
    const what = t.cut === 'skin' ? 'Tanner' : t.cut === 'limbs' ? 'Butcher' : t.cut === 'head' ? 'Headhunter' : t.cut === 'burst' ? 'Faceless Killer' : t.dump === 'water' ? 'Drowner' : t.dump === 'trash' ? 'Trash Man' : t.weapon === 'blade' ? 'Ripper' : t.weapon === 'silent' ? 'Whisper' : t.weapon === 'hands' ? 'Strangler' : t.weapon === 'shotgun' ? 'Slaughterer' : t.weapon === 'blunt' ? 'Hammer' : 'Stalker';
    return `${t.time === 'night' && R.rng() < 0.5 ? 'Midnight' : place} ${what}`;
  };

  // ---------------------------------------------------------------- the city reacts
  SK.apply = function (P) {
    const g = G();
    for (const c of g.world.cities) c.curfew = false;
    if (!P || P.phase !== 'active') return;
    const c = g.world.cities.find((x) => x.id === P.city);
    if (c && P.heat > 20) c.curfew = true;
    if (c) c.fear = Math.min(100, (c.fear || 0) + 5);
  };
  SK.daily = function () {
    const g = G(), s = this.state(), P = s.profile;
    this.dailyDiscovery();
    s.poi = Math.max(0, s.poi - 3);
    if (P && P.phase === 'active') {
      P.heat = Math.max(0, P.heat - 4);
      const quiet = g.pop.day - P.lastBody;
      // the wrong man
      if (P.heat > 30 && s.poi < 40 && quiet > 4 && R.rng() < 0.12) {
        const pool = g.pop.people.filter((q) => q.alive && q.city === P.city && !q.isDon && q.age > 22 && q.age < 60 && !q.met && (P.traits.sex === 'f' ? true : !q.fem));
        const q = R.rng.pick(pool);
        if (q) { q.jailed = g.pop.day + 10000; P.phase = 'wrongman'; P.wrong = g.pop.name(q); P.heat = 10; g.pop.addNews(P.city, `ARREST IN ${P.name.toUpperCase()} CASE. Police charge ${P.wrong}, ${q.age}, a ${g.pop.title(q)}. Neighbours "always knew something was off".`); g.ui.toast(`They arrested ${P.wrong} for your murders. The task force is standing down.`, 'good'); }
      }
      if (P.heat <= 0 && quiet > 20) { P.phase = 'closed'; g.pop.addNews(P.city, `The ${P.name} task force is quietly disbanded. The file stays open.`); }
    }
    this.apply(P);
  };
  SK.suspect = function (n, why) {
    const g = G(), s = this.state();
    if (s.linked) return;
    s.poi = Math.min(100, s.poi + n);
    if (why && n >= 10) g.ui.toast(`${why} (person of interest ${Math.round(s.poi)}%)`, 'warn');
    if (s.poi >= 100) this.name();
  };
  SK.name = function () {
    const g = G(), s = this.state(), P = s.profile, pl = g.player;
    if (s.linked) return;
    s.linked = true;
    const title = P ? `the ${P.name}` : 'a serial killer';
    g.pop.addNews(P ? P.city : 'avalon', `POLICE NAME SUSPECT: The man they call ${title} is young, well-dressed, and connected. Do not approach him.`);
    g.ui.story('THEY KNOW', `The task force has put it together. Your picture is in every patrol car on the coast as ${title}.\n\nIf they take you alive, there's no bail and no fine. It's death row.`);
    for (const c of g.world.cities) g.law.bounty[c.id] = (g.law.bounty[c.id] || 0) + 500;
    pl.rep.infamy += 25;
  };

  // ---------------------------------------------------------------- measures on the street
  const spawnCop = (x, y, plain) => {
    const g = G();
    const s = g.world.findNear(x | 0, y | 0, 0, 6, (xx, yy) => !g.world.solidPed(xx, yy) && !g.world.isWater(xx, yy));
    if (!s) return null;
    const h = plain ? g.actors.makeHuman(s.x * TS + 8, s.y * TS + 8, { arch: 'square', cash: 30 }) : g.actors.makeHuman(s.x * TS + 8, s.y * TS + 8, { cop: true });
    h.keep = true; h.taskForce = true;
    SK.live.push(h);
    return h;
  };
  SK.update = function (dt) {
    const g = G(), pl = g.player, s = this.state(), P = s.profile;
    this.pt = (this.pt || 0) - dt;
    if (this.pt <= 0) { this.pt = 2; this.poll(); }
    this.live = this.live.filter((h) => !h.dead && !h.removed && (Math.hypot(h.x - pl.x, h.y - pl.y) < TS * 50 || (h.keep = false)));
    // a decoy gets hit: the trap springs
    for (const h of this.live) if (h.decoy && !h.sprung && (h.hp < h.maxHp || h.dead || h.tied || h.down > 0 || h.carried)) this.spring(h);
    if (!P || P.phase !== 'active' || pl.room || pl.dead) return;
    const c = g.world.cityAt((pl.x / TS) | 0, (pl.y / TS) | 0);
    if (!c || c.id !== P.city) return;
    const hr = g.clock.hour(), night = hr >= 20 || hr < 6, hunting = (P.traits.time === 'night') === night;
    this.mt = (this.mt == null ? 20 : this.mt) - dt;
    if (this.mt > 0) return;
    this.mt = 45 + R.rng() * 45;
    const px = pl.x / TS, py = pl.y / TS;
    const sp = g.world.findNear(px, py, 10, 16, (x, y) => !g.world.solidPed(x, y) && !g.world.isWater(x, y) && D.roadTile[g.world.t(x, y)]);
    if (!sp) return;
    const r = R.rng();
    const cops = this.live.filter((h) => h.cop).length;
    if (P.heat > 20 && cops < 4 && r < 0.45) {
      // extra patrols walk the beat
      const a = spawnCop(sp.x, sp.y), b = spawnCop(sp.x + 1, sp.y);
      if (a) g.actors.say(a, R.rng.pick([`Task force. Everybody off the street after nine.`, `Keep your eyes open. The ${P.name} works this side of town.`]));
    } else if (P.heat > 40 && hunting && r < 0.7 && !this.live.some((h) => h.decoy)) {
      // someone who looks exactly like his type, alone. Too alone
      const h = spawnCop(sp.x, sp.y, true);
      if (h) {
        h.decoy = true; h.look.fem = P.traits.sex === 'f'; h.look.old = null;
        if (h.person) h.person = null;
        h.strangerName = null;
      }
    } else if (P.heat > 60 && hunting && !g.law.incident && cops < 4 && P.friskDay !== g.pop.day) { P.friskDay = g.pop.day; this.frisk(sp); }
  };
  SK.spring = function (h) {
    const g = G(), pl = g.player, s = this.state();
    h.sprung = true;
    if (!h.dead && h.down <= 0 && !h.tied) { h.cop = true; h.hostile = true; g.actors.arm(h, 'revolver'); g.actors.say(h, 'POLICE! It\'s him! Move in, move in!'); g.actors.setFight(h, pl); }
    for (let i = 0; i < 3; i++) { const c = spawnCop(h.x / TS + R.rng.int(-6, 6), h.y / TS + R.rng.int(-6, 6)); if (c) g.actors.setFight(c, pl); }
    g.law.startIncident({ type: 'murder', def: g.law.CRIMES.murder, x: pl.x, y: pl.y, jur: g.law.jurAt(pl.x, pl.y), identified: !pl.masked, lvl: 3, bounty: 200, t: g.clock.t }, null);
    g.ui.toast('A decoy! Plainclothes cops pour out of a parked van.', 'bad');
    this.suspect(pl.masked ? 30 : 60, 'You went for the task force\'s decoy.');
  };
  // "Evening, sir. Mind if we take a look?"
  SK.frisk = function (sp) {
    const g = G(), pl = g.player, s = this.state(), P = s.profile, ui = g.ui;
    const a = spawnCop(sp.x, sp.y), b = spawnCop(sp.x + 1, sp.y);
    if (!a) return;
    const hot = () => {
      const items = [];
      const wt = P.traits.weapon;
      for (const id in pl.inv.weapons) if (weaponOf(id) === wt && id !== 'fists') items.push(D.weapons[id].name);
      if (pl.inv.tools.remains) items.push('a garbage bag you don\'t want them to open');
      if (pl.bloody > 0.3) items.push('blood on your cuffs');
      if (pl.carrying) items.push('a body on your shoulder');
      return items;
    };
    setTimeout(() => {
      if (pl.dead || pl.room || g.law.incident) return;
      g.actors.say(a, 'Evening. Task force. Hands where I can see them.');
      ui.choice('Stop and frisk', [
        { label: 'Let them search you', small: 'If you\'re clean, you\'re clean', fn: () => { const h = hot(); if (!h.length) { g.actors.say(a, 'Alright. Get home, it\'s not safe out here.'); return; } const bad = h.some((x) => /bag|blood|body/.test(x)); if (bad || s.poi > 60) { g.actors.say(a, 'Well, well. Turn around, slowly.'); this.suspect(bad ? 100 : 40); g.law.startIncident({ type: 'murder', def: g.law.CRIMES.murder, x: pl.x, y: pl.y, jur: g.law.jurAt(pl.x, pl.y), identified: true, lvl: 2, bounty: 100, t: g.clock.t }, a); } else { g.actors.say(a, `Carrying a ${h[0]}, huh. We'll remember your face.`); this.suspect(25, `They found your ${h[0]}. It matches the profile.`); } } },
        { label: 'Slip them something ($200)', small: 'Most cops have a mortgage', fn: () => { if (!pl.pay(200) || R.rng() < 0.3) { g.actors.say(a, 'Bribing an officer? On this case?'); this.suspect(30, 'They didn\'t take the money.'); return; } g.actors.say(a, 'Didn\'t see you. Get going.'); } },
        { label: 'Run', small: 'They\'ll chase you, and they\'ll wonder why', fn: () => { this.suspect(20, 'Innocent men don\'t run.'); g.law.startIncident({ type: 'jailbreak', def: g.law.CRIMES.jailbreak, x: pl.x, y: pl.y, jur: g.law.jurAt(pl.x, pl.y), identified: !pl.masked, lvl: 1, bounty: 20, t: g.clock.t }, a); } },
      ]);
    }, 1400);
  };
  // dumping where they're watching
  SK.watched = function (pl) {
    const g = G(), s = this.state(), P = s.profile;
    if (!P || P.phase !== 'active' || P.heat < 30) return null;
    return s.sites.find((x) => R.dist(x.x, x.y, pl.x, pl.y) < TS * 12 && g.pop.day - x.day < 14);
  };
  SK.caughtDumping = function () {
    const g = G(), pl = g.player;
    const h = spawnCop(pl.x / TS + 4, pl.y / TS + 2, true);
    if (h) { h.cop = true; g.actors.arm(h, 'revolver'); g.actors.say(h, 'Don\'t move! We\'ve been sitting on this spot for a week!'); g.actors.setFight(h, pl); }
    g.law.startIncident({ type: 'murder', def: g.law.CRIMES.murder, x: pl.x, y: pl.y, jur: g.law.jurAt(pl.x, pl.y), identified: !pl.masked, lvl: 3, bounty: 250, t: g.clock.t }, h);
    this.suspect(100);
  };

  // ---------------------------------------------------------------- the heat tab
  SK.html = function () {
    const g = G(), s = this.state(), P = s.profile;
    if (!P && !s.unsolved.length) return '';
    let h = '<div class="sect">The task force</div>';
    if (!P) return h + `<p style="font-size:13px">${s.unsolved.length} unsolved killing${s.unsolved.length > 1 ? 's' : ''} on the books. Nobody has connected them. Yet.</p>`;
    const c = g.world.cities.find((x) => x.id === P.city);
    h += `<p><b style="font-size:16px">The ${esc(P.name)}</b> · ${P.bodies.length} linked · ${P.phase === 'active' ? `<span style="color:var(--red)">active in ${esc(c ? c.name : '')}</span>` : P.phase === 'wrongman' ? `they charged ${esc(P.wrong)}` : 'task force disbanded'}</p>`;
    h += '<p style="font-size:13px;color:var(--brown)">The profile they printed:</p>';
    for (const t of TRAITS) { if (t === 'city') continue; const v = P.traits[t], conf = P.conf[t] || 50; h += `<p style="margin:2px 0">${conf >= 75 ? '●' : conf >= 50 ? '◐' : '○'} The killer ${esc((LABEL[t] || {})[v] || v)}</p>`; }
    if (P.phase === 'active') h += `<p style="font-size:13px">On the street: ${P.heat > 20 ? 'curfew and extra patrols' : 'routine patrols'}${P.heat > 40 ? ', decoys' : ''}${P.heat > 60 ? ', stop-and-frisk' : ''}${P.heat > 30 ? ', stakeouts at old dump sites' : ''}. Break the pattern and the profile gets blurry.</p>`;
    h += `<p>Person of interest</p><div class="meter" style="width:100%"><i style="width:${Math.round(s.poi)}%;background:${s.poi > 70 ? 'var(--red)' : s.poi > 35 ? 'var(--mustard)' : 'var(--good)'}"></i></div>${s.linked ? '<p style="color:var(--red)"><b>They know it\'s you. Arrest means death row.</b></p>' : ''}`;
    return h;
  };

  // ---------------------------------------------------------------- wiring
  SK.init = function (g) {
    this.live = []; this.runtime = new Map(); this.mt = 20;
    this.apply(this.state().profile);
    if (this.wrapped) return;
    this.wrapped = true;
    const LP = R.Law.prototype, crime = LP.crime;
    LP.crime = function (type, x, y, opts) {
      if ((type === 'murder' || type === 'manslaughter') && opts && opts.victim && opts.victim.dead) SK.onMurder(opts.victim, type === 'manslaughter' ? 'car' : null);
      return crime.apply(this, arguments);
    };
    // dumping a body or a bag: are they watching this spot?
    const PP = R.Player.prototype, ctx = PP.contextAction;
    PP.contextAction = function () {
      const a = ctx.call(this);
      if (a && /trash|water|brush|Sink|Dump/i.test(a.label) && /body|remains/i.test(a.label)) {
        const fn = a.fn, self = this;
        a.fn = function () { const r = fn.apply(this, arguments); if (/trash/i.test(a.label) && self.game) { /* note how it was dumped */ } if (SK.watched(self)) SK.caughtDumping(); return r; };
      }
      return a;
    };
    const J = R.Jobs.prototype, jd = J.daily;
    J.daily = function () { jd.call(this); SK.daily(); };
    const html = R.cases.html;
    R.cases.html = function () { return html.call(this) + SK.html(); };
    // death row
    const SL = R.slammer, book = SL.book;
    SL.book = function (jur, days) {
      if (SK.state().linked) { const r = book.call(this, jur, 999); setTimeout(() => G().ui.story('DEATH ROW', 'No lawyer can fix this one. No parole board, no appeal worth the paper.\n\nThe only way out of here is over the wall.'), 600); return r; }
      return book.call(this, jur, days);
    };
    // trash dumps mark the body so the signature knows
    const B = R.bodies, bctx = B.context;
    B.context = function (pl) {
      const a = bctx.call(this, pl);
      if (a && pl.carrying && /trash/i.test(a.label)) { const body = pl.carrying, fn = a.fn; a.fn = function () { body.trashed = true; return fn.apply(this, arguments); }; }
      if (a && pl.carrying && /trunk/i.test(a.label)) { const body = pl.carrying, fn = a.fn; a.fn = function () { body.inTrunk = true; return fn.apply(this, arguments); }; }
      return a;
    };
  };
})();
