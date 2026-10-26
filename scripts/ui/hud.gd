extends CanvasLayer
## Player HUD (scenes/ui/hud.tscn). Reads the player every frame. [H] hides it.
## The layout (labels, health bar, crosshair, death screen) is edited in the scene;
## this script only fills in the texts.

## Which player this HUD shows (split screen: one HUD per half).
@export_range(1, 2) var player_number := 1

var _player: Node = null
var _toast_time := 0.0
var _alarm := false

@onready var _root: Control = %Root
@onready var _health_label: Label = %HealthLabel
@onready var _health_bar: ProgressBar = %HealthBar
@onready var _infection_label: Label = %InfectionLabel
@onready var _kills_label: Label = %KillsLabel
@onready var _stance_label: Label = %StanceLabel
@onready var _weapon_label: Label = %WeaponLabel
@onready var _objective_label: Label = %ObjectiveLabel
@onready var _prompt_label: Label = %PromptLabel
@onready var _slot_rifle = %SlotRifle
@onready var _slot_shotgun = %SlotShotgun
@onready var _slot_bandages = %SlotBandages
@onready var _slot_syringes = %SlotSyringes
@onready var _slot_keycard = %SlotKeycard
@onready var _toast_label: Label = %ToastLabel
@onready var _flash: ColorRect = %Flash
@onready var _alarm_tint: ColorRect = %AlarmTint
@onready var _death_panel: Control = %DeathPanel
@onready var _died_label: Label = %DiedLabel


func _ready() -> void:
	add_to_group("hud")
	if GameManager.player_count >= 2:
		$Root/ControlsLabel.visible = false          # too long for half a screen
	GameManager.message.connect(show_toast)
	GameManager.alarm_started.connect(_on_alarm_started)
	SaveManager.game_loaded.connect(_on_game_loaded)


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = null
		for p in get_tree().get_nodes_in_group("player"):
			if p.player_number == player_number:
				_player = p
		if _player == null:
			return

	if Input.is_action_just_pressed("px_toggle_hud"):
		_root.visible = not _root.visible

	var p = _player
	_health_label.text = "HEALTH %d/%d" % [ceili(p.health), int(p.max_health)]
	_health_bar.max_value = p.max_health
	_health_bar.value = p.health

	var infection_text := "INFECTION %d%%" % int(p.infection)
	if p.infection > 0.0:
		infection_text += " · use BANDAGES (%d)" % p.bandages
	_infection_label.text = infection_text
	_infection_label.modulate = Color(0.6, 1.0, 0.4) if p.infection > 0.0 else Color(1, 1, 1, 0.7)

	_kills_label.text = "INFECTED %d / %d" % [GameManager.kills, GameManager.kill_target]
	_stance_label.text = "%s · noise %d m" % [p.stance_text(), roundi(p.noise_radius)]
	_weapon_label.text = p.weapon_text()
	_objective_label.text = "OBJECTIVE: " + GameManager.objective_text()
	_prompt_label.text = p.current_prompt
	_update_slots(p)

	_toast_time -= delta
	_toast_label.modulate.a = clamp(_toast_time, 0.0, 1.0)

	_flash.color.a = move_toward(_flash.color.a, 0.0, delta * 1.5)
	if _alarm:
		_alarm_tint.color.a = 0.03 + 0.03 * sin(Time.get_ticks_msec() / 1000.0 * 4.0)
	if p.dead:
		if p._all_players_dead():
			var key := "[R / A]" if GameManager.player_count >= 2 else "[R]"
			_died_label.text = ("YOU DIED\n%s Load last save" if SaveManager.has_save() else "YOU DIED\n%s Restart") % key
		else:
			_died_label.text = "YOU ARE DOWN\nBack up next to your partner in %d s" % ceili(p.revive_left)
	_death_panel.visible = p.dead


func _on_alarm_started() -> void:
	_alarm = true


func _on_game_loaded(_slot_id: String) -> void:
	_alarm = GameManager.phase >= GameManager.Phase.SURVIVE


func show_toast(text: String) -> void:
	_toast_label.text = text
	_toast_time = 3.5


func target_player() -> Node:
	return _player


func flash_damage() -> void:
	_flash.color.a = 0.45


## Item bar: weapons, bandages, syringes (Floor 1 mission) and the keycard.
func _update_slots(p) -> void:
	var rifle_ammo := ""
	if p.has_weapon("rifle"):
		rifle_ammo = "%d | %d" % [p.inventory.ammo["rifle"]["mag"], p.inventory.ammo["rifle"]["reserve"]]
	var shotgun_ammo := ""
	if p.has_weapon("shotgun"):
		shotgun_ammo = "%d | %d" % [p.inventory.ammo["shotgun"]["mag"], p.inventory.ammo["shotgun"]["reserve"]]
	_slot_rifle.set_state(p.has_weapon("rifle"), p.current_weapon == "rifle", rifle_ammo)
	_slot_shotgun.set_state(p.has_weapon("shotgun"), p.current_weapon == "shotgun", shotgun_ammo)
	_slot_bandages.set_state(p.bandages > 0, p.healing, "x%d" % p.bandages)
	var show_syringes := GameManager.floor_number == 1 and (GameManager.phase == GameManager.Phase.COLLECT or GameManager.syringes > 0)
	_slot_syringes.visible = show_syringes
	_slot_syringes.set_state(GameManager.syringes > 0, false, "%d / %d" % [GameManager.syringes, GameManager.SYRINGES_NEEDED])
	_slot_keycard.set_state(GameManager.has_keycard, false, "Keycard" if GameManager.has_keycard else "")
