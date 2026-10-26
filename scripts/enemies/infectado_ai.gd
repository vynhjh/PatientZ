extends CharacterBody3D
## Infected of Floor 1 (scenes/enemies/infectado.tscn).
## Hears noise, sees the player, follows grid paths through open doors.
##
## Nodes in the scene:
##   CollisionShape3D · Visual/Model (Zombie_Walking.fbx) · Visual/PatientZGlow
##   Animations (AnimationPlayer, library zombie.tres: "walk", "death") · Groan (3D sound)

const Config = preload("res://scripts/systems/level_config.gd")
const HitMaterial = preload("res://assets/materials/hit_flash.tres")

const PATIENT_Z_SCALE := 1.3        # Patient Z is bigger
const ANIM_REFERENCE_SPEED := 1.0   # movement speed (m/s) that matches animation speed 1.0
const ANIM_IDLE_SPEED := 0.25       # slow shuffle while standing
const CHARACTER_LAYER := 2          # blood decals (layer 1) don't stain the infected
const SEPARATION_RADIUS := 1.0      # infected keep this distance from each other (metres)
const WANDER_RADIUS_CELLS := 2      # idle infected roam this many cells around their spot

enum State { IDLE, INVESTIGATE, CHASE, DEAD }

var level: Node = null          # floor script, provides find_path()
## Attack animations of this scene's library (empty = the quick lunge of the normal infected).
## The hit lands at attack_hit_times[i] (0-1 of the animation) if the player is still in range.
@export var attack_animations: Array[StringName] = []
@export var attack_hit_times: Array[float] = []
@export var attack_anim_speed := 1.6
## Movement speed (m/s) that matches the walk animation at speed 1.0.
@export var anim_reference_speed := ANIM_REFERENCE_SPEED
## Patient Z in infectado.tscn is the normal model scaled up; scenes with their own model turn this off.
@export var scale_as_patient_z := true
## Dormant: stands still, deaf and blind, until wake() (Floor 2: the room trigger of its room)
## or until it is shot.
@export var dormant := false

var is_patient_z := false
var hunting := false           # always knows where the player is (Patient Z after breaking out)
var spawn_index := -1          # position in the floor list, used as id in the save
var health := Config.ZOMBIE_HEALTH
var state := State.IDLE

@export_group("Stats")
## Each kind of infected is a scene with its own values: infectado.tscn (normal),
## infectado_runner.tscn (fast) and infectado_heavy.tscn (hits for 40).
@export var max_health := Config.ZOMBIE_HEALTH
@export var walk_speed := 1.1
@export var chase_speed := 3.0
@export var sight_range := 14.0
@export var attack_range := 1.5
@export var attack_damage := 12.0
@export var attack_infection := 9.0
@export var attack_cooldown := 1.3
@export_group("Look")
## Size of the model and of its collision capsule.
@export var model_scale := 1.0
## Colour multiplied into the model's materials (white = unchanged).
@export var tint := Color.WHITE
@export_group("")

var _player: Node3D = null
var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _path: PackedVector3Array = PackedVector3Array()
var _path_index := 0
var _repath_timer := 0.0
var _attack_timer := 0.0
var _lose_timer := 0.0
var _wander_timer := 0.0
var _wander_target := Vector3.ZERO
var _groan_timer := 0.0
var _target_unreachable := false    # last path could not reach the target (closed door)
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

var _walk_animation := "walk"
var _death_animation := "death"
var _meshes: Array = []             # MeshInstance3D of the model (for the hit flash)
var _attacking := 0.0               # time left of the attack animation
var _pick_timer := 0.0

@onready var _visual: Node3D = %Visual          # pivot used for the lunge
@onready var _model: Node3D = %Model
@onready var _anim_player: AnimationPlayer = %Animations
@onready var _shape: CollisionShape3D = %CollisionShape3D
@onready var _groan: AudioStreamPlayer3D = %Groan


func setup(level_node: Node, patient_z: bool) -> void:
	level = level_node
	is_patient_z = patient_z
	if is_patient_z:
		max_health = Config.PATIENT_Z_HEALTH * GameManager.enemy_health_mult()
		health = max_health
		hunting = true
		chase_speed = 4.3 * GameManager.enemy_speed_mult()       # faster than the other infected
		attack_damage = 25.0 * GameManager.enemy_damage_mult()
		attack_range = 2.0
		attack_infection = 15.0
		sight_range = 18.0


func _ready() -> void:
	add_to_group("infected")
	# 2 players: tougher, harder-hitting and a bit faster infected
	max_health *= GameManager.enemy_health_mult()
	attack_damage *= GameManager.enemy_damage_mult()
	chase_speed *= GameManager.enemy_speed_mult()
	health = max_health
	_meshes = _model.find_children("*", "MeshInstance3D", true, false)
	if not is_equal_approx(model_scale, 1.0):
		_visual.scale = Vector3.ONE * model_scale
		_shape.shape = _shape.shape.duplicate()
		_shape.shape.radius *= model_scale
		_shape.shape.height *= model_scale
		_shape.position.y *= model_scale
	if tint != Color.WHITE:
		_apply_tint(tint)
	for mesh in _meshes:
		mesh.layers = CHARACTER_LAYER
	if is_patient_z and scale_as_patient_z:
		_visual.scale = Vector3.ONE * PATIENT_Z_SCALE
		_shape.shape = _shape.shape.duplicate()       # bigger capsule only for him
		_shape.shape.radius *= PATIENT_Z_SCALE
		_shape.shape.height *= PATIENT_Z_SCALE
		_shape.position.y *= PATIENT_Z_SCALE
	if is_patient_z:
		%PatientZGlow.visible = true
	_anim_player.play(_walk_animation)
	_anim_player.seek(randf() * _anim_player.current_animation_length, true)   # not all in sync
	_anim_player.speed_scale = ANIM_IDLE_SPEED
	_home = global_position
	_wander_target = _home
	_wander_timer = randf_range(1.0, 4.0)
	NoiseManager.noise_emitted.connect(_on_noise)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if dormant:
		velocity = Vector3(0.0, velocity.y - _gravity * delta if not is_on_floor() else 0.0, 0.0)
		move_and_slide()
		_animate(delta, 0.0)
		return
	_pick_timer -= delta
	if _player == null or not is_instance_valid(_player) or _player.dead or _pick_timer <= 0.0:
		_pick_timer = 0.5
		_pick_player()

	_attack_timer -= delta
	if _attacking > 0.0:
		_attacking -= delta
		if _attacking <= 0.0 and state != State.DEAD:
			_anim_player.play(_walk_animation, 0.2)
	var player_alive: bool = _player != null and not _player.dead

	if player_alive and (hunting or _can_see_player()):
		state = State.CHASE
		_target = _player.global_position
		_lose_timer = 5.0
	elif state == State.CHASE:
		_lose_timer -= delta
		if not player_alive or _lose_timer <= 0.0:
			state = State.INVESTIGATE

	var move := Vector3.ZERO
	match state:
		State.IDLE:
			move = _wander(delta)
		State.INVESTIGATE:
			move = _follow_path(_target, walk_speed * 1.8, delta)
			if _flat_distance(_target) < 1.2 or _target_unreachable:
				state = State.IDLE
				_home = global_position
				_wander_target = _home
		State.CHASE:
			move = _chase(delta)

	move += _separation() * (walk_speed if state == State.IDLE else chase_speed) * 0.6
	if _attacking > 0.0:
		move = Vector3.ZERO              # stands still while swinging
	velocity.x = move.x
	velocity.z = move.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()

	var flat_vel := Vector2(velocity.x, velocity.z)
	if flat_vel.length() > 0.2:
		rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), 8.0 * delta)
	_animate(delta, flat_vel.length())
	_update_groan(delta)


func _chase(delta: float) -> Vector3:
	var dist := _flat_distance(_player.global_position)
	if dist <= attack_range:
		_face(_player.global_position, delta)
		if _attack_timer <= 0.0:
			_attack_timer = attack_cooldown
			_attack()
		return Vector3.ZERO
	if dist < 3.5 and _has_line_of_sight():
		return _direction_to(_player.global_position) * chase_speed
	var move := _follow_path(_target, chase_speed, delta)
	if _target_unreachable:
		state = State.IDLE
		_wander_target = global_position
	return move


## Idle: roams between random free spots of its own room (never towards closed doors).
func _wander(delta: float) -> Vector3:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = randf_range(4.0, 9.0)
		if level and randf() < 0.75:
			_wander_target = level.random_point_near(_home, WANDER_RADIUS_CELLS)
		else:
			_wander_target = global_position          # stand still for a while
		_repath_timer = 0.0
	if _flat_distance(_wander_target) < 0.5:
		return Vector3.ZERO
	return _follow_path(_wander_target, walk_speed * 0.6, delta)


func _follow_path(target: Vector3, speed: float, delta: float) -> Vector3:
	_repath_timer -= delta
	if _repath_timer <= 0.0 and level:
		_repath_timer = 0.5
		_path = level.find_path(global_position, target)
		_path_index = 1 if _path.size() > 1 else 0
		_target_unreachable = not level.is_reachable(global_position, target)
	if _target_unreachable:
		return Vector3.ZERO                         # behind a closed door: don't crowd it
	while _path_index < _path.size() and _flat_distance(_path[_path_index]) < 0.6:
		_path_index += 1
	if _path_index < _path.size():
		return _direction_to(_path[_path_index]) * speed
	if _flat_distance(target) > 0.5:
		return _direction_to(target) * speed
	return Vector3.ZERO


## Pushes away from infected that are too close, so they don't stack on one spot.
func _separation() -> Vector3:
	var push := Vector3.ZERO
	for other in get_tree().get_nodes_in_group("infected"):
		if other == self:
			continue
		var away: Vector3 = global_position - other.global_position
		away.y = 0.0
		var dist := away.length()
		if dist < SEPARATION_RADIUS and dist > 0.001:
			push += away / dist * (1.0 - dist / SEPARATION_RADIUS)
	return push.limit_length(1.0)


func _attack() -> void:
	if attack_animations.is_empty():
		_lunge()
		_land_hit()
		return
	var i := randi() % attack_animations.size()
	var anim := attack_animations[i]
	var length := _anim_player.get_animation(anim).length / attack_anim_speed
	_anim_player.speed_scale = 1.0
	_anim_player.play(anim, 0.15, attack_anim_speed)
	_attacking = length
	_attack_timer = maxf(attack_cooldown, length)
	var hit_at: float = attack_hit_times[i] if i < attack_hit_times.size() else 0.5
	get_tree().create_timer(length * hit_at).timeout.connect(_land_hit)


func _land_hit() -> void:
	if state == State.DEAD or _player == null or _player.dead:
		return
	if _flat_distance(_player.global_position) <= attack_range + 0.4:
		_player.take_hit(attack_damage, attack_infection)


func _can_see_player() -> bool:
	var max_range := sight_range * (0.45 if _player.crouching else 1.0)
	var to := _player.global_position - global_position
	var dist := to.length()
	if dist > max_range:
		return false
	if dist > 3.0:
		var forward := -global_basis.z
		if forward.dot(to.normalized()) < -0.1:
			return false
	return _has_line_of_sight()


func _has_line_of_sight() -> bool:
	var eye := global_position + Vector3.UP * 1.6
	var chest := _player.global_position + Vector3.UP * 1.1
	var query := PhysicsRayQueryParameters3D.create(eye, chest, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Wakes a dormant infected: from now on it sees, hears and hunts like the others.
func wake(alert := false) -> void:
	if not dormant or state == State.DEAD:
		return
	dormant = false
	_groan_timer = randf_range(0.1, 1.5)
	if _player == null:
		_player = _nearest_player()
	if alert and _player:
		state = State.CHASE
		_target = _player.global_position
		_lose_timer = 6.0
		_repath_timer = 0.0


func _on_noise(pos: Vector3, radius: float, source: Node) -> void:
	if state == State.DEAD or state == State.CHASE or dormant:
		return
	if global_position.distance_to(pos) <= radius:
		if level and not level.is_reachable(global_position, pos):
			return                                  # heard through a wall / closed door
		state = State.INVESTIGATE
		_target = pos
		_repath_timer = 0.0
		if source and source.is_in_group("player") and global_position.distance_to(pos) < radius * 0.4:
			state = State.CHASE
			_lose_timer = 4.0


func take_damage(amount: float, _hit_position: Vector3) -> void:
	if state == State.DEAD:
		return
	if dormant:
		if _player == null:
			_player = _nearest_player()
		wake()
	health -= amount
	_flash_hit()
	if _player and state != State.CHASE:
		state = State.CHASE
		_target = _player.global_position
		_lose_timer = 6.0
		_repath_timer = 0.0
	if level and level.blood:
		level.blood.hit_splash(global_position)
	if health <= 0.0:
		_die()


func _die() -> void:
	%PatientZGlow.visible = false
	state = State.DEAD
	remove_from_group("infected")
	_shape.set_deferred("disabled", true)
	velocity = Vector3.ZERO
	if _death_animation != "":
		_anim_player.speed_scale = 1.0
		_anim_player.play(_death_animation, 0.15)
		# the body moves while falling: the pool appears under it when it hits the floor
		get_tree().create_timer(_anim_player.current_animation_length * 0.55).timeout.connect(_pool_under_body)
	else:
		if _anim_player:
			_anim_player.pause()
		var tween := create_tween()
		tween.tween_property(_visual, "rotation:x", PI / 2.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(_visual, "position:y", 0.25, 0.5)
		_pool_under_body()
	_on_killed()


## What a death counts for (the mini-boss overrides it).
## 2 players: chase the closest one that is alive.
func _nearest_player() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for p in get_tree().get_nodes_in_group("player"):
		if p.dead:
			continue
		var d: float = p.global_position.distance_squared_to(global_position)
		if d < best_d:
			best_d = d
			best = p
	if best == null:
		best = get_tree().get_first_node_in_group("player")
	return best


func _pick_player() -> void:
	var p := _nearest_player()
	if p != _player and p != null:
		_player = p
		if state == State.CHASE:
			_target = p.global_position


## Copies of the model's materials with the colour multiplied (the hit flash uses the overlay).
func _apply_tint(color: Color) -> void:
	for mesh: MeshInstance3D in _meshes:
		for i in mesh.mesh.get_surface_count():
			var mat := mesh.get_active_material(i)
			if mat is StandardMaterial3D:
				var copy: StandardMaterial3D = mat.duplicate()
				copy.albedo_color = copy.albedo_color * color
				mesh.set_surface_override_material(i, copy)


func _on_killed() -> void:
	if is_patient_z and GameManager.floor_number >= 3:
		GameManager.register_final_boss_kill()     # final boss: not one of the 60 infected
		return
	if is_patient_z:
		GameManager.notify("Patient Z eliminated!")
	GameManager.register_kill()


## Already dead when the game is loaded: corpse on the floor, no kill counted again.
func die_silently() -> void:
	state = State.DEAD
	%PatientZGlow.visible = false
	remove_from_group("infected")
	_shape.set_deferred("disabled", true)
	if _death_animation != "":
		# jump straight to the last frame of the death animation (lying on the floor)
		_anim_player.speed_scale = 1.0
		_anim_player.play(_death_animation)
		_anim_player.seek(_anim_player.current_animation_length, true)
	else:
		if _anim_player:
			_anim_player.pause()
		_visual.rotation.x = PI / 2.0
		_visual.position.y = 0.25
	_pool_under_body()


func _pool_under_body() -> void:
	if level and level.blood and is_inside_tree():
		level.blood.pool(_body_position())


## Where the body is now (the hips bone, which moves during the death animation).
func _body_position() -> Vector3:
	if _model:
		var skeletons := _model.find_children("*", "Skeleton3D", true, false)
		if not skeletons.is_empty():
			var sk: Skeleton3D = skeletons[0]
			var hips := sk.find_bone("mixamorig_Hips")
			if hips >= 0:
				var p: Vector3 = (sk.global_transform * sk.get_bone_global_pose(hips)).origin
				return Vector3(p.x, global_position.y, p.z)
	return global_position


# --- Save / load (world.json) ---------------------------------------------------

func get_save_data() -> Dictionary:
	return {
		"index": spawn_index,
		"alive": state != State.DEAD,
		"position": SaveManager.vec3_to_array(global_position),
		"rotation": rotation.y,
		"health": health,
		"dormant": dormant,
	}


func load_save_data(data: Dictionary) -> void:
	global_position = SaveManager.array_to_vec3(data.get("position", []))
	rotation.y = float(data.get("rotation", 0.0))
	health = float(data.get("health", health))
	dormant = bool(data.get("dormant", dormant))
	_home = global_position
	_wander_target = _home
	if not bool(data.get("alive", true)):
		die_silently()


# --- Helpers --------------------------------------------------------------

func _flat_distance(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


func _direction_to(point: Vector3) -> Vector3:
	var dir := point - global_position
	dir.y = 0.0
	return dir.normalized() if dir.length() > 0.01 else Vector3.ZERO


func _face(point: Vector3, delta: float) -> void:
	var dir := _direction_to(point)
	if dir != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 10.0 * delta)


## Plays the walk animation faster or slower depending on the movement speed.
func _animate(_delta: float, speed: float) -> void:
	if _anim_player == null or _walk_animation == "" or _attacking > 0.0:
		return
	if not _anim_player.is_playing():
		_anim_player.play(_walk_animation)
	if speed < 0.2:
		_anim_player.speed_scale = ANIM_IDLE_SPEED
	else:
		_anim_player.speed_scale = clampf(speed / anim_reference_speed, 0.5, 2.4)


## Red flash on the whole model when a bullet hits.
func _flash_hit() -> void:
	for mesh in _meshes:
		mesh.material_overlay = HitMaterial
	get_tree().create_timer(0.08).timeout.connect(_clear_flash)


func _clear_flash() -> void:
	for mesh in _meshes:
		if is_instance_valid(mesh):
			mesh.material_overlay = null


func _lunge() -> void:
	var tween := create_tween()
	tween.tween_property(_visual, "position:z", -0.35, 0.12)
	tween.tween_property(_visual, "position:z", 0.0, 0.25)


func _update_groan(delta: float) -> void:
	_groan_timer -= delta
	if _groan_timer <= 0.0:
		_groan_timer = randf_range(4.0, 9.0) if state != State.CHASE else randf_range(2.0, 4.0)
		_groan.pitch_scale = randf_range(0.35, 0.5) * (0.8 if is_patient_z else 1.0)
		_groan.play()
