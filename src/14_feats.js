// RHAPSODY — achievements. Milestones you earn by playing however you play: saint or
// butcher, hunter or high roller. Each one pops up once, with a fanfare, and they're all
// listed (with the ones still to get) at the bottom of Menu > Status. The sequel adds its own
// (space, colonies, the Choir...) through R.feats.list.
'use strict';
(function () {
  const FE = (R.feats = {});
  const G = () => R.game;
  const st = (pl) => pl.stats || {};
  FE.list = [
    { id: 'blood', name: 'First Blood', how: 'Kill someone', test: (pl) => st(pl).kills >= 1 },
    { id: 'reaper', name: 'The Reaper', how: 'Kill 50 people', test: (pl) => st(pl).kills >= 50 },
    { id: 'saint', name: 'Saint of the Coast', how: 'Reach 60 honour', test: (pl) => (pl.rep.honor || 0) >= 60 },
    { id: 'feared', name: 'Feared', how: 'Reach 60 infamy', test: (pl) => (pl.rep.infamy || 0) >= 60 },
    { id: 'roller', name: 'High Roller', how: 'Hold $10,000', test: (pl) => pl.cash >= 10000 },
    { id: 'mogul', name: 'Mogul', how: 'Hold $100,000', test: (pl) => pl.cash >= 100000 },
    { id: 'ring', name: 'Ring Bearer', how: 'Wear a lantern ring', test: (pl) => !!pl.inv.tools.ring },
    { id: 'phone', name: 'The Voice on the Line', how: 'Collect a Phone Man envelope', test: () => { const s = R.shark.street().phone; return !!(s && s.done >= 1); } },
    { id: 'dog', name: 'Best Friend', how: 'Adopt a stray dog', test: () => !!R.shark.street().dog },
    { id: 'blue', name: 'Thin Blue Line', how: 'Wear a police uniform', test: (pl) => !!pl.disguise },
    { id: 'shine', name: 'White Lightning', how: 'Sell 20 jugs of moonshine', test: () => { const s = R.shark.street().shine; return !!(s && s.sold >= 20); } },
    { id: 'brinks', name: 'Armored Car', how: 'Crack an armored car', test: () => { const s = R.shark.street().armored; return !!(s && s.hits >= 1); } },
    { id: 'steps', name: 'On the Church Steps', how: 'Make a hit at a mob funeral', test: () => { const s = R.shark.street().funerals; return !!(s && s.hits >= 1); } },
    { id: 'storm', name: 'Weathered', how: 'Ride out a hurricane', test: () => { const s = R.shark.street().storm; return !!(s && s.count >= 1); } },
    { id: 'nine', name: 'All Nine Lights', how: 'Own every lantern ring', test: () => !!(R.corps && R.corps.count && R.corps.count() >= 9) },
    { id: 'hunter', name: 'Big Game', how: 'Hunt 10 animals', test: (pl) => st(pl).hunted >= 10 },
    { id: 'road', name: 'Road Warrior', how: 'Travel 50 miles', test: (pl) => st(pl).miles >= 50 },
    { id: 'fisher', name: 'Gone Fishin\'', how: 'Catch 5 fish', test: (pl) => st(pl).fish >= 5 },
    { id: 'broke', name: 'Everybody Talks', how: 'Break someone in an interrogation', test: (pl) => st(pl).broken >= 1 },
    { id: 'kidnap', name: 'Over the Shoulder', how: 'Carry someone who\'s out cold', test: (pl) => st(pl).kidnaps >= 1 },
    { id: 'escape', name: 'Houdini', how: 'Escape from custody', test: (pl) => st(pl).escapes >= 1 },
    { id: 'jobs', name: 'Reliable', how: 'Finish 10 jobs', test: (pl) => st(pl).jobs >= 10 },
  ];
  FE.got = function () { const pl = G().player; pl.stats.feats = pl.stats.feats || {}; return pl.stats.feats; };
  FE.check = function () {
    const g = G(), pl = g && g.player;
    if (!pl || !pl.stats || (R.opening && R.opening.active)) return;
    const got = this.got();
    for (const f of this.list) {
      if (got[f.id]) continue;
      let ok = false;
      try { ok = !!f.test(pl); } catch (e) { ok = false; }
      if (ok) { got[f.id] = g.pop ? g.pop.day + 1 : 1; g.audio.sfx('promote'); g.ui.banner('ACHIEVEMENT', `${f.name}: ${f.how}`); return; }
    }
  };
  FE.html = function () {
    const got = this.got(), n = this.list.filter((f) => got[f.id]).length;
    return `<div class="sect">Achievements · ${n}/${this.list.length}</div>` + this.list.map((f) => `<p style="margin:2px 0;${got[f.id] ? '' : 'opacity:0.45'}">${got[f.id] ? '★' : '☆'} <b>${f.name}</b> · ${f.how}${got[f.id] ? ` <small>(day ${got[f.id]})</small>` : ''}</p>`).join('');
  };
  FE.init = function (g) {
    this.t = 0;
    if (this.wrapped) return;
    this.wrapped = true;
    const GP = R.Game.prototype, tick = GP.tick;
    GP.tick = function (dt) { const r = tick.apply(this, arguments); FE.t = (FE.t || 0) - dt; if (FE.t <= 0) { FE.t = 3; FE.check(); } return r; };
    const U = R.UI.prototype, tab = U.openMenuTab;
    U.openMenuTab = function (t, s) { const r = tab.apply(this, arguments); if (t === 'status') { const body = document.getElementById('mbody'); if (body) body.insertAdjacentHTML('beforeend', FE.html()); } return r; };
    // the counters the list needs
    const IN = R.interro;
    if (IN) { const act = IN.act; IN.act = function (h) { const was = h.intr && h.intr.broken; const r = act.apply(this, arguments); if (!was && h.intr && h.intr.broken) { const s = G().player.stats; s.broken = (s.broken || 0) + 1; } return r; }; }
    const B = R.bodies, pu = B.pickUp;
    B.pickUp = function (a) { const r = pu.apply(this, arguments); if (a && a.kind === 'h' && !a.dead) { const s = G().player.stats; s.kidnaps = (s.kidnaps || 0) + 1; } return r; };
  };
})();
