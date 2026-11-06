## whip.gd (root script of scenes/whip.tscn, instanced under the Player)
## Purpose: Medusa's snake-hair whip. Listens to the Player's whip phases: on
## ANTICIPATION it plays the 8-frame lash animation, and the fan-shaped hitbox is
## only enabled during ACTIVE. Each target is hit at most once per lash:
## enemies get stagger + knockback away from her (mirror-bearers also lose their
## mirror, inside Enemy.whip_hit), statues get Statue.whip_hit().
## The art is 3 to 5 snake sprites from her head (Balance.WHIP_SNAKE_TEXTURES), posed
## by `frame` (0-7); plain black lines are the fallback if the textures are missing.
## An AnimationPlayer animates `frame`; frame_changed tells the Player which body
## pose to show, so body and snakes share this one timeline.
extends Area2D

## Fired every time the lash frame changes (0-7). The Player's sprite follows it.
signal frame_changed(new_frame: int)

## Animation frames: 0 coil, 1 head back, 2 throw, 3 full fan, 4 hold,
## 5 retract, 6 retract, 7 neutral. Animated by the AnimationPlayer.
@export var frame: int = 7:
	set(value):
		frame = clampi(value, 0, Balance.WHIP_FRAME_EXTENT.size() - 1)
		_apply_frame()
		frame_changed.emit(frame)

## Name of the lash animation, built in code from Balance (so tuning stays there).
const ANIM_NAME: StringName = &"whip"

var _player: Player
## Which way the current lash points (-1 / 1), fixed when it starts.
var _facing: int = 1
## instance ids of everything this lash already hit.
var _hit_ids: Array[int] = []
var _lines: Array[Line2D] = []
## One snake sprite per line; empty if the snake textures failed to load.
var _snake_sprites: Array[Sprite2D] = []

@onready var _shape: CollisionPolygon2D = $Shape
@onready var _snakes: Node2D = $Snakes
@onready var _anim: AnimationPlayer = $Anim


func _ready() -> void:
	position = Balance.WHIP_HEAD_OFFSET
	monitoring = false
	for i in Balance.WHIP_SNAKES_DRAWN:
		var line := Line2D.new()
		line.width = Balance.WHIP_LINE_WIDTH
		line.default_color = Balance.COLOR_BLACK
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		_snakes.add_child(line)
		_lines.append(line)
	_build_snake_sprites()
	_build_animation()
	_apply_frame()
	body_entered.connect(_on_body_entered)
	_player = get_parent() as Player
	_player.whip_phase_changed.connect(_on_phase_changed)


## One Sprite2D per lash line, cycling through the 3 snake variants so the fan does
## not look cloned. Each is drawn from its tail (left edge, vertically centered), so
## the tail sits on the head and the snake's head lands on the line's tip.
## If any texture is missing, nothing is built and the black lines stay.
func _build_snake_sprites() -> void:
	var textures: Array[Texture2D] = []
	for path: String in Balance.WHIP_SNAKE_TEXTURES:
		if not ResourceLoader.exists(path):
			return
		textures.append(load(path) as Texture2D)
	for i in _lines.size():
		var sprite := Sprite2D.new()
		sprite.texture = textures[i % textures.size()]
		sprite.centered = false
		sprite.offset = Vector2(0.0, -sprite.texture.get_height() * 0.5)
		sprite.visible = false
		_snakes.add_child(sprite)
		_snake_sprites.append(sprite)
		_lines[i].visible = false


## One value track on `frame`, with a key where each frame begins: anticipation
## frames split WHIP_ANTICIPATION, active frames WHIP_ACTIVE, the rest WHIP_RECOVERY.
func _build_animation() -> void:
	var total: int = Balance.WHIP_FRAME_EXTENT.size()
	var recovery_frames: int = total - Balance.WHIP_ANTICIPATION_FRAMES - Balance.WHIP_ACTIVE_FRAMES
	var anim := Animation.new()
	anim.length = Balance.WHIP_ANTICIPATION + Balance.WHIP_ACTIVE + Balance.WHIP_RECOVERY
	var track: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, ^".:frame")
	anim.track_set_interpolation_type(track, Animation.INTERPOLATION_NEAREST)
	anim.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
	var index: int = 0
	var start: float = 0.0
	for phase in [[Balance.WHIP_ANTICIPATION, Balance.WHIP_ANTICIPATION_FRAMES],
			[Balance.WHIP_ACTIVE, Balance.WHIP_ACTIVE_FRAMES],
			[Balance.WHIP_RECOVERY, recovery_frames]]:
		for k in int(phase[1]):
			anim.track_insert_key(track, start + float(phase[0]) * k / int(phase[1]), index)
			index += 1
		start += float(phase[0])
	var library := AnimationLibrary.new()
	library.add_animation(ANIM_NAME, anim)
	_anim.add_animation_library(&"", library)
	# Step with physics, like the player's phase timers, so the two never drift.
	_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS


func _on_phase_changed(phase: Player.WhipPhase) -> void:
	match phase:
		Player.WhipPhase.ANTICIPATION:
			_facing = _player.facing
			_hit_ids.clear()
			_shape.polygon = _fan_points()
			_anim.play(ANIM_NAME)
			_anim.advance(0.0)  # show the coil on this very frame, not the next
		Player.WhipPhase.ACTIVE:
			monitoring = true
			Fx.play(&"whip_snap")
			_smear()
		Player.WhipPhase.RECOVERY:
			monitoring = false
		Player.WhipPhase.NONE:
			# Finished or cut short (jump, hit): drop the hitbox and put the hair away.
			monitoring = false
			_anim.stop()
			frame = Balance.WHIP_FRAME_EXTENT.size() - 1


## The hitbox: a thin fan from the head to a tip WHIP_REACH_BL ahead, WHIP_END_HEIGHT_BL
## tall there and drooping WHIP_TIP_DROOP. Mirrored for facing left (physics shapes
## are never scaled negative) with the winding reversed to stay valid.
func _fan_points() -> PackedVector2Array:
	var reach: float = Balance.WHIP_REACH_BL * Balance.BL
	var half_end: float = Balance.WHIP_END_HEIGHT_BL * Balance.BL * 0.5
	var points := PackedVector2Array([
		Vector2.ZERO,
		Vector2(reach * _facing, Balance.WHIP_TIP_DROOP - half_end),
		Vector2(reach * _facing, Balance.WHIP_TIP_DROOP + half_end),
	])
	if _facing < 0:
		points.reverse()
	return points


## Pose the lines for the current frame: each snake runs from the head toward a
## point on the fan's far edge, scaled by the frame's extent (negative = pulled
## back and up behind the head).
func _apply_frame() -> void:
	if _lines.is_empty():
		return
	var extent: float = Balance.WHIP_FRAME_EXTENT[frame]
	var spread: float = Balance.WHIP_FRAME_SPREAD[frame]
	var count: int = mini(Balance.WHIP_FRAME_SNAKES[frame], _lines.size())
	var reach: float = Balance.WHIP_REACH_BL * Balance.BL
	var half_end: float = Balance.WHIP_END_HEIGHT_BL * Balance.BL * 0.5
	for i in _lines.size():
		_lines[i].visible = i < count
		if i >= count:
			continue
		# -1 .. 1 across the fan (a single snake runs down the middle).
		var across: float = 0.0 if count == 1 else (float(i) / (count - 1) - 0.5) * 2.0
		var tip := Vector2(reach, Balance.WHIP_TIP_DROOP + across * spread * half_end) * extent
		tip.x *= _facing
		_lines[i].points = PackedVector2Array([Vector2.ZERO, tip])
		if not _snake_sprites.is_empty():
			_lines[i].visible = false
			_pose_snake(_snake_sprites[i], tip)
	# Hide the snake sprites this frame does not use.
	for i in range(count, _snake_sprites.size()):
		_snake_sprites[i].visible = false


## Stretch and turn one snake sprite so it runs from the head (origin) to `tip`.
## scale.x sets its length, scale.y its thickness (WHIP_SNAKE_THICKNESS px).
## Facing left the snake is flipped upside down, so its belly stays underneath.
func _pose_snake(sprite: Sprite2D, tip: Vector2) -> void:
	var length: float = tip.length()
	sprite.visible = length > 1.0
	if not sprite.visible:
		return
	sprite.rotation = tip.angle()
	sprite.scale = Vector2(length / sprite.texture.get_width(),
		Balance.WHIP_SNAKE_THICKNESS / sprite.texture.get_height())
	sprite.flip_v = _facing < 0


## Hit each target once per lash. Enemies are pushed away from Medusa; statues are
## only told (they never move).
## A pale smear over the lash's fan for a moment: motion blur, the way a fast strike
## reads in a drawing. It fades out over WHIP_SMEAR_S.
func _smear() -> void:
	var smear := Polygon2D.new()
	smear.polygon = _shape.polygon
	smear.color = Color(Balance.COLOR_MARBLE, Balance.WHIP_SMEAR_ALPHA)
	add_child(smear)
	var tween := smear.create_tween()
	tween.tween_property(smear, "modulate:a", 0.0, Balance.WHIP_SMEAR_S)
	tween.tween_callback(smear.queue_free)


func _on_body_entered(body: Node2D) -> void:
	Fx.dust(body.global_position, Balance.JUICE_WHIP_DUST)
	var id: int = body.get_instance_id()
	if _hit_ids.has(id):
		return
	if body is Enemy:
		_hit_ids.append(id)
		var away: int = int(signf(body.global_position.x - _player.global_position.x))
		(body as Enemy).whip_hit(away if away != 0 else _facing)
	elif body is Statue:
		_hit_ids.append(id)
		(body as Statue).whip_hit()
