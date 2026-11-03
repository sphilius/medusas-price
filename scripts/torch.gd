## torch.gd (root script of scenes/props/torch.tscn)
## Purpose: a wall torch for the torchlight level. A warm PointLight2D that flickers,
## plus a small gold flame shape so it also reads in the editor. Place it where
## the light should be; its origin is the flame.
extends Node2D

@onready var _light: PointLight2D = $Light
@onready var _flame: Polygon2D = $Flame

## Seconds until the flicker picks a new strength.
var _next_flicker: float = 0.0


func _ready() -> void:
	# A soft round light: a radial gradient from white in the middle to clear at the edge.
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1.0, 1.0, 1.0, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	_light.texture = texture
	_light.texture_scale = Balance.TORCH_RADIUS * 2.0 / 256.0
	_light.color = Balance.COLOR_GOLD
	_light.energy = Balance.TORCH_ENERGY
	_flame.color = Balance.COLOR_GOLD
	_flame.polygon = PackedVector2Array([Vector2(-5.0, 0.0), Vector2(0.0, -16.0), Vector2(5.0, 0.0)])


func _process(delta: float) -> void:
	_next_flicker -= delta
	if _next_flicker <= 0.0:
		_next_flicker = 1.0 / Balance.TORCH_FLICKER_RATE
		_light.energy = Balance.TORCH_ENERGY * (1.0 + randf_range(-Balance.TORCH_FLICKER, Balance.TORCH_FLICKER))
