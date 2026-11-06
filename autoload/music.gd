## music.gd (autoload "Music")
## Purpose: the adaptive score. Five loops, one per portrait stage (audio/music/
## stage_1..stage_5, made with Lyria 3 from docs/audio/lyria_prompts.md), all play in
## sync on their own players; only the current stage's loop is audible, and a stage
## change crossfades over MUSIC_FADE_S (so the music thins as the portrait ages and
## fills back in at a pool). The boss arena and the ending switch to their own track
## when that file exists. Missing files are skipped silently: with none at all the game
## is simply quiet; with only stage_1 that one loop plays throughout.
extends Node

## One player per stage loop that exists (index 0 = stage 1), plus the two extras.
var _stages: Array[AudioStreamPlayer] = []
var _boss: AudioStreamPlayer = null
var _ending: AudioStreamPlayer = null
## The player that should be audible right now.
var _current: AudioStreamPlayer = null


## Loads what exists, starts every stage loop together (muted) so they stay in step,
## and listens for the things that change the music. connect() hooks each signal to
## a function here: signals over polling.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep playing through hit-stops and pauses
	for i in Balance.PORTRAIT_STAGE_COUNT:
		var player := _make_player(Balance.MUSIC_STAGE_PATH % (i + 1))
		if player != null:
			_stages.append(player)
	_boss = _make_player(Balance.MUSIC_BOSS_PATH)
	_ending = _make_player(Balance.MUSIC_ENDING_PATH)
	for player in _stages:
		player.play()
	PortraitState.stage_changed.connect(func(_stage: int) -> void: _refresh())
	PortraitState.healed.connect(func(_stage: int) -> void: _refresh())
	Events.level_started.connect(func(_index: int) -> void: _refresh())
	_refresh()


## A looping, muted player for `path`, or null if the file is missing.
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


## Crossfade: the target rises to MUSIC_VOLUME_DB, every other player sinks to silent.
## The extras start when first needed; the stage loops never stop, so they stay in step.
func _fade_to(target: AudioStreamPlayer) -> void:
	if target == _current:
		return
	_current = target
	if target != null and not target.playing:
		target.play()
	for player: AudioStreamPlayer in _stages + ([_boss, _ending] as Array[AudioStreamPlayer]):
		if player == null:
			continue
		var to_db: float = Balance.MUSIC_VOLUME_DB if player == target else Balance.MUSIC_SILENT_DB
		var tween := create_tween()
		tween.tween_property(player, "volume_db", to_db, Balance.MUSIC_FADE_S)
