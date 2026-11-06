## events.gd (autoload "Events")
## Purpose: global signal bus. Systems emit here and listeners (portrait, FX,
## camera, RunLedger, gallery) connect here, so nobody holds references to anybody.
extends Node

## An enemy just turned to stone. pose_frame/flip describe the frozen pose.
signal petrified(enemy_type: StringName, pose_frame: int, flip: bool, position: Vector2)
## A statue hit something: landed = true after a fall, false when a slide stops.
signal statue_thud(position: Vector2, landed: bool)
## The whip cracked an intact statue / shattered a cracked one.
signal statue_cracked(enemy_type: StringName, position: Vector2)
signal statue_shattered(enemy_type: StringName, position: Vector2)
## Ask the active camera to shake: max offset in px, decay time in s.
signal shake_requested(strength: float, duration: float)
## The player was struck. source names the attacker (&"hoplite", &"leaper");
## from_position is where it came from, so the player knows which way to fly.
signal player_hit(cracks: int, source: StringName, from_position: Vector2)
## A mirror-bearer's mirror threw Medusa's gaze back at her. position is the mirror.
signal gaze_reflected(enemy_type: StringName, position: Vector2)
## Medusa touched a safe ledge marker; position is on the floor surface. A pit fall
## puts her back at the last one.
signal safe_ledge_reached(position: Vector2)
## Medusa healed at a mirror pool; position is on the floor. It is now her death respawn.
signal pool_used(position: Vector2)
## Medusa fell into a pit (a Pit zone, or below Balance.PLAYER_PIT_Y).
signal player_fell(position: Vector2)
## Medusa's portrait ran out: the turn-to-stone began / she is back on her feet at position
## (her center), after a death.
signal player_died(position: Vector2)
signal player_respawned(position: Vector2)
## Medusa reached the level exit. GameFlow answers by loading the next level.
signal level_exit_reached
## Perseus has turned to stone (opens the boss arena's exit).
signal boss_defeated
## An enemy was killed by the whip (lashes or the snake finisher), not petrified.
signal enemy_slain(enemy_type: StringName, position: Vector2)
