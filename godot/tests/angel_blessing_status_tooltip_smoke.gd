extends SceneTree

const CharacterInfoOverlayPerkPresenter := preload("res://scripts/hud/character_info_overlay_perk_presenter.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const RuntimePerkAngelBlessingAcquisitionLifecycle := preload("res://scripts/characters/runtime_perk_angel_blessing_acquisition_lifecycle.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

const PERK_ID := "angel_blessing"

var _failures: Array[String] = []


class FakeCatalog:
	extends RefCounted

	func get_perk_data(perk_id: String) -> Dictionary:
		if perk_id != PERK_ID:
			return {}
		return {
			"id": PERK_ID,
			"name": "Angel's Dice",
			"detail": "",
			"descriptions": {1: "stale static description"},
			"max_level": 1,
			"rarity": "mythic",
			"icon_color": Color(1.0, 0.82, 0.32),
		}


func _init() -> void:
	_run()


func _run() -> void:
	# 비저장 locale override 표준: 저장형 set_language()는 실제 사용자
	# language_settings.cfg를 오염시키므로 스모크에서 금지. 성공·실패 공통
	# 종료에서 ""로 해제해 엔진 locale까지 복원한다.
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_ENGLISH)
	_verify_unrolled_and_next_intro_status()
	var rolled_state: Object = _verify_face_three_and_all_six_buff_signs()
	_verify_character_info_presenter_reflects_runtime_status(rolled_state)
	_verify_angel_revision_invalidates_presenter_cache(rolled_state)
	LanguageSettings.set_test_locale_override("")

	if _failures.is_empty():
		print("angel_blessing_status_tooltip_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_unrolled_and_next_intro_status() -> void:
	var state := _owned_state()
	_expect_array(
		state.get_runtime_status_lines(PERK_ID),
		["Activates after the next stage begins"],
		"an owned but not-yet-rolled Angel Dice should explain its next stage trigger"
	)
	_expect(state.get_runtime_status_lines("not_angel_blessing").is_empty(), "runtime status query should ignore unrelated perks")

	var lifecycle := RuntimePerkAngelBlessingAcquisitionLifecycle.new()
	var reservation: Dictionary = lifecycle.on_accepted_choice(
		state,
		{"id": PERK_ID, "source": "result_box_mythic_direct"},
		0,
		1,
		{},
		false,
		null,
		null
	)
	_expect(bool(reservation.get("accepted", false)), "result-route fixture should reserve the Angel roll")
	_expect(str(reservation.get("route", "")) == "next_valid_intro", "result-route fixture should use next-valid-intro policy")
	_expect_array(
		state.get_runtime_status_lines(PERK_ID),
		["Dice queued for the next stage"],
		"queued next-valid-intro acquisition should replace the generic unrolled hint"
	)


func _verify_face_three_and_all_six_buff_signs() -> Object:
	var state := _owned_state()
	var positives := ["paddle_size", "gauge_max", "move_speed"]
	var positive_roll: Dictionary = state.roll_angel_blessing_for_stage(1, positives, 3, positives)
	_expect(bool(positive_roll.get("rolled", false)), "forced face-3 positive roll should succeed")
	_expect(int(positive_roll.get("roll_face", 0)) == 3, "forced Angel roll should preserve face 3")
	_expect_array(
		state.get_runtime_status_lines(PERK_ID),
		[
			"Current blessings (3)",
			"Paddle size +30%",
			"Maximum gauge +30%",
			"Move speed +30%",
		],
		"positive Angel blessings should expose a +30% runtime status"
	)

	var reductions := ["item_cooldown", "active_cooldown", "dash_cooldown"]
	var reduction_roll: Dictionary = state.roll_angel_blessing_for_stage(2, reductions, 3, reductions)
	_expect(bool(reduction_roll.get("rolled", false)), "forced face-3 reduction roll should succeed on the next stage")
	_expect(int(reduction_roll.get("roll_face", 0)) == 3, "second forced Angel roll should preserve face 3")
	_expect_array(
		state.get_runtime_status_lines(PERK_ID),
		[
			"Current blessings (3)",
			"Item cooldown -30%",
			"Skill cooldown -30%",
			"Dash cooldown -30%",
		],
		"cooldown Angel blessings should expose a -30% runtime status"
	)
	return state


func _verify_character_info_presenter_reflects_runtime_status(state: Object) -> void:
	var catalog := FakeCatalog.new()
	var status_lines: Array[String] = state.get_runtime_status_lines(PERK_ID)
	var acquired: Array = CharacterInfoOverlayPerkPresenter.build_acquired_perks(
		{PERK_ID: 1},
		catalog,
		state,
		null,
		{PERK_ID: 1},
		[],
		Color(0.42, 0.72, 1.0),
		Color(1.0, 0.82, 0.32)
	)
	_expect(acquired.size() == 1, "CharacterInfo presenter should build one acquired Angel Dice entry")
	if acquired.size() != 1:
		return
	var entry: Dictionary = acquired[0]
	_expect(str(entry.get("description", "")) == "\n".join(status_lines), "CharacterInfo presenter should replace stale catalog stats with live Angel status lines")
	_expect(str(entry.get("detail", "")) == status_lines[0], "CharacterInfo presenter should give an empty detail field the live Angel status header")

	# The live TAB snapshot normally carries a non-empty fusion display
	# projection even when Angel itself is an ordinary projected perk entry.
	# Seal that early-return path as well as the legacy levels-only fallback.
	var projection_snapshot := {
		"effective_runtime_skill_levels": {PERK_ID: 1},
		"perk_fusion_display_projection": {
			"entries": [{
				"type": "perk",
				"perk_id": PERK_ID,
				"base_level": 1,
				"effective_level": 1,
				"slot_cost": 1,
			}],
		},
	}
	var projected: Array = CharacterInfoOverlayPerkPresenter.build_acquired_perks(
		{PERK_ID: 1},
		catalog,
		state,
		projection_snapshot,
		{PERK_ID: 1},
		[]
	)
	_expect(projected.size() == 1, "live fusion projection should keep the projected Angel entry")
	if projected.size() == 1:
		var projected_entry: Dictionary = projected[0]
		_expect(
			str(projected_entry.get("description", "")) == "\n".join(status_lines),
			"live fusion projection path should apply Angel runtime status lines before returning"
		)


func _verify_angel_revision_invalidates_presenter_cache(state: Object) -> void:
	var catalog := FakeCatalog.new()
	var levels := {PERK_ID: 1}
	var effective_levels := {PERK_ID: 1}
	var base_snapshot := {
		"effective_runtime_skill_levels": effective_levels.duplicate(true),
		"angel_blessing": state.get_angel_blessing_snapshot(),
		"angel_blessing_acquisition": state.get_angel_blessing_acquisition_snapshot(),
	}
	var base_hash: int = CharacterInfoOverlayPerkPresenter.acquired_perk_cache_hash(
		levels,
		catalog,
		state,
		base_snapshot,
		effective_levels,
		[]
	)
	var revised_snapshot: Dictionary = base_snapshot.duplicate(true)
	var revised_roll: Dictionary = revised_snapshot.get("angel_blessing", {}) as Dictionary
	revised_roll["revision"] = int(revised_roll.get("revision", 0)) + 1
	revised_snapshot["angel_blessing"] = revised_roll
	var revised_hash: int = CharacterInfoOverlayPerkPresenter.acquired_perk_cache_hash(
		levels,
		catalog,
		state,
		revised_snapshot,
		effective_levels,
		[]
	)
	_expect(revised_hash != base_hash, "Angel roll revision alone should invalidate the CharacterInfo acquired-perk cache")


func _owned_state() -> Object:
	var state := RuntimePerkState.new()
	state.runtime_skill_levels[PERK_ID] = 1
	return state


func _expect_array(actual: Array, expected: Array, message: String) -> void:
	if actual == expected:
		return
	_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
