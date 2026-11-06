## museum_preview.gd - dev-only (scene: tools/museum_preview.tscn).
## Fakes a run (a few petrified enemies, portrait at stage 3) by emitting the same
## Events.petrified signal the game uses, then opens the museum, to check it by eye.
extends Node


## Emit fake petrifications, age the portrait, then load the museum as a child.
func _ready() -> void:
	RunLedger.start_run()
	var types: Array[StringName] = [&"hoplite", &"archer", &"leaper", &"mirror_bearer", &"eye_shading", &"hoplite"]
	for i in types.size():
		Events.petrified.emit(types[i], i % 4, i % 2 == 0, Vector2(i * 100.0, 0.0))
	PortraitState.stage = 3
	add_child(load("res://scenes/flow/museum.tscn").instantiate())
