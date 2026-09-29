// The game: persistent state (money, cargo, ship, heat, clock, objectives) and the scene
// switcher. Scenes own their own update/draw; the game hands them input and the screens.

import type { Input } from './core/input';
import { readSave, writeSave } from './core/save';
import { starterShip, stats, type Ship } from './ship/ship';
import type { PlanetId } from './world/planets';
import type { Look } from './gfx/people';

export type Good = 'rum' | 'tea' | 'ore' | 'meds' | 'vinyl' | 'blasters';
export const GOODS: Record<Good, { name: string; base: number; contraband?: boolean }> = {
  rum: { name: 'Synth-Rum', base: 40 },
  tea: { name: 'Spice Tea', base: 25 },
  ore: { name: 'Raw Ore', base: 15 },
  meds: { name: 'Medkits', base: 60 },
  vinyl: { name: 'Holo-Vinyl', base: 35 },
  blasters: { name: 'Blasters', base: 120, contraband: true },
};
// what each market pays, as a multiple of the base price
export const PRICES: Record<PlanetId, Partial<Record<Good, number>>> = {
  veridia: { rum: 1.35, tea: 0.7, ore: 1.5, meds: 1.1, vinyl: 0.8, blasters: 1.2 },
  castra: { rum: 1.1, tea: 1.2, ore: 1.2, meds: 0.8, vinyl: 1.4, blasters: 1.6 },
  hollow: { rum: 0.8, tea: 1.4, ore: 0.6, meds: 1.6, vinyl: 1.3, blasters: 1.8 },
};

export interface CargoLot { good: Good; n: number; stolen: boolean; hidden: boolean }

export interface Objective { id: string; text: string; done: boolean }

export interface Scene {
  name: string;
  enter?(): void;
  update(dt: number, input: Input): void;
  draw(g: CanvasRenderingContext2D, W: number, H: number): void;
  // what A does right now (shown on the button), or '' for nothing
  action(): string;
  // hooks for the automated tests
  test?: Record<string, () => unknown>;
}

export interface Ui {
  say(who: string, text: string, choices?: { label: string; fn: () => void }[]): void;
  busy(): boolean;
  toast(text: string, kind?: 'good' | 'bad' | ''): void;
  refresh(): void;
  openApp(app: string): void;
}

export class Game {
  credits = 800;
  cargo: CargoLot[] = [];
  ship: Ship = starterShip('Brass Buzzard');
  heat = { empire: 0, families: 0 };
  hp = 100;
  shipHull = -1; // -1 = full
  minutes = 8 * 60;
  location: { kind: 'planet' | 'space' | 'board'; planet: PlanetId } = { kind: 'planet', planet: 'veridia' };
  log: { t: number; text: string }[] = [];
  objectives: Objective[] = [
    { id: 'talk', text: 'Check in at Pad Control', done: false },
    { id: 'launch', text: 'Walk to your ship and launch', done: false },
    { id: 'rob', text: 'Disable and board a freighter', done: false },
    { id: 'fence', text: 'Sell the loot on Hollow Moon\'s black market', done: false },
    { id: 'upgrade', text: 'Refit your ship at a shipyard', done: false },
  ];
  player: Look = { skin: '#e0a880', hair: '#2a2230', style: 'short', top: '#e8742a', bottom: '#3a3a48', shoes: '#2a2028', outfit: 'flight', stache: true };
  scene: Scene | null = null;
  ui!: Ui;
  fade = 0;
  private pending: (() => Scene) | null = null;

  go(make: () => Scene): void { this.pending = make; this.fade = 0.0001; }

  tick(dt: number, input: Input): void {
    this.minutes += dt * 2; // one in-game hour per 30 real seconds
    if (this.fade > 0) {
      this.fade += dt * 3;
      if (this.fade >= 1 && this.pending) { this.scene = this.pending(); this.pending = null; this.scene.enter?.(); this.ui.refresh(); }
      if (this.fade >= 2) this.fade = 0;
      return;
    }
    this.scene?.update(dt, input);
    // Imperial heat cools off slowly
    this.heat.empire = Math.max(0, this.heat.empire - dt * 0.05);
  }

  hour(): number { return Math.floor(this.minutes / 60) % 24; }
  day(): number { return Math.floor(this.minutes / 1440) + 1; }
  clockLabel(): string {
    const h = this.hour(), m = Math.floor(this.minutes % 60);
    return `DAY ${this.day()} ${((h + 11) % 12) + 1}:${String(m).padStart(2, '0')}${h < 12 ? 'AM' : 'PM'}`;
  }
  // 0 = full day, 1 = deep night, with dawn and dusk between
  darkness(): number {
    const h = (this.minutes / 60) % 24;
    if (h >= 7 && h < 18) return 0;
    if (h >= 18 && h < 21) return (h - 18) / 3;
    if (h >= 21 || h < 5) return 1;
    return 1 - (h - 5) / 2;
  }

  radio(text: string): void { this.log.unshift({ t: this.minutes, text }); if (this.log.length > 40) this.log.pop(); this.ui?.refresh(); }
  complete(id: string): void {
    const o = this.objectives.find((x) => x.id === id);
    if (!o || o.done) return;
    o.done = true;
    const next = this.objectives.find((x) => !x.done);
    this.ui.toast(`✓ ${o.text}`, 'good');
    this.radio(next ? `Done: ${o.text}. Next: ${next.text}.` : `Done: ${o.text}. That's everything in this build!`);
  }

  // cargo
  used(): { open: number; hidden: number } {
    let open = 0, hidden = 0;
    for (const l of this.cargo) if (l.hidden) hidden += l.n; else open += l.n;
    return { open, hidden };
  }
  addCargo(good: Good, n: number, stolen: boolean): number {
    const s = stats(this.ship), u = this.used();
    // stolen goods go to the smuggler's hold first
    let left = n, put = 0;
    const into = (hidden: boolean, room: number) => {
      const k = Math.min(left, room);
      if (k <= 0) return;
      const lot = this.cargo.find((l) => l.good === good && l.stolen === stolen && l.hidden === hidden);
      if (lot) lot.n += k; else this.cargo.push({ good, n: k, stolen, hidden });
      left -= k; put += k;
    };
    if (stolen) { into(true, s.hidden - u.hidden); into(false, s.cargo - u.open); }
    else { into(false, s.cargo - u.open); into(true, s.hidden - u.hidden); }
    return put;
  }
  price(planet: PlanetId, good: Good): number { return Math.round(GOODS[good].base * (PRICES[planet][good] || 1)); }

  // saves
  save(): void {
    writeSave({ credits: this.credits, cargo: this.cargo, ship: this.ship, heat: this.heat, hp: this.hp, minutes: this.minutes, location: this.location, objectives: this.objectives, log: this.log.slice(0, 12), player: this.player });
  }
  load(): boolean {
    const d = readSave();
    if (!d) return false;
    Object.assign(this, {
      credits: d.credits, cargo: d.cargo, ship: d.ship, heat: d.heat, hp: d.hp, minutes: d.minutes, log: d.log || [], player: d.player || this.player,
      location: { kind: 'planet', planet: (d.location as { planet: PlanetId }).planet || 'veridia' },
    });
    const saved = d.objectives as Objective[];
    for (const o of this.objectives) o.done = !!saved.find((x) => x.id === o.id && x.done);
    return true;
  }
}
