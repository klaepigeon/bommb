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
  OP.nameSheet = function (g, done, title) {
    const pl = g.player, ui = g.ui, pick = (a) => a[(Math.random() * a.length) | 0];
    const vals = { first: pick(FIRST), last: pick(LAST), nick: pick(NICK) };
    const html = `${ui.header(title || 'Who are you?')}<div class="body"><p style="font-size:13px;color:var(--brown);margin:0 0 4px">A name the papers will spell wrong for years.</p>
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

  // ---------------------------------------------------------------- cinema: letterbox, captions, fades
  // Everything in the opening happens in the game world. These are the tools: black bars,
  // a caption in the lower bar, a fade, dialogue in the usual subtitle bar and speech
  // bubbles, and waits that run on game time (they freeze while a menu is open).
  OP.waits = [];
  OP.wait = function (s) { return new Promise((r) => this.waits.push({ t: s, r })); };
  OP.cineEl = function () {
    let el = document.getElementById('cine');
    if (el) return el;
    el = document.createElement('div'); el.id = 'cine';
    el.innerHTML = '<div class="cb t"></div><div class="cb b"><span class="cap"></span></div><div class="cf"></div>';
    const st = document.createElement('style');
    st.textContent = '#cine{position:fixed;pointer-events:none;z-index:40}#cine .cb{position:absolute;left:0;right:0;height:0;background:#000;transition:height .7s ease}#cine .t{top:0}#cine .b{bottom:0;display:flex;align-items:center;justify-content:center}#cine.on .cb{height:13%}#cine .cap{font:inherit;font-size:13px;letter-spacing:.14em;text-transform:uppercase;color:#f0e0b0;opacity:0;transition:opacity .6s;text-align:center;padding:0 12px}#cine .cap.show{opacity:1}#cine .cf{position:absolute;inset:0;background:#000;opacity:0;transition:opacity 1s}#cine .cf.black{opacity:1}body.cine #hudL,body.cine #hudR,body.cine #toasts,body.cine #wanted,body.cine #mapwrap,body.cine #menubtn,body.cine #padL,body.cine #padR,body.cine #ctx{visibility:hidden}';
    document.head.appendChild(st);
    document.body.appendChild(el);
    const fit = () => { const v = document.querySelector('#view canvas') || document.querySelector('#view') || document.querySelector('canvas'); if (!v) return; const r = v.getBoundingClientRect(); Object.assign(el.style, { left: r.left + 'px', top: r.top + 'px', width: r.width + 'px', height: r.height + 'px' }); };
    fit(); window.addEventListener('resize', fit); this.fit = fit;
    return el;
  };
  OP.cine = function (on) { const el = this.cineEl(); this.fit(); el.classList.toggle('on', !!on); document.body.classList.toggle('cine', !!on); this.cineOn = !!on; if (!on) this.caption(''); };
  OP.caption = function (text) { const c = this.cineEl().querySelector('.cap'); if (!text) { c.classList.remove('show'); return; } c.textContent = text; c.classList.add('show'); };
  OP.fade = function (black) { this.cineEl().querySelector('.cf').classList.toggle('black', !!black); return new Promise((r) => setTimeout(r, 1000)); };
  // a line of dialogue: a bubble if we can see them, the subtitle bar either way
  OP.say = function (who, text, name) {
    const g = R.game;
    if (who && !who.inCar && !who.hidden) g.actors.say(who, text, 2 + text.length * 0.05);
    else g.ui.subtitle(name || (who && g.actors.displayName(who)) || '', text);
    return this.wait(1.1 + text.length * 0.038);
  };
  // a choice in the dialogue sheet; closing it picks the first answer
  OP.ask = function (title, opts) {
    const g = R.game;
    return new Promise((res) => {
      let done = false;
      const pick = (i) => { if (done) return; done = true; this.asking = null; if (opts[i].fn) opts[i].fn(); res(i); };
      g.ui.choice(title, opts.map((o, i) => ({ label: o.label, small: o.small, cls: o.cls, fn: () => pick(i) })));
      this.asking = { t: 0, pick };
    });
  };

  // ---------------------------------------------------------------- roads
  OP.isRoad = function (x, y) { return !!D.roadTile[R.game.world.t(x, y)]; };
  // follow the road n tiles from (x,y) heading (dx,dy), turning where it bends
  OP.followRoad = function (x, y, dx, dy, n) {
    for (let i = 0; i < n; i++) {
      if (this.isRoad(x + dx, y + dy)) { x += dx; y += dy; continue; }
      const l = [dy, -dx], r = [-dy, dx];
      if (this.isRoad(x + l[0], y + l[1])) { [dx, dy] = l; x += dx; y += dy; continue; }
      if (this.isRoad(x + r[0], y + r[1])) { [dx, dy] = r; x += dx; y += dy; continue; }
      break;
    }
    return { x, y, dx, dy };
  };
  // a car that drives itself along the road: the intro doesn't trust the traffic AI with its actors
  OP.drive = function (car, tile, dx, dy, speed) { car.cine = { tx: tile.x, ty: tile.y, dx, dy, speed, want: speed }; car.parked = true; car.lights = true; car.speed = 0; };
  OP.stepCars = function (dt) {
    for (const v of R.game.traffic.list) {
      const c = v.cine;
      if (!c || v.removed) continue;
      c.speed += Math.sign(c.want - c.speed) * Math.min(Math.abs(c.want - c.speed), 90 * dt);
      if (c.speed < 0.5) { v.braking = c.want === 0; continue; }
      const nx = (c.tx + c.dx) * TS + 8, ny = (c.ty + c.dy) * TS + 8, d = Math.hypot(nx - v.x, ny - v.y), step = c.speed * dt;
      if (d <= step) { const n = this.followRoad(c.tx, c.ty, c.dx, c.dy, 1); if (n.x === c.tx && n.y === c.ty) { c.want = 0; c.speed = 0; continue; } c.tx = n.x - n.dx; c.ty = n.y - n.dy; c.tx += n.dx; c.ty += n.dy; c.dx = n.dx; c.dy = n.dy; v.x = nx; v.y = ny; }
      else { v.x += (nx - v.x) / d * step; v.y += (ny - v.y) / d * step; }
      const want = Math.atan2(c.dy, c.dx); let da = want - v.angle; while (da > Math.PI) da -= Math.PI * 2; while (da < -Math.PI) da += Math.PI * 2; v.angle += da * Math.min(1, dt * 6);
      v.vx = Math.cos(v.angle) * c.speed; v.vy = Math.sin(v.angle) * c.speed;
    }
  };

  // ---------------------------------------------------------------- 1. the ride
  OP.run = function (g) {
    const pl = g.player;
    this.active = true;
    pl.stats.startT = g.clock.t;
    for (const a of g.actors.list.slice()) if (a !== pl && !a.keep) g.actors.remove(a);
    if (pl.room) g.interiors.exit();
    const road = this.findRoad(g);
    if (!road) return this.nameSheet(g, () => this.wake(g)); // a world with no roads at all
    this.ride(g, road);
  };
  OP.findRoad = function (g) {
    const w = g.world, dust = w.cities.find((c) => c.id === 'dust') || w.cities[2];
    const T = D.T, desert = (x, y) => { let n = 0; for (let k = 0; k < 8; k++) { const t = w.t(x + ((k * 7) % 11) - 5, y + ((k * 5) % 9) - 4); if (t === T.DESERT || t === T.SAND || t === T.DIRT) n++; } return n >= 5; };
    // a straight stretch of highway, out of town, with sand either side
    const open = (x, y) => this.isRoad(x, y) && !w.cityAt(x, y) && !w.inCityRect(x, y, 10) && ((this.isRoad(x + 1, y) && this.isRoad(x - 1, y)) || (this.isRoad(x, y + 1) && this.isRoad(x, y - 1)));
    let road = null;
    for (let r = 14; r < 160 && !road; r += 6) for (let k = 0; k < 6 && !road; k++) road = w.findNear(dust.cx, dust.cy, r, r + 6, (x, y) => open(x, y) && desert(x, y));
    for (let r = 14; r < 160 && !road; r += 12) road = w.findNear(dust.cx, dust.cy, r, r + 12, open);
    for (let i = 0; i < 30000 && !road; i++) { const x = (Math.random() * w.W) | 0, y = (Math.random() * w.H) | 0; if (open(x, y)) road = { x, y }; }
    return road;
  };
  OP.ride = async function (g, road) {
    const pl = g.player, st = this.street(g);
    this.lock = { x: 0, y: 0 };
    g.clock.t = Math.floor(g.clock.t / 1440) * 1440 + 4 * 60 + 30; // the dead of night
    pl.cash = 0; pl.inv.weapons = { fists: 1 }; pl.weapon = 'fists'; pl.weaponOut = false; pl.hp = pl.maxHp;
    // which way the highway runs here, and a start a way back up it
    let dx = this.isRoad(road.x + 1, road.y) ? 1 : 0, dy = dx ? 0 : 1;
    // head out of town: whichever way along the highway leads further from the nearest city
    const w0 = g.world, far = (p) => Math.min(...w0.cities.map((c) => Math.hypot(c.cx - p.x, c.cy - p.y)));
    if (far(this.followRoad(road.x, road.y, -dx, -dy, 30)) > far(this.followRoad(road.x, road.y, dx, dy, 30))) { dx = -dx; dy = -dy; }
    const start = this.followRoad(road.x, road.y, -dx, -dy, 4);
    const car = g.traffic.make('sedan', start.x * TS + 8, start.y * TS + 8, Math.atan2(dy, dx), { parked: true, keep: true, color: '#1c1c20', locked: true });
    this.drive(car, start, dx, dy, 44);
    this.car = car;
    // two men from the Coast, real people you might meet again
    const pool = g.pop.people.filter((p) => p.alive && !p.fem && p.age >= 22 && p.age <= 52 && p.role !== 'cop' && p.role !== 'don' && !p.isDon && !p.actor && !p.faction);
    const men = [R.rng.pick(pool)]; men.push(R.rng.pick(pool.filter((p) => p !== men[0])));
    st.shooters = men.filter(Boolean).map((p) => p.id);
    const nameA = men[0] ? men[0].first : 'Driver', nameB = men[1] ? men[1].first : 'The other one';
    pl.hidden = true; this.riding = car;
    this.cine(true);
    this.cineEl().querySelector('.cf').classList.add('black');
    await this.wait(0.3);
    this.fade(false);
    this.caption('Dustwater flats · 4:30 a.m.');
    await this.wait(3);
    this.caption('');
    await this.say(null, 'Quiet back there.', nameA);
    await this.say(null, 'So. What do they call you, anyway?', nameB);
    await new Promise((res) => this.nameSheet(g, res, '"So. What do they call you?"'));
    await this.say(null, `${pl.first}. Huh.`, nameB);
    await this.say(null, 'Nobody\'s gonna remember that.', nameA);
    await this.wait(1.2);
    // out past the last lights, where nobody looks
    for (let i = 0; i < 300; i++) { const cx = (car.x / TS) | 0, cy = (car.y / TS) | 0; if (!g.world.cityAt(cx, cy) && !g.world.inCityRect(cx, cy, 8)) break; await this.wait(0.1); }
    await this.say(null, 'Right here\'s good.', nameA);
    car.cine.want = 0;
    await this.wait(1.6);
    // everybody out
    const stopT = { x: (car.x / TS) | 0, y: (car.y / TS) | 0 };
    this.road = stopT;
    const across = car.cine.dx ? [[0, 1], [0, -1]] : [[1, 0], [-1, 0]];
    const w = g.world, clear = (x, y) => !w.solidPed(x, y) && !w.isWater(x, y) && !this.isRoad(x, y) && !w.cityAt(x, y);
    let out = across.find(([ax, ay]) => { for (let k = 2; k <= 8; k++) if (!clear(stopT.x + ax * k, stopT.y + ay * k)) return false; return true; }) || across[0];
    const sx = car.x + out[0] * 16, sy = car.y + out[1] * 16;
    pl.hidden = false; this.riding = null;
    pl.place(sx, sy); g.cam.x = pl.x; g.cam.y = pl.y;
    const thugs = men.filter(Boolean).map((p, i) => {
      if (p.actor && !p.actor.dead) g.actors.remove(p.actor);
      const h = g.life.spawnPerson(p, car.x + (i ? 1 : -1) * 14 + out[0] * 10, car.y + (i ? 1 : -1) * 6 + out[1] * 10);
      if (!h) return null;
      h.keep = true; h.stay = true; h.state = 'idle'; h.timer = 1e9; h.hostile = false; h.scripted = true;
      g.actors.arm(h, i ? 'shotgun' : 'revolver');
      h.look.hatKind = 'fedora'; h.look.hatCol = '#2a2a2a';
      return h;
    }).filter(Boolean);
    this.scene = { t: 0, stage: 0, car, thugs, out, sx, sy };
    g.audio.sfx('bump');
    if (thugs[0]) await this.say(thugs[0], 'Out. Walk. Into the desert, nice and slow.');
    this.scene.stage = 1; this.scene.t = 0;
  };
  OP.street = function (g) { const pl = g.player; pl.street = pl.street || {}; return (pl.street.desert = pl.street.desert || {}); };

  // ---------------------------------------------------------------- 2. the walk, the shots
  OP.runScene = function (g, dt) {
    const sc = this.scene, pl = g.player, [a, b] = sc.thugs, [ox, oy] = sc.out;
    sc.t += dt;
    const follow = (h, bx, px, spd) => { if (!h || h.dead) return; const tx = pl.x - ox * bx + oy * px, ty = pl.y - oy * bx + ox * px, d = Math.hypot(tx - h.x, ty - h.y); if (d > 3) g.actors.moveActor(h, (tx - h.x) / d * spd, (ty - h.y) / d * spd, dt); h.state = 'idle'; h.timer = 1e9; };
    const face = (h) => { if (h) { h.ang = Math.atan2(pl.y - h.y, pl.x - h.x); h.dir = Math.abs(pl.y - h.y) > Math.abs(pl.x - h.x) ? (pl.y < h.y ? 3 : 0) : pl.x < h.x ? 2 : 1; } };
    if (sc.stage === 1) { // the walk out into the sand
      this.lock = { x: ox * 0.55, y: oy * 0.55 };
      follow(a, 20, -9, 38); follow(b, 22, 9, 38);
      if (Math.hypot(pl.x - sc.sx, pl.y - sc.sy) > TS * 6 || sc.t > 7) { sc.stage = 2; sc.t = 0; this.lock = { x: 0, y: 0 }; if (b) g.actors.say(b, 'That\'s far enough. Turn around.'); }
    }
    if (sc.stage === 2) {
      face(a); face(b);
      this.lock = sc.t > 0.35 && sc.t < 0.5 ? { x: -ox * 0.05, y: -oy * 0.05 } : { x: 0, y: 0 };
      if (sc.t > 1.5 && !sc.asked) { sc.asked = true; this.lastWords(g); }
    }
    if (sc.stage === 3) {
      face(a); face(b);
      if (a) { a.weaponOut = true; a.aiming = true; }
      if (sc.t > 0.2 && !sc.said) { sc.said = true; if (a) g.actors.say(a, sc.lunged ? 'Hold STILL, you son of a—' : 'Nothing personal, kid.'); }
      if (sc.t > 1.4 && !sc.shot1) { sc.shot1 = true; this.shoot(g, a, true); }
      if (sc.t > 2.0 && !sc.shot2) { sc.shot2 = true; this.shoot(g, a, !sc.lunged); pl.crawling = true; this.dirX = -ox; this.dirY = -oy; pl.hp = sc.lunged ? 30 : 22; }
      if (sc.t > 3.4) { sc.stage = 4; sc.t = 0; if (b) g.actors.say(b, 'Leave him for the buzzards. Come on.'); }
    }
    if (sc.stage === 4) { // they walk back and drive off
      for (const h of sc.thugs) { if (!h || h.removed) continue; const d = Math.hypot(sc.car.x - h.x, sc.car.y - h.y); if (sc.t > 1 && d > 10) g.actors.moveActor(h, (sc.car.x - h.x) / d * 45, (sc.car.y - h.y) / d * 45, dt); if (d <= 12 || sc.t > 7) { h.weaponOut = false; g.actors.remove(h); h.removed = true; } }
      if (sc.thugs.every((h) => !h || h.removed) && !sc.gone) { sc.gone = true; sc.car.cine.want = 80; g.audio.sfx('horn'); setTimeout(() => { if (!sc.car.removed) g.traffic.remove(sc.car); }, 6000); this.afterShots(g); }
    }
  };
  OP.lastWords = function (g) {
    const sc = this.scene, pl = g.player, [a, b] = sc.thugs, st = this.street(g);
    const say = (h, t) => h && g.actors.say(h, t);
    const go = () => { sc.stage = 3; sc.t = 0; };
    this.ask('"Any last words?"', [
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
  OP.afterShots = async function (g) {
    const pl = g.player;
    pl.crawling = true; pl.bloody = 1; pl.gutWound = true;
    await this.wait(2.5);
    this.caption('Two holes in you. One in the gut.');
    await this.wait(3);
    this.caption('They think you\'re dead.');
    await this.wait(2.6);
    this.caption('The highway. Crawl.');
    await this.wait(2.2);
    this.scene = null; this.lock = null;
    this.cine(false);
    const r = this.road;
    g.waypoint = { x: r.x * TS + 8, y: r.y * TS + 8 };
    g.ui.toast('Crawl back to the highway. Follow the gold line.', 'warn');
  };

  // ---------------------------------------------------------------- 3. crawling, and headlights
  OP.update = function (dt) {
    const g = R.game, pl = g.player;
    for (const wt of this.waits.slice()) { wt.t -= dt; if (wt.t <= 0) { this.waits.splice(this.waits.indexOf(wt), 1); wt.r(); } }
    if (this.asking) { this.asking.t += dt; if (this.asking.t > 0.6 && !g.ui.sheetOpen) this.asking.pick(0); }
    this.stepCars(dt);
    if (this.riding) { pl.x = this.riding.x; pl.y = this.riding.y; }
    if (this.scene) return this.runScene(g, dt);
    if (!pl.crawling) return;
    pl.hp = Math.max(8, pl.hp); // you're too stubborn to die out here
    // which way you're dragging yourself
    const dx = pl.x - (this.lastX == null ? pl.x : this.lastX), dy = pl.y - (this.lastY == null ? pl.y : this.lastY);
    this.lastX = pl.x; this.lastY = pl.y;
    if (!this.lock && (Math.abs(dx) > 0.02 || Math.abs(dy) > 0.02)) { this.dirX = dx; this.dirY = dy; }
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
    const tx = (pl.x / TS) | 0, ty = (pl.y / TS) | 0;
    if (!this.pickedUp && !this.lock && (this.isRoad(tx, ty) || (this.road && Math.hypot(pl.x / TS - this.road.x, pl.y / TS - this.road.y) < 1.6))) { this.pickedUp = true; this.pickup(g); }
  };
  OP.pickup = async function (g) {
    const pl = g.player;
    const fams = D.cities.map((c) => c.family);
    const fam = fams[(Math.random() * fams.length) | 0];
    const city = g.jobs.cityOfFamily(fam), club = city.buildings.find((b) => b && b.type === 'social');
    pl.family = fam; g.homeClub = club.id;
    g.waypoint = null;
    this.lock = { x: 0, y: 0 };
    this.cine(true);
    // headlights up the highway
    const tx = (pl.x / TS) | 0, ty = (pl.y / TS) | 0;
    const on = this.isRoad(tx, ty) ? { x: tx, y: ty } : this.road;
    const hdx = this.isRoad(on.x + 1, on.y) || this.isRoad(on.x - 1, on.y) ? 1 : 0, hdy = hdx ? 0 : 1;
    const from = this.followRoad(on.x, on.y, -hdx, -hdy, 14);
    const car = g.traffic.make('sedan', from.x * TS + 8, from.y * TS + 8, Math.atan2(-from.dy, -from.dx), { parked: true, keep: true, color: '#141418', locked: true });
    this.drive(car, from, -from.dx, -from.dy, 70);
    await this.wait(1.5);
    this.caption('Headlights.');
    // it slows when it reaches you
    for (let i = 0; i < 240; i++) { const c = car.cine, ahead = (pl.x - car.x) * c.dx + (pl.y - car.y) * c.dy; if (ahead < 26 || !c.want && c.speed < 1) break; if (ahead < 70) c.want = Math.max(18, ahead * 0.9); await this.wait(0.05); }
    car.cine.want = 0;
    this.caption('');
    await this.wait(1.4);
    g.audio.sfx('bump');
    const dp = R.campaign.donOf(fam);
    const drv = g.actors.makeHuman(car.x + 10, car.y - 10, { arch: 'tough', tag: 'driver', look: { fem: false, age: 40 } });
    drv.keep = true; drv.strangerName = 'Driver'; drv.look.hatKind = 'fedora'; drv.look.hatCol = '#1a1a1a'; drv.scripted = true;
    const walkTo = async (h, x, y, t) => { for (let k = 0; k < t * 20 && h && R.dist(h.x, h.y, x, y) > 12; k++) { const d = R.dist(h.x, h.y, x, y); g.actors.moveActor(h, (x - h.x) / d * 40, (y - h.y) / d * 40, 0.05); h.state = 'idle'; h.timer = 1e9; await this.wait(0.05); } };
    await walkTo(drv, pl.x + 14, pl.y - 4, 3);
    await this.say(drv, 'This one\'s still breathing, boss.');
    let don = null;
    if (dp && dp.alive) { if (dp.actor && !dp.actor.dead) g.actors.remove(dp.actor); don = g.life.spawnPerson(dp, car.x - 10, car.y - 10); if (don) { don.keep = true; don.scripted = true; don.state = 'idle'; don.timer = 1e9; } }
    if (don) { await walkTo(don, pl.x - 12, pl.y - 6, 4); await this.say(don, 'Well. Look at this.'); await this.say(don, 'Two in him and he\'s still going. That\'s a kind of talent.'); await this.say(don, 'Put him in the back. Careful with the upholstery.'); }
    await this.fade(true);
    for (const h of [drv, don]) if (h) g.actors.remove(h);
    g.traffic.remove(car);
    pl.crawling = false;
    this.wake(g, club, fam);
  };

  // ---------------------------------------------------------------- 4. the back room
  OP.wake = async function (g, club, fam) {
    const pl = g.player;
    fam = fam || pl.family; club = club || g.world.buildings[g.homeClub];
    const dn = g.jobs.donName(fam);
    this.lock = { x: 0, y: 0 };
    this.cine(true);
    this.cineEl().querySelector('.cf').classList.add('black');
    g.clock.skip(60 * 26);
    pl.hp = pl.maxHp; pl.bloody = 0; if (pl.wnd) { pl.wnd.bleed = 0; pl.wnd.marks = []; }
    pl.inv.weapons = { fists: 1, revolver: 1 }; pl.weapon = 'fists'; pl.cash = 60;
    pl.place(club.out.x * TS + 8, club.out.y * TS + 12);
    g.interiors.enter(club, 'guest');
    await this.wait(0.2);
    const dp = R.campaign.donOf(fam);
    let h = null;
    if (dp && dp.alive && pl.room) {
      if (dp.actor && !dp.actor.dead) g.actors.remove(dp.actor);
      h = g.life.spawnPerson(dp, pl.x + 20, pl.y - 6);
      if (h) { h.keep = true; h.stay = true; h.scripted = true; h.state = 'idle'; h.timer = 1e9; h.room = pl.room; h.dir = 3; h.ang = Math.PI; dp.met = true; dp.fam = Math.max(dp.fam || 0, 3); dp.opinion = Math.max(dp.opinion || 0, 20); }
    }
    this.fade(false);
    this.caption(`${club.name} · the next day`);
    await this.wait(3);
    this.caption('');
    const J = g.jobs, st = (d) => { J.standing[fam] = R.clamp((J.standing[fam] || 0) + d, -100, 100); };
    const me = (t) => { g.ui.subtitle(pl.first, t); return this.wait(1 + t.length * 0.04); };
    const don = (t) => this.say(h, t, 'Don ' + dn);
    await don('Stitches, a clean shirt, and you\'re still breathing. You\'re welcome.');
    await don('My driver found you on the side of my road with two holes in you. So. Who did you upset?');
    let i = await this.ask(`Don ${dn}`, [
      { label: '"I don\'t remember."', small: 'Keep it close' },
      { label: '"Somebody who\'s gonna regret it."', small: 'Infamy +', fn: () => { pl.rep.infamy += 3; } },
      { label: `"Thank you for stopping, Don ${dn}."`, small: 'Honor +, he likes manners', fn: () => { pl.rep.honor += 4; st(5); } },
    ]);
    await me(['I don\'t remember.', 'Somebody who\'s gonna regret it.', `Thank you for stopping, Don ${dn}.`][i]);
    await don(['Sure you don\'t.', 'I like that. Keep that.', 'Manners. Rare, these days.'][i]);
    await don('Doctors cost money. The shirt cost money. The silence of my driver, that cost the most.');
    i = await this.ask(`Don ${dn}`, [
      { label: '"I\'ll pay you back. Every cent."', small: 'Honor +, standing +', fn: () => { pl.rep.honor += 3; st(8); } },
      { label: '"What\'s it gonna cost me?"', small: 'Straight to business', fn: () => st(2) },
      { label: '"I didn\'t ask for your help."', small: 'Infamy +, standing −', fn: () => { pl.rep.infamy += 3; st(-8); } },
    ]);
    await me(['I\'ll pay you back. Every cent.', 'What\'s it gonna cost me?', 'I didn\'t ask for your help.'][i]);
    await don(['Yes. You will.', 'Straight to it. Good.', 'No. You were busy bleeding.'][i]);
    await don(`A man with nothing to lose is useful to me. You work for the ${fam} family now, or you walk out that door and take your chances.`);
    i = await this.ask(`Don ${dn}`, [
      { label: '"When do I start?"', small: 'Standing +', fn: () => st(10) },
      { label: '"I\'m my own man. But I\'ll hear you out."', small: 'Honor +, he respects it, barely', fn: () => { pl.rep.honor += 2; } },
      { label: '"What\'s the pay?"', small: '$100 up front, standing −', fn: () => { pl.addCash(100, true); st(-4); } },
    ]);
    await me(['When do I start?', 'I\'m my own man. But I\'ll hear you out.', 'What\'s the pay?'][i]);
    const offers = J.offersFor(fam);
    const first = offers.find((o) => o.kind === 'collect') || offers[0];
    if (first) { J.accept(first); J.offers[fam] = offers.filter((o) => o !== first); }
    await don('Good. Here\'s something small, to start.');
    await don('Somewhere out there are the men who left you in the desert. For now, you work for me.');
    this.lock = null;
    this.cine(false);
    if (h) h.scripted = false;
    this.active = false;
    g.ui.toast(`Talk to Don ${dn} for more work. Your first job is marked in gold. Walk out the doormat to leave.`, 'good');
    setTimeout(() => g.ui.toast('Crimes only count if someone sees them. Watch for gold "!" witnesses.'), 7000);
    g.save();
  };

  // ---------------------------------------------------------------- crawling
  OP.init = function (g) {
    this.pickedUp = false; this.road = null; this.active = false; this.waits = []; this.scene = null; this.lock = null; this.riding = null; this.asking = null; this.car = null;
    if (document.getElementById('cine')) { this.cine(false); this.cineEl().querySelector('.cf').classList.remove('black'); }
    if (g.player) g.player.hidden = false;
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
    const U0 = R.UI.prototype;
    // while a scene has the controls, the script decides what hurts you
    const PP = R.Player.prototype, ph = PP.hurt, pk = PP.knock;
    PP.hurt = function () { if (OP.lock || OP.riding || OP.active) return; return ph.apply(this, arguments); };
    if (pk) PP.knock = function () { if (OP.lock || OP.riding || OP.active) return; return pk.apply(this, arguments); };
    // 4:30 in the morning on a desert highway: no traffic but the cars in the story
    const TP = R.Traffic.prototype, man = TP.manage;
    TP.manage = function () { if (OP.active) { for (const v of this.list) if (!v.keep && !v.cine && v.driver !== this.game.player) this.remove(v); return; } return man.call(this); };
    // extras keep quiet during a scene; only the cast speaks
    const AP2 = R.Actors.prototype, asay = AP2.say;
    AP2.say = function (h, text, dur, color) { if ((OP.lock || OP.cineOn) && h && !h.scripted) return; return asay.call(this, h, text, dur, color); };
    const dh = U0.drawHud; if (dh) U0.drawHud = function () { if (OP.cineOn) return; return dh.apply(this, arguments); };
    const ban = U0.banner; U0.banner = function () { if (OP.cineOn) return; return ban.apply(this, arguments); };
    const GP = R.Game.prototype, hc = GP.hintCheck; if (hc) GP.hintCheck = function () { if (OP.cineOn || OP.lock) return; return hc.apply(this, arguments); };
    // nobody makes small talk with the men who are about to shoot you
    const U = R.UI.prototype, uc = U.updateCtx;
    U.updateCtx = function () { if (OP.lock || OP.cineOn) this.game.player.focus = null; return uc.call(this); };
    const RP = R.Renderer.prototype, dp = RP.drawPlayer;
    RP.drawPlayer = function (g, pl) {
      if (pl.hidden) return;
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
      rect(o + 11, -1, 2, 2, P.skin);
      // the head is wider than the shoulders, like every standing sprite: 12 long, 14 across
      const hx = o + 17.5, RX = 5.6, RY = 6.6;
      for (let y = -7; y <= 7; y++) for (let x = -7; x <= 7; x++) {
        if ((x * x) / (RX * RX) + (y * y) / (RY * RY) > 1) continue;
        const shadow = ((x + 1.4) * (x + 1.4)) / (RX * RX) + ((y + 1.6) * (y + 1.6)) / (RY * RY) > 0.98;
        const sheen = (x + 1) * (x + 1) * 0.4 + (y + 4.2) * (y + 4.2) < 1.8;
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
