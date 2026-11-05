## mirror_pool.gd (root script of scenes/props/mirror_pool.tscn)
## Purpose: a still pool that heals Medusa once per visit. Kneel in it (hold down) or
## simply stand still in it for Balance.POOL_STAND_TIME: the portrait clears this
## stage's cracks and drops one stage, and the pool becomes her death respawn
## (Events.pool_used). It is spent until she leaves and comes back.
## A death that respawns her inside it does not give her a free heal.
## Place it with its origin at the middle of the basin on the floor surface.
extends Area2D

## Medusa while she is inside the zone, else null.
var _player: Player = null
## Seconds she has stood still on the floor inside the zone.
var _still_time: float = 0.0
## True once healed on this visit.
var _spent: bool = false

@onready var _trigger: CollisionShape2D = $Trigger
@onready var _basin: Polygon2D = $Basin
@onready var _water: Polygon2D = $Water
@onready var _glint: Polygon2D = $Glint
## The painted basin (null if the art is missing; then the polygons draw the pool).
var _art: Sprite2D = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = Balance.PHYS_PLAYER
	monitorable = false
	var half_width: float = Balance.POOL_WIDTH_BL * Balance.BL * 0.5
	var zone := RectangleShape2D.new()
	zone.size = Vector2(half_width * 2.0, Balance.POOL_HEIGHT_BL * Balance.BL)
	_trigger.shape = zone
	_trigger.position = Vector2(0.0, -zone.size.y * 0.5)
	_basin.polygon = _rect(-half_width, 0.0, half_width, Balance.POOL_DEPTH)
	_basin.color = Balance.COLOR_BLACK
	_water.polygon = _rect(-half_width + 4.0, 0.0, half_width - 4.0, Balance.POOL_DEPTH - 3.0)
	_water.color = Balance.COLOR_MARBLE
	_glint.polygon = _rect(-half_width * 0.4, 1.0, half_width * 0.1, 3.0)
	_glint.color = Balance.COLOR_GOLD
	_art = SpriteKit.prop(self, &"pool")
	if _art != null:
		_art.position.y = Balance.POOL_DEPTH
		_basin.visible = false
		_water.visible = false
		move_child(_glint, -1)  # the gold glint stays on top of the painting
	set_physics_process(false)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	Events.player_respawned.connect(_on_player_respawned)
	_apply_visual()


func _physics_process(delta: float) -> void:
	if _spent or _player == null or not is_instance_valid(_player):
		return
	if _player.state == Player.State.DEAD or PortraitState.is_dead:
		return
	if _player.is_on_floor() and _player.state == Player.State.IDLE:
		_still_time += delta
	else:
		_still_time = 0.0
	if _player.is_kneeling() or _still_time >= Balance.POOL_STAND_TIME:
		_heal()


func _heal() -> void:
	_spent = true
	_apply_visual()
	PortraitState.heal_at_pool()
	Events.pool_used.emit(global_position)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player = body as Player
		_still_time = 0.0
		set_physics_process(true)


## Leaving recharges the pool.
func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_player = null
		_still_time = 0.0
		_spent = false
		set_physics_process(false)
		_apply_visual()


## Getting up inside the pool after dying counts as this visit.
func _on_player_respawned(center: Vector2) -> void:
	var local: Vector2 = to_local(center)
	var zone := _trigger.shape as RectangleShape2D
	if absf(local.x) <= zone.size.x * 0.5 and local.y <= 0.0 and local.y >= -zone.size.y:
		_spent = true
		_apply_visual()


## A spent pool goes dull and loses its gold glint.
func _apply_visual() -> void:
	_water.color = Balance.COLOR_MARBLE.darkened(0.45) if _spent else Balance.COLOR_MARBLE
	_glint.visible = not _spent
	if _art != null:
		_art.modulate = Color.WHITE.darkened(Balance.POOL_SPENT_DARKEN) if _spent else Color.WHITE


static func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])
