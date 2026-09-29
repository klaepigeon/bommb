// On foot on a planet: walk the spaceport district, talk to people, use the buildings, and
// walk back to your ship to launch. Drawn in the Gen 4 overworld style with a 16px grid,
// y-sorted sprites and a time-of-day tint with lit windows and lamp glow at night.

import type { Game, Scene } from '../game';
import { generate, PLANETS, type District, type Npc, type PlanetId, type Building } from './planets';
import { tileCanvas, drawEdges, variant, ANIMATED, TS, T } from '../gfx/tiles';
import { buildingArt, propArt } from '../gfx/buildings';
import { personSprite, type Facing } from '../gfx/people';
import { shipSprites } from '../ship/ship';
import { clamp, dist, strHash } from '../core/math';
import { sfx } from '../audio';
import { spaceScene } from '../space/spaceScene';

const districts = new Map<PlanetId, District>();
export function district(id: PlanetId): District {
  let d = districts.get(id);
  if (!d) { d = generate(id, strHash('brass-stars:' + id)); districts.set(id, d); }
  return d;
}

export function planetScene(game: Game, id: PlanetId, arriving: boolean): Scene {
  const d = district(id);
  const def = PLANETS[id];
  // start beside the ship on arrival, or at the pad edge
  const pl = { x: d.ship.x - 8, y: d.ship.y + 44, facing: 0 as Facing, walk: 0, moving: false };
  const cam = { x: 0, y: 0 };
  let ground: HTMLCanvasElement | null = null;
  let frame = 0, ft = 0;

  // static ground in one canvas; animated tiles are redrawn each frame on top
  const bake = () => {
    const cv = document.createElement('canvas'); cv.width = d.W * TS; cv.height = d.H * TS;
    const g = cv.getContext('2d') as CanvasRenderingContext2D;
    for (let y = 0; y < d.H; y++) for (let x = 0; x < d.W; x++) {
      const t = d.t(x, y);
      g.drawImage(tileCanvas(t, variant(x, y), 0), x * TS, y * TS);
      drawEdges(g, t, (dx, dy) => d.t(x + dx, y + dy), x * TS, y * TS, 0);
    }
    return cv;
  };

  const nearNpc = (): Npc | null => {
    let best: Npc | null = null, bd = 22;
    for (const n of d.npcs) { const k = dist(pl.x, pl.y, n.x, n.y); if (k < bd) { bd = k; best = n; } }
    return best;
  };
  const nearDoor = (): Building | null => {
    const tx = Math.floor(pl.x / TS), ty = Math.floor(pl.y / TS);
    return d.buildings.find((b) => Math.abs(b.door.x - tx) <= 1 && (b.door.y === ty || b.door.y === ty + 1 || b.door.y === ty - 1) && pl.y > b.door.y * TS - 10) || null;
  };
  const nearShip = () => dist(pl.x, pl.y, d.ship.x, d.ship.y + 10) < 48;

  // collision: a small box at the feet
  const blocked = (x: number, y: number) => {
    for (const [ox, oy] of [[-5, -3], [5, -3], [-5, 3], [5, 3]]) if (d.solid(Math.floor((x + ox) / TS), Math.floor((y + oy) / TS))) return true;
    // the parked ship
    if (Math.abs(x - d.ship.x) < 34 && Math.abs(y - d.ship.y) < 20) return true;
    return false;
  };

  const talk = (n: Npc) => {
    // turn to face the player
    const dx = pl.x - n.x, dy = pl.y - n.y;
    n.facing = Math.abs(dx) > Math.abs(dy) ? (dx < 0 ? 1 : 2) : dy < 0 ? 3 : 0;
    n.wait = 3;
    sfx('blip');
    game.ui.say(n.name, n.line);
  };

  const useBuilding = (b: Building) => {
    sfx('door');
    const ui = game.ui;
    switch (b.kind) {
      case 'terminal':
        ui.say(id === 'veridia' ? 'Dockmaster Venn' : 'Port Clerk', id === 'veridia'
          ? `Pad three, the Brass Buzzard. Docking's paid through tonight. You want work? Freighters run Castra to Hollow all day. What they carry isn't my business. What you do to them isn't either.`
          : `Dust Port. We don't log names out here. Black market's by the domes. If the Choir offers you tea, say no.`,
        [{ label: 'Save game', fn: () => { game.save(); ui.toast('Saved.', 'good'); } }, { label: 'Bye', fn: () => {} }]);
        game.complete('talk');
        break;
      case 'market': ui.openApp('market'); ui.say(b.name, id === 'hollow' ? 'We buy anything. Stolen goods at full price, no questions.' : 'Legitimate goods only. Stolen cargo needs a fence.'); break;
      case 'shipyard': ui.openApp('ship'); ui.say(b.name, 'Modules on the rack, hulls on order. Tap a slot on the Ship app to fit or strip a module.'); break;
      case 'casino': ui.say('Bouncer', 'Tables open in the next build, pal. Mr. Solari likes his house to win, and right now it isn\'t finished.'); break;
      case 'cantina':
        ui.say('Bartender', 'What\'ll it be?', [
          { label: 'Synth-rum (20)', fn: () => { if (game.credits < 20) return ui.toast('Not enough credits.', 'bad'); game.credits -= 20; game.hp = Math.min(100, game.hp + 25); sfx('coin'); ui.say('Bartender', rumour()); } },
          { label: 'Nothing', fn: () => {} },
        ]);
        break;
      case 'shop':
        ui.say('Outfitter', 'New flight jacket? Fifty credits, any colour you like, as long as it\'s one of these.', [
          { label: 'Change jacket (50)', fn: () => { if (game.credits < 50) return ui.toast('Not enough credits.', 'bad'); game.credits -= 50; const cols = ['#e8742a', '#d8c040', '#4a7ad0', '#c83a48', '#58b458', '#e878a8', '#e8e4dc']; game.player.top = cols[(cols.indexOf(game.player.top) + 1) % cols.length]; sfx('coin'); ui.refresh(); } },
          { label: 'Just looking', fn: () => {} },
        ]);
        break;
      case 'dome':
        ui.say(b.name, b.name === 'Choir Dome' ? 'Behind the glass, a hundred people in violet robes hum one long note. It doesn\'t stop for breath. Somebody at the door smiles at you too long.' : 'Rows of hydroponic tomatoes under violet lamps. A sign: TAKE ONE, THE CHOIR PROVIDES.');
        break;
      default: ui.say(b.name, 'Locked. Somebody\'s home: you can hear a hi-fi playing disco through the door.');
    }
  };

  const rumour = () => [
    '"Imperial freighters carry blasters under the ore. If you knew where to look."',
    '"The Solari don\'t like pirates. Unless the pirate\'s paying them."',
    '"A guy came through last week with a ring that glowed yellow. Nobody drank for free after that."',
    '"Hollow Moon\'s black market pays full price for hot cargo."',
  ][Math.floor(Math.random() * 4)];

  const updateNpcs = (dt: number) => {
    for (const n of d.npcs) {
      if (n.wait > 0) { n.wait -= dt; n.walk = 0; continue; }
      const dx = n.tx - n.x, dy = n.ty - n.y, k = Math.hypot(dx, dy);
      if (k < 2) {
        n.wait = 1 + Math.random() * 4;
        const tx = clamp(Math.floor(n.x / TS) + Math.floor(Math.random() * 9) - 4, 1, d.W - 2), ty = clamp(Math.floor(n.y / TS) + Math.floor(Math.random() * 9) - 4, 1, d.H - 2);
        if (!d.solid(tx, ty) && d.t(tx, ty) !== T.PAD) { n.tx = tx * TS + 8; n.ty = ty * TS + 8; }
        continue;
      }
      const sp = 26 * dt, mx = (dx / k) * sp, my = (dy / k) * sp;
      if (!blocked(n.x + mx, n.y) && dist(n.x + mx, n.y, pl.x, pl.y) > 12) n.x += mx; else n.tx = n.x;
      if (!blocked(n.x, n.y + my) && dist(n.x, n.y + my, pl.x, pl.y) > 12) n.y += my; else n.ty = n.y;
      n.facing = Math.abs(dx) > Math.abs(dy) ? (dx < 0 ? 1 : 2) : dy < 0 ? 3 : 0;
      n.walk += dt;
    }
  };

  const scene: Scene = {
    name: 'planet:' + id,
    enter() {
      game.location = { kind: 'planet', planet: id };
      ground = bake();
      if (arriving) {
        game.radio(`Landed on ${def.name}. ${def.blurb}`);
        // customs: the Solari scan open cargo if you're hot with the Empire
        if (id === 'veridia' && game.heat.empire > 10) {
          const hot = game.cargo.filter((l) => l.stolen && !l.hidden);
          if (hot.length) {
            const n = hot.reduce((s, l) => s + l.n, 0);
            game.cargo = game.cargo.filter((l) => !(l.stolen && !l.hidden));
            const fine = Math.min(game.credits, 150);
            game.credits -= fine;
            setTimeout(() => game.ui.say('Solari Customs', `Scanner says ${n} crates of Imperial cargo in your open bay. We'll take those, and ${fine} credits for the paperwork. Next time, a smuggler's hold. We never saw this.`), 400);
          }
        }
        game.save();
      }
    },
    update(dt, input) {
      ft += dt; if (ft > 0.35) { ft = 0; frame = (frame + 1) % 4; }
      updateNpcs(dt);
      if (game.ui.busy()) { pl.moving = false; return; }
      const mag = Math.hypot(input.x, input.y);
      pl.moving = mag > 0.2;
      if (pl.moving) {
        const run = input.down('b');
        const sp = (run ? 110 : 64) * dt;
        const mx = (input.x / Math.max(1, mag)) * sp, my = (input.y / Math.max(1, mag)) * sp;
        if (!blocked(pl.x + mx, pl.y)) pl.x += mx;
        if (!blocked(pl.x, pl.y + my)) pl.y += my;
        pl.facing = Math.abs(input.x) > Math.abs(input.y) ? (input.x < 0 ? 1 : 2) : input.y < 0 ? 3 : 0;
        pl.walk += dt * (run ? 1.7 : 1);
      } else pl.walk = 0;
      if (input.pressed('a')) {
        const n = nearNpc(), b = nearDoor();
        if (nearShip()) {
          game.ui.say(game.ship.name, 'Fire her up?', [
            { label: 'Launch', fn: () => { sfx('launch'); game.complete('launch'); game.save(); game.go(() => spaceScene(game, id)); } },
            { label: 'Not yet', fn: () => {} },
          ]);
        } else if (n) talk(n);
        else if (b) useBuilding(b);
      }
    },
    test: {
      // stand in front of the first building of a kind (for screenshots and tests)
      visit: () => { const b = d.buildings.find((x) => x.kind !== 'terminal') || d.buildings[0]; pl.x = b.door.x * TS + 8; pl.y = (b.door.y + 2) * TS + 8; pl.facing = 3; return b.name; },
      terminal: () => { const b = d.buildings.find((x) => x.kind === 'terminal') as Building; pl.x = b.door.x * TS + 8; pl.y = (b.door.y + 1) * TS + 4; pl.facing = 3; return b.name; },
    },
    action() {
      if (nearShip()) return 'LAUNCH';
      if (nearNpc()) return 'TALK';
      if (nearDoor()) return 'ENTER';
      return '';
    },
    draw(g, W, H) {
      cam.x = clamp(pl.x - W / 2, 0, d.W * TS - W);
      cam.y = clamp(pl.y - H / 2, 0, d.H * TS - H);
      const cx = Math.round(cam.x), cy = Math.round(cam.y);
      g.save();
      g.translate(-cx, -cy);
      if (ground) g.drawImage(ground, 0, 0);
      // animated tiles in view
      const x0 = Math.floor(cx / TS), y0 = Math.floor(cy / TS), x1 = x0 + Math.ceil(W / TS) + 1, y1 = y0 + Math.ceil(H / TS) + 1;
      for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
        const t = d.t(x, y);
        if (!ANIMATED.has(t)) continue;
        g.drawImage(tileCanvas(t, variant(x, y), frame), x * TS, y * TS);
        drawEdges(g, t, (dx, dy) => d.t(x + dx, y + dy), x * TS, y * TS, frame);
      }
      const night = game.darkness() > 0.5;
      // everything that stands up, sorted by its foot
      const items: { y: number; draw: () => void }[] = [];
      const inView = (x: number, y: number, m: number) => x > cx - m && x < cx + W + m && y > cy - m && y < cy + H + m * 2;
      for (const b of d.buildings) {
        const bx = b.x * TS, by = b.y * TS;
        if (!inView(bx + (b.w * TS) / 2, by, b.w * TS)) continue;
        items.push({ y: by + b.h * TS, draw: () => {
          const a = buildingArt(b.kind, b.w, b.h, b.seed, night);
          g.fillStyle = 'rgba(20,24,48,0.22)'; g.fillRect(bx + 4, by + b.h * TS - 2, b.w * TS, 5);
          g.drawImage(a.cv, bx, by - 16);
        } });
      }
      for (const p of d.props) {
        const px = p.x * TS, py = p.y * TS;
        if (!inView(px, py, 48)) continue;
        items.push({ y: py + 14, draw: () => { const s = propArt(p.kind, p.v, night); g.fillStyle = 'rgba(20,24,48,0.2)'; g.beginPath(); g.ellipse(px + 8, py + 14, 7, 3, 0, 0, 7); g.fill(); g.drawImage(s.cv, px + s.ox, py + s.oy); } });
      }
      // the ship on its pad, drawn at twice the space scale
      items.push({ y: d.ship.y + 20, draw: () => {
        const spr = shipSprites(game.ship)[0];
        g.fillStyle = 'rgba(20,24,48,0.25)'; g.beginPath(); g.ellipse(d.ship.x + 6, d.ship.y + 18, spr.width, 8, 0, 0, 7); g.fill();
        g.drawImage(spr, Math.round(d.ship.x - spr.width), Math.round(d.ship.y - spr.height), spr.width * 2, spr.height * 2);
      } });
      const person = (x: number, y: number, look: Npc['look'], facing: Facing, walk: number) => {
        const fr = walk > 0 ? (Math.floor(walk * 7) % 4 === 1 ? 1 : Math.floor(walk * 7) % 4 === 3 ? 2 : 0) : 0;
        g.fillStyle = 'rgba(20,24,48,0.25)'; g.beginPath(); g.ellipse(x, y + 5, 6, 2.5, 0, 0, 7); g.fill();
        g.drawImage(personSprite(look, facing, fr), Math.round(x - 16), Math.round(y - 25));
      };
      for (const n of d.npcs) if (inView(n.x, n.y, 32)) items.push({ y: n.y, draw: () => person(n.x, n.y, n.look, n.facing, n.walk) });
      items.push({ y: pl.y, draw: () => person(pl.x, pl.y, game.player, pl.facing, pl.moving ? pl.walk : 0) });
      items.sort((a, b) => a.y - b.y);
      for (const it of items) it.draw();
      g.restore();

      // time of day: a Gen 4 style palette tint, then light where the lamps and windows are
      const dk = game.darkness();
      const h = game.hour();
      if (dk > 0 || (h >= 17 && h < 19)) {
        g.save();
        g.globalCompositeOperation = 'multiply';
        g.fillStyle = dk > 0.5 ? `rgba(70,80,150,${0.35 + dk * 0.35})` : h >= 17 ? 'rgba(255,190,150,0.35)' : `rgba(150,140,200,${dk * 0.6})`;
        g.fillRect(0, 0, W, H);
        g.restore();
        if (dk > 0.4) {
          g.save();
          g.globalCompositeOperation = 'lighter';
          for (const p of d.props) {
            if (p.kind !== 'lamp' && p.kind !== 'crystal' && p.kind !== 'antenna') continue;
            const x = p.x * TS + 8 - cx, y = p.y * TS - (p.kind === 'lamp' ? 16 : 4) - cy;
            if (x < -60 || y < -60 || x > W + 60 || y > H + 60) continue;
            const col = p.kind === 'crystal' ? '160,90,220' : p.kind === 'antenna' ? '220,60,60' : '255,210,130';
            const r = g.createRadialGradient(x, y, 2, x, y, p.kind === 'lamp' ? 44 : 22);
            r.addColorStop(0, `rgba(${col},${0.45 * dk})`); r.addColorStop(1, `rgba(${col},0)`);
            g.fillStyle = r; g.fillRect(x - 50, y - 50, 100, 100);
          }
          g.restore();
        }
      }
    },
  };
  return scene;
}
