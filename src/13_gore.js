// RHAPSODY — wounds you can see. Fists and bats bruise (faces go purple, and it fades);
// bullets and blades open wounds that stain the shirt, drip a trail and drain health until
// they clot or get bandaged. Big hits take more: a point-blank shotgun, a heavy round, a
// car or a blast can take off an arm or the head, which bounce and roll away.
// Everything here respects the Blood & gore setting.
'use strict';
(function () {
  const TS = R.TILE, D = R.data;
  const GO = (R.gore = { parts: [] });
  const G = () => R.game;
  const on = () => G() && G().settings.gore !== false;
  const wnd = (a) => { a.wnd = a.wnd || { bruise: 0, bleed: 0 }; if (a.look) a.look._w = a.wnd; return a.wnd; };
  const BLOOD = ['#8a1a14', '#a8201a', '#6a1410'];

  // record the wound as the hit lands
  const C = R.combat, baseDamage = C.damage;
  C.damage = function (target, amt, source, kind) {
    if (target && target.kind === 'h' && !target.dead && target !== G().player) GO.hurt(target, amt, source, kind);
    return baseDamage.call(this, target, amt, source, kind);
  };
  GO.hurt = function (a, amt, source, kind) {
    const w = wnd(a);
    const blade = source && ((D.weapons[source.weapon] && D.weapons[source.weapon].blade) || (source.held && source.held.k === 'bottle'));
    if (kind === 'melee' && !blade) w.bruise = Math.min(1, w.bruise + amt / 45);
    else if (kind === 'bullet' || kind === 'blast' || blade) w.bleed = Math.min(1, w.bleed + amt / (kind === 'blast' ? 60 : 90));
    else if (kind === 'car' || kind === 'fall') { w.bruise = Math.min(1, w.bruise + amt / 60); w.bleed = Math.min(1, w.bleed + amt / 200); }
  };
  // the big ones: heads and arms
  const baseKill = C.kill;
  C.kill = function (h, source, kind) {
    const was = h && h.dead;
    const r = baseKill.call(this, h, source, kind);
    if (was || !h || h.kind !== 'h' || h.gibbed || !on()) return r;
    const k = kind || h.lastHitKind;
    const wpn = source && source.weapon, d = source && source.x != null ? Math.hypot(source.x - h.x, source.y - h.y) : 999;
    const close = d < TS * 3.2;
    let pHead = 0, pArm = 0;
    if (k === 'blast') { pHead = 0.45; pArm = 0.55; }
    else if (k === 'bullet' && wpn === 'shotgun') { pHead = close ? 0.4 : 0.08; pArm = close ? 0.3 : 0.05; }
    else if (k === 'bullet' && (wpn === 'magnum' || wpn === 'rifle')) { pHead = 0.12; pArm = 0.05; }
    else if (k === 'car') { pHead = 0.12; pArm = 0.22; }
    else if (k === 'melee' && wpn === 'knife') pArm = 0.04;
    const ang = source && source.x != null ? Math.atan2(h.y - source.y, h.x - source.x) : R.rng() * 6.28;
    const w = wnd(h);
    if (R.rng() < pHead) this.decap(h, ang, w);
    else if (R.rng() < pArm) this.sever(h, ang, w);
    return r;
  };
  C.decap = function (h, ang, w) {
    const g = G();
    w.headless = true;
    const spr = R.art.oldSprite(h.look, 2, 0, null);
    GO.parts.push({ kind: 'head', spr, x: h.x, y: h.y - 18, floor: h.y + (R.rng() - 0.3) * 8, vx: Math.cos(ang) * (60 + R.rng() * 60), vy: -90 - R.rng() * 40, rot: 0, vr: (R.rng() - 0.5) * 18, t: 0 });
    g.fx.spray(h.x, h.y - 14, -Math.PI / 2, 18);
    g.fx.spray(h.x, h.y - 14, ang, 10);
    g.fx.decal({ x: h.x + 10, y: h.y - 2, r: 3, grow: 10, rate: 2.2, c: 'rgba(96,14,12,0.65)', t: 900 });
    if (GO.parts.length > 60) GO.parts.shift();
  };
  C.sever = function (h, ang, w) {
    const g = G();
    w.armless = true;
    const col = (h.look && (h.look.jacketCol || h.look.top)) || '#3a3a4a';
    GO.parts.push({ kind: 'arm', col, skin: (h.look && h.look.skin) || '#d8a070', x: h.x + Math.cos(ang) * 4, y: h.y - 12, floor: h.y + (R.rng() - 0.3) * 10, vx: Math.cos(ang) * (50 + R.rng() * 50) + (R.rng() - 0.5) * 40, vy: -70 - R.rng() * 40, rot: R.rng() * 6, vr: (R.rng() - 0.5) * 20, t: 0 });
    g.fx.spray(h.x, h.y - 12, ang, 12);
    g.fx.decal({ x: h.x, y: h.y, r: 3, grow: 8, rate: 2, c: 'rgba(96,14,12,0.6)', t: 900 });
    if (GO.parts.length > 60) GO.parts.shift();
  };

  // live wounds: bleeding drains, bruises fade
  GO.update = function (dt) {
    const g = G(), pl = g.player;
    // parts in flight
    for (const p of this.parts) {
      if (p.rest) continue;
      p.t += dt;
      p.vy += 320 * dt; p.x += p.vx * dt; p.y += p.vy * dt; p.rot += p.vr * dt;
      if (R.rng() < dt * 20 && on()) g.fx.decal({ x: p.x, y: Math.max(p.y, p.floor) + 2, r: 1, c: 'rgba(110,20,16,0.55)', t: 600 });
      if (p.y >= p.floor) {
        p.y = p.floor;
        if (Math.abs(p.vy) > 60) { p.vy = -p.vy * 0.3; p.vx *= 0.5; p.vr *= 0.5; }
        else { p.rest = true; p.vx = 0; p.vy = 0; g.fx.decal({ x: p.x, y: p.y + 1, r: 2, grow: 5, rate: 1, c: 'rgba(96,14,12,0.6)', t: 900 }); }
      }
    }
    // people bleeding
    for (const a of g.actors.list) {
      const w = a.wnd;
      if (!w || a.dead || a.kind !== 'h') continue;
      if (w.bruise > 0) w.bruise = Math.max(0, w.bruise - dt * 0.006);
      if (w.bleed > 0.02) {
        a.hp -= w.bleed * 3 * dt;
        w.bleed = Math.max(0, w.bleed - dt * 0.012);
        if (on() && R.rng() < dt * (1 + w.bleed * 5)) g.fx.decal({ x: a.x + (R.rng() - 0.5) * 4, y: a.y + 1, r: 0.8 + w.bleed, c: 'rgba(110,20,16,0.55)', t: 500 });
        if (a.hp <= 0) { a.lastHitKind = 'bleed'; C.kill(a, a.lastHitBy || null, 'bleed'); }
      }
    }
    // you
    const w = pl.wnd;
    if (w) {
      if (pl.look) pl.look._w = w;
      if (w.bruise > 0) w.bruise = Math.max(0, w.bruise - dt * 0.01);
      if (w.bleed > 0.02 && !pl.dead) {
        if (!(g.cheats && g.cheats.god)) pl.hp -= w.bleed * 1.6 * dt;
        w.bleed = Math.max(0, w.bleed - dt * 0.01);
        if (on() && R.rng() < dt * (1 + w.bleed * 5)) g.fx.decal({ x: pl.x + (R.rng() - 0.5) * 4, y: pl.y + 1, r: 0.8 + w.bleed, c: 'rgba(110,20,16,0.55)', t: 500 });
        if (w.bleed > 0.3 && !w.warned) { w.warned = true; g.ui.toast('You\'re bleeding. Use a bandage (ITEM) or get to a hospital.', 'bad'); }
        if (pl.hp <= 0) pl.die();
      }
      if (pl.hp >= pl.maxHp) { w.bleed = 0; w.warned = false; }
    }
  };
  GO.init = function (g) {
    this.parts = [];
    if (this.wrapped) return;
    this.wrapped = true;
    const PP = R.Player.prototype, baseHurt = PP.hurt;
    PP.hurt = function (amt, src, kind) {
      const hp0 = this.hp;
      const r = baseHurt.call(this, amt, src, kind);
      if (this.hp < hp0) {
        const w = this.wnd = this.wnd || { bruise: 0, bleed: 0 };
        const blade = src && D.weapons[src.weapon] && D.weapons[src.weapon].blade;
        if (kind === 'melee' && !blade) w.bruise = Math.min(1, w.bruise + amt / 50);
        else if (kind === 'bullet' || kind === 'blast' || blade) w.bleed = Math.min(1, w.bleed + amt / 100);
      }
      return r;
    };
    const baseAct = R.goods.act;
    R.goods.act = function (it, a) {
      const r = baseAct.call(this, it, a);
      if (a === 'use' && it.key === 'bandage' && g.player.wnd) { g.player.wnd.bleed = 0; g.ui.toast('Bandaged tight. The bleeding stops.', 'good'); }
      return r;
    };
  };

  // ---------------------------------------------------------------- drawing
  GO.draw = function (g) {
    if (!on()) return;
    for (const p of this.parts) {
      g.save();
      g.translate(Math.round(p.x), Math.round(p.y));
      g.rotate(p.rest ? Math.round(p.rot / (Math.PI / 2)) * (Math.PI / 2) : p.rot);
      if (p.kind === 'head') {
        g.drawImage(p.spr, 0, 0, p.spr.width, 14, -p.spr.width / 2, -9, p.spr.width, 14);
        g.fillStyle = '#6a1410'; g.fillRect(-3, 4, 6, 1);
      } else {
        g.fillStyle = '#140e10'; g.fillRect(-1, -5, 4, 11);
        g.fillStyle = p.col; g.fillRect(0, -4, 2, 6);
        g.fillStyle = p.skin; g.fillRect(0, 2, 2, 3);
        g.fillStyle = '#a8201a'; g.fillRect(0, -5, 2, 1);
      }
      g.restore();
    }
  };
  const A = R.art, baseDraw = A.drawPerson;
  A.drawPerson = function (g, x, y, dir, walk, look, st) {
    const w = look && look._w;
    if (!w || !on() || !(w.bruise > 0.05 || w.bleed > 0.05 || w.headless || w.armless)) return baseDraw.call(this, g, x, y, dir, walk, look, st);
    st = st || {};
    const X = Math.round(x), Y = Math.round(y);
    if (st.down && w.headless) {
      // the body lies with its head to the right; cut it off at the neck
      g.save(); g.beginPath(); g.rect(X - 40, Y - 40, 49, 80); g.clip();
      baseDraw.call(this, g, x, y, dir, walk, look, st);
      g.restore();
      g.fillStyle = '#6a1410'; g.fillRect(X + 7, Y - 5, 3, 4); g.fillStyle = '#a8201a'; g.fillRect(X + 8, Y - 4, 1, 2);
      return;
    }
    baseDraw.call(this, g, x, y, dir, walk, look, st);
    if (st.down || st.scale || st.crouch || st.alpha != null) return;
    const seed = (look.seedStr || '').length * 7 + 3;
    const d8 = A.dir8(dir, st.ang), backTurned = d8 === 5 || d8 === 6 || d8 === 7;
    // bruises on the face, when you can see the face
    if (w.bruise > 0.05 && !backTurned) {
      g.globalAlpha = Math.min(0.85, w.bruise);
      g.fillStyle = '#5a2a5e';
      g.fillRect(X - 3 + (seed % 3), Y - 17, 2, 1);
      if (w.bruise > 0.35) g.fillRect(X + 1, Y - 15 + (seed % 2), 1, 2);
      if (w.bruise > 0.6) { g.fillStyle = '#3a1a3e'; g.fillRect(X - 2, Y - 14, 2, 1); }
      g.globalAlpha = 1;
    }
    // blood soaking the shirt
    if (w.bleed > 0.05 || w.armless) {
      const n = Math.min(7, 1 + Math.round((w.bleed || 0.4) * 8));
      g.fillStyle = '#8a1a14';
      for (let k = 0; k < n; k++) g.fillRect(X - 3 + ((seed * (k + 3)) % 6), Y - 10 + ((seed + k * 5) % 5), k % 3 ? 1 : 2, 1);
      if (w.armless) { g.fillStyle = '#a8201a'; g.fillRect(X + 3, Y - 11, 2, 2); }
    }
  };
})();
