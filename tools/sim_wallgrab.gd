## sim_wallgrab.gd - dev-only headless check (scene: tools/sim_wallgrab.tscn) for the
## whip wall-grab. In the shared sim room, Medusa is put in mid-air beside the pillar
## (x 864-896, top y 504), facing it, and lashes. Checks that her snakes grab the
## pillar and hold her still, that a jump springs her up past its top, and that a lash
## at nothing (facing away) does not grab.
## Prints PASS/FAIL lines and exits with the number of failures.
extends Node

var _failures: int = 0


func _ready() -> void:
	var room: Node = load("res://tools/sim_room.tscn").instantiate()
	add_child(room)
	var p: Player = room.get_node("Player")
	await _wait(0.2)
	# Beside the pillar, in the air, facing it.
	p._teleport(Vector2(800.0, 540.0))
	p.facing = 1
	Input.action_press(&"whip")
	await get_tree().physics_frame
	Input.action_release(&"whip")
	await _wait(Balance.WHIP_ANTICIPATION + 0.05)
	_check(p._clinging, "a mid-air lash at the pillar grabs it")
	var y_hold: float = p.global_position.y
	await _wait(Balance.WALL_GRAB_HOLD_S * 0.6)
	_check(p._clinging and absf(p.global_position.y - y_hold) < 2.0, "she hangs still while held")
	Input.action_press(&"jump")
	await get_tree().physics_frame
	var top_y: float = p.global_position.y
	for i in 40:
		await get_tree().physics_frame
		top_y = minf(top_y, p.global_position.y)
	Input.action_release(&"jump")
	_check(not p._clinging and top_y < 504.0 - 32.0, "a jump from the wall springs her up past the pillar top")
	# Facing away, nothing within reach: no grab.
	await _wait(1.0)
	p._teleport(Vector2(800.0, 540.0))
	p.facing = -1
	Input.action_press(&"whip")
	await get_tree().physics_frame
	Input.action_release(&"whip")
	await _wait(Balance.WHIP_ANTICIPATION + 0.05)
	_check(not p._clinging, "a lash at nothing does not grab")
	print("sim_wallgrab: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _wait(seconds: float) -> void:
	for i in ceili(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
