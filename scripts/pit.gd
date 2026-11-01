## pit.gd (root script of scenes/props/pit.tscn)
## Purpose: a kill zone under a gap. When Medusa drops into it, it announces
## Events.player_fell and she answers (one crack, back to the last safe ledge). It is
## invisible; the empty space is the art. Enemies and statues that fall are cleaned up
## by their own scripts, this zone only looks for the player.
## Place it with its origin at the middle of the zone's top edge, below the floor level.
extends Area2D

## Zone size in px. Zero means Balance.PIT_WIDTH_BL x PIT_HEIGHT_BL.
@export var size: Vector2 = Vector2.ZERO

@onready var _trigger: CollisionShape2D = $Trigger


func _ready() -> void:
	collision_layer = 0
	collision_mask = Balance.PHYS_PLAYER
	monitorable = false
	var zone := RectangleShape2D.new()
	zone.size = size if size != Vector2.ZERO else Vector2(Balance.PIT_WIDTH_BL, Balance.PIT_HEIGHT_BL) * Balance.BL
	_trigger.shape = zone
	_trigger.position = Vector2(0.0, zone.size.y * 0.5)
	body_entered.connect(_on_body_entered)


# Overlap signals fire while physics is flushing and the reaction moves the player,
# so answer a moment later.
func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		Events.player_fell.emit.call_deferred(body.global_position)
