## story_reel.gd (built in code by flow_card.gd on the title card; not a scene)
## Purpose: the wordless 20-second story told in panels, played after the player first
## presses a key on the title card. Each panel fades up from black, drifts slowly (a
## "Ken Burns" push-in or pan) and fades back to black:
##   1 the empty temple at noon      2 the gorgon's golden eye (her snakes hiss)
##   3 the heroes charge the steps   4 her gaze turns a soldier to stone
##   5 the price: the portrait ages through all five stages, crackling at each step.
## Panel 5 teaches the core rule without words: every petrification ages her portrait.
## Skipping works like a media player: the first key, button, click or touch shows a
## round "skip forward" button (two triangles and a bar) in the bottom right corner; a
## click or tap on it, or jump / whip / gaze while it shows, skips the reel. It hides
## again after a few seconds with no input. When the reel ends (or is skipped) it emits
## `finished`, and the title card moves on to level 1 (GameFlow's reels: the next level).
class_name StoryReel
extends CanvasLayer

## Emitted once when the reel ends or is skipped.
signal finished

## Set these BEFORE add_child (GameFlow does, for the reels between levels):
## the beats to show (Balance.STORY_PANELS format), and whether the portrait-aging beat
## follows them (only the title-card story has it).
var panels: Array = Balance.STORY_PANELS
var show_portrait: bool = true

## The panel being shown (a TextureRect that is moved and scaled by tweens).
var _panel: TextureRect = null
var _age: float = 0.0
var _done: bool = false
## The running sequence (kept so a skip can stop it).
var _sequence: Tween = null
## The skip button, hidden until the player gives any input.
var _skip: Button = null
## Seconds since the last input (the skip button hides after STORY_SKIP_HIDE_S).
var _idle: float = 0.0


## Builds a black backdrop and the panel, then chains every beat into one Tween:
## each tween_callback runs a function at its moment, tween_interval waits.
func _ready() -> void:
	layer = Balance.HUD_LAYER + 5  # above everything on the title card
	process_mode = Node.PROCESS_MODE_ALWAYS
	var black := ColorRect.new()
	black.color = Balance.COLOR_BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)  # the anchors size it to the screen
	add_child(black)
	_panel = TextureRect.new()
	_panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_panel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Anchored to the whole screen (not a fixed size), so it always fills the view.
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	_build_skip()
	_sequence = create_tween()
	for beat: Dictionary in panels:
		if not ResourceLoader.exists(beat["path"]):
			continue  # a missing panel is skipped, not shown as a black gap
		_sequence.tween_callback(_show.bind(beat))
		_sequence.tween_interval(float(beat["seconds"]))
	if show_portrait:
		_sequence.tween_callback(_portrait_aging)
		_sequence.tween_interval(Balance.STORY_PORTRAIT_STEP_S * Balance.PORTRAIT_STAGE_COUNT + Balance.STORY_FADE_S)
	_sequence.tween_callback(_finish)


## True if at least one of `beats` has its picture on disk (static: callable as
## StoryReel.has_any(...) without making a reel first).
static func has_any(beats: Array) -> bool:
	for beat: Dictionary in beats:
		if ResourceLoader.exists(beat["path"]):
			return true
	return false


## One panel: set its picture, fade it up, drift from `from` to `to` (scale, offset in
## px), fade it down at the end. The drift runs the whole time the panel is up.
func _show(beat: Dictionary) -> void:
	if not ResourceLoader.exists(beat["path"]):
		return
	_panel.texture = load(beat["path"])
	_panel.pivot_offset = _panel.size * 0.5  # zoom around the middle of the screen
	var seconds: float = beat["seconds"]
	_panel.modulate.a = 0.0
	_panel.scale = Vector2.ONE * float(beat["zoom_from"])
	_panel.position = beat["pan_from"]
	var drift := create_tween().set_parallel(true)
	drift.tween_property(_panel, "scale", Vector2.ONE * float(beat["zoom_to"]), seconds)
	drift.tween_property(_panel, "position", beat["pan_to"], seconds)
	var fade := create_tween()
	fade.tween_property(_panel, "modulate:a", 1.0, Balance.STORY_FADE_S)
	fade.tween_interval(maxf(seconds - Balance.STORY_FADE_S * 2.0, 0.0))
	fade.tween_property(_panel, "modulate:a", 0.0, Balance.STORY_FADE_S)
	if beat.has("sound"):
		Fx.play(StringName(beat["sound"]))


## The last beat: the portrait, centred, aging stage by stage with a crack each time.
func _portrait_aging() -> void:
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2.ONE * 0.6
	_panel.position = Vector2.ZERO
	var fade := create_tween()
	for stage in range(1, Balance.PORTRAIT_STAGE_COUNT + 1):
		fade.tween_callback(func() -> void:
			# The sharp 512 px portrait if it is there, else the small HUD one.
			for path: String in [Balance.PORTRAIT_TEXTURES_HD[stage - 1], Balance.PORTRAIT_TEXTURES[stage - 1]]:
				if ResourceLoader.exists(path):
					_panel.texture = load(path)
					break
			_panel.modulate.a = 1.0
			if stage > 1:
				Fx.play(&"crack_portrait", 1.0 - stage * 0.06))
		fade.tween_interval(Balance.STORY_PORTRAIT_STEP_S)
	fade.tween_property(_panel, "modulate:a", 0.0, Balance.STORY_FADE_S)


## The round skip button: same look as the pause menu's buttons (dark disc, marble
## ring, gold ring on hover), drawn icon, no text. Starts hidden and see-through.
func _build_skip() -> void:
	var size: float = Balance.STORY_SKIP_SIZE
	_skip = Button.new()
	_skip.custom_minimum_size = Vector2(size, size)
	_skip.size = Vector2(size, size)
	var screen: Vector2 = get_viewport().get_visible_rect().size
	_skip.position = screen - Vector2(size, size) - Vector2.ONE * Balance.STORY_SKIP_MARGIN
	_skip.focus_mode = Control.FOCUS_NONE  # keys are handled in _input below
	for style_name: String in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(Balance.COLOR_BLACK, 0.85)
		box.set_corner_radius_all(int(size * 0.5))
		box.set_border_width_all(3)
		box.border_color = Balance.COLOR_GOLD if style_name in ["hover", "pressed"] else Balance.COLOR_MARBLE
		_skip.add_theme_stylebox_override(style_name, box)
	_skip.draw.connect(_draw_skip_icon)
	_skip.pressed.connect(_finish)
	_skip.visible = false
	_skip.modulate.a = 0.0
	add_child(_skip)


## "Skip forward": two triangles pointing right and a bar, in marble.
func _draw_skip_icon() -> void:
	var s: float = _skip.size.x
	var c := Vector2(s, s) * 0.5
	var h: float = s * 0.18
	var w: float = s * 0.16
	for x: float in [-w * 1.15, -w * 0.15]:
		var left: Vector2 = c + Vector2(x, 0.0)
		_skip.draw_colored_polygon(PackedVector2Array([
			left + Vector2(0.0, -h), left + Vector2(w, 0.0), left + Vector2(0.0, h)]), Balance.COLOR_MARBLE)
	_skip.draw_rect(Rect2(c + Vector2(w * 0.95, -h), Vector2(s * 0.05, h * 2.0)), Balance.COLOR_MARBLE)


## Counts how long the reel has played, and hides the skip button after a quiet spell.
func _process(delta: float) -> void:
	_age += delta
	if _skip != null and _skip.visible:
		_idle += delta
		if _idle > Balance.STORY_SKIP_HIDE_S:
			_skip.visible = false
			_skip.modulate.a = 0.0


## Any press shows the skip button. While it shows, jump / whip / gaze also skip (for
## keyboards and pads); a click or tap on the button skips through its `pressed` signal.
func _input(event: InputEvent) -> void:
	if _done or not event.is_pressed() or event.is_echo():
		return
	if not (event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventJoypadButton):
		return
	_idle = 0.0
	if _skip.visible:
		if event.is_action_pressed(&"jump") or event.is_action_pressed(&"whip") or event.is_action_pressed(&"gaze"):
			get_viewport().set_input_as_handled()
			_finish()
		return  # a click or tap goes on to the button itself
	_skip.visible = true
	create_tween().tween_property(_skip, "modulate:a", 1.0, Balance.STORY_SKIP_FADE_S)
	get_viewport().set_input_as_handled()  # the reveal press does nothing else


## End once: stop the sequence and tell the title card (the `finished` signal).
func _finish() -> void:
	if _done:
		return
	_done = true
	if _sequence != null:
		_sequence.kill()
	finished.emit()
