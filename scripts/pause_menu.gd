## pause_menu.gd (built in code by GameFlow; not a scene)
## Purpose: the wordless pause menu. Esc or P, or the small two-bar button in the top
## right corner (for mouse and touch), pauses a level and shows:
##   - three round buttons: resume (play triangle), restart this level (circular arrow;
##     the portrait keeps its cracks, so it is no free heal), music on/off (a note);
##   - below them, the controls legend: each action's icon over its key-caps (KeyHint).
## Everything is drawn with shapes and icons, no words or numbers (CLAUDE.md HARD RULE).
## The buttons are real Godot Buttons, so mouse, touch, arrow keys + Enter all work.
## It only opens inside the four levels (GameFlow index 1 to 4), never on cards.
class_name PauseMenu
extends CanvasLayer

## What each round button draws (see _draw_icon).
enum Icon { RESUME, RESTART, MUSIC }

## Everything shown while paused (hidden otherwise).
var _panel: Control = null
## The small always-visible pause button (top right).
var _corner: Button = null
## The round buttons, kept so focus can start on "resume".
var _buttons: Array[Button] = []
## Name of the audio bus the Music autoload plays on (muted by the music button).
const MUSIC_BUS: StringName = &"Music"


## _ready: build the corner button and the (hidden) menu. process_mode ALWAYS keeps
## this layer working while the rest of the game is paused by get_tree().paused.
func _ready() -> void:
	layer = Balance.HUD_LAYER + 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_corner = _round_button(Balance.PAUSE_CORNER_SIZE, _draw_bars)
	_corner.position = Vector2(get_viewport().get_visible_rect().size.x - Balance.PAUSE_CORNER_SIZE - Balance.PAUSE_CORNER_MARGIN, Balance.PAUSE_CORNER_MARGIN)
	_corner.focus_mode = Control.FOCUS_NONE  # clicking it must not steal the keyboard
	_corner.pressed.connect(toggle)
	add_child(_corner)
	_build_panel()
	_panel.visible = false
	_refresh_corner()
	Events.level_started.connect(func(_i: int) -> void: _refresh_corner())


## The dim backdrop, the three round buttons and the controls legend.
func _build_panel() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	var dim := ColorRect.new()
	dim.color = Color(Balance.COLOR_BLACK, Balance.PAUSE_DIM)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(dim)
	var size: float = Balance.PAUSE_BUTTON_SIZE
	var gap: float = size * 0.5
	var icons: Array[Icon] = [Icon.RESUME, Icon.RESTART, Icon.MUSIC]
	var left: float = screen.x * 0.5 - (icons.size() * size + (icons.size() - 1) * gap) * 0.5
	for i in icons.size():
		var b := _round_button(size, _draw_icon.bind(icons[i]))
		b.position = Vector2(left + i * (size + gap), screen.y * Balance.PAUSE_BUTTONS_Y)
		b.pressed.connect(_on_button.bind(icons[i]))
		_panel.add_child(b)
		_buttons.append(b)
	# Focus neighbours: left/right arrows (ui_left / ui_right) move between buttons.
	for i in _buttons.size():
		_buttons[i].focus_neighbor_left = _buttons[(i - 1 + _buttons.size()) % _buttons.size()].get_path()
		_buttons[i].focus_neighbor_right = _buttons[(i + 1) % _buttons.size()].get_path()
	_build_legend(screen)


## The controls legend: one KeyHint (icon over key-caps) per action, in a row. Its
## `actions` list is left empty so the hints never fade out here.
func _build_legend(screen: Vector2) -> void:
	var rows: Array = [
		["left", ["A"]], ["right", ["D"]], ["jump", ["space"]],
		["whip", ["J"]], ["gaze", ["K"]], ["down", ["S"]],
	]
	var step: float = screen.x * Balance.PAUSE_LEGEND_STEP
	var x: float = screen.x * 0.5 - step * (rows.size() - 1) * 0.5
	for row: Array in rows:
		var hint: KeyHint = load("res://scenes/ui/key_hint.tscn").instantiate()
		hint.icon_name = row[0]
		hint.keys.assign(row[1])
		hint.position = Vector2(x, screen.y * Balance.PAUSE_LEGEND_Y)
		hint.scale = Vector2.ONE * Balance.PAUSE_LEGEND_SCALE
		_panel.add_child(hint)
		x += step


## A flat round Button of `size` px whose picture is drawn by `painter` (a Callable
## hooked to the button's `draw` signal). Styles: dark disc, gold ring on hover/focus.
func _round_button(size: float, painter: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.size = Vector2(size, size)
	for style_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(Balance.COLOR_BLACK, 0.85)
		box.set_corner_radius_all(int(size * 0.5))
		box.set_border_width_all(3)
		box.border_color = Balance.COLOR_GOLD if style_name in ["hover", "focus", "pressed"] else Balance.COLOR_MARBLE
		if style_name == "focus":
			box.draw_center = false  # focus is drawn on top of normal/hover: ring only
		b.add_theme_stylebox_override(style_name, box)
	b.draw.connect(func() -> void: painter.call(b))
	return b


## Esc or P toggles the menu (Esc is Godot's built-in "ui_cancel" action).
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	var pause_key: bool = key != null and key.pressed and not key.echo and key.physical_keycode == KEY_P
	if event.is_action_pressed(&"ui_cancel") or pause_key:
		toggle()
		get_viewport().set_input_as_handled()


## Open or close. Opening is only allowed inside a level and not mid-transition.
func toggle() -> void:
	if _panel.visible:
		_close()
	elif _can_open():
		_panel.visible = true
		get_tree().paused = true
		_buttons[0].grab_focus()
		Fx.play(&"shard", 0.7)


## Hide the menu and let the game run again (get_tree().paused = false).
func _close() -> void:
	_panel.visible = false
	get_tree().paused = false


## True inside the four levels while no scene change is running.
func _can_open() -> bool:
	return GameFlow.current_index >= 1 and GameFlow.current_index <= 4 and not GameFlow._changing


## The corner button shows only where the menu can open.
func _refresh_corner() -> void:
	_corner.visible = GameFlow.current_index >= 1 and GameFlow.current_index <= 4


## A round button was pressed.
func _on_button(icon: Icon) -> void:
	match icon:
		Icon.RESUME:
			_close()
		Icon.RESTART:
			_close()
			GameFlow.go_to(GameFlow.current_index)
		Icon.MUSIC:
			var bus: int = AudioServer.get_bus_index(MUSIC_BUS)
			if bus >= 0:
				AudioServer.set_bus_mute(bus, not AudioServer.is_bus_mute(bus))
			_buttons[2].queue_redraw()


# ---------------------------------------------------------------------------
# Icon drawing (in the button's own coordinates; called through its `draw` signal)
# ---------------------------------------------------------------------------

## Two upright bars: the universal pause sign.
func _draw_bars(b: Button) -> void:
	var s: float = b.size.x
	var w: float = s * 0.14
	var h: float = s * 0.44
	for x: float in [s * 0.36, s * 0.64]:
		b.draw_rect(Rect2(x - w * 0.5, (s - h) * 0.5, w, h), Balance.COLOR_MARBLE)


## The picture for each round menu button, in marble.
func _draw_icon(b: Button, icon: Icon) -> void:
	var s: float = b.size.x
	var c := Vector2(s, s) * 0.5
	var col: Color = Balance.COLOR_MARBLE
	match icon:
		Icon.RESUME:
			# A play triangle, nudged right so it looks centred.
			var r: float = s * 0.24
			b.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 0.7, -r), c + Vector2(-r * 0.7, r), c + Vector2(r * 1.1, 0.0)]), col)
		Icon.RESTART:
			# Three quarters of a circle with an arrowhead at its open end.
			var r: float = s * 0.22
			b.draw_arc(c, r, deg_to_rad(-60.0), deg_to_rad(230.0), 32, col, s * 0.07, true)
			var tip: Vector2 = c + Vector2.from_angle(deg_to_rad(-60.0)) * r
			b.draw_colored_polygon(PackedVector2Array([
				tip + Vector2(-s * 0.11, -s * 0.04), tip + Vector2(s * 0.06, -s * 0.1), tip + Vector2(s * 0.04, s * 0.09)]), col)
		Icon.MUSIC:
			# A quaver: round head, stem, flag. Muted: a gold slash across it.
			var head: Vector2 = c + Vector2(-s * 0.08, s * 0.14)
			b.draw_circle(head, s * 0.09, col)
			var top: Vector2 = head + Vector2(s * 0.08, -s * 0.38)
			b.draw_line(head + Vector2(s * 0.08, 0.0), top, col, s * 0.05)
			b.draw_line(top, top + Vector2(s * 0.14, s * 0.12), col, s * 0.05)
			var bus: int = AudioServer.get_bus_index(MUSIC_BUS)
			if bus >= 0 and AudioServer.is_bus_mute(bus):
				b.draw_line(c + Vector2(-s * 0.26, -s * 0.26), c + Vector2(s * 0.26, s * 0.26), Balance.COLOR_GOLD, s * 0.07)
