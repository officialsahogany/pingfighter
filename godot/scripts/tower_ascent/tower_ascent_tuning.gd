extends RefCounted

# TEMP: §6에서 상자 등급 수치가 확정될 때까지 한곳에서만 조정한다.
const CHEST_NORMAL_BASE_WEIGHT := 75.0
const CHEST_SUPREME_ART_BASE_WEIGHT := 20.0
const CHEST_SECRET_CHOSIK_BASE_WEIGHT := 5.0
const CHEST_FLOOR_NORMAL_WEIGHT_REDUCTION := 1.5
const CHEST_FLOOR_SUPREME_WEIGHT_BONUS := 1.0
const CHEST_FLOOR_SECRET_WEIGHT_BONUS := 0.5
const CHEST_RISK_NORMAL_WEIGHT_REDUCTION := 8.0
const CHEST_RISK_SUPREME_WEIGHT_BONUS := 5.0
const CHEST_RISK_SECRET_WEIGHT_BONUS := 3.0

# TEMP: Phase A only establishes the single rarity schema and the ownership of
# the per-match cap. Product tuning may replace these values without moving the
# runtime owners or adding another acquisition-specific rarity field.
const TEMP_FIELD_ACTIVE_RARITIES := ["common"]
const TEMP_NORMAL_CHEST_ACTIVE_RARITIES := ["common", "rare"]
const TEMP_SHOP_REGULAR_ACTIVE_RARITIES := ["common", "rare"]
const TEMP_SHOP_PREMIUM_ACTIVE_RARITIES := ["legendary", "mythic"]
const TEMP_REGULAR_SPAWN_BUDGET_MIN := 0
const TEMP_REGULAR_SPAWN_BUDGET_MAX := 1

# TEMP: Phase B establishes generated floor/row ownership. Product tuning may
# change only these values while the 12-floor and floor-gate contracts remain
# fixed; map row width now belongs to the seeded v7 graph generator.
const TEMP_OPTIONAL_ROWS_PER_FLOOR := 1
const TEMP_STANDARD_EXTRA_COMBAT_ROWS_MIN := 1
const TEMP_STANDARD_EXTRA_COMBAT_ROWS_MAX := 3
const TEMP_STANDARD_COMBAT_BUDGET_MIN := 10
const TEMP_STANDARD_COMBAT_BUDGET_MAX := 12
const TEMP_NODE_TYPE_WEIGHTS := {
	"shop": 2,
	"training": 2,
	"fallen_monk": 1,
	"guardian_spring": 1,
	"rest": 2,
}

# TEMP: v1.6 fixes the two-target/one-target layout contract but leaves final
# battle-scene target sizing and placement to product tuning.
const TEMP_ROUTE_TARGET_LEFT_X := 220.0
const TEMP_ROUTE_TARGET_RIGHT_X := 540.0
const TEMP_ROUTE_TARGET_CENTER_X := 380.0
const TEMP_ROUTE_TARGET_Y := 165.0
const TEMP_ROUTE_TARGET_DRAW_RADIUS := 30.0
const TEMP_ROUTE_TARGET_HIT_RADIUS := 49.0
const TEMP_ROUTE_TARGET_LABEL_WIDTH := 184.0
const TEMP_ROUTE_TARGET_LABEL_HEIGHT := 30.0
const TEMP_ROUTE_TARGET_LABEL_GAP := 8.0
const TEMP_ROUTE_AIM_MIN_DEGREES := -55.0
const TEMP_ROUTE_AIM_MAX_DEGREES := 55.0
const TEMP_ROUTE_AIM_SWEEP_PERIOD_SECONDS := 2.4
const TEMP_ROUTE_AIM_ENTRY_ARM_SECONDS := 0.35
# Live feedback 2026-08-22: the route serve read as too fast to aim, so this
# is a deliberate 30 percent cut from the original 522.0.
const TEMP_ROUTE_AIM_SERVE_SPEED_PER_SECOND := 365.4
const TEMP_ROUTE_AIM_GAUGE_RADIUS := 58.0
const TEMP_ROUTE_AIM_GAUGE_PLAYER_GAP := 100.0
const TEMP_ROUTE_AIM_GAUGE_PIVOT_RATIO := Vector2(0.5, 0.875)
const TEMP_ROUTE_AIM_GAUGE_TEXTURE_RADIUS_PX := 88.0
const TEMP_ROUTE_AIM_ARROW_ORBIT_RATIO := 0.72
const TEMP_ROUTE_WIND_PANEL_SIZE := Vector2(112.0, 36.0)
const TEMP_ROUTE_WIND_PANEL_GAP := 14.0
const TEMP_ROUTE_WIND_STRENGTH_CELL_SIZE := Vector2(12.0, 7.0)
const TEMP_ROUTE_WIND_STRENGTH_CELL_GAP := 3.0
const TEMP_ROUTE_PICKUP_CURRENCY_COUNT_MIN := 2
const TEMP_ROUTE_PICKUP_CURRENCY_COUNT_MAX := 5
const TEMP_ROUTE_PICKUP_PLACEMENT_RECT := Rect2(70.0, 235.0, 620.0, 310.0)
const TEMP_ROUTE_PICKUP_DRAW_RADIUS := 18.0
const TEMP_ROUTE_PICKUP_HIT_RADIUS := 20.0
const TEMP_ROUTE_PICKUP_MIN_CENTER_GAP := 58.0
const TEMP_ROUTE_PICKUP_MIN_TARGET_CENTER_GAP := 86.0
const TEMP_ROUTE_PICKUP_MIN_PATH_CENTER_GAP := 38.0
const TEMP_ROUTE_PICKUP_ROUTE_ORIGIN := Vector2(380.0, 665.0)
const TEMP_ROUTE_PICKUP_PLACEMENT_ATTEMPTS := 96
const TEMP_ROUTE_PICKUP_FALLBACK_GRID_STEP := Vector2(58.0, 54.0)

# TEMP: the map-view overlay establishes the information hierarchy while its
# final mobile/readability sizing is still product-tuning work.
const TEMP_MAP_OVERLAY_NODE_RADIUS := 8.0
const TEMP_MAP_OVERLAY_CURRENT_RING_RADIUS := 14.0
const TEMP_MAP_OVERLAY_NODE_LABEL_FONT_SIZE := 10
const TEMP_MAP_OVERLAY_NODE_LABEL_OFFSET_X := 11.0
const TEMP_MAP_OVERLAY_NODE_LABEL_WIDTH := 110.0
const TEMP_MAP_OVERLAY_STATE_LABEL_WIDTH := 48.0
const TEMP_MAP_OVERLAY_LEGEND_Y := 662.0
# TEMP: v1.12 fixes the transition beats and proportional fullscreen-map
# skeleton. Product tuning may adjust these values in place, but must not move
# the clock out of the tower flow or restore absolute layout caps.
const TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC := 0.25
const TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC := 0.25
# Author timing in the repository's 60-frame convention. The production
# physics clock runs at 72 Hz, so this exact second occupies 72 physics ticks.
const TEMP_MAP_TRANSITION_CAMERA_ZOOM_IN_SEC := 60.0 / 60.0
const TEMP_MAP_TRANSITION_TRAVEL_SEC := 1.60
const TEMP_MAP_TRANSITION_ARRIVE_VANISH_SEC := 0.35
const TEMP_MAP_TRANSITION_MAP_FADE_OUT_SEC := 0.28
const TEMP_NODE_MODAL_FADE_IN_SEC := 0.25
const TEMP_MAP_OVERLAY_FADE_SEC := 0.18
const TEMP_MAP_OUTER_MARGIN_RATIO := 0.024
const TEMP_MAP_SIDE_GUTTER_RATIO := 0.130
const TEMP_MAP_LANE_SPAN_RATIO := 0.290
const TEMP_MAP_ART_SIZE_RATIO := 0.720
const TEMP_MAP_CONTENT_TOP_RATIO := 0.1025
const TEMP_MAP_CONTENT_BOTTOM_RATIO := 0.1925
# TEMP: v1.13 replaces full-map disclosure with a vertically tracked map.
# Keep the zoom and focus policy in the shared tuning table until product feel
# tuning is final; the camera owner still enforces a minimum 2x scale.
const TEMP_MAP_CAMERA_ZOOM := 2.15
const TEMP_MAP_CAMERA_FOCUS_Y_RATIO := 0.50
const TEMP_MAP_CAMERA_BOUNDARY_ART_PADDING_RATIO := 0.78
# The transition begins at the established v1.13 crop, then narrows enough to
# read as an intro without hiding the next route row.
const TEMP_MAP_CAMERA_INTRO_START_MULTIPLIER := 1.0
const TEMP_MAP_CAMERA_INTRO_END_MULTIPLIER := 1.18
const TEMP_MAP_PATH_CURVE_MIN_RATIO := 0.10
const TEMP_MAP_PATH_CURVE_MAX_RATIO := 0.24
const TEMP_MAP_PATH_CURVE_SKEW_RATIO := 0.08
const TEMP_MAP_PATH_ENDPOINT_CLEARANCE_RATIO := 0.68
const TEMP_MAP_PATH_SAMPLE_MIN := 18
const TEMP_MAP_PATH_SAMPLE_MAX := 42
const TEMP_MAP_PATH_DOT_GAP_ART_RATIO := 0.32
const TEMP_MAP_PATH_DOT_OUTER_RADIUS_ART_RATIO := 0.072
const TEMP_MAP_PATH_DOT_INNER_RADIUS_ART_RATIO := 0.030
const TEMP_MAP_PATH_DOT_CIRCLE_SEGMENTS := 10
# Each dot is two polygon draws. Dense v7 lane graphs keep every edge and
# adapt dot spacing once during cached projection instead of dropping paths.
const TEMP_MAP_PATH_DRAW_CALL_BUDGET := 1536

# TEMP: v1.12 keeps the exhausted reward board visible briefly before the
# route flow resumes. Final presentation timing remains product-tuning work.
const TEMP_REWARD_PICK_EMPTY_BOARD_HOLD_SEC := 0.60

# TEMP: v1.12 fixes the starting-card structure while final presentation
# timing remains product-tuning work. Keep this table independent from the
# four-card boss reward picker; the two flows have different contracts.
const TEMP_START_CARD_TOTAL_COUNT := 3
const TEMP_START_CARD_MIN_CHOSIK_COUNT := 1
const TEMP_START_CARD_MAX_CHOSIK_COUNT := 2
const TEMP_START_CARD_TWO_CHOSIK_CHANCE := 0.50
const TEMP_START_CARD_MUGONG_START_LEVEL := 2
const TEMP_START_CARD_PICK_LIMIT := 1
const TEMP_START_CARD_MIN_TOTAL_CANDIDATES := 3
const TEMP_START_CARD_OFFER_VERSION := 1
const TEMP_START_CARD_FOOTER_RESERVE_PX := 0.0
const TEMP_START_CARD_BACKDROP_ALPHA := 1.0
const TEMP_START_CARD_INTRO_ANIM_SEC := 0.28
const TEMP_START_CARD_ABSORB_DURATION_SEC := 0.78
const TEMP_START_CARD_FAILSAFE_TIMEOUT_SEC := 60.0
const TEMP_START_CARD_COUNTDOWN_WINDOW_SEC := 10.0
const TEMP_START_CARD_COLD_BUILD_BUDGET_MS := 8.0

# TEMP: Phase C validates only the relative price skeleton fixed by the goal
# document. Product balance may replace these values without moving payment,
# stock, or snapshot ownership out of the tower run.
const TEMP_PHASE_C_SHOP_COMMON_ACTIVE_PRICE := 60
const TEMP_PHASE_C_SHOP_LEGENDARY_ACTIVE_PRICE := 180
const TEMP_PHASE_C_SHOP_MYTHIC_ACTIVE_PRICE := 300
const TEMP_PHASE_C_SHOP_CAPSULE_PRICE := 80
const TEMP_PHASE_C_SHOP_CHANCE_GEM_PRICE := 150
const TEMP_PHASE_C_TRAINING_STAT_COST := 1
const TEMP_PHASE_C_TRAINING_MUGONG_COST := 2
const TEMP_PHASE_C_MONK_CHOSIK_ACQUIRE_COST := 3
const TEMP_PHASE_C_MONK_CHOSIK_SWAP_COST := 4
const TEMP_PHASE_C_MONK_CHOSIK_REMOVE_COST := 5
const TEMP_PHASE_C_SPRING_ENHANCE_COST := 2
const TEMP_PHASE_C_REST_RESTORE_PER_NODE := 1

# TEMP: Remaining shell boss slots reuse existing Godot bosses until their
# content tracks replace the stand-ins. Ported variants route from the boss
# registry itself and must not retain duplicate entries here.
const TEMP_BOSS_STANDIN_BY_SLOT := {
	"floor_04_shell_01": {"stage": 4, "boss_id": "ponk"},
	"floor_04_shell_02": {"stage": 4, "boss_id": "ponk"},
	"floor_05_shell_01": {"stage": 5, "boss_id": "hongryun"},
	"floor_05_shell_02": {"stage": 5, "boss_id": "hongryun"},
	"floor_06_shell_01": {"stage": 6, "boss_id": "tetriser"},
	"floor_06_shell_02": {"stage": 6, "boss_id": "tetriser"},
	"floor_07_shell_01": {"stage": 7, "boss_id": "akamu_rigo"},
	"floor_07_shell_02": {"stage": 7, "boss_id": "akamu_rigo"},
	"floor_08_shell_01": {"stage": 8, "boss_id": "minotaur"},
	"floor_08_shell_02": {"stage": 8, "boss_id": "minotaur"},
	"floor_09_fake_ending": {"stage": 8, "boss_id": "minotaur"},
	"floor_10_shell_01": {"stage": 6, "boss_id": "tetriser"},
	"floor_10_shell_02": {"stage": 7, "boss_id": "akamu_rigo"},
	"floor_10_shell_03": {"stage": 8, "boss_id": "minotaur"},
	"floor_11_king_01": {"stage": 4, "boss_id": "ponk"},
	"floor_11_king_02": {"stage": 5, "boss_id": "hongryun"},
	"floor_11_king_03": {"stage": 6, "boss_id": "tetriser"},
	"floor_11_king_04": {"stage": 7, "boss_id": "akamu_rigo"},
	"floor_12_true_ending": {"stage": 8, "boss_id": "minotaur"},
}

# Canonical §3.5 parity value. League scaling remains a later tuning input;
# the base opportunity roll is 10% and is resolved once during map generation.
const NORMAL_BOSS_ENRAGED_CHANCE := 0.10
