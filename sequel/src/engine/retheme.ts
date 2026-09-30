// Game 1's newer systems, in XX8X's words. The Phone Man, the stills, the armored cars, the
// storms and the funerals all run unchanged underneath; this puts the future's vocabulary on
// whatever they say (toasts, stories, menus, the papers), and keeps the storms where they
// belong: acid monsoons blow in off Earth's poisoned Gulf, and nowhere else.

import { EARTH } from './earth';
import { SPACE } from './space';

// word for word, longest first. Case follows the original (Word, word, WORD).
const LEX: [RegExp, string][] = [
  [/\bwhite lightning\b/gi, 'blue lightning'], [/\bcopper still\b/gi, 'synth-still'], [/\bjugs? of moonshine\b/gi, 'cells of synth-shine'],
  [/\bmoonshine\b/gi, 'synth-shine'], [/\bATF agents\b/g, 'Excise Enforcers'], [/\brevenuers\b/gi, 'excise men'],
  [/\bhurricane\b/gi, 'acid monsoon'], [/\bthe power company\b/gi, 'Syndicate Power'], [/\bboard up your windows\b/gi, 'seal your vents'],
  [/\barmored car\b/gi, 'credit hauler'], [/\bbank money\b/gi, 'Syndicate credits'], [/\bthe FBI\b/g, 'the Imperial Inquisition'], [/\bthe chief\b/g, 'the Peacekeeper Prefect'],
  [/\bpayphone\b/gi, 'vid-phone'], [/\bchurch steps\b/gi, 'temple steps'], [/\bthe Archbishop\b/g, 'the High Cantor'], [/\bFuneral mass\b/g, 'Funeral rite'],
  [/\bthe Teamsters\b/g, 'the Haulers\' Guild'], [/\bwhitewalls\b/gi, 'repulsor pads'], [/\btyres\b/gi, 'repulsor pads'],
];
const cased = (orig: string, rep: string) => (orig === orig.toUpperCase() && /[A-Z]/.test(orig) ? rep.toUpperCase() : /^[A-Z]/.test(orig) ? rep[0].toUpperCase() + rep.slice(1) : rep);
export function say(s: unknown): any {
  if (typeof s !== 'string' || !s) return s;
  let out = s;
  for (const [re, rep] of LEX) out = out.replace(re, (m) => cased(m, rep));
  return out;
}

const U = R.UI.prototype as any;
const toast = U.toast, story = U.story, choice = U.choice, banner = U.banner, io = U.interiorOptions;
U.toast = function (msg: string, kind?: string) { return toast.call(this, say(msg), kind); };
U.story = function (title: string, text: string, cb?: () => void) { return story.call(this, say(title), say(text), cb); };
U.banner = function (title: string, sub?: string) { return banner.call(this, say(title), say(sub)); };
const relabel = (opts: any[]) => (opts || []).map((o) => (o && typeof o === 'object' ? Object.assign(o, { label: say(o.label), small: say(o.small) }) : o));
U.choice = function (title: string, opts: any[]) { return choice.call(this, say(title), relabel(opts)); };
// game 1's modules wrap the shop menus when the game starts, after this file loads: keep ours
// outermost by re-wrapping whenever something has wrapped over it
const lexIO = (inner: any) => { const f = function (this: any, b: any) { return relabel(inner.call(this, b)); }; (f as any).lex = true; return f; };
U.interiorOptions = lexIO(io);
const GP = R.Game.prototype, tick = GP.tick;
GP.tick = function (this: Game, dt: number) { if (!U.interiorOptions.lex) U.interiorOptions = lexIO(U.interiorOptions); return tick.call(this, dt); };
const PopP = (R as any).Population.prototype, news = PopP.addNews;
PopP.addNews = function (city: string, text: string) { return news.call(this, city, say(text)); };

// the loot, named before the still's module names it
const D = R.data as any;
D.loot = D.loot || {};
D.loot.moonshine = D.loot.moonshine || { name: 'Cell of Synth-Shine', v: 0 };

// storms: Earth only (Mars has its dust, and the rest have no weather worth the name)
const HU = (R as any).hurricane;
if (HU) {
  const up = HU.update;
  HU.update = function (dt: number) {
    if (!EARTH.active || SPACE.active) { (R as any).blackout = false; return; }
    return up.call(this, dt);
  };
}

(window as any).BS2 = Object.assign((window as any).BS2 || {}, { say });
