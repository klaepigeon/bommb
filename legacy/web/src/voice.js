// Voices. A very basic text-to-speech: the Android app's own TTS engine if we're in the app,
// the browser's speech synthesis if it has one, and if neither, a babble of little
// square-wave syllables (so Socko always has a voice). Plus Socko's dialogue queue, the
// objective line in the corner, and the tutorial tips he gives the first time you need them.
import { G, onUpdate } from './core.js';
import { AUDIO } from './audio.js';

const $ = (id) => document.getElementById(id);
export const VOICE = { talking: 0, mouth: 0 }; // talking: seconds left; mouth: 0..1 open

// ---------------------------------------------------------------- speech
const VOICES = {
  socko: { pitch: 1.9, rate: 1.12, babble: 520 },
  marta: { pitch: 0.1, rate: 0.62, babble: 140 },
};
function pickVoice() {
  const vs = window.speechSynthesis?.getVoices?.() || [];
  return vs.find((v) => /en[-_]GB/i.test(v.lang)) || vs.find((v) => /^en/i.test(v.lang)) || vs[0] || null;
}
export function say(text, who = 'socko') {
  const v = VOICES[who] || VOICES.socko;
  const words = text.split(/\s+/).length;
  const dur = Math.max(1.2, words * 0.36 / v.rate + 0.4);
  VOICE.talking = dur; VOICE.who = who;
  try {
    if (window.FlatNative?.speak && window.FlatNative.speak(text, v.pitch, v.rate)) return dur;
    if (window.speechSynthesis && pickVoice()) {
      const u = new SpeechSynthesisUtterance(text); u.voice = pickVoice(); u.pitch = Math.min(2, v.pitch); u.rate = v.rate; u.volume = 1;
      u.onend = () => { VOICE.talking = Math.min(VOICE.talking, 0.15); };
      window.speechSynthesis.cancel(); window.speechSynthesis.speak(u);
      return dur;
    }
  } catch (e) { /* fall through to babble */ }
  babble(text, v.babble);
  return dur;
}
// little syllables: one per vowel group, pitch wobbling round the voice's centre
function babble(text, f0) {
  const ctx = AUDIO.ctx; if (!ctx) return;
  const syl = (text.match(/[aeiouy]+/gi) || ['a']).length;
  const t0 = ctx.currentTime + 0.02, out = ctx.createGain(); out.gain.value = 0.11; out.connect(ctx.destination);
  for (let i = 0; i < syl; i++) {
    const o = ctx.createOscillator(); o.type = 'square'; o.frequency.value = f0 * (0.85 + Math.random() * 0.35);
    const f = ctx.createBiquadFilter(); f.type = 'bandpass'; f.frequency.value = 700 + Math.random() * 1400; f.Q.value = 3;
    const g = ctx.createGain(); const ts = t0 + i * 0.11;
    g.gain.setValueAtTime(0, ts); g.gain.linearRampToValueAtTime(1, ts + 0.015); g.gain.linearRampToValueAtTime(0, ts + 0.09);
    o.connect(f); f.connect(g); g.connect(out); o.start(ts); o.stop(ts + 0.1);
  }
}

// ---------------------------------------------------------------- Socko's lines
// queued so he never talks over himself; each shows in a speech box while it plays
const queue = [];
let busy = 0;
export function socko(text, o = {}) {
  if (!G.flags.socko && !o.force) return;
  const t = typeof text === 'function' ? text() : text;
  if (o.once) { G.flags['said_' + o.once] = G.flags['said_' + o.once] || 0; if (G.flags['said_' + o.once]) return; G.flags['said_' + o.once] = 1; }
  queue.push({ t, who: o.who || 'socko' });
}
export function objective(text) {
  G.objective = text;
  const el = $('objective'); el.innerHTML = text ? `<b>${G.flags.socko ? 'Socko says' : 'Objective'}</b>${text}` : ''; el.classList.toggle('on', !!text);
  el.classList.remove('new'); void el.offsetWidth; el.classList.add('new');
}
onUpdate((dt) => {
  if (VOICE.talking > 0) {
    VOICE.talking -= dt;
    // the mouth: a rough syllable rhythm
    VOICE.phase = (VOICE.phase || 0) + dt * 9;
    VOICE.mouth = Math.max(0, Math.sin(VOICE.phase) * 0.5 + 0.5 * Math.sin(VOICE.phase * 2.3)) * (VOICE.talking > 0 ? 1 : 0);
  } else VOICE.mouth *= 0.8;
  busy -= dt;
  if (busy <= 0 && queue.length && !G.cutscene) {
    const q = queue.shift();
    const el = $('socko'); el.querySelector('b').textContent = q.who === 'socko' ? 'SOCKO' : '';
    el.querySelector('span').textContent = q.t; el.classList.add('on'); el.classList.toggle('her', q.who !== 'socko');
    const d = say(q.t, q.who); busy = d + 0.5;
    clearTimeout(el._h); el._h = setTimeout(() => el.classList.remove('on'), (d + 0.6) * 1000);
  }
});

// ---------------------------------------------------------------- the quest line and the tips
// places Socko has something to say about, the first time you get there
onUpdate(() => {
  if (!G.flags.socko) return;
  const z = String(G.playerZone || '').split(':')[0];
  const at = { f48: 'f48', f51: 'f51', void: 'void', stair0: 'basement', street: 'street' }[z];
  if (at) G.tip(at);
  const w = G.flags.barricade; if (w && !G.flags.outside && G.playerPos && w.body.position.distanceTo(new w.body.position.constructor(G.playerPos.x, w.body.position.y, G.playerPos.z)) < 1.6) G.tip('push');
});
// glyphs: controller if they're using one, keys otherwise
const k = (key, pad) => (G.glyph === 'A' ? pad : key);
export function startSocko() {
  G.flags.socko = true;
  socko('Hey. Hey! Up you get, bud. Floor’s freezing, huh?');
  socko('Name’s Socko. I’m on your hand now. Don’t think about it too hard.');
  socko('The lady’s gone. Door’s still chained. So: first thing, we find a way out of this flat.');
  socko(() => `${k('W A S D', 'The left stick')} to walk. ${k('Mouse', 'Right stick')} to look around. You know this. You’re a detective.`);
  socko(() => `${k('E', 'A')} to use stuff, open stuff, pick stuff up. I can’t pick stuff up. No thumbs. Well. One thumb. Yours.`);
  setTimeout(() => objective('Find a way out of Flat 47.'), 9000);
  setTimeout(() => { if (!G.torch?.on) G.tip('torch'); }, 26000);
  setTimeout(() => G.tip('crouch'), 70000);
}
// first-time tips, fired from the game's own hooks
G.tip = (id) => {
  const T = {
    torch: () => `${k('F', 'X')} for the torch. It’s a cheap one. Give it a shake if it dies. Kidding. You can’t shake it.`,
    held: () => `${k('Right mouse', 'Left trigger')} to look at it up close. ${k('Left mouse', 'Right trigger')} to chuck it. Don’t chuck me.`,
    read: () => 'Reading’s good. Reading’s how you find out what’s what.',
    crouch: () => `${k('C', 'Y')} to crouch. Look under stuff. People hide things under stuff.`,
    chain: () => 'Padlock. Somebody had a key to that. Somewhere wet, I bet. Everything in here’s wet.',
    push: () => 'That wardrobe ain’t gonna move itself. Lean on it. Walk into it, I mean.',
    key: () => 'Keys! Go on then. Front door. Before I start getting attached to the place.',
    out: () => 'Okay. Stairwell. She said boxes. Have we seen any boxes? I haven’t seen any boxes.',
    f48: () => 'Oh. Oh, these are boxes. Grey boxes. With labels. That’s… that’s worse, actually.',
    boxes: () => 'These ain’t the right boxes. I don’t know how I know. Upstairs. Fifty-one. The note said fifty-one.',
    f51: () => 'Same flat. Nobody’s ever lived in it. Footprints though. Somebody walked in. Follow ’em?',
    void: () => 'I don’t like this. I’m a sock and I don’t like this.',
    back: () => 'We’re back. We didn’t come back. We’re just… back. Something moved. The bear moved.',
    f44: () => 'Long hallway. Real long. Count the doors. No, don’t, I counted, it’s bad.',
    basement: () => 'Basement. The notice said don’t go down. We went down. Classic us.',
    loop: () => 'Ten. Eleven. The building’s got nine floors, bud.',
    street: () => 'That’s not outside. That’s nothing. Shut the door.',
  };
  if (!T[id]) return;
  socko(T[id], { once: id });
  // the quest follows the tips
  const next = { key: 'Get the front door open.', out: 'Find the boxes she asked about.', boxes: 'Go up to Flat 51.', f51: 'Follow the footprints.', back: 'Go down. All the way down.', basement: 'The basement door. Listen at it.' }[id];
  if (next) setTimeout(() => objective(next), 2500);
};
