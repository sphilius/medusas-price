## enemy.gd (base class; each enemy scene's root script extends it)
## Purpose: what every enemy shares - facing, gaze progress (tinted from black
## toward marble white) and petrification into a Statue.
## Expects a child Node2D named "Visual" holding the art. Placeholder art is drawn
## white so Visual.modulate alone sets its color.
class_name Enemy
extends CharacterBody2D

## Sent with Events.petrified (portrait, ledger and gallery tell enemies apart by it).
@export var enemy_type: StringName = &"enemy"
## Eye-shading soldiers take longer to petrify (Balance.GAZE_HOLD_EYE_SHADING).
@export var eye_shading: bool = false

## Which way the enemy looks: -1 = left, 1 = right. Change it with set_facing().
var facing: int = 1

## Seconds spent continuously in the gaze cone with a clear view.
var _gaze_time: float = 0.0
## Set once petrify() runs, so it can only happen once.
var _petrified: bool = false

## The art. Flipped for facing, tinted for gaze progress, handed to the Statue.
@onready var visual: Node2D = $Visual


func _ready() -> void:
	visual.modulate = Balance.COLOR_BLACK


## Seconds of continuous gaze needed to petrify. Subclasses may override.
func gaze_hold() -> float:
	return Balance.GAZE_HOLD_EYE_SHADING if eye_shading else Balance.GAZE_HOLD


## Called by the gaze every physics frame this enemy is in the cone and visible.
func add_gaze(delta: float) -> void:
	if _petrified:
		return
	_gaze_time += delta
	var t: float = clampf(_gaze_time / gaze_hold(), 0.0, 1.0)
	visual.modulate = Balance.COLOR_BLACK.lerp(Balance.COLOR_MARBLE, t)
	if _gaze_time >= gaze_hold():
		petrify()


## Called by the gaze when the enemy leaves the cone, is blocked, or gaze ends.
func reset_gaze() -> void:
	if _petrified or _gaze_time == 0.0:
		return
	_gaze_time = 0.0
	visual.modulate = Balance.COLOR_BLACK


## Face left (-1) or right (1) and mirror the art to match.
func set_facing(dir: int) -> void:
	facing = dir
	visual.scale.x = dir


## Current animation frame of the first AnimatedSprite2D under Visual, else 0.
func pose_frame() -> int:
	var sprites: Array[Node] = visual.find_children("*", "AnimatedSprite2D", true, false)
	return (sprites[0] as AnimatedSprite2D).frame if not sprites.is_empty() else 0


## Turn to stone: swap this body for a Statue in the same pose, then announce it.
func petrify() -> void:
	if _petrified:
		return
	_petrified = true
	set_physics_process(false)
	var frame: int = pose_frame()
	var flip: bool = facing < 0
	var where: Vector2 = global_position
	Statue.from_enemy(self)
	Events.petrified.emit(enemy_type, frame, flip, where)
	queue_free()
