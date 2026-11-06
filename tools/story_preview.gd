## story_preview.gd - dev-only (scene: tools/story_preview.tscn). Plays every story reel
## back to back: the four level-transition reels (Balance.TRANSITION_STORIES, the same way
## GameFlow._transition_reel does) and then the title-card intro (Balance.STORY_PANELS).
## Render it to PNG frames to look at the panels without playing the game:
##   godot --path . --rendering-driver opengl3 --write-movie out.png --fixed-fps 2 res://tools/story_preview.tscn
## Prints each reel as it starts and quits when the last one ends.
extends Node


func _ready() -> void:
	# Dictionary keys come back in insertion order (2, 3, 4, 6).
	for index: int in Balance.TRANSITION_STORIES:
		print("reel for scene %d" % index)
		await _play(Balance.TRANSITION_STORIES[index], false)
	print("intro reel")
	await _play(Balance.STORY_PANELS, true)
	get_tree().quit()


## One reel, built exactly like GameFlow builds it; `await` waits for its `finished`.
func _play(beats: Array, portrait: bool) -> void:
	var reel := StoryReel.new()
	reel.panels = beats
	reel.show_portrait = portrait
	add_child(reel)
	await reel.finished
	reel.queue_free()
