## dummy_enemy.gd (root script of scenes/dummy_enemy.tscn)
## Purpose: a test target for the gaze. A black block that patrols around its
## spawn point and jumps every few seconds, so it can be frozen on the ground or
## mid-air and then stood on.
extends Enemy

## Patrol center (spawn x).
var _home_x: float = 0.0

@onready var _jump_timer: Timer = $JumpTimer


func _ready() -> void:
	super._ready()
	_home_x = position.x
	_jump_timer.wait_time = Balance.DUMMY_JUMP_INTERVAL
	_jump_timer.timeout.connect(_on_jump_timer_timeout)
	_jump_timer.start()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += Balance.ENEMY_GRAVITY * delta

	# Turn around at a wall (face away from it) or at either end of the patrol.
	var limit: float = Balance.DUMMY_PATROL_BL * Balance.BL
	if is_on_wall():
		set_facing(1 if get_wall_normal().x > 0.0 else -1)
	elif facing > 0 and position.x > _home_x + limit:
		set_facing(-1)
	elif facing < 0 and position.x < _home_x - limit:
		set_facing(1)

	velocity.x = facing * Balance.DUMMY_WALK_SPEED
	move_and_slide()


## Hop, if standing on something.
func _on_jump_timer_timeout() -> void:
	if is_on_floor():
		velocity.y = Balance.DUMMY_JUMP_VELOCITY
