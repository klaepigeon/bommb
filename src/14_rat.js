// RHAPSODY — rats. Everyone you lean on is a door the FBI can knock on: the debtor whose
// fingers you broke, the cop who got burned by Internal Affairs, the crew member you
// forgot to pay. Push people hard enough and one of them starts wearing a wire. You hear
// about it sideways: a whisper, a clue, a captain who owes you. Find them before the
// grand jury does, and then decide: another funeral, a bus ticket out of town, or a
// better idea, which is to let them keep talking, only now they say what you tell them.
'use strict';
(function () {
  const TS = R.TILE;
  const G = () => R.game;
  const RT = (R.rat = {});
  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
  const AGENTS = ['Special Agent Dale Whitcomb', 'Special Agent Ruth Ellery', 'Special Agent Carl Moody', 'Special Agent Joan Prewitt'];

  RT.state = function () { const st = R.shark.street(); return (st.rat = st.rat || { pressure: {}, why: {}, cur: null, caught: 0, turned: 0 }); };
  RT.active = function () { const r = this.state().cur; return r && r.status === 'talking' ? r : null; };
  RT.pressure = function (pid, n, why) {
    if (pid == null || pid < 0) return;
    const s = this.state();
    s.pressure[pid] = Math.min(30, (s.pressure[pid] || 0) + n);
    if (why) s.why[pid] = why;
    else if (!s.why[pid]) s.why[pid] = this.kindOf(pid);
  };
  RT.kindOf = function (pid) {
    const g = G(), p = g.pop.people[pid];
    if (!p) return 'leaned';
    if (p.role === 'cop') return 'cop';
    if (R.shark.state().loans.some((l) => l.pid === pid)) return 'debtor';
    if (g.player.crew.some((h) => h.person && h.person.id === pid)) return 'crew';
    return 'leaned';
  };
  const KIND = { cop: 'a cop you paid', debtor: 'somebody who owes you money', crew: 'somebody in your crew', leaned: 'somebody you leaned on' };
  RT.candidates = function () {
    const g = G(), s = this.state(), ids = new Set(Object.keys(s.pressure).map(Number));
    for (const h of g.player.crew) if (h.person) ids.add(h.person.id);
    return [...ids].map((id) => g.pop.people[id]).filter((p) => p && p.alive);
  };
  RT.caseOf = function (r) { return r && R.cases.state().list.find((c) => c.id === r.caseId); };

  // ---------------------------------------------------------------- someone flips
  RT.daily = function () {
    const g = G(), pl = g.player, s = this.state(), CS = R.cases;
    for (const k in s.pressure) { s.pressure[k] *= 0.93; if (s.pressure[k] < 0.3) { delete s.pressure[k]; } }
    for (const h of pl.crew) if (h.person) this.pressure(h.person.id, (h.person.opinion || 0) < 30 ? 0.8 : 0.25, 'crew');
    const r = s.cur;
    if (r && r.status === 'talking') return this.progress(r);
    if (r && r.status === 'turned') return this.doubleAgent(r);
    if (g.pop.day < 6) return;
    const open = CS ? CS.open().length : 0;
    for (const p of this.candidates()) {
      const pr = s.pressure[p.id] || 0.2;
      if (R.rng() < 0.006 * pr * (1 + open * 0.3) * (0.6 + pl.rep.infamy / 120)) { this.flip(p); break; }
    }
  };
  RT.flip = function (p) {
    const g = G(), s = this.state();
    s.cur = { pid: p.id, name: g.pop.name(p), day: g.pop.day, progress: 0, clues: [], status: 'talking', kind: s.why[p.id] || this.kindOf(p.id), agent: R.rng.pick(AGENTS), caseId: null, nextClue: g.pop.day + 1 + R.rng.int(0, 1) };
    g.pop.remember(p, 'rat', 'Two men in a grey sedan asked me about you. I told them I didn\'t know anything.', g.pop.day);
  };
  RT.progress = function (r) {
    const g = G(), p = g.pop.people[r.pid], CS = R.cases;
    if (!p || !p.alive) return this.silenced(r, false);
    r.progress = Math.min(100, r.progress + 6 + (r.kind === 'crew' ? 3 : 0) + (r.kind === 'cop' ? 2 : 0));
    if (g.pop.day >= r.nextClue) { this.clue(r); r.nextClue = g.pop.day + 3 + R.rng.int(0, 1); }
    const c = this.caseOf(r);
    if (c) {
      c.progress = r.progress;
      if (r.progress >= 100 && c.status === 'open') { r.status = 'testified'; CS.warrant(c); g.pop.addNews('avalon', `GRAND JURY INDICTS. A cooperating witness, identified only as "a close associate", testified for six hours. ${r.agent}: "This is the beginning."`); }
    }
  };
  // the whispers
  RT.clue = function (r) {
    const g = G(), p = g.pop.people[r.pid], CS = R.cases;
    const have = r.clues.map((c) => c.k);
    const pool = ['kind', 'fem', 'city', 'work', 'age'].filter((k) => !have.includes(k));
    if (!r.caseId) {
      const cs = CS.state(), city = g.pop.cityObj(p.city);
      const c = { id: cs.next++, type: 'rico', name: 'Federal Racketeering', jur: p.city || 'avalon', day: g.pop.day, t: g.clock.t, lastT: g.clock.t, progress: r.progress, status: 'open', det: r.agent + ', FBI', witnesses: [], coldH: 0, masked: true, face: {}, clothes: {}, bloody: false, bounty: 250, where: city ? city.name : 'New Avalon' };
      cs.list.unshift(c);
      r.caseId = c.id;
      g.ui.story('A WHISPER', `The bartender leans in close. "Friend of mine at the courthouse says the FBI has a new pal. Somebody close to you. Somebody who knows things."\n\nThere's a federal case open. Find the rat before the grand jury hears from them.`);
    }
    if (!pool.length) return;
    const k = pool.includes('kind') ? 'kind' : R.rng.pick(pool); // what sort of person first, the details later
    const text = { kind: `It's ${KIND[r.kind]}.`, fem: `It's a ${p.fem ? 'woman' : 'man'}.`, city: `They live in ${(g.pop.cityObj(p.city) || {}).name || 'the county'}.`, work: p.work != null && g.world.buildings[p.work] ? `They work at ${g.world.buildings[p.work].name}.` : `They're out of work.`, age: `They're ${p.age < 30 ? 'young, under thirty' : p.age < 50 ? 'somewhere between thirty and fifty' : 'over fifty'}.` }[k];
    r.clues.push({ k, text });
    if (r.clues.length > 1) g.ui.toast(`A whisper about the rat: "${text}"`, 'warn');
  };
  RT.matches = function (r, p) {
    for (const c of r.clues) {
      if (c.k === 'kind' && (this.state().why[p.id] || this.kindOf(p.id)) !== r.kind) return false;
      const q = G().pop.people[r.pid];
      if (c.k === 'fem' && !!p.fem !== !!q.fem) return false;
      if (c.k === 'city' && p.city !== q.city) return false;
      if (c.k === 'work' && p.work !== q.work) return false;
      if (c.k === 'age' && (p.age < 30 ? 0 : p.age < 50 ? 1 : 2) !== (q.age < 30 ? 0 : q.age < 50 ? 1 : 2)) return false;
    }
    return true;
  };
  RT.suspects = function () { const r = this.active(); return r ? this.candidates().filter((p) => this.matches(r, p)) : []; };
  RT.captainTip = function (j) {
    const g = G(), r = this.active(), cap = R.payroll.jur(j).capName || 'The captain';
    if (!r) return g.ui.toast(`${cap}: "Nobody. You're clean, far as I hear."`);
    if (r.progress < 20) return g.ui.toast(`${cap}: "The feds are sniffing. Give me a few days."`);
    r.named = true;
    g.ui.story('A NAME', `${cap} writes something on the back of a parking ticket and slides it across the desk.\n\n"${r.name}. You didn't get it from me."`);
  };

  // ---------------------------------------------------------------- taking a ride
  RT.opts = function (h, opts) {
    const g = G(), r = this.active(), p = h.person;
    if (!r || !r.caseId || !p || !this.candidates().includes(p)) return;
    const i = Math.max(0, opts.findIndex((o) => /Goodbye/.test(o.label)));
    opts.splice(i, 0, { label: '"Let\'s take a ride. Just you and me."', small: 'Accuse them of talking to the FBI', cls: 'bad', fn: () => this.confront(h) });
  };
  RT.confront = function (h) {
    const g = G(), pl = g.player, p = h.person, r = this.active(), ui = g.ui;
    if (r.pid !== p.id) {
      p.opinion = Math.min(p.opinion || 0, -30);
      pl.rep.honor = Math.max(0, pl.rep.honor - 1);
      g.actors.say(h, R.rng.pick(['Me?! After everything? You got the wrong guy!', 'I never said a word to nobody. Not one word!', 'You\'re paranoid. You know that? Paranoid.']));
      if (h.crew) { pl.dismiss(h); ui.toast(`${g.pop.name(p)} walked out of your crew. You were wrong about them.`, 'bad'); }
      else ui.toast('Wrong one. They were telling the truth, and now they\'re scared of you.', 'warn');
      this.pressure(p.id, 3);
      return;
    }
    const brave = (h.tr && h.tr.brave) || 0.5, fear = (p.fear || 0) / 100 + (pl.weaponOut ? 0.3 : 0) + pl.rep.infamy / 300;
    if (R.rng() < 0.4 + fear - brave * 0.4) {
      g.actors.say(h, R.rng.pick(['They were gonna put me away for twenty years! What was I supposed to do?', 'Okay... OKAY. They had me by the throat. I\'m sorry. I\'m sorry.', 'I only told them little stuff! Nothing that matters! I swear!']));
      h.state = 'cower';
      ui.choice(`${r.name} is a rat`, [
        { label: 'You know what happens to rats', small: 'Make an example. It\'s murder', cls: 'bad', fn: () => { r.exposed = true; h.intimidated = true; g.actors.say(h, 'No, no, no, please...'); ui.toast('Finish it. Quietly, if you can.', 'warn'); } },
        { label: '"Get out of town. Tonight." ($300)', small: 'Bus fare and a warning. The case falls apart', fn: () => { if (!pl.pay(300)) return ui.toast('You don\'t have the bus fare.'); this.silenced(r, false, 'gone'); p.leftTown = true; if (g.actors.remove) g.actors.remove(h); ui.toast(`${r.name} is on the midnight bus with a suitcase. The FBI lost its witness.`, 'good'); } },
        { label: '"Keep talking to them. Only now you tell them what I say."', small: 'Turn them. Feed the feds lies', cls: 'go', fn: () => this.turn(r, h) },
      ]);
    } else {
      g.actors.say(h, R.rng.pick(['I don\'t know what you\'re talking about.', 'You\'re crazy. I gotta go.', 'Get away from me!']));
      h.state = 'flee';
      r.progress = Math.min(100, r.progress + 8);
      r.named = true;
      ui.toast(`${r.name} bolted. That was as good as a confession, and now the FBI knows you know.`, 'warn');
    }
  };
  RT.turn = function (r, h) {
    const g = G(), s = this.state(), c = this.caseOf(r);
    r.status = 'turned'; s.turned++;
    if (c) { c.status = 'cold'; c.progress = Math.max(0, c.progress - 50); }
    g.actors.say(h, 'Whatever you want. Whatever you say. Just... thank you.');
    g.ui.toast(`${r.name} works for you now. The FBI will hear exactly what you want them to.`, 'good');
  };
  // a double agent muddies every file the police have
  RT.doubleAgent = function (r) {
    const g = G(), p = g.pop.people[r.pid];
    if (!p || !p.alive) { r.status = 'done'; return; }
    for (const c of R.cases.open()) if (c.type !== 'rico' && c.status === 'open') c.progress = Math.max(0, c.progress - 3);
    // the feds aren't stupid forever
    if (R.rng() < 0.03) { r.status = 'burned'; g.pop.addNews('avalon', `An FBI informant was charged with obstruction yesterday. "He lied to us for months," said ${r.agent}.`); g.ui.toast(`The FBI caught on to ${r.name}. Your double agent is burned.`, 'warn'); }
  };
  // the rat is dead, gone, or both
  RT.silenced = function (r, byPlayer, how) {
    const g = G(), s = this.state(), c = this.caseOf(r);
    if (r.status !== 'talking' && r.status !== 'turned') return;
    const was = r.status;
    r.status = how || 'dead';
    s.caught++;
    if (c && was === 'talking') {
      c.progress = Math.max(0, c.progress - 70);
      if (c.progress < 40) { c.status = 'cold'; g.pop.addNews('avalon', `Federal case collapses. "Without our witness, there is no case," admits ${r.agent}.`); }
      g.ui.toast(how === 'gone' ? 'The rat is gone. The federal case is falling apart.' : 'The rat won\'t be testifying. The federal case is falling apart.', 'good');
    }
    delete s.pressure[r.pid];
  };

  // ---------------------------------------------------------------- the heat tab
  RT.html = function () {
    const g = G(), r = this.active();
    if (!r || !r.caseId) return '';
    let h = '<div class="sect">There\'s a rat</div>';
    h += r.named ? `<p>It's <b>${esc(r.name)}</b>.</p>` : '';
    h += r.clues.map((c) => `<p>• ${esc(c.text)}</p>`).join('');
    const sus = this.suspects();
    if (!r.named && sus.length && sus.length <= 8) h += `<p><small>Could be: ${sus.map((p) => esc(g.pop.name(p))).join(', ')}</small></p>`;
    h += `<p><small>Talk to a suspect and take them for a ride. A captain on your payroll can find out for sure.</small></p>`;
    return h;
  };

  RT.init = function (g) {
    if (!this.onDeathFn) this.onDeathFn = (p, by) => { const r = RT.state().cur; if (r && p && r.pid === p.id) RT.silenced(r, by); };
    const ls = R.bus.map.get('person:died');
    if (!ls || !ls.includes(this.onDeathFn)) R.bus.on('person:died', this.onDeathFn);
    if (this.wrapped) return;
    this.wrapped = true;
    const tree = R.dialog.tree;
    R.dialog.tree = function (h) { const t = tree.call(this, h); if (t && t.options && h.person) RT.opts(h, t.options); return t; };
    const J = R.Jobs.prototype, jd = J.daily;
    J.daily = function () { jd.call(this); RT.daily(); };
    const CS = R.cases, weigh = CS.weigh, hour = CS.hour, html = CS.html;
    CS.weigh = function (c) {
      if (c.type !== 'rico') return weigh.call(this, c);
      const r = RT.state().cur;
      return [{ k: 'rat', v: 0, label: r && r.status === 'talking' ? 'A cooperating witness close to you is talking to the FBI' : 'Their witness is gone', fix: r && r.status === 'talking' ? 'Find the rat. See the section below.' : null }];
    };
    // the FBI keeps its own clock
    CS.hour = function () {
      const fed = this.state().list.filter((c) => c.type === 'rico' && c.status === 'open');
      for (const c of fed) c.status = 'fed';
      try { hour.call(this); } finally { for (const c of fed) c.status = 'open'; }
    };
    CS.html = function () { return html.call(this) + RT.html(); };
  };
})();
