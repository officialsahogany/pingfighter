extends SceneTree

const Stage7AkamuBossSkillHudRenderer := preload("res://scripts/stages/stage7/stage7_akamu_boss_skill_hud_renderer.gd")
const Stage7AkamuState := preload("res://scripts/stages/stage7/stage7_akamu_state.gd")

const SKILLCARD_PATHS := {
	"stage7_clone": "res://assets/sprites/hud/stage7_akamu_shadow_clone_skillcard_imagegen_v1.png",
	"stage7_shuriken": "res://assets/sprites/hud/stage7_akamu_shuriken_skillcard_imagegen_v1.png",
	"stage7_cloud": "res://assets/sprites/hud/stage7_akamu_cloud_screen_skillcard_imagegen_v1.png",
	"stage7_superspeed": "res://assets/sprites/hud/stage7_akamu_superspeed_skillcard_imagegen_v1.png",
}
const ASSET_STATUS_KEYS := [
	"clone_card_texture",
	"shuriken_card_texture",
	"cloud_card_texture",
	"superspeed_card_texture",
]
const EXPECTED_SKILL_IDS := [
	"stage7_clone",
	"stage7_shuriken",
	"stage7_cloud",
	"stage7_superspeed",
]

var _failures: Array[String] = []


func _init() -> void:
	var renderer := Stage7AkamuBossSkillHudRenderer.new()
	_verify_staged_prewarm(renderer)
	_verify_card_resources()
	_verify_live_state_surface()
	_verify_fill_ratio_contract(renderer)
	_verify_active_tooltip_contract()

	if _failures.is_empty():
		print("stage7_akamu_skillcard_art_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_card_resources() -> void:
	for skill_id in EXPECTED_SKILL_IDS:
		var path: String = str(SKILLCARD_PATHS.get(skill_id, ""))
		_expect(path != "", "%s should have a skillcard texture path" % skill_id)
		_expect(FileAccess.file_exists(path), "%s skillcard PNG should exist" % skill_id)
		var importable: bool = ResourceLoader.exists(path, "Texture2D")
		_expect(importable, "%s skillcard PNG should be importable as Texture2D" % skill_id)
		if not importable:
			continue
		var texture := ResourceLoader.load(path, "Texture2D") as Texture2D
		_expect(texture != null, "%s skillcard PNG should load as Texture2D" % skill_id)
		if texture == null:
			continue
		var texture_size: Vector2 = texture.get_size()
		_expect(texture_size.x >= 1024.0, "%s skillcard should retain high-resolution source art" % skill_id)
		_expect(texture_size.y >= 256.0, "%s skillcard should retain enough vertical detail" % skill_id)
		var aspect_ratio: float = texture_size.x / maxf(1.0, texture_size.y)
		_expect(
			aspect_ratio >= 3.0 and aspect_ratio <= 4.2,
			"%s skillcard should use a wide card composition, got %.3f:1" % [skill_id, aspect_ratio]
		)


func _verify_staged_prewarm(renderer: Object) -> void:
	_expect(renderer.has_method("prewarm_assets_step"), "Stage 7 skillcard renderer should expose staged prewarm")
	if not renderer.has_method("prewarm_assets_step"):
		return
	for step_index in range(EXPECTED_SKILL_IDS.size()):
		var completed: bool = bool(renderer.call("prewarm_assets_step"))
		var expected_completed: bool = step_index == EXPECTED_SKILL_IDS.size() - 1
		_expect(
			completed == expected_completed,
			"Stage 7 skillcard prewarm step %d should report completed=%s" % [step_index + 1, expected_completed]
		)
		_expect(
			_texture_cache_size(renderer) == step_index + 1,
			"Stage 7 skillcard prewarm step %d should touch exactly one additional texture" % (step_index + 1)
		)
	_expect(bool(renderer.call("prewarm_assets_step")), "completed Stage 7 skillcard prewarm should remain idempotent")
	_expect(_texture_cache_size(renderer) == 4, "idempotent Stage 7 skillcard prewarm should keep four cached textures")

	var asset_status: Dictionary = renderer.call("get_asset_status")
	for key in ASSET_STATUS_KEYS:
		_expect(bool(asset_status.get(key, false)), "Stage 7 skillcard renderer should report %s loaded" % key)
	_expect(
		not bool(asset_status.get("uses_code_native_placeholder", true)),
		"Stage 7 skillcard renderer should leave code-native placeholder mode after art prewarm"
	)


func _verify_live_state_surface() -> void:
	var state := Stage7AkamuState.new()
	var hud_context: Dictionary = state.get_hud_context()
	_expect(bool(hud_context.get("stage7_boss_skill_hud_active", false)), "Stage 7 live state should enable its boss skillcard rail")
	var skills: Array = _as_array(hud_context.get("stage7_boss_skill_hud_skills", []))
	_expect(skills.size() == 3, "Stage 7 live state should keep the ultimate card off the rail before Awakening")
	var actual_ids: Array[String] = []
	for value in skills:
		if not (value is Dictionary):
			continue
		var skill: Dictionary = value
		actual_ids.append(str(skill.get("id", "")))
		_expect(bool(skill.get("implemented", false)), "%s should be a live implemented skillcard" % str(skill.get("id", "unknown")))
		_expect(skill.has("status"), "%s should expose a live HUD status" % str(skill.get("id", "unknown")))
		_expect(skill.has("progress"), "%s should expose cooldown progress" % str(skill.get("id", "unknown")))
		_expect(skill.has("next_activation_remaining"), "%s should expose next-activation sorting metadata" % str(skill.get("id", "unknown")))
	_expect(actual_ids == EXPECTED_SKILL_IDS.slice(0, 3), "Stage 7 pre-Awakening rail should publish only the three base skill ids")
	state.debug_force_complete_awakening()
	skills = _as_array(state.get_hud_context().get("stage7_boss_skill_hud_skills", []))
	actual_ids.clear()
	for value in skills:
		if value is Dictionary:
			actual_ids.append(str((value as Dictionary).get("id", "")))
	_expect(actual_ids == EXPECTED_SKILL_IDS, "Awakening should reveal the ultimate as the fourth art-backed rail card")
	var unlocked_skill := _find_skill(skills, "stage7_superspeed")
	_expect_close(float(unlocked_skill.get("cooldown_remaining", 0.0)), 50.0, "the revealed ultimate card should begin on its 50-second unlock cooldown")
	_expect_close(float(unlocked_skill.get("cooldown_total", 0.0)), 50.0, "the revealed ultimate card should expose the shared 50-second cooldown total")


func _verify_fill_ratio_contract(renderer: Object) -> void:
	_expect(
		renderer.has_method("_resolve_fill_ratio"),
		"Stage 7 skillcard renderer should expose _resolve_fill_ratio for status-safe cooldown rendering"
	)
	if not renderer.has_method("_resolve_fill_ratio"):
		return

	var charging_state := Stage7AkamuState.new()
	charging_state.debug_set_shuriken_cooldown_remaining(5.0, 10.0)
	var charging_skill := _find_skill(
		charging_state.get_hud_context().get("stage7_boss_skill_hud_skills", []),
		"stage7_shuriken"
	)
	_expect(str(charging_skill.get("status", "")) == "charging", "shuriken fill precondition should use live charging state")
	_expect_close(
		float(renderer.call("_resolve_fill_ratio", charging_skill)),
		0.5,
		"charging Stage 7 skillcard should preserve cooldown progress"
	)

	var locked_state := Stage7AkamuState.new()
	locked_state.debug_set_gauge(200.0)
	var locked_skill := _find_skill(
		locked_state.get_hud_context().get("stage7_boss_skill_hud_skills", []),
		"stage7_superspeed"
	)
	_expect(locked_skill.is_empty(), "the locked ultimate should be absent instead of leaking a pre-Awakening card")
	var locked_fixture := {"status": "locked", "progress": 0.8}
	_expect_close(
		float(renderer.call("_resolve_fill_ratio", locked_fixture)),
		0.0,
		"the renderer's compatibility locked state should still force zero bright fill"
	)

	var ready_state := Stage7AkamuState.new()
	ready_state.debug_set_awakened(true)
	ready_state.debug_set_gauge(250.0)
	var ready_skill := _find_skill(
		ready_state.get_hud_context().get("stage7_boss_skill_hud_skills", []),
		"stage7_superspeed"
	)
	_expect(str(ready_skill.get("status", "")) == "ready", "superspeed fill precondition should use live ready state")
	_expect_close(
		float(renderer.call("_resolve_fill_ratio", ready_skill)),
		1.0,
		"ready Stage 7 skillcard should render fully bright"
	)

	ready_state.debug_set_superspeed_active(true)
	var active_skill := _find_skill(
		ready_state.get_hud_context().get("stage7_boss_skill_hud_skills", []),
		"stage7_superspeed"
	)
	_expect(str(active_skill.get("status", "")) == "active", "superspeed fill precondition should use live active state")
	_expect_close(
		float(renderer.call("_resolve_fill_ratio", active_skill)),
		1.0,
		"active Stage 7 skillcard should stay fully bright instead of draining with duration"
	)


func _verify_active_tooltip_contract() -> void:
	var status_labels: Dictionary = Stage7AkamuBossSkillHudRenderer.TOOLTIP_STYLE.get("status_labels", {})
	_expect(
		str(status_labels.get("active", "")) == "발동 중",
		"active Stage 7 skillcard tooltip should describe the live activation instead of charge progress"
	)


func _texture_cache_size(renderer: Object) -> int:
	var textures: Variant = renderer.get("_textures")
	if textures is Dictionary:
		return (textures as Dictionary).size()
	return -1


func _find_skill(value: Variant, skill_id: String) -> Dictionary:
	for entry_value in _as_array(value):
		if entry_value is Dictionary and str((entry_value as Dictionary).get("id", "")) == skill_id:
			return entry_value
	return {}


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _expect_close(actual: float, expected: float, message: String, tolerance: float = 0.0001) -> void:
	_expect(absf(actual - expected) <= tolerance, "%s (expected %.4f, got %.4f)" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
