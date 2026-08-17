extends SceneTree

const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const ActiveItemFieldSpawnController := preload("res://scripts/items/active_item_field_spawn_controller.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const CharacterInfoOverlayPerkPresenter := preload("res://scripts/hud/character_info_overlay_perk_presenter.gd")
const StageClearRewardResolver := preload("res://scripts/core/stage_clear_reward_resolver.gd")
const VictoryLootPhaseState := preload("res://scripts/core/victory_loot_phase_state.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")


class FakeOwner:
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var megingjord_equipped := false
	var dowsing_pendulum_equipped := false
	var dowsing_pendulum_range := 0.0
	var dowsing_pendulum_context: Dictionary = {}
	var accessory_slot_count := 2
	var runtime_accessory_slot_bonus := 0
	var runtime_perk_levels: Dictionary = {}
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var player_pos := Vector2(300.0, 700.0)
	var current_stage := 1
	var stage1_boss_variant := "dalji"

	func queue_redraw() -> void:
		pass


class FakeRegistry:
	var mythic_runtime: Object
	var runtime_perk_state: Object

	func _init(mythic: Object, perks: Object) -> void:
		mythic_runtime = mythic
		runtime_perk_state = perks

	func get_instance(key: String) -> Object:
		if key == "mythic_item_runtime":
			return mythic_runtime
		if key == "runtime_perk_state":
			return runtime_perk_state
		return null


var _failed := false


func _init() -> void:
	var catalog := RuntimePerkCatalog.new()
	var treasure_map_data: Dictionary = catalog.get_perk_data("downtown_treasure_map")
	_expect(str(treasure_map_data.get("name", "")) == "천기보도", "catalog should register Heavenly-Secret Treasure Map")
	_expect(int(treasure_map_data.get("max_level", 0)) == 5, "Treasure Map should have five levels")
	_expect(
		str(treasure_map_data.get("detail", "")).find("보물탐색") < 0,
		"Treasure Map tooltip must not mention the retired Treasure Hunt perk"
	)
	# 비전초식 상자는 배정된 보스(S1 달지 · S2 청링귀)에게만 존재하고 해당 비전을
	# 이미 보유하면 굴림 자체가 사라진다. 짧은 카드 문구는 수치만 싣되, 상세 문구는
	# 이 두 조건을 반드시 밝혀야 한다 — 조건을 지운 상세 문구는 런의 대부분 구간에서
	# 작동하지 않는 레인을 무조건적 효과처럼 주장하게 된다.
	var treasure_map_detail: String = str(treasure_map_data.get("detail", ""))
	_expect(
		treasure_map_detail.find("배정된") >= 0,
		"Treasure Map detail must scope the Vision box lane to bosses that have a box assigned: %s" % treasure_map_detail
	)
	_expect(
		treasure_map_detail.find("아직 보유하지 않았을 때") >= 0,
		"Treasure Map detail must scope the Vision box lane to a not-yet-owned Vision: %s" % treasure_map_detail
	)
	# 패시브 아이템이 퍽으로 전환되어 사라졌으므로 천기보도는 2옵션 무공이다 —
	# 표시가 존재하지 않는 드랍 계약을 주장하면 안 된다.
	var treasure_map_descriptions: Dictionary = treasure_map_data.get("descriptions", {})
	for level_key in treasure_map_descriptions.keys():
		var description_text: String = str(treasure_map_descriptions[level_key])
		_expect(
			description_text.find("패시브") < 0,
			"Treasure Map Lv.%s must not advertise a passive drop lane: %s" % [str(level_key), description_text]
		)
		_expect(
			description_text.find("절세무공") >= 0,
			"Treasure Map Lv.%s must advertise the Peerless Martial Art lane: %s" % [str(level_key), description_text]
		)
		_expect(
			description_text.find("비전초식 상자 +%d%%p" % (int(level_key) * 3)) >= 0,
			"Treasure Map Lv.%s must advertise its +3pp-per-level Vision box lane: %s" % [str(level_key), description_text]
		)
		_expect(
			description_text.find("보물탐색") < 0,
			"Treasure Map Lv.%s must not advertise the retired Treasure Hunt lane: %s" % [str(level_key), description_text]
		)
	_expect(
		str(treasure_map_data.get("detail", "")).find("패시브") < 0,
		"Treasure Map detail must not advertise a passive drop lane"
	)
	var max_choice: Dictionary = treasure_map_data.duplicate(true)
	max_choice["id"] = "downtown_treasure_map"
	max_choice["description"] = str(treasure_map_descriptions.get(5, ""))
	max_choice["current_level"] = 4
	max_choice["next_level"] = 5
	var overlay_renderer := RuntimePerkOverlayRenderer.new()
	overlay_renderer._ensure_card_desc_cache([max_choice, max_choice, max_choice], 250.0)
	var rendered_max_stats := "".join(
		(overlay_renderer._card_desc_cache[0] as Dictionary).get("accent_lines", [])
	).replace(" ", "")
	_expect(
		rendered_max_stats == str(max_choice["description"]).replace(" ", ""),
		"Treasure Map max-invested offer card must render both numeric lanes without clipping: %s" % rendered_max_stats
	)
	# 상세 문구는 조건부 레인이라 길다. 상태/캐릭터정보 툴팁의 좌측 본문은
	# draw_perk_status_tooltip과 같은 예산(font 15 · 좌폭 300-패딩 24 · 6줄)으로
	# 감기며, 여기서 잘리면 조건이 사라져 무조건적 효과처럼 읽힌다 —
	# 문구를 늘릴 때마다 이 레그가 실측으로 막는다.
	var rendered_detail := "".join(
		overlay_renderer._wrap_text_px(treasure_map_detail, 15, 300.0 - 12.0 * 2.0, 6)
	).replace(" ", "")
	_expect(
		rendered_detail == treasure_map_detail.replace(" ", ""),
		"Treasure Map detail must fit the status tooltip budget without dropping its scope clause: %s" % rendered_detail
	)
	var tooltip_stats := CharacterInfoOverlayPerkPresenter.build_perk_stat_entries(
		str(max_choice["description"]),
		str(max_choice.get("detail", ""))
	)
	_expect(
		tooltip_stats.size() == 2
		and str((tooltip_stats[1] as Dictionary).get("text", "")) == "비전초식 상자 +15%p",
		"Treasure Map max-invested character-info tooltip must expose the Vision box lane"
	)

	var perk_state := RuntimePerkState.new()
	perk_state.runtime_skill_levels["downtown_treasure_map"] = 5
	_expect_close(
		perk_state.get_downtown_treasure_map_mythic_multiplier(),
		8.5,
		"Lv.5 mythic multiplier should match Python"
	)
	var mythic_runtime := MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(mythic_runtime, perk_state)
	var loot_phase := VictoryLootPhaseState.new()
	loot_phase._registry = registry
	loot_phase._current_stage = 1

	# 프로덕션 비전초식 상자 마킹 경로: 기본 20%에는 실패하는 같은 roll이
	# 천기보도 Lv.1(+3%p)부터 성공하고, Lv.5의 최종 경계는 정확히 35%다.
	perk_state.runtime_skill_levels.erase("downtown_treasure_map")
	loot_phase.set_vision_offer_roll_for_tests(func() -> float: return 0.20)
	var base_chance_boxes: Array = [{"kind": "normal"}]
	loot_phase._try_mark_boss_vision_offer_box(base_chance_boxes, owner)
	_expect(
		str((base_chance_boxes[0] as Dictionary).get("boss_vision_offer_id", "")) == "",
		"control: the base 20% Vision box chance must miss at roll 0.20"
	)

	perk_state.runtime_skill_levels["downtown_treasure_map"] = 1
	var level1_boxes: Array = [{"kind": "normal"}]
	loot_phase._try_mark_boss_vision_offer_box(level1_boxes, owner)
	_expect(
		str((level1_boxes[0] as Dictionary).get("boss_vision_offer_id", "")) != "",
		"Lv.1 Treasure Map must raise the Vision box chance from 20% to 23%"
	)

	perk_state.runtime_skill_levels["downtown_treasure_map"] = 5
	_expect_close(
		perk_state.get_downtown_treasure_map_vision_box_chance(0.20),
		0.35,
		"Lv.5 Vision box chance should be base 20% + 15pp"
	)
	loot_phase.set_vision_offer_roll_for_tests(func() -> float: return 0.3499)
	var level5_hit_boxes: Array = [{"kind": "normal"}]
	loot_phase._try_mark_boss_vision_offer_box(level5_hit_boxes, owner)
	_expect(
		str((level5_hit_boxes[0] as Dictionary).get("boss_vision_offer_id", "")) != "",
		"Lv.5 Vision box chance must accept rolls below 35%"
	)
	loot_phase.set_vision_offer_roll_for_tests(func() -> float: return 0.35)
	var level5_miss_boxes: Array = [{"kind": "normal"}]
	loot_phase._try_mark_boss_vision_offer_box(level5_miss_boxes, owner)
	_expect(
		str((level5_miss_boxes[0] as Dictionary).get("boss_vision_offer_id", "")) == "",
		"Lv.5 Vision box chance must reject the 35% threshold roll"
	)

	perk_state.runtime_skill_levels["downtown_treasure_map"] = 6
	_expect_close(
		perk_state.get_downtown_treasure_map_vision_box_chance(0.20),
		0.38,
		"effective Lv.6 Vision box chance should keep scaling"
	)

	var field_spawn_controller := ActiveItemFieldSpawnController.new()
	var level6_shares: Dictionary = field_spawn_controller._get_spawn_group_target_shares(
		{"active": 1.0, "passive": 1.0, "mythic": 1.0},
		registry
	)
	_expect_close(
		float(level6_shares.get("active", 0.0)),
		0.70,
		"field spawn should read the canonical Lv.6 Treasure Map helper for active share"
	)
	_expect_close(
		float(level6_shares.get("passive", 0.0)),
		0.20,
		"Treasure Map must no longer move the legacy passive field share"
	)
	_expect_close(
		float(level6_shares.get("mythic", 0.0)),
		0.10,
		"field spawn should read the canonical Lv.6 Treasure Map helper for mythic share"
	)

	# 프로덕션 소비처 씰. 퍽 전환 ON에서 필드 신화/패시브 드랍은 통째로 제외되므로
	# 천기보도의 "절세무공 확률" 레인이 실제로 살아있는 경로는 보상 상자 굴림뿐이다.
	# 같은 roll에서 Lv.0(대조군)과 Lv.5가 다른 보상으로 갈려야 배율 배선이 증명된다 —
	# 배율을 안 넘기면 두 레그가 같은 값이 되어 실패한다.
	var reward_resolver := StageClearRewardResolver.new()
	var conversion_was_enabled: bool = PerkConversionFlags.is_enabled()
	PerkConversionFlags.debug_set_enabled(true)

	perk_state.runtime_skill_levels.erase("downtown_treasure_map")
	_expect_reward_type(reward_resolver._roll_normal_box_reward(owner, registry, 0.95), "starpoint",
		"control: normal box at roll 0.95 without Treasure Map")
	_expect_reward_type(reward_resolver._roll_advanced_box_reward(owner, registry, 0.20), "starpoint",
		"control: advanced box at roll 0.20 without Treasure Map")

	perk_state.runtime_skill_levels["downtown_treasure_map"] = 5
	_expect_reward_type(reward_resolver._roll_normal_box_reward(owner, registry, 0.95), "mythic_perk_choice",
		"Lv.5 Treasure Map must widen the normal-box Peerless band")
	_expect_reward_type(reward_resolver._roll_advanced_box_reward(owner, registry, 0.20), "mythic_perk_choice",
		"Lv.5 Treasure Map must widen the advanced-box Peerless band")

	PerkConversionFlags.debug_set_enabled(conversion_was_enabled)

	# _expect의 quit(1)은 실행을 멈추지 않는다 — 게이트 없이 말미 quit(0)이
	# 종료코드를 덮어써 실패가 GREEN으로 보고된다(공허-GREEN 트랩).
	if _failed:
		quit(1)
		return
	print("treasure_map_perk_port_smoke: ok")
	quit(0)


func _expect_reward_type(reward: Dictionary, expected_type: String, message: String) -> void:
	_expect(
		str(reward.get("type", "")) == expected_type,
		"%s: got '%s' expected '%s'" % [message, str(reward.get("type", "")), expected_type]
	)


func _inventory_has_item(runtime: Object, item_name: String) -> bool:
	var snapshot: Dictionary = runtime.get_snapshot()
	var inventory: Array = snapshot.get("inventory_items", [])
	for item_value in inventory:
		if item_value is Dictionary and str(item_value.get("name", "")) == item_name:
			return true
	return false


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
