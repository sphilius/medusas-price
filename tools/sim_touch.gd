## sim_touch.gd - dev-only headless check (scene: tools/sim_touch.tscn).
## Fake fingers are fed to the on-screen buttons and the real input actions are checked:
## one finger per button, several fingers at once (multi-touch), sliding from one button
## to the next, touching empty space, releasing, the buttons hiding on a key press, the
## portrait "turn your phone" pause, and finally that the buttons really drive Medusa
## (walk, jump, whip, gaze) in the graybox room. Also confirms no text nodes exist.
## Double-tap sprint is covered too: the timing window is counted in physics steps, so the
## sim waits with _physics(n) (not real seconds) and every run gives the same answer.
## Tip: a name starting with an underscore (like _touch._buttons) is "private" by habit only;
## GDScript lets the sim peek at it, which is how it checks the gold sprint chevron.
extends Node

## The graybox room under test, its touch layer and its player (found in _ready).
var _room: Node
var _touch: CanvasLayer
var _player: Player
## How many checks have failed; also the process exit code (0 = all passed).
var _failures: int = 0


## Godot calls _ready() once the sim scene is running. "await" pauses this function
## until the thing after it happens (here: the next physics frame), then carries on,
## which lets a test read like a story instead of being split across many callbacks.
func _ready() -> void:
	_room = load("res://scenes/test_room.tscn").instantiate()
	add_child(_room)
	_touch = _room.get_node("TouchControls")
	_player = _room.get_node("Player")
	await get_tree().physics_frame
	await _test_buttons_and_multitouch()
	await _test_slide_and_miss()
	await _test_double_tap_sprint()
	await _test_hide_on_key()
	await _test_portrait_pause()
	_test_no_text()
	await _test_drives_medusa()
	await _test_double_tap_drives_medusa()
	print("sim_touch: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


## Send one finger event and let the game process a frame.
## push_input(event, true) hands the event straight to the viewport using game
## coordinates (the "true"), the same path a real touch takes after the engine has
## scaled it to the 1280 x 720 screen. (Input.parse_input_event does not reach nodes
## in headless mode, so it cannot be used here.)
func _finger(index: int, pos: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = pos
	event.pressed = pressed
	get_viewport().push_input(event, true)
	await get_tree().process_frame


## Slide a finger that is already down to a new spot.
func _drag(index: int, pos: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = pos
	get_viewport().push_input(event, true)
	await get_tree().process_frame


## Lift every possible finger (0-4), so one test never leaves a thumb down for the next,
## then wait longer than the double-tap window so an old tap cannot pair with the next test's tap.
func _release_everything() -> void:
	for i in 5:
		await _finger(i, Vector2.ZERO, false)
	await _physics(ceili(Balance.TOUCH_DOUBLE_TAP_WINDOW * Engine.physics_ticks_per_second) + 5)


## Wait n physics steps. The touch layer's double-tap clock counts physics steps, so the
## sim counts them too (one step = 1/60 s).
func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Each button presses its own action; several fingers work at once; lifting one finger
## releases only its button.
func _test_buttons_and_multitouch() -> void:
	_touch.set_touch_active(false)
	await _finger(0, Balance.TOUCH_RIGHT_POS, true)
	_check("a first touch reveals the buttons", _touch.is_touch_active())
	_check("finger on the right button presses move_right", Input.is_action_pressed("move_right"))
	_check("the other buttons stay up", not Input.is_action_pressed("move_left") and not Input.is_action_pressed("jump"))
	await _finger(1, Balance.TOUCH_JUMP_POS, true)
	_check("second finger presses jump while right is still held", Input.is_action_pressed("jump") and Input.is_action_pressed("move_right"))
	await _finger(2, Balance.TOUCH_GAZE_POS, true)
	_check("third finger holds gaze too", Input.is_action_pressed("gaze"))
	await _finger(1, Balance.TOUCH_JUMP_POS, false)
	_check("lifting the jump finger releases only jump", not Input.is_action_pressed("jump") \
			and Input.is_action_pressed("move_right") and Input.is_action_pressed("gaze"))
	await _release_everything()
	_check("lifting every finger releases every action", not Input.is_action_pressed("move_right") \
			and not Input.is_action_pressed("gaze"))
	for pair: Array in [[Balance.TOUCH_LEFT_POS, "move_left"], [Balance.TOUCH_DOWN_POS, "move_down"], [Balance.TOUCH_WHIP_POS, "whip"]]:
		await _finger(0, pair[0], true)
		_check("button for %s presses it" % pair[1], Input.is_action_pressed(pair[1]))
		await _finger(0, pair[0], false)
		_check("and releases it", not Input.is_action_pressed(pair[1]))


## Sliding a thumb moves the press; touching nothing presses nothing; the hit area is
## the button's radius times Balance.TOUCH_HIT_SCALE (checked a hair inside and outside).
func _test_slide_and_miss() -> void:
	await _finger(0, Balance.TOUCH_RIGHT_POS, true)
	await _drag(0, Balance.TOUCH_LEFT_POS)
	_check("sliding the thumb from right to left swaps the press", Input.is_action_pressed("move_left") \
			and not Input.is_action_pressed("move_right"))
	await _drag(0, Vector2(640.0, 100.0))
	_check("sliding off every button releases it", not Input.is_action_pressed("move_left"))
	await _finger(0, Vector2(640.0, 100.0), false)
	await _finger(0, Vector2(640.0, 100.0), true)
	_check("touching empty space presses nothing", not Input.is_action_pressed("move_left") \
			and not Input.is_action_pressed("jump") and not Input.is_action_pressed("whip"))
	await _finger(0, Vector2(640.0, 100.0), false)
	# Just inside the forgiving hit circle counts, just outside it does not.
	var edge: float = Balance.TOUCH_ACTION_RADIUS * Balance.TOUCH_HIT_SCALE
	await _finger(0, Balance.TOUCH_JUMP_POS + Vector2(edge - 2.0, 0.0), true)
	_check("just inside the forgiving ring still presses", Input.is_action_pressed("jump"))
	await _finger(0, Balance.TOUCH_JUMP_POS + Vector2(edge - 2.0, 0.0), false)
	await _finger(0, Balance.TOUCH_JUMP_POS + Vector2(edge + 4.0, 0.0), true)
	_check("just outside it does not", not Input.is_action_pressed("jump"))
	await _release_everything()


## Picking up a keyboard hides the buttons and must not leave an action stuck on.
func _test_hide_on_key() -> void:
	await _finger(0, Balance.TOUCH_RIGHT_POS, true)
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	get_viewport().push_input(key, true)
	await get_tree().process_frame
	_check("a key press hides the buttons", not _touch.is_touch_active())
	_check("and lets go of what they held", not Input.is_action_pressed("move_right"))
	await _release_everything()
	_touch.set_touch_active(true)


## An upright touch device pauses behind the rotate picture; turning it sideways resumes.
## Window sizes are made up here (apply_window_size) because headless has no real window.
func _test_portrait_pause() -> void:
	_touch.apply_window_size(Vector2i(375, 812))
	_check("upright phone shows the rotate picture", _touch.is_rotate_prompt_showing())
	_check("and pauses the game", get_tree().paused)
	_touch.apply_window_size(Vector2i(812, 375))
	_check("sideways phone takes the picture down", not _touch.is_rotate_prompt_showing())
	_check("and unpauses", not get_tree().paused)
	_touch.set_touch_active(false)
	_touch.apply_window_size(Vector2i(375, 812))
	_check("an upright desktop window (no touch) is left alone", not _touch.is_rotate_prompt_showing() and not get_tree().paused)
	_touch.set_touch_active(true)
	_touch.apply_window_size(Vector2i(1280, 720))


## The No Text rule: no Label-like node anywhere under the touch layer.
func _test_no_text() -> void:
	var bad: int = 0
	for node: Node in _touch.find_children("*", "", true, false):
		if node is Label or node is RichTextLabel or node is Button or node is LineEdit:
			bad += 1
	_check("touch layer has no text nodes", bad == 0)


## Double tap = sprint. Tap a direction, lift, press the same direction again inside the
## window and "run" is held with it (like Shift). Too slow, the other direction, or a
## single tap does nothing; lifting or sliding off ends it; the gold chevron follows it.
func _test_double_tap_sprint() -> void:
	await _release_everything()
	await _finger(0, Balance.TOUCH_RIGHT_POS, true)
	_check("one plain press does not sprint", Input.is_action_pressed("move_right") and not Input.is_action_pressed("run"))
	await _finger(0, Balance.TOUCH_RIGHT_POS, false)
	await _physics(5)
	await _finger(0, Balance.TOUCH_RIGHT_POS, true)
	_check("tap, lift, press again quickly: walks and sprints", Input.is_action_pressed("move_right") and Input.is_action_pressed("run"))
	_check("the gold chevron shows while sprinting", _touch._buttons[&"move_right"]["sprint_mark"].visible)
	_check("and not on the other direction", not _touch._buttons[&"move_left"]["sprint_mark"].visible)
	await _finger(0, Balance.TOUCH_RIGHT_POS, false)
	_check("lifting the thumb ends the walk and the sprint", not Input.is_action_pressed("move_right") \
			and not Input.is_action_pressed("run"))
	_check("and hides the chevron", not _touch._buttons[&"move_right"]["sprint_mark"].visible)

	# Too slow: the window has closed.
	await _release_everything()
	await _finger(0, Balance.TOUCH_RIGHT_POS, true)
	await _finger(0, Balance.TOUCH_RIGHT_POS, false)
	await _physics(ceili(Balance.TOUCH_DOUBLE_TAP_WINDOW * Engine.physics_ticks_per_second) + 8)
	await _finger(0, Balance.TOUCH_RIGHT_POS, true)
	_check("a slow second press does not sprint", Input.is_action_pressed("move_right") and not Input.is_action_pressed("run"))
	await _release_everything()

	# Different direction: it takes two taps on the SAME side.
	await _finger(0, Balance.TOUCH_RIGHT_POS, true)
	await _finger(0, Balance.TOUCH_RIGHT_POS, false)
	await _physics(5)
	await _finger(0, Balance.TOUCH_LEFT_POS, true)
	_check("right then left does not sprint", Input.is_action_pressed("move_left") and not Input.is_action_pressed("run"))
	await _release_everything()

	# Works to the left too.
	await _finger(0, Balance.TOUCH_LEFT_POS, true)
	await _finger(0, Balance.TOUCH_LEFT_POS, false)
	await _physics(5)
	await _finger(0, Balance.TOUCH_LEFT_POS, true)
	_check("double tap on the left sprints left", Input.is_action_pressed("move_left") and Input.is_action_pressed("run"))
	# Sliding onto the other direction ends the sprint.
	await _drag(0, Balance.TOUCH_RIGHT_POS)
	_check("sliding to the other direction ends the sprint", Input.is_action_pressed("move_right") \
			and not Input.is_action_pressed("run"))
	await _release_everything()

	# A jump finger tapping twice must not sprint (only direction buttons count).
	await _finger(1, Balance.TOUCH_JUMP_POS, true)
	await _finger(1, Balance.TOUCH_JUMP_POS, false)
	await _physics(5)
	await _finger(1, Balance.TOUCH_JUMP_POS, true)
	_check("double tapping jump does not sprint", not Input.is_action_pressed("run"))
	await _release_everything()


## The sprint reaches Medusa: a double tap takes her to the sprint top speed, a plain hold
## only to the walk speed, and letting go stops the sprint.
func _test_double_tap_drives_medusa() -> void:
	for child in _room.get_children():
		if child is Enemy:
			child.queue_free()   # nobody should stab her while she runs
	await _physics(3)
	_player.global_position = Vector2(150.0, 568.0)
	_player.velocity = Vector2.ZERO
	await _finger(0, Balance.TOUCH_RIGHT_POS, true)
	await _physics(30)
	var walking: float = _player.velocity.x
	await _finger(0, Balance.TOUCH_RIGHT_POS, false)
	await _release_everything()
	_player.global_position = Vector2(150.0, 568.0)
	_player.velocity = Vector2.ZERO
	await _finger(0, Balance.TOUCH_RIGHT_POS, true)
	await _finger(0, Balance.TOUCH_RIGHT_POS, false)
	await _physics(4)
	await _finger(0, Balance.TOUCH_RIGHT_POS, true)
	await _physics(30)
	var sprinting: float = _player.velocity.x
	_check("a plain hold walks at %.0f (got %.0f)" % [Balance.PLAYER_RUN_SPEED, walking],
			is_equal_approx(walking, Balance.PLAYER_RUN_SPEED))
	_check("a double-tap hold sprints at %.0f (got %.0f)" % [Balance.PLAYER_RUN_SPEED * Balance.PLAYER_SPRINT_MULT, sprinting],
			is_equal_approx(sprinting, Balance.PLAYER_RUN_SPEED * Balance.PLAYER_SPRINT_MULT))
	await _release_everything()


## The real proof: buttons move Medusa through the same actions as the keyboard.
func _test_drives_medusa() -> void:
	# The earlier tests wait a while; the hoplites would walk over and stab her mid-test.
	# This test is about buttons moving Medusa, so the enemies are removed and she starts fresh.
	for child in _room.get_children():
		if child is Enemy:
			child.queue_free()
	await _physics(3)
	_player.global_position = Vector2(150.0, 568.0)
	_player.velocity = Vector2.ZERO
	await _player_settled()
	var start_x: float = _player.global_position.x
	await _finger(0, Balance.TOUCH_RIGHT_POS, true)
	for i in 20:
		await get_tree().physics_frame
	await _finger(0, Balance.TOUCH_RIGHT_POS, false)
	_check("holding the right button walks Medusa right", _player.global_position.x > start_x + 40.0 and _player.facing == 1)

	await _player_settled()
	await _finger(1, Balance.TOUCH_JUMP_POS, true)
	for i in 6:
		await get_tree().physics_frame
	_check("jump button lifts her off the floor", _player.velocity.y < 0.0 or not _player.is_on_floor())
	await _finger(1, Balance.TOUCH_JUMP_POS, false)
	await _player_settled()

	await _finger(1, Balance.TOUCH_WHIP_POS, true)
	await _finger(1, Balance.TOUCH_WHIP_POS, false)
	for i in 3:
		await get_tree().physics_frame
	_check("tapping whip starts a lash", _player.state == Player.State.WHIP)
	for i in 40:
		await get_tree().physics_frame
	_check("the lash ends by itself", _player.state != Player.State.WHIP)

	await _finger(2, Balance.TOUCH_GAZE_POS, true)
	for i in 4:
		await get_tree().physics_frame
	_check("holding gaze puts her in the gaze state", _player.state == Player.State.GAZE)
	await _finger(2, Balance.TOUCH_GAZE_POS, false)
	for i in 4:
		await get_tree().physics_frame
	_check("letting go ends the gaze", _player.state != Player.State.GAZE)
	await _release_everything()


## Wait until she stands still on the floor.
func _player_settled() -> void:
	for i in 90:
		await get_tree().physics_frame
		if _player.is_on_floor() and _player.velocity.length() < 1.0:
			return


## Count and print one result. Any FAIL makes the whole sim exit with a non-zero code.
func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("%s  %s" % ["PASS" if ok else "FAIL", label])
