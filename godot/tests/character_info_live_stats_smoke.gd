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
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
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
	_expect(_find_stat(stats, "대시 토큰").is_empty(), "TAB stats should omit dash token summary")
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

	var lingpet_owner := FakeOwner.new({
		"lingpet_id": "maribo",
		"lingpet_state": "companion",
		"lingpet_companion_defense_rate": 0.30,
	})
	var lingpet_stats: Array = overlay._build_lingpet_stats(lingpet_owner)
	_expect(str(_find_stat(lingpet_stats, "이동 속도").get("value", "")) == "2.00", "Maribo move speed should use a slower single player-style speed value")
	_expect(not _find_stat(lingpet_stats, "몸집크기").is_empty(), "Maribo catch range should be labeled as body size")
	_expect(_find_stat(lingpet_stats, "캐치 범위").is_empty(), "Maribo stats should not expose the old catch-range label")
	_expect(str(_find_stat(lingpet_stats, "게이지 획득량").get("value", "")) == "40pt", "Maribo direct-hit gauge gain should be shown as the ringpet common stat")
	_expect(str(_find_stat(lingpet_stats, "액티브 쿨타임").get("value", "")) == "40초", "Maribo stats should show Hydro Sphere cooldown")
	_expect(_find_stat(lingpet_stats, "공명 충전 쿨타임").is_empty(), "Maribo stats should not expose the removed resonance-charge cooldown")
	var defense_stat: Dictionary = _find_stat(lingpet_stats, "방어율")
	_expect(str(defense_stat.get("value", "")) == "30%", "Maribo defense rate should be visible in lingpet stats")
	_expect(
		str(defense_stat.get("tooltip_body", "")).find("공을 안정적으로 막을 확률") >= 0,
		"Maribo defense rate should explain the actual intercept behavior in a tooltip"
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
	})
	var lunabi_panel_snapshot: Dictionary = CharacterInfoOverlayLingpetPresenter.build_panel_snapshot(lunabi_owner, Callable(CharacterInfoOverlayValueUtils, "safe_owner_get"), CharacterInfoOverlay.LINGPET_HATCH_REQUIRED_HITS)
	var lunabi_skill_specs: Array = CharacterInfoOverlayLingpetPresenter.get_skill_specs(lunabi_panel_snapshot, CharacterInfoOverlay.STAT_BUFF_COLOR)
	var lunabi_stats: Array = overlay._build_lingpet_stats(lunabi_owner)
	var lunabi_art_texture: Texture2D = CharacterInfoOverlayLingpetTextureLoader.get_art_texture("lunabi", {})
	var lunabi_live2d_source_0: Rect2 = CharacterInfoOverlayLingpetPresenter.panel_live2d_source_rect("lunabi", lunabi_art_texture.get_size() if lunabi_art_texture != null else Vector2.ZERO, 0.0)
	var lunabi_live2d_source_1: Rect2 = CharacterInfoOverlayLingpetPresenter.panel_live2d_source_rect("lunabi", lunabi_art_texture.get_size() if lunabi_art_texture != null else Vector2.ZERO, 0.07)
	_expect(str(lunabi_panel_snapshot.get("pet_id", "")) == "lunabi", "Lunabi panel snapshot should preserve its catalog pet id")
	_expect(lunabi_skill_specs.size() == 2, "Lunabi character-info panel should show its shipped active skill plus the shared passive icon")
	_expect(str((lunabi_skill_specs[0] as Dictionary).get("id", "")) == "lunabi_headbutt", "Lunabi active icon should use the Headbutt catalog skill id")
	_expect(str((lunabi_skill_specs[0] as Dictionary).get("icon_texture_id", "")).ends_with("lunabi_headbutt_skill_icon_imagegen_v1.png"), "Lunabi active icon should use the imagegen skill icon instead of Maribo's card")
	_expect(str((lunabi_skill_specs[1] as Dictionary).get("id", "")) == "lingpet_resonance_boost", "Lunabi fallback passive icon should come from the default shared passive pool")
	_expect(str(_find_stat(lunabi_stats, "액티브 쿨타임").get("value", "")) == "30초", "Lunabi should show the Headbutt active cooldown stat")
	_expect(str(_find_stat(lunabi_stats, "이동 속도").get("value", "")) == "4.75", "Lunabi character-info speed should use its own sortie-flight catalog stat, not Maribo's")
	_expect(CharacterInfoOverlayLingpetTextureLoader.uses_panel_live2d_art("lunabi"), "Lunabi character-info art should opt into the panel Live2D sheet")
	_expect(not CharacterInfoOverlayLingpetTextureLoader.uses_panel_live2d_art("maribo"), "Maribo character-info art should keep using the static cutin art for now")
	_expect(lunabi_art_texture != null and str(lunabi_art_texture.resource_path).ends_with("lunabi_click_live2d_pingpong_98f.png"), "Lunabi character-info art should resolve to the 98-frame panel Live2D sheet")
	_expect(lunabi_live2d_source_0.position == Vector2.ZERO and lunabi_live2d_source_0.size == Vector2(1024.0, 1024.0), "Lunabi character-info Live2D should start from the first 1024px sheet cell")
	_expect(is_equal_approx(lunabi_live2d_source_1.position.x, 1024.0), "Lunabi character-info Live2D should advance to the next sheet cell after one 16fps tick")
	_expect(CharacterInfoOverlayLingpetPresenter.should_redraw_panel_live2d(lunabi_panel_snapshot), "Lunabi character-info panel should request redraws while its panel Live2D is visible")
	_expect(not CharacterInfoOverlayLingpetPresenter.should_redraw_panel_live2d(maribo_panel_snapshot), "Maribo character-info panel should not request continuous Live2D redraws")

	print("character_info_live_stats_smoke: ok")
	quit(0)


func _finish_active_runtime_initialization(runtime: Object) -> void:
	if runtime == null or not runtime.has_method("prewarm_initialization_step"):
		return
	while not bool(runtime.prewarm_initialization_step()):
		pass


func _find_stat(stats: Array, label: String) -> Dictionary:
	for value in stats:
		if value is Dictionary:
			var stat: Dictionary = value
			if str(stat.get("label", "")) == label:
				return stat
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
	quit(1)
