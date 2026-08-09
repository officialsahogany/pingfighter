extends SceneTree

const CharacterInfoOverlayOwnerState := preload("res://scripts/hud/character_info_overlay_owner_state.gd")
const CharacterInfoOverlayStatsPresenter := preload("res://scripts/hud/character_info_overlay_stats_presenter.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkOverflowDescriptions := preload("res://scripts/characters/runtime_perk_overflow_descriptions.gd")
const StatusEffectState := preload("res://scripts/status/status_effect_state.gd")
const WeatherEventState := preload("res://scripts/stages/common/weather_event_state.gd")


class FusionSpeedStub extends RefCounted:
	func get_runtime_skill_bonus(_perk_id: String) -> float:
		return 0.0

	func get_perk_fusion_move_speed_multiplier() -> float:
		return 1.25


func _init() -> void:
	var conversion_was_enabled := PerkConversionFlags.is_enabled()
	PerkConversionFlags.debug_set_enabled(true)
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)

	_test_converted_mythic_owner_labels()
	_test_gauge_and_fusion_labels()
	_test_weather_status_and_guardian_labels()

	PerkConversionFlags.debug_set_enabled(conversion_was_enabled)
	LanguageSettings.set_test_locale_override("")
	print("character_info_stat_source_attribution_smoke: ok")
	quit()


func _test_converted_mythic_owner_labels() -> void:
	var perk_state := RuntimePerkState.new()
	perk_state.runtime_skill_levels["hermes_shoes"] = 1
	perk_state.runtime_skill_levels["master"] = 1
	perk_state.runtime_skill_levels["fuel_pouch"] = 1
	var runtime := MythicItemRuntime.new()
	runtime.runtime_perk_state_ref = perk_state

	var speed_entries: Array = runtime.get_player_stat_breakdown("player_speed")
	_expect_ratio(speed_entries, "축지신행", 1.5, "Hermes conversion")
	_expect(_find_entry(speed_entries, "신화 아이템").is_empty(), "converted speed source must not use the mythic category label")

	var cooldown_entries: Array = CharacterInfoOverlayStatsPresenter.stat_chain_breakdown(
		1000.0,
		[runtime],
		"get_active_item_cooldown_msec",
		null,
		runtime,
		null,
		null
	)
	_expect_ratio(cooldown_entries, "축성공", 0.97, "Master conversion")

	var gauge_entries: Array = CharacterInfoOverlayStatsPresenter.max_gauge_breakdown(perk_state, runtime, 500.0)
	var fuel_entry := _find_entry(gauge_entries, "태허심법")
	_expect(float(fuel_entry.get("before", 0.0)) == 500.0, "태허심법 should start at the real base vigor maximum")
	_expect(float(fuel_entry.get("after", 0.0)) == 540.0, "태허심법 Lv.1 should expose its +40 vigor step")

	# These transformed/round states are runtime-owned even after conversion.
	# Set the real helper states and verify their current martial-art names.
	runtime.get_player_speed_multiplier()
	runtime.odins_eye_state.active = true
	runtime.odins_eye_state.penalty_active = true
	var odin_speed_entries: Array = runtime.get_player_stat_breakdown("player_speed")
	_expect_ratio(odin_speed_entries, "윤회천안", 0.5, "Odin transformation speed")
	var odin_dash_entries: Array = runtime.get_player_stat_breakdown("dash_recharge", 120.0)
	_expect_ratio(odin_dash_entries, "윤회천안", 2.0, "Odin transformation recharge")

	runtime.baal_boots_weather_state.round_effect_active = true
	runtime.baal_boots_weather_state.round_weather_type = "breeze"
	var baal_entries: Array = runtime.get_player_stat_breakdown("player_speed")
	_expect_ratio(baal_entries, "풍우식기결", 1.5, "Baal wind round")

	runtime.horn_strawberry_mask_state.active = true
	runtime.horn_strawberry_mask_state.state = "transformed"
	runtime.horn_strawberry_mask_state.paddle_size_bonus_pct = 0.2
	var horn_entries: Array = runtime.get_player_stat_breakdown("paddle_size")
	_expect_ratio(horn_entries, "혼딸기강신", 1.2, "Horn Strawberry transformation")


func _test_gauge_and_fusion_labels() -> void:
	var gauge_steps: Array = [
		{"source": "bluetooth_ring", "before": 50.0, "after": 60.0},
		{"source": "gold_digger", "before": 60.0, "after": 66.0},
		{"source": "horn_strawberry", "before": 66.0, "after": 80.0},
	]
	var gauge_entries: Array = CharacterInfoOverlayStatsPresenter.gauge_breakdown_from_steps(gauge_steps, null, null)
	_expect(not _find_entry(gauge_entries, "격기심법").is_empty(), "Bluetooth compatibility source should display as 격기심법")
	_expect(not _find_entry(gauge_entries, "취금결").is_empty(), "Gold Digger compatibility source should display as 취금결")
	_expect(not _find_entry(gauge_entries, "혼딸기강신").is_empty(), "Horn Strawberry compatibility source should display as 혼딸기강신")
	var gold_perk_data: Dictionary = RuntimePerkCatalog.new().get_perk_data("gold_digger")
	_expect(str((gold_perk_data.get("descriptions", {}) as Dictionary).get(1, "")) == "골드·일부 기력 획득 +15%", "취금결 card text should disclose its vigor contribution")
	_expect(RuntimePerkOverflowDescriptions.generate_stats_text("gold_digger", 6) == "골드·일부 기력 획득 +65%", "취금결 Lv.6+ text should stay synchronized")

	var fusion_entries: Array = CharacterInfoOverlayStatsPresenter.move_speed_breakdown(
		"viper",
		null,
		FusionSpeedStub.new(),
		null,
		null,
		null,
		null,
		null,
		null,
		Callable(CharacterInfoOverlayOwnerState, "call_numeric_multiplier")
	)
	_expect_ratio(fusion_entries, "잔향", 1.25, "fusion Reverb")
	_expect(_find_entry(fusion_entries, "무공 합일").is_empty(), "Reverb must not be mislabeled as 무공 합일")


func _test_weather_status_and_guardian_labels() -> void:
	var weather := WeatherEventState.new()
	weather.weather_event_active = true
	weather.weather_event_type = "rain"
	_expect_ratio(weather.get_player_stat_breakdown("player_speed"), "비", 0.7, "rain weather")

	var status := StatusEffectState.new()
	status.apply_status("player", "slow", 60.0, {
		"multiplier": 0.65,
		"label": "환루천우",
	}, "stage3_tear_shower")
	_expect_ratio(status.get_player_stat_breakdown("player_speed"), "환루천우", 0.65, "named player slow")
	var magnetic_status := StatusEffectState.new()
	magnetic_status.apply_status("player", "slow", 60.0, {
		"multiplier": 0.75,
	}, "stage4_magnetic_projectile")
	_expect_ratio(magnetic_status.get_player_stat_breakdown("player_speed"), "굴절 자기장", 0.75, "mapped player slow")

	var tailwind_runtime := LingpetEggRuntime.new()
	_expect(tailwind_runtime.debug_grant_and_activate_pet("maribo", null, false, "", "lingpet_tailwind_steps", null, 1, 3), "tailwind guardian test loadout should activate")
	_expect_ratio(tailwind_runtime.get_player_stat_breakdown("player_speed"), "순풍 발산", 1.1, "guardian tailwind")

	var resonance_runtime := LingpetEggRuntime.new()
	_expect(resonance_runtime.debug_grant_and_activate_pet("maribo", null, false, "", "lingpet_resonance_boost", null, 1, 3), "resonance guardian test loadout should activate")
	var resonance_entries: Array = resonance_runtime.get_player_stat_breakdown("gauge_gain", 50.0)
	_expect_ratio(resonance_entries, "공명 증폭", 1.1, "guardian resonance")


func _find_entry(entries: Array, label: String) -> Dictionary:
	for value in entries:
		if value is Dictionary and str((value as Dictionary).get("label", "")) == label:
			return value
	return {}


func _expect_ratio(entries: Array, label: String, expected: float, context: String) -> void:
	var entry := _find_entry(entries, label)
	_expect(not entry.is_empty(), "%s should expose source '%s'" % [context, label])
	_expect(absf(float(entry.get("ratio", 0.0)) - expected) < 0.005, "%s should expose ratio %.3f" % [context, expected])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
