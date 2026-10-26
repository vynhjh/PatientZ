extends SkeletonModifier3D
## Upper-body twist for the weapon poses + gun placement.
##
## In the Mixamo "Gunplay" animations the whole character is turned (shooting stance) by the
## rotation of the model's root node, and the arms point forward thanks to that turn. The game
## keeps the root and the legs from the walk animation, so this modifier gives that same turn
## (twist_angle, read from each weapon animation) only to the spine: the arms aim forward again
## while the legs keep walking forward.
## lower_angle lowers the weapon (walking with the gun in hand, not aiming): both arms turn
## together around the line through the two shoulders, so the hands keep holding the gun.
## After that it puts the gun socket in the right hand, pointing to the left hand.
## The engine blends the result with `influence` (0 = unarmed, 1 = weapon pose).

var spine_bone := -1
var right_hand := -1
var left_hand := -1
var right_arm := -1
var left_arm := -1
var right_palm := -1            # middle finger root bones: with the wrist they give the palm
var left_palm := -1
var lower_angle := 0.0          # radians, > 0 points the gun towards the floor
## Running: the gun is held with the right hand only, along the forearm (the arms swing freely).
var one_hand := false
var right_forearm := -1
const RUN_GUN_PITCH := 0.75     # radians below the horizon while running
var twist_angle := 0.0          # radians around the vertical axis
var gun_socket: Node3D = null   # player's "Hand" node


func setup(spine: int, right: int, left: int, r_arm := -1, l_arm := -1, r_palm := -1, l_palm := -1) -> void:
	spine_bone = spine
	right_hand = right
	left_hand = left
	right_arm = r_arm
	left_arm = l_arm
	right_palm = r_palm
	left_palm = l_palm


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or spine_bone < 0:
		return
	# Vertical axis expressed in skeleton space
	var up := (skeleton.global_basis.inverse() * Vector3.UP).normalized()
	if absf(twist_angle) > 0.001:
		var parent := skeleton.get_bone_parent(spine_bone)
		var parent_rot := skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
		var twist := Quaternion(up, twist_angle)
		var local := skeleton.get_bone_pose_rotation(spine_bone)
		skeleton.set_bone_pose_rotation(spine_bone, parent_rot.inverse() * twist * parent_rot * local)
	_lower_arms(skeleton)
	_place_gun(skeleton)


func _lower_arms(skeleton: Skeleton3D) -> void:
	if right_arm < 0 or left_arm < 0 or absf(lower_angle) < 0.001:
		return
	var r_pose := skeleton.get_bone_global_pose(right_arm)
	var l_pose := skeleton.get_bone_global_pose(left_arm)
	var axis := l_pose.origin - r_pose.origin
	if axis.length() < 0.01:
		return
	# Half shoulder line (hands stay on the gun), half body side axis (the muzzle points down)
	var side := Vector3.RIGHT if axis.x >= 0.0 else Vector3.LEFT
	axis = (axis.normalized() + side).normalized()
	var pivot := (r_pose.origin + l_pose.origin) * 0.5
	var rot := Basis(axis, lower_angle)
	var turn := Transform3D(rot, pivot - rot * pivot)
	skeleton.set_bone_global_pose(right_arm, turn * r_pose)
	skeleton.set_bone_global_pose(left_arm, turn * l_pose)


func _place_gun(skeleton: Skeleton3D) -> void:
	if gun_socket == null or right_hand < 0 or left_hand < 0:
		return
	if one_hand and right_forearm >= 0:
		# in the right hand, steady: barrel forward and down (the hand swings with the run)
		var palm := _palm(skeleton, right_hand, right_palm)
		var forward := skeleton.global_basis.z
		forward.y = 0.0
		if forward.length() > 0.01:
			var dir := (forward.normalized() * cos(RUN_GUN_PITCH) + Vector3.DOWN * sin(RUN_GUN_PITCH)).normalized()
			gun_socket.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), palm)
		return
	if influence < 0.5:
		return
	var right := _palm(skeleton, right_hand, right_palm)
	var left := _palm(skeleton, left_hand, left_palm)
	var forward := left - right
	if forward.length() < 0.05:
		return
	gun_socket.global_transform = Transform3D(Basis.looking_at(forward, Vector3.UP), right)


## Centre of the palm (between the wrist and the root of the middle finger), in world space.
func _palm(skeleton: Skeleton3D, wrist: int, finger: int) -> Vector3:
	var p := skeleton.get_bone_global_pose(wrist).origin
	if finger >= 0:
		p = p.lerp(skeleton.get_bone_global_pose(finger).origin, 0.6)
	return skeleton.global_transform * p
