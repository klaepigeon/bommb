// RHAPSODY — relics: every brush with the uncanny leaves you something that changes how
// you play. They live in your pockets (Tools) and last forever.
//   Captain's Doubloon  (lay the Drowned Captain to rest): swim full speed, never tire, fish bite fast
//   Tuft of Sasquatch Fur (see the big fella): predators leave you alone
//   Probe Implant       (get abducted): you hear the police radio; search circles shrink
//   Devil's Luck        (sell your soul): better odds at every table, and some hits just miss
//   Scratch's Tooth     (kill Old Scratch): fists and blades hit a third harder
//   Ember Collar        (kill a hellhound): punches can set people alight
'use strict';
(function () {
  const D = R.data, TS = R.TILE;
  const RL = (R.relics = {});
  const G = () => R.game;
  const DEF = {
    doubloon: { name: 'Captain\'s Doubloon', desc: 'Salt-green gold from the Mary Alice. You swim like you were born in the water, never tire, and fish bite faster.' },
    tuft: { name: 'Tuft of Sasquatch Fur', desc: 'It smells like the deep woods. Bears, wolves and gators leave you alone unless you start it.' },
    implant: { name: 'Probe Implant', desc: 'Something behind your ear hums on police frequencies. You hear every dispatch, and search circles are a quarter smaller.' },
    luck: { name: 'Devil\'s Luck', desc: 'Part of the bargain. Every table leans your way, and one hit in eight just... misses.' },
    tooth: { name: 'Scratch\'s Tooth', desc: 'A gator tooth the size of a railroad spike. Fists and blades hit a third harder.' },
    collar: { name: 'Ember Collar', desc: 'Still warm. One punch in six sets the other guy on fire.' },
  };
  RL.DEF = DEF;
  for (const k in DEF) D.tools['relic_' + k] = { name: DEF[k].name };
  RL.has = (k) => { const pl = G() && G().player; return !!(pl && pl.relics && pl.relics[k]); };
  RL.grant = function (k) {
    const g = G(), pl = g.player;
    pl.relics = pl.relics || {};
    if (pl.relics[k]) return;
    pl.relics[k] = 1;
    pl.inv.tools['relic_' + k] = 1;
    g.audio.sfx('promote');
    g.ui.story(`RELIC: ${DEF[k].name.toUpperCase()}`, DEF[k].desc);
  };
  RL.init = function (g) {
    if (this.wrapped) return;
    this.wrapped = true;
    const L = R.legends;
    // the Captain's doubloon becomes a relic instead of pawn fodder
    // (checked every frame in update)
    // the sasquatch: the first sighting
    // (update watches the legends' seen marks)
    // UFO abduction: patch the abduction by watching for the missing-time story
    const baseStory = g.ui.story;
    const U = R.UI.prototype, st = U.story;
    U.story = function (title, body, cb) {
      if (/MISSING TIME|ABDUCT/i.test(title || '')) setTimeout(() => RL.grant('implant'), 600);
      return st.apply(this, arguments);
    };
    // the police radio
    const LP = R.Law.prototype, baseRadius = LP.searchRadius, baseDispatch = LP.dispatch;
    LP.searchRadius = function () { return baseRadius.call(this) * (RL.has('implant') ? 0.75 : 1); };
    LP.dispatch = function () { if (RL.has('implant') && this.incident) this.game.ui.toast('*kzzt* "All units, suspect last seen near ' + (this.incident.lastX ? `${Math.round(this.incident.lastX / TS)}, ${Math.round(this.incident.lastY / TS)}` : 'the scene') + '..."'); return baseDispatch.apply(this, arguments); };
    // the tables
    const gamble = U.gamble;
    U.gamble = function (p, stake, mult) { return gamble.call(this, p + (RL.has('luck') ? 0.08 : 0), stake, mult); };
    // some hits just miss
    const PP = R.Player.prototype, baseHurt = PP.hurt;
    PP.hurt = function (amt, src, kind) {
      if (RL.has('luck') && kind !== 'fall' && kind !== 'drown' && R.rng() < 0.125) { this.game.fx.text(this.x, this.y - 26, 'MISSED', '#ff5030'); return; }
      return baseHurt.call(this, amt, src, kind);
    };
    // harder hits, burning fists
    const C = R.combat, baseDamage = C.damage;
    C.damage = function (target, amt, source, kind) {
      const pl = G().player;
      if (source === pl && (kind === 'melee')) {
        if (RL.has('tooth')) amt *= 1.35;
        if (RL.has('collar') && target && target.kind === 'h' && R.rng() < 1 / 6) { target.burning = Math.max(target.burning || 0, 3); G().fx.text(target.x, target.y - 26, 'FWOOSH', '#ff8a30'); }
      }
      return baseDamage.call(this, target, amt, source, kind);
    };
    // legendary kills
    const baseKill = C.kill;
    C.kill = function (h, source, kind) {
      const was = h && h.dead;
      const r = baseKill.call(this, h, source, kind);
      const pl = G().player;
      if (!was && h && h.kind === 'a' && (source === pl || (source && source.driver === pl))) {
        if (h.legendary === 'scratch') setTimeout(() => RL.grant('tooth'), 500);
        if (h.def && h.def.name === 'Hellhound') setTimeout(() => RL.grant('collar'), 500);
      }
      return r;
    };
  };
  RL.update = function (dt) {
    const g = G(), pl = g.player;
    if (pl.inv.loot.doubloon > 0 && !this.has('doubloon')) { pl.inv.loot.doubloon--; this.grant('doubloon'); }
    if (g.hints.soulSold && !this.has('luck')) this.grant('luck');
    if (!g.hints.soulSold && this.has('luck')) { pl.relics.luck = 0; pl.inv.tools.relic_luck = 0; g.ui.toast('The Devil\'s luck leaves you with your soul.'); }
    const sq = R.legends.active && R.legends.active.squatch;
    if (sq && sq.spotted && !this.has('tuft')) { this.grant('tuft'); }
    // the doubloon: the water can't tire you
    if (this.has('doubloon') && pl.swimming) pl.swimT = 0;
  };
  // the doubloon swimmer isn't slowed by water
  const AP = R.Actors.prototype, baseMove = AP.moveActor;
  AP.moveActor = function (a, vx, vy, dt) {
    if (a && a === G().player && RL.has('doubloon') && R.water && R.water.wet(a.x, a.y)) { vx *= 2; vy *= 2; }
    return baseMove.call(this, a, vx, vy, dt);
  };
})();
