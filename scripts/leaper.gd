## leaper.gd (root script of scenes/enemies/leaper.tscn)
## Purpose: the gap jumper. Crouches at a gap edge; when the player is across a
## gap within LEAPER_RANGE_BL it leaps in a ballistic arc that lands where she
## stood. A player on its own stretch of floor is ignored (contact still hurts).
## Touching her emits Events.player_hit(1, "leaper"). Rests after landing.
extends Enemy

enum State { WAIT, LEAP, RECOVER }

var state: State = State.WAIT
var _timer: float = 0.0
## Seconds airborne in the current leap (landing only counts after a minimum).
var _air_time: float = 0.0


func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	if tick_stagger(delta):
		move_and_slide()  # a staggered leaper is harmless: no contact check
		return
	match state:
		State.WAIT: _wait()
		State.LEAP: _leap(delta)
		State.RECOVER: _recover(delta)
	move_and_slide()
	check_contact()  # shared with every enemy, see Enemy.check_contact


func _wait() -> void:
	velocity.x = 0.0
	var player: Player = find_player()
	if player == null or not is_on_floor():
		return
	var d: Vector2 = player.global_position - global_position
	if absf(d.x) > Balance.LEAPER_RANGE_BL * Balance.BL \
			or absf(d.y) > Balance.LEAPER_LEVEL_SLACK_BL * Balance.BL:
		return
	set_facing(1 if d.x > 0.0 else -1)
	if absf(d.x) >= Balance.LEAPER_MIN_DISTANCE_BL * Balance.BL and _gap_between(player.global_position.x):
		_launch(d)


## True if the floor breaks somewhere between here and target_x (she is across a gap).
func _gap_between(target_x: float) -> bool:
	var dir: float = signf(target_x - global_position.x)
	var x: float = global_position.x + dir * (half_size.x + Balance.ENEMY_LEDGE_PROBE_AHEAD)
	while (target_x - x) * dir > 0.0:
		if not has_floor_at(x):
			return true
		x += dir * Balance.LEAPER_GAP_PROBE_STEP
	return false


## Ballistic launch: fixed apex height, horizontal speed chosen so the arc
## comes down on the target (d = target - self, y down).
func _launch(d: Vector2) -> void:
	var g: float = Balance.ENEMY_GRAVITY
	var vy: float = -sqrt(2.0 * g * Balance.LEAPER_APEX_BL * Balance.BL)
	var t: float = (-vy + sqrt(vy * vy + 2.0 * g * maxf(d.y, 0.0))) / g
	velocity = Vector2(clampf(d.x / t, -Balance.LEAPER_MAX_SPEED, Balance.LEAPER_MAX_SPEED), vy)
	state = State.LEAP
	_air_time = 0.0


func _leap(delta: float) -> void:
	_air_time += delta
	if _air_time >= Balance.LEAPER_MIN_AIR_TIME and is_on_floor():
		velocity.x = 0.0
		state = State.RECOVER
		_timer = Balance.LEAPER_RECOVERY


func _recover(delta: float) -> void:
	velocity.x = 0.0
	_timer -= delta
	if _timer <= 0.0:
		state = State.WAIT


## A whip hit cancels a leap in progress; after the stagger it rests, then looks again.
func _on_staggered() -> void:
	if state == State.LEAP:
		state = State.RECOVER
		_timer = Balance.LEAPER_RECOVERY

