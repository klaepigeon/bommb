// RHAPSODY — hands-on minigames drawn in the same pixel style as the world: picking
// locks, hotwiring, cracking safes, blackjack, slots, pool, darts and craps. Each one
// runs in a sheet with its own little canvas and calls back with how it went.
(function () {
  const A = () => R.art;
  const INK = '#1b1410', PAPER = '#f6ecd0', GOLD = '#f0b838', RED = '#c83a2a', GREEN = '#3a8a4a', FELT = '#1f5a3a', WOOD = '#6a3a1e';
  const M = (R.mini = {});

  // ---------------------------------------------------------------- framework
  // spec: { title, sub, w, h, init(s), update(s, dt), draw(g, s), down(s, x, y), up(s, x, y),
  //         buttons: [[id, label]], press(s, id), release(s, id), locked }
  M.open = function (spec, done) {
    const ui = R.game.ui, g0 = R.game;
    const W = spec.w || 240, H = spec.h || 140;
    const btns = (spec.buttons || []).map(([id, label, cls]) => `<button class="mgb ${cls || ''}" data-b="${id}">${label}</button>`).join('');
    const s = ui.openSheet('mini', ui.header(spec.title, spec.sub) + `<div class="body mgbody"><canvas class="mg" width="${W}" height="${H}" style="--ar:${(W / H).toFixed(3)}"></canvas><div class="mgmsg" id="mgmsg"></div><div class="mgbtns">${btns}</div></div>`);
    const cv = s.querySelector('canvas.mg'), g = cv.getContext('2d');
    g.imageSmoothingEnabled = false;
    const st = { t: 0, W, H, done: false, msg: (m) => { const el = s.querySelector('#mgmsg'); if (el) el.textContent = m; }, cash: () => g0.player.cash };
    let result;
    st.finish = (r, delay) => {
      if (st.done) return;
      st.done = true;
      result = r;
      setTimeout(() => { if (ui.sheetOpen === 'mini') ui.closeSheet(); }, delay == null ? 900 : delay);
    };
    const toXY = (e) => { const r = cv.getBoundingClientRect(); return [((e.clientX - r.left) / r.width) * W, ((e.clientY - r.top) / r.height) * H]; };
    cv.addEventListener('pointerdown', (e) => { e.preventDefault(); if (!st.done && spec.down) spec.down(st, ...toXY(e)); });
    cv.addEventListener('pointermove', (e) => { if (!st.done && spec.move) spec.move(st, ...toXY(e)); });
    cv.addEventListener('pointerup', (e) => { if (!st.done && spec.up) spec.up(st, ...toXY(e)); });
    s.querySelectorAll('.mgb').forEach((b) => {
      b.addEventListener('pointerdown', (e) => { e.preventDefault(); if (!st.done && spec.press) spec.press(st, b.dataset.b); g0.audio.sfx('click'); });
      b.addEventListener('pointerup', () => { if (!st.done && spec.release) spec.release(st, b.dataset.b); });
      b.addEventListener('pointerleave', () => { if (!st.done && spec.release) spec.release(st, b.dataset.b); });
    });
    st.button = (id) => s.querySelector(`[data-b="${id}"]`);
    if (spec.init) spec.init(st);
    let last = performance.now(), alive = true;
    const loop = (now) => {
      if (!alive) return;
      const dt = Math.min(0.05, (now - last) / 1000);
      last = now;
      st.t += dt;
      if (spec.update && !st.done) spec.update(st, dt);
      g.setTransform(1, 0, 0, 1, 0, 0);
      spec.draw(g, st);
      requestAnimationFrame(loop);
    };
    requestAnimationFrame(loop);
    ui.onClose = () => { alive = false; if (done) done(result === undefined ? null : result, st); };
    if (spec.locked) { const x = s.querySelector('header .x'); if (x) x.style.visibility = 'hidden'; }
    return st;
  };
  const txt = (g, s, x, y, o) => A().ptext(g, s, x, y, Object.assign({ color: PAPER, shadow: INK }, o || {}));
  const box = (g, x, y, w, h, fill, edge) => { g.fillStyle = edge || INK; g.fillRect(x - 1, y - 1, w + 2, h + 2); g.fillStyle = fill; g.fillRect(x, y, w, h); };

  // ---------------------------------------------------------------- lockpicking
  // Pins bounce in their chambers; lift each one as it crosses the shear line.
  M.lockpick = function (opts, done) {
    const pl = R.game.player, n = opts.pins || 4;
    if (!pl.inv.tools.lockpick) { R.game.ui.toast('No lockpicks. Pawn shops and general stores sell them.', 'warn'); return done && done(false); }
    return M.open({
      title: opts.title || 'Pick the Lock', sub: `${n} pins. Tap LIFT (or the lock) as the lit pin crosses the gold line. Picks left: ${pl.inv.tools.lockpick}`,
      w: 240, h: 130, buttons: [['lift', 'LIFT', 'big'], ['quit', 'GIVE UP']],
      init(s) {
        s.pins = Array.from({ length: n }, (_, i) => ({ set: false, sp: 2.2 + Math.random() * 1.6 + i * 0.35 + (opts.hard || 0), ph: Math.random() * 6 }));
        s.i = 0; s.strain = 0; s.win = Math.max(0.1, 0.2 - (opts.hard || 0) * 0.03); s.shake = 0;
      },
      update(s, dt) { s.shake = Math.max(0, s.shake - dt * 3); },
      pos(s, p) { return Math.sin(s.t * p.sp + p.ph); },
      press(s, id) {
        if (id === 'quit') return s.finish(false, 0);
        this.lift(s);
      },
      down(s) { this.lift(s); },
      lift(s) {
        const p = s.pins[s.i];
        if (!p) return;
        if (Math.abs(this.pos(s, p)) < s.win) {
          p.set = true; s.i++;
          R.game.audio.sfx('reload');
          if (s.i >= n) { s.msg('Click. The cylinder turns.'); R.game.audio.sfx('door'); s.finish(true); }
          else s.msg(`Pin ${s.i} set.`);
        } else {
          s.strain++; s.shake = 1; R.game.audio.sfx('bump');
          if (s.strain >= 3) {
            pl.inv.tools.lockpick--;
            s.msg(`SNAP. The pick broke. ${pl.inv.tools.lockpick} left.`);
            if (!pl.inv.tools.lockpick) s.finish(false);
            else { s.strain = 0; s.i = 0; s.pins.forEach((q) => (q.set = false)); }
          } else s.msg(['Too early.', 'Missed it.', 'Easy... the pick is bending.'][s.strain - 1] || 'Missed.');
        }
      },
      draw(g, s) {
        g.fillStyle = '#2a1e16'; g.fillRect(0, 0, 240, 130);
        const ox = s.shake ? (Math.random() - 0.5) * 3 : 0;
        // lock body
        box(g, 20 + ox, 20, 200, 90, '#b08a3a');
        g.fillStyle = '#d8b050'; g.fillRect(22 + ox, 22, 196, 4);
        const sw = 180 / n;
        const shear = 64;
        for (let i = 0; i < n; i++) {
          const p = s.pins[i], x = 30 + i * sw + sw / 2 - 6 + ox;
          box(g, x, 28, 12, 72, '#3a2a1a');
          const y = p.set ? shear - 2 : shear + this.pos(s, p) * 22; // top of the key pin
          // driver pin + key pin
          g.fillStyle = '#8a8a92'; g.fillRect(x + 2, y - 16, 8, 14);
          g.fillStyle = i === s.i ? '#f6e080' : '#c0a060'; g.fillRect(x + 2, y, 8, 16);
          g.fillStyle = p.set ? GREEN : i === s.i ? GOLD : '#6a5a3a'; g.fillRect(x + 4, y + 2, 4, 2);
        }
        g.fillStyle = GOLD; g.fillRect(24 + ox, shear - 1, 192, 2);
        // the pick
        g.fillStyle = '#c8c8d0'; g.fillRect(0, 104, 30 + Math.min(n - 1, s.i) * sw + sw / 2, 3);
        txt(g, `STRAIN ${'!'.repeat(s.strain)}`, 22, 114, { color: s.strain ? RED : '#8a7a5a' });
      },
    }, (r) => done && done(!!r));
  };

  // ---------------------------------------------------------------- hotwiring
  M.hotwire = function (opts, done) {
    const cols = [['#d83a2a', 'RED'], ['#2a6ad8', 'BLUE'], ['#e0c020', 'YEL'], ['#3aa84a', 'GRN'], ['#e8e8e8', 'WHT']].slice(0, opts.wires || 4);
    return M.open({
      title: opts.title || 'Hotwire', sub: opts.sub || 'Tap a wire on the left, then its match on the right. Then crank it over before the timer runs out.', w: 240, h: 130,
      buttons: [['crank', 'CRANK', 'big'], ['quit', 'GIVE UP']],
      init(s) {
        s.left = cols.map((c, i) => ({ c, i })); s.right = cols.map((c, i) => ({ c, i })).sort(() => Math.random() - 0.5);
        s.linked = new Set(); s.pick = null; s.time = opts.time || 14; s.crank = 0; s.spark = 0;
      },
      update(s, dt) {
        s.time -= dt; s.spark = Math.max(0, s.spark - dt * 4);
        if (s.cranking) { s.crank += dt * 0.8; if (s.crank > 1) { s.msg('VROOM. She turns over.'); R.game.audio.sfx('promote'); s.finish(true, 600); } }
        else s.crank = Math.max(0, s.crank - dt * 0.6);
        if (s.time <= 0) { s.msg('Too slow. The alarm is screaming.'); s.finish(false); }
      },
      down(s, x, y) {
        const rowOf = (yy) => Math.floor((yy - 22) / 18);
        const r = rowOf(y);
        if (r < 0 || r >= cols.length) return;
        if (x < 70) { if (!s.linked.has(s.left[r].i)) s.pick = s.left[r].i; }
        else if (x > 170 && s.pick != null) {
          if (s.right[r].i === s.pick) { s.linked.add(s.pick); s.msg(s.linked.size === cols.length ? 'All connected. CRANK it!' : 'Connected.'); R.game.audio.sfx('reload'); }
          else { s.spark = 1; s.time -= 2; s.msg('ZAP! Wrong wire. -2 seconds.'); R.game.audio.sfx('bump'); }
          s.pick = null;
        }
      },
      press(s, id) {
        if (id === 'quit') return s.finish(false, 0);
        if (id === 'crank') { if (s.linked.size < cols.length) { s.spark = 1; s.msg('Nothing. Finish the wires first.'); } else s.cranking = true; }
      },
      release(s, id) { if (id === 'crank') s.cranking = false; },
      draw(g, s) {
        g.fillStyle = '#1a1614'; g.fillRect(0, 0, 240, 130);
        box(g, 10, 10, 220, 100, '#2e2a26');
        cols.forEach(([c], i) => {
          const y = 22 + i * 18;
          // left stubs
          const L = s.left[i];
          box(g, 18, y, 44, 8, L.c[0]);
          if (s.pick === L.i) { g.strokeStyle = PAPER; g.strokeRect(16.5, y - 2.5, 48, 13); }
          const Rr = s.right[i];
          box(g, 178, y, 44, 8, Rr.c[0]);
          if (s.linked.has(L.i)) {
            const ry = 22 + s.right.findIndex((q) => q.i === L.i) * 18;
            g.strokeStyle = L.c[0]; g.lineWidth = 3;
            g.beginPath(); g.moveTo(62, y + 4); g.bezierCurveTo(110, y + 4, 130, ry + 4, 178, ry + 4); g.stroke();
          }
        });
        if (s.spark) for (let k = 0; k < 8; k++) { g.fillStyle = k % 2 ? '#fff6c0' : GOLD; g.fillRect(100 + Math.random() * 40, 30 + Math.random() * 60, 2, 2); }
        txt(g, `${Math.max(0, s.time).toFixed(1)}s`, 120, 114, { align: 'center', color: s.time < 4 ? RED : GOLD });
        box(g, 170, 116, 60, 6, '#3a3a3a'); g.fillStyle = GREEN; g.fillRect(170, 116, 60 * Math.min(1, s.crank), 6);
      },
    }, (r) => done && done(!!r));
  };

  // ---------------------------------------------------------------- safecracking
  // Mastermind with a PIN pad: find the 4-digit code. After each guess the lights say how
  // many digits are right and in place (green) and right but misplaced (amber). A good
  // listener (the stethoscope) gets an extra try; each wrong guess makes a little noise.
  M.safe = function (opts, done) {
    const N = opts.digits || 4, TRIES = (opts.tries || 10) + (R.game.player.inv.tools.stethoscope ? 2 : 0);
    // no digit repeats, so every light narrows things down
    const pool = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
    const code = [];
    while (code.length < N) code.push(pool.splice(Math.floor(Math.random() * pool.length), 1)[0]);
    const score = (guess) => {
      let green = 0, amber = 0;
      const cRest = [], gRest = [];
      for (let i = 0; i < N; i++) { if (guess[i] === code[i]) green++; else { cRest.push(code[i]); gRest.push(guess[i]); } }
      for (const d of gRest) { const k = cRest.indexOf(d); if (k >= 0) { amber++; cRest.splice(k, 1); } }
      return [green, amber];
    };
    // the digits are on the pad drawn in the canvas; the buttons below are the big three
    return M.open({
      title: 'Crack the Safe', sub: `Tap digits on the pad to crack the ${N}-digit code. No digit repeats. Green light: right digit, right place. Amber: right digit, wrong place. ${TRIES} tries before it locks out.`, w: 240, h: 150,
      buttons: [['del', '⌫ DEL'], ['ok', 'ENTER', 'big'], ['quit', 'QUIT']],
      init(s) { s.cur = []; s.hist = []; s.shake = 0; s.open = 0; s.tries = TRIES; s.press = (id) => this.press(s, id); },
      update(s, dt) { s.shake = Math.max(0, s.shake - dt * 3); if (s.open) s.open = Math.min(1, s.open + dt * 2); },
      press(s, id) {
        if (id === 'quit') return s.finish(false, 0);
        if (id === 'del') { s.cur.pop(); return; }
        if (id === 'ok') {
          if (s.cur.length < N) return s.msg(`Enter all ${N} digits first.`);
          const [green, amber] = score(s.cur);
          s.hist.push({ d: s.cur.slice(), green, amber });
          s.cur = [];
          if (green === N) { s.open = 0.01; s.msg('Clunk. The bolts slide back. It\'s open.'); R.game.audio.sfx('door'); return s.finish(true, 1200); }
          R.game.audio.sfx('bump'); s.shake = 1;
          // a wrong code beeps: anyone nearby might hear
          const pl = R.game.player; R.game.actors.noise(pl.x, pl.y, R.TILE * 3, 'rustle', pl);
          if (s.hist.length >= TRIES) { s.msg(`LOCKOUT. The code was ${code.join('')}. Better luck with the next one.`); R.game.audio.sfx('alarm'); return s.finish(false, 1800); }
          s.msg(green + amber === 0 ? 'None of those digits. Cross them off.' : `${green} in place, ${amber} misplaced. ${TRIES - s.hist.length} tries left.`);
          return;
        }
        if (!/^\d$/.test(id)) return;
        if (s.cur.includes(+id)) return s.msg(`${id} is already in. No digit repeats.`);
        if (s.cur.length < N) { s.cur.push(+id); R.game.audio.sfx('click'); }
      },
      down(s, x, y) {
        // tapping the pad on the canvas works too (the digit grid on the right)
        if (x < 150 || y < 20) return;
        const col = Math.floor((x - 150) / 28), row = Math.floor((y - 20) / 30);
        const pad = [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9'], ['del', '0', 'ok']];
        if (row >= 0 && row < 4 && col >= 0 && col < 3) this.press(s, pad[row][col]);
      },
      draw(g, s) {
        const ox = s.shake ? (Math.random() - 0.5) * 3 : 0;
        g.fillStyle = '#23232a'; g.fillRect(0, 0, 240, 150);
        // the safe door and its display
        box(g, 6 + ox, 6, 136, 138, '#4a4a56');
        box(g, 14 + ox, 12, 120, 20, '#0e1a12');
        for (let i = 0; i < N; i++) txt(g, s.cur[i] != null ? String(s.cur[i]) : '_', 34 + ox + i * 24, 17, { scale: 2, color: '#68f0a0', shadow: null });
        // the history: each guess and its lights
        const rows = s.hist.slice(-8);
        rows.forEach((h, r) => {
          const y = 38 + r * 13;
          txt(g, h.d.join(' '), 18 + ox, y, { color: '#e8e0d0', shadow: null });
          for (let k = 0; k < N; k++) {
            const c = k < h.green ? '#58e070' : k < h.green + h.amber ? '#f0b030' : '#2a2a30';
            g.fillStyle = INK; g.fillRect(84 + ox + k * 12, y, 9, 9);
            g.fillStyle = c; g.fillRect(85 + ox + k * 12, y + 1, 7, 7);
          }
        });
        txt(g, `${Math.max(0, TRIES - s.hist.length)} LEFT`, 18 + ox, 134, { color: TRIES - s.hist.length <= 2 ? RED : GOLD });
        if (s.open) { g.fillStyle = `rgba(240,184,56,${s.open * 0.35})`; g.fillRect(6, 6, 136, 138); }
        // the pad
        const pad = [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9'], ['⌫', '0', 'OK']];
        txt(g, 'PIN', 190, 6, { align: 'center', color: '#b8b0a0' });
        pad.forEach((row, r) => row.forEach((k, c) => {
          const x = 152 + c * 28, y = 20 + r * 30;
          box(g, x, y, 24, 24, k === 'OK' ? '#3a8a4a' : k === '⌫' ? '#8a3a2a' : '#c8c0b0');
          txt(g, k, x + 12, y + 8, { align: 'center', color: k === 'OK' || k === '⌫' ? PAPER : INK, shadow: null });
        }));
      },
    }, (r) => done && done(!!r));
  };

  // ---------------------------------------------------------------- cards
  const SUITS = ['♠', '♥', '♦', '♣'], RANKS = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
  const deck = () => { const d = []; for (let k = 0; k < 2; k++) for (const s of SUITS) for (const r of RANKS) d.push({ r, s }); return d.sort(() => Math.random() - 0.5); };
  const cardVal = (c) => (c.r === 'A' ? 11 : ['J', 'Q', 'K'].includes(c.r) ? 10 : +c.r);
  const handVal = (h) => { let v = h.reduce((a, c) => a + cardVal(c), 0), aces = h.filter((c) => c.r === 'A').length; while (v > 21 && aces--) v -= 10; return v; };
  function drawCard(g, c, x, y, down) {
    box(g, x, y, 22, 30, down ? '#7a2a2a' : '#fffaf0');
    if (down) { g.fillStyle = '#9a3a3a'; for (let k = 2; k < 28; k += 4) g.fillRect(x + 2, y + k, 18, 2); return; }
    const red = c.s === '♥' || c.s === '♦';
    txt(g, c.r, x + 2, y + 2, { color: red ? RED : INK, shadow: null });
    g.fillStyle = red ? RED : INK;
    const px = x + 11, py = y + 18;
    if (c.s === '♥') { g.fillRect(px - 4, py - 3, 3, 3); g.fillRect(px + 1, py - 3, 3, 3); g.fillRect(px - 4, py, 8, 2); g.fillRect(px - 3, py + 2, 6, 2); g.fillRect(px - 1, py + 4, 2, 1); }
    else if (c.s === '♦') { g.fillRect(px - 1, py - 4, 2, 9); g.fillRect(px - 2, py - 3, 4, 7); g.fillRect(px - 3, py - 1, 6, 3); }
    else if (c.s === '♠') { g.fillRect(px - 1, py - 4, 2, 2); g.fillRect(px - 3, py - 2, 6, 3); g.fillRect(px - 4, py + 1, 8, 2); g.fillRect(px - 1, py + 3, 2, 3); }
    else { g.fillRect(px - 1, py - 4, 3, 3); g.fillRect(px - 4, py - 1, 3, 3); g.fillRect(px + 2, py - 1, 3, 3); g.fillRect(px - 1, py + 1, 2, 4); }
  }
  M.blackjack = function (opts, done) {
    const g0 = R.game, pl = g0.player;
    let net = 0;
    const bets = opts.bets || [10, 25, 50, 100];
    return M.open({
      title: opts.title || 'Blackjack', sub: 'Beat the dealer without going over 21. Dealer stands on 17. Blackjack pays 3 to 2.', w: 240, h: 140,
      buttons: [['bet', `BET $${bets[0]}`], ['deal', 'DEAL', 'big'], ['hit', 'HIT'], ['stand', 'STAND'], ['dbl', 'DOUBLE'], ['quit', 'LEAVE']],
      init(s) { s.deck = deck(); s.bi = 0; s.phase = 'bet'; s.p = []; s.d = []; s.msg(`Cash ${R.fmtMoney(pl.cash)}. Pick a bet and deal.`); },
      draw1(s) { if (s.deck.length < 15) s.deck = deck(); return s.deck.pop(); },
      settle(s) {
        const pv = handVal(s.p), dv = handVal(s.d);
        let win = 0;
        if (pv > 21) win = -s.bet;
        else if (s.p.length === 2 && pv === 21 && !(s.d.length === 2 && dv === 21)) win = s.bet * 1.5;
        else if (dv > 21 || pv > dv) win = s.bet;
        else if (pv < dv) win = -s.bet;
        if (win > 0) { pl.addCash(s.bet + win); g0.audio.sfx('cash'); }
        else if (win === 0) pl.addCash(s.bet);
        net += win;
        s.phase = 'bet';
        s.msg(`${pv > 21 ? 'Bust.' : dv > 21 ? 'Dealer busts!' : win > 0 ? (win === s.bet * 1.5 ? 'BLACKJACK!' : 'You win!') : win < 0 ? 'Dealer wins.' : 'Push.'} ${win > 0 ? '+' : ''}${R.fmtMoney(win)}. Cash ${R.fmtMoney(pl.cash)}.`);
      },
      dealerPlay(s) { while (handVal(s.d) < 17) s.d.push(this.draw1(s)); this.settle(s); },
      press(s, id) {
        if (id === 'quit') return s.finish({ net }, 0);
        if (id === 'bet' && s.phase === 'bet') { s.bi = (s.bi + 1) % bets.length; s.button('bet').textContent = `BET $${bets[s.bi]}`; return; }
        if (id === 'deal' && s.phase === 'bet') {
          const b = bets[s.bi];
          if (!pl.pay(b)) return s.msg('Not enough cash for that bet.');
          s.bet = b; s.p = [this.draw1(s), this.draw1(s)]; s.d = [this.draw1(s), this.draw1(s)]; s.phase = 'play';
          if (handVal(s.p) === 21) { this.dealerPlay(s); return; }
          s.msg(`You have ${handVal(s.p)}. Hit or stand?`);
          return;
        }
        if (s.phase !== 'play') return;
        if (id === 'hit') { s.p.push(this.draw1(s)); const v = handVal(s.p); if (v > 21) this.settle(s); else s.msg(`You have ${v}.`); }
        if (id === 'stand') this.dealerPlay(s);
        if (id === 'dbl' && s.p.length === 2) { if (!pl.pay(s.bet)) return s.msg('Not enough to double.'); s.bet *= 2; s.p.push(this.draw1(s)); if (handVal(s.p) > 21) this.settle(s); else this.dealerPlay(s); }
      },
      draw(g, s) {
        g.fillStyle = FELT; g.fillRect(0, 0, 240, 140);
        g.fillStyle = '#2a6a4a'; g.beginPath(); g.ellipse(120, 0, 130, 70, 0, 0, Math.PI); g.fill();
        txt(g, 'DEALER', 8, 6, { color: '#a8d8b8' });
        s.d.forEach((c, i) => drawCard(g, c, 60 + i * 26, 6, s.phase === 'play' && i === 1));
        txt(g, 'YOU', 8, 78, { color: '#a8d8b8' });
        s.p.forEach((c, i) => drawCard(g, c, 60 + i * 26, 78, false));
        if (s.p.length) txt(g, String(handVal(s.p)), 40, 90, { color: GOLD });
        if (s.phase === 'bet' && s.d.length) txt(g, String(handVal(s.d)), 40, 18, { color: GOLD });
        txt(g, `NET ${net >= 0 ? '+' : ''}${net}`, 232, 128, { align: 'right', color: net >= 0 ? '#a8f0a8' : '#f0a0a0' });
      },
    }, (r) => { if (net) g0.ui.toast(`You ${net > 0 ? 'walk away up' : 'walk away down'} ${R.fmtMoney(Math.abs(net))}.`, net > 0 ? 'good' : 'warn'); if (net > 0) pl.cool = Math.min(100, pl.cool + 8); done && done(net); });
  };

  // ---------------------------------------------------------------- slots
  const SYM = ['7', 'BAR', 'BELL', 'CHERRY', 'LEMON', 'FEDORA'];
  const REEL = ['CHERRY', 'LEMON', 'BAR', 'CHERRY', 'BELL', 'LEMON', 'FEDORA', 'CHERRY', '7', 'LEMON', 'BELL', 'BAR', 'LEMON', 'CHERRY', 'FEDORA', 'LEMON'];
  function drawSym(g, k, x, y) {
    const c = { '7': RED, BAR: INK, BELL: GOLD, CHERRY: '#c8203a', LEMON: '#e8d030', FEDORA: '#3a2a4a' }[k];
    g.fillStyle = c;
    if (k === '7') { g.fillRect(x - 6, y - 8, 12, 3); g.fillRect(x + 2, y - 5, 4, 3); g.fillRect(x, y - 2, 4, 3); g.fillRect(x - 2, y + 1, 4, 7); }
    else if (k === 'BAR') { g.fillRect(x - 9, y - 4, 18, 8); txt(g, 'BAR', x, y - 3, { align: 'center', color: PAPER, shadow: null }); }
    else if (k === 'BELL') { g.fillRect(x - 3, y - 8, 6, 3); g.fillRect(x - 5, y - 5, 10, 8); g.fillRect(x - 7, y + 3, 14, 2); g.fillRect(x - 1, y + 5, 2, 2); }
    else if (k === 'CHERRY') { g.fillRect(x - 6, y, 5, 5); g.fillRect(x + 1, y + 1, 5, 5); g.fillStyle = '#3a8a2a'; g.fillRect(x - 3, y - 7, 1, 7); g.fillRect(x + 3, y - 6, 1, 7); g.fillRect(x - 3, y - 8, 7, 2); }
    else if (k === 'LEMON') { g.fillRect(x - 6, y - 4, 12, 8); g.fillRect(x - 8, y - 2, 16, 4); }
    else { g.fillRect(x - 8, y + 1, 16, 3); g.fillRect(x - 5, y - 6, 10, 7); g.fillStyle = RED; g.fillRect(x - 5, y - 1, 10, 2); }
  }
  M.slots = function (opts, done) {
    const g0 = R.game, pl = g0.player, stake = opts.stake || 5;
    let net = 0;
    const pay = (a) => (a[0] === a[1] && a[1] === a[2] ? { '7': 60, BAR: 25, BELL: 15, FEDORA: 12, CHERRY: 8, LEMON: 5 }[a[0]] : a.filter((k) => k === 'CHERRY').length === 2 ? 2 : a.includes('CHERRY') ? 1 : 0);
    return M.open({
      title: 'One-Armed Bandit', sub: `$${stake} a pull. PULL, then STOP each reel. Three 7s pays 60 to 1.`, w: 240, h: 130,
      buttons: [['pull', 'PULL', 'big'], ['s0', 'STOP'], ['s1', 'STOP'], ['s2', 'STOP'], ['quit', 'LEAVE']],
      init(s) { s.pos = [0, 5, 9]; s.spin = [false, false, false]; s.v = [0, 0, 0]; },
      update(s, dt) {
        for (let i = 0; i < 3; i++) if (s.spin[i]) s.pos[i] = (s.pos[i] + dt * (14 + i * 3)) % REEL.length;
        else s.pos[i] = R.approach ? R.approach(s.pos[i], Math.round(s.pos[i]), dt * 8) : Math.round(s.pos[i]);
        s.flash = Math.max(0, (s.flash || 0) - dt);
      },
      press(s, id) {
        if (id === 'quit') return s.finish({ net }, 0);
        if (id === 'pull') {
          if (s.spin.some((x) => x)) return;
          if (!pl.pay(stake)) return s.msg('Out of cash.');
          net -= stake; s.spin = [true, true, true]; s.msg('Spinning...'); g0.audio.sfx('reload');
          s.auto = setTimeout(() => { for (let i = 0; i < 3; i++) if (s.spin[i]) this.stop(s, i); }, 5000);
          return;
        }
        if (id[0] === 's') this.stop(s, +id[1]);
      },
      stop(s, i) {
        if (!s.spin[i]) return;
        s.spin[i] = false; s.pos[i] = Math.round(s.pos[i] + 0.3) % REEL.length;
        g0.audio.sfx('click');
        if (!s.spin.some((x) => x)) {
          clearTimeout(s.auto);
          const a = s.pos.map((p) => REEL[p % REEL.length]);
          const m = pay(a);
          if (m) { const w = m * stake; pl.addCash(w); net += w; s.flash = 1.5; g0.audio.sfx('cash'); s.msg(`${a.join(' · ')}  WIN ${R.fmtMoney(w)}!`); }
          else s.msg(`${a.join(' · ')}  Nothing.`);
        }
      },
      draw(g, s) {
        g.fillStyle = '#5a1a1a'; g.fillRect(0, 0, 240, 130);
        box(g, 30, 8, 180, 114, '#c8a040');
        g.fillStyle = s.flash > 0 && Math.floor(s.t * 8) % 2 ? '#fff6a0' : '#3a2a10'; g.fillRect(36, 12, 168, 8);
        txt(g, 'LUCKY SEVENS', 120, 12, { align: 'center', color: s.flash > 0 ? RED : GOLD, shadow: null });
        for (let i = 0; i < 3; i++) {
          const x = 44 + i * 54;
          box(g, x, 28, 44, 72, '#fffaf0');
          g.save(); g.beginPath(); g.rect(x, 28, 44, 72); g.clip();
          for (let k = -1; k <= 1; k++) {
            const p = s.pos[i];
            const idx = ((Math.floor(p) + k) % REEL.length + REEL.length) % REEL.length;
            const off = (p - Math.floor(p)) * 24;
            drawSym(g, REEL[idx], x + 22, 64 + k * 24 - off);
          }
          g.restore();
        }
        g.fillStyle = RED; g.fillRect(40, 63, 164, 1);
        txt(g, `NET ${net >= 0 ? '+' : ''}${net}`, 206, 108, { align: 'right', color: INK, shadow: null });
      },
    }, () => { if (net > 0) g0.ui.toast(`Slots: up ${R.fmtMoney(net)}.`, 'good'); done && done(net); });
  };

  // ---------------------------------------------------------------- pool
  M.pool = function (opts, done) {
    const g0 = R.game, pl = g0.player, stake = opts.stake || 10;
    if (!pl.pay(stake)) { g0.ui.toast(`Pool is ${R.fmtMoney(stake)} a rack.`, 'warn'); return done && done(0); }
    const TW = 240, TH = 130, rim = 12, rad = 3.2;
    const pockets = [[rim, rim], [TW / 2, rim - 2], [TW - rim, rim], [rim, TH - rim], [TW / 2, TH - rim + 2], [TW - rim, TH - rim]];
    return M.open({
      title: 'Eight-Ball Hustle', sub: `$${stake} stake. Sink 3 balls in 6 shots to win double. Drag on the table to aim, tap SHOOT when the power bar is where you want it.`, w: TW, h: TH,
      buttons: [['shoot', 'SHOOT', 'big'], ['quit', 'FORFEIT']],
      init(s) {
        s.balls = [{ x: 60, y: TH / 2, vx: 0, vy: 0, c: '#fffaf0', cue: 1 }];
        const cols = ['#e0c020', '#2a4ad8', '#d83a2a', '#6a2a8a', '#e07020', '#1a1a1a'];
        let k = 0;
        for (let r = 0; r < 3; r++) for (let j = 0; j <= r; j++) s.balls.push({ x: 160 + r * 6.2, y: TH / 2 + (j - r / 2) * 6.6, vx: 0, vy: 0, c: cols[k++] });
        s.aim = 0; s.power = 0; s.shots = 6; s.sunk = 0; s.moving = false;
      },
      move(s, x, y) { const c = s.balls[0]; if (!s.moving) s.aim = Math.atan2(y - c.y, x - c.x); },
      down(s, x, y) { this.move(s, x, y); },
      press(s, id) {
        if (id === 'quit') return s.finish(-1, 0);
        if (id === 'shoot' && !s.moving && s.shots > 0) {
          const p = 40 + Math.abs(Math.sin(s.t * 2.2)) * 260;
          const c = s.balls[0];
          c.vx = Math.cos(s.aim) * p; c.vy = Math.sin(s.aim) * p;
          s.shots--; s.moving = true; s.sunkThis = 0; g0.audio.sfx('bump');
        }
      },
      update(s, dt) {
        const steps = 4, h = dt / steps;
        for (let st = 0; st < steps; st++) {
          for (const b of s.balls) {
            if (b.gone) continue;
            b.x += b.vx * h; b.y += b.vy * h;
            const f = Math.pow(0.45, h); b.vx *= f; b.vy *= f;
            if (Math.hypot(b.vx, b.vy) < 4) { b.vx = 0; b.vy = 0; }
            if (b.x < rim + rad) { b.x = rim + rad; b.vx = Math.abs(b.vx) * 0.8; }
            if (b.x > TW - rim - rad) { b.x = TW - rim - rad; b.vx = -Math.abs(b.vx) * 0.8; }
            if (b.y < rim + rad) { b.y = rim + rad; b.vy = Math.abs(b.vy) * 0.8; }
            if (b.y > TH - rim - rad) { b.y = TH - rim - rad; b.vy = -Math.abs(b.vy) * 0.8; }
            for (const [px, py] of pockets) if (Math.hypot(b.x - px, b.y - py) < 7) {
              if (b.cue) { b.x = 60; b.y = TH / 2; b.vx = b.vy = 0; s.msg('Scratch!'); }
              else { b.gone = true; s.sunk++; s.sunkThis++; g0.audio.sfx('thud'); }
            }
          }
          for (let i = 0; i < s.balls.length; i++) for (let j = i + 1; j < s.balls.length; j++) {
            const a = s.balls[i], b = s.balls[j];
            if (a.gone || b.gone) continue;
            const dx = b.x - a.x, dy = b.y - a.y, d = Math.hypot(dx, dy);
            if (d > 0 && d < rad * 2) {
              const nx = dx / d, ny = dy / d, ov = rad * 2 - d;
              a.x -= nx * ov / 2; a.y -= ny * ov / 2; b.x += nx * ov / 2; b.y += ny * ov / 2;
              const rv = (a.vx - b.vx) * nx + (a.vy - b.vy) * ny;
              if (rv > 0) { a.vx -= rv * nx; a.vy -= rv * ny; b.vx += rv * nx; b.vy += rv * ny; }
            }
          }
        }
        if (s.moving && s.balls.every((b) => b.gone || (!b.vx && !b.vy))) {
          s.moving = false;
          if (s.sunk >= 3) { pl.addCash(stake * 2); g0.audio.sfx('cash'); s.msg(`Three down. You take the hustler for ${R.fmtMoney(stake * 2)}.`); s.finish(stake, 1400); }
          else if (!s.shots) { s.msg('Out of shots. The hustler grins and pockets your money.'); s.finish(-stake, 1400); }
          else s.msg(`${s.sunkThis ? 'In!' : 'Nothing.'} Sunk ${s.sunk}/3, ${s.shots} shots left.`);
        }
      },
      draw(g, s) {
        g.fillStyle = WOOD; g.fillRect(0, 0, TW, TH);
        g.fillStyle = '#1f6a44'; g.fillRect(rim, rim, TW - rim * 2, TH - rim * 2);
        g.fillStyle = INK; for (const [px, py] of pockets) { g.beginPath(); g.arc(px, py, 6, 0, 7); g.fill(); }
        for (const b of s.balls) if (!b.gone) { g.fillStyle = INK; g.beginPath(); g.arc(b.x, b.y + 0.6, rad + 0.6, 0, 7); g.fill(); g.fillStyle = b.c; g.beginPath(); g.arc(b.x, b.y, rad, 0, 7); g.fill(); g.fillStyle = 'rgba(255,255,255,0.6)'; g.fillRect(b.x - 1.5, b.y - 1.5, 1, 1); }
        const c = s.balls[0];
        if (!s.moving) {
          g.strokeStyle = 'rgba(255,250,220,0.5)'; g.setLineDash([2, 3]); g.beginPath(); g.moveTo(c.x, c.y); g.lineTo(c.x + Math.cos(s.aim) * 80, c.y + Math.sin(s.aim) * 80); g.stroke(); g.setLineDash([]);
          g.strokeStyle = '#c8a060'; g.lineWidth = 2; g.beginPath(); g.moveTo(c.x - Math.cos(s.aim) * 6, c.y - Math.sin(s.aim) * 6); g.lineTo(c.x - Math.cos(s.aim) * 70, c.y - Math.sin(s.aim) * 70); g.stroke(); g.lineWidth = 1;
          const p = Math.abs(Math.sin(s.t * 2.2));
          box(g, 4, TH - 10, 60, 5, '#3a2010'); g.fillStyle = p > 0.8 ? RED : GOLD; g.fillRect(4, TH - 10, 60 * p, 5);
        }
        txt(g, `SUNK ${s.sunk}/3  SHOTS ${s.shots}`, TW - 6, 1, { align: 'right', color: PAPER });
      },
    }, (r) => { if (r > 0) pl.cool = Math.min(100, pl.cool + 8); done && done(r); });
  };

  // ---------------------------------------------------------------- darts
  M.darts = function (opts, done) {
    const g0 = R.game, pl = g0.player, stake = opts.stake || 10;
    if (!pl.pay(stake)) { g0.ui.toast(`Darts is ${R.fmtMoney(stake)} a game.`, 'warn'); return done && done(0); }
    const NUM = [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5];
    const cx = 90, cy = 66, R0 = 50;
    const score = (x, y) => {
      const d = Math.hypot(x - cx, y - cy) / R0;
      if (d < 0.07) return 50; if (d < 0.16) return 25; if (d > 1) return 0;
      const a = (Math.atan2(y - cy, x - cx) + Math.PI / 2 + Math.PI * 2 + Math.PI / 20) % (Math.PI * 2);
      const n = NUM[Math.floor(a / (Math.PI / 10)) % 20];
      return n * (d > 0.56 && d < 0.64 ? 3 : d > 0.9 ? 2 : 1);
    };
    return M.open({
      title: 'Darts', sub: `$${stake} a game, three rounds of three darts against the regular. Tap THROW when the sight is on target. Drinking makes it wobble.`, w: 240, h: 132,
      buttons: [['throw', 'THROW', 'big'], ['quit', 'FORFEIT']],
      init(s) { s.darts = []; s.me = 0; s.them = 0; s.round = 1; s.n = 0; },
      aim(s) { const wob = 14 + pl.drunk * 40; return [cx + Math.sin(s.t * 1.7) * wob + Math.sin(s.t * 4.3) * wob * 0.3, cy + Math.cos(s.t * 1.3) * wob * 0.8 + Math.sin(s.t * 3.1) * wob * 0.3]; },
      press(s, id) {
        if (id === 'quit') return s.finish(-stake, 0);
        if (id !== 'throw' || s.wait) return;
        const [x, y] = this.aim(s);
        const jx = x + (Math.random() - 0.5) * 4, jy = y + (Math.random() - 0.5) * 4;
        const sc = score(jx, jy);
        s.darts.push({ x: jx, y: jy }); s.me += sc; s.n++;
        g0.audio.sfx('punch');
        s.msg(sc === 50 ? 'BULLSEYE!' : sc ? `${sc}!` : 'Missed the board.');
        if (s.n === 3) {
          s.wait = true;
          setTimeout(() => {
            const them = Math.round(20 + Math.random() * 70);
            s.them += them; s.darts = []; s.n = 0; s.wait = false;
            if (s.round === 3) {
              const win = s.me > s.them;
              if (win) { pl.addCash(stake * 2); g0.audio.sfx('cash'); }
              s.msg(`The regular throws ${them}. Final: you ${s.me}, him ${s.them}. ${win ? `You win ${R.fmtMoney(stake * 2)}!` : 'He wins.'}`);
              s.finish(win ? stake : -stake, 1600);
            } else { s.msg(`The regular throws ${them}. Round ${s.round + 1}.`); s.round++; }
          }, 900);
        }
      },
      draw(g, s) {
        g.fillStyle = '#3a2418'; g.fillRect(0, 0, 240, 132);
        g.fillStyle = INK; g.beginPath(); g.arc(cx, cy, R0 + 4, 0, 7); g.fill();
        for (let i = 0; i < 20; i++) {
          const a0 = (i / 20) * Math.PI * 2 - Math.PI / 2 - Math.PI / 20, a1 = a0 + Math.PI / 10;
          for (const [r1, r2, c1, c2] of [[0.9, 1, RED, GREEN], [0.64, 0.9, '#1a1a1a', '#e8dcc0'], [0.56, 0.64, RED, GREEN], [0.16, 0.56, '#1a1a1a', '#e8dcc0']]) {
            g.fillStyle = i % 2 ? c1 : c2; g.beginPath(); g.arc(cx, cy, r2 * R0, a0, a1); g.arc(cx, cy, r1 * R0, a1, a0, true); g.fill();
          }
          txt(g, String(NUM[i]), cx + Math.cos(a0 + Math.PI / 20) * (R0 + 10), cy + Math.sin(a0 + Math.PI / 20) * (R0 + 10) - 3, { align: 'center', color: PAPER, shadow: null });
        }
        g.fillStyle = GREEN; g.beginPath(); g.arc(cx, cy, 0.16 * R0, 0, 7); g.fill();
        g.fillStyle = RED; g.beginPath(); g.arc(cx, cy, 0.07 * R0, 0, 7); g.fill();
        for (const d of s.darts) { g.fillStyle = GOLD; g.fillRect(d.x - 1, d.y - 1, 2, 2); g.fillStyle = INK; g.fillRect(d.x + 1, d.y - 4, 1, 4); }
        if (!s.wait) { const [x, y] = this.aim(s); g.strokeStyle = PAPER; g.beginPath(); g.arc(x, y, 4, 0, 7); g.stroke(); g.fillStyle = PAPER; g.fillRect(x - 0.5, y - 7, 1, 3); g.fillRect(x - 0.5, y + 4, 1, 3); g.fillRect(x - 7, y - 0.5, 3, 1); g.fillRect(x + 4, y - 0.5, 3, 1); }
        box(g, 170, 10, 64, 60, '#2a1a10');
        txt(g, `ROUND ${s.round}/3`, 202, 14, { align: 'center', color: GOLD });
        txt(g, `YOU  ${s.me}`, 176, 30); txt(g, `HIM  ${s.them}`, 176, 44);
        txt(g, `DART ${s.n + 1}/3`, 176, 58, { color: '#a89878' });
      },
    }, (r) => done && done(r));
  };

  // ---------------------------------------------------------------- craps
  M.dice = function (opts, done) {
    const g0 = R.game, pl = g0.player, stake = opts.stake || 10;
    let net = 0;
    const pips = { 1: [[0, 0]], 2: [[-1, -1], [1, 1]], 3: [[-1, -1], [0, 0], [1, 1]], 4: [[-1, -1], [1, -1], [-1, 1], [1, 1]], 5: [[-1, -1], [1, -1], [0, 0], [-1, 1], [1, 1]], 6: [[-1, -1], [1, -1], [-1, 0], [1, 0], [-1, 1], [1, 1]] };
    return M.open({
      title: 'Shoot Dice', sub: `$${stake} a come-out. Hold SHAKE and let go to roll. 7 or 11 wins, 2, 3 or 12 loses, anything else is your point: hit it again before a 7.`, w: 240, h: 110,
      buttons: [['shake', 'SHAKE', 'big'], ['quit', 'WALK']],
      init(s) { s.d = [3, 4]; s.point = 0; s.shaking = 0; s.roll = 0; s.bet = 0; },
      update(s, dt) {
        if (s.shaking) s.shaking += dt;
        if (s.roll > 0) { s.roll -= dt; s.d = [1 + Math.floor(Math.random() * 6), 1 + Math.floor(Math.random() * 6)]; if (s.roll <= 0) this.land(s); }
      },
      press(s, id) {
        if (id === 'quit') return s.finish({ net }, 0);
        if (id === 'shake' && s.roll <= 0) {
          if (!s.point) { if (!pl.pay(stake)) return s.msg('No cash, no dice.'); net -= stake; s.bet = stake; }
          s.shaking = 0.01;
        }
      },
      release(s, id) { if (id === 'shake' && s.shaking) { s.shaking = 0; s.roll = 0.8; g0.audio.sfx('thud'); } },
      land(s) {
        const t = s.d[0] + s.d[1];
        const win = () => { pl.addCash(s.bet * 2); net += s.bet * 2; g0.audio.sfx('cash'); s.point = 0; };
        if (!s.point) {
          if (t === 7 || t === 11) { win(); s.msg(`${t}! Natural. You win ${R.fmtMoney(s.bet)}.`); }
          else if (t === 2 || t === 3 || t === 12) s.msg(`${t}. Craps. You lose.`);
          else { s.point = t; s.msg(`Your point is ${t}. Roll it again before a 7.`); }
        } else if (t === s.point) { win(); s.msg(`${t}! You made your point.`); }
        else if (t === 7) { s.point = 0; s.msg('Seven out. The alley takes your money.'); }
        else s.msg(`${t}. Still looking for ${s.point}.`);
      },
      draw(g, s) {
        g.fillStyle = '#4a4038'; g.fillRect(0, 0, 240, 110);
        g.fillStyle = '#3a322a'; for (let k = 0; k < 240; k += 12) g.fillRect(k, 0, 1, 110);
        const sh = s.shaking ? Math.sin(s.t * 40) * 3 : 0;
        s.d.forEach((v, i) => {
          const x = 90 + i * 40 + sh, y = 44 + (s.roll > 0 ? Math.sin(s.t * 30 + i) * 6 : 0);
          box(g, x - 12, y - 12, 24, 24, '#fffaf0');
          g.fillStyle = v === 1 ? RED : INK;
          for (const [px, py] of pips[v]) g.fillRect(x + px * 6 - 2, y + py * 6 - 2, 4, 4);
        });
        txt(g, s.point ? `POINT ${s.point}` : 'COME-OUT ROLL', 120, 80, { align: 'center', color: GOLD });
        txt(g, `NET ${net >= 0 ? '+' : ''}${net}`, 234, 96, { align: 'right', color: net >= 0 ? '#a8f0a8' : '#f0a0a0' });
      },
    }, () => done && done(net));
  };
})();
