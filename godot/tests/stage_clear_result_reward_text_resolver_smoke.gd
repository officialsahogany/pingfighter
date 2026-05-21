extends SceneTree

const StageClearResultRewardTextResolver := preload("res://scripts/ui/stage_clear_result_reward_text_resolver.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")

var _failures: Array[String] = []


class FakePerkCatalog:
	extends RefCounted

	func get_perk_data(perk_id: String) -> Dictionary:
		if perk_id == "catalog_perk":
			return {
				"id": "catalog_perk",
				"name": "Catalog Perk",
				"description": "Catalog Detail",
			}
		return {}


func _init() -> void:
	_verify_detail_text_resolution()
	_verify_perk_data_resolution()
	_verify_type_fallback_labels()
	_verify_title_resolution()
	_verify_scene_delegates_text_resolver()

	if _failures.is_empty():
		print("stage_clear_result_reward_text_resolver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_detail_text_resolution() -> void:
	_expect(
		StageClearResultRewardTextResolver.get_reward_detail_text({"description": "Direct"}, {"description": "Perk"}, "Fallback") == "Direct",
		"direct reward description should win over perk data"
	)
	_expect(
		StageClearResultRewardTextResolver.get_reward_detail_text({"detail": "Direct Detail"}, {}, "Fallback") == "Direct Detail",
		"direct reward detail should be used when description is empty"
	)
	_expect(
		StageClearResultRewardTextResolver.get_reward_detail_text({}, {"description": "Perk Description"}, "Fallback") == "Perk Description",
		"perk description should be used after direct reward text"
	)
	_expect(
		StageClearResultRewardTextResolver.get_reward_detail_text({"next_level": 2}, {"descriptions": {1: "Level 1", 2: "Level 2"}}, "Fallback") == "Level 2",
		"perk descriptions should prefer the next level entry"
	)
	_expect(
		StageClearResultRewardTextResolver.get_reward_detail_text({"next_level": 4}, {"descriptions": {1: "Level 1"}}, "Fallback") == "Level 1",
		"perk descriptions should fall back to level 1"
	)
	_expect(
		StageClearResultRewardTextResolver.get_reward_detail_text({}, {"detail": "Perk Detail"}, "Fallback") == "Perk Detail",
		"perk detail should be used when descriptions are missing"
	)
	_expect(
		StageClearResultRewardTextResolver.get_reward_detail_text({}, {}, "Fallback") == "Fallback",
		"detail resolver should return the caller fallback when no text exists"
	)


func _verify_perk_data_resolution() -> void:
	var inline_reward: Dictionary = {"perk_data": {"id": "inline", "name": "Inline Perk"}}
	var inline_data: Dictionary = StageClearResultRewardTextResolver.get_reward_perk_data(inline_reward, FakePerkCatalog.new(), "catalog_perk")
	_expect(str(inline_data.get("name", "")) == "Inline Perk", "inline perk_data should win over catalog data")
	inline_data["name"] = "Changed"
	_expect(str((inline_reward["perk_data"] as Dictionary).get("name", "")) == "Inline Perk", "inline perk_data should be duplicated")

	var catalog_data: Dictionary = StageClearResultRewardTextResolver.get_reward_perk_data({}, FakePerkCatalog.new(), "catalog_perk")
	_expect(str(catalog_data.get("name", "")) == "Catalog Perk", "catalog perk data should be used when inline data is absent")
	catalog_data["name"] = "Changed"
	var catalog_data_again: Dictionary = StageClearResultRewardTextResolver.get_reward_perk_data({}, FakePerkCatalog.new(), "catalog_perk")
	_expect(str(catalog_data_again.get("name", "")) == "Catalog Perk", "catalog perk data should be duplicated")

	_expect(
		StageClearResultRewardTextResolver.get_reward_perk_data({}, null, "catalog_perk").is_empty(),
		"missing catalog should return empty perk data"
	)
	_expect(
		StageClearResultRewardTextResolver.get_reward_perk_data({}, FakePerkCatalog.new(), "").is_empty(),
		"missing perk id should return empty perk data"
	)


func _verify_type_fallback_labels() -> void:
	_expect(StageClearResultRewardTextResolver.get_reward_type_fallback_label("active") == "액티브", "active fallback label should be localized")
	_expect(StageClearResultRewardTextResolver.get_reward_type_fallback_label("passive") == "패시브", "passive fallback label should be localized")
	_expect(StageClearResultRewardTextResolver.get_reward_type_fallback_label("mythic") == "신화", "mythic fallback label should be localized")
	_expect(StageClearResultRewardTextResolver.get_reward_type_fallback_label("starpoint") == "스타포인트", "starpoint fallback label should be localized")
	_expect(StageClearResultRewardTextResolver.get_reward_type_fallback_label("skill") == "퍽", "skill fallback label should reuse the perk label")
	_expect(StageClearResultRewardTextResolver.get_reward_type_fallback_label("unknown") == "보상", "unknown fallback label should use the reward fallback")


func _verify_title_resolution() -> void:
	_expect(
		StageClearResultRewardTextResolver.get_reward_title({"label": "Direct Label"}, {"name": "Perk Name"}, true, "Fallback") == "Direct Label",
		"direct reward label should win over perk name"
	)
	_expect(
		StageClearResultRewardTextResolver.get_reward_title({}, {"name": "Perk Name"}, true, "Fallback") == "Perk Name",
		"perk reward title should use perk data name"
	)
	_expect(
		StageClearResultRewardTextResolver.get_reward_title({}, {"name": "Perk Name"}, false, "Fallback") == "Fallback",
		"non-perk reward title should use fallback label"
	)
	_expect(
		StageClearResultRewardTextResolver.get_reward_title({"type": "starpoint", "amount": 8}, {}, false, "Fallback", "퍽 선택권") == "퍽 선택권 +8",
		"starpoint rewards should format the amount title in the resolver"
	)


func _verify_scene_delegates_text_resolver() -> void:
	var scene := StageClearResultScene.new()
	scene._perk_catalog = FakePerkCatalog.new()

	_expect(scene._get_reward_title({"type": "starpoint", "amount": 5}).contains("+5"), "scene should keep starpoint amount title formatting")
	_expect(scene._get_reward_title({"type": "perk", "perk_id": "catalog_perk"}) == "Catalog Perk", "scene title wrapper should use catalog perk names")
	_expect(scene._get_reward_detail_text({"type": "perk", "perk_id": "catalog_perk"}) == "Catalog Detail", "scene detail wrapper should use catalog perk descriptions")
	_expect(scene._get_reward_detail_text({"perk_data": {"descriptions": {2: "Level 2"}}, "next_level": 2}) == "Level 2", "scene detail wrapper should delegate level descriptions")
	_expect(scene._get_reward_perk_data({"perk_id": "catalog_perk"}).get("name", "") == "Catalog Perk", "scene perk-data wrapper should delegate catalog lookup")
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	_expect(
		source.find("StageClearResultRewardTextResolver.get_reward_type_fallback_label") >= 0,
		"scene should call fallback-label resolver directly"
	)
	_expect(
		source.find("func _reward_type_fallback_label") < 0
		and source.find("func _get_reward_detail_fallback_text") < 0,
		"scene should not keep text pass-through fallback wrappers"
	)
	scene.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
