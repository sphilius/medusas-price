## player.gd (root script of scenes/player.tscn)
## Purpose: Medusa's movement - run, jump (coyote time, jump buffer, variable
## height) - plus the state machine other systems will hook into later.
## Every tuning number comes from the Balance autoload; nothing is typed inline.
class_name Player
extends CharacterBody2D

## All the things Medusa can be doing. In WHIP, GAZE, HURT and DEAD she simply
## falls and slows down (no movement input). GAZE is entered while K is held and
## read by the Gaze child; WHIP (J) runs the three whip phases below and is read
## by the Whip child; HURT and DEAD wait for the portrait.
enum State { IDLE, RUN, JUMP, FALL, WHIP, GAZE, HURT, DEAD }

## The parts of a lash, in order. NONE whenever the state is not WHIP. No other
## action, and no gaze, during ANTICIPATION and RECOVERY; only RECOVERY can be
## cancelled (by jumping).
enum WhipPhase { NONE, ANTICIPATION, ACTIVE, RECOVERY }

## Fired whenever the state changes (animation, audio and VFX can listen).
signal state_changed(old_state: State, new_state: State)
## Fired at every whip phase change. The Whip child listens: it plays the lash
## animation and enables its hitbox during ACTIVE only.
signal whip_phase_changed(phase: WhipPhase)

## Which way she looks: -1 = left, 1 = right. Other systems read this (gaze cone, whip).
var facing: int = 1
## Current state. Change it with enter_state(), not by assigning directly.
var state: State = State.IDLE
## Which part of the lash she is in (NONE outside State.WHIP).
var whip_phase: WhipPhase = WhipPhase.NONE

## Seconds left in which a jump is still allowed after walking off a ledge.
var _coyote_left: float = 0.0
## Seconds left in which a recent jump press is still remembered.
var _buffer_left: float = 0.0
## Seconds left in the HURT stun and in the invulnerability that follows a hit.
var _hurt_left: float = 0.0
var _invuln_left: float = 0.0
## Seconds spent walking into the same side of a statue (push starts at STATUE_PUSH_DELAY).
var _push_time: float = 0.0
## Seconds left in the current whip phase (a negative leftover carries into the next).
var _whip_left: float = 0.0

## Where she stands again after a pit fall (center) and after dying (center). Both
## start at her spawn; safe ledges and mirror pools move them.
var _safe_ledge_point: Vector2 = Vector2.ZERO
var _pool_point: Vector2 = Vector2.ZERO
## True from the moment the portrait runs out until she is back on her feet.
var _dying: bool = false
## Whether Shift (sprint) was held on her last frame on the ground. In the air this stays
## as it was at take-off, so a jump keeps the speed it started with.
var _air_sprint: bool = false

## The child node holding the art; flipped when facing changes.
@onready var _visual: Node2D = $Visual
## Medusa's animated sprite (made in _ready by SpriteKit), or null if the art is
## missing, in which case the placeholder polygons stay visible.
var _sprite: AnimatedSprite2D = null
## Last kneel / push flags, so the animation only changes when one of them flips.
var _was_kneeling: bool = false
var _was_pushing: bool = false


func _ready() -> void:
	add_to_group(&"player")
	_safe_ledge_point = global_position
	_pool_point = global_position
	Events.player_hit.connect(_on_player_hit)
	Events.safe_ledge_reached.connect(_on_safe_ledge_reached)
	Events.pool_used.connect(_on_pool_used)
	Events.player_fell.connect(_on_player_fell)
	PortraitState.died.connect(_on_portrait_died)
	_sprite = SpriteKit.attach(_visual, &"medusa")
	state_changed.connect(func(_old: State, _new: State) -> void: _refresh_animation())
	($Whip as Node).frame_changed.connect(_on_whip_frame)
	_refresh_animation()


func _physics_process(delta: float) -> void:
	# Backstop for a fall no Pit zone caught. The respawn moves her back up, so it fires once.
	if not _dying and global_position.y > Balance.PLAYER_PIT_Y:
		Events.player_fell.emit(global_position)
	_tick_hurt(delta)
	# Timers run in every state, so a jump pressed during the lash can cancel its recovery.
	_update_jump_timers(delta)
	_tick_whip(delta)
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

	# Horizontal: accelerate toward the target speed (also brakes when dir is 0).
	velocity.x = move_toward(velocity.x, dir * _top_speed(), Balance.PLAYER_GROUND_ACCEL * delta)

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
	# Kneel and push are not states, so watch their flags and re-pick the pose when one flips.
	var kneeling: bool = is_kneeling()
	var pushing: bool = _push_time > 0.0
	if kneeling != _was_kneeling or pushing != _was_pushing:
		_was_kneeling = kneeling
		_was_pushing = pushing
		_refresh_animation()


## A hit lands: stun, knock away from the attacker, start the invulnerable window.
## Ignored while already stunned, invulnerable or dead.
func _on_player_hit(cracks: int, source: StringName, from_position: Vector2) -> void:
	if _invuln_left > 0.0 or state in [State.HURT, State.DEAD]:
		return
	RunLedger.log_event("hit", {
		"source": String(source),
		"cracks": cracks,
		"position": [global_position.x, global_position.y],
		"level": RunLedger.level,
	})
	# Only a hit that gets past the gate above costs cracks (hits during the
	# invulnerable window are ignored, however often the enemy re-sends them).
	PortraitState.add_cracks(cracks, source)
	if _dying:
		return
	var away: float = signf(global_position.x - from_position.x)
	if away == 0.0:
		away = -float(facing)
	velocity = Vector2(away * Balance.PLAYER_KNOCKBACK_X, -Balance.PLAYER_KNOCKBACK_Y)
	_hurt_left = Balance.PLAYER_HURT_TIME
	_invuln_left = Balance.PLAYER_INVULN_TIME
	enter_state(State.HURT)


## Touching a safe ledge: a pit fall will put her back here (marker is on the floor).
func _on_safe_ledge_reached(floor_point: Vector2) -> void:
	_safe_ledge_point = floor_point + Vector2(0.0, -Balance.PLAYER_FEET_OFFSET)


## Healing at a pool makes it the death respawn.
func _on_pool_used(floor_point: Vector2) -> void:
	_pool_point = floor_point + Vector2(0.0, -Balance.PLAYER_FEET_OFFSET)


## Fell into a pit: one crack, then back to the last safe ledge with a brief grace
## period. If that crack was the last one, dying takes over instead.
func _on_player_fell(_where: Vector2) -> void:
	if _dying:
		return
	RunLedger.log_event("pit", {"level": RunLedger.level})
	PortraitState.add_cracks(Balance.CRACKS_PIT, &"pit")
	if _dying:
		return
	_teleport(_safe_ledge_point)
	_hurt_left = 0.0
	_invuln_left = Balance.PLAYER_INVULN_TIME
	_update_locomotion_state(0.0)


## The portrait ran out: turn to marble (art tinted over DEATH_STONE_TIME while the
## screen desaturates), hold, then get up at the last pool at the respawn stage.
func _on_portrait_died() -> void:
	if _dying:
		return
	_dying = true
	_hurt_left = 0.0
	enter_state(State.DEAD)
	RunLedger.log_event("death", {
		"source": String(PortraitState.last_source),
		"position": [global_position.x, global_position.y],
		"level": RunLedger.level,
	})
	Events.player_died.emit(global_position)
	var polygons: Array[Polygon2D] = []
	var base_colors: Array[Color] = []
	for node: Node in _visual.find_children("*", "Polygon2D", true, false):
		polygons.append(node as Polygon2D)
		base_colors.append((node as Polygon2D).color)
	var tint := func(t: float) -> void:
		for i in polygons.size():
			polygons[i].color = base_colors[i].lerp(Balance.COLOR_MARBLE, t)
	var tween: Tween = create_tween()
	tween.tween_method(tint, 0.0, 1.0, Balance.DEATH_STONE_TIME)
	tween.tween_interval(Balance.DEATH_HOLD_TIME)
	await tween.finished
	PortraitState.reset_after_death()
	for i in polygons.size():
		polygons[i].color = base_colors[i]
	_visual.modulate.a = 1.0
	_teleport(_pool_point)
	_invuln_left = Balance.PLAYER_INVULN_TIME
	_dying = false
	enter_state(State.IDLE)
	Events.player_respawned.emit(global_position)


## Put her somewhere else, standing still. A smoothed follow camera jumps with her
## instead of swooping across the level.
func _teleport(point: Vector2) -> void:
	global_position = point
	velocity = Vector2.ZERO
	_push_time = 0.0
	for node: Node in find_children("*", "Camera2D", false, false):
		(node as Camera2D).reset_smoothing()


## Down is held while she is on the floor and free to act: the kneel that works a mirror pool.
func is_kneeling() -> bool:
	return is_on_floor() and state in [State.IDLE, State.RUN] and Input.is_action_pressed("move_down")


## Her top horizontal speed right now: walking, or sprinting while Shift is held. Shift is
## only read while she stands on the floor (see _air_sprint), so the speed she takes off
## with is the speed she keeps through the jump, which is what makes a sprint jump longer.
func _top_speed() -> float:
	if is_on_floor():
		_air_sprint = Input.is_action_pressed("run")
	return Balance.PLAYER_RUN_SPEED * (Balance.PLAYER_SPRINT_MULT if _air_sprint else 1.0)


## Count down the stun and invulnerability; flicker the art while invulnerable.
func _tick_hurt(delta: float) -> void:
	if _hurt_left > 0.0:
		_hurt_left -= delta
		if _hurt_left <= 0.0 and state == State.HURT:
			_update_locomotion_state(0.0)
	if _invuln_left > 0.0:
		_invuln_left = maxf(_invuln_left - delta, 0.0)
		var faded: bool = int(_invuln_left / Balance.PLAYER_FLICKER_PERIOD) % 2 == 0 and _invuln_left > 0.0
		_visual.modulate.a = Balance.PLAYER_FLICKER_ALPHA if faded else 1.0


## Switch state and announce it. Safe to call from other scripts.
func enter_state(new_state: State) -> void:
	if new_state == state:
		return
	var old: State = state
	state = new_state
	state_changed.emit(old, new_state)
	# However the lash ends (finished, jump-cancelled, interrupted by a hit), clear its phase.
	if old == State.WHIP:
		_set_whip_phase(WhipPhase.NONE)


## False while whipping (anticipation through recovery), hurt or dead.
func can_gaze() -> bool:
	return state not in [State.WHIP, State.HURT, State.DEAD]


## J starts a lash from any state but WHIP itself, HURT and DEAD (it interrupts a gaze).
func can_whip() -> bool:
	return state not in [State.WHIP, State.HURT, State.DEAD]


## Start a lash on J, then walk its three phases by their Balance times. Leaving a
## phase carries any overshoot into the next, so the whole lash lasts exactly
## anticipation + active + recovery. A jump pressed during recovery (or buffered
## just before it, with the ground or coyote time under her) ends the lash early;
## the normal movement code then performs that jump in the same frame.
func _tick_whip(delta: float) -> void:
	if state != State.WHIP:
		if Input.is_action_just_pressed("whip") and can_whip():
			_start_whip()
		return
	_whip_left -= delta
	if _whip_left <= 0.0:
		match whip_phase:
			WhipPhase.ANTICIPATION:
				_set_whip_phase(WhipPhase.ACTIVE)
				_whip_left += Balance.WHIP_ACTIVE
			WhipPhase.ACTIVE:
				_set_whip_phase(WhipPhase.RECOVERY)
				_whip_left += Balance.WHIP_RECOVERY
			WhipPhase.RECOVERY:
				_update_locomotion_state(0.0)
				return
	if whip_phase == WhipPhase.RECOVERY and _buffer_left > 0.0 and _coyote_left > 0.0:
		_update_locomotion_state(0.0)


func _start_whip() -> void:
	enter_state(State.WHIP)
	_whip_left = Balance.WHIP_ANTICIPATION
	_set_whip_phase(WhipPhase.ANTICIPATION)


func _set_whip_phase(phase: WhipPhase) -> void:
	if phase == whip_phase:
		return
	whip_phase = phase
	whip_phase_changed.emit(phase)


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
	var friction: float = Balance.PLAYER_HURT_FRICTION if state == State.HURT else Balance.PLAYER_GROUND_ACCEL
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	if not is_on_floor():
		# Mid-air the lash itself hangs her up: half gravity while it is active.
		var lashing: bool = state == State.WHIP and whip_phase == WhipPhase.ACTIVE
		velocity.y += Balance.PLAYER_GRAVITY * (Balance.WHIP_AIR_GRAVITY_MULT if lashing else 1.0) * delta
	move_and_slide()


## Pick the animation that matches what she is doing. Called when the state changes
## and when the kneel / push flags flip (signals, not a check every frame).
func _refresh_animation() -> void:
	if _sprite == null:
		return
	match state:
		State.IDLE:
			SpriteKit.play(_sprite, &"kneel" if _was_kneeling else &"idle")
		State.RUN:
			SpriteKit.play(_sprite, &"push" if _was_pushing else &"run")
		State.JUMP:
			SpriteKit.play(_sprite, &"jump")
		State.FALL:
			SpriteKit.play(_sprite, &"fall")
		State.WHIP:
			# The whip timeline drives the frame (see _on_whip_frame), so hold still here.
			SpriteKit.play(_sprite, &"whip")
			_sprite.pause()
		State.GAZE:
			SpriteKit.play(_sprite, &"gaze")
		State.HURT:
			SpriteKit.play(_sprite, &"hurt")
		State.DEAD:
			SpriteKit.play(_sprite, &"death")


## The lash moved to frame `whip_frame` (0-7): show the matching body pose.
## Frames 0-1 are the wind-up, 2-4 the strike, 5-7 the recovery (see build_sprites.py).
func _on_whip_frame(whip_frame: int) -> void:
	if _sprite == null or state != State.WHIP:
		return
	if _sprite.animation != &"whip":
		_sprite.play(&"whip")
		_sprite.pause()
	_sprite.frame = whip_frame
