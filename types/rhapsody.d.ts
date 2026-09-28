// Type declarations for the game's global namespace. The game ships as one concatenated
// script, so every module shares the global `R`. TypeScript modules (src/*.ts) are fully
// typed against these; the older JavaScript modules still attach extra fields at runtime,
// which is why the big game objects keep an index signature as an escape hatch.

interface Rng {
  (): number;
  int(lo: number, hi: number): number;
  pick<T>(arr: readonly T[]): T;
  chance(p: number): boolean;
  range(lo: number, hi: number): number;
  weighted<T>(pairs: readonly (readonly [T, number])[]): T | undefined;
  shuffle<T>(arr: T[]): T[];
}
interface Noise {
  (x: number, y: number): number;
  fbm(x: number, y: number, oct?: number): number;
}
interface Positioned { x: number; y: number }
interface Bus {
  map: Map<string, ((...args: any[]) => void)[]>;
  on(ev: string, fn: (...args: any[]) => void): void;
  emit(ev: string, ...args: any[]): void;
}
interface SpatialHashT<T extends Positioned = Positioned> {
  cell: number;
  map: Map<number, T[]>;
  clear(): void;
  key(cx: number, cy: number): number;
  insert(o: T): void;
  query(x: number, y: number, r: number, out?: T[]): T[];
}
interface Store {
  get<T = any>(k: string): T | null;
  set(k: string, v: unknown): boolean;
  del(k: string): void;
}

interface Clock {
  t: number; real: number; rate: number;
  update(dt: number): void;
  skip(mins: number): void;
  day(): number; hour(): number; isNight(): boolean; weekday(): string;
  darkness(): number; golden(): number; label(): string;
}
interface Camera {
  x: number; y: number; zoom: number; vw: number; vh: number; ox: number; oy: number;
  left(): number; top(): number;
  onScreen(x: number, y: number, margin?: number): boolean;
  shake(n: number): void;
  [k: string]: any;
}
interface City {
  id: string; name: string; family: string;
  cx: number; cy: number; x0: number; y0: number; x1: number; y1: number;
  buildings: Building[];
  prosperity: number; heat: number;
  [k: string]: any;
}
interface Building {
  id: number; type: string; name: string;
  x: number; y: number; w: number; h: number;
  out: { x: number; y: number }; door: { x: number; y: number };
  face: 'N' | 'S' | 'E' | 'W';
  city: City; cityId: string;
  destroyed: boolean;
  [k: string]: any;
}
interface World {
  W: number; H: number; TH: number; seed: number;
  tile: Uint8Array; obj: Uint8Array; bid: Uint16Array | Uint32Array | Int32Array;
  cities: City[];
  buildings: (Building | null)[];
  idx(x: number, y: number): number;
  inb(x: number, y: number): boolean;
  t(x: number, y: number): number;
  o(x: number, y: number): number;
  setT(x: number, y: number, t: number): void;
  setO(x: number, y: number, o: number): void;
  solidPed(x: number, y: number): boolean;
  solidCar(x: number, y: number): boolean;
  isWater(x: number, y: number): boolean;
  cityAt(tx: number, ty: number): City | null;
  buildingAt(tx: number, ty: number): Building | null;
  biomeAt(tx: number, ty: number): string;
  inCityRect(x: number, y: number, margin?: number): boolean;
  findNear(tx: number, ty: number, rmin: number, rmax: number, pred: (x: number, y: number) => boolean, rnd?: Rng): { x: number; y: number } | null;
  los(ax: number, ay: number, bx: number, by: number): boolean;
  [k: string]: any;
}

interface Person { id: number; first: string; last: string; alive: boolean; opinion: number; fear: number; city: string; actor?: Human | null; [k: string]: any }
interface Human extends Positioned {
  kind: 'h';
  dir: number; ang: number; walk: number;
  hp: number; maxHp: number;
  dead: boolean; down: number;
  state: string; timer: number;
  hostile: boolean; cop: boolean; crew?: boolean;
  look: any; person: Person | null;
  weapon: string; armed: boolean;
  room?: any; inCar?: Vehicle | null;
  [k: string]: any;
}
interface Vehicle extends Positioned {
  kind: 'v';
  modelId: string; model: any;
  angle: number; speed: number; vx: number; vy: number;
  hp: number; maxHp: number;
  driver: Human | Player | null;
  lights: boolean; siren: boolean; wrecked: boolean; burning: number; removed?: boolean;
  [k: string]: any;
}
interface Player extends Positioned {
  hp: number; maxHp: number; cash: number;
  dir: number; ang: number; walk: number;
  dead: boolean; room: any; inCar: Vehicle | null;
  weapon: string; weaponOut: boolean;
  crew: Human[];
  style: Record<string, any>;
  stats: Record<string, number>;
  rep: { honor: number; infamy: number; [k: string]: number };
  street?: Record<string, any>;
  place(x: number, y: number): void;
  [k: string]: any;
}
interface Settings { vol: number; music: number; zoom: number; renderer?: 'gl' | 'classic'; crt?: boolean; [k: string]: any }
interface Game {
  started: boolean;
  settings: Settings;
  world: World; clock: Clock; cam: Camera;
  player: Player;
  waypoint: { x: number; y: number } | null;
  renderer: any; ui: any; actors: any; traffic: any; law: any; jobs: any; pop: any; env: any; fx: any; audio: any; interiors: any; life: any;
  saveSettings(): void;
  tick(dt: number): void;
  [k: string]: any;
}

interface RNS {
  TILE: number;
  DIRS: readonly (readonly [number, number])[];
  FLOW: { N: number; E: number; S: number; W: number; X: number };
  DIRBIT: readonly number[];
  mulberry(seed: number): Rng;
  rng: Rng;
  hash2(x: number, y: number, s?: number): number;
  strHash(s: string): number;
  makeNoise(seed: number): Noise;
  clamp(v: number, lo: number, hi: number): number;
  lerp(a: number, b: number, t: number): number;
  dist(ax: number, ay: number, bx: number, by: number): number;
  dist2(ax: number, ay: number, bx: number, by: number): number;
  angDiff(a: number, b: number): number;
  approach(v: number, target: number, step: number): number;
  compass(dx: number, dy: number): string;
  dir4(dx: number, dy: number): number;
  fmtMoney(n: number): string;
  bus: Bus;
  SpatialHash: new <T extends Positioned = Positioned>(cell: number) => SpatialHashT<T>;
  store: Store;
  game: Game;
  data: any;
  [k: string]: any;
}

declare var R: RNS;
interface Window { R: RNS }
