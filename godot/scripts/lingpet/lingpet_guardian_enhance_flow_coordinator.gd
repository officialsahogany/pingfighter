extends RefCounted

const LingpetEnhancementBuffStore := preload(
	"res://scripts/lingpet/lingpet_enhancement_buff_store.gd"
)
const LingpetGuardianEnhanceApplier := preload(
	"res://scripts/lingpet/lingpet_guardian_enhance_applier.gd"
)
const LingpetGuardianEnhanceResultDetail := preload(
	"res://scripts/lingpet/lingpet_guardian_enhance_result_detail.gd"
)

var _offer_engine: Object = null
var _presentation: Object = null
var _guardian_run_context_coordinator: Object = null
var _guardian_run_state: Object = null
var _collection_state: Object = null
var _current_profile: Object = null
var _loadout_state: Object = null
var _snapshot_builder: Object = null
var _runtime_facade_ref: WeakRef = null
var _roll_rng_for_tests: RandomNumberGenerator = null


func configure(
	offer_engine: Object,
	presentation: Object,
	guardian_run_context_coordinator: Object,
	guardian_run_state: Object,
	collection_state: Object,
	current_profile: Object,
	loadout_state: Object,
	snapshot_builder: Object,
	runtime_facade: Object
) -> void:
	_offer_engine = offer_engine
	_presentation = presentation
	_guardian_run_context_coordinator = guardian_run_context_coordinator
	_guardian_run_state = guardian_run_state
	_collection_state = collection_state
	_current_profile = current_profile
	_loadout_state = loadout_state
	_snapshot_builder = snapshot_builder
	_runtime_facade_ref = weakref(runtime_facade) if runtime_facade != null else null


func reset_for_tests() -> void:
	_roll_rng_for_tests = null
	if _presentation != null and _presentation.has_method("reset_for_tests"):
		_presentation.reset_for_tests()


func set_roll_rng_for_tests(rng: RandomNumberGenerator) -> void:
	_roll_rng_for_tests = rng


func get_offer_state_for_tests() -> Dictionary:
	if _offer_engine != null and _offer_engine.has_method("get_state_for_tests"):
		return _offer_engine.get_state_for_tests()
	return {}


func build_offer(owner: Object, current_pet_id: String) -> Dictionary:
	var pet_id := resolve_pet_id(owner, current_pet_id)
	if pet_id == "":
		return {
			"offer_allowed": false,
			"reserve": false,
			"blocked_reason": "no_owned_guardian",
			"candidates": [],
		}
	_configure_reward_context(pet_id, current_pet_id)
	var skill_availability: Dictionary = (
		_guardian_run_state.get_guardian_enhancement_skill_availability(pet_id)
	)
	var result: Dictionary = _offer_engine.build_offer(
		owner,
		_guardian_run_state.get_pet_data(pet_id),
		_guardian_run_state.get_duration_increase_count(),
		bool(skill_availability.get("has_second_active", false)),
		bool(skill_availability.get("has_second_passive", false))
	)
	result["pet_id"] = pet_id
	return result


func apply_random_roll(
	candidates: Array,
	owner: Object,
	registry: Object,
	trigger_source: String,
	current_pet_id: String,
	rng_override: RandomNumberGenerator = null
) -> Dictionary:
	var pet_id := resolve_pet_id(owner, current_pet_id)
	if pet_id == "":
		return {
			"accepted": false,
			"modal_started": false,
			"blocked_reason": "no_owned_guardian",
		}
	var result: Dictionary = LingpetGuardianEnhanceApplier.resolve_random_roll(
		candidates,
		Callable(self, "can_apply_candidate").bind(pet_id),
		Callable(self, "apply_candidate").bind(owner, registry, pet_id, current_pet_id),
		Callable(self, "apply_duration_fallback").bind(owner, registry),
		rng_override if rng_override != null else _roll_rng_for_tests
	)
	result["display_candidate_icons"] = _presentation.build_display_candidate_icons(
		candidates,
		result,
		registry
	)
	complete_roll(result, pet_id, registry, trigger_source, owner, current_pet_id)
	return result


func build_live_candidates(owner: Object, current_pet_id: String) -> Array:
	var pet_id := resolve_pet_id(owner, current_pet_id)
	if pet_id == "":
		return []
	_configure_reward_context(pet_id, current_pet_id)
	var skill_availability: Dictionary = (
		_guardian_run_state.get_guardian_enhancement_skill_availability(pet_id)
	)
	var raw_candidates: Array[Dictionary] = (
		_guardian_run_state.build_guardian_enhancement_candidates(
			pet_id,
			bool(skill_availability.get("has_second_active", false)),
			bool(skill_availability.get("has_second_passive", false))
		)
	)
	var candidates: Array = []
	for candidate in raw_candidates:
		candidates.append(_offer_engine.localize_candidate(candidate))
	return candidates


func trigger_from_absorption(
	owner: Object,
	registry: Object,
	current_pet_id: String
) -> Dictionary:
	var pet_id := resolve_pet_id(owner, current_pet_id)
	if pet_id == "":
		return {"accepted": false, "blocked_reason": "no_owned_guardian"}
	return apply_random_roll(
		build_live_candidates(owner, current_pet_id),
		owner,
		registry,
		"absorb",
		current_pet_id
	)


func can_apply_candidate(candidate: Dictionary, pet_id: String) -> bool:
	var skill_availability: Dictionary = (
		_guardian_run_state.get_guardian_enhancement_skill_availability(pet_id)
	)
	return _guardian_run_state.can_apply_guardian_enhancement(
		pet_id,
		candidate,
		bool(skill_availability.get("has_second_active", false)),
		bool(skill_availability.get("has_second_passive", false))
	)


func apply_candidate(
	candidate: Dictionary,
	owner: Object,
	registry: Object,
	pet_id: String,
	current_pet_id: String
) -> Dictionary:
	var target_pet_id := pet_id.strip_edges().to_lower()
	if target_pet_id == "":
		target_pet_id = resolve_pet_id(owner, current_pet_id)
	var before_pet_data: Dictionary = _guardian_run_state.get_pet_data(target_pet_id)
	var before_loadout: Dictionary = _loadout_state.get_stored_loadout(target_pet_id)
	var skill_availability: Dictionary = (
		_guardian_run_state.get_guardian_enhancement_skill_availability(target_pet_id)
	)
	var result: Dictionary = _guardian_run_state.apply_guardian_enhancement(
		target_pet_id,
		candidate,
		bool(skill_availability.get("has_second_active", false)),
		bool(skill_availability.get("has_second_passive", false))
	)
	if not bool(result.get("accepted", false)):
		return result
	_guardian_run_context_coordinator.handle_enhancement_gain(
		target_pet_id,
		registry,
		current_pet_id,
		_current_profile,
		_loadout_state,
		_guardian_run_state,
		_snapshot_builder
	)
	if str(candidate.get("type", "")) in [
		LingpetEnhancementBuffStore.REWARD_TYPE_ACTIVE_UNLOCK,
		LingpetEnhancementBuffStore.REWARD_TYPE_PASSIVE_UNLOCK,
		LingpetEnhancementBuffStore.REWARD_TYPE_SECOND_ACTIVE_UNLOCK,
		LingpetEnhancementBuffStore.REWARD_TYPE_SECOND_PASSIVE_UNLOCK,
	]:
		_apply_current_loadout(owner, registry)
	var after_pet_data: Dictionary = _guardian_run_state.get_pet_data(target_pet_id)
	var after_loadout: Dictionary = _loadout_state.get_stored_loadout(target_pet_id)
	var detail := LingpetGuardianEnhanceResultDetail.build(
		candidate,
		target_pet_id,
		before_pet_data,
		after_pet_data,
		before_loadout,
		after_loadout
	)
	result["result_detail"] = detail
	_copy_detail_fields(result, detail)
	_invalidate_runtime_snapshot()
	_sync_owner(owner, registry)
	return result


func apply_duration_fallback(owner: Object, registry: Object) -> Dictionary:
	var result: Dictionary = _guardian_run_state.apply_guardian_enhance_duration_fallback()
	if bool(result.get("accepted", false)):
		var detail := LingpetGuardianEnhanceResultDetail.build_fallback()
		result["result_detail"] = detail
		_copy_detail_fields(result, detail)
		_invalidate_runtime_snapshot()
		_sync_owner(owner, registry)
	return result


func complete_roll(
	result: Dictionary,
	display_pet_id: String,
	registry: Object,
	trigger_source: String,
	owner: Object,
	current_pet_id: String
) -> void:
	_presentation.complete_roll(
		result,
		display_pet_id,
		current_pet_id,
		registry,
		trigger_source,
		owner
	)


func resolve_pet_id(owner: Object, current_pet_id: String) -> String:
	_collection_state.sync_from_owner(owner)
	var owned: Array[String] = _collection_state.get_owned_pet_ids_from_owner(owner)
	if owned.is_empty():
		return ""
	var normalized_current: String = _current_profile.normalize_pet_id(current_pet_id)
	if normalized_current != "" and owned.has(normalized_current):
		return normalized_current
	var slots: Array[String] = _collection_state.get_battle_slots_from_owner(owner)
	var active_index: int = _collection_state.get_active_slot_index_from_owner(owner)
	if active_index >= 0 and active_index < slots.size():
		var slot_pet: String = _current_profile.normalize_pet_id(str(slots[active_index]))
		if slot_pet != "":
			return slot_pet
	return _current_profile.normalize_pet_id(str(owned[0]))


func _configure_reward_context(pet_id: String, current_pet_id: String) -> void:
	_guardian_run_context_coordinator.configure(
		pet_id,
		current_pet_id,
		_current_profile,
		_loadout_state,
		_guardian_run_state
	)


static func _copy_detail_fields(result: Dictionary, detail: Dictionary) -> void:
	for key in [
		"skill_id",
		"skill_display_name",
		"previous_level",
		"new_level",
		"icon_texture_path",
		"stat_amount",
		"stat_unit",
	]:
		if detail.has(key):
			result[key] = detail.get(key)


func _apply_current_loadout(owner: Object, registry: Object) -> void:
	var runtime_facade := _get_runtime_facade()
	if runtime_facade != null and runtime_facade.has_method("_apply_current_loadout"):
		runtime_facade.call("_apply_current_loadout", owner, true, false, registry)


func _invalidate_runtime_snapshot() -> void:
	var runtime_facade := _get_runtime_facade()
	if runtime_facade != null and runtime_facade.has_method("_invalidate_runtime_snapshot_cache"):
		runtime_facade.call("_invalidate_runtime_snapshot_cache")


func _sync_owner(owner: Object, registry: Object) -> void:
	var runtime_facade := _get_runtime_facade()
	if runtime_facade != null and runtime_facade.has_method("_sync_owner"):
		runtime_facade.call("_sync_owner", owner, registry)


func _get_runtime_facade() -> Object:
	if _runtime_facade_ref == null:
		return null
	var value: Variant = _runtime_facade_ref.get_ref()
	if typeof(value) == TYPE_OBJECT and value != null and is_instance_valid(value):
		return value as Object
	return null
