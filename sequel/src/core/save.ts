// Versioned saves. Every save carries its format version; loading runs each migration in
// order, so an old save always opens in a newer build.

const KEY = 'rhapsody2.save';
export const SAVE_VERSION = 1;

type Migration = (d: Record<string, unknown>) => Record<string, unknown>;
// MIGRATIONS[n] upgrades a version-n save to version n + 1
const MIGRATIONS: Record<number, Migration> = {};

export function writeSave(data: Record<string, unknown>): boolean {
  try { localStorage.setItem(KEY, JSON.stringify({ v: SAVE_VERSION, at: Date.now(), data })); return true; } catch { return false; }
}

export function readSave(): Record<string, unknown> | null {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return null;
    const box = JSON.parse(raw) as { v: number; data: Record<string, unknown> };
    let d = box.data, v = box.v || 1;
    while (v < SAVE_VERSION) { const m = MIGRATIONS[v]; if (!m) return null; d = m(d); v++; }
    return d;
  } catch { return null; }
}

export function clearSave(): void { try { localStorage.removeItem(KEY); } catch { /* storage blocked */ } }
