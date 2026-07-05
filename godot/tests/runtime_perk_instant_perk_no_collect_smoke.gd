extends SceneTree

# Seals that instant one-shot perks (common_refresh / star_change) do their
# real work but never enter runtime_skill_levels — the "collected perks" source
# for the character-info perk grid. Regression reference: 새로고침 (common_refresh)
# leaked into the character-info perk list because its handler wrote a tracking
# count into runtime_skill_levels, unlike every other instant perk.

const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const CharacterInfoOverlayPerkPresenter := preload("res://scripts/hud/character_info_overlay_perk_presenter.gd")


func _init() -> void:
	_verify_common_refresh_does_not_collect()
	_verify_star_change_does_not_collect()
	_verify_grid_excludes_instant_but_keeps_real_perk()

	print("runtime_perk_instant_perk_no_collect_smoke: ok")
	quit(0)


func _verify_common_refresh_does_not_collect() -> void:
	var perk_state: Object = RuntimePerkState.new()
	var before_choices: int = int(perk_state.pending_skill_choices)
	var ok: bool = perk_state.apply_choice({"id": "common_refresh"}, null, null)
	_expect(ok, "common_refresh should apply")
	_expect(
		int(perk_state.pending_skill_choices) == before_choices + 1,
		"common_refresh must re-open exactly one perk choice"
	)
	_expect(
		not perk_state.runtime_skill_levels.has("common_refresh"),
		"common_refresh must NOT enter runtime_skill_levels (collected-perk source)"
	)


func _verify_star_change_does_not_collect() -> void:
	var perk_state: Object = RuntimePerkState.new()
	var before_choices: int = int(perk_state.pending_skill_choices)
	var ok: bool = perk_state.apply_choice({"id": "star_change"}, null, null)
	_expect(ok, "star_change should apply")
	_expect(
		int(perk_state.pending_skill_choices) == before_choices + 3,
		"star_change (+3 starpoints, 1 per choice) must re-open three perk choices"
	)
	_expect(
		not perk_state.runtime_skill_levels.has("star_change"),
		"star_change must NOT enter runtime_skill_levels (collected-perk source)"
	)


func _verify_grid_excludes_instant_but_keeps_real_perk() -> void:
	var perk_state: Object = RuntimePerkState.new()
	# A genuinely collected, level-scaling perk that SHOULD appear in the grid.
	perk_state.runtime_skill_levels["dash_acceleration"] = 2
	perk_state.apply_choice({"id": "common_refresh"}, null, null)

	var catalog: Object = RuntimePerkCatalog.new()
	var acquired: Array = CharacterInfoOverlayPerkPresenter.build_acquired_perks(
		perk_state.runtime_skill_levels, catalog
	)
	_expect(
		_has_perk_id(acquired, "dash_acceleration"),
		"genuinely collected perk should still render in the character-info grid"
	)
	_expect(
		not _has_perk_id(acquired, "common_refresh"),
		"instant common_refresh must NOT render in the character-info perk grid"
	)


func _has_perk_id(acquired: Array, perk_id: String) -> bool:
	for perk in acquired:
		if str((perk as Dictionary).get("id", "")) == perk_id:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
