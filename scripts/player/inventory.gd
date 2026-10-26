extends Node
## Player inventory: weapons with their ammo, and bandages.

var bandages := 2
var ammo := {}              # weapon id -> {"mag": int, "reserve": int}
var _pending_ammo := {}     # ammo found before having that weapon


func has_weapon(id: String) -> bool:
	return ammo.has(id)


## Returns true if the weapon is new.
func add_weapon(id: String, data: Dictionary) -> bool:
	if has_weapon(id):
		ammo[id]["reserve"] += data["mag_size"]
		return false
	ammo[id] = {"mag": data["start_mag"], "reserve": data["start_reserve"] + _pending_ammo.get(id, 0)}
	_pending_ammo.erase(id)
	return true


func add_ammo(id: String, amount: int, weapon_name: String) -> void:
	if not has_weapon(id):
		_pending_ammo[id] = _pending_ammo.get(id, 0) + amount
		GameManager.notify("%s ammo found (no weapon yet)" % weapon_name)
		return
	ammo[id]["reserve"] += amount
	GameManager.notify("+%d %s ammo" % [amount, weapon_name])


func add_bandages(amount: int) -> void:
	bandages += amount


func get_save_data() -> Dictionary:
	return {"bandages": bandages, "ammo": ammo.duplicate(true), "pending_ammo": _pending_ammo.duplicate()}


func load_save_data(data: Dictionary) -> void:
	bandages = int(data.get("bandages", bandages))
	ammo = {}
	var saved_ammo: Dictionary = data.get("ammo", {})
	for id in saved_ammo:
		ammo[id] = {"mag": int(saved_ammo[id].get("mag", 0)), "reserve": int(saved_ammo[id].get("reserve", 0))}
	_pending_ammo = {}
	var pending: Dictionary = data.get("pending_ammo", {})
	for id in pending:
		_pending_ammo[id] = int(pending[id])


func take_bandage() -> bool:
	if bandages <= 0:
		return false
	bandages -= 1
	return true
