## portrait_state.gd (autoload "PortraitState")
## Purpose: Medusa's health. The portrait has Balance.PORTRAIT_STAGE_COUNT stages; each
## fills after Balance.PORTRAIT_THRESHOLDS[stage - 1] cracks and then the next stage
## begins (overflow carries over). Filling the last stage is death. Owns the numbers
## only: the HUD draws them and the Player reacts to `died`.
## Petrifying costs a crack here (from Events.petrified); hits, pits and the rest call
## add_cracks() themselves.
extends Node

## The stage advanced, was healed down, or was reset (new stage number).
signal stage_changed(stage: int)
## The crack count within the current stage changed (new count).
signal cracked(total_in_stage: int)
## A mirror pool healed her (the stage she is at now).
signal healed(stage: int)
## The last stage filled. Emitted once; cracks are ignored until reset_after_death().
signal died

## 1 (Defiant) to Balance.PORTRAIT_STAGE_COUNT (Stone).
var stage: int = 1
var cracks_in_stage: int = 0
## True from `died` until reset_after_death() / reset_run().
var is_dead: bool = false
## What dealt the latest cracks (for the death entry in the ledger).
var last_source: StringName = &""


func _ready() -> void:
	Events.petrified.connect(_on_petrified)


## Cracks needed to clear a stage.
func threshold(for_stage: int) -> int:
	return Balance.PORTRAIT_THRESHOLDS[for_stage - 1]


## Every crack taken since the last reset or heal, across stages.
func total_cracks() -> int:
	var total: int = cracks_in_stage
	for s in range(1, stage):
		total += threshold(s)
	return total


## Take n cracks from `source` (&"petrify", &"hoplite", &"pit", ...). Walks forward
## through the stages, carrying any overflow, and dies at the end of the last one.
func add_cracks(n: int, source: StringName) -> void:
	if n <= 0 or is_dead:
		return
	var stage_before: int = stage
	var dies: bool = false
	var left: int = n
	last_source = source
	while left > 0:
		var room: int = threshold(stage) - cracks_in_stage
		if left < room:
			cracks_in_stage += left
			left = 0
		elif stage >= Balance.PORTRAIT_STAGE_COUNT:
			cracks_in_stage = threshold(stage)
			dies = true
			left = 0
		else:
			left -= room
			stage += 1
			cracks_in_stage = 0
	RunLedger.log_event("crack", {
		"cracks": n,
		"source": String(source),
		"stage": stage,
		"in_stage": cracks_in_stage,
		"level": RunLedger.level,
	})
	if stage != stage_before:
		stage_changed.emit(stage)
	cracked.emit(cracks_in_stage)
	if dies:
		is_dead = true
		died.emit()


## A mirror pool: clear this stage's cracks and drop one stage (stage 1 only clears).
func heal_at_pool() -> void:
	if is_dead:
		return
	var stage_before: int = stage
	stage = maxi(stage - 1, 1)
	cracks_in_stage = 0
	RunLedger.log_event("pool", {"stage": stage, "level": RunLedger.level})
	if stage != stage_before:
		stage_changed.emit(stage)
	cracked.emit(0)
	healed.emit(stage)


## A shard: close up to `n` cracks of the current stage (never below 0, never a stage
## back; that is what pools are for). The HUD redraws from `cracked`.
func mend(n: int) -> void:
	if is_dead or n <= 0 or cracks_in_stage == 0:
		return
	cracks_in_stage = maxi(cracks_in_stage - n, 0)
	RunLedger.log_event("mend", {"stage": stage, "in_stage": cracks_in_stage, "level": RunLedger.level})
	cracked.emit(cracks_in_stage)


## Back on her feet after dying: Balance.DEATH_RESPAWN_STAGE with 0 cracks.
func reset_after_death() -> void:
	_set_fresh(Balance.DEATH_RESPAWN_STAGE)


## A brand new run: stage 1, 0 cracks.
func reset_run() -> void:
	_set_fresh(1)


func _set_fresh(new_stage: int) -> void:
	is_dead = false
	var stage_before: int = stage
	stage = new_stage
	cracks_in_stage = 0
	if stage != stage_before:
		stage_changed.emit(stage)
	cracked.emit(0)


func _on_petrified(_enemy_type: StringName, _pose_frame: int, _flip: bool, _position: Vector2) -> void:
	add_cracks(Balance.CRACKS_PETRIFY, &"petrify")
