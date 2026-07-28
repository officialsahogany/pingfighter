extends "res://scripts/hud/lingpet_acquire_cutin_overlay_host.gd"

# Presentation-only fork of the acquisition cut-in. The inherited host owns the
# proven 14-pet sheet grid overrides, threaded prewarm, static fallback, and
# cutin_vfx_anim lane. This host only adapts the runtime surface and replaces the
# acquisition copy with an enhancement result banner.

var _guardian_runtime: Object = null


class AcquireRuntimeProxy:
	extends RefCounted

	var source: Object = null

	func _init(runtime: Object) -> void:
		source = runtime

	func is_acquire_cutin_active() -> bool:
		return source != null and bool(source.is_guardian_enhance_cutin_active())

	func is_acquire_cutin_dismissing() -> bool:
		return source != null and bool(source.is_guardian_enhance_cutin_dismissing())

	func get_acquire_cutin_progress() -> float:
		return float(source.get_guardian_enhance_cutin_progress()) if source != null else 0.0

	func get_acquire_cutin_dismiss_progress() -> float:
		return float(source.get_guardian_enhance_cutin_dismiss_progress()) if source != null else 0.0

	func get_snapshot() -> Dictionary:
		return source.get_guardian_enhance_cutin_snapshot() if source != null else {}


func draw(canvas: CanvasItem, runtime: Object, view_size: Vector2) -> void:
	if runtime == null or not runtime.has_method("is_guardian_enhance_cutin_active"):
		return
	_guardian_runtime = runtime
	super.draw(canvas, AcquireRuntimeProxy.new(runtime), view_size)
	_guardian_runtime = null


func _draw_title(canvas: CanvasItem, view_size: Vector2, progress: float) -> void:
	if progress < TEXT_START:
		return
	var appear := _ease_out_cubic(clampf((progress - TEXT_START) / 0.12, 0.0, 1.0))
	var title := "수호령강화"
	var title_size := int(view_size.y * 0.062)
	var title_dim := TITLE_FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size)
	var title_pos := Vector2((view_size.x - title_dim.x) * 0.5, view_size.y * 0.75)
	canvas.draw_string(TITLE_FONT, title_pos + Vector2(2.0, 2.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(0.0, 0.04, 0.03, 0.7 * appear))
	canvas.draw_string(TITLE_FONT, title_pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(0.64, 1.0, 0.80, appear))
	var feedback := "강화 완료"
	if _guardian_runtime != null and _guardian_runtime.has_method("get_guardian_enhance_cutin_snapshot"):
		feedback = str((_guardian_runtime.get_guardian_enhance_cutin_snapshot() as Dictionary).get("feedback_text", feedback))
	var banner := Rect2(view_size.x * 0.18, view_size.y * 0.82, view_size.x * 0.64, view_size.y * 0.09)
	canvas.draw_rect(banner, Color(0.02, 0.13, 0.10, 0.90 * appear), true)
	canvas.draw_rect(banner, Color(0.52, 1.0, 0.76, appear), false, maxf(2.0, view_size.y * 0.003))
	var feedback_size := int(view_size.y * 0.030)
	var feedback_dim := TITLE_FONT.get_string_size(feedback, HORIZONTAL_ALIGNMENT_LEFT, -1, feedback_size)
	var feedback_pos := Vector2((view_size.x - feedback_dim.x) * 0.5, banner.position.y + banner.size.y * 0.64)
	canvas.draw_string(TITLE_FONT, feedback_pos, feedback, HORIZONTAL_ALIGNMENT_LEFT, -1, feedback_size, Color(0.94, 1.0, 0.96, appear))


func _draw_cutin_vfx_anim(
	canvas: CanvasItem,
	view_size: Vector2,
	t: float,
	entrance: float,
	alpha: float
) -> void:
	super._draw_cutin_vfx_anim(canvas, view_size, t, entrance, alpha)
	var center := Vector2(view_size.x * 0.5, view_size.y * 0.44)
	var pulse := 0.5 + 0.5 * sin(t * 7.0)
	for ring_index in range(3):
		var radius := view_size.y * (0.12 + float(ring_index) * 0.055 + pulse * 0.012)
		canvas.draw_arc(center, radius, t * (0.7 + ring_index * 0.2), t * (0.7 + ring_index * 0.2) + PI * 1.35, 48, Color(0.34, 1.0, 0.68, alpha * entrance * (0.52 - ring_index * 0.10)), maxf(2.0, view_size.y * 0.004), true)


func _draw_dismiss_hint(canvas: CanvasItem, view_size: Vector2, progress: float) -> void:
	if progress < HOLD_PROGRESS:
		return
	var pulse := 0.58 + 0.42 * sin(float(Time.get_ticks_msec()) * 0.006)
	var hint := "클릭하여 계속 · ESC 건너뛰기"
	var size_px := int(view_size.y * 0.026)
	var dim := TITLE_FONT.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px)
	var pos := Vector2((view_size.x - dim.x) * 0.5, view_size.y * 0.96)
	canvas.draw_string(TITLE_FONT, pos, hint, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(0.90, 1.0, 0.94, pulse))
