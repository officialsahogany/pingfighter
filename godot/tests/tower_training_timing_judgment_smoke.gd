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

const TRACK_WIDTH_PX := 300.0
const TARGET_X_PX := 150.0

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_pixel_boundaries_and_luck_width()
	_verify_wall_clock_period_and_single_target_roll()
	_verify_three_tier_presentation_sequence()
	_verify_shared_timer_and_idle_ownership_sources()
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


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
