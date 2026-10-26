extends Node3D
## Patient Z · Floor 1 (Underground Lab) — scenes/levels/laboratorio_piso1.tscn
##
## Everything you see is placed in the scene: WorldEnvironment, World (floor, ceiling, walls),
## Lights (lamp.tscn), Doors (door.tscn), Cabinets (cabinet.tscn), Furniture, Items (pickup.tscn),
## Clutter / Debris / WallDecor (scenes/props: stretchers, wheelchairs, photos, blood messages…),
## Stairs, Breach, Signs, Boss (jefe.tscn), Player (player.tscn), AlarmSystem, Blood, HUD,
## DialogueUI and PauseMenu.
## This script only adds the logic: map validation, rooms and pathfinding (from MAPA),
## the alarm, spawning the infected, random blood, checkpoints and save/load.

const Config = preload("res://scripts/systems/level_config.gd")
const Coop = preload("res://scripts/systems/coop.gd")
const InfectadoScene = preload("res://scenes/enemies/infectado.tscn")
const PatientZScene = preload("res://scenes/enemies/patient_z.tscn")      # final boss (Blind Hunter)
const LampMaterial = preload("res://assets/materials/lamp_panel.tres")

## Legend:
## # wall · . floor · D door · L lamp · P player · B boss · Z infected
## A M-9 rifle (its room is the Security Guard Room) · E shotgun · T containment breach
## X stairs to Floor 2 (locked)
const MAPA := [
	"###############################",
	"#......#......###......#......#",
	"#..L...#..L...###..L...#...L..#",
	"#......#......###......#......#",
	"#......#......###......#......#",
	"###D#######D#######D#######D###",
	"#.....L.......L.......L.......#",
	"#P............B...............#",
	"#.............................#",
	"####D##########X###############",
	"#......#..Z....L.....Z.#......#",
	"#..A.L.D....E.....Z....D..L.Z.#",
	"#......#....Z..........#......#",
	"####D###########D#######...T..#",
	"#..Z......Z...#........D.Z....#",
	"#.....L.......D...Z.L..#..Z...#",
	"#...Z...L..Z..#.Z......#......#",
	"#.........Z...#......Z.#...L..#",
	"###############################",
]

const NO_CELL := Vector2i(-1, -1)
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var floor_name := "Floor 1 · Underground Lab"     # shown in the saved games list
var astar := AStarGrid2D.new()
var player: CharacterBody3D
var player2: CharacterBody3D    # split screen (2 players), null otherwise
var blood: Node3D               # blood_spawner.gd, also used by the infected

var _env: Environment
var _lamp_mat: StandardMaterial3D

@onready var _alarm: Node = $AlarmSystem
@onready var _infected_root: Node3D = $Infected
var _zombie_spawns: Array[Vector2i] = []
var _breach_cell := NO_CELL
var _region_of := {}            # Vector2i -> region id
var _regions: Array = []        # region id -> Array of Vector2i
var _hall_region := -1
var _guard_region := -1
var _start_rooms: Array[int] = []
var _used_cells := {}
# Objects the save system needs to find again (see get_save_data / load_save_data)
var _doors := {}                # Vector2i -> door
var _cabinets := {}             # Vector2i -> cabinet
var _pickups := {}              # weapon id -> pickup
var _zombies: Array = []        # in spawn order
var _patient_z: Node3D = null   # waits outside the scene until the other infected are dead


func _ready() -> void:
	add_to_group("level")
	player2 = Coop.setup_players(self)
	_validate_map()
	GameManager.reset_floor(Config.objetivo_bajas)
	GameManager.alarm_started.connect(_on_alarm_started)
	GameManager.kills_changed.connect(_on_kills_changed)

	# Own copies of the environment and the lamp material: the alarm turns them red
	_env = $WorldEnvironment.environment.duplicate()
	$WorldEnvironment.environment = _env
	_lamp_mat = LampMaterial.duplicate()
	_alarm.setup(_env, _lamp_mat)
	for lamp in $Lights.get_children():
		lamp.get_node("Panel").material_override = _lamp_mat
		_alarm.register_lamp(lamp.get_node("Light"))

	_analyze_regions()
	_build_astar()
	_collect_scene_objects()
	blood = $Blood
	_spawn_room_blood()

	# Checkpoints (autosave) at the important moments of the mission
	GameManager.phase_changed.connect(_on_phase_changed)
	GameManager.keycard_obtained.connect(_autosave)
	GameManager.rifle_obtained.connect(_autosave)

	# "Continue" from the main menu: restore the saved game now that the floor exists
	SaveManager.apply_pending(self)


## Finds the doors, cabinets, weapons and furniture placed in the scene.
func _collect_scene_objects() -> void:
	player = $Player
	for door in get_tree().get_nodes_in_group("doors"):
		_doors[door.cell] = door
		door.opened.connect(_on_door_opened)
	for cabinet in get_tree().get_nodes_in_group("cabinets"):
		_cabinets[cabinet.cell] = cabinet
		_used_cells[cabinet.cell] = true
	for pickup in get_tree().get_nodes_in_group("pickups"):
		_pickups[pickup.weapon_id] = pickup
		_used_cells[world_to_cell(pickup.global_position)] = true
	for item in $Furniture.get_children() + $Clutter.get_children():
		_used_cells[world_to_cell(item.global_position)] = true
	# Stretchers abandoned in the middle of a room close their cell for the pathfinding
	for blocker in get_tree().get_nodes_in_group("blocks_path"):
		astar.set_point_solid(world_to_cell(blocker.global_position), true)
	for cell in _all_cells():
		match ch(cell):
			"Z":
				_zombie_spawns.append(cell)
			"T":
				_breach_cell = cell


# --- Map helpers ----------------------------------------------------------

func ch(cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= MAPA.size():
		return "#"
	var row: String = MAPA[cell.y]
	if cell.x < 0 or cell.x >= row.length():
		return "#"
	return row[cell.x]


func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * Config.CELL_SIZE, 0.0, cell.y * Config.CELL_SIZE)


func world_to_cell(pos: Vector3) -> Vector2i:
	return Vector2i(roundi(pos.x / Config.CELL_SIZE), roundi(pos.z / Config.CELL_SIZE))


func _all_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in MAPA.size():
		for x in (MAPA[y] as String).length():
			cells.append(Vector2i(x, y))
	return cells


func _find_char(c: String) -> Vector2i:
	for cell in _all_cells():
		if ch(cell) == c:
			return cell
	return NO_CELL


func _validate_map() -> bool:
	var ok := true
	if MAPA.size() != Config.ROWS:
		push_error("MAPA has %d rows, expected %d" % [MAPA.size(), Config.ROWS])
		ok = false
	var zombies := 0
	for y in MAPA.size():
		var row: String = MAPA[y]
		if row.length() != Config.COLS:
			push_error("MAPA row %d has %d characters, expected %d" % [y, row.length(), Config.COLS])
			ok = false
		zombies += row.count("Z")
	if zombies != Config.objetivo_bajas:
		push_error("MAPA has %d 'Z' but objetivo_bajas = %d (level_config.gd)" % [zombies, Config.objetivo_bajas])
		ok = false

	# Every non-wall cell must be reachable (doors and stairs count as passable).
	var open_cells: Array[Vector2i] = []
	for cell in _all_cells():
		if ch(cell) != "#":
			open_cells.append(cell)
	if not open_cells.is_empty():
		var seen := {open_cells[0]: true}
		var stack: Array[Vector2i] = [open_cells[0]]
		while not stack.is_empty():
			var cur: Vector2i = stack.pop_back()
			for d in DIRS:
				var n: Vector2i = cur + d
				if ch(n) != "#" and not seen.has(n):
					seen[n] = true
					stack.append(n)
		var unreachable := open_cells.filter(func(c): return not seen.has(c))
		if not unreachable.is_empty():
			push_error("MAPA has unreachable cells (x, y): %s" % [unreachable])
			ok = false

	if ok:
		print("[Piso 1] MAPA OK: %dx%d, %d infected" % [Config.COLS, MAPA.size(), zombies])
	return ok


# --- Regions, doors and pathfinding -----------------------------------------

## Splits the floor into rooms separated by doors/stairs. Doors that join the
## start hall with a room without infected, weapons or the breach are the
## "first 4 rooms" (open after talking to the boss); the rest need the keycard.
func _analyze_regions() -> void:
	for cell in _all_cells():
		if ch(cell) in "#DX" or _region_of.has(cell):
			continue
		var id := _regions.size()
		var cells: Array[Vector2i] = [cell]
		_region_of[cell] = id
		var stack: Array[Vector2i] = [cell]
		while not stack.is_empty():
			var cur: Vector2i = stack.pop_back()
			for d in DIRS:
				var n: Vector2i = cur + d
				if not (ch(n) in "#DX") and not _region_of.has(n):
					_region_of[n] = id
					cells.append(n)
					stack.append(n)
		_regions.append(cells)

	_hall_region = _region_of.get(_find_char("P"), -1)
	_guard_region = _region_of.get(_find_char("A"), -1)
	for cell in _all_cells():
		if ch(cell) == "D" and _door_kind(cell) == "start":
			for r in _door_regions(cell):
				if r != _hall_region and not _start_rooms.has(r):
					_start_rooms.append(r)
	if _start_rooms.size() != 4:
		push_warning("Expected 4 start rooms next to the hall, found %d" % _start_rooms.size())


func _door_regions(cell: Vector2i) -> Array[int]:
	var ids: Array[int] = []
	for d in DIRS:
		var r: int = _region_of.get(cell + d, -1)
		if r >= 0 and not ids.has(r):
			ids.append(r)
	return ids


func _door_kind(cell: Vector2i) -> String:
	var ids := _door_regions(cell)
	if ids.size() == 2 and ids.has(_hall_region):
		var other: int = ids[0] if ids[1] == _hall_region else ids[1]
		if _region_is_clean(other):
			return "start"
	return "keycard"


func _region_is_clean(id: int) -> bool:
	for cell in _regions[id]:
		if ch(cell) in "ZAET":
			return false
	return true


func _build_astar() -> void:
	astar.region = Rect2i(0, 0, Config.COLS, MAPA.size())
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for cell in _all_cells():
		if ch(cell) in "#DXT":
			astar.set_point_solid(cell, true)


## Used by the infected. Returns world points from one position to another.
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var result := PackedVector3Array()
	var a := _nearest_open(world_to_cell(from))
	var b := _nearest_open(world_to_cell(to))
	if a == NO_CELL or b == NO_CELL:
		return result
	for id in astar.get_id_path(a, b, true):
		result.append(cell_to_world(id))
	return result


func _nearest_open(cell: Vector2i) -> Vector2i:
	if astar.is_in_boundsv(cell) and not astar.is_point_solid(cell):
		return cell
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var n: Vector2i = cell + d
		if astar.is_in_boundsv(n) and not astar.is_point_solid(n):
			return n
	return NO_CELL


func _on_door_opened(cell: Vector2i) -> void:
	astar.set_point_solid(cell, false)


# --- Alarm ----------------------------------------------------------------

func _on_alarm_started() -> void:
	_alarm.start()
	_spawn_infected()
	# Fresh blood in the hall when the emergency starts
	if _hall_region >= 0:
		blood.spawn_in_room(_regions[_hall_region], 12, cell_to_world, _wall_dir, Config.CELL_SIZE)
	GameManager.notify("ALARM · The infected are loose!")


## Spawns the infected spread over their rooms: each room gets as many infected as "Z" it
## has in MAPA, but on random free cells (not furniture, not next to doors), at least one cell
## apart, so they don't all start in the same place. Different every new game.
func _spawn_infected() -> void:
	var spawn_rng := RandomNumberGenerator.new()
	spawn_rng.randomize()
	var cells := _zombie_spawns.duplicate()          # one entry per "Z" (keeps save indices)
	var by_region := {}
	for i in _zombie_spawns.size():
		var region: int = _region_of.get(_zombie_spawns[i], -1)
		if not by_region.has(region):
			by_region[region] = []
		by_region[region].append(i)
	for region in by_region:
		var chosen := _spread_cells(region, by_region[region].size(), spawn_rng)
		for k in by_region[region].size():
			cells[by_region[region][k]] = chosen[k]

	var patient_index := -1
	if _breach_cell != NO_CELL:
		var best := INF
		for i in cells.size():
			var d := Vector2(cells[i] - _breach_cell).length()
			if d < best:
				best = d
				patient_index = i
	for i in cells.size():
		var cell: Vector2i = cells[i]
		var zombie: CharacterBody3D = (PatientZScene if i == patient_index else InfectadoScene).instantiate()
		zombie.setup(self, i == patient_index)
		zombie.spawn_index = i
		_zombies.append(zombie)
		zombie.position = cell_to_world(cell) + Vector3(spawn_rng.randf_range(-0.8, 0.8), 0, spawn_rng.randf_range(-0.8, 0.8))
		zombie.rotation.y = spawn_rng.randf() * TAU
		if i == patient_index:
			_patient_z = zombie       # Patient Z comes out last (see _on_kills_changed)
			if _breach_cell != NO_CELL:
				zombie.position = cell_to_world(_nearest_open(_breach_cell))
		else:
			_infected_root.add_child(zombie)


func _exit_tree() -> void:
	if _patient_z != null:
		_patient_z.free()          # never entered the scene
		_patient_z = null


## When only Patient Z is left, he breaks out of the containment breach and hunts the player.
func _on_kills_changed(kills: int, target: int) -> void:
	if _patient_z != null and kills >= target - 1:
		_release_patient_z()


func _release_patient_z(announce := true) -> void:
	var zombie := _patient_z
	_patient_z = null
	_infected_root.add_child(zombie)
	if announce:
		GameManager.notify("PATIENT Z has broken out of containment! He is hunting you.")
		if blood:
			blood.splatter_floor(zombie.global_position, 3.0)


## `count` free cells of a room, as far apart as possible.
func _spread_cells(region: int, count: int, rng: RandomNumberGenerator) -> Array:
	var free := _free_cells(region)
	if free.is_empty():
		free = _regions[region].filter(func(c): return not astar.is_point_solid(c))
	# shuffle
	for i in range(free.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = free[i]
		free[i] = free[j]
		free[j] = tmp
	var chosen: Array = []
	for min_gap in [3, 2, 1, 0]:
		for cell in free:
			if chosen.size() >= count:
				break
			if chosen.has(cell):
				continue
			var ok := true
			for other in chosen:
				if maxi(absi(cell.x - other.x), absi(cell.y - other.y)) < min_gap:
					ok = false
					break
			if ok:
				chosen.append(cell)
		if chosen.size() >= count:
			break
	while chosen.size() < count:                       # tiny room: share cells
		chosen.append(free[chosen.size() % free.size()])
	return chosen


## Walkable cells of a room without furniture and away from doors.
func _free_cells(region: int) -> Array:
	var result: Array = []
	for cell in _regions[region]:
		if not (ch(cell) in ".LZ") or _used_cells.has(cell) or astar.is_point_solid(cell):
			continue
		var near_door := false
		for d in DIRS:
			if ch(cell + d) in "DX":
				near_door = true
		if not near_door:
			result.append(cell)
	return result


## True if there is a complete path (through open doors only) between two positions.
func is_reachable(from: Vector3, to: Vector3) -> bool:
	var a := _nearest_open(world_to_cell(from))
	var b := _nearest_open(world_to_cell(to))
	if a == NO_CELL or b == NO_CELL:
		return false
	if a == b:
		return true
	return not astar.get_id_path(a, b, false).is_empty()


## Random free spot in the same room, within `radius` cells (used by idle infected).
func random_point_near(pos: Vector3, radius: int) -> Vector3:
	var center := world_to_cell(pos)
	var region: int = _region_of.get(center, -1)
	if region < 0:
		return pos
	var options: Array = []
	for cell in _regions[region]:
		if maxi(absi(cell.x - center.x), absi(cell.y - center.y)) <= radius and not _used_cells.has(cell) and not astar.is_point_solid(cell):
			options.append(cell)
	if options.is_empty():
		return pos
	var cell: Vector2i = options[randi() % options.size()]
	return cell_to_world(cell) + Vector3(randf_range(-0.9, 0.9), 0, randf_range(-0.9, 0.9))


# --- Blood ------------------------------------------------------------------

## Random blood in every room where infected appear, plus around the breach.
func _spawn_room_blood() -> void:
	for id in _regions.size():
		var cells: Array = _regions[id]
		var infected := cells.filter(func(c): return ch(c) == "Z").size()
		var has_breach := cells.any(func(c): return ch(c) == "T")
		if infected == 0 and not has_breach:
			continue
		var amount := 8 + infected * 6 + (16 if has_breach else 0)
		blood.spawn_in_room(cells, amount, cell_to_world, _wall_dir, Config.CELL_SIZE)


## Direction of a wall next to the cell (Vector2i.ZERO if none).
func _wall_dir(cell: Vector2i) -> Vector2i:
	for d in DIRS:
		if ch(cell + d) == "#":
			return d
	return Vector2i.ZERO


# --- Save / load (world.json) -------------------------------------------------

func get_save_data() -> Dictionary:
	var doors: Array = []
	for cell in _doors:
		if _doors[cell].is_open:
			doors.append(SaveManager.cell_to_array(cell))
	var cabinets: Array = []
	for cell in _cabinets:
		if _cabinets[cell].is_open:
			cabinets.append(SaveManager.cell_to_array(cell))
	var weapons_taken: Array = []
	for id in _pickups:
		if _pickups[id].taken:
			weapons_taken.append(id)
	var infected: Array = []
	for zombie in _zombies:
		if is_instance_valid(zombie) and zombie.is_inside_tree():
			infected.append(zombie.get_save_data())
	return {
		"doors_open": doors,
		"cabinets_open": cabinets,
		"weapons_taken": weapons_taken,
		"alarm": _alarm.active,
		"infected": infected,
	}


func load_save_data(data: Dictionary) -> void:
	for c in data.get("doors_open", []):
		var cell := SaveManager.array_to_cell(c)
		if _doors.has(cell):
			_doors[cell].open()
	for c in data.get("cabinets_open", []):
		var cell := SaveManager.array_to_cell(c)
		if _cabinets.has(cell):
			_cabinets[cell].open_silently()
	for id in data.get("weapons_taken", []):
		if _pickups.has(id):
			_pickups[id].take_silently()
	if bool(data.get("alarm", false)):
		_alarm.start(false)          # red lights, no siren again
		_spawn_infected()
		for z in data.get("infected", []):
			var index := int(z.get("index", -1))
			if index >= 0 and index < _zombies.size():
				if _zombies[index] == _patient_z:
					_release_patient_z(false)      # he was already out when the game was saved
				_zombies[index].load_save_data(z)
		if _patient_z != null and GameManager.kills >= GameManager.kill_target - 1:
			_release_patient_z(false)


func _on_phase_changed(_phase: int) -> void:
	_autosave()


func _autosave() -> void:
	if SaveManager.is_loading or player == null or player.dead:
		return
	SaveManager.save_game.call_deferred(self, true)
