extends SceneTree

const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerMapScrollAssetCatalog := preload(
	"res://scripts/tower_ascent/tower_map_scroll_asset_catalog.gd"
)
const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const EXPECTED_ASSET_COUNT := 16
const EXPECTED_UPSCALE_MANIFEST_ASSET_COUNT := 11
const EXPECTED_CLOUD_ASSET_COUNT := 5
const EXPECTED_STANDARD_MAP_ROW_COUNT := 32
const EXPECTED_PRODUCTION_DRAW_CHUNK_COUNT := 21
const EXPECTED_PRODUCTION_SAME_ASSET_BUTT_COUNT := 9
const EXPECTED_PRODUCTION_CROSS_ASSET_DISSOLVE_COUNT := 11
const EXPECTED_BAND_SEAM_OVERLAP_WORLD_PX := 16.0
const EXPECTED_BAND_SOURCE_EDGE_GUARD_WORLD_PX := 0.0
const EXPECTED_BAND_TILEABLE_METHOD := "forward_exemplar_residual_lap_v2"
const EXPECTED_BAND_TILEABLE_BASE_METHOD := "approved_interior_forward_exemplar"
const EXPECTED_BAND_TILEABLE_WEIGHT_CURVE := (
	"paired_12_1_lap_with_smoothstep_endpoint_residual"
)
const EXPECTED_BAND_TILEABLE_ROUNDING := "signed_round_half_up"
const EXPECTED_BAND_TILEABLE_MIN_COMPARISON_TEXTURE_ROWS := 28
const EXPECTED_BAND_TILEABLE_MAX_COMPARISON_TEXTURE_ROWS := 48
const EXPECTED_BAND_TILEABLE_X4_PAIRED_MEAN_LIMIT := 29.0
const EXPECTED_BAND_TILEABLE_WORLD_PAIRED_MEAN_LIMIT := 25.0
const EXPECTED_BAND_TILEABLE_X4_SEAM_LUMA_LIMIT := 0.01
const EXPECTED_BAND_TILEABLE_WORLD_SEAM_LUMA_LIMIT := 0.01
const EXPECTED_BAND_TILEABLE_MIN_IMPROVEMENT_FRACTION := 0.35
const EXPECTED_BAND_TILEABLE_MAX_DIRECT_CORRELATION_EXCESS := 0.16
const EXPECTED_BAND_TILEABLE_MAX_MIRROR_CORRELATION_EXCESS := 0.12
const EXPECTED_BAND_TILEABLE_VALUE_CLOSURE_METHOD := (
	"coarse_world_then_x4_endpoint_then_world_inner_dc_dither_v2"
)
const EXPECTED_BAND_BRIGHT_GUTTER_GUARD_METHOD := (
	"lanczos_phase16_and_cyclic_profile_local_luma_clamp_v3"
)
const EXPECTED_BAND_BRIGHT_GUTTER_SEARCH_RADIUS_WORLD_PX := 16
const EXPECTED_BAND_BRIGHT_GUTTER_MINIMUM_RUN_WORLD_PX := 2
const EXPECTED_BAND_BRIGHT_GUTTER_TARGET_LUMA := 198.0
const EXPECTED_BAND_TEXTURE_SCALE := 4
const EXPECTED_BAND_BODY_LUMA_THRESHOLD := 200.0
const EXPECTED_BAND_BODY_DETAIL_THRESHOLD := 18.0
const EXPECTED_BAND_EDGE_BLEED_WORLD_PX := {
	"human_realm_01_mountain_rev2_x4.png": Vector2i(21, 15),
	"human_realm_02_village_rev2_x4.png": Vector2i(24, 22),
	"human_realm_03_river_rev2_x4.png": Vector2i(21, 15),
	"immortal_realm_01_islands_rev2_x4.png": Vector2i(26, 23),
	"immortal_realm_02_cloud_cranes_rev2_x4.png": Vector2i(18, 15),
	"immortal_realm_03_pavilions_rev2_x4.png": Vector2i(25, 26),
}
const EXPECTED_BAND_MIST_METHOD := "approved_yeouidu_landform_mist_bake_v3"
const EXPECTED_BAND_MIST_BASE_COMMIT := "4739e14ce7f38005947555b59876676def8f723d"
const EXPECTED_BAND_MIST_SOURCE := (
	"images/tower_map_cloud_bitmap_candidates_cc3b/candidates/"
	+ "cloud_haze_band_imagegen_candidate_x4.png"
)
const EXPECTED_BAND_MIST_SOURCE_SHA256 := (
	"11c84301b4fef6f758da4c1d4d58ac7b26693dce799eb486a69fe8ed2b009cfb"
)
const EXPECTED_BAND_MIST_SOURCE_COMMIT := "50c440f946209dc5d149f136a5cf629fc8942681"
const EXPECTED_BAND_MIST_TOOL_SOURCE := (
	"res://../tools/art/bake_tower_map_band_cloud_mist_z13c.py"
)
const EXPECTED_BAND_MIST_TOOL_SHA256 := (
	"61984456a5d4adf53ff5d84b126fdcf6b39ca2d9ddf41731a8b80a0812ed560c"
)
const EXPECTED_BAND_MIST_MANIFEST_SHA256 := (
	"ec100f7da0a245b3bd819b850428b796c89a9385e0757692dc81bc689ac9088e"
)
const EXPECTED_BAND_MIST_FIXED_SEED := 0x5A313343
const EXPECTED_BAND_MIST_FIXED_SEED_STRIP_TABLE_SHA256 := (
	"ac3645cb08a6da17a4d1b8c0a40ece787042a23093358fa9dddf08f8cbb05ca4"
)
const EXPECTED_BAND_MIST_FIXED_SEED_SHAPE_TABLE_SHA256 := (
	"c287c5ce7fbe5599e6c7db4440acb865e332a5a6988aa11ab3d85dda1e2f28ac"
)
const EXPECTED_BAND_MIST_REVERSE_COUNTERFACTUAL_CONSTRUCTION := (
	"copy_then_bottom_edge_equals_reversed_top_edge_v1"
)
const EXPECTED_BAND_MIST_REVERSE_COUNTERFACTUAL_ASSIGNMENT := (
	"counterfactual[-rows:] = sample[:rows][::-1]"
)
const EXPECTED_BAND_MIST_SOURCE_SIZE := Vector2i(2768, 576)
const EXPECTED_BAND_MIST_OUTPUT_SIZE := Vector2i(2768, 1280)
const EXPECTED_BAND_MIST_WORLD_SIZE := Vector2i(692, 320)
const EXPECTED_BAND_MIST_STRIP_HEIGHT := 279
const EXPECTED_BAND_MIST_EDGE_PATCH_HEIGHT := 140
const EXPECTED_BAND_MIST_CORE_WORLD_PX := 18
const EXPECTED_BAND_MIST_FEATHER_WORLD_PX := 17
const EXPECTED_BAND_MIST_FILL_COVER_WORLD_PX := 26
const EXPECTED_BAND_MIST_EDGE_ZONE_WORLD_PX := 35
const EXPECTED_BAND_MIST_IMMUTABLE_BODY_RECT := Rect2i(0, 140, 2768, 1000)
const EXPECTED_BAND_MIST_MIN_CORE_OPACITY := 1.0
const EXPECTED_BAND_MIST_MAX_CORE_OPACITY := 1.0
const EXPECTED_BAND_MIST_MIN_FEATHER_FRONT_STD_TEXTURE_PX := 6.0
const EXPECTED_BAND_MIST_MIN_FEATHER_HORIZONTAL_RESIDUAL_STD := 0.01
const EXPECTED_BAND_MIST_PATCH_BLUR_TEXTURE_PX := 2.0
const EXPECTED_BAND_MIST_MAX_MIRROR_CORRELATION := 0.12
const EXPECTED_BAND_MIST_MIN_REVERSED_COUNTERFACTUAL_CORRELATION := 0.95
const EXPECTED_BAND_MIST_MAX_SEAM_BODY_LUMA_DELTA := 5.0
const EXPECTED_BAND_MIST_MAX_TONE_LUMA := 205.0
const EXPECTED_BAND_MIST_MAX_TONE_CONTRAST_RATIO := 1.0
const EXPECTED_BAND_MIST_MIN_VARIANCE_RATIO := 0.80
const EXPECTED_BAND_MIST_MAX_VARIANCE_RATIO := 1.25
const EXPECTED_BAND_MIST_MIN_CENTER_DETAIL_RATIO := 0.75
const EXPECTED_BAND_MIST_MAX_CENTER_DETAIL_RATIO := 1.25
const EXPECTED_BAND_MIST_THICKNESS_VARIATION_RATIO := 0.40
const EXPECTED_BAND_MIST_NOMINAL_SHAPED_FEATHER_WORLD_PX := 6.25
const EXPECTED_BAND_MIST_MIN_SHAPED_FEATHER_WORLD_PX := 3.75
const EXPECTED_BAND_MIST_MAX_SHAPED_FEATHER_WORLD_PX := 8.75
const EXPECTED_BAND_MIST_OUTER_ALPHA_GUARD_WORLD_PX := 0.25
const EXPECTED_BAND_MIST_MIN_THICKNESS_P95_HALF_RANGE_WORLD_PX := 2.10
const EXPECTED_BAND_MIST_MEANDER_AMPLITUDE_WORLD_PX := 12.0
const EXPECTED_BAND_MIST_MIN_MEANDER_MAXIMUM_WORLD_PX := 11.5
const EXPECTED_BAND_MIST_MAX_MEANDER_MAXIMUM_WORLD_PX := 12.25
const EXPECTED_BAND_MIST_MIN_MEANDER_P95_HALF_RANGE_WORLD_PX := 9.5
const EXPECTED_BAND_MIST_MIN_FIELD_WAVELENGTH_WORLD_PX := 346.0
const EXPECTED_BAND_MIST_MIN_HORIZONTAL_CONTROL_SPAN_WORLD_PX := 16.0
const EXPECTED_BAND_MIST_MIN_THINNING_WIDTH_RATIO := 0.15
const EXPECTED_BAND_MIST_MAX_THINNING_WIDTH_RATIO := 0.25
const EXPECTED_BAND_MIST_MIN_THINNING_OPACITY_MULTIPLIER := 0.34
const EXPECTED_BAND_MIST_MAX_THINNING_OPACITY_MULTIPLIER := 0.48
const EXPECTED_BAND_MIST_MIN_TERRAIN_ATTACHMENT_GAIN := 0.04
const EXPECTED_BAND_MIST_MAX_TERRAIN_ATTACHMENT_ACTIVE_RATIO := 0.35
const EXPECTED_BAND_MIST_MAX_TERRAIN_ATTACHMENT_DEPTH_WORLD_PX := 1.75
const EXPECTED_BAND_MIST_MIN_TOP_BOTTOM_PHASE_DELTA_RAD := 0.20
const EXPECTED_BAND_MIST_MAX_THINNING_STRONG_OVERLAP_RATIO := 0.05
const EXPECTED_BAND_MIST_MIN_COLUMN_INTEGRATED_OPACITY_WORLD_PX := 26.0
const EXPECTED_BAND_MIST_MIN_WARP_VERTICAL_JACOBIAN := 0.55
const EXPECTED_BAND_MIST_MIN_VERTICAL_CONTROL_SPAN_WORLD_PX := 8.0
const EXPECTED_BAND_MIST_HORIZONTAL_CONTROL_CELLS := 43
const EXPECTED_BAND_MIST_EDGE_VERTICAL_CONTROL_CELLS := 4
const EXPECTED_BAND_MIST_PERIODIC_HALO_CONTROL_CELLS := 3
const EXPECTED_BAND_MIST_MIN_SHARED_SEAM_HALF_RANGE_WORLD_PX := 1.0
const EXPECTED_BAND_MIST_MIN_ACTUAL_FRONT_HALF_RANGE_WORLD_PX := 1.75
const EXPECTED_BAND_MIST_MAX_ACTUAL_FRONT_CORRELATION := 0.90
const EXPECTED_BAND_MIST_MAX_TERRAIN_CONTROL_ACTIVE_RATIO := 0.05
const EXPECTED_BAND_MIST_MAX_SOURCE_SAMPLING_BIAS_WORLD_PX := 2.0
const EXPECTED_BAND_MIST_MEANDER_SOURCE_MARGIN_WORLD_PX := 13
const EXPECTED_BAND_MIST_SHARED_SEAM_RESIDUAL_AMPLITUDE_WORLD_PX := 1.5
const EXPECTED_BAND_MIST_THINNING_ACTIVE_WINDOW_THRESHOLD := 0.01
const EXPECTED_BAND_MIST_TERRAIN_CONTROL_QUANTILE := 0.985
const EXPECTED_BAND_MIST_MIN_TERRAIN_SELECTED_STRENGTH := 0.55
const EXPECTED_BAND_MIST_MIN_TERRAIN_SELECTED_FOOT_SCORE := 0.20
const EXPECTED_BAND_MIST_MIN_TERRAIN_SELECTED_DIRECTIONAL_DELTA := 0.05
const EXPECTED_BAND_MIST_TERRAIN_SELECTED_CONTROL_CELLS_PER_EDGE := 1
const EXPECTED_BAND_MIST_TERRAIN_BRIDGE_ANCHOR_WORLD_PX := 24
const EXPECTED_BAND_MIST_TERRAIN_BRIDGE_VERTICAL_CONTROL_CELLS := 6
const EXPECTED_BAND_MIST_TERRAIN_BRIDGE_REVEAL_MINIMUM_WORLD_PX := 0.5
const EXPECTED_BAND_MIST_TERRAIN_BRIDGE_REVEAL_MAXIMUM_WORLD_PX := 1.0
const EXPECTED_BAND_MIST_MIN_TERRAIN_BRIDGE_DETAIL_GAIN := 1.82
const EXPECTED_BAND_MIST_MAX_TERRAIN_BRIDGE_DETAIL_GAIN := 2.0
const EXPECTED_BAND_MIST_TERRAIN_BRIDGE_COMPOSITE_LUMA_BIAS := 18.0
const EXPECTED_BAND_MIST_VISIBLE_PIGMENT_NOMINAL_HALF_WIDTH_WORLD_PX := 16.0
const EXPECTED_BAND_MIST_VISIBLE_PIGMENT_MAXIMUM_MIX := 0.9
const EXPECTED_BAND_MIST_VISIBLE_HAZE_FLOOR := 0.14
const EXPECTED_BAND_MIST_VISIBLE_THINNING_FACTOR_EXPONENT := 1.25
const EXPECTED_BAND_MIST_VISIBLE_ACTIVE_PROFILE_GATE := 0.60
const EXPECTED_BAND_MIST_VISIBLE_THINNING_TERRAIN_DETAIL_GAIN := 0.35
const EXPECTED_BAND_MIST_VISIBLE_SHARED_REFERENCE_DETAIL_GAIN := 1.5
const EXPECTED_BAND_MIST_VISIBLE_CENTERLINE_TARGET_HALF_RANGE_WORLD_PX := 12.0
const EXPECTED_BAND_MIST_MIN_VISIBLE_CENTERLINE_HALF_RANGE_WORLD_PX := 9.5
const EXPECTED_BAND_MIST_MAX_VISIBLE_CENTERLINE_ABSOLUTE_WORLD_PX := 13.5
const EXPECTED_BAND_MIST_MIN_VISIBLE_CENTERLINE_VALID_RATIO := 0.75
const EXPECTED_BAND_MIST_MAX_FULL_WIDTH_PALE_RUN_WORLD_PX := 1.0
const EXPECTED_BAND_MIST_MAX_CORE_LOCAL_LUMA_P95_GAIN := 6.0
const EXPECTED_BAND_MIST_MAX_CORE_LOCAL_LUMA_GAIN := 12.0
const EXPECTED_BAND_MIST_MIN_THINNED_TERRAIN_DETAIL_RATIO := 1.15
const EXPECTED_BAND_MIST_MIN_VISIBLE_THINNED_PEAK_INK_MIX := 0.30
const EXPECTED_BAND_MIST_MIN_VISIBLE_HAZE_FLOOR := 0.12
const EXPECTED_BAND_MIST_VISIBLE_SHAPE_SEAM_TRANSITION_WORLD_PX := 1.25
const EXPECTED_BAND_MIST_VISIBLE_EDGE_VEIL_TRANSITION_WORLD_PX := 1.25
const EXPECTED_BAND_MIST_VISIBLE_EDGE_VEIL_MINIMUM_FACTOR := 0.45
const EXPECTED_BAND_MIST_VISIBLE_EDGE_CENTERLINE_DIVERGENCE_WORLD_PX := 1.5
const EXPECTED_BAND_MIST_VISIBLE_EDGE_VEIL_TOP_PHASE_OFFSET_RAD := PI * 0.5
const EXPECTED_BAND_MIST_MAX_VISIBLE_EDGE_CROSS_CORRELATION := 0.10
const EXPECTED_BAND_MIST_VISIBLE_EDGE_CENTERLINE_MAXIMUM_WORLD_PX := 14.0
const EXPECTED_BAND_MIST_THRESHOLD_MAX_VISIBLE_CENTERLINE_WORLD_PX := 15.0
const EXPECTED_BAND_MIST_MIN_ACTUAL_APPLIED_THINNING_ACTIVE_RATIO := 0.15
const EXPECTED_BAND_MIST_MAX_ACTUAL_APPLIED_THINNING_ACTIVE_RATIO := 0.25
const EXPECTED_BAND_MIST_MAX_ACTUAL_APPLIED_THINNING_STRONG_OVERLAP := 0.05
const EXPECTED_BAND_MIST_MAX_ACTUAL_APPLIED_THINNING_CORRELATION := 0.20
const EXPECTED_BAND_MIST_MAX_VISIBLE_EDGE_VEIL_P05 := 0.50
const EXPECTED_BAND_MIST_MIN_VISIBLE_EDGE_VEIL_P95 := 0.95
const EXPECTED_BAND_MIST_STRIPS := {
	"human_realm_01_mountain_rev2_x4.png": {
		"rect": Rect2i(6, 209, 1152, 279), "detail_gain": 1.65,
		"terrain_bridge_detail_gain": 2.0,
		"source_sampling_bias_world_px": 0.0,
	},
	"human_realm_02_village_rev2_x4.png": {
		"rect": Rect2i(96, 176, 1088, 279), "detail_gain": 1.54,
		"terrain_bridge_detail_gain": 1.82,
		"source_sampling_bias_world_px": 0.0,
	},
	"human_realm_03_river_rev2_x4.png": {
		"rect": Rect2i(1524, 160, 1024, 279), "detail_gain": 1.54,
		"terrain_bridge_detail_gain": 2.0,
		"source_sampling_bias_world_px": 0.0,
	},
	"immortal_realm_01_islands_rev2_x4.png": {
		"rect": Rect2i(0, 200, 928, 279), "detail_gain": 1.66,
		"terrain_bridge_detail_gain": 2.0,
		"source_sampling_bias_world_px": 0.0,
	},
	"immortal_realm_02_cloud_cranes_rev2_x4.png": {
		"rect": Rect2i(102, 235, 1024, 279), "detail_gain": 1.44,
		"terrain_bridge_detail_gain": 1.82,
		"source_sampling_bias_world_px": -2.0,
	},
	"immortal_realm_03_pavilions_rev2_x4.png": {
		"rect": Rect2i(650, 193, 1024, 279), "detail_gain": 1.54,
		"terrain_bridge_detail_gain": 2.0,
		"source_sampling_bias_world_px": 0.0,
	},
}
const EXPECTED_BAND_MIST_OUTPUT_ORDER := [
	"human_realm_01_mountain_rev2_x4.png",
	"human_realm_02_village_rev2_x4.png",
	"human_realm_03_river_rev2_x4.png",
	"immortal_realm_01_islands_rev2_x4.png",
	"immortal_realm_02_cloud_cranes_rev2_x4.png",
	"immortal_realm_03_pavilions_rev2_x4.png",
]
const EXPECTED_BAND_MIST_BASE_OUTPUT_SHA256 := {
	"human_realm_01_mountain_rev2_x4.png": "c9510f9415f44cef8ae9b90e05d67bfc2be3db345b078bae71b20865706a6db6",
	"human_realm_02_village_rev2_x4.png": "4f0fc3b4703f00074b878a5b07f787f2a4896bff85f397b390f493673dc9ebfd",
	"human_realm_03_river_rev2_x4.png": "29b1f8123863248b4fde779ddcdede592410d79029725f938136cf5784fa5f9e",
	"immortal_realm_01_islands_rev2_x4.png": "1da86fe656698b27f3bf5afe795d869fe201591776ac2799ab05e80cf1901a09",
	"immortal_realm_02_cloud_cranes_rev2_x4.png": "2f5ed583ee8231a7046f194e9c5089cd84feb5dbff63a9eab443d0a031af83ab",
	"immortal_realm_03_pavilions_rev2_x4.png": "72bfd1e06958bfb1c8b073add85fa7ee62185f9955300121c2ac6ea93444cfe5",
}
const EXPECTED_BAND_MIST_BASE_RGB_SHA256 := {
	"human_realm_01_mountain_rev2_x4.png": "b85d9a2b4b2616259b58e2c8eac62644dd45323b2b1c534128fa3223fb0edbdd",
	"human_realm_02_village_rev2_x4.png": "0001e85e2684fe4b4df03567d689d88f5903318dbaff69050dfb7d2f9ee9b84b",
	"human_realm_03_river_rev2_x4.png": "d08a28b9559a016f5983fe4bc737ead704ded41a355820ff258209814730a9b9",
	"immortal_realm_01_islands_rev2_x4.png": "9b225ca73444e4e7d32f4e49a4fa8d41675a2b38bac42dad4526751121bc3d01",
	"immortal_realm_02_cloud_cranes_rev2_x4.png": "88d3bb57fde05c21ce6f744ac18d229e2626beec92a846ee1ce043e4c3511952",
	"immortal_realm_03_pavilions_rev2_x4.png": "44275fbc05944fbb4e8efa8fe1668dfa59b0dd4d93ffb876faa95214a3eaf9d9",
}
const EXPECTED_BAND_MIST_IMMUTABLE_BODY_RGB_SHA256 := {
	"human_realm_01_mountain_rev2_x4.png": "eaccd05cb5d630bd17dda27441dd0cf9f30ff47f9fa6f09f3371e404a310bb66",
	"human_realm_02_village_rev2_x4.png": "225a824f22ca6ae8ad5ec1f759abce948f6c31323763e3e1026e8bad07a8b20c",
	"human_realm_03_river_rev2_x4.png": "43df9f91774636208273bc8c7a9a8378b004c14959e26f408b163b823b179ed7",
	"immortal_realm_01_islands_rev2_x4.png": "c796c5b7d6819e22af1f5b8880e80650edcccaac66c4faff12cd92019ec54a3e",
	"immortal_realm_02_cloud_cranes_rev2_x4.png": "b2e31dfa59b80f3a8e176179d190fe3856af5cd764b519784353a911410336f4",
	"immortal_realm_03_pavilions_rev2_x4.png": "c9f83853ebf3b9c6a6b5dbcf034f7f00527b891c2ea7dae562b9378c7e1c239e",
}
const EXPECTED_BAND_MIST_BASE_EDGE_BLEED_SHA256 := {
	"human_realm_01_mountain_rev2_x4.png": "3aadc883b559010d57d69fe80f58452cfba30b738ab7490f3ed135b351c49817",
	"human_realm_02_village_rev2_x4.png": "138fabe29cf6b86a6e06ea2835058b7ad4f5933a2e666555a24077b96769926a",
	"human_realm_03_river_rev2_x4.png": "699a0d0d8fd0c164ae7297b9d12e6ec12aafa306b1b7670dea060ab526c99fdf",
	"immortal_realm_01_islands_rev2_x4.png": "fdbc01744e4dd6ac00650514d5121f97aea735b03cf9e06ad13014ebb32c70a1",
	"immortal_realm_02_cloud_cranes_rev2_x4.png": "ed5b4cc94363076804320e68184fc25ee5bee4909756f6fcc584a9a98fc77cc6",
	"immortal_realm_03_pavilions_rev2_x4.png": "9bcbf407d9982b2a917032cc6fe0e3d5b314a61c3b15a036574f7f7c4efc897d",
}
const EXPECTED_BAND_MIST_FINAL_OUTPUT_SHA256 := {
	"human_realm_01_mountain_rev2_x4.png": "bec65c0a77fc778bc3bf4b14e12d1f54dd5c0fed3a45a9e99ecff155bb41cd54",
	"human_realm_02_village_rev2_x4.png": "92ec34c7050f5e88beb93d320f7b9ccdaa87c4516f5cbf55d5c9fc16a7164176",
	"human_realm_03_river_rev2_x4.png": "10ef6e2c73c291311fc6cdbbeef78aafd8677d593bbe4d01640bb097f2c2ebb2",
	"immortal_realm_01_islands_rev2_x4.png": "75996f5efd571f70f988627e015959db27d23799f92c6f846f0c0111241b940c",
	"immortal_realm_02_cloud_cranes_rev2_x4.png": "5cb429408c80876bf66d1b346cfea9b59a540a45f0f96bbc3bbeda450dfc000a",
	"immortal_realm_03_pavilions_rev2_x4.png": "b4066643c9c76a652af54386d306886d33c90c0ab06a750fafeaa6280e2c18d9",
}
const EXPECTED_BAND_MIST_FINAL_RGB_SHA256 := {
	"human_realm_01_mountain_rev2_x4.png": "671dc1acdfdad89dc33c4fcbc5967b63ffed4d3543943b6f09cc5b12bde9d772",
	"human_realm_02_village_rev2_x4.png": "8cf88751923090713e99706a0e6ec3a2076312fb3bb9193f4754b2e4434fb3f3",
	"human_realm_03_river_rev2_x4.png": "659a8e0b6bc4ad101dffb30defaaa94f0e4e0d6044f7d2f84a3ebc32c07e5790",
	"immortal_realm_01_islands_rev2_x4.png": "f7975d242484942d1e196b4ac408e4fd52e92eb0a87e6c12293e47572c37632c",
	"immortal_realm_02_cloud_cranes_rev2_x4.png": "b2573ab3483f4da53f576628d3759ff5e464dd6ef049b628f5318b58a79916a7",
	"immortal_realm_03_pavilions_rev2_x4.png": "1b33414b56faf3f5e39170e17fdea448ef18cad500755a67e3e0212e1230c303",
}

var _failures: Array[String] = []
var _leg_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_approved_asset_catalog_and_dimensions()
	_verify_x4_manifest_and_import_policy()
	_verify_band_edge_bleed_art_contract()
	_verify_band_edge_mist_bake_art_contract()
	_verify_cloud_bitmap_import_policy()
	_verify_negative_cache_and_missing_asset_fallback()
	_verify_deterministic_nonrepeating_floor_variants()
	_verify_production_prewarm_order_and_draw_peek_contract()
	_verify_opaque_floor_tile_render_model_and_fallback()
	_verify_band_chunk_scale_invariant_boundary_fixture()
	_verify_fullscreen_draw_call_budget_lockstep()
	_verify_three_route_brush_states_and_geometry()
	_verify_fullscreen_medal_node_contract()
	_verify_floor_gate_plaque_three_slice_contract()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_map_scroll_wiring_contract_smoke: PASS=%d" % _leg_count)
		print("tower_map_scroll_wiring_contract_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
		quit(1)


func _verify_x4_manifest_and_import_policy() -> void:
	var manifest_path := (
		"res://assets/sprites/tower/map_scroll/tower_map_scroll_x4_manifest.json"
	)
	var manifest_value: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(manifest_path)
	)
	_expect(manifest_value is Dictionary, "S5 must retain its reproducible x4 asset manifest")
	if not (manifest_value is Dictionary):
		return
	var manifest := manifest_value as Dictionary
	_expect(str(manifest.get("model", "")) == "realesrgan-x4plus", "S5 must pin the conservative Real-ESRGAN model selected by the art gate")
	_expect(int(manifest.get("scale", 0)) == 4, "S5 must pin the approved x4 scale")
	var records: Array = manifest.get("assets", [])
	_expect(
		records.size() == EXPECTED_UPSCALE_MANIFEST_ASSET_COUNT,
		"the Real-ESRGAN manifest must retain its original 11 promoted bitmaps"
	)
	var alpha_asset_count := 0
	for record_value in records:
		var record := record_value as Dictionary
		var source_name := str(record.get("source", ""))
		var output_name := str(record.get("output", ""))
		var root := "res://assets/sprites/tower/map_scroll/"
		var source_path := root + source_name
		var output_path := root + output_name
		_expect(FileAccess.file_exists(source_path), "%s source must remain preserved" % source_name)
		_expect(FileAccess.file_exists(output_path), "%s x4 output must remain tracked" % output_name)
		_expect(
			FileAccess.get_sha256(source_path) == str(record.get("source_sha256", "")),
			"%s reviewed source hash must remain unchanged" % source_name
		)
		_expect(
			FileAccess.get_sha256(output_path) == str(record.get("output_sha256", "")),
			"%s generated x4 hash must match the manifest" % output_name
		)
		var alpha: Dictionary = record.get("alpha", {})
		if bool(alpha.get("present", false)):
			alpha_asset_count += 1
			_expect(str(record.get("output_mode", "")) == "RGBA", "%s must retain recombined source alpha" % output_name)
		else:
			_expect(str(record.get("output_mode", "")) == "RGB", "%s must remain an opaque RGB bitmap" % output_name)
		var import_source := FileAccess.get_file_as_string(output_path + ".import")
		_expect(import_source.find("compress/mode=2") >= 0, "%s must use offline VRAM compression" % output_name)
		_expect(import_source.find("compress/high_quality=true") >= 0, "%s must use high-quality VRAM compression" % output_name)
		_expect(import_source.find("mipmaps/generate=true") >= 0, "%s must generate mipmaps for overview downscaling" % output_name)
	_expect(alpha_asset_count == 4, "only the three brushes and plaque may own source alpha")
	_leg_count += 1


func _verify_cloud_bitmap_import_policy() -> void:
	var catalog := TowerMapScrollAssetCatalog.new()
	_expect(
		TowerMapScrollAssetCatalog.CLOUD_ASSET_KEYS.size() == EXPECTED_CLOUD_ASSET_COUNT,
		"the bitmap cloud family must declare three motifs plus wall interior and dissolve"
	)
	var expected_world_sizes := {
		TowerMapScrollAssetCatalog.CLOUD_SWIRL_LARGE: Vector2i(260, 160),
		TowerMapScrollAssetCatalog.CLOUD_SWIRL_MEDIUM: Vector2i(196, 112),
		TowerMapScrollAssetCatalog.CLOUD_WISP: Vector2i(152, 64),
		TowerMapScrollAssetCatalog.CLOUD_WALL_INTERIOR: Vector2i(692, 320),
		TowerMapScrollAssetCatalog.CLOUD_WALL_DISSOLVE: Vector2i(692, 224),
	}
	var expected_texture_sizes := {
		TowerMapScrollAssetCatalog.CLOUD_SWIRL_LARGE: Vector2i(1040, 640),
		TowerMapScrollAssetCatalog.CLOUD_SWIRL_MEDIUM: Vector2i(784, 448),
		TowerMapScrollAssetCatalog.CLOUD_WISP: Vector2i(608, 256),
		TowerMapScrollAssetCatalog.CLOUD_WALL_INTERIOR: Vector2i(2768, 1280),
		TowerMapScrollAssetCatalog.CLOUD_WALL_DISSOLVE: Vector2i(2768, 896),
	}
	for asset_key in TowerMapScrollAssetCatalog.CLOUD_ASSET_KEYS:
		var path := catalog.resolve_declared_path(asset_key)
		_expect(path.ends_with("_imagegen_v1_x4.png"), "%s must bind the approved versioned imagegen bitmap" % asset_key)
		_expect(ResourceLoader.exists(path, "Texture2D"), "%s must own an imported Texture2D" % asset_key)
		_expect(catalog.get_expected_size(asset_key) == expected_world_sizes[asset_key], "%s must preserve its authored world size" % asset_key)
		_expect(catalog.get_expected_texture_size(asset_key) == expected_texture_sizes[asset_key], "%s must preserve exact x4 texture density" % asset_key)
		var image := Image.new()
		var image_error := image.load_png_from_buffer(
			FileAccess.get_file_as_bytes(path)
		)
		_expect(image_error == OK and not image.is_empty(), "%s source bitmap must decode" % asset_key)
		if image_error == OK and not image.is_empty():
			if asset_key == TowerMapScrollAssetCatalog.CLOUD_WALL_INTERIOR:
				_expect(
					image.detect_alpha() == Image.ALPHA_NONE,
					"the wall interior must remain an opaque concealment core"
				)
			else:
				_expect(
					image.detect_alpha() != Image.ALPHA_NONE,
					"%s must retain soft source alpha" % asset_key
				)
		var import_source := FileAccess.get_file_as_string(path + ".import")
		_expect(import_source.find("compress/mode=2") >= 0, "%s must use offline VRAM compression" % asset_key)
		_expect(import_source.find("compress/high_quality=true") >= 0, "%s must use high-quality VRAM compression" % asset_key)
		_expect(import_source.find("mipmaps/generate=true") >= 0, "%s must generate mipmaps for fit-all downscaling" % asset_key)
	_leg_count += 1


func _verify_band_edge_bleed_art_contract() -> void:
	var manifest_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://assets/sprites/tower/map_scroll/tower_map_scroll_x4_manifest.json"
	))
	_expect(manifest_value is Dictionary, "Z13 tileable-band manifest must decode")
	if not (manifest_value is Dictionary):
		return
	var records_by_output := {}
	for record_value in (manifest_value as Dictionary).get("assets", []):
		if record_value is Dictionary:
			var record := record_value as Dictionary
			records_by_output[str(record.get("output", ""))] = record
	var catalog := TowerMapScrollAssetCatalog.new()
	var band_asset_keys := (
		TowerMapScrollAssetCatalog.HUMAN_BAND_ASSET_KEYS
		+ TowerMapScrollAssetCatalog.IMMORTAL_BAND_ASSET_KEYS
	)
	for asset_key in band_asset_keys:
		var path := catalog.resolve_declared_path(asset_key)
		var output_name := path.get_file()
		var record: Dictionary = records_by_output.get(output_name, {})
		var edge_bleed: Dictionary = record.get("edge_bleed", {})
		var top_world_px := int(edge_bleed.get("top_world_px", 0))
		var bottom_world_px := int(edge_bleed.get("bottom_world_px", 0))
		var texture_scale := int(edge_bleed.get("texture_scale", 0))
		var comparison_texture_rows := int(edge_bleed.get(
			"comparison_texture_rows",
			0
		))
		var lap_world_px := int(edge_bleed.get("lap_world_px", 0))
		var forward_exemplar: Dictionary = edge_bleed.get("forward_exemplar", {})
		var paired_weights: Array = forward_exemplar.get("paired_weights", [])
		var x4_lap_metrics: Dictionary = edge_bleed.get("x4_lap_metrics", {})
		var world_lap_metrics: Dictionary = edge_bleed.get("world_lap_metrics", {})
		var x4_paired: Dictionary = x4_lap_metrics.get("paired", {})
		var world_paired: Dictionary = world_lap_metrics.get("paired", {})
		var improvement: Dictionary = edge_bleed.get(
			"paired_mean_improvement_fraction",
			{}
		)
		var self_similarity: Dictionary = edge_bleed.get("self_similarity", {})
		var x4_similarity: Dictionary = self_similarity.get("x4", {})
		var world_similarity: Dictionary = self_similarity.get("world", {})
		var value_closure: Dictionary = edge_bleed.get("value_closure", {})
		var thresholds: Dictionary = edge_bleed.get("validation_thresholds", {})
		var bright_gutter_guard: Dictionary = edge_bleed.get(
			"bright_gutter_guard",
			{}
		)
		var expected_widths: Vector2i = EXPECTED_BAND_EDGE_BLEED_WORLD_PX.get(
			output_name,
			Vector2i.ZERO
		)
		_expect(
			str(edge_bleed.get("method", "")) == EXPECTED_BAND_TILEABLE_METHOD
			and str(edge_bleed.get("base_method", ""))
				== EXPECTED_BAND_TILEABLE_BASE_METHOD,
			"%s must pin the Z13 forward-preserving wrap over its Z11 base" % output_name
		)
		_expect(
			str(edge_bleed.get("weight_curve", ""))
				== EXPECTED_BAND_TILEABLE_WEIGHT_CURVE
			and str(edge_bleed.get("rounding", ""))
				== EXPECTED_BAND_TILEABLE_ROUNDING,
			"%s must retain the deterministic forward residual lap" % output_name
		)
		_expect(
			lap_world_px > 0
			and comparison_texture_rows == lap_world_px * texture_scale
			and comparison_texture_rows
				>= EXPECTED_BAND_TILEABLE_MIN_COMPARISON_TEXTURE_ROWS
			and comparison_texture_rows
				<= EXPECTED_BAND_TILEABLE_MAX_COMPARISON_TEXTURE_ROWS,
			"%s must compare the full approved multirow lap, never one texture row"
				% output_name
		)
		_expect(
			int(x4_lap_metrics.get("texture_scale", 0)) == EXPECTED_BAND_TEXTURE_SCALE
			and int(x4_lap_metrics.get("comparison_rows", 0))
				== comparison_texture_rows
			and int(world_lap_metrics.get("texture_scale", 0)) == 1
			and int(world_lap_metrics.get("comparison_rows", 0)) == lap_world_px,
			"%s must pin both x4 and world multirow measurement windows" % output_name
		)
		_expect(
			is_equal_approx(
				float(edge_bleed.get("mean_abs_rgb_delta", -1.0)),
				float(x4_paired.get("mean_abs_rgb_delta", -2.0))
			)
			and is_equal_approx(
				float(edge_bleed.get("p95_abs_rgb_delta", -1.0)),
				float(x4_paired.get("p95_abs_rgb_delta", -2.0))
			)
			and int(edge_bleed.get("max_channel_delta", -1))
				== int(x4_paired.get("max_channel_delta", -2)),
			"%s compatibility wrap metrics must name the full x4 lap" % output_name
		)
		_expect(
			is_equal_approx(
				float((thresholds.get("x4_paired", {}) as Dictionary).get(
					"mean_abs_rgb_delta",
					-1.0
				)),
				EXPECTED_BAND_TILEABLE_X4_PAIRED_MEAN_LIMIT
			)
			and is_equal_approx(
				float((thresholds.get("world_paired", {}) as Dictionary).get(
					"mean_abs_rgb_delta",
					-1.0
				)),
				EXPECTED_BAND_TILEABLE_WORLD_PAIRED_MEAN_LIMIT
			)
			and is_equal_approx(
				float(thresholds.get("x4_seam_row_mean_luma_jump", -1.0)),
				EXPECTED_BAND_TILEABLE_X4_SEAM_LUMA_LIMIT
			)
			and is_equal_approx(
				float(thresholds.get("world_seam_row_mean_luma_jump", -1.0)),
				EXPECTED_BAND_TILEABLE_WORLD_SEAM_LUMA_LIMIT
			)
			and is_equal_approx(
				float(thresholds.get(
					"minimum_paired_mean_improvement_fraction",
					-1.0
				)),
				EXPECTED_BAND_TILEABLE_MIN_IMPROVEMENT_FRACTION
			)
			and is_equal_approx(
				float(thresholds.get("maximum_direct_correlation_excess", -1.0)),
				EXPECTED_BAND_TILEABLE_MAX_DIRECT_CORRELATION_EXCESS
			)
			and is_equal_approx(
				float(thresholds.get("maximum_mirror_correlation_excess", -1.0)),
				EXPECTED_BAND_TILEABLE_MAX_MIRROR_CORRELATION_EXCESS
			),
			"%s must retain the shared Z13 lap, luma, improvement, and similarity limits"
				% output_name
		)
		_expect(
			_metric_triplet_within(
				x4_paired,
				thresholds.get("x4_paired", {}) as Dictionary
			)
			and _metric_triplet_within(
				world_paired,
				thresholds.get("world_paired", {}) as Dictionary
			)
			and _metric_triplet_within(
				x4_lap_metrics.get("seam", {}) as Dictionary,
				thresholds.get("x4_seam", {}) as Dictionary
			)
			and _metric_triplet_within(
				world_lap_metrics.get("seam", {}) as Dictionary,
				thresholds.get("world_seam", {}) as Dictionary
			)
			and _metric_triplet_within(
				x4_lap_metrics.get("derivative", {}) as Dictionary,
				thresholds.get("x4_derivative", {}) as Dictionary
			)
			and _metric_triplet_within(
				world_lap_metrics.get("derivative", {}) as Dictionary,
				thresholds.get("world_derivative", {}) as Dictionary
			),
			"%s multirow paired, seam, and derivative metrics must stay inside bounds"
				% output_name
		)
		_expect(
			_metric_triplet_within(
				x4_lap_metrics.get("body_boundary", {}) as Dictionary,
				thresholds.get("x4_body_boundary", {}) as Dictionary
			)
			and _metric_triplet_within(
				world_lap_metrics.get("body_boundary", {}) as Dictionary,
				thresholds.get("world_body_boundary", {}) as Dictionary
			)
			and _metric_triplet_within(
				x4_lap_metrics.get("body_boundary_derivative", {}) as Dictionary,
				thresholds.get("x4_body_boundary_derivative", {}) as Dictionary
			)
			and _metric_triplet_within(
				world_lap_metrics.get("body_boundary_derivative", {}) as Dictionary,
				thresholds.get("world_body_boundary_derivative", {}) as Dictionary
			),
			"%s lap synthesis must meet the untouched-body boundary smoothly"
				% output_name
		)
		_expect(
			float(x4_lap_metrics.get("seam_row_mean_luma_jump", INF))
				<= EXPECTED_BAND_TILEABLE_X4_SEAM_LUMA_LIMIT
			and float(world_lap_metrics.get("seam_row_mean_luma_jump", INF))
				<= EXPECTED_BAND_TILEABLE_WORLD_SEAM_LUMA_LIMIT
			and float(world_lap_metrics.get("minimum_row_detail", -INF))
				>= EXPECTED_BAND_BODY_DETAIL_THRESHOLD
			and float(improvement.get("x4", -INF))
				>= EXPECTED_BAND_TILEABLE_MIN_IMPROVEMENT_FRACTION
			and float(improvement.get("world", -INF))
				>= EXPECTED_BAND_TILEABLE_MIN_IMPROVEMENT_FRACTION,
			"%s must close world luma while preserving detail and beating Z11"
				% output_name
		)
		_expect(
			float(x4_similarity.get("direct_excess", INF))
				<= EXPECTED_BAND_TILEABLE_MAX_DIRECT_CORRELATION_EXCESS
			and float(world_similarity.get("direct_excess", INF))
				<= EXPECTED_BAND_TILEABLE_MAX_DIRECT_CORRELATION_EXCESS
			and float(x4_similarity.get("mirror_excess", INF))
				<= EXPECTED_BAND_TILEABLE_MAX_MIRROR_CORRELATION_EXCESS
			and float(world_similarity.get("mirror_excess", INF))
				<= EXPECTED_BAND_TILEABLE_MAX_MIRROR_CORRELATION_EXCESS,
			"%s residual ink must remain below direct and mirror repetition excess limits"
				% output_name
		)
		_expect(
			str(forward_exemplar.get("orientation", "")) == "forward"
			and paired_weights.size() == 2
			and int(paired_weights[0]) == 12
			and int(paired_weights[1]) == 1
			and int(forward_exemplar.get("source_world_row", -1)) >= 0
			and int(forward_exemplar.get("bridge_world_px", 0))
				== top_world_px + bottom_world_px
			and int(forward_exemplar.get("lap_world_px", 0)) == lap_world_px
			and str(forward_exemplar.get("endpoint_correction", ""))
				== "additive_integer_smoothstep_residual",
			"%s must pin one forward exemplar without reflection or rewind" % output_name
		)
		_expect(
			str(value_closure.get("method", ""))
				== EXPECTED_BAND_TILEABLE_VALUE_CLOSURE_METHOD
			and int(value_closure.get("texture_rows_per_side", 0)) == 8
			and int(value_closure.get("x4_endpoint_texture_rows_per_side", 0)) == 1
			and int(value_closure.get("world_inner_texture_rows_per_side", 0)) == 7
			and bool(value_closure.get(
				"world_inner_excludes_x4_endpoint_rows",
				false
			))
			and is_equal_approx(
				float(value_closure.get("after_x4_seam_row_mean_luma_jump", INF)),
				float(x4_lap_metrics.get("seam_row_mean_luma_jump", -INF))
			)
			and is_equal_approx(
				float(value_closure.get("after_world_seam_row_mean_luma_jump", INF)),
				float(world_lap_metrics.get("seam_row_mean_luma_jump", -INF))
			)
			and is_equal_approx(
				float(value_closure.get("maximum_x4_seam_row_mean_luma_jump", -1.0)),
				EXPECTED_BAND_TILEABLE_X4_SEAM_LUMA_LIMIT
			)
			and is_equal_approx(
				float(value_closure.get("maximum_world_seam_row_mean_luma_jump", -1.0)),
				EXPECTED_BAND_TILEABLE_WORLD_SEAM_LUMA_LIMIT
			)
			and float(value_closure.get(
				"before_x4_endpoint_seam_row_mean_luma_jump",
				-INF
			)) > float(value_closure.get(
				"after_x4_endpoint_seam_row_mean_luma_jump",
				INF
			))
			and float(value_closure.get("before_world_seam_row_mean_luma_jump", -INF))
				> float(value_closure.get("after_world_seam_row_mean_luma_jump", INF))
			and value_closure.get("render_proxy_source_scales", [])
				== ["x4", "x4_to_world_lanczos"]
			and str(value_closure.get("render_proxy_boundary_rows", ""))
				== "last_then_first_at_each_source_scale"
			and str(value_closure.get("projected_boundary_snap", "")) == "round"
			and bool(value_closure.get("projected_snap_invariant", false)),
			"%s must pin independent x4-endpoint and inner-world luma closure"
				% output_name
		)
		_expect(
			str(bright_gutter_guard.get("method", ""))
				== EXPECTED_BAND_BRIGHT_GUTTER_GUARD_METHOD
			and int(bright_gutter_guard.get("search_radius_world_px", -1))
				== EXPECTED_BAND_BRIGHT_GUTTER_SEARCH_RADIUS_WORLD_PX
			and int(bright_gutter_guard.get("minimum_run_world_px", -1))
				== EXPECTED_BAND_BRIGHT_GUTTER_MINIMUM_RUN_WORLD_PX
			and is_equal_approx(
				float(bright_gutter_guard.get("luma_threshold", -1.0)),
				EXPECTED_BAND_BODY_LUMA_THRESHOLD
			)
			and is_equal_approx(
				float(bright_gutter_guard.get("detail_threshold", -1.0)),
				EXPECTED_BAND_BODY_DETAIL_THRESHOLD
			)
			and is_equal_approx(
				float(bright_gutter_guard.get("target_luma", -1.0)),
				EXPECTED_BAND_BRIGHT_GUTTER_TARGET_LUMA
			)
			and int(bright_gutter_guard.get("maximum_run_world_px", -1)) == 0,
			"%s must retain the zero-pixel bright-gutter edge guard" % output_name
		)
		_expect(
			texture_scale == EXPECTED_BAND_TEXTURE_SCALE,
			"%s edge bleed must retain x4 density" % output_name
		)
		_expect(
			Vector2i(top_world_px, bottom_world_px) == expected_widths,
			"%s must retain the measured top/bottom gutter widths" % output_name
		)
		_expect(
			is_equal_approx(
				float(edge_bleed.get("body_luma_threshold", -1.0)),
				EXPECTED_BAND_BODY_LUMA_THRESHOLD
			)
			and is_equal_approx(
				float(edge_bleed.get("body_detail_threshold", -1.0)),
				EXPECTED_BAND_BODY_DETAIL_THRESHOLD
			),
			"%s must retain the measured body-boundary thresholds" % output_name
		)
		var edge_mist_bake: Dictionary = record.get("edge_mist_bake", {})
		_expect(
			str(edge_bleed.get("original_output_sha256", "")).length() == 64
			and str(edge_bleed.get("z11_output_sha256", "")).length() == 64
			and str(edge_bleed.get("z11_rgb_sha256", "")).length() == 64
			and str(edge_bleed.get("original_output_sha256", ""))
				!= str(edge_bleed.get("z11_output_sha256", ""))
			and str(edge_bleed.get("z11_output_sha256", ""))
				!= str(record.get("output_sha256", "")),
			"%s must retain distinct pre-Z11 and Z11 output-hash provenance" % output_name
		)
		_expect(
			str(edge_bleed.get("wrapped_rgb_sha256", "")).length() == 64
			and str(edge_mist_bake.get("base_rgb_sha256", ""))
				== str(edge_bleed.get("wrapped_rgb_sha256", ""))
			and str(edge_mist_bake.get("base_output_sha256", "")).length() == 64,
			"%s Z13-c must retain the wrapped Z13 edge-bleed result as pinned parent provenance"
				% output_name
		)
	var common_path := catalog.resolve_declared_path(TowerMapScrollAssetCatalog.COMMON_HANJI_PAPER)
	var common := Image.new()
	var common_error := common.load_png_from_buffer(FileAccess.get_file_as_bytes(common_path))
	_expect(common_error == OK and not common.is_empty(), "common hanji paper must decode for edge comparison")
	if common_error == OK and not common.is_empty():
		var sample_rows := 8 * EXPECTED_BAND_TEXTURE_SCALE
		var common_top_edge := common.get_region(Rect2i(0, 0, common.get_width(), sample_rows))
		var common_top_inner := common.get_region(Rect2i(0, sample_rows, common.get_width(), sample_rows))
		var common_bottom_edge := common.get_region(Rect2i(
			0,
			common.get_height() - sample_rows,
			common.get_width(),
			sample_rows
		))
		var common_bottom_inner := common.get_region(Rect2i(
			0,
			common.get_height() - sample_rows * 2,
			common.get_width(),
			sample_rows
		))
		_expect(
			absf(_mean_image_luma_8bit(common_top_edge) - _mean_image_luma_8bit(common_top_inner)) <= 2.0
			and absf(_mean_image_luma_8bit(common_bottom_edge) - _mean_image_luma_8bit(common_bottom_inner)) <= 2.0,
			"common hanji paper must remain a flat paper control, not a band-art gutter target"
		)
	_leg_count += 1


func _verify_band_edge_mist_bake_art_contract() -> void:
	var manifest_path := (
		"res://assets/sprites/tower/map_scroll/tower_map_scroll_x4_manifest.json"
	)
	_expect(
		_sha256(FileAccess.get_file_as_bytes(manifest_path))
			== EXPECTED_BAND_MIST_MANIFEST_SHA256,
		"Z13-c edge-mist manifest bytes must remain reproducibly pinned"
	)
	var manifest_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		manifest_path
	))
	_expect(manifest_value is Dictionary, "Z13-c edge-mist manifest must decode")
	if not (manifest_value is Dictionary):
		return
	var records_by_output: Dictionary = {}
	for record_value in (manifest_value as Dictionary).get("assets", []):
		if record_value is Dictionary:
			var record := record_value as Dictionary
			records_by_output[str(record.get("output", ""))] = record
	for expected_output in EXPECTED_BAND_MIST_OUTPUT_ORDER:
		_expect(
			records_by_output.has(str(expected_output)),
			"Z13-c manifest must retain %s" % str(expected_output)
		)

	var source_path := "res://../" + EXPECTED_BAND_MIST_SOURCE
	var source_image := Image.new()
	var source_error := source_image.load_png_from_buffer(
		FileAccess.get_file_as_bytes(source_path)
	)
	var source_ready := (
		FileAccess.file_exists(source_path)
		and source_error == OK
		and not source_image.is_empty()
		and source_image.get_size() == EXPECTED_BAND_MIST_SOURCE_SIZE
		and source_image.get_format() == Image.FORMAT_RGBA8
	)
	_expect(
		source_ready
		and _sha256(FileAccess.get_file_as_bytes(source_path))
			== EXPECTED_BAND_MIST_SOURCE_SHA256,
		"Z13-c must retain the approved RGBA yeouidu cloud bitmap and SHA-256"
	)

	var catalog := TowerMapScrollAssetCatalog.new()
	var band_asset_keys := (
		TowerMapScrollAssetCatalog.HUMAN_BAND_ASSET_KEYS
		+ TowerMapScrollAssetCatalog.IMMORTAL_BAND_ASSET_KEYS
	)
	var unique_edge_rects: Dictionary = {}
	var unique_edge_crop_hashes: Dictionary = {}
	var rejected_x4_count := 0
	var rejected_world_count := 0
	var vertical_smear_red_count := 0
	var reverse_mirror_gate_red_count := 0
	var independent_reverse_red_count := 0
	var parallel_band_red_count := 0
	var unique_shape_seeds: Dictionary = {}
	var unique_shape_phase_signatures: Dictionary = {}
	for asset_key in band_asset_keys:
		var path := catalog.resolve_declared_path(asset_key)
		var output_name := path.get_file()
		var record: Dictionary = records_by_output.get(output_name, {})
		var edge_bleed: Dictionary = record.get("edge_bleed", {})
		var contract: Dictionary = record.get("edge_mist_bake", {})
		var strip: Dictionary = contract.get("strip", {})
		var top_crop: Dictionary = contract.get("top_crop", {})
		var bottom_crop: Dictionary = contract.get("bottom_crop", {})
		var tone: Dictionary = contract.get("tone", {})
		var visible_shape_metrics: Dictionary = tone.get("visible_shape_metrics", {})
		var masks: Dictionary = contract.get("mask_metrics", {})
		var metrics: Dictionary = contract.get("metrics", {})
		var shape_modulation: Dictionary = contract.get("shape_modulation", {})
		var shape_edges: Dictionary = shape_modulation.get("edges", {})
		var field_construction: Dictionary = shape_modulation.get(
			"field_construction",
			{}
		)
		var pigment_warp: Dictionary = shape_modulation.get("pigment_warp", {})
		var cross_edge_metrics: Dictionary = shape_modulation.get(
			"cross_edge_metrics",
			{}
		)
		var parallel_counterproof: Dictionary = shape_modulation.get(
			"parallel_band_counterproof",
			{}
		)
		var reverse_counterproof: Dictionary = contract.get(
			"reverse_counterproof",
			{}
		)
		var rejected: Dictionary = contract.get("rejected_z13_counterproof", {})
		var thresholds: Dictionary = contract.get("validation_thresholds", {})
		var shared_seam: Dictionary = contract.get("shared_textured_seam", {})
		var guaranteed_coverage: Array = contract.get(
			"guaranteed_coverage_subzone_world_px",
			[]
		)
		var active_ragged_fade: Array = contract.get(
			"active_ragged_fade_world_px",
			[]
		)
		var expected_spec: Dictionary = EXPECTED_BAND_MIST_STRIPS.get(output_name, {})
		var expected_strip_rect: Rect2i = expected_spec.get(
			"rect",
			Rect2i(-1, -1, -1, -1)
		)
		var expected_gain := float(expected_spec.get("detail_gain", -1.0))
		var expected_terrain_bridge_detail_gain := float(expected_spec.get(
			"terrain_bridge_detail_gain",
			-1.0
		))
		var expected_source_sampling_bias_world_px := float(expected_spec.get(
			"source_sampling_bias_world_px",
			INF
		))
		var expected_source_sampling_bias_texture_px := int(round(
			expected_source_sampling_bias_world_px * EXPECTED_BAND_TEXTURE_SCALE
		))
		var expected_bottom_rect := Rect2i(
			expected_strip_rect.position,
			Vector2i(expected_strip_rect.size.x, EXPECTED_BAND_MIST_EDGE_PATCH_HEIGHT)
		)
		var expected_top_rect := Rect2i(
			expected_strip_rect.position + Vector2i(
				0,
				EXPECTED_BAND_MIST_EDGE_PATCH_HEIGHT - 1
			),
			Vector2i(expected_strip_rect.size.x, EXPECTED_BAND_MIST_EDGE_PATCH_HEIGHT)
		)
		var strip_rect := _manifest_rect2i(strip.get("rect", []))
		var top_rect := _manifest_rect2i(top_crop.get("rect", []))
		var bottom_rect := _manifest_rect2i(bottom_crop.get("rect", []))
		var horizontal_scale := float(strip.get("horizontal_scale", -1.0))

		_expect(
			_mist_manifest_contract_is_v3(contract),
			"%s must retain the exact Z13-e v3 manifest schema" % output_name
		)
		_expect(
			str(contract.get("method", "")) == EXPECTED_BAND_MIST_METHOD
			and str(contract.get("base_method", "")) == EXPECTED_BAND_TILEABLE_METHOD
			and str(contract.get("base_commit", ""))
				== EXPECTED_BAND_MIST_BASE_COMMIT,
			"%s must own a separate v3 landform mist bake over the pinned Z13 wrap"
				% output_name
		)
		_expect(
			str(contract.get("source", "")) == EXPECTED_BAND_MIST_SOURCE
			and str(contract.get("source_sha256", ""))
				== EXPECTED_BAND_MIST_SOURCE_SHA256
			and str(contract.get("source_approval_commit", ""))
				== EXPECTED_BAND_MIST_SOURCE_COMMIT
			and int(contract.get("fixed_seed", -1)) == EXPECTED_BAND_MIST_FIXED_SEED
			and str(contract.get("fixed_seed_role", ""))
				== "deterministic_low_frequency_shape_and_literal_table_version"
			and str(contract.get("fixed_seed_strip_table_sha256", ""))
				== EXPECTED_BAND_MIST_FIXED_SEED_STRIP_TABLE_SHA256
			and str(contract.get("fixed_seed_shape_table_sha256", ""))
				== EXPECTED_BAND_MIST_FIXED_SEED_SHAPE_TABLE_SHA256
			and str(contract.get("crop_selection_method", ""))
				== "fixed_seed_literal_strip_with_margin_macro_warp_v3",
			"%s must pin the approved cloud source and both fixed-seed tables"
				% output_name
		)
		var meander_source: Dictionary = strip.get("meander_source", {})
		var meander_rect := _manifest_rect2i(meander_source.get("rect", []))
		var effective_center_rect := _manifest_rect2i(
			meander_source.get("effective_center_rect", [])
		)
		_expect(
			strip_rect == expected_strip_rect
			and strip_rect.size.y == EXPECTED_BAND_MIST_STRIP_HEIGHT
			and _rect_inside_size(strip_rect, EXPECTED_BAND_MIST_SOURCE_SIZE)
			and horizontal_scale >= 2.0
			and horizontal_scale <= 3.0
			and is_equal_approx(
				horizontal_scale,
				float(EXPECTED_BAND_MIST_OUTPUT_SIZE.x) / float(strip_rect.size.x)
			)
			and is_equal_approx(float(strip.get("vertical_scale", -1.0)), 1.0)
			and is_equal_approx(float(contract.get("vertical_scale", -1.0)), 1.0)
			and is_equal_approx(float(strip.get("detail_gain", -1.0)), expected_gain)
			and int(strip.get("shared_textured_row", -1))
				== EXPECTED_BAND_MIST_EDGE_PATCH_HEIGHT - 1,
			"%s must preserve one whole 279-row logical strip inside the macro-warp crop"
				% output_name
		)
		_expect(
			int(meander_source.get("margin_world_px", -1))
				== EXPECTED_BAND_MIST_MEANDER_SOURCE_MARGIN_WORLD_PX
			and is_equal_approx(
				float(meander_source.get("source_sampling_bias_world_px", INF)),
				expected_source_sampling_bias_world_px
			)
			and int(meander_source.get("source_sampling_bias_texture_px", 9999))
				== expected_source_sampling_bias_texture_px
			and meander_rect.position.x == strip_rect.position.x
			and meander_rect.position.y
				== (
					strip_rect.position.y
					- EXPECTED_BAND_MIST_MEANDER_SOURCE_MARGIN_WORLD_PX
						* EXPECTED_BAND_TEXTURE_SCALE
					+ expected_source_sampling_bias_texture_px
				)
			and meander_rect.size.x == strip_rect.size.x
			and meander_rect.size.y
				== strip_rect.size.y + 26 * EXPECTED_BAND_TEXTURE_SCALE
			and _rect_inside_size(meander_rect, EXPECTED_BAND_MIST_SOURCE_SIZE)
			and effective_center_rect.position
				== strip_rect.position + Vector2i(
					0,
					expected_source_sampling_bias_texture_px
				)
			and effective_center_rect.size == strip_rect.size
			and _rect_inside_size(effective_center_rect, EXPECTED_BAND_MIST_SOURCE_SIZE)
			and str(meander_source.get(
				"effective_center_crop_rgba_sha256",
				""
			)).length() == 64
			and float(meander_source.get(
				"effective_center_alpha_weighted_luma_std",
				-1.0
			)) > 0.0
			and str(meander_source.get("crop_rgba_sha256", "")).length() == 64
			and str(meander_source.get(
				"resized_blurred_rgba_sha256",
				""
			)).length() == 64,
			"%s meander source must retain a 13px vertical margin without edge synthesis"
				% output_name
		)
		_expect(
			top_rect == expected_top_rect
			and bottom_rect == expected_bottom_rect
			and top_crop == strip.get("top_crop", {})
			and bottom_crop == strip.get("bottom_crop", {})
			and _rect_inside_size(top_rect, EXPECTED_BAND_MIST_SOURCE_SIZE)
			and _rect_inside_size(bottom_rect, EXPECTED_BAND_MIST_SOURCE_SIZE),
			"%s top/bottom crops must be the two overlapping 140-row strip halves"
				% output_name
		)
		for edge_rect in [bottom_rect, top_rect]:
			unique_edge_rects[_mist_rect_key(edge_rect)] = true
		for crop_value in [bottom_crop, top_crop]:
			var crop := crop_value as Dictionary
			var crop_sha := str(crop.get("rgba_sha256", ""))
			var resized_sha := str(crop.get("resized_blurred_rgba_sha256", ""))
			_expect(
				crop_sha.length() == 64 and resized_sha.length() == 64,
				"%s every source crop and whole-patch transform must retain SHA-256"
					% output_name
			)
			unique_edge_crop_hashes[crop_sha] = true
		if (
			source_ready
			and _rect_inside_size(strip_rect, EXPECTED_BAND_MIST_SOURCE_SIZE)
			and _rect_inside_size(top_rect, EXPECTED_BAND_MIST_SOURCE_SIZE)
			and _rect_inside_size(bottom_rect, EXPECTED_BAND_MIST_SOURCE_SIZE)
		):
			var source_strip := source_image.get_region(strip_rect)
			var source_top := source_image.get_region(top_rect)
			var source_bottom := source_image.get_region(bottom_rect)
			_expect(
				_sha256(source_strip.get_data())
					== str(strip.get("crop_rgba_sha256", ""))
				and _sha256(source_top.get_data())
					== str(top_crop.get("rgba_sha256", ""))
				and _sha256(source_bottom.get_data())
					== str(bottom_crop.get("rgba_sha256", "")),
				"%s decoded source strip/top/bottom bytes must match provenance"
					% output_name
			)

		_expect(
			int(contract.get("texture_scale", 0)) == EXPECTED_BAND_TEXTURE_SCALE
			and int(contract.get("core_world_px", 0))
				== EXPECTED_BAND_MIST_CORE_WORLD_PX
			and int(contract.get("feather_world_px", 0))
				== EXPECTED_BAND_MIST_FEATHER_WORLD_PX
			and int(contract.get("covered_prior_fill_through_world_px", 0))
				== EXPECTED_BAND_MIST_FILL_COVER_WORLD_PX
			and int(contract.get("edge_zone_world_px", 0))
				== EXPECTED_BAND_MIST_EDGE_ZONE_WORLD_PX
			and guaranteed_coverage.size() == 2
			and int(guaranteed_coverage[0]) == EXPECTED_BAND_MIST_CORE_WORLD_PX
			and int(guaranteed_coverage[1]) == EXPECTED_BAND_MIST_FILL_COVER_WORLD_PX
			and active_ragged_fade.size() == 2
			and int(active_ragged_fade[0]) == EXPECTED_BAND_MIST_FILL_COVER_WORLD_PX
			and int(active_ragged_fade[1]) == EXPECTED_BAND_MIST_EDGE_ZONE_WORLD_PX,
			"%s must pin core, full-cover, irregular-fade, and immutable-body zones"
				% output_name
		)
		_expect(
			not bool(contract.get("mirror", true))
			and not bool(contract.get("reverse", true))
			and not bool(contract.get("row_equalization", true))
			and not bool(contract.get("column_equalization", true))
			and not bool(contract.get("endpoint_equalization", true))
			and not bool(contract.get("one_pixel_column_operations", true))
			and is_equal_approx(
				float(contract.get("gaussian_blur_texture_px", -1.0)),
				EXPECTED_BAND_MIST_PATCH_BLUR_TEXTURE_PX
			)
			and str(contract.get("feather_mask", ""))
				== "fixed_seed_low_frequency_landform_feather_v3",
			"%s must reject mirror/row/column forcing and retain low-frequency feathering"
				% output_name
		)
		_expect(
			str(shape_modulation.get("method", ""))
				== "fixed_seed_coarse_mesh_landform_mist_shape_v2"
			and str(shape_modulation.get("parameter_table_sha256", ""))
				== EXPECTED_BAND_MIST_FIXED_SEED_SHAPE_TABLE_SHA256
			and is_equal_approx(
				float(field_construction.get("primary_cycles", -1.0)),
				1.0
			)
			and is_equal_approx(
				float(field_construction.get("secondary_cycles", -1.0)),
				2.0
			)
			and float(field_construction.get("minimum_wavelength_world_px", -1.0))
				>= EXPECTED_BAND_MIST_MIN_FIELD_WAVELENGTH_WORLD_PX
			and float(field_construction.get(
				"minimum_horizontal_control_span_world_px",
				-1.0
			)) >= EXPECTED_BAND_MIST_MIN_HORIZONTAL_CONTROL_SPAN_WORLD_PX
			and float(field_construction.get(
				"minimum_vertical_control_span_world_px",
				-1.0
			)) >= EXPECTED_BAND_MIST_MIN_VERTICAL_CONTROL_SPAN_WORLD_PX
			and int(field_construction.get("horizontal_control_cells", -1))
				== EXPECTED_BAND_MIST_HORIZONTAL_CONTROL_CELLS
			and int(field_construction.get("edge_vertical_control_cells", -1))
				== EXPECTED_BAND_MIST_EDGE_VERTICAL_CONTROL_CELLS
			and int(field_construction.get("periodic_halo_control_cells", -1))
				== EXPECTED_BAND_MIST_PERIODIC_HALO_CONTROL_CELLS
			and str(field_construction.get("rasterization", ""))
				== "pillow_bicubic_from_coarse_control_plane"
			and not bool(field_construction.get("one_pixel_column_operations", true))
			and not bool(field_construction.get("per_column_adjustment", true)),
			"%s shape fields must be fixed-seed, low-frequency, and vectorized"
				% output_name
		)
		_expect(
			str(pigment_warp.get("method", ""))
				== "coarse_16x8_world_px_pillow_mesh_shared_row_v2"
			and int(pigment_warp.get("margin_world_px", -1))
				== EXPECTED_BAND_MIST_MEANDER_SOURCE_MARGIN_WORLD_PX
			and int(pigment_warp.get("horizontal_control_cells", -1))
				== EXPECTED_BAND_MIST_HORIZONTAL_CONTROL_CELLS
			and int(pigment_warp.get("vertical_control_cells", -1))
				== EXPECTED_BAND_MIST_EDGE_VERTICAL_CONTROL_CELLS * 2
			and int(pigment_warp.get("minimum_horizontal_control_span_texture_px", -1))
				>= int(
					EXPECTED_BAND_MIST_MIN_HORIZONTAL_CONTROL_SPAN_WORLD_PX
					* EXPECTED_BAND_TEXTURE_SCALE
				)
			and int(pigment_warp.get("minimum_vertical_control_span_texture_px", -1))
				>= int(
					EXPECTED_BAND_MIST_MIN_VERTICAL_CONTROL_SPAN_WORLD_PX
					* EXPECTED_BAND_TEXTURE_SCALE
				)
			and int(pigment_warp.get("shared_logical_row", -1))
				== EXPECTED_BAND_MIST_EDGE_PATCH_HEIGHT - 1
			and is_equal_approx(
				float(pigment_warp.get(
					"shared_seam_residual_amplitude_world_px",
					-1.0
				)),
				EXPECTED_BAND_MIST_SHARED_SEAM_RESIDUAL_AMPLITUDE_WORLD_PX
			)
			and float(pigment_warp.get(
				"shared_row_displacement_p95_half_range_world_px",
				-1.0
			)) >= EXPECTED_BAND_MIST_MIN_SHARED_SEAM_HALF_RANGE_WORLD_PX
			and float(pigment_warp.get(
				"shared_row_displacement_maximum_absolute_world_px",
				-1.0
			)) > 0.0
			and absf(float(pigment_warp.get("source_sampling_bias_world_px", INF)))
				<= EXPECTED_BAND_MIST_MAX_SOURCE_SAMPLING_BIAS_WORLD_PX
			and is_equal_approx(
				float(pigment_warp.get("source_sampling_bias_world_px", INF)),
				expected_source_sampling_bias_world_px
			)
			and is_equal_approx(
				float(pigment_warp.get("source_sampling_bias_texture_px", INF)),
				float(expected_source_sampling_bias_texture_px)
			)
			and str(pigment_warp.get("sampling_offset_sign", ""))
				== "positive_source_y_moves_visible_pigment_upward"
			and float(pigment_warp.get("minimum_vertical_jacobian", -INF))
				>= EXPECTED_BAND_MIST_MIN_WARP_VERTICAL_JACOBIAN
			and not bool(pigment_warp.get("one_pixel_column_operations", true))
			and not bool(pigment_warp.get("per_column_adjustment", true))
			and str(pigment_warp.get("warped_rgba_sha256", "")).length() == 64,
			"%s macro pigment warp must preserve C0 and a positive vertical Jacobian"
				% output_name
		)
		for edge_name in ["top", "bottom"]:
			var edge_shape: Dictionary = shape_edges.get(edge_name, {})
			_expect(
				_mist_edge_shape_is_within_contract(edge_name, edge_shape),
				"%s %s edge must pass thickness/meander/thinning/terrain/full-cover gates"
					% [output_name, edge_name]
			)
			unique_shape_seeds[int(edge_shape.get("deterministic_seed", -1))] = true
			var phase_signature := "%.12f|%.12f|%.12f|%.12f|%.12f" % [
				float(edge_shape.get("thickness_phase_rad", -1.0)),
				float(edge_shape.get("thickness_secondary_phase_rad", -1.0)),
				float(edge_shape.get("meander_phase_rad", -1.0)),
				float(edge_shape.get("meander_secondary_phase_rad", -1.0)),
				float(edge_shape.get("terrain_phase_rad", -1.0)),
			]
			unique_shape_phase_signatures[phase_signature] = true
		_expect(
			float(cross_edge_metrics.get("thickness_primary_phase_delta_rad", -1.0))
				>= EXPECTED_BAND_MIST_MIN_TOP_BOTTOM_PHASE_DELTA_RAD
			and float(cross_edge_metrics.get("meander_primary_phase_delta_rad", -1.0))
				>= EXPECTED_BAND_MIST_MIN_TOP_BOTTOM_PHASE_DELTA_RAD
			and float(cross_edge_metrics.get("minimum_primary_phase_delta_rad", -1.0))
				>= EXPECTED_BAND_MIST_MIN_TOP_BOTTOM_PHASE_DELTA_RAD
			and float(cross_edge_metrics.get("thinning_strong_overlap_ratio", INF))
				<= EXPECTED_BAND_MIST_MAX_THINNING_STRONG_OVERLAP_RATIO
			and float(cross_edge_metrics.get("actual_front_absolute_correlation", INF))
				<= EXPECTED_BAND_MIST_MAX_ACTUAL_FRONT_CORRELATION
			and bool(cross_edge_metrics.get("parameter_signatures_unique", false)),
			"%s top/bottom must use distinct phases and non-overlapping thinning windows"
				% output_name
		)
		var parallel_is_red := _mist_parallel_band_counterproof_is_red(
			parallel_counterproof
		)
		_expect(
			parallel_is_red,
			"%s disabled parallel-band construction must turn the shape gate RED"
				% output_name
		)
		if parallel_is_red:
			parallel_band_red_count += 1
		var top_front: Dictionary = masks.get("top_feather_front", {})
		var bottom_front: Dictionary = masks.get("bottom_feather_front", {})
		var top_shape_metrics: Dictionary = (
			shape_edges.get("top", {}) as Dictionary
		).get("metrics", {})
		var bottom_shape_metrics: Dictionary = (
			shape_edges.get("bottom", {}) as Dictionary
		).get("metrics", {})
		_expect(
			float(masks.get("core_minimum", -1.0))
				>= EXPECTED_BAND_MIST_MIN_CORE_OPACITY
			and float(masks.get("core_maximum", INF))
				<= EXPECTED_BAND_MIST_MAX_CORE_OPACITY
			and float(masks.get("minimum_opacity_through_world_px_26", -1.0))
				>= EXPECTED_BAND_MIST_MIN_CORE_OPACITY
			and float(masks.get("feather_column_profile_residual_std", -1.0))
				>= EXPECTED_BAND_MIST_MIN_FEATHER_HORIZONTAL_RESIDUAL_STD
			and float(top_front.get("depth_std_texture_px", -1.0))
				>= EXPECTED_BAND_MIST_MIN_FEATHER_FRONT_STD_TEXTURE_PX
			and float(bottom_front.get("depth_std_texture_px", -1.0))
				>= EXPECTED_BAND_MIST_MIN_FEATHER_FRONT_STD_TEXTURE_PX
			and float(top_front.get("p95_half_range_world_px", -1.0))
				>= EXPECTED_BAND_MIST_MIN_ACTUAL_FRONT_HALF_RANGE_WORLD_PX
			and float(bottom_front.get("p95_half_range_world_px", -1.0))
				>= EXPECTED_BAND_MIST_MIN_ACTUAL_FRONT_HALF_RANGE_WORLD_PX
			and is_equal_approx(
				float(top_front.get("p05_depth_texture_px", INF)),
				float(top_shape_metrics.get("actual_front_p05_depth_texture_px", -INF))
			)
			and is_equal_approx(
				float(bottom_front.get("p95_depth_texture_px", INF)),
				float(bottom_shape_metrics.get("actual_front_p95_depth_texture_px", -INF))
			)
			and str(masks.get("top_mask_float32_sha256", "")).length() == 64
			and str(masks.get("bottom_mask_float32_sha256", "")).length() == 64,
			"%s must keep the dense 26px cover and torn brush-front variance"
				% output_name
		)
		_expect(
			float(tone.get("mist_tone_maximum_luma", INF))
				<= EXPECTED_BAND_MIST_MAX_TONE_LUMA + 0.0001
			and float(tone.get("mist_to_source_contrast_ratio", INF))
				<= EXPECTED_BAND_MIST_MAX_TONE_CONTRAST_RATIO
			and is_equal_approx(float(tone.get("detail_gain", -1.0)), expected_gain)
			and float(tone.get("top_opacity_weighted_detail_mean", -1.0)) > 0.0
			and float(tone.get("bottom_opacity_weighted_detail_mean", -1.0)) > 0.0
			and str(tone.get("detail_model", ""))
				== "immutable_body_bridge_with_meandering_literal_pigment_v3"
			and str(tone.get("edge_offset_profile", ""))
				== "whole_edge_smootherstep_to_zero_at_shared_seam_v1"
			and is_equal_approx(
				float(tone.get("approved_literal_source_alpha_weighted_luma_std", -1.0)),
				float(strip.get("approved_source_alpha_weighted_luma_std", -2.0))
			)
			and is_equal_approx(
				float(tone.get("effective_source_alpha_weighted_luma_std", -1.0)),
				float(meander_source.get(
					"effective_center_alpha_weighted_luma_std",
					-2.0
				))
			)
			and str(tone.get("global_offset_objective", ""))
				== "minimize_maximum_top_bottom_body_luma_delta",
			"%s mist must converge to low-contrast paper-safe tone" % output_name
		)
		_expect(
			_mist_visible_shape_metrics_are_within_contract(
				visible_shape_metrics,
				tone,
				expected_terrain_bridge_detail_gain
			),
			"%s visible mist must independently pass meander, thinning, terrain, and luma gates"
				% output_name
		)
		_expect(
			_mist_thresholds_are_exact(thresholds),
			"%s must pin all Z13-e v3 acceptance thresholds" % output_name
		)
		_expect(
			_mist_manifest_metrics_within_contract(metrics),
			"%s manifest x4/world variance, mirror, luma, and detail metrics must pass"
				% output_name
		)
		var x4_mirror: Dictionary = metrics.get("x4_mirror_correlation", {})
		var world_mirror: Dictionary = metrics.get("world_mirror_correlation", {})
		var manifest_reverse_is_red := (
			_mist_reverse_counterproof_schema_is_exact(reverse_counterproof)
			and str(reverse_counterproof.get("construction", ""))
				== EXPECTED_BAND_MIST_REVERSE_COUNTERFACTUAL_CONSTRUCTION
			and str(reverse_counterproof.get("assignment", ""))
				== EXPECTED_BAND_MIST_REVERSE_COUNTERFACTUAL_ASSIGNMENT
			and not bool(reverse_counterproof.get("production_mirror", true))
			and is_equal_approx(
				float(reverse_counterproof.get(
					"maximum_allowed_mirror_correlation",
					-1.0
				)),
				EXPECTED_BAND_MIST_MAX_MIRROR_CORRELATION
			)
			and is_equal_approx(
				float(reverse_counterproof.get(
					"x4_maximum_absolute_correlation",
					-INF
				)),
				float(x4_mirror.get("mirrored_counterfactual_correlation", INF))
			)
			and is_equal_approx(
				float(reverse_counterproof.get(
					"world_maximum_absolute_correlation",
					-INF
				)),
				float(world_mirror.get("mirrored_counterfactual_correlation", INF))
			)
			and float(reverse_counterproof.get(
				"x4_maximum_absolute_correlation",
				-INF
			)) >= EXPECTED_BAND_MIST_MIN_REVERSED_COUNTERFACTUAL_CORRELATION
			and float(reverse_counterproof.get(
				"world_maximum_absolute_correlation",
				-INF
			)) >= EXPECTED_BAND_MIST_MIN_REVERSED_COUNTERFACTUAL_CORRELATION
			and bool(reverse_counterproof.get("mirror_gate_red", false))
		)
		_expect(
			manifest_reverse_is_red,
			"%s exact reversed-top-as-bottom manifest counterproof must turn both mirror gates RED"
				% output_name
		)
		if manifest_reverse_is_red:
			reverse_mirror_gate_red_count += 1
		if _mist_rejected_z13_scale_is_red(rejected, "x4"):
			rejected_x4_count += 1
		if _mist_rejected_z13_scale_is_red(rejected, "world"):
			rejected_world_count += 1

		_expect(
			str(rejected.get("base_output_sha256", ""))
				== str(EXPECTED_BAND_MIST_BASE_OUTPUT_SHA256.get(output_name, ""))
			and str(rejected.get("base_rgb_sha256", ""))
				== str(EXPECTED_BAND_MIST_BASE_RGB_SHA256.get(output_name, ""))
			and bool(rejected.get("vertical_variance_gate_red", false)),
			"%s rejected Z13 counterproof must bind the exact 4739 parent"
				% output_name
		)
		var immutable_body_rect := _manifest_rect2i(
			contract.get("immutable_body_rect", [])
		)
		_expect(
			str(contract.get("base_output_sha256", ""))
				== str(EXPECTED_BAND_MIST_BASE_OUTPUT_SHA256.get(output_name, ""))
			and str(contract.get("base_rgb_sha256", ""))
				== str(EXPECTED_BAND_MIST_BASE_RGB_SHA256.get(output_name, ""))
			and str(contract.get("base_rgb_sha256", ""))
				== str(edge_bleed.get("wrapped_rgb_sha256", ""))
			and str(contract.get("base_edge_bleed_method", ""))
				== EXPECTED_BAND_TILEABLE_METHOD
			and str(contract.get("base_edge_bleed_sha256", ""))
				== str(EXPECTED_BAND_MIST_BASE_EDGE_BLEED_SHA256.get(output_name, ""))
			and immutable_body_rect == EXPECTED_BAND_MIST_IMMUTABLE_BODY_RECT
			and int(contract.get("outside_35_world_px_changed_pixels", -1)) == 0
			and str(contract.get("immutable_body_rgb_sha256", ""))
				== str(
					EXPECTED_BAND_MIST_IMMUTABLE_BODY_RGB_SHA256.get(
						output_name,
						""
					)
				),
			"%s must preserve the approved Z13 edge_bleed parent and body bytes"
				% output_name
		)

		var image := Image.new()
		var image_error := image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
		var image_ready := (
			image_error == OK
			and not image.is_empty()
			and image.get_size() == EXPECTED_BAND_MIST_OUTPUT_SIZE
			and image.get_format() == Image.FORMAT_RGB8
		)
		_expect(
			image_ready,
			"%s final Z13-c bitmap must decode as exact RGB8 x4 art" % output_name
		)
		if not image_ready:
			continue
		var output_sha := _sha256(FileAccess.get_file_as_bytes(path))
		var rgb_sha := _sha256(image.get_data())
		_expect(
			output_sha == str(record.get("output_sha256", ""))
			and output_sha == str(contract.get("output_sha256", ""))
			and output_sha
				== str(EXPECTED_BAND_MIST_FINAL_OUTPUT_SHA256.get(output_name, ""))
			and rgb_sha == str(contract.get("wrapped_rgb_sha256", ""))
			and rgb_sha == str(EXPECTED_BAND_MIST_FINAL_RGB_SHA256.get(output_name, "")),
			"%s final PNG and decoded RGB hashes must remain pinned" % output_name
		)
		var immutable_body := image.get_region(EXPECTED_BAND_MIST_IMMUTABLE_BODY_RECT)
		_expect(
			_sha256(immutable_body.get_data())
				== str(
					EXPECTED_BAND_MIST_IMMUTABLE_BODY_RGB_SHA256.get(
						output_name,
						""
					)
				),
			"%s decoded rows outside both 35px edge zones must be byte-identical"
				% output_name
		)
		var first_row := image.get_region(Rect2i(0, 0, image.get_width(), 1))
		var last_row := image.get_region(
			Rect2i(0, image.get_height() - 1, image.get_width(), 1)
		)
		_expect(
			bool(shared_seam.get("x4_rows_equal", false))
			and int(shared_seam.get("strip_row", -1))
				== EXPECTED_BAND_MIST_EDGE_PATCH_HEIGHT - 1
			and int(shared_seam.get("top_output_row", -1)) == 0
			and int(shared_seam.get("bottom_output_row", -1))
				== EXPECTED_BAND_MIST_OUTPUT_SIZE.y - 1
			and not bool(shared_seam.get("per_column_adjustment", true))
			and first_row.get_data() == last_row.get_data()
			and _sha256(first_row.get_data())
				== str(shared_seam.get("rgb_sha256", "")),
			"%s butt endpoints must share one natural textured source row"
				% output_name
		)

		var decoded_x4 := _measure_decoded_mist_metrics(
			image,
			EXPECTED_BAND_TEXTURE_SCALE
		)
		var world_image: Image = image.duplicate() as Image
		world_image.resize(
			EXPECTED_BAND_MIST_WORLD_SIZE.x,
			EXPECTED_BAND_MIST_WORLD_SIZE.y,
			Image.INTERPOLATE_LANCZOS
		)
		var decoded_world := _measure_decoded_mist_metrics(world_image, 1)
		_expect(
			_mist_decoded_metrics_within_contract(decoded_x4)
			and _mist_decoded_metrics_within_contract(decoded_world),
			"%s independently decoded x4/world seam metrics must pass"
				% output_name
		)
		var exact_reverse_x4 := _build_exact_reversed_top_as_bottom_counterfactual(
			image,
			EXPECTED_BAND_TEXTURE_SCALE
		)
		var exact_reverse_world: Image = exact_reverse_x4.duplicate() as Image
		exact_reverse_world.resize(
			EXPECTED_BAND_MIST_WORLD_SIZE.x,
			EXPECTED_BAND_MIST_WORLD_SIZE.y,
			Image.INTERPOLATE_LANCZOS
		)
		var independent_reverse_x4 := _measure_rec709_butt_mirror_correlation(
			exact_reverse_x4,
			EXPECTED_BAND_TEXTURE_SCALE
		)
		var independent_reverse_world := _measure_rec709_butt_mirror_correlation(
			exact_reverse_world,
			1
		)
		var independent_reverse_is_red := (
			independent_reverse_x4
				>= EXPECTED_BAND_MIST_MIN_REVERSED_COUNTERFACTUAL_CORRELATION
			and independent_reverse_world
				>= EXPECTED_BAND_MIST_MIN_REVERSED_COUNTERFACTUAL_CORRELATION
		)
		_expect(
			independent_reverse_is_red,
			(
				"%s independently constructed exact reverse must turn x4/world mirror gates RED: %.6f/%.6f"
				% [output_name, independent_reverse_x4, independent_reverse_world]
			)
		)
		if independent_reverse_is_red:
			independent_reverse_red_count += 1
		var vertical_smear := _build_vertical_smear_counterfactual(
			image,
			EXPECTED_BAND_TEXTURE_SCALE
		)
		var vertical_smear_metrics := _measure_decoded_smear_variance(
			vertical_smear,
			EXPECTED_BAND_TEXTURE_SCALE,
			decoded_x4.get("column_vertical_variance", {}) as Dictionary
		)
		if _mist_decoded_variance_is_red(vertical_smear_metrics):
			vertical_smear_red_count += 1

	_expect(
		unique_edge_rects.size() == band_asset_keys.size() * 2
		and unique_edge_crop_hashes.size() == band_asset_keys.size() * 2,
		"Z13-c must retain twelve distinct source offsets and crop contents"
	)
	_expect(
		rejected_x4_count == band_asset_keys.size()
		and rejected_world_count == band_asset_keys.size(),
		"the exact rejected Z13 parent must turn all six x4 and world variance gates RED"
	)
	_expect(
		vertical_smear_red_count == band_asset_keys.size(),
		"column-constant seam smear must turn the independent variance gate RED for all six bands"
	)
	_expect(
		reverse_mirror_gate_red_count == band_asset_keys.size()
		and independent_reverse_red_count == band_asset_keys.size(),
		"all six bands must retain manifest and independently measured exact-reverse mirror RED legs"
	)
	_expect(
		parallel_band_red_count == band_asset_keys.size(),
		"all six disabled parallel-band counterproofs must turn the v3 shape gate RED"
	)
	_expect(
		unique_shape_seeds.size() == band_asset_keys.size() * 2
		and unique_shape_phase_signatures.size() == band_asset_keys.size() * 2,
		"all twelve band edges must retain unique deterministic seeds and phase signatures"
	)
	_verify_band_edge_mist_source_contract()
	_leg_count += 1


func _mist_manifest_contract_is_v3(contract: Dictionary) -> bool:
	if not _dictionary_has_exact_keys(contract, [
		"method", "base_method", "base_commit", "texture_scale",
		"source", "source_sha256", "source_approval_commit", "fixed_seed",
		"fixed_seed_role", "fixed_seed_strip_table_sha256",
		"fixed_seed_shape_table_sha256", "crop_selection_method",
		"strip", "top_crop", "bottom_crop", "vertical_scale", "mirror", "reverse",
		"row_equalization", "column_equalization", "endpoint_equalization",
		"one_pixel_column_operations", "gaussian_blur_texture_px", "core_world_px",
		"feather_world_px", "guaranteed_coverage_subzone_world_px",
		"active_ragged_fade_world_px", "edge_zone_world_px",
		"covered_prior_fill_through_world_px", "feather_mask", "shape_modulation", "tone",
		"mask_metrics", "shared_textured_seam", "metrics", "reverse_counterproof",
		"rejected_z13_counterproof", "base_output_sha256", "base_rgb_sha256",
		"base_edge_bleed_method", "base_edge_bleed_sha256", "immutable_body_rect",
		"immutable_body_rgb_sha256", "outside_35_world_px_changed_pixels",
		"validation_thresholds", "wrapped_rgb_sha256", "output_sha256",
	]):
		return false
	var strip: Dictionary = contract.get("strip", {})
	if not _dictionary_has_exact_keys(strip, [
		"selection_method", "rect", "horizontal_scale", "vertical_scale",
		"detail_gain", "crop_rgba_sha256",
		"approved_source_alpha_weighted_luma_std",
		"resized_blurred_rgba_sha256", "meander_source", "bottom_crop", "top_crop",
		"shared_textured_row",
	]):
		return false
	if not _dictionary_has_exact_keys(
		strip.get("meander_source", {}) as Dictionary,
		[
			"rect", "margin_world_px", "source_sampling_bias_world_px",
			"source_sampling_bias_texture_px", "effective_center_rect",
			"effective_center_crop_rgba_sha256",
			"effective_center_alpha_weighted_luma_std", "crop_rgba_sha256",
			"resized_blurred_rgba_sha256",
		]
	):
		return false
	for crop_name in ["top_crop", "bottom_crop"]:
		if not _dictionary_has_exact_keys(
			contract.get(crop_name, {}) as Dictionary,
			["rect", "rgba_sha256", "resized_blurred_rgba_sha256"]
		):
			return false
	if not _dictionary_has_exact_keys(contract.get("tone", {}) as Dictionary, [
		"detail_model", "source_alpha_weighted_mean_luma", "target_body_mean_rgb",
		"target_body_luma", "detail_gain", "bottom_opacity_weighted_detail_mean",
		"top_opacity_weighted_detail_mean", "global_rgb_offset",
		"top_edge_rgb_offset", "bottom_edge_rgb_offset", "edge_offset_profile",
		"global_offset_objective", "composited_luma", "top_composited_luma",
		"bottom_composited_luma", "maximum_edge_body_luma_delta",
		"mist_tone_maximum_luma", "approved_literal_source_alpha_weighted_luma_std",
		"effective_source_alpha_weighted_luma_std",
		"resized_blurred_source_alpha_weighted_luma_std", "mist_tone_luma_std",
		"mist_to_source_contrast_ratio", "visible_shape_metrics",
	]):
		return false
	if not _mist_visible_shape_metrics_schema_is_exact(
		(contract.get("tone", {}) as Dictionary).get("visible_shape_metrics", {})
			as Dictionary
	):
		return false
	if not _mist_shape_modulation_schema_is_exact(
		contract.get("shape_modulation", {}) as Dictionary
	):
		return false
	var masks: Dictionary = contract.get("mask_metrics", {})
	if not _dictionary_has_exact_keys(masks, [
		"core_minimum", "core_maximum", "core_mean",
		"minimum_opacity_through_world_px_26",
		"feather_column_profile_residual_std", "top_feather_front",
		"bottom_feather_front", "top_mask_float32_sha256",
		"bottom_mask_float32_sha256",
	]):
		return false
	for front_name in ["top_feather_front", "bottom_feather_front"]:
		if not _dictionary_has_exact_keys(
			masks.get(front_name, {}) as Dictionary,
			[
				"opacity_threshold", "minimum_depth_texture_px",
				"maximum_depth_texture_px", "depth_std_texture_px",
				"p05_depth_texture_px", "p95_depth_texture_px",
				"p95_half_range_world_px",
			]
		):
			return false
	if not _dictionary_has_exact_keys(
		contract.get("shared_textured_seam", {}) as Dictionary,
		[
			"method", "strip_row", "bottom_output_row", "top_output_row",
			"x4_rows_equal", "rgb_sha256", "per_column_adjustment",
		]
	):
		return false
	if not _dictionary_has_exact_keys(
		contract.get("reverse_counterproof", {}) as Dictionary,
		[
			"construction", "assignment", "production_mirror",
			"maximum_allowed_mirror_correlation",
			"x4_maximum_absolute_correlation",
			"world_maximum_absolute_correlation", "mirror_gate_red",
		]
	):
		return false
	if not _dictionary_has_exact_keys(
		contract.get("rejected_z13_counterproof", {}) as Dictionary,
		[
			"base_output_sha256", "base_rgb_sha256", "metrics",
			"vertical_variance_gate_red",
		]
	):
		return false
	if not _dictionary_has_exact_keys(
		contract.get("validation_thresholds", {}) as Dictionary,
		[
			"minimum_column_vertical_variance_ratio",
			"maximum_column_vertical_variance_ratio",
			"maximum_mirror_correlation", "maximum_seam_body_luma_delta",
			"maximum_mist_tone_luma", "maximum_mist_to_source_contrast_ratio",
			"minimum_core_opacity", "minimum_opacity_through_world_px_26",
			"minimum_ragged_mask_residual_std",
			"minimum_feather_front_std_texture_px",
			"minimum_center_detail_ratio", "maximum_center_detail_ratio",
			"thickness_variation_ratio", "nominal_shaped_feather_world_px",
			"minimum_shaped_feather_world_px", "maximum_shaped_feather_world_px",
			"outer_alpha_guard_world_px",
			"minimum_thickness_p95_half_range_world_px",
			"meander_amplitude_world_px", "minimum_meander_p95_half_range_world_px",
			"minimum_field_wavelength_world_px",
			"minimum_horizontal_control_span_world_px",
			"minimum_vertical_control_span_world_px", "horizontal_control_cells",
			"edge_vertical_control_cells", "periodic_halo_control_cells",
			"meander_source_margin_world_px", "maximum_source_sampling_bias_world_px",
			"shared_seam_residual_amplitude_world_px",
			"minimum_shared_seam_p95_half_range_world_px",
			"minimum_actual_front_p95_half_range_world_px",
			"maximum_actual_front_absolute_correlation",
			"minimum_thinning_width_ratio", "maximum_thinning_width_ratio",
			"thinning_active_window_threshold",
			"minimum_thinning_opacity_multiplier",
			"maximum_thinning_opacity_multiplier",
			"minimum_terrain_attachment_maximum_gain",
			"maximum_terrain_attachment_active_ratio",
			"maximum_terrain_attachment_depth_world_px",
			"terrain_control_quantile", "maximum_terrain_control_active_ratio",
			"minimum_terrain_selected_strength",
			"minimum_terrain_selected_foot_score",
			"minimum_terrain_selected_directional_delta",
			"terrain_selected_control_cells_per_edge",
			"minimum_top_bottom_phase_delta_rad",
			"maximum_thinning_strong_overlap_ratio",
			"minimum_column_integrated_opacity_world_px",
			"minimum_warp_vertical_jacobian",
			"terrain_bridge_anchor_world_px",
			"terrain_bridge_horizontal_control_cells",
			"terrain_bridge_vertical_control_cells",
			"terrain_bridge_reveal_minimum_world_px",
			"terrain_bridge_reveal_maximum_world_px",
			"minimum_terrain_bridge_whole_anchor_detail_gain",
			"maximum_terrain_bridge_whole_anchor_detail_gain",
			"terrain_bridge_composite_luma_bias",
			"visible_pigment_nominal_half_width_world_px",
			"visible_pigment_maximum_mix", "visible_haze_floor",
			"visible_thinning_factor_exponent",
			"visible_thinning_terrain_detail_gain",
			"visible_shared_reference_detail_gain",
			"visible_shape_seam_transition_world_px",
			"visible_edge_veil_transition_world_px",
			"visible_edge_veil_minimum_factor",
			"visible_edge_centerline_divergence_world_px",
			"visible_edge_centerline_maximum_absolute_world_px",
			"visible_centerline_target_p95_half_range_world_px",
			"minimum_visible_centerline_p95_half_range_world_px",
			"maximum_visible_centerline_absolute_world_px",
			"minimum_visible_centerline_valid_ratio",
			"maximum_full_width_pale_run_world_px",
			"maximum_core_local_luma_p95_gain", "maximum_core_local_luma_gain",
			"minimum_thinned_terrain_detail_ratio",
			"minimum_visible_thinned_peak_ink_mix", "minimum_visible_haze_floor",
			"minimum_actual_applied_thinning_active_ratio",
			"maximum_actual_applied_thinning_active_ratio",
			"maximum_actual_applied_thinning_strong_overlap_ratio",
			"maximum_actual_applied_thinning_absolute_correlation",
			"actual_applied_thinning_shared_seam_rows_exact",
			"actual_applied_thinning_signatures_unique",
			"maximum_visible_edge_centerline_residual_absolute_correlation",
			"maximum_visible_edge_veil_absolute_correlation",
			"maximum_visible_edge_veil_p05", "minimum_visible_edge_veil_p95",
			"endpoint_row_mean_jump",
		]
	):
		return false
	return _mist_metric_schema_is_exact(contract.get("metrics", {}) as Dictionary)


func _mist_visible_shape_metrics_schema_is_exact(visible: Dictionary) -> bool:
	if not _dictionary_has_exact_keys(visible, [
		"method", "terrain_bridge", "pigment", "full_width_pale_run_world_px",
		"core_local_luma_positive_gain_p95",
		"core_local_luma_positive_gain_maximum", "terrain_detail_by_edge",
		"minimum_thinned_terrain_detail_ratio",
	]):
		return false
	var terrain: Dictionary = visible.get("terrain_bridge", {})
	if not _dictionary_has_exact_keys(terrain, [
		"anchor_world_px", "horizontal_control_cells", "vertical_control_cells",
		"rasterization", "whole_anchor_detail_gain", "composite_luma_bias",
		"edge_luma_calibration", "shared_reference_rgb_float32_sha256",
		"shared_reference_detail_gain", "reveal_depth_minimum_world_px",
		"reveal_depth_maximum_world_px", "maximum_mix", "rgb_float32_sha256",
		"one_pixel_column_operations", "per_column_adjustment",
	]):
		return false
	var calibration: Dictionary = terrain.get("edge_luma_calibration", {})
	if not _dictionary_has_exact_keys(calibration, ["bottom", "top"]):
		return false
	for edge_name in ["bottom", "top"]:
		if not _dictionary_has_exact_keys(
			calibration.get(edge_name, {}) as Dictionary,
			[
				"source_mean_luma", "literal_target_body_mean_luma",
				"target_body_mean_luma", "whole_edge_rgb_offset",
				"calibrated_mean_luma",
			]
		):
			return false
	var pigment: Dictionary = visible.get("pigment", {})
	if not _dictionary_has_exact_keys(pigment, [
		"centroid_p05_world_px", "centroid_p95_world_px",
		"centroid_p95_half_range_world_px", "centroid_maximum_absolute_world_px",
		"centroid_valid_column_ratio", "nominal_half_width_world_px",
		"thickness_variation_ratio", "edge_centerline_divergence_world_px",
		"edge_centerline_cross_edge_correlation",
		"edge_centerline_cross_edge_absolute_correlation", "haze_floor",
		"maximum_ink_mix",
		"thinning_factor_exponent", "active_profile_gate",
		"edge_veil_transition_world_px", "edge_veil_minimum_factor",
		"edge_veil_top_phase_offset_rad", "edge_veil_cross_edge_correlation",
		"edge_veil_cross_edge_absolute_correlation", "edge_veil_bottom_p05",
		"edge_veil_bottom_p95", "edge_veil_top_p05", "edge_veil_top_p95",
		"thinning_terrain_detail_gain", "minimum_visible_thinning_factor",
		"minimum_thinned_peak_ink_mix", "thinning_windows",
		"ink_mix_float32_sha256", "actual_applied_thinning_profiles",
	]):
		return false
	var actual_thinning: Dictionary = pigment.get(
		"actual_applied_thinning_profiles",
		{}
	)
	if not _dictionary_has_exact_keys(actual_thinning, [
		"construction", "transition_world_px", "shared_seam_rows_exact",
		"bottom", "top", "bottom_top_correlation",
		"bottom_top_absolute_correlation", "strong_overlap_ratio", "signatures_unique",
	]):
		return false
	for edge_name in ["bottom", "top"]:
		if not _dictionary_has_exact_keys(
			actual_thinning.get(edge_name, {}) as Dictionary,
			["active_ratio", "p90", "float32_sha256"]
		):
			return false
	var thinning_windows: Dictionary = pigment.get("thinning_windows", {})
	if not _dictionary_has_exact_keys(thinning_windows, ["bottom", "top"]):
		return false
	for edge_name in ["bottom", "top"]:
		if not _dictionary_has_exact_keys(
			thinning_windows.get(edge_name, {}) as Dictionary,
			[
				"active_ratio", "p90", "maximum", "active_top_quintile_threshold",
				"minimum_active_peak_ink_mix",
			]
		):
			return false
	var terrain_detail: Dictionary = visible.get("terrain_detail_by_edge", {})
	if not _dictionary_has_exact_keys(terrain_detail, ["bottom", "top"]):
		return false
	for edge_name in ["bottom", "top"]:
		if not _dictionary_has_exact_keys(
			terrain_detail.get(edge_name, {}) as Dictionary,
			[
				"active_top_quintile_counterfactual_retention",
				"same_columns_thinning_disabled_retention",
				"enabled_to_disabled_ratio",
			]
		):
			return false
	return true


func _mist_visible_shape_metrics_are_within_contract(
	visible: Dictionary,
	tone: Dictionary,
	expected_terrain_bridge_detail_gain: float
) -> bool:
	if not _mist_visible_shape_metrics_schema_is_exact(visible):
		return false
	var terrain: Dictionary = visible.get("terrain_bridge", {})
	var pigment: Dictionary = visible.get("pigment", {})
	if (
		str(visible.get("method", ""))
			!= "immutable_body_coarse_bridge_and_meandering_pigment_v2"
		or int(terrain.get("anchor_world_px", -1))
			!= EXPECTED_BAND_MIST_TERRAIN_BRIDGE_ANCHOR_WORLD_PX
		or int(terrain.get("horizontal_control_cells", -1))
			!= EXPECTED_BAND_MIST_HORIZONTAL_CONTROL_CELLS
		or int(terrain.get("vertical_control_cells", -1))
			!= EXPECTED_BAND_MIST_TERRAIN_BRIDGE_VERTICAL_CONTROL_CELLS
		or str(terrain.get("rasterization", ""))
			!= "pillow_box_to_bicubic_control_lattice_plus_whole_anchor_residual"
		or not is_equal_approx(
			float(terrain.get("whole_anchor_detail_gain", -1.0)),
			expected_terrain_bridge_detail_gain
		)
		or expected_terrain_bridge_detail_gain
			< EXPECTED_BAND_MIST_MIN_TERRAIN_BRIDGE_DETAIL_GAIN
		or expected_terrain_bridge_detail_gain
			> EXPECTED_BAND_MIST_MAX_TERRAIN_BRIDGE_DETAIL_GAIN
		or not is_equal_approx(
			float(terrain.get("composite_luma_bias", -1.0)),
			EXPECTED_BAND_MIST_TERRAIN_BRIDGE_COMPOSITE_LUMA_BIAS
		)
		or not is_equal_approx(
			float(terrain.get("shared_reference_detail_gain", -1.0)),
			EXPECTED_BAND_MIST_VISIBLE_SHARED_REFERENCE_DETAIL_GAIN
		)
		or str(terrain.get("shared_reference_rgb_float32_sha256", "")).length() != 64
		or str(terrain.get("rgb_float32_sha256", "")).length() != 64
		or not is_equal_approx(
			float(terrain.get("reveal_depth_minimum_world_px", -1.0)),
			EXPECTED_BAND_MIST_TERRAIN_BRIDGE_REVEAL_MINIMUM_WORLD_PX
		)
		or not is_equal_approx(
			float(terrain.get("reveal_depth_maximum_world_px", -1.0)),
			EXPECTED_BAND_MIST_TERRAIN_BRIDGE_REVEAL_MAXIMUM_WORLD_PX
		)
		or float(terrain.get("maximum_mix", -1.0)) <= 0.0
		or float(terrain.get("maximum_mix", INF)) > 1.0
		or bool(terrain.get("one_pixel_column_operations", true))
		or bool(terrain.get("per_column_adjustment", true))
	):
		return false
	var calibration: Dictionary = terrain.get("edge_luma_calibration", {})
	for edge_name in ["bottom", "top"]:
		var edge_calibration: Dictionary = calibration.get(edge_name, {})
		var source_mean := float(edge_calibration.get("source_mean_luma", INF))
		var literal_target := float(edge_calibration.get(
			"literal_target_body_mean_luma",
			-INF
		))
		var target := float(edge_calibration.get("target_body_mean_luma", -INF))
		var whole_edge_offset := float(edge_calibration.get("whole_edge_rgb_offset", INF))
		var calibrated_mean := float(edge_calibration.get("calibrated_mean_luma", -INF))
		if (
			not is_equal_approx(literal_target, float(tone.get("target_body_luma", INF)))
			or not is_equal_approx(
				target,
				literal_target + EXPECTED_BAND_MIST_TERRAIN_BRIDGE_COMPOSITE_LUMA_BIAS
			)
			or not is_equal_approx(whole_edge_offset, target - source_mean)
			or calibrated_mean <= source_mean
			or calibrated_mean > target + 0.0001
		):
			return false
	if (
		float(pigment.get("centroid_p95_half_range_world_px", -1.0))
			< EXPECTED_BAND_MIST_MIN_VISIBLE_CENTERLINE_HALF_RANGE_WORLD_PX
		or float(pigment.get("centroid_maximum_absolute_world_px", INF))
			> EXPECTED_BAND_MIST_MAX_VISIBLE_CENTERLINE_ABSOLUTE_WORLD_PX
		or float(pigment.get("centroid_valid_column_ratio", -1.0))
			< EXPECTED_BAND_MIST_MIN_VISIBLE_CENTERLINE_VALID_RATIO
		or not is_equal_approx(
			float(pigment.get("nominal_half_width_world_px", -1.0)),
			EXPECTED_BAND_MIST_VISIBLE_PIGMENT_NOMINAL_HALF_WIDTH_WORLD_PX
		)
		or not is_equal_approx(
			float(pigment.get("thickness_variation_ratio", -1.0)),
			EXPECTED_BAND_MIST_THICKNESS_VARIATION_RATIO
		)
		or not is_equal_approx(
			float(pigment.get("edge_centerline_divergence_world_px", -1.0)),
			EXPECTED_BAND_MIST_VISIBLE_EDGE_CENTERLINE_DIVERGENCE_WORLD_PX
		)
		or not is_equal_approx(
			float(pigment.get("edge_centerline_cross_edge_absolute_correlation", INF)),
			absf(float(pigment.get("edge_centerline_cross_edge_correlation", INF)))
		)
		or float(pigment.get("edge_centerline_cross_edge_absolute_correlation", INF))
			> EXPECTED_BAND_MIST_MAX_VISIBLE_EDGE_CROSS_CORRELATION
		or not is_equal_approx(
			float(pigment.get("maximum_ink_mix", -1.0)),
			EXPECTED_BAND_MIST_VISIBLE_PIGMENT_MAXIMUM_MIX
		)
		or not is_equal_approx(
			float(pigment.get("thinning_factor_exponent", -1.0)),
			EXPECTED_BAND_MIST_VISIBLE_THINNING_FACTOR_EXPONENT
		)
		or not is_equal_approx(
			float(pigment.get("active_profile_gate", -1.0)),
			EXPECTED_BAND_MIST_VISIBLE_ACTIVE_PROFILE_GATE
		)
		or not is_equal_approx(
			float(pigment.get("edge_veil_transition_world_px", -1.0)),
			EXPECTED_BAND_MIST_VISIBLE_EDGE_VEIL_TRANSITION_WORLD_PX
		)
		or not is_equal_approx(
			float(pigment.get("edge_veil_minimum_factor", -1.0)),
			EXPECTED_BAND_MIST_VISIBLE_EDGE_VEIL_MINIMUM_FACTOR
		)
		or not is_equal_approx(
			float(pigment.get("edge_veil_top_phase_offset_rad", -1.0)),
			EXPECTED_BAND_MIST_VISIBLE_EDGE_VEIL_TOP_PHASE_OFFSET_RAD
		)
		or not is_equal_approx(
			float(pigment.get("edge_veil_cross_edge_absolute_correlation", INF)),
			absf(float(pigment.get("edge_veil_cross_edge_correlation", INF)))
		)
		or float(pigment.get("edge_veil_cross_edge_absolute_correlation", INF))
			> EXPECTED_BAND_MIST_MAX_VISIBLE_EDGE_CROSS_CORRELATION
		or float(pigment.get("edge_veil_bottom_p05", INF))
			> EXPECTED_BAND_MIST_MAX_VISIBLE_EDGE_VEIL_P05
		or float(pigment.get("edge_veil_top_p05", INF))
			> EXPECTED_BAND_MIST_MAX_VISIBLE_EDGE_VEIL_P05
		or float(pigment.get("edge_veil_bottom_p95", -1.0))
			< EXPECTED_BAND_MIST_MIN_VISIBLE_EDGE_VEIL_P95
		or float(pigment.get("edge_veil_top_p95", -1.0))
			< EXPECTED_BAND_MIST_MIN_VISIBLE_EDGE_VEIL_P95
		or not is_equal_approx(
			float(pigment.get("thinning_terrain_detail_gain", -1.0)),
			EXPECTED_BAND_MIST_VISIBLE_THINNING_TERRAIN_DETAIL_GAIN
		)
		or float(pigment.get("minimum_visible_thinning_factor", -1.0)) <= 0.0
		or float(pigment.get("minimum_visible_thinning_factor", INF)) >= 1.0
		or float(pigment.get("minimum_thinned_peak_ink_mix", -1.0))
			< EXPECTED_BAND_MIST_MIN_VISIBLE_THINNED_PEAK_INK_MIX
		or float(pigment.get("haze_floor", -1.0))
			< EXPECTED_BAND_MIST_MIN_VISIBLE_HAZE_FLOOR
		or not is_equal_approx(
			float(pigment.get("haze_floor", -1.0)),
			EXPECTED_BAND_MIST_VISIBLE_HAZE_FLOOR
		)
		or str(pigment.get("ink_mix_float32_sha256", "")).length() != 64
		or float(visible.get("full_width_pale_run_world_px", INF))
			> EXPECTED_BAND_MIST_MAX_FULL_WIDTH_PALE_RUN_WORLD_PX
		or float(visible.get("core_local_luma_positive_gain_p95", INF))
			> EXPECTED_BAND_MIST_MAX_CORE_LOCAL_LUMA_P95_GAIN
		or float(visible.get("core_local_luma_positive_gain_maximum", INF))
			> EXPECTED_BAND_MIST_MAX_CORE_LOCAL_LUMA_GAIN
		or float(visible.get("minimum_thinned_terrain_detail_ratio", -1.0))
			< EXPECTED_BAND_MIST_MIN_THINNED_TERRAIN_DETAIL_RATIO
	):
		return false
	var actual_thinning: Dictionary = pigment.get(
		"actual_applied_thinning_profiles",
		{}
	)
	if (
		str(actual_thinning.get("construction", ""))
			!= "mean_applied_rows_outside_veil_transition_v1"
		or not is_equal_approx(
			float(actual_thinning.get("transition_world_px", -1.0)),
			EXPECTED_BAND_MIST_VISIBLE_EDGE_VEIL_TRANSITION_WORLD_PX
		)
		or not bool(actual_thinning.get("shared_seam_rows_exact", false))
		or not bool(actual_thinning.get("signatures_unique", false))
		or not is_equal_approx(
			float(actual_thinning.get("bottom_top_absolute_correlation", -1.0)),
			absf(float(actual_thinning.get("bottom_top_correlation", INF)))
		)
		or float(actual_thinning.get("bottom_top_absolute_correlation", INF))
			> EXPECTED_BAND_MIST_MAX_ACTUAL_APPLIED_THINNING_CORRELATION
		or float(actual_thinning.get("strong_overlap_ratio", INF))
			> EXPECTED_BAND_MIST_MAX_ACTUAL_APPLIED_THINNING_STRONG_OVERLAP
	):
		return false
	var actual_thinning_signatures: Dictionary = {}
	for edge_name in ["bottom", "top"]:
		var applied: Dictionary = actual_thinning.get(edge_name, {})
		var applied_active_ratio := float(applied.get("active_ratio", -1.0))
		var applied_signature := str(applied.get("float32_sha256", ""))
		if (
			applied_active_ratio
				< EXPECTED_BAND_MIST_MIN_ACTUAL_APPLIED_THINNING_ACTIVE_RATIO
			or applied_active_ratio
				> EXPECTED_BAND_MIST_MAX_ACTUAL_APPLIED_THINNING_ACTIVE_RATIO
			or float(applied.get("p90", -1.0)) <= 0.0
			or applied_signature.length() != 64
		):
			return false
		actual_thinning_signatures[applied_signature] = true
	if actual_thinning_signatures.size() != 2:
		return false
	var thinning_windows: Dictionary = pigment.get("thinning_windows", {})
	var terrain_detail: Dictionary = visible.get("terrain_detail_by_edge", {})
	for edge_name in ["bottom", "top"]:
		var window: Dictionary = thinning_windows.get(edge_name, {})
		var detail: Dictionary = terrain_detail.get(edge_name, {})
		if (
			float(window.get("active_ratio", -1.0)) <= 0.0
			or float(window.get("active_ratio", INF)) >= 1.0
			or float(window.get("minimum_active_peak_ink_mix", -1.0))
				< EXPECTED_BAND_MIST_MIN_VISIBLE_THINNED_PEAK_INK_MIX
			or float(detail.get("active_top_quintile_counterfactual_retention", -1.0))
				<= 0.0
			or float(detail.get("same_columns_thinning_disabled_retention", -1.0))
				<= 0.0
			or float(detail.get("enabled_to_disabled_ratio", -1.0))
				< EXPECTED_BAND_MIST_MIN_THINNED_TERRAIN_DETAIL_RATIO
		):
			return false
	return true


func _mist_shape_modulation_schema_is_exact(shape: Dictionary) -> bool:
	if not _dictionary_has_exact_keys(shape, [
		"method", "field_construction", "pigment_warp", "edges",
		"cross_edge_metrics", "parameter_table_sha256", "parallel_band_counterproof",
	]):
		return false
	if not _dictionary_has_exact_keys(shape.get("field_construction", {}) as Dictionary, [
		"primary_cycles", "secondary_cycles", "minimum_wavelength_world_px",
		"minimum_horizontal_control_span_world_px",
		"minimum_vertical_control_span_world_px", "horizontal_control_cells",
		"edge_vertical_control_cells", "periodic_halo_control_cells",
		"rasterization", "one_pixel_column_operations", "per_column_adjustment",
	]):
		return false
	if not _dictionary_has_exact_keys(shape.get("pigment_warp", {}) as Dictionary, [
		"method", "margin_world_px", "horizontal_control_cells",
		"vertical_control_cells", "minimum_horizontal_control_span_texture_px",
		"minimum_vertical_control_span_texture_px", "shared_logical_row",
		"shared_seam_primary_phase_rad", "shared_seam_secondary_phase_rad",
		"shared_seam_residual_amplitude_world_px",
		"source_y_control_minimum_texture_px", "source_y_control_maximum_texture_px",
		"sampling_offset_sign", "shared_row_displacement_p95_half_range_world_px",
		"shared_row_displacement_maximum_absolute_world_px",
		"minimum_vertical_jacobian", "one_pixel_column_operations",
		"per_column_adjustment", "warped_rgba_sha256",
		"source_sampling_bias_world_px", "source_sampling_bias_texture_px",
	]):
		return false
	if not _dictionary_has_exact_keys(shape.get("cross_edge_metrics", {}) as Dictionary, [
		"thickness_primary_phase_delta_rad", "meander_primary_phase_delta_rad",
		"minimum_primary_phase_delta_rad", "thinning_strong_overlap_ratio",
		"parameter_signatures_unique", "actual_front_absolute_correlation",
	]):
		return false
	if not _dictionary_has_exact_keys(
		shape.get("parallel_band_counterproof", {}) as Dictionary,
		[
			"construction", "shape_gate_red", "red_effects",
			"all_production_outputs_changed", "effects",
			"disabled_strip_rgba_sha256",
		]
	):
		return false
	var counterproof: Dictionary = shape.get("parallel_band_counterproof", {})
	var effects: Dictionary = counterproof.get("effects", {})
	if not _dictionary_has_exact_keys(effects, [
		"thickness_disabled", "meander_disabled", "thinning_disabled",
		"terrain_disabled",
	]):
		return false
	var meander: Dictionary = effects.get("meander_disabled", {})
	if not _dictionary_has_exact_keys(meander, [
		"production_helper", "gate_red", "production_output_changed",
		"warped_rgba_sha256", "actual_warped_rgba_sha256", "edges",
		"alpha_identity_changed_pixels", "alpha_identity_maximum_delta",
	]):
		return false
	var meander_edges: Dictionary = meander.get("edges", {})
	if not _dictionary_has_exact_keys(meander_edges, ["top", "bottom"]):
		return false
	for edge_name in ["top", "bottom"]:
		if not _dictionary_has_exact_keys(meander_edges.get(edge_name, {}) as Dictionary, [
			"meander_p05_world_px", "meander_p95_world_px",
			"meander_p95_half_range_world_px", "meander_maximum_absolute_world_px",
			"meander_absolute_mean_world_px",
		]):
			return false
	for effect_name in ["thickness_disabled", "thinning_disabled", "terrain_disabled"]:
		var effect: Dictionary = effects.get(effect_name, {})
		if not _dictionary_has_exact_keys(effect, ["production_helper", "gate_red", "edges"]):
			return false
		var effect_edges: Dictionary = effect.get("edges", {})
		if not _dictionary_has_exact_keys(effect_edges, ["top", "bottom"]):
			return false
		for edge_name in ["top", "bottom"]:
			if not _dictionary_has_exact_keys(
				effect_edges.get(edge_name, {}) as Dictionary,
				[
					"mask_float32_sha256", "production_output_changed",
					"thickness_p95_half_range_world_px", "thinning_active_ratio",
					"minimum_applied_thinning_factor",
					"terrain_attachment_maximum_gain",
				]
			):
				return false
	var edges: Dictionary = shape.get("edges", {})
	if not _dictionary_has_exact_keys(edges, ["top", "bottom"]):
		return false
	for edge_name in ["top", "bottom"]:
		var edge: Dictionary = edges.get(edge_name, {})
		if not _dictionary_has_exact_keys(edge, [
			"deterministic_seed", "thickness_phase_rad",
			"thickness_secondary_phase_rad", "meander_phase_rad",
			"meander_secondary_phase_rad", "thinning_center_ratio",
			"thinning_width_ratio", "thinning_opacity_multiplier",
			"terrain_phase_rad", "metrics",
		]):
			return false
		if not _dictionary_has_exact_keys(edge.get("metrics", {}) as Dictionary, [
			"thickness_minimum_world_px", "thickness_maximum_world_px",
			"thickness_p05_world_px", "thickness_p95_world_px",
			"thickness_p95_half_range_world_px", "thinning_width_ratio",
			"minimum_outer_opacity_multiplier", "thinning_active_ratio",
			"thinning_strong_ratio", "minimum_applied_thinning_factor",
			"minimum_column_integrated_opacity_world_px",
			"terrain_attachment_mean_gain", "terrain_attachment_maximum_gain",
			"terrain_attachment_active_ratio",
			"terrain_attachment_maximum_depth_world_px", "terrain_control_cells",
			"terrain_active_control_cells", "terrain_control_active_ratio",
			"terrain_horizontal_active_ratio", "terrain_directional_role",
			"terrain_eligible_control_row", "terrain_selected_control_cells",
			"terrain_selected_raw_foot_scores",
			"terrain_selected_directional_deltas",
			"terrain_selected_applied_strengths",
			"terrain_selected_available_depth_ratios",
			"terrain_selected_distance_minimum_world_px",
			"terrain_selected_distance_maximum_world_px",
			"outer_guard_maximum_opacity",
			"meander_p05_world_px", "meander_p95_world_px",
			"meander_p95_half_range_world_px", "meander_maximum_absolute_world_px",
			"meander_absolute_mean_world_px", "actual_front_p05_depth_texture_px",
			"actual_front_p95_depth_texture_px",
			"actual_front_p95_half_range_world_px",
		]):
			return false
	return true


func _mist_metric_schema_is_exact(metrics: Dictionary) -> bool:
	if not _dictionary_has_exact_keys(metrics, [
		"x4_column_vertical_variance", "world_column_vertical_variance",
		"x4_mirror_correlation", "world_mirror_correlation",
		"x4_luma", "world_luma", "x4_center_detail", "world_center_detail",
	]):
		return false
	var variance_keys := [
		"texture_scale", "seam_mean_column_variance",
		"body_mean_column_variance", "mean_ratio",
		"seam_median_column_variance", "body_median_column_variance",
		"median_ratio",
	]
	var mirror_keys := [
		"texture_scale", "high_pass_radius_px", "maximum_shift_px",
		"maximum_absolute_correlation", "counterfactual_construction",
		"counterfactual_bottom_edge_rows", "mirrored_counterfactual_correlation",
	]
	var luma_keys := [
		"texture_scale", "top_mean", "bottom_mean", "seam_mean", "body_mean",
		"top_absolute_delta", "bottom_absolute_delta", "absolute_delta", "ratio",
		"endpoint_row_mean_jump",
	]
	var center_keys := [
		"texture_scale", "center_row_detail", "neighbor_row_detail_median",
		"center_to_neighbor_detail_ratio", "center_row_mean_luma_jump",
		"maximum_local_row_mean_luma_step",
	]
	for scale_name in ["x4", "world"]:
		if not _dictionary_has_exact_keys(
			metrics.get("%s_column_vertical_variance" % scale_name, {}) as Dictionary,
			variance_keys
		):
			return false
		if not _dictionary_has_exact_keys(
			metrics.get("%s_mirror_correlation" % scale_name, {}) as Dictionary,
			mirror_keys
		):
			return false
		if not _dictionary_has_exact_keys(
			metrics.get("%s_luma" % scale_name, {}) as Dictionary,
			luma_keys
		):
			return false
		if not _dictionary_has_exact_keys(
			metrics.get("%s_center_detail" % scale_name, {}) as Dictionary,
			center_keys
		):
			return false
	return true


func _dictionary_has_exact_keys(value: Dictionary, expected_keys: Array) -> bool:
	if value.size() != expected_keys.size():
		return false
	for key_value in expected_keys:
		if not value.has(str(key_value)):
			return false
	return true


func _mist_edge_shape_is_within_contract(edge_name: String, edge: Dictionary) -> bool:
	var edge_metrics: Dictionary = edge.get("metrics", {})
	var width_ratio := float(edge.get("thinning_width_ratio", -1.0))
	var opacity_multiplier := float(edge.get("thinning_opacity_multiplier", -1.0))
	var active_ratio := float(edge_metrics.get("thinning_active_ratio", -1.0))
	var phase_values := [
		float(edge.get("thickness_phase_rad", -1.0)),
		float(edge.get("thickness_secondary_phase_rad", -1.0)),
		float(edge.get("meander_phase_rad", -1.0)),
		float(edge.get("meander_secondary_phase_rad", -1.0)),
		float(edge.get("terrain_phase_rad", -1.0)),
	]
	for phase in phase_values:
		if float(phase) < 0.0 or float(phase) >= TAU:
			return false
	return (
		int(edge.get("deterministic_seed", -1)) >= 0
		and float(edge.get("thinning_center_ratio", -1.0)) >= 0.0
		and float(edge.get("thinning_center_ratio", INF)) < 1.0
		and width_ratio >= EXPECTED_BAND_MIST_MIN_THINNING_WIDTH_RATIO
		and width_ratio <= EXPECTED_BAND_MIST_MAX_THINNING_WIDTH_RATIO
		and opacity_multiplier >= EXPECTED_BAND_MIST_MIN_THINNING_OPACITY_MULTIPLIER
		and opacity_multiplier <= EXPECTED_BAND_MIST_MAX_THINNING_OPACITY_MULTIPLIER
		and is_equal_approx(
			float(edge_metrics.get("thickness_minimum_world_px", -1.0)),
			EXPECTED_BAND_MIST_MIN_SHAPED_FEATHER_WORLD_PX
		)
		and is_equal_approx(
			float(edge_metrics.get("thickness_maximum_world_px", -1.0)),
			EXPECTED_BAND_MIST_MAX_SHAPED_FEATHER_WORLD_PX
		)
		and float(edge_metrics.get("thickness_p05_world_px", -1.0))
			>= EXPECTED_BAND_MIST_MIN_SHAPED_FEATHER_WORLD_PX
		and float(edge_metrics.get("thickness_p95_world_px", INF))
			<= EXPECTED_BAND_MIST_MAX_SHAPED_FEATHER_WORLD_PX
		and float(edge_metrics.get("thickness_p95_half_range_world_px", -1.0))
			>= EXPECTED_BAND_MIST_MIN_THICKNESS_P95_HALF_RANGE_WORLD_PX
		and is_equal_approx(float(edge_metrics.get("thinning_width_ratio", -1.0)), width_ratio)
		and active_ratio >= EXPECTED_BAND_MIST_MIN_THINNING_WIDTH_RATIO
		and active_ratio <= EXPECTED_BAND_MIST_MAX_THINNING_WIDTH_RATIO
		and float(edge_metrics.get("thinning_strong_ratio", -1.0)) > 0.0
		and float(edge_metrics.get("thinning_strong_ratio", INF))
			<= EXPECTED_BAND_MIST_MAX_THINNING_WIDTH_RATIO
		and float(edge_metrics.get("minimum_outer_opacity_multiplier", -1.0))
			>= EXPECTED_BAND_MIST_MIN_THINNING_OPACITY_MULTIPLIER
		and float(edge_metrics.get("minimum_applied_thinning_factor", -1.0))
			>= EXPECTED_BAND_MIST_MIN_THINNING_OPACITY_MULTIPLIER
		and float(edge_metrics.get("minimum_applied_thinning_factor", INF))
			<= EXPECTED_BAND_MIST_MAX_THINNING_OPACITY_MULTIPLIER
		and float(edge_metrics.get("minimum_column_integrated_opacity_world_px", -1.0))
			>= EXPECTED_BAND_MIST_MIN_COLUMN_INTEGRATED_OPACITY_WORLD_PX
		and float(edge_metrics.get("terrain_attachment_mean_gain", -1.0)) > 0.0
		and float(edge_metrics.get("terrain_attachment_maximum_gain", -1.0))
			>= EXPECTED_BAND_MIST_MIN_TERRAIN_ATTACHMENT_GAIN
		and float(edge_metrics.get("terrain_attachment_active_ratio", -1.0)) > 0.0
		and float(edge_metrics.get("terrain_attachment_active_ratio", INF))
			<= EXPECTED_BAND_MIST_MAX_TERRAIN_ATTACHMENT_ACTIVE_RATIO
		and _mist_terrain_selection_is_local(edge_name, edge_metrics)
		and float(edge_metrics.get("terrain_attachment_maximum_depth_world_px", -1.0))
			> 0.0
		and float(edge_metrics.get("terrain_attachment_maximum_depth_world_px", INF))
			<= EXPECTED_BAND_MIST_MAX_TERRAIN_ATTACHMENT_DEPTH_WORLD_PX
		and is_zero_approx(float(edge_metrics.get("outer_guard_maximum_opacity", INF)))
		and float(edge_metrics.get("meander_p95_half_range_world_px", -1.0))
			>= EXPECTED_BAND_MIST_MIN_MEANDER_P95_HALF_RANGE_WORLD_PX
		and float(edge_metrics.get("actual_front_p95_half_range_world_px", -1.0))
			>= EXPECTED_BAND_MIST_MIN_ACTUAL_FRONT_HALF_RANGE_WORLD_PX
		and float(edge_metrics.get("meander_maximum_absolute_world_px", -1.0))
			>= EXPECTED_BAND_MIST_MIN_MEANDER_MAXIMUM_WORLD_PX
		and float(edge_metrics.get("meander_maximum_absolute_world_px", INF))
			<= EXPECTED_BAND_MIST_MAX_MEANDER_MAXIMUM_WORLD_PX
		and float(edge_metrics.get("meander_absolute_mean_world_px", -1.0)) > 0.0
	)


func _mist_terrain_selection_is_local(edge_name: String, metrics: Dictionary) -> bool:
	var selected_cells: Array = metrics.get("terrain_selected_control_cells", [])
	var raw_scores: Array = metrics.get("terrain_selected_raw_foot_scores", [])
	var directional_deltas: Array = metrics.get(
		"terrain_selected_directional_deltas",
		[]
	)
	var strengths: Array = metrics.get("terrain_selected_applied_strengths", [])
	var available_depths: Array = metrics.get(
		"terrain_selected_available_depth_ratios",
		[]
	)
	var active_cells := int(metrics.get("terrain_active_control_cells", -1))
	var expected_row := (
		EXPECTED_BAND_MIST_EDGE_VERTICAL_CONTROL_CELLS - 1
		if edge_name == "top"
		else 0
	)
	if (
		int(metrics.get("terrain_control_cells", -1))
			!= EXPECTED_BAND_MIST_HORIZONTAL_CONTROL_CELLS
		or active_cells != EXPECTED_BAND_MIST_TERRAIN_SELECTED_CONTROL_CELLS_PER_EDGE
		or selected_cells.size() != active_cells
		or raw_scores.size() != active_cells
		or directional_deltas.size() != active_cells
		or strengths.size() != active_cells
		or available_depths.size() != active_cells
		or float(metrics.get("terrain_control_active_ratio", INF)) <= 0.0
		or float(metrics.get("terrain_control_active_ratio", INF))
			> EXPECTED_BAND_MIST_MAX_TERRAIN_CONTROL_ACTIVE_RATIO
		or float(metrics.get("terrain_horizontal_active_ratio", INF)) <= 0.0
		or float(metrics.get("terrain_horizontal_active_ratio", INF))
			> EXPECTED_BAND_MIST_MAX_TERRAIN_ATTACHMENT_ACTIVE_RATIO
		or int(metrics.get("terrain_eligible_control_row", -1)) != expected_row
		or not is_equal_approx(
			float(metrics.get("terrain_selected_distance_minimum_world_px", -1.0)),
			float(EXPECTED_BAND_MIST_FILL_COVER_WORLD_PX)
		)
		or not is_equal_approx(
			float(metrics.get("terrain_selected_distance_maximum_world_px", -1.0)),
			float(EXPECTED_BAND_MIST_EDGE_ZONE_WORLD_PX)
				- EXPECTED_BAND_MIST_OUTER_ALPHA_GUARD_WORLD_PX
		)
	):
		return false
	var expected_role := (
		"outer_feather_lower_foot_toward_inward_positive_y"
		if edge_name == "top"
		else "outer_feather_lower_foot_toward_inward_negative_y"
	)
	if str(metrics.get("terrain_directional_role", "")) != expected_role:
		return false
	for index in range(active_cells):
		var cell: Array = selected_cells[index]
		if (
			cell.size() != 2
			or int(cell[0]) != expected_row
			or int(cell[1]) < 0
			or int(cell[1]) >= EXPECTED_BAND_MIST_HORIZONTAL_CONTROL_CELLS
			or float(raw_scores[index]) < EXPECTED_BAND_MIST_MIN_TERRAIN_SELECTED_FOOT_SCORE
			or float(directional_deltas[index])
				< EXPECTED_BAND_MIST_MIN_TERRAIN_SELECTED_DIRECTIONAL_DELTA
			or float(strengths[index]) < EXPECTED_BAND_MIST_MIN_TERRAIN_SELECTED_STRENGTH
			or float(strengths[index]) > 1.0
			or float(available_depths[index]) < 0.0
			or float(available_depths[index]) > 1.0
		):
			return false
	return true


func _mist_parallel_band_counterproof_is_red(counterproof: Dictionary) -> bool:
	var expected_red_effects := [
		"meander_disabled",
		"terrain_disabled",
		"thickness_disabled",
		"thinning_disabled",
	]
	if not (
		str(counterproof.get("construction", ""))
			== "production_helpers_effect_disabled_and_remeasured_v2"
		and bool(counterproof.get("shape_gate_red", false))
		and bool(counterproof.get("all_production_outputs_changed", false))
		and counterproof.get("red_effects", []) == expected_red_effects
		and str(counterproof.get("disabled_strip_rgba_sha256", "")).length() == 64
	):
		return false
	var effects: Dictionary = counterproof.get("effects", {})
	for effect_name in expected_red_effects:
		var effect: Dictionary = effects.get(effect_name, {})
		if not bool(effect.get("gate_red", false)):
			return false
		if effect_name == "meander_disabled":
			if (
				str(effect.get("production_helper", "")) != "warp_pigment_strip"
				or not bool(effect.get("production_output_changed", false))
				or str(effect.get("warped_rgba_sha256", "")).length() != 64
				or str(effect.get("actual_warped_rgba_sha256", "")).length() != 64
				or str(effect.get("warped_rgba_sha256", ""))
					== str(effect.get("actual_warped_rgba_sha256", ""))
				or int(effect.get("alpha_identity_changed_pixels", -1)) != 0
				or int(effect.get("alpha_identity_maximum_delta", -1)) != 0
			):
				return false
			for edge_name in ["top", "bottom"]:
				var edge: Dictionary = (effect.get("edges", {}) as Dictionary).get(
					edge_name,
					{}
				)
				if (
					float(edge.get("meander_p95_half_range_world_px", INF))
						>= EXPECTED_BAND_MIST_MIN_MEANDER_P95_HALF_RANGE_WORLD_PX
					or not is_zero_approx(float(edge.get(
						"meander_maximum_absolute_world_px",
						INF
					)))
				):
					return false
			continue
		if str(effect.get("production_helper", "")) != "opacity_mask":
			return false
		for edge_name in ["top", "bottom"]:
			var edge: Dictionary = (effect.get("edges", {}) as Dictionary).get(
				edge_name,
				{}
			)
			if (
				str(edge.get("mask_float32_sha256", "")).length() != 64
				or not bool(edge.get("production_output_changed", false))
			):
				return false
			if (
				effect_name == "thickness_disabled"
				and float(edge.get("thickness_p95_half_range_world_px", INF))
					>= EXPECTED_BAND_MIST_MIN_THICKNESS_P95_HALF_RANGE_WORLD_PX
			):
				return false
			if (
				effect_name == "thinning_disabled"
				and (
					float(edge.get("thinning_active_ratio", INF))
						>= EXPECTED_BAND_MIST_MIN_THINNING_WIDTH_RATIO
					or float(edge.get("minimum_applied_thinning_factor", -INF))
						<= EXPECTED_BAND_MIST_MAX_THINNING_OPACITY_MULTIPLIER
				)
			):
				return false
			if (
				effect_name == "terrain_disabled"
				and float(edge.get("terrain_attachment_maximum_gain", INF))
					>= EXPECTED_BAND_MIST_MIN_TERRAIN_ATTACHMENT_GAIN
			):
				return false
	return true


func _mist_reverse_counterproof_schema_is_exact(counterproof: Dictionary) -> bool:
	return _dictionary_has_exact_keys(counterproof, [
		"construction", "assignment", "production_mirror",
		"maximum_allowed_mirror_correlation",
		"x4_maximum_absolute_correlation", "world_maximum_absolute_correlation",
		"mirror_gate_red",
	])


func _mist_thresholds_are_exact(thresholds: Dictionary) -> bool:
	return (
		is_equal_approx(
			float(thresholds.get("minimum_column_vertical_variance_ratio", -1.0)),
			EXPECTED_BAND_MIST_MIN_VARIANCE_RATIO
		)
		and is_equal_approx(
			float(thresholds.get("maximum_column_vertical_variance_ratio", -1.0)),
			EXPECTED_BAND_MIST_MAX_VARIANCE_RATIO
		)
		and is_equal_approx(
			float(thresholds.get("maximum_mirror_correlation", -1.0)),
			EXPECTED_BAND_MIST_MAX_MIRROR_CORRELATION
		)
		and is_equal_approx(
			float(thresholds.get("maximum_seam_body_luma_delta", -1.0)),
			EXPECTED_BAND_MIST_MAX_SEAM_BODY_LUMA_DELTA
		)
		and is_equal_approx(
			float(thresholds.get("maximum_mist_tone_luma", -1.0)),
			EXPECTED_BAND_MIST_MAX_TONE_LUMA
		)
		and is_equal_approx(
			float(thresholds.get("maximum_mist_to_source_contrast_ratio", -1.0)),
			EXPECTED_BAND_MIST_MAX_TONE_CONTRAST_RATIO
		)
		and is_equal_approx(
			float(thresholds.get("minimum_core_opacity", -1.0)),
			EXPECTED_BAND_MIST_MIN_CORE_OPACITY
		)
		and is_equal_approx(
			float(thresholds.get("minimum_opacity_through_world_px_26", -1.0)),
			EXPECTED_BAND_MIST_MIN_CORE_OPACITY
		)
		and is_equal_approx(
			float(thresholds.get("minimum_ragged_mask_residual_std", -1.0)),
			EXPECTED_BAND_MIST_MIN_FEATHER_HORIZONTAL_RESIDUAL_STD
		)
		and is_equal_approx(
			float(thresholds.get("minimum_feather_front_std_texture_px", -1.0)),
			EXPECTED_BAND_MIST_MIN_FEATHER_FRONT_STD_TEXTURE_PX
		)
		and is_equal_approx(
			float(thresholds.get("minimum_center_detail_ratio", -1.0)),
			EXPECTED_BAND_MIST_MIN_CENTER_DETAIL_RATIO
		)
		and is_equal_approx(
			float(thresholds.get("maximum_center_detail_ratio", -1.0)),
			EXPECTED_BAND_MIST_MAX_CENTER_DETAIL_RATIO
		)
		and is_equal_approx(
			float(thresholds.get("thickness_variation_ratio", -1.0)),
			EXPECTED_BAND_MIST_THICKNESS_VARIATION_RATIO
		)
		and is_equal_approx(
			float(thresholds.get("nominal_shaped_feather_world_px", -1.0)),
			EXPECTED_BAND_MIST_NOMINAL_SHAPED_FEATHER_WORLD_PX
		)
		and is_equal_approx(
			float(thresholds.get("minimum_shaped_feather_world_px", -1.0)),
			EXPECTED_BAND_MIST_MIN_SHAPED_FEATHER_WORLD_PX
		)
		and is_equal_approx(
			float(thresholds.get("maximum_shaped_feather_world_px", -1.0)),
			EXPECTED_BAND_MIST_MAX_SHAPED_FEATHER_WORLD_PX
		)
		and is_equal_approx(
			float(thresholds.get("outer_alpha_guard_world_px", -1.0)),
			EXPECTED_BAND_MIST_OUTER_ALPHA_GUARD_WORLD_PX
		)
		and is_equal_approx(
			float(thresholds.get("minimum_thickness_p95_half_range_world_px", -1.0)),
			EXPECTED_BAND_MIST_MIN_THICKNESS_P95_HALF_RANGE_WORLD_PX
		)
		and is_equal_approx(
			float(thresholds.get("meander_amplitude_world_px", -1.0)),
			EXPECTED_BAND_MIST_MEANDER_AMPLITUDE_WORLD_PX
		)
		and is_equal_approx(
			float(thresholds.get("minimum_meander_p95_half_range_world_px", -1.0)),
			EXPECTED_BAND_MIST_MIN_MEANDER_P95_HALF_RANGE_WORLD_PX
		)
		and is_equal_approx(
			float(thresholds.get("minimum_field_wavelength_world_px", -1.0)),
			EXPECTED_BAND_MIST_MIN_FIELD_WAVELENGTH_WORLD_PX
		)
		and is_equal_approx(
			float(thresholds.get("minimum_horizontal_control_span_world_px", -1.0)),
			EXPECTED_BAND_MIST_MIN_HORIZONTAL_CONTROL_SPAN_WORLD_PX
		)
		and is_equal_approx(
			float(thresholds.get("minimum_vertical_control_span_world_px", -1.0)),
			EXPECTED_BAND_MIST_MIN_VERTICAL_CONTROL_SPAN_WORLD_PX
		)
		and int(thresholds.get("horizontal_control_cells", -1))
			== EXPECTED_BAND_MIST_HORIZONTAL_CONTROL_CELLS
		and int(thresholds.get("edge_vertical_control_cells", -1))
			== EXPECTED_BAND_MIST_EDGE_VERTICAL_CONTROL_CELLS
		and int(thresholds.get("periodic_halo_control_cells", -1))
			== EXPECTED_BAND_MIST_PERIODIC_HALO_CONTROL_CELLS
		and int(thresholds.get("meander_source_margin_world_px", -1))
			== EXPECTED_BAND_MIST_MEANDER_SOURCE_MARGIN_WORLD_PX
		and is_equal_approx(
			float(thresholds.get("maximum_source_sampling_bias_world_px", -1.0)),
			EXPECTED_BAND_MIST_MAX_SOURCE_SAMPLING_BIAS_WORLD_PX
		)
		and is_equal_approx(
			float(thresholds.get("shared_seam_residual_amplitude_world_px", -1.0)),
			EXPECTED_BAND_MIST_SHARED_SEAM_RESIDUAL_AMPLITUDE_WORLD_PX
		)
		and is_equal_approx(
			float(thresholds.get("minimum_shared_seam_p95_half_range_world_px", -1.0)),
			EXPECTED_BAND_MIST_MIN_SHARED_SEAM_HALF_RANGE_WORLD_PX
		)
		and is_equal_approx(
			float(thresholds.get("minimum_actual_front_p95_half_range_world_px", -1.0)),
			EXPECTED_BAND_MIST_MIN_ACTUAL_FRONT_HALF_RANGE_WORLD_PX
		)
		and is_equal_approx(
			float(thresholds.get("maximum_actual_front_absolute_correlation", -1.0)),
			EXPECTED_BAND_MIST_MAX_ACTUAL_FRONT_CORRELATION
		)
		and is_equal_approx(
			float(thresholds.get("minimum_thinning_width_ratio", -1.0)),
			EXPECTED_BAND_MIST_MIN_THINNING_WIDTH_RATIO
		)
		and is_equal_approx(
			float(thresholds.get("maximum_thinning_width_ratio", -1.0)),
			EXPECTED_BAND_MIST_MAX_THINNING_WIDTH_RATIO
		)
		and is_equal_approx(
			float(thresholds.get("thinning_active_window_threshold", -1.0)),
			EXPECTED_BAND_MIST_THINNING_ACTIVE_WINDOW_THRESHOLD
		)
		and is_equal_approx(
			float(thresholds.get("minimum_thinning_opacity_multiplier", -1.0)),
			EXPECTED_BAND_MIST_MIN_THINNING_OPACITY_MULTIPLIER
		)
		and is_equal_approx(
			float(thresholds.get("maximum_thinning_opacity_multiplier", -1.0)),
			EXPECTED_BAND_MIST_MAX_THINNING_OPACITY_MULTIPLIER
		)
		and is_equal_approx(
			float(thresholds.get("minimum_terrain_attachment_maximum_gain", -1.0)),
			EXPECTED_BAND_MIST_MIN_TERRAIN_ATTACHMENT_GAIN
		)
		and is_equal_approx(
			float(thresholds.get("maximum_terrain_attachment_active_ratio", -1.0)),
			EXPECTED_BAND_MIST_MAX_TERRAIN_ATTACHMENT_ACTIVE_RATIO
		)
		and is_equal_approx(
			float(thresholds.get("maximum_terrain_attachment_depth_world_px", -1.0)),
			EXPECTED_BAND_MIST_MAX_TERRAIN_ATTACHMENT_DEPTH_WORLD_PX
		)
		and is_equal_approx(
			float(thresholds.get("terrain_control_quantile", -1.0)),
			EXPECTED_BAND_MIST_TERRAIN_CONTROL_QUANTILE
		)
		and is_equal_approx(
			float(thresholds.get("maximum_terrain_control_active_ratio", -1.0)),
			EXPECTED_BAND_MIST_MAX_TERRAIN_CONTROL_ACTIVE_RATIO
		)
		and is_equal_approx(
			float(thresholds.get("minimum_terrain_selected_strength", -1.0)),
			EXPECTED_BAND_MIST_MIN_TERRAIN_SELECTED_STRENGTH
		)
		and is_equal_approx(
			float(thresholds.get("minimum_terrain_selected_foot_score", -1.0)),
			EXPECTED_BAND_MIST_MIN_TERRAIN_SELECTED_FOOT_SCORE
		)
		and is_equal_approx(
			float(thresholds.get("minimum_terrain_selected_directional_delta", -1.0)),
			EXPECTED_BAND_MIST_MIN_TERRAIN_SELECTED_DIRECTIONAL_DELTA
		)
		and int(thresholds.get("terrain_selected_control_cells_per_edge", -1))
			== EXPECTED_BAND_MIST_TERRAIN_SELECTED_CONTROL_CELLS_PER_EDGE
		and is_equal_approx(
			float(thresholds.get("minimum_top_bottom_phase_delta_rad", -1.0)),
			EXPECTED_BAND_MIST_MIN_TOP_BOTTOM_PHASE_DELTA_RAD
		)
		and is_equal_approx(
			float(thresholds.get("maximum_thinning_strong_overlap_ratio", -1.0)),
			EXPECTED_BAND_MIST_MAX_THINNING_STRONG_OVERLAP_RATIO
		)
		and is_equal_approx(
			float(thresholds.get("minimum_column_integrated_opacity_world_px", -1.0)),
			EXPECTED_BAND_MIST_MIN_COLUMN_INTEGRATED_OPACITY_WORLD_PX
		)
		and is_equal_approx(
			float(thresholds.get("minimum_warp_vertical_jacobian", -1.0)),
			EXPECTED_BAND_MIST_MIN_WARP_VERTICAL_JACOBIAN
		)
		and int(thresholds.get("terrain_bridge_anchor_world_px", -1))
			== EXPECTED_BAND_MIST_TERRAIN_BRIDGE_ANCHOR_WORLD_PX
		and int(thresholds.get("terrain_bridge_horizontal_control_cells", -1))
			== EXPECTED_BAND_MIST_HORIZONTAL_CONTROL_CELLS
		and int(thresholds.get("terrain_bridge_vertical_control_cells", -1))
			== EXPECTED_BAND_MIST_TERRAIN_BRIDGE_VERTICAL_CONTROL_CELLS
		and is_equal_approx(
			float(thresholds.get("terrain_bridge_reveal_minimum_world_px", -1.0)),
			EXPECTED_BAND_MIST_TERRAIN_BRIDGE_REVEAL_MINIMUM_WORLD_PX
		)
		and is_equal_approx(
			float(thresholds.get("terrain_bridge_reveal_maximum_world_px", -1.0)),
			EXPECTED_BAND_MIST_TERRAIN_BRIDGE_REVEAL_MAXIMUM_WORLD_PX
		)
		and is_equal_approx(
			float(thresholds.get(
				"minimum_terrain_bridge_whole_anchor_detail_gain",
				-1.0
			)),
			EXPECTED_BAND_MIST_MIN_TERRAIN_BRIDGE_DETAIL_GAIN
		)
		and is_equal_approx(
			float(thresholds.get(
				"maximum_terrain_bridge_whole_anchor_detail_gain",
				-1.0
			)),
			EXPECTED_BAND_MIST_MAX_TERRAIN_BRIDGE_DETAIL_GAIN
		)
		and is_equal_approx(
			float(thresholds.get("terrain_bridge_composite_luma_bias", -1.0)),
			EXPECTED_BAND_MIST_TERRAIN_BRIDGE_COMPOSITE_LUMA_BIAS
		)
		and is_equal_approx(
			float(thresholds.get("visible_pigment_nominal_half_width_world_px", -1.0)),
			EXPECTED_BAND_MIST_VISIBLE_PIGMENT_NOMINAL_HALF_WIDTH_WORLD_PX
		)
		and is_equal_approx(
			float(thresholds.get("visible_pigment_maximum_mix", -1.0)),
			EXPECTED_BAND_MIST_VISIBLE_PIGMENT_MAXIMUM_MIX
		)
		and is_equal_approx(
			float(thresholds.get("visible_haze_floor", -1.0)),
			EXPECTED_BAND_MIST_VISIBLE_HAZE_FLOOR
		)
		and is_equal_approx(
			float(thresholds.get("visible_thinning_factor_exponent", -1.0)),
			EXPECTED_BAND_MIST_VISIBLE_THINNING_FACTOR_EXPONENT
		)
		and is_equal_approx(
			float(thresholds.get("visible_thinning_terrain_detail_gain", -1.0)),
			EXPECTED_BAND_MIST_VISIBLE_THINNING_TERRAIN_DETAIL_GAIN
		)
		and is_equal_approx(
			float(thresholds.get("visible_shared_reference_detail_gain", -1.0)),
			EXPECTED_BAND_MIST_VISIBLE_SHARED_REFERENCE_DETAIL_GAIN
		)
		and is_equal_approx(
			float(thresholds.get("visible_shape_seam_transition_world_px", -1.0)),
			EXPECTED_BAND_MIST_VISIBLE_SHAPE_SEAM_TRANSITION_WORLD_PX
		)
		and is_equal_approx(
			float(thresholds.get("visible_edge_veil_transition_world_px", -1.0)),
			EXPECTED_BAND_MIST_VISIBLE_EDGE_VEIL_TRANSITION_WORLD_PX
		)
		and is_equal_approx(
			float(thresholds.get("visible_edge_veil_minimum_factor", -1.0)),
			EXPECTED_BAND_MIST_VISIBLE_EDGE_VEIL_MINIMUM_FACTOR
		)
		and is_equal_approx(
			float(thresholds.get("visible_edge_centerline_divergence_world_px", -1.0)),
			EXPECTED_BAND_MIST_VISIBLE_EDGE_CENTERLINE_DIVERGENCE_WORLD_PX
		)
		and is_equal_approx(
			float(thresholds.get(
				"visible_edge_centerline_maximum_absolute_world_px",
				-1.0
			)),
			EXPECTED_BAND_MIST_VISIBLE_EDGE_CENTERLINE_MAXIMUM_WORLD_PX
		)
		and is_equal_approx(
			float(thresholds.get(
				"visible_centerline_target_p95_half_range_world_px",
				-1.0
			)),
			EXPECTED_BAND_MIST_VISIBLE_CENTERLINE_TARGET_HALF_RANGE_WORLD_PX
		)
		and is_equal_approx(
			float(thresholds.get(
				"minimum_visible_centerline_p95_half_range_world_px",
				-1.0
			)),
			EXPECTED_BAND_MIST_MIN_VISIBLE_CENTERLINE_HALF_RANGE_WORLD_PX
		)
		and is_equal_approx(
			float(thresholds.get("maximum_visible_centerline_absolute_world_px", -1.0)),
			EXPECTED_BAND_MIST_THRESHOLD_MAX_VISIBLE_CENTERLINE_WORLD_PX
		)
		and is_equal_approx(
			float(thresholds.get("minimum_visible_centerline_valid_ratio", -1.0)),
			EXPECTED_BAND_MIST_MIN_VISIBLE_CENTERLINE_VALID_RATIO
		)
		and is_equal_approx(
			float(thresholds.get("maximum_full_width_pale_run_world_px", -1.0)),
			EXPECTED_BAND_MIST_MAX_FULL_WIDTH_PALE_RUN_WORLD_PX
		)
		and is_equal_approx(
			float(thresholds.get("maximum_core_local_luma_p95_gain", -1.0)),
			EXPECTED_BAND_MIST_MAX_CORE_LOCAL_LUMA_P95_GAIN
		)
		and is_equal_approx(
			float(thresholds.get("maximum_core_local_luma_gain", -1.0)),
			EXPECTED_BAND_MIST_MAX_CORE_LOCAL_LUMA_GAIN
		)
		and is_equal_approx(
			float(thresholds.get("minimum_thinned_terrain_detail_ratio", -1.0)),
			EXPECTED_BAND_MIST_MIN_THINNED_TERRAIN_DETAIL_RATIO
		)
		and is_equal_approx(
			float(thresholds.get("minimum_visible_thinned_peak_ink_mix", -1.0)),
			EXPECTED_BAND_MIST_MIN_VISIBLE_THINNED_PEAK_INK_MIX
		)
		and is_equal_approx(
			float(thresholds.get("minimum_visible_haze_floor", -1.0)),
			EXPECTED_BAND_MIST_MIN_VISIBLE_HAZE_FLOOR
		)
		and is_equal_approx(
			float(thresholds.get("minimum_actual_applied_thinning_active_ratio", -1.0)),
			EXPECTED_BAND_MIST_MIN_ACTUAL_APPLIED_THINNING_ACTIVE_RATIO
		)
		and is_equal_approx(
			float(thresholds.get("maximum_actual_applied_thinning_active_ratio", -1.0)),
			EXPECTED_BAND_MIST_MAX_ACTUAL_APPLIED_THINNING_ACTIVE_RATIO
		)
		and is_equal_approx(
			float(thresholds.get(
				"maximum_actual_applied_thinning_strong_overlap_ratio",
				-1.0
			)),
			EXPECTED_BAND_MIST_MAX_ACTUAL_APPLIED_THINNING_STRONG_OVERLAP
		)
		and is_equal_approx(
			float(thresholds.get(
				"maximum_actual_applied_thinning_absolute_correlation",
				-1.0
			)),
			EXPECTED_BAND_MIST_MAX_ACTUAL_APPLIED_THINNING_CORRELATION
		)
		and bool(thresholds.get("actual_applied_thinning_shared_seam_rows_exact", false))
		and bool(thresholds.get("actual_applied_thinning_signatures_unique", false))
		and is_equal_approx(
			float(thresholds.get(
				"maximum_visible_edge_centerline_residual_absolute_correlation",
				-1.0
			)),
			EXPECTED_BAND_MIST_MAX_VISIBLE_EDGE_CROSS_CORRELATION
		)
		and is_equal_approx(
			float(thresholds.get("maximum_visible_edge_veil_absolute_correlation", -1.0)),
			EXPECTED_BAND_MIST_MAX_VISIBLE_EDGE_CROSS_CORRELATION
		)
		and is_equal_approx(
			float(thresholds.get("maximum_visible_edge_veil_p05", -1.0)),
			EXPECTED_BAND_MIST_MAX_VISIBLE_EDGE_VEIL_P05
		)
		and is_equal_approx(
			float(thresholds.get("minimum_visible_edge_veil_p95", -1.0)),
			EXPECTED_BAND_MIST_MIN_VISIBLE_EDGE_VEIL_P95
		)
		and str(thresholds.get("endpoint_row_mean_jump", ""))
			== "diagnostic_only_natural_shared_row"
	)


func _mist_manifest_metrics_within_contract(metrics: Dictionary) -> bool:
	if not _mist_metric_schema_is_exact(metrics):
		return false
	for scale_name in ["x4", "world"]:
		var expected_scale := EXPECTED_BAND_TEXTURE_SCALE if scale_name == "x4" else 1
		var variance: Dictionary = metrics.get(
			"%s_column_vertical_variance" % scale_name,
			{}
		)
		var mirror: Dictionary = metrics.get(
			"%s_mirror_correlation" % scale_name,
			{}
		)
		var luminance: Dictionary = metrics.get("%s_luma" % scale_name, {})
		var center_detail: Dictionary = metrics.get(
			"%s_center_detail" % scale_name,
			{}
		)
		if (
			int(variance.get("texture_scale", 0)) != expected_scale
			or int(mirror.get("texture_scale", 0)) != expected_scale
			or int(luminance.get("texture_scale", 0)) != expected_scale
			or int(center_detail.get("texture_scale", 0)) != expected_scale
			or not _mist_scale_metrics_within_contract(
				variance,
				luminance,
				center_detail
			)
			or float(mirror.get("maximum_absolute_correlation", INF))
				> EXPECTED_BAND_MIST_MAX_MIRROR_CORRELATION
			or str(mirror.get("counterfactual_construction", ""))
				!= EXPECTED_BAND_MIST_REVERSE_COUNTERFACTUAL_CONSTRUCTION
			or int(mirror.get("counterfactual_bottom_edge_rows", -1))
				!= EXPECTED_BAND_MIST_EDGE_ZONE_WORLD_PX * expected_scale
			or float(mirror.get("mirrored_counterfactual_correlation", -INF))
				< EXPECTED_BAND_MIST_MIN_REVERSED_COUNTERFACTUAL_CORRELATION
		):
			return false
	return true


func _mist_decoded_metrics_within_contract(metrics: Dictionary) -> bool:
	return (
		bool(metrics.get("ready", false))
		and _mist_scale_metrics_within_contract(
			metrics.get("column_vertical_variance", {}) as Dictionary,
			metrics.get("luma", {}) as Dictionary,
			metrics.get("center_detail", {}) as Dictionary
		)
	)


func _mist_decoded_variance_is_red(metrics: Dictionary) -> bool:
	if not bool(metrics.get("ready", false)):
		return false
	var variance: Dictionary = metrics.get("column_vertical_variance", {})
	for ratio_name in ["mean_ratio", "median_ratio"]:
		var ratio := float(variance.get(ratio_name, INF))
		if (
			ratio < EXPECTED_BAND_MIST_MIN_VARIANCE_RATIO
			or ratio > EXPECTED_BAND_MIST_MAX_VARIANCE_RATIO
		):
			return true
	return false


func _mist_scale_metrics_within_contract(
	variance: Dictionary,
	luminance: Dictionary,
	center_detail: Dictionary
) -> bool:
	for ratio_name in ["mean_ratio", "median_ratio"]:
		var ratio := float(variance.get(ratio_name, INF))
		if (
			ratio < EXPECTED_BAND_MIST_MIN_VARIANCE_RATIO
			or ratio > EXPECTED_BAND_MIST_MAX_VARIANCE_RATIO
		):
			return false
	for delta_name in ["top_absolute_delta", "bottom_absolute_delta", "absolute_delta"]:
		if (
			float(luminance.get(delta_name, INF))
			> EXPECTED_BAND_MIST_MAX_SEAM_BODY_LUMA_DELTA
		):
			return false
	var detail_ratio := float(
		center_detail.get("center_to_neighbor_detail_ratio", INF)
	)
	return (
		detail_ratio >= EXPECTED_BAND_MIST_MIN_CENTER_DETAIL_RATIO
		and detail_ratio <= EXPECTED_BAND_MIST_MAX_CENTER_DETAIL_RATIO
	)


func _mist_rejected_z13_scale_is_red(
	rejected: Dictionary,
	scale_name: String
) -> bool:
	if not bool(rejected.get("vertical_variance_gate_red", false)):
		return false
	var rejected_metrics: Dictionary = rejected.get("metrics", {})
	var variance: Dictionary = rejected_metrics.get(
		"%s_column_vertical_variance" % scale_name,
		{}
	)
	for ratio_name in ["mean_ratio", "median_ratio"]:
		var ratio := float(variance.get(ratio_name, INF))
		if (
			ratio < EXPECTED_BAND_MIST_MIN_VARIANCE_RATIO
			or ratio > EXPECTED_BAND_MIST_MAX_VARIANCE_RATIO
		):
			return true
	return false


func _build_exact_reversed_top_as_bottom_counterfactual(
	image: Image,
	texture_scale: int
) -> Image:
	var counterfactual: Image = image.duplicate() as Image
	if (
		counterfactual == null
		or counterfactual.is_empty()
		or counterfactual.get_format() != Image.FORMAT_RGB8
		or texture_scale <= 0
	):
		return counterfactual
	var edge_rows := EXPECTED_BAND_MIST_EDGE_ZONE_WORLD_PX * texture_scale
	if edge_rows <= 0 or edge_rows * 2 >= counterfactual.get_height():
		return counterfactual
	var top_edge: Image = counterfactual.get_region(Rect2i(
		0,
		0,
		counterfactual.get_width(),
		edge_rows
	))
	top_edge.flip_y()
	counterfactual.blit_rect(
		top_edge,
		Rect2i(Vector2i.ZERO, top_edge.get_size()),
		Vector2i(0, counterfactual.get_height() - edge_rows)
	)
	return counterfactual


func _measure_rec709_butt_mirror_correlation(
	image: Image,
	texture_scale: int
) -> float:
	if (
		image == null
		or image.is_empty()
		or image.get_format() != Image.FORMAT_RGB8
		or texture_scale <= 0
	):
		return -INF
	var width := image.get_width()
	var height := image.get_height()
	var edge_rows := EXPECTED_BAND_MIST_EDGE_ZONE_WORLD_PX * texture_scale
	if edge_rows <= 0 or edge_rows * 2 >= height:
		return -INF
	var rgb := image.get_data()
	if rgb.size() != width * height * 3:
		return -INF
	var sample_count := width * edge_rows
	var top_total := 0.0
	var bottom_total := 0.0
	var top_square_total := 0.0
	var bottom_square_total := 0.0
	var cross_total := 0.0
	for local_y in range(edge_rows):
		var top_row_offset := local_y * width
		var mirrored_bottom_row_offset := (height - 1 - local_y) * width
		for x in range(width):
			var top_byte := (top_row_offset + x) * 3
			var bottom_byte := (mirrored_bottom_row_offset + x) * 3
			var top_luma := (
				0.2126 * float(rgb[top_byte])
				+ 0.7152 * float(rgb[top_byte + 1])
				+ 0.0722 * float(rgb[top_byte + 2])
			)
			var bottom_luma := (
				0.2126 * float(rgb[bottom_byte])
				+ 0.7152 * float(rgb[bottom_byte + 1])
				+ 0.0722 * float(rgb[bottom_byte + 2])
			)
			top_total += top_luma
			bottom_total += bottom_luma
			top_square_total += top_luma * top_luma
			bottom_square_total += bottom_luma * bottom_luma
			cross_total += top_luma * bottom_luma
	var sample_count_float := float(sample_count)
	var numerator := cross_total - top_total * bottom_total / sample_count_float
	var top_energy := (
		top_square_total - top_total * top_total / sample_count_float
	)
	var bottom_energy := (
		bottom_square_total - bottom_total * bottom_total / sample_count_float
	)
	var denominator_squared := top_energy * bottom_energy
	if denominator_squared <= 1.0e-9:
		return 0.0
	return numerator / sqrt(denominator_squared)


func _build_vertical_smear_counterfactual(
	image: Image,
	texture_scale: int
) -> Image:
	var counterfactual: Image = image.duplicate() as Image
	if (
		counterfactual == null
		or counterfactual.is_empty()
		or counterfactual.get_format() != Image.FORMAT_RGB8
		or texture_scale <= 0
	):
		return counterfactual
	var width := counterfactual.get_width()
	var height := counterfactual.get_height()
	var edge_rows := EXPECTED_BAND_MIST_EDGE_ZONE_WORLD_PX * texture_scale
	if edge_rows <= 0 or edge_rows * 2 >= height:
		return counterfactual
	var rgb := counterfactual.get_data()
	for x in range(width):
		var red_total := 0
		var green_total := 0
		var blue_total := 0
		for local_y in range(edge_rows):
			var top_byte := (local_y * width + x) * 3
			var bottom_byte := ((height - edge_rows + local_y) * width + x) * 3
			red_total += int(rgb[top_byte]) + int(rgb[bottom_byte])
			green_total += int(rgb[top_byte + 1]) + int(rgb[bottom_byte + 1])
			blue_total += int(rgb[top_byte + 2]) + int(rgb[bottom_byte + 2])
		var sample_count := edge_rows * 2
		var mean_red := int(round(float(red_total) / float(sample_count)))
		var mean_green := int(round(float(green_total) / float(sample_count)))
		var mean_blue := int(round(float(blue_total) / float(sample_count)))
		for local_y in range(edge_rows):
			var write_top_byte := (local_y * width + x) * 3
			var write_bottom_byte := ((height - edge_rows + local_y) * width + x) * 3
			rgb[write_top_byte] = mean_red
			rgb[write_top_byte + 1] = mean_green
			rgb[write_top_byte + 2] = mean_blue
			rgb[write_bottom_byte] = mean_red
			rgb[write_bottom_byte + 1] = mean_green
			rgb[write_bottom_byte + 2] = mean_blue
	return Image.create_from_data(
		width,
		height,
		false,
		Image.FORMAT_RGB8,
		rgb
	)


func _measure_decoded_smear_variance(
	image: Image,
	texture_scale: int,
	body_reference: Dictionary
) -> Dictionary:
	if (
		image == null
		or image.is_empty()
		or image.get_format() != Image.FORMAT_RGB8
		or texture_scale <= 0
	):
		return {"ready": false}
	var width := image.get_width()
	var height := image.get_height()
	var edge_rows := EXPECTED_BAND_MIST_EDGE_ZONE_WORLD_PX * texture_scale
	if edge_rows <= 0 or edge_rows * 2 >= height:
		return {"ready": false}
	var rgb := image.get_data()
	var seam_count := edge_rows * 2
	var seam_column_variances := PackedFloat64Array()
	seam_column_variances.resize(width)
	for x in range(width):
		var seam_sum := 0.0
		var seam_square_sum := 0.0
		for local_y in range(edge_rows):
			var top_byte := (local_y * width + x) * 3
			var bottom_byte := ((height - edge_rows + local_y) * width + x) * 3
			var top_luma := (
				0.2126 * float(rgb[top_byte])
				+ 0.7152 * float(rgb[top_byte + 1])
				+ 0.0722 * float(rgb[top_byte + 2])
			)
			var bottom_luma := (
				0.2126 * float(rgb[bottom_byte])
				+ 0.7152 * float(rgb[bottom_byte + 1])
				+ 0.0722 * float(rgb[bottom_byte + 2])
			)
			seam_sum += top_luma + bottom_luma
			seam_square_sum += top_luma * top_luma + bottom_luma * bottom_luma
		var seam_mean := seam_sum / float(seam_count)
		seam_column_variances[x] = maxf(
			0.0,
			seam_square_sum / float(seam_count) - seam_mean * seam_mean
		)
	var seam_variance_mean := _mist_packed_mean(seam_column_variances)
	var seam_variance_median := _mist_packed_median(seam_column_variances)
	var body_variance_mean := float(
		body_reference.get("body_mean_column_variance", 0.0)
	)
	var body_variance_median := float(
		body_reference.get("body_median_column_variance", 0.0)
	)
	return {
		"ready": true,
		"column_vertical_variance": {
			"seam_mean_column_variance": seam_variance_mean,
			"body_mean_column_variance": body_variance_mean,
			"mean_ratio": _mist_safe_ratio(
				seam_variance_mean,
				body_variance_mean
			),
			"seam_median_column_variance": seam_variance_median,
			"body_median_column_variance": body_variance_median,
			"median_ratio": _mist_safe_ratio(
				seam_variance_median,
				body_variance_median
			),
		},
	}


func _measure_decoded_mist_metrics(
	image: Image,
	texture_scale: int
) -> Dictionary:
	if (
		image == null
		or image.is_empty()
		or image.get_format() != Image.FORMAT_RGB8
		or texture_scale <= 0
	):
		return {"ready": false}
	var width := image.get_width()
	var height := image.get_height()
	var edge_rows := EXPECTED_BAND_MIST_EDGE_ZONE_WORLD_PX * texture_scale
	if edge_rows <= 0 or edge_rows * 2 >= height:
		return {"ready": false}
	var rgb := image.get_data()
	if rgb.size() != width * height * 3:
		return {"ready": false}
	var values := PackedFloat64Array()
	values.resize(width * height)
	for pixel_index in range(width * height):
		var byte_index := pixel_index * 3
		values[pixel_index] = (
			0.2126 * float(rgb[byte_index])
			+ 0.7152 * float(rgb[byte_index + 1])
			+ 0.0722 * float(rgb[byte_index + 2])
		)

	var seam_column_variances := PackedFloat64Array()
	var body_column_variances := PackedFloat64Array()
	seam_column_variances.resize(width)
	body_column_variances.resize(width)
	var top_total := 0.0
	var bottom_total := 0.0
	var body_total := 0.0
	var seam_count := edge_rows * 2
	var body_count := height - edge_rows * 2
	for x in range(width):
		var seam_sum := 0.0
		var seam_square_sum := 0.0
		var body_sum := 0.0
		var body_square_sum := 0.0
		for local_y in range(edge_rows):
			var top_value := values[local_y * width + x]
			var bottom_value := values[(height - edge_rows + local_y) * width + x]
			top_total += top_value
			bottom_total += bottom_value
			seam_sum += top_value + bottom_value
			seam_square_sum += top_value * top_value + bottom_value * bottom_value
		for y in range(edge_rows, height - edge_rows):
			var body_value := values[y * width + x]
			body_total += body_value
			body_sum += body_value
			body_square_sum += body_value * body_value
		var seam_mean := seam_sum / float(seam_count)
		var body_mean := body_sum / float(body_count)
		seam_column_variances[x] = maxf(
			0.0,
			seam_square_sum / float(seam_count) - seam_mean * seam_mean
		)
		body_column_variances[x] = maxf(
			0.0,
			body_square_sum / float(body_count) - body_mean * body_mean
		)

	var seam_variance_mean := _mist_packed_mean(seam_column_variances)
	var body_variance_mean := _mist_packed_mean(body_column_variances)
	var seam_variance_median := _mist_packed_median(seam_column_variances)
	var body_variance_median := _mist_packed_median(body_column_variances)
	var top_mean := top_total / float(width * edge_rows)
	var bottom_mean := bottom_total / float(width * edge_rows)
	var combined_mean := (top_total + bottom_total) / float(width * seam_count)
	var body_mean := body_total / float(width * body_count)

	var row_details := PackedFloat64Array()
	row_details.resize(seam_count)
	for butt_y in range(seam_count):
		var source_y := (
			height - edge_rows + butt_y
			if butt_y < edge_rows
			else butt_y - edge_rows
		)
		var row_sum := 0.0
		var row_square_sum := 0.0
		var row_offset := source_y * width
		for x in range(width):
			var row_value := values[row_offset + x]
			row_sum += row_value
			row_square_sum += row_value * row_value
		var row_mean := row_sum / float(width)
		row_details[butt_y] = sqrt(
			maxf(0.0, row_square_sum / float(width) - row_mean * row_mean)
		)
	var center := edge_rows
	var near := 4 * texture_scale
	var far := 16 * texture_scale
	var neighbor_details := PackedFloat64Array()
	for index in range(center - far, center - near):
		neighbor_details.append(row_details[index])
	for index in range(center + near, center + far):
		neighbor_details.append(row_details[index])
	var center_detail := (
		row_details[center - 1] + row_details[center]
	) * 0.5
	var neighbor_detail := _mist_packed_median(neighbor_details)

	return {
		"ready": true,
		"texture_scale": texture_scale,
		"column_vertical_variance": {
			"seam_mean_column_variance": seam_variance_mean,
			"body_mean_column_variance": body_variance_mean,
			"mean_ratio": _mist_safe_ratio(
				seam_variance_mean,
				body_variance_mean
			),
			"seam_median_column_variance": seam_variance_median,
			"body_median_column_variance": body_variance_median,
			"median_ratio": _mist_safe_ratio(
				seam_variance_median,
				body_variance_median
			),
		},
		"luma": {
			"top_mean": top_mean,
			"bottom_mean": bottom_mean,
			"seam_mean": combined_mean,
			"body_mean": body_mean,
			"top_absolute_delta": absf(top_mean - body_mean),
			"bottom_absolute_delta": absf(bottom_mean - body_mean),
			"absolute_delta": absf(combined_mean - body_mean),
		},
		"center_detail": {
			"center_row_detail": center_detail,
			"neighbor_row_detail_median": neighbor_detail,
			"center_to_neighbor_detail_ratio": _mist_safe_ratio(
				center_detail,
				neighbor_detail
			),
		},
	}


func _mist_packed_mean(values: PackedFloat64Array) -> float:
	if values.is_empty():
		return INF
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())


func _mist_packed_median(values: PackedFloat64Array) -> float:
	if values.is_empty():
		return INF
	var ordered := values.duplicate()
	ordered.sort()
	var middle := int(floor(float(ordered.size()) * 0.5))
	if ordered.size() % 2 == 0:
		return (ordered[middle - 1] + ordered[middle]) * 0.5
	return ordered[middle]


func _mist_safe_ratio(numerator: float, denominator: float) -> float:
	return numerator / denominator if denominator > 1.0e-9 else INF


func _verify_band_edge_mist_source_contract() -> void:
	var art_source := FileAccess.get_file_as_string(EXPECTED_BAND_MIST_TOOL_SOURCE)
	art_source = art_source.replace("\r\n", "\n").replace("\r", "\n")
	_expect(
		_sha256(art_source.to_utf8_buffer())
			== EXPECTED_BAND_MIST_TOOL_SHA256,
		"Z13-c canonical LF-normalized art generator SHA-256 must remain pinned"
	)
	var strip_table_body := _python_function_body(
		art_source,
		"def strip_table_payload("
	)
	var deterministic_shape_body := _python_function_body(
		art_source,
		"def deterministic_shape_words("
	)
	var edge_shape_specs_body := _python_function_body(
		art_source,
		"def edge_shape_specs("
	)
	var shape_table_body := _python_function_body(
		art_source,
		"def shape_table_payload("
	)
	var validate_shape_table_body := _python_function_body(
		art_source,
		"def validate_shape_table("
	)
	var horizontal_nodes_body := _python_function_body(
		art_source,
		"def horizontal_control_nodes_texture_px("
	)
	var periodic_control_body := _python_function_body(
		art_source,
		"def periodic_control_field("
	)
	var expand_control_body := _python_function_body(
		art_source,
		"def expand_horizontal_control_field("
	)
	var low_frequency_body := _python_function_body(
		art_source,
		"def periodic_low_frequency_field("
	)
	var thinning_window_body := _python_function_body(
		art_source,
		"def periodic_thinning_window("
	)
	var luma_body := _python_function_body(art_source, "def luma(")
	var crop_body := _python_function_body(art_source, "def crop_strip(")
	var warp_body := _python_function_body(art_source, "def warp_pigment_strip(")
	var terrain_body := _python_function_body(
		art_source,
		"def terrain_attachment_support("
	)
	var terrain_bridge_body := _python_function_body(
		art_source,
		"def terrain_bridge_from_immutable_body("
	)
	var opacity_body := _python_function_body(art_source, "def opacity_mask(")
	var tone_body := _python_function_body(
		art_source,
		"def tone_and_composite_strip("
	)
	var build_body := _python_function_body(art_source, "def build_band(")
	var measured_mirror_body := _python_function_body(
		art_source,
		"def measured_mirror_correlation("
	)
	var mirror_body := _python_function_body(art_source, "def mirror_metrics(")
	var reverse_body := _python_function_body(art_source, "def reverse_counterproof(")
	var shape_gate_body := _python_function_body(art_source, "def shape_gate_failures(")
	var mask_metrics_body := _python_function_body(art_source, "def mask_metrics(")
	var production_counterproof_body := _python_function_body(
		art_source,
		"def production_shape_counterproofs("
	)
	_expect(
		art_source.count("def circular_phase_midpoint(") == 1,
		"Z13-e generator must retain exactly one circular phase midpoint helper definition"
	)
	var update_manifest_body := _python_function_body(
		art_source,
		"def update_manifest("
	)
	var validate_final_body := _python_function_body(
		art_source,
		"def validate_final_record("
	)
	var main_body := _python_function_body(art_source, "def main(")
	var production_bake_source := (
		deterministic_shape_body
		+ edge_shape_specs_body
		+ horizontal_nodes_body
		+ periodic_control_body
		+ expand_control_body
		+ low_frequency_body
		+ thinning_window_body
		+ crop_body
		+ warp_body
		+ terrain_body
		+ terrain_bridge_body
		+ opacity_body
		+ tone_body
		+ build_body
	)
	var mesh_upper_left := warp_body.find(
		"float(source_y_control[control_y_index, control_x_index])"
	)
	var mesh_lower_left := warp_body.find(
		"float(source_y_control[control_y_index + 1, control_x_index])"
	)
	var mesh_lower_right := warp_body.find(
		"float(source_y_control[control_y_index + 1, control_x_index + 1])"
	)
	var mesh_upper_right := warp_body.find(
		"float(source_y_control[control_y_index, control_x_index + 1])"
	)
	_expect(
		crop_body.find(
			"source[strip.y : strip.y + STRIP_HEIGHT, strip.x : strip.x + strip.width]"
		) >= 0
		and crop_body.find("(DESTINATION_WIDTH, STRIP_HEIGHT)") >= 0
		and crop_body.find("ImageFilter.GaussianBlur(GAUSSIAN_BLUR_TEXTURE_PX)") >= 0
		and crop_body.find("crop[:EDGE_PATCH_HEIGHT]") >= 0
		and crop_body.find("crop[EDGE_PATCH_HEIGHT - 1 :]") >= 0
		and crop_body.find("effective_source_y = strip.y + source_sampling_bias_rows")
			>= 0
		and crop_body.find("extended_source_y = (") >= 0
		and crop_body.find(
			"strip.y - MEANDER_MARGIN_ROWS + source_sampling_bias_rows"
		) >= 0
		and crop_body.find("extended_source_y : extended_source_y") >= 0
		and crop_body.find(
			"expected_extended_height = STRIP_HEIGHT + MEANDER_MARGIN_ROWS * 2"
		) >= 0
		and crop_body.find(
			"extended_crop.shape != (expected_extended_height, strip.width, 4)"
		) >= 0,
		"Z13-e generator must transform one contiguous strip plus a bounded meander margin"
	)
	_expect(
		opacity_body.find("native_alpha") >= 0
		and opacity_body.find("brush") >= 0
		and opacity_body.find("periodic_low_frequency_field(") >= 0
		and opacity_body.find("periodic_thinning_window(shape)") >= 0
		and opacity_body.find("terrain_attachment_support(") >= 0
		and opacity_body.find("distance_rows <= COVERED_ROWS") >= 0
		and mask_metrics_body.find("top[: COVERED_ROWS + 1]") >= 0
		and mask_metrics_body.find("bottom[-(COVERED_ROWS + 1) :]") >= 0
		and opacity_body.find("minimum_applied_thinning_factor") >= 0
		and opacity_body.find("minimum_column_integrated_opacity_world_px") >= 0,
		"Z13-e mask must keep full cover while shaping, thinning, and attaching locally"
	)
	_expect(
		production_bake_source.find("_mirrored_edge_bleed(") < 0
		and production_bake_source.find("[::-1]") < 0
		and production_bake_source.find("np.flip") < 0
		and production_bake_source.find("np.tile") < 0
		and production_bake_source.find("np.repeat") < 0
		and production_bake_source.find("np.roll(") < 0
		and production_bake_source.find("np.take(") < 0
		and production_bake_source.find("np.take_along_axis(") < 0
		and production_bake_source.find("np.arange(DESTINATION_WIDTH") < 0
		and production_bake_source.find("horizontal_indices") < 0
		and production_bake_source.find("extended_patch[lower_rows") < 0
		and production_bake_source.find("extended_patch[upper_rows") < 0
		and production_bake_source.find("for x in ") < 0
		and production_bake_source.find("for x, ") < 0
		and production_bake_source.find("[:, :1]") < 0
		and production_bake_source.find("[:, -1:]") < 0
		and build_body.find("np.array_equal(bottom[-1], top[0])") >= 0
		and warp_body.find("Image.Transform.MESH") >= 0
		and warp_body.find("for control_x_index in range(len(horizontal_nodes) - 1)")
			>= 0,
		"Z13-e production bake must reject mirror, column loops/slices, roll, and take"
	)
	_expect(
		strip_table_body.find("\"fixed_seed\": FIXED_SEED") >= 0
		and strip_table_body.find("\"fixed_seed_role\": FIXED_SEED_ROLE") >= 0
		and strip_table_body.find("\"strips\": [") >= 0
		and shape_table_body.find("\"fixed_seed\": FIXED_SEED") >= 0
		and shape_table_body.find("\"fixed_seed_role\": FIXED_SEED_ROLE") >= 0
		and shape_table_body.find("edge_shape_specs(spec.output)") >= 0
		and shape_table_body.find(
			"\"terrain_bridge_detail_gain\": spec.terrain_bridge_detail_gain"
		) >= 0
		and validate_shape_table_body.find(
			"TERRAIN_BRIDGE_WHOLE_ANCHOR_DETAIL_GAIN"
		) >= 0
		and validate_shape_table_body.find(
			"<= spec.terrain_bridge_detail_gain"
		) >= 0
		and build_body.find(
			"\"fixed_seed_strip_table_sha256\": canonical_json_sha256(strip_table_payload())"
		) >= 0
		and build_body.find(
			"\"fixed_seed_shape_table_sha256\": canonical_json_sha256(shape_table_payload())"
		) >= 0,
		"Z13-e crop and twelve-edge shape digests must bind the fixed seed"
	)
	_expect(
		terrain_bridge_body.find("whole_anchor_detail_gain: float") >= 0
		and terrain_bridge_body.find("* whole_anchor_detail_gain") >= 0
		and terrain_bridge_body.find("Image.Resampling.BOX") >= 0
		and terrain_bridge_body.find("Image.Resampling.BICUBIC") >= 0
		and terrain_bridge_body.find("literal_target_body_luma") >= 0
		and terrain_bridge_body.find(
			"target_body_luma = ("
		) >= 0
		and terrain_bridge_body.find(
			"rgb_offset = target_body_luma - source_mean"
		) >= 0
		and terrain_bridge_body.find("bridge[edge_slice] = np.clip(") >= 0
		and tone_body.find("terrain_bridge_from_immutable_body(") >= 0
		and tone_body.find("terrain_bridge_detail_gain,") >= 0
		and build_body.find("spec.terrain_bridge_detail_gain,") >= 0,
		"Z13-e visible terrain bridge must use per-band detail gain and whole-edge luma calibration"
	)
	_expect(
		tone_body.find("bottom_seam_transition = smootherstep(") >= 0
		and tone_body.find("VISIBLE_SHAPE_SEAM_TRANSITION_WORLD_PX") >= 0
		and tone_body.find("edge_centerline_by_edge") >= 0
		and tone_body.find("shared_visible_centerline[None, :]") >= 0
		and tone_body.find("bottom_visible_half_width - shared_visible_half_width") >= 0
		and tone_body.find("top_visible_half_width - shared_visible_half_width") >= 0
		and tone_body.find("shared_thinning_window = np.maximum(") >= 0
		and tone_body.find("shared_thinning_factor = np.minimum(") >= 0
		and tone_body.find(
			"bottom_thinning_window - shared_thinning_window"
		) >= 0
		and tone_body.find("top_thinning_window - shared_thinning_window") >= 0
		and tone_body.find("VISIBLE_EDGE_VEIL_TRANSITION_WORLD_PX") >= 0
		and tone_body.find("shared_edge_veil = 0.5 * (") >= 0
		and tone_body.find("edge_veil_by_edge[\"bottom\"] - shared_edge_veil") >= 0
		and tone_body.find("edge_veil_by_edge[\"top\"] - shared_edge_veil") >= 0
		and tone_body.find(
			"bottom_distance_world_px >= VISIBLE_EDGE_VEIL_TRANSITION_WORLD_PX"
		) >= 0
		and tone_body.find(
			"top_distance_world_px >= VISIBLE_EDGE_VEIL_TRANSITION_WORLD_PX"
		) >= 0
		and tone_body.find("actual_thinning_shared_seam_rows_exact") >= 0
		and tone_body.find("visible_thinning_window[EDGE_ROWS - 1]") >= 0
		and tone_body.find("visible_thinning_window[EDGE_ROWS]") >= 0
		and tone_body.find("actual_thinning_signatures_unique") >= 0
		and tone_body.find("actual_thinning_absolute_correlation") >= 0
		and tone_body.find(
			"MAXIMUM_ACTUAL_APPLIED_THINNING_ABSOLUTE_CORRELATION"
		) >= 0,
		"Z13-e visible shape must share only the seam and transition to edge-specific fields in 1.25px"
	)
	_expect(
		tone_body.find("thinning_disabled_ink_mix") >= 0
		and tone_body.find("thinning_disabled_result = compose(") >= 0
		and tone_body.find("thinning_disabled_counterfactual_result = compose(") >= 0
		and tone_body.find("thinning_disabled_terrain_detail_signal") >= 0
		and tone_body.find("same_columns_thinning_disabled_retention") >= 0,
		"Z13-e visible thinning must retain an actual compose-helper OFF counterproof"
	)
	_expect(
		deterministic_shape_body.find("hashlib.sha512(") >= 0
		and deterministic_shape_body.find(
			"f\"{FIXED_SEED:08x}|{output}|{edge_name}|z13e\""
		) >= 0
		and validate_shape_table_body.find("len(seeds) != expected_edges") >= 0
		and validate_shape_table_body.find("len(signatures) != expected_edges") >= 0
		and horizontal_nodes_body.find("HORIZONTAL_CONTROL_CELLS + 1") >= 0
		and horizontal_nodes_body.find("np.linspace(0.0, DESTINATION_WIDTH") >= 0
		and periodic_control_body.find("PRIMARY_FIELD_CYCLES") >= 0
		and periodic_control_body.find("SECONDARY_FIELD_CYCLES") >= 0
		and expand_control_body.find("HORIZONTAL_CONTROL_HALO_CELLS") >= 0
		and expand_control_body.find("Image.Resampling.BICUBIC") >= 0
		and thinning_window_body.find("wrapped_distance = np.minimum") >= 0,
		"Z13-e shape parameters must derive twelve unique low-frequency fields"
	)
	_expect(
		warp_body.find("minimum_vertical_jacobian") >= 0
		and warp_body.find("displacement_control_rows") >= 0
		and warp_body.find("seam_residual_control") >= 0
		and warp_body.find("Image.Transform.MESH") >= 0
		and warp_body.find("Image.Resampling.BICUBIC") >= 0
		and warp_body.find("source_x0") >= 0
		and mesh_upper_left >= 0
		and mesh_upper_left < mesh_lower_left
		and mesh_lower_left < mesh_lower_right
		and mesh_lower_right < mesh_upper_right
		and terrain_body.find("dark_detail = blurred_luma - base_luma") >= 0
		and terrain_body.find("Image.Resampling.BOX") >= 0
		and terrain_body.find("selected_cells = ranked_cells[:maximum_active_cells]")
			>= 0
		and terrain_body.find("sparse_control[eligible_row, positive_selected]") >= 0
		and terrain_body.find("np.mean(np.max(support, axis=0) > 0.01)") >= 0,
		"Z13-e meander must be a non-folding macro mesh and terrain bite must be local"
	)
	_expect(
		shape_gate_body.find("thinning_active_ratio") >= 0
		and shape_gate_body.find("minimum_applied_thinning_factor") >= 0
		and shape_gate_body.find("minimum_column_integrated_opacity_world_px") >= 0
		and production_counterproof_body.find(
			"meander_amplitude_world_px=0.0"
		) >= 0
		and production_counterproof_body.find("thickness_variation_world_px\": 0.0")
			>= 0
		and production_counterproof_body.find("thinning_enabled\": False") >= 0
		and production_counterproof_body.find("terrain_opacity_gain\": 0.0") >= 0
		and production_counterproof_body.find("production_output_changed") >= 0
		and production_counterproof_body.find("set(red_effects) != expected_effects")
			>= 0,
		"Z13-e producer must disable and remeasure each actual production helper for RED"
	)
	_expect(
		luma_body.find("* 0.2126") >= 0
		and luma_body.find("* 0.7152") >= 0
		and luma_body.find("* 0.0722") >= 0
		and measured_mirror_body.find("bottom_mirrored = high_pass[-rows:][::-1]")
			>= 0,
		"Z13-e mirror metric must retain Rec.709 luma and reversed-bottom comparison"
	)
	_expect(
		mirror_body.find("counterfactual = sample.copy()") >= 0
		and mirror_body.find("counterfactual[-rows:] = sample[:rows][::-1]") >= 0
		and mirror_body.find(
			"counterfactual_correlation = measured_mirror_correlation("
		) >= 0
		and mirror_body.find("shifted_abs_pearson_max(top, top") < 0
		and reverse_body.find(
			"\"assignment\": \"counterfactual[-rows:] = sample[:rows][::-1]\""
		) >= 0
		and reverse_body.find("x4_correlation > MAXIMUM_MIRROR_CORRELATION") >= 0
		and reverse_body.find("world_correlation > MAXIMUM_MIRROR_CORRELATION")
			>= 0,
		"Z13-c producer must construct and reject a real reversed-top-as-bottom counterfactual"
	)
	_expect(
		update_manifest_body.find(
			"canonical_json_sha256(records[spec.output].get(\"edge_bleed\", {}))"
		) >= 0
		and update_manifest_body.find(
			"records[spec.output][\"edge_mist_bake\"] = contract"
		) >= 0
		and update_manifest_body.find(
			"records[spec.output][\"edge_bleed\"] = contract"
		) < 0
		and validate_final_body.find(
			"canonical_json_sha256(record.get(\"edge_bleed\", {}))"
		) >= 0
		and validate_final_body.find("final Z13-c source/table provenance drifted") >= 0
		and validate_final_body.find(
			"reverse_counterproof(metrics) != contract.get(\"reverse_counterproof\")"
		) >= 0,
		"Z13-c writer and final validator must preserve the approved edge_bleed parent"
	)
	_expect(
		main_body.find(
			"final_already_present = all(current_contract_flags) and not all(base_flags)"
		) >= 0
		and main_body.find("contract = validate_final_record(") >= 0
		and main_body.find("if args.apply and not build_from_base:") >= 0
		and main_body.find(
			"tower_map_band_cloud_mist_z13c: apply_noop_final_already_valid"
		) >= 0,
		"Z13-c --apply on a valid final must validate every artifact and exit as a no-op"
	)


func _manifest_rect2i(value: Variant) -> Rect2i:
	if not (value is Array) or (value as Array).size() != 4:
		return Rect2i(-1, -1, -1, -1)
	var values := value as Array
	return Rect2i(
		int(values[0]),
		int(values[1]),
		int(values[2]),
		int(values[3])
	)


func _rect_inside_size(rect: Rect2i, size: Vector2i) -> bool:
	return (
		rect.size.x > 0
		and rect.size.y > 0
		and rect.position.x >= 0
		and rect.position.y >= 0
		and rect.end.x <= size.x
		and rect.end.y <= size.y
	)


func _mist_rect_key(rect: Rect2i) -> String:
	return "%d,%d,%d,%d" % [
		rect.position.x,
		rect.position.y,
		rect.size.x,
		rect.size.y,
	]


func _python_function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_function := source.find("\ndef ", start + signature.length())
	return source.substr(
		start,
		source.length() - start if next_function < 0 else next_function - start
	)


func _has_tileable_band_wrap(image: Image, comparison_rows: int) -> bool:
	var metrics := _measure_tileable_band_wrap(image, comparison_rows)
	return (
		bool(metrics.get("ready", false))
		and float(metrics.get("mean_abs_rgb_delta", INF))
			<= EXPECTED_BAND_TILEABLE_X4_PAIRED_MEAN_LIMIT
	)


func _measure_tileable_band_wrap(image: Image, comparison_rows: int) -> Dictionary:
	if (
		image == null
		or image.is_empty()
		or comparison_rows <= 0
		or comparison_rows * 2 > image.get_height()
	):
		return {"ready": false}
	var absolute_rgb_total := 0.0
	var maximum_channel_delta := 0
	var sample_count := image.get_width() * comparison_rows * 3
	for y in range(comparison_rows):
		var bottom_y := image.get_height() - comparison_rows + y
		for x in range(image.get_width()):
			var top: Color = image.get_pixel(x, y)
			var bottom: Color = image.get_pixel(x, bottom_y)
			var red_delta := absi(
				int(round(top.r * 255.0)) - int(round(bottom.r * 255.0))
			)
			var green_delta := absi(
				int(round(top.g * 255.0)) - int(round(bottom.g * 255.0))
			)
			var blue_delta := absi(
				int(round(top.b * 255.0)) - int(round(bottom.b * 255.0))
			)
			absolute_rgb_total += float(red_delta + green_delta + blue_delta)
			maximum_channel_delta = maxi(
				maximum_channel_delta,
				maxi(red_delta, maxi(green_delta, blue_delta))
			)
	return {
		"ready": sample_count > 0,
		"mean_abs_rgb_delta": (
			absolute_rgb_total / float(sample_count)
			if sample_count > 0
			else INF
		),
		"max_channel_delta": maximum_channel_delta,
	}


func _metric_triplet_within(metrics: Dictionary, thresholds: Dictionary) -> bool:
	return (
		not metrics.is_empty()
		and not thresholds.is_empty()
		and float(metrics.get("mean_abs_rgb_delta", INF))
			<= float(thresholds.get("mean_abs_rgb_delta", -INF))
		and float(metrics.get("p95_abs_rgb_delta", INF))
			<= float(thresholds.get("p95_abs_rgb_delta", -INF))
		and int(metrics.get("max_channel_delta", 256))
			<= int(thresholds.get("max_channel_delta", -1))
	)


func _measure_endpoint_row_luma_jump(image: Image) -> float:
	if image == null or image.is_empty() or image.get_width() <= 0:
		return INF
	var first_row_luma := 0.0
	var last_row_luma := 0.0
	var last_y := image.get_height() - 1
	for x in range(image.get_width()):
		var first: Color = image.get_pixel(x, 0)
		var last: Color = image.get_pixel(x, last_y)
		first_row_luma += (
			0.2126 * float(int(round(first.r * 255.0)))
			+ 0.7152 * float(int(round(first.g * 255.0)))
			+ 0.0722 * float(int(round(first.b * 255.0)))
		)
		last_row_luma += (
			0.2126 * float(int(round(last.r * 255.0)))
			+ 0.7152 * float(int(round(last.g * 255.0)))
			+ 0.0722 * float(int(round(last.b * 255.0)))
		)
	return absf(first_row_luma - last_row_luma) / float(image.get_width())


func _restore_z11_mirrored_band_edges(
	image: Image,
	top_rows: int,
	bottom_rows: int
) -> Image:
	var restored := image.duplicate()
	if (
		top_rows <= 0
		or bottom_rows <= 0
		or top_rows * 2 >= image.get_height()
		or bottom_rows * 2 >= image.get_height()
	):
		return restored
	var restored_top := image.get_region(Rect2i(
		0,
		top_rows,
		image.get_width(),
		top_rows
	))
	restored_top.flip_y()
	restored.blit_rect(
		restored_top,
		Rect2i(Vector2i.ZERO, restored_top.get_size()),
		Vector2i.ZERO
	)
	var restored_bottom := image.get_region(Rect2i(
		0,
		image.get_height() - bottom_rows * 2,
		image.get_width(),
		bottom_rows
	))
	restored_bottom.flip_y()
	restored.blit_rect(
		restored_bottom,
		Rect2i(Vector2i.ZERO, restored_bottom.get_size()),
		Vector2i(0, image.get_height() - bottom_rows)
	)
	return restored


func _mean_image_luma_8bit(image: Image) -> float:
	var sample := image.duplicate()
	sample.resize(1, 1, Image.INTERPOLATE_LANCZOS)
	var color: Color = sample.get_pixel(0, 0)
	return (0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b) * 255.0


func _sha256(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256) != OK:
		return ""
	hashing.update(bytes)
	return hashing.finish().hex_encode()


func _verify_approved_asset_catalog_and_dimensions() -> void:
	var catalog := TowerMapScrollAssetCatalog.new()
	var keys := catalog.get_asset_keys()
	_expect(keys.size() == EXPECTED_ASSET_COUNT, "the catalog must declare all 16 approved files")
	var declared_paths: Dictionary = {}
	for asset_key in keys:
		var path := catalog.resolve_declared_path(asset_key)
		_expect(path.begins_with("res://assets/sprites/tower/map_scroll/"), "%s must remain inside the canonical map-scroll root" % asset_key)
		_expect(path.ends_with("_x4.png"), "%s must use the versioned Real-ESRGAN x4 candidate" % asset_key)
		_expect(path.find("_candidate") < 0, "%s runtime path must not retain candidate naming" % asset_key)
		_expect(not declared_paths.has(path), "%s must own a distinct bitmap" % asset_key)
		declared_paths[path] = true
		_expect(ResourceLoader.exists(path, "Texture2D"), "%s must have an imported Texture2D" % asset_key)
		var cold := catalog.get_cached_resolution(asset_key)
		_expect(not bool(cold.get("cached", true)), "%s cold draw peek must not touch the filesystem" % asset_key)
	var prewarm := catalog.prewarm_all()
	_expect(bool(prewarm.get("ready", false)), "all approved files must prewarm")
	_expect(int(prewarm.get("entry_count", 0)) == EXPECTED_ASSET_COUNT, "prewarm must cache all 16 approved files")
	for asset_key in keys:
		var resolution := catalog.get_cached_resolution(asset_key)
		var texture := resolution.get("texture", null) as Texture2D
		_expect(bool(resolution.get("ready", false)), "%s must pass its explicit dimension contract" % asset_key)
		_expect(texture != null, "%s must resolve as Texture2D" % asset_key)
		if texture != null:
			_expect(
				Vector2i(texture.get_size()) == catalog.get_expected_texture_size(asset_key),
				"%s must use its declared x4 texture density" % asset_key
			)
			var world_size := catalog.get_expected_size(asset_key)
			var expected_world_size := (
				Vector2i(620, 48)
				if asset_key == TowerMapScrollAssetCatalog.FLOOR_GATE_PLAQUE
				else catalog.get_expected_size(asset_key)
				if asset_key in TowerMapScrollAssetCatalog.CLOUD_ASSET_KEYS
				else Vector2i(72, 320)
				if asset_key in [
					TowerMapScrollAssetCatalog.ROUTE_BRUSH_UNSELECTED,
					TowerMapScrollAssetCatalog.ROUTE_BRUSH_AVAILABLE,
					TowerMapScrollAssetCatalog.ROUTE_BRUSH_COMPLETED_GOLD,
				]
				else Vector2i(692, 320)
			)
			_expect(
				world_size == expected_world_size,
				"%s x4 density must not change authored world geometry" % asset_key
			)
	var first_key := str(keys[0])
	var mutable_copy := catalog.get_cached_resolution(first_key)
	mutable_copy["ready"] = false
	_expect(bool(catalog.get_cached_resolution(first_key).get("ready", false)), "GRT-032: cached resolutions must be shallow defensive copies")
	var debug_state := catalog.get_debug_state()
	_expect(int(debug_state.get("filesystem_probe_count", -1)) == EXPECTED_ASSET_COUNT, "each approved path must be probed exactly once")
	_expect(int(debug_state.get("resource_load_count", -1)) == EXPECTED_ASSET_COUNT, "each approved texture must load exactly once")
	_leg_count += 1


func _verify_negative_cache_and_missing_asset_fallback() -> void:
	var canonical := TowerMapScrollAssetCatalog.new()
	var missing_key := TowerMapScrollAssetCatalog.HUMAN_BAND_ASSET_KEYS[1]
	var missing_path := canonical.resolve_declared_path(missing_key)
	var catalog := TowerMapScrollAssetCatalog.new(
		func(path: String) -> bool:
			return path != missing_path and ResourceLoader.exists(path, "Texture2D"),
		func(path: String) -> Resource:
			return ResourceLoader.load(path, "Texture2D")
	)
	var first := catalog.prewarm_asset(missing_key)
	var second := catalog.prewarm_asset(missing_key)
	_expect(not bool(first.get("ready", true)), "a deleted approved file must select the procedural fallback")
	_expect(str(first.get("reason", "")) == "missing_asset", "a deleted approved file must preserve the missing_asset reason")
	_expect(first.get("texture", null) == null, "a missing file must not fabricate a texture")
	_expect(bool(second.get("cache_hit", false)), "GRT-004: a missing path must remain negatively cached")
	var debug_state := catalog.get_debug_state()
	_expect(int(debug_state.get("filesystem_probe_count", -1)) == 1, "a repeated missing path must not be statted every frame")
	_expect(int(debug_state.get("resource_load_count", -1)) == 0, "a missing path must never reach ResourceLoader.load")
	_leg_count += 1


func _verify_deterministic_nonrepeating_floor_variants() -> void:
	var catalog := TowerMapScrollAssetCatalog.new()
	var previous_key := ""
	var first_pass: Array[String] = []
	for floor_number in range(1, 13):
		var realm_kind := (
			TowerMapScrollAssetCatalog.REALM_IMMORTAL
			if floor_number >= 10
			else TowerMapScrollAssetCatalog.REALM_HUMAN
		)
		var asset_key := TowerMapScrollAssetCatalog.resolve_band_asset_key(realm_kind, floor_number, previous_key)
		_expect(asset_key != previous_key, "adjacent floors %d/%d must not reuse one band variant" % [floor_number - 1, floor_number])
		first_pass.append(asset_key)
		previous_key = asset_key
	var second_pass: Array[String] = []
	previous_key = ""
	for floor_number in range(1, 13):
		var realm_kind := TowerMapScrollAssetCatalog.REALM_IMMORTAL if floor_number >= 10 else TowerMapScrollAssetCatalog.REALM_HUMAN
		var asset_key := TowerMapScrollAssetCatalog.resolve_band_asset_key(realm_kind, floor_number, previous_key)
		second_pass.append(asset_key)
		previous_key = asset_key
	_expect(first_pass == second_pass, "floor band selection must be deterministic and gameplay-RNG free")
	_leg_count += 1


func _verify_opaque_floor_tile_render_model_and_fallback() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {
		"run_id": "tower-map-scroll-bands",
		"map_seed": 83521,
	}), "the S3 render fixture must begin")
	var renderer := flow.get("_renderer") as Object
	_expect(renderer != null, "the S3 fixture must use its production-prewarmed renderer")
	var model: Dictionary = renderer.call(
		"build_fullscreen_map_model",
		flow,
		Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))
	)
	var background: Dictionary = model.get("scroll_background", {})
	_expect(bool(background.get("ready", false)), "the live fullscreen model must select approved opaque bands")
	var tiles: Array = background.get("tiles", [])
	var draw_chunks: Array = background.get("draw_chunks", [])
	var production_global_rows: Dictionary = {}
	for phase_variant in flow.get_graph_phases():
		if not (phase_variant is Dictionary):
			continue
		for node_variant in (phase_variant as Dictionary).get("nodes", []):
			if not (node_variant is Dictionary):
				continue
			var global_row := int((node_variant as Dictionary).get("global_row", -1))
			if global_row >= 0:
				production_global_rows[global_row] = true
	_expect(
		production_global_rows.size() == EXPECTED_STANDARD_MAP_ROW_COUNT,
		"the Y1 compact standard map must retain 32 generated rows"
	)
	_expect(
		tiles.size() == (model.get("floor_bands", []) as Array).size()
		and tiles.size() == 12,
		"the default overview must retain one approved band-art contract for floors 1 through 12"
	)
	_expect(draw_chunks.size() >= tiles.size(), "expanded segments must expose every opaque repeated/cropped draw chunk")
	var world_rect: Rect2 = model.get("world_rect", Rect2())
	var tile_world_rect: Rect2 = background.get("world_rect", Rect2())
	var camera: Dictionary = model.get("camera", {})
	var camera_offset: Vector2 = camera.get("offset", Vector2.ZERO)
	var camera_view_rect: Rect2 = model.get("camera_view_rect", Rect2())
	var camera_world_rect: Rect2 = model.get("camera_world_rect", Rect2())
	var camera_render_zoom := float(camera.get("render_zoom_multiplier", 0.0))
	var projected_camera_world := Rect2(
		camera_world_rect.position * camera_render_zoom + camera_offset,
		camera_world_rect.size * camera_render_zoom
	)
	var content_rect: Rect2 = model.get("content_rect", Rect2())
	var map_scale := float(model.get("map_scale", 0.0))
	var previous_key := ""
	var previous_floor := 0
	var asset_key_by_floor := {}
	_expect(is_equal_approx(world_rect.size.x, content_rect.size.x), "the M-key scroll world must fit the live content width")
	var expected_default_zoom := clampf(
		float(model.get("minimum_cover_zoom", 0.0))
			/ TowerAscentTuning.TEMP_MAP_DEFAULT_ZOOMOUT_DIVISOR,
		float(model.get("minimum_fit_all_zoom", 0.0)),
		float(model.get("minimum_cover_zoom", 0.0))
	)
	_expect(is_equal_approx(camera_render_zoom, expected_default_zoom), "the M-key camera must derive four wheel-down notches from its viewport cover")
	_expect(bool(model.get("subcover_active", false)), "the M-key default must activate the explicit scroll surround")
	_expect(
		projected_camera_world.position.x > camera_view_rect.position.x + 0.01
			and projected_camera_world.end.x < camera_view_rect.end.x - 0.01
			and projected_camera_world.position.y <= camera_view_rect.position.y + 0.01
			and projected_camera_world.end.y >= camera_view_rect.end.y - 0.01,
		"the default scroll must expose only horizontal surround while retaining vertical art coverage"
	)
	for index in range(tiles.size()):
		var tile := tiles[index] as Dictionary
		var tile_rect: Rect2 = tile.get("rect", Rect2())
		var asset_key := str(tile.get("asset_key", ""))
		_expect(tile.get("texture", null) is Texture2D, "every visible floor tile must own a cached band texture")
		_expect(tile.get("paper_texture", null) is Texture2D, "the approved common paper must sit below every opaque band")
		_expect(
			asset_key != previous_key,
			"adjacent rendered floors %d/%d must not repeat variant %s"
				% [previous_floor, int(tile.get("floor", 0)), asset_key]
		)
		_expect(is_equal_approx(tile_rect.position.x, tile_world_rect.position.x) and is_equal_approx(tile_rect.size.x, tile_world_rect.size.x), "every band must span the scroll width")
		_expect(tile_rect.size.is_equal_approx(Vector2(692.0, 320.0) * map_scale), "each opaque band must preserve its approved aspect ratio at M-key content scale: floor=%d size=%s" % [int(tile.get("floor", 0)), str(tile_rect.size)])
		asset_key_by_floor[int(tile.get("floor", 0))] = asset_key
		previous_key = asset_key
		previous_floor = int(tile.get("floor", 0))
	var previous_end_y := tile_world_rect.position.y
	_expect(
		is_equal_approx(
			float(renderer.call("get_map_scroll_band_seam_overlap_world_px")),
			EXPECTED_BAND_SEAM_OVERLAP_WORLD_PX
		),
		"different-art chunks must retain the approved 16px base-world dissolve"
	)
	_expect(
		is_equal_approx(
			float(renderer.call("get_map_scroll_band_source_edge_guard_world_px")),
			EXPECTED_BAND_SOURCE_EDGE_GUARD_WORLD_PX
		),
		"Z13 tileable bands must sample the true source edge without a runtime guard"
	)
	var expected_overlap := EXPECTED_BAND_SEAM_OVERLAP_WORLD_PX * map_scale
	var expected_tile_height := 320.0 * map_scale
	_expect(
		draw_chunks.size() == EXPECTED_PRODUCTION_DRAW_CHUNK_COUNT,
		"the 32-row Y1 map must retain its 21 production draw chunks"
	)
	_expect(
		int(background.get("draw_call_count", -1)) == draw_chunks.size() * 2,
		"tileable bodies and forward entries must remain one art draw per chunk"
	)
	var first_band_scale := _chunk_vertical_scale(draw_chunks[0] as Dictionary, "texture")
	var first_chunk := draw_chunks[0] as Dictionary
	var first_paper_scale := _chunk_vertical_scale_for_rects(
		first_chunk.get("paper_rect", Rect2()),
		first_chunk.get("paper_source_rect", Rect2()),
		first_chunk.get("paper_texture", null) as Texture2D
	)
	var production_scales_match := true
	var production_repeat_bounds_ok := true
	var production_c0_ok := true
	var production_repeat_enabled := true
	var production_same_asset_butt_count := 0
	var production_cross_asset_dissolve_count := 0
	var production_reflected_tail_count := 0
	var previous_chunk_asset_key := ""
	var previous_body_source_phase_world_px := 0.0
	var previous_chunk_height := 0.0
	for chunk_index in range(draw_chunks.size()):
		var chunk_variant: Variant = draw_chunks[chunk_index]
		var chunk := chunk_variant as Dictionary
		var chunk_rect: Rect2 = chunk.get("rect", Rect2())
		var chunk_asset_key := str(chunk.get("asset_key", ""))
		var alpha_ramp_world_px := float(chunk.get("alpha_ramp_world_px", -1.0))
		var forward_dissolve_world_px := float(chunk.get(
			"forward_dissolve_world_px",
			-1.0
		))
		var body_source_phase_world_px := float(chunk.get(
			"body_source_phase_world_px",
			-1.0
		))
		var source_rect: Rect2 = chunk.get(
			"normalized_source_rect",
			Rect2(0.0, 0.0, 1.0, 1.0)
		)
		var paper_rect: Rect2 = chunk.get("paper_rect", Rect2())
		var paper_source_rect: Rect2 = chunk.get("paper_source_rect", Rect2())
		var seam_entry_rect: Rect2 = chunk.get("seam_entry_rect", Rect2())
		var seam_entry_source_rect: Rect2 = chunk.get("seam_entry_source_rect", Rect2())
		var seam_tail_rect: Rect2 = chunk.get("seam_tail_rect", Rect2())
		var seam_tail_source_rect: Rect2 = chunk.get("seam_tail_source_rect", Rect2())
		var repeat_texture := chunk.get("texture", null) as CanvasTexture
		var has_previous_chunk := chunk_index > 0
		var same_asset_as_previous := (
			has_previous_chunk and chunk_asset_key == previous_chunk_asset_key
		)
		var cross_asset_boundary := has_previous_chunk and not same_asset_as_previous
		var expected_seam_kind := (
			"map_top"
			if not has_previous_chunk
			else "same_asset_butt" if same_asset_as_previous else "cross_asset_forward"
		)
		var required_overlap := expected_overlap if cross_asset_boundary else 0.0
		var expected_body_source_phase_world_px := 0.0
		if same_asset_as_previous:
			expected_body_source_phase_world_px = fposmod(
				previous_body_source_phase_world_px + previous_chunk_height,
				expected_tile_height
			)
		elif cross_asset_boundary:
			expected_body_source_phase_world_px = required_overlap
		_expect(repeat_texture != null, "every opaque draw chunk must own its repeat wrapper")
		var repeat_enabled: bool = (
			repeat_texture != null
			and repeat_texture.diffuse_texture == chunk.get("source_texture", null)
			and repeat_texture.texture_repeat == CanvasItem.TEXTURE_REPEAT_ENABLED
		)
		production_repeat_enabled = production_repeat_enabled and repeat_enabled
		_expect(repeat_enabled, "every band body must repeat vertically through its cached CanvasTexture")
		_expect(chunk.get("paper_texture", null) is Texture2D, "every opaque draw chunk must retain the common paper underlay")
		_expect(
			str(chunk.get("asset_key", ""))
				== str(asset_key_by_floor.get(int(chunk.get("floor", 0)), "")),
			"every repeated/cropped chunk must retain its floor's selected variant"
		)
		_expect(
			is_equal_approx(chunk_rect.position.x, tile_world_rect.position.x)
			and is_equal_approx(chunk_rect.size.x, tile_world_rect.size.x),
			"every repeated band chunk must span the scroll width"
		)
		_expect(
			is_equal_approx(paper_rect.position.y, previous_end_y)
			and chunk_rect.is_equal_approx(paper_rect),
			"every tileable band body must fill its complete logical paper chunk"
		)
		_expect(
			str(chunk.get("seam_kind", "")) == expected_seam_kind,
			"every chunk must classify map-top, same-art butt, or different-art entry"
		)
		_expect(
			is_equal_approx(alpha_ramp_world_px, required_overlap)
			and is_equal_approx(forward_dissolve_world_px, required_overlap)
			and is_equal_approx(
				float(chunk.get("source_edge_guard_world_px", -1.0)),
				0.0
			),
			"only different-art boundaries may own the unguarded 16px forward dissolve"
		)
		_expect(
			not chunk.has("reflected_tail_world_px")
			and not chunk.has("seam_tail_rect")
			and not chunk.has("seam_tail_source_rect")
			and not seam_tail_rect.has_area()
			and not seam_tail_source_rect.has_area(),
			"Z13 must not retain reflected or forward tail phase geometry"
		)
		if (
			chunk.has("reflected_tail_world_px")
			or seam_tail_rect.has_area()
			or seam_tail_source_rect.has_area()
		):
			production_reflected_tail_count += 1
		_expect(
			is_equal_approx(
				source_rect.size.y,
				chunk_rect.size.y / (320.0 * map_scale)
			),
			"full band-body source and target heights must preserve native scale"
		)
		_expect(
			is_equal_approx(body_source_phase_world_px, expected_body_source_phase_world_px)
			and is_equal_approx(
				source_rect.position.y,
				expected_body_source_phase_world_px / expected_tile_height
			),
			"every body must carry the modulo source phase without rewind"
		)
		var body_repeat_bounds_ok := (
			source_rect.position.y >= -0.0001
			and source_rect.end.y
				<= 1.0 + expected_overlap / expected_tile_height + 0.0001
		)
		var paper_source_bounds_ok := (
			paper_source_rect.position.y >= -0.0001
			and paper_source_rect.end.y <= 1.0001
		)
		production_repeat_bounds_ok = (
			production_repeat_bounds_ok
			and body_repeat_bounds_ok
			and paper_source_bounds_ok
		)
		_expect(
			body_repeat_bounds_ok,
			"body UVs may exceed one dissolve span only through the repeat wrapper"
		)
		_expect(
			paper_source_bounds_ok,
			"every paper source rect must stay inside normalized texture bounds"
		)
		if not has_previous_chunk:
			_expect(
				not seam_entry_rect.has_area()
				and not seam_entry_source_rect.has_area(),
				"the map-top chunk must omit incoming seam phase geometry"
			)
		elif same_asset_as_previous:
			production_same_asset_butt_count += 1
			var same_asset_c0 := (
				not seam_entry_rect.has_area()
				and not seam_entry_source_rect.has_area()
				and is_equal_approx(
					fposmod(
						previous_body_source_phase_world_px + previous_chunk_height,
						expected_tile_height
					),
					body_source_phase_world_px
				)
			)
			production_c0_ok = production_c0_ok and same_asset_c0
			_expect(
				same_asset_c0,
				"same-art chunks must meet as a phase-free modulo-continuous butt joint"
			)
		else:
			production_cross_asset_dissolve_count += 1
			_expect(
				is_equal_approx(seam_entry_rect.position.y, paper_rect.position.y - required_overlap)
				and is_equal_approx(seam_entry_rect.end.y, paper_rect.position.y),
				"every real seam must own one bounded incoming phase strip"
			)
			var entry_source_bounds_ok := (
				seam_entry_source_rect.position.y >= -0.0001
				and seam_entry_source_rect.end.y <= 1.0001
			)
			production_repeat_bounds_ok = (
				production_repeat_bounds_ok and entry_source_bounds_ok
			)
			_expect(
				entry_source_bounds_ok,
				"every seam-entry source rect must stay inside normalized texture bounds"
			)
			_expect(
				is_equal_approx(
					seam_entry_source_rect.position.y,
					0.0
				)
				and is_equal_approx(
					seam_entry_source_rect.size.y,
					required_overlap / (320.0 * map_scale)
				),
				"every different-art entry must sample forward from source row zero"
			)
			var cross_asset_c0 := is_equal_approx(
				seam_entry_source_rect.end.y,
				source_rect.position.y
			)
			production_c0_ok = production_c0_ok and cross_asset_c0
			_expect(
				cross_asset_c0,
				"the forward entry must end on the full body's first source row"
			)
			_expect(
				is_equal_approx(
					_chunk_vertical_scale_for_rects(
						seam_entry_rect,
						seam_entry_source_rect,
						chunk.get("texture", null) as Texture2D
					),
					first_band_scale
				),
				"every forward seam entry must preserve native art scale"
			)
		var band_scale_matches := is_equal_approx(
			_chunk_vertical_scale(chunk, "texture"),
			first_band_scale
		)
		var paper_scale_matches := is_equal_approx(
			_chunk_vertical_scale_for_rects(
				paper_rect,
				paper_source_rect,
				chunk.get("paper_texture", null) as Texture2D
			),
			first_paper_scale
		)
		production_scales_match = (
			production_scales_match and band_scale_matches and paper_scale_matches
		)
		_expect(
			band_scale_matches,
			"band layer scale must match the first chunk for every production chunk"
		)
		_expect(
			paper_scale_matches,
			"paper layer scale must match the first chunk for every production chunk"
		)
		_expect(not chunk.has("content_rect"), "content_rect must not survive as duplicate dead geometry")
		_expect(chunk.has("paper_rect"), "paper_rect must remain the live logical chunk geometry")
		previous_end_y = paper_rect.end.y
		previous_chunk_asset_key = chunk_asset_key
		previous_body_source_phase_world_px = body_source_phase_world_px
		previous_chunk_height = paper_rect.size.y
	_expect(
		production_same_asset_butt_count == EXPECTED_PRODUCTION_SAME_ASSET_BUTT_COUNT
		and production_cross_asset_dissolve_count
			== EXPECTED_PRODUCTION_CROSS_ASSET_DISSOLVE_COUNT
		and production_reflected_tail_count == 0,
		"21 chunks must split into 9 same-art butts, 11 forward dissolves, and 0 tails"
	)
	_expect(
		is_equal_approx(previous_end_y, tile_world_rect.end.y),
		"the opaque tile stack must cover the complete scroll world: end=%.3f expected=%.3f"
			% [previous_end_y, tile_world_rect.end.y]
	)
	print(
		"[TowerMapBandTileableInvariant] production_chunks=%d scale_match=%s band_scale=%.6f paper_scale=%.6f repeat_bounds=%s repeat_enabled=%s c0=%s same_asset_butts=%d forward_dissolves=%d reflected_tails=%d"
			% [
				draw_chunks.size(),
				str(production_scales_match),
				first_band_scale,
				first_paper_scale,
				str(production_repeat_bounds_ok),
				str(production_repeat_enabled),
				str(production_c0_ok),
				production_same_asset_butt_count,
				production_cross_asset_dissolve_count,
				production_reflected_tail_count,
			]
	)
	var legacy_model: Dictionary = renderer.call("build_render_model", flow)
	var legacy: Dictionary = legacy_model.get("legacy_scroll_background", {})
	_expect(bool(legacy.get("ready", false)), "the transformed legacy surface must use the same approved tiles")

	var catalog := TowerMapScrollAssetCatalog.new()
	catalog.prewarm_all()
	var resolutions: Dictionary = {}
	for asset_key in catalog.get_asset_keys():
		resolutions[asset_key] = catalog.get_cached_resolution(asset_key)
	var missing_key := str((tiles[0] as Dictionary).get("asset_key", ""))
	var missing_resolution: Dictionary = (resolutions[missing_key] as Dictionary).duplicate(false)
	missing_resolution["ready"] = false
	missing_resolution["texture"] = null
	resolutions[missing_key] = missing_resolution
	var fallback: Dictionary = renderer.build_scroll_background_model(
		model.get("floor_bands", []),
		world_rect,
		str(model.get("realm_kind", "human_realm")),
		resolutions
	)
	_expect(not bool(fallback.get("ready", true)), "a missing used band must keep the procedural fallback alive")
	_expect(str(fallback.get("reason", "")) == "band_unavailable", "the fallback must identify its missing band gate")
	var renderer_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	)
	var phase_draw_body := _function_body(
		renderer_source,
		"func _draw_scroll_texture_phase("
	)
	_expect(renderer_source.find("draw_texture_rect_region") >= 0, "S3 must crop only camera-visible source regions")
	_expect(
		renderer.has_method("resolve_scroll_texture_phase_sample"),
		"band entries must retain their production-called phase sampler"
	)
	var projected_entry := Rect2(0.0, 0.0, 1.0, 16.0)
	var projected_body := Rect2(0.0, 16.0, 1.0, 320.0)
	var entry_source := Rect2(0.0, 0.0, 1.0, 16.0 / 320.0)
	var body_source := Rect2(0.0, 16.0 / 320.0, 1.0, 1.0)
	var entry_start: Vector2 = renderer.call(
		"resolve_scroll_texture_phase_sample",
		projected_entry.position.y,
		true,
		projected_entry,
		projected_body,
		entry_source,
		body_source
	)
	var entry_end: Vector2 = renderer.call(
		"resolve_scroll_texture_phase_sample",
		projected_entry.end.y,
		true,
		projected_entry,
		projected_body,
		entry_source,
		body_source
	)
	var body_start: Vector2 = renderer.call(
		"resolve_scroll_texture_phase_sample",
		projected_body.position.y,
		false,
		projected_entry,
		projected_body,
		entry_source,
		body_source
	)
	var body_end: Vector2 = renderer.call(
		"resolve_scroll_texture_phase_sample",
		projected_body.end.y,
		false,
		projected_entry,
		projected_body,
		entry_source,
		body_source
	)
	_expect(
		entry_start.is_equal_approx(Vector2(0.0, 0.0))
		and entry_end.is_equal_approx(Vector2(16.0 / 320.0, 1.0))
		and entry_end.x > entry_start.x,
		"restoring reverse entry sampling must turn the production phase helper RED"
	)
	_expect(
		body_start.is_equal_approx(entry_end)
		and body_end.is_equal_approx(Vector2(1.0 + 16.0 / 320.0, 1.0)),
		"restoring the body to source row zero must turn the production phase helper RED"
	)
	_expect(
		renderer_source.find("reflected_tail_world_px") < 0
		and renderer_source.find("tail_source_rect") < 0,
		"the production renderer must not retain any reflected-tail restoration path"
	)
	_expect(
		phase_draw_body.find("var has_entry := entry_rect.has_area()") >= 0
		and phase_draw_body.find("resolve_scroll_texture_phase_sample(") >= 0
		and phase_draw_body.find("_draw_scroll_texture_region(") < 0
		and phase_draw_body.find("CanvasItem.TEXTURE_REPEAT_ENABLED") < 0,
		"same-art and cross-art bodies must share the repeat-safe polygon path"
	)
	_expect(renderer_source.find("canvas.draw_polygon(polygon_points, colors, uvs, texture)") >= 0, "the seam ramp must remain one polygon draw per RGB band chunk")
	_expect(renderer_source.find("draw_rect(MAP_RECT, PAPER, true)") >= 0, "S3 must retain the procedural paper fallback")
	_leg_count += 1


func _verify_band_chunk_scale_invariant_boundary_fixture() -> void:
	var catalog := TowerMapScrollAssetCatalog.new()
	catalog.prewarm_all()
	var resolutions: Dictionary = {}
	for asset_key in catalog.get_asset_keys():
		resolutions[asset_key] = catalog.get_cached_resolution(asset_key)
	var floor_band_heights := PackedFloat32Array([320.0, 740.0, 160.0])
	var floor_bands: Array[Dictionary] = []
	var chunk_y := 0.0
	for index in range(floor_band_heights.size()):
		var band_height := float(floor_band_heights[index])
		floor_bands.append({
			"segment_floor": index + 1,
			"realm_kind": "human_realm",
			"segment_rect": Rect2(0.0, chunk_y, 692.0, band_height),
			"y": chunk_y + band_height * 0.5,
		})
		chunk_y += band_height
	var renderer := TowerAscentFlowRenderer.new()
	var model := renderer.build_scroll_background_model(
		floor_bands,
		Rect2(0.0, 0.0, 692.0, chunk_y),
		"human_realm",
		resolutions,
		Vector2(692.0, 320.0)
	)
	_expect(bool(model.get("ready", false)), "scale boundary fixture must resolve approved textures")
	var chunks: Array = model.get("draw_chunks", [])
	var expected_chunk_heights := PackedFloat32Array([320.0, 320.0, 320.0, 100.0, 160.0])
	_expect(
		chunks.size() == expected_chunk_heights.size(),
		"scale boundary fixture must retain full, repeated, cap, and cross-art chunks"
	)
	if chunks.size() != expected_chunk_heights.size():
		_leg_count += 1
		return
	var expected_fades := PackedFloat32Array([0.0, 16.0, 0.0, 0.0, 16.0])
	var expected_phases := PackedFloat32Array([0.0, 16.0, 16.0, 16.0, 16.0])
	var expected_entry_heights := PackedFloat32Array([0.0, 16.0, 0.0, 0.0, 16.0])
	var expected_seam_kinds := PackedStringArray([
		"map_top",
		"cross_asset_forward",
		"same_asset_butt",
		"same_asset_butt",
		"cross_asset_forward",
	])
	var first_band_scale := _chunk_vertical_scale(chunks[0] as Dictionary, "texture")
	var first_chunk := chunks[0] as Dictionary
	var first_paper_scale := _chunk_vertical_scale_for_rects(
		first_chunk.get("paper_rect", Rect2()),
		first_chunk.get("paper_source_rect", Rect2()),
		first_chunk.get("paper_texture", null) as Texture2D
	)
	var boundary_scales_match := true
	var boundary_repeat_bounds_ok := true
	var boundary_c0_ok := true
	var boundary_same_asset_butts := 0
	var boundary_forward_dissolves := 0
	for index in range(chunks.size()):
		var chunk := chunks[index] as Dictionary
		var chunk_rect: Rect2 = chunk.get("rect", Rect2())
		var source_rect: Rect2 = chunk.get("normalized_source_rect", Rect2())
		var paper_rect: Rect2 = chunk.get("paper_rect", Rect2())
		var paper_source_rect: Rect2 = chunk.get("paper_source_rect", Rect2())
		var entry_rect: Rect2 = chunk.get("seam_entry_rect", Rect2())
		var entry_source_rect: Rect2 = chunk.get("seam_entry_source_rect", Rect2())
		_expect(
			chunk_rect.is_equal_approx(paper_rect)
			and is_equal_approx(chunk_rect.size.y, float(expected_chunk_heights[index])),
			"boundary chunk %d tileable body must fill its complete paper chunk" % index
		)
		_expect(
			is_equal_approx(float(chunk.get("alpha_ramp_world_px", -1.0)), float(expected_fades[index])),
			"boundary chunk %d must dissolve only when its asset changes" % index
		)
		_expect(
			is_equal_approx(float(chunk.get("source_edge_guard_world_px", -1.0)), 0.0),
			"boundary chunk %d must not reintroduce a source-edge guard" % index
		)
		_expect(
			str(chunk.get("seam_kind", "")) == str(expected_seam_kinds[index])
			and is_equal_approx(entry_rect.size.y, float(expected_entry_heights[index])),
			"boundary chunk %d must classify its butt or forward entry" % index
		)
		_expect(
			not chunk.has("reflected_tail_world_px")
			and not chunk.has("seam_tail_rect")
			and not chunk.has("seam_tail_source_rect"),
			"boundary chunk %d must not own any tail phase" % index
		)
		_expect(
			is_equal_approx(
				float(chunk.get("body_source_phase_world_px", -1.0)),
				float(expected_phases[index])
			)
			and is_equal_approx(
				source_rect.position.y,
				float(expected_phases[index]) / 320.0
			)
			and is_equal_approx(
				source_rect.size.y,
				float(expected_chunk_heights[index]) / 320.0
			),
			"boundary chunk %d must preserve its full native-scale body phase" % index
		)
		var repeat_texture := chunk.get("texture", null) as CanvasTexture
		var source_bounds_ok := (
			source_rect.position.y >= -0.0001 and source_rect.end.y <= 1.0001
				+ EXPECTED_BAND_SEAM_OVERLAP_WORLD_PX / 320.0
			and paper_source_rect.position.y >= -0.0001
			and paper_source_rect.end.y <= 1.0001
			and entry_source_rect.position.y >= -0.0001
			and entry_source_rect.end.y <= 1.0001
			and repeat_texture != null
			and repeat_texture.texture_repeat == CanvasItem.TEXTURE_REPEAT_ENABLED
		)
		boundary_repeat_bounds_ok = boundary_repeat_bounds_ok and source_bounds_ok
		_expect(
			source_bounds_ok,
			"320/160/cap bodies may exceed [0,1] only by one repeated dissolve span"
		)
		if expected_seam_kinds[index] == "same_asset_butt":
			boundary_same_asset_butts += 1
			var previous_chunk := chunks[index - 1] as Dictionary
			var same_c0 := is_equal_approx(
				fposmod(
					float(previous_chunk.get("body_source_phase_world_px", 0.0))
						+ float((previous_chunk.get("paper_rect", Rect2()) as Rect2).size.y),
					320.0
				),
				float(chunk.get("body_source_phase_world_px", -1.0))
			)
			boundary_c0_ok = boundary_c0_ok and same_c0
			_expect(same_c0 and not entry_rect.has_area(), "same-art boundary must be a C0 butt")
		elif expected_seam_kinds[index] == "cross_asset_forward":
			boundary_forward_dissolves += 1
			var cross_c0 := (
				is_equal_approx(entry_source_rect.position.y, 0.0)
				and is_equal_approx(entry_source_rect.size.y, 16.0 / 320.0)
				and is_equal_approx(entry_source_rect.end.y, source_rect.position.y)
			)
			boundary_c0_ok = boundary_c0_ok and cross_c0
			_expect(cross_c0, "different-art entry must join the r-offset body without rewind")
		var band_scale_matches := is_equal_approx(
			_chunk_vertical_scale(chunk, "texture"),
			first_band_scale
		)
		var paper_scale_matches := is_equal_approx(
			_chunk_vertical_scale_for_rects(
				paper_rect,
				paper_source_rect,
				chunk.get("paper_texture", null) as Texture2D
			),
			first_paper_scale
		)
		boundary_scales_match = (
			boundary_scales_match and band_scale_matches and paper_scale_matches
		)
		_expect(
			band_scale_matches,
			"320/160/cap band scale must match the first 320px chunk"
		)
		_expect(
			paper_scale_matches,
			"320/160/cap paper scale must match the first 320px chunk"
		)
	print(
		"[TowerMapBandTileableBoundary] chunk_heights=320,320,320,100,160 entries=0,16,0,0,16 tails=0,0,0,0,0 phases=0,16,16,16,16 same_asset_butts=%d forward_dissolves=%d scale_match=%s repeat_bounds=%s c0=%s band_scale=%.6f paper_scale=%.6f"
			% [
				boundary_same_asset_butts,
				boundary_forward_dissolves,
				str(boundary_scales_match),
				str(boundary_repeat_bounds_ok),
				str(boundary_c0_ok),
				first_band_scale,
				first_paper_scale,
			]
	)
	_leg_count += 1


func _chunk_vertical_scale(chunk: Dictionary, texture_key: String) -> float:
	var texture := chunk.get(texture_key, null) as Texture2D
	var target_rect: Rect2 = chunk.get("rect", Rect2())
	var source_rect: Rect2 = chunk.get("normalized_source_rect", Rect2())
	if texture == null or source_rect.size.y <= 0.0 or texture.get_height() <= 0:
		return -1.0
	return target_rect.size.y / (source_rect.size.y * float(texture.get_height()))


func _chunk_vertical_scale_for_rects(
	target_rect: Rect2,
	source_rect: Rect2,
	texture: Texture2D
) -> float:
	if texture == null or source_rect.size.y <= 0.0 or texture.get_height() <= 0:
		return -1.0
	return target_rect.size.y / (source_rect.size.y * float(texture.get_height()))


func _verify_fullscreen_draw_call_budget_lockstep() -> void:
	var worst_seed := -1
	var worst_draw_calls := -1
	var worst_background_draw_calls := -1
	for map_seed in range(1, 129):
		var flow := TowerAscentFlowOwner.new()
		_expect(flow.begin_vertical_slice(null, Callable(), {
			"run_id": "tower-map-band-seam-budget-%d" % map_seed,
			"map_seed": map_seed,
		}), "the draw-call budget fixture must begin for seed %d" % map_seed)
		var renderer := flow.get("_renderer") as Object
		_expect(
			renderer != null,
			"seed %d budget fixture must use its production-prewarmed renderer" % map_seed
		)
		var model: Dictionary = renderer.call(
			"build_fullscreen_map_model",
			flow,
			Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))
		)
		var debug_state: Dictionary = renderer.call("get_render_cache_debug_state")
		var draw_calls := int(debug_state.get("total_map_draw_call_budget", -1))
		var background: Dictionary = model.get("scroll_background", {})
		var background_draw_calls := int(background.get("draw_call_count", -1))
		_expect(
			draw_calls <= TowerAscentTuning.TEMP_MAP_PATH_DRAW_CALL_BUDGET,
			"seed %d map draw calls %d must stay within the sealed %d ceiling"
				% [map_seed, draw_calls, TowerAscentTuning.TEMP_MAP_PATH_DRAW_CALL_BUDGET]
		)
		_expect(
			background_draw_calls
				== (background.get("draw_chunks", []) as Array).size() * 2,
			"seed %d must retain one paper and one phase-mapped art draw per chunk"
				% map_seed
		)
		if draw_calls > worst_draw_calls:
			worst_seed = map_seed
			worst_draw_calls = draw_calls
			worst_background_draw_calls = background_draw_calls
		if flow.has_method("_finish_vertical_slice"):
			flow.call("_finish_vertical_slice")
	print(
		"[TowerMapBandSeamBudget] seeds=128 worst_seed=%d map_draw_calls=%d/%d background_draw_calls=%d"
			% [
				worst_seed,
				worst_draw_calls,
				TowerAscentTuning.TEMP_MAP_PATH_DRAW_CALL_BUDGET,
				worst_background_draw_calls,
			]
	)
	_leg_count += 1


func _verify_production_prewarm_order_and_draw_peek_contract() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var flow := TowerAscentFlowOwner.new()
	var production_renderer := flow.get("_renderer") as Object
	_expect(
		production_renderer != null,
		"the production flow must expose its renderer"
	)
	var cold_repeat_state := flow.get_map_scroll_asset_debug_state()
	_expect(
		int(cold_repeat_state.get("entry_count", -1)) == 0
		and int(cold_repeat_state.get("repeat_texture_ready_count", -1)) == 0
		and int(cold_repeat_state.get("repeat_texture_create_count", -1)) == 0,
		"a cold production catalog must not materialize repeat wrappers"
	)
	var cold := flow.get_map_scroll_asset_resolution(TowerMapScrollAssetCatalog.COMMON_HANJI_PAPER)
	_expect(not bool(cold.get("cached", true)), "the production owner must begin with a non-probing cold peek")
	_expect(flow.begin_vertical_slice(null, Callable(), {
		"run_id": "tower-map-scroll-prewarm",
		"map_seed": 83521,
	}), "the production flow fixture must begin")
	var debug_state := flow.get_map_scroll_asset_debug_state()
	_expect(int(debug_state.get("entry_count", 0)) == EXPECTED_ASSET_COUNT, "prepare must prewarm all 16 files before map draw")
	_expect(int(debug_state.get("ready_count", 0)) == EXPECTED_ASSET_COUNT, "production prewarm must retain all approved textures")
	_expect(
		int(debug_state.get("repeat_texture_ready_count", -1)) == 6
		and int(debug_state.get("repeat_texture_expected_count", -1)) == 6
		and int(debug_state.get("repeat_texture_create_count", -1)) == 6,
		"prepare must materialize exactly six catalog-owned repeat wrappers"
	)
	var create_count_before_model := int(
		debug_state.get("repeat_texture_create_count", -1)
	)
	var fullscreen_model: Dictionary = production_renderer.call(
		"build_fullscreen_map_model",
		flow,
		Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))
	)
	var repeat_state_after_model := flow.get_map_scroll_asset_debug_state()
	_expect(
		bool((fullscreen_model.get("scroll_background", {}) as Dictionary).get(
			"ready",
			false
		))
		and int(repeat_state_after_model.get("repeat_texture_create_count", -1))
			== create_count_before_model
		and int(repeat_state_after_model.get("repeat_texture_ready_count", -1)) == 6,
		"production model construction must remain allocation-free after catalog prewarm"
	)
	var isolated_flow := TowerAscentFlowOwner.new()
	var isolated_repeat_state := isolated_flow.get_map_scroll_asset_debug_state()
	_expect(
		int(isolated_repeat_state.get("entry_count", -1)) == 0
		and int(isolated_repeat_state.get("repeat_texture_ready_count", -1)) == 0
		and int(isolated_repeat_state.get("repeat_texture_create_count", -1)) == 0,
		"repeat wrappers and lifecycle counters must remain catalog-instance owned"
	)
	var second_prewarm_value: Variant = flow.call("_prewarm_map_scroll_assets")
	var second_prewarm: Dictionary = (
		second_prewarm_value as Dictionary
		if second_prewarm_value is Dictionary
		else {}
	)
	var repeat_state_after_repeat := flow.get_map_scroll_asset_debug_state()
	_expect(
		bool(second_prewarm.get("ready", false))
		and int(repeat_state_after_repeat.get("repeat_texture_ready_count", -1)) == 6
		and int(repeat_state_after_repeat.get("repeat_texture_create_count", -1)) == 6,
		"repeated prewarm must retain six catalog wrappers without allocating again"
	)
	var map_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_map_progress.gd"
	)
	var prepare_body := _function_body(map_source, "func prepare_vertical_slice_combat(")
	var prewarm_index := prepare_body.find("_prewarm_map_scroll_assets()")
	var ready_index := prepare_body.find("_prepared = true")
	_expect(prewarm_index >= 0 and ready_index > prewarm_index, "GRT-003: map art prewarm must finish before the flow becomes drawable")
	var renderer_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	)
	# The sanctioned prewarm-aware wrapper is ProjectResourceLoader.load_imported_texture,
	# whose name contains "ResourceLoader.load" as a substring. Strip the wrapper before
	# searching so the seal still catches a RAW engine load on the draw owner.
	var raw_load_source: String = renderer_source.replace("ProjectResourceLoader.load_imported_texture", "")
	raw_load_source = raw_load_source.replace("ProjectResourceLoader.load_texture", "")
	_expect(raw_load_source.find("ResourceLoader.load") < 0, "draw ownership must not load resources")
	_expect(raw_load_source.find("ResourceLoader.exists") < 0, "draw ownership must not probe missing paths")
	var background_model_body := _function_body(
		renderer_source,
		"func build_scroll_background_model("
	)
	var catalog_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_map_scroll_asset_catalog.gd"
	)
	var catalog_prewarm_body := _function_body(
		catalog_source,
		"func prewarm_asset("
	)
	_expect(
		renderer_source.count("CanvasTexture.new()") == 0
		and background_model_body.find("CanvasTexture.new()") < 0
		and background_model_body.find(
			"resolution.get(\"repeat_texture\", null) as CanvasTexture"
		) >= 0,
		"renderer model construction must be catalog lookup-only"
	)
	_expect(
		catalog_source.count("CanvasTexture.new()") == 1
		and catalog_prewarm_body.find("CanvasTexture.new()") >= 0
		and catalog_prewarm_body.find(
			"repeat_texture.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED"
		) >= 0,
		"repeat-wrapper allocation must remain isolated in catalog prewarm"
	)
	_leg_count += 1


func _verify_three_route_brush_states_and_geometry() -> void:
	var renderer := TowerAscentFlowRenderer.new()
	var edge := {"from": "floor_1_gate", "to": "floor_2_left"}
	var unselected_key := renderer.resolve_route_brush_asset_key(edge, [], [], "floor_1_gate")
	var available_key := renderer.resolve_route_brush_asset_key(
		edge,
		[],
		["floor_2_left"],
		"floor_1_gate"
	)
	var completed_key := renderer.resolve_route_brush_asset_key(
		edge,
		[{"from": "floor_1_gate", "to": "floor_2_left"}],
		["floor_2_left"],
		"floor_1_gate"
	)
	_expect(unselected_key == TowerMapScrollAssetCatalog.ROUTE_BRUSH_UNSELECTED, "an inactive route must use the approved unselected brush")
	_expect(available_key == TowerMapScrollAssetCatalog.ROUTE_BRUSH_AVAILABLE, "a current-node candidate must use the approved available brush")
	_expect(completed_key == TowerMapScrollAssetCatalog.ROUTE_BRUSH_COMPLETED_GOLD, "route history must take priority and use the approved gold brush")
	_expect(unselected_key != available_key and available_key != completed_key and completed_key != unselected_key, "the three route states must never collapse to alpha variants of one key")
	var route_clip := Rect2(Vector2.ZERO, Vector2(100.0, 100.0))
	var clipped_edge := {
		"from_position": Vector2(50.0, 50.0),
		"to_position": Vector2(50.0, 140.0),
	}
	_expect(renderer.should_draw_route_edge_in_view(clipped_edge, unselected_key, route_clip), "an unselected edge with one offscreen endpoint must retain its visible segment")
	_expect(renderer.should_draw_route_edge_in_view(clipped_edge, available_key, route_clip), "an available edge with one offscreen endpoint must retain its visible segment")
	_expect(renderer.should_draw_route_edge_in_view(clipped_edge, completed_key, route_clip), "completed gold history must retain its established clipped continuation")
	clipped_edge = {
		"from_position": Vector2(-20.0, -20.0),
		"to_position": Vector2(120.0, 120.0),
	}
	_expect(renderer.should_draw_route_edge_in_view(clipped_edge, unselected_key, route_clip), "a diagonal edge with both endpoints offscreen must remain drawable while crossing the viewport")
	clipped_edge = {
		"from_position": Vector2(-40.0, 20.0),
		"to_position": Vector2(-20.0, 80.0),
	}
	_expect(not renderer.should_draw_route_edge_in_view(clipped_edge, unselected_key, route_clip), "an edge wholly outside the viewport must remain culled")
	_expect(renderer.should_draw_route_edge_in_view(clipped_edge, completed_key, route_clip), "completed gold history must remain unconditionally drawable outside the viewport")
	clipped_edge["to_position"] = Vector2(50.0, 90.0)
	clipped_edge["from_position"] = Vector2(50.0, 50.0)
	_expect(renderer.should_draw_route_edge_in_view(clipped_edge, unselected_key, route_clip), "a non-gold edge between two visible nodes must remain drawable")

	var catalog := TowerMapScrollAssetCatalog.new()
	catalog.prewarm_all()
	var texture_paths := PackedStringArray()
	for asset_key in [unselected_key, available_key, completed_key]:
		var texture := catalog.get_cached_resolution(asset_key).get("texture", null) as Texture2D
		_expect(texture != null, "%s must resolve to its own approved brush texture" % asset_key)
		if texture != null:
			texture_paths.append(texture.resource_path)
	_expect(texture_paths.size() == 3 and texture_paths[0] != texture_paths[1] and texture_paths[1] != texture_paths[2] and texture_paths[2] != texture_paths[0], "the three path states must bind three distinct files")

	var quads := renderer.build_route_brush_strip(PackedVector2Array([
		Vector2(100.0, 300.0),
		Vector2(124.0, 220.0),
		Vector2(112.0, 140.0),
	]))
	var completed_quads := renderer.build_completed_route_brush_strip(PackedVector2Array([
		Vector2(100.0, 300.0),
		Vector2(124.0, 220.0),
		Vector2(112.0, 140.0),
	]))
	_expect(quads.size() >= 4, "a long curved route must tile the vertical brush instead of stretching one copy end to end")
	_expect(quads.size() > completed_quads.size(), "non-gold routes must overlap more brush copies while completed gold keeps its approved spacing")
	var saw_full_tile := false
	var saw_uv_restart := false
	var previous_tile_start := -INF
	for quad_index in range(quads.size()):
		var quad := quads[quad_index] as Dictionary
		var quad_points: PackedVector2Array = quad.get("points", PackedVector2Array())
		var quad_uvs: PackedVector2Array = quad.get("uvs", PackedVector2Array())
		_expect(quad_points.size() == 4, "every brush tile segment must remain a textured quad")
		if quad_points.size() == 4:
			_expect(is_equal_approx(quad_points[0].distance_to(quad_points[1]), 18.0), "route width must stay at the fixed 18px world contract")
			_expect(is_equal_approx(quad_points[2].distance_to(quad_points[3]), 18.0), "route width must not grow with edge length")
			var texture_axis := (
				(quad_points[2] + quad_points[3]) * 0.5
				- (quad_points[0] + quad_points[1]) * 0.5
			).normalized()
			var path_direction: Vector2 = quad.get("path_direction", Vector2.ZERO)
			_expect(texture_axis.dot(path_direction) >= 0.999, "the texture vertical axis must align with the local route direction")
		_expect(float(quad.get("world_length", INF)) <= 80.001, "no brush tile may exceed the 72:320 aspect-ratio length")
		_expect(is_equal_approx(float(quad.get("tile_stride", 0.0)), 28.0), "non-gold route stamps must advance by the dense 28px stride")
		var tile_start := float(quad.get("tile_start_distance", INF))
		if is_finite(previous_tile_start):
			_expect(is_equal_approx(tile_start - previous_tile_start, 28.0), "dense route stamps must overlap at one deterministic stride")
		previous_tile_start = tile_start
		if quad_uvs.size() == 4:
			_expect(quad_uvs[0].y >= -0.001 and quad_uvs[2].y <= 1.001, "each tiled brush copy must use normalized vertical UVs")
			saw_full_tile = saw_full_tile or is_equal_approx(quad_uvs[2].y, 1.0)
			if quad_index > 0:
				var previous_uvs: PackedVector2Array = (quads[quad_index - 1] as Dictionary).get("uvs", PackedVector2Array())
				if previous_uvs.size() == 4 and is_equal_approx(previous_uvs[2].y, 1.0) and is_equal_approx(quad_uvs[0].y, 0.0):
					saw_uv_restart = true
	_expect(saw_full_tile and saw_uv_restart, "vertical brush UVs must restart for each along-path tile")

	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {
		"run_id": "tower-map-scroll-brush",
		"map_seed": 83521,
	}), "the S4 production brush fixture must begin")
	var model := renderer.build_fullscreen_map_model(
		flow,
		Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))
	)
	var model_edges: Array = model.get("edges", [])
	_expect(not model_edges.is_empty() and not ((model_edges[0] as Dictionary).get("brush_quads", []) as Array).is_empty(), "fullscreen curved routes must cache textured brush geometry")
	var art_radius := float(model.get("art_size", 0.0)) * 0.5
	for model_edge_variant in model_edges:
		var model_edge := model_edge_variant as Dictionary
		_expect(
			(model_edge.get("path_start", Vector2.ZERO) as Vector2).distance_to(
				model_edge.get("from_position", Vector2.ZERO) as Vector2
			) <= art_radius + 0.001,
			"route starts must clamp under the source medal instead of leaving an orphan stamp"
		)
		_expect(
			(model_edge.get("path_end", Vector2.ZERO) as Vector2).distance_to(
				model_edge.get("to_position", Vector2.ZERO) as Vector2
			) <= art_radius + 0.001,
			"route ends must clamp under the target medal instead of protruding past the node"
		)
	var cache_state := renderer.get_render_cache_debug_state()
	_expect(int(cache_state.get("path_brush_segment_count", 0)) > 0, "the render cache must account for brush strip segments")
	_expect(int(cache_state.get("path_brush_draw_call_budget", -1)) == int(cache_state.get("path_brush_segment_count", 0)), "the brush strip draw-call budget must remain explicit")
	var renderer_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	)
	_expect(renderer_source.find("canvas.draw_polygon(") >= 0, "S4 must actually draw the approved brush textures")
	# The training-dummy floor-pivot wobble (862a27477) legitimately rotates via
	# a temporary draw transform. The playfield-transform contract is therefore
	# balance, not absence: every non-identity draw_set_transform must pair with
	# an immediate identity restore so map drawing never inherits a stale matrix.
	var transform_call_count := renderer_source.count("canvas.draw_set_transform(")
	var identity_restore_count := renderer_source.count(
		"canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)"
	)
	_expect(
		transform_call_count == identity_restore_count * 2,
		"every non-identity draw_set_transform in the map renderer must pair with an identity restore"
	)
	var fullscreen_draw_start := renderer_source.find("func _draw_fullscreen_map_model(")
	var fullscreen_edge_start := renderer_source.find("for edge_variant in model.get(\"edges\", [])", fullscreen_draw_start)
	var fullscreen_plaque_redraw := renderer_source.find("_draw_fullscreen_floor_guides(", fullscreen_edge_start)
	_expect(fullscreen_edge_start >= 0 and fullscreen_plaque_redraw > fullscreen_edge_start, "fullscreen plaques must redraw over route endpoints before medals")
	var legacy_draw_start := renderer_source.find("func _draw_route_map(")
	var legacy_edge_start := renderer_source.find("for edge_variant in edges:", legacy_draw_start)
	var legacy_plaque_redraw := renderer_source.find("_draw_floor_bands(", legacy_edge_start)
	_expect(legacy_edge_start >= 0 and legacy_plaque_redraw > legacy_edge_start, "M-key plaques must redraw over route endpoints before medals")
	_leg_count += 1


func _verify_fullscreen_medal_node_contract() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {
		"run_id": "tower-map-scroll-medals",
		"map_seed": 83521,
	}), "the fullscreen medal fixture must begin")
	var renderer := flow.get("_renderer") as Object
	_expect(renderer != null, "the medal fixture must use its production-prewarmed renderer")
	var model: Dictionary = renderer.call(
		"build_fullscreen_map_model",
		flow,
		Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))
	)
	_expect(is_equal_approx(float(model.get("art_size", 0.0)), 32.0 * float(model.get("map_scale", 0.0))), "M-key node medals must follow the same content scale as the scroll")
	var renderer_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	)
	var fullscreen_node_body := _function_body(
		renderer_source,
		"func _draw_fullscreen_map_node("
	)
	_expect(fullscreen_node_body.find("NODE_ART_TEXTURES") < 0, "fullscreen nodes must not place the legacy square art tile behind approved medals")
	_expect(fullscreen_node_body.find("canvas.draw_circle(") >= 0, "fullscreen nodes must use the same circular medal frame language as the approved composite")
	_expect(fullscreen_node_body.find("build_map_icon_presentation(node)") >= 0, "fullscreen medals must keep the approved iconography catalog")
	var target_ids: Array[String] = flow.get_route_target_ids()
	_expect(not target_ids.is_empty(), "the 2.15x gameplay fixture must expose a route target")
	if not target_ids.is_empty():
		flow.call("_resolve_route_target", target_ids[0])
		var total := (
			TowerAscentTuning.TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC
			+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC
			+ TowerAscentTuning.TEMP_MAP_TRANSITION_CAMERA_ZOOM_IN_SEC
			+ TowerAscentTuning.TEMP_MAP_TRANSITION_TRAVEL_SEC
			+ TowerAscentTuning.TEMP_MAP_TRANSITION_ARRIVE_VANISH_SEC
			+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_OUT_SEC
		)
		flow.set_transition_progress_for_qa(
			(
				TowerAscentTuning.TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC
				+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC
			) / total
		)
		var gameplay_model: Dictionary = renderer.call(
			"build_fullscreen_map_model",
			flow,
			Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))
		)
		var gameplay_camera: Dictionary = gameplay_model.get("camera", {})
		var gameplay_base_zoom := float(gameplay_camera.get("base_zoom_multiplier", 0.0))
		var gameplay_default_zoom := clampf(
			float(gameplay_model.get("minimum_cover_zoom", 0.0))
				/ TowerAscentTuning.TEMP_MAP_DEFAULT_ZOOMOUT_DIVISOR,
			float(gameplay_model.get("minimum_fit_all_zoom", 0.0)),
			float(gameplay_model.get("minimum_cover_zoom", 0.0))
		)
		_expect(is_equal_approx(gameplay_base_zoom, gameplay_default_zoom), "the walking transition must begin at the four-notch-out base")
		_expect(is_equal_approx(float(gameplay_camera.get("zoom_multiplier", 0.0)), 1.0), "the existing 1.0 to 1.18 walker intro multiplier must remain separate from the cover-aware base zoom")
	_leg_count += 1


func _verify_floor_gate_plaque_three_slice_contract() -> void:
	var renderer := TowerAscentFlowRenderer.new()
	var target_rect := renderer.build_floor_plaque_target_rect(Vector2(346.0, 320.0))
	_expect(target_rect.size.is_equal_approx(Vector2(184.0, 24.0)), "the runtime plaque must read as a compact floor marker rather than a shelf")
	var slices := renderer.build_horizontal_three_slice_model(
		Vector2(2480.0, 192.0),
		target_rect
	)
	_expect(slices.size() == 3, "the x4 plaque must render as left, stretchable middle, and right slices")
	if slices.size() == 3:
		var left := slices[0] as Dictionary
		var middle := slices[1] as Dictionary
		var right := slices[2] as Dictionary
		var left_source: Rect2 = left.get("source_rect", Rect2())
		var middle_source: Rect2 = middle.get("source_rect", Rect2())
		var right_source: Rect2 = right.get("source_rect", Rect2())
		var left_target: Rect2 = left.get("target_rect", Rect2())
		var middle_target: Rect2 = middle.get("target_rect", Rect2())
		var right_target: Rect2 = right.get("target_rect", Rect2())
		_expect(is_equal_approx(left_source.size.x, 192.0) and is_equal_approx(right_source.size.x, 192.0), "the plaque endcaps must retain their approved square source geometry at x4 density")
		_expect(is_equal_approx(left_target.size.x, target_rect.size.y) and is_equal_approx(right_target.size.x, target_rect.size.y), "horizontal stretching must preserve both endcap aspect ratios")
		_expect(is_equal_approx(left_target.end.x, middle_target.position.x) and is_equal_approx(middle_target.end.x, right_target.position.x), "plaque slices must meet without gaps")
		_expect(is_equal_approx(left_source.end.x, middle_source.position.x) and is_equal_approx(middle_source.end.x, right_source.position.x), "three-slice source regions must cover the approved texture continuously")
		_expect(is_equal_approx(right_source.end.x, 2480.0) and is_equal_approx(right_target.end.x, target_rect.end.x), "three-slice rendering must cover both full source and target widths")
	var catalog := TowerMapScrollAssetCatalog.new()
	catalog.prewarm_all()
	var plaque_resolution := catalog.get_cached_resolution(
		TowerMapScrollAssetCatalog.FLOOR_GATE_PLAQUE
	)
	var plaque_texture := plaque_resolution.get("texture", null) as Texture2D
	_expect(plaque_texture != null and Vector2i(plaque_texture.get_size()) == Vector2i(2480, 192), "S5 must use the x4 plaque texture without changing its world rect")
	var renderer_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	)
	_expect(renderer_source.find("_draw_floor_plaque(") >= 0 and renderer_source.find("build_horizontal_three_slice_model(") >= 0, "both map surfaces must use the approved plaque and runtime floor number overlay")
	_leg_count += 1


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_func := source.find("\nfunc ", start + signature.length())
	return source.substr(start) if next_func < 0 else source.substr(start, next_func - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
