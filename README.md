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

## Saving
Progress is saved automatically: when a level starts, whenever your party or
stable changes, every 20 seconds, and when you close the game. There are
**3 save slots**; the title screen shows which one you're about to play, with
**New Game** (first free slot) and **Load Game** (load or delete a slot).

A save holds your tamer's name, party, hay beds, coins, potions and the
furthest level reached. Each player's save lives on **their own computer**
(`user://saves`, e.g. `%APPDATA%/Godot/app_userdata/Pack Leader/saves` on
Windows; in the browser it's stored by the browser), so you can bring your
tamer and pets into a friend's game. When you join, your save is sent to the
host, which checks it (real species, sensible levels, at most 3 party pets
and 20 beds) before restoring it. The host's save decides which level the
game starts on.

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
| LMB | Swing your bat toward the mouse: weakens creatures (never below 1 HP) and smashes crates |
| E | Throw a capture at the creature under the mouse |
| RMB on a wild creature or the rival | Send your pets to attack it |
| RMB on the ground | Pets drop their target and regroup |
| T (or the stance button under your pets) | Toggle pets between **Aggressive** and **Passive** |
| 1 / 2 / 3 | Use the ability of the pet in that party slot, aimed at the mouse |
| Q | Drink a health potion (heals 50%) |
| F (at the stable / lemonade stand) | Open/close the stable or the shop |
| K | Open/close the pet skills screen |
| I | Open/close your inventory (gear and bag) |
| Mouse wheel | Zoom the camera in and out (remembered between games) |
| M | Switch the mini map between the corner and a large view of the whole level |
| Esc | Close whatever menu is open (stable, shop, a confirmation, the Load Game list); with nothing open, the in-game menu: resume, save, quit to the main menu (solo pauses) |
| Space | Dash (brief invulnerability) |

- **Levels:** each level is one long, wide, randomly generated path that
  always runs from left to right across the screen, winding up and down, with rocks and packs of
  wild creatures that get tougher the further you go. It starts at a camp with
  the stable and ends in a boss arena. Defeat the boss and a portal opens at
  the far end; step in and everyone moves on to the next, harder level, and
  every pet gets bonus XP.
- **Biomes:** levels cycle through four biomes, each with its own creatures
  and its own boss (and creature levels keep rising each time round):

  | Level | Biome | Creatures | Boss |
  |---|---|---|---|
  | 1, 5, 9… | Greenmeadow | Cats: Mossback, Emberfox, Voltwing, Gloomhorn, Bloomling (the first two creatures by the camp are always Bloomlings) | **Rival Tamer** with one pet. The pet fights and uses its ability; when the rival is beaten the pet goes wild, weakened, so you can capture it |
  | 2, 6, 10… | Frostfang Peaks | Birds: Frostfinch, Quillpuff, Aurora Swift, Snowl | **Glacier Titan**: drops Avalanches (a red warning circle, then a slam that damages and slows) and summons capturable Frostfinches at 66% and 33% health |
  | 3, 7, 11… | Sunscorch Dunes (desert) | Dogs: Fangjackal, Dunehound, Cactipup, Sunfennec | **Sand Wyrm**: burrows underground (it can't be hit there), tunnels under a player or pet behind a warning circle and erupts; at half health it whips up sandstorms |
  | 4, 8, 12… | Mirewood Bog (swamp) | Lizards: Bogleon, Mirelurk, Wisp Gecko, Sporeguana | **Bog Witch**: a ranged caster whose bolts poison; she blinks away when you get close, drops toxic puddles and summons Bogleons at 60% and 30% health |
- **Tamer health:** after 5 seconds without taking damage you regenerate 3% of
  your max health per second. You carry up to **2 potions** (Q heals 50%),
  and start every level with a full pair. Bloomlings and Aurora Swifts can heal
  you too.
- **Lemonade stand:** halfway along every level there is a lemonade stand in
  a safe clearing. Press F there to buy from the vendor:
  - **Potion** (10 coins), up to the 2 you can carry.
  - **Lucky Lemonade** (15 coins): capture chance x1.5 for 90 seconds (still
    capped at 95%). Buying another while it's active resets the timer; it
    doesn't stack. The HUD and the hover capture chance include the boost.
- **Crates and coins:** crates along the path break in two hits and spill
  coins (gold crates take four hits and hold far more). Walk over coins to
  pick them up; coins belong to whoever collects them and carry over between
  levels.
- **Mini map:** bottom right, showing the path around you the way the camera
  sees it: rocks, crates, the stable (brown), the lemonade stand (yellow), the
  portal (purple, filled when open), the boss (big red), wild creatures (red),
  your pets (green), other players and their pets (in their colours) and you
  (an arrow). Press M for the whole level, large; M or Esc to shrink it.
- **Your tamer** is a little person with a bat, drawn in your colour (hair
  colour varies by player). They walk with swinging arms and legs; attacking
  swings the bat, and every hit pops a ring of spinning stars.
- **Village:** halfway along every level, a side path leads up the screen
  (through a doorway in the far wall) to a small village square: a few houses,
  a second **stable** and the **Bat Shop**. No wild creatures are placed
  there. At the Bat Shop (F) you can upgrade your Wooden Bat (12 damage) to a
  **Spiked Bat** (22 damage) for 60 coins. Every bat still stops creatures at 1 HP. Your bat is saved.
  The lemonade stand now sits on the stretch of path just before the village.
- **Breeder (village):** press F at the pink stall with the hay pen. Pick two
  different pets **of the same kind** (from your party or stable, any level)
  and pay 25 coins: they have a **hybrid** baby, a new species that only
  comes from breeding. No cross-breeding: cats only breed with cats, birds
  with birds, dogs with dogs and lizards with lizards. Each of the 28 pairings
  (10 cat, 6 bird, 6 dog, 6 lizard) makes its own hybrid, stronger than
  either parent (20% more health and attack than the better one), bigger,
  with a horn, mane (a frill or ruff), crown or wings (leathery on lizards)
  and a powered-up ability. The parents stay with you; the baby
  (level 1) joins your party, or the first free hay bed. Hybrids can't be bred
  again.

  | Parents | Hybrid | Ability |
  |---|---|---|
  | Mossback + Emberfox | Magmashell | Molten Guard: taunts, takes 60% less damage for 5s |
  | Mossback + Voltwing | Thundershell | Storm Shell: reflects 85% of damage for 5s |
  | Mossback + Gloomhorn | Stonehorn | Quake: bigger slam, stuns 2.5s |
  | Mossback + Bloomling | Mossbloom | Grove Aurora: heals everyone nearby 40% |
  | Emberfox + Voltwing | Blitzfox | Blitz Pounce: leap for 3.5x damage |
  | Emberfox + Gloomhorn | Cinderhorn | Meteor Slam: heavy slam, stuns 1.5s |
  | Emberfox + Bloomling | Sunpetal | Phoenix Bloom: heals the most hurt ally 70% |
  | Voltwing + Gloomhorn | Stormhorn | Thunder Chain: lightning jumps 5 times |
  | Voltwing + Bloomling | Sparkblossom | Static Ward: shields everyone 40% for 7s |
  | Gloomhorn + Bloomling | Duskbloom | Dusk Veil: enemies deal 50% less for 7s |
  | Frostfinch + Quillpuff | Glacipuff | Blizzard Nova: big frost blast, slows to 40% for 4s |
  | Frostfinch + Aurora Swift | Shimmerwing | Frost Aurora: heals everyone nearby 45% |
  | Frostfinch + Snowl | Rimeowl | Frost Ambush: teleports behind a target, 4x damage |
  | Quillpuff + Aurora Swift | Prismpuff | Prism Armor: reflects 85% of damage for 6s |
  | Quillpuff + Snowl | Quillowl | Quill Storm: heavy damage all around, slows 3s |
  | Aurora Swift + Snowl | Dawnowl | Dawn Song: heals everyone nearby 50% |
  | Fangjackal + Dunehound | Duneripper | Toxic Sandstorm: a big damaging storm for 6s |
  | Fangjackal + Cactipup | Thornjackal | Thorn Fang: hard bite, poisons for 6s |
  | Fangjackal + Sunfennec | Solarjackal | Solar Flare: half of nearby enemies' attacks miss for 5s |
  | Dunehound + Cactipup | Cactihound | Cactus Wall: shields everyone 45% for 7s |
  | Dunehound + Sunfennec | Sunhound | Heat Haze: scorching damage zone for 6s |
  | Cactipup + Sunfennec | Bloomfennec | Desert Bloom: heals everyone nearby 40% |
  | Bogleon + Mirelurk | Swampdrake | Mud Lash: yanks a target in for 2.5x damage |
  | Bogleon + Wisp Gecko | Glowleon | Soul Lash: 2.8x damage, heals it and you 70% of it |
  | Bogleon + Sporeguana | Toxileon | Toxic Haze: enemies deal 50% less for 7s |
  | Mirelurk + Wisp Gecko | Wraithlurk | Spirit Trap: up to 4 traps that root for 3.5s |
  | Mirelurk + Sporeguana | Mossdrake | Toxic Bog: poisonous damage zone for 6s |
  | Wisp Gecko + Sporeguana | Sporewisp | Glow Spores: heals everyone nearby 40% |
- **Pets are animated** too, at the pace they actually move: cats and dogs
  trot (diagonal legs together) and sway or wag their tails, birds hop and flap,
  lizards paddle in a sprawl and swing their bodies and tails, winged hybrids
  flap, and everyone breathes a little standing still.
- **Loot and inventory (I):** gear drops as glowing sacks (a beam of light in
  the item's rarity colour, its name above it): from crates (12%, gold crates
  40%), defeated wild creatures (8%) and every boss. Walk over a sack to put
  it in your **bag** (24 places). The inventory shows your **seven gear slots**
  (weapon, chest, pants, hat, two rings, a necklace) and the bag: click an item
  to see it, double-click (or Wear / Take off) to put it on or take it off,
  or throw it away. The weapon slot shows your bat (upgrade it at the Bat
  Shop). So far there are **jackets** for the chest, one per area level 1-5
  (Tattered, Leather, Padded, Studded, Ranger's: 4-16% less damage taken), each
  Common, Fine (+2%) or Superior (+4%); areas past level 5 drop level 5 gear.
  A worn jacket shows on your tamer. Armor is capped at 60%. Gear is saved.
- **Checkpoint:** downed players get back up after a few seconds at the start
  camp, or at the **lemonade stand** once they have reached it (come near it
  or get past it) this level. A grey flag beside the stand rises and turns
  green when you claim it. Each player has their own checkpoint; it resets on
  every new level.
- **Capturing:** the chance is 0% at full health and rises as the creature
  gets weaker. It is scaled by the species' `catch_rate` and lowered for
  higher-level creatures (at most 95%). Your **bat** never takes a creature
  below 1 HP, and a creature at 1 HP is a **99%** catch, so bonk it down and
  press E. (Pets can still knock a creature out, so set them to Passive when
  you want a capture.) Hover a creature to see the current chance. Failed
  captures make the creature angry.
- **Pet stance:** in **Passive** mode your pets stop attacking, drop their
  targets and just follow you, so you can weaken a creature with your own
  attack and capture it before the pets finish it off. Abilities you trigger
  yourself (1/2/3) still work. Sending pets at an enemy with RMB switches them
  back to **Aggressive** (the default) and they attack; T switches too.
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
  | Bloomling | Mending Bloom | Heals the most injured ally nearby (a pet or a player, including you) for 45% |
  | Frostfinch | Frost Nova | Damages every enemy around it and slows them to half speed for 3s |
  | Quillpuff | Frost Armor | For 5s, reflects 60% of the damage it takes back at the attacker |
  | Aurora Swift | Healing Aurora | Heals every nearby pet *and player* for 35% of their max health |
  | Snowl | Shadow Step | Teleports behind a target and strikes it for 3x damage |
  | Fangjackal | Venom Fang | Bites a target and poisons it (damage over 5s) |
  | Dunehound | Sandstorm | A sandstorm at the target that damages enemies inside it for 5s |
  | Cactipup | Spine Shield | Shields nearby pets *and players*, absorbing damage equal to 30% of their max health for 6s |
  | Sunfennec | Sun Flare | Damages nearby enemies and makes half their attacks miss for 4s |
  | Bogleon | Tongue Lash | Yanks a target next to the Bogleon and hits it for 1.5x damage (bosses are too heavy to pull) |
  | Mirelurk | Mud Trap | Hides a mud trap where it stands (up to 3, for 30s). The first enemy to step on it springs it: enemies nearby are damaged and rooted (can't move) for 2.5s |
  | Wisp Gecko | Life Drain | Hits a target for 2x and heals the gecko *and you* for 60% of the damage |
  | Sporeguana | Spore Cloud | Nearby enemies deal 40% less damage for 6s |
- **Pet skills (K):** every pet has a skill tree of six passive skills, shown
  on the skills screen (press K or click "Pet skills") with an icon for each:
  claws for attack damage, a heart for max health, a shield for armor, and a
  gold paw on **pack skills**, which boost *every* pet in your party while that
  pet is awake. The skills unlock left to right at levels 5, 10, 15, 20, 25 and
  30, and each can be trained up to **4 ranks**. Pets earn a skill point at
  level 5 and every 2 levels after (13 by level 30, against 24 possible ranks),
  so choose: click a skill to spend a point on it. "Reset skills" gives a pet's
  points back for free. Tanks like the Mossback and Mirelurk lean on armor and
  health, strikers like the Emberfox and Snowl on damage, supports like the
  Bloomling and Cactipup on pack skills. Armor is capped at 60%. Rivals' pets
  come trained. Unspent points show as "+N" in the party panel.
- **Stable:** every level has two stables, one at the start camp and one in
  the village; both open the same stable. Press F at either to open it: your
  party sits on three cushions (numbered by their ability key) and up to
  **20 pets sleep in hay beds**. Everything is drag and drop:
  drag a pet from a bed onto the party to bring it along, from the party onto a
  bed to rest it, onto an occupied place to swap, between beds to rearrange,
  or between party slots to change which key (1/2/3) uses its ability. Drop a
  pet on the **release gate** (and confirm) to set it free. Stabled pets are
  fully healed. If you capture a creature while your party is full it goes to
  the first free bed; if every bed is full too, the capture is refused.
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
| `scripts/save_game.gd` | Autoload `SaveGame`: save slots, autosave, and handing a save to the server to restore |
| `scripts/network.gd` | Autoload `Network`: WebSocket host/join, solo mode, player registry (names, colours) |
| `scenes/main.tscn` + `scripts/main.gd` | Menu + `LevelSpawner` that replicates the world to joining clients |
| `scenes/world.tscn` + `scripts/world.gd` | Level flow (start → rival → portal → next level), level geometry, spawners, XP sharing, FX |
| `scripts/level_generator.gd` | Deterministic layout of a level from a seed: path segments, rocks, creature spots, boss, exit |
| `scripts/biome_db.gd` | The biomes levels cycle through: their creatures, boss and colours |
| `scenes/rival.tscn` + `scripts/rival.gd` | The AI rival tamer boss (and the base class for every boss) |
| `scenes/titan.tscn` + `scripts/titan.gd` | The Glacier Titan boss: Avalanche and Frostfinch summons |
| `scenes/sand_wyrm.tscn` + `scripts/sand_wyrm.gd` | The Sand Wyrm boss: burrow, erupt, sandstorms |
| `scenes/bog_witch.tscn` + `scripts/bog_witch.gd` | The Bog Witch boss: poison bolts, blink, toxic puddles, Bogleon summons |
| `scenes/player.tscn` + `scripts/player.gd` | Movement, aim, and server-validated attack/capture/command requests |
| `scenes/creature.tscn` + `scripts/creature.gd` | One scene for wild creatures *and* pets: wild AI, pet AI, taming, levelling |
| `scripts/pet_skills.gd` | Every species's six skills, skill points and ranks, and how they add up |
| `scripts/level_generator.gd` (village) + `World._build_village` | The village side path, square, houses and bat shop |
| `scripts/breeding_db.gd`, `scripts/breeder_window.gd` | Which pairs breed into which hybrid, the rules, and the breeder's window |
| `scripts/person_model.gd` | The tamer's body, bat, walk cycle and bat swing, built from simple meshes |
| `scripts/creature_animator.gd` | Pet animations (walk, tails, wings, breathing), driven by how fast each pet moves |
| `scripts/pause_menu.gd` | The in-game menu on Esc: resume, save, quit to the main menu |
| `scripts/ui_theme.gd` → `resources/ui_theme.tres`, `scripts/ui_icons.gd` | The menus' look (dark panels, gold borders, light text) and their line icons (small SVGs drawn at runtime). Rebuild the theme file with `godot --headless --path . -s res://scripts/tools/build_ui_theme.gd` |
| `scripts/ground_textures.gd` | The ground textures, painted in code per biome: grass, snow and ice, sand ripples, swamp mud and puddles, plus camp dirt, arena flagstones and village cobblestones |
| `scripts/building_textures.gd` | The buildings' shared textures, painted in code: clay shingle roofs, plaster walls, plank doors (and stall woodwork) |
| `scenes/obstacles/*.tscn` (built by `scripts/tools/build_obstacles.gd`) | Four premade trees and rocks per biome (meadow: oak, pine, mossy boulder, berry bush; frost: frosted white spruce, ice crystals, snow boulder, frozen tree; desert: cactus, sandstone pillar, palm, boulders; swamp: willow, vine tree, mossy rock, old stump), placed turned and sized differently from the level seed. Rebuild with `godot --headless --path . -s res://scripts/tools/build_obstacles.gd` |
| `scripts/item_db.gd`, `scripts/inventory_window.gd`, `scripts/loot.gd` | Gear (items, slots, rarities, jackets), the inventory window (I) and loot sacks on the ground |
| `scripts/mini_map.gd` | The mini map (and the large map, M), drawn from the level layout |
| `scripts/skill_window.gd`, `scripts/skill_icons.gd` | The skills screen (K) and its skill icons, drawn in code |
| `scripts/creature_model.gd` | Builds each creature's body from simple meshes: a cat, bird, dog or lizard, depending on its biome |
| `scripts/creature_species.gd`, `resources/species/*.tres`, `scripts/species_db.gd` | Species data. Add a `.tres` and list it in `SpeciesDB` to add a species |
| `scripts/combat.gd` | Faction rule (`Combat.are_enemies`) that enforces no friendly fire |
| `scripts/abilities/*.gd`, `resources/abilities/*.tres` | `PetAbility` base class and one subclass per ability; tune values in the `.tres` files |
| `scenes/crate.tscn` + `scripts/crate.gd`, `scenes/coin.tscn` + `scripts/coin.gd` | Breakable crates and the coins they spill |
| `scripts/components/health.gd` | Health with setter-driven signals (works with replication), plus poison and damage-absorbing shields |
| `scripts/pet_slot.gd` | A drag-and-drop place in the stable window (hay bed, party cushion or release gate), drawn in code |
| `scenes/hud.tscn` + `scripts/hud.gd` | Health, pet party, hover/capture info, message feed |

Physics layers: 1 world · 2 players · 3 hostiles (wild creatures, bosses, rival pets) · 4 player pets.

## Suggested next steps
1. **More for the vendor to sell:** pet treats (XP), revive items or cosmetics.
2. **Wild abilities:** let wild creatures use their species ability too (rival pets already do).
3. **More abilities per pet:** e.g. a second ability unlocked at level 5, or abilities learned from items.
4. **Smoother networking:** interpolate remote players and creatures, which currently snap to each replicated position.
5. **Real art:** replace the placeholder meshes with glTF models and an `AnimationTree`.
6. **Level variety:** more biomes, side branches with treasure, and rival tamers with more pets on later levels.
7. **Pathfinding:** a `NavigationRegion3D` with a `NavigationAgent3D` on each creature, so they route around rocks.
