## story_reel.gd (built in code by flow_card.gd on the title card; not a scene)
## Purpose: the wordless 20-second story told in panels, played after the player first
## presses a key on the title card. Each panel fades up from black, drifts slowly (a
## "Ken Burns" push-in or pan) and fades back to black:
##   1 the empty temple at noon      2 the gorgon's golden eye (her snakes hiss)
##   3 the heroes charge the steps   4 her gaze turns a soldier to stone
##   5 the price: the portrait ages through all five stages, crackling at each step.
## Panel 5 teaches the core rule without words: every petrification ages her portrait.
## Jump, whip or gaze skips it after STORY_SKIP_AFTER seconds. When it ends (or is
## skipped) it emits `finished`, and the title card moves on to level 1.
class_name StoryReel
extends CanvasLayer

## Emitted once when the reel ends or is skipped.
signal finished

## The panel being shown (a TextureRect that is moved and scaled by tweens).
var _panel: TextureRect = null
var _age: float = 0.0
var _done: bool = false
## The running sequence (kept so a skip can stop it).
var _sequence: Tween = null


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
	_sequence = create_tween()
	for beat: Dictionary in Balance.STORY_PANELS:
		_sequence.tween_callback(_show.bind(beat))
		_sequence.tween_interval(float(beat["seconds"]))
	_sequence.tween_callback(_portrait_aging)
	_sequence.tween_interval(Balance.STORY_PORTRAIT_STEP_S * Balance.PORTRAIT_STAGE_COUNT + Balance.STORY_FADE_S)
	_sequence.tween_callback(_finish)


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
			if ResourceLoader.exists(Balance.PORTRAIT_TEXTURES[stage - 1]):
				_panel.texture = load(Balance.PORTRAIT_TEXTURES[stage - 1])
			_panel.modulate.a = 1.0
			if stage > 1:
				Fx.play(&"crack_portrait", 1.0 - stage * 0.06))
		fade.tween_interval(Balance.STORY_PORTRAIT_STEP_S)
	fade.tween_property(_panel, "modulate:a", 0.0, Balance.STORY_FADE_S)


## Counts how long the reel has played (for the skip delay).
func _process(delta: float) -> void:
	_age += delta


## Jump, whip or gaze skips the reel once it has played for STORY_SKIP_AFTER seconds.
func _input(event: InputEvent) -> void:
	if _done or _age < Balance.STORY_SKIP_AFTER:
		return
	if event.is_action_pressed(&"jump") or event.is_action_pressed(&"whip") or event.is_action_pressed(&"gaze"):
		get_viewport().set_input_as_handled()
		_finish()


## End once: stop the sequence and tell the title card (the `finished` signal).
func _finish() -> void:
	if _done:
		return
	_done = true
	if _sequence != null:
		_sequence.kill()
	finished.emit()
