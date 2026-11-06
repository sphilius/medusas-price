## enemy_base.gd (base class; each enemy scene's root script extends it)
## Purpose: what every enemy shares - layer 3 body, gravity, facing, gaze progress
## (marble spreading from where the gaze touched, petrify.gdshader), petrification into a Statue, and
## removal when it falls into a pit, and the whip: each lash costs 1 hp (staggers and
## knocks back); at 0 hp the enemy collapses into dust (_die). A lash that lands while
## the enemy is winding up an attack (is_telegraphing) is a PARRY: the enemy is EXPOSED
## for PARRY_OPEN_S, the gaze petrifies it almost at once, and the next lash is the
## snake finisher (the snakes latch on and strangle it). Whip kills cost no crack;
## petrifying costs one, so the whip is the slow, safe road and the gaze the fast one.
## Bodies are solid to Medusa both ways (she masks enemies, enemies mask her), and a
## ContactHitbox built in _ready lets subclasses hurt her on touch (check_contact).
## Expects a child Node2D named "Visual" holding the art. In _ready the real sprite
## art (SpriteKit, keyed by enemy_type) is added under it; if that art is missing the
## white placeholder polygons stay and Visual.modulate sets their color instead.
## Subclasses override _animate() to pick the animation for their current state.
class_name Enemy
extends CharacterBody2D

## Sent with Events.petrified (portrait, ledger and gallery tell enemies apart by it).
@export var enemy_type: StringName = &"enemy"
## Eye-shading soldiers take longer to petrify (Balance.GAZE_HOLD_EYE_SHADING).
@export var eye_shading: bool = false

## Which way the enemy looks: -1 = left, 1 = right. Change it with set_facing().
var facing: int = 1

## Seconds of continuous gaze needed to petrify (set in _ready, read by the gaze).
var gaze_hold_time: float = Balance.GAZE_HOLD
## Half the body's size (px), read from its rectangle CollisionShape2D in _ready.
## Floor probes start from it, so short bodies (the leaper) probe at their own feet.
var half_size: Vector2 = Vector2(Balance.ENEMY_HALF_WIDTH, Balance.ENEMY_HALF_HEIGHT)

## Mirror-bearers also have their mirror knocked aside by the whip (knock_mirror).
@export var mirror_bearer: bool = false

## Seconds left staggered by a whip hit: the enemy does nothing but slide to a stop.
var _stagger_left: float = 0.0
## Whip hits left before it dies (set from Balance.ENEMY_WHIP_HP in _ready).
var hp: int = 5
## Seconds left EXPOSED after a parry (0 = not exposed).
var _exposed_left: float = 0.0
## True once it is dying (whip kill or finisher): ignores everything after that.
var _dying: bool = false

## Seconds spent continuously in the gaze cone with a clear view.
var _gaze_time: float = 0.0
## Where the gazing eye is (global), set by the Gaze right before add_gaze(). The
## stone starts spreading from the point of the sprite nearest to it.
var gaze_from: Vector2 = Vector2.ZERO
## The petrify shader on the sprite while a gaze is in progress (null otherwise).
var _petrify_mat: ShaderMaterial = null
## Set once petrify() runs, so it can only happen once.
var _petrified: bool = false

## The art. Flipped for facing, tinted for gaze progress, handed to the Statue.
@onready var visual: Node2D = $Visual

## The animated sprite added by SpriteKit, or null when only placeholders exist.
var sprite: AnimatedSprite2D = null

## Touch zone around the body (built in _ready); check_contact() reads it.
var _contact: Area2D = null


## _ready runs once when the enemy enters the scene tree (after its children are
## ready). Subclasses that override it must call super._ready() first.
func _ready() -> void:
	collision_layer = Balance.PHYS_ENEMIES
	# Masking the player too makes the block two-way: an enemy walking into a standing
	# Medusa stops against her instead of sliding inside her body.
	collision_mask = Balance.PHYS_WORLD | Balance.PHYS_STATUES | Balance.PHYS_PLAYER
	gaze_hold_time = Balance.GAZE_HOLD_EYE_SHADING if eye_shading else Balance.GAZE_HOLD
	hp = Balance.ENEMY_WHIP_HP.get(&"eye_shading" if eye_shading else enemy_type, Balance.ENEMY_WHIP_HP_DEFAULT)
	# Real art: the eye-shading hoplite has its own sheet, everyone else is keyed by type.
	sprite = SpriteKit.attach(visual, &"eye_shading" if eye_shading else enemy_type)
	# Sprites carry their own colors (white modulate); placeholders are tinted black.
	visual.modulate = Color.WHITE if sprite != null else Balance.COLOR_BLACK
	# Eye-shading soldiers show the "hand over the eyes" pose: a Visual/HandShade node,
	# hidden for everyone else. The sprite art already draws the hand.
	var shade := visual.get_node_or_null("HandShade") as Node2D
	if shade != null:
		shade.visible = eye_shading and sprite == null
	var body := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body and body.shape is RectangleShape2D:
		half_size = (body.shape as RectangleShape2D).size * 0.5
	_build_contact_area()
	_animate()


## Override: show the animation for the current state (subclasses call SpriteKit.play
## from here). Runs on every state change, on stagger start and on stagger end.
func _animate() -> void:
	pass


## An Area2D a little bigger than the body. Solid bodies never overlap, so an area the
## exact body size would miss a touch; the margin catches bodies pressed together.
func _build_contact_area() -> void:
	_contact = Area2D.new()
	_contact.name = "ContactHitbox"
	_contact.collision_layer = 0  # detects only; nothing detects it
	_contact.collision_mask = Balance.PHYS_PLAYER
	var shape := RectangleShape2D.new()
	shape.size = (half_size + Vector2.ONE * Balance.ENEMY_CONTACT_MARGIN) * 2.0
	var holder := CollisionShape2D.new()
	holder.shape = shape
	_contact.add_child(holder)
	add_child(_contact)


## Subclasses call this after move_and_slide(): touching Medusa costs her a crack and
## knocks her back (her invulnerable window stops repeat hits). Staggered enemies and
## statues never hurt. The hit names this enemy's type, e.g. "hoplite".
func check_contact() -> void:
	if _petrified or _dying or is_staggered():
		return
	for node in _contact.get_overlapping_bodies():
		if node is Player:
			Events.player_hit.emit(Balance.CRACKS_HIT, enemy_type, global_position)
			return


## Gravity, plus removal once far below the level. Subclasses call this first
## in their _physics_process, then set velocity.x and move_and_slide().
func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += Balance.ENEMY_GRAVITY * delta
	if global_position.y > Balance.ENEMY_KILL_Y:
		queue_free()


## The whip landed: stagger and knock back away_dir (-1 / 1, away from Medusa).
## Mirror-bearers also lose their mirror for a moment. Not for statues (see Statue.whip_hit).
func whip_hit(away_dir: int) -> void:
	if _petrified or _dying:
		return
	if _exposed_left > 0.0:
		_finisher()
		return
	if is_telegraphing():
		_parry()
		return
	hp -= 1
	RunLedger.log_event("whip_hit", {"enemy": String(enemy_type), "hp": hp})
	if hp <= 0:
		_die()
		return
	_flash(Balance.COLOR_MARBLE)
	_stagger_left = Balance.WHIP_STAGGER
	velocity.x = away_dir * sqrt(2.0 * Balance.ENEMY_KNOCKBACK_DECEL * Balance.WHIP_KNOCKBACK_BL * Balance.BL)
	_on_staggered()
	SpriteKit.play(sprite, &"stagger")
	if mirror_bearer:
		knock_mirror(Balance.WHIP_MIRROR_KNOCK)


## Override: true while the enemy is winding up an attack, the moment a lash parries.
func is_telegraphing() -> bool:
	return false


## True while exposed after a parry (the gaze petrifies almost at once).
func is_exposed() -> bool:
	return _exposed_left > 0.0


## The parry: a stun long enough to act on, a gold flash, a hit-stop and a metal ting.
## While exposed the gaze needs only PARRY_GAZE_HOLD seconds.
func _parry() -> void:
	_exposed_left = Balance.PARRY_OPEN_S
	_stagger_left = Balance.PARRY_OPEN_S
	velocity.x = 0.0
	gaze_hold_time = Balance.PARRY_GAZE_HOLD
	_on_staggered()
	SpriteKit.play(sprite, &"stagger")
	_flash(Balance.COLOR_GOLD, Balance.PARRY_OPEN_S)
	Fx.play(&"mirror_glint", 0.8)
	Fx.hit_stop(Balance.HITSTOP_PARRY)
	Events.shake_requested.emit(Balance.SHAKE_PARRY_PX, Balance.SHAKE_PARRY_TIME)
	RunLedger.log_event("parry", {"enemy": String(enemy_type)})


## The snake finisher: the snakes latch on (a black line from her head to the enemy),
## the enemy shakes and turns poison-dark, then dies.
func _finisher() -> void:
	_dying = true
	_exposed_left = 0.0
	set_physics_process(false)
	Fx.play(&"hiss", 1.2)
	Fx.hit_stop(Balance.HITSTOP_FINISHER)
	var player: Player = find_player()
	if player != null:
		var latch := Line2D.new()
		latch.width = Balance.FINISHER_LATCH_WIDTH
		latch.default_color = Balance.COLOR_BLACK
		latch.top_level = true  # drawn in world space, not moved by this enemy
		latch.points = PackedVector2Array([player.global_position + Balance.WHIP_HEAD_OFFSET, global_position])
		add_child(latch)
	var tween := create_tween()
	for i in 6:  # a struggling shake
		tween.tween_property(visual, "position:x", 3.0 if i % 2 == 0 else -3.0, Balance.FINISHER_TIME / 6.0)
	tween.parallel().tween_property(visual, "modulate", Balance.FINISHER_POISON_TINT, Balance.FINISHER_TIME)
	tween.tween_callback(_die)
	RunLedger.log_event("finisher", {"enemy": String(enemy_type)})


## Death by whip: collision off, a dust puff, a slump and fade, then gone.
## Events.enemy_slain tells the ledger (and anything else) it happened.
func _die() -> void:
	_dying = true
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	Fx.play(&"statue_thud", 1.4)
	Fx.dust(global_position + Vector2(0.0, half_size.y), Balance.DUST_DEATH_COUNT)
	Events.enemy_slain.emit(enemy_type, global_position)
	RunLedger.log_event("slain", {"enemy": String(enemy_type), "level": RunLedger.level})
	var tween := create_tween().set_parallel(true)
	tween.tween_property(visual, "rotation", facing * -1.2, Balance.ENEMY_DEATH_S)
	tween.tween_property(visual, "position:y", half_size.y * 0.6, Balance.ENEMY_DEATH_S)
	tween.tween_property(self, "modulate:a", 0.0, Balance.ENEMY_DEATH_S)
	tween.chain().tween_callback(queue_free)


## A brief colour flash on the art (white on a hit, gold on a parry).
func _flash(color: Color, seconds: float = Balance.HIT_FLASH_S) -> void:
	var tween := create_tween()
	visual.modulate = color
	tween.tween_property(visual, "modulate", Color.WHITE if sprite != null else Balance.COLOR_BLACK, seconds)


## True while a whip hit still holds the enemy.
func is_staggered() -> bool:
	return _stagger_left > 0.0


## Subclasses call this right after apply_gravity(): while staggered it slides the
## enemy to a stop and returns true, and the subclass should only move_and_slide()
## and return (no AI, no attacks) for that frame.
func tick_stagger(delta: float) -> bool:
	if _stagger_left <= 0.0:
		return false
	_stagger_left -= delta
	if _exposed_left > 0.0:
		_exposed_left -= delta
		if _exposed_left <= 0.0:
			gaze_hold_time = Balance.GAZE_HOLD_EYE_SHADING if eye_shading else Balance.GAZE_HOLD
	velocity.x = move_toward(velocity.x, 0.0, Balance.ENEMY_KNOCKBACK_DECEL * delta)
	if _stagger_left <= 0.0:
		_animate()  # back on its feet: show the state's animation again
	return true


## Override to drop whatever the enemy was doing (a wind-up, a thrust) when staggered.
func _on_staggered() -> void:
	pass


## Stub for the mirror-bearer enemy (a later prompt): knock the mirror aside for
## `seconds`, so a gaze into it no longer reflects.
func knock_mirror(_seconds: float) -> void:
	pass


## The player node (group "player"), or null.
func find_player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player


## True if there is no floor just ahead of the feet in direction dir (-1 / 1).
func ledge_ahead(dir: int) -> bool:
	return not has_floor_at(global_position.x + dir * (half_size.x + Balance.ENEMY_LEDGE_PROBE_AHEAD))


## True if world or statue floor sits at x, level with this body's feet.
func has_floor_at(x: float) -> bool:
	var from := Vector2(x, global_position.y + half_size.y - Balance.ENEMY_LEDGE_PROBE_INSET)
	var query := PhysicsRayQueryParameters2D.create(from,
			from + Vector2(0.0, Balance.ENEMY_LEDGE_PROBE_DOWN + Balance.ENEMY_LEDGE_PROBE_INSET),
			Balance.PHYS_WORLD | Balance.PHYS_STATUES)
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Called by the gaze every physics frame this enemy is in the cone and visible.
func add_gaze(delta: float) -> void:
	if _petrified or _dying:
		return
	_gaze_time += delta
	var t: float = clampf(_gaze_time / gaze_hold_time, 0.0, 1.0)
	if sprite != null:
		# First frame of this gaze: put the shader on and pin where the stone starts.
		if _petrify_mat == null:
			_petrify_mat = SpriteKit.petrify_material()
			_petrify_mat.set_shader_parameter(&"origin", SpriteKit.frame_uv(sprite, gaze_from))
			sprite.material = _petrify_mat
		_petrify_mat.set_shader_parameter(&"progress", t)
	else:
		visual.modulate = Balance.COLOR_BLACK.lerp(Balance.COLOR_MARBLE, t)
	if _gaze_time >= gaze_hold_time:
		petrify()


## Called by the gaze when the enemy leaves the cone, is blocked, or gaze ends.
func reset_gaze() -> void:
	if _petrified or _gaze_time == 0.0:
		return
	_gaze_time = 0.0
	if sprite != null:
		# Drop the shader entirely (cheaper than running it at progress 0).
		sprite.material = null
		_petrify_mat = null
	else:
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
	if _petrified or _dying:
		return
	_petrified = true
	set_physics_process(false)
	if _petrify_mat != null:
		_petrify_mat.set_shader_parameter(&"progress", 1.0)  # fully stone at the hand-off
	var frame: int = pose_frame()
	var flip: bool = facing < 0
	var where: Vector2 = global_position
	Statue.from_enemy(self)
	Events.petrified.emit(enemy_type, frame, flip, where)
	queue_free()
