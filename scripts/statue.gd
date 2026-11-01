## statue.gd (built in code by Statue.from_enemy; no scene)
## Purpose: a petrified enemy, frozen in the enemy's last pose and tinted marble
## white, on the statues layer. It has no gravity of its own: a statue frozen
## mid-air hangs there as a platform until it is pushed. Pushed, it slides; with
## nothing under it, it falls until it lands (thud). Cracking and shattering
## come with the whip.
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
	statue.add_child(statue._grind)

	enemy.get_parent().add_child(statue)

	# Freeze the pose: move the art over, stop any animation, paint it marble.
	var art: Node2D = enemy.visual
	art.reparent(statue, false)
	for sprite in art.find_children("*", "AnimatedSprite2D", true, false):
		(sprite as AnimatedSprite2D).pause()
	art.modulate = Balance.COLOR_MARBLE
	return statue


## Called by the player every physics frame she leans into this statue (after
## the push delay). The slide lasts while pushes keep coming.
func push(dir: int) -> void:
	if motion == Motion.FALLING:
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
