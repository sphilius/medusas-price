## sim_statue.gd - dev-only headless check (scene: tools/sim_statue.tscn).
## Petrifies fresh dummies in the test room, then pushes the statues and prints
## PASS/FAIL: the test room's PlatformDummy can be frozen from the platform and
## pushed off it, push delay, slide speed and stop on release, stop at a wall
## (one thud), push off a platform edge and land, and a mid-air statue that
## hangs until pushed and then falls.
extends Node

const DUMMY: PackedScene = preload("res://scenes/dummy_enemy.tscn")
## Top of FloorA: a 64 px body standing on it has its center 32 px higher.
const FLOOR_Y: float = 568.0
## Top of PlatformA (y 492, 24 tall): body center when standing on it.
const PLATFORM_Y: float = 448.0

var _room: Node
var _player: Player
## Every Events.statue_thud as [position, landed].
var _thuds: Array = []
var _failures: int = 0


func _ready() -> void:
	_room = load("res://scenes/test_room.tscn").instantiate()
	add_child(_room)
	_player = _room.get_node("Player")
	_room.get_node("DummyEnemy").queue_free()  # the patrolling one would wander into tests
	Events.statue_thud.connect(func(p, landed): _thuds.append([p, landed]))
	await _frames(10)

	await _test_platform_dummy_scene()
	await _test_ground_push()
	await _test_wall_stop()
	await _test_platform_edge_fall()
	await _test_mid_air_push()

	print("sim_statue: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


## The room's own PlatformDummy: gaze it from the platform, push it off, hear it land.
func _test_platform_dummy_scene() -> void:
	var dummy: Enemy = _room.get_node("PlatformDummy")
	var start: Vector2 = dummy.position
	await _frames(30)
	_check("platform dummy stands still", dummy.position.distance_to(start) < 1.0)
	_place_player(Vector2(360, PLATFORM_Y))
	Input.action_press("gaze")
	await _frames(40)
	Input.action_release("gaze")
	_check("platform dummy petrified from the platform", not is_instance_valid(dummy))
	var statue: Statue = get_tree().get_nodes_in_group(&"statues").back() as Statue
	_thuds.clear()
	Input.action_press("move_right")
	await _frames(120)
	Input.action_release("move_right")
	await _frames(60)
	_check("pushed off the platform, landed on the floor", statue.motion == Statue.Motion.STILL 			and absf(statue.position.y - FLOOR_Y) < 1.0)
	_check("landing thud played", not _thuds.is_empty() and _thuds.back()[1] == true)
	await _free(statue)


## No slide before the delay, about 96 px/s after it, stops (with a thud) on release.
func _test_ground_push() -> void:
	var statue: Statue = await _make_statue(Vector2(600, FLOOR_Y))
	_place_player(Vector2(530, FLOOR_Y))
	_thuds.clear()
	Input.action_press("move_right")
	await _frames(18)  # 0.3 s: still inside the push delay
	_check("no slide before the push delay", is_equal_approx(statue.position.x, 600.0))
	await _frames(30)  # past the delay, sliding
	_check("slides once the delay passes", statue.motion == Statue.Motion.SLIDING)
	var x0: float = statue.position.x
	await _frames(60)
	var moved: float = statue.position.x - x0
	_check("slide speed about STATUE_PUSH_SPEED (%.0f px in 1 s)" % moved,
			moved > Balance.STATUE_PUSH_SPEED * 0.8 and moved <= Balance.STATUE_PUSH_SPEED + 2.0)
	_check("player keeps contact while pushing", absf(statue.position.x - _player.position.x - 40.0) < 4.0)
	Input.action_release("move_right")
	await _frames(10)
	var x1: float = statue.position.x
	await _frames(20)
	_check("stops when the push is released", statue.motion == Statue.Motion.STILL and is_equal_approx(statue.position.x, x1))
	_check("one stop thud, not landed", _thuds.size() == 1 and _thuds[0][1] == false)
	_check("statue never fell (stayed on the floor)", absf(statue.position.y - FLOOR_Y) < 1.0)
	await _free(statue)


## Pushed into the pillar it stops flush against it, with exactly one thud.
func _test_wall_stop() -> void:
	var statue: Statue = await _make_statue(Vector2(790, FLOOR_Y))
	_place_player(Vector2(720, FLOOR_Y))
	_thuds.clear()
	Input.action_press("move_right")
	await _frames(150)
	Input.action_release("move_right")
	await _frames(10)
	var pillar_left: float = 880.0 - 16.0
	_check("stops flush at the pillar", absf(statue.position.x + 20.0 - pillar_left) < 2.0)
	_check("exactly one thud at the wall", _thuds.size() == 1)
	await _free(statue)


## Pushed off PlatformA it falls and lands on the floor below with a landing thud.
func _test_platform_edge_fall() -> void:
	var statue: Statue = await _make_statue(Vector2(470, PLATFORM_Y))
	_place_player(Vector2(420, PLATFORM_Y))
	_thuds.clear()
	Input.action_press("move_right")
	var fell: bool = false
	for i in 120:
		await _frames(1)
		fell = fell or statue.motion == Statue.Motion.FALLING
	Input.action_release("move_right")
	await _frames(60)
	_check("falls off the platform edge", fell)
	_check("lands on the floor below", statue.motion == Statue.Motion.STILL and absf(statue.position.y - FLOOR_Y) < 1.0)
	_check("landing thud", not _thuds.is_empty() and _thuds.back()[1] == true)
	await _free(statue)


## A statue frozen mid-air beside the platform hangs until pushed, then drops to the floor.
func _test_mid_air_push() -> void:
	var statue: Statue = await _make_statue(Vector2(540, 470))
	_place_player(Vector2(300, PLATFORM_Y))
	await _frames(60)
	_check("mid-air statue hangs while untouched", is_equal_approx(statue.position.y, 470.0))
	_place_player(Vector2(470, PLATFORM_Y))
	Input.action_press("move_right")
	await _frames(60)
	Input.action_release("move_right")
	await _frames(60)
	_check("pushed mid-air statue lands on the floor", statue.motion == Statue.Motion.STILL \
			and absf(statue.position.y - FLOOR_Y) < 1.0)
	await _free(statue)


## Petrify a motionless dummy at `pos` and return its statue.
func _make_statue(pos: Vector2) -> Statue:
	var dummy: Enemy = DUMMY.instantiate()
	dummy.position = pos
	_room.add_child(dummy)
	dummy.set_physics_process(false)
	dummy.get_node("JumpTimer").stop()
	await _frames(1)
	dummy.petrify()
	await _frames(10)  # let the hit-stop pass
	var statues: Array[Node] = get_tree().get_nodes_in_group(&"statues")
	return statues.back() as Statue


func _place_player(pos: Vector2) -> void:
	_player.position = pos
	_player.velocity = Vector2.ZERO
	_player.facing = 1


func _free(node: Node) -> void:
	node.queue_free()
	await _frames(2)


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
