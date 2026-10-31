## game_camera.gd (root script of scenes/game_camera.tscn)
## Purpose: the follow camera. On Events.shake_requested it jitters its offset
## randomly, with the amplitude decaying linearly to zero.
extends Camera2D

## Peak offset (px) of the current shake.
var _strength: float = 0.0
## Total and remaining seconds of the current shake.
var _duration: float = 0.0
var _time_left: float = 0.0


func _ready() -> void:
	Events.shake_requested.connect(_on_shake_requested)


func _process(delta: float) -> void:
	if _time_left <= 0.0:
		return
	_time_left = maxf(_time_left - delta, 0.0)
	var amp: float = _current_amplitude()
	offset = Vector2(randf_range(-amp, amp), randf_range(-amp, amp))


## Strength the shake has decayed to right now.
func _current_amplitude() -> float:
	return _strength * (_time_left / _duration) if _duration > 0.0 else 0.0


## A new shake never weakens one already running.
func _on_shake_requested(strength: float, duration: float) -> void:
	if strength < _current_amplitude():
		return
	_strength = strength
	_duration = duration
	_time_left = duration
