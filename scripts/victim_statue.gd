## victim_statue.gd (root script of scenes/props/victim_statue.tscn)
## Purpose: a statue that is already there when the level starts (someone Medusa, or
## the heroes, froze long ago). It is a real Statue: it can be pushed, it cracks on the
## first whip hit and shatters on the second, and it is a platform while it stands.
## Choose its pose and the way it faces in the Inspector; the figure is built from
## placeholder polygons, tinted marble white, when the level starts. In the editor you
## only see a pale box the size of its body (that box is removed at runtime).
## Place it with its origin 32 px above the floor, like an enemy (feet at origin + 32).
extends Statue

## The poses a victim can be frozen in.
enum Pose { STANDING, ARMS_RAISED, CROUCHED, FLEEING }

## The pose, chosen in the Inspector.
@export var pose: Pose = Pose.STANDING
## True = faces right, false = faces left.
@export var faces_right: bool = true

## Where the feet are, relative to the origin (same as an enemy's).
const FEET_Y: float = 32.0


## _ready is Godot's "I just entered the scene tree" callback; it runs once. A normal
## Statue is built in code by Statue.from_enemy(), but a victim is placed in the editor,
## so this does the same set-up itself: physics layers, the body box, the figure and
## the grinding sound. (Fx is an autoload: a script Godot loads first and keeps global.)
func _ready() -> void:
	enemy_type = &"victim"
	collision_layer = Balance.PHYS_STATUES
	# Same as a statue made from an enemy: only matters when it is pushed or falls.
	collision_mask = Balance.PHYS_WORLD | Balance.PHYS_STATUES
	sync_to_physics = false
	add_to_group(&"statues")
	var editor_box := get_node_or_null("EditorBox")
	if editor_box:
		editor_box.queue_free()
	_build_body()
	_build_art()
	# Grinding loop for when it is pushed (same as every statue).
	_grind = AudioStreamPlayer2D.new()
	_grind.stream = Fx.grind_stream
	_grind.volume_db = Balance.GRIND_SFX_VOLUME_DB
	add_child(_grind)


## The collision box. Crouching is shorter, but the feet stay on the same line.
func _build_body() -> void:
	var size: Vector2 = Balance.VICTIM_BODY_SIZE
	if pose == Pose.CROUCHED:
		size.y = Balance.VICTIM_CROUCH_HEIGHT
	var shape := RectangleShape2D.new()
	shape.size = size
	var holder := CollisionShape2D.new()
	holder.shape = shape
	holder.position = Vector2(0.0, FEET_Y - size.y * 0.5)
	add_child(holder)


## The figure: a node of white polygons, tinted marble, flipped for facing.
func _build_art() -> void:
	_art = Node2D.new()
	_art.name = "Art"
	add_child(_art)
	match pose:
		Pose.STANDING:
			_part([[-9, -32], [9, -32], [9, -14], [-9, -14]])      # head
			_part([[-14, -14], [14, -14], [14, 32], [-14, 32]])    # body
			_part([[-20, -10], [-14, -10], [-14, 18], [-20, 18]])  # left arm down
			_part([[14, -10], [20, -10], [20, 18], [14, 18]])      # right arm down
		Pose.ARMS_RAISED:
			_part([[-9, -30], [9, -30], [9, -12], [-9, -12]])      # head
			_part([[-14, -12], [14, -12], [14, 32], [-14, 32]])    # body
			_part([[-14, -10], [-8, -10], [-20, -44], [-26, -40]]) # left arm up
			_part([[14, -10], [8, -10], [20, -44], [26, -40]])     # right arm up
		Pose.CROUCHED:
			_part([[-8, -6], [8, -6], [8, 8], [-8, 8]])            # head, tucked
			_part([[-22, 8], [22, 8], [22, 32], [-22, 32]])        # hunched body
			_part([[-22, -2], [-8, -8], [-4, 0], [-18, 8]])        # arm over the head
		Pose.FLEEING:
			_part([[0, -32], [18, -32], [18, -14], [0, -14]])      # head, forward
			_part([[-8, -14], [14, -14], [8, 8], [-14, 8]])        # leaning torso
			_part([[-14, 8], [-4, 8], [-22, 32], [-30, 32]])       # back leg
			_part([[-4, 8], [8, 8], [14, 32], [4, 32]])            # front leg
			_part([[-8, -10], [-2, -6], [-26, -2], [-30, -8]])     # arm flung back
	_art.scale.x = 1.0 if faces_right else -1.0
	_art.modulate = Balance.COLOR_MARBLE


## Add one polygon (list of [x, y] points) to the art.
func _part(points: Array) -> void:
	var poly := Polygon2D.new()
	var packed := PackedVector2Array()
	for p: Array in points:
		packed.append(Vector2(p[0], p[1]))
	poly.polygon = packed
	_art.add_child(poly)
