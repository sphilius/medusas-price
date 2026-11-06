## perseus.gd (root script of scenes/enemies/perseus.tscn)
## Purpose: the boss. Perseus fights in 3 phases and only a gaze into his open chest
## hurts him:
##   1 FLIGHT    - hovers on winged sandals, then dives at Medusa.
##   (study)     - between phases 1 and 2 he hovers and his shield replays ghost echoes
##                 of her last gazes (marble Medusas where she stood), as if learning.
##   2 GROUNDED  - walks in and cuts with the harpe.
##   3 DESPERATE - shield-bash charges across the arena that shatter any statue; after
##                 each charge he braces behind the shield and only a lash of the
##                 whip knocks it aside (a whip icon pulses over him while he braces).
## The whip also parries: a lash while his gold glint shows (phases 2 and 3) cancels
## the attack and drops his shield for a longer window (PERSEUS_PARRY_WINDOW_MULT).
## Every attack is telegraphed by a gold glint and ends with his shield dropped for a
## window. A gaze held PERSEUS_GAZE_HIT_TIME on him in that window is a hit; after
## PERSEUS_GAZE_HITS_PER_PHASE hits the next phase starts; after phase 3 he turns to
## stone and the arena's exit opens (Events.boss_defeated).
## Gazing at him while his shield is up reflects it (2 cracks, like a mirror-bearer).
## Any attack that touches her costs CRACKS_PERSEUS.
## Readability (playtest 2026-11-05: phase 2 was unclear, phase 3 went unnoticed, the
## echoes meant nothing): while his shield is down a gaze-eye icon pulses over his head;
## six pips at the top of the screen (two per phase) fill as gaze hits land; each phase
## he loses leaves stone creeping further over him (petrify shader, partial), with a
## white flash; during the study the world dims and each echo is joined to his shield
## by a gold beam (he is studying her reflections), then the echoes shatter.
## If Medusa dies during the fight, the whole fight starts over from phase 1 when she
## gets up (Events.player_respawned): pips empty, stone gone, he rises to hover again.
## A lash that does neither (parry or braced shield) glances off with a gold spark and
## a clank, so the player sees the whip connect and learns when it matters.
## Adaptation (Features.PERSEUS_ADAPT): the window shrinks to her median reaction time
## + 0.15 s (clamped 0.45 to 1.0 s), and he attacks from the side she faces least.
## With the flag off the window stays SHIELD_WINDOW_BASE and he attacks from behind
## her current facing.
extends Enemy

enum State { HOVER, TELEGRAPH, DIVE, WALK, SLASH, BASH, SHIELD_DOWN, REEL, STUDY, DEFEATED, GUARD }

## Left and right edge of the arena floor he moves within (world x, px). Set in boss.tscn.
@export var arena_left: float = 0.0
@export var arena_right: float = 1600.0

## 1, 2 or 3.
var phase: int = 1
## Gaze hits landed in the current phase.
var hits_in_phase: int = 0
## Seconds from each shield drop to her gaze landing on him (for the adapted window).
var reactions: Array[float] = []
## Seconds she has spent facing left and facing right during the fight.
var facing_time: Dictionary = {-1: 0.0, 1: 0.0}
## Current behaviour; assigning it updates the pose (see _animate).
var state: State = State.HOVER:
	set(value):
		state = value
		_state_time = 0.0
		_animate()

## Seconds spent in the current state.
var _state_time: float = 0.0
## The arena floor height under him (world y of his center when standing), from spawn.
var _floor_y: float = 0.0
## Where the current attack is aimed / lined up (world x).
var _target_x: float = 0.0
## Which attack the telegraph leads into.
var _next_attack: State = State.DIVE
## Seconds the shield has been down this window, and whether she already reacted.
var _window: float = 0.0
var _reacted: bool = false
## Seconds before another reflect can cost her cracks.
var _reflect_cooldown: float = 0.0
## True once this attack has hurt her (one hit per attack).
var _attack_landed: bool = false

@onready var _shield: Node2D = $Visual/Shield
@onready var _glint: Polygon2D = $Glint

## The "gaze now" eye shown over his head while his shield is down.
var _eye: Sprite2D = null
## The whip icon over his head while he braces in phase 3 (null if the art is missing).
var _whip_icon: Sprite2D = null
## The boss pips (screen space) and the dimmer used in the study beat.
var _pips: Node2D = null
var _dim: ColorRect = null
## How far the stone has crept over him (0 = none); grows each phase he loses.
var _stone: float = 0.0
## Where the fight starts (set in _ready): a restart after her death puts him back here.
var _start_pos: Vector2 = Vector2.ZERO
## The study beat's movement tween, kept so a restart can stop it.
var _study_tween: Tween = null


## _ready runs once when he enters the scene. super._ready() runs Enemy's setup first
## (layers, sprite art, contact zone); @onready vars above are already filled by then.
func _ready() -> void:
	super._ready()
	_floor_y = global_position.y
	_start_pos = global_position
	# Her death freezes him; her getting up restarts the fight from phase 1.
	Events.player_died.connect(func(_p: Vector2) -> void:
		if state != State.DEFEATED:
			set_physics_process(false))
	Events.player_respawned.connect(func(_p: Vector2) -> void: _restart_fight())
	SpriteKit.weapon(_shield, &"shield")
	_place_shield(true)
	_glint.color = Color(Balance.COLOR_GOLD, Balance.GLINT_ALPHA)
	_glint.polygon = SpriteKit.sparkle(Balance.PERSEUS_GLINT_SIZE * 0.5)
	_glint.visible = false
	_eye = _build_icon("gaze", Balance.PERSEUS_EYE_SIZE)
	_whip_icon = _build_icon("whip", Balance.PERSEUS_WHIP_ICON_SIZE)
	_build_hud()
	_start_hover()


## A gold key icon (made by tools/cut_ui_icons.py) above his head, hidden until needed:
## "gaze" shows while his shield is down, "whip" while he braces in phase 3. Returns
## null (no icon, no error) if the art is missing.
func _build_icon(key: String, size_px: float) -> Sprite2D:
	if not ResourceLoader.exists(Balance.KEY_HINT_ICONS[key]):
		return null
	var icon := Sprite2D.new()
	icon.texture = load(Balance.KEY_HINT_ICONS[key])
	icon.modulate = Balance.COLOR_GOLD
	icon.position = Vector2(0.0, -half_size.y - Balance.PERSEUS_EYE_RISE)
	icon.scale = Vector2.ONE * (size_px / icon.texture.get_height())
	icon.visible = false
	add_child(icon)
	return icon


## A CanvasLayer (screen space, unaffected by the camera) holding the pips and the dimmer.
## The pips are drawn by a plain Node2D through its `draw` signal: connect() hooks our
## _draw_pips function to it, and queue_redraw() asks for a new drawing.
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = Balance.HUD_LAYER - 1
	add_child(layer)
	_dim = ColorRect.new()
	_dim.color = Color(Balance.COLOR_BLACK, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_dim)
	_pips = Node2D.new()
	_pips.position = Vector2(get_viewport_rect().size.x * 0.5, Balance.PERSEUS_PIPS_Y)
	_pips.draw.connect(_draw_pips)
	layer.add_child(_pips)
	_pips.queue_redraw()


## Six pips in three pairs: filled marble for landed hits, outlined for hits to come;
## the current phase's pair is ringed in gold.
func _draw_pips() -> void:
	var per: int = Balance.PERSEUS_GAZE_HITS_PER_PHASE
	var r: float = Balance.PERSEUS_PIP_RADIUS
	var step: float = r * 2.6
	var gap: float = r * 2.5
	var total_w: float = Balance.PERSEUS_PHASES * per * step + (Balance.PERSEUS_PHASES - 1) * gap
	var x: float = -total_w * 0.5 + r
	for ph in range(1, Balance.PERSEUS_PHASES + 1):
		for i in per:
			var landed: bool = ph < phase or (ph == phase and i < hits_in_phase) or state == State.DEFEATED
			var center := Vector2(x, 0.0)
			_pips.draw_circle(center, r + 2.0, Balance.COLOR_BLACK)
			if landed:
				_pips.draw_circle(center, r, Balance.COLOR_MARBLE)
			if ph == phase and state != State.DEFEATED:
				_pips.draw_arc(center, r + 3.5, 0.0, TAU, 20, Balance.COLOR_GOLD, 2.0)
			x += step
		x += gap


## The whip never hurts him (only the gaze does), but it opens him up:
##   - during his gold-glint wind-up on the ground (phases 2 and 3): a parry, the
##     attack is cancelled and the shield drops for a longer window;
##   - while he braces after a phase-3 charge: the shield is knocked aside.
## Any other lash glances off the shield.
func whip_hit(_away_dir: int) -> void:
	if state == State.TELEGRAPH and phase >= 2:
		_glint.visible = false
		_knocked(Balance.PERSEUS_PARRY_WINDOW_MULT)
		RunLedger.log_event("parry", {"enemy": "perseus"})
	elif state == State.GUARD:
		_knocked(1.0)
		RunLedger.log_event("perseus_shield_knocked", {"phase": phase})
	elif state != State.DEFEATED and state != State.STUDY:
		_glance()


## A lash that only hits the shield: a gold flash on it and a high clank, nothing else.
func _glance() -> void:
	Fx.play(&"mirror_glint", 1.4)
	_shield.modulate = Balance.COLOR_GOLD
	var back := create_tween()
	back.tween_property(_shield, "modulate", Color.WHITE, Balance.PERSEUS_GLANCE_FLASH_S)


## Her death undone: back to the very start of the fight (phase 1, no hits, no stone).
## The adaptation data (reactions, facing_time) is kept: he still remembers her.
func _restart_fight() -> void:
	if state == State.DEFEATED:
		return
	if _study_tween != null and _study_tween.is_valid():
		_study_tween.kill()
	phase = 1
	hits_in_phase = 0
	_stone = 0.0
	_gaze_time = 0.0
	if _petrify_mat != null:
		_petrify_mat.set_shader_parameter(&"progress", 0.0)
	if _dim != null:
		_dim.color = Color(Balance.COLOR_BLACK, 0.0)
	_glint.visible = false
	_place_shield(true)
	global_position = _start_pos
	velocity = Vector2.ZERO
	visual.modulate = Color.WHITE
	if _pips != null:
		_pips.queue_redraw()
	set_physics_process(true)
	_start_hover()


## The lash landed: gold flash, glint sound, hit-stop and shake, then the open window.
func _knocked(window_mult: float) -> void:
	_flash(Balance.COLOR_GOLD, Balance.PARRY_OPEN_S)
	Fx.play(&"mirror_glint", 0.8)
	Fx.hit_stop(Balance.HITSTOP_PARRY)
	Events.shake_requested.emit(Balance.SHAKE_PARRY_PX, Balance.SHAKE_PARRY_TIME)
	_drop_shield(window_mult)


## _physics_process runs every physics tick: count time, track which way she faces
## (for the least-guarded side), then run the current state's tick.
func _physics_process(delta: float) -> void:
	_state_time += delta
	_reflect_cooldown = maxf(_reflect_cooldown - delta, 0.0)
	if _eye != null:
		# Pulse the eye while he is open: sin() over time gives a smooth throb.
		_eye.visible = state == State.SHIELD_DOWN
		var throb: float = 1.0 + 0.15 * sin(_state_time * TAU * 2.0)
		_eye.scale = Vector2.ONE * throb * (Balance.PERSEUS_EYE_SIZE / _eye.texture.get_height())
	if _whip_icon != null:
		_whip_icon.visible = state == State.GUARD
		var beat: float = 1.0 + 0.15 * sin(_state_time * TAU * 2.0)
		_whip_icon.scale = Vector2.ONE * beat * (Balance.PERSEUS_WHIP_ICON_SIZE / _whip_icon.texture.get_height())
	var player: Player = find_player()
	if player != null:
		facing_time[player.facing] = float(facing_time[player.facing]) + delta
	match state:
		State.HOVER:
			_tick_hover(delta, player)
		State.TELEGRAPH:
			_tick_telegraph(player)
		State.DIVE:
			_tick_dive(delta, player)
		State.WALK:
			_tick_walk(delta, player)
		State.SLASH:
			_tick_slash(player)
		State.BASH:
			_tick_bash(delta, player)
		State.SHIELD_DOWN:
			_tick_window(delta)
		State.GUARD:
			_hold(delta)
			if _state_time >= Balance.PERSEUS_GUARD_TIME:
				_next_after_window()  # not knocked aside in time: he charges again
		State.REEL:
			_hold(delta)
			if _state_time >= Balance.PERSEUS_REEL_TIME:
				_next_after_window()
		State.STUDY:
			_hold_in_air(delta)
		State.DEFEATED:
			_hold(delta)


# ---------------------------------------------------------------------------
# Phase moves
# ---------------------------------------------------------------------------

## Phase 1 rest: rise to hover height and drift to the side he will dive from.
func _start_hover() -> void:
	var player: Player = find_player()
	_target_x = _attack_x(player)
	state = State.HOVER


## HOVER: glide to hover height above the attack point, then telegraph the dive.
func _tick_hover(_delta: float, player: Player) -> void:
	var goal := Vector2(_target_x, _floor_y - Balance.PERSEUS_HOVER_HEIGHT)
	velocity = (goal - global_position).limit_length(Balance.PERSEUS_DRIFT_SPEED)
	_face_toward(player)
	move_and_slide()
	if _state_time >= Balance.PERSEUS_HOVER_TIME:
		_telegraph(State.DIVE)


## Gold glint, hold still, then the attack it announces.
func _telegraph(attack: State) -> void:
	_next_attack = attack
	_glint.visible = true
	_place_glint()
	velocity = Vector2.ZERO
	state = State.TELEGRAPH


## TELEGRAPH: keep facing her while the glint shows, then start the announced attack.
func _tick_telegraph(player: Player) -> void:
	_face_toward(player)
	if _state_time < Balance.PERSEUS_TELEGRAPH_TIME:
		return
	_glint.visible = false
	_attack_landed = false
	# The attack aims where she is now, not where she will be.
	_target_x = player.global_position.x if player != null else global_position.x
	state = _next_attack


## Straight dive toward where she stood, until he reaches the floor.
func _tick_dive(_delta: float, player: Player) -> void:
	var goal := Vector2(_target_x, _floor_y)
	velocity = (goal - global_position).normalized() * Balance.PERSEUS_DIVE_SPEED
	move_and_slide()
	_hurt_on_touch(player)
	if global_position.y >= _floor_y - 2.0 or is_on_floor() or _state_time > 2.0:
		global_position.y = minf(global_position.y, _floor_y)
		_drop_shield()


## Phase 2: walk to cutting range on the side she guards least, then telegraph a cut.
func _tick_walk(delta: float, player: Player) -> void:
	apply_gravity(delta)
	_face_toward(player)
	var goal_x: float = player.global_position.x + _guard_side() * Balance.PERSEUS_SLASH_REACH * 0.8 \
			if player != null else global_position.x
	goal_x = clampf(goal_x, arena_left, arena_right)
	velocity.x = signf(goal_x - global_position.x) * Balance.PERSEUS_WALK_SPEED
	move_and_slide()
	if absf(goal_x - global_position.x) < 8.0 or _state_time > 3.0:
		velocity.x = 0.0
		_telegraph(State.SLASH)


## The harpe cut: live for PERSEUS_SLASH_TIME in front of him.
func _tick_slash(player: Player) -> void:
	if player != null and not _attack_landed:
		var d: Vector2 = player.global_position - global_position
		if d.x * facing > 0.0 and absf(d.x) <= Balance.PERSEUS_SLASH_REACH and absf(d.y) <= Balance.BL:
			_land_attack()
	if _state_time >= Balance.PERSEUS_SLASH_TIME:
		_drop_shield()


## Phase 3: charge across the arena, shattering statues, until a wall or the far edge.
func _tick_bash(delta: float, player: Player) -> void:
	apply_gravity(delta)
	velocity.x = facing * Balance.PERSEUS_BASH_SPEED
	move_and_slide()
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i).get_collider() as Statue
		if hit != null:
			hit.shatter()
	_hurt_on_touch(player)
	var at_edge: bool = global_position.x <= arena_left or global_position.x >= arena_right
	if at_edge or is_on_wall() or _state_time >= Balance.PERSEUS_BASH_MAX_TIME:
		velocity.x = 0.0
		_face_toward(player)
		state = State.GUARD  # braced: shield stays up until the whip knocks it aside


# ---------------------------------------------------------------------------
# The window (shield down) and gaze hits
# ---------------------------------------------------------------------------

## End of an attack (or a lash that opened him): shield down for the (adapted) window,
## stretched by `mult` (a parry gives a longer window).
func _drop_shield(mult: float = 1.0) -> void:
	velocity = Vector2.ZERO
	_window = adapted_window(reactions, Features.PERSEUS_ADAPT) * mult
	_reacted = false
	_place_shield(false)
	state = State.SHIELD_DOWN


## SHIELD_DOWN: stand open until the window runs out (gaze hits end it early).
func _tick_window(delta: float) -> void:
	_hold(delta)
	if _state_time >= _window:
		_next_after_window()


## Called by the gaze every physics frame he is in the cone with a clear view.
## Shield up: the gaze bounces back. Shield down: it counts toward a hit.
func add_gaze(delta: float) -> void:
	if state == State.DEFEATED or state == State.STUDY:
		return
	if state != State.SHIELD_DOWN:
		_reflect()
		return
	if not _reacted:
		_reacted = true
		reactions.append(_state_time)
	_gaze_time += delta
	if _gaze_time >= Balance.PERSEUS_GAZE_HIT_TIME:
		_gaze_time = 0.0
		register_gaze_hit()


## Called by the gaze when she looks away: the hold toward a hit starts over.
func reset_gaze() -> void:
	_gaze_time = 0.0


## One gaze hit: count it, flash, and move the fight on (next phase, or defeat).
func register_gaze_hit() -> void:
	hits_in_phase += 1
	Fx.play(&"petrify", 0.8)
	Fx.hit_stop(Balance.HITSTOP_PERSEUS)
	Events.shake_requested.emit(Balance.SHAKE_PERSEUS_HIT_PX, Balance.SHAKE_PERSEUS_HIT_TIME)
	RunLedger.log_event("perseus_hit", {"phase": phase, "hits": hits_in_phase})
	if _pips != null:
		_pips.queue_redraw()  # fill this hit's pip now, not only when the phase ends
	var flash := create_tween()
	visual.modulate = Balance.COLOR_MARBLE
	flash.tween_property(visual, "modulate", Color.WHITE, Balance.PERSEUS_REEL_TIME)
	if hits_in_phase < Balance.PERSEUS_GAZE_HITS_PER_PHASE:
		state = State.REEL
		return
	hits_in_phase = 0
	phase += 1
	if _pips != null:
		_pips.queue_redraw()
	if phase <= Balance.PERSEUS_PHASES:
		_phase_beat()
	if phase > Balance.PERSEUS_PHASES:
		_defeat()
	elif phase == 2:
		_study()
	else:
		state = State.REEL


## A phase lost: stone creeps further over him (kept on), a big shake and a flash.
func _phase_beat() -> void:
	_stone = Balance.PERSEUS_PHASE_STONE * (phase - 1)
	if sprite != null:
		if _petrify_mat == null:
			_petrify_mat = SpriteKit.petrify_material()
			_petrify_mat.set_shader_parameter(&"origin", Vector2(0.5, 0.0))  # from the head down
			sprite.material = _petrify_mat
		_petrify_mat.set_shader_parameter(&"progress", _stone)
	Fx.hit_stop(Balance.HITSTOP_PERSEUS * 2.0)
	Events.shake_requested.emit(Balance.SHAKE_PERSEUS_PHASE_PX, Balance.SHAKE_PERSEUS_PHASE_TIME)
	if _dim != null:
		var flash := create_tween()
		_dim.color = Color(Balance.COLOR_MARBLE, 0.6)
		flash.tween_property(_dim, "color", Color(Balance.COLOR_MARBLE, 0.0), 0.4)


## After a window (or a reel): the next attack of the current phase.
func _next_after_window() -> void:
	_place_shield(true)
	match phase:
		1:
			_start_hover()
		2:
			state = State.WALK
		_:
			var player: Player = find_player()
			_face_toward(player)
			_telegraph(State.BASH)


## The mirror throws her gaze back (once per cooldown): 2 cracks, gold beam.
func _reflect() -> void:
	if _reflect_cooldown > 0.0:
		return
	var player: Player = find_player()
	if player == null:
		return
	_reflect_cooldown = Balance.MIRROR_REFLECT_COOLDOWN
	var from: Vector2 = _shield.global_position
	var beam := Line2D.new()
	beam.top_level = true
	beam.points = PackedVector2Array([from, player.global_position + Balance.GAZE_EYE_OFFSET])
	beam.width = Balance.MIRROR_BEAM_WIDTH
	beam.default_color = Balance.COLOR_GOLD
	add_child(beam)
	var fade := beam.create_tween()
	fade.tween_property(beam, "modulate:a", 0.0, Balance.MIRROR_BEAM_TIME)
	fade.tween_callback(beam.queue_free)
	Events.gaze_reflected.emit(enemy_type, from)
	Events.player_hit.emit(Balance.CRACKS_REFLECT, &"reflect", from)


# ---------------------------------------------------------------------------
# Study beat and defeat
# ---------------------------------------------------------------------------

## Between phases 1 and 2: hover at the arena's middle while ghost echoes of her last
## gazes appear one after another, then come down for phase 2.
func _study() -> void:
	state = State.STUDY
	_place_shield(true)
	var echoes: Array = RunLedger.events_of("gaze")
	echoes = echoes.slice(maxi(echoes.size() - Balance.PERSEUS_ECHO_COUNT, 0))
	var tween := create_tween()
	_study_tween = tween
	if _dim != null:
		var dim := create_tween()
		dim.tween_property(_dim, "color", Color(Balance.COLOR_BLACK, Balance.PERSEUS_STUDY_DIM), 0.5)
		dim.tween_interval(Balance.PERSEUS_ECHO_TIME * (echoes.size() + 0.5))
		dim.tween_property(_dim, "color", Color(Balance.COLOR_BLACK, 0.0), 0.5)
	var middle := Vector2((arena_left + arena_right) * 0.5, _floor_y - Balance.PERSEUS_HOVER_HEIGHT)
	tween.tween_property(self, "global_position", middle, Balance.PERSEUS_ECHO_TIME * 0.5)
	for e: Dictionary in echoes:
		var data: Dictionary = e["data"]
		var where := Vector2(data["position"][0], data["position"][1])
		tween.tween_callback(_show_echo.bind(where, int(data["facing"])))
		tween.tween_interval(Balance.PERSEUS_ECHO_TIME)
	tween.tween_property(self, "global_position:y", _floor_y, Balance.PERSEUS_ECHO_TIME * 0.5)
	tween.tween_callback(func() -> void: state = State.WALK)


## One ghost: Medusa's gaze pose in pale marble at `where`, fading in and out.
func _show_echo(where: Vector2, dir: int) -> void:
	var info: Dictionary = Balance.SPRITE_ART[&"medusa"]
	if not ResourceLoader.exists(info["frames"]):
		return
	var ghost := AnimatedSprite2D.new()
	ghost.top_level = true
	ghost.sprite_frames = load(info["frames"]) as SpriteFrames
	ghost.animation = &"gaze"
	ghost.offset = info["offset"]
	ghost.scale = Vector2(dir, 1.0) * (float(info["height"]) / float(info["figure_h"]))
	ghost.global_position = where + Vector2(0.0, info["feet_y"])
	ghost.material = SpriteKit.marble_material()
	ghost.modulate = Color(Balance.COLOR_GOLD, 0.0)  # a gold-tinted reflection of her
	add_child(ghost)
	# The beam: his shield "sees" her old gaze, a thin gold line from shield to ghost.
	var beam := Line2D.new()
	beam.top_level = true
	beam.width = Balance.MIRROR_BEAM_WIDTH
	beam.default_color = Color(Balance.COLOR_GOLD, 0.8)
	beam.points = PackedVector2Array([_shield.global_position, where + Balance.GAZE_EYE_OFFSET])
	add_child(beam)
	Fx.play(&"mirror_glint")
	var fade := ghost.create_tween()
	fade.tween_property(ghost, "modulate:a", Balance.PERSEUS_ECHO_ALPHA, Balance.PERSEUS_ECHO_TIME * 0.3)
	fade.tween_interval(Balance.PERSEUS_ECHO_TIME * 0.4)
	fade.tween_callback(func() -> void:
		Fx.play(&"crack_portrait", 1.3)  # the reflection shatters like glass
		Fx.dust(where, 10, Balance.COLOR_GOLD))
	fade.tween_property(ghost, "modulate:a", 0.0, Balance.PERSEUS_ECHO_TIME * 0.3)
	fade.parallel().tween_property(beam, "modulate:a", 0.0, Balance.PERSEUS_ECHO_TIME * 0.3)
	fade.tween_callback(beam.queue_free)
	fade.tween_callback(ghost.queue_free)


## Phase 3 done: he kneels, stone spreads over him, he becomes a statue, exit opens.
func _defeat() -> void:
	state = State.DEFEATED
	_glint.visible = false
	if _pips != null:
		_pips.queue_redraw()
	var player: Player = find_player()
	if sprite != null:
		_petrify_mat = SpriteKit.petrify_material()
		var from: Vector2 = player.global_position + Balance.GAZE_EYE_OFFSET if player != null else global_position
		_petrify_mat.set_shader_parameter(&"origin", SpriteKit.frame_uv(sprite, from))
		sprite.material = _petrify_mat
	# A Tween changes a value over time: here it calls _set_stone(0 .. 1) over the
	# defeat time, then runs _finish_defeat once.
	var tween := create_tween()
	tween.tween_method(_set_stone, _stone, 1.0, Balance.PERSEUS_DEFEAT_STONE_TIME)
	tween.tween_callback(_finish_defeat)


## How far the stone has spread over him during the defeat (0 .. 1).
func _set_stone(t: float) -> void:
	if _petrify_mat != null:
		_petrify_mat.set_shader_parameter(&"progress", t)


## Fully stone: announce it (the exit opens) and swap him for a Statue.
func _finish_defeat() -> void:
	Events.boss_defeated.emit()
	petrify()


# ---------------------------------------------------------------------------
# Helpers (the two adaptation rules are static so the sim can test them directly)
# ---------------------------------------------------------------------------

## Shield-down window: clamp(median reaction + offset, min, max) when adapting and
## there is data, else the base window.
static func adapted_window(times: Array[float], adapt: bool) -> float:
	if not adapt or times.is_empty():
		return Balance.SHIELD_WINDOW_BASE
	var sorted: Array[float] = times.duplicate()
	sorted.sort()
	var n: int = sorted.size()
	var median: float = sorted[n / 2] if n % 2 == 1 else (sorted[n / 2 - 1] + sorted[n / 2]) * 0.5
	return clampf(median + Balance.SHIELD_WINDOW_ADAPT_OFFSET, Balance.SHIELD_WINDOW_MIN, Balance.SHIELD_WINDOW_MAX)


## The side (-1 left, 1 right of her) to attack from: the one she has faced least.
## A tie, or adaptation off, means behind her current facing.
static func least_guarded_side(times: Dictionary, current_facing: int, adapt: bool) -> int:
	if adapt:
		var left: float = times.get(-1, 0.0)
		var right: float = times.get(1, 0.0)
		if not is_equal_approx(left, right):
			return -1 if left < right else 1
	return -current_facing


## The side to attack from right now (reads her live facing for the fallback rule).
func _guard_side() -> int:
	var player: Player = find_player()
	return least_guarded_side(facing_time, player.facing if player != null else 1, Features.PERSEUS_ADAPT)


## Where to line up for the next attack: beside her on her least-guarded side.
func _attack_x(player: Player) -> float:
	if player == null:
		return global_position.x
	return clampf(player.global_position.x + _guard_side() * Balance.PERSEUS_ATTACK_OFFSET, arena_left, arena_right)


## Turn to look at her (and move the glint to the new front).
func _face_toward(player: Player) -> void:
	if player == null:
		return
	var dir: int = 1 if player.global_position.x >= global_position.x else -1
	if dir != facing:
		set_facing(dir)
		_place_glint()


## An attack touching her costs CRACKS_PERSEUS (once per attack).
func _hurt_on_touch(player: Player) -> void:
	if _attack_landed or player == null:
		return
	for node in _contact.get_overlapping_bodies():
		if node is Player:
			_land_attack()
			return


## The attack hit her: 2 cracks, and no second hit from the same attack.
func _land_attack() -> void:
	_attack_landed = true
	Events.player_hit.emit(Balance.CRACKS_PERSEUS, &"perseus", global_position)


## Stand still on the floor (gravity on).
func _hold(delta: float) -> void:
	apply_gravity(delta)
	velocity.x = 0.0
	move_and_slide()


## Hang still in the air (the study beat's tween moves him instead).
func _hold_in_air(_delta: float) -> void:
	velocity = Vector2.ZERO


## Shield raised in front (up) or dropped to his side (the open window).
func _place_shield(up: bool) -> void:
	_shield.position = Balance.PERSEUS_SHIELD_UP_POS if up else Balance.PERSEUS_SHIELD_DOWN_POS
	_shield.rotation = 0.0 if up else deg_to_rad(Balance.PERSEUS_SHIELD_DOWN_DEG)


## The glint lives outside Visual (not flipped with it), so mirror it by hand.
func _place_glint() -> void:
	_glint.position = Vector2(Balance.PERSEUS_GLINT_OFFSET.x * facing, Balance.PERSEUS_GLINT_OFFSET.y)


## Pose for the current state (called by the state setter).
func _animate() -> void:
	match state:
		State.HOVER, State.STUDY:
			SpriteKit.play(sprite, &"hover")
		State.TELEGRAPH:
			SpriteKit.play(sprite, &"hover" if phase == 1 else &"grounded")
		State.GUARD:
			SpriteKit.play(sprite, &"grounded")
		State.DIVE:
			SpriteKit.play(sprite, &"dive")
		State.WALK:
			SpriteKit.play(sprite, &"grounded")
		State.SLASH:
			SpriteKit.play(sprite, &"slash")
		State.BASH:
			SpriteKit.play(sprite, &"bash")
		State.SHIELD_DOWN, State.REEL:
			SpriteKit.play(sprite, &"shield_down")
		State.DEFEATED:
			SpriteKit.play(sprite, &"defeated")
