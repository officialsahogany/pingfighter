extends SceneTree

# expect-zero-object-leaks
const BattleRewardModalInputRouter := preload(
	"res://scripts/core/battle_reward_modal_input_router.gd"
)

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var redraw_count := 0

	func queue_redraw() -> void:
		redraw_count += 1

	func get_viewport_rect() -> Rect2:
		return Rect2(Vector2.ZERO, Vector2(1280.0, 900.0))


class FakeMythicRuntime:
	extends RefCounted

	var acquisition_active := false
	var pandora_active := false
	var acquisition_input_count := 0
	var pandora_input_count := 0
	var acquisition_registries: Array[Object] = []
	var pandora_view_sizes: Array[Vector2] = []

	func is_acquisition_cinematic_active() -> bool:
		return acquisition_active

	func handle_acquisition_cinematic_input(
		_event: InputEvent,
		registry: Object = null
	) -> bool:
		acquisition_input_count += 1
		acquisition_registries.append(registry)
		return false

	func is_pandora_legacy_selection_active() -> bool:
		return pandora_active

	func handle_pandora_legacy_selection_input(
		_event: InputEvent,
		_owner: Object,
		_registry: Object,
		view_size: Vector2
	) -> bool:
		pandora_input_count += 1
		pandora_view_sizes.append(view_size)
		return false


class FakeRuntimePerkState:
	extends RefCounted

	var angel_active := false
	var angel_input_count := 0
	var angel_view_sizes: Array[Vector2] = []

	func is_angel_blessing_modal_active() -> bool:
		return angel_active

	func handle_angel_blessing_input(
		_event: InputEvent,
		_owner: Object,
		_registry: Object,
		view_size: Vector2
	) -> bool:
		angel_input_count += 1
		angel_view_sizes.append(view_size)
		return false


class ModuleHolder:
	extends RefCounted

	var modules: Dictionary = {}

	func get_module(key: String) -> Object:
		var value: Variant = modules.get(key, null)
		return value as Object if value is Object else null


class FakeRegistry:
	extends RefCounted

	var marker := "live_registry"


func _init() -> void:
	_verify_mythic_acquisition_has_first_priority()
	_verify_pandora_follows_inactive_acquisition()
	_verify_angel_follows_inactive_item_modals()
	_verify_inactive_routes_fall_through()
	_verify_source_ownership_and_order()
	call_deferred("_finish")


func _finish() -> void:
	if _failures.is_empty():
		print("battle_reward_modal_input_router_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_mythic_acquisition_has_first_priority() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var mythic: FakeMythicRuntime = fixture["mythic"]
	var perk_state: FakeRuntimePerkState = fixture["perk_state"]
	var registry: FakeRegistry = fixture["registry"]
	var owner := FakeOwner.new()
	mythic.acquisition_active = true
	mythic.pandora_active = true
	perk_state.angel_active = true
	_expect(
		BattleRewardModalInputRouter.new().handle_input(
			InputEventKey.new(), owner, registry, Callable(holder, "get_module")
		),
		"active mythic acquisition must consume reward-modal input"
	)
	_expect(mythic.acquisition_input_count == 1, "mythic acquisition must receive the event once")
	_expect(mythic.acquisition_registries == [registry], "mythic acquisition must receive the live registry")
	_expect(mythic.pandora_input_count == 0 and perk_state.angel_input_count == 0, "mythic acquisition must stop lower reward modals")
	_expect(owner.redraw_count == 1, "active mythic acquisition must redraw even when its local result is false")
	_clear_fixture(fixture)


func _verify_pandora_follows_inactive_acquisition() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var mythic: FakeMythicRuntime = fixture["mythic"]
	var perk_state: FakeRuntimePerkState = fixture["perk_state"]
	var registry: FakeRegistry = fixture["registry"]
	var owner := FakeOwner.new()
	mythic.pandora_active = true
	perk_state.angel_active = true
	_expect(
		BattleRewardModalInputRouter.new().handle_input(
			InputEventKey.new(), owner, registry, Callable(holder, "get_module")
		),
		"active Pandora selection must consume after inactive acquisition"
	)
	_expect(mythic.acquisition_input_count == 0, "inactive acquisition must not receive Pandora input")
	_expect(mythic.pandora_input_count == 1, "Pandora selection must receive the event once")
	_expect(mythic.pandora_view_sizes == [Vector2(1280.0, 900.0)], "Pandora selection must receive live viewport size")
	_expect(perk_state.angel_input_count == 0, "Pandora selection must stop Angel input")
	_expect(owner.redraw_count == 1, "active Pandora selection must redraw even when its local result is false")
	_clear_fixture(fixture)


func _verify_angel_follows_inactive_item_modals() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var perk_state: FakeRuntimePerkState = fixture["perk_state"]
	var registry: FakeRegistry = fixture["registry"]
	var owner := FakeOwner.new()
	perk_state.angel_active = true
	_expect(
		BattleRewardModalInputRouter.new().handle_input(
			InputEventKey.new(), owner, registry, Callable(holder, "get_module")
		),
		"active Angel blessing must consume after inactive item modals"
	)
	_expect(perk_state.angel_input_count == 1, "Angel blessing must receive the event once")
	_expect(perk_state.angel_view_sizes == [Vector2(1280.0, 900.0)], "Angel blessing must receive live viewport size")
	_expect(owner.redraw_count == 1, "active Angel blessing must redraw even when its local result is false")
	_clear_fixture(fixture)


func _verify_inactive_routes_fall_through() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var registry: FakeRegistry = fixture["registry"]
	var owner := FakeOwner.new()
	_expect(
		not BattleRewardModalInputRouter.new().handle_input(
			InputEventKey.new(), owner, registry, Callable(holder, "get_module")
		),
		"inactive reward modals must fall through"
	)
	_expect(owner.redraw_count == 0, "inactive reward modals must not redraw")
	_clear_fixture(fixture)


func _verify_source_ownership_and_order() -> void:
	var router_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_reward_modal_input_router.gd"
	)
	var input_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_input_controller.gd"
	)
	_expect(router_source.find("is_acquisition_cinematic_active") < router_source.find("is_pandora_legacy_selection_active"), "mythic acquisition route must precede Pandora")
	_expect(router_source.find("is_pandora_legacy_selection_active") < router_source.find("is_angel_blessing_modal_active"), "Pandora route must precede Angel blessing")
	_expect(router_source.contains("handle_acquisition_cinematic_input(event, registry)"), "reward router must forward registry to acquisition input")
	_expect(router_source.contains("handle_pandora_legacy_selection_input("), "reward router must own Pandora input fanout")
	_expect(router_source.contains("handle_angel_blessing_input("), "reward router must own Angel input fanout")
	_expect(input_source.contains("BattleRewardModalInputRouter.new()"), "scene input controller must compose reward-modal router")
	_expect(input_source.contains("_reward_modal_input_router.handle_input("), "scene input controller must delegate reward-modal input once")
	_expect(input_source.find("_handle_runtime_perk_choice_input(") < input_source.find("_reward_modal_input_router.handle_input("), "runtime-perk choice must stay above reward modals")
	_expect(input_source.find("_reward_modal_input_router.handle_input(") < input_source.find("var overlay_input:"), "reward modals must stay above ordinary overlay input")
	_expect(not input_source.contains("func _handle_mythic_acquisition_input"), "scene input controller must not retain mythic acquisition policy")
	_expect(not input_source.contains("func _handle_pandora_legacy_selection_input"), "scene input controller must not retain Pandora input policy")
	_expect(not input_source.contains("func _handle_angel_blessing_input"), "scene input controller must not retain Angel input policy")


func _build_fixture() -> Dictionary:
	var holder := ModuleHolder.new()
	var mythic := FakeMythicRuntime.new()
	var perk_state := FakeRuntimePerkState.new()
	var registry := FakeRegistry.new()
	holder.modules = {
		"mythic_item_runtime": mythic,
		"runtime_perk_state": perk_state,
	}
	return {
		"holder": holder,
		"mythic": mythic,
		"perk_state": perk_state,
		"registry": registry,
	}


func _clear_fixture(fixture: Dictionary) -> void:
	var holder: ModuleHolder = fixture["holder"]
	holder.modules.clear()
	fixture.clear()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
