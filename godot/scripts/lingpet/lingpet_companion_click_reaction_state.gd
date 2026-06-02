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
const VIEW_HEIGHT := 300.0
const CENTER_OFFSET_Y := -70.0
const CLICK_ZONE_HALF_WIDTH := 70.0
const CLICK_ZONE_HALF_HEIGHT := 60.0
const PREWARM_VISUAL_KEYS := ["click_reaction_anim"]

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


func can_start_at(playfield_pos: Vector2, companion_pos: Vector2) -> bool:
	if companion_pos == Vector2.ZERO:
		return false
	return (
		absf(playfield_pos.x - companion_pos.x) <= CLICK_ZONE_HALF_WIDTH
		and absf(playfield_pos.y - companion_pos.y) <= CLICK_ZONE_HALF_HEIGHT
	)


func draw(canvas: CanvasItem, center: Vector2, texture: Texture2D) -> void:
	if canvas == null or texture == null or texture.get_width() <= 1 or texture.get_height() <= 1:
		return
	var alpha: float = get_alpha()
	if alpha <= 0.0:
		return
	var cell_w: float = float(texture.get_width()) / float(COLS)
	var cell_h: float = float(texture.get_height()) / float(ROWS)
	if cell_w <= 0.0 or cell_h <= 0.0:
		return
	var frame: int = get_frame()
	var col: int = frame % COLS
	var row: int = int(float(frame) / float(COLS))
	var src := Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)
	var disp_h: float = VIEW_HEIGHT
	var disp_w: float = disp_h * (cell_w / cell_h)
	var dest_center := center + Vector2(0.0, CENTER_OFFSET_Y)
	var dest := Rect2(dest_center.x - disp_w * 0.5, dest_center.y - disp_h * 0.5, disp_w, disp_h)
	canvas.draw_texture_rect_region(texture, dest, src, Color(1.0, 1.0, 1.0, alpha))


static func _smooth01(value: float) -> float:
	var t: float = clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
