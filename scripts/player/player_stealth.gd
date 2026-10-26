extends CharacterBody3D
## Player of Patient Z: movement, crouch/stealth noise, health, infection and interaction.
## Scene: scenes/player/player.tscn
##   CollisionShape3D · Body (PlayerModel, Hand with the guns, FlashlightPivot/Flashlight)
##   HurtSound · Inventory · CameraRig (SpringArm3D/Camera3D) · WeaponController (ShotSound)

signal died

## 1 = keyboard and mouse (actions "px_...") · 2 = gamepad / numeric keypad (actions "p2_...").
## Player 2 only exists in 2-player games (split screen); the level removes it otherwise.
@export_range(1, 2) var player_number := 1
## Colour multiplied into the model (player 2 wears a blue-ish coat).
@export var outfit_tint := Color.WHITE


const WALK_SPEED := 2.8
const RUN_SPEED := 5.0
const CROUCH_SPEED := 1.4
const INTERACT_DISTANCE := 2.6
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.1

# Noise radius (metres) for each movement type
const NOISE_RUN := 14.0
const NOISE_WALK := 6.0
const NOISE_CROUCH := 2.0
const NOISE_SHOT := 30.0

var max_health := 100.0
var health := 100.0
var infection := 0.0          # 0..100 %
var dead := false
var crouching := false
var running := false
var noise_radius := 0.0
var current_prompt := ""
var flashlight_on := false

## Bandage: heals BANDAGE_HEALTH and removes BANDAGE_INFECTION over HEAL_TIME seconds,
## then the HealParticles node bursts green.
const HEAL_TIME := 1.5
const BANDAGE_HEALTH := 25.0
const BANDAGE_INFECTION := 40.0
var _heal_left := 0.0
var healing: bool:
	get:
		return _heal_left > 0.0

# Read by the HUD
var bandages: int:
	get:
		return inventory.bandages
var current_weapon: String:
	get:
		return weapons.current_weapon

@onready var inventory: Node = $Inventory
@onready var camera_rig: Node3D = $CameraRig
@onready var weapons: Node = $WeaponController

var _noise_timer := 0.0
var _shot_noise := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

@onready var _shape: CollisionShape3D = %CollisionShape3D
@onready var _body_pivot: Node3D = %Body
@onready var _model: Node3D = %PlayerModel
@onready var _hand: Node3D = %Hand
@onready var _flashlight_pivot: Node3D = %FlashlightPivot
@onready var _flashlight: SpotLight3D = %Flashlight
@onready var _heal_particles: GPUParticles3D = %HealParticles
@onready var _hurt_player: AudioStreamPlayer = %HurtSound


## Name of an input action for this player: act("shoot") → "px_shoot" or "p2_shoot".
func act(action: String) -> StringName:
	return StringName(("px_" if player_number == 1 else "p2_") + action)


func _ready() -> void:
	add_to_group("player")
	if outfit_tint != Color.WHITE:
		_model.tint(outfit_tint)
	# The level rotates the player to face the boss; the camera takes that direction.
	var start_yaw := rotation.y
	rotation = Vector3.ZERO
	camera_rig.setup(self, start_yaw)
	weapons.setup(self, inventory, camera_rig, _hand)
	_model.set_gun_socket(_hand)                # with a weapon the gun follows the hands
	set_flashlight(false)
	GameManager.alarm_started.connect(_on_alarm_started)
	if player_number == 1:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if dead:
		var restart: bool = (event is InputEventKey and event.pressed and event.physical_keycode == KEY_R) \
			or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A)
		if restart and _all_players_dead():
			# Back to the last save if there is one, otherwise restart the floor.
			if SaveManager.has_save():
				SaveManager.request_load()
			get_tree().reload_current_scene()
		return
	if player_number != 1:
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if dead:
		_update_down(delta)
		return
	var busy := _dialogue_busy()
	_body_pivot.rotation.y = camera_rig.yaw
	_update_movement(delta, busy)
	_model.update_animation(Vector2(velocity.x, velocity.z).length(), running, crouching)
	_model.set_weapon(weapons.current_weapon)    # weapon pose on the upper body
	_model.aiming = not busy and Input.is_action_pressed(act("aim"))
	_hand.visible = _model.gun_in_hands()       # running: the weapon is put away until you stop
	_flashlight_pivot.rotation.x = camera_rig.pitch
	if not busy and Input.is_action_just_pressed(act("flashlight")):
		set_flashlight(not flashlight_on)
	_update_noise(delta)
	_update_status(delta, busy)
	weapons.update(delta, busy)
	_update_interaction(busy)


# --- Movement and stealth -------------------------------------------------

func _update_movement(delta: float, busy: bool) -> void:
	var input := Vector2.ZERO
	if not busy:
		input = Input.get_vector(act("left"), act("right"), act("forward"), act("back"))
		if Input.is_action_just_pressed(act("crouch")):
			_set_crouch(not crouching)

	running = not busy and Input.is_action_pressed(act("sprint")) and input.length() > 0.1
	if running and crouching:
		_set_crouch(false)

	var speed := CROUCH_SPEED if crouching else (RUN_SPEED if running else WALK_SPEED)
	var dir := (Basis(Vector3.UP, camera_rig.yaw) * Vector3(input.x, 0, input.y)).normalized()
	velocity.x = move_toward(velocity.x, dir.x * speed, speed * 10.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, speed * 10.0 * delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()


func _set_crouch(value: bool) -> void:
	crouching = value
	var h := CROUCH_HEIGHT if crouching else STAND_HEIGHT
	(_shape.shape as CapsuleShape3D).height = h
	_shape.position.y = h / 2.0
	_body_pivot.scale.y = h / STAND_HEIGHT
	camera_rig.set_height(h - 0.2)


func _update_noise(delta: float) -> void:
	var moving := Vector2(velocity.x, velocity.z).length() > 0.3
	var move_noise := 0.0
	if moving:
		move_noise = NOISE_CROUCH if crouching else (NOISE_RUN if running else NOISE_WALK)
	_shot_noise = move_toward(_shot_noise, 0.0, NOISE_SHOT * delta)
	noise_radius = max(move_noise, _shot_noise)

	_noise_timer -= delta
	if moving and _noise_timer <= 0.0:
		_noise_timer = 0.4
		NoiseManager.emit_noise(global_position, move_noise, self)


## Called by the weapon controller on every shot.
func register_shot() -> void:
	_model.play_fire()                          # recoil animation
	_shot_noise = NOISE_SHOT
	NoiseManager.emit_noise(global_position, NOISE_SHOT, self)


func stance_text() -> String:
	if healing:
		return "HEALING..."
	if crouching:
		return "CROUCHED"
	if running:
		return "RUNNING"
	return "STANDING"


# --- Health / infection ---------------------------------------------------

func _update_status(delta: float, busy: bool) -> void:
	if infection > 0.0:
		infection = min(100.0, infection + 0.35 * delta)
	if infection >= 100.0:
		_apply_damage(4.0 * delta)
	if not busy and Input.is_action_just_pressed(act("bandage")):
		use_bandage()
	if _heal_left > 0.0:
		var step := minf(delta, _heal_left)
		_heal_left -= step
		health = min(max_health, health + BANDAGE_HEALTH * step / HEAL_TIME)
		infection = max(0.0, infection - BANDAGE_INFECTION * step / HEAL_TIME)
		if _heal_left <= 0.0:
			_heal_particles.restart()           # green burst: healed
			var glow: OmniLight3D = _heal_particles.get_node("HealLight")
			glow.light_energy = 2.5
			create_tween().tween_property(glow, "light_energy", 0.0, 1.2)
			GameManager.notify("Healed")


func take_hit(damage: float, infection_amount: float) -> void:
	if dead:
		return
	infection = min(100.0, infection + infection_amount)
	_apply_damage(damage)
	_hurt_player.play()
	for hud in get_tree().get_nodes_in_group("hud"):
		if hud.target_player() == self:
			hud.flash_damage()


func _apply_damage(amount: float) -> void:
	health = max(0.0, health - amount)
	if health <= 0.0 and not dead:
		dead = true
		revive_left = REVIVE_TIME
		current_prompt = ""
		_heal_left = 0.0
		if _all_players_dead():
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_body_pivot.rotation.x = -PI / 2.0
		_body_pivot.position.y = 0.3
		died.emit()


func use_bandage() -> void:
	if infection <= 0.0 and health >= max_health:
		GameManager.notify("You don't need a bandage")
		return
	if healing:
		return
	if not inventory.take_bandage():
		GameManager.notify("No bandages left")
		return
	_heal_left = HEAL_TIME                      # heals little by little (see _update_status)
	GameManager.notify("Applying bandage...")


## 2 players: while the other player is alive, a fallen player gets up next to them after
## REVIVE_TIME seconds (with half health). If both fall, it is game over.
const REVIVE_TIME := 15.0
var revive_left := 0.0


func _update_down(delta: float) -> void:
	if GameManager.player_count < 2 or _all_players_dead():
		revive_left = REVIVE_TIME
		return
	revive_left -= delta
	if revive_left <= 0.0:
		for p in get_tree().get_nodes_in_group("player"):
			if p != self and not p.dead:
				revive(p.global_position + p.global_basis.x * 1.0)
				break


## Gets up again (2 players).
func revive(at: Vector3, revive_health := 50.0) -> void:
	dead = false
	health = revive_health
	infection = 0.0
	global_position = at
	velocity = Vector3.ZERO
	_body_pivot.rotation.x = 0.0
	_body_pivot.position.y = 0.0
	GameManager.notify("Player %d is back on their feet" % player_number)


func _all_players_dead() -> bool:
	for p in get_tree().get_nodes_in_group("player"):
		if not p.dead:
			return false
	return true


# --- Used by items (cabinets, pickups) and the HUD -------------------------

func add_bandages(amount: int) -> void:
	inventory.add_bandages(amount)


func add_ammo(id: String, amount: int) -> void:
	weapons.add_ammo(id, amount)


func give_weapon(id: String) -> void:
	weapons.give_weapon(id)


func has_weapon(id: String) -> bool:
	return inventory.has_weapon(id)


func weapon_text() -> String:
	return weapons.weapon_text()


# --- Interaction ----------------------------------------------------------

func _update_interaction(busy: bool) -> void:
	var focus: Node = null if busy else _find_focus()
	current_prompt = focus.get_prompt() if focus else ""
	if focus and Input.is_action_just_pressed(act(String(focus.interact_action()).trim_prefix("px_"))):
		focus.interact(self)


func _find_focus() -> Node:
	var forward: Vector3 = camera_rig.forward()
	forward.y = 0.0
	forward = forward.normalized()
	var best: Node = null
	var best_score := INF
	for node in get_tree().get_nodes_in_group("interactable"):
		var to: Vector3 = node.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist > INTERACT_DISTANCE or node.get_prompt() == "":
			continue
		var facing := forward.dot(to.normalized()) if dist > 0.01 else 1.0
		if facing < 0.3:
			continue
		var score := dist - facing
		if score < best_score:
			best_score = score
			best = node
	return best


func _dialogue_busy() -> bool:
	var dialogue := get_tree().get_first_node_in_group("dialogue_ui")
	return dialogue != null and dialogue.is_busy()


# --- Save / load (player.json) -----------------------------------------------

func get_save_data() -> Dictionary:
	return {
		"position": SaveManager.vec3_to_array(global_position),
		"yaw": camera_rig.yaw,
		"pitch": camera_rig.pitch,
		"health": health,
		"infection": infection,
		"flashlight": flashlight_on,
		"current_weapon": weapons.current_weapon,
		"inventory": inventory.get_save_data(),
	}


func load_save_data(data: Dictionary) -> void:
	global_position = SaveManager.array_to_vec3(data.get("position", []))
	velocity = Vector3.ZERO
	camera_rig.yaw = float(data.get("yaw", camera_rig.yaw))
	camera_rig.pitch = float(data.get("pitch", camera_rig.pitch))
	health = float(data.get("health", max_health))
	infection = float(data.get("infection", 0.0))
	inventory.load_save_data(data.get("inventory", {}))
	var weapon: String = data.get("current_weapon", "")
	if weapon != "" and inventory.has_weapon(weapon):
		weapons.equip(weapon)
	set_flashlight(bool(data.get("flashlight", false)))


# --- Flashlight -----------------------------------------------------------

func _on_alarm_started() -> void:
	set_flashlight(true)


func set_flashlight(on: bool) -> void:
	flashlight_on = on
	_flashlight.visible = on
