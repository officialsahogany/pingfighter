extends SceneTree

const CharacterInfoOverlayLingpetCardSpecs := preload("res://scripts/hud/character_info_overlay_lingpet_card_specs.gd")
const CharacterInfoOverlayLingpetPresenter := preload("res://scripts/hud/character_info_overlay_lingpet_presenter.gd")
const SourceContractFunctionBody := preload("res://tests/source_contract_function_body.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_full_skill_rail_projection()
	_verify_unlock_projection()
	_verify_presenter_boundary_contract()
	if _failures.is_empty():
		print("character_info_lingpet_card_specs_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_full_skill_rail_projection() -> void:
	var stat_color := Color(0.45, 1.0, 0.68, 1.0)
	var snapshot := {
		"pet_id": "maribo",
		"companion_skill_id": "maribo_hydro_sphere",
		"companion_skill_name": "하이드로 스피어",
		"companion_skill_description": "첫 액티브",
		"companion_skill_cooldown_duration": 40.0,
		"companion_skill_level": 2,
		"companion_skill_icon_path": "res://active_1.png",
		"companion_skill_card_path": "res://active_1_card.png",
		"companion_skill_id_1": "second_active",
		"companion_skill_name_1": "두 번째 액티브",
		"companion_skill_description_1": "둘째 액티브",
		"companion_skill_cooldown_duration_1": 12.5,
		"companion_skill_level_1": 3,
		"companion_skill_icon_path_1": "res://active_2.png",
		"companion_passive_skill_id": "lingpet_resonance_boost",
		"companion_passive_skill_name": "공명 부스트",
		"companion_passive_skill_description": "첫 패시브",
		"companion_passive_skill_level": 4,
		"companion_passive_skill_icon_path": "res://passive_1.png",
		"gauge_gain_bonus_pct": 12.5,
		"companion_player_speed_bonus_pct": 8.0,
		"companion_starpoint_tracking_chance_pct": 6.0,
		"companion_ring_dash_chance_pct": 4.0,
		"companion_passive_skill_id_1": "second_passive",
		"companion_passive_skill_name_1": "두 번째 패시브",
		"companion_passive_skill_description_1": "둘째 패시브",
		"companion_passive_skill_level_1": 5,
		"companion_passive_skill_icon_path_1": "res://passive_2.png",
	}
	var specs := CharacterInfoOverlayLingpetCardSpecs.get_skill_specs(snapshot, stat_color)
	_expect(specs.size() == 4, "full Lingpet loadout should project two active and two passive cards")
	if specs.size() != 4:
		return
	var active_one: Dictionary = specs[0]
	var active_two: Dictionary = specs[1]
	var passive_one: Dictionary = specs[2]
	var passive_two: Dictionary = specs[3]
	_expect(str(active_one.get("subtitle", "")).find("Lv.2") >= 0 and str(active_one.get("subtitle", "")).find("40") >= 0, "primary active subtitle should preserve level and cooldown")
	_expect(str(active_two.get("subtitle", "")).find("Lv.3") >= 0 and str(active_two.get("subtitle", "")).find("12.5") >= 0, "second active subtitle should preserve level and cooldown")
	_expect(str(passive_one.get("subtitle", "")).find("Lv.4") >= 0, "primary passive subtitle should preserve level")
	for token in ["받아치기", "이동", "추적", "전이"]:
		_expect(str(passive_one.get("subtitle", "")).find(token) >= 0, "primary passive subtitle should preserve %s bonus copy" % token)
	_expect(str(passive_two.get("subtitle", "")).find("Lv.5") >= 0, "second passive subtitle should preserve level")
	_expect(CharacterInfoOverlayLingpetPresenter.get_skill_specs(snapshot, stat_color) == specs, "presenter compatibility facade should return the exact card-spec projection")
	_expect(CharacterInfoOverlayLingpetCardSpecs.get_display_name("") == "링펫", "blank pet id should keep the generic Ringpet label")


func _verify_unlock_projection() -> void:
	var options: Array = [
		{"choice_key": "active", "locked": true, "candidates": ["a", "b"]},
		{"choice_key": "passive", "locked": false, "candidates": ["only_one"]},
		{"choice_key": "second_active", "locked": false, "candidates": ["a", "b"]},
		{"choice_key": "second_passive", "locked": false, "candidates": ["c", "d"]},
	]
	_expect(CharacterInfoOverlayLingpetCardSpecs.count_open_unlock_options(options) == 2, "unlock count should ignore locked and single-candidate choices")
	_expect(str(CharacterInfoOverlayLingpetCardSpecs.first_open_unlock_option(options).get("choice_key", "")) == "second_active", "first-open projection should preserve source order")
	_expect(CharacterInfoOverlayLingpetCardSpecs.unlock_choice_title("second_active") == "2nd 액티브 선택", "second-active title should remain authored Korean copy")
	_expect(CharacterInfoOverlayLingpetCardSpecs.unlock_choice_subtitle("passive") == "패시브 후보", "passive candidate subtitle should remain authored Korean copy")
	var candidate := CharacterInfoOverlayLingpetCardSpecs.unlock_candidate_spec("maribo", "active", "maribo_hydro_sphere", Color.GREEN, Color.CYAN)
	_expect(str(candidate.get("id", "")) == "maribo_hydro_sphere", "active unlock candidate should preserve catalog id")
	_expect(str(candidate.get("card_texture_path", "")).find("maribo_hydro_sphere") >= 0, "active unlock candidate should preserve card art path")
	_expect(bool(candidate.get("use_card", false)), "active unlock candidate should select card art when available")


func _verify_presenter_boundary_contract() -> void:
	var presenter_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_lingpet_presenter.gd")
	var specs_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_lingpet_card_specs.gd")
	_expect(_function_body(presenter_source, "static func get_skill_specs(").find("CharacterInfoOverlayLingpetCardSpecs.get_skill_specs") >= 0, "presenter skill-spec facade should delegate")
	_expect(_function_body(presenter_source, "static func _unlock_candidate_spec(").find("CharacterInfoOverlayLingpetCardSpecs.unlock_candidate_spec") >= 0, "presenter unlock-candidate facade should delegate")
	_expect(_function_body(presenter_source, "static func _first_open_unlock_option(").find("CharacterInfoOverlayLingpetCardSpecs.first_open_unlock_option") >= 0, "presenter first-open facade should delegate")
	_expect(_function_body(presenter_source, "static func get_skill_specs(").find("companion_skill_cooldown_duration_1") < 0, "skill-spec facade should not retain second-skill card composition details")
	_expect(specs_source.find("CanvasItem") < 0 and specs_source.find("FileAccess") < 0, "card-spec projection should remain draw- and I/O-free")


func _function_body(source: String, signature: String) -> String:
	return SourceContractFunctionBody.extract(source, signature)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
