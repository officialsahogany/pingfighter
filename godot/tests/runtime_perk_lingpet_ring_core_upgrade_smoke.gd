extends SceneTree

const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")
const RuntimePerkLingpetRewards := preload("res://scripts/characters/runtime_perk_lingpet_rewards.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const OFFER_SAMPLE_COUNT := 20

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var lingpet_owned_pet_ids: Array = []
	var owned_lingpet_ids: Array = []
	var owned_ringpet_ids: Array = []
	var lingpet_collection: Dictionary = {}
	var ringpet_collection: Dictionary = {}
	var owned_lingpets: Dictionary = {}
	var owned_ringpets: Dictionary = {}
	var lingpet_state := ""
	var lingpet_id := ""
	var selected_character_type := "smasher"


class EmptyCatalog:
	extends RefCounted

	func get_choices(
		_character_type: String,
		_runtime_levels: Dictionary,
		_exclude_instant: bool = false,
		_base_choice_count: int = 3,
		_owner: Object = null,
		_registry: Object = null
	) -> Array:
		return []


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(next_instances: Dictionary) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	_run()


func _run() -> void:
	_verify_ring_core_card_gate_next_tier_and_pick()
	_verify_ring_core_max_and_owned_empty_suppression()
	_verify_ring_core_monotonic_debug_and_icon_contracts()
	_verify_ring_core_run_reset_clears_purchased_tier()
	_verify_ring_core_early_reserve_offer()
	_verify_cooldown_suppresses_force_include_after_upgrade()
	_verify_cooldown_ticks_once_per_presented_choice_screen()
	_verify_non_korean_tier_names_have_no_hangul()

	if _failures.is_empty():
		print("runtime_perk_lingpet_ring_core_upgrade_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_ring_core_card_gate_next_tier_and_pick() -> void:
	# R5 / per-run: the ring-core perk reads/upgrades the RUN tier (real
	# egg_runtime run-state), NOT a fake store. A fake store that "works" used to
	# mask the real R3 store no-op -- that was the false-green this slice broke.
	var catalog := RuntimePerkCatalog.new()
	var perk_state := RuntimePerkState.new()
	var owner := _owned_owner()
	var runtime := LingpetEggRuntime.new()
	runtime._affinity_state.set_run_ring_core_tier(2)
	var registry := FakeRegistry.new({"lingpet_egg_runtime": runtime})
	var choice := _choice_by_id(catalog.get_choices("smasher", {}, true, 200, owner, registry), "lingpet_ring_core_upgrade")
	_expect(not choice.is_empty(), "owned lingpet owner should see the ring-core upgrade card below max tier")
	_expect_eq(int(choice.get("current_tier", -1)), 2, "ring-core card should read the current RUN tier")
	_expect_eq(int(choice.get("next_tier", -1)), 3, "ring-core card should target the next tier only")
	_expect_eq(int(choice.get("next_level", -1)), 3, "ring-core card next_level should mirror next_tier for legacy UI")
	_expect_eq(str(choice.get("icon_id", "")), "lingpet_ring_core_upgrade_tier_3", "ring-core card should resolve the next-tier icon id")

	_expect(perk_state.apply_choice(choice, owner, registry), "ring-core upgrade choice should apply through runtime perk state")
	_expect_eq(runtime.get_run_ring_core_tier(), 3, "ring-core perk pick should upgrade THIS run's tier")
	_expect(not perk_state.runtime_skill_levels.has("lingpet_ring_core_upgrade"), "ring-core upgrade should not write runtime_skill_levels")

	var next_choice := _choice_by_id(catalog.get_choices("smasher", {}, true, 200, owner, registry), "lingpet_ring_core_upgrade")
	_expect_eq(int(next_choice.get("next_tier", -1)), 4, "ring-core card should advance to the next tier after a successful pick")
	_expect_eq(str(next_choice.get("icon_id", "")), "lingpet_ring_core_upgrade_tier_4", "ring-core icon should follow the newly exposed next tier")


func _verify_ring_core_max_and_owned_empty_suppression() -> void:
	var catalog := RuntimePerkCatalog.new()
	var owner := _owned_owner()

	var max_runtime := LingpetEggRuntime.new()
	max_runtime._affinity_state.set_run_ring_core_tier(6)
	var max_registry := FakeRegistry.new({"lingpet_egg_runtime": max_runtime})
	var max_choices := catalog.get_choices("smasher", {}, true, 200, owner, max_registry)
	_expect(_choice_by_id(max_choices, "lingpet_ring_core_upgrade").is_empty(), "max-tier ring core should suppress further upgrade cards")

	var tier2_runtime := LingpetEggRuntime.new()
	tier2_runtime._affinity_state.set_run_ring_core_tier(2)
	var tier2_registry := FakeRegistry.new({"lingpet_egg_runtime": tier2_runtime})
	var empty_owner := FakeOwner.new()
	var empty_choices := catalog.get_choices("smasher", {}, true, 200, empty_owner, tier2_registry)
	_expect(_choice_by_id(empty_choices, "lingpet_ring_core_upgrade").is_empty(), "owned-empty owner should not see ring-core upgrade cards")

	var missing_runtime_choices := catalog.get_choices("smasher", {}, true, 200, owner, FakeRegistry.new({}))
	_expect(_choice_by_id(missing_runtime_choices, "lingpet_ring_core_upgrade").is_empty(), "missing lingpet runtime should not expose a dead ring-core card")


func _verify_ring_core_monotonic_debug_and_icon_contracts() -> void:
	var catalog := RuntimePerkCatalog.new()
	var perk_state := RuntimePerkState.new()
	var owner := _owned_owner()
	var runtime := LingpetEggRuntime.new()
	runtime._affinity_state.set_run_ring_core_tier(3)
	var registry := FakeRegistry.new({"lingpet_egg_runtime": runtime})
	var stale_choice := catalog.get_perk_data("lingpet_ring_core_upgrade")
	stale_choice["next_tier"] = 2
	_expect(not perk_state.apply_choice(stale_choice, owner, registry), "stale lower-tier ring-core choices should not apply")
	_expect_eq(runtime.get_run_ring_core_tier(), 3, "stale lower-tier ring-core choices should not lower the run tier")
	_expect(not perk_state.runtime_skill_levels.has("lingpet_ring_core_upgrade"), "failed ring-core choices should not create runtime_skill_levels state")

	_expect(perk_state.debug_set_perk_level("lingpet_ring_core_upgrade", 5, owner, registry, catalog), "debug setter should recognize the non-level ring-core id")
	_expect_eq(runtime.get_run_ring_core_tier(), 5, "debug setter should route ring-core through the run-state upgrade path")
	_expect(not perk_state.runtime_skill_levels.has("lingpet_ring_core_upgrade"), "debug ring-core upgrade should still avoid runtime_skill_levels")

	var icon_renderer := RuntimePerkIconRenderer.new()
	for tier in range(1, 7):
		var icon_id := "lingpet_ring_core_upgrade_tier_%d" % tier
		_expect(icon_renderer.covered_ids().has(icon_id), "%s should be covered by the runtime perk icon renderer" % icon_id)
		_expect(icon_renderer.has_icon(icon_id), "%s should load a tier-specific PNG icon" % icon_id)

	var catalog_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_catalog.gd")
	_expect(catalog_source.find("_append_lingpet_ring_core_upgrade_choice") >= 0, "catalog should append the dynamic ring-core upgrade card")
	_expect(catalog_source.find("icon_id") >= 0 and catalog_source.find("LINGPET_RING_CORE_ICON_ID_PREFIX") >= 0, "catalog should emit a tier-aware icon id")
	_expect(catalog_source.find("get_run_ring_core_tier()") >= 0, "catalog ring-core card should read the run-state tier, not the permanent store")
	# 배선 소스씰(모듈 분리 구조 — 2026-07-20 씰 갱신): 특수 적용은
	# choice dispatch → action runner 콜백 → state 위임 → rewards 실적용
	# 사슬로 흐르고, generic runtime_skill_levels 레벨업(standard path)은
	# dispatch가 특수 액션을 해석한 뒤에만 도달한다. (구 인라인 분기
	# 소스씰은 rewards 모듈 분리로 이동된 실코드를 못 찾는 낡은 계약.)
	var flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_apply_flow.gd")
	var dispatch_call := flow_source.find("choice_action_runner.run_dispatch(")
	var standard_call := flow_source.find("choice_standard_path.apply_level_choice_to_runtime_state(")
	_expect(dispatch_call >= 0 and standard_call > dispatch_call, "special dispatch must run before the generic standard path (ring-core must never fall into a runtime_skill_levels tally)")
	var dispatch_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_dispatch.gd")
	_expect(dispatch_source.find("ACTION_LINGPET_RING_CORE_UPGRADE") >= 0, "choice dispatch must resolve the ring-core special action")
	var runner_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_action_runner.gd")
	_expect(runner_source.find("Callable(state, \"_apply_lingpet_ring_core_upgrade\")") >= 0, "the action runner must bind the ring-core state callback")
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	_expect(state_source.find("_lingpet_rewards.apply_ring_core_upgrade_from_runtime_state(") >= 0, "state must delegate the ring-core apply to the lingpet rewards module")
	_expect(state_source.find("store.upgrade_ring_core_tier") < 0, "state must not call the dropped permanent store upgrade")
	var rewards_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_lingpet_rewards.gd")
	_expect(rewards_source.find("upgrade_run_ring_core_tier(target_tier") >= 0, "rewards must route through the run-state upgrade")
	_expect(rewards_source.find("store.upgrade_ring_core_tier") < 0, "rewards must not call the dropped permanent store upgrade")
	_expect(rewards_source.find("LingpetRingCoreRules.MAX_RING_CORE_TIER") >= 0, "rewards must clamp against the ring-core rules max tier constant")
	_expect(rewards_source.find("LanguageSettings.get_language() != LanguageSettings.LANGUAGE_KOREAN") >= 0, "rewards must branch tier names on the non-Korean locale")

	# R5 / per-run: localize_perk_data overrides description with PERK_SUMMARY_* for
	# non-KR, so those summaries must NOT still claim a permanent/shared upgrade.
	var lang_source := FileAccess.get_file_as_string("res://scripts/core/language_settings_data.gd")
	_expect(lang_source.find("Permanently upgrades the shared Ring Core") < 0, "non-KR ring-core perk summary must not describe a permanent shared upgrade (EN/ZH/JA/RU)")
	_expect(lang_source.find("permanentemente el Ring Core compartido") < 0, "non-KR ring-core perk summary must not describe a permanent shared upgrade (ES)")
	_expect(lang_source.find("permanentemente o Ring Core compartilhado") < 0, "non-KR ring-core perk summary must not describe a permanent shared upgrade (PT)")


func _verify_ring_core_run_reset_clears_purchased_tier() -> void:
	# R5 / per-run seal: a perk-purchased ring-core tier must not survive a new run.
	var catalog := RuntimePerkCatalog.new()
	var perk_state := RuntimePerkState.new()
	var owner := _owned_owner()
	var runtime := LingpetEggRuntime.new()
	var registry := FakeRegistry.new({"lingpet_egg_runtime": runtime})
	var choice := _choice_by_id(catalog.get_choices("smasher", {}, true, 200, owner, registry), "lingpet_ring_core_upgrade")
	_expect(not choice.is_empty(), "fresh run should still offer the ring-core upgrade card")
	_expect(perk_state.apply_choice(choice, owner, registry), "ring-core perk should apply from a fresh run")
	_expect_eq(runtime.get_run_ring_core_tier(), 1, "ring-core perk should raise the fresh run tier to 1")
	runtime._affinity_state.reset_for_new_run()
	_expect_eq(runtime.get_run_ring_core_tier(), 0, "a new run should reset the perk-purchased ring-core tier to 0")


func _verify_ring_core_early_reserve_offer() -> void:
	var catalog := RuntimePerkCatalog.new()
	for tier in [0, 1, 2]:
		_expect_eq(catalog._get_lingpet_ring_core_early_reserve_count(tier), 1, "ring-core early reserve should be active through tier %d" % tier)
	for tier in [3, 4, 5, 6]:
		_expect_eq(catalog._get_lingpet_ring_core_early_reserve_count(tier), 0, "ring-core early reserve should taper off at tier %d" % tier)

	var owner := _owned_owner()
	var runtime := LingpetEggRuntime.new()
	var registry := FakeRegistry.new({"lingpet_egg_runtime": runtime})
	_expect_eq(_ring_core_hits_in_target3_samples(catalog, owner, registry, 41000), OFFER_SAMPLE_COUNT, "tier 0 should force-include T1 in every 3-card early offer")
	var tier0_choice := _choice_by_id(catalog.get_choices("smasher", {}, true, 3, owner, registry), "lingpet_ring_core_upgrade")
	_expect(not tier0_choice.has("_lingpet_ring_core_reserved"), "ring-core reservation marker should not leak to UI choices")

	var tier1_result: Dictionary = runtime.upgrade_run_ring_core_tier(1, owner, registry)
	_expect(bool(tier1_result.get("accepted", false)), "ring-core cooldown fixture should raise to tier 1")
	_drain_ring_core_offer_cooldown(runtime)
	_expect_eq(runtime.get_ring_core_offer_cooldown_screens(), 0, "drained tier-1 cooldown fixture should reach zero")
	_expect_eq(_ring_core_hits_in_target3_samples(catalog, owner, registry, 42000), OFFER_SAMPLE_COUNT, "tier 1 with cooldown 0 should force-include T2 in every 3-card early offer")

	var tier2_result: Dictionary = runtime.upgrade_run_ring_core_tier(2, owner, registry)
	_expect(bool(tier2_result.get("accepted", false)), "ring-core cooldown fixture should raise to tier 2")
	_drain_ring_core_offer_cooldown(runtime)
	_expect_eq(runtime.get_ring_core_offer_cooldown_screens(), 0, "drained tier-2 cooldown fixture should reach zero")
	_expect_eq(_ring_core_hits_in_target3_samples(catalog, owner, registry, 43000), OFFER_SAMPLE_COUNT, "tier 2 with cooldown 0 should force-include T3 in every 3-card early offer")

	var split: Dictionary = catalog._extract_lingpet_ring_core_reserved_choices([
		{"id": "dash_module_control"},
		{"id": "lingpet_ring_core_upgrade", "_lingpet_ring_core_reserved": true},
		{"id": "lingpet_affinity_chip", "_lingpet_ring_core_reserved": true},
	], 3)
	var reserved: Array = split.get("reserved", []) as Array
	var remaining: Array = split.get("remaining", []) as Array
	_expect_eq(reserved.size(), 1, "reserved extractor should reserve only the ring-core card")
	if reserved.size() == 1:
		var reserved_choice: Dictionary = reserved[0] as Dictionary
		_expect_eq(str(reserved_choice.get("id", "")), "lingpet_ring_core_upgrade", "reserved extractor should preserve the ring-core id")
		_expect(not reserved_choice.has("_lingpet_ring_core_reserved"), "reserved extractor should erase the private ring-core marker")
	var chip_choice := _choice_by_id(remaining, "lingpet_affinity_chip")
	_expect(not chip_choice.has("_lingpet_ring_core_reserved"), "reserved extractor should erase stray markers from non-ring-core choices")

	var catalog_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_catalog.gd")
	_expect(catalog_source.find("LINGPET_RING_CORE_EARLY_RESERVE_BY_TIER := [1, 1, 1, 0, 0, 0, 0]") >= 0, "catalog should lock the selected tier 0-2 early reserve tuning")
	_expect(catalog_source.find("_extract_lingpet_ring_core_reserved_choices") >= 0, "catalog should split reserved ring-core cards before shuffle/truncation")
	_expect(catalog_source.find("LINGPET_RING_CORE_PRIORITY_KEY") >= 0, "catalog should use a named private reservation marker")
	_expect(catalog_source.find("_get_lingpet_ring_core_offer_cooldown(registry) <= 0") >= 0, "catalog should gate forced ring-core reservation on the cooldown reaching zero")


func _verify_cooldown_suppresses_force_include_after_upgrade() -> void:
	var catalog := RuntimePerkCatalog.new()
	var owner := _owned_owner()
	var runtime := LingpetEggRuntime.new()
	var registry := FakeRegistry.new({"lingpet_egg_runtime": runtime})
	var cooldown := LingpetAffinityState.RING_CORE_OFFER_COOLDOWN_SCREENS
	_expect(cooldown > 0, "ring-core offer cooldown should be a positive screen count")

	for target_tier in [1, 2]:
		var upgrade: Dictionary = runtime.upgrade_run_ring_core_tier(target_tier, owner, registry)
		_expect(bool(upgrade.get("accepted", false)), "ring-core upgrade to tier %d should be accepted for the cooldown fixture" % target_tier)
		_expect_eq(runtime.get_ring_core_offer_cooldown_screens(), cooldown, "ring-core upgrade to tier %d should arm the offer cooldown" % target_tier)
		var immediate_hits := _ring_core_hits_in_target3_samples(catalog, owner, registry, 51000 + target_tier * 100)
		_expect(
			immediate_hits < OFFER_SAMPLE_COUNT,
			"armed cooldown should suppress guaranteed ring-core force-include at tier %d (hit %d/%d samples)" % [target_tier, immediate_hits, OFFER_SAMPLE_COUNT]
		)
		_drain_ring_core_offer_cooldown(runtime)
		_expect_eq(runtime.get_ring_core_offer_cooldown_screens(), 0, "tier %d cooldown should drain back to zero" % target_tier)
		_expect_eq(
			_ring_core_hits_in_target3_samples(catalog, owner, registry, 52000 + target_tier * 100),
			OFFER_SAMPLE_COUNT,
			"drained cooldown should restore guaranteed force-include for the next ring-core tier after tier %d" % target_tier
		)


func _verify_cooldown_ticks_once_per_presented_choice_screen() -> void:
	var catalog := RuntimePerkCatalog.new()
	var owner := _owned_owner()
	var runtime := LingpetEggRuntime.new()
	var registry := FakeRegistry.new({"lingpet_egg_runtime": runtime})
	var cooldown := LingpetAffinityState.RING_CORE_OFFER_COOLDOWN_SCREENS
	var upgrade: Dictionary = runtime.upgrade_run_ring_core_tier(1, owner, registry)
	_expect(bool(upgrade.get("accepted", false)), "modal tick fixture should raise to tier 1")
	_expect_eq(runtime.get_ring_core_offer_cooldown_screens(), cooldown, "modal tick fixture should start armed")

	var empty_state := RuntimePerkState.new()
	empty_state.pending_skill_choices = 1
	empty_state.open_next_choice("smasher", EmptyCatalog.new(), true, owner, registry)
	_expect_eq(runtime.get_ring_core_offer_cooldown_screens(), cooldown, "empty/non-presented choice recursion should not tick the ring-core cooldown")

	var perk_state := RuntimePerkState.new()
	for screen_index in range(cooldown):
		perk_state.pending_skill_choices = 1
		perk_state.choice_active = false
		perk_state.current_choices.clear()
		perk_state.open_next_choice("smasher", catalog, true, owner, registry)
		_expect(perk_state.choice_active, "presented cooldown screen %d should open a real perk modal" % (screen_index + 1))
		_expect_eq(
			runtime.get_ring_core_offer_cooldown_screens(),
			cooldown - screen_index - 1,
			"presented cooldown screen %d should tick the ring-core cooldown exactly once" % (screen_index + 1)
		)


func _owned_owner() -> FakeOwner:
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	return owner


func _choice_by_id(choices: Array, choice_id: String) -> Dictionary:
	for value in choices:
		if value is Dictionary and str((value as Dictionary).get("id", "")) == choice_id:
			return (value as Dictionary).duplicate(true)
	return {}


func _ring_core_hits_in_target3_samples(catalog: Object, owner: Object, registry: Object, seed_base: int) -> int:
	var hits := 0
	for i in range(OFFER_SAMPLE_COUNT):
		seed(seed_base + i)
		var choices: Array = catalog.get_choices("smasher", {}, true, 3, owner, registry)
		if not _choice_by_id(choices, "lingpet_ring_core_upgrade").is_empty():
			hits += 1
	return hits


func _verify_non_korean_tier_names_have_no_hangul() -> void:
	# 설계 권위(2026-07-20): 6티어 유지 — 비한국어 로케일에서 티어명 전부
	# 라틴 표기여야 하며 피드백 문구에 한글이 누출되면 안 된다. 비저장
	# override로 엔진 locale만 고정한다(user:// 무접촉).
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_ENGLISH)
	var rewards: Object = RuntimePerkLingpetRewards.new()
	var expected := ["Standard", "Boost", "Hyper", "Overdrive", "Ultimate", "Zenith"]
	for tier in range(1, 7):
		var tier_name: String = rewards.get_ring_core_tier_name(tier)
		_expect(
			tier_name == expected[tier - 1],
			"non-Korean tier %d name should be %s (got %s)" % [tier, expected[tier - 1], tier_name]
		)
		var feedback: String = rewards.format_ring_core_upgrade_feedback("Ring Core", tier_name)
		_expect(not _contains_hangul(feedback), "non-Korean feedback must not leak Korean tier names: %s" % feedback)
	LanguageSettings.set_test_locale_override("")


func _contains_hangul(text: String) -> bool:
	for i in range(text.length()):
		var code := text.unicode_at(i)
		if code >= 0xAC00 and code <= 0xD7A3:
			return true
	return false


func _drain_ring_core_offer_cooldown(runtime: Object) -> void:
	for _i in range(LingpetAffinityState.RING_CORE_OFFER_COOLDOWN_SCREENS + 2):
		runtime.tick_ring_core_offer_cooldown()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
