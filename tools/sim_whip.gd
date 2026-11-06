## sim_whip.gd - dev-only headless check (scene: tools/sim_whip.tscn).
## Runs the snake-hair whip in the sim room and prints PASS/FAIL: phase timing,
## hitbox only during ACTIVE, the 8-frame animation, input locks, jump-cancelled
## recovery, half gravity in the air during ACTIVE, one hit per lash, stagger and
## knockback (both directions), reach, statue / mirror hooks, a hit interrupting the
## lash, and the hoplite: gold glint through the wind-up, whip reach beating the
## spear reach by spacing, and a lash that cancels a wind-up before the thrust.
extends Node

const DUMMY: PackedScene = preload("res://scenes/dummy_enemy.tscn")
const HOPLITE: PackedScene = preload("res://scenes/enemies/hoplite.tscn")
const LEAPER: PackedScene = preload("res://scenes/enemies/leaper.tscn")
## Player center y standing on the sim room floor.
const STAND_Y: float = 568.0
## One physics frame (s).
const DT: float = 1.0 / 60.0

var _room: Node
var _player: Player
var _whip: Area2D
var _hits: Array = []
var _failures: int = 0


func _ready() -> void:
	_room = load("res://tools/sim_room.tscn").instantiate()
	add_child(_room)
	_player = _room.get_node("Player")
	_whip = _player.get_node("Whip")
	for child in _room.get_children():  # tests spawn their own enemies
		if child is Enemy:
			child.queue_free()
	Events.player_hit.connect(func(c, s, p): _hits.append([c, s]))
	await _frames(10)

	await _test_timing_and_animation()
	await _test_locks()
	await _test_jump_cancels_recovery()
	await _test_air_gravity()
	await _test_hit_stagger_knockback()
	await _test_reach_and_sides()
	await _test_statue_and_mirror()
	await _test_hit_interrupts_whip()
	await _test_leaper_point_blank()
	await _test_hoplite_glint()
	await _test_hoplite_spacing()
	await _test_whip_beats_windup()

	print("sim_whip: %s" % ("ALL PASS" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


## Anticipation 0.15 s, active 0.10 s, recovery 0.20 s; hitbox on only in ACTIVE;
## AnimationPlayer steps frames 0..7 in order, the fan frames inside the active window.
func _test_timing_and_animation() -> void:
	_place_player(Vector2(300, STAND_Y), 1)
	await _frames(5)
	var samples: Array = await _lash_samples(40)
	var counts: Dictionary = {}
	var monitoring_outside_active: int = 0
	var frames_seen: Array[int] = []
	var lines_ok: bool = true
	for s in samples:
		counts[s["phase"]] = counts.get(s["phase"], 0) + 1
		if s["monitoring"] and s["phase"] != Player.WhipPhase.ACTIVE:
			monitoring_outside_active += 1
		if s["phase"] != Player.WhipPhase.NONE and (frames_seen.is_empty() or frames_seen.back() != s["frame"]):
			frames_seen.append(s["frame"])
		if s["lines"] != Balance.WHIP_FRAME_SNAKES[s["frame"]]:
			lines_ok = false
	var antic: int = counts.get(Player.WhipPhase.ANTICIPATION, 0)
	var active: int = counts.get(Player.WhipPhase.ACTIVE, 0)
	var recovery: int = counts.get(Player.WhipPhase.RECOVERY, 0)
	_check("anticipation ~0.15 s (%d frames)" % antic, absi(antic - roundi(Balance.WHIP_ANTICIPATION / DT)) <= 1)
	_check("active ~0.10 s (%d frames)" % active, absi(active - roundi(Balance.WHIP_ACTIVE / DT)) <= 1)
	_check("recovery ~0.20 s (%d frames)" % recovery, absi(recovery - roundi(Balance.WHIP_RECOVERY / DT)) <= 1)
	_check("hitbox enabled only during ACTIVE", monitoring_outside_active == 0)
	_check("8 frames play in order (%s)" % str(frames_seen), frames_seen == [0, 1, 2, 3, 4, 5, 6, 7])
	_check("drawn snake count follows the frame table (3 to 5 lines)", lines_ok)
	var fan: Array = samples.filter(func(s): return s["frame"] == 3 and s["phase"] != Player.WhipPhase.NONE)
	_check("full fan frame is inside the active window", not fan.is_empty() \
			and fan.all(func(s): return s["phase"] == Player.WhipPhase.ACTIVE))
	var last: Dictionary = samples.back()
	_check("back to neutral, hair put away", last["phase"] == Player.WhipPhase.NONE and last["frame"] == 7 and last["lines"] == 0)
	_check("state leaves WHIP at the end", _player.state == Player.State.IDLE)


## Anticipation takes no other actions: move, jump and gaze are ignored; recovery
## also refuses gaze. Gaze held through the lash resumes after it.
func _test_locks() -> void:
	_place_player(Vector2(300, STAND_Y), 1)
	await _frames(5)
	var x0: float = _player.position.x
	_tap("whip")
	await _frames(1)
	Input.action_press("move_right")
	Input.action_press("gaze")
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	await _frames(5)
	_check("anticipation: still in WHIP, no gaze", _player.state == Player.State.WHIP \
			and _player.whip_phase == Player.WhipPhase.ANTICIPATION)
	_check("anticipation: no move, no jump", absf(_player.position.x - x0) < 1.0 and _player.is_on_floor())
	await _frames(10)  # now into the active / recovery part
	_check("later in the lash: still no gaze, no run", _player.state == Player.State.WHIP \
			and not (_player.get_node("Gaze/Cone") as Polygon2D).visible and absf(_player.position.x - x0) < 1.0)
	await _frames(20)
	_check("lash over with K held: gaze resumes", _player.state == Player.State.GAZE)
	Input.action_release("gaze")
	Input.action_release("move_right")
	await _frames(5)


## A jump pressed in recovery ends the lash and jumps right away; one pressed during
## anticipation does not cancel it.
func _test_jump_cancels_recovery() -> void:
	_place_player(Vector2(300, STAND_Y), 1)
	await _frames(5)
	_tap("whip")
	var recovery_start: int = -1
	for i in 40:
		await _frames(1)
		if _player.whip_phase == Player.WhipPhase.RECOVERY:
			recovery_start = i
			break
	await _frames(3)
	_check("in recovery before jumping", _player.state == Player.State.WHIP and _player.whip_phase == Player.WhipPhase.RECOVERY)
	_tap("jump")
	await _frames(2)
	_check("jump cancels recovery and takes off", _player.state != Player.State.WHIP and _player.velocity.y < 0.0)
	await _frames(60)

	# Jump pressed early in anticipation must not skip the lash.
	_place_player(Vector2(300, STAND_Y), 1)
	await _frames(5)
	_tap("whip")
	await _frames(1)
	_tap("jump")
	await _frames(12)  # past anticipation, inside active/recovery start; buffer long expired
	_check("jump during anticipation does not cancel the lash", _player.state == Player.State.WHIP and _player.is_on_floor())
	await _frames(40)


## Mid-air, gravity is halved during ACTIVE and only then.
func _test_air_gravity() -> void:
	_place_player(Vector2(300, 100), 1)
	await _frames(2)
	_tap("whip")
	var per_phase: Dictionary = {}
	var prev_vy: float = _player.velocity.y
	var prev_phase: int = Player.WhipPhase.NONE
	for i in 40:
		await _frames(1)
		var phase: int = _player.whip_phase
		if phase == prev_phase and phase != Player.WhipPhase.NONE:
			per_phase[phase] = per_phase.get(phase, []) + [_player.velocity.y - prev_vy]
		prev_vy = _player.velocity.y
		prev_phase = phase
	var g_frame: float = Balance.PLAYER_GRAVITY * DT
	_check("gravity normal in anticipation", _avg(per_phase.get(Player.WhipPhase.ANTICIPATION, [0.0])) > g_frame * 0.95)
	_check("gravity x0.5 during active (dv %.1f vs %.1f)" % [_avg(per_phase.get(Player.WhipPhase.ACTIVE, [0.0])), g_frame * Balance.WHIP_AIR_GRAVITY_MULT],
			absf(_avg(per_phase.get(Player.WhipPhase.ACTIVE, [0.0])) - g_frame * Balance.WHIP_AIR_GRAVITY_MULT) < 1.0)
	_check("gravity normal again in recovery", _avg(per_phase.get(Player.WhipPhase.RECOVERY, [0.0])) > g_frame * 0.95)
	await _frames(80)  # land


## One hit per lash: the stagger timer is never restarted and the knockback is 1 BL.
func _test_hit_stagger_knockback() -> void:
	var dummy: Enemy = _spawn_dummy(Vector2(400, STAND_Y))
	_place_player(Vector2(300, STAND_Y), 1)
	await _frames(5)
	var x0: float = dummy.position.x
	_tap("whip")
	var staggered_frames: int = 0
	for i in 60:
		await _frames(1)
		if dummy.is_staggered():
			staggered_frames += 1
	var pushed: float = dummy.position.x - x0
	_check("stagger lasts ~0.4 s once (%d frames)" % staggered_frames, absi(staggered_frames - roundi(Balance.WHIP_STAGGER / DT)) <= 2)
	_check("knockback ~1 BL away from her (%.0f px)" % pushed, absf(pushed - Balance.WHIP_KNOCKBACK_BL * Balance.BL) < 8.0)
	dummy.queue_free()
	await _frames(2)


## Hits land at 2 BL, miss beyond it, miss behind her; facing left pushes left.
func _test_reach_and_sides() -> void:
	_place_player(Vector2(500, STAND_Y), 1)
	var near: Enemy = _spawn_dummy(Vector2(500 + 140, STAND_Y))
	var far: Enemy = _spawn_dummy(Vector2(500 + 170, STAND_Y))
	var behind: Enemy = _spawn_dummy(Vector2(500 - 100, STAND_Y))
	await _frames(5)
	_tap("whip")
	await _frames(30)
	_check("hit just inside 2 BL", near.is_staggered() or near.position.x > 640.0 + 1.0)
	_check("no hit beyond reach", far.position.x == 670.0)
	_check("no hit behind her", behind.position.x == 400.0)
	for d in [near, far, behind]:
		d.queue_free()
	await _frames(70)

	_place_player(Vector2(500, STAND_Y), -1)
	var left: Enemy = _spawn_dummy(Vector2(400, STAND_Y))
	await _frames(5)
	_tap("whip")
	await _frames(30)
	_check("facing left: knocked left (x=%.0f)" % left.position.x, left.position.x < 400.0 - 40.0)
	left.queue_free()
	await _frames(2)


## Statues get whip_hit() and never move; a mirror-bearer gets knock_mirror(1.5).
func _test_statue_and_mirror() -> void:
	_place_player(Vector2(300, STAND_Y), 1)
	var dummy: Enemy = _spawn_dummy(Vector2(400, STAND_Y))
	await _frames(3)
	dummy.petrify()
	await _frames(3)
	var statue: Statue = get_tree().get_nodes_in_group(&"statues").back() as Statue
	var where: Vector2 = statue.position
	_tap("whip")
	await _frames(30)
	_check("statue got whip_hit (in the lash's hit list)", _whip._hit_ids.has(statue.get_instance_id()))
	_check("whip never moves a statue", statue.position == where and statue.motion == Statue.Motion.STILL)
	statue.queue_free()
	await _frames(2)

	var src := GDScript.new()
	src.source_code = "extends \"res://scripts/dummy_enemy.gd\"\nvar knocked: float = 0.0\nfunc knock_mirror(seconds: float) -> void:\n\tknocked = seconds\n"
	src.reload()
	var bearer: Enemy = _spawn_dummy(Vector2(400, STAND_Y), src)
	bearer.mirror_bearer = true
	var plain: Enemy = _spawn_dummy(Vector2(240, STAND_Y), src)  # behind her: not hit
	await _frames(5)
	_tap("whip")
	await _frames(30)
	_check("mirror-bearer: knock_mirror(%.1f)" % Balance.WHIP_MIRROR_KNOCK, bearer.get("knocked") == Balance.WHIP_MIRROR_KNOCK)
	_check("others never get knock_mirror", plain.get("knocked") == 0.0)
	bearer.queue_free()
	plain.queue_free()
	await _frames(2)


## A hit during the lash cancels it: hurt state, phase cleared, hitbox off.
func _test_hit_interrupts_whip() -> void:
	await _frames(70)  # let any invulnerability from earlier lapse
	_place_player(Vector2(300, STAND_Y), 1)
	await _frames(5)
	_tap("whip")
	await _frames(3)
	Events.player_hit.emit(1, &"test", Vector2(500, STAND_Y))
	await _frames(2)
	_check("hit during lash: HURT, phase cleared, hitbox off", _player.state == Player.State.HURT \
			and _player.whip_phase == Player.WhipPhase.NONE and not _whip.monitoring)
	await _frames(100)


## The fan also catches the 40 px tall leaper standing right in front of her.
func _test_leaper_point_blank() -> void:
	_place_player(Vector2(300, STAND_Y), 1)
	var leaper: Enemy = LEAPER.instantiate()
	leaper.position = Vector2(300 + 70, 580)
	_room.add_child(leaper)
	await _frames(5)
	_tap("whip")
	await _frames(20)
	_check("leaper hit at point blank", leaper.is_staggered() or leaper.position.x > 370.0 + 8.0)
	leaper.queue_free()
	await _frames(2)


## The wind-up shows a gold glint on the spearhead on every frame before the thrust.
func _test_hoplite_glint() -> void:
	await _frames(70)
	_hits.clear()
	_place_player(Vector2(300, STAND_Y), 1)
	var hop: Enemy = HOPLITE.instantiate()
	hop.position = Vector2(300 + 260, STAND_Y)
	_room.add_child(hop)
	var windup_frames: int = 0
	var glint_every_frame: bool = true
	var glint_on_tip: bool = true
	var glint_gold: bool = true
	var thrust_started: bool = false
	var glint_at_thrust: bool = false
	for i in 200:
		await _frames(1)
		if hop.state == hop.State.WINDUP:
			windup_frames += 1
			glint_every_frame = glint_every_frame and hop._glint.visible
			glint_gold = glint_gold and Color(hop._glint.color, 1.0) == Balance.COLOR_GOLD  # gold at any alpha
			var tip: Vector2 = hop._spear.to_global(Vector2(Balance.HOPLITE_SPEAR_TIP_X, 0.0))
			glint_on_tip = glint_on_tip and hop._glint.global_position.distance_to(tip) < 1.5
		elif hop.state == hop.State.THRUST and not thrust_started:
			thrust_started = true
			glint_at_thrust = hop._glint.visible
			break
	_check("wind-up lasts ~0.35 s (%d frames)" % windup_frames, absi(windup_frames - roundi(Balance.HOPLITE_WINDUP / DT)) <= 2)
	_check("gold glint on every wind-up frame, before the thrust", thrust_started and glint_every_frame and glint_gold)
	_check("glint sits on the spearhead", glint_on_tip)
	_check("glint still lit when the thrust begins", glint_at_thrust)
	hop.queue_free()
	await _frames(70)


## By spacing: lash reach 2 BL vs spear 1.5 BL. At 130-140 px (center to center) the
## whip lands while the spear's hitbox cannot touch her; at 100 px both reach.
func _test_hoplite_spacing() -> void:
	_check("whip reach beats spear reach in Balance", Balance.WHIP_REACH_BL > Balance.HOPLITE_SPEAR_REACH_BL)
	for gap in [130.0, 140.0]:
		var result: Dictionary = await _spacing_probe(gap)
		_check("gap %.0f px: whip lands, spear cannot reach her" % gap, result["whipped"] and not result["speared"])
	var close: Dictionary = await _spacing_probe(100.0)
	_check("gap 100 px: both reach", close["whipped"] and close["speared"])


## Frozen hoplite `gap` px to her right, facing her; one lash. Reports whether the
## lash staggered him and whether his spear hitbox overlapped her.
func _spacing_probe(gap: float) -> Dictionary:
	await _frames(70)
	_place_player(Vector2(300, STAND_Y), 1)
	var hop: Enemy = HOPLITE.instantiate()
	hop.position = Vector2(300 + gap, STAND_Y)
	_room.add_child(hop)
	hop.set_physics_process(false)  # no AI: pure geometry
	hop.set_facing(-1)
	await _frames(5)
	var speared: bool = hop._hitbox.get_overlapping_bodies().has(_player)
	_tap("whip")
	await _frames(25)
	var whipped: bool = hop.is_staggered() or hop._stagger_left > 0.0
	hop.queue_free()
	await _frames(2)
	return {"whipped": whipped, "speared": speared}


## Live duel: the instant the hoplite starts his wind-up, she lashes. The fan lands
## (0.15 s) long before the thrust (0.35 s): he is staggered and knocked back, his
## spear returns to rest, and she takes no hit.
func _test_whip_beats_windup() -> void:
	await _frames(70)
	_hits.clear()
	_place_player(Vector2(300, STAND_Y), 1)
	var hop: Enemy = HOPLITE.instantiate()
	hop.position = Vector2(300 + 230, STAND_Y)
	_room.add_child(hop)
	for i in 200:
		await _frames(1)
		if hop.state == hop.State.WINDUP:
			break
	_check("hoplite reached his wind-up", hop.state == hop.State.WINDUP)
	var x0: float = hop.position.x
	_tap("whip")
	await _frames(30)
	# Since the parry change: a lash during the wind-up exposes him instead of knocking him back.
	_check("lash during the wind-up parries: exposed, no thrust", hop.is_exposed() and hop.state != hop.State.THRUST and x0 > 0.0)
	_check("no glint, spear at rest after the interrupt", not hop._glint.visible and hop._spear_offset == 0.0)
	_check("she took no hit", _hits.is_empty())
	hop.queue_free()
	await _frames(2)


# --- helpers ---------------------------------------------------------------

## Tap the J key and sample every physics frame for `count` frames, starting with
## the press frame.
func _lash_samples(count: int) -> Array:
	var samples: Array = []
	_tap("whip")
	for i in count:
		await _frames(1)
		var visible_lines: int = 0
		# Count visible snakes: the sprite versions when the art loaded, else the black lines.
		var snakes: Array[Node] = _whip.get_node("Snakes").get_children()
		var use_sprites: bool = snakes.any(func(n: Node) -> bool: return n is Sprite2D)
		for snake: Node in snakes:
			if (snake is Sprite2D) == use_sprites and (snake as CanvasItem).visible:
				visible_lines += 1
		samples.append({
			"phase": _player.whip_phase,
			"monitoring": _whip.monitoring,
			"frame": _whip.frame,
			"lines": visible_lines,
		})
	return samples


## A stationary dummy (gravity and stagger only, no patrol), optionally with another script.
func _spawn_dummy(pos: Vector2, script: Script = null) -> Enemy:
	var dummy: Enemy = DUMMY.instantiate()
	if script != null:
		dummy.set_script(script)
	dummy.position = pos
	dummy.stationary = true
	_room.add_child(dummy)
	dummy.get_node("JumpTimer").stop()
	return dummy


func _tap(action: String) -> void:
	Input.action_press(action)
	get_tree().physics_frame.connect(func(): Input.action_release(action), CONNECT_ONE_SHOT)


func _place_player(pos: Vector2, face: int) -> void:
	_player.position = pos
	_player.velocity = Vector2.ZERO
	_player.facing = face
	_player._visual.scale.x = face


func _avg(values: Array) -> float:
	var total: float = 0.0
	for v in values:
		total += v
	return total / maxf(values.size(), 1.0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(label: String, ok: bool) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1
