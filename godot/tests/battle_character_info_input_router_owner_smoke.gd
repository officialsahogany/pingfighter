extends SceneTree

# expect-zero-object-leaks
const BattleCharacterInfoInputRouter := preload(
	"res://scripts/core/battle_character_info_input_router.gd"
)

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var redraw_count := 0
	var lingpet_slots: Array = ["maribo", "lunabi"]

	func queue_redraw() -> void:
		redraw_count += 1


class FakeModalGate:
	extends RefCounted

	var character_info_active := false

	func is_character_info_active(_module_getter: Callable) -> bool:
		return character_info_active


class FakeCharacterInfo:
	extends RefCounted

	var handled_result := true
	var redraw_requested := false
	var handle_count := 0
	var prewarm_count := 0
	var open_count := 0
	var last_owner: Object = null
	var last_registry: Object = null
	var last_module_getter := Callable()
	var last_view_size := Vector2.ZERO
	var last_lingpet_ids: Array[String] = []

	func handle_input(
		_event: InputEvent,
		owner: Object,
		registry: Object,
		view_size: Vector2
	) -> bool:
		handle_count += 1
		last_owner = owner
		last_registry = registry
		last_view_size = view_size
		return handled_result

	func consume_input_redraw_request() -> bool:
		var requested := redraw_requested
		redraw_requested = false
		return requested

	func prewarm_assets(
		owner: Object,
		registry: Object,
		module_getter: Callable,
		_force: bool,
		view_size: Vector2,
		lingpet_ids: Array
	) -> void:
		prewarm_count += 1
		last_owner = owner
		last_registry = registry
		last_module_getter = module_getter
		last_view_size = view_size
		last_lingpet_ids.assign(lingpet_ids)

	func open(owner: Object, registry: Object) -> void:
		open_count += 1
		last_owner = owner
		last_registry = registry


class FakeLegacyCharacterInfo:
	extends RefCounted

	var open_count := 0

	func open() -> void:
		open_count += 1


class FakePauseMenu:
	extends RefCounted

	var close_count := 0

	func close() -> void:
		close_count += 1


class FakeGameAudio:
	extends RefCounted

	var character_info_toggle_count := 0

	func play_character_info_toggle() -> void:
		character_info_toggle_count += 1


class FakeOverlayFrame:
	extends RefCounted

	var handled_result := true
	var queue_count := 0
	var last_owner: Object = null
	var last_registry: Object = null
	var last_module_getter := Callable()
	var last_force := false

	func queue_character_info_overlay_redraw(
		owner: Object,
		registry: Object,
		module_getter: Callable,
		force: bool
	) -> bool:
		queue_count += 1
		last_owner = owner
		last_registry = registry
		last_module_getter = module_getter
		last_force = force
		return handled_result


class ModuleHolder:
	extends RefCounted

	var modules: Dictionary = {}

	func get_module(key: String) -> Object:
		var value: Variant = modules.get(key, null)
		return value as Object if value is Object else null


func _init() -> void:
	_verify_active_input_respects_redraw_gate()
	_verify_active_input_falls_back_to_owner_redraw()
	_verify_inactive_overlay_falls_through()
	_verify_tab_closes_pause_prewarms_and_opens()
	_verify_pause_action_supports_legacy_open_signature()
	_verify_pause_action_forwards_registry_for_shared_open_effects()
	_verify_source_ownership()
	call_deferred("_finish")


func _finish() -> void:
	if _failures.is_empty():
		print("battle_character_info_input_router_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_active_input_respects_redraw_gate() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var gate: FakeModalGate = fixture["gate"]
	var character_info: FakeCharacterInfo = fixture["character_info"]
	var overlay_frame: FakeOverlayFrame = fixture["overlay_frame"]
	var owner := FakeOwner.new()
	var registry := RefCounted.new()
	gate.character_info_active = true
	var router := BattleCharacterInfoInputRouter.new()
	var first_consumed: bool = router.handle_active_input(
		InputEventMouseMotion.new(),
		owner,
		registry,
		Callable(holder, "get_module"),
		Vector2(1280.0, 720.0)
	)
	_expect(first_consumed, "active character-info overlay must consume input")
	_expect(character_info.handle_count == 1, "active overlay must receive input once")
	_expect(overlay_frame.queue_count == 0, "input without redraw request must not redraw")
	_expect(owner.redraw_count == 0, "redraw-gated input must not hit owner fallback")

	character_info.redraw_requested = true
	var second_consumed: bool = router.handle_active_input(
		InputEventMouseMotion.new(),
		owner,
		registry,
		Callable(holder, "get_module"),
		Vector2(1280.0, 720.0)
	)
	_expect(second_consumed, "redraw-worthy character-info input must remain consumed")
	_expect(character_info.handle_count == 2, "second active input must reach overlay")
	_expect(overlay_frame.queue_count == 1, "redraw request must use overlay-frame redraw path")
	_expect(overlay_frame.last_owner == owner, "overlay redraw must receive battle owner")
	_expect(overlay_frame.last_registry == registry, "overlay redraw must receive registry")
	_expect(overlay_frame.last_force, "overlay redraw must preserve forced character-info redraw")
	_expect(owner.redraw_count == 0, "successful overlay redraw must avoid owner fallback")
	_clear_fixture(fixture)


func _verify_active_input_falls_back_to_owner_redraw() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var gate: FakeModalGate = fixture["gate"]
	var character_info: FakeCharacterInfo = fixture["character_info"]
	var overlay_frame: FakeOverlayFrame = fixture["overlay_frame"]
	var owner := FakeOwner.new()
	gate.character_info_active = true
	character_info.redraw_requested = true
	overlay_frame.handled_result = false
	var consumed: bool = BattleCharacterInfoInputRouter.new().handle_active_input(
		InputEventKey.new(),
		owner,
		holder,
		Callable(holder, "get_module"),
		Vector2(760.0, 750.0)
	)
	_expect(consumed, "active overlay must consume input when redraw facade declines")
	_expect(owner.redraw_count == 1, "declined overlay redraw must fall back to owner redraw")
	_clear_fixture(fixture)


func _verify_inactive_overlay_falls_through() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var character_info: FakeCharacterInfo = fixture["character_info"]
	var consumed: bool = BattleCharacterInfoInputRouter.new().handle_active_input(
		InputEventKey.new(),
		FakeOwner.new(),
		holder,
		Callable(holder, "get_module"),
		Vector2(760.0, 750.0)
	)
	_expect(not consumed, "inactive character-info overlay must fall through")
	_expect(character_info.handle_count == 0, "inactive overlay must not receive input")
	_clear_fixture(fixture)


func _verify_tab_closes_pause_prewarms_and_opens() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var character_info: FakeCharacterInfo = fixture["character_info"]
	var pause_menu: FakePauseMenu = fixture["pause_menu"]
	var game_audio: FakeGameAudio = fixture["game_audio"]
	var overlay_frame: FakeOverlayFrame = fixture["overlay_frame"]
	var owner := FakeOwner.new()
	var registry := RefCounted.new()
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_TAB
	var consumed: bool = BattleCharacterInfoInputRouter.new().handle_open_shortcut(
		event,
		owner,
		registry,
		Callable(holder, "get_module"),
		Vector2(1600.0, 900.0)
	)
	_expect(consumed, "TAB shortcut must be consumed")
	_expect(pause_menu.close_count == 1, "TAB open must close pause menu first")
	_expect(character_info.prewarm_count == 1, "TAB open must prewarm character info once")
	_expect(character_info.last_view_size == Vector2(1600.0, 900.0), "prewarm must receive current view size")
	_expect(character_info.last_lingpet_ids == ["maribo", "lunabi"], "prewarm must include equipped Guardian Spirit slots only")
	_expect(character_info.open_count == 1, "TAB open must open character info once")
	# 열기 큐 소유자는 CharacterInfoOverlay.open() 이다. 라우터가 다시 재생하면
	# 전투 TAB 만 두 번 울리고 광장 TAB / 일시정지 진입은 여전히 무음으로 남는다.
	_expect(game_audio.character_info_toggle_count == 0, "router must not play the paper-scroll cue itself — the shared overlay open() owns it")
	_expect(character_info.last_owner == owner, "two-argument open must receive owner")
	_expect(character_info.last_registry == registry, "two-argument open must receive registry")
	_expect(overlay_frame.queue_count == 1, "TAB open must request character-info overlay redraw")
	_expect(owner.redraw_count == 0, "successful overlay redraw must avoid direct owner redraw")
	_clear_fixture(fixture)


func _verify_pause_action_supports_legacy_open_signature() -> void:
	var holder := ModuleHolder.new()
	var character_info := FakeLegacyCharacterInfo.new()
	holder.modules["character_info_overlay"] = character_info
	BattleCharacterInfoInputRouter.new().open_from_pause(
		FakeOwner.new(),
		holder,
		Callable(holder, "get_module"),
		Vector2(760.0, 750.0)
	)
	_expect(character_info.open_count == 1, "pause action must support legacy zero-argument open")
	holder.modules.clear()


# 일시정지 메뉴 진입이 owner+registry 를 실어 보내야 오버레이가 game_audio 를 해석해
# 열기 큐와 BGM 먹먹함을 켤 수 있다. registry 를 흘리지 않으면 둘 다 조용히 죽는다.
func _verify_pause_action_forwards_registry_for_shared_open_effects() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var character_info: FakeCharacterInfo = fixture["character_info"]
	var owner := FakeOwner.new()
	var registry := RefCounted.new()
	BattleCharacterInfoInputRouter.new().open_from_pause(
		owner,
		registry,
		Callable(holder, "get_module"),
		Vector2(1600.0, 900.0)
	)
	_expect(character_info.open_count == 1, "pause action must open character info once")
	_expect(character_info.last_owner == owner, "pause action must forward owner to the shared open path")
	_expect(character_info.last_registry == registry, "pause action must forward registry so open() can resolve game_audio")
	_clear_fixture(fixture)


func _verify_source_ownership() -> void:
	var router_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_character_info_input_router.gd"
	)
	var input_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_overlay_input_controller.gd"
	)
	var pause_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_pause_menu_input_router.gd"
	)
	_expect(router_source.contains("CharacterInfoLingpetPrewarmFilter.get_slot_prewarm_pet_ids"), "router must own Guardian Spirit prewarm filtering")
	_expect(router_source.contains("consume_input_redraw_request"), "router must own character-info input redraw gating")
	_expect(router_source.contains("queue_character_info_overlay_redraw"), "router must own overlay-frame redraw forwarding")
	_expect(input_source.contains("BattleCharacterInfoInputRouter.new()"), "overlay controller must compose character-info router")
	_expect(input_source.contains("_character_info_input_router.handle_active_input("), "overlay controller must delegate active character-info input")
	_expect(input_source.contains("_character_info_input_router.handle_open_shortcut("), "overlay controller must delegate TAB opening")
	_expect(pause_source.contains("_character_info_input_router.open_from_pause("), "pause action must reuse character-info open policy")
	_expect(not input_source.contains("func _prewarm_character_info"), "overlay controller must not retain character-info prewarm policy")
	_expect(not input_source.contains("consume_input_redraw_request"), "overlay controller must not retain character-info redraw policy")


func _build_fixture() -> Dictionary:
	var holder := ModuleHolder.new()
	var gate := FakeModalGate.new()
	var character_info := FakeCharacterInfo.new()
	var pause_menu := FakePauseMenu.new()
	var overlay_frame := FakeOverlayFrame.new()
	var game_audio := FakeGameAudio.new()
	holder.modules = {
		"battle_scene_modal_gate_controller": gate,
		"character_info_overlay": character_info,
		"pause_menu_overlay": pause_menu,
		"game_audio": game_audio,
		"battle_scene_overlay_frame_controller": overlay_frame,
	}
	return {
		"holder": holder,
		"gate": gate,
		"character_info": character_info,
		"pause_menu": pause_menu,
		"game_audio": game_audio,
		"overlay_frame": overlay_frame,
	}


func _clear_fixture(fixture: Dictionary) -> void:
	var holder: ModuleHolder = fixture["holder"]
	holder.modules.clear()
	fixture.clear()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
