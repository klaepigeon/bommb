// The building's sound. Everything is synthesised at start-up (no samples): wind through
// the broken panes, the city a long way down, the pipes, the drips, the buzz of the one
// tube still lit, sirens, and the flat upstairs, where somebody is still walking about.
// Positional sources go through HRTF panners and a crude occlusion filter: a sound in
// another room is muffled by how many walls are in the way.
import * as THREE from 'three';
import { roomAt } from './plan.js';
import { G } from './core.js';

let ctx = null, master, wet, dry, comp;
const G_rumble = (s, ms) => window.__G?.rumble?.(s, ms);
const buffers = {};
const loops = [];
export const AUDIO = { ready: false, listenerRoom: null, listener: new THREE.Vector3() };

// ---------------------------------------------------------------- synthesis helpers
function buf(sec, fn, ch = 1) {
  const sr = ctx.sampleRate, n = Math.floor(sec * sr), b = ctx.createBuffer(ch, n, sr);
  for (let c = 0; c < ch; c++) { const d = b.getChannelData(c); fn(d, sr, c); }
  return b;
}
const noise = () => Math.random() * 2 - 1;
function lp(d, a) { let y = 0; for (let i = 0; i < d.length; i++) { y += a * (d[i] - y); d[i] = y; } return d; }
function hp(d, a) { let y = 0, x0 = 0; for (let i = 0; i < d.length; i++) { const x = d[i]; y = a * (y + x - x0); x0 = x; d[i] = y; } return d; }
function norm(d, peak = 0.9) { let m = 0; for (let i = 0; i < d.length; i++) m = Math.max(m, Math.abs(d[i])); if (m > 0) for (let i = 0; i < d.length; i++) d[i] *= peak / m; return d; }
// resonant 2-pole bandpass
function bp(d, sr, f, q) {
  const w = 2 * Math.PI * f / sr, al = Math.sin(w) / (2 * q), b0 = al, a0 = 1 + al, a1 = -2 * Math.cos(w), a2 = 1 - al;
  let x1 = 0, x2 = 0, y1 = 0, y2 = 0;
  for (let i = 0; i < d.length; i++) { const x = d[i]; const y = (b0 * x - b0 * x2 - a1 * y1 - a2 * y2) / a0; x2 = x1; x1 = x; y2 = y1; y1 = y; d[i] = y; }
  return d;
}
const env = (t, a, dcy) => (t < a ? t / a : Math.exp(-(t - a) / dcy));

function makeBuffers() {
  const B = buffers;
  // door creak: stick-slip friction, a wandering squeal
  B.doorCreak = buf(1.3, (d, sr) => {
    let ph = 0, f = 340 + Math.random() * 120;
    for (let i = 0; i < d.length; i++) {
      const t = i / sr; f += (Math.random() - 0.5) * 6 + Math.sin(t * 7) * 1.2;
      ph += f / sr; const stick = Math.sin(t * (30 + Math.sin(t * 3) * 12) * 6.283) > 0.2 ? 1 : 0.25;
      d[i] = (Math.sin(ph * 6.283) * 0.6 + Math.sin(ph * 6.283 * 2.01) * 0.3 + noise() * 0.15) * stick * env(t, 0.08, 0.6) * (t < 1.1 ? 1 : (1.3 - t) * 5);
    }
    bp(d, sr, 900, 0.7); norm(d, 0.5);
  });
  B.doorScrape = buf(0.9, (d, sr) => { for (let i = 0; i < d.length; i++) { const t = i / sr; d[i] = noise() * env(t, 0.05, 0.35) * (0.6 + 0.4 * Math.sin(t * 90)); } lp(d, 0.08); norm(d, 0.6); });
  const thump = (f, dec, click, amp) => (d, sr) => { for (let i = 0; i < d.length; i++) { const t = i / sr; d[i] = Math.sin(6.283 * f * t * (1 - t * 0.4)) * Math.exp(-t / dec) + noise() * Math.exp(-t / click) * 0.6; } lp(d, 0.3); norm(d, amp); };
  B.doorShut = buf(0.6, thump(90, 0.09, 0.012, 0.8));
  B.doorHeavy = buf(0.9, thump(60, 0.15, 0.02, 0.9));
  B.doorStuck = buf(0.5, thump(120, 0.05, 0.01, 0.6));
  B.click = buf(0.06, (d, sr) => { for (let i = 0; i < d.length; i++) { const t = i / sr; d[i] = (noise() * 0.5 + Math.sin(t * 6.283 * 2200)) * Math.exp(-t / 0.006); } norm(d, 0.5); });
  B.switch = buf(0.12, (d, sr) => { for (let i = 0; i < d.length; i++) { const t = i / sr; d[i] = (noise() * 0.6 + Math.sin(t * 6.283 * 1500)) * (Math.exp(-t / 0.004) + (t > 0.03 ? Math.exp(-(t - 0.03) / 0.005) * 0.6 : 0)); } norm(d, 0.5); });
  const metalHit = (fs, dec) => (d, sr) => { for (let i = 0; i < d.length; i++) { const t = i / sr; let v = 0; fs.forEach((f, k) => { v += Math.sin(6.283 * f * t) * Math.exp(-t / (dec / (1 + k * 0.6))) / (1 + k); }); d[i] = v + noise() * Math.exp(-t / 0.003) * 0.5; } norm(d, 0.7); };
  B.chainRattle = buf(0.7, (d, sr) => { const hits = [0, 0.05, 0.09, 0.16, 0.2, 0.31, 0.38, 0.45]; for (const h of hits) { const f = 2500 + Math.random() * 2500, s0 = Math.floor((h + Math.random() * 0.02) * sr); for (let i = 0; i < sr * 0.06 && s0 + i < d.length; i++) { const t = i / sr; d[s0 + i] += (Math.sin(6.283 * f * t) + Math.sin(6.283 * f * 1.47 * t) * 0.6) * Math.exp(-t / 0.012) * (0.4 + Math.random() * 0.6); } } norm(d, 0.5); });
  B.bolt = buf(0.5, (d, sr) => { for (let i = 0; i < d.length; i++) { const t = i / sr; d[i] = (t < 0.3 ? noise() * 0.3 * (0.5 + Math.sin(t * 200)) : 0) + (t > 0.3 ? metalHitS(t - 0.3) : 0); } bp(d, sr, 1800, 0.8); norm(d, 0.6); });
  function metalHitS(t) { return (Math.sin(6.283 * 1400 * t) + Math.sin(6.283 * 2170 * t) * 0.6) * Math.exp(-t / 0.03); }
  B.drawer = buf(0.55, (d, sr) => { for (let i = 0; i < d.length; i++) { const t = i / sr; d[i] = noise() * (t < 0.4 ? 0.5 * (0.6 + 0.4 * Math.sin(t * 140)) : 0) * env(t, 0.03, 0.4) + (t > 0.4 ? Math.sin(6.283 * 140 * t) * Math.exp(-(t - 0.4) / 0.03) : 0); } bp(d, sr, 600, 0.6); norm(d, 0.55); });
  B.cabinet = buf(0.6, (d, sr) => { let ph = 0; for (let i = 0; i < d.length; i++) { const t = i / sr; ph += (700 + Math.sin(t * 40) * 80) / sr; d[i] = Math.sin(ph * 6.283) * env(t, 0.05, 0.15) * 0.4 + noise() * 0.1 * env(t, 0.01, 0.2); } bp(d, sr, 1100, 0.9); norm(d, 0.4); });
  B.pickup = buf(0.25, (d, sr) => { for (let i = 0; i < d.length; i++) { const t = i / sr; d[i] = noise() * env(t, 0.02, 0.07); } bp(d, sr, 2500, 0.7); norm(d, 0.3); });
  B.wood = buf(0.35, thump(180, 0.05, 0.006, 0.7));
  B.woodHeavy = buf(0.6, thump(90, 0.12, 0.01, 0.9));
  B.metal = buf(0.9, metalHit([520, 1310, 2290, 3410], 0.25));
  B.can = buf(0.4, metalHit([1250, 2840, 4100], 0.08));
  B.glassTink = buf(0.5, metalHit([3200, 5100, 7300], 0.06));
  B.glassBreak = buf(1.2, (d, sr) => { for (let k = 0; k < 40; k++) { const s0 = Math.floor(Math.pow(Math.random(), 2) * 0.8 * sr), f = 2500 + Math.random() * 6000; for (let i = 0; i < sr * 0.08 && s0 + i < d.length; i++) { const t = i / sr; d[s0 + i] += Math.sin(6.283 * f * t) * Math.exp(-t / 0.015) * (1 - s0 / d.length); } } for (let i = 0; i < 4000; i++) d[i] += noise() * (1 - i / 4000); norm(d, 0.6); });
  B.paper = buf(0.3, (d, sr) => { for (let i = 0; i < d.length; i++) { const t = i / sr; d[i] = noise() * env(t, 0.01, 0.1) * (Math.random() < 0.3 ? 1 : 0.3); } hp(d, 0.9); norm(d, 0.25); });
  B.soft = buf(0.3, thump(110, 0.03, 0.02, 0.4));
  B.board = buf(1.0, (d, sr) => { for (let i = 0; i < d.length; i++) { const t = i / sr; d[i] = noise() * env(t, 0.005, 0.05) * 1.5 + (t > 0.05 && t < 0.6 ? Math.sin(6.283 * (900 - t * 600) * t) * 0.3 * Math.sin(t * 60) : 0) + (t > 0.7 ? Math.sin(6.283 * 150 * t) * Math.exp(-(t - 0.7) / 0.05) : 0); } norm(d, 0.7); });
  // pipe knock: a struck iron pipe full of water — dull, ringing low
  B.knock = buf(0.8, (d, sr) => { for (let i = 0; i < d.length; i++) { const t = i / sr; d[i] = (Math.sin(6.283 * 165 * t) + Math.sin(6.283 * 412 * t) * 0.45 + Math.sin(6.283 * 797 * t) * 0.2) * Math.exp(-t / 0.14) + noise() * Math.exp(-t / 0.004) * 0.8; } lp(d, 0.4); norm(d, 0.85); });
  B.drip = buf(0.25, (d, sr) => { let ph = 0; for (let i = 0; i < d.length; i++) { const t = i / sr; ph += (1500 * Math.exp(-t * 40) + 500) / sr; d[i] = Math.sin(ph * 6.283) * Math.exp(-t / 0.03); } norm(d, 0.4); });
  B.dripWater = buf(0.3, (d, sr) => { let ph = 0; for (let i = 0; i < d.length; i++) { const t = i / sr; ph += (900 * Math.exp(-t * 25) + 400) / sr; d[i] = Math.sin(ph * 6.283) * Math.exp(-t / 0.05) + noise() * Math.exp(-t / 0.004) * 0.2; } norm(d, 0.45); });
  // building creak: a long low structural groan
  B.creak = buf(2.6, (d, sr) => { for (let i = 0; i < d.length; i++) d[i] = noise(); const f0 = 70 + Math.random() * 60; const e = new Float32Array(d.length); for (let i = 0; i < d.length; i++) { const t = i / sr; e[i] = env(t, 0.6, 0.9) * (0.6 + 0.4 * Math.sin(t * 13)); } bp(d, sr, f0, 6); bp(d, sr, f0 * 1.02, 4); for (let i = 0; i < d.length; i++) d[i] *= e[i]; norm(d, 0.7); });
  B.groan = buf(3.5, (d, sr) => { let ph = 0; for (let i = 0; i < d.length; i++) { const t = i / sr; ph += (48 + Math.sin(t * 0.9) * 9 + noise() * 3) / sr; d[i] = (Math.sin(ph * 6.283) + noise() * 0.4) * env(t, 1.0, 1.2); } lp(d, 0.05); norm(d, 0.7); });
  // something heavy dragged over a floor
  B.drag = buf(2.2, (d, sr) => { for (let i = 0; i < d.length; i++) { const t = i / sr; const stick = (Math.sin(t * 6.283 * (6 + Math.sin(t * 2) * 2)) > -0.2) ? 1 : 0.2; d[i] = noise() * stick * env(t, 0.2, 0.8); } lp(d, 0.05); norm(d, 0.8); });
  B.stepAbove = buf(0.35, thump(55, 0.06, 0.02, 0.9));
  B.thudFar = buf(1.2, thump(40, 0.25, 0.05, 0.9));
  B.scratch = buf(1.8, (d, sr) => { for (let i = 0; i < d.length; i++) { const t = i / sr; const burst = Math.max(0, Math.sin(t * 6.283 * 3.3)) ** 4; d[i] = noise() * burst * env(t, 0.1, 1.2); } bp(d, sr, 2200, 1.2); norm(d, 0.5); });
  B.tvOn = buf(0.5, (d, sr) => { for (let i = 0; i < d.length; i++) { const t = i / sr; d[i] = noise() * Math.exp(-t / 0.02) + Math.sin(6.283 * 15600 * t) * 0.2 * Math.exp(-t / 0.3) + Math.sin(6.283 * 60 * t) * Math.exp(-t / 0.08); } norm(d, 0.5); });
  B.plug = buf(2.5, (d, sr) => { for (let i = 0; i < d.length; i++) { const t = i / sr; d[i] = noise() * (0.5 + 0.5 * Math.sin(t * 6.283 * 3.7)) * env(t, 0.1, 1.5); } lp(d, 0.06); bp(d, sr, 250, 1.5); norm(d, 0.6); });
  // the sting: a low cluster swelling, a metal shriek over it, cut off
  B.sting = buf(3.2, (d, sr) => { let a = 0, b2 = 0, c = 0; for (let i = 0; i < d.length; i++) { const t = i / sr; a += 55 / sr; b2 += 58.3 / sr; c += (1900 + Math.sin(t * 13) * 300 + t * 400) / sr; const sw = Math.min(1, t / 0.15) * (t < 2.6 ? 1 : Math.max(0, 1 - (t - 2.6) / 0.6)); d[i] = sw * ((Math.sin(a * 6.283) + Math.sin(b2 * 6.283)) * 0.5 + Math.sin(c * 6.283) * 0.18 * Math.min(1, t / 0.6) + noise() * 0.08); } norm(d, 0.95); });
  B.heart = buf(0.9, (d, sr) => { for (let i = 0; i < d.length; i++) { const t = i / sr; const th = (t0) => (t > t0 ? Math.sin(6.283 * 48 * (t - t0)) * Math.exp(-(t - t0) / 0.06) : 0); d[i] = th(0) + th(0.22) * 0.7; } lp(d, 0.2); norm(d, 0.9); });
  B.breath = buf(1.6, (d, sr) => { for (let i = 0; i < d.length; i++) { const t = i / sr; d[i] = noise() * Math.sin(Math.min(1, t / 1.6) * Math.PI) ** 2; } bp(d, sr, 900, 0.8); norm(d, 0.35); });
  // footsteps per surface
  const step = (lo, click, crunch, amp) => (d, sr) => { for (let i = 0; i < d.length; i++) { const t = i / sr; d[i] = Math.sin(6.283 * lo * t) * Math.exp(-t / 0.035) * 0.8 + noise() * Math.exp(-t / click) * 0.6 + (crunch ? noise() * (Math.random() < 0.06 ? 1 : 0) * Math.exp(-t / 0.08) * crunch : 0); } norm(d, amp); };
  B.step_wood = [0, 1, 2].map(() => buf(0.22, step(95, 0.01, 0, 0.5)));
  B.step_lino = [0, 1, 2].map(() => buf(0.2, step(120, 0.006, 0, 0.35)));
  B.step_tile = [0, 1, 2].map(() => buf(0.2, step(160, 0.004, 0.2, 0.45)));
  B.step_concrete = [0, 1, 2].map(() => buf(0.25, step(110, 0.008, 0.6, 0.5)));
  B.step_debris = [0, 1, 2].map(() => buf(0.32, step(90, 0.015, 1.4, 0.55)));
  B.step_glass = [0, 1, 2].map(() => buf(0.32, step(130, 0.006, 2.0, 0.5)));
  B.boardCreak = [0, 1].map(() => buf(0.5, (d, sr) => { let ph = 0, f = 220 + Math.random() * 200; for (let i = 0; i < d.length; i++) { const t = i / sr; f += (Math.random() - 0.5) * 4; ph += f / sr; d[i] = Math.sin(ph * 6.283) * env(t, 0.06, 0.15) * (Math.sin(t * 6.283 * 45) > 0 ? 1 : 0.3); } bp(d, sr, 500, 1); norm(d, 0.25); }));
}

// impulse response: a small hard room, plus a long dark tail for "the building"
function impulse(sec, decay, dark) {
  return buf(sec, (d, sr, c) => { for (let i = 0; i < d.length; i++) d[i] = noise() * Math.pow(1 - i / d.length, decay); lp(d, dark); void c; }, 2);
}

// ---------------------------------------------------------------- graph
export function initAudio() {
  if (ctx) { ctx.resume(); return; }
  ctx = new (window.AudioContext || window.webkitAudioContext)();
  comp = ctx.createDynamicsCompressor(); comp.threshold.value = -16; comp.ratio.value = 4;
  master = ctx.createGain(); master.gain.value = 0.9;
  dry = ctx.createGain(); wet = ctx.createGain(); wet.gain.value = 0.35;
  const conv = ctx.createConvolver(); conv.buffer = impulse(1.6, 3, 0.25);
  dry.connect(master); wet.connect(conv); conv.connect(master);
  master.connect(comp); comp.connect(ctx.destination);
  makeBuffers();
  AUDIO.ready = true;
  AUDIO.ctx = ctx;
  startAmbience();
}
export function setMasterVolume(v) { if (master) master.gain.value = v; }
// a dead silence for a few seconds (blackouts), then the building comes back
G.audioDuck = (sec) => { if (!master) return; const t = ctx.currentTime, v = master.gain.value; master.gain.cancelScheduledValues(t); master.gain.setTargetAtTime(0.02, t, 0.15); master.gain.setTargetAtTime(v, t + sec, 0.8); };

// per-source chain: [gain] -> [occlusion lowpass] -> [panner] -> dry + wet
function chain(pos, o = {}) {
  const g = ctx.createGain(); g.gain.value = o.vol ?? 1;
  const f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 20000;
  g.connect(f);
  let out = f;
  if (pos) {
    const p = ctx.createPanner(); p.panningModel = 'HRTF'; p.distanceModel = 'inverse';
    p.refDistance = o.ref ?? 1; p.rolloffFactor = o.rolloff ?? 1.3; p.maxDistance = 200;
    p.positionX.value = pos.x; p.positionY.value = pos.y; p.positionZ.value = pos.z;
    f.connect(p); out = p;
    if (!o.noOcclude) occlude(f, pos, o.room);
  }
  out.connect(dry);
  const s = ctx.createGain(); s.gain.value = o.wet ?? 1; out.connect(s); s.connect(wet);
  return { g, f, out, setPos: (q) => { if (out.positionX) { out.positionX.value = q.x; out.positionY.value = q.y; out.positionZ.value = q.z; } } };
}

// walls in the way, roughly: same room clear; adjacent muffled; across the flat or outside, dull
function occlusionFor(pos, room) {
  const lr = AUDIO.listenerRoom;
  const zn = room ? null : G.zoneAt?.(pos.x, pos.y, pos.z);
  const sr = room ?? (zn ? zn.key : pos.y > 2.9 ? 'above' : pos.y < -0.3 ? 'below' : roomAt(pos.x, pos.z) || 'outside');
  if (sr === lr) return 20000;
  if (sr === 'outside') return lr === 'balcony' ? 20000 : ['living', 'bedroom', 'kitchen'].includes(lr) ? 5000 : 900;
  if (sr === 'above' || sr === 'below') return 700;
  if (sr === 'landing') return lr === 'hall' ? 1500 : String(lr).startsWith('stair') ? 20000 : 500;
  if (String(sr).startsWith('stair') && String(lr).startsWith('stair')) return 9000;
  if (String(sr).startsWith('stair') || String(lr).startsWith('stair')) return lr === 'hall' || sr === 'hall' ? 1500 : 1100;
  if (String(sr).split(':')[0] === String(lr).split(':')[0] && String(sr).includes(':')) return 3000;
  const open = new Set(['living:hall', 'hall:kitchen', 'hall:bedroom', 'living:balcony']);
  if (open.has(`${sr}:${lr}`) || open.has(`${lr}:${sr}`)) return 4000;
  if (sr === 'hall' || lr === 'hall') return 1600;
  return 700;
}
function occlude(filter, pos, room) { filter.frequency.value = occlusionFor(pos, room); filter._pos = pos; filter._room = room; occluders.add(filter); }
const occluders = new Set();

export function sfx(name, pos, o = {}) {
  if (!ctx) return null;
  let b = buffers[name]; if (Array.isArray(b)) b = b[(Math.random() * b.length) | 0];
  if (!b) return null;
  const src = ctx.createBufferSource(); src.buffer = b;
  src.playbackRate.value = (o.rate ?? 1) * (o.jitter === false ? 1 : 0.94 + Math.random() * 0.12);
  const c = chain(pos ? { x: pos.x, y: pos.y, z: pos.z } : null, o);
  src.connect(c.g); src.start(ctx.currentTime + (o.delay || 0));
  src.onended = () => { occluders.delete(c.f); c.g.disconnect(); };
  return src;
}

// a looping node graph (oscillators, noise) feeding a positional chain
function noiseLoop(sec = 4) { return buf(sec, (d) => { for (let i = 0; i < d.length; i++) d[i] = noise(); }); }
function brownLoop(sec = 6) { return buf(sec, (d) => { let y = 0; for (let i = 0; i < d.length; i++) { y = (y + noise() * 0.02) * 0.998; d[i] = y; } norm(d, 0.9); }); }

export function loopSource(kind, pos, o = {}) {
  if (!ctx) return null;
  const c = chain(pos, o);
  const nodes = [];
  if (kind === 'wind') {
    const s = ctx.createBufferSource(); s.buffer = noiseLoop(); s.loop = true;
    const f = ctx.createBiquadFilter(); f.type = 'bandpass'; f.frequency.value = 500; f.Q.value = 0.6;
    const w = ctx.createBiquadFilter(); w.type = 'bandpass'; w.frequency.value = o.whistle || 1300; w.Q.value = 18; // the whistle in the broken pane
    const wg = ctx.createGain(); wg.gain.value = 0.35;
    const gust = ctx.createGain(); gust.gain.value = 0.4;
    s.connect(f); f.connect(gust); s.connect(w); w.connect(wg); wg.connect(gust); gust.connect(c.g);
    s.start(); nodes.push(s);
    c.gust = gust.gain; c.whistle = w.frequency; c.band = f.frequency;
  } else if (kind === 'city') {
    const s = ctx.createBufferSource(); s.buffer = brownLoop(); s.loop = true;
    const f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 260;
    s.connect(f); f.connect(c.g); s.start(); nodes.push(s);
  } else if (kind === 'buzz') {
    const o1 = ctx.createOscillator(); o1.type = 'sawtooth'; o1.frequency.value = 100;
    const o2 = ctx.createOscillator(); o2.type = 'square'; o2.frequency.value = 50;
    const f = ctx.createBiquadFilter(); f.type = 'bandpass'; f.frequency.value = 1200; f.Q.value = 1.2;
    const g2 = ctx.createGain(); g2.gain.value = 0.15;
    o1.connect(f); o2.connect(g2); g2.connect(f); f.connect(c.g); o1.start(); o2.start(); nodes.push(o1, o2);
  } else if (kind === 'static') {
    const s = ctx.createBufferSource(); s.buffer = noiseLoop(2); s.loop = true;
    const f = ctx.createBiquadFilter(); f.type = 'highpass'; f.frequency.value = 900;
    const whine = ctx.createOscillator(); whine.frequency.value = 15625; const wg = ctx.createGain(); wg.gain.value = 0.02;
    s.connect(f); f.connect(c.g); whine.connect(wg); wg.connect(c.g); s.start(); whine.start(); nodes.push(s, whine);
  } else if (kind === 'tone') { // off-hook busy tone, 425 Hz, on/off
    const o1 = ctx.createOscillator(); o1.frequency.value = 425; const gate = ctx.createGain(); gate.gain.value = 0;
    o1.connect(gate); gate.connect(c.g); o1.start(); nodes.push(o1);
    const t0 = ctx.currentTime;
    for (let i = 0; i < 2000; i++) { gate.gain.setValueAtTime(0.25, t0 + i * 0.7); gate.gain.setValueAtTime(0, t0 + i * 0.7 + 0.35); }
  } else if (kind === 'hum') {
    const o1 = ctx.createOscillator(); o1.frequency.value = 50; const o2 = ctx.createOscillator(); o2.frequency.value = 150;
    const g2 = ctx.createGain(); g2.gain.value = 0.3; o1.connect(c.g); o2.connect(g2); g2.connect(c.g); o1.start(); o2.start(); nodes.push(o1, o2);
  } else if (kind === 'flame') {
    const s = ctx.createBufferSource(); s.buffer = noiseLoop(3); s.loop = true;
    const f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 400; s.connect(f); f.connect(c.g); s.start(); nodes.push(s);
  }
  const h = {
    ...c, nodes, pos, base: o.vol ?? 1,
    set(v, ramp = 0.1) { c.g.gain.setTargetAtTime(v, ctx.currentTime, ramp); },
    stop() { nodes.forEach((n) => { try { n.stop(); } catch (e) { /* */ } }); occluders.delete(c.f); c.g.disconnect(); },
  };
  loops.push(h);
  return h;
}

// ---------------------------------------------------------------- ambience director
const P = (x, y, z) => new THREE.Vector3(x, y, z);
let amb = null;
function startAmbience() {
  amb = {
    windLiving: loopSource('wind', P(1.6, 1.6, -0.2), { vol: 0.55, whistle: 1250 }),
    windBed: loopSource('wind', P(5.6, 1.6, -0.2), { vol: 0.25, whistle: 1900 }),
    windBalc: loopSource('wind', P(2.2, 1.5, -3), { vol: 0.5, whistle: 700, room: 'outside' }),
    city: loopSource('city', null, { vol: 0.25 }),
    cityOut: loopSource('city', P(5, -10, -30), { vol: 1.4, ref: 8, rolloff: 0.4, room: 'outside' }),
    hum: loopSource('hum', null, { vol: 0.012 }),
  };
  AUDIO.amb = amb;
  timers.push(
    { t: 4, every: [6, 14], f: () => sfx('dripWater', P(9.85, 0.05, 0.3), { vol: 0.5 }) },          // kitchen riser leak
    { t: 2, every: [1.5, 4], f: () => sfx('dripWater', P(7.7, 0.1, 6.3), { vol: 0.7 }) },          // through the bathroom ceiling
    { t: 6, every: [7, 11], f: () => sfx('drip', P(9.7, 0.9, 1.25), { vol: 0.35 }) },              // kitchen tap
    { t: 20, every: [25, 55], f: () => sfx(Math.random() < 0.6 ? 'creak' : 'groan', P(Math.random() * 10, 2.7, Math.random() * 8), { vol: 0.6, room: 'above' }) },
    { t: 14, every: [30, 70], f: () => knockSeq(P(9.9, 1.5, 0.3), Math.random() < 0.5 ? [3, 3] : [2], 0.5) },
    { t: 40, every: [60, 120], f: siren },
    { t: 30, every: [45, 90], f: walkAbove },
    { t: 55, every: [70, 140], f: () => sfx('drag', P(2 + Math.random() * 6, 3.1, Math.random() * 7), { vol: 0.8, room: 'above' }) },
    { t: 70, every: [60, 110], f: () => sfx('thudFar', P(12, 1, 4.5 + (Math.random() - 0.5) * 6), { vol: 0.7, room: 'landing' }) },
    { t: 90, every: [90, 180], f: stairSteps },
    { t: 120, every: [100, 200], f: () => sfx('scratch', P(Math.random() < 0.5 ? -0.2 : 10.2, 1.0, 5.5 + Math.random() * 2.5), { vol: 0.35, room: 'wall' }) },
    { t: 25, every: [20, 40], f: () => sfx('doorShut', P(-15 + Math.random() * 30, -2 + Math.random() * 10, -30), { vol: 1.2, ref: 6, rolloff: 0.5, room: 'outside' }) },
  );
}
const timers = [];
export function addTimer(t) { timers.push(t); }

export function knockSeq(pos, groups, vol = 0.6, delay = 0) {
  let t = delay;
  const near = AUDIO.listener.distanceTo(pos) < 5;
  for (const n of groups) { for (let i = 0; i < n; i++) { sfx('knock', pos, { vol, delay: t, jitter: false, rate: 0.98 + Math.random() * 0.04, room: 'wall' }); if (near) setTimeout(() => G_rumble(0.35, 90), t * 1000); t += 0.32; } t += 0.75; }
  return t;
}
function walkAbove() {
  let x = 1 + Math.random() * 8, z = 1 + Math.random() * 6; const a = Math.random() * 6.28, n = 6 + (Math.random() * 10 | 0);
  for (let i = 0; i < n; i++) {
    x += Math.cos(a) * 0.7; z += Math.sin(a) * 0.7;
    sfx('stepAbove', P(x, 3.2, z), { vol: 0.9, delay: i * 0.62 + Math.random() * 0.05, room: 'above' });
  }
  // and sometimes, they stop right over you
  if (Math.random() < 0.35 && AUDIO.listener) { const L = AUDIO.listener; sfx('stepAbove', P(L.x, 3.2, L.z), { vol: 1, delay: n * 0.62 + 2.5, room: 'above' }); }
}
function stairSteps() {
  const n = 10 + (Math.random() * 8 | 0), up = Math.random() < 0.5;
  for (let i = 0; i < n; i++) {
    const k = up ? i / n : 1 - i / n;
    sfx('step_concrete', P(12.4, -2 + k * 3.5, 3 + k * 2.5), { vol: 0.9, delay: i * 0.55, room: 'landing' });
  }
}
function siren() {
  if (!ctx) return;
  const pos = P(-200 + Math.random() * 400, 10, -300 - Math.random() * 300);
  const c = chain(pos, { vol: 0.6, ref: 60, rolloff: 0.6, room: 'outside', wet: 2 });
  const o = ctx.createOscillator(); o.type = 'triangle';
  const f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 1400;
  o.connect(f); f.connect(c.g);
  const t0 = ctx.currentTime, dur = 14 + Math.random() * 10;
  c.g.gain.setValueAtTime(0, t0); c.g.gain.linearRampToValueAtTime(0.6, t0 + 3); c.g.gain.setValueAtTime(0.6, t0 + dur - 4); c.g.gain.linearRampToValueAtTime(0, t0 + dur);
  for (let t = 0; t < dur; t += 4) { o.frequency.setValueAtTime(560, t0 + t); o.frequency.linearRampToValueAtTime(980, t0 + t + 2); o.frequency.linearRampToValueAtTime(560, t0 + t + 4); }
  o.start(t0); o.stop(t0 + dur + 0.1);
  o.onended = () => { occluders.delete(c.f); c.g.disconnect(); };
}

// ---------------------------------------------------------------- per frame
const fwd = new THREE.Vector3(), up = new THREE.Vector3();
let occT = 0;
export function updateAudio(camera, dt, room) {
  if (!ctx) return;
  AUDIO.listenerRoom = room;
  const L = ctx.listener, p = camera.getWorldPosition(AUDIO.listener);
  camera.getWorldDirection(fwd); up.set(0, 1, 0).applyQuaternion(camera.quaternion);
  if (L.positionX) {
    const t = ctx.currentTime;
    L.positionX.setTargetAtTime(p.x, t, 0.02); L.positionY.setTargetAtTime(p.y, t, 0.02); L.positionZ.setTargetAtTime(p.z, t, 0.02);
    L.forwardX.setTargetAtTime(fwd.x, t, 0.02); L.forwardY.setTargetAtTime(fwd.y, t, 0.02); L.forwardZ.setTargetAtTime(fwd.z, t, 0.02);
    L.upX.setTargetAtTime(up.x, t, 0.02); L.upY.setTargetAtTime(up.y, t, 0.02); L.upZ.setTargetAtTime(up.z, t, 0.02);
  } else { L.setPosition(p.x, p.y, p.z); L.setOrientation(fwd.x, fwd.y, fwd.z, up.x, up.y, up.z); }
  // re-occlude as the listener moves room to room
  occT -= dt;
  if (occT <= 0) {
    occT = 0.25;
    for (const f of occluders) f.frequency.setTargetAtTime(occlusionFor(f._pos, f._room), ctx.currentTime, 0.2);
  }
  // gusts
  if (amb) {
    const t = ctx.currentTime;
    const gust = 0.35 + 0.3 * Math.sin(t * 0.21) + 0.2 * Math.sin(t * 0.67 + 1) + 0.15 * Math.sin(t * 1.9);
    for (const w of [amb.windLiving, amb.windBed, amb.windBalc]) { w.gust.setTargetAtTime(Math.max(0.05, gust), t, 0.3); w.band.setTargetAtTime(380 + gust * 400, t, 0.3); }
    // the city is louder the closer you are to the courtyard windows
    const outK = p.z < 0 ? 1 : Math.max(0, 1 - p.z / 5);
    amb.city.set(0.08 + 0.25 * outK, 0.5);
  }
  for (const tm of timers) {
    tm.t -= dt;
    if (tm.t <= 0) { tm.t = tm.every ? tm.every[0] + Math.random() * (tm.every[1] - tm.every[0]) : Infinity; tm.f(); }
  }
}
