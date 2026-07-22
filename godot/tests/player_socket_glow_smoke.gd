extends SceneTree

# Socket-composition pilot seal: per-frame sprite sockets + perk-gated
# under-board glow.
#
# Legs:
#  - catalog math: cell-local -> screen mapping, left mirror + id swap,
#    idle "back" -> "any" fallback, per-direction authored attack data,
#    fail-closed resolution, frame clamp
#  - glow renderer: perk-level gate, layer command shape, level scaling,
#    cell-basis guard, debug marker gate
#  - context chain: DEFAULT_VALUES declaration, real scene-context owner
#    projection (divergent perk level), actor-context pass-through
#  - funnel: real stage1_player_sprite_renderer.draw() inside a SubViewport
#    probe with a recording spy (headless-safe), plus a windowed pixel diff
#    (glow on vs off) at the resolved socket position.

const BattleDrawContext := preload("res://scripts/core/battle_draw_context.gd")
const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")
const PlayerSpriteSocketCatalog := preload("res://scripts/characters/player_sprite_socket_catalog.gd")
const PlayerSocketGlowRenderer := preload("res://scripts/characters/player_socket_glow_renderer.gd")
const Stage1PlayerSpriteRenderer := preload("res://scripts/stages/stage1/stage1_player_sprite_renderer.gd")

const WALK_RIGHT_SHEET_PATH := "res://assets/sprites/smasher/smasher_rear_move_right_sd_blue_energy_glide_bodyweight_v9_4x2_160_clean.png"
const PROBE_RECT := Rect2(300.0, 500.0, 160.0, 160.0)
const PROBE_FRAME := 2

var _failures: Array[String] = []


class FakeOwner extends RefCounted:
	var selected_character_type := "smasher"
	var runtime_perk_levels: Dictionary = {}
	var player_socket_debug_overlay_enabled := false


class FakeRegistry extends RefCounted:
	func get_instance(_name: String) -> Object:
		return null


class SpyGlowRenderer extends RefCounted:
	var forward: Object = PlayerSocketGlowRenderer.new()
	var under_glow_calls: Array = []
	var debug_marker_calls: Array = []

	func draw_under_glow(canvas: CanvasItem, context: Dictionary, motion_id: String, frame_index: int, direction: String, dest_rect: Rect2, cell_size: Vector2 = Vector2.ZERO) -> void:
		under_glow_calls.append({
			"motion_id": motion_id,
			"frame_index": frame_index,
			"direction": direction,
			"dest_rect": dest_rect,
			"cell_size": cell_size,
		})
		forward.draw_under_glow(canvas, context, motion_id, frame_index, direction, dest_rect, cell_size)

	func draw_debug_markers(canvas: CanvasItem, context: Dictionary, motion_id: String, frame_index: int, direction: String, dest_rect: Rect2, cell_size: Vector2 = Vector2.ZERO) -> void:
		debug_marker_calls.append({"motion_id": motion_id, "frame_index": frame_index})
		forward.draw_debug_markers(canvas, context, motion_id, frame_index, direction, dest_rect, cell_size)


class PlayerDrawProbe extends Node2D:
	var renderer: Object = null
	var context: Dictionary = {}
	var draw_count := 0

	func _draw() -> void:
		draw_count += 1
		# Opaque arena-tone backdrop so the additive glow composites the same
		# way it does over the real stage floor (transparent-bg captures
		# misrepresent additive layers).
		draw_rect(Rect2(0.0, 0.0, 760.0, 750.0), Color(0.09, 0.09, 0.13, 1.0))
		if renderer != null:
			renderer.draw(self, context, PROBE_RECT, true, PROBE_RECT.position, Vector2(155.0, 50.0), Vector2.ZERO)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_catalog_walk_right_mapping()
	_verify_catalog_left_mirror_swaps_ids()
	_verify_catalog_idle_back_falls_to_any()
	_verify_catalog_attack_uses_authored_left_data()
	_verify_catalog_fail_closed()
	_verify_catalog_frame_clamp()
	_verify_glow_perk_level_gate_and_shape()
	_verify_glow_level_scaling()
	_verify_glow_cell_basis_guard()
	_verify_debug_marker_gate()
	_verify_owner_schema_declaration()
	_verify_scene_context_projection()
	_verify_actor_context_pass_through()
	await _verify_funnel_integration()

	if _failures.is_empty():
		print("player_socket_glow_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_catalog_walk_right_mapping() -> void:
	# 한미량 v1방식 단청(소품통일) walk right f0 foot_l=(57,128), foot_r=(106,128).
	var dest := Rect2(100.0, 200.0, 80.0, 80.0)
	var sockets: Dictionary = PlayerSpriteSocketCatalog.resolve_screen_sockets("smasher", "walk", "right", 0, dest)
	_expect(sockets.has("foot_l") and sockets.has("foot_r"), "walk right f0 should resolve both foot sockets")
	_expect_vec(sockets.get("foot_l", Vector2.ZERO), Vector2(100.0 + 57.0 / 160.0 * 80.0, 200.0 + 128.0 / 160.0 * 80.0), "walk right f0 foot_l should map cell-local px into the dest rect")
	_expect_vec(sockets.get("foot_r", Vector2.ZERO), Vector2(100.0 + 106.0 / 160.0 * 80.0, 200.0 + 128.0 / 160.0 * 80.0), "walk right f0 foot_r should map cell-local px into the dest rect")


func _verify_catalog_left_mirror_swaps_ids() -> void:
	# Left sheets are mirrors of right: x flips AND _l/_r ids swap so foot_l
	# stays the screen-left socket. right f0 foot_l=57/foot_r=106.
	var dest := Rect2(0.0, 0.0, 160.0, 160.0)
	var sockets: Dictionary = PlayerSpriteSocketCatalog.resolve_screen_sockets("smasher", "walk", "left", 0, dest)
	_expect(sockets.has("foot_l") and sockets.has("foot_r"), "walk left f0 should resolve mirrored sockets")
	_expect_vec(sockets.get("foot_l", Vector2.ZERO), Vector2(160.0 - 106.0, 128.0), "walk left foot_l should be the mirrored right-sheet foot_r")
	_expect_vec(sockets.get("foot_r", Vector2.ZERO), Vector2(160.0 - 57.0, 128.0), "walk left foot_r should be the mirrored right-sheet foot_l")
	var foot_l: Vector2 = sockets.get("foot_l", Vector2.ZERO)
	var foot_r: Vector2 = sockets.get("foot_r", Vector2.ZERO)
	_expect(foot_l.x < foot_r.x, "mirrored socket ids must keep foot_l on the screen-left side")


func _verify_catalog_idle_back_falls_to_any() -> void:
	var dest := Rect2(0.0, 0.0, 160.0, 160.0)
	var sockets: Dictionary = PlayerSpriteSocketCatalog.resolve_screen_sockets("smasher", "idle", "back", 0, dest)
	_expect_vec(sockets.get("foot_l", Vector2.ZERO), Vector2(55.0, 129.0), "idle direction 'back' should fall back to the authored 'any' data")


func _verify_catalog_attack_uses_authored_left_data() -> void:
	# Attack left is independently authored (f0 foot_l y=124); a mirror of the
	# right sheet would land at y=125.
	var dest := Rect2(0.0, 0.0, 160.0, 160.0)
	var sockets: Dictionary = PlayerSpriteSocketCatalog.resolve_screen_sockets("smasher", "attack", "left", 0, dest)
	_expect_vec(sockets.get("foot_l", Vector2.ZERO), Vector2(55.0, 124.0), "attack left should use its own authored data, not a mirror of right")


func _verify_catalog_fail_closed() -> void:
	var dest := Rect2(0.0, 0.0, 160.0, 160.0)
	_expect(PlayerSpriteSocketCatalog.resolve_screen_sockets("viper", "walk", "right", 0, dest).is_empty(), "unknown character should resolve to empty (fail-closed)")
	_expect(PlayerSpriteSocketCatalog.resolve_screen_sockets("smasher", "thor_shield", "back", 0, dest).is_empty(), "motion without authored data should resolve to empty (fail-closed)")
	_expect(PlayerSpriteSocketCatalog.resolve_screen_sockets("smasher", "walk", "right", 0, Rect2()).is_empty(), "zero-size dest rect should resolve to empty")


func _verify_catalog_frame_clamp() -> void:
	var dest := Rect2(0.0, 0.0, 160.0, 160.0)
	var last: Dictionary = PlayerSpriteSocketCatalog.resolve_screen_sockets("smasher", "walk", "right", 7, dest)
	var overflow: Dictionary = PlayerSpriteSocketCatalog.resolve_screen_sockets("smasher", "walk", "right", 99, dest)
	_expect(not last.is_empty() and overflow == last, "overflowing frame index should clamp to the last authored frame")


func _verify_glow_perk_level_gate_and_shape() -> void:
	var renderer := PlayerSocketGlowRenderer.new()
	var base_context := {"selected_character_type": "smasher", "player_anim_clock": 1.25}
	var off_context := base_context.duplicate()
	off_context["player_socket_glow_perk_level"] = 0
	_expect(renderer.build_draw_commands(off_context, "walk", 0, "right", PROBE_RECT).is_empty(), "perk level 0 should emit no glow commands")

	var on_context := base_context.duplicate()
	on_context["player_socket_glow_perk_level"] = 3
	var commands: Array = renderer.build_draw_commands(on_context, "walk", 0, "right", PROBE_RECT)
	var expected_commands: int = 2 * PlayerSocketGlowRenderer.GLOW_LAYERS.size()
	_expect(commands.size() == expected_commands, "level 3 walk glow should emit one command per socket per layer")
	var sockets: Dictionary = PlayerSpriteSocketCatalog.resolve_screen_sockets("smasher", "walk", "right", 0, PROBE_RECT)
	var foot_l: Vector2 = sockets.get("foot_l", Vector2.ZERO)
	var anchored := 0
	for command in commands:
		var command_dict: Dictionary = command
		var color: Color = command_dict.get("color", Color.TRANSPARENT)
		_expect(color.a > 0.0, "glow command alpha should be positive")
		if str(command_dict.get("socket_id", "")) == "foot_l":
			var pos: Vector2 = command_dict.get("pos", Vector2.ZERO)
			_expect(absf(pos.x - foot_l.x) < 0.01, "foot_l glow layers should anchor at the resolved socket x")
			anchored += 1
	_expect(anchored == PlayerSocketGlowRenderer.GLOW_LAYERS.size(), "every glow layer of foot_l should anchor at its socket")


func _verify_glow_level_scaling() -> void:
	var renderer := PlayerSocketGlowRenderer.new()
	var context_level1 := {"selected_character_type": "smasher", "player_socket_glow_perk_level": 1}
	var context_level5 := {"selected_character_type": "smasher", "player_socket_glow_perk_level": 5}
	var radius_level1: float = _max_command_radius(renderer.build_draw_commands(context_level1, "walk", 0, "right", PROBE_RECT))
	var radius_level5: float = _max_command_radius(renderer.build_draw_commands(context_level5, "walk", 0, "right", PROBE_RECT))
	_expect(radius_level5 > radius_level1, "glow radius should scale with perk level (Lv.5 > Lv.1)")


func _verify_glow_cell_basis_guard() -> void:
	var renderer := PlayerSocketGlowRenderer.new()
	var context := {"selected_character_type": "smasher", "player_socket_glow_perk_level": 2}
	_expect(renderer.build_draw_commands(context, "attack", 0, "right", PROBE_RECT, Vector2(344.0, 384.0)).is_empty(), "legacy 344x384 attack cells should fail the cell-basis guard and skip")
	_expect(not renderer.build_draw_commands(context, "attack", 0, "right", PROBE_RECT, Vector2(160.0, 160.0)).is_empty(), "authored 160px cells should pass the cell-basis guard")
	_expect(not renderer.build_draw_commands(context, "attack", 0, "right", PROBE_RECT).is_empty(), "unspecified cell size should not block resolution")


func _verify_debug_marker_gate() -> void:
	var renderer := PlayerSocketGlowRenderer.new()
	var off_context := {"selected_character_type": "smasher"}
	_expect(renderer.build_debug_marker_commands(off_context, "walk", 0, "right", PROBE_RECT).is_empty(), "debug markers should stay off without the debug flag")
	var on_context := {"selected_character_type": "smasher", "player_socket_debug_overlay_enabled": true}
	var commands: Array = renderer.build_debug_marker_commands(on_context, "walk", 0, "right", PROBE_RECT)
	var socket_count: int = PlayerSpriteSocketCatalog.resolve_screen_sockets("smasher", "walk", "right", 0, PROBE_RECT).size()
	_expect(socket_count > 0 and commands.size() == socket_count * 2, "debug markers should emit 2 crosshair lines per resolved socket")


func _verify_owner_schema_declaration() -> void:
	_expect(BattleSceneState.DEFAULT_VALUES.has("player_socket_debug_overlay_enabled"), "player_socket_debug_overlay_enabled must be declared in BattleSceneState.DEFAULT_VALUES (owner.set on undeclared keys is a silent no-op)")
	var state := BattleSceneState.new()
	state.set_value("player_socket_debug_overlay_enabled", true)
	_expect(bool(state.get_value("player_socket_debug_overlay_enabled")) == true, "declared socket debug flag should round-trip through the schema-gated owner")


func _verify_scene_context_projection() -> void:
	var builder := BattleDrawContext.new()
	var registry := FakeRegistry.new()
	var owner := FakeOwner.new()
	owner.runtime_perk_levels = {"common_swiftness": 3}
	owner.player_socket_debug_overlay_enabled = true
	var context: Dictionary = builder.build_scene_context(owner, Vector2.ZERO, registry)
	_expect(int(context.get("player_socket_glow_perk_level", -1)) == 3, "scene context should project the owned common_swiftness (신속) level to the glow scalar (divergent case)")
	_expect(bool(context.get("player_socket_debug_overlay_enabled", false)) == true, "scene context should carry the socket debug flag from the owner")

	var bare_owner := FakeOwner.new()
	var bare_context: Dictionary = builder.build_scene_context(bare_owner, Vector2.ZERO, registry)
	_expect(int(bare_context.get("player_socket_glow_perk_level", -1)) == 0, "scene context should default the glow scalar to 0 when the perk is not owned")


func _verify_actor_context_pass_through() -> void:
	var builder := BattleDrawContext.new()
	var actor_context: Dictionary = builder.build_actor_context({
		"selected_character_type": "smasher",
		"player_socket_glow_perk_level": 4,
		"player_socket_debug_overlay_enabled": true,
	}, {})
	_expect(int(actor_context.get("player_socket_glow_perk_level", -1)) == 4, "actor context should pass the glow perk level through to stage renderers")
	_expect(bool(actor_context.get("player_socket_debug_overlay_enabled", false)) == true, "actor context should pass the socket debug flag through to stage renderers")


func _verify_funnel_integration() -> void:
	var walk_texture: Texture2D = load(WALK_RIGHT_SHEET_PATH)
	_expect(walk_texture is Texture2D, "smasher walk right sheet should load for the funnel probe")
	if not (walk_texture is Texture2D):
		return

	var glow_context := {
		"selected_character_type": "smasher",
		"player_socket_glow_perk_level": 3,
		"player_walk_direction": 1,
		"player_walk_right_texture": walk_texture,
		"player_sprite_frame": PROBE_FRAME,
		"player_anim_clock": 0.0,
		"stage1_player_silhouette_rim_enabled": false,
	}
	var control_context := glow_context.duplicate()
	control_context["player_socket_glow_perk_level"] = 0

	var glow_capture: Dictionary = await _render_probe(glow_context)
	var control_capture: Dictionary = await _render_probe(control_context)

	var glow_spy: SpyGlowRenderer = glow_capture.get("spy")
	_expect(glow_spy.under_glow_calls.size() > 0, "real player draw should route through the socket glow renderer")
	if glow_spy.under_glow_calls.size() > 0:
		var call: Dictionary = glow_spy.under_glow_calls[0]
		_expect(str(call.get("motion_id", "")) == "walk", "funnel should pass the walk motion id to the glow renderer")
		_expect(int(call.get("frame_index", -1)) == PROBE_FRAME, "funnel should pass the live sprite frame to the glow renderer")
		_expect(str(call.get("direction", "")) == "right", "funnel should pass the walk direction to the glow renderer")
		_expect(call.get("dest_rect", Rect2()) == PROBE_RECT, "funnel should pass the body dest rect so glow inherits shake/scale")
		_expect(call.get("cell_size", Vector2.ZERO) == Vector2(160.0, 160.0), "funnel should forward the sheet cell basis for the mismatch guard")

	var headless := OS.get_cmdline_args().has("--headless") or DisplayServer.get_name().to_lower().find("headless") >= 0
	if not headless:
		var glow_image: Image = glow_capture.get("image")
		var control_image: Image = control_capture.get("image")
		if glow_image != null and not glow_image.is_empty():
			var save_err: int = glow_image.save_png("user://player_socket_glow_qa.png")
			if save_err == OK:
				print("player_socket_glow_qa: saved ", ProjectSettings.globalize_path("user://player_socket_glow_qa.png"))
		if glow_image != null and control_image != null:
			var sockets: Dictionary = PlayerSpriteSocketCatalog.resolve_screen_sockets("smasher", "walk", "right", PROBE_FRAME, PROBE_RECT)
			var foot_l: Vector2 = sockets.get("foot_l", Vector2.ZERO)
			var sample := Vector2i(int(foot_l.x), int(foot_l.y) + 9)
			var glow_px: Color = glow_image.get_pixelv(sample)
			var control_px: Color = control_image.get_pixelv(sample)
			var glow_luminance: float = glow_px.r * 0.30 + glow_px.g * 0.55 + glow_px.b * 0.15
			var control_luminance: float = control_px.r * 0.30 + control_px.g * 0.55 + control_px.b * 0.15
			_expect(
				glow_luminance > control_luminance + 0.05,
				"windowed pixel QA: additive glow should be visibly brighter than the glow-off control at the socket sample point (%.3f vs %.3f)" % [glow_luminance, control_luminance]
			)


func _render_probe(context: Dictionary) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(760, 750)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	var probe := PlayerDrawProbe.new()
	var renderer := Stage1PlayerSpriteRenderer.new()
	var spy := SpyGlowRenderer.new()
	renderer.socket_glow_renderer = spy
	probe.renderer = renderer
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
	return {"spy": spy, "image": image, "draw_count": probe.draw_count}


func _max_command_radius(commands: Array) -> float:
	var max_radius := 0.0
	for command in commands:
		if command is Dictionary:
			max_radius = maxf(max_radius, float((command as Dictionary).get("radius", 0.0)))
	return max_radius


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_vec(actual: Vector2, expected: Vector2, message: String) -> void:
	if not actual.is_equal_approx(expected):
		_failures.append("%s (expected %s, got %s)" % [message, expected, actual])
