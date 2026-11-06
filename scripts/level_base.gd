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
## It also dresses the level from its Lighting: a painted background (Parallax2D),
## the matching terrain texture, and Greek-key bands along the top and bottom of the
## screen. Missing art leaves the plain Backdrop and placeholder tiles in place.
class_name LevelBase
extends Node2D

## Time of day. Each value maps to one tint in Balance (LIGHT_*).
enum Lighting { NOON, DUSK, TORCHLIGHT, STORM }

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const CAMERA_SCENE: PackedScene = preload("res://scenes/game_camera.tscn")

## Set this per level in the Inspector.
@export var lighting: Lighting = Lighting.NOON
## Boss arena: the exit stays shut (hidden, no trigger) until Events.boss_defeated.
@export var exit_locked: bool = false
## True for a level whose exit door is held open by a pressure plate (the cave). The
## door is shown dark and shut until the plate's `pressed` calls unlock_exit(); the
## plate's `released` calls lock_exit() again. build_levels.gd wires those signals.
@export var exit_needs_plate: bool = false

@onready var _spawn: Marker2D = $Spawn
@onready var _exit: Area2D = $LevelExit
@onready var _exit_trigger: CollisionShape2D = $LevelExit/Trigger
@onready var _exit_art: Polygon2D = $LevelExit/Art
@onready var _tint: CanvasModulate = $Tint
@onready var _backdrop: CanvasItem = $Backdrop
@onready var _terrain: TileMapLayer = $Terrain

## Waits between lightning flashes (storm only).
var _lightning_timer: Timer


func _ready() -> void:
	_tint.color = _base_color()
	(_backdrop as Polygon2D).color = Balance.COLOR_BACKDROP
	_build_world_art()
	_build_exit()
	_spawn_player()
	_exit.body_entered.connect(_on_exit_body_entered)
	if exit_locked:
		_exit.visible = false
		_exit.monitoring = false
		Events.boss_defeated.connect(unlock_exit)
	elif exit_needs_plate:
		lock_exit()
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


## Background, terrain texture and meander bands for this level's Lighting.
func _build_world_art() -> void:
	var index: int = int(lighting)
	var bg: Texture2D = _load_texture(Balance.LEVEL_BACKGROUNDS[index])
	if bg != null:
		# The painting is 720 px tall like the screen: it slides sideways a little with
		# the camera (PARALLAX_BG_SCROLL) and stays put vertically (scroll y = 0).
		# It is drawn at 1 / CAMERA_ZOOM so it keeps its on-screen size while the
		# camera zooms in on the characters: the scenery reads as far away, not huge.
		var unzoom: float = 1.0 / Balance.CAMERA_ZOOM
		var bg_art: Sprite2D = _add_parallax(bg, Vector2(Balance.PARALLAX_BG_SCROLL, 0.0), Vector2.ZERO, unzoom, Balance.PARALLAX_BG_Z)
		# Haze pushes the painting back so the characters and terrain read in front.
		var haze := ShaderMaterial.new()
		haze.shader = load("res://shaders/haze.gdshader")
		haze.set_shader_parameter("haze_color", Balance.LEVEL_HAZE_COLOR[index])
		haze.set_shader_parameter("amount", Balance.LEVEL_HAZE_AMOUNT[index])
		bg_art.material = haze
		_backdrop.visible = false
	_build_terrain_art(index)
	var band: Texture2D = _load_texture(Balance.MEANDER_TEXTURE)
	if band != null:
		_add_meander_bands(band)


## The Greek-key bands along the top and bottom screen edges. They sit on their own
## CanvasLayer (screen space), so camera zoom and limits never move them; a world-space
## Parallax2D band drifted into the middle of the ground once the camera zoomed in.
## TextureRect's TILE stretch repeats the 40 px tile; scale shrinks it to MEANDER_HEIGHT.
func _add_meander_bands(band: Texture2D) -> void:
	var layer := CanvasLayer.new()
	layer.layer = Balance.HUD_LAYER - 2  # above the world, below the portrait HUD
	add_child(layer)
	var screen: Vector2 = get_viewport_rect().size
	var band_scale: float = Balance.MEANDER_HEIGHT / band.get_height()
	for top: bool in [true, false]:
		var rect := TextureRect.new()
		rect.texture = band
		rect.stretch_mode = TextureRect.STRETCH_TILE
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.size = Vector2(screen.x / band_scale, band.get_height())
		rect.scale = Vector2.ONE * band_scale
		rect.position = Vector2(0.0, 0.0 if top else screen.y - Balance.MEANDER_HEIGHT)
		layer.add_child(rect)


## One repeating Parallax2D layer holding `texture` drawn from `top_left` (screen px)
## at `art_scale`. repeat_size makes it tile left and right forever.
func _add_parallax(texture: Texture2D, scroll: Vector2, top_left: Vector2, art_scale: float, z: int) -> Sprite2D:
	var layer := Parallax2D.new()
	layer.scroll_scale = scroll
	layer.repeat_size = Vector2(texture.get_width() * art_scale, 0.0)
	layer.repeat_times = Balance.PARALLAX_REPEAT_TIMES
	layer.z_index = z
	var art := Sprite2D.new()
	art.texture = texture
	art.centered = false
	art.position = top_left
	art.scale = Vector2.ONE * art_scale
	# A tile narrower than the screen (the meander) is drawn as one long strip: the
	# sprite shows a region wider than the screen and texture_repeat tiles it inside.
	# Parallax2D then only has to wrap the strip by one tile width.
	var screen_w: float = get_viewport_rect().size.x / Balance.CAMERA_ZOOM  # view width in world px
	if texture.get_width() * art_scale < screen_w:
		art.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		art.region_enabled = true
		var tiles_across: int = ceili(screen_w / (texture.get_width() * art_scale)) + 2
		art.region_rect = Rect2(0.0, 0.0, texture.get_width() * tiles_across, texture.get_height())
	layer.add_child(art)
	add_child(layer)
	move_child(layer, 0)  # behind the level's own nodes in tree order
	return art


## The terrain look (shaders/terrain.gdshader): a seamless painted surface drawn in
## world space, with black outlines on exposed sides and a Greek-key lip on exposed
## tops. Each cell is switched to one of 16 marker tiles whose atlas x is a bit set of
## its exposed sides (1 top, 2 left, 4 right, 8 bottom); the shader reads it back.
## If any art is missing, the terrain keeps its plain placeholder tiles.
func _build_terrain_art(index: int) -> void:
	var surface: Texture2D = _load_texture(Balance.LEVEL_SURFACE[index])
	var markers: Texture2D = _load_texture(Balance.TERRAIN_EDGE_ATLAS)
	if surface == null or markers == null or _terrain.tile_set == null:
		return
	# Copy the shared TileSet (deep, so the atlas source is copied too), then give the
	# copy the marker atlas and 15 more tiles with the same collision as tile (0, 0).
	var tile_set := _terrain.tile_set.duplicate(true) as TileSet
	var source := tile_set.get_source(tile_set.get_source_id(0)) as TileSetAtlasSource
	if source == null:
		return
	source.texture = markers
	var base: TileData = source.get_tile_data(Vector2i.ZERO, 0)
	for depth in range(8):
		for flags in range(16):
			var coords := Vector2i(flags, depth)
			if coords == Vector2i.ZERO:
				continue  # the original tile, which already has its collision
			if not source.has_tile(coords):
				source.create_tile(coords)
			var data: TileData = source.get_tile_data(coords, 0)
			for i in base.get_collision_polygons_count(0):
				data.add_collision_polygon(0)
				data.set_collision_polygon_points(0, i, base.get_collision_polygon_points(0, i))
	_terrain.tile_set = tile_set
	var source_id: int = tile_set.get_source_id(0)
	# Ground goes all the way down: any cell at ground level or below with nothing under
	# it is extended to TERRAIN_BOTTOM_ROW, so the playable ground is one solid mass to
	# the bottom of the view (no slab floating over the painting). Floating ledges above
	# ground level are left as they are.
	for cell: Vector2i in _terrain.get_used_cells():
		if cell.y >= Balance.TERRAIN_GROUND_ROW and _terrain.get_cell_source_id(cell + Vector2i.DOWN) == -1:
			for row in range(cell.y + 1, Balance.TERRAIN_BOTTOM_ROW + 1):
				_terrain.set_cell(Vector2i(cell.x, row), source_id, Vector2i.ZERO)
	# Re-tile: an "exposed" side is one with no terrain cell next to it. The atlas row
	# is the depth: how many solid cells sit above this one (0 = a top surface), capped
	# at 7. The shader darkens the rock with depth, like light falling off underground.
	for cell: Vector2i in _terrain.get_used_cells():
		var flags: int = 0
		if _terrain.get_cell_source_id(cell + Vector2i.UP) == -1:
			flags |= 1
		if _terrain.get_cell_source_id(cell + Vector2i.LEFT) == -1:
			flags |= 2
		if _terrain.get_cell_source_id(cell + Vector2i.RIGHT) == -1:
			flags |= 4
		if _terrain.get_cell_source_id(cell + Vector2i.DOWN) == -1:
			flags |= 8
		var depth: int = 0
		while depth < 7 and _terrain.get_cell_source_id(cell + Vector2i(0, -(depth + 1))) != -1:
			depth += 1
		_terrain.set_cell(cell, source_id, Vector2i(flags, depth))
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/terrain.gdshader")
	mat.set_shader_parameter("surface", surface)
	mat.set_shader_parameter("surface_px", Balance.TERRAIN_SURFACE_PX)
	mat.set_shader_parameter("tint", Balance.LEVEL_SURFACE_TINT[index])
	mat.set_shader_parameter("lip", _load_texture(Balance.MEANDER_TEXTURE))
	mat.set_shader_parameter("lip_px", Balance.TERRAIN_LIP_PX)
	mat.set_shader_parameter("edge_px", Balance.TERRAIN_EDGE_PX)
	mat.set_shader_parameter("edge_color", Balance.COLOR_BLACK)
	mat.set_shader_parameter("atlas_tiles", 16.0)
	mat.set_shader_parameter("atlas_rows", 8.0)
	mat.set_shader_parameter("tile_px", float(Balance.TILE_SIZE))
	mat.set_shader_parameter("deep_color", Balance.TERRAIN_DEEP_COLOR[index])
	mat.set_shader_parameter("deep_px", Balance.TERRAIN_DEEP_PX)
	mat.set_shader_parameter("deep_max", Balance.TERRAIN_DEEP_MAX)
	_terrain.material = mat


## Load a texture if the file exists; null (and no error popup) if it does not.
func _load_texture(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


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
	# The painted temple doorway replaces the marble arch when the art is there.
	if SpriteKit.prop(_exit, &"exit_door") != null:
		_exit_art.visible = false


## Put Medusa and her follow camera on the spawn marker.
func _spawn_player() -> void:
	var player: Node2D = PLAYER_SCENE.instantiate()
	# Position first: Player remembers where it was first added as its respawn point.
	player.position = _spawn.position
	add_child(player)
	var camera := CAMERA_SCENE.instantiate() as Camera2D
	camera.zoom = Vector2.ONE * Balance.CAMERA_ZOOM
	# Keep the view inside the level: never past its side walls or below the ground.
	var used: Rect2i = _terrain.get_used_rect()
	camera.limit_left = used.position.x * Balance.TILE_SIZE
	camera.limit_right = used.end.x * Balance.TILE_SIZE
	camera.limit_bottom = (Balance.TERRAIN_BOTTOM_ROW + 1) * Balance.TILE_SIZE
	player.add_child(camera)


## Open the exit (shown, trigger on). Deferred: it may be called during a physics callback.
func unlock_exit() -> void:
	_exit.visible = true
	_exit.modulate = Color.WHITE
	_exit.set_deferred("monitoring", true)


## Shut the exit again (plate released): the door stays visible but dark, and walking
## into it does nothing. Deferred like unlock_exit.
func lock_exit() -> void:
	_exit.visible = true
	_exit.modulate = Balance.EXIT_LOCKED_TINT
	_exit.set_deferred("monitoring", false)


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
