## shard.gd (root script of scenes/props/shard.tscn)
## Purpose: a hidden pottery shard, the reward for exploring off the main path (a high
## ledge, the far side of a crumbling bridge). It bobs and glints gold; touching it
## mends one crack of the portrait (PortraitState.mend) and logs "shard" to the run
## ledger. Wordless: the reward is the crack visibly closing on the portrait.
class_name Shard
extends Area2D

var _time: float = 0.0
var _taken: bool = false


## A small round pickup zone that notices only Medusa.
func _ready() -> void:
	collision_layer = 0
	collision_mask = Balance.PHYS_PLAYER
	monitorable = false
	var zone := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = Balance.SHARD_RADIUS
	zone.shape = circle
	add_child(zone)
	# body_entered is a signal Area2D emits when a body walks in; connect() hooks it up.
	body_entered.connect(_on_body_entered)


## Bob up and down (sin over time) and redraw the glint.
func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## Medusa touched it: mend a crack once, log it, then a quick grow-and-fade and gone.
## tween_callback(queue_free) removes the node when the animation ends.
func _on_body_entered(body: Node2D) -> void:
	if _taken or not body is Player:
		return
	_taken = true
	PortraitState.mend(1)
	RunLedger.log_event("shard", {"level": RunLedger.level, "x": global_position.x})
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * 1.8, 0.2)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)


## A terracotta fragment with a black band and a gold rim, plus a pulsing glint.
func _draw() -> void:
	var bob: float = sin(_time * 3.0) * 4.0
	var r: float = Balance.SHARD_RADIUS
	var piece := PackedVector2Array([Vector2(-r, -r * 0.2 + bob), Vector2(-r * 0.3, -r + bob),
			Vector2(r, -r * 0.5 + bob), Vector2(r * 0.6, r * 0.8 + bob), Vector2(-r * 0.5, r * 0.6 + bob)])
	draw_colored_polygon(piece, Balance.COLOR_TERRACOTTA)
	draw_line(Vector2(-r * 0.8, bob), Vector2(r * 0.8, -r * 0.1 + bob), Balance.COLOR_BLACK, 3.0)
	var rim := piece.duplicate()
	rim.append(piece[0])
	draw_polyline(rim, Balance.COLOR_GOLD, 2.0)
	var glint: float = 0.5 + 0.5 * sin(_time * 5.0)
	draw_circle(Vector2(r * 0.4, -r * 0.4 + bob), 2.0 + glint * 2.0, Balance.COLOR_MARBLE)
