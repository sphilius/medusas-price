## moving_platform.gd (root script of scenes/props/moving_platform.tscn)
## Purpose: a stone slab that glides back and forth between its start and start + travel,
## easing in and out at each end (a cosine curve). Medusa and enemies ride it: its
## collider is an AnimatableBody2D, the body type Godot moves by code and whose motion
## it passes on to whatever stands on it. The tiles are only the look.
class_name MovingPlatform
extends TerrainPiece

## How far it moves from its start (px). (0, -128) = 2 BL up and back.
@export var travel: Vector2 = Vector2(192.0, 0.0)
## Seconds for a full trip there and back.
@export var period: float = 4.0
## 0..1: where in the trip it starts, so neighbouring platforms can be out of step.
@export var phase: float = 0.0

## The moving collider. The tiles live inside it, so the look moves with it.
var _body: AnimatableBody2D
var _time: float = 0.0


## _ready runs once when the platform enters the level. `super._ready()` calls the
## parent class's _ready (TerrainPiece builds the tiles) before adding the moving parts.
func _ready() -> void:
	super._ready()  # build the tiles first (TerrainPiece._ready)
	tiles.collision_enabled = false
	var body := AnimatableBody2D.new()
	body.collision_layer = Balance.PHYS_WORLD
	body.collision_mask = 0
	# sync_to_physics: the body's motion is applied in the physics step, so riders
	# move with it without jitter.
	body.sync_to_physics = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size_px()
	shape.shape = rect
	shape.position = size_px() * 0.5
	body.add_child(shape)
	add_child(body)
	# The body must move ITSELF (its own position), not through its parent: an
	# AnimatableBody2D only passes motion to riders when its local position changes.
	remove_child(tiles)
	body.add_child(tiles)
	_body = body
	_time = phase * period


## Moves in the physics step, so bodies riding it get its motion the same frame.
func _physics_process(delta: float) -> void:
	_time += delta
	# 0 -> 1 -> 0 over one period, slow at both ends.
	var k: float = 0.5 - 0.5 * cos(TAU * _time / maxf(period, 0.1))
	_body.position = travel * k
