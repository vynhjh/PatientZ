# Patient Z · Piso 1

Proyecto de Godot 4.7 (Forward+). Abrir con **Importar** y elegir `project.godot`.

## Flujo
`MainMenu.tscn` (escena principal) → **Play** → `main.tscn` → `scenes/levels/laboratorio_piso1.tscn`
→ escaleras → `scenes/levels/laboratorio_piso2.tscn` → escaleras → `scenes/levels/laboratorio_piso3.tscn` (final: Patient Z).
`main.tscn` abre el piso que toca (`scripts/main.gd`): partida nueva = Piso 1, escaleras = el siguiente piso
(con la vida, armas, munición y vendas del jugador), Continue = el piso donde se guardó.

## 2 jugadores · pantalla dividida (menú → Play → New Game · 2 Players)
- Izquierda **Jugador 1**: teclado y ratón (como siempre; Ctrl y Shift **izquierdos**).
- Derecha **Jugador 2** (bata azul): **mando** o, sin mando, flechas + teclado numérico:
  | Acción | Mando | Teclado |
  |---|---|---|
  | Mover / mirar | stick izquierdo / derecho | flechas / num 8 5 4 6 |
  | Disparar / apuntar | RT / LT | Ctrl derecho / num 0 |
  | Correr / agacharse | L3 o LB / B | Shift derecho / num . |
  | Interactuar / hablar | A / Y | num Enter / num + |
  | Recargar / guardar arma | X / RB | num 7 / num 9 |
  | Fusil / escopeta / venda / linterna | D-pad ← / → / ↓ / ↑ | num 1 / 2 / 3 / ÷ |
  | Pausa | Start | Esc |
- Cada piso tiene los nodos **Player2** (`player.tscn` con `player_number = 2`) y **SplitScreen**
  (`scenes/ui/split_screen.tscn`: dos SubViewport con su Camera3D y su HUD). En 1 jugador se quitan solos.
- Más difícil con 2 jugadores: infectados y jefes con **+60 % de vida**, **+30 % de daño** y **+10 % de velocidad**
  (`enemy_*_mult()` en `game_manager.gd`). Los infectados persiguen al jugador más cercano.
- Si uno cae y el otro sigue vivo, se levanta a su lado a los 15 s con media vida. Si caen los dos: R / A carga el último guardado.
- Las armas de las mesas se dan a los dos; la vida, munición y vendas son de cada uno. Se guardan los dos jugadores.

## Correr
Al correr el arma se guarda (no se ve) y vuelve a las manos al dejar de correr; corriendo no se puede disparar.

## Ajustes (menú principal → Settings → Volume)
- **General Volume**: todo el sonido (bus `Master`). **Music Volume**: solo la música del menú y la de fondo (bus
  `Music`, definido en `default_bus_layout.tres`; los nodos de música tienen `Bus = Music`).
- Escena `scenes/ui/settings_menu.tscn` (botones y sliders conectados en la escena). Los valores se guardan en
  `user://settings.cfg` y se aplican al arrancar (autoload `Settings`, `scripts/autoload/settings.gd`).

## Pantalla completa
- Ya activada: *Proyecto → Configuración del proyecto → Display → Window → Size → Mode = Fullscreen*
  (con "Configuración avanzada" activado), y *Stretch → Mode = canvas_items*, *Aspect = expand* para que el HUD y
  los menús se escalen a cualquier resolución. **F11** alterna entre pantalla completa y ventana.
- Si al darle a Play el juego sale dentro del editor (pestaña "Juego"/"Game"): en esa pestaña, menú **⋮** →
  desmarca **"Incrustar juego en la próxima ejecución" / "Embed Game on Next Play"**. Así se abre en su propia
  ventana a pantalla completa.

## Piso 2 · The Containment Spiral (`scenes/levels/laboratorio_piso2.tscn`)
Salas en caracol, una detrás de otra: **Stairwell** (escalera en L desde el Piso 1, con descanso) → **Corridor** →
**Medical Supplies** (4 armarios de vendas) → **Armory A** y **Armory B** (armarios de munición de fusil y escopeta)
→ **Ward C** → **Ward B** → **Ward A** → **Containment** (mini-jefe "The Brute") → **Exit** (escalera al Piso 3).
```
LaboratorioPiso2 (laboratorio_piso2.gd)
├─ WorldEnvironment
├─ World (StaticBody3D)      Floor*, StairwellFloor, Ceiling*, ShaftCeiling, Wall* + shapes, DoorTop*/DoorBottom*
├─ Stairwell                 LowerFlight, MidLanding, UpperFlight, TopLanding (StaticBody3D: escalones + rampa)
│                            RailingLower/Upper/Landing/Top (barandillas con colisión)
├─ ExitStairs                Flight, Landing, StairsToFloor3 (stairs.tscn → target_scene = Piso 3)
├─ Lights                    Lamp1..44 (luces rojas de emergencia)
├─ Doors                     Floor1Door (sealed), StairwellDoor, Door*, ContainmentDoor (cleared), ExitDoor (boss)
├─ Cabinets                  Cabinet1..36 (contents: bandage / ammo_rifle / ammo_shotgun)
├─ Furniture                 camillas, sillas de ruedas, porta-sueros, carritos, mesas, taquillas, armeros…
├─ Debris · WallDecor · WallDamage · Signs
├─ RoomTriggers              Area3D por sala (room_trigger.gd: room_name, infected_group)
├─ Infected                  ArmoryA (4), ArmoryB (6), WardC (8), WardB (8), WardA (9) = 35 · Containment/TheBrute
├─ Player · AlarmSystem/Siren · Blood · HUD · DialogueUI · PauseMenu
```
- Los infectados del Piso 2 están `dormant` (dormidos): no se mueven ni oyen hasta que entras en su sala
  (el `Area3D` de la sala los despierta) o hasta que les disparas.
- La puerta **CONTAINMENT** se abre al matar a los 35. **The Brute** (`scenes/enemies/mini_boss.tscn`,
  `scripts/enemies/mini_boss.gd`): 1600 de vida, cada golpe quita **40**, el fusil le hace solo el 60 % y la
  escopeta a menos de 6 m el 250 %. Al morir se abre la puerta **EXIT** y la escalera al Piso 3.
- Luces: `energy_scale` del nodo `AlarmSystem` (0.22 = más oscuro).
- Para mover algo: muévelo en la escena. Si cambias paredes o salas, actualiza `MAPA` y `ROOMS` en
  `scripts/levels/laboratorio_piso2.gd` (los usan los caminos de los infectados).

## Estructura: escenas + scripts
Todo lo que se ve está en escenas (`.tscn`) y se edita en el editor. Los scripts solo tienen el comportamiento
(no crean mallas, colisiones ni UI).

```
main.tscn
└─ LaboratorioPiso1            scenes/levels/laboratorio_piso1.tscn   (laboratorio_piso1.gd)
   ├─ WorldEnvironment         assets/materials/lab_environment.tres
   ├─ World (StaticBody3D)     Floor, Ceiling, Wall1..N + Shape1..N   (materiales lab_floor/ceiling/wall.tres)
   ├─ Lights                   Lamp1..14            → scenes/environment/lamp.tscn
   ├─ Doors                    Door1..11            → scenes/items/door.tscn       (Inspector: cell, kind)
   ├─ Cabinets                 Cabinet1..12         → scenes/items/cabinet.tscn    (Inspector: contents, cell)
   ├─ Furniture                Desk, Fridge, LabTable, Locker, GunRack, SecurityDesk → scenes/furniture/
   ├─ Clutter                  camillas, sillas de ruedas, porta-sueros, sillas, carritos → scenes/props/
   ├─ Debris                   papeles por el suelo → scenes/props/papers.tscn
   ├─ WallDecor                fotos, tablones MISSING, mensajes con sangre, huellas de manos, arañazos
   ├─ Items                    RiflePickup, ShotgunPickup → scenes/items/pickup.tscn (Inspector: weapon_id)
   ├─ Signs                    GuardRoomSign        → scenes/environment/sign.tscn (Inspector: text, size, color)
   ├─ Stairs                   scenes/items/stairs.tscn
   ├─ Breach                   scenes/environment/breach.tscn
   ├─ Boss                     scenes/npc/jefe.tscn
   ├─ Player                   scenes/player/player.tscn
   ├─ Infected                 (vacío: aquí aparecen los infectados, scenes/enemies/infectado.tscn)
   ├─ AlarmSystem / Siren      alarm_system.gd + AudioStreamPlayer
   ├─ Blood                    blood_spawner.gd (decals de sangre)
   ├─ HUD                      scenes/ui/hud.tscn
   ├─ DialogueUI               scenes/ui/dialogue_ui.tscn
   └─ PauseMenu                scenes/ui/pause_menu.tscn  (incluye Slots → save_slot_list.tscn)
```

**Player** (`scenes/player/player.tscn`, CharacterBody3D):
`CollisionShape3D` (cápsula) · `Body/PlayerModel/Model` (Walking.fbx con *Editable Children*) ·
`Model/AnimationTree` (librerías `assets/player/animations/player_base.tres` y `player_guns.tres`) ·
`…/Skeleton3D/AimTwist` · `Body/Hand` (RifleModel, ShotgunModel, MuzzleLight) · `FlashlightPivot/Flashlight` ·
`CameraRig/SpringArm3D/Camera3D` · `WeaponController/ShotSound` · `HurtSound` · `Inventory`.

**Infectado** (`scenes/enemies/infectado.tscn`, CharacterBody3D): `CollisionShape3D` · `Visual/Model`
(Zombie_Walking.fbx) · `Visual/PatientZGlow` · `Animations` (AnimationPlayer, librería
`assets/enemies/animations/zombie.tres`: walk, death) · `Groan`.

Los botones de los menús están conectados en la escena (pestaña **Nodo → Señales**).
Los scripts buscan sus nodos con nombre único (`%Nombre`), así que puedes moverlos dentro de la escena.

Para mover una puerta, armario, mueble o lámpara: selecciónalo en `laboratorio_piso1.tscn` y muévelo.
Si cambias la distribución de paredes, actualiza también `MAPA` (lo usan las salas y el pathfinding).

## Ambiente de hospital abandonado
- Mensajes con sangre (`wall_message`): en el Inspector `text`, `size`, `style` (`scrawl` = fuente Rock Salt,
  escrito con el dedo · `dripping` = Rubik Wet Paint, chorreando) y `messiness` (cuánto se tuerce cada letra).
  Fuentes en `assets/fonts/` (licencias Apache 2.0 y SIL OFL incluidas).
- Paredes dañadas (nodo **WallDamage** del nivel): `wall_crack` (grietas, elige `shape` 0-2) y `wall_hole`
  (pared rota con ladrillo a la vista y escombros en el suelo).
- Objetos en `scenes/props/`: `stretcher` (camilla), `wheelchair`, `iv_stand` (porta-suero), `chair`, `trolley`,
  `papers`, `wall_photo` (elige la foto en el Inspector), `missing_board`, `wall_message` (texto y tamaño en el
  Inspector), `handprints`, `scratches`. Arrástralos a la escena del nivel para poner más.
- Las camillas del centro de algunas salas están en el grupo `blocks_path`: su casilla se cierra para el
  pathfinding de los infectados. Si pones otra en mitad de una sala, añádele ese grupo.
- Puertas oxidadas: material del nodo `Panel/Slab` en `scenes/items/door.tscn` (textura `assets/textures/rusty_metal.png`).
- Lámparas rotas que parpadean: `flicker` en el Inspector de cada `Lamp` (se apagan al saltar la alarma, que controla todas las luces).

## Jugador
- Velocidad: `WALK_SPEED` (2.8), `RUN_SPEED` (5.0) y `CROUCH_SPEED` (1.4) en `scripts/player/player_stealth.gd`.
- Munición inicial: `start_reserve` en `scripts/player/weapon_controller.gd` (fusil 120, escopeta 24).
- Modelos de las armas: escenas `scenes/weapons/m4a1.tscn` (`assets/weapons/m4a1.glb`) y
  `scenes/weapons/shotgun.tscn` (`assets/weapons/shotgun.glb`). El nodo `Model` de cada una está colocado para que
  la empuñadura quede en el origen, el cañón hacia -Z y el nodo `Muzzle` en la boca del cañón.
  Están instanciadas en `Body/Hand/RifleModel/M4A1` y `Body/Hand/ShotgunModel/Shotgun` de `scenes/player/player.tscn`
  y en las mesas de `scenes/items/pickup.tscn`. El nodo `Hand` se coloca en la palma derecha y apunta a la izquierda.

## Animaciones del jugador
- `Body/PlayerModel/Model/AnimationTree` (árbol en `assets/player/animations/player_tree.tres`): el nodo
  **locomotion** elige `idle` (Standing W Briefcase Idle, parado), `walk` (Walking) o `run` (Running) para todo el
  cuerpo; con un arma, el torso y los brazos toman la pose del arma encima (nodo **arms**).
- Corriendo no se puede disparar: se ve la animación de correr completa y el arma va en la mano derecha.
- **Q** guarda el arma (manos libres: caminar, correr y reposo sin arma) y la vuelve a sacar. 1 y 2 sacan cada arma.

## Arma en mano
- Sin disparar, el personaje lleva el arma baja con las dos manos (al caminar o parado).
- Al disparar o con **clic derecho** sube a la pose de apuntar; vuelve a bajarla 1,5 s después del último disparo.
- Ajustes en `scripts/player/player_model.gd`: `LOWER_ANGLE` (cuánto baja), `AIM_HOLD_TIME`, `RAISE_SPEED`, `LOWER_SPEED`.

## Archivos que tú pones
| Archivo | Para qué |
|---|---|
| `assets/img/menu.png` | Fondo del menú (ya incluido, en `Background › Texture` de MainMenu.tscn) |
| `assets/items/medical_syringe.glb` | Jeringa de los armarios (ya incluida, escena `scenes/items/syringe.tscn`) |
| `assets/audio/soundtrack.mp3` | Música de fondo: suena en bucle desde que salta la alarma y en el resto del juego (autoload `Soundtrack`, escena `scenes/systems/soundtrack.tscn`; volumen en su nodo `Music`) |
| `assets/items/bandage_roll.glb` | Vendas de los armarios (escena `scenes/items/bandage.tscn`, nodo `Bandages` de `cabinet.tscn`) |
| `assets/audio/menu_music.mp3` | Música del menú (ya incluida, en `Music › Stream` de MainMenu.tscn) |
| `assets/player/Walking.fbx` | Modelo y animación del jugador (ya incluido) |
| `assets/player/Rifle_Gunplay.fbx` | Postura y retroceso con el fusil M-9 (ya incluido) |
| `assets/player/Shotgun_Gunplay.fbx` | Postura y retroceso con la escopeta (ya incluido) |
| `assets/enemies/Zombie_Walking.fbx` | Modelo y animación de los infectados del Piso 1 (ya incluido) |
| `assets/audio/alarm.mp3` (opcional) | Sonido de la alarma. Si no está, suena `assets/audio/sfx/alarm_siren.wav` (nodo `AlarmSystem/Siren`) |

Si cambias los nombres, edita las constantes de `scripts/ui/main_menu.gd` y `scripts/systems/alarm_system.gd`.

## Controles
W A S D mover (las flechas son del Jugador 2) · Shift correr (no se puede disparar) · C agacharse · E hablar · F interactuar · Clic disparar · Clic derecho apuntar · Q guardar/sacar arma · R recargar ·
1-2 armas · 3 venda · L linterna · H ocultar UI · Esc menú de pausa

## Dónde cambiar cosas
- Mapa: `MAPA` en `scripts/levels/laboratorio_piso1.gd`
- Nº de infectados: `objetivo_bajas` en `scripts/systems/level_config.gd` (debe coincidir con las `Z` del mapa)
- Diálogos: `scripts/systems/dialogue_db.gd`
- Duración/volumen de la alarma: `scripts/systems/alarm_system.gd`
- Modelo del jugador: nodo `Model` en `scenes/player/player.tscn`
- Animaciones: `Model/AnimationTree` en `scenes/player/player.tscn`. Con un arma, las piernas siguen
  la animación de caminar y el torso/brazos la postura del arma (AnimationTree). Al disparar se reproduce la
  animación completa (retroceso). `scripts/player/aim_twist_modifier.gd` gira el torso para que el arma apunte al frente.
- Modelo de los infectados: nodo `Visual/Model` en `scenes/enemies/infectado.tscn`
- Carteles 3D (STAIRS, SECURITY GUARD ROOM): instancias de `scenes/environment/sign.tscn` (texto en el Inspector)
- Sangre (Decals): `scripts/environment/blood_spawner.gd` · solo se ve con el renderer Forward+ o Mobile

## Partidas guardadas (varias)
- **Menú principal → Play**: *New Game* (empieza una partida nueva en su propia ranura, sin tocar las demás) · *Continue* (lista de partidas guardadas: cargar o borrar) · *Back*.
- **Esc → menú de pausa**: *Resume · Save Game · Load Game · Main Menu*.
  - *Save Game*: **+ New Save** crea una partida guardada nueva, o eliges una de la lista para sobrescribirla (pide confirmación).
  - *Load Game*: eliges cualquier partida guardada.
- **Checkpoints**: al hablar con el jefe, al saltar la alarma, al recibir la tarjeta y al coger el fusil se guarda sola la partida que estás jugando.
- Al morir, **R** carga el último guardado de esa partida.
- Script: `scripts/autoload/save_manager.gd` (autoload `SaveManager`) · lista reutilizable: `scripts/ui/save_slot_list.gd`.
- Cada partida guardada es una carpeta en `user://saves/<id>/` con 4 archivos:
  `meta.json` (nº de partida, fecha, objetivo, tiempo) · `progress.json` (misión) · `player.json` (jugador e inventario) · `world.json` (puertas, armarios, armas, infectados).
  En Godot: *Proyecto → Abrir carpeta de datos del usuario*.

## Piso 3 · The Core (`scenes/levels/laboratorio_piso3.tscn`)
Mismo concepto que el Piso 2, todo en nodos, pero más grande (777 celdas), más oscuro (`energy_scale` 0.15 y más
niebla), más destruido (paredes rotas, grietas, escombros `rubble_pile.tscn`, paneles del techo caídos
`ceiling_debris.tscn`, camillas volcadas) y con más sangre.
Caracol: **Stairwell** (escalera en L) → **Corridor** → **Pharmacy** → **Morgue** (armario con la **tarjeta de
seguridad**) → puerta con tarjeta → **Surgery** → **Ward D** → **Ward E** → **Isolation** → puerta con tarjeta →
**Research Lab** → **Quarantine** → **Containment Core** (Patient Z, se abre al matar a los **60** infectados).
- 39 armarios (vendas, munición de fusil y escopeta, y la tarjeta). Las puertas con tarjeta son `kind = keycard`.
- Patient Z (`scenes/enemies/patient_z.tscn`, 2500 de vida) duerme hasta que entras en el Core. Al matarlo: fin del juego.
- Lógica: `scripts/levels/laboratorio_piso3.gd` (hereda de `laboratorio_piso2.gd`; solo cambia el mapa y los ajustes).

## Barra de objetos (HUD)
`scenes/ui/hud.tscn` → nodo **ItemSlots** con 5 instancias de `scenes/ui/item_slot.tscn`: fusil, escopeta, vendas,
jeringas (solo en la misión del Piso 1) y tarjeta. El icono de cada ranura se cambia en el Inspector (`icon`);
los iconos están en `assets/ui/icons/`. El arma que llevas en la mano se marca en amarillo y lo que no tienes sale apagado.

## Vendas y curación
[3] usa una venda: cura 25 de vida y quita 40 de infección poco a poco durante 1,5 s ("HEALING...") y al terminar
salen partículas verdes (nodo **HealParticles** de `scenes/player/player.tscn`, con una luz verde `HealLight`).
Ajustes: `HEAL_TIME`, `BANDAGE_HEALTH`, `BANDAGE_INFECTION` en `scripts/player/player_stealth.gd`.

## Tipos de infectados (desde el Piso 2)
| Escena | Vida | Velocidad persiguiendo | Daño por golpe | Aspecto |
|---|---|---|---|---|
| `scenes/enemies/infectado.tscn` (normal) | 140 | 3.0 m/s | 12 | normal |
| `scenes/enemies/infectado_runner.tscn` (**Runner**) | 90 | 4.8 m/s | 8 | verdoso, algo más pequeño |
| `scenes/enemies/infectado_heavy.tscn` (**Heavy**) | 260 | 2.3 m/s | **40** | rojizo, ×1.3, ataques con zarpazo |
Piso 2: 8 Runners y 5 Heavies de los 35 · Piso 3: 15 Runners y 10 Heavies de los 60 (nodos `Runner#` y `Heavy#`
dentro de `Infected`). Los valores están en el Inspector de cada escena (grupo **Stats** y **Look**). Para cambiar
un infectado de tipo, borra el nodo y arrastra otra de las tres escenas a su sitio.

## Munición y vendas de los armarios
Cada armario tiene `amount` en el Inspector (0 = 1 venda / 24 balas / 8 cartuchos). En los Pisos 2 y 3:
**2 vendas, 60 balas de fusil y 16 cartuchos de escopeta** por armario.

## Jefe (doctor)
- `scenes/npc/jefe.tscn`: el modelo es `assets/npc/doctor.fbx` (nodo `Model/Doctor`, escalado ×8 y girado porque
  el FBX viene pequeño y tumbado). Su animación "Take 001" (escribiendo en la carpeta) se repite en bucle.

## Infectados
- Modelo: `assets/enemies/Zombie_Walking.fbx` · muerte: `assets/enemies/Zombie_Death.fbx` (Death From The Front, Mixamo).
- Aparecen repartidos por cada sala (en sitios libres, lejos de puertas y muebles, distintos en cada partida nueva).
- Mientras las puertas estén cerradas se quedan en su sala: no oyen a través de las paredes ni se agolpan en la puerta.
- Chocan entre ellos y se separan, así que no se amontonan en un mismo punto.
- Vida: `ZOMBIE_HEALTH` (140) y `PATIENT_Z_HEALTH` (1000) en `scripts/systems/level_config.gd`.
- **Patient Z** (jefe final) tiene su propia escena: `scenes/enemies/patient_z.tscn`, con el modelo Blind Hunter
  (`assets/enemies/PatientZ_Walking.fbx`) y la librería `assets/enemies/animations/patient_z.tres`:
  `walk`, `attack_swipe` (Mutant Swiping), `attack_slam` (Standing Torch Melee Attack 04) y `death`
  (la muerte de los zombis adaptada a su esqueleto). Las animaciones se dejaron "en el sitio" (sin avanzar solas).
- No aparece con los demás: sale de la brecha de contención cuando ya mataste a los otros 14, y te persigue
  siempre sabiendo dónde estás. Es más rápido que los otros (4.3 m/s contra 3.0) y pega más fuerte (25).
- Sus ataques: en el Inspector de `patient_z.tscn` → `attack_animations`, `attack_hit_times` (momento del golpe,
  0-1) y `attack_anim_speed`.

## Ambiente
- Oscuridad de la alarma: `AMBIENT_ALARM_ENERGY`, `ALARM_LIGHT_MIN/MAX` y `ALARM_FOG_DENSITY` en `scripts/systems/level_config.gd`.
- Cantidad de sangre: `_spawn_room_blood()` en `scripts/levels/laboratorio_piso1.gd`.
