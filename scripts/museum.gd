## museum.gd (root script of scenes/flow/museum.tscn)
## Purpose: the museum ending, after the run vase. Centuries later, every hero this
## run turned to stone stands on a plinth in a quiet gallery, in the pose it was frozen
## in (RunLedger's "petrify" events), with Perseus last and largest. Above them hangs
## the portrait at the stage this run left it. The view drifts slowly along the row;
## any key, button or touch (after MUSEUM_INPUT_DELAY_S) moves on to the ending card.
## A run that petrified no one shows an empty gallery: just the plinths and Perseus.
## Wordless: shapes, sprites and the painting only.
extends Node2D

## Seconds since the gallery appeared (input is ignored for a moment at the start).
var _age: float = 0.0
var _leaving: bool = false


## _ready: build the room, then the statues, then start the slow camera drift.
func _ready() -> void:
	var statues: Array = RunLedger.summary().get("petrified", [])
	statues = statues.slice(0, Balance.MUSEUM_MAX_STATUES)
	var count: int = statues.size() + 1  # + Perseus
	var width: float = maxf(Balance.MUSEUM_SPACING * (count + 1), 1280.0)
	_build_room(width)
	var x: float = Balance.MUSEUM_SPACING
	for s: Dictionary in statues:
		_add_statue(StringName(s.get("enemy_type", "hoplite")), int(s.get("pose_frame", 0)), bool(s.get("flip", false)), x, 1.0)
		x += Balance.MUSEUM_SPACING
	_add_statue(&"perseus", 0, true, x, Balance.MUSEUM_PERSEUS_SCALE, &"defeated")
	_add_portrait(width)
	_drift(width)


## Wall, floor and two meander-style bands: plain rectangles in the palette.
func _build_room(width: float) -> void:
	var wall := ColorRect.new()
	wall.color = Balance.MUSEUM_WALL_COLOR
	wall.size = Vector2(width + 1280.0, 720.0)
	wall.position = Vector2(-640.0, 0.0)
	add_child(wall)
	var floor_rect := ColorRect.new()
	floor_rect.color = Balance.COLOR_CLAY_DARK
	floor_rect.size = Vector2(width + 1280.0, 720.0 - Balance.MUSEUM_FLOOR_Y)
	floor_rect.position = Vector2(-640.0, Balance.MUSEUM_FLOOR_Y)
	add_child(floor_rect)
	for y: float in [Balance.MUSEUM_BAND_Y, Balance.MUSEUM_FLOOR_Y - 10.0]:
		var band := ColorRect.new()
		band.color = Balance.COLOR_BLACK
		band.size = Vector2(width + 1280.0, 6.0)
		band.position = Vector2(-640.0, y)
		add_child(band)


## One statue: a marble plinth, and on it the enemy's sprite frozen in its pose with
## the marble shader (the same material real statues use), scaled up for display.
func _add_statue(type: StringName, pose_frame: int, flip: bool, x: float, size_mult: float, anim: StringName = &"") -> void:
	var plinth := ColorRect.new()
	plinth.color = Balance.COLOR_MARBLE
	plinth.size = Balance.MUSEUM_PLINTH_SIZE * Vector2(size_mult, 1.0)
	plinth.position = Vector2(x - plinth.size.x * 0.5, Balance.MUSEUM_FLOOR_Y - plinth.size.y)
	add_child(plinth)
	var holder := Node2D.new()
	# SpriteKit.attach puts the feet at +feet_y below the holder, so lift it by that.
	var info: Dictionary = Balance.SPRITE_ART.get(type, {})
	var feet: float = float(info.get("feet_y", 32.0)) * Balance.MUSEUM_STATUE_SCALE * size_mult
	holder.position = Vector2(x, plinth.position.y - feet)
	holder.scale = Vector2(-1.0 if flip else 1.0, 1.0) * Balance.MUSEUM_STATUE_SCALE * size_mult
	add_child(holder)
	var sprite: AnimatedSprite2D = SpriteKit.attach(holder, type)
	if sprite == null:
		return  # art missing: an empty plinth is still a fine exhibit
	var names: PackedStringArray = sprite.sprite_frames.get_animation_names()
	sprite.animation = anim if anim != &"" and sprite.sprite_frames.has_animation(anim) else StringName(names[0])
	sprite.stop()
	sprite.frame = clampi(pose_frame, 0, sprite.sprite_frames.get_frame_count(sprite.animation) - 1)
	var mat := SpriteKit.marble_material()
	mat.set_shader_parameter(&"recolor", true)
	sprite.material = mat


## The portrait as this run left it, in a gold ring, high on the wall in the middle.
func _add_portrait(width: float) -> void:
	var stage: int = clampi(PortraitState.stage, 1, Balance.PORTRAIT_TEXTURES.size())
	var path: String = Balance.PORTRAIT_TEXTURES[stage - 1]
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	var art := Sprite2D.new()
	art.texture = tex
	art.position = Vector2(width * 0.5, Balance.MUSEUM_PORTRAIT_Y)
	art.scale = Vector2.ONE * (Balance.MUSEUM_PORTRAIT_SIZE / float(tex.get_height()))
	add_child(art)
	var ring := Line2D.new()
	ring.width = 6.0
	ring.default_color = Balance.COLOR_GOLD
	var r: float = Balance.MUSEUM_PORTRAIT_SIZE * 0.52
	for i in 49:
		ring.add_point(art.position + Vector2.from_angle(TAU * i / 48.0) * r)
	add_child(ring)


## A Camera2D that tweens from the left end of the gallery to the right end and back.
func _drift(width: float) -> void:
	var cam := Camera2D.new()
	cam.position = Vector2(640.0, 360.0)
	add_child(cam)
	cam.make_current()
	var end_x: float = maxf(width - 640.0, 640.0)
	if end_x <= 640.0:
		return  # it all fits on one screen
	var tween := create_tween().set_loops()
	tween.tween_property(cam, "position:x", end_x, Balance.MUSEUM_PAN_S).set_trans(Tween.TRANS_SINE)
	tween.tween_property(cam, "position:x", 640.0, Balance.MUSEUM_PAN_S).set_trans(Tween.TRANS_SINE)


## Counts time for the input delay.
func _process(delta: float) -> void:
	_age += delta


## Any key, button or touch after the delay moves on to the ending card (once).
func _unhandled_input(event: InputEvent) -> void:
	if _leaving or _age < Balance.MUSEUM_INPUT_DELAY_S or not event.is_pressed() or event.is_echo():
		return
	_leaving = true
	GameFlow.next_level()
