## fx.gd (autoload "Fx")
## Purpose: game feel. Listens to Events and plays hit-stop, camera shake and
## sounds. The crack sound is a short noise burst baked into an AudioStreamWAV
## in code (no audio files yet, and WAV samples play reliably in the no-threads
## Web build, unlike AudioStreamGenerator).
extends Node

## Plays the crack; pitch is jittered each time so repeats don't sound identical.
var _crack_player: AudioStreamPlayer
## Bumped by every hit_stop(); only the newest one may restore the time scale.
var _stop_id: int = 0


func _ready() -> void:
	# Keep running while the tree is paused or slowed.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_crack_player = AudioStreamPlayer.new()
	_crack_player.stream = _make_crack_stream()
	_crack_player.volume_db = Balance.CRACK_SFX_VOLUME_DB
	add_child(_crack_player)
	Events.petrified.connect(_on_petrified)


## Freeze the game for `duration` real seconds. Overlapping calls extend the stop.
func hit_stop(duration: float) -> void:
	_stop_id += 1
	var my_id: int = _stop_id
	Engine.time_scale = Balance.HITSTOP_TIME_SCALE
	# ignore_time_scale = true, so the timer itself is not slowed by the stop.
	await get_tree().create_timer(duration, true, false, true).timeout
	if my_id == _stop_id:
		Engine.time_scale = 1.0


## Play the placeholder stone-crack sound.
func play_crack() -> void:
	_crack_player.pitch_scale = 1.0 + randf_range(-Balance.CRACK_SFX_PITCH_JITTER, Balance.CRACK_SFX_PITCH_JITTER)
	_crack_player.play()


func _on_petrified(_enemy_type: StringName, _pose_frame: int, _flip: bool, _position: Vector2) -> void:
	play_crack()
	Events.shake_requested.emit(Balance.SHAKE_PETRIFY_PX, Balance.SHAKE_PETRIFY_TIME)
	hit_stop(Balance.HITSTOP_DURATION)


## Bake a mono 16-bit crack: white noise plus a low sine "thunk", both decaying fast.
func _make_crack_stream() -> AudioStreamWAV:
	var rate: int = Balance.CRACK_SFX_MIX_RATE
	var count: int = int(Balance.CRACK_SFX_LENGTH * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t: float = float(i) / rate
		var env: float = exp(-t * Balance.CRACK_SFX_DECAY)
		var noise: float = randf_range(-1.0, 1.0) * Balance.CRACK_SFX_NOISE_MIX
		var thunk: float = sin(TAU * Balance.CRACK_SFX_THUNK_HZ * t) * Balance.CRACK_SFX_THUNK_MIX
		var sample: float = clampf((noise + thunk) * env, -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
