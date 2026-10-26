extends "res://scripts/levels/laboratorio_piso2.gd"
## Patient Z · Floor 3 (The Core) — scenes/levels/laboratorio_piso3.tscn
##
## Same idea as Floor 2 (everything placed as nodes in the scene, this script only adds the
## logic, inherited from laboratorio_piso2.gd): bigger, darker, more destroyed and bloodier.
## 60 dormant infected that wake up room by room, more cabinets with bandages and ammo,
## a security keycard (in a Morgue cabinet) for the doors marked K, and Patient Z in the last
## room (Containment Core), which opens when the 60 infected are dead.
##
## Spiral: Stairwell → Corridor → Pharmacy → Morgue → (keycard) Surgery → Ward D → Ward E →
## Isolation → (keycard) Research Lab → Quarantine → Containment Core (Patient Z).

## Legend: # wall · . floor · S stairwell (Floor 2 height) · U door stairwell → corridor
## D door · K keycard door · Q Containment Core door (opens when the 60 infected are dead)
## F sealed door back to Floor 2
const MAPA3 := [
	"#####################################",
	"#SSSS##################.............#",
	"#SSSSU................D.............#",
	"#SSSS#................#.............#",
	"#SSSS##################.............#",
	"FSSSS#######..........#.............#",
	"############..........#.............#",
	"#..........K..........#######D#######",
	"#..........#..........#.............#",
	"#..........#####D######.............#",
	"#..........#..........#.............#",
	"#..........#..........#.............#",
	"#..........#..........#.............#",
	"#..........#####Q######.............#",
	"#..........#..........#.............#",
	"#..........#..........#######K#######",
	"#..........#..........#.............#",
	"#..........#..........#.............#",
	"#..........#..........#.............#",
	"#####D#################.............#",
	"#..........#..........#.............#",
	"#..........#..........#.............#",
	"#..........#..........#.............#",
	"#..........D..........D.............#",
	"#..........#..........#.............#",
	"#..........#..........#.............#",
	"#..........#..........#.............#",
	"#..........#..........#.............#",
	"#####################################",
]

const ROOMS3 := {
	"Stairwell": [Vector2i(1, 1), Vector2i(4, 5), "Stairwell"],
	"Corridor": [Vector2i(6, 2), Vector2i(21, 3), "Floor 3 · The Core"],
	"Pharmacy": [Vector2i(23, 1), Vector2i(35, 6), "Pharmacy"],
	"Morgue": [Vector2i(23, 8), Vector2i(35, 14), "Morgue"],
	"Surgery": [Vector2i(23, 16), Vector2i(35, 27), "Surgery"],
	"WardD": [Vector2i(12, 20), Vector2i(21, 27), "Ward D"],
	"WardE": [Vector2i(1, 20), Vector2i(10, 27), "Ward E"],
	"Isolation": [Vector2i(1, 7), Vector2i(10, 18), "Isolation"],
	"Lab": [Vector2i(12, 5), Vector2i(21, 8), "Research Lab"],
	"Quarantine": [Vector2i(12, 10), Vector2i(21, 12), "Quarantine"],
	"Core": [Vector2i(12, 14), Vector2i(21, 18), "Containment Core · Patient Z"],
}


func _configure() -> void:
	map = MAPA3
	rooms = ROOMS3
	floor_number = 3
	floor_name = "Floor 3 · The Core"
	arrival_text = "FLOOR 3 · The Core. Find the security keycard."
	blood_rooms = ["Corridor", "Pharmacy", "Morgue", "Surgery", "WardD", "WardE", "Isolation", "Lab", "Quarantine", "Core"]
	blood_density = 1.1
	fog_density = 0.045
	boss_room = "Core"
	boss_wake_text = "PATIENT Z is awake. End this."
	boss_health = 2500.0
