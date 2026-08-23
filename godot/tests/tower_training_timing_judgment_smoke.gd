extends SceneTree

const TowerTrainingTimingJudgmentPolicy := preload(
	"res://scripts/tower_ascent/tower_training_timing_judgment_policy.gd"
)
const TowerTrainingTimingState := preload(
	"res://scripts/tower_ascent/tower_training_timing_state.gd"
)
const TowerTrainingStrikePresentationState := preload(
	"res://scripts/tower_ascent/tower_training_strike_presentation_state.gd"
)
const TowerAscentNodeModalLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_localization.gd"
)
const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)

const TRACK_WIDTH_PX := 300.0
const TARGET_X_PX := 150.0
const TIMING_GAUGE_ASSET_SPECS := [
	{
		"path": "res://assets/ui/tower_training_gauge/tower_training_gauge_frame_imagegen_v1.png",
		"sha256": "127019a4e3dd3b41351508c821088e529bf4670dc04f36e339e3db8fb9fe8401",
		"size": Vector2i(1593, 156),
		"imported_name": "tower_training_gauge_frame_imagegen_v1.png-73107fd70445e4ac76b5506d8fa38b40.ctex",
	},
	{
		"path": "res://assets/ui/tower_training_gauge/tower_training_gauge_tick_imagegen_v1.png",
		"sha256": "ce4f992983ac8cc9b8a01e64736ca64dd206dbac6c9e2576044fb976c6d17eb4",
		"size": Vector2i(123, 517),
		"imported_name": "tower_training_gauge_tick_imagegen_v1.png-cfb846a65982b33a635698224a7a1a46.ctex",
	},
	{
		"path": "res://assets/ui/tower_training_gauge/tower_training_gauge_pointer_imagegen_v2.png",
		"sha256": "e69b3e712dc9b44b7bea500b3d920d6df1cba2354b51fb6d9d844722cffeb1f6",
		"size": Vector2i(218, 918),
		"imported_name": "tower_training_gauge_pointer_imagegen_v2.png-d64df188574f2c6ba1ec6dfc35de7c2e.ctex",
	},
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_pixel_boundaries_and_luck_width()
	_verify_wall_clock_period_and_single_target_roll()
	_verify_three_tier_presentation_sequence()
	_verify_shared_timer_and_idle_ownership_sources()
	_verify_training_timing_gauge_promoted_assets()
	_verify_training_timing_gauge_asset_contract_and_fallback()
	_verify_localization_and_retired_probability_copy()
	if _failures.is_empty():
		print("tower_training_timing_judgment_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_pixel_boundaries_and_luck_width() -> void:
	# 피드백2 2항: Luck 2 means the critical cell is exactly 6px on this 300px
	# contract track and each great band is twice that (12px). Critical is
	# [147, 153], great bands are [135, 147) and (153, 165].
	_expect(_judge_px(147) == "critical", "left critical boundary pixel belongs to critical")
	_expect(_judge_px(146) == "great", "one pixel outside left critical boundary drops to great")
	_expect(_judge_px(153) == "critical", "right critical boundary pixel belongs to critical")
	_expect(_judge_px(154) == "great", "one pixel outside right critical boundary drops to great")
	_expect(_judge_px(135) == "great", "left great outer boundary pixel belongs to great")
	_expect(_judge_px(134) == "base", "one pixel outside left great boundary drops to base")
	_expect(_judge_px(165) == "great", "right great outer boundary pixel belongs to great")
	_expect(_judge_px(166) == "base", "one pixel outside right great boundary drops to base")

	var width_base := TowerTrainingTimingJudgmentPolicy.cell_width_ratio(
		TowerTrainingTimingJudgmentPolicy.BASE_LUCK_PERCENT
	)
	var width_max := TowerTrainingTimingJudgmentPolicy.cell_width_ratio(8.0)
	var width_over_cap := TowerTrainingTimingJudgmentPolicy.cell_width_ratio(80.0)
	var width_under_floor := TowerTrainingTimingJudgmentPolicy.cell_width_ratio(0.25)
	_expect(is_equal_approx(width_base, 0.02), "base Luck 2 derives a 2 percent critical cell")
	_expect(is_equal_approx(width_max, 0.08), "Luck 8 derives the 8 percent ceiling cell")
	_expect(is_equal_approx(width_over_cap, 0.08), "Luck width cap preserves a base-result region")
	_expect(is_equal_approx(width_under_floor, 0.01), "Luck width floor keeps a visible 1 percent cell")
	var judged := TowerTrainingTimingJudgmentPolicy.judge_position(0.5, 0.5, 2.0)
	_expect(
		is_equal_approx(float(judged.get("great_outer_half_width_ratio", 0.0)), 0.05),
		"great bands must span exactly twice the critical cell on each side"
	)
	var timing := TowerTrainingTimingState.new()
	timing.set_clock_msec_for_tests(400)
	var visual_target := TowerTrainingTimingJudgmentPolicy.roll_target(11, "zone-node", "zone", 0, 2.0)
	_expect(timing.start(visual_target), "zone visual fixture starts")
	var zone_model: Dictionary = timing.get_visual_model()
	var zone_target := float(zone_model.get("target_position", -1.0))
	_expect(
		is_equal_approx(float(zone_model.get("great_left_start", 9.9)), zone_target - 0.05)
		and is_equal_approx(float(zone_model.get("critical_start", 9.9)), zone_target - 0.01)
		and is_equal_approx(float(zone_model.get("critical_end", -9.9)), zone_target + 0.01)
		and is_equal_approx(float(zone_model.get("great_right_end", -9.9)), zone_target + 0.05),
		"visual model zone boundaries must mirror the judgment factors"
	)
	_expect(is_equal_approx(TowerTrainingTimingJudgmentPolicy.multiplier_for_judgment("critical"), 1.5), "critical multiplier is x1.5")
	_expect(is_equal_approx(TowerTrainingTimingJudgmentPolicy.multiplier_for_judgment("great"), 1.3), "great multiplier is x1.3")
	_expect(is_equal_approx(TowerTrainingTimingJudgmentPolicy.multiplier_for_judgment("base"), 1.0), "base multiplier is x1.0")


func _verify_wall_clock_period_and_single_target_roll() -> void:
	var target := TowerTrainingTimingJudgmentPolicy.roll_target(7721, "training-node", "move-speed", 4, 20.0)
	_expect(int(target.get("roll_count", 0)) == 1, "one valid timing start rolls target exactly once")
	var timing := TowerTrainingTimingState.new()
	timing.set_clock_msec_for_tests(1000)
	_expect(timing.start(target), "timing state starts from one authoritative target")
	var expected_positions := {
		1000: 0.0,
		1200: 0.25,
		1400: 0.5,
		1800: 1.0,
		2200: 0.5,
		2600: 0.0,
	}
	for wall_msec in expected_positions:
		timing.set_clock_msec_for_tests(int(wall_msec))
		timing.update_wall_clock()
		_expect(is_equal_approx(
			float(timing.get_debug_state().get("pendulum_position", -1.0)),
			float(expected_positions[wall_msec])
		), "analytic wall-clock position is frame-rate independent at %dms" % wall_msec)
	_expect(int(timing.get_debug_state().get("target_roll_count", 0)) == 1, "many presentation frames never reroll target placement")


func _verify_three_tier_presentation_sequence() -> void:
	var critical := _started_strike("critical", 1000)
	var critical_start: Dictionary = critical.get_visual_model()
	_expect(bool(critical_start.get("hitstop_active", false)), "critical starts with presentation-only hitstop")
	_expect(not bool(critical_start.get("aura_active", true)), "critical aura waits until the 200ms prelude ends")
	critical.set_clock_msec_for_tests(1199)
	critical.update_wall_clock()
	_expect(bool(critical.get_visual_model().get("hitstop_active", false)), "critical prelude remains frozen through 199ms")
	critical.set_clock_msec_for_tests(1200)
	critical.update_wall_clock()
	var critical_aura: Dictionary = critical.get_visual_model()
	_expect(bool(critical_aura.get("aura_active", false)), "red critical aura begins after prelude hitstop")
	_expect(not bool(critical_aura.get("strike_visible", true)), "critical strike waits for the red aura beat")
	critical.set_clock_msec_for_tests(1259)
	critical.update_wall_clock()
	_expect(not bool(critical.get_visual_model().get("strike_visible", true)), "critical aura leads the attack through 59ms")
	critical.set_clock_msec_for_tests(1260)
	critical.update_wall_clock()
	_expect(bool(critical.get_visual_model().get("strike_visible", false)), "critical attack starts after the 60ms aura lead")
	critical.set_clock_msec_for_tests(1720)
	critical.update_wall_clock()
	var critical_wobble: Dictionary = critical.get_visual_model()
	_expect(is_equal_approx(rad_to_deg(float(critical_wobble.get("dummy_rotation_radians", 0.0))), 12.0), "critical dummy reaches the large 12 degree wobble")
	_expect(bool(critical_wobble.get("message_active", false)), "critical message rises only after the dummy reaches its away pose")
	_expect(str(critical_wobble.get("message_text", "")).begins_with("회심의 수련!"), "critical sequence retains confirmed copy")

	var great := _started_strike("great", 3000)
	_expect(bool(great.get_visual_model().get("aura_active", false)), "great begins with blue aura")
	great.set_clock_msec_for_tests(3460)
	great.update_wall_clock()
	_expect(is_equal_approx(rad_to_deg(float(great.get_visual_model().get("dummy_rotation_radians", 0.0))), 7.0), "great dummy uses medium 7 degree wobble")

	var base := _started_strike("base", 5000)
	_expect(not bool(base.get_visual_model().get("aura_active", true)), "base result has no aura")
	base.set_clock_msec_for_tests(5460)
	base.update_wall_clock()
	_expect(is_equal_approx(rad_to_deg(float(base.get_visual_model().get("dummy_rotation_radians", 0.0))), 3.5), "base dummy uses slight 3.5 degree wobble")


func _verify_shared_timer_and_idle_ownership_sources() -> void:
	var runtime_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_runtime.gd"
	)
	var policy_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_training_timing_judgment_policy.gd"
	)
	var offer_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_training_offer_builder.gd"
	)
	var transition_tick := runtime_source.find("_transition_fade_state.update_node_modal_fade")
	var presentation_tick := runtime_source.find("update_training_presentations_wall_clock", transition_tick)
	_expect(transition_tick >= 0 and presentation_tick > transition_tick, "shared modal timer ticks before display-only timing presentation")
	var between := runtime_source.substr(transition_tick, presentation_tick - transition_tick)
	_expect(not between.contains("return"), "critical hitstop cannot return early and freeze shared modal timers")

	var modal_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_node_modal_state.gd"
	)
	_expect(modal_source.contains("var _training_timing_state: Object = null"), "idle modal owns no timing state or dynamic layer")
	_expect(modal_source.contains("var state := TowerTrainingTimingState.new()"), "timing RefCounted is allocated only by active begin path")
	_expect(not runtime_source.contains("TowerTrainingTimingState.new()"), "idle runtime frame never allocates timing UI")
	_expect(
		policy_source.contains("RandomNumberGenerator.new()")
		and policy_source.contains("map_seed")
		and policy_source.contains("node_id")
		and not policy_source.contains("_gameplay_rng_state"),
		"target authority follows the offer policy's map/node-derived local RNG"
	)
	_expect(
		offer_source.contains("RandomNumberGenerator.new()")
		and offer_source.contains("map_seed")
		and offer_source.contains("node_id"),
		"training offer remains the source stream-policy counterproof"
	)

	var renderer_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	)
	var aura_start := renderer_source.find("func _draw_training_judgment_aura")
	var aura_end := renderer_source.find("func _draw_training_judgment_message", aura_start)
	var aura_source := renderer_source.substr(aura_start, aura_end - aura_start)
	_expect(
		not aura_source.contains("draw_arc")
		and not aura_source.contains("draw_polyline")
		and not aura_source.contains("draw_dashed_line"),
		"judgment aura contains no closed outline, ring, or dotted stroke"
	)
	_expect(
		aura_source.contains("0.02")
		and aura_source.contains("24.0 * content_scale")
		and aura_source.contains("7.0 * content_scale"),
		"judgment aura uses approved broad low-alpha filled layers"
	)


func _verify_training_timing_gauge_asset_contract_and_fallback() -> void:
	var renderer := TowerAscentFlowRenderer.new()
	var expected_paths := PackedStringArray([
		"res://assets/ui/tower_training_gauge/tower_training_gauge_frame_imagegen_v1.png",
		"res://assets/ui/tower_training_gauge/tower_training_gauge_tick_imagegen_v1.png",
		"res://assets/ui/tower_training_gauge/tower_training_gauge_pointer_imagegen_v2.png",
	])
	_expect(
		renderer.get_training_timing_gauge_asset_paths() == expected_paths,
		"timing-gauge prewarm exposes the three approved asset paths"
	)
	var contract: Dictionary = renderer.get_training_timing_gauge_asset_contract()
	_expect(
		Vector2i(contract.get("frame_source_size", Vector2i.ZERO)) == Vector2i(1593, 156)
		and Vector2i(contract.get("tick_source_size", Vector2i.ZERO)) == Vector2i(123, 517)
		and Vector2i(contract.get("pointer_source_size", Vector2i.ZERO)) == Vector2i(218, 918)
		and Vector2i(contract.get("runtime_gauge_size", Vector2i.ZERO)) == Vector2i(357, 29),
		"timing-gauge source and runtime dimensions match the approved art contract"
	)
	var bitmap_state: Dictionary = renderer.get_training_timing_gauge_asset_debug_state()
	_expect(
		bool(bitmap_state.get("loaded", false))
		and str(bitmap_state.get("render_mode", "")) == "bitmap"
		and Vector2i(bitmap_state.get("frame_size", Vector2i.ZERO)) == Vector2i(1593, 156)
		and Vector2i(bitmap_state.get("tick_size", Vector2i.ZERO)) == Vector2i(123, 517)
		and Vector2i(bitmap_state.get("pointer_size", Vector2i.ZERO)) == Vector2i(218, 918),
		"all three approved textures are prewarmed before the timing gauge draws"
	)
	renderer.debug_set_training_timing_gauge_textures(null, null, null)
	var fallback_state: Dictionary = renderer.get_training_timing_gauge_asset_debug_state()
	_expect(
		not bool(fallback_state.get("loaded", true))
		and str(fallback_state.get("render_mode", "")) == "procedural_fallback",
		"one missing timing-gauge set selects the complete procedural fallback"
	)
	renderer.prewarm_training_timing_gauge_assets()
	_expect(
		bool(renderer.get_training_timing_gauge_asset_debug_state().get("loaded", false)),
		"timing-gauge prewarm recovers after the forced missing-texture leg"
	)

	var renderer_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	)
	var gauge_start := renderer_source.find("func _draw_training_timing_gauge(")
	var gauge_end := renderer_source.find("func _training_timing_segment_rect", gauge_start)
	var gauge_source := renderer_source.substr(gauge_start, gauge_end - gauge_start)
	_expect(
		gauge_start >= 0
		and gauge_end > gauge_start
		and gauge_source.contains("var use_bitmap_chrome := _has_training_timing_gauge_assets()")
		and gauge_source.contains("_draw_training_timing_gauge_procedural_frame")
		and gauge_source.contains("_draw_training_timing_gauge_procedural_tick")
		and gauge_source.contains("_draw_training_timing_gauge_procedural_pointer"),
		"bitmap rendering keeps the complete procedural frame, tick, and pointer fallback"
	)
	_expect(
		gauge_source.contains('model.get("critical_start"')
		and gauge_source.contains('model.get("critical_end"')
		and gauge_source.contains('model.get("great_left_start"')
		and gauge_source.contains('model.get("great_right_end"')
		and gauge_source.contains("track_rect.size.x * float(boundary_ratio)"),
		"GRT-018 bitmap ticks still consume the state model's precomputed boundaries"
	)
	_expect(
		gauge_source.contains("draw_texture_rect_region")
		and gauge_source.contains("draw_texture_rect")
		and gauge_source.contains("canvas.draw_rect(")
		and gauge_source.contains("canvas.draw_line(")
		and gauge_source.contains("canvas.draw_circle(")
		and not gauge_source.contains("ProjectResourceLoader"),
		"timing-gauge draw uses cached bitmaps while source-sealing the old procedural calls"
	)


func _verify_training_timing_gauge_promoted_assets() -> void:
	for spec_variant in TIMING_GAUGE_ASSET_SPECS:
		var spec: Dictionary = spec_variant
		var asset_path := str(spec.get("path", ""))
		var import_path := asset_path + ".import"
		_expect(FileAccess.file_exists(asset_path), "%s must be promoted" % asset_path)
		_expect(FileAccess.file_exists(import_path), "%s must carry its .import sidecar" % asset_path)
		if not FileAccess.file_exists(asset_path):
			continue
		_expect(
			FileAccess.get_sha256(asset_path).to_lower() == str(spec.get("sha256", "")),
			"%s bytes must exactly match the approved candidate" % asset_path
		)
		var image := Image.load_from_file(ProjectSettings.globalize_path(asset_path))
		_expect(image != null and not image.is_empty(), "%s must decode" % asset_path)
		if image == null or image.is_empty():
			continue
		_expect(
			image.get_size() == Vector2i(spec.get("size", Vector2i.ZERO)),
			"%s canvas must match the approved source size" % asset_path
		)
		_expect(
			_edge_alpha_count(image) == 0,
			"%s transparent canvas edges must remain empty" % asset_path
		)
		if not FileAccess.file_exists(import_path):
			continue
		var import_source := FileAccess.get_file_as_string(import_path)
		_expect(
			import_source.contains('source_file="%s"' % asset_path),
			"%s .import must target the promoted PNG" % asset_path
		)
		_expect(
			import_source.contains(str(spec.get("imported_name", ""))),
			"%s .import must name its deterministic materialized texture" % asset_path
		)
		_expect(
			import_source.contains("compress/mode=0")
			and import_source.contains("mipmaps/generate=false"),
			"%s must retain lossless, no-mipmap UI import settings" % asset_path
		)


func _verify_localization_and_retired_probability_copy() -> void:
	var timing_keys: Array[String] = [
		TowerAscentNodeModalLocalization.KEY_TRAINING_TIMING_BADGE,
		TowerAscentNodeModalLocalization.KEY_TRAINING_TIMING_PROMPT,
		TowerAscentNodeModalLocalization.KEY_TRAINING_TIMING_CANCELLED,
		TowerAscentNodeModalLocalization.KEY_TRAINING_TIMING_CRITICAL,
		TowerAscentNodeModalLocalization.KEY_TRAINING_TIMING_GREAT,
		TowerAscentNodeModalLocalization.KEY_TRAINING_TIMING_BASE,
		TowerAscentNodeModalLocalization.KEY_TRAINING_TIMING_RESULT,
	]
	var translated_locale_count := 0
	for locale_text_variant in TowerAscentNodeModalLocalization.TEXT_BY_LOCALE.values():
		var locale_text: Dictionary = locale_text_variant
		var has_all_timing_keys := true
		for key in timing_keys:
			if not locale_text.has(key):
				has_all_timing_keys = false
				break
		if has_all_timing_keys:
			translated_locale_count += 1
	_expect(translated_locale_count == 7, "all seven locales contain every timing key")
	var localization_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_node_modal_localization.gd"
	)
	_expect(localization_source.contains('KEY_TRAINING_TIMING_CRITICAL: "회심의 수련!"'), "confirmed critical Korean copy is exact")
	_expect(localization_source.contains('KEY_TRAINING_TIMING_GREAT: "훌륭한 수련!"'), "confirmed great Korean copy is exact")
	_expect(localization_source.contains('KEY_TRAINING_TIMING_BASE: "수련 성공"'), "confirmed base Korean copy is exact")
	_expect(not localization_source.contains("행운 20% · 효과 +50%"), "retired random-luck footer copy is absent")
	_expect(not localization_source.contains("행운 발동!"), "retired random trigger receipt is absent")


func _started_strike(kind: String, start_msec: int) -> Object:
	var state := TowerTrainingStrikePresentationState.new()
	state.configure("smasher", {}, null)
	state.set_clock_msec_for_tests(start_msec)
	var result_copy: String = str({
		"critical": "회심의 수련! 이동 속도 +6%",
		"great": "훌륭한 수련! 이동 속도 +5.2%",
		"base": "수련 성공 이동 속도 +4%",
	}.get(kind, "수련 성공 이동 속도 +4%"))
	_expect(state.start(kind, result_copy), "%s strike starts" % kind)
	return state


func _judge_px(position_px: int) -> String:
	return str(TowerTrainingTimingJudgmentPolicy.judge_position(
		float(position_px) / TRACK_WIDTH_PX,
		TARGET_X_PX / TRACK_WIDTH_PX,
		2.0
	).get("judgment_kind", ""))


func _edge_alpha_count(image: Image) -> int:
	var count := 0
	for x in range(image.get_width()):
		count += int(image.get_pixel(x, 0).a > 0.0)
		count += int(image.get_pixel(x, image.get_height() - 1).a > 0.0)
	for y in range(1, image.get_height() - 1):
		count += int(image.get_pixel(0, y).a > 0.0)
		count += int(image.get_pixel(image.get_width() - 1, y).a > 0.0)
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
