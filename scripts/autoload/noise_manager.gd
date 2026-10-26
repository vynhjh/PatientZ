extends Node
## Broadcasts noises so the infected can hear them. Register as autoload "NoiseManager".

signal noise_emitted(position: Vector3, radius: float, source: Node)


func emit_noise(position: Vector3, radius: float, source: Node = null) -> void:
	if radius > 0.0:
		noise_emitted.emit(position, radius, source)
