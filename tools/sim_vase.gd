## sim_vase.gd - dev-only headless check (scene: tools/sim_vase.tscn).
## Run vase: the fallback amphora shows at once; a failed Worker call keeps it (no
## error); a good base64 PNG answer fades in over it; garbage never replaces it.
## The Worker address is pointed at an unreachable port so no real request is made.
## Run: godot --headless --path . res://tools/sim_vase.tscn  (exit code = failures)
extends Node

var _failures: int = 0


func _ready() -> void:
	AIClient.base_url = "http://127.0.0.1:9"  # nothing listens here: the call fails fast
	var Vase := preload("res://scripts/vase.gd")
	var png: PackedByteArray = Image.create(8, 8, false, Image.FORMAT_RGBA8).save_png_to_buffer()
	_check("a base64 PNG decodes", Vase.decode_image(Marshalls.raw_to_base64(png), "image/png") != null)
	_check("garbage does not decode", Vase.decode_image("bm90IGFuIGltYWdl", "image/png") == null)
	_check("an empty answer does not decode", Vase.decode_image("", "image/png") == null)

	var vase: Node2D = load("res://scenes/flow/vase.tscn").instantiate()
	add_child(vase)
	await _frames(2)
	var fallback: Texture2D = load(Balance.VASE_FALLBACK)
	_check("the fallback vase shows at once", vase._shown != null and vase._shown.texture == fallback)
	vase._on_completed("/vase", false, {})
	_check("a failed call keeps the fallback", vase._shown.texture == fallback)
	vase._on_completed("/vase", true, {"image": "bm90IGFuIGltYWdl", "mime": "image/png"})
	_check("a broken image keeps the fallback", vase._shown.texture == fallback)
	vase._on_completed("/vase", true, {"image": Marshalls.raw_to_base64(png), "mime": "image/png"})
	await _frames(int(Balance.VASE_FADE_S * 60.0) + 10)
	_check("a good AI vase replaces the fallback", vase._shown.texture != fallback)
	_check("the fallback is gone after the fade", vase.find_children("*", "Sprite2D", false, false).size() == 1)
	print("sim_vase: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(label: String, ok: bool) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1
