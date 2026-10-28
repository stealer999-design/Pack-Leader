# Pack Leader

Co-op (2–4 players) isometric action RPG where **pets are the focus**: every
creature in the world can be captured, then follows you, fights for you and
levels up. Each level is a randomly generated path from a start camp to a
rival tamer waiting at the end.

![screenshot](screenshot.png)

## Run
Open `project.godot` in Godot 4.4+ and press F5. Click **Play solo**, or have
one player click **Host** while the others enter the host's address and click
**Join**. Networking uses WebSockets on **TCP port 24565**; for play over the
internet the host must forward that port (or use a tunnel, see below).

Quick local test with two instances, from the command line:
```
godot --path . -- --host --name=Alice
godot --path . -- --join=127.0.0.1 --name=Bob
godot --path . -- --solo
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

## Playing in a browser
Export the **Web** preset (or use a release zip): it produces `index.html` plus a
few files. It needs no special server headers (it is built without threads), so
any static host works. The easiest is [itch.io](https://itch.io): create an
HTML game, upload the zipped `export/web` folder, and tick "This file will be
played in the browser".

- **Solo** works anywhere: click **Play solo**, or open `index.html?solo`.
- **Multiplayer:** browsers can **join** but not **host**. Someone hosts from the
  desktop version, and browser players join it. Desktop and browser players can
  play together.
- A page served over **https** (like itch.io) may only connect to a secure
  `wss://` address. The host can get one without a certificate by running a
  tunnel, for example [Cloudflare's free quick tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/do-more-with-tunnels/trycloudflare/):
  `cloudflared tunnel --url http://localhost:24565`. It prints an
  `https://….trycloudflare.com` address; players type it into **Join** as
  `wss://….trycloudflare.com`.
- Join links: `index.html?join=wss://example.trycloudflare.com&name=Bob` connects
  straight away.

## How to play
| Input | Action |
|---|---|
| WASD | Move |
| LMB | Attack toward the mouse (weak, used to weaken creatures) |
| E | Throw a capture at the creature under the mouse |
| RMB on a wild creature or the rival | Send your pets to attack it |
| RMB on the ground | Pets drop their target and regroup |
| 1 / 2 / 3 | Use the ability of the pet in that party slot, aimed at the mouse |
| F (at the stable) | Open/close the stable |
| Space | Dash (brief invulnerability) |

- **Levels:** each level is one randomly generated path that always runs up
  the screen, winding left and right, with rocks and packs of wild creatures
  that get tougher the further you go. It starts at a camp with the stable and
  ends in an arena where a **Rival Tamer** waits with one pet. Get close and
  the rival challenges you; its pet fights and uses its ability too. Defeat the
  rival and a portal opens at the far end. Step in and everyone moves on to the
  next, harder level. Defeating a rival also gives every pet bonus XP, and the
  rival's pet goes wild (weakened), so you can capture it.
- **Downed players** respawn next to a teammate who is still standing, or at
  the start camp if nobody is.
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
- **Stable:** there is one stable, at the start of every level, holding up to
  12 pets per player.
  Walk up to it and press F to store, take out, swap or release pets.
  Stabled pets are fully healed. If you capture a creature while your party is
  full, it goes straight to the stable; if the stable is full too, the capture
  is refused.
- **No friendly fire:** there are two sides: hostiles (wild creatures, rivals
  and rivals' pets) and tamers (every player and every player's pet). Nothing
  can hurt or target its own side, and pets immediately drop a target that
  someone else captures. Mossbacks are passive, which makes them good first
  captures.

## Architecture
The host is the authoritative server and also plays.

- **Player position** is owned by each client (`PositionSync`), so movement
  feels responsive.
- **Requests:** attacks, captures and pet commands are sent to the server as
  RPCs, which checks and resolves them.
- **Server-owned state:** all creature and rival AI, damage, health,
  ownership and XP run on the server and are replicated to clients.
- **Levels** are generated from a seed. Only the seed and level number are
  replicated (`World.level_state`); every peer builds identical geometry from
  them, including players who join mid-game.

| Path | What it is |
|---|---|
| `scripts/network.gd` | Autoload `Network`: WebSocket host/join, solo mode, player registry (names, colours) |
| `scenes/main.tscn` + `scripts/main.gd` | Menu + `LevelSpawner` that replicates the world to joining clients |
| `scenes/world.tscn` + `scripts/world.gd` | Level flow (start → rival → portal → next level), level geometry, spawners, XP sharing, FX |
| `scripts/level_generator.gd` | Deterministic layout of a level from a seed: path segments, rocks, creature spots, rival, exit |
| `scenes/rival.tscn` + `scripts/rival.gd` | The AI rival tamer at the end of each level |
| `scenes/player.tscn` + `scripts/player.gd` | Movement, aim, and server-validated attack/capture/command requests |
| `scenes/creature.tscn` + `scripts/creature.gd` | One scene for wild creatures *and* pets: wild AI, pet AI, taming, levelling |
| `scripts/creature_species.gd`, `resources/species/*.tres`, `scripts/species_db.gd` | Species data. Add a `.tres` and list it in `SpeciesDB` to add a species |
| `scripts/combat.gd` | Faction rule (`Combat.are_enemies`) that enforces no friendly fire |
| `scripts/abilities/*.gd`, `resources/abilities/*.tres` | `PetAbility` base class and one subclass per ability; tune values in the `.tres` files |
| `scripts/components/health.gd` | Health with setter-driven signals (works with replication) |
| `scenes/hud.tscn` + `scripts/hud.gd` | Health, pet party, hover/capture info, message feed |

Physics layers: 1 world · 2 players · 3 hostiles (wild creatures, rivals, rival pets) · 4 player pets.

## Suggested next steps
1. **Persistence:** save each player's party and stable to disk so pets carry between sessions.
2. **Wild abilities:** let wild creatures use their species ability too (rival pets already do).
3. **More abilities per pet:** e.g. a second ability unlocked at level 5, or abilities learned from items.
4. **Smoother networking:** interpolate remote players and creatures, which currently snap to each replicated position.
5. **Real art:** replace the placeholder meshes with glTF models and an `AnimationTree`.
6. **Level variety:** themed biomes per level, side branches with treasure, and rival tamers with more pets on later levels.
7. **Pathfinding:** a `NavigationRegion3D` with a `NavigationAgent3D` on each creature, so they route around rocks.
