extends Node
## Save games, autoloaded as `SaveGame`.
##
## Each player's progress is saved on their own computer (user://saves), in one
## of MAX_SLOTS slots: name, party, hay beds, coins, potions and the furthest
## level reached. In multiplayer every player brings their own tamer and pets
## into the host's game: after spawning, the local player sends its save to the
## server, which validates and restores it. The host's save also decides which
## level the game starts on.
##
## Saving is automatic: when a level starts, when the party or stable changes,
## every AUTOSAVE_INTERVAL seconds, and when the window is closed.

const MAX_SLOTS := 3
const SAVE_DIR := "user://saves"
const VERSION := 1
const AUTOSAVE_INTERVAL := 20.0  ## Seconds of real time.

## The slot being played (or about to be). -1 = none chosen.
var slot := -1
## The data loaded from `slot` ({} for a new game).
var loaded := {}

var _player: Player
var _world: World
var _next_autosave_msec := 0
var _party_signature := ""


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func _process(_delta: float) -> void:
	if not is_instance_valid(_player) or slot < 0:
		return
	var signature := _current_party_signature()
	if Time.get_ticks_msec() >= _next_autosave_msec or signature != _party_signature:
		_party_signature = signature
		save_now()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_now()


# --- Slots (title screen) -----------------------------------------------------------

func slot_path(index: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, index + 1]


func has_save(index: int) -> bool:
	return FileAccess.file_exists(slot_path(index))


func read_slot(index: int) -> Dictionary:
	if not has_save(index):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(slot_path(index)))
	return parsed if parsed is Dictionary else {}


func delete_slot(index: int) -> void:
	DirAccess.remove_absolute(slot_path(index))
	if index == slot:
		loaded = {}


func first_empty_slot() -> int:
	for i in MAX_SLOTS:
		if not has_save(i):
			return i
	return -1


## The slot saved most recently, or -1 if there are no saves.
func latest_slot() -> int:
	var best := -1
	var best_time := -1.0
	for i in MAX_SLOTS:
		var data := read_slot(i)
		if not data.is_empty() and float(data.get("saved_at", 0)) > best_time:
			best = i
			best_time = float(data.get("saved_at", 0))
	return best


## Chooses the slot to play: continues it if it holds a save, otherwise starts a new game there.
func choose_slot(index: int) -> void:
	slot = index
	loaded = read_slot(index)


## One line describing a slot, for the title screen.
func describe(index: int) -> String:
	var data := read_slot(index)
	if data.is_empty():
		return "Slot %d  ·  empty" % (index + 1)
	var pets: int = data.get("party", []).size() + data.get("stable", []).filter(
			func(bed) -> bool: return bed is Dictionary and not bed.is_empty()).size()
	var when := Time.get_datetime_string_from_unix_time(int(data.get("saved_at", 0)), true)
	return "Slot %d  ·  %s  ·  Level %d  ·  %d pets  ·  %d coins  ·  saved %s" \
			% [index + 1, data.get("name", "?"), int(data.get("level", 1)), pets, int(data.get("coins", 0)), when]


## The level a hosted or solo game starts on.
func start_level() -> int:
	return maxi(int(loaded.get("level", 1)), 1)


# --- In game ---------------------------------------------------------------------------

## Called when the local player spawns: restore its saved progress on the server.
func on_local_player_spawned(player: Player, world: World) -> void:
	_player = player
	_world = world
	if loaded.is_empty():
		_next_autosave_msec = Time.get_ticks_msec() + 2000  # a new game: claim the slot right away
	else:
		_next_autosave_msec = Time.get_ticks_msec() + int(AUTOSAVE_INTERVAL * 1000)
		player.request_restore.rpc_id(1, loaded)
	player.stable_changed.connect(save_now)
	world.level_changed.connect(func() -> void:
		await get_tree().create_timer(1.0).timeout  # let the new level's state settle
		save_now(true))


## Writes the local player's progress to the current slot.
func save_now(announce := false) -> void:
	if slot < 0 or not is_instance_valid(_player) or not is_instance_valid(_world):
		return
	var party := []
	for pet in _world.get_pets(_player.peer_id):
		var data := pet.to_data()
		data["slot"] = pet.party_slot
		party.append(data)
	var level := maxi(_world.level_number, int(loaded.get("level", 1)))
	loaded = {
		"version": VERSION,
		"name": _player.display_name,
		"saved_at": Time.get_unix_time_from_system(),
		"level": level,
		"coins": _player.coins,
		"potions": _player.potions,
		"party": party,
		"stable": _player.stable.duplicate(true),
	}
	var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_warning("Could not save to %s" % slot_path(slot))
		return
	file.store_string(JSON.stringify(loaded, "\t"))
	file.close()
	_next_autosave_msec = Time.get_ticks_msec() + int(AUTOSAVE_INTERVAL * 1000)
	if announce:
		_world.hud.show_message("Game saved (slot %d)." % (slot + 1), Color(0.7, 0.9, 0.7))


func _current_party_signature() -> String:
	if not is_instance_valid(_world):
		return ""
	return ",".join(_world.get_pets(_player.peer_id).map(
			func(p: Creature) -> String: return "%d:%d:%d:%s" % [p.species_index, p.party_slot, p.level, p.skill_ranks]))
