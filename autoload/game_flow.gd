## game_flow.gd (autoload "GameFlow")
## Purpose: the order of the game and the way between its parts. When Medusa reaches
## a level's exit (Events.level_exit_reached) it fades to black, loads the next scene
## in ORDER, and fades back in. It logs "level_start" and "level_end" (with the seconds
## spent) to RunLedger, and calls RunLedger.start_run() when the intro begins.
## Dev only: in debug builds the number keys 1 to 5 jump straight to a level. In a
## release build that code is switched off (see _ready).
## A scene that is not in ORDER (like the test room) can still be played on its own;
## the flow just stays idle until you reach a scene that is in the list.
extends Node

## The game, in order. The position in this list is the level number RunLedger uses
## (intro 0, temple 1, cliffs 2, cave 3, boss 4, vase 5, ending 6).
const ORDER: Array[String] = [
	"res://scenes/flow/intro.tscn",
	"res://scenes/levels/level_1_temple.tscn",
	"res://scenes/levels/level_2_cliffs.tscn",
	"res://scenes/levels/level_3_cave.tscn",
	"res://scenes/levels/boss.tscn",
	"res://scenes/flow/vase.tscn",
	"res://scenes/flow/ending.tscn",
]
## Names for the ledger (same order as ORDER).
const NAMES: Array[String] = ["intro", "level_1_temple", "level_2_cliffs", "level_3_cave", "boss", "vase", "ending"]

## Index in ORDER of the scene we are in, or -1 for a scene that is not in the list.
var current_index: int = -1

## Ticks (ms) when the current scene started, for the time spent in it.
var _level_start_ms: int = 0
## True while a fade and scene change is running, so a second request is ignored.
var _changing: bool = false
## The black screen drawn over everything, above the HUD.
var _fade: ColorRect


func _ready() -> void:
	# Always run: the fade must keep going even if the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 200
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Balance.COLOR_BLACK
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)
	# A signal is "something happened" announced on the Events bus; connect() makes
	# next_level run every time it is emitted, so no script has to poll for the exit.
	Events.level_exit_reached.connect(next_level)
	# Debug-only level skip. Release builds never listen for the number keys.
	set_process_unhandled_input(OS.is_debug_build())
	# Debug-only performance log: frames per second to the browser console once a
	# second (never on screen). Release builds skip _process entirely.
	set_process(OS.is_debug_build())
	# The first scene is loaded after the autoloads, so look at it next frame.
	_adopt_current_scene.call_deferred()


## Seconds since the last FPS log line (debug builds only).
var _fps_clock: float = 0.0


## Debug builds: print the frame rate once a second (read it in the browser console).
func _process(delta: float) -> void:
	_fps_clock += delta
	if _fps_clock >= 1.0:
		_fps_clock = 0.0
		print("fps %d scene %d" % [Engine.get_frames_per_second(), current_index])


## Go to the next scene in ORDER (after the last one, back to the intro).
func next_level() -> void:
	if current_index < 0:
		return  # not in the flow (test room): nothing comes next
	go_to((current_index + 1) % ORDER.size())


## Fade out, load ORDER[index], fade in. Missing scenes are skipped silently (no popups).
func go_to(index: int) -> void:
	if _changing or index < 0 or index >= ORDER.size():
		return
	if not ResourceLoader.exists(ORDER[index]):
		return
	_changing = true
	_log_level_end()
	# A Tween animates a property over time (here the black screen's alpha 0 -> 1).
	# `await` pauses THIS function until the signal fires, while the game keeps running;
	# that is how the code waits for the fade without freezing anything.
	var out: Tween = create_tween()
	out.tween_property(_fade, "modulate:a", 1.0, Balance.FADE_OUT_S)
	await out.finished
	get_tree().change_scene_to_file(ORDER[index])
	# The new scene is in the tree a frame later.
	await get_tree().process_frame
	await get_tree().process_frame
	_begin_level(index)
	var back: Tween = create_tween()
	back.tween_property(_fade, "modulate:a", 0.0, Balance.FADE_IN_S)
	await back.finished
	_changing = false


## Debug builds: keys 1 to 5 jump to the temple, cliffs, cave, boss and run vase.
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var slot: int = key.keycode - KEY_1  # KEY_1 gives 0 ... KEY_5 gives 4
	if slot >= 0 and slot < 5:
		go_to(slot + 1)  # +1 skips the intro at index 0


## Work out which ORDER entry the starting scene is (F5, or F6 on a level).
func _adopt_current_scene() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var index: int = ORDER.find(scene.scene_file_path)
	if index >= 0:
		_begin_level(index)


## A scene in ORDER is now showing: remember it and log it.
func _begin_level(index: int) -> void:
	current_index = index
	_level_start_ms = Time.get_ticks_msec()
	if index == 0:
		RunLedger.start_run()  # a new run begins at the intro
	RunLedger.set_level(index)
	RunLedger.log_event("level_start", {"level": index, "name": NAMES[index]})


## Write a "level_end" event with how many seconds we spent in this scene. Called just
## before leaving it. Does nothing outside the flow (current_index is -1), so the test
## room never writes half-empty events.
func _log_level_end() -> void:
	if current_index < 0:
		return
	var seconds: float = (Time.get_ticks_msec() - _level_start_ms) / 1000.0
	RunLedger.log_event("level_end", {"level": current_index, "name": NAMES[current_index], "seconds": seconds})
