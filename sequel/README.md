# RHAPSODY XX8X

The sequel to *Rhapsody: The Brass Coast*, ten years on: a crime sim and space sim across our
real solar system, and now the stars next door. It runs on game 1's engine (every system:
crowds, traffic, combat, law, families, jobs, heists, relationships, the lantern rings) with the
sequel layered on top. Mobile first.

See [DESIGN.md](DESIGN.md) for the full plan.

## What's in it

- **A planet-sized Earth:** 2,592 sectors over the real continents, each a full game 1 map;
  walk from one to the next, or pick a landing zone from orbit. Streets of Fire and The Protomen
  are the look: neon, the El, searchlights, acid rain, robot Peacekeepers. You start here in
  Tom Cody's road duster, working for the Fear Man: game 1's magenta alien, now the one boss of
  Earth, very old and going senile. A blue marker leads you back to your ship.
- **The Fear Man and the rings:** every lantern ring stays locked until you kill the Fear Man
  (frail now, but guarded). His yellow ring and the Sinestro Corps uniform come off the body. With
  a ring, the construct menu can **take off into space with no ship**: masked, in uniform, fist
  blazing, at the starter skiff's speed. Your ship stays parked; call it down from any pad.
- **Worlds you can land on:** Earth, Mars (the Solari families), Venus (the Imperial capital and its court), Luna (black market,
  the Choir) and Ceres (ice mines, nobody's law). Each is a full game 1 world with its own
  save, names, families, police, terrain, peoples and wildlife.
- **Flying that works:** push the stick where you want to go, let go to stop; gravity can't
  touch you with flight assist on. Press A in open space for **Where to?**: pick any world,
  moon, station or base and the autopilot cruises there, steers round the Sun and holds you
  over it. Touch the stick to take over.
- **Frontier worlds and colonies:** Mercury, Io, Ganymede, Callisto, Titan and every empty
  planet on other stars are landable claim-camp worlds. Found a colony and build it up.
- **Stations and bases:** Imperial customs over Venus, the rebels' shipyard at Ganymede (the
  only yard that fits a cloak), an Imperial dreadnought, and orbital bases of your own.
- **The Choir's story:** listen to the Choir on Luna, answer the signal at their Cathedral over
  Titan, bring five Europan Song-Pearls, and fly to the Source past Neptune. Three endings.
- **The street:** neon punks and the Bombers (Streets of Fire's leather gang) join the cyborgs,
  robots and mutants on Earth.
- **Ways to make a living:** contracts boards on every pad (cargo and smuggling runs), Imperial
  bounties on pirates, hailing freighters (trade at sea, or make them dump their cargo), a market
  whose prices move with the news, street races against Raven on Earth, and the Pit (on Mars, the
  Red Pit) in any Neon Club.
- **Out there:** distress calls (rescues and traps), derelicts to board, solar storms, and Radio
  Free Luna, a pirate DJ who talks about what you've done.
- **Chrome and paint:** implants at any Chrome Clinic (reflexes, plating, a titan arm, a heart
  pump), and paint jobs and a new name for the ship.
- **Crew:** ask anyone (aliens especially) to fly with you; each role improves the ship.
- **The galaxy chart:** sixty generated stars beyond the real six, 12 light years a jump.
- **Gore and interrogation:** each sci-fi weapon takes bodies apart its own way; robots leak
  oil, aliens bleed their own colours; cut implants out of cyborgs; interrogate captives.
- **Real flight:** the real solar system at true distances and periods. Newtonian flight in
  every body's gravity (flight assist on or off), a cruise drive that scales with altitude,
  a flight computer for courses, a trajectory line and a camera that zooms out to the orbits.
- **Piracy:** disable freighters and board them as game 1 interiors; fight the crew, take the
  crates, sell them on a black market. Imperial patrols come when your heat is up.
- **Ship building:** eleven hulls from a one-seat skiff to a dreadnought, and a module grid
  (engines, reactors, cargo, smuggler's hold, guns, deflectors, boarding tube, tractor beam, jump
  drive, missile racks, drone bays, point defence, cloaking field, sensor array, afterburner,
  cryo pods, neutronium plate, ore refinery) that sets how the ship flies and fights. NPC traders,
  patrols, hunters, rebels and Imperial capital ships are built from the same catalogue.
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
System tabs are in the menu. Menu > Debug opens the XX8X debug tools (money, the clamp, every
hull fitted out, spawn any ship, land anywhere, jump to any star, the Fear Man, ring flight).

## Build and test

```
npm install
npm run check      # typecheck + build + all nine suites
```

- `tools/smoke.mjs` plays the core loop: Earth, the Fear Man's clamp, orbit, piracy, cruise to Luna,
  black market, Mars, and home to the Brass Coast.
- `tools/earth.mjs` plays the planet-sized Earth and the opening: the clamp, a triple-pay job,
  the peoples of the future, crossing sectors, the ocean, calling the ship, landing zones.
- `tools/fear.mjs` plays the newest layer: the duster, the ship marker, the Fear Man's death and
  his ring, ring flight to Mars and calling the ship down, NPC hulls, missiles and drones, and
  the XX8X debug menu.
- `tools/frontier.mjs` plays the newer systems: aliens, first contact, the orbital casino,
  mining the belt, Ceres wildlife and the food chain, bounty hunters (on the ground and
  boarding you), the court, and a jump to Alpha Centauri and back.

`dist/index.html` is one self-contained file; `dist/rhapsody-xx8x.html` is the body-only
variant used for the artifact.
