## key_hint.gd (root script of scenes/ui/key_hint.tscn)
## Purpose: a wordless in-world control hint, placed in a level where an action is first
## needed. It shows an action icon (eye = gaze, snake = whip, ...) above one or more
## key-caps. CLAUDE.md allows key-cap letters (A, D, J, K, S); Space and Shift are
## drawn as blank wide keys (Shift with an up arrow), so no word ever appears.
## On a touch screen only the icon shows (the on-screen buttons carry the same icons).
## The first time the player uses one of its actions, every hint for that action fades
## out for good (for this play session), so a returning player is not nagged.
class_name KeyHint
extends Node2D

## Input actions that count as "used it" (any one of them hides the hint).
@export var actions: Array[StringName] = []
## Key-caps left to right: a single letter ("A", "J"...), "space" or "shift".
@export var keys: Array[String] = []
## Icon above the caps: a key of Balance.KEY_HINT_ICONS ("left", "gaze", ...), or "".
@export var icon_name: String = ""

## Actions already used this session. `static var` is shared by every KeyHint, so a
## hint placed later in the game knows the player has already learned that action.
static var _used: Dictionary = {}

var _icon: Texture2D = null
var _touch: bool = false
var _fading: bool = false


## _ready runs once when the hint enters the level. It removes the hint if its action
## was learned earlier, otherwise picks touch or keyboard mode and loads the icon.
func _ready() -> void:
	for action: StringName in actions:
		if _used.has(action):
			queue_free()  # already learned: never show this hint
			return
	z_index = Balance.KEY_HINT_Z
	_touch = DisplayServer.is_touchscreen_available()
	var path: String = Balance.KEY_HINT_ICONS.get(icon_name, "")
	if path != "" and ResourceLoader.exists(path):
		_icon = load(path)
	queue_redraw()  # ask Godot to call _draw() on the next frame


## Polls the actions each frame. Polling (not _unhandled_input) is deliberate: the
## touch buttons press actions through Input.action_press, which sends no InputEvent.
func _process(_delta: float) -> void:
	if _fading:
		return
	for action: StringName in actions:
		if Input.is_action_just_pressed(action):
			_used[action] = true
	for action: StringName in actions:
		if _used.has(action):
			_fade_out()
			return


## A short fade, then the node removes itself.
func _fade_out() -> void:
	_fading = true
	set_process(false)
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, Balance.KEY_HINT_FADE_S)
	tween.tween_callback(queue_free)


## Draws, centered on the node's position: the icon, then the row of key-caps below it.
## _draw() runs once after queue_redraw(); the drawing stays until the next redraw.
func _draw() -> void:
	var cap_h: float = Balance.KEY_HINT_CAP_SIZE
	var gap: float = Balance.KEY_HINT_GAP
	var widths: Array[float] = []
	var row_w: float = 0.0
	if not _touch:
		for key: String in keys:
			var w: float = Balance.KEY_HINT_WIDE_CAP_W if key.length() > 1 else cap_h
			widths.append(w)
			row_w += w
		row_w += gap * maxf(0.0, keys.size() - 1)
	# Icon on top, scaled to KEY_HINT_ICON_H tall.
	var icon_bottom: float = -cap_h - gap if not _touch and not keys.is_empty() else 0.0
	if _icon != null:
		var scale_factor: float = Balance.KEY_HINT_ICON_H / float(_icon.get_height())
		var size := Vector2(_icon.get_width(), _icon.get_height()) * scale_factor
		draw_texture_rect(_icon, Rect2(Vector2(-size.x * 0.5, icon_bottom - size.y), size), false)
	if _touch:
		return
	# The key-caps.
	var x: float = -row_w * 0.5
	for i in keys.size():
		_draw_cap(Rect2(x, -cap_h, widths[i], cap_h), keys[i])
		x += widths[i] + gap


## One key-cap: dark rounded key, marble border, and its letter or symbol.
func _draw_cap(rect: Rect2, key: String) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Balance.KEY_HINT_CAP_COLOR
	box.border_color = Balance.COLOR_MARBLE
	box.set_border_width_all(Balance.KEY_HINT_BORDER)
	box.set_corner_radius_all(Balance.KEY_HINT_CORNER)
	draw_style_box(box, rect)
	var center: Vector2 = rect.get_center()
	match key:
		"space":
			pass  # a long blank key reads as the space bar on its own
		"shift":
			# Outline up arrow (the shift symbol), built from points around the center.
			var s: float = rect.size.y * 0.3
			var arrow := PackedVector2Array([
					center + Vector2(0, -s), center + Vector2(s, 0), center + Vector2(s * 0.45, 0),
					center + Vector2(s * 0.45, s), center + Vector2(-s * 0.45, s),
					center + Vector2(-s * 0.45, 0), center + Vector2(-s, 0), center + Vector2(0, -s)])
			draw_polyline(arrow, Balance.COLOR_MARBLE, 2.0, true)
		_:
			# A key-cap letter (allowed by the NO TEXT rule). ThemeDB.fallback_font is
			# Godot's built-in font, always present in the export.
			var font: Font = ThemeDB.fallback_font
			var font_size: int = Balance.KEY_HINT_FONT_SIZE
			var text_size: Vector2 = font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var baseline := Vector2(center.x - text_size.x * 0.5,
					center.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5)
			draw_string(font, baseline, key, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Balance.COLOR_MARBLE)
