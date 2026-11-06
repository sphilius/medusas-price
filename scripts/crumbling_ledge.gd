## crumbling_ledge.gd (root script of scenes/props/crumbling_ledge.tscn)
## Purpose: a cracked marble ledge. CRUMBLE_DELAY seconds after Medusa lands on it, it
## shakes, drops and fades (collision off); CRUMBLE_RESPAWN seconds later it is back.
## It is drawn paler than the ground, with dark cracks, so it reads as "this one breaks".
class_name CrumblingLedge
extends TerrainPiece

enum State { SOLID, SHAKING, FALLEN }

var state: State = State.SOLID
var _timer: float = 0.0
## The detector: a thin zone just above the top surface that notices Medusa standing.
var _sensor: Area2D
var _home: Vector2


## Builds the tiles (super._ready), tints them pale, draws cracks, and adds the sensor
## that notices Medusa standing on top. Area2D only detects; it never blocks movement.
func _ready() -> void:
	super._ready()
	_home = position
	modulate = Balance.CRUMBLE_TINT
	_add_cracks()
	_sensor = Area2D.new()
	_sensor.collision_layer = 0
	_sensor.collision_mask = Balance.PHYS_PLAYER
	_sensor.monitorable = false
	var zone := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(size_px().x, 6.0)
	zone.shape = rect
	zone.position = Vector2(size_px().x * 0.5, -3.0)  # a 6 px strip on top of the slab
	_sensor.add_child(zone)
	add_child(_sensor)


## Runs every physics step (60 times a second). `match` is GDScript's switch: one
## branch per state, so each state only does its own job.
func _physics_process(delta: float) -> void:
	match state:
		State.SOLID:
			# Polling the sensor here (not body_entered) also catches her landing again
			# while still inside it.
			for body in _sensor.get_overlapping_bodies():
				if body is Player and (body as Player).is_on_floor():
					state = State.SHAKING
					_timer = Balance.CRUMBLE_DELAY
		State.SHAKING:
			_timer -= delta
			position = _home + Vector2(randf_range(-1.5, 1.5), 0.0)  # a nervous shiver
			if _timer <= 0.0:
				_fall()
		State.FALLEN:
			_timer -= delta
			if _timer <= 0.0:
				_restore()


## Collision off at once; the slab drops a little and fades out.
func _fall() -> void:
	state = State.FALLEN
	_timer = Balance.CRUMBLE_RESPAWN
	position = _home
	tiles.collision_enabled = false
	Fx.play(&"crumble")
	# A Tween animates properties over time; set_parallel runs both at once.
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position", _home + Vector2(0.0, Balance.CRUMBLE_DROP_PX), 0.35)
	tween.tween_property(self, "modulate:a", 0.0, 0.35)


## Back in place, solid again, fading in.
func _restore() -> void:
	state = State.SOLID
	position = _home
	tiles.collision_enabled = true
	var color: Color = Balance.CRUMBLE_TINT
	color.a = 0.0
	modulate = color
	create_tween().tween_property(self, "modulate:a", 1.0, 0.3)


## A few dark zig-zag cracks across the slab (Line2D draws a polyline).
func _add_cracks() -> void:
	var w: float = size_px().x
	var h: float = size_px().y
	var step: float = w / 3.0
	for i in 2:
		var x0: float = step * (i + 1) + randf_range(-6.0, 6.0)
		var line := Line2D.new()
		line.width = 2.0
		line.default_color = Balance.COLOR_BLACK
		line.points = PackedVector2Array([Vector2(x0, 0.0), Vector2(x0 + 5.0, h * 0.35),
				Vector2(x0 - 4.0, h * 0.7), Vector2(x0 + 3.0, h)])
		add_child(line)
