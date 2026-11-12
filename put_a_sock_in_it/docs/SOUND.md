# Sound

Nothing is recorded. Every sound is made by code and baked once into `assets/audio/*.wav`.

## What was kept

The voices were kept as they were, because you liked them:

- the dialogue syllables `v_socko*`, `v_kurt*` and `v_marta*`
- Marta's `marta_scream`, `marta_rattle` and `marta_breath`
- Kurt's `gasp`, `breath` and `pant`
- `whisper`, `click` and `sniff`

These generators are still in `scripts/core/sfx.gd`, at 22.05 kHz.

## Everything else

Everything else comes from `scripts/core/sound_lib.gd` (SoundLib) at 32 kHz. It is built from four physical ideas instead of shaped noise:

| Idea | What it is | Used for |
|---|---|---|
| **modes** | A struck thing rings at its own frequencies, each dying away at its own rate. Wood has few, low, quick ones. Metal has many inharmonic, long ones. Glass is high and bright. | knock, door slam, latch, switch, pipe, tin, glass, the pistol's slide, footsteps on wood and tile |
| **friction** | Stick-slip: a train of tiny releases whose rate wanders, played through the body's resonances. | hinge creak, floorboards, a dragged chair, drawer runners, the building's groan, the magazine sliding in |
| **grains** | Many tiny events scattered in time. | grit under a shoe, glass shards settling, paper, plaster after a bullet |
| **beds** | Pink and brown noise, mains hum and slow throbs. Loops cross-fade into themselves with an equal-power seam, so there's no gap or click. | room tone (`drone`), wind with a door-gap whistle, the fridge (`hum`), the tube light (`buzz`), TV static, the busy tone, flies, the maze's breathing (`flesh_drone`), goo |

## Footsteps

Footsteps come in six surfaces with four variants each:

- wood
- lino, which sometimes squeaks
- tile
- concrete, with grit
- soft
- flesh, which sticks and then comes unstuck

Each step is a heel strike followed by the rest of the foot. Floorboard creaks have three variants.

## The mix (`Sfx._mix`)

- **Ducking:** while someone is talking, the world and the beds drop 6 dB. They duck fast and recover slowly.
- **Muffling near Marta:** inside 10 m of Marta, a low-pass on the world and the beds closes from fully open down to 1.5 kHz. The closer she is, the thicker everything sounds. Voices are not affected.
- **Busses:** the beds play on their own `Amb` bus, which has no reverb. World sounds keep the room reverb and are muffled through walls (`_occlude`).

## Changing a sound

Edit the generator, then rebake with:

```
godot --headless --path . -s tools/bake_audio.gd [-- only=<prefix>]
```

The voices are skipped, so they stay exactly as they are. Their old generators share one random stream, so rebaking them would change them. Add `-- voices` to force a rebake.

Generators are deterministic: each one seeds its own random number generator. One-shots end with a 20 ms fade and peak at 97% of full scale.
