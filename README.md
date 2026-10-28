# Pack Leader

Co-op (2–4 players) isometric action RPG where **pets are the focus**: every
creature in the world can be captured, then follows you, fights for you and
levels up.

![screenshot](screenshot.png)

## Run
Open `project.godot` in Godot 4.4+ and press F5. One player clicks **Host**;
others enter the host's IP and click **Join** (UDP port 24565; for play over
the internet the host must forward that port).

Quick local test with two instances, from the command line:
```
godot --path . -- --host --name=Alice
godot --path . -- --join=127.0.0.1 --name=Bob
```
Or in the editor: *Debug → Customize Run Instances*, enable 2 instances, and
give them the arguments `--host` and `--join=127.0.0.1`.

## Building a Windows .exe
Export presets for Windows and Linux are included (`export_presets.cfg`).
1. In Godot: **Editor → Manage Export Templates → Download and Install** (once).
2. **Project → Export**, choose **Windows Desktop**, click **Export Project**.

The game data is embedded, so the result is a single `PackLeader.exe` you can
share. From the command line:
```
godot --headless --path . --export-release "Windows Desktop" export/windows/PackLeader.exe
```

## How to play
| Input | Action |
|---|---|
| WASD | Move |
| LMB | Attack toward the mouse (weak, used to weaken creatures) |
| E | Throw a capture at the creature under the mouse |
| RMB on a wild creature | Send your pets to attack it |
| RMB on the ground | Pets drop their target and regroup |
| 1 / 2 / 3 | Use the ability of the pet in that party slot, aimed at the mouse |
| F (at the stable) | Open/close the stable |
| Space | Dash (brief invulnerability) |

- **Capturing:** the chance is 0% at full health and rises as the creature
  gets weaker. It is scaled by the species' `catch_rate` and lowered for
  higher-level creatures. Hover a creature to see the current chance. Failed
  captures make the creature angry.
- **Pets:** you can have up to 3 in your party. They automatically defend you
  and each other, and earn XP from kills within 25 units. When a pet runs out
  of health it faints and recovers after 8 seconds.
- **Pet abilities:** every species has a signature ability with its own
  cooldown (shown in the party panel). If the target is out of range, the pet
  runs into range first and then casts.

  | Species | Ability | Effect |
  |---|---|---|
  | Mossback | Shell Guard | Taunts nearby wild creatures onto itself, takes 50% less damage for 4s |
  | Emberfox | Pounce | Leaps to the target point and deals 2.5x damage around the landing |
  | Voltwing | Static Arc | Lightning that chains between up to 3 enemies (needs a target) |
  | Gloomhorn | Earthshaker | Damages and stuns every enemy within 4 units for 2s |
- **Stable:** the building north of the camp holds up to 12 pets per player.
  Walk up to it and press F to store, take out, swap or release pets.
  Stabled pets are fully healed. If you capture a creature while your party is
  full, it goes straight to the stable; if the stable is full too, the capture
  is refused.
- **No friendly fire:** there are two sides, wild creatures and tamers (every
  player and every pet). Nothing can hurt or target its own side, and pets
  immediately drop a target that someone else captures.
- **The world:** creatures get stronger the further they are from the central
  camp. Mossbacks are passive, which makes them good first captures.

## Architecture
The host is the authoritative server and also plays.

- **Player position** is owned by each client (`PositionSync`), so movement
  feels responsive.
- **Requests:** attacks, captures and pet commands are sent to the server as
  RPCs, which checks and resolves them.
- **Server-owned state:** all creature AI, damage, health, ownership and XP
  run on the server and are replicated to clients.

| Path | What it is |
|---|---|
| `scripts/network.gd` | Autoload `Network`: host/join, player registry (names, colours) |
| `scenes/main.tscn` + `scripts/main.gd` | Menu + `LevelSpawner` that replicates the world to joining clients |
| `scenes/world.tscn` + `scripts/world.gd` | Arena, player/creature spawners, wild population, XP sharing, FX |
| `scenes/player.tscn` + `scripts/player.gd` | Movement, aim, and server-validated attack/capture/command requests |
| `scenes/creature.tscn` + `scripts/creature.gd` | One scene for wild creatures *and* pets: wild AI, pet AI, taming, levelling |
| `scripts/creature_species.gd`, `resources/species/*.tres`, `scripts/species_db.gd` | Species data. Add a `.tres` and list it in `SpeciesDB` to add a species |
| `scripts/combat.gd` | Faction rule (`Combat.are_enemies`) that enforces no friendly fire |
| `scripts/abilities/*.gd`, `resources/abilities/*.tres` | `PetAbility` base class and one subclass per ability; tune values in the `.tres` files |
| `scripts/components/health.gd` | Health with setter-driven signals (works with replication) |
| `scenes/hud.tscn` + `scripts/hud.gd` | Health, pet party, hover/capture info, message feed |

Physics layers: 1 world · 2 players · 3 wild creatures · 4 pets.

## Suggested next steps
1. **Persistence:** save each player's party and stable to disk so pets carry between sessions.
2. **Wild abilities:** let wild creatures use their species ability too, for tougher fights.
3. **More abilities per pet:** e.g. a second ability unlocked at level 5, or abilities learned from items.
4. **Smoother networking:** interpolate remote players and creatures, which currently snap to each replicated position.
5. **Real art:** replace the placeholder meshes with glTF models and an `AnimationTree`.
6. **Pathfinding:** a `NavigationRegion3D` with a `NavigationAgent3D` on each creature, so they route around rocks.
