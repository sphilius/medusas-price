## statue.gd (built in code by Statue.from_enemy; no scene)
## Purpose: a petrified enemy. A StaticBody2D on the statues layer, frozen in
## the enemy's last pose and tinted marble white. It never falls on its own, so
## statues frozen mid-air stay put and are safe platforms.
## Cracking, shattering and pushing come with the whip and statue tasks.
class_name Statue
extends StaticBody2D

enum State { INTACT, CRACKED, SHATTERED }

## Intact -> cracked (first whip hit) -> shattered (second).
var state: State = State.INTACT
## What it used to be (copied from Enemy.enemy_type).
var enemy_type: StringName = &""


## Build a statue in `enemy`'s place and add it beside the enemy. The enemy's
## Visual node is moved over as-is, which keeps its exact frame, flip and pose.
## The caller frees the enemy.
static func from_enemy(enemy: Enemy) -> Statue:
	var statue := Statue.new()
	statue.enemy_type = enemy.enemy_type
	statue.collision_layer = Balance.PHYS_STATUES
	statue.collision_mask = 0
	statue.transform = enemy.transform
	statue.add_to_group(&"statues")

	# Same collision as the enemy (shape resources are shared; statues never resize).
	for child in enemy.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			statue.add_child(child.duplicate())

	enemy.get_parent().add_child(statue)

	# Freeze the pose: move the art over, stop any animation, paint it marble.
	var art: Node2D = enemy.visual
	art.reparent(statue, false)
	for sprite in art.find_children("*", "AnimatedSprite2D", true, false):
		(sprite as AnimatedSprite2D).pause()
	art.modulate = Balance.COLOR_MARBLE
	return statue
