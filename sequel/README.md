# RHAPSODY XX8X

The sequel to *Rhapsody: The Brass Coast*, ten years on: a crime sim and space sim across our
real solar system, and now the stars next door. It runs on game 1's engine (every system:
crowds, traffic, combat, law, families, jobs, heists, relationships, the lantern rings) with the
sequel layered on top. Mobile first.

See [DESIGN.md](DESIGN.md) for the full plan.

## What's in it

- **Worlds you can land on:** Earth (the Brass Coast itself, ten years older), Mars (the Solari
  families; you start here), Venus (the Imperial capital and its court), Luna (black market,
  the Choir) and Ceres (ice mines, nobody's law). Each is a full game 1 world with its own
  save, names, families, police, terrain, peoples and wildlife.
- **Real flight:** the real solar system at true distances and periods. Newtonian flight in
  every body's gravity (flight assist on or off), a cruise drive that scales with altitude,
  a flight computer for courses, a trajectory line and a camera that zooms out to the orbits.
- **Piracy:** disable freighters and board them as game 1 interiors; fight the crew, take the
  crates, sell them on a black market. Imperial patrols come when your heat is up.
- **Ship building:** a module grid (engines, reactors, cargo, smuggler's hold, guns,
  deflectors, boarding tube, tractor beam, jump drive and more) that sets how the ship flies.
- **Aliens:** Greys, the Choir, Martians, Saurians and Belters live in the worlds' populations.
  Make first contact with the Europans under Europa's ice.
- **Ecosystems:** every world has its own wildlife and a living food chain.
- **Stations and mining:** a casino in orbit over Mars, an assay station at Ceres, and an
  asteroid belt to mine.
- **The Imperial bounty:** hunters on the ground and in space (they board you), and the court
  on Venus.
- **The jump drive:** the six nearest real stars, each with generated worlds, peoples and
  wildlife.
- **Game 1 changes that also land here:** Mastermind-style PIN safes, finishable knock-over
  jobs, and the protagonist ten years older.

## Controls

Game 1's controls. On foot: stick to move, **A** for the context action, **B** to attack,
RUN, SNEAK. In space: the stick points and thrusts, attack fires, **RUN** toggles cruise,
**SNEAK** toggles flight assist, **A** lands, docks, boards or scans. The Ship, Cargo and
System tabs are in the menu.

## Build and test

```
npm install
npm run check      # typecheck + build + smoke + frontier
```

- `tools/smoke.mjs` plays the core loop: Mars, orbit, piracy, cruise to Luna, black market,
  Earth, and back to Mars.
- `tools/frontier.mjs` plays the newer systems: aliens, first contact, the orbital casino,
  mining the belt, Ceres wildlife and the food chain, bounty hunters (on the ground and
  boarding you), the court, and a jump to Alpha Centauri and back.

`dist/index.html` is one self-contained file; `dist/rhapsody-xx8x.html` is the body-only
variant used for the artifact.
