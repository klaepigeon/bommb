// RHAPSODY — the opening. You choose a name. Somebody else chose to put two bullets in
// you and leave you in the Dustwater flats. You come to in the sand and crawl, bleeding,
// for the highway. A long black car stops. One of the five dons of the Brass Coast looks
// down at you and decides you're worth saving. You wake up in his back room, and how you
// talk to him decides how the two of you start.
'use strict';
(function () {
  const D = R.data, TS = R.TILE;
  const OP = (R.opening = {});
  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
  const FIRST = ['Nicky', 'Tony', 'Sal', 'Vinnie', 'Frankie', 'Eddie', 'Johnny', 'Ray', 'Danny', 'Lou', 'Carmine', 'Joey', 'Rico', 'Dom', 'Benny', 'Mickey'];
  const LAST = ['Marchetti', 'Russo', 'Gallo', 'Costa', 'Moretti', 'DeLuca', 'Ferraro', 'Conti', 'Romano', 'Bruno', 'Esposito', 'Rizzo', 'Greco', 'Santoro', 'Lombardi', 'Caruso'];
  const NICK = ['The Mook', 'Knuckles', 'Two-Tone', 'Lucky', 'The Kid', 'Slick', 'Spats', 'Ice', 'Doc', 'Cadillac', 'Sugar', 'The Ghost', 'Lefty', 'Sideburns'];

  // ---------------------------------------------------------------- 1. who are you
  OP.nameSheet = function (g, done) {
    const pl = g.player, ui = g.ui, pick = (a) => a[(Math.random() * a.length) | 0];
    const vals = { first: pick(FIRST), last: pick(LAST), nick: pick(NICK) };
    const html = `${ui.header('Who are you?')}<div class="body"><p style="font-size:13px;color:var(--brown);margin:0 0 4px">A name the papers will spell wrong for years.</p>
      ${[['first', 'First name'], ['last', 'Last name'], ['nick', 'They call you']].map(([k, l]) => `<div style="display:flex;gap:6px;align-items:center;margin:5px 0"><label style="width:6.5em;font-size:13px">${l}</label><input data-k="${k}" maxlength="18" value="${esc(vals[k])}" style="flex:1;min-width:0;font:inherit;font-size:16px;padding:4px 8px;border:3px solid var(--ink);background:#fffaf0;color:var(--ink)"><button class="chip c-talk" data-roll="${k}">🎲</button></div>`).join('')}
      <div class="opts" style="margin-top:8px"><button class="opt go" id="nameGo">That's me</button></div></div>`;
    const s = ui.openSheet('name', html, true);
    s.querySelectorAll('button').forEach((b) => { if (b.textContent.trim() === '✕' || b.getAttribute('aria-label') === 'Close') b.remove(); });
    const input = (k) => s.querySelector(`input[data-k="${k}"]`);
    s.querySelectorAll('[data-roll]').forEach((b) => b.addEventListener('click', () => { const k = b.dataset.roll; input(k).value = pick(k === 'first' ? FIRST : k === 'last' ? LAST : NICK); }));
    s.querySelector('#nameGo').addEventListener('click', () => {
      const v = (k) => (input(k).value || '').trim().slice(0, 18) || vals[k];
      pl.first = v('first'); pl.last = v('last'); pl.nick = v('nick');
      ui.forceClose = true; ui.closeSheet(); ui.forceClose = false;
      done();
    });
  };

  // ---------------------------------------------------------------- 2. the desert
  OP.run = function (g) {
    const pl = g.player;
    pl.stats.startT = g.clock.t;
    for (const a of g.actors.list.slice()) if (a !== pl && !a.keep) g.actors.remove(a);
    this.nameSheet(g, () => this.desert(g));
  };
  OP.desert = function (g) {
    const pl = g.player, w = g.world;
    if (pl.room) g.interiors.exit();
    const dust = w.cities.find((c) => c.id === 'dust') || w.cities[2];
    // a stretch of highway outside Dustwater, and a spot of sand a way off it
    const T = D.T, desert = (x, y) => { let n = 0; for (let k = 0; k < 8; k++) { const t = w.t(x + ((k * 7) % 11) - 5, y + ((k * 5) % 9) - 4); if (t === T.DESERT || t === T.SAND || t === T.DIRT) n++; } return n >= 5; };
    const open = (x, y) => D.roadTile[w.t(x, y)] && !w.cityAt(x, y) && !w.inCityRect(x, y, 10);
    let road = null;
    for (let r = 14; r < 160 && !road; r += 6) for (let k = 0; k < 6 && !road; k++) road = w.findNear(dust.cx, dust.cy, r, r + 6, (x, y) => open(x, y) && desert(x, y));
    for (let r = 14; r < 160 && !road; r += 12) road = w.findNear(dust.cx, dust.cy, r, r + 12, open);
    if (!road) for (let i = 0; i < 4000 && !road; i++) { const x = (Math.random() * w.W) | 0, y = (Math.random() * w.H) | 0; if (open(x, y)) road = { x, y }; }
    // any road out of town will do
    if (!road) for (let i = 0; i < 20000 && !road; i++) { const x = (Math.random() * w.W) | 0, y = (Math.random() * w.H) | 0; if (D.roadTile[w.t(x, y)] && !w.cityAt(x, y)) road = { x, y }; }
    const clear = (x, y) => !w.solidPed(x, y) && !w.isWater(x, y) && !D.roadTile[w.t(x, y)] && !w.cityAt(x, y);
    let spot = null;
    if (road) for (let r = 10; r <= 22 && !spot; r += 2) for (let k = 0; k < 16 && !spot; k++) { const a = k / 16 * Math.PI * 2, x = Math.round(road.x + Math.cos(a) * r), y = Math.round(road.y + Math.sin(a) * r); if (clear(x, y) && clear(x, y - 1) && clear(x, y - 2)) spot = { x, y }; }
    if (!road || !spot) return this.wake(g); // a world with no roads at all
    this.road = road;
    g.clock.t = Math.floor(g.clock.t / 1440) * 1440 + 4 * 60 + 50; // before dawn
    pl.cash = 0; pl.inv.weapons = { fists: 1 }; pl.weapon = 'fists'; pl.weaponOut = false;
    this.stage(g, spot);
  };

  // ---------------------------------------------------------------- 2a. the shooting
  // Two men, a car with its lights off, a walk into the sand. You get one thing to say.
  OP.stage = function (g, spot) {
    const pl = g.player, sx = spot.x * TS + 8, sy = spot.y * TS + 8;
    const st = this.street(g);
    // two real people from the Coast, so you can find them again someday
    const pool = g.pop.people.filter((p) => p.alive && !p.fem && p.age >= 22 && p.age <= 52 && p.role !== 'cop' && p.role !== 'don' && !p.isDon && !p.actor && !p.faction);
    const men = [R.rng.pick(pool), null]; men[1] = R.rng.pick(pool.filter((p) => p !== men[0]));
    st.shooters = men.filter(Boolean).map((p) => p.id);
    const toRoad = Math.atan2(this.road.y * TS - sy, this.road.x * TS - sx);
    const car = g.traffic.make('sedan', sx + Math.cos(toRoad) * 40, sy + 30, toRoad + Math.PI, { parked: true, keep: true, color: '#1c1c20', locked: true });
    pl.place(sx, sy + 12);
    g.cam.x = pl.x; g.cam.y = pl.y;
    pl.hp = pl.maxHp;
    const thugs = men.filter(Boolean).map((p, i) => {
      if (p.actor && !p.actor.dead) g.actors.remove(p.actor);
      const h = g.life.spawnPerson(p, sx + (i ? 12 : -12), sy + 28);
      if (!h) return null;
      h.keep = true; h.stay = true; h.state = 'idle'; h.timer = 1e9; h.hostile = false; h.noTalk = true; h.scripted = true;
      g.actors.arm(h, i ? 'shotgun' : 'revolver');
      h.look.hatKind = 'fedora'; h.look.hatCol = '#2a2a2a';
      return h;
    }).filter(Boolean);
    this.scene = { t: 0, stage: 0, car, thugs, sx, sy, toRoad };
    this.lock = { x: 0, y: 0 };
    g.ui.toast('Dustwater flats. 4:50 in the morning.', 'warn');
    if (thugs[0]) g.actors.say(thugs[0], 'Out. Walk. Into the desert, nice and slow.');
  };
  OP.street = function (g) { const pl = g.player; pl.street = pl.street || {}; return (pl.street.desert = pl.street.desert || {}); };
  OP.runScene = function (g, dt) {
    const sc = this.scene, pl = g.player, [a, b] = sc.thugs;
    sc.t += dt;
    const follow = (h, ox, oy, spd) => { if (!h || h.dead) return; const tx = pl.x + ox, ty = pl.y + oy, d = Math.hypot(tx - h.x, ty - h.y); if (d > 3) g.actors.moveActor(h, (tx - h.x) / d * spd, (ty - h.y) / d * spd, dt); h.state = 'idle'; h.timer = 1e9; };
    const face = (h) => { if (h) { h.ang = Math.atan2(pl.y - h.y, pl.x - h.x); h.dir = pl.y < h.y ? 3 : 0; } };
    if (sc.stage === 0 && sc.t > 1.6) { sc.stage = 1; sc.t = 0; }
    if (sc.stage === 1) { // the walk
      this.lock = { x: 0, y: -0.55 };
      follow(a, -9, 20, 38); follow(b, 9, 22, 38);
      if (pl.y <= sc.sy - 22 || sc.t > 6) { sc.stage = 2; sc.t = 0; this.lock = { x: 0, y: 0 }; if (b) g.actors.say(b, 'That\'s far enough. Turn around.'); }
    }
    if (sc.stage === 2) {
      face(a); face(b);
      if (sc.t > 0.35 && sc.t < 0.5) this.lock = { x: 0, y: 0.05 }; else this.lock = { x: 0, y: 0 };
      if (sc.t > 1.5 && !sc.asked) { sc.asked = true; this.lastWords(g); }
      // closed the question without answering: silence is an answer too
      if (sc.asked && sc.t > 2.5 && !g.ui.sheetOpen) { sc.stage = 3; sc.t = 0; }
    }
    if (sc.stage === 3) { // the shots
      face(a); face(b);
      if (a) { a.weaponOut = true; a.aiming = true; }
      if (sc.t > 0.2 && !sc.said) { sc.said = true; if (a) g.actors.say(a, sc.lunged ? 'Hold STILL, you son of a—' : 'Nothing personal, kid.'); }
      if (sc.t > 1.4 && !sc.shot1) { sc.shot1 = true; this.shoot(g, a, true); }
      if (sc.t > 2.0 && !sc.shot2) { sc.shot2 = true; this.shoot(g, a, !sc.lunged); pl.crawling = true; pl.hp = sc.lunged ? 30 : 22; }
      if (sc.t > 3.4) { sc.stage = 4; sc.t = 0; if (b) g.actors.say(b, 'Leave him for the buzzards. Come on.'); }
    }
    if (sc.stage === 4) { // they leave
      for (const h of sc.thugs) { if (!h || h.removed) continue; const d = Math.hypot(sc.car.x - h.x, sc.car.y - h.y); if (sc.t > 1 && d > 10) g.actors.moveActor(h, (sc.car.x - h.x) / d * 45, (sc.car.y - h.y) / d * 45, dt); if (d <= 12 || sc.t > 5) { h.weaponOut = false; g.actors.remove(h); h.removed = true; } }
      if (sc.thugs.every((h) => !h || h.removed)) {
        if (!sc.driving) { sc.driving = 0; sc.car.lights = true; g.audio.sfx('horn'); }
        sc.driving += dt;
        const ang = sc.toRoad; sc.car.angle = ang; sc.car.x += Math.cos(ang) * 70 * dt; sc.car.y += Math.sin(ang) * 70 * dt;
        if (sc.driving > 3.2) { g.traffic.remove(sc.car); sc.stage = 5; this.afterShots(g); }
      }
    }
  };
  OP.lastWords = function (g) {
    const sc = this.scene, pl = g.player, [a, b] = sc.thugs, st = this.street(g);
    const say = (h, t) => h && g.actors.say(h, t);
    const go = () => { sc.stage = 3; sc.t = 0; };
    g.ui.choice('"Any last words?"', [
      { label: '"Who sent you?"', small: 'Maybe they slip', fn: () => { const fams = D.cities.map((c) => c.family); st.sentBy = R.rng.pick(fams); say(a, `Doesn't matter now. But the ${st.sentBy}s say hello.`); go(); } },
      { label: 'Look them in the eye', small: 'Remember these faces', fn: () => { st.faces = true; say(b, 'Quit staring at me.'); go(); } },
      { label: '"Please. I got money. I can get money—"', small: 'Beg', fn: () => { say(a, 'No you don\'t. We checked.'); go(); } },
      { label: 'Spit on his shoes', small: 'Infamy +', fn: () => { pl.rep.infamy += 2; say(a, 'Tough guy. Tough guys bleed the same.'); go(); } },
      { label: 'Lunge at him', small: 'You won\'t win. But he might miss', fn: () => { sc.lunged = true; pl.rep.infamy += 1; if (a) { a.hp -= 6; g.cam.shake(3); g.audio.sfx('punch'); a.x -= 6; } say(a, 'Son of a—!'); go(); } },
    ]);
  };
  OP.shoot = function (g, h, hit) {
    const pl = g.player;
    if (!h) return;
    const ang = Math.atan2(pl.y - 6 - h.y, pl.x - h.x);
    h.ang = ang;
    const [mx, my] = R.art.muzzle ? R.art.muzzle(h, h.weapon, ang) : [h.x, h.y - 10];
    g.fx.flash(mx, my); g.fx.sparks(mx, my, 4);
    g.audio.sfx(h.weapon === 'shotgun' ? 'shotgun' : 'shot');
    g.cam.shake(4); g.hitStop = 0.12;
    if (hit) {
      if (g.settings.gore !== false) { g.fx.blood(pl.x, pl.y - 6, 18); for (let k = 0; k < 6; k++) g.fx.decal({ x: pl.x + (Math.random() - 0.5) * 12, y: pl.y + (Math.random() - 0.3) * 8, r: 1 + Math.random() * 2.4, c: 'rgba(110,16,12,0.8)', t: 900 }); }
      pl.bloody = 1; if (R.butcher) R.butcher.mark(pl, 20, h, 'bullet');
    } else g.fx.sparks(pl.x + 10, pl.y + 4, 6);
  };
  OP.afterShots = function (g) {
    const pl = g.player, road = this.road;
    this.scene = null; this.lock = null;
    pl.crawling = true; pl.bloody = 1; pl.gutWound = true;
    g.waypoint = { x: road.x * TS + 8, y: road.y * TS + 8 };
    g.ui.story(`${pl.first} "${pl.nick}" ${pl.last}`, 'Two holes in you, one in the gut. The taillights shrink to nothing.\n\nThey think you\'re dead. You\'re not. Not yet.\n\nThere\'s a highway out there somewhere. Crawl.', () => g.ui.toast('Crawl to the highway. Follow the gold line.', 'warn'));
  };
  OP.update = function (dt) {
    const g = R.game, pl = g.player;
    if (this.scene) return this.runScene(g, dt);
    if (!pl.crawling) return;
    pl.hp = Math.max(8, pl.hp); // you're too stubborn to die out here
    // which way you're dragging yourself
    const dx = pl.x - (this.lastX == null ? pl.x : this.lastX), dy = pl.y - (this.lastY == null ? pl.y : this.lastY);
    this.lastX = pl.x; this.lastY = pl.y;
    if (Math.abs(dx) > 0.02 || Math.abs(dy) > 0.02) { this.dirX = dx; this.dirY = dy; this.faceL = dx < 0; }
    const moving = Math.hypot(dx, dy) > 0.02;
    // the gut wound leaves a smear behind you, and a pool when you stop to rest
    if (g.settings.gore !== false) {
      const m = Math.hypot(this.dirX || 1, this.dirY || 0) || 1, bx = pl.x - (this.dirX || 1) / m * 1, by = pl.y - (this.dirY || 0) / m * 1 + 1;
      this.trail = (this.trail || 0) - dt;
      if (moving && this.trail <= 0) {
        this.trail = 0.07;
        g.fx.decal({ x: bx + (Math.random() - 0.5) * 2, y: by + (Math.random() - 0.5) * 3, r: 1.3 + Math.random() * 0.9, c: `rgba(${100 + (Math.random() * 30) | 0},14,10,0.6)`, t: 900 });
        if (Math.random() < 0.25) g.fx.decal({ x: bx + (Math.random() - 0.5) * 8, y: by + (Math.random() - 0.5) * 7, r: 0.6, c: 'rgba(120,18,12,0.7)', t: 900 });
      } else if (!moving && this.trail <= 0) {
        this.trail = 0.5;
        this.pool = Math.min(4.5, (this.pool || 1.5) + 0.25);
        g.fx.decal({ x: bx, y: by + 1, r: this.pool, c: 'rgba(90,10,8,0.35)', t: 900 });
      }
      if (moving) this.pool = 1.5;
    }
    const r = this.road;
    if (r && Math.hypot(pl.x / TS - r.x, pl.y / TS - r.y) < 2.2 && !this.pickedUp) { this.pickedUp = true; this.pickup(g); }
  };
  OP.pickup = function (g) {
    const pl = g.player;
    const fams = D.cities.map((c) => c.family);
    const fam = fams[(Math.random() * fams.length) | 0];
    const city = g.jobs.cityOfFamily(fam), club = city.buildings.find((b) => b && b.type === 'social');
    const don = D.cities.find((c) => c.family === fam).don;
    pl.family = fam; g.homeClub = club.id;
    g.waypoint = null;
    // a long black car pulls over
    const car = g.traffic.make('sedan', pl.x - 60, pl.y + 4, 0, { parked: false, keep: true, color: '#141418' });
    if (car) { car.vx = 60; car.driver = null; }
    g.ui.story('Headlights', `A long black car slows, stops. A door opens. Expensive shoes on the gravel.\n\n"This one's still breathing, boss."\n\nA man in a camel coat crouches over you. ${don}. You know the face from the newspapers.\n\n"Put him in the back. Careful with the upholstery."`, () => {
      if (car) g.traffic.remove(car);
      pl.crawling = false;
      this.wake(g, club, fam, don);
    });
  };

  // ---------------------------------------------------------------- 3. the back room
  OP.wake = function (g, club, fam, don) {
    const pl = g.player;
    fam = fam || pl.family; club = club || g.world.buildings[g.homeClub];
    don = don || (D.cities.find((c) => c.family === fam) || {}).don || 'the Don';
    const dn = g.jobs.donName(fam);
    g.clock.skip(60 * 26);
    pl.hp = pl.maxHp; pl.bloody = 0; if (pl.wnd) pl.wnd.bleed = 0;
    pl.inv.weapons = { fists: 1, revolver: 1 }; pl.weapon = 'fists'; pl.cash = 60;
    pl.place(club.out.x * TS + 8, club.out.y * TS + 12);
    g.interiors.enter(club, 'guest');
    g.cutscene = true;
    // the don himself, across the table
    setTimeout(() => {
      const dp = R.campaign.donOf(fam);
      if (!dp || !dp.alive || !pl.room) return;
      if (dp.actor && !dp.actor.dead) g.actors.remove(dp.actor);
      const h = g.life.spawnPerson(dp, pl.x + 20, pl.y - 6);
      if (h) { h.keep = true; h.stay = true; h.state = 'idle'; h.timer = 1e9; h.room = pl.room; h.dir = 3; h.ang = Math.PI; dp.met = true; dp.fam = Math.max(dp.fam || 0, 3); dp.opinion = Math.max(dp.opinion || 0, 20); }
    }, 50);
    const J = g.jobs, st = (d) => { J.standing[fam] = R.clamp((J.standing[fam] || 0) + d, -100, 100); };
    const ask = (title, line, opts) => new Promise((res) => g.ui.story(title, line, () => setTimeout(() => g.ui.choice(`Don ${dn}`, opts.map((o) => ({ label: o[0], small: o[1], fn: () => { o[2](); res(o[3]); } }))), 150)));
    (async () => {
      await ask(`${club.name}, a day later`, `Stitches in your side, a clean shirt that isn't yours, and a glass of something brown on the table.\n\nDon ${dn} sits across from you, turning a ring on his finger.\n\n"My driver found you on the side of my road with two holes in you. So. Who did you upset?"`, [
        ['"I don\'t remember."', 'Keep it close', () => {}],
        ['"Somebody who\'s gonna regret it."', 'Infamy +', () => { pl.rep.infamy += 3; }],
        ['"Thank you for stopping, Don ' + dn + '."', 'Honor +, he likes manners', () => { pl.rep.honor += 4; st(5); }],
      ]);
      await ask('The debt', `"My doctor says you'll live. Doctors cost money. The shirt cost money. The silence of my driver, that cost the most."\n\nHe smiles without his eyes.`, [
        ['"I\'ll pay you back. Every cent."', 'Honor +, standing +', () => { pl.rep.honor += 3; st(8); }],
        ['"What\'s it gonna cost me?"', 'Straight to business', () => { st(2); }],
        ['"I didn\'t ask for your help."', 'Infamy +, standing −', () => { pl.rep.infamy += 3; st(-8); }],
      ]);
      await ask('The offer', `"A man with nothing to lose is useful to me. You work for the ${fam} family now, or you walk out that door and take your chances with whoever shot you."`, [
        ['"When do I start?"', 'Standing +', () => { st(10); }],
        ['"I\'m my own man. But I\'ll hear you out."', 'Honor +, he respects it, barely', () => { pl.rep.honor += 2; }],
        ['"What\'s the pay?"', '$100 up front, standing −', () => { pl.addCash(100, true); st(-4); }],
      ]);
      const offers = J.offersFor(fam);
      const first = offers.find((o) => o.kind === 'collect') || offers[0];
      if (first) { J.accept(first); J.offers[fam] = offers.filter((o) => o !== first); }
      g.cutscene = false;
      g.ui.story('Welcome to the family', `"Good. Here's something small, to start."\n\nHe slides a slip of paper across the table. A name, an address, an amount.\n\nSomewhere out there are the men who left you in the desert. For now, you work for Don ${dn}.`, () => {
        g.ui.toast(`Talk to Don ${dn} for more work. Your first job is marked in gold. Walk out the doormat to leave.`, 'good');
        setTimeout(() => g.ui.toast('Crimes only count if someone sees them. Watch for gold "!" witnesses.'), 7000);
        g.save();
      });
    })();
  };

  // ---------------------------------------------------------------- crawling
  OP.init = function (g) {
    this.pickedUp = false; this.road = null;
    if (this.wrapped) return;
    this.wrapped = true;
    const AP = R.Actors.prototype, mv = AP.moveActor;
    // crawling comes in pulls: reach, grab the sand, drag
    AP.moveActor = function (a, vx, vy, dt) {
      if (a && a.crawling) { const k = 0.34 * (0.15 + 1.7 * Math.max(0, Math.sin(R.game.clock.real * Math.PI * 2 * 0.9))); vx *= k; vy *= k; }
      return mv.call(this, a, vx, vy, dt);
    };
    // no one moves you but the men with the guns
    const IP = R.Input.prototype, iu = IP.update;
    IP.update = function () {
      iu.call(this);
      const L = OP.lock;
      if (L) { this.stick.x = L.x; this.stick.y = L.y; for (const k in this.pressedA) this.pressedA[k] = false; for (const k in this.heldA) this.heldA[k] = false; }
    };
    // nobody makes small talk with the men who are about to shoot you
    const U = R.UI.prototype, uc = U.updateCtx;
    U.updateCtx = function () { if (OP.scene) this.game.player.focus = null; return uc.call(this); };
    const RP = R.Renderer.prototype, dp = RP.drawPlayer;
    RP.drawPlayer = function (g, pl) {
      if (!pl.crawling) return dp.call(this, g, pl);
      OP.drawCrawl(g, pl);
    };
  };
  // ---------------------------------------------------------------- the crawl sprite sheet
  // A prone, top-down figure in the same style as every other person in the game: chibi
  // proportions (the big round head), a clean one-pixel outline and the diagonal light on
  // the hair. Every colour is sampled from your own sprite, so it's your jacket, your
  // trousers, your hair. Four frames: left arm thrown ahead with the left knee drawn up,
  // pull, right arm ahead with the right knee up, pull.
  const crawlCache = new Map();
  const lum = (c) => c[0] * 0.3 + c[1] * 0.59 + c[2] * 0.11;
  OP.crawlPalette = function (look) {
    const spr = R.art.oldSprite(look, 6, 0, null), W = spr.width, H = spr.height, k = W / 16;
    const d = spr.getContext('2d').getImageData(0, 0, W, H).data;
    const region = (x0, y0, x1, y1) => { const m = new Map(); for (let y = y0 * k; y <= y1 * k; y++) for (let x = x0 * k; x <= x1 * k; x++) { const i = (y * W + x) * 4; if (d[i + 3] < 200) continue; const key = (d[i] << 16) | (d[i + 1] << 8) | d[i + 2]; m.set(key, (m.get(key) || 0) + 1); } return [...m].map(([v, n]) => ({ c: [v >> 16, (v >> 8) & 255, v & 255], n })); };
    const all = region(0, 0, 15, 31);
    const outline = all.reduce((a, b) => (lum(b.c) < lum(a.c) ? b : a)).c;
    const hex = (c) => '#' + c.map((v) => v.toString(16).padStart(2, '0')).join('');
    const ramp = (list) => {
      list = list.filter((e) => hex(e.c) !== hex(outline));
      if (!list.length) return ['#333', '#555', '#777'];
      const mid = list.reduce((a, b) => (b.n > a.n ? b : a)).c;
      const byL = list.slice().sort((a, b) => lum(a.c) - lum(b.c));
      const dark = byL[0].c, light = byL[byL.length - 1].c;
      return [hex(dark), hex(mid), hex(light)];
    };
    const notSkin = (list) => list.filter((e) => !(e.c[0] - e.c[2] > 40 && lum(e.c) > 90));
    const skinC = region(0, 18, 15, 22).filter((e) => e.c[0] - e.c[2] > 40 && lum(e.c) > 90);
    const legs = notSkin(region(3, 21, 12, 25)), shoe = legs.slice().sort((a, b) => lum(a.c) - lum(b.c)).find((e) => hex(e.c) !== hex(outline));
    return { O: hex(outline), hair: ramp(notSkin(region(2, 4, 13, 12))), coat: ramp(notSkin(region(1, 16, 14, 19))), pants: ramp(notSkin(region(3, 21, 12, 24))), shoe: shoe ? hex(shoe.c) : hex(outline), skin: skinC.length ? hex(skinC.reduce((a, b) => (b.n > a.n ? b : a)).c) : (look.skin || '#e0a070') };
  };
  OP.crawlSheet = function (look) {
    const base = R.art.oldSprite(look, 6, 0, null);
    const hit = crawlCache.get(base);
    if (hit) return hit;
    const P = this.crawlPalette(look);
    // same scale as the standing sprite: 12px head, 10px-wide shoulders, 5px legs, 2px arms
    const GW = 26, GH = 20, CY = 10; // grid, facing right, centre row
    const frames = [0, 1, 2, 3].map((f) => {
      const g = []; for (let y = 0; y < GH; y++) g.push(new Array(GW).fill(null));
      const put = (x, y, c) => { x = Math.round(x); y = Math.round(y + CY); if (x >= 0 && y >= 0 && x < GW && y < GH) g[y][x] = c; };
      const rect = (x0, y0, w, h, c) => { for (let y = y0; y < y0 + h; y++) for (let x = x0; x < x0 + w; x++) put(x, y, c); };
      const o = f === 1 || f === 3 ? 2 : 1; // x origin; the body slides a pixel on the pull
      // legs, 3px wide like the standing sprite's; one knee drawn up to push
      const leg = (side, bent) => {
        const y = side < 0 ? -4 : 1;
        if (!bent) { rect(o + 1, y, 4, 3, P.pants[1]); rect(o + 1, side < 0 ? y : y + 2, 4, 1, side < 0 ? P.pants[2] : P.pants[0]); rect(o, y, 1, 3, P.shoe); }
        else { const ky = side < 0 ? -6 : 4; rect(o + 3, y, 2, 3, P.pants[1]); rect(o + 1, ky, 3, 2, P.pants[1]); rect(o + 1, ky + (side < 0 ? 0 : 1), 3, 1, side < 0 ? P.pants[2] : P.pants[0]); rect(o, ky, 1, 2, P.shoe); }
      };
      const ST = [['reach', 'tuck'], ['pull', 'tuck'], ['tuck', 'reach'], ['tuck', 'pull']][f];
      leg(-1, f === 0); leg(1, f === 2);
      // back of the coat: 6 long, 10 across, lit along the top edge
      rect(o + 5, -5, 6, 10, P.coat[1]); rect(o + 5, -5, 6, 1, P.coat[2]); rect(o + 5, 4, 6, 1, P.coat[0]); rect(o + 10, -4, 1, 8, P.coat[0]);
      // arms: 2px sleeves, 2x2 hands, exactly like the standing frames
      const arm = (side, st) => {
        const y = side < 0 ? -7 : 5, hi = side < 0 ? P.coat[2] : P.coat[0];
        if (st === 'reach') { rect(o + 8, y, 8, 2, P.coat[1]); rect(o + 8, side < 0 ? y : y + 1, 8, 1, hi); rect(o + 16, y, 2, 2, P.skin); }
        else if (st === 'pull') { const ey = side < 0 ? y - 1 : y + 1; rect(o + 8, y, 3, 2, P.coat[1]); rect(o + 10, ey, 4, 2, P.coat[1]); rect(o + 10, side < 0 ? ey : ey + 1, 4, 1, hi); rect(o + 14, ey, 2, 2, P.skin); }
        else { rect(o + 5, y, 5, 2, P.coat[1]); rect(o + 5, side < 0 ? y : y + 1, 5, 1, hi); rect(o + 3, y, 2, 2, P.skin); }
      };
      arm(-1, ST[0]); arm(1, ST[1]);
      // neck, then the head: 12 across with its outline, lit like the standing sprite
      rect(o + 11, -1, 1, 2, P.skin);
      const hx = o + 16.5, R0 = 5.3;
      for (let y = -6; y <= 6; y++) for (let x = -6; x <= 6; x++) {
        if (x * x + y * y > R0 * R0) continue;
        const shadow = (x + 1.6) * (x + 1.6) + (y + 1.6) * (y + 1.6) > (R0 - 0.1) * (R0 - 0.1);
        const sheen = (x + 1) * (x + 1) * 0.4 + (y + 3.5) * (y + 3.5) < 1.6;
        put(hx + x, y, shadow ? P.hair[0] : sheen ? P.hair[2] : P.hair[1]);
      }
      // auto outline in the sprite's own outline colour
      const out = g.map((row) => row.slice());
      for (let y = 0; y < GH; y++) for (let x = 0; x < GW; x++) if (!g[y][x] && ((g[y - 1] && g[y - 1][x]) || (g[y + 1] && g[y + 1][x]) || g[y][x - 1] || g[y][x + 1])) out[y][x] = P.O;
      const c = document.createElement('canvas'); c.width = GW; c.height = GH;
      const cx = c.getContext('2d');
      for (let y = 0; y < GH; y++) for (let x = 0; x < GW; x++) if (out[y][x]) { cx.fillStyle = out[y][x]; cx.fillRect(x, y, 1, 1); }
      return c;
    });
    const sheet = { frames, w: GW, h: GH, cy: CY };
    if (crawlCache.size > 40) crawlCache.clear();
    crawlCache.set(base, sheet);
    return sheet;
  };
  // face down in the sand, dragging yourself toward the highway
  OP.drawCrawl = function (g, pl) {
    const G = R.game, t = G.clock.real, gore = G.settings.gore !== false;
    const moving = !!(pl.walk && Math.abs(pl.walk) > 0.01) || (!OP.scene && G.input.stick && Math.hypot(G.input.stick.x, G.input.stick.y) > 0.1);
    const f = moving ? Math.floor(t * 0.9 * 4) % 4 : 0; // in step with the pull in moveActor
    const sh = this.crawlSheet(pl.look);
    const dx = OP.dirX == null ? 1 : OP.dirX, dy = OP.dirY || 0;
    const vert = Math.abs(dy) > Math.abs(dx);
    g.save();
    g.translate(Math.round(pl.x), Math.round(pl.y));
    if (vert) g.rotate(dy < 0 ? -Math.PI / 2 : Math.PI / 2); else if (dx < 0) g.scale(-1, 1);
    // local space: head toward +x. Shadow, and the blood you're lying in
    g.fillStyle = 'rgba(0,0,0,0.2)'; g.fillRect(-11, -5, 22, 11);
    if (gore) { g.fillStyle = 'rgba(96,10,8,0.5)'; g.fillRect(-6, 5, 5, 2); g.fillRect(-5, 6, 3, 2); }
    g.drawImage(sh.frames[f], -12, -sh.cy);
    // the gut wound, soaking out from under you
    if (gore) { const p = 0.55 + Math.sin(t * 3) * 0.2; g.fillStyle = `rgba(130,12,8,${p})`; g.fillRect(-5, 3, 3, 2); g.fillStyle = 'rgba(70,4,4,0.85)'; g.fillRect(-4, 4, 1, 1); }
    g.restore();
  };
})();
