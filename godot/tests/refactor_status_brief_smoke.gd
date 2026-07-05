extends SceneTree

const StageRuntimeRouter := preload("res://scripts/stages/stage_runtime_router.gd")
const GameplayStageModuleCatalog := preload("res://scripts/resources/gameplay_stage_module_catalog.gd")

const BRIEF_PATH := "res://../docs/refactor_status_brief.md"
const BOUNDARY_PATH := "res://../docs/current_development_boundary.md"
const ARCHITECTURE_PATH := "res://../docs/godot_port_architecture.md"
const LEDGER_PATH := "res://../docs/godot_module_ownership_ledger.md"
const MAIN_SCENE_PATH := "res://scenes/main.gd"

const SCRIPT_FOLDERS := [
	"items",
	"stages",
	"characters",
	"core",
	"lingpet",
	"hud",
	"ball",
	"ui",
	"resources",
	"effects",
	"plaza",
	"status",
	"audio",
	"ai",
]

const STAGE_FOLDERS := [
	"stage1",
	"stage2",
	"stage3",
	"stage4",
	"stage5",
	"stage6",
	"common",
]

const STAGE_LABELS := [
	"Stage 1",
	"Stage 2",
	"Stage 3",
	"Stage 4",
	"Stage 5",
	"Stage 6",
	"`common`",
]

const CHARACTER_PREFIXES := {
	"Smasher-prefixed": "smasher_",
	"Commando-prefixed": "commando_",
	"Viper-prefixed": "viper_",
	"Optimus-prefixed": "optimus_",
	"Blacksmith-prefixed": "blacksmith_",
	"Baltor-prefixed": "baltor_",
}

const STAGE_ROUTE_EXPECTATIONS := {
	5: {
		"actor_renderer": "stage5_hongryun_actor_renderer",
		"boss_actor_renderer": "stage5_hongryun_boss_actor_renderer",
		"pillar_scene_drawer": "stage5_hongryun_pillar_scene_drawer",
		"stage_background": "stage5_hongryun_pillar_background",
		"playfield_renderer": "stage5_hongryun_playfield_renderer",
		"boss_skill_hud_renderer": "stage5_hongryun_boss_skill_hud_renderer",
	},
	6: {
		"actor_renderer": "stage6_tetriser_actor_renderer",
		"boss_actor_renderer": "stage6_tetriser_boss_actor_renderer",
		"pillar_scene_drawer": "stage6_tetriser_pillar_scene_drawer",
		"stage_background": "stage6_tetriser_pillar_background",
		"playfield_renderer": "stage6_tetriser_playfield_renderer",
		"boss_skill_hud_renderer": "stage6_tetriser_boss_skill_hud_renderer",
	},
}

var _failed := false


func _init() -> void:
	var brief := _read_text(BRIEF_PATH)
	var boundary := _read_text(BOUNDARY_PATH)
	var architecture := _read_text(ARCHITECTURE_PATH)
	var ledger := _read_text(LEDGER_PATH)
	_expect(brief != "", "refactor status brief should be readable")
	_expect(boundary != "", "current development boundary should be readable")
	_expect(architecture != "", "Godot port architecture doc should be readable")
	_expect(ledger != "", "module ownership ledger should be readable")

	var script_files := _collect_gd_files("res://scripts")
	var test_files := _collect_gd_files("res://tests")
	var smoke_count := _count_smoke_files(test_files)
	_verify_snapshot_counts(brief, script_files.size(), test_files.size(), smoke_count)
	_verify_boundary_snapshot(boundary, script_files.size())
	_verify_architecture_snapshot_links(architecture)
	_verify_shell_and_stage_routes(brief, boundary)
	_verify_script_distribution(brief)
	_verify_stage_status(brief)
	_verify_character_status(brief)
	_verify_lingpet_coverage(brief, ledger)

	if _failed:
		quit(1)
		return
	print("refactor_status_brief_smoke: ok")
	quit(0)


func _verify_snapshot_counts(brief: String, script_count: int, test_count: int, smoke_count: int) -> void:
	_expect_table_int(brief, "`godot/scripts/` `.gd` files", 2, script_count, "brief scripts total should match the worktree")
	_expect_table_int(brief, "`godot/tests/` `.gd` files", 2, test_count, "brief tests total should match the worktree")
	_expect_table_int(brief, "`godot/tests/*_smoke.gd` files", 2, smoke_count, "brief smoke-test total should match the worktree")


func _verify_boundary_snapshot(boundary: String, script_count: int) -> void:
	_expect_contains(
		boundary,
		"The current worktree has %d GDScript modules under `godot/scripts/`." % script_count,
		"boundary script-count sentence should match the worktree"
	)
	_expect_contains(
		boundary,
		"Every current `godot/scripts/lingpet/*.gd`",
		"boundary should preserve the Lingpet ownership coverage claim"
	)
	_expect_contains(
		boundary,
		"`docs/refactor_status_brief.md`: one-page current Godot refactor status snapshot.",
		"boundary must-read list should keep the detailed refactor brief linked"
	)


func _verify_architecture_snapshot_links(architecture: String) -> void:
	_expect_contains(
		architecture,
		"Date-stamped status and module-count snapshots live in",
		"architecture doc should point status/count readers at the snapshot docs"
	)
	_expect_contains(
		architecture,
		"`docs/current_development_boundary.md`",
		"architecture doc should link the current boundary snapshot"
	)
	_expect_contains(
		architecture,
		"`docs/refactor_status_brief.md`",
		"architecture doc should link the detailed refactor brief"
	)
	_expect_contains(
		architecture,
		"This map names the stable owner folders.",
		"architecture module map should avoid duplicating per-snapshot counts"
	)


func _verify_shell_and_stage_routes(brief: String, boundary: String) -> void:
	var main_source := _read_text(MAIN_SCENE_PATH).strip_edges()
	_expect(
		main_source == "extends \"res://scripts/core/battle_scene_shell.gd\"",
		"main.gd should remain the one-line battle_scene_shell extension"
	)
	_expect_contains(
		brief + "\n" + boundary,
		"`godot/scenes/main.gd` is still the intended one-line shell extending",
		"snapshot docs should keep the main.gd shell claim explicit"
	)

	var router := StageRuntimeRouter.new()
	var catalog := GameplayStageModuleCatalog.new()
	for stage in STAGE_ROUTE_EXPECTATIONS.keys():
		var stage_id := int(stage)
		var expected_routes: Dictionary = STAGE_ROUTE_EXPECTATIONS[stage]
		for role in expected_routes.keys():
			var expected_key := str(expected_routes[role])
			var actual_key := router.get_module_key(stage_id, str(role))
			_expect(
				actual_key == expected_key,
				"Stage %d %s route should be %s, found %s" % [stage_id, str(role), expected_key, actual_key]
			)
			var spec: Dictionary = catalog.get_spec(expected_key)
			var path := str(spec.get("path", ""))
			_expect(path != "", "stage module catalog should register %s" % expected_key)
			_expect(FileAccess.file_exists(path), "stage module catalog path should exist for %s: %s" % [expected_key, path])


func _verify_script_distribution(brief: String) -> void:
	for folder in SCRIPT_FOLDERS:
		var folder_name := str(folder)
		var count := _collect_gd_files("res://scripts/%s" % folder_name).size()
		_expect_table_int(
			brief,
			"`scripts/%s/`" % folder_name,
			1,
			count,
			"brief script distribution should match %s" % folder_name
		)


func _verify_stage_status(brief: String) -> void:
	for index in range(STAGE_FOLDERS.size()):
		var folder_name := str(STAGE_FOLDERS[index])
		var label := str(STAGE_LABELS[index])
		var count := _collect_gd_files("res://scripts/stages/%s" % folder_name).size()
		_expect_table_int(brief, label, 3, count, "brief stage count should match %s" % folder_name)
	var root_count := _count_direct_gd_files("res://scripts/stages")
	_expect_table_int(brief, "`root`", 3, root_count, "brief stage root count should match direct stage scripts")


func _verify_character_status(brief: String) -> void:
	var character_files := _collect_gd_files("res://scripts/characters")
	var prefix_total := 0
	for label in CHARACTER_PREFIXES.keys():
		var prefix := str(CHARACTER_PREFIXES[label])
		var count := _count_prefixed_files(character_files, prefix)
		prefix_total += count
		_expect_table_int(brief, str(label), 1, count, "brief character count should match %s" % prefix)
	var shared_count := character_files.size() - prefix_total
	_expect_table_int(
		brief,
		"Shared/generic player/runtime-perk surface",
		1,
		shared_count,
		"brief shared character count should match non-prefixed character scripts"
	)


func _verify_lingpet_coverage(brief: String, ledger: String) -> void:
	var lingpet_files := _collect_gd_files("res://scripts/lingpet")
	_expect_contains(
		brief,
		"Current module count: %d `.gd` files under `godot/scripts/lingpet/`." % lingpet_files.size(),
		"brief Lingpet module-count sentence should match the worktree"
	)
	var missing := _missing_ledger_paths(ledger, lingpet_files)
	_expect(
		missing.is_empty(),
		"Lingpet ownership ledger missing current scripts: %s" % _join_strings(missing, ", ")
	)
	_expect_contains(
		brief,
		"Ownership coverage: 0 current Lingpet `.gd` files missing from",
		"brief should state zero current Lingpet ownership gaps"
	)


func _read_text(path: String) -> String:
	var candidates: Array[String] = [path]
	if path.begins_with("res://"):
		candidates.append(ProjectSettings.globalize_path(path))
	for candidate in candidates:
		var candidate_path := str(candidate)
		if FileAccess.file_exists(candidate_path):
			return FileAccess.get_file_as_string(candidate_path).replace("\r\n", "\n")
	return ""


func _collect_gd_files(root_path: String) -> Array[String]:
	var results: Array[String] = []
	var dir := DirAccess.open(root_path)
	if dir == null:
		return results
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var path := "%s/%s" % [root_path, entry]
		if dir.current_is_dir():
			results.append_array(_collect_gd_files(path))
		elif entry.ends_with(".gd"):
			results.append(path)
		entry = dir.get_next()
	dir.list_dir_end()
	results.sort()
	return results


func _count_direct_gd_files(root_path: String) -> int:
	var dir := DirAccess.open(root_path)
	if dir == null:
		return 0
	var count := 0
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with(".") and not dir.current_is_dir() and entry.ends_with(".gd"):
			count += 1
		entry = dir.get_next()
	dir.list_dir_end()
	return count


func _count_smoke_files(paths: Array[String]) -> int:
	var count := 0
	for path in paths:
		if str(path).ends_with("_smoke.gd"):
			count += 1
	return count


func _count_prefixed_files(paths: Array[String], prefix: String) -> int:
	var count := 0
	for path in paths:
		if str(path).get_file().begins_with(prefix):
			count += 1
	return count


func _missing_ledger_paths(ledger: String, paths: Array[String]) -> Array[String]:
	var missing: Array[String] = []
	for path in paths:
		var ledger_path := str(path).replace("res://", "")
		if ledger.find(ledger_path) < 0:
			missing.append(ledger_path)
	missing.sort()
	return missing


func _expect_table_int(source: String, first_cell: String, cell_index: int, expected: int, message: String) -> void:
	var actual := _table_int_for_first_cell(source, first_cell, cell_index)
	_expect(actual == expected, "%s (expected %d, found %d)" % [message, expected, actual])


func _table_int_for_first_cell(source: String, first_cell: String, cell_index: int) -> int:
	for raw_line in source.split("\n"):
		var cells := _split_table_cells(str(raw_line))
		if cells.size() <= cell_index:
			continue
		if str(cells[0]) != first_cell:
			continue
		var value := str(cells[cell_index])
		if value.is_valid_int():
			return int(value)
	return -1


func _split_table_cells(line: String) -> Array[String]:
	var trimmed := line.strip_edges()
	if not trimmed.begins_with("|") or not trimmed.ends_with("|"):
		return []
	var inner := trimmed.substr(1, trimmed.length() - 2)
	var cells: Array[String] = []
	for raw_cell in inner.split("|"):
		cells.append(str(raw_cell).strip_edges())
	return cells


func _expect_contains(source: String, needle: String, message: String) -> void:
	_expect(source.find(needle) >= 0, "%s: %s" % [message, needle])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true


func _join_strings(values: Array[String], delimiter: String) -> String:
	var output := ""
	for index in range(values.size()):
		if index > 0:
			output += delimiter
		output += values[index]
	return output
