## music.gd (autoload "Music")
## Purpose: the adaptive score. Five loops, one per portrait stage (audio/music/
## stage_1..stage_5.ogg, made with ElevenLabs from the briefs in docs/audio/
## lyria_prompts.md and converted by tools/build_music.py), plus a boss and an ending
## track. Only the track for where we are plays; a change (portrait stage, pool,
## new level, boss, ending) crossfades over MUSIC_FADE_S: the new track starts from its
## beginning and rises while the old one sinks and then stops. The tracks differ in
## length, so they cannot be kept in step; starting fresh on each change sounds like a
## new movement of the score instead. Missing files are skipped silently: with none at
## all the game is simply quiet; with only stage_1 that one loop plays throughout.
extends Node

## One player per stage loop that exists (index 0 = stage 1), plus the two extras.
var _stages: Array[AudioStreamPlayer] = []
var _boss: AudioStreamPlayer = null
var _ending: AudioStreamPlayer = null
## The player that should be audible right now.
var _current: AudioStreamPlayer = null
## The running volume tween per player, so a new fade can cancel an old one.
var _fades: Dictionary = {}
## The audio bus every music player uses (PauseMenu mutes it).
const MUSIC_BUS: StringName = &"Music"


## Loads what exists and listens for the things that change the music. connect() hooks
## each signal to a function here: signals over polling.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep playing through hit-stops and pauses
	# A "Music" audio bus (made here, routed into Master) so the pause menu can mute the
	# score on its own without silencing the sound effects.
	if AudioServer.get_bus_index(MUSIC_BUS) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, MUSIC_BUS)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, &"Master")
	for i in Balance.PORTRAIT_STAGE_COUNT:
		var player := _make_player(Balance.MUSIC_STAGE_PATH % (i + 1))
		if player != null:
			_stages.append(player)
	_boss = _make_player(Balance.MUSIC_BOSS_PATH)
	_ending = _make_player(Balance.MUSIC_ENDING_PATH)
	PortraitState.stage_changed.connect(func(_stage: int) -> void: _refresh())
	PortraitState.healed.connect(func(_stage: int) -> void: _refresh())
	Events.level_started.connect(func(_index: int) -> void: _refresh())
	_refresh()


## A looping, silent player for `path`, or null if the file is missing.
func _make_player(path: String) -> AudioStreamPlayer:
	if not ResourceLoader.exists(path):
		return null
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = Balance.MUSIC_SILENT_DB
	player.bus = MUSIC_BUS
	add_child(player)
	return player


## Pick the track for where we are (boss, ending, or the portrait stage) and fade to it.
func _refresh() -> void:
	var target: AudioStreamPlayer = null
	var scene: int = GameFlow.current_index
	if scene == Balance.MUSIC_BOSS_SCENE and _boss != null:
		target = _boss
	elif scene == Balance.MUSIC_ENDING_SCENE and _ending != null:
		target = _ending
	elif not _stages.is_empty():
		target = _stages[clampi(PortraitState.stage, 1, _stages.size()) - 1]
	_fade_to(target)


## The track playing right now (null when quiet). Used by tools/sim_music.gd.
func current() -> AudioStreamPlayer:
	return _current


## Crossfade: the target starts from the top (unless it is still audible from a fade
## that is being undone) and rises to MUSIC_VOLUME_DB; every other playing track sinks
## to silent and then stops, so only one or two tracks are ever being decoded.
func _fade_to(target: AudioStreamPlayer) -> void:
	if target == _current:
		return
	_current = target
	for player: AudioStreamPlayer in _stages + ([_boss, _ending] as Array[AudioStreamPlayer]):
		if player == null:
			continue
		if player == target:
			if not player.playing:
				player.volume_db = Balance.MUSIC_SILENT_DB
				player.play()
			_tween_volume(player, Balance.MUSIC_VOLUME_DB, false)
		elif player.playing:
			_tween_volume(player, Balance.MUSIC_SILENT_DB, true)


## Tween `player` to `to_db` over MUSIC_FADE_S, cancelling its previous fade first;
## with `stop_after` it stops at the end (tween_callback runs a function when reached).
func _tween_volume(player: AudioStreamPlayer, to_db: float, stop_after: bool) -> void:
	var old: Tween = _fades.get(player)
	if old != null and old.is_valid():
		old.kill()
	var tween := create_tween()
	tween.tween_property(player, "volume_db", to_db, Balance.MUSIC_FADE_S)
	if stop_after:
		tween.tween_callback(player.stop)
	_fades[player] = tween
