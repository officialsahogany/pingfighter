extends SceneTree

const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

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


class FakeRegistry:
	extends RefCounted

	func get_instance(_key: String) -> Object:
		return null


class CapturingCatalog:
	extends RefCounted

	var last_owner: Object = null
	var last_registry: Object = null

	func get_choices(
		_character_type: String,
		_runtime_skill_levels: Dictionary,
		_exclude_instant: bool = false,
		_target_choice_count: int = 3,
		owner: Object = null,
		registry: Object = null
	) -> Array:
		last_owner = owner
		last_registry = registry
		return [{
			"id": "dash_module_control",
			"name": "gate probe",
			"description": "gate probe",
		}]


func _init() -> void:
	_run()


func _run() -> void:
	_verify_lingpet_gated_choices_filter_on_owned_state()
	_verify_runtime_choice_modal_threads_owner_and_registry()
	_verify_gate_is_before_shuffle_and_academy_preview_threads_owner()

	if _failures.is_empty():
		print("runtime_perk_lingpet_owned_gate_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_lingpet_gated_choices_filter_on_owned_state() -> void:
	var catalog := RuntimePerkCatalog.new()
	var empty_owner := FakeOwner.new()
	var choices := _build_lingpet_gate_probe_choices()
	var filtered_empty: Array = catalog._filter_lingpet_owned_gate(choices, empty_owner)
	_expect(_choice_ids(filtered_empty) == ["dash_module_control"], "owned-empty owner should suppress ring-core and chip choices")

	var owned_owner := FakeOwner.new()
	owned_owner.lingpet_owned_pet_ids = ["maribo"]
	var filtered_owned: Array = catalog._filter_lingpet_owned_gate(choices, owned_owner)
	_expect(_choice_ids(filtered_owned) == ["lingpet_ring_core_upgrade", "dash_module_control", "lingpet_affinity_chip"], "owned lingpet owner should keep ring-core and chip choices")

	var companion_owner := FakeOwner.new()
	companion_owner.lingpet_state = "companion"
	companion_owner.lingpet_id = "maribo"
	var filtered_companion: Array = catalog._filter_lingpet_owned_gate(choices, companion_owner)
	_expect(_choice_ids(filtered_companion) == ["lingpet_ring_core_upgrade", "dash_module_control", "lingpet_affinity_chip"], "active companion state should use the same owned predicate as tutorial egg gating")


func _verify_runtime_choice_modal_threads_owner_and_registry() -> void:
	var owner := FakeOwner.new()
	owner.lingpet_owned_pet_ids = ["maribo"]
	var registry := FakeRegistry.new()
	var catalog := CapturingCatalog.new()
	var state := RuntimePerkState.new()
	state.pending_skill_choices = 1
	state.open_next_choice("smasher", catalog, false, owner, registry)
	_expect(catalog.last_owner == owner, "runtime perk modal should pass owner to catalog.get_choices")
	_expect(catalog.last_registry == registry, "runtime perk modal should pass registry to catalog.get_choices")


func _verify_gate_is_before_shuffle_and_academy_preview_threads_owner() -> void:
	var catalog_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_catalog.gd")
	var filter_index := catalog_source.find("choices = _filter_lingpet_owned_gate(choices, owner)")
	var reserve_index := catalog_source.find("_extract_lingpet_ring_core_reserved_choices", filter_index)
	var shuffle_index := catalog_source.find("choices.shuffle()", filter_index)
	var truncate_index := catalog_source.find("for choice in choices:", filter_index)
	_expect(filter_index >= 0, "runtime perk catalog should filter lingpet-gated choices")
	_expect(reserve_index > filter_index, "ring-core early reservation should run after the lingpet owned gate")
	_expect(shuffle_index > reserve_index, "ring-core early reservation should split force-included cards before shuffle")
	_expect(shuffle_index > filter_index, "lingpet owned gate should run before choice shuffle")
	_expect(truncate_index > shuffle_index, "choice truncation should happen after lingpet owned gate, reservation, and shuffle")

	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	_expect(
		state_source.find("catalog.get_choices(character_type, runtime_skill_levels, exclude_instant, target_choice_count, owner, registry)") >= 0,
		"runtime perk state should thread owner/registry into get_choices"
	)

	var academy_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_academy_transactions.gd")
	_expect(
		academy_source.find("_get_lesson_choices(catalog, character_type, runtime_state, owner, registry)") >= 0,
		"plaza academy preview should pass owner/registry into its lesson choice helper"
	)
	_expect(
		academy_source.find("catalog.get_choices(character_type, runtime_levels, true, 3, owner, registry)") >= 0,
		"plaza academy lesson choices should thread owner/registry into get_choices"
	)


func _build_lingpet_gate_probe_choices() -> Array:
	return [
		{"id": "lingpet_ring_core_upgrade"},
		{"id": "dash_module_control"},
		{"id": "lingpet_affinity_chip"},
	]


func _choice_ids(choices: Array) -> Array[String]:
	var ids: Array[String] = []
	for value in choices:
		if value is Dictionary:
			ids.append(str((value as Dictionary).get("id", "")))
	return ids


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
