extends SceneTree

const MythicAcquisitionCinematic := preload("res://scripts/items/mythic_item_acquisition_cinematic_v2.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const MythicPerkGrantHelper := preload("res://scripts/characters/mythic_perk_grant_helper.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const StageClearRewardResolver := preload("res://scripts/core/stage_clear_reward_resolver.gd")

const CAPTURE_PATH := "res://../.tmp/mythic_perk_acquisition_cinematic/mythic_perk_reveal.png"
const PEERLESS_ICON_FRAME_MSEC := 250
const SLOT_FILLER_IDS := [
	"dash_lightweight",
	"dash_module_control",
	"dash_jump",
	"dash_acceleration",
	"item_luck",
	"item_cooldown_mastery",
	"item_gauge_mastery",
	"common_swiftness",
]

var _failures: Array[String] = []


class FakeOwner:
	extends Node

	var active_item_slots: Array = []
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var runtime_perk_levels: Dictionary = {}
	var runtime_perk_effective_levels: Dictionary = {}
	var runtime_perk_pending_choices := 0
	var runtime_perk_starpoints := 0
	var runtime_perk_gold := 0
	var runtime_perk_choice_active := false
	var selected_character_type := "smasher"
	var current_stage := 4
	var arena_mode_enabled := false
	var item_perk_level_bonus := 0
	var viper_ignition_aura_active := false
	var player_pos := Vector2(302.5, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0

	func queue_redraw() -> void:
		pass


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(new_instances: Dictionary = {}) -> void:
		instances = new_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class OneMythicCatalog:
	extends RefCounted

	var real: Object = RuntimePerkCatalog.new()
	var only_id := "odins_eye"

	func _init(new_only_id: String = "odins_eye") -> void:
		only_id = new_only_id

	func get_perk_data(perk_id: String) -> Dictionary:
		var data: Dictionary = real.get_perk_data(perk_id)
		if perk_id != only_id:
			data["rarity"] = "common"
			data["tree"] = "debug_non_mythic"
		return data

	func has_open_perk_slot(_runtime_levels: Dictionary, _registry: Object = null) -> bool:
		return true

	func get_perk_slot_status(_runtime_levels: Dictionary, _registry: Object = null) -> Dictionary:
		return {
			"count": 0,
			"limit": 8,
			"is_full": false,
		}


class RecordingMythicRuntime:
	extends RefCounted

	var cinematic_active := false
	var start_calls := 0
	var last_item_data: Dictionary = {}
	var last_pickup_position := Vector2.ZERO
	var last_target_player_center := Vector2.ZERO

	func start_acquisition_cinematic(
		acquired_item_data: Dictionary,
		pickup_position: Vector2,
		_owner: Object,
		_registry: Object = null,
		target_player_center_override: Vector2 = Vector2.INF
	) -> bool:
		start_calls += 1
		cinematic_active = true
		last_item_data = acquired_item_data.duplicate(true)
		last_pickup_position = pickup_position
		last_target_player_center = target_player_center_override
		return true

	func is_acquisition_cinematic_active() -> bool:
		return cinematic_active

	func get_acquisition_cinematic_snapshot() -> Dictionary:
		return {
			"active": cinematic_active,
			"item_data": last_item_data.duplicate(true),
			"pickup_position": last_pickup_position,
			"player_center": last_target_player_center,
		}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	_verify_mythic_box_choice_opens_and_selection_starts_cinematic()
	_verify_mythic_box_choice_forwards_box_coordinates_to_cinematic()
	_verify_direct_mythic_perk_grant_starts_cinematic_once()
	_verify_public_angel_jackpot_grant_reserves_current_stage()
	_verify_guaranteed_angel_choice_reserves_next_intro()
	_verify_developer_angel_grant_reserves_once()
	_verify_mythic_perk_choice_fallback_does_not_start_cinematic()
	_verify_single_unowned_mythic_choice()
	_verify_mythic_perk_sheet_paths()
	_verify_static_fallback_metadata()
	_verify_cinematic_text_lane_key_gate()
	_verify_prewarm_includes_mythic_perk_sheets()
	await _capture_reveal_if_available()
	await _drain_frames(8)
	_clear_runtime_caches_for_test()
	await _drain_frames(30)
	PerkConversionFlags.debug_set_enabled(false)

	if _failures.is_empty():
		print("mythic_perk_acquisition_cinematic_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_mythic_box_choice_opens_and_selection_starts_cinematic() -> void:
	var owner := FakeOwner.new()
	root.add_child(owner)
	var runtime := RecordingMythicRuntime.new()
	var perk_state := RuntimePerkState.new()
	var perk_catalog := RuntimePerkCatalog.new()
	var registry := FakeRegistry.new({
		"mythic_item_runtime": runtime,
		"runtime_perk_state": perk_state,
		"runtime_perk_catalog": perk_catalog,
	})
	var resolver := StageClearRewardResolver.new()
	var reward: Dictionary = resolver.roll_reward(StageClearRewardResolver.BOX_GUARANTEED_MYTHIC, owner, registry)
	_expect(str(reward.get("type", "")) == StageClearRewardResolver.REWARD_MYTHIC_PERK_CHOICE, "flag-ON mythic box should roll a mythic perk choice reward")
	_expect(str(reward.get("perk_id", "")) == "", "mythic perk choice reward should not pre-pick a perk id")

	var summary: Dictionary = resolver.grant_rewards([reward], owner, registry)
	_expect(int(summary.get("mythic_perk_choice_opened", 0)) == 1, "mythic perk choice reward should open one choice modal")
	_expect(perk_state.is_choice_active(), "mythic perk choice reward should activate the runtime perk modal")
	_expect(perk_state.pending_skill_choices == 1, "mythic perk choice opening should queue one pending choice")
	_expect(runtime.start_calls == 0, "mythic perk box should not start the cinematic before a card is chosen")
	_expect(perk_state.current_choices.size() > 0 and perk_state.current_choices.size() <= 3, "mythic perk choice should show up to three cards")
	for choice_value in perk_state.current_choices:
		var choice: Dictionary = _get_dict(choice_value)
		_expect(str(choice.get("rarity", "")) == "mythic", "mythic perk choice cards should all carry mythic rarity")
		_expect(not bool(choice.get("is_gold_conversion", false)), "mythic perk choice should not include gold conversion")
		_expect(str(choice.get("tree", "")) == "mythic", "mythic perk choice should not include instant or filler trees")
		_expect(perk_state.get_runtime_skill_level(str(choice.get("id", ""))) == 0, "mythic perk choice should only include unowned mythic perks")

	var selected_choice: Dictionary = _get_dict(perk_state.current_choices[perk_state.selected_index])
	var selected_perk_id: String = str(selected_choice.get("id", ""))
	var expected_perk_data: Dictionary = perk_catalog.get_perk_data(selected_perk_id)
	var expected_description: String = "%s\n%s" % [LanguageSettings.translate_text("절세무공 대성!"), _first_description_line(expected_perk_data)]
	perk_state.update(0.30, Vector2(760.0, 750.0), owner, registry)
	perk_state.choose_selected(owner, registry, Vector2(760.0, 750.0))
	var item_data: Dictionary = runtime.last_item_data
	_expect(perk_state.get_runtime_skill_level(selected_perk_id) == 1, "chosen mythic perk should apply Lv.1 through runtime perk state")
	_expect(perk_state.pending_skill_choices == 0, "successful mythic perk selection should consume the pending choice")
	_expect(not perk_state.is_choice_active(), "successful mythic perk selection should close the choice modal")
	_expect(runtime.start_calls == 1, "successful mythic perk selection should start the acquisition cinematic once")
	_expect(runtime.is_acquisition_cinematic_active(), "successful mythic perk selection should leave the acquisition cinematic active")
	_expect(str(item_data.get("perk_id", "")) == selected_perk_id, "cinematic item_data should carry the chosen perk id")
	_expect(str(item_data.get("name", "")) == str(expected_perk_data.get("name", "")), "cinematic item_data name should use the chosen perk name")
	_expect(str(item_data.get("rarity", "")) == "mythic", "cinematic item_data should pass the mythic rarity gate")
	_expect(str(item_data.get("icon_sheet_path", "")) == str(RuntimePerkIconRenderer.PERK_SHEET_PATHS.get(selected_perk_id, "")), "cinematic should use the chosen animated mythic perk sheet")
	_expect(int(item_data.get("icon_frame_count", 0)) == 8, "cinematic mythic perk sheet should expose eight frames")
	_expect(int(item_data.get("icon_frame_msec", 0)) == PEERLESS_ICON_FRAME_MSEC, "cinematic peerless sheet should use the AutoSprite internal-motion cadence")
	_expect(str(item_data.get("reveal_description", "")) == expected_description, "cinematic should reveal the chosen Lv1 perk description")
	owner.queue_free()


func _verify_mythic_box_choice_forwards_box_coordinates_to_cinematic() -> void:
	# 결과화면 상자는 payload 에 상자 위치 기반 시네마틱 좌표를 싣는다. 선택형 신화퍽은
	# 카드를 고른 뒤에야 획득 시네마틱이 시작되므로, 그 좌표가 resolver → choice context →
	# 각 카드 스탬프 → 선택 시 시네마틱까지 흘러야 한다 (직접 grant 경로와 동일 계약).
	var owner := FakeOwner.new()
	root.add_child(owner)
	var runtime := RecordingMythicRuntime.new()
	var perk_state := RuntimePerkState.new()
	var perk_catalog := RuntimePerkCatalog.new()
	var registry := FakeRegistry.new({
		"mythic_item_runtime": runtime,
		"runtime_perk_state": perk_state,
		"runtime_perk_catalog": perk_catalog,
	})
	var resolver := StageClearRewardResolver.new()
	var reward: Dictionary = resolver.roll_reward(StageClearRewardResolver.BOX_GUARANTEED_MYTHIC, owner, registry)
	_expect(str(reward.get("type", "")) == StageClearRewardResolver.REWARD_MYTHIC_PERK_CHOICE, "guaranteed mythic box should roll a mythic perk choice reward")
	# 상자 오픈 payload(build_immediate_reward_payload)가 싣는 상자 위치 좌표를 모사.
	var box_pickup := Vector2(232.0, 306.0)
	var box_player_center := Vector2(612.0, 286.0)
	reward["pickup_position"] = box_pickup
	reward["target_player_center"] = box_player_center
	resolver.grant_rewards([reward], owner, registry)
	_expect(perk_state.is_choice_active(), "mythic perk choice reward should open the choice modal")
	_expect(perk_state.current_choices.size() > 0, "mythic perk choice reward should expose cards")
	for choice_value in perk_state.current_choices:
		var choice: Dictionary = _get_dict(choice_value)
		_expect(choice.get("pickup_position", Vector2.ZERO) == box_pickup, "each mythic choice card should carry the box pickup_position")
		_expect(choice.get("target_player_center", Vector2.INF) == box_player_center, "each mythic choice card should carry the box target_player_center")
	perk_state.update(0.30, Vector2(760.0, 750.0), owner, registry)
	perk_state.choose_selected(owner, registry, Vector2(760.0, 750.0))
	_expect(runtime.start_calls == 1, "selecting a mythic choice card should start the acquisition cinematic once")
	_expect(runtime.last_pickup_position == box_pickup, "mythic choice cinematic should honor the box pickup_position, not the default center")
	_expect(runtime.last_target_player_center == box_player_center, "mythic choice cinematic should honor the box target_player_center")
	owner.queue_free()


func _verify_direct_mythic_perk_grant_starts_cinematic_once() -> void:
	var owner := FakeOwner.new()
	root.add_child(owner)
	var runtime := RecordingMythicRuntime.new()
	var perk_state := RuntimePerkState.new()
	var perk_catalog := RuntimePerkCatalog.new()
	var registry := FakeRegistry.new({
		"mythic_item_runtime": runtime,
		"runtime_perk_state": perk_state,
		"runtime_perk_catalog": perk_catalog,
	})
	var resolver := StageClearRewardResolver.new()
	var reward: Dictionary = MythicPerkGrantHelper.build_reward_for_perk("odins_eye", owner, registry)
	reward["pickup_position"] = Vector2(244.0, 318.0)
	reward["target_player_center"] = Vector2(610.0, 284.0)
	var expected_perk_data: Dictionary = perk_catalog.get_perk_data("odins_eye")
	var expected_description: String = "%s\n%s" % [LanguageSettings.translate_text("절세무공 대성!"), _first_description_line(expected_perk_data)]

	var summary: Dictionary = resolver.grant_rewards([reward], owner, registry)
	var item_data: Dictionary = runtime.last_item_data
	_expect(int(summary.get("mythic_perk_granted", 0)) == 1, "successful mythic_perk grant should increment the mythic perk count")
	_expect(runtime.start_calls == 1, "direct mythic_perk grant should start the acquisition cinematic exactly once through apply_choice")
	_expect(runtime.is_acquisition_cinematic_active(), "successful mythic_perk grant should leave the acquisition cinematic active")
	_expect(str(item_data.get("perk_id", "")) == "odins_eye", "cinematic item_data should carry the granted perk id")
	_expect(str(item_data.get("name", "")) == str(expected_perk_data.get("name", "")), "cinematic item_data name should use the perk name")
	_expect(str(item_data.get("rarity", "")) == "mythic", "cinematic item_data should pass the mythic rarity gate")
	_expect(str(item_data.get("icon_sheet_path", "")) == str(RuntimePerkIconRenderer.PERK_SHEET_PATHS.get("odins_eye", "")), "cinematic should use the animated mythic perk sheet")
	_expect(int(item_data.get("icon_frame_count", 0)) == 8, "cinematic mythic perk sheet should expose eight frames")
	_expect(int(item_data.get("icon_frame_msec", 0)) == PEERLESS_ICON_FRAME_MSEC, "cinematic peerless sheet should use the AutoSprite internal-motion cadence")
	_expect(str(item_data.get("reveal_description", "")) == expected_description, "cinematic should reveal the Lv1 perk description")
	_expect(runtime.last_pickup_position == Vector2(244.0, 318.0), "mythic perk cinematic should honor reward pickup_position")
	_expect(runtime.last_target_player_center == Vector2(610.0, 284.0), "mythic perk cinematic should honor reward target_player_center")
	owner.queue_free()


func _verify_public_angel_jackpot_grant_reserves_current_stage() -> void:
	var owner := FakeOwner.new()
	root.add_child(owner)
	var runtime := RecordingMythicRuntime.new()
	var perk_state := RuntimePerkState.new()
	var perk_catalog := RuntimePerkCatalog.new()
	var registry := FakeRegistry.new({
		"mythic_item_runtime": runtime,
		"runtime_perk_state": perk_state,
		"runtime_perk_catalog": perk_catalog,
	})
	perk_catalog.mythic_jackpot_offer_chance = 1.0
	var choices: Array = perk_catalog.get_choices(
		owner.selected_character_type,
		{},
		true,
		RuntimePerkCatalog.CONVERTED_MYTHIC_PERKS.size()
	)
	var angel_choice: Dictionary = _find_choice(choices, "angel_blessing")
	_expect(not angel_choice.is_empty(), "public mythic jackpot should materialize an Angel Blessing card")
	if angel_choice.is_empty():
		owner.queue_free()
		return

	perk_state.current_choice_context = {
		"source": "battle_mythic_jackpot",
		"grant_scope": "battle",
	}
	var accepted: bool = perk_state.apply_choice(angel_choice, owner, registry)
	var acquisition_snapshot: Dictionary = perk_state.get_angel_blessing_acquisition_snapshot()
	var pending_value: Variant = acquisition_snapshot.get("pending_rolls", [])
	var pending_rolls: Array = pending_value if pending_value is Array else []
	_expect(accepted, "public Angel jackpot card should apply through the standard runtime choice path")
	_expect(perk_state.get_runtime_skill_level("angel_blessing") == 1, "public Angel jackpot card should commit Lv.1 ownership")
	_expect(runtime.start_calls == 1, "public Angel jackpot grant should start the shared mythic acquisition cinematic")
	_expect(str(runtime.last_item_data.get("perk_id", "")) == "angel_blessing", "public Angel cinematic should receive the Angel perk id")
	_expect(str(runtime.last_item_data.get("icon_sheet_path", "")) == str(RuntimePerkIconRenderer.PERK_SHEET_PATHS.get("angel_blessing", "")), "public Angel cinematic should use its animated sheet")
	_expect(pending_rolls.size() == 1, "accepted public Angel battle grant should reserve exactly one roll")
	if pending_rolls.size() == 1:
		var pending: Dictionary = _get_dict(pending_rolls[0])
		_expect(int(pending.get("stage", 0)) == owner.current_stage, "public Angel battle reservation should bind to the current stage")
		_expect(str(pending.get("policy", "")) == "current_stage", "public Angel battle reservation should use current-stage policy")
		_expect(bool(pending.get("waiting_for_cinematic", false)), "public Angel battle reservation should wait for cinematic completion")
	owner.queue_free()


func _verify_guaranteed_angel_choice_reserves_next_intro() -> void:
	var owner := FakeOwner.new()
	root.add_child(owner)
	var runtime := RecordingMythicRuntime.new()
	var perk_state := RuntimePerkState.new()
	var perk_catalog := OneMythicCatalog.new("angel_blessing")
	var registry := FakeRegistry.new({
		"mythic_item_runtime": runtime,
		"runtime_perk_state": perk_state,
		"runtime_perk_catalog": perk_catalog,
	})
	var resolver := StageClearRewardResolver.new()
	var reward: Dictionary = resolver.roll_reward(StageClearRewardResolver.BOX_GUARANTEED_MYTHIC, owner, registry)
	var summary: Dictionary = resolver.grant_rewards([reward], owner, registry)
	_expect(int(summary.get("mythic_perk_choice_opened", 0)) == 1, "guaranteed mythic channel should open when Angel is the only eligible card")
	_expect(perk_state.current_choices.size() == 1, "Angel-only guaranteed mythic pool should produce one card")
	if perk_state.current_choices.size() != 1:
		owner.queue_free()
		return
	var only_choice: Dictionary = _get_dict(perk_state.current_choices[0])
	_expect(str(only_choice.get("id", "")) == "angel_blessing", "guaranteed mythic channel should materialize Angel from the public helper list")
	perk_state.update(0.30, Vector2(760.0, 750.0), owner, registry)
	perk_state.choose_selected(owner, registry, Vector2(760.0, 750.0))
	var acquisition_snapshot: Dictionary = perk_state.get_angel_blessing_acquisition_snapshot()
	var pending_value: Variant = acquisition_snapshot.get("pending_rolls", [])
	var pending_rolls: Array = pending_value if pending_value is Array else []
	_expect(perk_state.get_runtime_skill_level("angel_blessing") == 1, "guaranteed Angel selection should commit Lv.1 ownership")
	_expect(runtime.start_calls == 1, "guaranteed Angel selection should start the shared mythic acquisition cinematic")
	_expect(pending_rolls.size() == 1, "guaranteed Angel selection should reserve exactly one future roll")
	if pending_rolls.size() == 1:
		var pending: Dictionary = _get_dict(pending_rolls[0])
		_expect(int(pending.get("stage", -1)) == 0, "result-screen Angel reservation must not reuse the completed stage")
		_expect(str(pending.get("policy", "")) == "next_valid_intro", "guaranteed Angel selection should wait for the next valid intro")
		_expect(bool(pending.get("waiting_for_cinematic", false)), "guaranteed Angel reservation should wait for cinematic completion")
	owner.queue_free()


func _verify_developer_angel_grant_reserves_once() -> void:
	var owner := FakeOwner.new()
	root.add_child(owner)
	var runtime := RecordingMythicRuntime.new()
	var perk_state := RuntimePerkState.new()
	var perk_catalog := RuntimePerkCatalog.new()
	var registry := FakeRegistry.new({
		"mythic_item_runtime": runtime,
		"runtime_perk_state": perk_state,
		"runtime_perk_catalog": perk_catalog,
	})
	var first_applied: bool = perk_state.debug_set_perk_level(
		"angel_blessing",
		1,
		owner,
		registry,
		perk_catalog
	)
	var first_snapshot: Dictionary = perk_state.get_angel_blessing_acquisition_snapshot()
	var first_pending_value: Variant = first_snapshot.get("pending_rolls", [])
	var first_pending: Array = first_pending_value if first_pending_value is Array else []
	_expect(first_applied, "developer picker should grant public Angel through debug_set_perk_level")
	_expect(perk_state.get_runtime_skill_level("angel_blessing") == 1, "developer Angel grant should commit Lv.1 ownership")
	_expect(runtime.start_calls == 1, "developer Angel grant should start the shared mythic acquisition cinematic")
	_expect(first_pending.size() == 1, "developer Angel grant should reserve one current-stage roll")
	if first_pending.size() == 1:
		var pending: Dictionary = _get_dict(first_pending[0])
		_expect(int(pending.get("stage", 0)) == owner.current_stage, "developer Angel grant should bind its reservation to the live stage")
		_expect(str(pending.get("policy", "")) == "current_stage", "developer Angel grant should use current-stage policy")

	var duplicate_applied: bool = perk_state.debug_set_perk_level(
		"angel_blessing",
		1,
		owner,
		registry,
		perk_catalog
	)
	var duplicate_snapshot: Dictionary = perk_state.get_angel_blessing_acquisition_snapshot()
	var duplicate_pending_value: Variant = duplicate_snapshot.get("pending_rolls", [])
	var duplicate_pending: Array = duplicate_pending_value if duplicate_pending_value is Array else []
	_expect(duplicate_applied, "duplicate developer Angel level assignment may remain a successful no-op")
	_expect(runtime.start_calls == 1, "duplicate developer Angel grant must not replay the acquisition cinematic")
	_expect(duplicate_pending.size() == 1, "duplicate developer Angel grant must not enqueue a second roll")
	owner.queue_free()


func _verify_mythic_perk_choice_fallback_does_not_start_cinematic() -> void:
	var owner := FakeOwner.new()
	root.add_child(owner)
	var runtime := RecordingMythicRuntime.new()
	var perk_state := RuntimePerkState.new()
	perk_state.runtime_skill_levels = _full_slot_levels()
	var registry := FakeRegistry.new({
		"mythic_item_runtime": runtime,
		"runtime_perk_state": perk_state,
		"runtime_perk_catalog": RuntimePerkCatalog.new(),
	})
	var resolver := StageClearRewardResolver.new()
	var reward: Dictionary = resolver.roll_reward(StageClearRewardResolver.BOX_GUARANTEED_MYTHIC, owner, registry)
	_expect(str(reward.get("type", "")) == StageClearRewardResolver.REWARD_STARPOINT, "slot-full mythic perk choice roll should fall back to starpoints")
	var summary: Dictionary = resolver.grant_rewards([reward], owner, registry)
	_expect(int(summary.get("starpoint_granted", 0)) == 3, "slot-full mythic_perk fallback should grant starpoints")
	_expect(runtime.start_calls == 0, "slot-full mythic_perk fallback should not start the cinematic")
	_expect(not runtime.is_acquisition_cinematic_active(), "slot-full mythic_perk fallback should leave the cinematic inactive")
	owner.queue_free()


func _verify_single_unowned_mythic_choice() -> void:
	var owner := FakeOwner.new()
	root.add_child(owner)
	var runtime := RecordingMythicRuntime.new()
	var perk_state := RuntimePerkState.new()
	var perk_catalog := OneMythicCatalog.new()
	var registry := FakeRegistry.new({
		"mythic_item_runtime": runtime,
		"runtime_perk_state": perk_state,
		"runtime_perk_catalog": perk_catalog,
	})
	var resolver := StageClearRewardResolver.new()
	var reward: Dictionary = resolver.roll_reward(StageClearRewardResolver.BOX_GUARANTEED_MYTHIC, owner, registry)
	var summary: Dictionary = resolver.grant_rewards([reward], owner, registry)
	_expect(int(summary.get("mythic_perk_choice_opened", 0)) == 1, "one available mythic should still open the mythic choice modal")
	_expect(perk_state.current_choices.size() == 1, "one available mythic should produce a one-card choice")
	var only_choice: Dictionary = _get_dict(perk_state.current_choices[0])
	_expect(str(only_choice.get("id", "")) == "odins_eye", "one-card mythic choice should contain the only mythic candidate")
	_expect(str(only_choice.get("rarity", "")) == "mythic", "one-card mythic choice should keep mythic rarity")
	owner.queue_free()


func _verify_mythic_perk_sheet_paths() -> void:
	var renderer := RuntimePerkIconRenderer.new()
	for perk_id_value in MythicPerkGrantHelper.MYTHIC_PERK_IDS:
		var perk_id: String = str(perk_id_value)
		var sheet_path: String = str(RuntimePerkIconRenderer.PERK_SHEET_PATHS.get(perk_id, ""))
		_expect(sheet_path != "", "%s should register an animated perk sheet path" % perk_id)
		_expect(ResourceLoader.exists(sheet_path, "Texture2D"), "%s animated perk sheet should import as Texture2D" % perk_id)
		var item_data: Dictionary = MythicPerkGrantHelper.build_acquisition_cinematic_item_data(perk_id, null)
		_expect(str(item_data.get("icon_sheet_path", "")) == sheet_path, "%s acquisition should prefer the same production sheet" % perk_id)
		_expect(int(item_data.get("icon_frame_msec", 0)) == PEERLESS_ICON_FRAME_MSEC, "%s acquisition cadence should stay at 250ms" % perk_id)
		_expect(is_equal_approx(renderer.get_icon_frame_interval_msec(perk_id), float(item_data.get("icon_frame_msec", 0))), "%s card/HUD and acquisition cadence should share one renderer contract" % perk_id)


func _verify_static_fallback_metadata() -> void:
	var static_path := str(RuntimePerkIconRenderer.PERK_ICON_PATHS.get("odins_eye", ""))
	var metadata: Dictionary = MythicPerkGrantHelper._build_cinematic_icon_metadata("odins_eye", "", static_path)
	_expect(str(metadata.get("icon_path", "")) == static_path, "acquisition should keep the existing static peerless icon as fallback")
	_expect(not metadata.has("icon_sheet_path"), "static acquisition fallback should not masquerade as a sheet")
	_expect(int(metadata.get("icon_frame_count", 0)) == 1, "static acquisition fallback must expose one full frame instead of slicing the icon into eight slivers")
	_expect(int(metadata.get("icon_frame_msec", 0)) == PEERLESS_ICON_FRAME_MSEC, "static fallback metadata should preserve the peerless presentation cadence contract")


func _verify_cinematic_text_lane_key_gate() -> void:
	var owner := FakeOwner.new()
	root.add_child(owner)
	var item_data: Dictionary = MythicItemCatalog.new().build_item_by_name("heavenly_cape")
	var cinematic := MythicAcquisitionCinematic.new()
	root.add_child(cinematic)
	cinematic.trigger(item_data, Vector2(220.0, 330.0), Vector2(380.0, 725.0))
	var item_snapshot: Dictionary = cinematic.get_snapshot()
	_expect(not bool(item_snapshot.get("text_reveal_enabled", true)), "plain mythic item data should not enable the additive text lane")
	_expect(str(item_snapshot.get("reveal_description", "")) == "", "plain mythic item data should not synthesize reveal text")

	var perk_data: Dictionary = RuntimePerkCatalog.new().get_perk_data("odins_eye")
	var perk_cinematic_data := {
		"name": str(perk_data.get("name", "odins_eye")),
		"rarity": "mythic",
		"icon_sheet_path": str(RuntimePerkIconRenderer.PERK_SHEET_PATHS.get("odins_eye", "")),
		"icon_frame_count": 8,
		"icon_frame_msec": PEERLESS_ICON_FRAME_MSEC,
		"reveal_description": _first_description_line(perk_data),
	}
	cinematic.trigger(perk_cinematic_data, Vector2(220.0, 330.0), Vector2(380.0, 725.0))
	cinematic.update(1.21)
	cinematic.update(0.41)
	cinematic.update(0.51)
	cinematic.update(0.51)
	var perk_snapshot: Dictionary = cinematic.get_snapshot()
	_expect(bool(perk_snapshot.get("text_reveal_enabled", false)), "mythic perk cinematic data should enable the additive text lane")
	_expect(float(perk_snapshot.get("text_alpha", 0.0)) > 0.5, "mythic perk text lane should fade in during reveal")
	_expect(str(perk_snapshot.get("reveal_description", "")) == _first_description_line(perk_data), "mythic perk text lane should keep the Lv1 description")
	cinematic.queue_free()
	owner.queue_free()


func _verify_prewarm_includes_mythic_perk_sheets() -> void:
	var runtime := MythicItemRuntime.new()
	var owner := FakeOwner.new()
	root.add_child(owner)
	runtime.prewarm_acquisition_cinematic(owner, FakeRegistry.new())
	for perk_id_value in MythicPerkGrantHelper.MYTHIC_PERK_IDS:
		var perk_id: String = str(perk_id_value)
		var sheet_path: String = str(RuntimePerkIconRenderer.PERK_SHEET_PATHS.get(perk_id, ""))
		_expect(ProjectResourceLoader.get_cached_texture(sheet_path) != null, "%s mythic perk sheet should be prewarmed for acquisition cinematic" % perk_id)
	if runtime.acquisition_cinematic != null:
		runtime.acquisition_cinematic.queue_free()
		runtime.acquisition_cinematic = null
	owner.queue_free()


func _capture_reveal_if_available() -> void:
	if DisplayServer.get_name().to_lower().find("headless") >= 0:
		print("mythic_perk_acquisition_cinematic_smoke: screenshot skipped under headless display server")
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(760, 750)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var cinematic := MythicAcquisitionCinematic.new()
	viewport.add_child(cinematic)
	await process_frame

	var perk_data: Dictionary = RuntimePerkCatalog.new().get_perk_data("odins_eye")
	var perk_cinematic_data := {
		"name": str(perk_data.get("name", "odins_eye")),
		"rarity": "mythic",
		"icon_sheet_path": str(RuntimePerkIconRenderer.PERK_SHEET_PATHS.get("odins_eye", "")),
		"icon_frame_count": 8,
		"icon_frame_msec": PEERLESS_ICON_FRAME_MSEC,
		"reveal_description": _first_description_line(perk_data),
	}
	cinematic.trigger(perk_cinematic_data, Vector2(220.0, 330.0), Vector2(380.0, 725.0))
	cinematic.update(1.21)
	cinematic.update(0.41)
	cinematic.update(0.51)
	cinematic.update(0.51)
	await process_frame
	await process_frame

	var viewport_texture: Texture2D = viewport.get_texture()
	_expect(viewport_texture != null, "mythic perk capture viewport should expose a texture")
	if viewport_texture != null:
		var image: Image = viewport_texture.get_image()
		_expect(image != null and not image.is_empty(), "mythic perk capture should produce a non-empty image")
		if image != null and not image.is_empty():
			var output_path: String = ProjectSettings.globalize_path(CAPTURE_PATH)
			DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
			var save_error: int = image.save_png(output_path)
			_expect(save_error == OK, "mythic perk reveal screenshot should save to %s" % output_path)
			_expect(
				_count_bright_pixels(image, Rect2i(120, 456, 520, 112)) > 80,
				"mythic perk reveal screenshot should contain bright text pixels in the text lane"
			)
	viewport.queue_free()


func _full_slot_levels() -> Dictionary:
	var levels := {}
	for perk_id in SLOT_FILLER_IDS:
		levels[str(perk_id)] = 1
	return levels


func _first_description_line(perk_data: Dictionary) -> String:
	var descriptions_value: Variant = perk_data.get("descriptions", {})
	if descriptions_value is Dictionary:
		var descriptions: Dictionary = descriptions_value
		return str(descriptions.get(1, descriptions.get("1", ""))).strip_edges()
	return str(perk_data.get("detail", perk_data.get("description", ""))).strip_edges()


func _count_bright_pixels(image: Image, rect: Rect2i) -> int:
	var count := 0
	var end_x: int = mini(image.get_width(), rect.position.x + rect.size.x)
	var end_y: int = mini(image.get_height(), rect.position.y + rect.size.y)
	for y in range(maxi(0, rect.position.y), end_y):
		for x in range(maxi(0, rect.position.x), end_x):
			var color: Color = image.get_pixel(x, y)
			if color.a > 0.1 and max(color.r, max(color.g, color.b)) > 0.58:
				count += 1
	return count


func _get_dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


func _find_choice(choices: Array, perk_id: String) -> Dictionary:
	for value: Variant in choices:
		if value is Dictionary and str((value as Dictionary).get("id", "")) == perk_id:
			return value as Dictionary
	return {}


func _clear_runtime_caches_for_test() -> void:
	MythicAcquisitionCinematic.reset_for_test()
	ProjectResourceLoader.clear_caches()


func _drain_frames(frame_count: int) -> void:
	for _i in range(frame_count):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
