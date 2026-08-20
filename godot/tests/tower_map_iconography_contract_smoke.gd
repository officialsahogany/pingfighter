extends SceneTree

const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)
const TowerAscentMapIconography := preload(
	"res://scripts/tower_ascent/tower_ascent_map_iconography.gd"
)
const TowerAscentBossRegistry := preload(
	"res://scripts/tower_ascent/tower_ascent_boss_registry.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const NONCOMBAT_ICON_CASES := [
	{"kind": "shop", "filename": "node_shop_imagegen_v1.png"},
	{"kind": "training", "filename": "node_training_imagegen_v1.png"},
	{"kind": "fallen_monk", "filename": "node_fallen_monk_imagegen_v1.png"},
	{"kind": "guardian_spring", "filename": "node_guardian_spring_imagegen_v1.png"},
	{"kind": "rest", "filename": "node_rest_imagegen_v1.png"},
	{"kind": "map_hint", "filename": "map_hint_imagegen_v1.png"},
]

var _failures: Array[String] = []


func _init() -> void:
	_verify_deterministic_path_contract()
	_verify_promoted_noncombat_icons_hide_names()
	_verify_every_ported_boss_has_one_unique_icon_and_hides_its_name()
	_verify_missing_asset_negative_cache_and_label_fallback()
	_verify_renderer_uses_one_owner_without_preloaded_icons()
	_verify_map_input_consumer_audit_and_top_corner_counterproof()
	if _failures.is_empty():
		print("tower_map_iconography_contract_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_deterministic_path_contract() -> void:
	var iconography := TowerAscentMapIconography.new()
	_expect(
		iconography.resolve_icon_path("shop")
		== "res://assets/sprites/tower/map_icons/node_shop_imagegen_v1.png",
		"shop must resolve through the canonical node icon path"
	)
	_expect(
		iconography.resolve_icon_path("combat", "molewang")
		== "res://assets/sprites/tower/map_icons/boss_molewang_imagegen_v1.png",
		"combat plus boss_id must resolve one deterministic boss path"
	)
	_expect(
		iconography.resolve_icon_path("enraged", "molewang")
		== iconography.resolve_icon_path("combat", "molewang"),
		"enraged state must preserve the boss identity icon"
	)
	_expect(
		iconography.resolve_boss_id_for_node({"boss_slot_id": "floor_03_teddy_bear"})
		== "teddy_bear",
		"the registry slot adapter must preserve the unique visual boss identity"
	)
	_expect(
		iconography.resolve_boss_id_for_node({
			"boss_slot_id": "floor_04_shell_02",
			"standin": {"stage": 4, "boss_id": "ponk"},
		}) == "ponk",
		"shell slots must render the approved icon for their actual stand-in identity"
	)
	_expect(
		iconography.resolve_icon_path("combat", "../unsafe").is_empty(),
		"unsafe identifiers must fail closed instead of escaping the icon root"
	)


func _verify_promoted_noncombat_icons_hide_names() -> void:
	var iconography := TowerAscentMapIconography.new()
	for case_variant in NONCOMBAT_ICON_CASES:
		var case: Dictionary = case_variant
		var kind := str(case.get("kind", ""))
		var expected_path := "%s/%s" % [
			TowerAscentMapIconography.ICON_ROOT,
			str(case.get("filename", "")),
		]
		var presentation := iconography.resolve_presentation(kind, "", "stale name")
		_expect(
			str(presentation.get("icon_path", "")) == expected_path,
			"%s must resolve its approved runtime filename" % kind
		)
		_expect_promoted_texture(presentation, kind)
		_expect(
			str(presentation.get("fallback_label", "")).is_empty(),
			"%s must replace the name string when its approved icon exists" % kind
		)


func _verify_every_ported_boss_has_one_unique_icon_and_hides_its_name() -> void:
	var renderer := TowerAscentFlowRenderer.new()
	var boss_registry := TowerAscentBossRegistry.new()
	var seen_icon_paths: Dictionary = {}
	var ported_count := 0
	for floor_number_variant in TowerAscentBossRegistry.FLOOR_BOSS_SLOTS:
		var floor_number := int(floor_number_variant)
		for slot_variant in TowerAscentBossRegistry.FLOOR_BOSS_SLOTS[floor_number]:
			var slot: Dictionary = slot_variant
			if str(slot.get("status", "")) != TowerAscentBossRegistry.STATUS_PORTED:
				continue
			ported_count += 1
			var slot_id := str(slot.get("slot_id", ""))
			var display_name := str(slot.get("display_name", ""))
			var presentation := renderer.build_map_icon_presentation({
				"kind": "combat",
				"label": display_name,
				"boss_slot_id": slot_id,
				"standin": boss_registry.get_standin(slot_id),
			})
			var icon_path := str(presentation.get("icon_path", ""))
			_expect(not seen_icon_paths.has(icon_path), "%s must not share another boss icon" % slot_id)
			seen_icon_paths[icon_path] = true
			_expect_promoted_texture(presentation, slot_id)
			_expect(
				str(presentation.get("fallback_label", "")).is_empty(),
				"%s must hide only its name text while keeping its unique icon" % slot_id
			)
	_expect(ported_count == 14, "the current FLOOR_BOSS_SLOTS contract must expose 14 real bosses")
	_expect(seen_icon_paths.size() == ported_count, "every real boss must own one unique icon path")


func _verify_missing_asset_negative_cache_and_label_fallback() -> void:
	var renderer := TowerAscentFlowRenderer.new()
	var missing_node := {
		"kind": "combat",
		"label": "계약 폴백 보스",
		"boss_slot_id": "floor_99_missing_contract_probe",
	}
	var first: Dictionary = renderer.build_map_icon_presentation(missing_node)
	var second: Dictionary = renderer.build_map_icon_presentation(missing_node)
	var missing_path := str(first.get("icon_path", ""))
	_expect(not missing_path.is_empty(), "the negative leg must resolve a reserved path")
	_expect(not FileAccess.file_exists(missing_path), "the negative leg path must remain absent")
	_expect(first.get("icon_texture", null) == null, "an absent icon must not fabricate a texture")
	_expect(str(first.get("fallback_label", "")) == "계약 폴백 보스", "an absent boss icon must preserve the current label")
	_expect(second == first, "a repeated missing lookup must reuse the cached presentation result")
	var debug_state: Dictionary = renderer.get_map_icon_cache_debug_state()
	var attempts: Dictionary = debug_state.get("load_attempt_by_path", {})
	_expect(int(attempts.get(missing_path, 0)) == 1, "GRT-004: a missing icon path must hit the filesystem exactly once")
	_expect(int(debug_state.get("miss_count", 0)) == 1, "the missing path must occupy one negative-cache entry")

	var shop_model: Dictionary = renderer.build_map_icon_presentation({
		"kind": "shop",
		"label": "stale fixture label",
	})
	_expect(shop_model.get("icon_texture", null) is Texture2D, "the promoted shop icon must load")
	_expect(str(shop_model.get("fallback_label", "")).is_empty(), "a present shop icon must replace its name string")


func _verify_renderer_uses_one_owner_without_preloaded_icons() -> void:
	var owner_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_map_iconography.gd"
	)
	var renderer_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	)
	_expect(owner_source.find("preload(") < 0, "the icon owner must never const-preload reserved art")
	_expect(owner_source.find("ResourceLoader.exists") >= 0 and owner_source.find("ResourceLoader.load") >= 0, "the icon owner must use guarded runtime loading")
	_expect(renderer_source.count("TowerAscentMapIconography.new()") == 1, "the renderer must own exactly one iconography resolver/cache")
	_expect(renderer_source.find("build_map_icon_presentation(node)") >= 0, "the map draw paths must consume the shared presentation contract")
	_expect(
		renderer_source.count('icon_presentation.get("fallback_label", "")') == 2,
		"fullscreen and playfield map paths must both retain the S1 label fallback"
	)


func _verify_map_input_consumer_audit_and_top_corner_counterproof() -> void:
	var hit_consumer_sources: Array[String] = []
	_collect_sources_containing(
		"res://scripts",
		"get_node_index_at",
		hit_consumer_sources
	)
	_expect(
		hit_consumer_sources.is_empty(),
		"the read-only map must not acquire a label-dependent node hit consumer: %s"
		% str(hit_consumer_sources)
	)

	var radius := TowerAscentTuning.TEMP_MAP_OVERLAY_NODE_RADIUS
	var canonical_center := Vector2(240.0, 180.0)
	var top_corner_probe := canonical_center + Vector2(-1.0, -1.0).normalized() * (radius - 0.25)
	var drifted_center := canonical_center + Vector2(radius * 0.5, radius * 0.5)
	_expect(
		top_corner_probe.distance_to(canonical_center) <= radius,
		"GRT-022 top-corner probe must hit the canonical node circle"
	)
	_expect(
		top_corner_probe.distance_to(drifted_center) > radius,
		"GRT-022 top-corner probe must reject a label-coupled shifted node circle"
	)
	_expect(
		canonical_center.distance_to(drifted_center) <= radius,
		"GRT-022 counterproof must show why a center-only probe would miss the drift"
	)


func _collect_sources_containing(
	directory_path: String,
	needle: String,
	result: Array[String]
) -> void:
	for filename in DirAccess.get_files_at(directory_path):
		if not filename.ends_with(".gd"):
			continue
		var source_path := directory_path.path_join(filename)
		if FileAccess.get_file_as_string(source_path).find(needle) >= 0:
			result.append(source_path)
	for child_directory in DirAccess.get_directories_at(directory_path):
		_collect_sources_containing(
			directory_path.path_join(child_directory),
			needle,
			result
		)


func _expect_promoted_texture(presentation: Dictionary, identity: String) -> void:
	var texture_value: Variant = presentation.get("icon_texture", null)
	_expect(texture_value is Texture2D, "%s must load a Texture2D from its approved asset" % identity)
	if texture_value is Texture2D:
		var texture := texture_value as Texture2D
		_expect(
			texture.get_width() == 256 and texture.get_height() == 256,
			"%s must retain the 256x256 runtime contract" % identity
		)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
