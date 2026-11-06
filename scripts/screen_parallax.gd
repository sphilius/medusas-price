## screen_parallax.gd (built in code by level_base.gd; not a scene)
## Purpose: one background layer drawn in SCREEN space (on a CanvasLayer, so camera
## zoom and height never show a gap under it) that slides sideways at `scroll` x the
## camera's speed: small = far away, larger = nearer. Two kinds:
##   PAINTING  - the level's background painting, its own baked-in top and bottom bands
##               trimmed off, scaled to fill the screen height, repeated sideways.
##   HILLS / SPIRES - a silhouette band along the bottom of the screen (rolling hills by
##               day, jagged rock spires in the cave and storm), made from a few sine
##               waves so it needs no art. Several bands at different speeds = depth.
class_name ScreenParallax
extends Node2D

enum Kind { PAINTING, HILLS, SPIRES }

var kind: Kind = Kind.PAINTING
## Fraction of the camera's sideways motion this layer moves by.
var scroll: float = 0.1
## PAINTING: the texture and the part of it to show (its bands trimmed off).
var texture: Texture2D = null
var region: Rect2 = Rect2()
## HILLS / SPIRES: colour, how tall the band reaches (fraction of screen height), seed.
var color: Color = Color.BLACK
var height: float = 0.3
var seed_value: int = 1

## Width (screen px) after which the layer's pattern repeats.
var _period: float = 1.0
var _screen: Vector2 = Vector2.ZERO


## _ready runs once the layer is in the tree (its properties were set before that):
## work out how wide one repeat is, then ask for a drawing with queue_redraw().
func _ready() -> void:
	_screen = get_viewport_rect().size
	if kind == Kind.PAINTING and texture != null:
		_period = region.size.x * (_screen.y / region.size.y)
	else:
		_period = _screen.x * 2.0
	queue_redraw()


## Follows the camera every frame: position.x is the camera's x times `scroll`, wrapped
## into one period, so the drawing (which covers two periods) always fills the screen.
func _process(_delta: float) -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return
	var x: float = cam.get_screen_center_position().x * scroll
	position.x = -fposmod(x, _period)


## Draws two periods side by side (draw calls happen once; moving the node is free).
func _draw() -> void:
	for i in range(0, ceili(_screen.x / _period) + 2):
		var left: float = i * _period
		if kind == Kind.PAINTING:
			if texture != null:
				draw_texture_rect_region(texture, Rect2(left, 0.0, _period, _screen.y), region)
		else:
			draw_colored_polygon(_band_points(left), color)


## The silhouette outline across one period: a sum of sine waves (seeded, so each band
## differs) for hills, or the same with sharp peaks for spires, closed along the bottom.
func _band_points(left: float) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var waves: Array[Vector3] = []  # (frequency in periods, amplitude, phase)
	for i in 3:
		# Whole numbers of waves per period, so the band joins up seamlessly. Hills use
		# few, broad waves (each finer one weaker); spires use more, for sharp peaks.
		var freq: int = rng.randi_range(1, 2) * (i + 1) if kind == Kind.HILLS else rng.randi_range(2, 4) * (i + 1)
		var amp: float = rng.randf_range(0.5, 1.0) / (i + 1) if kind == Kind.HILLS else rng.randf_range(0.3, 1.0)
		waves.append(Vector3(float(freq), amp, rng.randf() * TAU))
	var points := PackedVector2Array()
	var steps: int = 96
	var top: float = _screen.y * (1.0 - height)
	for s in steps + 1:
		var u: float = float(s) / steps
		var h: float = 0.0
		for w in waves:
			var v: float = sin(u * TAU * w.x + w.z)
			if kind == Kind.SPIRES:
				v = pow(absf(v), 4.0) * 2.0 - 0.6  # narrow, sharp peaks
			h += v * w.y
		points.append(Vector2(left + u * _period, top - h * _screen.y * height * 0.35))
	points.append(Vector2(left + _period, _screen.y))
	points.append(Vector2(left, _screen.y))
	return points
