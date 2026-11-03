## arrow.gd (root script of scenes/projectiles/arrow.tscn)
## Purpose: an archer's arrow. Flies on a ballistic arc (launch velocity + gravity),
## pointing along its motion. Each physics frame it ray-casts the step it is about to
## take, so a fast arrow never tunnels through a thin wall or statue:
##  - hits Medusa: Events.player_hit(1, "arrow") and the arrow is gone;
##  - hits the world or a statue: it sticks in (rides along if the statue is pushed),
##    fades after ARROW_STUCK_TIME, and goes no further, so statues block arrows.
class_name Arrow
extends Node2D

## Current velocity (px/s). Set by the archer through launch().
var velocity: Vector2 = Vector2.ZERO
## Seconds in the air; the arrow is dropped after Balance.ARROW_MAX_FLIGHT.
var _age: float = 0.0
## True once the arrow has stuck into something.
var _stuck: bool = false


## Start the flight from the current position with the given velocity.
func launch(initial_velocity: Vector2) -> void:
	velocity = initial_velocity
	rotation = velocity.angle()


## _physics_process runs every physics tick. While flying: apply gravity, ray-cast the
## step ahead, and either move there or react to what the ray hit.
func _physics_process(delta: float) -> void:
	if _stuck:
		return
	_age += delta
	if _age > Balance.ARROW_MAX_FLIGHT:
		queue_free()
		return
	velocity.y += Balance.ARROW_GRAVITY * delta
	var from: Vector2 = global_position
	var to: Vector2 = from + velocity * delta
	var query := PhysicsRayQueryParameters2D.create(from, to,
			Balance.PHYS_WORLD | Balance.PHYS_STATUES | Balance.PHYS_PLAYER)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		rotation = velocity.angle()
		return
	global_position = hit["position"]
	var collider: Object = hit["collider"]
	if collider is Player:
		Events.player_hit.emit(Balance.CRACKS_HIT, &"arrow", from)
		queue_free()
	else:
		_stick_into(collider as Node2D)


## Stop here. Statues carry the arrow with them; fade out after a while.
func _stick_into(target: Node2D) -> void:
	_stuck = true
	velocity = Vector2.ZERO
	if target is Statue:
		reparent(target, true)
	var fade := create_tween()
	fade.tween_interval(Balance.ARROW_STUCK_TIME)
	fade.tween_property(self, "modulate:a", 0.0, 0.5)
	fade.tween_callback(queue_free)
