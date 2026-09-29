# Rhapsody II: Brass Stars (prototype v0.1)

The sequel to *Rhapsody: The Brass Coast*: a seventies space opera across a solar system,
drawn in the Gen 4 DS style (HeartGold/SoulSilver/Platinum) and played like a DS on a phone.
The world is on the top screen and the Ship Watch on the bottom touch screen.

See [DESIGN.md](DESIGN.md) for the full plan, including carrying game 1's systems over.

## What's in v0.1

- **Two planets on foot:** Veridia (green casino trade world) and Hollow Moon (dusty mining
  moon). Each has a generated spaceport district with Gen 4 buildings and props, wandering
  NPCs who talk, and day/night with lamp glow and lit windows.
- **Buildings you can use:** Pad Control (save), the markets (Veridia's legit exchange,
  Hollow Moon's black market), shipyards, cantinas (a drink and a rumour), the outfitter,
  the Choir Dome.
- **Space:** fly between orbiting planets past the sun and an asteroid belt; jump by
  hyperlane from the Map app; land at Veridia and Hollow Moon. Castra Prime denies clearance
  for now.
- **Piracy:** freighters run the lanes. Shoot out their engines, board them through your
  tube, fight the crew room to room, loot the crates. Imperial patrols come for you once your
  heat is up.
- **Ship building:** the Ship app is a module grid (engines, reactors, cargo, smuggler's
  hold, guns, deflectors, quarters, med bay, boarding tube, shag lounge, lantern battery,
  armour). The layout drives thrust, power, cargo, guns, shields and hull, plus the sprite
  you fly and the interior boarders walk. You can also buy bigger hulls.
- **Trade and smuggling:** six goods with different prices per planet. Stolen cargo only
  sells on the black market, and Veridia's customs take it from your open bay if you land hot.

## Controls

Stick or WASD/arrows to move. **A** (J/Z/Space) talks, uses, launches, lands, boards and
takes. **B** (K/X) runs on foot and fires in space and aboard ships. Tap the apps on the
bottom screen.

## Build and test

```
npm install
npm run check      # typecheck + build + smoke (plays the whole v0.1 loop headless)
```

`dist/index.html` is a single self-contained file.
