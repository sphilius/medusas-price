## sim_combat.gd - dev-only headless check (scene: tools/sim_combat.tscn) for whip combat.
## Checks: a hoplite dies after ENEMY_WHIP_HP lashes (and not one sooner); a lash during
## its wind-up is a parry that leaves it exposed (and the gaze hold drops to
## PARRY_GAZE_HOLD); a lash on an exposed enemy is the snake finisher, which kills it.
## Each kill emits Events.enemy_slain. Prints PASS/FAIL; exit code = failures.
extends Node

const HOPLITE: PackedScene = preload("res://scenes/enemies/hoplite.tscn")
const ROOM: PackedScene = preload("res://scenes/levels/level_1_temple.tscn")

var _failures: int = 0
## How many enemy_slain signals arrived (a one-element array so the lambda can change it).
var _slain: Array[int] = [0]


## Runs the tests in order; each `await` lets the physics frames for that test pass.
func _ready() -> void:
	Events.enemy_slain.connect(func(_t: StringName, _p: Vector2) -> void: _slain[0] += 1)
	await _test_lashes_kill()
	await _test_parry_and_finisher()
	print("sim_combat: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


## Prints one PASS/FAIL line and counts failures (the exit code at the end).
func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


## A level with one hoplite standing on the forecourt floor, far from Medusa.
func _setup() -> Array:
	var level: Node = ROOM.instantiate()
	var hop: Enemy = HOPLITE.instantiate()
	hop.position = Vector2(600.0, 576.0)
	level.add_child(hop)
	add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return [level, hop]


## Waits `seconds` of physics time.
func _wait(seconds: float) -> void:
	for i in ceili(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


## A hoplite takes exactly its hp in lashes: one short and it lives, the last kills it.
func _test_lashes_kill() -> void:
	var got: Array = await _setup()
	var level: Node = got[0]
	var hop: Enemy = got[1]
	var hp: int = hop.hp
	_check(hp == Balance.ENEMY_WHIP_HP[&"hoplite"], "hoplite starts with its whip hp")
	_slain[0] = 0
	for i in hp - 1:
		hop.whip_hit(1)
		await _wait(Balance.WHIP_STAGGER + 0.05)
	_check(is_instance_valid(hop) and not hop._dying, "it survives one lash short of its hp")
	hop.whip_hit(1)
	await _wait(Balance.ENEMY_DEATH_S + 0.2)
	_check(not is_instance_valid(hop) and _slain[0] == 1, "the last lash kills it (enemy_slain)")
	level.free()
	await get_tree().physics_frame


## A lash during the wind-up parries (no hp lost, exposed); the next lash finishes it.
## hoplite.gd has no class_name, so its enum is reached through the instance (hop.State).
func _test_parry_and_finisher() -> void:
	var got: Array = await _setup()
	var level: Node = got[0]
	var hop: Enemy = got[1]
	_slain[0] = 0
	hop.state = hop.State.WINDUP  # as if it had started its thrust wind-up
	_check(hop.is_telegraphing(), "a hoplite winding up is telegraphing")
	hop.whip_hit(1)
	await get_tree().physics_frame
	_check(hop.is_exposed() and is_equal_approx(hop.gaze_hold_time, Balance.PARRY_GAZE_HOLD), "a lash during the wind-up parries: exposed, near-instant gaze")
	_check(hop.hp == Balance.ENEMY_WHIP_HP[&"hoplite"], "the parry lash does not cost hp")
	hop.whip_hit(1)
	# Generous wait: the hit-stops slow game time while they run.
	await _wait(Balance.FINISHER_TIME + Balance.ENEMY_DEATH_S + 1.5)
	_check(not is_instance_valid(hop) and _slain[0] == 1, "a lash on the exposed enemy is the finisher: it dies")
	level.free()
	await get_tree().physics_frame
