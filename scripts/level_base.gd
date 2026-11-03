## level_base.gd (root script of scenes/levels/level_base.tscn)
## Purpose: the kit every level is built from. Make a level by choosing
## Scene > New Inherited Scene > level_base.tscn, then in the editor:
##   - paint terrain on the "Terrain" TileMapLayer (32 px tiles, placeholder terracotta),
##   - drag "Spawn" to where Medusa starts,
##   - drag "LevelExit" to the door, then drop props/enemies in as children,
##   - pick the time of day with "Lighting" in the Inspector (tints the level when it runs).
## At runtime this script puts Medusa (with her camera) on the spawn marker, tints the
## level, and tells the rest of the game when she reaches the exit. In the STORM
## lighting it also flashes lightning every 6 to 12 seconds.
## Torchlight levels are dark; place scenes/props/torch.tscn to light them.
class_name LevelBase
extends Node2D

## Time of day. Each value maps to one tint in Balance (LIGHT_*).
enum Lighting { NOON, DUSK, TORCHLIGHT, STORM }

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const CAMERA_SCENE: PackedScene = preload("res://scenes/game_camera.tscn")

## Set this per level in the Inspector.
@export var lighting: Lighting = Lighting.NOON

@onready var _spawn: Marker2D = $Spawn
@onready var _exit: Area2D = $LevelExit
@onready var _exit_trigger: CollisionShape2D = $LevelExit/Trigger
@onready var _exit_art: Polygon2D = $LevelExit/Art
@onready var _tint: CanvasModulate = $Tint

## Waits between lightning flashes (storm only).
var _lightning_timer: Timer


func _ready() -> void:
	_tint.color = _base_color()
	_build_exit()
	_spawn_player()
	_exit.body_entered.connect(_on_exit_body_entered)
	if lighting == Lighting.STORM:
		_lightning_timer = Timer.new()
		_lightning_timer.one_shot = true
		_lightning_timer.timeout.connect(_on_lightning_timer_timeout)
		add_child(_lightning_timer)
		_schedule_lightning()


## The tint color for the chosen time of day.
func _base_color() -> Color:
	match lighting:
		Lighting.DUSK:
			return Balance.LIGHT_DUSK
		Lighting.TORCHLIGHT:
			return Balance.LIGHT_TORCH
		Lighting.STORM:
			return Balance.LIGHT_STORM
	return Balance.LIGHT_NOON


## Size the exit trigger and draw its door (a marble arch: no words).
func _build_exit() -> void:
	_exit.collision_layer = 0
	_exit.collision_mask = Balance.PHYS_PLAYER
	_exit.monitorable = false
	var size := Vector2(Balance.LEVEL_EXIT_WIDTH_BL, Balance.LEVEL_EXIT_HEIGHT_BL) * Balance.BL
	var zone := RectangleShape2D.new()
	zone.size = size
	_exit_trigger.shape = zone
	# The LevelExit origin sits on the floor; the door rises above it.
	_exit_trigger.position = Vector2(0.0, -size.y * 0.5)
	var half: float = size.x * 0.5
	_exit_art.polygon = PackedVector2Array([
			Vector2(-half, 0.0), Vector2(-half, -size.y * 0.8), Vector2(0.0, -size.y),
			Vector2(half, -size.y * 0.8), Vector2(half, 0.0)])
	_exit_art.color = Balance.COLOR_MARBLE


## Put Medusa and her follow camera on the spawn marker.
func _spawn_player() -> void:
	var player: Node2D = PLAYER_SCENE.instantiate()
	# Position first: Player remembers where it was first added as its respawn point.
	player.position = _spawn.position
	add_child(player)
	player.add_child(CAMERA_SCENE.instantiate())


func _on_exit_body_entered(body: Node2D) -> void:
	if body is Player:
		Events.level_exit_reached.emit()


func _schedule_lightning() -> void:
	_lightning_timer.start(randf_range(Balance.LIGHTNING_MIN_S, Balance.LIGHTNING_MAX_S))


func _on_lightning_timer_timeout() -> void:
	_flash_lightning()
	_schedule_lightning()


## Two quick flashes (flash, fade, flash, fade), then back to the storm tint.
func _flash_lightning() -> void:
	var base: Color = _base_color()
	var tween: Tween = create_tween()
	for i in 2:
		tween.tween_property(_tint, "color", Balance.LIGHTNING_COLOR, 0.0)
		tween.tween_interval(Balance.LIGHTNING_HOLD_S)
		tween.tween_property(_tint, "color", base, Balance.LIGHTNING_FADE_S)
		if i == 0:
			tween.tween_interval(Balance.LIGHTNING_DOUBLE_GAP_S)
