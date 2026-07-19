extends SceneTree

# Seals the current-perks panel rendering the dash-token perk as one slot cell PER level
# (its per-level slot cost), instead of a single leveled icon. Mirrors the design
# decision that dash-token Lv.N occupies N of the perk-slot budget, so the list must
# read the same as the dynamic slot counter above it. Data-layer seal on
# runtime_perk_overlay_renderer._build_acquired_perks (the draw loop then suppresses the
# level badge for is_slot_cell entries).

const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var renderer := RuntimePerkOverlayRenderer.new()
	var catalog := RuntimePerkCatalog.new()

	# Dash token Lv3 -> three flagged slot cells; a normal multi-level perk stays one entry.
	var acquired: Array = renderer._build_acquired_perks(
		{"dash_amplification": 3, "dash_lightweight": 2}, catalog, null
	)
	var dash_cells := 0
	var dash_flagged := 0
	var lightweight_entries := 0
	var lightweight_flagged := 0
	for entry_value in acquired:
		var entry: Dictionary = entry_value
		match str(entry.get("id", "")):
			"dash_amplification":
				dash_cells += 1
				if bool(entry.get("is_slot_cell", false)):
					dash_flagged += 1
			"dash_lightweight":
				lightweight_entries += 1
				if bool(entry.get("is_slot_cell", false)):
					lightweight_flagged += 1
	_expect(dash_cells == 3, "dash token Lv3 should expand into three slot cells (got %d)" % dash_cells)
	_expect(dash_flagged == 3, "every dash-token slot cell should be flagged is_slot_cell so the badge is suppressed (got %d)" % dash_flagged)
	_expect(lightweight_entries == 1, "a normal multi-level perk should stay one leveled entry (got %d)" % lightweight_entries)
	_expect(lightweight_flagged == 0, "a normal perk must not be flagged as a slot cell")

	# Lv2 -> two cells (confirms cost == level, not a hardcoded count).
	var acquired_lv2: Array = renderer._build_acquired_perks({"dash_amplification": 2}, catalog, null)
	var lv2_cells := 0
	for entry_value in acquired_lv2:
		if str((entry_value as Dictionary).get("id", "")) == "dash_amplification":
			lv2_cells += 1
	_expect(lv2_cells == 2, "dash token Lv2 should expand into exactly two slot cells (got %d)" % lv2_cells)

	# Lv1 -> single cell, NOT flagged (one slot = normal leveled badge, indistinguishable
	# from an ordinary 1-slot perk, which is correct).
	var acquired_lv1: Array = renderer._build_acquired_perks({"dash_amplification": 1}, catalog, null)
	var lv1_cells := 0
	var lv1_flagged := 0
	for entry_value in acquired_lv1:
		var entry: Dictionary = entry_value
		if str(entry.get("id", "")) == "dash_amplification":
			lv1_cells += 1
			if bool(entry.get("is_slot_cell", false)):
				lv1_flagged += 1
	_expect(lv1_cells == 1, "dash token Lv1 (one slot) should stay a single cell (got %d)" % lv1_cells)
	_expect(lv1_flagged == 0, "dash token Lv1 single cell should keep the normal level badge, not slot-cell mode")

	# Contiguity: dash cells must stay adjacent even when another perk shares the same level
	# (Lv3 here). Godot sort_custom is unstable, so this seals the id tie-break.
	var mixed: Array = renderer._build_acquired_perks(
		{"dash_amplification": 3, "dash_lightweight": 3}, catalog, null
	)
	var first_dash := -1
	var last_dash := -1
	for i in range(mixed.size()):
		if str((mixed[i] as Dictionary).get("id", "")) == "dash_amplification":
			if first_dash < 0:
				first_dash = i
			last_dash = i
	_expect(first_dash >= 0 and (last_dash - first_dash) == 2, "dash-token slot cells must stay contiguous (indices %d..%d) even next to a same-level perk" % [first_dash, last_dash])

	if _failures.is_empty():
		print("perk_overlay_dash_token_slot_cells_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
