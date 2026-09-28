// RHAPSODY — more ways to lose an evening. Pinball in the arcade and the back of every
// bar, arm wrestling for a stake, a dance-off under the disco ball, three-card monte on
// the sidewalk, bare-knuckle bouts in a back room, five-card draw, and drag racing on an
// empty boulevard at 2 AM. Same framework and pixel style as the first set.
'use strict';
(function () {
  const INK = '#1b1410', PAPER = '#f6ecd0', GOLD = '#f0b838', RED = '#c83a2a', GREEN = '#3a8a4a', FELT = '#1f5a3a', BLUE = '#3a6aa8', PINK = '#e04890';
  const M = R.mini;
  const G = () => R.game;
  const txt = (g, s, x, y, o) => R.art.ptext(g, s, x, y, Object.assign({ color: PAPER, shadow: INK }, o || {}));
  const box = (g, x, y, w, h, fill, edge) => { g.fillStyle = edge || INK; g.fillRect(x - 1, y - 1, w + 2, h + 2); g.fillStyle = fill; g.fillRect(x, y, w, h); };
  // tiny pixel suits and arrows (the pixel font has no glyphs for them)
  const SUITPX = [
    ['..#..', '.###.', '#####', '..#..', '.###.'], // spade
    ['.#.#.', '#####', '#####', '.###.', '..#..'], // heart
    ['..#..', '.###.', '#####', '.###.', '..#..'], // diamond
    ['.###.', '..#..', '#####', '..#..', '.###.'], // club
  ];
  const suit = (g, si, x, y, col, k) => { k = k || 1; g.fillStyle = col; SUITPX[si].forEach((row, yy) => [...row].forEach((c, xx) => { if (c === '#') g.fillRect(x + xx * k, y + yy * k, k, k); })); };
  const arrow = (g, dir, x, y, col) => { g.fillStyle = col; for (let i = 0; i < 5; i++) { const w = i * 2 + 1; if (dir === 0) g.fillRect(x + i, y + 4 - i, 1, w); else if (dir === 3) g.fillRect(x + 4 - i, y + 4 - i, 1, w); else if (dir === 2) g.fillRect(x + 4 - i, y + i, w, 1); else g.fillRect(x + 4 - i, y + 4 - i + 4 - i + i, w, 1); } };
  const clean = (fn) => (R.money ? R.money.clean(fn) : fn());
  const stakeOf = (opts, d) => opts.stake || d;
  const ante = (stake, what) => { const g = G(); if (!g.player.pay(stake)) { g.ui.toast(`${what} is ${R.fmtMoney(stake)}.`, 'warn'); return false; } return true; };

  // ---------------------------------------------------------------- pinball
  // Two flippers, three bumpers, a drain. Keep it alive; 20,000 wins a free game and bragging rights.
  M.pinball = function (opts, done) {
    const g0 = G(), pl = g0.player, cost = opts.stake || 1;
    if (!ante(cost, 'A game')) return done && done(0);
    const W = 160, H = 200, BUMP = [[50, 60, 9], [110, 60, 9], [80, 95, 10]];
    return M.open({
      title: 'Pinball: "Disco Inferno"', sub: `${R.fmtMoney(cost)} a ball, three balls. Hold LEFT and RIGHT to flip. 20,000 wins a free game.`, w: W, h: H,
      buttons: [['l', '◀ LEFT', 'big'], ['r', 'RIGHT ▶', 'big'], ['quit', 'WALK AWAY']],
      init(s) { s.balls = 3; s.score = 0; s.L = 0; s.Rt = 0; this.serve(s); },
      serve(s) { s.bx = 148; s.by = 170; s.vx = -20 - Math.random() * 30; s.vy = -260; s.live = true; },
      press(s, id) { if (id === 'quit') return s.finish(s.score, 0); if (id === 'l') s.L = 1; if (id === 'r') s.Rt = 1; },
      release(s, id) { if (id === 'l') s.L = 0; if (id === 'r') s.Rt = 0; },
      update(s, dt) {
        if (!s.live) return;
        for (let k = 0; k < 4; k++) {
          const d = dt / 4;
          s.vy += 220 * d; s.bx += s.vx * d; s.by += s.vy * d;
          if (s.bx < 6) { s.bx = 6; s.vx = Math.abs(s.vx) * 0.9; } if (s.bx > W - 6) { s.bx = W - 6; s.vx = -Math.abs(s.vx) * 0.9; }
          if (s.by < 6) { s.by = 6; s.vy = Math.abs(s.vy) * 0.9; }
          for (const [x, y, r] of BUMP) { const dx = s.bx - x, dy = s.by - y, dd = Math.hypot(dx, dy); if (dd < r + 3) { const nx = dx / dd, ny = dy / dd; s.bx = x + nx * (r + 3); s.by = y + ny * (r + 3); const sp = Math.max(170, Math.hypot(s.vx, s.vy) * 1.05); s.vx = nx * sp; s.vy = ny * sp; s.score += 500; s.flash = 0.15; g0.audio.sfx('click'); } }
          // flippers: two slanted bars that kick up when held
          const fy = 176;
          if (s.by > fy - 4 && s.by < fy + 6 && s.vy > 0) {
            if (s.bx > 28 && s.bx < 76) { if (s.L) { s.vy = -300; s.vx = 60 + (s.bx - 52) * 3; s.score += 10; g0.audio.sfx('punch'); } else { s.vy = -Math.abs(s.vy) * 0.35; s.vx += 30; } }
            else if (s.bx > 84 && s.bx < 132) { if (s.Rt) { s.vy = -300; s.vx = -60 + (s.bx - 108) * 3; s.score += 10; g0.audio.sfx('punch'); } else { s.vy = -Math.abs(s.vy) * 0.35; s.vx -= 30; } }
          }
          if (s.by > H + 6) {
            s.live = false; s.balls--;
            if (s.balls <= 0) {
              const free = s.score >= 20000;
              s.msg(free ? `${s.score.toLocaleString()}! FREE GAME. The kids at the next machine are impressed.` : `Game over: ${s.score.toLocaleString()}.`);
              if (free) { pl.cool = Math.min(100, (pl.cool || 0) + 20); clean(() => pl.addCash(cost)); }
              return s.finish(s.score, 1800);
            }
            s.msg(`Drained. ${s.balls} ball${s.balls > 1 ? 's' : ''} left.`); setTimeout(() => this.serve(s), 700);
          }
        }
        if (s.flash > 0) s.flash -= dt;
      },
      draw(g, s) {
        const t = s.t;
        g.fillStyle = '#140c1c'; g.fillRect(0, 0, W, H);
        // playfield art: a disco sunburst
        for (let i = 0; i < 12; i++) { g.fillStyle = i % 2 ? '#2a1438' : '#3a1a48'; g.beginPath(); g.moveTo(80, 110); g.arc(80, 110, 140, i * Math.PI / 6 + t * 0.2, (i + 1) * Math.PI / 6 + t * 0.2); g.fill(); }
        for (const [x, y, r] of BUMP) { g.fillStyle = s.flash > 0 ? GOLD : PINK; g.beginPath(); g.arc(x, y, r, 0, 7); g.fill(); g.fillStyle = PAPER; g.beginPath(); g.arc(x, y, r * 0.45, 0, 7); g.fill(); }
        g.fillStyle = '#6a4a2a'; g.fillRect(0, 0, 4, H); g.fillRect(W - 4, 0, 4, H);
        // flippers
        g.save(); g.fillStyle = GOLD;
        g.translate(30, 176); g.rotate(s.L ? -0.45 : 0.35); g.fillRect(0, -2, 46, 5); g.restore();
        g.save(); g.fillStyle = GOLD; g.translate(130, 176); g.rotate(s.Rt ? 0.45 : -0.35); g.fillRect(-46, -2, 46, 5); g.restore();
        if (s.live) { g.fillStyle = '#d8d8e0'; g.beginPath(); g.arc(s.bx, s.by, 3.5, 0, 7); g.fill(); g.fillStyle = '#fff'; g.fillRect(s.bx - 2, s.by - 2, 1, 1); }
        box(g, 4, 2, 76, 12, '#000'); txt(g, String(s.score).padStart(6, '0'), 8, 4, { color: '#ff5a3a', shadow: null });
        txt(g, `BALL ${4 - s.balls}`, 100, 4, { color: GOLD });
      },
    }, (r) => done && done(r));
  };

  // ---------------------------------------------------------------- arm wrestling
  M.armwrestle = function (opts, done) {
    const g0 = G(), pl = g0.player, stake = stakeOf(opts, 20), foe = opts.foe || 'A dock worker';
    if (!ante(stake, 'The bet')) return done && done(0);
    const str = 0.8 + Math.random() * 0.8 - (pl.drunk || 0) * 0.3;
    return M.open({
      title: 'Arm wrestling', sub: `${foe} puts ${R.fmtMoney(stake)} on the table. Mash PUSH. When he grits his teeth, HOLD STEADY instead or you'll lose your wrist.`, w: 200, h: 110,
      buttons: [['push', 'PUSH', 'big'], ['hold', 'HOLD STEADY'], ['quit', 'CONCEDE']],
      init(s) { s.pos = 0; s.grit = 0; s.nextGrit = 1.5 + Math.random() * 2; },
      press(s, id) {
        if (id === 'quit') { s.msg('You let him have it. He laughs and pockets the cash.'); return s.finish(-stake, 900); }
        if (id === 'push') { if (s.grit > 0) { s.pos -= 0.09; s.msg('He was ready for that!'); } else s.pos += 0.045; }
        if (id === 'hold' && s.grit > 0) { s.pos += 0.06; s.grit = 0; s.msg('You hold, and his surge breaks against you.'); }
      },
      update(s, dt) {
        s.pos -= dt * 0.1 * str;
        s.nextGrit -= dt;
        if (s.nextGrit <= 0 && s.grit <= 0) { s.grit = 0.9; s.nextGrit = 1.5 + Math.random() * 2.5; }
        if (s.grit > 0) { s.grit -= dt; s.pos -= dt * 0.25 * str; }
        if (s.pos >= 1) { clean(() => pl.addCash(stake * 2)); g0.audio.sfx('cash'); pl.rep.infamy += 0.5; s.msg(`SLAM. His knuckles hit the wood. ${R.fmtMoney(stake * 2)}.`); s.finish(stake, 1500); }
        if (s.pos <= -1) { s.msg('Your arm hits the table. The bar cheers for him.'); s.finish(-stake, 1500); }
      },
      draw(g, s) {
        g.fillStyle = '#3a2418'; g.fillRect(0, 0, 200, 110); g.fillStyle = '#6a3a1e'; g.fillRect(20, 70, 160, 30);
        const ang = -s.pos * 1.2, cx = 100, cy = 70;
        g.save(); g.translate(cx, cy); g.rotate(ang);
        g.fillStyle = '#c89070'; g.fillRect(-4, -46, 8, 46); g.fillStyle = '#a06a48'; g.fillRect(-6, -52, 12, 10);
        g.restore();
        g.fillStyle = '#2a2a3a'; g.fillRect(22, 30, 40, 40); g.fillStyle = s.grit > 0 ? RED : '#8a5a3a'; g.fillRect(138, 30, 40, 40);
        txt(g, 'YOU', 30, 20, { color: GOLD }); txt(g, s.grit > 0 ? 'GRRR!' : 'HIM', 140, 20, { color: s.grit > 0 ? RED : PAPER });
        box(g, 30, 102, 140, 5, '#222'); g.fillStyle = s.pos > 0 ? GREEN : RED; g.fillRect(100, 102, s.pos * 70, 5);
      },
    }, (r) => done && done(r));
  };

  // ---------------------------------------------------------------- dance-off
  const ARROWS = ['◀', '▼', '▲', '▶'];
  M.dance = function (opts, done) {
    const g0 = G(), pl = g0.player, stake = stakeOf(opts, 5);
    if (!ante(stake, 'The cover')) return done && done(0);
    return M.open({
      title: 'Dance-off', sub: 'Steps rise to the line in time with the record. Hit the matching arrow as each one crosses. Beat the local king of the floor.', w: 200, h: 150,
      buttons: [['0', '◀', 'big'], ['1', '▼', 'big'], ['2', '▲', 'big'], ['3', '▶', 'big']],
      init(s) { s.notes = []; for (let i = 0; i < 28; i++) s.notes.push({ t: 1.2 + i * 0.52 + (i % 5 === 4 ? 0.26 : 0), k: (Math.random() * 4) | 0, hit: 0 }); s.score = 0; s.combo = 0; s.best = 0; s.rival = 0; },
      press(s, id) {
        const k = +id, now = s.t;
        const n = s.notes.find((q) => !q.hit && q.k === k && Math.abs(q.t - now) < 0.18);
        if (n) { const perfect = Math.abs(n.t - now) < 0.07; n.hit = perfect ? 2 : 1; s.combo++; s.best = Math.max(s.best, s.combo); s.score += (perfect ? 100 : 50) * (1 + Math.floor(s.combo / 8)); s.msg(perfect ? 'OUTTA SIGHT!' : 'Groovy.'); }
        else { s.combo = 0; s.msg('Two left feet!'); }
      },
      update(s, dt) {
        for (const n of s.notes) if (!n.hit && s.t - n.t > 0.2) { n.hit = -1; s.combo = 0; }
        s.rival += dt * 150;
        if (s.t > s.notes[s.notes.length - 1].t + 1) {
          const win = s.score > s.rival;
          if (win) { pl.cool = 100; pl.rep.honor += 1; clean(() => pl.addCash(stake * 4)); g0.audio.sfx('cash'); }
          else pl.cool = Math.min(100, (pl.cool || 0) + 20);
          s.msg(win ? `The floor is yours. ${s.score} to ${Math.round(s.rival)}, best combo ${s.best}. Somebody sends over a drink.` : `The king keeps his crown, ${Math.round(s.rival)} to ${s.score}. Not bad, though.`);
          s.finish(win ? 1 : 0, 2200);
        }
      },
      draw(g, s) {
        const t = s.t;
        g.fillStyle = '#12081c'; g.fillRect(0, 0, 200, 150);
        // light-up floor
        for (let y = 0; y < 5; y++) for (let x = 0; x < 8; x++) { const on = (x + y + Math.floor(t * 4)) % 3 === 0; g.fillStyle = on ? ['#ff4aa0', '#f0b838', '#4ac8ff'][(x + y) % 3] : '#241830'; g.fillRect(4 + x * 24, 100 + y * 10, 22, 8); }
        // disco ball glints
        for (let i = 0; i < 10; i++) { g.fillStyle = 'rgba(255,255,255,0.5)'; g.fillRect((i * 37 + t * 60) % 200, (i * 23 + t * 17) % 90, 2, 2); }
        const lineY = 24;
        g.fillStyle = 'rgba(246,236,208,0.25)'; g.fillRect(40, lineY - 1, 120, 2);
        const arr = (k, x, y, col) => { if (k === 1) { g.fillStyle = col; for (let i = 0; i < 5; i++) g.fillRect(x + i, y + i, 9 - i * 2, 1); } else if (k === 2) { g.fillStyle = col; for (let i = 0; i < 5; i++) g.fillRect(x + 4 - i, y + i, i * 2 + 1, 1); } else arrow(g, k, x, y, col); };
        for (let k = 0; k < 4; k++) arr(k, 52 + k * 30, lineY - 3, '#6a5a7a');
        for (const n of s.notes) { if (n.hit > 0) continue; const y = lineY + (n.t - t) * 110; if (y < -10 || y > 96) continue; arr(n.k, 52 + n.k * 30, y - 3, n.hit < 0 ? '#5a4a5a' : [PINK, GOLD, '#4ac8ff', GREEN][n.k]); }
        txt(g, `YOU ${s.score}`, 4, 4, { color: GOLD }); txt(g, `KING ${Math.round(s.rival)}`, 130, 4, { color: PINK });
        if (s.combo > 3) txt(g, `${s.combo} COMBO`, 70, 86, { color: PAPER });
      },
    }, (r) => done && done(r));
  };

  // ---------------------------------------------------------------- three-card monte
  M.monte = function (opts, done) {
    const g0 = G(), pl = g0.player, stake = stakeOf(opts, 20);
    if (!ante(stake, 'The bet')) return done && done(0);
    const sharp = opts.sharp == null ? 0.25 : opts.sharp; // chance he palms the queen outright
    return M.open({
      title: 'Three-card monte', sub: `"Find the lady, find the lady!" ${R.fmtMoney(stake)} says you can't. Follow the queen, then tap her card.`, w: 200, h: 100,
      init(s) { s.pos = [0, 1, 2]; s.queen = 1; s.swaps = 7 + ((Math.random() * 5) | 0); s.sw = null; s.phase = 'show'; s.pt = 1.2; },
      update(s, dt) {
        s.pt -= dt;
        if (s.phase === 'show' && s.pt <= 0) { s.phase = 'shuffle'; s.pt = 0; }
        if (s.phase === 'shuffle') {
          if (!s.sw) { if (s.swaps-- <= 0) { s.phase = 'pick'; s.msg('Which one is she?'); return; } const a = (Math.random() * 3) | 0; let b = (Math.random() * 3) | 0; if (b === a) b = (a + 1) % 3; s.sw = { a, b, k: 0, sp: 3.2 + (7 - s.swaps) * 0.3 }; }
          s.sw.k += dt * s.sw.sp;
          if (s.sw.k >= 1) { const ca = s.pos.indexOf(s.sw.a), cb = s.pos.indexOf(s.sw.b); s.pos[ca] = s.sw.b; s.pos[cb] = s.sw.a; s.sw = null; }
        }
      },
      down(s, x) {
        if (s.phase !== 'pick') return;
        const slot = x < 70 ? 0 : x < 130 ? 1 : 2;
        const card = s.pos.indexOf(slot);
        const cheated = Math.random() < sharp;
        s.phase = 'reveal'; s.picked = slot;
        if (card === s.queen && !cheated) { clean(() => pl.addCash(stake * 2)); g0.audio.sfx('cash'); s.msg(`The queen of hearts! He pays you ${R.fmtMoney(stake * 2)}, not happily.`); s.finish(stake, 1800); }
        else { if (card === s.queen) { s.cheat = true; s.msg('You had her. He flips it and... a jack? He palmed the queen. Hustled.'); } else s.msg('A jack. The crowd groans. His "cousin" in the crowd wins the next round, funny enough.'); s.finish(-stake, 2200); }
      },
      draw(g, s) {
        g.fillStyle = '#2a2a30'; g.fillRect(0, 0, 200, 100); box(g, 20, 20, 160, 70, FELT);
        for (let c = 0; c < 3; c++) {
          let slot = s.pos.indexOf(c), x = 40 + slot * 60, y = 40;
          if (s.sw && (c === s.sw.a || c === s.sw.b)) { const other = c === s.sw.a ? s.sw.b : s.sw.a, x2 = 40 + s.pos.indexOf(other) * 60; x = x + (x2 - x) * s.sw.k; y = 40 + Math.sin(s.sw.k * Math.PI) * (c === s.sw.a ? -10 : 10); }
          const faceUp = s.phase === 'show' || (s.phase === 'reveal' && (slot === s.picked || c === s.queen));
          box(g, x - 10, y - 14, 20, 28, faceUp ? PAPER : BLUE);
          if (faceUp) { const q = c === s.queen && !(s.cheat && slot === s.picked); txt(g, q ? 'Q' : 'J', x - 6, y - 12, { color: q ? RED : INK, shadow: null }); suit(g, q ? 1 : 0, x - 5, y + 1, q ? RED : INK, 2); }
          else { g.fillStyle = '#5a8ac8'; g.fillRect(x - 7, y - 11, 14, 22); }
        }
      },
    }, (r) => done && done(r));
  };

  // ---------------------------------------------------------------- bare-knuckle boxing
  M.boxing = function (opts, done) {
    const g0 = G(), pl = g0.player, purse = stakeOf(opts, 50), foe = opts.foe || '"Kid" Dynamite';
    if (!ante(purse, 'The buy-in')) return done && done(0);
    return M.open({
      title: `Back-room bout vs ${foe}`, sub: 'Watch his shoulders. When he winds up (!) BLOCK. When he drops his guard, HAYMAKER. JAB to chip away. Three rounds.', w: 200, h: 120,
      buttons: [['jab', 'JAB', 'big'], ['block', 'BLOCK', 'big'], ['hay', 'HAYMAKER', 'big']],
      init(s) { s.me = 100; s.him = 100; s.round = 1; s.rt = 30; s.state = 'guard'; s.st = 1; s.block = 0; s.stun = 0; s.hit = 0; },
      press(s, id) {
        if (s.stun > 0) return;
        if (id === 'block') { s.block = 0.5; return; }
        if (id === 'jab') { if (s.state === 'open') { s.him -= 9; s.hit = 0.12; } else if (s.state === 'guard') s.him -= 2; else if (s.state === 'wind') { s.him -= 5; } g0.audio.sfx('punch'); }
        if (id === 'hay') { if (s.state === 'open') { s.him -= 24; s.hit = 0.25; g0.cam.shake(1); } else { s.stun = 0.8; s.msg('Wide open! He counters.'); s.me -= 10; } g0.audio.sfx('punch'); }
        if (s.him <= 0) { const win = purse * 3; clean(() => pl.addCash(win)); g0.audio.sfx('cash'); pl.rep.infamy += 2; s.msg(`${foe} goes down and stays down. The room erupts. ${R.fmtMoney(win)}.`); s.finish(win, 2000); }
      },
      update(s, dt) {
        s.st -= dt; s.rt -= dt; s.block = Math.max(0, s.block - dt); s.stun = Math.max(0, s.stun - dt); s.hit = Math.max(0, s.hit - dt);
        if (s.st <= 0) {
          if (s.state === 'wind') { if (s.block > 0) { s.me -= 3; s.msg('Blocked!'); s.state = 'open'; s.st = 0.9; } else { s.me -= 18; g0.cam.shake(1.5); g0.audio.sfx('punch'); s.msg('He catches you clean!'); s.state = 'guard'; s.st = 0.8 + Math.random(); } }
          else if (s.state === 'open') { s.state = 'guard'; s.st = 0.6 + Math.random() * 1.2; }
          else { s.state = Math.random() < 0.6 ? 'wind' : 'open'; s.st = s.state === 'wind' ? 0.55 : 0.7; }
        }
        if (s.me <= 0) { pl.hp = Math.max(10, pl.hp - 30); if (R.butcher) R.butcher.mark(pl, 20, null, 'melee'); s.msg('The ceiling spins. You wake up on the floor with a towel on your face.'); return s.finish(-purse, 2000); }
        if (s.rt <= 0) { if (s.round >= 3) { const win = s.him < s.me; if (win) { clean(() => pl.addCash(purse * 2)); g0.audio.sfx('cash'); } s.msg(win ? `Decision: YOU. ${R.fmtMoney(purse * 2)}.` : 'Decision goes to him. Hometown judges.'); return s.finish(win ? purse : -purse, 2000); } s.round++; s.rt = 30; s.me = Math.min(100, s.me + 15); s.msg(`Round ${s.round}.`); }
      },
      draw(g, s) {
        g.fillStyle = '#1a1210'; g.fillRect(0, 0, 200, 120);
        g.fillStyle = 'rgba(255,230,160,0.12)'; g.beginPath(); g.moveTo(80, 0); g.lineTo(120, 0); g.lineTo(170, 120); g.lineTo(30, 120); g.fill();
        // him
        const bob = Math.sin(s.t * 6) * 2, wind = s.state === 'wind', open = s.state === 'open';
        g.fillStyle = s.hit > 0 ? '#f0d0c0' : '#c89070'; g.fillRect(88, 30 + bob, 24, 22); // head
        g.fillStyle = '#8a3a2a'; g.fillRect(80, 52 + bob, 40, 36); // chest
        g.fillStyle = RED; // gloves
        if (open) { g.fillRect(70, 80 + bob, 12, 10); g.fillRect(118, 80 + bob, 12, 10); } else if (wind) { g.fillRect(64, 40 + bob, 12, 10); g.fillRect(118, 50 + bob, 12, 10); txt(g, '!', 136, 20, { color: GOLD }); } else { g.fillRect(84, 50 + bob, 12, 10); g.fillRect(104, 50 + bob, 12, 10); }
        // my gloves
        g.fillStyle = BLUE; g.fillRect(50, s.block > 0 ? 70 : 96, 18, 14); g.fillRect(132, s.block > 0 ? 70 : 96, 18, 14);
        box(g, 6, 6, 60, 5, '#300'); g.fillStyle = GREEN; g.fillRect(6, 6, Math.max(0, s.me) * 0.6, 5);
        box(g, 134, 6, 60, 5, '#300'); g.fillStyle = RED; g.fillRect(134, 6, Math.max(0, s.him) * 0.6, 5);
        txt(g, `R${s.round} ${Math.ceil(s.rt)}`, 84, 4, { color: GOLD });
      },
    }, (r) => done && done(r));
  };

  // ---------------------------------------------------------------- five-card draw
  const SUITS = ['♠', '♥', '♦', '♣'], RANKS = '23456789TJQKA';
  const deck = () => { const d = []; for (let s = 0; s < 4; s++) for (let r = 0; r < 13; r++) d.push({ r, s }); for (let i = d.length - 1; i > 0; i--) { const j = (Math.random() * (i + 1)) | 0; [d[i], d[j]] = [d[j], d[i]]; } return d; };
  const rank = (h) => {
    const rs = h.map((c) => c.r).sort((a, b) => b - a), cnt = {}; rs.forEach((r) => { cnt[r] = (cnt[r] || 0) + 1; });
    const groups = Object.entries(cnt).map(([r, n]) => [n, +r]).sort((a, b) => b[0] - a[0] || b[1] - a[1]);
    const flush = h.every((c) => c.s === h[0].s), uniq = [...new Set(rs)], straight = uniq.length === 5 && (rs[0] - rs[4] === 4 || rs.join() === '12,3,2,1,0');
    const tie = groups.map((x) => x[1]);
    let cat = 0, name = 'High card';
    if (straight && flush) { cat = 8; name = 'Straight flush'; } else if (groups[0][0] === 4) { cat = 7; name = 'Four of a kind'; } else if (groups[0][0] === 3 && groups[1][0] === 2) { cat = 6; name = 'Full house'; } else if (flush) { cat = 5; name = 'Flush'; } else if (straight) { cat = 4; name = 'Straight'; } else if (groups[0][0] === 3) { cat = 3; name = 'Three of a kind'; } else if (groups[0][0] === 2 && groups[1][0] === 2) { cat = 2; name = 'Two pair'; } else if (groups[0][0] === 2) { cat = 1; name = 'A pair'; }
    return { score: cat * 1e10 + tie.reduce((a, r, i) => a + r * Math.pow(15, 4 - i), 0), name };
  };
  M.poker = function (opts, done) {
    const g0 = G(), pl = g0.player, stake = stakeOf(opts, 25), foe = opts.foe || 'Fat Sal';
    if (!ante(stake, 'The ante')) return done && done(0);
    return M.open({
      title: `Five-card draw with ${foe}`, sub: `${R.fmtMoney(stake)} ante. Tap cards to hold them, then DRAW. Bet big or fold after the draw.`, w: 220, h: 110,
      buttons: [['draw', 'DRAW', 'big'], ['raise', `RAISE ${R.fmtMoney(stake)}`], ['call', 'SHOW'], ['fold', 'FOLD']],
      init(s) { s.d = deck(); s.me = s.d.splice(0, 5); s.him = s.d.splice(0, 5); s.hold = [0, 0, 0, 0, 0]; s.phase = 'hold'; s.pot = stake * 2; s.msg('Tap the cards you want to keep.'); },
      down(s, x, y) { if (s.phase !== 'hold' || y < 56) return; const i = Math.floor((x - 10) / 42); if (i >= 0 && i < 5) s.hold[i] ^= 1; },
      press(s, id) {
        if (id === 'fold') { s.msg(`You fold. ${foe} rakes in the pot without showing.`); return s.finish(-stake, 1200); }
        if (id === 'draw' && s.phase === 'hold') {
          for (let i = 0; i < 5; i++) if (!s.hold[i]) s.me[i] = s.d.pop();
          // he keeps pairs and better, redraws the rest
          const cnt = {}; s.him.forEach((c) => { cnt[c.r] = (cnt[c.r] || 0) + 1; });
          for (let i = 0; i < 5; i++) if (cnt[s.him[i].r] < 2 && !(s.him[i].r >= 11 && Math.random() < 0.4)) s.him[i] = s.d.pop();
          s.phase = 'bet'; s.msg(`You have ${rank(s.me).name.toLowerCase()}. Raise, show, or fold.`); return;
        }
        if (s.phase !== 'bet') return;
        if (id === 'raise') { if (!pl.pay(stake)) return s.msg('You can\'t cover a raise.'); s.pot += stake * 2; s.raised = true; }
        if (id === 'raise' || id === 'call') {
          const a = rank(s.me), b = rank(s.him); s.phase = 'show';
          const win = a.score > b.score;
          if (win) { clean(() => pl.addCash(s.pot)); g0.audio.sfx('cash'); }
          s.msg(`${foe} shows ${b.name.toLowerCase()}. ${win ? `Your ${a.name.toLowerCase()} takes ${R.fmtMoney(s.pot)}.` : 'His hand wins.'}`);
          s.finish(win ? s.pot - stake * (s.raised ? 2 : 1) : -stake * (s.raised ? 2 : 1), 2200);
        }
      },
      draw(g, s) {
        g.fillStyle = FELT; g.fillRect(0, 0, 220, 110);
        const card = (c, x, y, up, held) => { box(g, x, y, 34, 44, up ? PAPER : '#8a2a2a'); if (!up) { g.fillStyle = '#c84a4a'; g.fillRect(x + 4, y + 4, 26, 36); return; } const red = c.s === 1 || c.s === 2; txt(g, RANKS[c.r].replace('T', '10'), x + 4, y + 3, { color: red ? RED : INK, shadow: null }); suit(g, c.s, x + 12, y + 18, red ? RED : INK, 2); if (held) { g.fillStyle = GOLD; g.fillRect(x, y + 40, 34, 4); txt(g, 'HELD', x + 17, y + 46, { align: 'center', color: GOLD }); } };
        for (let i = 0; i < 5; i++) card(s.him[i], 10 + i * 42, 4, s.phase === 'show', false);
        for (let i = 0; i < 5; i++) card(s.me[i], 10 + i * 42, 58, true, s.phase === 'hold' && s.hold[i]);
        txt(g, `POT ${R.fmtMoney(s.pot)}`, 110, 50, { align: 'center', color: GOLD });
      },
    }, (r) => done && done(r));
  };

  // ---------------------------------------------------------------- drag race
  M.drag = function (opts, done) {
    const g0 = G(), pl = g0.player, stake = stakeOf(opts, 100), foe = opts.foe || 'Eddie in the Stallion GT';
    if (!ante(stake, 'The race')) return done && done(0);
    return M.open({
      title: 'Drag race, quarter mile', sub: `${R.fmtMoney(stake)} to ${foe}. Hit GAS on green (too early and you jump the light), then SHIFT when the needle's in the red-gold band.`, w: 220, h: 110,
      buttons: [['gas', 'GAS', 'big'], ['shift', 'SHIFT', 'big']],
      init(s) { s.light = 0; s.lt = 0; s.go = false; s.rpm = 0; s.gear = 1; s.v = 0; s.x = 0; s.fx = 0; s.fv = 0; s.foeGear = 1; s.foeRpm = 0; s.launch = null; },
      press(s, id) {
        if (id === 'gas' && !s.go) { if (s.light < 3) { s.msg('JUMPED THE LIGHT! Disqualified. He takes your money.'); return s.finish(-stake, 1500); } s.go = true; s.launch = s.t - s.greenT; s.msg(s.launch < 0.25 ? 'Perfect launch!' : 'Slow off the line!'); }
        if (id === 'shift' && s.go && s.gear < 4) { const good = s.rpm > 0.78 && s.rpm < 0.93; s.gear++; s.rpm = good ? 0.5 : 0.35; s.bonus = good ? 1 : 0; s.msg(good ? 'Perfect shift!' : s.rpm > 0.93 ? 'Over-rev!' : 'Early shift.'); }
      },
      update(s, dt) {
        s.lt += dt;
        if (s.light < 3 && s.lt > 0.9) { s.light++; s.lt = 0; if (s.light === 3) s.greenT = s.t; g0.audio.sfx('click'); }
        if (s.light < 3) return;
        // the rival: decent but not perfect
        s.foeRpm += dt * (0.55 - s.foeGear * 0.07); if (s.foeRpm > 0.84 + Math.random() * 0.08 && s.foeGear < 4) { s.foeGear++; s.foeRpm = 0.45; }
        s.fv += dt * (70 - s.foeGear * 10) * (s.foeRpm > 0.95 ? 0.4 : 1); s.fx += s.fv * dt;
        if (s.go) {
          s.rpm += dt * (0.6 - s.gear * 0.08);
          const over = s.rpm > 1;
          if (over) s.rpm = 1;
          s.v += dt * (74 - s.gear * 10) * (over ? 0.35 : 1) * (s.bonus ? 1.1 : 1) * (s.launch != null && s.launch < 0.25 ? 1.08 : 1); s.x += s.v * dt;
        }
        const L = 400;
        if (s.x >= L || s.fx >= L) {
          const win = s.x >= s.fx;
          if (win) { clean(() => pl.addCash(stake * 2)); g0.audio.sfx('cash'); pl.rep.infamy += 1; pl.cool = Math.min(100, (pl.cool || 0) + 25); }
          s.msg(win ? `You take it by ${Math.round((s.x - s.fx) / 4)} car lengths. ${R.fmtMoney(stake * 2)}.` : `${foe} by a nose.`);
          s.finish(win ? stake : -stake, 1800);
        }
      },
      draw(g, s) {
        g.fillStyle = '#12101a'; g.fillRect(0, 0, 220, 110);
        g.fillStyle = '#2a2a30'; g.fillRect(0, 30, 220, 50); g.fillStyle = GOLD; for (let x = -((s.x * 0.8) % 20); x < 220; x += 20) g.fillRect(x, 54, 10, 2);
        // finish line comes closer
        const fl = 20 + (400 - s.x) * 0.5; if (fl < 220) { g.fillStyle = PAPER; g.fillRect(fl, 30, 3, 50); }
        const car = (x, y, col) => { g.fillStyle = col; g.fillRect(x, y, 26, 10); g.fillStyle = '#1a1a24'; g.fillRect(x + 8, y + 2, 10, 6); g.fillStyle = '#fffbe0'; g.fillRect(x + 25, y + 1, 1, 2); g.fillRect(x + 25, y + 7, 1, 2); };
        car(20, 60, RED); car(20 + (s.fx - s.x) * 0.5, 36, BLUE);
        // tree
        for (let i = 0; i < 3; i++) { g.fillStyle = s.light > i ? (i === 2 ? '#3aff6a' : GOLD) : '#3a3020'; g.beginPath(); g.arc(200, 10 + i * 8, 3, 0, 7); g.fill(); }
        // tach
        box(g, 6, 84, 90, 20, '#000'); g.fillStyle = '#8a2a1a'; g.fillRect(6 + 90 * 0.78, 84, 90 * 0.15, 20); g.fillStyle = GOLD; g.fillRect(6 + 90 * 0.78, 84, 2, 20);
        g.fillStyle = PAPER; g.fillRect(6 + s.rpm * 88, 84, 2, 20);
        txt(g, `GEAR ${s.gear}`, 104, 88, { color: GOLD });
      },
    }, (r) => done && done(r));
  };

  // ---------------------------------------------------------------- where you find them
  // (hooked at game setup: this file loads before the UI module)
  const MT = (R.monte = { t: 20 });
  MT.init = function () {
  if (this.wrapped) return;
  this.wrapped = true;
  const U = R.UI.prototype, io = U.interiorOptions;
  U.interiorOptions = function (b) {
    const o = io.call(this, b), g = G(), h = g.clock.hour(), night = h >= 19 || h < 3;
    const add = (label, small, fn) => o.push({ label, small, fn: () => { g.ui.closeSheet && g.ui.closeSheet(); setTimeout(fn, 60); } });
    if (b.type === 'bar' || b.type === 'arcade' || b.type === 'costume') add('Play pinball', '"Disco Inferno", $1 a game', () => M.pinball({ stake: 1 }));
    if (b.type === 'bar') {
      add('Arm-wrestle a regular', '$20 on the table', () => M.armwrestle({ stake: 20, foe: R.rng.pick(['A dock worker', 'A trucker named Tiny', 'The bartender\'s brother', 'A lumberjack from Pinecrest']) }));
      if (night) add('Poker in the back room', 'Five-card draw, $25 ante', () => M.poker({ stake: 25, foe: R.rng.pick(['Fat Sal', 'Moe the Barber', 'A priest on his night off', 'Lucky Lenny']) }));
      if (night && (g.clock.day() % 7 === 4 || g.clock.day() % 7 === 5)) add('Back-room bout', 'Friday and Saturday nights. $50 buy-in, triple if you KO him', () => M.boxing({ stake: 50, foe: R.rng.pick(['"Kid" Dynamite', 'Big Walt', 'The Butcher of Bayou Clair', 'Irish Mickey']) }));
    }
    if ((b.type === 'club' || b.type === 'strip') && night) add('Challenge the king of the floor', 'Dance-off, $5', () => M.dance({ stake: 5 }));
    if (b.type === 'gas' && (h >= 23 || h < 4)) add('Street racers out back', 'Quarter mile, $100 a race', () => M.drag({ stake: 100, foe: R.rng.pick(['Eddie in the Stallion GT', 'Rosa in a cherry Monarch', 'The Pinecrest twins', 'A kid in his dad\'s Interceptor']) }));
    return o;
  };

  const tree = R.dialog.tree;
  R.dialog.tree = function (h) {
    const t = tree.call(this, h);
    if (t && t.options && h.monte) {
      const i = Math.max(0, t.options.findIndex((o) => /Goodbye/.test(o.label)));
      t.options.splice(i, 0, { label: '"Deal me in."', small: 'Three-card monte, $20', cls: 'go', fn: () => { G().ui.closeSheet(); setTimeout(() => M.monte({ stake: 20, sharp: G().player.rep.infamy > 50 ? 0.05 : 0.25 }), 60); } });
      t.options.splice(i, 0, { label: '"I know that trick."', small: 'Call out the hustle (he might not like it)', fn: () => { const g = G(); if (g.player.rep.infamy > 40 || g.player.weaponOut) { g.actors.say(h, 'Hey, no problem, no problem. Here, take this and scram.'); g.player.addCash(40); } else { g.actors.say(h, 'You calling me a cheat? Beat it before my cousin gets here.'); } } });
    }
    return t;
  };
  };
  // three-card monte hustlers on the sidewalk, daytime, in the cities
  MT.update = function (dt) {
    const g = G(), pl = g.player, TS = R.TILE, w = g.world;
    this.t -= dt;
    if (this.t > 0) return;
    this.t = 40;
    if (pl.room || pl.inCar || (R.opening && R.opening.active)) return;
    const hr = g.clock.hour(), city = w.cityAt((pl.x / TS) | 0, (pl.y / TS) | 0);
    if (!city || hr < 10 || hr > 19 || (this.h && !this.h.dead && !this.h.removed && R.dist(this.h.x, this.h.y, pl.x, pl.y) < TS * 30)) return;
    if (Math.random() > 0.35) return;
    const sp = w.findNear((pl.x / TS) | 0, (pl.y / TS) | 0, 10, 18, (x, y) => w.t(x, y) === R.data.T.WALK && !w.solidPed(x, y));
    if (!sp || g.cam.onScreen(sp.x * TS + 8, sp.y * TS + 8, 10)) return;
    const h = g.actors.makeHuman(sp.x * TS + 8, sp.y * TS + 8, { arch: 'hustler', cash: 120 });
    h.keep = true; h.stay = true; h.state = 'idle'; h.timer = 1e9; h.monte = true; h.strangerName = 'Card sharp';
    this.h = h;
    setTimeout(() => { if (h && !h.dead && !h.removed && R.dist(h.x, h.y, g.player.x, g.player.y) < TS * 14) g.actors.say(h, 'Find the lady! Find the lady! Twenty gets you forty!'); }, 1500);
  };
})();
