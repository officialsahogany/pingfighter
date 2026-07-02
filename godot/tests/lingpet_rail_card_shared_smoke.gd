extends SceneTree

# Verifies the shared LingpetRailCard helper (build_entry / append_entry /
# tooltip_info / is_lingpet_skill) and that ALL SIX stages' boss skill-card
# rails wire the hatched lingpet card through it (the companion persists across
# every stage, so its card must ride every stage's rail, not just Stage 1).
# Stage 6 (Tetriser) was the original omission this guard now seals: it shipped
# without the append_entry call, so the lingpet card never appeared and its
# left-to-right cooldown wipe never animated on Stage 6.

const LingpetRailCard := preload("res://scripts/stages/common/lingpet_rail_card.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _failures: Array[String] = []


class FakeLingpetRuntime:
	extends RefCounted

	var active := true
	var snapshot := {}
	var rail_surface := {}
	var snapshot_calls := 0
	var rail_surface_calls := 0

	func is_companion_active(_pet_id: String = "") -> bool:
		return active

	func is_maribo_companion_active() -> bool:
		return active

	func get_rail_card_surface() -> Dictionary:
		rail_surface_calls += 1
		return rail_surface

	func get_snapshot() -> Dictionary:
		snapshot_calls += 1
		return snapshot


class FakeRegistry:
	extends RefCounted

	var runtime: Object = null

	func get_instance(key: String) -> Object:
		if key == "lingpet_egg_runtime":
			return runtime
		return null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_is_lingpet_skill()
	_verify_catalog_active_skill_index()
	_verify_rail_card_surface_matches_snapshot()
	_verify_build_entry_states()
	_verify_build_entry_inactive_is_empty()
	_verify_build_entries_second_active_slot()
	_verify_append_entry_forces_active_flag()
	_verify_append_entry_noop_when_inactive()
	_verify_append_entry_appends_both_active_slots()
	_verify_tooltip_info()
	_verify_all_stage_rails_wire_shared_helper()
	_seed_lingpet_skillcard_texture_cache()
	_verify_staged_prewarm()
	_verify_prewarm_registered()

	for _cleanup_frame in range(4):
		LingpetRailCard.clear_caches()
		ProjectResourceLoader.clear_caches()
		await process_frame
	if _failures.is_empty():
		print("lingpet_rail_card_shared_smoke: ok")
		call_deferred("_quit_with_code", 0)
	else:
		for failure in _failures:
			push_error(failure)
		call_deferred("_quit_with_code", 1)


func _quit_with_code(exit_code: int) -> void:
	await process_frame
	quit(exit_code)


func _make_runtime(active: bool, cooldown: float, ready: bool, projectile: bool, puddle: bool, winding_up: bool, flash: float = 0.0) -> FakeLingpetRuntime:
	var runtime := FakeLingpetRuntime.new()
	runtime.active = active
	runtime.snapshot = {
		"companion_skill_id": "maribo_hydro_sphere" if active else "",
		"companion_skill_name": "하이드로 스피어",
		"companion_skill_description": "물의 기운이 담긴 창을 던집니다.",
		"companion_skill_card_path": "res://assets/sprites/lingpet/maribo_hydro_sphere_skillcard_imagegen_v2.png",
		"companion_skill_cooldown": cooldown,
		"companion_skill_cooldown_duration": 40.0,
		"companion_skill_ready": ready,
		"companion_skill_flash_ratio": flash,
		"companion_skill_winding_up": winding_up,
		"hydro_sphere_projectile_active": projectile,
		"hydro_sphere_puddle_active": puddle,
		"headbutt_active": false,
		"headbutt_impact_active": false,
		"headbutt_miss_active": false,
		"headbutt_repeat_wait_active": false,
	}
	return runtime


func _make_registry(runtime: Object) -> FakeRegistry:
	var registry := FakeRegistry.new()
	registry.runtime = runtime
	return registry


# 모락모랑/rabi-style dual-active snapshot: slot 0 = soul_clone (52s), slot 1 =
# ghost_summon (40s). The per-effect "active" flag drives per-slot casting.
func _make_dual_runtime(primary_soul_clone_active: bool, second_ghost_summon_active: bool) -> FakeLingpetRuntime:
	var runtime := FakeLingpetRuntime.new()
	runtime.active = true
	runtime.snapshot = {
		"companion_skill_id": "rabi_soul_clone",
		"companion_skill_name": "영혼분신",
		"companion_skill_description": "영혼 분신을 소환합니다.",
		"companion_skill_card_path": "res://assets/sprites/lingpet/lunabi_headbutt_skillcard_imagegen_v1.png",
		"companion_skill_cooldown": 18.2,
		"companion_skill_cooldown_duration": 52.0,
		"companion_skill_ready": false,
		"companion_skill_flash_ratio": 0.0,
		"companion_skill_winding_up": false,
		"soul_clone_active": primary_soul_clone_active,
		"companion_skill_id_1": "rabi_ghost_summon",
		"companion_skill_name_1": "유령소환",
		"companion_skill_description_1": "유령 패들을 소환합니다.",
		"companion_skill_card_path_1": "res://assets/sprites/lingpet/lunabi_headbutt_skillcard_imagegen_v1.png",
		"companion_skill_cooldown_1": 30.0,
		"companion_skill_cooldown_duration_1": 40.0,
		"companion_skill_ready_1": false,
		"companion_skill_flash_ratio_1": 0.0,
		"companion_skill_winding_up_1": false,
		"ghost_summon_active": second_ghost_summon_active,
	}
	return runtime


func _verify_is_lingpet_skill() -> void:
	_expect(LingpetRailCard.is_lingpet_skill({"is_lingpet": true}), "is_lingpet_skill should detect the is_lingpet flag")
	_expect(LingpetRailCard.is_lingpet_skill({"id": "maribo_hydro_sphere"}), "is_lingpet_skill should detect the maribo skill id")
	_expect(LingpetRailCard.is_lingpet_skill({"id": "lunabi_headbutt"}), "is_lingpet_skill should detect the Lunabi skill id through the catalog")
	_expect(not LingpetRailCard.is_lingpet_skill({"id": "whip"}), "is_lingpet_skill should reject boss skills")


func _verify_catalog_active_skill_index() -> void:
	var catalog_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_catalog.gd")
	var rail_source := FileAccess.get_file_as_string("res://scripts/stages/common/lingpet_rail_card.gd")
	var get_body := _function_body(catalog_source, "static func get_active_skill_entry(")
	var has_body := _function_body(catalog_source, "static func has_active_skill_entry(")
	var index_body := _function_body(catalog_source, "static func _build_active_skill_id_index(")
	var rail_lingpet_body := _function_body(rail_source, "static func is_lingpet_skill(")

	_expect(catalog_source.find("static var _active_skill_id_index") >= 0, "catalog should keep a static active-skill id index")
	_expect(get_body.find("_get_active_skill_id_index().get") >= 0, "get_active_skill_entry should read the indexed catalog entry")
	_expect(get_body.find("duplicate(true)") >= 0, "get_active_skill_entry should keep returning a mutation-safe deep copy")
	_expect(get_body.find("get_active_skill_entry_from_entries") < 0, "get_active_skill_entry should not fall back to the per-call full scan")
	_expect(has_body.find("_get_active_skill_id_index().has") >= 0, "has_active_skill_entry should use an O(1) index membership check")
	_expect(has_body.find("_normalize_skill_pool") < 0 and has_body.find("_get_active_skill_pool_from_entry") < 0, "has_active_skill_entry miss path must not normalize active skill pools")
	_expect(index_body.find("_normalize_skill_pool") < 0 and index_body.find("duplicate(true)") < 0, "active-skill id index should store PETS skill references without one-time deep-copy churn")
	_expect(rail_lingpet_body.find("has_active_skill_entry") >= 0, "is_lingpet_skill should use catalog membership, not metadata lookup")
	_expect(rail_lingpet_body.find("get_active_skill_entry") < 0, "is_lingpet_skill boss-card miss path should not duplicate catalog entries")
	_expect(not LingpetCatalog.has_active_skill_entry("whip"), "catalog index should reject a non-lingpet boss skill id")
	_expect(LingpetCatalog.get_active_skill_entry("whip").is_empty(), "catalog metadata lookup should still return empty for non-lingpet ids")

	var checked_ids: Dictionary = {}
	for raw_pet_id in LingpetCatalog.PETS.keys():
		for active_skill in LingpetCatalog.get_active_skill_pool(str(raw_pet_id)):
			var skill_id := str(active_skill.get("id", "")).strip_edges()
			if skill_id == "" or checked_ids.has(skill_id):
				continue
			checked_ids[skill_id] = true
			var indexed := LingpetCatalog.get_active_skill_entry("  %s  " % skill_id.to_upper())
			var scanned := LingpetCatalog.get_active_skill_entry_from_entries(LingpetCatalog.PETS, skill_id)
			_expect(_dictionary_equal(indexed, scanned), "indexed active skill metadata should match the legacy scan for %s" % skill_id)
			var original_runtime_kind := str(indexed.get("runtime_kind", ""))
			indexed["runtime_kind"] = "__mutated_by_smoke__"
			_expect(str(LingpetCatalog.get_active_skill_entry(skill_id).get("runtime_kind", "")) == original_runtime_kind, "indexed active skill lookup should return a copy for %s" % skill_id)


func _verify_rail_card_surface_matches_snapshot() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var host_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_skill_runtime_host.gd")
	var rail_source := FileAccess.get_file_as_string("res://scripts/stages/common/lingpet_rail_card.gd")
	var rail_build_body := _function_body(rail_source, "static func build_entries(")
	var surface_body := _function_body(runtime_source, "func _build_rail_card_surface_uncached(")
	_expect(rail_build_body.find("get_rail_card_surface") >= 0, "rail card builder should prefer the narrow rail-card surface")
	_expect(rail_build_body.find("get_snapshot") >= 0, "rail card builder should keep get_snapshot as a fallback for test doubles / legacy runtimes")
	_expect(surface_body.find("_snapshot_builder.build_runtime_snapshot") < 0, "rail-card surface must not build the full runtime snapshot")
	_expect(surface_body.find("_build_runtime_snapshot_uncached") < 0, "rail-card surface must not call the full snapshot builder")
	_expect(surface_body.find("_merge_rail_card_skill_runtime_snapshot") >= 0, "rail-card surface should merge only mounted skill runtime snapshots")
	_expect(host_source.find("func get_snapshot_for_skill_id") >= 0 and host_source.find("func _peek_skill_for_kind") >= 0, "skill runtime host should support non-instantiating per-skill snapshot lookup")

	var cases := [
		{
			"name": "charging",
			"snapshot": _make_runtime(true, 20.0, false, false, false, false).snapshot,
		},
		{
			"name": "ready",
			"snapshot": _make_runtime(true, 0.0, true, false, false, false).snapshot,
		},
		{
			"name": "casting",
			"snapshot": _make_runtime(true, 30.0, false, true, false, false).snapshot,
		},
		{
			"name": "flash",
			"snapshot": _make_runtime(true, 12.0, false, false, false, false, 0.75).snapshot,
		},
		{
			"name": "dual_slot",
			"snapshot": _make_dual_runtime(false, true).snapshot,
		},
	]
	for test_case in cases:
		var snapshot: Dictionary = test_case.get("snapshot", {})
		var snapshot_runtime := FakeLingpetRuntime.new()
		snapshot_runtime.active = true
		snapshot_runtime.snapshot = snapshot
		var snapshot_entries := LingpetRailCard.build_entries(_make_registry(snapshot_runtime))

		var surface_runtime := FakeLingpetRuntime.new()
		surface_runtime.active = true
		surface_runtime.snapshot = snapshot
		surface_runtime.rail_surface = _rail_surface_from_snapshot(snapshot)
		var surface_entries := LingpetRailCard.build_entries(_make_registry(surface_runtime))
		_expect(_entry_arrays_equal(surface_entries, snapshot_entries), "rail-card surface entries should match full snapshot entries for %s" % str(test_case.get("name", "")))
		_expect(surface_runtime.rail_surface_calls == 1, "rail-card surface should be read once for %s" % str(test_case.get("name", "")))
		_expect(surface_runtime.snapshot_calls == 0, "rail-card surface path should not call get_snapshot for %s" % str(test_case.get("name", "")))

	var fallback_runtime := FakeLingpetRuntime.new()
	fallback_runtime.active = true
	fallback_runtime.snapshot = _make_runtime(true, 20.0, false, false, false, false).snapshot
	fallback_runtime.rail_surface = {}
	var fallback_entries := LingpetRailCard.build_entries(_make_registry(fallback_runtime))
	_expect(not fallback_entries.is_empty(), "empty rail surface should fall back to the full snapshot")
	_expect(fallback_runtime.snapshot_calls == 1, "empty rail surface fallback should call get_snapshot once")


func _verify_build_entry_states() -> void:
	# Charging: cooldown remaining, not ready, not casting -> progress < 1.
	var charging := LingpetRailCard.build_entry(_make_registry(_make_runtime(true, 20.0, false, false, false, false)))
	_expect(not charging.is_empty(), "build_entry should produce an entry for an active companion")
	_expect(str(charging.get("id", "")) == "maribo_hydro_sphere", "rail entry id should be maribo_hydro_sphere")
	_expect(bool(charging.get("is_lingpet", false)), "rail entry should carry is_lingpet")
	_expect(charging.get("accent_color", Color.BLACK) == LingpetRailCard.ACCENT, "rail entry accent should be the cyan ally accent")
	_expect(str(charging.get("card_texture_path", "")).ends_with("maribo_hydro_sphere_skillcard_imagegen_v2.png"), "rail entry should carry the catalog-backed skill-card texture path")
	_expect(not str(charging.get("description", "")).is_empty(), "rail entry should carry the companion skill description for tooltip paths")
	_expect(str(charging.get("status", "")) == "charging", "remaining cooldown should read as charging")
	_expect(absf(float(charging.get("progress", -1.0)) - 0.5) <= 0.01, "progress should be 1 - cooldown/duration (20/40 -> 0.5)")

	# Ready: cooldown 0, ready, not casting.
	var ready := LingpetRailCard.build_entry(_make_registry(_make_runtime(true, 0.0, true, false, false, false)))
	_expect(str(ready.get("status", "")) == "ready", "zero cooldown + ready should read as ready")
	_expect(absf(float(ready.get("progress", -1.0)) - 1.0) <= 0.01, "ready entry progress should be full")

	# Casting: winding up overrides to casting even before the projectile launches.
	var windup := LingpetRailCard.build_entry(_make_registry(_make_runtime(true, 0.0, true, false, false, true)))
	_expect(str(windup.get("status", "")) == "casting", "wind-up should read as casting on the rail card")
	var projectile := LingpetRailCard.build_entry(_make_registry(_make_runtime(true, 30.0, false, true, false, false)))
	_expect(str(projectile.get("status", "")) == "casting", "an in-flight hydro projectile should read as casting")

	var lunabi_runtime := FakeLingpetRuntime.new()
	lunabi_runtime.active = true
	lunabi_runtime.snapshot = {
		"companion_skill_id": "lunabi_headbutt",
		"companion_skill_name": "박치기",
		"companion_skill_description": "달벳이 상대 패들을 향해 돌진합니다.",
		"companion_skill_card_path": "res://assets/sprites/lingpet/lunabi_headbutt_skillcard_imagegen_v1.png",
		"companion_skill_cooldown": 12.0,
		"companion_skill_cooldown_duration": 30.0,
		"companion_skill_ready": false,
		"companion_skill_flash_ratio": 0.0,
		"companion_skill_winding_up": false,
		"headbutt_active": true,
		"headbutt_impact_active": false,
		"headbutt_miss_active": false,
		"headbutt_repeat_wait_active": false,
	}
	var lunabi_entry := LingpetRailCard.build_entry(_make_registry(lunabi_runtime))
	_expect(str(lunabi_entry.get("id", "")) == "lunabi_headbutt", "rail entry should support Lunabi Headbutt")
	_expect(str(lunabi_entry.get("status", "")) == "casting", "an active Lunabi Headbutt dash should read as casting")
	_expect(absf(float(lunabi_entry.get("cooldown_total", 0.0)) - 30.0) <= 0.01, "Lunabi rail entry should carry its 30s cooldown")
	_expect(str(lunabi_entry.get("card_texture_path", "")).ends_with("lunabi_headbutt_skillcard_imagegen_v1.png"), "Lunabi rail entry should carry the imagegen skill-card texture path")
	lunabi_runtime.snapshot["headbutt_active"] = false
	lunabi_runtime.snapshot["headbutt_repeat_wait_active"] = true
	var lunabi_repeat_wait_entry := LingpetRailCard.build_entry(_make_registry(lunabi_runtime))
	_expect(str(lunabi_repeat_wait_entry.get("status", "")) == "casting", "Lunabi Headbutt repeat wait should stay in casting state on the rail card")

	# Ghost Summon (rabi): an active summon effect must read as casting, not fall back
	# to charging while the ghosts are still on the field.
	var ghost_runtime := FakeLingpetRuntime.new()
	ghost_runtime.active = true
	ghost_runtime.snapshot = {
		"companion_skill_id": "rabi_ghost_summon",
		"companion_skill_name": "유령 소환",
		"companion_skill_description": "모락모랑이 유령들을 소환합니다.",
		"companion_skill_card_path": "res://assets/sprites/lingpet/lunabi_headbutt_skillcard_imagegen_v1.png",
		"companion_skill_cooldown": 30.0,
		"companion_skill_cooldown_duration": 40.0,
		"companion_skill_ready": false,
		"companion_skill_flash_ratio": 0.0,
		"companion_skill_winding_up": false,
		"ghost_summon_active": true,
	}
	var ghost_entry := LingpetRailCard.build_entry(_make_registry(ghost_runtime))
	_expect(str(ghost_entry.get("status", "")) == "casting", "an active Ghost Summon effect should read as casting on the rail card, not revert to charging")


# A lingpet with a SECOND unlocked active slot (e.g. 모락모랑/rabi with
# soul_clone + ghost_summon) must show BOTH cards on the rail, and each card's
# casting state must be independent of the other slot. This is the reported bug:
# only the slot-0 card appeared even though the character-info panel showed two
# active skills.
func _verify_build_entries_second_active_slot() -> void:
	var registry := _make_registry(_make_dual_runtime(false, true))
	var entries := LingpetRailCard.build_entries(registry)
	_expect(entries.size() == 2, "build_entries should emit one card per live active slot (2 when a second active is unlocked)")
	if entries.size() == 2:
		var primary: Dictionary = entries[0]
		var second: Dictionary = entries[1]
		_expect(str(primary.get("id", "")) == "rabi_soul_clone", "first rail entry should be the slot-0 active skill")
		_expect(str(second.get("id", "")) == "rabi_ghost_summon", "second rail entry should be the slot-1 active skill")
		_expect(absf(float(primary.get("cooldown_total", 0.0)) - 52.0) <= 0.01, "primary entry should carry its own 52s cooldown")
		_expect(absf(float(second.get("cooldown_total", 0.0)) - 40.0) <= 0.01, "second entry should carry its own 40s cooldown")
		_expect(str(second.get("label", "")) == "유령소환", "second entry should carry the slot-1 skill name")
		_expect(str(second.get("card_texture_path", "")).ends_with(".png"), "second entry should carry the slot-1 skill-card texture path")
		# Per-slot casting independence: an active slot-1 effect must NOT full-fill
		# the slot-0 card (draw_card sets fill_ratio = 1.0 whenever status == casting).
		_expect(str(primary.get("status", "")) == "charging", "slot-0 card must stay charging while only slot-1 is casting")
		_expect(str(second.get("status", "")) == "casting", "slot-1 card should read casting when its own effect is active")
		_expect(absf(float(primary.get("progress", -1.0)) - 0.65) <= 0.02, "primary progress should reflect its own cooldown (18.2/52 -> ~0.65)")
	# build_entry() (single) must still return ONLY the primary card for legacy callers.
	_expect(str(LingpetRailCard.build_entry(registry).get("id", "")) == "rabi_soul_clone", "build_entry should still return only the primary slot-0 card")
	# Mirror direction: slot-0 casting, slot-1 charging -> only the primary reads casting.
	var mirror := LingpetRailCard.build_entries(_make_registry(_make_dual_runtime(true, false)))
	_expect(mirror.size() == 2, "build_entries should still emit two cards in the mirror casting case")
	if mirror.size() == 2:
		_expect(str((mirror[0] as Dictionary).get("status", "")) == "casting", "slot-0 card reads casting when its own effect is active")
		_expect(str((mirror[1] as Dictionary).get("status", "")) == "charging", "slot-1 card stays charging while only slot-0 casts")


func _verify_build_entry_inactive_is_empty() -> void:
	_expect(LingpetRailCard.build_entry(_make_registry(_make_runtime(false, 0.0, false, false, false, false))).is_empty(), "build_entry should be empty when the companion is not active (pre-hatch mystery)")
	_expect(LingpetRailCard.build_entry(_make_registry(null)).is_empty(), "build_entry should be empty when no lingpet runtime is registered")
	_expect(LingpetRailCard.build_entry(null).is_empty(), "build_entry should be empty for a null registry")


func _verify_append_entry_forces_active_flag() -> void:
	var registry := _make_registry(_make_runtime(true, 0.0, true, false, false, false))
	var context := {"stage9_boss_skill_hud_skills": [{"id": "boss_a"}], "stage9_boss_skill_hud_active": false}
	LingpetRailCard.append_entry(context, registry, "stage9_boss_skill_hud_skills", "stage9_boss_skill_hud_active")
	var skills: Array = context.get("stage9_boss_skill_hud_skills", [])
	_expect(skills.size() == 2, "append_entry should append the lingpet entry to the rail array")
	_expect(str((skills[1] as Dictionary).get("id", "")) == "maribo_hydro_sphere", "appended entry should be the lingpet card")
	_expect(bool(context.get("stage9_boss_skill_hud_active", false)), "append_entry MUST force the rail active flag true (renderers early-return on a false flag)")
	# Must not mutate the caller's original array reference in place.
	_expect(skills.size() == 2, "append_entry should write a fresh duplicated array")


func _verify_append_entry_noop_when_inactive() -> void:
	var registry := _make_registry(_make_runtime(false, 0.0, false, false, false, false))
	var context := {"stage9_boss_skill_hud_skills": [{"id": "boss_a"}], "stage9_boss_skill_hud_active": false}
	LingpetRailCard.append_entry(context, registry, "stage9_boss_skill_hud_skills", "stage9_boss_skill_hud_active")
	_expect((context.get("stage9_boss_skill_hud_skills", []) as Array).size() == 1, "append_entry should be a no-op when the companion is not active")
	_expect(not bool(context.get("stage9_boss_skill_hud_active", true)), "append_entry should NOT force the active flag when there is no lingpet entry")


func _verify_append_entry_appends_both_active_slots() -> void:
	var context := {"stage9_boss_skill_hud_skills": [{"id": "boss_a"}], "stage9_boss_skill_hud_active": false}
	LingpetRailCard.append_entry(context, _make_registry(_make_dual_runtime(false, true)), "stage9_boss_skill_hud_skills", "stage9_boss_skill_hud_active")
	var skills: Array = context.get("stage9_boss_skill_hud_skills", [])
	_expect(skills.size() == 3, "append_entry should append BOTH lingpet cards after the boss skill (1 boss + 2 lingpet)")
	if skills.size() == 3:
		_expect(str((skills[1] as Dictionary).get("id", "")) == "rabi_soul_clone", "first appended lingpet card is slot 0")
		_expect(str((skills[2] as Dictionary).get("id", "")) == "rabi_ghost_summon", "second appended lingpet card is slot 1")
	_expect(bool(context.get("stage9_boss_skill_hud_active", false)), "append_entry MUST force the rail active flag true for the dual-slot case too")


func _verify_tooltip_info() -> void:
	var info := LingpetRailCard.tooltip_info()
	_expect(str(info.get("name", "")) == "하이드로 스피어", "tooltip should name the Hydro Sphere skill")
	_expect(absf(float(info.get("cooldown_seconds", 0.0)) - 40.0) <= 0.01, "tooltip should expose cooldown_seconds 40 (stage1/4 + shared spec)")
	_expect(not str(info.get("cooldown", "")).is_empty(), "tooltip should expose a cooldown string (stage5 own tooltip reads it)")
	_expect(not str(info.get("description", "")).is_empty(), "tooltip should expose a description")
	var future_skill_info := LingpetRailCard.tooltip_info({
		"id": "test_bubble_guard",
		"is_lingpet": true,
		"label": "Bubble Guard",
		"trigger_label": "Auto",
		"cooldown_total": 18.0,
		"description": "Future lingpet tooltip copy",
	})
	_expect(str(future_skill_info.get("name", "")) == "Bubble Guard", "tooltip should use the live lingpet card label, not the Maribo fallback")
	_expect(str(future_skill_info.get("trigger", "")) == "Auto", "tooltip should use the live lingpet trigger label")
	_expect(absf(float(future_skill_info.get("cooldown_seconds", 0.0)) - 18.0) <= 0.01, "tooltip should use the live lingpet skill cooldown")
	_expect(str(future_skill_info.get("description", "")) == "Future lingpet tooltip copy", "tooltip should use the live lingpet skill description")
	var lunabi_info := LingpetRailCard.tooltip_info({
		"id": "lunabi_headbutt",
		"is_lingpet": true,
		"label": "박치기",
		"trigger_label": "자동",
		"cooldown_total": 30.0,
		"description": "달벳이 돌진합니다.",
	})
	_expect(str(lunabi_info.get("name", "")) == "박치기", "tooltip should use the live Lunabi Headbutt label")
	_expect(absf(float(lunabi_info.get("cooldown_seconds", 0.0)) - 30.0) <= 0.01, "tooltip should expose Lunabi Headbutt's 30s cooldown")


func _verify_all_stage_rails_wire_shared_helper() -> void:
	# Each stage's boss-skill HUD composition must append via the shared helper with
	# its own rail keys, and each renderer must delegate the lingpet card to the helper.
	var stages := [
		{
			"drawer": "res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd",
			"renderer": "res://scripts/stages/stage1/stage1_dalji_boss_skill_hud_renderer.gd",
			"skills_key": "stage1_dalji_boss_skill_hud_skills",
			"active_key": "stage1_dalji_boss_skill_hud_active",
		},
		{
			"drawer": "res://scripts/stages/stage2/stage2_pillar_scene_drawer.gd",
			"renderer": "res://scripts/stages/stage2/stage2_boss_skill_hud_renderer.gd",
			"skills_key": "stage2_boss_skill_hud_skills",
			"active_key": "stage2_boss_skill_hud_active",
		},
		{
			"drawer": "res://scripts/stages/stage3/stage3_pillar_scene_drawer.gd",
			"renderer": "res://scripts/stages/stage3/stage3_boss_skill_hud_renderer.gd",
			"skills_key": "stage3_boss_skill_hud_skills",
			"active_key": "stage3_boss_skill_hud_active",
		},
		{
			"drawer": "res://scripts/stages/stage4/stage4_pillar_scene_drawer.gd",
			"renderer": "res://scripts/stages/stage4/stage4_ponk_boss_skill_hud_renderer.gd",
			"skills_key": "stage4_ponk_boss_skill_hud_skills",
			"active_key": "stage4_ponk_boss_skill_hud_active",
		},
		{
			"drawer": "res://scripts/stages/stage5/stage5_hongryun_pillar_scene_drawer.gd",
			"renderer": "res://scripts/stages/stage5/stage5_hongryun_boss_skill_hud_renderer.gd",
			"skills_key": "stage5_boss_skill_hud_skills",
			"active_key": "stage5_boss_skill_hud_active",
		},
		{
			"drawer": "res://scripts/stages/stage6/stage6_tetriser_pillar_scene_drawer.gd",
			"renderer": "res://scripts/stages/stage6/stage6_tetriser_boss_skill_hud_renderer.gd",
			"skills_key": "stage6_boss_skill_hud_skills",
			"active_key": "stage6_boss_skill_hud_active",
		},
	]
	var router_source: String = FileAccess.get_file_as_string("res://scripts/stages/stage_runtime_router.gd")
	_expect(router_source.find("\"pillar_scene_drawer\": \"stage5_hongryun_pillar_scene_drawer\"") >= 0, "Stage 5 live router should use the Hongryun pillar drawer covered by this test")
	for stage in stages:
		var drawer_source: String = FileAccess.get_file_as_string(str(stage["drawer"]))
		_expect(drawer_source.find("lingpet_rail_card.gd") >= 0, "%s should preload the shared lingpet rail card helper" % str(stage["drawer"]))
		_expect(drawer_source.find("append_entry(") >= 0, "%s should append the lingpet card via the shared helper" % str(stage["drawer"]))
		_expect(drawer_source.find("\"%s\"" % str(stage["skills_key"])) >= 0, "%s should pass its boss rail skills key %s" % [str(stage["drawer"]), str(stage["skills_key"])])
		_expect(drawer_source.find("\"%s\"" % str(stage["active_key"])) >= 0, "%s should pass its boss rail active-flag key %s" % [str(stage["drawer"]), str(stage["active_key"])])
		var renderer_source: String = FileAccess.get_file_as_string(str(stage["renderer"]))
		_expect(renderer_source.find("LingpetRailCard") >= 0, "%s should reference the shared LingpetRailCard helper" % str(stage["renderer"]))
		_expect(renderer_source.find("is_lingpet_skill") >= 0, "%s should delegate the lingpet entry via is_lingpet_skill" % str(stage["renderer"]))


func _verify_prewarm_registered() -> void:
	var controller_source: String = FileAccess.get_file_as_string("res://scripts/core/battle_boot_resource_prewarm_controller.gd")
	_expect(controller_source.find("LingpetRailCard.prewarm_step()") >= 0, "boot prewarm controller should stage the lingpet rail card texture load (no hot-path lazy load on any stage)")


func _verify_staged_prewarm() -> void:
	_expect(not bool(LingpetRailCard.prewarm_step()), "first lingpet rail card prewarm step should only build the path list")
	var guard := 0
	var max_steps: int = max(80, _expected_lingpet_skillcard_path_count() * 8 + 8)
	while not bool(LingpetRailCard.prewarm_step()) and guard < max_steps:
		guard += 1
	_expect(guard < max_steps, "lingpet rail card staged prewarm should complete within a bounded number of steps")
	var source: String = FileAccess.get_file_as_string("res://scripts/stages/common/lingpet_rail_card.gd")
	_expect(source.find("prewarm_texture_threaded_step") >= 0, "lingpet rail card prewarm should use the threaded texture path")


func _expected_lingpet_skillcard_path_count() -> int:
	return _expected_lingpet_skillcard_paths().size()


func _seed_lingpet_skillcard_texture_cache() -> void:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.9, 1.0, 1.0))
	var texture := ImageTexture.create_from_image(image)
	for card_path in _expected_lingpet_skillcard_paths():
		ProjectResourceLoader.store_texture(card_path, texture)


func _expected_lingpet_skillcard_paths() -> Array[String]:
	var seen: Dictionary = {}
	var paths: Array[String] = []
	_append_expected_lingpet_skillcard_path(str(LingpetRailCard.TEXTURE_PATH), seen, paths)
	for pet_id in LingpetCatalog.get_pet_ids(true):
		for active_skill in LingpetCatalog.get_active_skill_pool(str(pet_id)):
			if not bool(active_skill.get("enabled", true)):
				continue
			_append_expected_lingpet_skillcard_path(str(active_skill.get("card_texture_path", "")), seen, paths)
	return paths


func _append_expected_lingpet_skillcard_path(path: String, seen: Dictionary, paths: Array[String]) -> void:
	var resolved_path := path.strip_edges()
	if resolved_path == "":
		return
	if seen.has(resolved_path):
		return
	seen[resolved_path] = true
	paths.append(resolved_path)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_func := source.find("\nfunc ", start + signature.length())
	var next_static_func := source.find("\nstatic func ", start + signature.length())
	if next_func < 0 or (next_static_func >= 0 and next_static_func < next_func):
		next_func = next_static_func
	if next_func < 0:
		return source.substr(start)
	return source.substr(start, next_func - start)


func _dictionary_equal(left: Dictionary, right: Dictionary) -> bool:
	if left.size() != right.size():
		return false
	for key in left.keys():
		if not right.has(key):
			return false
		if left[key] != right[key]:
			return false
	return true


func _entry_arrays_equal(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	for i in range(left.size()):
		if not (left[i] is Dictionary) or not (right[i] is Dictionary):
			return false
		if not _dictionary_equal(left[i] as Dictionary, right[i] as Dictionary):
			return false
	return true


func _rail_surface_from_snapshot(snapshot: Dictionary) -> Dictionary:
	var surface: Dictionary = {}
	for key in snapshot.keys():
		var key_text := str(key)
		if key_text.begins_with("companion_skill_") or _is_rail_casting_flag_key(key_text):
			surface[key] = snapshot[key]
	return surface


func _is_rail_casting_flag_key(key: String) -> bool:
	return key in [
		"hydro_sphere_projectile_active",
		"hydro_sphere_puddle_active",
		"headbutt_active",
		"headbutt_impact_active",
		"headbutt_miss_active",
		"headbutt_repeat_wait_active",
		"moon_orbit_projectile_active",
		"moon_orbit_field_active",
		"bubble_trap_projectile_active",
		"bubble_trap_capture_active",
		"thunder_orb_projectile_active",
		"thunder_orb_explosion_active",
		"thunder_orb_electric_stun_active",
		"solar_bolt_active",
		"solar_bolt_refire_pending",
		"solar_bolt_vfx_active",
		"soul_clone_active",
		"ghost_summon_active",
		"star_coil_active",
		"star_coil_visible",
		"gravity_accel_active",
		"gravity_accel_field_active",
		"sand_prison_active",
	]


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
