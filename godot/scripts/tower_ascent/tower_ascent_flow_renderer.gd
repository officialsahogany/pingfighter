extends RefCounted

const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)
const TowerAscentMapOverlayLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_map_overlay_localization.gd"
)
const PlazaInteriorRoomRenderer := preload(
	"res://scripts/plaza/plaza_interior_room_renderer.gd"
)
const CommonStarpointVisualHost := preload(
	"res://scripts/effects/common_starpoint_visual_host.gd"
)
const TowerAscentMapIconography := preload(
	"res://scripts/tower_ascent/tower_ascent_map_iconography.gd"
)
const TowerAscentMapCameraModel := preload(
	"res://scripts/tower_ascent/tower_ascent_map_camera_model.gd"
)
const TowerAscentRouteWindPolicy := preload(
	"res://scripts/tower_ascent/tower_ascent_route_wind_policy.gd"
)
const TowerAscentRoutePickupState := preload(
	"res://scripts/tower_ascent/tower_ascent_route_pickup_state.gd"
)
const TowerAscentMapPathGeometry := preload(
	"res://scripts/tower_ascent/tower_ascent_map_path_geometry.gd"
)
const TowerAscentMapCloudLayer := preload(
	"res://scripts/tower_ascent/tower_ascent_map_cloud_layer.gd"
)
const TowerAscentFloorTitleCatalog := preload(
	"res://scripts/tower_ascent/tower_ascent_floor_title_catalog.gd"
)
const TowerMapScrollAssetCatalog := preload(
	"res://scripts/tower_ascent/tower_map_scroll_asset_catalog.gd"
)
const ProjectResourceLoader := preload(
	"res://scripts/resources/project_resource_loader.gd"
)
const WeatherEventRenderer := preload(
	"res://scripts/stages/common/weather_event_renderer.gd"
)

const ROUTE_AIM_GAUGE_FAN_PATH := (
	"res://assets/sprites/tower/route_aim_gauge_fan_imagegen_v1.png"
)
const ROUTE_AIM_GAUGE_ARROW_PATH := (
	"res://assets/sprites/tower/route_aim_gauge_arrow_imagegen_v1.png"
)
const ROUTE_AIM_GAUGE_FAN_TEXTURE := preload(
	"res://assets/sprites/tower/route_aim_gauge_fan_imagegen_v1.png"
)
const ROUTE_AIM_GAUGE_ARROW_TEXTURE := preload(
	"res://assets/sprites/tower/route_aim_gauge_arrow_imagegen_v1.png"
)
const ROUTE_WIND_VANE_ATLAS_PATH := (
	"res://assets/sprites/tower/route_wind_vane_imagegen_v4b_atlas.png"
)
const ROUTE_WIND_VANE_ATLAS_COLS := 7
const ROUTE_WIND_VANE_ATLAS_ROWS := 1
const ROUTE_WIND_VANE_ATLAS_FRAMES := 7
const ROUTE_WIND_VANE_FRAME_SIZE := Vector2i(112, 36)
const ROUTE_WIND_VANE_FRAME_CALM := 0
const ROUTE_WIND_VANE_FRAME_LEFT_WEAK := 1
const ROUTE_WIND_VANE_FRAME_LEFT_MEDIUM := 2
const ROUTE_WIND_VANE_FRAME_LEFT_STRONG := 3
const ROUTE_WIND_VANE_FRAME_RIGHT_WEAK := 4
const ROUTE_WIND_VANE_FRAME_RIGHT_MEDIUM := 5
const ROUTE_WIND_VANE_FRAME_RIGHT_STRONG := 6
const ROUTE_PICKUP_BAG_TEXTURE := preload(
	"res://assets/sprites/perks/item_bag_expansion_perk_icon.png"
)
const TRAINING_DUMMY_TEXTURE_PATH := (
	"res://assets/sprites/tower/noncombat/training_dummy_imagegen_v1.png"
)
const TRAINING_DUMMY_TEXTURE_SIZE := Vector2i(256, 256)
const TRAINING_DUMMY_TEXTURE_PIVOT := Vector2(128.0, 236.0)
const TRAINING_DUMMY_VISIBLE_BOUNDS := Rect2i(54, 64, 148, 172)
const TRAINING_DUMMY_FLOOR_OFFSET_PX := 13.0

const NODE_ART_PATHS := {
	"boss": "res://assets/sprites/stage1/dalji/dalji_boss_portrait_2x2.png",
	"combat": "res://assets/sprites/stage1/dalji/dalji_boss_portrait_2x2.png",
	"enraged": "res://assets/sprites/stage1/dalji/dalji_boss_portrait_2x2.png",
	"shop": "res://assets/ui/plaza/interior/plaza_shop_strewn_coin_pile_autosprite_static_v1.png",
	"training": "res://assets/sprites/perks/common_training_perk_icon.png",
	"fallen_monk": "res://assets/sprites/perks/soul_summon_art_manual_icon.png",
	"guardian_spring": "res://assets/sprites/lingpet/guardian_spirit_egg_traditional_item_icon_v1.png",
	"rest": "res://assets/sprites/items/campfire_icon_hq_v1.png",
}
const NODE_ART_TEXTURES := {
	"boss": preload("res://assets/sprites/stage1/dalji/dalji_boss_portrait_2x2.png"),
	"combat": preload("res://assets/sprites/stage1/dalji/dalji_boss_portrait_2x2.png"),
	"enraged": preload("res://assets/sprites/stage1/dalji/dalji_boss_portrait_2x2.png"),
	"shop": preload("res://assets/ui/plaza/interior/plaza_shop_strewn_coin_pile_autosprite_static_v1.png"),
	"training": preload("res://assets/sprites/perks/common_training_perk_icon.png"),
	"fallen_monk": preload("res://assets/sprites/perks/soul_summon_art_manual_icon.png"),
	"guardian_spring": preload("res://assets/sprites/lingpet/guardian_spirit_egg_traditional_item_icon_v1.png"),
	"rest": preload("res://assets/sprites/items/campfire_icon_hq_v1.png"),
}
const BOSS_ART_GRID := Vector2i(2, 2)

const PLAYFIELD_SIZE := Vector2(760.0, 750.0)
const MAP_RECT := Rect2(34.0, 24.0, 692.0, 702.0)
const MAP_SCROLL_TILE_SIZE := Vector2(692.0, 320.0)
const MAP_SCROLL_ROW_PITCH := 160.0
const MAP_SCROLL_NODE_ART_SIZE := 32.0
const MAP_SCROLL_ROUTE_BRUSH_WIDTH := 18.0
const MAP_SCROLL_ROUTE_BRUSH_TILE_LENGTH := (
	MAP_SCROLL_ROUTE_BRUSH_WIDTH * 320.0 / 72.0
)
const MAP_SCROLL_ROUTE_BRUSH_TILE_STRIDE := 28.0
const MAP_SCROLL_ROUTE_ENDPOINT_CLEARANCE_RATIO := 0.42
const MAP_SCROLL_PLAQUE_SIZE := Vector2(184.0, 24.0)
const MODAL_RECT := Rect2(24.0, 28.0, 712.0, 694.0)
const MAP_NODE_RADIUS := 6.0
const ACTIVE_NODE_RADIUS := 13.0
const BALANCE_ROW_RECT := Rect2(170.0, 106.0, 420.0, 34.0)
const BALANCE_ENTRY_GAP := 36.0
const BALANCE_ICON_SIZE := 20.0
const BALANCE_ICON_LEFT_PAD := 12.0
const BALANCE_TEXT_GAP := 10.0
const BALANCE_FONT_SIZE := 18.0
const BALANCE_TEXT_OUTLINE_SIZE := 2.0
const LAYOUT_FLAG_TRAINING_STAGE := "training_stage"
const LAYOUT_FLAG_HERO_CARD := "hero_card"
const LAYOUT_FLAG_PAGE_CONTROLS := "page_controls"

const INK := Color("30271f")
const INK_SOFT := Color("665343")
const PAPER := Color("f1dfb8")
const PAPER_DEEP := Color("d7bd88")
const CINNABAR := Color("9e352d")
const CINNABAR_DARK := Color("63241f")
const GOLD := Color("bd8c35")
const SEALED := Color("5e5145")
const MAP_SURROUND_HUMAN := Color(0.018, 0.012, 0.01, 1.0)
const MAP_SURROUND_IMMORTAL := Color(0.018, 0.03, 0.035, 1.0)
const MAP_SCROLL_EDGE_INK_SCREEN_PX := 6.0
const MAP_SCROLL_EDGE_GAP_RATIO := 0.08
const SUBCOVER_ZOOM_EPSILON := 0.0001

var _cached_graph_key := ""
var _cached_render_model: Dictionary = {}
var _cached_fullscreen_key := ""
var _cached_fullscreen_model: Dictionary = {}
var _last_fullscreen_model: Dictionary = {}
var _graph_cache_build_count := 0
var _fullscreen_cache_build_count := 0
var _path_cache_build_count := 0
var _path_cached_dot_count := 0
var _path_cached_dot_gap := 0.0
var _path_cached_brush_segment_count := 0
var _map_iconography := TowerAscentMapIconography.new()
var _map_cloud_layer := TowerAscentMapCloudLayer.new()
var _route_wind_vane_atlas_texture: Texture2D = null
var _training_dummy_texture: Texture2D = null
var _route_wind_effect_renderer: Object = WeatherEventRenderer.new()


func _init() -> void:
	_route_wind_vane_atlas_texture = ProjectResourceLoader.load_imported_texture(
		ROUTE_WIND_VANE_ATLAS_PATH,
		"Tower route wind-vane atlas is missing; using the procedural fallback",
		"Tower route wind-vane atlas failed to load; using the procedural fallback"
	)
	_route_wind_effect_renderer.prewarm_wind_assets()
	prewarm_training_dummy_asset()


func prewarm_training_dummy_asset() -> void:
	# Flow state owns this renderer before a node modal can draw. Resolve the
	# approved bitmap here so neither the idle modal nor a strike frame performs
	# file lookup, decoding, or cache insertion.
	_training_dummy_texture = ProjectResourceLoader.load_imported_texture(
		TRAINING_DUMMY_TEXTURE_PATH,
		"Tower training dummy bitmap is missing; using the procedural fallback",
		"Tower training dummy bitmap failed to load; using the procedural fallback"
	)


func get_training_dummy_asset_paths() -> PackedStringArray:
	return PackedStringArray([TRAINING_DUMMY_TEXTURE_PATH])


func get_training_dummy_asset_contract() -> Dictionary:
	return {
		"path": TRAINING_DUMMY_TEXTURE_PATH,
		"texture_size": TRAINING_DUMMY_TEXTURE_SIZE,
		"pivot": TRAINING_DUMMY_TEXTURE_PIVOT,
		"visible_bounds": TRAINING_DUMMY_VISIBLE_BOUNDS,
		"floor_offset_px": TRAINING_DUMMY_FLOOR_OFFSET_PX,
	}


func get_training_dummy_asset_debug_state() -> Dictionary:
	return {
		"loaded": _training_dummy_texture != null,
		"render_mode": "bitmap" if _training_dummy_texture != null else "procedural_fallback",
		"texture_size": (
			Vector2i(_training_dummy_texture.get_size())
			if _training_dummy_texture != null
			else Vector2i.ZERO
		),
		"texture_class": (
			_training_dummy_texture.get_class()
			if _training_dummy_texture != null
			else ""
		),
	}


func debug_set_training_dummy_texture(texture: Variant) -> void:
	_training_dummy_texture = texture as Texture2D if texture is Texture2D else null


func get_route_aim_gauge_asset_paths() -> PackedStringArray:
	return PackedStringArray([
		ROUTE_AIM_GAUGE_FAN_PATH,
		ROUTE_AIM_GAUGE_ARROW_PATH,
	])


static func surround_color_for_realm(realm_kind: String) -> Color:
	return MAP_SURROUND_IMMORTAL if realm_kind == "immortal_realm" else MAP_SURROUND_HUMAN


func get_route_wind_vane_asset_paths() -> PackedStringArray:
	return PackedStringArray([ROUTE_WIND_VANE_ATLAS_PATH])


func get_route_wind_vane_asset_contract() -> Dictionary:
	return {
		"path": ROUTE_WIND_VANE_ATLAS_PATH,
		"cols": ROUTE_WIND_VANE_ATLAS_COLS,
		"rows": ROUTE_WIND_VANE_ATLAS_ROWS,
		"frames": ROUTE_WIND_VANE_ATLAS_FRAMES,
		"frame_size": ROUTE_WIND_VANE_FRAME_SIZE,
		"texture_size": Vector2i(
			ROUTE_WIND_VANE_FRAME_SIZE.x * ROUTE_WIND_VANE_ATLAS_COLS,
			ROUTE_WIND_VANE_FRAME_SIZE.y * ROUTE_WIND_VANE_ATLAS_ROWS
		),
		"frame_order": PackedStringArray([
			"calm",
			"left_weak",
			"left_medium",
			"left_strong",
			"right_weak",
			"right_medium",
			"right_strong",
		]),
	}


func get_route_wind_vane_asset_debug_state() -> Dictionary:
	return {
		"loaded": _route_wind_vane_atlas_texture != null,
		"texture_size": (
			Vector2i(_route_wind_vane_atlas_texture.get_size())
			if _route_wind_vane_atlas_texture != null
			else Vector2i.ZERO
		),
		"texture_class": (
			_route_wind_vane_atlas_texture.get_class()
			if _route_wind_vane_atlas_texture != null
			else ""
		),
	}


func debug_set_route_wind_vane_atlas_texture(texture: Variant) -> void:
	_route_wind_vane_atlas_texture = texture as Texture2D if texture is Texture2D else null


func draw(canvas: CanvasItem, flow: Object) -> void:
	if canvas == null or flow == null or not flow.has_method("is_active") or not bool(flow.is_active()):
		return
	var phase_name := str(flow.get_phase_name())
	if phase_name == "NODE_MODAL":
		_draw_node_modal(canvas, flow)
		return
	if phase_name == "ROUTE_AIM":
		_draw_route_aim(canvas, flow)
		return
	if phase_name == "MAP_OVERLAY":
		_draw_map_surface(canvas, flow, true)
		return
	if phase_name == "MAP_TRANSITION":
		_draw_map_surface(canvas, flow)
		_draw_map_transition(canvas, flow)
		return
	if phase_name == "FAKE_ENDING_TEASER":
		_draw_fake_ending_teaser(canvas, flow)
	elif phase_name == "ENDING_CHOICE":
		_draw_ending_choice(canvas, flow)
	elif phase_name == "RUN_SETTLEMENT":
		_draw_run_settlement(canvas, flow)
	elif phase_name == "GAUNTLET_TRANSITION":
		_draw_gauntlet_transition(canvas, flow)


func draw_fullscreen_map(
	canvas: CanvasItem,
	flow: Object,
	fallback_rect: Rect2 = Rect2(),
	walker_model: Dictionary = {}
) -> void:
	if canvas == null or flow == null:
		return
	if flow.has_method("should_draw_fullscreen_map") and not bool(flow.should_draw_fullscreen_map()):
		return
	var viewport_rect := resolve_fullscreen_rect(canvas, fallback_rect)
	if viewport_rect.size.x <= 0.0 or viewport_rect.size.y <= 0.0:
		return
	var model := build_fullscreen_map_model(flow, viewport_rect)
	if model.is_empty():
		return
	_draw_fullscreen_map_model(canvas, flow, model, walker_model)


func draw_fullscreen_surface(
	canvas: CanvasItem,
	flow: Object,
	fallback_rect: Rect2 = Rect2(),
	walker_model: Dictionary = {}
) -> void:
	if flow == null or not flow.has_method("get_phase_name"):
		return
	if str(flow.get_phase_name()) == "NODE_MODAL":
		draw_fullscreen_node_modal(canvas, flow, fallback_rect)
		return
	draw_fullscreen_map(canvas, flow, fallback_rect, walker_model)


func draw_fullscreen_node_modal(
	canvas: CanvasItem,
	flow: Object,
	fallback_rect: Rect2 = Rect2()
) -> void:
	if canvas == null or flow == null:
		return
	var viewport_rect := resolve_fullscreen_rect(canvas, fallback_rect)
	if viewport_rect.size.x <= 0.0 or viewport_rect.size.y <= 0.0:
		return
	var model: Dictionary = (
		flow.get_node_modal_view_model(viewport_rect.size)
		if flow.has_method("get_node_modal_view_model")
		else {}
	)
	if model.is_empty():
		return
	var node_kind := str(model.get(
		"node_kind",
		flow.get_node_modal_kind() if flow.has_method("get_node_modal_kind") else "common_shell"
	))
	var owns_background_contract := flow.has_method(
		"get_retained_noncombat_node_background_resolution"
	)
	var render_context: Dictionary = (
		flow.get_node_modal_render_context()
		if flow.has_method("get_node_modal_render_context")
		else {}
	)
	var background_model := build_noncombat_node_background_model(flow, viewport_rect)
	if background_model.is_empty():
		# Compatibility fixtures without the S4 owner keep R4's procedural shell.
		# Production fallback deliberately draws nothing here so the stage-owned
		# background below remains visible when an approved bitmap is unavailable.
		if not owns_background_contract:
			_draw_node_modal_backdrop(canvas, viewport_rect, node_kind)
	else:
		_draw_noncombat_node_background_model(canvas, background_model)
	model["render_context"] = render_context
	_draw_node_modal(canvas, model)


func draw_retained_noncombat_node_background(
	canvas: CanvasItem,
	flow: Object,
	fallback_rect: Rect2 = Rect2()
) -> void:
	if canvas == null or flow == null:
		return
	# NODE_MODAL owns its opaque screen-space draw later in the frame. This early
	# pass exists for ROUTE_AIM and departure transitions so actors stay above it.
	if flow.has_method("get_phase_name") and str(flow.get_phase_name()) == "NODE_MODAL":
		return
	var viewport_rect := resolve_fullscreen_rect(canvas, fallback_rect)
	var model := build_noncombat_node_background_model(flow, viewport_rect)
	if not model.is_empty():
		_draw_noncombat_node_background_model(canvas, model)


func build_noncombat_node_background_model(
	flow: Object,
	viewport_rect: Rect2
) -> Dictionary:
	if (
		flow == null
		or viewport_rect.size.x <= 0.0
		or viewport_rect.size.y <= 0.0
		or not flow.has_method("get_retained_noncombat_node_background_resolution")
	):
		return {}
	var resolution: Dictionary = flow.get_retained_noncombat_node_background_resolution()
	if resolution.is_empty() or bool(resolution.get("fallback_to_stage_background", false)):
		return {}
	var kind := str(resolution.get("kind", ""))
	var source := str(resolution.get("source", ""))
	if source == "bitmap":
		var texture := resolution.get("texture", null) as Texture2D
		if texture == null:
			return {}
		var source_rect := _texture_cover_source_rect(texture, viewport_rect)
		if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
			return {}
		return {
			"kind": kind,
			"source": source,
			"texture": texture,
			"target_rect": viewport_rect,
			"source_rect": source_rect,
		}
	if source == "procedural":
		return {
			"kind": kind,
			"source": source,
			"target_rect": viewport_rect,
		}
	return {}


func resolve_fullscreen_rect(canvas: CanvasItem, fallback_rect: Rect2) -> Rect2:
	# GRT-044: a fullscreen surface trusts the live viewport first. The tree
	# guard keeps headless/source fixtures from emitting get_viewport_rect errors.
	if canvas != null and canvas.is_inside_tree():
		return canvas.get_viewport_rect()
	return fallback_rect


func _draw_noncombat_node_background_model(
	canvas: CanvasItem,
	model: Dictionary
) -> void:
	var target_rect: Rect2 = model.get("target_rect", Rect2())
	if str(model.get("source", "")) == "bitmap":
		var texture := model.get("texture", null) as Texture2D
		var source_rect: Rect2 = model.get("source_rect", Rect2())
		if texture != null and target_rect.size.x > 0.0 and target_rect.size.y > 0.0:
			canvas.draw_texture_rect_region(
				texture,
				target_rect,
				source_rect,
				Color.WHITE,
				false,
				true
			)
		return
	if str(model.get("source", "")) == "procedural":
		_draw_node_modal_backdrop(
			canvas,
			target_rect,
			str(model.get("kind", "rest"))
		)


func _texture_cover_source_rect(texture: Texture2D, target_rect: Rect2) -> Rect2:
	var texture_size := texture.get_size()
	if (
		texture_size.x <= 0.0
		or texture_size.y <= 0.0
		or target_rect.size.x <= 0.0
		or target_rect.size.y <= 0.0
	):
		return Rect2()
	var scale := maxf(
		target_rect.size.x / texture_size.x,
		target_rect.size.y / texture_size.y
	)
	var source_size := target_rect.size / maxf(0.001, scale)
	return Rect2((texture_size - source_size) * 0.5, source_size)


func build_fullscreen_map_model(flow: Object, viewport_rect: Rect2) -> Dictionary:
	var base := build_render_model(flow)
	if base.is_empty() or viewport_rect.size.x <= 0.0 or viewport_rect.size.y <= 0.0:
		_last_fullscreen_model = {}
		return {}
	var fit_content_width := str(flow.get_phase_name()) != "MAP_TRANSITION"
	var static_base := (
		_build_full_tower_overview_base(flow, base)
		if fit_content_width
		else base
	)
	var fullscreen_key := "%s:%0.3f:%0.3f:%s" % [
		_cached_graph_key,
		viewport_rect.size.x,
		viewport_rect.size.y,
		"overview_fit" if fit_content_width else "walking_source",
	]
	if fullscreen_key != _cached_fullscreen_key:
		_cached_fullscreen_key = fullscreen_key
		_cached_fullscreen_model = _build_static_fullscreen_map_model(
			static_base,
			viewport_rect,
			fit_content_width
		)
		_fullscreen_cache_build_count += 1
	if _cached_fullscreen_model.is_empty():
		return {}
	var model := _cached_fullscreen_model.duplicate(false)
	model["active_candidate_ids"] = base.get("active_candidate_ids", [])
	model["current_node_id"] = str(base.get("current_node_id", ""))
	model["selected_target_id"] = str(base.get("selected_target_id", ""))
	model["pointer_selected_node_id"] = (
		str(flow.get_map_pointer_selected_node_id())
		if flow.has_method("get_map_pointer_selected_node_id")
		else ""
	)
	model["route_history"] = base.get("route_history", [])
	model["floor_reveal_visual"] = (
		flow.get_floor_reveal_visual_model()
		if flow.has_method("get_floor_reveal_visual_model")
		else {"revealed_floor": 0}
	)
	model["transition_marker"] = _build_fullscreen_transition_marker(
		flow,
		base,
		model.get("world_rect", Rect2()),
		model.get("position_by_id", {}),
		model.get("edges", [])
	)
	var transition_marker: Dictionary = model.get("transition_marker", {})
	var focus_world_position: Vector2 = (
		transition_marker.get("world_position", Vector2.ZERO)
		if not transition_marker.is_empty()
		else model.get("position_by_id", {}).get(
			str(base.get("current_node_id", "")),
			(model.get("world_rect", Rect2()) as Rect2).end
		)
	)
	var camera_intro_multiplier := maxf(
		1.0,
		float(transition_marker.get("camera_zoom_multiplier", 1.0))
	)
	var camera_base_multiplier := (
		float(model.get("preferred_camera_zoom", 1.0))
		if not transition_marker.is_empty()
		else float(model.get("minimum_cover_zoom", 1.0))
	)
	var camera_render_multiplier := camera_base_multiplier * camera_intro_multiplier
	var camera_focus_x_blend := clampf(
		inverse_lerp(
			TowerAscentTuning.TEMP_MAP_CAMERA_INTRO_START_MULTIPLIER,
			TowerAscentTuning.TEMP_MAP_CAMERA_INTRO_END_MULTIPLIER,
			camera_intro_multiplier
		),
		0.0,
		1.0
	)
	var has_manual_zoom := (
		flow.has_method("has_map_camera_manual_zoom_override")
		and bool(flow.has_map_camera_manual_zoom_override())
		and flow.has_method("get_map_camera_manual_zoom_multiplier")
	)
	if has_manual_zoom:
		camera_render_multiplier = clampf(
			float(flow.get_map_camera_manual_zoom_multiplier()),
			float(model.get("minimum_fit_all_zoom", 1.0)),
			maxf(
				float(model.get("minimum_cover_zoom", 1.0)),
				TowerAscentTuning.TEMP_MAP_WHEEL_ZOOM_MAX
			)
		)
	var subcover_active := (
		has_manual_zoom
		and camera_render_multiplier + SUBCOVER_ZOOM_EPSILON
			< float(model.get("minimum_cover_zoom", 1.0))
	)
	var camera_world_rect: Rect2 = (
		model.get("fit_all_camera_world_rect", model.get("camera_world_rect", Rect2()))
		if subcover_active
		else model.get("camera_world_rect", Rect2())
	)
	model["camera_world_rect"] = camera_world_rect
	if subcover_active:
		model["nodes"] = model.get("overview_nodes", model.get("nodes", []))
		model["edges"] = model.get("overview_edges", model.get("edges", []))
		model["floor_bands"] = model.get(
			"overview_floor_bands",
			model.get("floor_bands", [])
		)
		model["scroll_background"] = model.get(
			"overview_scroll_background",
			model.get("scroll_background", {})
		)
		model["position_by_id"] = model.get(
			"overview_position_by_id",
			model.get("position_by_id", {})
		)
	var camera_model := TowerAscentMapCameraModel.build(
		model.get("camera_view_rect", Rect2()),
		camera_world_rect,
		focus_world_position,
		0.0,
		TowerAscentTuning.TEMP_MAP_CAMERA_FOCUS_Y_RATIO,
		camera_render_multiplier,
		camera_focus_x_blend
	)
	if (
		flow.has_method("has_map_camera_manual_override")
		and bool(flow.has_map_camera_manual_override())
		and flow.has_method("get_map_camera_manual_offset")
	):
		TowerAscentMapCameraModel.apply_offset_override(
			camera_model,
			flow.get_map_camera_manual_offset()
		)
	camera_model["base_zoom_multiplier"] = camera_base_multiplier
	camera_model["render_zoom_multiplier"] = camera_render_multiplier
	# Keep the established intro-only diagnostic field stable; all drawing and
	# hit testing read render_zoom_multiplier.
	camera_model["zoom_multiplier"] = camera_intro_multiplier
	camera_model["minimum_cover_zoom"] = float(model.get("minimum_cover_zoom", 1.0))
	camera_model["minimum_fit_all_zoom"] = float(model.get("minimum_fit_all_zoom", 1.0))
	camera_model["maximum_zoom"] = maxf(
		float(model.get("minimum_cover_zoom", 1.0)),
		TowerAscentTuning.TEMP_MAP_WHEEL_ZOOM_MAX
	)
	model["subcover_active"] = subcover_active
	model["surround_color"] = surround_color_for_realm(str(model.get(
		"realm_kind",
		"human_realm"
	)))
	model["camera"] = camera_model
	_last_fullscreen_model = model
	return model


func _build_full_tower_overview_base(flow: Object, active_base: Dictionary) -> Dictionary:
	if not flow.has_method("get_graph_phases"):
		return active_base
	var phases: Array = flow.get_graph_phases()
	if phases.size() <= 1:
		return active_base
	var overview := active_base.duplicate(false)
	var floors: Array[Dictionary] = []
	var nodes: Array[Dictionary] = []
	var edges: Array[Dictionary] = []
	var active_phase: Dictionary = active_base.get("phase", {})
	var active_phase_id := str(active_phase.get("id", ""))
	for phase_variant in phases:
		if not (phase_variant is Dictionary):
			continue
		var phase := phase_variant as Dictionary
		var realm_kind := str(phase.get("realm_kind", "human_realm"))
		var phase_is_active := str(phase.get("id", "")) == active_phase_id
		for floor_variant in phase.get("floors", []):
			if not (floor_variant is Dictionary):
				continue
			var floor_data := (floor_variant as Dictionary).duplicate(true)
			floor_data["realm_kind"] = realm_kind
			floor_data["overview_active_phase"] = phase_is_active
			floors.append(floor_data)
		for node_variant in phase.get("nodes", []):
			if not (node_variant is Dictionary):
				continue
			var node := (node_variant as Dictionary).duplicate(true)
			node["realm_kind"] = realm_kind
			node["overview_active_phase"] = phase_is_active
			# Locked registry-only data contributes layout and cloud bounds, but it
			# is neither rendered nor hittable until the gameplay content unlocks.
			node["overview_hidden"] = str(node.get(
				"content_state",
				"generated"
			)) != "generated"
			nodes.append(node)
		for edge_variant in phase.get("edges", []):
			if edge_variant is Dictionary:
				edges.append((edge_variant as Dictionary).duplicate(true))
	if floors.is_empty() or nodes.is_empty():
		return active_base
	overview["floors"] = floors
	overview["nodes"] = nodes
	overview["edges"] = edges
	overview["full_tower_overview"] = true
	return overview


func _build_static_fullscreen_map_model(
	base: Dictionary,
	viewport_rect: Rect2,
	fit_content_width: bool = true
) -> Dictionary:
	var outer_margin := minf(viewport_rect.size.x, viewport_rect.size.y) * TowerAscentTuning.TEMP_MAP_OUTER_MARGIN_RATIO
	var safe_content_bounds := viewport_rect.grow(-outer_margin)
	var panel_rect := viewport_rect
	var side_gutter := safe_content_bounds.size.x * TowerAscentTuning.TEMP_MAP_SIDE_GUTTER_RATIO
	var top_inset := viewport_rect.size.y * TowerAscentTuning.TEMP_MAP_CONTENT_TOP_RATIO
	var bottom_inset := viewport_rect.size.y * TowerAscentTuning.TEMP_MAP_CONTENT_BOTTOM_RATIO
	var content_rect := Rect2(
		safe_content_bounds.position + Vector2(side_gutter, top_inset),
		Vector2(
			maxf(1.0, safe_content_bounds.size.x - side_gutter * 2.0),
			maxf(1.0, safe_content_bounds.size.y - top_inset - bottom_inset)
		)
	)
	var map_scale := (
		maxf(0.001, content_rect.size.x / MAP_SCROLL_TILE_SIZE.x)
		if fit_content_width
		else 1.0
	)
	var scaled_tile_size := MAP_SCROLL_TILE_SIZE * map_scale
	var scaled_row_pitch := MAP_SCROLL_ROW_PITCH * map_scale
	var nodes: Array = base.get("nodes", [])
	var source_min_x := INF
	var source_max_x := -INF
	var source_min_y := INF
	var source_max_y := -INF
	var unique_rows: Dictionary = {}
	for node_variant in nodes:
		if not (node_variant is Dictionary):
			continue
		var source_position := _vector2((node_variant as Dictionary).get("position", Vector2.ZERO))
		source_min_x = minf(source_min_x, source_position.x)
		source_max_x = maxf(source_max_x, source_position.x)
		source_min_y = minf(source_min_y, source_position.y)
		source_max_y = maxf(source_max_y, source_position.y)
		unique_rows[int(round(source_position.y))] = true
	if not is_finite(source_min_y) or not is_finite(source_max_y):
		return {}
	var sorted_source_rows: Array = unique_rows.keys()
	sorted_source_rows.sort()
	var row_index_by_source_y: Dictionary = {}
	for row_index in range(sorted_source_rows.size()):
		row_index_by_source_y[int(sorted_source_rows[row_index])] = row_index
	var active_first_row_index := 0
	var found_active_row := false
	for node_variant in nodes:
		if not (node_variant is Dictionary):
			continue
		var node := node_variant as Dictionary
		if not bool(node.get("overview_active_phase", true)):
			continue
		var source_position := _vector2(node.get("position", Vector2.ZERO))
		var source_row_index := int(row_index_by_source_y.get(
			int(round(source_position.y)),
			0
		))
		active_first_row_index = (
			mini(active_first_row_index, source_row_index)
			if found_active_row
			else source_row_index
		)
		found_active_row = true
	var world_rect := Rect2(
		Vector2(
			content_rect.get_center().x - scaled_tile_size.x * 0.5,
			content_rect.position.y - float(active_first_row_index) * scaled_row_pitch
		),
		Vector2(
			scaled_tile_size.x,
			maxf(
				scaled_row_pitch,
				float(maxi(0, sorted_source_rows.size() - 1)) * scaled_row_pitch
			)
		)
	)
	var art_size := MAP_SCROLL_NODE_ART_SIZE * map_scale
	var lane_span := world_rect.size.x * TowerAscentTuning.TEMP_MAP_LANE_SPAN_RATIO
	var center_x := world_rect.get_center().x
	var position_by_id: Dictionary = {}
	var projected_node_by_id: Dictionary = {}
	var projected_nodes: Array[Dictionary] = []
	for node_variant in nodes:
		if not (node_variant is Dictionary):
			continue
		var node := (node_variant as Dictionary).duplicate(true)
		var source_position := _vector2(node.get("position", Vector2.ZERO))
		var source_x_ratio := (
			lerpf(-1.0, 1.0, inverse_lerp(source_min_x, source_max_x, source_position.x))
			if not is_equal_approx(source_min_x, source_max_x)
			else 0.0
		)
		var source_row_index := int(row_index_by_source_y.get(int(round(source_position.y)), 0))
		var screen_position := Vector2(
			center_x + source_x_ratio * lane_span,
			world_rect.position.y
				+ float(source_row_index) * scaled_row_pitch
		)
		var node_kind := str(node.get("kind", ""))
		node["world_position"] = screen_position
		node["world_art_rect"] = Rect2(
			screen_position - Vector2.ONE * art_size * 0.5,
			Vector2.ONE * art_size
		)
		node["art_path"] = str(NODE_ART_PATHS.get(node_kind, NODE_ART_PATHS["combat"]))
		var node_id := str(node.get("id", ""))
		position_by_id[node_id] = screen_position
		projected_node_by_id[node_id] = node
		projected_nodes.append(node)
	var node_hit_cell_size := maxf(1.0, art_size)
	var node_hit_ids_by_cell: Dictionary = {}
	for node in projected_nodes:
		if bool(node.get("overview_hidden", false)):
			continue
		var hit_node_id := str(node.get("id", ""))
		var hit_rect: Rect2 = node.get("world_art_rect", Rect2())
		var minimum_cell := Vector2i(
			floori(hit_rect.position.x / node_hit_cell_size),
			floori(hit_rect.position.y / node_hit_cell_size)
		)
		var maximum_cell := Vector2i(
			floori((hit_rect.end.x - 0.001) / node_hit_cell_size),
			floori((hit_rect.end.y - 0.001) / node_hit_cell_size)
		)
		for cell_y in range(minimum_cell.y, maximum_cell.y + 1):
			for cell_x in range(minimum_cell.x, maximum_cell.x + 1):
				var cell := Vector2i(cell_x, cell_y)
				if not node_hit_ids_by_cell.has(cell):
					node_hit_ids_by_cell[cell] = []
				(node_hit_ids_by_cell[cell] as Array).append(hit_node_id)
	var straight_edges: Array[Dictionary] = []
	for edge_variant in base.get("edges", []):
		if not (edge_variant is Dictionary):
			continue
		var edge := edge_variant as Dictionary
		var from_id := str(edge.get("from", ""))
		var to_id := str(edge.get("to", ""))
		if not position_by_id.has(from_id) or not position_by_id.has(to_id):
			continue
		if (
			bool((projected_node_by_id.get(from_id, {}) as Dictionary).get(
				"overview_hidden",
				false
			))
			or bool((projected_node_by_id.get(to_id, {}) as Dictionary).get(
				"overview_hidden",
				false
			))
		):
			continue
		straight_edges.append({
			"from": from_id,
			"to": to_id,
			"from_position": position_by_id[from_id],
			"to_position": position_by_id[to_id],
		})
	var curved_edges := TowerAscentMapPathGeometry.build(
		straight_edges,
		int(base.get("map_seed", 0)),
		art_size,
		TowerAscentTuning.TEMP_MAP_PATH_CURVE_MIN_RATIO,
		TowerAscentTuning.TEMP_MAP_PATH_CURVE_MAX_RATIO,
		TowerAscentTuning.TEMP_MAP_PATH_CURVE_SKEW_RATIO,
		MAP_SCROLL_ROUTE_ENDPOINT_CLEARANCE_RATIO,
		TowerAscentTuning.TEMP_MAP_PATH_SAMPLE_MIN,
		TowerAscentTuning.TEMP_MAP_PATH_SAMPLE_MAX
	)
	var dot_gap := art_size * TowerAscentTuning.TEMP_MAP_PATH_DOT_GAP_ART_RATIO
	var dotted_edges: Array[Dictionary] = []
	var cloud_draw_call_reserve := TowerAscentMapCloudLayer.estimate_draw_calls(
		projected_nodes
	)
	var route_draw_call_budget := maxi(
		2,
		TowerAscentTuning.TEMP_MAP_PATH_DRAW_CALL_BUDGET - cloud_draw_call_reserve
	)
	# This loop runs only while rebuilding the cached graph projection. If a
	# wider v7 graph exceeds the draw budget, it keeps every route and expresses
	# the same paths with wider dot spacing instead of clipping connections.
	for _budget_attempt in range(4):
		dotted_edges = TowerAscentMapPathGeometry.attach_dots(
			curved_edges,
			dot_gap,
			art_size * TowerAscentTuning.TEMP_MAP_PATH_DOT_OUTER_RADIUS_ART_RATIO,
			art_size * TowerAscentTuning.TEMP_MAP_PATH_DOT_INNER_RADIUS_ART_RATIO,
			TowerAscentTuning.TEMP_MAP_PATH_DOT_CIRCLE_SEGMENTS
		)
		var draw_call_count := TowerAscentMapPathGeometry.dot_count(dotted_edges) * 2
		if draw_call_count <= route_draw_call_budget:
			break
		dot_gap *= maxf(
			1.05,
			float(draw_call_count) / float(route_draw_call_budget)
		)
	var projected_edges := _attach_route_brush_strips(dotted_edges, map_scale)
	var active_projected_nodes: Array[Dictionary] = []
	var active_position_by_id: Dictionary = {}
	for node in projected_nodes:
		if not bool(node.get("overview_active_phase", true)):
			continue
		active_projected_nodes.append(node)
		var active_node_id := str(node.get("id", ""))
		active_position_by_id[active_node_id] = node.get("world_position", Vector2.ZERO)
	var active_projected_edges: Array[Dictionary] = []
	for edge in projected_edges:
		if (
			active_position_by_id.has(str(edge.get("from", "")))
			and active_position_by_id.has(str(edge.get("to", "")))
		):
			active_projected_edges.append(edge)
	_path_cache_build_count += 1
	_path_cached_dot_count = TowerAscentMapPathGeometry.dot_count(projected_edges)
	_path_cached_dot_gap = dot_gap
	_path_cached_brush_segment_count = _route_brush_segment_count(projected_edges)
	var segment_y_bounds: Dictionary = {}
	for node in projected_nodes:
		var segment_floor := int(node.get("segment_floor", node.get("floor", 0)))
		if segment_floor <= 0:
			continue
		var node_y := float((node.get("world_position", Vector2.ZERO) as Vector2).y)
		var y_bounds: Vector2 = segment_y_bounds.get(
			segment_floor,
			Vector2(node_y, node_y)
		)
		y_bounds.x = minf(y_bounds.x, node_y)
		y_bounds.y = maxf(y_bounds.y, node_y)
		segment_y_bounds[segment_floor] = y_bounds
	var floor_bands: Array[Dictionary] = []
	for floor_variant in base.get("floors", []):
		if not (floor_variant is Dictionary):
			continue
		var floor_data := floor_variant as Dictionary
		var rows: Array = floor_data.get("rows", [])
		if rows.is_empty() or not (rows[rows.size() - 1] is Dictionary):
			continue
		var gate_ids: Array = (rows[rows.size() - 1] as Dictionary).get("node_ids", [])
		if gate_ids.is_empty() or not position_by_id.has(str(gate_ids[0])):
			continue
		var floor_number := int(floor_data.get("floor", 0))
		var band_y := float((position_by_id[str(gate_ids[0])] as Vector2).y)
		var segment_bounds: Vector2 = segment_y_bounds.get(
			floor_number,
			Vector2(band_y, band_y)
		)
		# Segment ownership is half-open at the midpoint between adjacent
		# rows. A normal two-row floor remains one native 320px band, while
		# the expanded first-floor segment grows from its actual row extent.
		var band_rect := Rect2(
			world_rect.position.x,
			segment_bounds.x - scaled_row_pitch * 0.5,
			scaled_tile_size.x,
			segment_bounds.y - segment_bounds.x + scaled_row_pitch
		)
		floor_bands.append({
			"floor": floor_number,
			"segment_floor": floor_number,
			"realm_kind": str(floor_data.get(
				"realm_kind",
				base.get("realm_kind", "human_realm")
			)),
			"overview_active_phase": bool(floor_data.get(
				"overview_active_phase",
				true
			)),
			"y": band_y,
			# `rect` remains the approved 692:320 art tile contract.
			# `segment_rect` is the authoritative half-open ownership band and
			# may span multiple native tiles when a floor gains more rows.
			"rect": Rect2(
				world_rect.position.x,
				band_y - scaled_tile_size.y * 0.5,
				scaled_tile_size.x,
				scaled_tile_size.y
			),
			"segment_rect": band_rect,
		})
	var active_floor_bands: Array[Dictionary] = []
	var active_camera_world_rect := Rect2()
	var has_active_camera_world_rect := false
	for band_variant in floor_bands:
		if not (band_variant is Dictionary):
			continue
		var band := band_variant as Dictionary
		if not bool(band.get("overview_active_phase", true)):
			continue
		active_floor_bands.append(band)
		var band_rect: Rect2 = band.get("segment_rect", band.get("rect", Rect2()))
		active_camera_world_rect = (
			active_camera_world_rect.merge(band_rect)
			if has_active_camera_world_rect
			else band_rect
		)
		has_active_camera_world_rect = true
	var scroll_background := build_scroll_background_model(
		active_floor_bands,
		world_rect,
		str(base.get("realm_kind", "human_realm")),
		base.get("map_scroll_assets", {}),
		scaled_tile_size
	)
	var overview_scroll_background := build_scroll_background_model(
		floor_bands,
		world_rect,
		str(base.get("realm_kind", "human_realm")),
		base.get("map_scroll_assets", {}),
		scaled_tile_size
	)
	# The node layout keeps the established safe gutters, while the camera and
	# scroll artwork own the whole screen. `world_rect` is the exact opaque
	# map-art extent, so clamping against it cannot reveal the paper panel when a
	# cover crop tracks near an edge.
	var camera_view_rect := viewport_rect
	var fit_all_camera_world_rect: Rect2 = overview_scroll_background.get(
		"world_rect",
		Rect2(
			Vector2(world_rect.position.x, world_rect.position.y - scaled_tile_size.y * 0.5),
			Vector2(world_rect.size.x, world_rect.size.y + scaled_tile_size.y)
		)
	)
	var camera_world_rect: Rect2 = scroll_background.get(
		"world_rect",
		active_camera_world_rect
		if has_active_camera_world_rect
		else fit_all_camera_world_rect
	)
	var minimum_cover_zoom := TowerAscentMapCameraModel.minimum_cover_zoom(
		camera_view_rect,
		camera_world_rect
	)
	var minimum_fit_all_zoom := TowerAscentMapCameraModel.minimum_fit_all_zoom(
		camera_view_rect,
		fit_all_camera_world_rect
	)
	var preferred_camera_zoom := maxf(
		minimum_cover_zoom,
		TowerAscentTuning.TEMP_MAP_CAMERA_ZOOM if not fit_content_width else 1.0
	)
	var cloud_layer_model := _map_cloud_layer.build(
		projected_nodes,
		fit_all_camera_world_rect,
		int(base.get("map_seed", 0)),
		art_size,
		base.get("map_scroll_assets", {}),
		map_scale
	)
	return {
		"viewport_rect": viewport_rect,
		"panel_rect": panel_rect,
		"safe_content_bounds": safe_content_bounds,
		"content_rect": content_rect,
		"world_rect": world_rect,
		"camera_view_rect": camera_view_rect,
		"camera_world_rect": camera_world_rect,
		"fit_all_camera_world_rect": fit_all_camera_world_rect,
		"minimum_cover_zoom": minimum_cover_zoom,
		"minimum_fit_all_zoom": minimum_fit_all_zoom,
		"preferred_camera_zoom": preferred_camera_zoom,
		"cloud_layer": cloud_layer_model,
		"map_scale": map_scale,
		"plaque_size": MAP_SCROLL_PLAQUE_SIZE * map_scale,
		"nodes": active_projected_nodes,
		"edges": active_projected_edges,
		"floor_bands": active_floor_bands,
		"overview_nodes": projected_nodes,
		"overview_edges": projected_edges,
		"overview_floor_bands": floor_bands,
		"scroll_background": scroll_background,
		"overview_scroll_background": overview_scroll_background,
		"map_scroll_assets": base.get("map_scroll_assets", {}),
		"position_by_id": active_position_by_id,
		"overview_position_by_id": position_by_id,
		"node_by_id": projected_node_by_id,
		"node_hit_cell_size": node_hit_cell_size,
		"node_hit_ids_by_cell": node_hit_ids_by_cell,
		"art_size": art_size,
		"map_seed": int(base.get("map_seed", 0)),
		"phase": base.get("phase", {}),
		"realm_kind": str(base.get("realm_kind", "human_realm")),
		"locked_phase_hints": base.get("locked_phase_hints", []),
		"full_tower_overview": bool(base.get("full_tower_overview", false)),
	}


func _build_fullscreen_transition_marker(
	flow: Object,
	base: Dictionary,
	world_rect: Rect2,
	position_by_id: Dictionary,
	edges_value: Variant
) -> Dictionary:
	if str(flow.get_phase_name()) != "MAP_TRANSITION":
		return {}
	var source_id := str(flow.get_route_source_node_id())
	var target_id := str(base.get("selected_target_id", ""))
	var target_position: Vector2 = position_by_id.get(
		target_id,
		world_rect.position + Vector2(world_rect.size.x * 0.5, world_rect.size.y * 0.12)
	)
	var visual_model: Dictionary = (
		flow.get_map_transition_visual_model()
		if flow.has_method("get_map_transition_visual_model")
		else {"travel_progress": flow.get_map_transition_progress(), "marker_scale": 1.0, "marker_alpha": 1.0}
	)
	var route_edge: Dictionary = {}
	var edges: Array = edges_value if edges_value is Array else []
	for edge_variant in edges:
		if not (edge_variant is Dictionary):
			continue
		var edge := edge_variant as Dictionary
		if str(edge.get("from", "")) == source_id and str(edge.get("to", "")) == target_id:
			route_edge = edge
			break
	var travel_progress := float(visual_model.get("travel_progress", 0.0))
	var from_position: Vector2 = position_by_id.get(
		source_id,
		Vector2(world_rect.get_center().x, world_rect.end.y)
	)
	var world_position := (
		TowerAscentMapPathGeometry.sample_travel_position(route_edge, travel_progress)
		if not route_edge.is_empty()
		else from_position.lerp(target_position, travel_progress)
	)
	var facing_probe := (
		TowerAscentMapPathGeometry.sample_travel_position(
			route_edge,
			minf(1.0, travel_progress + 0.015)
		)
		if not route_edge.is_empty()
		else target_position
	)
	return {
		"from_position": from_position,
		"to_position": target_position,
		"world_position": world_position,
		"facing_right": facing_probe.x >= world_position.x,
		"progress": travel_progress,
		"scale": float(visual_model.get("marker_scale", 1.0)),
		"alpha": float(visual_model.get("marker_alpha", 1.0)),
		"camera_zoom_multiplier": float(
			visual_model.get("camera_zoom_multiplier", 1.0)
		),
		"segment": str(visual_model.get("segment", "")),
		"phase_entry": bool(flow.is_phase_entry_transition()),
	}


func get_node_art_asset_paths() -> Array[String]:
	var result: Array[String] = []
	for path_value in NODE_ART_PATHS.values():
		var path := str(path_value)
		if not result.has(path):
			result.append(path)
	return result


func build_map_icon_presentation(node: Dictionary) -> Dictionary:
	var node_kind := str(node.get("kind", ""))
	var fallback_label := str(node.get("label", ""))
	if not (node_kind in TowerAscentMapIconography.COMBAT_NODE_KINDS):
		fallback_label = TowerAscentMapOverlayLocalization.node_kind_label(
			node_kind,
			bool(node.get("enraged", false))
		)
	return _map_iconography.resolve_presentation(
		node_kind,
		_map_iconography.resolve_boss_id_for_node(node),
		fallback_label
	)


func get_map_icon_cache_debug_state() -> Dictionary:
	return _map_iconography.get_debug_state()


func get_last_fullscreen_camera_offset() -> Vector2:
	if _last_fullscreen_model.is_empty():
		return Vector2.ZERO
	var camera: Dictionary = _last_fullscreen_model.get("camera", {})
	return camera.get("offset", Vector2.ZERO)


func get_last_fullscreen_camera_model() -> Dictionary:
	if _last_fullscreen_model.is_empty():
		return {}
	var camera_value: Variant = _last_fullscreen_model.get("camera", {})
	return (camera_value as Dictionary).duplicate(true) if camera_value is Dictionary else {}


func resolve_fullscreen_node_id_at_screen_position(
	screen_position: Vector2
) -> String:
	if _last_fullscreen_model.is_empty():
		return ""
	var view_rect: Rect2 = _last_fullscreen_model.get("camera_view_rect", Rect2())
	if not view_rect.has_point(screen_position):
		return ""
	var camera: Dictionary = _last_fullscreen_model.get("camera", {})
	var zoom := _camera_render_zoom(camera)
	var offset: Vector2 = camera.get("offset", Vector2.ZERO)
	var world_position := (screen_position - offset) / zoom
	var cell_size := float(_last_fullscreen_model.get("node_hit_cell_size", 0.0))
	if cell_size <= 0.0:
		return ""
	var cell := Vector2i(
		floori(world_position.x / cell_size),
		floori(world_position.y / cell_size)
	)
	var hit_index: Dictionary = _last_fullscreen_model.get(
		"node_hit_ids_by_cell",
		{}
	)
	if not hit_index.has(cell):
		return ""
	var node_by_id: Dictionary = _last_fullscreen_model.get("node_by_id", {})
	var nearest_node_id := ""
	var nearest_distance_squared := INF
	for node_id_value in hit_index[cell] as Array:
		var node_id := str(node_id_value)
		var node_value: Variant = node_by_id.get(node_id, null)
		if not (node_value is Dictionary):
			continue
		var world_art_rect: Rect2 = (node_value as Dictionary).get(
			"world_art_rect",
			Rect2()
		)
		if not world_art_rect.has_point(world_position):
			continue
		var distance_squared := world_art_rect.get_center().distance_squared_to(
			world_position
		)
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_node_id = node_id
	return nearest_node_id


func _draw_fullscreen_map_model(
	canvas: CanvasItem,
	flow: Object,
	model: Dictionary,
	walker_model: Dictionary = {}
) -> void:
	var viewport_rect: Rect2 = model.get("viewport_rect", Rect2())
	var panel_rect: Rect2 = model.get("panel_rect", Rect2())
	var content_rect: Rect2 = model.get("content_rect", Rect2())
	var camera_view_rect: Rect2 = model.get("camera_view_rect", viewport_rect)
	var world_rect: Rect2 = model.get("world_rect", content_rect)
	var camera_model: Dictionary = model.get("camera", {})
	var realm_kind := str(model.get("realm_kind", "human_realm"))
	var immortal_realm := realm_kind == "immortal_realm"
	var subcover_active := bool(model.get("subcover_active", false))
	var surround_color: Color = model.get(
		"surround_color",
		surround_color_for_realm(realm_kind)
	)
	canvas.draw_rect(viewport_rect, surround_color, true)
	if not subcover_active:
		canvas.draw_rect(panel_rect, Color("dce3da") if immortal_realm else PAPER, true)
		canvas.draw_rect(panel_rect, CINNABAR_DARK, false, 5.0)
		canvas.draw_rect(panel_rect.grow(-10.0), GOLD, false, 1.5)
	var scroll_background_value: Variant = model.get("scroll_background", {})
	var scroll_background: Dictionary = (
		scroll_background_value as Dictionary
		if scroll_background_value is Dictionary
		else {}
	)
	var scroll_background_ready := bool(scroll_background.get("ready", false))
	if scroll_background_ready:
		_draw_scroll_background_model(canvas, scroll_background, camera_view_rect, camera_model)
		if subcover_active:
			_draw_subcover_scroll_edge_treatment(
				canvas,
				camera_view_rect,
				model.get("camera_world_rect", Rect2()),
				camera_model
			)
	else:
		if immortal_realm:
			_draw_immortal_realm_backdrop(canvas, camera_view_rect)
		_draw_fullscreen_castle(
			canvas,
			camera_view_rect,
			world_rect,
			model.get("floor_bands", []),
			realm_kind,
			camera_model
		)
	for edge_variant in model.get("edges", []):
		if not (edge_variant is Dictionary):
			continue
		var edge := edge_variant as Dictionary
		var brush_asset_key := resolve_route_brush_asset_key(
			edge,
			model.get("route_history", []),
			model.get("active_candidate_ids", []),
			str(model.get("current_node_id", ""))
		)
		if not should_draw_route_edge_in_view(
			edge,
			brush_asset_key,
			camera_view_rect,
			camera_model
		):
			continue
		var brush_texture := _cached_map_scroll_texture(
			model.get("map_scroll_assets", {}),
			brush_asset_key
		)
		if brush_texture != null:
			_draw_route_brush_strip(
				canvas,
				_route_brush_quads_for_asset(edge, brush_asset_key),
				brush_texture,
				camera_view_rect,
				camera_model
			)
		else:
			_draw_fullscreen_procedural_dotted_edge(
				canvas,
				edge,
				camera_view_rect,
				camera_model,
				float(model.get("art_size", 0.0))
			)
	if scroll_background_ready:
		_draw_fullscreen_floor_guides(
			canvas,
			camera_view_rect,
			model.get("floor_bands", []),
			camera_model,
			model.get("map_scroll_assets", {}),
			float(model.get("map_scale", 1.0))
		)
	var active_candidate_ids: Array = model.get("active_candidate_ids", [])
	var current_node_id := str(model.get("current_node_id", ""))
	var selected_target_id := str(model.get("selected_target_id", ""))
	var pointer_selected_node_id := str(model.get("pointer_selected_node_id", ""))
	for node_variant in model.get("nodes", []):
		if (
			node_variant is Dictionary
			and not bool((node_variant as Dictionary).get("overview_hidden", false))
		):
			_draw_fullscreen_map_node(
				canvas,
				node_variant as Dictionary,
				active_candidate_ids,
				current_node_id,
				selected_target_id,
				pointer_selected_node_id,
				camera_view_rect,
				camera_model
			)
	_draw_fullscreen_transition_marker(
		canvas,
		model.get("transition_marker", {}),
		walker_model,
		float(model.get("art_size", 24.0)),
		camera_model
	)
	# Clouds own spatial disclosure inside the camera. The locked-phase hint is a
	# single status badge in fixed screen chrome and is drawn later, so the two
	# roles never stack text or outlines over an obscured floor.
	_map_cloud_layer.draw(
		canvas,
		model.get("cloud_layer", {}),
		camera_model,
		model.get("floor_reveal_visual", {})
	)
	_draw_floor_reveal_title(
		canvas,
		camera_view_rect,
		model.get("floor_reveal_visual", {})
	)
	var font := ThemeDB.fallback_font
	var chrome_ink := PAPER if subcover_active else INK
	var chrome_ink_soft := PAPER_DEEP if subcover_active else INK_SOFT
	canvas.draw_string(
		font,
		panel_rect.position + Vector2(34.0, 48.0),
		"%s · %s" % [
			TowerAscentMapOverlayLocalization.text(TowerAscentMapOverlayLocalization.KEY_TITLE),
			TowerAscentMapOverlayLocalization.realm_label(realm_kind),
		],
		HORIZONTAL_ALIGNMENT_LEFT,
		panel_rect.size.x * 0.48,
		30,
		chrome_ink
	)
	canvas.draw_string(
		font,
		panel_rect.position + Vector2(34.0, 72.0),
		flow.get_header_subtitle(),
		HORIZONTAL_ALIGNMENT_LEFT,
		panel_rect.size.x * 0.58,
		14,
		chrome_ink_soft
	)
	_draw_locked_phase_hints(canvas, panel_rect, model.get("locked_phase_hints", []))
	var transition_marker_value: Variant = model.get("transition_marker", {})
	if (
		transition_marker_value is Dictionary
		and bool((transition_marker_value as Dictionary).get("phase_entry", false))
	):
		var banner_rect := Rect2(
			panel_rect.get_center() - Vector2(150.0, 27.0),
			Vector2(300.0, 54.0)
		)
		canvas.draw_rect(banner_rect, Color(0.08, 0.12, 0.14, 0.92), true)
		canvas.draw_rect(banner_rect, GOLD, false, 2.0)
		canvas.draw_string(
			font,
			banner_rect.position + Vector2(0.0, 35.0),
			TowerAscentMapOverlayLocalization.text(
				TowerAscentMapOverlayLocalization.KEY_ENTER_IMMORTAL
			),
			HORIZONTAL_ALIGNMENT_CENTER,
			banner_rect.size.x,
			22,
			PAPER
		)
	canvas.draw_string(
		font,
		Vector2(panel_rect.end.x - 230.0, panel_rect.position.y + 48.0),
		TowerAscentMapOverlayLocalization.text(TowerAscentMapOverlayLocalization.KEY_CLOSE_HINT),
		HORIZONTAL_ALIGNMENT_RIGHT,
		196.0,
		14,
		chrome_ink_soft
	)
	var legend_rect := Rect2(
		panel_rect.position.x + 34.0,
		panel_rect.end.y - 56.0,
		panel_rect.size.x - 68.0,
		38.0
	)
	canvas.draw_rect(legend_rect, Color(PAPER_DEEP, 0.7), true)
	canvas.draw_rect(legend_rect, GOLD, false, 1.0)
	canvas.draw_string(
		font,
		legend_rect.position + Vector2(10.0, 24.0),
		TowerAscentMapOverlayLocalization.text(TowerAscentMapOverlayLocalization.KEY_LEGEND_TYPES),
		HORIZONTAL_ALIGNMENT_CENTER,
		legend_rect.size.x - 20.0,
		11,
		INK
	)


func _draw_subcover_scroll_edge_treatment(
	canvas: CanvasItem,
	view_rect: Rect2,
	map_world_rect: Rect2,
	camera_model: Dictionary
) -> void:
	var projected_rect := _camera_world_rect_to_screen(camera_model, map_world_rect)
	if projected_rect.size.x <= 0.0 or projected_rect.size.y <= 0.0:
		return
	var visible_rect := projected_rect.intersection(view_rect)
	if visible_rect.size.x <= 0.0 or visible_rect.size.y <= 0.0:
		return
	var edge_ink := Color(INK, 0.68)
	var horizontal_gap := projected_rect.size.x * MAP_SCROLL_EDGE_GAP_RATIO
	var vertical_gap := projected_rect.size.y * MAP_SCROLL_EDGE_GAP_RATIO
	var horizontal_length := maxf(
		0.0,
		projected_rect.size.x - horizontal_gap * 2.0
	)
	var vertical_length := maxf(
		0.0,
		projected_rect.size.y - vertical_gap * 2.0
	)
	# Four disconnected filled washes darken the scroll's own edge without
	# introducing the repository-forbidden closed or dotted perimeter silhouette.
	canvas.draw_rect(Rect2(
		Vector2(projected_rect.position.x + horizontal_gap, projected_rect.position.y),
		Vector2(horizontal_length, MAP_SCROLL_EDGE_INK_SCREEN_PX)
	).intersection(view_rect), edge_ink, true)
	canvas.draw_rect(Rect2(
		Vector2(
			projected_rect.position.x + horizontal_gap,
			projected_rect.end.y - MAP_SCROLL_EDGE_INK_SCREEN_PX
		),
		Vector2(horizontal_length, MAP_SCROLL_EDGE_INK_SCREEN_PX)
	).intersection(view_rect), edge_ink, true)
	canvas.draw_rect(Rect2(
		Vector2(projected_rect.position.x, projected_rect.position.y + vertical_gap),
		Vector2(MAP_SCROLL_EDGE_INK_SCREEN_PX, vertical_length)
	).intersection(view_rect), edge_ink, true)
	canvas.draw_rect(Rect2(
		Vector2(
			projected_rect.end.x - MAP_SCROLL_EDGE_INK_SCREEN_PX,
			projected_rect.position.y + vertical_gap
		),
		Vector2(MAP_SCROLL_EDGE_INK_SCREEN_PX, vertical_length)
	).intersection(view_rect), edge_ink, true)


func _draw_fullscreen_castle(
	canvas: CanvasItem,
	content_rect: Rect2,
	world_rect: Rect2,
	floor_bands_value: Variant,
	realm_kind: String = "human_realm",
	camera_model: Dictionary = {}
) -> void:
	var tower_rect := Rect2(
		content_rect.get_center().x - content_rect.size.x * 0.27,
		content_rect.position.y - 6.0,
		content_rect.size.x * 0.54,
		content_rect.size.y + 12.0
	)
	var immortal_realm := realm_kind == "immortal_realm"
	canvas.draw_rect(
		tower_rect,
		Color(0.45, 0.5, 0.48, 0.28) if immortal_realm else Color(PAPER_DEEP, 0.28),
		true
	)
	canvas.draw_rect(tower_rect, Color(GOLD, 0.5), false, 2.0)
	var roof_y := _camera_world_to_screen(
		camera_model,
		Vector2(world_rect.get_center().x, world_rect.position.y - 9.0)
	).y
	if roof_y >= content_rect.position.y - 38.0 and roof_y <= content_rect.end.y + 12.0:
		canvas.draw_colored_polygon(
			PackedVector2Array([
				Vector2(tower_rect.position.x - 24.0, roof_y),
				Vector2(tower_rect.get_center().x, roof_y - 30.0),
				Vector2(tower_rect.end.x + 24.0, roof_y),
				Vector2(tower_rect.end.x, roof_y + 10.0),
				Vector2(tower_rect.position.x, roof_y + 10.0),
			]),
			CINNABAR_DARK
		)
	var floor_bands: Array = floor_bands_value if floor_bands_value is Array else []
	for band_variant in floor_bands:
		if not (band_variant is Dictionary):
			continue
		var band := band_variant as Dictionary
		var band_rect: Rect2 = band.get("rect", Rect2())
		var projected_y := _camera_world_to_screen(
			camera_model,
			Vector2(band_rect.get_center().x, float(band.get("y", band_rect.get_center().y)))
		).y
		var projected_rect := _camera_world_rect_to_screen(
			camera_model,
			band_rect
		).intersection(content_rect)
		if projected_rect.size.x <= 0.0 or projected_rect.size.y <= 0.0:
			continue
		canvas.draw_rect(projected_rect, Color(PAPER_DEEP, 0.31), true)
		canvas.draw_line(
			Vector2(projected_rect.position.x, projected_y),
			Vector2(projected_rect.end.x, projected_y),
			Color(GOLD, 0.5),
			1.0
		)
		canvas.draw_string(
			ThemeDB.fallback_font,
			Vector2(content_rect.position.x - 58.0, projected_y + 4.0),
			"%dF" % int(band.get("floor", 0)),
			HORIZONTAL_ALIGNMENT_RIGHT,
			44.0,
			11,
			INK_SOFT
		)


func _draw_fullscreen_floor_guides(
	canvas: CanvasItem,
	content_rect: Rect2,
	floor_bands_value: Variant,
	camera_model: Dictionary,
	resolution_by_key_value: Variant,
	map_scale: float = 1.0
) -> void:
	var floor_bands: Array = floor_bands_value if floor_bands_value is Array else []
	var plaque_texture := _cached_map_scroll_texture(
		resolution_by_key_value,
		TowerMapScrollAssetCatalog.FLOOR_GATE_PLAQUE
	)
	for band_variant in floor_bands:
		if not (band_variant is Dictionary):
			continue
		var band := band_variant as Dictionary
		var band_rect: Rect2 = band.get("rect", Rect2())
		var projected_y := _camera_world_to_screen(
			camera_model,
			Vector2(band_rect.get_center().x, float(band.get("y", band_rect.get_center().y)))
		).y
		if projected_y < content_rect.position.y or projected_y > content_rect.end.y:
			continue
		if plaque_texture != null:
			var plaque_world_rect := build_floor_plaque_target_rect(
				Vector2(
					band_rect.get_center().x,
					float(band.get("y", band_rect.get_center().y))
				),
				map_scale
			)
			var plaque_rect := _camera_world_rect_to_screen(camera_model, plaque_world_rect)
			_draw_floor_plaque(
				canvas,
				plaque_texture,
				plaque_rect,
				content_rect,
				int(band.get("floor", 0))
			)
		else:
			canvas.draw_line(
				Vector2(content_rect.position.x, projected_y),
				Vector2(content_rect.end.x, projected_y),
				Color(GOLD, 0.28),
				1.0
			)
			canvas.draw_string(
				ThemeDB.fallback_font,
				Vector2(content_rect.position.x + 8.0, projected_y + 4.0),
				"%dF" % int(band.get("floor", 0)),
				HORIZONTAL_ALIGNMENT_LEFT,
				44.0,
				11,
				INK_SOFT
			)


func _draw_immortal_realm_backdrop(canvas: CanvasItem, content_rect: Rect2) -> void:
	var cloud_color := Color(0.86, 0.9, 0.87, 0.78)
	for cloud_spec in [
		[0.12, 0.2, 0.13],
		[0.82, 0.34, 0.16],
		[0.2, 0.74, 0.18],
		[0.76, 0.88, 0.12],
	]:
		var center := content_rect.position + Vector2(
			content_rect.size.x * float(cloud_spec[0]),
			content_rect.size.y * float(cloud_spec[1])
		)
		var radius := content_rect.size.x * float(cloud_spec[2])
		canvas.draw_circle(center, radius, cloud_color)
		canvas.draw_circle(center + Vector2(radius * 0.65, radius * 0.08), radius * 0.72, cloud_color)
	var cliff_color := Color(0.25, 0.29, 0.28, 0.5)
	canvas.draw_colored_polygon(PackedVector2Array([
		content_rect.position + Vector2(0.0, content_rect.size.y * 0.42),
		content_rect.position + Vector2(content_rect.size.x * 0.22, content_rect.size.y * 0.24),
		content_rect.position + Vector2(content_rect.size.x * 0.3, content_rect.size.y),
		content_rect.position + Vector2(0.0, content_rect.size.y),
	]), cliff_color)
	canvas.draw_colored_polygon(PackedVector2Array([
		content_rect.position + Vector2(content_rect.size.x, content_rect.size.y * 0.52),
		content_rect.position + Vector2(content_rect.size.x * 0.78, content_rect.size.y * 0.3),
		content_rect.position + Vector2(content_rect.size.x * 0.7, content_rect.size.y),
		content_rect.end,
	]), cliff_color)


func _draw_locked_phase_hints(
	canvas: CanvasItem,
	panel_rect: Rect2,
	hints_value: Variant
) -> void:
	var hints: Array = hints_value if hints_value is Array else []
	for hint_variant in hints:
		if not (hint_variant is Dictionary) or not bool((hint_variant as Dictionary).get("locked", false)):
			continue
		var hint_rect := Rect2(
			panel_rect.end.x - 278.0,
			panel_rect.position.y + 78.0,
			244.0,
			34.0
		)
		canvas.draw_rect(hint_rect, Color(SEALED, 0.78), true)
		canvas.draw_rect(hint_rect, GOLD, false, 1.0)
		canvas.draw_string(
			ThemeDB.fallback_font,
			hint_rect.position + Vector2(0.0, 23.0),
			TowerAscentMapOverlayLocalization.text(
				TowerAscentMapOverlayLocalization.KEY_REALM_IMMORTAL_LOCKED
			),
			HORIZONTAL_ALIGNMENT_CENTER,
			hint_rect.size.x,
			13,
			PAPER
		)


func _draw_floor_reveal_title(
	canvas: CanvasItem,
	view_rect: Rect2,
	reveal_visual: Dictionary
) -> void:
	# 피드백2 9항: 새 층 진입(구름 걷힘) 위로 뜨는 디아블로식 구역 타이틀.
	# 걷힘의 단일 progress에서 알파를 파생하므로 스킵 클릭과 함께 사라지고,
	# 별도 타이머·게임플레이 상태를 만들지 않는 표시 전용 연출이다.
	if not bool(reveal_visual.get("active", false)):
		return
	var target_floor := int(reveal_visual.get("target_floor", 0))
	var title := TowerAscentFloorTitleCatalog.floor_title(target_floor)
	if title.is_empty():
		return
	var alpha := TowerAscentFloorTitleCatalog.title_alpha(
		float(reveal_visual.get("progress", 0.0))
	)
	if alpha <= 0.001:
		return
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var title_scale := maxf(0.6, view_rect.size.y / 750.0)
	var label := TowerAscentFloorTitleCatalog.floor_label(target_floor)
	var label_font_size := maxi(12, int(round(19.0 * title_scale)))
	var title_font_size := maxi(24, int(round(50.0 * title_scale)))
	var label_baseline := Vector2(
		view_rect.position.x,
		view_rect.position.y + view_rect.size.y * 0.285
	)
	var title_baseline := label_baseline + Vector2(0.0, 58.0 * title_scale)
	var shadow_ink := Color(0.03, 0.02, 0.012, 0.62 * alpha)
	var outline_ink := Color(0.10, 0.066, 0.032, 0.90 * alpha)
	canvas.draw_string(
		font,
		label_baseline + Vector2(1.5, 2.0) * title_scale,
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		view_rect.size.x,
		label_font_size,
		shadow_ink
	)
	canvas.draw_string_outline(
		font,
		label_baseline,
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		view_rect.size.x,
		label_font_size,
		maxi(2, int(round(4.0 * title_scale))),
		outline_ink
	)
	canvas.draw_string(
		font,
		label_baseline,
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		view_rect.size.x,
		label_font_size,
		Color(0.90, 0.78, 0.50, alpha)
	)
	canvas.draw_string(
		font,
		title_baseline + Vector2(2.0, 3.0) * title_scale,
		title,
		HORIZONTAL_ALIGNMENT_CENTER,
		view_rect.size.x,
		title_font_size,
		shadow_ink
	)
	canvas.draw_string_outline(
		font,
		title_baseline,
		title,
		HORIZONTAL_ALIGNMENT_CENTER,
		view_rect.size.x,
		title_font_size,
		maxi(3, int(round(8.0 * title_scale))),
		outline_ink
	)
	canvas.draw_string(
		font,
		title_baseline,
		title,
		HORIZONTAL_ALIGNMENT_CENTER,
		view_rect.size.x,
		title_font_size,
		Color(0.97, 0.87, 0.58, alpha)
	)


func _draw_fullscreen_transition_marker(
	canvas: CanvasItem,
	marker_value: Variant,
	walker_model: Dictionary = {},
	art_size: float = 24.0,
	camera_model: Dictionary = {}
) -> void:
	if not (marker_value is Dictionary) or (marker_value as Dictionary).is_empty():
		return
	var marker := marker_value as Dictionary
	var progress := clampf(float(marker.get("progress", 0.0)), 0.0, 1.0)
	var from_position := _vector2(marker.get("from_position", Vector2.ZERO))
	var to_position := _vector2(marker.get("to_position", Vector2.ZERO))
	var position := _camera_world_to_screen(
		camera_model,
		_vector2(marker.get("world_position", from_position.lerp(to_position, progress)))
	)
	var camera_zoom_multiplier := _camera_render_zoom(camera_model)
	var marker_scale := clampf(float(marker.get("scale", 1.0)), 0.0, 1.0)
	var marker_alpha := clampf(float(marker.get("alpha", 1.0)), 0.0, 1.0)
	if marker_alpha <= 0.001 or marker_scale <= 0.001:
		return
	if _draw_fullscreen_walker(
		canvas,
		walker_model,
		position,
		bool(marker.get("facing_right", to_position.x >= from_position.x)),
		progress,
		art_size * camera_zoom_multiplier,
		marker_scale,
		marker_alpha
	):
		return
	canvas.draw_circle(
		position,
		(13.0 + 2.0 * sin(progress * PI)) * marker_scale,
		Color(CINNABAR, marker_alpha)
	)
	canvas.draw_circle(
		position,
		19.0 * marker_scale,
		Color(GOLD, marker_alpha),
		false,
		3.0 * marker_scale
	)


func _draw_fullscreen_walker(
	canvas: CanvasItem,
	walker_model: Dictionary,
	position: Vector2,
	facing_right: bool,
	travel_progress: float,
	art_size: float,
	marker_scale: float,
	marker_alpha: float
) -> bool:
	var preferred_key := "right_texture" if facing_right else "left_texture"
	var fallback_key := "left_texture" if facing_right else "right_texture"
	var texture_value: Variant = walker_model.get(preferred_key, null)
	var mirror_x := false
	if not (texture_value is Texture2D):
		texture_value = walker_model.get(fallback_key, null)
		mirror_x = texture_value is Texture2D
	if not (texture_value is Texture2D):
		return false
	var texture := texture_value as Texture2D
	var grid_cols := maxi(1, int(walker_model.get("grid_cols", 4)))
	var grid_rows := maxi(1, int(walker_model.get("grid_rows", 2)))
	var frame_count := clampi(int(walker_model.get("frame_count", 8)), 1, grid_cols * grid_rows)
	var frame_index := int(floor(travel_progress * float(frame_count) * 3.0)) % frame_count
	var frame_col := frame_index % grid_cols
	var frame_row := frame_index / grid_cols
	var uv_min := Vector2(float(frame_col) / float(grid_cols), float(frame_row) / float(grid_rows))
	var uv_max := Vector2(float(frame_col + 1) / float(grid_cols), float(frame_row + 1) / float(grid_rows))
	if mirror_x:
		var swap_x := uv_min.x
		uv_min.x = uv_max.x
		uv_max.x = swap_x
	var draw_size := Vector2.ONE * maxf(28.0, art_size * 1.9) * marker_scale
	var half := draw_size * 0.5
	var points := PackedVector2Array([
		position + Vector2(-half.x, -half.y),
		position + Vector2(half.x, -half.y),
		position + Vector2(half.x, half.y),
		position + Vector2(-half.x, half.y),
	])
	var uvs := PackedVector2Array([
		Vector2(uv_min.x, uv_min.y),
		Vector2(uv_max.x, uv_min.y),
		Vector2(uv_max.x, uv_max.y),
		Vector2(uv_min.x, uv_max.y),
	])
	canvas.draw_polygon(
		points,
		PackedColorArray([Color(1.0, 1.0, 1.0, marker_alpha)]),
		uvs,
		texture
	)
	return true


func _draw_fullscreen_map_node(
	canvas: CanvasItem,
	node: Dictionary,
	active_candidate_ids: Array,
	current_node_id: String,
	selected_target_id: String,
	pointer_selected_node_id: String,
	content_rect: Rect2,
	camera_model: Dictionary = {}
) -> void:
	var node_id := str(node.get("id", ""))
	var world_art_rect: Rect2 = node.get("world_art_rect", Rect2())
	var art_rect := _camera_world_rect_to_screen(camera_model, world_art_rect)
	var screen_position := _camera_world_to_screen(
		camera_model,
		_vector2(node.get("world_position", world_art_rect.get_center()))
	)
	if not content_rect.grow(-3.0).encloses(art_rect.grow(3.0)):
		return
	var current := node_id == current_node_id
	var active := active_candidate_ids.has(node_id)
	var selected := not selected_target_id.is_empty() and node_id == selected_target_id
	var pointer_selected := (
		not pointer_selected_node_id.is_empty()
		and node_id == pointer_selected_node_id
	)
	var completed := bool(node.get("completed", false))
	var skipped := bool(node.get("skipped", false))
	var route_locked := bool(node.get("route_locked", false))
	var enraged := bool(node.get("enraged", false))
	var frame_color := CINNABAR if current or selected else GOLD if active else INK
	if enraged:
		frame_color = CINNABAR
	if route_locked or skipped:
		frame_color = SEALED
	var medal_radius := art_rect.size.x * 0.5
	var medal_fill := GOLD if completed or current else PAPER_DEEP
	if route_locked or skipped:
		medal_fill = SEALED
	elif enraged:
		medal_fill = CINNABAR_DARK
	elif active:
		medal_fill = Color("e6c15c")
	if selected:
		medal_fill = CINNABAR
	canvas.draw_circle(screen_position, medal_radius, medal_fill)
	canvas.draw_circle(
		screen_position,
		medal_radius,
		frame_color,
		false,
		2.0 if current or active or selected else 1.0
	)
	if pointer_selected:
		canvas.draw_circle(
			screen_position,
			medal_radius + maxf(3.0, art_rect.size.x * 0.08),
			GOLD,
			false,
			3.0
		)
	var icon_presentation := build_map_icon_presentation(node)
	var icon_texture_value: Variant = icon_presentation.get("icon_texture", null)
	if icon_texture_value is Texture2D:
		var icon_inset := art_rect.size.x * 0.08
		canvas.draw_texture_rect(
			icon_texture_value as Texture2D,
			art_rect.grow(-icon_inset),
			false,
			_map_icon_modulate(route_locked, skipped, completed, current)
		)
	if current:
		canvas.draw_circle(screen_position, art_rect.size.x * 0.72, CINNABAR, false, 3.0)
	if skipped:
		canvas.draw_line(art_rect.position, art_rect.end, PAPER, 2.0)
		canvas.draw_line(
			Vector2(art_rect.end.x, art_rect.position.y),
			Vector2(art_rect.position.x, art_rect.end.y),
			PAPER,
			2.0
		)
	var display_label := str(icon_presentation.get("fallback_label", ""))
	var left_lane := screen_position.x < content_rect.get_center().x - 1.0
	var label_width := clampf(content_rect.size.x * 0.22, 76.0, 170.0)
	var label_x := art_rect.position.x - label_width - 9.0 if left_lane else art_rect.end.x + 9.0
	var alignment := HORIZONTAL_ALIGNMENT_RIGHT if left_lane else HORIZONTAL_ALIGNMENT_LEFT
	if not display_label.is_empty():
		canvas.draw_string(
			ThemeDB.fallback_font,
			Vector2(label_x, screen_position.y + 4.0),
			display_label,
			alignment,
			label_width,
			10,
			INK
		)
	var state_label := TowerAscentMapOverlayLocalization.node_state_label(
		current,
		completed,
		skipped,
		route_locked
	)
	if not state_label.is_empty():
		canvas.draw_string(
			ThemeDB.fallback_font,
			Vector2(label_x, screen_position.y + 14.0),
			state_label,
			alignment,
			label_width,
			8,
			CINNABAR_DARK if current else INK_SOFT
		)


func _draw_map_surface(
	canvas: CanvasItem,
	flow: Object,
	map_overlay: bool = false
) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, PLAYFIELD_SIZE), Color(0.035, 0.025, 0.02, 0.92), true)
	var render_model := build_render_model(flow)
	var scroll_background_value: Variant = render_model.get("legacy_scroll_background", {})
	var scroll_background: Dictionary = (
		scroll_background_value as Dictionary
		if scroll_background_value is Dictionary
		else {}
	)
	if bool(scroll_background.get("ready", false)):
		_draw_scroll_background_model(canvas, scroll_background, MAP_RECT)
	else:
		canvas.draw_rect(MAP_RECT, PAPER, true)
	canvas.draw_rect(MAP_RECT, INK, false, 4.0)
	canvas.draw_rect(MAP_RECT.grow(-8.0), PAPER_DEEP, false, 1.5)
	_draw_title(canvas, flow, map_overlay)
	_draw_route_map(canvas, flow, map_overlay)
	if map_overlay:
		_draw_map_overlay_legend(canvas)


func build_render_model(flow: Object) -> Dictionary:
	if flow == null:
		return {}
	var revision := int(flow.get_map_render_revision()) if flow.has_method("get_map_render_revision") else 0
	var phase_index := int(flow.get_active_graph_phase_index()) if flow.has_method("get_active_graph_phase_index") else 0
	var graph_key := "%d:%d:%d" % [flow.get_instance_id(), phase_index, revision]
	if graph_key != _cached_graph_key:
		var nodes: Array = flow.get_graph_nodes() if flow.has_method("get_graph_nodes") else []
		if nodes.is_empty():
			return {}
		var phase: Dictionary = (
			flow.peek_active_graph_phase()
			if flow.has_method("peek_active_graph_phase")
			else flow.get_active_graph_phase()
			if flow.has_method("get_active_graph_phase")
			else {}
		)
		_cached_graph_key = graph_key
		_cached_render_model = {
			"floors": flow.get_graph_floors() if flow.has_method("get_graph_floors") else [],
			"nodes": nodes,
			"edges": flow.get_graph_edges() if flow.has_method("get_graph_edges") else [],
			"phase": phase,
			"realm_kind": str(phase.get("realm_kind", "human_realm")),
			"locked_phase_hints": phase.get("locked_phase_hints", []),
			"map_seed": flow.get_map_seed() if flow.has_method("get_map_seed") else 0,
			"map_scroll_assets": _collect_map_scroll_asset_resolutions(flow),
		}
		_cached_render_model["legacy_route_edges"] = _build_legacy_route_edges(
			_cached_render_model.get("edges", []),
			nodes
		)
		_cached_render_model["legacy_scroll_background"] = build_scroll_background_model(
			_build_legacy_floor_band_markers(
				_cached_render_model.get("floors", []),
				nodes
			),
			MAP_RECT,
			str(_cached_render_model.get("realm_kind", "human_realm")),
			_cached_render_model.get("map_scroll_assets", {})
		)
		_cached_fullscreen_key = ""
		_cached_fullscreen_model.clear()
		_graph_cache_build_count += 1
	var result := _cached_render_model.duplicate(false)
	result["active_candidate_ids"] = flow.get_route_target_ids() if flow.has_method("get_route_target_ids") else []
	result["current_node_id"] = str(flow.get_current_node_id()) if flow.has_method("get_current_node_id") else ""
	result["selected_target_id"] = str(flow.get_selected_target_id()) if flow.has_method("get_selected_target_id") else ""
	result["route_history"] = flow.get_route_history() if flow.has_method("get_route_history") else []
	return result


func build_scroll_background_model(
	floor_bands_value: Variant,
	world_rect: Rect2,
	realm_kind: String,
	resolution_by_key_value: Variant,
	tile_size: Vector2 = MAP_SCROLL_TILE_SIZE
) -> Dictionary:
	if world_rect.size.x <= 0.0 or world_rect.size.y <= 0.0:
		return {"ready": false, "reason": "invalid_world_rect", "tiles": []}
	var floor_bands: Array = floor_bands_value.duplicate(true) if floor_bands_value is Array else []
	if floor_bands.is_empty():
		return {"ready": false, "reason": "missing_floor_bands", "tiles": []}
	floor_bands.sort_custom(func(a: Variant, b: Variant) -> bool:
		return float((a as Dictionary).get("y", 0.0)) < float((b as Dictionary).get("y", 0.0))
	)
	var resolution_by_key: Dictionary = (
		resolution_by_key_value as Dictionary
		if resolution_by_key_value is Dictionary
		else {}
	)
	var paper_resolution: Dictionary = resolution_by_key.get(
		TowerMapScrollAssetCatalog.COMMON_HANJI_PAPER,
		{}
	)
	var paper_texture := paper_resolution.get("texture", null) as Texture2D
	if not bool(paper_resolution.get("ready", false)) or paper_texture == null:
		return {"ready": false, "reason": "paper_unavailable", "tiles": []}
	var tiles: Array[Dictionary] = []
	var draw_chunks: Array[Dictionary] = []
	var previous_asset_key := ""
	for index in range(floor_bands.size()):
		var band := floor_bands[index] as Dictionary
		var floor_number := int(band.get("segment_floor", band.get("floor", 0)))
		var band_realm_kind := str(band.get("realm_kind", realm_kind))
		var band_rect: Rect2 = band.get("segment_rect", band.get("rect", Rect2(
			Vector2(
				world_rect.position.x,
				float(band.get("y", world_rect.get_center().y)) - tile_size.y * 0.5
			),
			tile_size
		)))
		if not band_rect.has_area():
			continue
		var first_band_asset_key := ""
		var first_band_texture: Texture2D = null
		var chunk_y := band_rect.position.y
		while chunk_y < band_rect.end.y - 0.001:
			var chunk_height := minf(tile_size.y, band_rect.end.y - chunk_y)
			var asset_key := TowerMapScrollAssetCatalog.resolve_band_asset_key(
				band_realm_kind,
				floor_number,
				previous_asset_key
			)
			var resolution: Dictionary = resolution_by_key.get(asset_key, {})
			var texture := resolution.get("texture", null) as Texture2D
			if not bool(resolution.get("ready", false)) or texture == null:
				return {
					"ready": false,
					"reason": "band_unavailable",
					"missing_asset_key": asset_key,
					"tiles": [],
				}
			if first_band_texture == null:
				first_band_asset_key = asset_key
				first_band_texture = texture
			draw_chunks.append({
				"floor": floor_number,
				"realm_kind": band_realm_kind,
				"asset_key": asset_key,
				"rect": Rect2(
					Vector2(world_rect.position.x, chunk_y),
					Vector2(tile_size.x, chunk_height)
				),
				"normalized_source_rect": Rect2(
					Vector2.ZERO,
					Vector2(1.0, chunk_height / tile_size.y)
				),
				"paper_texture": paper_texture,
				"texture": texture,
			})
			previous_asset_key = asset_key
			chunk_y += chunk_height
		if first_band_texture != null:
			tiles.append({
				"floor": floor_number,
				"realm_kind": band_realm_kind,
				"asset_key": first_band_asset_key,
				# `tiles` remains the one-approved-art-per-floor contract used
				# by content-scale seals. Rendering consumes draw_chunks so an
				# expanded segment repeats/crops art instead of stretching it.
				"rect": Rect2(
					Vector2(
						world_rect.position.x,
						float(band.get("y", band_rect.get_center().y))
							- tile_size.y * 0.5
					),
					tile_size
				),
				"band_rect": band_rect,
				"paper_texture": paper_texture,
				"texture": first_band_texture,
			})
	if tiles.is_empty() or draw_chunks.is_empty():
		return {"ready": false, "reason": "missing_band_tiles", "tiles": []}
	var first_tile_rect: Rect2 = (draw_chunks[0] as Dictionary).get("rect", Rect2())
	var last_tile_rect: Rect2 = (draw_chunks[-1] as Dictionary).get("rect", Rect2())
	var tile_world_rect := Rect2(
		Vector2(world_rect.position.x, first_tile_rect.position.y),
		Vector2(tile_size.x, last_tile_rect.end.y - first_tile_rect.position.y)
	)
	return {
		"ready": true,
		"reason": "approved_tiles_ready",
		"world_rect": tile_world_rect,
		"realm_kind": realm_kind,
		"tiles": tiles,
		"draw_chunks": draw_chunks,
	}


func resolve_segment_floor_for_world_y(
	floor_bands_value: Variant,
	world_y: float
) -> int:
	var floor_bands: Array = (
		floor_bands_value as Array
		if floor_bands_value is Array
		else []
	)
	var boundary_epsilon := 0.01
	var maximum_bottom := -INF
	for band_variant in floor_bands:
		if band_variant is Dictionary:
			var band_rect: Rect2 = (band_variant as Dictionary).get(
				"segment_rect",
				(band_variant as Dictionary).get("rect", Rect2())
			)
			maximum_bottom = maxf(maximum_bottom, band_rect.end.y)
	for band_variant in floor_bands:
		if not (band_variant is Dictionary):
			continue
		var band := band_variant as Dictionary
		var band_rect: Rect2 = band.get("segment_rect", band.get("rect", Rect2()))
		if not band_rect.has_area():
			continue
		var inside_half_open := (
			world_y >= band_rect.position.y - boundary_epsilon
			and world_y < band_rect.end.y - boundary_epsilon
		)
		var closes_outer_bottom := (
			is_equal_approx(band_rect.end.y, maximum_bottom)
			and is_equal_approx(world_y, band_rect.end.y)
		)
		if inside_half_open or closes_outer_bottom:
			return int(band.get("segment_floor", band.get("floor", 0)))
	return 0


func _collect_map_scroll_asset_resolutions(flow: Object) -> Dictionary:
	var result: Dictionary = {}
	if flow == null or not flow.has_method("get_map_scroll_asset_resolution"):
		return result
	for asset_key in TowerMapScrollAssetCatalog.ASSET_SPECS.keys():
		result[str(asset_key)] = flow.get_map_scroll_asset_resolution(str(asset_key))
	return result


func _build_legacy_floor_band_markers(floors_value: Variant, nodes: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var floors: Array = floors_value if floors_value is Array else []
	for floor_variant in floors:
		if not (floor_variant is Dictionary):
			continue
		var floor_data := floor_variant as Dictionary
		var rows: Array = floor_data.get("rows", [])
		if rows.is_empty() or not (rows[rows.size() - 1] is Dictionary):
			continue
		var gate_ids: Array = (rows[rows.size() - 1] as Dictionary).get("node_ids", [])
		if gate_ids.is_empty():
			continue
		result.append({
			"floor": int(floor_data.get("floor", 0)),
			"y": _find_node_position(nodes, str(gate_ids[0])).y,
		})
	return result


func _build_legacy_route_edges(edges_value: Variant, nodes: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var edges: Array = edges_value if edges_value is Array else []
	for edge_variant in edges:
		if not (edge_variant is Dictionary):
			continue
		var edge := (edge_variant as Dictionary).duplicate(true)
		var from_position := _find_node_position(nodes, str(edge.get("from", "")))
		var to_position := _find_node_position(nodes, str(edge.get("to", "")))
		edge["from_position"] = from_position
		edge["to_position"] = to_position
		var route_points := PackedVector2Array([from_position, to_position])
		edge["brush_quads"] = build_route_brush_strip(route_points)
		edge["completed_brush_quads"] = build_completed_route_brush_strip(
			route_points
		)
		result.append(edge)
	return result


func resolve_route_brush_asset_key(
	edge: Dictionary,
	route_history_value: Variant,
	active_candidate_ids_value: Variant,
	current_node_id: String
) -> String:
	var from_id := str(edge.get("from", ""))
	var to_id := str(edge.get("to", ""))
	var route_history: Array = route_history_value if route_history_value is Array else []
	for route_variant in route_history:
		if not (route_variant is Dictionary):
			continue
		var route := route_variant as Dictionary
		if str(route.get("from", "")) == from_id and str(route.get("to", "")) == to_id:
			return TowerMapScrollAssetCatalog.ROUTE_BRUSH_COMPLETED_GOLD
	var active_candidate_ids: Array = (
		active_candidate_ids_value
		if active_candidate_ids_value is Array
		else []
	)
	if from_id == current_node_id and active_candidate_ids.has(to_id):
		return TowerMapScrollAssetCatalog.ROUTE_BRUSH_AVAILABLE
	return TowerMapScrollAssetCatalog.ROUTE_BRUSH_UNSELECTED


func should_draw_route_edge_in_view(
	edge: Dictionary,
	asset_key: String,
	clip_rect: Rect2,
	camera_model: Dictionary = {}
) -> bool:
	if asset_key == TowerMapScrollAssetCatalog.ROUTE_BRUSH_COMPLETED_GOLD:
		return true
	var from_screen := _camera_world_to_screen(
		camera_model,
		edge.get("from_position", Vector2.ZERO) as Vector2
	)
	var to_screen := _camera_world_to_screen(
		camera_model,
		edge.get("to_position", Vector2.ZERO) as Vector2
	)
	return clip_rect.has_point(from_screen) and clip_rect.has_point(to_screen)


func build_route_brush_strip(
	points: PackedVector2Array,
	map_scale: float = 1.0
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if points.size() < 2:
		return result
	var cumulative_distances := PackedFloat32Array([0.0])
	var total_distance := 0.0
	for index in range(1, points.size()):
		total_distance += points[index - 1].distance_to(points[index])
		cumulative_distances.append(total_distance)
	if total_distance <= 0.001:
		return result
	var safe_scale := maxf(0.001, map_scale)
	var target_width := MAP_SCROLL_ROUTE_BRUSH_WIDTH * safe_scale
	var tile_length := MAP_SCROLL_ROUTE_BRUSH_TILE_LENGTH * safe_scale
	var tile_stride := MAP_SCROLL_ROUTE_BRUSH_TILE_STRIDE * safe_scale
	var half_width := target_width * 0.5
	var tile_start_distance := 0.0
	var tile_index := 0
	while tile_start_distance < total_distance - 0.001:
		var tile_end_distance := minf(
			tile_start_distance + tile_length,
			total_distance
		)
		var start_point := _sample_polyline_at_distance(
			points,
			cumulative_distances,
			tile_start_distance
		)
		var end_point := _sample_polyline_at_distance(
			points,
			cumulative_distances,
			tile_end_distance
		)
		var path_direction := (end_point - start_point).normalized()
		if not path_direction.is_zero_approx():
			var path_normal := Vector2(-path_direction.y, path_direction.x)
			var quad := PackedVector2Array([
				start_point - path_normal * half_width,
				start_point + path_normal * half_width,
				end_point + path_normal * half_width,
				end_point - path_normal * half_width,
			])
			var end_v := clampf(
				(tile_end_distance - tile_start_distance)
					/ tile_length,
				0.0,
				1.0
			)
			result.append({
				"points": quad,
				"uvs": PackedVector2Array([
					Vector2(0.0, 0.0),
					Vector2(1.0, 0.0),
					Vector2(1.0, end_v),
					Vector2(0.0, end_v),
				]),
				"bounds": _packed_points_bounds(quad),
				"world_length": tile_end_distance - tile_start_distance,
				"target_width": target_width,
				"tile_index": tile_index,
				"tile_start_distance": tile_start_distance,
				"tile_stride": tile_stride,
				"path_direction": path_direction,
			})
		tile_start_distance += tile_stride
		tile_index += 1
	return result


func build_completed_route_brush_strip(
	points: PackedVector2Array,
	map_scale: float = 1.0
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if points.size() < 2:
		return result
	var cumulative_distances := PackedFloat32Array([0.0])
	var total_distance := 0.0
	for index in range(1, points.size()):
		total_distance += points[index - 1].distance_to(points[index])
		cumulative_distances.append(total_distance)
	if total_distance <= 0.001:
		return result
	var break_distances := PackedFloat32Array([0.0])
	for index in range(1, cumulative_distances.size() - 1):
		break_distances.append(cumulative_distances[index])
	var safe_scale := maxf(0.001, map_scale)
	var target_width := MAP_SCROLL_ROUTE_BRUSH_WIDTH * safe_scale
	var tile_length := MAP_SCROLL_ROUTE_BRUSH_TILE_LENGTH * safe_scale
	var tile_boundary := tile_length
	while tile_boundary < total_distance - 0.001:
		break_distances.append(tile_boundary)
		tile_boundary += tile_length
	break_distances.append(total_distance)
	break_distances.sort()
	var half_width := target_width * 0.5
	for index in range(1, break_distances.size()):
		var start_distance := float(break_distances[index - 1])
		var end_distance := float(break_distances[index])
		if end_distance - start_distance <= 0.001:
			continue
		var start_point := _sample_polyline_at_distance(
			points,
			cumulative_distances,
			start_distance
		)
		var end_point := _sample_polyline_at_distance(
			points,
			cumulative_distances,
			end_distance
		)
		var start_normal := _polyline_normal_at_distance(
			points,
			cumulative_distances,
			start_distance
		)
		var end_normal := _polyline_normal_at_distance(
			points,
			cumulative_distances,
			end_distance
		)
		var tile_start_distance := floorf(
			(start_distance + 0.001) / tile_length
		) * tile_length
		var start_v := clampf(
			(start_distance - tile_start_distance) / tile_length,
			0.0,
			1.0
		)
		var end_v := clampf(
			(end_distance - tile_start_distance) / tile_length,
			0.0,
			1.0
		)
		if is_zero_approx(end_v) or end_distance >= tile_start_distance + tile_length - 0.001:
			end_v = 1.0
		var quad := PackedVector2Array([
			start_point - start_normal * half_width,
			start_point + start_normal * half_width,
			end_point + end_normal * half_width,
			end_point - end_normal * half_width,
		])
		result.append({
			"points": quad,
			"uvs": PackedVector2Array([
				Vector2(0.0, start_v),
				Vector2(1.0, start_v),
				Vector2(1.0, end_v),
				Vector2(0.0, end_v),
			]),
			"bounds": _packed_points_bounds(quad),
			"world_length": end_distance - start_distance,
			"target_width": target_width,
		})
	return result


func _sample_polyline_at_distance(
	points: PackedVector2Array,
	cumulative_distances: PackedFloat32Array,
	distance: float
) -> Vector2:
	var safe_distance := clampf(distance, 0.0, float(cumulative_distances[-1]))
	for index in range(1, cumulative_distances.size()):
		var segment_end := float(cumulative_distances[index])
		if safe_distance > segment_end and index < cumulative_distances.size() - 1:
			continue
		var segment_start := float(cumulative_distances[index - 1])
		var segment_length := maxf(0.001, segment_end - segment_start)
		return points[index - 1].lerp(
			points[index],
			clampf((safe_distance - segment_start) / segment_length, 0.0, 1.0)
		)
	return points[-1]


func _polyline_normal_at_distance(
	points: PackedVector2Array,
	cumulative_distances: PackedFloat32Array,
	distance: float
) -> Vector2:
	var total_distance := float(cumulative_distances[-1])
	var sample_radius := minf(1.0, total_distance * 0.01)
	var before := _sample_polyline_at_distance(
		points,
		cumulative_distances,
		maxf(0.0, distance - sample_radius)
	)
	var after := _sample_polyline_at_distance(
		points,
		cumulative_distances,
		minf(total_distance, distance + sample_radius)
	)
	var tangent := (after - before).normalized()
	if tangent.is_zero_approx():
		tangent = Vector2.UP
	return Vector2(-tangent.y, tangent.x)


func _attach_route_brush_strips(
	edges_value: Variant,
	map_scale: float = 1.0
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var edges: Array = edges_value if edges_value is Array else []
	for edge_variant in edges:
		if not (edge_variant is Dictionary):
			continue
		var edge := (edge_variant as Dictionary).duplicate(true)
		var points: PackedVector2Array = edge.get("path_points", PackedVector2Array())
		edge["brush_quads"] = build_route_brush_strip(points, map_scale)
		edge["completed_brush_quads"] = build_completed_route_brush_strip(
			points,
			map_scale
		)
		result.append(edge)
	return result


func _route_brush_quads_for_asset(edge: Dictionary, asset_key: String) -> Array:
	if asset_key == TowerMapScrollAssetCatalog.ROUTE_BRUSH_COMPLETED_GOLD:
		var completed_value: Variant = edge.get("completed_brush_quads", [])
		return completed_value if completed_value is Array else []
	var dense_value: Variant = edge.get("brush_quads", [])
	return dense_value if dense_value is Array else []


func _route_brush_segment_count(edges_value: Variant) -> int:
	var count := 0
	var edges: Array = edges_value if edges_value is Array else []
	for edge_variant in edges:
		if edge_variant is Dictionary:
			count += ((edge_variant as Dictionary).get("brush_quads", []) as Array).size()
	return count


func _packed_points_bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var minimum := points[0]
	var maximum := points[0]
	for point in points:
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)
	return Rect2(minimum, maximum - minimum)


func _cached_map_scroll_texture(
	resolution_by_key_value: Variant,
	asset_key: String
) -> Texture2D:
	var resolution_by_key: Dictionary = (
		resolution_by_key_value as Dictionary
		if resolution_by_key_value is Dictionary
		else {}
	)
	var resolution: Dictionary = resolution_by_key.get(asset_key, {})
	if not bool(resolution.get("ready", false)):
		return null
	return resolution.get("texture", null) as Texture2D


func _draw_route_brush_strip(
	canvas: CanvasItem,
	brush_quads_value: Variant,
	texture: Texture2D,
	clip_rect: Rect2,
	camera_model: Dictionary = {}
) -> void:
	var brush_quads: Array = brush_quads_value if brush_quads_value is Array else []
	for quad_variant in brush_quads:
		if not (quad_variant is Dictionary):
			continue
		var quad := quad_variant as Dictionary
		var world_points: PackedVector2Array = quad.get("points", PackedVector2Array())
		var screen_points := PackedVector2Array()
		for point in world_points:
			screen_points.append(_camera_world_to_screen(camera_model, point))
		if not _packed_points_bounds(screen_points).intersects(clip_rect):
			continue
		canvas.draw_polygon(
			screen_points,
			PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]),
			quad.get("uvs", PackedVector2Array()),
			texture
		)


func _draw_fullscreen_procedural_dotted_edge(
	canvas: CanvasItem,
	edge: Dictionary,
	content_rect: Rect2,
	camera_model: Dictionary,
	art_size: float
) -> void:
	var outer_radius := art_size * TowerAscentTuning.TEMP_MAP_PATH_DOT_OUTER_RADIUS_ART_RATIO
	var inner_radius := art_size * TowerAscentTuning.TEMP_MAP_PATH_DOT_INNER_RADIUS_ART_RATIO
	var camera_zoom := _camera_render_zoom(camera_model)
	for dot_variant in edge.get("dots", []):
		if not (dot_variant is Dictionary):
			continue
		var center := _camera_world_to_screen(
			camera_model,
			(dot_variant as Dictionary).get("center", Vector2.ZERO)
		)
		if not content_rect.has_point(center):
			continue
		canvas.draw_circle(center, outer_radius * camera_zoom, Color(CINNABAR_DARK, 0.72))
		canvas.draw_circle(center, inner_radius * camera_zoom, Color(GOLD, 0.94))


func _draw_scroll_background_model(
	canvas: CanvasItem,
	model: Dictionary,
	clip_rect: Rect2,
	camera_model: Dictionary = {}
) -> void:
	if not bool(model.get("ready", false)):
		return
	for tile_variant in model.get("draw_chunks", model.get("tiles", [])):
		if not (tile_variant is Dictionary):
			continue
		var tile := tile_variant as Dictionary
		var world_target: Rect2 = tile.get("rect", Rect2())
		_draw_scroll_texture_region(
			canvas,
			tile.get("paper_texture", null) as Texture2D,
			world_target,
			clip_rect,
			camera_model,
			tile.get("normalized_source_rect", Rect2(0.0, 0.0, 1.0, 1.0))
		)
		_draw_scroll_texture_region(
			canvas,
			tile.get("texture", null) as Texture2D,
			world_target,
			clip_rect,
			camera_model,
			tile.get("normalized_source_rect", Rect2(0.0, 0.0, 1.0, 1.0))
		)


func _draw_scroll_texture_region(
	canvas: CanvasItem,
	texture: Texture2D,
	world_target: Rect2,
	clip_rect: Rect2,
	camera_model: Dictionary,
	normalized_source_rect: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0)
) -> void:
	if texture == null or world_target.size.x <= 0.0 or world_target.size.y <= 0.0:
		return
	var projected_target := _camera_world_rect_to_screen(camera_model, world_target)
	var visible_target := projected_target.intersection(clip_rect)
	if visible_target.size.x <= 0.0 or visible_target.size.y <= 0.0:
		return
	var texture_size := texture.get_size()
	var relative_position := (visible_target.position - projected_target.position) / projected_target.size
	var relative_size := visible_target.size / projected_target.size
	var normalized_source_size := normalized_source_rect.size
	var source_rect := Rect2(
		texture_size * (
			normalized_source_rect.position
			+ normalized_source_size * relative_position
		),
		texture_size * normalized_source_size * relative_size
	)
	canvas.draw_texture_rect_region(
		texture,
		visible_target,
		source_rect,
		Color.WHITE,
		false,
		true
	)


func get_render_cache_debug_state() -> Dictionary:
	var cloud_model: Dictionary = _cached_fullscreen_model.get("cloud_layer", {})
	var cloud_draw_calls := int(cloud_model.get("draw_call_count", 0))
	return {
		"graph_key": _cached_graph_key,
		"graph_build_count": _graph_cache_build_count,
		"fullscreen_key": _cached_fullscreen_key,
		"fullscreen_build_count": _fullscreen_cache_build_count,
		"path_build_count": _path_cache_build_count,
		"path_dot_count": _path_cached_dot_count,
		"path_dot_gap": _path_cached_dot_gap,
		"path_draw_call_budget": _path_cached_dot_count * 2,
		"cloud_draw_call_budget": cloud_draw_calls,
		"total_map_draw_call_budget": _path_cached_dot_count * 2 + cloud_draw_calls,
		"path_brush_segment_count": _path_cached_brush_segment_count,
		"path_brush_draw_call_budget": _path_cached_brush_segment_count,
	}


func _draw_title(canvas: CanvasItem, flow: Object, map_overlay: bool = false) -> void:
	var font := ThemeDB.fallback_font
	var title := (
		TowerAscentMapOverlayLocalization.text(TowerAscentMapOverlayLocalization.KEY_TITLE)
		if map_overlay
		else "승천탑 행로"
	)
	canvas.draw_string(font, Vector2(62.0, 70.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 30, INK)
	canvas.draw_string(
		font,
		Vector2(62.0, 98.0),
		flow.get_header_subtitle(),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		15,
		INK_SOFT
	)
	canvas.draw_circle(Vector2(683.0, 71.0), 24.0, CINNABAR)
	canvas.draw_circle(Vector2(683.0, 71.0), 18.0, PAPER, false, 2.0)
	canvas.draw_string(font, Vector2(670.0, 79.0), "塔", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, PAPER)
	if map_overlay:
		canvas.draw_string(
			font,
			Vector2(452.0, 101.0),
			TowerAscentMapOverlayLocalization.text(
				TowerAscentMapOverlayLocalization.KEY_CLOSE_HINT
			),
			HORIZONTAL_ALIGNMENT_RIGHT,
			184.0,
			13,
			INK_SOFT
		)


func _draw_route_map(canvas: CanvasItem, flow: Object, map_overlay: bool = false) -> void:
	var render_model := build_render_model(flow)
	var nodes: Array = render_model.get("nodes", [])
	var edges: Array = render_model.get("legacy_route_edges", [])
	if nodes.is_empty():
		return
	var floors: Array = render_model.get("floors", [])
	var active_candidate_ids: Array = render_model.get("active_candidate_ids", [])
	var current_node_id := str(render_model.get("current_node_id", ""))
	var selected_target_id := str(render_model.get("selected_target_id", ""))
	for edge_variant in edges:
		if not (edge_variant is Dictionary):
			continue
		var edge := edge_variant as Dictionary
		var brush_asset_key := resolve_route_brush_asset_key(
			edge,
			render_model.get("route_history", []),
			active_candidate_ids,
			current_node_id
		)
		if not should_draw_route_edge_in_view(
			edge,
			brush_asset_key,
			MAP_RECT
		):
			continue
		var brush_texture := _cached_map_scroll_texture(
			render_model.get("map_scroll_assets", {}),
			brush_asset_key
		)
		if brush_texture != null:
			_draw_route_brush_strip(
				canvas,
				_route_brush_quads_for_asset(edge, brush_asset_key),
				brush_texture,
				MAP_RECT
			)
		else:
			canvas.draw_line(
				edge.get("from_position", Vector2.ZERO),
				edge.get("to_position", Vector2.ZERO),
				Color(INK_SOFT, 0.46),
				1.5
			)
	_draw_floor_bands(
		canvas,
		floors,
		nodes,
		render_model.get("map_scroll_assets", {})
	)
	for node_variant in nodes:
		var node: Dictionary = node_variant
		_draw_map_node(
			canvas,
			node,
			active_candidate_ids,
			current_node_id,
			selected_target_id,
			map_overlay
		)


func _draw_floor_bands(
	canvas: CanvasItem,
	floors: Array,
	nodes: Array,
	resolution_by_key_value: Variant = {}
) -> void:
	var font := ThemeDB.fallback_font
	var plaque_texture := _cached_map_scroll_texture(
		resolution_by_key_value,
		TowerMapScrollAssetCatalog.FLOOR_GATE_PLAQUE
	)
	for floor_variant in floors:
		if not (floor_variant is Dictionary):
			continue
		var floor_data := floor_variant as Dictionary
		var rows: Array = floor_data.get("rows", [])
		if rows.is_empty() or not (rows[rows.size() - 1] is Dictionary):
			continue
		var gate_ids: Array = (rows[rows.size() - 1] as Dictionary).get("node_ids", [])
		if gate_ids.is_empty():
			continue
		var gate_position := _find_node_position(nodes, str(gate_ids[0]))
		if plaque_texture != null:
			_draw_floor_plaque(
				canvas,
				plaque_texture,
				build_floor_plaque_target_rect(gate_position),
				MAP_RECT,
				int(floor_data.get("floor", 0))
			)
		else:
			canvas.draw_line(Vector2(86.0, gate_position.y), Vector2(674.0, gate_position.y), Color(GOLD, 0.18), 1.0)
			canvas.draw_string(font, Vector2(53.0, gate_position.y + 4.0), "%dF" % int(floor_data.get("floor", 0)), HORIZONTAL_ALIGNMENT_CENTER, 30.0, 11, INK_SOFT)


func _draw_floor_plaque(
	canvas: CanvasItem,
	texture: Texture2D,
	target_rect: Rect2,
	clip_rect: Rect2,
	floor_number: int
) -> void:
	_draw_horizontal_three_slice(canvas, texture, target_rect, clip_rect)
	var font_size := maxi(12, int(round(target_rect.size.y * 0.42)))
	var baseline_y := target_rect.get_center().y + float(font_size) * 0.34
	var number_column_width := minf(
		target_rect.size.x * 0.2,
		maxf(72.0, target_rect.size.y * 2.4)
	)
	var number_column_x := target_rect.position.x + target_rect.size.y * 0.75
	canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(number_column_x, baseline_y),
		"%dF" % floor_number,
		HORIZONTAL_ALIGNMENT_CENTER,
		number_column_width,
		font_size,
		INK
	)


func build_floor_plaque_target_rect(center: Vector2, map_scale: float = 1.0) -> Rect2:
	var target_size := MAP_SCROLL_PLAQUE_SIZE * maxf(0.001, map_scale)
	return Rect2(center - target_size * 0.5, target_size)


func build_horizontal_three_slice_model(
	texture_size: Vector2,
	target_rect: Rect2
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return result
	if target_rect.size.x <= 0.0 or target_rect.size.y <= 0.0:
		return result
	var source_cap := minf(texture_size.y, texture_size.x * 0.5)
	var target_cap := minf(target_rect.size.y, target_rect.size.x * 0.5)
	var source_middle_width := maxf(0.0, texture_size.x - source_cap * 2.0)
	var target_middle_width := maxf(0.0, target_rect.size.x - target_cap * 2.0)
	result.append({
		"source_rect": Rect2(0.0, 0.0, source_cap, texture_size.y),
		"target_rect": Rect2(target_rect.position, Vector2(target_cap, target_rect.size.y)),
	})
	result.append({
		"source_rect": Rect2(source_cap, 0.0, source_middle_width, texture_size.y),
		"target_rect": Rect2(
			target_rect.position + Vector2(target_cap, 0.0),
			Vector2(target_middle_width, target_rect.size.y)
		),
	})
	result.append({
		"source_rect": Rect2(texture_size.x - source_cap, 0.0, source_cap, texture_size.y),
		"target_rect": Rect2(
			Vector2(target_rect.end.x - target_cap, target_rect.position.y),
			Vector2(target_cap, target_rect.size.y)
		),
	})
	return result


func _draw_horizontal_three_slice(
	canvas: CanvasItem,
	texture: Texture2D,
	target_rect: Rect2,
	clip_rect: Rect2
) -> void:
	if texture == null:
		return
	for slice in build_horizontal_three_slice_model(texture.get_size(), target_rect):
		_draw_clipped_screen_texture_region(
			canvas,
			texture,
			slice.get("target_rect", Rect2()),
			slice.get("source_rect", Rect2()),
			clip_rect
		)


func _draw_clipped_screen_texture_region(
	canvas: CanvasItem,
	texture: Texture2D,
	target_rect: Rect2,
	source_rect: Rect2,
	clip_rect: Rect2
) -> void:
	if target_rect.size.x <= 0.0 or target_rect.size.y <= 0.0:
		return
	var visible_target := target_rect.intersection(clip_rect)
	if visible_target.size.x <= 0.0 or visible_target.size.y <= 0.0:
		return
	var relative_position := (visible_target.position - target_rect.position) / target_rect.size
	var relative_size := visible_target.size / target_rect.size
	var visible_source := Rect2(
		source_rect.position + source_rect.size * relative_position,
		source_rect.size * relative_size
	)
	canvas.draw_texture_rect_region(
		texture,
		visible_target,
		visible_source,
		Color.WHITE,
		false,
		true
	)


func _find_node_position(nodes: Array, node_id: String) -> Vector2:
	for node_variant in nodes:
		var node: Dictionary = node_variant
		if str(node.get("id", "")) == node_id:
			return _vector2(node.get("position", Vector2.ZERO))
	return Vector2.ZERO


func _draw_map_node(
	canvas: CanvasItem,
	node: Dictionary,
	active_candidate_ids: Array,
	current_node_id: String,
	selected_target_id: String,
	map_overlay: bool = false
) -> void:
	var position := _vector2(node.get("position", Vector2.ZERO))
	var node_id := str(node.get("id", ""))
	var completed := bool(node.get("completed", false))
	var active := active_candidate_ids.has(node_id)
	var current := node_id == current_node_id
	var selected := node_id == selected_target_id and not selected_target_id.is_empty()
	var skipped := bool(node.get("skipped", false))
	var route_locked := bool(node.get("route_locked", false))
	var enraged := bool(node.get("enraged", false))
	var radius := (
		TowerAscentTuning.TEMP_MAP_OVERLAY_NODE_RADIUS
		if map_overlay
		else ACTIVE_NODE_RADIUS if active or current or selected else MAP_NODE_RADIUS
	)
	var fill := GOLD if completed or current else PAPER_DEEP
	if route_locked or skipped:
		fill = SEALED
	elif enraged:
		fill = CINNABAR_DARK
	elif active:
		fill = Color("e6c15c")
	if selected:
		fill = CINNABAR
	canvas.draw_circle(position, radius, fill)
	canvas.draw_circle(position, radius, CINNABAR_DARK if active or selected else INK, false, 2.0 if active or current or selected else 1.0)
	var icon_presentation := build_map_icon_presentation(node)
	var icon_texture_value: Variant = icon_presentation.get("icon_texture", null)
	if icon_texture_value is Texture2D:
		var icon_size := Vector2.ONE * radius * 1.55
		canvas.draw_texture_rect(
			icon_texture_value as Texture2D,
			Rect2(position - icon_size * 0.5, icon_size),
			false,
			_map_icon_modulate(route_locked, skipped, completed, current)
		)
	if map_overlay and current:
		canvas.draw_circle(
			position,
			TowerAscentTuning.TEMP_MAP_OVERLAY_CURRENT_RING_RADIUS,
			CINNABAR,
			false,
			3.0
		)
	if enraged:
		canvas.draw_circle(position, radius + 3.0, CINNABAR, false, 1.5)
	if skipped:
		canvas.draw_line(position + Vector2(-5.0, -5.0), position + Vector2(5.0, 5.0), PAPER, 1.5)
		canvas.draw_line(position + Vector2(5.0, -5.0), position + Vector2(-5.0, 5.0), PAPER, 1.5)
	var label := str(icon_presentation.get("fallback_label", ""))
	var text_color := PAPER if selected else INK
	if map_overlay:
		if not label.is_empty():
			canvas.draw_string(
				ThemeDB.fallback_font,
				position + Vector2(
					TowerAscentTuning.TEMP_MAP_OVERLAY_NODE_LABEL_OFFSET_X,
					3.0
				),
				label,
				HORIZONTAL_ALIGNMENT_LEFT,
				TowerAscentTuning.TEMP_MAP_OVERLAY_NODE_LABEL_WIDTH,
				TowerAscentTuning.TEMP_MAP_OVERLAY_NODE_LABEL_FONT_SIZE,
				INK
			)
		var state_label := TowerAscentMapOverlayLocalization.node_state_label(
			current,
			completed,
			skipped,
			route_locked
		)
		if not state_label.is_empty():
			canvas.draw_string(
				ThemeDB.fallback_font,
				position + Vector2(
					-TowerAscentTuning.TEMP_MAP_OVERLAY_STATE_LABEL_WIDTH - 11.0,
					3.0
				),
				state_label,
				HORIZONTAL_ALIGNMENT_RIGHT,
				TowerAscentTuning.TEMP_MAP_OVERLAY_STATE_LABEL_WIDTH,
				TowerAscentTuning.TEMP_MAP_OVERLAY_NODE_LABEL_FONT_SIZE,
				CINNABAR_DARK if current else INK_SOFT
			)
	elif (active or selected) and not label.is_empty():
		canvas.draw_string(
			ThemeDB.fallback_font,
			position + Vector2(-70.0, -17.0),
			label,
			HORIZONTAL_ALIGNMENT_CENTER,
			140.0,
			12,
			text_color
		)


func _map_icon_modulate(
	route_locked: bool,
	skipped: bool,
	completed: bool,
	current: bool
) -> Color:
	if route_locked or skipped:
		return Color(0.45, 0.42, 0.38, 0.72)
	if completed and not current:
		return Color(0.72, 0.66, 0.54, 0.82)
	return Color.WHITE


func _draw_map_overlay_legend(canvas: CanvasItem) -> void:
	var panel := Rect2(
		66.0,
		TowerAscentTuning.TEMP_MAP_OVERLAY_LEGEND_Y,
		628.0,
		50.0
	)
	canvas.draw_rect(panel, Color(PAPER_DEEP, 0.82), true)
	canvas.draw_rect(panel, GOLD, false, 1.5)
	canvas.draw_string(
		ThemeDB.fallback_font,
		panel.position + Vector2(12.0, 19.0),
		TowerAscentMapOverlayLocalization.text(
			TowerAscentMapOverlayLocalization.KEY_LEGEND_TYPES
		),
		HORIZONTAL_ALIGNMENT_CENTER,
		panel.size.x - 24.0,
		11,
		INK
	)
	canvas.draw_string(
		ThemeDB.fallback_font,
		panel.position + Vector2(12.0, 39.0),
		TowerAscentMapOverlayLocalization.text(
			TowerAscentMapOverlayLocalization.KEY_LEGEND_STATES
		),
		HORIZONTAL_ALIGNMENT_CENTER,
		panel.size.x - 24.0,
		11,
		INK_SOFT
	)


func build_node_modal_backdrop_model(
	node_kind: String,
	viewport_rect: Rect2
) -> Dictionary:
	var kind := node_kind.strip_edges().to_lower()
	var palettes := {
		"shop": [Color("100f1d"), Color("2b1937"), Color("d99532")],
		"training": [Color("20150f"), Color("503125"), Color("d49b48")],
		"fallen_monk": [Color("11151b"), Color("2c3035"), Color("9e352d")],
		"guardian_spring": [Color("071c24"), Color("164c55"), Color("65c7ba")],
		"rest": [Color("08101f"), Color("192544"), Color("e5a94f")],
		"common_shell": [Color("17120f"), Color("3b2d24"), GOLD],
	}
	if not palettes.has(kind):
		kind = "common_shell"
	var palette: Array = palettes[kind]
	return {
		"kind": kind,
		"rect": viewport_rect,
		"top_color": palette[0],
		"bottom_color": palette[1],
		"accent": palette[2],
	}


func _draw_node_modal_backdrop(
	canvas: CanvasItem,
	viewport_rect: Rect2,
	node_kind: String
) -> void:
	var model := build_node_modal_backdrop_model(node_kind, viewport_rect)
	var kind := str(model.get("kind", "common_shell"))
	var accent: Color = model.get("accent", GOLD)
	if kind == "shop" and viewport_rect.position == Vector2.ZERO:
		var room_scale := minf(
			viewport_rect.size.x / 1000.0,
			viewport_rect.size.y / 720.0
		)
		PlazaInteriorRoomRenderer.draw_room(
			canvas,
			ThemeDB.fallback_font,
			viewport_rect.size,
			maxf(0.1, room_scale),
			0.0,
			"shop",
			accent,
			null
		)
		return
	_draw_node_modal_gradient(canvas, model)
	match kind:
		"training":
			_draw_training_backdrop(canvas, viewport_rect, accent)
		"fallen_monk":
			_draw_fallen_monk_backdrop(canvas, viewport_rect, accent)
		"guardian_spring":
			_draw_guardian_spring_backdrop(canvas, viewport_rect, accent)
		"rest":
			_draw_rest_backdrop(canvas, viewport_rect, accent)
		_:
			_draw_common_node_backdrop(canvas, viewport_rect, accent)


func _draw_node_modal_gradient(canvas: CanvasItem, model: Dictionary) -> void:
	var rect: Rect2 = model.get("rect", Rect2())
	var top_color: Color = model.get("top_color", Color.BLACK)
	var bottom_color: Color = model.get("bottom_color", Color.BLACK)
	for band_index in range(18):
		var progress := float(band_index) / 17.0
		var band_rect := Rect2(
			rect.position + Vector2(0.0, rect.size.y * progress),
			Vector2(rect.size.x, rect.size.y / 17.0 + 2.0)
		)
		canvas.draw_rect(band_rect, top_color.lerp(bottom_color, progress), true)


func _draw_training_backdrop(canvas: CanvasItem, rect: Rect2, accent: Color) -> void:
	var horizon_y := rect.position.y + rect.size.y * 0.55
	canvas.draw_circle(
		rect.position + Vector2(rect.size.x * 0.78, rect.size.y * 0.22),
		rect.size.y * 0.095,
		Color(accent, 0.24)
	)
	canvas.draw_rect(
		Rect2(Vector2(rect.position.x, horizon_y), Vector2(rect.size.x, rect.end.y - horizon_y)),
		Color("2b1d17"),
		true
	)
	for index in range(11):
		var y := lerpf(horizon_y, rect.end.y, float(index) / 10.0)
		canvas.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(accent, 0.12), 2.0)
	for side_value in [-1.0, 1.0]:
		var side: float = float(side_value)
		var x: float = rect.get_center().x + side * rect.size.x * 0.34
		canvas.draw_rect(Rect2(Vector2(x - 16.0, rect.position.y), Vector2(32.0, rect.size.y)), Color("3b2018"), true)
		canvas.draw_rect(Rect2(Vector2(x - 22.0, rect.position.y + rect.size.y * 0.16), Vector2(44.0, 16.0)), accent, true)


func _draw_fallen_monk_backdrop(canvas: CanvasItem, rect: Rect2, accent: Color) -> void:
	canvas.draw_circle(
		rect.position + Vector2(rect.size.x * 0.23, rect.size.y * 0.22),
		rect.size.y * 0.09,
		Color("b8b2a4")
	)
	for index in range(6):
		var x := rect.position.x + rect.size.x * (0.12 + float(index) * 0.15)
		var height := rect.size.y * (0.28 + float(index % 3) * 0.07)
		var ruin := Rect2(Vector2(x, rect.end.y - height), Vector2(rect.size.x * 0.065, height))
		canvas.draw_rect(ruin, Color("25282b"), true)
		canvas.draw_rect(ruin, Color(accent, 0.28), false, 2.0)
	for index in range(9):
		var rubble_center := rect.position + Vector2(
			rect.size.x * (0.08 + float(index) * 0.105),
			rect.size.y * (0.82 + float(index % 2) * 0.05)
		)
		canvas.draw_circle(rubble_center, rect.size.y * 0.018, Color("343539"))


func _draw_guardian_spring_backdrop(canvas: CanvasItem, rect: Rect2, accent: Color) -> void:
	var water_rect := Rect2(
		rect.position + Vector2(0.0, rect.size.y * 0.48),
		Vector2(rect.size.x, rect.size.y * 0.52)
	)
	canvas.draw_rect(water_rect, Color("0b3540"), true)
	var spring_center := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.67)
	for index in range(8, 0, -1):
		canvas.draw_arc(
			spring_center,
			rect.size.y * (0.035 + float(index) * 0.035),
			0.0,
			TAU,
			64,
			Color(accent, 0.05 + float(8 - index) * 0.018),
			2.0
		)
	for index in range(7):
		var y := rect.position.y + rect.size.y * (0.20 + float(index) * 0.055)
		canvas.draw_arc(Vector2(rect.get_center().x, y), rect.size.x * 0.22, PI, TAU, 36, Color(0.82, 0.95, 0.91, 0.08), 7.0)


func _draw_rest_backdrop(canvas: CanvasItem, rect: Rect2, accent: Color) -> void:
	for index in range(36):
		var point := rect.position + Vector2(
			fposmod(float(index * 137), rect.size.x),
			fposmod(float(index * 71), rect.size.y * 0.56)
		)
		canvas.draw_circle(point, 1.5 + float(index % 3), Color(0.92, 0.88, 0.72, 0.34))
	var hill_points := PackedVector2Array([
		Vector2(rect.position.x, rect.end.y),
		rect.position + Vector2(0.0, rect.size.y * 0.70),
		rect.position + Vector2(rect.size.x * 0.28, rect.size.y * 0.58),
		rect.position + Vector2(rect.size.x * 0.52, rect.size.y * 0.74),
		rect.position + Vector2(rect.size.x * 0.76, rect.size.y * 0.61),
		Vector2(rect.end.x, rect.position.y + rect.size.y * 0.72),
		rect.end,
	])
	canvas.draw_colored_polygon(hill_points, Color("111a24"))
	var fire_center := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.77)
	canvas.draw_circle(fire_center, rect.size.y * 0.09, Color(accent, 0.08))
	canvas.draw_circle(fire_center, rect.size.y * 0.035, Color(accent, 0.92))
	canvas.draw_circle(fire_center - Vector2(0.0, rect.size.y * 0.02), rect.size.y * 0.016, Color("fff1a6"))


func _draw_common_node_backdrop(canvas: CanvasItem, rect: Rect2, accent: Color) -> void:
	for index in range(9):
		var inset := rect.size.y * (0.04 + float(index) * 0.035)
		canvas.draw_rect(rect.grow(-inset), Color(accent, 0.08), false, 2.0)


func _screen_point(point: Vector2, scale_value: float, offset: Vector2) -> Vector2:
	return offset + point * scale_value


func _screen_rect(rect: Rect2, scale_value: float, offset: Vector2) -> Rect2:
	return Rect2(_screen_point(rect.position, scale_value, offset), rect.size * scale_value)


func _camera_world_to_screen(camera_model: Dictionary, point: Vector2) -> Vector2:
	return _screen_point(
		point,
		_camera_render_zoom(camera_model),
		_vector2(camera_model.get("offset", Vector2.ZERO))
	)


func _camera_world_rect_to_screen(camera_model: Dictionary, rect: Rect2) -> Rect2:
	return _screen_rect(
		rect,
		_camera_render_zoom(camera_model),
		_vector2(camera_model.get("offset", Vector2.ZERO))
	)


func _camera_render_zoom(camera_model: Dictionary) -> float:
	return maxf(
		0.001,
		float(camera_model.get(
			"render_zoom_multiplier",
			camera_model.get("zoom_multiplier", 1.0)
		))
	)
func _draw_node_modal(
	canvas: CanvasItem,
	model_value: Variant,
	render_context: Dictionary = {}
) -> void:
	# The transformed playfield dispatcher still reaches this method so its
	# phase return remains explicit, but only the fullscreen pass supplies the
	# screen-layout model and is allowed to render it.
	if not (model_value is Dictionary):
		return
	var model := model_value as Dictionary
	var embedded_render_context: Variant = model.get("render_context", {})
	if render_context.is_empty() and embedded_render_context is Dictionary:
		render_context = embedded_render_context as Dictionary
	var content_scale := maxf(0.001, float(model.get("content_scale", 1.0)))
	var content_offset: Vector2 = model.get("content_offset", Vector2.ZERO)
	var modal_rect: Rect2 = model.get("modal_rect", MODAL_RECT)
	canvas.draw_rect(modal_rect, Color("f7e9c8"), true)
	canvas.draw_rect(modal_rect, CINNABAR_DARK, false, 5.0 * content_scale)
	canvas.draw_rect(modal_rect.grow(-13.0 * content_scale), GOLD, false, 2.0 * content_scale)
	var font := ThemeDB.fallback_font
	canvas.draw_string(
		font,
		_screen_point(Vector2(126.0, 64.0), content_scale, content_offset),
		str(model.get("title", "행로 정비")),
		HORIZONTAL_ALIGNMENT_CENTER,
		508.0 * content_scale,
		maxi(12, int(round(30.0 * content_scale))),
		INK
	)
	canvas.draw_line(
		_screen_point(Vector2(126.0, 78.0), content_scale, content_offset),
		_screen_point(Vector2(634.0, 78.0), content_scale, content_offset),
		GOLD,
		2.0 * content_scale
	)
	canvas.draw_string(
		font,
		_screen_point(Vector2(126.0, 100.0), content_scale, content_offset),
		str(model.get("description", "")),
		HORIZONTAL_ALIGNMENT_CENTER,
		508.0 * content_scale,
		maxi(10, int(round(16.0 * content_scale))),
		INK_SOFT
	)
	var balance_layout := build_balance_row_layout(content_scale, content_offset)
	var balance_entries: Array = balance_layout.get("entries", [])
	if balance_entries.size() == 2:
		_draw_balance_entry(
			canvas,
			balance_entries[0] as Dictionary,
			str(model.get("muhon_text", "")),
			content_scale
		)
		_draw_balance_entry(
			canvas,
			balance_entries[1] as Dictionary,
			str(model.get("gold_text", "")),
			content_scale
		)
	var layout_flags_value: Variant = model.get("layout_flags", {})
	var layout_flags: Dictionary = (
		layout_flags_value as Dictionary
		if layout_flags_value is Dictionary
		else {}
	)
	if bool(layout_flags.get(LAYOUT_FLAG_TRAINING_STAGE, false)):
		_draw_training_stage_layout(canvas, model, content_scale, render_context)
	var actions: Array = model.get("actions", [])
	var action_rects: Array = model.get("action_rects", [])
	var interaction_visuals: Array = model.get("interaction_visuals", [])
	var has_pointer_visuals := bool(model.get("has_pointer_visuals", false))
	var selected_index := int(model.get("selected_index", 0))
	var training_card_ordinal := 0
	var node_accent := GOLD
	if has_pointer_visuals:
		node_accent = build_node_modal_backdrop_model(
			str(model.get("node_kind", "common_shell")),
			Rect2(Vector2.ZERO, model.get("view_size", Vector2(760.0, 750.0)))
		).get("accent", GOLD)
	for index in range(actions.size()):
		if not (actions[index] is Dictionary):
			continue
		var row_rect := (
			action_rects[index] as Rect2
			if index < action_rects.size() and action_rects[index] is Rect2
			else _screen_rect(
				Rect2(126.0, 301.0 + float(index) * 43.0, 508.0, 38.0),
				content_scale,
				content_offset
			)
		)
		var action := actions[index] as Dictionary
		if (
			bool(layout_flags.get(LAYOUT_FLAG_TRAINING_STAGE, false))
			and str(action.get("id", "")) != "end_work"
		):
			training_card_ordinal += 1
			_draw_training_card_ordinal(
				canvas,
				row_rect,
				training_card_ordinal,
				content_scale
			)
		var card_renderer: Object = render_context.get("card_renderer", null)
		var icon_renderer: Object = render_context.get("icon_renderer", null)
		var draws_card := (
			str(model.get("node_kind", "")) in [
				"shop",
				"training",
				"fallen_monk",
				"guardian_spring",
				"rest",
			]
			and str(action.get("id", "")) != "end_work"
			and card_renderer != null
			and card_renderer.has_method("draw_tower_node_card")
		)
		if draws_card:
			if has_pointer_visuals:
				var visual_state: Dictionary = (
					interaction_visuals[index] as Dictionary
					if index < interaction_visuals.size()
					and interaction_visuals[index] is Dictionary
					else {}
				)
				visual_state["node_accent"] = node_accent
				card_renderer.call(
					"draw_tower_node_card",
					canvas,
					action,
					row_rect,
					index == selected_index,
					icon_renderer,
					index,
					render_context.get("active_item_hud_visuals", null),
					visual_state,
					render_context.get("hover_detail_context", {})
				)
			else:
				card_renderer.call(
					"draw_tower_node_card",
					canvas,
					action,
					row_rect,
					index == selected_index,
					icon_renderer,
					index,
					render_context.get("active_item_hud_visuals", null)
				)
		else:
			if not row_rect.has_area():
				continue
			_draw_modal_action_row(
				canvas,
				row_rect,
				action,
				index == selected_index,
				content_scale
			)
	if bool(layout_flags.get(LAYOUT_FLAG_TRAINING_STAGE, false)):
		_draw_training_stats_panel(canvas, model, render_context)
	if bool(layout_flags.get(LAYOUT_FLAG_PAGE_CONTROLS, false)):
		_draw_node_modal_page_controls(canvas, model, node_accent, content_scale)
	var status_baseline: Vector2 = model.get(
		"status_baseline",
		_screen_point(Vector2(126.0, 680.0), content_scale, content_offset)
	)
	canvas.draw_string(
		font,
		status_baseline,
		str(model.get("status_text", "")),
		HORIZONTAL_ALIGNMENT_CENTER,
		508.0 * content_scale,
		maxi(10, int(round(14.0 * content_scale))),
		INK_SOFT
	)


func _draw_node_modal_page_controls(
	canvas: CanvasItem,
	model: Dictionary,
	node_accent: Color,
	content_scale: float
) -> void:
	var page_count := maxi(1, int(model.get("page_count", 1)))
	if page_count <= 1:
		return
	var visible_page := clampi(int(model.get("visible_page", 0)), 0, page_count - 1)
	var hovered_direction := int(model.get("hovered_page_direction", 0))
	var pressed_direction := int(model.get("pressed_page_direction", 0))
	var font := ThemeDB.fallback_font
	for spec in [
		{
			"direction": -1,
			"rect": model.get("page_previous_rect", Rect2()),
			"label": "‹",
			"enabled": visible_page > 0,
		},
		{
			"direction": 1,
			"rect": model.get("page_next_rect", Rect2()),
			"label": "›",
			"enabled": visible_page < page_count - 1,
		},
	]:
		var rect: Rect2 = spec.get("rect", Rect2())
		if not rect.has_area():
			continue
		var direction := int(spec.get("direction", 0))
		var enabled := bool(spec.get("enabled", false))
		var hovered := direction == hovered_direction
		var pressed := direction == pressed_direction
		var fill := Color(0.95, 0.88, 0.70, 0.94) if enabled else Color(0.55, 0.50, 0.43, 0.32)
		if hovered and enabled:
			fill = fill.lerp(Color(node_accent, 0.90), 0.28)
		if pressed and enabled:
			fill = fill.darkened(0.12)
		canvas.draw_rect(rect, fill, true)
		canvas.draw_rect(
			rect,
			Color(node_accent, 0.94 if hovered or pressed else 0.68) if enabled else Color(0.30, 0.27, 0.24, 0.32),
			false,
			maxf(1.0, (2.4 if hovered or pressed else 1.5) * content_scale)
		)
		canvas.draw_string(
			font,
			rect.position + Vector2(0.0, rect.size.y * 0.73),
			str(spec.get("label", "")),
			HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x,
			maxi(12, int(round(24.0 * content_scale))),
			INK if enabled else INK_SOFT
		)
	var label_rect: Rect2 = model.get("page_label_rect", Rect2())
	if label_rect.has_area():
		canvas.draw_string(
			font,
			label_rect.position + Vector2(0.0, label_rect.size.y * 0.70),
			"%d / %d" % [visible_page + 1, page_count],
			HORIZONTAL_ALIGNMENT_CENTER,
			label_rect.size.x,
			maxi(10, int(round(14.0 * content_scale))),
			INK_SOFT
		)
func _draw_training_stage_layout(
	canvas: CanvasItem,
	model: Dictionary,
	content_scale: float,
	render_context: Dictionary = {}
) -> void:
	var stage_rect: Rect2 = model.get("training_stage_rect", Rect2())
	if not stage_rect.has_area():
		return
	var presentation: Object = render_context.get("training_stage_presentation", null)
	var visual_model: Dictionary = (
		presentation.get_visual_model()
		if presentation != null and presentation.has_method("get_visual_model")
		else {}
	)
	var timing_presentation: Object = render_context.get(
		"training_timing_presentation",
		null
	)
	var timing_model: Dictionary = (
		timing_presentation.get_visual_model()
		if timing_presentation != null
		and timing_presentation.has_method("get_visual_model")
		else {}
	)
	var shake_offset: Vector2 = _vector2(
		visual_model.get("stage_shake_offset", Vector2.ZERO)
	) * content_scale
	var shaken_stage_rect := Rect2(stage_rect.position + shake_offset, stage_rect.size)
	# S3 remains inside the existing fullscreen renderer. There is no Node host,
	# so GRT-039 cannot acquire a (0,0) spawn transform or physics interpolation;
	# only the training-stage coordinates below receive the bounded shake offset.
	canvas.draw_rect(shaken_stage_rect, Color(0.12, 0.075, 0.052, 0.94), true)
	for band_index in range(4):
		var band_progress := float(band_index) / 3.0
		var band_rect := Rect2(
			shaken_stage_rect.position + Vector2(
				0.0,
				shaken_stage_rect.size.y * band_progress * 0.58
			),
			Vector2(shaken_stage_rect.size.x, shaken_stage_rect.size.y * 0.20 + 1.0)
		)
		canvas.draw_rect(
			band_rect,
			Color(0.36, 0.22, 0.13, 0.055 + band_progress * 0.025),
			true
		)
	var floor_rect := Rect2(
		shaken_stage_rect.position + Vector2(0.0, shaken_stage_rect.size.y * 0.61),
		Vector2(shaken_stage_rect.size.x, shaken_stage_rect.size.y * 0.39)
	)
	canvas.draw_rect(floor_rect, Color(0.23, 0.13, 0.075, 0.90), true)
	var player_slot: Rect2 = model.get("training_player_slot_rect", Rect2())
	player_slot.position += shake_offset
	var dummy_slot: Rect2 = model.get("training_dummy_slot_rect", Rect2())
	dummy_slot.position += shake_offset
	_draw_training_slot_shadow(
		canvas,
		player_slot,
		shaken_stage_rect,
		content_scale
	)
	_draw_training_slot_shadow(
		canvas,
		dummy_slot,
		shaken_stage_rect,
		content_scale
	)
	if bool(visual_model.get("aura_active", false)):
		_draw_training_judgment_aura(
			canvas,
			player_slot,
			content_scale,
			str(visual_model.get("judgment_kind", "base")),
			float(visual_model.get("aura_progress", 0.0))
		)
	_draw_training_character(
		canvas,
		player_slot,
		shaken_stage_rect,
		content_scale,
		visual_model
	)
	var dummy_pivot := _draw_training_dummy(
		canvas,
		dummy_slot,
		shaken_stage_rect,
		content_scale,
		float(visual_model.get("dummy_rotation_radians", 0.0))
	)
	if bool(visual_model.get("impact_active", false)):
		_draw_training_impact_effect(
			canvas,
			dummy_pivot,
			content_scale,
			float(visual_model.get("impact_progress", 0.0)),
			float(visual_model.get("dummy_rotation_radians", 0.0)),
			visual_model.get("impact_directions", []),
			visual_model.get("impact_point_offsets", [])
		)
	if bool(visual_model.get("message_active", false)):
		_draw_training_judgment_message(
			canvas,
			stage_rect,
			content_scale,
			str(visual_model.get("message_text", "")),
			str(visual_model.get("judgment_kind", "base")),
			float(visual_model.get("message_progress", 0.0))
		)
	if bool(timing_model.get("visible", false)):
		_draw_training_timing_gauge(
			canvas,
			stage_rect,
			content_scale,
			timing_model
		)


func _draw_training_timing_gauge(
	canvas: CanvasItem,
	stage_rect: Rect2,
	content_scale: float,
	model: Dictionary
) -> void:
	var gauge_rect := Rect2(
		stage_rect.position + Vector2(24.0, 11.0) * content_scale,
		Vector2(stage_rect.size.x - 48.0 * content_scale, 29.0 * content_scale)
	)
	if not gauge_rect.has_area():
		return
	var track_rect := gauge_rect.grow(-5.0 * content_scale)
	canvas.draw_rect(gauge_rect.grow(3.0 * content_scale), Color(0.03, 0.018, 0.012, 0.34), true)
	canvas.draw_rect(gauge_rect, Color(0.16, 0.095, 0.045, 0.98), true)
	canvas.draw_rect(track_rect, Color(0.055, 0.045, 0.038, 0.98), true)
	# GRT-018 guard: consume the state's precomputed zone boundaries so the
	# drawn cells can never drift from the judgment math; the fallbacks mirror
	# the policy factors (great bands are GREAT_CELL_MULTIPLIER x the cell).
	var target_position := clampf(float(model.get("target_position", 0.5)), 0.0, 1.0)
	var cell_width := clampf(float(model.get("cell_width_ratio", 0.02)), 0.005, 0.08)
	var critical_start := clampf(
		float(model.get("critical_start", target_position - cell_width * 0.5)), 0.0, 1.0
	)
	var critical_end := clampf(
		float(model.get("critical_end", target_position + cell_width * 0.5)), 0.0, 1.0
	)
	var great_left_start := clampf(
		float(model.get("great_left_start", target_position - cell_width * 2.5)), 0.0, 1.0
	)
	var great_right_end := clampf(
		float(model.get("great_right_end", target_position + cell_width * 2.5)), 0.0, 1.0
	)
	var critical_rect := _training_timing_segment_rect(
		track_rect,
		critical_start,
		critical_end
	)
	var great_left_rect := _training_timing_segment_rect(
		track_rect,
		great_left_start,
		critical_start
	)
	var great_right_rect := _training_timing_segment_rect(
		track_rect,
		critical_end,
		great_right_end
	)
	for great_rect in [great_left_rect, great_right_rect]:
		canvas.draw_rect(great_rect, Color(0.13, 0.34, 0.54, 0.72), true)
		canvas.draw_rect(great_rect.grow(-1.0 * content_scale), Color(0.30, 0.58, 0.76, 0.18), true)
	var pulse := clampf(float(model.get("pulse_strength", 0.0)), 0.0, 1.0)
	canvas.draw_rect(
		critical_rect.grow((4.0 + 5.0 * pulse) * content_scale),
		Color(0.92, 0.08, 0.045, 0.055 + pulse * 0.045),
		true
	)
	canvas.draw_rect(critical_rect, Color(0.68, 0.045, 0.028, 0.94), true)
	canvas.draw_rect(
		critical_rect.grow(-2.0 * content_scale),
		Color(1.0, 0.20, 0.08, 0.18 + pulse * 0.12),
		true
	)
	# The jackpot cell is a UI contract, so its requested gold border is explicit;
	# aura and impact VFX remain fill-and-broad-stroke only.
	canvas.draw_rect(
		critical_rect,
		Color(0.95, 0.72, 0.24, 0.96),
		false,
		2.0 * content_scale
	)
	for boundary_ratio in [
		great_left_start,
		critical_start,
		critical_end,
		great_right_end,
	]:
		var boundary_x := track_rect.position.x + track_rect.size.x * float(boundary_ratio)
		canvas.draw_line(
			Vector2(boundary_x, track_rect.position.y),
			Vector2(boundary_x, track_rect.end.y),
			Color(0.95, 0.77, 0.38, 0.34),
			1.0 * content_scale
		)
	var pendulum_position := clampf(float(model.get("pendulum_position", 0.0)), 0.0, 1.0)
	var marker_x := track_rect.position.x + track_rect.size.x * pendulum_position
	var marker_color := Color(0.98, 0.91, 0.70, 1.0)
	match str(model.get("judgment_kind", "")):
		"critical":
			marker_color = Color(1.0, 0.35, 0.16, 1.0)
		"great":
			marker_color = Color(0.38, 0.78, 1.0, 1.0)
	canvas.draw_line(
		Vector2(marker_x, track_rect.position.y - 3.0 * content_scale),
		Vector2(marker_x, track_rect.end.y + 3.0 * content_scale),
		Color(marker_color, 0.22),
		9.0 * content_scale
	)
	canvas.draw_line(
		Vector2(marker_x, track_rect.position.y - 4.0 * content_scale),
		Vector2(marker_x, track_rect.end.y + 4.0 * content_scale),
		marker_color,
		3.0 * content_scale
	)
	canvas.draw_circle(
		Vector2(marker_x, gauge_rect.get_center().y),
		4.5 * content_scale,
		marker_color
	)


func _training_timing_segment_rect(
	track_rect: Rect2,
	start_ratio: float,
	end_ratio: float
) -> Rect2:
	var clamped_start := clampf(start_ratio, 0.0, 1.0)
	var clamped_end := clampf(end_ratio, clamped_start, 1.0)
	return Rect2(
		Vector2(
			track_rect.position.x + track_rect.size.x * clamped_start,
			track_rect.position.y
		),
		Vector2(track_rect.size.x * (clamped_end - clamped_start), track_rect.size.y)
	)


func _draw_training_judgment_aura(
	canvas: CanvasItem,
	player_slot: Rect2,
	content_scale: float,
	judgment_kind: String,
	progress: float
) -> void:
	var t := clampf(progress, 0.0, 1.0)
	var center := player_slot.get_center() + Vector2(8.0, 10.0) * content_scale
	var aura_color := (
		Color(0.96, 0.11, 0.055)
		if judgment_kind == "critical"
		else Color(0.12, 0.52, 0.95)
	)
	var bloom_radius := (20.0 + 58.0 * sin(t * PI)) * content_scale
	canvas.draw_circle(center, bloom_radius * 1.28, Color(aura_color, 0.035))
	canvas.draw_circle(center, bloom_radius * 0.86, Color(aura_color, 0.085))
	canvas.draw_circle(
		center + Vector2(-8.0, -10.0) * content_scale,
		bloom_radius * 0.44,
		Color(1.0, 0.78, 0.46, 0.10) if judgment_kind == "critical" else Color(0.56, 0.86, 1.0, 0.10)
	)
	for direction in [
		Vector2(-0.96, -0.26),
		Vector2(-0.62, -0.78),
		Vector2(0.15, -0.98),
		Vector2(0.82, -0.52),
		Vector2(0.94, 0.22),
	]:
		var ray_direction: Vector2 = direction
		var inner := center + ray_direction * (12.0 + 9.0 * t) * content_scale
		var outer := center + ray_direction * (42.0 + 38.0 * t) * content_scale
		canvas.draw_line(inner, outer, Color(aura_color, 0.02), 24.0 * content_scale)
		canvas.draw_line(inner, outer, Color(aura_color, 0.16 * (1.0 - t)), 7.0 * content_scale)
	for point_spec in [
		Vector2(-31.0, -21.0),
		Vector2(24.0, -34.0),
		Vector2(39.0, 12.0),
	]:
		var drift: Vector2 = point_spec
		canvas.draw_circle(
			center + drift * content_scale * (0.72 + t * 0.45),
			(3.0 - 1.2 * t) * content_scale,
			Color(aura_color.lightened(0.45), 0.78 * (1.0 - t))
		)


func _draw_training_judgment_message(
	canvas: CanvasItem,
	stage_rect: Rect2,
	content_scale: float,
	message_text: String,
	judgment_kind: String,
	progress: float
) -> void:
	if message_text.is_empty():
		return
	var t := clampf(progress, 0.0, 1.0)
	# 피드백2 3항: the old bottom-band baseline sat straight on the dummy trunk
	# (orange copy on ochre wood). Float the copy in the upper stage clear of
	# the gauge band, and guarantee contrast with an ink outline.
	var rise := 12.0 * t * content_scale
	var baseline := Vector2(
		stage_rect.position.x,
		stage_rect.position.y + 80.0 * content_scale - rise
	)
	var color := Color(0.94, 0.84, 0.62, 1.0)
	if judgment_kind == "critical":
		color = Color(1.0, 0.38, 0.18, 1.0)
	elif judgment_kind == "great":
		color = Color(0.38, 0.78, 1.0, 1.0)
	var alpha := minf(1.0, t * 8.0) * (1.0 - pow(maxf(0.0, t - 0.85) / 0.15, 2.0))
	var font_size := maxi(
		12,
		int(round((22.0 if judgment_kind == "critical" else 20.0) * content_scale))
	)
	canvas.draw_string(
		ThemeDB.fallback_font,
		baseline + Vector2(1.5, 2.0) * content_scale,
		message_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		stage_rect.size.x,
		font_size,
		Color(0.02, 0.012, 0.008, 0.72 * alpha)
	)
	canvas.draw_string_outline(
		ThemeDB.fallback_font,
		baseline,
		message_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		stage_rect.size.x,
		font_size,
		maxi(3, int(round(6.0 * content_scale))),
		Color(0.05, 0.028, 0.018, 0.92 * alpha)
	)
	canvas.draw_string(
		ThemeDB.fallback_font,
		baseline,
		message_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		stage_rect.size.x,
		font_size,
		Color(color, alpha)
	)


func _draw_training_card_ordinal(
	canvas: CanvasItem,
	card_rect: Rect2,
	ordinal: int,
	content_scale: float
) -> void:
	if not card_rect.has_area() or ordinal <= 0:
		return
	var center := Vector2(
		card_rect.position.x - 6.0 * content_scale,
		card_rect.get_center().y
	)
	var radius := 10.0 * content_scale
	var shadow_center := center + Vector2(1.5, 2.0) * content_scale
	var shadow_points := PackedVector2Array([
		shadow_center + Vector2(0.0, -radius),
		shadow_center + Vector2(radius, 0.0),
		shadow_center + Vector2(0.0, radius),
		shadow_center + Vector2(-radius, 0.0),
	])
	canvas.draw_colored_polygon(shadow_points, Color(0.02, 0.015, 0.01, 0.34))
	var wood_points := PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(-radius, 0.0),
	])
	canvas.draw_colored_polygon(wood_points, Color(0.20, 0.105, 0.048, 0.98))
	var inset := radius * 0.68
	var brass_points := PackedVector2Array([
		center + Vector2(0.0, -inset),
		center + Vector2(inset, 0.0),
		center + Vector2(0.0, inset),
		center + Vector2(-inset, 0.0),
	])
	canvas.draw_colored_polygon(brass_points, Color(0.62, 0.42, 0.18, 0.78))
	var font := ThemeDB.fallback_font
	canvas.draw_string(
		font,
		center + Vector2(-radius, radius * 0.37),
		str(ordinal),
		HORIZONTAL_ALIGNMENT_CENTER,
		radius * 2.0,
		maxi(8, int(round(10.0 * content_scale))),
		Color(0.97, 0.90, 0.72, 0.98)
	)


func _draw_training_stats_panel(
	canvas: CanvasItem,
	model: Dictionary,
	render_context: Dictionary
) -> void:
	var renderer: Object = render_context.get("card_renderer", null)
	if renderer == null or not renderer.has_method("draw_tower_training_stats_panel"):
		return
	renderer.call(
		"draw_tower_training_stats_panel",
		canvas,
		model.get("training_stats_rect", Rect2()),
		model.get("pointer_position", Vector2(-1.0, -1.0)),
		model.get("view_size", Vector2(760.0, 750.0)),
		render_context.get("icon_renderer", null),
		render_context.get("training_stats_tooltip_overlay", null)
	)


func _draw_training_slot_shadow(
	canvas: CanvasItem,
	slot_rect: Rect2,
	stage_rect: Rect2,
	content_scale: float
) -> void:
	if not slot_rect.has_area():
		return
	var shadow_center := Vector2(
		slot_rect.get_center().x,
		stage_rect.end.y - 15.0 * content_scale
	)
	canvas.draw_line(
		shadow_center - Vector2(48.0 * content_scale, 0.0),
		shadow_center + Vector2(48.0 * content_scale, 0.0),
		Color(0.02, 0.015, 0.012, 0.20),
		22.0 * content_scale
	)
	canvas.draw_line(
		shadow_center - Vector2(34.0 * content_scale, 0.0),
		shadow_center + Vector2(34.0 * content_scale, 0.0),
		Color(0.72, 0.42, 0.18, 0.08),
		7.0 * content_scale
	)


func _draw_training_character(
	canvas: CanvasItem,
	slot_rect: Rect2,
	stage_rect: Rect2,
	content_scale: float,
	visual_model: Dictionary
) -> void:
	if not slot_rect.has_area():
		return
	var draw_size: Vector2 = _vector2(
		visual_model.get("draw_size", Vector2(160.0, 160.0))
	) * content_scale
	var floor_y := stage_rect.end.y - 13.0 * content_scale
	var center_x := (
		slot_rect.get_center().x
		+ float(visual_model.get("character_offset_x", 0.0)) * content_scale
	)
	var destination := Rect2(
		Vector2(center_x - draw_size.x * 0.5, floor_y - draw_size.y),
		draw_size
	)
	var sprite_value: Variant = visual_model.get("sprite", {})
	if sprite_value is Dictionary:
		var sprite := sprite_value as Dictionary
		var texture_value: Variant = sprite.get("texture", null)
		var source_rect: Rect2 = sprite.get("region", Rect2())
		if texture_value is Texture2D and source_rect.has_area():
			canvas.draw_texture_rect_region(
				texture_value as Texture2D,
				destination,
				source_rect,
				Color.WHITE,
				false,
				true
			)
			return
	_draw_training_character_fallback(
		canvas,
		destination,
		str(visual_model.get("character_type", "smasher")),
		str(visual_model.get("weapon_kind", "paddle")),
		bool(visual_model.get("active", false))
	)


func _draw_training_character_fallback(
	canvas: CanvasItem,
	destination: Rect2,
	character_type: String,
	weapon_kind: String,
	strike_active: bool
) -> void:
	# A missing cache entry must remain visible. These are filled silhouettes,
	# never a silent/empty draw, and the weapon mark remains character-specific.
	var scale_value := destination.size.x / 160.0
	var feet := Vector2(destination.get_center().x, destination.end.y - 9.0 * scale_value)
	var body_color := Color(0.18, 0.24, 0.30, 0.96)
	var light_color := Color(0.56, 0.82, 0.92, 0.88)
	match character_type:
		"viper":
			body_color = Color(0.29, 0.11, 0.43, 0.96)
			light_color = Color(0.44, 0.92, 0.94, 0.90)
		"soldier":
			body_color = Color(0.20, 0.31, 0.17, 0.96)
			light_color = Color(0.72, 0.84, 0.40, 0.90)
		"optimus":
			body_color = Color(0.16, 0.35, 0.47, 0.98)
			light_color = Color(0.56, 0.92, 1.0, 0.92)
		"blacksmith":
			body_color = Color(0.42, 0.25, 0.10, 0.98)
			light_color = Color(1.0, 0.66, 0.24, 0.92)
	canvas.draw_line(
		feet,
		feet + Vector2(0.0, -74.0 * scale_value),
		body_color,
		34.0 * scale_value
	)
	canvas.draw_circle(
		feet + Vector2(0.0, -98.0 * scale_value),
		22.0 * scale_value,
		body_color
	)
	canvas.draw_line(
		feet + Vector2(-22.0, -51.0) * scale_value,
		feet + Vector2(25.0, -49.0) * scale_value,
		light_color,
		10.0 * scale_value
	)
	var weapon_origin := feet + Vector2(24.0, -52.0) * scale_value
	var reach := 14.0 if strike_active else 0.0
	match weapon_kind:
		"firearm":
			canvas.draw_line(
				weapon_origin,
				weapon_origin + Vector2(53.0 + reach, -10.0) * scale_value,
				Color(0.12, 0.14, 0.12, 1.0),
				13.0 * scale_value
			)
			canvas.draw_circle(
				weapon_origin + Vector2(55.0 + reach, -10.0) * scale_value,
				5.0 * scale_value,
				light_color
			)
		"hammer":
			canvas.draw_line(
				weapon_origin,
				weapon_origin + Vector2(39.0 + reach, -32.0) * scale_value,
				Color(0.27, 0.16, 0.08, 1.0),
				8.0 * scale_value
			)
			canvas.draw_line(
				weapon_origin + Vector2(29.0 + reach, -39.0) * scale_value,
				weapon_origin + Vector2(49.0 + reach, -23.0) * scale_value,
				light_color,
				18.0 * scale_value
			)
		"arm_blade":
			canvas.draw_line(
				weapon_origin,
				weapon_origin + Vector2(50.0 + reach, -21.0) * scale_value,
				light_color,
				7.0 * scale_value
			)
		"energy_paddle":
			canvas.draw_line(
				weapon_origin,
				weapon_origin + Vector2(52.0 + reach, -4.0) * scale_value,
				Color(0.28, 0.86, 1.0, 0.84),
				18.0 * scale_value
			)
		_:
			canvas.draw_line(
				weapon_origin,
				weapon_origin + Vector2(54.0 + reach, -2.0) * scale_value,
				light_color,
				14.0 * scale_value
			)


func _draw_training_dummy(
	canvas: CanvasItem,
	slot_rect: Rect2,
	stage_rect: Rect2,
	content_scale: float,
	rotation_radians: float
) -> Vector2:
	if not slot_rect.has_area():
		return Vector2.ZERO
	var pivot := resolve_training_dummy_floor_pivot(
		slot_rect,
		stage_rect,
		content_scale
	)
	if _training_dummy_texture != null:
		_draw_training_dummy_bitmap(
			canvas,
			pivot,
			content_scale,
			rotation_radians
		)
	else:
		_draw_training_dummy_placeholder(
			canvas,
			pivot,
			content_scale,
			rotation_radians
		)
	return pivot


static func resolve_training_dummy_floor_pivot(
	slot_rect: Rect2,
	stage_rect: Rect2,
	content_scale: float
) -> Vector2:
	return Vector2(
		slot_rect.get_center().x,
		stage_rect.end.y - TRAINING_DUMMY_FLOOR_OFFSET_PX * content_scale
	)


static func training_dummy_bitmap_local_rect(content_scale: float) -> Rect2:
	return Rect2(
		-TRAINING_DUMMY_TEXTURE_PIVOT * content_scale,
		Vector2(TRAINING_DUMMY_TEXTURE_SIZE) * content_scale
	)


func _draw_training_dummy_bitmap(
	canvas: CanvasItem,
	pivot: Vector2,
	content_scale: float,
	rotation_radians: float
) -> void:
	# Both the approved bitmap and S6's three wobble tiers rotate around the
	# exact floor-contact pivot. Reset the temporary draw transform immediately
	# so the impact, message, cards, and stats retain their existing coordinates.
	canvas.draw_set_transform(pivot, rotation_radians, Vector2.ONE)
	canvas.draw_texture_rect(
		_training_dummy_texture,
		training_dummy_bitmap_local_rect(content_scale),
		false
	)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_training_dummy_placeholder(
	canvas: CanvasItem,
	pivot: Vector2,
	content_scale: float,
	rotation_radians: float
) -> void:
	var wood := Color(0.31, 0.17, 0.075, 1.0)
	var straw := Color(0.78, 0.57, 0.24, 0.98)
	var straw_light := Color(0.96, 0.77, 0.38, 0.90)
	var tie := Color(0.48, 0.12, 0.08, 0.96)
	canvas.draw_line(
		_training_dummy_point(pivot, Vector2(-31.0, -3.0) * content_scale, rotation_radians),
		_training_dummy_point(pivot, Vector2(31.0, -3.0) * content_scale, rotation_radians),
		wood,
		14.0 * content_scale
	)
	canvas.draw_line(
		pivot,
		_training_dummy_point(pivot, Vector2(0.0, -123.0) * content_scale, rotation_radians),
		wood,
		17.0 * content_scale
	)
	canvas.draw_line(
		_training_dummy_point(pivot, Vector2(0.0, -35.0) * content_scale, rotation_radians),
		_training_dummy_point(pivot, Vector2(0.0, -112.0) * content_scale, rotation_radians),
		straw,
		43.0 * content_scale
	)
	canvas.draw_line(
		_training_dummy_point(pivot, Vector2(-52.0, -101.0) * content_scale, rotation_radians),
		_training_dummy_point(pivot, Vector2(52.0, -101.0) * content_scale, rotation_radians),
		straw,
		15.0 * content_scale
	)
	canvas.draw_line(
		_training_dummy_point(pivot, Vector2(-45.0, -101.0) * content_scale, rotation_radians),
		_training_dummy_point(pivot, Vector2(45.0, -101.0) * content_scale, rotation_radians),
		straw_light,
		7.0 * content_scale
	)
	var head_center := _training_dummy_point(
		pivot,
		Vector2(0.0, -143.0) * content_scale,
		rotation_radians
	)
	canvas.draw_circle(head_center, 23.0 * content_scale, straw)
	canvas.draw_circle(
		head_center + Vector2(-5.0, -5.0) * content_scale,
		8.0 * content_scale,
		Color(1.0, 0.84, 0.48, 0.22)
	)
	canvas.draw_line(
		_training_dummy_point(pivot, Vector2(-23.0, -71.0) * content_scale, rotation_radians),
		_training_dummy_point(pivot, Vector2(23.0, -71.0) * content_scale, rotation_radians),
		tie,
		9.0 * content_scale
	)


func _draw_training_impact_effect(
	canvas: CanvasItem,
	dummy_pivot: Vector2,
	content_scale: float,
	progress: float,
	rotation_radians: float,
	impact_directions: Array,
	impact_point_offsets: Array
) -> void:
	var t := clampf(progress, 0.0, 1.0)
	var impact := _training_dummy_point(
		dummy_pivot,
		Vector2(-34.0, -104.0) * content_scale,
		rotation_radians
	)
	var spread := (18.0 + 40.0 * t) * content_scale
	var broad_alpha := 0.02 * (1.0 - t)
	canvas.draw_circle(
		impact,
		(23.0 + 38.0 * t) * content_scale,
		Color(1.0, 0.58, 0.18, 0.075 * (1.0 - t))
	)
	canvas.draw_circle(
		impact + Vector2(8.0, -4.0) * content_scale * t,
		(11.0 + 17.0 * t) * content_scale,
		Color(1.0, 0.88, 0.50, 0.12 * (1.0 - t))
	)
	var resolved_directions: Array = impact_directions
	if resolved_directions.is_empty():
		resolved_directions = [
			Vector2(-1.0, -0.20),
			Vector2(-0.72, -0.72),
			Vector2(0.12, -1.0),
			Vector2(0.72, -0.54),
		]
	for direction in resolved_directions:
		var unit_direction: Vector2 = (direction as Vector2).normalized()
		var inner := impact + unit_direction * spread * 0.18
		var outer := impact + unit_direction * spread
		canvas.draw_line(
			inner,
			outer,
			Color(1.0, 0.64, 0.22, broad_alpha),
			22.0 * content_scale
		)
		canvas.draw_line(
			inner,
			outer,
			Color(1.0, 0.83, 0.42, 0.16 * (1.0 - t)),
			7.0 * content_scale
		)
	var resolved_point_offsets: Array = impact_point_offsets
	if resolved_point_offsets.is_empty():
		resolved_point_offsets = [
			Vector2(-19.0, -12.0),
			Vector2(15.0, -22.0),
			Vector2(24.0, 7.0),
		]
	for point_offset in resolved_point_offsets:
		var drift: Vector2 = point_offset as Vector2
		canvas.draw_circle(
			impact + drift * content_scale * (0.45 + t),
			(2.8 - 1.2 * t) * content_scale,
			Color(1.0, 0.92, 0.58, 0.72 * (1.0 - t))
		)


func _training_dummy_point(
	pivot: Vector2,
	local_point: Vector2,
	rotation_radians: float
) -> Vector2:
	return pivot + local_point.rotated(rotation_radians)


func build_balance_row_layout(
	content_scale: float = 1.0,
	content_offset: Vector2 = Vector2.ZERO
) -> Dictionary:
	var safe_scale := maxf(0.001, content_scale)
	var row_rect := _screen_rect(BALANCE_ROW_RECT, safe_scale, content_offset)
	var gap := BALANCE_ENTRY_GAP * safe_scale
	var entry_width := (row_rect.size.x - gap) * 0.5
	var entry_size := Vector2(entry_width, row_rect.size.y)
	var entries: Array[Dictionary] = []
	for index in range(2):
		var entry_rect := Rect2(
			row_rect.position + Vector2(float(index) * (entry_width + gap), 0.0),
			entry_size
		)
		var icon_size := BALANCE_ICON_SIZE * safe_scale
		var icon_center := Vector2(
			entry_rect.position.x + BALANCE_ICON_LEFT_PAD * safe_scale + icon_size * 0.5,
			entry_rect.get_center().y
		)
		var text_left := icon_center.x + icon_size * 0.5 + BALANCE_TEXT_GAP * safe_scale
		entries.append({
			"currency": "muhon" if index == 0 else "gold",
			"rect": entry_rect,
			"icon_center": icon_center,
			"icon_size": icon_size,
			"text_rect": Rect2(
				Vector2(text_left, entry_rect.position.y),
				Vector2(maxf(0.0, entry_rect.end.x - text_left), entry_rect.size.y)
			),
		})
	return {
		"row_rect": row_rect,
		"entries": entries,
		"uses_background_box": false,
	}


func _draw_balance_entry(
	canvas: CanvasItem,
	entry: Dictionary,
	label: String,
	content_scale: float = 1.0
) -> void:
	var rect: Rect2 = entry.get("rect", Rect2())
	var icon_center: Vector2 = entry.get("icon_center", rect.get_center())
	var icon_size := maxf(1.0, float(entry.get("icon_size", BALANCE_ICON_SIZE * content_scale)))
	if str(entry.get("currency", "")) == "muhon":
		CommonStarpointVisualHost.draw_muhon_fallback(
			canvas,
			icon_center,
			icon_size * 0.34,
			1.0,
			0.62,
			false,
			0.0
		)
	else:
		_draw_gold_coin_icon(canvas, icon_center, icon_size, content_scale)
	var text_rect: Rect2 = entry.get("text_rect", rect)
	var font_size := maxi(10, int(round(BALANCE_FONT_SIZE * content_scale)))
	var baseline := Vector2(
		text_rect.position.x,
		rect.position.y + (rect.size.y - float(font_size)) * 0.5 + float(font_size) * 0.82
	)
	var outline_size := maxi(1, int(round(BALANCE_TEXT_OUTLINE_SIZE * content_scale)))
	canvas.draw_string_outline(
		ThemeDB.fallback_font,
		baseline,
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		text_rect.size.x,
		font_size,
		outline_size,
		Color(PAPER, 0.94)
	)
	canvas.draw_string(
		ThemeDB.fallback_font,
		baseline,
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		text_rect.size.x,
		font_size,
		INK
	)


func _draw_gold_coin_icon(
	canvas: CanvasItem,
	center: Vector2,
	size: float,
	content_scale: float
) -> void:
	var radius := maxf(4.0, size * 0.5)
	canvas.draw_circle(center, radius, Color(0.78, 0.55, 0.14, 1.0))
	canvas.draw_circle(
		center,
		maxf(1.0, radius - 1.8 * content_scale),
		Color(1.0, 0.82, 0.26, 1.0)
	)
	canvas.draw_arc(
		center,
		maxf(1.0, radius - 3.0 * content_scale),
		0.0,
		TAU,
		20,
		Color(0.80, 0.56, 0.16, 0.45),
		maxf(1.0, content_scale),
		true
	)
	canvas.draw_circle(
		center + Vector2(-radius * 0.26, -radius * 0.30),
		maxf(1.0, radius * 0.26),
		Color(1.0, 0.95, 0.66, 0.55)
	)


func _draw_modal_action_row(
	canvas: CanvasItem,
	rect: Rect2,
	action: Dictionary,
	selected: bool,
	content_scale: float = 1.0
) -> void:
	var enabled := bool(action.get("enabled", true))
	var fill := CINNABAR if selected and enabled else Color(PAPER_DEEP, 0.72)
	var text_color := PAPER if selected and enabled else INK
	if not enabled:
		fill = Color(SEALED, 0.32)
		text_color = Color(SEALED, 0.84)
	canvas.draw_rect(rect, fill, true)
	canvas.draw_rect(
		rect,
		CINNABAR_DARK if selected else GOLD,
		false,
		(2.0 if selected else 1.0) * content_scale
	)
	canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(
			rect.position.x + 10.0 * content_scale,
			rect.position.y + minf(25.0 * content_scale, rect.size.y * 0.56)
		),
		str(action.get("label", "")),
		HORIZONTAL_ALIGNMENT_LEFT,
		maxf(52.0 * content_scale, rect.size.x - 102.0 * content_scale),
		maxi(10, int(round((14.0 if rect.size.x < 400.0 * content_scale else 16.0) * content_scale))),
		text_color
	)
	canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(
			rect.end.x - 88.0 * content_scale,
			rect.position.y + minf(25.0 * content_scale, rect.size.y * 0.56)
		),
		str(action.get("cost_text", "")),
		HORIZONTAL_ALIGNMENT_RIGHT,
		78.0 * content_scale,
		maxi(9, int(round((12.0 if rect.size.x < 400.0 * content_scale else 14.0) * content_scale))),
		text_color
	)


func _draw_route_aim(canvas: Object, flow: Object) -> void:
	var font := ThemeDB.fallback_font
	_draw_route_wind_effect(canvas, flow)
	for target_variant in flow.get_route_aim_targets():
		var target: Dictionary = target_variant
		var target_position := _vector2(target.get("position", Vector2.ZERO))
		var target_radius := float(target.get("draw_radius", TowerAscentTuning.TEMP_ROUTE_TARGET_DRAW_RADIUS))
		var target_fill := CINNABAR_DARK if bool(target.get("enraged", false)) else PAPER_DEEP
		canvas.draw_circle(target_position, target_radius, target_fill)
		canvas.draw_circle(target_position, target_radius, CINNABAR, false, 3.0)
		var icon_presentation: Dictionary = target.get("icon_presentation", {})
		var icon_texture_value: Variant = icon_presentation.get("icon_texture", null)
		if icon_texture_value is Texture2D:
			var icon_size := Vector2.ONE * target_radius * 1.72
			canvas.draw_texture_rect(
				icon_texture_value as Texture2D,
				Rect2(target_position - icon_size * 0.5, icon_size),
				false
			)
		else:
			var fallback_label := str(icon_presentation.get(
				"fallback_label",
				target.get("label", "행로")
			))
			var label_rect := Rect2(
				target_position.x - TowerAscentTuning.TEMP_ROUTE_TARGET_LABEL_WIDTH * 0.5,
				target_position.y - target_radius - TowerAscentTuning.TEMP_ROUTE_TARGET_LABEL_GAP - TowerAscentTuning.TEMP_ROUTE_TARGET_LABEL_HEIGHT,
				TowerAscentTuning.TEMP_ROUTE_TARGET_LABEL_WIDTH,
				TowerAscentTuning.TEMP_ROUTE_TARGET_LABEL_HEIGHT
			)
			canvas.draw_rect(label_rect, Color(0.04, 0.025, 0.02, 0.86), true)
			canvas.draw_rect(label_rect, GOLD, false, 1.5)
			canvas.draw_string(font, label_rect.position + Vector2(0.0, 21.0), fallback_label, HORIZONTAL_ALIGNMENT_CENTER, label_rect.size.x, 16, PAPER)
	_draw_route_pickups(canvas, flow)
	_draw_route_aim_gauge(canvas, flow)
	_draw_route_wind_indicator(canvas, flow)
	canvas.draw_string(font, Vector2(80.0, 42.0), "서브로 다음 행로의 표적을 맞히세요", HORIZONTAL_ALIGNMENT_CENTER, 600.0, 18, PAPER)
	canvas.draw_string(font, Vector2(80.0, 64.0), "명중할 때까지 다시 서브할 수 있습니다", HORIZONTAL_ALIGNMENT_CENTER, 600.0, 15, Color(PAPER, 0.82))


func _draw_route_wind_effect(canvas: Object, flow: Object) -> int:
	if (
		canvas == null
		or not (canvas is CanvasItem)
		or flow == null
		or not flow.has_method("get_route_wind_visual_state")
	):
		return 0
	if flow.has_method("has_visible_route_wind_indicator"):
		if not bool(flow.has_visible_route_wind_indicator()):
			return 0
	elif (
		not flow.has_method("get_route_wind_model")
		or not TowerAscentRouteWindPolicy.is_indicator_visible(flow.get_route_wind_model())
	):
		return 0
	return _route_wind_effect_renderer.draw_wind_particles(
		flow.get_route_wind_visual_state(),
		canvas as CanvasItem,
		Vector2.ZERO,
		1.0,
		Rect2(Vector2.ZERO, PLAYFIELD_SIZE)
	)


func debug_draw_route_wind_effect(canvas: Object, flow: Object) -> int:
	return _draw_route_wind_effect(canvas, flow)


func debug_draw_route_aim(canvas: Object, flow: Object) -> void:
	_draw_route_aim(canvas, flow)


func _draw_route_pickups(canvas: Object, flow: Object) -> void:
	if not flow.has_method("get_route_pickups"):
		return
	for pickup_variant in flow.get_route_pickups():
		var pickup: Dictionary = pickup_variant
		var center := _vector2(pickup.get("position", Vector2.ZERO))
		var radius := maxf(4.0, float(pickup.get(
			"draw_radius",
			TowerAscentTuning.TEMP_ROUTE_PICKUP_DRAW_RADIUS
		)))
		match str(pickup.get("kind", "")):
			TowerAscentRoutePickupState.KIND_GOLD:
				_draw_gold_coin_icon(canvas, center, radius * 1.55, 1.0)
			TowerAscentRoutePickupState.KIND_MUHON:
				CommonStarpointVisualHost.draw_muhon_fallback(
					canvas,
					center,
					radius * 0.52,
					1.0,
					0.72,
					false,
					0.0
				)
			TowerAscentRoutePickupState.KIND_ACTIVE_ITEM:
				canvas.draw_circle(center, radius, Color(CINNABAR_DARK, 0.72))
				canvas.draw_circle(center, radius, GOLD, false, 2.0)
				var icon_size := Vector2.ONE * radius * 1.82
				canvas.draw_texture_rect(
					ROUTE_PICKUP_BAG_TEXTURE,
					Rect2(center - icon_size * 0.5, icon_size),
					false
				)


func debug_draw_route_pickups(canvas: Object, flow: Object) -> void:
	_draw_route_pickups(canvas, flow)


func _draw_route_wind_indicator(canvas: Object, flow: Object) -> void:
	if (
		not flow.has_method("get_route_aim_gauge_model")
		or not flow.has_method("get_route_wind_model")
	):
		return
	# GRT-043: calm route entries exit before the gauge/wind draw models are
	# built. A gate inside the panel painter would still build-then-discard.
	if flow.has_method("has_visible_route_wind_indicator"):
		if not bool(flow.has_visible_route_wind_indicator()):
			return
	elif not TowerAscentRouteWindPolicy.is_indicator_visible(
		flow.get_route_wind_model()
	):
		return
	var gauge_model: Dictionary = flow.get_route_aim_gauge_model()
	if not bool(gauge_model.get("visible", false)):
		return
	_draw_route_wind_indicator_model(
		canvas,
		_vector2(gauge_model.get("origin", Vector2.ZERO)),
		flow.get_route_wind_model()
	)


func debug_draw_route_wind_indicator(
	canvas: Object,
	origin: Vector2,
	wind_model: Dictionary
) -> void:
	_draw_route_wind_indicator_model(canvas, origin, wind_model)


func debug_draw_route_wind_from_flow(canvas: Object, flow: Object) -> void:
	_draw_route_wind_indicator(canvas, flow)


func _draw_route_wind_indicator_model(
	canvas: Object,
	origin: Vector2,
	wind_model: Dictionary
) -> void:
	if not TowerAscentRouteWindPolicy.is_indicator_visible(wind_model):
		return
	var panel := _route_wind_panel_rect(origin)
	var frame_index := resolve_route_wind_vane_frame_index(wind_model)
	if _draw_route_wind_vane_atlas_frame(canvas, panel, frame_index):
		return
	_draw_route_wind_indicator_procedural(canvas, panel, wind_model)


func debug_draw_route_wind_vane_atlas_frame(
	canvas: Object,
	origin: Vector2,
	frame_index: int
) -> bool:
	return _draw_route_wind_vane_atlas_frame(
		canvas,
		_route_wind_panel_rect(origin),
		frame_index
	)


func resolve_route_wind_vane_frame_index(wind_model: Dictionary) -> int:
	var direction := clampi(int(wind_model.get("direction", 0)), -1, 1)
	var strength_level := clampi(int(wind_model.get("strength_level", 0)), 0, 3)
	if direction < 0 and strength_level > 0:
		return ROUTE_WIND_VANE_FRAME_LEFT_WEAK + strength_level - 1
	if direction > 0 and strength_level > 0:
		return ROUTE_WIND_VANE_FRAME_RIGHT_WEAK + strength_level - 1
	return ROUTE_WIND_VANE_FRAME_CALM


func _route_wind_panel_rect(origin: Vector2) -> Rect2:
	var panel_size := TowerAscentTuning.TEMP_ROUTE_WIND_PANEL_SIZE
	var panel_x := (
		origin.x
		+ TowerAscentTuning.TEMP_ROUTE_AIM_GAUGE_RADIUS
		+ TowerAscentTuning.TEMP_ROUTE_WIND_PANEL_GAP
	)
	if panel_x + panel_size.x > PLAYFIELD_SIZE.x - 12.0:
		panel_x = (
			origin.x
			- TowerAscentTuning.TEMP_ROUTE_AIM_GAUGE_RADIUS
			- TowerAscentTuning.TEMP_ROUTE_WIND_PANEL_GAP
			- panel_size.x
		)
	return Rect2(
		Vector2(panel_x, origin.y - panel_size.y * 0.5),
		panel_size
	)


func _draw_route_wind_vane_atlas_frame(
	canvas: Object,
	panel: Rect2,
	frame_index: int
) -> bool:
	if (
		_route_wind_vane_atlas_texture == null
		or not canvas.has_method("draw_texture_rect_region")
		or frame_index < 0
		or frame_index >= ROUTE_WIND_VANE_ATLAS_FRAMES
	):
		return false
	var expected_texture_size := Vector2(
		float(ROUTE_WIND_VANE_FRAME_SIZE.x * ROUTE_WIND_VANE_ATLAS_COLS),
		float(ROUTE_WIND_VANE_FRAME_SIZE.y * ROUTE_WIND_VANE_ATLAS_ROWS)
	)
	if _route_wind_vane_atlas_texture.get_size() != expected_texture_size:
		return false
	var source_rect := Rect2(
		Vector2(
			float(frame_index * ROUTE_WIND_VANE_FRAME_SIZE.x),
			0.0
		),
		Vector2(ROUTE_WIND_VANE_FRAME_SIZE)
	)
	# draw_texture_rect_region consumes pixel source rects directly. No
	# draw_polygon UVs are involved, so GRT-033 normalization cannot regress.
	canvas.draw_texture_rect_region(
		_route_wind_vane_atlas_texture,
		panel,
		source_rect
	)
	return true


func _draw_route_wind_indicator_procedural(
	canvas: Object,
	panel: Rect2,
	wind_model: Dictionary
) -> void:
	var center := panel.get_center()
	canvas.draw_rect(panel, Color(0.04, 0.025, 0.02, 0.88), true)
	canvas.draw_rect(panel, GOLD, false, 1.5)
	canvas.draw_line(
		Vector2(panel.position.x + 10.0, center.y),
		Vector2(panel.end.x - 10.0, center.y),
		Color(PAPER, 0.42),
		1.5,
		true
	)
	var direction := clampi(int(wind_model.get("direction", 0)), -1, 1)
	var strength_level := clampi(int(wind_model.get("strength_level", 0)), 0, 3)
	var cell_size := TowerAscentTuning.TEMP_ROUTE_WIND_STRENGTH_CELL_SIZE
	var cell_gap := TowerAscentTuning.TEMP_ROUTE_WIND_STRENGTH_CELL_GAP
	for side in [-1, 1]:
		for level in range(1, 4):
			var distance := 12.0 + float(level - 1) * (cell_size.x + cell_gap)
			var cell_center := center + Vector2(float(side) * distance, 10.0)
			var cell := Rect2(cell_center - cell_size * 0.5, cell_size)
			var active: bool = direction == int(side) and level <= strength_level
			if active:
				canvas.draw_rect(cell, Color(CINNABAR, 0.92), true)
			else:
				canvas.draw_rect(cell, Color(PAPER, 0.34), false, 1.0)
	canvas.draw_circle(center, 3.5, Color("fff1a6"))
	if direction == 0 or strength_level == 0:
		canvas.draw_circle(center, 8.0, Color(GOLD, 0.72), false, 1.5)
		return
	var arrow_direction := Vector2(float(direction), 0.0)
	var arrow_tip := center + arrow_direction * 42.0
	var arrow_base := center + arrow_direction * 12.0
	var perpendicular := Vector2(0.0, 1.0)
	canvas.draw_colored_polygon(
		PackedVector2Array([
			arrow_tip,
			arrow_base + perpendicular * 6.0,
			arrow_base - perpendicular * 6.0,
		]),
		Color("ffcf59")
	)


func _draw_route_aim_gauge(canvas: Object, flow: Object) -> void:
	_draw_route_aim_gauge_with_textures(
		canvas,
		flow,
		ROUTE_AIM_GAUGE_FAN_TEXTURE,
		ROUTE_AIM_GAUGE_ARROW_TEXTURE
	)


func debug_draw_route_aim_gauge_with_textures(
	canvas: Object,
	flow: Object,
	fan_texture: Variant,
	arrow_texture: Variant
) -> void:
	_draw_route_aim_gauge_with_textures(canvas, flow, fan_texture, arrow_texture)


func _draw_route_aim_gauge_with_textures(
	canvas: Object,
	flow: Object,
	fan_texture: Variant,
	arrow_texture: Variant
) -> void:
	if not flow.has_method("get_route_aim_gauge_model"):
		return
	var model: Dictionary = flow.get_route_aim_gauge_model()
	if not bool(model.get("visible", false)):
		return
	var origin := _vector2(model.get("origin", Vector2.ZERO))
	var radius := TowerAscentTuning.TEMP_ROUTE_AIM_GAUGE_RADIUS
	var min_angle := deg_to_rad(float(model.get(
		"min_degrees",
		TowerAscentTuning.TEMP_ROUTE_AIM_MIN_DEGREES
	)))
	var max_angle := deg_to_rad(float(model.get(
		"max_degrees",
		TowerAscentTuning.TEMP_ROUTE_AIM_MAX_DEGREES
	)))
	var angle := deg_to_rad(float(model.get("angle_degrees", 0.0)))
	if not (fan_texture is Texture2D) or not (arrow_texture is Texture2D):
		_draw_route_aim_gauge_procedural(
			canvas,
			origin,
			radius,
			min_angle,
			max_angle,
			angle
		)
		return
	var fan := fan_texture as Texture2D
	var arrow := arrow_texture as Texture2D
	var texture_scale := (
		radius / TowerAscentTuning.TEMP_ROUTE_AIM_GAUGE_TEXTURE_RADIUS_PX
	)
	var fan_size := fan.get_size() * texture_scale
	var fan_pivot := fan_size * TowerAscentTuning.TEMP_ROUTE_AIM_GAUGE_PIVOT_RATIO
	canvas.draw_texture_rect(
		fan,
		Rect2(origin - fan_pivot, fan_size),
		false,
		Color.WHITE,
		false
	)
	var arrow_direction := Vector2(sin(angle), -cos(angle))
	var arrow_center := (
		origin
		+ arrow_direction
		* radius
		* TowerAscentTuning.TEMP_ROUTE_AIM_ARROW_ORBIT_RATIO
	)
	var arrow_half_size := arrow.get_size() * texture_scale * 0.5
	var axis_x := Vector2(cos(angle), sin(angle))
	var axis_y := Vector2(-axis_x.y, axis_x.x)
	var points := PackedVector2Array([
		arrow_center - axis_x * arrow_half_size.x - axis_y * arrow_half_size.y,
		arrow_center + axis_x * arrow_half_size.x - axis_y * arrow_half_size.y,
		arrow_center + axis_x * arrow_half_size.x + axis_y * arrow_half_size.y,
		arrow_center - axis_x * arrow_half_size.x + axis_y * arrow_half_size.y,
	])
	var uvs := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(0.0, 1.0),
	])
	canvas.draw_polygon(
		points,
		PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]),
		uvs,
		arrow
	)


func _draw_route_aim_gauge_procedural(
	canvas: Object,
	origin: Vector2,
	radius: float,
	min_angle: float,
	max_angle: float,
	angle: float
) -> void:
	var outer_fan := _build_route_aim_fan(origin, radius, min_angle, max_angle, 28)
	var inner_fan := _build_route_aim_fan(origin, radius - 8.0, min_angle, max_angle, 28)
	canvas.draw_colored_polygon(outer_fan, Color(CINNABAR_DARK, 0.42))
	canvas.draw_colored_polygon(inner_fan, Color(GOLD, 0.18))
	canvas.draw_arc(
		origin,
		radius + 3.0,
		-PI * 0.5 + min_angle,
		-PI * 0.5 + max_angle,
		28,
		Color(CINNABAR, 0.16),
		12.0,
		true
	)
	canvas.draw_arc(
		origin,
		radius,
		-PI * 0.5 + min_angle,
		-PI * 0.5 + max_angle,
		28,
		Color(GOLD, 0.88),
		3.0,
		true
	)
	for tick_index in range(7):
		var ratio := float(tick_index) / 6.0
		var tick_angle := lerpf(min_angle, max_angle, ratio)
		var tick_direction := Vector2(sin(tick_angle), -cos(tick_angle))
		canvas.draw_line(
			origin + tick_direction * (radius - 10.0),
			origin + tick_direction * (radius - 3.0),
			Color(PAPER, 0.58),
			2.0,
			true
		)
	var arrow_direction := Vector2(sin(angle), -cos(angle))
	var arrow_end := origin + arrow_direction * (radius - 6.0)
	canvas.draw_line(origin, arrow_end, Color(CINNABAR, 0.25), 10.0, true)
	canvas.draw_line(origin, arrow_end, Color("ffcf59"), 4.0, true)
	var perpendicular := Vector2(-arrow_direction.y, arrow_direction.x)
	var arrow_head := PackedVector2Array([
		arrow_end + arrow_direction * 7.0,
		arrow_end - arrow_direction * 5.0 + perpendicular * 5.0,
		arrow_end - arrow_direction * 5.0 - perpendicular * 5.0,
	])
	canvas.draw_colored_polygon(arrow_head, Color("fff1a6"))
	canvas.draw_circle(origin, 6.0, Color(CINNABAR, 0.28))
	canvas.draw_circle(origin, 3.0, Color("fff1a6"))


func _build_route_aim_fan(
	origin: Vector2,
	radius: float,
	min_angle: float,
	max_angle: float,
	segments: int
) -> PackedVector2Array:
	var points := PackedVector2Array([origin])
	for index in range(segments + 1):
		var ratio := float(index) / float(segments)
		var angle := lerpf(min_angle, max_angle, ratio)
		points.append(origin + Vector2(sin(angle), -cos(angle)) * radius)
	return points


func _draw_map_transition(canvas: CanvasItem, flow: Object) -> void:
	var progress: float = clampf(float(flow.get_map_transition_progress()), 0.0, 1.0)
	var current: Vector2 = flow.get_rest_node_position()
	var target: Vector2 = flow.get_selected_target_position()
	var marker := current.lerp(target, progress)
	canvas.draw_circle(marker, 12.0 + 3.0 * sin(progress * PI), CINNABAR)
	canvas.draw_circle(marker, 18.0, GOLD, false, 3.0)
	canvas.draw_string(
		ThemeDB.fallback_font,
		Vector2(80.0, 704.0),
		"선택한 행로로 이동 중",
		HORIZONTAL_ALIGNMENT_CENTER,
		600.0,
		20,
		INK
	)


func _draw_fake_ending_teaser(canvas: CanvasItem, flow: Object) -> void:
	var model: Dictionary = (
		flow.get_ending_view_model()
		if flow.has_method("get_ending_view_model")
		else {}
	)
	canvas.draw_rect(Rect2(Vector2.ZERO, PLAYFIELD_SIZE), Color(0.02, 0.012, 0.01, 0.84), true)
	var panel := Rect2(104.0, 214.0, 552.0, 292.0)
	canvas.draw_rect(panel, Color("201813"), true)
	canvas.draw_rect(panel, CINNABAR, false, 4.0)
	canvas.draw_rect(panel.grow(-12.0), GOLD, false, 1.5)
	var font := ThemeDB.fallback_font
	canvas.draw_string(font, Vector2(144.0, 286.0), str(model.get("title", "가짜 끝")), HORIZONTAL_ALIGNMENT_CENTER, 472.0, 30, PAPER)
	canvas.draw_line(Vector2(166.0, 310.0), Vector2(594.0, 310.0), Color(GOLD, 0.72), 2.0)
	canvas.draw_string(font, Vector2(132.0, 374.0), str(model.get("body", "")), HORIZONTAL_ALIGNMENT_CENTER, 496.0, 24, Color("f3dba8"))
	canvas.draw_string(font, Vector2(132.0, 454.0), str(model.get("prompt", "")), HORIZONTAL_ALIGNMENT_CENTER, 496.0, 15, Color(PAPER, 0.78))


func _draw_ending_choice(canvas: CanvasItem, flow: Object) -> void:
	var model: Dictionary = (
		flow.get_ending_choice_view_model()
		if flow.has_method("get_ending_choice_view_model")
		else {}
	)
	canvas.draw_rect(Rect2(Vector2.ZERO, PLAYFIELD_SIZE), Color(0.02, 0.012, 0.01, 0.84), true)
	var panel := Rect2(104.0, 156.0, 552.0, 430.0)
	canvas.draw_rect(panel, Color("f3e1b8"), true)
	canvas.draw_rect(panel, CINNABAR_DARK, false, 5.0)
	canvas.draw_rect(panel.grow(-12.0), GOLD, false, 1.5)
	var font := ThemeDB.fallback_font
	canvas.draw_string(font, Vector2(144.0, 226.0), str(model.get("title", "왕의 시련")), HORIZONTAL_ALIGNMENT_CENTER, 472.0, 30, INK)
	canvas.draw_string(font, Vector2(132.0, 286.0), str(model.get("body", "")), HORIZONTAL_ALIGNMENT_CENTER, 496.0, 17, INK_SOFT)
	var actions: Array = model.get("actions", [])
	var selected_index := int(model.get("selected_index", 0))
	for index in range(actions.size()):
		var rect := Rect2(158.0, 382.0 + float(index) * 64.0, 444.0, 50.0)
		var selected := index == selected_index
		canvas.draw_rect(rect, CINNABAR if selected else Color(PAPER_DEEP, 0.76), true)
		canvas.draw_rect(rect, CINNABAR_DARK, false, 2.0)
		canvas.draw_string(font, Vector2(rect.position.x, rect.position.y + 33.0), str((actions[index] as Dictionary).get("label", "")), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 18, PAPER if selected else INK)
	canvas.draw_string(font, Vector2(132.0, 548.0), str(model.get("prompt", "")), HORIZONTAL_ALIGNMENT_CENTER, 496.0, 14, CINNABAR_DARK)


func _draw_run_settlement(canvas: CanvasItem, flow: Object) -> void:
	var model: Dictionary = (
		flow.get_settlement_view_model()
		if flow.has_method("get_settlement_view_model")
		else {}
	)
	canvas.draw_rect(Rect2(Vector2.ZERO, PLAYFIELD_SIZE), Color(0.018, 0.012, 0.01, 0.9), true)
	var panel := Rect2(86.0, 76.0, 588.0, 598.0)
	canvas.draw_rect(panel, Color("f2dfb7"), true)
	canvas.draw_rect(panel, CINNABAR_DARK, false, 5.0)
	canvas.draw_rect(panel.grow(-12.0), GOLD, false, 1.5)
	var font := ThemeDB.fallback_font
	canvas.draw_string(font, Vector2(126.0, 137.0), str(model.get("title", "등정 종료")), HORIZONTAL_ALIGNMENT_CENTER, 508.0, 30, INK)
	canvas.draw_string(font, Vector2(544.0, 137.0), str(model.get("floor_text", "")), HORIZONTAL_ALIGNMENT_RIGHT, 70.0, 17, CINNABAR_DARK)
	canvas.draw_string(font, Vector2(116.0, 177.0), str(model.get("body", "")), HORIZONTAL_ALIGNMENT_CENTER, 528.0, 16, INK_SOFT)
	_draw_settlement_section(
		canvas,
		Rect2(116.0, 208.0, 528.0, 176.0),
		str(model.get("lost_build_title", "")),
		model.get("lost_build_rows", [])
	)
	_draw_settlement_section(
		canvas,
		Rect2(116.0, 402.0, 528.0, 176.0),
		str(model.get("persistent_income_title", "")),
		model.get("persistent_income_rows", [])
	)
	canvas.draw_string(font, Vector2(126.0, 632.0), str(model.get("prompt", "")), HORIZONTAL_ALIGNMENT_CENTER, 508.0, 15, CINNABAR_DARK)


func _draw_settlement_section(
	canvas: CanvasItem,
	rect: Rect2,
	title: String,
	rows_value: Variant
) -> void:
	canvas.draw_rect(rect, Color(PAPER_DEEP, 0.42), true)
	canvas.draw_rect(rect, GOLD, false, 1.5)
	canvas.draw_string(ThemeDB.fallback_font, rect.position + Vector2(18.0, 30.0), title, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 36.0, 18, INK)
	var rows: Array = rows_value if rows_value is Array else []
	for index in range(mini(rows.size(), 6)):
		canvas.draw_string(
			ThemeDB.fallback_font,
			rect.position + Vector2(28.0, 60.0 + float(index) * 20.0),
			"· %s" % str(rows[index]),
			HORIZONTAL_ALIGNMENT_LEFT,
			rect.size.x - 56.0,
			13,
			INK_SOFT
		)


func _draw_gauntlet_transition(canvas: CanvasItem, flow: Object) -> void:
	var model: Dictionary = (
		flow.get_gauntlet_transition_view_model()
		if flow.has_method("get_gauntlet_transition_view_model")
		else {}
	)
	canvas.draw_rect(Rect2(Vector2.ZERO, PLAYFIELD_SIZE), Color(0.018, 0.012, 0.01, 0.9), true)
	var panel := Rect2(104.0, 170.0, 552.0, 390.0)
	canvas.draw_rect(panel, Color("201813"), true)
	canvas.draw_rect(panel, CINNABAR, false, 5.0)
	canvas.draw_rect(panel.grow(-12.0), GOLD, false, 1.5)
	var font := ThemeDB.fallback_font
	canvas.draw_string(font, Vector2(144.0, 242.0), str(model.get("title", "4천왕 연전")), HORIZONTAL_ALIGNMENT_CENTER, 472.0, 30, PAPER)
	canvas.draw_line(Vector2(166.0, 268.0), Vector2(594.0, 268.0), Color(GOLD, 0.72), 2.0)
	canvas.draw_string(font, Vector2(132.0, 322.0), str(model.get("body", "")), HORIZONTAL_ALIGNMENT_CENTER, 496.0, 19, Color("f3dba8"))
	var opponent: Dictionary = model.get("opponent", {})
	canvas.draw_rect(Rect2(176.0, 352.0, 408.0, 54.0), Color(CINNABAR_DARK, 0.82), true)
	canvas.draw_string(
		font,
		Vector2(176.0, 387.0),
		str(opponent.get("display_name", "4천왕 슬롯")),
		HORIZONTAL_ALIGNMENT_CENTER,
		408.0,
		20,
		PAPER
	)
	canvas.draw_string(font, Vector2(132.0, 450.0), str(model.get("preserve", "")), HORIZONTAL_ALIGNMENT_CENTER, 496.0, 15, Color(PAPER, 0.82))
	canvas.draw_string(font, Vector2(132.0, 516.0), str(model.get("prompt", "")), HORIZONTAL_ALIGNMENT_CENTER, 496.0, 15, Color(GOLD, 0.9))


func _clip_line_to_rect(
	start: Vector2,
	finish: Vector2,
	rect: Rect2
) -> PackedVector2Array:
	var delta := finish - start
	var minimum_t := 0.0
	var maximum_t := 1.0
	var checks := [
		Vector2(-delta.x, start.x - rect.position.x),
		Vector2(delta.x, rect.end.x - start.x),
		Vector2(-delta.y, start.y - rect.position.y),
		Vector2(delta.y, rect.end.y - start.y),
	]
	for check_variant in checks:
		var check: Vector2 = check_variant
		var denominator: float = check.x
		var numerator: float = check.y
		if is_zero_approx(denominator):
			if numerator < 0.0:
				return PackedVector2Array()
			continue
		var ratio: float = numerator / denominator
		if denominator < 0.0:
			minimum_t = maxf(minimum_t, ratio)
		else:
			maximum_t = minf(maximum_t, ratio)
		if minimum_t > maximum_t:
			return PackedVector2Array()
	return PackedVector2Array([
		start + delta * minimum_t,
		start + delta * maximum_t,
	])


func _vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Vector2i:
		return Vector2(value as Vector2i)
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	return Vector2.ZERO
