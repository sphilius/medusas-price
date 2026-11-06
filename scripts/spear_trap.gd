## spear_trap.gd (root script of scenes/props/spear_trap.tscn)
## Purpose: a row of spears hidden in the floor that thrust up on a timer. The cycle:
## DOWN (safe) -> WARN (gold glints on the slots, the game's danger colour) -> UP (any
## touch costs a crack, like a hoplite hit) -> DOWN again. A statue resting on the trap
## JAMS it: the spears stay down and the statue becomes a safe bridge. That is the
## "statue bridge" puzzle: petrify an enemy, push the statue into the spear trench.
## Place its origin at the left end of the trap, on the floor surface.
class_name SpearTrap
extends Area2D

enum State { DOWN, WARN, UP }

## Width in 32 px tiles.
@export var width_tiles: int = 2
## 0..1: where in its cycle it starts, so a row of traps can ripple.
@export var phase: float = 0.0

var state: State = State.DOWN
var _timer: float = 0.0
## How far the spears are out, 0 (hidden) to 1 (fully up); drawn in _draw().
var _extend: float = 0.0


## Sets up the hurt zone (an Area2D only detects; it never blocks) and starts the cycle.
func _ready() -> void:
	collision_layer = 0
	collision_mask = Balance.PHYS_PLAYER | Balance.PHYS_STATUES | Balance.PHYS_ENEMIES
	monitorable = false
	var zone := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var w: float = width_tiles * Balance.TILE_SIZE
	rect.size = Vector2(w - 8.0, Balance.SPEAR_HEIGHT)
	zone.shape = rect
	zone.position = Vector2(w * 0.5, -Balance.SPEAR_HEIGHT * 0.5)
	add_child(zone)
	# Start part-way through the cycle, given by `phase`.
	var cycle: float = Balance.SPEAR_DOWN_S + Balance.SPEAR_WARN_S + Balance.SPEAR_UP_S
	_timer = Balance.SPEAR_DOWN_S - fposmod(phase * cycle, cycle)
	if _timer <= 0.0:
		_timer += cycle


## True while a statue sits in the trap (statues are bodies on PHYS_STATUES).
func is_jammed() -> bool:
	for body in get_overlapping_bodies():
		if body.is_in_group(&"statues"):
			return true
	return false


## The cycle, one state at a time (`match` is GDScript's switch).
func _physics_process(delta: float) -> void:
	_timer -= delta
	match state:
		State.DOWN:
			if _timer <= 0.0 and not is_jammed():
				_set_state(State.WARN, Balance.SPEAR_WARN_S)
		State.WARN:
			if _timer <= 0.0:
				_set_state(State.UP, Balance.SPEAR_UP_S)
				# Only traps near Medusa are heard (the sound is not positional, so
				# otherwise every trap in the level would clack all the time).
				var player: Node2D = get_tree().get_first_node_in_group(&"player")
				if player != null and player.global_position.distance_to(global_position) < Balance.SPEAR_SFX_RANGE:
					Fx.play(&"spear", Balance.SPEAR_SFX_PITCH)
		State.UP:
			# Pull back at once if a statue landed in the trap while it was up.
			if _timer <= 0.0 or is_jammed():
				_set_state(State.DOWN, Balance.SPEAR_DOWN_S)
			else:
				for body in get_overlapping_bodies():
					if body is Player:
						# The player's own hit handling gives the crack, knockback and the
						# short invulnerability, so standing in it costs one crack, not 60.
						Events.player_hit.emit(Balance.CRACKS_HIT, &"spear", global_position + Vector2(width_tiles * 16.0, 0.0))
					elif body.has_method(&"spike_hit"):
						body.spike_hit()  # an enemy she whipped onto the spikes dies
	var target: float = 1.0 if state == State.UP else 0.0
	_extend = move_toward(_extend, target, delta * Balance.SPEAR_THRUST_SPEED)
	queue_redraw()  # ask for _draw() again next frame


## Switch state and set how long it lasts.
func _set_state(new_state: State, seconds: float) -> void:
	state = new_state
	_timer = seconds


## The trap's art: a dark slot strip, the spear shafts and bronze tips sliding up, and
## a gold glint on each slot while it warns.
func _draw() -> void:
	var w: float = width_tiles * Balance.TILE_SIZE
	draw_rect(Rect2(0.0, -4.0, w, 4.0), Balance.COLOR_BLACK)
	var count: int = width_tiles * 3
	var gap: float = w / count
	var h: float = Balance.SPEAR_HEIGHT * _extend
	for i in count:
		var x: float = gap * (i + 0.5)
		if h > 1.0:
			draw_line(Vector2(x, 0.0), Vector2(x, -h), Balance.COLOR_BLACK, 3.0)
			var tip := PackedVector2Array([Vector2(x - 5.0, -h + 6.0), Vector2(x, -h - 8.0), Vector2(x + 5.0, -h + 6.0)])
			draw_colored_polygon(tip, Balance.COLOR_GOLD if state == State.WARN else Balance.COLOR_BLACK)
		if state == State.WARN:
			draw_circle(Vector2(x, -3.0), 3.0, Balance.COLOR_GOLD)
