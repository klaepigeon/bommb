// Make the ship yours: a name on the hull and a paint job, at the pad (walk up to your ship).
// Every paint is an 80s colour scheme; the sprite, the stripes and the shading follow it.

import { SQ, saveSequel } from './state';
import { SHIP_MENU } from './travel';

const PAINTS: [string, string][] = [
  ['Brass Buzzard', '#d8d4c8'], ['Miami Pink', '#ff5a9a'], ['Outrun Purple', '#7a4ac8'], ['Chrome', '#c8ccd8'], ['Midnight', '#2a2a3a'],
  ['Hot Rod Red', '#d83a2a'], ['Racing Green', '#2a6a3a'], ['Sunset Orange', '#f08a3a'], ['Laser Teal', '#3ac8c8'], ['Gold Rush', '#e0b030'],
  ['Imperial White', '#eceef4'], ['Rebel Rust', '#c86a3a'],
];
const PRICE = 300;
export function repaint(g: Game): void {
  g.ui.choice(`Paint the ${SQ.ship.name} · ${'$' + PRICE}`, PAINTS.map(([name, col]) => ({ label: name, small: SQ.ship.paint === col ? 'Current paint' : col, fn: () => {
    if (SQ.ship.paint === col) return;
    if (g.player.cash < PRICE) return g.ui.toast(`A paint job is $${PRICE}.`, 'warn');
    g.player.cash -= PRICE; SQ.ship.paint = col; saveSequel();
    g.audio.sfx('equip');
    g.ui.toast(`The ${SQ.ship.name}, in ${name}. Looks fast.`, 'good');
  } })));
}
export function rename(g: Game): void {
  const n = window.prompt('Name your ship', SQ.ship.name);
  if (!n || !n.trim()) return;
  SQ.ship.name = n.trim().slice(0, 22); saveSequel();
  g.ui.toast(`She's the ${SQ.ship.name} now. Paint the name on the nose.`, 'good');
}
SHIP_MENU.push((g) => ({ label: 'Paint and name', small: `The ${SQ.ship.name}: paint jobs $${PRICE}, a new name free`, fn: () => g.ui.choice('Paint and name', [{ label: 'Repaint the hull', fn: () => repaint(g) }, { label: 'Rename the ship', fn: () => rename(g) }]) }));

(window as any).BS2 = Object.assign((window as any).BS2 || {}, { PAINTS });
