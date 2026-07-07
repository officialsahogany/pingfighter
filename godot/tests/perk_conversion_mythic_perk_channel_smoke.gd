extends SceneTree

const ActiveItemFieldSpawnPool := preload("res://scripts/items/active_item_field_spawn_pool.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const MythicPerkGrantHelper := preload("res://scripts/characters/mythic_perk_grant_helper.gd")
const PandoraLegacyPoolBuilder := preload("res://scripts/items/pandora_legacy_pool_builder.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const StageClearResultImmediateRewardGrantData := preload("res://scripts/core/stage_clear_result_immediate_reward_grant_data.gd")
const StageClearResultRewardCardDrawHelper := preload("res://scripts/ui/stage_clear_result_reward_card_draw_helper.gd")
const StageClearResultSummaryBuilder := preload("res://scripts/ui/stage_clear_result_summary_builder.gd")
const StageClearRewardResolver := preload("res://scripts/core/stage_clear_reward_resolver.gd")
const TreasureHuntRuntime := preload("res://scripts/items/treasure_hunt_runtime.gd")

const RESULT_RENDER_CAPTURE_PATH := "res://../.tmp/perk_conversion_s5a/mythic_perk_result_card.png"

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
	var runtime_perk_choice_active := false
	var selected_character_type := "smasher"
	var player_pos := Vector2(302.5, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0

	func queue_redraw() -> void:
		pass


class FakeRegistry:
	var instances: Dictionary = {}

	func _init(new_instances: Dictionary = {}) -> void:
		instances = new_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class CountingMythicRuntime:
	var acquire_calls := 0

	func acquire_item(
		_item_name: String,
		_owner: Object,
		_registry: Object,
		_rolls: Dictionary = {},
		_auto_equip: bool = true,
		_play_feedback: bool = false,
		_source_item_data: Dictionary = {}
	) -> int:
		acquire_calls += 1
		return acquire_calls - 1

	func get_snapshot() -> Dictionary:
		return {"inventory_items": []}


class RecordingPerkIconRenderer:
	var real: Object = RuntimePerkIconRenderer.new()
	var draw_calls := 0
	var last_skill_id := ""
	var last_result := false

	func draw_icon(canvas: CanvasItem, skill_id: String, rect: Rect2, alpha: float = 1.0, active: bool = true) -> bool:
		draw_calls += 1
		last_skill_id = skill_id
		last_result = bool(real.draw_icon(canvas, skill_id, rect, alpha, active))
		return last_result

	func get_icon_source(skill_id: String) -> Dictionary:
		return real._get_icon_source(skill_id)


class ResultCardProbe:
	extends Control

	var reward: Dictionary = {}
	var perk_catalog: Object = null
	var perk_icon_renderer: Object = null

	func _draw() -> void:
		StageClearResultRewardCardDrawHelper.draw_reward_card(
			self,
			ThemeDB.fallback_font,
			reward,
			Rect2(Vector2(64.0, 42.0), Vector2(292.0, 142.0)),
			1.55,
			1.0,
			{
				"timer": 0.35,
				"perk_catalog": perk_catalog,
				"perk_icon_renderer": perk_icon_renderer,
				"reward_icon_cache": {},
			}
		)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	PerkConversionFlags.debug_set_enabled(false)
	_verify_flag_off_legacy_mythic_routes()
	_verify_flag_on_stage_clear_mythic_perk_grant()
	_verify_flag_on_field_and_pandora_mythic_suppression()
	_verify_flag_on_treasure_mythic_perk_grant()
	_verify_all_owned_fallback_starpoints()
	await _verify_result_screen_card_uses_animated_mythic_perk_icon()
	PerkConversionFlags.debug_set_enabled(false)

	if _failures.is_empty():
		print("perk_conversion_mythic_perk_channel_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_flag_off_legacy_mythic_routes() -> void:
	var resolver := StageClearRewardResolver.new()
	PerkConversionFlags.debug_set_enabled(false)
	_expect(str(resolver.roll_reward(StageClearRewardResolver.BOX_GUARANTEED_MYTHIC).get("type", "")) == StageClearRewardResolver.REWARD_MYTHIC, "flag-OFF guaranteed mythic box should stay mythic item")
	_expect(str(resolver._roll_normal_box_reward(null, null, 0.99).get("type", "")) == StageClearRewardResolver.REWARD_MYTHIC, "flag-OFF normal mythic lane should stay mythic item")
	_expect(str(resolver._roll_advanced_box_reward(null, null, 0.0).get("type", "")) == StageClearRewardResolver.REWARD_MYTHIC, "flag-OFF advanced mythic lane should stay mythic item")

	var field_candidates: Array[Dictionary] = ActiveItemFieldSpawnPool.new().build_spawn_candidates(FakeRegistry.new())
	_expect(_count_spawn_group(field_candidates, "mythic") > 0, "flag-OFF field spawn should still include mythic item candidates")
	var pandora_builder := PandoraLegacyPoolBuilder.new()
	_expect(not pandora_builder.build_mythic_pool(MythicItemCatalog.new()).is_empty(), "flag-OFF Pandora mythic pool should stay populated")

	var mythic_runtime := MythicItemRuntime.new()
	var treasure_result: Dictionary = TreasureHuntRuntime.new()._roll_result(FakeOwner.new(), FakeRegistry.new({
		"mythic_item_runtime": mythic_runtime,
		"runtime_perk_state": RuntimePerkState.new(),
		"runtime_perk_catalog": RuntimePerkCatalog.new(),
	}), 0.0)
	_expect(str(treasure_result.get("result_type", "")) == "legendary", "flag-OFF treasure mythic result should stay legendary item")
	_expect(not (mythic_runtime.get_snapshot().get("inventory_items", []) as Array).is_empty(), "flag-OFF treasure mythic result should enter mythic item inventory")


func _verify_flag_on_stage_clear_mythic_perk_grant() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	var resolver := StageClearRewardResolver.new()
	var owner := FakeOwner.new()
	root.add_child(owner)
	var mythic_runtime := CountingMythicRuntime.new()
	var perk_state := RuntimePerkState.new()
	var registry := FakeRegistry.new({
		"mythic_item_runtime": mythic_runtime,
		"runtime_perk_state": perk_state,
		"runtime_perk_catalog": RuntimePerkCatalog.new(),
	})
	var guaranteed: Dictionary = resolver.roll_reward(StageClearRewardResolver.BOX_GUARANTEED_MYTHIC, owner, registry)
	_expect(str(guaranteed.get("type", "")) == StageClearRewardResolver.REWARD_MYTHIC_PERK, "flag-ON guaranteed mythic box should roll mythic_perk")
	_expect(str(guaranteed.get("perk_id", "")) != "", "flag-ON mythic_perk reward should carry perk_id")

	var summary: Dictionary = resolver.grant_rewards([guaranteed], owner, registry)
	var granted_perk_id: String = str(guaranteed.get("perk_id", ""))
	_expect(int(summary.get("mythic_perk_granted", 0)) == 1, "flag-ON mythic_perk reward should increment mythic_perk grant count")
	_expect(mythic_runtime.acquire_calls == 0, "flag-ON mythic_perk reward must not call mythic item acquire_item")
	_expect(perk_state.get_runtime_skill_level(granted_perk_id) == 1, "flag-ON mythic_perk reward should apply Lv.1 through runtime perk state")

	var immediate_owner := FakeOwner.new()
	root.add_child(immediate_owner)
	var immediate_state := RuntimePerkState.new()
	var immediate_registry := FakeRegistry.new({
		"mythic_item_runtime": CountingMythicRuntime.new(),
		"runtime_perk_state": immediate_state,
		"runtime_perk_catalog": RuntimePerkCatalog.new(),
	})
	var immediate_reward: Dictionary = MythicPerkGrantHelper.build_reward_for_perk("odins_eye", immediate_owner, immediate_registry)
	var immediate_result: Dictionary = StageClearResultImmediateRewardGrantData.grant_immediate_box_reward(
		immediate_reward,
		immediate_owner,
		immediate_registry,
		false,
		resolver
	)
	_expect(bool(immediate_result.get("granted", false)), "result-screen immediate mythic_perk grant should succeed")
	_expect(not bool(immediate_result.get("raise_mythic_acquisition_cinematic", false)), "mythic_perk immediate grant must not raise mythic item acquisition cinematic")
	_expect(immediate_state.get_runtime_skill_level("odins_eye") == 1, "result-screen immediate mythic_perk grant should apply through runtime perk state")
	owner.queue_free()
	immediate_owner.queue_free()


func _verify_flag_on_field_and_pandora_mythic_suppression() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	var field_candidates: Array[Dictionary] = ActiveItemFieldSpawnPool.new().build_spawn_candidates(FakeRegistry.new())
	_expect(_count_spawn_group(field_candidates, "active") > 0, "flag-ON field spawn should keep active candidates")
	_expect(_count_spawn_group(field_candidates, "passive") == 0, "flag-ON field spawn should remove passive item candidates")
	_expect(_count_spawn_group(field_candidates, "mythic") == 0, "flag-ON field spawn should remove mythic item candidates")

	var pandora_builder := PandoraLegacyPoolBuilder.new()
	var mythic_catalog := MythicItemCatalog.new()
	_expect(pandora_builder.build_passive_pool(mythic_catalog, FakeOwner.new()).is_empty(), "flag-ON Pandora passive pool should be empty")
	_expect(pandora_builder.build_mythic_pool(mythic_catalog).is_empty(), "flag-ON Pandora mythic pool should be empty")
	var pandora_runtime := MythicItemRuntime.new()
	var choices: Array = pandora_runtime.generate_pandora_legacy_selection_choices(FakeOwner.new(), FakeRegistry.new({"mythic_item_runtime": pandora_runtime}))
	_expect(choices.size() == 3, "flag-ON Pandora should still produce three active-only choices")
	for choice_value in choices:
		var choice: Dictionary = _get_dict(choice_value)
		_expect(str(choice.get("pandora_source", "")) == "active", "flag-ON Pandora choice should be active-source only")


func _verify_flag_on_treasure_mythic_perk_grant() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	var mythic_runtime := MythicItemRuntime.new()
	var perk_state := RuntimePerkState.new()
	var owner := FakeOwner.new()
	root.add_child(owner)
	var registry := FakeRegistry.new({
		"mythic_item_runtime": mythic_runtime,
		"runtime_perk_state": perk_state,
		"runtime_perk_catalog": RuntimePerkCatalog.new(),
	})
	var result: Dictionary = TreasureHuntRuntime.new()._roll_result(owner, registry, 0.0)
	var perk_id: String = str(result.get("perk_id", ""))
	_expect(str(result.get("result_type", "")) == "mythic_perk", "flag-ON treasure mythic lane should return mythic_perk result")
	_expect(perk_id != "", "flag-ON treasure mythic_perk result should expose perk_id")
	# Assert the RAW granted level, not the effective level: a random pick can be
	# transcendent_crown, whose own effect inflates effective levels, so the
	# effective-level query returns >1 for the crown even though the grant set
	# runtime_skill_levels[crown] == 1. "Granted Lv.1" means the raw level is 1.
	_expect(
		int(perk_state.runtime_skill_levels.get(perk_id, 0)) == 1,
		"flag-ON treasure mythic_perk result should apply raw Lv.1 for %s, levels=%s" % [perk_id, str(perk_state.runtime_skill_levels)]
	)
	_expect((mythic_runtime.get_snapshot().get("inventory_items", []) as Array).is_empty(), "flag-ON treasure mythic lane must not grant mythic item inventory")
	owner.queue_free()


func _verify_all_owned_fallback_starpoints() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	var owner := FakeOwner.new()
	root.add_child(owner)
	var perk_state := RuntimePerkState.new()
	for perk_id in MythicPerkGrantHelper.MYTHIC_PERK_IDS:
		perk_state.runtime_skill_levels[str(perk_id)] = 1
	var registry := FakeRegistry.new({
		"runtime_perk_state": perk_state,
		"runtime_perk_catalog": RuntimePerkCatalog.new(),
		"mythic_item_runtime": CountingMythicRuntime.new(),
	})
	var resolver := StageClearRewardResolver.new()
	var fallback_reward: Dictionary = resolver.roll_reward(StageClearRewardResolver.BOX_GUARANTEED_MYTHIC, owner, registry)
	_expect(str(fallback_reward.get("type", "")) == StageClearRewardResolver.REWARD_STARPOINT, "all-owned mythic_perk roll should fall back to starpoints")
	_expect(int(fallback_reward.get("amount", 0)) >= 1 and int(fallback_reward.get("amount", 0)) <= 3, "mythic_perk fallback starpoints should stay in ★1-3 range")
	var summary: Dictionary = resolver.grant_rewards([fallback_reward], owner, registry)
	_expect(int(summary.get("starpoint_granted", 0)) == int(fallback_reward.get("amount", 0)), "all-owned fallback should grant the fallback starpoint amount")
	owner.queue_free()


func _verify_result_screen_card_uses_animated_mythic_perk_icon() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	var reward: Dictionary = MythicPerkGrantHelper.build_reward_for_perk("odins_eye", null, FakeRegistry.new({
		"runtime_perk_catalog": RuntimePerkCatalog.new(),
		"runtime_perk_state": RuntimePerkState.new(),
	}))
	var boxes := [{"kind": StageClearRewardResolver.BOX_GUARANTEED_MYTHIC, "state": "opened", "reward": reward}]
	var summary_state: Dictionary = StageClearResultSummaryBuilder.build_result_summary_state({}, boxes)
	_expect(int(summary_state.get("perk_reward_count", 0)) == 1, "result summary should classify mythic_perk box reward as a perk")
	_expect(int(summary_state.get("item_reward_count", 0)) == 0, "result summary should not classify mythic_perk box reward as an item")

	var recorder := RecordingPerkIconRenderer.new()
	var source: Dictionary = recorder.get_icon_source("odins_eye")
	var sheet_texture: Texture2D = source.get("texture", null)
	var region: Rect2 = source.get("region", Rect2())
	_expect(sheet_texture != null, "mythic result-card renderer should resolve Odins Eye icon texture")
	if sheet_texture != null:
		_expect(sheet_texture.get_width() == 1024 and sheet_texture.get_height() == 128, "mythic result-card renderer should use the 8-frame animated sheet")
	_expect(region.size == Vector2(128.0, 128.0), "mythic result-card renderer should slice one 128x128 sheet frame")

	var viewport := SubViewport.new()
	viewport.size = Vector2i(420, 220)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var probe := ResultCardProbe.new()
	probe.size = Vector2(420.0, 220.0)
	probe.reward = reward
	probe.perk_catalog = RuntimePerkCatalog.new()
	probe.perk_icon_renderer = recorder
	viewport.add_child(probe)
	root.add_child(viewport)
	probe.queue_redraw()
	await process_frame
	await process_frame
	_expect(recorder.draw_calls > 0, "result reward card should call the perk icon renderer for mythic_perk rewards")
	_expect(recorder.last_skill_id == "odins_eye", "result reward card should render the mythic perk id, not an item fallback")
	_expect(recorder.last_result, "result reward card mythic perk draw should succeed")
	var display_name: String = DisplayServer.get_name().to_lower()
	var viewport_texture: Texture2D = viewport.get_texture()
	if display_name != "headless" and viewport_texture != null:
		var image: Image = viewport_texture.get_image()
		if image != null:
			var output_path: String = ProjectSettings.globalize_path(RESULT_RENDER_CAPTURE_PATH)
			DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
			var save_error: int = image.save_png(output_path)
			_expect(save_error == OK, "result reward card screenshot should save to %s" % output_path)
	else:
		print("perk_conversion_mythic_perk_channel_smoke: screenshot skipped under headless dummy renderer")
	viewport.queue_free()


func _count_spawn_group(candidates: Array, group: String) -> int:
	var count := 0
	for value in candidates:
		var item: Dictionary = _get_dict(value)
		if _get_item_group(item) == group:
			count += 1
	return count


func _get_item_group(item_data: Dictionary) -> String:
	var item_type := str(item_data.get("type", "active"))
	var rarity := str(item_data.get("rarity", ""))
	if item_type in ["mythic", "legendary"] or rarity in ["mythic", "legendary"]:
		return "mythic"
	if item_type == "passive":
		return "passive"
	return "active"


func _get_dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
