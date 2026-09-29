// Boot: the title screen, then a fixed-step loop driving the current scene on the top screen
// and keeping the Ship Watch (bottom screen) fresh.

import { Game, type Scene } from './game';
import { Input } from './core/input';
import { DsUi } from './ui/ui';
import { planetScene } from './world/planetScene';
import { spaceScene, spaceState } from './space/spaceScene';
import { boardScene } from './space/boardScene';
import { hash2 } from './core/math';
import { readSave, clearSave } from './core/save';
import { sfx, unlockAudio } from './audio';
import { shipSprites } from './ship/ship';

const SW = 256, SH = 192; // one DS screen

const view = document.getElementById('view') as HTMLCanvasElement;
view.width = SW; view.height = SH;
const g = view.getContext('2d') as CanvasRenderingContext2D;
g.imageSmoothingEnabled = false;

const game = new Game();
const input = new Input();
const ui = new DsUi(game);
game.ui = ui;
input.bindTouch(document.getElementById('stickzone') as HTMLElement, document.getElementById('knob') as HTMLElement, {
  a: document.getElementById('btnA'), b: document.getElementById('btnB'), start: document.getElementById('btnStart'),
});
addEventListener('pointerdown', unlockAudio, { once: false });
addEventListener('keydown', unlockAudio);

// ---------------------------------------------------------------- title
function titleScene(): Scene {
  let t = 0, chosen = false;
  const title = document.getElementById('title') as HTMLElement;
  title.hidden = false;
  const hasSave = !!readSave();
  (document.getElementById('tContinue') as HTMLButtonElement).hidden = !hasSave;
  const start = (cont: boolean) => {
    if (chosen) return;
    chosen = true;
    unlockAudio(); sfx('launch');
    title.hidden = true;
    if (cont && game.load()) {
      game.go(() => planetScene(game, game.location.planet, false));
      game.radio(`Welcome back. ${game.clockLabel()}.`);
    } else {
      clearSave();
      game.go(() => planetScene(game, 'veridia', false));
      setTimeout(() => {
        game.ui.say('', 'VERIDIA. Year XX7X. The Brass Coast is a long way behind you, and so is whoever you were there.');
        game.ui.say('', 'You\'ve got a scrappy skiff called the Brass Buzzard, 800 credits and a Sinestro Corps uniform in a duffel bag you don\'t talk about.');
        game.ui.say('', 'Check in at Pad Control, north of your ship. The Ship Watch (bottom screen) has your goals, map and ship.');
        game.radio('Arrived on Veridia. Check in at Pad Control.');
      }, 700);
    }
  };
  (document.getElementById('tNew') as HTMLButtonElement).onclick = () => start(false);
  (document.getElementById('tContinue') as HTMLButtonElement).onclick = () => start(true);
  return {
    name: 'title',
    update(dt, inp) { t += dt; if (inp.pressed('a') || inp.pressed('start')) start(hasSave); },
    action: () => 'START',
    draw(c, W, H) {
      c.fillStyle = '#070718'; c.fillRect(0, 0, W, H);
      for (let k = 0; k < 140; k++) {
        const x = (hash2(k, 1) * W + t * (4 + hash2(k, 2) * 18)) % W, y = hash2(k, 3) * H;
        c.fillStyle = hash2(k, 4) < 0.15 ? '#ffe8a0' : '#d8d8f0'; c.fillRect(Math.floor(x), Math.floor(y), hash2(k, 5) < 0.2 ? 2 : 1, 1);
      }
      // a ship drifting across
      const spr = shipSprites(game.ship)[0];
      c.drawImage(spr, Math.floor(((t * 22) % (W + 80)) - 60), 128 + Math.sin(t) * 3);
    },
  };
}

// ---------------------------------------------------------------- loop
game.scene = titleScene();
let last = performance.now(), acc = 0, refreshT = 0;
const STEP = 1 / 60;
const labelA = document.querySelector('#btnA span') as HTMLElement;

function frame(now: number) {
  acc = Math.min(acc + (now - last) / 1000, STEP * 6);
  last = now;
  input.poll();
  let steps = 0;
  while (acc >= STEP) {
    // a press that the dialogue box used doesn't reach the scene
    const talking = ui.busy();
    ui.tick(STEP, input);
    if (talking) input.endFrame();
    game.tick(STEP, input);
    input.endFrame();
    acc -= STEP; steps++;
  }
  // draw
  g.setTransform(1, 0, 0, 1, 0, 0);
  game.scene?.draw(g, SW, SH);
  if (game.fade > 0) { g.fillStyle = `rgba(0,0,0,${game.fade < 1 ? game.fade : 2 - game.fade})`; g.fillRect(0, 0, SW, SH); }
  const act = ui.busy() ? 'NEXT' : game.scene?.action() || '';
  if (labelA.textContent !== act) labelA.textContent = act;
  refreshT -= steps * STEP;
  if (refreshT <= 0) { refreshT = game.location.kind === 'space' && ui.app === 'map' ? 0.5 : 1; if (game.scene?.name !== 'title') ui.refresh(); }
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);

// for tests and debugging
(window as unknown as { BS: unknown }).BS = { game, input, ui, planetScene, spaceScene, spaceState, boardScene };
