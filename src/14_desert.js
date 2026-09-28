// RHAPSODY — unfinished business. The two men who walked you into the desert are real
// people with real addresses, and they think you're dead. Leads come in over the first
// weeks: a name, a bar, a job. If you looked them in the eye that night you'll know them
// on sight. Find them and choose: a bullet, a conversation, or mercy. The one who talks
// tells you who paid for it.
'use strict';
(function () {
  const TS = R.TILE;
  const G = () => R.game;
  const DS = (R.desert = {});
  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);

  DS.state = function () { const pl = G().player; pl.street = pl.street || {}; return (pl.street.desert = pl.street.desert || {}); };
  DS.men = function () { const g = G(), s = this.state(); return (s.shooters || []).map((id) => g.pop.people[id]).filter(Boolean); };
  DS.lead = function (p) { const s = this.state(); s.leads = s.leads || {}; return (s.leads[p.id] = s.leads[p.id] || { name: false, where: false }); };
  DS.known = function (p) { return this.state().faces || this.lead(p).name; };
  DS.who = function () {
    const s = this.state(), g = G();
    if (!s.orderedBy) { const fams = R.data.cities.map((c) => c.family).filter((f) => f !== g.player.family); s.orderedBy = s.sentBy && s.sentBy !== g.player.family ? s.sentBy : R.rng.pick(fams); }
    return s.orderedBy;
  };

  // ---------------------------------------------------------------- leads trickle in
  DS.daily = function () {
    const g = G(), s = this.state();
    if (!s.shooters || s.closed || (R.opening && R.opening.active)) return;
    s.startDay = s.startDay == null ? g.pop.day : s.startDay;
    // men die of other things too: a turf war, a heart attack, a bad night in Port Hollow
    for (const p of this.men()) if (!p.alive && !(s.done || []).includes(p.id)) this.close(p, 'dead');
    if (s.closed) return;
    if (g.pop.day - s.startDay === 2 && !s.promised) { s.promised = true; g.ui.toast('The don\'s people are asking around about the men from the desert. Leads will come.', 'warn'); }
    if (g.pop.day - s.startDay < 3 || R.rng() > 0.4) return;
    const open = this.men().filter((p) => p.alive && !(s.done || []).includes(p.id));
    const p = open.find((q) => !this.lead(q).name) || open.find((q) => !this.lead(q).where);
    if (!p) return;
    const L = this.lead(p), b = g.world.buildings[p.work != null ? p.work : p.home];
    if (!L.name) { L.name = true; g.ui.toast(`A lead on the desert: one of them is called ${g.pop.name(p)}.`, 'warn'); }
    else { L.where = true; if (b) { g.ui.toast(`A lead on the desert: ${p.first} ${p.work != null ? 'works at' : 'lives at'} ${b.name}. Waypoint set.`, 'warn'); g.waypoint = { x: b.out.x * TS + 8, y: b.out.y * TS + 8 }; } }
  };

  // ---------------------------------------------------------------- he sees a ghost
  DS.update = function (dt) {
    const g = G(), s = this.state(), pl = g.player;
    this.t = (this.t || 0) - dt;
    if (this.t > 0 || !s.shooters || s.closed || pl.room || (R.opening && R.opening.active)) return;
    this.t = 0.5;
    for (const p of this.men()) {
      const h = p.actor;
      if (!h || h.dead || h.desertSeen || !p.alive) continue;
      if (R.dist(h.x, h.y, pl.x, pl.y) > TS * 7 || !g.world.los(h.x, h.y - 8, pl.x, pl.y - 8)) continue;
      h.desertSeen = true;
      h.desertMan = true;
      p.fam = Math.max(p.fam || 0, 2); // you know his name now, one way or another
      this.lead(p).name = this.lead(p).name || !!s.faces;
      if (this.known(p)) g.ui.toast(`That's him. ${g.pop.name(p)}, from the desert.`, 'bad');
      if (h.tr && h.tr.brave > 0.55) { g.actors.say(h, R.rng.pick(['You... you\'re supposed to be DEAD.', 'No. No, I watched you go down!', 'Should\'ve put one in your head.'])); if (!h.weapon || h.weapon === 'fists') g.actors.arm(h, 'revolver'); h.hostile = true; h.hostileLocked = true; g.actors.setFight(h, pl); }
      else { g.actors.say(h, R.rng.pick(['Oh God. Oh God, it\'s you.', 'Stay away from me!', 'It wasn\'t my idea!'])); g.actors.setFlee(h, pl, 6); }
    }
  };

  // ---------------------------------------------------------------- face to face
  DS.opts = function (h, opts) {
    const g = G(), s = this.state(), p = h.person, pl = g.player;
    if (!p || !s.shooters || !s.shooters.includes(p.id) || (s.done || []).includes(p.id) || !this.known(p)) return;
    const i = Math.max(0, opts.findIndex((o) => /Goodbye/.test(o.label)));
    opts.splice(i, 0, { label: '"Remember me? The desert."', small: 'One of the men who shot you', cls: 'bad', fn: () => g.ui.choice(`${g.pop.name(p)} has gone white`, [
      { label: '"Who paid you?"', small: 'Make him talk. Fear helps', fn: () => this.talk(h) },
      { label: 'Settle it', small: 'He knows what\'s coming', cls: 'bad', fn: () => { g.actors.say(h, 'Wait, wait, WAIT—'); h.hostile = true; h.hostileLocked = true; h.intimidated = false; g.actors.setFight(h, pl); } },
      { label: '"Get out of my sight. Leave the Coast."', small: 'Mercy. Honor +3', fn: () => this.close(p, 'spared', h) },
    ]) });
  };
  DS.talk = function (h) {
    const g = G(), p = h.person, pl = g.player, s = this.state();
    const f = (p.fear || 0) / 100 + (pl.weaponOut ? 0.35 : 0) + pl.rep.infamy / 200 + ((h.hp || 100) < 50 ? 0.3 : 0);
    if (R.rng() < 0.3 + f) {
      const fam = this.who();
      s.knowsWho = true;
      const other = this.men().find((q) => q !== p && q.alive && !(s.done || []).includes(q.id));
      if (other) { const L = this.lead(other); L.name = true; L.where = true; }
      g.actors.say(h, `It was the ${fam}s. Don ${g.jobs.donName(fam)} paid us two grand.${other ? ` ${other.first} set it up. Ask him.` : ''}`);
      g.ui.toast(`The ${fam} family ordered the desert. ${other ? `And now you know where ${other.first} is.` : ''}`, 'warn');
      if (R.turf) { const t = R.turf.state(); if (t.grudge && t.grudge.hasOwnProperty(fam)) t.grudge[fam] = Math.max(t.grudge[fam], 25); }
      g.jobs.standing[fam] = R.clamp((g.jobs.standing[fam] || 0) - 20, -100, 100);
    } else { g.actors.say(h, 'I ain\'t saying nothing. Do what you gotta do.'); p.fear = Math.min(100, (p.fear || 0) + 25); }
  };
  DS.close = function (p, how, h) {
    const g = G(), s = this.state(), pl = g.player;
    s.done = s.done || []; s.how = s.how || {};
    if (s.done.includes(p.id)) return;
    s.done.push(p.id); s.how[p.id] = how;
    if (how === 'spared') { pl.rep.honor += 3; if (h) { g.actors.say(h, 'Thank you. I swear to God, you\'ll never see me again.'); g.actors.setFlee(h, pl, 8); } p.leftTown = true; g.ui.toast(`You let ${p.first} go.`, 'good'); }
    else if (how === 'killed') { pl.rep.infamy += 2; g.ui.toast(`That's one for the desert: ${g.pop.name(p)}.`, 'warn'); }
    else g.ui.toast(`${g.pop.name(p)} is dead. Somebody else got there first.`);
    if (this.men().every((q) => s.done.includes(q.id))) {
      s.closed = true;
      const fam = s.knowsWho ? this.who() : null;
      setTimeout(() => g.ui.toast(fam ? `The men from the desert are settled. The ${fam}s paid for it, and they know you know.` : 'The men from the desert are settled. Whoever paid them is still out there.', 'good'), 1800);
      if (fam) g.pop.addNews('port', `Two men with ties to the ${fam} family have turned up ${s.how && Object.values(s.how).includes('killed') ? 'dead' : 'missing'} in as many weeks. Police call it "a family matter."`);
    }
  };

  DS.html = function () {
    const g = G(), s = this.state();
    if (!s.shooters || !s.shooters.length || (R.opening && R.opening.active)) return '';
    let h = '<div class="sect">Unfinished business</div>';
    for (const p of this.men()) {
      const L = this.lead(p), done = (s.done || []).includes(p.id), b = g.world.buildings[p.work != null ? p.work : p.home];
      const name = this.known(p) ? esc(g.pop.name(p)) : 'The other one';
      h += `<p>• <b>${name}</b>${done ? ` · <small>${esc((s.how || {})[p.id] || 'settled')}</small>` : L.where && b ? `<br><small>${p.work != null ? 'Works at' : 'Lives at'} ${esc(b.name)}, ${esc((g.pop.cityObj(p.city) || {}).name || '')}</small>` : `<br><small>${s.faces ? 'You\'d know his face anywhere.' : 'No face, no name. Yet.'}</small>`}</p>`;
    }
    h += `<p><small>${s.knowsWho ? `Ordered by the ${esc(this.who())} family.` : 'Somebody paid for it. One of them will know who.'}</small></p>`;
    return h;
  };

  DS.init = function (g) {
    if (!this.onDeathFn) this.onDeathFn = (p, by) => { const s = DS.state(); if (p && s.shooters && s.shooters.includes(p.id)) DS.close(p, by ? 'killed' : 'dead'); };
    const ls = R.bus.map.get('person:died');
    if (!ls || !ls.includes(this.onDeathFn)) R.bus.on('person:died', this.onDeathFn);
    if (this.wrapped) return;
    this.wrapped = true;
    const tree = R.dialog.tree;
    R.dialog.tree = function (h) { const t = tree.call(this, h); if (t && t.options && h.person) DS.opts(h, t.options); return t; };
    const J = R.Jobs.prototype, jd = J.daily;
    J.daily = function () { jd.call(this); DS.daily(); };
    const cj = R.campaign.jobsHtml;
    R.campaign.jobsHtml = function () { return cj.call(this) + DS.html(); };
  };
})();
