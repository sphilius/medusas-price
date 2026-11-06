## sim_perseus.gd - dev-only headless check (scene: tools/sim_perseus.tscn).
## Perseus: the adapted shield window (median reaction + 0.15, clamped 0.45..1.0, base
## 1.0 with adaptation off), the least-guarded side rule, a gaze into his raised shield
## reflects (2 cracks), a gaze held in the open window counts as a hit and records a
## reaction time, 2 hits per phase move the phases on, and after phase 3 he turns to
## stone and the locked arena exit opens.
## Run: godot --headless --path . res://tools/sim_perseus.tscn  (exit code = failures)
extends Node

var _failures: int = 0
var _hits: Array = []
var _defeated: bool = false


func _ready() -> void:
	Events.player_hit.connect(func(c: int, s: StringName, _p: Vector2) -> void: _hits.append([c, s]))
	Events.boss_defeated.connect(func() -> void: _defeated = true)
	_test_rules()
	await _test_fight()
	print("sim_perseus: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


## The two adaptation rules, as plain math.
func _test_rules() -> void:
	var P := preload("res://scripts/perseus.gd")
	var fast: Array[float] = [0.1, 0.2, 0.3]
	var mid: Array[float] = [0.5, 0.7]
	var slow: Array[float] = [2.0]
	var none: Array[float] = []
	_check("fast reactions clamp the window to 0.45", is_equal_approx(P.adapted_window(fast, true), 0.45))
	_check("median 0.6 gives a 0.75 window", is_equal_approx(P.adapted_window(mid, true), 0.75))
	_check("slow reactions clamp the window to 1.0", is_equal_approx(P.adapted_window(slow, true), 1.0))
	_check("no data: base window", is_equal_approx(P.adapted_window(none, true), Balance.SHIELD_WINDOW_BASE))
	_check("adaptation off: base window", is_equal_approx(P.adapted_window(fast, false), Balance.SHIELD_WINDOW_BASE))
	_check("faces right more -> attacks from her left", P.least_guarded_side({-1: 2.0, 1: 9.0}, 1, true) == -1)
	_check("faces left more -> attacks from her right", P.least_guarded_side({-1: 9.0, 1: 2.0}, -1, true) == 1)
	_check("adaptation off -> from behind her", P.least_guarded_side({-1: 2.0, 1: 9.0}, -1, false) == 1)


## The arena: reflect, a window hit, phases, defeat, exit.
func _test_fight() -> void:
	RunLedger.start_run()
	var arena: Node = load("res://scenes/levels/boss.tscn").instantiate()
	add_child(arena)
	await _frames(5)
	var perseus = arena.get_node("Perseus")
	var exit: Area2D = arena.get_node("LevelExit")
	_check("the arena exit starts locked", not exit.visible and not exit.monitoring)

	# Shield up: the gaze bounces back for 2 cracks.
	perseus.add_gaze(1.0 / 60.0)
	_check("gaze into the raised shield reflects for 2 (%s)" % str(_hits),
			_hits.has([Balance.CRACKS_REFLECT, &"reflect"]))

	# Open window: a held gaze is a hit and a reaction time.
	perseus._drop_shield()
	await _frames(6)
	for i in int(Balance.PERSEUS_GAZE_HIT_TIME * 60.0) + 2:
		perseus.add_gaze(1.0 / 60.0)
	_check("a held gaze in the window lands one hit", perseus.hits_in_phase == 1)
	_check("the reaction time was recorded", perseus.reactions.size() == 1)

	perseus.register_gaze_hit()
	_check("2 hits end phase 1 and start the study beat", perseus.phase == 2 and perseus.state == perseus.State.STUDY)
	perseus.register_gaze_hit()
	perseus.register_gaze_hit()
	_check("2 more hits reach phase 3", perseus.phase == 3)
	perseus.register_gaze_hit()
	perseus.register_gaze_hit()
	_check("phase 3 done: defeated", perseus.state == perseus.State.DEFEATED)
	await _frames(int(Balance.PERSEUS_DEFEAT_STONE_TIME * 60.0) + 20)
	_check("boss_defeated was announced", _defeated)
	_check("he is a statue now", not arena.find_children("*", "Statue", true, false).is_empty())
	_check("the exit is open", exit.visible and exit.monitoring)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(label: String, ok: bool) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1
