## gaze.gd (root script of scenes/gaze.tscn, instanced under the Player)
## Purpose: Medusa's petrifying gaze. While the player is in State.GAZE it shows
## the gold cone, and every enemy inside it with a clear line of sight gains
## petrify progress. Leaving the cone, a blocked view or letting go resets it.
## The cone is an Area2D on the gaze layer that only sees enemies; walls and
## statues block it through a raycast (Balance.GAZE_LOS_MASK).
extends Area2D

## Enemies currently overlapping the cone (kept by body_entered / body_exited).
var _in_cone: Array[Enemy] = []

@onready var _player: Player = get_parent()
@onready var _shape: CollisionPolygon2D = $Shape
@onready var _cone: Polygon2D = $Cone


func _ready() -> void:
	position = Balance.GAZE_EYE_OFFSET
	var points: PackedVector2Array = _build_cone()
	_shape.polygon = points
	_cone.polygon = points
	_cone.color = Color(Balance.COLOR_GOLD, Balance.GAZE_CONE_ALPHA)
	_cone.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	# The cone is symmetric, so turning it half a circle mirrors it (no negative scale on physics shapes).
	rotation = 0.0 if _player.facing > 0 else PI
	var active: bool = _player.state == Player.State.GAZE
	_cone.visible = active
	for enemy in _in_cone.duplicate():
		if not is_instance_valid(enemy):
			_in_cone.erase(enemy)
		elif active and _has_line_of_sight(enemy):
			enemy.add_gaze(delta)
		else:
			enemy.reset_gaze()


## Fan polygon: the eye, then an arc at cone length from -half-angle to +half-angle.
func _build_cone() -> PackedVector2Array:
	var points := PackedVector2Array([Vector2.ZERO])
	var radius: float = Balance.GAZE_LENGTH_BL * Balance.BL
	var half: float = deg_to_rad(Balance.GAZE_HALF_ANGLE_DEG)
	for i in Balance.GAZE_ARC_SEGMENTS + 1:
		var angle: float = lerpf(-half, half, float(i) / Balance.GAZE_ARC_SEGMENTS)
		points.append(Vector2.from_angle(angle) * radius)
	return points


## True if nothing on the LOS layers sits between the eye and the enemy's center.
func _has_line_of_sight(enemy: Enemy) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, enemy.global_position, Balance.GAZE_LOS_MASK)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _on_body_entered(body: Node2D) -> void:
	if body is Enemy and not _in_cone.has(body):
		_in_cone.append(body)


func _on_body_exited(body: Node2D) -> void:
	if body is Enemy:
		_in_cone.erase(body)
		(body as Enemy).reset_gaze()
