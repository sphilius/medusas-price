## sim_levels.gd - dev-only headless check (scene: tools/sim_levels.tscn).
## Loads every level and checks its lighting, spawn and (level 1) props, cracks a
## victim statue, then drives GameFlow through real scene changes: exit signal ->
## next level, the debug number-key skip, and the ledger's level_start / level_end.
## Prints PASS/FAIL lines and exits non-zero if anything failed.
extends Node

const LEVELS: Dictionary = {
	"res://scenes/levels/level_1_temple.tscn": Balance.LIGHT_NOON,
	"res://scenes/levels/level_2_cliffs.tscn": Balance.LIGHT_DUSK,
	"res://scenes/levels/level_3_cave.tscn": Balance.LIGHT_TORCH,
	"res://scenes/levels/boss.tscn": Balance.LIGHT_STORM,
}

var _failures: int = 0


func _ready() -> void:
	await _test_levels()
	await _test_victim_statue()
	await _test_flow()
	print("sim_levels: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


## Each level: right tint, Medusa placed on the spawn marker, one exit.
func _test_levels() -> void:
	for path: String in LEVELS:
		var level: LevelBase = (load(path) as PackedScene).instantiate()
		add_child(level)
		await get_tree().physics_frame
		var player: Node2D = get_tree().get_first_node_in_group(&"player")
		_check(level.get_node("Tint").color == LEVELS[path], "%s tint" % path.get_file())
		_check(player != null and player.global_position.distance_to(level.get_node("Spawn").global_position) < 8.0, "%s player at spawn" % path.get_file())
		_check(level.get_node("Terrain").get_used_cells().size() > 0, "%s has terrain" % path.get_file())
		level.free()
		await get_tree().physics_frame


## The pre-placed victim: first whip cracks, second shatters.
func _test_victim_statue() -> void:
	var level: LevelBase = (load("res://scenes/levels/level_1_temple.tscn") as PackedScene).instantiate()
	add_child(level)
	await get_tree().physics_frame
	var victim: Statue = level.get_node("VictimStatue")
	_check(victim.is_in_group(&"statues") and victim.state == Statue.State.INTACT, "victim starts intact, in statues group")
	victim.whip_hit()
	_check(victim.state == Statue.State.CRACKED, "victim cracks on first hit")
	victim.whip_hit()
	_check(victim.state == Statue.State.SHATTERED, "victim shatters on second hit")
	level.free()
	await get_tree().physics_frame


## Real scene changes through GameFlow.
func _test_flow() -> void:
	# Detach from current_scene so change_scene_to_file does not free this test.
	get_tree().current_scene = null
	GameFlow.current_index = -1
	GameFlow.next_level()
	_check(GameFlow.current_index == -1, "next_level does nothing outside the flow")

	GameFlow.go_to(1)
	await get_tree().create_timer(1.5).timeout
	_check(get_tree().current_scene != null and get_tree().current_scene.scene_file_path == GameFlow.ORDER[1], "go_to(1) loads the temple")
	_check(GameFlow.current_index == 1 and RunLedger.level == 1, "flow index and ledger level = 1")

	Events.level_exit_reached.emit()
	await get_tree().create_timer(1.5).timeout
	_check(GameFlow.current_index == 2, "exit signal moves on to the cliffs")
	var ends: Array = RunLedger.events_of("level_end")
	_check(ends.size() == 1 and ends[0]["data"]["name"] == "level_1_temple" and ends[0]["data"]["seconds"] >= 0.0, "level_end logged with time")
	var starts: Array = RunLedger.events_of("level_start")
	_check(starts.size() >= 2 and starts[-1]["data"]["name"] == "level_2_cliffs", "level_start logged")

	var key := InputEventKey.new()
	key.keycode = KEY_4
	key.pressed = true
	GameFlow._unhandled_input(key)
	await get_tree().create_timer(1.5).timeout
	_check(GameFlow.current_index == 4, "key 4 skips to the boss")

	# Intro resets the ledger (start_run).
	GameFlow.go_to(0)
	await get_tree().create_timer(1.5).timeout
	_check(GameFlow.current_index == 0 and RunLedger.events_of("level_end").is_empty(), "intro starts a fresh run")
