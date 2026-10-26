extends Node
## Weapons of the player: equip, shoot (raycast from the camera) and reload.
## Uses the nodes of scenes/player/player.tscn: Hand/RifleModel, Hand/ShotgunModel,
## Hand/MuzzleLight and WeaponController/ShotSound.

const ImpactScene = preload("res://scenes/effects/impact.tscn")

const WEAPONS := {
	"rifle": {
		"name": "M-9 Rifle", "mag_size": 24, "start_mag": 24, "start_reserve": 120,
		"damage": 34.0, "pellets": 1, "spread": 0.008, "fire_delay": 0.13,
		"automatic": true, "reload_time": 1.6, "recoil": 0.012,
	},
	"shotgun": {
		"name": "Shotgun", "mag_size": 6, "start_mag": 6, "start_reserve": 24,
		"damage": 18.0, "pellets": 8, "spread": 0.06, "fire_delay": 0.85,
		"automatic": false, "reload_time": 2.2, "recoil": 0.05,
	},
}

var current_weapon := ""
var _last_weapon := ""              # the one [Q] takes out again

var _player: CharacterBody3D
var _inventory: Node
var _camera_rig: Node3D
var _fire_cooldown := 0.0
var _reload_timer := 0.0
var _models := {}                  # weapon id -> model node in the hand
var _muzzle_light: OmniLight3D

@onready var _shot_player: AudioStreamPlayer = %ShotSound


## hand: the "Hand" node that carries the gun models (it follows the hands of the model).
func setup(player: CharacterBody3D, inventory: Node, camera_rig: Node3D, hand: Node3D) -> void:
	_player = player
	_inventory = inventory
	_camera_rig = camera_rig
	_models = {"rifle": hand.get_node("RifleModel"), "shotgun": hand.get_node("ShotgunModel")}
	for model in _models.values():          # layer 2: blood decals don't stain the guns
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			mesh.layers = 2
	_muzzle_light = hand.get_node("MuzzleLight")


func give_weapon(id: String) -> void:
	_inventory.add_weapon(id, WEAPONS[id])
	GameManager.notify("%s picked up" % WEAPONS[id]["name"])
	equip(id)


func add_ammo(id: String, amount: int) -> void:
	_inventory.add_ammo(id, amount, WEAPONS[id]["name"])


func equip(id: String) -> void:
	if id != "":
		_last_weapon = id
	current_weapon = id
	_reload_timer = 0.0
	for weapon_id in _models:
		_models[weapon_id].visible = weapon_id == id


## [Q]: put the weapon away (empty hands) or take it out again.
func toggle_holster() -> void:
	if current_weapon != "":
		equip("")
		GameManager.notify("Weapon put away")
	elif _last_weapon != "" and _inventory.has_weapon(_last_weapon):
		equip(_last_weapon)
	elif _inventory.has_weapon("rifle"):
		equip("rifle")
	elif _inventory.has_weapon("shotgun"):
		equip("shotgun")


func weapon_text() -> String:
	if current_weapon == "":
		return "Unarmed  [Q] take out weapon" if _last_weapon != "" else "Unarmed"
	var a: Dictionary = _inventory.ammo[current_weapon]
	var text := "%s  %d | %d" % [WEAPONS[current_weapon]["name"], a["mag"], a["reserve"]]
	if _reload_timer > 0.0:
		text += "  (reloading...)"
	return text


## Called by the player every physics frame.
func update(delta: float, busy: bool) -> void:
	_fire_cooldown -= delta
	_muzzle_light.light_energy = move_toward(_muzzle_light.light_energy, 0.0, delta * 40.0)
	if _reload_timer > 0.0:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_finish_reload()

	if busy:
		return
	if Input.is_action_just_pressed(_player.act("weapon_1")) and _inventory.has_weapon("rifle"):
		equip("rifle")
	if Input.is_action_just_pressed(_player.act("weapon_2")) and _inventory.has_weapon("shotgun"):
		equip("shotgun")
	if Input.is_action_just_pressed(_player.act("holster")):
		toggle_holster()
	if current_weapon == "":
		return
	if Input.is_action_just_pressed(_player.act("reload")):
		_start_reload()

	if _player.running:
		return                      # can't shoot while running
	var data: Dictionary = WEAPONS[current_weapon]
	var wants_fire := Input.is_action_pressed(_player.act("shoot")) if data["automatic"] else Input.is_action_just_pressed(_player.act("shoot"))
	var can_aim: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or _player.player_number != 1
	if wants_fire and can_aim and _fire_cooldown <= 0.0 and _reload_timer <= 0.0:
		if _inventory.ammo[current_weapon]["mag"] > 0:
			fire()
		else:
			_start_reload()


func fire() -> void:
	var data: Dictionary = WEAPONS[current_weapon]
	_fire_cooldown = data["fire_delay"]
	_inventory.ammo[current_weapon]["mag"] -= 1
	_player.register_shot()
	_muzzle_light.light_energy = 6.0
	_shot_player.pitch_scale = 1.0 if current_weapon == "rifle" else 0.7
	_shot_player.play()
	_camera_rig.add_recoil(data["recoil"])

	var camera: Camera3D = _camera_rig.camera
	var space := _player.get_world_3d().direct_space_state
	var origin := camera.global_position
	var forward := -camera.global_basis.z
	for i in data["pellets"]:
		var spread: float = data["spread"]
		var dir := (forward + camera.global_basis.x * randf_range(-spread, spread) + camera.global_basis.y * randf_range(-spread, spread)).normalized()
		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * 80.0, 1 | 4, [_player.get_rid()])
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var flesh: bool = hit.collider.has_method("take_damage")
		if flesh:
			hit.collider.take_damage(data["damage"], hit.position)
		_spawn_impact(hit.position, flesh)


func _start_reload() -> void:
	if current_weapon == "" or _reload_timer > 0.0:
		return
	var a: Dictionary = _inventory.ammo[current_weapon]
	if a["reserve"] <= 0:
		GameManager.notify("No ammo left")
		return
	if a["mag"] >= WEAPONS[current_weapon]["mag_size"]:
		return
	_reload_timer = WEAPONS[current_weapon]["reload_time"]


func _finish_reload() -> void:
	var a: Dictionary = _inventory.ammo[current_weapon]
	var needed: int = WEAPONS[current_weapon]["mag_size"] - a["mag"]
	var taken: int = min(needed, a["reserve"])
	a["mag"] += taken
	a["reserve"] -= taken


## Small flash where a bullet hits (red on flesh). Scene: scenes/effects/impact.tscn
func _spawn_impact(pos: Vector3, flesh: bool) -> void:
	var spark: MeshInstance3D = ImpactScene.instantiate()
	get_tree().current_scene.add_child(spark)
	spark.global_position = pos
	if flesh:
		var mat: StandardMaterial3D = spark.get_surface_override_material(0)
		mat.albedo_color = Color(0.6, 0.0, 0.0)
		mat.emission = Color(0.6, 0.0, 0.0)
	var tween := spark.create_tween()
	tween.tween_property(spark, "scale", Vector3.ONE * 0.1, 0.25)
	tween.tween_callback(spark.queue_free)
