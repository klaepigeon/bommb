// Things to read. Each returns { canvas, text } for the reading view; the canvas is also
// used as the object's texture, so what you read is what's on the paper in the room.
import { canvas, rng, noiseCanvas } from './textures.js';

const HAND = '"Segoe Print","Bradley Hand","Comic Sans MS","Chalkboard SE",cursive';
const PRINT = 'Georgia, "Times New Roman", serif';

function paper(w, h, bg = '#e6dcc2', seed = 1) {
  const c = canvas(w, h), g = c.getContext('2d'), r = rng(seed);
  g.fillStyle = bg; g.fillRect(0, 0, w, h);
  g.globalAlpha = 0.22; g.globalCompositeOperation = 'multiply'; g.drawImage(noiseCanvas(256, 6, 4, seed), 0, 0, w, h); g.globalCompositeOperation = 'source-over'; g.globalAlpha = 1;
  // foxing and a damp edge
  for (let i = 0; i < 40; i++) { g.fillStyle = `rgba(140,100,40,${r() * 0.15})`; g.beginPath(); g.arc(r() * w, r() * h, r() * 5, 0, 6.28); g.fill(); }
  const grd = g.createLinearGradient(0, h, 0, h * 0.75); grd.addColorStop(0, 'rgba(120,90,40,0.25)'); grd.addColorStop(1, 'rgba(120,90,40,0)'); g.fillStyle = grd; g.fillRect(0, 0, w, h);
  return { c, g, r };
}
function handLines(g, lines, x, y, size, col = 'rgba(30,35,70,0.85)', lh = 1.45, r = Math.random) {
  g.font = `${size}px ${HAND}`; g.fillStyle = col; g.textBaseline = 'top';
  lines.forEach((l, i) => { g.save(); g.translate(x + (r() - 0.5) * 4, y + i * size * lh); g.rotate((r() - 0.5) * 0.012); g.fillText(l, 0, 0); g.restore(); });
}
function wrap(g, text, maxW) {
  const out = []; for (const para of text.split('\n')) { let line = ''; for (const w of para.split(' ')) { const t = line ? line + ' ' + w : w; if (g.measureText(t).width > maxW && line) { out.push(line); line = w; } else line = t; } out.push(line); }
  return out;
}
const memo = {};
const once = (k, f) => () => memo[k] || (memo[k] = f());

// ---------------------------------------------------------------- the fridge note (Marta to Ilya)
export const fridgeNote = once('fridge', () => {
  const { c, g, r } = paper(520, 640, '#ece4cf', 3);
  g.strokeStyle = 'rgba(120,140,190,0.35)'; for (let y = 70; y < 640; y += 34) { g.beginPath(); g.moveTo(0, y); g.lineTo(520, y); g.stroke(); }
  const text = [
    'Ilya —',
    '',
    'they are saying the buses go',
    'from the school yard at six.',
    'One bag each. Documents.',
    '',
    'If you get home and we are',
    'gone, do not wait here for us.',
    'Do NOT drink from the tap.',
    'Not even boiled.',
    '',
    'Sonya made you a drawing.',
    "It's on the table.",
    '',
    '                     — M.',
  ];
  handLines(g, text, 34, 44, 26, 'rgba(25,30,80,0.88)', 1.3, r);
  return { canvas: c, text: text.join('\n').replace(/ {2,}/g, ' ') };
});

// ---------------------------------------------------------------- the box-room note (pencil, someone else)
export const denNote = once('den', () => {
  const { c, g, r } = paper(560, 720, '#d8ceb4', 9);
  const lines = [
    'Day 23?',
    '',
    'Water came on again for an hour.',
    'Brown, then clear. I did not drink it.',
    '',
    'The knocking answered me tonight.',
    'Three, then three.',
    'I did not knock back.',
    '',
    'Whoever is upstairs walks all night',
    'but there is nobody upstairs. I went',
    'up to 51. The door is open and the',
    'rooms are empty and the dust on the',
    'floor has no footprints in it.',
    '',
    "I'll wait for them here. This was",
    'the only room with a bolt.',
    '',
    'Somebody has bolted it.',
    'From the other side.',
  ];
  handLines(g, lines, 30, 36, 22, 'rgba(50,48,46,0.78)', 1.5, r);
  // pencil smudges, a crossed-out line
  g.fillStyle = 'rgba(60,60,60,0.12)'; g.fillRect(28, 36 + 22 * 1.5 * 9 - 2, 380, 30);
  return { canvas: c, text: lines.join('\n') };
});

// ---------------------------------------------------------------- Sonya's notebook
export const sonyaBook = once('sonya', () => {
  const { c, g, r } = paper(560, 680, '#efe9d8', 21);
  g.strokeStyle = 'rgba(150,160,200,0.45)';
  for (let y = 0; y < 680; y += 22) { g.beginPath(); g.moveTo(0, y); g.lineTo(560, y); g.stroke(); }
  for (let x = 0; x < 560; x += 22) { g.beginPath(); g.moveTo(x, 0); g.lineTo(x, 680); g.stroke(); }
  g.strokeStyle = 'rgba(200,60,60,0.5)'; g.beginPath(); g.moveTo(60, 0); g.lineTo(60, 680); g.stroke();
  const lines = [
    'Sonya   2nd class',
    '',
    'My papa works at the plant',
    'at night. In the night the',
    'house talks. Mama says it is',
    'only the pipes. The pipes',
    'say things in knocks. I can',
    'count them.',
    '',
    'Grandad Pavel said if you',
    'knock back they know which',
    'flat you are in.',
    '',
    'So I dont.',
  ];
  handLines(g, lines, 72, 30, 25, 'rgba(30,50,140,0.85)', 1.32, r);
  g.font = `bold 40px ${HAND}`; g.fillStyle = 'rgba(200,40,40,0.75)'; g.fillText('4', 460, 600); // the teacher's mark
  return { canvas: c, text: lines.join('\n') };
});

// ---------------------------------------------------------------- Sonya's drawing for her dad (found in the box room)
export const drawing = once('drawing', () => {
  const { c, g, r } = paper(640, 460, '#f2eee2', 33);
  g.lineCap = 'round'; g.lineJoin = 'round';
  const scrib = (col, w, pts) => { g.strokeStyle = col; g.lineWidth = w; g.beginPath(); pts.forEach(([x, y], i) => (i ? g.lineTo(x + (r() - 0.5) * 3, y + (r() - 0.5) * 3) : g.moveTo(x, y))); g.stroke(); };
  // sun, ground
  scrib('rgba(240,190,30,0.9)', 6, Array.from({ length: 30 }, (_, i) => [560 + Math.cos(i / 4) * 40, 70 + Math.sin(i / 4) * 40]));
  scrib('rgba(60,150,60,0.8)', 10, [[0, 410], [640, 400]]);
  // the plant: a building with three chimneys
  g.strokeStyle = 'rgba(80,80,90,0.9)'; g.lineWidth = 4; g.strokeRect(330, 240, 200, 160);
  for (const x of [360, 420, 480]) { g.strokeRect(x, 140, 22, 100); scrib('rgba(120,120,120,0.6)', 8, [[x + 11, 135], [x + 25, 100], [x + 5, 70], [x + 30, 40]]); }
  g.font = `28px ${HAND}`; g.fillStyle = 'rgba(80,80,90,0.9)'; g.fillText('ZAVOD 3', 360, 330);
  // papa, big, and a small girl holding his hand
  const person = (x, s, col) => { g.strokeStyle = col; g.lineWidth = 4; g.beginPath(); g.arc(x, 400 - 150 * s, 20 * s, 0, 6.28); g.stroke(); scrib(col, 4, [[x, 400 - 130 * s], [x, 400 - 60 * s], [x - 25 * s, 400]]); scrib(col, 4, [[x, 400 - 60 * s], [x + 25 * s, 400]]); scrib(col, 4, [[x - 35 * s, 400 - 110 * s], [x + 35 * s, 400 - 110 * s]]); };
  person(150, 1.4, 'rgba(40,60,150,0.9)'); person(240, 0.8, 'rgba(200,60,90,0.9)');
  g.font = `30px ${HAND}`; g.fillStyle = 'rgba(200,40,40,0.85)'; g.fillText('PAPA', 110, 120); g.fillText('ME', 220, 250);
  g.font = `22px ${HAND}`; g.fillStyle = 'rgba(40,60,150,0.85)'; g.fillText('come home soon', 40, 445);
  // folded, then unfolded, then folded again many times
  g.fillStyle = 'rgba(0,0,0,0.08)'; g.fillRect(318, 0, 4, 460); g.fillRect(0, 228, 640, 4);
  return { canvas: c, text: '(A crayon drawing. A tall man and a girl holding hands in front of a building with three chimneys: ZAVOD 3. "PAPA". "ME". Underneath: "come home soon".)\n\nIt has been folded and unfolded so many times it is soft as cloth.' };
});

// ---------------------------------------------------------------- the kitchen calendar
export const calendar = once('calendar', () => {
  const W = 520, H = 700;
  const { c, g, r } = paper(W, H, '#e9e2cc', 41);
  // top half: a picture (the Kerzhansk embankment, faded)
  const grd = g.createLinearGradient(0, 0, 0, 300); grd.addColorStop(0, '#8fa0a8'); grd.addColorStop(1, '#c0b090'); g.fillStyle = grd; g.fillRect(20, 20, W - 40, 280);
  g.fillStyle = 'rgba(70,80,90,0.7)'; for (let i = 0; i < 12; i++) g.fillRect(30 + i * 40, 190 - r() * 80, 30, 120);
  g.fillStyle = 'rgba(90,110,120,0.6)'; g.fillRect(20, 250, W - 40, 50);
  g.font = `italic 15px ${PRINT}`; g.fillStyle = '#3a3428'; g.fillText('Kerzhansk. The embankment at evening.', 30, 322);
  g.font = `bold 34px ${PRINT}`; g.fillStyle = '#6a1a14'; g.textAlign = 'center'; g.fillText('OCTOBER', W / 2, 370); g.textAlign = 'left';
  const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  g.font = `bold 15px ${PRINT}`; g.fillStyle = '#3a3428'; days.forEach((d, i) => g.fillText(d, 38 + i * 66, 400));
  const cell = (d) => { const i = d + 2 - 1; return [24 + (i % 7) * 66, 412 + Math.floor(i / 7) * 52]; }; // the 1st is a Wednesday
  g.strokeStyle = 'rgba(60,50,40,0.35)';
  for (let d = 1; d <= 31; d++) {
    const [x, y] = cell(d); g.strokeRect(x, y, 66, 52);
    g.font = `16px ${PRINT}`; g.fillStyle = (d + 2) % 7 === 0 || (d + 1) % 7 === 0 ? '#8a2a1a' : '#3a3428'; g.fillText(String(d), x + 5, y + 18);
    if (d <= 14) { g.strokeStyle = 'rgba(30,30,60,0.6)'; g.lineWidth = 2; g.beginPath(); g.moveTo(x + 8, y + 8); g.lineTo(x + 58, y + 46); g.moveTo(x + 58, y + 8); g.lineTo(x + 8, y + 46); g.stroke(); g.lineWidth = 1; g.strokeStyle = 'rgba(60,50,40,0.35)'; }
  }
  const note = (d, t, col = 'rgba(25,30,90,0.9)') => { const [x, y] = cell(d); g.font = `12px ${HAND}`; g.fillStyle = col; t.split('|').forEach((l, i) => g.fillText(l, x + 4, y + 32 + i * 11)); };
  note(3, 'S. doctor'); note(4, 'I. nights'); note(5, 'I. nights'); note(6, 'water off'); note(7, 'water off'); note(9, 'DO NOT|drink', 'rgba(170,20,20,0.95)');
  note(10, 'I. nights'); note(11, 'I. nights'); note(12, 'no light'); note(13, 'meeting|yard 7pm');
  { const [x, y] = cell(15); g.strokeStyle = 'rgba(170,20,20,0.9)'; g.lineWidth = 3; g.beginPath(); g.ellipse(x + 33, y + 26, 30, 23, 0, 0, 6.28); g.stroke(); g.lineWidth = 1; note(15, 'BUS 6:00|school', 'rgba(170,20,20,0.95)'); }
  { const [x, y] = cell(22); g.font = `12px ${HAND}`; g.fillStyle = 'rgba(30,30,30,0.8)'; g.fillText('Sonya 8', x + 6, y + 36); g.strokeStyle = 'rgba(200,60,90,0.8)'; g.beginPath(); g.arc(x + 50, y + 15, 7, 0, 6.28); g.stroke(); }
  return {
    canvas: c,
    text: 'OCTOBER. Every day crossed through up to the 14th.\n3 — S. doctor · 4, 5, 10, 11 — I. nights · 6, 7 — water off · 9 — DO NOT drink (red) · 12 — no light · 13 — meeting, yard 7pm\n15 — circled hard in red: BUS 6:00 school\n22 — Sonya 8, with a little drawn balloon.\n\nNothing after the 15th is crossed out.',
  };
});

// ---------------------------------------------------------------- evacuation notice (glued inside the front door)
export const notice = once('notice', () => {
  const { c, g } = paper(520, 720, '#e2dccb', 51);
  g.textAlign = 'center'; g.fillStyle = '#1e1a16';
  g.font = `bold 20px ${PRINT}`; g.fillText('DISTRICT EXECUTIVE COMMITTEE', 260, 60);
  g.font = `15px ${PRINT}`; g.fillText('Leninsky District · Kerzhansk', 260, 84);
  g.font = `bold 44px ${PRINT}`; g.fillText('NOTICE', 260, 150);
  g.textAlign = 'left'; g.font = `17px ${PRINT}`;
  const body = 'To all residents of Buildings 12, 14 and 16, Ulitsa Gagarina. By order of the Committee a temporary relocation of residents will take place on 15 October beginning 06:00. Residents must assemble in the yard of School No. 9 with identity documents and ONE bag per person. Pets may not be brought. Do not lock your apartments. Leave interior doors open to permit inspection. Until relocation: do not use tap water for drinking, cooking or washing. Do not use the lifts. Do not go down to the basements. Remain calm. The measure is precautionary and residents will be informed of their return.';
  const lines = wrap(g, body, 440); lines.forEach((l, i) => g.fillText(l, 40, 200 + i * 26));
  g.font = `italic 15px ${PRINT}`; g.fillText('Chairman — signature illegible', 40, 200 + lines.length * 26 + 40);
  // torn corner, someone's handwriting across the bottom
  g.fillStyle = '#0e0c0a'; g.beginPath(); g.moveTo(520, 600); g.lineTo(440, 720); g.lineTo(520, 720); g.fill();
  g.font = `22px ${HAND}`; g.fillStyle = 'rgba(30,30,60,0.85)'; g.fillText('47 — 3 people. Sokolov.', 50, 660);
  return { canvas: c, text: 'NOTICE — District Executive Committee, Leninsky District.\n\n' + body + '\n\nHandwritten at the bottom: "47 — 3 people. Sokolov." The bottom corner is torn away.' };
});

// ---------------------------------------------------------------- newspaper
export const paperFront = once('newspaper', () => {
  const W = 640, H = 860; const { c, g, r } = paper(W, H, '#d9d1bc', 61);
  g.fillStyle = '#1c1a17'; g.textAlign = 'center';
  g.font = `bold 52px ${PRINT}`; g.fillText('VECHERNY KERZHANSK', W / 2, 70);
  g.font = `14px ${PRINT}`; g.fillText('Evening edition · 12 October · Price 2 kop.', W / 2, 96);
  g.fillRect(30, 108, W - 60, 3);
  g.font = `bold 30px ${PRINT}`;
  wrap(g, 'Water supply "safe", says Committee', W - 80).forEach((l, i) => g.fillText(l, W / 2, 150 + i * 34));
  g.font = `italic 17px ${PRINT}`; g.fillText('Residents of districts 4–7 asked to remain calm', W / 2, 225);
  g.textAlign = 'left'; g.font = `13px ${PRINT}`;
  const col = (x, y, w, n) => { for (let i = 0; i < n; i++) { const len = w * (0.6 + r() * 0.4); g.fillStyle = `rgba(30,28,24,${0.35 + r() * 0.2})`; g.fillRect(x, y + i * 15, i % 9 === 8 ? len * 0.4 : len, 7); } };
  col(30, 250, 180, 30); col(230, 250, 180, 18); col(430, 250, 180, 30);
  // photo: a queue at a water bowser
  g.fillStyle = '#6a665e'; g.fillRect(230, 530, 180, 130); g.fillStyle = '#2a2824'; for (let i = 0; i < 9; i++) g.fillRect(240 + i * 18, 600 - r() * 20, 10, 60);
  g.fillStyle = '#4a4640'; g.fillRect(330, 560, 70, 40);
  g.font = `italic 11px ${PRINT}`; g.fillStyle = '#2a2824'; wrap(g, 'Residents on Ulitsa Gagarina collect water from a tanker. Photo: V. Orlov', 180).forEach((l, i) => g.fillText(l, 230, 678 + i * 13));
  g.font = `bold 18px ${PRINT}`; g.fillStyle = '#1c1a17'; g.fillText('Third night of power cuts', 30, 740); g.fillText('in the Leninsky district', 30, 762);
  col(30, 780, 300, 5);
  g.font = `bold 16px ${PRINT}`; g.fillText('Plant No. 3: night shift', 360, 740); g.fillText('"continues as normal"', 360, 760);
  col(360, 780, 250, 5);
  return { canvas: c, text: 'VECHERNY KERZHANSK — 12 October.\n\nWATER SUPPLY "SAFE", SAYS COMMITTEE. Residents of districts 4–7 asked to remain calm.\n\n(photo) Residents on Ulitsa Gagarina collect water from a tanker.\n\nThird night of power cuts in the Leninsky district.\nPlant No. 3: night shift "continues as normal".' };
});

// ---------------------------------------------------------------- prescription label / box
export const prescription = once('rx', () => {
  const { c, g } = paper(420, 260, '#f0ece2', 71);
  g.fillStyle = '#1e1a16'; g.font = `bold 18px ${PRINT}`; g.fillText('Pharmacy No. 22', 20, 34);
  g.font = `15px ${PRINT}`; g.fillText('Sokolova S. I.   (7 yrs)', 20, 70); g.fillText('Salbutamol inhaler, 100 mcg', 20, 100); g.fillText('2 puffs as needed. Not more than 8 a day.', 20, 128);
  g.font = `18px ${HAND}`; g.fillStyle = 'rgba(30,30,90,0.9)'; g.fillText('last one — get more Mon!', 20, 190);
  return { canvas: c, text: 'Pharmacy No. 22 — Sokolova S. I. (7 yrs). Salbutamol inhaler, 100 mcg. 2 puffs as needed.\n\nIn biro across the bottom: "last one — get more Mon!"\n\nThe inhaler beside it is empty.' };
});
export const workPass = once('pass', () => {
  const { c, g } = paper(420, 270, '#d8dccc', 81);
  g.fillStyle = '#2a3a2a'; g.fillRect(0, 0, 420, 50); g.fillStyle = '#e8e8d8'; g.font = `bold 20px ${PRINT}`; g.fillText('PLANT No. 3 · PASS', 20, 34);
  g.fillStyle = '#9a9a8a'; g.fillRect(24, 70, 110, 140); g.fillStyle = '#5a5246'; g.beginPath(); g.ellipse(79, 125, 30, 38, 0, 0, 6.28); g.fill();
  g.fillStyle = '#1e1a16'; g.font = `17px ${PRINT}`; g.fillText('SOKOLOV I. P.', 150, 95); g.fillText('Shop 4 · Night shift', 150, 125); g.fillText('No. 03-1187', 150, 155);
  g.font = `italic 13px ${PRINT}`; g.fillText('Valid to: Dec.', 150, 190);
  g.strokeStyle = 'rgba(160,30,30,0.7)'; g.lineWidth = 3; g.beginPath(); g.arc(320, 215, 34, 0, 6.28); g.stroke();
  return { canvas: c, text: 'PLANT No. 3 — PASS. SOKOLOV I. P., Shop 4, Night shift. No. 03-1187.\n\nThe photograph has been rubbed almost blank by a thumb.' };
});
export const photoBack = (who) => ({ canvas: null, text: who });
