// Controllers: the browser Gamepad API, or (in the Android app) a native bridge that
// forwards the controller from Android's input system — WebView's own gamepad support
// is patchy, so the app hands us axes and buttons itself via window.__nativePad.
//
// Standard layout:  left stick move · right stick look · A use · B back/drop · X torch
// Y crouch · RB / R3 hurry · RT throw · LT inspect · Start pause · D-pad menus
import { G } from './core.js';

export const PAD = { connected: false, using: false, lastUse: 0, native: null, rumble: null };
const BTN = { A: 0, B: 1, X: 2, Y: 3, LB: 4, RB: 5, LT: 6, RT: 7, SELECT: 8, START: 9, L3: 10, R3: 11, UP: 12, DOWN: 13, LEFT: 14, RIGHT: 15 };
let prev = new Array(17).fill(false);

// called by the Android app: axes [lx, ly, rx, ry, lt, rt], buttons as a bitmask in the order above
window.__nativePad = (lx, ly, rx, ry, lt, rt, mask) => {
  PAD.native = { axes: [lx, ly, rx, ry], lt, rt, mask, t: performance.now() };
};

function read() {
  if (PAD.native && performance.now() - PAD.native.t < 4000) {
    const n = PAD.native, b = [];
    for (let i = 0; i < 17; i++) b[i] = !!(n.mask & (1 << i));
    b[BTN.LT] = b[BTN.LT] || n.lt > 0.5; b[BTN.RT] = b[BTN.RT] || n.rt > 0.5;
    return { axes: n.axes, b };
  }
  const pads = navigator.getGamepads ? navigator.getGamepads() : [];
  for (const p of pads) {
    if (!p || !p.connected) continue;
    PAD.rumble = p.vibrationActuator || null;
    return { axes: [p.axes[0] || 0, p.axes[1] || 0, p.axes[2] || 0, p.axes[3] || 0], b: p.buttons.map((x) => x.pressed || x.value > 0.5) };
  }
  return null;
}

const dz = (v, d = 0.18) => (Math.abs(v) < d ? 0 : Math.sign(v) * (Math.abs(v) - d) / (1 - d));

// h: handlers from main.js
export function updatePad(dt, h) {
  const s = read();
  PAD.connected = !!s;
  if (!s) return;
  const b = s.b, down = (i) => b[i] && !prev[i];
  const any = b.some(Boolean) || s.axes.some((a) => Math.abs(a) > 0.3);
  if (any && !PAD.using) { PAD.using = true; h.onMode?.(true); }
  if (any) PAD.lastUse = performance.now();

  if (h.menuOpen()) {
    // menus: D-pad / left stick to move focus, A to press, B or Start to back out
    const y = (down(BTN.DOWN) ? 1 : 0) - (down(BTN.UP) ? 1 : 0) + stickStep(s.axes[1], 'y');
    const x = (down(BTN.RIGHT) ? 1 : 0) - (down(BTN.LEFT) ? 1 : 0) + stickStep(s.axes[0], 'x');
    if (y) h.menuMove(y);
    if (x) h.menuAdjust(x);
    if (down(BTN.A)) h.menuPress();
    if (down(BTN.B) || down(BTN.START)) h.menuBack();
  } else {
    // body
    h.move(dz(s.axes[0]), -dz(s.axes[1]), b[BTN.RB] || b[BTN.L3]);
    const lx = dz(s.axes[2], 0.12), ly = dz(s.axes[3], 0.12);
    if (lx || ly) {
      // a curve, so small deflections aim finely and full deflection turns fast
      const k = 900 * dt;
      h.look(Math.sign(lx) * lx * lx * k * 1.25, Math.sign(ly) * ly * ly * k);
    }
    if (down(BTN.A)) h.use();
    if (down(BTN.B)) h.back();
    if (down(BTN.X)) h.torch();
    if (down(BTN.Y)) h.crouch();
    if (down(BTN.RT)) h.throw();
    if (down(BTN.LT)) h.inspect();
    if (down(BTN.START) || down(BTN.SELECT)) h.pause();
  }
  prev = b.slice();
}
const stepT = { x: 0, y: 0 };
function stickStep(v, k) {
  if (Math.abs(v) < 0.6) { stepT[k] = 0; return 0; }
  const now = performance.now();
  if (now - stepT[k] < 260) return 0;
  stepT[k] = now; return Math.sign(v);
}

export function rumble(strong = 0.5, ms = 120) {
  if (!PAD.using) return;
  try {
    if (PAD.native && window.FlatNative?.rumble) window.FlatNative.rumble(Math.round(ms), Math.round(strong * 255));
    else PAD.rumble?.playEffect?.('dual-rumble', { duration: ms, strongMagnitude: strong, weakMagnitude: strong * 0.6 });
  } catch (e) { /* no rumble */ }
}
G.rumble = rumble;
