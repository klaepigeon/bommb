// Input: a virtual stick and DS-style buttons on touch, WASD/arrows + J/K/Enter on keys.
// Scenes read `x, y` (the stick, -1..1) and the edge-triggered `pressed` set.

export type Button = 'a' | 'b' | 'start';

export class Input {
  x = 0;
  y = 0;
  private held = new Set<Button>();
  private edge = new Set<Button>();
  private keys = new Set<string>();
  private stick = { active: false, id: -1, cx: 0, cy: 0, x: 0, y: 0 };

  constructor() {
    addEventListener('keydown', (e) => {
      if (e.repeat) return;
      this.keys.add(e.key.toLowerCase());
      const b = this.keyButton(e.key);
      if (b) { this.press(b); e.preventDefault(); }
    });
    addEventListener('keyup', (e) => {
      this.keys.delete(e.key.toLowerCase());
      const b = this.keyButton(e.key);
      if (b) this.held.delete(b);
    });
    addEventListener('blur', () => { this.keys.clear(); this.held.clear(); });
  }

  private keyButton(k: string): Button | null {
    k = k.toLowerCase();
    if (k === 'j' || k === 'z' || k === ' ') return 'a';
    if (k === 'k' || k === 'x') return 'b';
    if (k === 'enter' || k === 'escape') return 'start';
    return null;
  }

  press(b: Button): void { this.held.add(b); this.edge.add(b); }
  release(b: Button): void { this.held.delete(b); }
  down(b: Button): boolean { return this.held.has(b); }
  pressed(b: Button): boolean { return this.edge.has(b); }

  // wire the on-screen stick and buttons
  bindTouch(zone: HTMLElement, knob: HTMLElement, buttons: Record<Button, HTMLElement | null>): void {
    const R = 44;
    const move = (px: number, py: number) => {
      let dx = px - this.stick.cx, dy = py - this.stick.cy;
      const d = Math.hypot(dx, dy);
      if (d > R) { dx = (dx / d) * R; dy = (dy / d) * R; }
      this.stick.x = dx / R; this.stick.y = dy / R;
      knob.style.transform = `translate(${dx}px, ${dy}px)`;
    };
    zone.addEventListener('pointerdown', (e) => {
      const r = zone.getBoundingClientRect();
      this.stick = { active: true, id: e.pointerId, cx: r.left + r.width / 2, cy: r.top + r.height / 2, x: 0, y: 0 };
      zone.setPointerCapture(e.pointerId);
      move(e.clientX, e.clientY);
    });
    zone.addEventListener('pointermove', (e) => { if (this.stick.active && e.pointerId === this.stick.id) move(e.clientX, e.clientY); });
    const end = (e: PointerEvent) => {
      if (e.pointerId !== this.stick.id) return;
      this.stick.active = false; this.stick.x = 0; this.stick.y = 0;
      knob.style.transform = '';
    };
    zone.addEventListener('pointerup', end);
    zone.addEventListener('pointercancel', end);
    for (const [b, el] of Object.entries(buttons) as [Button, HTMLElement | null][]) {
      if (!el) continue;
      el.addEventListener('pointerdown', (e) => { e.preventDefault(); this.press(b); el.classList.add('on'); });
      const up = () => { this.release(b); el.classList.remove('on'); };
      el.addEventListener('pointerup', up);
      el.addEventListener('pointerleave', up);
      el.addEventListener('pointercancel', up);
    }
  }

  // call once per frame before the scene updates
  poll(): void {
    let kx = 0, ky = 0;
    const k = this.keys;
    if (k.has('a') || k.has('arrowleft')) kx -= 1;
    if (k.has('d') || k.has('arrowright')) kx += 1;
    if (k.has('w') || k.has('arrowup')) ky -= 1;
    if (k.has('s') || k.has('arrowdown')) ky += 1;
    if (kx || ky) { const d = Math.hypot(kx, ky); this.x = kx / d; this.y = ky / d; }
    else { this.x = this.stick.x; this.y = this.stick.y; }
  }
  // call once per frame after the scene updates
  endFrame(): void { this.edge.clear(); }
}
