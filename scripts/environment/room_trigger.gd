extends Area3D
## Room activation area (Floor 2). One per room: its CollisionShape3D covers the room behind
## the door. The infected of the room (children of `infected_group`) stay dormant until the
## player enters this area; then they all wake up and hunt.
##
## Set in the Inspector: room_name (shown when you enter) and infected_group (the node with
## the room's infected, for example ../../Infected/Room4).

signal room_entered(room_name: String)

@export var room_name := "Room"
@export var infected_group: NodePath
@export var announce := true

var activated := false


func _ready() -> void:
	add_to_group("room_triggers")
	collision_layer = 0
	collision_mask = 2            # the player's layer
	monitorable = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if activated or not body.is_in_group("player"):
		return
	activate()
	if announce:
		GameManager.notify(room_name)


## Wakes every infected of the room (also used when loading a saved game).
func activate(alert := true) -> void:
	activated = true
	room_entered.emit(room_name)
	var group := get_node_or_null(infected_group)
	if group == null:
		return
	for zombie in group.get_children():
		if zombie.has_method("wake"):
			zombie.wake(alert)
