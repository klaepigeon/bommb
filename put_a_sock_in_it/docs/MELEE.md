# Melee, durability and Kurt's hands

Code: `scripts/player/hands.gd` (the blow, the arm, breaking), `scripts/combat/weapons.gd` (the
numbers), `MartaHunter.melee_hit` (what it does to her). Test: `tools/melee_test.gd`.

## Controls

| Input | Holding something | Pistol drawn, hands empty | Pistol holstered (or none) |
|---|---|---|---|
| **Attack** (LMB / RT / touch HIT) tap | swing it | shoot | jab |
| **Attack** held ≥ 0.35 s, released | heavy swing (overhead) | shoot | haymaker (hook) |
| **Throw** (G / middle mouse / LB / touch THROW) | throw it | | |
| **Holster** (H / D-pad up / touch GUN) | | put the pistol away | draw it |
| **Interact** (E) | drop it | | |

Kurt's left hand is Socko's; everything is done with the right. The arm is the rigged KurtArm
(21 bones): a fist for punches, a grip round a swung thing, a hold under a carried one. It's in
view while it's doing something or holding something, and drops out of sight a second after.

## A blow

**Windup** (draw back; held there while the button is held: hold past 0.35 s and it becomes a
heavy blow) → **strike** (0.08 s, 0.12 s heavy; the hit is resolved at its end) → **recover**
(back to guard, or to holding). A held thing rides in the hand through the swing, frozen, at the
offset it had when the swing began; a long thing is held at its end.

The hit: three rays out from the eye along the look (centre, 14 cm either side), as long as the
weapon's reach; the nearest thing they meet. Her: `melee_hit`. A loose thing: shoved. A wall or
a door: it jars his arm (and the weapon), and anything with `punched()` hears about it (the
skill tree's wall-punching uses this).

**Stamina.** Each blow costs seconds of the same stamina running uses. Tired (less left than the
blow costs), he hits at half damage, 60% shove, and recovers 40% slower.

**Noise.** Every hit is a noise she can hear (`Game.make_noise`), louder for heavy blows.

## Weapon classes

Anything he can pick up is a weapon. It's classified once, by what it's called and then by
weight, and the class gives its numbers. Damage is to her poise (below).

| Class | Things | Dmg | Windup s | Recover s | Reach m | Shove | Stamina s | Durability | Breaks into |
|---|---|---|---|---|---|---|---|---|---|
| fist | (empty hand) | 6 | 0.07 | 0.28 | 0.95 | 0.6 | 0.25 | never | |
| flimsy | books, paper, shoes, socks, the doll, blocks | 3 | 0.10 | 0.30 | 1.05 | 0.3 | 0.20 | 12 | |
| brittle | bottles, jars, glasses, cups, the tureen, the ashtray, the shade | 9 | 0.12 | 0.32 | 1.05 | 0.8 | 0.30 | 1 | shard |
| blunt | tins, paint tins, boots, the stove; anything 0.3–2 kg | 11 | 0.16 | 0.38 | 1.15 | 1.2 | 0.35 | 10 | |
| tool | hammer (wrench, iron) | 18 | 0.18 | 0.42 | 1.15 | 1.4 | 0.40 | 30 | |
| blade | kitchen knife, razor | 15 | 0.10 | 0.28 | 1.05 | 0.4 | 0.25 | 14 | |
| shard | broken glass (from brittle) | 12 | 0.09 | 0.26 | 0.95 | 0.3 | 0.22 | 4 | |
| chop | axe | 30 | 0.38 | 0.70 | 1.35 | 2.2 | 0.80 | 25 | |
| long | standard lamp | 14 | 0.30 | 0.60 | 1.80 | 2.6 | 0.70 | 6 | pole |
| pole | lamp pole (from long) | 12 | 0.26 | 0.55 | 1.70 | 2.2 | 0.60 | 6 | |
| heavy | chairs; anything over 2 kg | 24 | 0.50 | 0.85 | 1.30 | 3.5 | 1.00 | 3 | leg |
| leg | chair leg (from heavy) | 13 | 0.18 | 0.40 | 1.25 | 1.3 | 0.35 | 8 | |

**Heavy blow:** ×1.8 damage, ×1.6 shove, ×2.2 windup, ×1.4 recovery, ×1.6 stamina, and twice
the wear.

**Strength.** Damage is multiplied by `Game.stat("strength")` (1.0 as he is; the Skills tree
raises it).

## Durability

Each thing has hits in it (the table). A blow that lands on her or on a wall uses one (two for a
heavy blow); knocking a light loose thing about doesn't. Durability is kept on the thing itself,
so a worn hammer stays worn if he puts it down. The HUD shows what's left as pips while he's
holding it, and the prompt shows it as a percentage.

At zero it breaks: pieces fly off (glass tinkling, wood cracking; a loud noise), and if the class
breaks into something he's left holding that (glass → a shard that cuts; a chair → a leg; the
lamp → its pole). Otherwise his hand is empty.

## Marta

She can't be killed by fists or furniture (or bullets): it knocks her about. Each blow takes
**poise** (40, refilling 6 a second). A blow that leaves poise above zero is a **flinch** (her head
snaps round, her chest knocked back) and, if she wasn't already after him, she is now. A blow
that takes the last of it **stuns** her, exactly as a bullet does: she reels away and comes back
harder. Every blow shoves her back by the weapon's shove.

So: fists alone (6 a jab) can't stun her before her poise comes back; a hammer takes three
quick blows; one heavy axe blow (54) does it outright.
