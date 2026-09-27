// RHAPSODY — input: floating touch joystick + touch buttons (mobile first),
// keyboard for desktop. Actions are polled per frame via held()/pressed().
'use strict';
(function () {
  const KEYS = {
    KeyE: 'use', Enter: 'use', Space: 'attack', KeyF: 'attack', KeyQ: 'weapon', ShiftLeft: 'run', ShiftRight: 'run',
    KeyC: 'sneak', KeyM: 'mask', KeyR: 'radio', KeyG: 'greet', KeyT: 'talk', KeyX: 'defuse', KeyV: 'antag', KeyH: 'horn',
    KeyZ: 'cool', KeyB: 'brake', KeyI: 'heal', Escape: 'menu', Tab: 'map', KeyN: 'map',
  };
  const MOVE = { KeyW: [0, -1], ArrowUp: [0, -1], KeyS: [0, 1], ArrowDown: [0, 1], KeyA: [-1, 0], ArrowLeft: [-1, 0], KeyD: [1, 0], ArrowRight: [1, 0] };

  const Input = (R.Input = function (game, root) {
    this.game = game;
    this.stick = { x: 0, y: 0 };
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

    // touch joystick zone: the left side of the play area (not on buttons)
    const zone = this.root.querySelector('#stickzone');
    const base = this.root.querySelector('#stickbase');
    const knob = this.root.querySelector('#stickknob');
    this.base = base;
    this.knob = knob;
    zone.addEventListener('pointerdown', (e) => {
      e.preventDefault();
      if (this.touchStick) return;
      this.game.audio.unlock();
      zone.setPointerCapture(e.pointerId);
      this.touchStick = { id: e.pointerId, ox: e.clientX, oy: e.clientY, x: e.clientX, y: e.clientY };
      this.drawStick();
    });
    zone.addEventListener('pointermove', (e) => {
      const t = this.touchStick;
      if (!t || t.id !== e.pointerId) return;
      t.x = e.clientX; t.y = e.clientY;
      // let the base follow when dragged far (floating stick)
      const max = 52;
      const dx = t.x - t.ox, dy = t.y - t.oy, d = Math.hypot(dx, dy);
      if (d > max * 1.5) { t.ox = t.x - (dx / d) * max * 1.5; t.oy = t.y - (dy / d) * max * 1.5; }
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
    if (!t) {
      this.base.style.opacity = 0;
      this.knob.style.opacity = 0;
      return;
    }
    const max = 52;
    let dx = t.x - t.ox, dy = t.y - t.oy;
    const d = Math.hypot(dx, dy);
    if (d > max) { dx = (dx / d) * max; dy = (dy / d) * max; }
    this.base.style.opacity = 1;
    this.knob.style.opacity = 1;
    this.base.style.transform = `translate(${t.ox - 60}px, ${t.oy - 60}px)`;
    this.knob.style.transform = `translate(${t.ox + dx - 26}px, ${t.oy + dy - 26}px)`;
  };
  P.update = function () {
    let x = 0, y = 0;
    for (const k of this.keysDown) if (MOVE[k]) { x += MOVE[k][0]; y += MOVE[k][1]; }
    const d = Math.hypot(x, y);
    if (d > 0) { x /= d; y /= d; }
    const t = this.touchStick;
    if (t) {
      const max = 52;
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
