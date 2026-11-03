## mirror_bearer.gd (root script of scenes/enemies/mirror_bearer.tscn)
## Purpose: the soldier with a bronze mirror. Walks like a hoplite (patrols his ledge,
## chases Medusa when she is close on the same level) and holds the mirror up on the
## side he faces. He has no weapon: touching him hurts (Enemy.check_contact).
## The trick is the gaze. If her gaze lands on him while the mirror is up and she is on
## the mirror's side, it bounces: a gold beam flies back to her, she takes
## CRACKS_REFLECT cracks ("reflect"), the gaze progress resets and he does NOT petrify.
## knock_mirror(seconds) (the whip does this) swings the mirror aside; while it is
## aside the gaze works on him like on anyone. The mirror flashes gold once a second
## so players notice it.
extends Enemy

enum State { PATROL, CHASE }

var state: State = State.PATROL
## Patrol center (spawn x).
var _home_x: float = 0.0
## Seconds the mirror stays knocked aside (0 = held up).
var _knock_left: float = 0.0
## Seconds until the next reflection may hurt her (so one held gaze is not a hit per frame).
var _reflect_cooldown: float = 0.0
## Counts up to MIRROR_GLINT_PERIOD for the gold flash.
var _glint_clock: float = 0.0

## The mirror (disc + handle) inside Visual, so it is tinted with the body.
@onready var _mirror: Node2D = $Visual/Mirror
## The gold flash. Outside Visual so the gaze tint does not recolor it.
@onready var _glint: Polygon2D = $Glint


## _ready runs once when he enters the scene. super._ready() runs Enemy's setup first.
func _ready() -> void:
	super._ready()
	_home_x = position.x
	mirror_bearer = true  # tells Enemy.whip_hit to call knock_mirror
	_glint.color = Balance.COLOR_GOLD
	_glint.scale = Vector2.ONE * (Balance.MIRROR_GLINT_SIZE / Balance.MIRROR_GLINT_ART_RADIUS)
	_glint.visible = false
	_place_mirror()


## _physics_process runs every physics tick (delta = seconds since the last one):
## gravity, stagger, then patrol or chase, then the mirror's timers and glint.
func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	_reflect_cooldown = maxf(_reflect_cooldown - delta, 0.0)
	_tick_mirror(delta)
	if tick_stagger(delta):
		move_and_slide()  # a staggered bearer is harmless
		return
	match state:
		State.PATROL: _patrol()
		State.CHASE: _chase()
	move_and_slide()
	check_contact()


## PATROL: pace back and forth around the spawn point, turning at walls, ledges and the
## patrol limit; switch to CHASE when Medusa comes close on the same level.
func _patrol() -> void:
	if _notices(find_player()):
		state = State.CHASE
		return
	var limit: float = Balance.MIRROR_PATROL_BL * Balance.BL
	if is_on_wall() or ledge_ahead(facing):
		set_facing(-facing)
	elif facing > 0 and position.x > _home_x + limit:
		set_facing(-1)
	elif facing < 0 and position.x < _home_x - limit:
		set_facing(1)
	velocity.x = facing * Balance.MIRROR_PATROL_SPEED


## Walk at Medusa, always facing her so the mirror points at her, and stop a little
## short (the body still hurts if she walks into it).
func _chase() -> void:
	var player: Player = find_player()
	if not _notices(player):
		velocity.x = 0.0
		state = State.PATROL
		return
	var dx: float = player.global_position.x - global_position.x
	set_facing(1 if dx > 0.0 else -1)
	if absf(dx) <= Balance.MIRROR_STOP_BL * Balance.BL or ledge_ahead(facing) or is_on_wall():
		velocity.x = 0.0
	else:
		velocity.x = facing * Balance.MIRROR_CHASE_SPEED


## Player within notice range on roughly the same level.
func _notices(player: Player) -> bool:
	if player == null:
		return false
	var d: Vector2 = player.global_position - global_position
	return absf(d.x) <= Balance.MIRROR_NOTICE_BL * Balance.BL \
			and absf(d.y) <= Balance.MIRROR_LEVEL_SLACK_BL * Balance.BL


# ---------------------------------------------------------------------------
# The mirror
# ---------------------------------------------------------------------------

## Swing the mirror aside for `seconds` (overrides the stub in Enemy). A second knock
## while it is already aside just extends the time.
func knock_mirror(seconds: float) -> void:
	_knock_left = maxf(_knock_left, seconds)
	_glint.visible = false
	_place_mirror()


## True while the mirror is held up in front of him.
func mirror_up() -> bool:
	return _knock_left <= 0.0


## Counts down the knock, puts the mirror back when it ends, and fires the gold glint
## once per MIRROR_GLINT_PERIOD (not while the mirror is aside).
func _tick_mirror(delta: float) -> void:
	if _knock_left > 0.0:
		_knock_left -= delta
		if _knock_left <= 0.0:
			_place_mirror()
		return
	_glint_clock += delta
	if _glint_clock >= Balance.MIRROR_GLINT_PERIOD:
		_glint_clock = 0.0
	_glint.visible = _glint_clock < Balance.MIRROR_GLINT_TIME
	_glint.position = Vector2(facing * Balance.MIRROR_HELD_OFFSET.x, Balance.MIRROR_HELD_OFFSET.y)


## Put the mirror art where it belongs: held out front, or hanging aside when knocked.
func _place_mirror() -> void:
	_mirror.position = Balance.MIRROR_HELD_OFFSET
	_mirror.rotation = 0.0 if mirror_up() else deg_to_rad(Balance.MIRROR_KNOCK_DEG)


## Overrides Enemy.set_facing: also moves the gold glint to the side the mirror is on
## (the glint lives outside Visual, so flipping the art does not move it).
func set_facing(dir: int) -> void:
	super.set_facing(dir)
	if _glint != null:
		_glint.position = Vector2(dir * Balance.MIRROR_HELD_OFFSET.x, Balance.MIRROR_HELD_OFFSET.y)


# ---------------------------------------------------------------------------
# The gaze
# ---------------------------------------------------------------------------

## Called by the gaze every physics frame he is in the cone with a clear view
## (overrides Enemy.add_gaze). Mirror up and facing her: reflect instead of petrifying.
func add_gaze(delta: float) -> void:
	var player: Player = find_player()
	if player != null and mirror_up() and not is_staggered() and _faces(player):
		reset_gaze()
		_reflect(player)
		return
	super.add_gaze(delta)


## True if Medusa stands on the side the mirror points to.
func _faces(player: Player) -> bool:
	return (player.global_position.x - global_position.x) * facing > 0.0


## Throw her gaze back: a gold beam, then the cracks (once per cooldown) and the ledger.
func _reflect(player: Player) -> void:
	if _reflect_cooldown > 0.0:
		return
	_reflect_cooldown = Balance.MIRROR_REFLECT_COOLDOWN
	var mirror_pos: Vector2 = to_global(Vector2(facing * Balance.MIRROR_HELD_OFFSET.x, Balance.MIRROR_HELD_OFFSET.y))
	_flash_beam(mirror_pos, player.global_position + Balance.GAZE_EYE_OFFSET)
	Events.gaze_reflected.emit(enemy_type, mirror_pos)
	Events.player_hit.emit(Balance.CRACKS_REFLECT, &"reflect", mirror_pos)


## A gold line from the mirror to her eyes that fades out. top_level makes the line
## ignore this node's position, so the points are plain world coordinates.
func _flash_beam(from: Vector2, to: Vector2) -> void:
	var beam := Line2D.new()
	beam.top_level = true
	beam.points = PackedVector2Array([from, to])
	beam.width = Balance.MIRROR_BEAM_WIDTH
	beam.default_color = Balance.COLOR_GOLD
	add_child(beam)
	var fade := beam.create_tween()
	fade.tween_property(beam, "modulate:a", 0.0, Balance.MIRROR_BEAM_TIME)
	fade.tween_callback(beam.queue_free)
