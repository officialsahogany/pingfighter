extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PhysiqueTrainingCatalog := preload("res://scripts/characters/physique_training_catalog.gd")
const PhysiqueTrainingOfferPlanner := preload("res://scripts/characters/physique_training_offer_planner.gd")
const PhysiqueTrainingState := preload("res://scripts/characters/physique_training_state.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const SmasherDashActiveMotionResolver := preload("res://scripts/characters/smasher_dash_active_motion_resolver.gd")
const CharacterInfoOverlayStatsPresenter := preload("res://scripts/hud/character_info_overlay_stats_presenter.gd")
const MythicItemResourceBonusRuntime := preload("res://scripts/items/mythic_item_resource_bonus_runtime.gd")
const TowerAscentFlowEconomyProgress := preload("res://scripts/tower_ascent/tower_ascent_flow_economy_progress.gd")
const TowerAscentNodeModalLocalization := preload("res://scripts/tower_ascent/tower_ascent_node_modal_localization.gd")
const TowerTrainingTimingJudgmentPolicy := preload("res://scripts/tower_ascent/tower_training_timing_judgment_policy.gd")

const EXPECTED_MATRIX_CASES := 99
const STORAGE_ID := "physique_storage"
const BASE_DASH_DURATION := 15.0
const PRE_FIX_DASH_AMOUNT := 5.0
const FPS_SCALE_60HZ := 1.0
const FPS_SCALE_72HZ := 60.0 / 72.0
const SHIPPED_TRAINED_DASH_DISTANCE := 240.0

var _catalog: Object = PhysiqueTrainingCatalog.new()
var _failures: Array[String] = []
var _matrix_cases := 0


func _init() -> void:
	var original_language := LanguageSettings.get_language()
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	PerkConversionFlags.debug_set_enabled(true)
	_verify_display_apply_matrix()
	_verify_dash_duration_label_localization()
	_verify_dash_judgment_distances()
	_verify_fractional_hit_gauge_stacks()
	_verify_multiply_before_ceiling()
	_verify_offer_and_modal_behavior_contracts()
	PerkConversionFlags.debug_set_enabled(false)
	LanguageSettings.set_test_locale_override(original_language)
	LanguageSettings.set_test_locale_override("")
	if _failures.is_empty():
		print("physique_training_display_apply_parity_smoke: matrix=%d dash=base<great<critical hit_stacks=1/2/3/5 caps=4" % _matrix_cases)
		print("physique_training_display_apply_parity_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_display_apply_matrix() -> void:
	var mastery_specs: Array[Dictionary] = [
		{"level": 0, "multiplier": 1.0},
		{"level": 1, "multiplier": 1.25},
		{"level": 3, "multiplier": 2.0},
	]
	var judgment_specs: Array[Dictionary] = [
		{"kind": TowerTrainingTimingJudgmentPolicy.JUDGMENT_BASE, "multiplier": 1.0},
		{"kind": TowerTrainingTimingJudgmentPolicy.JUDGMENT_GREAT, "multiplier": 1.3},
		{"kind": TowerTrainingTimingJudgmentPolicy.JUDGMENT_CRITICAL, "multiplier": 1.5},
	]
	for training_id: String in PhysiqueTrainingCatalog.TRAINING_IDS:
		var data: Dictionary = _catalog.get_training_data(training_id)
		var stat_key := str(data.get("stat_key", ""))
		var raw_amount := float(data.get("amount", 0.0))
		var ceiling := float(data.get("effective_ceiling", 0.0))
		var front_values: Array[String] = []
		var base_values: Array[String] = []
		var great_values: Array[String] = []
		var critical_values: Array[String] = []
		for mastery_spec: Dictionary in mastery_specs:
			var mastery_level := int(mastery_spec.get("level", 0))
			var effective_mastery := float(mastery_spec.get("multiplier", 1.0))
			if training_id == STORAGE_ID:
				effective_mastery = 1.0
			var expected_front := raw_amount * effective_mastery
			if ceiling > 0.0:
				expected_front = minf(expected_front, ceiling)
			front_values.append(_format_number(expected_front))
			for judgment_spec: Dictionary in judgment_specs:
				_matrix_cases += 1
				var runtime := RuntimePerkState.new()
				if mastery_level > 0:
					runtime.runtime_skill_levels["training_mastery"] = mastery_level
				var card: Dictionary = _catalog.build_card(
					training_id,
					0,
					runtime.get_physique_training_multiplier()
				)
				var context := "%s mastery=%.2f judgment=%s" % [
					training_id,
					effective_mastery,
					str(judgment_spec.get("kind", "")),
				]
				_expect(
					is_equal_approx(float(card.get("training_value_after", -1.0)), expected_front),
					"%s card front/accumulated value must include mastery" % context
				)
				var expected_description := "%s %s%s %s" % [
					str(card.get("training_value_label", "")),
					_format_number(expected_front),
					str(card.get("training_unit_ko", card.get("training_unit", ""))),
					"감소" if bool(card.get("training_reduction", false)) else "증가",
				]
				_expect(
					str(card.get("description", "")) == expected_description,
					"%s first-card copy must be '%s', got '%s'" % [context, expected_description, card.get("description", "")]
				)
				var judgment_kind := str(judgment_spec.get("kind", ""))
				var applied_multiplier := TowerTrainingTimingJudgmentPolicy.applied_multiplier(
					training_id,
					judgment_kind
				)
				card["training_effect_multiplier"] = applied_multiplier
				_expect(
					runtime._apply_physique_training_choice(card, null, null),
					"%s production training apply must accept" % context
				)
				var expected_applied := expected_front * applied_multiplier
				if ceiling > 0.0:
					expected_applied = minf(expected_applied, ceiling)
				match judgment_kind:
					TowerTrainingTimingJudgmentPolicy.JUDGMENT_GREAT:
						great_values.append(_format_number(expected_applied))
					TowerTrainingTimingJudgmentPolicy.JUDGMENT_CRITICAL:
						critical_values.append(_format_number(expected_applied))
					_:
						base_values.append(_format_number(expected_applied))
				_expect(
					is_equal_approx(runtime.get_physique_training_bonus(stat_key), expected_applied),
					"%s applied bonus must equal card front times judgment: expected %.4f got %.4f" % [
						context,
						expected_applied,
						runtime.get_physique_training_bonus(stat_key),
					]
				)
		print(
			"physique_training_display_apply_parity_smoke: row=%s front=%s base=%s great=%s critical=%s cases=9"
			% [
				training_id,
				"/".join(front_values),
				"/".join(base_values),
				"/".join(great_values),
				"/".join(critical_values),
			]
		)
	_expect(_matrix_cases == EXPECTED_MATRIX_CASES, "display/apply matrix must execute all 99 cases")


func _verify_dash_duration_label_localization() -> void:
	var expected_labels := {
		LanguageSettings.LANGUAGE_KOREAN: "활주 지속",
		LanguageSettings.LANGUAGE_ENGLISH: "Glide Duration",
		LanguageSettings.LANGUAGE_CHINESE: "滑步持续时间",
		LanguageSettings.LANGUAGE_JAPANESE: "滑走持続時間",
		LanguageSettings.LANGUAGE_SPANISH: "Duración del deslizamiento",
		LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL: "Duração do deslize",
		LanguageSettings.LANGUAGE_RUSSIAN: "Длительность скольжения",
	}
	var expected_mugong_summaries := {
		LanguageSettings.LANGUAGE_ENGLISH: "glide duration",
		LanguageSettings.LANGUAGE_CHINESE: "滑步持续时间",
		LanguageSettings.LANGUAGE_JAPANESE: "滑走持続時間",
		LanguageSettings.LANGUAGE_SPANISH: "duración del deslizamiento",
		LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL: "duração do deslize",
		LanguageSettings.LANGUAGE_RUSSIAN: "длительность скольжения",
	}
	for locale: String in LanguageSettings.SUPPORTED_LANGUAGES:
		LanguageSettings.set_test_locale_override(locale)
		var description := str(_catalog.build_card("physique_dash_distance", 0).get("description", ""))
		_expect(
			description.contains(str(expected_labels.get(locale, ""))),
			"%s dash-duration card must use the localized duration label: %s" % [locale, description]
		)
		var mugong: Dictionary = RuntimePerkCatalog.new().get_perk_data("dash_jump")
		if locale == LanguageSettings.LANGUAGE_KOREAN:
			for level: int in range(1, 6):
				var level_description := str((mugong.get("descriptions", {}) as Dictionary).get(level, ""))
				_expect(
					level_description.contains("활주 지속") and not level_description.contains("활주 거리"),
					"dash Mugong Lv.%d must use the duration vocabulary: %s" % [level, level_description]
				)
		else:
			var summary := str(mugong.get("description", "")).to_lower()
			_expect(
				summary.contains(str(expected_mugong_summaries.get(locale, ""))),
				"%s dash Mugong summary must use the duration vocabulary: %s" % [locale, summary]
			)
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)


func _verify_dash_judgment_distances() -> void:
	var displayed_distances: Array[float] = []
	var distances_60hz: Array[float] = []
	var distances_72hz: Array[float] = []
	var previous_60hz: Array[float] = []
	var previous_72hz: Array[float] = []
	for judgment_kind: String in [
		TowerTrainingTimingJudgmentPolicy.JUDGMENT_BASE,
		TowerTrainingTimingJudgmentPolicy.JUDGMENT_GREAT,
		TowerTrainingTimingJudgmentPolicy.JUDGMENT_CRITICAL,
	]:
		var runtime := RuntimePerkState.new()
		var card: Dictionary = _catalog.build_card("physique_dash_distance", 0)
		card["training_effect_multiplier"] = TowerTrainingTimingJudgmentPolicy.applied_multiplier(
			"physique_dash_distance",
			judgment_kind
		)
		_expect(runtime._apply_physique_training_choice(card, null, null), "%s dash fixture must apply" % judgment_kind)
		var duration := runtime.get_dash_duration_frames(BASE_DASH_DURATION)
		var predicted_distance := SmasherDashActiveMotionResolver.compute_total_dash_distance(duration)
		var actual_60hz := _simulate_dash_distance(duration, FPS_SCALE_60HZ)
		var actual_72hz := _simulate_dash_distance(duration, FPS_SCALE_72HZ)
		var applied_multiplier := TowerTrainingTimingJudgmentPolicy.applied_multiplier(
			"physique_dash_distance",
			judgment_kind
		)
		var previous_duration := BASE_DASH_DURATION * (
			1.0 + PRE_FIX_DASH_AMOUNT * applied_multiplier / 100.0
		)
		var old_60hz := _simulate_dash_distance(previous_duration, FPS_SCALE_60HZ)
		var old_72hz := _simulate_dash_distance(previous_duration, FPS_SCALE_72HZ)
		_expect(
			is_equal_approx(actual_60hz, predicted_distance),
			"%s 60Hz dash %.6f must match the fps-independent displayed integration %.6f" % [judgment_kind, actual_60hz, predicted_distance]
		)
		_expect(
			actual_72hz >= predicted_distance and actual_72hz - predicted_distance < 3.0,
			"%s 72Hz integration %.6f must stay within the measured positive discretization band above display %.6f" % [judgment_kind, actual_72hz, predicted_distance]
		)
		_expect(
			actual_60hz > old_60hz and actual_72hz > old_72hz,
			"%s corrected amount must not regress either tick-rate leg" % judgment_kind
		)
		displayed_distances.append(predicted_distance)
		distances_60hz.append(actual_60hz)
		distances_72hz.append(actual_72hz)
		previous_60hz.append(old_60hz)
		previous_72hz.append(old_72hz)
	_expect(
		displayed_distances.size() == 3
		and absf(displayed_distances[0] - SHIPPED_TRAINED_DASH_DISTANCE) <= 1.0
		and displayed_distances[0] < displayed_distances[1]
		and displayed_distances[1] < displayed_distances[2],
		"dash judgment tiers must preserve the 240px base total and remain distinct: %s" % [displayed_distances]
	)
	if displayed_distances.size() == 3:
		print("physique_training_display_apply_parity_smoke: dash_display=%.3f/%.3f/%.3f" % displayed_distances)
		print("physique_training_display_apply_parity_smoke: dash_before_60hz=%.3f/%.3f/%.3f dash_after_60hz=%.3f/%.3f/%.3f" % [previous_60hz[0], previous_60hz[1], previous_60hz[2], distances_60hz[0], distances_60hz[1], distances_60hz[2]])
		print("physique_training_display_apply_parity_smoke: dash_before_72hz=%.3f/%.3f/%.3f dash_after_72hz=%.3f/%.3f/%.3f" % [previous_72hz[0], previous_72hz[1], previous_72hz[2], distances_72hz[0], distances_72hz[1], distances_72hz[2]])


func _simulate_dash_distance(duration_frames: float, fps_scale: float) -> float:
	var resolver := SmasherDashActiveMotionResolver.new()
	var position := Vector2.ZERO
	var timer := duration_frames
	var guard := 0
	while timer > 0.0 and guard < 600:
		var result: Dictionary = resolver.update(
			fps_scale,
			position,
			-100000.0,
			100000.0,
			0.0,
			1.0,
			timer,
			false
		)
		position = result.get("player_pos", position) as Vector2
		timer = float(result.get("timer", 0.0))
		guard += 1
	return position.x


func _verify_fractional_hit_gauge_stacks() -> void:
	var resource_runtime := MythicItemResourceBonusRuntime.new()
	for stack_count: int in [1, 2, 3, 5]:
		var runtime := RuntimePerkState.new()
		for index: int in range(stack_count):
			_expect(
				runtime._apply_physique_training_choice(
					_catalog.build_card("physique_hit_gauge", index),
					null,
					null
				),
				"hit-gauge stack %d must apply" % (index + 1)
			)
		var actual := resource_runtime.calculate_bluetooth_ring_gauge_charge(
			RuntimeBridge.new(runtime),
			50.0
		)
		var expected := 50.0 * (1.0 + 0.07 * float(stack_count))
		_expect(
			is_equal_approx(actual, expected),
			"hit-gauge stacks=%d must preserve %.4f instead of flooring to %.4f" % [stack_count, expected, actual]
		)
		var displayed := CharacterInfoOverlayStatsPresenter.format_gauge_point_value(actual)
		_expect(
			displayed == "%spt" % _format_number(actual)
			and float(displayed.trim_suffix("pt")) <= actual,
			"hit-gauge stacks=%d TAB value must expose the real fractional gain without rounding up: %s" % [stack_count, displayed]
		)
	print("physique_training_display_apply_parity_smoke: hit_gauge=53.5/57.0/60.5/67.5")


func _verify_multiply_before_ceiling() -> void:
	var cap_specs: Array[Dictionary] = [
		{"id": "physique_dash_recharge", "count": 25, "ceiling": 100.0},
		{"id": "physique_dash_recovery", "count": 17, "ceiling": 100.0},
		{"id": "physique_active_item_cooldown", "count": 14, "ceiling": 95.0},
		{"id": "physique_chosik_cooldown", "count": 32, "ceiling": 95.0},
	]
	for spec: Dictionary in cap_specs:
		var training_id := str(spec.get("id", ""))
		var count := int(spec.get("count", 0))
		var ceiling := float(spec.get("ceiling", 0.0))
		var state := PhysiqueTrainingState.new()
		for _index: int in range(count):
			state.commit(training_id, _catalog)
		var stat_key := str(_catalog.get_stat_key(training_id))
		var card: Dictionary = _catalog.build_card(
			training_id,
			count,
			2.0,
			state.get_applied_count(training_id)
		)
		_expect(
			is_equal_approx(state.get_bonus(stat_key, _catalog, 2.0), ceiling),
			"%s state must multiply before clamping to %.1f" % [training_id, ceiling]
		)
		_expect(
			float(card.get("training_value_before", ceiling + 1.0)) <= ceiling
			and float(card.get("training_value_after", ceiling + 1.0)) <= ceiling,
			"%s card accumulated values must not advertise above %.1f" % [training_id, ceiling]
		)
		var runtime := RuntimePerkState.new()
		var restore_result: Dictionary = runtime.apply_unlock_save_snapshot({
			"runtime_skill_levels": {"training_mastery": 3},
			"physique_training": state.get_snapshot(),
		})
		_expect(bool(restore_result.get("restored", false)), "%s high-stack snapshot must restore" % training_id)
		_expect(
			is_equal_approx(runtime.get_physique_training_bonus(stat_key), ceiling),
			"%s final runtime bonus must stop at %.1f" % [training_id, ceiling]
		)
		match training_id:
			"physique_dash_recharge":
				_expect(is_equal_approx(runtime.get_dash_recharge_frames(300.0), 6.0), "dash recharge consumer must retain its six-frame floor")
			"physique_dash_recovery":
				_expect(is_equal_approx(runtime.get_dash_recovery_frames(42.0), 1.0), "dash recovery consumer must retain its one-frame floor")
			"physique_active_item_cooldown":
				_expect(runtime.get_active_item_cooldown_msec(1000) == 50, "active-item cooldown consumer must retain its five-percent floor")
			"physique_chosik_cooldown":
				_expect(is_equal_approx(runtime.get_player_skill_cooldown_multiplier(), 0.05), "Chosik consumer must retain its five-percent floor")


func _verify_offer_and_modal_behavior_contracts() -> void:
	var planner_state := PhysiqueTrainingState.new()
	_expect(
		bool(planner_state.commit("physique_dash_recharge", _catalog, 1.5).get("accepted", false)),
		"planner applied-count fixture must commit"
	)
	var planned: Dictionary = PhysiqueTrainingOfferPlanner.new().plan_offer(
		[{"id": "replaceable", "offer_lane": "replaceable", "offer_protected": false}],
		PhysiqueTrainingOfferPlanner.OFFER_SOURCE_BATTLE_STARPOINT,
		planner_state,
		_catalog,
		0.0,
		0.0,
		0.0
	)
	var planned_choices: Array = planned.get("choices", []) as Array
	var planned_card: Dictionary = planned_choices[0] as Dictionary if planned_choices.size() == 1 else {}
	_expect(
		bool(planned.get("appeared", false))
		and is_equal_approx(float(planned_card.get("training_applied_count_before", -1.0)), 1.5)
		and is_equal_approx(float(planned_card.get("training_value_before", -1.0)), 6.0),
		"live offer planner must project the real fractional applied_count into its card"
	)

	var economy := TowerAscentFlowEconomyProgress.new()
	var action: Dictionary = economy._build_training_action(
		"stat",
		_catalog.build_card("physique_move_speed", 0, 2.0),
		10,
		{"muhon": 10}
	)
	var live_choice: Dictionary = action.get("payload", {}).get("choice", {}) as Dictionary
	_expect(
		str(live_choice.get("bonus_badge_text", ""))
		== TowerAscentNodeModalLocalization.text(
			TowerAscentNodeModalLocalization.KEY_TRAINING_JUDGMENT_MAX_BADGE,
			{"effect": "12%"}
		),
		"training action producer must expose the separated judgment-maximum badge"
	)
	_expect(
		economy._training_maximum_message({
			"id": STORAGE_ID,
			"training_max_count": 5,
		}) == "5/5",
		"storage maximum fallback must derive from catalog metadata"
	)
	var localization_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_node_modal_localization.gd"
	)
	_expect(
		not localization_source.contains("KEY_TRAINING_BONUS_BADGE")
		and TowerAscentNodeModalLocalization.KEY_TRAINING_JUDGMENT_MAX_BADGE
		!= TowerAscentNodeModalLocalization.KEY_TRAINING_TIMING_BADGE,
		"the retired timing-badge alias must not bypass the separated badge contract"
	)


func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.1f" % value


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class RuntimeBridge:
	extends RefCounted

	var runtime_perk_state_ref: Object

	func _init(state: Object) -> void:
		runtime_perk_state_ref = state
