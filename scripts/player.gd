## player.gd (root script of scenes/player.tscn)
## Purpose: Medusa's movement - run, jump (coyote time, jump buffer, variable
## height) - plus the state machine other systems will hook into later.
## Every tuning number comes from the Balance autoload; nothing is typed inline.
class_name Player
extends CharacterBody2D

## All the things Medusa can be doing. In WHIP, GAZE, HURT and DEAD she simply
## falls and slows down (no movement input). GAZE is entered while K is held and
## read by the Gaze child; WHIP, HURT and DEAD wait for the whip and portrait.
enum State { IDLE, RUN, JUMP, FALL, WHIP, GAZE, HURT, DEAD }

## Fired whenever the state changes (animation, audio and VFX can listen).
signal state_changed(old_state: State, new_state: State)

## Which way she looks: -1 = left, 1 = right. Other systems read this (gaze cone, whip).
var facing: int = 1
## Current state. Change it with enter_state(), not by assigning directly.
var state: State = State.IDLE

## Seconds left in which a jump is still allowed after walking off a ledge.
var _coyote_left: float = 0.0
## Seconds left in which a recent jump press is still remembered.
var _buffer_left: float = 0.0
## Seconds spent walking into the same side of a statue (push starts at STATUE_PUSH_DELAY).
var _push_time: float = 0.0

## The child node holding the placeholder art; flipped when facing changes.
@onready var _visual: Node2D = $Visual


func _physics_process(delta: float) -> void:
	# Gaze roots Medusa while held: she brakes, still falls, and cannot turn.
	# Releasing K hands control back to the normal locomotion states.
	if Input.is_action_pressed("gaze") and can_gaze():
		enter_state(State.GAZE)
	elif state == State.GAZE:
		_update_locomotion_state(0.0)

	# Stub states: no player control yet, but keep physics sane (gravity + slow down).
	if state in [State.WHIP, State.GAZE, State.HURT, State.DEAD]:
		_push_time = 0.0
		_process_stub_state(delta)
		return

	var dir: float = Input.get_axis("move_left", "move_right")
	_update_facing(dir)
	_update_jump_timers(delta)

	# Horizontal: accelerate toward the target speed (also brakes when dir is 0).
	velocity.x = move_toward(velocity.x, dir * Balance.PLAYER_RUN_SPEED, Balance.PLAYER_GROUND_ACCEL * delta)

	# Vertical: gravity only while airborne.
	if not is_on_floor():
		velocity.y += Balance.PLAYER_GRAVITY * delta

	# Jump if a press is buffered and we are (or just were) on the ground.
	if _buffer_left > 0.0 and _coyote_left > 0.0:
		velocity.y = Balance.PLAYER_JUMP_VELOCITY
		_buffer_left = 0.0
		_coyote_left = 0.0  # spend coyote time so we cannot double jump

	# Variable jump height: letting go while still rising cuts the upward speed.
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= Balance.PLAYER_JUMP_CUT

	move_and_slide()
	_update_push(dir, delta)
	_update_locomotion_state(dir)


## Switch state and announce it. Safe to call from other scripts.
func enter_state(new_state: State) -> void:
	if new_state == state:
		return
	var old: State = state
	state = new_state
	state_changed.emit(old, new_state)


## False while whipping (anticipation through recovery), hurt or dead.
func can_gaze() -> bool:
	return state not in [State.WHIP, State.HURT, State.DEAD]


## Remember the last non-zero direction and mirror the art to match.
func _update_facing(dir: float) -> void:
	if dir != 0.0:
		facing = 1 if dir > 0.0 else -1
		_visual.scale.x = facing


## Tick coyote time and jump buffer.
func _update_jump_timers(delta: float) -> void:
	if is_on_floor():
		_coyote_left = Balance.PLAYER_COYOTE_TIME
	else:
		_coyote_left = maxf(_coyote_left - delta, 0.0)

	if Input.is_action_just_pressed("jump"):
		_buffer_left = Balance.PLAYER_JUMP_BUFFER
	else:
		_buffer_left = maxf(_buffer_left - delta, 0.0)


## Statue pushing: walk into a statue's side from the ground for STATUE_PUSH_DELAY,
## then it slides while she keeps pushing. Her speed is matched to the slide so
## she stays in contact instead of stuttering against it.
func _update_push(dir: float, delta: float) -> void:
	var statue: Statue = _statue_pushed_into(dir)
	if statue == null or not is_on_floor():
		_push_time = 0.0
		return
	_push_time += delta
	if _push_time >= Balance.STATUE_PUSH_DELAY:
		statue.push(int(signf(dir)))
		velocity.x = signf(dir) * Balance.STATUE_PUSH_SPEED


## The statue she just walked into side-on in the held direction, or null.
func _statue_pushed_into(dir: float) -> Statue:
	if dir == 0.0:
		return null
	for i in get_slide_collision_count():
		var hit: KinematicCollision2D = get_slide_collision(i)
		if hit.get_collider() is Statue and hit.get_normal().x * signf(dir) <= -Balance.STATUE_PUSH_NORMAL:
			return hit.get_collider() as Statue
	return null


## Pick IDLE / RUN / JUMP / FALL from what the body is actually doing.
func _update_locomotion_state(dir: float) -> void:
	if is_on_floor():
		if dir == 0.0 and absf(velocity.x) < 5.0:
			enter_state(State.IDLE)
		else:
			enter_state(State.RUN)
	elif velocity.y < 0.0:
		enter_state(State.JUMP)
	else:
		enter_state(State.FALL)


## Placeholder for WHIP / GAZE / HURT / DEAD: fall, slow to a stop, no input.
func _process_stub_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, Balance.PLAYER_GROUND_ACCEL * delta)
	if not is_on_floor():
		velocity.y += Balance.PLAYER_GRAVITY * delta
	move_and_slide()
