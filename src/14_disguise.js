// RHAPSODY — the uniform. Take it off a cop who's out cold (or worse) and put it on: blue shirt,
// cap, badge. Street cops stop recognising your face; nobody looks twice at a policeman. Walk
// into a police station in it and you can lose a case file from the detectives' desk, or make
// the evidence against you disappear from the property room. But do anything serious in front
// of people and the disguise is blown. Take it off at home, a hotel or a tailor.
'use strict';
(function () {
  const TS = R.TILE;
  const G = () => R.game;
  const DS = (R.disguise = {});
  const SHIRT = ['#141c34', '#2a3a6a', '#3a4e8a', '#5a70b0'], PANTS = ['#0e1424', '#1a2a4a', '#28406a', '#3a5688'], CAP = ['#0c0c10', '#1e1e26', '#34343e', '#4a4a56'];
  DS.on = () => !!(G() && G().player && G().player.disguise);
  DS.dress = function (pl) {
    if (!pl.disguise || !pl.look) return;
    const ov = (pl.look.oldOverride = pl.look.oldOverride || {});
    Object.assign(ov, { shirt: SHIRT, pants: PANTS, jacket: null, style: 'cap', cap: CAP, top: 'collar', flare: false, belt: '#1a1410' });
    pl.look.hatKind = null; pl.look.uniformBadge = true; pl.look.seedStr = (pl.look.seedStr || 'p') + '-cop';
  };
  DS.put = function (cop) {
    const g = G(), pl = g.player;
    cop.stripped = true;
    pl.disguise = { since: g.clock.t, name: cop.strangerName || 'Officer' };
    pl.buildLook();
    g.audio.sfx('equip');
    g.ui.toast('Blue shirt, cap, badge. Walk like you own the street: street cops won\'t know your face now. Anything serious in front of people blows it.', 'good');
  };
  DS.off = function (why) {
    const g = G(), pl = g.player;
    if (!pl.disguise) return;
    pl.disguise = null; pl.look.uniformBadge = false;
    pl.buildLook();
    if (why) g.ui.toast(why, 'bad');
  };
  DS.context = function (pl) {
    if (pl.disguise || pl.inCar || pl.room || pl.carrying) return null;
    const cop = G().actors.near(pl.x, pl.y, TS * 1.4, (q) => q.kind === 'h' && q.cop && !q.stripped && !q.carried && (q.dead || q.down > 0) && !q.gibbed)[0];
    return cop ? { label: 'Take the uniform', fn: () => this.put(cop) } : null;
  };
  DS.init = function (g) {
    if (this.wrapped) return;
    this.wrapped = true;
    const PP = R.Player.prototype, bl = PP.buildLook, ctx = PP.contextAction;
    PP.buildLook = function () { const r = bl.apply(this, arguments); if (this.disguise) DS.dress(this); return r; };
    PP.contextAction = function () { return DS.context(this) || ctx.call(this); };
    const L = R.Law.prototype, sees = L.copSees, crime = L.crime;
    // a cop doesn't look at another cop's face
    L.copSees = function (cop, d) { if (this.game.player.disguise && !this.incident && !(cop.brandishT > 0)) return; return sees.call(this, cop, d); };
    // anything serious and it's over
    L.crime = function (type, x, y, opts) {
      const r = crime.apply(this, arguments), def = this.CRIMES[type];
      if (this.game.player.disguise && def && def.lvl >= 2 && !(opts && opts.minor)) DS.off('Somebody saw a "cop" do that. The disguise is blown, and they\'ll know that face now.');
      return r;
    };
    // the station
    const U = R.UI.prototype, io = U.interiorOptions;
    U.interiorOptions = function (b) {
      const o = io.call(this, b), g2 = this.game, pl = g2.player, st = R.shark.street(), day = g2.pop.day;
      if (pl.disguise && b.type === 'police') {
        const risk = () => { if (R.rng() < 0.2) { DS.off('The desk sergeant squints at you. "You ain\'t from this precinct." Run.'); g2.law.startIncident({ type: 'impersonation', def: { name: 'Impersonating an Officer' }, x: pl.x, y: pl.y, jur: g2.law.jurAt(pl.x, pl.y), identified: true, lvl: 2, bounty: 150 }, null); return true; } return false; };
        if (st.fileDay !== day) o.push({ label: 'Lose a case file', small: 'The detectives\' desk. Nobody watches it at lunch.', fn: () => {
          st.fileDay = day; if (risk()) return;
          const c = R.cases && R.cases.open().sort((a, b2) => b2.progress - a.progress)[0];
          if (!c) return g2.ui.toast('There\'s no file on you. Somebody\'s doing you a favour already.');
          c.progress = Math.max(0, c.progress - 60); if (c.status === 'warrant') c.status = 'open';
          g2.ui.toast(`The file on the ${c.name.toLowerCase()} in ${c.where} goes into the furnace. ${c.det} will be looking for it for a week.`, 'good');
        } });
        if (st.evDay !== day) o.push({ label: 'Clear out the property room', small: 'Your evidence box: the gun, the clothes, the prints', fn: () => {
          st.evDay = day; if (risk()) return;
          const j = g2.law.jurAt(pl.x, pl.y), b0 = g2.law.bounty[j] || 0;
          g2.law.bounty[j] = Math.round(b0 * 0.4);
          g2.ui.toast(`A cardboard box, walked out the back in broad daylight. Bounty here ${R.fmtMoney(b0)} → ${R.fmtMoney(g2.law.bounty[j])}.`, 'good');
        } });
      }
      if (pl.disguise && (b.type === 'house' || b.type === 'hotel' || b.type === 'motel' || b.type === 'tailor' || b.type === 'apartment')) o.push({ label: 'Take off the uniform', small: 'Back to yourself', fn: () => { DS.off(); g2.ui.toast('The uniform goes in a bag. Your own face again.'); } });
      return o;
    };
  };
})();
