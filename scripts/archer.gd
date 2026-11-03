## archer.gd (root script of scenes/enemies/archer.tscn)
## Purpose: the ledge archer. Stands still. When Medusa is within ARCHER_RANGE_BL and
## in line of sight (nothing in the world or a statue between them), it faces her and
## draws for ARCHER_DRAW_TIME with a gold glint on the arrowhead, then looses an arrow
## (scenes/projectiles/arrow.tscn) on a ballistic arc that leads her a little. Then it
## waits ARCHER_COOLDOWN seconds. Losing sight mid-draw lowers the bow. A whip hit
## also breaks the draw. Set eye_shading on the scene for the slow-to-petrify variant.
extends Enemy

enum State { IDLE, DRAW, COOLDOWN }

const ARROW_SCENE: PackedScene = preload("res://scenes/projectiles/arrow.tscn")

var state: State = State.IDLE
## Seconds left in the current DRAW or COOLDOWN.
var _timer: float = 0.0

@onready var _glint: Polygon2D = $Glint


## _ready runs once when the archer enters the scene. super._ready() runs Enemy's setup
## first (collision layers, contact zone); then we style the gold glint.
func _ready() -> void:
	super._ready()
	_glint.color = Balance.COLOR_GOLD
	_glint.scale = Vector2.ONE * (Balance.ARCHER_GLINT_SIZE / Balance.ARCHER_GLINT_ART_RADIUS)
	_glint.visible = false
	_place_glint()


## _physics_process runs every physics tick (delta = seconds since the last one). It
## applies gravity, handles the whip stagger, then runs whichever state we are in.
func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	if tick_stagger(delta):
		move_and_slide()  # a staggered archer is harmless
		return
	velocity.x = 0.0
	match state:
		State.IDLE: _idle()
		State.DRAW: _draw_bow(delta)
		State.COOLDOWN: _cooldown(delta)
	move_and_slide()
	check_contact()


## IDLE: wait until Medusa is in range with a clear view, then start drawing.
func _idle() -> void:
	var player: Player = find_player()
	if not _can_see(player):
		return
	_face(player)
	state = State.DRAW
	_timer = Balance.ARCHER_DRAW_TIME
	_glint.visible = true


## DRAW: hold the bow back (gold glint) for ARCHER_DRAW_TIME, then fire. Named
## _draw_bow because Godot already has a built-in _draw() for custom drawing.
func _draw_bow(delta: float) -> void:
	var player: Player = find_player()
	if not _can_see(player):
		_lower_bow()
		return
	_face(player)
	_timer -= delta
	if _timer <= 0.0:
		_fire(player)
		_glint.visible = false
		state = State.COOLDOWN
		_timer = Balance.ARCHER_COOLDOWN


## COOLDOWN: do nothing until the pause between shots is over.
func _cooldown(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		state = State.IDLE


## A whip hit drops the draw (no shot, no cooldown: he has to start over).
func _on_staggered() -> void:
	_lower_bow()


## Abort a draw: back to IDLE with the glint off.
func _lower_bow() -> void:
	state = State.IDLE
	_glint.visible = false


## Player in range and nothing from the world or a statue between the eyes.
func _can_see(player: Player) -> bool:
	if player == null:
		return false
	if global_position.distance_to(player.global_position) > Balance.ARCHER_RANGE_BL * Balance.BL:
		return false
	var query := PhysicsRayQueryParameters2D.create(_muzzle(), player.global_position,
			Balance.PHYS_WORLD | Balance.PHYS_STATUES)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Turn toward Medusa (and move the glint to the new side).
func _face(player: Player) -> void:
	var dir: int = 1 if player.global_position.x > global_position.x else -1
	if dir != facing:
		set_facing(dir)
		_place_glint()


## Where the arrow leaves the bow, in world space.
func _muzzle() -> Vector2:
	return global_position + Vector2(facing * Balance.ARCHER_MUZZLE.x, Balance.ARCHER_MUZZLE.y)


## The glint sits on the arrowhead. It lives outside Visual (the gaze tints Visual),
## so it is flipped by hand.
func _place_glint() -> void:
	_glint.position = Vector2(facing * Balance.ARCHER_MUZZLE.x, Balance.ARCHER_MUZZLE.y)


## Loose an arrow at where Medusa will be. Flight time comes from the straight-line
## distance and ARROW_SPEED; her horizontal motion over that time is added (scaled by
## ARCHER_LEAD, "slightly"), and the launch velocity cancels gravity's drop over the
## flight: v = d / t - g * t / 2 on y, d / t on x.
func _fire(player: Player) -> void:
	var from: Vector2 = _muzzle()
	var target: Vector2 = player.global_position
	var t: float = from.distance_to(target) / Balance.ARROW_SPEED
	# Two passes: the lead changes the distance, so the flight time shifts a little.
	for i in 2:
		var lead := Vector2(player.velocity.x * t * Balance.ARCHER_LEAD, 0.0)
		t = maxf(from.distance_to(target + lead) / Balance.ARROW_SPEED, 0.05)
		target = player.global_position + lead
	var d: Vector2 = target - from
	var launch := Vector2(d.x / t, d.y / t - 0.5 * Balance.ARROW_GRAVITY * t)
	var arrow: Arrow = ARROW_SCENE.instantiate()
	# The arrow belongs to the level, not the archer, so it outlives him.
	get_parent().add_child(arrow)
	arrow.global_position = from
	arrow.launch(launch)
