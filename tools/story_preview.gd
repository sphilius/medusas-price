## story_preview.gd - dev-only: plays the story reel on its own so it can be recorded
## with Godot's movie writer (--write-movie). Quits when the reel ends.
extends Node


func _ready() -> void:
	var reel := StoryReel.new()
	reel.finished.connect(get_tree().quit)
	add_child(reel)
