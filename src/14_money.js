// RHAPSODY — dirty money. Cash from crime is dirty: robbery, heists, ransoms, dealing,
// muggings, the families' envelopes. Spend a lot of it at once and people notice, and
// so does the Treasury. Clean money comes from businesses you own, lucky nights at the
// tables, and laundering: run it through the books of a business you own, or buy chips
// and cash out at a casino. Let suspicion climb and the auditors come knocking.
'use strict';
(function () {
  const TS = R.TILE;
  const G = () => R.game;
  const MN = (R.money = { cleanDepth: 0 });
  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);

  MN.state = function () { const pl = G().player; return (pl.money = pl.money || { dirty: 0, susp: 0, warned: 0, audits: 0, washed: 0 }); };
  MN.dirty = function () { const s = this.state(), pl = G().player; if (s.dirty > pl.cash) s.dirty = Math.max(0, pl.cash); return s.dirty; };
  MN.clean = function (fn) { this.cleanDepth++; try { return fn(); } finally { this.cleanDepth--; } };
  MN.raise = function (n, why) {
    const s = this.state(), g = G();
    const was = s.susp;
    s.susp = R.clamp(s.susp + n, 0, 100);
    if (why && Math.floor(was / 10) !== Math.floor(s.susp / 10)) g.ui.toast(`${why} (Treasury suspicion ${Math.round(s.susp)}%)`, 'warn');
  };

  // ---------------------------------------------------------------- earning and spending
  MN.wrap = function () {
    const PP = R.Player.prototype, baseAdd = PP.addCash, basePay = PP.pay;
    PP.addCash = function (n, clean) {
      baseAdd.call(this, n);
      if (n > 0 && !clean && !MN.cleanDepth && this === G().player) MN.state().dirty += n;
    };
    PP.pay = function (n) {
      const s = MN.state(), cash = this.cash, dirty = MN.dirty();
      if (!basePay.call(this, n)) return false;
      const share = cash > 0 ? dirty / cash : 0, spent = n * share;
      s.dirty = Math.max(0, s.dirty - spent);
      // crumpled twenties by the fistful draw looks
      if (n >= 250 && spent > 120) MN.raise(spent / 45, `You paid ${R.fmtMoney(n)} in crumpled bills. People remember that.`);
      return true;
    };
    // clean sources
    const ES = R.realty || R.estate;
    if (ES && ES.daily) { const d = ES.daily; ES.daily = function () { return MN.clean(() => d.apply(this, arguments)); }; }
    if (ES && ES.income) { const inc = ES.income; ES.income = function (b) { return b.raidedUntil && G().pop.day < b.raidedUntil ? 0 : inc.call(this, b); }; }
    const U = R.UI.prototype, gamble = U.gamble;
    U.gamble = function () { return MN.clean(() => gamble.apply(this, arguments)); };
    const io = U.interiorOptions;
    U.interiorOptions = function (b) { const o = io.call(this, b); MN.washOpts(b, o); return o; };
    // the stash keeps track of which of its dollars are dirty
    if (ES && ES.openStash) {
      const os = ES.openStash;
      ES.openStash = function (g) {
        const pl = g.player, st = (pl.stash = pl.stash || { cash: 0, loot: {} });
        const c0 = pl.cash, s0 = st.cash, d0 = MN.dirty();
        const choice = g.ui.choice;
        g.ui.choice = function (title, opts) {
          g.ui.choice = choice;
          const wrap = (o) => Object.assign({}, o, { fn: () => { const r = o.fn && o.fn(); MN.settleStash(pl, st, c0, s0, d0); return r; } });
          return choice.call(this, title, opts.map(wrap));
        };
        return os.call(this, g);
      };
    }
  };
  MN.settleStash = function (pl, st, c0, s0, d0) {
    const s = this.state(), moved = s0 - st.cash; // + taken out, − put in
    st.dirty = st.dirty || 0;
    if (moved < 0) { const n = -moved, d = Math.min(d0, n); st.dirty += d; s.dirty = Math.max(0, d0 - d); }
    else if (moved > 0) { const d = Math.min(st.dirty, moved); s.dirty = d0 + d; st.dirty -= d; }
  };

  // ---------------------------------------------------------------- laundering
  const WASH_FEE = { laundry: 0.05, arcade: 0.08, club: 0.08, bar: 0.1, diner: 0.1 };
  MN.washOpts = function (b, opts) {
    const g = G(), pl = g.player, s = this.state(), ES = R.realty || R.estate;
    const dirty = this.dirty();
    const day = g.pop.day;
    const own = (pl.properties || []).includes(b.id) && ES && ES.isBiz && ES.isBiz(b);
    if (own) {
      if (b.washDay !== day) { b.washDay = day; b.washed = 0; }
      const cap = Math.round(Math.max(150, (ES.income(b) || 60) * 4) * (b.reno ? 1.5 : 1)) - b.washed;
      const fee = WASH_FEE[b.type] || 0.12;
      if (b.raidedUntil && day < b.raidedUntil) { opts.unshift({ label: 'The books are sealed', small: `Treasury raid. Reopens on day ${b.raidedUntil + 1}`, fn: () => {} }); return; }
      opts.unshift({ label: 'Run cash through the books', small: dirty > 0 ? `${R.fmtMoney(Math.min(dirty, Math.max(0, cap)))} of your ${R.fmtMoney(dirty)} dirty · ${Math.round(fee * 100)}% goes to the bookkeeper · ${R.fmtMoney(Math.max(0, cap))} left today` : 'Your cash is clean', cls: 'go', fn: () => this.wash(Math.min(dirty, Math.max(0, cap)), fee, b, `${b.name} rings up ${'a very good week'}`) });
    }
    if (b.type === 'casino') {
      if (s.chipDay !== day) { s.chipDay = day; s.chips = 0; }
      const cap = 600 - s.chips;
      opts.push({ label: 'Buy chips, play a hand, cash out', small: dirty > 0 ? `Launder up to ${R.fmtMoney(Math.min(dirty, Math.max(0, cap)))} today · the house keeps 20%` : 'Your cash is clean', fn: () => { const n = Math.min(dirty, Math.max(0, cap)); s.chips += n; this.wash(n, 0.2, null, 'The cashier counts out fresh hundreds'); } });
    }
  };
  MN.wash = function (n, fee, b, line) {
    const g = G(), pl = g.player, s = this.state();
    n = Math.floor(n);
    if (n <= 0) return g.ui.toast(this.dirty() > 0 ? 'Not today. Come back tomorrow.' : 'Your money\'s already clean.');
    const cut = Math.ceil(n * fee);
    pl.cash -= cut;
    s.dirty = Math.max(0, s.dirty - n);
    s.washed += n - cut;
    if (b) b.washed = (b.washed || 0) + n;
    this.raise(n / 600);
    g.audio.sfx('cash');
    g.ui.toast(`${line}. ${R.fmtMoney(n - cut)} clean, ${R.fmtMoney(cut)} in fees.`, 'good');
  };

  // ---------------------------------------------------------------- the Treasury
  MN.daily = function () {
    const g = G(), pl = g.player, s = this.state();
    s.susp = Math.max(0, s.susp - 2);
    // walking around with a fortune in dirty cash is its own problem
    if (this.dirty() > 3000) this.raise(2, 'Word gets around about the roll in your pocket.');
    if (s.susp >= 50 && s.warned < 1) { s.warned = 1; g.pop.addNews('avalon', 'Treasury agents seen asking questions at banks and car dealerships. "Routine," says a spokesman.'); g.ui.toast('The Treasury is asking about big cash purchases. Launder your money.', 'warn'); }
    if (s.susp >= 75 && R.rng() < 0.4) this.audit();
  };
  MN.audit = function () {
    const g = G(), pl = g.player, s = this.state(), ES = R.realty || R.estate;
    s.audits++;
    const biz = (pl.properties || []).map((id) => g.world.buildings[id]).filter((b) => b && !b.destroyed && ES && ES.isBiz(b));
    if (biz.length) { const b = R.rng.pick(biz); b.raidedUntil = g.pop.day + 3; g.pop.addNews(b.city.id, `Treasury agents carried boxes of records out of ${b.name} yesterday. The owner could not be reached.`); }
    const total = pl.cash + (pl.stash ? pl.stash.cash : 0);
    const fine = Math.max(200, Math.round(total * 0.2));
    g.ui.story('AUDIT', `Two men in grey suits and a letter from the Treasury. They'd like to see receipts for your lifestyle.${biz.length ? '\n\nThey sealed the books at one of your businesses for three days.' : ''}`);
    setTimeout(() => g.ui.choice('The Treasury wants answers', [
      { label: `Pay the settlement (${R.fmtMoney(fine)})`, small: 'Suspicion drops a lot', fn: () => { const fromPocket = Math.min(pl.cash, fine); pl.cash -= fromPocket; if (fine > fromPocket && pl.stash) pl.stash.cash = Math.max(0, pl.stash.cash - (fine - fromPocket)); s.susp = Math.max(0, s.susp - 45); g.ui.toast('Paid. The agents leave with a handshake and a warning.', 'good'); } },
      { label: 'Hire a crooked accountant ($400)', small: 'Clean money only. Cooks the books', fn: () => { const clean = pl.cash - this.dirty(); if (clean < 400) return g.ui.toast('He only takes clean money. You don\'t have enough.', 'warn'); pl.cash -= 400; s.susp = Math.max(0, s.susp - 60); g.ui.toast('Twelve shoeboxes of receipts appear overnight. The agents are baffled.', 'good'); } },
      { label: 'Tell them to get lost', small: 'They open a tax case', fn: () => this.taxCase() },
    ]), 400);
  };
  MN.taxCase = function () {
    const g = G(), CS = R.cases, s = CS.state();
    if (CS.open().some((c) => c.type === 'tax')) return;
    const c = { id: s.next++, type: 'tax', name: 'Tax Evasion', jur: 'avalon', day: g.pop.day, t: g.clock.t, lastT: g.clock.t, progress: 30, status: 'open', det: 'Agent Milton Kress, U.S. Treasury', witnesses: [], coldH: 0, masked: true, face: {}, clothes: {}, bloody: false, bounty: 150, where: 'New Avalon' };
    s.list.unshift(c);
    g.ui.toast('The Treasury opened a tax case. It\'s in your Heat tab.', 'bad');
  };
  // the books count as evidence in a tax case
  MN.wrapCases = function () {
    const CS = R.cases, weigh = CS.weigh, html = CS.html;
    CS.weigh = function (c) {
      if (c.type !== 'tax') return weigh.call(this, c);
      const s = MN.state();
      return [{ k: 'books', v: s.susp / 20, label: `The books: ${s.susp > 60 ? 'a lot of money with no explanation' : s.susp > 25 ? 'some spending they can\'t account for' : 'mostly in order'}`, fix: s.susp > 25 ? 'Launder your cash and stop paying for big things with it.' : null }];
    };
    CS.html = function () {
      const s = MN.state(), pl = G().player, dirty = MN.dirty(), st = pl.stash || { cash: 0 };
      const money = `<div class="sect">Your money</div><p>On you: <b>${R.fmtMoney(pl.cash)}</b>${dirty ? ` <span style="color:var(--red)">(${R.fmtMoney(dirty)} dirty)</span>` : ' (clean)'} · in your stash: ${R.fmtMoney(st.cash)}${st.dirty ? ` (${R.fmtMoney(Math.round(st.dirty))} dirty)` : ''}</p><p>Treasury suspicion</p><div class="meter" style="width:100%"><i style="width:${Math.round(s.susp)}%;background:${s.susp > 70 ? 'var(--red)' : s.susp > 40 ? 'var(--mustard)' : 'var(--good)'}"></i></div><p style="font-size:13px;color:var(--brown)">Crime pays in dirty cash. Big purchases with it raise suspicion. Launder it through a business you own or at a casino. Laundered so far: ${R.fmtMoney(Math.round(s.washed))}.</p><div class="sect">Open cases</div>`;
      return money + html.call(this);
    };
  };
  MN.init = function (g) {
    if (this.wrapped) return;
    this.wrapped = true;
    this.wrap();
    this.wrapCases();
    const LP = R.Law.prototype;
    if (!LP.CRIMES.tax) LP.CRIMES.tax = { name: 'Tax Evasion', bounty: 150, lvl: 1 };
    const J = R.Jobs.prototype, jd = J.daily;
    J.daily = function () { jd.call(this); MN.daily(); };
  };
})();
