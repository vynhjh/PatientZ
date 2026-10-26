extends Node
## Global game state for Patient Z. Register as autoload "GameManager".

signal phase_changed(phase: int)
signal syringes_changed(count: int)
signal kills_changed(kills: int, target: int)
signal alarm_started
signal keycard_obtained
signal rifle_obtained
signal message(text: String)
signal miniboss_killed
signal final_boss_killed

const MAIN_SCENE := "res://main.tscn"

enum Phase { INTRO, COLLECT, SURVIVE, CLEARED }

const SYRINGES_NEEDED := 5

var phase: int = Phase.INTRO
var syringes := 0
var has_keycard := false
var kills := 0
var kill_target := 0
var has_rifle := false
var floor_number := 1          # 1 = Underground Lab · 2 = Containment Spiral
## 1 or 2 (split screen). Chosen in the main menu, saved with the game.
var player_count := 1
var miniboss_dead := false     # Floor 2
var final_boss_dead := false   # Floor 3: Patient Z

## Floor change: the next floor that main.tscn must open, and the player's state to bring along
## (health, infection, weapons, ammo, bandages, flashlight).
var next_floor_scene := ""
var carry_player := {}
var carry_player2 := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input_actions()


## [F11] switches between full screen and a window (full screen is set in Project Settings:
## Display > Window > Size > Mode = Fullscreen).
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("px_fullscreen"):
		var full := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)


## Called by each floor when it loads.
func reset_floor(target_kills: int, number := 1) -> void:
	floor_number = number
	miniboss_dead = false
	final_boss_dead = false
	phase = Phase.INTRO
	syringes = 0
	has_keycard = false
	kills = 0
	kill_target = target_kills
	has_rifle = false
	phase_changed.emit(phase)
	syringes_changed.emit(syringes)
	kills_changed.emit(kills, kill_target)


func set_phase(new_phase: int) -> void:
	phase = new_phase
	phase_changed.emit(phase)


func add_syringe() -> void:
	syringes += 1
	syringes_changed.emit(syringes)


func has_all_syringes() -> bool:
	return syringes >= SYRINGES_NEEDED


## Boss takes the syringes and the emergency starts.
func deliver_syringes() -> void:
	syringes = 0
	syringes_changed.emit(syringes)
	set_phase(Phase.SURVIVE)
	alarm_started.emit()


func give_keycard() -> void:
	has_keycard = true
	keycard_obtained.emit()
	notify("Keycard obtained")


func register_kill() -> void:
	kills += 1
	kills_changed.emit(kills, kill_target)
	if floor_number == 1 and phase == Phase.SURVIVE and kills >= kill_target:
		set_phase(Phase.CLEARED)
		notify("Floor cleared! The stairs to Floor 2 are unlocked.")
	elif floor_number == 2 and kills == kill_target:
		notify("All infected rooms cleared! The containment door is open.")
	elif floor_number == 3 and kills == kill_target:
		notify("All infected cleared! The Containment Core is open: Patient Z is waiting.")


## Floor 3: Patient Z is dead, the game is won.
func register_final_boss_kill() -> void:
	final_boss_dead = true
	set_phase(Phase.CLEARED)
	final_boss_killed.emit()
	notify("PATIENT Z IS DEAD. You survived.")


## Floor 2: the mini-boss is dead, the room with the stairs to Floor 3 opens.
func register_miniboss_kill() -> void:
	miniboss_dead = true
	miniboss_killed.emit()
	set_phase(Phase.CLEARED)
	notify("The Brute is dead! The stairs to Floor 3 are open.")


## Difficulty with 2 players: the infected have more health, hit harder and run a bit faster.
func enemy_health_mult() -> float:
	return 1.6 if player_count >= 2 else 1.0


func enemy_damage_mult() -> float:
	return 1.3 if player_count >= 2 else 1.0


func enemy_speed_mult() -> float:
	return 1.1 if player_count >= 2 else 1.0


## Goes to another floor keeping the player's state (called by the stairs).
func go_to_floor(scene_path: String, player: Node) -> void:
	carry_player2 = {}
	for p in get_tree().get_nodes_in_group("player"):
		if p.player_number == 1:
			carry_player = p.get_save_data()
		else:
			carry_player2 = p.get_save_data()
	if player and carry_player.is_empty():
		carry_player = player.get_save_data()
	next_floor_scene = scene_path
	get_tree().change_scene_to_file(MAIN_SCENE)


func set_has_rifle() -> void:
	if has_rifle:
		return
	has_rifle = true
	rifle_obtained.emit()


## --- Save / load (used by SaveManager → progress.json) ---

func get_save_data() -> Dictionary:
	return {
		"phase": phase,
		"syringes": syringes,
		"has_keycard": has_keycard,
		"kills": kills,
		"kill_target": kill_target,
		"has_rifle": has_rifle,
		"floor_number": floor_number,
		"player_count": player_count,
		"miniboss_dead": miniboss_dead,
		"final_boss_dead": final_boss_dead,
	}


func load_save_data(data: Dictionary) -> void:
	phase = int(data.get("phase", Phase.INTRO))
	syringes = int(data.get("syringes", 0))
	has_keycard = bool(data.get("has_keycard", false))
	kills = int(data.get("kills", 0))
	kill_target = int(data.get("kill_target", kill_target))
	has_rifle = bool(data.get("has_rifle", false))
	floor_number = int(data.get("floor_number", floor_number))
	player_count = int(data.get("player_count", player_count))
	miniboss_dead = bool(data.get("miniboss_dead", false))
	final_boss_dead = bool(data.get("final_boss_dead", false))
	phase_changed.emit(phase)
	syringes_changed.emit(syringes)
	kills_changed.emit(kills, kill_target)


func can_use_stairs() -> bool:
	if floor_number >= 3:
		return false
	if floor_number == 2:
		return miniboss_dead
	return phase == Phase.CLEARED


func objective_text() -> String:
	if floor_number == 3:
		if final_boss_dead:
			return "Patient Z is dead · You survived"
		if kills >= kill_target:
			return "FLOOR 3: Kill Patient Z in the Containment Core"
		if not has_keycard:
			return "FLOOR 3: Find the security keycard · Infected %d / %d" % [kills, kill_target]
		return "FLOOR 3: Clear the infected and reach Patient Z (%d / %d Infected)" % [kills, kill_target]
	if floor_number == 2:
		if miniboss_dead:
			return "FLOOR 2: Take the stairs to Floor 3"
		if kills >= kill_target:
			return "FLOOR 2: Kill the Brute in the containment room"
		return "FLOOR 2: Clear the infected rooms and reach Patient Z's zone (%d / %d Infected)" % [kills, kill_target]
	match phase:
		Phase.INTRO:
			return "Talk to your boss"
		Phase.COLLECT:
			if has_all_syringes():
				return "Bring the syringes to your boss"
			return "Find syringes in the first 4 rooms (%d/%d)" % [syringes, SYRINGES_NEEDED]
		Phase.SURVIVE:
			if not has_rifle:
				return "Get the rifle in the Security Guard Room"
			return "SURVIVE · Eliminate the infected (%d/%d)" % [kills, kill_target]
		Phase.CLEARED:
			return "Take the stairs to Floor 2"
	return ""


func notify(text: String) -> void:
	message.emit(text)


func _setup_input_actions() -> void:
	# Actions are created by code so the project settings don't need editing.
	# The px_ prefix avoids clashing with actions that already exist.
	_add_keys("px_forward", [KEY_W])
	_add_keys("px_back", [KEY_S])
	_add_keys("px_left", [KEY_A])
	_add_keys("px_right", [KEY_D])
	_add_key_left("px_sprint", KEY_SHIFT)
	_add_keys("px_crouch", [KEY_C])
	_add_key_left("px_crouch", KEY_CTRL)
	_add_keys("px_talk", [KEY_E])
	_add_keys("px_interact", [KEY_F])
	_add_keys("px_reload", [KEY_R])
	_add_keys("px_weapon_1", [KEY_1])
	_add_keys("px_weapon_2", [KEY_2])
	_add_keys("px_bandage", [KEY_3])
	_add_keys("px_holster", [KEY_Q])
	_add_keys("px_toggle_hud", [KEY_H])
	_add_keys("px_flashlight", [KEY_L])
	_add_keys("px_pause", [KEY_ESCAPE])
	_add_keys("px_fullscreen", [KEY_F11])
	if not InputMap.has_action("px_shoot"):
		InputMap.add_action("px_shoot")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("px_shoot", click)
	if not InputMap.has_action("px_aim"):
		InputMap.add_action("px_aim")
		var right_click := InputEventMouseButton.new()
		right_click.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("px_aim", right_click)


	_setup_player2_actions()
	_add_joy_button("px_pause", JOY_BUTTON_START)


## Player 2 (split screen): a gamepad, or the arrow keys + numeric keypad if there is none.
##   Move: left stick / arrows · Look: right stick / numpad 8 5 4 6 · Shoot: RT / Right Ctrl
##   Aim: LT / numpad 0 · Run: L3 or LB / Right Shift · Crouch: B / numpad . · Interact: A / numpad Enter
##   Talk: Y / numpad + · Reload: X / numpad 7 · Weapons: D-pad left/right / numpad 1 2
##   Bandage: D-pad down / numpad 3 · Flashlight: D-pad up / numpad / · Put weapon away: RB / numpad 9
func _setup_player2_actions() -> void:
	_add_keys("p2_forward", [KEY_UP]); _add_joy_axis("p2_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_keys("p2_back", [KEY_DOWN]); _add_joy_axis("p2_back", JOY_AXIS_LEFT_Y, 1.0)
	_add_keys("p2_left", [KEY_LEFT]); _add_joy_axis("p2_left", JOY_AXIS_LEFT_X, -1.0)
	_add_keys("p2_right", [KEY_RIGHT]); _add_joy_axis("p2_right", JOY_AXIS_LEFT_X, 1.0)
	_add_keys("p2_look_left", [KEY_KP_4]); _add_joy_axis("p2_look_left", JOY_AXIS_RIGHT_X, -1.0)
	_add_keys("p2_look_right", [KEY_KP_6]); _add_joy_axis("p2_look_right", JOY_AXIS_RIGHT_X, 1.0)
	_add_keys("p2_look_up", [KEY_KP_8]); _add_joy_axis("p2_look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_add_keys("p2_look_down", [KEY_KP_5]); _add_joy_axis("p2_look_down", JOY_AXIS_RIGHT_Y, 1.0)
	_add_key_right("p2_shoot", KEY_CTRL); _add_joy_axis("p2_shoot", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_keys("p2_aim", [KEY_KP_0]); _add_joy_axis("p2_aim", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_add_key_right("p2_sprint", KEY_SHIFT); _add_joy_button("p2_sprint", JOY_BUTTON_LEFT_STICK); _add_joy_button("p2_sprint", JOY_BUTTON_LEFT_SHOULDER)
	_add_keys("p2_crouch", [KEY_KP_PERIOD]); _add_joy_button("p2_crouch", JOY_BUTTON_B)
	_add_keys("p2_interact", [KEY_KP_ENTER]); _add_joy_button("p2_interact", JOY_BUTTON_A)
	_add_keys("p2_talk", [KEY_KP_ADD]); _add_joy_button("p2_talk", JOY_BUTTON_Y)
	_add_keys("p2_reload", [KEY_KP_7]); _add_joy_button("p2_reload", JOY_BUTTON_X)
	_add_keys("p2_weapon_1", [KEY_KP_1]); _add_joy_button("p2_weapon_1", JOY_BUTTON_DPAD_LEFT)
	_add_keys("p2_weapon_2", [KEY_KP_2]); _add_joy_button("p2_weapon_2", JOY_BUTTON_DPAD_RIGHT)
	_add_keys("p2_bandage", [KEY_KP_3]); _add_joy_button("p2_bandage", JOY_BUTTON_DPAD_DOWN)
	_add_keys("p2_flashlight", [KEY_KP_DIVIDE]); _add_joy_button("p2_flashlight", JOY_BUTTON_DPAD_UP)
	_add_keys("p2_holster", [KEY_KP_9]); _add_joy_button("p2_holster", JOY_BUTTON_RIGHT_SHOULDER)


## Only the right-hand Ctrl / Shift (the left ones belong to player 1).
func _add_key_right(action: StringName, key: Key) -> void:
	_add_located(action, key, KEY_LOCATION_RIGHT)


func _add_key_left(action: StringName, key: Key) -> void:
	_add_located(action, key, KEY_LOCATION_LEFT)


func _add_located(action: StringName, key: Key, location: KeyLocation) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	ev.location = location
	InputMap.action_add_event(action, ev)


func _add_joy_axis(action: StringName, axis: JoyAxis, value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	ev.device = -1
	InputMap.action_add_event(action, ev)


func _add_joy_button(action: StringName, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.device = -1
	InputMap.action_add_event(action, ev)


func _add_keys(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)
