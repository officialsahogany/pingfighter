extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemDebugSpawnMenu := preload("res://scripts/items/active_item_debug_spawn_menu.gd")
const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemEffectRouter := preload("res://scripts/items/active_item_effect_router.gd")
const ActiveItemFieldSpawnPool := preload("res://scripts/items/active_item_field_spawn_pool.gd")
const ActiveItemSlotController := preload("res://scripts/items/active_item_slot_controller.gd")
const LanguageSettingsData := preload("res://scripts/core/language_settings_data.gd")
const MysticDiceRoller := preload("res://scripts/characters/mystic_dice_roller.gd")
const PandoraLegacyPoolBuilder := preload("res://scripts/items/pandora_legacy_pool_builder.gd")
const PlazaGachaTransactions := preload("res://scripts/plaza/plaza_gacha_transactions.gd")
const RuntimePerkMysticDiceRuntimeState := preload(
	"res://scripts/characters/runtime_perk_mystic_dice_runtime_state.gd"
)
const RuntimePerkResumeSafety := preload("res://scripts/characters/runtime_perk_resume_safety.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends Node
	var active_item_slots: Array = []
	# 리줌 안전장치가 실제로 읽고 되쓰는 필드 — 선언하지 않으면 owner.set()이
	# 조용한 no-op이 되어 무장 여부를 결과로 확인할 수 없다.
	var ball_vel: Vector2 = Vector2(0.0, 6.0)
	var player_collision_cooldown: float = 0.0


class FakeRegistry:
	extends RefCounted
	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Object:
		return instances.get(key, null)


# 실 경로의 쿨다운 일시정지는 이 드라이버를 통해서만 걸린다 — 레지스트리에
# 없으면 pause()가 조용히 조기 반환하므로, 세워두지 않으면 공허-GREEN이 된다.
class FakeSkillTooltipDriver:
	extends RefCounted
	var pause_calls := 0
	var resume_calls := 0

	func pause_skill_cooldowns(_owner: Object, _registry: Object) -> void:
		pause_calls += 1

	func resume_skill_cooldowns(_owner: Object, _registry: Object) -> void:
		resume_calls += 1


class FakeOwnerSync:
	extends RefCounted
	var owner_sync_calls := 0
	var mythic_sync_calls := 0

	func sync_owner_effects_from_runtime_state(
		_runtime_state: Object,
		_owner: Object,
		_registry: Object
	) -> void:
		owner_sync_calls += 1

	func refresh_mythic_runtime_perk_consumers_from_runtime_state(
		_runtime_state: Object,
		_owner: Object,
		_registry: Object
	) -> void:
		mythic_sync_calls += 1


class ItemOriginRuntime:
	extends RefCounted
	var current_choices: Array = []
	var _owner_sync_flow: Object = FakeOwnerSync.new()
	# 실물 안전장치를 물려 커밋 후 "무장했다"가 아니라 "공이 실제로 얼었다"를
	# 단언한다(호출 카운트만 세는 Fake 씰의 공허-GREEN 방지).
	var _resume_safety: Object = RuntimePerkResumeSafety.new()
	var pause_calls := 0
	var resume_calls := 0
	var choice_active := false
	var angel_modal_active := false

	func is_choice_active() -> bool:
		return choice_active

	func is_angel_blessing_modal_active() -> bool:
		return angel_modal_active

	func _pause_skill_cooldowns_for_choice(_owner: Object, _registry: Object) -> void:
		pause_calls += 1

	func _resume_skill_cooldowns_for_choice() -> void:
		resume_calls += 1

	func _try_arm_resume_safety(owner: Object, registry: Object) -> void:
		_resume_safety.try_arm_from_runtime_state(self, owner, registry)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_catalog_and_icon()
	_verify_acquisition_routes()
	_verify_localized_names()
	_verify_slot_use_opens_modal_and_consumes_item()
	_verify_blocked_open_keeps_item_and_cooldown()
	_verify_item_origin_commit_skips_choice_finish()
	_verify_item_modal_pauses_and_rearms_gameplay_clocks()
	if _failures.is_empty():
		print("mystic_dice_active_item_smoke: ok")
		call_deferred("_finish", 0)
	else:
		for failure: String in _failures:
			push_error(failure)
		call_deferred("_finish", 1)


func _finish(exit_code: int) -> void:
	# Let the deferred test stack and its temporary catalog/resources unwind
	# before the SceneTree exits. Quitting inside _run() leaves those locals
	# alive during ResourceCache teardown and produces a false RED.
	await process_frame
	quit(exit_code)


func _verify_catalog_and_icon() -> void:
	var item: Dictionary = ActiveItemCatalog.new().build_item_by_name("mystic_dice")
	_expect(str(item.get("type", "")) == "active", "Mystic Dice should be an active item")
	_expect(str(item.get("effect", "")) == "mystic_dice", "Mystic Dice should route its effect id")
	_expect(is_equal_approx(float(item.get("chance", 0.0)), 0.005), "Mystic Dice should use the legacy rare 0.005 weight")
	_expect(bool(item.get("consumable", false)), "Mystic Dice should be consumable")
	_expect("mystic_dice" in ActiveItemCatalog.FIELD_SPAWN_ORDER, "field drops should include Mystic Dice")
	_expect("mystic_dice" in ActiveItemDebugSpawnMenu.DEBUG_ENTRY_ORDER, "F2 item debug should include Mystic Dice")
	var icon_path := str(item.get("icon_path", ""))
	var source_image := Image.new()
	var source_load_error := source_image.load_png_from_buffer(FileAccess.get_file_as_bytes(icon_path))
	_expect(source_load_error == OK, "Mystic Dice active-item source icon should load")
	if source_load_error == OK:
		_expect(source_image.get_size() == Vector2i(32, 32), "Mystic Dice icon should be authored at 32px")
	var icon: Texture2D = load(icon_path) as Texture2D
	_expect(icon != null, "Mystic Dice active-item icon should load")


func _verify_acquisition_routes() -> void:
	var field_item: Dictionary = _find_item(
		ActiveItemFieldSpawnPool.new().build_spawn_candidates(),
		"mystic_dice"
	)
	_expect(not field_item.is_empty(), "ordinary field drops should contain Mystic Dice")
	_expect(
		is_equal_approx(float(field_item.get("chance", 0.0)), 0.005),
		"field-drop candidates should preserve the rare 0.005 weight"
	)
	var pandora_item: Dictionary = _find_item(
		PandoraLegacyPoolBuilder.new().build_active_pool(),
		"mystic_dice"
	)
	_expect(not pandora_item.is_empty(), "Pandora's active pool should contain Mystic Dice")
	_expect(
		"mystic_dice" in PlazaGachaTransactions.new()._get_gacha_item_names(),
		"plaza gacha should inherit Mystic Dice from the active-item field order"
	)


func _verify_localized_names() -> void:
	var localized_names := [
		LanguageSettingsData.ITEM_DISPLAY_EN.get("mystic_dice", ""),
		LanguageSettingsData.ITEM_DISPLAY_ZH.get("mystic_dice", ""),
		LanguageSettingsData.ITEM_DISPLAY_JA.get("mystic_dice", ""),
		LanguageSettingsData.ITEM_DISPLAY_ES.get("mystic_dice", ""),
		LanguageSettingsData.ITEM_DISPLAY_PT_BR.get("mystic_dice", ""),
		LanguageSettingsData.ITEM_DISPLAY_RU.get("mystic_dice", ""),
	]
	for localized_name: Variant in localized_names:
		_expect(str(localized_name).strip_edges() != "", "every supported non-Korean locale should name Mystic Dice")
	_expect(
		str(LanguageSettingsData.ACTIVE_ITEM_DESCRIPTION_EN.get("mystic_dice", "")).strip_edges() != "",
		"English active-item tooltip copy should exist"
	)
	var legacy_flavor_copy := [
		str(LanguageSettingsData.PERK_SUMMARY_EN.get("mystic_dice", "")),
		str(LanguageSettingsData.PERK_SUMMARY_ZH.get("mystic_dice", "")),
		str(LanguageSettingsData.PERK_SUMMARY_JA.get("mystic_dice", "")),
		str(LanguageSettingsData.PERK_SUMMARY_ES.get("mystic_dice", "")),
		str(LanguageSettingsData.PERK_SUMMARY_PT_BR.get("mystic_dice", "")),
		str(LanguageSettingsData.PERK_SUMMARY_RU.get("mystic_dice", "")),
	]
	var migration_terms := ["active item", "主动道具", "アクティブアイテム", "objeto activo", "item ativo", "активный предмет"]
	for index: int in range(legacy_flavor_copy.size()):
		var flavor_text := str(legacy_flavor_copy[index])
		var migration_term := str(migration_terms[index])
		_expect(flavor_text.strip_edges() != "", "every locale should retain legacy flavor copy")
		_expect(
			migration_term.to_lower() not in flavor_text.to_lower(),
			"legacy hover copy must not read like a migration patch note"
		)


func _verify_slot_use_opens_modal_and_consumes_item() -> void:
	var runtime := RuntimePerkState.new()
	var registry := FakeRegistry.new()
	registry.instances["runtime_perk_state"] = runtime
	var cooldown_driver := FakeSkillTooltipDriver.new()
	registry.instances["battle_scene_skill_tooltip_driver"] = cooldown_driver
	var owner := FakeOwner.new()
	owner.active_item_slots = [ActiveItemCatalog.new().build_item_by_name("mystic_dice")]
	var effect_controller := ActiveItemEffectController.new()
	var effect_router := ActiveItemEffectRouter.new()
	var applied := ActiveItemSlotController.new().use_slot(
		0,
		owner,
		registry,
		false,
		func(item_data: Dictionary, use_owner: Object, use_registry: Object) -> bool:
			return effect_router.apply_item_effect(
				item_data,
				use_owner,
				use_registry,
				effect_controller,
				null
			)
	)
	_expect(applied, "using a held Mystic Dice should start its modal")
	_expect(owner.active_item_slots.is_empty(), "successful use should consume the active slot")
	_expect(runtime.is_mystic_dice_modal_active(), "active-item use should open the Dice modal")
	_expect(runtime.is_choice_active(), "Dice item modal should enter the shared battle modal gate")
	# 물리는 모달 게이트가 막지만 스킬/액티브 아이템 쿨다운은 벽시계 기준이라,
	# 실 경로에서 반드시 일시정지가 걸려야 한다(안 걸리면 모달을 열어둔 실시간
	# 만큼 다른 아이템·스킬 쿨다운이 공짜로 흐른다).
	_expect(
		cooldown_driver.pause_calls == 1,
		"item-origin modal should pause skill/active-item cooldown clocks exactly once"
	)
	_expect(
		runtime._skill_cooldown_pause.is_active(),
		"the shared cooldown pause should stay engaged while the item modal is open"
	)
	runtime._mystic_dice_runtime_state.reset_modal()
	# 티어다운도 실 계약대로: pause 헬퍼가 owner/registry 를 붙들고 있으므로
	# 해제 없이 owner 를 free 하면 매달린 참조가 남는다.
	runtime._resume_skill_cooldowns_for_choice()
	_expect(
		cooldown_driver.resume_calls == 1,
		"releasing the modal should resume the cooldown clocks exactly once"
	)
	_expect(
		not runtime._skill_cooldown_pause.is_active(),
		"the shared cooldown pause must not stay engaged after the modal closes"
	)
	owner.free()


func _verify_blocked_open_keeps_item_and_cooldown() -> void:
	# 열지 못하는 프레임(무공 선택·천사 모달·이미 열린 주사위)에서는 소비도
	# 쿨다운 시작도 없어야 한다 — 효과가 false를 반환하면 슬롯 컨트롤러가
	# 소비 이전에 조기 반환하는 계약.
	var blocked_cases := [
		{"label": "a Mugong/fusion choice", "choice": true, "angel": false},
		{"label": "an Angel Blessing modal", "choice": false, "angel": true},
	]
	for case_value: Variant in blocked_cases:
		var blocked_case: Dictionary = case_value as Dictionary
		var dice_runtime := RuntimePerkMysticDiceRuntimeState.new()
		var runtime := ItemOriginRuntime.new()
		runtime.choice_active = bool(blocked_case.get("choice", false))
		runtime.angel_modal_active = bool(blocked_case.get("angel", false))
		var owner := FakeOwner.new()
		_expect(
			not dice_runtime.begin_active_item_modal_from_runtime_state(runtime, owner, null),
			"the Dice item must not open over %s" % str(blocked_case.get("label", ""))
		)
		_expect(
			not dice_runtime.is_modal_active(),
			"a blocked open must leave no half-started modal for %s" % str(blocked_case.get("label", ""))
		)
		_expect(
			runtime.pause_calls == 0,
			"a blocked open must not touch the cooldown clocks for %s" % str(blocked_case.get("label", ""))
		)
		owner.free()

	var reentry_dice := RuntimePerkMysticDiceRuntimeState.new()
	var reentry_runtime := ItemOriginRuntime.new()
	var reentry_owner := FakeOwner.new()
	_expect(
		reentry_dice.begin_active_item_modal_from_runtime_state(reentry_runtime, reentry_owner, null),
		"the first item use should open the Dice modal"
	)
	_expect(
		not reentry_dice.begin_active_item_modal_from_runtime_state(reentry_runtime, reentry_owner, null),
		"a second copy must not re-open over the live Dice modal"
	)
	_expect(reentry_runtime.pause_calls == 1, "the refused re-entry must not double-pause the clocks")
	reentry_dice.reset_modal()
	reentry_owner.free()

	# 실 슬롯 경로 관통: 모달이 이미 열린 상태에서 두 번째 사본을 써도 소비되지
	# 않아야 한다. 첫 사용이 남긴 전역 쿨다운이 결과를 가리지 않도록 컨트롤러와
	# 아이템 인스턴스를 새로 세운다(쿨다운으로 막히면 통과 이유가 뒤바뀐다).
	var live_runtime := RuntimePerkState.new()
	var live_registry := FakeRegistry.new()
	live_registry.instances["runtime_perk_state"] = live_runtime
	var live_owner := FakeOwner.new()
	live_owner.active_item_slots = [ActiveItemCatalog.new().build_item_by_name("mystic_dice")]
	var live_effect_controller := ActiveItemEffectController.new()
	var live_effect_router := ActiveItemEffectRouter.new()
	var use_callback := func(item_data: Dictionary, use_owner: Object, use_registry: Object) -> bool:
		return live_effect_router.apply_item_effect(
			item_data,
			use_owner,
			use_registry,
			live_effect_controller,
			null
		)
	_expect(
		live_runtime.begin_mystic_dice_active_item(live_owner, live_registry),
		"the first Dice copy should open the modal"
	)
	var second_use := ActiveItemSlotController.new().use_slot(
		0,
		live_owner,
		live_registry,
		false,
		use_callback
	)
	_expect(not second_use, "a second Dice copy must be refused while its modal is live")
	_expect(
		live_owner.active_item_slots.size() == 1,
		"a refused use must leave the consumable in its slot"
	)
	var kept_item: Dictionary = live_owner.active_item_slots[0] as Dictionary
	_expect(
		not kept_item.has("last_use_msec"),
		"a refused use must not stamp the item's cooldown anchor"
	)
	live_runtime._mystic_dice_runtime_state.reset_modal()
	live_owner.free()


func _verify_item_origin_commit_skips_choice_finish() -> void:
	var dice_runtime := RuntimePerkMysticDiceRuntimeState.new()
	var runtime := ItemOriginRuntime.new()
	var owner := FakeOwner.new()
	var units: Array = []
	for _stat_key: String in MysticDiceRoller.STAT_KEYS:
		units.append(1.0)
	_expect(
		dice_runtime.begin_active_item_modal_from_runtime_state(runtime, owner, null, units),
		"item-origin modal should start without a perk choice"
	)
	dice_runtime.get_modal_flow().update(2.0)
	dice_runtime.get_modal_flow().set_selected_action(1)
	var committed: Dictionary = dice_runtime.activate_selected_action_from_runtime_state(
		runtime,
		owner,
		null
	)
	_expect(bool(committed.get("accepted", false)), "item-origin roll should commit")
	_expect(str(committed.get("source", "")) == "active_item", "commit should retain its item origin")
	_expect(not dice_runtime.is_modal_active(), "item-origin commit should close the modal")
	_expect(dice_runtime.get_raw("player_speed") == 3, "item roll should update canonical stat state")
	var owner_sync: FakeOwnerSync = runtime._owner_sync_flow as FakeOwnerSync
	_expect(owner_sync.owner_sync_calls == 1, "item commit should resync owner stats once")
	_expect(owner_sync.mythic_sync_calls == 1, "item commit should refresh item consumers once")
	owner.free()


# 아이템은 랠리 임의 프레임에 쓸 수 있으므로, 커밋 직후 공이 원래 속도로 즉시
# 재개되면 회피 불가 실점이 된다. 퍽/천사 모달과 같은 리줌 안전장치가 실제로
# 무장되는지를 호출 카운트가 아니라 "공이 얼었는가 + 실점이 막히는가"라는
# 결과로 단언한다.
func _verify_item_modal_pauses_and_rearms_gameplay_clocks() -> void:
	var dice_runtime := RuntimePerkMysticDiceRuntimeState.new()
	var runtime := ItemOriginRuntime.new()
	var registry := FakeRegistry.new()
	var owner := FakeOwner.new()
	# 플레이어를 향해 하강 중인 공 — 안전장치가 보호하도록 설계된 상태.
	owner.ball_vel = Vector2(2.0, 7.0)
	var units: Array = []
	for _stat_key: String in MysticDiceRoller.STAT_KEYS:
		units.append(1.0)
	_expect(
		dice_runtime.begin_active_item_modal_from_runtime_state(runtime, owner, registry, units),
		"item-origin modal should open on a live descending ball"
	)
	_expect(runtime.pause_calls == 1, "opening the item modal should pause the wall-clock cooldowns once")
	_expect(runtime.resume_calls == 0, "the open path must not resume the clocks early")
	_expect(
		owner.ball_vel == Vector2(2.0, 7.0),
		"opening the modal must not disturb the ball itself (physics is gated separately)"
	)
	dice_runtime.get_modal_flow().update(2.0)
	dice_runtime.get_modal_flow().set_selected_action(1)
	var committed: Dictionary = dice_runtime.activate_selected_action_from_runtime_state(
		runtime,
		owner,
		registry
	)
	_expect(bool(committed.get("accepted", false)), "the lifecycle leg should still commit its roll")
	_expect(runtime.resume_calls == 1, "closing the item modal should resume the cooldown clocks once")
	var safety_context: Dictionary = runtime._resume_safety.get_context()
	_expect(
		bool(safety_context.get("perk_resume_freeze_active", false)),
		"item-origin commit should arm the resume freeze"
	)
	_expect(
		bool(safety_context.get("perk_resume_score_blocking", false)),
		"the armed freeze should block scoring while the player re-acquires the ball"
	)
	_expect(
		owner.ball_vel == Vector2.ZERO,
		"the armed safety should hold the ball still instead of resuming at full speed"
	)
	var remembered_vel: Vector2 = safety_context.get("perk_resume_original_ball_vel", Vector2.ZERO)
	_expect(
		remembered_vel == Vector2(2.0, 7.0),
		"the safety should remember the pre-modal velocity to ramp back toward"
	)
	owner.free()


func _find_item(pool: Array, item_name: String) -> Dictionary:
	for item_value: Variant in pool:
		if item_value is Dictionary and str((item_value as Dictionary).get("name", "")) == item_name:
			return (item_value as Dictionary).duplicate(true)
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
