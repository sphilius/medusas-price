## sim_player.gd - dev-only headless check (scene: tools/sim_player.tscn).
## Standing still, presses jump three ways and prints each jump's height:
## a long hold (full jump), a short tap (cut jump), and a walk-off-ledge coyote jump.
extends Node

func _ready() -> void:
	var room: Node = load("res://tools/sim_room.tscn").instantiate()
	add_child(room)
	var p: Player = room.get_node("Player")
	var ground_y: float = p.position.y
	var peak: float = ground_y
	for i in 400:
		await get_tree().physics_frame
		if i == 40: Input.action_press("jump")        # full hold
		if i == 100: Input.action_release("jump")
		if i == 140: Input.action_press("jump")       # short tap
		if i == 143: Input.action_release("jump")
		peak = minf(peak, p.position.y)
		if i == 120 or i == 200:
			print("jump peak height: %.0f px (%.2f BL)" % [ground_y - peak, (ground_y - peak) / Balance.BL])
			peak = ground_y
	get_tree().quit()
