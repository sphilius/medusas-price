## fx.gd (autoload "Fx")
## Purpose: game feel. Listens to Events and plays hit-stop, camera shake and
## sounds. The sounds are CC0 recordings from Freesound in audio/sfx/ (listed in
## Balance.SFX_FILES, credited in audio/CREDITS.md), played by play(name). If a file is
## missing, the old code-made placeholders (crack, grind, thud, shatter, baked into
## AudioStreamWAVs) still play, so the game never goes silent or errors.
extends Node

## Looping stone-on-stone grind. Each Statue plays it on its own player while sliding.
var grind_stream: AudioStream

## One player per recorded sound, by name (see Balance.SFX_FILES).
var _sfx: Dictionary = {}

## Plays the crack; pitch is jittered each time so repeats don't sound identical.
var _crack_player: AudioStreamPlayer
## Plays the statue thud (higher pitch for a slide stopping, full for a landing).
var _thud_player: AudioStreamPlayer
## Plays the shatter when a cracked statue breaks.
var _shatter_player: AudioStreamPlayer
## Bumped by every hit_stop(); only the newest one may restore the time scale.
var _stop_id: int = 0


func _ready() -> void:
	# Keep running while the tree is paused or slowed.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_sfx()
	grind_stream = _make_grind_stream()
	if _sfx.has(&"grind_loop"):
		var grind: AudioStreamOggVorbis = (_sfx[&"grind_loop"] as AudioStreamPlayer).stream.duplicate()
		grind.loop = true
		grind_stream = grind
	_crack_player = _add_player(_make_crack_stream(), Balance.CRACK_SFX_VOLUME_DB)
	_thud_player = _add_player(_make_thud_stream(), Balance.THUD_SFX_VOLUME_DB)
	_shatter_player = _add_player(_make_shatter_stream(), Balance.SHATTER_SFX_VOLUME_DB)
	Events.petrified.connect(_on_petrified)
	Events.statue_thud.connect(_on_statue_thud)
	Events.statue_cracked.connect(_on_statue_cracked)
	Events.statue_shattered.connect(_on_statue_shattered)
	# More events that only need a sound: connect() with a lambda (an inline func).
	Events.player_hit.connect(func(_c: int, _s: StringName, _p: Vector2) -> void: play(&"crack_portrait"))
	Events.gaze_reflected.connect(func(_t: StringName, _p: Vector2) -> void: play(&"reflect"))
	Events.pool_used.connect(func(_p: Vector2) -> void: play(&"pool"))
	Events.player_died.connect(func(_p: Vector2) -> void: play(&"petrify", Balance.SFX_DEATH_PITCH))


## Make one AudioStreamPlayer per sound file that exists. max_polyphony lets the same
## sound overlap itself (three quick whips) instead of cutting itself off.
func _load_sfx() -> void:
	for sound_name: StringName in Balance.SFX_FILES:
		var path: String = Balance.SFX_FILES[sound_name]
		if not ResourceLoader.exists(path):
			continue
		var player := _add_player(load(path), Balance.SFX_VOLUME_DB.get(sound_name, 0.0))
		player.max_polyphony = Balance.SFX_POLYPHONY
		_sfx[sound_name] = player


## Play a recorded sound by name, with a little random pitch so repeats don't sound
## identical. Returns false if that sound has no file (the caller may use a fallback).
func play(sound_name: StringName, pitch: float = 1.0) -> bool:
	var player: AudioStreamPlayer = _sfx.get(sound_name)
	if player == null:
		return false
	player.pitch_scale = pitch * (1.0 + randf_range(-Balance.SFX_PITCH_JITTER, Balance.SFX_PITCH_JITTER))
	player.play()
	return true


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
	if not play(&"petrify"):
		play_crack()
	Events.shake_requested.emit(Balance.SHAKE_PETRIFY_PX, Balance.SHAKE_PETRIFY_TIME)
	hit_stop(Balance.HITSTOP_DURATION)


func _on_statue_thud(_position: Vector2, landed: bool) -> void:
	var pitch: float = 1.0 if landed else Balance.THUD_SFX_STOP_PITCH
	if not play(&"statue_thud", pitch):
		_thud_player.pitch_scale = pitch
		_thud_player.play()
	if landed:
		Events.shake_requested.emit(Balance.SHAKE_STATUE_LAND_PX, Balance.SHAKE_STATUE_LAND_TIME)


## A statue cracked: the same crack as a petrify, but lower and heavier.
func _on_statue_cracked(_enemy_type: StringName, _position: Vector2) -> void:
	if play(&"statue_crack"):
		return
	_crack_player.pitch_scale = Balance.STATUE_CRACK_SFX_PITCH + randf_range(-Balance.CRACK_SFX_PITCH_JITTER, Balance.CRACK_SFX_PITCH_JITTER)
	_crack_player.play()


func _on_statue_shattered(_enemy_type: StringName, _position: Vector2) -> void:
	if not play(&"statue_shatter"):
		_shatter_player.play()


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


## Shatter: a long noise burst over a low rumble, both dying away slowly.
func _make_shatter_stream() -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	samples.resize(int(Balance.SHATTER_SFX_LENGTH * Balance.SFX_MIX_RATE))
	for i in samples.size():
		var t: float = float(i) / Balance.SFX_MIX_RATE
		var noise: float = randf_range(-1.0, 1.0) * Balance.SHATTER_SFX_NOISE_MIX
		var rumble: float = sin(TAU * Balance.SHATTER_SFX_RUMBLE_HZ * t) * Balance.SHATTER_SFX_RUMBLE_MIX
		samples[i] = (noise + rumble) * exp(-t * Balance.SHATTER_SFX_DECAY)
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
