extends SceneTree
# expect-zero-object-leaks — run_smoke_tests.ps1이 종료 시 ObjectDB 누수
# 경고를 실패로 간주한다(FakeOwner 등 Node 프로브는 레그마다 free 필수).

const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const MythicPerkGrantHelper := preload("res://scripts/characters/mythic_perk_grant_helper.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkEffectiveLevels := preload("res://scripts/characters/runtime_perk_effective_levels.gd")
const CharacterInfoOverlayOwnerState := preload("res://scripts/hud/character_info_overlay_owner_state.gd")
const MythicItemEquipmentIndex := preload("res://scripts/items/mythic_item_equipment_index.gd")
const LanguageSettingsData := preload("res://scripts/core/language_settings_data.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

const OFFER_SCAN_COUNT := 500
const CAPTURE_PATH := "res://../.tmp/perk_slot_limit/perk_slot_limit_choice_modal.png"

var _failures: Array[String] = []
var _language_settings_snapshot: Dictionary = {}


class AccessoryProbeOwner:
	extends RefCounted

	var accessory_slot_count := 0
	var runtime_accessory_slot_bonus := 0
	var runtime_perk_levels := {"common_expansion": 2}


class AccessoryProbeRuntime:
	extends RefCounted

	func _safe_owner_get(owner: Object, key: String, fallback: Variant) -> Variant:
		var value: Variant = owner.get(key)
		return fallback if value == null else value

	func _get_dict(value: Variant) -> Dictionary:
		return value if value is Dictionary else {}


class FakeOwner:
	extends Node

	var selected_character_type := "smasher"
	var lingpet_owned_pet_ids: Array = []
	var owned_lingpet_ids: Array = []
	var owned_ringpet_ids: Array = []
	var lingpet_collection: Dictionary = {}
	var ringpet_collection: Dictionary = {}
	var owned_lingpets: Dictionary = {}
	var owned_ringpets: Dictionary = {}
	var player_pos := Vector2(302.5, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var runtime_perk_levels: Dictionary = {}
	var runtime_perk_effective_levels: Dictionary = {}
	# sentinel: 실제 owner-effect sync가 이 필드를 0으로 '덮는지' 본다 —
	# 필드가 없으면 소비자 fallback 0으로 읽혀 씰이 공허해진다.
	var runtime_accessory_slot_bonus := 7
	var runtime_perk_pending_choices := 0
	var runtime_perk_starpoints := 0
	var runtime_perk_choice_active := false


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(new_instances: Dictionary = {}) -> void:
		instances = new_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class ByproductSlotState:
	extends RefCounted

	var owned_byproducts: Array[String] = []
	var slot_reduction := 0

	func _init(next_owned_byproducts: Array[String], next_slot_reduction: int = 0) -> void:
		owned_byproducts = next_owned_byproducts.duplicate()
		slot_reduction = next_slot_reduction

	func get_perk_fusion_owned_byproduct_ids() -> Array[String]:
		return owned_byproducts.duplicate()

	func get_perk_fusion_slot_reduction() -> int:
		return slot_reduction


class ChoiceModalProbe:
	extends Control

	var runtime_state: Object = null
	var catalog: Object = null
	var icon_renderer: Object = null
	var overlay_renderer: Object = RuntimePerkOverlayRenderer.new()

	func _draw() -> void:
		overlay_renderer.draw(self, runtime_state, catalog, Vector2(960.0, 720.0), icon_renderer)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# [게이트 격리] 이 스모크는 한국어 원문 문구를 직접 검사한다 — 저장된
	# 게임 언어 설정(ru 등)에 따라 결과가 갈리면 focused 게이트가 환경
	# 의존이 된다. '비저장 override'로 locale을 ko에 고정해 user:// 설정
	# 파일을 처음부터 읽기만 하고 절대 쓰지 않는다 — 저장형 set_language를
	# 쓰면 도중 크래시 시 실제 사용자 설정이 ko로 손상된 채 남는다.
	# 파일 스냅샷은 무접촉 검증(시작/종료 바이트 동일성 fail-closed)용.
	_language_settings_snapshot = _snapshot_settings_file(LanguageSettings.SETTINGS_PATH)
	if not bool(_language_settings_snapshot.get("read_ok", false)):
		# 진짜 fail-fast: 초기 스냅샷을 못 읽으면 무접촉 대조의 기준 자체가
		# 없으므로 어떤 locale 작업도 시작하지 않고 즉시 중단한다.
		push_error("perk_slot_limit_smoke: initial settings snapshot read failed - aborting before any locale work (fail-fast)")
		quit(1)
		return
	LanguageSettings.set_test_locale_override("ko")
	PerkConversionFlags.debug_set_enabled(true)
	_verify_slot_classifier_and_count()
	_verify_offer_budget_at_five_slots()
	_verify_offer_budget_at_six_slots()
	_verify_non_consuming_choices_survive_full_slots()
	_verify_mythic_grant_respects_slots()
	_verify_slot_status_data()
	_verify_fusion_byproduct_slot_expansion()
	_verify_fusion_byproduct_apply_fanout()
	_verify_legacy_expansion_live_paths_and_defensive_restore_hook()
	_verify_mythic_gate_follows_dynamic_limit()
	_verify_expansion_localization_semantics()
	await _capture_choice_modal_slot_status()
	PerkConversionFlags.debug_set_enabled(false)
	_verify_flag_off_isolation()

	# split-brain 씰: warm-cache 상태에서 '저장 언어와 다른' override를 걸었다
	# 해제하면 get_language()와 TranslationServer.get_locale()이 함께 저장
	# locale로 복원돼야 한다(변수만 비우면 엔진이 마지막 override에 남는다).
	# 반드시 warm-cache로 재현한다: cold cache면 해제 뒤의 get_language()가
	# config-로드 경로에서 엔진 locale을 lazy 재적용해 split-brain을 우연히
	# 치유하므로 씰이 공허해진다. probe는 고정값이 아니라 저장 언어와 반드시
	# 다르게 동적 선택한다 — 저장 언어=ru 환경에서 고정 ru probe는 복원
	# 코드를 지워도 캐시·엔진이 이미 전부 ru라 GREEN(반증 공허)이 된다.
	LanguageSettings.set_test_locale_override("")
	var warm_saved_language: String = LanguageSettings.normalize_language(LanguageSettings.get_language())
	_expect(not warm_saved_language.is_empty(), "warm-cache setup should resolve the saved language")
	var probe_language: String = "ru" if warm_saved_language != "ru" else "ja"
	_expect(LanguageSettings.normalize_language(probe_language) != warm_saved_language, "the probe language must differ from the saved language (a same-language probe makes the seal vacuous)")
	LanguageSettings.set_test_locale_override(probe_language)
	_expect(_engine_locale_is(probe_language), "override(%s) should drive the engine locale" % probe_language)

	# override 활성 중 set_language()는 캐시·파일만 갱신하고 엔진 locale은
	# override가 계속 소유해야 한다(가드 삭제 시 여기서 RED). ⚠️이 레그는
	# 실 user:// 설정 파일에 어떤 쓰기도 하면 안 된다 — '쓰고 원복'은
	# set_language와 원복 사이 크래시 윈도우에서 실 설정을 오염시킨다
	# (fresh 프로필에 없던 cfg 생성, 기존 파일 재직렬화·truncate 손상).
	# 경로 seam으로 저장까지 포함한 전체 실경로를 스크래치 파일로 돌리고,
	# 스크래치가 실제 쓰였는지로 실경로 완주를 증명한다.
	# 스크래치 씰 자립화: 존재-검사만으로는 삭제 불가능한 stale 스크래치
	# 하나로 save 실패가 공허 통과한다. 프로세스별 고유 경로(병렬 경합
	# 차단) + 시작 부재 확인 + 저장 내용 load 대조(이번 실행이 쓴
	# schema/locale) + 삭제 성공·최종 부재 확인까지 한 묶음으로 봉인한다.
	var settings_scratch_path := "user://perk_slot_limit_smoke_language_scratch_%d.cfg" % OS.get_process_id()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_scratch_path))
	_expect(not FileAccess.file_exists(settings_scratch_path), "the scratch path must start absent (an undeletable stale scratch would make the save seal vacuous)")
	LanguageSettings.set_test_settings_path_override(settings_scratch_path)
	LanguageSettings.set_language(warm_saved_language)
	_expect(_engine_locale_is(probe_language), "set_language during an active override must not steal the engine locale from the override")
	var scratch_config := ConfigFile.new()
	_expect(scratch_config.load(settings_scratch_path) == OK, "the guard leg must exercise the real save path (the scratch file must load back)")
	_expect(int(scratch_config.get_value(LanguageSettings.SETTINGS_SECTION, LanguageSettings.SETTINGS_SCHEMA_KEY, -1)) == LanguageSettings.SETTINGS_SCHEMA_VERSION, "the scratch save must carry the schema version written by this run")
	_expect(str(scratch_config.get_value(LanguageSettings.SETTINGS_SECTION, LanguageSettings.SETTINGS_LANGUAGE_KEY, "")) == warm_saved_language, "the scratch save must carry the locale written by this run")
	LanguageSettings.set_test_settings_path_override("")
	_expect(DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_scratch_path)) == OK, "scratch cleanup must report success")
	_expect(not FileAccess.file_exists(settings_scratch_path), "the scratch file must be gone after cleanup")

	# warm-clear 본 씰(P2 핵심): 해제 시 캐시·엔진 동시 복원.
	LanguageSettings.set_test_locale_override("")
	var released_language: String = LanguageSettings.normalize_language(LanguageSettings.get_language())
	_expect(released_language == warm_saved_language, "releasing the override must restore get_language() to the saved language")
	_expect(not _engine_locale_is(probe_language) or released_language == LanguageSettings.normalize_language(probe_language), "releasing the override must not leave the engine locale on the override value (split-brain)")
	_expect(_engine_locale_is(released_language), "released engine locale must match get_language() (both restored together)")

	# reset/cache-miss→clear 전이: reset_cache_for_tests는 override를
	# 건드리지 않고(별개 레이어), cold cache에서 해제해도 최종 상태는
	# 캐시·엔진 모두 저장 locale로 정합해야 한다.
	LanguageSettings.set_test_locale_override(probe_language)
	LanguageSettings.reset_cache_for_tests()
	_expect(LanguageSettings.get_language() == LanguageSettings.normalize_language(probe_language), "reset_cache_for_tests must not clear the test locale override")
	LanguageSettings.set_test_locale_override("")
	var cold_released_language: String = LanguageSettings.normalize_language(LanguageSettings.get_language())
	_expect(cold_released_language == warm_saved_language, "cold-cache release must land back on the saved language")
	_expect(_engine_locale_is(cold_released_language), "cold-cache release must leave the engine locale on the saved language too")
	_verify_settings_file_untouched()
	if _failures.is_empty():
		print("perk_slot_limit_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_slot_classifier_and_count() -> void:
	var catalog := RuntimePerkCatalog.new()
	var star_detector := catalog.get_perk_data("star_detector")
	var odins_eye := catalog.get_perk_data("odins_eye")
	var unlock_plasma := catalog.get_perk_data("unlock_plasma")
	var instant := catalog.get_perk_data("instant_gauge_full")
	var gold := catalog.get_perk_data("convert_to_gold")

	_expect(RuntimePerkCatalog.is_slot_consuming_perk(star_detector), "converted regular perks should consume one perk slot")
	_expect(RuntimePerkCatalog.is_slot_consuming_perk(odins_eye), "converted mythic perks should consume one perk slot")
	_expect(not RuntimePerkCatalog.is_slot_consuming_perk(unlock_plasma), "unlock_* active-skill cards should not consume the perk-slot budget")
	_expect(not RuntimePerkCatalog.is_slot_consuming_perk(instant), "instant cards should not consume the perk-slot budget")
	_expect(not RuntimePerkCatalog.is_slot_consuming_perk(gold), "gold conversion should not consume the perk-slot budget")

	var mixed_levels := _full_slot_levels()
	mixed_levels["unlock_plasma"] = 1
	mixed_levels["instant_gauge_full"] = 1
	mixed_levels["convert_to_gold"] = 1
	_expect_eq(catalog.count_owned_slot_perks(mixed_levels), RuntimePerkCatalog.BASE_PERK_SLOT_LIMIT, "slot count should ignore unlock/instant/gold levels")


func _verify_offer_budget_at_five_slots() -> void:
	var catalog := RuntimePerkCatalog.new()
	var levels := _five_slot_levels()
	var choices: Array = catalog.get_choices("smasher", levels, true, OFFER_SCAN_COUNT)
	_expect(_has_choice_id(choices, "item_recycle"), "with five occupied slots, a new slot-consuming perk should still be offerable")
	_expect(_has_choice_id(choices, "dash_acceleration"), "with five occupied slots, owned slot-consuming perks should still level up")


func _verify_offer_budget_at_six_slots() -> void:
	var catalog := RuntimePerkCatalog.new()
	var levels := _full_slot_levels()
	var choices: Array = catalog.get_choices("smasher", levels, true, OFFER_SCAN_COUNT)
	_expect(not _has_choice_id(choices, "item_recycle"), "with six occupied slots, new slot-consuming perks should be filtered out")
	_expect(_has_choice_id(choices, "dash_acceleration"), "with six occupied slots, owned slot-consuming level-ups should remain offerable")


func _verify_non_consuming_choices_survive_full_slots() -> void:
	var catalog := RuntimePerkCatalog.new()
	var runtime := LingpetEggRuntime.new()
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	var registry := FakeRegistry.new({"lingpet_egg_runtime": runtime})
	var full_levels := _full_slot_levels()

	var choices_with_instant: Array = catalog.get_choices("smasher", full_levels, false, OFFER_SCAN_COUNT, owner, registry)
	_expect(_has_choice_id(choices_with_instant, "instant_gauge_full"), "full slots should not suppress instant choices")
	_expect(not _has_choice_id(choices_with_instant, "convert_to_gold"), "normal offers should retire gold conversion")

	var choices_without_instant: Array = catalog.get_choices("smasher", full_levels, true, OFFER_SCAN_COUNT, owner, registry)
	_expect(_has_choice_id(choices_without_instant, "unlock_plasma"), "full slots should not suppress unlock_* active-skill choices")
	owner.free()


func _verify_mythic_grant_respects_slots() -> void:
	var catalog := RuntimePerkCatalog.new()
	var owner := FakeOwner.new()
	root.add_child(owner)
	var five_state := RuntimePerkState.new()
	five_state.runtime_skill_levels = _five_slot_levels()
	var five_registry := FakeRegistry.new({
		"runtime_perk_state": five_state,
		"runtime_perk_catalog": catalog,
	})
	var mythic_reward: Dictionary = MythicPerkGrantHelper.build_reward(owner, five_registry)
	_expect(str(mythic_reward.get("type", "")) == MythicPerkGrantHelper.REWARD_MYTHIC_PERK, "five occupied slots should allow a new mythic perk reward")
	var mythic_result: Dictionary = MythicPerkGrantHelper.grant_reward(mythic_reward, owner, five_registry)
	_expect(bool(mythic_result.get("granted", false)), "five occupied slots should grant the mythic perk through runtime perk state")
	_expect_eq(catalog.count_owned_slot_perks(five_state.runtime_skill_levels), RuntimePerkCatalog.BASE_PERK_SLOT_LIMIT, "mythic grant at five slots should fill the sixth slot")

	var full_state := RuntimePerkState.new()
	full_state.runtime_skill_levels = _full_slot_levels()
	var full_registry := FakeRegistry.new({
		"runtime_perk_state": full_state,
		"runtime_perk_catalog": catalog,
	})
	var fallback_reward: Dictionary = MythicPerkGrantHelper.build_reward(owner, full_registry)
	_expect(str(fallback_reward.get("type", "")) == MythicPerkGrantHelper.REWARD_STARPOINT, "six occupied slots should roll mythic perk rewards into starpoints")
	var fallback_result: Dictionary = MythicPerkGrantHelper.grant_reward(fallback_reward, owner, full_registry)
	_expect(bool(fallback_result.get("fallback_starpoint", false)), "six occupied slots should grant the mythic fallback as starpoints")
	_expect_eq(catalog.count_owned_slot_perks(full_state.runtime_skill_levels), RuntimePerkCatalog.BASE_PERK_SLOT_LIMIT, "starpoint fallback should not add a seventh slot-consuming perk")
	owner.free()


func _verify_slot_status_data() -> void:
	var catalog := RuntimePerkCatalog.new()
	var five_status: Dictionary = catalog.get_perk_slot_status(_five_slot_levels())
	var full_status: Dictionary = catalog.get_perk_slot_status(_full_slot_levels())
	_expect_eq(int(five_status.get("count", 0)), 5, "slot status should report five occupied slots")
	_expect_eq(int(five_status.get("limit", 0)), RuntimePerkCatalog.BASE_PERK_SLOT_LIMIT, "slot status should expose the fixed slot limit")
	_expect(not bool(five_status.get("is_full", false)), "slot status should not mark five slots as full")
	_expect_eq(int(full_status.get("count", 0)), RuntimePerkCatalog.BASE_PERK_SLOT_LIMIT, "slot status should report six occupied slots")
	_expect(bool(full_status.get("is_full", false)), "slot status should mark six slots as full")


func _verify_fusion_byproduct_slot_expansion() -> void:
	var catalog := RuntimePerkCatalog.new()
	var state := ByproductSlotState.new(["meridian_expand"])
	var registry := FakeRegistry.new({"runtime_perk_state": state})
	_expect_eq(catalog.get_perk_slot_limit({}, null), RuntimePerkCatalog.BASE_PERK_SLOT_LIMIT, "no byproduct context should keep the base limit of 6")
	_expect_eq(catalog.get_perk_slot_limit({"common_expansion": 99}, null), RuntimePerkCatalog.BASE_PERK_SLOT_LIMIT, "legacy expansion levels must not raise the flag-ON slot limit")
	_expect_eq(catalog.get_perk_slot_limit({}, state), RuntimePerkCatalog.MAX_PERK_SLOT_LIMIT, "runtime-state context should expose the meridian expansion limit of 7")
	_expect_eq(catalog.get_perk_slot_limit({}, registry), RuntimePerkCatalog.MAX_PERK_SLOT_LIMIT, "registry context should expose the meridian expansion limit of 7")
	var state_status: Dictionary = catalog.get_perk_slot_status(_full_slot_levels(), state)
	var registry_status: Dictionary = catalog.get_perk_slot_status(_full_slot_levels(), registry)
	_expect_eq(int(state_status.get("limit", 0)), 7, "slot status must forward runtime-state context into the limit query")
	_expect_eq(int(registry_status.get("limit", 0)), 7, "slot status must forward registry context into the limit query")
	_expect(not bool(state_status.get("is_full", true)) and not bool(registry_status.get("is_full", true)), "six occupied slots should remain open at the byproduct limit of 7")
	_expect(catalog.has_open_perk_slot(_full_slot_levels(), registry), "open-slot checks must forward the byproduct context")
	var duplicate_state := ByproductSlotState.new(["meridian_expand", "meridian_expand"])
	_expect_eq(catalog._resolve_perk_fusion_slot_limit_bonus(duplicate_state), 1, "duplicate/corrupt byproduct ids must resolve to one ownership bonus before the hard-limit clamp")
	_expect_eq(catalog.get_perk_slot_limit({}, duplicate_state), RuntimePerkCatalog.MAX_PERK_SLOT_LIMIT, "duplicate/corrupt byproduct ids must still grant the one-time slot bonus only once")
	var effective_levels := RuntimePerkEffectiveLevels.new()
	_expect(not effective_levels.is_runtime_level_bonus_eligible("common_expansion", 2), "the preserved flag-OFF expansion definition must remain excluded from effective-level inflation")


func _verify_fusion_byproduct_apply_fanout() -> void:
	# 실제 합일 커밋으로 부산물과 슬롯 환급을 함께 만든 뒤, 오퍼→적용→HUD
	# 상태가 동일한 registry 컨텍스트를 통해 6/7→7/7을 보는지 봉인한다.
	var catalog := RuntimePerkCatalog.new()
	var owner := FakeOwner.new()
	root.add_child(owner)
	var state: Object = _build_meridian_expanded_state(catalog)
	var registry := FakeRegistry.new({
		"runtime_perk_state": state,
		"runtime_perk_catalog": catalog,
	})
	_expect(state.get_perk_fusion_owned_byproduct_ids().has("meridian_expand"), "real fusion commit should own meridian_expand")
	_expect_eq(catalog.count_owned_slot_perks(state.runtime_skill_levels, registry), 6, "seven raw perks minus one fusion refund should occupy six slots")
	_expect_eq(catalog.get_perk_slot_limit(state.runtime_skill_levels, registry), 7, "real owned byproduct should raise the live limit to 7")
	_expect(catalog.has_open_perk_slot(state.runtime_skill_levels, registry), "real owned byproduct should reopen the slot budget")
	var reopened_choices: Array = catalog.get_choices("smasher", state.runtime_skill_levels, true, OFFER_SCAN_COUNT, owner, registry)
	var seventh_choice: Dictionary = {}
	for choice_value in reopened_choices:
		if choice_value is Dictionary and str((choice_value as Dictionary).get("id", "")) == "item_recycle":
			seventh_choice = choice_value
			break
	_expect(not seventh_choice.is_empty(), "reopened budget should offer a new slot-consuming perk again")
	_expect(state.apply_choice(seventh_choice, owner, registry), "real apply path should accept the seventh slot-consuming perk")
	var final_status: Dictionary = catalog.get_perk_slot_status(state.runtime_skill_levels, registry)
	_expect_eq(int(final_status.get("count", 0)), 7, "seventh perk should occupy the expanded slot")
	_expect_eq(int(final_status.get("limit", 0)), 7, "limit should stay at 7 after filling it")
	_expect(bool(final_status.get("is_full", false)), "7/7 should read as full again")
	owner.free()


func _verify_legacy_expansion_live_paths_and_defensive_restore_hook() -> void:
	var catalog := RuntimePerkCatalog.new()
	var choices: Array = catalog.get_choices("smasher", {}, true, OFFER_SCAN_COUNT)
	_expect(not _has_choice_id(choices, "common_expansion"), "flag ON: common_expansion must not appear in the live offer pool")
	_expect(not _has_choice_id(catalog.get_debug_perk_entries("smasher"), "common_expansion"), "flag ON: the debug picker must not grant the retired perk as a slot-consuming dead entry")
	var legacy_data: Dictionary = catalog.get_perk_data("common_expansion")
	legacy_data["id"] = "common_expansion"
	_expect(RuntimePerkCatalog.is_slot_consuming_perk(legacy_data), "flag ON must remove the retired non-consuming escape-valve exception")
	# Production currently writes fusion snapshots but has no consumer that
	# calls restore_perk_fusion_snapshot(). This is a unit-level contract for
	# the correctly placed future restore seam, not proof of live save healing.
	var state := RuntimePerkState.new()
	state.runtime_skill_levels = {"common_expansion": 3}
	var restore_result: Dictionary = state.restore_perk_fusion_snapshot({"records": []}, catalog)
	_expect(bool(restore_result.get("removed_legacy_common_expansion", false)), "flag-ON defensive restore hook should report removing the retired expansion key")
	_expect(not state.runtime_skill_levels.has("common_expansion"), "flag-ON defensive restore hook must erase the retired common_expansion level")


func _verify_mythic_gate_follows_dynamic_limit() -> void:
	# 신화 오퍼/그랜트의 슬롯 게이트가 동적 한도를 추종해야 한다: 부산물로
	# 한도 7·보유 6이면 신화 퍽이 grant되고(7번째), 7/7이 되면 다시
	# 스타포인트로 넘어간다. owner-sync: grant가 owner 유효레벨 동기화까지
	# 요구하는 실경로(grant_reward)를 그대로 지난다.
	var catalog := RuntimePerkCatalog.new()
	var owner := FakeOwner.new()
	root.add_child(owner)
	var state: Object = _build_meridian_expanded_state(catalog)
	var registry := FakeRegistry.new({
		"runtime_perk_state": state,
		"runtime_perk_catalog": catalog,
	})
	var expanded_reward: Dictionary = MythicPerkGrantHelper.build_reward(owner, registry)
	_expect(str(expanded_reward.get("type", "")) == MythicPerkGrantHelper.REWARD_MYTHIC_PERK, "expanded limit (6/7) should let the mythic gate offer a new mythic perk")
	var expanded_result: Dictionary = MythicPerkGrantHelper.grant_reward(expanded_reward, owner, registry)
	_expect(bool(expanded_result.get("granted", false)), "expanded limit should grant the mythic perk into the seventh slot")
	var post_grant_status: Dictionary = catalog.get_perk_slot_status(state.runtime_skill_levels, registry)
	_expect_eq(int(post_grant_status.get("count", 0)), 7, "mythic grant should fill the seventh (expanded) slot")
	var refill_reward: Dictionary = MythicPerkGrantHelper.build_reward(owner, registry)
	_expect(str(refill_reward.get("type", "")) == MythicPerkGrantHelper.REWARD_STARPOINT, "7/7 under the expanded limit should fall back to starpoints again")
	# grant-side 게이트: 7/7에서 신화 퍽 보상을 '강제로' grant해도 슬롯
	# 게이트가 막고 스타포인트로 격하돼야 한다(offer-side 폴백만 보면
	# grant 경로의 게이트 소실을 못 잡는다).
	var forced_mythic_reward := {
		"type": MythicPerkGrantHelper.REWARD_MYTHIC_PERK,
		"fallback_starpoints": 1,
	}
	var pre_forced_count: int = catalog.count_owned_slot_perks(state.runtime_skill_levels, registry)
	var forced_result: Dictionary = MythicPerkGrantHelper.grant_reward(forced_mythic_reward, owner, registry)
	_expect(bool(forced_result.get("fallback_starpoint", false)), "7/7 forced mythic grant must degrade to the starpoint fallback (grant-side slot gate)")
	_expect(not bool(forced_result.get("granted", false)) or bool(forced_result.get("fallback_starpoint", false)), "7/7 forced mythic grant must not land a new mythic perk")
	_expect_eq(catalog.count_owned_slot_perks(state.runtime_skill_levels, registry), pre_forced_count, "7/7 forced mythic grant must not add an eighth slot-consuming perk")
	owner.free()


func _verify_expansion_localization_semantics() -> void:
	# 의미론 씰: 이름/요약이 stale '장신구(accessory)' 문구로 남아 있으면
	# 키 존재만 보는 기존 localization 스모크는 통과한다 — 6언어 전부
	# '장신구' 계열 단어 부재 + 무공 슬롯 계열 단어 존재를 직접 본다.
	var stale_tokens := {
		"en": "accessory", "zh": "饰品", "ja": "アクセサリ",
		"es": "accesorio", "pt": "acessório", "ru": "аксессуар",
	}
	var expected_tokens := {
		"en": "mugong", "zh": "武功", "ja": "武功",
		"es": "mugong", "pt": "mugong", "ru": "мугон",
	}
	var name_maps := {
		"en": LanguageSettingsData.PERK_NAME_EN, "zh": LanguageSettingsData.PERK_NAME_ZH,
		"ja": LanguageSettingsData.PERK_NAME_JA, "es": LanguageSettingsData.PERK_NAME_ES,
		"pt": LanguageSettingsData.PERK_NAME_PT_BR, "ru": LanguageSettingsData.PERK_NAME_RU,
	}
	var summary_maps := {
		"en": LanguageSettingsData.PERK_SUMMARY_EN, "zh": LanguageSettingsData.PERK_SUMMARY_ZH,
		"ja": LanguageSettingsData.PERK_SUMMARY_JA, "es": LanguageSettingsData.PERK_SUMMARY_ES,
		"pt": LanguageSettingsData.PERK_SUMMARY_PT_BR, "ru": LanguageSettingsData.PERK_SUMMARY_RU,
	}
	var name_tokens := {
		"en": "meridian", "zh": "脉", "ja": "脈",
		"es": "meridianos", "pt": "meridianos", "ru": "меридиан",
	}
	var raw_only_tokens := {
		"en": "directly invested", "zh": "直接投资", "ja": "直接投資",
		"es": "directamente", "pt": "diretamente", "ru": "напрямую",
	}
	for lang in stale_tokens.keys():
		var name_text: String = str((name_maps[lang] as Dictionary).get("accessory_slot_expand", ""))
		var summary_text: String = str((summary_maps[lang] as Dictionary).get("accessory_slot_expand", ""))
		_expect(name_text != "" and summary_text != "", "expansion perk should keep %s name/summary entries" % lang)
		var stale: String = str(stale_tokens[lang])
		_expect(name_text.to_lower().find(stale) < 0 and summary_text.to_lower().find(stale) < 0, "%s expansion copy must drop the stale accessory wording" % lang)
		_expect(summary_text.to_lower().find(str(expected_tokens[lang]).to_lower()) >= 0, "%s expansion summary should describe Mugong slots" % lang)
		_expect(name_text.to_lower().find(str(name_tokens[lang]).to_lower()) >= 0, "%s expansion NAME should preserve the meridian-art identity" % lang)
		_expect(summary_text.to_lower().find(str(raw_only_tokens[lang]).to_lower()) >= 0, "%s expansion summary must carry the RAW-only (directly invested) notice" % lang)
	# 6개 비한국어 전부에서 flag ON/OFF의 localize 실경로와 힌트 번역을
	# 순환 봉인한다(en 단일 검증으로는 언어별 재분기를 못 잡는다).
	for cycle_language in ["en", "zh", "ja", "es", "pt-BR", "ru"]:
		LanguageSettings.set_test_locale_override(cycle_language)
		var on_cycle_name: String = LanguageSettings.localize_perk_name("common_expansion", "광맥결")
		_expect(on_cycle_name != "" and on_cycle_name != "광맥결", "flag ON %s: localize should replace the Korean Mugong name" % cycle_language)
		var on_cycle_hint: String = LanguageSettings.translate_text(RuntimePerkOverlayRenderer.get_full_slot_hint())
		_expect(on_cycle_hint != "" and on_cycle_hint != "강화·비소모 퍽만", "flag ON %s: the full-slot hint must be translated" % cycle_language)
		PerkConversionFlags.debug_set_enabled(false)
		var off_cycle_name: String = LanguageSettings.localize_perk_name("common_expansion", "확장")
		_expect(off_cycle_name != "" and off_cycle_name != on_cycle_name, "flag OFF %s: localize must fall back to the legacy expansion name (not the new perk-slot wording)" % cycle_language)
		var cycle_legacy_token: String = str({
			"en": "accessory", "zh": "饰品", "ja": "アクセサリ",
			"es": "accesorio", "pt-BR": "acessório", "ru": "аксессуар",
		}.get(cycle_language, ""))
		var off_cycle_data: Dictionary = RuntimePerkCatalog.new().get_perk_data("common_expansion")
		var off_cycle_copy: String = (str(off_cycle_data.get("description", "")) + " " + str(off_cycle_data.get("detail", ""))).to_lower()
		_expect(off_cycle_copy.find(cycle_legacy_token) >= 0, "flag OFF %s: the catalog copy must carry the legacy accessory wording (bad translation guard)" % cycle_language)
		var off_cycle_hint: String = LanguageSettings.translate_text(RuntimePerkOverlayRenderer.get_full_slot_hint())
		_expect(off_cycle_hint != "" and off_cycle_hint != "보유 퍽 강화만", "flag OFF %s: the legacy full-slot hint must be translated" % cycle_language)
		_expect(off_cycle_hint != on_cycle_hint, "flag OFF %s: the legacy hint must differ from the flag-ON hint (same-mistranslation guard)" % cycle_language)
		var cycle_hint_token: String = str({
			"en": "upgrade", "zh": "强化", "ja": "強化",
			"es": "mejoras", "pt-BR": "melhorias", "ru": "улучшен",
		}.get(cycle_language, ""))
		_expect(on_cycle_hint.to_lower().find(cycle_hint_token) >= 0 and off_cycle_hint.to_lower().find(cycle_hint_token) >= 0, "%s: both full-slot hints should carry the upgrade meaning token" % cycle_language)
		# ON 힌트는 '비소모 퍽도 계속 나온다'는 의미를 잃으면 안 된다 —
		# upgrade 토큰만 보면 '모든 강화만' 류 오역도 통과한다.
		var cycle_on_only_token: String = str({
			"en": "non-slot", "zh": "不占位", "ja": "非消費",
			"es": "sin espacio", "pt-BR": "sem espaço", "ru": "без ячейки",
		}.get(cycle_language, ""))
		_expect(on_cycle_hint.to_lower().find(cycle_on_only_token) >= 0, "flag ON %s: the hint must keep the non-slot-perk meaning token" % cycle_language)
		PerkConversionFlags.debug_set_enabled(true)
	LanguageSettings.set_test_locale_override("ko")
	# alias -> localize 실경로: 데이터 dict 검사만으로는 PERK_LOCALIZATION_
	# ALIASES 경유 실조회가 죽어도 통과한다 — 실제 localize API로 봉인.
	_expect(str(LanguageSettingsData.PERK_LOCALIZATION_ALIASES.get("common_expansion", "")) == "accessory_slot_expand", "common_expansion must alias to the localized expansion entry")
	LanguageSettings.set_test_locale_override("en")
	var localized_name: String = LanguageSettings.localize_perk_name("common_expansion", "광맥결")
	LanguageSettings.set_test_locale_override("ko")
	_expect(localized_name.to_lower().find("meridian") >= 0, "live localize path must resolve common_expansion to the meridian-art wording (got '%s')" % localized_name)
	# 한국어 detail의 RAW-only 고지.
	var catalog := RuntimePerkCatalog.new()
	var detail: String = str(catalog.get_perk_data("common_expansion").get("detail", ""))
	_expect(detail.find("직접 투자") >= 0, "Korean detail must state the RAW-only (directly invested levels) rule")


func _verify_flag_off_isolation() -> void:
	# flag OFF: 한도는 중앙 격리로 고정 6(UI는 flag와 무관하게 조회),
	# 확장 퍽은 레거시 장신구 의미(소모 + 장신구 슬롯 2→4 유지).
	var catalog := RuntimePerkCatalog.new()
	_expect_eq(catalog.get_perk_slot_limit({"common_expansion": 4}), RuntimePerkCatalog.BASE_PERK_SLOT_LIMIT, "flag OFF: the slot limit must stay pinned at 6 regardless of expansion levels")
	var expansion_data := catalog.get_perk_data("common_expansion")
	expansion_data["id"] = "common_expansion"
	_expect(RuntimePerkCatalog.is_slot_consuming_perk(expansion_data), "flag OFF: the legacy expansion perk keeps consuming a slot")
	# OFF에서 노출되는 정의도 레거시 의미여야 한다 — 새 정의(max 4·퍽 슬롯
	# 문구)를 그대로 내보내면 실효(장신구 2칸)와 모순되는 무효 레벨 노출.
	_expect_eq(int(expansion_data.get("max_level", 0)), 2, "flag OFF: the expansion perk must expose the legacy max level of 2")
	_expect(str(expansion_data.get("detail", "")).find("장신구") >= 0, "flag OFF: the expansion perk detail must describe the legacy accessory meaning")
	# get_perk_data(조회)만 고치면 실제 오퍼는 pool 원본(새 정의)을 직접
	# 읽어 계약을 우회한다 — 실오퍼 후보에서 레거시 계약을 직접 봉인.
	var off_offer_choices: Array = catalog.get_choices("smasher", {"common_expansion": 2}, true, OFFER_SCAN_COUNT)
	_expect(not _has_choice_id(off_offer_choices, "common_expansion"), "flag OFF: the real offer must stop the expansion perk at the legacy max level of 2 (levels 3~4 must not surface)")
	var off_fresh_choices: Array = catalog.get_choices("smasher", {}, true, OFFER_SCAN_COUNT)
	var off_expansion_choice: Dictionary = {}
	for off_choice_value in off_fresh_choices:
		if off_choice_value is Dictionary and str((off_choice_value as Dictionary).get("id", "")) == "common_expansion":
			off_expansion_choice = off_choice_value
			break
	_expect(not off_expansion_choice.is_empty(), "flag OFF: the legacy expansion perk should still appear in the real offer below its max")
	_expect_eq(int(off_expansion_choice.get("max_level", 0)), 2, "flag OFF: the real offer candidate must carry the legacy max level of 2")
	_expect(str(off_expansion_choice.get("description", "")).find("장신구") >= 0, "flag OFF: the real offer candidate must describe accessory slots, not perk slots")
	_expect(RuntimePerkOverlayRenderer.get_full_slot_hint() == "보유 무공 강화만", "flag OFF: the full-slot hint should keep the branded upgrade-only wording")
	PerkConversionFlags.debug_set_enabled(true)
	_expect(RuntimePerkOverlayRenderer.get_full_slot_hint().find("비소모") >= 0, "flag ON: the full-slot hint must state the real rule (upgrades + non-consuming perks stay offerable)")
	var on_expansion_data := RuntimePerkCatalog.new().get_perk_data("common_expansion")
	_expect_eq(int(on_expansion_data.get("max_level", 0)), 4, "flag ON: the expansion perk exposes the four-level slot meaning")
	PerkConversionFlags.debug_set_enabled(false)
	# 장신구 양방향: OFF에서는 2→4칸 확장 유지, ON에서는 미반영(이중 적용 차단).
	_expect_eq(CharacterInfoOverlayOwnerState.accessory_slot_count(0, 0, {"common_expansion": 2}, 2), 4, "flag OFF: accessory slots keep expanding 2 -> 4")
	# OFF 레거시 effect sync: 확장 레벨이 장신구 보너스로 환산돼 owner에
	# 실린다(레거시 경로 유지 계약).
	var off_owner := FakeOwner.new()
	root.add_child(off_owner)
	var off_state := RuntimePerkState.new()
	off_state.runtime_skill_levels = {"common_expansion": 2}
	var off_registry := FakeRegistry.new({"runtime_perk_catalog": catalog})
	off_state._sync_runtime_perk_owner_effects(off_owner, off_registry)
	_expect_eq(int(off_owner.runtime_accessory_slot_bonus), 2, "flag OFF: the legacy effect sync should keep converting expansion levels into the accessory bonus")
	var off_restore_result: Dictionary = off_state.restore_perk_fusion_snapshot({"records": []}, catalog)
	_expect(not bool(off_restore_result.get("removed_legacy_common_expansion", true)), "flag-OFF defensive restore hook must not remove the legacy expansion key")
	_expect_eq(int(off_state.runtime_skill_levels.get("common_expansion", 0)), 2, "flag-OFF defensive restore hook must preserve the legacy expansion level")
	off_owner.free()
	# bulk 경로(get_all_perk_data)도 OFF에서 레거시 정의를 봐야 한다.
	var off_bulk: Dictionary = catalog.get_all_perk_data()
	_expect_eq(int((off_bulk.get("common_expansion", {}) as Dictionary).get("max_level", 0)), 2, "flag OFF: bulk perk data must expose the legacy max level of 2")
	# 디버그 목록도 같은 정의를 봐야 UI(max 4 표시)와 적용(max 2 재해석)이
	# 어긋나지 않는다.
	var off_debug_expansion: Dictionary = {}
	for debug_entry_value in catalog.get_debug_perk_entries():
		if debug_entry_value is Dictionary and str((debug_entry_value as Dictionary).get("id", "")) == "common_expansion":
			off_debug_expansion = debug_entry_value
			break
	_expect(not off_debug_expansion.is_empty(), "flag OFF: the debug perk list should still contain the expansion perk")
	_expect_eq(int(off_debug_expansion.get("max_level", 0)), 2, "flag OFF: the debug perk list must expose the legacy max level of 2 (picker/apply mismatch guard)")
	# 비한국어에서도 OFF는 레거시 문구여야 한다(alias가 새 문구로 대체하면
	# 비한국어에서만 다시 갈라진다).
	LanguageSettings.set_test_locale_override("en")
	var off_localized_name: String = LanguageSettings.localize_perk_name("common_expansion", "확장")
	var off_localized_data: Dictionary = catalog.get_perk_data("common_expansion")
	LanguageSettings.set_test_locale_override("ko")
	_expect(off_localized_name.to_lower().find("perk slot") < 0, "flag OFF: the English name must not use the new perk-slot wording (got '%s')" % off_localized_name)
	_expect(str(off_localized_data.get("description", "")).to_lower().find("accessory") >= 0 or str(off_localized_data.get("detail", "")).to_lower().find("accessory") >= 0, "flag OFF: the English copy must keep the legacy accessory wording")
	var equipment_index := MythicItemEquipmentIndex.new()
	var accessory_owner := AccessoryProbeOwner.new()
	var accessory_runtime := AccessoryProbeRuntime.new()
	_expect(equipment_index.is_equipment_slot_enabled(accessory_runtime, "accessory3", accessory_owner), "flag OFF: legacy expansion should enable accessory slot 3")
	PerkConversionFlags.debug_set_enabled(true)
	_expect_eq(CharacterInfoOverlayOwnerState.accessory_slot_count(0, 0, {"common_expansion": 2}, 2), 2, "flag ON: expansion levels must not add accessory slots (double-apply guard)")
	_expect(not equipment_index.is_equipment_slot_enabled(accessory_runtime, "accessory3", accessory_owner), "flag ON: expansion levels must not enable extra accessory equipment slots")
	PerkConversionFlags.debug_set_enabled(false)


func _capture_choice_modal_slot_status() -> void:
	if DisplayServer.get_name().to_lower().find("headless") >= 0:
		print("perk_slot_limit_smoke: screenshot skipped under headless display server")
		return
	var catalog := RuntimePerkCatalog.new()
	var state := RuntimePerkState.new()
	state.runtime_skill_levels = _full_slot_levels()
	state.pending_skill_choices = 1
	var owner := FakeOwner.new()
	root.add_child(owner)
	var registry := FakeRegistry.new({
		"runtime_perk_state": state,
		"runtime_perk_catalog": catalog,
	})
	state.open_next_choice("smasher", catalog, false, owner, registry)
	var probe := ChoiceModalProbe.new()
	probe.size = Vector2(960.0, 720.0)
	probe.runtime_state = state
	probe.catalog = catalog
	probe.icon_renderer = RuntimePerkIconRenderer.new()
	root.add_child(probe)
	probe.queue_redraw()
	await process_frame
	await process_frame
	var viewport_texture := root.get_texture()
	if viewport_texture != null:
		var image: Image = viewport_texture.get_image()
		if image != null and not image.is_empty():
			var output_path := ProjectSettings.globalize_path(CAPTURE_PATH)
			DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
			var save_error: int = image.save_png(output_path)
			_expect(save_error == OK, "slot-limit choice modal screenshot should save to %s" % output_path)
	probe.free()
	owner.free()


func _five_slot_levels() -> Dictionary:
	return {
		"dash_acceleration": 1,
		"item_luck": 1,
		"item_gauge_mastery": 1,
		"item_caffeine": 1,
		"item_polish": 1,
	}


func _build_meridian_expanded_state(catalog: Object) -> Object:
	var state := RuntimePerkState.new()
	state.runtime_skill_levels = {
		"item_luck": 5,
		"common_bulk_up": 5,
		"dash_lightweight": 1,
		"dash_module_control": 1,
		"dash_jump": 1,
		"dash_acceleration": 1,
		"star_detector": 1,
	}
	var record: Dictionary = state.commit_perk_fusion(
		["item_luck", "common_bulk_up"],
		{"outcome": "byproduct", "byproducts": ["meridian_expand"]},
		catalog
	)
	_expect(not record.is_empty(), "meridian expansion fixture must commit through the real fusion facade")
	return state


func _full_slot_levels() -> Dictionary:
	var levels := _five_slot_levels()
	levels["star_detector"] = 1
	return levels


func _choice_by_id(choices: Array, choice_id: String) -> Dictionary:
	for value in choices:
		if value is Dictionary and str((value as Dictionary).get("id", "")) == choice_id:
			return (value as Dictionary).duplicate(true)
	return {}


func _has_choice_id(choices: Array, choice_id: String) -> bool:
	return not _choice_by_id(choices, choice_id).is_empty()


func _snapshot_settings_file(path: String) -> Dictionary:
	# read 실패와 '실제 빈 파일'을 구분한다 — 둘 다 빈 바이트로 취급하면
	# 시작/종료 읽기가 모두 실패해도 동일하다고 통과하는 fail-open이 된다.
	var had_original := FileAccess.file_exists(path)
	var original_bytes := PackedByteArray()
	var read_ok := true
	if had_original:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			read_ok = false
		else:
			original_bytes = file.get_buffer(file.get_length())
			file.close()
	return {
		"had": had_original,
		"bytes": original_bytes,
		"read_ok": read_ok,
	}


func _verify_settings_file_untouched() -> void:
	# fail-closed: 비저장 override 계약이 깨져 어떤 경로든 user:// 설정
	# 파일을 만들거나 바꿨다면 스모크 자체를 실패시킨다(존재 여부+바이트
	# 동일성 대조 — 읽기 실패도 불일치로 취급).
	var final_state: Dictionary = _snapshot_settings_file(LanguageSettings.SETTINGS_PATH)
	_expect(
		bool(_language_settings_snapshot.get("read_ok", false)) and bool(final_state.get("read_ok", false)),
		"settings snapshots must be readable on both ends (a read failure must fail closed, not compare as empty)"
	)
	_expect(
		bool(final_state.get("had", false)) == bool(_language_settings_snapshot.get("had", false)),
		"language settings file existence must be unchanged (non-persisting override contract)"
	)
	_expect(
		(final_state.get("bytes", PackedByteArray()) as PackedByteArray) == (_language_settings_snapshot.get("bytes", PackedByteArray()) as PackedByteArray),
		"language settings file bytes must be unchanged (non-persisting override contract)"
	)


func _engine_locale_is(language: String) -> bool:
	# 엔진은 set_locale("pt-BR")을 "pt_BR"로 표준화해 돌려준다 — raw
	# begins_with 비교는 pt-BR 사용자에서 위양성 RED. 양쪽 모두
	# normalize_language()로 접은 뒤 동등 비교한다.
	return LanguageSettings.normalize_language(TranslationServer.get_locale()) == LanguageSettings.normalize_language(language)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: int, expected: int, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %d, got %d)" % [message, expected, actual])
