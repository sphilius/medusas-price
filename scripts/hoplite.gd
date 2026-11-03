## hoplite.gd (root script of scenes/enemies/hoplite.tscn)
## Purpose: the spear soldier. Patrols its ledge; notices the player within
## HOPLITE_NOTICE_BL on the same level, walks toward her, and at spear range
## winds up (spear drawn back, gold glint) then thrusts. A thrust that touches
## the player emits Events.player_hit(1, "hoplite"). Never walks off a ledge.
## His body blocks her, and touching it hurts too (Enemy.check_contact).
extends Enemy

enum State { PATROL, CHASE, WINDUP, THRUST, RECOVER }

var state: State = State.PATROL
## Patrol center (spawn x).
var _home_x: float = 0.0
## Seconds left in the current WINDUP / THRUST / RECOVER.
var _timer: float = 0.0
## True once this thrust has struck (one hit per thrust).
var _struck: bool = false
## Spear slide along its length (px): 0 resting, negative drawn back, positive thrust.
var _spear_offset: float = 0.0

@onready var _spear: Node2D = $Visual/Spear
@onready var _glint: Polygon2D = $Glint
@onready var _hitbox: Area2D = $SpearHitbox
@onready var _hitbox_shape: CollisionShape2D = $SpearHitbox/Shape


func _ready() -> void:
	super._ready()
	_home_x = position.x
	_glint.color = Balance.COLOR_GOLD
	_glint.scale = Vector2.ONE * (Balance.HOPLITE_GLINT_SIZE / Balance.HOPLITE_GLINT_ART_RADIUS)
	_glint.visible = false
	var shape := RectangleShape2D.new()
	shape.size = Vector2(_reach() - Balance.ENEMY_HALF_WIDTH, Balance.HOPLITE_HITBOX_THICKNESS)
	_hitbox_shape.shape = shape
	_hitbox.position.x = facing * (Balance.ENEMY_HALF_WIDTH + shape.size.x * 0.5)
	_place_spear(0.0)


func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	if tick_stagger(delta):
		move_and_slide()
		return
	match state:
		State.PATROL: _patrol()
		State.CHASE: _chase()
		State.WINDUP: _windup(delta)
		State.THRUST: _thrust(delta)
		State.RECOVER: _recover(delta)
	move_and_slide()
	check_contact()


func _patrol() -> void:
	if _notices(find_player()):
		state = State.CHASE
		return
	var limit: float = Balance.HOPLITE_PATROL_BL * Balance.BL
	if is_on_wall() or ledge_ahead(facing):
		set_facing(-facing)
	elif facing > 0 and position.x > _home_x + limit:
		set_facing(-1)
	elif facing < 0 and position.x < _home_x - limit:
		set_facing(1)
	velocity.x = facing * Balance.HOPLITE_PATROL_SPEED


func _chase() -> void:
	var player: Player = find_player()
	if not _notices(player):
		velocity.x = 0.0
		state = State.PATROL
		return
	var dx: float = player.global_position.x - global_position.x
	set_facing(1 if dx > 0.0 else -1)
	if absf(dx) <= _reach():
		velocity.x = 0.0
		state = State.WINDUP
		_timer = Balance.HOPLITE_WINDUP
		_glint.visible = true
		_place_spear(-Balance.HOPLITE_SPEAR_DRAW_BACK)
	elif ledge_ahead(facing) or is_on_wall():
		velocity.x = 0.0
	else:
		velocity.x = facing * Balance.HOPLITE_CHASE_SPEED


func _windup(delta: float) -> void:
	velocity.x = 0.0
	_timer -= delta
	if _timer <= 0.0:
		state = State.THRUST
		_timer = Balance.HOPLITE_THRUST_ACTIVE
		_struck = false
		_place_spear(_reach() - Balance.ENEMY_HALF_WIDTH * 2.0)


func _thrust(delta: float) -> void:
	velocity.x = 0.0
	_timer -= delta
	if not _struck:
		for body in _hitbox.get_overlapping_bodies():
			if body is Player:
				_struck = true
				Events.player_hit.emit(Balance.CRACKS_HIT, &"hoplite", global_position)
				break
	if _timer <= 0.0:
		state = State.RECOVER
		_timer = Balance.HOPLITE_RECOVERY
		_glint.visible = false
		_place_spear(0.0)


func _recover(delta: float) -> void:
	velocity.x = 0.0
	_timer -= delta
	if _timer <= 0.0:
		state = State.CHASE


## A whip hit breaks the attack: no glint, spear back at rest, and once the
## stagger ends he goes back to chasing (a wind-up has to start over).
func _on_staggered() -> void:
	if state in [State.WINDUP, State.THRUST, State.RECOVER]:
		state = State.CHASE
	_glint.visible = false
	_place_spear(0.0)


## Spear reach in px.
func _reach() -> float:
	return Balance.HOPLITE_SPEAR_REACH_BL * Balance.BL


## Player within notice range on roughly the same level.
func _notices(player: Player) -> bool:
	if player == null:
		return false
	var d: Vector2 = player.global_position - global_position
	return absf(d.x) <= Balance.HOPLITE_NOTICE_BL * Balance.BL \
			and absf(d.y) <= Balance.HOPLITE_LEVEL_SLACK_BL * Balance.BL


## Slide the spear along its length and put the glint on its tip. The glint
## lives outside Visual (the gaze tints Visual), so it is flipped by hand.
func _place_spear(offset: float) -> void:
	_spear_offset = offset
	_spear.position.x = offset
	_glint.position = Vector2(facing * (Balance.HOPLITE_SPEAR_TIP_X + offset), _spear.position.y)


func set_facing(dir: int) -> void:
	super.set_facing(dir)
	_hitbox.position.x = dir * absf(_hitbox.position.x)
	if _glint != null:
		_place_spear(_spear_offset)
