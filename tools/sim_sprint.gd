## sim_sprint.gd - dev-only headless check (scene: tools/sim_sprint.tscn).
## Sprint (hold Shift): the Shift key is bound to the "run" action; holding it raises top
## speed to PLAYER_SPRINT_MULT x the walk speed; the speed carries through a jump so a
## sprint jump travels farther; Shift pressed or released in mid-air does not change the
## arc; and a sprint jump clears the level 1 gap that a walking jump does not.
extends Node

## Where the level 1 gap sits (see scenes/test_room.tscn) and the height she stands at.
const GAP_LEFT: float = 672.0
const GAP_RIGHT: float = 960.0
const STAND_Y: float = 568.0

## The graybox room under test and its player (rebuilt by _fresh_room for each test).
var _room: Node
var _player: Player
## How many checks have failed; also the exit code (0 = all passed).
var _failures: int = 0


## Godot calls _ready() once when the sim scene starts. "await" pauses a function until
## the thing after it finishes (here each test, which itself waits for physics frames),
## so the tests run one after another like a story.
func _ready() -> void:
	_test_shift_key_maps_to_run()
	await _test_top_speeds()
	await _test_jump_distance()
	await _test_air_latch()
	await _test_gap_crossing()
	print("sim_sprint: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


## The Shift key must be bound to the "run" action. InputMap.event_is_action asks the
## project's input map directly "does this key event belong to this action?", which works
## in headless mode (Input.parse_input_event does not update action state there).
## A browser reports Shift with shift_pressed = true; both forms must match.
func _test_shift_key_maps_to_run() -> void:
	for shift_flag in [true, false]:
		var key := InputEventKey.new()
		key.physical_keycode = KEY_SHIFT
		key.keycode = KEY_SHIFT
		key.shift_pressed = shift_flag
		key.pressed = true
		_check("a Shift key press (shift_pressed=%s) belongs to the run action" % str(shift_flag),
				InputMap.event_is_action(key, &"run"))
	var other := InputEventKey.new()
	other.physical_keycode = KEY_D
	other.pressed = true
	_check("other keys do not trigger run", not InputMap.event_is_action(other, &"run"))
	_check("Shift does not trigger walking", not InputMap.event_is_action(
			_shift_event(), &"move_right") and not InputMap.event_is_action(_shift_event(), &"jump"))


## A Shift key-down event, as a browser would send it.
func _shift_event() -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SHIFT
	key.keycode = KEY_SHIFT
	key.shift_pressed = true
	key.pressed = true
	return key


## Walking tops out at PLAYER_RUN_SPEED; with Shift held at PLAYER_RUN_SPEED x PLAYER_SPRINT_MULT.
func _test_top_speeds() -> void:
	await _fresh_room()
	_place(Vector2(1000.0, STAND_Y))
	Input.action_press("move_right")
	await _frames(45)
	var walk_speed: float = _player.velocity.x
	Input.action_press("run")
	await _frames(45)
	var sprint_speed: float = _player.velocity.x
	Input.action_release("run")
	Input.action_release("move_right")
	_check("walking top speed is %.0f (got %.0f)" % [Balance.PLAYER_RUN_SPEED, walk_speed],
			is_equal_approx(walk_speed, Balance.PLAYER_RUN_SPEED))
	_check("sprinting top speed is %.0f (got %.0f)" % [Balance.PLAYER_RUN_SPEED * Balance.PLAYER_SPRINT_MULT, sprint_speed],
			is_equal_approx(sprint_speed, Balance.PLAYER_RUN_SPEED * Balance.PLAYER_SPRINT_MULT))


## Jump at full speed on the long far ledge, with and without Shift, and measure how far
## she travels (take-off x to landing x).
func _test_jump_distance() -> void:
	var walk: float = await _flat_jump_distance(false)
	var sprint: float = await _flat_jump_distance(true)
	_check("a sprint jump travels farther: walk %.0f px, sprint %.0f px" % [walk, sprint], sprint > walk * 1.35)


## Shift is read on the ground only. Letting go in the air keeps the sprint speed;
## pressing it in the air does not add any.
func _test_air_latch() -> void:
	await _fresh_room()
	_place(Vector2(1000.0, STAND_Y))
	Input.action_press("move_right")
	Input.action_press("run")
	await _frames(45)
	Input.action_press("jump")
	await _frames(6)
	Input.action_release("jump")
	Input.action_release("run")
	await _frames(6)
	var kept: float = _player.velocity.x
	_check("letting go of Shift in mid-air keeps the sprint speed (%.0f)" % kept,
			not _player.is_on_floor() and is_equal_approx(kept, Balance.PLAYER_RUN_SPEED * Balance.PLAYER_SPRINT_MULT))
	Input.action_release("move_right")

	await _fresh_room()
	_place(Vector2(1000.0, STAND_Y))
	Input.action_press("move_right")
	await _frames(45)
	Input.action_press("jump")
	await _frames(6)
	Input.action_release("jump")
	Input.action_press("run")
	await _frames(6)
	var unchanged: float = _player.velocity.x
	Input.action_release("run")
	Input.action_release("move_right")
	_check("pressing Shift in mid-air adds no speed (%.0f)" % unchanged,
			not _player.is_on_floor() and is_equal_approx(unchanged, Balance.PLAYER_RUN_SPEED))


## At the default 4.5 BL gap a walking jump pressed at the edge falls short, a sprint
## jump pressed at the same spot lands on the far ledge.
func _test_gap_crossing() -> void:
	var walked: bool = await _gap_jump(false)
	var sprinted: bool = await _gap_jump(true)
	_check("a walking jump from the edge does not clear the default gap", not walked)
	_check("a sprint jump from the edge clears the default gap", sprinted)


## Run along the far ledge, jump once at full speed, return how far she flew.
func _flat_jump_distance(sprint: bool) -> float:
	await _fresh_room()
	_place(Vector2(1000.0, STAND_Y))
	Input.action_press("move_right")
	if sprint:
		Input.action_press("run")
	await _frames(45)
	var takeoff_x: float = _player.position.x
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("jump")
	for i in 120:
		await _frames(1)
		if _player.is_on_floor():
			break
	var landing_x: float = _player.position.x
	Input.action_release("run")
	Input.action_release("move_right")
	return landing_x - takeoff_x


## Run at the gap from the near ledge and jump as her centre reaches the edge. True if she
## ends up standing on the far ledge.
func _gap_jump(sprint: bool) -> bool:
	await _fresh_room()
	_place(Vector2(400.0, STAND_Y))
	Input.action_press("move_right")
	if sprint:
		Input.action_press("run")
	var pressed: bool = false
	var landed: bool = false
	for i in 200:
		await _frames(1)
		if not pressed and _player.position.x >= GAP_LEFT - 8.0:
			Input.action_press("jump")
			pressed = true
		if pressed and i > 5 and _player.is_on_floor() and _player.position.x > GAP_RIGHT - 20.0:
			landed = true
			break
		if _player.position.y > STAND_Y + Balance.BL:
			break  # fell into the gap
	Input.action_release("jump")
	Input.action_release("run")
	Input.action_release("move_right")
	return landed


## A fresh copy of the graybox with every enemy removed (they would walk over and stab her).
func _fresh_room() -> void:
	if is_instance_valid(_room):
		_room.queue_free()
	await _frames(2)
	_room = load("res://scenes/test_room.tscn").instantiate()
	add_child(_room)
	_player = _room.get_node("Player")
	for child in _room.get_children():
		if child is Enemy:
			child.queue_free()
	await _frames(3)


## Put Medusa at a spot, standing still and facing right (a clean start for a test).
func _place(pos: Vector2) -> void:
	_player.global_position = pos
	_player.velocity = Vector2.ZERO
	_player.facing = 1


## Wait n physics frames. "await get_tree().physics_frame" resumes this function the next
## time the engine runs a physics step (60 per second), which is when Medusa moves.
func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Print PASS or FAIL for one check and count failures (any FAIL gives a non-zero exit code).
func _check(label: String, ok: bool) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1
