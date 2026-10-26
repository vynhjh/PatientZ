extends StaticBody3D
## Medical cabinet that can be opened once with [F] (scenes/items/cabinet.tscn).
## The floor scene sets `contents` and `cell` on each instance. Front faces local +Z.

## "syringe", "bandage", "ammo_rifle", "ammo_shotgun", "keycard" or "" (empty)
@export var contents := ""
@export var cell := Vector2i(-1, -1)      # map cell, used as the cabinet id in the save
## How much it gives (0 = default: 1 bandage · 24 rifle rounds · 8 shotgun shells).
@export var amount := 0

var is_open := false

@onready var _hinge: Node3D = %Hinge


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("cabinets")
	%Syringe.visible = contents == "syringe"
	%Bandages.visible = contents == "bandage"
	%Keycard.visible = contents == "keycard"
	%AmmoBox.visible = contents.begins_with("ammo")


func get_prompt() -> String:
	return "" if is_open else "[F] open"


func interact_action() -> StringName:
	return &"px_interact"


func interact(player: Node) -> void:
	if is_open:
		return
	is_open = true
	remove_from_group("interactable")
	var tween := create_tween()
	tween.tween_property(_hinge, "rotation:y", -1.9, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if contents == "syringe":
		_take_item(%Syringe)
	elif contents == "bandage":
		_take_item(%Bandages)
	elif contents == "keycard":
		_take_item(%Keycard)
	_give_contents(player)


## Opened cabinet without giving the item again (used when loading a save).
func open_silently() -> void:
	is_open = true
	remove_from_group("interactable")
	_hinge.rotation.y = -1.9
	%Syringe.visible = false
	%Bandages.visible = false
	%Keycard.visible = false


## The item on the shelf (syringe.tscn / bandage.tscn) is seen for a moment, then rises and
## vanishes (taken).
func _take_item(item: Node3D) -> void:
	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(item, "position:y", item.position.y + 0.25, 0.5).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(item, "scale", Vector3.ZERO, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(item.hide)


func _give_contents(player: Node) -> void:
	match contents:
		"syringe":
			GameManager.add_syringe()
			GameManager.notify("Syringe found (%d/%d)" % [GameManager.syringes, GameManager.SYRINGES_NEEDED])
		"keycard":
			GameManager.give_keycard()
		"bandage":
			var n := amount if amount > 0 else 1
			player.add_bandages(n)
			GameManager.notify("Bandage found" if n == 1 else "%d bandages found" % n)
		"ammo_rifle":
			player.add_ammo("rifle", amount if amount > 0 else 24)
		"ammo_shotgun":
			player.add_ammo("shotgun", amount if amount > 0 else 8)
		_:
			GameManager.notify("Empty...")
