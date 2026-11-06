## level_overview.gd - dev-only: renders a zoomed-out picture of a whole level so its
## layout can be checked by eye. Not headless (it needs to draw). Run with Godot's movie
## writer, which saves each rendered frame as a PNG:
##   godot --path . --write-movie out.png --quit-after 8 res://tools/level_overview.tscn -- <level>
extends Node


## Loads the level named on the command line and frames all its terrain with one camera.
func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var level: Node2D = load("res://scenes/levels/%s.tscn" % args[0]).instantiate()
	add_child(level)
	await get_tree().process_frame
	var used: Rect2i = level.get_node("Terrain").get_used_rect()
	var rect := Rect2(Vector2(used.position) * 32.0, Vector2(used.size) * 32.0)  # cells -> px
	rect = rect.grow_individual(0, 0, 0, -320)  # skip the deep fill under the view
	var cam := Camera2D.new()
	var view: Vector2 = get_viewport().get_visible_rect().size
	var z: float = minf(view.x / rect.size.x, view.y / rect.size.y)
	cam.zoom = Vector2(z, z)
	cam.position = rect.get_center()
	add_child(cam)
	cam.make_current()
	print("overview rect ", rect, " zoom ", z)
