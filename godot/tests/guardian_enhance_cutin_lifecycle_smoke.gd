extends SceneTree

const Smoke := preload("res://tests/lingpet_egg_runtime_smoke.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LingpetEnhancementBuffStore := preload(
	"res://scripts/lingpet/lingpet_enhancement_buff_store.gd"
)
const LingpetGuardianEnhanceCutinOverlayHost := preload(
	"res://scripts/hud/lingpet_guardian_enhance_cutin_overlay_host.gd"
)
const LingpetGuardianEnhanceCutinState := preload(
	"res://scripts/lingpet/lingpet_guardian_enhance_cutin_state.gd"
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
	var result_icon_paths: Array[String] = []
	var idle_fallback := false

	func prewarm_pet_assets_step(
		_pet_id: String,
		_allow_sync_fallback: bool = false,
		_perf_logger: Object = null,
		_perf_label_prefix: String = ""
	) -> bool:
		prewarm_calls += 1
		return true

	func is_pet_panel_anim_ready(_pet_id: String) -> bool:
		return true

	func prewarm_result_icon_path(icon_path: String) -> bool:
		result_icon_paths.append(icon_path)
		return FileAccess.file_exists(icon_path)

	func get_animation_contract(_pet_id: String) -> Dictionary:
		return {
			"visual_key": "companion_idle" if idle_fallback else "companion_click_reaction_anim",
			"idle_fallback": idle_fallback,
			"cols": 2,
			"rows": 2,
			"frame_count": 4,
			"frame_interval": 0.05,
			"draw_size": 108.0,
		}


class FakeModules:
	extends RefCounted

	var modules: Dictionary = {}

	func get_module(key: String) -> Object:
		var value: Variant = modules.get(key, null)
		return value as Object if typeof(value) == TYPE_OBJECT else null


func _init() -> void:
	_verify_reward_precedes_compact_presentation_and_auto_close()
	_verify_skip_and_round_transition_cleanup()
	_verify_idle_fallback_and_modal_gate()
	_verify_compact_host_and_roster_contract()
	if _failures.is_empty():
		print("guardian_enhance_cutin_lifecycle_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_reward_precedes_compact_presentation_and_auto_close() -> void:
	var fixture := _make_fixture()
	var runtime: Object = fixture.runtime
	var candidate := {
		"type": LingpetEnhancementBuffStore.REWARD_TYPE_ACTIVE_SKILL,
		"skill_slot": 1,
		"weight": 1.0,
	}
	var result: Dictionary = runtime.apply_guardian_enhance_random_roll(
		[candidate],
		fixture.owner,
		fixture.registry
	)
	_expect(bool(result.get("accepted", false)), "automatic roll must apply its only valid candidate")
	_expect(not bool(result.get("modal_started", true)), "automatic roll must not open the retired choice modal")
	_expect(runtime.is_guardian_enhance_cutin_active(), "applied reward must start the compact presentation")
	_expect(int((runtime.get_guardian_enhancement_rewards_for_tests("maribo") as Dictionary).get("active_skill_bonus", 0)) == 1, "buff owner must already contain the reward before the first presentation tick")
	var detail: Dictionary = result.get("result_detail", {}) as Dictionary
	var icon_path := str(detail.get("icon_texture_path", ""))
	_expect(icon_path != "" and fixture.host.result_icon_paths.has(icon_path), "skill result icon must be prewarmed before the compact panel starts")
	_expect(
		str(runtime.get_guardian_enhance_cutin_snapshot().get("phase", ""))
		== LingpetGuardianEnhanceCutinState.PHASE_INTRO,
		"presentation must begin in INTRO"
	)
	runtime.advance_guardian_enhance_cutin(0.14, fixture.registry)
	_expect(
		str(runtime.get_guardian_enhance_cutin_snapshot().get("phase", ""))
		== LingpetGuardianEnhanceCutinState.PHASE_ROLL,
		"INTRO boundary must enter ROLL"
	)
	runtime.advance_guardian_enhance_cutin(0.75, fixture.registry)
	_expect(
		str(runtime.get_guardian_enhance_cutin_snapshot().get("phase", ""))
		== LingpetGuardianEnhanceCutinState.PHASE_STAMP,
		"ROLL boundary must enter STAMP before the pet reacts"
	)
	runtime.advance_guardian_enhance_cutin(0.22, fixture.registry)
	var reaction_snapshot: Dictionary = runtime.get_guardian_enhance_cutin_snapshot()
	_expect(bool(reaction_snapshot.get("reaction_active", false)), "STAMP completion must start one click reaction")
	runtime.advance_guardian_enhance_cutin(0.19, fixture.registry)
	_expect(runtime.is_guardian_enhance_cutin_active(), "reaction must remain visible before its one-loop duration completes")
	runtime.advance_guardian_enhance_cutin(0.01, fixture.registry)
	_expect(
		str(runtime.get_guardian_enhance_cutin_snapshot().get("phase", ""))
		== LingpetGuardianEnhanceCutinState.PHASE_OUTRO,
		"one reaction loop must enter OUTRO instead of closing on the result frame"
	)
	runtime.advance_guardian_enhance_cutin(0.159, fixture.registry)
	_expect(runtime.is_guardian_enhance_cutin_active(), "OUTRO must retain the compact panel until 0.16s")
	runtime.advance_guardian_enhance_cutin(0.001, fixture.registry)
	_expect(not runtime.is_guardian_enhance_cutin_active(), "OUTRO completion hook must auto-close the compact panel")
	_expect(int(fixture.audio.stop_calls) == 1, "automatic close must stop enhancement presentation audio")
	_expect(int((runtime.get_guardian_enhancement_rewards_for_tests("maribo") as Dictionary).get("active_skill_bonus", 0)) == 1, "presentation close must never roll back the pre-applied reward")
	_cleanup_runtime(runtime)


func _verify_skip_and_round_transition_cleanup() -> void:
	var visual_result := {"accepted": true, "feedback_text": "기력 획득량 증가 획득"}
	for phase in [
		LingpetGuardianEnhanceCutinState.PHASE_INTRO,
		LingpetGuardianEnhanceCutinState.PHASE_ROLL,
		LingpetGuardianEnhanceCutinState.PHASE_STAMP,
		LingpetGuardianEnhanceCutinState.PHASE_REACTION,
		LingpetGuardianEnhanceCutinState.PHASE_OUTRO,
	]:
		var fixture := _make_fixture()
		var runtime: Object = fixture.runtime
		runtime.complete_guardian_enhance_roll(visual_result, "maribo", fixture.registry)
		_advance_runtime_to_phase(runtime, fixture.registry, phase)
		_expect(
			str(runtime.get_guardian_enhance_cutin_snapshot().get("phase", "")) == phase,
			"skip fixture must reach %s" % phase
		)
		_expect(runtime.cancel_guardian_enhance_cutin(fixture.registry), "click/ESC-equivalent skip must close immediately during %s" % phase)
		_expect(not runtime.is_guardian_enhance_cutin_active(), "skip must clear all compact presentation state during %s" % phase)
		_expect(int(fixture.audio.stop_calls) == 1, "skip must stop enhancement presentation audio during %s" % phase)
		_cleanup_runtime(runtime)

	var round_fixture := _make_fixture()
	var round_runtime: Object = round_fixture.runtime
	round_runtime.complete_guardian_enhance_roll(visual_result, "maribo", round_fixture.registry)
	round_runtime.reset_round({"owner": round_fixture.owner, "registry": round_fixture.registry})
	_expect(not round_runtime.is_guardian_enhance_cutin_active(), "round transition must synchronously clear the compact panel")
	_expect(int(round_fixture.audio.stop_calls) == 1, "round transition cleanup must stop enhancement presentation audio")
	var input_source := FileAccess.get_file_as_string("res://scripts/core/battle_lingpet_priority_input_router.gd")
	_expect(input_source.find("is_guardian_enhance_cutin_awaiting_dismiss") < 0, "input routing must not retain the old confirm-button wait state")
	_expect(input_source.find("_is_confirm_event(event) and runtime.has_method(\"cancel_guardian_enhance_cutin\")") >= 0, "click/confirm must route to immediate compact-panel skip")
	_cleanup_runtime(round_runtime)


func _verify_idle_fallback_and_modal_gate() -> void:
	var fixture := _make_fixture(true)
	var runtime: Object = fixture.runtime
	runtime.complete_guardian_enhance_roll({"accepted": true, "feedback_text": "강화 획득"}, "maribo", fixture.registry)
	runtime.advance_guardian_enhance_cutin(0.14, fixture.registry)
	runtime.advance_guardian_enhance_cutin(0.75, fixture.registry)
	runtime.advance_guardian_enhance_cutin(0.22, fixture.registry)
	var snapshot: Dictionary = runtime.get_guardian_enhance_cutin_snapshot()
	_expect(bool(snapshot.get("idle_fallback", false)), "missing click-reaction fixture must enter the idle one-loop fallback")
	var modules := FakeModules.new()
	modules.modules["lingpet_egg_runtime"] = runtime
	var getter := Callable(modules, "get_module")
	var gate := BattleSceneModalGateController.new()
	_expect(gate.is_lingpet_guardian_enhance_cutin_active(getter), "modal gate must expose the compact enhancement panel")
	_expect(gate.should_block_battle_physics(getter), "active compact enhancement panel must pause battle physics")
	runtime.advance_guardian_enhance_cutin(0.20, fixture.registry)
	_expect(runtime.is_guardian_enhance_cutin_active(), "idle fallback must retain the panel for OUTRO")
	runtime.advance_guardian_enhance_cutin(0.16, fixture.registry)
	_expect(not runtime.is_guardian_enhance_cutin_active(), "idle fallback must also auto-close after exactly one loop")
	_cleanup_runtime(runtime)


func _verify_compact_host_and_roster_contract() -> void:
	var host := LingpetGuardianEnhanceCutinOverlayHost.new()
	var host_source := FileAccess.get_file_as_string("res://scripts/hud/lingpet_guardian_enhance_cutin_overlay_host.gd")
	_expect(host_source.find("extends \"res://scripts/hud/lingpet_acquire_cutin_overlay_host.gd\"") < 0, "enhancement host must no longer inherit the full-screen acquisition cutin")
	_expect(host_source.find("PANEL_MAX_SIZE") >= 0 and host_source.find("companion_click_reaction_anim") >= 0, "enhancement host must own a bounded compact panel and companion reaction visual")
	_expect(host_source.find("Time.get_ticks_msec()") < 0, "compact panel motion must be derived from deterministic phase time")
	var fallback_pets: Array[String] = []
	for pet_id in LingpetCatalog.get_pet_ids():
		var contract: Dictionary = host.get_animation_contract(pet_id)
		if bool(contract.get("idle_fallback", false)):
			fallback_pets.append(pet_id)
	_expect(fallback_pets.is_empty(), "all current guardians must have dedicated companion click-reaction sheets; got %s" % [fallback_pets])
	var monkey_contract: Dictionary = host.get_animation_contract("monkeyring")
	_expect(is_equal_approx(float(monkey_contract.get("frame_interval", 0.0)), 0.05), "compact panel must honor Monkeyring's per-pet reaction cadence override")
	_expect(int(monkey_contract.get("cols", 0)) == 14 and int(monkey_contract.get("rows", 0)) == 7, "compact panel must resolve the current roster's 14x7 reaction grid through its overridable contract")
	host.prewarm_assets()
	var missing_icons: Array[String] = []
	for pet_id in LingpetCatalog.get_pet_ids():
		for skill in LingpetCatalog.get_active_skill_pool(pet_id):
			var icon_path := str(skill.get("icon_texture_path", ""))
			if icon_path == "" or not FileAccess.file_exists(icon_path) or not host.has_cached_result_icon(icon_path):
				missing_icons.append("%s:%s" % [pet_id, str(skill.get("id", ""))])
	for passive in LingpetCatalog.get_passive_skill_pool(LingpetCatalog.DEFAULT_PET_ID):
		var icon_path := str(passive.get("icon_texture_path", ""))
		if icon_path == "" or not FileAccess.file_exists(icon_path) or not host.has_cached_result_icon(icon_path):
			missing_icons.append("common:%s" % str(passive.get("id", "")))
	_expect(missing_icons.is_empty(), "every catalog skill result icon must exist and prewarm before draw; missing %s" % [missing_icons])


func _make_fixture(idle_fallback: bool = false) -> Dictionary:
	var owner := Smoke.FakeOwner.new()
	_seed_owner(owner)
	var runtime: Object = LingpetEggRuntime.new()
	var audio := FakeAudio.new()
	var host := FakeCutinHost.new()
	host.idle_fallback = idle_fallback
	var registry := Smoke.FakeRegistry.new({
		"lingpet_egg_runtime": runtime,
		"game_audio": audio,
		"lingpet_guardian_enhance_cutin_overlay_host": host,
	})
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner, false, "maribo_spear_throw", "maribo_hydro_resonance", registry), "fixture must activate maribo")
	return {"owner": owner, "runtime": runtime, "registry": registry, "audio": audio, "host": host}


func _advance_runtime_to_phase(runtime: Object, registry: Object, target_phase: String) -> void:
	if target_phase == LingpetGuardianEnhanceCutinState.PHASE_INTRO:
		return
	runtime.advance_guardian_enhance_cutin(0.14, registry)
	if target_phase == LingpetGuardianEnhanceCutinState.PHASE_ROLL:
		return
	runtime.advance_guardian_enhance_cutin(0.75, registry)
	if target_phase == LingpetGuardianEnhanceCutinState.PHASE_STAMP:
		return
	runtime.advance_guardian_enhance_cutin(0.22, registry)
	if target_phase == LingpetGuardianEnhanceCutinState.PHASE_REACTION:
		return
	runtime.advance_guardian_enhance_cutin(0.20, registry)


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
