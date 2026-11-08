// The flat's floor plan. Flat 47, fourth floor of Building 14, a 1950s brick block on a
// courtyard. Metres; x runs east, z runs south (into the building), y is up.
// The north wall (z = 0) faces the courtyard; the east wall (x = 10) is the stairwell.
export const H = 2.75;      // floor to ceiling
export const T = 0.14;      // interior partitions
export const EXT = 0.42;    // outer brick walls
export const DOOR_H = 2.05;
export const STOREY = 3.1;  // floor-to-floor outside
export const FLOOR_NO = 4;  // ground is (FLOOR_NO-1) storeys + plinth below
export const GROUND = -(FLOOR_NO - 1) * STOREY - 0.9;

export const ROOMS = {
  living:  { x0: 0,   x1: 4.4, z0: 0,   z1: 5.2, name: 'Living room' },
  bedroom: { x0: 4.4, x1: 7.6, z0: 0,   z1: 3.8, name: 'Bedroom' },
  kitchen: { x0: 7.6, x1: 10,  z0: 0,   z1: 3.8, name: 'Kitchen' },
  hall:    { x0: 4.4, x1: 10,  z0: 3.8, z1: 5.2, name: 'Hallway' },
  storage: { x0: 0,   x1: 2.8, z0: 5.2, z1: 8,   name: 'Box room' },
  child:   { x0: 2.8, x1: 6.4, z0: 5.2, z1: 8,   name: "Sonya's room" },
  bath:    { x0: 6.4, x1: 10,  z0: 5.2, z1: 8,   name: 'Bathroom' },
};
export const BOUNDS = { x0: 0, x1: 10, z0: 0, z1: 8 };

// inner (finished-surface) rectangle of a room: inset by half a partition where it isn't an outer wall
export function inner(r) {
  const k = T / 2;
  return {
    x0: r.x0 === BOUNDS.x0 ? r.x0 : r.x0 + k, x1: r.x1 === BOUNDS.x1 ? r.x1 : r.x1 - k,
    z0: r.z0 === BOUNDS.z0 ? r.z0 : r.z0 + k, z1: r.z1 === BOUNDS.z1 ? r.z1 : r.z1 - k,
  };
}

// Walls. axis 'x' = a wall in the plane x = c running along z; axis 'z' = plane z = c along x.
// p0..p1 = the wall's thickness span on its own axis.
export const LINES = [
  { id: 'n',  axis: 'z', c: 0,   p0: -EXT, p1: 0,        a0: -EXT, a1: 10 + EXT, ext: true },
  { id: 's',  axis: 'z', c: 8,   p0: 8,    p1: 8 + EXT,  a0: -EXT, a1: 10 + EXT, ext: true },
  { id: 'w',  axis: 'x', c: 0,   p0: -EXT, p1: 0,        a0: 0,    a1: 8,        ext: true },
  { id: 'e',  axis: 'x', c: 10,  p0: 10,   p1: 10 + EXT, a0: 0,    a1: 8,        ext: true },
  { id: 'i1', axis: 'x', c: 4.4, p0: 4.4 - T / 2, p1: 4.4 + T / 2, a0: 0,   a1: 5.2 },
  { id: 'i2', axis: 'x', c: 7.6, p0: 7.6 - T / 2, p1: 7.6 + T / 2, a0: 0,   a1: 3.8 },
  { id: 'i3', axis: 'z', c: 3.8, p0: 3.8 - T / 2, p1: 3.8 + T / 2, a0: 4.4, a1: 10 },
  { id: 'i4', axis: 'z', c: 5.2, p0: 5.2 - T / 2, p1: 5.2 + T / 2, a0: 0,   a1: 10 },
  { id: 'i5', axis: 'x', c: 2.8, p0: 2.8 - T / 2, p1: 2.8 + T / 2, a0: 5.2, a1: 8 },
  { id: 'i6', axis: 'x', c: 6.4, p0: 6.4 - T / 2, p1: 6.4 + T / 2, a0: 5.2, a1: 8 },
];

// Openings: on a line, along a0..a1, heights y0..y1.
export const OPENINGS = [
  { id: 'livWin',   line: 'n',  a0: 0.75, a1: 2.55, y0: 0.85, y1: 2.35, kind: 'window' },
  { id: 'balDoor',  line: 'n',  a0: 2.8,  a1: 3.55, y0: 0,    y1: 2.35, kind: 'balcony' },
  { id: 'bedWin',   line: 'n',  a0: 5.25, a1: 6.75, y0: 0.85, y1: 2.35, kind: 'window' },
  { id: 'kitWin',   line: 'n',  a0: 8.25, a1: 9.45, y0: 0.95, y1: 2.35, kind: 'window' },
  { id: 'childWin', line: 's',  a0: 3.85, a1: 5.35, y0: 0.85, y1: 2.35, kind: 'window' },
  { id: 'dLiving',  line: 'i1', a0: 4.18, a1: 5.03, y0: 0, y1: DOOR_H, kind: 'door' },
  { id: 'dBed',     line: 'i3', a0: 6.5,  a1: 7.35, y0: 0, y1: DOOR_H, kind: 'door' },
  { id: 'dKit',     line: 'i3', a0: 8.1,  a1: 8.95, y0: 0, y1: DOOR_H, kind: 'door' },
  { id: 'dChild',   line: 'i4', a0: 5.25, a1: 6.05, y0: 0, y1: DOOR_H, kind: 'door' },
  { id: 'dBath',    line: 'i4', a0: 8.75, a1: 9.45, y0: 0, y1: DOOR_H, kind: 'door' },
  { id: 'dStore',   line: 'i4', a0: 1.45, a1: 2.2,  y0: 0, y1: DOOR_H, kind: 'door' },
  { id: 'dEntry',   line: 'e',  a0: 4.12, a1: 5.0,  y0: 0, y1: DOOR_H + 0.05, kind: 'entry' },
];
export const lineById = Object.fromEntries(LINES.map((l) => [l.id, l]));
export const openById = Object.fromEntries(OPENINGS.map((o) => [o.id, o]));

// balcony outside the living room
export const BALCONY = { x0: 0.55, x1: 3.95, z0: -1.75, z1: -EXT, y: -0.12 };
// stair landing beyond the front door
export const LANDING = { x0: 10 + EXT, x1: 13.6, z0: 2.2, z1: 7.0 };

// where the player wakes up, and which way they face (yaw)
export const SPAWN = { x: 9.35, z: 4.55, yaw: Math.PI / 2 + 0.25 };

export function roomAt(x, z, y = 0) {
  if (y < -0.6 || y > 2.95) return null;
  for (const [k, r] of Object.entries(ROOMS)) if (x >= r.x0 && x < r.x1 && z >= r.z0 && z < r.z1) return k;
  if (x >= BALCONY.x0 && x <= BALCONY.x1 && z >= BALCONY.z0 && z < 0) return 'balcony';
  return null;
}

// ---------------------------------------------------------------- the rest of Building 14
// Floor f's landing is at y = floorY(f); flat 47 is on floor 4 (y = 0).
export const floorY = (f) => (f - FLOOR_NO) * STOREY;
// The stairwell: a switchback stair between the Sokolovs' flat (west) and 48 (east).
//   landing (floor level):  z STAIR.zl .. STAIR.z1
//   two flights:            z STAIR.zm .. STAIR.zl — west one down to the half-landing, east one on down
//   half-landing:           z STAIR.z0 .. STAIR.zm at floor - STOREY/2
// A narrow well runs down between the flights, all the way.
export const STAIR = {
  x0: 10 + EXT, x1: 14.0, z0: 0, z1: 8, zm: 1.25, zl: 3.45,
  wx1: 12.06, ex0: 12.36,           // west flight x0..wx1, well wx1..ex0, east flight ex0..x1
  floors: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10], top: 9, // 10 exists only to be looked at, then you're back on 9
};
// four flats a landing: west (behind the west wall), two east, one south. Floor 4: 47, 48, 49, 50
export const flatNo = (f, k) => 4 * f + 31 + k; // k: 0 west, 1 east-near, 2 east-far, 3 south
