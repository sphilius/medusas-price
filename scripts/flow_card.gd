## flow_card.gd (root script of scenes/flow/intro.tscn and scenes/flow/ending.tscn)
## Purpose: the title and ending screens. Each shows its painted card (`art`), the
## title card also the game logo (`logo`, the only text the rules allow), and waits
## for any button, key or touch; then GameFlow moves on (the intro goes to level 1,
## the ending goes back to the intro). If the art is missing, a wordless marble eye
## drawn from polygons is shown instead.
extends Node2D

## The full-screen painting (1280 x 720). Set in the scene's Inspector.
@export_file("*.png") var art: String = ""
## Optional logo drawn over the painting's empty left half (title card only).
@export_file("*.png") var logo: String = ""

## Where the eye sits on the 1280 x 720 screen.
const CENTER: Vector2 = Vector2(640.0, 360.0)

## Seconds to ignore input after the card appears, so the press that ended the
## previous scene cannot skip this one.
const INPUT_DELAY_S: float = 0.5

## Seconds since the card appeared.
var _age: float = 0.0

## The title card sets this in intro.tscn: the first key press plays the story reel
## (scripts/story_reel.gd) before level 1 instead of going straight there.
@export var play_story: bool = false
var _story_started: bool = false


func _ready() -> void:
	if _add_art():
		return
	# Fallback eye: a marble almond with a gold iris and a black pupil, built from polygons.
	_add_shape(_almond(220.0, 90.0), Balance.COLOR_MARBLE)
	_add_shape(_almond(60.0, 60.0), Balance.COLOR_GOLD)
	_add_shape(_almond(18.0, 40.0), Balance.COLOR_BLACK)


## _process runs every frame; here it only counts up the card's age.
func _process(delta: float) -> void:
	_age += delta


## Any key, button or touch moves on. _unhandled_input only sees input nothing else used.
func _unhandled_input(event: InputEvent) -> void:
	if _age < INPUT_DELAY_S or not event.is_pressed() or event.is_echo() or _story_started:
		return
	if play_story:
		# Play the reel; its `finished` signal (connect) moves on to level 1.
		_story_started = true
		var reel := StoryReel.new()
		reel.finished.connect(GameFlow.next_level)
		add_child(reel)
		return
	GameFlow.next_level()


## Show the painted card (and the logo, if any). Returns false if the painting is
## missing, so _ready can draw the fallback eye instead.
func _add_art() -> bool:
	if art == "" or not ResourceLoader.exists(art):
		return false
	var card := Sprite2D.new()
	card.texture = load(art) as Texture2D
	card.centered = false
	add_child(card)
	if logo != "" and ResourceLoader.exists(logo):
		var mark := Sprite2D.new()
		mark.texture = load(logo) as Texture2D
		mark.position = Balance.CARD_LOGO_CENTER
		mark.scale = Vector2.ONE * (Balance.CARD_LOGO_WIDTH / mark.texture.get_width())
		add_child(mark)
	return true


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
