## sim_music.gd - dev-only headless check (scene: tools/sim_music.tscn).
## The Music autoload: every track file loads as a looping Ogg stream, the stage-1 loop
## plays at the start, aging the portrait crossfades to the next stage's loop (the old
## one stops once silent), the boss scene switches to the boss track, and the pool
## (heal) brings the stage loop back. Prints PASS/FAIL lines, exits non-zero on failure.
extends Node

var _failures: int = 0


## The whole check runs from _ready (called once when the scene starts). Emitting
## Events.level_started by hand stands in for a real level load; `await` on a timer
## pauses here until the crossfade has had time to finish.
func _ready() -> void:
	for i in Balance.PORTRAIT_STAGE_COUNT:
		_check_track(Balance.MUSIC_STAGE_PATH % (i + 1))
	_check_track(Balance.MUSIC_BOSS_PATH)
	_check_track(Balance.MUSIC_ENDING_PATH)

	PortraitState.reset_run()
	GameFlow.current_index = 1
	Events.level_started.emit(1)
	var first: AudioStreamPlayer = Music.current()
	_check(first != null and first.playing and first.stream.resource_path.ends_with("stage_1.ogg"), "level start plays the stage 1 loop")

	# Enough cracks to finish stage 1 moves the portrait (and the music) to stage 2.
	PortraitState.add_cracks(PortraitState.threshold(1), &"sim")
	var second: AudioStreamPlayer = Music.current()
	_check(PortraitState.stage == 2 and second != first and second.stream.resource_path.ends_with("stage_2.ogg"), "aging to stage 2 switches to the stage 2 loop")
	await get_tree().create_timer(Balance.MUSIC_FADE_S + 0.3).timeout
	_check(not first.playing and is_equal_approx(second.volume_db, Balance.MUSIC_VOLUME_DB), "old loop stops after the fade, new one is at full volume")

	GameFlow.current_index = Balance.MUSIC_BOSS_SCENE
	Events.level_started.emit(Balance.MUSIC_BOSS_SCENE)
	_check(Music.current().stream.resource_path.ends_with("boss.ogg"), "boss scene plays the boss track")

	GameFlow.current_index = 1
	Events.level_started.emit(1)
	PortraitState.heal_at_pool()
	_check(Music.current().stream.resource_path.ends_with("stage_1.ogg"), "pool heal drops back to the stage 1 loop")

	print("sim_music: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


## One track file: exists, loads as Ogg Vorbis, is set to loop, and is a sensible length.
func _check_track(path: String) -> void:
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	var ogg := stream as AudioStreamOggVorbis
	_check(ogg != null and ogg.loop and ogg.get_length() > 30.0, "%s loads, loops, %.0f s" % [path.get_file(), stream.get_length() if stream != null else 0.0])


## Prints one PASS/FAIL line and counts failures (the count becomes the exit code).
func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1
