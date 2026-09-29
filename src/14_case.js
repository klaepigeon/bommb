// RHAPSODY — the investigation. A serious crime doesn't end when the sirens stop: a
// detective opens a case and works it every hour. Evidence builds the case: a body that
// got found, witnesses who saw your face, the clothes you wore, the gun you used, the car
// you drove. Every piece can be dealt with: sink the body, lean on the witness, burn the
// suit, drop the gun in the harbor, respray the car, grow a beard. Leave enough and the
// case closes in on you: a detective comes asking questions, and then a warrant.
'use strict';
(function () {
  const D = R.data, O = D.O, TS = R.TILE;
  const G = () => R.game;
  const CS = (R.cases = { live: new Map() });
  const SERIOUS = { murder: 1, kidnap: 1, robbery: 1, heist: 1, arson: 1, carjack: 1, burglary: 1, mugging: 1, copMurder: 1, copAssault: 1, explosion: 1, manslaughter: 1 };
  const DETECTIVES = { port: 'Det. Frank Mullane', avalon: 'Det. Lorraine Vitale', dust: 'Det. Ray Cordero', pine: 'Det. Harlan Voss', bayou: 'Det. Aurelie Batiste', county: 'Inv. Wendell Pike' };
  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);

  CS.state = function () { const pl = G().player; return (pl.cases = pl.cases || { list: [], next: 1 }); };
  CS.open = function () { return this.state().list.filter((c) => c.status === 'open' || c.status === 'warrant'); };
  const rt = (c) => { if (!CS.live.has(c.id)) CS.live.set(c.id, {}); return CS.live.get(c.id); };
  const faceOf = (s) => ({ hair: s.hair, hairCol: s.hairCol, facial: s.facial, glasses: !!s.glasses, hat: s.hat });
  const clothesOf = (s) => ({ jacket: s.jacket, shirt: s.shirt, pants: s.pants });
  const same = (a, b) => Object.keys(a).every((k) => a[k] === b[k]);

  // ---------------------------------------------------------------- opening a case
  CS.onCrime = function (type, x, y, opts) {
    const g = G(), pl = g.player, law = g.law;
    if (!SERIOUS[type] || (opts && opts.minor) || (g.cheats && g.cheats.noLaw)) return;
    const def = law.CRIMES[type], jur = law.jurAt(x, y), now = g.clock.t;
    const s = this.state();
    let c = s.list.find((k) => k.status === 'open' && k.jur === jur && now - k.lastT < 45);
    if (!c) {
      c = { id: s.next++, type, name: def.name, jur, day: g.pop.day, t: now, lastT: now, progress: 0, status: 'open', det: DETECTIVES[jur] || DETECTIVES.county, witnesses: [], coldH: 0, masked: !!pl.masked, face: faceOf(pl.style), clothes: clothesOf(pl.style), bloody: pl.bloody > 0.3, body: null, weapon: null, car: null, visited: false, sketch: false, bounty: def.bounty, where: g.world.cityAt((x / TS) | 0, (y / TS) | 0) ? g.world.cityAt((x / TS) | 0, (y / TS) | 0).name : 'the County' };
      s.list.unshift(c);
      if (s.list.length > 30) s.list.pop();
    } else { c.lastT = now; c.bounty += def.bounty; if (def.bounty > law.CRIMES[c.type].bounty) { c.type = type; c.name = def.name; } }
    const r = rt(c);
    // what they have
    const w = pl.weapon && D.weapons[pl.weapon] && (D.weapons[pl.weapon].gun || pl.weapon === 'knife') ? pl.weapon : null;
    if (w) c.weapon = { id: w, name: D.weapons[w].name, gone: false };
    const car = pl.inCar || g.traffic.nearestCar(pl.x, pl.y, TS * 4);
    if (car && (pl.inCar === car || car.owner === 'player' || car.stolen)) { c.car = { name: car.model.name, color: car.color || '', gone: false, sprayed: false }; r.car = car; }
    const victim = opts && opts.victim;
    if (victim && (type === 'murder' || type === 'manslaughter' || type === 'copMurder')) { c.body = { state: 'there', who: victim.person ? g.pop.name(victim.person) : 'a stranger', pid: victim.person ? victim.person.id : null }; r.victim = victim; }
    // a contract the family ordered: their lawyers and their cops lean on the file
    const j = g.jobs.active;
    if (victim && victim.person && j && j.kind === 'hit' && j.person === victim.person.id) c.contract = true;
    // witnesses from this crime (the law module tags them)
    setTimeout(() => {
      for (const a of g.actors.list) {
        if (!a.witness || a.witness.crime.t !== now || a.dead) continue;
        if (a.person && !c.witnesses.some((x) => x.pid === a.person.id)) c.witnesses.push({ pid: a.person.id, name: g.pop.name(a.person), masked: !!pl.masked, gone: null });
        else if (!a.person && c.witnesses.filter((x) => x.pid == null).length < 2) c.witnesses.push({ pid: null, name: 'a passer-by', masked: !!pl.masked, gone: null, day: g.pop.day });
      }
      if (law.incident && law.incident.crimes && law.incident.crimes.some((k) => k.t === now) && law.incident.state === 'pursuit' && !c.witnesses.some((x) => x.cop)) c.witnesses.push({ pid: null, name: 'a police officer', masked: !!pl.masked, cop: true, gone: null });
    }, 50);
  };

  // ---------------------------------------------------------------- the case, hour by hour
  CS.weigh = function (c) {
    const g = G(), pl = g.player, r = rt(c), parts = [];
    const add = (k, v, label, fix) => parts.push({ k, v, label, fix });
    const ids = c.witnesses.filter((x) => !x.gone);
    for (const x of ids) add('wit', x.cop ? 2 : x.masked ? 1 : 3, x.cop ? 'A police officer\'s report' : `Witness: ${x.name}${x.masked ? ' (saw a masked man)' : ''}`, x.cop ? 'Pay the bounty in ' + g.law.jurName(c.jur) + ' and the report gets filed away.' : x.pid != null ? 'Find them. Lean on them, pay them off, or worse.' : 'A stranger. They\'ll forget your face in a day or two.');
    const seen = ids.length > 0;
    if (seen && !c.masked) { const m = same(c.face, faceOf(pl.style)); add('face', m ? 2 : 0.3, m ? 'Your face: they have a good description' : 'Your face: the sketch doesn\'t look like you anymore', m ? 'Change your hair or grow a beard at a barber.' : null); }
    if (seen) { const m = same(c.clothes, clothesOf(pl.style)); add('clothes', m ? 1.5 + (c.bloody ? 1 : 0) : 0.2, m ? `The clothes${c.bloody ? ', covered in blood' : ''}: still on your back` : 'The clothes: long gone', m ? 'Buy a new outfit at a tailor.' : null); }
    if (c.body) {
      const v = r.victim;
      if (v && !v.removed && v.dead) c.body.state = v.found ? 'found' : v.hidden || v.sunk ? 'missing' : v.carried ? 'there' : c.body.state === 'found' ? 'found' : 'there';
      else if (v && (v.hidden || v.sunk)) c.body.state = 'missing';
      const st = c.body.state;
      add('body', st === 'found' ? 3 : st === 'missing' ? 0.4 : 1.5, st === 'found' ? `The body of ${c.body.who}: at the morgue` : st === 'missing' ? `${c.body.who}: a missing person, no body` : `The body of ${c.body.who}: lying where it fell`, st === 'found' ? null : st === 'missing' ? null : 'Move it before somebody finds it: trunk, trash, brush or the bottom of the harbor.');
    }
    if (c.weapon && !c.weapon.gone) {
      if (!pl.inv.weapons[c.weapon.id]) c.weapon.gone = true;
      else if (seen || (c.body && c.body.state === 'found')) add('weapon', 2, `The weapon: your ${c.weapon.name}, ballistics can match it`, 'Toss it in the water or a trash can.');
    }
    if (c.car && !c.car.gone) {
      const v = r.car;
      if (v && (v.wrecked || v.burning > 0 || (v.removed && v.sinkT > 3))) { c.car.gone = true; }
      else if (!c.car.sprayed) add('car', seen ? 2 : 0.8, `The car: a ${c.car.name}, somebody got the plate`, 'Burn it, sink it, or respray it at a garage.');
    }
    return parts;
  };
  CS.hour = function () {
    const g = G(), pl = g.player;
    for (const c of this.open()) {
      if (c.status !== 'open') continue;
      // a dead detective's cases sit on a desk until someone new picks them up
      if (c.stalledUntil && g.clock.t < c.stalledUntil) continue;
      // strangers forget
      for (const x of c.witnesses) {
        if (x.gone) continue;
        if (x.pid == null && !x.cop && g.pop.day - (x.day || c.day) >= 2) x.gone = 'forgot';
        if (x.pid != null) { const p = g.pop.people[x.pid]; if (!p || !p.alive) x.gone = 'dead'; }
      }
      const parts = this.weigh(c);
      const sum = parts.reduce((a, p) => a + p.v, 0);
      const lawyer = c.lawyerUntil && g.clock.t < c.lawyerUntil;
      // the higher you stand in the family, the more friends you have in the precinct
      const shield = (c.contract ? 0.45 : 1) * Math.max(0.4, 1 - g.jobs.rank() * 0.12);
      if (!lawyer) c.progress = Math.min(100, c.progress + sum * 0.7 * shield * (R.campaign && R.campaign.state().route === 'badge' ? 0.5 : 1));
      if (sum < 0.8) c.coldH++; else c.coldH = 0;
      if (c.coldH >= 36) { c.status = 'cold'; g.ui.toast(`${c.det} closed the file on the ${c.name.toLowerCase()} in ${c.where}. Unsolved.`, 'good'); continue; }
      if (c.progress >= 40 && !c.sketch && c.witnesses.some((x) => !x.gone && !x.masked)) { c.sketch = true; g.pop.addNews(c.jur === 'county' ? 'port' : c.jur, `Police release a sketch in the ${c.name.toLowerCase()} in ${c.where}. "Young, well dressed, and very dangerous," says ${c.det}.`); g.ui.toast('The papers printed a police sketch of you. Check the Heat tab.', 'warn'); }
      if (c.progress >= 55 && !c.visited) this.visit(c);
      if (c.progress >= 100) this.warrant(c);
    }
  };
  CS.warrant = function (c) {
    const g = G(), pl = g.player, law = g.law;
    c.status = 'warrant';
    law.bounty[c.jur] = (law.bounty[c.jur] || 0) + c.bounty * 2;
    pl.rep.infamy += 4;
    g.pop.addNews(c.jur === 'county' ? 'port' : c.jur, `WARRANT ISSUED in the ${c.name.toLowerCase()} in ${c.where}. ${c.det}: "We know who did it. It's a matter of time."`);
    g.ui.story('WARRANT', `${c.det} has enough on you for the ${c.name.toLowerCase()} in ${c.where}.\n\nA ${R.fmtMoney(c.bounty * 2)} bounty is on your head in ${law.jurName(c.jur)}. Pay it off at a police station, or keep running.`);
    if (law.jurAt(pl.x, pl.y) === c.jur && !law.incident && !pl.room) law.startIncident({ type: c.type, def: law.CRIMES[c.type], x: pl.x, y: pl.y, jur: c.jur, identified: true, lvl: 2, bounty: 0, t: g.clock.t }, null);
  };

  // ---------------------------------------------------------------- the detective comes calling
  CS.visit = function (c) {
    const g = G(), pl = g.player;
    if (pl.room || pl.inCar || g.law.incident || this.detective) return;
    const s = g.world.findNear(pl.x / TS, pl.y / TS, 7, 11, (x, y) => !g.world.solidPed(x, y) && !g.world.isWater(x, y));
    if (!s) return;
    c.visited = true;
    const fem = /Lorraine|Aurelie/.test(c.det);
    const h = g.actors.makeHuman(s.x * TS + 8, s.y * TS + 8, { cop: true, arch: 'square', cash: 20, look: { fem, age: 48, skin: '#c89070', hair: '#3a2a1a', top: '#7a6a4a', bottom: '#3a3a3a', seedStr: 'det' + c.id, oldOverride: { style: fem ? 'bob' : 'short', jacket: ['#4a3a20', '#6a5430', '#8e7444', '#b0965c'], top: 'collar', shirt: ['#8a8a8a', '#b0b0b0', '#d0d0d0', '#f0f0f0'], pants: ['#2a2a2a', '#3a3a3a', '#4a4a4a', '#5a5a5a'], glasses: !fem } } });
    h.keep = true; h.detectiveFor = c.id; h.strangerName = c.det; h.hostile = false; h.state = 'travel'; h.look.hatKind = 'fedora'; h.look.hatCol = '#4a3a20';
    g.actors.goTo(h, (pl.x / TS) | 0, (pl.y / TS) | 0, { near: 20 });
    this.detective = h;
    g.ui.toast(`${c.det} is walking your way. Hands in pockets, eyes on you.`, 'warn');
  };
  CS.detTree = function (h) {
    const g = G(), pl = g.player, c = this.state().list.find((k) => k.id === h.detectiveFor);
    const ui = g.ui, say = (t) => ui.talkLine(t), done = (msg, d) => { if (c) c.progress = R.clamp(c.progress + d, 0, 100); ui.closeSheet(); if (msg) ui.toast(msg, d < 0 ? 'good' : 'warn'); h.keep = false; h.detectiveFor = null; h.state = 'travel'; g.actors.goTo(h, ((h.x / TS) | 0) + R.rng.int(-30, 30), ((h.y / TS) | 0) + 25, {}); this.detective = null; };
    if (!c) return { title: h.strangerName, options: [{ label: 'Goodbye', fn: () => ui.closeSheet() }] };
    setTimeout(() => say(`"${c.det}. Few questions about the ${c.name.toLowerCase()} in ${c.where}. Where were you on ${['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][c.day % 7]} night?"`), 0);
    const opts = [];
    opts.push({ label: '"Home. Watching Kojak."', small: `Cool ${Math.round(pl.cool)}/100: keep it steady`, fn: () => { const ok = R.rng() < 0.35 + pl.cool / 160; pl.cool = Math.max(0, pl.cool - 30); done(ok ? `${c.det} writes something down. "Kojak. Sure." (case −20)` : `"Kojak was a rerun that night, pal." (case +10)`, ok ? -20 : 10); } });
    const price = 120 + c.bounty;
    opts.push({ label: `Slip an envelope across ($${price})`, small: 'Most of them have a mortgage', fn: () => { if (!pl.pay(price)) return say('"Is that supposed to be funny?"'); const ok = R.rng() < 0.7; done(ok ? `${c.det} pockets it without looking. "Maybe I had the wrong guy." (case −45)` : `"Attempted bribery of an officer. Keep it. I'll add it to your file." (case +20)`, ok ? -45 : 20); } });
    opts.push({ label: '"Talk to my lawyer." ($100)', small: 'Stalls the case for two days', fn: () => { if (!pl.pay(100)) return say('"You don\'t have a lawyer, do you."'); c.lawyerUntil = g.clock.t + 2 * 1440; done(`Your lawyer's letter lands on ${c.det}'s desk. The case stalls for two days.`, 0); } });
    if (R.campaign && R.campaign.state().route === 'badge') opts.push({ label: '"Call Rourke. I\'m with him."', small: 'The informant\'s card', fn: () => { c.status = 'closed'; done(`${c.det} makes a phone call and goes pale. "My mistake." Case closed.`, 0); } });
    opts.push({ label: 'Walk away', fn: () => done(`"Don't leave town." (case +10)`, 10) });
    return { title: c.det, sub: `Case: ${c.name}, ${c.where} · ${Math.round(c.progress)}% solved`, options: opts };
  };

  // ---------------------------------------------------------------- leaning on witnesses
  CS.witnessCase = function (p) { if (!p) return null; for (const c of this.open()) { const x = c.witnesses.find((w) => w.pid === p.id && !w.gone); if (x) return { c, x }; } return null; };
  CS.witnessOpts = function (h, opts) {
    const g = G(), pl = g.player, hit = this.witnessCase(h.person);
    if (!hit) return;
    const { c, x } = hit, ui = g.ui, say = (t) => ui.talkLine(t);
    const i = Math.max(0, opts.findIndex((o) => /Goodbye|Leave/.test(o.label)));
    const fear = R.dialog.fear(h);
    opts.splice(i, 0, { label: '"About what you saw the other night..."', small: `Witness in the ${c.name.toLowerCase()}`, cls: 'go', fn: () => {
      ui.choice(`${x.name} goes pale`, [
        { label: 'Lean on them', small: fear > 20 ? 'They look scared already' : 'They don\'t scare easy', fn: () => { const ok = R.rng() < 0.35 + fear / 120 + (1 - h.tr.brave) * 0.3; if (ok) { x.gone = 'scared'; g.actors.say(h, R.rng.pick(['I didn\'t see nothing. I swear on my mother.', 'I was drunk. I don\'t remember a thing.', 'What night? I was in Ohio.'])); ui.toast(`${x.name} won't testify.`, 'good'); pl.rep.infamy += 1; if (h.person) h.person.opinion -= 25; } else { g.actors.say(h, 'You threatening me? I\'m calling the detective!'); c.progress = Math.min(100, c.progress + 15); g.law.crime('assault', h.x, h.y, { victim: h, minor: true }); ui.toast('That backfired. They told the detective about you. (case +15)', 'bad'); } } },
        { label: `Pay for their silence ($${60 + c.bounty})`, small: 'Cash and a smile', fn: () => { if (!pl.pay(60 + c.bounty)) return ui.toast('You don\'t have it.'); if (R.rng() < 0.8 || (h.person && h.person.opinion > 20)) { x.gone = 'paid'; g.actors.say(h, 'Funny, my memory\'s getting worse every day.'); ui.toast(`${x.name} develops amnesia.`, 'good'); } else { g.actors.say(h, 'You can\'t buy me. Get lost.'); c.progress = Math.min(100, c.progress + 5); } } },
        { label: 'Never mind', fn: () => {} },
      ]);
    } });
  };

  // ---------------------------------------------------------------- getting rid of things
  CS.evidenceWeapon = function () { const pl = G().player; for (const c of this.open()) if (c.weapon && !c.weapon.gone && pl.inv.weapons[c.weapon.id]) return c.weapon; return null; };
  CS.context = function (pl) {
    const g = G();
    if (pl.room || pl.inCar || pl.carrying) return null;
    const w = this.evidenceWeapon();
    if (!w) return null;
    const tx = (pl.x / TS) | 0, ty = (pl.y / TS) | 0;
    let spot = null;
    for (let yy = ty - 1; yy <= ty + 2 && !spot; yy++) for (let xx = tx - 1; xx <= tx + 1 && !spot; xx++) { if (g.world.isWater(xx, yy)) spot = 'water'; else if (g.world.o(xx, yy) === O.TRASH) spot = 'trash'; }
    if (!spot) return null;
    return { label: `Ditch the ${w.name} (evidence)`, fn: () => {
      delete pl.inv.weapons[w.id];
      if (pl.weapon === w.id) { pl.weapon = 'fists'; pl.weaponOut = false; }
      for (const c of this.open()) if (c.weapon && c.weapon.id === w.id) c.weapon.gone = true;
      g.audio.sfx(spot === 'water' ? 'splash' : 'bump', pl.x, pl.y);
      g.ui.toast(spot === 'water' ? `Plop. The ${w.name} sinks into the dark. No gun, no match.` : `Under the coffee grounds. The ${w.name} goes out with the trash.`, 'good');
    } };
  };
  CS.respray = function (b, opts) {
    const g = G(), pl = g.player;
    for (const c of this.open()) {
      const v = c.car && !c.car.gone && !c.car.sprayed && rt(c).car;
      if (!v || v.removed || R.dist(v.x, v.y, b.out.x * TS, b.out.y * TS) > TS * 10) continue;
      opts.push({ label: `Respray the ${v.model.name}`, price: '$60', small: 'New paint, new plates, no questions', fn: () => { if (!pl.pay(60)) return g.ui.toast('Sixty bucks. Cash.'); const cols = v.model.colors || ['#3a5a8a']; v.color = cols.find((x) => x !== v.color) || '#2a6a3a'; v.art = null; c.car.sprayed = true; g.audio.sfx('cash'); g.ui.toast(`The ${v.model.name} rolls out ${['candy apple', 'avocado', 'harvest gold', 'midnight'][R.rng.int(0, 3)]}, with Nevada plates.`, 'good'); } });
      return;
    }
  };

  // ---------------------------------------------------------------- the heat tab
  CS.html = function () {
    const g = G(), s = this.state();
    const open = this.open(), rest = s.list.filter((c) => !open.includes(c)).slice(0, 6);
    if (!s.list.length) return '<p>No detective has your name on a file. Keep it that way.</p><p style="font-size:13px;color:var(--brown)">Serious crimes open a case. Bodies, witnesses, the gun, the car and the clothes you wore all count as evidence.</p>';
    let h = '';
    for (const c of open) {
      const parts = this.weigh(c);
      h += `<div class="case"><div style="display:flex;gap:10px;align-items:flex-start"><canvas class="sketch" data-case="${c.id}" width="30" height="36" style="width:60px;height:72px;image-rendering:pixelated;border:2px solid var(--ink);background:#e8dcc0"></canvas><div style="flex:1"><b style="font-size:16px">${esc(c.name)}, ${esc(c.where)}</b>${c.status === 'warrant' ? ' <b style="color:var(--red)">WARRANT</b>' : ''}<br><small>${esc(c.det)} · day ${c.day + 1}</small><div class="meter" style="margin-top:4px"><i style="width:${Math.round(c.progress)}%;background:${c.progress > 70 ? 'var(--red)' : c.progress > 40 ? 'var(--mustard)' : 'var(--good)'}"></i></div><small>${Math.round(c.progress)}% solved${c.lawyerUntil && g.clock.t < c.lawyerUntil ? ' · stalled by your lawyer' : ''}${c.contract ? ' · the family is leaning on this file' : ''}</small></div></div>`;
      h += parts.length ? parts.map((p) => `<p style="margin:4px 0">${p.v >= 1.5 ? '●' : p.v >= 0.8 ? '◐' : '○'} ${esc(p.label)}${p.fix ? `<br><small style="color:var(--brown)">↳ ${esc(p.fix)}</small>` : ''}</p>`).join('') : '<p>Nothing solid. It\'ll go cold.</p>';
      const gone = c.witnesses.filter((x) => x.gone && x.gone !== 'forgot');
      if (gone.length) h += `<p><small>Witnesses who won't talk: ${gone.map((x) => esc(x.name)).join(', ')}</small></p>`;
      h += '</div>';
    }
    if (rest.length) h += `<div class="sect">Old files</div>${rest.map((c) => `<p>• ${esc(c.name)}, ${esc(c.where)}: ${c.status === 'cold' ? 'went cold' : 'closed'}</p>`).join('')}`;
    return h;
  };
  // the sketch artist did their best
  CS.drawSketches = function (root) {
    root.querySelectorAll('canvas.sketch').forEach((cv) => {
      const c = this.state().list.find((k) => k.id === +cv.dataset.case);
      if (!c) return;
      const g = cv.getContext('2d');
      const look = R.lookFromStyle(Object.assign({}, G().player.style, c.face, c.clothes), c.masked);
      g.fillStyle = '#e8dcc0'; g.fillRect(0, 0, cv.width, cv.height);
      g.fillStyle = '#b8b0a0'; g.fillRect(0, 30, cv.width, 1); g.fillRect(0, 20, cv.width, 1);
      g.save(); g.scale(2, 2); R.art.drawPerson(g, cv.width / 4, 27, 2, 0, look, {}); g.restore();
      const img = g.getImageData(0, 0, cv.width, cv.height), d = img.data;
      const acc = c.masked ? 0.2 : Math.min(1, c.witnesses.filter((x) => !x.masked).length * 0.35 + 0.2);
      const rnd = R.mulberry(c.id * 77);
      for (let i = 0; i < d.length; i += 4) {
        const l = (d[i] * 0.3 + d[i + 1] * 0.59 + d[i + 2] * 0.11);
        // pencil: solid ink for the darks, cross-hatching for the mids, paper for the lights
        const px = (i / 4) % cv.width, py = ((i / 4) / cv.width) | 0;
        const bg = d[i + 3] < 10 || (d[i] === 232 && d[i + 1] === 220 && d[i + 2] === 192);
        let ink = bg ? 232 : l < 70 ? 52 : l < 150 ? ((px + py) % 2 ? 110 : 200) : l < 215 ? ((px + py) % 4 === 0 ? 150 : 226) : 232;
        if (!bg && rnd() > acc + 0.4) ink = rnd() < 0.5 ? 232 : 90; // what they didn't see, the artist guessed
        d[i] = ink; d[i + 1] = ink * 0.95; d[i + 2] = ink * 0.84;
      }
      g.putImageData(img, 0, 0);
    });
  };

  // ---------------------------------------------------------------- wiring
  // ---------------------------------------------------------------- killing the detective
  // The case doesn't die with them, but it bleeds: the notes are half in their head, the file
  // goes to someone new who has to start over, and the witnesses stop returning calls. Every
  // case they carried loses most of its progress, stalls for two days, and loses a witness.
  const REPLACE = ['Det. Sam Kowalski', 'Det. Nora Beck', 'Det. Luis Arriaga', 'Det. June Tanaka', 'Det. Walt Brennan', 'Det. Ida Moreau'];
  CS.detectiveKilled = function (name) {
    const g = G(), s = this.state();
    const hit = this.open().filter((c) => c.det === name);
    if (!hit.length) return 0;
    const next = R.rng.pick(REPLACE.filter((n) => n !== name));
    for (const c of hit) {
      c.progress = Math.round(c.progress * 0.3);
      c.stalledUntil = g.clock.t + 1440 * 2;
      if (c.status === 'warrant') { c.status = 'open'; }
      const live = (c.witnesses || []).filter((x) => !x.gone);
      if (live.length) live[0].gone = 'scared';
      c.det = next;
    }
    g.pop.addNews(hit[0].jur === 'county' ? 'port' : hit[0].jur, `DETECTIVE SLAIN. ${name} was found dead today. The department promises "justice", but word is the files are a mess. ${next} takes over.`);
    g.ui.toast(`${name} is dead. Their case${hit.length > 1 ? 's' : ''} against you just fell apart (progress cut, stalled two days). ${next} picks up the pieces.`, 'good');
    s.detsKilled = (s.detsKilled || 0) + 1;
    return hit.length;
  };
  CS.init = function (g) {
    this.live = new Map(); this.detective = null; this.lastHour = Math.floor(g.clock.t / 60);
    if (this.wrapped) return;
    this.wrapped = true;
    const C = R.combat, ck = C.kill;
    C.kill = function (h, source, kind) {
      const was = h && h.dead, r = ck.apply(this, arguments);
      if (!was && h && h.dead && (h.detectiveFor || (h.strangerName && /^(Det\.|Inv\.)/.test(h.strangerName)))) {
        if (CS.detective === h) CS.detective = null;
        CS.detectiveKilled(h.strangerName);
      }
      return r;
    };
    const LP = R.Law.prototype, baseCrime = LP.crime, basePay = LP.payBounty;
    LP.crime = function (type, x, y, opts) { const r = baseCrime.apply(this, arguments); try { CS.onCrime(type, x, y, opts || {}); } catch (e) { console.error(e); } return r; };
    LP.payBounty = function (jur) { const r = basePay.apply(this, arguments); if (!(this.bounty[jur] > 0)) for (const c of CS.open()) if (c.jur === jur) { if (c.status === 'warrant') c.status = 'closed'; for (const x of c.witnesses) if (x.cop) x.gone = 'filed'; } return r; };
    const PP = R.Player.prototype, baseCtx = PP.contextAction;
    PP.contextAction = function () { return CS.context(this) || baseCtx.call(this); };
    const tree = R.dialog.tree;
    R.dialog.tree = function (h) {
      if (h.detectiveFor) return CS.detTree(h);
      const t = tree.call(this, h);
      if (t && t.options && h.person) CS.witnessOpts(h, t.options);
      return t;
    };
    const U = R.UI.prototype, io = U.interiorOptions;
    U.interiorOptions = function (b) { const o = io.call(this, b); if (b.type === 'garage' || b.type === 'gas') CS.respray(b, o); return o; };
  };
  CS.update = function (dt) {
    const g = G(), hr = Math.floor(g.clock.t / 60);
    if (hr !== this.lastHour) { const n = Math.min(6, hr - this.lastHour); this.lastHour = hr; for (let i = 0; i < n; i++) this.hour(); }
    const d = this.detective, pl = g.player;
    if (d) {
      if (d.dead || d.removed) { this.detective = null; return; }
      if (d.detectiveFor && !pl.room) {
        const dist = R.dist(d.x, d.y, pl.x, pl.y);
        if (dist > TS * 2.2) { if (!d.goal || R.dist(d.goal.tx * TS, d.goal.ty * TS, pl.x, pl.y) > TS * 3) { d.state = 'travel'; g.actors.goTo(d, (pl.x / TS) | 0, (pl.y / TS) | 0, { near: 20 }); } d.asked = false; }
        else if (!d.asked) { d.asked = true; d.state = 'idle'; d.timer = 1e9; g.actors.say(d, 'Got a minute, friend?'); }
        if (dist > TS * 40) { g.actors.remove(d); this.detective = null; }
      }
    }
  };
})();
