## run_ledger.gd (autoload "RunLedger")
## Purpose: in-memory event log for the current run. Each event is {t, type, data},
## with t in seconds since start_run(). Feeds the AI features (vase, gallery,
## Perseus adaptation, music) as JSON. Nothing here is drawn on screen.
extends Node

## Events of the current run, oldest first.
var _events: Array[Dictionary] = []
## Ticks (ms) at start_run(), the zero point for t.
var _start_ms: int = 0
## Level the player is on. Set with set_level().
var level: int = 1


func _ready() -> void:
	start_run()
	Events.petrified.connect(_on_petrified)
	Events.statue_cracked.connect(_on_statue_cracked)
	Events.statue_shattered.connect(_on_statue_shattered)


## Forget the previous run and start the clock.
func start_run() -> void:
	_events.clear()
	_start_ms = Time.get_ticks_msec()


func set_level(value: int) -> void:
	level = value


## Append one event with its time stamp.
func log_event(type: String, data: Dictionary) -> void:
	_events.append({"t": (Time.get_ticks_msec() - _start_ms) / 1000.0, "type": type, "data": data})


## Every event of one type, oldest first.
func events_of(type: String) -> Array:
	return _events.filter(func(e: Dictionary) -> bool: return e["type"] == type)


## The whole run as a JSON array string.
func to_json() -> String:
	return JSON.stringify(_events)


## Counts by type, petrified enemies with their poses, deaths, pools used, level.
func summary() -> Dictionary:
	var counts: Dictionary = {}
	var petrified: Array = []
	var by_enemy: Dictionary = {}
	for e: Dictionary in _events:
		var kind: String = e["type"]
		counts[kind] = counts.get(kind, 0) + 1
		if kind == "petrify":
			var d: Dictionary = e["data"]
			var enemy: String = d["enemy_type"]
			petrified.append({"enemy_type": enemy, "pose_frame": d["pose_frame"], "flip": d["flip"]})
			by_enemy[enemy] = by_enemy.get(enemy, 0) + 1
	return {
		"counts": counts,
		"petrified": petrified,
		"petrified_by_enemy": by_enemy,
		"deaths": counts.get("death", 0),
		"pools_used": counts.get("pool", 0),
		"level": level,
	}


func _on_petrified(enemy_type: StringName, pose_frame: int, flip: bool, position: Vector2) -> void:
	log_event("petrify", {
		"enemy_type": String(enemy_type),
		"pose_frame": pose_frame,
		"flip": flip,
		"position": [position.x, position.y],
		"level": level,
		"portrait_stage": PortraitState.stage,
	})


func _on_statue_cracked(enemy_type: StringName, position: Vector2) -> void:
	log_event("statue_cracked", {"enemy_type": String(enemy_type), "position": [position.x, position.y], "level": level})


func _on_statue_shattered(enemy_type: StringName, position: Vector2) -> void:
	log_event("statue_shattered", {"enemy_type": String(enemy_type), "position": [position.x, position.y], "level": level})


## Debug only: F9 prints the run JSON to the console. Stripped from release builds.
func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_F9:
		print(to_json())
