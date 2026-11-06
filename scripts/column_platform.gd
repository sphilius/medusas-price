## column_platform.gd (root script of scenes/props/column_platform.tscn)
## Purpose: a ledge on top of a broken column. It is one-way: Medusa jumps up through
## it from below and lands on top (one_way_collision), the classic way to stack a
## climb. The column sprite stands under the slab down to the ground below.
class_name ColumnPlatform
extends TerrainPiece

## How far the column reaches down from the slab's top to the ground (px).
@export var column_height: float = 128.0


## Builds the slab (super._ready), swaps its solid collision for a one-way strip, and
## adds the column underneath.
func _ready() -> void:
	super._ready()
	# The tiles are only the look; the real floor is a one-way strip on top.
	tiles.collision_enabled = false
	var body := StaticBody2D.new()
	body.collision_layer = Balance.PHYS_WORLD
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(size_px().x, Balance.COLUMN_ONE_WAY_THICKNESS)
	shape.shape = rect
	shape.position = Vector2(size_px().x * 0.5, Balance.COLUMN_ONE_WAY_THICKNESS * 0.5)
	# one_way_collision: only blocks bodies moving DOWN onto it from above.
	shape.one_way_collision = true
	body.add_child(shape)
	add_child(body)
	_add_column()


## The broken-column sprite, stretched to reach the ground, centred under the slab and
## drawn behind it (z_index -1 relative to this node).
func _add_column() -> void:
	if not ResourceLoader.exists(Balance.COLUMN_TEXTURE):
		return
	var tex: Texture2D = load(Balance.COLUMN_TEXTURE)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	var reach: float = column_height - size_px().y
	var width: float = minf(size_px().x * 0.6, Balance.COLUMN_WIDTH)
	sprite.scale = Vector2(width / tex.get_width(), reach / tex.get_height())
	sprite.position = Vector2((size_px().x - width) * 0.5, size_px().y)
	sprite.z_index = -1
	add_child(sprite)
	_add_sight_blocker(sprite.position, Vector2(width, reach))


## The column is solid stone to the gaze: an invisible box over the shaft (and the
## slab above it) on the sight-only layer. Bodies never touch it (nothing has that
## layer in its mask); only the gaze's line-of-sight ray stops at it.
func _add_sight_blocker(top_left: Vector2, shaft: Vector2) -> void:
	var blocker := StaticBody2D.new()
	blocker.collision_layer = Balance.PHYS_SIGHT
	blocker.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(shaft.x, shaft.y + size_px().y)
	shape.shape = rect
	shape.position = Vector2(top_left.x + shaft.x * 0.5, (shaft.y + size_px().y) * 0.5)
	blocker.add_child(shape)
	add_child(blocker)
