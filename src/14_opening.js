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
    const html = `${ui.header('Who are you?')}<div class="body"><p style="font-size:14px;color:var(--brown)">A name the papers will spell wrong for years.</p>
      ${[['first', 'First name'], ['last', 'Last name'], ['nick', 'They call you']].map(([k, l]) => `<label style="display:block;margin:8px 0 2px;font-size:13px">${l}</label><div style="display:flex;gap:6px"><input data-k="${k}" maxlength="18" value="${esc(vals[k])}" style="flex:1;font:inherit;font-size:18px;padding:6px 8px;border:3px solid var(--ink);background:#fffaf0;color:var(--ink)"><button class="chip c-talk" data-roll="${k}">🎲</button></div>`).join('')}
      <div class="opts" style="margin-top:14px"><button class="opt go" id="nameGo">That's me</button></div></div>`;
    const s = ui.openSheet('name', html, true);
    s.querySelectorAll('button').forEach((b) => { if (b.textContent.trim() === '✕' || b.getAttribute('aria-label') === 'Close') b.remove(); });
    const input = (k) => s.querySelector(`input[data-k="${k}"]`);
    s.querySelectorAll('[data-roll]').forEach((b) => b.addEventListener('click', () => { const k = b.dataset.roll; input(k).value = pick(k === 'first' ? FIRST : k === 'last' ? LAST : NICK); }));
    s.querySelector('#nameGo').addEventListener('click', () => {
      const v = (k) => (input(k).value || '').trim().slice(0, 18) || vals[k];
      pl.first = v('first'); pl.last = v('last'); pl.nick = v('nick');
      ui.closeSheet();
      done();
    });
  };

  // ---------------------------------------------------------------- 2. the desert
  OP.run = function (g) {
    const pl = g.player;
    pl.stats.startT = g.clock.t;
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
    const spot = road && w.findNear(road.x, road.y - 18, 0, 14, (x, y) => !w.solidPed(x, y) && !w.isWater(x, y) && !D.roadTile[w.t(x, y)] && !w.cityAt(x, y) && Math.hypot(x - road.x, y - road.y) > 12);
    if (!road || !spot) return this.wake(g); // no desert handy: skip to the back room
    this.road = road;
    g.clock.t = Math.floor(g.clock.t / 1440) * 1440 + 5 * 60 + 40; // dawn
    pl.place(spot.x * TS + 8, spot.y * TS + 8);
    g.cam.x = pl.x; g.cam.y = pl.y;
    pl.hp = 22; pl.crawling = true; pl.bloody = 1; pl.weaponOut = false;
    pl.cash = 0; pl.inv.weapons = { fists: 1 }; pl.weapon = 'fists';
    g.waypoint = { x: road.x * TS + 8, y: road.y * TS + 8 };
    g.ui.story(`${pl.first} "${pl.nick}" ${pl.last}`, 'A car trunk. A dirt road. Two men you never saw clearly, and two shots.\n\nThey drove off laughing and left you for the buzzards.\n\nYou\'re not dead. Not yet. There\'s a highway out there somewhere. Crawl.', () => g.ui.toast('Crawl to the highway. Follow the gold line.', 'warn'));
  };
  OP.update = function (dt) {
    const g = R.game, pl = g.player;
    if (!pl.crawling) return;
    pl.hp = Math.max(8, pl.hp); // you're too stubborn to die out here
    // a trail of blood behind you
    this.trail = (this.trail || 0) - dt;
    if (this.trail <= 0 && g.settings.gore !== false) { this.trail = 0.35; g.fx.decal({ x: pl.x + (Math.random() - 0.5) * 3, y: pl.y + 1, r: 1.2, c: 'rgba(110,20,16,0.55)', t: 700 }); }
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
    AP.moveActor = function (a, vx, vy, dt) { if (a && a.crawling) { vx *= 0.3; vy *= 0.3; } return mv.call(this, a, vx, vy, dt); };
    const RP = R.Renderer.prototype, dp = RP.drawPlayer;
    RP.drawPlayer = function (g, pl) {
      if (!pl.crawling) return dp.call(this, g, pl);
      // face down in the sand, dragging yourself along
      const t = R.game.clock.real, moving = pl.walk && Math.abs(pl.walk) > 0.01;
      R.art.drawPerson(g, pl.x - 8 + (moving ? Math.round(Math.sin(t * 6)) : 0), pl.y + 4, 2, 0, pl.look, { down: true });
    };
  };
})();
