extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemDebugSpawnMenu := preload("res://scripts/items/active_item_debug_spawn_menu.gd")
const ActiveItemEffectRouter := preload("res://scripts/items/active_item_effect_router.gd")
const ActiveItemPickupFeedback := preload("res://scripts/items/active_item_pickup_feedback.gd")
const MythicItemPandoraLegacyRuntime := preload("res://scripts/items/mythic_item_pandora_legacy_runtime.gd")
const PandoraLegacyPoolBuilder := preload("res://scripts/items/pandora_legacy_pool_builder.gd")

const ITEM_ID := "strange_vial"

var _failures: Array[String] = []


class FakeEffectController:
	extends RefCounted

	var activation_count := 0

	func activate_strange_vial(_owner: Object, _registry: Object) -> bool:
		activation_count += 1
		return true


func _init() -> void:
	_verify_acquisition_surfaces_are_closed()
	_verify_stale_payload_cannot_activate()

	if _failures.is_empty():
		print("active_item_strange_vial_removed_smoke: ok")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_acquisition_surfaces_are_closed() -> void:
	var catalog := ActiveItemCatalog.new()
	_expect(ActiveItemCatalog.is_acquisition_disabled(ITEM_ID), "Strange Vial should be retired at the public catalog boundary")
	_expect(not ActiveItemCatalog.FIELD_SPAWN_ORDER.has(ITEM_ID), "Strange Vial should not enter ordinary field drops")
	_expect(catalog.build_item_by_name(ITEM_ID).is_empty(), "Strange Vial should not build through the public catalog")
	_expect(not ActiveItemDebugSpawnMenu.DEBUG_ENTRY_ORDER.has(ITEM_ID), "Strange Vial should not appear in the F2 item menu")
	_expect(not ActiveItemPickupFeedback.ITEM_NAME_KO.has(ITEM_ID), "Strange Vial should not keep a pickup-display entry")
	_expect(not MythicItemPandoraLegacyRuntime.ACTIVE_ITEM_KOREAN_NAMES.has(ITEM_ID), "Strange Vial should not keep a Pandora card title")

	var active_pool: Array = PandoraLegacyPoolBuilder.new().build_active_pool()
	for item_value in active_pool:
		if item_value is Dictionary:
			_expect(str((item_value as Dictionary).get("name", "")) != ITEM_ID, "Strange Vial should not enter Pandora active choices")


func _verify_stale_payload_cannot_activate() -> void:
	var effect_controller := FakeEffectController.new()
	var applied: bool = ActiveItemEffectRouter.new().apply_item_effect(
		{"name": ITEM_ID, "effect": ITEM_ID},
		null,
		null,
		effect_controller,
		null
	)
	_expect(not applied, "A stale Strange Vial payload should be rejected by the effect router")
	_expect(effect_controller.activation_count == 0, "A stale Strange Vial payload should not reach the old activation helper")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
