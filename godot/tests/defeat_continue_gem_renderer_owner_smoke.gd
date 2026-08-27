extends SceneTree

# expect-zero-object-leaks
const DefeatContinueGemRenderer := preload("res://scripts/core/defeat_continue_gem_renderer.gd")
const BattleCoreTexturePaths := preload("res://scripts/resources/battle_core_texture_paths.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_layout_and_state_contract()
	_verify_hwangyeokjeon_jade_asset_contract()
	_verify_source_ownership()
	if _failures.is_empty():
		print("defeat_continue_gem_renderer_owner_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_layout_and_state_contract() -> void:
	var renderer := DefeatContinueGemRenderer.new()
	var view_size := Vector2(1280.0, 720.0)
	var first := renderer.get_consumed_gem_center(view_size, 3, 1)
	var second := renderer.get_consumed_gem_center(view_size, 3, 2)
	var third := renderer.get_consumed_gem_center(view_size, 3, 3)
	_expect(first.is_equal_approx(Vector2(518.4, 528.0)), "first consumed gem center must preserve the left slot")
	_expect(second.is_equal_approx(Vector2(640.0, 528.0)), "second consumed gem center must preserve the middle slot")
	_expect(third.is_equal_approx(Vector2(761.6, 528.0)), "third consumed gem center must preserve the right slot")
	_expect(renderer.get_consumed_gem_center(view_size, 3, 0).is_equal_approx(first), "consumed count must clamp to the first slot")
	_expect(renderer.get_consumed_gem_center(view_size, 3, 99).is_equal_approx(third), "consumed count must clamp to the final slot")

	renderer.sync_gauge_state(0, 99, 4, true, 1.7, -2.0, Vector2(3.0, 4.0), 1.4)
	_expect(renderer._max_gems == 1, "gem renderer must normalize max gems to at least one")
	_expect(renderer._visual_remaining_gems == 1, "gem renderer must clamp visual remaining gems")
	_expect(is_equal_approx(renderer._pulse, 1.0), "gem renderer must clamp pulse input")
	_expect(is_zero_approx(renderer._confirm_elapsed), "gem renderer must reject negative confirm time")
	_expect(is_equal_approx(renderer._shatter_progress, 1.0), "gem renderer must clamp shatter progress")

	renderer.sync_impact_state(1.4, -0.2, 0.5, 2.0, -1.0, 0.4, 3.0, Vector2(5.0, 6.0))
	_expect(is_equal_approx(renderer._pre_shatter_charge, 1.0), "gem renderer must clamp pre-shatter charge")
	_expect(is_zero_approx(renderer._pre_shatter_crack), "gem renderer must clamp pre-shatter crack")
	_expect(is_equal_approx(renderer._chroma_split_strength, 0.5), "gem renderer must preserve valid chroma strength")
	_expect(is_equal_approx(renderer._impact_flash_alpha, 1.0), "gem renderer must clamp impact flash")
	_expect(is_zero_approx(renderer._impact_ring_progress), "gem renderer must clamp ring progress")
	_expect(is_equal_approx(renderer._impact_light_beam_alpha, 1.0), "gem renderer must clamp beam alpha")


func _verify_hwangyeokjeon_jade_asset_contract() -> void:
	var full_path := BattleCoreTexturePaths.CHANCE_GEM_FULL_TEXTURE_PATH
	var broken_path := BattleCoreTexturePaths.CHANCE_GEM_BROKEN_TEXTURE_PATH
	_expect(full_path.ends_with("chance_gem_hwangyeokjeon_jade_full_imagegen_v2.png"), "intact chance gem must route to the Hwangyeokjeon faceted-jade asset")
	_expect(broken_path.ends_with("chance_gem_hwangyeokjeon_jade_broken_imagegen_v2.png"), "spent chance gem must route to the matching broken faceted-jade asset")
	_expect(full_path != broken_path, "intact and spent jade wards must remain separate authored states")
	_expect(FileAccess.file_exists(full_path), "intact Hwangyeokjeon faceted-jade PNG must exist")
	_expect(FileAccess.file_exists(broken_path), "broken Hwangyeokjeon faceted-jade PNG must exist")


func _verify_source_ownership() -> void:
	var renderer_source := FileAccess.get_file_as_string("res://scripts/core/defeat_continue_gem_renderer.gd")
	var screen_source := FileAccess.get_file_as_string("res://scripts/core/defeat_chance_gems_continue_screen.gd")
	_expect(renderer_source.contains("func draw_gem_sequence"), "gem renderer must own the draw entrypoint")
	_expect(renderer_source.contains("func _draw_gem_shatter_sheet"), "gem renderer must own shatter-sheet drawing")
	_expect(renderer_source.contains("func _draw_pre_shatter_charge"), "gem renderer must own pre-shatter charge drawing")
	_expect(renderer_source.contains("func _draw_shatter_impact_layers"), "gem renderer must own shatter impact drawing")
	_expect(renderer_source.contains("func _draw_gem_setting"), "chance gems must use Hwangyeokjeon lacquer-and-brass settings")
	_expect(renderer_source.contains("func _draw_cloud_knot_marker"), "chance-gem rail must use Hwangyeokjeon cloud-knot terminals")
	_expect(renderer_source.contains("JADE_GEM_ACTIVE_MODULATE"), "authored jade colors must replace the legacy cyan crystal tint")
	_expect(renderer_source.contains("GEM_SHATTER_ENERGY_BOX_SCALE"), "legacy 64-frame fracture energy must stay contained inside the jade ward face")
	_expect(renderer_source.contains("func _draw_spent_gem_cracks"), "spent jade wards must retain a readable fracture accent at runtime slot scale")
	_expect(not renderer_source.contains("func _draw_diamond_marker"), "legacy cyan diamond rail markers must stay removed")
	_expect(renderer_source.contains("GEM_SHATTER_FRAME_COUNT := 64"), "gem renderer must preserve the 64-frame sheet contract")
	_expect(not renderer_source.contains("func _process"), "gem renderer must remain caller-clocked")
	_expect(not renderer_source.contains("Dictionary"), "gem renderer handoff must not allocate frame context dictionaries")
	_expect(screen_source.contains("_gem_renderer.sync_gauge_state"), "continue screen must sync gauge presentation explicitly")
	_expect(screen_source.contains("_gem_renderer.sync_impact_state"), "continue screen must sync impact presentation explicitly")
	_expect(screen_source.contains("_gem_renderer.draw_gem_sequence"), "continue screen must delegate gem drawing")
	_expect(not screen_source.contains("func _draw_gem_slot"), "continue screen must not retain gem-slot drawing")
	_expect(not screen_source.contains("func _draw_gem_shatter_sheet"), "continue screen must not retain shatter-sheet drawing")
	_expect(not screen_source.contains("func _draw_pre_shatter_charge"), "continue screen must not retain pre-shatter drawing")
	_expect(not screen_source.contains("func _draw_shatter_impact_layers"), "continue screen must not retain impact drawing")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
