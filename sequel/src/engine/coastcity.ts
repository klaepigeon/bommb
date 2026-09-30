// Coast City. Hal Jordan's hometown, on the California coast one sector north of the Brass
// Coast. Parallax burned it to the ground once. The Fear Man rebuilt it in yellow, street by
// street, as a shrine to his master: every lamp, every window, every neon tube and every cloud
// burns gold, and the blimps preach Parallax. The Fear Man keeps court here, in the club on
// the first city's main street. Kill Parallax on Mars and the gold starts to fade.

import { SQ, saveSequel } from './state';
import { inCoastCity } from './dystopia';
import { markFearMan, fearDead } from './fearboss';

export const COAST_SLOGANS = ['PARALLAX IS FEAR', 'FEAR IS ORDER', 'HE BURNED IT · WE REBUILT IT', 'YELLOW IS THE ONLY LIGHT', 'PRAISE THE GREAT FEAR', 'COAST CITY REMEMBERS'];
export const COAST_NEON = ['#ffe070', '#f0c020', '#fff27a'];

const GP = R.Game.prototype, setup = GP.setup;
GP.setup = function (this: Game, seed: number, save: unknown) {
  const r = setup.call(this, seed, save);
  if (inCoastCity()) {
    const g = this;
    setTimeout(() => {
      if (!SQ.flags.coastSeen) {
        SQ.flags.coastSeen = 1; saveSequel();
        g.ui.story('Coast City', `Hal Jordan's hometown.\n\nParallax burned it to the ground once, a long time ago, and the Fear Man rebuilt it for him: every street, every lamp, every window, all of it in yellow. The light here has one colour, and it isn't a colour that makes you feel safe.\n\nThe blimps say PARALLAX IS FEAR. The Syndicate say the old man has his club on the main street, and that he talks to his master on Mars at night, in the yellow.${SQ.flags.parallax === 2 ? '\n\n(Parallax is dead. The gold is already fading at the edges.)' : ''}`, () => { if (!fearDead()) markFearMan(g); });
      } else if (!fearDead()) markFearMan(g);
    }, 600);
  }
  return r;
};

(window as any).BS2 = Object.assign((window as any).BS2 || {}, { inCoastCity });
