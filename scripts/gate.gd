## gate.gd (root script of scenes/props/gate.tscn)
## Purpose: a bronze portcullis that blocks the way until a pressure plate is pressed.
## It slides up while the plate is down and drops again when the plate is released, so
## a statue (or Medusa) has to hold the plate. Wired by `plate`, a path to a
## PressurePlate in the same level; it connects to the plate's pressed/released signals.
## Place its origin at the bottom-left of the opening, on the floor surface.
class_name Gate
extends Node2D

## The plate that opens it (an @export NodePath is set in the level scene).
@export var plate: NodePath
## Height of the opening in 32 px tiles, and its width.
@export var height_tiles: int = 3
@export var width_tiles: int = 1

var is_open: bool = false
var _body: StaticBody2D
var _shape: CollisionShape2D
var _bars: Node2D
var _tween: Tween


## Builds the blocking body and the bar art, then listens to the plate's signals.
func _ready() -> void:
	var size := Vector2(width_tiles, height_tiles) * Balance.TILE_SIZE
	_body = StaticBody2D.new()
	_body.collision_layer = Balance.PHYS_WORLD
	_body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = Vector2(size.x * 0.5, -size.y * 0.5)
	_body.add_child(shape)
	_shape = shape
	add_child(_body)
	_bars = Node2D.new()
	_bars.draw.connect(_draw_bars.bind(size))  # the `draw` signal runs our drawing code
	add_child(_bars)
	_bars.queue_redraw()
	var node: Node = get_node_or_null(plate)
	if node != null and node.has_signal(&"pressed"):
		# connect(): every time the plate emits `pressed`, Godot calls open() here.
		node.connect(&"pressed", open)
		node.connect(&"released", close)


## Slides the bars up; the way is clear as soon as the move starts.
func open() -> void:
	if is_open:
		return
	is_open = true
	# set_deferred: change it after this physics step (a plate signal can fire mid-step).
	_shape.set_deferred("disabled", true)  # collision off
	_slide(-height_tiles * Balance.TILE_SIZE + 8.0)


## Drops the bars again and blocks the way.
func close() -> void:
	if not is_open:
		return
	is_open = false
	_shape.set_deferred("disabled", false)  # collision back on
	_slide(0.0)


## Tweens the bars to `to_y`, cancelling a move still running (kill) so a quick
## press-release-press never leaves two tweens fighting over the bars.
func _slide(to_y: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_bars, "position:y", to_y, Balance.GATE_MOVE_S)


## Black vertical bars with bronze (gold) spikes at the bottom and a top rail.
func _draw_bars(size: Vector2) -> void:
	var count: int = maxi(3, width_tiles * 3)
	var gap: float = size.x / count
	_bars.draw_rect(Rect2(0.0, -size.y, size.x, 6.0), Balance.COLOR_BLACK)
	for i in count:
		var x: float = gap * (i + 0.5)
		_bars.draw_line(Vector2(x, -size.y), Vector2(x, -6.0), Balance.COLOR_BLACK, 4.0)
		_bars.draw_colored_polygon(PackedVector2Array([Vector2(x - 4.0, -8.0), Vector2(x, 0.0), Vector2(x + 4.0, -8.0)]), Balance.COLOR_GOLD)
	_bars.draw_rect(Rect2(0.0, -size.y * 0.5 - 2.0, size.x, 4.0), Balance.COLOR_BLACK)
