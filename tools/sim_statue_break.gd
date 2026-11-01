## sim_statue_break.gd - dev-only headless check (scene: tools/sim_statue_break.tscn).
## Whips statues and prints PASS/FAIL: first lash cracks (fracture lines over the whole
## body, chip burst, ledger entry), second shatters (rubble, no collision, left the
## "statues" group, freed after the rubble, ledger entry), one hit per lash, nothing
## happens on a shattered statue; pushing never cracks or shatters; the whip never
## pushes; and the pressure plate: pressed / released for Medusa (grounded only) and
## for statues (also when pushed off, shattered or freed).
extends Node

const DUMMY: PackedScene = preload("res://scenes/dummy_enemy.tscn")
const PLATE: PackedScene = preload("res://scenes/props/pressure_plate.tscn")
## Body center y of a 64 px body standing on the sim room floor (its top is y 600).
const FLOOR_Y: float = 568.0
## The floor's top surface.
const FLOOR_TOP: float = 600.0
## One physics frame (s).
const DT: float = 1.0 / 60.0

var _room: Node
var _player: Player
var _failures: int = 0


func _ready() -> void:
	_room = load("res://tools/sim_room.tscn").instantiate()
	add_child(_room)
	_player = _room.get_node("Player")
	_room.get_node("DummyEnemy").queue_free()
	_room.get_node("PlatformDummy").queue_free()
	await _frames(10)

	await _test_crack_then_shatter()
	await _test_nothing_on_shattered()
	await _test_push_never_breaks()
	await _test_whip_never_pushes()
	await _test_plate_player()
	await _test_plate_statue()

	print("sim_statue_break: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


## Lash 1: INTACT -> CRACKED with lines over the whole body, chips and a ledger entry.
## Lash 2: CRACKED -> SHATTERED, rubble, collision gone, freed after the rubble.
func _test_crack_then_shatter() -> void:
	RunLedger.start_run()
	var cracks_heard: Array = []
	var shatters_heard: Array = []
	Events.statue_cracked.connect(func(t, p): cracks_heard.append(p))
	Events.statue_shattered.connect(func(t, p): shatters_heard.append(p))

	var statue: Statue = await _make_statue(Vector2(400, FLOOR_Y))
	var where: Vector2 = statue.position
	_check("a fresh statue is INTACT, no fracture lines", statue.state == Statue.State.INTACT and statue._cracks == null)
	_place_player(Vector2(300, FLOOR_Y))
	await _frames(3)

	_tap("whip")
	await _frames(30)
	_check("first lash: CRACKED (one hit per lash, not shattered)", statue.state == Statue.State.CRACKED)
	_check("cracking does not move it", statue.position == where and statue.motion == Statue.Motion.STILL)
	var rect: Rect2 = statue._body_rect()
	var lines: Array[Node] = statue._cracks.get_children()
	_check("%d lines (white over a dark edge)" % lines.size(), lines.size() == Balance.STATUE_CRACK_LINES * 2)
	var white: int = 0
	var inside: bool = true
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for line in lines:
		white += 1 if (line as Line2D).default_color == Balance.COLOR_MARBLE else 0
		for p in (line as Line2D).points:
			inside = inside and rect.grow(0.01).has_point(p)
			low = low.min(p)
			high = high.max(p)
	_check("half of the lines are marble white", white == Balance.STATUE_CRACK_LINES)
	_check("every point lies on the statue's body", inside)
	_check("lines span the whole body (%.0f%% x %.0f%%)" % [(high.x - low.x) / rect.size.x * 100.0, (high.y - low.y) / rect.size.y * 100.0],
			high.x - low.x >= rect.size.x * 0.9 and high.y - low.y >= rect.size.y * 0.9)
	_check("lines draw above the art", statue._cracks.get_index() > statue._art.get_index())
	var chips: Array[Node] = statue.find_children("*", "CPUParticles2D", false, false)
	_check("chip burst emitted", chips.size() == 1 and (chips[0] as CPUParticles2D).amount == Balance.STATUE_CHIP_COUNT)
	_check("ledger: statue_cracked once", RunLedger.events_of("statue_cracked").size() == 1 and cracks_heard.size() == 1)
	var entry: Dictionary = RunLedger.events_of("statue_cracked")[0]["data"]
	_check("ledger entry names the enemy and where", entry["enemy_type"] == "dummy" and entry["position"] == [where.x, where.y])
	await _frames(40)
	_check("spent chip emitter cleaned up", statue.find_children("*", "CPUParticles2D", false, false).is_empty())

	_tap("whip")
	await _frames(16)  # past the 0.15 s anticipation, inside the active window
	_check("second lash: SHATTERED", statue.state == Statue.State.SHATTERED)
	_check("ledger: statue_shattered once", RunLedger.events_of("statue_shattered").size() == 1 and shatters_heard.size() == 1)
	var solid: bool = false
	for child in statue.get_children():
		if child is CollisionShape2D and not (child as CollisionShape2D).disabled:
			solid = true
	_check("collision removed", not solid)
	_check("left the statues group", not statue.is_in_group(&"statues"))
	_check("body and cracks hidden", not statue._art.visible and not statue._cracks.visible)
	var rubble: Array[Node] = statue.find_children("*", "CPUParticles2D", false, false)
	_check("rubble burst emitted", rubble.size() == 1 and (rubble[0] as CPUParticles2D).amount == Balance.STATUE_RUBBLE_COUNT)
	_check("statue lives until the rubble is done", is_instance_valid(statue))
	await _frames(int(Balance.STATUE_RUBBLE_LIFETIME / DT) + 40)
	_check("statue freed after the rubble", not is_instance_valid(statue))
	await _frames(10)


## A shattered statue ignores a further lash, push, and is never solid to Medusa.
func _test_nothing_on_shattered() -> void:
	RunLedger.start_run()
	var statue: Statue = await _make_statue(Vector2(400, FLOOR_Y))
	statue.whip_hit()
	statue.whip_hit()
	await _frames(2)
	statue.whip_hit()
	statue.push(1)
	await _frames(10)
	_check("a third hit changes nothing (one shatter logged)", RunLedger.events_of("statue_shattered").size() == 1 \
			and statue.state == Statue.State.SHATTERED)
	_check("a shattered statue cannot be pushed", statue.motion == Statue.Motion.STILL and statue.position == Vector2(400, FLOOR_Y))
	_place_player(Vector2(340, FLOOR_Y))
	Input.action_press("move_right")
	await _frames(40)
	Input.action_release("move_right")
	_check("Medusa walks through where it stood", _player.position.x > 400.0)
	await _frames(100)


## Pushing (ground slide, into a wall, off an edge) never cracks or shatters, and a cracked
## statue stays cracked through it.
func _test_push_never_breaks() -> void:
	RunLedger.start_run()
	var intact: Statue = await _make_statue(Vector2(790, FLOOR_Y))
	_place_player(Vector2(720, FLOOR_Y))
	Input.action_press("move_right")
	await _frames(150)  # slides into the pillar and stays pushed against it
	Input.action_release("move_right")
	await _frames(10)
	_check("pushed into the wall: still INTACT", intact.state == Statue.State.INTACT and intact._cracks == null)
	await _free(intact)

	var cracked: Statue = await _make_statue(Vector2(790, FLOOR_Y))
	cracked.whip_hit()
	_place_player(Vector2(720, FLOOR_Y))
	Input.action_press("move_right")
	await _frames(150)
	Input.action_release("move_right")
	await _frames(10)
	_check("cracked statue pushed into the wall: still CRACKED", is_instance_valid(cracked) \
			and cracked.state == Statue.State.CRACKED)
	_check("no shatter logged from pushing", RunLedger.events_of("statue_shattered").is_empty() \
			and RunLedger.events_of("statue_cracked").size() == 1)
	await _free(cracked)

	# Off the edge of a platform and onto the floor.
	var faller: Statue = await _make_statue(Vector2(470, 448))
	_place_player(Vector2(420, 448))
	Input.action_press("move_right")
	await _frames(120)
	Input.action_release("move_right")
	await _frames(60)
	_check("fell off the platform and landed: still INTACT", faller.motion == Statue.Motion.STILL \
			and absf(faller.position.y - FLOOR_Y) < 1.0 and faller.state == Statue.State.INTACT)
	await _free(faller)


## A lash beside a statue, with the push key held, moves nothing and never starts a push.
func _test_whip_never_pushes() -> void:
	var statue: Statue = await _make_statue(Vector2(360, FLOOR_Y))
	var where: Vector2 = statue.position
	_place_player(Vector2(320, FLOOR_Y))  # touching its side
	await _frames(5)
	Input.action_press("move_right")
	_tap("whip")
	var pushed_during_lash: bool = false
	for i in 30:  # the whole lash (0.45 s), shorter than the 0.4 s push delay after it
		await _frames(1)
		pushed_during_lash = pushed_during_lash or statue.motion != Statue.Motion.STILL \
				or statue._push_grace_left > 0.0 or statue.position != where
	_check("lash: statue hit (cracked) but never pushed or moved", pushed_during_lash == false \
			and statue.state == Statue.State.CRACKED and statue.position == where)
	Input.action_release("move_right")
	await _frames(5)
	await _free(statue)


## Medusa presses the plate only standing on the floor: landing on it presses, walking
## off releases, being airborne inside the zone does not count.
func _test_plate_player() -> void:
	_place_player(Vector2(150, FLOOR_Y))
	await _frames(5)
	var plate := PLATE.instantiate()
	plate.position = Vector2(300, FLOOR_TOP)
	_room.add_child(plate)
	var log: Array = []
	plate.pressed.connect(func(): log.append("pressed"))
	plate.released.connect(func(): log.append("released"))
	await _frames(5)
	_check("plate starts released", not plate.is_pressed and log.is_empty())

	# Feet 6 px above the floor, inside the 8 px trigger zone: airborne, so no press yet.
	_place_player(Vector2(300, FLOOR_Y - 6.0))
	await _frames(1)
	_check("airborne inside the zone: not pressed", not plate.is_pressed and not _player.is_on_floor())
	await _frames(15)
	_check("landed on the plate: pressed once", plate.is_pressed and log == ["pressed"])
	_check("pressed look: slab sunk and gold", is_equal_approx(plate.get_node("Slab").scale.y, Balance.PLATE_PRESSED_SCALE) \
			and plate.get_node("Slab").color == Balance.COLOR_GOLD)
	Input.action_press("move_left")
	await _frames(60)
	Input.action_release("move_left")
	await _frames(5)
	_check("walked off: released once", not plate.is_pressed and log == ["pressed", "released"])
	_check("released look: slab raised and marble", plate.get_node("Slab").scale.y == 1.0 \
			and plate.get_node("Slab").color == Balance.COLOR_MARBLE)
	plate.queue_free()
	await _frames(2)


## A statue on the plate holds it; shattering, freeing, or pushing it off releases it.
func _test_plate_statue() -> void:
	_place_player(Vector2(100, FLOOR_Y))
	var plate := PLATE.instantiate()
	plate.position = Vector2(300, FLOOR_TOP)
	_room.add_child(plate)
	var log: Array = []
	plate.pressed.connect(func(): log.append("pressed"))
	plate.released.connect(func(): log.append("released"))

	var statue: Statue = await _make_statue(Vector2(300, FLOOR_Y))
	await _frames(5)
	_check("statue on the plate: pressed", plate.is_pressed and log == ["pressed"])
	_check("pressed look: slab sunk and gold", is_equal_approx(plate.get_node("Slab").scale.y, Balance.PLATE_PRESSED_SCALE) \
			and plate.get_node("Slab").color == Balance.COLOR_GOLD)
	statue.whip_hit()
	await _frames(5)
	_check("a cracked statue still presses", plate.is_pressed and log == ["pressed"])
	statue.whip_hit()
	await _frames(5)
	_check("shattering releases it", not plate.is_pressed and log == ["pressed", "released"])
	await _frames(70)

	log.clear()
	var second: Statue = await _make_statue(Vector2(300, FLOOR_Y))
	await _frames(5)
	_check("pressed again by a new statue", plate.is_pressed and log == ["pressed"])
	second.queue_free()
	await _frames(5)
	_check("freeing the statue releases it", not plate.is_pressed and log == ["pressed", "released"])

	log.clear()
	var pushed: Statue = await _make_statue(Vector2(300, FLOOR_Y))
	_place_player(Vector2(230, FLOOR_Y))
	await _frames(5)
	_check("pressed once more", plate.is_pressed and log == ["pressed"])
	Input.action_press("move_right")
	await _frames(140)  # 0.4 s delay, then 96 px/s: clear of the 64 px plate
	Input.action_release("move_right")
	await _frames(10)
	_check("pushed clear of the plate: released (statue x %.0f)" % pushed.position.x, not plate.is_pressed \
			and log == ["pressed", "released"])
	await _free(pushed)
	plate.queue_free()
	await _frames(2)


# --- helpers ---------------------------------------------------------------

## Petrify a motionless dummy at `pos` and return its statue.
func _make_statue(pos: Vector2) -> Statue:
	var dummy: Enemy = DUMMY.instantiate()
	dummy.position = pos
	_room.add_child(dummy)
	dummy.set_physics_process(false)
	dummy.get_node("JumpTimer").stop()
	await _frames(1)
	dummy.petrify()
	await _frames(10)  # let the hit-stop pass
	return get_tree().get_nodes_in_group(&"statues").back() as Statue


func _tap(action: String) -> void:
	Input.action_press(action)
	get_tree().physics_frame.connect(func(): Input.action_release(action), CONNECT_ONE_SHOT)


func _place_player(pos: Vector2) -> void:
	_player.position = pos
	_player.velocity = Vector2.ZERO
	_player.facing = 1
	_player._visual.scale.x = 1


func _free(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
	await _frames(2)


func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
