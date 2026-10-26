extends "res://scripts/enemies/infectado_ai.gd"
## Floor 2 mini-boss "The Brute" (scenes/enemies/mini_boss.tscn), in the penultimate room.
## Uses the infected AI (paths, sight, hearing, room activation) with its own rules:
##   · very tough: rifle bullets only do RIFLE_FACTOR of their damage
##   · weak to the shotgun at close range (SHOTGUN_FACTOR within SHOTGUN_RANGE metres)
##   · every hit takes HIT_DAMAGE of the player's 100 HP
##   · its death is not one of the 35 infected: it opens the room with the stairs to Floor 3

const MAX_HEALTH := 1600.0
const HIT_DAMAGE := 40.0
const RIFLE_FACTOR := 0.6
const SHOTGUN_FACTOR := 2.5
const SHOTGUN_RANGE := 6.0
const TINT := Color(1.0, 0.55, 0.5)       # reddish skin


func _ready() -> void:
	super._ready()
	max_health = MAX_HEALTH * GameManager.enemy_health_mult()
	health = max_health
	chase_speed = 3.4
	walk_speed = 1.3
	attack_damage = HIT_DAMAGE * GameManager.enemy_damage_mult()
	attack_infection = 10.0
	attack_range = 2.2
	attack_cooldown = 1.6
	sight_range = 22.0
	%PatientZGlow.visible = true             # red glow of the boss
	_apply_tint(TINT)


func take_damage(amount: float, hit_position: Vector3) -> void:
	if state == State.DEAD:
		return
	if _player == null:
		_player = _nearest_player()
	var factor := RIFLE_FACTOR
	if _player and _player.weapons.current_weapon == "shotgun":
		factor = SHOTGUN_FACTOR if _flat_distance(_player.global_position) <= SHOTGUN_RANGE else 1.0
	super.take_damage(amount * factor, hit_position)


func _on_killed() -> void:
	GameManager.register_miniboss_kill()


## Health shown on the HUD (0-1).
func health_ratio() -> float:
	return clampf(health / max_health, 0.0, 1.0)
