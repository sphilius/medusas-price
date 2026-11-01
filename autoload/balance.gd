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

# ---------------------------------------------------------------------------
# Player movement
# ---------------------------------------------------------------------------
## Top running speed (px/s).
const PLAYER_RUN_SPEED: float = 300.0
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
## Portrait cracks paid per petrified enemy.
const GAZE_CRACK_COST: int = 1
## Where the cone starts, relative to Medusa's center (her eyes).
const GAZE_EYE_OFFSET: Vector2 = Vector2(0.0, -20.0)
## Alpha of the gold cone polygon.
const GAZE_CONE_ALPHA: float = 0.35
## Points along the cone's far arc (more = rounder).
const GAZE_ARC_SEGMENTS: int = 8
## Line-of-sight ray mask: anything on these layers blocks the gaze.
const GAZE_LOS_MASK: int = PHYS_WORLD | PHYS_STATUES

# ---------------------------------------------------------------------------
# Game feel
# ---------------------------------------------------------------------------
## Hit-stop on petrify: real seconds, and the time scale held during it.
const HITSTOP_DURATION: float = 0.08
const HITSTOP_TIME_SCALE: float = 0.05
## Camera shake on petrify: max offset (px) and decay time (s).
const SHAKE_PETRIFY_PX: float = 6.0
const SHAKE_PETRIFY_TIME: float = 0.2
## Sample rate (Hz) of every placeholder sound generated in code.
const SFX_MIX_RATE: int = 22050
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
const GRIND_SFX_VOLUME_DB: float = -10.0
## Placeholder thud, generated in code: length (s), frequency (Hz), decay rate,
## volume (dB), and pitch multiplier for a slide stopping (a landing uses 1.0).
const THUD_SFX_LENGTH: float = 0.18
const THUD_SFX_HZ: float = 55.0
const THUD_SFX_DECAY: float = 25.0
const THUD_SFX_VOLUME_DB: float = -3.0
const THUD_SFX_STOP_PITCH: float = 1.4

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
## Player below this y (px) fell into a pit (graybox: back to the start).
const PLAYER_PIT_Y: float = 1400.0
## How far below the feet / ahead of the body (px) the ledge check looks.
const ENEMY_LEDGE_PROBE_DOWN: float = 24.0
const ENEMY_LEDGE_PROBE_AHEAD: float = 8.0
## The ledge ray starts this far (px) above the feet, so it never begins inside the floor.
const ENEMY_LEDGE_PROBE_INSET: float = 4.0
## Half the standing enemy body width / height (px), the ledge probe's origin.
const ENEMY_HALF_WIDTH: float = 20.0
const ENEMY_HALF_HEIGHT: float = 32.0
## Size (px) of the hoplite's gold wind-up glint.
const HOPLITE_GLINT_SIZE: float = 10.0
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
