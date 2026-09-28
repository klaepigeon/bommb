// RHAPSODY — the envelope. Every precinct has cops who'd like a better car. Buy a beat
// cop a coffee with a fifty folded under the cup and he starts missing things. Get enough
// of them and the captain will see you, and a captain loses files, warns you before the
// raid, and knows who's been talking to the feds. It all costs money every week, and
// Internal Affairs is always looking for a headline. A cop who gets burned for you has a
// choice to make about who he's more afraid of.
'use strict';
(function () {
  const TS = R.TILE;
  const G = () => R.game;
  const PR = (R.payroll = {});
  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
  const BEAT = 40, CAPTAIN = 250;
  const SERIOUS = { copAssault: 1, copMurder: 1, heist: 1, jailbreak: 1, rico: 1 };

  PR.state = function () { const st = R.shark.street(); return (st.pay = st.pay || { jur: {}, due: null, paid: 0, sweeps: 0, looked: 0 }); };
  PR.jur = function (j) { const s = this.state(); return (s.jur[j] = s.jur[j] || { beats: [], captain: null }); };
  PR.weekly = function () { let n = 0; for (const j in this.state().jur) { const r = this.state().jur[j]; n += r.beats.length * BEAT + (r.captain != null ? CAPTAIN : 0); } return n; };
  PR.hasCaptain = function (j) { const r = this.state().jur[j]; return !!(r && r.captain != null); };
  PR.anyCaptain = function () { const s = this.state(); return Object.keys(s.jur).find((j) => s.jur[j].captain != null) || null; };
  PR.lookAway = function (j) { const r = this.state().jur[j]; if (!r) return 0; return Math.min(0.85, r.beats.length * 0.14 + (r.captain != null ? 0.3 : 0)); };
  // a real officer from that precinct's roster
  PR.officer = function (j, taken) {
    const g = G();
    const pool = g.pop.people.filter((p) => p.alive && p.role === 'cop' && (p.city === j || j === 'county') && !taken.includes(p.id));
    return pool.length ? R.rng.pick(pool) : null;
  };

  // ---------------------------------------------------------------- a word with an officer
  PR.copOpts = function (h, opts) {
    const g = G(), pl = g.player;
    if (!h.cop || h.detectiveFor || g.law.incident || h.hostile) return;
    const j = g.law.jurAt(h.x, h.y), r = this.jur(j);
    if (h.onPayroll) { opts.unshift({ label: '"Everything good, officer?"', small: 'He\'s on your payroll', fn: () => g.actors.say(h, R.rng.pick(['Quiet night. Keep it that way.', 'Didn\'t see you. Never do.', 'Captain says hello.'])) }); return; }
    if (r.beats.length >= 6) return;
    opts.unshift({ label: `"Let me buy you a coffee, officer."`, small: `Bribe: ${R.fmtMoney(BEAT)} now and every week`, cls: 'go', fn: () => {
      const chance = 0.35 + pl.rep.infamy / 250 + g.jobs.rank() * 0.08 + (h.tr && h.tr.greedy ? h.tr.greedy * 0.3 : 0.1) - (g.law.totalBounty() > 0 ? 0.15 : 0);
      if (R.rng() < chance) {
        if (!pl.pay(BEAT)) return g.ui.toast('You don\'t have the fifty.');
        const p = this.officer(j, r.beats.concat(r.captain != null ? [r.captain] : []));
        r.beats.push(p ? p.id : -1 - r.beats.length);
        h.onPayroll = true;
        if (p) h.strangerName = 'Officer ' + p.last;
        if (this.state().due == null) this.state().due = g.pop.day + 7;
        g.actors.say(h, R.rng.pick(['Cream, two sugars. I\'ll be seeing you around.', 'Nice doing business. I work this beat Tuesdays.', 'You didn\'t get this from me.']));
        g.ui.toast(`${h.strangerName || 'The officer'} is on your payroll in ${g.law.jurName(j)}. ${R.fmtMoney(BEAT)} a week.`, 'good');
      } else {
        g.actors.say(h, R.rng.pick(['Are you trying to bribe a police officer? Beat it before I change my mind.', 'I\'m gonna pretend I didn\'t hear that.', 'Put your wallet away, pal.']));
        g.law.bounty[j] = (g.law.bounty[j] || 0) + 10;
        g.ui.toast('He\'s straight. That cost you a $10 bounty.', 'warn');
      }
    } });
  };

  // ---------------------------------------------------------------- at the precinct
  PR.stationOpts = function (b, opts) {
    const g = G(), pl = g.player, ui = g.ui;
    if (b.type !== 'police') return;
    const j = b.cityId, r = this.jur(j);
    if (r.captain == null) {
      const ok = r.beats.length >= 2 || g.jobs.rank() >= 2;
      opts.push({ label: 'Ask to see the captain', small: ok ? `Put the precinct on your payroll: ${R.fmtMoney(CAPTAIN)} a week` : 'Nobody here knows you yet. Get two beat cops on the envelope first', fn: () => {
        if (!ok) return ui.toast('"The captain\'s busy." He\'s always busy, for strangers.');
        const p = this.officer(j, r.beats);
        const name = p ? 'Captain ' + p.last : 'The captain';
        ui.choice(`${name} closes the blinds`, [
          { label: `Slide over the envelope (${R.fmtMoney(CAPTAIN)})`, small: 'Files go missing. Raids get warned. Rats get named', cls: 'go', fn: () => {
            if (!pl.pay(CAPTAIN)) return ui.toast('Short. He doesn\'t take IOUs.');
            r.captain = p ? p.id : -99; r.capName = name;
            if (this.state().due == null) this.state().due = g.pop.day + 7;
            ui.toast(`${name} is yours. Cases in ${g.law.jurName(j)} slow down, and he'll warn you when they're close.`, 'good');
          } },
          { label: 'Think better of it', fn: () => {} },
        ]);
      } });
    } else {
      opts.push({ label: `A word with ${r.capName || 'the captain'}`, small: 'He works for you', fn: () => this.captainMenu(j) });
    }
  };
  PR.captainMenu = function (j) {
    const g = G(), pl = g.player, ui = g.ui, r = this.jur(j), CS = R.cases;
    const cases = CS ? CS.open().filter((c) => c.jur === j && c.status === 'open' && c.type !== 'rico') : [];
    const bnt = g.law.bounty[j] || 0;
    const opts = cases.map((c) => ({ label: `Lose the file on the ${c.name.toLowerCase()} ($300)`, small: `${Math.round(c.progress)}% solved. Knocks it back hard`, fn: () => { if (!pl.pay(300)) return ui.toast('Not enough.'); c.progress = Math.max(0, c.progress - 45); c.coldH += 12; ui.toast('A box of evidence goes to the wrong warehouse.', 'good'); } }));
    if (bnt) opts.push({ label: `Tear up the warrant (${R.fmtMoney(Math.ceil(bnt * 0.5))})`, small: 'Half your bounty here, off the books', fn: () => { if (!pl.pay(Math.ceil(bnt * 0.5))) return ui.toast('Not enough.'); g.law.bounty[j] = 0; ui.toast('"What warrant?"', 'good'); } });
    if (R.rat && R.rat.active()) opts.push({ label: '"Anybody been talking to the feds?"', small: 'He hears things', fn: () => R.rat.captainTip(j) });
    opts.push({ label: 'Cut him loose', small: 'Stops the weekly envelope', fn: () => { const pid = r.captain; r.captain = null; if (R.rat && pid >= 0) R.rat.pressure(pid, 3); ui.toast('He looks at you a long time. "Your call."', 'warn'); } });
    opts.push({ label: 'Leave', fn: () => {} });
    ui.choice(`${r.capName || 'The captain'} · ${g.law.jurName(j)}`, opts);
  };

  // ---------------------------------------------------------------- effects
  PR.wrapLaw = function () {
    const LP = R.Law.prototype, si = LP.startIncident;
    LP.startIncident = function (crime, cop) {
      const g = this.game;
      if (cop && !this.incident && !SERIOUS[crime.type] && R.rng() < PR.lookAway(crime.jur)) {
        PR.state().looked++;
        cop.brandishT = 30;
        g.actors.say(cop, R.rng.pick(['...I didn\'t see nothing.', 'Huh. Look at the time.', 'Not my beat.']));
        g.ui.toast('The officer looks at his shoes. That\'s what the envelope is for.', 'good');
        return;
      }
      return si.call(this, crime, cop);
    };
    const ab = LP.addBounty;
    LP.addBounty = function (crime) {
      if (PR.hasCaptain(crime.jur) && !SERIOUS[crime.type]) { const b = crime.bounty; crime.bounty = Math.round(b * 0.6); const r = ab.call(this, crime); crime.bounty = b; return r; }
      return ab.call(this, crime);
    };
    const CS = R.cases, weigh = CS.weigh, hour = CS.hour;
    CS.weigh = function (c) {
      const parts = weigh.call(this, c);
      if (c.type !== 'rico' && c.type !== 'tax' && PR.hasCaptain(c.jur)) {
        const sum = parts.reduce((a, p) => a + Math.max(0, p.v), 0);
        if (sum > 0) parts.push({ k: 'captain', v: -sum * 0.4, label: `${PR.jur(c.jur).capName || 'Your captain'} keeps misplacing the paperwork` });
      }
      return parts;
    };
    CS.hour = function () {
      hour.call(this);
      for (const c of this.open()) {
        if (c.tipped || c.progress < 70 || !PR.hasCaptain(c.jur)) continue;
        c.tipped = true;
        G().ui.toast(`${PR.jur(c.jur).capName}: "The ${c.name.toLowerCase()} file is getting thick. Do something about it."`, 'warn');
      }
    };
  };

  // ---------------------------------------------------------------- payday, and Internal Affairs
  PR.daily = function () {
    const g = G(), pl = g.player, s = this.state();
    if (s.due == null || g.pop.day < s.due) return;
    const cost = this.weekly();
    if (!cost) { s.due = null; return; }
    s.due = g.pop.day + 7;
    const st = pl.stash || { cash: 0 };
    if (pl.cash + st.cash >= cost) {
      const a = Math.min(pl.cash, cost); pl.cash -= a; if (cost > a) st.cash -= cost - a;
      s.paid += cost;
      g.ui.toast(`The weekly envelopes went out: ${R.fmtMoney(cost)} to your friends in blue.`);
    } else {
      // nobody works for free
      for (const j in s.jur) { const r = s.jur[j]; for (const pid of r.beats.concat(r.captain != null ? [r.captain] : [])) if (R.rat && pid >= 0) R.rat.pressure(pid, 2); r.beats = []; r.captain = null; }
      g.ui.story('NO ENVELOPE', 'You missed the week. Your friends in the department are not your friends any more, and they know a lot about you.');
      return;
    }
    // Internal Affairs
    for (const j in s.jur) {
      const r = s.jur[j], n = r.beats.length + (r.captain != null ? 3 : 0);
      if (!n) continue;
      if (R.rng() < 0.012 * n + pl.rep.infamy / 3000) {
        s.sweeps++;
        const burned = r.captain != null ? r.captain : R.rng.pick(r.beats);
        const name = r.captain != null ? r.capName : 'a patrolman';
        g.pop.addNews(j === 'county' ? 'port' : j, `INTERNAL AFFAIRS SWEEP: ${name} and ${Math.max(0, r.beats.length - (r.captain != null ? 0 : 1))} officers suspended in ${g.law.jurName(j)}. "The rot runs deep," says the commissioner.`);
        g.ui.story('INTERNAL AFFAIRS', `IA came through the ${g.law.jurName(j)} precinct like a fire. Everybody you paid there is suspended.\n\n${name} is looking at prison time. He'd very much like a deal.`);
        if (R.rat && burned >= 0) R.rat.pressure(burned, 8);
        r.beats = []; r.captain = null;
      }
    }
  };

  // ---------------------------------------------------------------- walking the beat
  // A cop or two walks the sidewalks downtown by day: the ones you can buy a coffee.
  PR.update = function (dt) {
    const g = G(), pl = g.player, TS = R.TILE, w = g.world;
    this.t = (this.t == null ? 5 : this.t) - dt;
    if (this.t > 0) return;
    this.t = 15;
    if (pl.room || pl.inCar || (R.opening && R.opening.active) || g.law.incident) return;
    const hr = g.clock.hour(), city = w.cityAt((pl.x / TS) | 0, (pl.y / TS) | 0);
    if (!city || hr < 7 || hr > 21) return;
    const want = city.id === 'avalon' ? 2 : 1;
    const have = g.actors.list.filter((a) => a.footBeat && !a.dead && !a.removed && R.dist(a.x, a.y, pl.x, pl.y) < TS * 34).length;
    if (have >= want) return;
    const sp = w.findNear((pl.x / TS) | 0, (pl.y / TS) | 0, 16, 26, (x, y) => w.t(x, y) === R.data.T.WALK && !w.solidPed(x, y));
    if (!sp || g.cam.onScreen(sp.x * TS + 8, sp.y * TS + 8, 30)) return;
    const h = g.actors.makeHuman(sp.x * TS + 8, sp.y * TS + 8, { cop: true, role: 'cop', city: city.id });
    h.look = g.pop.makeLook(R.mulberry(R.rng.int(0, 1e9)), { fem: R.rng.chance(0.3), age: 30 + R.rng.int(0, 20), role: 'cop', city: city.id });
    g.actors.arm(h, 'revolver'); h.weaponOut = false;
    h.footBeat = true;
    g.actors.startWander(h);
  };

  PR.html = function () {
    const g = G(), s = this.state(), rows = Object.keys(s.jur).filter((j) => s.jur[j].beats.length || s.jur[j].captain != null);
    if (!rows.length) return '';
    let h = '<div class="sect">On the payroll</div>';
    for (const j of rows) { const r = s.jur[j]; h += `<p>• <b>${esc(g.law.jurName(j))}</b>: ${r.beats.length} beat cop${r.beats.length === 1 ? '' : 's'}${r.captain != null ? ` and <b>${esc(r.capName)}</b>` : ''} · they look away ${Math.round(this.lookAway(j) * 100)}% of the time</p>`; }
    h += `<p><small>${R.fmtMoney(this.weekly())} a week, next envelope on day ${(s.due || 0) + 1}. Paid so far ${R.fmtMoney(s.paid)}. They looked the other way ${s.looked} time${s.looked === 1 ? '' : 's'}. Internal Affairs sweeps: ${s.sweeps}.</small></p>`;
    return h;
  };

  PR.init = function (g) {
    if (this.wrapped) return;
    this.wrapped = true;
    this.wrapLaw();
    const tree = R.dialog.tree;
    R.dialog.tree = function (h) { const t = tree.call(this, h); if (t && t.options) PR.copOpts(h, t.options); return t; };
    const U = R.UI.prototype, io = U.interiorOptions;
    U.interiorOptions = function (b) { const o = io.call(this, b); PR.stationOpts(b, o); return o; };
    const J = R.Jobs.prototype, jd = J.daily;
    J.daily = function () { jd.call(this); PR.daily(); };
    const html = R.cases.html;
    R.cases.html = function () { return html.call(this) + PR.html(); };
    const LP = R.Law.prototype;
    if (!LP.CRIMES.rico) LP.CRIMES.rico = { name: 'Racketeering', bounty: 200, lvl: 2 };
    if (!LP.CRIMES.hijack) LP.CRIMES.hijack = { name: 'Hijacking', bounty: 40, lvl: 2 };
  };
})();
