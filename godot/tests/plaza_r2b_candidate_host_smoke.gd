extends SceneTree

const PlazaAssetLoader := preload("res://scripts/plaza/plaza_asset_loader.gd")
const PlazaMapLayoutGenerator := preload("res://scripts/plaza/plaza_map_layout_generator.gd")
const PlazaMapProjection := preload("res://scripts/plaza/plaza_map_projection.gd")
const PlazaR2MapWorldCandidateHost := preload("res://scripts/plaza/plaza_r2_map_world_candidate_host.gd")

const WORLD_SIZE := Vector2(2400.0, 1500.0)
const VIEW_SIZE := Vector2(2020.0, 1246.0)
const SPAWN_ANCHOR := Vector2(120.0, 666.0)
const EXIT_ZONE := Rect2(2250.0, 596.0, 120.0, 92.0)
const SAFE_INSETS := {
	"left": 72.0,
	"top": 72.0,
	"right": 360.0,
	"bottom": 120.0,
}

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var specs := PlazaAssetLoader.build_hwangyeok_building_specs(1, 5, false, false)
	var layout := PlazaMapLayoutGenerator.generate(
		1,
		5,
		WORLD_SIZE,
		specs,
		SPAWN_ANCHOR,
		EXIT_ZONE
	)
	_expect(bool((layout.get("validation", {}) as Dictionary).get("valid", false)), "seed 5 source layout must be valid")
	_expect(str(layout.get("fingerprint", "")).length() == 64, "source layout must expose its concrete fingerprint")
	var bank := _find_by_type(layout.get("building_specs", []), "bank")
	_expect(not bank.is_empty(), "seed 5 candidate fixture must include bank")
	if bank.is_empty():
		_finish()
		return

	var bank_anchor := bank.get("sort_anchor_world", Vector2.ZERO) as Vector2
	var player_world := bank_anchor + Vector2(0.0, 14.0)
	var host := PlazaR2MapWorldCandidateHost.new()
	host.name = "PlazaR2BCandidateHost"
	root.add_child(host)
	var state := _build_state(layout, player_world, 1000)
	_expect(host.sync_state(state), "valid seed 5 candidate host state must sync")
	_verify_live_tree(host, bank, player_world)
	_verify_caller_road_mutation_isolation(host, state)
	_verify_actual_tree_counterproofs(host, state)
	_verify_strict_art_validation(host, state)
	_verify_fail_closed(host, state)
	_verify_production_disconnection()
	host.free()
	_finish()


func _build_state(layout: Dictionary, player_world: Vector2, ticks_msec: int) -> Dictionary:
	return {
		"render_size": VIEW_SIZE,
		"safe_insets": SAFE_INSETS,
		"layout": layout,
		"player_world_pos": player_world,
		"camera_center_world": WORLD_SIZE * 0.5,
		"camera_zoom": 1.0,
		"ticks_msec": ticks_msec,
		"actor_rect_relative_world": Rect2(-55.0, -130.0, 110.0, 150.0),
		"actor_color": Color(0.05, 0.92, 1.0, 1.0),
		"ysort_probe": {
			"building_type": "bank",
			"rect_relative_world": Rect2(-90.0, -100.0, 180.0, 140.0),
			"color": Color(1.0, 0.12, 0.04, 1.0),
		},
	}


func _verify_live_tree(host: Control, bank: Dictionary, player_world: Vector2) -> void:
	var status := host.call("get_debug_status") as Dictionary
	_expect(bool(status.get("candidate_only", false)), "host must identify itself as candidate-only")
	_expect(not bool(status.get("production_connected", true)), "candidate host must remain production-disconnected")
	_expect(bool(status.get("active", false)) and bool(status.get("visible", false)), "valid sync must activate the retained host")
	_expect(not bool(status.get("process_enabled", true)), "candidate host must remain owner-sync driven")
	_expect(bool(status.get("projection_valid", false)), "valid host must retain a valid shared projection")
	var sort_status := status.get("sort_contract", {}) as Dictionary
	_expect(bool(sort_status.get("valid", false)), "actual retained node tree must satisfy the shared Y-sort contract")
	_expect(bool(sort_status.get("sort_root_y_sort_enabled", false)), "the one actual sort root must enable Y sorting")
	_expect(bool(sort_status.get("sort_root_modulate_white", false)), "shared sort root must keep inherited modulate white")
	_expect(int(sort_status.get("building_count", -1)) == 2, "seed 5 host must expose two direct building siblings")
	_expect(int(sort_status.get("actor_count", -1)) == 1, "host must expose one direct actor sibling")
	_expect(int(sort_status.get("direct_child_count", -1)) == 3, "sort root must contain only two buildings plus actor")
	for key in [
		"all_direct_parent_match",
		"all_direct_z_zero",
		"all_direct_relative",
		"all_direct_not_top_level",
		"all_wrapper_modulate_white",
		"all_wrappers_group_children",
		"all_layer_z_zero",
		"all_layer_relative",
		"all_layer_not_top_level",
		"all_layer_self_modulate_white",
		"all_layer_not_show_behind_parent",
		"all_layer_not_using_parent_material",
		"all_layer_material_contract_valid",
		"shared_material_blend_contract_valid",
		"actor_wrapper_visible",
		"actor_body_visible",
	]:
		_expect(bool(sort_status.get(key, false)), "actual sort-tree field %s must be true" % key)

	var sort_root := host.call("get_sort_root_for_test") as Node2D
	var actor := host.call("get_actor_sort_item_for_test") as Node2D
	var bank_item := host.call("get_building_sort_item_for_test", "bank") as Node2D
	_expect(sort_root != null and actor != null and bank_item != null, "host must expose the real retained sort nodes")
	if sort_root == null or actor == null or bank_item == null:
		return
	_expect(actor.get_parent() == sort_root and bank_item.get_parent() == sort_root, "actor and building must be direct siblings, not nested sort claims")
	var projection := host.call("get_projection_snapshot_for_test") as Dictionary
	_expect(
		actor.position.is_equal_approx(PlazaMapProjection.world_to_screen(player_world, projection)),
		"actor wrapper position must equal the projected player foot"
	)
	var bank_anchor := bank.get("sort_anchor_world", Vector2.ZERO) as Vector2
	_expect(
		bank_item.position.is_equal_approx(PlazaMapProjection.world_to_screen(bank_anchor, projection)),
		"building wrapper position must equal its projected authored sort anchor"
	)
	var base := bank_item.get_node("Base") as Sprite2D
	var base_rect := Rect2(bank_item.position + base.position, base.texture.get_size() * base.scale)
	var expected_rect := PlazaMapProjection.world_rect_to_screen(bank.get("visual_rect", Rect2()), projection)
	_expect(_rect_equal_approx(base_rect, expected_rect), "base child rect must stay anchor-relative and reconstruct the projected visual rect")
	var sign := bank_item.get_node("SignEmissive") as Sprite2D
	var window := bank_item.get_node("WindowGlowMask") as Sprite2D
	_expect(base.z_index == 0 and sign.z_index == 0 and window.z_index == 0, "all building layers must remain at z=0 inside the grouped wrapper")
	_expect(
		base.material is CanvasItemMaterial
		and (base.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_MIX,
		"base child must bind MIX"
	)
	_expect(
		sign.material is CanvasItemMaterial
		and window.material is CanvasItemMaterial
		and (sign.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD
		and (window.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD,
		"sign/window children must bind ADD without escaping Y-sort z"
	)
	_expect(int(sort_status.get("mix_material_id", 0)) == base.material.get_instance_id(), "status must report the actual expected MIX material instance")
	_expect(int(sort_status.get("add_material_id", 0)) == sign.material.get_instance_id(), "status must report the actual expected ADD material instance")
	_verify_material_record_contract(sort_status, "valid live tree")
	var probe := bank_item.get_node("YSortProbe") as Polygon2D
	_expect(probe.visible and probe.polygon.size() == 4, "pixel counterproof must configure a real opaque child on the bank wrapper")
	var actor_body := actor.get_node("Body") as Polygon2D
	_expect(actor_body.polygon.size() == 4, "actor must be a retained CanvasItem child rather than immediate draw state")
	_expect(actor_body.z_index == 0 and actor_body.z_as_relative and not actor_body.top_level and not actor_body.use_parent_material, "actor body must share the grouped layer/material contract")
	_expect(probe.z_index == 0 and probe.z_as_relative and not probe.top_level and not probe.use_parent_material, "bank sentinel must remain an actual z0 relative child with local material ownership")


func _verify_material_record_contract(status: Dictionary, label: String) -> void:
	var records_value: Variant = status.get("layer_material_records", null)
	_expect(records_value is Array, "%s must publish actual layer material records" % label)
	if not (records_value is Array):
		return
	var material_records := records_value as Array
	_expect(not material_records.is_empty(), "%s material records must be non-vacuous" % label)
	for record_value in material_records:
		_expect(record_value is Dictionary, "%s material record must be a dictionary" % label)
		if not (record_value is Dictionary):
			continue
		var record := record_value as Dictionary
		_expect(bool(record.get("valid", false)), "%s layer %s must satisfy its actual ID/blend contract" % [label, str(record.get("layer_name", ""))])
		_expect(int(record.get("actual_material_id", -1)) == int(record.get("expected_material_id", -2)), "%s layer %s material instance IDs must match" % [label, str(record.get("layer_name", ""))])
		_expect(int(record.get("actual_blend_mode", -2)) == int(record.get("expected_blend_mode", -3)), "%s layer %s blend modes must match" % [label, str(record.get("layer_name", ""))])
		_expect(not bool(record.get("actual_use_parent_material", true)), "%s layer %s must not bypass its local material" % [label, str(record.get("layer_name", ""))])
		_expect(not bool(record.get("expected_use_parent_material", true)), "%s layer %s expected parent-material flag must be explicit false" % [label, str(record.get("layer_name", ""))])
		_expect((record.get("actual_self_modulate", Color.TRANSPARENT) as Color).is_equal_approx(Color.WHITE), "%s layer %s self_modulate must be white" % [label, str(record.get("layer_name", ""))])
		_expect((record.get("expected_self_modulate", Color.TRANSPARENT) as Color).is_equal_approx(Color.WHITE), "%s layer %s expected self_modulate must be explicit white" % [label, str(record.get("layer_name", ""))])
		_expect(not bool(record.get("actual_show_behind_parent", true)), "%s layer %s must not render behind its wrapper" % [label, str(record.get("layer_name", ""))])


func _verify_caller_road_mutation_isolation(host: Control, state: Dictionary) -> void:
	var records_before := host.call("get_road_draw_records_for_test") as Array[Dictionary]
	_expect(not records_before.is_empty(), "active candidate must compile concrete road draw records")
	var layout := state.get("layout", {}) as Dictionary
	var road_graph := layout.get("road_graph", {}) as Dictionary
	var edges := road_graph.get("edges", []) as Array
	_expect(not edges.is_empty(), "caller mutation counterproof requires a concrete road edge")
	if edges.is_empty():
		return
	var first_edge := edges[0] as Dictionary
	var original_polyline_value: Variant = first_edge.get("polyline_world", null)
	_expect(original_polyline_value is PackedVector2Array or original_polyline_value is Array, "seed 5 road edge must expose a concrete authored polyline")
	if not (original_polyline_value is PackedVector2Array) and not (original_polyline_value is Array):
		return
	var original_polyline: Variant
	var mutated_polyline: Variant
	if original_polyline_value is PackedVector2Array:
		original_polyline = (original_polyline_value as PackedVector2Array).duplicate()
		mutated_polyline = (original_polyline as PackedVector2Array).duplicate()
		(mutated_polyline as PackedVector2Array)[0] += Vector2(777.0, -555.0)
	else:
		original_polyline = (original_polyline_value as Array).duplicate(true)
		mutated_polyline = (original_polyline as Array).duplicate(true)
		(mutated_polyline as Array)[0] = ((mutated_polyline as Array)[0] as Vector2) + Vector2(777.0, -555.0)
	first_edge["polyline_world"] = mutated_polyline
	var records_while_caller_is_mutated := host.call("get_road_draw_records_for_test") as Array[Dictionary]
	_expect(records_while_caller_is_mutated == records_before, "post-sync caller road mutation must not alter active compiled draw state")
	_expect(bool((host.call("get_debug_status") as Dictionary).get("active", false)), "caller road mutation must not deactivate the already compiled frame")
	first_edge["polyline_world"] = original_polyline
	_expect((host.call("get_road_draw_records_for_test") as Array[Dictionary]) == records_before, "restoring caller state must also leave the isolated host unchanged")


func _verify_actual_tree_counterproofs(host: Control, state: Dictionary) -> void:
	var sort_root := host.call("get_sort_root_for_test") as Node2D
	var actor := host.call("get_actor_sort_item_for_test") as Node2D
	var bank := host.call("get_building_sort_item_for_test", "bank") as Node2D
	if sort_root == null or actor == null or bank == null:
		return

	sort_root.y_sort_enabled = false
	sort_root.modulate = Color(1.0, 1.0, 1.0, 0.0)
	actor.z_index = 1
	actor.modulate = Color(1.0, 1.0, 1.0, 0.0)
	actor.visible = false
	bank.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var base := bank.get_node("Base") as Sprite2D
	var sign := bank.get_node("SignEmissive") as Sprite2D
	var window := bank.get_node("WindowGlowMask") as Sprite2D
	var probe := bank.get_node("YSortProbe") as Polygon2D
	var mix_material := base.material as CanvasItemMaterial
	var add_material := sign.material as CanvasItemMaterial
	var foreign_base_material := CanvasItemMaterial.new()
	foreign_base_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var foreign_sign_material := CanvasItemMaterial.new()
	foreign_sign_material.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	for sprite in [base, sign, window]:
		(sprite as Sprite2D).z_index = 1
		(sprite as Sprite2D).z_as_relative = false
		(sprite as Sprite2D).top_level = true
		(sprite as Sprite2D).self_modulate = Color(1.0, 1.0, 1.0, 0.0)
		(sprite as Sprite2D).show_behind_parent = true
	base.material = foreign_base_material
	sign.material = foreign_sign_material
	window.material = null
	base.use_parent_material = true
	mix_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add_material.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	probe.top_level = true
	var actor_body := actor.get_node("Body") as Polygon2D
	actor_body.z_as_relative = false
	actor_body.top_level = true
	probe.material = foreign_base_material
	probe.use_parent_material = true
	probe.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	probe.show_behind_parent = true
	actor_body.material = foreign_sign_material
	actor_body.use_parent_material = true
	actor_body.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	actor_body.show_behind_parent = true
	actor_body.visible = false
	var mutated := host.call("get_sort_contract_status") as Dictionary
	_expect(not bool(mutated.get("valid", true)), "mutating actual root, wrapper, glow, probe, and actor layers must turn the contract RED")
	_expect(not bool(mutated.get("sort_root_y_sort_enabled", true)), "Y-sort counterproof must read the mutated node property")
	_expect(not bool(mutated.get("sort_root_modulate_white", true)), "root inherited-modulate counterproof must read the actual root")
	_expect(not bool(mutated.get("all_direct_z_zero", true)), "actor-z counterproof must read the actual direct sibling")
	_expect(not bool(mutated.get("all_wrapper_modulate_white", true)), "wrapper inherited-modulate counterproof must inspect building and actor wrappers")
	_expect(not bool(mutated.get("all_layer_z_zero", true)), "glow-z counterproof must inspect the actual child Sprite2D")
	_expect(not bool(mutated.get("all_layer_relative", true)), "relative-z counterproof must inspect window and actor body children")
	_expect(not bool(mutated.get("all_layer_not_top_level", true)), "top-level counterproof must inspect probe and actor body children")
	_expect(not bool(mutated.get("all_layer_self_modulate_white", true)), "self-modulate counterproof must inspect actual child CanvasItems")
	_expect(not bool(mutated.get("all_layer_not_show_behind_parent", true)), "show-behind counterproof must inspect actual child CanvasItems")
	_expect(not bool(mutated.get("all_layer_not_using_parent_material", true)), "parent-material counterproof must inspect actual CanvasItem flags")
	_expect(not bool(mutated.get("all_layer_material_contract_valid", true)), "material counterproof must inspect actual Base/Sign/Window bindings and blend")
	_expect(not bool(mutated.get("shared_material_blend_contract_valid", true)), "shared material counterproof must inspect actual MIX/ADD objects")
	_expect(not bool(mutated.get("actor_wrapper_visible", true)) and not bool(mutated.get("actor_body_visible", true)), "actor visibility counterproof must inspect wrapper and Body")
	var saw_material_red := false
	for material_record_value in mutated.get("layer_material_records", []) as Array:
		if material_record_value is Dictionary and not bool((material_record_value as Dictionary).get("valid", true)):
			saw_material_red = true
	_expect(saw_material_red, "material counterproof must publish at least one concrete RED actual/expected record")

	var restored_state := state.duplicate(true)
	restored_state["ticks_msec"] = 1022
	_expect(host.call("sync_state", restored_state), "valid owner sync must restore every mutation left in place")
	var restored := host.call("get_sort_contract_status") as Dictionary
	_expect(bool(restored.get("valid", false)), "restored actual tree must return GREEN")
	_expect(bool(restored.get("sort_root_y_sort_enabled", false)), "valid sync must restore the actual Y-sort root")
	_expect(bool(restored.get("sort_root_modulate_white", false)), "valid sync must restore root inherited modulate")
	_expect(bool(restored.get("all_direct_z_zero", false)), "valid sync must restore direct wrapper z")
	_expect(bool(restored.get("all_wrapper_modulate_white", false)), "valid sync must restore all wrapper inherited modulate")
	_expect(bool(restored.get("all_layer_z_zero", false)), "valid sync must restore every child layer z")
	_expect(bool(restored.get("all_layer_relative", false)), "valid sync must restore every child layer relative-z flag")
	_expect(bool(restored.get("all_layer_not_top_level", false)), "valid sync must restore every child layer top-level flag")
	_expect(bool(restored.get("all_layer_self_modulate_white", false)), "valid sync must restore every child self_modulate")
	_expect(bool(restored.get("all_layer_not_show_behind_parent", false)), "valid sync must restore every child show_behind_parent flag")
	_expect(bool(restored.get("all_layer_not_using_parent_material", false)), "valid sync must disable parent-material inheritance on every child layer")
	_expect(bool(restored.get("all_layer_material_contract_valid", false)), "valid sync must restore every actual layer material binding")
	_expect(bool(restored.get("shared_material_blend_contract_valid", false)), "valid sync must restore both shared material blend modes")
	_expect(bool(restored.get("actor_wrapper_visible", false)) and bool(restored.get("actor_body_visible", false)), "valid sync must restore Actor and Body visibility")
	_expect(sort_root.modulate.is_equal_approx(Color.WHITE), "valid sync must restore actual sort-root modulate")
	_expect(bank.modulate.is_equal_approx(Color.WHITE) and actor.modulate.is_equal_approx(Color.WHITE), "valid sync must restore actual wrapper modulate")
	_expect(actor.visible and actor_body.visible, "valid sync must restore actual Actor and Body visibility")
	for sprite in [base, sign, window]:
		_expect((sprite as Sprite2D).z_index == 0, "valid sync must restore %s z_index" % (sprite as Sprite2D).name)
		_expect((sprite as Sprite2D).z_as_relative, "valid sync must restore %s z_as_relative" % (sprite as Sprite2D).name)
		_expect(not (sprite as Sprite2D).top_level, "valid sync must restore %s top_level" % (sprite as Sprite2D).name)
		_expect(not (sprite as Sprite2D).use_parent_material, "valid sync must restore %s use_parent_material" % (sprite as Sprite2D).name)
		_expect((sprite as Sprite2D).self_modulate.is_equal_approx(Color.WHITE), "valid sync must restore %s self_modulate" % (sprite as Sprite2D).name)
		_expect(not (sprite as Sprite2D).show_behind_parent, "valid sync must restore %s show_behind_parent" % (sprite as Sprite2D).name)
	_expect(base.material == mix_material, "valid sync must rebind Base to the canonical MIX material instance")
	_expect(sign.material == add_material and window.material == add_material, "valid sync must rebind Sign/Window to the canonical ADD material instance")
	_expect(probe.material == null and actor_body.material == null, "valid sync must clear foreign Probe/Body materials back to RID 0")
	_expect(not probe.use_parent_material and not actor_body.use_parent_material, "valid sync must disable Probe/Body parent material inheritance")
	_expect(probe.self_modulate.is_equal_approx(Color.WHITE) and actor_body.self_modulate.is_equal_approx(Color.WHITE), "valid sync must restore Probe/Body self_modulate")
	_expect(not probe.show_behind_parent and not actor_body.show_behind_parent, "valid sync must restore Probe/Body show_behind_parent")
	_expect(mix_material.blend_mode == CanvasItemMaterial.BLEND_MODE_MIX, "valid sync must restore the shared MIX blend mode")
	_expect(add_material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "valid sync must restore the shared ADD blend mode")
	_verify_material_record_contract(restored, "restored actual tree")
	var null_material_layer_count := 0
	for material_record_value in restored.get("layer_material_records", []) as Array:
		if not (material_record_value is Dictionary):
			continue
		var material_record := material_record_value as Dictionary
		if str(material_record.get("layer_name", "")) in ["YSortProbe", "Body"]:
			null_material_layer_count += 1
			_expect(int(material_record.get("actual_material_id", -1)) == 0, "Probe/Body actual material RID must restore to 0")
			_expect(int(material_record.get("expected_material_id", -1)) == 0, "Probe/Body expected material RID must be 0")
	_expect(null_material_layer_count == 3, "seed 5 must expose two probe plus one actor-body RID 0 records")


func _verify_strict_art_validation(host: Control, state: Dictionary) -> void:
	_expect(host.call("sync_state", state), "strict-art counterproofs require a fresh valid baseline")
	_expect_art_rejection(
		host,
		_with_building_field(state, "sign_glow_strength", "bright"),
		"invalid_building_glow_strength",
		"wrong-type glow strength",
		state
	)
	_expect_art_rejection(
		host,
		_with_building_field(state, "window_glow_strength", NAN),
		"invalid_building_glow_strength",
		"NaN glow strength",
		state
	)
	_expect_art_rejection(
		host,
		_with_building_field(state, "window_glow_strength", -0.1),
		"invalid_building_glow_strength",
		"negative glow strength",
		state
	)
	_expect_art_rejection(
		host,
		_with_building_field(state, "sign_glow_color", "gold"),
		"invalid_building_glow_color_type",
		"wrong-type glow color",
		state
	)
	_expect_art_rejection(
		host,
		_with_building_field(state, "window_glow_color", Color(NAN, 0.5, 0.5, 1.0)),
		"invalid_building_glow_color",
		"NaN glow color",
		state
	)
	_expect_art_rejection(
		host,
		_with_building_field(state, "base_texture", "not_a_texture"),
		"invalid_building_texture",
		"wrong-type building texture",
		state
	)

	var wrong_actor_color := state.duplicate(true)
	wrong_actor_color["actor_color"] = "cyan"
	_expect_art_rejection(host, wrong_actor_color, "invalid_actor_art_type", "wrong-type actor color", state)
	var nan_actor_color := state.duplicate(true)
	nan_actor_color["actor_color"] = Color(0.0, NAN, 1.0, 1.0)
	_expect_art_rejection(host, nan_actor_color, "invalid_actor_art", "NaN actor color", state)
	var nan_actor_rect := state.duplicate(true)
	nan_actor_rect["actor_rect_relative_world"] = Rect2(Vector2(NAN, -130.0), Vector2(110.0, 150.0))
	_expect_art_rejection(host, nan_actor_rect, "invalid_actor_art", "NaN actor rect", state)

	var wrong_probe_type := state.duplicate(true)
	wrong_probe_type["ysort_probe"] = "not_a_probe"
	_expect_art_rejection(host, wrong_probe_type, "invalid_probe_type", "wrong-type probe dictionary", state)
	var wrong_probe_color := state.duplicate(true)
	(wrong_probe_color.get("ysort_probe", {}) as Dictionary)["color"] = "red"
	_expect_art_rejection(host, wrong_probe_color, "invalid_probe_color_type", "wrong-type probe color", state)
	var nan_probe_color := state.duplicate(true)
	(nan_probe_color.get("ysort_probe", {}) as Dictionary)["color"] = Color(1.0, 0.0, NAN, 1.0)
	_expect_art_rejection(host, nan_probe_color, "invalid_probe_color", "NaN probe color", state)
	var wrong_probe_rect := state.duplicate(true)
	(wrong_probe_rect.get("ysort_probe", {}) as Dictionary)["rect_relative_world"] = "not_a_rect"
	_expect_art_rejection(host, wrong_probe_rect, "invalid_probe_rect_type", "wrong-type probe rect", state)
	var nan_probe_rect := state.duplicate(true)
	(nan_probe_rect.get("ysort_probe", {}) as Dictionary)["rect_relative_world"] = Rect2(Vector2.ZERO, Vector2(NAN, 140.0))
	_expect_art_rejection(host, nan_probe_rect, "invalid_probe_rect", "NaN probe rect", state)


func _with_building_field(state: Dictionary, key: String, value: Variant) -> Dictionary:
	var invalid_state := state.duplicate(true)
	var layout := invalid_state.get("layout", {}) as Dictionary
	var specs := layout.get("building_specs", []) as Array
	if not specs.is_empty() and specs[0] is Dictionary:
		(specs[0] as Dictionary)[key] = value
	layout["fingerprint"] = PlazaMapLayoutGenerator.build_fingerprint(layout)
	return invalid_state


func _expect_art_rejection(
	host: Control,
	invalid_state: Dictionary,
	expected_reason: String,
	label: String,
	valid_state: Dictionary
) -> void:
	var actor := host.call("get_actor_sort_item_for_test") as Node2D
	var bank := host.call("get_building_sort_item_for_test", "bank") as Node2D
	var actor_position_before := actor.position if actor != null else Vector2.INF
	var sign_modulate_before := Color.TRANSPARENT
	if bank != null:
		sign_modulate_before = (bank.get_node("SignEmissive") as Sprite2D).modulate
	var road_records_before := host.call("get_road_draw_records_for_test") as Array[Dictionary]
	var sync_count_before := int((host.call("get_debug_status") as Dictionary).get("successful_sync_count", -1))
	_expect(not bool(host.call("sync_state", invalid_state)), "%s must reject without a script error" % label)
	var rejected := host.call("get_debug_status") as Dictionary
	_expect(str(rejected.get("last_sync_rejection_reason", "")) == expected_reason, "%s must report %s" % [label, expected_reason])
	_verify_hidden(host, label)
	_expect(int(rejected.get("successful_sync_count", -2)) == sync_count_before, "%s must not commit a partial sync" % label)
	if actor != null:
		_expect(actor.position.is_equal_approx(actor_position_before), "%s must not mutate the retained actor" % label)
	if bank != null:
		_expect((bank.get_node("SignEmissive") as Sprite2D).modulate.is_equal_approx(sign_modulate_before), "%s must not mutate retained building art" % label)
	_expect((host.call("get_road_draw_records_for_test") as Array[Dictionary]) == road_records_before, "%s must not mutate compiled road draw state" % label)
	_expect(bool(host.call("sync_state", valid_state)), "%s must recover through a valid owner sync" % label)


func _verify_fail_closed(host: Control, state: Dictionary) -> void:
	var missing_ticks := state.duplicate(true)
	missing_ticks.erase("ticks_msec")
	_expect(not bool(host.call("sync_state", missing_ticks)), "missing owner-frame tick must reject sync")
	_verify_hidden(host, "missing ticks")
	_expect(str((host.call("get_debug_status") as Dictionary).get("last_sync_rejection_reason", "")) == "missing_ticks_msec", "missing tick rejection must be diagnosable")

	var degenerate := state.duplicate(true)
	degenerate["render_size"] = Vector2(1.0, VIEW_SIZE.y)
	_expect(not bool(host.call("sync_state", degenerate)), "degenerate render size must reject sync")
	_verify_hidden(host, "degenerate render")

	var stale := state.duplicate(true)
	var stale_layout := (state.get("layout", {}) as Dictionary).duplicate(true)
	stale_layout["fingerprint"] = "0".repeat(64)
	stale["layout"] = stale_layout
	_expect(not bool(host.call("sync_state", stale)), "stale layout fingerprint must reject sync")
	_expect(str((host.call("get_debug_status") as Dictionary).get("last_sync_rejection_reason", "")) == "stale_layout_fingerprint", "fingerprint rejection must be concrete")
	_verify_hidden(host, "stale fingerprint")

	_expect(host.call("sync_state", state), "valid state must reactivate after rejection legs")
	_expect(not bool(host.call("sync_state", state, false)), "inactive owner gate must reject activation")
	_verify_hidden(host, "inactive owner")
	_expect(host.call("sync_state", state), "valid state must reactivate before clear")
	host.call("clear_transient_canvas_items")
	var cleared := host.call("get_debug_status") as Dictionary
	_expect(str(cleared.get("last_sync_rejection_reason", "")) == "cleared", "clear must expose its lifecycle reason")
	_expect(not bool(cleared.get("projection_valid", true)), "clear must discard the retained projection")
	_verify_hidden(host, "transient clear")


func _verify_hidden(host: Control, label: String) -> void:
	var status := host.call("get_debug_status") as Dictionary
	_expect(not bool(status.get("active", true)) and not bool(status.get("visible", true)), "%s must hide the host" % label)
	_expect(int(status.get("visible_building_count", -1)) == 0, "%s must hide every retained building" % label)
	_expect(not bool(status.get("actor_visible", true)), "%s must hide the retained actor" % label)


func _verify_production_disconnection() -> void:
	var scene_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_scene.gd")
	_expect(
		not scene_source.contains("plaza_r2_map_world_candidate_host.gd"),
		"production PlazaScene must retain zero candidate-host references"
	)
	var project_source := FileAccess.get_file_as_string("res://project.godot")
	_expect(
		not project_source.contains("plaza_r2_map_world_candidate_host.gd"),
		"project autoload/input configuration must not connect the candidate host"
	)


func _find_by_type(value: Variant, building_type: String) -> Dictionary:
	if not (value is Array):
		return {}
	for item_value in value as Array:
		if item_value is Dictionary and str((item_value as Dictionary).get("type", "")) == building_type:
			return (item_value as Dictionary).duplicate(false)
	return {}


func _rect_equal_approx(left: Rect2, right: Rect2) -> bool:
	return left.position.is_equal_approx(right.position) and left.size.is_equal_approx(right.size)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("plaza_r2b_candidate_host_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
