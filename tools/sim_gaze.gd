## sim_gaze.gd - dev-only headless check (scene: tools/sim_gaze.tscn).
## Runs the gaze against fresh dummies in the test room and prints PASS/FAIL:
## petrify on the ground, timer reset on release, walls block line of sight,
## freeze mid-air and stay put, and the player can stand on that statue.
extends Node

const DUMMY: PackedScene = preload("res://scenes/dummy_enemy.tscn")

var _room: Node
var _player: Player
## Args of every Events.petrified seen, in order.
var _petrified_log: Array = []
var _failures: int = 0


func _ready() -> void:
	_room = load("res://tools/sim_room.tscn").instantiate()
	add_child(_room)
	_player = _room.get_node("Player")
	for child in _room.get_children():  # tests use their own dummies
		if child is Enemy:
			child.queue_free()
	Events.petrified.connect(func(t, f, fl, p): _petrified_log.append([t, f, fl, p]))
	await _frames(10)

	await _test_ground_petrify()
	await _test_release_resets()
	await _test_wall_blocks()
	await _test_mid_air_and_stand()

	print("sim_gaze: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


## Dummy held still in front of the player petrifies after ~GAZE_HOLD, flip reported.
func _test_ground_petrify() -> void:
	var dummy: Enemy = _spawn_still_dummy(Vector2(600, 568), -1)
	_place_player(Vector2(450, 568), 1)
	RunLedger.start_run()
	Input.action_press("gaze")
	await _frames(12)
	_check("rooted in GAZE state while held", _player.state == Player.State.GAZE)
	_check("tint progressing toward marble", dummy.visual.modulate.r > Balance.COLOR_BLACK.r + 0.05)
	await _frames(30)
	Input.action_release("gaze")
	_check("ground dummy petrified", not is_instance_valid(dummy))
	_check("petrified signal fired once", _petrified_log.size() == 1)
	if _petrified_log.size() == 1:
		var args: Array = _petrified_log[0]
		_check("signal type/frame/flip", args[0] == &"dummy" and args[1] == 0 and args[2] == true)
		_check("signal position", (args[3] as Vector2).distance_to(Vector2(600, 568)) < 1.0)
	# RunLedger heard the same petrify and can hand it to the AI features as JSON.
	var logged: Array = RunLedger.events_of("petrify")
	_check("ledger logged one petrify", logged.size() == 1)
	if logged.size() == 1:
		var data: Dictionary = logged[0]["data"]
		_check("ledger event carries type/frame/flip/position", data["enemy_type"] == "dummy" \
				and data["pose_frame"] == 0 and data["flip"] == true \
				and Vector2(data["position"][0], data["position"][1]).distance_to(Vector2(600, 568)) < 1.0)
	var parsed: Variant = JSON.parse_string(RunLedger.to_json())
	_check("ledger JSON round-trips", parsed is Array and (parsed as Array).size() == 1)
	var summary: Dictionary = RunLedger.summary()
	_check("ledger summary counts the dummy", summary["petrified_by_enemy"].get("dummy", 0) == 1 \
			and summary["counts"].get("petrify", 0) == 1)
	var statue: Statue = _latest_statue()
	_check("statue on layer 4 at dummy spot", statue != null and statue.collision_layer == Balance.PHYS_STATUES \
			and statue.position.distance_to(Vector2(600, 568)) < 1.0)
	_check("statue keeps flip and is marble", statue != null and statue.get_node("Visual").scale.x == -1 \
			and statue.get_node("Visual").modulate == Balance.COLOR_MARBLE)
	await _frames(10)
	_check("player leaves GAZE on release", _player.state != Player.State.GAZE)
	await _clear_statues()


## Two 0.3 s gazes with a release between never reach 0.4 s.
func _test_release_resets() -> void:
	var dummy: Enemy = _spawn_still_dummy(Vector2(600, 568), 1)
	_place_player(Vector2(450, 568), 1)
	Input.action_press("gaze")
	await _frames(18)
	Input.action_release("gaze")
	await _frames(5)
	_check("tint resets on release", dummy.visual.modulate == Balance.COLOR_BLACK)
	Input.action_press("gaze")
	await _frames(18)
	Input.action_release("gaze")
	_check("release resets the timer", is_instance_valid(dummy))
	dummy.queue_free()
	await _frames(2)


## The pillar between player and dummy blocks the gaze entirely.
func _test_wall_blocks() -> void:
	var dummy: Enemy = _spawn_still_dummy(Vector2(770, 568), 1)
	_place_player(Vector2(960, 568), -1)
	Input.action_press("gaze")
	await _frames(60)
	Input.action_release("gaze")
	_check("pillar blocks line of sight", is_instance_valid(dummy))
	dummy.queue_free()
	await _frames(2)


## A jumping dummy frozen in the air hangs there, and the player can land on it.
func _test_mid_air_and_stand() -> void:
	var dummy: Enemy = DUMMY.instantiate()
	dummy.position = Vector2(600, 568)
	_room.add_child(dummy)
	dummy.get_node("JumpTimer").stop()
	_place_player(Vector2(420, 568), 1)
	await _frames(3)
	dummy.velocity.y = Balance.DUMMY_JUMP_VELOCITY
	Input.action_press("gaze")
	await _frames(45)
	Input.action_release("gaze")
	var statue: Statue = _latest_statue()
	_check("dummy froze mid-air", statue != null and statue.position.y < 568.0 - Balance.BL * 0.5)
	if statue == null:
		return
	var frozen_y: float = statue.position.y
	await _frames(120)
	_check("mid-air statue does not fall", is_equal_approx(statue.position.y, frozen_y))

	# Drop the player onto it from a little above.
	_place_player(Vector2(statue.position.x, frozen_y - Balance.BL - 40.0), 1)
	await _frames(60)
	var stand_y: float = frozen_y - Balance.BL  # both bodies are 64 px tall
	_check("player stands on the statue", _player.is_on_floor() and absf(_player.position.y - stand_y) < 2.0)
	await _frames(60)
	_check("standing is stable", _player.is_on_floor() and absf(_player.position.y - stand_y) < 2.0)


func _spawn_still_dummy(pos: Vector2, face: int) -> Enemy:
	var dummy: Enemy = DUMMY.instantiate()
	dummy.position = pos
	_room.add_child(dummy)
	dummy.set_physics_process(false)  # no walking or jumping
	dummy.get_node("JumpTimer").stop()
	dummy.set_facing(face)
	return dummy


func _place_player(pos: Vector2, face: int) -> void:
	_player.position = pos
	_player.velocity = Vector2.ZERO
	_player.facing = face


func _latest_statue() -> Statue:
	var statues: Array[Node] = get_tree().get_nodes_in_group(&"statues")
	return statues.back() as Statue if not statues.is_empty() else null


func _clear_statues() -> void:
	for s in get_tree().get_nodes_in_group(&"statues"):
		s.queue_free()
	await _frames(2)


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
