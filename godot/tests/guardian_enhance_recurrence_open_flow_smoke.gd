extends SceneTree

const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const GuardianEnhanceOfferEngine := preload(
	"res://scripts/lingpet/lingpet_guardian_enhance_offer_engine.gd"
)
const LingpetEnhancementBuffStore := preload(
	"res://scripts/lingpet/lingpet_enhancement_buff_store.gd"
)

var _failures := 0


class DynamicOwner:
	extends Node
	var lingpet_owned_pet_ids: Array[String] = ["maribo"]


class PersistentGuardianRuntime:
	extends RefCounted
	var offer_engine := GuardianEnhanceOfferEngine.new()
	var candidates_enabled := true

	func build_guardian_enhance_offer(owner: Object) -> Dictionary:
		var pet_data := _open_pet_data() if candidates_enabled else _closed_pet_data()
		var offer := offer_engine.build_offer(
			owner,
			pet_data,
			0 if candidates_enabled else LingpetEnhancementBuffStore.MAX_DURATION_INCREASES,
			candidates_enabled,
			candidates_enabled
		)
		offer["pet_id"] = "maribo"
		return offer

	func mark_selected() -> void:
		offer_engine.mark_applied()

	func _open_pet_data() -> Dictionary:
		var counts := LingpetEnhancementBuffStore.get_empty_reward_counts()
		counts["active_unlocked"] = true
		counts["passive_unlocked"] = true
		counts["signature"] = LingpetEnhancementBuffStore.build_reward_signature(counts)
		return {
			"pet_id": "maribo",
			"reward_motion_style": "patrol",
			"active_skill_base_level": 1,
			"passive_skill_base_level": 1,
			"reward_counts": counts,
		}

	func _closed_pet_data() -> Dictionary:
		var counts := LingpetEnhancementBuffStore.get_empty_reward_counts()
		counts["active_unlocked"] = true
		counts["passive_unlocked"] = true
		counts["mobility_stacks"] = LingpetEnhancementBuffStore.MAX_MOBILITY_STACKS
		counts["defense_stacks"] = LingpetEnhancementBuffStore.MAX_DEFENSE_STACKS
		counts["gauge_stacks"] = LingpetEnhancementBuffStore.MAX_GAUGE_STACKS
		counts["signature"] = LingpetEnhancementBuffStore.build_reward_signature(counts)
		return {
			"pet_id": "maribo",
			"reward_motion_style": "patrol",
			"active_skill_base_level": LingpetEnhancementBuffStore.SKILL_LEVEL_MAX,
			"passive_skill_base_level": LingpetEnhancementBuffStore.SKILL_LEVEL_MAX,
			"reward_counts": counts,
		}


class FakeRegistry:
	extends RefCounted
	var lingpet_runtime: Object

	func _init(runtime: Object) -> void:
		lingpet_runtime = runtime

	func get_instance(key: String) -> Object:
		if key == "lingpet_egg_runtime":
			return lingpet_runtime
		return null


func _init() -> void:
	_verify_declined_and_selected_recurrence_through_open_flow()
	_verify_empty_candidate_screen_does_not_consume_cooldown()
	if _failures == 0:
		print("guardian_enhance_recurrence_open_flow_smoke: ok")
	quit(_failures)


func _verify_declined_and_selected_recurrence_through_open_flow() -> void:
	var owner := DynamicOwner.new()
	root.add_child(owner)
	var runtime := PersistentGuardianRuntime.new()
	var registry := FakeRegistry.new(runtime)
	var state := RuntimePerkState.new()
	var catalog := RuntimePerkCatalog.new()

	_expect(_open_screen(state, catalog, owner, registry), "screen 1 must reserve Guardian Enhancement after ownership")
	for screen_number in range(2, 5):
		_expect(not _open_screen(state, catalog, owner, registry), "declined path screen %d must stay on cooldown" % screen_number)
	_expect(_open_screen(state, catalog, owner, registry), "declined path screen 5 must guarantee recurrence")

	# Selecting the recurrence calls the production engine's apply-side seam;
	# the next cycle must keep the same exact pacing.
	runtime.mark_selected()
	for screen_number in range(2, 5):
		_expect(not _open_screen(state, catalog, owner, registry), "selected path cooldown screen %d must hide the card" % screen_number)
	_expect(_open_screen(state, catalog, owner, registry), "selected path screen 5 must guarantee recurrence")
	owner.queue_free()


func _verify_empty_candidate_screen_does_not_consume_cooldown() -> void:
	var owner := DynamicOwner.new()
	root.add_child(owner)
	var runtime := PersistentGuardianRuntime.new()
	var registry := FakeRegistry.new(runtime)
	var state := RuntimePerkState.new()
	var catalog := RuntimePerkCatalog.new()
	_expect(_open_screen(state, catalog, owner, registry), "fixture must arm the first presentation cooldown")
	runtime.candidates_enabled = false
	_expect(not _open_screen(state, catalog, owner, registry), "candidate-empty screen must suppress the card")
	runtime.candidates_enabled = true
	for cooldown_index in range(3):
		_expect(not _open_screen(state, catalog, owner, registry), "candidate-empty screen must not consume cooldown tick %d" % (cooldown_index + 1))
	_expect(_open_screen(state, catalog, owner, registry), "card must recur only after three eligible cooldown screens")
	owner.queue_free()


func _open_screen(state: Object, catalog: Object, owner: Object, registry: Object) -> bool:
	state.pending_skill_choices = 1
	state.choice_active = false
	state.current_choices.clear()
	state.current_choice_context.clear()
	state.current_perk_slot_status.clear()
	state.open_next_choice("smasher", catalog, true, owner, registry)
	for choice_value in state.current_choices:
		if choice_value is Dictionary:
			var choice := choice_value as Dictionary
			if str(choice.get("id", "")) == GuardianEnhanceOfferEngine.PERK_ID:
				_expect(str(choice.get("offer_lane", "")) == "guardian_enhance_reserved", "every live recurrence must use the protected catalog lane")
				_expect(bool(choice.get("offer_protected", false)), "every live recurrence must be protected from shuffle truncation")
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
