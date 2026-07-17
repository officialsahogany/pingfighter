extends RefCounted

const MysticDiceRoller := preload("res://scripts/characters/mystic_dice_roller.gd")

const ENTRY_TYPE := "mystic_dice"
const PERK_ID := "mystic_dice"


# Canonical, read-only projection for the run-scoped Mystic Dice accumulation.
#
# The projection is deliberately separate from gameplay state. Consumers receive
# a synthetic slot-free perk entry only after the first committed use, and can
# safely cache it by cache_signature without reading the mutable state object.
func build(dice_snapshot: Dictionary) -> Dictionary:
	var revision := int(dice_snapshot.get("revision", 0))
	var use_count := maxi(0, int(dice_snapshot.get("use_count", 0)))
	var permanent_raw := _normalized_raw(dice_snapshot.get("permanent_raw", {}))
	var signature_values: Array[int] = []
	for stat_key: String in MysticDiceRoller.STAT_KEYS:
		signature_values.append(int(permanent_raw.get(stat_key, 0)))
	var signature := hash([
		revision,
		use_count,
		maxi(0, int(dice_snapshot.get("max_uses_per_run", 0))),
		maxi(0, int(dice_snapshot.get("remaining_uses", 0))),
		signature_values,
	])
	var entries: Array[Dictionary] = []
	if use_count > 0:
		entries.append({
			"type": ENTRY_TYPE,
			"id": PERK_ID,
			"perk_id": PERK_ID,
			"base_level": 1,
			"effective_level": 1,
			"slot_cost": 0,
			"use_count": use_count,
			"max_uses_per_run": maxi(0, int(dice_snapshot.get("max_uses_per_run", 0))),
			"remaining_uses": maxi(0, int(dice_snapshot.get("remaining_uses", 0))),
			"mystic_dice_revision": revision,
			"permanent_raw": permanent_raw.duplicate(true),
		})
	return {
		"entries": entries.duplicate(true),
		"mystic_dice_revision": revision,
		"cache_signature": signature,
	}


# Append the synthetic entry to the established runtime-perk display projection.
# Keeping the composite under the existing projection channel lets every current
# HUD/TAB consumer see Dice without learning a second merge policy.
func merge(base_projection: Dictionary, dice_snapshot: Dictionary) -> Dictionary:
	var dice_projection := build(dice_snapshot)
	var dice_entries: Array = dice_projection.get("entries", []) as Array
	if dice_entries.is_empty():
		return base_projection.duplicate(true)
	var merged := base_projection.duplicate(true)
	var entries: Array = []
	var base_entries_value: Variant = merged.get("entries", [])
	if base_entries_value is Array:
		for entry_value: Variant in base_entries_value as Array:
			if entry_value is Dictionary and str((entry_value as Dictionary).get("type", "")) == ENTRY_TYPE:
				continue
			entries.append((entry_value as Dictionary).duplicate(true) if entry_value is Dictionary else entry_value)
	entries.append_array(dice_entries.duplicate(true))
	merged["entries"] = entries
	merged["mystic_dice_revision"] = int(dice_projection.get("mystic_dice_revision", 0))
	merged["cache_signature"] = hash([
		int(base_projection.get("cache_signature", 0)),
		int(dice_projection.get("cache_signature", 0)),
	])
	return merged


func _normalized_raw(raw_value: Variant) -> Dictionary:
	var raw: Dictionary = raw_value as Dictionary if raw_value is Dictionary else {}
	var normalized: Dictionary = {}
	for stat_key: String in MysticDiceRoller.STAT_KEYS:
		normalized[stat_key] = clampi(int(raw.get(stat_key, 0)), -9, 9)
	return normalized
