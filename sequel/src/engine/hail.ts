// Hailing. Fly up alongside a freighter (not shooting) and USE hails her. Trade with her at
// sea (a markup, but no pad needed), or lean on her: the captain weighs your guns against his
// and either dumps the hold out of the airlock (stolen, of course) or calls mayday and fights.

import { SQ, saveSequel, type Good } from './state';
import { SPACE, HOOKS, type Craft } from './space';
import { stats } from '../ship/ship';
import { addCargo, GOODS, price } from './cargo';
import { fmt } from './bounty';

const near = (): Craft | null => SPACE.crafts.find((c) => c.kind === 'freighter' && !c.dead && !c.disabled && !c.hostile && !(c as any).noHail && Math.hypot(c.x - SPACE.x, c.y - SPACE.y) < 260) || null;
const worth = (g: Good) => price('earth', g);
const firepower = (st: ReturnType<typeof stats>) => st.guns * st.dmg + st.missiles * 30 + st.drones * 12 + st.shield * 0.3;

function hail(g: Game, c: Craft): void {
  const my = stats(SQ.ship), their = stats(c.ship);
  const odds = Math.max(0.05, Math.min(0.95, firepower(my) / (firepower(my) + firepower(their) + 20) + (g.player.rep.infamy || 0) / 400));
  const load = c.cargo.filter((l) => l.n > 0);
  g.ui.choice(`${c.name} · ${c.flag === 'empire' ? 'Imperial' : 'Solari'} freighter`, [
    ...load.map((l) => ({ label: `Buy her ${GOODS[l.good].name} (${l.n})`, small: `${fmt(Math.round(worth(l.good) * 1.2))} each, over the airlock`, fn: () => {
      const each = Math.round(worth(l.good) * 1.2), k = Math.min(l.n, Math.floor(g.player.cash / each));
      if (!k) return g.ui.toast('You can\'t afford a crate.', 'warn');
      const put = addCargo(l.good, k, false);
      if (!put) return g.ui.toast('No room in your holds.', 'warn');
      l.n -= put; g.player.cash -= put * each; g.audio.sfx('cash'); saveSequel();
      g.ui.toast(`${put} ${GOODS[l.good].name} across the airlock. Pleasure doing business.`, 'good');
    } })),
    { label: 'Demand her cargo', small: `Your guns against hers: about ${Math.round(odds * 100)}% she folds`, fn: () => {
      if (Math.random() < odds) {
        let got = 0;
        for (const l of load) { const put = addCargo(l.good, l.n, true); l.n -= put; got += put; }
        c.looted = true;
        if (c.flag === 'empire') { SQ.heat.empire += 10; SQ.bounty += 100; } else SQ.heat.families += 10;
        g.player.rep.infamy = (g.player.rep.infamy || 0) + 1;
        saveSequel(); g.audio.sfx('loot');
        g.ui.toast(got ? `The captain dumps ${got} crates out of the airlock and burns for home. Not a shot fired.` : 'She folds, but your holds are full. Nothing to take.', got ? 'good' : 'warn');
        SQ.achieved = SQ.achieved || {}; SQ.achieved.shakedowns = (SQ.achieved.shakedowns || 0) + 1;
      } else {
        c.hostile = true; c.cool = 0.5;
        if (c.flag === 'empire') { SQ.heat.empire += 15; SQ.bounty += 150; }
        g.ui.toast(`${c.name}: "Mayday, mayday! Pirates!" She opens fire.`, 'bad');
        g.audio.sfx('alarm');
      }
    } },
    { label: 'Wish her a safe run', small: '', fn: () => g.ui.toast(`${c.name}: "And you, stranger."`) },
  ]);
}
HOOKS.use.push((g) => { const c = near(); return c ? { label: 'Hail', fn: () => hail(g, c) } : null; });

(window as any).BS2 = Object.assign((window as any).BS2 || {}, { hail: (c: Craft) => hail(R.game, c) });
