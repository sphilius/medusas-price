## test_room.gd (root script of scenes/test_room.tscn)
## Purpose: level 1 graybox. The pit under the gap and the safe ledges put Medusa back
## on her feet (see Player), so this script only keeps the room solvable: the gap can
## only be crossed on a leaper frozen mid-leap, so if a fall finds no leaper and no
## leaper statue left in the room, a fresh leaper appears at its starting spot.
## Debug builds only: F10 asks the AI Worker's /test endpoint for an image and shows it
## (proves the Worker round trip). Release builds never create that sprite.
extends Node2D

const LEAPER_SCENE: PackedScene = preload("res://scenes/enemies/leaper.tscn")

## Where the room's leaper starts (taken from the scene).
var _leaper_home: Vector2 = Vector2.ZERO
## True when a replacement leaper is owed but Medusa is standing on its spawn point
## (the far safe ledge sits right there). Spawning on top of her would shove her body
## toward the gap and hurt her, so it waits until she has stepped clear.
var _leaper_pending: bool = false
## Debug-only F10 test image, made in code on the first success (null until then).
var _ai_debug_sprite: Sprite2D = null


func _ready() -> void:
	_leaper_home = $Leaper.position
	Events.player_fell.connect(_on_player_fell)
	if OS.is_debug_build():
		AIClient.completed.connect(_on_ai_completed)


## Events.player_fell (a signal on the Events autoload) fires on every pit fall. The
## Player's own handler already moved her to the safe ledge, so here we only note that
## the room owes a leaper; _physics_process decides when it is safe to spawn it.
func _on_player_fell(_where: Vector2) -> void:
	if not _has_leaper():
		_leaper_pending = true


## Spawn an owed leaper once Medusa is clear of its spawn point. A cheap check each
## physics frame, and only while one is owed (almost never).
func _physics_process(_delta: float) -> void:
	if not _leaper_pending:
		return
	var player := get_node_or_null("Player") as Node2D
	if player and player.global_position.distance_to(_leaper_home) < Balance.LEAPER_RESPAWN_CLEARANCE_BL * Balance.BL:
		return
	_leaper_pending = false
	var leaper: Node2D = LEAPER_SCENE.instantiate()
	leaper.name = "Leaper"
	leaper.position = _leaper_home
	add_child.call_deferred(leaper)


## A live leaper in the room, or a leaper statue that has not shattered.
func _has_leaper() -> bool:
	for child in get_children():
		if child is Enemy and (child as Enemy).enemy_type == &"leaper" and not child.is_queued_for_deletion():
			return true
	for node in get_tree().get_nodes_in_group(&"statues"):
		var statue := node as Statue
		if statue != null and statue.enemy_type == &"leaper" and statue.state != Statue.State.SHATTERED \
				and not statue.is_queued_for_deletion():
			return true
	return false


## Debug only: F10 sends one /test request to the AI Worker.
func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	# `as` casts to InputEventKey, or gives null when the event is a mouse/joypad event.
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_F10:
		AIClient.request("/test", {}, Balance.AI_TEST_TIMEOUT_S)


## Worker answered. Only a successful /test is shown; any failure does nothing (no text).
func _on_ai_completed(endpoint: String, ok: bool, data: Dictionary) -> void:
	if endpoint != "/test" or not ok:
		return
	var texture: ImageTexture = _texture_from_base64(str(data.get("image", "")), str(data.get("mime", "")))
	if texture == null:
		return
	if _ai_debug_sprite == null:
		# Its own CanvasLayer draws in screen space, so the follow camera cannot move it
		# off screen; layer 100 keeps it above the portrait HUD.
		var layer := CanvasLayer.new()
		layer.layer = 100
		add_child(layer)
		_ai_debug_sprite = Sprite2D.new()
		_ai_debug_sprite.position = Balance.AI_DEBUG_SPRITE_POS
		layer.add_child(_ai_debug_sprite)
	_ai_debug_sprite.texture = texture
	# Scale evenly so the longest side is AI_DEBUG_SPRITE_SIZE px.
	var longest: float = maxf(texture.get_width(), texture.get_height())
	_ai_debug_sprite.scale = Vector2.ONE * (Balance.AI_DEBUG_SPRITE_SIZE / longest)


## Base64 image bytes + MIME type -> texture, or null if the type is unknown or the
## bytes do not decode.
func _texture_from_base64(b64: String, mime: String) -> ImageTexture:
	if b64.is_empty():
		return null
	var bytes: PackedByteArray = Marshalls.base64_to_raw(b64)
	var image := Image.new()
	var err: Error
	match mime:
		"image/png":
			err = image.load_png_from_buffer(bytes)
		"image/jpeg", "image/jpg":
			err = image.load_jpg_from_buffer(bytes)
		"image/webp":
			err = image.load_webp_from_buffer(bytes)
		_:
			return null
	if err != OK or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)
