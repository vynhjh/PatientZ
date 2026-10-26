extends Node
## Player settings (autoload "Settings"), saved in user://settings.cfg.
##   Volume: "Master" (everything) and "Music" (menu music + background soundtrack).
## The buses are in default_bus_layout.tres; music players use the "Music" bus.

const FILE := "user://settings.cfg"

var volumes := {"Master": 1.0, "Music": 1.0}      # 0.0 - 1.0


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(FILE) == OK:
		for bus in volumes:
			volumes[bus] = clampf(float(cfg.get_value("volume", bus, volumes[bus])), 0.0, 1.0)
	for bus in volumes:
		_apply(bus)


func get_volume(bus: String) -> float:
	return volumes.get(bus, 1.0)


## value: 0.0 (silent) - 1.0 (full). Applied at once and saved.
func set_volume(bus: String, value: float) -> void:
	volumes[bus] = clampf(value, 0.0, 1.0)
	_apply(bus)
	var cfg := ConfigFile.new()
	cfg.load(FILE)
	cfg.set_value("volume", bus, volumes[bus])
	cfg.save(FILE)


func _apply(bus: String) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volumes[bus], 0.0001)))
	AudioServer.set_bus_mute(index, volumes[bus] <= 0.001)
