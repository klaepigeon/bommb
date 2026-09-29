// Tiny synthesized sound effects (no files): square and noise blips in the DS spirit.

let ctx: AudioContext | null = null;
let vol = 0.5;
export function unlockAudio(): void {
  if (ctx) { if (ctx.state === 'suspended') void ctx.resume(); return; }
  try { ctx = new AudioContext(); } catch { ctx = null; }
}
export function setVolume(v: number): void { vol = v; }

type Sfx = 'blip' | 'door' | 'coin' | 'laser' | 'hit' | 'boom' | 'launch' | 'land' | 'bad' | 'thrust';

export function sfx(kind: Sfx): void {
  if (!ctx || vol <= 0) return;
  const t = ctx.currentTime;
  const out = ctx.createGain();
  out.connect(ctx.destination);
  const tone = (type: OscillatorType, f0: number, f1: number, dur: number, g0: number) => {
    const o = ctx!.createOscillator(), g = ctx!.createGain();
    o.type = type; o.frequency.setValueAtTime(f0, t); o.frequency.exponentialRampToValueAtTime(Math.max(20, f1), t + dur);
    g.gain.setValueAtTime(g0 * vol, t); g.gain.exponentialRampToValueAtTime(0.001, t + dur);
    o.connect(g); g.connect(out); o.start(t); o.stop(t + dur + 0.02);
  };
  const noise = (dur: number, g0: number, lp: number) => {
    const n = Math.floor(ctx!.sampleRate * dur), buf = ctx!.createBuffer(1, n, ctx!.sampleRate), d = buf.getChannelData(0);
    for (let i = 0; i < n; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / n);
    const s = ctx!.createBufferSource(), f = ctx!.createBiquadFilter(), g = ctx!.createGain();
    s.buffer = buf; f.type = 'lowpass'; f.frequency.value = lp; g.gain.value = g0 * vol;
    s.connect(f); f.connect(g); g.connect(out); s.start(t);
  };
  switch (kind) {
    case 'blip': tone('square', 880, 880, 0.06, 0.08); break;
    case 'door': tone('square', 330, 440, 0.12, 0.08); break;
    case 'coin': tone('square', 988, 1319, 0.12, 0.08); break;
    case 'laser': tone('sawtooth', 1400, 180, 0.14, 0.07); break;
    case 'hit': noise(0.12, 0.25, 2200); break;
    case 'boom': noise(0.7, 0.45, 600); tone('sine', 120, 30, 0.6, 0.3); break;
    case 'launch': noise(1.4, 0.3, 900); tone('sawtooth', 60, 220, 1.4, 0.12); break;
    case 'land': noise(0.8, 0.25, 500); break;
    case 'bad': tone('square', 220, 110, 0.25, 0.1); break;
    case 'thrust': noise(0.1, 0.05, 400); break;
  }
}
