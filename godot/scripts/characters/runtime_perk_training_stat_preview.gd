extends RefCounted

const CharacterInfoOverlayState := preload("res://scripts/hud/character_info_overlay_state.gd")
const CharacterInfoOverlayStatsPresenter := preload("res://scripts/hud/character_info_overlay_stats_presenter.gd")
const MythicItemOwnerSyncer := preload("res://scripts/items/mythic_item_owner_syncer.gd")
const MythicItemRuntimeConstants := preload("res://scripts/items/mythic_item_runtime_constants.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

# UI routing only: the numeric value for every row is still assembled by the
# production stat presenter. `common_training` has a real gameplay consumer but
# no row in the shipped ten-row ledger; storage has a row but no continuous bar.
const SOURCE_PERK_ROW_INDEX := {
	"common_swiftness": 0,
	"common_bulk_up": 1,
	"bluetooth_ring": 2,
	"fuel_pouch": 3,
	"dash_jump": 4,
	"dash_module_control": 5,
	"dash_lightweight": 6,
	"item_cooldown_mastery": 7,
	"bulletproof_hat": 8,
}

var build_count := 0
var _fallback_character_runtime: Object = PlayerCharacterRuntime.new()
var _mythic_owner_syncer: Object = MythicItemOwnerSyncer.new()


func is_source_previewable(source_perk_id: String) -> bool:
	return SOURCE_PERK_ROW_INDEX.has(source_perk_id.strip_edges())


func get_source_row_index(source_perk_id: String) -> int:
	return int(SOURCE_PERK_ROW_INDEX.get(source_perk_id.strip_edges(), -1))


func build_preview(
	runtime_state: Object,
	choice: Dictionary,
	owner: Object,
	registry: Object,
	character_runtime: Object = null
) -> Dictionary:
	build_count += 1
	if (
		runtime_state == null
		or owner == null
		or registry == null
		or not bool(choice.get("is_physique_training", false))
		or not runtime_state.has_method("project_next_physique_training_choice")
	):
		return {"visible": false, "reason": "invalid_context"}
	var source_perk_id := str(choice.get("source_perk_id", "")).strip_edges()
	var row_index := get_source_row_index(source_perk_id)
	if row_index < 0:
		return {
			"visible": false,
			"reason": "no_continuous_stat_row",
			"source_perk_id": source_perk_id,
		}
	var resolved_character_runtime: Object = (
		character_runtime if character_runtime != null else _fallback_character_runtime
	)
	var current_rows: Array = _build_rows(
		runtime_state,
		owner,
		registry,
		resolved_character_runtime,
		-1.0
	)
	if row_index >= current_rows.size():
		return {"visible": false, "reason": "missing_current_row"}
	var stat_key := str(choice.get("training_stat_key", "")).strip_edges()
	var projector := Callable(self, "_build_projected_rows").bind(
		runtime_state,
		owner,
		registry,
		resolved_character_runtime,
		stat_key
	)
	var projection_result: Dictionary = runtime_state.project_next_physique_training_choice(
		choice,
		registry,
		projector
	)
	if not bool(projection_result.get("accepted", false)):
		return {
			"visible": false,
			"reason": str(projection_result.get("reason", "projection_rejected")),
			"source_perk_id": source_perk_id,
			"row_index": row_index,
		}
	var projected_rows_value: Variant = projection_result.get("projection", [])
	if not (projected_rows_value is Array) or row_index >= (projected_rows_value as Array).size():
		return {"visible": false, "reason": "missing_projected_row"}
	var current_row_value: Variant = current_rows[row_index]
	var projected_row_value: Variant = (projected_rows_value as Array)[row_index]
	if not (current_row_value is Dictionary) or not (projected_row_value is Dictionary):
		return {"visible": false, "reason": "invalid_stat_row"}
	var current_row := current_row_value as Dictionary
	var projected_row := projected_row_value as Dictionary
	var current_fill := CharacterInfoOverlayStatsPresenter.player_stat_row_fill_ratio(current_row)
	var projected_fill := CharacterInfoOverlayStatsPresenter.player_stat_row_fill_ratio(projected_row)
	if current_fill < 0.0 or projected_fill <= current_fill + 0.00001:
		return {
			"visible": false,
			"reason": "no_visible_increase",
			"source_perk_id": source_perk_id,
			"row_index": row_index,
			"current_fill_ratio": current_fill,
			"projected_fill_ratio": projected_fill,
			"current_value": str(current_row.get("value", "")),
			"projected_value": str(projected_row.get("value", "")),
		}
	return {
		"visible": true,
		"reason": "projected",
		"training_id": str(choice.get("id", "")),
		"source_perk_id": source_perk_id,
		"stat_key": str(projection_result.get("stat_key", stat_key)),
		"row_index": row_index,
		"current_fill_ratio": current_fill,
		"projected_fill_ratio": projected_fill,
		"current_value": str(current_row.get("value", "")),
		"projected_value": str(projected_row.get("value", "")),
	}


func _build_projected_rows(
	runtime_state: Object,
	owner: Object,
	registry: Object,
	character_runtime: Object,
	stat_key: String
) -> Array:
	var projected_owner_gauge_max := -1.0
	if stat_key == "max_gauge_flat":
		var mythic_item_runtime: Object = _get_registry_instance(registry, "mythic_item_runtime")
		if mythic_item_runtime == null:
			return []
		var gauge_projection: Dictionary = _mythic_owner_syncer.build_fuel_pouch_gauge_projection(
			mythic_item_runtime,
			MythicItemRuntimeConstants.CONTEXT_CONSTANTS,
			0.0,
			runtime_state
		)
		projected_owner_gauge_max = float(gauge_projection.get("next_max", -1.0))
	return _build_rows(
		runtime_state,
		owner,
		registry,
		character_runtime,
		projected_owner_gauge_max
	)


func _build_rows(
	runtime_state: Object,
	owner: Object,
	registry: Object,
	character_runtime: Object,
	owner_special_gauge_max_override: float
) -> Array:
	return CharacterInfoOverlayStatsPresenter.build_player_stat_rows(
		owner,
		registry,
		character_runtime,
		runtime_state,
		null,
		null,
		"",
		[],
		-1,
		null,
		CharacterInfoOverlayState.SPECIAL_GAUGE_MAX,
		CharacterInfoOverlayState.PLAYER_BASE_PADDLE_WIDTH,
		CharacterInfoOverlayState.BASE_ACTIVE_ITEM_SLOT_COUNT,
		CharacterInfoOverlayState.STAT_BUFF_COLOR,
		CharacterInfoOverlayState.STAT_DEBUFF_COLOR,
		false,
		owner_special_gauge_max_override
	)


func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
