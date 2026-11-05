## sprite_kit.gd (static helper class, not attached to any node)
## Purpose: puts the real character art on a body. attach() builds an AnimatedSprite2D
## from Balance.SPRITE_ART, sizes it to the hitbox, stands it on the body's feet and
## hides the old placeholder polygons. If the art is missing it returns null and the
## placeholders stay visible (the game never breaks over a missing file).
## Also makes weapon sprites from Balance.WEAPON_ART, and the petrify / marble shader
## materials with their colors and settings filled in from Balance.
class_name SpriteKit
extends RefCounted

const PETRIFY_SHADER: Shader = preload("res://shaders/petrify.gdshader")
const MARBLE_SHADER: Shader = preload("res://shaders/marble.gdshader")


## Adds the character `art` (a key of Balance.SPRITE_ART) under `visual` and returns
## the sprite, or null if the art could not be loaded. `visual` is the node the
## scripts flip and tint, so the sprite flips with it for free.
static func attach(visual: Node2D, art: StringName) -> AnimatedSprite2D:
	var info: Dictionary = Balance.SPRITE_ART.get(art, {})
	if info.is_empty() or not ResourceLoader.exists(info["frames"]):
		return null
	var frames := load(info["frames"]) as SpriteFrames
	if frames == null:
		return null
	# Animation speeds come from Balance, not from the .tres (the .tres is generated).
	var speeds: Dictionary = Balance.ANIM_FPS.get(art, {})
	for anim: StringName in speeds:
		if frames.has_animation(anim):
			frames.set_animation_speed(anim, speeds[anim])

	var sprite := AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.sprite_frames = frames
	sprite.offset = info["offset"]
	sprite.scale = Vector2.ONE * (float(info["height"]) / float(info["figure_h"]))
	sprite.position = Vector2(0.0, info["feet_y"])
	# Hide the placeholder shapes that sit directly under Visual (Body, Helmet, ...).
	# Weapon holders (Spear, Mirror) are Node2D, not Polygon2D, so they stay.
	for child: Node in visual.get_children():
		if child is Polygon2D:
			(child as Polygon2D).visible = false
	visual.add_child(sprite)
	# Draw the body behind the weapons that are already children of Visual.
	visual.move_child(sprite, 0)
	sprite.play(frames.get_animation_names()[0])
	return sprite


## Switch `sprite` to animation `anim` (and restart a one-shot pose). Does nothing if
## the sprite is missing, the animation does not exist, or it is already playing it,
## so calling it every time a state changes is cheap and safe.
static func play(sprite: AnimatedSprite2D, anim: StringName, speed_scale: float = 1.0) -> void:
	if sprite == null or not sprite.sprite_frames.has_animation(anim):
		return
	sprite.speed_scale = speed_scale
	if sprite.animation == anim and sprite.is_playing():
		return
	sprite.play(anim)


## Replaces the placeholder polygons under `holder` (e.g. Visual/Spear) with the weapon
## sprite `weapon` (a key of Balance.WEAPON_ART). The holder keeps its position, so the
## code that slides or swings it keeps working. Returns the sprite, or null on failure.
## The art's middle goes to the WEAPON_ART "center" point inside the holder.
static func weapon(holder: Node2D, weapon_name: StringName) -> Sprite2D:
	var info: Dictionary = Balance.WEAPON_ART.get(weapon_name, {})
	if info.is_empty() or not ResourceLoader.exists(info["texture"]):
		return null
	var texture := load(info["texture"]) as Texture2D
	if texture == null:
		return null
	var sprite := Sprite2D.new()
	sprite.name = "Art"
	sprite.texture = texture
	var longest: float = maxf(texture.get_width(), texture.get_height())
	sprite.scale = Vector2.ONE * (float(info["length"]) / longest)
	sprite.position = info.get("center", Vector2.ZERO)
	for child: Node in holder.get_children():
		if child is Polygon2D or child is Line2D:
			(child as CanvasItem).visible = false
	holder.add_child(sprite)
	return sprite


## A fresh petrify material (one per body, because each has its own progress/origin).
static func petrify_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = PETRIFY_SHADER
	mat.set_shader_parameter(&"marble_color", Balance.COLOR_MARBLE)
	mat.set_shader_parameter(&"vein_color", Balance.COLOR_MARBLE_VEIN)
	mat.set_shader_parameter(&"edge_color", Balance.COLOR_PETRIFY_EDGE)
	mat.set_shader_parameter(&"edge_width", Balance.PETRIFY_EDGE_WIDTH)
	mat.set_shader_parameter(&"noise_scale", Balance.PETRIFY_NOISE_SCALE)
	mat.set_shader_parameter(&"noise_amount", Balance.PETRIFY_NOISE_AMOUNT)
	mat.set_shader_parameter(&"octaves", Balance.SHADER_NOISE_OCTAVES)
	mat.set_shader_parameter(&"progress", 0.0)
	return mat


## A fresh marble material for a statue (one each, since `cracked` is per statue).
static func marble_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = MARBLE_SHADER
	mat.set_shader_parameter(&"marble_color", Balance.COLOR_MARBLE)
	mat.set_shader_parameter(&"vein_color", Balance.COLOR_MARBLE_VEIN)
	mat.set_shader_parameter(&"rim_color", Balance.COLOR_MARBLE_RIM)
	mat.set_shader_parameter(&"crack_color", Balance.COLOR_BLACK)
	mat.set_shader_parameter(&"vein_scale", Balance.MARBLE_VEIN_SCALE)
	mat.set_shader_parameter(&"vein_strength", Balance.MARBLE_VEIN_STRENGTH)
	mat.set_shader_parameter(&"rim_px", Balance.MARBLE_RIM_PX)
	mat.set_shader_parameter(&"crack_scale", Balance.MARBLE_CRACK_SCALE)
	mat.set_shader_parameter(&"crack_width", Balance.MARBLE_CRACK_WIDTH)
	mat.set_shader_parameter(&"octaves", Balance.SHADER_NOISE_OCTAVES)
	mat.set_shader_parameter(&"cracked", false)
	return mat


## Where `global_point` falls on the sprite's current frame, as UV (0..1 each way,
## clamped to the frame). to_local() undoes the sprite's position, scale and the
## Visual flip, so a gaze from the left lands on the left edge even when flipped.
static func frame_uv(sprite: AnimatedSprite2D, global_point: Vector2) -> Vector2:
	var texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if texture == null:
		return Vector2(0.5, 0.5)
	var size: Vector2 = texture.get_size()
	# A centered sprite's frame spans offset - size/2 .. offset + size/2 in local space.
	var top_left: Vector2 = sprite.offset - size * 0.5
	var uv: Vector2 = (sprite.to_local(global_point) - top_left) / size
	return uv.clamp(Vector2.ZERO, Vector2.ONE)

