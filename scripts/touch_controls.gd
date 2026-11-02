## touch_controls.gd (root script of scenes/ui/touch_controls.tscn)
## Purpose: on-screen buttons so the game plays on a phone. Six buttons (walk left,
## walk right, kneel, jump, whip, gaze) press and release the SAME input actions the
## keyboard uses, so Medusa's code never knows the difference. Every finger is tracked
## on its own, so you can hold a direction with one thumb and tap jump or whip with the
## other. Sliding a thumb from one button to the next moves the press with it.
## The buttons only show on touch devices: they appear on the first touch and hide again
## on the first key press. When a touch device is held upright (portrait) the game
## pauses behind a "turn your phone sideways" picture. No words, no numbers: shapes only.
extends CanvasLayer

## One entry per button, in draw order. "action" is the InputMap action it presses.
## Look and place tunables live in Balance (TOUCH_*).
const ACTION_LEFT: StringName = &"move_left"
const ACTION_RIGHT: StringName = &"move_right"
const ACTION_DOWN: StringName = &"move_down"
const ACTION_JUMP: StringName = &"jump"
const ACTION_WHIP: StringName = &"whip"
const ACTION_GAZE: StringName = &"gaze"

## action -> {"pos": Vector2, "radius": float, "node": Node2D, "disc": Polygon2D}
var _buttons: Dictionary = {}
## Finger index -> the action that finger is currently holding down (&"" = none).
## A "finger index" is the number the engine gives each finger on the glass: 0 for the
## first finger down, 1 for the second, and so on. That is what makes multi-touch work.
var _fingers: Dictionary = {}
## Actions this script has pressed and not yet released (so it never releases a key
## the player is holding on a real keyboard).
var _pressed_by_us: Dictionary = {}
## True while the buttons are showing (a touch device, or a touch was seen).
var _touch_active: bool = false
## True while this script has paused the game for the portrait picture.
var _paused_by_me: bool = false
var _rotate_tween: Tween = null

# "@onready" fills these in just before _ready() runs, once the scene's child nodes exist.
# "$Name" is shorthand for "the child node called Name" (see scenes/ui/touch_controls.tscn).
@onready var _buttons_root: Node2D = $Buttons
@onready var _rotate_prompt: Node2D = $RotatePrompt
@onready var _phone: Node2D = $RotatePrompt/Phone


## Godot calls _ready() once, when this node and its children have entered the game.
## Here: build the six buttons and the rotate picture, listen for window resizes, and
## decide whether this device gets the buttons at all.
func _ready() -> void:
	layer = Balance.TOUCH_LAYER
	# Keep listening while the portrait picture has the game paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_button(ACTION_LEFT, Balance.TOUCH_LEFT_POS, Balance.TOUCH_MOVE_RADIUS, Balance.COLOR_MARBLE)
	_build_button(ACTION_RIGHT, Balance.TOUCH_RIGHT_POS, Balance.TOUCH_MOVE_RADIUS, Balance.COLOR_MARBLE)
	_build_button(ACTION_DOWN, Balance.TOUCH_DOWN_POS, Balance.TOUCH_DOWN_RADIUS, Balance.COLOR_MARBLE)
	_build_button(ACTION_JUMP, Balance.TOUCH_JUMP_POS, Balance.TOUCH_ACTION_RADIUS, Balance.COLOR_MARBLE)
	_build_button(ACTION_WHIP, Balance.TOUCH_WHIP_POS, Balance.TOUCH_ACTION_RADIUS, Balance.COLOR_MARBLE)
	# Gaze is the power: its ring is gold, like the gaze cone.
	_build_button(ACTION_GAZE, Balance.TOUCH_GAZE_POS, Balance.TOUCH_ACTION_RADIUS, Balance.COLOR_GOLD)
	_build_rotate_prompt()
	# A signal is the engine telling us "something happened". connect() says "call my
	# function when it does". Here: whenever the window changes size (e.g. the phone turns).
	get_tree().root.size_changed.connect(_on_window_resized)
	set_touch_active(_detect_touch_device())


## Show or hide the buttons. Hiding lets go of everything they were holding down.
func set_touch_active(active: bool) -> void:
	_touch_active = active
	_buttons_root.visible = active
	if not active:
		_fingers.clear()
		_refresh_actions()
	_on_window_resized()


## True while the buttons are showing.
func is_touch_active() -> bool:
	return _touch_active


## True while the "turn your phone sideways" picture is up.
func is_rotate_prompt_showing() -> bool:
	return _rotate_prompt.visible


## The real window size changed. (The sim calls apply_window_size with a made-up size.)
func _on_window_resized() -> void:
	apply_window_size(Vector2i(DisplayServer.window_get_size()))


## Upright (taller than wide) on a touch device: pause behind the rotate picture.
## Sideways again: take the picture down and unpause (only if this script paused it).
func apply_window_size(window_size: Vector2i) -> void:
	var upright: bool = _touch_active and window_size.y > window_size.x
	_rotate_prompt.visible = upright
	if upright:
		_release_all()
		if not get_tree().paused:
			get_tree().paused = true
			_paused_by_me = true
		_start_rotate_hint()
	else:
		if _paused_by_me:
			get_tree().paused = false
			_paused_by_me = false
		_stop_rotate_hint()


## Godot calls _input() for every input event (touch, key, mouse...) before the game
## sees it. "event is InputEventScreenTouch" asks "is this event a finger going down or
## up?"; "as" then treats it as that type so we can read its fields.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not _touch_active:
			set_touch_active(true)
		if touch.pressed:
			_fingers[touch.index] = _button_at(touch.position)
		else:
			_fingers.erase(touch.index)
		_refresh_actions()
	elif event is InputEventScreenDrag:
		# A thumb that slides onto another button takes the press with it.
		var drag := event as InputEventScreenDrag
		if _fingers.has(drag.index):
			_fingers[drag.index] = _button_at(drag.position)
			_refresh_actions()
	elif _touch_active and _is_keyboard_or_pad_press(event):
		# Someone picked up a keyboard or gamepad: get the buttons out of the way.
		set_touch_active(false)


## Letting the browser tab lose focus must not leave Medusa running forever.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release_all()


## Which action's button is under a point, or &"" for none. The nearest centre wins
## when two buttons' forgiving hit areas overlap.
func _button_at(point: Vector2) -> StringName:
	var best: StringName = &""
	var best_distance: float = INF
	for action: StringName in _buttons:
		var button: Dictionary = _buttons[action]
		var distance: float = point.distance_to(button["pos"])
		if distance <= float(button["radius"]) * Balance.TOUCH_HIT_SCALE and distance < best_distance:
			best = action
			best_distance = distance
	return best


## Make the real input actions match what the fingers hold. This is the one place that
## calls Input.action_press / action_release, so two fingers on one button, or a finger
## leaving, can never leave an action stuck "on". Only actions WE pressed are released,
## so a key held on a real keyboard is never cut off by mistake.
func _refresh_actions() -> void:
	# Step 1: which actions are held by at least one finger right now?
	var held: Dictionary = {}
	for finger: int in _fingers:
		held[_fingers[finger]] = true
	# Step 2: press the newly held ones, release the ones no finger holds any more.
	for action: StringName in _buttons:
		var is_down: bool = held.has(action)
		if is_down and not _pressed_by_us.has(action):
			Input.action_press(action)
			_pressed_by_us[action] = true
		elif not is_down and _pressed_by_us.has(action):
			Input.action_release(action)
			_pressed_by_us.erase(action)
		_show_pressed(action, is_down)


## Let go of everything the buttons hold (used when the tab loses focus, the buttons
## hide, or the portrait picture appears).
func _release_all() -> void:
	_fingers.clear()
	_refresh_actions()


## Looks of one button: brighter disc and a small squeeze while a finger is down.
func _show_pressed(action: StringName, is_down: bool) -> void:
	var button: Dictionary = _buttons[action]
	var disc: Polygon2D = button["disc"]
	disc.modulate.a = Balance.TOUCH_PRESSED_DISC_ALPHA if is_down else Balance.TOUCH_IDLE_DISC_ALPHA
	(button["node"] as Node2D).scale = Vector2.ONE * (Balance.TOUCH_PRESSED_SCALE if is_down else 1.0)


## A key or gamepad button went down (not auto-repeat, not stick jitter).
func _is_keyboard_or_pad_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key := event as InputEventKey
		return key.pressed and not key.echo
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).pressed
	return false


## True on a device that reports a touch screen, or when the page address ends in ?touch
## (handy for trying the buttons on a computer).
func _detect_touch_device() -> bool:
	if DisplayServer.is_touchscreen_available():
		return true
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval("new URLSearchParams(window.location.search).has('touch')", true))
	return false


# ---------------------------------------------------------------------------
# Drawing: every button is a dark disc, a ring and an icon made of polygons/lines.
# ---------------------------------------------------------------------------

func _build_button(action: StringName, pos: Vector2, radius: float, ring_color: Color) -> void:
	var root := Node2D.new()
	root.position = pos
	_buttons_root.add_child(root)

	var disc := Polygon2D.new()
	disc.polygon = _circle(radius)
	disc.color = Balance.COLOR_BLACK
	disc.modulate.a = Balance.TOUCH_IDLE_DISC_ALPHA
	root.add_child(disc)

	var ring := Line2D.new()
	ring.points = _circle(radius - Balance.TOUCH_RING_WIDTH * 0.5)
	ring.closed = true
	ring.width = Balance.TOUCH_RING_WIDTH
	ring.default_color = ring_color
	ring.modulate.a = Balance.TOUCH_ICON_ALPHA
	root.add_child(ring)

	var icon := Node2D.new()
	icon.modulate.a = Balance.TOUCH_ICON_ALPHA
	root.add_child(icon)
	_draw_icon(icon, action, radius)

	_buttons[action] = {"pos": pos, "radius": radius, "node": root, "disc": disc}


## The picture on a button, drawn at the button's radius.
func _draw_icon(icon: Node2D, action: StringName, r: float) -> void:
	match action:
		ACTION_LEFT:
			_add_polygon(icon, [Vector2(-0.40, 0.0), Vector2(0.28, -0.42), Vector2(0.28, 0.42)], r, Balance.COLOR_MARBLE)
		ACTION_RIGHT:
			_add_polygon(icon, [Vector2(0.40, 0.0), Vector2(-0.28, -0.42), Vector2(-0.28, 0.42)], r, Balance.COLOR_MARBLE)
		ACTION_DOWN:
			_add_polygon(icon, [Vector2(0.0, 0.40), Vector2(-0.45, -0.28), Vector2(0.45, -0.28)], r, Balance.COLOR_MARBLE)
		ACTION_JUMP:
			# An arrow pointing up.
			_add_polygon(icon, [
				Vector2(0.0, -0.52), Vector2(0.45, -0.02), Vector2(0.17, -0.02), Vector2(0.17, 0.48),
				Vector2(-0.17, 0.48), Vector2(-0.17, -0.02), Vector2(-0.45, -0.02),
			], r, Balance.COLOR_MARBLE)
		ACTION_WHIP:
			# Three snakes fanning out from the bottom left, like the whip's fan.
			var root := Vector2(-0.38, 0.38)
			for tip: Vector2 in [Vector2(0.48, -0.48), Vector2(0.56, -0.06), Vector2(0.24, -0.56)]:
				var snake := Line2D.new()
				snake.points = PackedVector2Array([root * r, (root.lerp(tip, 0.5) + Vector2(0.0, 0.14)) * r, tip * r])
				snake.width = Balance.TOUCH_ICON_STROKE
				snake.default_color = Balance.COLOR_MARBLE
				snake.joint_mode = Line2D.LINE_JOINT_ROUND
				snake.begin_cap_mode = Line2D.LINE_CAP_ROUND
				snake.end_cap_mode = Line2D.LINE_CAP_ROUND
				icon.add_child(snake)
		ACTION_GAZE:
			# An open eye: a lens shape with a dark pupil.
			var lens: Array[Vector2] = []
			for i in range(0, 13):
				var x: float = -0.62 + 1.24 * i / 12.0
				lens.append(Vector2(x, -0.36 * (1.0 - pow(x / 0.62, 2.0))))
			for i in range(12, -1, -1):
				var x: float = -0.62 + 1.24 * i / 12.0
				lens.append(Vector2(x, 0.36 * (1.0 - pow(x / 0.62, 2.0))))
			_add_polygon(icon, lens, r, Balance.COLOR_GOLD)
			var pupil := Polygon2D.new()
			pupil.polygon = _circle(r * 0.2)
			pupil.color = Balance.COLOR_BLACK
			icon.add_child(pupil)


## Add a filled shape to an icon. The points are written for a button of radius 1
## (so -0.4 means "40% of the radius to the left") and scaled up by r here, which is
## how the same icon fits a big button or a small one.
func _add_polygon(parent: Node2D, unit_points: Array, r: float, color: Color) -> void:
	var points := PackedVector2Array()
	for p: Vector2 in unit_points:
		points.append(p * r)
	var polygon := Polygon2D.new()
	polygon.polygon = points
	polygon.color = color
	parent.add_child(polygon)


## Corner points of a round shape around (0, 0): a polygon with many short sides looks
## like a circle. Walks a full turn (TAU = 2 x pi radians) in equal steps.
func _circle(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in Balance.TOUCH_CIRCLE_SEGMENTS:
		points.append(Vector2.from_angle(TAU * i / Balance.TOUCH_CIRCLE_SEGMENTS) * radius)
	return points


## The rotate picture: a black screen with a phone outline and a turning arrow.
## It sits in the 1280 x 720 play area, so it is visible whichever way the phone is held.
func _build_rotate_prompt() -> void:
	var screen_size: Vector2 = Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))
	var cover := Polygon2D.new()
	cover.polygon = PackedVector2Array([Vector2.ZERO, Vector2(screen_size.x, 0.0), screen_size, Vector2(0.0, screen_size.y)])
	cover.color = Balance.COLOR_BLACK
	_rotate_prompt.add_child(cover)
	_rotate_prompt.move_child(cover, 0)

	_phone.position = screen_size * 0.5
	var half: Vector2 = Balance.TOUCH_ROTATE_PHONE_SIZE * 0.5
	var outline := Line2D.new()
	outline.points = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)])
	outline.closed = true
	outline.width = Balance.TOUCH_ROTATE_STROKE
	outline.joint_mode = Line2D.LINE_JOINT_ROUND
	outline.default_color = Balance.COLOR_MARBLE
	_phone.add_child(outline)
	# The phone's "speaker": a short bar near the top, so it reads as a phone.
	var speaker := Line2D.new()
	speaker.points = PackedVector2Array([Vector2(-half.x * 0.3, -half.y * 0.82), Vector2(half.x * 0.3, -half.y * 0.82)])
	speaker.width = Balance.TOUCH_ROTATE_STROKE
	speaker.default_color = Balance.COLOR_GOLD
	_phone.add_child(speaker)
	# A curved arrow above it that says "turn".
	var arrow := Line2D.new()
	var arc := PackedVector2Array()
	var arc_radius: float = half.y + 40.0
	for i in range(0, 11):
		arc.append(Vector2.from_angle(deg_to_rad(-150.0 + 120.0 * i / 10.0)) * arc_radius)
	arrow.points = arc
	arrow.width = Balance.TOUCH_ROTATE_STROKE
	arrow.default_color = Balance.COLOR_TERRACOTTA
	arrow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_phone.add_child(arrow)
	var tip: Vector2 = arc[arc.size() - 1]
	var heading: Vector2 = (arc[arc.size() - 1] - arc[arc.size() - 2]).normalized()
	var side: Vector2 = heading.orthogonal()
	var head := Polygon2D.new()
	head.polygon = PackedVector2Array([tip + heading * 60.0, tip + side * 44.0, tip - side * 44.0])
	head.color = Balance.COLOR_TERRACOTTA
	_phone.add_child(head)
	_rotate_prompt.visible = false


## Tip the phone picture on its side and back, forever, while it is showing.
## The tween keeps running while the game is paused behind it.
func _start_rotate_hint() -> void:
	if _rotate_tween != null and _rotate_tween.is_valid():
		return
	_phone.rotation = 0.0
	_rotate_tween = create_tween().set_loops()
	_rotate_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_rotate_tween.tween_property(_phone, "rotation", -PI * 0.5, Balance.TOUCH_ROTATE_TURN_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_rotate_tween.tween_interval(Balance.TOUCH_ROTATE_TURN_TIME * 0.6)
	_rotate_tween.tween_property(_phone, "rotation", 0.0, Balance.TOUCH_ROTATE_TURN_TIME * 0.5)
	_rotate_tween.tween_interval(Balance.TOUCH_ROTATE_TURN_TIME * 0.4)


## Stop the turning animation (the phone is sideways now, the picture is gone).
func _stop_rotate_hint() -> void:
	if _rotate_tween != null:
		_rotate_tween.kill()
		_rotate_tween = null
