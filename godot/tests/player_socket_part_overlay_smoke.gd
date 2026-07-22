extends SceneTree

# Socket composition slice 2 seal: socket-anchored customization overlay
# placement + perk-driven cosmetic part injection (item_luck -> floating
# lucky-coin charm at the head_top socket).
#
# Legs:
#  - head_top socket data authored for every pilot motion
#  - overlay renderer socket placement math (right + mirrored left)
#  - fail-closed: unauthored motion / wrong cell basis emit no command
#  - part manifest projection + real scene/actor context injection chain
#    (owned -> injected, unowned -> absent, user slot entry wins)
#  - BattleResources part texture spec loads
#  - SubViewport pixel diff: coin visible above the head only while owned

const BattleDrawContext := preload("res://scripts/core/battle_draw_context.gd")
const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const PlayerSpriteSocketCatalog := preload("res://scripts/characters/player_sprite_socket_catalog.gd")
const PlayerCustomizationOverlayRenderer := preload("res://scripts/characters/player_customization_overlay_renderer.gd")
const RuntimePerkVisualPartCatalog := preload("res://scripts/characters/runtime_perk_visual_part_catalog.gd")
const Stage1PlayerSpriteRenderer := preload("res://scripts/stages/stage1/stage1_player_sprite_renderer.gd")

const WALK_RIGHT_SHEET_PATH := "res://assets/sprites/smasher/smasher_rear_move_right_sd_blue_energy_glide_bodyweight_v9_4x2_160_clean.png"
const PROBE_RECT := Rect2(300.0, 500.0, 160.0, 160.0)
const PROBE_FRAME := 2

var _failures: Array[String] = []


class FakeOwner extends RefCounted:
	var selected_character_type := "smasher"
	var runtime_perk_levels: Dictionary = {}


class FakeRegistry extends RefCounted:
	func get_instance(_name: String) -> Object:
		return null


class PlayerDrawProbe extends Node2D:
	var renderer: Object = null
	var context: Dictionary = {}
	var draw_count := 0

	func _draw() -> void:
		draw_count += 1
		draw_rect(Rect2(0.0, 0.0, 760.0, 750.0), Color(0.09, 0.09, 0.13, 1.0))
		if renderer != null:
			renderer.draw(self, context, PROBE_RECT, true, PROBE_RECT.position, Vector2(155.0, 50.0), Vector2.ZERO)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_head_top_authored_for_pilot_motions()
	_verify_socket_entry_dest_rect_right()
	_verify_socket_entry_dest_rect_left_mirror()
	_verify_socket_entry_fail_closed()
	_verify_part_manifest_projection()
	_verify_context_chain_injection()
	_verify_part_texture_spec_loads()
	await _verify_part_pixel_diff()

	if _failures.is_empty():
		print("player_socket_part_overlay_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_head_top_authored_for_pilot_motions() -> void:
	var dest := Rect2(0.0, 0.0, 160.0, 160.0)
	for probe in [["walk", "right"], ["dash", "right"], ["idle", "back"], ["attack", "left"], ["attack", "right"]]:
		var sockets: Dictionary = PlayerSpriteSocketCatalog.resolve_screen_sockets("smasher", probe[0], probe[1], 0, dest)
		_expect(sockets.has("head_top"), "head_top socket should be authored for %s/%s" % [probe[0], probe[1]])


func _build_accessory_context(texture: Texture2D) -> Dictionary:
	return {
		"selected_character_type": "smasher",
		"player_customization_overlay_slots": {
			"accessory": {
				"texture": texture,
				"socket_id": "head_top",
				"socket_offset": Vector2(0.0, -15.0),
				"socket_part_size": Vector2(20.0, 20.0),
				"grid_cols": 1,
				"grid_rows": 1,
				"frame_count": 1,
				"cell_width": 64.0,
				"cell_height": 64.0,
			},
		},
	}


func _build_walk_base_plan(renderer: Object, direction: String, motion_id: String = "walk", cell: Vector2 = Vector2(160.0, 160.0)) -> Dictionary:
	return renderer.build_base_plan(
		motion_id,
		0,
		Rect2(0.0, 0.0, 160.0, 160.0),
		Rect2(0.0, 0.0, cell.x, cell.y),
		{"selected_character_type": "smasher"},
		{
			"direction": direction,
			"grid_cols": 4,
			"grid_rows": 2,
			"frame_count": 8,
			"cell_width": cell.x,
			"cell_height": cell.y,
		}
	)


func _verify_socket_entry_dest_rect_right() -> void:
	var renderer := PlayerCustomizationOverlayRenderer.new()
	var texture := _make_texture(Vector2i(64, 64), Color(1.0, 0.85, 0.2, 1.0))
	var context := _build_accessory_context(texture)
	var commands: Array = renderer.build_draw_commands(context, _build_walk_base_plan(renderer, "right"), "front")
	_expect(commands.size() == 1, "socket-anchored accessory should emit one front command for walk right")
	if commands.size() == 1:
		# v1방식 단청 walk right f0 head_top = (80.1, 32.0); offset (0,-15), size
		# 20x20 at 1:1 scale -> rect position (70.1, 7.0).
		var dest: Rect2 = (commands[0] as Dictionary).get("dest_rect", Rect2())
		_expect(dest.position.is_equal_approx(Vector2(70.1, 7.0)) and dest.size.is_equal_approx(Vector2(20.0, 20.0)), "accessory dest rect should center on head_top + offset (got %s)" % dest)
		var source: Rect2 = (commands[0] as Dictionary).get("source_rect", Rect2())
		_expect(source.size.is_equal_approx(Vector2(64.0, 64.0)), "static part should use its full 1x1 source cell, not the body grid")


func _verify_socket_entry_dest_rect_left_mirror() -> void:
	var renderer := PlayerCustomizationOverlayRenderer.new()
	var texture := _make_texture(Vector2i(64, 64), Color(1.0, 0.85, 0.2, 1.0))
	var context := _build_accessory_context(texture)
	var commands: Array = renderer.build_draw_commands(context, _build_walk_base_plan(renderer, "left"), "front")
	_expect(commands.size() == 1, "socket-anchored accessory should emit one front command for walk left")
	if commands.size() == 1:
		# Mirrored head_top x = 160 - 80.1 = 79.9 -> rect position (69.9, 7.0).
		var dest: Rect2 = (commands[0] as Dictionary).get("dest_rect", Rect2())
		_expect(dest.position.is_equal_approx(Vector2(69.9, 7.0)), "left-direction accessory should ride the mirrored head_top socket (got %s)" % dest)


func _verify_socket_entry_fail_closed() -> void:
	var renderer := PlayerCustomizationOverlayRenderer.new()
	var texture := _make_texture(Vector2i(64, 64), Color(1.0, 0.85, 0.2, 1.0))
	var context := _build_accessory_context(texture)
	var unauthored: Array = renderer.build_draw_commands(context, _build_walk_base_plan(renderer, "back", "thor_shield"), "front")
	_expect(unauthored.is_empty(), "unauthored motion should emit no accessory command (fail-closed, no guessed position)")
	var wrong_cell: Array = renderer.build_draw_commands(context, _build_walk_base_plan(renderer, "right", "attack", Vector2(344.0, 384.0)), "front")
	_expect(wrong_cell.is_empty(), "legacy cell basis should emit no accessory command (socket coordinates do not apply)")


func _verify_part_manifest_projection() -> void:
	var owned: Dictionary = RuntimePerkVisualPartCatalog.project_owned_levels({"item_luck": 2, "common_swiftness": 5})
	_expect(owned == {"item_luck": 2}, "manifest projection should keep only manifest perks with owned levels")
	_expect(RuntimePerkVisualPartCatalog.project_owned_levels({"item_luck": 0}).is_empty(), "level 0 should not project a part")


func _verify_context_chain_injection() -> void:
	var builder := BattleDrawContext.new()
	var registry := FakeRegistry.new()
	var coin := _make_texture(Vector2i(64, 64), Color(1.0, 0.85, 0.2, 1.0))

	var owner := FakeOwner.new()
	owner.runtime_perk_levels = {"item_luck": 2}
	var scene_context: Dictionary = builder.build_scene_context(owner, Vector2.ZERO, registry)
	_expect(scene_context.get("player_perk_visual_part_levels", {}) == {"item_luck": 2}, "scene context should project owned manifest perk levels")

	var actor_context: Dictionary = builder.build_actor_context({
		"selected_character_type": "smasher",
		"player_perk_visual_part_levels": {"item_luck": 2},
		"textures": {"perk_visual_part_lucky_coin": coin},
	}, {})
	var slots: Dictionary = _get_dict(actor_context.get("player_customization_overlay_slots", {}))
	_expect(slots.has("accessory"), "owned item_luck should inject the accessory part slot into the actor context")
	if slots.has("accessory"):
		_expect(str(_get_dict(slots.get("accessory")).get("socket_id", "")) == "head_top", "injected part should anchor at head_top")
	var overlay_textures: Dictionary = _get_dict(actor_context.get("player_customization_overlay_textures", {}))
	_expect(overlay_textures.get("perk_visual_part_lucky_coin", null) == coin, "actor context should expose the part texture to the overlay renderer")

	var unowned_context: Dictionary = builder.build_actor_context({
		"selected_character_type": "smasher",
		"textures": {"perk_visual_part_lucky_coin": coin},
	}, {})
	_expect(not _get_dict(unowned_context.get("player_customization_overlay_slots", {})).has("accessory"), "unowned perk should not inject the part slot")

	var user_entry := {"texture": coin, "dest_offset": Vector2(5.0, 5.0)}
	var user_priority_context: Dictionary = builder.build_actor_context({
		"selected_character_type": "smasher",
		"player_perk_visual_part_levels": {"item_luck": 2},
		"player_customization_overlay_slots": {"accessory": user_entry},
		"textures": {"perk_visual_part_lucky_coin": coin},
	}, {})
	var user_slots: Dictionary = _get_dict(user_priority_context.get("player_customization_overlay_slots", {}))
	_expect(_get_dict(user_slots.get("accessory")).has("dest_offset"), "existing user customization entry should win over the perk part injection")


func _verify_part_texture_spec_loads() -> void:
	var resources := BattleResources.new()
	var cache: Dictionary = resources.load_all({
		"selected_character_type": "smasher",
		"include_all_characters": false,
		"include_all_stages": false,
		"include_result_sheets": false,
		"current_stage": 1,
	})
	var texture: Variant = cache.get("perk_visual_part_lucky_coin", null)
	_expect(texture is Texture2D, "lucky coin part texture should load through BattleResources")
	if texture is Texture2D:
		_expect((texture as Texture2D).get_size().is_equal_approx(Vector2(1024.0, 1024.0)), "lucky coin part source should be the 1024px item art")


func _verify_part_pixel_diff() -> void:
	var walk_texture: Texture2D = load(WALK_RIGHT_SHEET_PATH)
	var coin_texture: Texture2D = load("res://assets/sprites/items/lucky_coin.png")
	_expect(walk_texture is Texture2D and coin_texture is Texture2D, "probe textures should load")
	if not (walk_texture is Texture2D and coin_texture is Texture2D):
		return

	var builder := BattleDrawContext.new()
	var part_actor_context: Dictionary = builder.build_actor_context({
		"selected_character_type": "smasher",
		"player_perk_visual_part_levels": {"item_luck": 2},
		"textures": {"perk_visual_part_lucky_coin": coin_texture},
	}, {})
	var control_actor_context: Dictionary = builder.build_actor_context({
		"selected_character_type": "smasher",
		"textures": {"perk_visual_part_lucky_coin": coin_texture},
	}, {})

	var part_capture: Dictionary = await _render_probe(_probe_context_from(part_actor_context, walk_texture))
	var control_capture: Dictionary = await _render_probe(_probe_context_from(control_actor_context, walk_texture))
	_expect(int(part_capture.get("draw_count", 0)) > 0, "probe should execute a real draw pass")

	var headless := OS.get_cmdline_args().has("--headless") or DisplayServer.get_name().to_lower().find("headless") >= 0
	if not headless:
		var part_image: Image = part_capture.get("image")
		var control_image: Image = control_capture.get("image")
		if part_image != null and not part_image.is_empty():
			var save_err: int = part_image.save_png("user://player_socket_part_qa.png")
			if save_err == OK:
				print("player_socket_part_qa: saved ", ProjectSettings.globalize_path("user://player_socket_part_qa.png"))
		if part_image != null and control_image != null:
			var sockets: Dictionary = PlayerSpriteSocketCatalog.resolve_screen_sockets("smasher", "walk", "right", PROBE_FRAME, PROBE_RECT)
			var head_top: Vector2 = sockets.get("head_top", Vector2.ZERO)
			var sample := Vector2i(int(head_top.x), int(head_top.y - 15.0))
			var part_px: Color = part_image.get_pixelv(sample)
			var control_px: Color = control_image.get_pixelv(sample)
			var delta: float = absf(part_px.r - control_px.r) + absf(part_px.g - control_px.g) + absf(part_px.b - control_px.b)
			_expect(delta > 0.15, "windowed pixel QA: the coin part should paint above the head only while owned (delta %.3f at %s)" % [delta, sample])


func _probe_context_from(actor_context: Dictionary, walk_texture: Texture2D) -> Dictionary:
	var context: Dictionary = actor_context.duplicate()
	context["player_walk_direction"] = 1
	context["player_walk_right_texture"] = walk_texture
	context["player_sprite_frame"] = PROBE_FRAME
	context["stage1_player_silhouette_rim_enabled"] = false
	return context


func _render_probe(context: Dictionary) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(760, 750)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	var probe := PlayerDrawProbe.new()
	probe.renderer = Stage1PlayerSpriteRenderer.new()
	probe.context = context
	viewport.add_child(probe)
	probe.queue_redraw()
	for _frame in range(4):
		await process_frame

	var image: Image = null
	var headless := OS.get_cmdline_args().has("--headless") or DisplayServer.get_name().to_lower().find("headless") >= 0
	if not headless:
		var texture := viewport.get_texture()
		if texture != null:
			image = texture.get_image()
			if image != null and not image.is_empty() and image.get_format() != Image.FORMAT_RGBA8:
				image.convert(Image.FORMAT_RGBA8)

	viewport.queue_free()
	return {"image": image, "draw_count": probe.draw_count}


func _make_texture(size: Vector2i, color: Color) -> Texture2D:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
