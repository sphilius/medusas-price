## build_levels.gd - dev-only generator for the level scenes (run once, or again to reset them).
## Run it with:  godot --headless --path . res://tools/build_levels.tscn
## (a scene, not --script, so the autoloads like Balance and Events exist).
## It creates scenes/levels/level_1_temple.tscn (a short sample layout following the
## spec's beats) and level_2_cliffs, level_3_cave and boss (a small starter floor and
## the right lighting). Each one is an INHERITED scene of level_base.tscn, so editing
## level_base later updates all of them. After this, edit the scenes in the Godot editor.
## WARNING: running it overwrites those four scene files, including your edits.
extends Node

const BASE: String = "res://scenes/levels/level_base.tscn"

## Tile size in px (matches Balance.TILE_SIZE).
const T: int = 32
## Row of the floor's top surface: row 19 is y = 608 px.
const FLOOR_ROW: int = 19
## Floor thickness in rows.
const FLOOR_DEPTH: int = 3


## _ready runs once when this scene starts. It builds each level file in turn and then
## quits, so the whole tool is one command. Each _build_* function ends in _save().
func _ready() -> void:
	# Only the levels in BUILD are rewritten. Level 1 and the boss arena were edited by
	# hand after they were generated (the boss has Perseus and a pool), so they are left
	# alone; add their names here only to reset them on purpose.
	for level: String in BUILD:
		match level:
			"level_1_temple": _build_level_1()
			"level_2_cliffs": _build_level_2()
			"level_3_cave": _build_level_3()
			"boss": _build_starter("boss", LevelBase.Lighting.STORM, [])
	print("build_levels: done")
	get_tree().quit()


## Which level files this run writes (see _ready).
const BUILD: Array[String] = ["level_2_cliffs", "level_3_cave"]

## Surface rows used by levels 2 and 3: the low floor (y 608) and the high shelf
## 5 rows up (y 448, 2.5 BL higher). 2.5 BL is above Medusa's 2 BL jump but below
## a jump made from the top of a 1 BL statue, so a shelf wall is a statue puzzle.
const HIGH_ROW: int = 14
## Rows of rock under a shelf (down past the bottom of the screen).
const SHELF_DEPTH: int = 8


## Level 2: cliffs over the sea at dusk. Beats, left to right:
## 1) a hoplite: petrify him and push his statue against the 2.5 BL cliff to climb it
##    (a victim statue behind the spawn is the spare if his statue gets smashed),
## 2) an archer on the clifftop, 3) a 3 BL gap with the leaper waiting on the far side,
## 4) a pool, a hoplite, then an archer on a pillar island between two 2.5 BL gaps
##    (gaze him from the edge, about 3.3 BL away, out of whip reach),
## 5) a hoplite and an eye-shading hoplite (0.7 s gaze), the last pool, the exit.
func _build_level_2() -> void:
	var root: LevelBase = _new_level("Level2Cliffs", LevelBase.Lighting.DUSK)
	var terrain: TileMapLayer = root.get_node("Terrain")
	var high_y: int = HIGH_ROW * T  # 448
	_fill(terrain, -4, 30, FLOOR_ROW, FLOOR_DEPTH)       # start floor
	_fill(terrain, 30, 52, HIGH_ROW, SHELF_DEPTH)        # first clifftop (wall at x 960)
	_fill(terrain, 58, 90, HIGH_ROW, SHELF_DEPTH)        # after the 3 BL leaper gap
	_fill(terrain, 95, 99, HIGH_ROW - 2, SHELF_DEPTH + 2)  # the archer's pillar (1 BL higher)
	_fill(terrain, 104, 140, HIGH_ROW, SHELF_DEPTH)      # last stretch
	_fill(terrain, -4, -2, 8, 14)                        # left wall
	_fill(terrain, 138, 140, 4, 10)                      # right wall

	# Medusa starts a little in, with the spare statue BEHIND her: placed in front, it
	# stood between her and the hoplite and blocked her gaze (playtest, 2026-11-05).
	root.get_node("Spawn").position = Vector2(300, 576)
	root.get_node("LevelExit").position = Vector2(4300, high_y)

	# Beat 1: the hoplite whose statue is the climbing block; the spare behind her.
	_add(root, "VictimStatue", "res://scenes/props/victim_statue.tscn", Vector2(150, 576), {"pose": 0})
	_add(root, "HopliteCliff", "res://scenes/enemies/hoplite.tscn", Vector2(700, 576))
	_add(root, "SafeLedgeTop", "res://scenes/props/safe_ledge.tscn", Vector2(1100, high_y))
	# Beat 2: the clifftop archer.
	_add(root, "ArcherTop", "res://scenes/enemies/archer.tscn", Vector2(1500, high_y - 32))
	# Beat 3: the 3 BL gap (tiles 52..58) with the leaper on the far edge.
	_add(root, "SafeLedgeGapNear", "res://scenes/props/safe_ledge.tscn", Vector2(1600, high_y))
	_add_pit(root, "PitLeaper", 52, 58, high_y)
	_add(root, "Leaper", "res://scenes/enemies/leaper.tscn", Vector2(1890, high_y - 20))
	_add(root, "SafeLedgeGapFar", "res://scenes/props/safe_ledge.tscn", Vector2(1960, high_y))
	# Beat 4: pool, hoplite, then the pillar archer between two 2.5 BL gaps.
	_add(root, "PoolMid", "res://scenes/props/mirror_pool.tscn", Vector2(2300, high_y))
	_add(root, "Hoplite2", "res://scenes/enemies/hoplite.tscn", Vector2(2600, high_y - 32))
	_add(root, "SafeLedgePillarNear", "res://scenes/props/safe_ledge.tscn", Vector2(2780, high_y))
	_add_pit(root, "PitPillarNear", 90, 95, high_y)
	_add(root, "ArcherPillar", "res://scenes/enemies/archer.tscn", Vector2(3090, high_y - 64 - 32))
	_add_pit(root, "PitPillarFar", 99, 104, high_y)
	_add(root, "SafeLedgeFinal", "res://scenes/props/safe_ledge.tscn", Vector2(3400, high_y))
	# Beat 5: two hoplites (the second shades his eyes), the last pool, the exit.
	_add(root, "Hoplite3", "res://scenes/enemies/hoplite.tscn", Vector2(3700, high_y - 32))
	_add(root, "EyeShading", "res://scenes/enemies/eye_shading_hoplite.tscn", Vector2(3950, high_y - 32))
	_add(root, "PoolLast", "res://scenes/props/mirror_pool.tscn", Vector2(4150, high_y))
	_save(root, "level_2_cliffs")


## Level 3: the cave of statues by torchlight. Beats, left to right:
## 1) old victim statues, then a mirror-bearer on open floor (whip the mirror aside,
##    then gaze), 2) a victim statue and an eye-shading hoplite: push either statue to
##    the 2.5 BL shelf wall and climb, 3) a mirror-bearer guarding a hoplite on the
##    shelf, 4) a 2.5 BL gap, a pool, 5) the door: it is open only while something
##    rests on the pressure plate. Push the waiting victim statue onto the plate (or
##    petrify the last mirror-bearer and push his statue back), then walk out.
func _build_level_3() -> void:
	var root: LevelBase = _new_level("Level3Cave", LevelBase.Lighting.TORCHLIGHT)
	root.exit_needs_plate = true
	var terrain: TileMapLayer = root.get_node("Terrain")
	var high_y: int = HIGH_ROW * T  # 448
	_fill(terrain, -4, 64, FLOOR_ROW, FLOOR_DEPTH)       # cave floor
	_fill(terrain, 64, 92, HIGH_ROW, SHELF_DEPTH)        # the shelf (wall at x 2048)
	_fill(terrain, 97, 135, HIGH_ROW, SHELF_DEPTH)       # past the gap
	_fill(terrain, -4, -2, 8, 14)                        # left wall
	_fill(terrain, 133, 135, 4, 10)                      # right wall

	root.get_node("Spawn").position = Vector2(128, 576)
	root.get_node("LevelExit").position = Vector2(4100, high_y)

	# Torches along the way, a little above head height.
	var torches: Array[Vector2] = [Vector2(300, 480), Vector2(850, 480), Vector2(1400, 480),
			Vector2(1950, 480), Vector2(2500, 320), Vector2(3050, 320), Vector2(3600, 320), Vector2(4050, 320)]
	for i in torches.size():
		_add(root, "Torch%d" % (i + 1), "res://scenes/props/torch.tscn", torches[i])

	# Beat 1: the statues of those who came before, then the first mirror-bearer.
	_add(root, "VictimOld1", "res://scenes/props/victim_statue.tscn", Vector2(420, 576), {"pose": 0})
	_add(root, "VictimOld2", "res://scenes/props/victim_statue.tscn", Vector2(560, 576), {"pose": 2, "faces_right": false})
	_add(root, "MirrorBearer1", "res://scenes/enemies/mirror_bearer.tscn", Vector2(1000, 576))
	# Beat 2: two ways to get a climbing block to the shelf wall.
	_add(root, "VictimClimb", "res://scenes/props/victim_statue.tscn", Vector2(1500, 576), {"pose": 1})
	_add(root, "EyeShading", "res://scenes/enemies/eye_shading_hoplite.tscn", Vector2(1750, 576))
	_add(root, "SafeLedgeShelf", "res://scenes/props/safe_ledge.tscn", Vector2(2150, high_y))
	# Beat 3: a mirror-bearer in front of a hoplite.
	_add(root, "MirrorBearer2", "res://scenes/enemies/mirror_bearer.tscn", Vector2(2500, high_y - 32))
	_add(root, "Hoplite", "res://scenes/enemies/hoplite.tscn", Vector2(2750, high_y - 32))
	# Beat 4: the gap (tiles 92..97) and the pool after it.
	_add(root, "SafeLedgeGapNear", "res://scenes/props/safe_ledge.tscn", Vector2(2880, high_y))
	_add_pit(root, "PitGap", 92, 97, high_y)
	_add(root, "SafeLedgeGapFar", "res://scenes/props/safe_ledge.tscn", Vector2(3200, high_y))
	_add(root, "PoolLast", "res://scenes/props/mirror_pool.tscn", Vector2(3330, high_y))
	# Beat 5: the plate door. The plate is 450 px from the door, so Medusa cannot hold
	# it down herself and reach the exit; a statue has to stay on it.
	_add(root, "VictimPlate", "res://scenes/props/victim_statue.tscn", Vector2(3500, high_y - 32), {"pose": 0})
	_add(root, "Plate", "res://scenes/props/pressure_plate.tscn", Vector2(3650, high_y))
	_add(root, "MirrorBearer3", "res://scenes/enemies/mirror_bearer.tscn", Vector2(3900, high_y - 32))
	var plate: Node = root.get_node("Plate")
	# CONNECT_PERSIST saves the connection in the .tscn, so it exists when the level loads.
	plate.connect(&"pressed", Callable(root, &"unlock_exit"), CONNECT_PERSIST)
	plate.connect(&"released", Callable(root, &"lock_exit"), CONNECT_PERSIST)
	_save(root, "level_3_cave")


## A pit under the gap between tile columns x0 and x1, for a floor at `surface_y`:
## its top edge sits 112 px below the floor (as in level 1) and it is 2 BL wider than
## the gap so a body falling past the edge is still caught.
func _add_pit(root: Node, node_name: String, x0: int, x1: int, surface_y: int) -> void:
	var center_x: float = (x0 + x1) * 0.5 * T
	_add(root, node_name, "res://scenes/props/pit.tscn", Vector2(center_x, surface_y + 112),
			{"size": Vector2((x1 - x0) * T + 128, 500)})


## Level 1: temple steps at noon. Beats in order, left to right:
## 1) a hoplite standing on a ledge, 2) the leaper and the 4.5 BL gap (a sprint jump
## clears it), 3) a pool soon after the first cracks, 4) three hoplites, 5) a pool, the exit.
func _build_level_1() -> void:
	var root: LevelBase = _new_level("Level1Temple", LevelBase.Lighting.NOON)
	var terrain: TileMapLayer = root.get_node("Terrain")
	var gap_tiles: int = roundi(Balance.LEVEL1_GAP_BL * Balance.BL / T)  # 4.5 BL = 9 tiles
	var gap_start: int = 48
	var gap_end: int = gap_start + gap_tiles
	_fill(terrain, -4, gap_start, FLOOR_ROW, FLOOR_DEPTH)       # near floor
	_fill(terrain, gap_end, 126, FLOOR_ROW, FLOOR_DEPTH)        # far floor
	_fill(terrain, 20, 30, FLOOR_ROW - 3, 3)                    # the ledge (1.5 BL high)
	_fill(terrain, -4, -2, 8, 14)                               # left wall
	_fill(terrain, 124, 126, 8, 14)                             # right wall

	var gap_center: float = (gap_start + gap_tiles * 0.5) * T
	root.get_node("Spawn").position = Vector2(128, 576)
	root.get_node("LevelExit").position = Vector2(3800, FLOOR_ROW * T)

	# Beat 1: a victim to push or crack, a hoplite up on the ledge.
	_add(root, "VictimStatue", "res://scenes/props/victim_statue.tscn", Vector2(420, 576), {"pose": 1})
	_add(root, "HopliteLedge", "res://scenes/enemies/hoplite.tscn", Vector2(800, 480))
	# Beat 2: the leaper waits at the edge; safe ledges either side; the pit under the gap.
	_add(root, "SafeLedgeNear", "res://scenes/props/safe_ledge.tscn", Vector2(1400, FLOOR_ROW * T))
	_add(root, "Leaper", "res://scenes/enemies/leaper.tscn", Vector2(1470, 588))
	_add(root, "Pit", "res://scenes/props/pit.tscn", Vector2(gap_center, 720), {"size": Vector2(gap_tiles * T + 128, 500)})
	_add(root, "SafeLedgeFar", "res://scenes/props/safe_ledge.tscn", Vector2(gap_end * T + 60, FLOOR_ROW * T))
	# Beat 3: the first pool, after the first cracks.
	_add(root, "PoolFirst", "res://scenes/props/mirror_pool.tscn", Vector2(2000, FLOOR_ROW * T))
	_add(root, "VictimCrouched", "res://scenes/props/victim_statue.tscn", Vector2(2250, 576), {"pose": 2, "faces_right": false})
	# Beat 4: three hoplites in a row. Beat 5: the pool before the exit.
	_add(root, "Hoplite1", "res://scenes/enemies/hoplite.tscn", Vector2(2500, 576))
	_add(root, "Hoplite2", "res://scenes/enemies/hoplite.tscn", Vector2(2800, 576))
	_add(root, "Hoplite3", "res://scenes/enemies/hoplite.tscn", Vector2(3100, 576))
	_add(root, "PoolLast", "res://scenes/props/mirror_pool.tscn", Vector2(3450, FLOOR_ROW * T))
	_save(root, "level_1_temple")


## A level with only a starter floor (so you can stand in it) and its lighting.
func _build_starter(file: String, light: LevelBase.Lighting, torches: Array) -> void:
	var root: LevelBase = _new_level(file.to_pascal_case(), light)
	var terrain: TileMapLayer = root.get_node("Terrain")
	_fill(terrain, -4, 60, FLOOR_ROW, FLOOR_DEPTH)
	_fill(terrain, -4, -2, 8, 14)
	var i: int = 0
	for pos: Vector2 in torches:
		i += 1
		_add(root, "Torch%d" % i, "res://scenes/props/torch.tscn", pos)
	_save(root, file)


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


func _save(root: Node, file: String) -> void:
	var packed := PackedScene.new()
	packed.pack(root)
	var err: Error = ResourceSaver.save(packed, "res://scenes/levels/%s.tscn" % file)
	print("build_levels: %s -> %s" % [file, error_string(err)])
	root.free()
