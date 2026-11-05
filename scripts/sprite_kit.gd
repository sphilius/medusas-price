## sprite_kit.gd (static helper class, not attached to any node)
## Purpose: puts the real character art on a body. attach() builds an AnimatedSprite2D
## from Balance.SPRITE_ART, sizes it to the hitbox, stands it on the body's feet and
## hides the old placeholder polygons. If the art is missing it returns null and the
## placeholders stay visible (the game never breaks over a missing file).
## Also makes weapon sprites from Balance.WEAPON_ART.
class_name SpriteKit
extends RefCounted


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
