## vase.gd (root script of scenes/flow/vase.tscn)
## Purpose: the run vase, shown after the boss. The painted fallback amphora appears at
## once. If Features.VASE_AI is on, the run summary (RunLedger.summary()) goes to the
## Worker's POST /vase, and when a painted vase of THIS run comes back it fades in over
## the fallback. Any failure (off, timeout, refusal, bad image) just keeps the fallback,
## with no message (no-text rule). Any key, button or touch moves on to the ending.
extends Node2D

## The endpoint this scene asks for (also how it recognises its own answer).
const ENDPOINT: String = "/vase"

## Seconds since the scene appeared (input is ignored for VASE_INPUT_DELAY_S).
var _age: float = 0.0
## The vase picture currently shown (the fallback, until an AI vase replaces it).
var _shown: Sprite2D = null


## _ready: dark background, the fallback vase, then (maybe) ask the Worker.
func _ready() -> void:
	var back := ColorRect.new()
	back.color = Balance.COLOR_BLACK
	back.size = get_viewport_rect().size
	add_child(back)
	var fallback: Texture2D = load(Balance.VASE_FALLBACK) as Texture2D if ResourceLoader.exists(Balance.VASE_FALLBACK) else null
	if fallback != null:
		_shown = _add_vase(fallback)
	if Features.VASE_AI:
		# connect() makes _on_completed run when AIClient emits `completed`; the answer
		# arrives later, so the scene stays responsive meanwhile.
		AIClient.completed.connect(_on_completed)
		AIClient.request(ENDPOINT, {"summary": RunLedger.summary()}, Balance.VASE_TIMEOUT_S)


func _process(delta: float) -> void:
	_age += delta


## Any key, button or touch (after the short delay) goes on to the ending.
func _unhandled_input(event: InputEvent) -> void:
	if _age < Balance.VASE_INPUT_DELAY_S or not event.is_pressed() or event.is_echo():
		return
	GameFlow.next_level()


## The Worker answered. Only a decodable image replaces the fallback.
func _on_completed(endpoint: String, ok: bool, data: Dictionary) -> void:
	if endpoint != ENDPOINT or not ok or not is_inside_tree():
		return
	var texture: Texture2D = decode_image(String(data.get("image", "")), String(data.get("mime", "")))
	if texture == null:
		return
	var fresh: Sprite2D = _add_vase(texture)
	fresh.modulate.a = 0.0
	var old: Sprite2D = _shown
	_shown = fresh
	var fade := create_tween()
	fade.tween_property(fresh, "modulate:a", 1.0, Balance.VASE_FADE_S)
	if old != null:
		fade.tween_callback(old.queue_free)


## A base64 PNG or JPEG -> texture, or null if it does not decode. Static so the sim
## can test it without a scene.
static func decode_image(base64: String, mime: String) -> Texture2D:
	if base64 == "":
		return null
	var bytes: PackedByteArray = Marshalls.base64_to_raw(base64)
	var image := Image.new()
	var err: int = image.load_jpg_from_buffer(bytes) if mime.contains("jpeg") or mime.contains("jpg") \
			else image.load_png_from_buffer(bytes)
	if err != OK or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


## One vase picture, scaled to VASE_HEIGHT and centered on the screen.
func _add_vase(texture: Texture2D) -> Sprite2D:
	var vase := Sprite2D.new()
	vase.texture = texture
	vase.position = Balance.VASE_CENTER
	vase.scale = Vector2.ONE * (Balance.VASE_HEIGHT / texture.get_height())
	add_child(vase)
	return vase
