## fx.gd (autoload "Fx")
## Purpose: game feel. Listens to Events and plays hit-stop, camera shake and
## sounds. Placeholder sounds (crack, statue grind loop, thud) are baked into
## AudioStreamWAVs in code: no audio files yet, and WAV samples play reliably in
## the no-threads Web build, unlike AudioStreamGenerator.
extends Node

## Looping stone-on-stone grind. Each Statue plays it on its own player while sliding.
var grind_stream: AudioStreamWAV

## Plays the crack; pitch is jittered each time so repeats don't sound identical.
var _crack_player: AudioStreamPlayer
## Plays the statue thud (higher pitch for a slide stopping, full for a landing).
var _thud_player: AudioStreamPlayer
## Bumped by every hit_stop(); only the newest one may restore the time scale.
var _stop_id: int = 0


func _ready() -> void:
	# Keep running while the tree is paused or slowed.
	process_mode = Node.PROCESS_MODE_ALWAYS
	grind_stream = _make_grind_stream()
	_crack_player = _add_player(_make_crack_stream(), Balance.CRACK_SFX_VOLUME_DB)
	_thud_player = _add_player(_make_thud_stream(), Balance.THUD_SFX_VOLUME_DB)
	Events.petrified.connect(_on_petrified)
	Events.statue_thud.connect(_on_statue_thud)


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


func _on_statue_thud(_position: Vector2, landed: bool) -> void:
	_thud_player.pitch_scale = 1.0 if landed else Balance.THUD_SFX_STOP_PITCH
	_thud_player.play()
	if landed:
		Events.shake_requested.emit(Balance.SHAKE_STATUE_LAND_PX, Balance.SHAKE_STATUE_LAND_TIME)


func _add_player(stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	return player


## Crack: white noise plus a low sine "thunk", both decaying fast.
func _make_crack_stream() -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	samples.resize(int(Balance.CRACK_SFX_LENGTH * Balance.SFX_MIX_RATE))
	for i in samples.size():
		var t: float = float(i) / Balance.SFX_MIX_RATE
		var noise: float = randf_range(-1.0, 1.0) * Balance.CRACK_SFX_NOISE_MIX
		var thunk: float = sin(TAU * Balance.CRACK_SFX_THUNK_HZ * t) * Balance.CRACK_SFX_THUNK_MIX
		samples[i] = (noise + thunk) * exp(-t * Balance.CRACK_SFX_DECAY)
	return _bake(samples)


## Grind: low-passed noise (a dull rumble), looped forever.
func _make_grind_stream() -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	samples.resize(int(Balance.GRIND_SFX_LENGTH * Balance.SFX_MIX_RATE))
	var smooth: float = 0.0
	for i in samples.size():
		smooth = lerpf(randf_range(-1.0, 1.0), smooth, Balance.GRIND_SFX_SMOOTH)
		samples[i] = smooth * Balance.GRIND_SFX_GAIN
	var wav: AudioStreamWAV = _bake(samples)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = samples.size()
	return wav


## Thud: a low sine that dies away.
func _make_thud_stream() -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	samples.resize(int(Balance.THUD_SFX_LENGTH * Balance.SFX_MIX_RATE))
	for i in samples.size():
		var t: float = float(i) / Balance.SFX_MIX_RATE
		samples[i] = sin(TAU * Balance.THUD_SFX_HZ * t) * exp(-t * Balance.THUD_SFX_DECAY)
	return _bake(samples)


## Pack -1..1 floats into a mono 16-bit AudioStreamWAV (values are clamped).
func _bake(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = Balance.SFX_MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
