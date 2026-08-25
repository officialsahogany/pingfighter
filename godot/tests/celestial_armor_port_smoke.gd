extends SceneTree

const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const MythicItemCelestialArmorRuntime := preload("res://scripts/items/mythic_item_celestial_armor_runtime.gd")
const PaddleBounceEventRouter := preload("res://scripts/ball/paddle_bounce_event_router.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")


class FakeOwner:
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var special_gauge := 100.0
	var special_gauge_max := 500.0
	var player_pos := Vector2(300.0, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var celestial_armor_equipped := false
	var celestial_armor_active := false
	var celestial_armor_trigger_chance_pct := 0.0
	var celestial_armor_gauge_cost := 0.0
	var celestial_armor_context: Dictionary = {}
	var celestial_armor_wave_active := false

	func queue_redraw() -> void:
		pass


class FakeRegistry:
	func get_instance(_key: String) -> Object:
		return null


class FakeMovementState:
	var call_count := 0

	func start_knockback(
		_velocity: float,
		_frames: float = 18.0,
		_decay_per_frame: float = 0.92,
		_replace_current: bool = false,
		_cleansable: bool = true
	) -> bool:
		call_count += 1
		return true


func _init() -> void:
	_verify_runtime_constant_ownership()
	_verify_descriptions_mention_knockback()

	var catalog: Object = MythicItemCatalog.new()
	var item_data: Dictionary = catalog.build_item_by_name("celestial_armor")
	_expect(not item_data.is_empty(), "celestial armor should build from catalog")
	_expect(str(item_data.get("slot", "")) == "top", "celestial armor should use top slot")
	_expect(str(item_data.get("display_name", "")) == "천구의 부동 갑주", "celestial armor should keep Korean display name")
	_expect(int(item_data.get("icon_frame_count", 0)) == 32, "celestial armor should expose 32 smooth icon frames")
	_expect_original_icon_assets(item_data, "celestial armor")
	_expect(_catalog_has_field_spawn(catalog, "celestial_armor"), "celestial armor should be in field spawn pool")
	_expect_celestial_rolls(catalog)

	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var runtime: Object = MythicItemRuntime.new()
	_expect(
		runtime.equip_item(
			"celestial_armor",
			owner,
			registry,
			{"trigger_chance_pct": 100.0, "gauge_cost": 20.0},
			false
		),
		"celestial armor should equip"
	)
	_expect(owner.equipment_slots.has("top"), "celestial armor should sync to top slot")
	_expect(str(owner.equipment_slots["top"].get("name", "")) == "celestial_armor", "top slot should contain celestial armor")
	_expect(owner.celestial_armor_equipped, "owner should expose celestial armor equipped")
	_expect(owner.celestial_armor_active, "owner should expose celestial armor active")
	_expect(is_equal_approx(owner.celestial_armor_trigger_chance_pct, 100.0), "owner should sync trigger chance")
	_expect(is_equal_approx(owner.celestial_armor_gauge_cost, 20.0), "owner should sync gauge cost")

	# 부동갑주 계약 = "스턴·넉백 무시"(WIP 파괴 후 복원). (A) 순수 넉백도 차단 대상,
	# (B) 한 히트의 스턴+넉백은 1롤로 둘 다 차단(paired 무료 우회), (C) recoil/burn은 제외.
	var proc_deps := {"owner": owner, "registry": registry}
	# (A) 순수 넉백(fresh, paired 타이머 0) → 독립 롤 100% → 차단 + 게이지 소비.
	_expect(
		runtime.try_consume_celestial_armor_immunity("pure_kb", "knockback", proc_deps),
		"celestial armor should block pure knockback (스턴·넉백 무시 contract)"
	)
	_expect(is_equal_approx(owner.special_gauge, 80.0), "pure knockback block should spend gauge")
	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(bool(snapshot.get("celestial_armor_wave_active", false)), "celestial armor should start wave VFX on a knockback block")
	_expect(str(snapshot.get("celestial_armor_last_blocked_effect_type", "")) == "knockback", "snapshot should expose the blocked knockback effect type")
	# (B) 방금 넉백 차단(effect=knockback) → 같은 히트의 스턴은 paired 무료 우회(추가 롤/게이지 없음).
	_expect(
		runtime.try_consume_celestial_armor_immunity("pure_kb", "stun", proc_deps),
		"paired stun (same hit as a blocked knockback) should bypass free"
	)
	_expect(is_equal_approx(owner.special_gauge, 80.0), "paired bypass should not spend additional gauge")
	# (C) 계약 밖(recoil/burn)은 비대상 — 게이트에서 거부, 게이지 무소비.
	_expect(
		not runtime.try_consume_celestial_armor_immunity("recoil_hit", "recoil", proc_deps),
		"celestial armor must NOT block recoil (contract excludes paddle-hit recoil / burn)"
	)
	_expect(is_equal_approx(owner.special_gauge, 80.0), "ineligible recoil should not spend gauge")

	# (D) P2-C: paired 무료 우회는 같은 물리 히트(같은 source)에만 허용. 다른 소스의 별개
	# 적대 이벤트가 3프레임 안에 반대 CC로 들어와도 무료로 막히면 안 된다(정상 확률·기력 경로).
	runtime.reset_round(registry)
	owner.special_gauge = 100.0
	_expect(
		runtime.try_consume_celestial_armor_immunity("src_a", "stun", proc_deps),
		"first hit (src_a stun) should block"
	)
	_expect(is_equal_approx(owner.special_gauge, 80.0), "src_a stun block should spend gauge once")
	# 다른 소스(src_b)의 넉백: paired 창이 열려 있어도 무료가 아니라 재-소비해야 한다.
	_expect(
		runtime.try_consume_celestial_armor_immunity("src_b", "knockback", proc_deps),
		"different-source hit should still block via a fresh roll"
	)
	_expect(
		is_equal_approx(owner.special_gauge, 60.0),
		"different-source opposite-CC hit must spend gauge AGAIN (no cross-source free bypass)"
	)
	# 같은 소스(src_a)의 반대 CC는 무료 우회 — 단 "두 번째 CC 성분 1회"만.
	runtime.reset_round(registry)
	owner.special_gauge = 100.0
	_expect(runtime.try_consume_celestial_armor_immunity("src_a", "stun", proc_deps), "src_a stun re-block")
	_expect(is_equal_approx(owner.special_gauge, 80.0), "src_a stun spends once")
	_expect(
		runtime.try_consume_celestial_armor_immunity("src_a", "knockback", proc_deps),
		"same-source paired opposite-CC should bypass free (once)"
	)
	_expect(is_equal_approx(owner.special_gauge, 80.0), "first same-source paired bypass spends no extra gauge")
	# 무료 우회권은 1회 소모: 같은 창(같은 프레임, 타이머 미경과)에서 같은 반대 CC를 또
	# 부르면 정상 확률·기력 경로로 복귀해야 한다(계약 = 두 번째 CC 성분 1회).
	_expect(
		runtime.try_consume_celestial_armor_immunity("src_a", "knockback", proc_deps),
		"second same-source opposite-CC should block via a fresh roll (paired consumed)"
	)
	_expect(
		is_equal_approx(owner.special_gauge, 60.0),
		"paired free bypass is single-use: the second same call must spend gauge again"
	)

	runtime.reset_round(registry)
	var context_only := {
		"special_gauge": 45.0,
		"player_pos": Vector2(300.0, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
	}
	_expect(
		runtime.try_consume_celestial_armor_immunity("context_stun", "stun", {"context": context_only}),
		"context-only celestial armor proc should work for stun update routes"
	)
	_expect(is_equal_approx(float(context_only.get("special_gauge", -1.0)), 25.0), "context-only proc should mutate context gauge")

	runtime.reset_round(registry)
	var low_gauge_context := {"special_gauge": 10.0}
	_expect(
		not runtime.try_consume_celestial_armor_immunity("low_gauge", "stun", {"context": low_gauge_context}),
		"celestial armor should fail when gauge is insufficient"
	)
	_expect(is_equal_approx(float(low_gauge_context.get("special_gauge", -1.0)), 10.0), "failed proc should not spend gauge")

	runtime.reset_round(registry)
	_expect(
		runtime.equip_item(
			"celestial_armor",
			owner,
			registry,
			{"trigger_chance_pct": 0.0, "gauge_cost": 20.0},
			false
		),
		"celestial armor should update roll overrides"
	)
	owner.special_gauge = 100.0
	_expect(
		not runtime.try_consume_celestial_armor_immunity("zero_chance", "stun", {"owner": owner}),
		"0 percent celestial armor should not block"
	)
	_expect(is_equal_approx(owner.special_gauge, 100.0), "failed chance roll should not spend gauge")

	_expect(
		runtime.equip_item(
			"celestial_armor",
			owner,
			registry,
			{"trigger_chance_pct": 100.0, "gauge_cost": 20.0},
			false
		),
		"celestial armor should re-equip deterministic test rolls"
	)
	runtime.reset_round(registry)
	var movement := FakeMovementState.new()
	var bounce_router: Object = PaddleBounceEventRouter.new()
	var rally_result: Dictionary = bounce_router.register_rally_feedback(
		Vector2(380.0, 690.0),
		Vector2(16.0, -18.0),
		true,
		false,
		{
			"movement_state": movement,
			"mythic_item_runtime": runtime,
		},
		{
			"player_pos": Vector2(300.0, 700.0),
			"player_paddle_width": 155.0,
			"player_paddle_height": 50.0,
		},
		100.0
	)
	_expect(rally_result.is_empty(), "paddle-hit knockback should not trigger celestial armor")
	_expect(movement.call_count == 1, "paddle-hit knockback should pass through celestial armor")

	_expect(runtime.unequip_item("celestial_armor", owner, registry), "celestial armor should unequip")
	_expect(not owner.celestial_armor_equipped, "owner should clear celestial armor equipped state")

	print("celestial_armor_port_smoke: ok")
	quit(0)


func _verify_runtime_constant_ownership() -> void:
	_expect(is_equal_approx(MythicItemCelestialArmorRuntime.MAX_TRIGGER_CHANCE_PCT, 100.0), "celestial armor helper should own trigger chance cap")
	_expect(is_equal_approx(MythicItemCelestialArmorRuntime.WAVE_LIFE_FRAMES, 33.0), "celestial armor helper should own wave lifetime")
	_expect(MythicItemCelestialArmorRuntime.SHARD_COUNT == 10, "celestial armor helper should own shard count")
	var runtime_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_runtime.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_celestial_armor_runtime.gd")
	_expect(runtime_source != "", "mythic runtime source should be readable")
	_expect(helper_source != "", "celestial armor helper source should be readable")
	_expect(not runtime_source.contains("CELESTIAL_ARMOR_CONSTANTS"), "runtime facade should not regain CELESTIAL_ARMOR_CONSTANTS")
	_expect(not runtime_source.contains("const CELESTIAL_ARMOR_MAX"), "runtime facade should not regain celestial cap constants")
	_expect(not runtime_source.contains("const CELESTIAL_ARMOR_WAVE"), "runtime facade should not regain celestial wave constants")
	_expect(not runtime_source.contains("const CELESTIAL_ARMOR_PAIRED"), "runtime facade should not regain celestial paired-proc constants")
	_expect(not runtime_source.contains("const CELESTIAL_ARMOR_SHARD"), "runtime facade should not regain celestial shard constants")
	_expect(not runtime_source.contains("const CELESTIAL_ARMOR_ARC"), "runtime facade should not regain celestial arc constants")
	_expect(not runtime_source.contains("const CELESTIAL_ARMOR_FEEDBACK"), "runtime facade should not regain celestial feedback constants")
	_expect(helper_source.contains("const FEEDBACK_SHAKE_INTENSITY"), "celestial armor helper should keep feedback constants")


func _expect_celestial_rolls(catalog: Object) -> void:
	var rolls: Array = catalog.get_roll_options("celestial_armor")
	_expect(rolls.size() == 2, "celestial armor should expose two roll options")
	var trigger_roll: Dictionary = _find_roll(rolls, "trigger_chance_pct")
	_expect(not trigger_roll.is_empty(), "celestial armor should expose trigger chance roll")
	_expect(is_equal_approx(float(trigger_roll.get("min", 0.0)), 50.0), "trigger chance min should match Python")
	_expect(is_equal_approx(float(trigger_roll.get("max", 0.0)), 80.0), "trigger chance max should match Python")
	var gauge_roll: Dictionary = _find_roll(rolls, "gauge_cost")
	_expect(not gauge_roll.is_empty(), "celestial armor should expose gauge cost roll")
	_expect(is_equal_approx(float(gauge_roll.get("min", 0.0)), 20.0), "gauge cost min should match Python")
	_expect(is_equal_approx(float(gauge_roll.get("max", 0.0)), 40.0), "gauge cost max should match Python")
	_expect(bool(gauge_roll.get("reverse", false)), "gauge cost should be a reverse roll")


func _find_roll(rolls: Array, key: String) -> Dictionary:
	for roll_value in rolls:
		var roll_data: Dictionary = roll_value if roll_value is Dictionary else {}
		if str(roll_data.get("key", "")) == key:
			return roll_data
	return {}


func _catalog_has_field_spawn(catalog: Object, item_name: String) -> bool:
	for item_value in catalog.get_field_spawn_items():
		var field_item: Dictionary = item_value if item_value is Dictionary else {}
		if str(field_item.get("name", "")) == item_name:
			return true
	return false


func _expect_original_icon_assets(item_data: Dictionary, item_label: String) -> void:
	var icon: Texture2D = ProjectResourceLoader.load_texture(str(item_data.get("icon_path", "")))
	_expect(icon != null, "%s static icon should load" % item_label)
	if icon != null:
		_expect(icon.get_width() == 32 and icon.get_height() == 32, "%s static icon should be the original 32px render" % item_label)

	var sheet: Texture2D = ProjectResourceLoader.load_texture(str(item_data.get("icon_sheet_path", "")))
	_expect(sheet != null, "%s animated icon sheet should load" % item_label)
	if sheet != null:
		_expect(sheet.get_width() == 1024 and sheet.get_height() == 32, "%s animated icon sheet should be the smooth 32-frame render" % item_label)


func _verify_descriptions_mention_knockback() -> void:
	# P2-B: 런타임이 스턴 AND 넉백을 막으므로 모든 표시 문구가 넉백을 언급해야 한다
	# (문구=다국어 동기화). 각 celestial_armor 설명 줄에 스턴 토큰이 있으면 넉백 토큰도
	# 반드시 있어야 한다 — 6개 언어 × MYTHIC_DESCRIPTION/PERK_SUMMARY 2계통 표류 봉인.
	var stun_tokens := ["스턴", "stun", "眩晕", "スタン", "aturdimiento", "atordoamento", "оглушение"]
	var kb_tokens := ["넉백", "knockback", "击退", "ノックバック", "empuje", "empurrão", "отбрасывание"]
	var loc: String = FileAccess.get_file_as_string("res://scripts/core/language_settings_data.gd")
	_expect(loc != "", "language_settings_data should be readable")
	for line in loc.split("\n"):
		if not line.contains("\"celestial_armor\""):
			continue
		if not _contains_any(line, stun_tokens):
			continue  # 이름 전용 줄(ITEM_DISPLAY/PERK_NAME)은 효과 문구가 없어 스킵
		_expect(
			_contains_any(line, kb_tokens),
			"celestial_armor localized desc mentions stun but not knockback: %s" % line.strip_edges()
		)
	# 한국어 소스 2파일(로컬라이제이션에 없음 — 직접 렌더): 갱신 문자열 존재 확인.
	var perk: String = FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_catalog.gd")
	_expect(perk.contains("스턴·넉백 무시 65%"), "perk catalog celestial_armor description must say 스턴·넉백")
	var cat: String = FileAccess.get_file_as_string("res://scripts/items/mythic_item_catalog_build_router.gd")
	_expect(cat.contains("스턴·넉백이 들어올 때 롤 확률로"), "item catalog celestial_armor description must say 스턴·넉백")


func _contains_any(text: String, tokens: Array) -> bool:
	for token in tokens:
		if text.contains(String(token)):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
