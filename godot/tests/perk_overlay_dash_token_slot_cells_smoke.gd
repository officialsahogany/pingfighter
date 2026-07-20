extends SceneTree

# Seals the current-perks panel rendering the dash-token perk as one slot cell PER level
# (its per-level slot cost), instead of a single leveled icon. Mirrors the design
# decision that dash-token Lv.N occupies N of the perk-slot budget, so the list must
# read the same as the dynamic slot counter above it. Data-layer seal on
# runtime_perk_overlay_renderer._build_acquired_perks (the draw loop then suppresses the
# level badge for is_slot_cell entries).

const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const CharacterInfoOverlayPerkPresenter := preload("res://scripts/hud/character_info_overlay_perk_presenter.gd")

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

	_run_projection_snapshot_legs(renderer, catalog)

	if _failures.is_empty():
		print("perk_overlay_dash_token_slot_cells_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


# Live regression leg (2026-07-21): a real runtime_perk_state snapshot ALWAYS carries a
# non-empty perk_fusion_display_projection once any perk is owned, so both the TAB grid
# and the in-battle status panel take the presenter's PROJECTION branch — the legacy
# no-snapshot legs above never exercise it. The original bug: that branch appended one
# leveled entry per perk (dash token Lv.2 rendered as a single "Lv.2" badge cell while
# the slot counter correctly charged 2), so cells and the counter disagreed on screen.
func _run_projection_snapshot_legs(renderer: RuntimePerkOverlayRenderer, catalog: RuntimePerkCatalog) -> void:
	var state := RuntimePerkState.new()
	state.runtime_skill_levels["dash_amplification"] = 2
	state.runtime_skill_levels["dash_lightweight"] = 1
	var snapshot: Dictionary = state.get_snapshot()
	var projection: Dictionary = snapshot.get("perk_fusion_display_projection", {}) as Dictionary
	var projection_entries: Array = projection.get("entries", []) as Array
	# Fail-closed guard: if the snapshot ever stops carrying projection entries, the
	# legs below silently fall back to the ordinary branch and seal nothing.
	_expect(not projection_entries.is_empty(), "real state snapshot must carry non-empty projection entries (leg would be void)")
	var has_dash_projection := false
	for entry_value in projection_entries:
		if entry_value is Dictionary and str((entry_value as Dictionary).get("id", "")) == "dash_amplification":
			has_dash_projection = true
	_expect(has_dash_projection, "projection entries must include the dash token perk (leg would be void)")

	# Leg A — presenter (TAB grid path) through the projection branch.
	var presented: Array = CharacterInfoOverlayPerkPresenter.build_acquired_perks(
		state.runtime_skill_levels, catalog, state, snapshot
	)
	var dash_cells := 0
	var dash_flagged := 0
	var dash_badgeless := 0
	var slot_cell_total := 0
	for entry_value in presented:
		var entry: Dictionary = entry_value
		if bool(entry.get("_slot_free_cell", false)):
			continue
		slot_cell_total += 1
		if str(entry.get("id", "")) == "dash_amplification":
			dash_cells += 1
			if bool(entry.get("_is_slot_cell", false)):
				dash_flagged += 1
			if str(entry.get("_level_text", "")) == "":
				dash_badgeless += 1
	_expect(dash_cells == 2, "projection branch: dash token Lv2 must expand into two slot cells (got %d)" % dash_cells)
	_expect(dash_flagged == 2, "projection branch: both dash cells must be flagged _is_slot_cell (got %d)" % dash_flagged)
	_expect(dash_badgeless == 2, "projection branch: dash slot cells must suppress the level badge (got %d badge-less)" % dash_badgeless)
	# Grid-vs-counter contract: the number of slot-consuming cells must equal the
	# slot counter shown above the grid (this was the user-visible mismatch).
	var counter_count := int((catalog.get_perk_slot_status(state.runtime_skill_levels, state) as Dictionary).get("count", -1))
	_expect(slot_cell_total == counter_count, "projection branch: grid slot cells (%d) must match the slot counter (%d)" % [slot_cell_total, counter_count])

	# Leg B — overlay status panel fold path must mirror the flat is_slot_cell keys.
	var folded: Array = renderer._build_acquired_perks_for_snapshot(
		state.runtime_skill_levels, catalog, state, snapshot
	)
	var folded_dash_cells := 0
	var folded_flat_flagged := 0
	for entry_value in folded:
		var entry: Dictionary = entry_value
		if str(entry.get("id", "")) == "dash_amplification":
			folded_dash_cells += 1
			if bool(entry.get("is_slot_cell", false)):
				folded_flat_flagged += 1
	_expect(folded_dash_cells == 2, "overlay fold path: dash token Lv2 must expand into two slot cells (got %d)" % folded_dash_cells)
	_expect(folded_flat_flagged == 2, "overlay fold path: both dash cells must mirror the flat is_slot_cell key (got %d)" % folded_flat_flagged)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
