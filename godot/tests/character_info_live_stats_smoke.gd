extends SceneTree

const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const CharacterInfoOverlay := preload("res://scripts/hud/character_info_overlay.gd")
const CharacterInfoOverlayLingpetPresenter := preload("res://scripts/hud/character_info_overlay_lingpet_presenter.gd")
const CharacterInfoOverlayLingpetTextureLoader := preload("res://scripts/hud/character_info_overlay_lingpet_texture_loader.gd")
const CharacterInfoOverlayOwnerState := preload("res://scripts/hud/character_info_overlay_owner_state.gd")
const CharacterInfoOverlayStatsPresenter := preload("res://scripts/hud/character_info_overlay_stats_presenter.gd")
const CharacterInfoOverlayValueUtils := preload("res://scripts/hud/character_info_overlay_value_utils.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetGuardianRunState := preload("res://scripts/lingpet/lingpet_guardian_run_state.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")


class FakeOwner:
	extends RefCounted

	var data: Dictionary = {}

	func _init(initial_data: Dictionary) -> void:
		data = initial_data.duplicate(true)

	func _get(property: StringName) -> Variant:
		return data.get(str(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		data[str(property)] = value
		return true

	func queue_redraw() -> void:
		pass


# Schema-gated owner that mirrors battle_scene_shell: set()/get() route through
# battle_scene_state, which SILENTLY no-ops writes to keys not in DEFAULT_VALUES.
# The plain FakeOwner above stores any key, so it cannot catch the real bug where
# a synced field is dropped because it is missing from the owner schema.
class SchemaGatedOwner:
	extends RefCounted

	var scene_state: Object = BattleSceneState.new()

	func _init() -> void:
		scene_state.reset()

	func _get(property: StringName) -> Variant:
		var key := str(property)
		if scene_state.has_key(key):
			return scene_state.get_value(key)
		return null

	func _set(property: StringName, value: Variant) -> bool:
		var key := str(property)
		if not scene_state.has_key(key):
			return false
		scene_state.set_value(key, value)
		return true

	func queue_redraw() -> void:
		pass

	func get_viewport_rect() -> Rect2:
		return Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))


class NullRegistry:
	extends RefCounted

	func get_instance(_key: String) -> Object:
		return null

	func get_cached_instance(_key: String) -> Object:
		return null


class FakeRegistry:
	var runtime_perk_state: Object
	var active_item_runtime: Object
	var mythic_item_runtime: Object

	func _init(perk_state: Object, active_runtime: Object, mythic_runtime: Object) -> void:
		runtime_perk_state = perk_state
		active_item_runtime = active_runtime
		mythic_item_runtime = mythic_runtime

	func get_instance(key: String) -> Object:
		match key:
			"runtime_perk_state":
				return runtime_perk_state
			"active_item_runtime":
				return active_item_runtime
			"mythic_item_runtime":
				return mythic_item_runtime
		return null


class CooldownPenaltyRuntime:
	extends RefCounted

	func get_active_item_cooldown_msec(base_cooldown_msec: float) -> float:
		return float(base_cooldown_msec) * 1.25


# 실전 게이지 산식(블루투스링) 배선 씰용 신화 스텁.
class BluetoothRingMythicStub:
	extends RefCounted

	func calculate_bluetooth_ring_gauge_charge(base_gain: float) -> float:
		return base_gain * 1.2


# 실전 대시 재충전 산식(축지부 배율) 배선 씰용 액티브 스텁.
class DashBoostActiveStub:
	extends RefCounted

	func get_dash_cooldown_multiplier() -> float:
		return 0.5


class SpeedMultiplierRuntime:
	extends RefCounted

	var multiplier := 1.0

	func _init(next_multiplier: float) -> void:
		multiplier = next_multiplier

	func get_player_speed_multiplier() -> float:
		return multiplier


class FakeCharacterRuntime:
	extends RefCounted

	func get_base_movement_config(_character_type: String) -> Dictionary:
		return {
			"paddle_speed": 6.0,
			"paddle_max_speed": 6.0,
		}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	var overlay: Object = CharacterInfoOverlay.new()
	var perk_state: Object = RuntimePerkState.new()
	var active_runtime: Object = ActiveItemRuntime.new()
	_finish_active_runtime_initialization(active_runtime)
	var mythic_runtime: Object = MythicItemRuntime.new()
	var registry := FakeRegistry.new(perk_state, active_runtime, mythic_runtime)
	var owner := FakeOwner.new({
		"selected_character_type": "smasher",
		"special_gauge": 120.0,
		"special_gauge_max": 500.0,
		"player_paddle_width": 155.0,
		"active_item_slots": [],
	})

	perk_state.runtime_skill_levels["common_swiftness"] = 2
	perk_state.runtime_skill_levels["common_bulk_up"] = 1
	perk_state.runtime_skill_levels["item_cooldown_mastery"] = 1
	_expect(active_runtime.effect_controller.activate_vitamin_pill(owner, registry), "vitamin pill should activate for the smoke test")

	var stats: Array = overlay._build_stats(owner, registry)
	_expect(stats.size() >= 9, "TAB stats should keep the live combat stat rows plus active-item slot count")
	_expect(_find_stat(stats, "게이지").is_empty(), "TAB stats should omit current gauge summary")
	_expect(_find_stat(stats, "활주 횟수").is_empty(), "TAB stats should omit the raw glide-charge summary")
	_expect(
		str(_find_stat(stats, "액티브 아이템 슬롯").get("value", "")) == "0 / 3",
		"TAB stats should show current active-item slots and base capacity"
	)
	_expect(
		abs(_stat_float(stats, "이동 속도") - 10.08) < 0.02,
		"TAB move speed should include common swiftness and active-item speed buffs"
	)
	_expect(
		_is_buff_color(_stat_color(stats, "이동 속도")),
		"TAB move speed buffs should be highlighted as a buff color"
	)
	_expect(
		abs(_stat_seconds(stats, "아이템 재충전") - 6.09) < 0.02,
		"TAB active-item cooldown should include runtime perk reductions"
	)
	_expect(
		_is_buff_color(_stat_color(stats, "아이템 재충전")),
		"TAB active-item cooldown reductions should be highlighted as a buff color"
	)

	# 능력치 툴팁 소스별 증감 내역 (2026-07-11): 어떤 퍽·아이템·상태이상이 스탯을
	# 바꿨는지 툴팁 본문에 원인 줄("· 라벨: ±N%")이 떠야 한다. 퍽 스텝은 구동
	# 퍽 이름으로, 액티브 아이템은 soft-contract를 통해 아이템 표시명으로 특정.
	var speed_perk_entry: Dictionary = _stat_breakdown_entry(stats, "이동 속도", "유운보")
	_expect(not speed_perk_entry.is_empty(), "move-speed breakdown should attribute the common_swiftness perk by display name")
	_expect(abs(float(speed_perk_entry.get("ratio", 0.0)) - 1.12) < 0.005, "swiftness Lv.2 should read as a +12% move-speed contribution")
	var speed_item_entry: Dictionary = _stat_breakdown_entry(stats, "이동 속도", "경신단")
	_expect(abs(float(speed_item_entry.get("ratio", 0.0)) - 1.5) < 0.005, "vitamin pill should read as a +50% move-speed contribution under its ITEM display name")
	var cooldown_perk_entry: Dictionary = _stat_breakdown_entry(stats, "아이템 재충전", "순환결")
	_expect(
		not cooldown_perk_entry.is_empty() and float(cooldown_perk_entry.get("ratio", 1.0)) < 1.0,
		"item-cooldown breakdown should attribute the mastery perk as a reduction"
	)
	_expect(not _find_stat(stats, "최대 기력").has("breakdown"), "base-value max-vigor row should not carry breakdown lines")
	# 증감 내역은 구조화 행(_player_stat_breakdown_rows_cache)으로 이동 —
	# 각 행은 {text, icon_id}. 툴팁 드로어가 아이콘 + 텍스트로 그린다.
	var speed_rows: Array = _stat_breakdown_rows(stats, "이동 속도")
	_expect(not _breakdown_row(speed_rows, "유운보: +12%").is_empty(), "move-speed breakdown row should carry the Yuunbo attribution")
	_expect(not _breakdown_row(speed_rows, "경신단: +50%").is_empty(), "move-speed breakdown row should name Gyeongsindan as the active-item cause")
	_expect(not _breakdown_row(_stat_breakdown_rows(stats, "아이템 재충전"), "순환결: -13%").is_empty(), "item-cooldown breakdown row should carry the Circulation Art reduction")

	# 편의 아이콘 (2026-07-12): 원인 행에 퍽/아이템 아이콘 id가 붙어야 한다.
	_expect(str(_breakdown_row(speed_rows, "유운보: +12%").get("icon_id", "")) == "common_swiftness", "Yuunbo breakdown row should carry the common_swiftness perk icon id")
	_expect(str(_breakdown_row(speed_rows, "경신단: +50%").get("icon_id", "")) == "vitamin_pill", "Gyeongsindan breakdown row should carry the vitamin item's icon id")
	_expect(str(_breakdown_row(_stat_breakdown_rows(stats, "아이템 재충전"), "순환결: -13%").get("icon_id", "")) == "item_cooldown_mastery", "Circulation Art breakdown row should carry the item_cooldown_mastery perk icon id")

	# 대시 거리는 스피릿 레이저 상수식(15×40×0.7=420)이 아니라 실전 감속 커브
	# 적분(210px)을 표시해야 한다 (2026-07-11 리뷰 P1: 실산식 일치).
	_expect(str(_find_stat(stats, "활주 거리").get("value", "")) == "210px", "TAB glide distance should show the real decel-curve traversal (210px), not the laser-length formula (420px)")

	# 실전 산식 배선 씰: 게이지=히트 라우터 체인(블루투스링), 대시 재충전=대시
	# 상태 체인(축지부 배율). HUD가 산식을 재구축하면 이 두 소스가 빠진다.
	var real_math_registry := FakeRegistry.new(RuntimePerkState.new(), DashBoostActiveStub.new(), BluetoothRingMythicStub.new())
	var real_math_stats: Array = overlay._build_stats(owner, real_math_registry)
	_expect(str(_find_stat(real_math_stats, "기력 획득량").get("value", "")) == "60pt", "TAB vigor gain should route through the real hit chain (bluetooth ring 50→60)")
	var ring_entry: Dictionary = _stat_breakdown_entry(real_math_stats, "기력 획득량", "블루투스링")
	_expect(abs(float(ring_entry.get("ratio", 0.0)) - 1.2) < 0.005, "gauge breakdown should name the bluetooth ring as a +20% source")
	_expect(str(_find_stat(real_math_stats, "활주 재충전").get("value", "")) == "2.50초", "TAB glide recharge should include the active dash-boost cooldown multiplier (300f×0.5)")
	var dash_boost_entry: Dictionary = _stat_breakdown_entry(real_math_stats, "활주 재충전", "축지부")
	_expect(abs(float(dash_boost_entry.get("ratio", 0.0)) - 0.5) < 0.005, "dash-recharge breakdown should name the dash boost as a -50% source")

	# 오귀속 씰 (2026-07-11 리뷰 P1): 신비의 주사위만 적용된 상태에서 주사위
	# 배율이 무공 이름("유운보")이나 범주("무공 효과")로 흡수되지 않고 자기 이름으로
	# 표시되어야 한다. 신비의 주사위는 별도 세션 WIP라 아직 미배선일 수 있어
	# has_method로 게이트한다 (미배선이면 오귀속할 대상 자체가 없다).
	if RuntimePerkState.new().has_method("commit_mystic_dice_roll"):
		var dice_state := RuntimePerkState.new()
		dice_state.commit_mystic_dice_roll({
			"player_speed": 10,
			"paddle_size": 0,
			"skill_gauge": 0,
			"dash_distance": 0,
			"dash_recovery": 0,
			"dash_cooldown": 0,
			"item_cooldown": 0,
		})
		var dice_registry := FakeRegistry.new(dice_state, active_runtime, null)
		var dice_stats: Array = overlay._build_stats(owner, dice_registry)
		var dice_entry: Dictionary = _stat_breakdown_entry(dice_stats, "이동 속도", "신비의 주사위")
		_expect(abs(float(dice_entry.get("ratio", 0.0)) - 1.10) < 0.005, "dice-only move-speed boost should surface as its own 신비의 주사위 line")
		_expect(_stat_breakdown_entry(dice_stats, "이동 속도", "유운보").is_empty(), "dice-only boost must NOT be misattributed to Yuunbo")
		_expect(_stat_breakdown_entry(dice_stats, "이동 속도", "무공 효과").is_empty(), "dice-only boost must NOT fall back to the generic martial-art-effect label")
	stats = overlay._build_stats(owner, registry)

	var lingpet_boosted_speed: float = CharacterInfoOverlayStatsPresenter.effective_move_speed(
		"mika",
		FakeCharacterRuntime.new(),
		null,
		null,
		null,
		null,
		SpeedMultiplierRuntime.new(1.10),
		Callable(CharacterInfoOverlayOwnerState, "call_numeric_multiplier")
	)
	_expect(
		abs(lingpet_boosted_speed - 6.6) < 0.02,
		"TAB move speed calculation should include lingpet player-speed multipliers"
	)

	active_runtime.effect_controller.long_boost_active = true
	active_runtime.effect_controller.long_boost_scale = 1.5
	stats = overlay._build_stats(owner, registry)
	_expect(
		_stat_pixels(stats, "몸집 크기") >= 246.0,
		"TAB body size should read live perk and active-item paddle scale, not only the cached owner width"
	)
	_expect(
		_is_buff_color(_stat_color(stats, "몸집 크기")),
		"TAB body size increases should be highlighted as a buff color"
	)

	_expect(
		int(mythic_runtime.acquire_item("slot_add", owner, registry, {"slot_add_count": 2.0}, true, false)) >= 0,
		"slot_add passive should be acquired and equipped"
	)
	owner.set("active_item_slots", [{"name": "banana"}, {"name": "soap"}])
	stats = overlay._build_stats(owner, registry)
	var active_slot_stat: Dictionary = _find_stat(stats, "액티브 아이템 슬롯")
	_expect(
		str(active_slot_stat.get("value", "")) == "2 / 5",
		"TAB stats should show active-item slot count with mythic slot expansion"
	)
	_expect(
		_is_buff_color(_stat_color(stats, "액티브 아이템 슬롯")),
		"TAB active-item slot capacity increases should be highlighted as a buff color"
	)

	var debuff_active_runtime: Object = ActiveItemRuntime.new()
	_finish_active_runtime_initialization(debuff_active_runtime)
	var debuff_registry := FakeRegistry.new(RuntimePerkState.new(), debuff_active_runtime, CooldownPenaltyRuntime.new())
	var debuff_stats: Array = overlay._build_stats(owner, debuff_registry)
	_expect(
		_is_debuff_color(_stat_color(debuff_stats, "아이템 재충전")),
		"TAB active-item cooldown increases should be highlighted as a debuff color"
	)
	var debuff_cooldown_entry: Dictionary = _stat_breakdown_entry(debuff_stats, "아이템 재충전", "신화 아이템")
	_expect(
		abs(float(debuff_cooldown_entry.get("ratio", 0.0)) - 1.25) < 0.005,
		"cooldown-penalty source should read as a +25% item-cooldown breakdown entry with its source label"
	)
	_expect(
		not _breakdown_row(_stat_breakdown_rows(debuff_stats, "아이템 재충전"), "신화 아이템: +25%").is_empty(),
		"item-cooldown breakdown row should name the debuff source with its +25% line"
	)

	var lingpet_owner := FakeOwner.new({
		"lingpet_id": "maribo",
		"lingpet_state": "companion",
		"lingpet_companion_defense_rate": 0.30,
		"lingpet_active_skill_id": "maribo_hydro_sphere",
		"lingpet_active_skill_level": 1,
		"lingpet_skill_id": "maribo_hydro_sphere",
		"lingpet_passive_skill_id": "lingpet_resonance_boost",
		"lingpet_passive_skill_level": 1,
	})
	var lingpet_stats: Array = overlay._build_lingpet_stats(lingpet_owner)
	_expect(str(_find_stat(lingpet_stats, "이동 속도").get("value", "")) == "2.00", "Maribo move speed should use a slower single player-style speed value")
	_expect(not _find_stat(lingpet_stats, "몸집크기").is_empty(), "Maribo catch range should be labeled as body size")
	_expect(_find_stat(lingpet_stats, "캐치 범위").is_empty(), "Maribo stats should not expose the old catch-range label")
	_expect(str(_find_stat(lingpet_stats, "기력 획득량").get("value", "")) == "40pt", "Maribo direct-hit vigor gain should be shown as the ringpet common stat")
	_expect(str(_find_stat(lingpet_stats, "액티브 쿨타임").get("value", "")) == "40초", "Maribo stats should show Hydro Sphere cooldown")
	_expect(_find_stat(lingpet_stats, "공명 충전 쿨타임").is_empty(), "Maribo stats should not expose the removed resonance-charge cooldown")
	var defense_stat: Dictionary = _find_stat(lingpet_stats, "방어율")
	_expect(str(defense_stat.get("value", "")) == "30%", "Maribo defense rate should be visible in lingpet stats")
	_expect(_find_stat(lingpet_stats, "출현율").is_empty(), "patrol-style Maribo should NOT show an 출현율 row (appearance rate is flight-only)")
	_expect(
		str(defense_stat.get("tooltip_body", "")).find("미리 예측해 가드") >= 0,
		"Maribo defense rate should explain the local predictive-guard behavior in a tooltip"
	)
	var maribo_panel_snapshot: Dictionary = CharacterInfoOverlayLingpetPresenter.build_panel_snapshot(lingpet_owner, Callable(CharacterInfoOverlayValueUtils, "safe_owner_get"), CharacterInfoOverlay.LINGPET_HATCH_REQUIRED_HITS)
	var maribo_skill_specs: Array = CharacterInfoOverlayLingpetPresenter.get_skill_specs(maribo_panel_snapshot, CharacterInfoOverlay.STAT_BUFF_COLOR)
	_expect(maribo_skill_specs.size() == 2, "Maribo character-info panel should show one active skill and one real passive icon")
	_expect(str((maribo_skill_specs[0] as Dictionary).get("id", "")) == "maribo_hydro_sphere", "Maribo active icon should use the catalog skill id")
	_expect(str((maribo_skill_specs[0] as Dictionary).get("card_texture_path", "")).find("maribo_hydro_sphere") >= 0, "Maribo active icon should use the catalog skill-card texture")
	_expect(str((maribo_skill_specs[1] as Dictionary).get("id", "")) == "lingpet_resonance_boost", "Maribo passive icon should use the Resonance Boost skill id")
	_expect(str((maribo_skill_specs[1] as Dictionary).get("icon_texture_id", "")) == LingpetCatalog.get_passive_icon_path("maribo", "lingpet_resonance_boost"), "Maribo passive icon should resolve through the lingpet catalog")
	var legacy_maribo_snapshot: Dictionary = maribo_panel_snapshot.duplicate(true)
	legacy_maribo_snapshot["companion_passive_skill_id"] = ""
	legacy_maribo_snapshot["companion_passive_skill_name"] = ""
	legacy_maribo_snapshot["companion_passive_skill_description"] = ""
	legacy_maribo_snapshot["companion_passive_skill_icon_path"] = ""
	var legacy_maribo_skill_specs: Array = CharacterInfoOverlayLingpetPresenter.get_skill_specs(legacy_maribo_snapshot, CharacterInfoOverlay.STAT_BUFF_COLOR)
	_expect(str((legacy_maribo_skill_specs[1] as Dictionary).get("id", "")) == "lingpet_resonance_boost", "legacy Maribo snapshot should resolve Resonance Boost")
	_expect(str((legacy_maribo_skill_specs[1] as Dictionary).get("icon_texture_id", "")) == LingpetCatalog.get_passive_icon_path("maribo", "lingpet_resonance_boost"), "legacy Maribo snapshot should keep the current passive icon")

	var lunabi_owner := FakeOwner.new({
		"lingpet_id": "lunabi",
		"lingpet_state": "companion",
		"lingpet_active_skill_id": "lunabi_headbutt",
		"lingpet_active_skill_level": 1,
		"lingpet_skill_id": "lunabi_headbutt",
		"lingpet_passive_skill_id": "lingpet_resonance_boost",
		"lingpet_passive_skill_level": 1,
	})
	var lunabi_panel_snapshot: Dictionary = CharacterInfoOverlayLingpetPresenter.build_panel_snapshot(lunabi_owner, Callable(CharacterInfoOverlayValueUtils, "safe_owner_get"), CharacterInfoOverlay.LINGPET_HATCH_REQUIRED_HITS)
	var lunabi_skill_specs: Array = CharacterInfoOverlayLingpetPresenter.get_skill_specs(lunabi_panel_snapshot, CharacterInfoOverlay.STAT_BUFF_COLOR)
	var lunabi_stats: Array = overlay._build_lingpet_stats(lunabi_owner)
	var lunabi_art_texture: Texture2D = CharacterInfoOverlayLingpetTextureLoader.get_art_texture("lunabi", {})
	var lunabi_loaded_size := lunabi_art_texture.get_size() if lunabi_art_texture != null else Vector2.ZERO
	var lunabi_cell_size := Vector2(lunabi_loaded_size.x / 14.0, lunabi_loaded_size.y / 7.0)
	var lunabi_live2d_source_0: Rect2 = CharacterInfoOverlayLingpetPresenter.panel_live2d_source_rect("lunabi", lunabi_art_texture.get_size() if lunabi_art_texture != null else Vector2.ZERO, 0.0)
	var lunabi_live2d_source_1: Rect2 = CharacterInfoOverlayLingpetPresenter.panel_live2d_source_rect("lunabi", lunabi_art_texture.get_size() if lunabi_art_texture != null else Vector2.ZERO, 0.07)
	_expect(str(lunabi_panel_snapshot.get("pet_id", "")) == "lunabi", "Lunabi panel snapshot should preserve its catalog pet id")
	_expect(lunabi_skill_specs.size() == 2, "Lunabi character-info panel should show its shipped active skill plus the shared passive icon")
	_expect(str((lunabi_skill_specs[0] as Dictionary).get("id", "")) == "lunabi_headbutt", "Lunabi active icon should use the Headbutt catalog skill id")
	_expect(str((lunabi_skill_specs[0] as Dictionary).get("icon_texture_id", "")).ends_with("lunabi_headbutt_skill_icon_imagegen_v1.png"), "Lunabi active icon should use the imagegen skill icon instead of Maribo's card")
	_expect(str((lunabi_skill_specs[1] as Dictionary).get("id", "")) == "lingpet_resonance_boost", "Lunabi fallback passive icon should come from the default shared passive pool")
	_expect(str(_find_stat(lunabi_stats, "액티브 쿨타임").get("value", "")) == "30초", "Lunabi should show the Headbutt active cooldown stat")
	_expect(str(_find_stat(lunabi_stats, "이동 속도").get("value", "")) == "4.75", "Lunabi character-info speed should use its own sortie-flight catalog stat, not Maribo's")
	_expect(_find_stat(lunabi_stats, "방어율").is_empty(), "flight-style Lunabi should NOT show a 방어율 row (defense intercept is patrol-only)")
	_expect(str(_find_stat(lunabi_stats, "출현율").get("value", "")) == "30%", "flight-style Lunabi should show an 출현율 row from its catalog appearance_rate")
	_expect(CharacterInfoOverlayLingpetTextureLoader.uses_panel_live2d_art("lunabi"), "Lunabi character-info art should opt into the panel Live2D sheet")
	_expect(not CharacterInfoOverlayLingpetTextureLoader.uses_panel_live2d_art("maribo"), "Maribo character-info art should keep using the static cutin art for now")
	_expect(lunabi_art_texture != null and str(lunabi_art_texture.resource_path).ends_with("lunabi_click_live2d_pingpong_98f.png"), "Lunabi character-info art should resolve to the 98-frame panel Live2D sheet")
	_expect(lunabi_live2d_source_0.position == Vector2.ZERO and lunabi_live2d_source_0.size == lunabi_cell_size, "Lunabi character-info Live2D should start from the first imported sheet cell")
	_expect(is_equal_approx(lunabi_live2d_source_1.position.x, lunabi_cell_size.x), "Lunabi character-info Live2D should advance to the next imported sheet cell after one 16fps tick")
	_expect(CharacterInfoOverlayLingpetPresenter.should_redraw_panel_live2d(lunabi_panel_snapshot), "Lunabi character-info panel should request redraws while its panel Live2D is visible")
	_expect(CharacterInfoOverlayLingpetPresenter.should_redraw_panel_live2d(maribo_panel_snapshot), "Maribo character-info panel should keep redrawing so the aurora backdrop animates (every companion, not only live2d pets)")
	var nekuring_owner := FakeOwner.new({
		"lingpet_id": "nekuring",
		"lingpet_state": "companion",
	})
	var nekuring_panel_snapshot: Dictionary = CharacterInfoOverlayLingpetPresenter.build_panel_snapshot(nekuring_owner, Callable(CharacterInfoOverlayValueUtils, "safe_owner_get"), CharacterInfoOverlay.LINGPET_HATCH_REQUIRED_HITS)
	var nekuring_art_texture: Texture2D = CharacterInfoOverlayLingpetTextureLoader.get_art_texture("nekuring", {})
	var nekuring_live2d_source_0: Rect2 = CharacterInfoOverlayLingpetPresenter.panel_live2d_source_rect("nekuring", nekuring_art_texture.get_size() if nekuring_art_texture != null else Vector2.ZERO, 0.0)
	var nekuring_live2d_source_1: Rect2 = CharacterInfoOverlayLingpetPresenter.panel_live2d_source_rect("nekuring", nekuring_art_texture.get_size() if nekuring_art_texture != null else Vector2.ZERO, 0.07)
	_expect(CharacterInfoOverlayLingpetTextureLoader.uses_panel_live2d_art("nekuring"), "Nekuring character-info art should opt into the panel Live2D sheet")
	_expect(nekuring_art_texture != null and str(nekuring_art_texture.resource_path).ends_with("nekuring_click_live2d_pingpong_98f.png"), "Nekuring character-info art should resolve to the 98-frame panel Live2D sheet")
	var nekuring_loaded_size := nekuring_art_texture.get_size() if nekuring_art_texture != null else Vector2.ZERO
	var nekuring_cell_size := Vector2(nekuring_loaded_size.x / 14.0, nekuring_loaded_size.y / 7.0)
	_expect(nekuring_live2d_source_0.position == Vector2.ZERO and nekuring_live2d_source_0.size == nekuring_cell_size, "Nekuring character-info Live2D should start from the first imported sheet cell")
	_expect(is_equal_approx(nekuring_live2d_source_1.position.x, nekuring_cell_size.x), "Nekuring character-info Live2D should advance to the next imported sheet cell after one 16fps tick")
	_expect(CharacterInfoOverlayLingpetPresenter.should_redraw_panel_live2d(nekuring_panel_snapshot), "Nekuring character-info panel should request redraws while its panel Live2D is visible")

	_verify_defense_override_reaches_panel_through_schema_gated_owner()
	_verify_enhancement_stat_boosts_reach_panel_through_schema_gated_owner()
	_verify_second_active_enhancement_level_reaches_panel_through_schema_gated_owner()
	_verify_second_slot_rows_reach_lingpet_tab()
	_verify_snapshot_sync_keys_are_schema_declared()

	ProjectResourceLoader.clear_caches()
	await _drain_frames(12)
	call_deferred("_finish_ok")


func _finish_ok() -> void:
	print("character_info_live_stats_smoke: ok")
	quit(0)


func _verify_defense_override_reaches_panel_through_schema_gated_owner() -> void:
	# Regression: the F7 defense-rate override must reach the character-info panel.
	# The panel reads owner.lingpet_companion_defense_rate; the per-frame sync writes
	# it via owner.set(). On the REAL owner (battle_scene_shell -> battle_scene_state)
	# set() SILENTLY no-ops keys missing from DEFAULT_VALUES, so when the field is not
	# declared the panel falls back to the catalog rate (== base, so it went unnoticed
	# at the base value) and the override never shows. A plain dict FakeOwner cannot
	# catch this; SchemaGatedOwner mirrors the real schema gate.
	var owner := SchemaGatedOwner.new()
	var registry := NullRegistry.new()
	var runtime: Object = LingpetEggRuntime.new()
	_expect(
		bool(runtime.debug_grant_and_activate_pet("maribo", owner, false, "maribo_hydro_sphere", "lingpet_resonance_boost", registry, 1, 1)),
		"schema-gated owner should accept a Maribo debug grant"
	)
	runtime.set_debug_defense_rate_override(0.5)
	runtime.update(0.0, owner, registry)
	var snapshot: Dictionary = CharacterInfoOverlayLingpetPresenter.build_panel_snapshot(owner, Callable(CharacterInfoOverlayValueUtils, "safe_owner_get"), CharacterInfoOverlay.LINGPET_HATCH_REQUIRED_HITS)
	_expect(
		is_equal_approx(float(snapshot.get("companion_defense_rate", 0.0)), 0.5),
		"F7 defense override (0.5) should reach the character-info panel through the schema-gated owner, not be dropped as Maribo's catalog 0.30"
	)

	# Clearing the override restores the catalog rate end-to-end through the same owner.
	runtime.set_debug_defense_rate_override(-1.0)
	runtime.update(0.0, owner, registry)
	var cleared: Dictionary = CharacterInfoOverlayLingpetPresenter.build_panel_snapshot(owner, Callable(CharacterInfoOverlayValueUtils, "safe_owner_get"), CharacterInfoOverlay.LINGPET_HATCH_REQUIRED_HITS)
	_expect(
		is_equal_approx(float(cleared.get("companion_defense_rate", 0.0)), 0.30),
		"clearing the override should restore Maribo's catalog 30% in the panel"
	)


func _verify_enhancement_stat_boosts_reach_panel_through_schema_gated_owner() -> void:
	# Guardian Enhance stacks (기동/게이지 강화) boost the runtime stats through
	# lingpet_current_profile.get_stat, and the per-frame sync mirrors the
	# BOOSTED values onto the owner. If the owner keys are missing from
	# BattleSceneState.DEFAULT_VALUES, owner.set() silently no-ops and the
	# panel falls back to the catalog BASE — the upgrade applies in gameplay
	# but never shows in the TAB rows (sibling of the defense-rate trap).
	var owner := SchemaGatedOwner.new()
	var registry := NullRegistry.new()
	var runtime: Object = LingpetEggRuntime.new()
	_expect(
		bool(runtime.debug_grant_and_activate_pet("maribo", owner, false, "maribo_hydro_sphere", "lingpet_resonance_boost", registry, 1, 1)),
		"schema-gated owner should accept a Maribo debug grant for the stat-boost case"
	)
	var mobility_result: Dictionary = runtime.apply_guardian_enhancement_candidate(
		{"type": LingpetGuardianRunState.REWARD_TYPE_MOBILITY}, owner, registry, "maribo"
	)
	var gauge_result: Dictionary = runtime.apply_guardian_enhancement_candidate(
		{"type": LingpetGuardianRunState.REWARD_TYPE_GAUGE}, owner, registry, "maribo"
	)
	_expect(bool(mobility_result.get("accepted", false)), "Guardian Enhance should apply the movement fixture stack")
	_expect(bool(gauge_result.get("accepted", false)), "Guardian Enhance should apply the vigor fixture stack")
	runtime.update(0.0, owner, registry)
	var base_gauge := float(LingpetCatalog.get_stat("maribo", "hit_gauge_gain", 40.0))
	var base_speed := float(LingpetCatalog.get_stat("maribo", "patrol_speed_default", 0.0))
	_expect(base_speed > 0.0, "Maribo should expose a catalog patrol speed for the divergence fixture")
	var rewards: Dictionary = runtime.get_guardian_enhancement_rewards_for_tests("maribo")
	var gauge_stacks := mini(int(rewards.get("gauge_stacks", 0)), LingpetGuardianRunState.MAX_GAUGE_STACKS)
	var mobility_stacks := mini(int(rewards.get("mobility_stacks", 0)), LingpetGuardianRunState.MAX_MOBILITY_STACKS)
	var expected_gauge := base_gauge + float(gauge_stacks) * 5.0
	var expected_speed := base_speed * (1.0 + minf(float(mobility_stacks) * 5.0, 30.0) / 100.0)
	_expect(gauge_stacks > 0, "stat-boost fixture should earn gauge stacks before checking panel sync")
	_expect(mobility_stacks > 0, "stat-boost fixture should earn mobility stacks before checking panel sync")
	var snapshot: Dictionary = CharacterInfoOverlayLingpetPresenter.build_panel_snapshot(owner, Callable(CharacterInfoOverlayValueUtils, "safe_owner_get"), CharacterInfoOverlay.LINGPET_HATCH_REQUIRED_HITS)
	# Derive the panel expectation from the live enhancement store.
	_expect(
		is_equal_approx(float(snapshot.get("companion_hit_gauge_gain", 0.0)), expected_gauge),
		"기력 강화 stacks should reach the panel vigor-gain row instead of the catalog base"
	)
	_expect(
		is_equal_approx(float(snapshot.get("companion_patrol_speed_default", 0.0)), expected_speed),
		"기동 강화 stacks should reach the panel move-speed row instead of the catalog base"
	)


func _verify_second_active_enhancement_level_reaches_panel_through_schema_gated_owner() -> void:
	# Guardian Enhance raises the SECOND active skill's effective level via
	# second_active_skill_bonus, folded into the profile's slot-1 level and the LIVE
	# runtime snapshot. But the TAB panel reads the slot-1 level from the owner key
	# lingpet_second_active_skill_level, which _sync_second_skill_static_owner must
	# write with the BOOSTED level (mirroring its primary sibling that writes
	# lingpet_active_skill_level). If that write is omitted, the owner key stays at
	# the loadout BASE level (1) and the TAB 2nd-active card is pinned at Lv.1 while
	# enhancement raises the real level everywhere else — Owner-Field Schema Trap.
	# The manual-owner.set panel test above (_verify_second_slot_rows) can't catch
	# this because it never exercises the runtime SYNC write; this fixture drives the
	# real LingpetEggRuntime.update owner sync. Reverse-verified: removing the
	# lingpet_second_active_skill_level _set_pair line fails the two asserts below.
	var owner := SchemaGatedOwner.new()
	var registry := NullRegistry.new()
	var runtime: Object = LingpetEggRuntime.new()
	_expect(
		bool(runtime.debug_grant_and_activate_pet("red_dragon", owner, false, "red_dragon_dragon_breath", "", registry, 1, 1)),
		"schema-gated owner should accept a Red Dragon primary skill for the 2nd-active case"
	)
	var unlock_result: Dictionary = runtime.apply_guardian_enhancement_candidate(
		{"type": LingpetGuardianRunState.REWARD_TYPE_SECOND_ACTIVE_UNLOCK}, owner, registry, "red_dragon"
	)
	_expect(bool(unlock_result.get("accepted", false)), "Guardian Enhance should unlock the second active slot")
	runtime.update(0.0, owner, registry)
	var skill_result: Dictionary = runtime.apply_guardian_enhancement_candidate(
		{"type": LingpetGuardianRunState.REWARD_TYPE_ACTIVE_SKILL, "skill_slot": 2}, owner, registry, "red_dragon"
	)
	_expect(bool(skill_result.get("accepted", false)), "Guardian Enhance should raise the second active skill level")
	runtime.update(0.0, owner, registry)

	var rewards: Dictionary = runtime.get_guardian_enhancement_rewards_for_tests("red_dragon")
	_expect(bool(rewards.get("second_active_unlocked", false)), "2nd-active fixture should retain the Guardian Enhance unlock")
	var second_bonus := int(rewards.get("second_active_skill_bonus", 0))
	_expect(second_bonus > 0, "2nd-active fixture should earn a second_active_skill_bonus so the base-vs-boosted divergence is real (a base==boosted case passes even with the bug)")
	var expected_second_level := LingpetCatalog.clamp_skill_level(LingpetCatalog.DEFAULT_ACTIVE_SKILL_LEVEL + second_bonus)
	_expect(expected_second_level > 1, "divergent case: the boosted 2nd-active level must exceed the base loadout level")

	# The owner key the TAB panel reads must carry the BOOSTED level, not base 1.
	_expect(
		int(owner.get("lingpet_second_active_skill_level")) == expected_second_level,
		"enhancement-boosted 2nd active level should reach the lingpet_second_active_skill_level owner key, not the loadout base"
	)
	var snapshot: Dictionary = CharacterInfoOverlayLingpetPresenter.build_panel_snapshot(owner, Callable(CharacterInfoOverlayValueUtils, "safe_owner_get"), CharacterInfoOverlay.LINGPET_HATCH_REQUIRED_HITS)
	_expect(str(snapshot.get("companion_skill_id_1", "")) != "", "2nd-active fixture should fill the slot-1 active card")
	_expect(
		int(snapshot.get("companion_skill_level_1", 0)) == expected_second_level,
		"enhancement-boosted 2nd active level should reach the TAB panel companion_skill_level_1 (Owner-Field Schema Trap: _sync_second_skill_static_owner must write the level)"
	)

	# Ordering contract: lingpet_loadout_state.sync_owner writes the loadout BASE
	# level to the SAME owner key whenever ensure_pet_loadout re-runs (runtime cache
	# invalid). Every invalidator must also invalidate the snapshot-builder sync
	# cache so the BOOSTED write re-fires AFTER the base write in the same
	# _sync_owner pass — otherwise the static-surface gate skips the re-write (key
	# unchanged) and the stale base sticks. Exercise the risky follow-on frames plus
	# an explicit invalidation round trip (mimics pet-switch / loadout-change /
	# level-up aftermath).
	for _frame in range(3):
		runtime.update(0.016, owner, registry)
	_expect(
		int(owner.get("lingpet_second_active_skill_level")) == expected_second_level,
		"boosted 2nd active level should survive follow-on update frames (loadout base writer must not clobber)"
	)
	runtime._loadout_state.invalidate_runtime_and_snapshot_cache(runtime._snapshot_builder)
	runtime.update(0.016, owner, registry)
	_expect(
		int(owner.get("lingpet_second_active_skill_level")) == expected_second_level,
		"boosted 2nd active level should survive a loadout-cache invalidation round trip (base writer re-fires, boosted write must follow in the same sync pass)"
	)


func _verify_second_slot_rows_reach_lingpet_tab() -> void:
	for key in [
		"lingpet_second_skill_id",
		"ringpet_second_skill_id",
		"lingpet_second_skill_name",
		"ringpet_second_skill_name",
		"lingpet_second_skill_cooldown_duration",
		"ringpet_second_skill_cooldown_duration",
		"lingpet_second_active_skill_level",
		"ringpet_second_active_skill_level",
		"lingpet_second_passive_skill_id",
		"ringpet_second_passive_skill_id",
		"lingpet_second_passive_skill_level",
		"ringpet_second_passive_skill_level",
	]:
		_expect(BattleSceneState.DEFAULT_VALUES.has(key), "BattleSceneState should declare %s for TAB slot-1 sync" % key)

	var owner := SchemaGatedOwner.new()
	owner.set("lingpet_id", "red_dragon")
	owner.set("lingpet_state", "companion")
	owner.set("lingpet_active_skill_id", "red_dragon_dragon_breath")
	owner.set("lingpet_active_skill_level", 2)
	owner.set("lingpet_skill_id", "red_dragon_dragon_breath")
	owner.set("lingpet_skill_name", "Dragon Breath")
	owner.set("lingpet_skill_cooldown_duration", 21.0)
	owner.set("lingpet_passive_skill_id", "lingpet_resonance_boost")
	owner.set("lingpet_passive_skill_level", 2)
	owner.set("lingpet_companion_appearance_rate", 0.30)
	owner.set("lingpet_second_skill_id", "red_dragon_dragon_wing")
	owner.set("lingpet_second_skill_name", "Wing Live")
	owner.set("lingpet_second_skill_cooldown_duration", 17.0)
	owner.set("lingpet_second_active_skill_level", 3)
	owner.set("lingpet_second_passive_skill_id", "lingpet_tailwind_steps")
	owner.set("lingpet_second_passive_skill_level", 4)

	var snapshot: Dictionary = CharacterInfoOverlayLingpetPresenter.build_panel_snapshot(owner, Callable(CharacterInfoOverlayValueUtils, "safe_owner_get"), CharacterInfoOverlay.LINGPET_HATCH_REQUIRED_HITS)
	_expect(str(snapshot.get("companion_skill_id_1", "")) == "red_dragon_dragon_wing", "TAB snapshot should read slot-1 active id from the raw owner key")
	_expect(str(snapshot.get("companion_skill_name_1", "")) == "Wing Live", "TAB snapshot should prefer the live slot-1 active name over catalog text")
	_expect(is_equal_approx(float(snapshot.get("companion_skill_cooldown_duration_1", 0.0)), 17.0), "TAB snapshot should read the live slot-1 active cooldown duration")
	_expect(int(snapshot.get("companion_skill_level_1", 0)) == 3, "TAB snapshot should read the slot-1 active level")
	_expect(str(snapshot.get("companion_passive_skill_id_1", "")) == "lingpet_tailwind_steps", "TAB snapshot should read slot-1 passive id through loadout owner sync")
	_expect(int(snapshot.get("companion_passive_skill_level_1", 0)) == 4, "TAB snapshot should read the slot-1 passive level")
	_expect(
		str(snapshot.get("companion_passive_skill_icon_path_1", "")) == LingpetCatalog.get_passive_icon_path("red_dragon", "lingpet_tailwind_steps"),
		"TAB snapshot should resolve slot-1 passive icon metadata from the catalog after the raw owner gate"
	)

	var specs: Array = CharacterInfoOverlayLingpetPresenter.get_skill_specs(snapshot, CharacterInfoOverlay.STAT_BUFF_COLOR)
	_expect(_has_skill_spec_id(specs, "red_dragon_dragon_breath"), "TAB skill rail should keep the primary active icon")
	_expect(_has_skill_spec_id(specs, "red_dragon_dragon_wing"), "TAB skill rail should draw the slot-1 active icon")
	_expect(_has_skill_spec_id(specs, "lingpet_resonance_boost"), "TAB skill rail should keep the primary passive icon")
	_expect(_has_skill_spec_id(specs, "lingpet_tailwind_steps"), "TAB skill rail should draw the slot-1 passive icon")
	_expect(str(_find_skill_spec(specs, "red_dragon_dragon_wing").get("badge", "")) == "A", "slot-1 active icon should use the active badge")
	_expect(str(_find_skill_spec(specs, "lingpet_tailwind_steps").get("badge", "")) == "P", "slot-1 passive icon should use the passive badge")

	var spacious_rect := Rect2(Vector2.ZERO, Vector2(560.0, 360.0))
	var spacious_rows: Array = _build_lingpet_rows_from_snapshot(snapshot, spacious_rect)
	_expect(not _find_stat_label_contains(spacious_rows, "2nd").is_empty(), "TAB lingpet stats should include the slot-1 active cooldown row when the row budget fits")
	_expect(str(_find_stat_label_contains(spacious_rows, "2nd").get("value", "")) == "17초", "slot-1 active cooldown row should show the live cooldown duration")

	var tight_rect := Rect2(Vector2.ZERO, Vector2(560.0, 340.0))
	var tight_rows: Array = _build_lingpet_rows_from_snapshot(snapshot, tight_rect)
	var tight_lingpet_rect := CharacterInfoOverlayStatsPresenter.lingpet_stat_rect_for_sections(tight_rect)
	var tight_visible_capacity := CharacterInfoOverlayStatsPresenter.lingpet_stat_rows_visible_capacity(tight_lingpet_rect, tight_rows.size())
	_expect(not _find_stat_label_contains(tight_rows, "2nd").is_empty(), "retiring affinity should free the tight-budget row for the slot-1 cooldown")
	_expect(_find_stat(tight_rows, "교감").is_empty(), "TAB lingpet stats must not retain the retired affinity row")
	_expect(tight_visible_capacity >= tight_rows.size(), "TAB lingpet stat row budget should keep every emitted row drawable")

	var cache := {}
	var spacious_cache: Dictionary = CharacterInfoOverlayLingpetPresenter.build_stats_cached(snapshot, cache, Color.WHITE, Color.WHITE, Color.WHITE, CharacterInfoOverlay.STAT_BUFF_COLOR, 60.0, CharacterInfoOverlay.LINGPET_HATCH_REQUIRED_HITS, "", spacious_rect)
	var tight_cache: Dictionary = CharacterInfoOverlayLingpetPresenter.build_stats_cached(snapshot, spacious_cache, Color.WHITE, Color.WHITE, Color.WHITE, CharacterInfoOverlay.STAT_BUFF_COLOR, 60.0, CharacterInfoOverlay.LINGPET_HATCH_REQUIRED_HITS, "", tight_rect)
	_expect(not _find_stat_label_contains(CharacterInfoOverlayValueUtils.get_array(spacious_cache.get("rows", [])), "2nd").is_empty(), "spacious cached TAB rows should keep the slot-1 active cooldown")
	_expect(not _find_stat_label_contains(CharacterInfoOverlayValueUtils.get_array(tight_cache.get("rows", [])), "2nd").is_empty(), "tight cached TAB rows should retain the freed slot-1 cooldown row")
	_expect(int(spacious_cache.get("hash", 0)) != int(tight_cache.get("hash", 0)), "row budget rect should participate in the TAB stats cache hash")

	var locked_owner := SchemaGatedOwner.new()
	locked_owner.set("lingpet_id", "red_dragon")
	locked_owner.set("lingpet_state", "companion")
	locked_owner.set("lingpet_active_skill_id", "red_dragon_dragon_breath")
	locked_owner.set("lingpet_active_skill_level", 2)
	locked_owner.set("lingpet_skill_id", "red_dragon_dragon_breath")
	locked_owner.set("lingpet_passive_skill_id", "lingpet_resonance_boost")
	locked_owner.set("lingpet_passive_skill_level", 2)
	var locked_snapshot: Dictionary = CharacterInfoOverlayLingpetPresenter.build_panel_snapshot(locked_owner, Callable(CharacterInfoOverlayValueUtils, "safe_owner_get"), CharacterInfoOverlay.LINGPET_HATCH_REQUIRED_HITS)
	var locked_specs: Array = CharacterInfoOverlayLingpetPresenter.get_skill_specs(locked_snapshot, CharacterInfoOverlay.STAT_BUFF_COLOR)
	_expect(str(locked_snapshot.get("companion_skill_id_1", "")) == "", "locked slot-1 active should stay hidden instead of catalog-falling back")
	_expect(str(locked_snapshot.get("companion_passive_skill_id_1", "")) == "", "locked slot-1 passive should stay hidden instead of catalog-falling back")
	_expect(not _has_skill_spec_id(locked_specs, "red_dragon_dragon_wing"), "locked slot-1 active should not draw a rail icon")
	_expect(not _has_skill_spec_id(locked_specs, "lingpet_tailwind_steps"), "locked slot-1 passive should not draw a rail icon")
	_expect(
		CharacterInfoOverlayLingpetPresenter.get_stats_cache_hash(snapshot, CharacterInfoOverlay.LINGPET_HATCH_REQUIRED_HITS) != CharacterInfoOverlayLingpetPresenter.get_stats_cache_hash(locked_snapshot, CharacterInfoOverlay.LINGPET_HATCH_REQUIRED_HITS),
		"TAB lingpet stats cache hash should include slot-1 keys so lock/unlock changes cannot freeze"
	)


func _verify_snapshot_sync_keys_are_schema_declared() -> void:
	# Structural seal for the owner-field schema trap: every lingpet_/ringpet_
	# key the per-frame snapshot sync writes must be declared in
	# BattleSceneState.DEFAULT_VALUES, or owner.set() silently no-ops it and
	# every mirror reader falls back to stale/base data.
	var source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_runtime_snapshot_builder.gd")
	_expect(source != "", "snapshot sync source should be readable for the schema seal")
	var key_regex := RegEx.new()
	key_regex.compile("\"((?:ling|ring)pet_[a-z0-9_]+)\"")
	var seen := {}
	for line in source.split("\n"):
		if (
			line.find("_set_pair(owner") < 0
			and line.find("_set_single(owner") < 0
			and line.find("owner.set(") < 0
		):
			continue
		for match_value in key_regex.search_all(line):
			var key := match_value.get_string(1)
			if seen.has(key):
				continue
			seen[key] = true
			_expect(BattleSceneState.DEFAULT_VALUES.has(key), "snapshot sync key must be declared in BattleSceneState.DEFAULT_VALUES or owner.set() silently no-ops it: %s" % key)
	_expect(seen.size() >= 40, "schema seal should scan the full snapshot sync key family (found %d)" % seen.size())


func _finish_active_runtime_initialization(runtime: Object) -> void:
	if runtime == null or not runtime.has_method("prewarm_initialization_step"):
		return
	while not bool(runtime.prewarm_initialization_step()):
		pass


func _drain_frames(frame_count: int) -> void:
	for i in frame_count:
		await process_frame


func _build_lingpet_rows_from_snapshot(snapshot: Dictionary, row_budget_rect: Rect2) -> Array:
	return CharacterInfoOverlayLingpetPresenter.build_stats(snapshot, Color.WHITE, Color.WHITE, Color.WHITE, CharacterInfoOverlay.STAT_BUFF_COLOR, 60.0, CharacterInfoOverlay.LINGPET_HATCH_REQUIRED_HITS, "", row_budget_rect)


func _find_skill_spec(specs: Array, id: String) -> Dictionary:
	for value in specs:
		if value is Dictionary:
			var spec: Dictionary = value
			if str(spec.get("id", "")) == id:
				return spec
	return {}


func _has_skill_spec_id(specs: Array, id: String) -> bool:
	return not _find_skill_spec(specs, id).is_empty()


func _find_stat_label_contains(stats: Array, label_fragment: String) -> Dictionary:
	for value in stats:
		if value is Dictionary:
			var stat: Dictionary = value
			if str(stat.get("label", "")).find(label_fragment) >= 0:
				return stat
	return {}


func _find_stat(stats: Array, label: String) -> Dictionary:
	for value in stats:
		if value is Dictionary:
			var stat: Dictionary = value
			if str(stat.get("label", "")) == label:
				return stat
	return {}


func _stat_breakdown_entry(stats: Array, label: String, entry_label: String) -> Dictionary:
	var breakdown: Variant = _find_stat(stats, label).get("breakdown", [])
	if breakdown is Array:
		for value in (breakdown as Array):
			if value is Dictionary and str((value as Dictionary).get("label", "")) == entry_label:
				return value
	return {}


func _player_stat_tooltip(stats: Array, label: String) -> String:
	for i in range(stats.size()):
		if stats[i] is Dictionary and str((stats[i] as Dictionary).get("label", "")) == label:
			if i < CharacterInfoOverlayStatsPresenter._player_stat_tooltip_cache.size():
				return str(CharacterInfoOverlayStatsPresenter._player_stat_tooltip_cache[i])
	return ""


func _stat_breakdown_rows(stats: Array, label: String) -> Array:
	for i in range(stats.size()):
		if stats[i] is Dictionary and str((stats[i] as Dictionary).get("label", "")) == label:
			if i < CharacterInfoOverlayStatsPresenter._player_stat_breakdown_rows_cache.size():
				var rows: Variant = CharacterInfoOverlayStatsPresenter._player_stat_breakdown_rows_cache[i]
				return rows if rows is Array else []
	return []


func _breakdown_row(rows: Array, text: String) -> Dictionary:
	for value in rows:
		if value is Dictionary and str((value as Dictionary).get("text", "")) == text:
			return value
	return {}


func _stat_float(stats: Array, label: String) -> float:
	return float(str(_find_stat(stats, label).get("value", "0")))


func _stat_seconds(stats: Array, label: String) -> float:
	return float(str(_find_stat(stats, label).get("value", "0")).replace("초", ""))


func _stat_pixels(stats: Array, label: String) -> float:
	return float(str(_find_stat(stats, label).get("value", "0")).replace("px", ""))


func _stat_color(stats: Array, label: String) -> Color:
	var color: Variant = _find_stat(stats, label).get("color", Color.WHITE)
	return color if color is Color else Color.WHITE


func _is_buff_color(color: Color) -> bool:
	return color.g > color.r and color.g > color.b


func _is_debuff_color(color: Color) -> bool:
	return color.r > color.g and color.r > color.b


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	ProjectResourceLoader.clear_caches()
	quit(1)
