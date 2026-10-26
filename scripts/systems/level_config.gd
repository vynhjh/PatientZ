extends RefCounted
## Floor 1 settings. Load it with: const Config = preload("res://scripts/systems/level_config.gd")

const ROWS := 19
const COLS := 31
const CELL_SIZE := 3.0          # metres per map cell
const WALL_HEIGHT := 3.2        # free height to the ceiling

## Must match the number of "Z" in MAPA (laboratorio_piso1.gd).
const objetivo_bajas := 15

const SYRINGES_NEEDED := 5
const CABINETS_PER_START_ROOM := 2

const FLOOR_2_SCENE := "res://scenes/levels/laboratorio_piso2.tscn"
const FLOOR_3_SCENE := "res://scenes/levels/laboratorio_piso3.tscn"

# Lights
const LIGHT_NORMAL := Color(0.85, 0.93, 1.0)
const LIGHT_ALARM := Color(1.0, 0.08, 0.05)
const AMBIENT_NORMAL := Color(0.72, 0.8, 0.88)
const AMBIENT_ALARM := Color(0.35, 0.02, 0.02)
const AMBIENT_ALARM_ENERGY := 0.12          # darker emergency ambience
const ALARM_LIGHT_MIN := 0.2                # red lamps pulse between these energies
const ALARM_LIGHT_MAX := 1.4
const ALARM_FOG_DENSITY := 0.025            # dark red haze during the alarm

# Infected
const ZOMBIE_HEALTH := 140.0
const PATIENT_Z_HEALTH := 1000.0         # appears when all the other infected are dead
