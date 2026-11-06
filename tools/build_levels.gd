## build_levels.gd - dev-only generator for the level scenes (run again to rebuild them).
## Run it with:  godot --headless --path . res://tools/build_levels.tscn
## (a scene, not --script, so the autoloads like Balance and Events exist).
## It writes the levels named in BUILD as INHERITED scenes of level_base.tscn, so
## editing level_base later updates all of them.
## WARNING: running it overwrites those scene files, including edits made by hand.
##
## How the levels are designed (2026-11-05 rebuild, the full platformer kit):
## each level is a chain of rooms. A room TEACHES one idea where failing is cheap, then
## TESTS it with some danger, then TWISTS it (combines it with something else).
## Measures to design with (Balance): 1 tile = 32 px, 1 BL = 2 tiles. A jump rises 2 BL
## (4 tiles); a step of 2 to 3 tiles is comfortable. A walking jump crosses 3.5 BL
## (7 tiles), a sprint jump 5.3 BL (10 tiles). The zoomed camera shows about 27 x 15 tiles.
## Rows: row r has its top at y = r x 32. Level ground is row 19 (y 608) at the lowest.
extends Node

const BASE: String = "res://scenes/levels/level_base.tscn"

## Tile size in px (matches Balance.TILE_SIZE).
const T: int = 32
## The lowest ground row (y 608). Ground filled down to BOTTOM_ROW; level_base then
## extends it below the view.
const FLOOR_ROW: int = 19
const BOTTOM_ROW: int = 22

## Which level files this run writes. The boss arena was edited by hand (Perseus, pool),
## so it is left out unless you add "boss" on purpose.
const BUILD: Array[String] = ["level_1_temple", "level_2_cliffs", "level_3_cave"]

const P_HOPLITE: String = "res://scenes/enemies/hoplite.tscn"
const P_EYES: String = "res://scenes/enemies/eye_shading_hoplite.tscn"
const P_LEAPER: String = "res://scenes/enemies/leaper.tscn"
const P_ARCHER: String = "res://scenes/enemies/archer.tscn"
const P_MIRROR: String = "res://scenes/enemies/mirror_bearer.tscn"
const P_VICTIM: String = "res://scenes/props/victim_statue.tscn"
const P_LEDGE: String = "res://scenes/props/safe_ledge.tscn"
const P_POOL: String = "res://scenes/props/mirror_pool.tscn"
const P_PIT: String = "res://scenes/props/pit.tscn"
const P_TORCH: String = "res://scenes/props/torch.tscn"
const P_PLATE: String = "res://scenes/props/pressure_plate.tscn"
const P_MOVING: String = "res://scenes/props/moving_platform.tscn"
const P_CRUMBLE: String = "res://scenes/props/crumbling_ledge.tscn"
const P_COLUMN: String = "res://scenes/props/column_platform.tscn"
const P_SPEARS: String = "res://scenes/props/spear_trap.tscn"
const P_GATE: String = "res://scenes/props/gate.tscn"
const P_SHARD: String = "res://scenes/props/shard.tscn"
const P_HINT: String = "res://scenes/ui/key_hint.tscn"


## _ready runs once when this scene starts: build each level in BUILD, then quit.
## `match` is GDScript's switch statement.
func _ready() -> void:
	for level: String in BUILD:
		match level:
			"level_1_temple": _build_level_1()
			"level_2_cliffs": _build_level_2()
			"level_3_cave": _build_level_3()
			"boss": _build_starter("boss", LevelBase.Lighting.STORM)
	print("build_levels: done")
	get_tree().quit()


# =====================================================================================
# Level 1: temple steps at noon. Teaches every verb, then the first kit pieces.
# =====================================================================================

## Rooms, left to right:
## 1 the forecourt: move, a victim statue to push (teach push), up two temple steps (jump)
## 2 the plateau: a hoplite (teach gaze), whip hint; a broken-column climb to a shard
## 3 the leaper's gap: 4.5 BL, too far to walk-jump, a sprint jump clears it
## 4 the spear trench: a hoplite and a spare victim to push
##   into it; a statue resting in the trench jams the spears (the statue bridge)
## 5 the crumbling bridge over a pit: three cracked ledges that drop after you land
## 6 two hoplites, then a lift (vertical moving platform) up to the temple; pool, exit
func _build_level_1() -> void:
	var root: LevelBase = _new_level("Level1Temple", LevelBase.Lighting.NOON)
	var t: TileMapLayer = root.get_node("Terrain")
	_ground(t, -4, 24, 19)
	_ground(t, 24, 30, 17)         # temple step 1 (2 tiles up)
	_ground(t, 30, 60, 15)         # step 2 and the plateau
	# 3: the leaper's gap, tiles 60..69 (9 tiles = 4.5 BL)
	_ground(t, 69, 92, 15)
	# 4: spear trench, tiles 92..103, its floor 2 rows down
	_ground(t, 92, 103, 17)
	_ground(t, 103, 116, 15)
	# 5: crumbling bridge over the pit, tiles 116..131
	_ground(t, 131, 160, 15)
	# 6: the lift shaft at 160..164, then the temple top 5 rows higher
	_ground(t, 164, 212, 10)        # temple top, now with the gauntlet room
	_wall(t, -4, -2, 6, 19)
	_wall(t, 210, 212, 0, 10)

	root.get_node("Spawn").position = Vector2(128, 576)
	root.get_node("LevelExit").position = Vector2(206 * T, 10 * T)

	# Room 1
	_hint(root, "HintMove", Vector2(260, 540), [&"move_left", &"move_right"], ["A", "D"], "right")
	_add(root, "VictimPush", P_VICTIM, Vector2(13 * T, 576), {"pose": 1})
	_decor(root, "Amphora1", "res://art/sprites/props/amphora.png", Vector2(6 * T, 19 * T), 56.0)
	_hint(root, "HintJump", Vector2(21 * T, 540), [&"jump"], ["space"], "jump")
	# Room 2
	_add(root, "Hoplite1", P_HOPLITE, Vector2(46 * T, 15 * T - 32))
	_hint(root, "HintGaze", Vector2(38 * T, 15 * T - 80), [&"gaze"], ["K"], "gaze")
	_hint(root, "HintWhip", Vector2(50 * T, 15 * T - 80), [&"whip"], ["J"], "whip")
	# Columns step up 3 rows at a time: a jump rises exactly 4 rows, so 4 would need a
	# pixel-perfect jump.
	_column(root, "Column1", 52, 3, 12, 15)
	_column(root, "Column2", 56, 3, 9, 15)
	# An archer holds the high column: the shard is his to lose.
	_add(root, "ArcherColumn", P_ARCHER, Vector2(57.5 * T, 9 * T - 32))
	_add(root, "Shard1", P_SHARD, Vector2(57.5 * T, 7.5 * T))
	# Room 3
	_add(root, "SafeGapNear", P_LEDGE, Vector2(58 * T, 15 * T))
	_hint(root, "HintSprint", Vector2(55 * T, 15 * T - 160), [&"run"], ["shift"], "right")
	_add_pit(root, "PitLeaper", 60, 69, 15 * T)
	_add(root, "Leaper", P_LEAPER, Vector2(70 * T, 15 * T - 20))
	_add(root, "SafeGapFar", P_LEDGE, Vector2(72 * T, 15 * T))
	_add(root, "Leaper2", P_LEAPER, Vector2(76 * T, 15 * T - 20))
	# Room 4
	_add(root, "Hoplite2", P_HOPLITE, Vector2(86 * T, 15 * T - 32))
	_add(root, "VictimSpare", P_VICTIM, Vector2(83 * T, 15 * T - 32), {"pose": 2, "faces_right": false})
	# Two traps out of step: one statue jams only the trap it lands in.
	_spears(root, "TrenchSpearsA", 92, 5, 17, 0.0)
	_spears(root, "TrenchSpearsB", 97, 6, 17, 0.5)
	_decor(root, "ColumnDecor1", "res://art/sprites/props/column.png", Vector2(108 * T, 15 * T), 120.0)
	# Room 5
	_add(root, "SafeBridge", P_LEDGE, Vector2(114 * T, 15 * T))
	_add_pit(root, "PitBridge", 116, 131, 15 * T)
	_crumble(root, "Crumble1", 117, 3, 15)
	_crumble(root, "Crumble2", 121, 3, 15)
	_crumble(root, "Crumble3", 126, 3, 15)
	_add(root, "SafeBridgeFar", P_LEDGE, Vector2(133 * T, 15 * T))
	# The level's ONE pool (single use), about 70% of the way through.
	_add(root, "Pool", P_POOL, Vector2(136 * T, 15 * T))
	_hint(root, "HintKneel", Vector2(136 * T, 15 * T - 80), [&"move_down"], ["S"], "down")
	# Room 6
	# An archer looses at her while she crosses the crumbling bridge.
	_add(root, "ArcherBridge", P_ARCHER, Vector2(142 * T, 15 * T - 32))
	_add(root, "Hoplite3", P_HOPLITE, Vector2(147 * T, 15 * T - 32))
	_add(root, "Hoplite4", P_HOPLITE, Vector2(153 * T, 15 * T - 32))
	_lift(root, "Lift", 160, 4, 15, 10, 4.0)
	_add_pit(root, "PitLift", 160, 164, 15 * T)
	# Room 7: the gauntlet on the temple top. An archer waits at the top of the lift, then
	# three spear traps ripple out of step, then a mirror-bearer guards the door.
	_add(root, "ArcherLift", P_ARCHER, Vector2(167 * T, 10 * T - 32))
	_spears(root, "Gauntlet1", 170, 3, 10, 0.0)
	_spears(root, "Gauntlet2", 175, 3, 10, 0.33)
	_spears(root, "Gauntlet3", 180, 3, 10, 0.66)
	_add(root, "SafeGauntlet", P_LEDGE, Vector2(186 * T, 10 * T))
	_add(root, "MirrorDoor", P_MIRROR, Vector2(196 * T, 10 * T - 32))
	_decor(root, "ColumnDecor2", "res://art/sprites/props/column.png", Vector2(190 * T, 10 * T), 140.0)
	_decor(root, "ColumnDecor3", "res://art/sprites/props/column.png", Vector2(201 * T, 10 * T), 140.0)
	_save(root, "level_1_temple")


# =====================================================================================
# Level 2: cliffs over the sea at dusk. Archers, the leaper, and going UP.
# =====================================================================================

## Rooms:
## 1 the cliff foot: petrify a hoplite, push his statue to the 2.5 BL cliff and climb it
##   (spare victim statue behind the spawn)
## 2 the clifftop: an archer; a column to a shard
## 3 the sea gap: a moving slab ferries her across 5 BL of open sea; the leaper waits
## 4 the pillar archer between two gaps (gaze reaches 4 BL, the whip only 2)
## 5 the crumbling stair: three cracked ledges climbing to the high cliff over the sea
## 6 the high cliff: hoplite, eye-shading hoplite (0.7 s gaze), pool, exit
func _build_level_2() -> void:
	var root: LevelBase = _new_level("Level2Cliffs", LevelBase.Lighting.DUSK)
	var t: TileMapLayer = root.get_node("Terrain")
	_ground(t, -4, 26, 19)
	_ground(t, 26, 48, 14)         # the cliff, 5 rows (2.5 BL) above the start
	# 3: sea gap 48..58
	_ground(t, 58, 72, 14)
	# 4: gap 72..77, pillar 77..81 one row higher... two rows, gap 81..86
	_ground(t, 77, 81, 12)
	_ground(t, 86, 102, 14)
	# 5: crumbling stair over the sea 102..117
	_ground(t, 117, 140, 8)        # the high cliff, 6 rows above
	_wall(t, -4, -2, 6, 19)
	_wall(t, 138, 140, -2, 8)

	root.get_node("Spawn").position = Vector2(300, 576)
	root.get_node("LevelExit").position = Vector2(137 * T, 8 * T)

	# Room 1
	_add(root, "VictimSpare", P_VICTIM, Vector2(150, 576), {"pose": 0})
	_add(root, "HopliteCliff", P_HOPLITE, Vector2(700, 576))
	_add(root, "SafeTop", P_LEDGE, Vector2(30 * T, 14 * T))
	# Room 2
	_add(root, "HopliteTop", P_HOPLITE, Vector2(40 * T, 14 * T - 32))
	_add(root, "ArcherTop", P_ARCHER, Vector2(44 * T, 14 * T - 32))
	_column(root, "Column1", 36, 3, 11, 14)
	_add(root, "Shard1", P_SHARD, Vector2(37.5 * T, 10 * T))
	# Room 3
	_add(root, "SafeSeaNear", P_LEDGE, Vector2(46 * T, 14 * T))
	_add_pit(root, "PitSea", 48, 58, 14 * T)
	_ferry(root, "Ferry", 49, 3, 14, Vector2(5 * T, 0), 3.5)
	_add(root, "Leaper", P_LEAPER, Vector2(59 * T, 14 * T - 20))
	_add(root, "SafeSeaFar", P_LEDGE, Vector2(61 * T, 14 * T))
	# An archer fires on the ferry from the far shore.
	_add(root, "ArcherShore", P_ARCHER, Vector2(68 * T, 14 * T - 32))
	# Room 4
	_add(root, "SafePillarNear", P_LEDGE, Vector2(70 * T, 14 * T))
	_add_pit(root, "PitPillarNear", 72, 77, 14 * T)
	_add(root, "ArcherPillar", P_ARCHER, Vector2(79 * T, 12 * T - 32))
	_add_pit(root, "PitPillarFar", 81, 86, 14 * T)
	_add(root, "SafePillarFar", P_LEDGE, Vector2(88 * T, 14 * T))
	# The level's ONE pool (single use), about 65% of the way through.
	_add(root, "Pool", P_POOL, Vector2(91 * T, 14 * T))
	_add(root, "Hoplite2", P_HOPLITE, Vector2(95 * T, 14 * T - 32))
	# Crossfire: a second archer beyond the pillar.
	_add(root, "ArcherFar", P_ARCHER, Vector2(98 * T, 14 * T - 32))
	# Room 5
	_add(root, "SafeStair", P_LEDGE, Vector2(100 * T, 14 * T))
	_add_pit(root, "PitStair", 102, 117, 14 * T)
	_crumble(root, "Stair1", 103, 3, 12)
	_crumble(root, "Stair2", 107, 3, 10)
	_crumble(root, "Stair3", 111, 3, 8)
	# Room 6
	_add(root, "SafeHigh", P_LEDGE, Vector2(119 * T, 8 * T))
	# An archer on the high cliff shoots down at the crumbling stair.
	_add(root, "ArcherHigh", P_ARCHER, Vector2(121 * T, 8 * T - 32))
	_add(root, "Hoplite3", P_HOPLITE, Vector2(124 * T, 8 * T - 32))
	_add(root, "EyeShading", P_EYES, Vector2(127 * T, 8 * T - 32))
	_spears(root, "ExitSpears", 129, 3, 8, 0.0)
	_add(root, "MirrorExit", P_MIRROR, Vector2(134 * T, 8 * T - 32))
	_save(root, "level_2_cliffs")


# =====================================================================================
# Level 3: the cave of statues by torchlight. Mirror-bearers, plates, gates, a lift.
# =====================================================================================

## Rooms:
## 1 the hall of victims: old statues, the first mirror-bearer (whip the mirror aside,
##   then gaze)
## 2 the gate: a plate 10 tiles before a portcullis. Standing on it yourself is not enough
##   (the gate shuts as you leave); push a victim statue onto it
## 3 the spear trench: an eye-shading hoplite to petrify and push in as a bridge
## 4 the lift shaft up to the shelf; a mirror-bearer guarding a hoplite; a column to a shard
## 5 a crumbling ledge over a gap, the pool
## 6 the door: open only while a statue rests on the plate 450 px away (exit_needs_plate)
func _build_level_3() -> void:
	var root: LevelBase = _new_level("Level3Cave", LevelBase.Lighting.TORCHLIGHT)
	root.exit_needs_plate = true
	var t: TileMapLayer = root.get_node("Terrain")
	_ground(t, -4, 56, 19)
	# 3: trench 56..67, two rows down
	_ground(t, 56, 67, 21)
	_ground(t, 67, 80, 19)
	# 4: lift shaft 80..84, shelf 6 rows up
	_ground(t, 84, 110, 13)
	# 5: gap 110..117
	_ground(t, 120, 142, 13)        # past the widened crumbling gap
	_wall(t, -4, -2, 4, 19)
	_wall(t, 140, 142, 0, 13)
	# The cave ceiling: a band of rock along the top, with a lower overhang over room 4.
	_wall(t, -4, 142, -4, 4)
	_wall(t, 60, 78, 4, 7)

	root.get_node("Spawn").position = Vector2(128, 576)
	root.get_node("LevelExit").position = Vector2(138 * T, 13 * T)

	var torches: Array[Vector2] = [Vector2(10, 15), Vector2(26, 15), Vector2(42, 15), Vector2(70, 15),
			Vector2(90, 9), Vector2(104, 9), Vector2(122, 9), Vector2(134, 9)]
	for i in torches.size():
		_add(root, "Torch%d" % (i + 1), P_TORCH, torches[i] * T)
	for i in 6:
		_decor(root, "Stalactite%d" % (i + 1), "res://art/sprites/props/stalactite.png",
				Vector2((14 + i * 22) * T, 4 * T + 70), 70.0, true)

	# Room 1
	_add(root, "VictimOld1", P_VICTIM, Vector2(12 * T, 576), {"pose": 0})
	_add(root, "VictimOld2", P_VICTIM, Vector2(16 * T, 576), {"pose": 3, "faces_right": false})
	_add(root, "MirrorBearer1", P_MIRROR, Vector2(24 * T, 576))
	_add(root, "MirrorBearer1b", P_MIRROR, Vector2(20 * T, 576))
	# Room 2: plate at 34, gate at 45
	_add(root, "VictimGate", P_VICTIM, Vector2(30 * T, 576), {"pose": 1})
	_add(root, "GatePlate", P_PLATE, Vector2(35 * T, 19 * T))
	_gate(root, "Gate1", 45, 19, 4, NodePath("../GatePlate"))
	# Room 3
	_add(root, "HopliteGate", P_HOPLITE, Vector2(48 * T, 576))
	_add(root, "EyeShading", P_EYES, Vector2(52 * T, 576))
	_add(root, "SafeTrench", P_LEDGE, Vector2(54 * T, 19 * T))
	_spears(root, "TrenchSpearsA", 56, 5, 21, 0.0)
	_spears(root, "TrenchSpearsB", 61, 6, 21, 0.5)
	_add(root, "SafeTrenchFar", P_LEDGE, Vector2(69 * T, 19 * T))
	# Room 4
	_lift(root, "Lift", 80, 4, 19, 13, 4.0)
	_add_pit(root, "PitLift", 80, 84, 19 * T)
	_add(root, "SafeShelf", P_LEDGE, Vector2(86 * T, 13 * T))
	# The level's ONE pool (single use), about 62% of the way through.
	_add(root, "Pool", P_POOL, Vector2(88 * T, 13 * T))
	_add(root, "MirrorBearer2", P_MIRROR, Vector2(94 * T, 13 * T - 32))
	_add(root, "Hoplite", P_HOPLITE, Vector2(100 * T, 13 * T - 32))
	_column(root, "Column1", 104, 3, 10, 13)
	_add(root, "Shard1", P_SHARD, Vector2(105.5 * T, 9 * T))
	# Room 5
	_add(root, "SafeGap", P_LEDGE, Vector2(108 * T, 13 * T))
	_add_pit(root, "PitGap", 110, 120, 13 * T)
	_crumble(root, "CrumbleGap1", 111, 3, 13)
	_crumble(root, "CrumbleGap2", 115, 3, 13)
	_add(root, "SafeGapFar", P_LEDGE, Vector2(121 * T, 13 * T))
	_add(root, "LeaperFar", P_LEAPER, Vector2(122 * T, 13 * T - 20))
	# Room 6: the plate door
	_add(root, "VictimPlate", P_VICTIM, Vector2(124 * T, 13 * T - 32), {"pose": 0})
	_add(root, "Plate", P_PLATE, Vector2(128 * T, 13 * T))
	_spears(root, "DoorSpears", 130, 2, 13, 0.25)
	_add(root, "MirrorBearer3", P_MIRROR, Vector2(133 * T, 13 * T - 32))
	_add(root, "ArcherDoor", P_ARCHER, Vector2(135 * T, 13 * T - 32))
	var plate: Node = root.get_node("Plate")
	# CONNECT_PERSIST saves the connection in the .tscn, so it exists when the level loads.
	plate.connect(&"pressed", Callable(root, &"unlock_exit"), CONNECT_PERSIST)
	plate.connect(&"released", Callable(root, &"lock_exit"), CONNECT_PERSIST)
	_save(root, "level_3_cave")


## A level with only a starter floor (used for the boss arena when rebuilt on purpose).
func _build_starter(file: String, light: LevelBase.Lighting) -> void:
	var root: LevelBase = _new_level(file.to_pascal_case(), light)
	var t: TileMapLayer = root.get_node("Terrain")
	_ground(t, -4, 60, FLOOR_ROW)
	_wall(t, -4, -2, 8, FLOOR_ROW)
	_save(root, file)


# =====================================================================================
# Building blocks
# =====================================================================================

## Ground with its top surface at `top_row`, filled down to BOTTOM_ROW, columns [x0, x1).
func _ground(layer: TileMapLayer, x0: int, x1: int, top_row: int) -> void:
	_fill(layer, x0, x1, top_row, BOTTOM_ROW - top_row + 1)


## Solid rock between rows [row0, row1), columns [x0, x1) (walls, ceilings).
func _wall(layer: TileMapLayer, x0: int, x1: int, row0: int, row1: int) -> void:
	_fill(layer, x0, x1, row0, row1 - row0)


## A column platform: slab `width` tiles wide at column x, its top on `top_row`, the
## column reaching down to the ground surface at `ground_row`.
func _column(root: Node, node_name: String, x: int, width: int, top_row: int, ground_row: int) -> void:
	_add(root, node_name, P_COLUMN, Vector2(x * T, top_row * T),
			{"width_tiles": width, "column_height": float((ground_row - top_row) * T)})


## A crumbling ledge `width` tiles wide, its top on `top_row`.
func _crumble(root: Node, node_name: String, x: int, width: int, top_row: int) -> void:
	_add(root, node_name, P_CRUMBLE, Vector2(x * T, top_row * T), {"width_tiles": width})


## A lift: a moving slab in a shaft that carries her from `from_row` up to `to_row`.
func _lift(root: Node, node_name: String, x: int, width: int, from_row: int, to_row: int, period: float) -> void:
	_add(root, node_name, P_MOVING, Vector2(x * T, from_row * T),
			{"width_tiles": width, "travel": Vector2(0, (to_row - from_row) * T), "period": period})


## A ferry: a moving slab that glides sideways by `travel`.
func _ferry(root: Node, node_name: String, x: int, width: int, top_row: int, travel: Vector2, period: float) -> void:
	_add(root, node_name, P_MOVING, Vector2(x * T, top_row * T),
			{"width_tiles": width, "travel": travel, "period": period})


## A spear trap `width` tiles wide on the ground surface at `row`.
func _spears(root: Node, node_name: String, x: int, width: int, row: int, phase: float = 0.0) -> void:
	_add(root, node_name, P_SPEARS, Vector2(x * T, row * T), {"width_tiles": width, "phase": phase})


## A gate at column x standing on the surface at `row`, `height` tiles tall.
func _gate(root: Node, node_name: String, x: int, row: int, height: int, plate: NodePath) -> void:
	_add(root, node_name, P_GATE, Vector2(x * T, row * T), {"height_tiles": height, "plate": plate})


## A key hint. Typed arrays are built here, because the hint's @export properties are
## Array[StringName] / Array[String] and an untyped [] literal would not fit them.
func _hint(root: Node, node_name: String, pos: Vector2, actions: Array[StringName], keys: Array[String], icon: String) -> void:
	_add(root, node_name, P_HINT, pos, {"actions": actions, "keys": keys, "icon_name": icon})


## A decoration sprite (no collision) standing on `feet` (bottom-centre), `height` px
## tall, drawn behind the characters. `hang` hangs it from the point instead.
func _decor(root: Node, node_name: String, texture_path: String, feet: Vector2, height: float, hang: bool = false) -> void:
	if not ResourceLoader.exists(texture_path):
		return
	var tex: Texture2D = load(texture_path)
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = tex
	sprite.scale = Vector2.ONE * (height / tex.get_height())
	sprite.offset = Vector2(0, tex.get_height() * 0.5 if hang else -tex.get_height() * 0.5)
	sprite.position = feet
	sprite.z_index = -1
	root.add_child(sprite)
	sprite.owner = root


## A pit under the gap between tile columns x0 and x1, for a floor at `surface_y`:
## its top edge sits 112 px below the floor and it is 2 BL wider than the gap so a body
## falling past the edge is still caught.
func _add_pit(root: Node, node_name: String, x0: int, x1: int, surface_y: int) -> void:
	var center_x: float = (x0 + x1) * 0.5 * T
	_add(root, node_name, P_PIT, Vector2(center_x, surface_y + 112),
			{"size": Vector2((x1 - x0) * T + 128, 500)})


## An inherited-scene root of level_base. GEN_EDIT_STATE_MAIN is what makes saving it
## produce an inherited scene (a file that points at level_base) instead of a copy.
func _new_level(node_name: String, light: LevelBase.Lighting) -> LevelBase:
	var root: LevelBase = (load(BASE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	root.name = node_name
	root.lighting = light
	return root


## Fill tile columns [x0, x1) and `rows` rows from `row0` downward with the terrain tile.
func _fill(layer: TileMapLayer, x0: int, x1: int, row0: int, rows: int) -> void:
	for x in range(x0, x1):
		for y in range(row0, row0 + rows):
			layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))


## Instance a scene as a child of the level root, at `pos`, with optional property values.
func _add(root: Node, node_name: String, path: String, pos: Vector2, props: Dictionary = {}) -> void:
	var node: Node2D = (load(path) as PackedScene).instantiate()
	node.name = node_name
	node.position = pos
	for key: String in props:
		node.set(key, props[key])
	root.add_child(node)
	node.owner = root  # without an owner the node is not saved with the scene


## Pack the level into a scene file.
func _save(root: Node, file: String) -> void:
	var packed := PackedScene.new()
	packed.pack(root)
	var err: Error = ResourceSaver.save(packed, "res://scenes/levels/%s.tscn" % file)
	print("build_levels: %s -> %s" % [file, error_string(err)])
	root.free()
