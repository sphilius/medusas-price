## balance.gd (autoload "Balance")
## Purpose: the single home for EVERY tuning number and color in the game.
## Rule: never type a gameplay number inline in another script; add a const here.
## All values are starting values from the Jam Design Spec - tune them here.
## Units: 1 BL (body length) = 64 px = Medusa's standing height.
extends Node

# ---------------------------------------------------------------------------
# Units
# ---------------------------------------------------------------------------
## Pixels in one body length (BL).
const BL: float = 64.0

# ---------------------------------------------------------------------------
# Physics layer bits (names live in project.godot [layer_names])
# ---------------------------------------------------------------------------
const PHYS_WORLD: int = 1        # layer 1
const PHYS_PLAYER: int = 2       # layer 2
const PHYS_ENEMIES: int = 4      # layer 3
const PHYS_STATUES: int = 8      # layer 4
const PHYS_GAZE: int = 32        # layer 6
## Layer 7: sight blockers only (column shafts). Nothing collides with it; it only
## stops the gaze's line-of-sight ray, so you cannot stare through solid stone.
const PHYS_SIGHT: int = 64

# ---------------------------------------------------------------------------
# Color code (the wordless UI)
# ---------------------------------------------------------------------------
## Terracotta = the living world.
const COLOR_TERRACOTTA: Color = Color("C8643B")
## Near-black = bodies in motion.
const COLOR_BLACK: Color = Color("1A1410")
## Marble white = stone, cost, cracks.
const COLOR_MARBLE: Color = Color("F2EFE8")
## Gold = danger and power (gaze cone, mirror glints, telegraphs).
const COLOR_GOLD: Color = Color("E8B547")
## Dark clay brown: terrain and architecture in the painted art.
const COLOR_CLAY_DARK: Color = Color("7A3A22")
## The plain backdrop behind a level whose painting is missing (a dim clay grey).
const COLOR_BACKDROP: Color = Color(0.42, 0.36, 0.3)

# ---------------------------------------------------------------------------
# Player movement
# ---------------------------------------------------------------------------
## Top running speed (px/s).
const PLAYER_RUN_SPEED: float = 300.0
## Sprint (hold Shift, PC only): top speed becomes PLAYER_RUN_SPEED x this. Because the
## speed carries through a jump, a sprint jump also travels farther (about 1.5x the reach
## of a normal jump). Whether she sprints is decided on her last frame on the ground, so
## pressing or releasing Shift in mid-air does not bend the jump arc.
const PLAYER_SPRINT_MULT: float = 1.5
## Ground acceleration (px/s^2).
const PLAYER_GROUND_ACCEL: float = 2400.0
## Gravity (px/s^2).
const PLAYER_GRAVITY: float = 1800.0
## Jump apex height in body lengths (about 2 BL).
const PLAYER_JUMP_APEX_BL: float = 2.0
## Upward launch speed that reaches the apex: v = sqrt(2 * g * h). Negative = up.
## (sqrt(2 * 1800 * 128) = 678.8)
const PLAYER_JUMP_VELOCITY: float = -678.8
## Seconds after leaving a ledge during which jump still works.
const PLAYER_COYOTE_TIME: float = 0.10
## Seconds a jump press is remembered before landing.
const PLAYER_JUMP_BUFFER: float = 0.12
## Releasing jump early multiplies upward speed by this (variable jump height).
const PLAYER_JUMP_CUT: float = 0.5

# ---------------------------------------------------------------------------
# Gaze (hold K)
# ---------------------------------------------------------------------------
## Cone length in BL.
const GAZE_LENGTH_BL: float = 4.0
## Cone half-angle in degrees (facing direction only).
const GAZE_HALF_ANGLE_DEG: float = 20.0
## Seconds an enemy must stay inside the cone to petrify.
const GAZE_HOLD: float = 0.4
## Same, for eye-shading soldiers.
const GAZE_HOLD_EYE_SHADING: float = 0.7
## Where the cone starts, relative to Medusa's center (her eyes).
const GAZE_EYE_OFFSET: Vector2 = Vector2(0.0, -20.0)
## Alpha of the gold cone polygon.
const GAZE_CONE_ALPHA: float = 0.35
## Points along the cone's far arc (more = rounder).
const GAZE_ARC_SEGMENTS: int = 8
## Line-of-sight ray mask: anything on these layers blocks the gaze.
const GAZE_LOS_MASK: int = PHYS_WORLD | PHYS_STATUES | PHYS_SIGHT

# ---------------------------------------------------------------------------
# Game feel
# ---------------------------------------------------------------------------
## Hit-stop on petrify: real seconds, and the time scale held during it.
const HITSTOP_DURATION: float = 0.08
# --- Juice (Prompt 17) ---
## Hit-stops (s): statue shatter, Medusa hurt.
const HITSTOP_SHATTER: float = 0.04
const HITSTOP_HURT: float = 0.05
## Shake when Medusa is hurt.
const SHAKE_HURT_PX: float = 5.0
const SHAKE_HURT_TIME: float = 0.18
## Squash and stretch (x, y scale): springing up, landing; how fast it eases back (1/s).
const JUICE_JUMP_STRETCH: Vector2 = Vector2(0.84, 1.16)
const JUICE_LAND_SQUASH: Vector2 = Vector2(1.2, 0.82)
const JUICE_SQUASH_RETURN: float = 12.0
## A landing counts (squash + dust) when she was falling faster than this (px/s).
const JUICE_LAND_MIN_SPEED: float = 250.0
## Dust specks: landing, each run puff, a petrify, a shatter, a whip hit.
const JUICE_LAND_DUST: int = 8
const JUICE_RUN_DUST: int = 3
const JUICE_PETRIFY_DUST: int = 12
const JUICE_SHATTER_DUST: int = 18
const JUICE_WHIP_DUST: int = 5
## Run dust: a puff every this many seconds above this speed (px/s).
const JUICE_RUN_DUST_EVERY: float = 0.28
const JUICE_RUN_DUST_SPEED: float = 200.0
## Whip smear: opacity and seconds to fade.
const WHIP_SMEAR_ALPHA: float = 0.45
const WHIP_SMEAR_S: float = 0.1
## Camera look-ahead toward where she faces (px) and how fast it eases (1/s).
const CAMERA_LOOKAHEAD_PX: float = 56.0
const CAMERA_LOOKAHEAD_EASE: float = 3.0
## Vignette by portrait stage: radius where the dark starts (0 = centre, 1 = corner)
## and how dark the corners get, from stage 1 to stage 5.
const VIGNETTE_SHADER: String = "res://shaders/vignette.gdshader"
const VIGNETTE_INNER_START: float = 0.75
const VIGNETTE_INNER_END: float = 0.4
const VIGNETTE_STRENGTH_START: float = 0.25
const VIGNETTE_STRENGTH_END: float = 0.7
const HITSTOP_TIME_SCALE: float = 0.05
## Camera shake on petrify: max offset (px) and decay time (s).
const SHAKE_PETRIFY_PX: float = 6.0
const SHAKE_PETRIFY_TIME: float = 0.2
## Sample rate (Hz) of every placeholder sound generated in code.
const SFX_MIX_RATE: int = 22050
## Music (autoload Music): stage loops by number, the extras, their scene indexes in
## GameFlow.ORDER, the playing and silent volumes (dB), and the crossfade time (s).
# --- Story reel (scripts/story_reel.gd) and level transitions (GameFlow) ---
## The panels in order: picture, seconds on screen, zoom and pan (px) at start and end,
## and an optional sound. The portrait-aging beat follows them.
const STORY_PANELS: Array[Dictionary] = [
	{"path": "res://art/story/panel_1_temple.png", "seconds": 3.5, "zoom_from": 1.0, "zoom_to": 1.08, "pan_from": Vector2.ZERO, "pan_to": Vector2(-20, 0)},
	{"path": "res://art/story/panel_2_gorgon.png", "seconds": 3.0, "zoom_from": 1.0, "zoom_to": 1.3, "pan_from": Vector2.ZERO, "pan_to": Vector2(-60, 40), "sound": "hiss"},
	{"path": "res://art/story/panel_3_heroes.png", "seconds": 3.5, "zoom_from": 1.12, "zoom_to": 1.12, "pan_from": Vector2(60, 0), "pan_to": Vector2(-60, 0)},
	{"path": "res://art/story/panel_4_gaze.png", "seconds": 3.5, "zoom_from": 1.15, "zoom_to": 1.0, "pan_from": Vector2.ZERO, "pan_to": Vector2.ZERO, "sound": "petrify"},
]
## Seconds per portrait stage in the aging beat, fade time (s), and the skip delay (s).
const STORY_PORTRAIT_STEP_S: float = 0.9
const STORY_FADE_S: float = 0.6
const STORY_SKIP_AFTER: float = 2.0
## Between levels: the painting shown before each GameFlow index, its seconds and zoom.
const TRANSITION_PANELS: Dictionary = {
	2: "res://art/bg/level_2_bg.png",
	3: "res://art/bg/level_3_bg.png",
	4: "res://art/bg/level_4_bg.png",
}
## Between levels, a short wordless story reel (scripts/story_reel.gd, no portrait
## beat): the panels shown before each GameFlow index (2 cliffs, 3 cave, 4 boss,
## 6 ending). Prompts for the art: docs/art/storyboard_prompts.md. Panels whose file is
## missing are skipped; with none at all, TRANSITION_PANELS (one painting) is used.
const TRANSITION_BEAT_S: float = 3.8
const TRANSITION_STORIES: Dictionary = {
	2: [
		{"path": "res://art/story/ch2_1.webp", "seconds": TRANSITION_BEAT_S, "zoom_from": 1.0, "zoom_to": 1.1, "pan_from": Vector2.ZERO, "pan_to": Vector2(-20, -10)},
		{"path": "res://art/story/ch2_2.webp", "seconds": TRANSITION_BEAT_S, "zoom_from": 1.12, "zoom_to": 1.12, "pan_from": Vector2(50, 0), "pan_to": Vector2(-50, 0)},
		{"path": "res://art/story/ch2_3.webp", "seconds": TRANSITION_BEAT_S, "zoom_from": 1.12, "zoom_to": 1.0, "pan_from": Vector2.ZERO, "pan_to": Vector2.ZERO},
	],
	3: [
		{"path": "res://art/story/ch3_1.webp", "seconds": TRANSITION_BEAT_S, "zoom_from": 1.0, "zoom_to": 1.1, "pan_from": Vector2.ZERO, "pan_to": Vector2(-20, -10)},
		{"path": "res://art/story/ch3_2.webp", "seconds": TRANSITION_BEAT_S, "zoom_from": 1.12, "zoom_to": 1.12, "pan_from": Vector2(50, 0), "pan_to": Vector2(-50, 0)},
		{"path": "res://art/story/ch3_3.webp", "seconds": TRANSITION_BEAT_S, "zoom_from": 1.12, "zoom_to": 1.0, "pan_from": Vector2.ZERO, "pan_to": Vector2.ZERO},
	],
	4: [
		{"path": "res://art/story/ch4_1.webp", "seconds": TRANSITION_BEAT_S, "zoom_from": 1.0, "zoom_to": 1.1, "pan_from": Vector2.ZERO, "pan_to": Vector2(-20, -10)},
		{"path": "res://art/story/ch4_2.webp", "seconds": TRANSITION_BEAT_S, "zoom_from": 1.12, "zoom_to": 1.12, "pan_from": Vector2(50, 0), "pan_to": Vector2(-50, 0)},
		{"path": "res://art/story/ch4_3.webp", "seconds": TRANSITION_BEAT_S, "zoom_from": 1.12, "zoom_to": 1.0, "pan_from": Vector2.ZERO, "pan_to": Vector2.ZERO},
	],
	6: [
		{"path": "res://art/story/end_1.webp", "seconds": TRANSITION_BEAT_S, "zoom_from": 1.0, "zoom_to": 1.1, "pan_from": Vector2.ZERO, "pan_to": Vector2(-20, -10)},
		{"path": "res://art/story/end_2.webp", "seconds": TRANSITION_BEAT_S, "zoom_from": 1.12, "zoom_to": 1.12, "pan_from": Vector2(50, 0), "pan_to": Vector2(-50, 0)},
		{"path": "res://art/story/end_3.webp", "seconds": TRANSITION_BEAT_S, "zoom_from": 1.12, "zoom_to": 1.0, "pan_from": Vector2.ZERO, "pan_to": Vector2.ZERO},
	],
}
const TRANSITION_S: float = 2.4
const TRANSITION_ZOOM: float = 1.08
const MUSIC_STAGE_PATH: String = "res://audio/music/stage_%d.ogg"
const MUSIC_BOSS_PATH: String = "res://audio/music/boss.ogg"
const MUSIC_ENDING_PATH: String = "res://audio/music/ending.ogg"
const MUSIC_BOSS_SCENE: int = 4
const MUSIC_ENDING_SCENE: int = 6
const MUSIC_VOLUME_DB: float = -8.0
const MUSIC_SILENT_DB: float = -60.0
const MUSIC_FADE_S: float = 2.0
## Recorded sound effects (CC0, Freesound; see audio/CREDITS.md), played by Fx.play().
const SFX_FILES: Dictionary = {
	&"petrify": "res://audio/sfx/petrify.ogg",
	&"statue_crack": "res://audio/sfx/statue_crack.ogg",
	&"statue_shatter": "res://audio/sfx/statue_shatter.ogg",
	&"statue_thud": "res://audio/sfx/statue_thud.ogg",
	&"grind_loop": "res://audio/sfx/grind_loop.ogg",
	&"whip_snap": "res://audio/sfx/whip_snap.ogg",
	&"hiss": "res://audio/sfx/hiss.ogg",
	&"arrow": "res://audio/sfx/arrow.ogg",
	&"mirror_glint": "res://audio/sfx/mirror_glint.ogg",
	&"reflect": "res://audio/sfx/reflect.ogg",
	&"pool": "res://audio/sfx/pool.ogg",
	&"crack_portrait": "res://audio/sfx/crack_portrait.ogg",
	&"spear": "res://audio/sfx/spear.ogg",
	&"crumble": "res://audio/sfx/crumble.ogg",
	&"gate": "res://audio/sfx/gate.ogg",
	&"shard": "res://audio/sfx/shard.ogg",
}
## Per-sound volume trims in dB (0 = as recorded); tune by ear.
const SFX_VOLUME_DB: Dictionary = {
	&"hiss": -8.0, &"crack_portrait": -6.0, &"spear": -20.0, &"gate": -4.0, &"shard": -4.0, &"statue_thud": -3.0,
}
## How many copies of one sound may overlap, and the random pitch spread (+/-).
const SFX_POLYPHONY: int = 4
const SFX_PITCH_JITTER: float = 0.06
## Death replays the petrify crackle lower and slower; a gate closing sounds lower.
const SFX_DEATH_PITCH: float = 0.6
const SFX_GATE_CLOSE_PITCH: float = 0.8
## Placeholder crack sound, generated in code: length (s), random pitch jitter
## (+/-), noise decay rate, thunk frequency (Hz), noise and thunk mix levels,
## and volume (dB).
const CRACK_SFX_LENGTH: float = 0.06
const CRACK_SFX_PITCH_JITTER: float = 0.1
const CRACK_SFX_DECAY: float = 70.0
const CRACK_SFX_THUNK_HZ: float = 110.0
const CRACK_SFX_NOISE_MIX: float = 0.7
const CRACK_SFX_THUNK_MIX: float = 0.5
const CRACK_SFX_VOLUME_DB: float = -6.0

# ---------------------------------------------------------------------------
# Whip (hold J) - snake hair
# ---------------------------------------------------------------------------
## Reach in BL.
const WHIP_REACH_BL: float = 2.0
## Number of snakes in the fan (3 to 5).
const WHIP_SNAKES_MIN: int = 3
const WHIP_SNAKES_MAX: int = 5
## Phase timings in seconds. No whip or gaze during anticipation/recovery.
const WHIP_ANTICIPATION: float = 0.15
const WHIP_ACTIVE: float = 0.10
const WHIP_RECOVERY: float = 0.20
## Gravity multiplier while the lash is active in the air.
const WHIP_AIR_GRAVITY_MULT: float = 0.5
## Enemy stagger (s) and knockback (BL) when hit.
const WHIP_STAGGER: float = 0.4
const WHIP_KNOCKBACK_BL: float = 1.0
## Seconds a mirror-bearer's mirror is knocked aside.
const WHIP_MIRROR_KNOCK: float = 1.5
## Whip combat. Lashes to kill each enemy type (hp); anything unlisted uses the default.
const ENEMY_WHIP_HP: Dictionary = {
	&"hoplite": 5, &"leaper": 4, &"archer": 4, &"mirror_bearer": 6, &"eye_shading": 6,
}
const ENEMY_WHIP_HP_DEFAULT: int = 5
## A whip kill: seconds to slump and fade, and dust specks.
const ENEMY_DEATH_S: float = 0.6
const DUST_DEATH_COUNT: int = 14
## White flash on each lash (s).
const HIT_FLASH_S: float = 0.12
## Parry: seconds exposed, the gaze hold while exposed (s), hit-stop (s), shake.
const PARRY_OPEN_S: float = 1.5
const PARRY_GAZE_HOLD: float = 0.08
const HITSTOP_PARRY: float = 0.09
const SHAKE_PARRY_PX: float = 5.0
const SHAKE_PARRY_TIME: float = 0.15
## Snake finisher: seconds of struggle, poison tint, hit-stop.
const FINISHER_TIME: float = 0.55
const FINISHER_POISON_TINT: Color = Color(0.35, 0.45, 0.25, 1.0)
const HITSTOP_FINISHER: float = 0.12
## Dust puffs (Fx.dust): colour, seconds a speck lives, launch speed and gravity (px/s).
const DUST_COLOR: Color = Color(0.93, 0.88, 0.8, 0.9)
const DUST_LIFETIME: float = 0.55
const DUST_SPEED: float = 110.0
const DUST_GRAVITY: float = 260.0
## Where the snakes grow from, relative to Medusa's center (her head). Reach is
## measured from here, so the tip sits WHIP_REACH_BL ahead of her center.
const WHIP_HEAD_OFFSET: Vector2 = Vector2(0.0, -22.0)
## The hitbox fan is this tall (BL) at its far end and narrows to a point at the head.
const WHIP_END_HEIGHT_BL: float = 0.6
## The fan's centerline droops this many px by its tip, so the lash also lands on
## short enemies (the leaper) standing level with her.
const WHIP_TIP_DROOP: float = 18.0
## Snakes drawn at full fan (3 to 5) and their line width (px).
const WHIP_SNAKES_DRAWN: int = 5
const WHIP_LINE_WIDTH: float = 4.0
## Placeholder animation, one entry per frame: coil, head back, throw, full fan,
## hold, retract, retract, neutral. Extent is the fraction of reach the snakes
## stretch (negative = pulled back behind the head), spread is how open the fan is
## (0 = snakes bundled, 1 = full hitbox width), snakes is how many are drawn.
## Anticipation shows frames 0-1, the active hitbox frames 2-3, recovery 4-7.
const WHIP_FRAME_EXTENT: Array[float] = [0.15, -0.30, 0.60, 1.0, 1.0, 0.65, 0.30, 0.0]
const WHIP_FRAME_SPREAD: Array[float] = [0.0, 0.0, 0.5, 1.0, 1.0, 0.6, 0.2, 0.0]
const WHIP_FRAME_SNAKES: Array[int] = [3, 3, 4, 5, 5, 4, 3, 0]
## How many animation frames belong to anticipation and to the active lash; the
## rest play during recovery. Each phase's frames split its time equally.
const WHIP_ANTICIPATION_FRAMES: int = 2
const WHIP_ACTIVE_FRAMES: int = 2
## Deceleration (px/s^2) of a staggered enemy sliding from a whip knockback. The
## launch speed is derived so the slide covers WHIP_KNOCKBACK_BL: v = sqrt(2 * a * d).
const ENEMY_KNOCKBACK_DECEL: float = 1600.0

# ---------------------------------------------------------------------------
# Statues
# ---------------------------------------------------------------------------
## Seconds of continuous push-contact before a statue starts sliding.
const STATUE_PUSH_DELAY: float = 0.4
## Slide speed (px/s).
const STATUE_PUSH_SPEED: float = 96.0
## Grinding loop pitch range, rising with speed.
const STATUE_GRIND_PITCH_MIN: float = 0.9
const STATUE_GRIND_PITCH_MAX: float = 1.2
## Slide acceleration (px/s^2): a short ramp to full speed, so the grind pitch rises.
const STATUE_PUSH_ACCEL: float = 480.0
## Seconds a slide keeps going after the last push contact (absorbs one-frame gaps).
const STATUE_PUSH_GRACE: float = 0.05
## How square-on the contact must be to count as a push (|normal.x| at least this).
const STATUE_PUSH_NORMAL: float = 0.7
## Gravity for a statue pushed off an edge (px/s^2).
const STATUE_GRAVITY: float = PLAYER_GRAVITY
## A statue still falling after this many seconds went into a pit and is removed.
const STATUE_MAX_FALL_TIME: float = 3.0
## Camera shake when a falling statue lands: max offset (px) and decay time (s).
const SHAKE_STATUE_LAND_PX: float = 4.0
const SHAKE_STATUE_LAND_TIME: float = 0.15
## Placeholder grinding loop, generated in code: length (s), low-pass smoothing
## (0..1, higher = duller), gain, volume (dB).
const GRIND_SFX_LENGTH: float = 0.5
const GRIND_SFX_SMOOTH: float = 0.92
const GRIND_SFX_GAIN: float = 3.0
## Grind loop volume (dB). The recording is normalized to a -1 dB peak (it was -13 dB,
## and at -10 here the slide was silent in playtest).
const GRIND_SFX_VOLUME_DB: float = -2.0
## How fast the positional grind fades with distance (1 = Godot default, lower = gentler).
const GRIND_SFX_ATTENUATION: float = 0.4
## Placeholder thud, generated in code: length (s), frequency (Hz), decay rate,
## volume (dB), and pitch multiplier for a slide stopping (a landing uses 1.0).
const THUD_SFX_LENGTH: float = 0.18
const THUD_SFX_HZ: float = 55.0
const THUD_SFX_DECAY: float = 25.0
const THUD_SFX_VOLUME_DB: float = -3.0
const THUD_SFX_STOP_PITCH: float = 1.4

# ---------------------------------------------------------------------------
# Statue cracks and shatter (the whip: first hit cracks, second shatters)
# ---------------------------------------------------------------------------
## Fracture lines drawn over a cracked statue (alternating down and across), the
## zigzag segments per line, how far a zigzag strays from its straight path (as a
## fraction of the statue's shorter side), and the line widths (px): the white
## crack on top of a wider dark edge (alpha) so it still reads on marble.
const STATUE_CRACK_LINES: int = 6
const STATUE_CRACK_SEGMENTS: int = 5
const STATUE_CRACK_JITTER: float = 0.12
const STATUE_CRACK_WIDTH: float = 2.0
const STATUE_CRACK_EDGE_WIDTH: float = 4.0
const STATUE_CRACK_EDGE_ALPHA: float = 0.5
## Chip burst when a statue cracks: count, lifetime (s), spread (degrees either side
## of straight up), launch speed range (px/s), and square size range (px).
const STATUE_CHIP_COUNT: int = 10
const STATUE_CHIP_SPREAD_DEG: float = 90.0
const STATUE_CHIP_LIFETIME: float = 0.5
const STATUE_CHIP_SPEED_MIN: float = 90.0
const STATUE_CHIP_SPEED_MAX: float = 220.0
const STATUE_CHIP_SIZE_MIN: float = 2.0
const STATUE_CHIP_SIZE_MAX: float = 4.0
## Rubble burst when a statue shatters (the statue is freed once it ends); 180 degrees
## of spread is a full circle.
const STATUE_RUBBLE_COUNT: int = 32
const STATUE_RUBBLE_SPREAD_DEG: float = 180.0
const STATUE_RUBBLE_LIFETIME: float = 0.9
const STATUE_RUBBLE_SPEED_MIN: float = 80.0
const STATUE_RUBBLE_SPEED_MAX: float = 300.0
const STATUE_RUBBLE_SIZE_MIN: float = 4.0
const STATUE_RUBBLE_SIZE_MAX: float = 9.0
## Placeholder statue-crack sound: the petrify crack at this pitch (lower = heavier).
const STATUE_CRACK_SFX_PITCH: float = 0.75
## Placeholder shatter, generated in code: length (s), noise decay rate, rumble
## frequency (Hz), noise and rumble mix levels, volume (dB).
const SHATTER_SFX_LENGTH: float = 0.5
const SHATTER_SFX_DECAY: float = 9.0
const SHATTER_SFX_RUMBLE_HZ: float = 70.0
const SHATTER_SFX_NOISE_MIX: float = 0.8
const SHATTER_SFX_RUMBLE_MIX: float = 0.5
const SHATTER_SFX_VOLUME_DB: float = -4.0

# ---------------------------------------------------------------------------
# Pressure plate (scenes/props/pressure_plate.tscn)
# ---------------------------------------------------------------------------
## Width in BL, and how tall (px) the trigger zone is above the plate's surface.
## Anything standing on the floor there overlaps it; something jumping over briefly
## does too, which the plate ignores (see PressurePlate._counts).
const PLATE_WIDTH_BL: float = 1.0
const PLATE_TRIGGER_HEIGHT: float = 8.0
## Slab height (px) and how much of it is left when pressed (scale, 0..1).
const PLATE_SLAB_HEIGHT: float = 6.0
const PLATE_PRESSED_SCALE: float = 0.35

# ---------------------------------------------------------------------------
# Enemies
# ---------------------------------------------------------------------------
## Hoplite spear reach (BL) and thrust wind-up (s, shows a gold glint).
const HOPLITE_SPEAR_REACH_BL: float = 1.5
const HOPLITE_WINDUP: float = 0.35
## Gravity for all enemies (px/s^2).
const ENEMY_GRAVITY: float = PLAYER_GRAVITY
## Enemies below this y (px) fell into a pit and are removed.
const ENEMY_KILL_Y: float = 1600.0
## Player below this y (px) fell into a pit: backstop for when no Pit zone caught her.
const PLAYER_PIT_Y: float = 1400.0
## How far below the feet / ahead of the body (px) the ledge check looks.
const ENEMY_LEDGE_PROBE_DOWN: float = 24.0
const ENEMY_LEDGE_PROBE_AHEAD: float = 8.0
## The ledge ray starts this far (px) above the feet, so it never begins inside the floor.
const ENEMY_LEDGE_PROBE_INSET: float = 4.0
## Half the standing enemy body width / height (px), the ledge probe's origin.
const ENEMY_HALF_WIDTH: float = 20.0
const ENEMY_HALF_HEIGHT: float = 32.0
## Enemy bodies are solid to Medusa (she can't run through them) and touching one hurts.
## The touch zone is the body grown by this many px on every side, so a body pressed
## flat against hers still counts as touching. A whip-staggered enemy blocks but is harmless.
const ENEMY_CONTACT_MARGIN: float = 2.0
## A replacement leaper (owed after a pit fall) waits until Medusa is at least this many
## BL from its spawn point, so it never appears inside her.
const LEAPER_RESPAWN_CLEARANCE_BL: float = 2.0
## Size (px) of the hoplite's gold wind-up glint.
const HOPLITE_GLINT_SIZE: float = 5.0
## Every attack glint: a four-point sparkle (SpriteKit.sparkle) whose waist is this
## fraction of its radius, drawn slightly see-through so it stays subtle.
const GLINT_WAIST: float = 0.18
const GLINT_ALPHA: float = 0.85
## Hoplite art geometry, matching scenes/enemies/hoplite.tscn: the Glint
## polygon's radius and the spear tip's x in the Visual's right-facing space (px).
const HOPLITE_GLINT_ART_RADIUS: float = 5.0
const HOPLITE_SPEAR_TIP_X: float = 52.0

## Hoplite: patrol speed, chase speed (px/s), patrol half-width (BL), notice
## range (BL), vertical slack for "same level" (BL), thrust active time and
## recovery after the thrust (s), thrust hitbox thickness (px), and how far
## the spear is drawn back during the wind-up (px).
const HOPLITE_PATROL_SPEED: float = 50.0
const HOPLITE_CHASE_SPEED: float = 90.0
const HOPLITE_PATROL_BL: float = 2.0
const HOPLITE_NOTICE_BL: float = 5.0
const HOPLITE_LEVEL_SLACK_BL: float = 1.0
const HOPLITE_THRUST_ACTIVE: float = 0.12
const HOPLITE_RECOVERY: float = 0.5
const HOPLITE_HITBOX_THICKNESS: float = 14.0
const HOPLITE_SPEAR_DRAW_BACK: float = 16.0

## Leaper: leap trigger range (BL), vertical slack (BL), nearest target (BL),
## leap apex height (BL), fastest horizontal leap speed (px/s), pause after
## landing (s) and minimum landing time before it counts (s).
const LEAPER_RANGE_BL: float = 6.0
const LEAPER_LEVEL_SLACK_BL: float = 2.0
const LEAPER_MIN_DISTANCE_BL: float = 1.0
const LEAPER_APEX_BL: float = 1.5
const LEAPER_MAX_SPEED: float = 500.0
const LEAPER_RECOVERY: float = 0.8
const LEAPER_MIN_AIR_TIME: float = 0.1
## Spacing (px) of the floor samples between the leaper and the player when
## checking she is across a gap (smaller than any gap worth leaping).
const LEAPER_GAP_PROBE_STEP: float = 16.0

## Archer: sees the player within this range (BL) and in line of sight; draw time (s,
## gold glint on the arrowhead), cooldown between shots (s), arrow launch speed (px/s)
## and gravity (px/s^2), how much of the player's motion it leads (0 = aims at her
## feet-first position, 1 = full lead), where the arrow leaves the body (px from the
## center, facing side), glint size (px, the art's radius is ARCHER_GLINT_ART_RADIUS).
const ARCHER_RANGE_BL: float = 9.0
const ARCHER_DRAW_TIME: float = 0.5
const ARCHER_COOLDOWN: float = 2.5
const ARCHER_LEAD: float = 0.5
const ARCHER_MUZZLE: Vector2 = Vector2(26.0, -8.0)
const ARCHER_GLINT_SIZE: float = 5.0
const ARCHER_GLINT_ART_RADIUS: float = 5.0
## Arrow: speed (px/s), gravity (px/s^2), seconds it stays stuck in a wall or statue
## before fading away, seconds it may fly before it is dropped, and its length (px).
const ARROW_SPEED: float = 700.0
const ARROW_GRAVITY: float = 600.0
const ARROW_STUCK_TIME: float = 4.0
const ARROW_MAX_FLIGHT: float = 3.0
const ARROW_LENGTH: float = 28.0

## Mirror-bearer: patrol and chase speeds (px/s), patrol half-width (BL), notice range
## (BL), vertical slack (BL), the gap he keeps from Medusa (BL), mirror glint period
## and flash length (s), seconds between reflected gazes (matches her invulnerability),
## and how long the gold reflection beam is drawn (s) and how wide (px).
const MIRROR_PATROL_SPEED: float = 50.0
const MIRROR_CHASE_SPEED: float = 80.0
const MIRROR_PATROL_BL: float = 2.0
const MIRROR_NOTICE_BL: float = 6.0
const MIRROR_LEVEL_SLACK_BL: float = 1.0
const MIRROR_STOP_BL: float = 1.5
const MIRROR_GLINT_PERIOD: float = 1.0
const MIRROR_GLINT_TIME: float = 0.15
const MIRROR_REFLECT_COOLDOWN: float = 1.0
const MIRROR_BEAM_TIME: float = 0.25
const MIRROR_BEAM_WIDTH: float = 5.0
## Mirror centre relative to the body, facing side (px); the knocked-aside mirror
## swings by this many degrees (it hangs down and away from the gaze).
const MIRROR_HELD_OFFSET: Vector2 = Vector2(26.0, -10.0)
const MIRROR_KNOCK_DEG: float = 80.0
const MIRROR_GLINT_SIZE: float = 8.0
const MIRROR_GLINT_ART_RADIUS: float = 5.0

## DEFAULT size of the level 1 gap (BL): the open space between the near and far ledges
## in scenes/test_room.tscn, where the leaper first shows up. This is the default size;
## it was 5.0 BL until it was shrunk by half a body length on 2026-11-02. The scene holds
## the real geometry (LedgeNear's right edge to LedgeFar's left edge); sim_enemies.gd
## fails if the scene and this number ever disagree, so change them together.
const LEVEL1_GAP_BL: float = 4.5

## Player hurt: stun time (s), invulnerability (s), flicker half-period (s),
## knockback launch speed (px/s, x and upward y), and friction while stunned.
const PLAYER_HURT_TIME: float = 0.5
const PLAYER_INVULN_TIME: float = 1.0
const PLAYER_FLICKER_PERIOD: float = 0.08
const PLAYER_FLICKER_ALPHA: float = 0.3
const PLAYER_KNOCKBACK_X: float = 240.0
const PLAYER_KNOCKBACK_Y: float = 220.0
const PLAYER_HURT_FRICTION: float = 400.0

## Test dummy: walk speed (px/s), patrol half-width (BL), seconds between jumps,
## jump launch speed (negative = up; apex ~1.6 BL, ~0.67 s in the air).
const DUMMY_WALK_SPEED: float = 80.0
const DUMMY_PATROL_BL: float = 2.0
const DUMMY_JUMP_INTERVAL: float = 3.0
const DUMMY_JUMP_VELOCITY: float = -600.0

# ---------------------------------------------------------------------------
# Portrait (the only HUD) - cracks needed to advance each stage
# Stage 1 Defiant, 2 Rage, 3 Grief, 4 Exhaustion, 5 Stone (20 total = death)
# ---------------------------------------------------------------------------
const PORTRAIT_STAGE_COUNT: int = 5
const PORTRAIT_THRESHOLDS: Array[int] = [6, 5, 4, 3, 2]
## Crack costs by source.
const CRACKS_PETRIFY: int = 1
const CRACKS_HIT: int = 1        # hoplite, leaper, arrow
const CRACKS_PIT: int = 1
const CRACKS_REFLECT: int = 2    # own gaze reflected by a mirror
const CRACKS_PERSEUS: int = 2    # any Perseus attack
## Stage a player respawns at after death (0 cracks).
const DEATH_RESPAWN_STAGE: int = 2

# ---------------------------------------------------------------------------
# Portrait HUD (scenes/ui/portrait_hud.tscn): wordless, top-left
# ---------------------------------------------------------------------------
## Shield width = height (px) and gap from the screen corner (px).
const HUD_SIZE: float = 140.0
const HUD_MARGIN: float = 16.0
## Width (px) of the round frame's rim, and the frame's segments (more = rounder).
const HUD_FRAME_WIDTH: float = 6.0
const HUD_CIRCLE_SEGMENTS: int = 48
## Placeholder painting per stage, bright (Defiant) to gray (Stone).
const PORTRAIT_STAGE_COLORS: Array[Color] = [
	Color("F2D9A0"), Color("D9A066"), Color("B07A55"), Color("8A7468"), Color("6B6B6B"),
]
## Hairline cracks: line width (px), zigzag points per crack, how far the zigzag
## strays (fraction of the shield radius), how deep a crack reaches (fraction of
## the radius, from the rim inward), and how far it may lean off the straight line.
const CRACK_LINE_WIDTH: float = 2.0
## The wider dark edge drawn under each hairline (width px, alpha) so it reads on a bright painting.
const CRACK_EDGE_WIDTH: float = 4.0
const CRACK_EDGE_ALPHA: float = 0.55
const CRACK_POINTS: int = 5
const CRACK_JITTER: float = 0.12
const CRACK_REACH_MIN: float = 0.55
const CRACK_REACH_MAX: float = 0.95
## White flash over the shield on a stage change: peak alpha and fade time (s).
const HUD_FLASH_ALPHA: float = 0.9
const HUD_FLASH_TIME: float = 0.3
## Flinch on a hit: shake (px), scale dip and time (s).
const HUD_FLINCH_PX: float = 6.0
const HUD_FLINCH_SCALE: float = 0.9
const HUD_FLINCH_TIME: float = 0.22
## Snap on a petrify: scale pop and time (s).
const HUD_SNAP_SCALE: float = 1.12
const HUD_SNAP_TIME: float = 0.14
## Soften at a pool: warm glow peak alpha and fade time (s).
const HUD_SOFTEN_ALPHA: float = 0.55
const HUD_SOFTEN_TIME: float = 0.9
## Soften at a pool: the shield swells by this scale as the glow fades.
const HUD_SOFTEN_SCALE: float = 1.05
## Side (px) of the placeholder painting textures generated in code (round, solid color).
const HUD_TEXTURE_SIZE: int = 128
## Shield canvas layer, above the world. The death desaturate sits just below it.
const HUD_LAYER: int = 10

# ---------------------------------------------------------------------------
# Touch controls (scenes/ui/touch_controls.tscn): on-screen buttons for phones
# ---------------------------------------------------------------------------
# Positions are in game pixels on the 1280 x 720 screen (centre of each button).
# Left thumb: walk left / right, with a small kneel button above them.
const TOUCH_LEFT_POS: Vector2 = Vector2(130.0, 590.0)
const TOUCH_RIGHT_POS: Vector2 = Vector2(310.0, 590.0)
const TOUCH_DOWN_POS: Vector2 = Vector2(220.0, 440.0)
# Right thumb: gaze (hold), whip (tap), jump (hold for height).
const TOUCH_GAZE_POS: Vector2 = Vector2(1090.0, 420.0)
const TOUCH_WHIP_POS: Vector2 = Vector2(960.0, 600.0)
const TOUCH_JUMP_POS: Vector2 = Vector2(1150.0, 590.0)
# Button radii (px). About 9 mm or more on a phone held in landscape.
const TOUCH_MOVE_RADIUS: float = 76.0
const TOUCH_DOWN_RADIUS: float = 56.0
const TOUCH_ACTION_RADIUS: float = 80.0
## A finger counts as on a button up to this many radii from its centre (forgiving thumbs).
const TOUCH_HIT_SCALE: float = 1.25
## Disc and icon opacity while idle and while a finger is down (idle stays see-through).
const TOUCH_IDLE_DISC_ALPHA: float = 0.32
const TOUCH_PRESSED_DISC_ALPHA: float = 0.65
const TOUCH_ICON_ALPHA: float = 0.8
## Width (px) of the ring around each button and of the whip/arrow strokes.
const TOUCH_RING_WIDTH: float = 5.0
const TOUCH_ICON_STROKE: float = 7.0
## Pressed buttons shrink to this scale.
const TOUCH_PRESSED_SCALE: float = 0.92
## Segments for round shapes (more = rounder).
const TOUCH_CIRCLE_SEGMENTS: int = 40
## "Turn your phone sideways" overlay: size of the phone icon (px), stroke width (px) and
## seconds per half turn. Big on purpose: held upright the whole 1280 px width shrinks to
## about a third, so a small picture would be unreadable.
const TOUCH_ROTATE_PHONE_SIZE: Vector2 = Vector2(280.0, 460.0)
const TOUCH_ROTATE_STROKE: float = 16.0
const TOUCH_ROTATE_TURN_TIME: float = 1.1
## Touch layer, above the portrait HUD.
const TOUCH_LAYER: int = 20
## Double-tap sprint: tap a direction button, lift, and press the SAME direction again within
## this many seconds; she sprints (like holding Shift) until that finger lifts or slides off.
const TOUCH_DOUBLE_TAP_WINDOW: float = 0.25
## While sprinting, a gold second arrow (a "double chevron") shows beside the direction
## arrow. Its tip x, back x and half-height, as fractions of the button radius.
const TOUCH_SPRINT_MARK_TIP: float = 0.84
const TOUCH_SPRINT_MARK_BACK: float = 0.46
const TOUCH_SPRINT_MARK_HALF: float = 0.30

# ---------------------------------------------------------------------------
# Respawn props and death
# ---------------------------------------------------------------------------
## Distance (px) from Medusa's center to her feet; props sit on the floor, she is placed
## this far above them.
const PLAYER_FEET_OFFSET: float = 32.0
## Safe ledge marker: trigger size (BL) and the flag drawn on it (px).
const SAFE_LEDGE_WIDTH_BL: float = 1.0
const SAFE_LEDGE_HEIGHT_BL: float = 1.5
const SAFE_LEDGE_POLE_HEIGHT: float = 44.0
const SAFE_LEDGE_FLAG_SIZE: float = 14.0
## Pit kill zone default size (BL). A scene can override it per instance.
const PIT_WIDTH_BL: float = 6.0
const PIT_HEIGHT_BL: float = 6.0
## Mirror pool: width and trigger height (BL), basin depth (px), and seconds of standing
## still inside before it heals without a kneel.
const POOL_WIDTH_BL: float = 2.0
const POOL_HEIGHT_BL: float = 1.0
const POOL_DEPTH: float = 8.0
const POOL_STAND_TIME: float = 1.0
## Death: seconds to turn to marble, hold as a statue, and fade the screen back.
const DEATH_STONE_TIME: float = 1.0
const DEATH_HOLD_TIME: float = 0.5
const DEATH_FADE_BACK_TIME: float = 0.4

# ---------------------------------------------------------------------------
# Perseus (boss)
# ---------------------------------------------------------------------------
const PERSEUS_PHASES: int = 3
## Gaze hits needed per phase.
const PERSEUS_GAZE_HITS_PER_PHASE: int = 2
## Base shield-down window after each attack (s).
const SHIELD_WINDOW_BASE: float = 1.0
## Adapted window = clamp(median reaction + OFFSET, MIN, MAX).
const SHIELD_WINDOW_ADAPT_OFFSET: float = 0.15
const SHIELD_WINDOW_MIN: float = 0.45
const SHIELD_WINDOW_MAX: float = 1.0
## How many of the player's last gazes the mirror replays in the study beat.
const PERSEUS_ECHO_COUNT: int = 3
## Seconds of gaze on his open chest (shield down) that count as one gaze hit.
const PERSEUS_GAZE_HIT_TIME: float = 0.2
## Phase 1 (flight): hover height above the arena floor (px), seconds spent drifting to
## the attack side, drift speed (px/s), and dive speed (px/s).
const PERSEUS_HOVER_HEIGHT: float = 3.0 * BL
const PERSEUS_HOVER_TIME: float = 1.2
const PERSEUS_DRIFT_SPEED: float = 260.0
const PERSEUS_DIVE_SPEED: float = 700.0
## How far to the side of Medusa he lines up before an attack (px).
const PERSEUS_ATTACK_OFFSET: float = 3.5 * BL
## Gold telegraph before every attack (s), the same warning as the hoplite's glint.
const PERSEUS_TELEGRAPH_TIME: float = 0.45
## Phase 2 (grounded): walk speed (px/s), harpe reach (px) and how long the cut is live (s).
const PERSEUS_WALK_SPEED: float = 160.0
const PERSEUS_SLASH_REACH: float = 1.6 * BL
const PERSEUS_SLASH_TIME: float = 0.2
## Phase 3 (desperate): shield-bash charge speed (px/s) and the longest a charge lasts (s).
const PERSEUS_BASH_SPEED: float = 520.0
const PERSEUS_BASH_MAX_TIME: float = 2.5
## Study beat between phases 1 and 2: seconds each ghost echo of a past gaze shows,
## and the ghosts' opacity.
const PERSEUS_ECHO_TIME: float = 1.0
const PERSEUS_ECHO_ALPHA: float = 0.6
## Seconds of rest after a gaze hit (he reels, shield still down, no damage).
const PERSEUS_REEL_TIME: float = 0.6
## The whip in the boss fight (perseus.gd whip_hit):
## a lash while his gold glint shows (phases 2 and 3) parries: the attack is cancelled
## and his shield drops for the window x PERSEUS_PARRY_WINDOW_MULT.
const PERSEUS_PARRY_WINDOW_MULT: float = 1.6
## Phase 3: after each charge he braces behind the shield for this long (s); only a
## lash knocks it aside (a gaze just reflects). Not knocked in time = he charges again.
const PERSEUS_GUARD_TIME: float = 2.2
## The whip icon pulsing over him while he braces (px tall), like the gaze eye.
const PERSEUS_WHIP_ICON_SIZE: float = 24.0
## A lash that only glances off the shield flashes it gold for this long (s).
const PERSEUS_GLANCE_FLASH_S: float = 0.25
## Defeat: seconds the stone takes to cover him before he becomes a statue.
const PERSEUS_DEFEAT_STONE_TIME: float = 1.5
## His shield (Visual/Shield): held in front, or dropped to his side during the window.
const PERSEUS_SHIELD_UP_POS: Vector2 = Vector2(16.0, -6.0)
const PERSEUS_SHIELD_DOWN_POS: Vector2 = Vector2(6.0, 22.0)
const PERSEUS_SHIELD_DOWN_DEG: float = 70.0
## Size of the gold telegraph diamond and where it shows (on the harpe / shield).
const PERSEUS_GLINT_SIZE: float = 7.0
## Readability: the gaze-now eye over his head (px tall, px above his body), the pips
## (radius px, distance from the screen top), stone left per lost phase (0..1), the
## study dimming (alpha), and the shakes / hit-stops for hits and phase changes.
const PERSEUS_EYE_SIZE: float = 26.0
const PERSEUS_EYE_RISE: float = 40.0
const PERSEUS_PIP_RADIUS: float = 7.0
const PERSEUS_PIPS_Y: float = 44.0
const PERSEUS_PHASE_STONE: float = 0.3
const PERSEUS_STUDY_DIM: float = 0.45
const HITSTOP_PERSEUS: float = 0.14
const SHAKE_PERSEUS_PHASE_PX: float = 10.0
const SHAKE_PERSEUS_PHASE_TIME: float = 0.4
const PERSEUS_GLINT_OFFSET: Vector2 = Vector2(24.0, -30.0)
## Screen shake when a gaze hit lands.
const SHAKE_PERSEUS_HIT_PX: float = 8.0
const SHAKE_PERSEUS_HIT_TIME: float = 0.25

# ---------------------------------------------------------------------------
# AI Worker (Cloudflare Worker that talks to the LLM / image models)
# ---------------------------------------------------------------------------
## Base URL of the deployed Worker. Replace CHANGE-ME with the real workers.dev subdomain
## after `wrangler deploy`. No keys live here: the Worker holds the secrets.
const WORKER_URL: String = "https://medusas-price-worker.medusas-price-worker-dark-roots-creations.workers.dev"
## Seconds before a /test request gives up (image models can be slow on a cold start).
const AI_TEST_TIMEOUT_S: float = 60.0
## Debug-build F10 test image: longest side (px) and where its center sits in the
## 1280x720 screen (upper middle; drawn on its own CanvasLayer, so the follow camera
## does not move it).
const AI_DEBUG_SPRITE_SIZE: float = 512.0
const AI_DEBUG_SPRITE_POS: Vector2 = Vector2(640.0, 300.0)
## Origin header sent on desktop (non-web) runs. Browsers set Origin themselves; the
## Worker only answers allowlisted origins, and it allows http://localhost on any port.
const AI_DESKTOP_ORIGIN: String = "http://localhost"

# ---------------------------------------------------------------------------
# Level kit (scenes/levels/level_base.tscn) and level flow (autoload GameFlow)
# ---------------------------------------------------------------------------
## Side of one terrain tile in px (2 tiles = 1 BL). The placeholder tileset uses it.
const TILE_SIZE: int = 32
## Tint multiplied over the whole level (CanvasModulate) for each time of day.
## Noon: warm and bright. Dusk: orange-violet. Torchlight: dark (torches add light back).
## Storm: desaturated blue.
const LIGHT_NOON: Color = Color(1.0, 0.95, 0.84)
const LIGHT_DUSK: Color = Color(0.95, 0.62, 0.68)
const LIGHT_TORCH: Color = Color(0.16, 0.13, 0.18)
const LIGHT_STORM: Color = Color(0.48, 0.55, 0.68)
## Storm lightning: seconds between flashes (random in this range), the flash color,
## and how long the flash holds and then fades back. Two flashes in a row feel like thunder.
const LIGHTNING_MIN_S: float = 6.0
const LIGHTNING_MAX_S: float = 12.0
const LIGHTNING_COLOR: Color = Color(0.92, 0.96, 1.0)
const LIGHTNING_HOLD_S: float = 0.06
const LIGHTNING_FADE_S: float = 0.25
const LIGHTNING_DOUBLE_GAP_S: float = 0.12
## Torch (scenes/props/torch.tscn): light radius (px), strength, flicker amount (fraction
## of strength) and speed (changes per second).
const TORCH_RADIUS: float = 220.0
const TORCH_ENERGY: float = 1.3
const TORCH_FLICKER: float = 0.2
const TORCH_FLICKER_RATE: float = 12.0
## Level exit door: width and height in BL.
const LEVEL_EXIT_WIDTH_BL: float = 1.0
const LEVEL_EXIT_HEIGHT_BL: float = 2.0
## Tint of an exit door that is shut (the cave's pressure-plate door while no statue
## holds the plate down): the door still shows where to go, but dark.
const EXIT_LOCKED_TINT: Color = Color(0.35, 0.3, 0.28, 1.0)

# --- Key hints (scripts/key_hint.gd): wordless control hints in level 1 ---
## Height (and width, for a letter key) of a key-cap, px.
const KEY_HINT_CAP_SIZE: float = 18.0
## Width of the wide caps (Space, Shift), px.
const KEY_HINT_WIDE_CAP_W: float = 44.0
## Space between caps, and between the caps and the icon, px.
const KEY_HINT_GAP: float = 3.0
## Height the action icon is drawn at, px.
const KEY_HINT_ICON_H: float = 18.0
## Letter size on a cap, and the cap's border width and corner radius, px.
const KEY_HINT_FONT_SIZE: int = 11
const KEY_HINT_BORDER: int = 1
const KEY_HINT_CORNER: int = 3
## Cap fill: bodies-in-motion black, slightly see-through.
const KEY_HINT_CAP_COLOR: Color = Color(0.102, 0.078, 0.063, 0.85)
## Seconds the hint takes to fade after the action is first used.
const KEY_HINT_FADE_S: float = 0.6
## Draw order: above the terrain and characters, below the HUD layer.
const KEY_HINT_Z: int = 30
## Icon textures by name (made by tools/cut_ui_icons.py from art/raw/P18).
const KEY_HINT_ICONS: Dictionary = {
	"left": "res://art/sprites/ui/icon_left.png",
	"right": "res://art/sprites/ui/icon_right.png",
	"down": "res://art/sprites/ui/icon_down.png",
	"jump": "res://art/sprites/ui/icon_jump.png",
	"whip": "res://art/sprites/ui/icon_whip.png",
	"gaze": "res://art/sprites/ui/icon_gaze.png",
}
# --- Pause menu (scripts/pause_menu.gd) ---
## Corner pause button: size and distance from the screen edge (px).
const PAUSE_CORNER_SIZE: float = 44.0
const PAUSE_CORNER_MARGIN: float = 14.0
## How dark the world gets behind the menu (0 to 1).
const PAUSE_DIM: float = 0.72
## The round buttons: size (px) and height on screen (fraction of screen height).
const PAUSE_BUTTON_SIZE: float = 120.0
const PAUSE_BUTTONS_Y: float = 0.28
## The controls legend: height on screen, spacing (fraction of screen width), scale.
const PAUSE_LEGEND_Y: float = 0.72
const PAUSE_LEGEND_STEP: float = 0.12
const PAUSE_LEGEND_SCALE: float = 2.25
## Fade to black between levels: seconds out and seconds back in.
# --- Museum ending (scripts/museum.gd) ---
## At most this many of the run's statues are shown (the first ones petrified).
const MUSEUM_MAX_STATUES: int = 14
## Gap between plinths (px), statue display scale, Perseus's extra size.
const MUSEUM_SPACING: float = 170.0
const MUSEUM_STATUE_SCALE: float = 2.6
const MUSEUM_PERSEUS_SCALE: float = 1.3
## Plinth size (px), floor line, upper wall band and portrait height and size (px).
const MUSEUM_PLINTH_SIZE: Vector2 = Vector2(110.0, 70.0)
const MUSEUM_FLOOR_Y: float = 600.0
const MUSEUM_BAND_Y: float = 40.0
const MUSEUM_PORTRAIT_Y: float = 175.0
const MUSEUM_PORTRAIT_SIZE: float = 190.0
const MUSEUM_WALL_COLOR: Color = Color("E2A27A")
## Seconds for one slow drift along the gallery, and before input counts.
const MUSEUM_PAN_S: float = 9.0
const MUSEUM_INPUT_DELAY_S: float = 2.0
const FADE_OUT_S: float = 0.35
const FADE_IN_S: float = 0.35
## Victim statue (scenes/props/victim_statue.tscn): body size (px) when standing, and
## the shorter body height (px) of the crouched pose. The feet stay where a standing
## enemy's feet would be, so it sits on the floor like any statue.
const VICTIM_BODY_SIZE: Vector2 = Vector2(40.0, 64.0)
const VICTIM_CROUCH_HEIGHT: float = 40.0

# ---------------------------------------------------------------------------
# Sprite art (made by tools/build_sprites.py from art/processed/)
# ---------------------------------------------------------------------------
## One entry per character, read by SpriteKit.attach():
##   frames    = the SpriteFrames resource
##   offset    = AnimatedSprite2D offset that puts the drawn feet on the node origin
##               (printed by build_sprites.py; re-copy it if the art is rebuilt)
##   figure_h  = height in px of the first frame's drawn figure (from the same tool)
##   height    = how tall that figure should be in the game (px) - the hitbox height,
##               so scale = height / figure_h
##   feet_y    = where the feet go below the body's center (half the hitbox height)
const SPRITE_ART: Dictionary = {
	&"medusa": {"frames": "res://art/sprites/medusa/medusa_frames.tres",
		"offset": Vector2(2.5, -64.0), "figure_h": 115.0, "height": 64.0, "feet_y": 32.0},
	&"hoplite": {"frames": "res://art/sprites/hoplite/hoplite_frames.tres",
		"offset": Vector2(24.0, -109.0), "figure_h": 209.0, "height": 64.0, "feet_y": 32.0},
	&"eye_shading": {"frames": "res://art/sprites/eye_shading/eye_shading_frames.tres",
		"offset": Vector2(23.0, -108.5), "figure_h": 209.0, "height": 64.0, "feet_y": 32.0},
	&"leaper": {"frames": "res://art/sprites/leaper/leaper_frames.tres",
		"offset": Vector2(63.5, -104.0), "figure_h": 203.0, "height": 40.0, "feet_y": 20.0},
	&"archer": {"frames": "res://art/sprites/archer/archer_frames.tres",
		"offset": Vector2(-6.0, -107.0), "figure_h": 207.0, "height": 64.0, "feet_y": 32.0},
	&"mirror_bearer": {"frames": "res://art/sprites/mirror_bearer/mirror_bearer_frames.tres",
		"offset": Vector2(-6.5, -105.5), "figure_h": 208.0, "height": 64.0, "feet_y": 32.0},
	&"perseus": {"frames": "res://art/sprites/perseus/perseus_frames.tres",
		"offset": Vector2(-16.0, -96.0), "figure_h": 192.0, "height": 80.0, "feet_y": 40.0},
}
## Animation speeds in frames per second, per character. Only animations with more
## than one frame need an entry; single-frame poses just hold.
const ANIM_FPS: Dictionary = {
	&"medusa": {&"idle": 2.0, &"run": 10.0},
	&"hoplite": {&"walk": 6.0},
	&"eye_shading": {&"walk": 6.0},
	&"archer": {&"idle": 2.0},
	&"mirror_bearer": {&"walk": 6.0},
	&"perseus": {&"hover": 6.0},
}
## Seconds the leaper shows its takeoff pose before the stretched mid-leap pose.
const LEAPER_TAKEOFF_POSE_S: float = 0.12
## Seconds the archer shows the open-handed release pose after a shot.
const ARCHER_RELEASE_POSE_S: float = 0.2
## Walk animation speed multiplier while an enemy chases (it moves faster, so do its legs).
const ANIM_CHASE_SPEED_SCALE: float = 1.6
## Detachable weapon sprites (Sprite2D): how long each is in the game (px, along its
## longest side) and where its middle sits inside its holder node. Sizes match the old
## placeholder shapes, so the hitboxes and the code that moves them still line up.
const WEAPON_ART: Dictionary = {
	&"spear": {"texture": "res://art/sprites/weapons/spear.png", "length": 66.0, "center": Vector2(19.0, 0.0)},
	&"arrow": {"texture": "res://art/sprites/weapons/arrow.png", "length": 29.0, "center": Vector2(0.5, 0.0)},
	&"mirror": {"texture": "res://art/sprites/weapons/mirror.png", "length": 36.0, "center": Vector2(0.0, 4.0)},
	&"shield": {"texture": "res://art/sprites/weapons/shield.png", "length": 42.0},
}
## Whip snake sprites (3 variants, drawn tail-left, head-right) and their thickness in
## the game (px). Each lash line becomes one of these, stretched to the line's length.
const WHIP_SNAKE_TEXTURES: Array[String] = [
	"res://art/sprites/whip/snake_0.png",
	"res://art/sprites/whip/snake_1.png",
	"res://art/sprites/whip/snake_2.png",
]
const WHIP_SNAKE_THICKNESS: float = 9.0
## Portrait paintings, stage 1 (Defiant) to 5 (Stone).
const PORTRAIT_TEXTURES: Array[String] = [
	"res://art/portrait/stage_1.png",
	"res://art/portrait/stage_2.png",
	"res://art/portrait/stage_3.png",
	"res://art/portrait/stage_4.png",
	"res://art/portrait/stage_5.png",
]

# ---------------------------------------------------------------------------
# Shaders (petrify, marble, death veil)
# ---------------------------------------------------------------------------
## Noise layers in the petrify and marble shaders. 2 looks best; drop to 1 if the web
## build cannot hold 60 fps in the busiest room.
const SHADER_NOISE_OCTAVES: int = 2
## Stone colors that are not in the 4-color code: the grey of carved lines and veins,
## the slightly darker edge of a statue, and the bright front of the spreading stone.
const COLOR_MARBLE_VEIN: Color = Color(0.55, 0.52, 0.49)
const COLOR_MARBLE_RIM: Color = Color(0.72, 0.69, 0.65)
const COLOR_PETRIFY_EDGE: Color = Color(1.0, 1.0, 1.0)
## Petrify spread: width of the bright front (UV units), noise blob size and bend.
const PETRIFY_EDGE_WIDTH: float = 0.05
const PETRIFY_NOISE_SCALE: float = 5.0
const PETRIFY_NOISE_AMOUNT: float = 0.3
## Marble: veining size and strength, rim width (texture px; 0 = off, saves 4 reads),
## crack cell size and crack line width.
const MARBLE_VEIN_SCALE: float = 7.0
const MARBLE_VEIN_STRENGTH: float = 0.12
const MARBLE_RIM_PX: float = 3.0
const MARBLE_CRACK_SCALE: float = 5.0
## The portrait's craquelure and wear shader (replaces the overlay crack lines).
const PORTRAIT_CRACK_SHADER: String = "res://shaders/portrait_crack.gdshader"
const MARBLE_CRACK_WIDTH: float = 0.03
## Where Medusa's eyes are in her frame (UV): her own death starts there.
const MEDUSA_EYE_UV: Vector2 = Vector2(0.62, 0.15)
## Death veil: how far the gray world is pushed toward marble white at full strength.
const DEATH_VEIL_MARBLE_MIX: float = 0.45

# ---------------------------------------------------------------------------
# World art (backgrounds, terrain, meander bands, cards)
# ---------------------------------------------------------------------------
## Per level art, indexed by LevelBase.Lighting (NOON = level 1 temple, DUSK = level 2
## cliffs, TORCHLIGHT = level 3 cave, STORM = the boss at the cave mouth).
const LEVEL_BACKGROUNDS: Array[String] = [
	"res://art/bg/level_1_bg.png",
	"res://art/bg/level_2_bg.png",
	"res://art/bg/level_3_bg.png",
	"res://art/bg/level_4_bg.png",
]
## Seamless painted terrain surfaces (texkit `tile --method graphcut --size 512` on the
## P12 paintings with their Greek-key band cut off), by Lighting. The cave reuses the
## cliff rock (darkened by its tint): texkit's cave result showed seams by eye.
const LEVEL_SURFACE: Array[String] = [
	"res://art/tiles/surface_temple.png",
	"res://art/tiles/surface_rock.png",
	"res://art/tiles/surface_rock.png",
	"res://art/tiles/surface_rock.png",
]
## Multiplies each level's surface colour (1 = as painted).
const LEVEL_SURFACE_TINT: Array[Color] = [
	Color(1.0, 1.0, 1.0), Color(1.0, 0.95, 0.92), Color(0.62, 0.55, 0.52), Color(0.8, 0.76, 0.76),
]
## World px covered by one copy of the surface painting (a temple brick ends up
## about 1.3 BL wide, close to Medusa's size).
const TERRAIN_SURFACE_PX: float = 64.0
## Marker atlas for terrain.gdshader: 16 x 8 blank 32 px tiles. Column = exposed sides
## (bits: 1 top, 2 left, 4 right, 8 bottom); row = depth below the surface (0-7).
const TERRAIN_EDGE_ATLAS: String = "res://art/tiles/terrain_edges.png"
## Black outline on exposed terrain sides, and the Greek-key lip on exposed tops, px.
const TERRAIN_EDGE_PX: float = 3.0
## Terrain at this row (y = row x 32) or lower counts as ground and is extended down to
## TERRAIN_BOTTOM_ROW, so the ground is one solid mass below the view's bottom edge.
const TERRAIN_GROUND_ROW: int = 19
# --- Screen-space parallax background (level_base._build_background) ---
## The CanvasLayer it sits on (negative = behind the world).
const BG_CANVAS_LAYER: int = -10
## How fast the painting drifts with the camera (fraction of camera motion).
const BG_PAINTING_SCROLL: float = 0.1
## Fractions of the painting's height trimmed off its own top and bottom bands.
const BG_TRIM_TOP: float = 0.06
const BG_TRIM_BOTTOM: float = 0.14
## The silhouette bands, far to near: scroll speed, how tall (fraction of the screen),
## and how far toward the deep terrain colour they are darkened.
const BG_BAND_SCROLLS: Array[float] = [0.3, 0.55]
const BG_BAND_HEIGHTS: Array[float] = [0.42, 0.3]
const BG_BAND_DARKEN: Array[float] = [0.35, 0.6]
const TERRAIN_BOTTOM_ROW: int = 30
## Depth darkening by Lighting: deep rock fades toward this colour over TERRAIN_DEEP_PX
## px below the surface, by at most TERRAIN_DEEP_MAX.
const TERRAIN_DEEP_COLOR: Array[Color] = [
	Color("2A120A"), Color("240E08"), Color("120C09"), Color("120C09"),
]
const TERRAIN_DEEP_PX: float = 160.0
const TERRAIN_DEEP_MAX: float = 0.85
# --- Platformer kit (scripts/terrain_piece.gd and the props built on it) ---
## Crumbling ledge: seconds from Medusa landing to the drop, seconds until it is back,
## how far it sinks while fading (px), and its pale cracked-marble tint.
const CRUMBLE_DELAY: float = 0.5
const CRUMBLE_RESPAWN: float = 3.0
const CRUMBLE_DROP_PX: float = 24.0
const CRUMBLE_TINT: Color = Color(1.25, 1.18, 1.1, 1.0)
## Column platform: thickness of its one-way top (px), the column sprite and its width.
const COLUMN_ONE_WAY_THICKNESS: float = 8.0
const COLUMN_TEXTURE: String = "res://art/sprites/props/column.png"
const COLUMN_WIDTH: float = 56.0
## Spear trap: seconds hidden, glinting (the warning) and up; how tall the spears rise
## (px) and how fast they move (fraction of full height per second).
## Spike trap sound: only traps closer to Medusa than this (px) are heard, and the
## clack plays a little lower (pitch) so it is less shrill.
const SPEAR_SFX_RANGE: float = 9.0 * BL
const SPEAR_SFX_PITCH: float = 0.8
const SPEAR_DOWN_S: float = 1.6
const SPEAR_WARN_S: float = 0.45
const SPEAR_UP_S: float = 0.9
const SPEAR_HEIGHT: float = 40.0
const SPEAR_THRUST_SPEED: float = 10.0
## Gate: seconds for the bars to slide open or shut.
const GATE_MOVE_S: float = 0.4
## Shard pickup radius (px, also its drawn size).
const SHARD_RADIUS: float = 10.0
## Picking one up: a gold sparkle (px) flies to the portrait in SHARD_FLY_S seconds,
## then the portrait swells to this scale and back.
const SHARD_FLY_SIZE: float = 9.0
const SHARD_FLY_S: float = 0.55
const SHARD_PULSE_SCALE: float = 1.1
## Camera zoom (2 = twice as close). 1.5 makes Medusa about 96 screen px tall, about
## an eighth of the screen, like the reference platformers.
const CAMERA_ZOOM: float = 2.25
const TERRAIN_LIP_PX: float = 8.0
## Background haze (shaders/haze.gdshader) by Lighting: the colour the painting fades
## toward, and how far (0 = none). Light terracotta makes the black figures pop by day;
## dark clay lets the cave and storm paintings sink into the dark.
const LEVEL_HAZE_COLOR: Array[Color] = [
	Color("E3A27F"), Color("D98A6A"), Color("5A2A18"), Color("4A2A22"),
]
const LEVEL_HAZE_AMOUNT: Array[float] = [0.45, 0.4, 0.35, 0.35]
const LEVEL_TERRAIN: Array[String] = [
	"res://art/tiles/terrain_temple.png",
	"res://art/tiles/terrain_cliffs.png",
	"res://art/tiles/terrain_cave.png",
	"res://art/tiles/terrain_temple.png",
]
## How much the background moves with the camera (0 = glued to the screen, 1 = to the world).
const PARALLAX_BG_SCROLL: float = 0.3
## How many extra copies of the background to draw on each side so wide screens never
## see its edge.
const PARALLAX_REPEAT_TIMES: int = 2
## Draw order: the background behind everything, the meander bands in front of the world.
const PARALLAX_BG_Z: int = -20
const MEANDER_Z: int = 40
## The Greek-key band along the top and bottom of the screen: its tile, its height on
## screen (px) and how fast it slides sideways with the camera.
const MEANDER_TEXTURE: String = "res://art/tiles/meander.png"
const MEANDER_HEIGHT: float = 18.0
const MEANDER_SCROLL: float = 1.0
## Title and ending cards and the logo (the only allowed text in the game).
const CARD_TITLE: String = "res://art/cards/title.png"
const CARD_END: String = "res://art/cards/end.png"
const CARD_LOGO: String = "res://art/cards/logo.png"
## Where the logo sits on the title card (center, px) and its width on screen (px).
const CARD_LOGO_CENTER: Vector2 = Vector2(290.0, 340.0)
const CARD_LOGO_WIDTH: float = 520.0
## Victim statue art, one per VictimStatue.Pose (standing, arms raised, crouched,
## fleeing). Already drawn as white marble, so no shader is needed. All four share the
## standing figure's scale, which makes the standing one VICTIM_BODY_SIZE.y tall.
const VICTIM_TEXTURES: Array[String] = [
	"res://art/sprites/statues/victim_0.png",
	"res://art/sprites/statues/victim_1.png",
	"res://art/sprites/statues/victim_2.png",
	"res://art/sprites/statues/victim_3.png",
]
## Level prop art (SpriteKit.prop): the picture, its height in the game (px), and
## which point of the picture (fractions of its width and height) sits on the prop's
## origin. Mirror pool: the basin's bottom middle sits POOL_DEPTH below the floor
## line; torch: the cup sits under the flame; exit: the doorway stands on the floor.
const PROP_ART: Dictionary = {
	&"pool": {"texture": "res://art/sprites/props/pool.png", "height": 30.0,
		"pivot": Vector2(0.5, 0.75)},
	&"torch_bracket": {"texture": "res://art/sprites/props/torch_bracket.png", "height": 28.0,
		"pivot": Vector2(0.62, 0.05)},
	&"exit_door": {"texture": "res://art/sprites/props/exit_door.png", "height": 150.0,
		"pivot": Vector2(0.5, 1.0)},
}
## How much a spent mirror pool darkens (0 = not at all, 1 = black).
const POOL_SPENT_DARKEN: float = 0.45

# ---------------------------------------------------------------------------
# Run vase (scenes/flow/vase.tscn)
# ---------------------------------------------------------------------------
## The painted fallback amphora, shown at once and kept if the AI one never arrives.
const VASE_FALLBACK: String = "res://art/cards/vase_fallback.png"
## How tall the vase is drawn on the 1280 x 720 screen (px), and where its middle sits.
const VASE_HEIGHT: float = 640.0
const VASE_CENTER: Vector2 = Vector2(640.0, 360.0)
## Seconds to wait for the Worker (an LLM call plus an image) before giving up silently.
const VASE_TIMEOUT_S: float = 60.0
## Seconds the AI vase takes to fade in over the fallback.
const VASE_FADE_S: float = 1.0
## Seconds before a key press may leave the vase (so the boss's last press cannot skip it).
const VASE_INPUT_DELAY_S: float = 1.0
