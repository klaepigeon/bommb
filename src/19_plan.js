// RHAPSODY — the plan board. Big jobs get planned in the back room: pick a bank or a
// casino, case it for the shift change, choose the approach and the way into the vault,
// then put your crew on the roles. A wireman has the alarm cut before you're downstairs, a
// lookout buys time on the silent alarm, muscle comes down with you, and a driver waits at
// the door with the engine running. The take is split, and the crew remember a good score.
'use strict';
(function () {
  const D = R.data, TS = R.TILE;
  const G = () => R.game;
  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
  const PB = (R.plan = {});
  const ROLES = {
    wireman: { name: 'Wireman', does: 'Cuts the alarm panel before you go down', cut: 0.1 },
    lookout: { name: 'Lookout', does: 'Longer grace on the stairs; the silent alarm takes 30s longer', cut: 0.08 },
    muscle: { name: 'Muscle', does: 'Comes downstairs with you and fights the guards', cut: 0.12 },
    driver: { name: 'Driver', does: 'Waits at the door with a fast car; you lose the cops sooner', cut: 0.1 },
  };
  const APPROACH = {
    quiet: { name: 'Quiet', does: 'After hours. Cameras and guards; nobody knows till morning.' },
    loud: { name: 'Loud', does: 'Business hours, at gunpoint. The alarm rings; about a minute.' },
    inside: { name: 'Inside man', does: '$400 to a teller for a keycard. Walk down the staff stairs any time.' },
  };
  const TOOLS = { drill: 'Thermal drill (slow, noisy)', dynamite: 'Dynamite (instant, loud)', combo: 'The combination (tap the bank\'s phone first)' };

  PB.state = function () { const pl = G().player; pl.street = pl.street || {}; return pl.street; };
  PB.plan = function () { return this.state().plan || null; };
  PB.targets = function () {
    const g = G(), pl = g.player;
    return g.world.buildings.filter((b) => b && !b.destroyed && (b.type === 'bank' || b.type === 'casino')).sort((a, b) => Math.hypot(a.out.x * TS - pl.x, a.out.y * TS - pl.y) - Math.hypot(b.out.x * TS - pl.x, b.out.y * TS - pl.y)).slice(0, 8);
  };
  PB.open = function (pick) {
    const g = G(), ui = g.ui, pl = g.player, s = this.state();
    let p = s.plan;
    if (!p || pick) {
      const opts = this.targets().map((b) => ({ label: b.name, small: `${b.type === 'casino' ? 'Casino counting room' : 'Bank vault'} · ${b.city.name}${pl.cased && pl.cased[b.id] ? ' · cased' : ''}${g.pop.day - (b.robbedDay || -99) < 14 ? ' · hit recently, still jumpy' : ''}`, fn: () => { s.plan = { b: b.id, approach: 'quiet', tool: 'drill', roles: {}, made: g.pop.day }; this.open(); } }));
      opts.push({ label: 'Not now', fn: () => {} });
      return ui.choice('Pick the score', opts);
    }
    const b = g.world.buildings[p.b];
    if (!b || b.destroyed) { s.plan = null; return this.open(true); }
    const cased = !!(pl.cased && pl.cased[b.id]);
    const roster = R.camp ? R.camp.state().members.filter((m) => { const q = R.camp.person(m); return q && q.alive; }) : [];
    const who = (pid) => { const q = g.pop.people[pid]; return q ? g.pop.short(q) : '—'; };
    const card = (t, body) => `<div class="pcard"><b>${t}</b>${body}</div>`;
    let html = ui.header('The Plan', 'Pinned to the cork board in the back room.') + '<div class="body board">';
    html += card('The score', `<p>${esc(b.name)}, ${esc(b.city.name)}. ${b.type === 'casino' ? 'Counting room: six pallets, four guards.' : 'Vault level: four pallets, three guards.'}</p><p>${cased ? '<span class="ok">Cased.</span> Cameras sweep slower for you. Shift change 2 to 4 AM: one guard fewer if you go quiet then.' : '<span class="no">Not cased.</span> Go inside and ask about the safe-deposit boxes (or the high-roller room).'}</p>`);
    html += card('Approach', `<div class="prow">${Object.entries(APPROACH).map(([k, a]) => `<button class="chip ${p.approach === k ? 'c-greet' : 'c-talk'}" data-ap="${k}">${a.name}</button>`).join('')}</div><p class="sm">${APPROACH[p.approach].does}</p>`);
    html += card('The vault', `<div class="prow">${Object.entries(TOOLS).map(([k, t]) => `<button class="chip ${p.tool === k ? 'c-greet' : 'c-talk'}" data-tool="${k}">${t.split(' (')[0]}</button>`).join('')}</div><p class="sm">${TOOLS[p.tool]}${p.tool === 'drill' && !pl.inv.tools.drill ? ' · <span class="no">you don\'t have one (pawn shop, $250)</span>' : ''}${p.tool === 'dynamite' && !(pl.inv.ammo.dynamite > 0) ? ' · <span class="no">you have none</span>' : ''}${p.tool === 'combo' && !b.comboKnown ? ' · <span class="no">not known yet</span>' : ''}</p>`);
    html += card('The crew', Object.entries(ROLES).map(([k, r]) => `<div class="prole"><span><b>${r.name}</b> <small>${r.does} · ${Math.round(r.cut * 100)}% cut</small></span><button class="chip ${p.roles[k] != null ? 'c-greet' : 'c-talk'}" data-role="${k}">${p.roles[k] != null ? esc(who(p.roles[k])) : 'Assign'}</button></div>`).join('') + (roster.length ? '' : '<p class="sm no">Nobody on the roster. Recruit people (they join the crew), then plan.</p>'));
    const cut = Object.keys(p.roles).reduce((a, k) => a + (p.roles[k] != null ? ROLES[k].cut : 0), 0);
    html += card('Go', `<p class="sm">Crew take ${Math.round(cut * 100)}% of the score. ${p.approach === 'inside' ? (pl.keycards && pl.keycards[b.id] ? 'You have the keycard.' : 'The keycard costs $400 when you commit.') : ''}</p><div class="prow"><button class="chip c-greet" data-go="1">Commit to the plan</button><button class="chip c-talk" data-new="1">Different score</button><button class="chip c-antag" data-scrap="1">Scrap it</button></div>`);
    html += '</div>';
    const sh = ui.openSheet('plan', html);
    const re = () => { g.audio.sfx('click'); this.open(); };
    sh.querySelectorAll('[data-ap]').forEach((x) => x.addEventListener('click', () => { p.approach = x.dataset.ap; re(); }));
    sh.querySelectorAll('[data-tool]').forEach((x) => x.addEventListener('click', () => { p.tool = x.dataset.tool; re(); }));
    sh.querySelectorAll('[data-role]').forEach((x) => x.addEventListener('click', () => {
      const k = x.dataset.role;
      const taken = new Set(Object.entries(p.roles).filter(([r, v]) => r !== k && v != null).map(([, v]) => v));
      const opts = roster.filter((m) => !taken.has(m.pid)).map((m) => ({ label: R.camp.name(m), small: `Loyalty ${Math.round(m.loyalty)} · mood ${Math.round(m.mood)}${m.skill ? ` · veteran ×${m.skill}` : ''}`, fn: () => { p.roles[k] = m.pid; this.open(); } }));
      opts.push({ label: 'Nobody', fn: () => { delete p.roles[k]; this.open(); } });
      ui.choice(ROLES[k].name, opts);
    }));
    sh.querySelector('[data-new]').addEventListener('click', () => this.open(true));
    sh.querySelector('[data-scrap]').addEventListener('click', () => { s.plan = null; ui.closeSheet(); ui.toast('The board comes down. Maybe next month.'); });
    sh.querySelector('[data-go]').addEventListener('click', () => this.commit());
  };
  PB.commit = function () {
    const g = G(), ui = g.ui, pl = g.player, p = this.plan(), b = g.world.buildings[p.b];
    if (p.approach === 'inside' && !(pl.keycards && pl.keycards[b.id])) {
      if (!pl.pay(400)) return ui.toast('The teller wants $400 up front.', 'warn');
      pl.keycards = pl.keycards || {}; pl.keycards[b.id] = 1;
    }
    p.go = true;
    R.poi.add(b.out.x, b.out.y, 'tip', `The score: ${b.name}`, APPROACH[p.approach].name);
    g.waypoint = { x: b.out.x * TS + 8, y: b.out.y * TS + 8 };
    ui.closeSheet();
    const names = Object.entries(p.roles).map(([k, pid]) => `${ROLES[k].name}: ${g.pop.short(g.pop.people[pid])}`).join(', ');
    ui.story('The plan is on', `${b.name}. ${APPROACH[p.approach].name}. ${names ? names + '.' : 'Just you.'}\n\n${p.approach === 'loud' ? 'Walk in during business hours with a gun and head for the vault.' : p.approach === 'inside' ? 'Walk in and take the staff stairs.' : 'Come back after hours and break in; the vault is downstairs.'} The crew will be where they need to be.`);
  };

  // ---------------------------------------------------------------- the plan plays out
  PB.active = function (bid) { const p = this.plan(); return p && p.go && p.b === bid ? p : null; };
  PB.init = function () {
    if (this.wired) return;
    this.wired = true;
    const H = R.heist, bEnter = H.enter;
    H.enter = function (b, how) {
      const g = G(), pl = g.player, p = PB.active(b.id);
      const r = bEnter.apply(this, arguments);
      const room = pl.room;
      if (!p || !room) return r;
      pl.heist.plan = true;
      const hr = g.clock.hour();
      if (p.roles.wireman != null) { room.panelCut = true; g.ui.toast(`${g.pop.short(g.pop.people[p.roles.wireman])} cut the alarm panel from the junction box outside. The cameras are talking to nobody.`, 'good'); }
      if (p.roles.lookout != null) { room.grace = (room.grace || 0) + 8; room.lookout = true; }
      if ((pl.cased && pl.cased[b.id]) && how !== 'loud' && hr >= 2 && hr < 4) { const gd = (H.guards || []).find((q) => !q.dead); if (gd) { g.actors.remove(gd); H.guards = H.guards.filter((q) => q !== gd); g.ui.toast('Shift change. One guard short, like you planned.', 'good'); } }
      if (p.roles.muscle != null) {
        const q = g.pop.people[p.roles.muscle];
        const h = q && g.life.spawnPerson(q, pl.x + 12, pl.y);
        if (h) { h.room = room; const t = g.ui.toast; g.ui.toast = () => {}; try { pl.recruit(h); } finally { g.ui.toast = t; } g.actors.arm(h, 'shotgun'); g.actors.say(h, 'Right behind you.'); }
      }
      return r;
    };
    const bRaise = H.raise;
    H.raise = function (level) {
      const r = bRaise.apply(this, arguments);
      const room = G().player.room;
      if (level === 'silent' && room && room.lookout && room.alarm === 'silent' && !room.lookoutUsed) { room.lookoutUsed = true; room.alarmT += 30; G().ui.toast('Your lookout radios in: "Squad car went the other way. You got an extra thirty."', 'good'); }
      return r;
    };
    const IP = R.Interiors.prototype, bExit = IP.exit;
    IP.exit = function () {
      const g = G(), pl = g.player, room = pl.room;
      const hs = pl.heist, vault = room && room.b.type === 'vaultlvl';
      const bank = vault ? g.world.buildings[room.b.vaultOf] : null;
      const p = bank && PB.active(bank.id);
      const cash0 = pl.cash;
      const r = bExit.apply(this, arguments);
      if (!p || !hs || !hs.bags) return r;
      const take = pl.cash - cash0;
      // the split
      let paid = 0;
      for (const [k, pid] of Object.entries(p.roles)) {
        const share = Math.round(take * ROLES[k].cut);
        paid += share;
        const m = R.camp && R.camp.member(g.pop.people[pid]);
        if (m) { m.loyalty = Math.min(100, m.loyalty + 15); m.mood = Math.min(100, m.mood + 20); m.skill++; }
      }
      if (paid) { pl.cash -= paid; g.ui.toast(`The crew's cut: ${R.fmtMoney(paid)}. They'll be buying rounds for a month.`, 'good'); }
      // the getaway
      if (p.roles.driver != null) {
        const q = g.pop.people[p.roles.driver];
        const v = g.traffic.make(R.rng.pick(['muscle', 'coupe']), pl.x + 16, pl.y + 8, 0, { owner: 'player', locked: false, keep: true });
        v.speed = 0; v.parked = true;
        g.ui.toast(`${q ? g.pop.short(q) : 'Your driver'} pulls up with the engine running. Get in.`, 'good');
        if (g.law.incident) g.law.incident.getaway = true;
      }
      if (R.memory) R.memory.log('heist', { x: bank.out.x * TS, y: bank.out.y * TS, seen: room.alarm !== 'off' && !pl.masked });
      delete this.game.player.street.plan;
      return r;
    };
    // a driver outside makes the search shorter
    const L = R.Law.prototype, bUpd = L.update;
    L.update = function (dt) { if (this.incident && this.incident.getaway && this.incident.searchLeft > 0) this.incident.searchLeft -= dt * 0.8; return bUpd.apply(this, arguments); };
    // the board lives in the club's back room
    const U = R.UI.prototype, bIO = U.interiorOptions;
    U.interiorOptions = function (b) {
      const opts = bIO.apply(this, arguments) || [];
      const club = R.camp && R.camp.club();
      if (club && b === club) { const p = PB.plan(); opts.splice(1, 0, { label: 'The plan board', small: p ? `${G().world.buildings[p.b].name} · ${APPROACH[p.approach].name}${p.go ? ' · ON' : ''}` : 'Plan a bank or casino job with the crew', fn: () => { this.closeSheet(); PB.open(); } }); }
      return opts;
    };
    const st = document.createElement('style');
    st.textContent = '.board{background:#b98a52;background-image:radial-gradient(rgba(0,0,0,0.12) 1px,transparent 1px);background-size:6px 6px}.pcard{background:var(--paper);border:3px solid var(--ink);border-radius:4px;padding:6px 10px;margin:8px 4px;color:var(--ink);box-shadow:2px 3px 0 rgba(0,0,0,0.35);position:relative}.pcard:before{content:"";position:absolute;top:-6px;left:50%;width:10px;height:10px;border-radius:50%;background:#c83a2a;border:2px solid var(--ink)}.pcard b{font-family:var(--pix);font-weight:400;font-size:12px}.pcard p{margin:4px 0;font-size:14px}.pcard .sm{font-size:12px;color:var(--muted)}.prow{display:flex;flex-wrap:wrap;gap:6px;margin:6px 0}.prole{display:flex;justify-content:space-between;align-items:center;gap:8px;margin:5px 0}.prole small{display:block;color:var(--muted);font-size:11px}.ok{color:#4a7a20}.no{color:var(--red)}';
    document.head.appendChild(st);
  };
})();
