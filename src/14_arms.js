// RHAPSODY — the armory, extended. The sap puts people to sleep instead of in the ground
// (best from behind, on someone who never saw you coming). New guns and blades show up
// in the hands of the coast's worse citizens, and every new weapon gets its own icon.
'use strict';
(function () {
  const D = R.data, TS = R.TILE;
  const G = () => R.game;
  const AR = (R.arms = {});

  AR.init = function (g) {
    if (this.wrapped) return;
    this.wrapped = true;
    // the sap: a knockout, not a killing
    const C = R.combat, dmg = C.damage;
    C.damage = function (t, amt, source, kind) {
      const pl = G().player;
      if (source === pl && kind === 'melee' && pl.weapon === 'sap' && t && t.kind === 'h' && !t.dead && !t.cop) {
        const unaware = t.state !== 'fight' && t.state !== 'flee' && !t.hostile;
        const behind = Math.abs(R.angDiff(t.ang || 0, Math.atan2(t.y - pl.y, t.x - pl.x))) < 1.2;
        if (unaware || t.hp < 45) {
          t.down = Math.max(t.down || 0, behind ? 30 : 16);
          t.ko = true;
          G().fx.text(t.x, t.y - 26, 'OUT COLD', '#e0d0a0');
          G().audio.sfx('punch', t.x, t.y);
          return dmg.call(this, t, Math.min(amt, Math.max(0, t.hp - 5)), source, kind);
        }
      }
      return dmg.call(this, t, amt, source, kind);
    };
    // icons for the new hardware
    const Goods = R.goods, icon = Goods.icon;
    const extra = { silencer: () => { const o = new R.old.O(16, 16); o.shadedRect(3, 6, 10, 4, R.old.x.black); o.hline(3, 12, 6, '#7a7a84'); return o.outlineBy(R.old.Ue).toCanvas(); }, bolts: () => { const o = new R.old.O(16, 16); for (let k = 0; k < 3; k++) { o.line(3 + k * 3, 13, 9 + k * 3, 3, R.old.x.wood[2]); o.set(9 + k * 3, 3, '#c8c8d0'); } return o.outlineBy(R.old.Ue).toCanvas(); } };
    const cache = {};
    Goods.icon = function (key, j) {
      if (!j && (extra[key] || (D.weapons[key] && ['derringer', 'colt45', 'sawedoff', 'carbine', 'crossbow', 'tommy', 'razor', 'machete', 'hatchet', 'crowbar', 'sap'].includes(key)))) {
        if (cache[key]) return cache[key];
        let cv = extra[key] ? extra[key]() : null;
        if (!cv) { const a = R.art.gunArt(key) || R.art.itemArt(key); cv = a && a.cv; }
        if (cv) return (cache[key] = cv);
      }
      return icon.call(this, key, j);
    };
    // the underworld re-arms
    const AP = R.Actors.prototype, arm = AP.arm;
    AP.arm = function (h, w) {
      if (h && h.faction && h.faction !== 'law' && !h.cop && R.rng() < 0.35) w = R.rng.pick({ revolver: ['colt45', 'derringer'], magnum: ['colt45'], shotgun: ['sawedoff'], chopper: ['tommy'], knife: ['razor', 'machete'], bat: ['crowbar', 'hatchet'] }[w] || [w]);
      return arm.call(this, h, w);
    };
  };
})();
