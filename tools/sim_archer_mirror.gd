## sim_archer_mirror.gd - dev-only headless check (scene: tools/sim_archer_mirror.tscn).
## Archer: waits for range + line of sight, draws 0.5 s then shoots, the arrow hits for
## 1 crack ("arrow"), a statue between them blocks sight and an arrow sticks into it,
## 2.5 s cooldown. Mirror-bearer: a gaze into the mirror reflects (2 cracks "reflect",
## ledger event, he does not petrify); knock_mirror lets the gaze petrify him.
## Eye-shading hoplite: gaze_hold_time 0.7 and the hand-over-eyes pose is shown.
extends Node

## Player center y standing on the near ledge of the graybox.
const STAND_Y: float = 568.0

var _room: Node
var _player: Player
var _hits: Array = []
var _failures: int = 0


func _ready() -> void:
	Events.player_hit.connect(func(c: int, s: StringName, _p: Vector2) -> void: _hits.append([c, s]))
	await _test_archer_shoots()
	await _test_statue_blocks_archer()
	await _test_mirror_reflects()
	await _test_eye_shading()
	print("sim_archer_mirror: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


## Archer 5 BL away: no arrow during the draw, one soon after, 1 crack "arrow", and
## the next shot waits for the cooldown.
func _test_archer_shoots() -> void:
	await _fresh_room()
	var archer: Enemy = _spawn("res://scenes/enemies/archer.tscn", Vector2(300, STAND_Y))
	_place_player(Vector2(300 + 5.0 * Balance.BL, STAND_Y), -1)
	await _frames(15)  # 0.25 s: still drawing
	_check("archer is drawing, no arrow yet", _count_arrows() == 0 and archer.state == archer.State.DRAW)
	await _frames(30)  # 0.75 s total
	_check("archer has fired an arrow after the 0.5 s draw", _count_arrows() >= 1 or not _hits.is_empty())
	await _frames(40)
	_check("arrow hit for 1 crack named arrow (%s)" % str(_hits), not _hits.is_empty() and _hits[0] == [Balance.CRACKS_HIT, &"arrow"])
	_check("archer is cooling down", archer.state == archer.State.COOLDOWN)


## A statue between them blocks the archer's view (no draw); an arrow thrown at it sticks.
func _test_statue_blocks_archer() -> void:
	await _fresh_room()
	var hop: Enemy = _spawn("res://scenes/enemies/hoplite.tscn", Vector2(420, STAND_Y))
	hop.set_physics_process(false)
	hop.petrify()
	await _frames(30)
	var archer: Enemy = _spawn("res://scenes/enemies/archer.tscn", Vector2(300, STAND_Y))
	_place_player(Vector2(540, STAND_Y), -1)
	await _frames(40)
	_check("archer will not draw through a statue", archer.state == archer.State.IDLE)
	var arrow: Arrow = load("res://scenes/projectiles/arrow.tscn").instantiate()
	_room.add_child(arrow)
	arrow.global_position = Vector2(340, STAND_Y)
	arrow.launch(Vector2(600, 0))
	await _frames(30)
	_check("arrow stuck into the statue and rides on it", arrow.get_parent() is Statue)
	_check("blocked arrow hurt nobody (%s)" % str(_hits), _hits.is_empty())


## Gaze at a mirror-bearer who faces her: reflect, not petrify. Knocked aside: petrify.
func _test_mirror_reflects() -> void:
	await _fresh_room()
	var bearer: Enemy = _spawn("res://scenes/enemies/mirror_bearer.tscn", Vector2(520, STAND_Y))
	bearer.set_physics_process(false)  # hold still; only the gaze logic is under test
	bearer.set_facing(-1)
	_place_player(Vector2(520 - 2.0 * Balance.BL, STAND_Y), 1)
	RunLedger.start_run()
	Input.action_press("gaze")
	await _frames(45)  # 0.75 s, longer than the 0.4 s hold
	_check("bearer did not petrify behind his mirror", is_instance_valid(bearer) and not bearer._petrified)
	_check("reflect cost 2 cracks named reflect (%s)" % str(_hits), _hits.has([Balance.CRACKS_REFLECT, &"reflect"]))
	_check("reflect logged to RunLedger", RunLedger.events_of("reflect").size() >= 1)
	bearer.knock_mirror(Balance.WHIP_MIRROR_KNOCK)
	await _frames(40)
	Input.action_release("gaze")
	_check("with the mirror knocked aside he petrifies", not is_instance_valid(bearer) or bearer.is_queued_for_deletion() or bearer._petrified)


## Eye-shading soldier: 0.7 s hold and the HandShade pose visible; plain hoplite hides it.
func _test_eye_shading() -> void:
	await _fresh_room()
	var shade: Enemy = _spawn("res://scenes/enemies/eye_shading_hoplite.tscn", Vector2(300, STAND_Y))
	var plain: Enemy = _spawn("res://scenes/enemies/hoplite.tscn", Vector2(100, STAND_Y))
	_check("eye-shading gaze_hold_time is 0.7", is_equal_approx(shade.gaze_hold_time, Balance.GAZE_HOLD_EYE_SHADING))
	# The pose is in the eye-shading sprite sheet; without art, the HandShade polygon shows it.
	var shows_pose: bool = shade.sprite.sprite_frames == load(Balance.SPRITE_ART[&"eye_shading"]["frames"]) 			if shade.sprite != null else shade.get_node("Visual/HandShade").visible
	_check("eye-shading shows the hand-over-eyes pose", shows_pose)
	_check("plain hoplite hides it", not plain.get_node("Visual/HandShade").visible)


# ---------------------------------------------------------------------------

## Arrows currently flying or stuck anywhere in the room.
func _count_arrows() -> int:
	return _room.find_children("*", "Arrow", true, false).size()


## Instance a scene into the room at pos and return its root.
func _spawn(path: String, pos: Vector2) -> Enemy:
	var enemy: Enemy = load(path).instantiate()
	_room.add_child(enemy)
	enemy.global_position = pos
	return enemy


## Throw away the current room and load a fresh graybox with its stock enemies removed.
func _fresh_room() -> void:
	Input.action_release("gaze")
	if is_instance_valid(_room):
		_room.queue_free()
	await _frames(2)
	_room = load("res://scenes/test_room.tscn").instantiate()
	add_child(_room)
	_player = _room.get_node("Player")
	for child in _room.get_children():
		if child is Enemy:
			child.queue_free()
	_hits.clear()
	await _frames(5)
	# Wait out any invulnerability left from the previous test's hit.
	await _frames(int(Balance.PLAYER_INVULN_TIME * Engine.physics_ticks_per_second) + 5)
	_hits.clear()


func _place_player(pos: Vector2, dir: int) -> void:
	_player.global_position = pos
	_player.velocity = Vector2.ZERO
	_player.facing = dir


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(label: String, ok: bool) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1
