extends Node
## Save / load system with several saved games. Register as autoload "SaveManager".
##
## Every saved game is a folder (a "slot") with one JSON file per part of the game:
##   user://saves/<slot id>/
##     meta.json      → game number, date, floor, objective, play time (shown in the lists)
##     progress.json  → mission state (GameManager: phase, syringes, keycard, kills...)
##     player.json    → position, health, infection, inventory, weapons, flashlight
##     world.json     → opened doors and cabinets, weapons taken, infected (alive/dead, position, health)
##
## Each file is written to a ".tmp" file first and then renamed, so a crash while saving
## never leaves a half-written save. Loading checks every file before using any of them.
##
## Flow:
##   New game:  SaveManager.start_new_game()          → new slot, the other saves are not touched
##   Save:      SaveManager.save_game(level)           → current slot (checkpoints / overwrite)
##              SaveManager.save_game(level, false, SaveManager.NEW_SLOT) → a new saved game
##   Load:      SaveManager.request_load(slot_id)  → change to the game scene → the floor calls
##              SaveManager.apply_pending(level) at the end of its _ready().

signal game_saved(slot_id: String, autosave: bool)
signal game_loaded(slot_id: String)

const SAVE_VERSION := 1
const SAVES_DIR := "user://saves"
const NEW_SLOT := "__new__"
const FILES := {
	"meta": "meta.json",
	"progress": "progress.json",
	"player": "player.json",
	"world": "world.json",
}

var current_slot := ""       # saved game that belongs to the game being played
var game_number := 0         # "Game 3" in the lists
var pending_load := false
var is_loading := false      # true while a save is being applied (avoids autosaving it again)

var _loaded := {}            # section name -> Dictionary
var _play_time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if get_tree().current_scene and get_tree().current_scene.name == "Main" and not get_tree().paused:
		_play_time += delta


# --- Saved games list --------------------------------------------------------------

## All valid saved games, newest first. Each item is the meta.json data plus "id".
func list_slots() -> Array:
	var result: Array = []
	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		return result
	for dir_name in DirAccess.get_directories_at(SAVES_DIR):
		if not has_save(dir_name):
			continue
		var meta = _read_json(_path(dir_name, "meta"))
		if meta is Dictionary:
			meta["id"] = dir_name
			result.append(meta)
	result.sort_custom(func(a, b): return str(a.get("saved_at", "")) > str(b.get("saved_at", "")))
	return result


func has_any_save() -> bool:
	return not list_slots().is_empty()


func has_save(slot_id := "") -> bool:
	if slot_id == "":
		slot_id = current_slot
	if slot_id == "":
		return false
	for section in FILES:
		if not FileAccess.file_exists(_path(slot_id, section)):
			return false
	return true


func get_save_info(slot_id := "") -> Dictionary:
	if slot_id == "":
		slot_id = current_slot
	if not has_save(slot_id):
		return {}
	var meta = _read_json(_path(slot_id, "meta"))
	return meta if meta is Dictionary else {}


## Text for the lists: "Game 2 · Get the rifle...\n2026-10-22 15:30 · 12 min played"
static func describe(meta: Dictionary) -> String:
	var minutes := int(float(meta.get("play_time", 0.0)) / 60.0)
	var date := str(meta.get("saved_at", "")).replace("T", " ").substr(0, 16)   # "2026-10-22 15:49"
	var kind := "  (checkpoint)" if bool(meta.get("autosave", false)) else ""
	var mode := " · 2 players" if int(meta.get("players", 1)) >= 2 else ""
	return "Game %d%s · %s\n%s · %d min played%s" % [int(meta.get("game_number", 1)), mode, meta.get("objective", ""), date, minutes, kind]


# --- New game -------------------------------------------------------------------

## Starts a new game in a new slot. The saved games that already exist are not touched.
func start_new_game() -> void:
	pending_load = false
	_play_time = 0.0
	game_number = _next_game_number()
	current_slot = _new_slot_id()


# --- Save -------------------------------------------------------------------------

## slot_id: "" = current slot · NEW_SLOT = a new saved game · or the id of a slot to overwrite.
func save_game(level: Node, autosave := false, slot_id := "") -> bool:
	if level == null or not is_instance_valid(level) or not level.is_inside_tree() or level.player == null or level.player.dead:
		return false
	if slot_id == NEW_SLOT or (slot_id == "" and current_slot == ""):
		slot_id = _new_slot_id()
	elif slot_id == "":
		slot_id = current_slot
	if game_number <= 0:
		game_number = _next_game_number()

	var player_data: Dictionary = level.player.get_save_data()
	var p2 = level.get("player2")
	if p2 != null and is_instance_valid(p2):
		player_data["player2"] = p2.get_save_data()          # split screen
	var sections := {
		"progress": GameManager.get_save_data(),
		"player": player_data,
		"world": level.get_save_data(),
		"meta": {
			"version": SAVE_VERSION,
			"game_number": game_number,
			"saved_at": Time.get_datetime_string_from_system(false, true),
			"scene": level.scene_file_path,
			"floor": str(level.floor_name) if "floor_name" in level else "Floor 1 · Underground Lab",
			"objective": GameManager.objective_text(),
			"players": GameManager.player_count,
			"play_time": _play_time,
			"autosave": autosave,
		},
	}
	var folder := SAVES_DIR.path_join(slot_id)
	DirAccess.make_dir_recursive_absolute(folder)
	# Write everything to .tmp files first, then swap them in.
	for section in sections:
		if not _write_json(_path(slot_id, section) + ".tmp", sections[section]):
			push_error("SaveManager: could not write %s" % section)
			return false
	for section in sections:
		DirAccess.rename_absolute(_path(slot_id, section) + ".tmp", _path(slot_id, section))
	current_slot = slot_id
	game_saved.emit(slot_id, autosave)
	GameManager.notify("Checkpoint saved" if autosave else "Game saved")
	return true


# --- Load -------------------------------------------------------------------------

## Reads and checks all files of a saved game. Returns false if it is missing or broken.
func request_load(slot_id := "") -> bool:
	if slot_id == "":
		slot_id = current_slot
	if not has_save(slot_id):
		return false
	var data := {}
	for section in FILES:
		var value = _read_json(_path(slot_id, section))
		if not (value is Dictionary):
			push_error("SaveManager: %s of %s is damaged" % [FILES[section], slot_id])
			return false
		data[section] = value
	if int(data["meta"].get("version", 0)) != SAVE_VERSION:
		push_error("SaveManager: save version %s not supported" % data["meta"].get("version"))
		return false
	_loaded = data
	current_slot = slot_id
	game_number = int(data["meta"].get("game_number", 1))
	_play_time = float(data["meta"].get("play_time", 0.0))
	pending_load = true
	return true


## Floor scene of the saved game waiting to be loaded (main.tscn opens it).
func pending_scene() -> String:
	if not pending_load:
		return ""
	return str(_loaded.get("meta", {}).get("scene", ""))


## 1 or 2 players in the saved game waiting to be loaded.
func pending_players() -> int:
	return int(_loaded.get("meta", {}).get("players", 1)) if pending_load else GameManager.player_count


## Called by the floor when it has finished building itself.
func apply_pending(level: Node) -> void:
	if not pending_load:
		return
	pending_load = false
	is_loading = true
	GameManager.load_save_data(_loaded["progress"])
	level.load_save_data(_loaded["world"])
	level.player.load_save_data(_loaded["player"])
	var p2 = level.get("player2")
	if p2 != null and is_instance_valid(p2) and _loaded["player"].has("player2"):
		p2.load_save_data(_loaded["player"]["player2"])
	is_loading = false
	_loaded = {}
	game_loaded.emit(current_slot)
	GameManager.notify("Game loaded")


func delete_slot(slot_id: String) -> void:
	if slot_id == "":
		return
	for section in FILES:
		for suffix in ["", ".tmp"]:
			var file: String = _path(slot_id, section) + suffix
			if FileAccess.file_exists(file):
				DirAccess.remove_absolute(file)
	DirAccess.remove_absolute(SAVES_DIR.path_join(slot_id))
	if slot_id == current_slot:
		current_slot = ""


func delete_all() -> void:
	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		return
	for dir_name in DirAccess.get_directories_at(SAVES_DIR):
		delete_slot(dir_name)
	current_slot = ""


# --- Helpers (Vector3 <-> JSON) ------------------------------------------------

static func vec3_to_array(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func array_to_vec3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2])) if a.size() >= 3 else Vector3.ZERO


static func cell_to_array(c: Vector2i) -> Array:
	return [c.x, c.y]


static func array_to_cell(a: Array) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1])) if a.size() >= 2 else Vector2i(-1, -1)


func _new_slot_id() -> String:
	var stamp := Time.get_datetime_string_from_system(false, false).replace("-", "").replace(":", "").replace("T", "_")
	var id := "save_%s" % stamp
	var n := 2
	while DirAccess.dir_exists_absolute(SAVES_DIR.path_join(id)) or id == current_slot:
		id = "save_%s_%d" % [stamp, n]
		n += 1
	return id


func _next_game_number() -> int:
	var highest := 0
	for meta in list_slots():
		highest = maxi(highest, int(meta.get("game_number", 0)))
	return highest + 1


func _path(slot_id: String, section: String) -> String:
	return SAVES_DIR.path_join(slot_id).path_join(FILES[section])


func _write_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	return JSON.parse_string(text)
