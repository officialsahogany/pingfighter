extends SceneTree

const LingpetCollectionState := preload("res://scripts/lingpet/lingpet_collection_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_cosmetic_identity_vocabulary_is_retained()
	_verify_collection_identity_survives_without_affinity_growth()
	_verify_numeric_and_next_reward_surfaces_are_retired()

	if _failures.is_empty():
		print("lingpet_permanent_collection_surface_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_cosmetic_identity_vocabulary_is_retained() -> void:
	var language_source := FileAccess.get_file_as_string(
		"res://scripts/core/language_settings_data.gd"
	)
	_expect(
		language_source.count('"하트 공명":') == 4,
		"Heart Resonance must remain a localized cosmetic identity term"
	)


func _verify_collection_identity_survives_without_affinity_growth() -> void:
	var collection := LingpetCollectionState.new()
	collection.set_owned_pet_ids(["maribo", "lunabi"])
	_expect(
		collection.get_owned_pet_ids() == ["maribo", "lunabi"],
		"guardian collection identity must remain independent from retired affinity growth"
	)
	var collection_source := FileAccess.get_file_as_string(
		"res://scripts/lingpet/lingpet_collection_state.gd"
	)
	_expect(
		collection_source.contains("func get_owned_pet_ids"),
		"the permanent owned-guardian collection surface must remain"
	)


func _verify_numeric_and_next_reward_surfaces_are_retired() -> void:
	var presenter_source := FileAccess.get_file_as_string(
		"res://scripts/hud/character_info_overlay_lingpet_presenter.gd"
	)
	var stats_source := FileAccess.get_file_as_string(
		"res://scripts/hud/character_info_overlay_lingpet_stats_projection.gd"
	)
	for retired_term in ["affinity_points", "affinity_level", "교감", "다음 보상"]:
		_expect(
			not presenter_source.contains(retired_term),
			"TAB presenter must not restore retired affinity surface: %s" % retired_term
		)
		_expect(
			not stats_source.contains(retired_term),
			"TAB stats must not restore retired affinity surface: %s" % retired_term
		)
	var language_source := FileAccess.get_file_as_string(
		"res://scripts/core/language_settings_data.gd"
	)
	_expect(
		not language_source.contains('"최대 강화 완료":'),
		"retired affinity terminal-reward copy must not remain in localization data"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
