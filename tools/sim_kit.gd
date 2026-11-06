## sim_kit.gd - dev-only headless check (scene: tools/sim_kit.tscn) for the platformer kit.
## Builds a small level-1 copy, drops the kit pieces into it, and checks that:
## the level re-skins every piece with the terrain look; a moving platform moves and
## carries Medusa; a crumbling ledge drops her after CRUMBLE_DELAY and comes back after
## CRUMBLE_RESPAWN; a column platform lets her jump up through it and stand on top.
## Prints PASS/FAIL lines and exits with the number of failures.
extends Node

const LEVEL: PackedScene = preload("res://scenes/levels/level_1_temple.tscn")
const MOVING: PackedScene = preload("res://scenes/props/moving_platform.tscn")
const CRUMBLE: PackedScene = preload("res://scenes/props/crumbling_ledge.tscn")
const COLUMN: PackedScene = preload("res://scenes/props/column_platform.tscn")

var _failures: int = 0


## Runs the tests in order; each `await` waits for that test's physics frames to pass.
func _ready() -> void:
	await _test_moving()
	await _test_crumble()
	await _test_column()
	print("sim_kit: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


## Prints one PASS/FAIL line and counts failures (the exit code at the end).
func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


## A fresh level with one piece added BEFORE the level enters the tree, the way a piece
## saved in a level scene arrives (so the level's _ready re-skins it).
func _level_with(piece: Node2D, at: Vector2) -> Array:
	var level: LevelBase = LEVEL.instantiate()
	piece.position = at
	level.add_child(piece)
	add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var player: Player = get_tree().get_first_node_in_group(&"player")
	return [level, player]


## Waits `seconds` of physics time.
func _wait(seconds: float) -> void:
	for i in ceili(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


## A sideways platform high above the floor, Medusa set down on it.
func _test_moving() -> void:
	var piece: MovingPlatform = MOVING.instantiate()
	piece.width_tiles = 4
	piece.travel = Vector2(160.0, 0.0)
	piece.period = 2.0
	var got: Array = await _level_with(piece, Vector2(600.0, 300.0))
	var level: Node = got[0]
	var player: Player = got[1]
	_check(piece.tiles.material is ShaderMaterial, "moving platform gets the terrain material")
	player.global_position = piece.global_position + Vector2(64.0, -40.0)
	player.velocity = Vector2.ZERO
	await _wait(0.4)
	var start_x: float = player.global_position.x
	var body: Node2D = piece.tiles.get_parent()  # the moving collider holding the tiles
	var piece_start: float = body.global_position.x
	await _wait(0.5)
	_check(body.global_position.x > piece_start + 20.0, "moving platform moves")
	_check(player.is_on_floor() and player.global_position.x > start_x + 20.0, "it carries Medusa along")
	level.free()
	await get_tree().physics_frame


## A ledge above the floor; she stands on it, it drops, she falls, it returns.
func _test_crumble() -> void:
	var piece: CrumblingLedge = CRUMBLE.instantiate()
	piece.width_tiles = 3
	var got: Array = await _level_with(piece, Vector2(600.0, 400.0))
	var level: Node = got[0]
	var player: Player = got[1]
	player.global_position = piece.global_position + Vector2(48.0, -40.0)
	player.velocity = Vector2.ZERO
	await _wait(0.2)
	_check(player.is_on_floor() and player.global_position.y < 400.0, "Medusa stands on the crumbling ledge")
	await _wait(Balance.CRUMBLE_DELAY + 0.4)
	_check(piece.state == CrumblingLedge.State.FALLEN and player.global_position.y > 420.0, "it drops her after CRUMBLE_DELAY")
	await _wait(Balance.CRUMBLE_RESPAWN)
	_check(piece.state == CrumblingLedge.State.SOLID and piece.tiles.collision_enabled, "it comes back after CRUMBLE_RESPAWN")
	level.free()
	await get_tree().physics_frame


## A column ledge 3 BL... lower: its top 96 px above the floor; she jumps up through it.
func _test_column() -> void:
	var piece: ColumnPlatform = COLUMN.instantiate()
	piece.width_tiles = 3
	piece.column_height = 96.0
	var got: Array = await _level_with(piece, Vector2(560.0, 608.0 - 96.0))
	var level: Node = got[0]
	var player: Player = got[1]
	player.global_position = Vector2(608.0, 576.0)  # on the floor, under the ledge
	player.velocity = Vector2.ZERO
	await _wait(0.2)
	Input.action_press(&"jump")
	await _wait(0.45)
	Input.action_release(&"jump")
	await _wait(0.6)
	_check(player.is_on_floor() and player.global_position.y < 512.0, "she jumps up through the column ledge and stands on it")
	level.free()
	await get_tree().physics_frame
