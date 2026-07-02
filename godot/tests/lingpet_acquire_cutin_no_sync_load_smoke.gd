extends SceneTree

const LingpetAcquireCutinState := preload("res://scripts/lingpet/lingpet_acquire_cutin_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_ready_gate_never_sync_loads_anim_sheet()
	_verify_live_prewarm_uses_unbounded_threaded_wait()
	_verify_asset_gate_deadline_releases_static_fallback()

	if _failures.is_empty():
		print("lingpet_acquire_cutin_no_sync_load_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_ready_gate_never_sync_loads_anim_sheet() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/hud/lingpet_acquire_cutin_overlay_host.gd")
	var ready_body := _function_body(source, "func is_pet_cutin_anim_ready")
	_expect(not ready_body.is_empty(), "cut-in host should expose the reveal asset-ready gate")
	_expect(
		ready_body.find("ProjectResourceLoader.load_imported_texture") < 0,
		"reveal asset-ready gate must not synchronously import-load the heavy cut-in anim sheet"
	)
	_expect(
		ready_body.find("_load_catalog_texture") < 0,
		"reveal asset-ready gate must not route through the synchronous catalog texture loader"
	)
	_expect(
		ready_body.find("prewarm_pet_assets_step(normalized, false)") >= 0,
		"reveal asset-ready gate should keep the threaded stream alive without sync fallback"
	)
	_expect(
		ready_body.find("return false") >= 0,
		"reveal asset-ready gate should report not-ready when the threaded stream has not cached the anim sheet"
	)


func _verify_live_prewarm_uses_unbounded_threaded_wait() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/hud/lingpet_acquire_cutin_overlay_host.gd")
	var pet_prewarm_body := _function_body(source, "func prewarm_pet_assets_step")
	_expect(
		source.find("CUTIN_LIVE_TEXTURE_PREWARM_MAX_MSEC := 0") >= 0
			and source.find("CUTIN_LIVE_TEXTURE_PREWARM_MAX_POLLS := 0") >= 0,
		"live cut-in texture prewarm should define no-expiry bounds so slow workers are not demoted to sync loads"
	)
	_expect(
		pet_prewarm_body.find("allow_sync_fallback") >= 0,
		"per-pet cut-in prewarm should make sync fallback an explicit opt-in"
	)
	_expect(
		pet_prewarm_body.find("CUTIN_LIVE_TEXTURE_PREWARM_MAX_MSEC") >= 0
			and pet_prewarm_body.find("CUTIN_LIVE_TEXTURE_PREWARM_MAX_POLLS") >= 0,
		"per-pet cut-in prewarm should use live no-expiry bounds by default"
	)


func _verify_asset_gate_deadline_releases_static_fallback() -> void:
	var state := LingpetAcquireCutinState.new()
	state.start("maribo")
	state.advance(LingpetAcquireCutinState.REVEAL_SECONDS * 2.0, false)
	_expect(
		not bool(state.is_awaiting_dismiss()),
		"missing anim sheet should hold the reveal before the static fallback deadline"
	)
	_expect(
		float(state.get_progress()) <= LingpetAcquireCutinState.REVEAL_ASSET_GATE_FRACTION + 0.001,
		"missing anim sheet should clamp reveal progress below the solid-art lock while the deadline has not expired"
	)
	state.advance(LingpetAcquireCutinState.REVEAL_ASSET_GATE_MAX_HOLD_SECONDS + LingpetAcquireCutinState.REVEAL_SECONDS, false)
	_expect(
		bool(state.is_awaiting_dismiss()),
		"deadline expiry should release the reveal on the static fallback instead of soft-locking the modal"
	)
	_expect(
		is_equal_approx(float(state.get_progress()), 1.0),
		"deadline-released static fallback reveal should reach full progress"
	)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_func := source.find("\nfunc ", start + signature.length())
	if next_func < 0:
		return source.substr(start)
	return source.substr(start, next_func - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
