## shard.gd (root script of scenes/props/shard.tscn)
## Purpose: a hidden pottery shard, the reward for exploring off the main path (a high
## ledge, the far side of a crumbling bridge). It is drawn as a tiny copy of her young
## portrait in a gold rim (so it reads as "a piece of the portrait"), bobbing and
## glinting. Touching it mends SHARD_MEND cracks (PortraitState.mend); if the portrait
## has fewer cracks, the rest becomes gold ward rings around the portrait HUD that take
## the next cracks instead. Logs "shard" to the run ledger. Wordless: the cracks close
## or a gold ring appears around the portrait, right as a sparkle flies into it.
class_name Shard
extends Area2D

var _time: float = 0.0
var _taken: bool = false
## Her youngest portrait (stage 1), drawn small inside the gold rim; null = fallback.
var _face: Texture2D = null


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
	if ResourceLoader.exists(Balance.PORTRAIT_TEXTURES[0]):
		_face = load(Balance.PORTRAIT_TEXTURES[0])


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
	Events.shard_collected.emit(global_position)  # the HUD flies a sparkle to the portrait
	PortraitState.mend(Balance.SHARD_MEND)
	Fx.play(&"shard")
	RunLedger.log_event("shard", {"level": RunLedger.level, "x": global_position.x})
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * 1.8, 0.2)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)


## A tiny portrait medallion in a thick gold rim, with a pulsing glint. Without the
## portrait art: a terracotta fragment with a black band and a gold rim.
func _draw() -> void:
	var bob: float = sin(_time * 3.0) * 4.0
	var r: float = Balance.SHARD_RADIUS
	if _face != null:
		draw_circle(Vector2(0.0, bob), r * 1.25, Balance.COLOR_GOLD)
		draw_texture_rect(_face, Rect2(Vector2(-r, -r + bob), Vector2(r, r) * 2.0), false)
		var shine: float = 0.5 + 0.5 * sin(_time * 5.0)
		draw_circle(Vector2(r * 0.5, -r * 0.6 + bob), 1.5 + shine * 2.0, Balance.COLOR_MARBLE)
		return
	var piece := PackedVector2Array([Vector2(-r, -r * 0.2 + bob), Vector2(-r * 0.3, -r + bob),
			Vector2(r, -r * 0.5 + bob), Vector2(r * 0.6, r * 0.8 + bob), Vector2(-r * 0.5, r * 0.6 + bob)])
	draw_colored_polygon(piece, Balance.COLOR_TERRACOTTA)
	draw_line(Vector2(-r * 0.8, bob), Vector2(r * 0.8, -r * 0.1 + bob), Balance.COLOR_BLACK, 3.0)
	var rim := piece.duplicate()
	rim.append(piece[0])
	draw_polyline(rim, Balance.COLOR_GOLD, 2.0)
	var glint: float = 0.5 + 0.5 * sin(_time * 5.0)
	draw_circle(Vector2(r * 0.4, -r * 0.4 + bob), 2.0 + glint * 2.0, Balance.COLOR_MARBLE)
