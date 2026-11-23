class_name LegendaryDB
## The loot table's top end, Diablo III style:
##
## - Legendary items (orange): 8 for each 5-level band of item levels, from
##   21-25 up to 76-80 (one band per area, Act 2 onwards): one for each of the
##   tamer's slots (a bat, a jacket, pants, a hat, boots, two rings and a
##   necklace). Each has fixed stats that roll near the top of their range,
##   one extra random stat, and a legendary power (POWERS), whose strength
##   grows with the band and rolls 85-100% of that band's value.
## - Set items (green): two six-piece sets for each class of pet, dropping
##   only in the last act of each cycle (Act 5, then Act 10...). Pieces worn
##   by the tamer count up to bonuses for that class's pets at 2, 4 and 6
##   pieces; the 6-piece bonus adds a big power of its own.
##
## Items are made by ItemDB (make_legendary, make_set_piece); a worn item's
## power is gathered by gather() and used through the hooks at the bottom
## (Creature.skill_bonus, receive_damage, Player...).

const FIRST_ILVL := 21  ## The first band's lowest item level.
const BAND_SIZE := 5
const BANDS := 12  ## 21-25, 26-30, ... 76-80.
## Drop odds: each item that drops at item level 21+ is a Legendary this often
## (x magic find). About 11 items drop over an area (packs, Alphas, vases, the
## Champion or boss), so a band gives about 0.8 Legendaries a run: none about
## 45% of the time, one 37%, two or more 18% (a little more where a named boss
## drops 3 items). Bosses' and Champions' drops are likelier. Tune with
## scripts/tools/dropsim.gd when areas get more content.
const LEGENDARY_CHANCE := 0.06
const BOSS_LEGENDARY_CHANCE := 0.12
## In the last act of a cycle, each item that drops is a set piece this often.
const SET_CHANCE := 0.07
## A set piece is for one of the classes in your party this often (smart loot).
const SMART_SET_SHARE := 0.6

## The legendary powers. `text`: what it does ("%d" = its value; {Pets} and
## {pets} read "Your cats" / "cats" on a class set's bonus); `range`: its value
## in the first band and in the last.
const POWERS := {
	# Pets' strength, by circumstance (Creature.skill_bonus).
	"pack_might": {"text": "{Pets} deal +%d%% damage for each pet in your party", "range": [4, 12]},
	"kin_bond": {"text": "{Pets} deal +%d%% damage for each pet family in your party", "range": [5, 15]},
	"heel": {"text": "{Pets} within 10 units of you take %d%% less damage", "range": [8, 20]},
	"hunt_far": {"text": "{Pets} more than 10 units from you deal +%d%% damage", "range": [12, 36]},
	"vigor": {"text": "{Pets} above 80%% health deal +%d%% damage", "range": [12, 36]},
	"last_stand": {"text": "{Pets} below 35%% health take %d%% less damage", "range": [15, 35]},
	"quicken": {"text": "{Pets}: abilities recharge %d%% faster", "range": [8, 20]},
	"arcane_flow": {"text": "{Pets}: +%d%% ability damage, healing and shields", "range": [12, 40]},
	"keen_eye": {"text": "{Pets}: +%d%% critical hit chance", "range": [4, 12]},
	"venom_lore": {"text": "{Pets}: +%d%% poison and burn damage, and they last that much longer", "range": [15, 45]},
	# Pets' hits, by who they hit (Creature/Rival.receive_damage).
	"executioner": {"text": "{Pets} deal +%d%% damage to enemies below 30%% health", "range": [20, 60]},
	"first_strike": {"text": "{Pets} deal +%d%% damage to enemies above 90%% health", "range": [20, 60]},
	"giant_slayer": {"text": "{Pets} deal +%d%% damage to Champions, pack Alphas and bosses", "range": [15, 45]},
	"bully": {"text": "{Pets} deal +%d%% damage to poisoned or stunned enemies", "range": [15, 45]},
	# Kills.
	"feast": {"text": "When {pets} kill an enemy, all your pets heal %d%% of their max health", "range": [3, 8]},
	"corpse_blast": {"text": "Enemies {pets} kill explode, dealing %d%% of their max health to enemies nearby", "range": [10, 30]},
	"rush": {"text": "After you or your pets kill an enemy, you move %d%% faster for 4 seconds", "range": [15, 35]},
	"siphon": {"text": "When you or your pets kill an enemy, you heal %d%% of your max health", "range": [2, 6]},
	# The tamer.
	"thorns": {"text": "Enemies that hit you take %d%% of the damage back", "range": [30, 100]},
	"evasion": {"text": "%d%% chance to dodge an attack", "range": [6, 15]},
	"second_wind": {"text": "Dropping below 30%% health shields you for %d%% of your max health (once a minute)", "range": [30, 60]},
	"regrowth": {"text": "Heal %d%% of your max health every 5 seconds", "range": [3, 8]},
	# The bat.
	"heavy_swing": {"text": "Bat hits have a %d%% chance to stun for 1.5 seconds", "range": [15, 35]},
	"chain_swing": {"text": "Bat hits arc to 2 more enemies nearby for %d%% of the damage", "range": [40, 100]},
	"rally": {"text": "Bat hits rouse your pets: +%d%% damage for 5 seconds", "range": [10, 30]},
	"leech_swing": {"text": "Bat hits heal you and your pets for %d%% of the damage", "range": [20, 50]},
	# Taming and finding.
	"charmer": {"text": "+%d%% capture chance", "range": [8, 20]},
	"mentor": {"text": "Pets gain %d%% more experience", "range": [10, 30]},
	"fortune": {"text": "%d%% better odds of good items (Legendaries too)", "range": [20, 50]},
	"greed": {"text": "%d%% more coins", "range": [30, 80]},
}
## Powers that are plain tamer stats (added by ItemDB.stats, so they count in
## totals, tooltips and comparisons like any other stat).
const STAT_POWERS := {"fortune": "magic_find", "greed": "coin_find"}

## The fixed stats of a legendary, by its type: {affix: multiplier of the top
## of its range} (plus one random affix when it's made).
const AFFIXES := {
	"bat": {"pet_damage": 1.2, "health": 1.0},
	"jacket": {"armor": 1.2, "health": 1.2, "pet_health": 1.1},
	"pants": {"armor": 1.2, "health": 1.1, "poison_resist": 1.0},
	"hat": {"health": 1.2, "pet_damage": 1.1, "magic_find": 1.0},
	"boots": {"speed": 1.2, "health": 1.0, "armor": 1.0},
	"ring": {"pet_damage": 1.3, "life_hit": 1.1},
	"necklace": {"pet_damage": 1.2, "pet_health": 1.2, "cooldown": 1.0},
}

## Every legendary: id: [name, type, band (0 = item level 21-25), power].
## Each band is themed on the area it drops in.
const LEGENDARIES := {
	# Band 0 · Lv 21-25 · Hollowmere Graveyard (Act 2, area 1)
	"gravediggers_spade": ["Gravedigger's Spade", "bat", 0, "heavy_swing"],
	"shroud_of_the_restless": ["Shroud of the Restless", "jacket", 0, "second_wind"],
	"mourners_leggings": ["Mourner's Leggings", "pants", 0, "last_stand"],
	"sextons_lantern_hat": ["Sexton's Lantern Hat", "hat", 0, "charmer"],
	"cryptwalkers": ["Cryptwalkers", "boots", 0, "rush"],
	"ring_of_the_pale_hand": ["Ring of the Pale Hand", "ring", 0, "executioner"],
	"bonebound_band": ["Bonebound Band", "ring", 0, "feast"],
	"lantern_of_lost_souls": ["Lantern of Lost Souls", "necklace", 0, "quicken"],
	# Band 1 · Lv 26-30 · Hollowmere Graveyard (area 2)
	"tombstone_mallet": ["Tombstone Mallet", "bat", 1, "rally"],
	"ossuary_vest": ["Ossuary Vest", "jacket", 1, "thorns"],
	"grave_moss_trousers": ["Grave-Moss Trousers", "pants", 1, "regrowth"],
	"crown_of_withered_roses": ["Crown of Withered Roses", "hat", 1, "mentor"],
	"mistwalker_boots": ["Mistwalker Boots", "boots", 1, "evasion"],
	"coffin_nail_ring": ["Coffin Nail Ring", "ring", 1, "first_strike"],
	"seal_of_the_ninth_bell": ["Seal of the Ninth Bell", "ring", 1, "pack_might"],
	"reliquary_of_whispers": ["Reliquary of Whispers", "necklace", 1, "arcane_flow"],
	# Band 2 · Lv 31-35 · Hollowmere Graveyard (area 3, Howard the Zombie Fish)
	"howards_fishbone_club": ["Howard's Fishbone Club", "bat", 2, "leech_swing"],
	"drowned_captains_coat": ["Drowned Captain's Coat", "jacket", 2, "heel"],
	"bogwater_waders": ["Bogwater Waders", "pants", 2, "thorns"],
	"gill_hood_of_the_deep": ["Gill-Hood of the Deep", "hat", 2, "fortune"],
	"barnacle_boots": ["Barnacle Boots", "boots", 2, "siphon"],
	"hook_of_the_deep": ["Hook of the Deep", "ring", 2, "giant_slayer"],
	"ring_of_rotting_tides": ["Ring of Rotting Tides", "ring", 2, "bully"],
	"pearl_of_the_restless_dead": ["Pearl of the Restless Dead", "necklace", 2, "kin_bond"],
	# Band 3 · Lv 36-40 · Scorchsand Ruins (Act 3, area 1)
	"sandstorm_cudgel": ["Sandstorm Cudgel", "bat", 3, "chain_swing"],
	"sunbaked_cuirass": ["Sunbaked Cuirass", "jacket", 3, "evasion"],
	"dune_strider_breeches": ["Dune Strider Breeches", "pants", 3, "heel"],
	"pharaohs_sun_crown": ["Pharaoh's Sun Crown", "hat", 3, "arcane_flow"],
	"scarab_shell_sandals": ["Scarab-Shell Sandals", "boots", 3, "rush"],
	"eye_of_the_scorpion": ["Eye of the Scorpion", "ring", 3, "venom_lore"],
	"ring_of_endless_sands": ["Ring of Endless Sands", "ring", 3, "vigor"],
	"ankh_of_ten_lives": ["Ankh of Ten Lives", "necklace", 3, "feast"],
	# Band 4 · Lv 41-45 · Scorchsand Ruins (area 2)
	"tomb_kings_scepter": ["Tomb King's Scepter", "bat", 4, "heavy_swing"],
	"wrappings_of_the_embalmed": ["Wrappings of the Embalmed", "jacket", 4, "regrowth"],
	"sandscoured_greaves": ["Sandscoured Greaves", "pants", 4, "last_stand"],
	"mask_of_the_jackal_god": ["Mask of the Jackal God", "hat", 4, "charmer"],
	"mirage_steppers": ["Mirage Steppers", "boots", 4, "hunt_far"],
	"signet_of_the_vizier": ["Signet of the Vizier", "ring", 4, "executioner"],
	"sunstone_loop": ["Sunstone Loop", "ring", 4, "keen_eye"],
	"scarab_of_rebirth": ["Scarab of Rebirth", "necklace", 4, "corpse_blast"],
	# Band 5 · Lv 46-50 · Scorchsand Ruins (area 3)
	"obelisk_shard": ["Obelisk Shard", "bat", 5, "rally"],
	"sandwyrm_scale_coat": ["Sandwyrm Scale Coat", "jacket", 5, "thorns"],
	"caravan_masters_pants": ["Caravan Master's Pants", "pants", 5, "greed"],
	"desert_seers_turban": ["Desert Seer's Turban", "hat", 5, "mentor"],
	"sidewinder_boots": ["Sidewinder Boots", "boots", 5, "evasion"],
	"wyrmtooth_ring": ["Wyrmtooth Ring", "ring", 5, "giant_slayer"],
	"band_of_the_burning_sun": ["Band of the Burning Sun", "ring", 5, "first_strike"],
	"hourglass_of_the_ancients": ["Hourglass of the Ancients", "necklace", 5, "quicken"],
	# Band 6 · Lv 51-55 · Cinderpeak Caldera (Act 4, area 1)
	"magma_forged_bat": ["Magma-Forged Bat", "bat", 6, "chain_swing"],
	"ashen_guardplate": ["Ashen Guardplate", "jacket", 6, "second_wind"],
	"cinderwalker_legguards": ["Cinderwalker Legguards", "pants", 6, "regrowth"],
	"helm_of_the_ember_lord": ["Helm of the Ember Lord", "hat", 6, "keen_eye"],
	"lavastep_boots": ["Lavastep Boots", "boots", 6, "rush"],
	"ring_of_smouldering_wrath": ["Ring of Smouldering Wrath", "ring", 6, "bully"],
	"obsidian_coil": ["Obsidian Coil", "ring", 6, "pack_might"],
	"heart_of_the_volcano": ["Heart of the Volcano", "necklace", 6, "arcane_flow"],
	# Band 7 · Lv 56-60 · Cinderpeak Caldera (area 2)
	"fireborn_bat": ["Fireborn Bat", "bat", 7, "leech_swing"],
	"salamander_hide": ["Salamander Hide", "jacket", 7, "heel"],
	"pyreclad_greaves": ["Pyreclad Greaves", "pants", 7, "thorns"],
	"crown_of_cinders": ["Crown of Cinders", "hat", 7, "fortune"],
	"ashwalker_treads": ["Ashwalker Treads", "boots", 7, "hunt_far"],
	"flamebrand_signet": ["Flamebrand Signet", "ring", 7, "executioner"],
	"ember_of_kinship": ["Ember of Kinship", "ring", 7, "kin_bond"],
	"phoenix_feather_charm": ["Phoenix Feather Charm", "necklace", 7, "feast"],
	# Band 8 · Lv 61-65 · Cinderpeak Caldera (area 3)
	"calderas_wrath": ["Caldera's Wrath", "bat", 8, "heavy_swing"],
	"molten_core_plate": ["Molten Core Plate", "jacket", 8, "evasion"],
	"brimstone_breeches": ["Brimstone Breeches", "pants", 8, "last_stand"],
	"titans_ash_helm": ["Titan's Ash Helm", "hat", 8, "charmer"],
	"firestorm_striders": ["Firestorm Striders", "boots", 8, "siphon"],
	"ring_of_the_erupting_peak": ["Ring of the Erupting Peak", "ring", 8, "corpse_blast"],
	"scorched_seal": ["Scorched Seal", "ring", 8, "vigor"],
	"eye_of_the_inferno": ["Eye of the Inferno", "necklace", 8, "venom_lore"],
	# Band 9 · Lv 66-70 · Frostveil Expanse (Act 5, area 1)
	"glacierbreaker": ["Glacierbreaker", "bat", 9, "chain_swing"],
	"frostbound_mantle": ["Frostbound Mantle", "jacket", 9, "second_wind"],
	"rimewoven_leggings": ["Rimewoven Leggings", "pants", 9, "heel"],
	"crown_of_winters_edge": ["Crown of Winter's Edge", "hat", 9, "mentor"],
	"snowdrift_treads": ["Snowdrift Treads", "boots", 9, "evasion"],
	"band_of_endless_winter": ["Band of Endless Winter", "ring", 9, "first_strike"],
	"frostfang_loop": ["Frostfang Loop", "ring", 9, "giant_slayer"],
	"shard_of_the_aurora": ["Shard of the Aurora", "necklace", 9, "quicken"],
	# Band 10 · Lv 71-75 · Frostveil Expanse (area 2)
	"hailstorm_basher": ["Hailstorm Basher", "bat", 10, "rally"],
	"yeti_fur_greatcoat": ["Yeti-Fur Greatcoat", "jacket", 10, "regrowth"],
	"icewalker_greaves": ["Icewalker Greaves", "pants", 10, "thorns"],
	"helm_of_the_northern_lights": ["Helm of the Northern Lights", "hat", 10, "arcane_flow"],
	"avalanche_boots": ["Avalanche Boots", "boots", 10, "rush"],
	"ring_of_the_frozen_heart": ["Ring of the Frozen Heart", "ring", 10, "executioner"],
	"pack_alphas_signet": ["Pack Alpha's Signet", "ring", 10, "pack_might"],
	"locket_of_the_eternal_pack": ["Locket of the Eternal Pack", "necklace", 10, "kin_bond"],
	# Band 11 · Lv 76-80 · Frostveil Expanse (area 3)
	"worldsplitter": ["Worldsplitter", "bat", 11, "leech_swing"],
	"aegis_of_the_pack_leader": ["Aegis of the Pack Leader", "jacket", 11, "heel"],
	"legplates_of_the_last_stand": ["Legplates of the Last Stand", "pants", 11, "last_stand"],
	"crown_of_the_beastmaster": ["Crown of the Beastmaster", "hat", 11, "charmer"],
	"boots_of_the_endless_hunt": ["Boots of the Endless Hunt", "boots", 11, "hunt_far"],
	"ring_of_a_thousand_hunts": ["Ring of a Thousand Hunts", "ring", 11, "corpse_blast"],
	"alphas_promise": ["Alpha's Promise", "ring", 11, "feast"],
	"heart_of_the_wild": ["Heart of the Wild", "necklace", 11, "keen_eye"],
}

## The class sets: two per class of pet, six pieces each. A set with a bat
## and a necklace leaves both ring slots free; one with two rings leaves the
## bat and necklace slots free. `main` / `second`: the class stats its pieces
## roll; `bonus`: {pieces worn: {skill-tree stat: percent}} for that class's
## pets; `power`: [kind, value], the 6-piece bonus's power, for that class's pets.
const SETS := {
	"starweaver": {"name": "Starweaver's Regalia", "class": "wizard", "main": "spell_power", "second": "cooldown",
		"bonus": {2: {"spell_power": 25}, 4: {"cooldown": 20}, 6: {"spell_power": 100}}, "power": ["corpse_blast", 45],
		"pieces": {
			"starweaver_bat": ["Starweaver's Comet Bat", "bat"],
			"starweaver_robe": ["Starweaver's Robe", "jacket"],
			"starweaver_leggings": ["Starweaver's Leggings", "pants"],
			"starweaver_cowl": ["Starweaver's Cowl", "hat"],
			"starweaver_slippers": ["Starweaver's Slippers", "boots"],
			"starweaver_astrolabe": ["Starweaver's Astrolabe", "necklace"],
		}},
	"stormcaller": {"name": "Stormcaller's Vestments", "class": "wizard", "main": "crit_chance", "second": "damage",
		"bonus": {2: {"crit_chance": 10}, 4: {"crit_damage": 60}, 6: {"damage": 80}}, "power": ["executioner", 90],
		"pieces": {
			"stormcaller_mantle": ["Stormcaller's Mantle", "jacket"],
			"stormcaller_kilt": ["Stormcaller's Kilt", "pants"],
			"stormcaller_crown": ["Stormcaller's Crown", "hat"],
			"stormcaller_striders": ["Stormcaller's Striders", "boots"],
			"stormcaller_seal": ["Stormcaller's Seal", "ring"],
			"stormcaller_band": ["Stormcaller's Thunder Band", "ring"],
		}},
	"oathkeeper": {"name": "Oathkeeper's Armor", "class": "paladin", "main": "heal_power", "second": "health",
		"bonus": {2: {"heal_power": 30}, 4: {"health": 30}, 6: {"heal_power": 100}}, "power": ["feast", 12],
		"pieces": {
			"oathkeeper_warbat": ["Oathkeeper's Warbat", "bat"],
			"oathkeeper_tabard": ["Oathkeeper's Tabard", "jacket"],
			"oathkeeper_greaves": ["Oathkeeper's Greaves", "pants"],
			"oathkeeper_helm": ["Oathkeeper's Helm", "hat"],
			"oathkeeper_sabatons": ["Oathkeeper's Sabatons", "boots"],
			"oathkeeper_symbol": ["Oathkeeper's Holy Symbol", "necklace"],
		}},
	"bulwark": {"name": "Bulwark of the Pack", "class": "paladin", "main": "armor", "second": "damage",
		"bonus": {2: {"armor": 12}, 4: {"health": 40}, 6: {"damage": 70}}, "power": ["giant_slayer", 70],
		"pieces": {
			"bulwark_plate": ["Bulwark Plate", "jacket"],
			"bulwark_legguards": ["Bulwark Legguards", "pants"],
			"bulwark_greathelm": ["Bulwark Greathelm", "hat"],
			"bulwark_ironshods": ["Bulwark Ironshods", "boots"],
			"bulwark_signet": ["Bulwark Signet", "ring"],
			"bulwark_band": ["Bulwark Band of Valor", "ring"],
		}},
	"skyhunter": {"name": "Skyhunter's Plumage", "class": "archer", "main": "crit_damage", "second": "crit_chance",
		"bonus": {2: {"crit_chance": 10}, 4: {"attack_speed": 20}, 6: {"crit_damage": 150}}, "power": ["first_strike", 90],
		"pieces": {
			"skyhunter_bat": ["Skyhunter's Talon Bat", "bat"],
			"skyhunter_vest": ["Skyhunter's Feathered Vest", "jacket"],
			"skyhunter_breeches": ["Skyhunter's Breeches", "pants"],
			"skyhunter_hood": ["Skyhunter's Falcon Hood", "hat"],
			"skyhunter_windboots": ["Skyhunter's Windboots", "boots"],
			"skyhunter_whistle": ["Skyhunter's Whistle", "necklace"],
		}},
	"windrider": {"name": "Windrider's Trappings", "class": "archer", "main": "attack_speed", "second": "damage",
		"bonus": {2: {"attack_speed": 15}, 4: {"damage": 30}, 6: {"damage": 80}}, "power": ["hunt_far", 55],
		"pieces": {
			"windrider_coat": ["Windrider's Coat", "jacket"],
			"windrider_trousers": ["Windrider's Trousers", "pants"],
			"windrider_goggles": ["Windrider's Goggles", "hat"],
			"windrider_gale_boots": ["Windrider's Gale Boots", "boots"],
			"windrider_loop": ["Windrider's Loop", "ring"],
			"windrider_feather_ring": ["Windrider's Feather Ring", "ring"],
		}},
	"basilisk_queen": {"name": "Coils of the Basilisk Queen", "class": "venomancer", "main": "dot_power", "second": "dot_duration",
		"bonus": {2: {"dot_power": 30}, 4: {"dot_duration": 30}, 6: {"dot_power": 120}}, "power": ["bully", 70],
		"pieces": {
			"basilisk_queen_bat": ["Basilisk Queen's Fang Bat", "bat"],
			"basilisk_queen_scalemail": ["Basilisk Queen's Scalemail", "jacket"],
			"basilisk_queen_coils": ["Basilisk Queen's Coils", "pants"],
			"basilisk_queen_crest": ["Basilisk Queen's Crest", "hat"],
			"basilisk_queen_slithers": ["Basilisk Queen's Slithers", "boots"],
			"basilisk_queen_venom_sac": ["Basilisk Queen's Venom Sac", "necklace"],
		}},
	"plaguebringer": {"name": "Plaguebringer's Garb", "class": "venomancer", "main": "toxic_blood", "second": "armor",
		"bonus": {2: {"toxic_blood": 50}, 4: {"armor": 12}, 6: {"toxic_blood": 150, "damage": 40}}, "power": ["corpse_blast", 45],
		"pieces": {
			"plaguebringer_shroud": ["Plaguebringer's Shroud", "jacket"],
			"plaguebringer_wraps": ["Plaguebringer's Wraps", "pants"],
			"plaguebringer_mask": ["Plaguebringer's Mask", "hat"],
			"plaguebringer_bog_boots": ["Plaguebringer's Bog Boots", "boots"],
			"plaguebringer_seal": ["Plaguebringer's Seal", "ring"],
			"plaguebringer_rot_band": ["Plaguebringer's Rot Band", "ring"],
		}},
}


# --- The table -----------------------------------------------------------------------

## The band an item level falls in (0 = 21-25), or -1 below the first.
static func band_of(ilvl: int) -> int:
	if ilvl < FIRST_ILVL:
		return -1
	return mini((ilvl - FIRST_ILVL) / BAND_SIZE, BANDS - 1)


## "21-25" for a band.
static func band_levels(band: int) -> String:
	var low := FIRST_ILVL + band * BAND_SIZE
	return "%d-%d" % [low, low + BAND_SIZE - 1]


## Every legendary of a band (ids).
static func in_band(band: int) -> Array:
	return LEGENDARIES.keys().filter(func(id: String) -> bool: return LEGENDARIES[id][2] == band)


## A power's full value in a band (the best roll).
static func power_value(kind: String, band: int) -> int:
	var r: Array = POWERS[kind].range
	return roundi(lerpf(r[0], r[1], clampf(band / float(BANDS - 1), 0.0, 1.0)))


## A power's words with its value; `pet_class` ("" = all pets) names whose pets it's for.
static func power_text(kind: String, value: int, pet_class := "") -> String:
	if not POWERS.has(kind):
		return ""
	var pets := "pets"
	if ItemDB.PET_GEAR.has(pet_class):
		pets = ItemDB.PET_GEAR[pet_class].pets
	var text: String = POWERS[kind].text % value
	return text.replace("{Pets}", ("Your " + pets) if pets != "pets" else "Pets").replace("{pets}", ("your " + pets) if pets != "pets" else "your pets")


## True if the last act of a cycle (Act 5, 10...): where set items drop.
static func sets_drop_in(level_number: int) -> bool:
	if level_number <= BiomeDB.CROSSROADS:
		return false
	var act: int = BiomeDB.act_of(level_number).act
	return (act - 1) % BiomeDB.ACT_LEVELS.size() == BiomeDB.ACT_LEVELS.size() - 1


## The set a piece belongs to ("" if none).
static func set_of_piece(piece: String) -> String:
	for set_id: String in SETS:
		if SETS[set_id].pieces.has(piece):
			return set_id
	return ""


## How many of a set's pieces are worn (each piece once).
static func pieces_worn(set_id: String, equipment: Dictionary) -> int:
	var worn := {}
	for item in equipment.values():
		if item is Dictionary and item.get("set", "") == set_id and int(item.get("rarity", 0)) == ItemDB.SET:
			worn[item.get("unique", "")] = true
	return worn.size()


# --- Powers in play ------------------------------------------------------------------

## Every power a tamer's worn gear gives: {kind: [[value, pet_class], ...]}
## (pet_class "" = all pets): each legendary's power, and each class set's
## 6-piece power when all six are worn.
static func gather(equipment: Dictionary) -> Dictionary:
	var out := {}
	for item in equipment.values():
		if item is Dictionary and int(item.get("rarity", 0)) == ItemDB.UNIQUE and LEGENDARIES.has(item.get("unique", "")):
			var kind: String = LEGENDARIES[item.unique][3]
			if not out.has(kind):
				out[kind] = []
			out[kind].append([int(item.get("power", 0)), ""])
	for set_id: String in SETS:
		if pieces_worn(set_id, equipment) >= 6:
			var p: Array = SETS[set_id].power
			if not out.has(p[0]):
				out[p[0]] = []
			out[p[0]].append([int(p[1]), SETS[set_id]["class"]])
	return out


## The total of power `kind` (its values added up) that applies to a pet of
## `pet_class` ("" = only powers for all pets, e.g. the tamer's own).
static func amount(powers: Dictionary, kind: String, pet_class := "") -> float:
	var sum := 0.0
	for entry: Array in powers.get(kind, []):
		if entry[1] == "" or entry[1] == pet_class:
			sum += float(entry[0])
	return sum


## The powers of a pet's tamer ({} for wild creatures and rival pets).
static func of_pet(pet: Node) -> Dictionary:
	if not (pet is Creature) or not pet.is_player_pet() or pet.world == null:
		return {}
	var tamer: Player = pet.world.get_player(pet.owner_id)
	return tamer.legend_powers() if tamer else {}


## Creature.skill_bonus: what the tamer's powers add to a pet's `stat` (a
## fraction, like skill_bonus), by the pet's circumstances right now.
static func pet_stat(pet: Creature, stat: String) -> float:
	var powers := of_pet(pet)
	if powers.is_empty():
		return 0.0
	var cls := pet.species.pet_class()
	var tamer: Player = pet.world.get_player(pet.owner_id)
	var pct := 0.0
	match stat:
		"damage":
			var party: Array = pet.world.get_pets(pet.owner_id).filter(func(p: Creature) -> bool: return not p.fainted)
			pct += amount(powers, "pack_might", cls) * party.size()
			var families := {}
			for p: Creature in party:
				families[p.species.pet_class()] = true
			pct += amount(powers, "kin_bond", cls) * families.size()
			if tamer and pet.global_position.distance_to(tamer.global_position) > 10.0:
				pct += amount(powers, "hunt_far", cls)
			if pet.health.fraction() > 0.8:
				pct += amount(powers, "vigor", cls)
			if tamer and tamer.rally_left() > 0.0:
				pct += tamer.rally_amount()
		"armor":
			if tamer and pet.global_position.distance_to(tamer.global_position) <= 10.0:
				pct += amount(powers, "heel", cls)
			if pet.health.fraction() < 0.35:
				pct += amount(powers, "last_stand", cls)
		"cooldown":
			pct += amount(powers, "quicken", cls)
		"spell_power", "heal_power":
			pct += amount(powers, "arcane_flow", cls)
		"crit_chance":
			pct += amount(powers, "keen_eye", cls)
		"dot_power", "dot_duration":
			pct += amount(powers, "venom_lore", cls)
	return pct / 100.0


## Creature/Rival.receive_damage: how much more a hit from `source` (a pet)
## does to `victim`, as a multiplier.
static func hit_multiplier(source: Node, victim: Node) -> float:
	if not (source is Creature) or not is_instance_valid(source):
		return 1.0
	var powers := of_pet(source)
	if powers.is_empty():
		return 1.0
	var cls: String = source.species.pet_class()
	var pct := 0.0
	var fraction: float = victim.health.fraction()
	if fraction < 0.3:
		pct += amount(powers, "executioner", cls)
	if fraction > 0.9:
		pct += amount(powers, "first_strike", cls)
	var big: bool = victim is Rival or (victim is Creature and (victim.elite or victim.pack_leader))
	if big:
		pct += amount(powers, "giant_slayer", cls)
	var troubled: bool = victim.health.is_poisoned() or (victim is Creature and victim.is_stunned())
	if troubled:
		pct += amount(powers, "bully", cls)
	return 1.0 + pct / 100.0


## Server: `victim` was just killed by `source` (a pet, or a tamer's bat).
static func on_kill(source: Node, victim: Node) -> void:
	if not is_instance_valid(source) or not is_instance_valid(victim):
		return
	var tamer: Player = null
	var cls := ""
	if source is Player:
		tamer = source
	elif source is Creature and source.is_player_pet() and source.world:
		tamer = source.world.get_player(source.owner_id)
		cls = source.species.pet_class()
	if tamer == null:
		return
	var powers := tamer.legend_powers()
	if powers.is_empty():
		return
	var world: World = tamer.world
	var feast := amount(powers, "feast", cls) if source is Creature else 0.0
	if feast > 0.0:
		for pet in world.get_pets(tamer.peer_id):
			if not pet.fainted:
				pet.health.heal(pet.health.max_health * feast / 100.0)
		world.play_heart.rpc(source.global_position)
	var blast := amount(powers, "corpse_blast", cls) if source is Creature else 0.0
	if blast > 0.0:
		var damage: float = victim.health.max_health * blast / 100.0
		var at: Vector3 = victim.global_position
		world.play_burst.rpc(at, Color(1.0, 0.55, 0.25), 3.5)
		for c: Creature in world.get_tree().get_nodes_in_group("creatures"):
			if c != victim and is_instance_valid(c) and Combat.are_enemies(tamer, c) and c.is_targetable() \
					and c.global_position.distance_to(at) <= 4.0:
				c.receive_damage(damage, null)  # no source: a blast's kills don't blast again
	var rush := amount(powers, "rush")
	if rush > 0.0:
		tamer.start_rush.rpc_id(tamer.peer_id, rush)
	var siphon := amount(powers, "siphon")
	if siphon > 0.0 and not tamer.downed:
		tamer.health.heal(tamer.health.max_health * siphon / 100.0)


## Server: the tamer's bat just hit `victim` for `damage`.
static func on_bat_hit(tamer: Player, victim: Node, damage: float) -> void:
	var powers := tamer.legend_powers()
	if powers.is_empty() or not is_instance_valid(victim):
		return
	var world: World = tamer.world
	var stun := amount(powers, "heavy_swing")
	if stun > 0.0 and victim is Creature and randf() < stun / 100.0:
		victim.stun(1.5)
	var arc := amount(powers, "chain_swing")
	if arc > 0.0:
		var near: Array = world.get_tree().get_nodes_in_group("creatures").filter(func(c: Creature) -> bool:
			return c != victim and is_instance_valid(c) and Combat.are_enemies(tamer, c) and c.is_targetable() \
					and c.global_position.distance_to(victim.global_position) <= 6.0)
		near.sort_custom(func(a: Creature, b: Creature) -> bool:
			return a.global_position.distance_to(victim.global_position) < b.global_position.distance_to(victim.global_position))
		var points := PackedVector3Array([victim.global_position + Vector3.UP])
		for c: Creature in near.slice(0, 2):
			points.append(c.global_position + Vector3.UP)
			c.receive_damage(damage * arc / 100.0, null)
		if points.size() > 1:
			world.play_lightning.rpc(points)
	var rally := amount(powers, "rally")
	if rally > 0.0:
		tamer.start_rally(rally)
	var leech := amount(powers, "leech_swing")
	if leech > 0.0:
		var heal := damage * leech / 100.0
		tamer.health.heal(heal)
		for pet in world.get_pets(tamer.peer_id):
			if not pet.fainted:
				pet.health.heal(heal)
