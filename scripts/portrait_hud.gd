## portrait_hud.gd (root script of scenes/ui/portrait_hud.tscn)
## Purpose: the only HUD. A round shield in the top-left corner showing Medusa's
## portrait: one painting per stage, one white hairline crack per crack taken, a white
## flash when the stage changes. Small reactions: flinch on a hit, snap on a petrify,
## soften at a pool. Also owns the grayscale veil that plays when she turns to stone.
## No words, no numbers: only shapes, colors and the paintings.
## The paintings are placeholder solid-color circles (Balance.PORTRAIT_STAGE_COLORS)
## until the real art arrives; swap _stage_textures for the real five.
extends CanvasLayer

const DESATURATE: Shader = preload("res://shaders/desaturate.gdshader")

## One round placeholder texture per stage (index = stage - 1).
var _stage_textures: Array[Texture2D] = []
## The crack hairlines currently drawn, in the order they appeared.
var _lines: Array[Line2D] = []
## Where the shield rests, and the totals last drawn (a rise means a new crack).
var _base_pos: Vector2 = Vector2.ZERO
var _last_total: int = 0
## Varies the crack pattern between runs; the same (stage, index) still draws the same crack.
var _salt: int = 0
var _shake_tween: Tween = null
var _pulse_tween: Tween = null
var _flash_tween: Tween = null
var _glow_tween: Tween = null
var _veil_tween: Tween = null

@onready var _shield: Control = $Shield
@onready var _painting: TextureRect = $Shield/Painting
@onready var _cracks: Control = $Shield/Cracks
@onready var _frame: Line2D = $Shield/Frame
@onready var _glow: Polygon2D = $Shield/Glow
@onready var _flash: Polygon2D = $Shield/Flash
@onready var _veil: ColorRect = $DeathFx/Veil


func _ready() -> void:
	layer = Balance.HUD_LAYER
	$DeathFx.layer = Balance.HUD_LAYER - 1
	_salt = randi()
	var size: float = Balance.HUD_SIZE
	_base_pos = Vector2(Balance.HUD_MARGIN, Balance.HUD_MARGIN)
	_shield.position = _base_pos
	_shield.size = Vector2(size, size)
	_shield.pivot_offset = Vector2(size, size) * 0.5
	_painting.position = Vector2.ZERO
	_painting.size = Vector2(size, size)
	_painting.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_painting.stretch_mode = TextureRect.STRETCH_SCALE
	# Craquelure: the damage is painted into the portrait (shaders/portrait_crack.gdshader).
	if ResourceLoader.exists(Balance.PORTRAIT_CRACK_SHADER):
		var crack_mat := ShaderMaterial.new()
		crack_mat.shader = load(Balance.PORTRAIT_CRACK_SHADER)
		crack_mat.set_shader_parameter(&"crack_color", Balance.COLOR_BLACK)
		crack_mat.set_shader_parameter(&"flake_color", Balance.COLOR_MARBLE)
		_painting.material = crack_mat
	var center := Vector2(size, size) * 0.5
	_frame.points = _circle(center, size * 0.5 - Balance.HUD_FRAME_WIDTH * 0.5)
	_frame.closed = true
	_frame.width = Balance.HUD_FRAME_WIDTH
	_frame.default_color = Balance.COLOR_BLACK
	var inner: PackedVector2Array = _circle(center, size * 0.5 - Balance.HUD_FRAME_WIDTH)
	_flash.polygon = inner
	# Flash and glow fade through modulate, not color: recoloring a polygon every frame
	# makes the Web (WebGL2) renderer warn. They are only drawn while they play.
	_flash.color = Balance.COLOR_MARBLE
	_flash.modulate.a = 0.0
	_flash.visible = false
	_glow.polygon = inner
	_glow.color = Balance.COLOR_TERRACOTTA
	_glow.modulate.a = 0.0
	_glow.visible = false
	_veil.material = _make_veil_material()
	_veil.visible = false
	# The five painted stages (Defiant .. Stone). If a painting is missing, that stage
	# silently falls back to the old flat colored disc.
	for i in Balance.PORTRAIT_STAGE_COLORS.size():
		var path: String = Balance.PORTRAIT_TEXTURES[i] if i < Balance.PORTRAIT_TEXTURES.size() else ""
		var painting: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
		_stage_textures.append(painting if painting != null else _make_painting(Balance.PORTRAIT_STAGE_COLORS[i]))
	_show_stage(PortraitState.stage)
	_sync_cracks(PortraitState.cracks_in_stage)
	_last_total = PortraitState.total_cracks()
	PortraitState.stage_changed.connect(_on_stage_changed)
	PortraitState.cracked.connect(_on_cracked)
	Events.shard_collected.connect(_on_shard_collected)
	PortraitState.ward_changed.connect(_on_ward_changed)
	_build_ward()
	PortraitState.healed.connect(_on_healed)
	Events.player_died.connect(_on_player_died)
	Events.player_respawned.connect(_on_player_respawned)


func _show_stage(stage: int) -> void:
	_painting.texture = _stage_textures[clampi(stage, 1, _stage_textures.size()) - 1]


## Swap the painting, clear the cracks and flash white.
func _on_stage_changed(stage: int) -> void:
	_show_stage(stage)
	_sync_cracks(0)
	_kill(_flash_tween)
	_flash.modulate.a = Balance.HUD_FLASH_ALPHA
	_flash.visible = true
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "modulate:a", 0.0, Balance.HUD_FLASH_TIME)
	_flash_tween.tween_callback(func() -> void: _flash.visible = false)


## Draw exactly n hairlines; a new crack makes the shield flinch (or snap, for a petrify).
func _on_cracked(total_in_stage: int) -> void:
	_sync_cracks(total_in_stage)
	var total: int = PortraitState.total_cracks()
	if total > _last_total:
		if PortraitState.last_source == &"petrify":
			_snap()
		else:
			_flinch()
	_last_total = total


func _on_healed(_stage: int) -> void:
	_last_total = PortraitState.total_cracks()
	_soften()


## Medusa turning to stone: the world fades to gray over the same time as her tint.
func _on_player_died(_position: Vector2) -> void:
	_kill(_veil_tween)
	_set_veil(0.0)
	_veil.visible = true
	_veil_tween = create_tween()
	_veil_tween.tween_method(_set_veil, 0.0, 1.0, Balance.DEATH_STONE_TIME)


func _on_player_respawned(_position: Vector2) -> void:
	_kill(_veil_tween)
	_veil_tween = create_tween()
	_veil_tween.tween_method(_set_veil, 1.0, 0.0, Balance.DEATH_FADE_BACK_TIME)
	_veil_tween.tween_callback(func() -> void: _veil.visible = false)


func _set_veil(amount: float) -> void:
	(_veil.material as ShaderMaterial).set_shader_parameter("amount", amount)


# ---------------------------------------------------------------------------
# Cracks
# ---------------------------------------------------------------------------

## Add or remove hairlines until exactly n are drawn.
func _sync_cracks(n: int) -> void:
	# The craquelure shader on the painting shows the damage; the old overlay lines are
	# only kept as a fallback if the shader is missing.
	var crack_mat := _painting.material as ShaderMaterial
	if crack_mat != null:
		var need: float = float(PortraitState.threshold(PortraitState.stage))
		crack_mat.set_shader_parameter(&"amount", clampf(n / maxf(need, 1.0), 0.0, 1.0))
		crack_mat.set_shader_parameter(&"wear", float(PortraitState.stage - 1) / float(maxi(Balance.PORTRAIT_STAGE_COUNT - 1, 1)))
		return
	while _lines.size() > n:
		_lines.pop_back().queue_free()
	while _lines.size() < n:
		var line: Line2D = _make_crack(PortraitState.stage, _lines.size())
		_cracks.add_child(line)
		_lines.append(line)


## A jagged hairline from the rim toward the middle. The same (stage, index, salt)
## always draws the same crack, so it does not jump around when redrawn.
func _make_crack(stage: int, index: int) -> Line2D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([stage, index, _salt])
	var radius: float = Balance.HUD_SIZE * 0.5
	var center := Vector2(radius, radius)
	var angle: float = rng.randf() * TAU
	var lean: float = rng.randf_range(-0.6, 0.6)
	var reach: float = rng.randf_range(Balance.CRACK_REACH_MIN, Balance.CRACK_REACH_MAX)
	var from: Vector2 = center + Vector2.from_angle(angle) * radius
	var to: Vector2 = center + Vector2.from_angle(angle + lean) * radius * (1.0 - reach)
	var side: Vector2 = (to - from).orthogonal().normalized()
	var line := Line2D.new()
	line.width = Balance.CRACK_LINE_WIDTH
	line.default_color = Balance.COLOR_MARBLE
	# The dark edge is a child drawn behind the hairline, so removing the crack removes both.
	var edge := Line2D.new()
	edge.width = Balance.CRACK_EDGE_WIDTH
	edge.default_color = Color(Balance.COLOR_BLACK, Balance.CRACK_EDGE_ALPHA)
	edge.show_behind_parent = true
	line.add_child(edge)
	for i in Balance.CRACK_POINTS:
		var t: float = float(i) / (Balance.CRACK_POINTS - 1)
		var stray: float = 0.0 if i == 0 or i == Balance.CRACK_POINTS - 1 else rng.randf_range(-1.0, 1.0) * Balance.CRACK_JITTER * radius
		var point: Vector2 = from.lerp(to, t) + side * stray
		line.add_point(point)
		edge.add_point(point)
	return line


# ---------------------------------------------------------------------------
# Reactions (each restarts from the resting pose)
# ---------------------------------------------------------------------------

## A hit: a quick shake while the shield dips smaller.
func _flinch() -> void:
	_rest()
	var step: float = Balance.HUD_FLINCH_TIME * 0.25
	var px: float = Balance.HUD_FLINCH_PX
	_shake_tween = create_tween()
	_shake_tween.tween_property(_shield, "position", _base_pos + Vector2(px, 0.0), step)
	_shake_tween.tween_property(_shield, "position", _base_pos + Vector2(-px * 0.6, 0.0), step)
	_shake_tween.tween_property(_shield, "position", _base_pos + Vector2(px * 0.3, 0.0), step)
	_shake_tween.tween_property(_shield, "position", _base_pos, step)
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(_shield, "scale", Vector2.ONE * Balance.HUD_FLINCH_SCALE, Balance.HUD_FLINCH_TIME * 0.3)
	_pulse_tween.tween_property(_shield, "scale", Vector2.ONE, Balance.HUD_FLINCH_TIME * 0.7)


## A shard was picked up: a gold sparkle flies from where it was (converted from world
## to screen position with the viewport's canvas transform) into the portrait, which
## then swells gently, so the player sees that shards mend the painting.
func _on_shard_collected(world_pos: Vector2) -> void:
	var sparkle := Polygon2D.new()
	sparkle.polygon = SpriteKit.sparkle(Balance.SHARD_FLY_SIZE)
	sparkle.color = Balance.COLOR_GOLD
	sparkle.position = get_viewport().get_canvas_transform() * world_pos
	add_child(sparkle)
	var target: Vector2 = _shield.global_position + Vector2.ONE * Balance.HUD_SIZE * 0.5
	var fly := create_tween()
	fly.tween_property(sparkle, "position", target, Balance.SHARD_FLY_S).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fly.parallel().tween_property(sparkle, "rotation", TAU, Balance.SHARD_FLY_S)
	fly.tween_callback(sparkle.queue_free)
	fly.tween_callback(func() -> void:
		_rest()
		_pulse_tween = create_tween()
		_pulse_tween.tween_property(_shield, "scale", Vector2.ONE * Balance.SHARD_PULSE_SCALE, 0.12)
		_pulse_tween.tween_property(_shield, "scale", Vector2.ONE, 0.3))


## Gold ward rings drawn around the portrait (one per ring PortraitState.ward holds).
## A plain Node2D on the shield draws them through its `draw` signal.
var _ward: Node2D = null


func _build_ward() -> void:
	_ward = Node2D.new()
	_ward.position = Vector2.ONE * Balance.HUD_SIZE * 0.5
	_ward.draw.connect(func() -> void:
		for i in PortraitState.ward:
			var r: float = Balance.HUD_SIZE * 0.5 + Balance.WARD_RING_GAP * (i + 1)
			_ward.draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Balance.COLOR_GOLD, Balance.WARD_RING_WIDTH, true))
	_shield.add_child(_ward)


## A ring was added (shard) or used up (it took a crack): redraw, and pulse the shield.
func _on_ward_changed(_rings: int) -> void:
	_ward.queue_redraw()
	_rest()
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(_shield, "scale", Vector2.ONE * Balance.SHARD_PULSE_SCALE, 0.12)
	_pulse_tween.tween_property(_shield, "scale", Vector2.ONE, 0.3)


## A petrify: a crisp pop outward and back, like a stone snapping into place.
func _snap() -> void:
	_rest()
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(_shield, "scale", Vector2.ONE * Balance.HUD_SNAP_SCALE, Balance.HUD_SNAP_TIME * 0.4)
	_pulse_tween.tween_property(_shield, "scale", Vector2.ONE, Balance.HUD_SNAP_TIME * 0.6)


## A pool: the shield swells gently and a warm glow fades out over it.
func _soften() -> void:
	_rest()
	_kill(_glow_tween)
	_glow.modulate.a = Balance.HUD_SOFTEN_ALPHA
	_glow.visible = true
	_glow_tween = create_tween()
	_glow_tween.tween_property(_glow, "modulate:a", 0.0, Balance.HUD_SOFTEN_TIME)
	_glow_tween.tween_callback(func() -> void: _glow.visible = false)
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(_shield, "scale", Vector2.ONE * Balance.HUD_SOFTEN_SCALE, Balance.HUD_SOFTEN_TIME * 0.4).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(_shield, "scale", Vector2.ONE, Balance.HUD_SOFTEN_TIME * 0.6).set_trans(Tween.TRANS_SINE)


## Stop any reaction in flight and put the shield back where it rests.
func _rest() -> void:
	_kill(_shake_tween)
	_kill(_pulse_tween)
	_shield.position = _base_pos
	_shield.scale = Vector2.ONE


func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()


# ---------------------------------------------------------------------------
# Drawing helpers
# ---------------------------------------------------------------------------

func _circle(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in Balance.HUD_CIRCLE_SEGMENTS:
		points.append(center + Vector2.from_angle(TAU * i / Balance.HUD_CIRCLE_SEGMENTS) * radius)
	return points


## A solid-color disc with a one-pixel soft edge on a transparent square.
func _make_painting(color: Color) -> Texture2D:
	var side: int = Balance.HUD_TEXTURE_SIZE
	var image := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	var radius: float = side * 0.5
	for y in side:
		for x in side:
			var distance: float = Vector2(x + 0.5, y + 0.5).distance_to(Vector2(radius, radius))
			image.set_pixel(x, y, Color(color, clampf(radius - distance, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)


func _make_veil_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = DESATURATE
	material.set_shader_parameter("amount", 0.0)
	material.set_shader_parameter("marble_color", Balance.COLOR_MARBLE)
	material.set_shader_parameter("marble_mix", Balance.DEATH_VEIL_MARBLE_MIX)
	return material
