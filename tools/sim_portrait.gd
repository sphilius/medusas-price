## sim_portrait.gd - dev-only headless check (scene: tools/sim_portrait.tscn).
## Portrait state math (thresholds, overflow carry, death, pool heal), the crack costs
## (petrify, accepted hit, ignored hit while invulnerable, pit), the safe ledge and pit
## respawn, the mirror pool (stand or kneel, once per visit, recharge on re-entry), the
## death sequence (turn to stone, respawn at the last pool at stage 2) and the HUD
## (one crack line per crack, cleared on a stage change, no text nodes anywhere).
extends Node

## Player center y standing on either ledge of the graybox.
const STAND_Y: float = 568.0
## Where the graybox's props sit (see scenes/test_room.tscn).
const POOL_X: float = 1110.0
const FAR_LEDGE_X: float = 990.0
const PIT_X: float = 800.0

var _room: Node
var _player: Player
var _failures: int = 0
var _stage_events: Array[int] = []
var _died_count: int = 0


func _ready() -> void:
	PortraitState.stage_changed.connect(func(s: int) -> void: _stage_events.append(s))
	PortraitState.died.connect(func() -> void: _died_count += 1)
	_test_state_math()
	await _test_costs()
	await _test_pit()
	await _test_pool()
	await _test_death()
	await _test_hud()
	_test_shard_ward()
	print("sim_portrait: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


## Pure numbers: no room needed.
func _test_state_math() -> void:
	PortraitState.reset_run()
	PortraitState.add_cracks(5, &"test")
	_check("5 cracks: still stage 1 with 5", PortraitState.stage == 1 and PortraitState.cracks_in_stage == 5)
	PortraitState.add_cracks(1, &"test")
	_check("6th crack fills stage 1 and advances to stage 2 with 0", PortraitState.stage == 2 and PortraitState.cracks_in_stage == 0)
	PortraitState.reset_run()
	PortraitState.add_cracks(7, &"test")
	_check("7 cracks: stage 2 with 1 (overflow carried)", PortraitState.stage == 2 and PortraitState.cracks_in_stage == 1)
	PortraitState.reset_run()
	PortraitState.add_cracks(12, &"test")
	_check("12 cracks at once: stage 3 with 1", PortraitState.stage == 3 and PortraitState.cracks_in_stage == 1)
	_check("total_cracks counts earlier stages", PortraitState.total_cracks() == 12)
	PortraitState.reset_run()
	_stage_events.clear()
	PortraitState.add_cracks(6, &"test")
	_check("stage_changed emitted with the new stage", _stage_events == [2])

	# Death: 20 cracks in all, once.
	PortraitState.reset_run()
	_died_count = 0
	PortraitState.add_cracks(19, &"test")
	_check("19 cracks: stage 5 with 1, alive", PortraitState.stage == 5 and PortraitState.cracks_in_stage == 1 and _died_count == 0 \
			and not PortraitState.is_dead)
	PortraitState.add_cracks(1, &"test")
	_check("20th crack kills once", _died_count == 1 and PortraitState.is_dead)
	PortraitState.add_cracks(3, &"test")
	_check("cracks after death are ignored", _died_count == 1 and PortraitState.cracks_in_stage == 2)
	PortraitState.reset_after_death()
	_check("after death: stage 2, 0 cracks, alive", PortraitState.stage == Balance.DEATH_RESPAWN_STAGE \
			and PortraitState.cracks_in_stage == 0 and not PortraitState.is_dead)

	# Pool heal.
	PortraitState.reset_run()
	PortraitState.add_cracks(6 + 5 + 2, &"test")  # stage 3 with 2
	PortraitState.heal_at_pool()
	_check("pool at stage 3 drops to stage 2 and clears cracks", PortraitState.stage == 2 and PortraitState.cracks_in_stage == 0)
	PortraitState.reset_run()
	PortraitState.add_cracks(3, &"test")
	PortraitState.heal_at_pool()
	_check("pool at stage 1 only clears cracks", PortraitState.stage == 1 and PortraitState.cracks_in_stage == 0)
	PortraitState.reset_run()


## Costs: petrify 1, an accepted hit its cracks value, a repeat during invulnerability 0.
func _test_costs() -> void:
	await _fresh_room()
	Events.petrified.emit(&"hoplite", 0, false, Vector2(400, STAND_Y))
	_check("a petrify costs 1 crack", PortraitState.total_cracks() == Balance.CRACKS_PETRIFY)
	await _frames(40)  # hit-stop ends
	Events.player_hit.emit(Balance.CRACKS_HIT, &"hoplite", Vector2(500, STAND_Y))
	_check("an accepted hit costs its cracks value", PortraitState.total_cracks() == Balance.CRACKS_PETRIFY + Balance.CRACKS_HIT)
	Events.player_hit.emit(Balance.CRACKS_HIT, &"hoplite", Vector2(500, STAND_Y))
	_check("a hit while invulnerable costs nothing", PortraitState.total_cracks() == Balance.CRACKS_PETRIFY + Balance.CRACKS_HIT)
	await _frames(90)  # stun and invulnerability end
	Events.player_hit.emit(Balance.CRACKS_REFLECT, &"mirror", Vector2(500, STAND_Y))
	_check("a reflected gaze costs 2", PortraitState.total_cracks() == Balance.CRACKS_PETRIFY + Balance.CRACKS_HIT + Balance.CRACKS_REFLECT)
	_check("each crack went to the ledger", RunLedger.events_of("crack").size() == 3)


## A pit fall: 1 crack, back at the last safe ledge, and the room keeps a leaper.
func _test_pit() -> void:
	await _fresh_room()
	# The leaper starts on the far ledge by the spot she stands on below, so it goes first:
	# it is "wasted", and the gap is now uncrossable.
	_room.get_node("Leaper").queue_free()
	await _frames(2)
	_place_player(Vector2(FAR_LEDGE_X, STAND_Y))
	await _frames(5)
	var pits_before: int = RunLedger.events_of("pit").size()
	_place_player(Vector2(PIT_X, 900.0))
	await _frames(10)
	_check("pit fall costs 1 crack (total %d)" % PortraitState.total_cracks(), PortraitState.total_cracks() == Balance.CRACKS_PIT)
	_check("pit fall is logged", RunLedger.events_of("pit").size() == pits_before + 1)
	_check("pit fall puts her back on the last safe ledge (at %s)" % str(_player.global_position), \
			absf(_player.global_position.x - FAR_LEDGE_X) < 4.0 and absf(_player.global_position.y - STAND_Y) < 8.0)
	# She respawned on the leaper's spawn point: no leaper may appear inside her body...
	_check("no replacement leaper appears on top of her", _count_leapers() == 0)
	# ...but once she walks away the room owes one and gets it.
	_place_player(Vector2(FAR_LEDGE_X + 4.0 * Balance.BL, STAND_Y))
	await _frames(3)
	_check("a leaper is back for the wasted one once she steps clear", _count_leapers() == 1)
	_place_player(Vector2(PIT_X, 900.0))
	await _frames(10)
	_check("a room with a live leaper does not grow a second", _count_leapers() == 1)
	# The backstop: below PLAYER_PIT_Y with no pit zone around.
	await _fresh_room()
	_place_player(Vector2(-400.0, Balance.PLAYER_PIT_Y + Balance.BL))
	await _frames(5)
	_check("falling below the pit line also costs 1 and respawns her", PortraitState.total_cracks() == Balance.CRACKS_PIT \
			and _player.global_position.y < Balance.PLAYER_PIT_Y)


## The pool: stand 1 s or kneel; it heals ONCE and never refills (2026-11-05 change).
func _test_pool() -> void:
	await _fresh_room()
	# Leapers hop at her now (LEAPER_HOP_ON_FLAT); keep them out of the healing test.
	for child: Node in _room.get_children():
		if child is Enemy and (child as Enemy).enemy_type == &"leaper":
			child.queue_free()
	PortraitState.add_cracks(6 + 2, &"test")  # stage 2 with 2
	_place_player(Vector2(POOL_X, STAND_Y))
	await _frames(30)
	_check("not healed before standing a second", PortraitState.cracks_in_stage == 2)
	await _frames(50)
	_check("standing still for 1 s heals: stage 1, 0 cracks", PortraitState.stage == 1 and PortraitState.cracks_in_stage == 0)
	_check("the pool is logged", RunLedger.events_of("pool").size() == 1)
	PortraitState.add_cracks(2, &"test")
	await _frames(90)
	_check("one use per visit", PortraitState.cracks_in_stage == 2 and RunLedger.events_of("pool").size() == 1)
	_place_player(Vector2(POOL_X + 3.0 * Balance.BL, STAND_Y))
	await _frames(10)
	_place_player(Vector2(POOL_X, STAND_Y))
	await _frames(5)
	Input.action_press("move_down")
	await _frames(5)
	Input.action_release("move_down")
	_check("leaving and returning does NOT refill it (kneeling does nothing)",
			PortraitState.cracks_in_stage == 2 and RunLedger.events_of("pool").size() == 1)


## Dying: marble tint, then up at the last pool at stage 2 with 0 cracks.
func _test_death() -> void:
	await _fresh_room()
	for child: Node in _room.get_children():  # leapers hop at her now; keep them out
		if child is Enemy and (child as Enemy).enemy_type == &"leaper":
			child.queue_free()
	_place_player(Vector2(POOL_X, STAND_Y))
	await _frames(80)  # heals (stage 1, nothing to clear) and becomes the respawn point
	_place_player(Vector2(300.0, STAND_Y))
	await _frames(5)
	PortraitState.add_cracks(19, &"test")
	Events.player_hit.emit(Balance.CRACKS_HIT, &"hoplite", Vector2(400, STAND_Y))
	_check("the last crack kills", PortraitState.is_dead and _player.state == Player.State.DEAD)
	_check("death is logged", RunLedger.events_of("death").size() == 1)
	await _frames(int(Balance.DEATH_STONE_TIME * 60.0 * 0.5))
	# With sprite art the petrify shader's progress shows it; without, the body polygon's color.
	var sprite := _player.get_node_or_null("Visual/Sprite") as AnimatedSprite2D
	if sprite != null:
		var mat := sprite.material as ShaderMaterial
		var progress: float = mat.get_shader_parameter(&"progress") if mat != null else 0.0
		_check("she is turning to marble (stone progress %.2f)" % progress, progress > 0.3)
	else:
		var body: Polygon2D = _player.get_node("Visual/Body")
		_check("she is turning to marble (body color %s)" % str(body.color), body.color.r > 0.3)
	await _frames(int((Balance.DEATH_STONE_TIME + Balance.DEATH_HOLD_TIME) * 60.0 * 0.5) + 20)
	_check("up again: stage %d with 0 cracks" % Balance.DEATH_RESPAWN_STAGE, not PortraitState.is_dead \
			and PortraitState.stage == Balance.DEATH_RESPAWN_STAGE and PortraitState.cracks_in_stage == 0)
	_check("respawned at the last pool (at %s)" % str(_player.global_position), \
			absf(_player.global_position.x - POOL_X) < 4.0 and _player.state != Player.State.DEAD)
	if sprite != null:
		_check("her art is flesh again (no stone shader)", sprite.material == null)
	else:
		var body: Polygon2D = _player.get_node("Visual/Body")
		_check("her art is back to black", body.color.is_equal_approx(Balance.COLOR_BLACK))
	await _frames(200)
	_check("standing in the pool after a death gives no free heal", PortraitState.stage == Balance.DEATH_RESPAWN_STAGE)


## The shield: the craquelure shader's `amount` follows this stage's cracks, clears on a
## stage change while `wear` grows, and the HUD never has text.
func _test_hud() -> void:
	await _fresh_room()
	var painting: TextureRect = _room.get_node("PortraitHud/Shield/Painting")
	var mat := painting.material as ShaderMaterial
	PortraitState.add_cracks(3, &"test")
	await _frames(2)
	_check("3 of 6 cracks: craquelure amount 0.5", mat != null and is_equal_approx(float(mat.get_shader_parameter(&"amount")), 0.5))
	PortraitState.add_cracks(3, &"test")  # fills stage 1 (6)
	await _frames(2)
	_check("a stage change clears the craquelure, wear grows",
			is_zero_approx(float(mat.get_shader_parameter(&"amount"))) and float(mat.get_shader_parameter(&"wear")) > 0.0)
	PortraitState.add_cracks(2, &"test")
	await _frames(2)
	_check("2 of 5 cracks in stage 2: amount 0.4", is_equal_approx(float(mat.get_shader_parameter(&"amount")), 0.4))
	var before: Texture2D = painting.texture
	PortraitState.add_cracks(3, &"test")  # 2 + 3 = 5 fills stage 2
	await _frames(2)
	_check("a stage change swaps the painting", painting.texture != before)
	var texts: int = 0
	for node: Node in _room.get_node("PortraitHud").find_children("*", "", true, false):
		if node is Label or node is RichTextLabel or node is Button:
			texts += 1
	_check("the HUD has no text nodes", texts == 0)


# ---------------------------------------------------------------------------

## Shards: mend what they can, keep the rest as ward rings that absorb the next cracks.
func _test_shard_ward() -> void:
	PortraitState.reset_run()
	PortraitState.add_cracks(1, &"sim")
	PortraitState.mend(Balance.SHARD_MEND)
	_check("a shard mends the crack and keeps the rest as a ward ring", PortraitState.cracks_in_stage == 0 and PortraitState.ward == Balance.SHARD_MEND - 1)
	PortraitState.add_cracks(2, &"sim")
	_check("the ward ring takes the first crack", PortraitState.ward == 0 and PortraitState.cracks_in_stage == 1)
	PortraitState.reset_run()


func _count_lines(parent: Node) -> int:
	return parent.get_children().filter(func(n: Node) -> bool: return n is Line2D and not n.is_queued_for_deletion()).size()


func _count_leapers() -> int:
	var n: int = 0
	for child in _room.get_children():
		if child is Enemy and (child as Enemy).enemy_type == &"leaper" and not child.is_queued_for_deletion():
			n += 1
	return n


## A fresh graybox with the run reset and the hostile enemies gone (they are not under test).
func _fresh_room() -> void:
	if is_instance_valid(_room):
		_room.queue_free()
	await _frames(2)
	PortraitState.reset_run()
	RunLedger.start_run()
	_room = load("res://scenes/test_room.tscn").instantiate()
	add_child(_room)
	for node_name in ["Hoplite1", "Hoplite2", "Hoplite3"]:
		_room.get_node(node_name).queue_free()
	_player = _room.get_node("Player")
	await _frames(5)


func _place_player(pos: Vector2) -> void:
	_player.global_position = pos
	_player.velocity = Vector2.ZERO


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(label: String, ok: bool) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1
