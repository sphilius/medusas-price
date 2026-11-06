## statue.gd (built in code by Statue.from_enemy; no scene)
## Purpose: a petrified enemy, frozen in the enemy's last pose and painted marble
## white (marble.gdshader for sprite art, a plain tint for placeholders), on the statues layer. It has no gravity of its own: a statue frozen
## mid-air hangs there as a platform until it is pushed. Pushed, it slides; with
## nothing under it, it falls until it lands (thud).
## The whip, and only the whip, breaks it: whip_hit() cracks an intact statue
## (white fracture lines over its body + a chip burst) and shatters a cracked one
## (rubble burst, collision removed, freed once the rubble is done). Pushing never
## changes its state, and the whip never pushes it.
## An AnimatableBody2D is a StaticBody2D that code can move, so riders and
## pushers get correct collisions while it slides or falls.
class_name Statue
extends AnimatableBody2D

enum State { INTACT, CRACKED, SHATTERED }
## STILL = held where it is (even mid-air), SLIDING = being pushed, FALLING = pushed off an edge.
enum Motion { STILL, SLIDING, FALLING }

## Intact -> cracked (first whip hit) -> shattered (second).
var state: State = State.INTACT
## What it used to be (copied from Enemy.enemy_type).
var enemy_type: StringName = &""
## What the body is doing right now.
var motion: Motion = Motion.STILL

## Direction of the current push: -1 left, 1 right.
var _push_dir: int = 0
## Seconds the slide keeps going without a fresh push() (refreshed by every push).
var _push_grace_left: float = 0.0
## Current slide speed (ramps up to STATUE_PUSH_SPEED).
var _slide_speed: float = 0.0
## Current fall speed and how long the fall has lasted.
var _fall_speed: float = 0.0
var _fall_time: float = 0.0
## Grinding loop while sliding; pitch follows slide speed.
var _grind: AudioStreamPlayer2D
## The enemy's art (moved over by from_enemy) and the fracture lines drawn on top of
## it once cracked (null until then).
var _art: Node2D
var _cracks: Node2D
## The marble shader on the art when the enemy had real sprite art (null for the
## placeholder polygons, which are tinted marble and get Line2D cracks instead).
var _marble: ShaderMaterial = null


## Build a statue in `enemy`'s place and add it beside the enemy. The enemy's
## Visual node is moved over as-is, which keeps its exact frame, flip and pose.
## The caller frees the enemy.
static func from_enemy(enemy: Enemy) -> Statue:
	var statue := Statue.new()
	statue.enemy_type = enemy.enemy_type
	statue.collision_layer = Balance.PHYS_STATUES
	# Only matters while moving: slides stop at walls and statues, falls land on them.
	statue.collision_mask = Balance.PHYS_WORLD | Balance.PHYS_STATUES
	# Moved by move_and_collide, not by an animation.
	statue.sync_to_physics = false
	statue.transform = enemy.transform
	statue.add_to_group(&"statues")

	# Same collision as the enemy (shape resources are shared; statues never resize).
	for child in enemy.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			statue.add_child(child.duplicate())

	statue._grind = AudioStreamPlayer2D.new()
	statue._grind.stream = Fx.grind_stream
	statue._grind.volume_db = Balance.GRIND_SFX_VOLUME_DB
	statue._grind.attenuation = Balance.GRIND_SFX_ATTENUATION
	statue.add_child(statue._grind)

	enemy.get_parent().add_child(statue)

	# Freeze the pose: move the art over, stop any animation, paint it marble.
	var art: Node2D = enemy.visual
	statue._art = art
	art.reparent(statue, false)
	var sprites: Array[Node] = art.find_children("*", "AnimatedSprite2D", true, false)
	for sprite in sprites:
		(sprite as AnimatedSprite2D).pause()
	if sprites.is_empty():
		# Placeholder polygons are white, so a marble tint is enough.
		art.modulate = Balance.COLOR_MARBLE
		return statue
	# Real art is black and terracotta: tinting it would stay dark, so the marble shader
	# repaints it instead. It sits on Visual, and every drawn child (body, spear, mirror)
	# borrows it with use_parent_material, replacing the petrify shader on the body.
	art.modulate = Color.WHITE
	statue._marble = SpriteKit.marble_material()
	art.material = statue._marble
	for item in art.find_children("*", "CanvasItem", true, false):
		(item as CanvasItem).material = null
		(item as CanvasItem).use_parent_material = true
	return statue


## The whip landed on this statue: first hit cracks it, second shatters it. The
## whip never moves statues (this does not touch the motion state).
func whip_hit() -> void:
	match state:
		State.INTACT:
			_crack()
		State.CRACKED:
			_shatter()


## Called by the player every physics frame she leans into this statue (after
## the push delay). The slide lasts while pushes keep coming. Never changes `state`.
func push(dir: int) -> void:
	if motion == Motion.FALLING or state == State.SHATTERED:
		return
	_push_dir = dir
	_push_grace_left = Balance.STATUE_PUSH_GRACE


func _physics_process(delta: float) -> void:
	match motion:
		Motion.STILL:
			_process_still(delta)
		Motion.SLIDING:
			_process_slide(delta)
		Motion.FALLING:
			_process_fall(delta)


## Start sliding when pushed, unless something already blocks that way.
func _process_still(delta: float) -> void:
	if _push_grace_left <= 0.0:
		return
	_push_grace_left -= delta
	if test_move(global_transform, Vector2(_push_dir, 0.0)):
		return  # against a wall: no slide, no repeated thuds
	motion = Motion.SLIDING
	_grind.play()


## Slide until the pushing stops (release) or a wall is hit; fall at an edge.
func _process_slide(delta: float) -> void:
	_push_grace_left -= delta
	if _push_grace_left <= 0.0:
		_stop_slide()
		return
	_slide_speed = move_toward(_slide_speed, Balance.STATUE_PUSH_SPEED, Balance.STATUE_PUSH_ACCEL * delta)
	_grind.pitch_scale = lerpf(Balance.STATUE_GRIND_PITCH_MIN, Balance.STATUE_GRIND_PITCH_MAX,
			_slide_speed / Balance.STATUE_PUSH_SPEED)
	if move_and_collide(Vector2(_push_dir * _slide_speed * delta, 0.0)):
		_stop_slide()
	elif not test_move(global_transform, Vector2.DOWN):
		_start_fall()


## Drop straight down until landing on world or another statue.
func _process_fall(delta: float) -> void:
	_fall_speed += Balance.STATUE_GRAVITY * delta
	_fall_time += delta
	if move_and_collide(Vector2(0.0, _fall_speed * delta)):
		motion = Motion.STILL
		_fall_speed = 0.0
		_fall_time = 0.0
		Events.statue_thud.emit(global_position, true)
	elif _fall_time > Balance.STATUE_MAX_FALL_TIME:
		queue_free()  # fell into a pit


func _stop_slide() -> void:
	motion = Motion.STILL
	_slide_speed = 0.0
	_push_grace_left = 0.0
	_grind.stop()
	Events.statue_thud.emit(global_position, false)


func _start_fall() -> void:
	motion = Motion.FALLING
	_slide_speed = 0.0
	_push_grace_left = 0.0
	_grind.stop()


## INTACT -> CRACKED: fracture lines over the whole body and a chip burst. It keeps
## sliding or falling if it was.
func _crack() -> void:
	state = State.CRACKED
	var rect: Rect2 = _body_rect()
	if _marble != null:
		# Cracks start on the side the whip came from (Medusa's side), at chest height.
		var player := get_tree().get_first_node_in_group(&"player") as Node2D
		var from_left: bool = player != null and player.global_position.x < global_position.x
		_marble.set_shader_parameter(&"crack_origin", Vector2(0.25 if from_left else 0.75, 0.35))
		_marble.set_shader_parameter(&"cracked", true)  # cracks drawn by marble.gdshader
	else:
		_build_cracks(rect)
	var chips: CPUParticles2D = _burst(rect, Balance.STATUE_CHIP_COUNT, Balance.STATUE_CHIP_LIFETIME,
			Balance.STATUE_CHIP_SPREAD_DEG, Balance.STATUE_CHIP_SPEED_MIN, Balance.STATUE_CHIP_SPEED_MAX,
			Balance.STATUE_CHIP_SIZE_MIN, Balance.STATUE_CHIP_SIZE_MAX)
	chips.finished.connect(chips.queue_free)
	Events.statue_cracked.emit(enemy_type, global_position)


## Break this statue at once, whatever its state (Perseus's shield-bash does this).
func shatter() -> void:
	if state != State.SHATTERED:
		_shatter()


## CRACKED -> SHATTERED: the statue turns into a rubble burst. It stops moving, stops
## being solid (deferred: this runs inside the whip's physics callback), leaves the
## "statues" group, and is freed once the rubble has finished.
func _shatter() -> void:
	state = State.SHATTERED
	remove_from_group(&"statues")
	set_physics_process(false)
	motion = Motion.STILL
	_push_grace_left = 0.0
	_slide_speed = 0.0
	_fall_speed = 0.0
	_grind.stop()
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", true)
	_art.hide()
	if _cracks != null:
		_cracks.hide()
	var rubble: CPUParticles2D = _burst(_body_rect(), Balance.STATUE_RUBBLE_COUNT, Balance.STATUE_RUBBLE_LIFETIME,
			Balance.STATUE_RUBBLE_SPREAD_DEG, Balance.STATUE_RUBBLE_SPEED_MIN, Balance.STATUE_RUBBLE_SPEED_MAX,
			Balance.STATUE_RUBBLE_SIZE_MIN, Balance.STATUE_RUBBLE_SIZE_MAX)
	rubble.finished.connect(queue_free)
	Events.statue_shattered.emit(enemy_type, global_position)


## The statue's body in its own space: the union of its rectangle collision shapes.
## Cracks and debris cover the figure's mass, not a spear tip sticking out of it.
func _body_rect() -> Rect2:
	var rect := Rect2()
	var found: bool = false
	for child in get_children():
		var shape := child as CollisionShape2D
		if shape == null or not shape.shape is RectangleShape2D:
			continue
		var size: Vector2 = (shape.shape as RectangleShape2D).size
		var part := Rect2(shape.position - size * 0.5, size)
		rect = part if not found else rect.merge(part)
		found = true
	if not found:
		return Rect2(-Balance.ENEMY_HALF_WIDTH, -Balance.ENEMY_HALF_HEIGHT,
				Balance.ENEMY_HALF_WIDTH * 2.0, Balance.ENEMY_HALF_HEIGHT * 2.0)
	return rect


## Zigzag fracture lines spread over `rect`, alternating top-to-bottom and
## left-to-right, each a white line over a wider dark edge so it reads on marble.
func _build_cracks(rect: Rect2) -> void:
	_cracks = Node2D.new()
	add_child(_cracks)  # after the art, so it draws on top
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var stray: float = minf(rect.size.x, rect.size.y) * Balance.STATUE_CRACK_JITTER
	var edge_color := Color(Balance.COLOR_BLACK, Balance.STATUE_CRACK_EDGE_ALPHA)
	var down_lines: int = ceili(Balance.STATUE_CRACK_LINES * 0.5)
	var across_lines: int = Balance.STATUE_CRACK_LINES - down_lines
	for i in Balance.STATUE_CRACK_LINES:
		var down: bool = i % 2 == 0
		var slot: int = floori(i * 0.5)
		# One line per slot along the edge it starts on, jittered inside its slot.
		var along: float = (slot + rng.randf_range(0.2, 0.8)) / (down_lines if down else across_lines)
		var from: Vector2
		var to: Vector2
		if down:
			from = Vector2(rect.position.x + rect.size.x * along, rect.position.y)
			to = Vector2(rect.position.x + rect.size.x * rng.randf(), rect.end.y)
		else:
			from = Vector2(rect.position.x, rect.position.y + rect.size.y * along)
			to = Vector2(rect.end.x, rect.position.y + rect.size.y * rng.randf())
		var side: Vector2 = (to - from).orthogonal().normalized()
		var points := PackedVector2Array()
		for k in Balance.STATUE_CRACK_SEGMENTS + 1:
			var p: Vector2 = from.lerp(to, float(k) / Balance.STATUE_CRACK_SEGMENTS)
			if k > 0 and k < Balance.STATUE_CRACK_SEGMENTS:
				p += side * rng.randf_range(-stray, stray)
			points.append(p.clamp(rect.position, rect.end))
		_cracks.add_child(_make_line(points, Balance.STATUE_CRACK_EDGE_WIDTH, edge_color))
		_cracks.add_child(_make_line(points, Balance.STATUE_CRACK_WIDTH, Balance.COLOR_MARBLE))


func _make_line(points: PackedVector2Array, width: float, color: Color) -> Line2D:
	var line := Line2D.new()
	line.points = points
	line.width = width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	return line


## A one-shot burst of marble squares from across `rect`, flung out within `spread`
## degrees of straight up, falling under gravity and fading out. CPUParticles2D, so
## it works in the WebGL2 build. Particles stay in world space once launched.
func _burst(rect: Rect2, count: int, lifetime: float, spread: float, speed_min: float,
		speed_max: float, size_min: float, size_max: float) -> CPUParticles2D:
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 1.0])
	fade.colors = PackedColorArray([Balance.COLOR_MARBLE, Color(Balance.COLOR_MARBLE, 0.0)])
	var burst := CPUParticles2D.new()
	burst.position = rect.get_center()
	burst.amount = count
	burst.lifetime = lifetime
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.local_coords = false
	burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	burst.emission_rect_extents = rect.size * 0.5
	burst.direction = Vector2.UP
	burst.spread = spread
	burst.gravity = Vector2(0.0, Balance.STATUE_GRAVITY)
	burst.initial_velocity_min = speed_min
	burst.initial_velocity_max = speed_max
	burst.scale_amount_min = size_min
	burst.scale_amount_max = size_max
	burst.color_ramp = fade
	add_child(burst)
	burst.emitting = true
	return burst
