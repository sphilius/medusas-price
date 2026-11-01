## test_room.gd (root script of scenes/test_room.tscn)
## Purpose: level 1 graybox. Placeholder pit handling until real pits exist:
## a player who falls far below the level restarts the room. The whole room
## resets (enemies included), because the gap can only be crossed on a leaper
## frozen mid-leap: a wasted leaper must come back, or the level softlocks.
## Jumping into the pit is also the wordless "retry".
## When the room is not the current scene (a sim instanced it), only the
## player goes back to the start, so the sim itself is never reloaded.
extends Node2D

## Set once a reset is queued, so the pit only triggers once.
var _resetting: bool = false

@onready var _player: Player = $Player
@onready var _start: Vector2 = $Player.position


func _physics_process(_delta: float) -> void:
	if _resetting or _player.global_position.y <= Balance.PLAYER_PIT_Y:
		return
	RunLedger.log_event("pit", {"level": RunLedger.level})
	if get_tree().current_scene == self:
		_resetting = true
		get_tree().reload_current_scene.call_deferred()
	else:
		_player.global_position = _start
		_player.velocity = Vector2.ZERO
