## webcam_stare.gd (built in code by GameFlow; not a scene)
## Purpose: the Godot half of webcam stare mode. The browser half lives in
## web/shell.html (window.medusaStare): it watches the player's face with MediaPipe and
## reports "staring" when they widen their eyes. This node turns that into the same
## "gaze" input the K key and the touch gaze button press, so the rest of the game needs
## no changes at all.
## - Opt-in: off until the pause menu's camera button calls toggle().
## - Only in web builds with Features.WEBCAM on; everywhere else available() is false
##   and the camera button is not shown. The gaze key always keeps working.
## - Only presses gaze inside the four levels (GameFlow index 1 to 4), so a stare never
##   skips a story reel or a card.
## JavaScriptBridge is Godot's door to the page's JavaScript: get_interface() returns a
## JavaScript object we can call, and create_callback() wraps a GDScript function so
## JavaScript can call it back (signals across the bridge, no polling).
class_name WebcamStare
extends Node

## Emitted when the mode changes: &"off", &"loading", &"on" or &"failed".
signal state_changed(state: StringName)

## The mode as JavaScript last reported it.
var state: StringName = &"off"
## True while the player is staring (as JavaScript last reported it).
var staring: bool = false

## window.medusaStare, or null outside the browser.
var _js: JavaScriptObject = null
## The callback JavaScript calls. It MUST stay referenced here, or Godot frees it and
## the page would call a dead function.
var _callback: JavaScriptObject = null
## True while this node is holding the gaze action down.
var _pressing: bool = false


## Webcam mode can exist: a web build, the feature on, and a page that has the hook.
static func available() -> bool:
	return Features.WEBCAM and OS.has_feature("web")


## _ready: join the "webcam" group (the pause menu finds us there) and hook up the page.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps listening while the game is paused
	add_to_group(&"webcam")
	set_process(false)
	if not available():
		return
	_js = JavaScriptBridge.get_interface("medusaStare")
	if _js == null or not bool(_js.available):
		_js = null  # an old page or no camera API: stay off quietly
		return
	_callback = JavaScriptBridge.create_callback(_on_js)
	_js.setCallback(_callback)


## True when there is a page to talk to (the pause menu shows its button only then).
func is_ready() -> bool:
	return _js != null


## Switch the mode on (from off or failed) or off (from loading or on).
func toggle() -> void:
	if _js == null:
		return
	if state == &"on" or state == &"loading":
		_js.stop()
	else:
		_js.start(JSON.stringify({
			"delta": Balance.WEBCAM_STARE_DELTA,
			"release": Balance.WEBCAM_RELEASE,
			"calibrate": Balance.WEBCAM_CALIBRATE_S,
			"blink": Balance.WEBCAM_BLINK,
			"hz": Balance.WEBCAM_DETECT_HZ,
			"size": Balance.WEBCAM_PREVIEW_PX,
		}))


## JavaScript calls this with (state, staring) whenever either changes. Callbacks from
## JavaScriptBridge always receive their arguments packed in one Array.
func _on_js(args: Array) -> void:
	var new_state := StringName(str(args[0])) if args.size() > 0 else &"off"
	staring = bool(args[1]) if args.size() > 1 else false
	if new_state != state:
		state = new_state
		state_changed.emit(state)
	_apply()


## Hold or let go of the gaze action to match the stare.
func _apply() -> void:
	var want: bool = staring and state == &"on" and _in_level()
	if want and not _pressing:
		Input.action_press(&"gaze")
	elif not want and _pressing:
		Input.action_release(&"gaze")
	_pressing = want
	# While gaze is held, check each frame that we are still in a level (a scene change
	# to a card must let go); idle otherwise.
	set_process(_pressing)


## While holding gaze: let go as soon as the game leaves the levels.
func _process(_delta: float) -> void:
	if not _in_level():
		_apply()


## Inside the four levels and not paused.
func _in_level() -> bool:
	return GameFlow.current_index >= 1 and GameFlow.current_index <= 4 and not get_tree().paused
