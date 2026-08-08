extends SceneTree

const GuardianEnhanceHost := preload(
	"res://scripts/hud/lingpet_guardian_enhance_cutin_overlay_host.gd"
)
const GuardianEnhanceState := preload(
	"res://scripts/lingpet/lingpet_guardian_enhance_cutin_state.gd"
)
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")

var _failures: Array[String] = []


class CachedIconResolver:
	extends RefCounted

	func has_cached_result_icon(_registry: Object, icon_path: String) -> bool:
		return icon_path.begins_with("cached_")


func _init() -> void:
	_verify_phase_layout_curves()
	_verify_reel_stops_on_applied_result()
	_verify_reel_candidate_projection()
	_verify_candidate_snapshot_is_display_only()
	_verify_mix_only_ink_and_stamp_contract()

	if _failures.is_empty():
		print("guardian_enhance_cutin_visual_contract_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_phase_layout_curves() -> void:
	var intro_start := GuardianEnhanceHost.resolve_presentation_layout({
		"phase": GuardianEnhanceState.PHASE_INTRO,
		"phase_progress": 0.0,
	})
	_expect_close(float(intro_start.get("panel_alpha", -1.0)), 0.0, "INTRO must begin transparent")
	_expect_close(float(intro_start.get("panel_scale", -1.0)), 0.94, "INTRO must begin at the approved compact scale")
	var stamp_impact := GuardianEnhanceHost.resolve_presentation_layout({
		"phase": GuardianEnhanceState.PHASE_STAMP,
		"phase_progress": 0.3181818,
		"phase_elapsed": 0.07,
	})
	_expect(float(stamp_impact.get("panel_scale", 0.0)) > 1.0, "STAMP must retain a readable overshoot during its 0.14s impact")
	var stamp_peak := GuardianEnhanceHost.resolve_presentation_layout({
		"phase": GuardianEnhanceState.PHASE_STAMP,
		"phase_progress": 0.4545455,
		"phase_elapsed": 0.10,
	})
	_expect_close(float(stamp_peak.get("veil_alpha", 0.0)), 0.80, "STAMP must deepen the veil to 0.80 at 0.10s")
	var stamp_settled := GuardianEnhanceHost.resolve_presentation_layout({
		"phase": GuardianEnhanceState.PHASE_STAMP,
		"phase_progress": 0.6363636,
		"phase_elapsed": 0.14,
	})
	_expect_close(float(stamp_settled.get("panel_scale", 0.0)), 1.0, "STAMP overshoot must settle by 0.14s")
	var outro_mid := GuardianEnhanceHost.resolve_presentation_layout({
		"phase": GuardianEnhanceState.PHASE_OUTRO,
		"phase_progress": 0.5,
	})
	_expect_close(float(outro_mid.get("panel_alpha", -1.0)), 0.5, "OUTRO must reverse-fade panel alpha")
	_expect_close(float(outro_mid.get("panel_scale", -1.0)), 0.985, "OUTRO must contract toward 0.97")


func _verify_reel_stops_on_applied_result() -> void:
	var rolling := _reel_snapshot(0.52, 0.39, ["candidate_a", "candidate_b"])
	_expect(
		GuardianEnhanceHost.resolve_reel_icon_path(rolling) in ["candidate_a", "candidate_b"],
		"mid-ROLL reel must show only display candidates"
	)
	var stopped := _reel_snapshot(1.0, GuardianEnhanceState.ROLL_SECONDS, ["candidate_a", "candidate_b"])
	_expect(
		GuardianEnhanceHost.resolve_reel_icon_path(stopped) == "applied_result",
		"ROLL close hook must stop on the actual applied result icon"
	)
	var stamp := stopped.duplicate(true)
	stamp["phase"] = GuardianEnhanceState.PHASE_STAMP
	_expect(
		GuardianEnhanceHost.resolve_reel_icon_path(stamp) == "applied_result",
		"post-ROLL phases must remain locked to the actual applied result icon"
	)
	_expect(
		GuardianEnhanceHost.resolve_reel_icon_path(_reel_snapshot(0.5, 0.3, ["only_candidate"])) == "applied_result",
		"one-candidate pools must skip the fake reel and show the result"
	)
	_expect(
		GuardianEnhanceHost.resolve_reel_icon_path(_reel_snapshot(0.5, 0.3, [])) == "applied_result",
		"zero cached candidates must fall back to the result without runtime lookup"
	)


func _verify_reel_candidate_projection() -> void:
	var runtime := LingpetEggRuntime.new()
	runtime._guardian_enhance_cutin_host_resolver = CachedIconResolver.new()
	var candidates: Array = [
		{"icon_texture_path": "cached_first"},
		{"icon_texture_path": "missing_selected"},
		{"kind": "stat"},
	]
	for candidate_index in range(3, 12):
		candidates.append({"icon_texture_path": "cached_%d" % candidate_index})
	var result := {
		"applied_index": 1,
		"result_detail": {"icon_texture_path": "cached_result"},
	}
	var projected: Array[String] = runtime._build_guardian_enhance_display_candidate_icons(
		candidates,
		result,
		null
	)
	_expect(projected.size() == 8, "reel projection must be bounded to eight display candidates")
	_expect(projected[1] == "cached_result", "selected candidate must project the applied result icon")
	_expect(projected.has(""), "iconless candidates must retain the procedural stat glyph slot")
	_expect(not projected.has("missing_selected"), "uncached paths must never enter the frame-time reel")


func _verify_candidate_snapshot_is_display_only() -> void:
	var state := GuardianEnhanceState.new()
	var result := {
		"accepted": true,
		"applied_index": 1,
		"display_candidate_icons": ["a", "b", "c"],
	}
	state.start("maribo", result)
	var snapshot: Dictionary = state.get_snapshot()
	_expect(
		snapshot.get("display_candidate_icons", []) == ["a", "b", "c"],
		"state snapshot must preserve the bounded display-only candidate order"
	)
	_expect(int((snapshot.get("result", {}) as Dictionary).get("applied_index", -1)) == 1, "display projection must not rewrite the applied result")


func _verify_mix_only_ink_and_stamp_contract() -> void:
	var host_source := FileAccess.get_file_as_string(
		"res://scripts/hud/lingpet_guardian_enhance_cutin_overlay_host.gd"
	)
	var runtime_source := FileAccess.get_file_as_string(
		"res://scripts/lingpet/lingpet_egg_runtime.gd"
	)
	_expect(host_source.find("canvas.material") < 0, "immediate draw must not claim a no-op material swap")
	_expect(host_source.find("blend_mode") < 0, "MIX-only host must not expose a false ADD blend contract")
	_expect(host_source.find("draw_arc") >= 0 and host_source.find("_draw_stamp_background") >= 0, "host must draw the authored Enso stroke and vermilion stamp")
	_expect(host_source.find("GOLD_RIM_COLOR") >= 0, "STAMP must retain its veil-side gold rim flare")
	_expect(runtime_source.find("display_candidate_icons") >= 0, "runtime result must carry display-only reel candidates")
	_expect(runtime_source.find("has_cached_result_icon") >= 0, "runtime reel builder must admit only prewarmed nonprocedural icons")


func _reel_snapshot(progress: float, elapsed: float, candidates: Array) -> Dictionary:
	return {
		"phase": GuardianEnhanceState.PHASE_ROLL,
		"roll_progress": progress,
		"phase_elapsed": elapsed,
		"display_candidate_icons": candidates,
		"result": {"result_detail": {"icon_texture_path": "applied_result"}},
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_close(actual: float, expected: float, message: String, tolerance: float = 0.001) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected %.4f, got %.4f)" % [message, expected, actual])
