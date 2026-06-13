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
const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")
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


class FakeBondStore:
	extends RefCounted

	var bond_points: Dictionary = {}

	func _init(initial_points: Dictionary = {}) -> void:
		for raw_pet_id in initial_points.keys():
			set_bond_points(str(raw_pet_id), int(initial_points.get(raw_pet_id, 0)))

	func get_best_level(_pet_id: String) -> int:
		return 0

	func get_bond_points(pet_id: String) -> int:
		return int(bond_points.get(pet_id.strip_edges().to_lower(), 0))

	func set_bond_points(pet_id: String, points: int) -> void:
		var normalized_pet_id := pet_id.strip_edges().to_lower()
		if normalized_pet_id != "":
			bond_points[normalized_pet_id] = maxi(0, points)


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
	_expect(_find_stat(lunabi_stats, "방어율").is_empty(), "flight-style Lunabi should NOT show a 방어율 row (defense intercept is patrol-only)")
	_expect(str(_find_stat(lunabi_stats, "출현율").get("value", "")) == "30%", "flight-style Lunabi should show an 출현율 row from its catalog appearance_rate")
	_expect(CharacterInfoOverlayLingpetTextureLoader.uses_panel_live2d_art("lunabi"), "Lunabi character-info art should opt into the panel Live2D sheet")
	_expect(not CharacterInfoOverlayLingpetTextureLoader.uses_panel_live2d_art("maribo"), "Maribo character-info art should keep using the static cutin art for now")
	_expect(lunabi_art_texture != null and str(lunabi_art_texture.resource_path).ends_with("lunabi_click_live2d_pingpong_98f.png"), "Lunabi character-info art should resolve to the 98-frame panel Live2D sheet")
	_expect(lunabi_live2d_source_0.position == Vector2.ZERO and lunabi_live2d_source_0.size == Vector2(1024.0, 1024.0), "Lunabi character-info Live2D should start from the first 1024px sheet cell")
	_expect(is_equal_approx(lunabi_live2d_source_1.position.x, 1024.0), "Lunabi character-info Live2D should advance to the next sheet cell after one 16fps tick")
	_expect(CharacterInfoOverlayLingpetPresenter.should_redraw_panel_live2d(lunabi_panel_snapshot), "Lunabi character-info panel should request redraws while its panel Live2D is visible")
	_expect(not CharacterInfoOverlayLingpetPresenter.should_redraw_panel_live2d(maribo_panel_snapshot), "Maribo character-info panel should not request continuous Live2D redraws")
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
	_expect(nekuring_live2d_source_0.position == Vector2.ZERO and nekuring_live2d_source_0.size == Vector2(1152.0, 1152.0), "Nekuring character-info Live2D should start from the first 1152px HQ sheet cell")
	_expect(is_equal_approx(nekuring_live2d_source_1.position.x, 1152.0), "Nekuring character-info Live2D should advance to the next HQ sheet cell after one 16fps tick")
	_expect(CharacterInfoOverlayLingpetPresenter.should_redraw_panel_live2d(nekuring_panel_snapshot), "Nekuring character-info panel should request redraws while its panel Live2D is visible")

	_verify_defense_override_reaches_panel_through_schema_gated_owner()
	_verify_affinity_values_reach_panel_through_schema_gated_owner()
	_verify_affinity_stat_boosts_reach_panel_through_schema_gated_owner()
	_verify_snapshot_sync_keys_are_schema_declared()

	ProjectResourceLoader.clear_caches()
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


func _verify_affinity_values_reach_panel_through_schema_gated_owner() -> void:
	for key in [
		"lingpet_affinity_level",
		"ringpet_affinity_level",
		"lingpet_affinity_points",
		"ringpet_affinity_points",
		"lingpet_affinity_next_requirement",
		"ringpet_affinity_next_requirement",
		"lingpet_affinity_next_label",
		"ringpet_affinity_next_label",
		"lingpet_bond_points",
		"ringpet_bond_points",
		"lingpet_bond_title",
		"ringpet_bond_title",
	]:
		_expect(BattleSceneState.DEFAULT_VALUES.has(key), "BattleSceneState should declare %s for TAB affinity sync" % key)
	var fallback_owner := FakeOwner.new({
		"lingpet_id": "maribo",
		"lingpet_state": "companion",
	})
	var fallback_snapshot: Dictionary = CharacterInfoOverlayLingpetPresenter.build_panel_snapshot(fallback_owner, Callable(CharacterInfoOverlayValueUtils, "safe_owner_get"), CharacterInfoOverlay.LINGPET_HATCH_REQUIRED_HITS)
	_expect(str(fallback_snapshot.get("subtitle", "")) == "동행 중 · 친밀도 어색함", "TAB panel should fall back to the first permanent affinity title when no store data exists")
	_expect(str(fallback_snapshot.get("subtitle", "")).find("교감") < 0, "permanent title subtitle should not use the run-scoped 교감 label")

	var owner := SchemaGatedOwner.new()
	var registry := NullRegistry.new()
	var runtime: Object = LingpetEggRuntime.new()
	var bond_store := FakeBondStore.new({"maribo": 21})
	runtime.set_affinity_store_for_tests(bond_store)
	_expect(
		bool(runtime.debug_grant_and_activate_pet("maribo", owner, false, "maribo_hydro_sphere", "lingpet_resonance_boost", registry, 1, 1)),
		"schema-gated owner should accept a Maribo debug grant for affinity panel sync"
	)
	runtime.update(0.0, owner, registry)
	var before_snapshot: Dictionary = CharacterInfoOverlayLingpetPresenter.build_panel_snapshot(owner, Callable(CharacterInfoOverlayValueUtils, "safe_owner_get"), CharacterInfoOverlay.LINGPET_HATCH_REQUIRED_HITS)
	var before_hash := CharacterInfoOverlayLingpetPresenter.get_stats_cache_hash(before_snapshot, CharacterInfoOverlay.LINGPET_HATCH_REQUIRED_HITS)
	_expect(int(before_snapshot.get("bond_points", 0)) == 21, "TAB panel snapshot should read permanent bond points through the schema-gated owner")
	_expect(str(before_snapshot.get("bond_title", "")) == "영혼의 단짝", "TAB panel snapshot should resolve the permanent top title through the shared helper")
	_expect(str(before_snapshot.get("subtitle", "")) == "동행 중 · 친밀도 영혼의 단짝", "TAB art-panel subtitle should show the permanent 친밀도 title without adding a stat row")
	for _i in range(25):
		runtime.debug_add_affinity_points_for_tests("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT)
	runtime.update(0.0, owner, registry)
	var after_snapshot: Dictionary = CharacterInfoOverlayLingpetPresenter.build_panel_snapshot(owner, Callable(CharacterInfoOverlayValueUtils, "safe_owner_get"), CharacterInfoOverlay.LINGPET_HATCH_REQUIRED_HITS)
	var after_hash := CharacterInfoOverlayLingpetPresenter.get_stats_cache_hash(after_snapshot, CharacterInfoOverlay.LINGPET_HATCH_REQUIRED_HITS)
	_expect(int(after_snapshot.get("affinity_level", 0)) == 2, "TAB panel snapshot should read affinity Lv.2 through the schema-gated owner after a live level-up")
	_expect(is_equal_approx(float(after_snapshot.get("affinity_points", -1.0)), 0.0), "TAB panel snapshot should read post-level-up affinity points")
	_expect(is_equal_approx(float(after_snapshot.get("affinity_next_requirement", 0.0)), 100.0), "TAB panel snapshot should read the Lv.2 next requirement")
	_expect(str(after_snapshot.get("affinity_next_label", "")) != "", "TAB panel snapshot should read the next affinity reward label")
	_expect(after_hash != before_hash, "lingpet stat cache hash should change when affinity level changes")
	bond_store.set_bond_points("maribo", 6)
	runtime.update(0.0, owner, registry)
	var bond_changed_snapshot: Dictionary = CharacterInfoOverlayLingpetPresenter.build_panel_snapshot(owner, Callable(CharacterInfoOverlayValueUtils, "safe_owner_get"), CharacterInfoOverlay.LINGPET_HATCH_REQUIRED_HITS)
	var bond_changed_hash := CharacterInfoOverlayLingpetPresenter.get_stats_cache_hash(bond_changed_snapshot, CharacterInfoOverlay.LINGPET_HATCH_REQUIRED_HITS)
	_expect(str(bond_changed_snapshot.get("bond_title", "")) == "가까워짐", "TAB panel snapshot should update permanent title bands from store data")
	_expect(str(bond_changed_snapshot.get("subtitle", "")) == "동행 중 · 친밀도 가까워짐", "TAB subtitle should use 친밀도 only for the permanent bond axis")
	_expect(bond_changed_hash != after_hash, "lingpet stat cache hash should include bond fields so title changes cannot freeze")
	var overlay: Object = CharacterInfoOverlay.new()
	var rows: Array = overlay._build_lingpet_stats(owner)
	var affinity_row: Dictionary = _find_stat(rows, "교감")
	_expect(str(affinity_row.get("value", "")) == "Lv.2", "TAB lingpet stats should include a text-only 교감 Lv.N row")
	_expect(rows.size() >= 6, "TAB lingpet stats should keep six companion rows visible in the data model")
	var vertical_stack_rect := Rect2(Vector2.ZERO, Vector2(560.0, 360.0))
	var vertical_lingpet_rect := CharacterInfoOverlayStatsPresenter.lingpet_stat_rect_for_sections(vertical_stack_rect)
	var visible_capacity := CharacterInfoOverlayStatsPresenter.lingpet_stat_rows_visible_capacity(vertical_lingpet_rect, rows.size())
	_expect(visible_capacity >= 6, "vertical stacked TAB layout should have draw-time room for the sixth 교감 row")


func _verify_affinity_stat_boosts_reach_panel_through_schema_gated_owner() -> void:
	# 교감 reward stacks (기동/게이지 강화) boost the runtime stats through
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
	var commit_guard := 0
	while runtime.get_affinity_level("maribo") < LingpetAffinityState.MAX_LEVEL and commit_guard < 400:
		runtime.debug_add_affinity_points_for_tests("maribo", LingpetAffinityState.SOURCE_ROUND_COMMIT, {}, registry)
		commit_guard += 1
	_expect(runtime.get_affinity_level("maribo") == LingpetAffinityState.MAX_LEVEL, "stat-boost fixture should reach affinity max level via round commits")
	runtime.update(0.0, owner, registry)
	var base_gauge := float(LingpetCatalog.get_stat("maribo", "hit_gauge_gain", 40.0))
	var base_speed := float(LingpetCatalog.get_stat("maribo", "patrol_speed_default", 0.0))
	_expect(base_speed > 0.0, "Maribo should expose a catalog patrol speed for the divergence fixture")
	var snapshot: Dictionary = CharacterInfoOverlayLingpetPresenter.build_panel_snapshot(owner, Callable(CharacterInfoOverlayValueUtils, "safe_owner_get"), CharacterInfoOverlay.LINGPET_HATCH_REQUIRED_HITS)
	# Canonical Lv.15 track grants 3x 기동 강화 (+5% patrol speed each) and
	# 2x 게이지 강화 (+5 hit gauge each).
	_expect(
		is_equal_approx(float(snapshot.get("companion_hit_gauge_gain", 0.0)), base_gauge + 10.0),
		"게이지 강화 stacks should reach the panel gauge-gain row instead of the catalog base"
	)
	_expect(
		is_equal_approx(float(snapshot.get("companion_patrol_speed_default", 0.0)), base_speed * 1.15),
		"기동 강화 stacks should reach the panel move-speed row instead of the catalog base"
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
	ProjectResourceLoader.clear_caches()
	quit(1)
