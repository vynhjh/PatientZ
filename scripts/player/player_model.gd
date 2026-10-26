extends Node3D
## Player model and its animation (PlayerModel in scenes/player/player.tscn).
##
## Nodes in the scene:
##   Model           → assets/player/Walking.fbx (instance, Editable Children on)
##   Model/AnimationTree → libraries: player_base.tres (walk) + player_guns.tres (rifle, shotgun)
##   …/Skeleton3D/AimTwist → aim_twist_modifier.gd
##
## The AnimationTree mixes the animations: the legs keep walking (or stand still) and,
## with a weapon, the spine, arms and head take the weapon pose ("arms" Blend2 with a bone
## filter). Each shot plays the weapon animation once (recoil, "<weapon>_shot" OneShot).
## The Mixamo models face +Z; the Model node is turned 180° in the scene.

const UPPER_BODY_BONE := "Spine_02"
const RIGHT_HAND_BONE := "RightHand_013"
const LEFT_HAND_BONE := "LeftHand_039"
const RIGHT_PALM_BONE := "RightHandMiddle1_024"
const LEFT_PALM_BONE := "LeftHandMiddle1_050"
const RIGHT_FOREARM_BONE := "RightForeArm_012"
const RIGHT_ARM_BONE := "RightArm_011"
const LEFT_ARM_BONE := "LeftArm_037"
const WEAPON_IDS := ["rifle", "shotgun"]

const WALK_ANIM_SPEED := 1.0       # animation speed at walking speed
const RUN_ANIM_SPEED := 1.0        # "run" animation (Running.fbx) at running speed
const CROUCH_ANIM_SPEED := 0.6
const ARMS_BLEND_SPEED := 6.0      # how fast the arms go to / leave the weapon pose

## Not shooting: the gun is carried lowered (walking with the weapon in hand).
## Shooting or aiming ([Right click]) raises it; it stays up AIM_HOLD_TIME after the last shot.
const LOWER_ANGLE := deg_to_rad(38.0)
const AIM_HOLD_TIME := 1.5
const RAISE_SPEED := 9.0
const LOWER_SPEED := 2.5

## Visual layer 2: blood decals (layer 1) don't stain the characters.
const CHARACTER_LAYER := 2

var current_weapon := ""
var aiming := false                # set by the player ([Right click])
var running := false               # full running animation: weapon in one hand, no shooting
var skeleton: Skeleton3D

var _weapon_ids: Array = []        # weapons that have an animation in the tree
var _stance_yaw := {}              # weapon id -> turn of the shooting stance (radians)
var _arms_blend := 0.0
var _locomotion := ""
var _lowered := 1.0                # 1 = gun lowered, 0 = aiming
var _since_fire := 100.0

@onready var model: Node3D = $Model
@onready var _tree: AnimationTree = %AnimationTree
@onready var _aim_twist: SkeletonModifier3D = %AimTwist


func _ready() -> void:
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	for id in WEAPON_IDS:
		if _tree.has_animation("guns/" + id):
			_weapon_ids.append(id)
			_stance_yaw[id] = _root_yaw(_tree.get_animation("guns/" + id))
	_aim_twist.setup(skeleton.find_bone(UPPER_BODY_BONE), skeleton.find_bone(RIGHT_HAND_BONE), skeleton.find_bone(LEFT_HAND_BONE), skeleton.find_bone(RIGHT_ARM_BONE), skeleton.find_bone(LEFT_ARM_BONE),
			skeleton.find_bone(RIGHT_PALM_BONE), skeleton.find_bone(LEFT_PALM_BONE))
	_aim_twist.right_forearm = skeleton.find_bone(RIGHT_FOREARM_BONE)
	_aim_twist.influence = 0.0
	_set_layers(self)


func _process(delta: float) -> void:
	var target := 1.0 if _weapon_ids.has(current_weapon) and not running else 0.0
	_arms_blend = move_toward(_arms_blend, target, ARMS_BLEND_SPEED * delta)
	_tree.set("parameters/arms/blend_amount", _arms_blend)
	_aim_twist.influence = maxf(_arms_blend, 0.01)
	_aim_twist.one_hand = false
	_aim_twist.twist_angle = lerp_angle(_aim_twist.twist_angle, _stance_yaw.get(current_weapon, 0.0), minf(1.0, 10.0 * delta))
	_since_fire += delta
	var raised := aiming or _since_fire < AIM_HOLD_TIME
	_lowered = move_toward(_lowered, 0.0 if raised else 1.0, (RAISE_SPEED if raised else LOWER_SPEED) * delta)
	_aim_twist.lower_angle = LOWER_ANGLE * smoothstep(0.0, 1.0, _lowered)


# --- Public API (used by player_stealth.gd) ----------------------------------------

## Locomotion (whole body, the weapon pose goes on top): "idle" standing still (Standing W
## Briefcase Idle), "walk" walking or crouching, "run" running (Running).
func update_animation(horizontal_speed: float, is_running: bool, crouching: bool) -> void:
	running = is_running and horizontal_speed >= 0.3
	var state := "idle"
	if horizontal_speed >= 0.3:
		state = "run" if running else "walk"
	if state != _locomotion:
		_locomotion = state
		_tree.set("parameters/locomotion/transition_request", state)
	_tree.set("parameters/walk_speed/scale", CROUCH_ANIM_SPEED if crouching else WALK_ANIM_SPEED)
	_tree.set("parameters/run_speed/scale", RUN_ANIM_SPEED)


## "" = unarmed. Switches the upper body to that weapon's pose.
func set_weapon(id: String) -> void:
	if id == current_weapon:
		return
	current_weapon = id
	if _weapon_ids.has(id):
		_tree.set("parameters/weapon/transition_request", id)


## Recoil: plays the weapon animation once.
func play_fire() -> void:
	_since_fire = 0.0
	_lowered = minf(_lowered, 0.3)     # the gun snaps up for the shot
	if _weapon_ids.has(current_weapon):
		_tree.set("parameters/%s_shot/request" % current_weapon, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## The player's node that carries the gun models and the muzzle flash.
func set_gun_socket(socket: Node3D) -> void:
	_aim_twist.gun_socket = socket


## The gun is shown only while it is held with both hands (not while running: it is put away
## and comes back when the arms are in the weapon pose again).
func gun_in_hands() -> bool:
	return current_weapon != "" and not running and _arms_blend >= 0.6


## Player 2's coat colour: only the white parts of the texture (the lab coat) are tinted.
func tint(color: Color) -> void:
	var shader: Shader = load("res://assets/shaders/coat_tint.gdshader")
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var mat := mesh.get_active_material(i)
			if mat is StandardMaterial3D and mat.albedo_texture:
				var coat := ShaderMaterial.new()
				coat.shader = shader
				coat.set_shader_parameter("albedo_tex", mat.albedo_texture)
				coat.set_shader_parameter("coat_tint", color)
				mesh.set_surface_override_material(i, coat)


func has_weapon_animations() -> bool:
	return not _weapon_ids.is_empty()


# --- Helpers ------------------------------------------------------------------------

## Turn of the shooting stance: rotation (yaw) of the model's root node in the weapon animation.
## Its track is the rotation track whose path has no ":" (a node, not a bone).
func _root_yaw(anim: Animation) -> float:
	for t in anim.get_track_count():
		if anim.track_get_type(t) == Animation.TYPE_ROTATION_3D and not ":" in str(anim.track_get_path(t)):
			var q: Quaternion = anim.track_get_key_value(t, 0)
			return Basis(q).get_euler().y
	return 0.0


func _set_layers(node: Node) -> void:
	if node is VisualInstance3D and not node is Light3D:
		node.layers = CHARACTER_LAYER
	for child in node.get_children():
		_set_layers(child)
