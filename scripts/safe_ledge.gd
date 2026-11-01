## safe_ledge.gd (root script of scenes/props/safe_ledge.tscn)
## Purpose: a marker on solid ground. When Medusa touches it, it becomes the place a
## pit fall puts her back (Events.safe_ledge_reached). The flag turns marble white on
## the ledge she last touched and terracotta on the rest.
## Place it with its origin on the floor surface; the trigger rises above that point.
extends Area2D

@onready var _trigger: CollisionShape2D = $Trigger
@onready var _pole: Polygon2D = $Pole
@onready var _flag: Polygon2D = $Flag


func _ready() -> void:
	collision_layer = 0
	collision_mask = Balance.PHYS_PLAYER
	monitorable = false
	var zone := RectangleShape2D.new()
	zone.size = Vector2(Balance.SAFE_LEDGE_WIDTH_BL * Balance.BL, Balance.SAFE_LEDGE_HEIGHT_BL * Balance.BL)
	_trigger.shape = zone
	_trigger.position = Vector2(0.0, -zone.size.y * 0.5)
	var pole_height: float = Balance.SAFE_LEDGE_POLE_HEIGHT
	var flag: float = Balance.SAFE_LEDGE_FLAG_SIZE
	_pole.polygon = PackedVector2Array([Vector2(-1.5, -pole_height), Vector2(1.5, -pole_height), Vector2(1.5, 0.0), Vector2(-1.5, 0.0)])
	_pole.color = Balance.COLOR_MARBLE
	_flag.polygon = PackedVector2Array([Vector2(1.5, -pole_height), Vector2(1.5 + flag, -pole_height + flag * 0.5), Vector2(1.5, -pole_height + flag)])
	_flag.color = Balance.COLOR_TERRACOTTA
	body_entered.connect(_on_body_entered)
	Events.safe_ledge_reached.connect(_on_safe_ledge_reached)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		Events.safe_ledge_reached.emit(global_position)


## Only the ledge she touched last shows the marble flag.
func _on_safe_ledge_reached(floor_point: Vector2) -> void:
	_flag.color = Balance.COLOR_MARBLE if floor_point.is_equal_approx(global_position) else Balance.COLOR_TERRACOTTA
