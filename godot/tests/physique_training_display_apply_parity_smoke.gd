extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PhysiqueTrainingCatalog := preload("res://scripts/characters/physique_training_catalog.gd")
const PhysiqueTrainingState := preload("res://scripts/characters/physique_training_state.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const SmasherDashActiveMotionResolver := preload("res://scripts/characters/smasher_dash_active_motion_resolver.gd")
const MythicItemResourceBonusRuntime := preload("res://scripts/items/mythic_item_resource_bonus_runtime.gd")
const TowerTrainingTimingJudgmentPolicy := preload("res://scripts/tower_ascent/tower_training_timing_judgment_policy.gd")

const EXPECTED_MATRIX_CASES := 99
const STORAGE_ID := "physique_storage"
const BASE_DASH_DURATION := 15.0

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
	_verify_source_contracts()
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
		for mastery_spec: Dictionary in mastery_specs:
			for judgment_spec: Dictionary in judgment_specs:
				_matrix_cases += 1
				var runtime := RuntimePerkState.new()
				var mastery_level := int(mastery_spec.get("level", 0))
				if mastery_level > 0:
					runtime.runtime_skill_levels["training_mastery"] = mastery_level
				var effective_mastery := float(mastery_spec.get("multiplier", 1.0))
				if training_id == STORAGE_ID:
					effective_mastery = 1.0
				var expected_front := raw_amount * effective_mastery
				if ceiling > 0.0:
					expected_front = minf(expected_front, ceiling)
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
				_expect(
					is_equal_approx(runtime.get_physique_training_bonus(stat_key), expected_applied),
					"%s applied bonus must equal card front times judgment: expected %.4f got %.4f" % [
						context,
						expected_applied,
						runtime.get_physique_training_bonus(stat_key),
					]
				)
		print("physique_training_display_apply_parity_smoke: row=%s cases=9" % training_id)
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
	for locale: String in LanguageSettings.SUPPORTED_LANGUAGES:
		LanguageSettings.set_test_locale_override(locale)
		var description := str(_catalog.build_card("physique_dash_distance", 0).get("description", ""))
		_expect(
			description.contains(str(expected_labels.get(locale, ""))),
			"%s dash-duration card must use the localized duration label: %s" % [locale, description]
		)
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)


func _verify_dash_judgment_distances() -> void:
	var distances: Array[float] = []
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
		var actual_distance := _simulate_dash_distance(duration)
		_expect(
			is_equal_approx(actual_distance, predicted_distance),
			"%s actual dash %.6f must match the displayed integration %.6f" % [judgment_kind, actual_distance, predicted_distance]
		)
		distances.append(actual_distance)
	_expect(
		distances.size() == 3 and distances[0] < distances[1] and distances[1] < distances[2],
		"dash judgment tiers must produce distinct actual distances: %s" % [distances]
	)
	if distances.size() == 3:
		print("physique_training_display_apply_parity_smoke: dash_distance=%.3f/%.3f/%.3f" % distances)


func _simulate_dash_distance(duration_frames: float) -> float:
	var resolver := SmasherDashActiveMotionResolver.new()
	var position := Vector2.ZERO
	var timer := duration_frames
	var guard := 0
	while timer > 0.0 and guard < 600:
		var result: Dictionary = resolver.update(
			1.0,
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


func _verify_source_contracts() -> void:
	var planner_source := FileAccess.get_file_as_string(
		"res://scripts/characters/physique_training_offer_planner.gd"
	)
	_expect(
		planner_source.contains("float(state.get_applied_count(training_id))"),
		"live offer planner must pass applied_count_before into build_card"
	)
	var economy_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_economy_progress.gd"
	)
	_expect(
		not economy_source.contains("KEY_TRAINING_TIMING_BADGE"),
		"training action producer must keep the retired timing badge banned"
	)
	_expect(
		economy_source.contains("KEY_TRAINING_JUDGMENT_MAX_BADGE"),
		"training action producer must use the new separated judgment badge key"
	)
	_expect(
		not economy_source.contains("choice.get(\"level_text\", \"3/3\")")
		and economy_source.contains("choice.get(\"training_max_count\", 0)"),
		"storage maximum fallback must derive from catalog metadata"
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
