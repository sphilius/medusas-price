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

# ---------------------------------------------------------------------------
# Enemies
# ---------------------------------------------------------------------------
## Hoplite spear reach (BL) and thrust wind-up (s, shows a gold glint).
const HOPLITE_SPEAR_REACH_BL: float = 1.5
const HOPLITE_WINDUP: float = 0.35

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
