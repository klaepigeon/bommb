// RHAPSODY — crawling. Shoot someone in the legs, or hurt them badly enough (half their health
// gone), and they go down on their belly and crawl: the same reach-grab-drag as you in the
// desert, head first the way they're going, a smear of blood behind them. They're slow. The
// armed ones can still shoot from the ground; the rest crawl for cover, or away, or at you.
// Patch them up past three-quarters and (legs permitting) they get back on their feet.
'use strict';
(function () {
  const TS = R.TILE;
  const G = () => R.game;
  const CR = (R.crawl = { t: 0 });
  // who never goes down on their belly: bosses, the scripted, things without legs to speak of
  const exempt = (h) => h.kyle || h.hal || h.pilot || h.scripted || h.ghost || h.boss || h.mounted || (h.look && h.look.xeno === 'fearman' && h.senile === undefined);
  CR.should = function (h) {
    if (!h || h.kind !== 'h' || h.dead || h.tied || h.carried || h.inCar) return false;
    if (exempt(h) || (h.down > 0) || h.state === 'sleep' || h.state === 'perform') return false;
    if (h.crawling) return h.legShot || h.hp < h.maxHp * 0.75;
    return !!h.legShot || h.hp <= h.maxHp * 0.5;
  };
  CR.update = function (dt) {
    const g = G();
    this.t -= dt;
    const tick = this.t <= 0;
    if (tick) this.t = 0.25;
    for (const h of g.actors.list) {
      if (h.kind !== 'h' || h.dead) { if (h.crawling) h.crawling = false; continue; }
      if (tick) {
        const was = !!h.crawling;
        h.crawling = this.should(h);
        if (h.crawling && !was && R.rng() < 0.5) g.actors.say(h, R.rng.pick(['My leg! My LEG!', 'Aagh... can\'t stand...', 'Help me...', 'I\'m hit, I\'m hit!', '*groans*']));
      }
      if (!h.crawling) { h.crawlPX = h.x; h.crawlPY = h.y; continue; }
      // which way they're dragging themselves, and a smear behind them
      const dx = h.x - (h.crawlPX == null ? h.x : h.crawlPX), dy = h.y - (h.crawlPY == null ? h.y : h.crawlPY);
      h.crawlPX = h.x; h.crawlPY = h.y;
      h.crawlMoving = Math.hypot(dx, dy) > 0.02;
      if (h.crawlMoving) { h.crawlDX = dx; h.crawlDY = dy; }
      else if (h.state === 'fight' && h.target) { h.crawlDX = h.target.x - h.x; h.crawlDY = h.target.y - h.y; }
      if (h.crawlMoving && g.settings.gore !== false) {
        h.smearT = (h.smearT || 0) - dt;
        if (h.smearT <= 0) { h.smearT = 0.12; const m = Math.hypot(h.crawlDX, h.crawlDY) || 1; g.fx.decal({ x: h.x - h.crawlDX / m * 6 + (R.rng() - 0.5) * 2, y: h.y - h.crawlDY / m * 6 + 1, r: 1 + R.rng() * 0.8, c: 'rgba(110,14,10,0.5)', t: 600 }); }
      }
    }
  };
  // the prone figure: game 1's crawl sheet, head toward where they're going
  CR.draw = function (g, h) {
    const OP = R.opening, t = G().clock.real;
    const sh = OP.crawlSheet(h.look);
    const f = h.crawlMoving ? Math.floor((t + (h.id || 0) * 0.37) * 0.9 * 4) % 4 : 0;
    const dx = h.crawlDX == null ? 1 : h.crawlDX, dy = h.crawlDY || 0, vert = Math.abs(dy) > Math.abs(dx);
    g.save();
    g.translate(Math.round(h.x), Math.round(h.y));
    if (vert) g.rotate(dy < 0 ? -Math.PI / 2 : Math.PI / 2); else if (dx < 0) g.scale(-1, 1);
    g.fillStyle = 'rgba(0,0,0,0.2)'; g.fillRect(-11, -5, 22, 11);
    g.drawImage(sh.frames[f], -12, -sh.cy);
    // a gun in the reaching hand, pointed where they're looking
    const w = h.weapon && R.data.weapons[h.weapon];
    if (w && w.gun && (h.state === 'fight' || h.drawn)) { g.fillStyle = '#2a2a30'; g.fillRect(9, -2, 5, 2); g.fillStyle = '#5a5a64'; g.fillRect(9, -2, 5, 1); }
    g.restore();
  };
  CR.init = function (g) {
    this.t = 0;
    if (this.wrapped) return;
    this.wrapped = true;
    const RP = R.Renderer.prototype, dh = RP.drawHuman;
    RP.drawHuman = function (g2, h) { if (h.crawling && !h.dead && !h.tied && R.opening && R.opening.crawlSheet) return CR.draw(g2, h); return dh.call(this, g2, h); };
    // healed at a clinic, patched with a bandage: the legs work again
    const C = R.combat, dmg = C.damage;
    C.damage = function (t, amt) { const r = dmg.apply(this, arguments); if (t && t.dead) t.crawling = false; return r; };
  };
})();
