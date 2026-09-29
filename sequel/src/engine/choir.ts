// The Choir's story. On Luna the Choir hum in the streets; listen to them three times and they
// send you to Titan, where their Cathedral hangs in the orange haze. Let the signal in, bring
// the Cathedral five Song-Pearls from Europa's deep ones, and the Choir sings you the way to
// where the song comes from: the Source, a thing out past Neptune that isn't on any chart.
// Fly there (it's on "Where to?"), scan it, and choose:
//   Join the chord: your ring holds far more, and a Choir cantor flies with you as medic.
//   Silence it: the Empire pays a fortune and clears your name; the Choir never forgives you.
//   Take the song: it folds space for you from then on, your jump drive reaches 20 ly further.

import { SQ, saveSequel } from './state';
import { SOL_BODIES, BODIES, BODY, type BodyDef } from './planets';
import { SPACE, SCAN } from './space';
import { STATIONS, DOCK } from './stations';
import { fmt } from './bounty';

const pearls = () => SQ.cargo.filter((l) => l.good === 'pearls').reduce((a, l) => a + l.n, 0);
function takePearls(n: number): void {
  for (const l of SQ.cargo) { if (l.good !== 'pearls' || n <= 0) continue; const k = Math.min(l.n, n); l.n -= k; n -= k; }
  SQ.cargo = SQ.cargo.filter((l) => l.n > 0);
}

// ---------------------------------------------------------------- the Cathedral over Titan
STATIONS.sol.push({ id: 'cathedral', name: 'The Cathedral of the Choir', parent: 'titan', alt: 650, hours: 10, kind: 'cathedral', col: '#c878ff', blurb: 'A hollow crystal the size of a city, singing to itself in Titan\'s orbit.' });
DOCK.cathedral = (g) => {
  const f = SQ.flags;
  if (!f.choir) return g.ui.story('The Cathedral', 'The doors are shut. The whole station hums one low note, over and over, like it is waiting for someone who knows the next one.\n\n(The Choir on Luna might teach you.)');
  if (f.signal !== 1) {
    return g.ui.choice('The Cathedral · the signal', [
      { label: 'Let it in', small: 'The Choir will know you as one of their own', fn: () => { f.signal = 1; saveSequel(); if (g.player.willMax) { g.player.willMax += 20; g.player.will = g.player.willMax; } g.ui.story('The Signal', 'It isn\'t a voice. It\'s a key change. For a moment every star in the sky is a note, and you can hear the whole chord.\n\nA cantor in white meets you inside. "You heard it. Good. The song comes from further out than any of us has flown. The deep ones under Europa\'s ice remember the way; they keep it in their pearls.\n\nBring us five Song-Pearls, and we will sing you there."'); } },
      { label: 'Shut the scanner off', fn: () => { f.signal = -1; saveSequel(); g.ui.toast('Silence. The hum stays in your teeth for an hour.'); } },
    ]);
  }
  if (!f.source) {
    const n = pearls();
    return g.ui.choice('The Cathedral · the cantors', [
      { label: `Give them five Song-Pearls (${n} aboard)`, small: n >= 5 ? 'They will sing you the way to the Source' : 'Europa\'s deep ones trade them for music', fn: () => {
        if (n < 5) return g.ui.toast(`Five pearls. You have ${n}. Play Holo-Vinyl to the deep ones under Europa.`, 'warn');
        takePearls(5); f.source = 1; addSource(); saveSequel();
        g.audio.sfx('promote');
        g.ui.story('The Way', 'The cantors crush the pearls in their hands and breathe in the dust, and they sing. The chord is so low you feel it in your ship\'s hull from inside the Cathedral.\n\nWhen it stops, there is a new light on your chart: forty-five AU out, past Neptune, where nothing should be.\n\n"The Source," the cantor says. "Go, and listen, and decide. We could never decide."\n\n(It\'s on "Where to?" now.)');
      } },
      { label: 'Just listen', fn: () => { if (g.player.will != null && g.player.willMax) g.player.will = g.player.willMax; g.ui.toast('The hymn fills you up. Your ring charges full.', 'good'); } },
    ]);
  }
  if (!f.ending) return g.ui.story('The Cathedral', '"The Source is waiting," the cantors sing, all together. "Past Neptune. Go."');
  g.ui.story('The Cathedral', f.ending === 1 ? 'The Cathedral sings your name now, among the others.' : f.ending === 2 ? 'The doors stay shut. From inside, a single low note, full of grief.' : '"You took it for yourself," says the cantor. "Everyone does, in the end. Fly well."');
};

// ---------------------------------------------------------------- the Source
const SOURCE: BodyDef = { id: 'source', name: 'The Source', parent: 'sun', au: 45, days: 200000, radius: 140, gs: 10, color: '#c878ff', blurb: 'A body that isn\'t on any chart. It is singing.' };
export function addSource(): void {
  if (!SOL_BODIES.some((b) => b.id === 'source')) SOL_BODIES.push(SOURCE);
  if (SQ.system === 'sol' && !BODIES.some((b) => b.id === 'source')) { BODIES.push(SOURCE); BODY.source = SOURCE; }
  if (SPACE.active) SPACE.B = [];
}
if (SQ.flags.source) addSource();

SCAN.source = (g) => {
  const f = SQ.flags, pl = g.player;
  if (f.ending) return g.ui.story('The Source', f.ending === 1 ? 'It sings, and you sing back.' : f.ending === 2 ? 'Quiet, and cold, and dark. You did that.' : 'It sings a little quieter now. Some of it is yours.');
  g.ui.story('The Source', 'Up close it isn\'t a planet. It\'s a chord, held for four billion years, wrapped around a stone the size of a city. Every Choir voice, every Europan pearl, every hum in your ring: it all starts here.\n\nThe Empire would pay anything to have it switched off. The Choir would give anything to be part of it. And you could just... take it.', () => {
    g.ui.choice('The Source', [
      { label: 'Join the chord', small: 'Your ring holds far more; a cantor flies with you', fn: () => {
        f.ending = 1; saveSequel();
        if (pl.willMax) { pl.willMax += 100; pl.will = pl.willMax; }
        SQ.crew = SQ.crew || []; SQ.crew.push({ name: 'Cantor Aurel', species: 'Choir', role: 'medic', wage: 0, seed: 7 });
        g.audio.sfx('promote');
        g.ui.story('The Chord', 'You open your mouth and a note comes out that you have never made before and will never stop making.\n\nOn Luna, in Shaft Nine, the Choir stop mid-hymn and turn, all at once, toward the sky.\n\nA cantor is waiting at your airlock when you look back. "I go where the song goes," she says. "Now that\'s you."\n\n(THE END of the Choir\'s story. The ring holds far more; a cantor is your medic.)');
      } },
      { label: 'Silence it', small: `The Empire pays ${fmt(50000)} and clears your name`, fn: () => {
        f.ending = 2; saveSequel();
        pl.cash += 50000; SQ.bounty = 0; SQ.heat.empire = 0;
        g.audio.sfx('boom');
        g.ui.story('Silence', 'You fire into the chord until it breaks. It doesn\'t scream. It just stops, and for the first time in four billion years there is nothing to hear out here.\n\nAn Imperial cutter is waiting when you turn round. A senator\'s aide hands you a cheque and a pardon, and doesn\'t meet your eye.\n\nOn Luna, the Choir stop humming, and never start again.\n\n(THE END of the Choir\'s story. +$50,000; your bounty and heat are gone.)');
      } },
      { label: 'Take the song', small: 'It folds space for you: jumps reach 20 ly further', fn: () => {
        f.ending = 3; f.songDrive = 1; saveSequel();
        g.audio.sfx('promote');
        g.ui.story('The Song', 'You reach into the chord and pull out one note, the way you\'d take a coin from a fountain. It fits in your jump drive like it was made for it.\n\nSpace folds easier now. Further. The stars on the chart lean toward you.\n\n(THE END of the Choir\'s story. Your jumps reach 20 light years further.)');
      } },
    ]);
  });
};

(window as any).BS2 = Object.assign((window as any).BS2 || {}, { addSource });
