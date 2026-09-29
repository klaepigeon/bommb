// The future, as the 80s pictured it. Everywhere in the sequel the stuff of game 1 becomes
// the stuff of science fiction: blasters and vibro-knives, hover cars, cantinas, synth-food,
// chrome clinics. And on Earth, the dystopia: smog that never lifts, acid rain that stings,
// poisoned seas, and the whole picture graded like a VHS tape of a movie that got it right.

import { EARTH } from './earth';
import { SPACE } from './space';

const D = R.data;
const rename = (table: Record<string, { name: string }>, map: Record<string, string>) => { for (const [k, v] of Object.entries(map)) if (table[k]) table[k].name = v; };

// ---------------------------------------------------------------- the gear
rename(D.weapons, {
  knuckles: 'Shock Knuckles', bat: 'Stun Baton', knife: 'Vibro-Knife', revolver: 'Blaster Pistol', magnum: 'Hand Cannon', shotgun: 'Scatter Blaster',
  chopper: 'Pulse SMG', rifle: 'Rail Rifle', derringer: 'Holdout Blaster', sawedoff: 'Sawn-Off Scatter', carbine: 'Laser Carbine', crossbow: 'Bolt Caster',
  tommy: 'Drum Pulse Gun', razor: 'Mono-Wire Razor', machete: 'Plasma Machete', hatchet: 'Arc Hatchet', crowbar: 'Pry Bar', sap: 'Neural Sap',
  molotov: 'Napalm Canister', dynamite: 'Thermal Detonator',
});
rename(D.btypes, {
  general: 'Synth-Mart', liquor: 'Synth-Liquor', pharmacy: 'Chrome Clinic', diner: 'Noodle Bar', bar: 'Cantina', club: 'Neon Club', pawn: 'Chop Shop',
  gunshop: 'Blaster Store', tailor: 'Threads', police: 'Peacekeeper Post', hospital: 'Med Centre', garage: 'Hover Garage', hotel: 'Capsule Hotel',
  church: 'Temple of the Signal', social: 'Syndicate Lounge', gas: 'Fuel Cell Depot', butcher: 'Vat-Meat & Hides', school: 'Learning Pod',
  factory: 'Fabricator', office: 'Corp Tower', laundry: 'Sonic Laundry', barber: 'Cyber-Barber', arcade: 'Holo-Arcade', warehouse: 'Cargo Depot',
  barn: 'Hydro-Farm', cabin: 'Hab Module', costume: 'Holo-Masks', strip: 'Holo-Club', motel: 'Hab Motel',
});
rename(D.vehicles, { sedan: 'Ponce Hovercruiser', wagon: 'Brougham Skywagon', muscle: 'Stallion Thruster GT', pickup: 'Bison Cargo Skiff', van: 'Mystic Hover-Van' });
rename(D.consumables || {}, { whiskey: 'Synth-Whiskey', smokes: 'Stim Sticks', coffee: 'Caff-Tab', sandwich: 'Protein Brick', tonic: 'Nano-Tonic', bandage: 'Med-Foam' });
rename(D.loot || {}, { watch: 'Chrono', eight: 'Data Tapes', radio: 'Pocket Holo', fur: 'Synth-Fur Coat' });
rename(D.tools || {}, { lockpick: 'Bypass Kit', mask: 'Holo-Mask' });

// ---------------------------------------------------------------- hover cars
// every car floats a hand's width off the road on a glow
const A = R.art as any, baseCar = A.drawCar;
A.drawCar = function (g: CanvasRenderingContext2D, v: any) {
  if (!v || v.sunk || v.wrecked) return baseCar.call(this, g, v);
  const t = performance.now() / 1000, bob = Math.sin(t * 3 + (v.id || 0)) * 0.8;
  g.save();
  g.fillStyle = 'rgba(90,220,255,0.22)';
  g.beginPath(); g.ellipse(Math.round(v.x), Math.round(v.y) + 3, 16, 6, v.angle || 0, 0, Math.PI * 2); g.fill();
  g.fillStyle = 'rgba(160,240,255,0.35)';
  g.beginPath(); g.ellipse(Math.round(v.x), Math.round(v.y) + 3, 8, 3, v.angle || 0, 0, Math.PI * 2); g.fill();
  g.translate(0, -4 + bob);
  try { return baseCar.call(this, g, v); } finally { g.restore(); }
};

// ---------------------------------------------------------------- Earth's sky
const WEATHER_NAMES = Object.assign({}, R.Env.prototype.WEATHER_NAMES);
const DYSTOPIA_NAMES = { clear: 'Brown Haze', cloudy: 'Smog Cover', rain: 'Acid Rain', storm: 'Toxic Storm', fog: 'Smog', heat: 'Heat Dome' };
const EP = R.Env.prototype, baseSet = EP.setWeather;
EP.setWeather = function (this: any, kind: string) {
  // the sky over Earth hasn't been clear in years
  if (EARTH.active && (kind === 'clear' || kind === 'heat') && Math.random() < 0.75) kind = Math.random() < 0.6 ? 'fog' : 'rain';
  EP.WEATHER_NAMES = EARTH.active ? DYSTOPIA_NAMES : WEATHER_NAMES;
  return baseSet.call(this, kind);
};

// the grade: on Earth everything looks like a rented videotape of the future
let overlay: HTMLDivElement | null = null, graded = '', stingT = 0, told = false;
const GRADE = 'saturate(0.72) sepia(0.34) hue-rotate(-18deg) contrast(1.14) brightness(0.92)';
function ensureOverlay(): HTMLDivElement | null {
  if (overlay) return overlay;
  const stage = document.querySelector('.stage');
  if (!stage) return null;
  overlay = document.createElement('div');
  overlay.className = 'vhs';
  overlay.style.cssText = 'position:absolute;inset:0;pointer-events:none;display:none;mix-blend-mode:overlay;' +
    'background:repeating-linear-gradient(0deg,rgba(0,0,0,0.10) 0 1px,transparent 1px 3px),radial-gradient(ellipse at center,transparent 55%,rgba(40,0,50,0.55) 100%),linear-gradient(180deg,rgba(255,60,160,0.10),rgba(0,200,255,0.06));';
  // over the world, under the HUD
  stage.insertBefore(overlay, stage.querySelector('.hud'));
  return overlay;
}
const GP = R.Game.prototype, baseTick = GP.tick, baseSetup = GP.setup;
GP.setup = function (this: Game, seed: number, save: unknown) {
  const r = baseSetup.call(this, seed, save);
  if (EARTH.active && this.env) this.env.setWeather(Math.random() < 0.5 ? 'rain' : 'fog');
  else if (this.env) EP.WEATHER_NAMES = WEATHER_NAMES;
  return r;
};
GP.tick = function (this: Game, dt: number) {
  const r = baseTick.call(this, dt);
  const on = EARTH.active && !SPACE.active;
  const cv = this.renderer && this.renderer.cv;
  const want = on ? GRADE : !SPACE.active && R.planet && R.planet.grade ? R.planet.grade : '';
  if (cv && graded !== want) { cv.style.filter = want; graded = want; }
  const o = ensureOverlay();
  if (o) o.style.display = on ? 'block' : 'none';
  // acid rain stings out in the open
  if (on && !this.ui.paused() && this.player && !this.player.room && !this.player.inCar) {
    const rain = (this.env && this.env.weather.rain) || 0;
    if (rain > 0.6) {
      stingT -= dt;
      if (stingT <= 0) {
        stingT = 4;
        const pl = this.player;
        if (pl.hp > 30) pl.hp -= 1;
        if (!told) { told = true; this.ui.toast('Acid rain. It stings. Get under cover or into a car.', 'warn'); }
      }
    }
  }
  return r;
};
