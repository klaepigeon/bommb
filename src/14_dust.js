// RHAPSODY — dust storms. Out in the Dustwater country a hot afternoon can turn brown in
// ten minutes: the wind comes up, the sky goes the colour of a paper bag, and you can't
// see the next telephone pole. Witnesses can't see much either. Good weather for a job.
'use strict';
(function () {
  const TS = R.TILE;
  const G = () => R.game;
  const DU = (R.dust = { level: 0, storm: null });

  DU.inDesert = function () { const g = G(), pl = g.player; return pl.x / TS / g.world.W > 0.6 && pl.y / TS / g.world.H > 0.6; };
  DU.el = function () {
    let el = document.getElementById('dustveil');
    if (el) return el;
    el = document.createElement('div'); el.id = 'dustveil';
    const st = document.createElement('style');
    st.textContent = '#dustveil{position:fixed;pointer-events:none;z-index:30;opacity:0;background:rgba(190,146,90,.55);overflow:hidden}#dustveil:after{content:"";position:absolute;inset:-50%;background:repeating-linear-gradient(4deg,rgba(255,236,196,0) 0 9px,rgba(255,236,196,.16) 9px 10px,rgba(120,84,40,0) 10px 23px,rgba(120,84,40,.14) 23px 24px);animation:dustblow .7s linear infinite}@keyframes dustblow{from{transform:translate(0,0)}to{transform:translate(160px,6px)}}';
    document.head.appendChild(st);
    document.body.appendChild(el);
    return el;
  };
  DU.fit = function () { const v = document.querySelector('#view canvas') || document.querySelector('canvas'), el = this.el(); if (!v) return; const r = v.getBoundingClientRect(); Object.assign(el.style, { left: r.left + 'px', top: r.top + 'px', width: r.width + 'px', height: r.height + 'px' }); };

  DU.update = function (dt) {
    const g = G(), w = g.env.weather, pl = g.player;
    const desert = this.inDesert() && !pl.room;
    // a storm blows in on hot, dry days in the desert
    this.roll = (this.roll || 0) - dt * g.clock.rate;
    if (this.roll <= 0) {
      this.roll = 60; // once an in-game hour
      if (!this.storm && desert && (w.kind === 'heat' || w.kind === 'clear') && w.dry > 0.5 && R.rng() < 0.08 && !(R.opening && R.opening.active)) {
        this.storm = { left: (60 + R.rng() * 120) }; // in-game minutes
        g.ui.toast('Weather: a dust storm is blowing in. Nobody will see a thing.', 'warn');
      }
    }
    if (this.storm) { this.storm.left -= dt * g.clock.rate; if (this.storm.left <= 0) this.storm = null; }
    const want = this.storm && desert ? 1 : 0;
    this.level += (want - this.level) * Math.min(1, dt * 0.35);
    if (this.level > 0.02) {
      // it behaves like thick fog for everything that looks (witnesses, cops), and pushes hard
      w.fog = Math.max(w.fog, this.level * 0.8);
      w.wind.x = 1.8 * this.level + (1 - this.level) * w.wind.x;
      const n = dt * 40 * this.level;
      for (let k = 0; k < n; k++) {
        const x = pl.x + (R.rng() - 0.6) * 320, y = pl.y + (R.rng() - 0.5) * 200;
        g.fx.add({ x, y, vx: 140 + R.rng() * 80, vy: 10 + R.rng() * 16, life: 1, max: 1, c: R.rng() < 0.5 ? 'rgba(214,176,120,0.55)' : 'rgba(150,110,62,0.45)', s: R.rng() < 0.3 ? 2 : 1 });
      }
    }
    this.shimmer(dt);
    const el = this.el();
    if (this.level > 0.02) { if (!this.fitted) { this.fit(); this.fitted = true; window.addEventListener('resize', () => this.fit()); } el.style.opacity = (this.level * 0.85).toFixed(2); }
    else if (el.style.opacity !== '0') el.style.opacity = '0';
  };
  // ---------------------------------------------------------------- heat shimmer
  // Midday in the desert on a hot day the air over the road wobbles.
  DU.shimmer = function (dt) {
    const g = G(), w = g.env.weather, pl = g.player, hr = g.clock.hour();
    const on = this.inDesert() && !pl.room && w.kind === 'heat' && hr >= 11 && hr <= 16 && this.level < 0.1 && g.settings.shimmer !== false;
    this.heatOn = on;
    const cv = document.querySelector('#view canvas') || document.querySelector('canvas');
    if (!cv) return;
    if (R.gl && R.gl.on) { if (this.shimOn) { cv.style.filter = ''; this.shimOn = false; } return; } // the GPU does the shimmer
    if (!on) { if (this.shimOn) { cv.style.filter = ''; this.shimOn = false; } return; }
    if (!document.getElementById('heatshimmer')) {
      const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
      svg.setAttribute('width', '0'); svg.setAttribute('height', '0'); svg.style.position = 'absolute';
      svg.innerHTML = '<filter id="heatshimmer" x="0" y="0" width="100%" height="100%"><feTurbulence id="hsTurb" type="fractalNoise" baseFrequency="0.004 0.06" numOctaves="1" seed="1"/><feDisplacementMap in="SourceGraphic" scale="3" xChannelSelector="R" yChannelSelector="G"/></filter>';
      document.body.appendChild(svg);
    }
    if (!this.shimOn) { cv.style.filter = 'url(#heatshimmer)'; this.shimOn = true; }
    this.shimT = (this.shimT || 0) + dt;
    this.shimP = (this.shimP || 0) + dt;
    if (this.shimT > 0.06) { this.shimT = 0; const t = document.getElementById('hsTurb'); if (t) t.setAttribute('baseFrequency', `0.004 ${(0.055 + Math.sin(this.shimP * 1.7) * 0.012).toFixed(4)}`); }
  };

  DU.init = function () { this.storm = null; this.level = 0; if (document.getElementById('dustveil')) this.el().style.opacity = '0'; };
})();
