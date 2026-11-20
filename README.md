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
| LMB | Swing your bat toward the mouse: weakens creatures (never below 1 HP) and smashes vases |
| E | Toss a treat at the creature under the mouse (or, if there isn't one, the nearest tameable creature in range, preferring weakened ones) |
| RMB on a wild creature or the rival | Send your pets to attack it |
| RMB on the ground | Pets drop their target and regroup |
| T | Toggle pets between **Aggressive** and **Passive** |
| 1 / 2 / 3 | Use the ability of the pet in that party slot, aimed at the mouse |
| Q | Drink a health potion (heals 50%) |
| F (at the stable / lemonade stand) | Open/close the stable or the shop |
| K | Open/close the pet skills screen |
| I | Open/close your inventory (gear and bag) |
| Mouse wheel | Zoom the camera in and out (remembered between games); it zooms out no further than the view the game starts with |
| M | Switch the mini map between the corner and a large view of the whole level |
| Esc | Close whatever menu is open (stable, shop, a confirmation, the Load Game list); with nothing open, the in-game menu: resume, save, quit to the main menu (solo pauses) |
| Space | Dash (brief invulnerability) |

- **Action bar:** the bar along the bottom of the screen holds everything you
  use in a fight, and every box can be clicked as well as using its key (hover
  one for details):
  - your **health orb** (a glass ball of red that drains as you're hurt);
  - two tiny buttons stacked beside it: **capture** (E, lit up when there's a
    tameable creature in range, with its catch chance in the tooltip) above
    **potion** (Q, with a red count of how many you have and a cooldown sweep);
  - your **bat** (LMB);
  - your three **pets** (1 2 3): portrait, level, health and
    experience (gold) strips, the ability cooldown counting down (lit when ready), a
    "+" when they have skill points to spend, and "Dead" when killed. Click
    one to open the skills;
  - **pet stance** (T) and your **coins**.

  The bar is only as wide as what's on it.

  Under the mini map sit three tiny buttons: **inventory** (I, with a red
  count of new gear you've picked up), **skills** (K, with your pets' unspent
  points) and the **menu** (Esc).

- **Levels:** each level is one long, wide, randomly generated path that
  heads across the screen from left to right and winds through **one to three
  smooth curves** (S-bends, alternating left and right), its width easing
  wider and narrower along the way, with walls following its edges, rocks and packs of
  wild creatures that get tougher the further you go. It starts at a camp with
  the stable and ends in a boss arena. Defeat the boss and the **Next level**
  portal opens at the far end; step in and everyone moves on to the next,
  harder level, and every pet gets bonus XP.
- **First-capture tip:** the first time your bat knocks a creature you could
  tame down to 1 HP, the game pauses (solo; in multiplayer it keeps running)
  with a tip: *"Your bat can't kill the pets and it is now at 1HP. Press E to
  throw it a treat and he will now be your friend."* Press E to close it and
  throw the treat straight away, or click Got it (Enter and Esc close it too).
  It shows once per save. Then, a moment after your **first capture** (once
  its heart has popped up), a second tip pauses the game: *"Now that you have
  your first friend, they will fight alongside you to defeat your next foe.
  Right-click an enemy to tell your pets to attack it. Press T to set your
  pets to passive, and they will stand by while you befriend your next pet."* Also once per save. And the first time a capture
  goes to your **reserve** because your party is full (your 4th pet, in a new
  game), a third tip explains the reserve: it carries 3 more pets that level
  up too, you swap them in the inventory's Pets tab at any time (even
  mid-fight), dead pets need a stable, and once the reserve is full new
  friends go to the stable.
- **Capturing with treats:** every wild creature you could tame shows its
  **catch chance** over its name ("Catch 57%", grey at 0%, red to yellow to
  green as it rises; it counts your Lucky Lemonade). Pressing E (or the
  capture button) makes your tamer **toss a dog biscuit**, which arcs over to
  the creature: if it's caught, the creature gobbles the treat and a **pink
  heart** pops up over its head; if not, the treat bounces off and it breaks
  free. The result is decided when the treat lands.
- **Notifications where you're looking:** what happens to you and your pets
  pops up as a small badge (an icon and a few words) over the head it's
  about, rises and fades: **Level 5!** with a gold arrow over a pet that
  levels up, **+1 skill point (K)**, **Dead: rest at a stable**, **Revived!**,
  **Over-levelled: less XP**; over your tamer **Caught a Bloomling!**, where a
  capture went (reserve or stable), **Checkpoint!**, reserve pets levelling,
  stance changes, **No potions left**, **Too far away**; over a creature
  **Broke free!** or **Monsters can't be tamed**. Several at once stack
  upwards. The feed on the right is kept for the big news only (the area and
  its boss, boss summons, a boss beaten, rare finds, teammates going
  down, captures and breeding by others, and replies to what you do in a shop
  or the stable window), holds at most 4 lines and fades after a few seconds.
  Saving is silent.
- **Loading:** each level starts behind a short "Loading..." screen (about a
  second), while the game shows the camera everything the level can show,
  once: every effect (bolts, arrows, spells, bursts, zones, loot, coins,
  pickups), and the whole level at once (every creature, the boss, buildings
  and obstacles), and loads every sound and icon. Graphics cards compile each
  kind of material the first time they draw it, which used to cause little
  freezes the first few times things appeared mid-play.
- **Open fields (Acts 2-5):** the monster acts' levels (and their repeats) aren't paths: each is a
  **big open field**, a rounded box (about 224 by 328 units) with gently wavy
  edges and a wall all round (low on the side facing the camera). The camp is
  at the left end. The **boss has its own arena**: a walled box of flagstones
  outside the field's right-hand edge, anywhere up or down it, joined to the
  field by a short walled corridor through a gap in the wall; the exit and
  Travel portals are inside it, past the boss. The objective at the top reads
  **"Find and defeat"** the boss, and the arena is hidden on the map until
  you've found it. Somewhere in
  the middle, never dead centre and never near the edges, is a **town**
  ringed by a **white picket fence**, with gates on its south side (towards
  the camera) and west side (towards the camp). The town holds the
  **lemonade stand** (walking into town is your checkpoint), a stable, the
  bat shop and the breeder; no creatures are placed inside it. A field has
  **exactly as many** monsters, vases (and gold vases) and obstacles as the
  path level from the same seed would, just spread out over the field, clear
  of the camp, the arena and the town. The monsters come in **packs of 3 to
  5**, each pack **all one kind** (a pack of skeletons, a pack of zombies...).
- **Travel:** beside it stands the violet **Travel** portal, always open (even
  before the boss is beaten). Step into it to pick any area you've reached, to
  catch the pets that live there, or to level your pets somewhere easier
  before going on. Everyone travels together; going back never loses your
  progress (the furthest area reached stays unlocked), and saves resume in
  the area you were in.
- **The Crossroads:** a new game starts at the Crossroads, a peaceful hub
  with the stable, village and lemonade stand, and a plaza with a walk-in
  portal for each Act 1 area: **Greenmeadow** (cats, Wizards), **Frostfang
  Peaks** (birds, Archers), **Sunscorch Dunes** (dogs, Paladins) and
  **Mirewood Bog** (lizards, Venomancers). Each sign shows the creature
  levels you'd meet there. Walk into one to go: **you choose the order**, so
  you collect the pets you want first. The area you pick first has creatures
  at level 1-5, the second 6-10, the third 11-15 and the fourth 16-20, and
  its boss is scaled to match. After beating an Act 1 boss, its portal leads
  back to the Crossroads to pick the next one. A new area stays sealed until
  the current area's boss is beaten. Cleared areas stay open to revisit (and
  so does the Crossroads, through the Travel portal). Once all four are
  cleared, the boss's portal leads on to Act 2, and the Crossroads gets a red
  **On to Act 2** portal beside the Travel portal, so you can always get there
  from the hub.
- **Acts and biomes:** the four biomes make up **Act 1**, one area each, in
  the order you choose, and each area's creatures are five levels higher than
  the last (weakest by the camp, strongest near the boss; the rival's pet is
  at the top level). Then each of the four monster biomes is an act of its
  own, **three levels long**, for **16 levels** in all:

  | Act | Levels | Biome | Creature levels |
  |---|---|---|---|
  | Act 1 | 1-4 | Greenmeadow, Frostfang Peaks, Sunscorch Dunes, Mirewood Bog (your order) | 1-20 |
  | Act 2 | 5-7 | Hollowmere Graveyard: skeletons and zombies | 21-35 |
  | Act 3 | 8-10 | Scorchsand Ruins (desert): mummies and sand scorpions; boss Dom the House Cat | 36-50 |
  | Act 4 | 11-13 | Cinderpeak Caldera (volcano): fire imps and magma golems; boss Koleko the Fire Dog | 51-65 |
  | Act 5 | 14-16 | Frostveil Expanse (ice): frost wraiths and yetis; boss Pye the Parrot | 66-80 |

  Their foes are monsters, not creatures: they can't be captured, and your bat
  finishes them off (no 1 HP limit), so bring your pets from Act 1. The
  **named boss** guards the **third level** of each monster act. The first
  two levels end with a **Champion** instead: a giant version of one of the
  act's monsters (nearly twice the size, 8 times the health, 60% more damage,
  a gold name such as "Skeleton Champion"), waiting in the boss arena; beating
  it opens the exit, always drops gear and gives the team a boss's worth of
  experience. After level 16 the cycle starts again: Act 6 is the Act 1 areas
  at 81-100, and so on. Bosses get tougher to match. The HUD shows the act,
  area and creature levels.

  Every boss has its own model: the rival, Kael, is a realistic textured 3D
  model (`models/rival_kael.glb`, made in Meshy) of a cowboy in a red hat and
  shirt with a bat, rigged with a skeleton and animated: he stands with his
  arms thrown out to issue his challenge (planting his feet for 1.6 s), runs or
  walks after his target (the cycles paced to how fast he really moves), swings
  the bat overhead (Meshy's attack, sped up from the top of the wind-up), holds
  a ready stance between swings, and flashes white when hit. Meshy's automatic
  skinning tied the bat to his thigh and the jeans to his hands, so the model
  was repaired with `scripts/tools/meshy_skin/fix_rival_skin.py` (run it again
  on a fresh Meshy export). The older hat-and-cape model built in code is kept
  as a fallback. Pye the Parrot is a rigged Meshy model too (`models/pye.glb`):
  he waddles (a penguin walk) and runs with his wings spread wide like a goose
  squaring up (`scripts/tools/meshy_skin/fold_wings.py --spread` holds the wing
  bones still), and lowers his head to charge for each
  peck (played on the spot), standing still between moves; the grey parrot
  built in code is the fallback. The Glacier Titan is a rigged Meshy model as
  well (`models/glacier_titan.glb`): a hulking golem of blue ice that breathes
  and shifts while standing (a real idle), trudges after you (never runs), and
  slams both fists down from overhead; for an Avalanche he plants his feet and
  winds up from the start, so the fists land as the warning circle runs out.
  The ice golem built in code is the fallback. The Bog Witch is a rigged Meshy
  model (`models/bog_witch.glb`, `models/sand_wyrm.glb`, `models/zombie_fish.glb`, `models/dom.glb`, `models/koleko.glb`, Meshy's separate walk, idle and spell-cast
  exports merged into one file with `scripts/tools/meshy_skin/merge_anims.py`):
  a hag in tattered purple robes who idles, walks (never runs) and throws out
  her arms to cast each poison bolt, stopping to cast her toxic puddles; the
  floating witch built in code is the fallback. The Sand Wyrm is a Meshy model
  (`models/sand_wyrm.glb`) that Meshy couldn't rig (not a human shape), so
  `scripts/tools/meshy_skin/rig_worm.py` gives it a skeleton: a root holding
  its sand mound still, four body bones up the worm, a head and a mouth. The
  game animates it in code: a wave sways up the body (faster and wider while
  it slithers), it rears back and lunges to bite with its round maw gaping,
  and it sinks into the sand to burrow; the worm built in code is the
  fallback. Howard the Zombie Fish is a Mixamo-rigged Meshy model
  (`models/zombie_fish.glb`): he walks on his zombie legs, high-kicks for his
  hit, stops to cast each Rotten Splash and screams to raise the dead. A fish
  has no arms, but the rig did: his body was tied to the left shoulder and
  his side fins to the arm bones, which pulled them into long blades, so
  `scripts/tools/meshy_skin/fix_fish.py` moves all of that onto the upper
  spine and `fix_skin.py --generic` mends the few points that still tore. The
  fish built in code is the fallback. Dom the House Cat is a Meshy model too
  (`models/dom.glb`), but Meshy only rigs humanoids, so
  `scripts/tools/meshy_skin/rig_quad.py` (settings and animations in
  `scripts/tools/meshy_skin/dom/`) straightens him, gives him a four-legged
  skeleton (hips, spine, chest, neck, head, jaw, a four-bone tail and three
  bones a leg, plus shoulder blades and ears), weights him by body part and
  bakes keyframed animations in which a paw on the ground stays planted (two-
  bone IK), the shoulder blades roll, the head stays steady while the body
  sways and the tail follows through: an idle (breathing, looking about, ear
  flicks, a slow S-curving tail), a cat's walk that he uses at every speed
  (lateral sequence with direct registering: each hind paw lands in the print
  its fore paw just left), a bounding run whose spine gathers and stretches
  (unused for now), a paw swipe (his hit: weight back, paw cocked, a fast
  strike and a raking drag), a stalk-wiggle-pounce (Pounce and Swipe), a
  heaving hairball retch (which he stops for) and an arched-back, ears-flat,
  tail-up hiss (his summons); `fix_skin.py --generic`
  then mends the points that stretched. The cat built in code is the
  fallback. Koleko the Fire Dog goes through the same process
  (`models/koleko.glb`, settings and animations in
  `scripts/tools/meshy_skin/koleko/`; both animals share the planted-paw
  library `quad_lib.py`): a black, gold-spined hellhound that pants while he
  stands and trots everywhere (diagonal pairs striking together, a bounce on
  each beat; at speed 4.2 he is quicker than the other bosses' 3.0), lunges to bite and shakes
  his head (his hit), rears back and heaves forward to spit his Lava Spit
  (which he stops for) and settles back to howl at the sky when he calls his
  fire imps. He has no separate ears, but his mouth really opens. The dog
  built in code is the fallback. The Meshy models' textures
  are extracted next to each .glb (`models/*_texture_0.png`, `*_normal.png`,
  `*_metallic_roughness.png`) and imported GPU-compressed (S3TC, which desktop
  browsers also read), with the normal and roughness maps capped at 1024 px,
  so each boss adds about 6 MB to the download instead of 25. In the code-built set, the Glacier Titan a hulking ice golem with crystal
  shoulders and huge fists, the Sand Wyrm an armoured worm rearing out of a
  sand mound with a toothy maw and snapping mandibles, and the Bog Witch a
  hunched, floating witch with a crooked hat and a glowing staff.

  | Area | Biome | Creatures | Boss |
  |---|---|---|---|
  | Act 1 (your choice of order) | Greenmeadow | Cats: Mossback, Emberfox, Voltwing, Gloomhorn, Bloomling (the first two creatures by the camp are always Bloomlings) | **Rival Tamer** with one pet. The pet fights and uses its ability; when the rival is beaten the pet goes wild, weakened, so you can capture it |
  | Act 1 | Frostfang Peaks | Birds: Frostfinch, Quillpuff, Aurora Swift, Snowl | **Glacier Titan**: drops Avalanches (a red warning circle, then a slam that damages and slows) and summons capturable Frostfinches at 66% and 33% health |
  | Act 1 | Sunscorch Dunes (desert) | Dogs: Fangjackal, Dunehound, Cactipup, Sunfennec | **Sand Wyrm**: burrows underground (it can't be hit there), tunnels under a player or pet behind a warning circle and erupts; at half health it whips up sandstorms |
  | Act 1 | Mirewood Bog (swamp) | Lizards: Bogleon, Mirelurk, Wisp Gecko, Sporeguana | **Bog Witch**: a ranged caster whose bolts poison; she blinks away when you get close, drops toxic puddles and summons Bogleons at 60% and 30% health |
  | Act 2 (Lv 21-35) | Hollowmere Graveyard | Monsters: Skeletons (quick, with rusty swords) and Zombies (slow, tough, hit hard); can't be captured | **Howard the Zombie Fish**: a huge rotting fish on a pair of zombie legs, one eye bulging and one crossed out, ribs showing, a fishhook in his lip. He spits a Rotten Splash under a player or pet (a red warning circle, then damage and a slow), and calls up skeletons and a zombie at 66% and 33% health |
  | Act 3 (Lv 36-50) | Scorchsand Ruins (desert) | Monsters: Mummies (slow, bandaged, tough) and Sand Scorpions (fast, pincers and a stinger) | **Dom the House Cat**: a giant orange tabby with a white chest, socks and muzzle, green eyes, whiskers and a tall curling tail. By turns: **Pounce and Swipe** (a small warning circle; he springs forward onto it, claws everyone there and springs back) and **Hairball** (a warning circle, then a pool of green vomit that hurts anyone standing in it for 7 seconds); scorpions and a mummy answer his hiss at 66% and 33% health. This act's Champions are fixed: a **Skeleton Champion** on level 8 and a **Mummy Champion** on level 9 |
  | Act 4 (Lv 51-65) | Cinderpeak Caldera (volcano) | Monsters: Fire Imps (quick, winged, throw fire from range) and Magma Golems (slow, huge, hit hard) | **Koleko the Fire Dog**: a huge dog of black, cracked rock with lava glowing through the cracks, a crest of flames down his back, tall pointed ears, burning eyes and a tail of fire. Lava Spit (a warning circle, then a burst of fire that burns, and the ground stays ablaze for 3 seconds); fire imps leap from the flames at 66% and 33% health |
  | Act 5 (Lv 66-80) | Frostveil Expanse (ice) | Monsters: Frost Wraiths (floating, cast ice from range) and Yetis (big, shaggy, hit hard) | **Pye the Parrot**: a giant grey parrot: soft grey feathers (paler on the head, darker on the wings), a bright red tail, white face patches and a big black hooked beak. Feather Flurry (a warning circle, then a storm of feathers: damage and a slow); the blizzard brings wraiths and a yeti at 66% and 33% health. While fighting he chatters in speech bubbles: "whatcha doin?" and "Honk Honk" (to become audio later) |
- **Pet health:** your pets heal passively, 1 HP every half second, all the
  time (even mid-fight), unless they're dead (see Death below).
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
- **Vases and coins:** clay vases along the path shatter in one hit and spill
  coins (gold vases are rarer and hold far more). Walk over coins to
  pick them up; coins belong to whoever collects them and carry over between
  levels.
- **Mini map:** bottom right, showing the path around you the way the camera
  sees it: rocks, vases, the stable (brown), the lemonade stand (yellow), the
  portal (purple, filled when open), the boss (big red), wild creatures (red),
  your pets (green), other players and their pets (in their colours) and you
  (an arrow). Press M for the whole level, large; M or Esc to shrink it.
  In the open fields (Acts 2-5) the map starts **dark**: it's revealed as you walk
  (everything within about 18 units of you), and vases, wild creatures and
  the boss only show where you've explored. Each player has their own map.
- **Your tamer** is a little person with a bat, drawn in your colour (hair
  colour varies by player). They walk with swinging arms and legs; attacking
  swings the bat, and every hit pops a ring of spinning stars.
- **Village:** around halfway along every level (on a straight stretch of the
  winding path), a side path leads up the screen
  (through a doorway in the far wall) to a small village square: a few houses,
  a second **stable** and the **Bat Shop**. No wild creatures are placed
  there. At the Bat Shop (F) you can upgrade your Wooden Bat (12 damage) to a
  **Spiked Bat** (22 damage) for 60 coins, and once you reach Act 2, to the
  **Chain Bat** (36 damage, wrapped in a heavy chain) for 150 coins. Every bat
  still stops creatures at 1 HP (monsters it kills). Your bat is saved.
  The Bat Shop also **buys gear**: your bag is shown under the bats; click
  items to mark them (or "Mark all") and sell them: **Normal 1 coin, Magic 3,
  Rare 8**, plus 1 coin per 20 item levels. Every item's tooltip says what it sells for.
  The lemonade stand now sits on the stretch of path just before the village.
- **Breeder (village):** press F at the pink stall with the hay pen. Pick two
  different pets **of the same kind** (from your party, reserve or stable, any level)
  and pay 25 coins: they have a **hybrid** baby, a new species that only
  comes from breeding. No cross-breeding: cats only breed with cats, birds
  with birds, dogs with dogs and lizards with lizards. Each of the 28 pairings
  (10 cat, 6 bird, 6 dog, 6 lizard) makes its own hybrid, stronger than
  either parent (20% more health and attack than the better one), bigger,
  with a horn, mane (a frill or ruff), crown or wings (leathery on lizards)
  and a powered-up ability. The parents stay with you; the baby
  (born at 75% of its parents' average level, rounded down: two level 10
  parents have a level 7 baby) joins your party, or the first free hay bed. Hybrids can't be bred
  again. The breeder also **buys pets**: press "Sell pets to the breeder",
  click the pets to sell (from your party, reserve or stable) and confirm.
  Every pet sells for **1 coin**, a **hybrid** (only bred, never caught) for
  **2**. Their collars come off first and go back in your bag.

  | Parents | Hybrid | Ability |
  |---|---|---|
  | Mossback + Emberfox | Magmashell | Magma Orb: (Fire) Lobs a ball of magma at the spot: it bursts for 2x damage and leaves a pool of fire burning for 4s. |
  | Mossback + Voltwing | Thundershell | Thunderstorm: (Lightning) A storm over the spot for 3s: 6 bolts strike enemies within 4 units, each for 1.4x damage and a short stun. |
  | Mossback + Gloomhorn | Stonehorn | Hailstorm: (Water) Six hailstones crash down around the spot, each 1.3x damage where it lands, slowing enemies for 2s. |
  | Mossback + Bloomling | Mossbloom | Gale Blades: (Air) Slicing winds fan out towards where you aim: 2.2x damage in a wide 6.5-unit cone, hurling enemies back. |
  | Emberfox + Voltwing | Blitzfox | Lightning Bolt: (Lightning) Strikes the spot with a bolt from the sky: 4x damage and a short stun around it. |
  | Emberfox + Gloomhorn | Cinderhorn | Meteor Shower: (Fire) Rains three blazing meteors around the spot, each 2.2x damage and a 1.5s stun. |
  | Emberfox + Bloomling | Sunpetal | Flame Wave: (Fire) A wave of fire rolls out towards where you aim: 2x damage in a 7-unit cone, sets enemies burning, and scorches the ground for 4s. |
  | Voltwing + Gloomhorn | Stormhorn | Thunder Chain: (Lightning) A huge bolt strikes the spot for 2.2x, then lightning jumps on to 5 more enemies. |
  | Voltwing + Bloomling | Sparkblossom | Ball Lightning: (Lightning) A crackling ball flies to the spot and bursts for 1.8x damage, then arcs on to 4 more enemies. |
  | Gloomhorn + Bloomling | Duskbloom | Void Cyclone: (Air) A dark whirlwind at the spot for 5s: pulls enemies in, slows them to 40% and tears at them. |
  | Frostfinch + Quillpuff | Glacipuff | Hail Volley: Fires 5 frozen arrows in a cone towards where you aim, each 1.3x damage and slowing to 40% for 3s. |
  | Frostfinch + Aurora Swift | Shimmerwing | Eagle Eye: A rallying cry: every pet within 6 units of the spot gets +50% crit chance for 8s (crits do double damage). |
  | Frostfinch + Snowl | Rimeowl | Snipe: A long-range shot at the enemy nearest where you aim (up to 16 units): 4.5x damage and a 1s stun. |
  | Quillpuff + Aurora Swift | Prismpuff | Prism Shot: A dazzling arrow at the spot: 2x damage there, and every enemy near it is blinded (half their attacks miss) for 4s. |
  | Quillpuff + Snowl | Quillowl | Rain of Arrows: Rains 10 arrows down over the area where you aim, each hitting what it lands near for 1.2x damage. |
  | Aurora Swift + Snowl | Dawnowl | Sunburst Arrow: A blazing arrow at the spot that explodes: 2.2x damage to everything within 3 units, setting them burning. |
  | Fangjackal + Dunehound | Duneripper | Consecration: (Heal) Hallows the ground where you aim for 6s: enemies inside burn, allies inside heal 6% of their max health every second. |
  | Fangjackal + Cactipup | Thornjackal | Judgement: (Taunt) Leaps to the spot and smites every enemy there for 2x, taunting them, then heals itself 20% and the most injured ally by the damage dealt. |
  | Fangjackal + Sunfennec | Solarjackal | Holy Light: (Heal) A flash of holy light at the spot: damages and blinds enemies there for 5s and heals every ally there for 25%. |
  | Dunehound + Cactipup | Cactihound | Shield Wall: (Shield, taunt) Throws up a wall of shields around the spot: allies there absorb 35% of their max health for 6s and enemies there are taunted onto it. |
  | Dunehound + Sunfennec | Sunhound | Sunlit Sanctuary: (Heal) A wide circle of sunlight at the spot for 7s: allies inside heal 10% of their max health every second, enemies inside are scorched. |
  | Cactipup + Sunfennec | Bloomfennec | Blessing of the Dunes: (Heal) Heals every pet and player around the spot for 40% of their max health, and the most injured of them 20% more. |
  | Bogleon + Mirelurk | Swampdrake | Swamp Fang: Yanks the enemy nearest where you aim next to it, bites for 2x and poisons it hard (120% of its damage a second for 7s). |
  | Bogleon + Wisp Gecko | Glowleon | Soul Rot: Spits rot where you aim: 2.2x damage and heavy poison for 7s, and it and you heal for 50% of the hit. |
  | Bogleon + Sporeguana | Toxileon | Toxic Haze: A toxic burst where you aim: every enemy within 6 units is poisoned for 7s and deals 50% less damage. |
  | Mirelurk + Wisp Gecko | Wraithlurk | Spirit Trap: Hides a trap where you aim (up to 4). The first enemy to step on it springs it: enemies nearby are damaged and rooted for 3.5s. They are poisoned too, for 6s. |
  | Mirelurk + Sporeguana | Mossdrake | Toxic Bog: A pool of poisonous mud at the target for 7s: everything inside is poisoned (100% of its damage a second). |
  | Wisp Gecko + Sporeguana | Sporewisp | Plague Spores: Bursts plague spores at the spot: every enemy within 6 units is poisoned for 6s, and every pet and player nearby heals 20%. |
- **Pets are animated** too, at the pace they actually move: cats and dogs
  trot (diagonal legs together) and sway or wag their tails, birds hop and flap,
  lizards paddle in a sprawl and swing their bodies and tails, winged hybrids
  flap, and everyone breathes a little standing still.
- **Loot and inventory (I):** gear drops as glowing sacks (a beam of light in
  the item's rarity colour, its name above it). **Loot is personal**: every
  player rolls their own drops and sees only theirs. Drops come from:

  | Source | Chance | At least |
  |---|---|---|
  | Wild creature or monster | 8% | |
  | Pack Alpha (the first of each pack in the open fields; a little bigger) | 35% | Magic |
  | Vase | 12% | |
  | Gold vase | 50% | Magic |
  | Champion | 2 items | the first Magic, 40% of the time Rare |
  | Named boss | 3 items | the first Rare |

  **Act 1 drops only Normal and Magic items**, so the first Rare comes in
  Act 2. **Magic find** (from gear) makes Rare drops likelier, and **bad-luck
  protection** makes the first item from a boss or Champion Rare if you've gone
  3 levels without finding one. Walk over a sack to put
  it in your **bag** (40 places): a ring and a column of light in its rarity
  colour flash around your tamer, the item's icon and name float up over your
  head (everyone sees it), and the Inventory button shows how many new items
  you have until you open it. The inventory shows your **eight gear slots**
  (weapon, chest, pants, hat, boots, two rings, a necklace) and the bag. It's all drag and drop: drag an item onto its gear slot to
  wear it (swapping with what you had on; the slots it fits light up while
  you drag), drag worn gear into the bag to take it off, drag within the bag
  to tidy it, or drop it on the bin to throw it away (it asks first). To clear
  out lots at once, press **Select** (or right-click an item), click the junk to
  mark it (or **All**, then unmark keepers), and **Throw away** with one confirm. Click an
  item to see what it does; double-click is a shortcut. The weapon slot shows your bat (upgrade it at the Bat
  Shop; bats are bought, never dropped).

  **Gear works like Diablo's:** every item is a **base type** plus rolled
  **affixes**. Its **item level** is the level of the creature that dropped
  it (vases and bosses: the area's top creature level), with no cap, so deeper
  areas drop stronger gear. Bases come in three tiers, the better ones only
  dropping from item level 21 and 51:

  | Slot | Tier 1 | Tier 2 (ilvl 21+) | Tier 3 (ilvl 51+) | Base stat |
  |---|---|---|---|---|
  | Chest | Leather Jacket | Padded Coat | Ranger's Duster | Armor and tamer health |
  | Pants | Work Trousers | Reinforced Pants | Trail Breeches | Armor |
  | Hat | Cap | Hard Hat | Warden's Hat | Tamer health |
  | Boots | Sneakers | Hiking Boots | Pathfinder Boots | Move speed |
  | Ring (x2) | Band | Signet | Seal | None (always Magic or better) |
  | Necklace | Cord | Pendant | Talisman | None (always Magic or better) |
  | Collar (pet) | Strap | Studded Collar | Runed Collar | That pet's health |

  **Rarity** sets how many affixes it rolls: **Normal** (white) none,
  **Magic** (blue) 1-2, **Rare** (yellow) 3-5 and a random name ("Grim Fang
  Talisman"), and the named **Unique** (gold) and **Set** (green) items below. A Magic item is named by its affixes ("Savage Band of the
  Leech"). Each affix rolls in a range that grows with item level, so two
  items with the same name can differ a lot:

  | Affix | Does | At ilvl 1 | At ilvl 80 | On |
  |---|---|---|---|---|
  | Savage | Pets: more damage | 3-6% | 40-60% | Any |
  | Hearty | Pets: more max health | 4-8% | 45-70% | Any |
  | of Haste | Pets: abilities recharge faster | 2-4% | 10-15% | Necklace, collar |
  | of the Leech | Pets: heal a share of the damage they deal | 1-2% | 4-6% | Ring, collar |
  | of Vigor | Tamer: more max health | 5-10 | 120-180 | All but collars |
  | Sturdy | Tamer: less damage taken (armor caps at 60%) | 2-4% | 15-20% | Chest, pants, hat, boots |
  | of Warding | Tamer and pets: less poison | 5-10% | 30-50% | Any |
  | Swift | Tamer: moves faster | 2-4% | 10-15% | Boots |
  | of Fortune | Better odds of good items | 5-10% | 30-50% | Ring, necklace, hat |
  | Gilded | More coins | 5-10% | 30-50% | Ring, necklace, hat |

  On a collar, the pet affixes help only the pet wearing it.

  **Why gear matters from Act 2:** monsters keep growing at the same rate,
  but above level 20 your pets fall behind them (a pet's level bonus is
  divided by 1 + 0.15 per level above 20). Gear makes up the difference: with
  no gear, Act 2 gets hard and Act 3 is a slog; with the gear you find, every
  act can be finished.

  **Class items:** about half the Magic and Rare rings, necklaces and collars
  are made for one class of pet (half of those for the pets of the area
  you're in). They roll that class's skill-tree stats: Wizard **Arcane**
  (ability damage, faster cooldowns, attack damage, crit chance, health),
  Paladin **Holy** (healing and shields, armor, health, faster cooldowns,
  attack damage), Archer **Keen** (crit chance, crit damage, attack speed,
  attack damage, ability damage) and Venomancer **Venomous** (poison damage,
  poison duration, toxic blood, armor, attack damage). From item level 30
  they can also roll **+1 to +3 to every skill rank** of that class ("of the
  Archmage", "of the Crusader", "of the Hawkeye", "of the Basilisk"), which
  even lifts skills past their top rank. A class ring or necklace boosts
  every party pet of its class (at three quarters of a collar's strength); a
  class collar fits only that class of pet.

  **Uniques** (gold): about 40 named, one-of-a-kind items with fixed affixes
  that roll near the top of their range for their item level, such as
  Alpha's Signet (pets: much more damage, health and life per hit),
  Fortune's Feather (magic and coin find) and Archmage's Spark (+2 to every
  cat skill rank). Better ones only drop from the higher tiers.

  **Sets** (green): four class sets of four pieces, from item level 30.
  Pieces count when worn by the tamer or, for the collar, by a party pet; the
  bonuses go to every party pet of that class:

  | Set | Pieces | 2 pieces | 4 pieces |
  |---|---|---|---|
  | Archmage's Regalia (cats) | hat, necklace, ring, collar | +20% ability damage | abilities recharge 25% faster, +20% attack damage |
  | Crusader's Oath (dogs) | jacket, pants, necklace, collar | +25% healing and shields | +30% health, 15% less damage taken |
  | Hawkeye's Gear (birds) | boots, ring, necklace, collar | +10% crit chance | +50% crit damage, attacks 15% faster |
  | Basilisk's Coils (lizards) | hat, ring, necklace, collar | +25% poison damage | poison lasts 30% longer, +50% toxic blood |

  About 1 drop in 100 is a Unique or a set piece (more with magic find), and
  each named boss has a 10% chance that its first drop is one (not in Act 1).
  Extra skill ranks from gear show in the skills window (K).

  **Item pictures:** every base item has its own full-colour picture (a Leather
  Jacket with lapels and a zip, a quilted Padded Coat, a long belted Ranger's
  Duster; a cap, a hard hat with a lamp, a feathered Warden's Hat; and so
  on), with bronze, silver or gold fittings by tier. Its gem, badge or stripe
  shows the item's main bonus (red for pet damage, green for pet health,
  cyan for cooldowns, gold for magic find...) or, on class items, the class
  colour. Uniques get a gold star and set pieces a green leaf.

  **Comparing:** a green arrow marks bag items that beat what you (or one of
  your pets) wear. Click one and the inventory shows, beside its description,
  every stat that would change if it replaced what's worn there (the weaker
  ring, or the worst collar among the pets who can wear it): gains in green,
  losses in red.

  **Stash:** every village and town has a **stash chest** in its square. Press
  F at it to open the stash (40 places) beside your bag and click items to
  move them across. The stash is saved, so it keeps gear between runs.

  Rare items drop with a tall pillar of light and a two-note chime, and
  everyone is told who found one. Items from older saves are converted
  (Common to Normal, Fine to Magic, Superior to Rare); the old legendary
  items are retired.

  **Pet gear:** the inventory's **Pets** tab (next to **Tamer**) shows your
  party pets, each with one slot, for a **collar**. Drag a collar from the bag
  onto a pet to put it on (swapping with the one it wore), back into the bag
  to take it off, or double-click a collar in the bag to put it on the first
  pet without one. A collar buffs only the pet wearing it, shows on the pet
  (everyone sees it), and stays on it in the stable and in saves; releasing a
  pet puts its collar back in your bag.

  The inventory adds it all up under your gear. Your jacket, pants, hat and
  boots show on your tamer (every hat looks different). Armor is capped at
  60%. Gear is saved.
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
- **Pets:** you can have up to 3 pets out in your party, plus **3 in reserve**
  that travel with you and can be **swapped in at any time**, even mid-fight:
  open the inventory (I) on the **Pets** tab, where the reserve sits under
  your party, and drag a reserve pet onto a party pet (or the other way). A
  pet keeps its health when swapped out and back. Party pets automatically
  defend you
  and each other. **XP is shared by your whole team:** when an enemy dies
  within 25 units of you or one of your pets, every living pet in your party
  and your reserve gets its XP, all alike (wherever it is), so they level at
  the same rate. Bosses give every living party and reserve pet XP. Pets in
  the stable don't earn XP, and neither do dead ones. Levelling is paced
  to the areas (a pet that fights its way through an area ends up around its
  top level). A pet more than 2 levels above what it beats gets less XP: 20%
  less per extra level, down to a tenth (it tells you once per area), so to
  keep levelling, move on.
- **Naming pets:** right-click a pet's portrait to give it a name (up to 16
  characters) in your party or reserve (inventory, Pets tab) or anywhere in
  the stable window (party, reserve or hay beds). Its name shows over its
  head, on its portraits, in the skill window and tooltips (with its species
  in brackets), follows it through swaps, the stable and saves, and is seen
  by everyone in multiplayer. Clear the box to call it by its species again.
- **Death:** a pet that runs out of health **dies**: it lies there, can't
  fight, can't be healed (not by potions, abilities or passive healing) and
  can't be swapped back into the party until it **rests at a stable**. Swap
  it out for a reserve pet to keep fighting. As soon as you walk up to a
  stable (at the camp or in the village), every dead pet, in your party,
  reserve or the hay beds, comes back to life and everyone is healed to full.
  Rivals' pets still get back up after 8 seconds.
- **Look:** a realistic style (`scripts/model_look.gd`), except **your own
  pets**, which pop in the anime style (`scripts/anime_look.gd`): full
  colour, cel shading, black ink outlines and big anime eyes with a bright
  iris, glint and fierce brow. A creature switches the moment it changes
  hands: caught, it turns anime; the rival's pet going wild turns realistic.
  Every other model (the tamer, wild creatures, monsters, bosses) and every wall, building, fence and obstacle
  has natural, physically based shading, colours a little less saturated, like
  real fur, hide and paint, and fine surface detail: a mottled grain in its
  colour and a bump map, so bodies read as fur or skin and walls as stone. The
  painted ground, shingles, plaster and planks get bump maps from their own
  paint. Lighting: a warm sun with soft shadows, cool sky light, ambient
  occlusion in creases and corners (desktop), a filmic tone curve, a little
  bloom on glowing things, and smoothed edges (anti-aliasing). Wild creatures'
  eyes are small and glossy (cats and lizards amber with a slit pupil); the
  tamer has a natural face. The tamer (and the rival tamer) has jointed limbs: knees and
  elbows, with a human walk (bending knees, swinging arms, a body that dips,
  twists and leans) and a batter's swing (wind-up, body turn,
  follow-through). Pet portraits and menu icons keep their drawn style.
- **Classes:** pets fight differently by kind. **Cats are Wizards**: instead
  of biting, they fire magic bolts in their own colour from about 6.5 units
  away (wild cats shoot at you too), and their ability is a spell, cast with a
  glowing magic circle. The spells are fireballs, meteors, a magma orb, a
  lightning bolt and rockfalls, plus healing, shielding and cursing spells.
  Wizards are **glass cannons**: 30% less health than other pets, but their
  spells hit 30% harder and recharge in **1.5 seconds** instead of 3.
  **Dogs are Paladins**: melee tanks that heal. They have 35% more health and
  take 15% less damage, every bite comes with a **Healing Kiss** that heals
  the most injured ally nearby (a pet or player, itself included) for 30% of
  the damage, with a pink heart floating up from them, and wild enemies go for
  a paladin first. Their abilities heal and protect, in golden light: holy
  bites, sanctuaries, taunts with guard, shields and heals.
  **Birds are Archers**: they shoot arrows from about 8.5 units (the longest
  reach of any pet), hop back when an enemy that's after them gets close (a
  short hop, then a few seconds before the next), and every ability is a
  ranged shot: frost arrows, volleys, piercing shots, arrow rain, snipes, and
  healing arrows for the support birds.
  **Lizards are Venomancers**: their damage is poison. Each bite does 70% of
  their damage up front and stacks venom on the target (40% of their damage a
  second for 4s, up to three bites' worth), anything that hits them up close
  is poisoned back (toxic blood), and every ability poisons: venom lashes and
  spit, poison clouds and pools, plague spores, and poisoned traps.
  **Tamers resist poison:** a tamer takes only a quarter of any poison or
  venom (lizards' bites and toxic blood, poison abilities and zones, the Bog
  Witch's bolts); pets and creatures take it in full.
- **Sound:** every sound is designed in code (`scripts/sound_fx.gd`) and
  saved as a ready-made file in `sounds/` (rebuild them with
  `godot --headless --path . -s res://scripts/tools/build_sounds.gd`, then
  `godot --headless --path . --import`); the game just loads the files. Each
  plays where it happens:
  - pets' regular attacks make a simple sound by class: a thump for melee
    bites, a quick "pew" for wizards' bolts, an arrow swish for archers;
  - pet abilities are louder and bigger: a rising shimmer for wizards' spells,
    a bell chord for paladins, an arrow being loosed for archers (Rain of
    Arrows has its own barrage of arrows, trimmed to last as long as the
    arrows take to land), a bubbling hiss for venomancers;
  - an item dropping goes "bing" (a rare rings two higher notes);
  - tamers' footsteps patter as they walk.
- **Glowing shots:** every ranged attack, yours and your enemies' alike
  (wizard bolts and spells, arrows, venom spit, fire imp and frost wraith
  bolts, beams), glows: a soft halo in its colour, a fading trail behind it,
  and a light that lights up the ground it flies over, so shots are easy to
  follow in a busy fight.
- **Pet abilities:** every species has a signature ability (keys 1 2 3 for
  party pets 1-3) on a **3-second cooldown** (1.5 seconds for cats; shorter with the cooldown
  skills), and every ability **lands where your
  mouse is**: the pet runs within range of that spot first, then casts. Each
  class has its own kind: **cats** cast damage spells in four elements (fire,
  lightning, air, water: fireballs, chain lightning, cyclones, tidal waves,
  thunderstorms, hail), **dogs** taunt (leaping to the spot), heal, and raise
  armor and shields, **birds** use ranger skills (arrow cones, rain of
  arrows, piercing shots, snipes, Hunter's Mark and Eagle Eye for crits) and
  **lizards** poison (venom lashes and spit, poison clouds, plague spores,
  poisoned traps).
- **Critical hits:** basic attacks can crit for double damage (shown with
  stars): archers 15% of the time, everyone else 5%. Eagle Eye adds crit
  chance to pets near the spot; Hunter's Mark makes your pets crit marked
  enemies every hit.

  | Species | Ability | Effect |
  |---|---|---|
  | Mossback | Tidal Wave | (Water) A wave crashes out towards where you aim: 2x damage to everything in a 7-unit cone, knocking them back and slowing them for 2s. |
  | Emberfox | Fireball | (Fire) Hurls a fireball at the spot you aim at: it explodes for 2.5x damage around it and sets enemies burning. |
  | Voltwing | Static Arc | (Lightning) Calls lightning down where you aim (1.8x), then it arcs on to 3 more enemies. |
  | Gloomhorn | Cyclone | (Air) A howling cyclone at the spot for 4s: enemies inside are pulled in, slowed to half speed and battered. |
  | Bloomling | Bubble Burst | (Water) A giant bubble floats to the spot and bursts: 1.8x damage around it and enemies are slowed to half speed for 3s. |
  | Frostfinch | Frost Arrow | An icy arrow at the spot: 2x damage to anything close to where it lands, slowing them to half speed for 3s. |
  | Quillpuff | Arrow Cone | Fires 7 arrows in a wide cone towards where you aim, each hitting for 1.1x damage. |
  | Aurora Swift | Hunter's Mark | Shoots a red flare at the spot: every enemy within 3.5 units is marked for 6s, and your pets crit them with every hit. |
  | Snowl | Piercing Shot | An arrow that flies 14 units towards where you aim, through every enemy in its path, 2.5x damage each. |
  | Fangjackal | Leaping Challenge | (Taunt) Leaps to the spot, bites enemies there for 1x, taunts everything within 5 units onto itself and guards (40% less damage) for 4s. |
  | Dunehound | Sanctuary | (Heal) Blesses the ground where you aim for 6s: allies inside heal 8% of their max health every second. |
  | Cactipup | Guardian's Vow | (Taunt) Leaps to the spot, taunts every enemy within 6 units onto itself, takes 50% less damage for 5s and heals itself 25%. |
  | Sunfennec | Aegis | (Armor) Raises a holy aegis over allies around the spot: pets take 35% less damage for 6s (players get a matching shield), and everyone gets a 15% shield. |
  | Bogleon | Venom Lash | Yanks the enemy nearest where you aim next to the Bogleon with its tongue, hits it for 1.2x and poisons it (90% of its damage a second for 6s). |
  | Mirelurk | Mud Trap | Hides a mud trap where you aim (up to 3). The first enemy to step on it springs it: enemies nearby are damaged and rooted for 2.5s. They are poisoned too, for 5s. |
  | Wisp Gecko | Wither | Spits withering venom where you aim: 1.5x damage, poison for 6s, and the gecko and you heal for 40% of the hit. |
  | Sporeguana | Spore Cloud | A cloud of toxic spores where you aim, for 6s: enemies inside are poisoned, and those it hits first deal 40% less damage for 6s. |
- **Pet skills (K):** every pet has a skill tree of six passive skills from its
  **class**, shown on the skills screen (press K or click "Pet skills") with an
  icon for each, and a gold paw on **pack skills**, which boost *every* pet in
  your party while that pet is awake:

  | Class | Skills (in unlock order) |
  |---|---|
  | Wizard (cats) | Arcane Focus (+8% ability damage a rank), Mana Flow (abilities recharge 6% faster), Charged Bolts (+6% attack damage), Ley Lines (pack: +3% ability damage), Spell Ward (4% less damage taken), Archmage (+12% ability damage) |
  | Paladin (dogs) | Holy Strength (+10% healing, shields and Healing Kisses), Iron Hide (4% less damage taken), Devotion (abilities recharge 6% faster), Aura of Protection (pack: 2.5% less damage taken), Vitality (+7% max health), Beacon of Light (pack: +6% healing and shields) |
  | Archer (birds) | Sharpshooter (+4% crit chance), Quick Draw (attacks 7% faster), Deadly Precision (crits +20% damage), Hunting Party (pack: +2% crit chance), Steady Aim (+6% attack damage), Volley Master (+10% ability damage) |
  | Venomancer (lizards) | Potent Venom (+8% poison damage), Thick Scales (4% less damage taken), Lingering Toxins (poison lasts 12% longer), Toxic Blood (+25% toxic blood poison), Plague Bearer (pack: +2.5% attack damage), Virulence (+12% poison damage) |

  The skills unlock left to right at levels 5, 10, 15, 20, 25 and 30, and each
  can be trained up to **4 ranks**. Pets earn a skill point at level 5 and
  every 2 levels after (13 by level 30, against 24 possible ranks), so choose:
  click a skill to spend a point on it, right-click it to take one point
  back, or press "Reset skills" to get all of a pet's points back. Both are
  free. Armor is capped at 60% and cooldowns at 50% faster. Rivals'
  pets come trained. Unspent points show as "+N" in the party panel.
- **Stable:** every level has two stables, one at the start camp and one in
  the village; both open the same stable. Press F at either to open it: your
  party sits on three cushions (numbered by their ability key), your three
  **reserve** pets below them, and up to **20 pets sleep in hay beds**.
  Everything is drag and drop:
  drag a pet from a bed onto the party to bring it along, from the party onto a
  bed to rest it, onto an occupied place to swap, between beds to rearrange,
  or between party slots to change which key (1/2/3) uses its ability. Drop a
  pet on the **release gate** (and confirm) to set it free. At the stable
  every pet is healed and dead pets come back to life. If you capture a
  creature while your party is full it joins your reserve; if that's full too
  it goes to the first free bed; if every bed is full, the capture is refused.
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
| `models/scenery/<set>_<n>.glb` | Meshy models for the scenery (trees, rocks, props). `scripts/tools/build_obstacles.gd` uses one in place of the simple shapes when it exists: as tall as the old design, keeping its collision (narrowed to the model's footprint). Before adding one, run `scripts/tools/meshy_skin/pad_texture.py in.glb out.glb` (add `--fill-grey` for foliage) to fill the grey triangles Meshy leaves unpainted and pad the texture's edges; the extracted textures import VRAM-compressed at up to 1024 px. Lava glows where a `<set>_<n>_emit.png` glow map sits beside the model (made with `scripts/tools/meshy_skin/glow_map.py model.glb out.png [--yellow]`, which keeps only the lava-coloured parts of the texture), drawn as an additive overlay that `ModelLook` leaves in place; the smoking vent also gets drifting smoke particles |
| `textures/ground/`, `scripts/ground_photo.gdshader` | Photo-scanned ground for the biome floors (CC0, sources in `textures/ground/README.txt`): a style listed in `GroundTextures.PHOTO` with `<style>_albedo/_normal/_roughness.png` here is drawn with the shader instead of painted: laid by world position, two sizes blended by slow noise so the tile never shows as a grid, with a per-style tile size, tint and bump strength. So far: grass (Greenmeadow), snow (Frostfang Peaks, Frostveil Expanse), black rock (Cinderpeak Caldera; a set may also add an `_emission.png` to glow), sand (Sunscorch Dunes, Scorchsand Ruins) and graveyard (Hollowmere Graveyard). Start camps and town squares use brick (one size only, as a regular pattern blurs if blended); boss arenas stay painted |
| `scripts/graphics.gd` | Autoload `Graphics`: the 3D resolution (pause menu: Auto draws 3D at no more than 1440p's worth of pixels and upscales it with AMD FSR, so a 4K screen renders 3D at 67%; Full is native; Performance caps at 1080p), saved in `user://settings.cfg`; menus and text stay at full resolution |
| `scripts/perf_overlay.gd` | F3: a performance overlay (frame rate, script and physics time, draw calls, creatures on screen and chasing you) that also logs to `perf_log.csv` in the game's user folder, for tracking down slowdowns |
| `scripts/save_game.gd` | Autoload `SaveGame`: save slots, autosave, and handing a save to the server to restore |
| `scripts/network.gd` | Autoload `Network`: WebSocket host/join, solo mode, player registry (names, colours) |
| `scenes/main.tscn` + `scripts/main.gd` | Menu + `LevelSpawner` that replicates the world to joining clients |
| `scenes/world.tscn` + `scripts/world.gd` | Level flow (start → rival → portal → next level), level geometry, spawners, XP sharing, FX |
| `scripts/level_generator.gd` | Deterministic layout of a level from a seed: paths are laid out unrolled, then bent along a curved centre line (1-3 curves); open fields of Acts 2-5 (`generate_open`) are a wavy rounded box with a fenced town, using the path layout's counts; rocks, creature spots, boss, exit; mapping between path space and the level |
| `scripts/boss_models.gd`, `models/rival_kael.glb`, `models/pye.glb`, `models/glacier_titan.glb`, `models/bog_witch.glb`, `scripts/tools/meshy_skin/` | The bosses' models (Rival Kael, loaded from the Meshy model, with the old code-built rival kept as a fallback, Glacier Titan (a Meshy model, with a code-built fallback), Sand Wyrm (a Meshy model rigged in code, with a code-built fallback), Bog Witch (a Meshy model, with a code-built fallback), Howard the Zombie Fish (a Meshy model, with a code-built fallback), Sand Pharaoh, Sunmane the Desert Lion, Magma Colossus and Yeti King (unused for now), Dom the House Cat (a Meshy model rigged by script, with a code-built fallback), Koleko the Fire Dog (a Meshy model rigged by script, with a code-built fallback), Pye the Parrot (a Meshy model, with the code-built parrot as a fallback)) and what animates |
| `scripts/biome_db.gd` | The biomes levels cycle through: their creatures, boss and colours, and the 16-level cycle of acts (which levels end with a named boss or a Champion) |
| `scenes/rival.tscn` + `scripts/rival.gd` | The AI rival tamer boss (and the base class for every boss) |
| `scenes/titan.tscn` + `scripts/titan.gd` | The Glacier Titan boss: Avalanche and Frostfinch summons |
| `scenes/sand_wyrm.tscn` + `scripts/sand_wyrm.gd` | The Sand Wyrm boss: burrow, erupt, sandstorms |
| `scenes/bog_witch.tscn` + `scripts/bog_witch.gd` | The Bog Witch boss: poison bolts, blink, toxic puddles, Bogleon summons |
| `scenes/player.tscn` + `scripts/player.gd` | Movement, aim, and server-validated attack/capture/command requests |
| `scenes/creature.tscn` + `scripts/creature.gd` | One scene for wild creatures *and* pets: wild AI, pet AI, taming, levelling |
| `scripts/pet_skills.gd` | The four class skill trees, skill points and ranks, and how they add up |
| `scripts/level_generator.gd` (village) + `World._build_village` | The village side path, square, houses and bat shop |
| `scripts/breeding_db.gd`, `scripts/breeder_window.gd` | Which pairs breed into which hybrid, the rules, and the breeder's window |
| `scripts/person_model.gd` | The tamer's body, bat, walk cycle and bat swing, built from simple meshes |
| `scripts/creature_animator.gd` | Pet animations (walk, tails, wings, breathing), driven by how fast each pet moves |
| `scripts/pause_menu.gd` | The in-game menu on Esc: resume, save, quit to the main menu |
| `scripts/ui_theme.gd` → `resources/ui_theme.tres`, `scripts/ui_icons.gd` | The menus' look (dark panels, gold borders, light text) and their line icons (small SVGs drawn at runtime). Rebuild the theme file with `godot --headless --path . -s res://scripts/tools/build_ui_theme.gd` |
| `scripts/ground_textures.gd` | The ground textures, painted in code per biome: grass, snow and ice, sand ripples, swamp mud and puddles, graveyard soil, volcanic basalt with glowing lava cracks, plus camp dirt, arena flagstones and village cobblestones |
| `scripts/building_textures.gd` | The buildings' shared textures, painted in code: clay shingle roofs, plaster walls, plank doors (and stall woodwork) |
| `scenes/obstacles/*.tscn` (built by `scripts/tools/build_obstacles.gd`) | Four premade trees and rocks per biome (meadow: oak, pine, mossy boulder, berry bush; frost: frosted white spruce, ice crystals, snow boulder, frozen tree; desert: cactus, sandstone pillar, palm, boulders; swamp: willow, vine tree, mossy rock, old stump; graveyard: headstones, dead tree, crypt, grave cross; volcano: lava spire, charred tree, obsidian shards, smoking vent). Areas can name their set, so the Act 3 desert and Act 5 ice areas reuse the desert and frost sets, placed turned and sized differently from the level seed. Rebuild with `godot --headless --path . -s res://scripts/tools/build_obstacles.gd` |
| `scripts/item_db.gd`, `scripts/item_icons.gd`, `scripts/inventory_window.gd`, `scripts/loot.gd` | Gear (items: base types and tiers, item level, rarities, affixes and their ranges, class items, converting old saves), the inventory window (I: the Tamer tab, and the Pets tab with collars and the reserve) and loot sacks on the ground |
| `scripts/mini_map.gd` | The mini map (and the large map, M), drawn from the level layout, with fog of war on open fields |
| `scripts/skill_window.gd`, `scripts/skill_icons.gd` | The skills screen (K) and its skill icons, drawn in code |
| `scripts/creature_model.gd` | Builds each creature's body from simple meshes: a cat, bird, dog or lizard, depending on its biome, or a monster (skeleton, zombie, mummy, sand scorpion, fire imp, magma golem, frost wraith, yeti) |
| `scripts/creature_species.gd`, `resources/species/*.tres`, `scripts/species_db.gd` | Species data. Add a `.tres` and list it in `SpeciesDB` to add a species |
| `scripts/combat.gd` | Faction rule (`Combat.are_enemies`) that enforces no friendly fire |
| `scripts/abilities/*.gd`, `resources/abilities/*.tres` | `PetAbility` base class and one subclass per ability; tune values in the `.tres` files |
| `scenes/crate.tscn` + `scripts/crate.gd`, `scenes/coin.tscn` + `scripts/coin.gd` | Breakable vases (still called crates in the code) and the coins they spill |
| `scripts/components/health.gd` | Health with setter-driven signals (works with replication), plus poison and damage-absorbing shields |
| `scripts/pet_slot.gd` | A drag-and-drop place in the stable window (hay bed, party cushion, reserve place or release gate), drawn in code |
| `scenes/hud.tscn` + `scripts/hud.gd` | The HUD: objective, hover/capture info, message feed, windows |
| `scripts/sound_fx.gd`, `sounds/*.wav` (built by `scripts/tools/build_sounds.gd`, except the recorded `arrow_*.wav`) | The sound effects (attacks, abilities, item drops, footsteps): designed in code, saved as .wav files, played positionally |
| `scripts/action_bar.gd`, `scripts/action_slot.gd`, `scripts/health_orb.gd` | The action bar along the bottom (health, potion, capture, bat, the three pets, stance and coins) and the tiny inventory, skills and menu buttons under the mini map; each box draws its icon or portrait, key, cooldown sweep, badges and strips |

Physics layers: 1 world · 2 players · 3 hostiles (wild creatures, bosses, rival pets) · 4 player pets.

## Suggested next steps
1. **More for the vendor to sell:** pet treats (XP), revive items or cosmetics.
2. **Wild abilities:** let wild creatures use their species ability too (rival pets already do).
3. **More abilities per pet:** e.g. a second ability unlocked at level 5, or abilities learned from items.
4. **Smoother networking:** interpolate remote players and creatures, which currently snap to each replicated position.
5. **Real art:** replace the placeholder meshes with glTF models and an `AnimationTree`.
6. **Level variety:** more biomes, side branches with treasure, and rival tamers with more pets on later levels.
7. **Pathfinding:** a `NavigationRegion3D` with a `NavigationAgent3D` on each creature, so they route around rocks.
