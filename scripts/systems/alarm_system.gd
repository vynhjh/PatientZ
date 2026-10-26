extends Node
## Emergency alarm (AlarmSystem node in the floor scene): turns every lamp red, pulses them
## and plays the siren (child node "Siren", assets/audio/sfx/alarm_siren.wav, looped).
## If ALARM_SOUND exists (e.g. you drop "alarm.mp3" in assets/audio) it replaces the siren.
## The floor registers its lamps, then calls start() when the boss gets the syringes.

const Config = preload("res://scripts/systems/level_config.gd")

const ALARM_SOUND := "res://assets/audio/alarm.mp3"
const ALARM_SECONDS := 25.0     # how long the alarm sounds (0 = forever)
const ALARM_VOLUME_DB := -10.0

signal alarm_finished

var active := false
## Multiplies the brightness of the red lamps (Floor 2 has more lamps and is darker: 0.22).
@export var energy_scale := 1.0

var _env: Environment
var _lamp_mat: StandardMaterial3D
var _lamps: Array[OmniLight3D] = []
var _lamp_phase: Array[float] = []
var _time := 0.0
var _sounding := false

@onready var _player: AudioStreamPlayer = %Siren


func setup(env: Environment, lamp_mat: StandardMaterial3D) -> void:
	_env = env
	_lamp_mat = lamp_mat


func register_lamp(light: OmniLight3D) -> void:
	_lamps.append(light)
	_lamp_phase.append(randf() * TAU)


func start(play_sound := true) -> void:
	active = true
	_time = 0.0
	for light in _lamps:
		light.light_color = Config.LIGHT_ALARM
	if _lamp_mat:
		_lamp_mat.albedo_color = Config.LIGHT_ALARM
		_lamp_mat.emission = Config.LIGHT_ALARM
	if _env:
		_env.ambient_light_color = Config.AMBIENT_ALARM
		_env.ambient_light_energy = Config.AMBIENT_ALARM_ENERGY
		_env.fog_enabled = true
		_env.fog_light_color = Color(0.12, 0.0, 0.0)
		_env.fog_density = Config.ALARM_FOG_DENSITY
		_env.glow_intensity = 0.9
	if play_sound:
		_start_sound()


func _start_sound() -> void:
	_sounding = true
	_player.volume_db = ALARM_VOLUME_DB
	if ResourceLoader.exists(ALARM_SOUND):
		var stream: AudioStream = load(ALARM_SOUND)
		if "loop" in stream:
			stream.loop = true
		_player.stream = stream
	_player.play()


func stop_sound() -> void:
	if not _sounding:
		return
	_sounding = false
	_player.stop()
	alarm_finished.emit()


func _process(delta: float) -> void:
	if not active:
		return
	_time += delta
	# Red lights pulsing
	for i in _lamps.size():
		var pulse := 0.5 + 0.5 * sin(_time * 4.0 + _lamp_phase[i])
		_lamps[i].light_energy = (Config.ALARM_LIGHT_MIN + (Config.ALARM_LIGHT_MAX - Config.ALARM_LIGHT_MIN) * pulse) * energy_scale
	if _lamp_mat:
		_lamp_mat.emission_energy_multiplier = (0.6 + 2.0 * (0.5 + 0.5 * sin(_time * 4.0))) * energy_scale

	if not _sounding:
		return
	if ALARM_SECONDS > 0.0 and _time > ALARM_SECONDS:
		stop_sound()
		return
	# Fade out during the last 3 seconds
	if ALARM_SECONDS > 0.0:
		var fade := clampf((ALARM_SECONDS - _time) / 3.0, 0.0, 1.0)
		_player.volume_db = ALARM_VOLUME_DB + linear_to_db(maxf(fade, 0.001))
