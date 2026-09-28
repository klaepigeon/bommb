// RHAPSODY — after dark. A costume shop in every city with a wall of masks (each one
// changes your face, not just hides it). Bars and clubs that fill up, with folks dropping
// in on a whim when they pass an open door. A strip club in every city, dancers of every
// kind. Working girls and boys under the motel signs, and one in eight of them is a cop.
// And the calendar: it's always the Seventies here, the year is XX7X.
'use strict';
(function () {
  const D = R.data, TS = R.TILE;
  const G = () => R.game;
  const NT = (R.night = { workers: [] });
  const DIR8 = ['right', 'downright', 'down', 'downright', 'right', 'upright', 'up', 'upright'];
  const FLIP8 = [false, false, false, true, true, true, false, false];

  // ---------------------------------------------------------------- the calendar
  const MONTHS = [['JAN', 31], ['FEB', 28], ['MAR', 31], ['APR', 30], ['MAY', 31], ['JUN', 30], ['JUL', 31], ['AUG', 31], ['SEP', 30], ['OCT', 31], ['NOV', 30], ['DEC', 31]];
  R.calendar = function (day, long) {
    let d = (day + 151) % 365, m = 0; // the story starts on the first of June
    while (d >= MONTHS[m][1]) { d -= MONTHS[m][1]; m++; }
    const mon = MONTHS[m][0];
    return long ? `${mon.charAt(0)}${mon.slice(1).toLowerCase()} ${d + 1}, XX7X` : `${mon} ${d + 1} XX7X`;
  };

  // ---------------------------------------------------------------- masks
  const ramp = (a, b, c, d) => [a, b, c, d];
  const MASKS = (NT.MASKS = {
    ski: { name: 'Ski Mask', price: 10, col: ramp('#141418', '#24242e', '#383846', '#50505e') },
    stocking: { name: 'Nylon Stocking', price: 5, col: ramp('#7a5a44', '#9a7a60', '#b8987c', '#d4b496') },
    hockey: { name: 'Goalie Mask', price: 40, col: ramp('#a8a498', '#cfcbc0', '#e8e4da', '#fbf8f0'), feat: 'hockey' },
    clown: { name: 'Clown Mask', price: 35, col: ramp('#c8c0b8', '#e4dcd4', '#f2eee8', '#ffffff'), feat: 'clown' },
    skull: { name: 'Skull Mask', price: 30, col: ramp('#9a9282', '#c8c0ac', '#e2dac6', '#f6f2e6'), feat: 'skull' },
    lucha: { name: 'Luchador Mask', price: 45, col: ramp('#5a0a14', '#94141e', '#c8262a', '#f05248'), feat: 'lucha' },
    pig: { name: 'Rubber Pig', price: 25, col: ramp('#a85a6a', '#cc7a8a', '#e89aa8', '#fcc0c8'), feat: 'pig' },
    gorilla: { name: 'Gorilla Mask', price: 50, col: ramp('#100c0c', '#1e1814', '#302620', '#44362c'), feat: 'gorilla' },
    devil: { name: 'Devil Mask', price: 30, col: ramp('#4a0606', '#7a0e0e', '#a81c1c', '#d83a34'), feat: 'devil' },
    pumpkin: { name: 'Jack-o\'-Lantern', price: 20, col: ramp('#7a3206', '#b0520e', '#d8721c', '#fa9a3a'), feat: 'pumpkin' },
    bunny: { name: 'Easter Bunny', price: 35, col: ramp('#aca49c', '#d0c8c0', '#e8e2da', '#fcfaf6'), feat: 'bunny' },
    prez: { name: 'Rubber "Mr. President"', price: 60, col: ramp('#8a5a44', '#b07a5c', '#d09a7a', '#ecbc9a'), feat: 'prez' },
  });
  const FEAT = {
    // [dx, dy, w, h, colour] in front-facing head cells, dx from the face centre
    clown: [[-0.5, 11, 2, 2, '#e02020'], [-2, 13, 4, 1, '#c01818'], [-3.5, 11, 1, 1, '#3a6ae0'], [2.5, 11, 1, 1, '#3a6ae0'], [-4, 5, 8, 1, '#e8601c']],
    skull: [[-4, 9, 2, 2, '#141010'], [2, 9, 2, 2, '#141010'], [-0.5, 11, 1, 1, '#141010'], [-2, 13, 1, 1, '#3a342c'], [0, 13, 1, 1, '#3a342c'], [2, 13, 1, 1, '#3a342c']],
    hockey: [[-4, 8, 2, 1, '#c01818'], [2, 8, 2, 1, '#c01818'], [-2, 12, 1, 1, '#3a3a3a'], [0, 12, 1, 1, '#3a3a3a'], [2, 12, 1, 1, '#3a3a3a'], [-1, 13, 1, 1, '#3a3a3a'], [1, 13, 1, 1, '#3a3a3a']],
    lucha: [[-4, 9, 3, 1, '#f0c030'], [1, 9, 3, 1, '#f0c030'], [-2, 12, 4, 1, '#f0c030'], [-0.5, 5, 1, 3, '#f0c030']],
    pig: [[-2, 11, 4, 2, '#f4b0bc'], [-1, 12, 1, 1, '#6a2a34'], [1, 12, 1, 1, '#6a2a34'], [-5, 4, 2, 2, '#cc7a8a'], [3, 4, 2, 2, '#cc7a8a']],
    gorilla: [[-4, 8, 8, 1, '#0a0808'], [-2, 11, 4, 3, '#5a463a'], [-1, 12, 1, 1, '#140e0c'], [1, 12, 1, 1, '#140e0c']],
    devil: [[-5, 1, 2, 3, '#2a0404'], [3, 1, 2, 3, '#2a0404'], [-3, 12, 6, 1, '#2a0404'], [-4, 9, 2, 1, '#f0d040'], [2, 9, 2, 1, '#f0d040']],
    pumpkin: [[-4, 9, 2, 2, '#140a04'], [2, 9, 2, 2, '#140a04'], [-3, 12, 1, 1, '#140a04'], [-1, 12, 3, 1, '#140a04'], [2, 12, 1, 1, '#140a04'], [-0.5, 2, 2, 2, '#3a6a20']],
    bunny: [[-4, -3, 2, 7, '#f4f0ea'], [2, -3, 2, 7, '#f4f0ea'], [-3.5, -2, 1, 5, '#f0a0b0'], [2.5, -2, 1, 5, '#f0a0b0'], [-0.5, 11, 1, 1, '#f080a0']],
    prez: [[-5, 4, 10, 2, '#b8b4ac'], [-3, 12, 6, 1, '#5a1a14'], [-2, 12, 4, 1, '#f0ece0'], [-4, 8, 2, 1, '#3a2a20'], [2, 8, 2, 1, '#3a2a20']],
  };
  const ALWAYS = { devil: [0, 1], bunny: [0, 1, 2, 3], pig: [3, 4] }; // horns and ears show from any angle
  NT.drawMaskFeat = function (g, X, Y, look, st) {
    const f = FEAT[look.maskKind];
    if (!f) return;
    const d8 = R.art.dir8(st.dir != null ? st.dir : 2, st.ang), n = DIR8[d8], flip = FLIP8[d8];
    const front = n === 'down' || n === 'downright', cx = n === 'down' ? 7.5 : n === 'downright' ? 9.5 : n === 'right' ? 10.5 : 7.5;
    const kid = look.kid ? 2 : 0;
    f.forEach((p, i) => {
      if (!front && !(ALWAYS[look.maskKind] || []).includes(i)) return;
      const sx = cx + p[0] * (n === 'right' ? 0.6 : n === 'downright' ? 0.85 : 1);
      const x = flip ? 15 - sx - p[2] + 1 : sx;
      g.fillStyle = p[4];
      g.fillRect(Math.round(X - 8 + x), Math.round(Y - 25 + p[1] + kid), p[2], p[3]);
    });
  };

  // ---------------------------------------------------------------- shops
  NT.buyMask = function (k, price) {
    const g = G(), pl = g.player, m = MASKS[k];
    if (!(pl.inv.masks || {})[k]) { if (!pl.pay(price)) return g.ui.toast('Can\'t afford it.', 'warn'); (pl.inv.masks = pl.inv.masks || {})[k] = 1; g.audio.sfx('cash'); }
    pl.inv.tools.mask = 1;
    pl.style.maskKind = k;
    pl.buildLook();
    g.ui.toast(`${m.name}${pl.masked ? ' on.' : '. Press MASK to put it on.'}`, 'good');
  };
  NT.maskOpts = function (list, opts) {
    const pl = G().player;
    for (const k of list) {
      const m = MASKS[k], own = (pl.inv.masks || {})[k] || (k === 'ski' && pl.inv.tools.mask);
      opts.push({ label: own ? `${m.name}${pl.style.maskKind === k ? ' (wearing)' : ' (wear)'}` : m.name, price: own ? '' : R.fmtMoney(m.price), small: own ? 'Yours' : 'Rubber, latex, or worse', icon: 'mask', fn: () => this.buyMask(k, own ? 0 : m.price) });
    }
  };
  NT.stripOpts = function (b, opts) {
    const g = G(), pl = g.player, ui = g.ui;
    const dancers = g.actors.list.filter((a) => a.room === pl.room && a.dancer && !a.dead);
    opts.unshift({ label: 'Tip the dancers', price: '$5', small: 'Folded twice, tucked in', fn: () => { if (!pl.pay(5)) return; pl.cool = Math.min(100, pl.cool + 15); const d = R.rng.pick(dancers); if (d) g.actors.say(d, R.rng.pick(['Thanks, sugar.', 'Big spender!', 'Come back anytime, handsome.', 'Mm, don\'t be a stranger.'])); g.audio.sfx('cash'); } });
    opts.splice(1, 0, { label: 'A private dance', price: '$40', small: 'Three songs behind the velvet curtain', fn: () => { if (!pl.pay(40)) return ui.toast('Forty, cash.', 'warn'); g.clock.skip(20); pl.cool = 100; ui.closeSheet(); ui.story('Behind the curtain', `${R.rng.pick(['A disco ball, a velvet chair, and three songs that feel like one.', 'Donna Summer on the speakers and a strict hands-off policy, mostly observed.'])}\n\nYou walk out lighter in the wallet and cooler in the head.\n\n(Full Cool)`); } });
    opts.splice(2, 0, { label: 'Buy the house a round', price: '$30', small: 'Everybody here likes you a little more', fn: () => { if (!pl.pay(30)) return; for (const a of g.actors.list) if (a.room === pl.room && a.person) a.person.opinion = Math.min(100, a.person.opinion + 4); pl.rep.honor = Math.min(100, pl.rep.honor + 0.5); ui.toast('A cheer goes up. Somebody starts a conga line.', 'good'); } });
    opts.splice(3, 0, { label: 'Ask the manager what\'s going on', price: '$20', small: 'He sees everybody, eventually', fn: () => { if (!pl.pay(20)) return; const lead = g.jobs.makeLead({ x: pl.x, y: pl.y }); ui.toast(lead ? `"${lead}"` : '"Quiet week. Too quiet."'); } });
  };

  // ---------------------------------------------------------------- the stroll
  const NAMES_F = ['Candy', 'Roxy', 'Destiny', 'Ginger', 'Velvet', 'Cherry', 'Starla', 'Honey'];
  const NAMES_M = ['Rico', 'Dante', 'Lance', 'Stallion', 'Johnny Gold', 'Sonny', 'Blaze', 'Cash'];
  NT.spawnWorker = function (b) {
    const g = G();
    const s = g.world.findNear(b.out.x, b.out.y + 1, 1, 5, (x, y) => !g.world.solidPed(x, y) && !g.world.isWater(x, y));
    if (!s) return null;
    const fem = R.rng() < 0.5;
    const h = g.actors.makeHuman(s.x * TS + 8, s.y * TS + 8, { arch: 'flirt', tag: 'worker', cash: R.rng.int(20, 80), look: { fem, age: 26, skin: R.rng.pick(['#f0c8a0', '#c89070', '#8a5a3a', '#5a3a24']), hair: R.rng.pick(['#e8c860', '#1a1010', '#8a3a1a', '#d84a8a']), top: '#c02080', bottom: '#1a1a1a', seedStr: 'worker' + R.rng.int(0, 1e6), oldOverride: fem ? { style: R.rng.pick(['long', 'afro', 'bob', 'shag']), dress: true, shirt: R.rng.pick([ramp('#6a0a4a', '#a0186a', '#d830a0', '#ff70c8'), ramp('#6a4a0a', '#a07818', '#d8a830', '#ffe070'), ramp('#0a3a6a', '#185a9a', '#3a8ad8', '#80c0ff')]) } : { style: R.rng.pick(['shag', 'afro', 'long']), top: 'collar', shirt: ramp('#6a4a0a', '#a07818', '#d8a830', '#ffe070'), jacket: ramp('#1a0a2a', '#2a1440', '#402060', '#60308a'), pants: ramp('#e8e0d0', '#f0e8dc', '#f8f4ec', '#ffffff'), stache: true } } });
    h.keep = true; h.stay = true; h.state = 'idle'; h.timer = 1e9; h.worker = true;
    h.strangerName = R.rng.pick(fem ? NAMES_F : NAMES_M);
    h.sting = R.rng() < 0.12;
    this.workers.push(h);
    return h;
  };
  NT.workerTree = function (h) {
    const g = G(), pl = g.player, ui = g.ui, say = (t) => ui.talkLine(t), close = () => ui.closeSheet(), V = R.vice;
    setTimeout(() => say(R.rng.pick(['Looking for company, sugar?', 'Hey there, big spender.', 'You look like you could use a little fun.'])), 0);
    const car = g.traffic.list.find((v) => !v.removed && !v.wrecked && (v.owner === 'player' || v.stolen) && R.dist(v.x, v.y, pl.x, pl.y) < TS * 5);
    const motel = g.world.buildings.find((b) => b && !b.destroyed && (b.type === 'motel' || b.type === 'hotel') && R.dist(b.out.x * TS, b.out.y * TS, pl.x, pl.y) < TS * 18);
    const where = car ? 'your car' : V && V.hasPlace() ? 'your place' : motel ? `a room at ${motel.name}` : null;
    const price = 60 + (motel && !car && !(V && V.hasPlace()) ? 15 : 0);
    const opts = [
      { label: '"How much?"', fn: () => say(`"Sixty for an hour, sugar. More if you want the whole night."`) },
      { label: `"Let's go somewhere."`, small: where ? `${where} · $${price}` : 'You need a car, a room, or a motel nearby', price: where ? R.fmtMoney(price) : '', fn: () => {
        if (!where) return say('"Where, the sidewalk? Get a car, honey."');
        if (h.sting) { close(); h.cop = true; h.hostile = false; g.actors.say(h, 'Vice squad. You\'re under arrest for solicitation.'); g.law.startIncident({ type: 'solicit', def: g.law.CRIMES.solicit, x: pl.x, y: pl.y, jur: g.law.jurAt(pl.x, pl.y), identified: true, lvl: 1, bounty: 25, t: g.clock.t }, h); ui.toast('An undercover sting. Of course it was.', 'bad'); return; }
        if (!pl.pay(price)) return say('"Cash first, handsome. I\'m not a charity."');
        close();
        g.clock.skip(60);
        pl.cool = 100; pl.hp = Math.min(pl.maxHp, pl.hp + 25);
        ui.story('An hour later...', `${where === 'your car' ? 'The windows fog up. The radio plays something by the Bee Gees.' : 'A buzzing neon sign, a creaky bed, and a Gideon Bible nobody opens.'}\n\nThe rest is between you and ${h.strangerName}.\n\n(Full Cool)`);
        // somebody at home may hear about it
        const s = V && V.state(), sweet = pl.sweetheart != null && s && s.love[pl.sweetheart];
        if (sweet && R.rng() < 0.3) setTimeout(() => { sweet.love = Math.max(0, sweet.love - 20); g.ui.toast(`Word got back to ${g.pop.people[pl.sweetheart].first}. They're not answering the phone. (♥ −20)`, 'bad'); }, 4000);
        h.stay = false; h.keep = false; h.state = 'idle'; h.timer = 1;
      } },
      { label: '"Heard anything interesting?"', price: '$10', small: 'Working people hear everything', fn: () => { if (!pl.pay(10)) return; const lead = g.jobs.makeLead({ x: pl.x, y: pl.y }); say(lead ? `"${lead}"` : '"Only that the vice squad\'s been sniffing around. Careful, sugar."'); } },
      { label: 'Goodbye', fn: close },
    ];
    return { title: h.strangerName, sub: 'Working the corner', options: opts };
  };

  // ---------------------------------------------------------------- the whole night
  NT.update = function (dt) {
    const g = G(), pl = g.player;
    this.workers = this.workers.filter((h) => !h.dead && !h.removed && (R.dist(h.x, h.y, pl.x, pl.y) < TS * 45 || (g.actors.remove(h), false)));
    this.t = (this.t == null ? 3 : this.t) - dt;
    if (this.t > 0 || pl.room) return;
    this.t = 6;
    const hr = g.clock.hour(), night = hr >= 21 || hr < 4;
    const c = g.world.cityAt((pl.x / TS) | 0, (pl.y / TS) | 0);
    // workers under the neon
    if (c && night && this.workers.length < 2) {
      const spots = c.buildings.filter((b) => b && !b.destroyed && ['motel', 'strip', 'bar', 'hotel'].includes(b.type) && R.dist(b.out.x * TS, b.out.y * TS, pl.x, pl.y) < TS * 26 && R.dist(b.out.x * TS, b.out.y * TS, pl.x, pl.y) > TS * 8);
      if (spots.length && R.rng() < 0.5) this.spawnWorker(R.rng.pick(spots));
    }
    if (!night) for (const h of this.workers) { h.keep = false; h.stay = false; }
    // passers-by drop into an open bar on a whim
    if (c) {
      const bars = c.buildings.filter((b) => b && !b.destroyed && ['bar', 'club', 'strip', 'casino'].includes(b.type) && g.ui.isOpen(b) && R.dist(b.out.x * TS, b.out.y * TS, pl.x, pl.y) < TS * 24);
      if (bars.length) for (const a of g.actors.near(pl.x, pl.y, TS * 22, (q) => q.kind === 'h' && !q.dead && q.tag === 'ambient' && !q.look.kid && q.state !== 'travel' && q.state !== 'fight' && !q.goal && (!q.person || q.person.age >= 21))) {
        if (R.rng() > (hr >= 18 || hr < 2 ? 0.08 : 0.025)) continue;
        const b = bars.reduce((best, x) => (R.dist(x.out.x * TS, x.out.y * TS, a.x, a.y) < R.dist(best.out.x * TS, best.out.y * TS, a.x, a.y) ? x : best), bars[0]);
        if (R.dist(b.out.x * TS, b.out.y * TS, a.x, a.y) > TS * 14) continue;
        a.state = 'travel'; g.actors.goTo(a, b.out.x, b.out.y, { enter: true, placeKey: 'b:' + b.id });
        if (R.rng() < 0.3) g.actors.say(a, R.rng.pick(['One drink. Just one.', 'I could use a cold one.', 'Why not? It\'s Friday somewhere.', 'Hell of a day. Bartender better be working.']));
      }
    }
  };

  NT.init = function (g) {
    this.workers = []; this.t = 3;
    if (this.wrapped) return;
    this.wrapped = true;
    const LP = R.Law.prototype;
    if (!LP.CRIMES.solicit) LP.CRIMES.solicit = { name: 'Solicitation', bounty: 25, lvl: 1, minor: true };
    // masks: colours through the sprite painter, details painted on top
    const lfs = R.lookFromStyle;
    R.lookFromStyle = function (s, masked) {
      const l = lfs.call(this, s, masked);
      if (masked) { const k = s.maskKind || 'ski', m = MASKS[k] || MASKS.ski; l.maskKind = k; l.oldOverride = Object.assign({}, l.oldOverride || {}, { maskCol: m.col }); l.seedStr += '-mask-' + k; }
      return l;
    };
    const A = R.art, draw = A.drawPerson;
    A.drawPerson = function (g, x, y, dir, walk, look, st) {
      const r = draw.call(this, g, x, y, dir, walk, look, st);
      if (look && look.mask && look.maskKind && !(st && (st.down || st.scale || st.crouch))) NT.drawMaskFeat(g, Math.round(x), Math.round(y) - (walk && Math.abs(walk) > 0.01 && (Math.floor(walk * 0.5) % 4) % 2 ? 1 : 0), look, Object.assign({ dir }, st || {}));
      return r;
    };
    // shops and rooms
    const U = R.UI.prototype, io = U.interiorOptions;
    U.interiorOptions = function (b) {
      const o = io.call(this, b);
      if (b.type === 'costume') NT.maskOpts(Object.keys(MASKS), o);
      if (b.type === 'pawn') NT.maskOpts(['ski', 'stocking', 'hockey'], o);
      if (b.type === 'strip') NT.stripOpts(b, o);
      return o;
    };
    // dancers on the runway, both kinds
    const IP = R.Interiors.prototype, pop = IP.populate;
    IP.populate = function (room) {
      const r = pop.call(this, room);
      if (room.b.type === 'strip' && room.mode !== 'breakin' && G().ui.isOpen(room.b)) {
        const spots = room.extra.slice(0, 2);
        for (const s of spots) {
          const fem = R.rng() < 0.6;
          const h = this.spawnAt(room, null, s, { stay: true, arch: 'flirt', city: room.b.cityId });
          if (!h) continue;
          h.look.fem = fem; h.look.dress = fem; h.look.old = null; h.look.oldOverride = Object.assign({}, h.look.oldOverride || {}, fem ? { dress: true, shirt: ramp('#6a0a4a', '#a0186a', '#d830a0', '#ff70c8') } : { top: 'turtle', shirt: ramp('#6a4a0a', '#a07818', '#d8a830', '#ffe070'), pants: ramp('#141414', '#242424', '#3a3a3a', '#505050'), jacket: null });
          h.state = 'perform'; h.timer = 1e9; h.dancer = true; h.role = 'dancer'; h.strangerName = R.rng.pick(fem ? NAMES_F : NAMES_M);
        }
      }
      return r;
    };
    const tree = R.dialog.tree;
    R.dialog.tree = function (h) { return h.worker && !h.cop ? NT.workerTree(h) : tree.call(this, h); };
  };
})();
