## pressure_plate.gd (root script of scenes/props/pressure_plate.tscn)
## Purpose: a floor plate that is pressed while a statue or Medusa rests on it.
## Emits `pressed` when the first thing settles on it and `released` when the last
## thing leaves (walks off, is pushed off, is freed or shatters). Doors and other
## props connect to those two signals.
## Place it with its origin at the middle of the plate's base, on the floor surface:
## the trigger zone rises PLATE_TRIGGER_HEIGHT above that point.
## What counts as "on it": a statue that is not mid-fall, and Medusa only while she
## stands on the floor (so jumping over the plate does not press it). A statue that
## shatters stops counting at once.
extends Area2D

## Something just settled on the plate / the last thing just left it.
signal pressed
signal released

## True while the plate is pressed.
var is_pressed: bool = false

## Everything overlapping the trigger zone (counted or not, see _counts).
var _bodies: Array[Node2D] = []

@onready var _trigger: CollisionShape2D = $Trigger
@onready var _slab: Polygon2D = $Slab


func _ready() -> void:
	collision_layer = 0
	collision_mask = Balance.PHYS_PLAYER | Balance.PHYS_STATUES
	monitorable = false
	var half_width: float = Balance.PLATE_WIDTH_BL * Balance.BL * 0.5
	var zone := RectangleShape2D.new()
	zone.size = Vector2(half_width * 2.0, Balance.PLATE_TRIGGER_HEIGHT)
	_trigger.shape = zone
	_trigger.position = Vector2(0.0, -Balance.PLATE_TRIGGER_HEIGHT * 0.5)
	_slab.polygon = PackedVector2Array([
		Vector2(-half_width, -Balance.PLATE_SLAB_HEIGHT), Vector2(half_width, -Balance.PLATE_SLAB_HEIGHT),
		Vector2(half_width, 0.0), Vector2(-half_width, 0.0),
	])
	# Only needs a per-frame look while something is on it (to see her leave the ground).
	set_physics_process(false)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_apply_visual()


# Overlap signals fire while physics is flushing, so the press / release itself is
# worked out (and emitted) a moment later, where listeners may change physics freely.
func _on_body_entered(body: Node2D) -> void:
	_bodies.append(body)
	set_physics_process(true)
	_refresh.call_deferred()


func _on_body_exited(body: Node2D) -> void:
	_bodies.erase(body)
	set_physics_process(not _bodies.is_empty())
	_refresh.call_deferred()


func _physics_process(_delta: float) -> void:
	_refresh()


## Press or release when the answer to "is anything on me?" changes.
func _refresh() -> void:
	var now_pressed: bool = _bodies.any(_counts)
	if now_pressed == is_pressed:
		return
	is_pressed = now_pressed
	_apply_visual()
	if is_pressed:
		pressed.emit()
	else:
		released.emit()


## Does this overlapping body hold the plate down right now?
func _counts(body: Node2D) -> bool:
	if not is_instance_valid(body):
		return false
	if body is Statue:
		var statue := body as Statue
		return statue.state != Statue.State.SHATTERED and statue.motion != Statue.Motion.FALLING
	if body is Player:
		return (body as Player).is_on_floor()
	return false


## Pressed: the slab sinks (shrinks into the floor) and turns gold, the power color.
func _apply_visual() -> void:
	_slab.scale.y = Balance.PLATE_PRESSED_SCALE if is_pressed else 1.0
	_slab.color = Balance.COLOR_GOLD if is_pressed else Balance.COLOR_MARBLE
