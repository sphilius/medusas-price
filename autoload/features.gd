## features.gd (autoload "Features")
## Purpose: one switch per AI feature. Every AI feature must check its flag here
## and must have a non-AI fallback, so the game is always playable if one is off.
## Flip a flag to false to disable a feature everywhere at once.
extends Node

## Run vase: LLM + image model turn the run into a frieze on an amphora (via the Worker).
const VASE_AI: bool = true
## Statue gallery: img2img marble renders of the soldiers you froze (via the Worker).
const GALLERY_AI: bool = true
## Perseus adaptation: boss timing adapts to the player's measured reaction time (local only).
const PERSEUS_ADAPT: bool = true
## Webcam stare mode: MediaPipe in the HTML shell, runs only in the browser, opt-in from
## the pause menu's camera button. Fallback: the gaze key / gaze button, always.
const WEBCAM: bool = true
