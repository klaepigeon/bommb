// RHAPSODY — vendettas. Everyone you kill had people: a wife, a brother, a son. They don't
// know it was you, at first. Then a witness talks, the sketch runs in the paper, or the
// neighbourhood gossips, and they do know. What they do about it depends on who they
// are: the brave ones buy a gun and come looking, the rich hire somebody, the hustlers
// see an opportunity and send a letter, the timid go to the detective, and the children
// wait until they're grown. Settle it with money, with fear, or with another funeral,
// which starts the whole thing over with a different family.
'use strict';
(function () {
  const TS = R.TILE;
  const G = () => R.game;
  const VD = (R.vendetta = {});
  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
  const REL = { spouse: (p) => (p.fem ? 'husband' : 'wife'), kid: (p) => (p.fem ? 'mother' : 'father'), parent: (p) => (p.fem ? 'daughter' : 'son'), sibling: (p) => (p.fem ? 'brother' : 'sister') };
  // what the dead person was to the avenger
  const relName = (rel, victim) => ({ spouse: victim.fem ? 'wife' : 'husband', kid: victim.fem ? 'daughter' : 'son', parent: victim.fem ? 'mother' : 'father', sibling: victim.fem ? 'sister' : 'brother' })[rel];

  VD.state = function () { const pl = G().player; return (pl.vend = pl.vend || { list: [] }); };
  VD.active = function () { return this.state().list.filter((v) => !v.done); };

  // ---------------------------------------------------------------- a death, and who's left
  VD.onDeath = function (p, byPlayer) {
    if (!byPlayer || !p) return;
    const g = G(), pop = g.pop, s = this.state();
    const kin = pop.family(p).map(([rel, q]) => [rel === 'kid' ? 'parent' : rel === 'parent' ? 'kid' : rel, q]);
    // brothers and sisters: anyone who shares a parent
    for (const pid of p.parents || []) { const par = pop.people[pid]; if (par) for (const k of par.kids) if (k !== p.id && pop.people[k] && !kin.some(([, q]) => q.id === k)) kin.push(['sibling', pop.people[k]]); }
    // the case decides whether they already know
    const known = this.identified(p);
    for (const [rel, q] of kin) {
      if (!q || !q.alive || q.playerChild || q.playerPartner) continue;
      // rel here is what the victim was to q (the avenger)
      const v = { pid: q.id, vid: p.id, rel, day: pop.day, knows: known, mode: null, done: false, heat: 0 };
      q.grudge = known ? 100 : 0;
      s.list.push(v);
      if (known) this.decide(v);
    }
    if (s.list.length > 60) s.list.splice(0, s.list.length - 60);
  };
  VD.identified = function (p) {
    const CS = R.cases;
    if (!CS) return false;
    return CS.state().list.some((c) => c.body && c.body.pid === p.id && c.witnesses.some((x) => !x.masked && !x.gone));
  };
  // how they respond, once they know
  VD.decide = function (v) {
    const g = G(), q = g.pop.people[v.pid], vic = g.pop.people[v.vid];
    if (!q || !q.alive) { v.done = true; return; }
    q.grudge = 100;
    if (q.age < 16) v.mode = 'wait';
    else if (q.arch === 'hustler' || q.arch === 'gossip') v.mode = 'blackmail';
    else if (q.wealth > 60 && q.age > 40) v.mode = 'hire';
    else if (q.arch === 'tough' || q.arch === 'grumpy' || (q.tr && q.tr.brave > 0.6)) v.mode = 'hunt';
    else v.mode = 'cops';
    g.pop.remember(q, 'vendetta', `I know who killed my ${relName(v.rel, vic)} ${vic.first}. I know his face.`, g.pop.day);
    if (v.mode === 'cops') this.tellCops(v);
    if (v.mode === 'blackmail') v.dueDay = g.pop.day + 1;
  };
  VD.tellCops = function (v) {
    const g = G(), CS = R.cases, q = g.pop.people[v.pid], vic = g.pop.people[v.vid];
    const c = CS && CS.state().list.find((k) => k.body && k.body.pid === v.vid && (k.status === 'open' || k.status === 'warrant'));
    if (c) { c.progress = Math.min(100, c.progress + 20); if (!c.witnesses.some((x) => x.pid === q.id)) c.witnesses.push({ pid: q.id, name: g.pop.name(q), masked: false, gone: null }); }
    g.ui.toast(`${g.pop.name(q)} went to the police about ${vic.first}. They're naming you.`, 'bad');
    v.done = true;
  };

  // ---------------------------------------------------------------- every morning
  VD.daily = function () {
    const g = G(), pl = g.player, pop = g.pop;
    for (const v of this.active()) {
      const q = pop.people[v.pid];
      if (!q || !q.alive) { v.done = true; continue; }
      if (!v.knows) {
        // the neighbourhood talks; the paper prints the sketch
        const c = R.cases && R.cases.state().list.find((k) => k.body && k.body.pid === v.vid);
        const p = 0.04 + pl.rep.infamy / 900 + (c && c.sketch ? 0.12 : 0) + (this.identified(pop.people[v.vid]) ? 0.3 : 0);
        if (R.rng() < p) { v.knows = true; this.decide(v); if (!v.done && v.mode !== 'wait') g.ui.toast(`Somebody told ${pop.name(q)} who killed their ${relName(v.rel, pop.people[v.vid])}.`, 'warn'); }
        else if (pop.day - v.day > 30) v.done = true; // they never found out
        continue;
      }
      q.grudge = Math.max(q.grudge, 80); // it doesn't fade
      if (v.mode === 'wait' && q.age >= 18) { v.mode = q.tr && q.tr.brave > 0.4 ? 'hunt' : 'hire'; g.pop.addNews(q.city, `${pop.name(q)} turned 18 this week. Friends say ${q.fem ? 'she' : 'he'} "never got over" what happened to ${q.fem ? 'her' : 'his'} family.`); }
      if (v.mode === 'hunt' || v.mode === 'hire') v.heat = Math.min(100, v.heat + 20);
      if (v.mode === 'blackmail' && pop.day >= (v.dueDay || 0)) this.letter(v);
    }
  };
  // "I know what you did"
  VD.letter = function (v) {
    const g = G(), pl = g.player, q = g.pop.people[v.pid], vic = g.pop.people[v.vid];
    const amt = 100 + Math.round((q.wealth || 20) * 3) + (v.paid || 0) * 50;
    v.dueDay = g.pop.day + 4;
    g.ui.story('A LETTER', `An envelope under your door, no stamp.\n\n"I know what you did to my ${relName(v.rel, vic)} ${vic.first}. ${R.fmtMoney(amt)} in a paper bag, behind the diner, or I go to the police.\n— ${q.first}"`);
    setTimeout(() => g.ui.choice(`${g.pop.name(q)} wants ${R.fmtMoney(amt)}`, [
      { label: `Pay (${R.fmtMoney(amt)})`, small: 'They\'ll be back. They always come back', fn: () => { if (!pl.pay(amt)) { g.ui.toast('You can\'t cover it. They went to the cops.', 'bad'); return this.tellCops(v); } v.paid = (v.paid || 0) + 1; g.ui.toast(`Paid. ${q.first} will be quiet for a while.`, 'warn'); } },
      { label: 'Ignore it', small: 'They go to the police', fn: () => this.tellCops(v) },
      { label: 'Pay them a visit', small: 'Their home gets marked', fn: () => { const b = g.world.buildings[q.home]; if (b) { g.waypoint = { x: b.out.x * TS + 8, y: b.out.y * TS + 8 }; g.ui.toast(`${q.first} lives at ${b.name}. Waypoint set.`); } v.dueDay = g.pop.day + 2; } },
    ]), 500);
  };

  // ---------------------------------------------------------------- they come for you
  VD.update = function (dt) {
    const g = G(), pl = g.player;
    this.t = (this.t == null ? 40 : this.t) - dt;
    if (this.t > 0 || pl.room || pl.inCar || pl.dead || g.law.incident) return;
    this.t = 60 + R.rng() * 60;
    const c = g.world.cityAt((pl.x / TS) | 0, (pl.y / TS) | 0);
    for (const v of this.active()) {
      if (!v.knows || (v.mode !== 'hunt' && v.mode !== 'hire') || v.heat < 40) continue;
      const q = g.pop.people[v.pid], vic = g.pop.people[v.vid];
      if (!q || !q.alive || q.jailed > g.pop.day) continue;
      if (v.mode === 'hunt' && (!c || c.id !== q.city) && R.rng() < 0.7) continue; // they look where they live, mostly
      if (R.rng() > 0.5) continue;
      const sp = g.world.findNear(pl.x / TS, pl.y / TS, 13, 18, (x, y) => !g.world.solidPed(x, y) && !g.world.isWater(x, y));
      if (!sp) continue;
      v.heat = 0;
      if (v.mode === 'hunt') {
        if (q.actor && !q.actor.dead) g.actors.remove(q.actor);
        const h = g.life.spawnPerson(q, sp.x * TS + 8, sp.y * TS + 8);
        g.actors.arm(h, R.rng.pick(['shotgun', 'revolver', 'revolver', 'knife']));
        h.keep = true; h.hostile = true; h.hostileLocked = true; h.tr.brave = 1; h.avenger = v;
        g.actors.setFight(h, pl);
        g.actors.say(h, R.rng.pick([`You killed my ${relName(v.rel, vic)}!`, `This is for ${vic.first}, you son of a bitch!`, `${vic.first} had a family! LOOK AT ME!`]));
        g.ui.toast(`${g.pop.name(q)} found you. ${q.fem ? 'She' : 'He'} has a gun and nothing left to lose.`, 'bad');
      } else {
        for (let i = 0; i < 2; i++) { const h = g.actors.makeHuman(sp.x * TS + 8 + i * 12, sp.y * TS + 8, { weapon: R.rng.pick(['magnum', 'shotgun', 'chopper']), arch: 'tough', tag: 'hitman', cash: 80 }); h.keep = true; h.hostile = true; h.hostileLocked = true; h.tr.brave = 1; h.strangerName = 'Hired gun'; g.actors.setFight(h, pl); if (!i) g.actors.say(h, `Mr. ${q.last} sends his regards.`); }
        g.ui.toast(`Hired guns, paid for by the ${q.last} family.`, 'bad');
        v.hires = (v.hires || 0) + 1;
        if (v.hires >= 3) { v.done = true; g.pop.remember(q, 'vendetta', 'I spent everything I had on revenge. It didn\'t bring anyone back.', g.pop.day); }
      }
      break;
    }
  };

  // ---------------------------------------------------------------- facing them
  VD.forPerson = function (p) { return p && this.active().find((v) => v.pid === p.id && v.knows); };
  VD.opts = function (h, opts) {
    const g = G(), pl = g.player, v = this.forPerson(h.person);
    if (!v) return;
    const q = h.person, vic = g.pop.people[v.vid], ui = g.ui;
    const i = Math.max(0, opts.findIndex((o) => /Goodbye|Leave/.test(o.label)));
    const price = 150 + Math.round((q.wealth || 20) * 4);
    opts.splice(i, 0, { label: `"About ${vic.first}..."`, small: `They know you killed their ${relName(v.rel, vic)}`, cls: 'go', fn: () => ui.choice(`${g.pop.name(q)} is shaking`, [
      { label: `"I'm sorry." Leave an envelope (${R.fmtMoney(price)})`, small: 'Blood money. Sometimes it\'s enough', fn: () => { if (!pl.pay(price)) return ui.toast('Not enough.'); const ok = R.rng() < (q.arch === 'hustler' ? 0.95 : 0.55 + (q.wealth < 30 ? 0.25 : 0)); if (ok) { v.done = true; q.grudge = 0; q.opinion = Math.min(q.opinion, -30); g.actors.say(h, 'Get out of my sight. Don\'t ever come back.'); ui.toast(`${q.first} takes it. It's over, as much as it can be.`, 'good'); pl.rep.honor += 1; } else { g.actors.say(h, 'You think money brings him back?!'); h.hostile = true; g.actors.setFight(h, pl); } } },
      { label: 'Make them understand', small: 'Fear works on some people', fn: () => { const ok = R.rng() < 0.3 + (1 - (h.tr.brave || 0.5)) * 0.5 + pl.rep.infamy / 250; if (ok) { v.done = true; q.fear = 100; g.actors.say(h, 'Okay... okay. I never saw you. I\'ll leave town.'); ui.toast(`${q.first} drops it. You can see what it costs them.`, 'warn'); pl.rep.infamy += 2; } else { g.actors.say(h, 'You don\'t scare me. You took everything already.'); h.hostile = true; g.actors.setFight(h, pl); v.heat = 100; } } },
      { label: 'Walk away', fn: () => {} },
    ]) });
  };

  // ---------------------------------------------------------------- the heat tab
  VD.html = function () {
    const g = G(), list = this.active().filter((v) => v.knows);
    const sus = this.active().filter((v) => !v.knows).length;
    if (!list.length && !sus) return '';
    const MODE = { hunt: 'looking for you with a gun', hire: 'hiring gunmen', blackmail: 'blackmailing you', wait: 'too young. For now', cops: 'talking to the police' };
    let h = '<div class="sect">People who want you dead</div>';
    for (const v of list) { const q = g.pop.people[v.pid], vic = g.pop.people[v.vid]; h += `<p>• <b>${esc(g.pop.name(q))}</b>, ${q.age}: you killed ${q.fem ? 'her' : 'his'} ${esc(relName(v.rel, vic))} ${esc(vic.first)} · <span style="color:var(--red)">${MODE[v.mode] || 'grieving'}</span><br><small>${esc((g.pop.cityObj(q.city) || {}).name || '')}. Blood money, fear, or another funeral.</small></p>`; }
    if (sus) h += `<p><small>${sus} grieving relative${sus > 1 ? 's don\'t' : ' doesn\'t'} know it was you. Yet.</small></p>`;
    return h;
  };

  VD.init = function (g) {
    this.t = 40;
    if (!this.onDeathFn) this.onDeathFn = (p, by) => setTimeout(() => VD.onDeath(p, by), 150);
    const ls = R.bus.map.get('person:died');
    if (!ls || !ls.includes(this.onDeathFn)) R.bus.on('person:died', this.onDeathFn);
    if (this.wrapped) return;
    this.wrapped = true;
    const J = R.Jobs.prototype, jd = J.daily;
    J.daily = function () { jd.call(this); VD.daily(); };
    const tree = R.dialog.tree;
    R.dialog.tree = function (h) { const t = tree.call(this, h); if (t && t.options && h.person) VD.opts(h, t.options); return t; };
    const html = R.cases.html;
    R.cases.html = function () { return html.call(this) + VD.html(); };
    // the population module hands every relative a grudge straight away; only knowing makes it real
    const pk = R.Population.prototype.kill;
    R.Population.prototype.kill = function (p, cause) { const r = pk.call(this, p, cause); if (cause === 'player') for (const [, q] of this.family(p)) if (q.alive) q.grudge = 0; return r; };
  };
})();
