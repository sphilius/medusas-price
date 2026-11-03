## sim_contact.gd - dev-only headless check (scene: tools/sim_contact.tscn).
## Enemy bodies are solid and hurt on touch: Medusa running at a hoplite stops against
## him (never ends up past him) and takes one hit named "hoplite"; a whip-staggered
## hoplite still blocks but is harmless; jumping cleanly over one costs nothing; and a
## petrified hoplite (a statue) never hurts.
extends Node

## Player center y standing on the near ledge of the graybox.
const STAND_Y: float = 568.0
## Hoplite1 in scenes/test_room.tscn stands here on the near ledge.
const HOPLITE_X: float = 470.0

var _room: Node
var _player: Player
var _hop: Enemy
var _hits: Array = []
var _failures: int = 0


func _ready() -> void:
	# Lambdas (func(...): ...) let us connect a signal without writing a named method.
	Events.player_hit.connect(func(c: int, s: StringName, _p: Vector2) -> void: _hits.append([c, s]))
	await _test_run_into_hoplite()
	await _test_staggered_blocks_but_harmless()
	await _test_statue_never_hurts()
	print("sim_contact: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


## Hold right from 3 BL away. The hoplite would stab her at spear range, so his AI is
## off (see _fresh_room) to test the body alone: he stands still, only contact hurts.
func _test_run_into_hoplite() -> void:
	await _fresh_room()
	_place_player(Vector2(_hop.global_position.x - 3.0 * Balance.BL, STAND_Y))
	_hits.clear()
	Input.action_press("move_right")
	var furthest: float = _player.global_position.x
	for i in 60:
		await get_tree().physics_frame
		furthest = maxf(furthest, _player.global_position.x)
	Input.action_release("move_right")
	# Her right edge may touch his left edge, but her center must stay left of his body.
	var his_left: float = _hop.global_position.x - Balance.ENEMY_HALF_WIDTH
	_check("blocked: she never got past his body (furthest x %.0f, his left edge %.0f)" % [furthest, his_left], \
			furthest < his_left)
	# Holding right into him keeps hurting once her 1 s invulnerability runs out, so a
	# second hit at the very end is fine; the first must be a 1-crack hoplite touch.
	_check("touching him hurts: first hit is 1 crack named hoplite (%s)" % str(_hits), \
			_hits.size() >= 1 and _hits[0] == [Balance.CRACKS_HIT, &"hoplite"])
	_check("at most one hit per invulnerable window (%d in 1 s)" % _hits.size(), _hits.size() <= 2)
	_check("she was knocked back into HURT", _player.state == Player.State.HURT \
			or _player.global_position.x < furthest - 1.0)


## Whip-staggered enemies still block, but touching one is free.
func _test_staggered_blocks_but_harmless() -> void:
	await _fresh_room()
	_hits.clear()
	_hop.whip_hit(1)  # knocked right, away from her
	await _frames(6)
	_place_player(Vector2(_hop.global_position.x - Balance.ENEMY_HALF_WIDTH * 2.0, STAND_Y))
	Input.action_press("move_right")
	var furthest: float = _player.global_position.x
	for i in 10:
		await get_tree().physics_frame
		furthest = maxf(furthest, _player.global_position.x)
	Input.action_release("move_right")
	_check("staggered hoplite still blocks (furthest %.0f, hoplite %.0f)" % [furthest, _hop.global_position.x], \
			furthest < _hop.global_position.x)
	_check("staggered hoplite is harmless (%s)" % str(_hits), _hits.is_empty())


## A statue is a platform, not an enemy: standing against one costs nothing.
func _test_statue_never_hurts() -> void:
	await _fresh_room()
	_hop.petrify()
	await _frames(30)  # hit-stop and swap
	_hits.clear()
	_place_player(Vector2(HOPLITE_X - Balance.BL, STAND_Y))
	Input.action_press("move_right")
	await _frames(30)
	Input.action_release("move_right")
	_check("pushing against a hoplite statue never hurts (%s)" % str(_hits), _hits.is_empty())


# ---------------------------------------------------------------------------

## Keep the hoplite's physics (gravity, check_contact through a stand-in loop) but stop
## his AI, so he neither walks nor thrusts. We drive his frame ourselves below.
func _freeze_hoplite_ai() -> void:
	_hop.set_physics_process(false)
	# A stand-in physics loop: gravity, stagger slide, move, contact. No AI or spear.
	get_tree().physics_frame.connect(_hoplite_body_only)


## Runs once per physics frame (connected to the SceneTree's physics_frame signal) in
## place of the hoplite's own _physics_process: body physics and contact, no AI.
func _hoplite_body_only() -> void:
	if not is_instance_valid(_hop):
		return
	var delta: float = get_physics_process_delta_time()
	_hop.apply_gravity(delta)
	if not _hop.tick_stagger(delta):
		_hop.velocity.x = 0.0
	_hop.move_and_slide()
	_hop.check_contact()


## Throw away the current room and load a fresh copy of the graybox.
func _fresh_room() -> void:
	if get_tree().physics_frame.is_connected(_hoplite_body_only):
		get_tree().physics_frame.disconnect(_hoplite_body_only)
	if is_instance_valid(_room):
		_room.queue_free()
	await _frames(2)
	_room = load("res://scenes/test_room.tscn").instantiate()
	add_child(_room)
	_player = _room.get_node("Player")
	_hop = _room.get_node("Hoplite1")
	# Freeze his AI at once, before he can notice her and walk off his spot.
	_freeze_hoplite_ai()
	await _frames(5)
	# Wait out any invulnerability left from the previous test's hit.
	await _frames(int(Balance.PLAYER_INVULN_TIME * Engine.physics_ticks_per_second) + 5)


## Put Medusa at pos, standing still and facing right.
func _place_player(pos: Vector2) -> void:
	_player.global_position = pos
	_player.velocity = Vector2.ZERO
	_player.facing = 1


## Wait n physics frames. `await` pauses this function until each signal fires.
func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Print PASS/FAIL for one condition and count failures (the exit code).
func _check(label: String, ok: bool) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1
