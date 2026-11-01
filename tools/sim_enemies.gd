## sim_enemies.gd - dev-only headless check (scene: tools/sim_enemies.tscn).
## Runs the level 1 graybox: hoplite wind-up + thrust hits the player once,
## HURT/invulnerability/ledger, leaper leaps the gap, gaze petrifies a hoplite,
## the gap is too wide for a plain jump but can be crossed on a leaper frozen
## mid-leap, the leaper ignores a player on its own ledge, and falling into the
## pit puts her back on a ledge and restores a wasted leaper (the softlock guard).
extends Node

## Gap between LedgeNear and LedgeFar in scenes/test_room.tscn (px).
const GAP_LEFT: float = 640.0
## LedgeFar starts where a jump at the last coyote-time frame still falls short
## (her center peaks near x=919, so her body's right edge near 939).
const GAP_RIGHT: float = 960.0
## Player center y standing on either ledge.
const LEDGE_STAND_Y: float = 568.0
## Half body heights (px): player 64 tall, leaper 40 tall.
const PLAYER_HALF_H: float = 32.0
const LEAPER_HALF_H: float = 20.0

var _room: Node
var _player: Player
var _hits: Array = []
var _failures: int = 0


func _ready() -> void:
	_room = load("res://scenes/test_room.tscn").instantiate()
	add_child(_room)
	_player = _room.get_node("Player")
	Events.player_hit.connect(func(c, s, p): _hits.append([c, s]))
	await _frames(5)

	# Hoplite: player walks into notice range and gets stabbed.
	var hop: Node = _room.get_node("Hoplite1")
	_player.global_position = Vector2(hop.global_position.x - 150.0, 568)
	await _frames(20)
	_check("hoplite notices and winds up", hop.state in [hop.State.CHASE, hop.State.WINDUP])
	_player.global_position.x = hop.global_position.x - 80.0
	await _frames(5)
	_check("wind-up shows glint", hop.state == hop.State.WINDUP and hop._glint.visible)
	await _frames(30)
	_check("one hoplite hit", _hits.size() == 1 and _hits[0][1] == &"hoplite" and _hits[0][0] == 1)
	_check("player HURT after hit", _player.state == Player.State.HURT)
	_check("hit logged to ledger", RunLedger.events_of("hit").size() == 1)
	await _frames(35)
	_check("hurt ends after 0.5 s", _player.state != Player.State.HURT)

	# Leaper: player at the near edge, leaper leaps the gap.
	var leaper: Node = _room.get_node("Leaper")
	_player.global_position = Vector2(620, 568)
	_player.velocity = Vector2.ZERO
	await _frames(15)
	_check("leaper leaps", leaper.state == leaper.State.LEAP)
	await _frames(70)
	_check("leaper crossed the gap", leaper.global_position.x < 700.0)

	# Gaze: a charging hoplite is frozen before its thrust lands, spear kept in pose.
	var hop2: Node = _room.get_node("Hoplite2")
	# The landed leaper sits where she stood; its contact area would report her
	# for a frame after the teleport below. Its part is done, so remove it.
	leaper.queue_free()
	await _frames(70)  # let the last hit's invulnerability run out
	_player.global_position = Vector2(hop2.global_position.x - 150.0, 568)
	_player.velocity = Vector2.ZERO
	_player.facing = 1
	var hits_before: int = _hits.size()
	Input.action_press("gaze")
	await _frames(45)
	Input.action_release("gaze")
	var statue: Statue = get_tree().get_nodes_in_group(&"statues").back() as Statue
	_check("gaze petrifies a charging hoplite", not is_instance_valid(hop2) and statue != null \
			and statue.enemy_type == &"hoplite" and statue.has_node("Visual/Spear"))
	_check("frozen before the thrust landed (new hits: %s)" % str(_hits.slice(hits_before)), _hits.size() == hits_before)

	await _test_gap_crossing()
	await _test_plain_jump_falls_short()
	await _test_leaper_ignores_same_ledge()
	await _test_pit_reload()

	print("sim_enemies: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


## The intended route: freeze the leaper mid-leap over the gap, hop onto it,
## run across its top and jump to the far ledge. A plain jump cannot clear the gap.
func _test_gap_crossing() -> void:
	await _fresh_room()
	_room.get_node("Hoplite1").queue_free()  # would walk over and stab her while she gazes
	var leaper: Node = _room.get_node("Leaper")
	await _frames(5)
	_place_player(Vector2(620, LEDGE_STAND_Y), 1)
	Input.action_press("gaze")
	for i in 90:
		await _frames(1)
		if not is_instance_valid(leaper):
			break
	Input.action_release("gaze")
	var statues: Array[Node] = get_tree().get_nodes_in_group(&"statues")
	var statue: Statue = statues.back() as Statue if not statues.is_empty() else null
	_check("leaper frozen mid-leap over the gap", statue != null and statue.enemy_type == &"leaper" \
			and statue.position.x > GAP_LEFT and statue.position.x < GAP_RIGHT)
	if statue == null:
		return
	await _frames(10)

	# Hop onto it: run right, jump at once, let go of right when over the statue.
	var stand_y: float = statue.position.y - LEAPER_HALF_H - PLAYER_HALF_H
	Input.action_press("move_right")
	Input.action_press("jump")
	for i in 90:
		await _frames(1)
		if _player.position.x >= statue.position.x - 12.0:
			Input.action_release("move_right")
		if i > 5 and _player.is_on_floor():
			break
	Input.action_release("move_right")
	Input.action_release("jump")
	await _frames(5)
	_check("player lands on the frozen leaper", _player.is_on_floor() and absf(_player.position.y - stand_y) < 3.0)

	# Step back to its left edge, then run across the top and jump for the far ledge.
	Input.action_press("move_left")
	for i in 30:
		await _frames(1)
		if _player.position.x <= statue.position.x - 6.0:
			break
	Input.action_release("move_left")
	await _frames(10)
	Input.action_press("move_right")
	var jumped: bool = false
	var land_x: float = -1.0
	for i in 120:
		await _frames(1)
		if not jumped and _player.position.x >= statue.position.x + 24.0:
			Input.action_press("jump")
			jumped = true
		if jumped and i > 5 and _player.is_on_floor() and _player.position.x > GAP_RIGHT - 20.0:
			land_x = _player.position.x
			break
		if _player.position.y > LEDGE_STAND_Y + Balance.BL:
			break  # fell into the gap
	Input.action_release("move_right")
	Input.action_release("jump")
	_check("jump from the statue reaches the far ledge (landed x=%.0f, ledge starts %.0f)" % [land_x, GAP_RIGHT],
			land_x > 0.0 and absf(_player.position.y - LEDGE_STAND_Y) < 3.0)


## Spec: "a gap too wide to jump". Tries a full-speed jump from the edge and then
## from every later physics frame after leaving it, through the end of coyote
## time (the farthest a plain jump can reach); none may land on the far ledge.
func _test_plain_jump_falls_short() -> void:
	var coyote_frames: int = ceili(Balance.PLAYER_COYOTE_TIME * Engine.physics_ticks_per_second) + 1
	var jumps: int = 0
	var cleared: int = 0
	var best_x: float = 0.0
	for late in range(-1, coyote_frames + 1):
		var result: Dictionary = await _plain_jump(late)
		if result["jumped"]:
			jumps += 1
			best_x = maxf(best_x, result["peak_x"])
		if result["reached"]:
			cleared += 1
	_check("no plain or coyote-time jump clears the gap (%d jumps, farthest x=%.0f, ledge %.0f)" \
			% [jumps, best_x, GAP_RIGHT], jumps > 1 and cleared == 0)


## Run at the gap at full speed and press jump `late` physics frames after the
## feet leave the ledge (-1 = one frame before). Reports whether a jump happened,
## the farthest x reached at ledge height and whether she landed on the far side.
func _plain_jump(late: int) -> Dictionary:
	await _fresh_room()
	for child in _room.get_children():
		if child is Enemy:
			child.queue_free()
	await _frames(2)
	_place_player(Vector2(400, LEDGE_STAND_Y), 1)
	Input.action_press("move_right")
	var off_frames: int = -1  # frames since the feet left the ledge
	var pressed: bool = false
	var jumped: bool = false
	var reached: bool = false
	var peak_x: float = 0.0
	for i in 150:
		await _frames(1)
		var x: float = _player.position.x
		if late < 0 and not pressed and x >= GAP_LEFT - 21.0:
			Input.action_press("jump")
			pressed = true
		if off_frames < 0 and x > GAP_LEFT - 40.0 and not _player.is_on_floor():
			off_frames = 0
		elif off_frames >= 0:
			off_frames += 1
		if not pressed and off_frames == late:
			Input.action_press("jump")
			pressed = true
		jumped = jumped or (pressed and _player.velocity.y < 0.0)
		if _player.position.y <= LEDGE_STAND_Y:
			peak_x = maxf(peak_x, x)
		if i > 5 and _player.is_on_floor() and x > GAP_RIGHT - 20.0:
			reached = true
			break
		if _player.position.y > LEDGE_STAND_Y + Balance.BL:
			break
	Input.action_release("move_right")
	Input.action_release("jump")
	return {"jumped": jumped, "reached": reached, "peak_x": peak_x}


## Spec: the leaper leaps only when the player is across the gap.
func _test_leaper_ignores_same_ledge() -> void:
	await _fresh_room()
	var leaper: Node = _room.get_node("Leaper")
	_place_player(Vector2(leaper.global_position.x + 3.0 * Balance.BL, LEDGE_STAND_Y), -1)
	await _frames(40)
	_check("leaper ignores a player on its own ledge", leaper.state == leaper.State.WAIT)


## Softlock guard: a pit fall puts her back on a ledge, and a wasted leaper comes
## back at its spawn point so the gap can still be crossed.
func _test_pit_reload() -> void:
	await _fresh_room()
	var leaper_home: Vector2 = _room.get_node("Leaper").position
	_room.get_node("Leaper").queue_free()  # "wasted"
	var pits_before: int = RunLedger.events_of("pit").size()
	await _frames(2)
	_place_player(Vector2(800, 900), 1)
	await _frames(8)
	_check("pit fall is logged to the ledger", RunLedger.events_of("pit").size() == pits_before + 1)
	_check("pit fall puts her back on a ledge", _player.position.y < Balance.PLAYER_PIT_Y \
			and _player.position.y < LEDGE_STAND_Y + Balance.BL)
	_check("the room has its leaper back home", _room.has_node("Leaper") \
			and _room.get_node("Leaper").position.distance_to(leaper_home) < 1.0)


## Throw away the current room and load a fresh copy of the graybox.
func _fresh_room() -> void:
	if is_instance_valid(_room):
		_room.queue_free()
	await _frames(2)
	_room = load("res://scenes/test_room.tscn").instantiate()
	add_child(_room)
	_player = _room.get_node("Player")
	await _frames(5)


func _place_player(pos: Vector2, face: int) -> void:
	_player.global_position = pos
	_player.velocity = Vector2.ZERO
	_player.facing = face


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(label: String, ok: bool) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1
