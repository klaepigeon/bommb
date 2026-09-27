// RHAPSODY — input: floating touch joystick + touch buttons (mobile first),
// keyboard for desktop. Actions are polled per frame via held()/pressed().
'use strict';
(function () {
  const KEYS = {
    KeyE: 'use', Enter: 'use', Space: 'attack', KeyF: 'attack', KeyQ: 'weapon', ShiftLeft: 'run', ShiftRight: 'run',
    KeyC: 'sneak', KeyM: 'mask', KeyR: 'radio', KeyG: 'greet', KeyT: 'talk', KeyX: 'defuse', KeyV: 'antag', KeyH: 'horn',
    KeyZ: 'cool', KeyB: 'brake', KeyI: 'heal', KeyP: 'phone', KeyY: 'ring', KeyL: 'lib', Escape: 'menu', Tab: 'map', KeyN: 'map',
  };
  const MOVE = { KeyW: [0, -1], ArrowUp: [0, -1], KeyS: [0, 1], ArrowDown: [0, 1], KeyA: [-1, 0], ArrowLeft: [-1, 0], KeyD: [1, 0], ArrowRight: [1, 0] };

  const Input = (R.Input = function (game, root) {
    this.game = game;
    this.stick = { x: 0, y: 0 };
    this.lastTouch = 'ontouchstart' in window || navigator.maxTouchPoints > 0;
    this.keysDown = new Set();
    this.heldA = {};
    this.pressedA = {};
    this.longA = {};
    this.downAt = {};
    this.touchStick = null;
    this.root = root;
    this.bind();
  });
  const P = Input.prototype;

  P.bind = function () {
    const self = this;
    window.addEventListener('keydown', (e) => {
      this.lastTouch = false;
      if (e.target && (e.target.tagName === 'INPUT' || e.target.tagName === 'SELECT')) return;
      if (this.game.ui && this.game.ui.modalOpen() && e.code !== 'Escape') {
        if (e.code === 'Escape' || e.code === 'Tab') e.preventDefault();
        return;
      }
      if (KEYS[e.code] || MOVE[e.code]) e.preventDefault();
      if (e.repeat) return;
      this.keysDown.add(e.code);
      const a = KEYS[e.code];
      if (a) this.down(a);
      // car: space brakes, H horns
      if (this.game.player && this.game.player.inCar) {
        if (e.code === 'Space') this.down('brake');
        if (e.code === 'KeyE') {} // exit handled by use
      }
    });
    window.addEventListener('keyup', (e) => {
      this.keysDown.delete(e.code);
      const a = KEYS[e.code];
      if (a) this.up(a);
      if (e.code === 'Space') this.up('brake');
    });
    window.addEventListener('blur', () => { this.keysDown.clear(); this.heldA = {}; this.stick.x = this.stick.y = 0; this.touchStick = null; this.drawStick(); });

    // fixed joystick (like the original): touch anywhere in the left pad
    const zone = this.root.querySelector('#stickzone');
    const base = this.root.querySelector('#stickbase');
    const knob = this.root.querySelector('#stickknob');
    this.base = base;
    this.knob = knob;
    zone.addEventListener('pointerdown', (e) => {
      this.lastTouch = e.pointerType !== 'mouse';
      e.preventDefault();
      if (this.touchStick) return;
      this.game.audio.unlock();
      zone.setPointerCapture(e.pointerId);
      const r = base.getBoundingClientRect();
      this.touchStick = { id: e.pointerId, ox: r.left + r.width / 2, oy: r.top + r.height / 2, r: r.width * 0.36, x: e.clientX, y: e.clientY };
      this.drawStick();
    });
    zone.addEventListener('pointermove', (e) => {
      const t = this.touchStick;
      if (!t || t.id !== e.pointerId) return;
      t.x = e.clientX; t.y = e.clientY;
      this.drawStick();
    });
    const end = (e) => {
      const t = this.touchStick;
      if (!t || t.id !== e.pointerId) return;
      this.touchStick = null;
      this.drawStick();
    };
    zone.addEventListener('pointerup', end);
    zone.addEventListener('pointercancel', end);

    // on-screen buttons (data-k="action")
    this.root.querySelectorAll('[data-k]').forEach((btn) => {
      const a = btn.dataset.k;
      btn.addEventListener('pointerdown', (e) => {
        this.lastTouch = e.pointerType !== 'mouse';
        e.preventDefault();
        e.stopPropagation();
        this.game.audio.unlock();
        btn.setPointerCapture(e.pointerId);
        btn.classList.add('on');
        const act = this.game.player && this.game.player.inCar && btn.dataset.car ? btn.dataset.car : a;
        btn._act = act;
        this.down(act);
        if (navigator.vibrate) try { navigator.vibrate(8); } catch (err) {}
      });
      const up = (e) => {
        btn.classList.remove('on');
        if (btn._act) this.up(btn._act);
        btn._act = null;
      };
      btn.addEventListener('pointerup', up);
      btn.addEventListener('pointercancel', up);
      btn.addEventListener('contextmenu', (e) => e.preventDefault());
    });
  };
  P.down = function (a) {
    if (!this.heldA[a]) {
      this.pressedA[a] = true;
      this.downAt[a] = performance.now();
    }
    this.heldA[a] = true;
    if (a === 'menu') this.game.ui.toggleMenu();
    if (a === 'map') this.game.ui.openMenu('map');
    if (a === 'phone') this.game.ui.openPhone();
  };
  P.up = function (a) {
    const held = performance.now() - (this.downAt[a] || 0);
    this.heldA[a] = false;
    if (held > 450) this.longA[a] = true;
  };
  P.held = function (a) { return !!this.heldA[a]; };
  P.pressed = function (a) { return !!this.pressedA[a]; };
  P.longPressed = function (a) { return !!this.longA[a]; };
  P.endFrame = function () {
    this.pressedA = {};
    this.longA = {};
  };
  P.drawStick = function () {
    const t = this.touchStick;
    if (!t) { this.knob.style.transform = ''; return; }
    let dx = t.x - t.ox, dy = t.y - t.oy;
    const d = Math.hypot(dx, dy);
    if (d > t.r) { dx = (dx / d) * t.r; dy = (dy / d) * t.r; }
    this.knob.style.transform = `translate(${dx}px, ${dy}px)`;
  };
  P.update = function () {
    let x = 0, y = 0;
    for (const k of this.keysDown) if (MOVE[k]) { x += MOVE[k][0]; y += MOVE[k][1]; }
    const d = Math.hypot(x, y);
    if (d > 0) { x /= d; y /= d; }
    const t = this.touchStick;
    if (t) {
      const max = t.r;
      let dx = (t.x - t.ox) / max, dy = (t.y - t.oy) / max;
      const m = Math.hypot(dx, dy);
      if (m > 1) { dx /= m; dy /= m; }
      if (m > 0.12) { x = dx; y = dy; }
      // pushing the stick all the way = run (mobile)
      if (m > 1.25 && !this.game.player.inCar) this.heldA.runStick = true;
      else this.heldA.runStick = false;
    } else this.heldA.runStick = false;
    this.stick.x = x;
    this.stick.y = y;
  };
})();
