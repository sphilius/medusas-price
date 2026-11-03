## flow_card.gd (root script of scenes/flow/intro.tscn and scenes/flow/ending.tscn)
## Purpose: placeholder title and ending screens. They show a wordless marble eye
## (no text anywhere) and wait for any button, key or touch; then GameFlow moves on
## (the intro goes to level 1, the ending goes back to the intro).
## Replace the art later; keep this script so the flow keeps working.
extends Node2D

## Where the eye sits on the 1280 x 720 screen.
const CENTER: Vector2 = Vector2(640.0, 360.0)

## Seconds to ignore input after the card appears, so the press that ended the
## previous scene cannot skip this one.
const INPUT_DELAY_S: float = 0.5

## Seconds since the card appeared.
var _age: float = 0.0


func _ready() -> void:
	# The eye: a marble almond with a gold iris and a black pupil, built from polygons.
	_add_shape(_almond(220.0, 90.0), Balance.COLOR_MARBLE)
	_add_shape(_almond(60.0, 60.0), Balance.COLOR_GOLD)
	_add_shape(_almond(18.0, 40.0), Balance.COLOR_BLACK)


## _process runs every frame; here it only counts up the card's age.
func _process(delta: float) -> void:
	_age += delta


## Any key, button or touch moves on. _unhandled_input only sees input nothing else used.
func _unhandled_input(event: InputEvent) -> void:
	if _age < INPUT_DELAY_S or not event.is_pressed() or event.is_echo():
		return
	GameFlow.next_level()


## A pointed oval of half-width `w` and half-height `h`, as polygon points.
func _almond(w: float, h: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 24:
		var angle: float = TAU * i / 24.0
		# Squash the top and bottom toward the corners so the ends come to a point.
		points.append(Vector2(cos(angle) * w, sin(angle) * h * (1.0 - 0.35 * absf(cos(angle)))))
	return points


## Add one filled shape to the card. A Polygon2D is a node that draws a filled polygon;
## add_child() puts it in the scene tree so it gets drawn. Shapes added later draw on
## top of earlier ones, which is why the eye is built big to small.
func _add_shape(points: PackedVector2Array, color: Color) -> void:
	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color = color
	poly.position = CENTER
	add_child(poly)
