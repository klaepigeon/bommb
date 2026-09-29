// A pixel buffer for painting sprites and tiles by hand, then turning them into canvases.
// Colours are '#rrggbb' strings; they're packed once and written straight into ImageData.

const packed = new Map<string, number>();
export function pack(hex: string): number {
  let n = packed.get(hex);
  if (n === undefined) {
    const v = parseInt(hex.slice(1, 7), 16);
    n = (0xff000000 | ((v & 0xff) << 16) | (v & 0xff00) | ((v >> 16) & 0xff)) >>> 0; // ABGR (little endian)
    packed.set(hex, n);
  }
  return n;
}
export function unpack(n: number): string {
  return '#' + [n & 0xff, (n >> 8) & 0xff, (n >> 16) & 0xff].map((v) => v.toString(16).padStart(2, '0')).join('');
}

export class Px {
  readonly w: number;
  readonly h: number;
  readonly d: Uint32Array;
  constructor(w: number, h: number) { this.w = w; this.h = h; this.d = new Uint32Array(w * h); }

  in(x: number, y: number): boolean { return x >= 0 && y >= 0 && x < this.w && y < this.h; }
  raw(x: number, y: number): number { return this.in(x, y) ? this.d[y * this.w + x] : 0; }
  has(x: number, y: number): boolean { return this.raw(x, y) !== 0; }
  get(x: number, y: number): string | null { const n = this.raw(x, y); return n ? unpack(n) : null; }
  set(x: number, y: number, c: string | null): this {
    x = Math.floor(x); y = Math.floor(y);
    if (this.in(x, y)) this.d[y * this.w + x] = c ? pack(c) : 0;
    return this;
  }
  rect(x: number, y: number, w: number, h: number, c: string | null): this {
    for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) this.set(x + i, y + j, c);
    return this;
  }
  hline(x0: number, x1: number, y: number, c: string): this { for (let x = x0; x <= x1; x++) this.set(x, y, c); return this; }
  vline(x: number, y0: number, y1: number, c: string): this { for (let y = y0; y <= y1; y++) this.set(x, y, c); return this; }
  // a filled ellipse; fn gets normalised coords (-1..1) and returns the colour (or null to skip)
  oval(cx: number, cy: number, rx: number, ry: number, fn: (nx: number, ny: number, x: number, y: number) => string | null): this {
    for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++)
      for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++) {
        const nx = (x + 0.5 - cx) / rx, ny = (y + 0.5 - cy) / ry;
        if (nx * nx + ny * ny <= 1) { const c = fn(nx, ny, x, y); if (c) this.set(x, y, c); }
      }
    return this;
  }
  line(x0: number, y0: number, x1: number, y1: number, c: string): this {
    const n = Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0), 1);
    for (let k = 0; k <= n; k++) this.set(Math.round(x0 + ((x1 - x0) * k) / n), Math.round(y0 + ((y1 - y0) * k) / n), c);
    return this;
  }
  // Gen 4 outlines: each edge pixel takes a darkened shade of the colour it borders
  outline(dark: (inside: string) => string): this {
    const add: [number, number, string][] = [];
    for (let y = 0; y < this.h; y++)
      for (let x = 0; x < this.w; x++) {
        if (this.has(x, y)) continue;
        const n = this.raw(x, y + 1) || this.raw(x, y - 1) || this.raw(x + 1, y) || this.raw(x - 1, y);
        if (n) add.push([x, y, dark(unpack(n))]);
      }
    for (const [x, y, c] of add) this.set(x, y, c);
    return this;
  }
  flipX(): Px {
    const o = new Px(this.w, this.h);
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) o.d[y * this.w + x] = this.d[y * this.w + (this.w - 1 - x)];
    return o;
  }
  blit(src: Px, ox: number, oy: number): this {
    for (let y = 0; y < src.h; y++) for (let x = 0; x < src.w; x++) { const n = src.d[y * src.w + x]; if (n && this.in(x + ox, y + oy)) this.d[(y + oy) * this.w + x + ox] = n; }
    return this;
  }
  canvas(): HTMLCanvasElement {
    const cv = document.createElement('canvas');
    cv.width = this.w; cv.height = this.h;
    const g = cv.getContext('2d') as CanvasRenderingContext2D;
    const im = g.createImageData(this.w, this.h);
    new Uint32Array(im.data.buffer).set(this.d);
    g.putImageData(im, 0, 0);
    return cv;
  }
}
