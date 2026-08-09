extends SceneTree
# expect-zero-object-leaks -- presentation registry/owner links must stay weak.

const Coordinator := preload(
	"res://scripts/lingpet/lingpet_guardian_enhance_presentation_coordinator.gd"
)

var _failures: Array[String] = []


class FakeOfferEngine:
	extends RefCounted

	var mark_calls := 0
	var reset_calls := 0

	func get_trigger_source_label(source: String) -> String:
		return "source:%s" % source

	func mark_applied() -> void:
		mark_calls += 1

	func reset() -> void:
		reset_calls += 1


class FakeAudio:
	extends RefCounted

	var stop_calls := 0

	func stop_lingpet_guardian_enhance_cutin_loop() -> void:
		stop_calls += 1


class FakeRuntimePerkState:
	extends RefCounted

	var pause_calls := 0
	var resume_calls := 0
	var safety_calls := 0
	var last_owner: Object = null
	var last_registry: Object = null

	func _pause_skill_cooldowns_for_choice(owner: Object, registry: Object) -> void:
		pause_calls += 1
		last_owner = owner
		last_registry = registry

	func _resume_skill_cooldowns_for_choice() -> void:
		resume_calls += 1

	func _try_arm_resume_safety(owner: Object, registry: Object) -> void:
		safety_calls += 1
		last_owner = owner
		last_registry = registry


class FakeHost:
	extends RefCounted

	var prewarm_pet_calls := 0
	var cached_icons: Dictionary = {}

	func prewarm_pet_assets_step(
		_pet_id: String,
		_allow_sync_fallback: bool = false,
		_perf_logger: Object = null,
		_perf_label_prefix: String = ""
	) -> bool:
		prewarm_pet_calls += 1
		return true

	func is_pet_panel_anim_ready(_pet_id: String) -> bool:
		return true

	func get_animation_contract(_pet_id: String) -> Dictionary:
		return {
			"visual_key": "companion_click_reaction_anim",
			"idle_fallback": false,
			"cols": 2,
			"rows": 2,
			"frame_count": 4,
			"frame_interval": 0.05,
			"draw_size": 108.0,
		}

	func prewarm_result_icon_path(icon_path: String) -> bool:
		cached_icons[icon_path] = true
		return true

	func has_cached_result_icon(icon_path: String) -> bool:
		return bool(cached_icons.get(icon_path, false))


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(values: Dictionary = {}) -> void:
		instances = values

	func get_cached_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value as Object if typeof(value) == TYPE_OBJECT else null

	func get_instance(key: String) -> Object:
		return get_cached_instance(key)


func _init() -> void:
	_verify_facade_ownership_boundary()
	_verify_direct_presentation_lifecycle()
	if _failures.is_empty():
		print("lingpet_guardian_enhance_presentation_coordinator_owner_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_facade_ownership_boundary() -> void:
	var facade_source := FileAccess.get_file_as_string(
		"res://scripts/lingpet/lingpet_egg_runtime.gd"
	)
	var coordinator_source := FileAccess.get_file_as_string(
		"res://scripts/lingpet/lingpet_guardian_enhance_presentation_coordinator.gd"
	)
	_expect(
		facade_source.find("LingpetGuardianEnhancePresentationCoordinator") >= 0
		and facade_source.find("_guardian_enhance_presentation.configure") >= 0,
		"egg runtime must configure the presentation owner once"
	)
	for delegated_call in [
		"_guardian_enhance_presentation.complete_roll",
		"_guardian_enhance_presentation.is_active",
		"_guardian_enhance_presentation.get_snapshot",
		"_guardian_enhance_presentation.advance",
		"_guardian_enhance_presentation.cancel",
	]:
		_expect(
			facade_source.find(delegated_call) >= 0,
			"egg runtime must retain the %s compatibility delegation" % delegated_call
		)
	for retired_facade_token in [
		"_guardian_enhance_cutin_modal_owner",
		"_guardian_enhance_cutin_modal_registry",
		"_begin_guardian_enhance_cutin_modal_time",
		"_finish_guardian_enhance_cutin_modal_time",
		"_stop_guardian_enhance_cutin_audio",
	]:
		_expect(
			facade_source.find(retired_facade_token) < 0,
			"egg runtime must not regain presentation lifecycle token %s" % retired_facade_token
		)
	for owned_behavior in [
		"_pause_skill_cooldowns_for_choice",
		"_resume_skill_cooldowns_for_choice",
		"_try_arm_resume_safety",
		"stop_lingpet_guardian_enhance_cutin_loop",
		"prewarm_registry_step",
	]:
		_expect(
			coordinator_source.find(owned_behavior) >= 0,
			"presentation coordinator must own %s" % owned_behavior
		)
	_expect(
		coordinator_source.find("var _modal_registry: Object") < 0
		and coordinator_source.find("var _modal_owner: Object") < 0
		and coordinator_source.find("var _modal_registry_ref: WeakRef") >= 0
		and coordinator_source.find("var _modal_owner_ref: WeakRef") >= 0,
		"presentation modal context must use weak references instead of retaining registry cycles"
	)


func _verify_direct_presentation_lifecycle() -> void:
	var offer_engine := FakeOfferEngine.new()
	var audio := FakeAudio.new()
	var runtime_perk_state := FakeRuntimePerkState.new()
	var host := FakeHost.new()
	var registry := FakeRegistry.new({
		"game_audio": audio,
		"runtime_perk_state": runtime_perk_state,
		"lingpet_guardian_enhance_cutin_overlay_host": host,
	})
	var owner := RefCounted.new()
	var coordinator := Coordinator.new()
	coordinator.configure(offer_engine)
	var result := {
		"accepted": true,
		"applied_index": 0,
		"feedback_text": "강화 획득",
		"result_detail": {"icon_texture_path": "res://fake_result_icon.png"},
	}
	coordinator.complete_roll(result, "maribo", "maribo", registry, "perk", owner)
	_expect(coordinator.is_active(), "accepted result must start the presentation state")
	_expect(offer_engine.mark_calls == 1, "perk-triggered result must consume one offer reservation")
	_expect(str(result.get("trigger_source", "")) == "perk", "result must retain normalized trigger source")
	_expect(str(result.get("trigger_source_label", "")) == "source:perk", "result must receive the offer-engine source label")
	_expect(runtime_perk_state.pause_calls == 1, "presentation start must pause choice-time cooldowns once")
	_expect(runtime_perk_state.last_owner == owner and runtime_perk_state.last_registry == registry, "modal pause must retain the real owner and registry")
	_expect(host.prewarm_pet_calls == 1, "presentation start must prewarm the current Guardian animation")
	_expect(host.has_cached_result_icon("res://fake_result_icon.png"), "presentation start must prewarm the result icon before draw")
	var icons: Array[String] = coordinator.build_display_candidate_icons(
		[
			{"icon_texture_path": "res://replaced_candidate.png"},
			{"icon_texture_path": ""},
			{"icon_texture_path": "res://not_cached.png"},
		],
		result,
		registry
	)
	_expect(icons == ["res://fake_result_icon.png", ""], "reel icons must use the applied result override, neutral glyph, and cache-only filtering")
	coordinator.advance(10.0, registry, "maribo")
	_expect(not coordinator.is_active(), "one oversized idle tick must still close the bounded five-phase presentation")
	_expect(audio.stop_calls == 1, "automatic close must stop presentation audio exactly once")
	_expect(runtime_perk_state.resume_calls == 1 and runtime_perk_state.safety_calls == 1, "automatic close must resume cooldowns and arm resume safety exactly once")
	_expect(bool(coordinator.get_last_result_for_tests().get("accepted", false)), "last-result test surface must survive presentation close")

	coordinator.complete_roll({"accepted": true}, "maribo", "maribo", registry, "absorb", owner)
	_expect(offer_engine.mark_calls == 1, "absorption presentation must not consume the perk offer reservation")
	_expect(coordinator.cancel(registry), "explicit cancel must close an active presentation")
	_expect(audio.stop_calls == 2, "explicit cancel must stop presentation audio exactly once")
	_expect(runtime_perk_state.resume_calls == 2 and runtime_perk_state.safety_calls == 2, "explicit cancel must resume the modal clock exactly once")
	coordinator.complete_roll({"accepted": true}, "maribo", "maribo", registry, "absorb", owner)
	coordinator.reset_presentation_state()
	_expect(not coordinator.is_active(), "field-state reset must close an active presentation")
	_expect(audio.stop_calls == 3, "field-state reset must stop presentation audio exactly once")
	_expect(runtime_perk_state.resume_calls == 3 and runtime_perk_state.safety_calls == 3, "field-state reset must resume the modal clock exactly once")
	coordinator.reset_for_tests()
	_expect(offer_engine.reset_calls == 1, "test reset must reset the configured offer lifecycle")
	_expect(coordinator.get_last_result_for_tests().is_empty(), "test reset must clear retained result state")
	# Break the fixture's deliberate registry <-> modal-state observation cycle
	# before SceneTree exits so the owner smoke remains leak-clean.
	runtime_perk_state.last_owner = null
	runtime_perk_state.last_registry = null
	registry.instances.clear()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
