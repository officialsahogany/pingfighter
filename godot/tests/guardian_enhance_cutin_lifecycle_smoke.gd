extends SceneTree

const Smoke := preload("res://tests/lingpet_egg_runtime_smoke.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LingpetEnhancementBuffStore := preload(
	"res://scripts/lingpet/lingpet_enhancement_buff_store.gd"
)
const LingpetGuardianEnhanceCutinOverlayHost := preload(
	"res://scripts/hud/lingpet_guardian_enhance_cutin_overlay_host.gd"
)
const BattleSceneModalGateController := preload(
	"res://scripts/core/battle_scene_modal_gate_controller.gd"
)

var _failures: Array[String] = []


class FakeAudio:
	extends RefCounted

	var stop_calls := 0

	func stop_lingpet_guardian_enhance_cutin_loop() -> void:
		stop_calls += 1


class FakeCutinHost:
	extends RefCounted

	var prewarm_calls := 0

	func prewarm_pet_assets_step(_pet_id: String, _allow_sync_fallback: bool = false) -> bool:
		prewarm_calls += 1
		return true

	func is_pet_cutin_anim_ready(_pet_id: String) -> bool:
		return true


class FakeModules:
	extends RefCounted

	var modules: Dictionary = {}

	func get_module(key: String) -> Object:
		var value: Variant = modules.get(key, null)
		return value as Object if typeof(value) == TYPE_OBJECT else null


func _init() -> void:
	_verify_reward_precedes_presentation_and_cancel_cleanup()
	_verify_normal_dismiss_and_round_transition_cleanup()
	_verify_modal_gate_and_inherited_sheet_contract()
	if _failures.is_empty():
		print("guardian_enhance_cutin_lifecycle_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_reward_precedes_presentation_and_cancel_cleanup() -> void:
	var fixture := _make_fixture()
	var runtime: Object = fixture.runtime
	var candidate := {"type": LingpetEnhancementBuffStore.REWARD_TYPE_GAUGE}
	_expect(runtime.start_guardian_enhance_choice([candidate, {"type": LingpetEnhancementBuffStore.REWARD_TYPE_MOBILITY}], fixture.owner), "choice fixture must start")
	var result: Dictionary = runtime.apply_guardian_enhancement_candidate(candidate, fixture.owner, fixture.registry)
	_expect(bool(result.get("accepted", false)), "gameplay buff must apply before presentation")
	var counts_before: Dictionary = runtime.get_affinity_rewards_for_tests("maribo")
	_expect(int(counts_before.get("gauge_stacks", 0)) == 1, "buff owner must already contain the reward before cutin start")
	runtime.complete_guardian_enhance_choice(result, fixture.registry)
	_expect(runtime.is_guardian_enhance_cutin_active(), "accepted result must start the presentation-only cutin")
	_expect(int((runtime.get_affinity_rewards_for_tests("maribo") as Dictionary).get("gauge_stacks", 0)) == 1, "cutin activation must not own or defer the reward")
	_expect(runtime.cancel_guardian_enhance_cutin(fixture.registry), "ESC-equivalent force cancel must clear an active cutin")
	_expect(not runtime.is_guardian_enhance_cutin_active(), "force cancel must leave no active overlay timer")
	_expect(int(fixture.audio.stop_calls) == 1, "force cancel must stop cutin loop audio")
	_expect(int((runtime.get_affinity_rewards_for_tests("maribo") as Dictionary).get("gauge_stacks", 0)) == 1, "presentation cancel must never roll back the applied buff")
	_cleanup_runtime(runtime)


func _verify_normal_dismiss_and_round_transition_cleanup() -> void:
	var fixture := _make_fixture()
	var runtime: Object = fixture.runtime
	var visual_result := {"accepted": true, "feedback_text": "기력 획득량 증가 획득"}
	runtime.complete_guardian_enhance_choice(visual_result, fixture.registry)
	runtime.advance_guardian_enhance_cutin(1.2, fixture.registry)
	_expect(runtime.is_guardian_enhance_cutin_awaiting_dismiss(), "cutin must hold after reveal until confirm")
	_expect(runtime.begin_guardian_enhance_cutin_dismiss(), "click/confirm must start normal dismiss")
	runtime.advance_guardian_enhance_cutin(0.8, fixture.registry)
	_expect(not runtime.is_guardian_enhance_cutin_active(), "normal dismiss must clear overlay and timer state")
	_expect(int(fixture.audio.stop_calls) == 1, "normal dismiss completion must stop cutin loop audio")
	runtime.complete_guardian_enhance_choice(visual_result, fixture.registry)
	_expect(runtime.is_guardian_enhance_cutin_active(), "round-transition fixture must reopen the cutin")
	runtime.reset_round({"owner": fixture.owner, "registry": fixture.registry})
	_expect(not runtime.is_guardian_enhance_cutin_active(), "round transition must synchronously clear the cutin")
	_expect(int(fixture.audio.stop_calls) == 2, "round transition cleanup must stop cutin loop audio")
	_cleanup_runtime(runtime)


func _verify_modal_gate_and_inherited_sheet_contract() -> void:
	var fixture := _make_fixture()
	var runtime: Object = fixture.runtime
	runtime.complete_guardian_enhance_choice({"accepted": true, "feedback_text": "강화 완료"}, fixture.registry)
	var modules := FakeModules.new()
	modules.modules["lingpet_egg_runtime"] = runtime
	var getter := Callable(modules, "get_module")
	var gate := BattleSceneModalGateController.new()
	_expect(gate.is_lingpet_guardian_enhance_cutin_active(getter), "modal gate must expose the guardian enhance cutin")
	_expect(gate.should_block_battle_physics(getter), "active guardian enhance cutin must block battle physics")
	var host := LingpetGuardianEnhanceCutinOverlayHost.new()
	_expect(host.has_method("prewarm_pet_assets_step") and host.has_method("is_pet_cutin_anim_ready"), "enhance host must inherit the proven per-pet prewarm surface")
	var host_source := FileAccess.get_file_as_string("res://scripts/hud/lingpet_guardian_enhance_cutin_overlay_host.gd")
	var base_source := FileAccess.get_file_as_string("res://scripts/hud/lingpet_acquire_cutin_overlay_host.gd")
	_expect(host_source.find("extends \"res://scripts/hud/lingpet_acquire_cutin_overlay_host.gd\"") >= 0, "enhance presentation must fork the acquisition host rather than duplicate grid rules")
	_expect(base_source.find("CUTIN_ANIM_COLS_OVERRIDES") >= 0 and base_source.find("\"maribo\": 4") >= 0, "inherited host must retain explicit legacy grid overrides")
	_expect(base_source.find("cutin_vfx_anim") >= 0, "inherited prewarm/draw path must include the cutin_vfx_anim lane")
	runtime.cancel_guardian_enhance_cutin(fixture.registry)
	_cleanup_runtime(runtime)


func _make_fixture() -> Dictionary:
	var owner := Smoke.FakeOwner.new()
	_seed_owner(owner)
	var runtime: Object = LingpetEggRuntime.new()
	var audio := FakeAudio.new()
	var host := FakeCutinHost.new()
	var registry := Smoke.FakeRegistry.new({
		"lingpet_egg_runtime": runtime,
		"game_audio": audio,
		"lingpet_guardian_enhance_cutin_overlay_host": host,
	})
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner, false, "maribo_spear_throw", "maribo_hydro_resonance", registry), "fixture must activate maribo")
	return {"owner": owner, "runtime": runtime, "registry": registry, "audio": audio, "host": host}


func _seed_owner(owner: Object) -> void:
	owner.lingpet_owned_pet_ids = ["maribo"]
	owner.owned_lingpet_ids = ["maribo"]
	owner.owned_ringpet_ids = ["maribo"]
	owner.lingpet_collection = {"maribo": true}
	owner.ringpet_collection = {"maribo": true}
	owner.owned_lingpets = {"maribo": true}
	owner.owned_ringpets = {"maribo": true}
	owner.lingpet_slots = ["maribo", "", ""]
	owner.ringpet_slots = owner.lingpet_slots.duplicate()
	owner.lingpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.ringpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.lingpet_active_slot_index = 0
	owner.ringpet_active_slot_index = 0


func _cleanup_runtime(runtime: Object) -> void:
	if runtime != null:
		runtime.reset_for_tests()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
