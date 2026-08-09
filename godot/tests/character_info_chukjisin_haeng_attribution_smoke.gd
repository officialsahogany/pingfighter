extends SceneTree

const CharacterInfoOverlayOwnerState := preload("res://scripts/hud/character_info_overlay_owner_state.gd")
const CharacterInfoOverlayStatsPresenter := preload("res://scripts/hud/character_info_overlay_stats_presenter.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")


func _init() -> void:
	var conversion_was_enabled := PerkConversionFlags.is_enabled()
	PerkConversionFlags.debug_set_enabled(true)

	var perk_state := RuntimePerkState.new()
	perk_state.runtime_skill_levels["hermes_shoes"] = 1
	var mythic_runtime := MythicItemRuntime.new()
	mythic_runtime.runtime_perk_state_ref = perk_state

	var entries: Array = CharacterInfoOverlayStatsPresenter.move_speed_breakdown(
		"smasher",
		null,
		perk_state,
		null,
		null,
		mythic_runtime,
		null,
		null,
		null,
		Callable(CharacterInfoOverlayOwnerState, "call_numeric_multiplier")
	)
	var rows: Array = CharacterInfoOverlayStatsPresenter.breakdown_rows_from_entries(entries)
	PerkConversionFlags.debug_set_enabled(conversion_was_enabled)

	var chukjisin_entry := _find_entry(entries, "축지신행")
	_expect(absf(float(chukjisin_entry.get("ratio", 0.0)) - 1.5) < 0.005, "축지신행 기여 배율은 +50%여야 합니다")
	var chukjisin_row := _find_row(rows, "축지신행: +50%")
	_expect(not chukjisin_row.is_empty(), "이동 속도 내역에 '축지신행: +50%'가 표시되어야 합니다")
	_expect(str(chukjisin_row.get("icon_id", "")) == "hermes_shoes", "축지신행 내역은 호환 아이콘 ID를 유지해야 합니다")
	_expect(_find_row(rows, "신화 아이템: +50%").is_empty(), "축지신행 +50%를 신화 아이템으로 오표기하면 안 됩니다")

	print("character_info_chukjisin_haeng_attribution_smoke: ok")
	quit()


func _find_entry(entries: Array, label: String) -> Dictionary:
	for value in entries:
		if value is Dictionary and str((value as Dictionary).get("label", "")) == label:
			return value
	return {}


func _find_row(rows: Array, text_value: String) -> Dictionary:
	for value in rows:
		if value is Dictionary and str((value as Dictionary).get("text", "")) == text_value:
			return value
	return {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
