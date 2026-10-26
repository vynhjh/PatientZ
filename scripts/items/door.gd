extends StaticBody3D
## Sliding lab door (scenes/items/door.tscn).
## The floor scene sets `cell` and `kind` on each instance:
##   start   – Floor 1: opens after talking to the boss
##   keycard – Floor 1: needs the keycard
##   normal  – always opens with [F]
##   cleared – opens when every infected of the floor is dead
##   boss    – opens when the mini-boss is dead
##   sealed  – never opens (shows `sealed_text`)

signal opened(cell: Vector2i)

@export var cell := Vector2i.ZERO
@export_enum("start", "keycard", "normal", "cleared", "boss", "sealed") var kind := "start"
@export var sealed_text := "Sealed"
@export var slide_height := 3.2

var is_open := false

@onready var _panel: Node3D = %Panel
@onready var _stripe: MeshInstance3D = %Stripe
@onready var _shape: CollisionShape3D = %CollisionShape3D
@onready var _reader_mat: StandardMaterial3D = %ReaderFront.material_override


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("doors")
	var stripe_mat: StandardMaterial3D = _stripe.material_override
	var stripe_colors := {
		"start": Color(0.15, 0.55, 0.9), "normal": Color(0.15, 0.55, 0.9), "keycard": Color(0.9, 0.55, 0.1),
		"cleared": Color(0.85, 0.1, 0.1), "boss": Color(0.85, 0.1, 0.1), "sealed": Color(0.3, 0.3, 0.3),
	}
	stripe_mat.albedo_color = stripe_colors.get(kind, Color(0.9, 0.55, 0.1))


func _process(_delta: float) -> void:
	if is_open:
		return
	var color := Color.GREEN if _can_open() else Color.RED
	_reader_mat.albedo_color = color
	_reader_mat.emission = color


func get_prompt() -> String:
	if is_open:
		return ""
	match kind:
		"normal":
			return "[F] Open"
		"cleared":
			if _can_open():
				return "[F] Open the containment door"
			return "Locked · Clear the infected rooms (%d/%d)" % [GameManager.kills, GameManager.kill_target]
		"boss":
			return "[F] Open" if _can_open() else "Locked · Kill the Brute first"
		"sealed":
			return sealed_text
	if kind == "start":
		if GameManager.phase == GameManager.Phase.INTRO:
			return "Locked · Talk to your boss first"
		return "[F] Open"
	if not GameManager.has_keycard:
		return "[F] Locked · Keycard required"
	return "[F] to open the door"


func interact_action() -> StringName:
	return &"px_interact"


func interact(_player: Node) -> void:
	if is_open:
		return
	if not _can_open():
		if kind in ["cleared", "boss", "sealed"]:
			GameManager.notify(get_prompt().replace("Locked · ", "") + ".")
		elif kind == "start":
			GameManager.notify("Talk to your boss first.")
		else:
			GameManager.notify("You need a keycard to open this door.")
		return
	open()


func open() -> void:
	if is_open:
		return
	is_open = true
	remove_from_group("interactable")
	_shape.set_deferred("disabled", true)
	_reader_mat.albedo_color = Color.GREEN
	_reader_mat.emission = Color.GREEN
	var tween := create_tween()
	tween.tween_property(_panel, "position:y", slide_height - 0.15, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	opened.emit(cell)


func _can_open() -> bool:
	match kind:
		"normal":
			return true
		"cleared":
			return GameManager.kill_target > 0 and GameManager.kills >= GameManager.kill_target
		"boss":
			return GameManager.miniboss_dead
		"sealed":
			return false
	if kind == "start":
		return GameManager.phase != GameManager.Phase.INTRO
	return GameManager.has_keycard
