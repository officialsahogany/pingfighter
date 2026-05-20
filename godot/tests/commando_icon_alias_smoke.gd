extends SceneTree

const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")

const COMMANDO_UNLOCK_ICON_ALIASES := {
	"soldier_unlock_net_gun": "net_gun",
	"soldier_unlock_fire_support": "fire_support",
	"soldier_unlock_bowling_trap": "bowling_trap",
	"soldier_unlock_suicide_drone": "suicide_drone",
	"soldier_unlock_bazooka": "bazooka",
	"soldier_unlock_ak47": "ak47",
	"soldier_pistol_perk": "commando_pistol",
}

var _failures: Array[String] = []


func _init() -> void:
	_verify_commando_unlock_alias_icons()

	if _failures.is_empty():
		print("commando_icon_alias_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_commando_unlock_alias_icons() -> void:
	var catalog := RuntimePerkCatalog.new()
	var renderer := RuntimePerkIconRenderer.new()
	var covered_ids: Array = renderer.covered_ids()
	var commando_orb_paths: Dictionary = BattleResources.COMMANDO_SKILL_ICON_PATHS

	for perk_id in COMMANDO_UNLOCK_ICON_ALIASES.keys():
		var skill_id: String = str(COMMANDO_UNLOCK_ICON_ALIASES[perk_id])
		var perk_data: Dictionary = catalog.get_perk_data(str(perk_id))
		_expect(not perk_data.is_empty(), "%s should exist in the runtime perk catalog" % str(perk_id))
		_expect(str(perk_data.get("unlocks_skill", "")) == skill_id, "%s should unlock %s" % [str(perk_id), skill_id])
		_expect(bool(perk_data.get("is_weapon_unlock", false)), "%s should be marked as a Commando weapon unlock" % str(perk_id))

		var expected_path: String = str(commando_orb_paths.get(skill_id, ""))
		_expect(expected_path != "", "%s should have a Commando orb path" % skill_id)
		_expect(str(renderer._resolve_skill_icon_id(str(perk_id))) == skill_id, "%s should resolve to %s" % [str(perk_id), skill_id])
		_expect(str(renderer._get_static_path(str(perk_id))) == expected_path, "%s should reuse the real orb PNG path" % str(perk_id))
		_expect(str(renderer._get_static_path(skill_id)) == expected_path, "%s should use the same orb PNG path" % skill_id)
		_expect(renderer.has_icon(str(perk_id)), "%s should load through the runtime perk icon renderer" % str(perk_id))
		_expect(renderer.has_icon(skill_id), "%s should load as the real orb icon" % skill_id)

		var perk_source: Dictionary = renderer._get_icon_source(str(perk_id))
		var skill_source: Dictionary = renderer._get_icon_source(skill_id)
		_expect(perk_source.get("texture", null) == skill_source.get("texture", null), "%s and %s should share the same loaded texture" % [str(perk_id), skill_id])
		_expect(bool(renderer._needs_unlock_badge(str(perk_id))), "%s should draw the unlock badge over the shared motif" % str(perk_id))
		_expect(not bool(renderer._needs_unlock_badge(skill_id)), "%s orb icon should not draw the unlock badge" % skill_id)
		_expect(covered_ids.has(str(perk_id)), "%s should be listed in covered runtime icon ids" % str(perk_id))
		_expect(covered_ids.has(skill_id), "%s should be listed in covered runtime icon ids" % skill_id)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
