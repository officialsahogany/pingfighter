extends SceneTree

const ActiveItemCooldownComposer := preload("res://scripts/items/active_item_cooldown_composer.gd")
const ActiveItemHudLayout := preload("res://scripts/hud/active_item_hud_layout.gd")
const ActiveItemSlotController := preload("res://scripts/items/active_item_slot_controller.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PhysiqueTrainingCatalog := preload("res://scripts/characters/physique_training_catalog.gd")
const PhysiqueTrainingOfferPlanner := preload("res://scripts/characters/physique_training_offer_planner.gd")
const PhysiqueTrainingState := preload("res://scripts/characters/physique_training_state.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkChoiceDispatch := preload("res://scripts/characters/runtime_perk_choice_dispatch.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const CharacterInfoOverlayStatsPresenter := preload("res://scripts/hud/character_info_overlay_stats_presenter.gd")
const PerkFusionCatalog := preload("res://scripts/characters/perk_fusion_catalog.gd")
const MythicItemResourceBonusRuntime := preload("res://scripts/items/mythic_item_resource_bonus_runtime.gd")
const MythicItemOwnerSyncer := preload("res://scripts/items/mythic_item_owner_syncer.gd")
const MythicItemDefenseGearRuntime := preload("res://scripts/items/mythic_item_defense_gear_runtime.gd")
const MythicItemCooldownGearRuntime := preload("res://scripts/items/mythic_item_cooldown_gear_runtime.gd")
const PlayerMovementState := preload("res://scripts/characters/player_movement_state.gd")
const StatusEffectState := preload("res://scripts/status/status_effect_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	var original_language := LanguageSettings.get_language()
	PerkConversionFlags.debug_set_enabled(true)
	_verify_catalog_and_acquisition_rules()
	_verify_effective_ceilings()
	_verify_legacy_compat_saturation()
	_verify_offer_planner()
	_verify_runtime_auxiliary_exclusivity()
	_verify_offer_retirement_and_compatibility()
	_verify_dispatch_and_stat_queries()
	_verify_character_info_source_attribution()
	_verify_save_reset_and_localization()
	PerkConversionFlags.debug_set_enabled(false)
	_verify_flag_off_isolation()
	LanguageSettings.set_test_locale_override(original_language)
	LanguageSettings.set_test_locale_override("")
	if _failures.is_empty():
		print("physique_training_category_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_catalog_and_acquisition_rules() -> void:
	var catalog := PhysiqueTrainingCatalog.new()
	_expect(not RuntimePerkState.DEBUG_PHYSIQUE_TRAINING_OFFER_LOG, "shipping defaults must keep Physique Training offer telemetry silent")
	_expect(PhysiqueTrainingCatalog.TRAINING_IDS.size() == 11, "training catalog should contain eleven cards")
	_expect(is_equal_approx(catalog.get_amount("physique_dash_recharge"), 4.0), "dash recharge training should grant 4 percent")
	_expect(is_equal_approx(catalog.get_amount("physique_dash_recovery"), 6.0), "dash recovery training should grant 6 percent")
	_expect(is_equal_approx(catalog.get_amount("physique_dash_distance"), 5.0), "dash distance training should grant 5 percent")
	_expect(is_equal_approx(catalog.get_amount("physique_move_speed"), 4.0), "move speed training should grant 4 percent")
	_expect(is_equal_approx(catalog.get_amount("physique_posture"), 5.0), "posture training should grant 5 percent")
	_expect(is_equal_approx(catalog.get_amount("physique_paddle_size"), 2.0), "paddle training should grant 2 percent")
	_expect(is_equal_approx(catalog.get_amount("physique_max_gauge"), 30.0), "max-vigor training should grant 30 flat")
	_expect(is_equal_approx(catalog.get_amount("physique_hit_gauge"), 7.0), "hit-vigor training should grant 7 percent")
	_expect(is_equal_approx(catalog.get_amount("physique_active_item_cooldown"), 7.0), "cooldown training should grant 7 percent")
	_expect(is_equal_approx(catalog.get_amount("physique_chosik_cooldown"), 3.0), "Chosik cooldown training should grant 3 percent")
	_expect(is_equal_approx(catalog.get_amount("physique_storage"), 1.0), "storage training should stay at one slot")
	# 상한제 폐지(2026-08-08): 능력치별 상한도 런 전체 상한도 없다. 수납술만 5회 한정.
	for training_id: String in PhysiqueTrainingCatalog.TRAINING_IDS:
		if training_id == "physique_storage":
			continue
		_expect(
			catalog.get_max_count(training_id) == PhysiqueTrainingCatalog.UNLIMITED_COUNT,
			"%s should carry no acquisition cap" % training_id
		)
		_expect(catalog.is_unlimited(training_id), "%s should report itself as unlimited" % training_id)
	_expect(catalog.get_max_count("physique_storage") == 5, "storage training should remain the only capped entry, extended to five")
	_expect(not catalog.is_unlimited("physique_storage"), "storage training must stay capped")
	var state := PhysiqueTrainingState.new()
	for _index: int in range(12):
		_expect(
			bool(state.commit("physique_dash_recharge", catalog).get("accepted", false)),
			"an unlimited training should accept repeats past the retired per-stat cap"
		)
	_expect(state.get_count("physique_dash_recharge") == 12, "repeat acquisitions should accumulate without a cap")
	_expect(
		bool(state.commit("physique_move_speed", catalog).get("accepted", false)),
		"the retired run-total cap must not block a further training"
	)
	_expect(bool(state.can_acquire_any(catalog)), "unlimited trainings should stay offerable at any acquisition count")
	# 누적 표기가 상한 클램프에 접히지 않는지 — max_count(-1)을 그대로 clamp 하면 카드가
	# "0% 감소"로 읽히면서도 상태 단언은 전부 통과한다.
	var deep_card := catalog.build_card("physique_dash_recharge", 12)
	_expect(int(deep_card.get("training_count_after", 0)) == 13, "an unlimited card should keep counting past the retired cap")
	_expect(
		str(deep_card.get("description", "")).contains("52%"),
		"an unlimited card should state the full accumulated value, got '%s'" % str(deep_card.get("description", ""))
	)
	var storage_state := PhysiqueTrainingState.new()
	for _index: int in range(5):
		_expect(bool(storage_state.commit("physique_storage", catalog).get("accepted", false)), "storage should accept five acquisitions")
	_expect(not bool(storage_state.commit("physique_storage", catalog).get("accepted", true)), "storage should reject its sixth acquisition")
	_expect(not bool(storage_state.can_acquire("physique_storage", catalog)), "storage should report itself exhausted at five")
	_expect(is_equal_approx(storage_state.get_bonus("active_item_slot_bonus", catalog), 5.0), "five storage acquisitions should grant five slots")
	var restored_deep := PhysiqueTrainingState.new()
	restored_deep.restore({"acquired_counts": {"physique_dash_recharge": 12, "physique_storage": 5}}, catalog)
	_expect(restored_deep.get_count("physique_dash_recharge") == 12, "restore should preserve an uncapped acquisition count")
	_expect(restored_deep.get_count("physique_storage") == 5, "restore should preserve the new capped storage entry")


# 상한제 폐지의 뒷면: 소비자가 포화한 뒤의 습득은 죽은 카드다. 천장 도달 시 후보 제외 +
# 표기·실효값 클램프를 봉인한다(정본 §2.3).
func _verify_effective_ceilings() -> void:
	var catalog := PhysiqueTrainingCatalog.new()
	_expect(is_equal_approx(catalog.get_effective_ceiling("physique_active_item_cooldown"), 95.0), "cooldown ceiling should match the composer's 5 percent floor")
	_expect(is_equal_approx(catalog.get_effective_ceiling("physique_chosik_cooldown"), 95.0), "Chosik cooldown ceiling should match the final 5 percent floor")
	_expect(is_equal_approx(catalog.get_effective_ceiling("physique_dash_recharge"), 100.0), "dash recharge ceiling should be full reduction")
	_expect(is_equal_approx(catalog.get_effective_ceiling("physique_dash_recovery"), 100.0), "dash recovery ceiling should be full reduction")
	_expect(is_equal_approx(catalog.get_effective_ceiling("physique_posture"), 100.0), "posture ceiling should match the consumer clamp")
	for unbounded_id: String in ["physique_move_speed", "physique_paddle_size", "physique_max_gauge", "physique_hit_gauge", "physique_dash_distance"]:
		_expect(is_equal_approx(catalog.get_effective_ceiling(unbounded_id), 0.0), "%s should declare no ceiling" % unbounded_id)
	# 순환결 −7%/회: 13회 = 91%(유효) → 14회차는 91→95로 아직 개선 → 15회차가 죽은 카드.
	var cooldown_state := PhysiqueTrainingState.new()
	for _index: int in range(13):
		cooldown_state.commit("physique_active_item_cooldown", catalog)
	_expect(bool(cooldown_state.can_acquire("physique_active_item_cooldown", catalog)), "the last improving acquisition must stay offerable")
	_expect(bool(cooldown_state.commit("physique_active_item_cooldown", catalog).get("accepted", false)), "the last improving acquisition should commit")
	_expect(not bool(cooldown_state.can_acquire("physique_active_item_cooldown", catalog)), "a saturated training must leave the candidate pool")
	_expect(not bool(cooldown_state.commit("physique_active_item_cooldown", catalog).get("accepted", true)), "a saturated training must not commit a dead acquisition")
	_expect(is_equal_approx(cooldown_state.get_bonus("active_item_cooldown_reduction_pct", catalog), 95.0), "the applied bonus should clamp to the effective ceiling")
	var saturated_card := catalog.build_card("physique_active_item_cooldown", 14)
	_expect(str(saturated_card.get("description", "")).contains("95%"), "a saturated card must advertise the effective value, got '%s'" % str(saturated_card.get("description", "")))
	_expect(not str(saturated_card.get("description", "")).contains("105%"), "a saturated card must not advertise an impossible reduction")
	# 실경로 왕복: 천장이 곧 실제 포화 지점인지 소비자 출력으로 확인한다.
	var live_cooldown := RuntimePerkState.new()
	for _index: int in range(14):
		live_cooldown._apply_physique_training_choice(catalog.build_card("physique_active_item_cooldown", _index), null, null)
	_expect(live_cooldown.get_active_item_cooldown_msec(1000) == 50, "a saturated cooldown training should land exactly on the 5 percent floor")
	# 조식심법 수련 −3%/회: 31회 = 93%(유효) → 32회차가 95% 최종 하한에 닿는다.
	var chosik_state := RuntimePerkState.new()
	for index: int in range(31):
		chosik_state._apply_physique_training_choice(catalog.build_card("physique_chosik_cooldown", index), null, null)
	_expect(not chosik_state.is_physique_training_saturated("physique_chosik_cooldown"), "the thirty-second Chosik cooldown training should remain improving")
	_expect(chosik_state._apply_physique_training_choice(catalog.build_card("physique_chosik_cooldown", 31), null, null), "the thirty-second Chosik cooldown training should commit")
	_expect(is_equal_approx(chosik_state.get_player_skill_cooldown_multiplier(), 0.05), "thirty-two Chosik trainings should reach the 5 percent multiplier")
	_expect(chosik_state.is_physique_training_saturated("physique_chosik_cooldown"), "Chosik cooldown training should saturate at the final floor")
	_expect(not chosik_state._apply_physique_training_choice(catalog.build_card("physique_chosik_cooldown", 32), null, null), "a dead thirty-third Chosik training must be rejected")
	var live_recharge := RuntimePerkState.new()
	for _index: int in range(25):
		live_recharge._apply_physique_training_choice(catalog.build_card("physique_dash_recharge", _index), null, null)
	_expect(is_equal_approx(live_recharge.get_dash_recharge_frames(300.0), 6.0), "full-reduction training should land on the shipped recharge frame floor")
	_expect(
		not live_recharge._apply_physique_training_choice(catalog.build_card("physique_dash_recharge", 25), null, null),
		"a saturated training must be rejected on the real choice path, not only by the offer gate"
	)
	_expect(live_recharge.get_physique_training_count("physique_dash_recharge") == 25, "a rejected dead acquisition must not increment the count")
	var posture_state := PhysiqueTrainingState.new()
	for _index: int in range(20):
		posture_state.commit("physique_posture", catalog)
	_expect(not bool(posture_state.can_acquire("physique_posture", catalog)), "posture training should saturate at the consumer clamp")
	_expect(is_equal_approx(posture_state.get_bonus("posture_correction_pct", catalog), 100.0), "posture bonus should stop at 100 percent")
	# 천장 게이트가 무한 성장 계열을 과잉 차단하지 않는지(대조군).
	var move_state := PhysiqueTrainingState.new()
	for _index: int in range(30):
		move_state.commit("physique_move_speed", catalog)
	_expect(bool(move_state.can_acquire("physique_move_speed", catalog)), "ceiling-free trainings must never be gated out")
	_expect(is_equal_approx(move_state.get_bonus("move_speed_bonus_pct", catalog), 120.0), "ceiling-free bonus should keep accumulating")


# 재리뷰 P1: 카탈로그 고정 천장은 수련 누적치만 본다 — 기보유 이관 무공과 합성되는
# 호환 런은 천장 **전에** 포화하므로 기존 네 계열을 혼합 레그로 봉인한다. 각 계열마다
# ①마지막 개선 습득은 여전히 자격 있음 ②그 다음은 포화(오퍼 후보 제외 + 실적용 거절)
# ③수련 단독 대조군은 같은 횟수에서 아직 포화 아님(프로브가 횟수가 아니라 실제 결과를
# 보는지) 세 방향을 함께 확인한다.
func _verify_legacy_compat_saturation() -> void:
	var catalog := PhysiqueTrainingCatalog.new()
	var planner := PhysiqueTrainingOfferPlanner.new()
	var cases: Array = [
		{
			"training_id": "physique_active_item_cooldown",
			"legacy_perk": "item_cooldown_mastery",
			"last_improving_count": 13,
			"label": "순환결 + 순환결 무공 Lv.5 (쿨타임 5% 하한)",
		},
		{
			"training_id": "physique_dash_recovery",
			"legacy_perk": "dash_module_control",
			"last_improving_count": 13,
			"label": "수세결 + 수세결 무공 Lv.5 (후딜 1프레임 하한)",
		},
		{
			"training_id": "physique_dash_recharge",
			"legacy_perk": "dash_lightweight",
			"last_improving_count": 24,
			"label": "회기보 + 회기보 무공 Lv.5 (재충전 6프레임 하한)",
		},
		{
			"training_id": "physique_posture",
			"legacy_perk": "bulletproof_hat",
			"last_improving_count": 16,
			"label": "철심공 + 철심공 무공 Lv.5 (자세 보정 100% clamp)",
		},
	]
	for case_value: Variant in cases:
		var case: Dictionary = case_value as Dictionary
		var training_id := str(case.get("training_id", ""))
		var last_improving_count := int(case.get("last_improving_count", 0))
		var label := str(case.get("label", ""))
		var compat := RuntimePerkState.new()
		compat.runtime_skill_levels[str(case.get("legacy_perk", ""))] = 5
		for index: int in range(last_improving_count - 1):
			_expect(
				compat._apply_physique_training_choice(catalog.build_card(training_id, index), null, null),
				"%s: acquisition %d should still change the outcome" % [label, index + 1]
			)
		_expect(
			not compat.is_physique_training_saturated(training_id),
			"%s: the last improving acquisition must stay eligible" % label
		)
		_expect(
			compat._apply_physique_training_choice(catalog.build_card(training_id, last_improving_count - 1), null, null),
			"%s: the last improving acquisition should commit" % label
		)
		_expect(
			compat.is_physique_training_saturated(training_id),
			"%s: a compat run must saturate before the training-only ceiling" % label
		)
		_expect(
			not compat._apply_physique_training_choice(catalog.build_card(training_id, last_improving_count), null, null),
			"%s: the dead acquisition must be rejected on the real apply path" % label
		)
		_expect(
			compat.get_physique_training_count(training_id) == last_improving_count,
			"%s: the rejected dead acquisition must not increment the count" % label
		)
		# 오퍼 경로: 포화된 수련은 후보에서 사라진다(프로브를 planner 에 전달).
		var candidates := planner.build_candidates(
			compat._physique_training_state,
			catalog,
			compat
		)
		_expect(
			not _ids(candidates).has(training_id),
			"%s: a saturated training must leave the offer candidate pool" % label
		)
		# 대조군: 같은 횟수의 수련 단독 런은 아직 포화가 아니다(횟수 기반 판정 배제).
		var solo := RuntimePerkState.new()
		for index: int in range(last_improving_count):
			solo._apply_physique_training_choice(catalog.build_card(training_id, index), null, null)
		_expect(
			not solo.is_physique_training_saturated(training_id),
			"%s: a training-only run must NOT be saturated at the same count" % label
		)

	# 조식심법은 호환 ID의 기존 8%/레벨 효과를 유지하고, 새 수련 3% 계층과 곱으로
	# 합성한다. 기존 저장을 무효화하거나 새 수련으로 이중 변환하지 않는다.
	var legacy_chosik := RuntimePerkState.new()
	legacy_chosik.runtime_skill_levels["common_training"] = 5
	_expect(is_equal_approx(legacy_chosik.get_player_skill_cooldown_multiplier(), 0.6), "legacy common_training Lv.5 should retain its 40 percent reduction")
	_expect(legacy_chosik._apply_physique_training_choice(catalog.build_card("physique_chosik_cooldown", 0), null, null), "new Chosik training should coexist with a legacy-owned common_training")
	_expect(is_equal_approx(legacy_chosik.get_player_skill_cooldown_multiplier(), 0.582), "legacy and new Chosik cooldown layers should compose multiplicatively")

	# 재리뷰 P1: 중간 게터로 재면 **신화 계층**을 놓친다. 순환결 무공 Lv.5(−65%) +
	# master Lv.5(−12%)는 실제 최종 합성에서 12회차에 이미 하한(50ms)에 닿으므로
	# 13회차가 죽은 카드다. 프로덕션 gear 런타임을 그대로 물려 판정을 재현한다.
	var mythic_state := RuntimePerkState.new()
	mythic_state.runtime_skill_levels["item_cooldown_mastery"] = 5
	mythic_state.runtime_skill_levels["master"] = 5
	var mythic_cooldown_runtime := CooldownMythicRuntime.new()
	mythic_cooldown_runtime.runtime_perk_state_ref = mythic_state
	var mythic_registry := TrainingRegistry.new()
	mythic_registry.instances = {
		"runtime_perk_state": mythic_state,
		"mythic_item_runtime": mythic_cooldown_runtime,
	}
	for index: int in range(12):
		_expect(
			mythic_state._apply_physique_training_choice(catalog.build_card("physique_active_item_cooldown", index), null, null),
			"mythic compat: acquisition %d should commit" % (index + 1)
		)
	_expect(
		mythic_state.is_physique_training_saturated("physique_active_item_cooldown", mythic_registry),
		"the mythic layer must be part of the saturation judgement (master Lv.5 pulls the floor in one acquisition earlier)"
	)
	_expect(
		not mythic_state.is_physique_training_saturated("physique_active_item_cooldown"),
		"the registry-less reduced judgement must stay non-saturated here — that gap is exactly why the registry is threaded"
	)
	_expect(
		ActiveItemCooldownComposer.compose_effective_cooldown_msec(1000, mythic_state, mythic_cooldown_runtime) == 50,
		"the final composed cooldown should already sit on the 5 percent floor at twelve acquisitions"
	)
	_expect(
		not mythic_state._apply_physique_training_choice(catalog.build_card("physique_active_item_cooldown", 12), null, mythic_registry),
		"the dead thirteenth acquisition must be rejected once the registry reveals the mythic layer"
	)
	_expect(
		mythic_state.get_physique_training_count("physique_active_item_cooldown") == 12,
		"the rejected dead acquisition must not increment the count"
	)
	_expect(
		not _ids(planner.build_candidates(
			mythic_state._physique_training_state,
			catalog,
			mythic_state,
			mythic_registry
		)).has("physique_active_item_cooldown"),
		"a mythic-saturated training must leave the offer candidate pool"
	)
	# 마지막 개선 습득(12회차)은 여전히 자격이 있어야 한다 — 11회에서 판정한다.
	var mythic_eleven := RuntimePerkState.new()
	mythic_eleven.runtime_skill_levels["item_cooldown_mastery"] = 5
	mythic_eleven.runtime_skill_levels["master"] = 5
	var eleven_runtime := CooldownMythicRuntime.new()
	eleven_runtime.runtime_perk_state_ref = mythic_eleven
	var eleven_registry := TrainingRegistry.new()
	eleven_registry.instances = {
		"runtime_perk_state": mythic_eleven,
		"mythic_item_runtime": eleven_runtime,
	}
	for index: int in range(11):
		mythic_eleven._apply_physique_training_choice(catalog.build_card("physique_active_item_cooldown", index), null, null)
	_expect(
		not mythic_eleven.is_physique_training_saturated("physique_active_item_cooldown", eleven_registry),
		"the twelfth acquisition still lowers the composed cooldown and must stay eligible"
	)

	# 초식 쿨타임도 신화 아이템 배수까지 합친 최종 5% 하한을 후보 판정에 사용한다.
	var chosik_mythic_state := RuntimePerkState.new()
	for index: int in range(30):
		chosik_mythic_state._apply_physique_training_choice(catalog.build_card("physique_chosik_cooldown", index), null, null)
	var chosik_mythic_registry := TrainingRegistry.new()
	chosik_mythic_registry.instances = {"mythic_item_runtime": SkillCooldownMythicStub.new()}
	_expect(chosik_mythic_state.is_physique_training_saturated("physique_chosik_cooldown", chosik_mythic_registry), "the skill-cooldown saturation probe must include the mythic item multiplier")
	_expect(not chosik_mythic_state.is_physique_training_saturated("physique_chosik_cooldown"), "without the mythic registry, the thirty-first Chosik training should still improve")
	_expect(not chosik_mythic_state._apply_physique_training_choice(catalog.build_card("physique_chosik_cooldown", 30), null, chosik_mythic_registry), "a mythic-saturated Chosik training must be rejected")


func _verify_offer_planner() -> void:
	var catalog := PhysiqueTrainingCatalog.new()
	var state := PhysiqueTrainingState.new()
	var planner := PhysiqueTrainingOfferPlanner.new()
	var choices: Array = [
		{"id": "base_a", "offer_lane": "replaceable", "offer_protected": false},
		{"id": "dowsing_bonus", "offer_lane": "dowsing_bonus", "offer_protected": true},
		{"id": "base_b", "offer_lane": "replaceable", "offer_protected": false},
	]
	_expect(
		is_equal_approx(PhysiqueTrainingOfferPlanner.APPEARANCE_CHANCE, 0.60),
		"training appearance rate should stay at the approved 60 percent"
	)
	var appeared := planner.plan_offer(choices, "battle_starpoint", state, catalog, 0.599999, 0.0, 0.999999)
	var appeared_choices := _choices(appeared)
	_expect(bool(appeared.get("appeared", false)), "rolls below the 60 percent rate should replace one lane with training")
	_expect(appeared_choices.size() == choices.size(), "training replacement should preserve the offer card count")
	_expect(int(appeared.get("replacement_index", -1)) == 2, "replacement roll should target only a replaceable lane")
	_expect(bool((appeared_choices[2] as Dictionary).get("is_physique_training", false)), "the selected replaceable lane should become training")
	_expect(str((appeared_choices[1] as Dictionary).get("id", "")) == "dowsing_bonus", "training must not replace the protected Dowsing lane")
	_expect(not appeared.has("append_index"), "training result should no longer expose the append-era index contract")
	var rejected := planner.plan_offer(choices, "battle_starpoint", state, catalog, 0.60, 0.0, 0.0)
	_expect(bool(rejected.get("rolled", false)) and not bool(rejected.get("appeared", true)), "the 60 percent boundary should reject conventionally")
	var storage := planner.plan_offer(choices, "battle_starpoint", state, catalog, 0.0, 0.96, 0.0)
	_expect(str(storage.get("training_id", "")) == "physique_storage", "storage should occupy its final half-weight interval")
	_expect(is_equal_approx(float((catalog.get_training_data("physique_storage")).get("weight", 0.0)), 0.5), "storage weight should be 0.5")
	# 상한제 폐지 후 "후보 0장"은 런 총량이 아니라 남은 후보가 전부 소진된 경우에만
	# 성립한다 — 상한 있는 항목(수납술 5회)만 남은 카탈로그로 그 경로를 계속 봉인한다.
	var storage_only_catalog := StorageOnlyCatalog.new()
	var exhausted := PhysiqueTrainingState.new()
	for _index: int in range(5):
		_expect(bool(exhausted.commit("physique_storage", storage_only_catalog).get("accepted", false)), "the capped entry should accept its five acquisitions")
	var dead_offer := planner.plan_offer(choices, "battle_starpoint", exhausted, storage_only_catalog, 0.0, 0.0, 0.0)
	_expect(not bool(dead_offer.get("rolled", true)), "a fully exhausted candidate pool should produce no dead training card and consume no roll")
	_expect(_choices(dead_offer) == choices, "an exhausted no-op should preserve the exact offer")
	var protected_choices: Array = [
		{"id": "reserved_a", "offer_lane": "guardian_enhance_reserved", "offer_protected": true},
		{"id": "reserved_b", "offer_lane": "full_chosik_swap_reserved", "offer_protected": true},
	]
	var no_replacement := planner.plan_offer(protected_choices, "battle_starpoint", state, catalog, 0.0, 0.0, 0.0)
	_expect(not bool(no_replacement.get("rolled", true)), "an all-protected offer should no-op before every roll")
	_expect(_choices(no_replacement) == protected_choices, "an all-protected no-op should preserve the exact offer")


func _verify_runtime_auxiliary_exclusivity() -> void:
	var dice_state := RuntimePerkState.new()
	dice_state.current_choices = [{"id": "base", "offer_lane": "replaceable", "offer_protected": false}]
	dice_state.current_choice_context = {"source": "battle_starpoint"}
	var dice_result: Dictionary = dice_state._try_inject_mystic_dice_offer(0.0)
	dice_state._try_inject_physique_training_offer(bool(dice_result.get("appeared", false)), false, 0.0, 0.0, 0.0)
	_expect(_system_auxiliary_count(dice_state.current_choices) == 1, "Mystic Dice appearance should suppress training on the same screen")
	var training_state := RuntimePerkState.new()
	training_state.current_choices = [
		{"id": "base_a", "offer_lane": "replaceable", "offer_protected": false},
		{"id": "base_b", "offer_lane": "replaceable", "offer_protected": false},
		{"id": "base_c", "offer_lane": "replaceable", "offer_protected": false},
	]
	training_state.current_choice_context = {"source": "battle_starpoint"}
	var miss_result: Dictionary = training_state._try_inject_mystic_dice_offer(0.25)
	var original_count := training_state.current_choices.size()
	training_state._try_inject_physique_training_offer(bool(miss_result.get("appeared", false)), false, 0.0, 0.0, 0.0)
	_expect(training_state.current_choices.size() == original_count, "a Dice miss should replace one card without growing the offer")
	_expect(_system_auxiliary_count(training_state.current_choices) == 1, "a Dice miss should allow exactly one training card")
	_expect(_ids(training_state.current_choices).has("physique_dash_recharge"), "the deterministic training interval should replace with its first candidate")

	var fusion_state := RuntimePerkState.new()
	fusion_state.current_choices = training_state.current_choices.duplicate(true)
	fusion_state.current_choice_context = {"source": "battle_starpoint"}
	var metrics_before: Dictionary = fusion_state.get_physique_training_snapshot()
	seed(5521)
	var expected_after_fusion_skip := randf()
	seed(5521)
	var fusion_skip := fusion_state._try_inject_physique_training_offer(false, true)
	var actual_after_fusion_skip := randf()
	var metrics_after: Dictionary = fusion_state.get_physique_training_snapshot()
	_expect(bool(fusion_skip.get("skipped_for_perk_fusion", false)), "a fusion replacement should skip training for the whole screen")
	_expect(metrics_after.get("eligible_screen_count_before_dice_exhaustion", -1) == metrics_before.get("eligible_screen_count_before_dice_exhaustion", -2), "fusion-skip screens should not enter training eligibility metrics")
	_expect(is_equal_approx(actual_after_fusion_skip, expected_after_fusion_skip), "fusion-skip screens should not consume global RNG")

	var protected_state := RuntimePerkState.new()
	protected_state.current_choices = [
		{"id": "reserved", "offer_lane": "boss_vision_reserved", "offer_protected": true},
	]
	protected_state.current_choice_context = {"source": "battle_starpoint"}
	seed(7731)
	var expected_after_noop := randf()
	seed(7731)
	var protected_noop := protected_state._try_inject_physique_training_offer(false, false)
	var actual_after_noop := randf()
	_expect(not bool(protected_noop.get("rolled", true)), "a zero-replaceable runtime offer should no-op")
	_expect(is_equal_approx(actual_after_noop, expected_after_noop), "a zero-replaceable runtime offer should not consume global RNG")


func _verify_offer_retirement_and_compatibility() -> void:
	var catalog := RuntimePerkCatalog.new()
	var general_ids := _ids(catalog.get_debug_perk_entries())
	for retired_id: String in RuntimePerkCatalog.TRAINING_MIGRATED_PERK_IDS.keys():
		_expect(not retired_id in general_ids, "%s should be hidden from the general debug/offer list" % retired_id)
		_expect(not catalog.get_perk_data(retired_id).is_empty(), "%s should remain available by id for compatibility" % retired_id)
	var legacy_ids := _ids(catalog.get_legacy_training_compat_debug_entries())
	_expect(legacy_ids.size() == 10, "legacy compatibility injection should retain all ten migrated Mugong ids")
	_expect("common_training" in legacy_ids, "common_training should remain available only through the compatibility list")
	_expect(not "common_training" in _ids(catalog.get_choices("smasher", {}, true, 500)), "common_training should leave new Mugong offers")
	var fusion_catalog := PerkFusionCatalog.new()
	for retired_id: String in RuntimePerkCatalog.TRAINING_MIGRATED_PERK_IDS.keys():
		var classification: Dictionary = fusion_catalog.classify_perk(retired_id, catalog, 1)
		_expect(bool(classification.get("is_candidate_class", false)), "%s should remain a fusion candidate in an already-owned run" % retired_id)
		_expect(not bool(classification.get("fusion_excluded", true)), "%s must not receive the migration-only fusion exclusion flag" % retired_id)
	for training_id: String in PhysiqueTrainingCatalog.TRAINING_IDS:
		_expect(training_id in general_ids, "%s should appear in the dedicated training debug group" % training_id)
		_expect(not RuntimePerkCatalog.is_slot_consuming_perk(catalog.get_perk_data(training_id)), "training must not consume Mugong slots")
	_expect(not "convert_to_gold" in _ids(catalog.get_choices("smasher", {}, false, 3)), "normal offers should not append gold conversion")
	var legacy_owned := RuntimePerkState.new()
	legacy_owned.runtime_skill_levels["common_swiftness"] = 1
	_expect(legacy_owned.get_player_speed_multiplier() > 1.0, "an already-owned migrated Mugong should keep its runtime effect")


func _verify_dispatch_and_stat_queries() -> void:
	var catalog := PhysiqueTrainingCatalog.new()
	var dispatch := RuntimePerkChoiceDispatch.new().build_dispatch(catalog.build_card("physique_move_speed", 0), false, false)
	_expect(str(dispatch.get("action", "")) == RuntimePerkChoiceDispatch.ACTION_PHYSIQUE_TRAINING, "training cards should use their dedicated dispatch action")
	var debug_state := RuntimePerkState.new()
	_expect(debug_state.debug_set_perk_level("physique_move_speed", 0, null, null, RuntimePerkCatalog.new()), "training debug-group entries should use the preserved choice apply route")
	_expect(debug_state.get_physique_training_count("physique_move_speed") == 1, "a debug training grant should increment its acquisition count")
	var move_state := _state_with_training("physique_move_speed")
	move_state.runtime_skill_levels["item_polish"] = 5
	_expect(is_equal_approx(move_state.get_player_speed_multiplier(), 1.04), "polish should not amplify the 4 percent training bonus")
	var dash_state := _state_with_training("physique_dash_recharge")
	_expect(is_equal_approx(dash_state.get_dash_recharge_frames(100.0), 96.0), "dash recharge training should reduce frames by 4 percent")
	var recovery_state := _state_with_training("physique_dash_recovery")
	_expect(is_equal_approx(recovery_state.get_dash_recovery_frames(100.0), 94.0), "dash recovery training should reduce frames by 6 percent")
	var distance_state := _state_with_training("physique_dash_distance")
	_expect(is_equal_approx(distance_state.get_dash_duration_frames(100.0), 105.0), "dash distance training should increase duration/distance by 5 percent")
	var paddle_state := _state_with_training("physique_paddle_size")
	_expect(is_equal_approx(paddle_state.get_player_paddle_size_multiplier(), 1.02), "paddle training should add 2 percent")
	var live_paddle_state := RuntimePerkState.new()
	var live_paddle_owner := TrainingGaugeOwner.new()
	var live_paddle_registry := TrainingRegistry.new()
	live_paddle_registry.instances = {"runtime_perk_state": live_paddle_state}
	var paddle_center_before: float = live_paddle_owner.player_pos.x + live_paddle_owner.player_paddle_width * 0.5
	var paddle_bottom_before: float = live_paddle_owner.player_pos.y + live_paddle_owner.player_paddle_height
	_expect(
		live_paddle_state.apply_choice(catalog.build_card("physique_paddle_size", 0), live_paddle_owner, live_paddle_registry),
		"paddle training should be accepted through the complete choice path"
	)
	_expect(is_equal_approx(live_paddle_owner.player_paddle_width, 158.1), "paddle training should resize the live paddle width immediately")
	_expect(is_equal_approx(live_paddle_owner.player_paddle_height, 51.0), "paddle training should resize the live paddle height immediately")
	_expect(is_equal_approx(live_paddle_owner.player_pos.x + live_paddle_owner.player_paddle_width * 0.5, paddle_center_before), "paddle training should preserve the live paddle center")
	_expect(is_equal_approx(live_paddle_owner.player_pos.y + live_paddle_owner.player_paddle_height, paddle_bottom_before), "paddle training should preserve the live paddle bottom anchor")
	var gauge_state := _state_with_training("physique_max_gauge")
	_expect(is_equal_approx(gauge_state.get_converted_perk_option_value("fuel_pouch", "fuel_bonus_flat"), 30.0), "max-vigor training should work without owning the retired Mugong")
	_expect(is_equal_approx(MythicItemResourceBonusRuntime.new().get_effective_special_gauge_max(RuntimeBridge.new(gauge_state), 500.0), 530.0), "max-vigor training should reach the production resource consumer")
	var live_gauge_state := RuntimePerkState.new()
	var live_gauge_owner := TrainingGaugeOwner.new()
	var live_gauge_mythic := GaugeTrainingMythicRuntime.new()
	var live_gauge_registry := TrainingRegistry.new()
	live_gauge_registry.instances = {
		"runtime_perk_state": live_gauge_state,
		"mythic_item_runtime": live_gauge_mythic,
	}
	_expect(
		live_gauge_state.apply_choice(catalog.build_card("physique_max_gauge", 0), live_gauge_owner, live_gauge_registry),
		"max-vigor training should be accepted through the complete choice path"
	)
	_expect(live_gauge_mythic.refresh_calls == 1, "training choice should refresh live item-backed stat consumers")
	_expect(is_equal_approx(live_gauge_owner.special_gauge_max, 530.0), "max-vigor training should publish 530 to the live battle owner immediately")
	_expect(is_equal_approx(live_gauge_owner.special_gauge, 265.0), "maximum growth should preserve the owner's current gauge ratio")
	var hit_state := _state_with_training("physique_hit_gauge")
	_expect(is_equal_approx(hit_state.get_converted_perk_option_value("bluetooth_ring", "gauge_gain_pct"), 7.0), "hit-vigor training should add 7 percent")
	var hit_bridge := RuntimeBridge.new(hit_state)
	var hit_resource_runtime := MythicItemResourceBonusRuntime.new()
	_expect(is_equal_approx(hit_resource_runtime.get_bluetooth_ring_gauge_gain_pct(hit_bridge), 7.0), "hit-vigor training should reach the production hit-gauge consumer")
	_expect(is_equal_approx(hit_resource_runtime.calculate_bluetooth_ring_gauge_charge(hit_bridge, 50.0), 53.0), "hit-vigor training should turn a 50-point paddle hit into 53 vigor")
	var posture_state := _state_with_training("physique_posture")
	_expect(is_equal_approx(posture_state.get_converted_perk_option_value("bulletproof_hat", "posture_correction_pct"), 5.0), "posture training should add 5 percent")
	var defense_runtime := MythicItemDefenseGearRuntime.new()
	var posture_bridge := RuntimeBridge.new(posture_state)
	_expect(is_equal_approx(defense_runtime.get_player_stun_resist_pct(posture_bridge), 5.0), "posture training should reach the production stun-resistance consumer")
	_expect(is_equal_approx(defense_runtime.get_player_knockback_resist_pct(posture_bridge), 5.0), "posture training should reach the production knockback-resistance consumer")
	var live_posture_state := RuntimePerkState.new()
	var live_posture_owner := TrainingGaugeOwner.new()
	var live_posture_movement := PlayerMovementState.new()
	var live_posture_status := StatusEffectState.new()
	var live_posture_mythic := PostureTrainingMythicRuntime.new()
	var live_posture_registry := TrainingRegistry.new()
	live_posture_registry.instances = {
		"runtime_perk_state": live_posture_state,
		"mythic_item_runtime": live_posture_mythic,
		"player_movement_state": live_posture_movement,
		"status_effect_state": live_posture_status,
	}
	_expect(
		live_posture_state.apply_choice(catalog.build_card("physique_posture", 0), live_posture_owner, live_posture_registry),
		"posture training should be accepted through the complete choice path"
	)
	_expect(live_posture_mythic.refresh_calls == 1, "posture training should refresh live status consumers")
	_expect(is_equal_approx(live_posture_movement.get_posture_correction_pct(), 5.0), "posture training should update the live knockback-resistance cache immediately")
	_expect(is_equal_approx(live_posture_status.get_player_posture_correction_pct(), 5.0), "posture training should update the live stun-resistance cache immediately")
	var restored_posture_state := RuntimePerkState.new()
	var restored_posture_movement := PlayerMovementState.new()
	var restored_posture_status := StatusEffectState.new()
	var restored_posture_mythic := PostureTrainingMythicRuntime.new()
	var restored_posture_registry := TrainingRegistry.new()
	restored_posture_registry.instances = {
		"runtime_perk_state": restored_posture_state,
		"mythic_item_runtime": restored_posture_mythic,
		"player_movement_state": restored_posture_movement,
		"status_effect_state": restored_posture_status,
	}
	_expect(
		bool(restored_posture_state.apply_unlock_save_snapshot(live_posture_state.build_unlock_save_snapshot(), TrainingGaugeOwner.new(), restored_posture_registry).get("restored", false)),
		"posture training save should restore through the owner-sync path"
	)
	_expect(restored_posture_mythic.refresh_calls == 1, "posture training restore should refresh live status consumers")
	_expect(is_equal_approx(restored_posture_movement.get_posture_correction_pct(), 5.0), "posture training restore should republish knockback resistance")
	_expect(is_equal_approx(restored_posture_status.get_player_posture_correction_pct(), 5.0), "posture training restore should republish stun resistance")
	var storage_state := _state_with_training("physique_storage")
	_expect(storage_state.get_active_item_slot_capacity(3) == 4, "storage training should add one slot through the canonical capacity query")
	var five_storage := RuntimePerkState.new()
	for _index: int in range(5):
		five_storage._apply_physique_training_choice(catalog.build_card("physique_storage", _index), null, null)
	_expect(five_storage.get_active_item_slot_capacity(3) == 8, "five storage acquisitions should raise the canonical capacity from three to eight")
	_expect(
		not five_storage._apply_physique_training_choice(catalog.build_card("physique_storage", 5), null, null),
		"the sixth storage acquisition must be rejected on the complete choice path"
	)
	var slot_registry := TrainingRegistry.new()
	slot_registry.instances = {"runtime_perk_state": five_storage}
	var active_slots: Array = []
	for slot_index: int in range(7):
		active_slots.append({"name": "fixture_%d" % slot_index, "revealed": true})
	var slot_controller := ActiveItemSlotController.new()
	_expect(
		slot_controller.store_active_item({"item_data": {"name": "fixture_8"}}, active_slots, slot_registry, Callable()),
		"the production slot controller should accept the eighth active item"
	)
	_expect(
		not slot_controller.store_active_item({"item_data": {"name": "fixture_9"}}, active_slots, slot_registry, Callable()),
		"the production slot controller should reject a ninth active item"
	)
	var slot_layout: Dictionary = ActiveItemHudLayout.new().build_layout(
		Vector2(760.0, 900.0), Vector2.ZERO, Vector2(760.0, 750.0), 760.0, active_slots.size(), 8
	)
	var slot_rects: Array = slot_layout.get("slot_rects", []) as Array
	_expect(bool(slot_layout.get("visible", false)), "the eight-slot desktop HUD should remain visible")
	_expect(slot_rects.size() == 8, "the production HUD layout should allocate all eight active-item rects")
	_expect(not bool(slot_layout.get("overflow_visible", true)), "eight owned items should fit the eight-slot main box without an overflow lane")
	print("physique_training_category_smoke: storage=5 capacity=8 sixth=rejected slots_rendered=%d ninth_item=rejected" % slot_rects.size())
	var cooldown_state := _state_with_training("physique_active_item_cooldown")
	_expect(cooldown_state.get_active_item_cooldown_msec(1000) == 930, "cooldown training should enter the perk stage at 7 percent")
	_expect(ActiveItemCooldownComposer.compose_effective_cooldown_msec(1000, cooldown_state, FloorBreakingMythic.new()) == 50, "the composer should retain the final 5 percent cooldown floor")
	var chosik_state := _state_with_training("physique_chosik_cooldown")
	_expect(is_equal_approx(chosik_state.get_player_skill_cooldown_multiplier(), 0.97), "one Chosik training should reduce every player-skill cooldown by 3 percent")
	_expect(is_equal_approx(chosik_state.get_player_skill_cooldown_seconds(20.0), 19.4), "the shared cooldown-seconds query should include Chosik training")
	var live_chosik_state := RuntimePerkState.new()
	var live_chosik_owner := TrainingGaugeOwner.new()
	var live_chosik_registry := TrainingRegistry.new()
	var config_probes: Array = []
	live_chosik_registry.instances = {"runtime_perk_state": live_chosik_state}
	for key: String in ["smasher_skill_config", "viper_skill_config", "commando_skill_config", "blacksmith_skill_config", "optimus_skill_config"]:
		var probe := SkillCooldownConfigProbe.new()
		config_probes.append(probe)
		live_chosik_registry.instances[key] = probe
	_expect(live_chosik_state.apply_choice(catalog.build_card("physique_chosik_cooldown", 0), live_chosik_owner, live_chosik_registry), "Chosik training should apply through the complete choice path")
	for probe_value: Variant in config_probes:
		_expect(is_equal_approx((probe_value as SkillCooldownConfigProbe).last_multiplier, 0.97), "Chosik training should sync the 3 percent reduction to every character skill config")


func _verify_character_info_source_attribution() -> void:
	var move_state := _state_with_training("physique_move_speed")
	var move_entries: Array = CharacterInfoOverlayStatsPresenter.move_speed_breakdown(
		"mika",
		null,
		move_state,
		null,
		null,
		null,
		null,
		null,
		null,
		Callable(self, "_neutral_multiplier")
	)
	_expect(is_equal_approx(_ratio_for_label(move_entries, "유운보 수련"), 1.04), "character-info move speed should attribute the 4 percent source to Yuunbo training")

	var hit_state := _state_with_training("physique_hit_gauge")
	var gauge_entries: Array = CharacterInfoOverlayStatsPresenter.gauge_breakdown_from_steps(
		[{"source": "bluetooth_ring", "before": 50.0, "after": 53.5}],
		hit_state,
		null,
		null
	)
	_expect(is_equal_approx(_ratio_for_label(gauge_entries, "격기심법 수련"), 1.07), "character-info hit vigor should split the training source from the compatibility step")

	var storage_state := _state_with_training("physique_storage")
	var slot_entries: Array = CharacterInfoOverlayStatsPresenter.active_item_slot_breakdown(storage_state, null, 3)
	_expect(_text_for_label(slot_entries, "수납술 수련") == "+1", "character-info slot capacity should name the storage-training source")


func _verify_save_reset_and_localization() -> void:
	var state := _state_with_training("physique_move_speed")
	var snapshot: Dictionary = state.build_unlock_save_snapshot() as Dictionary
	var restored := RuntimePerkState.new()
	_expect(bool(restored.apply_unlock_save_snapshot(snapshot).get("restored", false)), "run save should restore training state")
	_expect(restored.get_physique_training_count("physique_move_speed") == 1, "run save should preserve acquisition count")
	restored.reset()
	_expect(restored.get_physique_training_count("physique_move_speed") == 0, "new-run reset should clear training")
	var catalog := PhysiqueTrainingCatalog.new()
	for locale: String in LanguageSettings.SUPPORTED_LANGUAGES:
		LanguageSettings.set_test_locale_override(locale)
		var card := catalog.build_card("physique_dash_recharge", 1)
		_expect(not str(card.get("name", "")).strip_edges().is_empty(), "%s should localize the training name" % locale)
		# 카드 문구 계약(2026-08-24): 앞쪽은 고정 퍼레벨 값, 괄호는 이미 적용된
		# 판정 배율까지 포함한 다음 누적값이다. 첫 수련 전에는 괄호를 생략한다.
		var description := str(card.get("description", ""))
		_expect(not description.contains("→"), "%s should drop the before-to-after machine notation" % locale)
		_expect(description.contains("8%"), "%s should state the accumulated result value" % locale)
		var accumulated_labels := {
			LanguageSettings.LANGUAGE_KOREAN: "누적",
			LanguageSettings.LANGUAGE_ENGLISH: "Total",
			LanguageSettings.LANGUAGE_CHINESE: "累计",
			LanguageSettings.LANGUAGE_JAPANESE: "累計",
			LanguageSettings.LANGUAGE_SPANISH: "Total",
			LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL: "Total",
			LanguageSettings.LANGUAGE_RUSSIAN: "Итог",
		}
		_expect(
			description.contains("(%s " % str(accumulated_labels.get(locale, ""))),
			"%s should localize the accumulated label, got '%s'" % [locale, description]
		)
		if locale == LanguageSettings.LANGUAGE_KOREAN:
			_expect(description == "활주 재충전 시간 4% 감소 (누적 8%)", "korean training accent should separate per-level and accumulated values, got '%s'" % description)
		else:
			_expect(description.contains("-4%") and description.contains("-8%"), "%s should sign both the per-level and accumulated reductions, got '%s'" % [locale, description])
		# 카드 카피 계약(정본 §2.3): 등장 확률·체감률·런 총량 같은 튜닝 상수는
		# 플레이어 카드에 노출하지 않는다 — 설계 문서·계측 로그 전용.
		_expect(not str(card.get("detail", "")).contains("40%"), "%s detail must not expose tuning rates" % locale)
		_expect(not str(card.get("detail", "")).contains("30%"), "%s detail must not expose effective rates" % locale)
		_expect(not str(card.get("detail", "")).strip_edges().is_empty(), "%s should keep a simplified training detail" % locale)
		for tuned_id: String in [
			"physique_paddle_size",
			"physique_dash_recovery",
			"physique_chosik_cooldown",
			"physique_dash_recharge",
		]:
			var tuned_description := str(catalog.build_card(tuned_id, 0).get("description", ""))
			var tuned_amount := int(round(catalog.get_amount(tuned_id)))
			_expect(
				tuned_description.contains("%d%%" % tuned_amount),
				"%s %s card must carry the canonical tuned amount %d%%, got '%s'" % [locale, tuned_id, tuned_amount, tuned_description]
			)
		# 설명문은 10종이 한 문장을 공유하던 "무공 슬롯을 차지하지 않는 기초 수련입니다"
		# 상태에서 항목별 문장으로 갈라졌다. 로케일 맵(PERK_SUMMARY_*)까지 항목별로
		# 채워졌는지 검사하지 않으면 한국어만 갈라지고 나머지가 공용 문장으로 남는다.
		var other_detail := str(catalog.build_card("physique_paddle_size", 0).get("detail", ""))
		_expect(
			other_detail != str(card.get("detail", "")),
			"%s must give each training its own detail sentence, both read '%s'" % [locale, other_detail]
		)
		var chosik_card := catalog.build_card("physique_chosik_cooldown", 0)
		_expect(not str(chosik_card.get("name", "")).strip_edges().is_empty(), "%s should localize the Chosik training name" % locale)
		_expect(not str(chosik_card.get("detail", "")).strip_edges().is_empty(), "%s should localize the Chosik training detail" % locale)
		if locale == LanguageSettings.LANGUAGE_KOREAN:
			_expect(str(chosik_card.get("name", "")) == "조식심법 수련", "the Korean Chosik training name should preserve the retired art's identity")
			_expect(str(chosik_card.get("description", "")) == "초식 쿨타임 3% 감소", "the Korean Chosik training effect line should state the approved 3 percent reduction")
		else:
			_expect(str(chosik_card.get("description", "")).contains("-3%"), "%s should localize the Chosik reduction label and retain -3%%" % locale)
			_expect(not str(chosik_card.get("description", "")).contains("초식 쿨타임"), "%s should not leak the Korean Chosik label" % locale)
		_expect(not str(chosik_card.get("description", "")).contains("("), "%s first training card must omit an empty accumulation suffix" % locale)


func _verify_flag_off_isolation() -> void:
	var catalog := RuntimePerkCatalog.new()
	var debug_ids := _ids(catalog.get_debug_perk_entries())
	_expect(not "physique_move_speed" in debug_ids, "flag-OFF debug picker should not expose training")
	var unlock_registry := UnlockAllRegistry.new()
	_expect("common_swiftness" in _ids(catalog.get_choices("smasher", {}, true, 500, null, unlock_registry)), "flag-OFF offers should retain the legacy Mugong")
	_expect("common_training" in _ids(catalog.get_choices("smasher", {}, true, 500, null, unlock_registry)), "flag-OFF offers should retain legacy common_training")
	var state := RuntimePerkState.new()
	state.restore_physique_training_snapshot({"acquired_counts": {"physique_move_speed": 1}})
	_expect(is_equal_approx(state.get_player_speed_multiplier(), 1.0), "flag-OFF runtime queries should ignore stored training")
	state.runtime_skill_levels["common_training"] = 1
	_expect(is_equal_approx(state.get_player_skill_cooldown_multiplier(), 0.92), "flag-OFF compatibility should preserve legacy common_training's 8 percent reduction")
	state.current_choices = [{"id": "base"}]
	state.current_choice_context = {"source": "battle_starpoint"}
	_expect(not bool(state._try_inject_physique_training_offer(false, false, 0.0, 0.0, 0.0).get("rolled", true)), "flag-OFF runtime should not replace a choice with training")


func _state_with_training(training_id: String) -> Object:
	var state := RuntimePerkState.new()
	var card := PhysiqueTrainingCatalog.new().build_card(training_id, 0)
	_expect(state._apply_physique_training_choice(card, null, null), "%s should commit through the choice action" % training_id)
	return state


func _neutral_multiplier(_source: Object, _method_name: String) -> float:
	return 1.0


func _ratio_for_label(entries: Array, label: String) -> float:
	for value: Variant in entries:
		if value is Dictionary and str((value as Dictionary).get("label", "")) == label:
			return float((value as Dictionary).get("ratio", 1.0))
	return 1.0


func _text_for_label(entries: Array, label: String) -> String:
	for value: Variant in entries:
		if value is Dictionary and str((value as Dictionary).get("label", "")) == label:
			return str((value as Dictionary).get("text", ""))
	return ""


func _choices(result: Dictionary) -> Array:
	var value: Variant = result.get("choices", [])
	return value as Array if value is Array else []


func _ids(entries: Array) -> Array[String]:
	var result: Array[String] = []
	for entry_value: Variant in entries:
		if entry_value is Dictionary:
			result.append(str((entry_value as Dictionary).get("id", "")))
	return result


func _system_auxiliary_count(choices: Array) -> int:
	var count := 0
	for choice_value: Variant in choices:
		if not choice_value is Dictionary:
			continue
		var choice := choice_value as Dictionary
		if bool(choice.get("is_mystic_dice", false)) or bool(choice.get("is_physique_training", false)):
			count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


# 신화 계층 판정용 최소 셸. 쿨타임 수학은 프로덕션 `MythicItemCooldownGearRuntime`을
# 그대로 쓰고(가짜 수식 금지), 그 런타임이 요구하는 표면만 채운다:
# `get_converted_perk_effect_level`(master 레벨 조회) + `roll_query`(쿨타임 장비 경로는
# flag 분기가 없어 항상 roll_query 를 탄다 — 없으면 nil 접근으로 죽는다).
class CooldownRollQueryStub:
	extends RefCounted

	func get_equipped_roll_sum(_runtime: Object, _item_name: String, _key: String) -> float:
		return 0.0

	func has_equipped_item_name(_runtime: Object, _item_name: String) -> bool:
		return false


class CooldownMythicRuntime:
	extends RefCounted

	var runtime_perk_state_ref: Object = null
	var roll_query := CooldownRollQueryStub.new()
	var _gear := MythicItemCooldownGearRuntime.new()

	func get_converted_perk_effect_level(perk_id: String) -> int:
		if runtime_perk_state_ref == null:
			return 0
		return int(runtime_perk_state_ref.get_converted_perk_effect_level(perk_id))

	func get_active_item_cooldown_msec(base_cooldown_msec: int) -> int:
		return int(_gear.get_active_item_cooldown_msec(self, base_cooldown_msec))


class FloorBreakingMythic:
	extends RefCounted

	func get_active_item_cooldown_msec(_base_cooldown_msec: int) -> int:
		return 1


class SkillCooldownMythicStub:
	extends RefCounted

	func get_player_skill_cooldown_multiplier() -> float:
		return 0.5


# 상한제 폐지 후 "후보 0장 → 완전 no-op" 경로를 봉인하기 위한 카탈로그 스텁.
# 상한 있는 항목(수납술 5회)만 노출하므로 그 상한을 채우면 후보가 실제로 비게 된다.
class StorageOnlyCatalog:
	extends RefCounted

	const CAPPED_ID := "physique_storage"

	var _inner := PhysiqueTrainingCatalog.new()

	func has_training(training_id: String) -> bool:
		return training_id.strip_edges() == CAPPED_ID

	func get_max_count(training_id: String) -> int:
		return _inner.get_max_count(training_id)

	func get_amount(training_id: String) -> float:
		return _inner.get_amount(training_id)

	func get_effective_ceiling(training_id: String) -> float:
		return _inner.get_effective_ceiling(training_id)

	func get_all_training_data() -> Array:
		return [_inner.get_training_data(CAPPED_ID)]

	func build_card(training_id: String, acquired_count: int, training_multiplier: float = 1.0) -> Dictionary:
		return _inner.build_card(training_id, acquired_count, training_multiplier)


class UnlockAllRegistry:
	extends RefCounted

	var _store := UnlockAllStore.new()

	func get_instance(key: String) -> Object:
		return _store if key == "tower_ascent_unlock_store" else null


class UnlockAllStore:
	extends RefCounted

	func is_unlocked(_content_type: String, _content_id: String) -> bool:
		return true


class RuntimeBridge:
	extends RefCounted

	var runtime_perk_state_ref: Object

	func _init(state: Object) -> void:
		runtime_perk_state_ref = state


class TrainingGaugeOwner:
	extends RefCounted

	var runtime_perk_effective_levels: Dictionary = {}
	var runtime_accessory_slot_bonus := 0
	var runtime_laurel_leaf_count := 0
	var runtime_paddle_scale := 1.0
	var runtime_paddle_base_width := 155.0
	var runtime_paddle_base_height := 50.0
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var player_paddle_scale := 1.0
	var player_pos := Vector2(302.5, 700.0)
	var special_gauge := 250.0
	var special_gauge_max := 500.0


class SkillCooldownConfigProbe:
	extends RefCounted

	var last_multiplier := 1.0

	func set_runtime_cooldown_multiplier(value: float) -> void:
		last_multiplier = value


class TrainingRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class GaugeTrainingMythicRuntime:
	extends RefCounted

	var runtime_perk_state_ref: Object = null
	var synced_special_gauge_max := 500.0
	var synced_special_gauge_unblessed_max := 500.0
	var synced_angel_gauge_multiplier := 1.0
	var refresh_calls := 0
	var _resource_bonus := MythicItemResourceBonusRuntime.new()
	var _owner_syncer := MythicItemOwnerSyncer.new()

	func refresh_runtime_perk_scaling(owner: Object, registry: Object) -> void:
		refresh_calls += 1
		runtime_perk_state_ref = registry.get_instance("runtime_perk_state") if registry != null else null
		_owner_syncer.sync_fuel_pouch_gauge_max(self, owner, {"base_special_gauge_max": 500.0})

	func get_effective_special_gauge_max(base_max: float) -> float:
		return _resource_bonus.get_effective_special_gauge_max(self, base_max)

	func _safe_owner_get(owner: Object, key: String, fallback: Variant) -> Variant:
		var value: Variant = owner.get(key) if owner != null else null
		return fallback if value == null else value


class PostureTrainingMythicRuntime:
	extends RefCounted

	var runtime_perk_state_ref: Object = null
	var refresh_calls := 0
	var _defense_runtime := MythicItemDefenseGearRuntime.new()
	var _owner_syncer := MythicItemOwnerSyncer.new()

	func refresh_runtime_perk_scaling(_owner: Object, registry: Object) -> void:
		refresh_calls += 1
		runtime_perk_state_ref = registry.get_instance("runtime_perk_state") if registry != null else null
		_owner_syncer.sync_player_status_resistance_to_movement(self, registry)

	func get_player_stun_resist_pct() -> float:
		return _defense_runtime.get_player_stun_resist_pct(self)

	func get_player_knockback_resist_pct() -> float:
		return _defense_runtime.get_player_knockback_resist_pct(self)

	func _get_instance(registry: Object, key: String) -> Object:
		return registry.get_instance(key) if registry != null else null
