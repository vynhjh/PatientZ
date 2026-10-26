extends Node3D
## Patient Z · Floor 2 (The Containment Spiral) — scenes/levels/laboratorio_piso2.tscn
##
## Everything you see is placed in the scene: World (floor, ceiling, walls), Stairwell (L-shaped
## stairs from Floor 1), ExitStairs (stairs to Floor 3), Lights, Doors, Cabinets, Furniture,
## Clutter, Debris, WallDecor, WallDamage, Signs, RoomTriggers (Area3D per room), Infected
## (35 dormant infected + the mini-boss, grouped by room), Player, AlarmSystem, Blood, HUD,
## DialogueUI and PauseMenu.
## This script only adds the logic: pathfinding from MAPA, the red emergency lights, the mission
## (35 kills → containment door → mini-boss → stairs to Floor 3), checkpoints and save/load.
##
## The rooms follow a spiral: Stairwell → Corridor → Medical Supplies → Armory A → Armory B →
## Ward C → Ward B → Ward A → Containment (mini-boss) → Exit (stairs to Floor 3).

const CELL_SIZE := 3.0
const WALL_HEIGHT := 3.2

## Legend: # wall · . floor · S stairwell (lower level, Floor 1 height) · U door stairwell → corridor
## D door · K containment door (opens when the 35 infected are dead) · E exit door (mini-boss dead)
## F sealed door back to Floor 1
const MAPA := [
	"###########################",
	"#SSSS############.........#",
	"#SSSSU..........D.........#",
	"#SSSS#..........#.........#",
	"#SSSS############.........#",
	"FSSSS####.......#.........#",
	"#########.......#####D#####",
	"#.......#.......#.........#",
	"#.......K.......#.........#",
	"#.......####E####.........#",
	"#.......#.......#.........#",
	"#.......#.......#.........#",
	"####D################D#####",
	"#.......#.......#.........#",
	"#.......#.......#.........#",
	"#.......#.......#.........#",
	"#.......D.......D.........#",
	"#.......#.......#.........#",
	"#.......#.......#.........#",
	"#.......#.......#.........#",
	"###########################",
]

## name → [first cell, last cell, name shown when you enter]
const ROOMS := {
	"Stairwell": [Vector2i(1, 1), Vector2i(4, 5), "Stairwell"],
	"Corridor": [Vector2i(6, 2), Vector2i(15, 3), "Floor 2 · Containment Spiral"],
	"Medical": [Vector2i(17, 1), Vector2i(25, 5), "Medical Supplies"],
	"ArmoryA": [Vector2i(17, 7), Vector2i(25, 11), "Armory A"],
	"ArmoryB": [Vector2i(17, 13), Vector2i(25, 19), "Armory B"],
	"WardC": [Vector2i(9, 13), Vector2i(15, 19), "Ward C"],
	"WardB": [Vector2i(1, 13), Vector2i(7, 19), "Ward B"],
	"WardA": [Vector2i(1, 7), Vector2i(7, 11), "Ward A"],
	"Containment": [Vector2i(9, 5), Vector2i(15, 8), "Containment"],
	"Exit": [Vector2i(9, 10), Vector2i(15, 11), "Exit · Stairs to Floor 3"],
}

const NO_CELL := Vector2i(-1, -1)
const LampMaterial = preload("res://assets/materials/lamp_panel.tres")
const Coop = preload("res://scripts/systems/coop.gd")

var floor_name := "Floor 2 · Containment Spiral"     # shown in the saved games list
# Per-floor settings (Floor 3 extends this script and changes them in _configure())
var map: Array = MAPA
var rooms: Dictionary = ROOMS
var floor_number := 2
var arrival_text := "FLOOR 2 · The Containment Spiral"
var blood_rooms: Array = ["Corridor", "ArmoryB", "WardC", "WardB", "WardA", "Containment"]
var blood_density := 0.5        # blood stains per cell of those rooms
var fog_density := -1.0         # > 0: thicker red haze than the alarm default
var boss_room := "Containment"
var boss_wake_text := "THE BRUTE has woken up! Use the shotgun up close."
var boss_health := -1.0         # > 0: overrides the boss health
var astar := AStarGrid2D.new()
var player: CharacterBody3D
var player2: CharacterBody3D    # split screen (2 players), null otherwise
var blood: Node3D               # blood_spawner.gd, also used by the infected
var mini_boss: CharacterBody3D

var _env: Environment
var _lamp_mat: StandardMaterial3D
var _doors := {}                # Vector2i -> door
var _cabinets := {}             # Vector2i -> cabinet
var _infected: Array = []       # every infected of the floor (not the mini-boss)

@onready var _alarm: Node = $AlarmSystem
@onready var _infected_root: Node3D = $Infected


## Floors that reuse this script set their map, rooms and settings here.
func _configure() -> void:
	pass


func _ready() -> void:
	_configure()
	add_to_group("level")
	player = $Player
	player2 = Coop.setup_players(self)
	blood = $Blood
	_collect_infected()
	GameManager.reset_floor(_infected.size(), floor_number)
	GameManager.set_phase(GameManager.Phase.SURVIVE)

	# Red emergency lights from the start (own copies of the environment and the lamp material)
	_env = $WorldEnvironment.environment.duplicate()
	$WorldEnvironment.environment = _env
	_lamp_mat = LampMaterial.duplicate()
	_alarm.setup(_env, _lamp_mat)
	for lamp in $Lights.get_children():
		lamp.get_node("Panel").material_override = _lamp_mat
		_alarm.register_lamp(lamp.get_node("Light"))
	_alarm.start(false)
	if fog_density > 0.0:
		_env.fog_density = fog_density

	_build_astar()
	for door in get_tree().get_nodes_in_group("doors"):
		_doors[door.cell] = door
		door.opened.connect(_on_door_opened)
	for cabinet in get_tree().get_nodes_in_group("cabinets"):
		_cabinets[cabinet.cell] = cabinet
	for trigger in get_tree().get_nodes_in_group("room_triggers"):
		trigger.room_entered.connect(_on_room_entered)
	_spawn_room_blood()

	GameManager.kills_changed.connect(_on_kills_changed)
	GameManager.miniboss_killed.connect(_autosave)
	GameManager.final_boss_killed.connect(_autosave)

	# State brought from Floor 1 (health, weapons, ammo, bandages, flashlight)
	if not GameManager.carry_player.is_empty() and not SaveManager.pending_load:
		var data: Dictionary = GameManager.carry_player
		data["position"] = SaveManager.vec3_to_array(player.global_position)
		data["yaw"] = player.rotation.y
		player.load_save_data(data)
		GameManager.carry_player = {}
		if player2 and not GameManager.carry_player2.is_empty():
			var data2: Dictionary = GameManager.carry_player2
			data2["position"] = SaveManager.vec3_to_array(player2.global_position)
			data2["yaw"] = player2.rotation.y
			player2.load_save_data(data2)
		GameManager.carry_player2 = {}
		GameManager.notify(arrival_text)
		_autosave.call_deferred()

	SaveManager.apply_pending(self)


## The infected placed in the scene, grouped by room under Infected/<Room>.
func _collect_infected() -> void:
	for group in _infected_root.get_children():
		for zombie in group.get_children():
			if not zombie.has_method("take_damage"):
				continue
			var is_patient_z: bool = zombie.scene_file_path.ends_with("patient_z.tscn")
			zombie.setup(self, is_patient_z)
			if is_patient_z or (zombie.get_script() and zombie.get_script().resource_path.ends_with("mini_boss.gd")):
				mini_boss = zombie          # the boss of the floor
				if boss_health > 0.0:
					zombie.max_health = boss_health * GameManager.enemy_health_mult()
					zombie.health = zombie.max_health
			else:
				_infected.append(zombie)


# --- Map helpers (also used by the infected) ------------------------------------------

func ch(cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= map.size() or cell.x < 0 or cell.x >= (map[cell.y] as String).length():
		return "#"
	return map[cell.y][cell.x]


func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * CELL_SIZE, 0.0, cell.y * CELL_SIZE)


func world_to_cell(pos: Vector3) -> Vector2i:
	return Vector2i(roundi(pos.x / CELL_SIZE), roundi(pos.z / CELL_SIZE))


func room_cells(room: String) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var a: Vector2i = rooms[room][0]
	var b: Vector2i = rooms[room][1]
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			cells.append(Vector2i(x, y))
	return cells


func _build_astar() -> void:
	astar.region = Rect2i(0, 0, (map[0] as String).length(), map.size())
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in map.size():
		for x in (map[y] as String).length():
			if ch(Vector2i(x, y)) != ".":
				astar.set_point_solid(Vector2i(x, y), true)      # walls, doors, stairwell
	for blocker in get_tree().get_nodes_in_group("blocks_path"):
		astar.set_point_solid(world_to_cell(blocker.global_position), true)


func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var result := PackedVector3Array()
	var a := _nearest_open(world_to_cell(from))
	var b := _nearest_open(world_to_cell(to))
	if a == NO_CELL or b == NO_CELL:
		return result
	for id in astar.get_id_path(a, b, true):
		result.append(cell_to_world(id))
	return result


func is_reachable(from: Vector3, to: Vector3) -> bool:
	var a := _nearest_open(world_to_cell(from))
	var b := _nearest_open(world_to_cell(to))
	if a == NO_CELL or b == NO_CELL:
		return false
	return a == b or not astar.get_id_path(a, b).is_empty()


## Random free point at most `radius` cells away (used by idle infected).
func random_point_near(pos: Vector3, radius: int) -> Vector3:
	var center := world_to_cell(pos)
	for i in 12:
		var c := center + Vector2i(randi_range(-radius, radius), randi_range(-radius, radius))
		if astar.is_in_boundsv(c) and not astar.is_point_solid(c) and is_reachable(pos, cell_to_world(c)):
			return cell_to_world(c) + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8))
	return pos


func _nearest_open(cell: Vector2i) -> Vector2i:
	if astar.is_in_boundsv(cell) and not astar.is_point_solid(cell):
		return cell
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var n: Vector2i = cell + d
		if astar.is_in_boundsv(n) and not astar.is_point_solid(n):
			return n
	return NO_CELL


func _on_door_opened(cell: Vector2i) -> void:
	if ch(cell) != "U":            # the stairwell stays closed to the infected
		astar.set_point_solid(cell, false)


# --- Mission -----------------------------------------------------------------------------

func _on_room_entered(room_name: String) -> void:
	if room_name == rooms[boss_room][2] and mini_boss and mini_boss.state != mini_boss.State.DEAD:
		GameManager.notify(boss_wake_text)


func _on_kills_changed(kills: int, target: int) -> void:
	if kills == target and target > 0:
		_autosave()


## Old blood in the infected rooms (decals), like Floor 1.
func _spawn_room_blood() -> void:
	for room in blood_rooms:
		var cells := room_cells(room)
		blood.spawn_in_room(cells, int(cells.size() * blood_density), cell_to_world, _wall_dir, CELL_SIZE)


func _wall_dir(cell: Vector2i) -> Vector2i:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if ch(cell + d) == "#":
			return d
	return Vector2i.ZERO


# --- Save / load ----------------------------------------------------------------------------

func get_save_data() -> Dictionary:
	var doors: Array = []
	for cell in _doors:
		if _doors[cell].is_open:
			doors.append(SaveManager.cell_to_array(cell))
	var cabinets: Array = []
	for cell in _cabinets:
		if _cabinets[cell].is_open:
			cabinets.append(SaveManager.cell_to_array(cell))
	var rooms: Array = []
	for trigger in get_tree().get_nodes_in_group("room_triggers"):
		if trigger.activated:
			rooms.append(str(trigger.name))
	var infected := {}
	for zombie in _infected + ([mini_boss] if mini_boss else []):
		infected[str(_infected_root.get_path_to(zombie))] = zombie.get_save_data()
	return {
		"doors_open": doors,
		"cabinets_open": cabinets,
		"rooms_activated": rooms,
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
	for trigger in get_tree().get_nodes_in_group("room_triggers"):
		if str(trigger.name) in data.get("rooms_activated", []):
			trigger.activate(false)
	var infected: Dictionary = data.get("infected", {})
	for path in infected:
		var zombie := _infected_root.get_node_or_null(NodePath(path))
		if zombie:
			zombie.load_save_data(infected[path])


func _autosave() -> void:
	if SaveManager.is_loading or player == null or player.dead:
		return
	SaveManager.save_game.call_deferred(self, true)
