extends Node3D
## Ceiling lamp (scenes/environment/lamp.tscn). Turn on `flicker` in the Inspector for a broken
## lamp that blinks. During the alarm the AlarmSystem controls every lamp, so it stops blinking.

@export var flicker := false

var _base_energy := 1.0
var _timer := 0.0

@onready var _light: OmniLight3D = %Light


func _ready() -> void:
	_base_energy = _light.light_energy
	set_process(flicker)


func _process(delta: float) -> void:
	if GameManager.phase >= GameManager.Phase.SURVIVE:
		set_process(false)
		return
	_timer -= delta
	if _timer > 0.0:
		return
	# Mostly on, with short bursts of blinking
	if randf() < 0.25:
		_light.light_energy = _base_energy * randf_range(0.0, 0.3)
		_timer = randf_range(0.03, 0.12)
	else:
		_light.light_energy = _base_energy * randf_range(0.8, 1.0)
		_timer = randf_range(0.05, 1.5)
