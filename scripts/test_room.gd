## test_room.gd (root script of scenes/test_room.tscn)
## Purpose: level 1 graybox. The pit under the gap and the safe ledges put Medusa back
## on her feet (see Player), so this script only keeps the room solvable: the gap can
## only be crossed on a leaper frozen mid-leap, so if a fall finds no leaper and no
## leaper statue left in the room, a fresh leaper appears at its starting spot.
extends Node2D

const LEAPER_SCENE: PackedScene = preload("res://scenes/enemies/leaper.tscn")

## Where the room's leaper starts (taken from the scene).
var _leaper_home: Vector2 = Vector2.ZERO


func _ready() -> void:
	_leaper_home = $Leaper.position
	Events.player_fell.connect(_on_player_fell)


func _on_player_fell(_where: Vector2) -> void:
	if _has_leaper():
		return
	var leaper: Node2D = LEAPER_SCENE.instantiate()
	leaper.name = "Leaper"
	leaper.position = _leaper_home
	add_child.call_deferred(leaper)


## A live leaper in the room, or a leaper statue that has not shattered.
func _has_leaper() -> bool:
	for child in get_children():
		if child is Enemy and (child as Enemy).enemy_type == &"leaper" and not child.is_queued_for_deletion():
			return true
	for node in get_tree().get_nodes_in_group(&"statues"):
		var statue := node as Statue
		if statue != null and statue.enemy_type == &"leaper" and statue.state != Statue.State.SHATTERED \
				and not statue.is_queued_for_deletion():
			return true
	return false
