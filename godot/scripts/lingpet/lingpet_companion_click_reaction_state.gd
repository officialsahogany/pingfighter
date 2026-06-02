extends RefCounted

# One-shot click-reaction Live2D playback for the in-battle companion.
#
# Unlike the acquisition cut-in (which pauses battle via the modal gate), this
# reaction does NOT pause gameplay -- the companion keeps patrolling underneath
# while the reaction sheet plays as a large popup above it, then fades out.
#
# The reaction sheet is the 98-frame pingpong click-reaction asset
# (click_reaction_anim, 14 cols x 7 rows, 1024px cells), the same sheet family
# as the stage-clear-result click reaction. Frame/alpha math mirrors
# StageClearResultClickReactionState but is kept local so lingpet has no
# dependency on the ui/ stage-clear modules and the smoke stays self-contained.

const COLS := 14
const ROWS := 7
const FRAME_COUNT := 98
const FRAME_INTERVAL := 0.036
const TRANSITION_IN := 0.16
const RETURN_HOLD := 0.16
const RETURN_FADE := 0.26
# One full forward+reverse pingpong play, then a short hold and fade-out.
const REACTION_DURATION := float(FRAME_COUNT) * FRAME_INTERVAL
const TOTAL_DURATION := REACTION_DURATION + RETURN_HOLD + RETURN_FADE

var active := false
var timer := 0.0


func start() -> void:
	active = true
	timer = 0.0


func reset() -> void:
	active = false
	timer = 0.0


func advance(delta: float) -> void:
	if not active:
		return
	timer += maxf(0.0, delta)
	if timer >= TOTAL_DURATION:
		reset()


func is_active() -> bool:
	return active


func get_frame() -> int:
	if timer >= REACTION_DURATION:
		return FRAME_COUNT - 1
	return clampi(int(floor(timer / maxf(0.001, FRAME_INTERVAL))), 0, FRAME_COUNT - 1)


func get_alpha() -> float:
	if not active:
		return 0.0
	if timer <= TRANSITION_IN:
		return _smooth01(timer / maxf(0.001, TRANSITION_IN))
	if timer >= REACTION_DURATION:
		var blend_elapsed: float = timer - REACTION_DURATION
		if blend_elapsed < RETURN_HOLD:
			return 1.0
		var fade_progress: float = clampf((blend_elapsed - RETURN_HOLD) / maxf(0.001, RETURN_FADE), 0.0, 1.0)
		return _smooth01(1.0 - fade_progress)
	return 1.0


static func _smooth01(value: float) -> float:
	var t: float = clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
