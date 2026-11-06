## game_camera.gd (root script of scenes/game_camera.tscn)
## Purpose: the follow camera. It leans a little ahead in the direction Medusa faces
## (look-ahead, eased), and on Events.shake_requested it jitters on top of that, the
## jitter decaying linearly to zero.
extends Camera2D

## Peak offset (px) of the current shake.
var _strength: float = 0.0
## Total and remaining seconds of the current shake.
var _duration: float = 0.0
var _time_left: float = 0.0


func _ready() -> void:
	Events.shake_requested.connect(_on_shake_requested)


## Eased look-ahead offset (px), added under the shake.
var _look: Vector2 = Vector2.ZERO


func _process(delta: float) -> void:
	var player := get_parent() as Player
	if player != null:
		var target := Vector2(player.facing * Balance.CAMERA_LOOKAHEAD_PX, 0.0)
		_look = _look.lerp(target, minf(Balance.CAMERA_LOOKAHEAD_EASE * delta, 1.0))
	var jitter := Vector2.ZERO
	if _time_left > 0.0:
		_time_left = maxf(_time_left - delta, 0.0)
		var amp: float = _current_amplitude()
		jitter = Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
	offset = _look + jitter


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
