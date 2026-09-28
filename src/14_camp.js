// RHAPSODY — the crew. Everyone who joins you goes on the roster for good, and when they're
// not riding with you they hang around the back room of your family's social club: cards,
// cigarettes, cleaning guns, arguing about the Hawks. Each has loyalty, mood and a need
// (money, rest, respect, action); each expects a wage every week; each has a personal
// trouble you can help with. How they feel changes how they fight: a happy, loyal crew hits
// harder and holds the line, a sour one breaks and runs, and a crew that's owed too long
// walks, or talks.
'use strict';
(function () {
  const TS = R.TILE;
  const G = () => R.game;
  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
  const CM = (R.camp = { t: 0 });

  const NEEDS = {
    pay: { label: 'Wants money', line: 'Rent\'s due. Rent\'s always due.' },
    rest: { label: 'Worn out', line: 'I ain\'t slept right since the thing at the docks.' },
    respect: { label: 'Feels overlooked', line: 'You ever gonna give me something real to do?' },
    action: { label: 'Restless', line: 'I\'m going stir crazy in here. Take me out.' },
  };
  const IDLE = [
    ['Deal me in.', 'Full house. Pay up.', 'You\'re cheating. I know you\'re cheating.'],
    ['Hawks lost again.', 'They\'re rebuilding.', 'They been rebuilding since \'61.'],
    ['Who drank my beer?', 'Nobody drank your beer.', 'Somebody drank my beer.'],
    ['Pass the oil.', 'You clean that thing more than you clean yourself.', 'It\'s never jammed on me.'],
    ['You hear the new Bee Gees?', 'Please don\'t sing.', '*sings anyway*'],
  ];
  // personal troubles: go somewhere, deal with someone
  const STORIES = [
    { id: 'brother', title: 'The Brother', ask: 'My kid brother owes the wrong people. They\'re gonna break his hands. Could you... talk to them?', target: 'bar', foe: 'Collector', done: 'You squared it. My brother\'s gonna be okay. I owe you, and I don\'t forget.' },
    { id: 'shop', title: 'Mama\'s Shop', ask: 'Some punk\'s been leaning on my mother\'s shop. Takes the till every Friday. She\'s seventy.', target: 'general', foe: 'Shakedown punk', done: 'Mama says thank you. She\'s making you a lasagna. Do not refuse the lasagna.' },
    { id: 'ex', title: 'The Ex', ask: 'My ex married a guy who hits her. I can\'t go near the place, there\'s a court order. You can.', target: 'house', foe: 'Wife beater', done: 'She called me. First time in two years. Thank you.' },
    { id: 'debt', title: 'Old Debts', ask: 'Guy I did time with says I owe him from inside. I don\'t. He\'s gonna make it my problem anyway.', target: 'diner', foe: 'Old cellmate', done: 'He won\'t be bothering anybody. I sleep better. Thanks, boss.' },
    { id: 'car', title: 'The Car', ask: 'Somebody boosted my Coupe DeVille. My Coupe DeVille. It\'s parked outside a garage across town, I seen it.', target: 'garage', foe: 'Car thief', done: 'My baby. Not a scratch. Okay, a scratch. I\'ll live.' },
  ];

  CM.state = function () {
    const pl = G().player;
    pl.street = pl.street || {};
    return (pl.street.camp = pl.street.camp || { members: [], lastWeek: G().pop.day, ammo: 0, round: -1 });
  };
  CM.person = (m) => G().pop.people[m.pid];
  CM.member = function (p) { return p ? this.state().members.find((m) => m.pid === p.id) : null; };
  CM.name = function (m) { const p = this.person(m); return p ? G().pop.short(p) : 'Somebody'; };
  CM.add = function (h) {
    const g = G(), s = this.state();
    if (!h.person || this.member(h.person)) return;
    h.person.met = true; h.person.greets = Math.max(h.person.greets || 0, 2);
    const rnd = R.mulberry(h.person.id * 31 + 7);
    s.members.push({ pid: h.person.id, joined: g.pop.day, loyalty: 40 + ((rnd() * 20) | 0), mood: 60, need: ['pay', 'rest', 'respect', 'action'][(rnd() * 4) | 0], wage: 40 + ((rnd() * 6) | 0) * 10, owed: 0, story: STORIES[(rnd() * STORIES.length) | 0].id, sstage: 0, fights: 0, skill: 0 });
    g.ui.toast(`${g.pop.short(h.person)} is on your crew roster. When they're not with you, they wait in the back room at the club.`, 'good');
  };
  CM.club = function () { const g = G(); return g.world.buildings[g.homeClub]; };
  CM.morale = function (m) { return (m.loyalty + m.mood) / 2; };

  // ---------------------------------------------------------------- the back room
  CM.sheet = function () {
    const g = G(), ui = g.ui, s = this.state(), pl = g.player;
    const alive = s.members.filter((m) => { const p = this.person(m); return p && p.alive; });
    const bar = (v, c) => `<span class="cbar"><i style="width:${Math.max(0, Math.min(100, v))}%;background:${c}"></i></span>`;
    let html = ui.header('The Crew', `${alive.length} on the roster. Wages come due every 7 days${s.members.some((m) => m.owed) ? ' (you owe some of them)' : ''}.`) + '<div class="body"><div class="crew">';
    const opts = [];
    for (const m of alive) {
      const p = this.person(m), out = pl.crew.some((c) => c.person === p);
      const st = STORIES.find((q) => q.id === m.story);
      html += `<div class="cm"><b>${esc(g.pop.short(p))}</b> <small>${out ? 'riding with you' : 'back room'} · wage ${R.fmtMoney(m.wage)}/wk${m.owed ? ` · <span style="color:var(--red)">owed ${R.fmtMoney(m.owed)}</span>` : ''}</small><div class="cbars">Loyalty ${bar(m.loyalty, '#6a9a30')} Mood ${bar(m.mood, '#e4a92a')}</div><small>${NEEDS[m.need] ? NEEDS[m.need].label : 'Content'}${st && m.sstage === 1 ? ` · on it: ${esc(st.title)}` : ''}${m.skill ? ` · veteran ×${m.skill}` : ''}</small><div class="crow">`;
      const add = (label, fn, cls) => { opts.push(fn); html += `<button class="chip ${cls || 'c-talk'}" data-o="${opts.length - 1}">${label}</button>`; };
      if (m.owed) add(`Pay ${R.fmtMoney(m.owed)}`, () => { if (!pl.pay(m.owed)) return ui.toast('You\'re short.', 'warn'); m.owed = 0; m.mood = Math.min(100, m.mood + 10); m.loyalty = Math.min(100, m.loyalty + 5); ui.toast(`${g.pop.short(p)} counts it twice. "We're good."`, 'good'); }, 'c-greet');
      if (m.need === 'pay') add('Slip $50', () => { if (!pl.pay(50)) return ui.toast('You\'re short.', 'warn'); m.mood = Math.min(100, m.mood + 20); m.loyalty = Math.min(100, m.loyalty + 4); m.need = null; });
      if (m.need === 'rest') add('Give a week off', () => { m.mood = Math.min(100, m.mood + 25); m.need = null; m.offUntil = g.pop.day + 2; ui.toast(`${g.pop.short(p)} is going fishing. Back in two days.`); });
      if (m.need === 'respect') add('Praise in front of the others', () => { m.mood = Math.min(100, m.mood + 15); m.loyalty = Math.min(100, m.loyalty + 8); m.need = null; for (const o of alive) if (o !== m) o.mood = Math.max(0, o.mood - 3); ui.toast(`${g.pop.short(p)} stands a little taller. A couple of the others roll their eyes.`); });
      if (st && m.sstage === 0 && m.loyalty >= 30) add('"Something on your mind?"', () => this.story(m, st));
      if (!out && !(m.offUntil > g.pop.day)) add('Ride with me', () => this.bring(m));
      add('Cut loose', () => { s.members = s.members.filter((q) => q !== m); const c = pl.crew.find((q) => q.person === p); if (c) pl.dismiss(c); ui.toast(`${g.pop.short(p)} takes it badly.${m.loyalty < 40 ? ' And they know things.' : ''}`, 'warn'); if (m.loyalty < 40 && R.rat && R.rat.pressure) R.rat.pressure(p.id, 20, 'cut loose from your crew'); }, 'c-antag');
      html += '</div></div>';
    }
    if (!alive.length) html += '<p>Nobody yet. People who like you (or fear you) can be asked to ride with you, and anyone who does joins the roster.</p>';
    html += '</div>';
    const camp = [];
    camp.push({ label: 'Buy a round', small: `$40 · everyone's mood +15${s.round === g.pop.day ? ' (already bought today)' : ''}`, fn: () => { if (s.round === g.pop.day) return; if (!pl.pay(40)) return ui.toast('You\'re short.', 'warn'); s.round = g.pop.day; for (const m of alive) m.mood = Math.min(100, m.mood + 15); ui.toast('"To the boss!" Glasses up.', 'good'); } });
    camp.push({ label: 'Stock the ammo crate', small: `$100 · the crew fights better for a week${s.ammo > g.pop.day ? ` (stocked until ${R.calendar(s.ammo)})` : ''}`, fn: () => { if (!pl.pay(100)) return ui.toast('You\'re short.', 'warn'); s.ammo = g.pop.day + 7; for (const m of alive) m.mood = Math.min(100, m.mood + 5); ui.toast('Fresh boxes of .38s. Somebody whistles.', 'good'); } });
    html += `<div class="sect">The back room</div><div class="opts">${camp.map((o, i) => `<button class="opt" data-c="${i}">${o.label}<small>${o.small}</small></button>`).join('')}</div></div>`;
    const sh = ui.openSheet('crew', html);
    sh.querySelectorAll('[data-o]').forEach((b) => b.addEventListener('click', () => { g.audio.sfx('click'); opts[+b.dataset.o](); if (ui.sheetOpen) this.sheet(); }));
    sh.querySelectorAll('[data-c]').forEach((b) => b.addEventListener('click', () => { g.audio.sfx('click'); camp[+b.dataset.c].fn(); this.sheet(); }));
  };
  CM.bring = function (m) {
    const g = G(), pl = g.player, p = this.person(m);
    if (pl.crew.length >= 4) return g.ui.toast('Four is a crew. Five is a parade.', 'warn');
    let h = p.actor && !p.actor.dead && !p.actor.removed ? p.actor : null;
    if (!h) h = g.life.spawnPerson(p, pl.x + 12, pl.y + 4);
    if (!h) return;
    h.room = pl.room || null;
    const q = g.ui.toast; g.ui.toast = () => {}; try { pl.recruit(h); } finally { g.ui.toast = q; }
    if (m.need === 'action') { m.need = null; m.mood = Math.min(100, m.mood + 15); }
    g.actors.say(h, R.rng.pick(['Let\'s go to work.', 'Finally.', 'Right behind you, boss.']));
    g.ui.closeSheet();
  };

  // ---------------------------------------------------------------- personal troubles
  CM.story = function (m, st) {
    const g = G(), ui = g.ui, w = g.world, pl = g.player;
    const c0 = this.club() ? this.club().city : w.cities[0];
    const b = w.buildings.filter((q) => q && !q.destroyed && q.type === st.target && q.city === c0)[0] || w.buildings.find((q) => q && !q.destroyed && q.type === st.target);
    ui.story(`${this.name(m)}: ${st.title}`, `"${st.ask}"`, () => {});
    if (!b) return;
    m.sstage = 1; m.sb = b.id;
    R.poi.add(b.out.x, b.out.y, 'tip', `${st.title} (${this.name(m)})`, st.foe);
    g.waypoint = { x: b.out.x * TS + 8, y: b.out.y * TS + 8 };
    ui.toast(`${st.title}: find the ${st.foe.toLowerCase()} at ${b.name}. Waypoint set.`, 'good');
  };
  CM.updateStories = function () {
    const g = G(), pl = g.player, s = this.state();
    for (const m of s.members) {
      if (m.sstage !== 1) continue;
      const st = STORIES.find((q) => q.id === m.story), b = g.world.buildings[m.sb];
      if (!st || !b) { m.sstage = 0; continue; }
      const d = Math.hypot(b.out.x * TS - pl.x, b.out.y * TS - pl.y);
      if (!m.foe && d < TS * 12 && !pl.room) {
        const f = g.actors.makeHuman(b.out.x * TS + 8, b.out.y * TS + 14, { tag: 'campfoe', weapon: R.rng.pick(['knife', 'bat', 'revolver']), arch: 'tough' });
        f.strangerName = st.foe; f.keep = true; f.hp = f.maxHp = 140; f.campFoe = m.pid;
        g.actors.say(f, R.rng.pick(['What are YOU looking at?', 'This ain\'t your business, pal.', `${this.name(m)} sent you? Ha!`]));
        m.foe = f;
      }
      if (m.foe && (m.foe.dead || m.foe.down > 0 || m.foe.state === 'surrender' || m.foe.state === 'flee')) {
        m.sstage = 2; m.foe = null; m.loyalty = Math.min(100, m.loyalty + 30); m.mood = Math.min(100, m.mood + 20); m.skill++;
        g.ui.story(`${st.title}: done`, `${this.name(m)}: "${st.done}"\n\n(Loyalty +30. ${this.name(m)} fights harder beside you.)`);
        if (R.memory) R.memory.log('rescue', { x: b.out.x * TS, y: b.out.y * TS, seen: true, victim: null });
      } else if (m.foe && m.foe.removed) m.foe = null;
    }
  };

  // ---------------------------------------------------------------- days and weeks
  CM.daily = function () {
    const g = G(), s = this.state(), pl = g.player;
    for (const m of s.members) {
      const p = this.person(m);
      if (!p || !p.alive) continue;
      m.mood = Math.max(0, Math.min(100, m.mood + (s.ammo > g.pop.day ? 1 : 0) - (m.need ? 4 : 0) - (m.owed ? 6 : 0) + 1));
      if (!m.need && R.rng() < 0.25) m.need = R.rng.pick(['pay', 'rest', 'respect', 'action']);
      if (m.mood < 25) m.loyalty = Math.max(0, m.loyalty - 3);
    }
    if (g.pop.day - s.lastWeek >= 7) {
      s.lastWeek = g.pop.day;
      let paid = 0, short = [];
      for (const m of s.members) {
        const p = this.person(m);
        if (!p || !p.alive) continue;
        if (pl.pay(m.wage)) paid += m.wage;
        else { m.owed += m.wage; m.loyalty = Math.max(0, m.loyalty - 10); short.push(g.pop.short(p)); }
      }
      if (paid) g.ui.toast(`Crew wages: ${R.fmtMoney(paid)} out of your pocket.`);
      if (short.length) g.ui.toast(`You came up short on wages for ${short.join(', ')}. They noticed.`, 'bad');
    }
    // people walk, and bitter people talk
    for (const m of s.members.slice()) {
      const p = this.person(m);
      if (!p || !p.alive) { s.members = s.members.filter((q) => q !== m); continue; }
      if (m.loyalty <= 5 || m.owed >= m.wage * 3) {
        s.members = s.members.filter((q) => q !== m);
        const c = pl.crew.find((q) => q.person === p); if (c) pl.dismiss(c);
        g.ui.toast(`${g.pop.short(p)} cleared out their locker. They're done with you.`, 'bad');
        if (R.rat && R.rat.pressure) R.rat.pressure(p.id, 35, 'walked out on your crew');
      }
    }
  };

  // ---------------------------------------------------------------- per-frame
  CM.update = function (dt) {
    const g = G(), pl = g.player;
    if (!g.started) return;
    for (const c of pl.crew) if (c.person && !this.member(c.person) && !c.corpsAlly && !c.halBackup && !c.fearRing) this.add(c);
    this.t -= dt;
    if (this.t > 0) return;
    this.t = 1;
    const s = this.state();
    if (this.day !== g.pop.day) { if (this.day != null) this.daily(); this.day = g.pop.day; }
    this.updateStories();
    // morale in the field: a sour crew breaks when it gets hurt
    for (const c of pl.crew) {
      const m = c.person && this.member(c.person);
      if (!m || c.dead) continue;
      if (c.state === 'fight') { m.inFight = true; if (c.hp < c.maxHp * 0.5 && this.morale(m) < 35 && !c.broke) { c.broke = true; g.actors.say(c, R.rng.pick(['I ain\'t dying for this!', 'Forget this!', 'You don\'t pay me enough!'])); g.actors.setFlee(c, pl, 6); m.loyalty = Math.max(0, m.loyalty - 5); } }
      else if (m.inFight) { m.inFight = false; m.fights++; m.mood = Math.min(100, m.mood + (m.need === 'action' ? 15 : 3)); if (m.need === 'action') m.need = null; if (c.broke) c.broke = false; else if (R.rng() < 0.5) g.actors.say(c, this.morale(m) > 70 ? R.rng.pick(['That\'s how it\'s done.', 'Anybody else?', 'Easy money.']) : R.rng.pick(['That was too close.', 'We gotta talk about my cut.', 'My hands won\'t stop shaking.'])); }
    }
    // the back room chatters
    if (pl.room && this.club() && pl.room.b === this.club()) {
      const here = g.actors.list.filter((a) => a.campMember && a.room === pl.room && !a.dead);
      this.chatT = (this.chatT || 0) - 1;
      if (here.length >= 2 && this.chatT <= 0) {
        this.chatT = 7;
        const [a, b] = [here[(R.rng() * here.length) | 0], here[(R.rng() * here.length) | 0]];
        if (a !== b) { const l = R.rng.pick(IDLE); g.actors.say(a, l[0]); setTimeout(() => { if (!b.dead) g.actors.say(b, l[1]); }, 1700); setTimeout(() => { if (!a.dead) g.actors.say(a, l[2]); }, 3400); }
      }
    }
  };

  CM.tree = function (h) {
    const g = G(), ui = g.ui, m = this.member(h.person);
    if (!m) return null;
    const p = h.person, need = m.need && NEEDS[m.need];
    const mood = m.mood > 70 ? 'Good. Real good.' : m.mood > 40 ? 'Can\'t complain. I mean I can, but I won\'t.' : 'Honestly? Not great, boss.';
    return { title: g.pop.short(p), sub: `Your crew. Loyalty ${Math.round(m.loyalty)}, mood ${Math.round(m.mood)}.`, options: [
      { label: '"How you holding up?"', fn: () => ui.talkLine(`${mood}${need ? ' ' + need.line : ''}`) },
      { label: 'The crew roster', small: 'Pay, praise, favours, who rides with you', cls: 'go', fn: () => this.sheet() },
      { label: 'Leave', fn: () => ui.closeSheet() },
    ] };
  };

  // ---------------------------------------------------------------- wiring
  CM.init = function (game) {
    this.t = 2; this.day = null;
    const s = this.state();
    for (const m of s.members) m.foe = null;
    if (this.wired) return;
    this.wired = true;
    // the back room fills with whoever isn't riding with you
    const IP = R.Interiors.prototype, bPop = IP.populate;
    IP.populate = function (room) {
      const r = bPop.apply(this, arguments);
      const g = G(), club = CM.club();
      if (club && room.b === club && room.mode !== 'breakin') {
        const spots = room.seats.concat(room.extra);
        let i = 0;
        for (const m of CM.state().members) {
          const p = CM.person(m);
          if (!p || !p.alive || (m.offUntil > g.pop.day) || g.player.crew.some((c) => c.person === p)) continue;
          if (p.actor && !p.actor.dead && !p.actor.removed) continue;
          const sp = spots[(i++) % Math.max(1, spots.length)] || room.center;
          const h = this.spawnAt(room, p, sp, { stay: true });
          if (h) { h.campMember = true; h.stay = true; h.state = 'idle'; h.timer = 1e9; }
        }
      }
      return r;
    };
    // crew on the roster talk like crew
    const bTree = R.dialog.tree;
    R.dialog.tree = function (h) { if (h && h.person && CM.member(h.person) && (h.campMember || h.crew)) { const t = CM.tree(h); if (t) return t; } return bTree.apply(this, arguments); };
    // loyal, happy crew hit harder; the ammo crate helps
    const bDmg = R.combat.damage;
    R.combat.damage = function (a, amt, src) {
      if (src && src.crew && src.person) {
        const m = CM.member(src.person);
        if (m) { const g = G(); let k = 1 + Math.max(0, CM.morale(m) - 50) / 200 + m.skill * 0.05; if (CM.state().ammo > g.pop.day) k += 0.1; const args = Array.from(arguments); args[1] = amt * k; return bDmg.apply(this, args); }
      }
      return bDmg.apply(this, arguments);
    };
    // the club's back room has a crew option
    const U = R.UI.prototype, bIO = U.interiorOptions;
    U.interiorOptions = function (b) {
      const opts = bIO.apply(this, arguments) || [];
      if (b === CM.club()) opts.unshift({ label: 'The crew', small: `${CM.state().members.length} on the roster · pay, praise, favours`, fn: () => { this.closeSheet(); CM.sheet(); } });
      return opts;
    };
    const st = document.createElement('style');
    st.textContent = '.crew .cm{border:3px solid var(--ink);border-radius:8px;background:var(--paper2);padding:6px 8px;margin:6px 0;color:var(--ink)}.crew .cm small{display:block;color:var(--muted);font-size:12px}.cbars{display:flex;gap:8px;align-items:center;font-size:12px;margin:3px 0}.cbar{display:inline-block;width:64px;height:8px;border:2px solid var(--ink);background:#3a2418;vertical-align:middle}.cbar i{display:block;height:100%}.crow{display:flex;flex-wrap:wrap;gap:5px;margin-top:5px}.crow .chip{font-size:10px;padding:5px 8px}';
    document.head.appendChild(st);
  };
})();
