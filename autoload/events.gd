## events.gd (autoload "Events")
## Purpose: global signal bus. Systems emit here and listeners (portrait, FX,
## camera, RunLedger, gallery) connect here, so nobody holds references to anybody.
extends Node

## An enemy just turned to stone. pose_frame/flip describe the frozen pose.
signal petrified(enemy_type: StringName, pose_frame: int, flip: bool, position: Vector2)
## Ask the active camera to shake: max offset in px, decay time in s.
signal shake_requested(strength: float, duration: float)
