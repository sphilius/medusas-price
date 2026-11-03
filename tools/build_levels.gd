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
	_build_level_1()
	_build_starter("level_2_cliffs", LevelBase.Lighting.DUSK, [])
	_build_starter("level_3_cave", LevelBase.Lighting.TORCHLIGHT, [Vector2(300, 480), Vector2(700, 480), Vector2(1100, 480)])
	_build_starter("boss", LevelBase.Lighting.STORM, [])
	print("build_levels: done")
	get_tree().quit()


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
