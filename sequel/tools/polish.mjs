// The graphical polish test: characters, drawn the way the game draws them, in all eight
// directions and every walk frame, checked pixel by pixel.
//   1. No stray pixels: every solid pixel of a character is joined to the body (no islands of
//      coat, glove, hat or overlay floating beside it).
//   2. Clothes are part of the sprite: nothing outside the body's own frame except the hat.
//   3. It animates: every walk frame differs from standing, and the coat changes with the legs.
//   4. The duster is a duster: coat pixels below the waist in every frame.
// Covers the player's starting look, every duster and the visor helmet, the aged face, and a
// crowd of NPCs off the street. Writes a contact sheet if you give it a directory.
//   node tools/polish.mjs [screenshot-dir]
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { writeFileSync } from 'node:fs';

const { chromium } = await import('playwright').catch(() => import('/opt/node22/lib/node_modules/playwright/index.mjs'));
const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const SHOTS = process.argv[2] || null;
const b = await chromium.launch();
const p = await (await b.newContext({ viewport: { width: 844, height: 390 } })).newPage();
const errs = [];
p.on('pageerror', (e) => errs.push(e.message + ' | ' + (e.stack || '').split('\n').slice(1, 3).join(' ')));
await p.goto('file://' + join(ROOT, 'dist/index.html') + '?quick');
await p.waitForSelector('#btnNew:not([hidden])', { timeout: 60000 });
const log = [];
const check = (ok, what) => { log.push((ok ? '✓ ' : '✗ ') + what); if (!ok) errs.push('step failed: ' + what); };
await p.click('#btnNew');
await p.waitForTimeout(900);
await p.evaluate(() => { for (let i = 0; i < 6; i++) { const s = document.querySelector('#story'); if (s && getComputedStyle(s).display !== 'none') { const b = s.querySelector('button'); if (b) b.click(); } } R.game.ui.closeSheet(); });

const r = await p.evaluate((wantSheet) => {
  const g = R.game, A = R.art, pl = g.player, ST = R.data.style;
  const W = 48, H = 48, OX = 24, OY = 40;
  const WALKS = [0, 2.2, 4.2, 6.2]; // walk values that land on phases 0, 1, 2, 3
  const render = (look, d8, walk) => {
    const cv = document.createElement('canvas'); cv.width = W; cv.height = H;
    A.drawPerson(cv.getContext('2d'), OX, OY, 1, walk, look, { ang: d8 * Math.PI / 4 });
    return cv;
  };
  const solid = (cv) => { const d = cv.getContext('2d').getImageData(0, 0, W, H).data, m = new Uint8Array(W * H); for (let i = 0; i < W * H; i++) m[i] = d[i * 4 + 3] >= 200 ? 1 : 0; return { m, d }; };
  // islands: 8-connected groups of solid pixels
  const islands = (m) => {
    const seen = new Uint8Array(W * H), sizes = [];
    islands.boxes = [];
    for (let s = 0; s < W * H; s++) {
      if (!m[s] || seen[s]) continue;
      let n = 0; const st = [s]; seen[s] = 1; let bx0 = W, by0 = H, bx1 = 0, by1 = 0;
      while (st.length) { const i = st.pop(); n++; const x = i % W, y = (i / W) | 0; bx0 = Math.min(bx0, x); bx1 = Math.max(bx1, x); by0 = Math.min(by0, y); by1 = Math.max(by1, y); for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) { const xx = x + dx, yy = y + dy; if (xx < 0 || yy < 0 || xx >= W || yy >= H) continue; const j = yy * W + xx; if (m[j] && !seen[j]) { seen[j] = 1; st.push(j); } } }
      sizes.push(n); islands.boxes.push({ n, at: `x${bx0 - OX}..${bx1 - OX} y${by0 - OY}..${by1 - OY}` });
    }
    islands.boxes.sort((a, b) => b.n - a.n);
    return sizes.sort((a, b) => b - a);
  };
  const looks = [];
  const withStyle = (name, patch) => { const s = Object.assign({}, pl.style || R.styleDefault(), patch); const l = R.lookFromStyle(s, false); l.seedStr = (pl.look.seedStr || 'p') + '-' + name; if (pl.look.aged) l.aged = pl.look.aged; return { name, look: l, coat: !!l.duster }; };
  looks.push({ name: 'player', look: pl.look, coat: !!pl.look.duster });
  for (const j of ['duster', 'duster_black', 'duster_red']) if (ST.jackets[j]) looks.push(withStyle(j, { jacket: j }));
  looks.push(withStyle('visor', { hat: 'protohelm' }));
  // a crowd off the street
  const crowd = g.pop.people.filter((q) => q.look).slice(0, 24);
  for (const q of crowd) looks.push({ name: 'npc:' + q.first, look: q.look, coat: !!q.look.duster });
  const bad = { islands: [], outside: [], still: [], coat: [], coatStill: [] };
  const sheet = wantSheet ? document.createElement('canvas') : null;
  if (sheet) { sheet.width = 8 * 4 * 26; sheet.height = Math.min(looks.length, 8) * 34; const sg = sheet.getContext('2d'); sg.fillStyle = '#6a8a5a'; sg.fillRect(0, 0, sheet.width, sheet.height); }
  let frames = 0;
  looks.forEach((L, li) => {
    for (let d8 = 0; d8 < 8; d8++) {
      const stills = [];
      const coatSets = [];
      for (let f = 0; f < 4; f++) {
        const cv = render(L.look, d8, WALKS[f]); frames++;
        if (sheet && li < 8) sheet.getContext('2d').drawImage(cv, OX - 13, OY - 30, 26, 34, (d8 * 4 + f) * 26, li * 34, 26, 34);
        const { m, d } = solid(cv);
        const is = islands(m);
        const total = is.reduce((a, b) => a + b, 0);
        // a Choir halo floats on purpose
        const halo = L.look.xeno && BS2.SPECIES && BS2.SPECIES[L.look.xeno] && BS2.SPECIES[L.look.xeno].feature === 'halo';
        if (is.length > 1 && !halo) bad.islands.push(`${L.name}${L.look.xeno ? '[' + L.look.xeno + ']' : ''}${L.look.hat ? '{hat ' + L.look.hat + '}' : ''} d${d8} f${f}: stray ${islands.boxes.slice(1).map((q) => q.n + 'px @' + q.at).join(', ')}`);
        // outside the sprite's own frame (the hat may rise above it)
        const spr = A.oldSprite(L.look, d8, f === 1 ? 1 : f === 3 ? 2 : 0, null);
        const bob = f === 1 || f === 3 ? 1 : 0;
        const x0 = OX - spr.width / 2, y0 = OY - bob - 25;
        let out = 0;
        for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (m[y * W + x] && (x < x0 - 1 || x >= x0 + spr.width + 1 || y >= y0 + spr.height + 1)) out++;
        if (out) bad.outside.push(`${L.name}${L.look.xeno ? '[' + L.look.xeno + ']' : ''}${L.look.hatKind ? '{' + L.look.hatKind + '}' : ''} d${d8} f${f}: ${out} px outside the body's frame`);
        stills.push(Array.from(m).join(''));
        if (L.coat) {
          // coat pixels: the sprite's jacket shades, below the waist (the lower third of the body)
          const J = new Set((A.oldLook(L.look).jacket || []).map((c) => c.toLowerCase()));
          let n = 0; const set = [];
          for (let y = OY - 8; y < OY; y++) for (let x = 0; x < W; x++) { const i = (y * W + x) * 4; if (d[i + 3] < 200) continue; const c = '#' + ((d[i] << 16) | (d[i + 1] << 8) | d[i + 2]).toString(16).padStart(6, '0'); if (J.has(c)) { n++; set.push(x + ',' + y); } }
          if (n < 3) bad.coat.push(`${L.name} d${d8} f${f}: only ${n} coat px below the waist`);
          coatSets.push(set.join(' '));
        }
      }
      // walking must look different from standing
      if (stills[1] === stills[0] || stills[3] === stills[0]) bad.still.push(`${L.name} d${d8}`);
      // and the coat must move with the stride (side and three-quarter views at least)
      if (L.coat && [0, 1, 3, 4].includes(d8) && coatSets[1] === coatSets[0] && coatSets[3] === coatSets[0]) bad.coatStill.push(`${L.name} d${d8}`);
    }
  });
  return { looks: looks.length, coats: looks.filter((l) => l.coat).length, frames, bad, sheet: sheet ? sheet.toDataURL() : null };
}, !!SHOTS);

const lim = (a) => a.slice(0, process.env.ALL ? 999 : 6).join(' | ') + (a.length > 6 ? ` … (+${a.length - 6})` : '');
check(r.frames > 0 && !r.bad.islands.length, `no stray pixels in ${r.frames} frames (${r.looks} looks × 8 directions × 4 steps)${r.bad.islands.length ? ': ' + lim(r.bad.islands) : ''}`);
check(!r.bad.outside.length, `clothes stay on the body (nothing outside the sprite's frame)${r.bad.outside.length ? ': ' + lim(r.bad.outside) : ''}`);
check(!r.bad.still.length, `every direction animates when walking${r.bad.still.length ? ': ' + lim(r.bad.still) : ''}`);
check(r.coats >= 4 && !r.bad.coat.length, `${r.coats} dusters fall below the waist in every frame${r.bad.coat.length ? ': ' + lim(r.bad.coat) : ''}`);
check(!r.bad.coatStill.length, `the coat moves with the stride${r.bad.coatStill.length ? ': ' + lim(r.bad.coatStill) : ''}`);
if (SHOTS && r.sheet) writeFileSync(join(SHOTS, 'polish_sheet.png'), Buffer.from(r.sheet.split(',')[1], 'base64'));

await b.close();
console.log(log.join('\n'));
if (errs.length) { console.error('ERRORS:\n' + errs.join('\n')); process.exit(1); }
console.log('polish ok');
