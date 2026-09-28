// RHAPSODY — WebAudio: synthesized sound effects and three procedural radio
// stations (funk, disco, outlaw country) plus tense police music.
'use strict';
(function () {
  const A = (R.Audio = function (game) {
    this.game = game;
    this.ctx = null;
    this.master = null;
    this.station = -1;
    this.mode = null; // 'radio' | 'tense' | null
    this.nextNote = 0;
    this.step = 0;
    this.vol = 0.7;
    this.musicVol = 0.5;
  });
  const P = A.prototype;

  P.unlock = function () {
    if (this.ctx) { if (this.ctx.state === 'suspended') this.ctx.resume(); return; }
    try {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) return;
      this.ctx = new AC();
      this.master = this.ctx.createGain();
      this.master.gain.value = this.vol;
      this.master.connect(this.ctx.destination);
      this.musicBus = this.ctx.createGain();
      this.musicBus.gain.value = this.musicVol;
      // warm "AM radio" filter for music
      this.radioFilter = this.ctx.createBiquadFilter();
      this.radioFilter.type = 'lowpass';
      this.radioFilter.frequency.value = 3800;
      this.musicBus.connect(this.radioFilter);
      this.radioFilter.connect(this.master);
      // noise buffer
      const len = this.ctx.sampleRate;
      this.noise = this.ctx.createBuffer(1, len, this.ctx.sampleRate);
      const d = this.noise.getChannelData(0);
      for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
      setInterval(() => this.schedule(), 40);
    } catch (e) {
      this.ctx = null;
    }
  };
  P.setVolume = function (v) {
    this.vol = v;
    if (this.master) this.master.gain.value = v;
  };
  P.setMusicVolume = function (v) {
    this.musicVol = v;
    if (this.musicBus) this.musicBus.gain.value = v;
  };

  // ------------------------------------------------ primitives
  P.env = function (node, t, a, d, peak) {
    const g = this.ctx.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(peak, t + a);
    g.gain.exponentialRampToValueAtTime(0.0001, t + a + d);
    node.connect(g);
    return g;
  };
  P.tone = function (type, f0, f1, dur, vol, out, t, attack) {
    const c = this.ctx;
    t = t || c.currentTime;
    const o = c.createOscillator();
    o.type = type;
    o.frequency.setValueAtTime(f0, t);
    if (f1 && f1 !== f0) o.frequency.exponentialRampToValueAtTime(Math.max(1, f1), t + dur);
    const g = this.env(o, t, attack || 0.005, dur, vol);
    g.connect(out || this.master);
    o.start(t);
    o.stop(t + dur + 0.05);
  };
  P.burst = function (dur, vol, freq, q, out, t, type) {
    const c = this.ctx;
    t = t || c.currentTime;
    const s = c.createBufferSource();
    s.buffer = this.noise;
    const f = c.createBiquadFilter();
    f.type = type || 'bandpass';
    f.frequency.value = freq;
    f.Q.value = q || 1;
    s.connect(f);
    const g = this.env(f, t, 0.003, dur, vol);
    g.connect(out || this.master);
    s.start(t, Math.random() * 0.5);
    s.stop(t + dur + 0.05);
  };

  P.sfx = function (name, x, y) {
    if (!this.ctx) return;
    let vol = 1;
    if (x !== undefined) {
      const cam = this.game.cam;
      const d = R.dist(x, y, cam.x, cam.y);
      vol = R.clamp(1 - d / 500, 0, 1);
      if (vol <= 0.02) return;
    }
    const v = (n) => n * vol;
    switch (name) {
      case 'punch': this.burst(0.08, v(0.6), 300, 1); this.tone('sine', 120, 50, 0.08, v(0.5)); break;
      case 'swing': this.burst(0.1, v(0.15), 1500, 0.8, null, null, 'highpass'); break;
      case 'stab': this.burst(0.06, v(0.4), 2500, 2); break;
      case 'thup': this.burst(0.05, v(0.35), 2200, 1.2); this.tone('sine', 260, 120, 0.05, v(0.12)); break;
      case 'shot': this.burst(0.18, v(0.8), 900, 0.6); this.tone('square', 180, 40, 0.1, v(0.25)); break;
      case 'shotgun': this.burst(0.35, v(0.9), 500, 0.5); this.tone('sine', 90, 30, 0.25, v(0.5)); break;
      case 'smg': this.burst(0.07, v(0.5), 1200, 0.8); break;
      case 'rifle': this.burst(0.3, v(0.9), 700, 0.5); this.tone('sawtooth', 220, 50, 0.15, v(0.2)); break;
      case 'boom': this.burst(1.2, v(1), 120, 0.4, null, null, 'lowpass'); this.tone('sine', 70, 25, 0.8, v(0.9)); break;
      case 'crash': this.burst(0.3, v(0.7), 800, 0.4); this.tone('square', 90, 40, 0.15, v(0.3)); break;
      case 'bump': this.burst(0.08, v(0.4), 600, 1); break;
      case 'thud': this.tone('sine', 110, 40, 0.15, v(0.6)); this.burst(0.08, v(0.3), 400, 1); break;
      case 'horn': this.tone('square', 392, 392, 0.35, v(0.18), null, null, 0.01); this.tone('square', 311, 311, 0.35, v(0.18), null, null, 0.01); break;
      case 'glass': for (let k = 0; k < 5; k++) this.tone('triangle', 2000 + Math.random() * 3000, 1500, 0.15, v(0.12), null, this.ctx.currentTime + k * 0.02); break;
      case 'door': this.tone('square', 140, 90, 0.08, v(0.2)); this.burst(0.05, v(0.2), 900, 2); break;
      case 'loot': this.tone('triangle', 600, 900, 0.08, v(0.2)); break;
      case 'cash': [880, 1175, 1568].forEach((f, i) => this.tone('square', f, f, 0.12, v(0.12), null, this.ctx.currentTime + i * 0.07)); break;
      case 'drink': this.burst(0.25, v(0.2), 700, 3); break;
      case 'equip': this.tone('square', 500, 700, 0.05, v(0.15)); break;
      case 'reload': this.burst(0.05, v(0.3), 2000, 3); this.burst(0.05, v(0.3), 1500, 3, null, this.ctx.currentTime + 0.15); break;
      case 'alarm': for (let k = 0; k < 6; k++) this.tone('square', k % 2 ? 880 : 660, k % 2 ? 880 : 660, 0.14, v(0.1), null, this.ctx.currentTime + k * 0.15); break;
      case 'thunder': this.burst(2.2, v(0.8), 90, 0.3, null, null, 'lowpass'); break;
      case 'howl': this.tone('sine', 400, 700, 1.2, v(0.15), null, null, 0.3); break;
      case 'ko': this.tone('triangle', 800, 200, 0.4, v(0.2)); break;
      case 'steal': this.tone('square', 300, 200, 0.2, v(0.15)); break;
      case 'accept': [523, 659, 784].forEach((f, i) => this.tone('triangle', f, f, 0.15, v(0.18), null, this.ctx.currentTime + i * 0.08)); break;
      case 'promote': [392, 523, 659, 784, 1046].forEach((f, i) => this.tone('square', f, f, 0.22, v(0.12), null, this.ctx.currentTime + i * 0.11)); break;
      case 'coolOn': this.tone('sine', 300, 80, 0.6, v(0.3)); break;
      case 'coolOff': this.tone('sine', 80, 300, 0.4, v(0.2)); break;
      case 'match': this.burst(0.3, v(0.3), 3000, 1); break;
      case 'click': this.tone('square', 900, 900, 0.03, v(0.08)); break;
      case 'bite': this.tone('square', 1200, 800, 0.1, v(0.2)); break;
      case 'splash': this.burst(0.4, v(0.3), 1200, 0.7); break;
    }
  };

  // ------------------------------------------------ music scheduling
  P.radio = function (station) {
    if (station === null || station === undefined) {
      if (this.mode === 'radio') this.mode = this.game.law.active() ? 'tense' : null;
      return;
    }
    this.station = station;
    this.mode = R.data.stations[station].id === 'off' ? null : 'radio';
    this.startMusic();
    const st = R.data.stations[station];
    this.game.ui.toast('📻 ' + st.name + (st.dj.length ? ` — "${R.rng.pick(st.dj)}"` : ''));
  };
  // music inside bars and clubs (jukebox), stops when you walk out
  P.indoorMusic = function (station) {
    if (station === null || station === undefined) {
      if (this.indoor) { this.indoor = false; if (!this.game.player.inCar) this.mode = this.game.law.active() ? 'tense' : null; }
      return;
    }
    this.indoor = true;
    this.station = station;
    this.mode = 'radio';
    this.startMusic();
  };
  P.nextStation = function (v) {
    const n = R.data.stations.length;
    v.radio = (v.radio + 1) % n;
    this.radio(v.radio);
    this.sfx('click');
  };
  P.music = function (kind) {
    if (this.mode === 'radio') return;
    this.mode = kind;
    this.startMusic();
  };
  P.startMusic = function () {
    if (!this.ctx) return;
    this.nextNote = this.ctx.currentTime + 0.05;
    this.step = 0;
    this.seed = R.rng.int(0, 99999);
  };

  const NOTE = (m) => 440 * Math.pow(2, (m - 69) / 12);
  P.schedule = function () {
    if (!this.ctx || !this.mode) return;
    const st = this.mode === 'radio' ? R.data.stations[this.station].id : this.mode;
    const bpm = st === 'disco' ? 120 : st === 'funk' ? 98 : st === 'outlaw' ? 112 : 96;
    const s16 = 60 / bpm / 4;
    const out = this.musicBus;
    while (this.nextNote < this.ctx.currentTime + 0.2) {
      const t = this.nextNote, i = this.step % 64, beat = i % 16;
      const bar = Math.floor(i / 16);
      if (st === 'funk') this.funk(t, i, beat, bar, out, s16);
      else if (st === 'disco') this.disco(t, i, beat, bar, out, s16);
      else if (st === 'outlaw') this.outlaw(t, i, beat, bar, out, s16);
      else if (st === 'tense') this.tense(t, i, beat, bar, out, s16);
      const swing = st === 'funk' && i % 2 === 1 ? s16 * 0.12 : 0;
      this.nextNote += s16 + (i % 2 === 0 ? swing : -swing);
      this.step++;
    }
  };
  P.kick = function (t, out, v) { this.tone('sine', 140, 40, 0.18, 0.7 * (v || 1), out, t); };
  P.snare = function (t, out, v) { this.burst(0.14, 0.35 * (v || 1), 1800, 0.7, out, t); this.tone('triangle', 200, 150, 0.06, 0.15, out, t); };
  P.hat = function (t, out, v, open) { this.burst(open ? 0.18 : 0.04, 0.12 * (v || 1), 8000, 1, out, t, 'highpass'); };

  P.funk = function (t, i, beat, bar, out, s16) {
    const rnd = R.mulberry(this.seed + bar * 7);
    if (beat === 0 || beat === 10 || (beat === 7 && bar % 2)) this.kick(t, out);
    if (beat === 4 || beat === 12) this.snare(t, out);
    if (beat === 15 && bar === 3) this.snare(t, out, 0.5);
    this.hat(t, out, beat % 4 === 2 ? 1 : 0.6, beat === 14);
    // bass: E minor pentatonic riff, repeats every 2 bars
    const riff = [40, 0, 40, 43, 0, 45, 0, 40, 0, 47, 45, 0, 43, 0, 38, 40];
    const nb = riff[beat];
    if (nb && !(bar === 3 && beat > 11)) this.tone('sawtooth', NOTE(nb), NOTE(nb) * 0.98, s16 * 1.6, 0.22, out, t, 0.004);
    // clavinet stabs on the offbeats
    if (beat % 4 === 2 || (beat === 7 && rnd() < 0.5)) {
      for (const n of [64, 67, 71]) this.tone('square', NOTE(n + (bar === 2 ? 5 : 0)), NOTE(n + (bar === 2 ? 5 : 0)), s16 * 0.5, 0.035, out, t, 0.002);
    }
    // horn line on bar 4
    if (bar === 3 && beat % 4 === 0) this.tone('sawtooth', NOTE([76, 79, 81, 83][beat / 4]), NOTE([76, 79, 81, 83][beat / 4]), s16 * 3, 0.05, out, t, 0.02);
  };
  P.disco = function (t, i, beat, bar, out, s16) {
    if (beat % 4 === 0) this.kick(t, out);
    if (beat === 4 || beat === 12) { this.snare(t, out, 0.8); this.burst(0.1, 0.1, 3000, 0.5, out, t); }
    if (beat % 4 === 2) this.hat(t, out, 1, true);
    else this.hat(t, out, 0.4);
    const prog = [57, 50, 55, 48]; // Am Dm G C
    const root = prog[bar];
    if (beat % 2 === 0) {
      const n = beat % 4 === 0 ? root - 12 : root;
      this.tone('square', NOTE(n), NOTE(n), s16 * 1.4, 0.12, out, t, 0.003);
    }
    if (beat === 0) {
      const chord = [0, 3 + (bar === 2 || bar === 3 ? 1 : 0), 7].map((x) => root + 12 + x);
      for (const n of chord) this.tone('sawtooth', NOTE(n), NOTE(n), s16 * 15, 0.028, out, t, 0.25);
    }
    // violin runs
    if (bar === 3 && beat >= 8) this.tone('triangle', NOTE(81 + (beat - 8) * 2), NOTE(81 + (beat - 8) * 2), s16 * 0.9, 0.05, out, t, 0.01);
  };
  P.outlaw = function (t, i, beat, bar, out, s16) {
    const prog = [43, 48, 43, 50]; // G C G D
    const root = prog[bar];
    if (beat === 0 || beat === 8) this.tone('triangle', NOTE(root - 12), NOTE(root - 12), s16 * 3, 0.3, out, t);
    if (beat === 4 || beat === 12) this.tone('triangle', NOTE(root - 5), NOTE(root - 5), s16 * 3, 0.26, out, t);
    if (beat === 4 || beat === 12) this.burst(0.12, 0.18, 2500, 0.6, out, t);
    if (beat === 0 || beat === 8) this.kick(t, out, 0.6);
    if (beat % 2 === 0) {
      const arp = [0, 4, 7, 12, 7, 4, 0, 4][(beat / 2) % 8];
      this.tone('triangle', NOTE(root + 12 + arp), NOTE(root + 12 + arp) * 0.995, s16 * 1.8, 0.07, out, t, 0.002);
    }
    // pedal steel slide at the end of each 4 bars
    if (bar === 3 && beat === 8) this.tone('sine', NOTE(74), NOTE(79), s16 * 8, 0.06, out, t, 0.1);
  };
  P.tense = function (t, i, beat, bar, out, s16) {
    if (beat % 4 === 0) this.tone('sawtooth', NOTE(beat === 12 ? 39 : 38), NOTE(38), s16 * 2, 0.16, out, t);
    if (beat % 2 === 1) this.hat(t, out, 0.5);
    if (beat === 0 || beat === 6) this.kick(t, out, 0.8);
    if (beat === 8 && bar % 2) this.tone('square', NOTE(62), NOTE(63), s16 * 6, 0.04, out, t, 0.05);
  };
})();
