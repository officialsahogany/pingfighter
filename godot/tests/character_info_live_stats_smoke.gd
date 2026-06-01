extends SceneTree

const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const CharacterInfoOverlay := preload("res://scripts/hud/character_info_overlay.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
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
	_expect(stats.size() >= 8, "TAB stats should keep the eight live combat stat rows")
	_expect(_find_stat(stats, "게이지").is_empty(), "TAB stats should omit current gauge summary")
	_expect(_find_stat(stats, "대시 토큰").is_empty(), "TAB stats should omit dash token summary")
	_expect(
		abs(_stat_float(stats, "이동 속도") - 10.08) < 0.02,
		"TAB move speed should include common swiftness and active-item speed buffs"
	)
	_expect(
		_is_buff_color(_stat_color(stats, "이동 속도")),
		"TAB move speed buffs should be highlighted as a buff color"
	)
	_expect(
		abs(_stat_seconds(stats, "아이템쿨타임") - 6.09) < 0.02,
		"TAB active-item cooldown should include runtime perk reductions"
	)
	_expect(
		_is_buff_color(_stat_color(stats, "아이템쿨타임")),
		"TAB active-item cooldown reductions should be highlighted as a buff color"
	)

	active_runtime.effect_controller.long_boost_active = true
	active_runtime.effect_controller.long_boost_scale = 1.5
	stats = overlay._build_stats(owner, registry)
	_expect(
		_stat_pixels(stats, "몸집크기") >= 246.0,
		"TAB body size should read live perk and active-item paddle scale, not only the cached owner width"
	)
	_expect(
		_is_buff_color(_stat_color(stats, "몸집크기")),
		"TAB body size increases should be highlighted as a buff color"
	)

	_expect(
		int(mythic_runtime.acquire_item("slot_add", owner, registry, {"slot_add_count": 2.0}, true, false)) >= 0,
		"slot_add passive should be acquired and equipped"
	)
	stats = overlay._build_stats(owner, registry)
	_expect(
		_find_stat(stats, "액티브 아이템").is_empty(),
		"TAB stats should leave active item slot counts to the dedicated active-item panel"
	)

	var debuff_active_runtime: Object = ActiveItemRuntime.new()
	_finish_active_runtime_initialization(debuff_active_runtime)
	var debuff_registry := FakeRegistry.new(RuntimePerkState.new(), debuff_active_runtime, CooldownPenaltyRuntime.new())
	var debuff_stats: Array = overlay._build_stats(owner, debuff_registry)
	_expect(
		_is_debuff_color(_stat_color(debuff_stats, "아이템쿨타임")),
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
		str(defense_stat.get("tooltip_body", "")).find("공을 적극적으로 막으러 이동할 확률") >= 0,
		"Maribo defense rate should explain the actual intercept behavior in a tooltip"
	)
	var maribo_panel_snapshot: Dictionary = overlay._get_lingpet_panel_snapshot(lingpet_owner)
	var maribo_skill_specs: Array = overlay._get_lingpet_skill_specs(maribo_panel_snapshot)
	_expect(maribo_skill_specs.size() == 2, "Maribo character-info panel should show one active skill and one real passive icon")
	_expect(str((maribo_skill_specs[0] as Dictionary).get("id", "")) == "maribo_hydro_sphere", "Maribo active icon should use the catalog skill id")
	_expect(str((maribo_skill_specs[0] as Dictionary).get("card_texture_path", "")).find("maribo_hydro_sphere") >= 0, "Maribo active icon should use the catalog skill-card texture")
	_expect(str((maribo_skill_specs[1] as Dictionary).get("id", "")) == "resonance_boost", "Maribo gauge bonus should remain as the one passive skill icon")

	var lunabi_owner := FakeOwner.new({
		"lingpet_id": "lunabi",
		"lingpet_state": "companion",
	})
	var lunabi_panel_snapshot: Dictionary = overlay._get_lingpet_panel_snapshot(lunabi_owner)
	var lunabi_skill_specs: Array = overlay._get_lingpet_skill_specs(lunabi_panel_snapshot)
	var lunabi_stats: Array = overlay._build_lingpet_stats(lunabi_owner)
	var lunabi_art_texture: Texture2D = overlay._get_lingpet_art_texture("lunabi")
	_expect(str(lunabi_panel_snapshot.get("pet_id", "")) == "lunabi", "Lunabi panel snapshot should preserve its catalog pet id")
	_expect(lunabi_skill_specs.is_empty(), "Lunabi placeholder active/passive data should not show Maribo skill icons")
	_expect(_find_stat(lunabi_stats, "액티브 쿨타임").is_empty(), "Lunabi should not show an active cooldown stat until its active skill ships")
	_expect(str(_find_stat(lunabi_stats, "이동 속도").get("value", "")) == "3.17", "Lunabi character-info speed should use its own catalog stat, not Maribo's")
	_expect(lunabi_art_texture != null and str(lunabi_art_texture.resource_path).ends_with("lunabi_cutin_art.png"), "Lunabi character-info art should resolve through the catalog cutin_art path")

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
