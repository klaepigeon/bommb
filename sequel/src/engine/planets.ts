// Our solar system in XX8X. Every body has its real orbit (semi-major axis in AU, period in
// days) and a surface gravity that shapes flight around it. Landable worlds are full game 1
// worlds (the same generator, population, traffic, law, families, jobs and every other
// system) with that world's names, families, terrain and police laid over them. Game 1's five
// city slots are kept (the systems key on them) and renamed per world.

import { SQ } from './state';

// Worlds are data: our solar system is one set, and the jump drive loads others (see
// galaxy.ts), so the ids are plain strings. The star is always 'sun'.
export type PlanetId = string;
export type BodyId = string;

export interface BodyDef {
  id: BodyId; name: string; parent: BodyId | null;
  au: number; // orbit radius around the parent, in AU (moons: in parent radii)
  days: number; // orbital period
  radius: number; // drawn radius in game units (exaggerated: true scale would make planets dots)
  gs: number; // surface gravity, game units/s²
  color: string; sea?: string; rings?: boolean; bands?: boolean; air?: boolean;
  blurb: string;
}

// 1 AU in game units. Planet radii are exaggerated ~200× so they read at ship scale; the
// distances stay true to each other, so the outer system is genuinely far.
export const AU = 60000;

export const SOL_BODIES: BodyDef[] = [
  { id: 'sun', name: 'The Sun', parent: null, au: 0, days: 1, radius: 2600, gs: 900, color: '#ffe070', blurb: 'Don\'t.' },
  { id: 'mercury', name: 'Mercury', parent: 'sun', au: 0.387, days: 88, radius: 180, gs: 40, color: '#a09088', blurb: 'Scorched rock. The Empire runs a solar-mirror prison on the dark side (not open yet).' },
  { id: 'venus', name: 'Venus', parent: 'sun', au: 0.723, days: 225, radius: 430, gs: 95, color: '#e8d098', blurb: 'The Imperial capital: marble cloud-cities floating above an acid sea.' },
  { id: 'earth', name: 'Earth', parent: 'sun', au: 1.0, days: 365, radius: 460, gs: 100, color: '#4a8a4a', sea: '#2a64b8', blurb: 'Home. The Brass Coast is still down there, ten years older, and so are its families.' },
  { id: 'luna', name: 'Luna', parent: 'earth', au: 8, days: 27.3, radius: 150, gs: 30, color: '#b0a8a0', blurb: 'The Moon: mining domes, a black market, and hymns on the radio at night.' },
  { id: 'mars', name: 'Mars', parent: 'sun', au: 1.524, days: 687, radius: 280, gs: 60, color: '#c8603a', sea: '#3a7ed0', blurb: 'Terraformed and green where the money is, red dust where it isn\'t. Casino city of the system.' },
  { id: 'ceres', name: 'Ceres', parent: 'sun', au: 2.77, days: 1680, radius: 110, gs: 22, color: '#8a8478', blurb: 'The biggest rock in the belt: claim-jumpers, ice miners and nobody\'s law.' },
  { id: 'jupiter', name: 'Jupiter', parent: 'sun', au: 5.2, days: 4333, radius: 1500, gs: 220, color: '#d8a878', bands: true, blurb: 'The king. Gas-mining rigs in the storms (not open yet).' },
  { id: 'io', name: 'Io', parent: 'jupiter', au: 2.4, days: 1.8, radius: 120, gs: 28, color: '#e8d040', blurb: 'Volcanoes and sulphur. Nobody lives here on purpose.' },
  { id: 'europa', name: 'Europa', parent: 'jupiter', au: 3.3, days: 3.6, radius: 110, gs: 25, color: '#e0d8c8', blurb: 'Ice over an ocean. Something down there answers radio calls.' },
  { id: 'ganymede', name: 'Ganymede', parent: 'jupiter', au: 4.4, days: 7.2, radius: 160, gs: 30, color: '#9a8a7a', blurb: 'The biggest moon. Rebel shipyards, if you believe the rumours.' },
  { id: 'callisto', name: 'Callisto', parent: 'jupiter', au: 5.8, days: 16.7, radius: 150, gs: 26, color: '#6a5a4a', blurb: 'Cratered and quiet. Too quiet, say the miners.' },
  { id: 'saturn', name: 'Saturn', parent: 'sun', au: 9.58, days: 10759, radius: 1250, gs: 190, color: '#e8d0a0', bands: true, rings: true, blurb: 'The rings are full of claim-jumpers and wrecks.' },
  { id: 'titan', name: 'Titan', parent: 'saturn', au: 3.6, days: 16, radius: 170, gs: 28, color: '#d8a048', blurb: 'Orange haze and methane lakes. The Choir came from here.' },
  { id: 'uranus', name: 'Uranus', parent: 'sun', au: 19.2, days: 30687, radius: 620, gs: 120, color: '#a8e0e8', blurb: 'Cold, pale and sideways.' },
  { id: 'neptune', name: 'Neptune', parent: 'sun', au: 30.1, days: 60190, radius: 600, gs: 125, color: '#4a6ae0', blurb: 'The edge of the map. The Corps keeps an outpost out here, they say.' },
];
// the live registry: whatever system you're in (filled by loadSystem)
export const BODIES: BodyDef[] = [];
export const BODY: Record<BodyId, BodyDef> = {};

export interface CityProfile { name: string; tag: string; family: string; don: string; biome?: string }
export interface Profile {
  id: PlanetId; name: string; blurb: string; faction: string;
  cities: [CityProfile, CityProfile, CityProfile, CityProfile, CityProfile] | null; // null = game 1's own names
  hamlets: [string, string, string, string] | null;
  law: string;
  terrain: 'earth' | 'mars' | 'moon' | 'capital' | 'jungle' | 'ice';
  black: boolean; // a black market that buys stolen cargo
  imperial?: boolean; // Imperial law: the bounty is enforced here
  species?: [string, number][]; // alien species living here, and their share of the population
  fauna?: string; // the ecosystem (see eco.ts)
}

export const SOL_PLANETS: Record<PlanetId, Profile> = {
  earth: {
    id: 'earth', name: 'Earth', faction: 'the five families of the Brass Coast', blurb: SOL_BODIES[3].blurb,
    cities: null, hamlets: null, law: 'Police', terrain: 'earth', black: false, fauna: 'earth',
  },
  mars: {
    id: 'mars', name: 'Mars', faction: 'the Solari families', blurb: SOL_BODIES[5].blurb, law: 'Imperial Security', terrain: 'mars', black: false, imperial: true, fauna: 'mars', species: [['martian', 0.08]],
    cities: [
      { name: 'Olympus Quay', tag: 'pads, piers and payoffs', family: 'Solari', don: 'Marcello "The Green" Solari' },
      { name: 'Green Mile', tag: 'the casinos never close', family: 'Marchetti', don: 'Vittoria Marchetti' },
      { name: 'Tharsis Flats', tag: 'red dust and smuggler strips', family: 'Voss', don: 'Anton Voss', biome: 'desert' },
      { name: 'Polar Cap City', tag: 'ice farms and quiet men', family: 'Kade', don: 'Declan Kade' },
      { name: 'Hellas Mire', tag: 'basin swamps and hush money', family: 'Orlov', don: 'Mama Irina Orlov' },
    ],
    hamlets: ['Orchard Ring', 'Viking Landing', 'Tollgate', 'Glasshouse Row'],
  },
  venus: {
    id: 'venus', name: 'Venus', faction: 'the Galactic Empire', blurb: SOL_BODIES[2].blurb, law: 'Imperial Security', terrain: 'capital', black: false, imperial: true, fauna: 'venus', species: [['saurian', 0.07]],
    cities: [
      { name: 'Imperial Docks', tag: 'customs, cargo and bribes', family: 'Varro', don: 'Senator Lucan Varro' },
      { name: 'Castra Prime', tag: 'marble, neon and surveillance', family: 'Aurelian', don: 'Prefect Aurelia Aurelian' },
      { name: 'Ashfall', tag: 'the prison quarries', family: 'Draken', don: 'Warden Silas Draken', biome: 'desert' },
      { name: 'Highspire', tag: 'the court in the clouds', family: 'Corvin', don: 'Duchess Mireille Corvin' },
      { name: 'The Undercroft', tag: 'where the Empire hides its mess', family: 'Rook', don: 'Commander Ysolde Rook' },
    ],
    hamlets: ['Garrison Nine', 'Aqueduct Gate', 'Cenotaph', 'Relay Station'],
  },
  luna: {
    id: 'luna', name: 'Luna', faction: 'the Choir and the rebels', blurb: SOL_BODIES[4].blurb, law: 'Mine Security', terrain: 'moon', black: true, fauna: 'luna', species: [['grey', 0.1], ['choir', 0.08]],
    cities: [
      { name: 'Tranquility Port', tag: 'no names, no logs', family: 'Ironjaw', don: 'Big Ma Ironjaw' },
      { name: 'Shaft Nine', tag: 'the mine that sings', family: 'Choir', don: 'Mother Canticle' },
      { name: 'Red Flats', tag: 'rebel country', family: 'Rook', don: 'Captain Ysolde Rook', biome: 'desert' },
      { name: 'Shackleton Ice', tag: 'water is worth killing for', family: 'Sorensen', don: 'Old Sven Sorensen' },
      { name: 'Brine Deep', tag: 'the salt swamps under the dome', family: 'Lark', don: 'Dolly Lark' },
    ],
    hamlets: ['Relay Six', 'Crater Stop', 'The Dig', 'Hymnal'],
  },
  ceres: {
    id: 'ceres', name: 'Ceres', faction: 'the claim-jumpers', blurb: SOL_BODIES.find((b) => b.id === 'ceres')!.blurb, law: 'Claim Wardens', terrain: 'ice', black: true, fauna: 'ceres', species: [['grey', 0.05], ['belter', 0.12]],
    cities: [
      { name: 'Occator Deep', tag: 'the bright spot, and the brightest bar', family: 'Mbeki', don: 'Auntie Nandi Mbeki' },
      { name: 'Ahuna Mons', tag: 'the ice volcano company town', family: 'Halloran', don: 'Foreman Halloran' },
      { name: 'Claim Forty', tag: 'first come, first shot', family: 'Szabo', don: 'Laci "Pick" Szabo', biome: 'desert' },
      { name: 'Kerwan Basin', tag: 'the old crater camps', family: 'Okafor', don: 'Ma Okafor' },
      { name: 'Haulyard', tag: 'where the ore ships dock', family: 'Duval', don: 'Remy Duval' },
    ],
    hamlets: ['Drill Nine', 'Tailings', 'Icebox', 'Last Claim'],
  },
};
// the live registry of landable worlds in the current system
export const PLANETS: Record<PlanetId, Profile> = {};
export const landable = () => Object.keys(PLANETS);

// swap the live registry to another system's bodies and worlds
export function loadSystem(bodies: BodyDef[], planets: Record<PlanetId, Profile>): void {
  BODIES.length = 0;
  BODIES.push(...bodies);
  for (const k of Object.keys(BODY)) delete BODY[k];
  for (const b of bodies) BODY[b.id] = b;
  for (const k of Object.keys(PLANETS)) delete PLANETS[k];
  Object.assign(PLANETS, planets);
}
loadSystem(SOL_BODIES, SOL_PLANETS);

// other systems come from the generator (galaxy.ts registers it); the same id always
// generates the same system
export interface System { id: string; name: string; bodies: BodyDef[]; planets: Record<PlanetId, Profile>; belt?: [number, number]; ly: number }
export const SOL: System = { id: 'sol', name: 'Sol', bodies: SOL_BODIES, planets: SOL_PLANETS, belt: [2.2, 3.3], ly: 0 };
export const GEN: { system: ((id: string) => System) | null } = { system: null };
export const systemData = (id: string): System => (id === 'sol' || !GEN.system ? SOL : GEN.system(id));
// the profile of the world you're standing on (it may be in a different system from your ship)
export const worldProfile = (): Profile => systemData(SQ.home).planets[SQ.planet] || SOL_PLANETS.mars;

// game 1's own names, for the text layer that renames them on the fly
export const GAME1 = {
  cities: ['Port Hollow', 'New Avalon', 'Dustwater', 'Pinecrest', 'Bayou Clair'],
  families: ['Vane', 'Castellano', 'Reyes', "O'Malley", 'Thibodeaux'],
  dons: ['Augustin "Gus" Vane', 'Carmine Castellano', 'Soledad Reyes', "Declan O'Malley", 'Mama Odile Thibodeaux'],
  hamlets: ["Kessler's Crossing", 'Coyote Flats', 'Mercy Falls', 'Tupelo Bend'],
};

// the substitutions for one world, longest first so "Port Hollow" goes before "Hollow";
// game 1's calendar year moves on ten years everywhere
export function renames(p: Profile): [RegExp, string][] {
  const out: [RegExp, string][] = [[/XX7X/g, 'XX8X']];
  if (!p.cities || !p.hamlets) return out;
  const pairs: [string, string][] = [];
  GAME1.dons.forEach((d, i) => pairs.push([d, p.cities![i].don]));
  pairs.push(['Gus Vane', p.cities[0].don], ['Don Vane', 'Don ' + p.cities[0].family]);
  GAME1.cities.forEach((c, i) => pairs.push([c, p.cities![i].name]));
  GAME1.hamlets.forEach((h, i) => pairs.push([h, p.hamlets![i]]));
  GAME1.families.forEach((f, i) => pairs.push([f, p.cities![i].family]));
  pairs.push(['the Brass Coast', p.name], ['The Brass Coast', p.name], ['Brass Coast', p.name], ['BRASS COAST', p.name.toUpperCase()]);
  pairs.sort((a, b) => b[0].length - a[0].length);
  const esc = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return out.concat(pairs.filter(([a, b]) => a !== b).map(([a, b]) => [new RegExp(`\\b${esc(a)}\\b`, 'g'), b] as [RegExp, string]));
}
